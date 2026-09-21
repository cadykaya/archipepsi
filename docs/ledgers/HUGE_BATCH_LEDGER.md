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

## Full-Amalgam matrix

*(built incrementally per plan §4 — never a prerequisite to starting)*

## Playable milestones

| Milestone | Build/ref | Launch/mode/save | Actual continuous player path | Test shortcuts | Owner verdict |
|---|---|---|---|---|---|
| 0.3 candidate | `19c5d8e` | production mode | exit/hold patch unplayed by owner | — | not yet played |

## Checkpoint

- **Last completed milestone:** M0. P0, P2, P2b and P3 verified.
- **Current coherent tree:** `claude/archipepsi-0-4-blindside`; `godot-rail-carrier`,
  `godot-passenger-carry`, `godot-affordance`, `godot-movement`, `godot-physics`,
  `godot-traverse`, `godot-content` and `godot-activity` green.
- **Deliberate reordering (decided by this lane, owner asleep):** P2/P3 were taken
  before P1. P0 delivered P1's stated de-risk value directly — the carry is
  measured — and Passing Platforms wants exactly a carrier that stops at points,
  so building the vehicle first means the minor reuses `RailCarrier` instead of
  duplicating it.
- **Exact next action:** P4/M1 — the first persistent machine chain (a
  player-performed setter interaction fires `latch_fired`; the link's commissioned
  state is recomputed from the latch at build time, never separately saved).
