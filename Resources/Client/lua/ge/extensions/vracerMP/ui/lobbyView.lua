-- VRacerMP client: builds what the lobby app shows (REG-1 .. REG-6). Pure.

local LobbyStore = require("vracerMP/lobby/lobbyStore")

local M = {}

local HIDDEN = { visible = false }

local function buildRacerRows(lobby, myPlayerId)
  local rows = {}
  for index, racer in ipairs(lobby.racers or {}) do
    rows[index] = {
      position = index,
      name = racer.name,
      isOwner = racer.id == lobby.ownerId,
      isMe = racer.id == myPlayerId,
    }
  end
  return rows
end

local function getStatusText(lobby)
  if not lobby then return "No race yet. Register to create one." end
  if lobby.state ~= "registering" then return "Race in progress" end
  return "Waiting for the owner to start"
end

-- track: TrackInfo of the start area (or of our race). lobby: its lobby, or nil.
local function build(track, lobby, myPlayerId)
  if not track then return HIDDEN end
  local isRegistrationOpen = lobby == nil or lobby.state == "registering"
  local isRegistered = LobbyStore.isPlayerRegistered(lobby, myPlayerId)
  local isOwner = LobbyStore.isPlayerOwner(lobby, myPlayerId)
  return {
    visible = true,
    trackName = track.name,
    statusText = getStatusText(lobby),
    hasRace = lobby ~= nil,
    isRegistrationOpen = isRegistrationOpen,
    isRegistered = isRegistered,
    isOwner = isOwner,
    canRegister = isRegistrationOpen and not isRegistered,
    canEditSettings = isRegistrationOpen and isOwner,
    isClosedTrack = track.closed,
    laps = lobby and lobby.laps or track.defaultLaps,
    dnfTimeoutSeconds = lobby and lobby.dnfTimeoutSeconds or nil,
    racers = buildRacerRows(lobby or {}, myPlayerId),
  }
end

M.build = build
M.HIDDEN = HIDDEN

return M
