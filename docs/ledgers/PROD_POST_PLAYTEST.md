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

| edit | source rule | behaviour kept | commit |
|---|---|---|---|

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
