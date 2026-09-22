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
| Bridge / design (D-1..D-7) | Dess | **accepted 2026-09-21** | F-16 is decided (owner: model **B2**) and D-7 is no longer blocked: `SUPPORTED_STATUS_TARGETS` is the per-kind-per-target declaration, exported to the engine as `ECHO_STATUS_SUPPORTED_TARGETS` (`c0d5446`), and the Godot application boundary refuses the PAIR. `lightened` has crossed on `object` only. RailNetwork landed at `704f379`. See F-21 on collapsing the duplicate export |
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
| M1-zone | A junction inside a real composed Zone | plan §6 decision 3 | D-4 (Dess), delivered `704f379` | `rail_networks.gd`, `zone_controller.gd`, `rail_zone_driver.gd` | **verified** | this batch | `make godot-rail-zone`, 23 checks, in CI. `ZoneController` reads `Zone.rail_networks` and builds a real `RailJunction` across the composed rooms: docks at the declared rooms' arrivals, a `RailPath` through them, a span per declaration carrying its own `latch_id`, and an `AlignmentControl` in the room `control_room_id` names. A null control means the span ships commissioned, per the schema. Latches go out through the existing `report_latch`, and a Zone rebuilt knowing the latch comes up commissioned — §5.4a recomputed, never a saved span. **Not yet played**: nothing composes a Zone that declares a railway, so this is the build-and-certify half, not a route a player has ridden |
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
| E-033-answer | **The open question, answered.** The engine had NEITHER vocabulary as a gameplay concept: `mass_kg` is a number on `ManipulableBody`, `PoweredLink` sums it, and no mass CLASS existed anywhere | `EX50-033.md` §3, ledger's own open question | SPEC-intake | `mass_class.gd` | **verified** | this batch | the class ladder and its thresholds are transcribed from `docs/design-proposals/02_PHYSICS_IS_THE_GAME.md` §10.2, which pins them; nothing is chosen here |
| E-033-sensor | A plate that reads mass CLASS and never sums: §8's "Optional debris cannot accumulate into HEAVY on this semantic plate" | `EX50-033.md` §3, §8 | E-033-answer | `class_plate.gd` | **verified** | this batch | `make godot-mass-class`, in CI. 300 kg of MEDIUM debris does not make a HEAVY plate, while the same mass holds a 120 kg summed threshold. The player is excluded by name, per §3 |
| E-033-control | §10's **decisive negative control**: the class plate against a summed-kilogram sensor, same crate, same kilograms | `EX50-033.md` §10 | E-033-sensor | `mass_class_driver.gd` | **verified** | this batch | the summed sensor is not written for the occasion — it is `PoweredLink`, the one that already ships. Class HEAVY→MEDIUM releases the class plate; the summed sensor reads 200 kg before and after. **And the converse**: 50 kg off the crate moves the summed reading and not the class, which is §6's "A mass-field ability that changes kilograms without changing the plate's semantic class may not release the plate" |
| E-033-step | §10's "verify that the same object remains collidable while the plate's output changes" | `EX50-033.md` §10 | E-033-control | `mass_class_driver.gd` | **verified** | this batch | a body dropped on the lightened crate comes to rest on its top, and the crate has not moved, shrunk or fallen |
| E-033-status | The `lightened` Status itself | `EX50-033.md` §3, Design 5 §15.2 | D-7 (Dess) | `manipulable_body.gd`, `status_effects.gd`, `echo.py` | **verified** | this batch | F-15 is answered and F-18 is closed. `ManipulableBody` carries a real `StatusEffects` whose target kind is `object`; `lightened: ("object",)` is declared in `SUPPORTED_STATUS_TARGETS` in the same change that landed the effects, per that table's own rule. `shift_class_provisionally` is gone. All four approved effects: class down one step, incoming impulse x2.0 (a continuous force deliberately unscaled), influence volumes reaching it, manipulation eligibility reading the class |
| E-033-room | The room: recess, sill, guide track, service drive, far bolt, return stair | `EX50-033.md` §2, §4, §5 | E-033-status | `unweighted_switch.gd`, `unweighted_driver.gd` | **verified** | this batch | `make godot-unweighted`, 61 checks, in CI. Sill 1.9 m: above a baseline jump from the floor (apex 1.333 m) and 0.433 m inside one from the 1.0 m crate top. Exercised through a real expiry: class returns, plate re-satisfies with nothing having moved, shutter shuts, and the bolt outlasts it. `--disconnected` is §11's control and shows the expected response failing. The route is walked end to end. **A playable development scenario** — its interlocks, campaign integration and save requirements are NOT discharged by this row |

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

**ID scheme, from 2026-09-22 (owner instruction).** New findings take a
**lane prefix**: `P-n` for engine/integration, **`DESS-nn`** for
bridge/design. The bridge lane is not `D-n` because **`D-1`..`D-8` is
already the handoff series** and one spelling meaning two things is the
failure this change exists to stop. Existing `F-nn` entries keep their
numbers. Full adoption note: *Finding IDs from here*, below.

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


### F-15 — `lightened` is not in the engine, and adding it is not a one-liner

EX50-033's whole mechanic is one Status: `lightened` drops an object's mass
class one step while leaving its kilograms, its collision and its shape alone.
The accepted design has it — `docs/design-proposals/05_STATUS_AS_GRAMMAR.md`
§15.2 gives it 8.0 s, magnitude 0.40, targets actor/object/player, and the
effect "`mass_class` drops one step; incoming impulse ×2.0; wind and conveyors
now affect it; becomes Physics-eligible if it was `HEAVY`".

**The engine does not.** `Constants.ECHO_STATUS_KINDS` has twelve kinds and
`lightened` is not one of them; `StatusEffects.apply` refuses anything outside
that list by design. And the list is a GENERATED artifact — `constants.gd`'s
own header says so — produced by `schemas/export.py` from the bridge schema's
closed `StatusKind`. So the change is a shared-schema change, in the same
category as D-3 and D-4, which this lane has consistently declined to make
alone.

**More to the point, it is not a one-line change even with permission.**
`StatusEffects.apply`'s own comment explains why: an unknown kind "was the worst
of both worlds — inert, because nothing reads it, yet still satisfying
`status_active` conditions and `status_applied` edges". A kind the schema admits
and no system implements is exactly that failure, and `lightened`'s specified
effect spans impulse response, wind, conveyors and Physics eligibility as well
as class. Adding the name without the effect would let Epsilon emit it into a
real campaign where it does nothing. That work is `B3`, it has a real blast
radius, and it is raised as **D-7** rather than taken.

**What was done instead.** The property distinction — which is what EX50-033 is
actually about — was built and measured without the Status: `MassClass`
transcribes §10.2's pinned ladder, `ClassPlate` reads class and never sums, and
the class is lowered by `ManipulableBody.shift_class_provisionally`, a
room-local shift with the Status's exact shape and a name that cannot be
mistaken for it. §10's decisive control then compares that plate against
`PoweredLink`, the summed-kilogram sensor that already ships, and the two
disagree in both directions: class moves and kilograms do not; kilograms move
and class does not.

That substitution does not weaken what those cases claim, because the claim is
about what the two SENSORS do when a class moves — true whatever moved it. It
does mean **the room is not built**, and the ledger says so rather than shipping
a playable scene whose central mechanic is a stand-in.


### F-16 — `lightened` is blocked by a vocabulary choice, not a missing name

**Dess, 2026-09-21.** F-15 is right that adding `lightened` is not a
one-liner. The reason underneath is larger: there are **two status
vocabularies in the accepted lineage and they share one word**.

| | source | the twelve |
|---|---|---|
| A — implemented | `ECHOES.md` → `echo.StatusKind` → `constants.gd` | burning, slowed, frozen, shocked, poisoned, marked, stunned, vulnerable, empowered, low_profile, haste, regenerating |
| B — designed | Design 5 §15.2, carried into Design 6 (§2787) | lightened, anchored, slippery, confused, turncoat, blinded, silenced, rooted, phased, burning, conductive, brittle |

Overlap: **`burning` only.** A is creature conditions ("on self or
enemies"); B is a property grammar over §15.1's five target kinds.

**The blocker is target scope.** `StatusComponent.target` is
`Literal["self", "enemy"]`, and EX50-033 applies a Status to a crate.
No addition to `StatusKind` makes that expressible. `lightened` needs
the kind, the widened target scope, and the runtime effect — and the
middle one is a product choice.

**Delivered without taking that choice:** NO STATUS BEFORE ITS EFFECT.
`IMPLEMENTED_STATUS_KINDS` is now separate from `STATUS_KINDS`;
`StatusComponent` refuses to emit a kind the runtime cannot honour;
`make export` sends the engine both lists. Equal today, so it refuses
nothing — its purpose is that the next name admitted cannot ship inert,
which is exactly the hole F-15 declined to open. Sabotage-proven.

**RESOLVED 2026-09-21 — owner took B2's architectural direction.** The
0.4 destination is the Amalgam Status system; object-targeted Status is
in scope. Two corrections to what this lane delivered first:

- **Thirteen, not twelve.** Amalgam §15.2 *modifies* Design 5 §15.2 —
  the twelve plus `exposed` (COGNITIVE, actor-only, Defense to 0.0, no
  crit per §0.4). The inherited twelve were not the target.
- **The gate was wrong.** `IMPLEMENTED_STATUS_KINDS = STATUS_KINDS` made
  support a consequence of being named, so each new kind admitted
  itself. Support is now declared in `SUPPORTED_STATUS_TARGETS`, per
  kind AND per target, with a one-way assertion to the vocabulary.

**All three application paths are gated**, not just `StatusComponent`:
`ApplyStatusOnHit` had a hand-written eight-kind literal (a fourth copy
of the vocabulary, kept in step with nothing — now derived, and the
derivation reproduces exactly those eight), and `Effect(apply_status)`
took a free string, so a rule could start `brunning`. 24 kinds named,
12 supported.

**Compatibility, recorded not migrated.** The ECHOES kinds stay named so
committed components still parse. One real collision: **`burning`** is in
both lists with incompatible meanings — today it deals periodic damage
(`dot_per_second()` = `4.0*burning + 2.0*poisoned`) and Amalgam §15.3
rule 1 forbids any Status dealing or scheduling Health damage, absolutely.
`burning` keeps its shipped meaning because nothing changed its runtime;
the §15.3-compliant one arrives with the engine effect, and **that change
carries the decision about existing `burning`/`poisoned` components.**
Not taken here.

**Engine-side note for Prod:** `constants.gd` now carries
`ECHO_STATUS_KINDS_IMPLEMENTED` beside `ECHO_STATUS_KINDS`.
`StatusEffects.apply` can assert against the narrower list when you want
it to; nothing requires that today, because the lists are equal.


### F-17 — two effects outlived a death, and the obvious fix would have been worse

`EchoRuntime._cancel_held_state()` clears the held state it happens to
remember — charge, burst, parry, glide, hover — and its own docstring records
that the hover was "the dangerous omission", found by a bug. Three more were
still missing, and two of them were **live defects in shipping behaviour**:

- **The tether resumed after a respawn.** `_update_swing` is polled at
  `player.gd:667`, *after* the `if _dead: return` guard at `:612`. So a player
  who died mid-swing kept `_swing_time` **frozen rather than cleared**; the
  moment `_respawn` set `_dead = false` the tether started pulling the
  respawned body toward an anchor in a part of the room they were no longer
  standing in.
- **A committed slam detonated at the respawn point.** `pending_slam` survived
  both death and respawn and paid out on the first landing afterwards.

`_launch_flight` and `_dash_window` leaked across an unequip as well.

**The obvious repair is a trap.** Having `_cancel_held_state` clear every
player-side effect would mean unequipping *one* Echo cancels effects *another*
Echo started — swapping a combat Echo would drop the tether a mobility Echo is
holding you on. Trading one defect for a worse one.

**So cleanup is shared and cancellation is not.** Each player-side effect now
records the slot that started it. `Player.end_swing(by)` / `cancel_slam(by)`
cancel only for that owner; `cancel_transient_effects()` — with no owner — is
death's call and ends everything. `_launch_flight` deliberately carries **no**
owner: a launch pad started it, no Echo owns it, and no slot change may drop a
body out of the sky.

**Three cases, and the proof they bite.** With both layers of the repair
reverted, five checks fail — including `death ends the tether (3.000 s left)`,
which is the defect verbatim. The two control cases pass in *both* states,
which is what a control is for: `_an_unrelated_swap_leaves_the_tether_alone`
and `_a_launch_arc_survives_an_unrelated_swap` assert something that was
already true and had to stay true.

A first cut of the slam case named its owner `"combat"`, which is not a slot —
`Constants.SLOT_NAMES` is `echo_a, echo_b, mobility, utility`. It passed for
the wrong reason, because no runtime's per-slot cancel could match it. Caught
by reverting the fix and finding only one failure where there should have been
several.


### F-18 — the engine half of "no status before its effect" was mine, and it was open

D-7 increment 2 admitted the destination's vocabulary: `ECHO_STATUS_KINDS`
went from **twelve names to twenty-four**, with `ECHO_STATUS_KINDS_IMPLEMENTED`
still the twelve that ship. That is correct, and it is the design's own rule —
a kind can be named, exported and reviewed while still un-emittable.

**The engine was asserting the wrong list.** `StatusEffects.apply` guarded on
`ECHO_STATUS_KINDS`, i.e. on the vocabulary rather than on support. So the
moment the twelve designed kinds were admitted,
`StatusEffects.apply("lightened", …)` **succeeded**: it stored, it satisfied
`status_active` conditions and `status_applied` edges, nothing implemented it,
and no cleanse order could remove it. That is the permanent inert
un-cleansable status the vocabulary's own comment was written about — reached
through the front door rather than through a typo.

It was measured on this tree: `godot-stats` passed while applying all
twenty-four and asserting all twenty-four were stored. **The suite was green
and demonstrating the defect.**

Not the bridge lane's error. Her commit says "no godot script was authored by
this lane", and the engine half of her rule was always Prod's: the bridge
refuses to **emit** an unsupported kind, the engine asserts it can **honour**
what it is handed. The window existed between her push and this integration.

Repaired: `apply` now refuses in two distinguishable ways — not a status at
all, versus named by the design but unimplemented. The case's claim got
**stronger**, not weaker: it was "every kind the schema admits is accepted"
and is now "every kind the runtime supports is accepted, and every kind the
vocabulary runs ahead on is refused and leaves nothing behind". With the guard
removed, twelve checks fail by name.


### F-19 — the targets had no facing rule at all, and one still has no answer

`Activities._row` writes `yaw` in **exactly one place** — the mounted branch. A
SHOT element that found no wall kept the room's default orientation, and the
floor solver that then placed it asks about *space* and never about what is in
front of the face. Twelve of twenty-seven targets in the diagnostic Zone were
unmounted; **seven faced into geometry**, two into a shell's own back wall and
three into each other.

The repair is a pass that runs when every element in the room exists, tries
sixteen facings, and rotates. **Positions do not move** — no room, no Check and
no element is relocated, and none is ever dropped.

**Four wrong turns on the way, each caught by the census rather than by
reasoning:**

1. **Per-row is the wrong level.** Inside `_row`, `taken` holds elements
   `0..i-1`, so three failures faced elements placed after them. Moving the pass
   to the end of `_row` fixed those; four remained, because a target in the
   room's *first activity* faced one in its *third*. The pass belongs to the
   room, not the row. 7 → 4.
2. **Solids read after the elements exist include the elements.** Every probe
   then hit the target's own collider and nothing turned at all. 4 → 7 again.
   The walk now prunes the element subtrees and models them from their claimed
   footprints instead.
3. **Padding the travel axis reaches backwards.** A probe padded in both
   horizontal axes extends *behind* the element into the wall it stands 0.45 m
   from, so a target refused every facing including the open ones. Padding is
   perpendicular to travel only.
4. **`occupied` is not what a shot travels through.** Refusing a facing because
   a *reservation* — a padded claim that keeps two pieces of content off each
   other — sat in front of it made this stricter than the census it exists to
   satisfy. A target with two clear metres of air kept a facing into a wall
   because a reward had booked the space. Solids and other elements' bodies are
   what a ray can hit, and that is what is asked. **4 → 1.**

**One case remains and rotation cannot solve it.** `ActivityElement_4` in
`c002`, at `-17.1, 2.2, 29.1`: sixteen facings, tried at the target's full
width and again at a sliver, and every one is blocked inside two metres. The
census agrees — its nearest blocker on the kept facing is at **1.90 m**, ten
centimetres short of `CLEAR_AHEAD`. It is boxed in, and the answer is a
placement change rather than a rotation.

**So the gate is not promoted.** `godot-target-facing` stays out of CI and
stays in `NOT_A_SUITE`, because it does not pass. Enabling a red test is not
the repair, and neither is relaxing `CLEAR_AHEAD` to 1.85 to collect a green
tick. The suite keeps measuring; the remaining case is named here.

`godot-activity`, `godot-zone-audit` and `godot-room-contract` — the three
suites sharing the Zone-1 fixture — are green, so the mount contract and the
never-drop-an-element rule survived the change.

**The placement correction, measured and proposed — 2026-09-21.** Owner
direction: "propose the smallest same-room placement correction rather than
another unbounded rotation search or a reduced clearance threshold." So the
census now carries a **bounded** proposal step, which runs only for an element
that failed: half a metre of travel in 5 cm steps, along the element's own
facing axis and the two perpendiculars, judged at the *same* `CLEAR_AHEAD`
every other target is held to, rejecting any candidate whose new origin is not
standing in open air or which leaves the room.

> `ActivityElement_4` in `c002` — **PROPOSAL: move 0.10 m back along its own
> facing**, from `(-17.10, 2.20, 29.10)` to `(-17.00, 2.20, 29.10)`. Same room,
> same 2.0 m clearance, no rotation.

Two steps of the ladder: 0.05 m is still short, 0.10 m clears. The wall behind
goes 1.25 m → 1.15 m, and the element is **unmounted**, so it owes nothing back
there — the BACK contract is only asked of targets claiming a mount.

**Reported, not applied.** It moves an element in a shipping Zone's generation
and would ripple into the placement fixtures and the zone-audit captures, so it
waits on the owner's word rather than being taken as read. `godot-target-facing`
stays in `NOT_A_SUITE` until it lands; the entry's text is corrected to say 1 of
27 rather than the stale 7 of 27 it still claimed after `e13e7e0`.


### F-20 — the support table under-declared what the engine implements

`SUPPORTED_STATUS_TARGETS["vulnerable"]` read `("enemy",)`. The engine
implements it **twice**: `stat_stack.gd:93` multiplies the PLAYER's
`damage_taken` by its magnitude, and `enemy.gd:434` multiplies the enemy's.

**The defect was invisible for a structural reason.** While support was asked
per KIND, `vulnerable` was supported and that was the whole question. Landing
the owner's per-TARGET boundary at the Godot application edge asked the second
half for the first time, and `godot-stats` went red on three cases — two of them
the player's own `damage_taken` and the cleanse order whose comment says in as
many words "`vulnerable`, which the player does suffer". The live door into it,
`rule_runtime.gd:342`, applies to `player.statuses`, whose side is `self`.

**Declared to match the runtime, not the other way about.** A target the engine
implements may not be refused, exactly as one it does not implement may not be
allowed. Reverting the one row and regenerating brings all three failures back,
so the fix is the declaration and not a softened boundary.

**Audited, not spot-fixed.** Every one of the thirteen implemented kinds was
read against its consumers: `marked` and `stunned` are genuinely enemy-only
(`enemy.gd:315,336,433,482`, nothing on the player); `low_profile` is correctly
`self` because `enemy.gd:304` reads the *player's* container; the five
`("self","enemy")` kinds and the three self buffs all match. `vulnerable` was
the only wrong row.

**The test that could not see it has been replaced.** It swept
`ECHO_STATUS_KINDS_IMPLEMENTED` against one `self` container, which asks only
whether a kind is accepted *somewhere*. It now sweeps all thirteen kinds across
all five §15.1 target kinds and asks both halves — accepted where declared, and
elsewhere no entry, no active state and no `status_applied` — plus two anchors
it cannot derive from the table it reads, naming the runtime lines behind
`vulnerable` and `lightened`.

**The bridge's own gate tests failed for being out of date**, which is its own
small finding: they were written when `lightened` was the example of
named-and-unsupported, so the change that gave it an effect broke them. The
invariants are kept and the examples move — and the named-but-unsupported sweep
is now DERIVED from the two lists rather than transcribed, with a guard so an
empty derivation cannot pass by running nothing. That is the lesson the on-hit
list in the same file had already learned once.


### F-21 — two exports of one map, from two lanes that could not see each other

Dess exported `SUPPORTED_STATUS_TARGETS` to the engine as
`ECHO_STATUS_SUPPORTED_TARGETS` (`c0d5446`); this lane had exported the same map
as `ECHO_STATUS_TARGETS` (`fb11161`). She branched from `e13e7e0`, before mine
landed, so neither was careless — the lanes simply arrived at the same need
within an hour of each other.

**The merge collapses them rather than keeping both.** Hers stands: the schema
and its exports are her lane, it is her file, and `SUPPORTED` is what the map
actually is. The three engine consumers — `status_effects.gd`'s application
boundary and the two drivers — are renamed onto it. Two spellings of one fact is
the failure this repository keeps having to uncreate, and it is cheapest to
uncreate on the day it appears.

**The coordination worked in the end.** Her commit says `lightened` is
deliberately not declared supported on her side, waiting on this lane reporting
the effect landed. It had: her control
`test_the_engine_is_told_which_targets_each_kind_supports` and this lane's
per-target sweep now check the same map from both ends. She also records F-18
from her side — widening the vocabulary to twenty-four opened the window where
`StatusEffects.apply` still guarded on `ECHO_STATUS_KINDS`.


### F-19 — D-1's seams, measured before the contract is written

**Dess, 2026-09-21.** Recorded so the acquisition contract is written
against the real path rather than a remembered one.

**What exists.** The interpretation machinery is whole: `save.interpretations`
is the log, `derive_mechanics` folds it, `next_interpretation_seq` pins how
far it has been written, and `handle_progress` carries Check confirmation.
Slot/equip resolution exists in `mechanics`.

**What does not exist.** *Nothing binds a claimed Check to a FEATURED
capability.* `railway_scenario.gd` says so at the site — in the real loop
the featured Echo arrives as "an AP Check, the interpretation fold, a
snapshot, `set_equipped`", and its pedestal is the one labelled shortcut
precisely because that chain is not built. There is no `set_equipped` in
the bridge at all.

**So D-1 is a binding, not a subsystem**, and the five requirements land
on seams that already exist:

| requirement | the seam it lands on |
|---|---|
| reachable featured acquisition | the Check allocator + `topology.reachability` |
| a qualifying local Echo | the fold's component output |
| preserved delivery of the foreign item | the AP claim path — the local grant must not consume it |
| matching pre-seed AP guarantees | AP's fill proves reachability before play; the local grant must agree with what was proven |
| retries / reload / delayed interpretation | `next_interpretation_seq` vs `len(save.interpretations)`, which already distinguishes written from pending |

The last row has existing machinery and is the one most likely to be
assumed rather than checked: a fold that lags is the ordinary case, not
an error.

**Not started, and not claimed as started.** B2 stays the preferred
direction; no proof of it is fabricated here.

### F-22 — D-1/D-2 landed: the binding, exercised

**Dess, 2026-09-21.** F-19 said D-1 is a binding rather than a
subsystem. It is, and it is built.

`Zone.featured_acquisition` names the capability a Zone is built to hand
over, the allocated Check that hands it over and the room holding it.
`zone.established_in_zone(zone)` is **the producer `capability_guarantee`
case C never had** — it returns exactly what the Zone features, never
what it merely contains.

**The rule with teeth: you may not need the grapple to reach the
grapple.** `topology.reachability` now takes the featured capability
AWAY and explores again, rather than trusting the caller left it out —
because a caller wiring case C into `declared_capabilities` is the
precise mistake it exists to catch, and that is what would make the room
look reachable. Sabotage-proven.

**The five requirements, exercised rather than described** (11 controls,
`bridge/tests/test_featured_acquisition.py`):

| requirement | what is asserted |
|---|---|
| reachable featured acquisition | the circular Zone is refused and says why; a room that does not carry the named Check is refused |
| qualifying local Echo | `owned_capabilities` gains `grapple` from an Action whose PRIMITIVE satisfies it — with the negative half, an Echo that does not qualify granting nothing |
| foreign item unchanged | `source_item_name` / `source_game` / `source_recipient_name` / `source_location_id` survive the fold verbatim while the capability still arrives |
| pre-seed AP guarantee | case C fires for the featured capability and NOT for one the Zone does not feature; once owned, the cheaper case B is reported instead |
| duplicate / delayed / reload | a second confirmation mints no second Echo and does not renumber the first; a lagging fold leaves case C carrying the Zone; the capability survives a real JSON round trip |

Sequence fields are infrastructure this rides on, and none of the above
is proved by pointing at one.

**Not claimed:** nothing here composes a featured Zone in the generator,
and no live-seed logic changed. `featured_acquisition` is optional, so
every Zone composed before it is unaffected.

## Full scope and status

Every workstream in the plan, including what has not been started. **A Dess
dependency blocks the row that names it and nothing else** — the campaign does
not stop at the first blocked row.

| ID | Workstream / milestone | State | Blocked by | Note |
|---|---|---|---|---|
| **A1** | 0.3 cleanup: shot-target orientation repaired, `godot-target-facing` promoted to a gate | **repaired 7 → 1; not promoted** | — | F-19. Unmounted SHOT elements had no facing rule at all; a room-level pass now aims them and six of the seven failures are gone. **The seventh cannot be solved by rotation** — `ActivityElement_4` in `c002` is blocked inside two metres in all sixteen facings, at full width and at a sliver, and the census's own nearest blocker is 1.90 m. It needs a placement change. The suite stays in `NOT_A_SUITE` and out of CI **because it does not pass**, which is the condition, not a formality |
| **A2** | Climbing-producer door records (`tower`, `platform_path` file `exit` past the wall the hole is cut in) | **not started** | — | bounded repair; scoped carefully because `door_world` feeds join sockets and lock slabs |
| **A3** | Finish-path coverage | **not started** | — | |
| **A4** | Stop tracking disposable test saves; launch hygiene | **not started** | — | |
| **B1** | Amalgam: one shared effect path | **not started** | — | |
| **B2** | Amalgam: usable builds | **not started** | — | |
| **B3** | Status/physics subsets (13 Statuses in 4 families, 8 compounds) | **not started** | — | F-15/D-7: `lightened` and `anchored` are specified and absent, and `E-033-room` waits on them. The mass-class vocabulary they act on now exists (`mass_class.gd`) |
| **B4** | Forge/Static economy | **not started — decision pending** | owner | plan §6 decision 6: only accepted recipes/costs/outputs; new economy rules stay a decision |
| **B5** | Independent Amalgam breadth after M3 | **not started** | M3 | |
| **C1** | Environmental objectives: reuse `ActivityElement` sensors | **done, in use** | — | the goal plate at `G` is exactly this; `RailReceiver` is the shot case |
| **C2** | A signal-driven actuator generalised from `PoweredLink` | **not started** | — | `RailSpan`/`AlignmentControl` and `ShuttleDeck`/`CallLever` are two concrete chains; the generalisation is not built |
| **C3** | Objective semantics (§5.4a) | **settled, implemented** | — | accepted consequences persist, live values do not. M1 is the worked example |
| **C4** | Reset / interruption / tool loss | **partly done** | — | EX50-011's reset is built and measured (E-011-*, §8). **Tool loss now has its cleanup half** (F-17): each player-side effect records the slot that started it, death ends everything, and an unrelated unequip ends nothing. Reset *groups* (§23.4) are still G3's, and blocked |
| **C4a** | `ServiceShutter`'s blocked-closure behaviour against §21.2 | **a measured delta, not started** | — | `01_RELIABLE_CORE.md:2318` requires a blocked closure to stop, **reverse to fully open**, and retry after 1.0 s, repeating indefinitely. `service_shutter.gd:144-152` stops and waits. The `held_open(seconds_over)` signal and `overrun()` readout already exist to report it. The shutter has no direct suite today — it is covered only incidentally by `counterfire_driver.gd` |
| **C4b** | One clearance helper instead of four | **not started** | — | `SpaceProbe.body_fits` (`space_probe.gd:132`) is the primitive, used by `affordance_nodes.gd:327`. `PoweredLink.doorway_is_clear` (`powered_link.gd:154`) hand-rolls the same query **and the runtime never calls it** — the door at `:124` moves regardless. `ServiceShutter` counts bodies in an Area3D; the blink has its own landing test |
| **C5** | Readable cause and effect from the existing vocabulary | **partly done** | — | signs, chevrons, lever labels, deck railings. Whether any of it reads is a playtest question |
| **C6** | Bounded objective-binding schema so Epsilon selects relationships | **not started** | **D-5 (Dess)** | |
| **D1–D5** | Blindside major, first section | **verified as M1 + M2-mech** | — | see the rows above |
| **D6** | Second binding (`ranged_hit` on bracing) | **verified, and labelled an existing-tool variant** | — | not a second acquisition loop |
| **D7** | Return-later variant | **deferred, tracked** | all-Checks exit policy (owner) | plan §6 decision 5; no silent change to the completion rule |
| **E-011** | Passing Platforms | **a playable development scenario.** Its route tests pass; they do not discharge its interlocks, campaign integration or save requirements | D-6 for save | `E-011-save` (§9) and `E-011-gates` (§8 boarding gates/interlocks) are open rows with their own states. A green route test is evidence about a route |
| **E-021** | Counterfire Arcade | **a playable development scenario.** Its route tests pass; they do not discharge its interlocks, campaign integration or save requirements | D-6 for save | `E-021-save` (§9) is open; `E-021-fair` cannot be closed by a test at all. The shutter's §21.2 interlock delta is its own row below |
| **E-033** | Unweighted Switch | **the property distinction is verified; the room is not built** | **D-7** for the Status | the open question is answered: the engine had neither vocabulary as a gameplay concept. §10's decisive control is done and green |
| **F** | Progression / Epsilon / AP engine half | **not started** | **D-1, D-2 (Dess)** | the `established_in_zone` producer's client half |
| **G1** | 0.4 save representation | **not started** | **D-6 (Dess)** | |
| **G2** | Legacy migration | **deliberately not done** | owner | no old campaign is touched |
| **G3** | Interruption | **not started** | — | |
| **G4** | Two unmistakable launch modes, separate saves, printed revision | **partly done** | — | the 0.4 scenarios launch by name and by double-click; the printed revision/provider/scale banner is not done |
| **H1** | **Enemy variety** — the recorded target is ~20 distinct enemies with meaningful combat roles (`docs/art/ART_REVIEW.md` § "The enemy roster target, recorded") | **3 of 10 declared roles have behaviour — a separate explicit workstream, NOT discharged by the 2026-09-21 Status/room checkpoint, and "no new content roster" does not erase it** | — | `Constants.ENEMY_ROLES` declares ten — `melee, ranged, brute, charger, bulwark, scuttler, artillery, beacon, diver, drifter` — and `ENEMY_ARCHETYPES` implements **three**. `Enemy.create` branches on those three only; the other seven are names in a generated constant with no runtime behind them. The art lane records the same gap from its side (`docs/art/review/batch008/README.md`: "seven of the ten roles have no collider, and the telegraph has no node in `enemy.gd`") |
| **H2** | Enemy telegraph as a hangable node | **the seam is archetype-agnostic and the ranged windup exists (F-14 repaired)**; the authored NODE is still art's side | — | The countdown's resolution called `_slam` unconditionally, so structurally only the brute COULD telegraph — any other attack opening a windup would have resolved into the brute's melee slam. It dispatches on `telegraph_kind` now, durations live in `Enemy.TELEGRAPH_SECONDS` instead of literals mid-function, and the ranged archetype commits `aim` for 0.45 s before firing. Adding a third attack is a table row and a branch, with no change to the countdown, the plant, the swell or the `telegraph_started`/`telegraph_finished` contract an authored telegraph binds to. `melee` declares no window on purpose and the reason is recorded. Covered in `godot-content` THROUGH THE COUNTDOWN — the first cut called the resolver directly and passed with the defect restored |
| **M0** | 0.4 line exists, 0.3 untouched | **verified** | — | |
| **M1** | One real machine chain | **verified** | — | `M1-zone` is built and certified this batch (`godot-rail-zone`): D-4 landed at `704f379` and the engine consumes it. What remains is a COMPOSER that declares a railway — no generated Zone asks for one yet — and a played route through it |
| **M2-mech** | Dev-scenario loop, labelled | **verified** | — | |
| **M3** | First content group | **3 of 3 built as playable development scenarios** | — | EX50-011, EX50-021 and EX50-033 all built and gated. **Built is not integrated**: all three are development scenarios, none is composed into a Zone, and their interlocks, campaign integration and save requirements are separate open rows. **Genuine Epsilon objective selection stays incomplete until D-5** and a handwritten configuration will not be reported as it |
| **M2 complete** | The intended experience, multiworld-safe | **blocked** | **D-1 (Dess)**, §5's five requirements | |
| **M6** | **Cross-room / Zone-spanning puzzle relationships** | **bridge half delivered; engine half and composition not started.** 0.4 COMPLETION, not a post-0.4 extension (owner scope clarification 2026-09-22) | Prod's runtime half; a composer that emits a relationship | **The declaration, the generation constraints, the progression validation and the save representation are in** (`Zone.zone_state`, `StateCondition` on `TopologyEdge`, the macro component in `topology._explore`, `ZoneProgress.macro_state`), with 20 controls on a really composed 23-room Zone and every rule sabotage-proven. **What is NOT in:** no composer emits a relationship, so nothing in a live seed declares one; the engine half is unbuilt; no physical acceptance has been run. | Prod's original measurement stands: Room boundaries must not be the default limit on puzzle scope; room-local puzzles stay supported. The architecture is already pinned at Amalgam §19.7 — room graphs read macro state and never write it, and *"a puzzle that should change the Zone drives a setter package's interaction, which the player then performs"* — so nothing is invented, but **none of it is built**: `grep -rn macro godot/scripts/` returns nothing, §20's `MACRO_STATE` and `MACRO_SELECTOR` are absent, and §21's macro effect types are absent. Engine half, measurement and the two rule questions: `docs/D8_CROSS_ROOM_PROD.md`. Acceptance is Blindside's major + acquisition branch through the real composition path with distinct room IDs — **not** a standalone scenario with labelled areas |
| **M6** | see the cross-room row above | | | |
| **M7** | **Transported-object support** — an object the player carries from one room to another | **verified** | — | OV04 P16. Bridge lane declared it (`Zone.transported_objects`, `ZoneProgress.object_rooms`, the `object_transported` intent, `record_object_transported` and `recover_transported_object`); this lane built the runtime (`transported_objects.gd`) and `godot-zone-state` covers it at 56 checks. One identity, moved physically, reported on the wire, reloaded where it was left, recovered when it leaves its volume, and **the save carries the room and nothing else** — §5.1 makes its Statuses EPHEMERAL, so there is no field a Status could ride in |
| **M4** | Remaining Amalgam breadth | **not started** | M3 | |
| **M5** | Pinned review build | **not started** | M3 | |

### Where a Dess handoff actually blocks something

| Handoff | Blocks | Does NOT block |
|---|---|---|
| D-1 acquisition contract | **M2's completion** | everything else in this table |
| D-2 `established_in_zone` producer | M2 complete, F | — |
| D-3 `DoorAssignment.requires` | capability gates | — |
| ~~D-4 `RailNetwork` schema~~ **delivered `704f379`, consumed this batch** | nothing | — |
| D-5 objective-binding vocabulary | C6, and any claim of **genuine** Epsilon objective selection | building and testing provisional configurations |
| D-6 0.4 save representation | G1, `E-011-save`, `E-021-save` | E-011's and E-021's other rows |
| ~~**D-7** `lightened` in the closed `StatusKind` with its effects~~ **delivered and consumed; `lightened: ("object",)` declared beside the runtime** | nothing | `E-033-answer`, `E-033-sensor`, `E-033-control`, `E-033-step`, all of which are done |
| ~~**D-8**~~ **AGREED AND THE BRIDGE HALF IS DELIVERED** (`docs/design-proposals/D8_CROSS_ROOM_STATE_CONTRACT.md`, §11 answers Prod's two rule questions; F-26) | nothing any more — M6's remaining work is the engine half | M1-zone, M3, the minors, H1/H2 — none of which needs it. Prod's half (runtime binding, machinery, cross-room feedback, physical acceptance) is specified in `docs/D8_CROSS_ROOM_PROD.md` and is **now unblocked**: the contract is agreed, so the owner's "agree the shared contract before competing implementations are written" is satisfied and the engine half is free to start |

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

**These are development scenarios, and a route test is evidence about a
route.** Each of the three rooms below runs only when an operator asks for it
by name: not composed, no Checks, no exit, no campaign, no bridge connection,
no save. A green continuous-play run says a person can get from one end to the
other. It says nothing about that room's interlocks, its campaign integration,
or its save requirements — those are separate rows, they are open, and several
are blocked on D-6. Nothing in this table is a progression claim.


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
- **Still blocked, and only where named:** M2's completion on the acquisition guarantee (D-1/D-2 delivered `96b6fdd`; the composer half is engine work, and the guarantee gates M2 completion and mandatory AP capability claims — not Zone/runtime integration development); `M1-zone`
  on D-4; `E-011-save`, `E-021-save` and G1 on D-6; genuine Epsilon objective
  selection on D-5. Nothing else in the scope table waits on a lane that has
  not accepted a handoff.
- **Two things no test will answer**, and they are named rather than quietly
  claimed: whether EX50-021's bait is fair (§12 says so itself), and whether
  any of this is fun. Both are playtest questions.
- **One suite outside CI is red, and it was red before this line existed.**
  `godot-target-facing`: 7 of 27 shot targets in a composed Zone cannot be
  shot from in front. Verified byte-identical at `19c5d8e` in a clean
  worktree. It is workstream A1 and it is not this batch's.
- **Scheduled work is off.** No heartbeat, no watchers, no subscriptions.


### F-22 — the contract declares a graph, the carrier runs a route

`Zone.rail_networks` (D-4, `704f379`) is shaped after what `RailJunction`
already runs -- docks, spans, one control per span, a latch per span -- and it
is a good fit in every respect but one. `RailSpan.from_dock` and `to_dock` are
any two of up to eight declared docks, so the schema describes a **graph**.
`RailCarrier` runs **one ordered route**: docks along a `RailPath`, with a link
between each consecutive pair. A span between the first and third dock has no
link to commission and no meaning the engine can honour.

**The engine refuses rather than guesses.** Routing the carrier through the dock
in between would be the engine deciding what the Zone meant, which is the
boundary `rail_networks.gd` exists to keep. A non-adjacent span is refused by
name, the network builds nothing, the Zone still builds, and the refusal is
readable on `ZoneController.rail_refusals` so a suite can report it as a
composition finding instead of a crash. `godot-rail-zone` pins that behaviour
including the refusal text.

**Concrete and bounded, for the bridge lane — three questions, not a rewrite:**

1. **Must spans join consecutive docks?** If yes, `RailNetwork` can validate it
   where it already validates that a span's docks exist, and the engine's
   refusal becomes unreachable. If no, the carrier has to become graph-capable,
   which is real engine work and should be scoped as such rather than assumed.
2. **Is `docks` order the route order?** The engine reads it as such -- it is
   the only ordering available -- and nothing in the schema says so.
3. **Is there a `home_dock`?** `RailJunction.park` defaults to dock 0 and the
   engine parks there. That is an engine assumption about a Zone's intent, and
   a one-field answer would make it a declaration.

Question 1 is the only one that can make a Zone unbuildable; 2 and 3 are
currently engine defaults doing a declaration's job, and are written down here
so they stop being invisible.

**Not blocking.** Every shape the schema can express that a route can run is
built and certified today.


### F-23 — every piece of Zone-scope state the engine has is monotone

Measured while answering the 2026-09-22 cross-room scope clarification.

`report_latch` / `progress.latched`, collected keys, station reached-ness: all
one-way, all deliberately so, each carrying a comment about why progress is
monotone. `PoweredLink`'s signal is the opposite extreme — live, recomputed
every physics frame, *"nothing here writes to a save, and there is deliberately
no field it could write to"*. Between "permanent" and "gone with the frame"
there is nothing.

**So there is no reversible Zone-scope state in the engine at all**, and the
owner's five state classes have four homes and one gap:

| class | today |
|---|---|
| permanent accepted change | `report_latch`, monotone, idempotent |
| **reversible Zone configuration** | **nothing** |
| temporary timer / Status | `StatusEffects`, live only per §5.4a |
| held input | `PoweredLink.powered`, per frame, never saved |
| transported-object state | `ManipulableBody`, replayed from the manifest |

A cross-room puzzle built on today's engine therefore has exactly one way to
express itself: a latch. Which is the shortcut the owner forbids — *"do not
silently replace a live requirement with a permanent latch"* — and which §19.7
forbids independently, since a latch *"is never a machine-graph variable, has
no predicate, and drives no macro effect"*.

**The reversible macro layer is the missing piece and it is the whole of D-8.**
§20's `MACRO_STATE` and `MACRO_SELECTOR` and §21's ten macro effect types are
pinned and unbuilt; `physics.py` already budgets macro variables against the
§4.10 state vector, so the accounting exists while the declaration does not.

Two places where a required design exceeds the pinned rules, with the exact
rule and the proposed amendment, are in `docs/D8_CROSS_ROOM_PROD.md` §4. The
sharper of the two: **§19.7 rule 2 makes a cross-room HELD requirement
impossible** — a held input is room-layer live state, room graphs may not write
macro state, and the only legal alternative today is a latch. The
recommendation is to express such a design as reversible Zone configuration
rather than as a held requirement, which needs no amendment; the amendment that
*would* be needed if a genuinely held cross-room requirement is wanted is named
so the choice is visible rather than made by accident.


### F-14 (second half) — the telegraph seam could only ever have been the brute's

Recorded when EX50-021 measured "the ranged archetype's windup: **none**". The
first half of that finding was true and obvious: the archetype fired the instant
its cooldown allowed, from anywhere inside its reach, with nothing to see first.

The second half was structural and was not visible until H2 was attempted.
`_physics_process`'s countdown resolved with a bare `_slam(player)` — so a
telegraph was not a seam any attack could hang from. **Any** attack that opened
a windup would have resolved into the brute's melee slam, landing damage at the
brute's reach on whatever the attacker was. The interface (`telegraph_started`,
`telegraph_finished`, `telegraph_progress`, `telegraph_origin`) was complete and
archetype-agnostic; the one line that consumed it was not.

Repaired by dispatching on `telegraph_kind`. The ranged archetype now commits
for `TELEGRAPH_SECONDS["ranged"]` (0.45 s) and plants while it does — the
existing windup branch already stopped an enemy mid-telegraph, generically, so
a ranged enemy taking a shot is now both readable and vulnerable, which is what
EX50-021 §11's dodge needs to be fair.

**A test that did not cover its own defect.** The first version of the new case
called `_resolve_telegraph` directly; reverting the dispatch to the old
unconditional `_slam` left it **green**. It runs the windup down through
`_physics_process` now, and the revert produces two failures.

`godot-counterfire`'s note said "the ranged archetype has NO windup" and is
rewritten to report the measured window instead — a note that went on asserting
a repaired defect would be the suite reporting history as measurement. Its
timings are unchanged, because that case builds its projectile through
`Enemy.fire_at()` rather than waiting for the AI.

**Not done, and not claimed:** H1. Seven of ten declared roles still have no
behaviour, and this changes nothing about that.

### F-24 — F-22's three questions, answered in the schema

**Dess, 2026-09-22.** Prod built the engine half against D-4 and found the
contract describing a **graph** where the carrier runs **one ordered route**.
The finding is correct and the defect is mine. All three answers land in
`RailNetwork`, with controls, at the commit carrying this entry.

**1. Must spans join consecutive docks? YES — and refused in the schema.**

`_a_span_joins_docks_the_route_visits_in_turn` refuses a span whose docks are
not adjacent in `docks` order, naming the docks the route passes in between.
The reasoning is the one this project keeps arriving at from other directions:
**a schema that can express what no runtime can build hands the engine a
decision it must not make.** Prod's refusal was the right call and stays in
place for a hand-built dictionary; it simply becomes unreachable from a
validated Zone, which is where a refusal of a too-loose schema belongs.

YES is also the answer that can be taken back. Making the carrier
graph-capable is real engine work to be scoped rather than assumed, and if it
is ever done, relaxing this rule invalidates no Zone that ever satisfied it.
Answering NO today would have left unbuildable Zones composable in the
meantime, which is the expensive direction.

**One more of the same defect, from the other side.** Consecutive docks have
ONE link, so two spans naming the same pair are two latches and two controls
over one piece of track and the second has nothing of its own to commission.
Refused by the same validator. Prod did not ask about this case; it follows
from Prod's own sentence, and it would have produced the same engine refusal.

**2. Is `docks` order the route order? YES, and it is written down.**

It had to be, or "consecutive" in answer 1 would not mean anything. The
`RailNetwork` docstring now states it. No field, no behaviour change: the
engine already read it this way because it was the only ordering available.
`test_a_span_declared_against_the_route_order_is_still_consecutive` is the
control that keeps the rule from being stricter than the fact — `s2` to `s1`
is the same link as `s1` to `s2` and is accepted.

**3. Is there a `home_dock`? There is now.**

`RailNetwork.home_dock: str | None = None`, refused if it names a dock the
network does not declare. `None` means the first dock, which is exactly what
`RailJunction.park` already does — so **nothing built today changes**, and
what was an engine assumption about a Zone's intent is now the Zone's own
declaration, with the same default.

Each rule sabotage-proven separately: neutralising the adjacency validator
fails exactly its three controls and leaves the `home_dock` controls green;
neutralising the `home_dock` check fails exactly its one.


### F-25 — the re-park undid the home dock one line later

Found while consuming F-24 answer 3. `RailNetwork.home_dock` was read, resolved
to an index and applied with `junction.park(index)` — and the carrier still sat
at dock 0.

`RailJunction.restore_from` ends with a bare `park()`, and it has to: a carrier
restored onto a link this build did not commission would be standing on track
that is not there. But `park`'s default argument was `0`, so the re-park did not
mean "come home", it meant "go to the first dock" — and `ZoneController` calls
`restore_from` immediately after the builder, so **any** home a caller chose was
overwritten by the next statement.

Latent rather than new: nothing had ever chosen a non-zero dock, so the default
and the intent agreed by accident. The moment a Zone declared one they stopped
agreeing.

**The junction owns its home now.** `RailJunction.home_dock` defaults to 0 —
unchanged behaviour for every caller — and `park(dock := -1)` honours it when
called with no argument. So `restore_from`'s re-park means "come home" and the
one place that knows which dock that is sets it.

`godot-rail-zone` covers both directions: a network naming `home_dock: d2`
parks at dock 2 (offset 35.73), and one declaring none still parks at the
first — the control that says F-24's answer cost nothing.
### F-26 — D-8 agreed and the bridge half landed; one search knew what another did not

**Dess, 2026-09-22.** The contract is agreed. Prod's
`docs/D8_CROSS_ROOM_PROD.md` and my
`docs/design-proposals/D8_CROSS_ROOM_STATE_CONTRACT.md` were written
without either lane seeing the other's, both named §19.7 as the
architecture, both quoted the same *"which the player then performs"*
sentence as the answer to the forbidden global signal bus, and both
called it D-8. §11 of the contract answers Prod's two rule questions:
the transported-object amendment is **accepted and narrowed to
authority** (§10.5 already settles persistence), and the held-requirement
resolution is **taken as recommended**, with the bounded §19.7 rule-2
exception declined and recorded as available.

**What landed, and the one rule worth arguing with.** `Zone.zone_state`
declares the variables `physics.state_vector_product` has budgeted since
before anything could name one; `StateCondition` gives `TopologyEdge`
the predicate §5.6 step 6a has always claimed to evaluate;
`topology._explore` carries a third state component; and
`ZoneProgress.macro_state` is a save field that is **overwritten rather
than accumulated**, joining `resume_anchor` and staying out of `latched`
for the reason Prod's §3 question 5 gives.

The rule I would most like argued with is **§4.0: lifetime is proven by
the declaration, not asserted by it.** `permanent` means the setter
selects exactly one state and it is not the initial one — monotone by
construction, §5.5's latch derived rather than labelled. `reversible`
means the initial state is selectable and at least one other, so the
player can always put it back. The owner's *"do not silently replace a
live requirement with a permanent latch"* is then **unwritable** rather
than discouraged: the silent version is precisely a permanent variable
wearing a reversible label, and the two now differ in a field a
validator reads instead of in an intention a reviewer has to notice.

**THE DEFECT, AND MY OWN TEST FOUND IT.** Adding the macro component to
`_explore` and threading it through five of the six searches in
`reachability` left `_key_graph_is_acyclic` exploring at the initial
state only. A gated spine edge therefore looked permanently shut, every
key beyond it looked unfetchable, and the composed Zone came back with
*"the key graph has a cycle: blue -> green -> blue"* — a cycle report
about a Zone that has no cycle.

That is this project's oldest failure, **reintroduced by the same change
that added the thing it is about**: one search knowing what another does
not. It was caught only because the acceptance case runs against the
really composed 23-room Zone rather than a three-room fixture; a toy
with no locked doors would have passed every assertion and shipped the
bug.

**Evidence.** `bridge/tests/test_cross_room_state.py`, 20 controls, all
against `playtest.played_zone()` — 23 rooms, 30 edges, re-validated
through `Zone.model_validate` rather than `model_copy` so the validators
actually run. Five rules sabotage-proven separately, each failing
exactly its own controls: the cross-room rule (1), the lifetime rule
(2), the edge predicate (3), the route-condition validator (2) and the
setter branch in the search (4). `make test` **1631 passed, 6 skipped**;
`check_packet` green after syncing the v0.8 `zone.py`, `graph.py` and
`protocol.py` mirrors; generated artifacts regenerated, never edited.

**What this is NOT.** No composer emits a cross-room relationship, so
nothing in a live seed declares one — the same honest position D-1's
`featured_acquisition` is in. The engine half is unbuilt by agreement,
and no physical acceptance has been run. A bridge that can refuse a bad
relationship is not a game that has one.


## Finding IDs from here: lane-prefixed

**Owner instruction, 2026-09-22:** *"use lane-prefixed IDs or one allocator;
don't spend another merge renumbering both lanes' unrelated findings."*

Adopted. From this entry onward the engine lane numbers its findings **`P-1`,
`P-2`, …** and the bridge lane numbers its own. Everything up to `F-26` keeps
the number it was merged under; nothing is renumbered, because renumbering
settled history is the cost this rule exists to stop paying.


### P-1 — four contract corrections, applied

Owner corrections of 2026-09-22, each against something this lane or the shared
contract had got wrong.

**1. Held cross-room mechanics are UNSUPPORTED, not unfair.**
`D8_CROSS_ROOM_PROD.md` had argued that a cross-room held requirement is a bad
puzzle — "holding a lever in one room while watching a door in another they
cannot see". That is a design opinion this lane does not get to impose, and
stating it risked quietly deleting a mechanic from the accepted design. The
document now says what is true: §19.7 rule 2 has no way to express one, so it is
unsupported under the current contract. Reversible configuration is approved for
the first Blindside integration and is **not a substitute** — where a selected
0.4 design needs a held mechanic, the obligation is the precise bounded
amendment, not a toggle wearing its name.

**2. Reversible operation is not reachable reversal.**
Dess's §4.0 rule proves `setter.selects` can return a variable to its initial
state — an **operation exists**. It does not prove the player can still reach
and use the control. Blindside's gantry is the case: it is overhead and out of
reach without the grapple, so *"the player entered its room"* is not *"the
player can operate it"*. State-aware route validation and **physical
setter-operability** are now separate evidence, and the second is this lane's.
Every acceptance case that touches a setter tests the real approach and the real
interaction — never a room id, never a directly assigned flag.

**3. The consecutive-dock rule states the implementation, not the design.**
`rail_networks.gd`'s header read as though branching railways had been ruled
out. They have not; they are **unbuilt**. Corrected, with the scope named: a
branching railway needs a carrier whose route is a graph rather than an ordered
list (`dock_offsets` and `commissioned` are both indexed by position along one
path), a switch actuator at the branching dock with a rule for how it is set,
and a reachability search that can tell the branches apart.

**What Blindside itself needs today: nothing more.** Its yard is S1→S2→S3, one
ordered route, and the acquisition branch is a WALKED and grappled route off the
S2 area — `BRANCH_OUT` is a distance from the junction, not a second line. The
restriction does not constrain the selected configuration. It would constrain a
configuration where the branch is itself railed, or where one carrier can be
sent two ways, and both of those are in the accepted design and unbuilt.

**4. A local reader beside a remote one is ordinary content.**
`ZoneStateVariable._a_reader_is_never_in_the_setters_room` refused ANY reader in
the setter's room — an acceptance-case requirement turned into a global content
restriction. It is now `_at_least_one_reader_is_somewhere_else`: the remote
consequence is what makes the relationship cross-room, and a control that also
drives something where the player is standing is fine and is the more legible
kind. A positive control was added, because "at least one elsewhere" and "none
here" pass exactly the same tests without one.


### P-2 — the control was placed through the wall, and the walk told me nothing

`make godot-zone-state`, 37 checks, in CI: D-8's engine half consuming
`Zone.zone_state`.

The first build placed a setter at `arrival + (-2.6, 0, 1.2)` — 2.6 m
**sideways**. A generated corridor is not that wide, so the lever went into the
plaster: the player walked to within 1.6 m, the interact ray hit the wall at
x −2.3, and `_interact_target` stayed null. Every case that operated the
control failed and every case that only read state passed, which is exactly the
shape that makes this worth writing down — **the walk succeeded**. `walked=true`
at 1.58 m is what a control you cannot use looks like from the outside.

Two wrong guesses before the measurement: the lever's half-base lift (real, and
fixed, and not the cause) and the interact range (3.0 m, never the cause). The
third step reported what the ray actually hit, by object rather than by name,
and the answer was a wall.

**Placement consults the committed bounds now.** `room_bounds` is the layout's
own answer to how wide a room is; `_inside` clamps every setter and mechanism
into it with a margin, and the offsets run ALONG a room rather than across it.
A room with no recorded bounds is left alone rather than clamped to nothing.

**The diagnostic stayed, conditioned on failure.** A control through a wall and
a control that ignores the key look identical from a `pulls` counter, so a
failed pull now reports what the camera was looking at instead. Success is
quiet.


### P-3 — D-8 consumed: a puzzle that crosses rooms, and the gap that remains

`ZoneController` builds `Zone.zone_state` into a `ZoneState` (the machine layer
of §19.7: no logic nodes, no room addressing another, idempotent), a control the
player operates, and mechanisms elsewhere that follow the value by **variable
id**. Proven, each as its own case:

- a declaration becomes a control in its declared room and a machine **two rooms
  away**, so nothing here is satisfied by a shared doorway;
- the player **walks to the control and presses the key**, the Zone accepts the
  state, and a barrier's collider moves in a room the player is not in;
- **reachable reversal** — the walk back is made and the control operated again,
  reported separately from the declaration that a reversal exists (owner
  correction 2);
- **partial reload** comes up at the saved value with the barrier already clear,
  which a mechanism waiting for a `changed` signal would fail;
- **completed reload** comes back still reversible, not as a latch wearing the
  name;
- **local reset** rebuilds the machine from the variable and loses neither the
  configuration nor an unrelated latch;
- the setter node is **freed outright** and every reader still works, because
  none of them ever held it;
- an unimplemented mechanism is refused by name and the Zone still builds.

**THE GAP, NAMED RATHER THAN FILLED.** `ZoneProgress.with_macro` and
`ZoneProgress.macro` exist — storage and read-back — and `protocol.py` has **no
intent** a client can send to report a selection: `latch_fired`, `lock_opened`
and their siblings are all there and there is nothing for Zone state. So the
engine sends nothing and invents no message; `ZoneState.as_reported()` is what
it *would* send and the suite asserts it. The authoritative state-update path is
the bridge lane's half of the next checkpoint.

**And what this is not.** No composer emits a `zone_state` declaration yet, so
the Zones here are hand-written dictionaries standing in for its output and
labelled as standing in for it. `docs/D8_CROSS_ROOM_PROD.md` §5 is unchanged:
the Blindside acceptance case is the composer's output through the real path,
and a reference fixture is an intermediate test.
## Overnight 04 — the engine lane's log lives elsewhere

`docs/ledgers/PROD_OV04.md`. Split out on 2026-09-22: both lanes append to this
file's tail and every merge was conflicting there, which is the same cost the
lane-prefixed finding IDs were meant to stop paying. The bridge lane's OV04
rows stay here.


## Overnight 04 — the bridge lane's rows

## The bridge lane's OV04 log lives in its own file

`docs/ledgers/DESS_OV04.md`, mirroring `docs/ledgers/PROD_OV04.md` and
for the same reason Prod gave: both lanes appended to the end of this
file and every merge tonight conflicted there. The lane-prefixed IDs
stopped two findings sharing a number; they did not stop two lanes
sharing a last line.

`DESS-01` onward move there. The shared scope matrix, the blocking
table and every pre-OV04 finding stay exactly where they are; nothing is
renumbered and nothing is rewritten.
