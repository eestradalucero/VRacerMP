-- VRacerMP server: payloads for other server plugins (plugin interface v2, B-12). Pure.
-- docs/commands.md (Plugin interface) documents them; keep the two in sync.

local protocol = require("vracerMP/shared/protocol")
local jsonEncoder = require("vracerMP/shared/jsonEncoder")
local messageBuilder = require("vracerMP/coordinator/messageBuilder")

local M = {}

-- One track: `id` is the mission folder, the value `create --track` takes.
local function buildTrackEntry(track)
  return {
    id = track:getMissionFolderName(),
    missionId = track.missionId,
    name = track.name,
    level = track.level,
    closed = track.closed,
    defaultLaps = track.defaultLaps,
    pathnodeCount = track.pathnodeCount,
  }
end

-- tracks: TrackDirectory:getAllTracks() (already sorted by name). Always a JSON array.
local function buildTrackList(tracks)
  local entries = {}
  for index, track in ipairs(tracks) do entries[index] = buildTrackEntry(track) end
  return jsonEncoder.markAsArray(entries)
end

-- "r-12" -> 12
local function getRaceNumber(race)
  return tonumber(race.raceId:match("(%d+)$")) or 0
end

-- One lobby payload (the same as vracerMP_raceUpdated) per race, ordered by race id.
-- Always a JSON array.
local function buildRaceList(races)
  local sorted = {}
  for index, race in ipairs(races) do sorted[index] = race end
  table.sort(sorted, function(a, b) return getRaceNumber(a) < getRaceNumber(b) end)
  local entries = {}
  for index, race in ipairs(sorted) do entries[index] = messageBuilder.buildLobby(race) end
  return jsonEncoder.markAsArray(entries)
end

-- vracerMP_tracksUpdated: every known track, after a player reported new ones.
local function buildTracksUpdated(tracks)
  return { version = protocol.pluginInterfaceVersion, tracks = buildTrackList(tracks) }
end

M.buildTrackList = buildTrackList
M.buildRaceList = buildRaceList
M.buildTracksUpdated = buildTracksUpdated

return M
