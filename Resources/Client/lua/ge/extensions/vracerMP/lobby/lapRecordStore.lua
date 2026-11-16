-- VRacerMP client: class LapRecordStore, each track's server lap record (B-8). Pure: fed by
-- the server's lapRecord messages, read by the lobby view.

local LapRecordStore = {}
LapRecordStore.__index = LapRecordStore

function LapRecordStore.new()
  local self = setmetatable({}, LapRecordStore)
  self.recordsByMissionId = {}
  return self
end

-- record = { missionId, trackName, lapTimeMs, name, model }
function LapRecordStore:saveRecord(record)
  self.recordsByMissionId[record.missionId] = record
end

function LapRecordStore:findRecord(missionId)
  return self.recordsByMissionId[missionId]
end

function LapRecordStore:clear()
  self.recordsByMissionId = {}
end

return LapRecordStore
