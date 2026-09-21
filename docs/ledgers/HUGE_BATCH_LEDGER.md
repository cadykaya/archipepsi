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
- **Preserved review snapshot:** `206167e`, on the remote branch
  **`review/0.4-m2mech-snapshot`**, which will not be advanced. That is the head
  the M2-mech railway was reviewed at: the whole first loop playable, the suite
  walking it with nothing placed (124 checks), full frontier green. **It is a
  snapshot, not a baseline** — its yard lets the base kit walk to S3 with the
  span up (F-09), which was measured and repaired afterwards. An annotated tag
  was written locally and could not be pushed: tag pushes to this remote fail
  with a transport disconnect while branch pushes succeed, so the branch is the
  durable ref.
- **Scope decisions approved:** `grapple_to_surface` featured; three-dock Blindside
  prototype; minors EX50-011 / EX50-021 / EX50-033; first-class `RailNetwork`;
  full-strength acquisition integration as M2's completion requirement.
- **Decisions still unresolved:** Forge/Static economy (B4); seed/retry policy;
  D7 return-later progression policy; old-save repair.
- **Processes running:** none.
- **Remote CI:** failing before it starts, on every commit, for want of a
  runner. See F-08. Local frontier green at `5b03ec9`.
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
| M1-hud | The scenario draws the real HUD: HP, slots, prompts, hit feedback | 0.4 scenario | M1-fight | `railway_scenario.gd` (`_hud`) | **verified** | `89dd872`+ | `main.gd` builds it the same way for a Zone; the only thing left out is the resource pool, because there is no campaign here to have one |
| M1-door | A double-click into the railway | 0.4 scenario | M1-play | `Play the Railway (Windows).bat`, `- bracing`, `_play-railway.bat`, `_find-godot.bat`, `play-railway.sh` | **implemented; the .bat files are UNTESTED** | `426532e` | there is no Windows in this container. The shell launcher was run and does find Godot and open the scenario. `_find-godot.bat` is a second copy of the finder inside `_play-3ab.bat` — a recorded debt, not a design |
| M1-access | Restored VEHICLE SERVICE and genuinely new DESTINATION ACCESS are two claims, asserted separately | owner check-in 2026-09-21 | M1-play | `railway_scenario.gd` (`_yard`, `_docks`), `rail_junction_driver.gd` | **verified** | `c347057`+ | measured before it was changed: the base kit walked 42.3 m and stood on S3 with the span up. F-09 |
| M1-recall | An island is not a trap: a player on S3 can call the skiff back with the base kit | consequence of M1-access | M1-access | `rail_junction_driver.gd` | **verified** | `c347057`+ | the direction controls are commands to the RAILWAY, not calls placed at a dock |
| SPEC-intake | The three EX50 originals recorded with provenance, digests verified after the copy | owner check-in 2026-09-21 | — | `docs/design-library/` | **verified** | `c347057` | paper proposals, REVISED_ON_PAPER; kept distinct from runtime evidence by directory |
| D6 | The second binding: `ranged_hit` on eligible bracing releasing the same span | plan §4 D6 / addendum "second binding — corrected" | M1-play | `railway_scenario.gd` (`_bracing`), `--railway --bracing` | **verified, and labelled** | `4a8cba5`+ | 124 checks. **An existing-tool objective variant, NOT a second acquisition loop** — `ranged_hit` establishes no newly acquired capability because the starting player already shoots the transport receivers. Built as an ALTERNATIVE configuration, never alongside the gantry: a yard with both would be a yard where the acquisition branch is optional |
| M1-safe | Dying in a yard with shooters in it is not a dead end | 0.4 scenario | M1-fight | `railway_scenario.gd` (`_place_player`) | **verified** | `3074c55`+ | `set_spawn`, not an assignment: the respawn transform is captured in `_ready`, so a player merely MOVED to S1 came back at the world origin |
| M1-walked | **Continuous play evidence**: the whole loop on foot, nothing placed | plan §8 ("continuous play evidence kept separate from placed-near-target, pre-unlocked, direct-handler and synthetic-state runs") | M2-mech | `rail_junction_driver.gd` (`_walked_end_to_end`) | **verified** | `88cb607`+ | 114 checks, stable over four runs. Board, shoot, ride, be refused, walk the branch, take the tool, walk back, pull up, throw the lever, ride to S3 — no teleports, every command a key |
| M1-fight | The ride is not a tram ride: three shooters on alternating sides, and cover that turns with the deck | plan §3 sequence ("one meaningful combat situation") | M1-play | `railway_scenario.gd` (`_gauntlet`, `_shield`) | **verified** | `a451876`+ | 96 checks. What is held: real enemies, alternating sides, the shield stops a shot from its side and nothing on the carrier stops one from the other, and a shot from the moving deck damages a shooter. **Whether the fight is any good is a playtest question and is not answered** |
| E-011-mech | EX50-011's two machines exist and keep their own rules: a lift with an authored intermediate dwell, a shuttle on a two-berth track at service speed, and one shared authoring of how either gets from one stop to the next | `EX50-011.md` §2, §3, §8 | SPEC-intake, P2 | `shuttle_deck.gd`, `stop_travel.gd`, `call_lever.gd`, `rail_carrier.gd` (`top_speed`/`accel`) | **verified** | this batch | `make godot-passing-platforms`, in CI. `RailCarrier` is reused for the shuttle rather than copied: a finite WEST HOLD / TRAVEL EAST / EAST HOLD / TRAVEL WEST schedule IS a two-dock railway with a fail-safe stop. The lift is a new class because a rail carrier on a vertical path stands its deck on end, and `RailPath` refuses such a path at 75° — correctly |
| E-011-room | The room is a place a person can stand: `--passing-platforms` | `EX50-011.md` §2 | E-011-mech | `passing_platforms.gd`, `main.gd` | **verified** | this batch | 28×22 m, 12 m high, arrival floor, recovery floor 3 m under the transfer plane, upper shelf, goal gallery, eleven call controls. **Development scaffolding, not a Zone**: no Checks, no exit, no campaign, no bridge |
| E-011-run | **Continuous play evidence**: from the arrival floor, board the lift, transfer to the shuttle with both machines commanded and moving, reach G | `EX50-011.md` §11 | E-011-room | `passing_platforms_driver.gd` (`_the_continuous_run`) | **verified** | this batch | nothing placed, nothing snapped, every command a keypress on a lever the body is looking at. Relative speed at the transfer 1.50 m/s; the step was taken 4.98 s after the launch lever. The three deck railings are counted before and after and are untouched |
| E-011-counter | §11's counterpart: the same commanded timing in a room whose tracks do not pass must NOT be reported successful | `EX50-011.md` §11 | E-011-run | `passing_platforms.gd` (`parted`), `--passing-platforms --parted` | **verified** | this batch | the one number replayed is the interval between pulling LAUNCH and stepping north. G is not reached, no stair is released, and the body ends on the recovery floor. **The walks are not replayed frame-by-frame and that is stated in the suite**: a body arriving at a lever one frame later would fire its interact into the air and fail for a reason unrelated to whether the tracks pass |
| E-011-patient | §6/§10's lowest-pressure solution is BUILT, not prose: stop the shuttle near the transfer from a control at the arrival floor, ride the lift, board it standing, restart it from its own onboard lever | `EX50-011.md` §6, §10 | E-011-room | `passing_platforms.gd` (`STOP H`, `H ON EAST`), driver (`_the_low_pressure_route`) | **verified** | this batch | walked end to end. §10 says that if no accessible control permits the sequence the paper alternative is false and must be removed or built; it is built |
| E-011-measure | §10's five measurements: world-space overlap duration, relative velocity at the transfer, railing collision, the landing, and recovery-floor coverage | `EX50-011.md` §10 | E-011-room | driver (`_the_overlap_is_measured`, `_the_railings_and_the_floor`, `_the_decks_never_touch`) | **verified** | this batch | overlap 2.17 / 2.68 / 1.75 s for a 1 / 2 / 3 s board-and-launch; the parted room reports 0.00 s, which is the instrument's own counterexample. The decks never intersect at ANY pair of positions (1681 sampled), because they never share a `z` — a property of the geometry, not of today's schedule |
| E-011-fall | §8's "the actual maximum fall height and damage must be verified" | `EX50-011.md` §8 | E-011-room | driver (`_the_fall_is_measured`) | **verified, and the answer is not the paper's** | this batch | 2.89 m onto the recovery floor, 0 HP. F-12: this runtime applies no fall damage at any height |
| E-011-save | §9: carrier poses, destinations and hold states restored before the player; a dwell not replayed against elapsed real time | `EX50-011.md` §9 | **D-6 (Dess)** | — | **not started — blocked** | — | there is no 0.4 save representation, no campaign under this scenario and nothing that could restore a carrier pose. Recorded as paper rather than covered by a test that would only re-read the specification back to itself |
| E-011-gates | §8's boarding gates and interlocks | `EX50-011.md` §8 | E-011-room | — | **not started** | — | the shelf's lift opening is open whenever the lift is away: an 8.0 m drop onto the arrival floor, survivable because there is no fall damage (F-12). §10 asks for a minimum scene and this is past it; it is named here rather than left for a player to find |
| E-011-enemies | §7's later encounter: gunners on fixed galleries so moving with the shuttle changes cover and angle | `EX50-011.md` §7 | E-011-room | — | **not started, by the specification** | — | "The first prototype has no enemies" |
| E-021 | EX50-021 Counterfire Arcade | `EX50-021.md` | SPEC-intake | — | **not started** | — | next in the approved minor group |
| E-021-input | §12's "critical unsupported dependency": a real hostile projectile operates a machine input, with the same pulse a player's shot produces, one impact counted once, and nothing else in the game changed | `EX50-021.md` §3, §10, §12 | SPEC-intake | `damageable.gd` (`HOSTILE_INPUT`), `enemy.gd` (`EnemyProjectile`, `fire_at`), `impact_receiver.gd` | **verified** | this batch | `make godot-counterfire`, in CI. Before this batch the answer was NO — see F-14. The extension is an **opt-in group**: a shot element that has not declared it is damageable, is hit by every player weapon, and is untouched by hostile fire, which the suite asserts directly |
| E-021-hood | §3's "physical directionality, not an owner-ID exception": the arrival side is hooded in steel and the lane side is not | `EX50-021.md` §3 | E-021-input | `impact_receiver.gd` (`_build_hood`) | **verified** | this batch | asked with the real Static Pulse from two real standing positions, so the geometry is what is tested rather than a branch |
| E-021-room | The room is a place a person can stand: `--counterfire` | `EX50-021.md` §2 | E-021-input | `counterfire_arcade.gd`, `main.gd` | **verified** | this batch | 24×18 m, one gunner, one receiver, two approaches, a timed shutter and an annex. **Development scaffolding, not a Zone** |
| E-021-bait | **Continuous play evidence**: the gunner commits a shot at a standing player, the player steps into the alcove, and the projectile carries on into the vacated stance and trips the receiver | `EX50-021.md` §11 | E-021-room | `counterfire_driver.gd` (`_the_committed_shot`) | **verified** | this batch | nothing knows the enemy is about to fire; the dodge is a keypress made on seeing the projectile exist. Measured: 0.88 s of flight, 0.43 s to cross into cover |
| E-021-counter | §11's counterpart: a real blocker between muzzle and receiver, and the shutter must not open | `EX50-021.md` §11 | E-021-bait | `--counterfire --blocked` | **verified** | this batch | the blocker is SOUTH of the stance on purpose: one north of it would also break the gunner's line of sight, and a counterpart that fails because no shot was fired is a weaker claim |
| E-021-fallback | §6/§11: killing the gunner before any hit still leaves the route completable | `EX50-021.md` §6, §11 | E-021-room | `counterfire_driver.gd` (`_the_fallback_route`) | **verified** | this batch | walked end to end with the gunner dead: up the lane, an ordinary Static Pulse on the plate, through the shutter inside its interval (5.4 s to spare), up to the flank, the manual release, the goal |
| E-021-interlock | §8: "A player already in the doorway is not crushed" | `EX50-021.md` §8 | E-021-room | `service_shutter.gd` | **verified** | this batch | the doorway is a real volume, not a distance check; the shutter waits, reports how long it has waited, and shuts the moment it is clear |
| E-021-persist | §9: the release is persistent and the timer is not | `EX50-021.md` §9 | E-021-room | `counterfire_arcade.gd` (`_on_release`) | **verified, within a run** | this batch | held open across two and a half intervals with nothing shot again. **Across a save it is untested**, for the same reason as `E-011-save`: there is nothing to save to |
| E-021-fair | §11/§12: whether the bait is actually fair | `EX50-021.md` §11, §12 | E-021-bait | — | **not answered, and cannot be by a test** | — | "The actual fairness of the bait remains unverified and must be tested before this room can be considered more than a coherent proposal." The margin is reported as a number. A number is not a playtest |
| E-021-save | §9: saving after the shutter opens but before the release must restore a safe position | `EX50-021.md` §9 | **D-6 (Dess)** | — | **not started — blocked** | — | no 0.4 save representation |
| E-033 | EX50-033 Unweighted Switch | `EX50-033.md` | SPEC-intake | — | **not started** | — | its sensor is a semantic mass-class / LIGHTENED interaction, NOT a summed-kilogram plate. Which of the two the engine has is an open question this ledger must answer before the row moves |

## ~~Not in the repository, and needed before M3 content~~ — SUPERSEDED

**Superseded by SPEC-intake (`c347057`).** The three EX50 originals were
recovered and are in the repository byte-for-byte under
`docs/design-library/EX50_entries/`, with their digests verified after the copy.
The block this section recorded is lifted. Kept as a row rather than deleted so
the reason the minor group started late stays legible.

**They are paper.** All three are `REVISED_ON_PAPER` and carry
`Implementation evidence: none`. Their numbers — speeds, dwells, distances — are
proposals, and a proposal that has been built is still a proposal about how the
result FEELS. That distinction is why `docs/design-library/README.md` exists and
why the rows above separate what was measured from what the paper says.

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

### F-08 — remote CI never started, on every commit including a docs-only one

- **Observation:** both workflows ("PR gate", "Integration") complete in three to
  five seconds with `conclusion: failure`, `runner_id: 0` and an empty
  `runner_name`. Log download returns 404 because no job ever produced one.
  **Every run on this branch, on every commit** — including `a451876`, which
  changed one Markdown file and nothing else.
- **Ruled out as this PR's**, as the batch's own rule requires: a docs-only
  commit cannot fail the Python suite in three seconds, and the one permitted
  re-run (attempt 2 of `35572321067`) was over in five.
- **Cause:** runner allocation at the account level — minutes, billing, or an
  Actions policy. **There is no fix to port into this branch**, and this lane
  does not touch billing or account settings.
- **Reported once**, on PR #12, per the rule: the failing checks named, the
  reason they are not this PR's, and the local verification that stands in for
  them. Not re-run again.
- **The owner's standing constraint is the right frame:** *do not treat remote
  CI infrastructure failure as gameplay evidence.* The frontier was run here
  instead, on a fixed tree, and its result is the one this batch stands on.

### F-09 — the yard's conveniences were standing in for the progression design

- **The question, from the owner:** `_yard` built one continuous collidable slab
  and `_docks` put a flight of steps at every dock, S3 included. Could the base
  kit simply walk to S3 without commissioning the span?
- **Measured before anything was changed: YES.** With the span up and nothing in
  the mobility slot, a walked route round the outside of the track — 42.3 m,
  no teleports — ended standing on S3's platform at `y = 1.00`.
- **What that meant:** the commissioned link was restoring **vehicle service**
  and nothing more, while the scenario read as though it opened a destination.
  Both conveniences came from assembling the place, and neither was ever
  measured, which is exactly how a test-yard shortcut becomes the design.
- **Change:** the yard floor is now four slabs around a hole, S3 stands on an
  island inside it, and a dock over the hole gets no steps — *"a flight of
  stairs rising out of a void is a bridge"*. The branch was moved to the S1 side
  of S2 so its walkway does not end over the hole.
- **Both claims are now asserted separately, in one case, so neither can stand
  in for the other:**

  | claim | measurement |
  |---|---|
  | destination access is gated | the walk ends in the hole at `y = -25.03`; the narrowest gap round S3 is 6.0 m; a run-up and a jump from the far rim also ends in the hole |
  | vehicle service is what the repair restores | same yard, span home, carrier crosses to S3 in 10.9 s |

- **And the island is not a trap** (M1-recall): step off, send the skiff away,
  and one Static Pulse at S3's forward chevron brings it back, because the
  direction controls are commands to the railway rather than calls placed at a
  dock.
- **Still not a progression claim.** This is dev scaffolding. Nothing here
  establishes an AP guarantee, a capability gate, or anything about a composed
  Zone; it establishes that the scenario now shows what it is meant to show.

### F-10 — the recovery floor had two strips of nothing in it

EX50-011 §2 is explicit: a missed transfer is "a short fall and repositioning,
not automatic death into a bottomless void." The room was built to satisfy that
— an arrival floor across the south of the chamber and a recovery floor a metre
above it covering everything north — and it did not.

The first cut stopped the recovery floor at `x = -11` and `x = 12`, numbers
chosen to clear the west shelf and the east gallery and never checked against
anything. That left two strips about three metres wide running the full depth
of the room with **no floor under them at all**. A body over there falls past
`FALL_KILL_Y` and dies.

**Nothing walked found it.** The continuous run, the counterpart and the patient
route all pass with the hole in the room, because none of them goes near the
walls. What found it was the census §10 asks for — a downward ray from every
point of a grid over the transfer level, asserting a floor under each — and it
reported eleven points with nothing beneath them before anyone had an opinion
about where the floor ought to reach. The fix is one line: the recovery floor
goes to the walls.

The general lesson is the one F-09 already paid for in the yard. A room is not
proved safe by the routes somebody thought to walk.

### F-11 — a duplicate node name is thrown away, not made readable

The suite counts the railings that ride on the two decks before and after the
continuous run, because §11 says the positive test "must not snap the player
onto H or disable its railing to pass" and a count is how that is checked. It
reported **two railings, and there are three.**

`Node.add_child` does not rename a colliding sibling to something readable
unless it is asked to (`force_readable_name`). It assigns a fast unique name
instead — `@StaticBody3D@93` — and the name the builder set is simply gone. Both
of the shuttle's railings were constructed as `"Railing"`, so the second one
lost its name, and a census that searched for railings by name found two.

Two repairs, and the second is the one that matters. The railings are now named
apart (`RailingEast`, `RailingNorth`, `RailingWest`), and the census no longer
searches the room by name at all: it reads the decks' own children. **A count of
parts should be taken from the thing that owns them.**

### F-12 — §8's fall question has an answer the paper did not anticipate

EX50-011 §8: "Missing H lands the player on the recovery floor. The actual
maximum fall height and damage must be verified. A shallow visual void cannot
secretly be a kill volume copied from another room type."

Measured, with a body walked off the lift's edge at the transfer plane:
**2.89 m, and 0 HP.** Not because the fall is short — because **this runtime
applies no fall damage at any height.** The only fatal fall is past
`FALL_KILL_Y = -30`, thirty metres below the arrival floor.

So the paper's worry is answered, and for the opposite reason to the one it
expects: nothing secretly kills, because nothing kills. What the recovery floor
costs a player is time and position, and the room's "make a decision, see it
fail, try a better one quickly" (§7) is therefore true today — but it is true by
an engine-wide default and not by anything this room does. **If fall damage is
ever introduced, this room's §8 claim has to be re-measured, not assumed.** It
is recorded here so that day has a starting point.

The related open item is E-011-gates: the shelf's lift opening is unrailed when
the lift is away, an 8.0 m drop, and §8's "doors or boarding gates use their
real safe interlocks" is not built.

### F-13 — an instrument error: a still deck slides against nothing

Caught before it was reported, and recorded because the ledger's value is in
distinguishing a broken game from a broken measurement.

"Is the player standing on this machine?" was first answered from
`get_slide_collision`, which is the right handle for a body that has just been
carried: the plan names it directly. It is the wrong handle for a body resting
on a **stationary** deck with no input. That frame can finish having slid
against nothing, the collision list comes back empty, and the instrument says
the player is not aboard — while `is_on_floor()` is true and the deck is right
under their feet.

It surfaced as a single failure in the patient route, which is precisely the
case where the shuttle is standing still, and for about a minute it looked like
a gameplay defect in the alternative §10 demands be built. The answer is to fall
back to a short downward ray and read what is actually under the feet. Both
handles are kept: the slide collision is the cheap answer when there is one.


### F-14 — two things about the runtime EX50-021 told me not to assume

§3 is blunt: "Existing player-only target filters must not be assumed to
support this." §12 names the dependency as the room's critical unsupported
one. Both were read rather than assumed, and both answers matter.

**A hostile projectile could not operate anything.** `EnemyProjectile` handed
`take_damage` to a body in group `"player"` and to nothing else; anything else
it touched simply stopped it and the projectile freed itself. So the whole
premise of the room — an enemy's committed shot as the input to a machine —
was absent, exactly as the paper feared.

The extension is deliberately the smallest one that works, because the obvious
one is wrong. Letting an enemy projectile call `Damageable.hit` on whatever it
touches is not a bounded extension; it is a change to what every damageable
node in the game means, and the first casualty would be `BreakablePanel` — a
gunner would open the affordance whose capability the player is charged for,
which is the same failure that class shipped with once for the opposite
reason. So a machine **opts in**, one node at a time, through
`Damageable.HOSTILE_INPUT`, and the suite asserts that an ordinary shot element
— damageable, hit by every player weapon — is untouched by hostile fire.

**And the ranged archetype has no windup.** `_say("shot")` plays a tone at the
instant of firing; only the brute telegraphs (`_windup`). So the projectile
itself is the entire warning, and the numbers are: **0.88 s** from muzzle to
stance at 14 m/s over 12.3 m, against **0.43 s** for the measured step into
cover. Whatever is left is reaction time.

That is not a verdict. §12 says "The actual fairness of the bait remains
unverified and must be tested before this room can be considered more than a
coherent proposal", and reporting a margin is not testing it. What is recorded
here is the margin, so that a playtest has something to disagree with.

One thing the runtime already had right, by accident rather than by
arrangement: the ranged archetype's `speed` is `0.0`, so the gunner holds its
gallery instead of walking down the lane. §7 wants exactly that — "Its position
and line of fire explain its presence before the player arrives."


## Full scope and status

Every workstream in the plan, including what has not been started. **A Dess
dependency blocks the row that names it and nothing else** — the campaign does
not stop at the first blocked row.

| ID | Workstream / milestone | State | Blocked by | Note |
|---|---|---|---|---|
| **A1** | 0.3 cleanup: shot-target orientation repaired, `godot-target-facing` promoted to a gate | **partly done** — repaired at `f4953c1`, **not in CI** | — | the driver exists and is not in `integration.yml`; promoting it is a one-line change and is not done |
| **A2** | Climbing-producer door records (`tower`, `platform_path` file `exit` past the wall the hole is cut in) | **not started** | — | bounded repair; scoped carefully because `door_world` feeds join sockets and lock slabs |
| **A3** | Finish-path coverage | **not started** | — | |
| **A4** | Stop tracking disposable test saves; launch hygiene | **not started** | — | |
| **B1** | Amalgam: one shared effect path | **not started** | — | |
| **B2** | Amalgam: usable builds | **not started** | — | |
| **B3** | Status/physics subsets (13 Statuses in 4 families, 8 compounds) | **not started** | — | |
| **B4** | Forge/Static economy | **not started — decision pending** | owner | plan §6 decision 6: only accepted recipes/costs/outputs; new economy rules stay a decision |
| **B5** | Independent Amalgam breadth after M3 | **not started** | M3 | |
| **C1** | Environmental objectives: reuse `ActivityElement` sensors | **done, in use** | — | the goal plate at `G` is exactly this; `RailReceiver` is the shot case |
| **C2** | A signal-driven actuator generalised from `PoweredLink` | **not started** | — | `RailSpan`/`AlignmentControl` and `ShuttleDeck`/`CallLever` are two concrete chains; the generalisation is not built |
| **C3** | Objective semantics (§5.4a) | **settled, implemented** | — | accepted consequences persist, live values do not. M1 is the worked example |
| **C4** | Reset / interruption / tool loss | **partly done** | — | EX50-011's reset is built and measured (E-011-*, §8). Tool loss is not |
| **C5** | Readable cause and effect from the existing vocabulary | **partly done** | — | signs, chevrons, lever labels, deck railings. Whether any of it reads is a playtest question |
| **C6** | Bounded objective-binding schema so Epsilon selects relationships | **not started** | **D-5 (Dess)** | |
| **D1–D5** | Blindside major, first section | **verified as M1 + M2-mech** | — | see the rows above |
| **D6** | Second binding (`ranged_hit` on bracing) | **verified, and labelled an existing-tool variant** | — | not a second acquisition loop |
| **D7** | Return-later variant | **deferred, tracked** | all-Checks exit policy (owner) | plan §6 decision 5; no silent change to the completion rule |
| **E-011** | Passing Platforms | **verified** except `E-011-save` / `E-011-gates` | D-6 for save only | see the rows above |
| **E-021** | Counterfire Arcade | **verified** except `E-021-save` and `E-021-fair` | D-6 for save only | see the rows above. Fairness is not a thing a test can answer |
| **E-033** | Unweighted Switch | **not started** | — | open question: semantic mass-class sensor vs summed-kilogram plate |
| **F** | Progression / Epsilon / AP engine half | **not started** | **D-1, D-2 (Dess)** | the `established_in_zone` producer's client half |
| **G1** | 0.4 save representation | **not started** | **D-6 (Dess)** | |
| **G2** | Legacy migration | **deliberately not done** | owner | no old campaign is touched |
| **G3** | Interruption | **not started** | — | |
| **G4** | Two unmistakable launch modes, separate saves, printed revision | **partly done** | — | the 0.4 scenarios launch by name and by double-click; the printed revision/provider/scale banner is not done |
| **M0** | 0.4 line exists, 0.3 untouched | **verified** | — | |
| **M1** | One real machine chain | **verified** | — | `M1-zone` (a junction inside a composed Zone) stays blocked on **D-4** |
| **M2-mech** | Dev-scenario loop, labelled | **verified** | — | |
| **M3** | First content group | **2 of 3** | — | EX50-011 and EX50-021 done; 033 not started. **Genuine Epsilon objective selection stays incomplete until D-5** and a handwritten configuration will not be reported as it |
| **M2 complete** | The intended experience, multiworld-safe | **blocked** | **D-1 (Dess)**, §5's five requirements | |
| **M4** | Remaining Amalgam breadth | **not started** | M3 | |
| **M5** | Pinned review build | **not started** | M3 | |

### Where a Dess handoff actually blocks something

| Handoff | Blocks | Does NOT block |
|---|---|---|
| D-1 acquisition contract | **M2's completion** | everything else in this table |
| D-2 `established_in_zone` producer | M2 complete, F | — |
| D-3 `DoorAssignment.requires` | capability gates | — |
| D-4 `RailNetwork` schema | `M1-zone` only | P0–P4, M1, M2-mech, M3, E-011 |
| D-5 objective-binding vocabulary | C6, and any claim of **genuine** Epsilon objective selection | building and testing provisional configurations |
| D-6 0.4 save representation | G1, `E-011-save` | E-011's other rows |

## Full-Amalgam matrix

*(built incrementally per plan §4 — never a prerequisite to starting)*

## Evidence classes, kept apart

The plan asks that continuous play evidence not be blended with the other
kinds. In `godot-rail-junction`:

| case | class | what it is |
|---|---|---|
| `_walked_end_to_end` | **continuous play** | nothing is placed; every metre is walked, ridden or pulled and every command is a key. One stated simplification: the shooters are removed, because this case measures the ROUTE and the fight has its own case |
| `_the_grapple_opens_the_gantry` | **placed-near-target** | the body is moved between the junction and the branch so each beat can be measured on its own |
| `_fighting_from_the_deck` | placed-near-target | the body is stood on the deck to measure the firing line and the shield |
| `_re_entry`, `_nothing_was_accepted`, `_another_packages_latch` | **synthetic state** | a junction is restored from a latch set handed to it directly |
| `_reported_once` | **direct handler** | `ZoneController.report_latch` is called, not reached through a machine |

And in `godot-passing-platforms`:

| case | class | what it is |
|---|---|---|
| `_the_continuous_run` | **continuous play** | nothing placed, nothing snapped. Walk to the call lever, pull it, walk onto the lift, pull LAUNCH, ride, step north, be carried east, walk off at G. Every command is a keypress on a lever the body is looking at, and the three deck railings are counted before and after |
| `_the_low_pressure_route` | **continuous play** | the same, by §6's patient alternative: STOP the shuttle from the arrival floor, ride up to it, board it standing, restart it from its own deck |
| the `--parted` counterpart | **continuous play, negative** | the same commanded timing — the interval between LAUNCH and the step — in a room whose tracks do not pass. **The walks are not replayed frame-by-frame**, and the suite says so where it does it |
| `_the_fall_is_measured` | **placed-near-target** | the body is stood on the lift at the transfer plane and walked off the edge, to measure the consequence of a miss rather than whether a person would make one |
| `_the_railings_and_the_floor` | **placed-near-target** | both machines are put at the rendezvous and the question is asked of rays |
| `_the_overlap_is_measured`, `_the_decks_never_touch`, `_the_dwell_is_declared`, `_no_queued_arrivals`, `_a_stop_is_not_undone_by_an_old_command`, `_reset_never_teleports` | **machine arithmetic** | `advance(STEP)` with no body in the room. A hand-stepped overlap is not evidence that a person can make the transfer; it says how long the opportunity lasts |

And in `godot-counterfire`:

| case | class | what it is |
|---|---|---|
| `_the_committed_shot` | **continuous play** | the real gunner with its real cooldown and its real line-of-sight test; the player walks into the lane and starts moving the instant a projectile exists, which is the only cue a human gets |
| the `--blocked` counterpart | **continuous play, negative** | the same bait with steel across the lane south of the stance |
| `_the_fallback_route` | **continuous play** | gunner dead, then every metre walked: up the lane, a real Static Pulse on the plate, through the shutter inside its interval, up to the flank, the release, the goal |
| `_the_hood_is_steel` | **placed-near-target** | the body is stood on each side of the receiver in turn and fires the real weapon |
| `_the_primitive`, `_the_extension_is_bounded`, `_cover_intercepts` | **synthetic** | a receiver on a bare stage and a projectile fired by a gunner built for the purpose. It answers whether the two hit paths arrive at the same place, which is a question about the code |
| `_the_interlock`, `_the_release_is_permanent` | **synthetic state** | the shutter is tripped and the release accepted directly, to measure what the interval does and does not control |

## Playable milestones

| Milestone | Build/ref | Launch/mode/save | Actual continuous player path | Test shortcuts | Owner verdict |
|---|---|---|---|---|---|
| 0.3 candidate | `19c5d8e` | production mode | exit/hold patch unplayed by owner | — | not yet played |
| M3, EX50-021 Counterfire Arcade | this batch | `godot --path godot -- --counterfire`, or "Play Counterfire Arcade (Windows).bat" / `./play-counterfire.sh` | stand in the painted lane where the gunner can see you; when it shoots, step west into the alcove and the shot carries on into the impact trip behind you, opening the service shutter for eight seconds; run the service route, pull the release and reach the goal. Or take the west stair, kill the gunner, and operate the trip yourself from the lane side | **the whole scenario is a test shortcut**: not a Zone, no campaign, no bridge, no Checks, no exit, no save. `--blocked` is the counterpart and its bait cannot work | not yet played |
| M3, EX50-011 Passing Platforms | this batch | `godot --path godot -- --passing-platforms`, or "Play Passing Platforms (Windows).bat" / `./play-passing-platforms.sh` | pull H EAST at the arrival floor, walk onto the lift, pull LAUNCH on its own deck, ride up; when the lift holds at the transfer plane and the shuttle's deck is under you, step north onto it; be carried east; walk off onto the goal gallery and the service stair opens. Or pull STOP H when it is beside the lift and take as long as you like | **the whole scenario is a test shortcut**: not a Zone, no campaign, no bridge, no Checks, no exit. No save, so nothing in §9 is exercised. `--parted` is the counterexample and is meant to be uncompletable | not yet played |
| M1 + M2-mech, the railway | `f9f51e9`+ | `godot --path godot -- --railway` (or `godot-bin/godot --path godot -- --railway`) | board at S1, shoot the chevron pointing down the track, ride; S2→S3 is refused; the gantry that lowers the span is overhead and out of reach; walk the branch past it, take the hookshot, try it on the ledge, come back, pull yourself to the ring, press E on the lever, ride to S3 | **the whole scenario is a test shortcut**: not a Zone, no campaign, no bridge, no Checks, no exit, and the Echo is granted by a pedestal rather than by a Check | not yet played |

## Checkpoint

- **Last completed milestone:** **two of the three approved minors.** EX50-011
  Passing Platforms (`make godot-passing-platforms`, 63 checks, 7 notes) and
  EX50-021 Counterfire Arcade (`make godot-counterfire`, 44 checks, 2 notes),
  both in CI, both verified against the bars their own specifications set.
- **Preserved review snapshot:** `review/0.4-m2mech-snapshot` at `206167e` —
  the playable M2-mech checkpoint, kept available and untouched.
- **Shared code touched, and re-verified:** `RailCarrier` gained per-carrier
  `top_speed`/`accel`; `Enemy` gained `muzzle()`/`fire_at()` and an
  `EnemyProjectile` that can deliver to a declared hostile input;
  `Damageable` gained the `HOSTILE_INPUT` opt-in. The full frontier is re-run
  on a frozen tree before any of this is called green.
- **Five findings this batch:** F-10 the recovery floor had two strips of
  nothing in it, found by the coverage census and by nothing walked; F-11 a
  duplicate node name is thrown away rather than made readable; F-12 this
  runtime applies no fall damage at any height; F-13 an instrument error — a
  body resting on a stationary deck can slide against nothing; F-14 a hostile
  projectile could not operate any machine at all, and the ranged archetype
  has no windup.
- **Exact next action:** EX50-033 Unweighted Switch, the last of the three.
  It carries an open question this ledger must answer before it is built — its
  sensor is a semantic mass-class / LIGHTENED interaction, not a
  summed-kilogram plate, and which of the two the engine has is not yet
  established.
- **Still blocked, and only where named:** M2's completion on D-1; `M1-zone`
  on D-4; `E-011-save`, `E-021-save` and G1 on D-6; genuine Epsilon objective
  selection on D-5. Nothing else in the scope table waits on a lane that has
  not accepted a handoff.
- **Two things no test will answer**, and they are named rather than quietly
  claimed: whether EX50-021's bait is fair (§12 says so itself), and whether
  any of this is fun. Both are playtest questions.
- **Scheduled work is off.** No heartbeat, no watchers, no subscriptions.
