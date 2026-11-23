-- VRacerMP client: which tracks' start areas is the car in? Pure: plain positions.
-- Several tracks can share a start area (e.g. Hirochi Raceway); the player picks one (B-13).

local M = {}

local function getSquaredDistance(position, area)
  local dx, dy, dz = position.x - area.x, position.y - area.y, position.z - area.z
  return dx * dx + dy * dy + dz * dz
end

-- position = { x, y, z }. Returns every track whose start area contains the position,
-- closest start first (ties by name, so the order never flickers). Empty when none.
local function findTracksAtPosition(position, tracks)
  local found = {}
  for _, track in ipairs(tracks) do
    local area = track.startArea
    local squaredDistance = getSquaredDistance(position, area)
    if squaredDistance <= area.radius * area.radius then
      table.insert(found, { track = track, squaredDistance = squaredDistance })
    end
  end
  table.sort(found, function(a, b)
    if a.squaredDistance ~= b.squaredDistance then return a.squaredDistance < b.squaredDistance end
    return a.track.name < b.track.name
  end)
  local tracksHere = {}
  for index, entry in ipairs(found) do tracksHere[index] = entry.track end
  return tracksHere
end

M.findTracksAtPosition = findTracksAtPosition

return M
