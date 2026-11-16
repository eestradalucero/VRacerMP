-- VRacerMP server: class RaceSettings, what the owner can configure.

local raceStates = require("vracerMP/shared/raceStates")

local RaceSettings = {}
RaceSettings.__index = RaceSettings

local MIN_LAPS = 1
local MAX_LAPS = 99
local MIN_DNF_TIMEOUT_SECONDS = 10
local MAX_DNF_TIMEOUT_SECONDS = 3600
local DEFAULT_DNF_TIMEOUT_SECONDS = 120
local NO_DNF_LIMIT = 0 -- nobody is disqualified by time (B-5)

local function isWholeNumberInRange(value, minimum, maximum)
  return type(value) == "number" and value == math.floor(value) and value >= minimum and value <= maximum
end

function RaceSettings.new(track)
  local self = setmetatable({}, RaceSettings)
  self.raceType = raceStates.raceType.landrush
  self.laps = track.closed and track.defaultLaps or 1
  self.dnfTimeoutSeconds = DEFAULT_DNF_TIMEOUT_SECONDS
  self.gridOrder = raceStates.gridOrder.registration
  self.allowRecover = true
  return self
end

local function validateLaps(laps, track)
  if laps == nil then return true end
  if not isWholeNumberInRange(laps, MIN_LAPS, MAX_LAPS) then
    return false, "Laps must be between " .. MIN_LAPS .. " and " .. MAX_LAPS
  end
  if not track.closed and laps ~= 1 then
    return false, "Point-to-point tracks are always 1 lap"
  end
  return true
end

local function validateDnfTimeout(seconds)
  if seconds == nil or seconds == NO_DNF_LIMIT then return true end
  if not isWholeNumberInRange(seconds, MIN_DNF_TIMEOUT_SECONDS, MAX_DNF_TIMEOUT_SECONDS) then
    return false, "DNF timeout must be 0 (no limit) or between " .. MIN_DNF_TIMEOUT_SECONDS .. " and "
      .. MAX_DNF_TIMEOUT_SECONDS .. " seconds"
  end
  return true
end

local function validateChanges(changes, track)
  local checks = {
    { validateLaps, changes.laps, track },
    { validateDnfTimeout, changes.dnfTimeoutSeconds },
  }
  for _, check in ipairs(checks) do
    local valid, message = check[1](check[2], check[3])
    if not valid then return false, message end
  end
  return true
end

-- changes = { laps?, dnfTimeoutSeconds? }.
-- Applies all or nothing. Returns true, or false and a message for the player.
function RaceSettings:applyChanges(changes, track)
  if type(changes) ~= "table" then return false, "No settings sent" end
  local valid, message = validateChanges(changes, track)
  if not valid then return false, message end

  self.laps = changes.laps or self.laps
  self.dnfTimeoutSeconds = changes.dnfTimeoutSeconds or self.dnfTimeoutSeconds
  return true
end

function RaceSettings:hasDnfLimit()
  return self.dnfTimeoutSeconds ~= NO_DNF_LIMIT
end

function RaceSettings:getDnfTimeoutMs()
  return self.dnfTimeoutSeconds * 1000
end

function RaceSettings:serialize()
  return {
    dnfTimeoutSeconds = self.dnfTimeoutSeconds,
    gridOrder = self.gridOrder,
    allowRecover = self.allowRecover,
  }
end

return RaceSettings
