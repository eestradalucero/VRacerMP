# VRacerMP — Backlog

What is pending, in progress and done. Living document: update it whenever we agree on,
start or finish something. Agreed details live here until the item is built; then they move
into [requirements](requirements.md) / [protocol](protocol.md) and the item is marked done.

**Status:** `Next` (agreed, in the work order) · `In progress` · `Testing` (built, waiting for an
in-game test) · `Done` · `Waiting` (needs input) · `Later` (idea, not scheduled).

---

## 1. Work order (agreed 2026-11-16)

Build one step at a time; stop after each step so it can be tested in game.

| # | Item | Status |
|---|------|--------|
| B-1 | Stop sending vehicle configs | Done (tested 2026-11-16) |
| B-5 | DNF time 0 = no limit | Done (tested 2026-11-16) |
| B-6 | Close results with a bindable control; auto-close after 30 s | Done (tested 2026-11-16) |
| B-7 | Results highlight the local player | Done (tested 2026-11-16) |
| B-8 | Server lap record | Done (tested 2026-11-16) |
| B-3 | Missed checkpoint: catch-up + penalties | Dropped (2026-11-16): penalty framework kept |
| B-4 | Commands (console, chat, plugins) + `docs/commands.md` | Done (tested 2026-11-16) |
| B-2 | Race information UI changes | Done (tested 2026-11-16) |
| B-9 | English and Spanish translations (BabelEdit) | Later (last, maybe a future session) |
| B-10 | Rankings: best time per player, per car and overall | Later (to discuss) |
| B-11 | Race-only prefabs, loaded on racing clients and removed at the end | Waiting (user learns the single-player setup first) |
| B-12 | VracerControl requests: plugin queries + `tracksUpdated` (v2), `remove --all`, `finish` | Done (tested 2026-11-23) |
| B-13 | Track picker at start areas shared by several tracks | Done (tested 2026-11-23) |

---

## 2. Agreed details

### B-1 Stop sending vehicle configs
A customized, unsaved vehicle's config is its whole serialized setup; sending it made every
race message huge and froze the game at race end (found at the Baja 1000 event, 2026-11-15).
- The client sends only the vehicle **model**. The server keeps only a model name (max 64
  characters) and ignores anything else, so older clients cannot cause it either.
- Results: `vehicle: { model }`.

### B-5 DNF time 0 = no limit
- The owner can set the DNF time to 0 ("No limit"): nobody is disqualified by time. The race
  ends when everyone finished, retired or disconnected.
- Allowed values: 0, or 10–3600 s. The lobby's −/+ buttons step 30 s and reach 0 below 30 s.

### B-6 Close results by control, auto-close
- A BeamNG input action "Close VRacerMP results" that players can bind (keyboard, wheel
  button…) in Options → Controls, in its own **VRacerMP** section. The on-screen Close button
  stays.
- The results close by themselves after 30 s; the panel shows the seconds left.

### B-7 Highlight the local player
- Your own row in the results is highlighted (instead of the winner's).

### B-8 Server lap record
- Fastest lap on each track since the server started (kept in memory; a restart resets it;
  no files).
- All laps count, penalty laps included. Fake racers (`/vracer fake`) never set records.
- Stored per track **and** vehicle model from the start, so a per-vehicle split later is
  only a display change. For now the record shown is the fastest of all vehicles.
- Shown in the lobby panel ("Server record: 1:24.120 — Name (etk800)"); a new record is
  announced in chat.

### B-3 Missed checkpoint: catch-up + penalties — dropped, framework kept
Built on 2026-11-16 and dropped after the in-game test: races finished at GO, every pathnode
counted as missed (on the first frame BeamNG's previous wheel positions are still at the map
origin). Decision: keep BeamNG's default checkpoint logic; no catch-up.

Kept as the base for future penalties (speed zones, vehicle repairs, …):
- Server: `RaceCoordinator:givePenalty(playerId, { reason, penaltyMs, details })`. A penalty
  counts for the lap it was given in and for the total time.
- Live positions and gaps stay raw; final results are ordered by total time.
- The racer gets a `penalty` message; the race info app shows "Penalty: +10\".000".
- Results screen: Time (raw), Penalties, Total columns.
- Results JSON: `raceStats` has `rawTime`, `penaltyTime`, `totalTime`, `lapPenalties` and a
  `penalties` list; each penalty has `raceTime`, `lap`, `reason`, `penalty` and reason-specific
  `details`.
- The `penaltyReason` enum (`shared/raceStates.lua`) is empty until the first penalty type.

### B-2 Race UI (agreed 2026-11-16, from two previews)
- The race panel becomes three apps, each movable in the layout editor:
  - **Race info**, top left, 5 px padding, left aligned: place (`2nd`), `Total time`,
    `Current lap`, `Best lap` (this race), `Server Record - <name>` (hidden when there is
    none). Penalty and finish/DNF rows appear only when they apply.
  - **Deltas**, centred a quarter down, no background: racer ahead in red (`+0".842`),
    racer behind in green (`-1".276`). Each fades in over 0.2 s when its gap arrives, stays
    3 s, fades out over 0.2 s, on its own.
  - **Laps and retire**, top right: `Laps: 2/3` and Retire. The confirmation ("Retire from
    the race? You'll be DNF." Yes, retire / Cancel) replaces that row in place.
- Time format: `mm'ss".fff`, with hours only past an hour (`1:04'12".880`). Used everywhere
  on screen and in chat; the results JSON keeps `mm:ss.mmm`.
- Results: the columns line up (header and rows share one grid); same time format.
- Pathnode count and racer count are no longer shown.

### B-4 Commands
- One command system, three entry points sharing one parser: the server console
  (`onConsoleInput`), chat (`/vracer …`), and other plugins (BeamMP events). A private tablet
  plugin for the sim rental business will use the plugin interface; it lives in a separate,
  private repo and depends only on the documented contract.
- `help [command]` lists commands / shows one; `help` and `docs/commands.md` come from the same
  command list, so they cannot drift apart.
- Commands (draft, agreed):

  | Command | What it does |
  |---|---|
  | `help [command]` | List commands or show one. |
  | `tracks` | Tracks on the current map (id, name, default laps). |
  | `races` | Races: id, track, state, owner, racers. |
  | `create --track <id or name> [--laps N] [--dnf S] [--players a,b,c]` | Create a race. |
  | `add [race] --players a,b` / `remove [race] --players a` | Register / unregister players. |
  | `set [race] [--laps N] [--dnf S]` | Change settings before the start (`--dnf 0` = no limit). |
  | `start [race]` | Start the race. |
  | `cancel [race]` | Cancel a race, no results. |
  | `fake [lapSeconds]` | Add a fake racer (testing). |

  `[race]` may be left out when there is one race, or in chat for the race you own. Options
  are case-insensitive (`--DNF` works); defaults are the track's laps and 120 s.
- **Owner:** the console/admin when created from the console or a plugin; the player who
  typed it when created from chat.
- **Permissions:** like the UI: only the owner (or the console) can `set`, `start`, `cancel`
  and `add` other players; any player can add or remove themselves.
- **Track list:** each client reports the tracks of the current map when it joins; the server
  keeps them in memory. (No tracks known until a player joins, which is fine: nobody can race
  before that.)
- **Players** are matched by their in-game name (case-insensitive). If two players share a
  name, both are registered; the reply lists who was registered.
- Players registered by command do not need to be at the start area; they are moved to the
  grid at start.
- **Plugin interface:** another plugin sends the event `vracerMP_command` with the command
  text and receives the reply in a reply event; VRacerMP also sends race updates and results
  as events plugins can listen to. Documented as a versioned contract.
- **Built (2026-11-16)**, documented in [commands.md](commands.md). Decided while building:
  - Races are named by id (`r-1`); `[race]` comes first, e.g. `fake r-1 60`.
  - A race created in chat is owned by its creator, who is registered too.
  - Races the server owns stay open while empty, until started or cancelled.
  - `cancel` works at any point (also during the race); nobody gets results.
  - `fake` is owner-only now (before: anyone registered), and only exists on a local test
    server: `tools/build.ps1 -ServerPath` turns it on in the installed copy
    (`serverOptions.testingCommands`); the release zip, `help` and the doc don't have it.
  - Tracks: id = mission folder (`001-Circuito`), full mission id or name; a unique part of
    the name also works.
  - Plugin events: `vracerMP_commandReply`, `vracerMP_raceUpdated`, `vracerMP_raceRemoved`,
    `vracerMP_raceResults` (JSON strings).

### B-9 Translations (last)
- English and Spanish; edited with BabelEdit (JSON files, one per language).
- BeamNG loads `locales/translations/<language>/*.translation.json` from mods.
- One `es` file covers every Spanish variant; a variant file (`es_ES`, `es_419`) is used only
  when both exist. Same rule for other languages.
- Only player-facing UI is translated. Commands, code and logs stay in English. Server notices
  are sent as a key + values so each player sees their own language.

### B-10 Rankings (idea, to discuss before building)
- Per track: the best times and who set them, so players can see where they stand.
- **One entry per player:** their best time only.
- Two views: **per car** (vehicle model) and **overall** (all cars mixed).
- Shown at registration (the lobby panel looks like the right place).
- Builds on B-8: lap times are already stored per track and per vehicle model.
- Open questions:
  - Best **lap** or best **race** time, or both?
  - How long it lasts: in memory since the server started (like B-8), or kept across restarts?
    Keeping it would need storage, and we agreed not to write files on the server.
  - How many entries to show in the lobby (top 10? your own place?).
  - Do penalty laps count (B-8: yes)?

### B-13 Track picker at shared start areas (agreed 2026-11-23)
Found at Hirochi Raceway: several time trials start at the same spot, and the closest one was
always used.
- The lobby shows ‹ › arrows beside the track name and "Track 2 of 4 here" when several
  tracks' start areas contain the car. Everything below (status, laps, record, Register) is for
  the track shown.
- It starts on a track whose race takes registrations (so players join the same race), else on
  the closest. The pick stays while the car is in the area; once registered, the lobby shows
  your race as before.
- Each track at the spot can have its own race. Commands already pick by name
  (`create --track forgotten`).
- Markers unchanged. Possible later: a dropdown instead of arrows for spots with many tracks.
- Track names come from the mission title, translated as BeamNG's map shows it (BeamNG's own
  race files are just called "Path"); the race file's name is the fallback. BajaSur titles
  change slightly (e.g. "Rancho Probaja Time Trial"); ids, records and commands are unaffected.
- The lobby shows the mission's preview picture (`preview.jpg/.png/.jpeg`) and translated
  description under the name, when the mission has them. Default lobby height 540 px.

### B-12 VracerControl requests (agreed 2026-11-16)
From `VracerControl/docs/raceMP-requests.md` (R-1 to R-3). VracerControl is a separate plugin
plus a web app for the venue; it only uses the documented plugin interface.
- **R-1 (plugin interface v2):** event `vracerMP_query` (`tracks`, `races`) answered with
  `vracerMP_queryReply` `{ version: 2, requestId, ok, query, data: [...], error }`; event
  `vracerMP_tracksUpdated` when a track report adds tracks. `vracerMP_commandReply` reports
  version 2.
- **R-2:** `remove [race] --all`: before GO everyone is unregistered (a server race stays open);
  from the grid on everyone not finished retires and FIN-9 ends the race. Owner only in chat.
  "Nobody to remove" when empty.
- **R-3:** `finish [race]`: only while running ("The race has not started; use cancel" before
  GO); finishers keep their result, the rest are DNF `stopped`; ends like a normal finish.
  Owner only in chat.
- Later (not requested yet): a `vracerMP_standingsUpdated` plugin event for a live leaderboard.

### B-11 Race-only prefabs (waiting)
- Like RaceMP: a track can have prefabs (cones, barriers, props…) used only for that race.
- They are loaded on the clients that are racing it, and removed when the race ends for them
  (finish, retire, DNF, cancel, disconnect).
- Waiting: the user first learns how to set them up for a track in single player, then asks
  for them to be added to multiplayer.

---

## 3. Later (ideas, not scheduled)

- Changes to how live gaps (deltas) are shown — user has ideas.
- Penalty types on the penalty framework: speed zones (`speedZoneViolation`), vehicle repairs
  (`vehicleRepair`), …
- Multiple races on the same track at the same time.
- Branching tracks.
- Server lap record split per vehicle (B-8 stores it already; likely part of B-10 Rankings).
- Grid freeze (START-3), jump-start penalty (START-7), continuous positions (UI-3), finish
  line marker (VIS-4), optional results file (LOG-3), BeamMP-only track config (TRK-8),
  reset/recover policy as a race setting (TIME-6).
- From [requirements §7](requirements.md#7-future-not-in-the-first-version): staggered starts,
  rolling starts, reverse direction, spectator view, collisions on/off between racers.

---

## 4. Done

| Date | Item |
|------|------|
| 2026-11-08 | MVP: registration, grid, countdown, timing, standings, gaps, DNF, results in chat. |
| 2026-11-08 | BeamNG-native UI apps (race panel, lobby, countdown, results). |
| 2026-11-08 | Published as its own project; hosted-server zip; no debug library. |
| 2026-11-09 | Start-area mission markers, Retire button, race ends when everyone drops out. |
| 2026-11-15 | Live use at the Baja 1000 event: about 300 races with 3 players. |
| 2026-11-16 | B-1 vehicle configs no longer sent; B-5 DNF 0 = no limit; B-7 own row highlighted in results. |
| 2026-11-16 | B-3 missed-checkpoint catch-up dropped; penalty framework kept for future penalty types. |
| 2026-11-16 | B-6 results close by a bindable control (own VRacerMP controls section) and after 30 s; B-8 server lap record. |
| 2026-11-16 | B-4 commands for the console, chat and plugins (`--all`, test-only `fake`); clients resend their tracks until the server welcomes them. |
| 2026-11-16 | B-2 race UI: race info, deltas and laps-and-retire apps; new time format; aligned results columns. |
| 2026-11-23 | B-12 plugin interface v2 (queries, `tracksUpdated`), `remove --all`, `finish` (DNF `stopped`). |
| 2026-11-23 | B-13 track picker at shared start areas; tracks named after their mission, with its picture and description. |
