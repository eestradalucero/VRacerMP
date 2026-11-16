-- VRacerMP server: class Racer, one player in one race.
-- Times are integer milliseconds of race time (0 = GO).
-- "Raw" times are what the car drove; penalties are added to the lap they were given in and
-- to the total time.

local raceStates = require("vracerMP/shared/raceStates")
local timeFormat = require("vracerMP/shared/timeFormat")
local jsonEncoder = require("vracerMP/shared/jsonEncoder")

local racerStatus = raceStates.racerStatus

local Racer = {}
Racer.__index = Racer

-- player = { playerId, name, beammpId?, vehicle = { model }?, isFake? }
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
  self.penalties = {}            -- { raceTimeMs, lap, reason, penaltyMs, details }
  self.penaltyTimeMs = 0
  self.lapPenaltiesMs = {}       -- penalty time of each completed lap
  self.currentLapPenaltyMs = 0
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

-- 1-based lap the racer is driving now.
function Racer:getCurrentLap()
  return #self.lapTimesMs + 1
end

-- A penalty counts for the lap it was given in and for the total time.
function Racer:addPenalty(penalty)
  table.insert(self.penalties, penalty)
  self.penaltyTimeMs = self.penaltyTimeMs + penalty.penaltyMs
  self.currentLapPenaltyMs = self.currentLapPenaltyMs + penalty.penaltyMs
end

local function completeLap(self, raceTimeMs)
  local rawLapTimeMs = raceTimeMs - self.lastLapEndTimeMs
  table.insert(self.lapTimesMs, rawLapTimeMs + self.currentLapPenaltyMs)
  table.insert(self.lapPenaltiesMs, self.currentLapPenaltyMs)
  self.currentLapPenaltyMs = 0
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

-- Time the car drove: finish time for finished racers, last crossing otherwise.
function Racer:getRawTimeMs()
  return self.finishTimeMs or self.lastCrossingTimeMs
end

-- Raw time plus penalties: what final positions are ordered by.
function Racer:getTotalTimeMs()
  local rawTimeMs = self:getRawTimeMs()
  if not rawTimeMs then return nil end
  return rawTimeMs + self.penaltyTimeMs
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
  return self:getTotalTimeMs() - winnerTimeMs
end

local function serializePenalty(penalty)
  return {
    raceTime = penalty.raceTimeMs,
    lap = penalty.lap,
    reason = penalty.reason,
    penalty = penalty.penaltyMs,
    details = penalty.details,
  }
end

local function serializePenalties(penalties)
  local serialized = {}
  for index, penalty in ipairs(penalties) do serialized[index] = serializePenalty(penalty) end
  return jsonEncoder.markAsArray(serialized)
end

-- The `raceStats` object of the results schema (requirements §6). Times include penalties
-- except `rawTime`; `winnerTimeMs` is the winner's total time.
function Racer:serializeRaceStats(winnerTimeMs)
  local bestLapIndex = self:getBestLapIndex()
  local totalTimeMs = self:getTotalTimeMs()
  return {
    rawTime = orNull(self:getRawTimeMs()),
    penaltyTime = self.penaltyTimeMs,
    totalTime = orNull(totalTimeMs),
    totalTimeReadable = orNull(timeFormat.formatRaceTime(totalTimeMs)),
    lapTimes = jsonEncoder.markAsArray(copyList(self.lapTimesMs)),
    lapTimesReadable = jsonEncoder.markAsArray(getReadableLapTimes(self.lapTimesMs)),
    lapPenalties = jsonEncoder.markAsArray(copyList(self.lapPenaltiesMs)),
    bestLap = orNull(bestLapIndex and bestLapIndex - 1), -- 0-based in the file
    bestLapTime = orNull(self:getBestLapTimeMs()),
    gapToWinner = orNull(getGapToWinner(self, winnerTimeMs)),
    recoveries = self.recoveries,
    penalties = serializePenalties(self.penalties),
  }
end

function Racer:serialize(winnerTimeMs)
  return {
    name = self.name,
    id = self.playerId,
    beammpId = orNull(self.beammpId),
    vehicle = { model = orNull(self.vehicle.model) },
    gridSlot = orNull(self.gridSlot),
    status = self.status,
    dnfReason = orNull(self.dnfReason),
    position = orNull(self.position),
    raceStats = self:serializeRaceStats(winnerTimeMs),
  }
end

return Racer
