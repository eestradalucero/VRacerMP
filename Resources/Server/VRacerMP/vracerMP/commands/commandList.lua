-- VRacerMP server: every command, in one list (B-4).
-- `help` and docs/commands.md are both built from this list, so they cannot drift apart
-- (regenerate the doc with: python tools/writeCommandsDoc.py).
--
-- A command: { name, usage, summary, details = { lines }, options = { allowed names },
--              maxArguments, isForTesting?, run(context, command) -> ok, lines }
-- Commands for testing (isForTesting) only exist where the server allows them
-- (serverOptions.testingCommands): they are left out of help and the doc, and cannot be run.

local raceCommands = require("vracerMP/commands/raceCommands")
local infoCommands = require("vracerMP/commands/infoCommands")

local M = {}

local RACE_ARGUMENT_NOTE = "[race] is a race id like r-1. Leave it out when there is only one race; "
  .. "in chat it defaults to the race you own or are in."

local commands = {}

-- The commands that exist here: testing commands only when includeTesting is true.
local function getCommands(includeTesting)
  local available = {}
  for _, command in ipairs(commands) do
    if includeTesting or not command.isForTesting then table.insert(available, command) end
  end
  return available
end

-- help is defined below: it needs the whole list.
local function findCommand(name, includeTesting)
  for _, command in ipairs(getCommands(includeTesting)) do
    if command.name == name then return command end
  end
  return nil
end

local function describeOneCommand(prefix, command)
  local lines = { "Usage: " .. prefix .. command.usage, command.summary }
  for _, line in ipairs(command.details or {}) do table.insert(lines, line) end
  return lines
end

local function describeAllCommands(prefix, includeTesting)
  local lines = { "VRacerMP commands (" .. prefix .. "help <command> for details):" }
  for _, command in ipairs(getCommands(includeTesting)) do
    table.insert(lines, prefix .. command.name .. " - " .. command.summary)
  end
  return lines
end

-- help [command]
local function runHelp(context, command)
  local name = command.arguments[1]
  if not name then return true, describeAllCommands(context.prefix, context.testingCommands) end
  local described = findCommand(name:lower(), context.testingCommands)
  if not described then return false, { "Unknown command \"" .. name .. "\". Type " .. context.prefix .. "help" } end
  return true, describeOneCommand(context.prefix, described)
end

commands = {
  {
    name = "help", usage = "help [command]", summary = "List the commands, or explain one.",
    options = {}, maxArguments = 1, run = runHelp,
  },
  {
    name = "tracks", usage = "tracks", summary = "List the race tracks of this map.",
    details = { "Shows each track's id (its mission folder), name and layout. Players' games report the "
      .. "tracks when they join, so the list is empty until someone joins." },
    options = {}, maxArguments = 0, run = infoCommands.runTracks,
  },
  {
    name = "races", usage = "races", summary = "List the races: id, track, state, owner, settings, racers.",
    options = {}, maxArguments = 0, run = infoCommands.runRaces,
  },
  {
    name = "create", usage = "create --track <id or name> [--laps N] [--dnf S] [--players a,b | --all]",
    summary = "Create a race on a track.",
    details = {
      "--track: the track's id or name (see tracks); part of the name works when only one track matches.",
      "--laps: 1-99 (always 1 on point-to-point tracks). Default: the track's laps.",
      "--dnf: seconds the others get after the first finisher, 10-3600, or 0 for no limit. Default: 120.",
      "--players: players to register, by in-game name, separated by commas.",
      "--all: register every player on the server who is not in a race yet.",
      "From the console or a plugin the server owns the race. In chat you own it and are registered too.",
    },
    options = { "track", "laps", "dnf", "players", "all" }, maxArguments = 0, run = raceCommands.runCreate,
  },
  {
    name = "add", usage = "add [race] --players a,b | --all", summary = "Register players in a race.",
    details = {
      "Players are found by in-game name, ignoring case; two players with the same name are both added.",
      "--all registers every player on the server who is not in a race yet; those racing elsewhere are listed.",
      "They do not need to be at the start area: the start moves them to the grid.",
      "In chat, leave out --players to add yourself. Only the owner can add others.",
      RACE_ARGUMENT_NOTE,
    },
    options = { "players", "all" }, maxArguments = 1, run = raceCommands.runAdd,
  },
  {
    name = "remove", usage = "remove [race] --players a | --all",
    summary = "Unregister players (after the start they retire: DNF).",
    details = {
      "In chat, leave out --players to remove yourself. Only the owner can remove others.",
      "--all removes every racer still in the race; from the grid on they retire, and the race ends "
        .. "as when everyone retires (before GO it is cancelled). Only the owner can use it.",
      RACE_ARGUMENT_NOTE,
    },
    options = { "players", "all" }, maxArguments = 1, run = raceCommands.runRemove,
  },
  {
    name = "set", usage = "set [race] [--laps N] [--dnf S]", summary = "Change a race's settings before the start.",
    details = { "Same values as create; --dnf 0 means no limit. Only the owner can change settings.", RACE_ARGUMENT_NOTE },
    options = { "laps", "dnf" }, maxArguments = 1, run = raceCommands.runSet,
  },
  {
    name = "start", usage = "start [race]", summary = "Start a race: racers are moved to the grid.",
    details = { "Only the owner can start a race.", RACE_ARGUMENT_NOTE },
    options = {}, maxArguments = 1, run = raceCommands.runStart,
  },
  {
    name = "finish", usage = "finish [race]", summary = "End a running race now, with results.",
    details = {
      "Racers who finished keep their result; everyone still racing is DNF (stopped).",
      "Only while the race is running; before GO use cancel. Only the owner can finish a race.",
      RACE_ARGUMENT_NOTE,
    },
    options = {}, maxArguments = 1, run = raceCommands.runFinish,
  },
  {
    name = "cancel", usage = "cancel [race]", summary = "Cancel a race at any point; nobody gets results.",
    details = { "Only the owner can cancel a race.", RACE_ARGUMENT_NOTE },
    options = {}, maxArguments = 1, run = raceCommands.runCancel,
  },
  {
    name = "fake", usage = "fake [race] [lapSeconds]", summary = "Add a fake racer, for testing alone.",
    details = { "It laps at a steady pace (default 90 s per lap). Only the owner can add one.",
      "Only on a local test server (installed with tools/build.ps1 -ServerPath).", RACE_ARGUMENT_NOTE },
    options = {}, maxArguments = 2, isForTesting = true, run = raceCommands.runFake,
  },
}

M.findCommand = findCommand
M.getCommands = getCommands

return M
