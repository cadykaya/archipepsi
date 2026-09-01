# P2 — the eight dimensionless shells, retrofitted to the P1 contract

Source-side retrofit against Production's landed P1 at **`99379e5`**
("A valid room means the same thing whoever produced it"). Targets the real
implementation, not the study's proposal — three places they differ are
noted below.

**Not live.** All eight export `review: "pending"`, so
`VisualOwnership.is_shippable()` refuses them and `build_chamber` falls back
to the procedural builder. They are also unreachable regardless, because
`SHELL_FOR_TYPE` still names the `shell_*_proc` ids. They stay pending until
Production integrates them, the P1 audit accepts them, and the owner reviews
the result.

## One blocker, and it is Production's to decide

> **`ShellValidator._check_envelope` refuses all eight**, for one reason,
> identically: the entry door wall occupies z ∈ [−0.40, 0], and the envelope
> it is measured against starts at z = 0 with 0.15 m of tolerance.

```
envelope = AABB(Vector3(-size.x/2, -FLOOR_ALLOWANCE, 0),
                Vector3(size.x, size.y + FLOOR_ALLOWANCE, size.z)).grow(0.15)
```

The z origin is fixed at 0 by construction, so **no choice of `size` can
contain a wall in front of it.** This is not a shell that can be fixed by
declaring different numbers.

**It is not obviously an art defect, and the evidence is Production's own
builder.** `ChamberBuilders._perimeter` puts its front wall at
`Vector3(..., height/2, 0)` with `WALL_THICKNESS` 0.4 — a box *centred* on
z = 0, spanning **[−0.2, +0.2]**. A procedural room would fail the same
check by 0.05 m. It does not fail today only because `ShellValidator` runs
on the authored path alone.

So the two producers use different conventions for the same wall:

| producer | entry wall | outside [0, depth] by |
|---|---|---|
| `ChamberBuilders` (procedural) | centred on z = 0 | 0.20 m |
| the eight shells (authored) | inner face on z = 0 | 0.40 m |

Neither fits an envelope that starts at z = 0 with 0.15 m of slack. **The art
lane has not modified any mesh to work around it**, per instruction. Three
ways out, all Production's call:

1. start the envelope at `-WALL_THICKNESS` rather than 0;
2. raise `POSITION_TOLERANCE` past the wall thickness (blunter — it also
   loosens the socket drift check);
3. exclude boundary walls from `_mesh_boxes`.

Option 1 is the one that matches what both producers actually build.

## What was derived, and from where

Everything below comes from the variable that *placed* the geometry. No
value was measured off a mesh or typed by hand.

| field | towers | treasure | corners |
|---|---|---|---|
| `surfaces` | `stones` — routecheck's own ordered list, plus `_deck`'s bridge | `_treasure_shell`'s `T_SIDE` floor + `_plinth`'s two step literals | `_corner`'s single `C_SIDE` floor |
| `traversal` | consecutive `stones` pairs, `kind` from the rise | the two plinth steps, `mandatory: false` | none (flat) |
| `volumes` | `_core`'s `CORE` column as `no_build`, arrival, objective | the plinth mass as `no_build`, arrival, objective | arrival |
| `sockets` | entry + exit from `exit_offset`, four `enemy_high` from the widest raised stones | entry + exit | entry + exit carrying `exit_yaw` |
| `exit_yaw` | 0 | 0 | `turn * 90` |

`stones` is the headline: it was computed, validated against `max_safe_gap`
by `routecheck.assert_reachable`, and then discarded. P1 is what finally
reads it.

**`exit_yaw`'s sign is not re-derived here.** `shell_corner_left`'s docstring
works it out from `zone_builder._rot` and a Godot basis; an earlier version
of that file had left and right swapped until a render disagreed with its own
caption (L-61). `turn = +1` is a LEFT turn, yaw +90.

## Derived vs assigned

**DERIVED** — every geometric field above, plus `size` (an axis swap of the
Blender bounding box) and the family half of `semantic_tags` (from the id).

**ASSIGNED, and labelled as such:**

- `semantic_tags`'s second entry is the builder's own descriptor —
  `spiral` / `gantry` / `collapse`, `protected` / `stored` / `displayed`,
  `turn_left` / `turn_right`. Factual, from `meta`, but a *naming* choice.
- `fallback` chains each shell to the procedural entry for its chamber type.
  Corners have no procedural counterpart — `corner()` is a corridor with a
  turn and the Zone schema has never carried one — so they chain to
  `shell_corridor_proc`. **A judgement call, flagged.**

**NOT EMITTED, deliberately:**

- **`size_class`.** The study said it was required for shells; the landed P1
  makes it `SizeClass | None = None`. Shipping a guess would dress taste as
  geometry. Footprints are 6 × 6 / 8 × 8 / 12 × 12 if the owner wants to
  assign small / medium / large, but the art lane is not assigning it.
- **`cost`.** Schema default, for the same reason.
- **intent tags.** Design, not measurement.

## The axis conversion, explicit

Three orders exist in the art manifests and only one is Godot's:

| field | order | `shell_tower_gantry` |
|---|---|---|
| `size` | **Blender** `[outer_width, LENGTH, outer_height]` | `[12.8, 14.6, 20.5]` |
| `interior` | Godot `[width, HEIGHT, length]` | `[12.0, 20.0, 12.0]` |
| `size_godot` → the pack's `size` | Godot `[width, height, depth]` | `[12.8, 20.5, 14.6]` |

`ShellValidator._check_envelope` reads the pack's `size` **as a Godot
Vector3**. Feeding the raw art `size` would have set the gantry tower's
height to 14.6 m — its length — instead of 20.5 m, and seven of the eight
square-footprint shells would have hidden it.

`roomcontract.assert_axis_order` runs at build time and states the invariant
rather than a tolerance:

- outer height ≥ interior height, outer length ≥ interior length;
- `size_godot == [size[0], size[2], size[1]]`, exactly.

Its first version used "agree within the wall thickness" and
`shell_treasure_coffer` failed it honestly — a coffered ceiling pocket puts
its outer height 1.8 m above its interior. That is the shell being itself,
not an axis error.

## Traversal markers live in the `.tscn`, not the `.glb`

`ShellValidator._check_segment` refuses a **mandatory** segment with no
`<name>_start` / `<name>_end` `Marker3D` — an unverifiable mandatory route is
refused rather than assumed good. The eight approved meshes carry no markers
and are not being remodelled, so the exporter builds them into the **wrapper
scene**, from the same manifest values the segment was declared from. Every
`.glb` stays byte-identical.

**Production should know this weakens one check.** For a script-generated
shell the marker and the manifest share one ancestor, so the drift comparison
between them is tautological. What still bites — and did — is the measured
rise and span against `max_safe_gap`.

That check caught a real error during this retrofit. The first version
declared segment endpoints at surface **centres**; `routecheck.jump_distance`
measures **edge to edge**. A spiral's last platform to its deck came out as a
6.59 m jump against a 2.60 m base-kit reach, when the two footprints actually
overlap and the crossing is a step. Endpoints now use the same closest-pair
measure routecheck uses, so a declared segment and a validated one describe
the same movement.

## Per-shell result

| shell | surfaces | traversal | volumes | sockets | exit_yaw | pack `size` (Godot) | review |
|---|---|---|---|---|---|---|---|
| `shell_tower_collapsed` | 11 | 9 | 3 | 6 | 0 | `[12.8, 11.5, 14.6]` | pending |
| `shell_tower_spiral` | 12 | 10 | 3 | 6 | 0 | `[12.8, 14.5, 14.6]` | pending |
| `shell_tower_gantry` | 23 | 21 | 3 | 6 | 0 | `[12.8, 20.5, 14.6]` | pending |
| `shell_treasure_vault` | 3 | 2 | 3 | 2 | 0 | `[8.8, 5.4, 8.8]` | pending |
| `shell_treasure_cache` | 3 | 2 | 3 | 2 | 0 | `[8.8, 5.4, 8.8]` | pending |
| `shell_treasure_coffer` | 3 | 2 | 3 | 2 | 0 | `[8.8, 6.3, 8.8]` | pending |
| `shell_corner_left` | 1 | 0 | 1 | 2 | **+90** | `[6.8, 4.5, 6.8]` | pending |
| `shell_corner_right` | 1 | 0 | 1 | 2 | **−90** | `[6.8, 4.5, 6.8]` | pending |

## Headroom: 47 predictions, and they are predictions

`tools/content/preflight_shells.py` compares declared surfaces against each
other and reports where one sits under another within `HEADROOM` (2.4 m).
**That is not the audit.** `room_audit.gd` fires real probes and samples each
surface at u, v ∈ {0.2, 0.5, 0.8} of its extent; what is overhead at those
nine points is a physics question this cannot answer.

Two families of prediction, both worth Production seeing before the audit
runs:

- **Tower climbs.** Consecutive spiral and gantry platforms are `PLAT` 2.6 m
  across and spaced 2.4 m, so each overhangs the one below by ~0.2 m at 1.0 m
  of rise. The sampled band reaches 0.78 m from centre and the overhang strip
  is the outer 0.2 m, so the samples do not land in it — but that is the
  sampler missing it, not clearance existing.
- **Tower ground and treasure plinths.** The 12 × 12 `ground` surface has
  platforms over parts of it, and a plinth step sits over the floor it stands
  on. Both are declared **as built**: the surface is what the builder laid,
  and P1's own rule is *declared decides, measured vetoes*. Shrinking a
  declared rect to dodge a sampler would be gaming the check.

If the audit refuses any of these, the finding is real and belongs to the
owner — not to a quiet edit here.

## Where P1 differs from the study

Recorded because the brief said to target the implementation:

1. **`size_class` is optional**, not required for shells.
2. **The socket vocabulary is narrower.** `cover`, `reactive` and
   `enemy_high` were promoted; the study's `machinery`, `container`,
   `hazard`, reward-pocket, `vista` and `presentation` kinds are absent by
   design — a kind with no consumer is a kind nobody can be held to.
3. **`exit_offset` is the `exit` socket's position**, read by
   `_exit_offset`, and it means the NEXT ROOM'S ORIGIN rather than a door
   face. The eight declare it accordingly.

## Rebuild and re-verify

```
.tools/blender/blender -b --python tools/blender/build_towers.py
.tools/blender/blender -b --python tools/blender/build_rooms.py
tools/export_content_pack.sh                    # regenerate godot/content/
tools/verify_content_pack.sh                    # BOTH Production validators
python3 tools/content/preflight_shells.py 99379e5
```
