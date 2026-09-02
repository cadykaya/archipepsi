# LARGE room library — the ten-room slate and the plan

**Phase 1 deliverable. No room is authored yet, and none should be until
this slate is approved.** The point of stopping here is that ten LARGE
rooms is roughly ten times the cost of `shell_hall_transit`, and the
expensive mistake is not a bad room — it is ten rooms that turn out to be
one room with different dressing.

---

## 0. Reconciled against the FINAL walk law (`b37fe07`)

**The Surface-budget conclusion in the first draft of this document was
wrong, and it is retracted.** It was read off the intermediate rule at
`93ddc60`. Production advanced past it, and the final law says the
opposite of what that draft inferred.

### What `b37fe07` actually says

The owner found a real unsoundness in the intermediate rule: it accepted
a walk the moment both endpoints landed on the SAME declared Surface,
and built edges between different Surfaces by comparing declared rects.
Under C(ii) a Surface promises only that a placement can be FOUND
somewhere inside it, so one valid Surface may span a six-metre chasm --
and that chasm was being certified walkable.

> **The declared rectangles bound the search and prove nothing.**

A walk is now proven by a bounded flood over player-radius samples: a
node exists only where the evidence finds support at a walkable height
and the player's body fits, and an edge exists only between neighbours
within one `MAX_VERTICAL_STEP`. A ring, a switchback and a 23 m ramp all
flood. A chasm does not, because no node exists over it.

### The four questions, measured

Art now mirrors that flood source-side in `tools/blender/traversallaw.py`.
It reproduced all three of Production's `shell_hall_transit` findings,
verbatim and by name, before a line of the hall changed -- which is the
only reason anything below is trusted.

**1. Does a ramp need ~1 Surface per metre?** **No.** Production's own
23 m sabotage ramp is declared with **one** Surface. Measured on the
hall: adding a Surface over the west climb's footprint changed the
flood's node count from 2268 to 2268 -- *exactly zero difference*. The
rects bound; they do not prove.

**2. What is the minimum truthful declaration for a large ramp?** One
Surface whose rect covers the flight's plan footprint, and often none at
all -- the decks at either end usually already cover it, and the domain
is grown by `DOMAIN_MARGIN` 1.5 m besides. **But the binding constraint
turned out to be geometric, not declarative.** `ShellValidator` floods
the collision hulls' axis-aligned boxes, and a ramp modelled as ONE
wedge is one box whose top is the high end: the evidence sees a cliff
wherever the ramp is. Measured on the hall before the fix, the box
evidence along the west climb returned 0.00 or 11.00 at every sample and
nothing between. So a climb is built as a chain of wedge sections each
rising no more than `roomkit.FLIGHT_RISE` (0.9 m) -- collinear, faces
meeting, visually the same ramp, and now presenting the intermediate
tops the evidence needs. Production's 23 m proof is thirty stacked slabs
for precisely this reason.

**3. Does the 32-Surface cap materially constrain the slate?** **No.**
Nothing in the library is near it. The hall itself needs 14 surfaces,
not 39. The cap constrains how many distinct *usable regions* a room
declares, which is a design budget rather than a height tax.

**4. Did the intermediate assumption suppress vertical ascent?** **Yes,
and that is now reversed.** The first draft deliberately kept mandatory
climbs small because ascent looked like it cost a Surface per metre.
Ascent is free. Four rooms have had their climbs restored to what their
spatial thesis actually wants -- see the slate below, where the changed
figures are marked.

### What did not change

C(ii) is intact. `gap` and `rise` keep their bounds. Rails are still
sparse authored control points and Production still supplies the smooth
Catmull-Rom spline. `grapple_point` is still a place rather than a
mechanic. The ten concepts and their silhouettes are unchanged.

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
| size | 34 × 52 × 34 · **climb 3 m** (exit is 46 m *below* entry) |
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
| size | 60 × 40 × 60 · **climb 16 m** (restored) |
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
| size | 46 × 56 × 46 · **climb 24 m** (restored) |
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
| size | 26 × 44 × 130 · **climb 20 m** (restored) |
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
| size | 56 × 44 × 56 · **climb 26 m** (restored) |
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

### The surface budget, revisited under the final rule

The first draft's table counted "ramp bands" that do not exist. Under
`b37fe07` a climb costs **zero** intermediate Surfaces, so a room's
surface count is simply its distinct usable regions -- 6 to 17 across the
slate, against a cap of 32. The cap is a design budget for how many
regions a room declares, not a tax on height, and **nothing in the
library is close to it.**

Four rooms have had their climbs restored to what their spatial thesis
wanted before the retracted rule pushed them down: the quarry contours
16 m instead of 6, the lattice climbs 24 instead of 8, the processional
rises 20 over 130 m instead of 12 over 120, and the interchange stacks
26 m of decks instead of 13. The sump also grew, because a pit that
commits you downward is better at 46 m than 40.

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
