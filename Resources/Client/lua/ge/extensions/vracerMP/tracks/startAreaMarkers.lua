-- VRacerMP client: the only file that touches BeamNG's mission marker
-- (gameplay/markers/missionMarker, bCDDL: called, never copied). Shows "register here" at the
-- start areas chosen by startAreaVisibility (REG-13), with the same icon as BeamNG's Time Trials.
--
-- BeamNG only drives mission markers in freeroam and career; BeamMP runs as "multiplayer",
-- so we create the markers and feed them each frame the data BeamNG's markerInteraction would.
-- If that internal API ever fails, we fall back to a simple light column with the track name.

local StartAreaMarkers = {}
StartAreaMarkers.__index = StartAreaMarkers

local logTag = "vracerMP.startAreaMarkers"
local MISSION_MARKER_MODULE = "lua/ge/extensions/gameplay/markers/missionMarker"
local MISSION_ICON = "mission_primary_triangle" -- BeamNG's default mission icon, used by Time Trials
local ICON_RENDERER_NAME = "markerIconRenderer" -- created by gameplay_playmodeMarkers

local COLUMN_HEIGHT = 25
local COLUMN_RADIUS = 0.6
local COLUMN_SHOW_DISTANCE = 300
local COLUMN_COLOR = ColorF(0.28, 0.49, 0.98, 0.35) -- BeamNG mission blue
local LABEL_COLOR = ColorF(1, 1, 1, 1)
local LABEL_BACKGROUND = ColorI(0, 0, 0, 192)

function StartAreaMarkers.new()
  local self = setmetatable({}, StartAreaMarkers)
  self.markersByMissionId = {}
  self.useColumns = false
  self.frameData = { bbCenter = vec3(), bbHalfAxis0 = vec3(), bbHalfAxis1 = vec3(), bbHalfAxis2 = vec3(),
                     vehPos = vec3(), camPos = vec3() }
  self.decals = {}
  return self
end

-- Mission markers -----------------------------------------------------------------------

local function getAreaPosition(track)
  local area = track.startArea
  return vec3(area.x, area.y, area.z)
end

local function createMissionMarker(track)
  if not gameplay_playmodeMarkers then extensions.load("gameplay_playmodeMarkers") end
  local marker = require(MISSION_MARKER_MODULE).create()
  marker:createObjects()
  marker:setup({ id = "vracerMP#" .. track.missionId, pos = getAreaPosition(track), icon = MISSION_ICON,
                 elemData = {}, focus = false })
  return marker
end

local function getOrCreateMarker(self, track)
  local marker = self.markersByMissionId[track.missionId]
  if not marker then
    marker = createMissionMarker(track)
    self.markersByMissionId[track.missionId] = marker
  end
  return marker
end

local function readVehicleBox(frameData, vehicle)
  local vehicleId = vehicle:getID()
  frameData.vehPos:set(vehicle:getPositionXYZ())
  frameData.bbCenter:set(be:getObjectOOBBCenterXYZ(vehicleId))
  frameData.bbHalfAxis0:set(be:getObjectOOBBHalfAxisXYZ(vehicleId, 0))
  frameData.bbHalfAxis1:set(be:getObjectOOBBHalfAxisXYZ(vehicleId, 1))
  frameData.bbHalfAxis2:set(be:getObjectOOBBHalfAxisXYZ(vehicleId, 2))
  frameData.highestBBPointZ = frameData.bbCenter.z + math.abs(frameData.bbHalfAxis0.z)
    + math.abs(frameData.bbHalfAxis1.z) + math.abs(frameData.bbHalfAxis2.z)
end

-- The fields missionMarker:update reads, as BeamNG's markerInteraction fills them.
local function buildFrameData(frameData, dt)
  local vehicle = be:getPlayerVehicle(0)
  frameData.camPos:set(core_camera.getPositionXYZ())
  frameData.veh = vehicle
  if vehicle then readVehicleBox(frameData, vehicle) end
  frameData.playerPosition = vehicle and frameData.vehPos or frameData.camPos
  frameData.dt = dt
  frameData.globalAlpha = 1
  frameData.cruisingSpeedFactor = 1
  frameData.isWalking = false
  frameData.bigMapActive = freeroam_bigMapMode ~= nil and freeroam_bigMapMode.bigMapActive() or false
  return frameData
end

local function collectDecals(marker, decals, decalCount)
  for _, decal in ipairs(marker.groundDecalData or {}) do
    decalCount = decalCount + 1
    decals[decalCount] = decal
  end
  return decalCount
end

local function hideMarkersNotShown(self, shownMissionIds)
  for missionId, marker in pairs(self.markersByMissionId) do
    if not shownMissionIds[missionId] then marker:hide() end
  end
end

local function renderMissionMarkers(self, tracks, dt)
  local shownMissionIds, decalCount = {}, 0
  if #tracks == 0 then return hideMarkersNotShown(self, shownMissionIds) end
  local frameData = buildFrameData(self.frameData, dt)
  for _, track in ipairs(tracks) do
    local marker = getOrCreateMarker(self, track)
    shownMissionIds[track.missionId] = true
    marker:show()
    marker:update(frameData)
    decalCount = collectDecals(marker, self.decals, decalCount)
  end
  hideMarkersNotShown(self, shownMissionIds)
  if decalCount > 0 then Engine.Render.DynamicDecalMgr.addDecals(self.decals, decalCount) end
end

-- Fallback columns ----------------------------------------------------------------------

local function drawColumn(track, cameraPosition)
  local bottom = getAreaPosition(track)
  if bottom:distance(cameraPosition) > COLUMN_SHOW_DISTANCE then return end
  local top = bottom + vec3(0, 0, COLUMN_HEIGHT)
  debugDrawer:drawCylinder(bottom, top, COLUMN_RADIUS, COLUMN_COLOR)
  debugDrawer:drawTextAdvanced(top, String(track.name .. " - register here"), LABEL_COLOR, true, false, LABEL_BACKGROUND)
end

local function renderColumns(tracks)
  local cameraPosition = core_camera.getPosition()
  for _, track in ipairs(tracks) do drawColumn(track, cameraPosition) end
end

-- Public --------------------------------------------------------------------------------

-- Removes our icons. Skipped when BeamNG already deleted the icon renderer (level unload),
-- because asking for it would create a new one.
function StartAreaMarkers:clear()
  local rendererExists = scenetree.findObject(ICON_RENDERER_NAME) ~= nil
  for _, marker in pairs(self.markersByMissionId) do
    if rendererExists then marker:clearObjects() end
  end
  self.markersByMissionId = {}
end

local function switchToColumns(self, problem)
  log('W', logTag, "BeamNG mission marker unavailable, showing columns instead: " .. tostring(problem))
  pcall(self.clear, self)
  self.useColumns = true
end

-- tracks: the start areas to mark this frame (startAreaVisibility); every other marker hides.
function StartAreaMarkers:render(tracks, dt)
  if self.useColumns then return renderColumns(tracks) end
  local rendered, problem = pcall(renderMissionMarkers, self, tracks, dt)
  if not rendered then switchToColumns(self, problem) end
end

return StartAreaMarkers
