-- VRacerMP server: finds what a command is about (B-4): the race, the players, the settings.
--
-- context = { coordinator, registry, trackDirectory, playerDirectory, requester, prefix,
--             testingCommands }
-- `requester` is the player who typed the command, or Race.SERVER for the console or a plugin.

local Race = require("vracerMP/races/race")
local RaceSettings = require("vracerMP/races/raceSettings")
local commandLine = require("vracerMP/commands/commandLine")

local M = {}

local function isServer(context)
  return context.requester == Race.SERVER
end

local function isRaceId(word)
  return type(word) == "string" and word:lower():match("^r%-%d+$") ~= nil
end

-- Takes the race id ("r-1") from the front of the arguments, if there is one.
local function takeRaceId(command)
  if not isRaceId(command.arguments[1]) then return nil end
  return table.remove(command.arguments, 1):lower()
end

local function listRaceIds(races)
  local raceIds = {}
  for index, race in ipairs(races) do raceIds[index] = race.raceId end
  return table.concat(raceIds, ", ")
end

local function findRaceOwnedBy(races, playerId)
  for _, race in ipairs(races) do
    if race.ownerPlayerId == playerId then return race end
  end
  return nil
end

local function findOnlyRace(races)
  if #races == 1 then return races[1] end
  if #races == 0 then return nil, "There are no races" end
  return nil, "Name the race: " .. listRaceIds(races)
end

-- No race named: in chat the race you own, else the race you are in; otherwise the only race.
local function findDefaultRace(context)
  local races = context.registry:getAllRaces()
  if not isServer(context) then
    local race = findRaceOwnedBy(races, context.requester) or context.registry:findRaceOfPlayer(context.requester)
    if race then return race end
  end
  return findOnlyRace(races)
end

-- The race named by the command's first argument, or the default race.
-- Returns the race, or nil and a message.
local function findRace(context, command)
  local raceId = takeRaceId(command)
  if not raceId then return findDefaultRace(context) end
  local race = context.registry:findRaceById(raceId)
  if race then return race end
  local races = context.registry:getAllRaces()
  if #races == 0 then return nil, "No race " .. raceId .. ": there are no races" end
  return nil, "No race " .. raceId .. ". Races: " .. listRaceIds(races)
end

-- The console and plugins may manage every race; players only the races they own.
local function canManage(context, race)
  return race:isOwner(context.requester)
end

-- Players named in --players, as { found = { { playerId, name } }, missing = { name },
-- busy = { player } }. `busy` is only filled by --all.
-- Two players with the same name are both found.
local function findNamedPlayers(context, namesText)
  local players = { found = {}, missing = {}, busy = {} }
  for _, name in ipairs(commandLine.splitList(namesText)) do
    local playerIds = context.playerDirectory.findPlayerIdsByName(name)
    if #playerIds == 0 then table.insert(players.missing, name) end
    for _, playerId in ipairs(playerIds) do
      table.insert(players.found, { playerId = playerId, name = context.playerDirectory.getPlayerName(playerId) })
    end
  end
  return players
end

local function toPlayer(context, playerId)
  return { playerId = playerId, name = context.playerDirectory.getPlayerName(playerId) }
end

-- --all: every connected player who is in no race yet. Players racing elsewhere are listed
-- as busy; players already in this race are left out.
local function findAllPlayers(context, race)
  local players = { found = {}, missing = {}, busy = {} }
  for _, playerId in ipairs(context.playerDirectory.getConnectedPlayerIds()) do
    local playersRace = context.registry:findRaceOfPlayer(playerId)
    if not playersRace then
      table.insert(players.found, toPlayer(context, playerId))
    elseif playersRace ~= race then
      table.insert(players.busy, toPlayer(context, playerId))
    end
  end
  return players
end

-- Checks --all against --players. Returns true, or false and a message.
local function checkAllOption(command)
  if command.options.all == nil then return true end
  if command.options.all ~= "" then return false, "--all takes no value" end
  if command.options.players then return false, "Use either --all or --players" end
  return true
end

-- --players, --all, or the player who typed the command when both are left out.
-- Returns the players (see findNamedPlayers), or nil and a message.
local function findTargetPlayers(context, command, race)
  local allIsValid, allError = checkAllOption(command)
  if not allIsValid then return nil, allError end
  if command.options.all then return findAllPlayers(context, race) end
  if command.options.players then return findNamedPlayers(context, command.options.players) end
  if isServer(context) then return nil, "Name the players: --players Ana, Bob, or --all" end
  return { found = { toPlayer(context, context.requester) }, missing = {}, busy = {} }
end

local function isOnlyTheRequester(context, players)
  for _, player in ipairs(players.found) do
    if player.playerId ~= context.requester then return false end
  end
  return true
end

-- Anyone may add or remove themselves; only the owner (or the server) may do it for others.
local function canChangePlayers(context, race, players)
  return canManage(context, race) or isOnlyTheRequester(context, players)
end

-- { laps?, dnfTimeoutSeconds? } from --laps and --dnf. Returns the changes, or nil and a message.
local function readSettingChanges(command)
  local changes = {}
  local readError
  if command.options.laps then
    changes.laps, readError = commandLine.readWholeNumber(command.options.laps, "laps")
    if readError then return nil, readError end
  end
  if command.options.dnf then
    changes.dnfTimeoutSeconds, readError = commandLine.readWholeNumber(command.options.dnf, "dnf")
    if readError then return nil, readError end
  end
  return changes
end

local function hasChanges(changes)
  return next(changes) ~= nil
end

-- Checks the changes against a track's rules without touching any race.
local function validateSettingChanges(track, changes)
  return RaceSettings.new(track):applyChanges(changes, track)
end

M.isServer = isServer
M.findRace = findRace
M.takeRaceId = takeRaceId
M.canManage = canManage
M.checkAllOption = checkAllOption
M.findTargetPlayers = findTargetPlayers
M.canChangePlayers = canChangePlayers
M.readSettingChanges = readSettingChanges
M.hasChanges = hasChanges
M.validateSettingChanges = validateSettingChanges

return M
