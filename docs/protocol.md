# VRacerMP — Network protocol (v1)

Living document. Event names live in [`shared/protocol.lua`](../shared/protocol.lua);
payloads are built in `Resources/Server/VRacerMP/vracerMP/coordinator/messageBuilder.lua`
(server → client) and `Resources/Client/lua/ge/extensions/vracerMP/controller/clientController.lua`
(client → server). Keep the three in sync.

## Conventions

- Every event name starts with `vracerMP_`.
- Every payload is a JSON object. Client → server uses BeamNG's `jsonEncode`;
  server → client uses the shared `jsonEncoder` (empty lists are `[]`).
- Every race message carries `raceId` (NFR-3). The server ignores messages whose
  `raceId` is not the sender's current race.
- Times are integer milliseconds of race time; 0 = GO.
- Player IDs are BeamMP player IDs. Fake racers (testing) have negative IDs and never
  receive messages.

## Flow

```mermaid
sequenceDiagram
  participant C as Client (each racer)
  participant S as Server
  C->>S: requestLobbies (level loaded)
  S-->>C: lobbyUpdated (one per race)
  C->>S: register (in a start area)
  S-->>C: lobbyUpdated (broadcast)
  C->>S: configure (owner)
  C->>S: startRace (owner)
  S-->>C: raceStarting (your grid slot)
  C->>S: gridReady (car placed)
  S-->>C: countdown (all on grid, or 10 s timeout)
  S-->>C: go (after 3 s)
  loop every pathnode
    C->>S: pathnodeReached
    S-->>C: gap (ahead to you, behind to the car ahead)
    S-->>C: standings
  end
  S-->>C: racerFinished (finish or DNF)
  S-->>C: raceResults (everyone done)
  S-->>C: raceRemoved (broadcast)
```

## Client → server

| Event | Payload | Notes |
|-------|---------|-------|
| `vracerMP_requestLobbies` | `{ tracks: [{ missionId, level, name, closed, pathnodeCount, defaultLaps }] }` | Sent when the level is loaded, and again every 2 s until the server answers with `welcome` (a message sent while still joining can be lost). `tracks` are the map's race tracks, kept in memory so races can be created by command (B-4; at most 500 are read). Server answers with one `lobbyUpdated` per race and one `lapRecord` per track that has a record. |
| `vracerMP_register` | `{ track: { missionId, level, name, closed, pathnodeCount, defaultLaps }, vehicle: { model } }` | Creates the track's race if none is open; first registrant is owner. `pathnodeCount` = crossings per lap. |
| `vracerMP_unregister` | `{ raceId }` | Before the start: leave. After (from the grid on): DNF `retired`; also sent by the race panel's Retire button. |
| `vracerMP_configure` | `{ raceId, laps?, dnfTimeoutSeconds? }` | Owner only, before the start. Laps 1–99 (always 1 on point-to-point tracks); timeout 0 (no limit) or 10–3600 s. |
| `vracerMP_startRace` | `{ raceId }` | Owner only. |
| `vracerMP_gridReady` | `{ raceId, vehicle: { model } }` | Car is on its grid slot. `vehicle` is the car the player races with (players registered by command had sent none). |
| `vracerMP_pathnodeReached` | `{ raceId, crossingNumber, raceTimeMs, lapCompleted }` | `crossingNumber` counts from 1 across laps; the server ignores anything but the next number. `raceTimeMs` comes from BeamNG's race engine (sub-frame precise). |

## Server → client

| Event | To | Payload |
|-------|----|---------|
| `vracerMP_welcome` | one player | `{ protocolVersion }` — answer to `requestLobbies`; the client stops asking. |
| `vracerMP_lobbyUpdated` | everyone | `{ raceId, missionId, trackName, closed, state, ownerId, ownerName, serverOwned, laps, dnfTimeoutSeconds, racers: [{ id, name, status }] }`. `serverOwned` is true for races created from the console or a plugin (B-4): `ownerId` is then -1 and `ownerName` "Server". Also sent when racers finish or retire, so clients know who is free to register again. |
| `vracerMP_raceRemoved` | everyone | `{ raceId, missionId }`. After `raceResults` when a race ends; alone when it was cancelled (everyone left before GO). |
| `vracerMP_raceStarting` | each racer | `{ raceId, missionId, laps, gridSlot, racerCount }` |
| `vracerMP_countdown` | racers | `{ raceId, goInMs }` (3000) |
| `vracerMP_go` | racers | `{ raceId }` |
| `vracerMP_gap` | one racer | `{ raceId, kind: "ahead" \| "behind", gapMs }` — `ahead`: red gap to the car in front (UI-8); `behind`: green gap to the car behind (UI-9). |
| `vracerMP_standings` | racers | `{ raceId, racerCount, entries: [{ id, name, position, lapsCompleted, crossings, penaltyTime, status }] }` in race order (live order uses raw times). |
| `vracerMP_racerFinished` | one racer | `{ raceId, status: "finished" \| "dnf", dnfReason, position, racerCount, totalTimeMs, bestLapTimeMs }` (`-1` = none, `""` = no reason) |
| `vracerMP_raceResults` | racers | The full results object, same shape as the results JSON ([requirements §6](requirements.md#6-results-schema)). |
| `vracerMP_notice` | one player | `{ message }` — why a request was refused (not owner, already registered, ...). |
| `vracerMP_penalty` | one racer | `{ raceId, reason, penaltyMs, totalPenaltyMs }` — the racer got a time penalty; the race panel shows the total. No penalty type sends it yet (planned: speed zones, vehicle repairs). |
| `vracerMP_lapRecord` | everyone / joining player | `{ missionId, trackName, lapTimeMs, name, model }` — a track's server lap record (B-8): broadcast when broken, and sent to a player who loads the level. A new record is also announced in chat. |

`state` values: `registering`, `gridding`, `countdown`, `running`, `finished`, `aborted`
(`shared/raceStates.lua`).

## Timing and trust

- GO is decided by the server; each client runs its countdown locally for `goInMs`
  and starts its race clock when `go` arrives (START-5).
- The server compares each reported `raceTimeMs` with its own time since GO. Outside
  −2 s / +1 s it logs a warning (TIME-5). MVP: warning only, the crossing is kept.
- Resets are counted from BeamMP's `onVehicleReset` while racing (TIME-7).

## Results in chat

When a race ends the server sends `Race:serialize()` as compact JSON in one chat message
to everyone (`MP.SendChatMessage(-1, json)`) and prints it to the server console (LOG-1).

## Commands and plugin events

Commands for the server console (`vracer ...`), chat (`/vracer ...`) and other server plugins,
and the events plugins can listen to, are in [commands.md](commands.md) (B-4).
