-- VRacerMP client: class ClientController, ties tracks, lobbies, our race session and the UI
-- to the server messages. main.lua forwards game hooks here and stays glue only.
-- UI button clicks are handled in controller/uiActions.lua.

local protocol = require("vracerMP/shared/protocol")
local clientNetwork = require("vracerMP/network/clientNetwork")
local trackCatalog = require("vracerMP/tracks/trackCatalog")
local startAreaWatcher = require("vracerMP/tracks/startAreaWatcher")
local startAreaVisibility = require("vracerMP/tracks/startAreaVisibility")
local StartAreaMarkers = require("vracerMP/tracks/startAreaMarkers")
local LobbyStore = require("vracerMP/lobby/lobbyStore")
local RaceSession = require("vracerMP/race/raceSession")
local playerVehicle = require("vracerMP/race/playerVehicle")
local Countdown = require("vracerMP/ui/countdown")
local UiPresenter = require("vracerMP/ui/uiPresenter")
local uiBridge = require("vracerMP/ui/uiBridge")
local layoutInstaller = require("vracerMP/ui/layoutInstaller")
local lobbyView = require("vracerMP/ui/lobbyView")
local raceView = require("vracerMP/ui/raceView")
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

local function showNotice(text)
  ui_message(text, NOTICE_SECONDS, "vracerMP")
end

function ClientController.new()
  local self = setmetatable({}, ClientController)
  self.tracks = {}
  self.lobbyStore = LobbyStore.new()
  self.session = nil
  self.results = nil
  self.isListening = false
  self.levelLoaded = false
  self.trackAtStartArea = nil
  self.panelTrack = nil
  self.panelLobby = nil
  self.secondsUntilStartAreaCheck = 0
  self.secondsUntilLayoutCheck = 0
  self.countdown = Countdown.new()
  self.presenter = UiPresenter.new(uiBridge.sendToUi)
  self.startAreaMarkers = StartAreaMarkers.new()
  return self
end

-- Level -------------------------------------------------------------------------------

function ClientController:loadLevel()
  self.tracks = trackCatalog.loadTracksForLevel(getCurrentLevelIdentifier())
  self.lobbyStore:clear()
  self.levelLoaded = true
  if self.isListening then clientNetwork.send(toServer.requestLobbies, {}) end
end

local function endSession(self)
  if self.session then self.session:dispose() end
  self.session = nil
end

function ClientController:unloadLevel()
  endSession(self)
  self.startAreaMarkers:clear()
  self.tracks = {}
  self.results = nil
  self.levelLoaded = false
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
    clientNetwork.send(toServer.gridReady, { raceId = startInfo.raceId })
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
  if isAboutMySession(self, payload) then self.session:applyGap(payload) end
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
end

local function handleNotice(self, payload)
  showNotice("VRacerMP: " .. tostring(payload.message))
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
}

-- BeamMP's networking functions may appear after our extension loads, so this is retried
-- every frame until it succeeds.
local function listenToServerOnce(self)
  if self.isListening or not clientNetwork.isConnectedToBeamMP() then return end
  for eventName, handler in pairs(messageHandlers) do
    clientNetwork.listen(eventName, function(payload) handler(self, payload) end)
  end
  self.isListening = true
  if self.levelLoaded then clientNetwork.send(toServer.requestLobbies, {}) end
end

-- UI ------------------------------------------------------------------------------------

function ClientController:handleUiAction(action)
  uiActions.handle(self, action)
end

function ClientController:closeResults()
  self.results = nil
end

function ClientController:resendUi()
  self.presenter:resendAll()
end

-- The lobby to show: the race we joined, else the race at the start area we are in.
local function refreshPanelTrackAndLobby(self, myPlayerId)
  self.panelTrack, self.panelLobby = nil, nil
  if isRacingNow(self) then return end
  local myLobby = self.lobbyStore:findLobbyOfPlayer(myPlayerId)
  if myLobby then
    self.panelTrack, self.panelLobby = trackCatalog.findTrackById(self.tracks, myLobby.missionId), myLobby
  elseif self.trackAtStartArea then
    self.panelTrack = self.trackAtStartArea
    self.panelLobby = self.lobbyStore:findLobbyForTrack(self.trackAtStartArea.missionId)
  end
end

local function buildViews(self)
  if uiBridge.isLayoutEditorOpen() then return sampleViews.build() end
  local myPlayerId = clientNetwork.getMyPlayerId()
  refreshPanelTrackAndLobby(self, myPlayerId)
  return {
    lobby = lobbyView.build(self.panelTrack, self.panelLobby, myPlayerId),
    race = self.session and raceView.build(self.session:getHudData()) or raceView.HIDDEN,
    countdown = self.countdown:getView(),
    results = self.results and resultsView.build(self.results) or resultsView.HIDDEN,
  }
end

local function installAppsWhenDue(self, dtReal)
  self.secondsUntilLayoutCheck = self.secondsUntilLayoutCheck - dtReal
  if self.secondsUntilLayoutCheck > 0 then return end
  self.secondsUntilLayoutCheck = LAYOUT_CHECK_SECONDS
  layoutInstaller.installIntoCurrentLayout()
end

local function updateUi(self, dtReal)
  installAppsWhenDue(self, dtReal)
  self.countdown:update(dtReal)
  self.presenter:present(buildViews(self), dtReal)
end

-- Frame update --------------------------------------------------------------------------

local function refreshStartArea(self, dtReal)
  self.secondsUntilStartAreaCheck = self.secondsUntilStartAreaCheck - dtReal
  if self.secondsUntilStartAreaCheck > 0 then return end
  self.secondsUntilStartAreaCheck = START_AREA_CHECK_SECONDS
  local position = playerVehicle.getPosition()
  self.trackAtStartArea = position and startAreaWatcher.findTrackAtPosition(position, self.tracks) or nil
end

local function updateSession(self, dtSim)
  if not self.session then return end
  local crossingMessage = self.session:update(dtSim)
  if crossingMessage then clientNetwork.send(toServer.pathnodeReached, crossingMessage) end
end

function ClientController:update(dtReal, dtSim)
  listenToServerOnce(self)
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
