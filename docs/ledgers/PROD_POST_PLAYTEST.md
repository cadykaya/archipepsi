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
