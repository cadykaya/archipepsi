# Wave 1 — three LARGE rooms, three proportions

> **Re-rendered at `67add07`.** The shared `roomkit.flight` helper was
> repaired — sloped wedges that sawtoothed underfoot became flat treads —
> and all three of these rooms build their climbs with it, so every view
> here and every phone sheet was regenerated against the new geometry
> rather than left stale. The rooms themselves are otherwise unchanged
> and all three remain `review: "pending"`. Triangle counts moved:
> plenum 1320 → 1656, yard 444 → 516, span 544 → 672, which is the cost
> of boxes over wedges. See `docs/art/review/hall_67add07/` and L-95.
>
> Sheets are rebuilt by `bash tools/shots/make_sheets.sh`.

**All three are `review: "pending"`.** Art does not write `pass`.
`verify_pack.gd` asserts the pack does *not* ship them, which is the same
gate the projectile visuals prove in the other direction.

Wave 1 exists to answer one question before seven more rooms are built:
**does LARGE work at proportions other than the hall's?** So the three
were chosen to be as unlike each other as the slate allows — a 1 : 3.6
shaft, an 84 m wide field, and a 90 m span — rather than to be the three
best ideas.

| | `shell_plenum_helix` | `shell_yard_gantry` | `shell_span_basin` |
|---|---|---|---|
| interior W×H×D | **20 × 72 × 20** | **84 × 16 × 52** | **30 × 22 × 90** |
| proportion | 1 : 3.6 tall | 5.3 : 1 wide | 3 : 1 long |
| chamber type | `tower` | `arena` | `arena` |
| triangles | 1,320 | 444 | 544 |
| colliders | 117 | 39 | 54 |
| surfaces / traversal / sockets / volumes | 20 / 15 / 9 / 3 | 6 / 5 / 11 / 3 | 6 / 5 / 10 / 3 |
| rail | **129.4 m**, 13 points, 3 turns | 72.0 m along the crane | 82.9 m under the deck |
| launch | 28.1 m, floor → collar | **63.1 m**, floor → catwalk | 22.5 m, basin → deck |
| grapple points | 3 | 3 | 3 |
| mandatory climb | 0 m (descends 68) | 0 m | 0 m |

Twelve views in this folder: four per room — entry read, the landmark,
the topology, and the local space most easily missed.

---

## `shell_plenum_helix` — the tall thin one, and the long rail

**A1** entry · **A2** the full 72 m from the floor · **A3** mid-helix ·
**A4** a collar

The owner's strongest standing want is *huge vertical space with a long
smooth spline rail through open air*, and this room is built for it. The
rail is **129 m of continuous descent** spiralling a hanging machine —
three and a half times the hall's, and the only one in the library long
enough that riding it is an event rather than a shortcut.

**Entry at the top, exit at the bottom.** The first decision is made at
the door: the floor is 68 m below and you are going down. The walk is
twelve runs of stair around the wall; the rail is one ride. Nothing else
in the slate opens that way.

**The machine hangs and never lands** — 8 m square, roof to 12 m up,
touching nothing. A founded core would cut the floor into corridors, and
this room needs its floor whole, because the floor is where a missed
rail puts you. Three collars ring it at 46.7 / 29.2 / 11.7 m, each
reached by a bridge from the helix: the only places to stand that are not
the wall, and the only places the machine can be touched.

**Recovery.** One continuous slab under the whole shaft, and a launch pad
on it aimed at the middle collar, so the way back up is a choice rather
than the stairs again.

## `shell_yard_gantry` — wide, low, and about the ground

**B1** entry across 84 m · **B2** from the crane bridge · **B3** the
catwalk · **B4** from cover, looking back

The deliberate inverse of the plenum, and the room that exists because a
library of tall spaces cannot hold a firefight. 84 m of open floor, four
cover clusters, a continuous catwalk ring at 8 m and a crane bridge at
12 that spans the full width and tells the player how wide the room is
before they have crossed any of it.

**The mandatory route is dead flat.** Every metre of height here is
optional — the catwalk is reached by two stair flights in opposite
corners, so climbing is never the shortest way anywhere. That is the
condition the offers are allowed to exist under, and this is the room
where it is most obviously true.

**The longest launch in the library**, 63.1 m floor to far catwalk,
because this is the only room wide enough to hold one.

**Machinery later.** Two loading docks are recessed into the north wall
and the crane passes over them. A carryable cube, a weighted button, a
powered door, a conduit run along the catwalk — this floor is open enough
to take a puzzle without the puzzle fighting the architecture. **None is
built.**

## `shell_span_basin` — a bridge over somewhere you can fall to

**C1** the deck, 90 m of it · **C2** from the basin, under the deck ·
**C3** both routes at once · **C4** looking back up

One 90 m deck on two pylons, with a whole second room underneath it.
Entry and exit are both on the bridge at 14 m, so the mandatory route is
level end to end — but the basin runs the full length too, has a flight
at each end, and also arrives. **The player picks a height and neither
choice is the detour.**

Above: exposed for 90 m with only two pylons to break line of sight.
Below: covered, slower, blind at the far end. Ranged enemies on the
bridge make the basin the flank; ranged enemies in the basin make the
bridge a gauntlet. **Neither is placed.**

**The deck has no railing on purpose.** A fall from 14 m lands on the
basin floor, which is continuous under the entire span and has its own
way back up at both ends — so falling off puts the player on the other
route rather than at a reload. That is what recovery geography has to
mean before any movement offer is allowed to be interesting.

**The rail is slung under the deck**, basin to basin at about 9 m: a
third height and a third route, and the room's best line is one you only
find by leaving the obvious one.

---

## Physical results

Every room passes the same gates the P2 library does, plus the new one.

| check | result |
|---|---|
| `traversallaw.assert_declared` (build gate) | **every mandatory `walk` proven** by the flood over collision hulls — 12 runs in the plenum, 2 in the yard, 2 in the span |
| `roomcollision.assert_standable` | every declared Surface offers a findable placement |
| `roomcollision.assert_exact` / `assert_supports` | collider set matches the solid parts; no Surface claims a floor that is not there |
| pack stage 1 — `schemas/content.py` | **PASS**, 21 entries |
| pack stage 2 — `content_registry.gd` | **PASS**, all three held PENDING |
| pack stage 3 — `verify_collision.gd` | **12 shells, 0 needing attention** |
| `preflight_shells.py` | 0 structural refusals |
| rail bounds | every segment 0.5–60 m, no pitch past 75° — asserted in each build |
| launch bounds | 22.5 / 63.1 / 28.1 m, all inside `LaunchSolver`'s 0.5–80; every target radius 3.5 over the 2.5 minimum |
| `grapple_point` | 3 per room, each with ≥4 m of air beneath and ground within 30 m below |

## What Wave 1 tells Waves 2 and 3

1. **LARGE is not a height.** The yard is 16 m tall and 84 wide and reads
   as large; the plenum is 20 wide and 72 tall and reads as large. The
   metre threshold the first slate draft nearly invented would have
   excluded one of them.
2. **A climb costs nothing to declare and a lot to model.** Under
   `b37fe07` a ramp needs no Surfaces — but it does need collision the
   import-time flood can see, which is why every climb here is a chain of
   ≤0.9 m sections. `roomkit.flight` makes that free; Waves 2 and 3
   should never hand-build a ramp.
3. **Declare a long route as several short walks.** The plenum's descent
   is twelve segments, not one. The flood fails closed at 8,000 samples,
   and one 170 m segment would ask it to prove a whole helix in a single
   search.
4. **A ring is not a rect.** The collars are twelve-gons; a Surface
   declared to their circumradius hangs off the flats. Declare the
   inscribed band.

## Rebuild

```sh
.tools/blender/blender -b --python tools/blender/build_plenum.py
.tools/blender/blender -b --python tools/blender/build_yard.py
.tools/blender/blender -b --python tools/blender/build_span.py
python3 tools/shots/gen_wave1_review.py
tools/shoot.sh tools/shots/wave1_review.json docs/art/review/wave1
```
