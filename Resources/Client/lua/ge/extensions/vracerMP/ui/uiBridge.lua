-- VRacerMP client: talks to BeamNG's UI (edge: guihooks, ui_appLayouts).

local M = {}

local function sendToUi(eventName, view)
  guihooks.trigger(eventName, view)
end

-- True while the player is editing the UI layout (apps then show sample content).
local function isLayoutEditorOpen()
  local appLayouts = extensions.ui_appLayouts
  return appLayouts ~= nil and appLayouts.isEditing ~= nil and appLayouts.isEditing() == true
end

M.sendToUi = sendToUi
M.isLayoutEditorOpen = isLayoutEditorOpen

return M
