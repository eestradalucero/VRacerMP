local t = require("tests/testRunner")
local LapRecords = require("vracerMP/records/lapRecords")

local function newLap(lapTimeMs, name, model, missionId)
  return { missionId = missionId or "level/timeTrial/a", trackName = "A", lapTimeMs = lapTimeMs, name = name, model = model }
end

t.test("only a faster lap is a new track record", function()
  local records = LapRecords.new()
  t.assertTrue(records:recordLap(newLap(60000, "Ana", "etk800")))
  t.assertEquals(records:recordLap(newLap(61000, "Bo", "etk800")), false)
  t.assertTrue(records:recordLap(newLap(59000, "Bo", "pickup")))
  t.assertEquals(records:getTrackRecord("level/timeTrial/a").name, "Bo")
end)

t.test("records are kept per vehicle model too", function()
  local records = LapRecords.new()
  records:recordLap(newLap(59000, "Bo", "pickup"))
  records:recordLap(newLap(61000, "Ana", "etk800"))
  records:recordLap(newLap(60500, "Cy", "etk800"))
  t.assertEquals(records:getVehicleRecord("level/timeTrial/a", "etk800").name, "Cy")
  t.assertEquals(records:getTrackRecord("level/timeTrial/a").name, "Bo")
end)

t.test("each track has its own record", function()
  local records = LapRecords.new()
  records:recordLap(newLap(59000, "Bo", "pickup"))
  records:recordLap(newLap(90000, "Ana", "etk800", "level/timeTrial/b"))
  t.assertEquals(#records:getAllTrackRecords(), 2)
end)

return t.runAll("lapRecords")
