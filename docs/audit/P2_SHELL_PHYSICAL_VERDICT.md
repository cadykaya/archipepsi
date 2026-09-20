# P2 — the first real physical verdict on the eight authored shells

Art head `a798b2c` (collision landed at `5c85265`). Measured by
`RoomAudit` through `make godot-room-contract`, on the imported shells in
the real physics space. **Author-declared metadata is a claim; Godot
measurement is authority** — every number below is a ray or a capsule,
not a manifest field.

All eight remain `review: "pending"`. The catalog offered to Epsilon is
empty, the Zone digest is unchanged, and every chamber still builds
procedurally. Nothing here changes what a player sees.

## Collision imported, and it is real

| shell | render meshes | bodies | shapes | shape class |
|---|---:|---:|---:|---|
| `shell_corner_left` | 1 | 10 | 10 | `ConvexPolygonShape3D` |
| `shell_corner_right` | 1 | 10 | 10 | `ConvexPolygonShape3D` |
| `shell_tower_collapsed` | 1 | 21 | 21 | `ConvexPolygonShape3D` |
| `shell_tower_gantry` | 1 | 33 | 33 | `ConvexPolygonShape3D` |
| `shell_tower_spiral` | 1 | 22 | 22 | `ConvexPolygonShape3D` |
| `shell_treasure_cache` | 1 | 16 | 16 | `ConvexPolygonShape3D` |
| `shell_treasure_coffer` | 1 | 20 | 20 | `ConvexPolygonShape3D` |
| `shell_treasure_vault` | 1 | 12 | 12 | `ConvexPolygonShape3D` |

* **Convex, as specified.** No `ConcavePolygonShape3D` anywhere.
* **Render geometry is not duplicated as collision.** Exactly one
  `MeshInstance3D` per shell; the hulls are separate bodies.
* **No `-col` / `-convcol` / `-colonly` mesh is being drawn.** Zero
  visible meshes carry an import suffix in their name.
* **Floors, walls and ceilings collide.** Every declared surface returns
  a floor hit at its declared height at 225/225 sample points; the
  headroom findings below exist *because* the ceilings and decks above
  them stopped a ray.
* **No collider seals a doorway.** `_openings_are_holes` puts the
  player's own capsule on the entry plane and the exit plane of all
  eight shells at two stances. Zero findings.

## The verdict

`structural = 0` on all eight: every shell is a well-formed room output.
What follows is physical.

| shell | findings | A | B | C |
|---|---:|---:|---:|---:|
| `shell_corner_left` | **0** | 0 | 0 | 0 |
| `shell_corner_right` | **0** | 0 | 0 | 0 |
| `shell_tower_collapsed` | 28 | 18 | 1 | 9 |
| `shell_tower_gantry` | 2 | 0 | 0 | 2 |
| `shell_tower_spiral` | 15 | 9 | 0 | 6 |
| `shell_treasure_cache` | 10 | 0 | 9 | 1 |
| `shell_treasure_coffer` | 10 | 0 | 9 | 1 |
| `shell_treasure_vault` | 10 | 0 | 9 | 1 |
| **total** | **75** | **27** | **28** | **20** |

Art predicted 47 headroom notes. Measured: exactly 47 (27 collapsed,
2 gantry, 15 spiral, 3 treasure floors). The other 28 are the treasure
step and one socket. Two further findings — a 1.00 m rise on the gantry
and the spiral — were the audit's own defect and are fixed; see the last
section.

### The decisive measurement

Every classification below rests on one probe the previous audit did not
make: **sweep the declared rect on a 15 x 15 grid, inset by the player's
own diameter, and at each point ask whether the floor is at the declared
height AND a 0.4 m x 1.8 m capsule fits standing on it.** That converts
"has 0.50 m of headroom" — which sounds fatal and often is not — into
"how much of this surface can a player actually use".

| surface | usable / 225 | reading |
|---|---:|---|
| corner `floor` | 189 | clean |
| gantry `step_*` | 195–225 | 2.6 m x 2.6 m platforms, metres of clear stance |
| gantry `landing_*` | 188–215 | clean |
| gantry / spiral / collapsed `ground` | 145–152 | overhung by its own stair |
| collapsed `rubble_0_0`, `rubble_0_1` | 90 | overhung by the next stone |
| spiral `platform_2`, `platform_5`, `platform_7` | 105–165 | partly overhung |
| treasure `floor` | 126–138 | overhung by its dais |
| treasure `step_high` | 225 | clean |
| **collapsed `rubble_1_0`, `rubble_1_1`** | **0** | **A** |
| **spiral `platform_6`** | **0** | **A** |
| **treasure `step_low`** | **0** (height found at 4) | **B** |

The separation is wide and clean: the smallest legitimate surface is
40 % usable, and the defects are 0 %. Nothing sits near the boundary.

## A. REAL GEOMETRY DEFECT — 27 findings, 2 shells

**The last rungs of the collapsed and spiral climbs run UNDER the top
deck, and a 1.8 m player does not fit.**

* `shell_tower_collapsed`: `rubble_1_0` (top y = 4.00) measures
  **1.50 m** of clearance under the `deck` slab (top y = 6.00, underside
  5.50), and `rubble_1_1` (top y = 5.00) measures **0.50 m** under the
  deck and under `rubble_1_2`. 0/225 usable on both.
* `shell_tower_spiral`: `platform_6` (top y = 7.00) lies entirely inside
  the `deck` footprint (top y = 9.00, underside 8.50) — **1.50 m** of
  clearance, 0/225 usable. `platform_7` is 105/225 usable overall, but
  the arrival point the manifest names, z = 8.6, is in the 0.50 m strip
  under the deck.

Both are on the **mandatory** route: `floor_0_to_rubble_1_0`,
`rubble_1_0_to_rubble_1_1`, `rubble_1_1_to_rubble_1_2` and
`platform_5_to_platform_6`, `platform_6_to_platform_7` all declare
`mandatory: true`. There is no declared way past them.

This is geometry, and it is Art's. No metadata edit rescues it, and none
was made. It is also settled independently of the open question in
section C: a surface with zero usable area is refused under either
reading of the contract.

## B. METADATA DERIVATION DEFECT — 28 findings

### `step_low`, in all three treasure shells (27)

Declared a walkable Surface at y = 0.40, 3.0 m x 3.0 m. `step_high`
(2.2 m x 2.2 m at y = 0.80) sits on top of it, leaving an exposed ring
**0.40 m wide** against a **0.80 m player diameter**.

Measured: of 225 player-inset sample points, **4** find the declared
0.40 m height at all — the extreme corners — and **0** are usable.
Nobody stands on `step_low` anywhere, ever.

The geometry is right and should not be touched: a two-tier dais with
0.40 m risers is well inside `MAX_VERTICAL_STEP` and reads correctly as
a pedestal. What is wrong is the claim. `step_low` is a **riser**, not a
stand surface, and the exporter declared it because it is a horizontal
top face. The contract is an API, not a mesh inventory: a `stand`
Surface must name somewhere a player can be.

Like section A, this is decided independently of section C — a surface
with zero usable area is refused under either reading.

### `shell_tower_collapsed` socket `high_3` (1)

An `enemy_high` socket at (3.8, 1.3, 2.0), derived as `rubble_0_0`'s
centre + 0.3 m. But `rubble_0_0` (x in [2.3, 5.3], z in [0.7, 3.3]) and
`rubble_0_1` (x in [1.8, 4.8], z in [2.2, 4.8]) **overlap**, so the
stone's centre sits 0.2 m inside the shadow of the stone above it. An
enemy placed there stands in rock. Deriving the socket from the stone's
*clear* area rather than its centre fixes it.

## C. CONTRACT SEMANTIC MISMATCH — RESOLVED: the owner chose C(ii)

The remaining 20 findings were one shape, on five shells: **a `stand`
Surface whose declared rect is the mesh's true top face, part of which is
under other geometry.** A ground floor under its own staircase (collapsed
1, gantry 2, spiral 1). A rubble stone under the next stone (collapsed 6,
spiral 5). A treasure floor under its dais (3). Measured usable area:
90/225 to 188/225. None zero; none full.

**The tower stones are legitimate general-purpose stand surfaces, not
traversal-only footholds.** That was the specific question, and the
measurement answers it: 2.6 m x 2.6 m to 3.0 m x 2.6 m platforms with
40-100 % of their player-inset area clear. Removing their `Surface`
declarations would throw away real, fightable space.

### The ruling

> A `stand` Surface does NOT mean every point of its rectangular extent
> is guaranteed clear. It means: this bounded region is OFFERED to a
> placement consumer, and Production can find a physically valid
> placement somewhere within it.

Deliberately the same shape as **a socket is an offer, not an order**.
The room contract is an API for usable space, not a decomposition of
every mesh top face into maximally clear rectangles.

A Surface with **zero** valid placements is invalid, and stays invalid.

### What it does NOT promise

Not that every point is clear. Not that the centre is clear. Not that
every player-sized point is clear. Not that the producer tessellated
around the stairs, pillars and daises standing on it.

### Validity is geometric, not a percentage

The 15 x 15 usable-area sweep is evidence and reporting. **No
percentage is encoded anywhere as a threshold.** The rule is: there
exists a footprint that fits. That is what separates a 40 %-usable
rubble stone from a 0 %-usable one, and it would still separate them if
every good room in the project measured 5 %.

### One solver, two consumers

`godot/scripts/content/placement.gd` owns the candidate set, the order it
is walked, the footprint rule and the verdict.

* `RoomAudit._surfaces_hold_weight` asks **can this Surface keep its
  promise?** with a standing player's footprint.
* `Activities._best_surface` / `_spot_on_surface` ask **where is the
  valid point?** with the element's own footprint.

Both call `Placement.find` over the same candidates in the same order.
The EVIDENCE differs and cannot not differ: the audit runs on a room in
the tree and measures with rays and shape queries; `Activities` runs
inside `build_chamber` on a root that is still detached and must use the
box derivation. So each passes a `clear` Callable, and the suite pins
their verdicts against each other on every producer -- the composer may
be stricter (a convex hull's AABB is bigger than the hull) but may never
be looser.

For the composer to see an authored room at all,
`ChamberBuilders.all_solid_boxes` now reads **collision shapes** as well
as meshes: an authored shell is one merged `MeshInstance3D`, so mesh
AABBs describe nothing inside it, and without its hulls the composer was
placing against a room it could not see.

### Findings after the ruling

| shell | before | after | what survives |
|---|---:|---:|---|
| `shell_corner_left` | 0 | **0** | — |
| `shell_corner_right` | 0 | **0** | — |
| `shell_tower_collapsed` | 28 | **3** | `rubble_1_0`, `rubble_1_1` (A); socket `high_3` (B) |
| `shell_tower_gantry` | 2 | **0** | — |
| `shell_tower_spiral` | 15 | **1** | `platform_6` (A) |
| `shell_treasure_cache` | 10 | **1** | `step_low` (B) |
| `shell_treasure_coffer` | 10 | **1** | `step_low` (B) |
| `shell_treasure_vault` | 10 | **1** | `step_low` (B) |
| **total** | **75** | **7** | 27 A + 28 B collapse into 3 A + 4 B surfaces |

**All 20 C findings disappeared and no A or B finding did.** The count
also changes shape: a finding is now one broken promise per surface
rather than one per failing sample point, so the 18 collapsed-rubble
findings became two, and the 27 `step_low` findings became three.

## FIXED: a measurement is not a declaration

Two findings — `step_0_0_to_step_0_1` on the gantry and
`platform_0_to_platform_1` on the spiral — reported a 1.00 m mandatory
rise as beyond a 1.00 m limit.

Measured rise: **1.000039101 m**. A `.glb` stores vertex positions as
quantised floats, so of thirty stairs modelled at exactly 1.0 m, the two
whose vertices rounded up were refused and the twenty-eight that rounded
down were not. `MAX_VERTICAL_STEP` means the player CAN take a 1.0 m
step; an audit that refuses the step at the limit refuses the law it
exists to enforce.

`RoomAudit.AS_BUILT_SLACK = 0.01` now names the tolerance once, and the
rise check and the span check — which had always carried a bare `+ 0.01`
three lines below — read the same constant. Two comparisons in one
function no longer hold two views of how exact a ray is.

The slack is pinned from both sides by
`_test_a_measurement_at_the_limit_is_still_the_legal_move`: a step 4 mm
over the limit is the same step, a step 15 cm over it is still refused,
and the constant must sit between them. Nothing else moved: the finding
count went 77 to 75, and every other finding on every shell is
unchanged.

## What each family needs

| family | verdict | who acts |
|---|---|---|
| `shell_corner_left`, `shell_corner_right` | **P2-A: measures true.** Zero findings. Ready for review the moment the owner wants to promote them. | owner |
| `shell_tower_gantry` | **P2-C only.** Two findings, both its own ground under its own stair. No geometry defect, no bad metadata. | owner (section C) |
| `shell_tower_spiral` | **P2-A + P2-C.** `platform_6` is unusable under the deck. | Art, then owner |
| `shell_tower_collapsed` | **P2-A + P2-B + P2-C.** `rubble_1_0` and `rubble_1_1` unusable under the deck; socket `high_3` in rock. | Art, then owner |
| `shell_treasure_*` (3) | **P2-B + P2-C.** `step_low` is a riser declared as a Surface. Geometry is correct and must not be changed. | Art, then owner |

---

# P2 TECHNICAL CERTIFICATION — the eight shells satisfy the room contract

Art head `1d22cef`, integrated verbatim: every Production-tracked content
file is **byte-identical** to Art's (`SCENE_PLAN.json`,
`authored_art.json`, and all eight `.glb` + `.tscn`). Nothing was
reproduced by hand.

**All eight shells: 0 structural findings, 0 physical findings.**

| shell | surf | trav | sock | doors | mesh | hull | structural | measured |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `shell_corner_left` | 1 | 0 | 1 | 2 | 1 | 10 | **0** | **0** |
| `shell_corner_right` | 1 | 0 | 1 | 2 | 1 | 10 | **0** | **0** |
| `shell_tower_collapsed` | 11 | 9 | 16 | 2 | 1 | 21 | **0** | **0** |
| `shell_tower_gantry` | 23 | 21 | 28 | 2 | 1 | 33 | **0** | **0** |
| `shell_tower_spiral` | 12 | 10 | 17 | 2 | 1 | 22 | **0** | **0** |
| `shell_treasure_cache` | 2 | 1 | 3 | 2 | 1 | 16 | **0** | **0** |
| `shell_treasure_coffer` | 2 | 1 | 3 | 2 | 1 | 20 | **0** | **0** |
| `shell_treasure_vault` | 2 | 1 | 3 | 2 | 1 | 12 | **0** | **0** |

The counts are the point. Zero findings over zero probes is the most
dangerous line a suite can print, so the report now says what each class
examined: stand Surfaces, traversal segments, sockets, the two doorway
planes, the mesh AABBs the envelope check reads, and the collision hulls.

## The seven old findings, closed

Proven by running **the same certification probes against the old pack**
in a worktree at `1648fa9` — they fail there and pass here, so a pass is
evidence rather than an absence of measurement.

| finding | class | old pack | new pack |
|---|---|---|---|
| collapsed `rubble_1_0` | A | route arrives with nowhere a 1.80 m player fits | **passes** |
| collapsed `rubble_1_1` | A | route arrives with nowhere a 1.80 m player fits | **passes** |
| spiral `platform_6` | A | route arrives with nowhere a 1.80 m player fits | **passes** |
| collapsed `high_3` | B | no room for the `ranged` envelope | **passes** |
| cache / coffer / vault `step_low` | B | 0/225 usable, declared a Surface | **no longer declared**; geometry unchanged |

The old pack additionally fails **spiral `high_3`**, which the previous
contract did not flag: `_points_have_ground` uses a 0.5 m buried-box and
that socket cleared it by ~0.05 m. Measuring the actual `ranged` envelope
(0.7 x 1.4 x 0.7) shows it never had room. That is an independent
confirmation of the owner's approved judgment call 2 — a socket is an
offer, and one nothing fits in is not an offer.

## Deck-well secondary effects

Measured from the resulting room, not from the helper that cut it.

| checked | how | result |
|---|---|---|
| Check / reward anchor on valid support | `_arrivals_are_standable` + `_test_a_check_never_stands_inside_the_room` | clean |
| deck sockets physically valid | `_points_have_ground` + the `ranged` envelope probe | clean |
| no new fall-through or unreachable area | every `stand` Surface keeps its promise under `Placement.find` | clean, all 54 declared surfaces |
| no doorway or open-envelope issue | `_openings_are_holes` (player capsule, both planes, two stances) + `_geometry_stays_inside_its_bounds` | clean |
| route continuous, climb reaches the upper area | mandatory-route probe on all 40 authored mandatory segments | clean |
| no collider spans the new opening | implied and measured: a player standing on `rubble_1_1` (y=5.00) occupies to y=6.80, through the old deck plane at y=6.00 | clean |
| player cannot be trapped in the well | the well contains the climb, and every mandatory arrival admits a standing player, so there is no enclosed pocket | clean |
| no new traversal violates movement law | `_traversal_is_true` with `AS_BUILT_SLACK` | clean |

Collision hull counts are unchanged (21 collapsed, 22 spiral): the deck
was reshaped, not split, so the well is a hole in one hull rather than a
new set of pieces.

## The moved `high_3` sockets

Both are supported (a floor ray finds ground beneath them), not buried,
and hold the full `ENEMY_ENVELOPES["ranged"]` box rather than merely
clearing a 0.5 m probe. Determinism is covered by the existing
same-chamber-twice test and by the whole pack being source-derived.

Neither is at its historical coordinate, and neither needs to be: the
contract is physical validity, not coordinate preservation.

## Gate state

* All eight remain `review: "pending"`. **Not promoted.**
* `shell_catalog()` offered to Epsilon: **0 entries.**
* Real-Zone digest **`6e8d83d0f3ec088b`** — 23 rooms, 15 Checks, 922
  points, 35 enemies. The 23-chamber activity audit JSON is
  **byte-identical** to `1648fa9`.
* Procedural fallback unchanged; no authored shell appears in ordinary
  generation.
* No Production code writes `size_class`, `exit_yaw`, `fits_floors`,
  corner tags or repaired surface/traversal/socket metadata. Every
  reference is a reader or a validator, so a fresh Art regeneration is
  consumable with no patch to reapply.

## P2 TECHNICALLY COMPLETE

**The eight authored shells satisfy the room contract.**

This is not owner approval for player-facing use. `review` stays
`pending` on all eight.
