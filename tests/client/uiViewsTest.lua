local t = require("tests/testRunner")
local lobbyView = require("vracerMP/ui/lobbyView")
local raceInfoView = require("vracerMP/ui/raceInfoView")
local lapsView = require("vracerMP/ui/lapsView")
local DeltaDisplay = require("vracerMP/ui/deltaDisplay")
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
  t.assertEquals(view.serverRecordText, "Server record: 01'24\".120 - Ana (etk800)")
  t.assertNil(lobbyView.build(TRACK, lobby, 4).serverRecordText, "no record yet")
end)

t.test("lobby offers the track picker only where several tracks share the start area", function()
  local shared = lobbyView.build(TRACK, nil, 4, nil, { index = 2, count = 4 })
  t.assertTrue(shared.canChooseTrack)
  t.assertEquals(shared.trackChoiceText, "Track 2 of 4 here")
  local alone = lobbyView.build(TRACK, nil, 4, nil, { index = 1, count = 1 })
  t.assertEquals(alone.canChooseTrack, false)
  t.assertNil(alone.trackChoiceText)
  t.assertEquals(lobbyView.build(TRACK, nil, 4).canChooseTrack, false, "in a race: no picker")
end)

t.test("lobby shows the mission's picture and description when it has them", function()
  local described = lobbyView.build({ name = "Forgotten Raceway", closed = true, defaultLaps = 1,
    description = "A route.", previewPath = "/gameplay/missions/x/preview.jpg" }, nil, 4)
  t.assertEquals(described.trackDescription, "A route.")
  t.assertEquals(described.trackPreviewPath, "/gameplay/missions/x/preview.jpg")
  local plain = lobbyView.build(TRACK, nil, 4)
  t.assertNil(plain.trackDescription)
  t.assertNil(plain.trackPreviewPath)
end)

t.test("a running race closes registration", function()
  local view = lobbyView.build(TRACK, newLobby("running"), 99)
  t.assertEquals(view.canRegister, false)
  t.assertEquals(view.statusText, "Race in progress")
end)

local RACING_HUD = { position = 2, currentLap = 2, laps = 3, raceTimeMs = 252880, currentLapMs = 81455,
  bestLapMs = 79902 }

t.test("race info shows place, times and the server record", function()
  local view = raceInfoView.build(RACING_HUD, { name = "vracerbcs02", lapTimeMs = 78311 })
  t.assertEquals(view.placeText, "2nd")
  t.assertEquals(view.totalTimeText, "Total time: 04'12\".880")
  t.assertEquals(view.currentLapText, "Current lap: 01'21\".455")
  t.assertEquals(view.bestLapText, "Best lap: 01'19\".902")
  t.assertEquals(view.serverRecordText, "Server Record - vracerbcs02: 01'18\".311")
  t.assertNil(view.penaltyText, "no penalty, no row")
  t.assertNil(view.finishText)
end)

t.test("race info hides the record row when the track has none; shows hours past an hour", function()
  local view = raceInfoView.build({ position = 1, currentLap = 1, laps = 1, raceTimeMs = 3852880, currentLapMs = 3852880 })
  t.assertNil(view.serverRecordText)
  t.assertEquals(view.totalTimeText, "Total time: 1:04'12\".880")
  t.assertEquals(view.bestLapText, "Best lap: --'--\".---", "no lap completed yet")
end)

t.test("places are ordinals", function()
  local places = { [1] = "1st", [2] = "2nd", [3] = "3rd", [4] = "4th", [11] = "11th", [12] = "12th",
    [13] = "13th", [21] = "21st", [22] = "22nd", [23] = "23rd", [101] = "101st", [111] = "111th" }
  for place, text in pairs(places) do t.assertEquals(raceInfoView.getOrdinalPlace(place), text) end
end)

t.test("race info shows penalties, then the finish or DNF", function()
  local penalized = raceInfoView.build({ position = 1, currentLap = 1, laps = 1, penaltyMs = 10000 })
  t.assertEquals(penalized.penaltyText, "Penalty: +10\".000")
  local finished = raceInfoView.build({ position = 2, currentLap = 3, laps = 3,
    finishInfo = { status = "finished", position = 2 } })
  t.assertEquals(finished.finishText, "Finished 2nd")
  local dnf = raceInfoView.build({ currentLap = 1, laps = 3, finishInfo = { status = "dnf", dnfReason = "retired" } })
  t.assertEquals(dnf.finishText, "DNF (retired)")
end)

t.test("laps app shows the lap and offers Retire while racing", function()
  local view = lapsView.build(RACING_HUD)
  t.assertEquals(view.lapsText, "Laps: 2/3")
  t.assertTrue(view.canRetire)
  local out = lapsView.build({ currentLap = 3, laps = 3, finishInfo = { status = "finished", position = 1 } })
  t.assertEquals(out.canRetire, false, "no Retire once out of the race")
end)

t.test("each delta shows for 3.2 s on its own, then fades out keeping its text", function()
  local deltas = DeltaDisplay.new()
  t.assertEquals(deltas:getView(false).visible, false, "only during a race")
  deltas:show({ kind = "ahead", gapMs = 842 })
  local view = deltas:getView(true)
  t.assertEquals(view.ahead.text, "+0\".842")
  t.assertTrue(view.ahead.isShown)
  t.assertEquals(view.behind.isShown, false)
  deltas:update(2.0)
  deltas:show({ kind = "behind", gapMs = 1276 })
  deltas:update(1.3) -- ahead: 3.3 s, behind: 1.3 s
  view = deltas:getView(true)
  t.assertEquals(view.ahead.isShown, false)
  t.assertEquals(view.ahead.text, "+0\".842", "kept for the fade out")
  t.assertTrue(view.behind.isShown)
  t.assertEquals(view.behind.text, "-1\".276")
  deltas:show({ kind = "ahead", gapMs = 500 })
  t.assertTrue(deltas:getView(true).ahead.isShown, "a new gap shows again")
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
  t.assertEquals(view.rows[2].gapToWinner, "+1\".500")
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
  t.assertEquals(view.rows[2].rawTime, "00'30\".000")
  t.assertEquals(view.rows[2].penaltyTime, "+02'28\".000")
  t.assertEquals(view.rows[2].totalTime, "02'58\".000")
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
  for _, name in ipairs({ "lobby", "raceInfo", "deltas", "laps", "countdown", "results" }) do
    t.assertTrue(views[name].visible, name .. " is visible")
  end
end)

return t.runAll("uiViews")
