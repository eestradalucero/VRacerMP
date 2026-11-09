-- VRacerMP client: what each UI button does (UI -> Lua, architecture §6.1).
-- The apps call vracerMP_main.handleUiAction({ action = "...", ... }).

local protocol = require("vracerMP/shared/protocol")
local clientNetwork = require("vracerMP/network/clientNetwork")
local playerVehicle = require("vracerMP/race/playerVehicle")

local M = {}

local logTag = "vracerMP.ui"
local toServer = protocol.toServer

local function register(controller)
  local track = controller.panelTrack
  if not track then return end
  clientNetwork.send(toServer.register, { track = track:serializeForServer(), vehicle = playerVehicle.getDescription() })
end

local function unregister(controller)
  local lobby = controller.panelLobby
  if lobby then clientNetwork.send(toServer.unregister, { raceId = lobby.raceId }) end
end

-- Retire from the race we are in: the server makes us DNF (FIN-8).
local function retire(controller)
  local session = controller.session
  if session then clientNetwork.send(toServer.unregister, { raceId = session.raceId }) end
end

local function startRace(controller)
  local lobby = controller.panelLobby
  if lobby then clientNetwork.send(toServer.startRace, { raceId = lobby.raceId }) end
end

-- The server validates the new value and broadcasts the updated lobby.
local function sendSettingChange(controller, settingName, delta)
  local lobby = controller.panelLobby
  if not lobby or type(delta) ~= "number" then return end
  local current = lobby[settingName]
  if type(current) ~= "number" then return end
  clientNetwork.send(toServer.configure, { raceId = lobby.raceId, [settingName] = current + delta })
end

local function changeLaps(controller, action)
  sendSettingChange(controller, "laps", action.delta)
end

local function changeDnfTimeout(controller, action)
  sendSettingChange(controller, "dnfTimeoutSeconds", action.delta)
end

local function closeResults(controller)
  controller:closeResults()
end

-- An app appeared and wants the current state.
local function refresh(controller)
  controller:resendUi()
end

local handlers = {
  register = register,
  unregister = unregister,
  startRace = startRace,
  retire = retire,
  changeLaps = changeLaps,
  changeDnfTimeout = changeDnfTimeout,
  closeResults = closeResults,
  refresh = refresh,
}

local function handle(controller, action)
  local handler = type(action) == "table" and handlers[action.action] or nil
  if not handler then
    log('W', logTag, "unknown UI action " .. tostring(type(action) == "table" and action.action or action))
    return
  end
  handler(controller, action)
end

M.handle = handle

return M
