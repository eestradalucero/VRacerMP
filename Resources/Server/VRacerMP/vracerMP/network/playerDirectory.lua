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

-- The player record races use: { playerId, name, beammpId, vehicle }.
local function buildPlayer(playerId, vehicle)
  return {
    playerId = playerId,
    name = getPlayerName(playerId),
    beammpId = getBeammpId(playerId),
    vehicle = vehicle,
  }
end

M.getPlayerName = getPlayerName
M.buildPlayer = buildPlayer

return M
