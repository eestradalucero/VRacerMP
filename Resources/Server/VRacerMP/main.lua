-- VRacerMP server plugin entry point. Glue only (architecture ORG-2):
-- registers BeamMP events and hands them to the race coordinator.
-- BeamMP calls event handlers by global name, so the handle* functions below are
-- the only globals in the plugin (architecture ORG-6).

-- BeamMP runs plugins from the server folder, so this relative path finds our modules.
-- (No debug library: BeamMP hosts refuse plugins that use it.)
local PLUGIN_FOLDER = "Resources/Server/VRacerMP"
package.path = PLUGIN_FOLDER .. "/?.lua;" .. package.path

local protocol = require("vracerMP/shared/protocol")
local serverOptions = require("vracerMP/serverOptions")
local log = require("vracerMP/util/serverLog").log
local ServerClock = require("vracerMP/util/serverClock")
local RaceRegistry = require("vracerMP/races/raceRegistry")
local ResultsAnnouncer = require("vracerMP/results/resultsAnnouncer")
local LapRecords = require("vracerMP/records/lapRecords")
local TrackDirectory = require("vracerMP/tracks/trackDirectory")
local RaceCoordinator = require("vracerMP/coordinator/raceCoordinator")
local CommandEntryPoints = require("vracerMP/commands/commandEntryPoints")
local serverNetwork = require("vracerMP/network/serverNetwork")
local playerDirectory = require("vracerMP/network/playerDirectory")
local pluginEvents = require("vracerMP/network/pluginEvents")

local logTag = "vracerMP"
local TICK_EVENT = "vracerMP_tick"
local TICK_INTERVAL_MS = 100
local CANCEL_CHAT_MESSAGE = 1

local registry = RaceRegistry.new(ServerClock.new())
local trackDirectory = TrackDirectory.new()

local coordinator = RaceCoordinator.new({
  registry = registry,
  network = serverNetwork,
  playerDirectory = playerDirectory,
  resultsAnnouncer = ResultsAnnouncer.new(serverNetwork),
  lapRecords = LapRecords.new(),
  trackDirectory = trackDirectory,
  pluginEvents = pluginEvents,
})

local commandEntryPoints = CommandEntryPoints.new({
  coordinator = coordinator,
  registry = registry,
  trackDirectory = trackDirectory,
  playerDirectory = playerDirectory,
  sendChat = MP.SendChatMessage,
  pluginEvents = pluginEvents,
  testingCommands = serverOptions.testingCommands,
})

-- Decodes the payload and calls the coordinator; invalid payloads are dropped.
local function forwardToCoordinator(methodName, playerId, rawData)
  local payload = serverNetwork.decodePayload(rawData)
  if not payload then return end
  coordinator[methodName](coordinator, playerId, payload)
end

-- Client events ----------------------------------------------------------------

function handleRequestLobbies(playerId, rawData) forwardToCoordinator("handleRequestLobbies", playerId, rawData) end
function handleRegister(playerId, rawData) forwardToCoordinator("handleRegister", playerId, rawData) end
function handleUnregister(playerId, rawData) forwardToCoordinator("handleUnregister", playerId, rawData) end
function handleConfigure(playerId, rawData) forwardToCoordinator("handleConfigure", playerId, rawData) end
function handleStartRace(playerId, rawData) forwardToCoordinator("handleStartRace", playerId, rawData) end
function handleGridReady(playerId, rawData) forwardToCoordinator("handleGridReady", playerId, rawData) end
function handlePathnodeReached(playerId, rawData) forwardToCoordinator("handlePathnodeReached", playerId, rawData) end

-- Server events ----------------------------------------------------------------

function handleTick()
  coordinator:handleTick()
end

function handlePlayerDisconnect(playerId)
  coordinator:handlePlayerDisconnect(playerId)
end

function handleVehicleReset(playerId)
  coordinator:handleVehicleReset(playerId)
end

-- Commands (B-4) ----------------------------------------------------------------

function handleChatMessage(playerId, playerName, message)
  if commandEntryPoints:runChatMessage(playerId, message) then return CANCEL_CHAT_MESSAGE end
end

-- BeamMP prints what this returns; other console input is left to the server and other plugins.
function handleConsoleInput(input)
  return commandEntryPoints:runConsoleInput(input)
end

-- Another plugin: MP.TriggerGlobalEvent("vracerMP_command", "start r-1", "myRequestId").
function handlePluginCommand(commandText, requestId)
  return commandEntryPoints:runPluginCommand(commandText, requestId)
end

-- Another plugin: MP.TriggerGlobalEvent("vracerMP_query", "tracks", "myRequestId") (B-12).
function handlePluginQuery(queryName, requestId)
  return commandEntryPoints:runPluginQuery(queryName, requestId)
end

-- Registration -------------------------------------------------------------------

local function registerClientEvents()
  local toServer = protocol.toServer
  MP.RegisterEvent(toServer.requestLobbies, "handleRequestLobbies")
  MP.RegisterEvent(toServer.register, "handleRegister")
  MP.RegisterEvent(toServer.unregister, "handleUnregister")
  MP.RegisterEvent(toServer.configure, "handleConfigure")
  MP.RegisterEvent(toServer.startRace, "handleStartRace")
  MP.RegisterEvent(toServer.gridReady, "handleGridReady")
  MP.RegisterEvent(toServer.pathnodeReached, "handlePathnodeReached")
end

local function registerServerEvents()
  MP.RegisterEvent("onPlayerDisconnect", "handlePlayerDisconnect")
  MP.RegisterEvent("onVehicleReset", "handleVehicleReset")
  MP.RegisterEvent("onChatMessage", "handleChatMessage")
  MP.RegisterEvent("onConsoleInput", "handleConsoleInput")
  MP.RegisterEvent(protocol.pluginEvents.command, "handlePluginCommand")
  MP.RegisterEvent(protocol.pluginEvents.query, "handlePluginQuery")
  MP.RegisterEvent(TICK_EVENT, "handleTick")
  MP.CreateEventTimer(TICK_EVENT, TICK_INTERVAL_MS)
end

registerClientEvents()
registerServerEvents()
log('I', logTag, "VRacerMP server loaded (protocol v" .. protocol.version .. ") from", PLUGIN_FOLDER)
if serverOptions.testingCommands then log('I', logTag, "testing commands are on (local test server)") end
