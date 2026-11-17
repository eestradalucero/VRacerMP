-- VRacerMP server: class RaceCoordinator, turns player events into race changes and messages.
--
-- It is the only place that combines the race rules (races/*) with the edges
-- (network, player directory, results announcement). Dependencies are injected, so tests
-- can pass fakes:
--   { registry, network, playerDirectory, resultsAnnouncer, lapRecords, trackDirectory,
--     pluginEvents? }
-- The handle* methods answer client messages; the public methods without "handle" are what
-- commands use (B-4). `requester` is a player ID or Race.SERVER (the console or a plugin).

local protocol = require("vracerMP/shared/protocol")
local raceStates = require("vracerMP/shared/raceStates")
local TrackRef = require("vracerMP/races/trackRef")
local Race = require("vracerMP/races/race")
local FakeRacer = require("vracerMP/testing/fakeRacer")
local messageBuilder = require("vracerMP/coordinator/messageBuilder")
local log = require("vracerMP/util/serverLog").log
local timeFormat = require("vracerMP/shared/timeFormat")

local logTag = "vracerMP.coordinator"
local toClient = protocol.toClient
local DEFAULT_FAKE_LAP_SECONDS = 90
local MIN_FAKE_LAP_SECONDS = 5
local pluginEventName = protocol.pluginEvents

local noPluginEvents = { publish = function() end }

local RaceCoordinator = {}
RaceCoordinator.__index = RaceCoordinator

function RaceCoordinator.new(dependencies)
  local self = setmetatable({}, RaceCoordinator)
  self.registry = dependencies.registry
  self.network = dependencies.network
  self.playerDirectory = dependencies.playerDirectory
  self.resultsAnnouncer = dependencies.resultsAnnouncer
  self.lapRecords = dependencies.lapRecords
  self.trackDirectory = dependencies.trackDirectory
  self.pluginEvents = dependencies.pluginEvents or noPluginEvents
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
  local lobby = messageBuilder.buildLobby(race)
  self.network.broadcast(toClient.lobbyUpdated, lobby)
  self.pluginEvents.publish(pluginEventName.raceUpdated, lobby)
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
  local removal = messageBuilder.buildRaceRemoved(race)
  self.network.broadcast(toClient.raceRemoved, removal)
  self.pluginEvents.publish(pluginEventName.raceRemoved, removal)
end

-- Finishing ------------------------------------------------------------------

local function finishRace(self, race)
  race:finish()
  self.resultsAnnouncer:announceRace(race)
  local results = messageBuilder.buildRaceResults(race)
  sendToRacers(self, race, toClient.raceResults, results)
  self.pluginEvents.publish(pluginEventName.raceResults, results)
  log('I', logTag, "race", race.raceId, "finished on", race.track.missionId)
  removeRace(self, race)
end

-- No results are sent for a cancelled race.
local function cancelRace(self, race, reason)
  log('I', logTag, "race", race.raceId, "cancelled:", reason)
  race:abort()
  removeRace(self, race)
end

-- Every player dropped out (FIN-9): before GO the race is cancelled; after GO any fake
-- racers stop and the race finishes with everyone DNF, so the track is free again.
local function endRaceWithoutPlayers(self, race)
  if not race:isRunning() then return cancelRace(self, race, "every player left before GO") end
  race:retireRemainingFakeRacers()
  sendStandings(self, race)
  finishRace(self, race)
end

local function endRaceIfOver(self, race)
  if race:isComplete() then
    finishRace(self, race)
  elseif race:haveAllPlayersDroppedOut() then
    endRaceWithoutPlayers(self, race)
  end
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
  broadcastLobby(self, race) -- racer statuses changed: those who left can register elsewhere
  endRaceIfOver(self, race)
end

-- Registration ---------------------------------------------------------------

local function createRaceOnTrack(self, track, ownerPlayerId)
  local race = self.registry:createRace(track, ownerPlayerId)
  log('I', logTag, "race", race.raceId, "created on", track.missionId)
  return race
end

local function findOrCreateRaceForTrack(self, track)
  local race = self.registry:findOpenRaceForTrack(track.missionId)
  if race then return race end
  if self.registry:isTrackBusy(track.missionId) then return nil, "A race is already running on this track" end
  return createRaceOnTrack(self, track, nil)
end

-- A player who just loaded the level reports the tracks of the map (B-4) and gets a welcome
-- (so their game stops asking), every race and every track's lap record.
function RaceCoordinator:handleRequestLobbies(playerId, payload)
  local trackCount = self.trackDirectory:reportTracks(payload and payload.tracks)
  log('I', logTag, "player", playerId, "joined VRacerMP and reported", trackCount, "tracks")
  self.network.sendToPlayer(playerId, toClient.welcome, { protocolVersion = protocol.version })
  for _, race in ipairs(self.registry:getAllRaces()) do
    self.network.sendToPlayer(playerId, toClient.lobbyUpdated, messageBuilder.buildLobby(race))
  end
  for _, record in ipairs(self.lapRecords:getAllTrackRecords()) do
    self.network.sendToPlayer(playerId, toClient.lapRecord, messageBuilder.buildLapRecord(record))
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

  local registered, registerError = self:registerPlayer(race, playerId, payload.vehicle)
  if not registered then sendNotice(self, playerId, registerError) end
end

-- Registers a player in a race that is still open. vehicle = { model } or nil (commands
-- register players without a car; it is filled in when they reach the grid).
-- Returns true, or false and a message.
function RaceCoordinator:registerPlayer(race, playerId, vehicle)
  if self.registry:findRaceOfPlayer(playerId) then return false, "Already registered in a race" end
  local registered, registerError = race:register(self.playerDirectory.buildPlayer(playerId, vehicle))
  if not registered then return false, registerError end
  broadcastLobby(self, race)
  return true
end

-- Server races stay open while empty: the console or plugin that made them decides (B-4).
local function removeRacerBeforeStart(self, race, playerId)
  local outcome = race:unregister(playerId)
  if outcome.isEmpty and not race:isServerOwned() then
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

-- Before the start the player is removed; after it they retire (DNF).
-- Returns true, or false and a message.
function RaceCoordinator:unregisterPlayer(race, playerId)
  local racer = race:getRacer(playerId)
  if not racer then return false, "Not in this race" end
  if racer:hasLeftTheRace() then return false, "Already out of the race" end
  if race:hasStarted() then
    retireRacerDuringRace(self, race, playerId, raceStates.dnfReason.retired)
  else
    removeRacerBeforeStart(self, race, playerId)
  end
  return true
end

function RaceCoordinator:handleUnregister(playerId, payload)
  local race = findPlayersRace(self, playerId, payload)
  if race then self:unregisterPlayer(race, playerId) end
end

-- changes = { laps?, dnfTimeoutSeconds? }. Returns true, or false and a message.
function RaceCoordinator:configureRace(race, requester, changes)
  local changed, changeError = race:configure(requester, changes)
  if not changed then return false, changeError end
  broadcastLobby(self, race)
  return true
end

function RaceCoordinator:handleConfigure(playerId, payload)
  local race = findPlayersRace(self, playerId, payload)
  if not race then return end
  local changed, changeError = self:configureRace(race, playerId, {
    laps = payload.laps,
    dnfTimeoutSeconds = payload.dnfTimeoutSeconds,
  })
  if not changed then sendNotice(self, playerId, changeError) end
end

-- Creates a race on a track (B-4). A player who creates one owns it and is registered in it;
-- races the server creates are owned by the server. Returns the race, or nil and a message.
function RaceCoordinator:createRace(track, requester)
  if self.registry:findOpenRaceForTrack(track.missionId) then return nil, "There is already an open race on " .. track.name end
  if self.registry:isTrackBusy(track.missionId) then return nil, "A race is already running on " .. track.name end
  if requester == Race.SERVER then
    local race = createRaceOnTrack(self, track, Race.SERVER)
    broadcastLobby(self, race)
    return race
  end
  if self.registry:findRaceOfPlayer(requester) then return nil, "You are already registered in a race" end
  local race = createRaceOnTrack(self, track, nil)
  self:registerPlayer(race, requester, nil)
  return race
end

-- Cancels a race at any point (B-4): racers are told, nobody gets results.
function RaceCoordinator:cancelRace(race)
  for _, playerId in ipairs(race:getRacerPlayerIds()) do
    sendNotice(self, playerId, "The race on " .. race.track.name .. " was cancelled")
  end
  cancelRace(self, race, "by command")
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

-- Sends every racer to the grid. Returns true, or false and a message.
function RaceCoordinator:startRace(race, requester)
  local started, startError = race:beginGridding(requester)
  if not started then return false, startError end

  log('I', logTag, "race", race.raceId, "starting with", #race.racers, "racers")
  sendGridSlots(self, race)
  broadcastLobby(self, race)
  markFakeRacersOnGrid(self, race)
  if race:areAllRacersOnGrid() then startCountdown(self, race) end
  return true
end

function RaceCoordinator:handleStartRace(playerId, payload)
  local race = findPlayersRace(self, playerId, payload)
  if not race then return end
  local started, startError = self:startRace(race, playerId)
  if not started then sendNotice(self, playerId, startError) end
end

-- The client says which car it is driving: players registered by a command had none yet.
function RaceCoordinator:handleGridReady(playerId, payload)
  local race = findPlayersRace(self, playerId, payload)
  if not race then return end
  race:updateVehicle(playerId, self.playerDirectory.readVehicle(payload.vehicle))
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

-- New server lap record (B-8): everyone's lobby panel shows it, and the chat announces it.
local function announceLapRecord(self, record)
  self.network.broadcast(toClient.lapRecord, messageBuilder.buildLapRecord(record))
  self.network.broadcastChat(string.format("New server lap record on %s: %s by %s (%s)",
    record.trackName, timeFormat.formatDisplayTime(record.lapTimeMs), record.name, record.model))
end

-- Fake racers are for testing and never set records.
local function recordLapTime(self, race, racer, lapTimeMs)
  if not lapTimeMs or racer.isFake then return end
  local isNewRecord = self.lapRecords:recordLap({
    missionId = race.track.missionId,
    trackName = race.track.name,
    lapTimeMs = lapTimeMs,
    name = racer.name,
    model = racer.vehicle.model,
  })
  if isNewRecord then announceLapRecord(self, self.lapRecords:getTrackRecord(race.track.missionId)) end
end

local function applyCrossing(self, race, playerId, crossing)
  local outcome, ignoredReason = race:recordCrossing(playerId, crossing)
  if not outcome then
    log('D', logTag, "crossing ignored for player", playerId, ignoredReason)
    return
  end
  warnIfImplausible(race, playerId, crossing, outcome)
  recordLapTime(self, race, outcome.racer, outcome.lapTimeMs)
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

-- Penalties ------------------------------------------------------------------

-- Gives a racer a time penalty and tells them; standings carry everyone's penalty time.
-- penalty = { reason, penaltyMs, details? } (see Race:givePenalty). No penalty type uses this
-- yet; planned: speed zones, vehicle repairs, ...
function RaceCoordinator:givePenalty(playerId, penalty)
  local race = self.registry:findRaceOfPlayer(playerId)
  if not race then return nil end
  local storedPenalty = race:givePenalty(playerId, penalty)
  if not storedPenalty then return nil end
  local racer = race:getRacer(playerId)
  self.network.sendToPlayer(playerId, toClient.penalty, messageBuilder.buildPenalty(race, racer, storedPenalty))
  sendStandings(self, race)
  return storedPenalty
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

-- Adds a fake racer to an open race. Returns true and a message, or false and a message.
function RaceCoordinator:addFakeRacer(race, lapSeconds)
  if not race:isRegistrationOpen() then return false, "The race has already started" end

  self.lastFakePlayerId = self.lastFakePlayerId - 1
  local lapTimeMs = getFakeLapTimeMs(lapSeconds)
  local fakeRacer = FakeRacer.new(self.lastFakePlayerId, lapTimeMs, race.track.pathnodeCount)
  race:register(fakeRacer:buildPlayer())
  self.fakeRacersByRaceId[race.raceId] = self.fakeRacersByRaceId[race.raceId] or {}
  table.insert(self.fakeRacersByRaceId[race.raceId], fakeRacer)
  broadcastLobby(self, race)
  return true, fakeRacer.name .. " joined (" .. math.floor(lapTimeMs / 1000) .. " s per lap)"
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
