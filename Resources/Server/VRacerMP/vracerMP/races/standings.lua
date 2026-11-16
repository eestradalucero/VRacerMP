-- VRacerMP server: race positions. Pure functions, no state.
--
-- Order:
--   1. finished racers, by finish time (live: raw time; final results: total time including
--      penalties);
--   2. racers still racing, by progress (pathnode crossings), then by who got there first;
--   3. DNF racers, by progress.
-- Ties fall back to grid slot / registration order so the order is stable.

local M = {}

local GROUP_FINISHED = 1
local GROUP_RACING = 2
local GROUP_DNF = 3

local function getGroup(racer)
  if racer:isFinished() then return GROUP_FINISHED end
  if racer:isDnf() then return GROUP_DNF end
  return GROUP_RACING
end

local function compareByTieBreak(a, b)
  local slotA = a.gridSlot or a.registrationOrder
  local slotB = b.gridSlot or b.registrationOrder
  return slotA < slotB
end

local function compareByProgress(a, b)
  if a.crossingCount ~= b.crossingCount then
    return a.crossingCount > b.crossingCount
  end
  local timeA = a.lastCrossingTimeMs or math.huge
  local timeB = b.lastCrossingTimeMs or math.huge
  if timeA ~= timeB then return timeA < timeB end
  return compareByTieBreak(a, b)
end

local function getFinishTimeMs(racer, includePenalties)
  if includePenalties then return racer:getTotalTimeMs() end
  return racer.finishTimeMs
end

local function newComparer(includePenalties)
  return function(a, b)
    local groupA, groupB = getGroup(a), getGroup(b)
    if groupA ~= groupB then return groupA < groupB end
    if groupA == GROUP_FINISHED then
      local timeA, timeB = getFinishTimeMs(a, includePenalties), getFinishTimeMs(b, includePenalties)
      if timeA ~= timeB then return timeA < timeB end
    end
    return compareByProgress(a, b)
  end
end

-- Returns a new list of racers in race order. Does not modify the input.
-- includePenalties: order finished racers by total time (final results) instead of raw time.
local function getOrderedRacers(racers, includePenalties)
  local ordered = {}
  for index, racer in ipairs(racers) do ordered[index] = racer end
  table.sort(ordered, newComparer(includePenalties == true))
  return ordered
end

-- Sorts and writes `racer.position` (1-based). Returns the ordered list.
local function assignPositions(racers, includePenalties)
  local ordered = getOrderedRacers(racers, includePenalties)
  for position, racer in ipairs(ordered) do
    racer.position = position
  end
  return ordered
end

M.getOrderedRacers = getOrderedRacers
M.assignPositions = assignPositions

return M
