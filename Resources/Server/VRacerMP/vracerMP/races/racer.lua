-- VRacerMP server: class Racer, one player in one race.
-- Times are integer milliseconds of race time (0 = GO).

local raceStates = require("vracerMP/shared/raceStates")
local timeFormat = require("vracerMP/shared/timeFormat")
local jsonEncoder = require("vracerMP/shared/jsonEncoder")

local racerStatus = raceStates.racerStatus

local Racer = {}
Racer.__index = Racer

-- player = { playerId, name, beammpId?, vehicle = { model, config }?, isFake? }
function Racer.new(player, registrationOrder)
  local self = setmetatable({}, Racer)
  self.playerId = player.playerId
  self.name = player.name
  self.beammpId = player.beammpId
  self.vehicle = player.vehicle or {}
  self.isFake = player.isFake == true
  self.registrationOrder = registrationOrder
  self.gridSlot = nil
  self.isOnGrid = false
  self.status = racerStatus.registered
  self.dnfReason = nil
  self.position = nil
  self.crossingCount = 0
  self.lastCrossingTimeMs = nil
  self.lapTimesMs = {}
  self.lastLapEndTimeMs = 0
  self.finishTimeMs = nil
  self.recoveries = 0
  return self
end

function Racer:isRacing()
  return self.status == racerStatus.racing
end

function Racer:isFinished()
  return self.status == racerStatus.finished
end

function Racer:isDnf()
  return self.status == racerStatus.dnf
end

function Racer:hasLeftTheRace()
  return self:isFinished() or self:isDnf()
end

function Racer:getLapsCompleted()
  return #self.lapTimesMs
end

function Racer:startRacing()
  self.status = racerStatus.racing
end

function Racer:markDnf(reason)
  self.status = racerStatus.dnf
  self.dnfReason = reason
end

function Racer:addRecovery()
  self.recoveries = self.recoveries + 1
end

local function completeLap(self, raceTimeMs)
  table.insert(self.lapTimesMs, raceTimeMs - self.lastLapEndTimeMs)
  self.lastLapEndTimeMs = raceTimeMs
end

-- Records one pathnode crossing. Returns true when this crossing finished the race.
function Racer:recordCrossing(raceTimeMs, lapCompleted, totalLaps)
  self.crossingCount = self.crossingCount + 1
  self.lastCrossingTimeMs = raceTimeMs
  if lapCompleted then
    completeLap(self, raceTimeMs)
  end
  if self:getLapsCompleted() >= totalLaps then
    self.status = racerStatus.finished
    self.finishTimeMs = raceTimeMs
    return true
  end
  return false
end

-- 1-based index into lapTimesMs, or nil when no lap is complete.
function Racer:getBestLapIndex()
  local bestIndex = nil
  for index, lapTimeMs in ipairs(self.lapTimesMs) do
    if bestIndex == nil or lapTimeMs < self.lapTimesMs[bestIndex] then
      bestIndex = index
    end
  end
  return bestIndex
end

function Racer:getBestLapTimeMs()
  local bestIndex = self:getBestLapIndex()
  return bestIndex and self.lapTimesMs[bestIndex] or nil
end

-- Total time for finished racers; time of the last crossing otherwise.
function Racer:getTotalTimeMs()
  return self.finishTimeMs or self.lastCrossingTimeMs
end

local function getReadableLapTimes(lapTimesMs)
  local readable = {}
  for index, lapTimeMs in ipairs(lapTimesMs) do
    readable[index] = timeFormat.formatRaceTime(lapTimeMs)
  end
  return readable
end

local function copyList(list)
  local copy = {}
  for index, value in ipairs(list) do copy[index] = value end
  return copy
end

local function orNull(value)
  if value == nil then return jsonEncoder.null end
  return value
end

local function getGapToWinner(self, winnerTimeMs)
  if not self:isFinished() or not winnerTimeMs then return nil end
  return self.finishTimeMs - winnerTimeMs
end

-- The `raceStats` object of the results schema (requirements §6).
function Racer:serializeRaceStats(winnerTimeMs)
  local bestLapIndex = self:getBestLapIndex()
  local totalTimeMs = self:getTotalTimeMs()
  return {
    totalTime = orNull(totalTimeMs),
    totalTimeReadable = orNull(timeFormat.formatRaceTime(totalTimeMs)),
    lapTimes = jsonEncoder.markAsArray(copyList(self.lapTimesMs)),
    lapTimesReadable = jsonEncoder.markAsArray(getReadableLapTimes(self.lapTimesMs)),
    bestLap = orNull(bestLapIndex and bestLapIndex - 1), -- 0-based in the file
    bestLapTime = orNull(self:getBestLapTimeMs()),
    gapToWinner = orNull(getGapToWinner(self, winnerTimeMs)),
    recoveries = self.recoveries,
  }
end

function Racer:serialize(winnerTimeMs)
  return {
    name = self.name,
    id = self.playerId,
    beammpId = orNull(self.beammpId),
    vehicle = {
      model = orNull(self.vehicle.model),
      config = orNull(self.vehicle.config),
    },
    gridSlot = orNull(self.gridSlot),
    status = self.status,
    dnfReason = orNull(self.dnfReason),
    position = orNull(self.position),
    raceStats = self:serializeRaceStats(winnerTimeMs),
  }
end

return Racer
