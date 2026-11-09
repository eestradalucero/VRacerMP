-- VRacerMP shared: JSON encoder.
-- Shared between server (Lua 5.3) and client (LuaJIT): keep to the common subset.
--
-- Why our own encoder: both game JSON libraries write an empty Lua table as `{}`,
-- but the results schema wants empty lists as `[]` (architecture JSON-4).
-- Wrap a list with `markAsArray(list)` to always encode it as an array.
-- `nil` values cannot live in Lua tables; use `jsonEncoder.null` to write `null`.

local M = {}

local arrayMarker = {}
local nullValue = setmetatable({}, { __tostring = function() return "null" end })

local function markAsArray(list)
  return setmetatable(list or {}, arrayMarker)
end

local function isMarkedArray(value)
  return getmetatable(value) == arrayMarker
end

local function isSequence(value)
  local count = 0
  for _ in pairs(value) do count = count + 1 end
  return count > 0 and count == #value
end

local escapes = {
  ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
  ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function encodeString(text)
  local escaped = text:gsub('[%c"\\]', function(char)
    return escapes[char] or string.format("\\u%04x", string.byte(char))
  end)
  return '"' .. escaped .. '"'
end

local function encodeNumber(number)
  if number ~= number or number == math.huge or number == -math.huge then
    return "null"
  end
  if number == math.floor(number) and math.abs(number) < 2^53 then
    return string.format("%d", number)
  end
  return string.format("%.14g", number)
end

local function getSortedKeys(object)
  local keys = {}
  for key in pairs(object) do keys[#keys + 1] = tostring(key) end
  table.sort(keys)
  return keys
end

local encodeValue

local function encodeArray(list, indent, depth)
  if #list == 0 then return "[]" end
  local parts = {}
  for index = 1, #list do
    parts[index] = encodeValue(list[index], indent, depth + 1)
  end
  if not indent then return "[" .. table.concat(parts, ",") .. "]" end
  local innerPad = string.rep(indent, depth + 1)
  local outerPad = string.rep(indent, depth)
  return "[\n" .. innerPad .. table.concat(parts, ",\n" .. innerPad) .. "\n" .. outerPad .. "]"
end

local function encodeObject(object, indent, depth)
  local keys = getSortedKeys(object)
  if #keys == 0 then return "{}" end
  local separator = indent and ": " or ":"
  local parts = {}
  for index, key in ipairs(keys) do
    local value = object[key]
    if value == nil then value = object[tonumber(key)] end
    parts[index] = encodeString(key) .. separator .. encodeValue(value, indent, depth + 1)
  end
  if not indent then return "{" .. table.concat(parts, ",") .. "}" end
  local innerPad = string.rep(indent, depth + 1)
  local outerPad = string.rep(indent, depth)
  return "{\n" .. innerPad .. table.concat(parts, ",\n" .. innerPad) .. "\n" .. outerPad .. "}"
end

encodeValue = function(value, indent, depth)
  local valueType = type(value)
  if value == nil or value == nullValue then return "null" end
  if valueType == "boolean" then return value and "true" or "false" end
  if valueType == "number" then return encodeNumber(value) end
  if valueType == "string" then return encodeString(value) end
  if valueType == "table" then
    if isMarkedArray(value) or isSequence(value) then
      return encodeArray(value, indent, depth)
    end
    return encodeObject(value, indent, depth)
  end
  error("jsonEncoder: cannot encode a " .. valueType)
end

-- Compact JSON, for network messages.
local function encode(value)
  return encodeValue(value, nil, 0)
end

-- Indented JSON with sorted keys, for files people read.
local function encodePretty(value)
  return encodeValue(value, "  ", 0)
end

M.null = nullValue
M.markAsArray = markAsArray
M.encode = encode
M.encodePretty = encodePretty

return M
