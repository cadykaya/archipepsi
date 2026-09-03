# Physical-truth repair — plenum, hall, span

**Art lane · branch `claude/archipepsi-art` · 2026-09-03**

| | |
| --- | --- |
| Art head before | `accdd2e` |
| Rooms repaired | `shell_plenum_helix`, `shell_hall_transit`, `shell_span_basin` |
| Rooms deliberately untouched | `shell_yard_gantry`, all eight P2 shells |
| Review states | all four Wave 1 rooms remain `review: "pending"` |
| Owner rulings applied | the launch-target ruling; the authored-entry ruling |

---

## What this was

Vera's audit measured a set of declared movement offers against the
collision the rooms actually ship, and found that several of them are
promises the geometry cannot keep: a rail riding inside a pylon, three
collar bands with the ride inside them, a launch target four metres
inside a machine, a grapple anchor with less than a metre of air beneath
it. Seven repairs, plus an art-side proof that the repairs are real and
that the check which found them can fail.

**Every number below was measured first, then repaired.** The art-side
mirror (`tools/content/measure_offers.py`) had to reproduce all of
Vera's findings — same colliders, same values — before a line of any
builder changed. That is the only reason it is trusted enough to be a
gate now.

---

## The seven repairs

### A-1 · The collars were rings in the art and discs in the engine

A `-convcolonly` node imports as a `ConvexPolygonShape3D`, and that shape
is **the convex hull of the node's vertices**. Each plenum collar is a
twelve-sided annulus from the machine's face at 4.00 m out to 6.75, with
an open middle. Its convex hull is a solid disc. So the hole the art
draws was filled, edge to edge, in every build.

Each collar is now **twelve convex trapezoidal prisms** sharing the
tube's own angles, and `roomcollision.assert_convex` refuses any collider
whose own mesh has a vertex outside one of its own face planes — for
every shell in the pack, at build time, from now on.

| | before | after |
| --- | --- | --- |
| plenum colliders | 117 | **150** |
| plenum triangles | 1656 | **1656** |
| plenum size | 21.20 × 20.00 × 73.60 m | **unchanged** |
| non-convex colliders, whole pack | 3 | **0** |

`_assert_annulus_pieces` proves the twelve pieces reassemble the ring
they replaced — same bounding box, same total volume to 1 mm³ — so the
decomposition cannot quietly become a different shape.

**Nothing visible changed.** The collar mesh is the same tube; only the
collision derived from it is now twelve pieces instead of one.

### A-2 · Every collar destination was the machine's axis

Eight declarations named a collar and carried the centre of the ring —
which is the centre of eight metres of hanging steel. They are all on the
band now, at `REWARD_RADIUS` 5.25, through one function.

| what | was | now |
| --- | --- | --- |
| `landing_4_to_collar_0` end | axis | the band, bridge side |
| `landing_7_to_collar_1` end | axis | the band, bridge side |
| `landing_10_to_collar_2` end | axis | the band, bridge side |
| `enemy_anchors` ×3 | `0, y, 10` | `0, 45.33, 15.25` · `5.25, 28.33, 10` · `−5.25, 11.33, 10` |
| `check_anchor` | `0, 28.33, 10` | `−5.25, 28.33, 10` |
| `launch_collar` | `0, 28.33, 10` | see A-3 |

A-1 and A-2 are **one commit**, as required: the decomposition opens a
real hole through each collar, so shipping it while leaving a
declaration on the axis would turn "inside a filled hull" into "in mid
air over a hole".

`check_anchor` was not a reported finding — nothing measures it — and it
is moved anyway, for that reason. It sits on the bridge side; the reward
is opposite, so the objective is the walk around the ring.

**One duplication removed.** `_build` chose the bridge's axis with
`abs(cx) > abs(cz - D/2)` and `_collar_point` chose the declared point's
axis with a second character-identical copy of the same expression. They
agreed only because the copies matched — the exact shape of L-97. There
is one `_collar_axis` now, and both read it.

It is worth knowing what that function decides: the landings sit on the
diagonal, so `abs(cx)` and `abs(cz − D/2)` are **both 7.9**, and what
actually breaks the tie is that `D − WALL − LAND/2` lands one ulp under
`IN − LAND/2`. Left exactly as it was — the bridges built from it are
what the owner reviewed — but named, so the next reader learns it from a
comment instead of from a manifest that moved.

### A-3 · The launch: the target was fixed, and the flight still was not

Moving `launch_collar` onto the band made it a real landing surface. The
arc was still impossible: to reach the middle collar at 28.333 m from the
floor, a body has to pass the low collar's ring on the way up, and there
is no floor it can leave from that misses it.

Measured across the whole floor — **4537 stances on a 0.25 m grid**, each
one a place a standing body actually fits, against all four band points
of each collar:

| collar | height | clear stances |
| --- | --- | --- |
| `collar_0` | 45.333 | **0 of 4537**, on any point |
| `collar_1` | 28.333 | **5**, all in one 0.2 × 0.5 m pocket in the SW corner — and none of them on the point this room's bridge axis declares |
| `collar_2` | 11.333 | **141** on the declared point, in a 1.0 m clear disc |

A launch that works from five square decimetres of a 400 m² floor is not
an offer. **So the launch serves the low collar now.** That is a change
to the room and not to a number, and it is the one design decision in
this repair:

* the low collar is the first thing above the floor, and its bridge puts
  you straight back on the helix;
* the room's own stated reason for having a floor pad — *"the walk back
  is a choice rather than a punishment"* — is served by the first landing
  back, not by the middle of a 72 m shaft;
* **the reward stays on the middle collar**, so the objective is still
  something you climb to.

The pad moved too, and became truthful while it was moving: it was at
`(0, 0.5, 6)` — half a metre of nothing under the player, neither a
stance nor a surface. It is now at `(−6.5, 0.0, 2.0)`, foot on the floor
like the hall's, on the bottom landing where the helix ends.

| | was | now |
| --- | --- | --- |
| `launch_floor` | `0.0, 0.5, 6.0` | `−6.5, 0.0, 2.0` |
| `launch_collar` | `0.0, 28.333, 10.0` (axis) | `−5.25, 11.333, 10.0` (band) |
| span | 28.12 m | 13.93 m |
| solved arc | obstructed 17 % along | **clear, apex 14.8 m, 1.65 s** |

### A-4 · The plenum rail: legal points, an illegal ride

All twelve control points sat at radius 6.788 — 3.8 cm **outside** the
rings' 6.75 — and the ride measured **0.1668 m inside all three**,
because a Catmull-Rom cuts its corners and the curve sags to 6.30 between
its points. The builder checked segment length and pitch on the polyline;
neither is a property the curve has.

One uniform ring cannot satisfy both ends of this shaft. The collars need
the sag pushed past 7.075; the stair runs come inward to 6.452, so a
uniformly wider helix trades three ring strikes for four tread strikes.
Measured, not guessed — every uniform radius was tried and refused. Only
the six points that **bracket a collar** are pushed out (`RAIL_NEAR` 4.8,
`RAIL_WIDE` 5.8); the rest keep the route the owner passed.

Rail length 129.41 → 140.18 m. **Clear.**

### B-3 · `grapple_1` had 0.76 m of air under it

The anchor at `x = 7` hung 0.762 m over `pl_run_5_tread3` — the body did
not fit at the anchor and there was nowhere near `SWING_ROOM` beneath it.
The module's own comment claimed each anchor "sits over a helix run …
which keeps the drop inside `GRAPPLE_DROP`", and it checked the *maximum*
drop and never the minimum.

A metre inward clears the run. `7.0 → 6.0`, drop **0.76 → 9.67 m**. The
other two are 16.76 m and 7.43 m and were left alone.

### 6 · The hall rail ran through the gantry and through a ramp

Two conflicts, both invisible to a polyline check:

| collider | the ride was |
| --- | --- |
| `hl_east_gantry` | 0.249 m **inside** the walkway deck |
| `hl_ramp1_tread4` | 0.389 m **inside** the west flight |
| `hl_ramp1_tread3` | 0.105 m inside |
| `hl_ramp1_tread5` | 0.059 m clear, against a beam that needs 0.325 |

The hall has a **deck level**: at y = 20.3–21 the plan is nearly floored
— the ring, both bridges, the north landing, and the east gantry from
x 13 to 19, with ramp3 carrying on above it from 21 to 28. A rail
climbing from 2 m to 31.5 has to cross that level exactly once, and the
old route crossed it standing on the gantry.

The route now threads the one real gap — **(10, 45)**: east of the ring,
west of the gantry, south of the north landing, under ramp3's third
tread. It arrives there already at 22 m, so the whole eastern sweep is a
**flyover** of the east gantry rather than a pass through it: the walkway
goes by two metres beneath the ride. The western leg came in from x −15
and −17 to −11.5, the middle of the 3.4 m corridor between ramp1 and the
ring.

Two control points changed plan position, two changed height, and the
route's shape — two laps around the armature, entry level to the exit —
is the same. Rail length 143.93 → 143.22 m. Tightest point on the new
ride: **0.494 m** from `ramp3_tread1`, against 0.325 needed.

### 7 · The span rail ran down the middle of both pylons

At x = 0 the ride was **1.9911 m inside** each pylon — 4 m square, floor
to deck soffit, with no vertical gap to pass through. The fix could only
be lateral, and 3.1 is where the deck's own east stringer is: the beam
rides *under structure* instead of *through it*, still wholly beneath a
7 m deck, clearing each pylon by **1.100 m**.

A constant offset on purpose. Give the control points different x and the
Catmull-Rom overshoots sideways between them, and that overshoot is what
put the beam past the deck edge in the versions that wove around the
pylons.

---

## Two findings raised and NOT repaired — these need the owner

The measurement found two more, in rooms whose form has passed review.
Neither is in Vera's audit and neither is one of the seven items.

| room | offer | what happens |
| --- | --- | --- |
| `shell_hall_transit` | `launch_basin` → `launch_gantry` | the flight clips `hl_east_gantry` at `(13.50, 18.78, 22.50)` |
| `shell_span_basin` | `launch_basin` → `launch_deck` | the flight clips `sp_deck` at `(0.00, 11.38, 49.95)` |

Both are the same shape, and both are **0.08 m**: the arc grazes the
underside of the very platform it is aiming for, one sample before it
clears the edge. The hall's pad sits under the east gantry's west edge;
the span's sits directly under a 7 m deck and the target is that deck's
top face.

**They are not repaired because repairing either means moving a launch
pad in a room the owner has passed** — and for the span, moving the pad
out from under the deck changes how the basin gets back up, which is a
route decision rather than an art one. Raised for a ruling.

They are **not** silenced. `measure_offers.RAISED` carries them by
collider name, and the gate fails if either finding changes, if either
comes back clean, or if either offer is renamed away. The only state that
passes is the state that was raised.

---

## The art-side proof

Three new files, all wired in:

| file | what it does |
| --- | --- |
| `tools/content/measure_offers.py` | measures every declared rail, launch and grapple in the pack against the shipped collider triangles |
| `tools/content/replay_audited.py` | replays the pre-repair pack out of git and **fails unless every audited finding still comes back** |
| `tools/content/sabotage_offers.py` | fifteen negative controls over both of the above |

`measure_offers` mirrors Production's rules and reads Production's own
constants out of its source rather than retyping them: `RailPath`'s
`TENSION` and `BAKE_INTERVAL`, `LaunchSolver`'s `APEX_CLEARANCE`,
`ARC_SAMPLES`, `MAX_RANGE`, `GRAVITY`, and the player capsule. Three
things it does that no earlier check did:

* **rails are measured on the baked curve**, swept an order finer than
  `BAKE_INTERVAL`, because every rail in this repair had legal control
  points and an illegal ride;
* **launch arcs are measured as the foot's path**, per the owner's
  ruling, so a target sitting on a floor face reads as the landing
  surface it is rather than as a buried point — three of the pack's four
  targets are at depth exactly 0.0000 m, and a body-centre reading would
  have refused all three good rooms on its first run;
* **`Hull` is only ever used on convex colliders**, because a collider's
  own face planes describe the shape Godot ships only when the mesh is
  already its own hull. That is why `assert_convex` had to come first.

Where the mirror could differ from the authority it is conservative in
the safe direction: outside a hull, `depth` returns the largest plane
distance, which is a lower bound on the true distance — so a clearance it
reports is a clearance the geometry really has.

**The replay is the part that makes the gate mean something.** A gate
that has only ever seen art that passes it has not been shown to do
anything, and breaking a number by hand only proves it reacts to
*something*. So `replay_audited.py` reads the shells and manifests out of
git at `accdd2e` — unmodified — and requires **twelve audited findings**
to come back by collider name and to the centimetre.

It comes in two parts, because one of the audited colliders cannot be
measured at all: the old collars are annuli, and an annulus's face planes
describe its hole rather than its ring. Pretending otherwise would be the
same mistake in a test that the repair took out of the art. So the
plenum's rail is replayed as the *audited points against today's convex
sectors*, which is how the 0.1668 m was reproduced in the first place and
is a fact about the route rather than about the old hull.

### The fifteen negative controls

```
sabotage-offers: the gate, against the declarations it replaced
  hall rail through the gantry and ramp1                 caught
  span rail through both pylons                          caught
  plenum rail, launch and grapple as audited             caught
  all three rooms at once                                caught

sabotage-offers: today's pack is not accidentally passing
  the whole shipped pack                                 clean

sabotage-offers: the raised ledger cannot rot
  an emptied ledger stops excusing anything              caught
  a ledger entry blaming the wrong collider              caught
  a ledger entry for an offer that is fine               caught
  a ledger entry whose offer no longer exists            caught

sabotage-offers: the replay of the audited pack
  the audited pack, unmodified                           clean
  a rail gap off by 5 cm                                 caught
  the plenum sag off by a third of a metre               caught
  the old collars called convex                          caught
  an audited finding left off the list                   caught
  the audited grapple given today's drop                 caught

sabotage-offers: PASS -- all 15 cases behaved
```

Every case substitutes its bug **in memory**. The rest of
`sabotage_checks.sh` edits the working tree and restores it with
`git checkout`, which is right for a guard that reads a source file and
wrong for these two — the declarations under test live in the pack's
generated manifests, and a script that checks out a manifest can eat an
export somebody has not committed yet.

---

## One more defect, found while rebuilding

`build_plenum.py` wrote `{cid: entry}` over the **whole** batch040
manifest, while `build_yard.py` and `build_span.py` read it first and
merged. Building the plenum on its own therefore deleted the yard and the
span from the pack — which is exactly what happened during this repair.
It had never shown up because `check_art_current.sh` happens to run the
plenum before both of them.

A generated artefact whose contents depend on the order its generators
ran in is not regenerable. It merges now, like its two siblings.

---

## Verification

```
[offer] shell_hall_transit   71 colliders, 0 non-convex
    rail_helix       ok       baked curve clears everything
    launch_basin     RAISED   apex 24.5 m, flight 1.97 s
    grapple_0/1/2    ok       ground 9.20 / 19.20 / 27.20 m below
[offer] shell_plenum_helix  150 colliders, 0 non-convex
    rail_descent     ok       baked curve clears everything
    launch_floor     ok       apex 14.8 m, flight 1.65 s
    grapple_0/1/2    ok       ground 16.76 / 9.67 / 7.43 m below
[offer] shell_span_basin     54 colliders, 0 non-convex
    rail_underdeck   ok       baked curve clears everything
    launch_basin     RAISED   apex 17.5 m, flight 1.73 s
    grapple_0/1/2    ok       ground 11.40 m below
[offer] shell_yard_gantry    39 colliders, 0 non-convex
    rail_crane       ok       launch_west ok       grapples ok
```

24 offers measured, 0 refused, 2 raised.

---

## What did not change

| | plenum | hall | span | yard |
| --- | --- | --- | --- | --- |
| triangles | 1656 | 924 | 672 | 516 |
| visible geometry | unchanged | unchanged | unchanged | untouched |
| entry / exit / connectors | unchanged | unchanged | unchanged | untouched |
| surfaces, sockets, volumes | unchanged | unchanged | unchanged | untouched |

The plenum's top-entry/bottom-exit shaft, the span's one-way mid-span
drop, the yard's ~16 m height and the hall's mandatory route and owner
form are all exactly as approved. **The yard was not touched at all** —
Vera found its rail and grapples physically truthful, and nothing here
disagrees.

No shell `.glb` changed except the plenum's, and that one changed only
in its collision node count. Nothing was promoted; all four Wave 1 rooms
remain `review: "pending"`.

---

## Standing state

* **Wave 2 has not started** and is not authorised by this repair.
* The approved P2 catalogue, the played Zone and the digest are unchanged.
* Lesson recorded as **L-98** in `docs/art/ART_LESSONS.md`.
* **Waiting on the owner:** the two raised launch arcs above.
