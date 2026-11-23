-- VRacerMP server: machine-readable queries for other plugins (plugin interface v2, B-12).
-- The event vracerMP_query(queryName, requestId?) is answered with vracerMP_queryReply.
-- Each query returns a JSON array; see docs/commands.md (Plugin interface).
--
-- context = { registry, trackDirectory } (see commandTargets.lua).

local jsonEncoder = require("vracerMP/shared/jsonEncoder")
local pluginPayloads = require("vracerMP/coordinator/pluginPayloads")

local M = {}

local queries = {
  -- Every known track, sorted by name (same order as the `tracks` command).
  tracks = function(context) return pluginPayloads.buildTrackList(context.trackDirectory:getAllTracks()) end,
  -- Every race, as its lobby payload, ordered by race id.
  races = function(context) return pluginPayloads.buildRaceList(context.registry:getAllRaces()) end,
}

-- Returns ok, data (always an array) and an error message (nil when ok).
local function run(context, queryName)
  local query = queries[queryName]
  if not query then return false, jsonEncoder.markAsArray({}), "Unknown query: " .. tostring(queryName) end
  return true, query(context), nil
end

M.run = run

return M
