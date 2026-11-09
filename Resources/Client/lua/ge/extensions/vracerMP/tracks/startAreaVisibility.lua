-- VRacerMP client: which start areas show a marker (REG-13). Pure.
-- A marker means "you can register here": the track has no race yet, or its race still takes
-- registrations. Tracks with a race under way show nothing, and nothing shows while we race.

local M = {}

local REGISTERING_STATE = "registering"

local function isOpenForRegistration(track, lobbyStore)
  local lobby = lobbyStore:findLobbyForTrack(track.missionId)
  return lobby == nil or lobby.state == REGISTERING_STATE
end

local function getTracksOpenForRegistration(tracks, lobbyStore, isRacing)
  local openTracks = {}
  if isRacing then return openTracks end
  for _, track in ipairs(tracks) do
    if isOpenForRegistration(track, lobbyStore) then table.insert(openTracks, track) end
  end
  return openTracks
end

M.getTracksOpenForRegistration = getTracksOpenForRegistration

return M
