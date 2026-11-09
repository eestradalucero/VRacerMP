-- VRacerMP shared: time formatting.
-- Shared between server (Lua 5.3) and client (LuaJIT): keep to the common subset.
-- All inputs are integer milliseconds.

local M = {}

local MS_PER_SECOND = 1000
local MS_PER_MINUTE = 60 * MS_PER_SECOND

local function splitMilliseconds(ms)
  local wholeMs = math.floor(math.abs(ms) + 0.5)
  local minutes = math.floor(wholeMs / MS_PER_MINUTE)
  local seconds = math.floor((wholeMs - minutes * MS_PER_MINUTE) / MS_PER_SECOND)
  local millis = wholeMs - minutes * MS_PER_MINUTE - seconds * MS_PER_SECOND
  return minutes, seconds, millis
end

-- "01:24.120": used in the results file (two-digit minutes).
local function formatRaceTime(ms)
  if ms == nil then return nil end
  local minutes, seconds, millis = splitMilliseconds(ms)
  return string.format("%02d:%02d.%03d", minutes, seconds, millis)
end

-- "1:24.120": used on screen.
local function formatHudTime(ms)
  if ms == nil then return "-:--.---" end
  local minutes, seconds, millis = splitMilliseconds(ms)
  return string.format("%d:%02d.%03d", minutes, seconds, millis)
end

-- "-0:00.214" (car ahead) or "+0:00.214" (car behind).
local function formatGap(ms, isAhead)
  local sign = isAhead and "-" or "+"
  return sign .. formatHudTime(ms)
end

M.formatRaceTime = formatRaceTime
M.formatHudTime = formatHudTime
M.formatGap = formatGap

return M
