-- VRacerMP server: class FakeRacer, a pretend opponent for testing alone (architecture A-7).
-- It "crosses" pathnodes at a steady pace with a small variation, so positions and gaps
-- can be tested with one real client. Added with the chat command `/vracer fake [lapSeconds]`.

local FakeRacer = {}
FakeRacer.__index = FakeRacer

local PACE_VARIATION = 0.04 -- +/- 4% per segment

function FakeRacer.new(playerId, lapTimeMs, pathnodeCount)
  local self = setmetatable({}, FakeRacer)
  self.playerId = playerId
  self.name = "Fake racer " .. tostring(-playerId)
  self.segmentTimeMs = lapTimeMs / pathnodeCount
  self.pathnodeCount = pathnodeCount
  self.crossingsSent = 0
  self.nextCrossingTimeMs = nil
  return self
end

-- The player record races use (see playerDirectory.buildPlayer).
function FakeRacer:buildPlayer()
  return {
    playerId = self.playerId,
    name = self.name,
    beammpId = nil,
    vehicle = { model = "fake", config = "fake" },
    isFake = true,
  }
end

-- Deterministic variation, so a test run can be repeated.
local function getSegmentDurationMs(self, crossingNumber)
  local variation = math.sin(crossingNumber * 1.7 + self.playerId) * PACE_VARIATION
  return math.floor(self.segmentTimeMs * (1 + variation))
end

-- Crossings due by `elapsedRaceMs`: list of { crossingNumber, raceTimeMs, lapCompleted }.
function FakeRacer:getDueCrossings(elapsedRaceMs)
  self.nextCrossingTimeMs = self.nextCrossingTimeMs or getSegmentDurationMs(self, 1)
  local dueCrossings = {}
  while self.nextCrossingTimeMs <= elapsedRaceMs do
    self.crossingsSent = self.crossingsSent + 1
    table.insert(dueCrossings, {
      crossingNumber = self.crossingsSent,
      raceTimeMs = self.nextCrossingTimeMs,
      lapCompleted = self.crossingsSent % self.pathnodeCount == 0,
    })
    self.nextCrossingTimeMs = self.nextCrossingTimeMs + getSegmentDurationMs(self, self.crossingsSent + 1)
  end
  return dueCrossings
end

return FakeRacer
