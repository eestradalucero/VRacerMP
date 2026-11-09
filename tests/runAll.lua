-- VRacerMP tests: runs every test file. Run from the repository root:
--   lua tests/runAll.lua            (any Lua 5.1 / LuaJIT / 5.3)
--   python tools/runTests.py        (runs this on both Lua 5.3 and LuaJIT through `lupa`)
-- Returns (and exits with) the number of failed tests.

local testFiles = {
  "tests/shared/timeFormatTest.lua",
  "tests/shared/jsonEncoderTest.lua",
  "tests/server/raceTest.lua",
  "tests/server/raceCoordinatorTest.lua",
  "tests/client/gridBuilderTest.lua",
  "tests/client/trackInfoTest.lua",
  "tests/client/lobbyStoreTest.lua",
  "tests/client/uiViewsTest.lua",
  "tests/client/countdownAndPresenterTest.lua",
  "tests/client/clientControllerTest.lua",
}

package.path = table.concat({
  "./?.lua",
  "Resources/Server/VRacerMP/?.lua",
  "Resources/Client/lua/ge/extensions/?.lua",
  package.path,
}, ";")

-- The build copies /shared into both packages as vracerMP/shared; tests read it in place.
local SHARED_PREFIX = "vracerMP/shared/"
local function findSharedModule(moduleName)
  if moduleName:sub(1, #SHARED_PREFIX) ~= SHARED_PREFIX then return nil end
  local path = "shared/" .. moduleName:sub(#SHARED_PREFIX + 1) .. ".lua"
  local loader, loadError = loadfile(path)
  if not loader then return "\n\tno shared file " .. path .. ": " .. tostring(loadError) end
  return loader
end
local searchers = package.searchers or package.loaders
table.insert(searchers, 2, findSharedModule)

-- Client modules log through the game's global `log`, the server through `Util.Log*`;
-- tests keep both quiet.
local function ignoreLog() end
log = log or ignoreLog
Util = Util or { LogDebug = ignoreLog, LogInfo = ignoreLog, LogWarn = ignoreLog, LogError = ignoreLog }

local function runTestFile(path)
  local runFile, loadError = loadfile(path)
  if not runFile then
    print("  FAIL could not load " .. path .. ": " .. tostring(loadError))
    return 1
  end
  local ran, failures = pcall(runFile)
  if not ran then
    print("  FAIL " .. path .. " crashed: " .. tostring(failures))
    return 1
  end
  return failures or 0
end

local totalFailures = 0
for _, path in ipairs(testFiles) do
  totalFailures = totalFailures + runTestFile(path)
end
print(_VERSION .. ": " .. (totalFailures == 0 and "all tests passed" or (totalFailures .. " failures")))

if not RUNNING_FROM_PYTHON and os and os.exit then os.exit(totalFailures == 0 and 0 or 1) end
return totalFailures
