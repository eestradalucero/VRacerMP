-- VRacerMP client: builds what the race panel shows (UI-1 .. UI-9). Pure.
-- Input is RaceSession:getHudData(); every time is formatted here, not in JavaScript.

local timeFormat = require("vracerMP/shared/timeFormat")

local M = {}

local HIDDEN = { visible = false }

local function getFinishText(finishInfo)
  if not finishInfo then return nil end
  if finishInfo.status == "dnf" then
    return "DNF (" .. tostring(finishInfo.dnfReason) .. ")"
  end
  return string.format("Finished P%d  %s", finishInfo.position or 0, timeFormat.formatHudTime(finishInfo.totalTimeMs))
end

local function formatGapOrNil(gapMs, isAhead)
  if not gapMs then return nil end
  return timeFormat.formatGap(gapMs, isAhead)
end

local function build(hud)
  if not hud then return HIDDEN end
  return {
    visible = true,
    position = "P" .. tostring(hud.position or "-"),
    racerCount = "/ " .. tostring(hud.racerCount or "-"),
    lap = string.format("%d / %d", hud.currentLap, hud.laps),
    raceTime = timeFormat.formatHudTime(hud.raceTimeMs),
    bestLap = timeFormat.formatHudTime(hud.bestLapMs),
    pathnodes = string.format("%d / %d", hud.pathnodesPassed, hud.pathnodeCount),
    aheadGap = formatGapOrNil(hud.aheadGapMs, true),
    behindGap = formatGapOrNil(hud.behindGapMs, false),
    finishText = getFinishText(hud.finishInfo),
  }
end

M.build = build
M.HIDDEN = HIDDEN

return M
