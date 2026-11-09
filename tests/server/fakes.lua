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

function M.newPlayerDirectory()
  local directory = {}
  function directory.buildPlayer(playerId, vehicle)
    return { playerId = playerId, name = "Player" .. playerId, beammpId = "id" .. playerId, vehicle = vehicle }
  end
  return directory
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
