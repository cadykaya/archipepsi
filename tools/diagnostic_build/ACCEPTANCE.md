# Diagnostic build — what to do with it, and what I could not test

Condi, 2026-10-08. Build `Archipepsi-Diagnostic-Campaign-<sha8>`.

**This is a private diagnostic build for your hands-on review. It is not a
release, not a release candidate, and nothing about how the game plays was
changed to make it.** No new rooms, no new features, no campaign schema
change.

## Installing it

Either way is fine:

- **The launcher.** Install the zip in the Archipepsi Launcher and press
  Play. (If you take the two-part delivery, select both part zips
  together, as with every review build.)
- **By hand.** Unpack the zip anywhere you can write to and double-click
  `START HERE - Mock Campaign (Windows).bat`. If you took the two parts,
  unpack both into the same folder first; the first start joins the game
  and removes the parts, which takes a few seconds.

Then press **MOCK CAMPAIGN** on the title screen. Nothing else to install:
no Godot, no Python, no checkout. Windows SmartScreen may warn, because the
build is not code-signed — "More info", then "Run anyway".

## The five things worth checking

1. **It starts at all, on your machine.** This is the one thing no test
   here can stand in for. Everything below only matters if this works.
2. **The campaign is the one you know.** Prototype scale, about ten Zones,
   thirty Checks, offline. It should feel like MOCK CAMPAIGN in a
   checkout, because it is the same code at the same scale.
3. **Your save survives.** Play a little, close the game, start it again:
   the campaign should come back. It lives in
   `%LOCALAPPDATA%\Archipepsi\Diagnostic Campaign\saves` — paste that into
   Explorer's address bar. Delete the build folder, install it again, and
   the save should still be there.
4. **Closing the game closes everything.** There is no second window to
   remember this time; the bridge starts and stops with the game. If a
   `python.exe` is still running in Task Manager after you quit, that is a
   bug and I want to know.
5. **It refuses to collide with a checkout.** If you have a checkout's
   "Start Archipepsi" window open, this build should refuse to start and
   say so, rather than quietly playing against that bridge's saves.

If something goes wrong, start
`With log window - Mock Campaign (Windows).bat` instead: the bridge and
the game print into one window. There are logs either way, in
`%LOCALAPPDATA%\Archipepsi\Diagnostic Campaign\logs`.

## What is deliberately not in it

- **The real Archipelago connection.** The bundled bridge runs in mock
  mode only. A server address typed into the game reaches the offline
  fixture campaign, not a server. Real Archipelago play still needs the
  developer setup (an Archipelago source checkout), and it is untested in
  this form. Bundling it is a bigger job and I have not started it.
- The candidate generation profile (minors, carry, lever routes, Bomb
  Bags), which is still opt-in and off.
- Every review room: Crossing D, Impact Lab, Impact Relay, the Railway,
  3A/3B. This is the plain campaign.
- Music. There still is none.

## What I tested, and what that is worth

Run by `tools/diagnostic_build/test.sh`, which anyone can re-run:

| | |
|---|---|
| The whole campaign, headlessly, through this build's own game and bridge | reached `ALL_CHECKS_CLEARED` and `GODOT INTEGRATION OK`, 349 assertions, no script errors |
| The build folder after that run | byte-identical; the save and the logs were in the per-user folder |
| A second instance while a bridge is listening | refused, with the reason on screen |
| `SHA256SUMS.txt` | covers every file, all match |
| `archipepsi-build.json` | consistent with the folder; the launcher imports and verifies the package and offers its mode |
| Notices | Godot's MIT grant, CPython's licence, each bundled wheel, the MinGW-w64 runtime |
| Two builds of the same commit | all three zips byte-identical |
| The two-part delivery | both zips under 30 MB, unpack into one folder that matches its checksums, and the starter joins the game on its first run |

**All of that ran under Wine 11 on Linux, not on Windows.** Wine is a
different runtime; it is good evidence that the build is wired up
correctly and no evidence at all about Windows. Your run is the first on
Windows.

Two more things I could not test here: anything about how it feels (that
is the point of handing it to you), and a machine that has never had
Python or Godot on it — this container has neither installed for the
build's own use, but it is not your PC.

## One thing I found and did not touch

`bridge/tests/test_bomb_fixture.py` fails on Python 3.13 with pydantic
2.14 (2266 of 2267 bridge tests pass). CI's pinned Python 3.11 passes it,
so this is a newer-interpreter difference in a committed fixture, not a
break. It is bridge code, so I left it alone and am telling you instead.
