-- Commands (B-4) through their three entry points, with the real coordinator and races.
local t = require("tests/testRunner")
local fakes = require("tests/server/fakes")
local protocol = require("vracerMP/shared/protocol")
local RaceRegistry = require("vracerMP/races/raceRegistry")
local RaceCoordinator = require("vracerMP/coordinator/raceCoordinator")
local ResultsAnnouncer = require("vracerMP/results/resultsAnnouncer")
local LapRecords = require("vracerMP/records/lapRecords")
local TrackDirectory = require("vracerMP/tracks/trackDirectory")
local CommandEntryPoints = require("vracerMP/commands/commandEntryPoints")
local commandList = require("vracerMP/commands/commandList")
local commandsDoc = require("vracerMP/commands/commandsDoc")

local toClient = protocol.toClient
local pluginEvents = protocol.pluginEvents

local PLAYERS = { [1] = "Ana", [2] = "Bob", [3] = "bob", [4] = "Carl" }
local CIRCUIT = fakes.newTrackData()
local SPRINT = fakes.newTrackData({ missionId = "vracer_bajasur/timeTrial/002-Rancho", name = "Rancho Sprint",
  closed = false, defaultLaps = 1 })

local function newSetup(testingCommands)
  local clock = fakes.newClock(0)
  local network = fakes.newNetwork()
  local registry = RaceRegistry.new(clock)
  local trackDirectory = TrackDirectory.new()
  local playerDirectory = fakes.newPlayerDirectory(PLAYERS)
  local events = fakes.newPluginEvents()
  local coordinator = RaceCoordinator.new({
    registry = registry, network = network, playerDirectory = playerDirectory,
    resultsAnnouncer = ResultsAnnouncer.new(network), lapRecords = LapRecords.new(),
    trackDirectory = trackDirectory, pluginEvents = events,
  })
  local setup = { clock = clock, network = network, registry = registry, coordinator = coordinator,
    pluginEvents = events, chatsByPlayer = {} }
  setup.entryPoints = CommandEntryPoints.new({
    coordinator = coordinator, registry = registry, trackDirectory = trackDirectory,
    playerDirectory = playerDirectory, pluginEvents = events,
    testingCommands = testingCommands ~= false,
    sendChat = function(playerId, text)
      setup.chatsByPlayer[playerId] = setup.chatsByPlayer[playerId] or {}
      table.insert(setup.chatsByPlayer[playerId], text)
    end,
  })
  coordinator:handleRequestLobbies(1, { tracks = { CIRCUIT, SPRINT } })
  return setup
end

local function console(setup, text)
  return setup.entryPoints:runConsoleInput("vracer " .. text)
end

-- Runs a chat command and returns the reply lines joined by newlines.
local function chat(setup, playerId, text)
  setup.chatsByPlayer[playerId] = {}
  t.assertTrue(setup.entryPoints:runChatMessage(playerId, "/vracer " .. text), "handled")
  return table.concat(setup.chatsByPlayer[playerId], "\n")
end

local function getOnlyRace(setup)
  return setup.registry:getAllRaces()[1]
end

t.test("other console input and chat are left alone", function()
  local setup = newSetup()
  t.assertNil(setup.entryPoints:runConsoleInput("status"))
  t.assertTrue(not setup.entryPoints:runChatMessage(1, "hello /vracer"))
  t.assertContains(setup.entryPoints:runConsoleInput("VRACER"), "VRacerMP commands")
end)

t.test("help lists every command and explains one", function()
  local setup = newSetup()
  local help = console(setup, "help")
  for _, command in ipairs(commandList.getCommands(true)) do t.assertContains(help, "vracer " .. command.name) end
  t.assertContains(console(setup, "help CREATE"), "Usage: vracer create --track")
  t.assertContains(chat(setup, 1, "help nope"), "Unknown command \"nope\". Type /vracer help")
end)

t.test("testing commands only exist on a local test server", function()
  local setup = newSetup(false)
  t.assertTrue(not console(setup, "help"):find("vracer fake", 1, true), "fake is not in help")
  console(setup, "create --track bronco")
  t.assertContains(console(setup, "fake"), "Unknown command \"fake\"")
  t.assertContains(console(setup, "help fake"), "Unknown command \"fake\"")
  t.assertEquals(#getOnlyRace(setup).racers, 0)
  t.assertTrue(not commandsDoc.buildCommandSection():find("fake", 1, true), "fake is not in the doc")
end)

t.test("tracks lists what the clients reported", function()
  local setup = newSetup()
  local tracks = console(setup, "tracks")
  t.assertContains(tracks, "001-Circuito: Circuito Bronco Short Course (circuit, 2 laps)")
  t.assertContains(tracks, "002-Rancho: Rancho Sprint (point-to-point)")
end)

t.test("the console creates a server race with settings and players", function()
  local setup = newSetup()
  local reply = console(setup, "create --TRACK bronco --laps 3 --dnf 0 --players ana, BOB, Zed")
  t.assertContains(reply, "Created race r-1 on Circuito Bronco Short Course: 3 laps, no DNF limit")
  t.assertContains(reply, "Added Ana")
  t.assertContains(reply, "Added Bob")
  t.assertContains(reply, "Added bob")
  t.assertContains(reply, "No player named: Zed")
  local lobby = setup.network:getLastPayload(toClient.lobbyUpdated)
  t.assertEquals(lobby.ownerName, "Server")
  t.assertTrue(lobby.serverOwned)
  t.assertEquals(#lobby.racers, 3)
  t.assertEquals(setup.pluginEvents:getLastPayload(pluginEvents.raceUpdated).raceId, "r-1")
end)

t.test("create checks the track and the settings before making a race", function()
  local setup = newSetup()
  t.assertContains(console(setup, "create --track nowhere"), "No track matches")
  t.assertContains(console(setup, "create --track rancho --laps 2"), "Point-to-point tracks are always 1 lap")
  t.assertContains(console(setup, "create --track 001-circuito --laps x"), "--laps needs a whole number")
  t.assertContains(console(setup, "create --track bronco --color red"), "Unknown option --color")
  t.assertEquals(#setup.registry:getAllRaces(), 0)
end)

t.test("a server race stays open when its last player leaves", function()
  local setup = newSetup()
  console(setup, "create --track bronco --players Ana")
  t.assertContains(console(setup, "remove --players Ana"), "Removed Ana")
  t.assertEquals(#getOnlyRace(setup).racers, 0)
  t.assertContains(console(setup, "races"), "r-1 Circuito Bronco Short Course: registering, owner Server")
end)

t.test("the console starts a race: players are sent to the grid", function()
  local setup = newSetup()
  console(setup, "create --track bronco --players Ana, Carl")
  t.assertContains(console(setup, "start r-1"), "is starting with 2 racers")
  t.assertEquals(setup.network:getLastPayload(toClient.raceStarting, 4).gridSlot, 2)
  t.assertContains(console(setup, "set --laps 5"), "already started")
end)

t.test("in chat the creator owns the race and is registered", function()
  local setup = newSetup()
  local reply = chat(setup, 1, "create --track rancho --players Carl")
  t.assertContains(reply, "Created race r-1 on Rancho Sprint")
  t.assertContains(reply, "Added Carl")
  local race = getOnlyRace(setup)
  t.assertEquals(race.ownerPlayerId, 1)
  t.assertEquals(#race.racers, 2)
  t.assertContains(chat(setup, 1, "set --dnf 30"), "1 lap, DNF 30 s")
end)

t.test("players may add and remove themselves; only the owner manages others", function()
  local setup = newSetup()
  chat(setup, 1, "create --track bronco")
  t.assertContains(chat(setup, 4, "add"), "Added Carl")
  t.assertContains(chat(setup, 4, "remove --players Ana"), "Only the race owner")
  t.assertContains(chat(setup, 4, "start"), "Only the race owner can start")
  t.assertContains(chat(setup, 4, "cancel"), "Only the race owner")
  t.assertContains(chat(setup, 4, "fake"), "Only the race owner")
  t.assertContains(chat(setup, 4, "remove"), "Removed Carl")
  t.assertContains(chat(setup, 1, "fake r-1 30"), "Fake racer 1 joined (30 s per lap)")
end)

t.test("--all registers everyone not in a race yet", function()
  local setup = newSetup()
  console(setup, "create --track rancho --players Carl")
  local reply = console(setup, "create --track bronco --all")
  t.assertContains(reply, "Added Ana")
  t.assertContains(reply, "Added bob")
  t.assertContains(reply, "Already in a race: Carl")
  console(setup, "remove r-2 --players Ana")
  t.assertEquals(console(setup, "add r-2 --all"), "Added Ana\nAlready in a race: Carl")
  console(setup, "cancel r-1")
  console(setup, "add r-2 --all")
  t.assertEquals(console(setup, "add r-2 --all"), "Nobody to add")
  t.assertContains(console(setup, "add r-2 --all --players Ana"), "Use either --all or --players")
  t.assertContains(console(setup, "add r-2 --all now"), "--all takes no value")
end)

t.test("in chat only the owner can add everyone", function()
  local setup = newSetup()
  chat(setup, 1, "create --track bronco")
  t.assertContains(chat(setup, 4, "add --all"), "Only the race owner")
  t.assertContains(chat(setup, 1, "add --all"), "Added Carl")
end)

t.test("a race must be named when there are several", function()
  local setup = newSetup()
  console(setup, "create --track bronco")
  console(setup, "create --track rancho")
  t.assertContains(console(setup, "start"), "Name the race: r-1, r-2")
  t.assertContains(console(setup, "start r-9"), "No race r-9. Races: r-1, r-2")
  t.assertContains(console(setup, "create --track bronco"), "already an open race")
end)

t.test("cancel ends a running race without results", function()
  local setup = newSetup()
  console(setup, "create --track bronco --players Ana")
  console(setup, "start")
  t.assertContains(console(setup, "cancel"), "r-1 Circuito Bronco Short Course was cancelled")
  t.assertContains(setup.network:getLastPayload(toClient.notice, 1).message, "was cancelled")
  t.assertEquals(#setup.network:getMessages(toClient.raceRemoved), 1)
  t.assertNil(setup.network:getLastPayload(toClient.raceResults, 1))
  t.assertEquals(setup.pluginEvents:getLastPayload(pluginEvents.raceRemoved).raceId, "r-1")
end)

t.test("plugins get a JSON reply, also published as an event", function()
  local setup = newSetup()
  local reply = setup.entryPoints:runPluginCommand("create --track bronco", "tablet-7")
  t.assertContains(reply, '"ok":true')
  t.assertContains(reply, '"requestId":"tablet-7"')
  local published = setup.pluginEvents:getLastPayload(pluginEvents.commandReply)
  t.assertEquals(published.requestId, "tablet-7")
  t.assertContains(published.lines[1], "Created race r-1")
  t.assertContains(setup.entryPoints:runPluginCommand("start r-5"), '"ok":false')
end)

t.test("docs/commands.md matches the command list", function()
  local file = io.open("docs/commands.md", "r")
  t.assertTrue(file ~= nil, "docs/commands.md exists")
  local text = file:read("*a"):gsub("\r\n", "\n") -- Git may check it out with Windows line ends
  file:close()
  t.assertTrue(text:find(commandsDoc.buildCommandSection(), 1, true) ~= nil,
    "run: python tools/writeCommandsDoc.py")
end)

return t.runAll("commands")
