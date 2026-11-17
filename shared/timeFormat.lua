-- VRacerMP shared: time formatting.
-- Shared between server (Lua 5.3) and client (LuaJIT): keep to the common subset.
-- All inputs are integer milliseconds.

local M = {}

local MS_PER_SECOND = 1000
local MS_PER_MINUTE = 60 * MS_PER_SECOND
local MINUTES_PER_HOUR = 60

local EMPTY_DISPLAY_TIME = "--'--\".---"

local function splitMilliseconds(ms)
  local wholeMs = math.floor(math.abs(ms) + 0.5)
  local minutes = math.floor(wholeMs / MS_PER_MINUTE)
  local seconds = math.floor((wholeMs - minutes * MS_PER_MINUTE) / MS_PER_SECOND)
  local millis = wholeMs - minutes * MS_PER_MINUTE - seconds * MS_PER_SECOND
  return minutes, seconds, millis
end

-- "01:24.120": used in the results JSON (two-digit minutes).
local function formatRaceTime(ms)
  if ms == nil then return nil end
  local minutes, seconds, millis = splitMilliseconds(ms)
  return string.format("%02d:%02d.%03d", minutes, seconds, millis)
end

-- "04'12\".880", or "1:04'12\".880" once the time passes an hour (B-2). Used on screen.
local function formatDisplayTime(ms)
  if ms == nil then return EMPTY_DISPLAY_TIME end
  local totalMinutes, seconds, millis = splitMilliseconds(ms)
  local hours = math.floor(totalMinutes / MINUTES_PER_HOUR)
  local minutes = totalMinutes - hours * MINUTES_PER_HOUR
  if hours > 0 then
    return string.format("%d:%02d'%02d\".%03d", hours, minutes, seconds, millis)
  end
  return string.format("%02d'%02d\".%03d", minutes, seconds, millis)
end

-- A difference between two times (gaps, penalties): "7\".768" under a minute, otherwise
-- like formatDisplayTime ("01'02\".500").
local function formatTimeDifference(ms)
  if math.abs(ms) >= MS_PER_MINUTE then return formatDisplayTime(ms) end
  local _, seconds, millis = splitMilliseconds(ms)
  return string.format("%d\".%03d", seconds, millis)
end

-- "+0\".842" or "-1\".276".
local function formatSignedDifference(ms, sign)
  return sign .. formatTimeDifference(ms)
end

M.formatRaceTime = formatRaceTime
M.formatDisplayTime = formatDisplayTime
M.formatTimeDifference = formatTimeDifference
M.formatSignedDifference = formatSignedDifference

return M
