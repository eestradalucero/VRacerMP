local t = require("tests/testRunner")
local fakes = require("tests/server/fakes")
local protocol = require("vracerMP/shared/protocol")
local RaceRegistry = require("vracerMP/races/raceRegistry")
local RaceCoordinator = require("vracerMP/coordinator/raceCoordinator")
local ResultsAnnouncer = require("vracerMP/results/resultsAnnouncer")
local chatCommands = require("vracerMP/coordinator/chatCommands")

local toClient = protocol.toClient

local function newSetup()
  local clock = fakes.newClock(0)
  local network = fakes.newNetwork()
  local coordinator = RaceCoordinator.new({
    registry = RaceRegistry.new(clock),
    network = network,
    playerDirectory = fakes.newPlayerDirectory(),
    resultsAnnouncer = ResultsAnnouncer.new(network),
  })
  return { clock = clock, network = network, coordinator = coordinator }
end

local function register(setup, playerId)
  setup.coordinator:handleRegister(playerId, { track = fakes.newTrackData(), vehicle = { model = "etk800", config = "856_m" } })
end

local function getRaceId(setup)
  return setup.network:getLastPayload(toClient.lobbyUpdated).raceId
end

-- Moves the clock forward in 100 ms ticks, like the server timer.
local function runTicks(setup, totalMs)
  for _ = 1, math.floor(totalMs / 100) do
    setup.clock:advance(100)
    setup.coordinator:handleTick()
  end
end

local function reportCrossing(setup, playerId, raceId, crossingNumber, raceTimeMs, lapCompleted)
  setup.coordinator:handlePathnodeReached(playerId, {
    raceId = raceId, crossingNumber = crossingNumber, raceTimeMs = raceTimeMs, lapCompleted = lapCompleted,
  })
end

t.test("register broadcasts the lobby with the owner", function()
  local setup = newSetup()
  register(setup, 4)
  local lobby = setup.network:getLastPayload(toClient.lobbyUpdated)
  t.assertEquals(lobby.ownerId, 4)
  t.assertEquals(lobby.laps, 2)
  t.assertEquals(#lobby.racers, 1)
end)

t.test("a player cannot register twice", function()
  local setup = newSetup()
  register(setup, 4)
  register(setup, 4)
  t.assertContains(setup.network:getLastPayload(toClient.notice, 4).message, "already registered")
end)

t.test("non-owner start is rejected with a notice", function()
  local setup = newSetup()
  register(setup, 1)
  register(setup, 2)
  setup.coordinator:handleStartRace(2, { raceId = getRaceId(setup) })
  t.assertContains(setup.network:getLastPayload(toClient.notice, 2).message, "owner")
end)

t.test("full race: grid, countdown, go, gaps, finish, results", function()
  local setup = newSetup()
  register(setup, 1)
  register(setup, 2)
  local raceId = getRaceId(setup)
  setup.coordinator:handleConfigure(1, { raceId = raceId, laps = 1 })
  setup.coordinator:handleStartRace(1, { raceId = raceId })
  t.assertEquals(setup.network:getLastPayload(toClient.raceStarting, 2).gridSlot, 2)

  setup.coordinator:handleGridReady(1, { raceId = raceId })
  setup.coordinator:handleGridReady(2, { raceId = raceId })
  t.assertEquals(setup.network:getLastPayload(toClient.countdown, 1).goInMs, 3000)
  runTicks(setup, 3000)
  t.assertEquals(#setup.network:getMessages(toClient.go, 1), 1)

  for crossing = 1, 4 do
    local lapCompleted = crossing == 4
    setup.clock:advance(10000)
    reportCrossing(setup, 1, raceId, crossing, crossing * 10000, lapCompleted)
    reportCrossing(setup, 2, raceId, crossing, crossing * 10000 + 250, lapCompleted)
  end

  t.assertEquals(setup.network:getLastPayload(toClient.gap, 2).kind, "ahead")
  t.assertEquals(setup.network:getLastPayload(toClient.gap, 2).gapMs, 250)
  t.assertEquals(setup.network:getLastPayload(toClient.gap, 1).kind, "behind")
  t.assertEquals(setup.network:getLastPayload(toClient.racerFinished, 1).position, 1)
  t.assertEquals(setup.network:getLastPayload(toClient.racerFinished, 2).position, 2)

  local results = setup.network:getLastPayload(toClient.raceResults, 1)
  t.assertEquals(results.status, "finished")
  t.assertEquals(results.racers[2].raceStats.gapToWinner, 250)
  t.assertEquals(#setup.network.chats, 1, "results are announced once, at the end")
  t.assertContains(setup.network.chats[1], '"status":"finished"')
  t.assertContains(setup.network.chats[1], '"lapTimesReadable":["00:40.000"]')
  t.assertEquals(#setup.network:getMessages(toClient.raceRemoved), 1)
end)

t.test("disconnect during the race is DNF and can end the race", function()
  local setup = newSetup()
  register(setup, 1)
  register(setup, 2)
  local raceId = getRaceId(setup)
  setup.coordinator:handleStartRace(1, { raceId = raceId })
  setup.coordinator:handleGridReady(1, { raceId = raceId })
  setup.coordinator:handleGridReady(2, { raceId = raceId })
  runTicks(setup, 3000)
  setup.coordinator:handlePlayerDisconnect(2)
  t.assertEquals(setup.network:getLastPayload(toClient.standings, 1).entries[2].status, "dnf")
  t.assertEquals(#setup.network.chats, 0, "nothing is announced while the race runs")
  setup.coordinator:handleUnregister(1, { raceId = raceId })
  t.assertContains(setup.network.chats[1], '"dnfReason":"disconnected"')
  t.assertContains(setup.network.chats[1], '"status":"finished"')
end)

t.test("grid timeout starts the countdown without missing racers", function()
  local setup = newSetup()
  register(setup, 1)
  register(setup, 2)
  local raceId = getRaceId(setup)
  setup.coordinator:handleStartRace(1, { raceId = raceId })
  setup.coordinator:handleGridReady(1, { raceId = raceId })
  runTicks(setup, 10000)
  t.assertEquals(#setup.network:getMessages(toClient.countdown, 1), 1)
  runTicks(setup, 3000)
  t.assertEquals(setup.network:getLastPayload(toClient.racerFinished, 2).dnfReason, "notOnGrid")
end)

t.test("last player leaving the lobby removes the race", function()
  local setup = newSetup()
  register(setup, 1)
  setup.coordinator:handleUnregister(1, { raceId = getRaceId(setup) })
  t.assertEquals(#setup.network:getMessages(toClient.raceRemoved), 1)
end)

t.test("fake racers race alone and the real player gets positions and gaps", function()
  local setup = newSetup()
  register(setup, 1)
  local reply = chatCommands.runCommand(setup.coordinator, 1, "/vracer fake 40")
  t.assertContains(reply, "Fake racer 1 joined")
  local raceId = getRaceId(setup)
  setup.coordinator:handleConfigure(1, { raceId = raceId, laps = 1 })
  setup.coordinator:handleStartRace(1, { raceId = raceId })
  setup.coordinator:handleGridReady(1, { raceId = raceId })
  runTicks(setup, 3000 + 11000) -- fake racer has crossed its first pathnode (10 s pace)
  reportCrossing(setup, 1, raceId, 1, 12000, false)
  t.assertEquals(setup.network:getLastPayload(toClient.gap, 1).kind, "ahead")
  t.assertEquals(setup.network:getLastPayload(toClient.standings, 1).entries[1].id, -1)
  runTicks(setup, 40000)
  t.assertEquals(setup.network:getLastPayload(toClient.standings, 1).entries[1].status, "finished")
  runTicks(setup, 120000) -- the real player never finishes: DNF timer ends the race
  t.assertEquals(setup.network:getLastPayload(toClient.raceResults, 1).racers[2].dnfReason, "timeout")
  t.assertContains(setup.network.chats[1], '"name":"Fake racer 1"')
end)

t.test("non-commands are not handled by chat commands", function()
  local setup = newSetup()
  t.assertNil(chatCommands.runCommand(setup.coordinator, 1, "hello"))
  t.assertContains(chatCommands.runCommand(setup.coordinator, 1, "/vracer"), "commands")
end)

return t.runAll("raceCoordinator")
