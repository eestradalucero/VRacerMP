-- VRacerMP client: adds a "VRacerMP" section to Options -> Controls, where our bindable actions
-- (lua/ge/extensions/core/input/actions/vracerMP.json, "cat": "vracerMP") are listed.
-- BeamNG keeps the sections in the core_input_categories table (categories.lua); a mod can
-- only add one at runtime.

local M = {}

local SECTION_ID = "vracerMP"
local SECTION = { order = 4.2, icon = "flag", title = "VRacerMP" } -- after BeamNG's Gameplay (4)

local function addSection()
  if not core_input_categories then extensions.load("core_input_categories") end
  if core_input_categories and not core_input_categories[SECTION_ID] then
    core_input_categories[SECTION_ID] = SECTION
  end
end

M.addSection = addSection

return M
