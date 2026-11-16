-- VRacerMP server: the command reference for docs/commands.md, built from the command list
-- (B-4), so the document and `help` cannot drift apart. Pure. Used by
-- tools/writeCommandsDoc.py and checked by tests/server/commandsTest.lua.

local commandList = require("vracerMP/commands/commandList")

local M = {}

M.START_MARKER = "<!-- commands:start (generated from commandList.lua: python tools/writeCommandsDoc.py) -->"
M.END_MARKER = "<!-- commands:end -->"

local function buildSummaryTable(commands)
  local lines = { "| Command | What it does |", "|---|---|" }
  for _, command in ipairs(commands) do
    table.insert(lines, "| `" .. command.usage .. "` | " .. command.summary .. " |")
  end
  return lines
end

local function buildCommandDetails(command)
  local lines = { "### " .. command.name, "", "`" .. command.usage .. "`", "", command.summary }
  if command.details and #command.details > 0 then
    table.insert(lines, "")
    for _, detail in ipairs(command.details) do table.insert(lines, "- " .. detail) end
  end
  return lines
end

local function appendAll(target, lines)
  for _, line in ipairs(lines) do table.insert(target, line) end
end

-- The text between the markers, markers included. Testing commands are left out: they only
-- exist on a local test server.
local function buildCommandSection()
  local commands = commandList.getCommands(false)
  local lines = { M.START_MARKER, "" }
  appendAll(lines, buildSummaryTable(commands))
  for _, command in ipairs(commands) do
    table.insert(lines, "")
    appendAll(lines, buildCommandDetails(command))
  end
  table.insert(lines, "")
  table.insert(lines, M.END_MARKER)
  return table.concat(lines, "\n")
end

M.buildCommandSection = buildCommandSection

return M
