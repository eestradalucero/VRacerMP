-- VRacerMP client: class DeltaDisplay, when the delta app shows each gap (B-2). Pure.
--
-- A gap arrives when we or a nearby racer pass a checkpoint. Each kind ("ahead": red, the
-- racer in front; "behind": green, the racer after us) is shown on its own: on for
-- 3.2 s (0.2 s fade in + 3 s), then off; the app fades it out in 0.2 s. The text stays
-- while it fades out.

local timeFormat = require("vracerMP/shared/timeFormat")

local DeltaDisplay = {}
DeltaDisplay.__index = DeltaDisplay

local SHOWN_SECONDS = 3.2
local KINDS = { "ahead", "behind" }
-- Ahead: we are this much behind them. Behind: they are this much behind us.
local SIGN_BY_KIND = { ahead = "+", behind = "-" }

function DeltaDisplay.new()
  local self = setmetatable({}, DeltaDisplay)
  self:clear()
  return self
end

function DeltaDisplay:clear()
  self.deltasByKind = {}
  for _, kind in ipairs(KINDS) do
    self.deltasByKind[kind] = { text = "", secondsLeft = 0 }
  end
end

-- gap = { kind = "ahead" | "behind", gapMs } (the server's gap message).
function DeltaDisplay:show(gap)
  local delta = self.deltasByKind[gap.kind]
  if not delta or type(gap.gapMs) ~= "number" then return end
  delta.text = timeFormat.formatSignedDifference(gap.gapMs, SIGN_BY_KIND[gap.kind])
  delta.secondsLeft = SHOWN_SECONDS
end

function DeltaDisplay:update(dtReal)
  for _, delta in pairs(self.deltasByKind) do
    delta.secondsLeft = math.max(0, delta.secondsLeft - dtReal)
  end
end

local function buildDeltaView(delta)
  return { text = delta.text, isShown = delta.secondsLeft > 0 }
end

-- isRacing: the app only exists during our race.
function DeltaDisplay:getView(isRacing)
  if not isRacing then return { visible = false } end
  return {
    visible = true,
    ahead = buildDeltaView(self.deltasByKind.ahead),
    behind = buildDeltaView(self.deltasByKind.behind),
  }
end

return DeltaDisplay
