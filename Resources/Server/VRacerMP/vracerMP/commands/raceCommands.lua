-- VRacerMP server: the commands that create and run races (B-4).
-- Each run(context, command) returns ok (true/false) and the reply lines.
-- See commandTargets.lua for `context` and commandLine.lua for `command`.

local targets = require("vracerMP/commands/commandTargets")
local raceText = require("vracerMP/commands/raceText")

local M = {}

local NOT_OWNER = "Only the race owner can do that"

local function fail(message)
  return false, { message }
end

-- Registers or unregisters each player; one reply line per player, plus the names not found.
local function changeEachPlayer(players, changePlayer, doneWord, failWord)
  local lines = {}
  for _, player in ipairs(players.found) do
    local changed, changeError = changePlayer(player.playerId)
    if changed then
      table.insert(lines, doneWord .. " " .. player.name)
    else
      table.insert(lines, "Could not " .. failWord .. " " .. player.name .. ": " .. changeError)
    end
  end
  if #players.missing > 0 then
    table.insert(lines, "No player named: " .. raceText.listNames(players.missing))
  end
  if #players.busy > 0 then
    table.insert(lines, "Already in a race: " .. raceText.listNames(players.busy))
  end
  return lines
end

local function registerPlayers(context, race, players)
  local lines = changeEachPlayer(players, function(playerId)
    return context.coordinator:registerPlayer(race, playerId, nil)
  end, "Added", "add")
  if #players.found == 0 then table.insert(lines, 1, "Nobody to add") end
  return lines
end

local function hasPlayerOptions(command)
  return command.options.players ~= nil or command.options.all ~= nil
end

-- create --track <id or name> [--laps N] [--dnf S] [--players a,b | --all]
local function runCreate(context, command)
  local allIsValid, allError = targets.checkAllOption(command)
  if not allIsValid then return fail(allError) end
  local track, trackError = context.trackDirectory:findTrack(command.options.track)
  if not track then return fail(trackError) end
  local changes, changesError = targets.readSettingChanges(command)
  if not changes then return fail(changesError) end
  local valid, invalidReason = targets.validateSettingChanges(track, changes)
  if not valid then return fail(invalidReason) end

  local race, createError = context.coordinator:createRace(track, context.requester)
  if not race then return fail(createError) end
  if targets.hasChanges(changes) then context.coordinator:configureRace(race, context.requester, changes) end

  local lines = { "Created race " .. race.raceId .. " on " .. track.name .. ": " .. raceText.getSettingsText(race) }
  if hasPlayerOptions(command) then
    for _, line in ipairs(registerPlayers(context, race, targets.findTargetPlayers(context, command, race))) do
      table.insert(lines, line)
    end
  end
  return true, lines
end

-- add [race] --players a,b | --all  (players may leave both out to add themselves)
local function runAdd(context, command)
  local race, raceError = targets.findRace(context, command)
  if not race then return fail(raceError) end
  local players, playersError = targets.findTargetPlayers(context, command, race)
  if not players then return fail(playersError) end
  if not targets.canChangePlayers(context, race, players) then return fail(NOT_OWNER) end
  return true, registerPlayers(context, race, players)
end

-- remove [race] --players a  (players may leave out --players to remove themselves)
local function runRemove(context, command)
  local race, raceError = targets.findRace(context, command)
  if not race then return fail(raceError) end
  local players, playersError = targets.findTargetPlayers(context, command, race)
  if not players then return fail(playersError) end
  if not targets.canChangePlayers(context, race, players) then return fail(NOT_OWNER) end
  return true, changeEachPlayer(players, function(playerId)
    return context.coordinator:unregisterPlayer(race, playerId)
  end, "Removed", "remove")
end

-- set [race] [--laps N] [--dnf S]
local function runSet(context, command)
  local race, raceError = targets.findRace(context, command)
  if not race then return fail(raceError) end
  local changes, changesError = targets.readSettingChanges(command)
  if not changes then return fail(changesError) end
  if not targets.hasChanges(changes) then return fail("Nothing to change: use --laps and/or --dnf") end
  local changed, changeError = context.coordinator:configureRace(race, context.requester, changes)
  if not changed then return fail(changeError) end
  return true, { race.raceId .. " " .. race.track.name .. ": " .. raceText.getSettingsText(race) }
end

-- start [race]
local function runStart(context, command)
  local race, raceError = targets.findRace(context, command)
  if not race then return fail(raceError) end
  local started, startError = context.coordinator:startRace(race, context.requester)
  if not started then return fail(startError) end
  return true, { race.raceId .. " " .. race.track.name .. " is starting with " .. #race.racers .. " racers" }
end

-- cancel [race]
local function runCancel(context, command)
  local race, raceError = targets.findRace(context, command)
  if not race then return fail(raceError) end
  if not targets.canManage(context, race) then return fail(NOT_OWNER) end
  context.coordinator:cancelRace(race)
  return true, { race.raceId .. " " .. race.track.name .. " was cancelled" }
end

-- fake [race] [lapSeconds]
local function runFake(context, command)
  local race, raceError = targets.findRace(context, command)
  if not race then return fail(raceError) end
  if not targets.canManage(context, race) then return fail(NOT_OWNER) end
  local added, message = context.coordinator:addFakeRacer(race, tonumber(command.arguments[1]))
  return added, { message }
end

M.runCreate = runCreate
M.runAdd = runAdd
M.runRemove = runRemove
M.runSet = runSet
M.runStart = runStart
M.runCancel = runCancel
M.runFake = runFake

return M
