# Playtest handoff — the 3A/3B checkpoint toward Playable 0.3

**Archipepsi Production lane · 2026-09-11**

| | |
| --- | --- |
| **Game revision to play** | **`96c450e8ba91ec012fb1e2ce44d269a67a14bf53`** — *The shell is the room, and a player rides one* |
| Audit | `docs/audit/2026-09-10-3ab-integration-audit.md` at `a83a8a5b801305211737d74c3263ffb5a50bf477` |
| Production report | `docs/reports/2026-09-11-3ab-integration.md` |
| Frozen authority | `docs/ROAD_TO_PLAYABLE_0_3.md` |

Game code and assets are **unchanged from `96c450e`**. This document and
the corrections in it are documentation only and were committed
separately (the launcher files added later touch no game code); if this file is at a later commit than the one above, the
code you are playing is still `96c450e`.

**This is a checkpoint, not a finish line.** It is the 3A/3B slice: an
authored room, composed by ordinary generation, that a player can walk
into and whose movement offer changes the route. Full-run completion, your
own judgment of how it plays, and the rest of the Road's criteria
(A3, A5–A8) each still need their own evidence. Vera's audit was a
checkpoint audit and says the same.

**Vera's verdict: nothing found blocks trying it.**

---

## 1. What you are running

There is **no exported build** — the repository has no Godot export
preset, and the existing workflow runs the project from source, which is
what the two launcher scripts already do. So:

* **Runnable project:** `godot/` in this checkout (`project.godot` at
  `godot/project.godot`).
* **Bridge:** `bridge/`, run as a Python module.

### Prerequisites

| | |
| --- | --- |
| Godot | **4.5.1 stable** (`4.5.1.stable.official.f62fdbde1`) — the version this revision is built and tested against |
| Python | 3.11+ with `pydantic` and `websockets` (`pip install pydantic websockets`) — the launcher scripts install these for you |
| Archipelago | **not needed.** This runs on the mock backend and the offline provider; no server, no API key |

## 2. The Zone you will be in

All three modes must use **one stored Zone**, and the way that is
guaranteed is a **shared `--save-dir`**: the bridge generates Zone 1 once,
stores it, and every later launch against the same save directory reads it
back rather than generating again.

Verified, three launches against one save directory:

```
launch 1 (asks for a Zone): generations = 1
launch 2 (same save dir):   generations = 0
launch 3 (same save dir):   generations = 0
same stored Zone all three: True
zone_id: zone_001 | chambers: 23
authored shells: ['shell_span_basin', 'shell_corner_left', 'shell_corner_right',
                  'shell_corner_left', 'shell_corner_right',
                  'shell_corner_left', 'shell_corner_right']
```

That is the audited composition: **`shell_span_basin` at `c006` plus six
alternating authored corners**, 7 of 23 chambers. It is the ordinary
offline-provider Zone — **not the `--playtest3a` showcase**, which is a
separate curated fixture and is not used anywhere below.

`bridge/archipepsi_bridge/playtest.py check` — the guard the Windows
launcher runs before it will start — passes at this revision and reports:

```
ZONE 1, which is the one you play:
  23 rooms, 15 Checks, 35 enemies, 908 points
  themed neon_transit for Bomb Rush Cyberfunk
  id a9e649315285bdf3
```

**`a9e649315285bdf3` is the Zone id to expect.** It comes from
`playtest check`, which is where I read it, and the Zone's id is carried
in the playtime record — so all three runs can be confirmed to be the
same level after the fact.

The authored-floor budget stays at **4000 m²** as audited. Nothing about
it changed for this handoff.

## 3. The easy way, on Windows

Three double-click files at the repo root:

```
Play 3AB - none (Windows).bat
Play 3AB - rail (Windows).bat
Play 3AB - launch (Windows).bat
```

Each one finds Python and Godot (asking once and remembering the answer
in `godot-path.txt`), starts the bridge **if it is not already running**,
and launches the game with its movement package. Switching modes means
closing the **game** window and double-clicking the next file — leave the
bridge window open, and the Zone stays the one you were just in.

They share `playtest-3ab\` as their save directory, which is what makes
all three the same stored Zone. They prefer Godot's `_console.exe` build
where it exists, because the ordinary Windows build is a GUI app whose
`print` output goes nowhere — and the `p3a:` census lines come from the
game.

All three are one line each; the logic lives once in `_play-3ab.bat`,
which is not for double-clicking.

**Caveat, stated plainly:** these were written and reviewed on Linux and
**I could not execute a Windows batch file to test them**. The first real
run found one: stripping the quotes drag-and-drop adds to a path was done
inside a parenthesised `if` block, where a `"` changes how cmd parses the
rest of the block, so the quotes survived into `godot-path.txt` and cmd
tried to run a command whose name was a quoted string. Everything that
touches a path is at the top level now, and delayed expansion is gone. What is
verified is everything they call — the bridge command, `playtest check`,
the port they wait on (`127.0.0.1:38290`, confirmed by starting the real
bridge), and the Godot argument form. If one misbehaves, §4 below is the
same thing by hand.

## 4. Exact commands, by hand

Two windows: the bridge in one, the game in the other. **Start the bridge
first.**

### Window 1 — the bridge (same for all three modes)

macOS / Linux:

```sh
cd <repo>/bridge
python3 -m archipepsi_bridge --ap=mock --epsilon=fallback \
    --mock-scale=default --save-dir ../playtest-3ab
```

Windows: double-click **`Playtest 2.5 (Windows).bat`**. It runs the
baseline check and then starts exactly this bridge, with
`--save-dir playtest-2.5`. Use it for all three runs and the save
directory stays the same, which is what matters.

`--mock-scale=default` is load-bearing: without it MOCK CAMPAIGN starts
the prototype's thirty-location campaign, and Zone 1 of that is a
different level.

### Window 2 — the game, once per mode

macOS / Linux (from the repo root):

```sh
godot --path godot -- --movement-package=none
godot --path godot -- --movement-package=rail
godot --path godot -- --movement-package=launch
```

(In the development container the binary is `godot-bin/godot`; on your
machine use whatever `godot` 4.5.1 is called there.)

Windows (from the repo root, adjust the Godot path):

```bat
"C:\path\to\Godot_v4.5.1-stable_win64.exe" --path godot -- --movement-package=rail
```

The `--` is required: everything after it goes to the game rather than to
Godot. **Run the game from a terminal rather than pressing Play in the
editor** — the editor's Play button passes no arguments, so the mode would
silently be `none`.

Verified on the real binary at this revision: `--movement-package=rial`
prints `p3a: REFUSED -- movement package 'rial' does not exist; the
selections are none, rail, launch` and applies nothing; a valid value is
accepted silently.

### In the game, each time

1. Press **MOCK CAMPAIGN**.
2. Take the portal into **Zone 1**.
3. **Do not take the exit portal** until you have finished comparing
   modes. Finishing Zone 1 advances the campaign to Zone 2, and Zone 2 is
   a different level. To switch modes: close the game, leave the bridge
   running (or restart it with the same `--save-dir`), and launch again.

### What the GAME's terminal should print

These lines come from the game, not the bridge — which is the other
reason to launch it from a terminal rather than from the editor. Once you
are in the Zone, per mode:

```
p3a: zone zone_001 mode=none   declared=6 judged=5 accepted=5 selected=0 built=0
p3a: zone zone_001 mode=rail   declared=6 judged=5 accepted=5 selected=1 built=1
p3a: zone zone_001 mode=launch declared=6 judged=5 accepted=5 selected=1 built=1
```

`built=1` in `rail` and `launch`, `built=0` in `none`, and the same
`zone_001` in all three, is the checkpoint working.

## 5. Controls

Read from `godot/project.godot` at this revision.

| Action | Bound to |
| --- | --- |
| Move | **W A S D**, or the arrow keys |
| Jump | **Space** |
| Interact — claim a Check, use a portal | **E** |
| Fire | **Left mouse button** |
| Echo inventory | **Tab** |
| Pause / menu | **Escape** |

Movement law you can feel: walk **7.0 m/s**, jump **8.0 m/s** against
**24.0** gravity, a **1.0 m** step-up, player height **1.8 m**.

## 6. What to try

Roughly in order; the first three are the checkpoint itself.

- [ ] **Find the big two-level room** (`c006`, `shell_span_basin`) — a
      31 × 90 m basin with a raised deck. You arrive on the **deck**, and
      the arrival is level: the connector meets the deck at the same
      height, so there is no drop at the doorway. Does the join read as a
      room you walked into, or as a seam?
- [ ] **Walk it in `none` first.** The basin floor runs unbroken beneath
      the whole span. Walk the length of it. How long does it take, and
      does the room feel like it is worth its size?
- [ ] **Then `rail`.** The rail is in that room. Walk into it moving along
      it to catch it, and ride. It follows an **83.04 m curve**; you end
      about **34.3 m from where you started in a straight line**, higher
      than the floor. Compare it with the walk you just did — that
      difference is the thing being checked.
- [ ] **Then `launch`.** The same room's authored launch pad. Where does
      it put you, and is that somewhere you wanted to go?
- [ ] **The six corners.** Six corridors are authored corner shells,
      alternating left and right. Do the turns read as deliberate, or as
      the level wandering?
- [ ] **Claim a Check or two** (E). Fifteen are allocated across the Zone.
- [ ] **Anything that looks wrong.** A wall you can walk through, a prop
      inside another prop, a room you cannot leave, an enemy in the floor.
      Note the room id if the HUD shows one.
- [ ] Only when you are done: **take the exit portal** if you want the
      playtime record written, knowing it advances to Zone 2.

## 7. Vera's findings, recorded

Three claims in the Production report were stronger than the evidence
behind them. **The facts hold; the wording did not.** Corrected here.

**C-1 · The walk-in test proves crossing, not landing.** The test breaks
the frame the player's position enters the room's bounds and then accepts
ground up to 4 m below; it never waits for `is_on_floor()`. As written it
would pass with the body mid-fall. The arrival *is* level — Vera measured
ground at the same height on both sides of the seam — so the fact is
true and the test is weaker than the claim.

**C-2 · 34.3 m is displacement, not distance ridden.** The number is
`start.distance_to(rode)`, a straight line between two points. The
authored path itself is **approximately 83.04 m** (the baked
Catmull-Rom through its five control points). Both numbers are real; the
report used one and described the other.

**C-3 · The rail does not make the destination otherwise unreachable.**
The report said "walking was never going to substitute." It was: the
basin floor runs unbroken for the full 80.8 m under the ride — 0 samples
without ground, 0 steps over the 1.0 m limit. What the ground probe shows
is that you cannot walk **at the rail's height**, not that you cannot
reach where it takes you. **A4 asks that the route differ, and it does** —
83 m of curve above a floor, versus the floor, at different speed and
elevation. A4 is satisfied on those grounds and does not need the
stronger claim.

Also recorded, from the same audit:

**C-4 · The Python count does not reproduce in a clean environment.**
`make test` reports **1144 passed** here and **1098 passed, 6 skipped, 0
failed** in a checkout where `make setup` has not run — modules that skip
at import. Nothing fails either way; the difference is environment, not
result.

## 8. Follow-ups — logged, not done here

None of these is done in this task, and none blocks playing.

**F-1 · The Yard join lets a corridor intersect solid wall.**
`shell_yard_gantry` declares its entry socket 26 m inside its own
envelope, so a room placed by that socket extends 26 m **behind** its
join plane. The planner and the overlap test both exempt exactly the pair
a join lands in — correctly, since rooms meet at a shared face — but that
exemption has **no depth bound**, so it cannot tell a face contact from a
wall standing in the approach corridor. Measured at a real join: 8.0 m²
of shared footprint, and **30 sampled capsule positions in the corridor's
walking lane blocked by `yd_west_0`**, the yard's own west wall. The
doorway stays passable; what is wrong is the corridor behind you.

*Not reachable in this checkpoint:* the Yard's 4430.4 m² footprint
exceeds the whole 4000 m² budget, so the offline provider can never adopt
it. **That is a side effect, not a placement guarantee.** Two things
follow and both belong in the record: the budget is read in exactly one
place — the offline generator — so **a live provider is not bound by it**,
only described to it; and any future budget above ~4430 m² makes the Yard
adoptable, at which point a pacing decision silently becomes a placement
decision.

*Smallest fix, when it is taken up:* bound the exemption — cap the
tolerated join overlap at the exempt piece's own depth, or refuse at load
a shell whose entry inset is non-zero unless it declares one. Either makes
this fail loudly instead of silently.

**F-2 · The walk-in test should wait for a landing.** Add an
`is_on_floor()` wait before asserting ground, so the test proves the half
of C-1 it currently assumes.

**F-3 · The rail's ground probe is not on the rail.** It samples
`start.lerp(rode, 0.5)`, which is **6.9 m off the actual ride**. The
intended fact is true and stronger than the current evidence — sampling
the real curve gives **41 of 41 samples with no ground within a step** —
so probing `rail.polyline()` makes the evidence match a claim that
already holds. While that is being touched: the comparison run gives the
walker up to 11 more frames than the rider and starts them falling rather
than walking. Both biases favour the walker, so the conclusion survives,
but neither should stay.

**F-4 · INT-3's stress result is narrower than it reads.** "120 copies,
465 pieces, zero clashes" is measured with the same one-deep exemption, so
it does not exclude a yard wall standing in its own approach connector.
Fixing F-1 is what makes INT-3 mean what it appears to mean.

## 9. Where the evidence lives

* Audit — `docs/audit/2026-09-10-3ab-integration-audit.md` @ `a83a8a5`
* Production report — `docs/reports/2026-09-11-3ab-integration.md`
* Stage 3B report — `docs/reports/2026-09-10-playtest3b-authored-composition.md`
* Frozen acceptance — `docs/ROAD_TO_PLAYABLE_0_3.md`
* Pre-3B baseline, kept verbatim — `docs/baselines/playtest_2_5.pre_3b.json`
