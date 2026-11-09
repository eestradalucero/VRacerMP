-- VRacerMP server: class GapTracker, time gaps between consecutive cars.
--
-- Every crossing has a progress number (1st pathnode crossed = 1, 2nd = 2, ... across laps).
-- When a car reaches progress N, the car directly ahead of it is the last car that reached
-- progress N before it. The gap is the difference of their race times at that point:
--   - the arriving car gets it as its red gap to the car ahead (UI-8);
--   - the car ahead gets it as its green gap to the car behind (UI-9).
-- This also works for lapped cars, because progress counts across laps.

local GapTracker = {}
GapTracker.__index = GapTracker

function GapTracker.new()
  local self = setmetatable({}, GapTracker)
  self.lastArrivalByProgress = {} -- progress -> { playerId, raceTimeMs }
  return self
end

-- Returns { aheadPlayerId, gapMs } when there is a car ahead, otherwise nil.
function GapTracker:recordCrossing(playerId, progress, raceTimeMs)
  local previousArrival = self.lastArrivalByProgress[progress]
  self.lastArrivalByProgress[progress] = { playerId = playerId, raceTimeMs = raceTimeMs }
  if not previousArrival then return nil end
  return {
    aheadPlayerId = previousArrival.playerId,
    gapMs = math.max(0, raceTimeMs - previousArrival.raceTimeMs),
  }
end

return GapTracker
