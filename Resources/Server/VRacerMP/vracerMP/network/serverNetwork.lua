-- VRacerMP server: sending and decoding network messages (edge: uses MP.* and Util.*).
-- Fake racers have negative player IDs and never receive messages.

local jsonEncoder = require("vracerMP/shared/jsonEncoder")
local log = require("vracerMP/util/serverLog").log

local logTag = "vracerMP.network"
local BROADCAST = -1

local M = {}

local function isRealPlayer(playerId)
  return type(playerId) == "number" and playerId >= 0
end

local function sendToPlayer(playerId, eventName, payload)
  if not isRealPlayer(playerId) then return end
  local sent, errorMessage = MP.TriggerClientEvent(playerId, eventName, jsonEncoder.encode(payload or {}))
  if sent == false then
    log('W', logTag, "could not send", eventName, "to player", playerId, errorMessage or "")
  end
end

local function sendToPlayers(playerIds, eventName, payload)
  local encoded = jsonEncoder.encode(payload or {})
  for _, playerId in ipairs(playerIds) do
    if isRealPlayer(playerId) then
      MP.TriggerClientEvent(playerId, eventName, encoded)
    end
  end
end

local function broadcast(eventName, payload)
  MP.TriggerClientEvent(BROADCAST, eventName, jsonEncoder.encode(payload or {}))
end

-- A chat message every player sees.
local function broadcastChat(text)
  MP.SendChatMessage(BROADCAST, text)
end

-- Returns the decoded table, or nil when the client sent invalid JSON.
local function decodePayload(rawData)
  if type(rawData) ~= "string" or rawData == "" then return {} end
  local ok, decoded = pcall(Util.JsonDecode, rawData)
  if not ok or type(decoded) ~= "table" then
    log('W', logTag, "ignored invalid JSON payload")
    return nil
  end
  return decoded
end

M.sendToPlayer = sendToPlayer
M.sendToPlayers = sendToPlayers
M.broadcast = broadcast
M.broadcastChat = broadcastChat
M.decodePayload = decodePayload

return M
