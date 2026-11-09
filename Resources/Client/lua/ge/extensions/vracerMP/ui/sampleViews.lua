-- VRacerMP client: sample content shown while BeamNG's layout editor is open, so players can
-- see and move the apps (UI-T6). Pure; built with the real view builders.

local lobbyView = require("vracerMP/ui/lobbyView")
local raceView = require("vracerMP/ui/raceView")
local resultsView = require("vracerMP/ui/resultsView")

local M = {}

local SAMPLE_TRACK = { name = "Sample Circuit", closed = true, defaultLaps = 3 }

local SAMPLE_LOBBY = {
  raceId = "sample", state = "registering", ownerId = 1, laps = 3, dnfTimeoutSeconds = 120,
  racers = { { id = 1, name = "You" }, { id = 2, name = "Racer Two" }, { id = 3, name = "Racer Three" } },
}

local SAMPLE_HUD = {
  position = 2, racerCount = 6, currentLap = 2, laps = 3, raceTimeMs = 104321, bestLapMs = 51234,
  pathnodesPassed = 7, pathnodeCount = 19, aheadGapMs = 412, behindGapMs = 1730,
}

local SAMPLE_RESULTS = {
  laps = 3,
  raceTrack = { name = "Sample Circuit" },
  racers = {
    { position = 1, name = "Racer Two", status = "finished", raceStats = { totalTime = 154210, bestLapTime = 50980, gapToWinner = 0 } },
    { position = 2, name = "You", status = "finished", raceStats = { totalTime = 155002, bestLapTime = 51234, gapToWinner = 792 } },
    { position = 3, name = "Racer Three", status = "dnf", dnfReason = "timeout", raceStats = { bestLapTime = 53100 } },
  },
}

local function build()
  return {
    lobby = lobbyView.build(SAMPLE_TRACK, SAMPLE_LOBBY, 1),
    race = raceView.build(SAMPLE_HUD),
    countdown = { visible = true, text = "3", animationKey = 0, isGo = false },
    results = resultsView.build(SAMPLE_RESULTS),
  }
end

M.build = build

return M
