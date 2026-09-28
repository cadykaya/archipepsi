# D · Status, enemy-job and combat-feedback art (050–052, with the 043 status pieces)

*Arty — 2026-09-28*

**Scope.** Only behaviour that exists at the pin is reviewed as live.
Future-only pieces are listed separately.

**Every image here is a posed art-lane render.** No Production driver
spawns enemies, telegraphs or statuses, so there is no runtime frame of any
of it. What the game does today is described from its code.

Not re-asked: the enemy silhouettes, and Production's eye (both ruled on
26 Sept).

## Look at

1. [`sheets/D1_telegraph_ring.jpg`](sheets/D1_telegraph_ring.jpg): the ring,
   and how it reads from eye height.
2. [`sheets/D2_ground_marks_to_scale.jpg`](sheets/D2_ground_marks_to_scale.jpg):
   a to-scale plan of each mark's art size against the runtime reach, and
   the two pieces that point the wrong way.
3. [`sheets/D3_impacts.jpg`](sheets/D3_impacts.jpg): body, shield and wall,
   plus two future-only impacts.
4. [`sheets/D4_status_markers.jpg`](sheets/D4_status_markers.jpg): the live
   status set and the future set.
5. [`sheets/D5_job_posts.jpg`](sheets/D5_job_posts.jpg): the enemy-job
   props.

## Decide (one line each; the reasons are on the sheets)

1. **Telegraph ring.** Approve the grammar. The ticks follow
   `telegraph_progress()`, CLOSED means released, and BROKEN means the enemy
   died or despawned.
   - Hold the flat orientation until it is shot in the engine at eye
     height; from there it reads as a line.
2. **Ground marks.** Must each mark cover the full runtime reach?
   - The charger's rush is 14.3 m and the artillery blast 3.2 m.
   - *Recommend:* yes, built at runtime size rather than scaled.
   - Show the beacon's 12 m range only under a visibility rule.
   - Hold the diver trail.
3. **Bulwark face.** Is it still wanted, now that the accepted mantlet
   carries the head-on read?
   - *Recommend:* keep it only for Production's code-built bodies, after the
     facing fix.
4. **Impacts.** Approve body and wall.
   - Approve the shield only as "mostly refused", since 15% still lands.
   - Park miss and interrupt.
5. **Status markers.**
   - Rule on Decision 7 (empowered's family) and on frozen's family now.
   - Decision 8: name Production as owner of the HUD tier.
   - Defer Decisions 5 and 6.
   - Review the live set as the candidate grammar, subject to a readability
     test in play.
6. **Job posts.** Approve the five role-fitted props as optional dressing
   that makes no claim about alertness. Park the three service props.

## Live vs future (at the pin)

| Live now (a runtime signal exists) | Future-only (the missing contract) |
|---|---|
| **Telegraph:** 6 roles; `telegraph_*` signals | **Interrupt:** nothing interrupts a windup |
| **Charger rush, artillery blast, beacon range, bulwark facing, diver dive:** the behaviours exist | **Miss:** no near-miss event |
| **Body, shield and wall hits:** inside `take_damage`, with no impact point | **Alert on ground roles:** a private flag, no signal |
| **Statuses on enemies:** slowed, frozen, shocked, poisoned, marked, stunned, vulnerable, empowered, burning, rooted, anchored; on objects: lightened | **Player-only markers** (haste, low_profile, regenerating): there is no HUD tier |
| **Jobs:** watch, tend, drift, patrol | **Charge socket, inspect panel, tool rack:** no job visits them |
| | **Compounds, the staged statuses, the player tick:** no compound rule, no runtime effect, no record of who applied a status |

## Status, kept apart

- **Visual approval:** none.
  - 050, 051 and 052 are PENDING (`docs/art/ART_REVIEW.md:4511, 4459, 4369`).
  - The 043 kit is a proposal, with four 11 Sept rulings standing.
- **Technical compatibility:** per sheet.
  - The ground marks do not match the pinned sizes.
  - `fx_bulwark_face` faces backwards.
- **Runtime binding:** none. No script outside `enemy.gd` listens to
  `telegraph_*`, and there is no status display anywhere.
- **Normal gameplay:** all ten roles can spawn, so the *behaviours* are
  live. The *art* is not.

## Engineering after (not the art judgement)

- A listener on `telegraph_*` at `TelegraphOrigin`.
- Public rush direction, artillery aim point, and dive state and vector.
- A hit event with the impact point and the absorbed share.
- A hook when a projectile stops.
- A way to pin a marker to a target, polling because expiry has no signal,
  plus a stored total duration.
- A rule for placing props at posts.

## Assets

- `assets/models/batch050/jobs/job_*.glb`
- `assets/models/batch051/combatfx/fx_*.glb`
- The 052 and 043 status kit: `docs/art/review/status_2026-09-11/`.
  The handoffs are `docs/art-requests/2026-09-22-{jobs,combatfx,status-readiness,enemy-readiness}-handoff.md`.

## Found tonight (nothing repaired)

- **`fx_bulwark_face` faces backwards.** The plate is at +Z (z 0.365–0.425
  in the GLB), and the bulwark's front is −Z (`enemy.gd:1262`).
  - *Smallest repair:* re-export it flipped, as `fa16cfea` did for the enemy
    roles.
- **Sizes don't match the runtime:**
  - the lane is 6 m against a 14.3 m rush;
  - the warned ground is r 1.3 against a 3.2 m blast;
  - the beacon ring is r 1.7 against a 12 m radius.
- **The diver trail points at the ground,** but the dive aims at an airborne
  player.
- **The evidence has errors:**
  - the drifter's idle and alert frames are pixel-identical;
  - the alert frames stage an orange glow at `anchor_warn`, which the
    26 Sept eye ruling reserves;
  - the ring frame lights every state at once.
- **Stale counts.**
  - The status records say 13 implemented statuses; the pin has 15 (adding
    rooted and anchored).
  - The enemy-readiness frames still say "not spawnable", but all ten roles
    spawn at the pin.
- **Production's own comment is wrong.** It says `completed` means "actually
  landed", but the code sends true on release, even for a miss
  (`enemy.gd:29-32` vs `:496-506`).
- **The 051 frames predate the 24 Sept texture re-bake.**
