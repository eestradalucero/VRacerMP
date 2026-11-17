-- VRacerMP client: sample content shown while BeamNG's layout editor is open, so players can
-- see and move the apps (UI-T6). Pure; built with the real view builders.

local lobbyView = require("vracerMP/ui/lobbyView")
local raceInfoView = require("vracerMP/ui/raceInfoView")
local lapsView = require("vracerMP/ui/lapsView")
local resultsView = require("vracerMP/ui/resultsView")

local M = {}

local SAMPLE_TRACK = { name = "Sample Circuit", closed = true, defaultLaps = 3 }

local SAMPLE_LOBBY = {
  raceId = "sample", state = "registering", ownerId = 1, laps = 3, dnfTimeoutSeconds = 120,
  racers = { { id = 1, name = "You" }, { id = 2, name = "Racer Two" }, { id = 3, name = "Racer Three" } },
}

local SAMPLE_HUD = {
  position = 2, racerCount = 6, currentLap = 2, laps = 3, raceTimeMs = 104321, currentLapMs = 53087,
  bestLapMs = 51234, pathnodesPassed = 7, pathnodeCount = 19, penaltyMs = 10000,
}

local SAMPLE_RECORD = { lapTimeMs = 50980, name = "Racer Two", model = "etk800" }

-- Both deltas on, so they can be placed in the layout editor.
local SAMPLE_DELTAS = {
  visible = true,
  ahead = { text = "+0\".412", isShown = true },
  behind = { text = "-1\".730", isShown = true },
}

local SAMPLE_RESULTS = {
  laps = 3,
  raceTrack = { name = "Sample Circuit" },
  racers = {
    { position = 1, name = "Racer Two", status = "finished", raceStats = { rawTime = 154210, penaltyTime = 0, totalTime = 154210, bestLapTime = 50980, gapToWinner = 0 } },
    { position = 2, id = 1, name = "You", status = "finished", raceStats = { rawTime = 135002, penaltyTime = 20000, totalTime = 155002, bestLapTime = 51234, gapToWinner = 792 } },
    { position = 3, name = "Racer Three", status = "dnf", dnfReason = "timeout", raceStats = { bestLapTime = 53100 } },
  },
}

local function build()
  return {
    lobby = lobbyView.build(SAMPLE_TRACK, SAMPLE_LOBBY, 1, SAMPLE_RECORD),
    raceInfo = raceInfoView.build(SAMPLE_HUD, SAMPLE_RECORD),
    deltas = SAMPLE_DELTAS,
    laps = lapsView.build(SAMPLE_HUD),
    countdown = { visible = true, text = "3", animationKey = 0, isGo = false },
    results = resultsView.build(SAMPLE_RESULTS, 1, 30),
  }
end

M.build = build

return M
