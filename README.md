# VRacerMP
> Multiplayer races for [BeamMP](https://beammp.com/), on tracks made with BeamNG's Race Editor.

VRacerMP lets several players race each other on a BeamMP server. Tracks are ordinary
BeamNG **time-trial missions** (`gameplay/missions/<level>/timeTrial/<mission>/`), so any
track made in the Race Editor works without extra setup.

**Status: MVP.** Landrush races (everyone starts together), one race per track.
See [docs/requirements.md](docs/requirements.md) for what is planned.

## Features
- Registration panel at each track's start area; the first player to register is the
  owner and sets laps and the DNF timeout.
- Cars are placed on the track's grid slots; animated 3-2-1-GO countdown decided by the server.
- Time-Trial-style two-pillar markers: orange for the next pathnode, grey for the two after it.
- HUD: position, lap, race time, best lap, pathnodes passed, red gap to the car ahead,
  green gap to the car behind.
- DNF when the timeout after the winner runs out, on disconnect, or when leaving the race.
- Results panel in game, and the results as JSON in the server chat (no files on the server).
- BeamNG-native UI apps (race panel, lobby, countdown, results). They appear automatically the
  first time, like BeamMP's chat; move or remove them in BeamNG's UI layout editor, where they
  show sample content so they are easy to find.

## Install on a server
1. Build (see below) or download a release.
2. Copy `Resources/Server/VRacerMP/` into your server's `Resources/Server/`.
3. Copy `Resources/Client/VRacerMP.zip` into your server's `Resources/Client/`.

When a race ends, its results are posted in the server chat as one JSON message and printed
to the server console. The plugin writes no files.

## Racing
1. Start areas where you can register show BeamNG's mission marker. Drive into one: the
   registration panel opens.
2. Press **Register**. The owner can change laps and the DNF timeout, then press **Start race**.
3. Wait for the countdown, race, and see the results at the end.
4. To drop out, press **Retire** on the race panel and confirm. You are DNF and stay in the
   results, and you can register for another race straight away. If every racer drops out, the
   race ends (before GO it is simply cancelled) and the track is free again.

Testing alone? Register, then type `/vracer fake 60` in chat to add a fake opponent
that laps in about 60 s.

## Making a track
Make a time trial with BeamNG's Race Editor (World Editor → Race Editor), save it as a
mission and give it **start positions named "Start Position ..."** (one per car; missing
slots are generated behind the last one). Branching tracks are not supported yet.
Tracks normally ship inside the **map mod** (e.g. `Vracer_BajaSur.zip` already contains its
time trials), so updating the map on the server updates the tracks. Only a track that is in
no map needs to go into this mod, under
`Resources/Client/gameplay/missions/<level>/timeTrial/<mission>/`.

Players' own copies in `Documents/BeamNG/current/gameplay/missions/` override the server's,
so remove or update them after changing a track; every racer must use the same race file.

## Development
- **Docs:** [requirements](docs/requirements.md), [architecture](docs/architecture.md),
  [protocol](docs/protocol.md).
- **Build:** `powershell -ExecutionPolicy Bypass -File tools/build.ps1` writes
  `export/Resources`. Add `-ServerPath "<your BeamMP server folder>"` to install it there.
- **Tests:** `python -m pip install --user lupa`, then `python tools/runTests.py`
  (runs on Lua 5.3 like the server and LuaJIT like the game).
- **Server smoke test:** after building, `python tools/smokeTestServer.py`.

Code that both sides use lives in `shared/` and is copied into both packages by the build.

## Credits
VRacerMP calls BeamNG's own race engine and markers, which stay under BeamNG's licence and are
not included here.

## Thank you
Thanks to Funky7Monkey and AbhiMayadam for RaceMP, which got us racing on BeamMP and inspired
this project.
