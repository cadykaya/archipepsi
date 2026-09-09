# PROD — Playable 0.3, Stage 3A: the live movement consumer

**Archipepsi Production lane · 2026-09-09**

Head before: `df2bb58`. Frozen authority: `docs/ROAD_TO_PLAYABLE_0_3.md`.

A real player now rides an authored rail and is thrown by an authored launch
pad, in a Zone built by the real runtime out of the four approved Wave-1
rooms. **Stage 3B is not started.** The showcase names its `shell_id` values
by hand, which is scaffolding and not composition.

---

## 1. Files changed

| file | what |
| --- | --- |
| `godot/scripts/gameplay/movement_selection.gd` | **new** — the operator control: the closed set `none` / `rail` / `launch`, the kinds each builds, and the refusal for anything else |
| `godot/scripts/content/showcase_zone.gd` | **new** — the curated Zone dictionary naming the four approved rooms |
| `godot/scripts/gameplay/telemetry.gd` | **new** — the `p3a:` operator log |
| `godot/tests/playtest3a_driver.gd` | **new** — the proof suite |
| `godot/scripts/gameplay/zone_controller.gd` | the six-step offer lifecycle, `movement_package`, `offer_census`, `offer_rooms` |
| `godot/scripts/main.gd` | `--playtest3a`, the driver flag, and the one-call-only mode handoff |
| `godot/scripts/gameplay/player.gd` | `rail_caught` / `rail_released` signals, and the launch-flight binding (§7) |
| `godot/scripts/gameplay/affordance_nodes.gd` | `LaunchPad.fired` signal, and the call that begins a launch flight |
| `Makefile` | `godot-playtest3a` |

**No content changed.** `godot/content/registry/authored_art.json` is
byte-identical to `df2bb58`; review states are 18 `pass` / 3 `pending`; no
geometry, manifest, socket, offer, connector or scene file was touched. No
Python, schema, or Archipelago change.

## 2. The showcase chain

Four rooms, order fixed in `ShowcaseZone.ROOMS`. Placement, vertical offset,
yaw and overlap avoidance are `ZoneBuilder`'s from the authored entry and exit
connectors — none of it is restated in the showcase, because a second copy of
the placement arithmetic is how a composer and a builder come to disagree.

| # | shell | origin | yaw |
| --- | --- | --- | --- |
| 1 | `shell_hall_transit` | `(0, 0, 0)` | 0° |
| 2 | `shell_plenum_helix` | `(0, −40, 67)` | 0° |
| 3 | `shell_yard_gantry` | `(−7.4, −40, 140)` | −90° |
| 4 | `shell_span_basin` | `(−33.4, −54, 188)` | 0° |

The chain descends 54 m across the plenum's top-entry/bottom-exit form and the
span's one-way drop, and turns a quarter at the yard. Three of the four rooms
sit at a nonzero origin and one is yawed, which is what makes the frame proofs
in §9 mean anything.

## 3. Runtime lifecycle and ownership

`ZoneController._validate_offers`, six steps in this order:

1. the Zone root is already in the tree — `setup` put it there;
2. **one physics frame is awaited**, because a probe against a body the physics
   server has not registered answers "nothing there";
3. **every** declared offer of **every** room is purely validated against real
   geometry — all kinds, whatever mode is selected, so the census describes the
   rooms rather than the selection;
4. declines and refusals are reported by name;
5. only then, and only for the selected mode, are accepted offers
   **constructed**; `none` constructs nothing at all;
6. a second construction into the same room is refused by `MovementPackage`.

Ownership is unchanged: `ContentInstantiator` resolves shells, `ZoneBuilder`
places them, `OfferBinding.validate` measures and builds nothing,
`OfferBinding.construct` builds and is called from exactly one place.

## 4. Operator commands

Windows (`godot.exe` on PATH, or the bundled binary):

```
godot.exe --path godot -- --playtest3a
godot.exe --path godot -- --playtest3a --movement-package=none
godot.exe --path godot -- --playtest3a --movement-package=rail
godot.exe --path godot -- --playtest3a --movement-package=launch
```

Linux/macOS from the repository root:

```
godot-bin/godot --path godot -- --playtest3a --movement-package=rail
```

The proof suite: `make godot-playtest3a`.

Omitting `--movement-package` inside the showcase means `none`. Omitting
`--playtest3a` does nothing at all: `--movement-package` alone does not open
the showcase, and ordinary startup printed **0** `p3a:` lines and **0** offer
warnings.

## 5. The offer census

Measured on the live showcase, three times:

| mode | declared | judged | accepted | declined | refused | built | pads | rail lanes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `none` | 24 | 20 | 20 | 0 | 0 | **0** | 0 | 0 |
| `rail` | 24 | 20 | 20 | 0 | 0 | **4** | 0 | 29 |
| `launch` | 24 | 20 | 20 | 0 | 0 | **4** | 4 | 0 |

Exactly the expected census. The three numbers are different facts: 24 manifest
entries; 20 verdicts, because a launch **pair** is one verdict measuring two
authored points; and 4 built offers, because the 12 accepted `grapple_point`
offers construct nothing — there is no grapple mechanic, and calling one built
would be a claim that something was made (R9).

The 29 lanes for 4 rail routes are the per-segment ride volumes
`AffordanceFeatures.build_rail` sweeps along each curve; the offer count is 4.

## 6. Real-player rail result

Hall `rail_helix`, 146.1 m of baked curve, lane at `(−11.5, 4.4, 19.0)`.

* The player walked into the ride volume; the lane's own `body_entered` called
  `Player.offer_rail`, and `RailRider.catch` accepted — **caught**.
* **Rode 29.23 m** over 240 physics frames with the real `_physics_process`.
* Left it through the documented exit — a real `jump` action press, driven
  through the input map rather than by clearing the rider from outside —
  **released**, `riding_rail()` false.
* **The same approach under `none`**: no lane exists, nothing was caught, and
  the body ended 23.01 m from the lane and more than 2 m from where the ride
  finished. The route changed because of the package.

## 7. Real-player launch result, and one player-behaviour change

Hall `launch_basin` → `launch_gantry`. The pad fired the real player with
velocity `(3.56, 34.29, 6.09)`, 35.01 m/s — **identical to the validated
solution to 0.001 m/s**. The player rose 24.21 m, travelled 24.59 m and landed
**0.20 m from the authored landing point**.

**That last number required a change to player behaviour, and it is the one
judgement call in this task.** Measured first, then made:

`LaunchSolver` solves a *ballistic* arc — two free-fall halves, no horizontal
loss. The airborne walk solve lerps horizontal velocity toward the input
direction every frame at `AIR_CONTROL` (0.4), so a player who lets go of the
stick keeps `(1 − 0.16)ⁿ` of it. Over this pad's 1.43 s ascent that is
**3.7 × 10⁻⁷**. The first measurement was exact about the consequence:

```
rose 24.21 m, travelled 0.00 m, landed back on the pad
closest approach to the authored aim: 13.28 m
```

The vertical half matched the ballistic prediction (24.50 m) because gravity is
untouched; the horizontal half was deleted. **Every authored launch was a
bounce** — which is precisely the distinction `LaunchSolver` exists to make:
"a bounce pad is a local vertical opportunity … a launch pad is an EDGE —
source and destination are both part of the contract." A destination air
control deletes is not part of any contract.

So `Player` now treats a launch as ballistic until the next landing: the
horizontal solve is skipped for the duration of the arc, and nothing else about
walking, jumping, gravity or air control changes. The flag is set by the pad
that fires it and cleared by landing or by catching a rail.

I read this as the "narrow binding needed to consume the already-defined
launch nodes" the brief permits, because without it there is no launch
consumer at all — only a bounce pad. **Whether a player should be able to
steer mid-launch is a feel decision and is deliberately not made**: the
conservative default is that the trajectory that was validated is the
trajectory that happens. Flagged for an owner ruling.

Under `none`, standing on the same spot moved the body 0.10 m in the same
number of frames, and nothing fired.

## 8. Translated and yawed rooms

With the whole Zone placed at `(−311, 27, 148)` and yawed 60°, every room sits
somewhere different again:

| shell | world origin | yaw |
| --- | --- | --- |
| `shell_hall_transit` | `(−311.0, 27.0, 148.0)` | 60° |
| `shell_plenum_helix` | `(−252.98, −13.0, 181.5)` | 60° |
| `shell_yard_gantry` | `(−193.46, −13.0, 224.41)` | −30° |
| `shell_span_basin` | `(−164.89, −27.0, 270.93)` | 60° |

A pad in a placed, yawed room fired a real player who landed **0.20 m from its
authored aim** — the same accuracy as at the origin.

**The transform is applied exactly once**, and that is asserted rather than
assumed: every launch pair's world target is required to equal the authored
point through the room's frame once, to 0.001 m, **and** to differ by more than
1 m from the same point through that frame twice. Without the second half the
comparison would pass at identity, where once and twice are the same place.

## 9. `none` finishes the Zone

50 mandatory traversal endpoints across the four rooms, checked with **zero
offer geometry in the Zone**: **0 without ground**. No Check and no mandatory
route depends on a constructed offer (R8). The vacuity guard is asserted too —
a run that checked 0 endpoints fails rather than reporting clean.

## 10. Purity, ordering, duplication

* Validating a live room once, then twice, gives the identical verdict and
  changes node count, pad count and lane count by **0**, in all three modes.
* Asking for `["rail_route", "launch_source"]` and `["launch_source",
  "rail_route"]` gives identical verdicts — order independence as behaviour,
  not as a source-shape check.
* A second `construct` into the same room is **refused by name**
  ("already constructed"), builds nothing, and leaves the pad count unchanged.
* A genuinely new Zone instance still builds its own four pads, so the guard
  stops duplication rather than stopping the feature.

## 11. Unknown selection

`--movement-package=grapple` in the real game:

```
ERROR: p3a: movement package 'grapple' does not exist; the selections are none, rail, launch
p3a: REFUSED -- movement package 'grapple' does not exist; the selections are none, rail, launch
```

The showcase does not open, no Zone is built, and **zero** offer lines follow.
`grapple`, `rails`, `RAIL`, `""` and `"none "` are all refused; a refused
selection produces the empty mode, which builds nothing, rather than silently
becoming `none`.

## 12. Telemetry

Every line is prefixed `p3a:` on the print channel, because the `make` targets
filter warnings out of their output. Declines and refusals still warn. Nothing
is persisted, nothing crosses the bridge, and no AP event or interpretation-log
state was added.

```
p3a: showcase 'playtest3a_showcase' requested, movement-package=rail, shells=shell_hall_transit, …
p3a: room p3a_hall   shell=shell_hall_transit   mode=rail   declared=6 judged=5 accepted=5 declined=0 built=1
p3a: zone playtest3a_showcase mode=rail declared=24 judged=20 accepted=20 built=4 declined=0 refused=0
p3a: rail CAUGHT at (…)      p3a: rail RELEASED at (…)
p3a: launch FIRED from (…) at (…)
```

## 13. Sabotage

Twelve, each applied to the working tree, run, observed, and restored.

| # | sabotage | result |
| --- | --- | --- |
| S1a | drop the physics-frame await in the offer stage | **did not bite** — see below |
| S1b | run the offer stage inline instead of deferred | **did not bite** |
| S1c | let a detached root be answered instead of refused | **did not bite in 3A** |
| S1d | probe an unregistered space (the observable form) | **22 failures** |
| S2 | `validate` returns `consume` again | **13 failures** |
| S3 | remove the once-per-root construction guard | **9 failures** |
| S4 | judge in local coordinates (`to_world` = identity) | **18 failures** |
| S5 | apply the room transform twice in `world_target` | **10 failures** |
| S6 | `rail` also builds `launch_source` | **2 failures** |
| S7 | `launch` also builds `rail_route` | **4 failures** |
| S8 | `none` builds `rail_route` | **7 failures** |
| S9 | an unknown mode silently becomes `none` | **10 failures** |
| S10 | recombine judging and construction in one pass | **22 failures** |
| S11 | stop checking mandatory endpoints | **1 failure** (vacuity guard) |
| S12 | strip the real-player proof counters | **1 failure** (vacuity guard) |

**S1 is reported as it measured, not as I expected it to.** Three attempts to
make "constructing before physics readiness" fail inside the 3A suite did not:
in this lifecycle the rooms are attached and their colliders registered before
the deferred stage runs, so removing the await, running the stage inline, and
even removing the detached-root refusal all still pass. The hazard is real and
is guarded — but by two things other than that await: the **census**, which
catches an unregistered space loudly (S1d, 22 failures, because grapple and
launch offers are declined when nothing answers), and `movement_driver`'s
existing **V6** sabotage, which tests the detached-root and null-space refusals
directly. The one-frame await is defensive rather than load-bearing on this
path, and saying so is more useful than claiming a guard that does not bite.

## 14. Regression

| gate | result |
| --- | --- |
| Godot suites | **18 / 18 exit 0** (17 existing + `godot-playtest3a`) |
| Python | **1140 passed, 0 failed, 627 subtests** — Python 3.11.15, pytest 9.1.1, `anthropic` 1.1.0, Archipelago checkout present, apworld built |
| Packet / schema gate | clean — 11 documents, 949 identifiers |
| `make baseline` | **byte-identical**, no diff |
| Played Zone | `6e8d83d0f3ec088b` — 23 rooms, 15 Checks, 922 points, 35 enemies, unchanged |
| Authored registry | byte-identical to `df2bb58`; 18 `pass` / 3 `pending` |
| Ordinary startup | 0 `p3a:` lines, 0 offer warnings, unchanged |

## 15. A1 / A2 / A4 after this task

* **A1 — an authored room appears in an actually played Zone: NOT SATISFIED.**
  The showcase names its `shell_id` values by hand. That is an operator writing
  the field Epsilon will write in 3B, and R3 says 3B is defined by the real
  path. Ordinary generated Zones still contain zero authored rooms.
* **A2 — a real Zone is composed from approved authored rooms: NOT SATISFIED.**
  Same reason. Naming four rooms is not composition.
* **A4 — a real movement package changes navigation: MECHANICALLY PROVEN,
  NOT YET CLOSED.** A real player rode an authored rail and was thrown by an
  authored launch pad to within 0.20 m of its authored aim, and both routes
  differ from `none`. Under the brief this must be re-proven through the normal
  played-Zone path after 3B before it is treated as permanently closed.

**Playable 0.3 is not complete.** Nothing here promotes a room, changes a
review state, starts Wave 2, implements Theme Packs, touches environmental
agency, or invents a grapple mechanic.

## 16. Report path and commit

`docs/reports/2026-09-09-playtest3a-live-movement-consumer.md`

Commit: see the return message.

---

**One thing needs an owner ruling before 3B:** whether a launched player should
be able to steer mid-flight. Stage 3A committed to the conservative answer —
the validated trajectory is the trajectory that happens — because the
alternative left every launch pad a bounce pad. The measurement that forced the
choice is in §7.
