-- VRacerMP server: class LapRecords, the fastest laps since the server started (B-8). Pure.
--
-- Kept in memory only: a restart clears them, and no files are written. Records are stored per
-- track and per vehicle model, so a per-vehicle list later is only a display change; for now
-- the record shown is each track's fastest lap of any vehicle. All laps count, penalty laps
-- included (their lap time already contains the penalty).

local LapRecords = {}
LapRecords.__index = LapRecords

function LapRecords.new()
  local self = setmetatable({}, LapRecords)
  self.trackRecords = {}   -- missionId -> record
  self.vehicleRecords = {} -- missionId -> model -> record
  return self
end

local function isFaster(lapTimeMs, record)
  return record == nil or lapTimeMs < record.lapTimeMs
end

local function saveVehicleRecord(self, record)
  local recordsOfTrack = self.vehicleRecords[record.missionId] or {}
  self.vehicleRecords[record.missionId] = recordsOfTrack
  if isFaster(record.lapTimeMs, recordsOfTrack[record.model]) then
    recordsOfTrack[record.model] = record
  end
end

-- lap = { missionId, trackName, lapTimeMs, name, model }.
-- Returns true when the lap is a new record for the track.
function LapRecords:recordLap(lap)
  local record = {
    missionId = lap.missionId,
    trackName = lap.trackName,
    lapTimeMs = lap.lapTimeMs,
    name = lap.name,
    model = lap.model or "unknown",
  }
  saveVehicleRecord(self, record)
  if not isFaster(record.lapTimeMs, self.trackRecords[record.missionId]) then return false end
  self.trackRecords[record.missionId] = record
  return true
end

function LapRecords:getTrackRecord(missionId)
  return self.trackRecords[missionId]
end

function LapRecords:getVehicleRecord(missionId, model)
  local recordsOfTrack = self.vehicleRecords[missionId]
  return recordsOfTrack and recordsOfTrack[model] or nil
end

-- Every track's record, for a player who just joined.
function LapRecords:getAllTrackRecords()
  local records = {}
  for _, record in pairs(self.trackRecords) do table.insert(records, record) end
  return records
end

return LapRecords
