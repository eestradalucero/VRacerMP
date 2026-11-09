-- VRacerMP shared: enums for race states, racer statuses and DNF reasons.
-- Shared between server (Lua 5.3) and client (LuaJIT): keep to the common subset.

local M = {}

M.raceState = {
  registering = "registering", -- lobby open, owner can configure
  gridding = "gridding",       -- cars being moved to their grid slots
  countdown = "countdown",     -- 3-2-1 running, GO pending
  running = "running",         -- race clock running
  finished = "finished",       -- every racer finished or DNF
  aborted = "aborted",         -- race removed before it could finish
}

M.racerStatus = {
  registered = "registered",
  racing = "racing",
  finished = "finished",
  dnf = "dnf",
}

M.dnfReason = {
  timeout = "timeout",           -- still racing when the DNF timer ran out
  disconnected = "disconnected", -- left the server
  retired = "retired",           -- unregistered during the race
  notOnGrid = "notOnGrid",       -- never confirmed the grid slot
}

M.raceType = {
  landrush = "landrush",
}

M.gridOrder = {
  registration = "registration",
}

return M
