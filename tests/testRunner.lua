-- VRacerMP tests: a tiny test runner that works on Lua 5.3 (server) and LuaJIT (client).
-- Usage inside a test file:
--   local t = require("tests/testRunner")
--   t.test("adds numbers", function() t.assertEquals(1 + 1, 2) end)

local M = {}

local registeredTests = {}

local function describeValue(value)
  if type(value) == "string" then return string.format("%q", value) end
  return tostring(value)
end

local function test(name, testFunction)
  table.insert(registeredTests, { name = name, run = testFunction })
end

local function fail(message, level)
  error(message, (level or 1) + 2)
end

local function assertEquals(actual, expected, message)
  if actual ~= expected then
    fail((message and (message .. ": ") or "") .. "expected " .. describeValue(expected) .. ", got " .. describeValue(actual))
  end
end

local function assertTrue(value, message)
  if not value then fail(message or "expected a true value") end
end

local function assertNil(value, message)
  if value ~= nil then fail((message or "expected nil") .. ", got " .. describeValue(value)) end
end

local function assertContains(text, fragment, message)
  if type(text) ~= "string" or not text:find(fragment, 1, true) then
    fail((message or "text does not contain fragment") .. ": " .. describeValue(fragment) .. " in " .. describeValue(text))
  end
end

-- Runs every registered test. Returns the number of failures.
local function runAll(suiteName)
  local failures = 0
  for _, registered in ipairs(registeredTests) do
    local passed, errorMessage = pcall(registered.run)
    if passed then
      print("  ok   " .. registered.name)
    else
      failures = failures + 1
      print("  FAIL " .. registered.name .. "\n       " .. tostring(errorMessage))
    end
  end
  print(string.format("%s: %d tests, %d failed", suiteName, #registeredTests, failures))
  registeredTests = {}
  return failures
end

M.test = test
M.assertEquals = assertEquals
M.assertTrue = assertTrue
M.assertNil = assertNil
M.assertContains = assertContains
M.runAll = runAll

return M
