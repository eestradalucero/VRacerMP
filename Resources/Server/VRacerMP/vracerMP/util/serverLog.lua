-- VRacerMP server: logging with the same signature as the client's `log(level, tag, ...)`,
-- so code reads the same on both sides (architecture ORG-7).
-- Levels: 'D' debug, 'I' info, 'W' warning, 'E' error.

local M = {}

local function getWriterForLevel(level)
  if type(Util) ~= "table" then return nil end
  local writers = {
    D = Util.LogDebug,
    I = Util.LogInfo,
    W = Util.LogWarn,
    E = Util.LogError,
  }
  return writers[level] or Util.LogInfo
end

local function joinMessageParts(...)
  local parts = {}
  for index = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(index, ...)))
  end
  return table.concat(parts, " ")
end

local function log(level, tag, ...)
  local message = "[" .. tostring(tag) .. "] " .. joinMessageParts(...)
  local writer = getWriterForLevel(level)
  if writer then
    writer(message)
  else
    -- Servers older than 3.3.0 (no Util.Log*) and unit tests.
    print("[" .. tostring(level) .. "] " .. message)
  end
end

M.log = log

return M
