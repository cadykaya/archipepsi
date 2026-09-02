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

## One blocker, and it is Production's to decide — CLOSED at `eda4fd9`

> **Resolved upstream, and the diagnosis held.** Production replaced both
> producers' private opinions with one shared `RoomContract.WALL_ALLOWANCE`,
> pointed `RoomAudit` at every mesh rather than only furniture-scale ones,
> and had `ShellValidator` delegate to the same rule. Zero envelope
> violations across the eight. The section below is kept as written because
> the reasoning is the reason it was fixed rather than worked around.

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

## P2-C — collision, and the three fields Production supplied by hand

`eda4fd9` integrated all eight and could measure **none** of them. Every
shell imported with one `MeshInstance3D` and zero colliders, so all 625
audit findings were of the "nothing is there" class and the verdict was NOT
MEASURABLE rather than measured-and-safe. Structural violations: zero. The
metadata was well formed and describing a room that was not physically
present.

### Collision is derived, not authored eight times

`tools/blender/roomcollision.py`. Two facts about the shells make this a
derivation rather than eight hand-built colliders:

1. **Every piece of all eight is a `brushkit.block`** — verified, the two
   builders call no other primitive. So a collider is a COPY of a piece,
   and its convex hull is that box exactly. "Simpler than the visual mesh
   and never larger than it" holds by construction, not by tolerance.
2. **Every piece is already painted with one of four roles**, and that
   choice is the author's statement about what the piece IS:

   | role | the player | collides |
   | --- | --- | --- |
   | `floor` | walks on it | yes |
   | `wall` | stops at it | yes |
   | `ceiling` | does not pass it | yes |
   | `trim` | looks at it | **no** |

**Trim is excluded on the spec's authority, not for convenience.** A
platform nose is 0.14 m wider than the slab it skirts and sits under its
top face; colliding it would make every platform wider than the `Surface`
the manifest declares — a visual change that moves a reachability, which
is exactly what S18 forbids.

### `-convcolonly`, and why that suffix

Verified empirically against this repo's own Godot rather than from memory,
by importing a probe `.glb` carrying all four suffixes:

| suffix | result |
| --- | --- |
| `-convcolonly` | `StaticBody3D` + `CollisionShape3D`(**Convex**), no mesh |
| `-colonly` | `StaticBody3D` + `CollisionShape3D`(Concave), no mesh |
| `-col` | `MeshInstance3D` + body + Concave |
| `-convcol` | `MeshInstance3D` + body + Convex |

Convex, because §3 allows trimesh only for decorative geometry the player
cannot stand on and these are floors. `only`, for two reasons: the collider
must not render, **and** `RoomAudit`'s envelope check reads `MeshInstance3D`
nodes — a collider that imported as a mesh would enter that arithmetic and
could refuse a room for geometry nobody can see.

### Colliders per shell

| shell | colliders | surface samples probed |
| --- | ---: | ---: |
| `shell_tower_gantry` | 33 | 207 |
| `shell_tower_spiral` | 22 | 108 |
| `shell_tower_collapsed` | 21 | 99 |
| `shell_treasure_coffer` | 20 | 27 |
| `shell_treasure_cache` | 16 | 27 |
| `shell_treasure_vault` | 12 | 27 |
| `shell_corner_left` | 10 | 9 |
| `shell_corner_right` | 10 | 9 |

All convex, zero concave, one visible mesh each — unchanged.

### The three fields, each from its own source

| field | value | where it came from |
| --- | --- | --- |
| `size_class` | towers `medium`, treasure `small`, corners `small` | **owner design assignment**, tabled in `_SIZE_CLASS` with its provenance. NOT derived from metres — a treasure room is 8.8 m and a corner 6.8 m and both are "small". |
| `exit_yaw` | `corner_left` +90, `corner_right` −90 | the builder's own `turn × 90`, **copied**. Production proved the sign end to end; there is no second opinion about which way a corner turns. |
| `fits_floors` | `[2]` / `[3]` / `[5]` | the `floors` variable the tower builder was given. Not parsed from the id, not counted off the platforms. |

The drift check is independent evidence these are right: it compares field
for field against Production's landed pack and flags **nothing** on these
three, because Art now emits exactly what Production applied by hand.

### The corners are corridors

`corner` is not a chamber type — `zone.py` has `corridor`, `arena`, `tower`,
`treasure_room` and never had a fifth — so the old tag meant the two corner
shells could never be offered to anything even once approved. Chamber type
is now `corridor`; `corner` survives as a **shape tag** beside it, which
describes the room without claiming to be a type. The turn itself travels in
`exit_yaw` and in the authored form.

This is the one change to a field Production already carries, so it is named
in `verify_manifest.DECLARED_HANDOFF` with its reason. Everything not on
that list still fails the drift check.

### The visible art did not change

`python3 tools/content/diff_shell_glb.py <ref>` reads both revisions of every
shell `.glb` and compares **accessor payloads byte for byte**: POSITION,
NORMAL, TEXCOORD_0, indices, the material JSON, and the embedded PNGs. All
eight: visible mesh identical, textures identical, colliders added. The
eleven unpacked F3 shells: byte-identical, not rebuilt.

## P2-D — the seven that survived C(ii), repaired at the source

Production settled the Surface contract at `1648fa9`: a `stand` Surface
promises that a valid placement can be FOUND somewhere in it, not that
every point of its rect is clear. Findings on the eight shells went
**75 to 7**, and all seven that survived were Art's.

### The check came first, and it reproduced all six before anything moved

`roomcollision.measure_stances` mirrors `Placement.find` over
`RoomAudit.player_stands_here` -- the same 9 x 9 candidate grid, the same
rule that the whole 0.8 m footprint stays inside the region, the same
2.4 m clearance volume lifted 0.02 m off the surface -- against the
collider boxes the build script placed.

Run against the unrepaired shells it returned **exactly** Production's
six surface findings, with the numbers the engine measured:

| shell | surface | headroom, predicted | measured by Production |
| --- | --- | ---: | ---: |
| `shell_tower_collapsed` | `rubble_1_0` | 1.50 | 1.50 |
| `shell_tower_collapsed` | `rubble_1_1` | 0.50 | 0.50 |
| `shell_tower_spiral` | `platform_6` | 1.50 | 1.50 |
| `shell_treasure_*` (x3) | `step_low` | 0.00 | zero placements |

Reproducing the known-bad set before touching anything is what makes the
tool worth trusting afterwards. It is now `assert_standable` and it stops
the build.

### A — the two towers: the deck was over the climb

One cause for all three. The deck is a 0.50 m slab at `rise` across the
back 4 m, and both climbs pass under it: a rung below it has
`rise - 0.50 - h` metres and no more.

Neither climb could move. The spiral's `inset`, `margin` and `spacing`
are `tower()`'s own, so an authored spiral climbs where a procedural one
does; the collapsed tower's alternating half-floors are what that shell
is, and an earlier left/right version was already refused by `routecheck`
for a 3.60 m crossing. The deck was art's own slab and had no such claim
on it -- see L-84.

`_deck_well` cuts the deck out of the column the climb comes up, derived
from `stones` and `heights`: any rung above `rise - DECK_THICK -
HEADROOM` whose plan falls under the deck contributes its x-band, plus a
margin, and a leftover sliver narrower than a player is given to the well
rather than left as deck.

| shell | deck before | deck after | why |
| --- | --- | --- | --- |
| `shell_tower_collapsed` | 12.0 x 4.0 | **7.4 x 4.0**, x from -1.4 | the level-1 rubble climbs at -x |
| `shell_tower_spiral` | 12.0 x 4.0 | **8.6 x 4.0**, x to +2.6 | the helix's last turn is at +x |
| `shell_tower_gantry` | 12.0 x 4.0 | **unchanged** | nothing of its climb is under the deck |

The deck rect, its routecheck stone, the sockets standing on it, the
Check anchor and the reward volume all move with it, because all five are
now read from the rect that was actually built. `routecheck` re-run:
worst jumps 0.80 / 1.75 / 0.10 m against 2.00 allowed.

### B — the three treasure rooms: `step_low` was never standable

`_plinth`'s 3.0 m lower step carries its 2.2 m upper step, so what is
left of it is a **0.40 m ring against a 0.80 m player**. Zero valid
placements, in all three shells.

**The geometry is right and is untouched** -- mesh and collision both,
proven byte-identical. A 0.40 m riser is legitimate architecture, well
inside `MAX_VERTICAL_STEP`, and it still collides because `_plinth`
paints both steps `floor`. What was wrong is the CLAIM. `step_low` is no
longer declared a stand Surface, the two 0.40 m rises become the one
0.80 m rise a player actually makes, and the mass stays declared as the
`plinth` `no_build` volume -- which is what a pedestal step is to a
composer.

### C — `high_3` was the centre of a stone with another stone on it

Consecutive rubble stones overlap in plan, and the socket was the
surface's centre, which put it 0.05 m inside the slab above. `stance_spot`
now runs `Placement`'s candidate search and returns the clear spot
NEAREST THE CENTRE, so a socket whose centre is already fine does not
move. Two moved, both by 0.225 m: collapsed's `high_3` in depth, and
spiral's `high_3` in width -- the second was not a Production finding and
had 0.05 m of margin against the audit's own `_buried` box. See L-85.

### What the engine says now

`verify_collision.gd`, rewritten to C(ii) and run on the shipped `.tscn`
files: **eight shells, zero needing attention.** Every declared Surface
offers a placement; the tightest still offers 32 per cent of its spots.
Still evidence and not a verdict -- `room_audit.gd` is the authority.

### Two findings, both reported and neither corrected — SUPERSEDED

Kept as written, because what happened to them is the point: one was
answered by Production changing the contract and the other by Art
changing the claim, and neither was answered by the shell being
redesigned. Both are repaired above.

**`step_low`** (req 38). The three treasure rooms declare it as a walkable
`Surface` and `_plinth`'s upper step stands on it: nine of nine samples
measure 0.80 where 0.40 is declared. The plinth is the approved F3 geometry
and `reward_position` is the engine's, so nothing was remodelled — and the
declaration was not quietly dropped either.

**Headroom** (req 39). 47 findings, which is exactly the count the P2
preflight predicted and could not confirm while the rooms had no collision:
27 in `shell_tower_collapsed`, 15 in `shell_tower_spiral`, 2 in
`shell_tower_gantry`, 1 in each treasure room. Tightest 0.50 m against
`RoomAudit.HEADROOM` 2.40. The towers climb on 1.00 m footholds that
`routecheck` validated as a chain; a `Surface` says a player can stand, and
a rung is not that. The vocabulary has no word for a foothold yet.

### What the collision check refused first

`verify_pack.gd` failed all eight the moment they had collision:
*"carries N collision object; hitboxes are engine-owned"*, applied to all
seventeen entries. Production says no such thing — `ContentInstantiator`
refuses a light on a **light housing** and collision on a **projectile
visual**, two scoped rules in two functions, neither about room shells,
whose collision `RoomAudit` requires. It was the third place the prop rule
had been written as if it were the lane's rule. The check now asserts the
scoped version, including the inverse for shells: a room shell with no
collision is a failure.

## Rebuild and re-verify

```
.tools/blender/blender -b --python tools/blender/build_towers.py
.tools/blender/blender -b --python tools/blender/build_rooms.py
tools/export_content_pack.sh                    # regenerate godot/content/
tools/verify_content_pack.sh                    # BOTH Production validators
python3 tools/content/preflight_shells.py 99379e5
python3 tools/content/diff_shell_glb.py <ref>   # visible art unchanged
xvfb-run -a .tools/godot --headless --path godot -s _verify_collision.gd
```

`verify_collision.gd` is copied into `godot/` for the run and deleted after,
like the other harness scripts. It reports and never declares a PASS.
