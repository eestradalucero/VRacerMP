local t = require("tests/testRunner")
local Countdown = require("vracerMP/ui/countdown")
local UiPresenter = require("vracerMP/ui/uiPresenter")

t.test("countdown shows 3, 2, 1 and waits on 1 for GO", function()
  local countdown = Countdown.new()
  countdown:start(3000)
  t.assertEquals(countdown:getView().text, "3")
  t.assertTrue(countdown:update(1.0))
  t.assertEquals(countdown:getView().text, "2")
  countdown:update(1.0)
  t.assertEquals(countdown:getView().text, "1")
  t.assertEquals(countdown:update(5.0), false, "stays on 1 until the server says GO")
  t.assertEquals(countdown:getView().text, "1")
end)

t.test("GO shows briefly, then the countdown hides", function()
  local countdown = Countdown.new()
  countdown:start(3000)
  local keyBeforeGo = countdown:getView().animationKey
  countdown:showGo()
  local view = countdown:getView()
  t.assertEquals(view.text, "GO!")
  t.assertTrue(view.isGo)
  t.assertTrue(view.animationKey > keyBeforeGo)
  countdown:update(2.0)
  t.assertEquals(countdown:getView().visible, false)
end)

local function newRecordingPresenter()
  local sent = {}
  local presenter = UiPresenter.new(function(eventName, view) table.insert(sent, { eventName = eventName, view = view }) end)
  return presenter, sent
end

local function countSent(sent, eventName)
  local count = 0
  for _, message in ipairs(sent) do
    if message.eventName == eventName then count = count + 1 end
  end
  return count
end

t.test("presenter sends a view only when it changes", function()
  local presenter, sent = newRecordingPresenter()
  local views = { lobby = { visible = true, trackName = "A" } }
  presenter:present(views, 0.016)
  presenter:present(views, 0.016)
  t.assertEquals(countSent(sent, "VRacerMPLobby"), 1)
  presenter:present({ lobby = { visible = true, trackName = "B" } }, 0.016)
  t.assertEquals(countSent(sent, "VRacerMPLobby"), 2)
end)

t.test("presenter limits the race panel to 20 updates per second", function()
  local presenter, sent = newRecordingPresenter()
  for frame = 1, 60 do -- one second at 60 fps, the clock changes every frame
    presenter:present({ race = { visible = true, raceTime = tostring(frame) } }, 1 / 60)
  end
  local raceUpdates = countSent(sent, "VRacerMPRace")
  t.assertTrue(raceUpdates >= 18 and raceUpdates <= 21, "got " .. raceUpdates .. " race updates")
end)

t.test("resendAll sends everything again", function()
  local presenter, sent = newRecordingPresenter()
  presenter:present({}, 0.016)
  local firstCount = #sent
  presenter:present({}, 0.016)
  t.assertEquals(#sent, firstCount)
  presenter:resendAll()
  presenter:present({}, 0.016)
  t.assertEquals(#sent, firstCount * 2)
end)

return t.runAll("countdownAndPresenter")
