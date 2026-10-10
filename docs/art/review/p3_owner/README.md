# P3 owner review — `shell_hall_transit`, the first LARGE authored room

**Review state: `pending`. Nothing here promotes it.** Art does not write
`pass`; that word is the owner's. The shell exports `review: "pending"`
and `verify_pack.gd` asserts that the pack does **not** ship it, which is
the same gate the projectile visuals prove in the other direction.

| | |
|---|---|
| content id | `shell_hall_transit` |
| chamber type | `arena` (shape tags `transit`, `vertical`) |
| size class | `large` — the owner's P3 direction, **not** derived from metres |
| source | `tools/blender/build_hall.py` → `batch039/shells` |
| contract | Production's movement seam at `af620d8` |
| interior | 40 W × 38 H × 60 D m — about **91,000 m³** |
| triangles | 552 |
| collision | 41 convex bodies, derived from the four painted roles |
| surfaces / traversal / sockets / volumes / offers | 14 / 13 / 10 / 3 / 3 |

For comparison, the largest P2 room (`shell_tower_gantry`) is 2,160 m³.
This is roughly **forty times** the volume. No new global metre threshold
for LARGE is proposed and none should be read into these numbers.

---

## The eight views

| | view | what it is for |
|---|---|---|
| 1 | `H1_entry` | The first read, from inside the door. The vestibule is 5.5 m, the hall is 38, and the exit portal is already visible 60 m away. |
| 2 | `H2_hero` | The primary spatial read, down the long axis. Four occupied layers and the landmark standing between them. |
| 3 | `H3_over` | The arrangement, from just under the roof. Gallery west, gantry east, landing north, core in the middle. |
| 4 | `H4_low` | From the basin floor, beside the armature. Scale contrast, and the recovery space. |
| 5 | `H5_mid` | On the west gallery at y=11. The core occludes the east side from here. |
| 6 | `H6_high` | On the east gantry at y=21, facing the last ramp. This deck is the launch pair's landing region. |
| 7 | `H7_reverse` | From the exit platform at y=28, looking back. 60 m to the door with every layer in the frame. |
| 8 | `H8_vertical` | Straight up the armature shaft from the basin, floor to roof. |

## The six overlays

Explanatory figures only. They add no geometry to the shell, ship
nowhere, and carry no review state. **Every point in them is read from
the shipped manifest** by `tools/blender/build_hall_overlay.py`, so a
figure cannot quietly disagree with the data — if the shell changes and
the figure is not rebuilt, the figure is missing rather than wrong.

| | overlay | reads |
|---|---|---|
| A | `O1_regions` | Every declared stand surface at its own size (green), with the five `enemy_high` sockets standing on them (violet). |
| B | `O2_route` | The mandatory route on foot with **no** movement package installed. Thick bars are the nine declared links; thin bars are this diagram's reading of the surface crossings between them. |
| C | `O3_rail` | The `rail_route` offer: eleven control points, twice around the core, entry level to the exit. |
| D | `O4_launch` | The launch pair. Filled disc = source, open ring = target. **Nothing is drawn between them.** |
| E | `O5_overhead` | Overhead structure — the grapple *question*, not an offer. |
| F | `O6_shaft` | The vertical-movement column: continuous open air from the basin to the core top. |

---

## What the owner asked for, and where to see it

**A big open area, not a corridor kit.** 91,000 m³ against P2's largest
at 2,160. `H2_hero`, `H3_over`.

**Large vertical volume.** 38 m floor to roof with an unbroken 12 m
shaft through the middle of the landmark. `H8_vertical`, `O6_shaft`.

**Long sightlines.** The longest is 64.7 m, from the entry eye to the top
of the exit portal, and it is **asserted in the build** rather than
hoped for: `_assert_sightline` walks 400 samples of that line against
every collider and the build fails if anything is in the way. `H1_entry`
is that assertion photographed.

**Strong scale contrast.** The vestibule is 10 × 9 × 5.5 m and opens
directly on a 38 m hall. Scale is a comparison, so the small term is
given first. `H1_entry`.

**Multiple elevations and subspaces.** Four occupied layers — basin 0,
west gallery 11, the ring / landing / gantry band at 21, exit platform
28 — and fourteen named stand surfaces among them. `O1_regions` is the
direct answer to "several local gameplay spaces or one big rectangle".

> **These figures are the pre-repair record.** They show the hall as it
> stood when this review was requested, which is the point of them. Two
> of the fourteen surfaces above — `plinth_west` and `plinth_east` — were
> demoted to plain geometry at `058ec8b` after the owner ruled on the
> `301374d` audit, so the shipped shell declares twelve. `O1_regions`
> still draws fourteen plates. It has deliberately **not** been
> re-rendered: re-rendering it would erase what was actually reviewed.
> The current state is the manifest — the plinths remain as geometry and
> are simply no longer declared standable.

**A visible distant destination.** The exit portal, 60 m away and 28 m
up, legible from the door. `H1_entry`, and again from the other end in
`H7_reverse`.

**A dominant landmark.** A machine armature: four 4 m columns and three
collar rings around a 12 m open shaft, topping out at 30 m.

> **Why a frame and not a mass.** A solid core would have been the easier
> sculpture and it would have killed the room. The one thing the player
> must be able to see from the door is where they are going, and a solid
> 18 m core sits exactly on that line. The armature's shaft *is* the
> sightline. The rings still do the occlusion work — from the door you
> cannot see the west gallery behind the core, and the room keeps
> revealing subspaces as you cross it (`H5_mid`).

**Widely separated enemy elevations.** Five `enemy_high` sockets at
y = 11.3, 21.3 (×3, on opposite sides of the core) and 28.3, and three
`cover` sockets on the basin. Violet posts in `O1_regions`.

**Compatible with a long 3D grind rail.** `rail_helix`: eleven points,
twice around the armature, 143.9 m of route from y=2 to y=31.5. Every
segment is inside `RailPath`'s 0.5–60 m and no pitch exceeds 75°, and
that is asserted at build time, not assumed. `O3_rail`.

**Compatible with LaunchPad, grapple, wind and moving platforms.**
See the next section — this is the part where the honest answer is
partly "not yet".

---

## The offers, and what Art is *not* claiming

`OFFER_KINDS` is closed at `rail_route`, `launch_source` and
`launch_target`. Production's own comment names `grapple_anchor`,
`platform_route` and `wind_column` as the next arrivals **through this
same field**, so no grammar is invented for them here.

| offer | kind | what it reserves |
|---|---|---|
| `rail_helix` | `rail_route` | 11 ordered points, 143.9 m, y 2 → 31.5 |
| `launch_basin` | `launch_source` | basin at (12, 0, 18), r = 3.0, aimed at `launch_gantry` |
| `launch_gantry` | `launch_target` | east gantry at (16, 21, 30), r = 3.5 |

The pair spans 24.5 m, inside `LaunchSolver`'s 0.5–80 m, and the target
radius clears its 2.5 m minimum.

**`O4_launch` draws no arc, and that is deliberate.** `LaunchSolver`
derives the trajectory from source, destination and gravity. Art never
authors velocity, direction or arc — there is nowhere in the schema to
put one, on purpose — and a curve drawn between the two pads would be
authoring one in a picture. The first time the solver disagreed with it,
the picture is what everybody would remember.

**AN OFFER IS NOT AN ORDER.** A package consumes the kinds it
understands and may decline every one. This room has to play as ordinary
combat space with no traversal mechanic installed at all, and `O2_route`
is the evidence that it does: nine mandatory `walk` links reach every
layer on foot.

**The grapple answer is a question, not an offer.** `grapple_anchor`
does not exist in the contract yet, so declaring one would be inventing
vocabulary. `O5_overhead` marks the structure that already spans open
floor — the three collar rings and the undersides of the west gallery,
east gantry and north landing. If a grapple package arrives, those are
the surfaces it would hang from, and the owner can say now whether that
is the room they want. The same geometry answers wind and moving
platforms: `O6_shaft` is one continuous unobstructed column from the
basin to 30 m.

---

## Combat and recovery

**No enemies are placed and no encounter is authored.** What the shell
provides is the spatial vocabulary: five high perches at three
elevations on opposite sides of a landmark that breaks line of sight,
three cover positions on the open basin, and a 40 × 50 m floor with
enough room to retreat across.

**Nothing here falls forever.** The basin is one continuous floor at
y = 0 under the *entire* hall, including under the core's shaft. There
is no pit and no void anywhere in the room. A missed rail or a missed
launch costs height and a walk back, never the level. Runtime recovery
and checkpoint behaviour are Production's and nothing here implements
any of either.

---

## One open contract question, raised not worked around

Production's traversal contract disagrees with itself, and a LARGE room
is the first thing that can see it.

* `schemas/content.py` — `TraversalSegment` tests `self.kind` and bounds
  only `rise` and `gap` by `MAX_VERTICAL_STEP` / `max_safe_gap`. `walk`
  and `drop` are deliberately unbounded.
* `shell_validator.gd` — `_check_segment` never reads `kind`. It applies
  the same bounds to **every** mandatory segment, `walk` included.

P2 could not see this: every mandatory segment in the eight was a 1.00 m
`rise`, inside both readings. A LARGE room cannot avoid it — a 28 m climb
declared as ramps is `walk`, and declared as 1 m steps is 28+ segments
against a schema cap of 32.

The clearest single case is `ring_n_to_ring_e`: **3.20 m, flat**, along a
continuous walkable collar, refused because 3.20 > `max_safe_gap(0)` =
2.60. There is floor under every centimetre of it.

**Art has not changed the shell to get past this.** The route is
declared as what it is, and `tools/verify_content_pack.sh` stage 4 runs
Production's own `ShellValidator` and prints every refusal, marked, on
every run. Which half of the contract is authoritative is Production's
decision, not Art's.

Art's side of the claim is checked: `_assert_walk_ground` in
`build_hall.py` proves that every mandatory `walk` link has collider
structure under the whole of its chord, at a height between its two
ends. A wall does not count.

---

## Deliberately not done

No enemies. No encounter. No checkpoint or respawn behaviour. No world
logic, pressure plates, boxes, beams or switches. No rail mesh in the
shell — a rail is an offer here, not permanent identity. No LaunchPad
art. No second LARGE room and no family. None of the eight P2 shells was
touched; `diff_shell_glb.py` and the pack verifier both confirm it.

## How to rebuild everything in this folder

```sh
.tools/blender/blender -b --python tools/blender/build_hall.py
.tools/blender/blender -b --python tools/blender/build_hall_overlay.py
python3 tools/shots/gen_p3_owner_review.py
tools/shoot.sh tools/shots/p3_owner_review.json docs/art/review/p3_owner
```
