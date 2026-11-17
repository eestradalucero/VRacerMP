-- VRacerMP client: what the race info app shows, top left (B-2). Pure.
-- Input is RaceSession:getHudData() and the track's server lap record; every text is built
-- here, not in JavaScript.

local timeFormat = require("vracerMP/shared/timeFormat")

local M = {}

local HIDDEN = { visible = false }

-- 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th ... 21st, 22nd, 23rd.
local function getOrdinalPlace(place)
  if type(place) ~= "number" then return "-" end
  local lastTwoDigits = place % 100
  local lastDigit = place % 10
  if lastTwoDigits >= 11 and lastTwoDigits <= 13 then return place .. "th" end
  if lastDigit == 1 then return place .. "st" end
  if lastDigit == 2 then return place .. "nd" end
  if lastDigit == 3 then return place .. "rd" end
  return place .. "th"
end

-- "Server Record - Ana: 01'18\".311", or nil when the track has no record yet.
local function getServerRecordText(lapRecord)
  if not lapRecord then return nil end
  return "Server Record - " .. tostring(lapRecord.name) .. ": " .. timeFormat.formatDisplayTime(lapRecord.lapTimeMs)
end

-- "Penalty: +10\".000" once the server gave us penalties.
local function getPenaltyText(penaltyMs)
  if not penaltyMs or penaltyMs <= 0 then return nil end
  return "Penalty: " .. timeFormat.formatSignedDifference(penaltyMs, "+")
end

-- "Finished 2nd" or "DNF (retired)", once we are out of the race.
local function getFinishText(finishInfo)
  if not finishInfo then return nil end
  if finishInfo.status == "dnf" then return "DNF (" .. tostring(finishInfo.dnfReason) .. ")" end
  return "Finished " .. getOrdinalPlace(finishInfo.position)
end

-- hud: RaceSession:getHudData(). lapRecord: { name, lapTimeMs } or nil.
local function build(hud, lapRecord)
  if not hud then return HIDDEN end
  return {
    visible = true,
    placeText = getOrdinalPlace(hud.position),
    totalTimeText = "Total time: " .. timeFormat.formatDisplayTime(hud.raceTimeMs),
    currentLapText = "Current lap: " .. timeFormat.formatDisplayTime(hud.currentLapMs),
    bestLapText = "Best lap: " .. timeFormat.formatDisplayTime(hud.bestLapMs),
    serverRecordText = getServerRecordText(lapRecord),
    penaltyText = getPenaltyText(hud.penaltyMs),
    finishText = getFinishText(hud.finishInfo),
  }
end

M.build = build
M.getOrdinalPlace = getOrdinalPlace
M.HIDDEN = HIDDEN

return M
