-- VRacerMP client: class Countdown, timing of the 3-2-1-GO countdown (START-4, UI-T2). Pure.
-- The app animates each new text; this class only decides which text shows when.

local Countdown = {}
Countdown.__index = Countdown

local GO_TEXT = "GO!"
local GO_DISPLAY_SECONDS = 1.2

function Countdown.new()
  local self = setmetatable({}, Countdown)
  self.secondsUntilGo = nil
  self.goSecondsLeft = nil
  self.text = nil
  self.changeCount = 0 -- the app restarts its animation when this changes
  return self
end

local function setText(self, text)
  if text == self.text then return false end
  self.text = text
  self.changeCount = self.changeCount + 1
  return true
end

local function getNumberText(secondsUntilGo)
  return tostring(math.ceil(secondsUntilGo))
end

function Countdown:start(goInMs)
  self.secondsUntilGo = goInMs / 1000
  self.goSecondsLeft = nil
  setText(self, getNumberText(self.secondsUntilGo))
end

function Countdown:showGo()
  self.secondsUntilGo = nil
  self.goSecondsLeft = GO_DISPLAY_SECONDS
  setText(self, GO_TEXT)
end

function Countdown:isGo()
  return self.text == GO_TEXT
end

-- Advances time. Returns true when the text changed (a new number, GO, or hidden).
function Countdown:update(dt)
  if self.secondsUntilGo then
    -- stays on "1" until the server says GO
    self.secondsUntilGo = math.max(self.secondsUntilGo - dt, 0.001)
    return setText(self, getNumberText(self.secondsUntilGo))
  end
  if self.goSecondsLeft then
    self.goSecondsLeft = self.goSecondsLeft - dt
    if self.goSecondsLeft <= 0 then
      self.goSecondsLeft = nil
      return setText(self, nil)
    end
  end
  return false
end

-- What the countdown app shows.
function Countdown:getView()
  if not self.text then return { visible = false } end
  return { visible = true, text = self.text, animationKey = self.changeCount, isGo = self:isGo() }
end

return Countdown
