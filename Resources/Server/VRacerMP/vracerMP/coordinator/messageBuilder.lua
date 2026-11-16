-- VRacerMP server: builds the payloads sent to clients. Pure functions.
-- docs/protocol.md documents every payload; keep the two in sync.

local jsonEncoder = require("vracerMP/shared/jsonEncoder")

local M = {}

local function buildLobbyRacers(race)
  local racers = {}
  for index, racer in ipairs(race.racers) do
    racers[index] = { id = racer.playerId, name = racer.name, status = racer.status }
  end
  return jsonEncoder.markAsArray(racers)
end

local function buildLobby(race)
  local owner = race:getOwner()
  return {
    raceId = race.raceId,
    missionId = race.track.missionId,
    trackName = race.track.name,
    closed = race.track.closed,
    state = race.state,
    ownerId = owner and owner.playerId or -1,
    ownerName = race:getOwnerName(),
    serverOwned = race:isServerOwned(), -- created from the console or a plugin (B-4)
    laps = race.settings.laps,
    dnfTimeoutSeconds = race.settings.dnfTimeoutSeconds,
    racers = buildLobbyRacers(race),
  }
end

local function buildRaceRemoved(race)
  return { raceId = race.raceId, missionId = race.track.missionId }
end

local function buildRaceStarting(race, racer)
  return {
    raceId = race.raceId,
    missionId = race.track.missionId,
    laps = race.settings.laps,
    gridSlot = racer.gridSlot,
    racerCount = #race.racers,
  }
end

local function buildCountdown(race, countdownMs)
  return { raceId = race.raceId, goInMs = countdownMs }
end

local function buildGo(race)
  return { raceId = race.raceId }
end

local function buildGap(race, gapKind, gapMs)
  return { raceId = race.raceId, kind = gapKind, gapMs = gapMs }
end

local function buildStandings(race)
  local entries = {}
  for index, racer in ipairs(race:getOrderedRacers()) do
    entries[index] = {
      id = racer.playerId,
      name = racer.name,
      position = racer.position or index,
      lapsCompleted = racer:getLapsCompleted(),
      crossings = racer.crossingCount,
      penaltyTime = racer.penaltyTimeMs,
      status = racer.status,
    }
  end
  return { raceId = race.raceId, racerCount = #race.racers, entries = jsonEncoder.markAsArray(entries) }
end

local function buildRacerFinished(race, racer)
  return {
    raceId = race.raceId,
    status = racer.status,
    dnfReason = racer.dnfReason or "",
    position = racer.position or 0,
    racerCount = #race.racers,
    totalTimeMs = racer:getTotalTimeMs() or -1,
    bestLapTimeMs = racer:getBestLapTimeMs() or -1,
  }
end

-- The full results (same shape as the results JSON in chat), for the results panel.
local function buildRaceResults(race)
  return race:serialize()
end

local function buildNotice(message)
  return { message = message }
end

local function buildPenalty(race, racer, penalty)
  return {
    raceId = race.raceId,
    reason = penalty.reason,
    penaltyMs = penalty.penaltyMs,
    totalPenaltyMs = racer.penaltyTimeMs,
  }
end

local function buildLapRecord(record)
  return {
    missionId = record.missionId,
    trackName = record.trackName,
    lapTimeMs = record.lapTimeMs,
    name = record.name,
    model = record.model,
  }
end

M.buildLobby = buildLobby
M.buildRaceRemoved = buildRaceRemoved
M.buildRaceStarting = buildRaceStarting
M.buildCountdown = buildCountdown
M.buildGo = buildGo
M.buildGap = buildGap
M.buildStandings = buildStandings
M.buildRacerFinished = buildRacerFinished
M.buildRaceResults = buildRaceResults
M.buildNotice = buildNotice
M.buildPenalty = buildPenalty
M.buildLapRecord = buildLapRecord

return M
