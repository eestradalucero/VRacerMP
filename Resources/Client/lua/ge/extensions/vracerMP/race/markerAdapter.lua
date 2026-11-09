-- VRacerMP client: the only file that touches BeamNG's race markers
-- (scenario/race_marker + scenario/raceMarkers/sideColumnMarker, bCDDL: called, never copied).
--
-- Two-pillar markers like single-player Time Trials (VIS-1): orange for the next
-- pathnode, grey for the few after it, the rest hidden. We create "detached" markers so we
-- own their list.

local raceMarker = require("scenario/race_marker")

local PathnodeMarkers = {}
PathnodeMarkers.__index = PathnodeMarkers

local MODE_NEXT = "default"  -- BeamNG mode we recolour orange
local MODE_OTHER = "next"    -- BeamNG mode we recolour grey
local MODE_HIDDEN = "hidden"
local ORANGE = { 1, 0.45, 0 }
local GREY = { 0.55, 0.55, 0.55 }
local WHITE = { 1, 1, 1 }

local function applyOurColours(marker)
  if not marker.modeInfos then return end
  marker.modeInfos[MODE_NEXT] = { color = ORANGE, baseColor = WHITE }
  marker.modeInfos[MODE_OTHER] = { color = GREY, baseColor = GREY }
end

local function createMarker(pathnode)
  local marker = raceMarker.createRaceMarker(true)
  applyOurColours(marker)
  marker:setToCheckpoint({
    name = pathnode.name,
    pos = pathnode.pos,
    radius = pathnode.radius,
    normal = pathnode.normal,
  })
  return marker
end

-- pathnodes: list of { id, name, pos, radius, normal } (see RaceEngine:getVisiblePathnodes).
function PathnodeMarkers.new(pathnodes)
  local self = setmetatable({}, PathnodeMarkers)
  self.markersById = {}
  for _, pathnode in ipairs(pathnodes) do
    self.markersById[pathnode.id] = createMarker(pathnode)
  end
  return self
end

local function getModeByPathnodeId(upcomingIds)
  local modes = {}
  for index, id in ipairs(upcomingIds) do
    modes[id] = index == 1 and MODE_NEXT or MODE_OTHER
  end
  return modes
end

-- upcomingIds: pathnode ids in driving order. The first is shown orange, the rest grey,
-- every other marker is hidden so the map stays readable.
function PathnodeMarkers:showUpcoming(upcomingIds)
  local modes = getModeByPathnodeId(upcomingIds)
  for id, marker in pairs(self.markersById) do
    marker:setMode(modes[id] or MODE_HIDDEN)
  end
end

function PathnodeMarkers:render(dt, dtSim)
  for _, marker in pairs(self.markersById) do
    marker:update(dt, dtSim)
  end
end

function PathnodeMarkers:remove()
  for _, marker in pairs(self.markersById) do
    marker:clearMarkers()
  end
  self.markersById = {}
end

return PathnodeMarkers
