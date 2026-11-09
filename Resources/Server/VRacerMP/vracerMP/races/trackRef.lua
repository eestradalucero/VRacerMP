-- VRacerMP server: class TrackRef, what the server knows about a race track.
-- The track file itself lives on the clients; the registering client describes it.

local TrackRef = {}
TrackRef.__index = TrackRef

local function isNonEmptyString(value)
  return type(value) == "string" and value ~= ""
end

local function isPositiveNumber(value)
  return type(value) == "number" and value > 0
end

-- Returns a TrackRef, or nil and a reason when the client sent something unusable.
function TrackRef.fromClientData(data)
  if type(data) ~= "table" then return nil, "missing track data" end
  if not isNonEmptyString(data.missionId) then return nil, "missing missionId" end
  if not isNonEmptyString(data.level) then return nil, "missing level" end
  if not isPositiveNumber(data.pathnodeCount) then return nil, "track has no pathnodes" end

  local self = setmetatable({}, TrackRef)
  self.missionId = data.missionId
  self.level = data.level
  self.name = isNonEmptyString(data.name) and data.name or data.missionId
  self.closed = data.closed == true
  self.pathnodeCount = math.floor(data.pathnodeCount)
  self.defaultLaps = isPositiveNumber(data.defaultLaps) and math.floor(data.defaultLaps) or 1
  return self
end

-- Last folder of the missionId, e.g. "001-Circuito". Used in result file names.
function TrackRef:getMissionFolderName()
  return self.missionId:match("([^/]+)$") or self.missionId
end

function TrackRef:serialize()
  return {
    missionId = self.missionId,
    name = self.name,
    closed = self.closed,
    pathnodeCount = self.pathnodeCount,
  }
end

return TrackRef
