-- VRacerMP client: puts our apps on screen by default (UI-T5), like BeamMP's chat.
--
-- The first time a UI layout is seen, any of our apps it lacks are added once with default
-- positions (BeamNG saves this as the player's copy of that layout). From then on the apps
-- belong to the player: they can move or remove them, and we never add them to that layout
-- again. Edge: BeamNG layout API and a small settings file.

local M = {}

local logTag = "vracerMP.layout"
local INSTALLED_LAYOUTS_FILE = "/settings/vracerMP/installedLayouts.json"

-- Default positions fit next to BeamMP's default layout (architecture §6.2).
local DEFAULT_APPS = {
  { appName = "vracermpRacePanel", placement = { top = "50px", right = "320px", width = "290px", height = "220px" } },
  { appName = "vracermpLobby", placement = { top = "290px", right = "320px", width = "330px", height = "360px" } },
  { appName = "vracermpCountdown", placement = { top = "18%", left = "0px", right = "0px", margin = "auto", width = "420px", height = "260px" } },
  { appName = "vracermpResults", placement = { top = "14%", left = "0px", right = "0px", margin = "auto", width = "660px", height = "440px" } },
}

local LAYOUT_EXTENSION = "ui_appLayouts"

local function getLayoutApi()
  if not extensions[LAYOUT_EXTENSION] then extensions.load(LAYOUT_EXTENSION) end
  return extensions[LAYOUT_EXTENSION]
end

local function readInstalledLayouts()
  return jsonReadFile(INSTALLED_LAYOUTS_FILE) or {}
end

local function rememberInstalledLayout(installedLayouts, filename)
  installedLayouts[filename] = true
  jsonWriteFile(INSTALLED_LAYOUTS_FILE, installedLayouts, true)
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

-- Returns how many apps were added.
local function addMissingApps(layoutApi, layout)
  local addedCount = 0
  for _, app in ipairs(DEFAULT_APPS) do
    if not layoutHasApp(layout, app.appName) and layoutApi.addApp(layout.filename, app.appName, copyPlacement(app.placement)) then
      addedCount = addedCount + 1
    end
  end
  return addedCount
end

-- Safe to call often: does nothing for layouts already handled.
local function installIntoCurrentLayout()
  local layoutApi = getLayoutApi()
  if not layoutApi or not layoutApi.getCurrentLayout then return end
  local layout = layoutApi.getCurrentLayout()
  if not layout or not layout.filename then return end

  local installedLayouts = readInstalledLayouts()
  if installedLayouts[layout.filename] then return end

  local addedCount = addMissingApps(layoutApi, layout)
  rememberInstalledLayout(installedLayouts, layout.filename)
  if addedCount > 0 then
    layoutApi.setCurrentLayout(layout.filename) -- reload so the new apps appear
    log('I', logTag, "added " .. addedCount .. " VRacerMP apps to layout " .. layout.filename)
  end
end

M.installIntoCurrentLayout = installIntoCurrentLayout

return M
