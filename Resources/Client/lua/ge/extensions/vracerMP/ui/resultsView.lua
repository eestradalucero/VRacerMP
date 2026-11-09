-- VRacerMP client: builds what the results app shows (FIN-5). Pure.
-- Input is the raceResults payload, the same shape as the results JSON (requirements §6).

local timeFormat = require("vracerMP/shared/timeFormat")

local M = {}

local HIDDEN = { visible = false }

local function getStatusText(racer)
  if racer.status == "dnf" then return "DNF " .. tostring(racer.dnfReason or "") end
  if racer.status == "finished" then return "Finished" end
  return tostring(racer.status)
end

local function buildRow(racer)
  local stats = racer.raceStats or {}
  local isFinished = racer.status == "finished"
  return {
    position = tostring(racer.position or "-"),
    name = racer.name,
    totalTime = isFinished and timeFormat.formatHudTime(stats.totalTime) or "-",
    gapToWinner = (isFinished and stats.gapToWinner and stats.gapToWinner > 0) and timeFormat.formatGap(stats.gapToWinner, false) or "",
    bestLap = timeFormat.formatHudTime(stats.bestLapTime),
    status = getStatusText(racer),
    isFinished = isFinished,
  }
end

local function getTitle(results)
  local track = results.raceTrack or {}
  local laps = results.laps or 0
  return string.format("%s  -  %d %s", track.name or "", laps, laps == 1 and "lap" or "laps")
end

local function build(results)
  if not results then return HIDDEN end
  local rows = {}
  for index, racer in ipairs(results.racers or {}) do
    rows[index] = buildRow(racer)
  end
  return { visible = true, title = getTitle(results), rows = rows }
end

M.build = build
M.HIDDEN = HIDDEN

return M
