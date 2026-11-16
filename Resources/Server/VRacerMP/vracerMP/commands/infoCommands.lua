-- VRacerMP server: commands that only show information (B-4).
-- Each run(context, command) returns ok (true/false) and the reply lines.

local raceText = require("vracerMP/commands/raceText")

local M = {}

-- tracks
local function runTracks(context)
  local tracks = context.trackDirectory:getAllTracks()
  if #tracks == 0 then return true, { "No tracks known yet: a player has to join the server first" } end
  local lines = { "Tracks on this map (" .. #tracks .. "):" }
  for _, track in ipairs(tracks) do table.insert(lines, raceText.describeTrack(track)) end
  return true, lines
end

-- races
local function runRaces(context)
  local races = context.registry:getAllRaces()
  if #races == 0 then return true, { "There are no races" } end
  local lines = {}
  for _, race in ipairs(races) do table.insert(lines, raceText.describeRace(race)) end
  return true, lines
end

M.runTracks = runTracks
M.runRaces = runRaces

return M
