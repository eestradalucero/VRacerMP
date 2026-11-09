local t = require("tests/testRunner")
local TrackInfo = require("vracerMP/tracks/trackInfo")
local startAreaWatcher = require("vracerMP/tracks/startAreaWatcher")

local FOLDER = "/gameplay/missions/vracer_bajasur/timeTrial/001-Circuito/"

local info = {
  name = "Circuito Bronco Short Course Time Trial",
  missionTypeData = { defaultLaps = 1 },
  startTrigger = { level = "vracer_bajasur", pos = { 249, 4036, 130 }, radius = 10 },
}

local function newRaceData(closed)
  return {
    name = "Circuito Bronco Short Course",
    classification = { closed = closed, branching = false },
    defaultLaps = 3,
    startNode = 136,
    pathnodes = {
      { oldId = 136, visible = true },
      { oldId = 137, visible = true },
      { oldId = 138, visible = false },
      { oldId = 139 },
    },
    startPositions = { { name = "Start Position 2", pos = { 1, 2, 3 }, rot = { 0, 0, 0, 1 } } },
  }
end

t.test("reads ids, names, laps and start area", function()
  local track = TrackInfo.fromMissionFiles(FOLDER, info, newRaceData(true))
  t.assertEquals(track.missionId, "vracer_bajasur/timeTrial/001-Circuito")
  t.assertEquals(track.raceFilePath, FOLDER .. "race.race.json")
  t.assertEquals(track.level, "vracer_bajasur")
  t.assertEquals(track.name, "Circuito Bronco Short Course")
  t.assertEquals(track.defaultLaps, 3)
  t.assertEquals(track.startArea.radius, 10)
  t.assertTrue(track:isRaceable())
end)

t.test("closed tracks count every visible pathnode as a crossing", function()
  local track = TrackInfo.fromMissionFiles(FOLDER, info, newRaceData(true))
  t.assertEquals(track.pathnodeCount, 3)
end)

t.test("point-to-point tracks skip the start pathnode and are one lap", function()
  local track = TrackInfo.fromMissionFiles(FOLDER, info, newRaceData(false))
  t.assertEquals(track.pathnodeCount, 2)
  t.assertEquals(track.defaultLaps, 1)
end)

t.test("start area watcher finds the track the car is in", function()
  local track = TrackInfo.fromMissionFiles(FOLDER, info, newRaceData(true))
  t.assertEquals(startAreaWatcher.findTrackAtPosition({ x = 252, y = 4040, z = 130 }, { track }), track)
  t.assertNil(startAreaWatcher.findTrackAtPosition({ x = 300, y = 4040, z = 130 }, { track }))
end)

return t.runAll("trackInfo")
