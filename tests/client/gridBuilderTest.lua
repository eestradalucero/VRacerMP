local t = require("tests/testRunner")
local gridBuilder = require("vracerMP/tracks/gridBuilder")

local IDENTITY = { 0, 0, 0, 1 }

local function assertNear(actual, expected, message)
  t.assertTrue(math.abs(actual - expected) < 1e-6, (message or "value") .. ": expected " .. expected .. ", got " .. actual)
end

local startPositions = {
  { name = "Start Position 2", pos = { 10, 20, 5 }, rot = IDENTITY },
  { name = "Pathnode 4 Recovery Reverse", pos = { 99, 99, 99 }, rot = IDENTITY },
  { name = "Start Position 174", pos = { 14, 12, 5 }, rot = IDENTITY },
}

t.test("uses Start Position entries in list order and skips recovery points", function()
  local slots = gridBuilder.buildGridSlots(startPositions, 2)
  t.assertEquals(#slots, 2)
  t.assertEquals(slots[1].pos[1], 10)
  t.assertEquals(slots[2].pos[1], 14)
  t.assertEquals(gridBuilder.countRealSlots(startPositions), 2)
end)

t.test("generates missing slots behind the last real slot in two columns", function()
  local slots = gridBuilder.buildGridSlots(startPositions, 5)
  t.assertEquals(#slots, 5)
  -- identity rotation: driving direction is +y, so "behind" is -y
  assertNear(slots[3].pos[1], 14 - 2.5, "row 1 left x")
  assertNear(slots[3].pos[2], 12 - 8, "row 1 y")
  assertNear(slots[4].pos[1], 14 + 2.5, "row 1 right x")
  assertNear(slots[5].pos[2], 12 - 16, "row 2 y")
end)

t.test("rotates vectors with a quaternion", function()
  local quarterTurnAroundZ = { 0, 0, math.sin(math.pi / 4), math.cos(math.pi / 4) }
  local rotated = gridBuilder.rotateVector(quarterTurnAroundZ, { 0, 1, 0 })
  assertNear(rotated[1], -1, "x")
  assertNear(rotated[2], 0, "y")
  assertNear(rotated[3], 0, "z")
end)

t.test("a track without start positions gives no slots", function()
  t.assertEquals(#gridBuilder.buildGridSlots({}, 3), 0)
end)

return t.runAll("gridBuilder")
