-- VRacerMP server: class ResultsAnnouncer, publishes a finished race's results (LOG-1).
-- The results JSON (requirements §6) is sent once, as one chat message to everyone, and
-- also printed to the server console. No files are written on the server.

local jsonEncoder = require("vracerMP/shared/jsonEncoder")
local log = require("vracerMP/util/serverLog").log

local logTag = "vracerMP.results"

local ResultsAnnouncer = {}
ResultsAnnouncer.__index = ResultsAnnouncer

-- network: anything with broadcastChat(text) (serverNetwork, or a test fake).
function ResultsAnnouncer.new(network)
  local self = setmetatable({}, ResultsAnnouncer)
  self.network = network
  return self
end

function ResultsAnnouncer:announceRace(race)
  local resultsJson = jsonEncoder.encode(race:serialize())
  self.network.broadcastChat(resultsJson)
  log('I', logTag, resultsJson)
  return resultsJson
end

return ResultsAnnouncer
