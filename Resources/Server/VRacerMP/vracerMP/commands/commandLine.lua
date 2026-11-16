-- VRacerMP server: reads a command line (B-4). Pure.
--
--   create --track Circuito Bronco --laps 3 --players Ana, Bob
--   -> { name = "create", arguments = {}, options = { track = "Circuito Bronco", laps = "3",
--        players = "Ana, Bob" } }
--
-- Words before the first option are arguments. An option's value is every word up to the next
-- option, so names may contain spaces. Command and option names ignore case.

local M = {}

local OPTION_PREFIX = "^%-%-"

local function splitWords(text)
  local words = {}
  for word in text:gmatch("%S+") do table.insert(words, word) end
  return words
end

local function isOption(word)
  return word:find(OPTION_PREFIX) ~= nil
end

local function readOptionName(word)
  return word:gsub(OPTION_PREFIX, ""):lower()
end

-- Returns the parsed command, or nil and a message.
local function parse(text)
  local words = splitWords(type(text) == "string" and text or "")
  if #words == 0 then return nil, "No command given" end

  local command = { name = words[1]:lower(), arguments = {}, options = {} }
  local currentOption, optionWords = nil, {}
  local function closeOption()
    if currentOption then command.options[currentOption] = table.concat(optionWords, " ") end
    currentOption, optionWords = nil, {}
  end

  for index = 2, #words do
    local word = words[index]
    if isOption(word) then
      closeOption()
      currentOption = readOptionName(word)
      if currentOption == "" then return nil, "An option is missing its name after --" end
    elseif currentOption then
      table.insert(optionWords, word)
    else
      table.insert(command.arguments, word)
    end
  end
  closeOption()
  return command
end

-- "Ana, Bob ,Carl" -> { "Ana", "Bob", "Carl" }
local function splitList(text)
  local items = {}
  for item in (text or ""):gmatch("[^,]+") do
    local trimmed = item:match("^%s*(.-)%s*$")
    if trimmed ~= "" then table.insert(items, trimmed) end
  end
  return items
end

-- A whole number, or nil and a message naming the option.
local function readWholeNumber(text, optionName)
  local number = tonumber(text)
  if not number or number ~= math.floor(number) then
    return nil, "--" .. optionName .. " needs a whole number"
  end
  return math.floor(number)
end

M.parse = parse
M.splitList = splitList
M.readWholeNumber = readWholeNumber

return M
