# P2 preparation — the eight dimensionless shells, mapped to their sources

**Preparation only. Nothing here is executed.** No room art, no remodelled
shells, no registry exposure, no F3 runtime integration, no Batch 038.

**This document does NOT decide the metadata schema.** Production is
implementing P1 and the contract is still moving. What this does is record,
for each of the eight candidates, *which variable in which build script
already holds each thing the contract will want* — so that when P1 reports
the final field names, the exporter retrofit is a mapping exercise rather
than an archaeology one.

Source: `docs/art/ROOM_ARCHITECTURE_STUDY.md` §6.1, §7, §9, §16, §17
(branch `claude/archipepsi-room-architecture-h3woci`). Owner has approved
the HYBRID direction; P1 is engineering-only and lands first.

## The finding that decides the cost of P2

> **The tower builders already compute the Surface list and the traversal
> chain as ONE variable, in route order, and `routecheck` already validates
> it against `max_safe_gap`. It is simply never exported.**

`build_towers.py` builds `stones` as `[((x, y), (width, depth)), ...]` in
route order and hands it to `routecheck.assert_reachable`, which returns
`(worst_measured, allowed)` — both of which *are* exported, as `worst_jump`
and `max_safe_gap_at_step`. The list that produced those two numbers is
thrown away.

That list is §6.1's `surfaces` and §6.1's `TraversalSegments`, from the same
data, already proven legal at build time. **Exporting `stones` is the whole
tower retrofit.** Everything else below is smaller than that.

## The axis trap, stated exactly

Three fields in every shell manifest, three different orders:

| field | order | tower_gantry |
|---|---|---|
| `size` | **Blender** `[x, y, z]` = `[outer_width, LENGTH, outer_height]` | `[12.8, 14.6, 20.5]` |
| `interior` | Godot `[width, HEIGHT, length]` | `[12.0, 20.0, 12.0]` |
| `bounds` | Godot `[[min_x, min_y, min_z], [size_x, size_y, size_z]]` | `[[-6, -1, 0], [12, 21, 14.2]]` |

`size` is the only Blender-ordered field, and it is the one a converter
would naturally reach for. **Feeding `size` verbatim into a Godot `Vector3`
sets the gantry tower's height to 14.6 m — its LENGTH — instead of 20.5 m.**

The transform is a single known one: Blender `(x, y, z)` → Godot
`(x, z, -y)`. It is **already applied** in `platform_anchors`
(`anchors.append([x, z, -y])`) and **not** applied in `stones`, which is raw
Blender. A converter must apply it exactly once, in one place.

Square footprints hide the trap: treasure is 8 × 8, corners 6 × 6, towers
12 × 12, so only the height axis ever disagrees. It will not announce itself
on seven of the eight; it will be wrong on all of them.

**`bounds` already matches §7's AABB**, including `min_y = -1.0`, which is
the same floor allowance `ContentInstantiator.FLOOR_ALLOWANCE` uses. That
field needs no conversion at all.

---

## Towers ×3 — `build_towers.py`

| | |
|---|---|
| ids | `shell_tower_collapsed`, `shell_tower_spiral`, `shell_tower_gantry` |
| glb | `assets/models/batch018/shells/<id>.glb` |
| builders | `shell_tower_collapsed()` L325, `shell_tower_spiral()` L240, `shell_tower_gantry()` L274; helpers `_shaft` L102, `_core` L148, `_deck` L180, `_slab` L195, `_spiral` L211 |
| constants | `SIDE` 12.0, `PER_FLOOR` 3.0, `STEP` 1.0, `CORE` 2.2, `PLAT` 2.6, `WALL` 0.40, `DOOR_W` 2.40, `DOOR_H` 3.20, `F_MIN/F_MAX` 2/5 — all read from `common.DIM`, i.e. the engine's own constants |

**Surfaces — mechanical.** `stones`, in route order:
`_GROUND` = centre `(0, -SIDE/2)` extent `(SIDE, SIDE)`; then one per
platform at `(x, y)` extent `(PLAT, PLAT)`; then the deck at
`(0, -SIDE + 2.0)` extent `(SIDE, 4.0)`. Heights come from `_spiral`/the
landing loop and from `rise`. The bridge is a fourth kind of surface in
`_deck`: `(0, -SIDE - 1.0)` extent `(3.0, 2.4)` at `rise`.

**Traversal — mechanical.** Consecutive `stones` pairs are the segments;
`STEP` is the rise; `routecheck` has already asserted every one of them
against `max_safe_gap`. `worst_jump` is 0.8 / 1.7 / 0.1 respectively, all
inside the 2.0 bound already recorded as `max_safe_gap_at_step`.

**Sockets — mechanical.** Entry `(0, 0, 0)` yaw 180 (`anchor="entrance"`);
exit from `exit_offset` `[0, rise, SIDE + 2.2]` yaw 0. Socket `width`/
`height` are `DOOR_W`/`DOOR_H`.

**Volumes — mechanical.** `enemy_anchors` already exist and every one sits
at y ≥ 1.3, so under §6.1's `y > 0.5` rule **all tower enemy spawns are
`enemy_high`** — worth stating, because it is a gameplay-visible
consequence of a derived rule rather than a choice. `objective` from
`check_anchor`. `player_entry` at the entry socket.

**`no_build` — mechanical.** `_core` is a solid central column, `CORE` 2.2
square, running the full `rise`. It is the one interior mass in the family
and its dimensions are a module constant.

**`descends`** — 0.0 for all three. Derivable, but should be *asserted*
rather than assumed: no tower has open shaft below y = 0.

**Hand-authoring required:** `size_class`, `semantic_tags` intent tags,
`cost`. Nothing geometric.

**GLB unchanged:** yes. Under §6.4 geometric validation, no marker nodes are
needed.

**Family-specific dependency:** `floors` exists only at 2 / 3 / 5. A
`floors=4` chamber has no shell and must either fall back procedurally or be
filtered out of the offer — Production's call, recorded in §16.

---

## Treasure ×3 — `build_rooms.py`

| | |
|---|---|
| ids | `shell_treasure_vault`, `shell_treasure_cache`, `shell_treasure_coffer` |
| glb | `assets/models/batch019/shells/<id>.glb` |
| builders | L215 / L250 / L293; helpers `_treasure_shell` L134, `_plinth` L183, `_door_wall` L98, `_solid_wall` L122 |
| constants | `T_SIDE` 8.0, `T_HEIGHT` 4.5, `WALL` 0.40, `DOOR_W` 2.40, `DOOR_H` 3.20, `PROP` 1.40 |

**Surfaces — mechanical, and there are three not one.** The floor
`(T_SIDE, T_SIDE)` at y 0; plinth step 0 `(3.0, 3.0)` at y 0.40; plinth
step 1 `(2.2, 2.2)` at y 0.80 — all literals inside `_plinth`, identical
across all three shells because the docstring is explicit that the reward
position is the engine's and not art's to move.

**Traversal — none.** A flat room with a two-step plinth, every rise 0.40 m
against `STEP` 1.0. No segments needed; a converter should emit an empty
list rather than omit the field.

**Sockets — mechanical.** Entry `(0, 0, 0)` yaw 180; exit `exit_offset`
`[0, 0, T_SIDE]` yaw 0. Doors are cut by `_door_wall` at `WALL/2` and
`-T_SIDE - WALL/2`, so the sill is y 0 and the opening is `DOOR_W` × `DOOR_H`.

**Volumes — mechanical.** `objective` from `check_anchor` `[0, 1.0, 4.0]`
(the reward sits at y 1.0 on top of the plinth); `player_entry` at entry;
`enemy_spawn` **none** — `enemy_anchors` is `[]` by design.

**`no_build` — mechanical.** The plinth mass, 3.0 × 3.0 × 0.8 centred on the
room. Under `ROOM_SCALE_SOLID` 6.0, so `solid_boxes` sees it and §6.1's
sub-6 m rule is satisfied without a declaration; declaring it anyway is
cheap and removes the ambiguity.

**Hand-authoring required:** `size_class`, intent tags, `cost`. The three
`story` values (`protected` / `stored` / `displayed`) and `plinth` styles
already exist as meta and map naturally onto intent tags — but *which* tag
vocabulary is a P1 decision, not a derivation.

**GLB unchanged:** yes.

**Family-specific note:** §16 flags recurrence — the exit room is a treasure
room every Zone, so three ids across 24–30 Zones is heavy. That is a
composition concern for the picker, not a conversion blocker.

---

## Corners ×2 — `build_rooms.py`

| | |
|---|---|
| ids | `shell_corner_left`, `shell_corner_right` |
| glb | `assets/models/batch019/shells/<id>.glb` |
| builders | `shell_corner_left()` L394, `shell_corner_right()` L413, both from `_corner(turn)` L327 |
| constants | `C_SIDE` 6.0, `CORRIDOR_H` 3.60, `WALL` 0.40, `DOOR_W` 2.40, `DOOR_H` 3.20 |

**Surfaces — mechanical.** One floor, `(C_SIDE, C_SIDE)` at y 0.

**Traversal — none.**

**Sockets — mechanical, and this is the family's whole point.** Entry
`(0, 0, 0)` yaw 180. Exit at `exit_offset` `[turn * S/2 + turn * WALL, 0, S/2]`
— already exported as `[3.4, 0, 3.0]` and `[-3.4, 0, 3.0]`.

> **`exit_yaw` = `turn * 90°`.** `turn` is already in the manifest (`+1` /
> `-1`). The builder's own docstring derives the sign from first principles:
> `corner(+1)` exits through the +X wall and `zone_builder._rot` is
> `Basis(Vector3.UP, yaw)`, so `yaw_after = yaw + PI/2` — **`turn=+1` is a
> LEFT turn, yaw +90**. That derivation was itself the fix for an earlier
> version that had the two names swapped, caught by a render disagreeing
> with its own caption (L-61). Do not re-derive it; it is written down and it
> was expensive.

**Volumes — mechanical.** `player_entry` only. `check_anchor` is `None` and
`enemy_anchors` is `[]`, both deliberately.

**`no_build` — none needed.** The chamfer and reveals are trim under 0.6 m.

**Hand-authoring required:** `size_class`, intent tags, `cost`.

**GLB unchanged:** yes.

**BLOCKING dependency:** §6.1 and §16 both gate this family on ZoneBuilder
consuming `exit_yaw`. **Corners must not land before that exists.** The art
side is otherwise ready today — the geometry always assumed a turning exit,
which is why `exit_offset` already carries it.

---

## The eight-shell matrix

| shell | family | footprint | surfaces derivable | traversal | exit_yaw | no_build | GLB change | gated on |
|---|---|---|---|---|---|---|---|---|
| `shell_tower_collapsed` | tower | 12 × 12 × 11 | 4 (`stones`) | 1 seg, worst 0.8 | 0 | core 2.2 | no | P1 |
| `shell_tower_spiral` | tower | 12 × 12 × 14 | 7 (`stones`) | 6 seg, worst 1.7 | 0 | core 2.2 | no | P1 |
| `shell_tower_gantry` | tower | 12 × 12 × 20 | 7 (`stones`) | 6 seg, worst 0.1 | 0 | core 2.2 | no | P1 |
| `shell_treasure_vault` | treasure | 8 × 8 × 4.5 | 3 (floor + 2 steps) | none | 0 | plinth | no | P1 |
| `shell_treasure_cache` | treasure | 8 × 8 × 4.5 | 3 | none | 0 | plinth | no | P1 |
| `shell_treasure_coffer` | treasure | 8 × 8 × 4.5 | 3 | none | 0 | plinth | no | P1 |
| `shell_corner_left` | corner | 6 × 6 × 3.6 | 1 | none | **+90** | none | no | P1 **+ exit_yaw** |
| `shell_corner_right` | corner | 6 × 6 × 3.6 | 1 | none | **−90** | none | no | P1 **+ exit_yaw** |

**Zero of the eight require a GLB change.** Every value is a live variable in
the build script or already in the sidecar manifest.

## What genuinely requires hand-authoring

Short, and none of it is geometric:

1. **`size_class`** — required for shells (§6.1) and absent from every
   manifest. Needs §4's thresholds, which P1 settles. Footprints are
   6 × 6 / 8 × 8 / 12 × 12, so the three families will likely land in three
   different classes, but that is a schema decision.
2. **`semantic_tags`** — the chamber-family tag is derivable from the id
   prefix; the *intent* tags are design. Existing meta (`story`, `plinth`,
   `climb`, `core`, `marker`, `ceiling`) is the raw material.
3. **`cost`** — an economy number, not a measurement.
4. **`surface_id` on gameplay sockets** — needs P1's Surface naming scheme
   before the tie can be written.

Everything else on §6.1's list derives.

## Blockers and dependencies on P1

| # | dependency | affects | why |
|---|---|---|---|
| **B1** | `_from_authored_scene` emits Surfaces as `{"kind":"stand", position, extent}` runtime dicts | all 8 | until the consumer shape is fixed, exporting Surfaces has no target |
| **B2** | Final field names for `surfaces`, `no_build`, `descends`, `TraversalSegment` | all 8 | mapping is trivial, guessing the names is not |
| **B3** | §4 size-class thresholds | all 8 | `size_class` is required and cannot be derived |
| **B4** | ZoneBuilder consumes `exit_yaw` | corners ×2 only | §16 gates the family explicitly |
| **B5** | §6.4 geometric-validation audit exists | all 8 | it is what makes "no GLB change" true rather than hopeful |
| **B6** | Catalog behaviour for `floors=4` | towers ×3 | 2/3/5 exist; 4 does not |

**B4 is the only family-specific blocker.** Towers and treasure are gated on
P1 alone; corners need one further thing.

## What becomes mechanical the moment P1 lands

In dependency order, and all of it exporter work in `tools/blender/`:

1. **Export `stones` from `build_towers.py`.** One list, already computed,
   already route-ordered, already validated. Surfaces and TraversalSegments
   both fall out of it. Highest value per line in the whole retrofit.
2. **Apply the Blender→Godot transform once**, in the converter, and assert
   it: `size` is Blender-ordered and every other field is not. A unit
   assertion that `interior[1] == size[2]` for a square-footprint shell
   would have caught the trap the study documents.
3. **Emit the three treasure Surfaces and the one corner Surface** from
   `_plinth`'s and `_corner`'s own literals.
4. **Emit `no_build`** from `CORE` (towers) and the plinth steps (treasure).
5. **Emit sockets** from `anchor="entrance"` + `exit_offset` + `DOOR_W`/
   `DOOR_H`, with `exit_yaw = turn * 90` for corners.
6. **Emit `descends: 0.0`** with an assertion rather than a literal.
7. **Land all eight as `review: "pending"`** and let the owner flip per
   entry — §16 is explicit, and the projectile reversal is the proof that
   per-entry review is the working kill switch.

Step 7 is not a formality. The art branch shipped `review: "pass"` for three
projectiles that Production had already reverted, and only this study caught
it; the exporter now carries `FIXTURE_REVIEW` / `PROJECTILE_REVIEW` as named
constants with the reason attached, and `verify_manifest.py` diffs the art
export against Production's landed pack field for field. **Eight shells
landing as `pass` by default would be the same bug at eight times the size.**
