-- VRacerMP server: chat commands. Only testing helpers for now; racing itself uses the UI.
--   /vracer help               list commands
--   /vracer fake [lapSeconds]  add a fake racer to your race (testing alone)

local M = {}

local COMMAND_PREFIX = "/vracer"

local HELP_TEXT = "VRacerMP commands: /vracer fake [lapSeconds] - add a fake racer to your race"

local function splitWords(text)
  local words = {}
  for word in text:gmatch("%S+") do words[#words + 1] = word end
  return words
end

local function isVracerCommand(words)
  return words[1] ~= nil and words[1]:lower() == COMMAND_PREFIX
end

-- Returns nil when the message is not a VRacerMP command, otherwise the reply text.
local function runCommand(coordinator, playerId, message)
  local words = splitWords(message)
  if not isVracerCommand(words) then return nil end

  local subCommand = words[2] and words[2]:lower() or "help"
  if subCommand == "fake" then
    return coordinator:handleAddFakeRacer(playerId, tonumber(words[3]))
  end
  return HELP_TEXT
end

M.runCommand = runCommand

return M
