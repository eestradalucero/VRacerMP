local t = require("tests/testRunner")
local timeFormat = require("vracerMP/shared/timeFormat")

t.test("formatRaceTime pads minutes for files", function()
  t.assertEquals(timeFormat.formatRaceTime(84120), "01:24.120")
  t.assertEquals(timeFormat.formatRaceTime(251334), "04:11.334")
  t.assertEquals(timeFormat.formatRaceTime(0), "00:00.000")
end)

t.test("formatRaceTime handles long races and nil", function()
  t.assertEquals(timeFormat.formatRaceTime(3725007), "62:05.007")
  t.assertNil(timeFormat.formatRaceTime(nil))
end)

t.test("formatRaceTime rounds fractional milliseconds", function()
  t.assertEquals(timeFormat.formatRaceTime(999.6), "00:01.000")
end)

t.test("formatHudTime uses single-digit minutes", function()
  t.assertEquals(timeFormat.formatHudTime(84120), "1:24.120")
  t.assertEquals(timeFormat.formatHudTime(nil), "-:--.---")
end)

t.test("formatGap shows red ahead and green behind signs", function()
  t.assertEquals(timeFormat.formatGap(214, true), "-0:00.214")
  t.assertEquals(timeFormat.formatGap(1500, false), "+0:01.500")
end)

return t.runAll("timeFormat")
