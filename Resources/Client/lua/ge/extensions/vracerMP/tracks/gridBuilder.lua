-- VRacerMP client: grid slots for a track (TRK-6). Pure: plain tables, no game calls.
--
-- Slots come from race-file start positions named "Start Position ...", in list order
-- (the same list also holds recovery points, which are skipped). When a track has fewer
-- slots than racers, extra slots are generated behind the last real one in 2 columns.
--
-- A slot is { pos = {x, y, z}, rot = {x, y, z, w} }. In BeamNG start positions the car's
-- front sits on `pos` and `rot * (0, 1, 0)` points in the driving direction.

local M = {}

local START_POSITION_PREFIX = "Start Position"
local ROW_SPACING_METERS = 8
local COLUMN_OFFSET_METERS = 2.5

local function rotateVector(rot, vector)
  local qx, qy, qz, qw = rot[1], rot[2], rot[3], rot[4]
  local vx, vy, vz = vector[1], vector[2], vector[3]
  -- t = 2 * cross(q.xyz, v)
  local tx = 2 * (qy * vz - qz * vy)
  local ty = 2 * (qz * vx - qx * vz)
  local tz = 2 * (qx * vy - qy * vx)
  -- v' = v + w * t + cross(q.xyz, t)
  return {
    vx + qw * tx + (qy * tz - qz * ty),
    vy + qw * ty + (qz * tx - qx * tz),
    vz + qw * tz + (qx * ty - qy * tx),
  }
end

local function isGridStartPosition(startPosition)
  local name = startPosition.name or ""
  return name:sub(1, #START_POSITION_PREFIX) == START_POSITION_PREFIX
end

local function copySlot(startPosition)
  local pos, rot = startPosition.pos, startPosition.rot
  return { pos = { pos[1], pos[2], pos[3] }, rot = { rot[1], rot[2], rot[3], rot[4] } }
end

local function getRealSlots(startPositions)
  local slots = {}
  for _, startPosition in ipairs(startPositions or {}) do
    if isGridStartPosition(startPosition) and startPosition.pos and startPosition.rot then
      table.insert(slots, copySlot(startPosition))
    end
  end
  return slots
end

-- generatedIndex is 0-based: 0 = left of row 1, 1 = right of row 1, 2 = left of row 2...
local function generateSlotBehind(originSlot, generatedIndex)
  local forward = rotateVector(originSlot.rot, { 0, 1, 0 })
  local side = rotateVector(originSlot.rot, { 1, 0, 0 })
  local rowsBack = math.floor(generatedIndex / 2) + 1
  local sideOffset = (generatedIndex % 2 == 0) and -COLUMN_OFFSET_METERS or COLUMN_OFFSET_METERS
  local origin = originSlot.pos
  local pos = {}
  for axis = 1, 3 do
    pos[axis] = origin[axis] - forward[axis] * ROW_SPACING_METERS * rowsBack + side[axis] * sideOffset
  end
  return { pos = pos, rot = { originSlot.rot[1], originSlot.rot[2], originSlot.rot[3], originSlot.rot[4] } }
end

-- Returns `slotCount` slots, or fewer if the track has no start position at all.
local function buildGridSlots(startPositions, slotCount)
  local slots = getRealSlots(startPositions)
  local originSlot = slots[#slots]
  if not originSlot then return slots end
  local generatedIndex = 0
  while #slots < slotCount do
    table.insert(slots, generateSlotBehind(originSlot, generatedIndex))
    generatedIndex = generatedIndex + 1
  end
  return slots
end

local function countRealSlots(startPositions)
  return #getRealSlots(startPositions)
end

M.rotateVector = rotateVector
M.buildGridSlots = buildGridSlots
M.countRealSlots = countRealSlots

return M
