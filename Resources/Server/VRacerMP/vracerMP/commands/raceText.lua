-- VRacerMP server: short descriptions of races and tracks for command replies (B-4). Pure.

local M = {}

local function getDnfText(seconds)
  if seconds == 0 then return "no DNF limit" end
  return "DNF " .. tostring(seconds) .. " s"
end

local function getLapsText(laps)
  return laps == 1 and "1 lap" or (tostring(laps) .. " laps")
end

-- "2 laps, DNF 120 s"
local function getSettingsText(race)
  return getLapsText(race.settings.laps) .. ", " .. getDnfText(race.settings.dnfTimeoutSeconds)
end

local function getRacerNames(race)
  local names = {}
  for index, racer in ipairs(race.racers) do names[index] = racer.name end
  if #names == 0 then return "nobody yet" end
  return table.concat(names, ", ")
end

-- "r-1 Circuito Bronco: registering, owner Server, 2 laps, DNF 120 s. Racers: Ana, Bob"
local function describeRace(race)
  local owner = race:getOwnerName()
  return string.format("%s %s: %s, owner %s, %s. Racers: %s", race.raceId, race.track.name, race.state,
    owner ~= "" and owner or "nobody", getSettingsText(race), getRacerNames(race))
end

-- "001-Circuito: Circuito Bronco (circuit, 2 laps)"
local function describeTrack(track)
  local layout = track.closed and ("circuit, " .. getLapsText(track.defaultLaps)) or "point-to-point"
  return string.format("%s: %s (%s)", track:getMissionFolderName(), track.name, layout)
end

local function listNames(players)
  local names = {}
  for index, player in ipairs(players) do names[index] = player.name or player end
  return table.concat(names, ", ")
end

M.getSettingsText = getSettingsText
M.describeRace = describeRace
M.describeTrack = describeTrack
M.listNames = listNames

return M
