-- Runs the real ClientController with stubbed BeamNG / BeamMP globals and checks what the
-- Vue apps would receive. The race session is faked (it needs the game's race engine).

local t = require("tests/testRunner")

local MY_ID = 4
local stubs = { uiEvents = {}, serverMessages = {}, serverHandlers = {}, addedApps = {}, editing = false }

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
    return nil
  end
  jsonWriteFile = function() end
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
      getCurrentLayout = function() return { filename = "/settings/ui_apps/layouts/default/beammp.uilayout.json", apps = {} } end,
      addApp = function(filename, appName) table.insert(stubs.addedApps, appName) return true end,
      setCurrentLayout = function() end,
      isEditing = function() return stubs.editing end,
    },
  }
end

-- Fake race session: enough for the race panel.
local FakeSession = {}
FakeSession.__index = FakeSession
FakeSession.state = { gridding = "gridding", countdown = "countdown", racing = "racing", finished = "finished" }
function FakeSession.new(track, startInfo) return setmetatable({ raceId = startInfo.raceId, state = "gridding", laps = startInfo.laps }, FakeSession) end
function FakeSession:placeOnGrid() return true end
function FakeSession:beginCountdown() self.state = "countdown" end
function FakeSession:go() self.state = "racing" return true end
function FakeSession:update() return nil end
function FakeSession:render() end
function FakeSession:applyGap() end
function FakeSession:applyStandings() end
function FakeSession:applyFinish() self.state = "finished" end
function FakeSession:dispose() end
function FakeSession:getHudData()
  return { position = 1, racerCount = 2, currentLap = 1, laps = self.laps, raceTimeMs = 1000, pathnodesPassed = 0, pathnodeCount = 2 }
end

local function loadController()
  installGlobals()
  package.loaded["vracerMP/race/raceSession"] = FakeSession
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

t.test("installs the four apps into the current layout once", function()
  runFrames(1)
  t.assertEquals(#stubs.addedApps, 4)
  t.assertEquals(stubs.addedApps[1], "vracermpRacePanel")
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
  t.assertEquals(message.vehicle.config, "856_m")
end)

t.test("owner sees settings; laps button sends a configure", function()
  serverSends("vracerMP_lobbyUpdated", { raceId = "r-1", missionId = "testlevel/timeTrial/001-Test", state = "registering",
    ownerId = MY_ID, laps = 2, dnfTimeoutSeconds = 120, racers = { { id = MY_ID, name = "Me" } } })
  runFrames(1)
  t.assertTrue(lastUiView("VRacerMPLobby").canEditSettings)
  controller:handleUiAction({ action = "changeLaps", delta = 1 })
  t.assertEquals(lastServerMessage("vracerMP_configure").laps, 3)
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
  t.assertEquals(lastUiView("VRacerMPRace").lap, "1 / 2")
end)

t.test("results show at the end and close on the button", function()
  serverSends("vracerMP_raceResults", { laps = 2, raceTrack = { name = "Circuito" },
    racers = { { position = 1, name = "Me", status = "finished", raceStats = { totalTime = 90000, bestLapTime = 44000, gapToWinner = 0 } } } })
  runFrames(1)
  t.assertTrue(lastUiView("VRacerMPResults").visible)
  t.assertEquals(lastUiView("VRacerMPRace").visible, false)
  controller:handleUiAction({ action = "closeResults" })
  runFrames(1)
  t.assertEquals(lastUiView("VRacerMPResults").visible, false)
end)

t.test("layout editor shows sample content in every app", function()
  stubs.editing = true
  runFrames(1)
  t.assertEquals(lastUiView("VRacerMPRace").position, "P2")
  stubs.editing = false
end)

t.test("unknown UI actions are ignored", function()
  controller:handleUiAction({ action = "explode" })
  controller:handleUiAction(nil)
  t.assertTrue(true)
end)

package.loaded["vracerMP/race/raceSession"] = nil
return t.runAll("clientController")
