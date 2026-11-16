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

-- The player record races use: { playerId, name, beammpId, vehicle = { model } }.
local function buildPlayer(playerId, vehicle)
  return {
    playerId = playerId,
    name = getPlayerName(playerId),
    beammpId = getBeammpId(playerId),
    vehicle = { model = readVehicleModel(vehicle) },
  }
end

M.getPlayerName = getPlayerName
M.buildPlayer = buildPlayer

return M
