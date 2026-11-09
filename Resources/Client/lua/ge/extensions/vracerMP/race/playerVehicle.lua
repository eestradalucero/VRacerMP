-- VRacerMP client: the vehicle the player is driving (edge: BeamNG vehicle API).

local M = {}

local NO_VEHICLE = -1

local function getVehicle()
  return be:getPlayerVehicle(0)
end

-- Returns the vehicle id, or nil when the player has no vehicle.
local function getVehicleId()
  local vehicleId = be:getPlayerVehicleID(0)
  if not vehicleId or vehicleId == NO_VEHICLE then return nil end
  return vehicleId
end

-- Returns { x, y, z } or nil.
local function getPosition()
  local vehicle = getVehicle()
  if not vehicle then return nil end
  local position = vehicle:getPosition()
  return { x = position.x, y = position.y, z = position.z }
end

-- "vehicles/etk800/856_m.pc" -> "856_m"
local function getConfigName(partConfig)
  if type(partConfig) ~= "string" then return nil end
  return partConfig:match("([^/\\]+)%.pc$") or partConfig
end

-- { model, config } for the race results (racers keep their own vehicle, START-1).
local function getDescription()
  local vehicle = getVehicle()
  if not vehicle then return {} end
  return { model = vehicle:getJBeamFilename(), config = getConfigName(vehicle.partConfig) }
end

M.getVehicleId = getVehicleId
M.getPosition = getPosition
M.getDescription = getDescription

return M
