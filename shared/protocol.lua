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
}

M.gapKind = {
  ahead = "ahead",   -- red: you are behind the car ahead by this much
  behind = "behind", -- green: the car behind is this far behind you
}

return M
