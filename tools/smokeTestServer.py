"""Smoke test: loads the BUILT server plugin (export/Resources/Server/VRacerMP/main.lua) on
Lua 5.3 with a mock BeamMP API, then plays a short race through the real event handlers
and prints the results message sent to chat. It runs from export/ like a server runs from its
own folder, and without the debug library, which BeamMP hosts refuse.

Run tools/build.ps1 first, then:
    python tools/smokeTestServer.py
Needs `lupa` (python -m pip install --user lupa).
"""
import json
import os
import sys

import lupa.lua53

MOCK_BEAMMP = r"""
local mock = { sent = {}, events = {}, timers = {}, nowSeconds = 0, chat = {} }
local function noop() end
MP = {
  RegisterEvent = function(eventName, handlerName) mock.events[eventName] = handlerName end,
  CreateEventTimer = function(eventName, ms) mock.timers[eventName] = ms end,
  TriggerClientEvent = function(playerId, eventName, data)
    table.insert(mock.sent, { playerId = playerId, eventName = eventName, data = data })
    return true
  end,
  CreateTimer = function() return { GetCurrent = function() return mock.nowSeconds end } end,
  GetPlayerName = function(playerId) return "Player" .. playerId end,
  GetPlayerIdentifiers = function(playerId) return { beammp = tostring(1000 + playerId) } end,
  SendChatMessage = function(playerId, text) table.insert(mock.chat, text) end,
}
Util = { LogInfo = noop, LogWarn = print, LogError = print, LogDebug = noop, JsonDecode = PYTHON_JSON_DECODE }
return mock
"""


def to_lua(lua, value):
    if isinstance(value, dict):
        return lua.table_from({k: to_lua(lua, v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([to_lua(lua, v) for v in value])
    return value


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    plugin_main = "Resources/Server/VRacerMP/main.lua"
    if not os.path.exists(os.path.join("export", plugin_main)):
        print("Build first: tools/build.ps1")
        return 1
    os.chdir("export")

    lua = lupa.lua53.LuaRuntime()
    lua.globals().PYTHON_JSON_DECODE = lambda text: to_lua(lua, json.loads(text))
    mock = lua.execute(MOCK_BEAMMP)
    lua.execute(f'debug = nil; dofile("{plugin_main}")')

    g = lua.globals()

    def call(event, player_id, payload):
        handler = mock.events[event]
        g[handler](player_id, json.dumps(payload))

    def advance(seconds):
        steps = int(seconds * 10)
        for _ in range(steps):
            mock.nowSeconds = mock.nowSeconds + 0.1
            g.handleTick()

    def last(event_name, player_id=None):
        for message in reversed(list(mock.sent.values())):
            if message.eventName == event_name and (player_id is None or message.playerId == player_id):
                return json.loads(message.data)
        return None

    print("registered events:", sorted(mock.events.keys()))
    track = {"missionId": "vracer_bajasur/timeTrial/001-Circuito", "level": "vracer_bajasur",
             "name": "Circuito Bronco Short Course", "closed": True, "pathnodeCount": 3, "defaultLaps": 2}
    call("vracerMP_register", 0, {"track": track, "vehicle": {"model": "etk800", "config": "856_m"}})
    race_id = last("vracerMP_lobbyUpdated")["raceId"]
    g.handleChatMessage(0, "Player0", "/vracer fake 30")
    print("chat reply:", list(mock.chat.values())[-1])
    call("vracerMP_configure", 0, {"raceId": race_id, "laps": 1})
    call("vracerMP_startRace", 0, {"raceId": race_id})
    print("raceStarting:", last("vracerMP_raceStarting", 0))
    call("vracerMP_gridReady", 0, {"raceId": race_id})
    print("countdown:", last("vracerMP_countdown", 0))
    advance(3.1)
    print("go:", last("vracerMP_go", 0))
    for crossing in range(1, 4):
        advance(9)
        call("vracerMP_pathnodeReached", 0, {"raceId": race_id, "crossingNumber": crossing,
                                             "raceTimeMs": crossing * 9000, "lapCompleted": crossing == 3})
        print("gap:", last("vracerMP_gap", 0), "| standings P:",
              [e["id"] for e in last("vracerMP_standings", 0)["entries"]])
    print("finished:", last("vracerMP_racerFinished", 0))
    advance(35)
    results = last("vracerMP_raceResults", 0)
    print("results status:", results and results["status"])
    for racer in (results or {}).get("racers", []):
        stats = racer["raceStats"]
        print("  P%s %s %s laps=%s best=%s" % (racer["position"], racer["name"], stats["totalTimeReadable"],
                                               stats["lapTimesReadable"], stats["bestLap"]))
    chat_messages = list(mock.chat.values())
    results_chat = chat_messages[-1] if chat_messages else ""
    print("results chat message (%d characters):" % len(results_chat))
    print(results_chat)
    return 0 if results and results["status"] == "finished" else 1


if __name__ == "__main__":
    sys.exit(main())
