-- VRacerMP shared: network event names. Payloads are documented in docs/protocol.md.
-- Shared between server (Lua 5.3) and client (LuaJIT): keep to the common subset.

local M = {}

M.version = 1

-- Client -> server
M.toServer = {
  requestLobbies = "vracerMP_requestLobbies",
  register = "vracerMP_register",
  unregister = "vracerMP_unregister",
  configure = "vracerMP_configure",
  startRace = "vracerMP_startRace",
  gridReady = "vracerMP_gridReady",
  pathnodeReached = "vracerMP_pathnodeReached",
}

-- Server -> client
M.toClient = {
  lobbyUpdated = "vracerMP_lobbyUpdated",
  raceRemoved = "vracerMP_raceRemoved",
  raceStarting = "vracerMP_raceStarting",
  countdown = "vracerMP_countdown",
  go = "vracerMP_go",
  gap = "vracerMP_gap",
  standings = "vracerMP_standings",
  racerFinished = "vracerMP_racerFinished",
  raceResults = "vracerMP_raceResults",
  notice = "vracerMP_notice",
  penalty = "vracerMP_penalty",     -- to the racer who got a time penalty
  lapRecord = "vracerMP_lapRecord", -- a track's server lap record (B-8)
  welcome = "vracerMP_welcome",     -- answer to requestLobbies: the client stops asking
}

-- Server <-> other server plugins (B-4, v2 in B-12; see docs/commands.md). Server only.
M.pluginInterfaceVersion = 2

M.pluginEvents = {
  command = "vracerMP_command",           -- in: (commandText, requestId?)
  commandReply = "vracerMP_commandReply", -- out: { version, requestId, ok, lines }
  query = "vracerMP_query",               -- in: (queryName, requestId?): "tracks" or "races"
  queryReply = "vracerMP_queryReply",     -- out: { version, requestId, ok, query, data, error }
  tracksUpdated = "vracerMP_tracksUpdated", -- out: { version, tracks } when new tracks were reported
  raceUpdated = "vracerMP_raceUpdated",   -- out: the lobby payload (same as lobbyUpdated)
  raceRemoved = "vracerMP_raceRemoved",   -- out: { raceId, missionId }
  raceResults = "vracerMP_raceResults",   -- out: the results payload (same as raceResults)
}

M.gapKind = {
  ahead = "ahead",   -- red: you are behind the car ahead by this much
  behind = "behind", -- green: the car behind is this far behind you
}

return M
