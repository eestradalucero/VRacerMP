-- VRacerMP client: puts our apps on screen by default (UI-T5), like BeamMP's chat.
--
-- Each of our apps is added once to each UI layout, with a default position (BeamNG saves
-- this as the player's copy of that layout). From then on the app belongs to the player: they
-- can move or remove it, and we never add it to that layout again. Apps that a new version
-- adds (B-2) are added once too. Apps we no longer ship are taken out of the layout.
-- Edge: BeamNG layout API and a small settings file.

local M = {}

local logTag = "vracerMP.layout"
local INSTALLED_LAYOUTS_FILE = "/settings/vracerMP/installedLayouts.json"

-- Default positions (architecture §6.2). Race info top left, laps and retire top right, the
-- deltas centered a quarter of the way down.
local DEFAULT_APPS = {
  { appName = "vracermpRaceInfo", placement = { top = "10px", left = "10px", width = "340px", height = "190px" } },
  { appName = "vracermpDeltas", placement = { top = "20%", left = "0px", right = "0px", margin = "auto", width = "300px", height = "100px" } },
  { appName = "vracermpLaps", placement = { top = "10px", right = "10px", width = "420px", height = "50px" } },
  { appName = "vracermpLobby", placement = { top = "290px", right = "320px", width = "330px", height = "540px" } },
  { appName = "vracermpCountdown", placement = { top = "18%", left = "0px", right = "0px", margin = "auto", width = "420px", height = "260px" } },
  { appName = "vracermpResults", placement = { top = "14%", left = "0px", right = "0px", margin = "auto", width = "860px", height = "440px" } },
}

-- Apps of older versions, removed from layouts: the race panel became three apps (B-2).
local RETIRED_APP_NAMES = { "vracermpRacePanel" }

-- Before B-2 a layout was remembered as a whole (true): it already had these apps.
local APPS_BEFORE_B2 = { "vracermpRacePanel", "vracermpLobby", "vracermpCountdown", "vracermpResults" }

local LAYOUT_EXTENSION = "ui_appLayouts"

local function getLayoutApi()
  if not extensions[LAYOUT_EXTENSION] then extensions.load(LAYOUT_EXTENSION) end
  return extensions[LAYOUT_EXTENSION]
end

-- Per layout file: the set of our apps already added once, e.g. { vracermpLobby = true }.
local function readInstalledApps(installedLayouts, filename)
  local installed = installedLayouts[filename]
  if installed == true then
    installed = {}
    for _, appName in ipairs(APPS_BEFORE_B2) do installed[appName] = true end
  end
  return installed or {}
end

local function layoutHasApp(layout, appName)
  for _, app in ipairs(layout.apps or {}) do
    if app.appName == appName then return true end
  end
  return false
end

local function copyPlacement(placement)
  local copy = {}
  for key, value in pairs(placement) do copy[key] = value end
  return copy
end

-- Adds the apps this layout never had. Returns how many were added.
local function addNewApps(layoutApi, layout, installedApps)
  local addedCount = 0
  for _, app in ipairs(DEFAULT_APPS) do
    if not installedApps[app.appName] then
      installedApps[app.appName] = true
      if not layoutHasApp(layout, app.appName)
        and layoutApi.addApp(layout.filename, app.appName, copyPlacement(app.placement)) then
        addedCount = addedCount + 1
      end
    end
  end
  return addedCount
end

local function isRetiredApp(appName)
  for _, retiredName in ipairs(RETIRED_APP_NAMES) do
    if retiredName == appName then return true end
  end
  return false
end

-- The layout as saved on disk. removeApp works on that copy, and the current layout can be a
-- stale one, so positions must come from it; else a stale position could remove another app.
local function findSavedLayout(layoutApi, filename)
  if not layoutApi.getAvailableLayouts then return nil end
  for _, savedLayout in ipairs(layoutApi.getAvailableLayouts() or {}) do
    if savedLayout.filename == filename then return savedLayout end
  end
  return nil
end

-- Removes apps we no longer ship. Returns how many were removed.
local function hasRetiredApp(layout)
  for _, app in ipairs(layout.apps or {}) do
    if isRetiredApp(app.appName) then return true end
  end
  return false
end

local function removeRetiredApps(layoutApi, layout)
  -- Checked on the current layout first: reading the saved layouts touches the disk.
  if not layoutApi.removeApp or not hasRetiredApp(layout) then return 0 end
  local savedLayout = findSavedLayout(layoutApi, layout.filename)
  if not savedLayout then return 0 end
  local removedCount = 0
  local apps = savedLayout.apps or {}
  for index = #apps, 1, -1 do -- from the end, so earlier indexes stay valid
    if isRetiredApp(apps[index].appName) and layoutApi.removeApp(layout.filename, index - 1) then -- 0-based
      removedCount = removedCount + 1
    end
  end
  return removedCount
end

local function rememberInstalledApps(installedLayouts, filename, installedApps)
  installedLayouts[filename] = installedApps
  jsonWriteFile(INSTALLED_LAYOUTS_FILE, installedLayouts, true)
end

local function hasEveryApp(installedApps)
  for _, app in ipairs(DEFAULT_APPS) do
    if not installedApps[app.appName] then return false end
  end
  return true
end

-- Safe to call often: does nothing once a layout has every app and no retired ones.
local function installIntoCurrentLayout()
  local layoutApi = getLayoutApi()
  if not layoutApi or not layoutApi.getCurrentLayout then return end
  local layout = layoutApi.getCurrentLayout()
  if not layout or not layout.filename then return end

  local installedLayouts = jsonReadFile(INSTALLED_LAYOUTS_FILE) or {}
  local installedApps = readInstalledApps(installedLayouts, layout.filename)
  local removedCount = removeRetiredApps(layoutApi, layout)
  if hasEveryApp(installedApps) and removedCount == 0 then return end

  local addedCount = addNewApps(layoutApi, layout, installedApps)
  rememberInstalledApps(installedLayouts, layout.filename, installedApps)
  if addedCount + removedCount > 0 then
    layoutApi.setCurrentLayout(layout.filename) -- reload so the changes appear
    log('I', logTag, "layout " .. layout.filename .. ": added " .. addedCount .. ", removed " .. removedCount .. " VRacerMP apps")
  end
end

M.installIntoCurrentLayout = installIntoCurrentLayout

return M
