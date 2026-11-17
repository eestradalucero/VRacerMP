-- Runs the real ClientController with stubbed BeamNG / BeamMP globals and checks what the
-- Vue apps would receive. The race session is faked (it needs the game's race engine).

local t = require("tests/testRunner")

local MY_ID = 4
local LAYOUT_FILE = "/settings/ui_apps/layouts/default/beammp.uilayout.json"
local stubs = { uiEvents = {}, serverMessages = {}, serverHandlers = {}, addedApps = {}, removedAppIndexes = {},
  editing = false, files = {}, layoutApps = {} }

local RACE_DATA = {
  name = "Circuito", classification = { closed = true }, defaultLaps = 2, startNode = 1,
  pathnodes = { { oldId = 1 }, { oldId = 2 } },
  startPositions = { { name = "Start Position 1", pos = { 0, 0, 0 }, rot = { 0, 0, 0, 1 } } },
}
local INFO = { missionType = "timeTrial", startTrigger = { level = "testlevel", pos = { 0, 0, 0 }, radius = 10 } }
local MISSION = "/gameplay/missions/testlevel/timeTrial/001-Test"

local function installGlobals()
  FS = { findFiles = function() return { MISSION .. "/info.json" } end }
  jsonReadFile = function(path)
    if path == MISSION .. "/info.json" then return INFO end
    if path == MISSION .. "/race.race.json" then return RACE_DATA end
    return stubs.files[path]
  end
  jsonWriteFile = function(path, data) stubs.files[path] = data end
  jsonEncode = function(value) return value end -- messages stay tables in tests
  getCurrentLevelIdentifier = function() return "testlevel" end
  guihooks = { trigger = function(eventName, view) table.insert(stubs.uiEvents, { eventName = eventName, view = view }) end }
  ui_message = function() end
  Engine = { Audio = { playOnce = function() end } }
  MPConfig = { getPlayerServerID = function() return MY_ID end }
  TriggerServerEvent = function(eventName, data) table.insert(stubs.serverMessages, { eventName = eventName, data = data }) end
  AddEventHandler = function(eventName, handler) stubs.serverHandlers[eventName] = handler end
  jsonDecode = function(payload) return payload end -- tests pass tables straight through
  local playerVehicle = { getPosition = function() return { x = 1, y = 1, z = 0 } end }
  be = {
    getPlayerVehicle = function() return { getPosition = function() return playerVehicle.getPosition() end,
      getJBeamFilename = function() return "etk800" end, partConfig = "vehicles/etk800/856_m.pc" } end,
    getPlayerVehicleID = function() return 101 end,
  }
  extensions = {
    load = function() end,
    ui_appLayouts = {
      getCurrentLayout = function() return { filename = LAYOUT_FILE, apps = stubs.layoutApps } end,
      getAvailableLayouts = function() return { { filename = LAYOUT_FILE, apps = stubs.layoutApps } } end,
      addApp = function(filename, appName) table.insert(stubs.addedApps, appName) return true end,
      removeApp = function(filename, index) table.insert(stubs.removedAppIndexes, index) return true end,
      setCurrentLayout = function() end,
      isEditing = function() return stubs.editing end,
    },
  }
end

-- Fake race session: enough for the race apps.
local FakeSession = {}
FakeSession.__index = FakeSession
FakeSession.state = { gridding = "gridding", countdown = "countdown", racing = "racing", finished = "finished" }
function FakeSession.new(track, startInfo)
  return setmetatable({ track = track, raceId = startInfo.raceId, state = "gridding", laps = startInfo.laps }, FakeSession)
end
function FakeSession:placeOnGrid() return true end
function FakeSession:beginCountdown() self.state = "countdown" end
function FakeSession:go() self.state = "racing" return true end
function FakeSession:update() return nil end
function FakeSession:render() end
function FakeSession:applyStandings() end
function FakeSession:applyFinish() self.state = "finished" end
function FakeSession:applyPenalty(penalty) self.penaltyMs = penalty.totalPenaltyMs end
function FakeSession:dispose() end
function FakeSession:getHudData()
  return { position = 1, racerCount = 2, currentLap = 1, laps = self.laps, raceTimeMs = 1000, currentLapMs = 1000,
    pathnodesPassed = 0, pathnodeCount = 2, penaltyMs = self.penaltyMs, state = self.state }
end

-- Fake start area markers: remember which tracks were marked last frame.
local FakeMarkers = {}
FakeMarkers.__index = FakeMarkers
function FakeMarkers.new() return setmetatable({ shownTracks = {} }, FakeMarkers) end
function FakeMarkers:render(tracks) self.shownTracks = tracks end
function FakeMarkers:clear() self.shownTracks = {} end

local function loadController()
  installGlobals()
  package.loaded["vracerMP/race/raceSession"] = FakeSession
  package.loaded["vracerMP/tracks/startAreaMarkers"] = FakeMarkers
  package.loaded["vracerMP/controller/clientController"] = nil
  return require("vracerMP/controller/clientController")
end

local function lastUiView(eventName)
  for index = #stubs.uiEvents, 1, -1 do
    if stubs.uiEvents[index].eventName == eventName then return stubs.uiEvents[index].view end
  end
  return nil
end

local function lastServerMessage(eventName)
  for index = #stubs.serverMessages, 1, -1 do
    if stubs.serverMessages[index].eventName == eventName then return jsonDecode(stubs.serverMessages[index].data) end
  end
  return nil
end

local function serverSends(eventName, payload)
  stubs.serverHandlers[eventName](payload)
end

local ClientController = loadController()
local controller = ClientController.new()
controller:loadLevel()

local function runFrames(count, dt)
  for _ = 1, count do controller:update(dt or 0.1, dt or 0.1) end
end

t.test("installs our six apps into the current layout once", function()
  runFrames(1)
  t.assertEquals(#stubs.addedApps, 6)
  t.assertEquals(stubs.addedApps[1], "vracermpRaceInfo")
  runFrames(30) -- the layout is checked again every 2 s
  t.assertEquals(#stubs.addedApps, 6, "never added twice")
end)

t.test("asks for the races with the map's tracks until the server welcomes us", function()
  runFrames(1)
  local request = lastServerMessage("vracerMP_requestLobbies")
  t.assertEquals(request.tracks[1].missionId, "testlevel/timeTrial/001-Test")
  local requestCount = #stubs.serverMessages
  runFrames(25) -- 2.5 s without an answer: asked again
  t.assertEquals(#stubs.serverMessages, requestCount + 1)
  serverSends("vracerMP_welcome", { protocolVersion = 1 })
  runFrames(30)
  t.assertEquals(#stubs.serverMessages, requestCount + 1, "no more requests once welcomed")
end)

t.test("the start area is marked while registration is possible", function()
  controller:render(0.016, 0.016)
  t.assertEquals(#controller.startAreaMarkers.shownTracks, 1)
  t.assertEquals(controller.startAreaMarkers.shownTracks[1].missionId, "testlevel/timeTrial/001-Test")
end)

t.test("the lobby shows the track's server lap record", function()
  serverSends("vracerMP_lapRecord", { missionId = "testlevel/timeTrial/001-Test", trackName = "Circuito",
    lapTimeMs = 84120, name = "Ana", model = "etk800" })
  runFrames(1)
  t.assertEquals(lastUiView("VRacerMPLobby").serverRecordText, "Server record: 01'24\".120 - Ana (etk800)")
end)

t.test("in a start area the lobby app offers registration", function()
  runFrames(3)
  local lobby = lastUiView("VRacerMPLobby")
  t.assertTrue(lobby.visible)
  t.assertEquals(lobby.trackName, "Circuito")
  t.assertTrue(lobby.canRegister)
end)

t.test("register button sends the track and vehicle to the server", function()
  controller:handleUiAction({ action = "register" })
  local message = lastServerMessage("vracerMP_register")
  t.assertEquals(message.track.missionId, "testlevel/timeTrial/001-Test")
  t.assertEquals(message.vehicle.model, "etk800")
  t.assertNil(message.vehicle.config, "configs are not sent")
end)

t.test("owner sees settings; laps button sends a configure", function()
  serverSends("vracerMP_lobbyUpdated", { raceId = "r-1", missionId = "testlevel/timeTrial/001-Test", state = "registering",
    ownerId = MY_ID, laps = 2, dnfTimeoutSeconds = 120, racers = { { id = MY_ID, name = "Me" } } })
  runFrames(1)
  t.assertTrue(lastUiView("VRacerMPLobby").canEditSettings)
  controller:handleUiAction({ action = "changeLaps", delta = 1 })
  t.assertEquals(lastServerMessage("vracerMP_configure").laps, 3)
end)

t.test("DNF time steps down to 0 (no limit) but not below", function()
  serverSends("vracerMP_lobbyUpdated", { raceId = "r-1", missionId = "testlevel/timeTrial/001-Test", state = "registering",
    ownerId = MY_ID, laps = 2, dnfTimeoutSeconds = 20, racers = { { id = MY_ID, name = "Me" } } })
  runFrames(1)
  controller:handleUiAction({ action = "changeDnfTimeout", delta = -30 })
  t.assertEquals(lastServerMessage("vracerMP_configure").dnfTimeoutSeconds, 0)
  local sentBefore = #stubs.serverMessages
  serverSends("vracerMP_lobbyUpdated", { raceId = "r-1", missionId = "testlevel/timeTrial/001-Test", state = "registering",
    ownerId = MY_ID, laps = 2, dnfTimeoutSeconds = 0, racers = { { id = MY_ID, name = "Me" } } })
  runFrames(1)
  controller:handleUiAction({ action = "changeDnfTimeout", delta = -30 })
  t.assertEquals(#stubs.serverMessages, sentBefore, "nothing below no limit")
end)

t.test("countdown and race panel follow the start", function()
  serverSends("vracerMP_raceStarting", { raceId = "r-1", missionId = "testlevel/timeTrial/001-Test", laps = 2, gridSlot = 1, racerCount = 1 })
  t.assertEquals(lastServerMessage("vracerMP_gridReady").raceId, "r-1")
  serverSends("vracerMP_countdown", { raceId = "r-1", goInMs = 3000 })
  runFrames(1, 0.01)
  t.assertEquals(lastUiView("VRacerMPCountdown").text, "3")
  t.assertEquals(lastUiView("VRacerMPLobby").visible, false, "lobby hides while racing")
  serverSends("vracerMP_go", { raceId = "r-1" })
  runFrames(1, 0.01)
  t.assertEquals(lastUiView("VRacerMPCountdown").text, "GO!")
  t.assertEquals(lastUiView("VRacerMPLaps").lapsText, "Laps: 1/2")
  t.assertTrue(lastUiView("VRacerMPLaps").canRetire)
  t.assertEquals(lastUiView("VRacerMPRaceInfo").placeText, "1st")
  t.assertEquals(lastUiView("VRacerMPRaceInfo").serverRecordText, "Server Record - Ana: 01'24\".120")
  controller:render(0.016, 0.016)
  t.assertEquals(#controller.startAreaMarkers.shownTracks, 0, "no start markers while racing")
end)

t.test("a penalty from the server shows in the race info", function()
  serverSends("vracerMP_penalty", { raceId = "r-1", reason = "testPenalty", penaltyMs = 85000, totalPenaltyMs = 85000 })
  runFrames(1)
  t.assertEquals(lastUiView("VRacerMPRaceInfo").penaltyText, "Penalty: +01'25\".000")
end)

t.test("a gap shows its delta for 3.2 s", function()
  serverSends("vracerMP_gap", { raceId = "r-1", kind = "ahead", gapMs = 842 })
  runFrames(1)
  local deltas = lastUiView("VRacerMPDeltas")
  t.assertEquals(deltas.ahead.text, "+0\".842")
  t.assertTrue(deltas.ahead.isShown)
  t.assertEquals(deltas.behind.isShown, false)
  runFrames(33)
  t.assertEquals(lastUiView("VRacerMPDeltas").ahead.isShown, false)
end)

t.test("retire button sends unregister for our race", function()
  controller:handleUiAction({ action = "retire" })
  t.assertEquals(lastServerMessage("vracerMP_unregister").raceId, "r-1")
end)

t.test("results of a race we left do not end our new race", function()
  serverSends("vracerMP_raceResults", { raceId = "r-old", laps = 1, raceTrack = { name = "Old" }, racers = {} })
  runFrames(1)
  t.assertEquals(lastUiView("VRacerMPRaceInfo").visible, true, "still racing r-1")
end)

t.test("results show at the end and close on the button", function()
  serverSends("vracerMP_raceResults", { raceId = "r-1", laps = 2, raceTrack = { name = "Circuito" },
    racers = { { position = 1, name = "Me", status = "finished", raceStats = { totalTime = 90000, bestLapTime = 44000, gapToWinner = 0 } } } })
  runFrames(1)
  t.assertTrue(lastUiView("VRacerMPResults").visible)
  t.assertEquals(lastUiView("VRacerMPRaceInfo").visible, false)
  t.assertEquals(lastUiView("VRacerMPLaps").visible, false)
  t.assertEquals(lastUiView("VRacerMPDeltas").visible, false)
  controller:handleUiAction({ action = "closeResults" })
  runFrames(1)
  t.assertEquals(lastUiView("VRacerMPResults").visible, false)
end)

t.test("results close by themselves after 30 seconds", function()
  serverSends("vracerMP_raceResults", { raceId = "r-2", laps = 1, raceTrack = { name = "Circuito" },
    racers = { { position = 1, id = MY_ID, name = "Me", status = "finished", raceStats = { totalTime = 60000 } } } })
  runFrames(1)
  t.assertTrue(lastUiView("VRacerMPResults").rows[1].isMe)
  runFrames(280) -- 28 s more
  t.assertEquals(lastUiView("VRacerMPResults").closeText, "Closes in 2 s")
  runFrames(25)
  t.assertEquals(lastUiView("VRacerMPResults").visible, false)
end)

t.test("layout editor shows sample content in every app", function()
  stubs.editing = true
  runFrames(1)
  t.assertEquals(lastUiView("VRacerMPRaceInfo").placeText, "2nd")
  t.assertTrue(lastUiView("VRacerMPDeltas").ahead.isShown)
  stubs.editing = false
end)

t.test("unknown UI actions are ignored", function()
  controller:handleUiAction({ action = "explode" })
  controller:handleUiAction(nil)
  t.assertTrue(true)
end)

package.loaded["vracerMP/race/raceSession"] = nil
package.loaded["vracerMP/tracks/startAreaMarkers"] = nil
t.test("an older layout gets the new apps once and loses the old race panel", function()
  local layoutInstaller = require("vracerMP/ui/layoutInstaller")
  stubs.files["/settings/vracerMP/installedLayouts.json"] = { [LAYOUT_FILE] = true } -- before B-2
  stubs.layoutApps = { { appName = "vracermpLobby" }, { appName = "vracermpRacePanel" }, { appName = "vracermpResults" } }
  stubs.addedApps, stubs.removedAppIndexes = {}, {}
  layoutInstaller.installIntoCurrentLayout()
  t.assertEquals(#stubs.addedApps, 3, "race info, deltas and laps")
  t.assertEquals(stubs.addedApps[2], "vracermpDeltas")
  t.assertEquals(#stubs.removedAppIndexes, 1)
  t.assertEquals(stubs.removedAppIndexes[1], 1, "0-based position of the race panel")
  stubs.layoutApps = { { appName = "vracermpLobby" }, { appName = "vracermpResults" } }
  layoutInstaller.installIntoCurrentLayout()
  t.assertEquals(#stubs.addedApps, 3, "nothing more to add")
  t.assertEquals(#stubs.removedAppIndexes, 1, "nothing more to remove")
end)

return t.runAll("clientController")
