-- VRacerMP client: class StartAreaChoice, the track the player picked at a shared start
-- area (B-13). Pure.
--
-- When the car enters a start area, the choice starts on a track whose race still takes
-- registrations (so the next player joins it instead of opening another), else on the closest
-- track. The choice stays while that track is still here; the lobby's arrows step through the
-- tracks, which keep their closest-first order.

local StartAreaChoice = {}
StartAreaChoice.__index = StartAreaChoice

local REGISTERING_STATE = "registering"

function StartAreaChoice.new()
  local self = setmetatable({}, StartAreaChoice)
  self.tracksHere = {}
  self.chosenIndex = nil
  return self
end

local function findTrackIndex(tracks, missionId)
  for index, track in ipairs(tracks) do
    if track.missionId == missionId then return index end
  end
  return nil
end

local function hasOpenRace(track, lobbyStore)
  local lobby = lobbyStore:findLobbyForTrack(track.missionId)
  return lobby ~= nil and lobby.state == REGISTERING_STATE
end

-- The first track with a race open for registration, else the closest (the first).
local function findDefaultIndex(tracks, lobbyStore)
  for index, track in ipairs(tracks) do
    if hasOpenRace(track, lobbyStore) then return index end
  end
  return 1
end

local function getChosenMissionId(self)
  local chosen = self.chosenIndex and self.tracksHere[self.chosenIndex]
  return chosen and chosen.missionId or nil
end

-- tracksHere: startAreaWatcher.findTracksAtPosition(...), closest first.
function StartAreaChoice:update(tracksHere, lobbyStore)
  local keptIndex = findTrackIndex(tracksHere, getChosenMissionId(self))
  self.tracksHere = tracksHere
  if #tracksHere == 0 then
    self.chosenIndex = nil
  else
    self.chosenIndex = keptIndex or findDefaultIndex(tracksHere, lobbyStore)
  end
end

-- delta: +1 for the next track, -1 for the previous one; wraps around.
function StartAreaChoice:step(delta)
  local count = #self.tracksHere
  if count < 2 or not self.chosenIndex or type(delta) ~= "number" then return end
  self.chosenIndex = (self.chosenIndex - 1 + delta) % count + 1
end

function StartAreaChoice:getChosenTrack()
  return self.chosenIndex and self.tracksHere[self.chosenIndex] or nil
end

-- { index, count } of the chosen track, for "Track 2 of 4 here"; nil when not in a start area.
function StartAreaChoice:getPosition()
  if not self.chosenIndex then return nil end
  return { index = self.chosenIndex, count = #self.tracksHere }
end

return StartAreaChoice
