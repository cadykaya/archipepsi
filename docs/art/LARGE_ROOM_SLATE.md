# LARGE room library — the ten-room slate and the plan

**Phase 1 deliverable. No room is authored yet, and none should be until
this slate is approved.** The point of stopping here is that ten LARGE
rooms is roughly ten times the cost of `shell_hall_transit`, and the
expensive mistake is not a bad room — it is ten rooms that turn out to be
one room with different dressing.

---

## 0. What changed under us, and what it costs

**Production's walk correction has LANDED**, at `93ddc60` — "A walk is
not a jump, and a rail is not a chain of corners". It is not in motion
any more, so the slate below is designed against the real rule rather
than around a gap.

### `TraversalLaw`, in one paragraph

Each traversal kind is held to what it *claims*. `gap` and `rise` keep
their base-kit bounds unchanged. `drop` is bounded by nothing — falling
is always possible. **`walk` is checked as CONNECTIVITY over the room's
own declared `surfaces`**: each endpoint must land on one, and the two
must be joined by a chain of surfaces that touch in plan (within
`PLAYER_RADIUS * 2` = 0.8 m) and step by no more than
`MAX_VERTICAL_STEP` = 1.0 m. Production's own note records that they
tried a straight-line ground sample first and discarded it for the same
reason Art discarded one at L-88: a ring collar and a chasm crossing are
identical along the chord.

This is the right rule and it is strictly better than what it replaced.

### The arithmetic it implies, measured

A `Surface` is `{name, center, extent(2)}` — **a flat rect at one
height**. There is no slope, and `extent` has no y. So a ramp cannot be
one Surface: `_surface_under` only matches a point within 1.0 m
vertically of the surface's own height.

**A mandatory on-foot climb therefore costs about one declared Surface
per metre of rise.** Against `surfaces` max_length = 32, that makes the
surface cap a *climb budget*.

Measured on the shipped hall:

```
declared surfaces today:            14
  basin_to_gallery       climbs 11.00 m -> 10 intermediate surface(s)
  gallery_to_landing     climbs 10.00 m ->  9 intermediate surface(s)
  gantry_to_exit         climbs  7.00 m ->  6 intermediate surface(s)
intermediate surfaces required:     25
total to satisfy TraversalLaw:      39   (cap is 32)
over cap by:                         7
```

`shell_hall_transit` **cannot be made compliant as designed.** That is a
finding about the hall, not a complaint about the law — and it is the
single most important input to this slate.

### What the slate does about it

**Descent is free. Ascent is not.** So most of these rooms spend their
height on descent, spectacle and *optional* ascent, and keep the
mandatory on-foot climb small. Only two of the ten spend real climb
budget, and both are under 14 m.

That is not a workaround; it is a better spread. The P2 towers are
already the "climb a shaft" room. A library where every LARGE room is
also a climb would be the convergence the brief warns about.

### The one contract question worth asking later

A **slope-aware Surface** (a second height, or a `ramp` kind whose
connectivity is proven by ground continuity along the declared segment
path rather than by a surface chain) would let a room have a 30 m
walkable ascent. Nothing in this slate needs it. **Not requested now** —
raising it before any room needs it would be asking Production to build
for a hypothetical. Recorded so that when a room does need it, the
question already has a shape.

### Also landed, and useful

- **Rails are smooth.** Catmull-Rom with Bezier handles; the curve passes
  through the points an artist drew. **Art must NOT hand-author dense
  points to fake smoothness.** Pitch and envelope containment are
  measured on the *baked* curve, so a route whose control points all sit
  legally can still fail by bowing — the source-side check has to bake
  too.
- **`grapple_point` joined `OFFER_KINDS`** — a place, not a mechanic.
  Validated as: anchor clear, ≥ 4.0 m clear air beneath (`SWING_ROOM`),
  and ground within 30 m below (`GRAPPLE_DROP`). Never built.
- **`_from_authored_scene` now emits `offers`** — the P3.0 seam was
  unconnected on the authored path until this commit, so the hall's three
  offers were being dropped between manifest and composer.
- **The hall stays PENDING with three findings**, all in its declarations
  rather than its geometry. Two are trivial (`gallery_to_landing` and
  `gantry_to_exit` begin 1.0 m past the platforms they leave from, in
  air). The third is the surface chain above.

---

## 1. The slate

Ten rooms. The acceptance test the brief gave — *strip every package,
enemy, Check and decoration; is it still recognisable from silhouette,
circulation and spatial idea?* — is answered in the last column of each
card.

Sizes are W × H × D in metres. `climb` is the mandatory on-foot ascent,
which is what the surface budget buys.

### 1 · `shell_sump_descent` — the pit you go down into

| | |
|---|---|
| size | 34 × 46 × 34 · **climb 3 m** (exit is 40 m *below* entry) |
| type | `arena` |
| landmark | a colossal intake cone at the bottom, mouth 14 m across |
| regions | entry balcony y=40; four terraced ledges spiralling down the walls at 30 / 21 / 12 / 5; the cone floor at 0 |
| circulation | one continuous descending contour around the walls; every ledge overlooks every ledge below it |
| offers | rail descending the full shaft; grapple across the void to side alcoves; launch *up* from the floor to a mid ledge (the way back) |
| packages | descent platforming · boss at the base · Check on the cone · quiet exploration |
| unlike the others | the exit is at the **bottom**. Nothing else in the library asks the player to commit downward. |

### 2 · `shell_span_basin` — a bridge over somewhere you can fall to

| | |
|---|---|
| size | 30 × 22 × 90 · **climb 0 m** (entry and exit both at y=14) |
| type | `arena` |
| landmark | the span itself: one 90 m deck on two pylons |
| regions | the bridge deck y=14; the basin floor y=0, fully walkable end to end; two end ramps joining them; pylon shoulders y=7 |
| circulation | **two parallel routes at two heights** — walk the bridge, or drop and take the basin. Both reach the exit. |
| offers | rail *under* the deck, basin to basin; launch basin → deck; grapple to the pylon shoulders |
| packages | ranged enemies holding the bridge with the basin as flank · a chase · a Check under the span · escort |
| unlike the others | horizontal spectacle. The only room whose mandatory route is dead flat across 90 m. |

### 3 · `shell_crossing_galleries` — two halls that pass through each other

| | |
|---|---|
| size | 70 × 26 × 70 footprint, arms 14 m wide · **climb 0 m** |
| type | `arena` |
| landmark | the crossing itself — a lit void where the upper gallery passes over the lower |
| regions | lower gallery y=0 running N–S; upper gallery y=12 running E–W; the crossing chamber; two dead-end overlooks at the unused arm ends |
| circulation | over **or** under, decided at the entry. The two routes see each other through the crossing and rejoin at the exit. |
| offers | rail along the upper gallery and out over the lower; grapple up through the crossing; launch across the void |
| packages | Portal-like routing puzzle · ambush from the level you did not take · a Check visible from the wrong gallery |
| unlike the others | the plan is a **cross, not a box**. Four long sightlines from one point. |

### 4 · `shell_cavern_stepped` — a quarry, contoured rather than stacked

| | |
|---|---|
| size | 55 × 34 × 55 · **climb 6 m** |
| type | `arena` |
| landmark | a fallen slab bridging two terraces, 22 m long, tilted |
| regions | seven irregular terraces at 0 / 4 / 7 / 11 / 14 / 18 / 22, none rectangular, none concentric; a flooded floor pan |
| circulation | the route **contours around** the cavern rather than climbing it — entry at y=14, exit at y=18 on the far side |
| offers | grapple between terraces; short launches across the pan; a rail down the fall line |
| packages | mixed traversal + combat · a machinery interaction on the slab · miniboss on the pan |
| unlike the others | **no orthogonal core and no symmetry.** The only room whose plan is not built from a grid. |

### 5 · `shell_plenum_helix` — the tall thin one, and the best rail in the library

| | |
|---|---|
| size | 20 × 72 × 20 · **climb 0 m** (entry at the top, exit at the bottom) |
| type | `tower` |
| landmark | a hanging chain of machinery filling the centre, never touching a wall |
| regions | entry platform y=70; a helical ledge descending the wall in one continuous turn-and-a-half; three machine collars at 48 / 30 / 14; exit y=0 |
| circulation | one helix down. The machine occludes the far wall from every point, so the room reveals itself a quarter-turn at a time. |
| offers | **the long rail**: one route, 70 m of descent, spiralling the machine — the "irresistible" rail the brief asks for; grapple across the shaft in any direction; a launch from the floor back up two collars |
| packages | a single long traversal set-piece · a descent under fire · a vertical boss |
| unlike the others | **1 : 3.6 aspect ratio.** The most extreme proportion in the library, and the room the rail package exists for. |

### 6 · `shell_yard_gantry` — wide, low, and about the ground

| | |
|---|---|
| size | 84 × 16 × 52 · **climb 0 m** |
| type | `arena` |
| landmark | a gantry crane spanning the full 84 m width at y=12 |
| regions | the yard floor y=0 with cover clusters; perimeter catwalks y=8; the crane bridge y=12; two loading docks recessed into the walls |
| circulation | flat across the yard, or the catwalk ring above it |
| offers | launches across the yard, the longest pair in the library; grapple to the crane; a short rail along the crane bridge |
| packages | **ranged enemies genuinely controlling territory** · a defend/hold · a crate-and-button puzzle on the floor · vehicle-scale spectacle |
| unlike the others | 84 m wide and 16 m tall — the **inverse proportion** of the plenum. A room about area, not height. |

### 7 · `shell_split_works` — one room divided, watching itself

| | |
|---|---|
| size | 46 × 30 × 62 · **climb 4 m** |
| type | `arena` |
| landmark | the dividing wall — a 2 m thick machine wall, pierced by three tiers of window openings |
| regions | west hall and east hall, each 22 m wide, each with a floor and one gallery; three crossing points (a low door, a mid catwalk, a high gap) |
| circulation | pick a side at the entry; cross where the wall lets you. The exit is on the side you did not start on. |
| offers | launch through a high window; grapple through a window to the other side; a rail on one side only, deliberately asymmetric |
| packages | **Portal-like**: send a cube through a window · a duel across the wall · powered-connection puzzle where the machine wall is the machine |
| unlike the others | it is **two rooms that can see each other and mostly cannot reach each other.** No other room withholds a space in view. |

### 8 · `shell_suspended_lattice` — a hall with no floor plane

| | |
|---|---|
| size | 42 × 44 × 42 · **climb 8 m** |
| type | `arena` |
| landmark | the hanging cluster: eleven platforms on rods from the ceiling, at nine different heights |
| regions | the suspended platforms; three catwalk spurs from the walls; the true floor at y=0, present, walkable and deliberately plain — the recovery space |
| circulation | a specific chain of catwalks and platforms on foot; anything else is an offer |
| offers | **grapple is the room's natural verb** — the densest grapple set in the library; launches between platforms; a rail threading the cluster |
| packages | 3D platforming · a hunt among the platforms · a Zelda-like traversal puzzle where reaching a platform is the puzzle |
| unlike the others | **circulation is fully three-dimensional.** No other room lacks a dominant floor. |

### 9 · `shell_approach_long` — the room you see the end of from the door

| | |
|---|---|
| size | 26 × 40 × 120 · **climb 12 m** |
| type | `arena` |
| landmark | the far portal, elevated and lit, visible from the entry across 120 m |
| regions | a processional floor rising gently along its whole length; flanking colonnade aisles at y=0; a clerestory gallery at y=22 above the aisles |
| circulation | one long gentle ascent, 12 m over 120 m — plus the aisles, which are level and faster but blind |
| offers | a rail the length of the clerestory; launch from the floor to the gallery; grapple to the colonnade capitals |
| packages | a processional set-piece · a gauntlet · a Check at the far end you can see the whole time · a quiet exploration corridor |
| unlike the others | **120 m long.** The one-point-perspective room, and the only one whose whole spatial idea is a single sightline. |

### 10 · `shell_junction_levels` — an interchange, where the room is its circulation

| | |
|---|---|
| size | 52 × 36 × 52 · **climb 13 m** |
| type | `arena` |
| landmark | the tangle itself — four walkway decks crossing at four different angles over one void |
| regions | decks at 0 / 7 / 14 / 21, none parallel to another; a central void they all pass over; four wall landings joining them |
| circulation | **maximum route multiplicity.** Entry on deck 0, exit on deck 21, and at least four distinct ways up. |
| offers | launch between decks; grapple through the void; short rails along two of the decks |
| packages | route-choice combat · a timed run · a door-and-power puzzle where the decks are the wiring · a chase |
| unlike the others | the **only room designed around having many correct answers.** Everything else has a route; this has a graph. |

### The spread, checked

| axis | coverage |
|---|---|
| proportion | tall-narrow (5), wide-low (6), very long (9), cubic (8, 10), cross-plan (3), long-low (2), irregular (4) |
| entry → exit | descends (1, 5), level (2, 3, 6, 7), contours (4), ascends modestly (8, 9, 10) |
| dominant landmark | intake cone · span · crossing void · fallen slab · hanging machine · gantry crane · machine wall · suspended cluster · far portal · the tangle |
| best-served offer | rail (5, 1) · launch (6, 2) · grapple (8, 4) · none-needed (3, 7, 9) |
| gameplay lean | combat territory (6, 2) · puzzle (7, 10, 3) · platforming (8, 1, 5) · spectacle/quiet (9, 4) |

### The surface budget, checked before anything is built

Platform counts are estimates read off each room's region list, so this
is a sanity check rather than a measurement — `T4` re-runs it per room
from the real build. The point is that no room in the slate is designed
into the wall the hall walked into.

| room | climb (m) | platforms | ramp bands | total | cap |
|---|---|---|---|---|---|
| `sump_descent` | 3 | 6 | 2 | **8** | 32 |
| `span_basin` | 0 | 8 | 0 | **8** | 32 |
| `crossing_galleries` | 0 | 9 | 0 | **9** | 32 |
| `cavern_stepped` | 6 | 10 | 5 | **15** | 32 |
| `plenum_helix` | 0 | 7 | 0 | **7** | 32 |
| `yard_gantry` | 0 | 11 | 0 | **11** | 32 |
| `split_works` | 4 | 12 | 3 | **15** | 32 |
| `suspended_lattice` | 8 | 17 | 7 | **24** | 32 |
| `approach_long` | 12 | 9 | 11 | **20** | 32 |
| `junction_levels` | 13 | 12 | 12 | **24** | 32 |

Worst case 24 of 32. The hall, by the same arithmetic, needs 39.

**None of them is "big rectangular hall + central tower + rail around
tower."** The closest is 5, and it differs by being a pure descent at a
1 : 3.6 aspect with the machine hung rather than founded.

---

## 2. Shared tooling — build once, not ten times

Everything below already exists in some form inside `build_hall.py` and
would otherwise be copy-pasted ten times.

| # | piece | why once |
|---|---|---|
| **T1** | **`roomkit.py`** — `_y`, `_slab`, `_ramp`, `_terrace`, the stones/heights/names bookkeeping, envelope and axis-order asserts, lifted out of `build_hall.py` verbatim | Ten rooms sharing one `_slab` means one place where the Godot axis swap is right |
| **T2** | **`walkchain`** — given a ramp or stair, emit the banded `Surface` chain at ≤ `MAX_VERTICAL_STEP` and **assert the bands satisfy `_surfaces_touch`** | This is the highest-value piece. The new law is mechanical; hand-counting bands across ten rooms is how a room ships broken |
| **T3** | **`traversallaw.py`** — a source-side mirror of Production's connectivity BFS, run as a build gate | Same move as `roomcollision.measure_stances` mirroring `Placement.find`. **This is the check that would have caught all three of the hall's findings before handoff.** Mirror first, reproduce the known-bad hall, *then* trust it |
| **T4** | **`budget`** — assert surfaces / traversal / offers ≤ 32 and print the climb cost | The hall went 7 over without anybody noticing until Production measured it |
| **T5** | **`railkit`** — sparse control points plus a source-side **Catmull-Rom bake** checking pitch and envelope containment on the *curve* | Production now measures the baked curve. A source check on control points alone would pass routes that bow outside the room |
| **T6** | **`review.py`** — generalise `gen_p3_owner_review.py` + `build_hall_overlay.py` to take a room id and emit the eight views and the overlays | A review package per room, one command, or ten packages get authored by hand and drift |

T2 and T3 are the two that are genuinely new. T1, T4, T5, T6 are
extractions.

---

## 3. Plan

| phase | work | gate |
|---|---|---|
| **A** | *this document* | **owner approves or redirects the slate** |
| **B** | Fix `shell_hall_transit`'s three findings. Two are trivial endpoint corrections. The third needs the route re-cut so the mandatory climb fits the surface budget — the hall is the reference room and it currently fails the gate | hall passes `TraversalLaw` on both evidences |
| **C** | Build T1–T6 against the fixed hall as the test case, and re-verify the eight P2 shells are untouched | tooling reproduces the hall's known-bad state before the fix, and its clean state after |
| **D** | Rooms in **waves of three** — a first wave of 3, reviewed, then 4, then 3 | owner review between waves, so a wrong direction costs three rooms and not ten |

**Wave order, chosen so the riskiest questions are answered first:**

1. **Wave 1 — `shell_plenum_helix`, `shell_yard_gantry`, `shell_span_basin`.**
   The two extreme proportions and the flat one. If LARGE only works at
   hall-ish proportions, this wave finds out at a cost of three rooms.
   It also delivers the long-rail room first, which is the thing the
   brief most wants to see.
2. **Wave 2 — `shell_sump_descent`, `shell_crossing_galleries`,
   `shell_suspended_lattice`, `shell_split_works`.** The four with the
   most unusual circulation topologies.
3. **Wave 3 — `shell_cavern_stepped`, `shell_approach_long`,
   `shell_junction_levels`.** The two that spend real climb budget, plus
   the non-orthogonal one — all three benefit from T2 being proven.

---

## 4. Open questions for the owner

1. **Ten is a ceiling, not a quota?** The brief says ten rooms and also
   "the goal is not 20 more assets". If wave 2 shows eight strong rooms
   and two weak ideas, Art's default will be to ship eight and say which
   two were dropped and why, rather than fill the number.
2. **Chamber type.** `zone.py` has `corridor`, `arena`, `tower`,
   `treasure_room`. Nine of these are `arena` and one (`plenum`) is
   `tower`. A tag no selector can ask for is a shell that never ships —
   that is what happened to `corner`. If Production wants a fifth type
   for LARGE spaces, now is the moment, not after ten shells carry the
   wrong one.
3. **Themes.** All ten are drafted in `concrete_facility`, like the hall.
   Six approved theme families exist. Re-skinning is cheap; deciding
   *which* rooms are which theme is a design call and is the owner's.
