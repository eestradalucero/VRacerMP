-- VRacerMP server: information about connected players (edge: uses MP.*).

local M = {}

local function getPlayerName(playerId)
  return MP.GetPlayerName(playerId) or ("Player " .. tostring(playerId))
end

-- The permanent BeamMP account ID, or nil for guests.
local function getBeammpId(playerId)
  local identifiers = MP.GetPlayerIdentifiers(playerId)
  if type(identifiers) ~= "table" then return nil end
  return identifiers.beammp
end

local MAX_MODEL_NAME_LENGTH = 64

-- Only the model name is kept, short. Older clients also sent the vehicle config, which can
-- be a whole serialized setup and made every race message huge.
local function readVehicleModel(vehicle)
  local model = type(vehicle) == "table" and vehicle.model or nil
  if type(model) ~= "string" then return nil end
  return model:sub(1, MAX_MODEL_NAME_LENGTH)
end

-- { model } from what a client sent, or nil when it sent no model.
local function readVehicle(vehicle)
  local model = readVehicleModel(vehicle)
  if not model then return nil end
  return { model = model }
end

-- The player record races use: { playerId, name, beammpId, vehicle = { model } }.
local function buildPlayer(playerId, vehicle)
  return {
    playerId = playerId,
    name = getPlayerName(playerId),
    beammpId = getBeammpId(playerId),
    vehicle = readVehicle(vehicle) or {},
  }
end

-- IDs of the connected players with this name, ignoring case (two players may share one).
local function findPlayerIdsByName(name)
  local playerIds = {}
  local wantedName = tostring(name):lower()
  for playerId, playerName in pairs(MP.GetPlayers() or {}) do
    if tostring(playerName):lower() == wantedName then table.insert(playerIds, playerId) end
  end
  table.sort(playerIds)
  return playerIds
end

-- IDs of every connected player, in order.
local function getConnectedPlayerIds()
  local playerIds = {}
  for playerId in pairs(MP.GetPlayers() or {}) do table.insert(playerIds, playerId) end
  table.sort(playerIds)
  return playerIds
end

M.getPlayerName = getPlayerName
M.getConnectedPlayerIds = getConnectedPlayerIds
M.buildPlayer = buildPlayer
M.readVehicle = readVehicle
M.findPlayerIdsByName = findPlayerIdsByName

return M
