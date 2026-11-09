-- VRacerMP client extension `vracerMP_main`. Glue only (architecture ORG-2):
-- forwards BeamNG game hooks and UI app actions to the client controller.

local ClientController = require("vracerMP/controller/clientController")

local M = {}

local logTag = "vracerMP"
local controller = nil

local function isLevelLoaded()
  return getCurrentLevelIdentifier and getCurrentLevelIdentifier() ~= nil
end

local function onExtensionLoaded()
  controller = ClientController.new()
  if isLevelLoaded() then controller:loadLevel() end
  log('I', logTag, "VRacerMP client loaded")
end

local function onClientPostStartMission()
  if controller then controller:loadLevel() end
end

local function onClientEndMission()
  if controller then controller:unloadLevel() end
end

local function onExtensionUnloaded()
  if controller then controller:unloadLevel() end
  controller = nil
end

local function onUpdate(dtReal, dtSim)
  if controller then controller:update(dtReal, dtSim) end
end

local function onPreRender(dt, dtSim)
  if controller then controller:render(dt, dtSim) end
end

-- Called by the VRacerMP Vue apps: vracerMP_main.handleUiAction({ action = "...", ... })
local function handleUiAction(action)
  if controller then controller:handleUiAction(action) end
end

M.onExtensionLoaded = onExtensionLoaded
M.onClientPostStartMission = onClientPostStartMission
M.onClientEndMission = onClientEndMission
M.onExtensionUnloaded = onExtensionUnloaded
M.onUpdate = onUpdate
M.onPreRender = onPreRender
M.handleUiAction = handleUiAction

return M
