-- VRacerMP client: class UiPresenter, sends view models to the Vue apps (architecture §6.1).
-- Pure: the sending function is injected. A view is sent only when it changed; the race
-- panel, whose clock changes every frame, at most 20 times per second.

local jsonEncoder = require("vracerMP/shared/jsonEncoder")

local UiPresenter = {}
UiPresenter.__index = UiPresenter

UiPresenter.channels = {
  lobby = { eventName = "VRacerMPLobby", minIntervalSeconds = 0 },
  race = { eventName = "VRacerMPRace", minIntervalSeconds = 0.05 },
  countdown = { eventName = "VRacerMPCountdown", minIntervalSeconds = 0 },
  results = { eventName = "VRacerMPResults", minIntervalSeconds = 0 },
}

-- sendToUi(eventName, view)
function UiPresenter.new(sendToUi)
  local self = setmetatable({}, UiPresenter)
  self.sendToUi = sendToUi
  self.lastSentByChannel = {}
  self.secondsSinceSentByChannel = {}
  return self
end

local function presentChannel(self, channelName, view, dtReal)
  local channel = UiPresenter.channels[channelName]
  local secondsSinceSent = (self.secondsSinceSentByChannel[channelName] or math.huge) + dtReal
  self.secondsSinceSentByChannel[channelName] = secondsSinceSent
  local encoded = jsonEncoder.encode(view)
  if encoded == self.lastSentByChannel[channelName] then return end
  if secondsSinceSent < channel.minIntervalSeconds then return end
  self.sendToUi(channel.eventName, view)
  self.lastSentByChannel[channelName] = encoded
  self.secondsSinceSentByChannel[channelName] = 0
end

-- views = { lobby, race, countdown, results }, each a view model table.
function UiPresenter:present(views, dtReal)
  for channelName in pairs(UiPresenter.channels) do
    presentChannel(self, channelName, views[channelName] or { visible = false }, dtReal or 0)
  end
end

-- An app (re)appeared: send everything again on the next present().
function UiPresenter:resendAll()
  self.lastSentByChannel = {}
  self.secondsSinceSentByChannel = {}
end

return UiPresenter
