local t = require("tests/testRunner")
local lobbyView = require("vracerMP/ui/lobbyView")
local raceView = require("vracerMP/ui/raceView")
local resultsView = require("vracerMP/ui/resultsView")
local sampleViews = require("vracerMP/ui/sampleViews")

local TRACK = { name = "Circuito", closed = true, defaultLaps = 3 }

local function newLobby(state)
  return {
    raceId = "r-1", state = state or "registering", ownerId = 4, laps = 2, dnfTimeoutSeconds = 90,
    racers = { { id = 4, name = "Owner" }, { id = 7, name = "Guest" } },
  }
end

t.test("lobby view is hidden without a track", function()
  t.assertEquals(lobbyView.build(nil, nil, 1).visible, false)
end)

t.test("lobby view without a race offers registration with track defaults", function()
  local view = lobbyView.build(TRACK, nil, 1)
  t.assertTrue(view.canRegister)
  t.assertEquals(view.hasRace, false)
  t.assertEquals(view.laps, 3)
end)

t.test("owner may edit and start; guest may only unregister", function()
  local ownerView = lobbyView.build(TRACK, newLobby(), 4)
  t.assertTrue(ownerView.canEditSettings)
  t.assertTrue(ownerView.isOwner)
  t.assertEquals(ownerView.racers[1].isOwner, true)
  local guestView = lobbyView.build(TRACK, newLobby(), 7)
  t.assertEquals(guestView.canEditSettings, false)
  t.assertTrue(guestView.isRegistered)
  t.assertEquals(guestView.canRegister, false)
  t.assertTrue(guestView.racers[2].isMe)
end)

t.test("DNF time 0 shows as no limit", function()
  local lobby = newLobby()
  t.assertEquals(lobbyView.build(TRACK, lobby, 4).dnfTimeoutText, "90 s")
  lobby.dnfTimeoutSeconds = 0
  t.assertEquals(lobbyView.build(TRACK, lobby, 4).dnfTimeoutText, "No limit")
end)

t.test("lobby shows the server record", function()
  local lobby = newLobby()
  local view = lobbyView.build(TRACK, lobby, 4, { lapTimeMs = 84120, name = "Ana", model = "etk800" })
  t.assertEquals(view.serverRecordText, "Server record: 1:24.120 - Ana (etk800)")
  t.assertNil(lobbyView.build(TRACK, lobby, 4).serverRecordText, "no record yet")
end)

t.test("a running race closes registration", function()
  local view = lobbyView.build(TRACK, newLobby("running"), 99)
  t.assertEquals(view.canRegister, false)
  t.assertEquals(view.statusText, "Race in progress")
end)

t.test("race view formats every value", function()
  local view = raceView.build({
    position = 2, racerCount = 5, currentLap = 2, laps = 3, raceTimeMs = 84120, bestLapMs = 41000,
    pathnodesPassed = 4, pathnodeCount = 19, aheadGapMs = 214, behindGapMs = nil,
  })
  t.assertEquals(view.position, "P2")
  t.assertEquals(view.racerCount, "/ 5")
  t.assertEquals(view.lap, "2 / 3")
  t.assertEquals(view.raceTime, "1:24.120")
  t.assertEquals(view.pathnodes, "4 / 19")
  t.assertEquals(view.aheadGap, "-0:00.214")
  t.assertNil(view.behindGap)
  t.assertTrue(view.canRetire)
  t.assertNil(view.penaltyText, "no penalty, no text")
  t.assertEquals(raceView.build({ currentLap = 1, laps = 1, pathnodesPassed = 0, pathnodeCount = 4,
    penaltyMs = 85000 }).penaltyText, "Penalty +1:25.000")
end)

t.test("race view shows finish and DNF text", function()
  local finished = raceView.build({ currentLap = 3, laps = 3, pathnodesPassed = 0, pathnodeCount = 19,
    finishInfo = { status = "finished", position = 1, totalTimeMs = 251334 } })
  t.assertEquals(finished.finishText, "Finished P1  4:11.334")
  local dnf = raceView.build({ currentLap = 1, laps = 3, pathnodesPassed = 0, pathnodeCount = 19,
    finishInfo = { status = "dnf", dnfReason = "timeout" } })
  t.assertEquals(dnf.finishText, "DNF (timeout)")
  t.assertEquals(dnf.canRetire, false, "no Retire button once out of the race")
end)

t.test("results view builds rows from the results JSON", function()
  local view = resultsView.build({
    laps = 1, raceTrack = { name = "Circuito" },
    racers = {
      { position = 1, name = "A", status = "finished", raceStats = { totalTime = 60000, bestLapTime = 60000, gapToWinner = 0 } },
      { position = 2, name = "B", status = "finished", raceStats = { totalTime = 61500, bestLapTime = 61500, gapToWinner = 1500 } },
      { position = 3, name = "C", status = "dnf", dnfReason = "disconnected", raceStats = {} },
    },
  })
  t.assertEquals(view.title, "Circuito  -  1 lap")
  t.assertEquals(view.rows[1].gapToWinner, "")
  t.assertEquals(view.rows[2].gapToWinner, "+0:01.500")
  t.assertEquals(view.rows[3].totalTime, "-")
  t.assertEquals(view.rows[3].status, "DNF disconnected")
  t.assertNil(view.closeText)
end)

t.test("results show raw time, penalties and total time", function()
  local view = resultsView.build({ laps = 1, raceTrack = { name = "C" }, racers = {
    { position = 1, id = 3, name = "A", status = "finished", raceStats = { rawTime = 60000, penaltyTime = 0, totalTime = 60000 } },
    { position = 2, id = 7, name = "B", status = "finished", raceStats = { rawTime = 30000, penaltyTime = 148000, totalTime = 178000 } },
  } }, 7)
  t.assertEquals(view.rows[1].penaltyTime, "")
  t.assertEquals(view.rows[2].rawTime, "0:30.000")
  t.assertEquals(view.rows[2].penaltyTime, "+2:28.000")
  t.assertEquals(view.rows[2].totalTime, "2:58.000")
end)

t.test("results highlight our own row and show when they close", function()
  local view = resultsView.build({ laps = 1, raceTrack = { name = "C" }, racers = {
    { position = 1, id = 3, name = "A", status = "finished", raceStats = { totalTime = 60000 } },
    { position = 2, id = 7, name = "Me", status = "finished", raceStats = { totalTime = 61000 } },
  } }, 7, 29.2)
  t.assertEquals(view.rows[1].isMe, false)
  t.assertTrue(view.rows[2].isMe)
  t.assertEquals(view.closeText, "Closes in 30 s")
end)

t.test("sample views show every app", function()
  local views = sampleViews.build()
  t.assertTrue(views.lobby.visible and views.race.visible and views.countdown.visible and views.results.visible)
end)

return t.runAll("uiViews")
