# Physical-truth adjudication — plenum collar collision, Hall grapple binding

**Independent audit. 2026-09-03. No implementation.**

Adjudicated references, all three fetched and inspected as detached
read-only worktrees:

| Lane | Ref | Subject |
| --- | --- | --- |
| Production | `f8e09ee` | *A room is entered where it says it is* |
| Art repair | `4441ea5` | *Wave 1: eight declared points that named a centre instead of a place* |
| Art head / report | `26a2914` | *Record the Wave 1 repair in the review and frontier documents* |

This audit changed no product code, repaired no content, altered no
review state and promoted no room. Its only artefact is this file.

---

## Method, and what it can and cannot claim

**No engine ran.** This environment has no Godot and no Blender binary,
so nothing here is a Godot execution trace. What was measured instead is
the engine's *input*, and the engine's *documented deterministic
transform* of it:

1. **The `.glb` files are the importer's input, and they are the same
   bytes in all three references.** `shell_plenum_helix.glb` is
   `md5 4457aca6…` identically at `f8e09ee`, `4441ea5`, `26a2914` and in
   `assets/models/batch040/shells/`. `shell_hall_transit.glb` is
   `md5 7073e44e…` in both lanes. Every `.glb.import` carries
   `nodes/use_name_suffixes=true`, which is what makes the suffix fire.
2. **A `-convcolonly` node becomes exactly one `ConvexPolygonShape3D`,
   whose shape is the convex hull of that node's vertex set.** Godot's
   importer routes the suffix to `Mesh::create_convex_shape()`, which
   concatenates every surface's `ARRAY_VERTEX` and hands it to
   `ConvexHullComputer::convex_hull`; the resulting hull vertices become
   the shape's points, and a `ConvexPolygonShape3D` is solid. `p_simplify`
   is false, so no decomposition happens. A convex hull is uniquely
   determined by its point set, so the hulls computed below are the
   shapes the engine ends up with — not an approximation of them.
   `tools/blender/roomcollision.py` states the same import behaviour,
   verified by the Art lane against this repo's own Godot 4.5.1.
3. **The probes are Production's own.** Every `clear` / `supported` /
   ground-ray window used below is copied from a specific call in
   `godot/scripts/content/room_audit.gd`, and `_grapples`, `_rails` and
   `LaunchSolver.violations` were replayed line-for-line over the hulls.

**Two honest limits, stated rather than smoothed over:**

* **Exact-boundary contacts are engine coin tosses and are labelled, not
  decided.** A ray whose far endpoint lands exactly on a collider face,
  or a point lying exactly on a face, is the case
  `room_audit.gd` itself calls "a coin toss" and `roomcollision.py` calls
  "grazing … not reproducible by arithmetic". Where a verdict turns on
  such a contact this report says so and reports the clearance as
  `0.000 m` instead of asserting an outcome.
* **Scope of the Hall collider set.** `shell_hall_transit.glb` carries 71
  collider nodes. Production measured **73** `CollisionShape3D`
  instantiated and left the +2 unreconciled. The analysis below is over
  the 71 authored shell colliders. Added bodies can only *add* collision,
  so they can strengthen a refusal but not rescue an acceptance; the
  acceptances below carry that caveat, the refusals do not.

---

# QUESTION A — Plenum collar collision topology

## A-1 · The collar hole truly contains invisible collision — 28.800 m³ of it, per collar

**Physical fact proven.** `build_plenum.py:238` builds each collar with
`brushkit.tube(COLLAR_OUT=6.75, mh=4.0, COLLAR_T=0.6, sides=12)` and
paints it `"floor"`, a `SOLID_ROLE`, so `roomcollision.build` emits a
`-convcolonly` twin of it. Measured from the shipped `.glb`:

| | |
| --- | --- |
| collider mesh | 48 unique vertices, 96 triangles, 144 stored verts |
| radii about the machine axis `(x=0, z=10)` | **exactly `{4.00, 6.75}`** — a real hole |
| heights | `collar_0` 44.7333–45.3333, `collar_1` 27.7333–28.3333, `collar_2` 10.7333–11.3333 |
| convex? | **no** — worst vertex lies **10.3837 m** outside a face plane |
| mesh volume | **53.2124 m³** |
| convex hull volume | **82.0123 m³** |
| difference | **28.7999 m³** |

The difference matches the analytic hole exactly: a regular 12-gon of
circumradius 4.0 has area 48.0000 m², and `48.0000 × 0.6 = 28.8000 m³`.
Across the three collars the imported collision is **246.037 m³** against
a visual **159.637 m³** — **86.40 m³ of collision with nothing to see**.
A 12-piece convex decomposition of the same annulus measures
**159.638 m³**, i.e. the visual mesh to within float32 round-trip.

So the reported effect is confirmed and quantified: each collar's
collider is a solid 12-gon prism of circumradius 6.75, and the hole is
filled out to radius 4.00.

**Actual player-facing impact: none — proven, not assumed.**

* The filled hole is a 12-gon of circumradius 4.00 (inradius 3.864), and
  the hanging machine's collider is `(-4, 12, 6) … (4, 68, 14)`. Over a
  `0.02 m` grid, **120 129 of 120 129 fill samples lie inside the
  machine's 8 × 8 footprint; 0 lie outside it.** The fill is never in
  open plan.
* Standing on the fill: over a `0.10 m` grid, **0 of 4 793 fill samples
  per collar** admit the player's stance box plus `HEADROOM` (2.4 m).
  `collar_0` and `collar_1` fills are *inside* the machine; `collar_2`'s
  fill has the machine's underside 0.667 m above it and a 1.8 m player
  does not fit.
* **Walking:** unchanged. **Falling:** unchanged — nothing can fall into
  the fill, because every column above it is occupied by the machine.
  **Rail use:** unchanged *by the fill* (see A-4 — the rail's real
  problem is the ring, not the hole). **The approved shaft form:**
  unchanged; appearance and player-reachable space are identical.

What the fill *does* change is measurement, and that is A-2.

**Why the current gates miss it.** Four independent blind spots, each
verified in the source:

1. `roomcollision.build`'s own docstring rests on a premise that is now
   false: *"Every piece of all eight shells is a `brushkit.block` …
   Verified: the two shell builders call no other brushkit primitive."*
   `build_plenum.py` is a **ninth** shell builder and calls
   `brushkit.tube`. The same claim is repeated in
   `docs/art/ASSET_AUTHORING.md:205` and `docs/art/ART_FRONTIER.md:304`.
2. `roomcollision.assert_exact` compares the collider's **world AABB**
   against its source part's world AABB. The collider *is* a mesh copy of
   the part, so this comparison is a tautology, and an AABB cannot see
   convexity: the annulus and its hull share an AABB exactly.
3. Every art-side physical check — `assert_supports`, `measure_probe`,
   `measure_stances`, `stance_spot`, and `traversallaw.assert_declared`
   via the `_world_box` callback — models a collider as its **AABB**.
   That over-approximation is *larger* than the hull, so the art side
   already believed the collar was solid and could not detect a
   discrepancy in either direction.
4. `RoomAudit` measures the room correctly and finds nothing wrong,
   because there *is* nothing wrong to a ray at the declared height — the
   fill answers it. This is the load-bearing point of A-2.

**Ownership: Art.** The shape and the gate that must refuse it are both
in `tools/blender/`.

**Blocks promotion of `shell_plenum_helix`: yes** — via A-2, whose
evidence this defect manufactures.

**Smallest correct follow-up task.** *Prove the necessary shape rather
than accepting the suggestion:* the requirement is only that **every
mesh carrying `-convcolonly` be convex**, because that is the exact
condition under which `create_convex_shape` returns the mesh itself. A
full convex decomposition library is **not** required and neither is
`-colonly`/trimesh (the spec forbids trimesh under a walkable surface).
For a 12-sided annulus the minimal correct construction is **12 convex
trapezoidal prisms, one per side, emitted as 12 collider nodes** — proven
above to reproduce the visual volume to 0.001 m³. So:

> Add a convexity assertion to `roomcollision.assert_exact` — for each
> collider, every face plane must be a supporting plane of its own vertex
> set — and give `roomcollision` a `build_annulus` path that emits one
> convex wedge per side for `brushkit.tube` parts. Rebuild
> `shell_plenum_helix`. No other shell changes.

**Tests the follow-up must leave behind.**

* A unit test asserting the annulus collider set is convex piecewise and
  that `Σ piece volume == visual mesh volume` within `1e-3` m³.
* A **sabotage test**: replace the wedge set with the single tube twin
  and assert `assert_exact` raises, naming the offending part. Without
  this the new assertion can be deleted silently.
* A repo-wide build-time assertion that **no** `-convcolonly` mesh is
  non-convex, so the tenth shell inherits the rule (it currently
  inherits the false premise instead).

---

## A-2 · None of the three optional collar endpoints is a physically real destination, and the fill is what hides that

**Physical fact proven.** `RoomAudit._traversal_is_true` steps each
endpoint `EDGE_INSET = 0.15 m` outward and fires
`_ray(w + UP*0.4, w + DOWN*GROUND_REACH)`. The three probed points are

| segment | probed point | radius from axis |
| --- | --- | --- |
| `landing_4_to_collar_0` | `(0.1061, 45.3333, 10.1061)` | 0.15 m |
| `landing_7_to_collar_1` | `(0.1061, 28.3333, 9.8939)` | 0.15 m |
| `landing_10_to_collar_2` | `(-0.1061, 11.3333, 9.8939)` | 0.15 m |

— all three deep inside the hole (the ring band starts at 4.00 m).
Result, against the real imported colliders:

| | as imported | with the collars correctly decomposed |
| --- | --- | --- |
| `landing_4_to_collar_0` | **HIT** `pl_collar_0` at y=45.3333 | **NO HIT** |
| `landing_7_to_collar_1` | **HIT** `pl_collar_1` at y=28.3333 | **NO HIT** |
| `landing_10_to_collar_2` | **HIT** `pl_collar_2` at y=11.3333 | **NO HIT** |

And the destinations themselves, against the real player capsule
(`PLAYER_RADIUS 0.4`, `PLAYER_HEIGHT 1.8`):

| endpoint | point inside `pl_machine` | stance + `HEADROOM` box | `TraversalLaw` `fits` capsule |
| --- | --- | --- | --- |
| `collar_0` (0, 45.3333, 10) | **yes** | blocked by `pl_machine` | blocked by `pl_machine` |
| `collar_1` (0, 28.3333, 10) | **yes** | blocked by `pl_machine` | blocked by `pl_machine` |
| `collar_2` (0, 11.3333, 10) | no (machine floor is 12.0) | blocked by `pl_machine` | blocked by `pl_machine` |

**All three endpoints are impossible destinations for the player's own
body**, and Art's report is accurate that two of the three are also
inside the machine collider. `collar_2`'s point is in the 0.667 m slot
between the collar top and the machine's underside — a 1.8 m player does
not fit in it.

So the answer to A-3 as posed is: **no declared collar endpoint describes
a physically real destination.** Each names the centre of the annulus,
which is the axis of eight metres of hanging steel — the same error class
the Wave 1 repair fixed in seven `cover` sockets and the `reward` volume.

**Actual player-facing impact.** Nothing a player can do today changes:
the segments are `mandatory: false`, and no runtime consumer walks them.
The impact is on **certification**: three manifest claims are false, and
the only check that looks at them is answered by collision that is not
there.

**Why the current gates miss it.** Precisely and only because of A-1.
`_traversal_is_true`'s endpoint ray runs on **every** segment — the
`if not bool(seg.get("mandatory", true)) … continue` skip happens
*after* that loop — so these three segments *are* probed on every audit
run, and they pass. Art's certification note that "`_traversal_is_true`
SKIPS OPTIONAL SEGMENTS" is true of the *flood* but not of the endpoint
check. Repair the collar collider alone and the plenum acquires **three
new `RoomAudit` findings** it does not have today. The clean sheet and
the invisible collision are the same fact.

**Ownership: shared handoff, Art first.** Art moves the endpoints onto
the collar band; Production makes the endpoint check independent of
collider convexity. Neither half is sufficient alone — Art's move without
Production's change leaves the next annulus undetectable, and
Production's change without Art's move turns the plenum red.

**Blocks promotion of `shell_plenum_helix`: yes.** Promotion certifies
the manifest true; three declared destinations are false, and the
evidence for the current pass is an artefact.

**Smallest correct follow-up task.**

> Move each `landing_N_to_collar_K` endpoint from the machine axis onto
> the collar band at `REWARD_RADIUS = 5.25`, on the bridge's side of the
> ring — the same constant and the same reasoning the Wave 1 `reward`
> repair already established. Land it **in the same commit as A-1**, so
> the audit never sees the decomposed collar with axis endpoints still
> declared.

**Tests the follow-up must leave behind.**

* A Godot test that each `landing_N_to_collar_K` endpoint passes
  `RoomAudit.player_stands_here` against the instantiated plenum — the
  capsule, not a ray.
* A **sabotage test** that returning any of the three endpoints to
  `(0, top, D/2)` turns the audit red, and that it does so **with the
  collar correctly decomposed** — i.e. the test must fail for the
  geometric reason, not because the fill was removed.
* A Production-side assertion that a traversal endpoint's supporting
  collider is convex, or equivalently that the endpoint is standable and
  not merely over something.

---

## A-3 · `launch_collar` — a declared launch destination 4.000 m inside the machine

*Elevated to a finding in its own right.* This was **not** in Art's
report, is **not** among the eleven measured findings, and **survived the
Wave 1 repair**.

**Physical fact proven.** `shell_plenum_helix` declares

```
launch_source  launch_floor   position (0.0,  0.5,  6.0)  radius 3.0  target launch_collar
launch_target  launch_collar  position (0.0, 28.3333, 10.0)  radius 3.5
```

identically in Production's registry at `f8e09ee` and in Art's manifest
at `26a2914` (all four LARGE shells' offer blocks are byte-identical
between the two lanes). Measured against the real colliders:

* `launch_collar` lies **4.0000 m inside** `pl_machine`'s interior. The
  machine's nearest face is 4 m away and its top face 39.7 m above.
* The player's capsule does **not** fit at the target.
* `LaunchSolver`'s solved arc (apex 31.83 m, flight 2.16 s) is
  **obstructed at sample 4 of 24 — 17 % along — inside `pl_machine`** at
  `(0.00, 12.89, 6.67)`.
* `supported` at the target returns **true**, on `pl_collar_1` — because
  of A-1's fill. Remove the fill and it returns nothing.

This is the identical defect the Wave 1 repair fixed one line away. The
diff at `4441ea5` moved the `reward` volume off `(0, land_y[7]+1, D/2)`
onto the band with the comment *"the centre of the collar, which is the
centre of EIGHT METRES OF SOLID MACHINE"* — and left `dst = (0.0,
land_y[7], D/2.0)` in `main()` untouched. Same point, same room, same
sentence, not repaired.

**Actual player-facing impact.** Zero today: nothing consumes
`launch_source` in production (B-1). The moment any package does, the
plenum's launch pad fires the player into a solid machine, or is
refused — and being refused is the *good* outcome.

**Why the current gates miss it.** Three at once. `RoomAudit.findings`
never reads `offers` — its seven checks cover surfaces, point sockets,
arrivals, openings, `player_entry`, traversal and bounds, and no offer
kind is among them. `build_plenum.py`'s art-side check on the pair is
`0.5 <= span <= 80.0` — a distance, not a place. And `LaunchSolver`, the
one thing that would catch it, has no caller (B-1).

**Ownership: Art.** A declared point carrying the centre of the thing it
names; the same class, source and fix as the eight already repaired.

**Blocks promotion of `shell_plenum_helix`: yes.**

**Smallest correct follow-up task.**

> Move `dst` in `build_plenum.py:408` off the machine axis to the collar
> band, reusing `_reward_spot`/`REWARD_RADIUS`, and re-check that the
> solved arc clears the machine. One expression.

**Tests the follow-up must leave behind.**

* A test that every `launch_target` in every LARGE shell admits the
  player's capsule and has support under it, run against the
  instantiated scene.
* A **sabotage test** returning `launch_collar` to the axis and asserting
  the launch pair is refused with the arc-obstruction reason.
* An art-side build assertion that a `launch_target` is not inside any
  `no_build` volume — the plenum already declares the machine as one, so
  this defect was declarable and undeclared.

---

## A-4 · `rail_descent` passes through all three *real* collar rings

*Elevated to a finding in its own right, and it is not the hull's fault.*

**Physical fact proven.** `RailPath.from_points` builds a Catmull-Rom
(`TENSION = 1.0`, handles `±tangent/3`). The 12 control points all sit at
radius **6.788 m** from the machine axis — 3.8 cm outside the ring's
6.75 m outer radius. The **smoothed curve cuts the corner** and dips to
radius **6.30 m**, which is inside the band. Measured:

| collar | samples inside | deepest penetration | radius range |
| --- | --- | --- | --- |
| `pl_collar_0` | 38 | **0.1663 m** at `(-5.71, 45.16, 7.18)` | 6.30–6.52 m |
| `pl_collar_1` | 38 | **0.1663 m** at `(-2.82, 28.16, 15.71)` | 6.30–6.52 m |
| `pl_collar_2` | 38 | **0.1663 m** at `(5.71, 11.16, 12.82)` | 6.30–6.52 m |

Critically: **76 of 76 penetrating samples per collar are inside the real
ring band (4.00–6.75 m), and 0 are in the invisible fill.** Substituting
the correct 12-wedge decomposition does not remove a single one. This is
authored geometry intersecting authored geometry, and repairing A-1 will
not touch it.

`AffordanceFeatures.RAIL_BEAM_THICKNESS` is 0.35 m, so half-thickness is
0.175 m: the rail's *centreline* enters the ring by 0.1663 m, i.e. the
beam would be very nearly half-buried in each collar.

`MovementPackage._rails` checks `clear` on exactly these smoothed samples
before building. Its verdict on `rail_descent` against real geometry is
**DECLINED**, three times over.

**Actual player-facing impact.** None today (no consumer). On
activation: the plenum's only rail — the offer the whole room exists for,
per its own docstring — is declined, and the room silently loses its
reason to exist. `MovementPackage`'s own header calls this "the worst
version of this failure".

**Why the current gates miss it.** `build_plenum.py` validates the rail
by **arithmetic on control points only** — segment length in
`[0.5, 60.0]` and pitch `≤ 75°` (lines 397–406). It never asks where the
smoothed curve goes, and the smoothing is Production's. `RoomAudit` does
not read offers. `MovementPackage._rails` is exactly the check designed
for this and has no caller. `docs/LARGE_ROOM_MOVEMENT.md:281` already
says *"`MovementPackage` additionally walks the smoothed curve against
room geometry before building it"* — true of the code, false of any run.

**Ownership: shared handoff, Art first.** Art owns the route; the fix is
a route change (or a collar radius change), not an engine change.
Production owns the fact that the only detector never runs.

**Blocks promotion of `shell_plenum_helix`: yes** — the room's primary
declared offer is false against its own geometry.

**Smallest correct follow-up task.**

> Push the four ring control points out from radius 6.788 m to a radius
> at which the *smoothed* curve clears 6.75 m plus half the beam
> thickness, and re-assert. Do not change the collars. One constant in
> `_rail_points`, chosen by measuring the baked curve rather than the
> control polyline.

**Tests the follow-up must leave behind.**

* A test that samples the **baked** curve (not the control polyline) of
  every LARGE shell's `rail_route` against the instantiated colliders and
  asserts `clear` at every sample.
* A **sabotage test** returning the control points to radius 6.788 and
  asserting the rail is declined, naming the collar.
* An art-side build assertion on the baked curve, so the failure lands
  where the geometry is still a local variable.

---

## A-5 · The topology defect does not recur — 3 of 425 collider nodes, all three the plenum's collars

**Physical fact proven.** Every `-convcolonly` node in every authored
shell was tested for convexity directly (for a closed mesh, convex iff
every face plane supports the whole vertex set):

| shell | collider nodes | non-convex |
| --- | --- | --- |
| `shell_corner_left` | 10 | 0 |
| `shell_corner_right` | 10 | 0 |
| `shell_hall_transit` | 71 | 0 |
| **`shell_plenum_helix`** | **117** | **3** — `pl_collar_0/1/2` |
| `shell_span_basin` | 54 | 0 |
| `shell_tower_collapsed` | 21 | 0 |
| `shell_tower_gantry` | 33 | 0 |
| `shell_tower_spiral` | 22 | 0 |
| `shell_treasure_cache` | 16 | 0 |
| `shell_treasure_coffer` | 20 | 0 |
| `shell_treasure_vault` | 12 | 0 |
| `shell_yard_gantry` | 39 | 0 |
| **total** | **425** | **3** |

Corroborated at the source: of the shell builders, only
`build_plenum.py` calls a non-`block` primitive — 7 × `brushkit.block`
and 1 × `brushkit.tube`. `build_hall.py` (14), `build_span.py` (8),
`build_yard.py` (9), `build_shells.py` (19), `build_towers.py` (20),
`build_rooms.py` (32) and `build_paths.py` (10) are blocks only.
`brushkit` offers `wedge`, `prism`, `tube`, `stair`, `sweep` and `grate`,
all of which would import the same way, so the rule matters going
forward even though today the defect is contained.

**The search stops here**, per the brief. The recurrence question is
answered exhaustively for authored shells and no further.

**Ownership: Art. Blocks promotion of other rooms: no.**
**Follow-up:** folded into A-1's repo-wide assertion — no separate task.

---

# QUESTION B — Hall grapple geometry binding

## B-1 · `MovementPackage` has no caller anywhere that has ever been shown real geometry

**Physical fact proven.** `MovementPackage.consume` has **8 call sites in
the whole repository**, all in one test file:

| site | `clear` | `supported` |
| --- | --- | --- |
| `movement_driver.gd:413` | `yes` | `yes` |
| `movement_driver.gd:423` | `anchor_is_solid` | `yes` |
| `movement_driver.gd:436` | `no_swing` | `yes` |
| `movement_driver.gd:447` | `yes` | `no` |
| `movement_driver.gd:837` | `solid_at_60` | `yes` |
| `movement_driver.gd:862` | `solid_at_60` | `yes` |
| `movement_driver.gd:867` | `yes` | `yes` |
| `movement_driver.gd:874` | `yes` | `yes` |

where `yes := func(_at): return true`, `no := func(_at): return false`,
and `solid_at_60 := func(at): return at.x < 50.0`. The string
`PhysicsDirectSpaceState3D` **does not occur in `movement_driver.gd` at
all**. `content_instantiator.gd` mentions `MovementPackage` only in a
comment. So:

* **no call in this repository has ever passed a physics space, a
  collider, or an authored shell to `MovementPackage`;**
* every offer verdict on record was produced by a constant or a
  half-space predicate over bare-box fixtures — which
  `movement_driver.gd`'s own header states plainly: *"NOT AUTHORED
  ROOMS."*

**What physical evidence the passing Hall test actually used: none.**
There is no committed test that runs `MovementPackage` against
`shell_hall_transit`. The certification claim *"All three grapple offers
BUILD through `MovementPackage`"* rests on an uncommitted ad-hoc harness
of the same kind as the "throwaway manifest edit" the same note
describes; the repository contains no artefact of it and it is not
reproducible from any ref. Production's own note is candid about the
underlying gap — *"`MovementPackage` has no production caller and
Production has no canonical `clear`/`supported` implementation — the
rules exist, their binding to real geometry does not"* — and this audit
confirms it exactly.

**Ownership: Production.** **Blocks promotion of any room: no by
itself** — it is the reason the other findings went unseen, not a defect
in a room.

## B-2 · The Hall's three grapple offers are physically true — and pass by exactly 0.000 m

**Physical fact proven.** Against the Hall's real imported collision,
using continuous evidence rather than strides:

| offer | anchor | every surface below | true drop | anchor clear | 4.0 m continuous clear air below | verdict |
| --- | --- | --- | --- | --- | --- | --- |
| `grapple_0` | (0.0, 9.2, 28.8) | `hl_basin` y=0.000 | 9.200 m | yes | yes | **REAL** |
| `grapple_1` | (5.2, 19.2, 34.0) | `hl_basin` y=0.000 | 19.200 m | yes | yes | **REAL** |
| `grapple_2` | (0.0, 27.2, 39.2) | `hl_basin` y=-0.000 | 27.200 m | yes | yes | **REAL** |

So the answer to B-3 as posed is **yes — all three Hall grapple points
are valid against the instantiated Hall's real collision.** Production's
passing claim reached a correct conclusion.

**But the verdict has no margin.** All three anchors sit at
`y ≡ 1.2 (mod 2)` above a floor at `y = 0`, so under the
`_points_have_ground` convention the decisive sample is:

| offer | drop | query height | window | floor top |
| --- | --- | --- | --- | --- |
| `grapple_0` | 8 m | y = 1.20 | **[0.00, 1.50]** | 0.000 — **on the lower limit** |
| `grapple_1` | 18 m | y = 1.20 | **[0.00, 1.50]** | 0.000 — **on the lower limit** |
| `grapple_2` | 26 m | y = 1.20 | **[0.00, 1.50]** | 0.000 — **on the lower limit** |

Clearance: **0.000 m**, three times. Sensitivity, under all three narrow
conventions:

| anchors moved | built / declined |
| --- | --- |
| −0.10, −0.05, −0.01, +0.00 m | 3 / 0 |
| **+0.01 m** | **0 / 3** |
| +0.05, +0.25 m | 0 / 3 |

**A one-centimetre lift declines all three.** The Hall's grapple
certification is a boundary coincidence between an anchor height and a
stride, not a property of the room.

**Ownership: Production.** **Blocks Hall promotion: no** — the offers are
true. But the *evidence* is worth nothing, and this is why B-3 matters.

## B-3 · The 2 m stepping produces **both** false refusal and false acceptance, from **different** causes

**Physical fact proven — false refusal, on real geometry, in an
owner-PASSED room.** `shell_span_basin` declares three grapple anchors at
y = 11.4 over a basin floor at y = 0 — true drop **11.400 m**, well
inside `GRAPPLE_DROP`. `_grapples` samples at drop 4, 6, 8, 10, 12 …, so
query heights are 7.4, 5.4, 3.4, 1.4, −0.6 …. With a 1.5 m window the
sample at y=1.4 sees `[0.20, 1.70]` and the next sees `[−1.80, −0.30]` —
**the floor at 0.000 falls in the gap between them.** Verdict:

| convention | window | span verdict |
| --- | --- | --- |
| `points_have_ground` | 1.5 m | **0 built / 3 declined** |
| `player_stands_here` | 1.6 m | **0 built / 3 declined** |
| `traversal_endpoint` | 1.6 m | **0 built / 3 declined** |
| `traversal_ground` | 2.6 m | 3 built / 0 declined |
| `arrivals_standable` | 4.6 m | 3 built / 0 declined |

Three physically real offers, refused, because `1.5 < 2.0`.

**Census over all four LARGE shells** — 2 268 candidate anchors on a
9 × 7 × 9 grid, the loop's verdict against continuous ground truth
(anchor clear, 4.0 m of *continuous* clear air below, first ground within
30 m):

| convention | window | agree | **false refusal** | **false acceptance** |
| --- | --- | --- | --- | --- |
| `points_have_ground` | 1.5 m | 2 033 | **186** | **49** |
| `traversal_ground` | 2.6 m | 2 218 | **0** | **50** |
| `arrivals_standable` | 4.6 m | 2 187 | **0** | **81** |

**Conclusively both.** And the two have different causes, which is the
part that decides the repair:

* **False refusal is the stride.** Blind bands exist iff
  `window < stride`, each `2.0 − window` wide: 0.5 m (25 % of all floor
  depths) at window 1.5, 0.4 m (20 %) at 1.6, **none** at 2.6 or 4.6.
  Widening the window past 2.0 m eliminates it entirely — 186 → 0.
* **False acceptance is not the stride, and widening the window makes it
  worse** (49 → 50 → 81). Three independent structural causes:
  1. **`clear` is sampled at exactly two points** — `at` and
     `at − UP*4` — so blocked swing space *between* them is invisible.
     Witness: `shell_plenum_helix` at `(-7.067, 26.6, 7.778)`, accepted
     by every convention, ground truth *"swing space blocked"*.
  2. **The window reaches `up` metres above the query point**, so the
     `drop = 4` sample can see ground as shallow as `4.0 − up` — 2.8 m
     for `up = 1.2`, i.e. **less than `SWING_ROOM`**. The loop then
     reports an opportunity whose hang space the contract forbids.
  3. **The window reaches `down` metres below the last query point**, so
     the `drop = 30` sample sees ground as deep as `30 + down` — 34 m for
     `down = 4.0`, i.e. **beyond `GRAPPLE_DROP`**. Witness:
     `shell_hall_transit` at `(-18.311, 33.65, 10.0)`, accepted, ground
     truth *"no ground within 30 m"*.

One further real defect surfaced by the same measurement: of the twelve
declared anchors across the four LARGE shells, **eleven are real and one
is not** — `shell_plenum_helix`'s `grapple_1` at `(7, 38, 10)` sits
**0.762 m** above `pl_run_5_tread3`, so the player's capsule does not fit
at the anchor itself and there is nowhere near `SWING_ROOM` beneath it.
Every convention correctly declines it. `build_plenum.py`'s comment
claims each anchor "sits over a helix run rather than over the floor,
which is what keeps the drop inside `GRAPPLE_DROP`" — it checks the
maximum drop and never the minimum.

**Why the current gates miss all of this.** `RoomAudit` never reads
`offers`; the offer rules live only in `MovementPackage`; and
`MovementPackage` has never been shown a collider (B-1). The rules and
the geometry have never been in the same room.

**Ownership: Production** for the API and the stride/window arithmetic;
**Art** for `grapple_1`'s anchor height.

**Blocks Hall promotion: no. Blocks `shell_plenum_helix`: yes** (via
`grapple_1`, alongside A-2/A-3/A-4).

**The smallest correct production API.** Not a wider window — that trades
186 false refusals for 31 more false acceptances. The stride and the
window are both symptoms of asking a *continuous* question with *point*
samples. The minimum correct surface is **two callables that answer
continuously**, which `_grapples` then needs no stride at all to use:

> ```
> ## The first ground at or below `at`, or -INF. NOT a window.
> static func ground_below(space, at: Vector3, reach: float) -> float
> ## Does the player's capsule fit at `at`?
> static func body_fits(space, at: Vector3) -> bool
> ```
>
> One canonical implementation over a `PhysicsDirectSpaceState3D`, living
> beside `RoomAudit` so the audit and the packages cannot hold two views.
> `_grapples` then reads:
> `drop = at.y - ground_below(space, at, GRAPPLE_DROP + SWING_ROOM)`;
> accept iff `body_fits(at)`, the swing column is **swept** clear over
> the whole `SWING_ROOM`, and `SWING_ROOM <= drop <= GRAPPLE_DROP`. The
> `while drop <= GRAPPLE_DROP: drop += 2.0` loop is deleted, not tuned.

This removes all four error channels at once: no stride, so no blind
band; a swept swing column, so no gap between two samples; a real
distance compared against both bounds, so neither `SWING_ROOM` nor
`GRAPPLE_DROP` can be straddled by a window.

**Ownership of the API: Production**, and `content_instantiator.gd` is
its natural first caller — it already builds the `offers` dictionary and
already has the instantiated root.

**Smallest correct follow-up task.**

> Add `ground_below` and `body_fits` as the canonical real-geometry
> evidence beside `RoomAudit`, replace `_grapples`' stride loop with a
> continuous drop measurement and a swept swing column, and give
> `MovementPackage.consume` one production caller that passes the
> instantiated room's physics space. Do not widen any window.

**The sabotage tests required to prove that binding** — each must fail if
its guard is removed:

1. **Stride sabotage.** Reinstate the `+= 2.0` loop with the 1.5 m window
   and assert `shell_span_basin`'s three anchors are declined. This is
   the false refusal, on real geometry, and it must be a red test rather
   than a paragraph.
2. **Boundary sabotage.** Lift the Hall's three anchors by 0.01 m and
   assert all three still build. Under today's code this flips 3/0 → 0/3;
   under a continuous API it must not move.
3. **Swing-sweep sabotage.** Reduce the swing check to its two endpoints
   and assert the plenum anchor at `(-7.067, 26.6, 7.778)` is then
   wrongly accepted.
4. **`SWING_ROOM` floor sabotage.** Assert `shell_plenum_helix`'s
   `grapple_1` (0.762 m of air) is declined, and that it is declined for
   *insufficient hang space* — not for a buried anchor.
5. **`GRAPPLE_DROP` ceiling sabotage.** Assert an anchor with first
   ground at 31 m is declined; today a 4.0 m window at `drop = 30`
   accepts up to 34 m.
6. **No-space sabotage.** Assert `MovementPackage.consume` refuses, and
   does not silently pass, when handed a detached root with no physics
   space — the same guard `RoomAudit.findings` already carries, for the
   same reason: *"a probe with nowhere to go comes back clean, which is
   the wrong kind of pass."*
7. **Vacuity guard.** Assert the suite both builds and declines at least
   one real-geometry offer, so a binding that silently stops measuring
   cannot read as green.

**Does this block Hall promotion, or only future grapple-package
activation?** **Only future activation, on grapple grounds.** All three
Hall anchors are physically true; nothing a player can do today touches
them; the defect is in the trustworthiness of the evidence, not the room.
But see B-4 — the same missing consumer conceals a Hall defect that
*does* block it.

## B-4 · Bounded recurrence scan — the movement offers declared by the four LARGE shells

Scope, per instruction: the currently declared `rail_route`,
`launch_source`/`launch_target` and `grapple_point` offers in
`shell_hall_transit`, `shell_plenum_helix`, `shell_span_basin` and
`shell_yard_gantry`, and nothing else. Offer blocks are byte-identical
between Production's registry at `f8e09ee` and Art's manifests at
`26a2914`, so this holds for both lanes.

### rail_route — 3 of 4 declined against real geometry

| shell | control point buried | smoothed curve passes through | deepest | verdict |
| --- | --- | --- | --- | --- |
| `shell_hall_transit` | **`#5` (17, 21, 33)**, depth 0.0000 on `hl_east_gantry`'s top face | `hl_east_gantry`, `hl_ramp1_tread3`, `hl_ramp1_tread4` | **0.3894 m** | **DECLINED** |
| `shell_plenum_helix` | none | all three real collar rings (A-4) | 0.1663 m | **DECLINED** |
| `shell_span_basin` | none | `sp_pylon_0`, `sp_pylon_1` | **1.9801 m** | **DECLINED** |
| `shell_yard_gantry` | none | nothing | — | built |

`shell_span_basin`'s `rail_underdeck` drives its centreline **1.98 m
through both bridge pylons** — the most severe of the three by an order
of magnitude, and unambiguous at any convention. `shell_hall_transit`'s
`rail_helix` enters the east gantry by 0.25 m and a ramp tread by
0.3894 m, both beyond the beam's own 0.175 m half-thickness; its control
point `#5` additionally lies exactly on the gantry's walking surface
(depth 0.0000 — a boundary case, and the curve is refused regardless).

### launch pairs — 4 of 4 refused, but only one is a geometry defect

The penetration depth separates two different things, and conflating them
would be the wrong verdict:

| shell | target | inside | **depth** | reading |
| --- | --- | --- | --- | --- |
| `shell_hall_transit` | `launch_gantry` (16, 21, 30) | `hl_east_gantry` | **0.0000 m** | sits exactly on the gantry's top face — a *floor point* |
| `shell_span_basin` | `launch_deck` (0, 14, 63) | `sp_deck` | **0.0000 m** | exactly on the deck's top face — a *floor point* |
| `shell_yard_gantry` | `launch_catwalk` (30, 8, 49.7) | `yd_catwalk_n` | **0.0000 m** | exactly on the catwalk's top face — a *floor point* |
| `shell_plenum_helix` | `launch_collar` (0, 28.3333, 10) | `pl_machine` | **4.0000 m** | **buried in the interior of a solid** |

Three of the four targets are correctly authored landing *surfaces*, and
whether `LaunchSolver` refuses them depends entirely on an unwritten
convention: `launch_solver.gd` documents `clear` as *"does the player's
body fit at this point"*, and a body centred on a floor point never
fits — it needs to be roughly `PLAYER_HEIGHT / 2` higher. **That is a
missing convention, not bad geometry**, and it is the single most likely
way a newly written canonical caller would refuse three good rooms on its
first run. `shell_plenum_helix` alone is a real geometry defect (A-3).

**Ownership.** Per row: `shell_span_basin`'s rail and
`shell_hall_transit`'s rail are **Art** (route changes);
`shell_plenum_helix`'s launch target is **Art** (A-3); the
floor-point-versus-body-point convention is **Production** and must be
settled *before* the first canonical caller lands, or it will manufacture
three false findings.

**Blocks promotion.**

| room | blocked | why |
| --- | --- | --- |
| `shell_plenum_helix` | **yes** | A-2, A-3, A-4, and `grapple_1` |
| `shell_span_basin` | **yes** | `rail_underdeck` 1.98 m through both pylons |
| `shell_hall_transit` | **yes** | `rail_helix` 0.25 m into the east gantry and 0.3894 m into a ramp tread — a real intersection, not a boundary case |
| `shell_yard_gantry` | **no** on offer grounds | rail clean, three anchors real; only the shared floor-point convention touches it |

**Smallest correct follow-up task** (one task, three rooms, no roadmap):

> Settle the `clear`-at-a-landing-surface convention in
> `launch_solver.gd` — state whether a `launch_target` names the floor or
> the body, and lift the probe by `PLAYER_HEIGHT / 2` if it names the
> floor. Then repair the two rail routes that intersect real geometry
> (`shell_span_basin`'s pylon crossings, `shell_hall_transit`'s east
> gantry and ramp clearances). `shell_plenum_helix`'s repairs are A-2 to
> A-4.

**Tests the follow-up must leave behind.**

* One test per LARGE shell asserting every declared offer survives
  `MovementPackage.consume` with the real instantiated space — the same
  test the canonical caller in B-3 makes possible.
* A **sabotage test** per repaired rail: restore the old control points
  and assert the route is declined, naming the collider.
* A test pinning the landing-surface convention explicitly: a
  `launch_target` on a floor face must be accepted, and one 1 m inside a
  slab must be refused. Today these two cases are indistinguishable.

---

# Summary of verdicts

| # | Finding | Owner | Blocks | Room |
| --- | --- | --- | --- | --- |
| A-1 | Collar annuli import as filled convex hulls; +28.800 m³ each, +86.40 m³ total; no player-reachable effect | Art | yes (via A-2) | plenum |
| A-2 | All three optional collar endpoints are impossible destinations; the fill is what makes them measure supported | shared, Art first | **yes** | plenum |
| A-3 | `launch_collar` declared 4.000 m inside the machine; survived the Wave 1 repair | Art | **yes** | plenum |
| A-4 | `rail_descent`'s smoothed curve enters all three **real** collar rings by 0.1663 m | shared, Art first | **yes** | plenum |
| A-5 | No recurrence: 3 of 425 collider nodes non-convex, all three the plenum's collars | Art | no | — |
| B-1 | `MovementPackage` has 8 call sites, all stubs; no physics space anywhere; the Hall grapple pass has no committed evidence | Production | no | — |
| B-2 | The Hall's three anchors are physically real, and pass by exactly 0.000 m; +0.01 m declines all three | Production | no | hall |
| B-3 | The 2 m stride yields **both** errors from different causes: 186 false refusals (stride) and 49–81 false acceptances (two-point `clear`, window over-reach at both ends) | Production; Art for `grapple_1` | yes for plenum | plenum |
| B-4 | 3 of 4 rails and 1 of 4 launch targets fail on real geometry; the other 3 targets are a missing convention, not a defect | per row | yes for span and hall | span, hall |

**Owner-facing bottom line.** Question A's collision-topology defect is
real, exactly quantified, and changes nothing a player can do — but it
is manufacturing the evidence for three false manifest claims, so it
cannot be left in place and it cannot be repaired without A-2 landing in
the same commit. Question B's binding gap is worse than reported: the
Hall's grapple offers are true, but nothing in the repository has ever
measured an offer against a collider, and the 2 m stride is wrong in both
directions rather than one. The bounded scan that gap made necessary
found real intersections in three of the four LARGE shells, and one of
them — the span's rail through both pylons — is the largest single
physical contradiction in the current library.

Nothing in this audit was implemented. No content, review state or room
promotion was touched.
