local t = require("tests/testRunner")
local fakes = require("tests/server/fakes")
local Race = require("vracerMP/races/race")
local TrackRef = require("vracerMP/races/trackRef")
local GapTracker = require("vracerMP/races/gapTracker")

local function newPlayer(playerId)
  return { playerId = playerId, name = "Player" .. playerId, vehicle = { model = "etk800", config = "856_m" } }
end

local function newRace(trackOverrides)
  local clock = fakes.newClock(1000)
  local track = assert(TrackRef.fromClientData(fakes.newTrackData(trackOverrides)))
  return Race.new("r-1", track, clock), clock
end

local function startRaceWith(playerIds)
  local race, clock = newRace()
  for _, playerId in ipairs(playerIds) do race:register(newPlayer(playerId)) end
  assert(race:beginGridding(playerIds[1]))
  for _, playerId in ipairs(playerIds) do race:markOnGrid(playerId) end
  race:beginCountdown()
  clock:advance(Race.COUNTDOWN_MS)
  race:beginRunning()
  return race, clock
end

-- Drives `playerId` through `count` crossings, `segmentMs` apart, starting after its last one.
local function driveCrossings(race, clock, playerId, count, segmentMs)
  local racer = race:getRacer(playerId)
  local outcome
  for _ = 1, count do
    local crossingNumber = racer.crossingCount + 1
    local raceTimeMs = (racer.lastCrossingTimeMs or 0) + segmentMs
    clock.nowMs = race.startedAtMs + raceTimeMs
    outcome = race:recordCrossing(playerId, {
      crossingNumber = crossingNumber,
      raceTimeMs = raceTimeMs,
      lapCompleted = crossingNumber % race.track.pathnodeCount == 0,
    })
  end
  return outcome
end

t.test("first registrant is owner; ownership passes on in registration order", function()
  local race = newRace()
  race:register(newPlayer(3))
  race:register(newPlayer(5))
  t.assertTrue(race:isOwner(3))
  race:unregister(3)
  t.assertTrue(race:isOwner(5))
end)

t.test("only the owner can configure and settings are validated", function()
  local race = newRace()
  race:register(newPlayer(3))
  race:register(newPlayer(5))
  local changed = race:configure(5, { laps = 3 })
  t.assertEquals(changed, false)
  t.assertTrue(race:configure(3, { laps = 5, dnfTimeoutSeconds = 60 }))
  t.assertEquals(race.settings.laps, 5)
  local valid, message = race:configure(3, { laps = 0 })
  t.assertEquals(valid, false)
  t.assertContains(message, "Laps")
end)

t.test("point-to-point tracks are always one lap", function()
  local race = newRace({ closed = false, defaultLaps = 3 })
  race:register(newPlayer(1))
  t.assertEquals(race.settings.laps, 1)
  t.assertEquals((race:configure(1, { laps = 2 })), false)
end)

t.test("grid slots follow registration order and registration closes", function()
  local race = newRace()
  race:register(newPlayer(7))
  race:register(newPlayer(2))
  t.assertTrue(race:beginGridding(7))
  t.assertEquals(race:getRacer(7).gridSlot, 1)
  t.assertEquals(race:getRacer(2).gridSlot, 2)
  t.assertEquals((race:register(newPlayer(9))), false)
end)

t.test("racers not on the grid at GO are DNF", function()
  local race = newRace()
  race:register(newPlayer(1))
  race:register(newPlayer(2))
  race:beginGridding(1)
  race:markOnGrid(1)
  race:beginCountdown()
  local missing = race:beginRunning()
  t.assertEquals(#missing, 1)
  t.assertEquals(race:getRacer(2).dnfReason, "notOnGrid")
end)

t.test("lap times, finish and best lap index", function()
  local race, clock = startRaceWith({ 1 })
  race.settings.laps = 2
  driveCrossings(race, clock, 1, 4, 20000) -- lap 1: 80 s
  local outcome = driveCrossings(race, clock, 1, 4, 19000) -- lap 2: 76 s
  local racer = race:getRacer(1)
  t.assertTrue(outcome.finished)
  t.assertEquals(racer.lapTimesMs[1], 80000)
  t.assertEquals(racer.lapTimesMs[2], 76000)
  t.assertEquals(racer:getTotalTimeMs(), 156000)
  local stats = racer:serialize(156000).raceStats
  t.assertEquals(stats.bestLap, 1, "0-based best lap")
  t.assertEquals(stats.totalTimeReadable, "02:36.000")
  t.assertEquals(stats.gapToWinner, 0)
end)

t.test("duplicate or out-of-order crossings are ignored", function()
  local race, clock = startRaceWith({ 1 })
  driveCrossings(race, clock, 1, 1, 10000)
  local outcome, reason = race:recordCrossing(1, { crossingNumber = 1, raceTimeMs = 10000 })
  t.assertNil(outcome)
  t.assertContains(reason, "unexpected crossing")
end)

t.test("positions follow progress, then crossing time", function()
  local race, clock = startRaceWith({ 1, 2, 3 })
  driveCrossings(race, clock, 2, 2, 10000)
  driveCrossings(race, clock, 1, 2, 10500)
  driveCrossings(race, clock, 3, 1, 9000)
  t.assertEquals(race:getRacer(2).position, 1)
  t.assertEquals(race:getRacer(1).position, 2)
  t.assertEquals(race:getRacer(3).position, 3)
end)

t.test("gap tracker returns the car directly ahead at the same progress", function()
  local tracker = GapTracker.new()
  t.assertNil(tracker:recordCrossing(1, 1, 10000))
  local gapForSecond = tracker:recordCrossing(2, 1, 10400)
  t.assertEquals(gapForSecond.aheadPlayerId, 1)
  t.assertEquals(gapForSecond.gapMs, 400)
  local gapForThird = tracker:recordCrossing(3, 1, 11000)
  t.assertEquals(gapForThird.aheadPlayerId, 2)
  t.assertEquals(gapForThird.gapMs, 600)
end)

t.test("first finisher starts the DNF timer; timeout marks the rest DNF", function()
  local race, clock = startRaceWith({ 1, 2 })
  race.settings.laps = 1
  race.settings.dnfTimeoutSeconds = 30
  driveCrossings(race, clock, 1, 4, 10000)
  t.assertNil(race:getDueAction())
  clock:advance(30000)
  t.assertEquals(race:getDueAction(), Race.dueAction.dnfTimeout)
  local timedOut = race:applyDnfTimeout()
  t.assertEquals(#timedOut, 1)
  t.assertEquals(race:getRacer(2).dnfReason, "timeout")
  t.assertTrue(race:isComplete())
end)

t.test("implausible race times are flagged", function()
  local race, clock = startRaceWith({ 1 })
  clock:advance(60000)
  local outcome = race:recordCrossing(1, { crossingNumber = 1, raceTimeMs = 20000 })
  t.assertEquals(outcome.isPlausible, false)
end)

t.test("serialize matches the results schema shape", function()
  local race, clock = startRaceWith({ 1, 2 })
  race.settings.laps = 1
  driveCrossings(race, clock, 2, 4, 10000)
  race:markDnf(1, "disconnected")
  race:finish()
  local data = race:serialize()
  t.assertEquals(data.schemaVersion, 1)
  t.assertEquals(data.status, "finished")
  t.assertEquals(data.raceTrack.missionId, "vracer_bajasur/timeTrial/001-Circuito")
  t.assertEquals(data.racers[1].id, 2)
  t.assertEquals(data.racers[1].position, 1)
  t.assertEquals(data.racers[2].status, "dnf")
  t.assertEquals(data.racers[2].dnfReason, "disconnected")
  t.assertEquals(data.owner.id, 1)
end)

return t.runAll("race")
