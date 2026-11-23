-- VRacerMP client: class ClientController, ties tracks, lobbies, our race session and the UI
-- to the server messages. main.lua forwards game hooks here and stays glue only.
-- UI button clicks are handled in controller/uiActions.lua.

local protocol = require("vracerMP/shared/protocol")
local clientNetwork = require("vracerMP/network/clientNetwork")
local trackCatalog = require("vracerMP/tracks/trackCatalog")
local startAreaWatcher = require("vracerMP/tracks/startAreaWatcher")
local StartAreaChoice = require("vracerMP/tracks/startAreaChoice")
local StartAreaChoice = require("vracerMP/tracks/startAreaChoice")
local startAreaVisibility = require("vracerMP/tracks/startAreaVisibility")
local StartAreaMarkers = require("vracerMP/tracks/startAreaMarkers")
local LobbyStore = require("vracerMP/lobby/lobbyStore")
local LapRecordStore = require("vracerMP/lobby/lapRecordStore")
local timeFormat = require("vracerMP/shared/timeFormat")
local RaceSession = require("vracerMP/race/raceSession")
local playerVehicle = require("vracerMP/race/playerVehicle")
local Countdown = require("vracerMP/ui/countdown")
local UiPresenter = require("vracerMP/ui/uiPresenter")
local uiBridge = require("vracerMP/ui/uiBridge")
local layoutInstaller = require("vracerMP/ui/layoutInstaller")
local lobbyView = require("vracerMP/ui/lobbyView")
local raceInfoView = require("vracerMP/ui/raceInfoView")
local lapsView = require("vracerMP/ui/lapsView")
local DeltaDisplay = require("vracerMP/ui/deltaDisplay")
local resultsView = require("vracerMP/ui/resultsView")
local sampleViews = require("vracerMP/ui/sampleViews")
local uiActions = require("vracerMP/controller/uiActions")

local ClientController = {}
ClientController.__index = ClientController

local logTag = "vracerMP"
local toServer = protocol.toServer
local toClient = protocol.toClient
local START_AREA_CHECK_SECONDS = 0.25
local LAYOUT_CHECK_SECONDS = 2
local NOTICE_SECONDS = 5
local RESULTS_AUTO_CLOSE_SECONDS = 30 -- B-6
local LOBBY_REQUEST_RETRY_SECONDS = 2

local function showNotice(text)
  ui_message(text, NOTICE_SECONDS, "vracerMP")
end

function ClientController.new()
  local self = setmetatable({}, ClientController)
  self.tracks = {}
  self.lobbyStore = LobbyStore.new()
  self.lapRecordStore = LapRecordStore.new()
  self.session = nil
  self.results = nil
  self.isListening = false
  self.levelLoaded = false
  self.isWelcomed = false -- the server answered our lobby request
  self.secondsUntilLobbyRequest = 0
  self.trackAtStartArea = nil
  self.startAreaChoice = StartAreaChoice.new() -- shared start areas (B-13)
  self.panelTrack = nil
  self.panelLobby = nil
  self.secondsUntilStartAreaCheck = 0
  self.secondsUntilLayoutCheck = 0
  self.countdown = Countdown.new()
  self.deltaDisplay = DeltaDisplay.new()
  self.presenter = UiPresenter.new(uiBridge.sendToUi)
  self.startAreaMarkers = StartAreaMarkers.new()
  return self
end

-- Level -------------------------------------------------------------------------------

local function serializeTracksForServer(tracks)
  local serialized = {}
  for index, track in ipairs(tracks) do serialized[index] = track:serializeForServer() end
  return serialized
end

-- Asks for the races and lap records, and tells the server which tracks this map has, so
-- races can be created by command (B-4).
local function requestLobbies(self)
  log('D', logTag, "asking the server for races; reporting " .. #self.tracks .. " tracks")
  clientNetwork.send(toServer.requestLobbies, { tracks = serializeTracksForServer(self.tracks) })
end

-- A message sent while we are still joining the server can be lost, so we ask again every
-- few seconds until the server welcomes us.
local function requestLobbiesUntilWelcomed(self, dtReal)
  if self.isWelcomed or not self.isListening or not self.levelLoaded then return end
  self.secondsUntilLobbyRequest = self.secondsUntilLobbyRequest - dtReal
  if self.secondsUntilLobbyRequest > 0 then return end
  self.secondsUntilLobbyRequest = LOBBY_REQUEST_RETRY_SECONDS
  requestLobbies(self)
end

function ClientController:loadLevel()
  self.tracks = trackCatalog.loadTracksForLevel(getCurrentLevelIdentifier())
  self.lobbyStore:clear()
  self.lapRecordStore:clear()
  self.levelLoaded = true
  self.isWelcomed = false
  self.secondsUntilLobbyRequest = 0
end

local function endSession(self)
  if self.session then self.session:dispose() end
  self.session = nil
  self.deltaDisplay:clear()
end

function ClientController:unloadLevel()
  endSession(self)
  self.startAreaMarkers:clear()
  self.tracks = {}
  self.results = nil
  self.levelLoaded = false
  self.isWelcomed = false
  self.trackAtStartArea = nil
  self.lobbyStore:clear()
end

-- Server messages -----------------------------------------------------------------------

local function isAboutMySession(self, payload)
  return self.session ~= nil and payload.raceId == self.session.raceId
end

local function isRacingNow(self)
  return self.session ~= nil and self.session.state ~= RaceSession.state.finished
end

local function handleWelcome(self, payload)
  self.isWelcomed = true
  log('I', logTag, "joined VRacerMP on the server (protocol v" .. tostring(payload.protocolVersion) .. ")")
end

local function handleLobbyUpdated(self, lobby)
  self.lobbyStore:saveLobby(lobby)
end

local function handleRaceRemoved(self, payload)
  self.lobbyStore:removeLobby(payload.raceId)
  if isAboutMySession(self, payload) and not self.results then
    endSession(self)
  end
end

local function handleRaceStarting(self, startInfo)
  local track = trackCatalog.findTrackById(self.tracks, startInfo.missionId)
  local vehicleId = playerVehicle.getVehicleId()
  if not track or not vehicleId then
    log('E', logTag, "cannot start: track " .. tostring(startInfo.missionId) .. " or vehicle missing")
    return
  end
  endSession(self)
  self.results = nil
  self.session = RaceSession.new(track, startInfo, vehicleId)
  if self.session:placeOnGrid() then
    -- The car we race with: players registered by a command had not told the server yet.
    clientNetwork.send(toServer.gridReady, { raceId = startInfo.raceId, vehicle = playerVehicle.getDescription() })
  end
end

local function handleCountdown(self, payload)
  if not isAboutMySession(self, payload) then return end
  self.session:beginCountdown()
  self.countdown:start(payload.goInMs)
  Engine.Audio.playOnce('AudioGui', 'event:UI_Countdown1')
end

local function handleGo(self, payload)
  if not isAboutMySession(self, payload) then return end
  self.countdown:showGo()
  Engine.Audio.playOnce('AudioGui', 'event:UI_CountdownGo')
  if not self.session:go() then showNotice("VRacerMP: could not load the race track") end
end

local function handleGap(self, payload)
  if isAboutMySession(self, payload) then self.deltaDisplay:show(payload) end
end

local function handleStandings(self, payload)
  if isAboutMySession(self, payload) then self.session:applyStandings(payload, clientNetwork.getMyPlayerId()) end
end

local function handleRacerFinished(self, payload)
  if not isAboutMySession(self, payload) then return end
  self.session:applyFinish(payload)
end

local function handleRaceResults(self, results)
  if isRacingNow(self) and not isAboutMySession(self, results) then return end -- a race we left earlier
  endSession(self)
  self.results = results
  self.secondsUntilResultsClose = RESULTS_AUTO_CLOSE_SECONDS
end

local function handleNotice(self, payload)
  showNotice("VRacerMP: " .. tostring(payload.message))
end

local function getPenaltyNotice(penalty)
  return string.format("VRacerMP: %s penalty (%s)", timeFormat.formatSignedDifference(penalty.penaltyMs, "+"),
    tostring(penalty.reason))
end

local function handlePenalty(self, payload)
  if not isAboutMySession(self, payload) then return end
  self.session:applyPenalty(payload)
  showNotice(getPenaltyNotice(payload))
end

local function handleLapRecord(self, record)
  self.lapRecordStore:saveRecord(record)
end

local messageHandlers = {
  [toClient.lobbyUpdated] = handleLobbyUpdated,
  [toClient.raceRemoved] = handleRaceRemoved,
  [toClient.raceStarting] = handleRaceStarting,
  [toClient.countdown] = handleCountdown,
  [toClient.go] = handleGo,
  [toClient.gap] = handleGap,
  [toClient.standings] = handleStandings,
  [toClient.racerFinished] = handleRacerFinished,
  [toClient.raceResults] = handleRaceResults,
  [toClient.notice] = handleNotice,
  [toClient.penalty] = handlePenalty,
  [toClient.lapRecord] = handleLapRecord,
  [toClient.welcome] = handleWelcome,
}

-- BeamMP's networking functions may appear after our extension loads, so this is retried
-- every frame until it succeeds.
local function listenToServerOnce(self)
  if self.isListening or not clientNetwork.isConnectedToBeamMP() then return end
  for eventName, handler in pairs(messageHandlers) do
    clientNetwork.listen(eventName, function(payload) handler(self, payload) end)
  end
  self.isListening = true
end

-- UI ------------------------------------------------------------------------------------

function ClientController:handleUiAction(action)
  uiActions.handle(self, action)
end

function ClientController:closeResults()
  self.results = nil
  self.secondsUntilResultsClose = nil
end

-- The lobby's arrows at a shared start area (B-13): +1 next track, -1 previous.
function ClientController:chooseTrack(delta)
  self.startAreaChoice:step(delta)
  self.trackAtStartArea = self.startAreaChoice:getChosenTrack()
end

function ClientController:resendUi()
  self.presenter:resendAll()
end

-- The lobby to show: the race we joined, else the race of the track picked at the start
-- area we are in. panelTrackChoice: { index, count } only in a start area (B-13).
local function refreshPanelTrackAndLobby(self, myPlayerId)
  self.panelTrack, self.panelLobby, self.panelTrackChoice = nil, nil, nil
  if isRacingNow(self) then return end
  local myLobby = self.lobbyStore:findLobbyOfPlayer(myPlayerId)
  if myLobby then
    self.panelTrack, self.panelLobby = trackCatalog.findTrackById(self.tracks, myLobby.missionId), myLobby
  elseif self.trackAtStartArea then
    self.panelTrack = self.trackAtStartArea
    self.panelLobby = self.lobbyStore:findLobbyForTrack(self.trackAtStartArea.missionId)
    self.panelTrackChoice = self.startAreaChoice:getPosition()
  end
end

local function buildViews(self)
  if uiBridge.isLayoutEditorOpen() then return sampleViews.build() end
  local myPlayerId = clientNetwork.getMyPlayerId()
  refreshPanelTrackAndLobby(self, myPlayerId)
  return {
    lobby = lobbyView.build(self.panelTrack, self.panelLobby, myPlayerId,
      self.panelTrack and self.lapRecordStore:findRecord(self.panelTrack.missionId), self.panelTrackChoice),
    raceInfo = self.session and raceInfoView.build(self.session:getHudData(),
      self.lapRecordStore:findRecord(self.session.track.missionId)) or raceInfoView.HIDDEN,
    deltas = self.deltaDisplay:getView(self.session ~= nil),
    laps = self.session and lapsView.build(self.session:getHudData()) or lapsView.HIDDEN,
    countdown = self.countdown:getView(),
    results = self.results and resultsView.build(self.results, myPlayerId, self.secondsUntilResultsClose)
      or resultsView.HIDDEN,
  }
end

local function installAppsWhenDue(self, dtReal)
  self.secondsUntilLayoutCheck = self.secondsUntilLayoutCheck - dtReal
  if self.secondsUntilLayoutCheck > 0 then return end
  self.secondsUntilLayoutCheck = LAYOUT_CHECK_SECONDS
  layoutInstaller.installIntoCurrentLayout()
end

local function closeResultsWhenDue(self, dtReal)
  if not self.secondsUntilResultsClose then return end
  self.secondsUntilResultsClose = self.secondsUntilResultsClose - dtReal
  if self.secondsUntilResultsClose <= 0 then self:closeResults() end
end

local function updateUi(self, dtReal)
  installAppsWhenDue(self, dtReal)
  closeResultsWhenDue(self, dtReal)
  self.countdown:update(dtReal)
  self.deltaDisplay:update(dtReal)
  self.presenter:present(buildViews(self), dtReal)
end

-- Frame update --------------------------------------------------------------------------

local function refreshStartArea(self, dtReal)
  self.secondsUntilStartAreaCheck = self.secondsUntilStartAreaCheck - dtReal
  if self.secondsUntilStartAreaCheck > 0 then return end
  self.secondsUntilStartAreaCheck = START_AREA_CHECK_SECONDS
  local position = playerVehicle.getPosition()
  local tracksHere = position and startAreaWatcher.findTracksAtPosition(position, self.tracks) or {}
  self.startAreaChoice:update(tracksHere, self.lobbyStore)
  self.trackAtStartArea = self.startAreaChoice:getChosenTrack()
end

local function updateSession(self, dtSim)
  if not self.session then return end
  local crossingMessage = self.session:update(dtSim)
  if crossingMessage then clientNetwork.send(toServer.pathnodeReached, crossingMessage) end
end

function ClientController:update(dtReal, dtSim)
  listenToServerOnce(self)
  requestLobbiesUntilWelcomed(self, dtReal)
  refreshStartArea(self, dtReal)
  updateSession(self, dtSim)
  updateUi(self, dtReal)
end

local function renderStartAreaMarkers(self, dt)
  local openTracks = startAreaVisibility.getTracksOpenForRegistration(self.tracks, self.lobbyStore, isRacingNow(self))
  self.startAreaMarkers:render(openTracks, dt)
end

function ClientController:render(dt, dtSim)
  if self.session then self.session:render(dt, dtSim) end
  renderStartAreaMarkers(self, dt)
end

return ClientController
