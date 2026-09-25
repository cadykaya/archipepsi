# Prod — post-playtest repair and interface work (CP0 → CP4, then inherited 0.4)

The governing packet is `post_playtest_v1.0/`, copied verbatim with every
`SHA256SUMS.txt` entry verified. Prod's brief is
`post_playtest_v1.0/dispatch/PROD_START.md`. The task IDs are the
packet's (`13_WORK_QUEUE.md`, `data/WORK_QUEUE.json`).

## CP0 — `H-START` (the reference, preserved)

- **Branch and head:** `claude/archipepsi-0-4-blindside` at `a745637`,
  equal to origin, clean tree. The start is preserved at the NEW ref
  `review/post-playtest-start-a745637`; nothing existing was overwritten.
- **Other lanes:** no commit since the packet. Arty's branch is still
  `4093ded`, and there is no Dess branch.
- **Profile and provider:** the candidate profile
  (`--candidate`, slot `candidate`, folder `.diagnostic-candidate`), with
  the deterministic fallback provider and the mock multiworld. There is
  no `ANTHROPIC_API_KEY` here.
- **The owner's played save:** not received yet, and not waited for.
  The owner offered to send it; every reproduction below that could use
  it says so.
- **Preflight:** `make godot-import` and `make doctor` pass. The full
  frontier is deliberately not run at CP0.

## The owner's decisions (2026-09-24, verbatim)

**D-06 — legacy saves / enemy persistence.** "Going forward, ordinary
quit/reload should preserve encounter state. Enemies I killed stay dead;
a partially cleared encounter restores the enemies that were still
alive. Reloading is not an encounter-reset event. For an older save that
has no per-enemy persistence data, do not guess that enemies were
killed, and do not respawn the whole encounter around the player at
their saved coordinates. Use any existing authoritative state that
genuinely proves something. Otherwise treat the encounter state as
unknown: reset that room's encounter and restore the player at that
room's safe arrival/checkpoint before enemy AI becomes active. Preserve
the rest of the saved world state. From that point onward the new
enemy-state persistence takes over. In other words: no fabricated
cleared rooms, but also absolutely no legacy-save ambushes."

**D-07 — pressure plates.** "Pressure plates are held sensors. Pressure
present = active. Pressure removed = inactive. A pressure plate must not
permanently latch merely because I stepped on it once. If a puzzle needs
a permanent change, use a visibly different permanent control such as a
lever, locking bolt, latch mechanism, etc. The existing latch machinery
can absolutely be reused underneath — I'm rejecting the
presentation/interaction of a one-shot pressure plate, not the latch
system. If a puzzle genuinely requires a pressure plate to remain
active, there must be a guaranteed physical way to keep pressure on it,
such as a movable object/weight. Do not silently turn the plate into a
toggle. A short timed mechanism may exist as its own clearly
communicated mechanic, but don't disguise permanent or timed state as
'the plate is still pressed.'"

D-08 (the release label for the menu and map) and D-05 (consumable
refill and capacity) stay open. Neither blocks this work.

## Ownership, recorded before any shared edit

The packet gives Dess the new shared schema, progression, fold and save
contracts (`H-RESUME-C`, `H-PRESSURE-C`, `H-RELEASE-C`, `H-UI-DATA`,
`H-MAP-DATA`, `H-SEAMS`). It gives Arty the source art (`H-GLYPH-KIT`,
`H-CIRCUITS`). Neither lane has been resumed, and neither has a commit
since the packet.

The owner approved CP0 → CP4 and decided D-06 and D-07. So Prod takes a
**temporary single-writer exception** for the narrowest shared edits the
approved repairs need:

- each edit is bounded by those rulings and by the accepted contracts;
- each is listed in the seam table below with its source rule, for
  Dess's later review;
- if Dess or Arty resumes, the file in question passes back to them.

Art-dependent work uses clearly provisional placeholder art. It is
never presented as the Glyph-authored final.

## W0.1 — handback to Dess at `f332fff` (recorded 2026-09-24)

Dess resumed at `76b0952` and requested the handback in
`docs/ledgers/DESS_POST_PLAYTEST.md` W0.1. The owner made it mandatory
before Dess edits any shared file, with no two-writer interval. The
exception above ends here.

**Handback to Dess at `f332fff`.** Released, all of it:

- `bridge/archipepsi_bridge/schemas/**`, `generated/*` included;
- topology, cross_room, latched_route, transport_route, candidate,
  minor_hosting, theme_packs, content_value, layout and store;
- the progress-intent seams of `campaign.py` and `server.py`;
- what is generated from them: `godot/scripts/autoload/constants.gd`,
  the apworld constants copy, `docs/design-packet-v0.8/schemas/*`, and
  the Zone fixtures the make targets regenerate;
- the bridge tests that exercise those files.

**Prod keeps none of them**, to no checkpoint.

**1. In-flight edits, committed or named.**

- **Committed before the handback:** `f332fff`. It fixes DESS-19
  (`record_defeat` listed in `TRANSITIONS`, packet mirror
  byte-identical) and DESS-20 (`protocol.schema.json` regenerated by
  `make export`). Both are defects of my own H-RESUME-R edit. `make
  test` at `f332fff`: 2149 passed. `check_packet`: clean. Export diff:
  clean. Dess's queue items for them are closed by that commit, for
  Dess to confirm.
- **Named and not landed:** a bridge half for D13 1b/1c. It covers the
  composer's lever form, `PULSE_BUTTON` in the placeable and route
  sensor kinds, the route validator's pulse, and their tests. I wrote
  it in a work tree under the exception, before D13 existed. It is
  **offered, not handed over as an edit**:
  `docs/ledgers/post_playtest_evidence/H-PRESSURE-R_bridge_half_offer.patch`,
  against `76b0952`, source files and tests only. Adopt it, adapt it or
  discard it. It does not implement D13 1a (the `validate_zone`
  refusal) or 1d (the held weight).

**2. From here, a shared change is asked for, never made.** Prod asks
through a note below, or a recorded temporary transfer.

**3. D13's order, from Prod's side.** The lever placement in
`RoomGraphs` lands first, runtime only. The bridge admitting a lever
(1c) is Dess's and comes after it, which is D13's "not before it". So
the engine can place and run `PULSE_BUTTON -> LATCH` before any Zone
asks for one.

Legacy plates keep their exact old placement (**M-1**). A plate-to-LATCH
route saved in a crowded room is still built where it always was, even
where the new rule would refuse a lever.

### Notes to Dess

- **N-1 (D12, Unweighted): the goal moves within G.** The Check stood
  at G's east end, just past the high return gap. From the floor under
  that gap, a hop put it inside the claim ray's 3 m. Reproduced by
  census and by play: `[E] CLAIM CHECK 055`, a claim sent, nothing
  solved.
  - D12's Return field keeps the gap open ("The gallery also drops back
    through the return gap").
  - So the goal moves, not the gap: to G's middle, beyond the upper
    doorway, out of reach of every floor cell. That is the registry's
    objective volume, a `godot/` file.
  - The contract text ("the goal on G") and the `latches` entry are
    unchanged.
- **N-2 (D12, Unweighted): the transit ride.** A player riding the
  carriage toward the recess jumped to the sill while it was 2.99 m from
  the wall with the crossing wide open, and reached G with `lightened`
  never applied. Reproduced by play.
  - Prod's proposal: the HEAVY plate becomes a weighbridge along the
    drive lane, so the carriage is on it wherever it is a step in
    reach.
  - This is room geometry. The graph and the contract are unchanged.
  - If D12 means the ride as a valid alternate, say so and it is
    reverted.
- **N-3 (DESS-25):** the PR gate and Integration workflows not starting
  are CI, which is Prod's. I will look.
- **N-5 (answers D-1; unblocks 1c).** The engine's lever placement
  landed at `2346261`. `RoomGraphs` places a `PULSE_BUTTON` as a lever
  that stays thrown once its latch is set, and its own placeable list
  already includes the lever (N-4). **1c can land whenever you are
  ready.** `candidate_live_driver.gd` now expects what the served Zone
  declares (`9d79fb7`), so it passes today with no route and will demand
  the lever route back once 1c composes it. Still Prod's after 1c:
  switching `godot-latched-route-live` to the lever form.
- **N-6 (N-3, CI, diagnosed; it needs the owner, not a commit).** Every
  Integration run from #356 to #555 failed in 3 to 9 seconds. The jobs
  never got a runner: `runner_id` 0, no runner name, and the log is a
  404. The workflows are not failing. GitHub is not starting them, which
  is an account-level refusal (typically the Actions billing or spending
  limit on a private repository). Only the owner can clear it, under
  GitHub Settings -> Billing and plans (and Settings -> Actions). No
  repository change will help, so none is made.
- **N-4 (D13 §1c, a correction).** D13 says "`RoomGraphs` does not read
  the bridge's placeable list (`godot/scripts` has no reference to it)".
  It did. `room_graphs.gd` refused any sensor kind outside the exported
  `Constants.SIGNAL_ZONE_PLACEABLE_SENSORS`, so the engine could not
  place a lever until the bridge admitted one, and the two halves could
  only land together.
  - The builder now keeps its own list, `RoomGraphs.PLACEABLE_SENSOR_KINDS`
    (`PRESSURE_PLATE`, `PULSE_BUTTON`).
  - `godot-signal-graph` holds D13's order as a test: whatever the
    bridge exports as placeable must be in it.
  - So your 1c can land any time after this. It needs nothing further
    from the engine except the two live suites, which Prod switches once
    the fixtures carry the lever.
- **N-7 (answers D-7.1).** `godot-candidate-live` ran on your
  regenerated `candidate_zone.json`: all eight phases are green. The
  c009 route is built, its `PULSE_BUTTON` is a lever you pull (1 of 1),
  and its shutter starts shut and restores shut. The D-07 decline branch
  is gone, so the seed phase now requires all four steps EMITTED.
  D-7.2 (the live suite's lever form) and D-7.3 (the two fixture
  targets) are Prod's next items, with the held route (D-4).
- **N-8 (answers D-4; one ask).** The held route is played
  (`godot-held-route`), and it needed an engine repair first.
  - As it stood, the engine placed every plate at the legacy spot (M-1).
    c002's legacy spot is under the 1.6 m gallery, and a carried weight
    could not be put down on it: every attempt stopped 2.2 to 2.6 m
    short. The route your search certified was impossible in the engine.
    That was the engine's placement, not the composer.
  - A held plate is now placed by the measured rule, like the lever, as
    a 1.4 m load pad with signs naming the weight and the rule. A held
    graph the engine cannot place is now refused at build, as a lever's
    is, so it can never be silently impossible again. It needs no
    bridge change.
  - All three of D-4's points are played: the door open while the
    weight rests, the interlock with the player in the doorway, and a
    rebuild from the reported pose. At this geometry the pad is 3.4 m
    from the doorway and the interact ray reaches 3 m, so the doorway
    case moves the weight by a declared harness step, not by hand.
  - **The ask:** a `--form held` for `tools/compose_latched_route.py`
    (with `--expect ../godot/tests/fixtures/held_route_zone.json`), as
    you did for the lever. The reload is a harness rebuild today, and
    with that form Prod can play it across a real restart, with
    `object_poses` through the bridge. The tool is yours, so it is not
    touched here.
- **N-9 (H-COUNTERFIRE: registry geometry, as N-1 was, and one fact).**
  - Counterfire's Check volume moved within the flank, to its north-east
    corner: `[13.65, 3.0, 12.25]` to `[13.85, 3.0, 16.55]`.
    - At the old spot, a double jump from the annex floor below claims
      it from off the flank (V-10).
    - The walkway it used to block (PPT-06) is wide now anyway.
  - The shell's `annex_pocket` surface (ground level) is now `deck`
    (y 3), because the pocket is solid under a deck (PPT-05, holes to
    the fall plane).
  - Neither touches D12's card. The claim is on the flank, the release
    is on the flank, and R1 to R5 hold. `godot-counterfire-hosted` shows
    each in play.
  - The fact: the offer order hosts EX50-021 in both zone_001 (c025)
    and zone_002 (c024). That is PT-04's "possibly two Counterfires". It
    is a correct consequence of `offer_order`, reported rather than
    changed.
- **N-10 (for H-PASSING; one ask).** EX50-011 is hosted only where the
  offer order reaches it: zone_002 in the candidate campaign. No fixture
  carries it, so its room can only be played live today.
  - **The ask:** a `passing_zone.json`, regenerated from source like
    `candidate_zone.json`. That means the candidate profile's composition
    of a Zone whose offer order hosts EX50-011 (zone_002 is the one the
    live suite meets), with a `make passing-fixture` recipe I will add
    to the Makefile.
  - Until it exists, Prod develops against a local capture of the Zone
    the real bridge serves (unedited, never committed). The hosted
    Passing suite goes into CI when your fixture lands.
  - Both halves are in the Makefile now:
    - `make godot-candidate-live CANDIDATE_DUMP=<path>` writes the
      capture;
    - `make godot-passing-hosted PASSING_ZONE=<path>` plays it. Its
      default is `godot/tests/fixtures/passing_zone.json`, the file this
      note asks for.

## Evidence rules (PROD_START)

- **Every repair has:**
  - a failing reproduction;
  - the changed behaviour;
  - a focused regression and a control;
  - its revision and scope.
- **Combat** uses cumulative events and deaths, and ordinary visible
  aiming.
- **Rooms** are tested hosted in a real candidate, with baseline and
  movement-assisted access, and the return.
- **Resume** kills and relaunches both processes.
- **The menu pause** covers incoming authorizations and input leakage.

## Shared-seam table (Prod's temporary exceptions, for Dess's review)

**Closed at the handback, `f332fff`.** No new rows after it.

| edit | source rule | behaviour kept | commit |
|---|---|---|---|
| `ZoneProgress.defeated: tuple[str, ...] \| None`, with `with_defeated`, the `EnemyDefeated` intent, `transitions.record_defeat` and `_declared_members`, and `SAVE_FIELD_CATEGORY["defeated"] = "ROOM_PERSISTENT"`. Protocol and transitions mirrored to the design packet; `check_packet.py` passes | Owner ruling D-06 (verbatim above). The packet's `H-RESUME-C` minimum (09 §resume): distinguish quit/reload from a reset, keep defeated membership, check identities for consistency, handle old absence explicitly. The contract is Dess's; this is the narrowest form that ruling needs | Every existing field and intent unchanged. `None` (absent in an old save) means unknown, never "nobody". `bridge/tests/test_encounter_resume.py` | H-RESUME-R |
| `DIVER_TRIGGER_HEIGHT` 1.6 → `round(0.6 * JUMP_APEX_HEIGHT, 2)` = 0.8 m, in `schemas/constants.py`. Mirrored to `docs/design-packet-v0.8/schemas/`; `constants.gd` and the apworld copy regenerated by `make export`; `check_packet.py` passes | The diver's approved brief, "ignores a grounded player and commits when they leave the ground" (EPSILON_SPEC diver row). OV04 P06.4: "Do not assume it must require the player to grapple". The 1.6 m value was Prod's provisional tuning (`a25383f`), not a Dess contract | A grounded player (floor, gantry, a step down a stair or kerb) still draws no dive. `bridge/tests/test_diver_trigger.py` holds both ends and the derivation | H-FLYER-AI |
| `record_defeat` added to `TRANSITIONS`; `protocol.schema.json` regenerated by `make export`. Packet mirror byte-identical | DESS-19 and DESS-20, found by the CP1 frontier and by Dess's H-SEAMS review. Both are defects of the H-RESUME-R row above | Nothing else changes. `make test` 2149 passed; `check_packet` clean; export diff clean | `f332fff` |

## CP1 — `H-ARTILLERY` (PT-11): no shell through walls, roofs or cover — repaired

- **Reproduced first,** on the unmodified runtime with ordinary AI
  targeting and cumulative counts
  (`post_playtest_evidence/H-ARTILLERY_repro_on_d92b637.log`):
  - **A**, the next room behind an intact wall: 3 shells committed, 3
    hits, 48 hp in 10 s.
  - **B**, under a roof but seen through its open side: 48 hp.
  - **C**, a blast 2.4 m away behind a 6 m wall: 16 hp.
  - **D**, a wall raised across a shell's path in flight: 16 hp.

  The source matched all three leads: it committed a shell on distance
  alone; the flight was set point by point with no collision; and the
  blast was `distance_to(target) <= blast`.
- **The repair (`enemy.gd`), physics only, no room-ID force field:**
  - **Knowledge:** the artillery commits only at a player in its own
    line of sight.
  - **Path:** the shell's own arc (`ArtilleryShell.point`, the one
    formula for flight and check) is sampled in 16 segments before it is
    fired. Arriving within 0.6 m of the target, or at the player there,
    counts as arriving.
  - **Flight:** each tick is a ray from the last position, and the shell
    detonates at whatever it meets.
  - **Cover:** a blast reaches a player only if the chest or the knees
    can be seen from the burst.
  - Actors (the enemies) are ignored by path and blast. Walls, floors,
    roofs and physical objects stop both.
- **Evidence:** `make godot-combat-fairness` (new), 7 checks.
  - A: 0 committed, 0 hits.
  - B: 0 committed.
  - **F** (new): hidden behind a 2.5 m wall the arc would clear, 0
    committed. This is the sight rule on its own.
  - C: 0 hits. Control C2: the same blast in the open lands 1 hit.
  - D: 0 hits.
  - **E**, the positive control: over 0.6 m cover, 3 shells and 48 hp.
    Artillery is not silenced.
- **Sabotages (each restored, each failing by name):**
  - SA1, no sight check: F fails (3 hits).
  - SA2, no arc check: B fails (3 committed). Its first version was
    written wrong (it skipped firing whenever the arc was clear, which
    also failed E); it was corrected and re-run.
  - SA3, no flight collision: D fails.
  - SA4, no blast cover: C fails.
- **A setup lesson, applied twice:**
  - A gun placed in the same frame as its wall asked about a world
    without the wall: one shell went through on the first run of A. The
    suite now settles the stage before the gun; a real Zone builds its
    geometry long before any enemy acts.
  - `roster_driver`'s artillery case made the gun and its target in the
    same frame. The gun was lifted onto the target and rode it at 1.8 m,
    and the case passed only because the gun fired in its first frame.
    The target is now made first and settled. `godot-roster` 52.
- **Neighbours:** `godot-encounter` 51, including "indirect fire reaches
  a player who stands still".

## CP1 — `H-FLYER-HIT` (PT-12): a flyer is hit where it is seen — repaired

- **Reproduced first,** on the unmodified runtime at `6ebbc90`
  (`post_playtest_evidence/H-FLYER-HIT_repro_on_6ebbc90.log`: 17 failures
  in 29 checks). The player aims its camera at the middle of the
  RENDERED meshes, never at an internal centre, and fires through the
  real `fire_pulse` binding; hits are counted cumulatively.
  - **Seen versus hittable:**
    - the drifter's visible body was centred at 4.78 m and its hittable
      box at 6.72 m (1.95 m apart);
    - the diver's was 4.50 m against 6.07 m (1.57 m apart).
  - **Aimed at the middle of the visible body** at 4, 9 and 18 m: 0 hits,
    both roles.
  - **The deliberate miss,** aimed 0.45 m ABOVE the visible body: 2 hits
    each. That is where the hidden collider was.
  - **A real explosive Echo shot** at the visible body did no damage.
  - The diver's shots started outside its visible body.
- **The cause, in the source:**
  - The envelope contract (`schemas/constants.py`, `EnemyEnvelope`) says
    `hover_height` is the collider's CENTRE above the FLOOR, and
    `create()` hangs the collider exactly that far above the pivot.
  - `_hold_station` then lifted the pivot a further `FLYER_HOVER_Y`
    (4.2 m), so the hover height was counted twice.
  - Meanwhile the flyers got the walker fallback visual, built upward
    from the pivot. The body was drawn near the pivot and hit 1.6–2 m
    above it.
- **The repair (runtime only; no shared file edited):**
  - **The station is the floor.** The flyer's pivot rests on the floor
    under it, so its body sits at exactly the envelope's hover height:
    the diver at 1.65–2.15 m, the drifter at 2.08–3.03 m.
    `_floor_beneath` casts from the body; with nothing under it, the
    flyer holds where it is.
  - **Drawn where it is hit.** A flyer's `Visual` sits at the collider's
    centre. Provisional engine silhouettes are built inside the
    collider's box on every axis: a dart for the diver, with the eye on
    the nose it faces with; a canopy, emitter and vanes for the drifter.
    A flinch now scales about the body's middle rather than the floor.
    Arty's models later replace the look against the same box
    (`H-ENEMY-ART`), never the box.
  - **Shots, sight and the dive come from the body.** `muzzle()` and
    line of sight start at a flyer's body (a walker's are unchanged). The
    dive is aimed from body to body, and lands body to body.
  - **Area effects measure to the body.** There are three new accessors:
    `body_centre()`, `nearest_body_point()` and `overhead()`.
    - An explosive Echo shot measures to the nearest point of the body,
      not to the pivot. Otherwise a direct hit on something hovering
      2.5 m up would be a blast 2.5 m away.
    - The damage bar sits above the collider's top. `pivot + 2.1` put it
      inside a diver and under a drifter.
- **Evidence:** `make godot-combat-fairness`, 29 checks: the 7 artillery
  checks, plus 11 per flyer.
  - Seen versus hittable centres: 0.02 m (drifter) and 0.00 m (diver).
    Each also passes a same-box check: each box encloses the other with
    0.05 m of slack (the hittable box shrunk by 0.2 m inside the seen
    one).
  - Each body sits at the envelope's hover height (2.55 m and 1.90 m).
  - The muzzle is inside the visible body, and the flyer faces the
    player (0° off).
  - Aimed at the visible body at 4, 9 and 18 m: 3, 2 and 3 hits for
    each role.
  - The deliberate misses, 0.45 m above and 0.45 m below: 0 hits.
  - The explosive Echo shot: drifter 44 → 34.8 hp, diver 20 → 10.7 hp.
- **Sabotages (each restored byte for byte, each failing by name):**
  - **SF1,** the station lifted by `FLYER_HOVER_Y` again: both "holds at
    the envelope's hover height" checks fail (6.07 m and 6.72 m). So
    does the drifter's miss above: from 9 m, a steep ray 0.45 m over the
    body's top grazes the box's near edge.
  - **SF2,** the flyer's `Visual` left at the pivot: 14 fail. These are
    the centres 1.90 m and 2.53 m apart, every near/mid/far shot, the
    same-box check, the muzzle check and the explosive shot.
  - **SF3,** the blast measured to the pivot again: both explosive-shot
    checks fail (0 damage).
  - **SF4,** a flyer's muzzle back at `pivot + 1.2`: both muzzle checks
    fail.
  - **SF5,** the walker silhouette on a flyer (at the right height): 10
    fail. These are the centres 0.33 m and 0.60 m apart, the same-box
    check, and shots at the visible middle that miss. The drifter's
    snout reaches below the collider, so aiming under it hits.
- **Tests that measured the old geometry, corrected (not weakened):**
  - `roster_driver`'s drifter case compared the PIVOT with the 4.2 m
    constant. It now asks whether the BODY holds at the envelope's hover
    height and clears a standing player's head. `godot-roster` 52.
  - `status_family_driver`'s "a rooted drifter neither drifts nor falls"
    read the pivot's height. It now reads the body's (3.12 m).
    `godot-status-family` 15.
- **Other neighbours, green:** `godot-encounter` 51, `godot-content`,
  `godot-hud`, `godot-verbs`, `godot-legible`, `godot-affordance`,
  `godot-test`, `godot-transport` 106, `godot-lab`, `godot-stats`,
  `godot-counterfire` 59.
- **What the owner will notice:** flyers hover lower than in the
  candidate that was played. They now sit at the heights the shared
  contract declares, with the diver at head height and the drifter just
  above it, instead of about 4.5 m up. If they should hang higher, that
  is one number per role in the contract (`hover_height`, Dess's), and
  the runtime follows it with no code change.
- **For Dess (no edit made):** the runtime no longer reads
  `FLYER_HOVER_Y` in `schemas/constants.py`. It is superseded by
  `EnemyEnvelope.hover_height`, and is left in place because the shared
  constants are Dess's to retire.
- **Art review:** pending. Arty's lane has not resumed, and `H-ENEMY-ART`
  depends on this task.

## CP1 — `H-FLYER-AI` (PT-13): what each flyer waits for, and what it does — diagnosed and repaired

Prod's findings in this packet are numbered `PPT-nn`.

- **Which flyers the owner met.** The played Zone (`candidate_zone.json`)
  has no drifters. Its only flyers are the five divers in `c011`: an
  arena with a 1.64 m gallery and a kill_all objective.
- **Reproduced first,** on the unmodified runtime at `41d7a9a`, with every
  number counted from an event as it happened:
  - `post_playtest_evidence/H-FLYER-AI_repro_on_41d7a9a.log`: 6 failures
    in 44 checks.
  - `H-FLYER-AI_c011_on_41d7a9a_runtime.log`: the played room.

  Health is never read at the end; that is how an earlier diagnosis
  reported "zero damage".
  - **The diver was not broken. Its trigger was out of reach.**
    - Standing or strafing, it noticed the player and correctly waited.
    - Jumping, 310 frames off the floor, drew 0 dives. The trigger was
      1.6 m, which the engine read as 1.8 m of clearance under the feet,
      and an ordinary jump peaks at 1.33 m. Outside a grapple arc,
      "commits when they leave the ground" never happened.
    - In `c011`, jumping drew 0 dives. The only damage came from a
      bulwark.
  - **Its dives could not arrive.** It committed from its 18 m notice
    radius, but a dive carries only 6.3 m (7 m/s for 0.9 s). It waited
    8.1 m away.
  - **It dived at players it could not see:** 2 dives committed through
    a wall.
  - **The drifter was never silent.** Against a stationary player it
    fired 3 shots, with 3 hits and 21 damage. But no shot was telegraphed:
    the F-14 defect the ranged role once had.
  - **A waiting diver looked no different from an idle one.**
- **The repair:**
  - **The trigger follows the jump.** This is a shared edit, recorded in
    the seam table. `DIVER_TRIGGER_HEIGHT` is now 0.8 m, three fifths of
    the jump's apex. The engine reads it as written; the extra 0.2 m is
    gone. An ordinary jump is above it for 0.42 s; a step down a stair or
    a kerb is not.
  - **A dive that can arrive, at a player it can see.**
    - The diver commits only within its dive reach (carry plus 1.6 m
      contact: 7.9 m), measured body to body, with line of sight.
    - It waits within striking distance (70% of that reach), not at the
      edge of what it can see.
    - `reach` stays its notice radius.
  - **A dive lands only on a body it has reached and can see:** contact
    within 1.6 m, with nothing solid between.
  - **The drifter's shot is committed, then fired,** after a 0.45 s
    "aim" windup, as the ranged role's is. Sight is checked when the shot
    is committed.
  - **States you can read, in the eye.**
    - Every role's eye flares while it telegraphs.
    - A flyer's eye is low while idle and burns steady once it has
      noticed the player. A waiting diver is watching, and now looks it.
    - The body is deliberately not pitched toward its target. A first cut
      did that, and it pushed the drawn diver outside its hitbox: the
      H-FLYER-HIT same-box check caught it.
- **Evidence:** `make godot-combat-fairness`, 50 checks.
  - **Drifter:**
    - stationary player: 3 telegraphed, 3 launched, 2 impacts, 14 damage;
    - strafing: 3 launched, 0 impacts (the windup makes it dodgeable);
    - jumping: 3 launched;
    - behind a wall: 0; at 30 m: 0;
    - its eye flares while it aims.
  - **Diver:**
    - standing or strafing: it notices the player every frame and waits
      (0 dives), within its dive reach;
    - its eye burns at the watching level, against the idle level with no
      one there;
    - ordinary jumps: 3 telegraphs, 2 dives, 2 impacts, 24 damage;
    - jumping while strafing: 2 dives, 1 landed. It is not a homing hit
      (P06.4);
    - held where a grapple arc puts the player: 2 dives, 2 impacts;
    - behind a wall: 0;
    - **a wall raised across a committed dive:** 0 impacts, though its
      body ends 1.50 m from the player's (contact is 1.6 m);
    - **a player already in the air 14 m off:** it closes first. Its
      farthest commit is 7.9 m, its dive reach; 2 dives, 2 landed;
    - at 30 m: 0.
  - **In the room the owner played:** `make godot-flyer-room`, new, 7
    checks, in CI.
    - The player is placed at `c011`'s own arrival, a declared harness
      step (see `PPT-01`). Everything after that is played.
    - Standing for 5 s: 0 dives, and 5 of 5 divers are watching.
    - Jumping for 6 s: 5 dives, 4 diver impacts, 48 damage. A bulwark
      from the uncleared `c009` followed the player in and landed 4 more;
      those are attributed by name and not counted as the divers'.
    - Cleared with the Static Pulse aimed at their bodies: 5 of 5 dead in
      7.0 s, counted from `enemy_died`, and kill_all is satisfied.
    - The same driver on the old runtime: 0 of 5 watching, 0 dives from
      jumping.
- **Sabotages (each restored byte for byte, each failing by name):**
  - **SA-A,** the trigger back at 1.6 m: 5 fail. Ordinary jumps draw no
    dive; nothing lands; the evading case gets no dive to evade; the
    raised-wall case never commits; the eye never flares.
  - **SA-B,** a dive committed without sight: "airborne player behind a
    wall" fails (2 dives).
  - **SA-C1,** the diver waiting at the ordinary stand-off: 6 fail. Its
    dives cannot arrive, and it waits 8.1 m away.
  - **SA-C2,** a dive committed from its whole notice radius: "in the air
    14 m off" fails, with the farthest commit at 14.3 m.
    - This check was twice wrong before it had teeth.
    - At first the probe let the player fall during the settle, so the
      diver had already closed in.
    - Then it counted commits only inside the window, and the sabotaged
      diver's 14 m commit came during the settle.
    - Each was corrected in the probe, never in the rule, and SA-C2 was
      re-run each time.
  - **SA-D,** the drifter firing with nothing to see first: 3 fail (no
    telegraph, and no eye flare).
  - **SA-E,** a dive landing by distance alone: the raised-wall case fails
    (1 impact through the wall).
  - **SA-F,** no eye states: "waiting reads as watching" fails (2.40
    against 2.40).
- **A test that measured the old trigger, corrected (not weakened):**
  `roster_driver`'s diver case placed its "standing" player a metre up,
  in the same frame as the diver. It spent its first frames dropping
  that metre, which is in the air by the new rule. It now lands before
  the diver exists, and the check also asks that it is on the floor.
  `godot-roster` 52.
- **Other neighbours, green:** `godot-status-family` 15,
  `godot-encounter` 51, `godot-content`, `godot-counterfire` 59,
  `godot-hud`, `godot-legible`, `test-schemas` 131, `test-bridge` 1936,
  and `check_packet.py`.
- **What the owner will notice:**
  - Jumping near divers now draws them.
  - They wait within striking distance with their eyes lit. When they
    commit, the eye flares and the body swells for 0.35 s, then they dive
    at where the player was. Moving after landing avoids it.
  - A drifter takes a visible 0.45 s aim before each shot.
- **`PPT-01` (noted, not fixed; a harness limit, not a proven game
  defect):** on `candidate_zone.json`, the suites' spine walker
  (`transport_driver._advance_to` with clearing) stalls in `c003`'s
  platform course after clearing `c002`.
- **Placement purpose (for Dess, recorded, not changed):**
  - With jumps counting, a diver contests the air anywhere a player
    jumps, and `c011`'s gallery gives its five a purpose.
  - A generator rule that places divers where the layout asks the player
    to leave the ground (gaps, anchors, galleries) is a composition
    question for Dess's lane.

## CP1 — `H-RESUME-R` (PT-16, D-06): an encounter resumes as it was left — repaired

- **Reproduced first, through two real processes,** on the unmodified
  runtime at `499cec8`
  (`post_playtest_evidence/H-RESUME-R_repro_on_499cec8.log`).
  - The room is `c005`, the power-cell room of the candidate the owner
    played: two bulwarks, and a warp station that comes online when the
    room's puzzle is solved.
  - One bulwark was killed. Both processes were killed and relaunched.
  - **The killed bulwark was back (2 of 2),** and the player was restored
    AT THE STATION, 3.0 m from a live bulwark.
  - This is PT-16's mechanism. Every room of 260 m² or more gets a
    station near its middle, arenas included, and the first bulwark's
    post lands almost on it. A resume put the player there and rebuilt
    every enemy from the Zone data.
- **No existing authoritative state proves a defeat.** The saved Zone
  progress holds keys, locks, stations, latches, the macro state, object
  rooms, poses and consumers, and carrier rests. Nothing in it is about
  an enemy. The packet rules out inferring kills from a claimed Check. So
  an older save's encounter state is genuinely unknown.
- **The contract** is a shared edit (seam table), the narrowest D-06
  needs:
  - **Identity:** `room/archetype#n`, the n-th spawn of that archetype in
    that room's declared `enemies`, in declaration order. That is the
    order every room builder lays them out in, so the engine and the
    bridge derive the same identity from the same declaration.
    - It is not an engine node path.
    - No health, timer or position is saved.
  - **Record:** `ZoneProgress.defeated` is monotone and idempotent.
    Ordinary quit and reload are not resets.
  - **`None` is not "nobody"; it means unknown:** a save written before
    the record existed. The first defeat after such an entry starts the
    record, and that entry had built every member. This is D-06's "from
    that point onward".
  - **Consistency, not trust:** `record_defeat` refuses a room the Zone
    does not have, an archetype that room does not declare, and an
    ordinal past the declared count.
- **The runtime:**
  - Each spawned enemy carries its declared identity.
  - A member the save records as defeated is **never built.** It is
    skipped in `setup`, before the first physics step, so it is absent
    before anything can perceive or attack.
  - A death is reported once under its identity. The in-flight half is
    remembered for a Hub return, like keys.
  - **The resumed player is never put among the living.**
    - If the room the resume point stands in holds any living member of
      its encounter (survivors of a partial clear, or everyone in an
      unknown save), the player is restored at THAT room's arrival: the
      doorway its encounter was composed to be entered from.
    - The player is told why: "1 LEFT IN C005 -- YOU START AT ITS
      ENTRANCE." For an unknown save: "NO RECORD OF WHICH ENEMIES FELL IN
      THIS SAVE -- C005'S ENCOUNTER IS BACK. YOU START AT ITS ENTRANCE."
    - The rest of the save is untouched.
    - It all happens inside `setup`. Enemies already ignore a player held
      for the layout verdict (`Enemy._find_player`), so nothing strikes
      during the build.
- **Evidence:**
  - **`make godot-resume-live`** (new, in CI) runs five phases. Each is a
    new client beside a new bridge (`--candidate=all`), and only the save
    crosses.
    - **partial:** `c005/bulwark#0` killed; the bridge holds exactly that.
    - **partial_restore:** 1 bulwark at control, the killed one absent.
      The player is at `c005`'s arrival, 10.9 m from the survivor. 0
      strikes during the build and 0 in the next 5 s. Then the survivor
      is killed.
    - **clear_restore:** no bulwark and kill_all satisfied. With nobody
      left, the player is back AT the station. 0 strikes.
    - **legacy:** a COPY made after `partial`, with the record stripped
      by `tools/strip_encounter_record.py`. That tool refuses any
      directory but a resume-test copy, and it deletes the `.bak`, which
      would still hold the record.
      - Both bulwarks are back: nothing is invented.
      - The player is at the arrival, 6.9 m from the nearest, and TOLD
        why. 0 strikes during the build.
      - The next kill starts the record: `["c005/bulwark#0"]`.
  - **`make godot-resume`** (new, in CI): 12 checks on the real
    `ZoneController`, read before the first physics step.
    - a partial clear, a full clear, no record, and a first entry
      (unchanged: the Zone's own arrival, nothing said);
    - one death gives one `enemy_defeated`, under its identity;
    - another room's encounter is untouched.
  - **`bridge/tests/test_encounter_resume.py`,** 15 tests:
    - unknown is not "nobody";
    - monotone and idempotent;
    - an older save's JSON loads as unknown;
    - the §5.1 category;
    - six malformed identities never parse;
    - an undeclared room, archetype or ordinal is refused;
    - every declared member, and not one more, can be recorded;
    - the record survives a bridge restart.
- **Sabotages (each restored byte for byte, each failing by name):**
  - **SR1,** the defeated built anyway: 4 fail offline. The defeated
    bulwark is back, the cleared room is not satisfied, and a cleared
    room still moves the player off its station.
  - **SR2,** the player left where the resume put them: 4 fail, "at
    the station among the living", and nothing is said.
  - **SR5,** a death not reported: "one death, one report" fails (0
    sent).
  - **SR6,** moved but not told: the unknown-save notice check fails.
  - **SR3,** an identity trusted from the client: "an undeclared member
    never becomes save data" fails.
  - **SR4,** an unknown record that never starts: 6 fail.
  - **SR1L, the packet's own named control** ("omit saved-defeat
    restoration and the reload case fails"), run through two real
    processes: `godot-resume-live` fails in `partial_restore`, with the
    killed bulwark back ("2 alive in c005").
- **Refinement, before the checkpoint:** the protection applies only to a
  RESUME, meaning a player restored at a station. An ordinary entry
  already starts at the Zone's own arrival, the doorway the Zone was
  composed to be entered from, so it is neither moved nor narrated. The
  offline suite's first-entry case holds it (12 of 12).
- **`PPT-02` (observed, not investigated):** in `partial_restore`, the
  bridge also recorded `c006/melee#0`. `c006` is the 40 × 59 m transit
  hall. Its melee chased the player toward `c005`, walked off the hall's
  drop, and died by the existing fall-kill rule (`ENEMY_FALL_KILL_Y`,
  "counts as dead: kill_all stays satisfiable"). The defeat was recorded
  like any other, which is consistent with that rule. Whether a melee
  should be composed where it can walk off that drop is a placement
  question, not this one.
- **What the owner will notice:**
  - Quitting and reloading keeps every kill.
  - A room left half-cleared starts you at its entrance, with the
    survivors at their posts and a line saying how many are left.
  - A cleared room starts you at its station.
  - The first time an older save (like the played one) is loaded, any
    room you resume in starts you at its entrance, with its encounter
    back and a line saying why. From then on, kills are kept.

## CP1 checkpoint — closed (the full frontier, twice)

- **On `76b0952` (before the handback):** 66 of 68 steps passed
  (`CP1_frontier_on_76b0952.tsv`). The two failures were DESS-19 and
  DESS-20, both from H-RESUME-R's shared edit, fixed at `f332fff` (the
  seam table's last row).
- **On `5f348ab` (the handback head, with Dess's eight commits):** 67 of
  68 passed (`CP1_frontier_on_5f348ab.tsv`). The one failure was this
  lane's own test over-asserting, not the game
  (`CP1_resume_live_legacy_overassertion_on_5f348ab.log`):
  - `godot-resume-live`'s legacy phase required the bridge's record to
    be exactly the bulwark it killed. It also held `c006/melee#0`: that
    melee chased the player off the transit hall's drop and died by the
    fall rule (PPT-02). Whether it happens is timing; on `76b0952` it
    did not.
  - Fixed at `72392d8`, stricter rather than looser: every
    `enemy_died` the engine emits is collected by declared identity,
    and the record must equal exactly that set and hold the kill. It
    fails if the bridge invents a death or misses one. Three
    consecutive two-process runs pass.
- **CP1 is closed.** The frontier was not re-run in full for a
  test-only change; the next full run is CP2's checkpoint.

## CP2 — `H-PRESSURE-R` (D-07), the engine's half — landed

The contract is Dess's D13 (H-PRESSURE-C). Its bridge half, 1a to 1c,
is Dess's after the W0.1 handback. This is the engine's half, which D13
orders first: "the bridge must not admit a Zone lever before
`RoomGraphs` can place one".

- **Reproduction, on `76b0952`** (`H-PRESSURE-R_repro_step_once_on_76b0952.log`,
  the CP1 frontier's own raw log of `godot-latched-route`). One step on
  the plate, then fully off it: the plate reads empty (`"satisfied":
  false`), "the latch still holds", and "the way opens fully with nobody
  on the plate (openness 1.00)". That is exactly the step-once plate D-07
  rejects.
- **What changed:**
  - A declared `PULSE_BUTTON` is built as a **lever** labelled "THROW
    BOLT -- OPENS THE SHUTTER".
  - Once the LATCH it feeds is set, live or restored from the save, the
    lever **stays thrown**, its prompt reads "BOLT THROWN -- THE WAY IS
    OPEN", and a second pull does nothing (`SignalGraph.lock_permanent_levers`).
  - A call control, and a minor's own lever, names no latch and is never
    locked.
  - The builder keeps **its own placeable list** (N-4).
  - **Levers are placed by a measured rule.** A spot is refused while
    anything solid the room built stands over the lever's footprint, up
    to a standing player's height, or crowds all four of its
    body-width approach sides. When the authored spots all fail, the
    rest of the floor on the room's side of the doorway is searched,
    nearest the door first.
  - **Legacy plates are placed exactly as before (M-1).**
- **`PPT-04`, found by the lever's own test.** The route spot in the
  latch fixture's `c002` is inside a 1.13 m cover block, under a gallery
  whose underside is 1.61 m off the floor.
  - A plate there could still be stepped on. The old played acceptance
    passed, and a saved Zone keeps playing it (M-1).
  - A lever there cannot be aimed at: the interact ray stopped on the
    block.
  - The measured rule puts the lever 2.4 m in from the doorway and
    3.2 m to its side, clear.
- **Regression** (`H-PRESSURE-R_after.log`):
  - `godot-latched-route`, 73 checks. It plays both forms whatever the
    fixture declares:
    - the Zone as composed, today the legacy plate, played as saved;
    - the lever, by explicit substitution of the route's one sensor,
      with the same room, doorway, LATCH and shutter;
    - V-08's control: an ordinary plate on the same shutter, with no
      latch, shuts again when stepped off.
  - `godot-signal-graph`, 61 checks, including the placeable-list order.
  - `godot-graphs`, `godot-zone-state` (60) and `godot-reversible` (32)
    are unchanged and green.
- **Sabotages** (`H-PRESSURE-R_sabotages.log`), each restored
  byte-for-byte:
  - SP-1: a latched lever springs back. "the lever STAYS THROWN" and
    "pulling it again does nothing" fail.
  - SP-2: the builder cannot place a lever. "the builder can place a
    lever" fails.
  - SP-4: legacy plates are placed by the measured rule. The saved
    route's graph is refused in `c002`, which is the M-1 regression the
    split exists to prevent.
  - **SP-3, as first written, was not caught.** It placed levers by the
    old rule, but with the lever's own smaller footprint the old list
    happens to pick a clear spot. So it was not the defect.
  - SP-3′ reproduces the defect itself: the lever at the plate's old
    spot. The interact ray misses and the THROW fails, with 8 failures.
- **Scope, stated:** offline.
  - The live suites (`godot-latched-route-live`, `godot-candidate-live`)
    play the committed fixtures. Those still declare the legacy plate
    until Dess's 1b regenerates them, so they are unchanged here.
  - Switching them to the lever is Prod's, after that.
- **What the owner will notice:** nothing yet in the played candidate,
  whose saved Zones keep their step-once plates (M-1). Once Dess's
  composer writes the lever, a new route shows a bolt lever that stays
  thrown and says the way is open. A plate is only ever a held sensor.

## CP2 — `H-UNWEIGHTED` (PT-05, D12's card) — repaired

PT-05: "saw an indestructible crate moved very slowly by a lever, did
not understand the goal, and walked to the Check." D12 (Dess's
H-RELEASE-C) is the contract. It says what must be true, and the
physical proposal is Prod's. Both proposals below were agreed by Dess
(N-1, N-2), and N-2 is flagged to the owner.

- **Reproductions, on the room as it stood** (unchanged from `76b0952`):
  - **The Check claimed from the floor**
    (`H-UNWEIGHTED_repro_census.log`).
    - The new census found 7 floor cells under the north wall's high
      return gap from which a hop puts the Check inside the claim ray's
      3 m.
    - Played: the real player walked from the arrival to one of them
      and hopped, the prompt read "[E] CLAIM CHECK 055", and a claim
      went out with nothing solved.
  - **The gallery reached from the carriage in transit.**
    - Ridden toward the recess, the carriage was a step within a
      running jump of the sill before its weight reached the plate.
    - A single ride-and-jump landed on G with `lightened` never applied.
    - The sweep that now guards it reproduces this on the old plate: 7
      of 14 jump points reach G, from 3.4 m to 1.6 m from the wall.
- **The room card, as built:**

| Field | Now |
|---|---|
| Arrival read | Upper doorway with "SERVICE CROSSING", the sill too high, the carriage in its bay. The weighbridge reads "A HEAVY LOAD ON IT SHUTS THE CROSSING" |
| Visible objective | The Check on G's middle, straight through the upper doorway: where the scenario's own goal plate always stood |
| Obstruction | The sill (1.9 m), and the weighbridge that holds the crossing shut while the HEAVY carriage is anywhere it is a step within reach |
| Controls | The service drive (2.3 m/s, was 1.1); the LIGHTENER, whose sign says what it does; the HOLD-OPEN BOLT on G, whose sign says it keeps the crossing open and lowers the return stair |
| State | Carriage placed: shut. Placed and `lightened`: open, with the step still there. The carriage's own readout says what it reads, and for how long |
| Valid alternates | Blink, double jump and grapple reach G (V-10: 24, 9 and 7 arrivals); a lighter object in the recess; standing in the closing shutter (interlock). None is nerfed |
| Refused bypasses | Any claim from outside G, by walk, hop, rail, carriage, blink, double jump or grapple. The carriage ridden in transit |
| Reward | The claim on G. Not gated on the bolt (D12 R1) |
| Return | Back down through the return gap after any arrival; the bolt's stair after it is pulled. The bolt stays thrown and says so |
| Reset/reload | Unchanged: the bolt persistent, `lightened` ephemeral, the carriage package-local |

- **What changed:**
  - The Check's objective volume moved within G. In the room's own
    frame it was at x 6.0, z 9.5, beside the return gap; it is now at
    x 0.0, z 10.2, beyond the upper doorway, 3.35 m from the nearest
    floor cell. In the registry's frame (entry at z 0) that is
    `[6.0, 1.9, 16.75]` to `[0.0, 1.9, 17.45]`: registry geometry (N-1,
    agreed).
  - The HEAVY plate runs back along the drive lane as a **weighbridge**
    to z 2.3, so the carriage is on it wherever it is a step within
    reach of the sill. Parked, it is clear of it, so §4's opening state
    is unchanged: the crossing starts open (N-2, agreed).
  - The drive runs at 2.3 m/s, where it was 1.1.
  - There are signs for the crossing, the weighbridge, the lightener and
    the bolt. They say what each thing does, never the order to do it
    in.
  - The carriage has a live readout ("READS HEAVY", "LIGHTENED: READS
    MEDIUM 6 s").
  - The carriage is dressed as guided service hardware: frame, deck,
    buffers, hazard banding, and guide shoes on the rails. It is meshes
    only and provisional, for Arty's H-MACHINE-ART; the collider is the
    same 2 x 1 x 2 m box.
  - The bolt now stays thrown once its latch is set, restored saves
    included: "BOLT HELD -- CROSSING OPEN, RETURN STAIR DOWN" (D-07's
    permanence, `CallLever.done_label`).
- **`godot-minor-claim`**, new and in CI, has 17 checks on the played
  candidate:
  - every declared minor is built as itself;
  - a claim census of each hosted room, with a played witness when it
    finds anything;
  - G unreached from the arrival as built;
  - V-10 at the schema maxima: 8,680 blinks, plus double-jump and
    grapple flights, with zero claims off G;
  - the ride sweep of 14 jump points;
  - the return after an alternate arrival, and again after the bolt.
- **Sabotages** (`H-UNWEIGHTED_sabotages.log`), each restored
  byte-for-byte: the Check back at its old spot (SU-1), the old plate
  and drive (SU-2), the bolt springing back (SU-3), the return gap
  walled up (SU-4) and the Unweighted shell refused (SU-5). Each fails
  by name.
  - Two of them first exposed holes in this suite, fixed before it was
    trusted.
  - The ride sweep counted a landing on the sill as a miss, so on the
    old plate it passed. It now counts the crossing, and fails there.
  - A refused shell made the census measure one room fewer and pass.
    The suite now requires every declared minor.
- **`godot-unweighted`'s crate-top walk.** The walker counted 1.4 m from
  the carriage's centre as arrived. That is also its south edge, where a
  body perches off the floor. The room as it was passed. The repaired
  room perched, with each change (weighbridge, drive speed, skin,
  readout) reverted in turn. The walk now goes into the top's footprint
  and waits to land. The assertion is unchanged, and 70 checks are
  green.
- **What the owner will notice:**
  - The Check is visible through the upper doorway and can only be
    taken on the gallery.
  - The carriage drives twice as fast, looks like a guided machine, and
    says what it weighs.
  - Standing on it while it drives no longer gets you up. The lightener
    is the way, or a movement power.
  - The bolt stays thrown once pulled.

## CP2 — `H-PRESSURE-R`: the lever route played live (Dess's D-7.2, D-7.3)

Dess's 1c (`462bf42`) composes `lever -> LATCH -> shutter`, and
`lever_route_zone.json` is that composer's output on the played Zone:
the lever in c002, the shutter across `e:c002:c003`.

- **`godot-latched-route-live` takes a form** (`LATCH_FORM`, default
  `legacy`).
  - The seed tool gets `--form` and the matching `--expect` fixture.
  - The driver gets `--latched-form=`. It checks that the served Zone
    declares that form's control (a `PRESSURE_PLATE` for legacy, a
    `PULSE_BUTTON` for the lever) and that the control is built as
    one, before it plays anything.
  - The legacy form is unchanged apart from that check: M-1's replay
    still steps on and off the plate (play 19, restore 13).
- **`godot-lever-route-live`** (new, in CI) runs the lever form in its
  own save directory (`H-PRESSURE-R_lever_live.log`):
  - seed: the real path generates zone_001 with no graph; the tool
    composes the lever route, identical to the fixture;
  - play (20 checks): the arena cleared with the base kit; the bolt
    pulled once with the real interact; one real `latch_fired`,
    accepted, in the snapshot and in the save file on disk; the forged
    latches refused; the bolt stays thrown and says so ("BOLT THROWN --
    THE WAY IS OPEN"); the way open with nobody at the lever; through
    into c003;
  - restore (14 checks), both processes new: the latch handed back
    before the first evaluation, the way open at once, nothing
    announced, **the bolt restored thrown** and never pulled in this
    process, and the doorway walked through.
- **Sabotages** (`H-PRESSURE-R_lever_live_sabotages.log`), each
  restored byte for byte:
  - SL-1, a restored latch no longer locks its lever (only a fresh throw
    does): the restore fails by name, "the bolt is restored THROWN"
    reading `[E] THROW BOLT -- OPENS THE SHUTTER`.
  - SL-2, the play phase told `legacy` on a lever seed: it fails at the
    form check before playing.
- **The fixture targets (D-7.3):** `lever-route-fixture` and
  `held-route-fixture` are added with Dess's recipes, and
  `latched-route-fixture`'s comment now calls its fixture M-1's legacy
  input. All three regenerate byte-identical to the committed fixtures.
- **What the owner will notice:** nothing new in the played candidate
  (M-1). A newly composed route shows the bolt, which is covered here
  across a real restart.

## CP2 — `H-PRESSURE-R`: the held route played (Dess's D-4) — repaired

D13 1d is D-07's held sensor with D-07's guarantee: "Pressure present =
active. Pressure removed = inactive. [...] there must be a guaranteed
physical way to keep pressure on it, such as a movable object/weight."
Dess's `held_route_zone.json` is the played Zone with an object-only
MEDIUM plate in c002, `held_by` a 40 kg `counterweight` homed in c002
(volume c001 and c002), driving the shutter across `e:c002:c003`
directly, with no LATCH.

- **The reproduction, on the fixture as it stood**
  (`H-PRESSURE-R_held_repro.log`). The new `godot-held-route` played it
  with the real player: 14 of 28 checks failed.
  - The engine placed the held plate at the legacy spot, because it
    placed every plate there (M-1). In c002 that spot is entirely under
    the low gallery (under 2 m of headroom), beside its support post.
    The survey in the log maps it.
  - A player cannot stand under it, and a carried weight rides at about
    1.4 m, so the carry sweep met the gallery and held the weight back:
    every attempt stopped 2.2 to 2.6 m from the plate's centre.
  - **The declared weight could not be put on the plate at all**, so
    the door could never be held open. The route the bridge certified
    was physically impossible in the engine.
- **The repair (engine only, `room_graphs.gd`):**
  - **A held plate is placed by the measured rule, as a lever is.** No
    saved Zone ever held one, so M-1 does not pin it to the legacy spot.
    Legacy step-once plates are placed exactly as before.
  - **It is a load pad, 1.4 m square** (`HELD_PLATE_SIZE`). It takes one
    carried 0.34 m weight, not a crate or a person. At the full 2.4 m
    the measured rule found no clear floor in c002 and refused the graph
    (SH-2 below).
  - **It says what holds it:** "LOAD PLATE -- HOLDS THE SHUTTER OPEN /
    WHILE THE COUNTERWEIGHT RESTS ON IT". **The weight says what it is
    for:** "COUNTERWEIGHT · 40 kg / FOR THE LOAD PLATE". Both are
    presentation, read from `held_by`; the weight's identity, mass and
    rules stay the declaration's.
- **Played after the repair** (`godot-held-route`, new, in CI; 33
  checks; `H-PRESSURE-R_held_after.log`):
  - build: nothing refused; an object-only MEDIUM plate; one 40 kg MEDIUM
    weight at home; the doorway shut; both signs present and naming each
    other. The pad stands
    3.4 m from its doorway, and the weight's home is 8.3 m from it;
  - played:
    - the rooms cleared with the base kit;
    - the player standing on the pad reads nothing, and the doorway
      stays shut (object-only);
    - the weight picked up with the interact ray, carried on, and put
      down 0.09 m from the pad's centre; the pad reads MEDIUM, and one
      `object_settled` is reported;
    - the doorway opens, and stays open for 5 s with nobody near;
    - through into c003 and back the same way;
    - lifted, it shuts, and nothing latched; put back, it opens again;
      the reported pose is exactly where the weight lies;
  - reloaded: a rebuild from that pose alone, with no latch and no plate
    state, puts one weight back where it was left, and the doorway opens;
  - the interlock: with the player standing in the open doorway, the
    weight is moved off the pad. The panel is refused its closure 3
    times, never comes below fully open, costs no health and moves the
    player 0 m. Stepping out, it shuts.
- **Declared harness steps:**
  - releasing the layout hold with no bridge;
  - the rebuild from the reported pose, standing in for the bridge's
    `object_poses` across a reload;
  - the interlock's move of the weight. A hand cannot lift it from the
    doorway here: the pad is 3.4 m away and the interact ray reaches
    3 m. So the move stands in for anything else that shifts the weight
    while somebody is under the panel.
- **Sabotages** (`H-PRESSURE-R_held_sabotages.log`), each restored byte
  for byte:

| # | Rule removed | Caught by |
|---|---|---|
| SH-1 | a held plate placed by the legacy rule again | 14 failures: the reproduction returns. The carry stops short, the weight is never put down, and the doorway never opens |
| SH-2 | a held plate at the full 2.4 m | the build refuses the graph: "no clear floor for sensor 'weight_plate'" |
| SH-3 | the declared weight never named | "the weight says what it is for: '(no label)'" |
| SH-4 | the held plate counts the player | "an object-only MEDIUM plate", and standing on it reads MEDIUM |
| SH-5 | the panel stays open once opened (a latch in disguise) | "LIFTED ... the doorway SHUTS (1.00 open)", and both interlock checks |
| SH-6 | the interlock does not watch the player | "(occupied false)", and the panel comes down fully on the player, moving them 0.54 m |

- **What stays open:**
  - The reload here is a harness rebuild. A real restart through the
    bridge needs the seed tool to compose this route onto a live Zone,
    and `tools/compose_latched_route.py` is Dess's; note N-8 asks for a
    `--form held`.
  - D-4's "lifting the weight while the player is in the doorway" cannot
    be done by hand at this geometry, as above. The interlock is shown
    with the declared move.
- **What the owner will notice:** nothing in the played candidate, which
  has no held route. A composed held route now puts a labelled load pad
  on open floor, with a labelled weight, and the door is open exactly
  while the weight rests on it.

## CP2 — `H-COUNTERFIRE` (PT-04, D12's card, V-11) — identified, played, repaired

PT-04: "Possibly two Counterfires; shot a target, emergency door opened,
took Check." The packet asks, in this order:
- identify the owner's instance;
- keep legitimate alternates;
- make gunner, receiver, shutter and reward read as one relationship
  without printing the answer;
- make sure a dead gunner never strands the reward.

- **Identification.**
  - **There really are two.** The minors' offer order turns with the
    Zone's ordinal (`minor_hosting.offer_order`). So the candidate hosts
    EX50-021 in zone_001 (c025) and again in zone_002 (c024), as the
    candidate-live logs show.
  - **The "emergency" target is the room's own receiver.** Its sign read
    "EMERGENCY IMPACT TRIP / SERVICE SHUTTER", and a hit on its face
    opens the shutter for 8 s. That is the designed relationship
    (EX50-021 §3), not an unrelated control.
  - **The owner's route is legitimate, so nothing is removed.** A shot on
    the receiver's face from the lane side is the designed conservative
    route (§6; D12's "baseline shot at the receiver's face").
  - **Which occurrence the owner played is not in anything we hold.**
    Their save would show it once the game sends `room_entered` (Dess's
    D-2), which lands with the CP4 map work.
- **Played on the hosted room as it stood** (`godot-counterfire-hosted`,
  new; `H-COUNTERFIRE_repro.log`): 10 of 23 checks failed.
  - **The owner's route works.** The Zone's gunner was killed with the
    base kit (4.2 s, 8 hp), the receiver shot on its face from the lane,
    the shutter passed with 5.1 s left, the flank climbed and the Check
    claimed. A dead gunner strands nothing.
  - **The hood holds:** 0 of 97 shots from the arrival side trip it, and
    130 of 393 from the lane side do.
  - **Legibility failed, as reported:**
    - the trip read "EMERGENCY";
    - nothing between the receiver and the shutter changed while the
      window ran;
    - the shutter had no readout;
    - the release sprang back.
  - **PPT-05, found by the new void census: two places dropped a player
    out of the world** (the survey is in the log).
    - The top of the 2.6 m low wall is a 0.4 m step down from the
      flank's reach, and it led onto a strip with nothing under it for
      44 m.
    - Under the flank, north of the annex floor, there was no ground.
  - **PPT-06, found by the return case: the flank could not be walked
    past the Check.**
    - The Check's 1.4 m collider stood on a 1.7 m flank, leaving 0.1 m
      and 0.2 m either side.
    - Stepping round it put the walker off the edge and into PPT-05's
      hole under the flank.
    - So the stair the release lowers, and the reach over the low wall,
      could not be walked to from where the flank is reached. The return
      that did work was through the held-open shutter.
    - I also blamed the 0.8 m slot over the low wall (the hosted
      pocket's north wall against the arcade's east wall, exactly the
      player's width). SC-7 shows a centred walk passes it, so that was
      not established.
- **The repair:**
  - **The trip says what it does:** "IMPACT TRIP / A HIT ON ITS FACE
    OPENS / THE SERVICE SHUTTER FOR 8 s". Nothing names the gunner, the
    bait or the dodge (D12: "without printing the answer on entry").
  - **The conduit from the receiver to the shutter glows** while the
    window runs, and for good once the release is thrown.
  - **The shutter has a live readout:** "SHUT", "OPEN · 6 s",
    "CLOSING", "HELD OPEN BY THE RELEASE".
  - **The release stays thrown and says so**, after a real restart too:
    "RELEASE THROWN -- SHUTTER HELD OPEN, STAIR DOWN" (`locks_with`,
    D-07).
  - **North of the annex is one solid mass, decked at the flank's
    height.**
    - The upper level is now 5.5 m wide, which on its own makes the flank
      walkable round the Check (SC-8, quick).
    - The north-east corner is solid.
    - The hosted pocket's north wall is gone, now that the solid corner
      closes the north. The way over the low wall is 1.2 m: margin for a
      player who is not walking dead centre, not a repair (SC-7).
  - **The Check moved within the flank**, to its north-east corner. Its
    registry volume went from `[13.65, 3.0, 12.25]` to
    `[13.85, 3.0, 16.55]`.
    - At its old spot, above the annex and near the stair, a double jump
      from the annex floor claims it from off the flank. SC-8 on the
      whole suite shows this: V-10 fails there.
  - **The shell's declared surfaces follow the geometry.** `annex_pocket`
    (at ground level) becomes `deck` (y 3), so the shell audit still
    accepts the room.
- **V-10 caught my first repair.** Flooring the pocket fixed PPT-05's
  second hole, but it made the pocket somewhere to double-jump or
  grapple from and claim the Check over the flank's edge (4 off-flank
  claims). The solid deck is what replaced it.
- **Played after the repair** (25 checks, `H-COUNTERFIRE_after.log`):
  - what the room says, as built and while the window runs;
  - no step off any of 7,906 reached cells lands on nothing;
  - the owner's route, with the gunner dead;
  - back from the flank with nothing pulled, off the reach onto the
    gallery;
  - the hood census;
  - V-10 at the schema maxima: 17,444 blinks and 18 flights, 16 legal
    arrivals on the flank, and no claim from anywhere else;
  - the release thrown for good, down its stair, and back to the arrival.
- **The gunner-driven route** (the bait) is played live through the real
  bridge by `godot-candidate-live`: the gunner baited, the release
  accepted, and Check 89100025 claimed. After a real restart the release
  is restored thrown (a new check there).
- **Declared harness steps:**
  - the census places the player on each sampled cell before firing;
  - `_mobility` places them for each blink and flight, and each case
    returns them to the room's arrival;
  - `ap_connected` is set so a claim can go out with no bridge;
  - the player's health is raised for the V-10 sweep only.
- **Sabotages** (`H-COUNTERFIRE_sabotages.log`), each restored byte for
  byte, on the suite without the V-10 sweep:

| # | Rule removed | Caught by |
|---|---|---|
| SC-1 | the trip says "EMERGENCY IMPACT TRIP" again | "the trip names what it does" |
| SC-2 | the conduit never lights | "the conduit ... LIGHTS while the window runs (0 glowing, 0 before)" |
| SC-3 | the shutter readout never changes | "the shutter says how long it has: 'SERVICE SHUTTER / SHUT'" |
| SC-4 | the release springs back like a call lever | "the release STAYS THROWN": `[E] SERVICE RELEASE ...` |
| SC-5 | the north-east corner open again (PPT-05) | the void census, at the reach's north edge |
| SC-6 | no deck: the pocket floorless under an open flank edge | the void census, under the flank |
| SC-7 | the pocket's north wall back (the 0.8 m slot) | **passes**: a centred walk goes through, so the slot was not a defect, and its removal is margin |
| SC-8 | the Check back at its old spot | **passes the quick suite** (the deck makes the flank walkable). On the whole suite, V-10 fails with a double-jump claim from the annex floor, which is why it moved |
| SC-9 | no hood: the receiver answers either side | the hood census: 59 of 98 arrival-side shots trip it |

- **What the owner will notice:**
  - The target over the lane says it opens the service shutter for 8 s.
  - A hit lights the line from the target to the shutter, and the
    shutter counts down.
  - The release stays thrown, and its stair can now be walked to.
  - The upper level is a proper deck, with nothing to fall off into.
  - The Check stands in the far corner of the deck.

## CP2 — `H-PASSING` (PT-06, PT-07, D12's card): reproduced, and the proposal stated before rebuilding

Delivery plan §4 and D12's card ask that the proposal ("a visible
machinery-locked cabinet or a destination mechanism") be stated before
the room is rebuilt. It is stated here, and the rebuild follows in its
own commit.

- **Played on the hosted room as it stands** (zone_002/c025; the Zone
  captured unedited from the real bridge by `godot-candidate-live`'s
  next phase, never committed; N-10 asks Dess for the fixture;
  `H-PASSING_repro.log`).
  - **PT-06 reproduced.** 233 cells reached from the arrival claim the
    Check with no transfer made. They all stand on the recovery floor
    just west of G, where a hop lifts the eye to 3.9 m, 0.1 m under G's
    floor, and the claim ray skims over G's west lip. Played: the real
    player walked there, hopped, read "[E] CLAIM CHECK 047", and a claim
    went out.
  - **Moving the Check cannot fix it.** The Check was moved over 45
    spots on G and the census re-taken at each: every spot is still
    claimed from that floor, 10 cells at the least. G is 2.95 m wide,
    the claim reaches 3 m, and the lip stands 0.1 m above a hopping
    eye. Unweighted's and Counterfire's repair does not work here.
  - **PT-07 reproduced.** Of four arrivals spread over G, three did not
    release the service stair; only an arrival near the 1.5 m goal plate
    does. A blink or a grapple to G's far side leaves a player 4 m up
    with no way down, which is the owner's "no recognizable return
    except random teleport".
  - **G is not reached from the arrival with the base kit**, and once
    released, the stair walks back down to A.
  - **The census's own error, fixed on the way.** A hop was placed
    without headroom, so under a low ceiling (G's slab over the
    recovery floor) the eye sat inside the slab and saw through it. The
    hop is now capped at the headroom (`ClaimCensus.rises_at`). The fix
    can only ever report fewer claims, so the earlier rooms' passes
    stand.
- **The proposal:**
  - **A destination, opened by the machine: not a cabinet.**
    - The Check stays on G. Reaching G is the objective, and the
      carriers are how you get there.
    - A cabinet whose lock is a machine state would either refuse a
      legal arrival (R1) or impose an input order the owner ruled out.
  - **G's west edge becomes a glass screen, with a gate at the shuttle's
    dock.**
    - The gate opens only while H stands docked at G. That is PT-06's
      "real machinery-operated release condition": the shuttle opens the
      gallery.
    - Nothing on the floor below sees through the glass or reaches over
      it. While H is docked its deck covers the floor under the lip,
      so nothing below reaches over it then either.
    - The screen stays glass, so G and its Check are seen from the
      arrival (the card's "arrival read").
  - **The stair is released by an arrival anywhere on G**: a volume
    over all of G replaces the 1.5 m plate, for every arrival R3 names.
  - **Controls labelled by what they do, and grouped as boards.** Their
    identities are unchanged: "CALL SHUTTLE EAST -- TO THE GALLERY",
    "HOLD SHUTTLE", "RESET BOTH CARRIERS", and so on.
    - The shelf says it is the lift's top.
    - The gate says it opens while the shuttle is docked.
    - Nothing prints the order of operations.
  - **What stays:** V's pause at the transfer plane, H's schedule,
    STOP-and-transfer, RESET, the recovery floor and its stair, the
    service stair and the carriers' persistence.
    - Blink or grapple to H stays the qualified alternate, as the card
      lists it.
    - V-10 will say what the screen does to any other movement arrival.

## CP2 — `H-PASSING` (PT-06, PT-07, D12's card) — repaired: G a glass gallery the shuttle opens

The proposal above, built. Two of its details were changed by what the
runs found; both changes are measured below.

- **What was built** (`passing_platforms_room.gd`):
  - **G is glass on its three open sides**, from under its slab to the
    tops of the walls. It stays in view from the arrival and is out of
    reach from everywhere else. The proposal named the west edge only.
    Both extents were measured:
    - with the west edge glazed, the census still found 34 cells north
      of G claiming the Check over its 1.1 m railing. The Check's
      collider stands 2.6 m tall, and a hop there sees its top (SP-2);
    - with glass only door-high, V-10 found double jumps claiming from
      the air west of G, and 163 blinks landing on G over it (SP-9).
  - **Its one door is a glass gate at the shuttle's dock.**
    - It opens only while H stands docked at G, and shuts when H leaves.
    - It is a `ServiceShutter`, so it never shuts on a body (§21.2).
    - The glass over it reaches 0.3 m below its top edge. Meeting that
      edge edge-to-edge, in the next plane, left a seam that a descending
      ray threaded; V-10 found it from the air west of the gate (SP-8).
    - A save with H docked at G restores the gate already open, in the
      same frame, rather than sliding open in front of the player.
  - **Any arrival on G releases the stair** (PT-07, R3). A volume over
    the whole gallery, from the glass's inner face, does it. Before, only
    the 1.4 m goal plate did; the plate itself is unchanged.
  - **The way back says where it goes:** "STAIR DOWN TO ARRIVAL" at its
    head.
    - The south glass has the stair's cut, removed with the railing's
      when the stair is released.
    - The cut is full height. A first version left glass above it, and
      the player's step, which wants a metre of headroom, would not
      climb the stair's head past the lever there
      (`godot-passing-platforms` caught it).
  - **Every control says what it does, not when to use it.** Their
    identities (the `levers` keys and node names) are unchanged. The 13
    read, for example:
    - "CALL SHUTTLE EAST -- TO THE GALLERY"
    - "HOLD SHUTTLE WHERE IT IS"
    - "RESET BOTH CARRIERS -- LIFT DOWN, SHUTTLE WEST"
    - "LIFT UP TO THE SHELF -- PAUSES AT THE SHUTTLE'S LEVEL"
  - **Three new signs:**
    - "CARRIER CONTROLS" names A's board;
    - "UPPER SHELF -- THE LIFT'S TOP";
    - "GALLERY GATE / OPEN WHILE THE SHUTTLE IS DOCKED".
  - **Supporting changes:**
    - `ServiceShutter.panel_material` (a glass gate is still a shutter);
    - `ThemeMaterials.glass_material()`.
- **Played after the repair** (`godot-passing-hosted`, new, 24 checks;
  `H-PASSING_after.log`), on zone_002/c025, as captured by the new
  `CANDIDATE_DUMP` recipe:
  - **the census:**
    - 0 of 5,814 cells reached from the arrival claim the Check (233
      before);
    - with H docked at G and its gate open, 0 of 5,817;
  - **what the room says:**
    - each of the 13 controls reads as what it does;
    - none of 22 signs and labels prints an order of operations;
    - the gate says what opens it;
    - the Check is in sight from the arrival through nothing but the
      gate's glass;
  - **as built,** G is not reached from the arrival with the base kit;
  - **the gate, played with the real levers at A's board:**
    - "CALL SHUTTLE EAST": H crossed to G in 14.4 s, and the gate stayed
      shut all the way (never above 0.00 open);
    - it opened 1.6 s after H docked;
    - after "CALL SHUTTLE WEST", it shut 1.6 s after H left;
  - **arrivals (R3):** the first arrival on G releases the stair. It was
    placed at G's far south-east corner, 2.6 m from the old plate's
    centre, where the plate alone does not reach (SP-6). The stair,
    signed at its head, is walked back down to A;
  - **the interlock:**
    - the player stood in the open gate and pulled "SEND SHUTTLE WEST"
      on G;
    - H left, and the gate was refused its closure 4 times;
    - it never came below fully open, cost 0 health and moved the player
      0 m;
    - once the player stepped out onto G, it shut;
  - **restore:** with H restored docked at G, the gate is open in the
    same frame; with H restored at the west berth, it is shut;
  - **V-10** at the schema maxima, on a fresh build of the same Zone:
    - 27,132 blinks and 18 flights;
    - no claim from anywhere but G;
    - 2 grapples (3 in a run on the first capture) arrive on G over the
      glass's top. Those are legal arrivals (R1), and the first of them
      released the stair (R3).
- **The baseline route through the real bridge.** `godot-candidate-live`,
  on this tree, is green in all eight phases, and its `next` phases play
  this same hosted room (`H-PASSING_candidate_live.log`):
  - LAUNCH on the lift, then a step across onto the restored held
    shuttle, then H ON EAST to the east berth;
  - walked off through the gate onto G. The stair was released and
    ACCEPTED as `minor_c025/stair`, and Check 89100005 was CONFIRMED;
  - after a real restart, the shuttle is restored at EAST, "and G's
    glass gate stands open, its shuttle docked there (1.00 open)" (a
    new check). The stair is then walked up from A onto G.
- **The standalone scenario** (`godot-passing-platforms`,
  `H-PASSING_standalone.log`): 70 of 70.
  - The continuous run, the patient route and the counterpart pass
    through the gate unchanged.
  - Its walker, coming up the stair, steps onto G over the 0.35 m plinth
    of the "SEND SHUTTLE WEST" lever at the stair's head, as it did
    before this change. Its feet end in exactly the same place.
- **Declared harness steps:**
  - the player is placed on each arrival point on G, and back at the
    arrival between cases;
  - `_mobility` places them for each blink and flight;
  - health is raised for the two censuses and the V-10 sweep;
  - the restore case calls the room's own `restore_carrier`, as the
    hosted room does before the player arrives.
  - Every lever is pulled by the player: aimed at, interact pressed.
- **Sabotages** (`H-PASSING_sabotages.log`), each restored byte for byte;
  the quick suite without V-10, except where the row says V-10:

| # | Rule removed | Caught by |
|---|---|---|
| SP-1 | no glass on G's west edge | the census (54 cells over the west lip), the glass check, and the docked census |
| SP-2 | no glass on G's north edge | the census (34 cells over the north railing), the glass check, and the docked census |
| SP-3 | the gate always open | the census (25 cells) and its **played witness**: the real player hopped at the lip, read "[E] CLAIM CHECK 005", and a claim went out. Also "shut as built", "stayed shut all the way", "shut behind it", and the interlock |
| SP-4 | the gate never opens | "docked at G, the gate opens", and the interlock case (no open gate to stand in) |
| SP-5 | the gate opens with H at either dock | the census and its played claim (as SP-3), "shut as built", "stayed shut all the way", and the restore at the west berth |
| SP-6 | only the goal plate releases the stair (PT-07) | "the first arrival on G releases the service stair": the far corner did not |
| SP-7 | the controls read as codes again | "each of its 13 controls reads as what it does": all 13 wrong |
| SP-8 | the glass over the gate meets its top edge to edge (V-10) | V-10: a double jump claims through the seam from the air west of the gate |
| SP-9 | the glass only door-high, as the proposal had it (V-10) | V-10: double jumps claim from the air west of G, and 163 blinks land on G over it |
| SP-10 | a restored shuttle does not bring its gate back | "restored docked at G, the gate is open in the same frame" |
| SP-11 | the stair released, its glass left uncut | the walk back down stops at the glass, and the interlock case cannot climb to G |

- **What stays open:**
  - **N-10:** the hosted suite needs Dess's `passing_zone.json`. Until
    then it runs on a local capture, and it is not in CI.
    - `make godot-candidate-live CANDIDATE_DUMP=<path>` writes the
      capture.
    - `make godot-passing-hosted PASSING_ZONE=<path>` plays it.
    - Two captures differed only in c025's Check id (89100047 and
      89100005); the room is the same.
  - **Which occurrence the owner played is not in anything we hold.**
    PT-06's "directly reachable" matches the 233 lip cells, but the save
    that would show it needs `room_entered` (D-2, with CP4's map work).
- **What the owner will notice:**
  - G, the goal gallery, is behind glass on three sides. You can see the
    Check from the arrival, and you can't reach it from the floor.
  - Where the shuttle docks, the glass is a gate. It slides up while the
    shuttle stands there and down when it leaves.
  - Every lever says what it does when you aim at it.
  - Getting onto G anywhere opens the stair back down, and the stair's
    head says where it goes.

## CP2 checkpoint — closed (the full frontier)

- **On `6e1c60b` (H-PASSING's head):** 73 of 74 steps passed, 06:24 to
  07:45 UTC (`CP2_frontier_on_6e1c60b.tsv`).
  - The steps are CP1's 68 and this checkpoint's six:
    - the four suites CP2 added to CI: `godot-counterfire-hosted`,
      `godot-held-route`, `godot-minor-claim` and
      `godot-lever-route-live`;
    - `godot-passing-hosted`, on the capture (not in CI; N-10);
    - the three route fixtures regenerated from source: byte-identical,
      and restored.
  - **The one failure was `make test`,** 1 of 2,221
    (`CP2_make_test_on_6e1c60b.log`). `test_ci_coverage` found
    `godot-passing-hosted` neither run by CI nor listed in
    `NOT_A_SUITE`. It was a real finding, and this lane's own: the target
    was added without saying why CI does not run it.
  - **Fixed at `22f59c1`.** The target is listed in `NOT_A_SUITE` with
    its reason (no fixture carries a Zone that hosts EX50-011; N-10), the
    way `godot-return-journey` is. `make test` on `22f59c1`: 2,221 passed
    (`CP2_make_test_on_22f59c1.log`).
  - The tree at the end differed only in `captures.json`'s provenance
    stamp, which `godot-zone-audit` writes. It was restored.
- **CP2 is closed.** As at CP1, the frontier was not re-run in full for
  a change to a test's list. These are local results; remote CI was not
  polled.
