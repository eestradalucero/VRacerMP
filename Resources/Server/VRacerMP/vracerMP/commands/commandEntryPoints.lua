-- VRacerMP server: class CommandEntryPoints, the three ways in for commands (B-4).
--
--   chat:     a player types "/vracer <command>"; the reply goes to that player's chat.
--   console:  "vracer <command>" in the server console; the reply is printed there.
--   plugin:   another plugin triggers vracerMP_command(commandText, requestId?); the reply is
--             returned and also published as vracerMP_commandReply (docs/commands.md).
--
-- dependencies = { coordinator, registry, trackDirectory, playerDirectory,
--                  sendChat(playerId, text), pluginEvents = { publish(eventName, payload) },
--                  testingCommands (serverOptions.lua) }

local Race = require("vracerMP/races/race")
local protocol = require("vracerMP/shared/protocol")
local jsonEncoder = require("vracerMP/shared/jsonEncoder")
local commandRunner = require("vracerMP/commands/commandRunner")

local CommandEntryPoints = {}
CommandEntryPoints.__index = CommandEntryPoints

local PLUGIN_REPLY_VERSION = 1

function CommandEntryPoints.new(dependencies)
  local self = setmetatable({}, CommandEntryPoints)
  self.dependencies = dependencies
  return self
end

local function buildContext(self, requester, prefix)
  local dependencies = self.dependencies
  return {
    coordinator = dependencies.coordinator,
    registry = dependencies.registry,
    trackDirectory = dependencies.trackDirectory,
    playerDirectory = dependencies.playerDirectory,
    requester = requester,
    prefix = prefix,
    testingCommands = dependencies.testingCommands == true,
  }
end

-- Returns true when the message was a VRacerMP command (it is then kept out of the chat).
function CommandEntryPoints:runChatMessage(playerId, message)
  local commandText = commandRunner.readChatCommand(message)
  if not commandText then return false end
  local _, lines = commandRunner.run(buildContext(self, playerId, commandRunner.CHAT_PREFIX), commandText)
  for _, line in ipairs(lines) do self.dependencies.sendChat(playerId, line) end
  return true
end

-- Returns the text to print, or nil when the line is not a VRacerMP command.
function CommandEntryPoints:runConsoleInput(input)
  local commandText = commandRunner.readConsoleCommand(input)
  if not commandText then return nil end
  local _, lines = commandRunner.run(buildContext(self, Race.SERVER, commandRunner.CONSOLE_PREFIX), commandText)
  return table.concat(lines, "\n")
end

-- commandText without any prefix, e.g. "start r-1". Returns the reply as JSON:
-- { version, requestId, ok, lines }.
function CommandEntryPoints:runPluginCommand(commandText, requestId)
  local ok, lines = commandRunner.run(buildContext(self, Race.SERVER, ""), tostring(commandText or ""))
  local reply = {
    version = PLUGIN_REPLY_VERSION,
    requestId = requestId or jsonEncoder.null,
    ok = ok == true,
    lines = jsonEncoder.markAsArray(lines),
  }
  self.dependencies.pluginEvents.publish(protocol.pluginEvents.commandReply, reply)
  return jsonEncoder.encode(reply)
end

return CommandEntryPoints
