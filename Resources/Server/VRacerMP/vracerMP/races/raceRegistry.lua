-- VRacerMP server: class RaceRegistry, every race on the server and who is in which.
-- Several races can exist at once (REG-11); a player is racing in at most one (REG-8).

local Race = require("vracerMP/races/race")

local RaceRegistry = {}
RaceRegistry.__index = RaceRegistry

function RaceRegistry.new(clock)
  local self = setmetatable({}, RaceRegistry)
  self.clock = clock
  self.races = {} -- in creation order
  self.lastRaceNumber = 0
  return self
end

local function createRaceId(self)
  self.lastRaceNumber = self.lastRaceNumber + 1
  return "r-" .. self.lastRaceNumber
end

function RaceRegistry:createRace(track)
  local race = Race.new(createRaceId(self), track, self.clock)
  table.insert(self.races, race)
  return race
end

function RaceRegistry:removeRace(raceId)
  for index, race in ipairs(self.races) do
    if race.raceId == raceId then
      table.remove(self.races, index)
      return
    end
  end
end

function RaceRegistry:getAllRaces()
  local copy = {}
  for index, race in ipairs(self.races) do copy[index] = race end
  return copy
end

function RaceRegistry:findRaceById(raceId)
  for _, race in ipairs(self.races) do
    if race.raceId == raceId then return race end
  end
  return nil
end

-- The race on this track that still accepts registrations, if any.
function RaceRegistry:findOpenRaceForTrack(missionId)
  for _, race in ipairs(self.races) do
    if race.track.missionId == missionId and race:isRegistrationOpen() then return race end
  end
  return nil
end

-- True when any race on this track has started and is not over yet.
function RaceRegistry:isTrackBusy(missionId)
  for _, race in ipairs(self.races) do
    if race.track.missionId == missionId and race:hasStarted() and not race:isOver() then return true end
  end
  return false
end

-- The race the player is still in. Once they finished or dropped out they are free to
-- register for another race (REG-12), even while this one goes on.
function RaceRegistry:findRaceOfPlayer(playerId)
  for _, race in ipairs(self.races) do
    local racer = race:getRacer(playerId)
    if racer and not race:isOver() and not racer:hasLeftTheRace() then return race end
  end
  return nil
end

return RaceRegistry
