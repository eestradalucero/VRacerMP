# VRacerMP — Commands

Races can be run from commands as well as from the in-game panels (backlog B-4). The same
commands work in three places:

| Where | How to type it | Who is asking |
|---|---|---|
| Server console | `vracer <command>` | The server: owns the races it creates and may manage every race. |
| Chat | `/vracer <command>` | The player who typed it. The reply goes only to them; the command is kept out of the chat. |
| Another server plugin | event `vracerMP_command` (see [Plugin interface](#plugin-interface)) | The server, like the console. |

`vracer help` (or `/vracer help`) lists the commands; `vracer help <command>` explains one.

**Testing:** on a local test server (installed with `tools/build.ps1 -ServerPath`) there is
also `fake [race] [lapSeconds]`, which adds a fake racer that laps at a steady pace (default
90 s), so you can test alone. Only the owner can add one. It is not in the release zip.

## Rules

- **Owner.** A race created from the console or a plugin is owned by the server: the lobby
  panel shows "Run by the server" and only the console or a plugin can change, start or cancel
  it. A race created in chat is owned by the player who typed it, who is registered in it too.
  A race created from the panel is owned by the first player who registered, as before.
- **Permissions in chat.** Like the panels: only the owner can `set`, `start`, `cancel`, add
  fake racers and add or remove other players. Anyone can add or remove themselves.
- **Players** are found by their in-game name, ignoring case. If two players share a name,
  both are registered; the reply lists who was. Players registered by command don't need to be
  at the start area: the start moves them to the grid. Their car is read when they reach it.
- **Tracks** are reported by each player's game when they join, and kept in memory. Until a
  player has joined, no tracks are known (nobody could race anyway). A track is found by its
  id (the mission folder, e.g. `001-Circuito`), its full mission id or its name, ignoring case;
  part of the name works when only one track matches.
- **Races** are named by their id (`r-1`). Leave it out when there is only one race; in chat it
  defaults to the race you own, then the race you are in.
- **Empty server races stay open** until they are started or cancelled; races created in chat
  or from the panel are removed when their last player leaves before the start.
- Options start with `--`, ignore case, and take every word up to the next option, so names
  may contain spaces: `--track Circuito Bronco --players Ana, Bob`.
- **Everyone at once:** `--all` (on `create` and `add`) registers every player on the server
  who is not in a race yet: `vracer add --all`.

## Commands

<!-- commands:start (generated from commandList.lua: python tools/writeCommandsDoc.py) -->

| Command | What it does |
|---|---|
| `help [command]` | List the commands, or explain one. |
| `tracks` | List the race tracks of this map. |
| `races` | List the races: id, track, state, owner, settings, racers. |
| `create --track <id or name> [--laps N] [--dnf S] [--players a,b | --all]` | Create a race on a track. |
| `add [race] --players a,b | --all` | Register players in a race. |
| `remove [race] --players a | --all` | Unregister players (after the start they retire: DNF). |
| `set [race] [--laps N] [--dnf S]` | Change a race's settings before the start. |
| `start [race]` | Start a race: racers are moved to the grid. |
| `finish [race]` | End a running race now, with results. |
| `cancel [race]` | Cancel a race at any point; nobody gets results. |

### help

`help [command]`

List the commands, or explain one.

### tracks

`tracks`

List the race tracks of this map.

- Shows each track's id (its mission folder), name and layout. Players' games report the tracks when they join, so the list is empty until someone joins.

### races

`races`

List the races: id, track, state, owner, settings, racers.

### create

`create --track <id or name> [--laps N] [--dnf S] [--players a,b | --all]`

Create a race on a track.

- --track: the track's id or name (see tracks); part of the name works when only one track matches.
- --laps: 1-99 (always 1 on point-to-point tracks). Default: the track's laps.
- --dnf: seconds the others get after the first finisher, 10-3600, or 0 for no limit. Default: 120.
- --players: players to register, by in-game name, separated by commas.
- --all: register every player on the server who is not in a race yet.
- From the console or a plugin the server owns the race. In chat you own it and are registered too.

### add

`add [race] --players a,b | --all`

Register players in a race.

- Players are found by in-game name, ignoring case; two players with the same name are both added.
- --all registers every player on the server who is not in a race yet; those racing elsewhere are listed.
- They do not need to be at the start area: the start moves them to the grid.
- In chat, leave out --players to add yourself. Only the owner can add others.
- [race] is a race id like r-1. Leave it out when there is only one race; in chat it defaults to the race you own or are in.

### remove

`remove [race] --players a | --all`

Unregister players (after the start they retire: DNF).

- In chat, leave out --players to remove yourself. Only the owner can remove others.
- --all removes every racer still in the race; from the grid on they retire, and the race ends as when everyone retires (before GO it is cancelled). Only the owner can use it.
- [race] is a race id like r-1. Leave it out when there is only one race; in chat it defaults to the race you own or are in.

### set

`set [race] [--laps N] [--dnf S]`

Change a race's settings before the start.

- Same values as create; --dnf 0 means no limit. Only the owner can change settings.
- [race] is a race id like r-1. Leave it out when there is only one race; in chat it defaults to the race you own or are in.

### start

`start [race]`

Start a race: racers are moved to the grid.

- Only the owner can start a race.
- [race] is a race id like r-1. Leave it out when there is only one race; in chat it defaults to the race you own or are in.

### finish

`finish [race]`

End a running race now, with results.

- Racers who finished keep their result; everyone still racing is DNF (stopped).
- Only while the race is running; before GO use cancel. Only the owner can finish a race.
- [race] is a race id like r-1. Leave it out when there is only one race; in chat it defaults to the race you own or are in.

### cancel

`cancel [race]`

Cancel a race at any point; nobody gets results.

- Only the owner can cancel a race.
- [race] is a race id like r-1. Leave it out when there is only one race; in chat it defaults to the race you own or are in.

<!-- commands:end -->

## Plugin interface

Version 2. Other plugins on the same BeamMP server talk to VRacerMP with BeamMP events.
Arguments and payloads are strings; payloads are JSON.

### Sending a command

```lua
MP.TriggerGlobalEvent("vracerMP_command", "create --track 001-Circuito --players Ana, Bob", "tablet-42")
```

- Argument 1: the command, without `vracer`/`/vracer`.
- Argument 2 (optional): a request id of your choice, returned with the reply.
- The plugin acts as the server (see [Rules](#rules)).

### Asking for data (queries)

```lua
MP.TriggerGlobalEvent("vracerMP_query", "tracks", "web-17")
```

- Argument 1: the query: `tracks` or `races`.
- Argument 2 (optional): a request id of your choice, returned with the reply.
- The reply is published as `vracerMP_queryReply` and is also the handler's return value:

```json
{ "version": 2, "requestId": "web-17", "ok": true, "query": "tracks", "data": [ ... ], "error": null }
```

- `data` is always a JSON array, also when empty (`[]`).
- An unknown query: `ok: false`, `data: []`, `error: "Unknown query: <name>"`.

| Query | `data` |
|---|---|
| `tracks` | Every known track, sorted by name (like the `tracks` command): `{ id, missionId, name, level, closed, defaultLaps, pathnodeCount }`. `id` is the mission folder (`001-Circuito`), the value `create --track` takes. |
| `races` | Every race, ordered by race id, each exactly the lobby payload of `vracerMP_raceUpdated`: `{ raceId, missionId, trackName, closed, state, ownerId, ownerName, serverOwned, laps, dnfTimeoutSeconds, racers }`. |

### Replies and race events

| Event | Payload (JSON) | When |
|---|---|---|
| `vracerMP_commandReply` | `{ version, requestId, ok, lines: [text] }` | After every plugin command. `requestId` is `null` when none was sent; `ok` is false when the command failed. The same JSON is also the return value of the `vracerMP_command` handler. |
| `vracerMP_queryReply` | `{ version, requestId, ok, query, data: [...], error }` | After every query (see above). |
| `vracerMP_tracksUpdated` | `{ version, tracks: [...] }`, the tracks as in the `tracks` query | A player's game reported tracks the server did not know yet (not on every join with the same tracks). |
| `vracerMP_raceUpdated` | The lobby payload (`vracerMP_lobbyUpdated` in [protocol](protocol.md)) | A race was created or changed: racers, settings, state. |
| `vracerMP_raceRemoved` | `{ raceId, missionId }` | A race ended or was cancelled. |
| `vracerMP_raceResults` | The results payload (`vracerMP_raceResults` in [protocol](protocol.md), [requirements §6](requirements.md)) | A race finished, also by `finish` or `remove --all`. Not sent for cancelled races. |

Listening:

```lua
function onVRacerRaceResults(resultsJson)
  local results = Util.JsonDecode(resultsJson)
  -- ...
end
MP.RegisterEvent("vracerMP_raceResults", "onVRacerRaceResults")
```

Changes to these events or payloads raise the version and are listed here.

| Version | Changes |
|---|---|
| 2 (2026-11-16, B-12) | `vracerMP_query` / `vracerMP_queryReply` (`tracks`, `races`) and `vracerMP_tracksUpdated`. `vracerMP_commandReply` reports `version: 2`. New commands `finish` and `remove --all`; new DNF reason `stopped`. |
| 1 (2026-11-16, B-4) | `vracerMP_command` / `vracerMP_commandReply`, `vracerMP_raceUpdated`, `vracerMP_raceRemoved`, `vracerMP_raceResults`. |
