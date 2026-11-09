-- VRacerMP client: which track's start area is the car in? Pure: plain positions.

local M = {}

local function getSquaredDistance(position, area)
  local dx, dy, dz = position.x - area.x, position.y - area.y, position.z - area.z
  return dx * dx + dy * dy + dz * dz
end

-- position = { x, y, z }. Returns the track whose start area contains the position
-- (the closest one if areas overlap), or nil.
local function findTrackAtPosition(position, tracks)
  local closestTrack, closestDistance = nil, math.huge
  for _, track in ipairs(tracks) do
    local area = track.startArea
    local squaredDistance = getSquaredDistance(position, area)
    if squaredDistance <= area.radius * area.radius and squaredDistance < closestDistance then
      closestTrack, closestDistance = track, squaredDistance
    end
  end
  return closestTrack
end

M.findTrackAtPosition = findTrackAtPosition

return M
