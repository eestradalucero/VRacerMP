-- VRacerMP server: class RaceCoordinator, turns player events into race changes and messages.
--
-- It is the only place that combines the race rules (races/*) with the edges
-- (network, player directory, results announcement). Dependencies are injected, so tests
-- can pass fakes:
--   { registry, network, playerDirectory, resultsAnnouncer }

local protocol = require("vracerMP/shared/protocol")
local raceStates = require("vracerMP/shared/raceStates")
local TrackRef = require("vracerMP/races/trackRef")
local Race = require("vracerMP/races/race")
local FakeRacer = require("vracerMP/testing/fakeRacer")
local messageBuilder = require("vracerMP/coordinator/messageBuilder")
local log = require("vracerMP/util/serverLog").log

local logTag = "vracerMP.coordinator"
local toClient = protocol.toClient
local DEFAULT_FAKE_LAP_SECONDS = 90
local MIN_FAKE_LAP_SECONDS = 5

local RaceCoordinator = {}
RaceCoordinator.__index = RaceCoordinator

function RaceCoordinator.new(dependencies)
  local self = setmetatable({}, RaceCoordinator)
  self.registry = dependencies.registry
  self.network = dependencies.network
  self.playerDirectory = dependencies.playerDirectory
  self.resultsAnnouncer = dependencies.resultsAnnouncer
  self.fakeRacersByRaceId = {}
  self.lastFakePlayerId = 0
  return self
end

-- Small helpers --------------------------------------------------------------

local function sendNotice(self, playerId, message)
  self.network.sendToPlayer(playerId, toClient.notice, messageBuilder.buildNotice(message))
end

local function sendToRacers(self, race, eventName, payload)
  self.network.sendToPlayers(race:getRacerPlayerIds(), eventName, payload)
end

local function broadcastLobby(self, race)
  self.network.broadcast(toClient.lobbyUpdated, messageBuilder.buildLobby(race))
end

local function sendStandings(self, race)
  sendToRacers(self, race, toClient.standings, messageBuilder.buildStandings(race))
end

-- The player's race, but only if the message is about that race (stale messages are ignored).
local function findPlayersRace(self, playerId, payload)
  local race = self.registry:findRaceOfPlayer(playerId)
  if not race then return nil end
  if payload and payload.raceId and payload.raceId ~= race.raceId then return nil end
  return race
end

local function removeRace(self, race)
  self.registry:removeRace(race.raceId)
  self.fakeRacersByRaceId[race.raceId] = nil
  self.network.broadcast(toClient.raceRemoved, messageBuilder.buildRaceRemoved(race))
end

-- Finishing ------------------------------------------------------------------

local function finishRace(self, race)
  race:finish()
  self.resultsAnnouncer:announceRace(race)
  sendToRacers(self, race, toClient.raceResults, messageBuilder.buildRaceResults(race))
  log('I', logTag, "race", race.raceId, "finished on", race.track.missionId)
  removeRace(self, race)
end

local function finishRaceIfComplete(self, race)
  if race:isComplete() then finishRace(self, race) end
end

local function announceRacerLeftTheRace(self, race, racer)
  self.network.sendToPlayer(racer.playerId, toClient.racerFinished, messageBuilder.buildRacerFinished(race, racer))
end

-- After racers finished or became DNF: tell them, update everyone, maybe end the race.
local function concludeRacers(self, race, racers)
  for _, racer in ipairs(racers) do
    announceRacerLeftTheRace(self, race, racer)
  end
  sendStandings(self, race)
  finishRaceIfComplete(self, race)
end

-- Registration ---------------------------------------------------------------

local function findOrCreateRaceForTrack(self, track)
  local race = self.registry:findOpenRaceForTrack(track.missionId)
  if race then return race end
  if self.registry:isTrackBusy(track.missionId) then return nil, "A race is already running on this track" end
  race = self.registry:createRace(track)
  log('I', logTag, "race", race.raceId, "created on", track.missionId)
  return race
end

function RaceCoordinator:handleRequestLobbies(playerId)
  for _, race in ipairs(self.registry:getAllRaces()) do
    self.network.sendToPlayer(playerId, toClient.lobbyUpdated, messageBuilder.buildLobby(race))
  end
end

function RaceCoordinator:handleRegister(playerId, payload)
  if self.registry:findRaceOfPlayer(playerId) then
    return sendNotice(self, playerId, "You are already registered in a race")
  end
  local track, trackError = TrackRef.fromClientData(payload.track)
  if not track then return sendNotice(self, playerId, "Cannot register: " .. trackError) end

  local race, raceError = findOrCreateRaceForTrack(self, track)
  if not race then return sendNotice(self, playerId, raceError) end

  local registered, registerError = race:register(self.playerDirectory.buildPlayer(playerId, payload.vehicle))
  if not registered then return sendNotice(self, playerId, registerError) end
  broadcastLobby(self, race)
end

local function removeRacerBeforeStart(self, race, playerId)
  local outcome = race:unregister(playerId)
  if outcome.isEmpty then
    log('I', logTag, "race", race.raceId, "removed: nobody left")
    race:abort()
    removeRace(self, race)
  else
    broadcastLobby(self, race)
  end
end

local function retireRacerDuringRace(self, race, playerId, reason)
  local outcome = race:unregister(playerId, reason)
  if outcome.becameDnf then
    concludeRacers(self, race, { race:getRacer(playerId) })
  end
end

function RaceCoordinator:handleUnregister(playerId, payload)
  local race = findPlayersRace(self, playerId, payload)
  if not race then return end
  if race:hasStarted() then
    retireRacerDuringRace(self, race, playerId, raceStates.dnfReason.retired)
  else
    removeRacerBeforeStart(self, race, playerId)
  end
end

function RaceCoordinator:handleConfigure(playerId, payload)
  local race = findPlayersRace(self, playerId, payload)
  if not race then return end
  local changed, changeError = race:configure(playerId, {
    laps = payload.laps,
    dnfTimeoutSeconds = payload.dnfTimeoutSeconds,
  })
  if not changed then return sendNotice(self, playerId, changeError) end
  broadcastLobby(self, race)
end

-- Start ----------------------------------------------------------------------

local function markFakeRacersOnGrid(self, race)
  for _, fakeRacer in ipairs(self.fakeRacersByRaceId[race.raceId] or {}) do
    race:markOnGrid(fakeRacer.playerId)
  end
end

local function sendGridSlots(self, race)
  for _, racer in ipairs(race.racers) do
    self.network.sendToPlayer(racer.playerId, toClient.raceStarting, messageBuilder.buildRaceStarting(race, racer))
  end
end

local function startCountdown(self, race)
  race:beginCountdown()
  sendToRacers(self, race, toClient.countdown, messageBuilder.buildCountdown(race, Race.COUNTDOWN_MS))
  broadcastLobby(self, race)
end

function RaceCoordinator:handleStartRace(playerId, payload)
  local race = findPlayersRace(self, playerId, payload)
  if not race then return end
  local started, startError = race:beginGridding(playerId)
  if not started then return sendNotice(self, playerId, startError) end

  log('I', logTag, "race", race.raceId, "starting with", #race.racers, "racers")
  sendGridSlots(self, race)
  broadcastLobby(self, race)
  markFakeRacersOnGrid(self, race)
  if race:areAllRacersOnGrid() then startCountdown(self, race) end
end

function RaceCoordinator:handleGridReady(playerId, payload)
  local race = findPlayersRace(self, playerId, payload)
  if not race then return end
  if race:markOnGrid(playerId) then startCountdown(self, race) end
end

local function startRunning(self, race)
  local missingRacers = race:beginRunning()
  sendToRacers(self, race, toClient.go, messageBuilder.buildGo(race))
  broadcastLobby(self, race)
  concludeRacers(self, race, missingRacers)
end

-- Racing ---------------------------------------------------------------------

local function sendGaps(self, race, playerId, gap)
  if not gap then return end
  self.network.sendToPlayer(playerId, toClient.gap, messageBuilder.buildGap(race, protocol.gapKind.ahead, gap.gapMs))
  self.network.sendToPlayer(gap.aheadPlayerId, toClient.gap, messageBuilder.buildGap(race, protocol.gapKind.behind, gap.gapMs))
end

local function warnIfImplausible(race, playerId, crossing, outcome)
  if outcome.isPlausible then return end
  log('W', logTag, "race", race.raceId, "player", playerId, "reported", crossing.raceTimeMs,
    "ms but the server measured", outcome.serverElapsedMs, "ms since GO")
end

local function readCrossing(payload)
  if type(payload.crossingNumber) ~= "number" or type(payload.raceTimeMs) ~= "number" then return nil end
  return {
    crossingNumber = math.floor(payload.crossingNumber),
    raceTimeMs = math.floor(payload.raceTimeMs),
    lapCompleted = payload.lapCompleted == true,
  }
end

local function applyCrossing(self, race, playerId, crossing)
  local outcome, ignoredReason = race:recordCrossing(playerId, crossing)
  if not outcome then
    log('D', logTag, "crossing ignored for player", playerId, ignoredReason)
    return
  end
  warnIfImplausible(race, playerId, crossing, outcome)
  sendGaps(self, race, playerId, outcome.gap)
  if outcome.finished then
    concludeRacers(self, race, { outcome.racer })
  else
    sendStandings(self, race)
  end
end

function RaceCoordinator:handlePathnodeReached(playerId, payload)
  local race = findPlayersRace(self, playerId, payload)
  if not race then return end
  local crossing = readCrossing(payload)
  if not crossing then return end
  applyCrossing(self, race, playerId, crossing)
end

function RaceCoordinator:handleVehicleReset(playerId)
  local race = self.registry:findRaceOfPlayer(playerId)
  if race then race:recordRecovery(playerId) end
end

function RaceCoordinator:handlePlayerDisconnect(playerId)
  local race = self.registry:findRaceOfPlayer(playerId)
  if not race then return end
  if race:hasStarted() then
    retireRacerDuringRace(self, race, playerId, raceStates.dnfReason.disconnected)
  else
    removeRacerBeforeStart(self, race, playerId)
  end
end

-- Fake racers (testing) -----------------------------------------------------

local function getFakeLapTimeMs(lapSeconds)
  if type(lapSeconds) ~= "number" or lapSeconds < MIN_FAKE_LAP_SECONDS then
    lapSeconds = DEFAULT_FAKE_LAP_SECONDS
  end
  return math.floor(lapSeconds * 1000)
end

-- Returns a message for the player who typed the command.
function RaceCoordinator:handleAddFakeRacer(playerId, lapSeconds)
  local race = self.registry:findRaceOfPlayer(playerId)
  if not race then return "Register in a race first" end
  if not race:isRegistrationOpen() then return "The race has already started" end

  self.lastFakePlayerId = self.lastFakePlayerId - 1
  local lapTimeMs = getFakeLapTimeMs(lapSeconds)
  local fakeRacer = FakeRacer.new(self.lastFakePlayerId, lapTimeMs, race.track.pathnodeCount)
  race:register(fakeRacer:buildPlayer())
  self.fakeRacersByRaceId[race.raceId] = self.fakeRacersByRaceId[race.raceId] or {}
  table.insert(self.fakeRacersByRaceId[race.raceId], fakeRacer)
  broadcastLobby(self, race)
  return fakeRacer.name .. " joined (" .. math.floor(lapTimeMs / 1000) .. " s per lap)"
end

local function advanceFakeRacers(self, race)
  if race.state ~= raceStates.raceState.running then return end
  for _, fakeRacer in ipairs(self.fakeRacersByRaceId[race.raceId] or {}) do
    for _, crossing in ipairs(fakeRacer:getDueCrossings(race:getElapsedRaceMs())) do
      local racer = race:getRacer(fakeRacer.playerId)
      if race:isOver() or not racer or not racer:isRacing() then break end
      applyCrossing(self, race, fakeRacer.playerId, crossing)
    end
  end
end

-- Timers ---------------------------------------------------------------------

local function runDueAction(self, race)
  local action = race:getDueAction()
  if action == Race.dueAction.beginCountdown then
    startCountdown(self, race)
  elseif action == Race.dueAction.go then
    startRunning(self, race)
  elseif action == Race.dueAction.dnfTimeout then
    concludeRacers(self, race, race:applyDnfTimeout())
  end
end

-- Called every 100 ms by the server timer.
function RaceCoordinator:handleTick()
  for _, race in ipairs(self.registry:getAllRaces()) do
    if not race:isOver() then runDueAction(self, race) end
    if not race:isOver() then advanceFakeRacers(self, race) end
  end
end

return RaceCoordinator
