-- VRacerMP server: the clock races use. Wraps BeamMP's MP.CreateTimer so race code
-- stays testable (tests pass a fake clock with the same methods).

local ServerClock = {}
ServerClock.__index = ServerClock

function ServerClock.new()
  local self = setmetatable({}, ServerClock)
  self.timer = MP.CreateTimer()
  return self
end

-- Milliseconds since the plugin started. Only differences matter.
function ServerClock:getNowMs()
  return math.floor(self.timer:GetCurrent() * 1000)
end

-- "2026-11-05T20:14:03Z", used inside the race results.
function ServerClock:getUtcIso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

return ServerClock
