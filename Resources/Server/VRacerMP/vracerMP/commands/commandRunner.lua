-- VRacerMP server: runs a command from any entry point (B-4): the server console, chat, or
-- another plugin. They share one parser and one command list (commandList.lua).
--
--   console:  vracer <command>      (server console; the server owns what it creates)
--   chat:     /vracer <command>     (the player who typed it)
--   plugin:   event vracerMP_command with the command text (the server)

local commandLine = require("vracerMP/commands/commandLine")
local commandList = require("vracerMP/commands/commandList")
local log = require("vracerMP/util/serverLog").log

local M = {}

local logTag = "vracerMP.commands"
local CHAT_PREFIX = "/vracer"
local CONSOLE_PREFIX = "vracer"

M.CHAT_PREFIX = CHAT_PREFIX .. " "
M.CONSOLE_PREFIX = CONSOLE_PREFIX .. " "

-- "<prefix> rest" -> "rest" ("" when only the prefix was typed), or nil for other text.
local function stripPrefix(text, prefix)
  if type(text) ~= "string" then return nil end
  local firstWord, rest = text:match("^%s*(%S+)%s*(.-)%s*$")
  if not firstWord or firstWord:lower() ~= prefix then return nil end
  return rest
end

-- The command text of a chat message, or nil when it is not a VRacerMP command.
local function readChatCommand(message)
  return stripPrefix(message, CHAT_PREFIX)
end

-- The command text of a console line, or nil when it is not a VRacerMP command.
local function readConsoleCommand(input)
  return stripPrefix(input, CONSOLE_PREFIX)
end

local function isAllowedOption(command, optionName)
  for _, allowed in ipairs(command.options) do
    if allowed == optionName then return true end
  end
  return false
end

-- Returns nil when the command line fits the command, otherwise a message.
local function checkCommandLine(context, command, parsed)
  local usage = "Usage: " .. context.prefix .. command.usage
  for optionName in pairs(parsed.options) do
    if not isAllowedOption(command, optionName) then return "Unknown option --" .. optionName .. ". " .. usage end
  end
  if #parsed.arguments > command.maxArguments then return usage end
  return nil
end

local function runParsedCommand(context, parsed)
  local command = commandList.findCommand(parsed.name, context.testingCommands)
  if not command then
    return false, { "Unknown command \"" .. parsed.name .. "\". Type " .. context.prefix .. "help" }
  end
  local lineError = checkCommandLine(context, command, parsed)
  if lineError then return false, { lineError } end
  return command.run(context, parsed)
end

-- context: see commandTargets.lua. Empty text shows the help.
-- Returns ok (true/false) and the reply lines. A bug in a command never escapes: it is
-- logged and reported as a failure.
local function run(context, text)
  local parsed, parseError = commandLine.parse(text ~= "" and text or "help")
  if not parsed then return false, { parseError } end
  local ran, ok, lines = pcall(runParsedCommand, context, parsed)
  if not ran then
    log('E', logTag, "command failed:", text, ok)
    return false, { "The command failed; see the server log" }
  end
  return ok, lines
end

M.readChatCommand = readChatCommand
M.readConsoleCommand = readConsoleCommand
M.run = run

return M
