-- VRacerMP client: builds what the results app shows (FIN-5, B-6, B-7). Pure.
-- Input is the raceResults payload, the same shape as the results JSON (requirements §6).

local timeFormat = require("vracerMP/shared/timeFormat")

local M = {}

local HIDDEN = { visible = false }

local function getStatusText(racer)
  if racer.status == "dnf" then return "DNF " .. tostring(racer.dnfReason or "") end
  if racer.status == "finished" then return "Finished" end
  return tostring(racer.status)
end

-- "+2:28.000", or "" without penalties.
local function getPenaltyText(penaltyMs)
  if not penaltyMs or penaltyMs <= 0 then return "" end
  return "+" .. timeFormat.formatHudTime(penaltyMs)
end

local function buildRow(racer, myPlayerId)
  local stats = racer.raceStats or {}
  local isFinished = racer.status == "finished"
  return {
    position = tostring(racer.position or "-"),
    name = racer.name,
    rawTime = isFinished and timeFormat.formatHudTime(stats.rawTime or stats.totalTime) or "-",
    penaltyTime = getPenaltyText(stats.penaltyTime),
    totalTime = isFinished and timeFormat.formatHudTime(stats.totalTime) or "-",
    gapToWinner = (isFinished and stats.gapToWinner and stats.gapToWinner > 0) and timeFormat.formatGap(stats.gapToWinner, false) or "",
    bestLap = timeFormat.formatHudTime(stats.bestLapTime),
    status = getStatusText(racer),
    isFinished = isFinished,
    isMe = racer.id == myPlayerId,
  }
end

local function getTitle(results)
  local track = results.raceTrack or {}
  local laps = results.laps or 0
  return string.format("%s  -  %d %s", track.name or "", laps, laps == 1 and "lap" or "laps")
end

local function getCloseText(secondsUntilClose)
  if not secondsUntilClose then return nil end
  return string.format("Closes in %d s", math.ceil(secondsUntilClose))
end

-- myPlayerId: our row is highlighted. secondsUntilClose: shown while the results auto-close.
local function build(results, myPlayerId, secondsUntilClose)
  if not results then return HIDDEN end
  local rows = {}
  for index, racer in ipairs(results.racers or {}) do
    rows[index] = buildRow(racer, myPlayerId)
  end
  return { visible = true, title = getTitle(results), rows = rows, closeText = getCloseText(secondsUntilClose) }
end

M.build = build
M.HIDDEN = HIDDEN

return M
