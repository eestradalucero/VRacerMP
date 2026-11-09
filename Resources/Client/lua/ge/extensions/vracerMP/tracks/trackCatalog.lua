-- VRacerMP client: finds the race tracks of the loaded level (edge: game file system).
-- Tracks are time-trial missions: /gameplay/missions/<level>/timeTrial/<mission>/ (TRK-1, TRK-4).

local TrackInfo = require("vracerMP/tracks/trackInfo")

local M = {}

local logTag = "vracerMP.tracks"
local MISSIONS_ROOT = "/gameplay/missions/"
local TIME_TRIAL_FOLDER = "/timeTrial/"

local function findTimeTrialInfoFiles()
  local infoFiles = {}
  for _, path in ipairs(FS:findFiles(MISSIONS_ROOT, "info.json", -1, true, false) or {}) do
    if path:lower():find(TIME_TRIAL_FOLDER:lower(), 1, true) then
      table.insert(infoFiles, path)
    end
  end
  return infoFiles
end

local function isForLevel(info, levelName)
  local trigger = info.startTrigger or {}
  return type(trigger.level) == "string" and trigger.level:lower() == levelName:lower()
end

local function loadTrack(infoPath, levelName)
  local info = jsonReadFile(infoPath)
  if not info or info.missionType ~= "timeTrial" or not isForLevel(info, levelName) then return nil end
  local missionFolder = infoPath:match("^(.*)/info%.json$")
  local raceData = jsonReadFile(missionFolder .. "/race.race.json")
  if not raceData then return nil end
  local track = TrackInfo.fromMissionFiles(missionFolder, info, raceData)
  if not track:isRaceable() then
    log('W', logTag, "skipping " .. track.missionId .. ": branching, no pathnodes or no start position")
    return nil
  end
  return track
end

-- Returns the list of TrackInfo for `levelName`, sorted by name.
local function loadTracksForLevel(levelName)
  local tracks = {}
  if not levelName then return tracks end
  for _, infoPath in ipairs(findTimeTrialInfoFiles()) do
    local track = loadTrack(infoPath, levelName)
    if track then table.insert(tracks, track) end
  end
  table.sort(tracks, function(a, b) return a.name < b.name end)
  log('I', logTag, "found " .. #tracks .. " race tracks for " .. levelName)
  return tracks
end

local function findTrackById(tracks, missionId)
  for _, track in ipairs(tracks) do
    if track.missionId == missionId then return track end
  end
  return nil
end

M.loadTracksForLevel = loadTracksForLevel
M.findTrackById = findTrackById

return M
