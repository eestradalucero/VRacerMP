-- VRacerMP server: class Race, one race on one track and its state machine.
--
--   registering -> gridding -> countdown -> running -> finished
--        \______________________________________________-> aborted
--
-- Pure race rules: no MP.* calls. Time comes from the injected clock
-- (`getNowMs()`, `getUtcIso()`), so tests can drive it.

local raceStates = require("vracerMP/shared/raceStates")
local jsonEncoder = require("vracerMP/shared/jsonEncoder")
local Racer = require("vracerMP/races/racer")
local RaceSettings = require("vracerMP/races/raceSettings")
local GapTracker = require("vracerMP/races/gapTracker")
local standings = require("vracerMP/races/standings")

local raceState = raceStates.raceState
local dnfReason = raceStates.dnfReason

local GRID_TIMEOUT_MS = 10000
local COUNTDOWN_MS = 3000
local PLAUSIBILITY_TOLERANCE_MS = 1000
local NETWORK_ALLOWANCE_MS = 1000
local SCHEMA_VERSION = 1

local Race = {}
Race.__index = Race

Race.COUNTDOWN_MS = COUNTDOWN_MS

function Race.new(raceId, track, clock)
  local self = setmetatable({}, Race)
  self.raceId = raceId
  self.track = track
  self.clock = clock
  self.settings = RaceSettings.new(track)
  self.state = raceState.registering
  self.racers = {}
  self.ownerPlayerId = nil
  self.nextRegistrationOrder = 1
  self.gapTracker = GapTracker.new()
  self.createdAtIso = clock:getUtcIso()
  self.startedAtIso = nil
  self.finishedAtIso = nil
  self.gridDeadlineMs = nil
  self.goAtMs = nil
  self.startedAtMs = nil
  self.dnfDeadlineMs = nil
  return self
end

-- Queries ------------------------------------------------------------------

function Race:getRacer(playerId)
  for _, racer in ipairs(self.racers) do
    if racer.playerId == playerId then return racer end
  end
  return nil
end

function Race:getRacerPlayerIds()
  local playerIds = {}
  for index, racer in ipairs(self.racers) do playerIds[index] = racer.playerId end
  return playerIds
end

function Race:getOwner()
  return self:getRacer(self.ownerPlayerId)
end

function Race:isOwner(playerId)
  return self.ownerPlayerId ~= nil and self.ownerPlayerId == playerId
end

function Race:isRegistrationOpen()
  return self.state == raceState.registering
end

function Race:hasStarted()
  return self.state ~= raceState.registering
end

function Race:isOver()
  return self.state == raceState.finished or self.state == raceState.aborted
end

function Race:isRunning()
  return self.state == raceState.running
end

-- True when every real (not fake) racer is DNF: nobody is racing and nobody finished.
function Race:haveAllPlayersDroppedOut()
  for _, racer in ipairs(self.racers) do
    if not racer.isFake and not racer:isDnf() then return false end
  end
  return true
end

function Race:getElapsedRaceMs()
  if not self.startedAtMs then return 0 end
  return self.clock:getNowMs() - self.startedAtMs
end

function Race:getOrderedRacers()
  return standings.getOrderedRacers(self.racers)
end

function Race:updatePositions()
  return standings.assignPositions(self.racers)
end

function Race:getWinner()
  local ordered = self:getOrderedRacers()
  local first = ordered[1]
  if first and first:isFinished() then return first end
  return nil
end

-- True when the race is running and nobody is racing any more.
function Race:isComplete()
  if self.state ~= raceState.running then return false end
  for _, racer in ipairs(self.racers) do
    if not racer:hasLeftTheRace() then return false end
  end
  return true
end

-- Registration ---------------------------------------------------------------

function Race:register(player)
  if not self:isRegistrationOpen() then return false, "Registration is closed" end
  if self:getRacer(player.playerId) then return false, "You are already registered" end

  table.insert(self.racers, Racer.new(player, self.nextRegistrationOrder))
  self.nextRegistrationOrder = self.nextRegistrationOrder + 1
  if not self.ownerPlayerId then
    self.ownerPlayerId = player.playerId
  end
  return true
end

local function removeRacer(self, playerId)
  for index, racer in ipairs(self.racers) do
    if racer.playerId == playerId then
      table.remove(self.racers, index)
      return
    end
  end
end

-- Next racer in registration order who is a real player (REG-7).
local function passOwnershipToNextRacer(self)
  self.ownerPlayerId = nil
  for _, racer in ipairs(self.racers) do
    if not racer.isFake then
      self.ownerPlayerId = racer.playerId
      return
    end
  end
end

local function hasRealPlayers(self)
  for _, racer in ipairs(self.racers) do
    if not racer.isFake then return true end
  end
  return false
end

-- Before the start the racer is removed; after it they become DNF (FIN-4).
-- Returns { becameDnf = bool, isEmpty = bool }.
function Race:unregister(playerId, reason)
  local racer = self:getRacer(playerId)
  if not racer then return { becameDnf = false, isEmpty = not hasRealPlayers(self) } end

  if self:hasStarted() then
    if not racer:hasLeftTheRace() then
      racer:markDnf(reason or dnfReason.retired)
      return { becameDnf = true, isEmpty = not hasRealPlayers(self) }
    end
    return { becameDnf = false, isEmpty = not hasRealPlayers(self) }
  end

  removeRacer(self, playerId)
  if self:isOwner(playerId) then
    passOwnershipToNextRacer(self)
  end
  return { becameDnf = false, isEmpty = not hasRealPlayers(self) }
end

function Race:configure(playerId, changes)
  if not self:isOwner(playerId) then return false, "Only the race owner can change settings" end
  if not self:isRegistrationOpen() then return false, "The race has already started" end
  return self.settings:applyChanges(changes, self.track)
end

-- Start --------------------------------------------------------------------

local function assignGridSlotsInRegistrationOrder(self)
  for index, racer in ipairs(self.racers) do
    racer.gridSlot = index
  end
end

function Race:beginGridding(playerId)
  if not self:isOwner(playerId) then return false, "Only the race owner can start the race" end
  if not self:isRegistrationOpen() then return false, "The race has already started" end
  if #self.racers == 0 then return false, "Nobody is registered" end

  assignGridSlotsInRegistrationOrder(self)
  self.state = raceState.gridding
  self.gridDeadlineMs = self.clock:getNowMs() + GRID_TIMEOUT_MS
  return true
end

function Race:areAllRacersOnGrid()
  for _, racer in ipairs(self.racers) do
    if not racer.isOnGrid and not racer:hasLeftTheRace() then return false end
  end
  return true
end

-- Returns true when this was the last racer the grid was waiting for.
function Race:markOnGrid(playerId)
  local racer = self:getRacer(playerId)
  if not racer or self.state ~= raceState.gridding then return false end
  racer.isOnGrid = true
  return self:areAllRacersOnGrid()
end

function Race:beginCountdown()
  self.state = raceState.countdown
  self.goAtMs = self.clock:getNowMs() + COUNTDOWN_MS
end

-- GO. Racers who never confirmed their grid slot are DNF (START-8).
-- Returns the list of racers made DNF.
function Race:beginRunning()
  self.state = raceState.running
  self.startedAtMs = self.clock:getNowMs()
  self.startedAtIso = self.clock:getUtcIso()
  local missingRacers = {}
  for _, racer in ipairs(self.racers) do
    if racer:hasLeftTheRace() then
      -- retired before GO: stays DNF
    elseif racer.isOnGrid then
      racer:startRacing()
    else
      racer:markDnf(dnfReason.notOnGrid)
      table.insert(missingRacers, racer)
    end
  end
  self:updatePositions()
  return missingRacers
end

-- Racing -------------------------------------------------------------------

local function isTimePlausible(self, raceTimeMs)
  local elapsedMs = self:getElapsedRaceMs()
  local earliestMs = elapsedMs - PLAUSIBILITY_TOLERANCE_MS - NETWORK_ALLOWANCE_MS
  local latestMs = elapsedMs + PLAUSIBILITY_TOLERANCE_MS
  return raceTimeMs >= earliestMs and raceTimeMs <= latestMs, elapsedMs
end

local function startDnfTimerIfFirstFinisher(self)
  if self.dnfDeadlineMs then return end
  self.dnfDeadlineMs = self.clock:getNowMs() + self.settings:getDnfTimeoutMs()
end

-- crossing = { crossingNumber, raceTimeMs, lapCompleted }
-- Returns an outcome table, or nil and a reason when the crossing is ignored:
--   { racer, gap = { aheadPlayerId, gapMs }?, finished = bool, isPlausible = bool, serverElapsedMs }
function Race:recordCrossing(playerId, crossing)
  if self.state ~= raceState.running then return nil, "race is not running" end
  local racer = self:getRacer(playerId)
  if not racer or not racer:isRacing() then return nil, "player is not racing" end
  if crossing.crossingNumber ~= racer.crossingCount + 1 then
    return nil, "unexpected crossing number " .. tostring(crossing.crossingNumber)
  end

  local isPlausible, serverElapsedMs = isTimePlausible(self, crossing.raceTimeMs)
  local finished = racer:recordCrossing(crossing.raceTimeMs, crossing.lapCompleted, self.settings.laps)
  local gap = self.gapTracker:recordCrossing(playerId, racer.crossingCount, crossing.raceTimeMs)
  if finished then startDnfTimerIfFirstFinisher(self) end
  self:updatePositions()

  return {
    racer = racer,
    gap = gap,
    finished = finished,
    isPlausible = isPlausible,
    serverElapsedMs = serverElapsedMs,
  }
end

function Race:markDnf(playerId, reason)
  local racer = self:getRacer(playerId)
  if not racer or racer:hasLeftTheRace() then return nil end
  racer:markDnf(reason)
  self:updatePositions()
  return racer
end

function Race:recordRecovery(playerId)
  local racer = self:getRacer(playerId)
  if racer and racer:isRacing() then racer:addRecovery() end
end

-- DNF timer ran out: everyone still racing is DNF (FIN-2). Returns those racers.
function Race:applyDnfTimeout()
  local timedOutRacers = {}
  for _, racer in ipairs(self.racers) do
    if racer:isRacing() then
      racer:markDnf(dnfReason.timeout)
      table.insert(timedOutRacers, racer)
    end
  end
  self.dnfDeadlineMs = nil
  self:updatePositions()
  return timedOutRacers
end

-- Timers -------------------------------------------------------------------

Race.dueAction = {
  beginCountdown = "beginCountdown",
  go = "go",
  dnfTimeout = "dnfTimeout",
}

-- What the coordinator should do now, if anything.
function Race:getDueAction()
  local nowMs = self.clock:getNowMs()
  if self.state == raceState.gridding and nowMs >= self.gridDeadlineMs then
    return Race.dueAction.beginCountdown
  end
  if self.state == raceState.countdown and nowMs >= self.goAtMs then
    return Race.dueAction.go
  end
  if self.state == raceState.running and self.dnfDeadlineMs and nowMs >= self.dnfDeadlineMs then
    return Race.dueAction.dnfTimeout
  end
  return nil
end

-- End ----------------------------------------------------------------------

-- Fake racers only exist for testing; when no real player is left they stop too.
-- Returns the fake racers made DNF.
function Race:retireRemainingFakeRacers()
  local retiredRacers = {}
  for _, racer in ipairs(self.racers) do
    if racer.isFake and not racer:hasLeftTheRace() then
      racer:markDnf(dnfReason.retired)
      table.insert(retiredRacers, racer)
    end
  end
  return retiredRacers
end

function Race:finish()
  self.state = raceState.finished
  self.finishedAtIso = self.clock:getUtcIso()
  self:updatePositions()
end

function Race:abort()
  self.state = raceState.aborted
  self.finishedAtIso = self.clock:getUtcIso()
end

-- Serialization (requirements §6) ------------------------------------------

local stateToFileStatus = {
  [raceState.registering] = "registering",
  [raceState.gridding] = "starting",
  [raceState.countdown] = "starting",
  [raceState.running] = "running",
  [raceState.finished] = "finished",
  [raceState.aborted] = "aborted",
}

local function orNull(value)
  if value == nil then return jsonEncoder.null end
  return value
end

local function serializeOwner(self)
  local owner = self:getOwner()
  if not owner then return jsonEncoder.null end
  return { name = owner.name, id = owner.playerId }
end

local function serializeRacers(self)
  local winner = self:getWinner()
  local winnerTimeMs = winner and winner.finishTimeMs or nil
  local serialized = {}
  for index, racer in ipairs(self:getOrderedRacers()) do
    serialized[index] = racer:serialize(winnerTimeMs)
  end
  return jsonEncoder.markAsArray(serialized)
end

function Race:serialize()
  return {
    schemaVersion = SCHEMA_VERSION,
    raceId = self.raceId,
    status = stateToFileStatus[self.state],
    raceType = self.settings.raceType,
    map = self.track.level,
    raceTrack = self.track:serialize(),
    laps = self.settings.laps,
    settings = self.settings:serialize(),
    owner = serializeOwner(self),
    createdAt = self.createdAtIso,
    startedAt = orNull(self.startedAtIso),
    finishedAt = orNull(self.finishedAtIso),
    racers = serializeRacers(self),
  }
end

return Race
