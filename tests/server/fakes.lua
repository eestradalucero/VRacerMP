-- Test doubles for the server's edges: clock, network (messages and chat), player directory.

local M = {}

function M.newClock(startMs)
  local clock = { nowMs = startMs or 0 }
  function clock:getNowMs() return self.nowMs end
  function clock:getUtcIso() return "2026-11-08T12:00:00Z" end
  function clock:advance(ms) self.nowMs = self.nowMs + ms end
  return clock
end

function M.newNetwork()
  local network = { sent = {}, chats = {} }
  local function record(playerId, eventName, payload)
    table.insert(network.sent, { playerId = playerId, eventName = eventName, payload = payload })
  end
  function network.sendToPlayer(playerId, eventName, payload)
    if playerId >= 0 then record(playerId, eventName, payload) end
  end
  function network.sendToPlayers(playerIds, eventName, payload)
    for _, playerId in ipairs(playerIds) do network.sendToPlayer(playerId, eventName, payload) end
  end
  function network.broadcast(eventName, payload)
    record(-1, eventName, payload)
  end
  function network.broadcastChat(text)
    table.insert(network.chats, text)
  end
  -- Messages of one event, optionally only those sent to one player.
  function network:getMessages(eventName, playerId)
    local found = {}
    for _, message in ipairs(self.sent) do
      if message.eventName == eventName and (playerId == nil or message.playerId == playerId) then
        table.insert(found, message)
      end
    end
    return found
  end
  function network:getLastPayload(eventName, playerId)
    local found = self:getMessages(eventName, playerId)
    return found[#found] and found[#found].payload or nil
  end
  return network
end

-- namesById: connected players, e.g. { [1] = "Ana", [2] = "Bob" }; by default every ID is
-- "Player<id>".
function M.newPlayerDirectory(namesById)
  local directory = {}
  function directory.getPlayerName(playerId)
    return namesById and namesById[playerId] or ("Player" .. playerId)
  end
  function directory.readVehicle(vehicle)
    if type(vehicle) ~= "table" or not vehicle.model then return nil end
    return { model = vehicle.model }
  end
  function directory.buildPlayer(playerId, vehicle)
    return { playerId = playerId, name = directory.getPlayerName(playerId), beammpId = "id" .. playerId,
      vehicle = directory.readVehicle(vehicle) or {} }
  end
  function directory.getConnectedPlayerIds()
    local playerIds = {}
    for playerId in pairs(namesById or {}) do table.insert(playerIds, playerId) end
    table.sort(playerIds)
    return playerIds
  end
  function directory.findPlayerIdsByName(name)
    local playerIds = {}
    for playerId, playerName in pairs(namesById or {}) do
      if playerName:lower() == name:lower() then table.insert(playerIds, playerId) end
    end
    table.sort(playerIds)
    return playerIds
  end
  return directory
end

-- Records what is published for other plugins.
function M.newPluginEvents()
  local pluginEvents = { published = {} }
  function pluginEvents.publish(eventName, payload)
    table.insert(pluginEvents.published, { eventName = eventName, payload = payload })
  end
  function pluginEvents:getLastPayload(eventName)
    for index = #self.published, 1, -1 do
      if self.published[index].eventName == eventName then return self.published[index].payload end
    end
    return nil
  end
  return pluginEvents
end

function M.newTrackData(overrides)
  local track = {
    missionId = "vracer_bajasur/timeTrial/001-Circuito",
    level = "vracer_bajasur",
    name = "Circuito Bronco Short Course",
    closed = true,
    pathnodeCount = 4,
    defaultLaps = 2,
  }
  for key, value in pairs(overrides or {}) do track[key] = value end
  return track
end

return M
