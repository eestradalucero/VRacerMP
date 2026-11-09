-- VRacerMP client: class RaceSession, our car's part in one race.
--
--   gridding -> countdown -> racing -> finished
--
-- It places the car, runs BeamNG's race engine and markers from GO, turns crossings into
-- messages for the server, and keeps what the HUD shows. It never decides positions:
-- those come from the server (NFR-1).

local RaceEngine = require("vracerMP/race/raceEngineAdapter")
local PathnodeMarkers = require("vracerMP/race/markerAdapter")
local gridPlacement = require("vracerMP/race/gridPlacement")

local RaceSession = {}
RaceSession.__index = RaceSession

local logTag = "vracerMP.session"
local VISIBLE_PATHNODE_COUNT = 3 -- the next pathnode plus the two after it

RaceSession.state = {
  gridding = "gridding",
  countdown = "countdown",
  racing = "racing",
  finished = "finished",
}

-- startInfo: the raceStarting payload { raceId, missionId, laps, gridSlot, racerCount }.
function RaceSession.new(track, startInfo, vehicleId)
  local self = setmetatable({}, RaceSession)
  self.track = track
  self.raceId = startInfo.raceId
  self.laps = startInfo.laps
  self.gridSlot = startInfo.gridSlot
  self.vehicleId = vehicleId
  self.state = RaceSession.state.gridding
  self.engine = nil
  self.markers = nil
  self.crossingCount = 0
  self.lapTimesMs = {}
  self.lastLapEndMs = 0
  self.raceTimeMs = 0
  self.position = startInfo.gridSlot
  self.racerCount = startInfo.racerCount
  self.aheadGapMs = nil
  self.behindGapMs = nil
  self.finishInfo = nil
  return self
end

function RaceSession:placeOnGrid()
  return gridPlacement.moveVehicleToSlot(self.vehicleId, self.track:getGridSlot(self.gridSlot))
end

function RaceSession:beginCountdown()
  self.state = RaceSession.state.countdown
end

local function refreshMarkers(self)
  self.markers:showUpcoming(self.engine:getUpcomingPathnodeIds(VISIBLE_PATHNODE_COUNT))
end

local function showMarkers(self)
  self.markers = PathnodeMarkers.new(self.engine:getVisiblePathnodes())
  refreshMarkers(self)
end

-- GO: start the race engine and show the markers. Returns false if the track failed to load.
function RaceSession:go()
  self.engine = RaceEngine.new(self.track.raceFilePath, self.vehicleId, self.laps)
  if not self.engine then return false end
  self.engine:start()
  showMarkers(self)
  self.state = RaceSession.state.racing
  log('I', logTag, "GO on " .. self.track.missionId)
  return true
end

local function removeRaceObjects(self)
  if self.engine then self.engine:stop() end
  if self.markers then self.markers:remove() end
  self.engine = nil
  self.markers = nil
end

local function recordLocalCrossing(self, crossing)
  self.crossingCount = self.crossingCount + 1
  if crossing.lapCompleted then
    table.insert(self.lapTimesMs, crossing.raceTimeMs - self.lastLapEndMs)
    self.lastLapEndMs = crossing.raceTimeMs
  end
  if crossing.raceCompleted then
    self.raceTimeMs = crossing.raceTimeMs
    self.state = RaceSession.state.finished
    removeRaceObjects(self)
  elseif self.markers then
    refreshMarkers(self)
  end
end

local function buildCrossingMessage(self, crossing)
  return {
    raceId = self.raceId,
    crossingNumber = self.crossingCount,
    raceTimeMs = crossing.raceTimeMs,
    lapCompleted = crossing.lapCompleted,
  }
end

-- Advances the race. Returns a pathnodeReached message when a pathnode was crossed.
function RaceSession:update(dtSim)
  if self.state ~= RaceSession.state.racing or not self.engine then return nil end
  self.engine:update(dtSim)
  self.raceTimeMs = self.engine:getRaceTimeMs()
  local crossing = self.engine:getCrossingThisFrame()
  if not crossing then return nil end
  recordLocalCrossing(self, crossing)
  return buildCrossingMessage(self, crossing)
end

function RaceSession:render(dt, dtSim)
  if self.markers then self.markers:render(dt, dtSim) end
end

-- Server messages -----------------------------------------------------------------

function RaceSession:applyStandings(standings, myPlayerId)
  self.racerCount = standings.racerCount or self.racerCount
  for _, entry in ipairs(standings.entries or {}) do
    if entry.id == myPlayerId then self.position = entry.position end
  end
end

function RaceSession:applyGap(gap)
  if gap.kind == "ahead" then
    self.aheadGapMs = gap.gapMs
  else
    self.behindGapMs = gap.gapMs
  end
end

-- racerFinished payload: we finished or became DNF.
function RaceSession:applyFinish(finishInfo)
  self.finishInfo = finishInfo
  self.position = finishInfo.position
  self.state = RaceSession.state.finished
  removeRaceObjects(self)
end

function RaceSession:dispose()
  removeRaceObjects(self)
end

-- HUD ------------------------------------------------------------------------------

local function getBestLapMs(lapTimesMs)
  local best = nil
  for _, lapTimeMs in ipairs(lapTimesMs) do
    if not best or lapTimeMs < best then best = lapTimeMs end
  end
  return best
end

local function getPathnodesPassedThisLap(self)
  return self.crossingCount - #self.lapTimesMs * self.track.pathnodeCount
end

local function getCurrentLap(self)
  return math.min(#self.lapTimesMs + 1, self.laps)
end

-- Everything the HUD shows (UI-1 .. UI-9).
function RaceSession:getHudData()
  return {
    state = self.state,
    position = self.position,
    racerCount = self.racerCount,
    currentLap = getCurrentLap(self),
    laps = self.laps,
    raceTimeMs = self.raceTimeMs,
    bestLapMs = getBestLapMs(self.lapTimesMs),
    pathnodesPassed = getPathnodesPassedThisLap(self),
    pathnodeCount = self.track.pathnodeCount,
    aheadGapMs = self.aheadGapMs,
    behindGapMs = self.behindGapMs,
    finishInfo = self.finishInfo,
  }
end

return RaceSession
