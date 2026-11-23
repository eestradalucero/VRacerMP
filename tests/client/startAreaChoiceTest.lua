-- Shared start areas (B-13): which tracks are here, and which one the player picked.
local t = require("tests/testRunner")
local startAreaWatcher = require("vracerMP/tracks/startAreaWatcher")
local StartAreaChoice = require("vracerMP/tracks/startAreaChoice")
local LobbyStore = require("vracerMP/lobby/lobbyStore")

local function newTrack(missionId, name, x)
  return { missionId = missionId, name = name, startArea = { x = x, y = 0, z = 0, radius = 20 } }
end

local SHORT = newTrack("hirochi/timeTrial/short", "Short Course", 2)
local FORGOTTEN = newTrack("hirochi/timeTrial/forgotten", "Forgotten Raceway", 5)
local LONG = newTrack("hirochi/timeTrial/long", "Long Course", 9)
local FAR_AWAY = newTrack("hirochi/timeTrial/drag", "Drag Strip", 500)
local ALL_TRACKS = { LONG, FAR_AWAY, SHORT, FORGOTTEN }
local AT_THE_SPOT = { x = 0, y = 0, z = 0 }

local function newLobbyStore(lobbies)
  local store = LobbyStore.new()
  for _, lobby in ipairs(lobbies or {}) do store:saveLobby(lobby) end
  return store
end

t.test("every start area around the car is found, closest first", function()
  local tracksHere = startAreaWatcher.findTracksAtPosition(AT_THE_SPOT, ALL_TRACKS)
  t.assertEquals(#tracksHere, 3)
  t.assertEquals(tracksHere[1], SHORT)
  t.assertEquals(tracksHere[3], LONG)
  t.assertEquals(#startAreaWatcher.findTracksAtPosition({ x = 250, y = 0, z = 0 }, ALL_TRACKS), 0)
end)

t.test("the choice starts on the closest track and the arrows wrap around", function()
  local choice = StartAreaChoice.new()
  choice:update(startAreaWatcher.findTracksAtPosition(AT_THE_SPOT, ALL_TRACKS), newLobbyStore())
  t.assertEquals(choice:getChosenTrack(), SHORT)
  t.assertEquals(choice:getPosition().count, 3)
  choice:step(-1)
  t.assertEquals(choice:getChosenTrack(), LONG, "previous from the first is the last")
  t.assertEquals(choice:getPosition().index, 3)
  choice:step(1)
  choice:step(1)
  t.assertEquals(choice:getChosenTrack(), FORGOTTEN)
end)

t.test("the choice starts on a track whose race takes registrations", function()
  local choice = StartAreaChoice.new()
  local lobbies = newLobbyStore({
    { raceId = "r-1", missionId = SHORT.missionId, state = "running", racers = {} },
    { raceId = "r-2", missionId = LONG.missionId, state = "registering", racers = {} },
  })
  choice:update(startAreaWatcher.findTracksAtPosition(AT_THE_SPOT, ALL_TRACKS), lobbies)
  t.assertEquals(choice:getChosenTrack(), LONG)
end)

t.test("the picked track stays while the car is in the area, and resets when it leaves", function()
  local choice = StartAreaChoice.new()
  local store = newLobbyStore()
  local tracksHere = startAreaWatcher.findTracksAtPosition(AT_THE_SPOT, ALL_TRACKS)
  choice:update(tracksHere, store)
  choice:step(1)
  store:saveLobby({ raceId = "r-3", missionId = LONG.missionId, state = "registering", racers = {} })
  choice:update(tracksHere, store)
  t.assertEquals(choice:getChosenTrack(), FORGOTTEN, "a race opening elsewhere does not move the choice")
  choice:update({}, store)
  t.assertNil(choice:getChosenTrack())
  t.assertNil(choice:getPosition())
  choice:update(tracksHere, store)
  t.assertEquals(choice:getChosenTrack(), LONG, "back in the area: the open race again")
end)

t.test("one track alone cannot be stepped away from", function()
  local choice = StartAreaChoice.new()
  choice:update({ FAR_AWAY }, newLobbyStore())
  choice:step(1)
  t.assertEquals(choice:getChosenTrack(), FAR_AWAY)
end)

return t.runAll("startAreaChoice")
