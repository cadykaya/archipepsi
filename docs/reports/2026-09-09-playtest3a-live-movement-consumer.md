# PROD — Playable 0.3, Stage 3A: the live movement consumer

**Archipepsi Production lane · 2026-09-09**

Head before: `df2bb58`. Frozen authority: `docs/ROAD_TO_PLAYABLE_0_3.md`.

**Amended 2026-09-09** with the owner's launch-air ruling (§7), the corrected
`none` evidence label (§9), and the S1 adjudication (§13). **Corrected
2026-09-09** with the three-phase lifecycle and exact selection (§3, §5),
the carrier non-cancellation rule (§7), and the landing reconciliation (§7). Stage 3A's
architecture, showcase, rail behaviour, offer census, lifecycle, telemetry,
safeguards and regression results are otherwise as accepted.

A real player now rides an authored rail and is thrown by an authored launch
pad, in a Zone built by the real runtime out of the four approved Wave-1
rooms. **Stage 3B is not started.** The showcase names its `shell_id` values
by hand, which is scaffolding and not composition.

---

## 1. Files changed

| file | what |
| --- | --- |
| `godot/scripts/gameplay/movement_selection.gd` | **new** — the operator control (the closed set `none` / `rail` / `launch` and the refusal for anything else) and the **deterministic selector** that names accepted offers by identity |
| `godot/scripts/content/showcase_zone.gd` | **new** — the curated Zone dictionary naming the four approved rooms |
| `godot/scripts/gameplay/telemetry.gd` | **new** — the `p3a:` operator log |
| `godot/tests/playtest3a_driver.gd` | **new** — the proof suite |
| `godot/scripts/gameplay/zone_controller.gd` | the **three-phase** offer lifecycle, `movement_package`, the seven-term `offer_census`, `offer_selection`, `offer_rooms` |
| `godot/scripts/main.gd` | `--playtest3a`, the driver flag, and the one-call-only mode handoff |
| `godot/scripts/gameplay/player.gd` | `rail_caught` / `rail_released` signals, the launch-flight binding, the carrier non-cancellation rule and the landing-only arc end (§7) |
| `godot/scripts/gameplay/movement_package.gd` | `judge`, `consume`, and `build_selected` — construction by identity |
| `godot/scripts/content/offer_binding.gd` | `construct_selected` |
| `godot/scripts/autoload/constants.gd` | `LAUNCH_CORRECTION_SPEED` |
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

## 3. Runtime lifecycle: three phases

`ZoneController._validate_offers`. The Zone root is already in the tree and one
physics frame is awaited first, because a probe against a body the physics
server has not registered answers "nothing there".

| phase | what it does | what it must not do |
| --- | --- | --- |
| **1 — VALIDATE** | purely measures every declared offer of **every** room against real geometry, all kinds, whatever the mode is | construct anything; choose anything |
| **2 — SELECT** | decides which accepted offers to build, **by identity**, with every room's verdict already in | construct anything; look at only one room |
| **3 — CONSTRUCT** | builds **exactly** the selected identities, from the verdict phase 1 took | re-judge; build anything not named |

**All validation finishes before the first construction**, and that is measured
rather than asserted about the source: the runtime records
`judged_before_first_build`, the number of rooms with a verdict when the first
node was made. Three-phase = 4; per-room validate-then-construct = 1. The suite
requires 4.

Phase 3 does not re-judge. Construction builds from phase 1's accepted array,
so no room is ever measured against another room's output.

**Ownership unchanged:** `ContentInstantiator` resolves shells, `ZoneBuilder`
places them, `OfferBinding.validate` measures and builds nothing,
`MovementSelection.select` chooses, `OfferBinding.construct_selected` builds.

### Exact-selection API

```gdscript
MovementSelection.select(mode, judged) -> Array   # {chamber, kind, offer}
MovementSelection.offers_for(chamber, selection) -> Array   # offer names
OfferBinding.construct_selected(root, accepted, chosen, who) -> Dictionary
```

`construct_selected` takes a verdict and a list of **names**, not a kind. An
offer that was accepted and not chosen constructs nothing; a name that is not
in `accepted` builds nothing either — construction is only ever a subset of
what was judged true. Construction can no longer build "everything of a
matching kind", because it is never told a kind.

### Deterministic selection policy

For the mode's kinds, take every accepted offer of those kinds and sort the
result on `chamber|kind|offer`. The sort is what makes the outcome independent
of the order rooms were placed in, the order the manifest listed offers in, the
order a `Dictionary` iterates, and the order the physics server answered.

For this library the policy happens to take one offer per room — but the
selection is still **enumerated by identity**, because a filter and a list that
happen to agree are not the same thing and only one of them can be checked.

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

## 5. The offer census — seven terms

Measured on the live showcase, three times:

| mode | declared | judged | accepted | **selected** | built | declined | refused |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `none` | 24 | 20 | 20 | **0** | 0 | 0 | 0 |
| `rail` | 24 | 20 | 20 | **4** | 4 | 0 | 0 |
| `launch` | 24 | 20 | 20 | **4** | 4 | 0 | 0 |

`judged_before_first_build` = **4** in every mode.

Seven different facts, none of them another:

* **declared 24** — manifest entries the four rooms carry, 6 apiece.
* **judged 20** — verdicts returned. Smaller, because a launch **pair** is one
  verdict measuring two authored points: the four `launch_target` entries are
  measured through their paired sources and never judged independently.
* **accepted 20** — verdicts that measured true.
* **selected 0 / 4 / 4** — accepted offers the package chose, by identity.
  Smaller, because a mode considers only its own kinds.
* **built 0 / 4 / 4** — selected offers a node now exists for. The **12
  accepted grapple points construct zero nodes** in every mode: there is no
  grapple mechanic, they are never selected, and calling one built would be a
  claim that something was made.
* **declined 0**, **refused 0**.

Scene counts agree with the census: `none` 0 pads / 0 lanes; `rail` 0 pads /
29 lanes (the per-segment ride volumes of 4 routes); `launch` 4 pads / 0 lanes.

## 6. Real-player rail result

**Selected identity:** `p3a_hall / rail_route / rail_helix` — one of the four
the selector named (`p3a_hall/rail_helix`, `p3a_plenum/rail_descent`,
`p3a_span/rail_underdeck`, `p3a_yard/rail_crane`). 146.1 m of baked curve, lane
at `(−11.5, 4.4, 19.0)`.

* The player walked into the ride volume; the lane's own `body_entered` called
  `Player.offer_rail`, and `RailRider.catch` accepted — **caught**.
* **Rode 29.23 m** over 240 physics frames with the real `_physics_process`.
* Left it through the documented exit — a real `jump` action press, driven
  through the input map rather than by clearing the rider from outside —
  **released**, `riding_rail()` false.
* **The same approach under `none`**: no lane exists, nothing was caught, and
  the body ended 23.01 m from the lane and more than 2 m from where the ride
  finished. The route changed because of the package.

## 7. Real-player launch result, and the launch-air ruling

Hall `launch_basin` → `launch_gantry`. The pad fired the real player with
velocity `(3.56, 34.29, 6.09)`, 35.01 m/s — **identical to the validated
solution to 0.001 m/s**. Closest approach to the authored landing point during
the flight: **0.20 m**; landing point with no input held: **1.03 m** from the
authored aim. (Two different measurements, reported as two.)

### What was measured first

`LaunchSolver` solves a *ballistic* arc — two free-fall halves, no horizontal
loss. The airborne walk solve lerps horizontal velocity toward the input
direction every frame at `AIR_CONTROL` (0.4), so a player who lets go of the
stick keeps `(1 − 0.16)ⁿ` of it. Over this pad's 1.43 s ascent that is
**3.7 × 10⁻⁷**:

```
rose 24.21 m, travelled 0.00 m, landed back on the pad
closest approach to the authored aim: 13.28 m
```

The vertical half matched the ballistic prediction (24.50 m) because gravity is
untouched; the horizontal half was deleted. **Every authored launch was a
bounce** — precisely the distinction `LaunchSolver` exists to make: "a bounce
pad is a local vertical opportunity … a launch pad is an EDGE — source and
destination are both part of the contract."

### The ruling, and three behaviours kept distinct

Owner ruling: **protect the launch, do not lock the player.** The first fix
disabled airborne input entirely, which conflicts with the Player Authority —
the base player can always modestly correct in the air. Three things are now
separate:

| behaviour | what it is |
| --- | --- |
| **ballistic carrier motion** | the horizontal half of the velocity the pad fired, stored apart from `velocity` and never touched by the airborne lerp |
| **bounded player correction** | a modest contribution layered on top each frame, capped at one named value |
| **ordinary movement** | untouched, and resumed the instant the arc ends |

### The carrier may not be cancelled

A second correction was needed. The first version clamped the **result's**
axial component at zero, which prevented reversal and still permitted
**cancellation**: a 1 m/s carrier opposed by a 2 m/s correction stopped moving
forward while the carrier sat privately stored, doing nothing. A carrier
preserved in a variable but absent from the velocity is not preserved.

The correction is now **decomposed against the authored axis before it is
applied**, and the opposing half is removed rather than clamped afterwards:

* the component **along** the authored direction may only be positive —
  bounded and additive, never subtractive;
* the component **across** it is free, bounded the same way, and bends the arc;
* so the applied axial speed is `|carrier| + forward × SPEED`, **never less
  than the carrier's own**.

Holding directly backward therefore contributes no axial correction at all. The
guarantee is arithmetic, not tuned, and holds for a 1 m/s carrier as surely as
a 20 m/s one.

For a **purely vertical carrier** with no horizontal authored axis, the carrier
(zero) is preserved exactly and the whole bounded correction is available
laterally — no horizontal launch direction is invented.

### A defect this uncovered

`is_on_floor()` carries the previous `move_and_slide`'s answer, and **a pad
fires a player who is standing on it**. On the frame after a grounded launch
the flag was still true, so the arc was ended before it had risen a centimetre
— every launch a player *walked* onto rather than *fell* onto lost its carrier.
Only a test that drops the body onto the pad fails to notice, and that is
exactly the configuration the earlier proofs used. Two corrections:

* only a **landing** ends the arc — on the floor *and* not rising;
* `_launch_flight` is the **single authority** for "is the arc running". Asking
  `is_on_floor()` again in the carry gave the carry and the ending two
  different notions of airborne, and the ordinary lerp drove a live carrier to
  −2.2 m/s in one frame.

### The provisional tuning value

```gdscript
const LAUNCH_CORRECTION_SPEED = 2.0   # m/s, Constants
```

**One named value, provisional**, its final feel Playtest 3's. A *speed*, in
the same units as `WALK_SPEED` (7.0), so "modest" is legible at under a third
of a walking pace. It bounds the correction only; the carrier is never scaled
by it.

**Measured effect**, hall pad, carrier `(3.56, 0, 6.09)` = 7.06 m/s:

| input held for the whole flight | result |
| --- | --- |
| none | closest approach **0.20 m**, landed **1.03 m** from the aim; carrier drift **0.0000 m/s** |
| perpendicular | **4.10 m** of lateral displacement; carrier drift **0.0000 m/s** |
| directly opposing | landed **14.25 m along** the authored direction, 14.25 m from the pad |

**On the slow-arc fixture** (1.0 m/s carrier, correction 2.0 — the boundary
where the invariant is load-bearing rather than arithmetic):

| run | forward progress along the authored axis | applied axial speed vs the carrier's |
| --- | --- | --- |
| no input | **1.883 m** | **0.0000 m/s** below |
| full opposing input | **1.900 m** | **0.0000 m/s** below |

The two agree to 0.017 m: opposing input contributes nothing axial, so it
neither slows, cancels, nor reverses the arc, and the applied velocity's
authored-axis component never falls below the carrier's own on any frame.
Forward progress is measured **at the moment the arc ends**, not at the loop's
end — after landing a held direction simply walks, which is correct behaviour
and is not the launch.

### Landing-error reconciliation

The two numbers were never a regression. They are **two metrics of the same
flight**, and both are now measured in one place and reported together.

| | |
| --- | --- |
| shell | `shell_hall_transit` |
| source offer | `launch_basin`, `launch_source`, room-local `(9.0, 0.0, 18.0)`, reservation radius 3.0 |
| target offer | `launch_gantry`, `launch_target`, room-local `(16.0, 21.0, 30.0)`, **landing radius 3.5** |
| configuration | showcase at identity, `--movement-package=launch`, real `Player`, input unfrozen, no direction held |
| **closest approach during flight** | **0.20 m** |
| **landing position** | **1.03 m** |

The first 3A report's 0.20 m was the closest-approach metric; §8's yawed-room
0.20 m is the same metric on a different placement of the same offer. The
amendment's 1.03 m is the landing position. **Same offer, same configuration,
different moments** — and both are well inside the authored 3.5 m landing
radius. No authored data or geometry was touched.

**And the landing is a place a player can be**, not merely a number near the
aim: ground found at **y = 21.000** — the authored target's own height — and
the capsule at the derived stand pose is **clear**.

### Launch state lifetime

Cleared in one place, `_end_launch_flight`, called from: **landing**; **catching
a rail**; **death** (which is also the out-of-bounds recovery — falling past
`FALL_KILL_Y` kills); **respawn**; and **`set_spawn`**, which is Zone entry and
Zone replacement. Proven: after landing the state is clear, a later launch from
the same pad begins with that pad's own carrier, a killed player is not in
flight, a respawned player carries nothing, and `set_spawn` clears it.

No persistent state, no AP event, no Epsilon decision and no schema field was
introduced.

### Ordinary jumping is unchanged

Measured on an un-launched airborne player: horizontal speed **6.00 → 0.07 m/s
over 20 frames**. The existing air control still runs exactly as before for
anyone who is not flying an authored arc.

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

A pad in a placed, yawed room fired a real player whose **closest approach to
its authored aim was 0.20 m** — the same metric, and the same figure, as at the
origin. (See §7 for why closest approach and landing position are two numbers.)

**The transform is applied exactly once**, and that is asserted rather than
assumed: every launch pair's world target is required to equal the authored
point through the room's frame once, to 0.001 m, **and** to differ by more than
1 m from the same point through that frame twice. Without the second half the
comparison would pass at identity, where once and twice are the same place.

## 9. Mandatory-route / no-offer solvability audit

**What this is, precisely.** 50 mandatory traversal endpoints across the four
rooms, checked with **zero offer geometry constructed in the Zone**: **0
without ground**. That is the authored mandatory-route audit staying clean
without any movement offer — R8's invariant, measured.

**What it is not.** It is *not* an observed end-to-end player completion of the
four-room showcase. No such run was performed, so none is claimed. **A6 — "the
current player can complete the Zone" — remains open**, for the genuine played
Zone and the owner's playtest after Stage 3B.

The vacuity guard is asserted too: a run that checked 0 endpoints fails rather
than reporting clean.

## 10. Selection, purity, ordering, duplication

**The selection, by identity:**

```
rail   -- p3a_hall/rail_route/rail_helix, p3a_plenum/rail_route/rail_descent,
          p3a_span/rail_route/rail_underdeck, p3a_yard/rail_route/rail_crane
launch -- p3a_hall/launch_source/launch_basin, p3a_plenum/launch_source/launch_floor,
          p3a_span/launch_source/launch_basin, p3a_yard/launch_source/launch_west
none   -- nothing selected
```

Proven behaviourally:

* **reversing the room array** — a live Zone built from the reversed showcase
  selects the identical four identities and builds 4 nodes;
* **reversing every manifest offer array** — the real validator measures the
  real room with `offers` reversed, and the selection is unchanged;
* **any other ordering** — the accepted array is reversed before selecting;
  unchanged. The sort on `chamber|kind|offer` is what guarantees it;
* **rail selects no launch, launch selects no rail** — asserted on the
  selected `kind`, not only on the nodes that came out;
* **none selects nothing** — `selected = 0`, `built = 0`;
* **accepted but unselected constructs nothing** — each room accepts 3 grapple
  points (12 across the Zone) and builds none of them, in every mode;
* **selection is pure and repeatable** — selecting twice from one verdict gives
  the identical identities;
* **construction cannot add an identity absent from the selection** — an empty
  selection built **0** nodes into a live room, and a selection naming one rail
  built exactly that one and no pad, in all four rooms;
* **validation is identical before and after selecting** — selection builds
  nothing, and a verdict taken after it matches one taken before;
* **all room validation finishes before the first construction** —
  `judged_before_first_build = 4`.

**Purity and duplication**, unchanged from the accepted result: validating once
then twice gives the identical verdict and changes node, pad and lane counts by
**0** in all three modes; both request orders agree; a second construction into
the same room is **refused by name** and leaves the pad count unchanged; a
genuinely new Zone still builds its own four.

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

The seven terms are printed as seven, per room and per Zone, plus the selection
by identity:

```
p3a: room p3a_hall   shell=shell_hall_transit   mode=rail   declared=6 judged=5 accepted=5 selected=1 declined=0 built=1
p3a: room p3a_plenum shell=shell_plenum_helix   mode=rail   declared=6 judged=5 accepted=5 selected=1 declined=0 built=1
p3a: room p3a_yard   shell=shell_yard_gantry    mode=rail   declared=6 judged=5 accepted=5 selected=1 declined=0 built=1
p3a: room p3a_span   shell=shell_span_basin     mode=rail   declared=6 judged=5 accepted=5 selected=1 declined=0 built=1
p3a: selection mode=rail (4) -- p3a_hall/rail_route/rail_helix, p3a_plenum/rail_route/rail_descent, p3a_span/rail_route/rail_underdeck, p3a_yard/rail_route/rail_crane
p3a: zone playtest3a_showcase mode=rail declared=24 judged=20 accepted=20 selected=4 built=4 declined=0 refused=0 (rooms judged before the first build: 4)
p3a: rail CAUGHT at (…)      p3a: rail RELEASED at (…)
p3a: launch FIRED from (…) at (…)
```

A count cannot distinguish "the rail in every room" from "four rails in one
room", so the selection is named one identity at a time.

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


**Amendment sabotages (2026-09-09):**

| # | sabotage | result |
| --- | --- | --- |
| A1 | let the ordinary airborne lerp erase the carrier | **6 failures** |
| A2 | disable launch air correction completely (`LAUNCH_CORRECTION_SPEED = 0`) | **1 failure** — "the correction is not reaching the flight" |
| A3 | drop the non-reversal invariant | **1 failure** — "reversed the launch: −1.8833 m backward along the authored direction while still in flight" |
| A4 | let launch state survive landing and reset | **4 failures** |
| A5 | apply the room transform twice in the yawed-room launch case | **10 failures** |

A3 needed its test placed where the invariant is load-bearing. On the hall pad
the carrier is 7.06 m/s and the correction is capped at 2.0, so "opposing input
cannot reverse the launch" is arithmetic there and the structural guard never
fires — removing it changed nothing observable. The guard matters for a carrier
*slower* than the correction, so it is now proven there: a real player, a real
launch state, a deliberately slow 1.0 m/s arc, and a held direction straight
back down it. In flight the player never went further back than **0.0000 m**
along the authored direction; with the invariant removed, **−1.8833 m**.

**Correction sabotages (2026-09-09):**

| # | sabotage | result |
| --- | --- | --- |
| B1 | the selector becomes a filter again — construction ignores the chosen identities and builds every accepted offer | **18 failures** — "mode rail built 8 nodes, not the 4 it should" |
| B2 | the lifecycle collapses back to per-room validate-then-construct | **5 failures** |

### S1 — adjudicated, and recorded as measured

Removing the defensive physics-frame await did not fail, and no failing test
was manufactured for it. The record:

* **Why it did not fail:** on this path the rooms are already attached and
  physics-registered by the time the deferred offer stage runs, so removing the
  await, running the stage inline, and even removing the detached-root refusal
  all still pass.
* **The actual required invariant** is a **valid, registered physics space** —
  not the await itself.
* **The biting guard is the unregistered-space sabotage** (S1d, 22 failures):
  with the room's colliders absent from the space every probe answers "nothing
  there", grapple and launch offers are declined, and the census catches it
  loudly. `movement_driver`'s existing **V6** covers the detached-root and
  null-space refusals directly.
* **The await is defensive lifecycle protection** and is not claimed as a
  load-bearing proof.

This result is accepted and does not block Stage 3A.

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

**The launch-air question is settled** (§7): the ballistic carrier is
protected, a bounded player correction of `LAUNCH_CORRECTION_SPEED = 2.0` m/s
is layered on top, and the correction can bend the arc but never cancel,
reverse, or return the player to the pad. That value is **provisional** and its
final feel is Playtest 3's to calibrate.
