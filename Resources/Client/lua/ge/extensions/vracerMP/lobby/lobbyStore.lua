-- VRacerMP client: class LobbyStore, the latest lobby state of every race the server announced.
-- Pure: fed by network messages, read by the UI.

local raceStates = require("vracerMP/shared/raceStates")

local LobbyStore = {}
LobbyStore.__index = LobbyStore

function LobbyStore.new()
  local self = setmetatable({}, LobbyStore)
  self.lobbiesByRaceId = {}
  return self
end

function LobbyStore:saveLobby(lobby)
  self.lobbiesByRaceId[lobby.raceId] = lobby
end

function LobbyStore:removeLobby(raceId)
  self.lobbiesByRaceId[raceId] = nil
end

function LobbyStore:clear()
  self.lobbiesByRaceId = {}
end

-- The open (registering) lobby for a track, or any lobby on it if none is open.
function LobbyStore:findLobbyForTrack(missionId)
  local anyLobby = nil
  for _, lobby in pairs(self.lobbiesByRaceId) do
    if lobby.missionId == missionId then
      if lobby.state == "registering" then return lobby end
      anyLobby = lobby
    end
  end
  return anyLobby
end

-- Registered, or racing; not once they finished or retired.
local function isStillInRace(lobby, playerId)
  for _, racer in ipairs(lobby.racers or {}) do
    if racer.id == playerId then
      return racer.status ~= raceStates.racerStatus.finished and racer.status ~= raceStates.racerStatus.dnf
    end
  end
  return false
end

-- The race the player is still in; after finishing or retiring they are free again (REG-12).
function LobbyStore:findLobbyOfPlayer(playerId)
  for _, lobby in pairs(self.lobbiesByRaceId) do
    if isStillInRace(lobby, playerId) then return lobby end
  end
  return nil
end

function LobbyStore.isPlayerRegistered(lobby, playerId)
  return lobby ~= nil and isStillInRace(lobby, playerId)
end

function LobbyStore.isPlayerOwner(lobby, playerId)
  return lobby ~= nil and lobby.ownerId == playerId
end

return LobbyStore
