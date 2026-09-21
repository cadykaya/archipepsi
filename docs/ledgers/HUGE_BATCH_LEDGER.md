# Archipepsi 0.4 huge batch — durable work ledger

## Approved assignment

- **Approved plan/version:** 2026-09-21 integrated plan + owner addendum of the
  same date (gantry in S2; second binding relabelled; P0 measures before
  prescribing; four persistence lifetimes; D7 backlogged).
- **Actual starting revision:** `19c5d8e` ("Restamp the placement captures against
  the verified revision").
- **Production comparison revision:** `19c5d8e` on
  `claude/archipepsi-echoes-continuation-b1adno` (draft PR #4) — **untouched**.
- **Development branch:** `claude/archipepsi-0-4-blindside`, branched from
  `19c5d8e`.
- **Latest known-good playable checkpoint:** `19c5d8e` (0.3 candidate; full
  frontier green).
- **Scope decisions approved:** `grapple_to_surface` featured; three-dock Blindside
  prototype; minors EX50-011 / EX50-021 / EX50-033; first-class `RailNetwork`;
  full-strength acquisition integration as M2's completion requirement.
- **Decisions still unresolved:** Forge/Static economy (B4); seed/retry policy;
  D7 return-later progression policy; old-save repair.
- **Processes running:** none.
- **Scheduler state:** heartbeat disabled; no watchers, subscriptions or scheduled
  check-ins. Observed via `list_triggers` — the account's routines are one-shot
  pokes belonging to an unrelated project, none firing into this session.

## Lane status

| Lane | Owner | Accepted? | Blocking |
|---|---|---|---|
| Engine / integration | Prod (this session) | yes | — |
| Bridge / design (D-1..D-6) | Dess | **not accepted — handoff prepared only** | M2 completion (D-1/D-2/D-3); genuine Epsilon objective selection (D-5) |
| 3D models | Arty | **not accepted — asset brief prepared only** | Final visual verdict only; blockout ships first |

## Task statuses

| ID | Player-visible outcome / contract | Source authority | Depends on | Owner/files | State | Revision | Evidence / limit |
|---|---|---|---|---|---|---|---|
| M0 | 0.4 line exists, 0.3 untouched | plan §4 | — | branch, this ledger | implemented | `19c5d8e`+ | branch created from 19c5d8e; 0.3 head unchanged |
| P0 | Measured: is a body actually carried on a moving platform? | addendum "P0 measures before prescribing" | — | `godot/tests/passenger_carry_driver.gd` | **verified** | `a7d23df`+ | 4 cases, all ABOARD, GROUNDED 300/300 in every case. `make godot-passenger-carry`, in CI |
| P2 | The railway is a vehicle: it travels dock to dock, stops, refuses missing track, reverses, and holds safely | plan §3 build order P2 | P0 | `godot/scripts/gameplay/rail_carrier.gd` | **verified** | `29ccf7a`+ | `make godot-rail-carrier`, in CI. 73 checks incl. a real passenger round the corner: DRIFT 0.124 m, GROUNDED 273/273, ABOARD yes |
| P2b | The rail a player sees is the rail they ride | plan §3 build order P2 ("swept along `polyline()` not `segments()`") | P2 | `affordance_features.gd`, `affordance_driver.gd` | **verified** | `29ccf7a`+ | ride left the swept beam by 0.744 m before, 0.030 m after. F-02 |
| P3 | Shooting a control sends the carrier; one blast is one command; opposed commands cancel and say so | plan §3 build order P3 | P2 | `rail_receiver.gd`, `rail_controls.gd` | **verified** | `29ccf7a`+ | fired through `Player._fire_static_pulse`, not by calling the element. Negative control: the same control alone travels |
| P4 | A player pulls a lever; a span of track locks home; the link becomes crossable; the repair survives leaving | plan §3 build order P4 / addendum "persistence precision" | P2, P3 | `rail_span.gd`, `alignment_control.gd`, `rail_junction.gd` | **verified** | `d1abde5`+ | `make godot-rail-junction`, 49 checks, in CI. Real `Player`, real `interact` verb, all four lifetimes measured separately |
| M1 | The client half of the latch contract: `latch_fired` sent, `progress.latched` read back | plan §3 P4 | P4 | `zone_controller.gd`, `main.gd` | **verified** | `d1abde5`+ | the bridge half was complete and tested since the physics slice; the client had never sent one |
| M1-zone | A junction inside a real composed Zone | plan §6 decision 3 | **D-4 (Dess)** | — | **blocked** | — | a package binds to `feature:<tag>` or `shell:<id>` only, and §13.2 forbids the first. Nothing in the Zone schema declares rail content, so no composed Zone can carry one |
| A-fix | `godot-return-journey` green again | 0.3 carry-over | — | `integration_driver.gd` | **verified** | `a0be324` | F-04 |
| M1-play | M1 is a place a person can stand: `--railway` | plan §3 ("M1 ... independently playable") | P4 | `railway_scenario.gd`, `railway_shot_driver.gd` | **verified** | `ca43341`+ | `make godot-rail-junction` builds and measures it; `make railway-shots` renders it. **Development scaffolding, not a Zone** |
| M2-mech | The intended experience, in a development scenario: see a control you cannot reach, cross to a branch, acquire the tool, come back and open it | plan §3 build order P5 / addendum "first grapple configuration" | P4, M1-play | `railway_scenario.gd` (`EchoGrant`), `echo_runtime.gd` | **verified, and labelled** | `f9f51e9`+ | 79 checks. **Explicitly not M2 and not multiworld-safe**: the Echo is handed over by the scenario's own pedestal, not by a Check, a fold or a snapshot |
| M1-visible | Leaving and coming back: the repair stays, everything else is rebuilt | addendum "persistence precision" | M1-play, M2-mech | `railway_scenario.gd` (`ReturnPlinth`, `reenter`) | **verified** | `9733cb5`+ | 88 checks. The case asserts the span, the lever and the carrier are DIFFERENT OBJECTS afterwards, so a reset dressed as a rebuild cannot pass it |

## Findings

### F-01 — the carry works; the deck is the constraint

- **Task / case identity:** P0, `make godot-passenger-carry` at `a7d23df`+,
  `AffordanceNodes.MovingPlatform` (2.4 x 0.4 x 2.4 deck, `PERIOD 5.0`), real
  `Player.create()`, four travel vectors.
- **Observation (not hypothesis):**

  | case | travel | DRIFT | GROUNDED | ABOARD |
  |---|---|---|---|---|
  | horizontal (skiff's case) | `(6,0,0)` | 0.609 m | 300/300 | yes |
  | vertical (shipped case) | `(0,3,0)` | 0.304 m | 300/300 | yes |
  | diagonal (climbing) | `(4,2,0)` | 0.454 m | 300/300 | yes |
  | horizontal + one footfall | `(6,0,0)` | 0.823 m | 300/300 | yes |

  Final offset returns to the starting offset in every non-walking case
  (e.g. horizontal `(-0.25, 0.20, 0)` -> `(-0.21, 0.20, 0)`).
- **Hypothesis and contradictory evidence checked:** four `player.gd` sites were
  suspected of fighting a moving deck — the step-down walker
  (`_note_a_step_down_ahead` / `_follow_the_step_down`, raw `move_and_collide`
  plus forced `velocity.y = 0`), the step-up climb
  (`_climb_a_step_the_law_promises`, `global_position +=`), world-space-absolute
  walk targets, and `is_on_floor()`-gated control. **None of them bit.** 100%
  grounded across 1200 measured frames, including the descending half of the
  diagonal case, contradicts the step-down hypothesis directly.
- **Cause established by:** measurement, not reading. `sync_to_physics = true` on
  an `AnimatableBody3D` does carry a `CharacterBody3D`, as
  `affordance_nodes.gd:398-400` claimed and nothing had tested.
- **Change:** **none to `player.gd`.** The candidate repairs named in the plan are
  withdrawn on the evidence. Added `godot/tests/passenger_carry_driver.gd` and the
  `godot-passenger-carry` gate.
- **Two instrument errors, caught before reporting:** (1) holding `move_forward`
  for a full 5 s period walked the passenger off a 2.4 m deck at 0.15 s and
  reported it as a carry failure — that is arithmetic about deck width, not a
  finding; (2) `ABOARD_LIMIT` was 1.0 m from the deck origin while the deck's own
  half-width is 1.2 m, so it called a passenger "off" while they were still
  standing on it. Both corrected; the case now measures one footfall against the
  real deck edge.
- **Remaining limit:** drift up to 0.609 m is transient lag while the deck
  *accelerates*, recovered afterwards. It is a function of the carrier's
  acceleration profile, so it is a **P2 tuning input**, not a defect.
- **Consequence for the carrier (design input):** the shipped 2.4 m deck is
  crossed by a walking rider in ~0.4 s. A skiff whose passenger moves to aim or
  take cover needs a deck sized from the rider's movement; 2.4 m must not be
  inherited from `MovingPlatform`.

### F-02 — the beam was not where the ride is

- **Task / case identity:** P2b, `make godot-rail-carrier` BEAM case and
  `make godot-affordance` `_the_rail_mesh_and_ride_come_from_one_path`, on the
  four-point bent route `(0,0,0) (9,0,0) (15,0,5) (15,0,13)`.
- **Observation (not hypothesis):** the ride leaves the control-point chord by
  **0.744 m** at the corner. The beam's own thickness is 0.35 m, so half of it is
  0.175 m: a rider on a curved rail was beside the beam, not on it. Swept along
  the ride instead, the worst gap is **0.030 m** — inside the beam.
- **Cause established by:** reading the two producers against each other, then
  measuring. `RailPath` gained Catmull-Rom handles in P3.5; `build_rail` still
  swept `segments()` (the control points). `rail_path.gd:261` recorded that the
  two "agree by construction" — **true when it was written**, because the curve
  was a polyline then.
- **Change:** `AffordanceFeatures.rail_sweep_points()` sweeps the control points
  when `bow() <= RAIL_BEAM_THICKNESS * 0.25` and a 1 m resample of the ride
  otherwise. `_aim_along` now sets a full basis instead of `rotation.y` alone, so
  a climbing rail is pitched rather than left as a horizontal box with a sloped
  ride inside it.
- **Shipped rails are byte-for-byte unchanged, and that is checked:** every rail
  in the game today is `rail_path()`'s two points, whose `bow()` is 0.0000 m, and
  the suite asserts that such a rail is still swept between its control points.
- **A test was changed, and here is exactly how.** `_the_rail_mesh_and_ride_come_from_one_path`
  asserted one box per *control* segment at the *control* midpoint — i.e. it was
  pinning the divergence in place. Its actual claim (the beam and the lane come
  from ONE path, and a hardcoded length must be detectable) is kept and now reads
  against the swept route. Its sabotage resistance came from three UNEQUAL
  segment lengths, and a uniform resample would have handed that hole back, so
  the suite now asserts the swept runs contain more than one distinct length.
  The case got stronger: 3 segments checked before, 14 now.

### F-03 — two carrier defects, found before it shipped

- **Braking stall.** The textbook loop — accelerate, shed speed once inside
  `v^2 / 2a` — undershoots by `v * delta / 2` on a discrete step. At 7 m/s and
  60 Hz that is 0.058 m, **further than `DOCK_EPSILON` (0.05)**: the carrier
  would halt short of the dock and then creep in, stuttering, re-accelerating
  every frame. Found by arithmetic before the first run. Replaced with a speed
  ceiling of `sqrt(2 * ACCEL * remaining)`, which is self-correcting and never
  implies braking harder than `ACCEL`.
- **A fail-safe that could not be released.** `hold(true)` leaves the carrier
  between docks with `heading == HOLD` and `target_dock == -1`; every later
  command fell into the reversing arithmetic and came back *"there is no dock
  behind this carrier"*. A held carrier that can never move again is not a
  fail-safe, it is a trap with a passenger in it. Found while writing the HOLD
  case. Fixed with `_segment()`: both ends of the segment the carrier is
  standing in are reachable, because it is standing in it.
- **Limit:** `ACCEL = 3.0` is still a number chosen from F-01's drift, not from
  a played route. The measured drift at that value is 0.124 m — a fifth of what
  `MovingPlatform`'s cosine loop produced — but tuning it is a playtest input.

### F-04 — the suite CI does not run was red for a day

- **Task / case identity:** `make godot-return-journey`, the PHYSICAL leg of
  `_the_return_carries_a_body_home` in `integration_driver.gd`.
- **Observation:** *"walking into the pad raised exactly one traversal and it
  raised 0"*, then *"the production consumer put the body at the Zone start:
  136.8 m away"*. Red since `19c5d8e`, found by running it as part of this
  batch's regression sweep.
- **Cause established by:** reading the three consumers of the changed contract
  against each other. `19c5d8e` turned the return plug from a tripwire into a
  2 s hold, at the owner's request. `room_contract_driver` and
  `traverse_driver` were updated with it; this one was not. `_walk_to` stops the
  moment the body is within 0.3 m of the pad — the instant the charge *starts* —
  and the case asserted the traversal had already happened.
- **Why nothing said so:** `godot-return-journey` is in `NOT_A_SUITE` and CI
  never runs it. Its own guard file's thesis is *"a suite nobody runs is worse
  than no suite"*, and this is what that costs.
- **Change:** the case now stands still and lets the device's clock run, in the
  same shape `traverse_driver._hold_in_the_plug` uses. **Not a relaxation:**
  entry is asserted to fire NOTHING, which the old assertion could not express,
  and the hold is asserted separately.
- **Open, not decided by this lane:** the suite ran green END TO END tonight,
  including the three legs its exclusion note describes as blocked on the
  `platform_path` side-door defect. That note may be stale. The exclusion was
  **not** changed — giving a live-bridge suite a CI step is the owner's call and
  one green run is not proof the named defect is closed.

### F-05 — M1 is complete except for the one part a schema owns

- **What works, measured:** the whole chain. A real `Player` aims the real
  interact probe at the lever, presses `interact`, the span travels, locks,
  fires its latch once, and the link the carrier was refused on becomes
  crossable. `ZoneController.report_latch` sends the intent with exactly the
  fields `record_latch` reads, idempotently. `main.gd` unions
  `progress.latched` into `latches_carried` beside keys, locks and stations,
  and a junction rebuilt from that union comes up repaired **without reporting
  anything**.
- **The four lifetimes, each measured separately** (addendum "persistence
  precision"): the accepted repair persists; a span left mid-travel leaves
  nothing behind; the lever comes back armed; the carrier is parked on a
  supported dock rather than resumed from a saved transform.
- **What is blocked, and why it is not a workaround waiting to happen:** a
  physics package binds to `feature:<tag>` or `shell:<shell_id>`
  (`layout.py::_content_refs`), and §13.2 forbids a `features:` tag from
  mattering. Nothing in the Zone schema declares rail content, so the composer
  cannot ask for a junction and the engine must not invent one. That is **D-4**,
  and it is Dess's.
- **One saved latch does not prove general persistence**, and nothing here is
  reported as if it did.

### F-06 — three defects the screenshots found and no test would have

- **The gantry stair reached nothing.** `_stair` took a foot, a height and a
  direction and chose its own tread, so its top step landed where the arithmetic
  put it: **four metres short of the gantry platform and two metres below it.**
  The lever was unreachable, and the whole scenario turns on reaching it. Now
  both ends are given and the count and tread are solved from them.
- **The stowed span read as more track.** Swinging a fourteen-metre beam aside
  about the vertical flung it across the yard at an angle that, from the dock,
  looked like track. Raised instead — a drawbridge — *"the bridge is up"* reads
  from anywhere you can see it, which is what a player at S2 must be able to
  tell before anything refuses them.
- **The direction chevron was a rectangle.** A `PrismMesh` shows its triangle
  along one axis only; aiming the apex down the track with a quarter turn about
  X left the player looking at the extruded rectangle from the dock. The
  triangle's plane is now the one containing the track and up. Before that, the
  chevron was buried inside the plate entirely, because the plate is turned to
  face the dock and the offset was computed from its thickness.
- **How they were found:** by rendering the scenario and looking at it
  (`make railway-shots`). `godot-rail-junction` passed throughout — every one of
  these is a fact about legibility or reachability that the signal-level
  assertions could not see. The suite now also builds the scenario and measures
  it, so the parts a test *can* hold are held.

### F-07 — the grapple is a verb the ballistics have to allow

- **Task / case identity:** M2-mech, `make godot-rail-junction`, real `Player`,
  real `fire_mobility` press, the component the schema's own tests author
  (`grapple_to_surface`, range 20, pull_force 14).
- **Measured, not assumed:** `_grapple` sets `velocity` to `pull_force` toward
  the hit point, and the player's own movement then lerps the HORIZONTAL part
  toward the walk intent every frame. The vertical survives; the lateral does
  not. Under this gravity (~21.9 m/s², measured from the arc) a 14 m/s pull
  tops out **4.45 m above where it started**, and only about the first metre of
  its lateral carry arrives.
- **Consequence for the geometry, which is where it was fixed:** a gantry 3.8 m
  above the dock and ten metres out was outside that envelope — the first cut
  peaked 2.7 m up and the player landed back where they started, and a second
  cut clipped its head on the gantry's own underside on the way up. The gantry
  is now 3.1 m above the rail and 7.5 m out, with the plate above its inner lip:
  the pull is steep, clears the lip, and lands. **Nothing in `player.gd` was
  changed** — its movement damping is production behaviour and a feel change to
  it is the owner's decision, not this lane's.
- **One defect repaired, because the grapple is now load-bearing:** `_grapple`
  returned on a miss with no `_refund_press()`, burning the cooldown and the
  power draw on a shot at the sky, while `_blink` and `_grapple_swing` both
  refund. A shot that lands on something that is not a `StaticBody3D` now
  refunds too: it is a miss for this verb and the player cannot tell the two
  apart.
- **An instrument error, caught before reporting:** the first cut read the
  cooldown one physics frame after the press and reported the Echo broken. A
  press issued from a coroutine lands between frames, so
  `is_action_just_pressed` can fall on the frame after the one the test resumes
  on — the pull it fired was already in the air. The case now waits a few
  frames for the press to be delivered.

## Full-Amalgam matrix

*(built incrementally per plan §4 — never a prerequisite to starting)*

## Playable milestones

| Milestone | Build/ref | Launch/mode/save | Actual continuous player path | Test shortcuts | Owner verdict |
|---|---|---|---|---|---|
| 0.3 candidate | `19c5d8e` | production mode | exit/hold patch unplayed by owner | — | not yet played |
| M1 + M2-mech, the railway | `f9f51e9`+ | `godot --path godot -- --railway` (or `godot-bin/godot --path godot -- --railway`) | board at S1, shoot the chevron pointing down the track, ride; S2→S3 is refused; the gantry that lowers the span is overhead and out of reach; walk the branch past it, take the hookshot, try it on the ledge, come back, pull yourself to the ring, press E on the lever, ride to S3 | **the whole scenario is a test shortcut**: not a Zone, no campaign, no bridge, no Checks, no exit, and the Echo is granted by a pedestal rather than by a Check | not yet played |

## Checkpoint

- **Last completed milestone:** M2-mech, and the visible re-entry. P0, P2, P2b, P3, P4, M1 and the
  development-scenario loop verified.
- **Current coherent tree:** `claude/archipepsi-0-4-blindside`; `godot-rail-carrier`,
  `godot-passenger-carry`, `godot-affordance`, `godot-movement`, `godot-physics`,
  `godot-traverse`, `godot-content` and `godot-activity` green.
- **Deliberate reordering (decided by this lane, owner asleep):** P2/P3 were taken
  before P1. P0 delivered P1's stated de-risk value directly — the carry is
  measured — and Passing Platforms wants exactly a carrier that stops at points,
  so building the vehicle first means the minor reuses `RailCarrier` instead of
  duplicating it.
- **Exact next action (owner's call first):** the whole first loop is playable
  and unplayed. Walking it is worth more than the next feature, because
  everything after this reuses its parts.
- **Not done and not started:** P1 (EX50-011, which can now reuse
  `RailCarrier`), M3, M4, M5. **M2's completion stays gated on the acquisition
  contract (§5) as approved** — M2-mech proves the experience and nothing about
  progression.
