-- VRacerMP client: the only file that touches BeamNG's race engine
-- (lua/ge/extensions/gameplay/race/race.lua, bCDDL: called, never copied). NFR-5.
--
-- One RaceEngine follows one vehicle (ours) through the track: pathnodes in order,
-- laps, and crossing times with sub-frame precision.

local RaceEngine = {}
RaceEngine.__index = RaceEngine

local logTag = "vracerMP.raceEngine"
local BEAMNG_RACE_CLASS = "/lua/ge/extensions/gameplay/race/race"

local function createBeamNGRace(raceFilePath, laps)
  local race = require(BEAMNG_RACE_CLASS)()
  race:setPathFile(raceFilePath)
  if not race.path then return nil end
  race.lapCount = laps
  race.useLapTimesApp = false   -- our HUD replaces BeamNG's lap-times app
  race.useHotlappingApp = false
  race.useWaypointAudio = true  -- keep the checkpoint sound
  return race
end

-- Returns a RaceEngine, or nil when the race file cannot be loaded.
function RaceEngine.new(raceFilePath, vehicleId, laps)
  local race = createBeamNGRace(raceFilePath, laps)
  if not race then
    log('E', logTag, "could not load race file " .. tostring(raceFilePath))
    return nil
  end
  local self = setmetatable({}, RaceEngine)
  self.race = race
  self.vehicleId = vehicleId
  race:setVehicleIds({ vehicleId })
  return self
end

function RaceEngine:start()
  self.race:startRace()
end

function RaceEngine:stop()
  if self.race.started then self.race:stopRace() end
end

function RaceEngine:update(dtSim)
  self.race:onUpdate(dtSim)
end

function RaceEngine:getRaceTimeMs()
  return math.floor(self.race.time * 1000 + 0.5)
end

local function getVehicleState(self)
  return self.race.states[self.vehicleId]
end

local function getLatestCrossingTime(state, lapCompleted)
  local times = lapCompleted and state.historicTimes or state.currentTimes
  local latest = times[#times]
  return latest and latest.endTime or nil
end

-- Call after update(). Returns the crossing made this frame, or nil:
--   { raceTimeMs, lapCompleted, raceCompleted }
function RaceEngine:getCrossingThisFrame()
  local state = getVehicleState(self)
  if not state or not state.events then return nil end
  local events = state.events
  if not (events.pathnodeReached or events.lapComplete or events.raceComplete) then return nil end

  local lapCompleted = (events.lapComplete or events.raceComplete) and true or false
  local crossingTime = getLatestCrossingTime(state, lapCompleted) or self.race.time
  return {
    raceTimeMs = math.floor(crossingTime * 1000 + 0.5),
    lapCompleted = lapCompleted,
    raceCompleted = events.raceComplete and true or false,
  }
end

-- Pathnodes to draw: { id, name, pos, radius, normal } for every visible pathnode (VIS-3).
function RaceEngine:getVisiblePathnodes()
  local pathnodes = {}
  for _, pathnode in ipairs(self.race.path.pathnodes.sorted) do
    if pathnode.visible then
      table.insert(pathnodes, {
        id = pathnode.id,
        name = pathnode.name,
        pos = pathnode.pos,
        radius = pathnode.radius,
        normal = pathnode.hasNormal and pathnode.normal or nil,
      })
    end
  end
  return pathnodes
end

-- The next `count` pathnode ids in driving order, the first being the one to reach now.
-- Uses BeamNG's list of upcoming segments, which wraps into the next lap and stops at the
-- finish line on the last lap.
function RaceEngine:getUpcomingPathnodeIds(count)
  local upcomingIds = {}
  local state = getVehicleState(self)
  if not state then return upcomingIds end
  local graph = self.race.path.config.graph
  for _, segmentId in ipairs(state.nonBranchingShiftedPathnodes or {}) do
    if #upcomingIds >= count then break end
    table.insert(upcomingIds, graph[segmentId].targetNode)
  end
  return upcomingIds
end

return RaceEngine
