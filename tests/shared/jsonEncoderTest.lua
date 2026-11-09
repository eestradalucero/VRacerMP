local t = require("tests/testRunner")
local jsonEncoder = require("vracerMP/shared/jsonEncoder")

t.test("encodes empty marked lists as arrays and empty tables as objects", function()
  t.assertEquals(jsonEncoder.encode({ laps = jsonEncoder.markAsArray({}) }), '{"laps":[]}')
  t.assertEquals(jsonEncoder.encode({}), "{}")
end)

t.test("encodes sequences, sorted object keys, null and booleans", function()
  local encoded = jsonEncoder.encode({ b = { 1, 2, 3 }, a = jsonEncoder.null, c = true })
  t.assertEquals(encoded, '{"a":null,"b":[1,2,3],"c":true}')
end)

t.test("writes integers without decimals and keeps fractions", function()
  t.assertEquals(jsonEncoder.encode({ 84120, 2.5, -3 }), "[84120,2.5,-3]")
end)

t.test("escapes strings", function()
  t.assertEquals(jsonEncoder.encode('say "hi"\n'), '"say \\"hi\\"\\n"')
end)

t.test("pretty output is indented", function()
  local pretty = jsonEncoder.encodePretty({ a = { 1 } })
  t.assertEquals(pretty, '{\n  "a": [\n    1\n  ]\n}')
end)

return t.runAll("jsonEncoder")
