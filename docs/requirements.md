# VRacerMP — Requirements

Living document. Updated as we discuss; every change is recorded in the
[Decision log](#10-decision-log).

**Status legend:** `Agreed` — confirmed by the project owner. `Proposed` — suggested,
waiting for confirmation. `Open` — needs a decision (see [§8](#8-open-questions)).
**Priority:** `MVP` — needed for the first playable version. `Later` — planned, not in the first version.

---

## 1. Purpose

Let several players on a BeamMP server race each other **at the same time** on
tracks built with BeamNG's own Race Editor (the files used by single-player Time
Trials), with registration, a synchronized start, live timing and positions,
and the race results sent to the server chat as JSON.

## 2. Glossary

| Term | Meaning |
|------|---------|
| **Track** | A race file (`race.race.json`) plus its mission info (`info.json`), e.g. `gameplay/missions/vracer_bajasur/timeTrial/001-Circuito/`. |
| **Pathnode** | A gate on the track (position, radius, direction). Racers must pass them in order. |
| **Split** | A pathnode marked `useAsSplit: true` in the race file. |
| **Start area** | Circle defined by `info.json → startTrigger` (`pos`, `radius`). |
| **Race** | One instance of a track being raced: its racers, settings and results. |
| **Owner** | The first player who registered for a race. Only the owner can configure and start it. |
| **Racer** | A player registered for a race. |
| **Landrush** | Everyone starts at the same time from a grid; first across the line wins. |
| **Staggered** | Racers start in groups every *x* seconds; best time wins. |
| **DNF** | Did Not Finish. |

## 3. Track source

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| TRK-1 | Tracks are read from BeamNG race files: `gameplay/missions/<level>/timeTrial/<mission>/info.json` and `race.race.json`. | MVP | Agreed |
| TRK-2 | Track order comes from `startNode` and the `segments` list (`from` → `to`, using `oldId`). | MVP | Proposed |
| TRK-3 | Closed tracks (`classification.closed: true`) are lapped: crossing the start node completes a lap. Open tracks (point-to-point, `endNode` set) are always 1 lap. | MVP | Proposed |
| TRK-4 | Only tracks for the level currently loaded are offered. | MVP | Proposed |
| TRK-5 | Tracks normally come with the **map mod** (Vracer_BajaSur ships its time trials). Only tracks that are in no map are shipped in the VRacerMP client mod, under the same path `gameplay/missions/<level>/timeTrial/<mission>/`. A mission must exist in one place only, or the copy used depends on load order. Players' local copies in their BeamNG user folder override both and must match the server's. | MVP | Agreed |
| TRK-6 | Grid slots come from `startPositions` whose name starts with `Start Position`, in list order (the list also contains recovery points, which are skipped). Tracks should define enough slots for the expected racers; when they don't, the missing slots are generated behind the default start position (2 columns, configurable spacing). | MVP | Agreed |
| TRK-8 | Optional BeamMP-only track configuration file (e.g. custom grid, BeamMP-specific settings), and BeamMP-only tracks that don't appear as single-player missions. | Later | Agreed |
| TRK-7 | Branching tracks (`classification.branching: true`) are not supported. | MVP | Proposed |

## 4. Functional requirements

### 4.1 Registration (REG)

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| REG-1 | When a player's vehicle is inside a track's start area, a panel shows the track name and a **Register** / **Unregister** button. | MVP | Agreed |
| REG-2 | The first player to register becomes the **owner**. | MVP | Agreed |
| REG-3 | Only the owner can change settings: number of laps, DNF timeout. | MVP | Agreed |
| REG-4 | The track is the one whose start area the owner registered at; it cannot be changed afterwards. | MVP | Agreed |
| REG-5 | The panel shows the list of registered racers and the current settings to everyone in the start area. | MVP | Proposed |
| REG-6 | Only the owner sees a **Start race** button. | MVP | Agreed |
| REG-7 | If the owner unregisters or disconnects, ownership passes to the next racer in registration order. If nobody is left, the race is removed. | MVP | Proposed |
| REG-8 | A player can be registered in only one race at a time. | MVP | Proposed |
| REG-9 | Registration closes when the race starts. | MVP | Proposed |
| REG-10 | Default lap count comes from `race.race.json → defaultLaps`. | MVP | Proposed |
| REG-11 | Several races, on different tracks, can exist and run at the same time. The data model and protocol support it from day one; the UI may expose one race per track. | Later (design: MVP) | Agreed |

### 4.2 Race start (START)

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| START-1 | On **Start race**, every racer's current vehicle is moved to its grid slot. Racers keep the vehicle they are driving. | MVP | Agreed |
| START-2 | Grid order: registration order. (Later: random, or by qualifying time.) | MVP | Agreed |
| START-3 | While on the grid, cars cannot move: neutral / handbrake held, but the engine can be revved. Any implementation is fine: BeamNG's built-in freeze, or our own. The MVP can be tested without it. | Later | Agreed |
| START-4 | A countdown (3-2-1-GO) is shown to all racers. It doesn't have to be BeamNG's built-in one; our own overlay is fine, ideally with each number animating in size and transparency. | MVP | Agreed |
| START-5 | GO is decided by the server and sent to all racers at the same moment. Each client runs its countdown locally, timed to end at GO. | MVP | Proposed |
| START-6 | At GO, all cars are released at once. | MVP | Agreed |
| START-7 | A racer who drives off the grid before GO gets a jump-start penalty. | Later | Proposed |
| START-8 | Racer vehicles that are not on the grid at start (e.g. player deleted the car) are DNF. | MVP | Proposed |

### 4.3 Timing (TIME)

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| TIME-1 | Track per racer: total race time, current race time, every lap time, best lap. | MVP | Agreed |
| TIME-2 | Landrush: every racer's race clock starts at **GO**, so total time matches finishing order. Lap 1 runs from GO around the whole track to the start pathnode, like single-player Time Trials (the grid is behind the start pathnode; see architecture A-2). (Staggered races, later: each racer's clock starts at their own first-pathnode crossing.) | MVP | Agreed |
| TIME-3 | Pathnodes must be passed in order. Missing one keeps the next pathnode as the target (the racer has to go back). | MVP | Proposed |
| TIME-4 | Times are stored and sent as integer **milliseconds**. | MVP | Proposed |
| TIME-5 | The server checks that reported times are plausible against its own clock (anti-cheat, tolerance about 1 s). | MVP | Proposed |
| TIME-6 | Reset / recover policy (allowed, penalty, or forbidden) is a race setting. Defaults from `info.json` (`allowRecover`, `recoverPenalty`, `allowFlip`). | Later | Agreed |
| TIME-7 | Resets / recoveries during a race are allowed without penalty and counted per racer (`recoveries` in the results). | MVP | Agreed |

### 4.4 Pathnode visuals (VIS)

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| VIS-1 | Pathnodes are shown like single-player Time Trials: two pillars per pathnode, **orange** for the next pathnode, **grey** for the two after it. All others are hidden, so the map does not get crowded. | MVP | Agreed |
| VIS-2 | Only racers in a running race see that race's pathnodes; other players don't. | MVP | Proposed |
| VIS-3 | Pathnodes with `visible: false` are not drawn but still count. | MVP | Proposed |
| VIS-4 | The final pathnode of the last lap is shown as the finish line. | Later | Proposed |

### 4.5 Race HUD (UI)

The UI uses BeamNG's own look (fonts, colours, components). Apps are on screen by default,
like BeamMP's chat, and players can move them in BeamNG's layout editor (architecture UI-T3..T7).

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| UI-1 | Position in race (e.g. `P2 / 6`). | MVP | Agreed |
| UI-2 | Position is updated at every pathnode. | MVP | Agreed |
| UI-3 | Position is updated continuously using lap + pathnode + distance to the next pathnode. | Later | Agreed |
| UI-4 | Current lap / total laps. | MVP | Agreed |
| UI-5 | Current race time. | MVP | Agreed |
| UI-6 | Best lap in this race, if any. | MVP | Agreed |
| UI-7 | Pathnodes passed / total, for the current lap. | MVP | Agreed |
| UI-8 | At every pathnode: the gap to the car ahead in **red** (`-0:00.000`), shown immediately. | MVP | Agreed |
| UI-9 | Gap to the car behind in **green** (`+0:00.000`), shown when the car behind reaches that same pathnode (it can't be known earlier). | MVP | Agreed |
| UI-10 | Time format everywhere: `m:ss.mmm` (`mm:ss.mmm` in files). | MVP | Proposed |

### 4.6 Finish (FIN)

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FIN-1 | A racer finishes when crossing the line at the end of the last lap. They see a "Finished" message with their position and time, using BeamNG's built-in finish screen if it can be reused, otherwise our own. | MVP | Agreed |
| FIN-2 | When the first racer finishes, a DNF timer starts (owner setting, default 120 s). Racers still racing when it runs out are DNF (`timeout`). | MVP | Agreed |
| FIN-3 | A racer who disconnects during the race is DNF (`disconnected`). | MVP | Agreed |
| FIN-4 | Unregistering or deleting the vehicle during the race is DNF (`retired`). | MVP | Proposed |
| FIN-5 | The race ends when every racer is finished or DNF. An in-game results panel (position, name, total time, best lap, DNF reason) is shown to racers and stays until they close it or a new race starts. This is in addition to the server file (LOG). | MVP | Agreed |
| FIN-7 | Non-racers are not restricted during a race: they can drive on the track and collide with racers. | MVP | Agreed |
| FIN-6 | After the race ends, pathnodes are removed and racers drive freely. | MVP | Proposed |

### 4.7 Results log (LOG)

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| LOG-1 | When a race ends, the server sends its results as **one JSON chat message** to everyone and prints it to the server console. **No files are written on the server** (many owners never open their server files). | MVP | Agreed |
| LOG-2 | Results are sent once, when the race ends (everyone finished or DNF). Nothing is sent to chat while the race runs. | MVP | Agreed |
| LOG-3 | Optional results file on the server, off by default, for owners who want one. | Later | Proposed |
| LOG-4 | Content follows the schema in [§6](#6-results-schema). | MVP | Agreed |

## 5. Non-functional requirements

| ID | Requirement | Status |
|----|-------------|--------|
| NFR-1 | **The server is the authority** on race state, registration, positions, finish and DNF. Clients report what they see (pathnode crossings) and display what the server sends. | Proposed |
| NFR-2 | Works on BeamMP-Server 3.1.0+ (Lua 5.3) and current BeamNG.drive + BeamMP client. | Proposed |
| NFR-3 | All race messages carry a `raceId`, so multiple races (REG-11) and stale messages are handled correctly. | Proposed |
| NFR-4 | Code follows `CLAUDE.md`: descriptive names, small functions, one file per responsibility. | Agreed |
| NFR-5 | Calls to BeamNG internal Lua (race path, markers, countdown, UI apps) go through a thin adapter, so a game update breaks only one file. | Proposed |
| NFR-6 | Race rules (ordering, positions, gaps, DNF) are plain Lua with no game or server calls, so they can be unit-tested outside the game. | Proposed |
| NFR-7 | Network use stays small: summaries, not full histories; continuous-position updates (UI-3) at most 4 per second per racer. | Proposed |

## 6. Results schema

v1. Sent as compact JSON in one chat message (LOG-1) and as the `raceResults` message for the in-game panel. Times are integer milliseconds plus a readable copy.

```json
{
  "schemaVersion": 1,
  "raceId": "r-7",
  "status": "running",
  "raceType": "landrush",
  "map": "vracer_bajasur",
  "raceTrack": {
    "missionId": "vracer_bajasur/timeTrial/001-Circuito",
    "name": "Circuito Bronco Short Course",
    "closed": true,
    "pathnodeCount": 19
  },
  "laps": 3,
  "settings": {
    "dnfTimeoutSeconds": 120,
    "gridOrder": "registration",
    "allowRecover": true
  },
  "owner": { "name": "Sarah", "id": 3 },
  "createdAt": "2026-11-05T20:12:41Z",
  "startedAt": "2026-11-05T20:14:03Z",
  "finishedAt": null,
  "racers": [
    {
      "name": "Sarah",
      "id": 3,
      "beammpId": "123456",
      "vehicle": { "model": "etk800", "config": "856_m" },
      "gridSlot": 1,
      "status": "finished",
      "dnfReason": null,
      "position": 1,
      "raceStats": {
        "totalTime": 251334,
        "totalTimeReadable": "04:11.334",
        "lapTimes": [84120, 83105, 84109],
        "lapTimesReadable": ["01:24.120", "01:23.105", "01:24.109"],
        "bestLap": 1,
        "bestLapTime": 83105,
        "gapToWinner": 0,
        "recoveries": 0
      }
    }
  ]
}
```

Field notes:
- `status`: `registering` | `starting` (grid + countdown) | `running` | `finished` | `aborted`.
- racer `status`: `registered` (before GO) | `racing` | `finished` | `dnf`; `dnfReason`: `timeout` | `disconnected` | `retired` | `notOnGrid` | `null`.
- Keys are written in alphabetical order.
- `id` is the BeamMP player ID, which is only valid for this session and can be reused after a reconnect. `beammpId` (from `MP.GetPlayerIdentifiers`) identifies the account permanently; it is `null` for guests.
- `bestLap` is the **0-based index** into `lapTimes` (in the example, `1` → `83105`, the second lap). Lua arrays are 1-based, so the server subtracts 1 when writing the file; `bestLapTime` is included so readers don't need the index.

## 7. Future (not in the first version)

- **Staggered starts:** groups of *x* cars start every *y* seconds; best time wins.
  The model already allows it: each racer has their own start time, and positions
  can be ordered by time instead of distance.
- BeamMP-only track configuration and tracks (TRK-8).
- Freezing cars on the grid (START-3).
- Rolling starts (`rollingStartPosition` in race files).
- Reverse direction (`reversible`, `reverseStartPosition`).
- Spectator view of a running race for non-racers.
- Collisions on/off between racers.
- Server-wide leaderboard built from the results.

## 8. Open questions

### Still open

None.

### Resolved

| ID | Question | Resolution |
|----|----------|------------|
| Q-1 | When does a racer's total time start? | Landrush: at GO for everyone (TIME-2). |
| Q-2 | Gap to the car behind isn't known when you pass a pathnode. | Red gap immediately; green gap when the car behind passes the same pathnode (UI-8, UI-9). |
| Q-3 | Where do grid slots come from? | `Start Position*` entries, generated slots as fallback (TRK-6). Tracks should provide enough slots. |
| Q-5 | `bestLap` as index or lap number? | 0-based index into `lapTimes` (§6). |
| Q-6 | How are tracks shipped? | Under `gameplay/missions/` like single-player (TRK-5). BeamMP-only config/tracks later (TRK-8). |
| Q-4 | Grid order? | Registration order for the MVP (START-2). |
| Q-7 | Resets during a race? | Allowed and counted for the MVP (TIME-7); penalty setting later (TIME-6). |
| Q-8 | Non-racers on track during a race? | No special handling for the MVP (FIN-7); collisions/ghosting option later. |
| Q-9 | Results in game or only in the file? | Both: in-game results panel (FIN-5) plus the server file. |

## 9. Feasibility notes

All parts are feasible with BeamMP + BeamNG Lua. Risks, highest first:

| Area | Approach | Risk | To verify |
|------|----------|------|-----------|
| Freeze on grid while allowing revs (Later, not blocking the MVP) | Vehicle-side Lua: BeamNG's scenario-style freeze, or our own (neutral + parking brake with throttle unlocked). Runs on each client for its own car. | Medium | Which BeamNG call freezes the car but lets the engine rev (scenarios do this during countdown). |
| Reusing BeamNG race code | Load `race.race.json` with BeamNG's race path classes, or parse the JSON ourselves (it's simple: pathnodes + segments). | Medium — internal API, changes between game versions. | Whether the race path loader and the pathnode markers (two pillars) can be used outside a mission. Fallback: parse ourselves and draw markers with debug draw or a small prefab. |
| Countdown / finish screens | Our own overlay is acceptable for the countdown (with size/transparency animation); reuse BeamNG's finish UI if easy. | Low | Whether an imgui overlay can animate smoothly enough, or a CEF (HTML) UI app is needed. |
| Teleport to grid in multiplayer | Each client moves its own car (`setPositionRotation` / safe teleport); BeamMP syncs the result. | Low | Brief "ghost" of the old position on other screens. |
| Continuous positions (UI-3) | Either clients report progress (lap, node, fraction) ~4 Hz, or the server reads vehicle positions. | Low | Whether `MP.GetPositionRaw` is available and current enough on the server. |
| Pathnode crossing detection | Client checks own car vs. next pathnode (radius + plane crossing using `normal`). | Low | — |
| Publishing results | `MP.SendChatMessage` to everyone. | Low | Very long messages (many racers) may be cut by the chat UI. |
| Multiple simultaneous races | Server keeps a table of races keyed by `raceId`; a player belongs to at most one. | Low | — |

## 10. Decision log

| Date | Decision |
|------|----------|
| 2026-11-05 | Scope changed: instead of fixing the trigger/prefab-based RaceMP, build a new system on BeamNG Race Editor files (`race.race.json`). The trigger-based protocol draft (`docs/protocol.md`) is superseded and will be rewritten from these requirements. |
| 2026-11-05 | First race type: landrush. Staggered starts planned for later. |
| 2026-11-05 | Q-1: landrush clocks start at GO. Q-2: red gap immediately, green gap when the car behind passes. Q-3: grid from `Start Position*` entries, generated fallback. Q-5: `bestLap` is a 0-based index. Q-6: tracks shipped under `gameplay/missions/`; BeamMP-only config later. |
| 2026-11-05 | Q-4: grid in registration order. Q-7: resets allowed and counted. Q-8: non-racers unrestricted. Q-9: in-game results panel plus server file. |
| 2026-11-05 | Grid freeze (START-3) moved to Later; the MVP can be tested without it. Countdown stays MVP but can be our own overlay, ideally animated (size and transparency). Reusing BeamNG's race code and markers is preferred but not required. |
| 2026-11-08 | TIME-2 corrected: lap 1 runs from GO around the whole track to the start pathnode (BeamNG race-file behaviour, architecture A-2). |
| 2026-11-08 | Results folder is `Resources/Server/VRacerMP/results/`. Schema: race status `starting`, racer status `registered`, DNF reason `notOnGrid` (START-8). BeamNG's race engine does not report invisible pathnodes, so they are not counted in "pathnodes passed" (VIS-3 partly). |
| 2026-11-08 | LOG changed: results go to the server chat as one JSON message when the race ends, and to the console. The server writes no files. A results file may come back later as an off-by-default option (LOG-3). |
| 2026-11-08 | TRK-5: BajaSur tracks come from the map mod; VRacerMP.zip ships no tracks for now. |
| 2026-11-08 | UI: BeamNG-native look; apps on by default and movable by players; one compact race panel. |
