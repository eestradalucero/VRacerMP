-- VRacerMP client: sending to and listening for the server (edge: BeamMP client API).

local M = {}

local logTag = "vracerMP.network"

local function isConnectedToBeamMP()
  return type(TriggerServerEvent) == "function"
end

local function send(eventName, payload)
  if not isConnectedToBeamMP() then
    log('W', logTag, "not on a BeamMP server, cannot send " .. eventName)
    return
  end
  TriggerServerEvent(eventName, jsonEncode(payload or {}))
end

local function decodePayload(eventName, rawData)
  local decoded, payload = pcall(jsonDecode, rawData or "{}")
  if not decoded or type(payload) ~= "table" then
    log('W', logTag, "ignored invalid payload for " .. eventName)
    return nil
  end
  return payload
end

-- handler(payload) is called with the decoded table.
local function listen(eventName, handler)
  if type(AddEventHandler) ~= "function" then return end
  AddEventHandler(eventName, function(rawData)
    local payload = decodePayload(eventName, rawData)
    if payload then handler(payload) end
  end)
end

-- This client's BeamMP player ID, or -1 when not connected.
local function getMyPlayerId()
  if MPConfig and MPConfig.getPlayerServerID then
    return tonumber(MPConfig.getPlayerServerID()) or -1
  end
  return -1
end

M.isConnectedToBeamMP = isConnectedToBeamMP
M.send = send
M.listen = listen
M.getMyPlayerId = getMyPlayerId

return M
