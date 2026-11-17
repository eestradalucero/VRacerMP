-- VRacerMP client: what the laps-and-retire app shows, top right (B-2). Pure.
-- The Retire button asks for confirmation in the app itself (FIN-8).

local M = {}

local HIDDEN = { visible = false }
local FINISHED_STATE = "finished" -- RaceSession.state.finished

local function isStillRacing(hud)
  return hud.finishInfo == nil and hud.state ~= FINISHED_STATE
end

-- hud: RaceSession:getHudData().
local function build(hud)
  if not hud then return HIDDEN end
  return {
    visible = true,
    lapsText = string.format("Laps: %d/%d", hud.currentLap, hud.laps),
    canRetire = isStillRacing(hud),
  }
end

M.build = build
M.HIDDEN = HIDDEN

return M
