-- VRacerMP server plugin entry point. Glue only (architecture ORG-2):
-- registers BeamMP events and hands them to the race coordinator.
-- BeamMP calls event handlers by global name, so the handle* functions below are
-- the only globals in the plugin (architecture ORG-6).

local DEFAULT_PLUGIN_FOLDER = "Resources/Server/VRacerMP"

local function getPluginFolder()
  local info = type(debug) == "table" and debug.getinfo and debug.getinfo(1, "S")
  if type(info) ~= "table" or type(info.source) ~= "string" then return DEFAULT_PLUGIN_FOLDER end
  local source = info.source:gsub("^@", ""):gsub("\\", "/")
  return source:match("^(.*)/[^/]*$") or DEFAULT_PLUGIN_FOLDER
end

local pluginFolder = getPluginFolder()
package.path = pluginFolder .. "/?.lua;" .. package.path

local protocol = require("vracerMP/shared/protocol")
local log = require("vracerMP/util/serverLog").log
local ServerClock = require("vracerMP/util/serverClock")
local RaceRegistry = require("vracerMP/races/raceRegistry")
local ResultsAnnouncer = require("vracerMP/results/resultsAnnouncer")
local RaceCoordinator = require("vracerMP/coordinator/raceCoordinator")
local chatCommands = require("vracerMP/coordinator/chatCommands")
local serverNetwork = require("vracerMP/network/serverNetwork")
local playerDirectory = require("vracerMP/network/playerDirectory")

local logTag = "vracerMP"
local TICK_EVENT = "vracerMP_tick"
local TICK_INTERVAL_MS = 100
local CANCEL_CHAT_MESSAGE = 1

local coordinator = RaceCoordinator.new({
  registry = RaceRegistry.new(ServerClock.new()),
  network = serverNetwork,
  playerDirectory = playerDirectory,
  resultsAnnouncer = ResultsAnnouncer.new(serverNetwork),
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

function handleChatMessage(playerId, playerName, message)
  local reply = chatCommands.runCommand(coordinator, playerId, message)
  if not reply then return end
  MP.SendChatMessage(playerId, reply)
  return CANCEL_CHAT_MESSAGE
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
  MP.RegisterEvent(TICK_EVENT, "handleTick")
  MP.CreateEventTimer(TICK_EVENT, TICK_INTERVAL_MS)
end

registerClientEvents()
registerServerEvents()
log('I', logTag, "VRacerMP server loaded (protocol v" .. protocol.version .. ") from", pluginFolder)
