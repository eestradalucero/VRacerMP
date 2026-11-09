-- VRacerMP client: class TrackInfo, one race track read from a time-trial mission folder
-- (`info.json` + `race.race.json`). Pure: takes already-decoded JSON tables.

local gridBuilder = require("vracerMP/tracks/gridBuilder")

local TrackInfo = {}
TrackInfo.__index = TrackInfo

local MISSIONS_ROOT = "/gameplay/missions/"

-- "/gameplay/missions/vracer_bajasur/timeTrial/001-Circuito/" -> "vracer_bajasur/timeTrial/001-Circuito"
local function getMissionId(missionFolder)
  local relative = missionFolder:gsub("\\", "/"):gsub("^.-" .. MISSIONS_ROOT:gsub("%p", "%%%0"), "")
  return (relative:gsub("/+$", ""))
end

local function findPathnodeByOldId(pathnodes, oldId)
  for _, pathnode in ipairs(pathnodes) do
    if pathnode.oldId == oldId then return pathnode end
  end
  return nil
end

local function isVisible(pathnode)
  return pathnode.visible ~= false
end

-- Pathnode crossings per lap, as reported by BeamNG's race engine: every visible pathnode.
-- On point-to-point tracks the car starts at the start pathnode, so it is not crossed.
local function countCrossingsPerLap(raceData, isClosed)
  local pathnodes = raceData.pathnodes or {}
  local visibleCount = 0
  for _, pathnode in ipairs(pathnodes) do
    if isVisible(pathnode) then visibleCount = visibleCount + 1 end
  end
  local startPathnode = findPathnodeByOldId(pathnodes, raceData.startNode)
  if not isClosed and startPathnode and isVisible(startPathnode) then
    visibleCount = visibleCount - 1
  end
  return visibleCount
end

local function readStartArea(info)
  local trigger = info.startTrigger or {}
  local pos = trigger.pos or { 0, 0, 0 }
  return { x = pos[1], y = pos[2], z = pos[3], radius = trigger.radius or 10 }
end

local function readDefaultLaps(info, raceData, isClosed)
  if not isClosed then return 1 end
  local missionTypeData = info.missionTypeData or {}
  return raceData.defaultLaps or missionTypeData.defaultLaps or 1
end

-- missionFolder: the folder holding info.json, e.g. "/gameplay/missions/<level>/timeTrial/<mission>/"
function TrackInfo.fromMissionFiles(missionFolder, info, raceData)
  local self = setmetatable({}, TrackInfo)
  local classification = raceData.classification or {}
  self.missionId = getMissionId(missionFolder)
  self.raceFilePath = (missionFolder:gsub("/+$", "")) .. "/race.race.json"
  self.level = (info.startTrigger and info.startTrigger.level) or self.missionId:match("^[^/]+")
  self.name = raceData.name or info.name or self.missionId
  self.closed = classification.closed == true
  self.branching = classification.branching == true
  self.defaultLaps = readDefaultLaps(info, raceData, self.closed)
  self.pathnodeCount = countCrossingsPerLap(raceData, self.closed)
  self.startArea = readStartArea(info)
  self.startPositions = raceData.startPositions or {}
  return self
end

-- Branching tracks are not supported (TRK-7); tracks need pathnodes and a start position.
function TrackInfo:isRaceable()
  return not self.branching and self.pathnodeCount > 0 and gridBuilder.countRealSlots(self.startPositions) > 0
end

function TrackInfo:getGridSlot(slotNumber)
  return gridBuilder.buildGridSlots(self.startPositions, slotNumber)[slotNumber]
end

-- What the server needs to know (server TrackRef.fromClientData).
function TrackInfo:serializeForServer()
  return {
    missionId = self.missionId,
    level = self.level,
    name = self.name,
    closed = self.closed,
    pathnodeCount = self.pathnodeCount,
    defaultLaps = self.defaultLaps,
  }
end

return TrackInfo
