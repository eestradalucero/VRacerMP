local t = require("tests/testRunner")
local LobbyStore = require("vracerMP/lobby/lobbyStore")
local startAreaVisibility = require("vracerMP/tracks/startAreaVisibility")

local function newLobby(raceId, state, racerIds)
  local racers = {}
  for index, id in ipairs(racerIds) do racers[index] = { id = id, name = "P" .. id } end
  return { raceId = raceId, missionId = "level/timeTrial/a", state = state, ownerId = racerIds[1], racers = racers }
end

t.test("prefers the open lobby of a track", function()
  local store = LobbyStore.new()
  store:saveLobby(newLobby("r-1", "running", { 1 }))
  store:saveLobby(newLobby("r-2", "registering", { 2 }))
  t.assertEquals(store:findLobbyForTrack("level/timeTrial/a").raceId, "r-2")
end)

t.test("finds the player's lobby and ownership", function()
  local store = LobbyStore.new()
  store:saveLobby(newLobby("r-1", "registering", { 4, 7 }))
  local lobby = store:findLobbyOfPlayer(7)
  t.assertEquals(lobby.raceId, "r-1")
  t.assertTrue(LobbyStore.isPlayerRegistered(lobby, 7))
  t.assertEquals(LobbyStore.isPlayerOwner(lobby, 7), false)
  t.assertTrue(LobbyStore.isPlayerOwner(lobby, 4))
end)

t.test("a player who finished or retired is no longer in the lobby's race", function()
  local store = LobbyStore.new()
  local lobby = newLobby("r-1", "running", { 4, 7 })
  lobby.racers[1].status = "racing"
  lobby.racers[2].status = "dnf"
  store:saveLobby(lobby)
  t.assertNil(store:findLobbyOfPlayer(7), "retired players can register elsewhere")
  t.assertEquals(LobbyStore.isPlayerRegistered(lobby, 7), false)
  t.assertEquals(store:findLobbyOfPlayer(4).raceId, "r-1")
end)

t.test("start area markers show where registration is possible", function()
  local store = LobbyStore.new()
  local tracks = { { missionId = "level/timeTrial/a" }, { missionId = "level/timeTrial/b" }, { missionId = "level/timeTrial/c" } }
  store:saveLobby(newLobby("r-1", "running", { 1 }))
  local lobbyB = newLobby("r-2", "registering", { 2 })
  lobbyB.missionId = "level/timeTrial/b"
  store:saveLobby(lobbyB)
  local open = startAreaVisibility.getTracksOpenForRegistration(tracks, store, false)
  t.assertEquals(#open, 2, "a is busy; b takes registrations; c has no race")
  t.assertEquals(open[1].missionId, "level/timeTrial/b")
  t.assertEquals(open[2].missionId, "level/timeTrial/c")
  t.assertEquals(#startAreaVisibility.getTracksOpenForRegistration(tracks, store, true), 0, "nothing while racing")
end)

t.test("removed lobbies are forgotten", function()
  local store = LobbyStore.new()
  store:saveLobby(newLobby("r-1", "registering", { 4 }))
  store:removeLobby("r-1")
  t.assertNil(store:findLobbyOfPlayer(4))
end)

return t.runAll("lobbyStore")
