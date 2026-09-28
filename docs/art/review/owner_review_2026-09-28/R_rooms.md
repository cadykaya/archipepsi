# R · The ordinary-room library we already own

*Arty — 2026-09-28*

**Why this exists.** You said ordinary rooms feel cluttered, cramped, and
too dominated by simple boxes. These are the existing rooms that could
help, before anything new is commissioned.

**What this is not.**
- It is not a room programme.
- Nothing is relabelled, resized, promoted or re-weighted.
- There are no upper doorways, no ID changes and no props.
- It covers geometry only. No shell here establishes enemy navigation,
  spawns or encounter pacing.

## Look at

1. [`sheets/R0_ordinary_rooms_today.jpg`](sheets/R0_ordinary_rooms_today.jpg):
   ordinary rooms as Production builds them now (its own zone-shot driver),
   and the rules that decide when a shell can replace one.
2. [`sheets/R1_room_reuse_a.jpg`](sheets/R1_room_reuse_a.jpg) and
   [`sheets/R2_room_reuse_b.jpg`](sheets/R2_room_reuse_b.jpg): the six
   examples. Each has an eye-height view and a roof-off plan.
3. [`sheets/R3_room_alternates.jpg`](sheets/R3_room_alternates.jpg): three
   alternates, and the poor fits.

**The loose images are in `evidence/rooms/`.**
- `R_eye_*`: the eye-height views.
- `R_plan_*`: the plans. They are drawn from each model's own upward faces
  by `tools/owner_review_2026_09_28/plan_from_glb.py`, with the doors
  marked from the manifest.

**The eye views are existing renders.** Their geometry is unchanged since
(checked); only the textures were re-baked on 24 September. The one
exception is the cross junction: its geometry moved, so it was re-rendered
tonight.

## The six

| # | Shell | Status | Usable ground; doors | Beyond a box | Fit |
|---|---|---|---|---|---|
| 1 | `shell_corridor_bays` (015) | **withheld** | a 6 × 16 m lane plus four 1.6 × 2.8 m bays, all at grade; doors at grade | pockets off a clear lane | **REUSE**, small / connector |
| 2 | `shell_corridor_gallery` (015) | **withheld** | 8 × 20 m at grade, plus a 2.6 × 14 m deck at +2.6 m reached by a stair; doors at grade | two routes, high ground | **REUSE**, standard |
| 3 | `shell_arena_pillars` (016) | **withheld** | 22 × 22 m at grade; a 4 × 4 column grid at 4.4 m pitch, 3.2 m aisles; doors at grade | cover as structure, not props | **REUSE**, standard / large |
| 4 | `shell_arena_balcony` (016) | **withheld** | an open plate at grade, plus a 2.4 m walkway at +3.2 m on three sides; doors at grade | height without clutter | **REUSE**, large |
| 5 | `shell_junction_triad` (044) | **candidate** | a spine, an arm and a bay, all at grade, plus an overlook at +2.8 m; entry, exit and a branch, all at grade | the plan makes the spaces | **REUSE**, large (as a through-room) |
| 6 | `shell_tower_collapsed` (018) | **offerable** | 12 × 12 m at grade, half-floors at +3 and +6 m; entry at grade, **exit at +6 m** | the one live split level | **ADAPT** |

The alternates are on R3:
- `shell_arena_pit`: REUSE. It overlaps Production's own pit band.
- `shell_junction_cross`: ADAPT. It is larger than any procedural arena.
- `shell_treasure_coffer`: POOR FIT. It is the same 8 m envelope as the
  procedural room.

The poor fits:
- `shell_corridor_narrow` (it is the box);
- the three platform paths (jumps over a void);
- the spiral and gantry towers (climbs);
- the two corners (connectors).

## What can use them today

These are read from Production's code at `c12a72f`, not run.

- **Offered to Epsilon in live play:** the 12 exported shells. That includes
  the P2 towers and treasure rooms, but Production's fallback never creates
  a tower or treasure_room chamber. Only a provider that makes those types
  can reach them.
- **What the fallback does with corridors:** a corridor whose features fit
  a 6 m interior becomes the 6 × 6 m corner shell.
- **Banded arenas:** 55% of arenas get a gallery or pit band. No shell
  declares `provides_elevation`, so those always stay procedural.
- **Size and budget:** `adopt()` writes a shell's size into the chamber
  (`bridge/archipepsi_bridge/shells.py:544`). The authored footprint is
  capped at 4000 m² per Zone.
- **Withheld (015–017):** the reason is fixed size against per-chamber size
  (req 35; the 015–019 owner blocker). `adopt()` is exactly req 35's own
  second option, but nothing has re-ruled 015–017 since.
- **044:** not in Production's registry, and no chamber type is declared.
  Production's topology now reads roles from declared sockets, which looks
  like the old "two-socket world" blocker is fixed (read, not run).
- **Movement:** the player steps up 1.0 m unaided. Enemy footing tolerates
  0.6 m per sample, so a 1 m level change is not yet shown to be walkable for
  enemies.

## Decide

**Which of these go into the small / standard / large ordinary-room
discussion as REUSE candidates, before anything new is commissioned?**

- *Recommend:*
  - small: bays;
  - standard: gallery and pillars;
  - large: balcony and triad (the triad only once branching rooms are ruled
    on);
  - the tower as an ADAPT reference.
- *Cost:* the withheld rooms need their old manifests brought up to the room
  contract (surfaces, sockets, traversal, size class, colliders). That is
  retrofit work, as P2 was.
- *Engineering after:*
  - re-rule req 35 now that `adopt()` exists;
  - a chamber type for the 044 rooms;
  - a provider that makes tower chambers, if a tower is ever wanted.

No selection-frequency change is proposed.

## Assets

- `assets/models/batch015/shells/`, `batch016/shells/`, `batch017/shells/`:
  withheld, PASS 28 Aug.
- `assets/models/batch018/shells/`, `batch019/shells/`: exported to
  `godot/content/shells/` and offerable.
- `assets/models/batch044/shells/`: candidate, PENDING 13 Sept.
