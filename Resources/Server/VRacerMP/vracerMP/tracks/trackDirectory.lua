-- VRacerMP server: class TrackDirectory, the race tracks of the current map (B-4).
-- The track files live on the clients: each client reports its tracks when it joins, and the
-- server keeps them in memory (no files). Commands use it to find a track by id or name.

local TrackRef = require("vracerMP/races/trackRef")

local TrackDirectory = {}
TrackDirectory.__index = TrackDirectory

local MAX_TRACKS_PER_REPORT = 500

function TrackDirectory.new()
  local self = setmetatable({}, TrackDirectory)
  self.tracksByMissionId = {}
  return self
end

-- trackDataList: what a client sent (see TrackRef.fromClientData). Unusable entries are skipped.
-- Read with pairs, so it does not depend on how the JSON decoder numbers a list.
-- Returns how many tracks were usable.
function TrackDirectory:reportTracks(trackDataList)
  if type(trackDataList) ~= "table" then return 0 end
  local readCount, usableCount = 0, 0
  for _, trackData in pairs(trackDataList) do
    readCount = readCount + 1
    if readCount > MAX_TRACKS_PER_REPORT then break end
    local track = TrackRef.fromClientData(trackData)
    if track then
      self.tracksByMissionId[track.missionId] = track
      usableCount = usableCount + 1
    end
  end
  return usableCount
end

-- Every known track, sorted by name.
function TrackDirectory:getAllTracks()
  local tracks = {}
  for _, track in pairs(self.tracksByMissionId) do table.insert(tracks, track) end
  table.sort(tracks, function(a, b) return a.name:lower() < b.name:lower() end)
  return tracks
end

local function getSearchableTexts(track)
  return { track.missionId:lower(), track:getMissionFolderName():lower(), track.name:lower() }
end

local function matchesExactly(track, searchText)
  for _, text in ipairs(getSearchableTexts(track)) do
    if text == searchText then return true end
  end
  return false
end

local function matchesPartly(track, searchText)
  for _, text in ipairs(getSearchableTexts(track)) do
    if text:find(searchText, 1, true) then return true end
  end
  return false
end

local function findTracksMatching(self, matches, searchText)
  local found = {}
  for _, track in ipairs(self:getAllTracks()) do
    if matches(track, searchText) then table.insert(found, track) end
  end
  return found
end

local function listTrackNames(tracks)
  local names = {}
  for index, track in ipairs(tracks) do names[index] = track.name end
  return table.concat(names, ", ")
end

-- Finds one track by its mission id, its folder name ("001-Circuito") or its name, ignoring
-- case; a unique partial match also works. Returns the track, or nil and a message.
function TrackDirectory:findTrack(text)
  if type(text) ~= "string" or text == "" then return nil, "Name a track (see: tracks)" end
  local searchText = text:lower()
  local exact = findTracksMatching(self, matchesExactly, searchText)
  if #exact == 1 then return exact[1] end
  local partial = #exact > 1 and exact or findTracksMatching(self, matchesPartly, searchText)
  if #partial == 1 then return partial[1] end
  if #partial > 1 then return nil, "More than one track matches \"" .. text .. "\": " .. listTrackNames(partial) end
  if next(self.tracksByMissionId) == nil then
    return nil, "No tracks known yet: a player has to join the server first"
  end
  return nil, "No track matches \"" .. text .. "\" (see: tracks)"
end

return TrackDirectory
