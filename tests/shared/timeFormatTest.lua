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

t.test("display times: minutes, seconds and thousandths", function()
  t.assertEquals(timeFormat.formatDisplayTime(252880), "04'12\".880")
  t.assertEquals(timeFormat.formatDisplayTime(0), "00'00\".000")
  t.assertEquals(timeFormat.formatDisplayTime(nil), "--'--\".---")
end)

t.test("display times show hours only past an hour", function()
  t.assertEquals(timeFormat.formatDisplayTime(3599999), "59'59\".999")
  t.assertEquals(timeFormat.formatDisplayTime(3600000), "1:00'00\".000")
  t.assertEquals(timeFormat.formatDisplayTime(3852880), "1:04'12\".880")
end)

t.test("differences are short under a minute", function()
  t.assertEquals(timeFormat.formatSignedDifference(842, "+"), "+0\".842")
  t.assertEquals(timeFormat.formatSignedDifference(7768, "-"), "-7\".768")
  t.assertEquals(timeFormat.formatTimeDifference(62500), "01'02\".500")
end)

return t.runAll("timeFormat")
