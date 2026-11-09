-- VRacerMP client: moves our vehicle onto its grid slot (START-1).
-- Uses BeamNG's start-position class so the car is placed exactly like in Time Trials
-- (front of the car on the slot). bCDDL: called, never copied.
-- Freezing on the grid (START-3) comes later.

local M = {}

local logTag = "vracerMP.grid"
local BEAMNG_START_POSITION_CLASS = "/lua/ge/extensions/gameplay/race/startPosition"

-- The start-position class only needs its owner for a unique id.
local placementOwner = { getNextUniqueIdentifier = function() return 0 end }

-- slot = { pos = {x, y, z}, rot = {x, y, z, w} } (see gridBuilder). Returns true on success.
local function moveVehicleToSlot(vehicleId, slot)
  if not slot then
    log('E', logTag, "no grid slot to move to")
    return false
  end
  local startPosition = require(BEAMNG_START_POSITION_CLASS)(placementOwner, "VRacerMP grid slot")
  startPosition:set(vec3(slot.pos[1], slot.pos[2], slot.pos[3]), quat(slot.rot[1], slot.rot[2], slot.rot[3], slot.rot[4]))
  local newPosition = startPosition:moveResetVehicleTo(vehicleId)
  return newPosition ~= nil
end

M.moveVehicleToSlot = moveVehicleToSlot

return M
