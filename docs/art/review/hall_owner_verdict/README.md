# `shell_hall_transit` — the owner's two changes

**Owner verdict on the library review: HALL FORM PASS WITH TWO CHANGES.**
Production certified the repaired geometry first — authored path
confirmed, structural 0, measured 0, mandatory circulation clean. Both
changes are **declarations**, not geometry.

The shell still exports `review: "pending"` until Production recertifies
the changed contract. Nothing here promotes it.

---

## Only two images, and that is the point

`shell_hall_transit.glb` came out of the build **byte-identical**. An
offer reserves a place and a traversal segment describes a way through;
neither models anything. So sixteen of the package's eighteen images are
the same pictures they were, and re-rendering them beside two changed
ones would only make it harder to see which two moved.

`docs/art/review/hall_67add07/` keeps the versions the owner actually
reviewed, and remains the reference for every unchanged view.

| | |
| --- | --- |
| `O2_route` | gains the optional segment that closes the collar |
| `O5_overhead` | gains the three anchors, on the rings it already marked |

---

## 1. Three grapple points

| | position | hangs from | ground below |
| --- | --- | --- | --- |
| `grapple_0` | `0.0, 9.2, 28.8` | low ring, underside 9.2 | **9.2 m** (basin) |
| `grapple_1` | `5.2, 19.2, 34.0` | walkable collar, underside 19.2 | **19.2 m** (basin) |
| `grapple_2` | `0.0, 27.2, 39.2` | high ring, underside 27.2 | **27.2 m** (basin) |

Each is radius 1.5, level with one ring's underside and 0.8 m into the
shaft opening, so the three make a ladder up the landmark with the basin
under all of them. `SWING_ROOM` is 4.0 m and `GRAPPLE_DROP` is 30 m; the
deepest of these is 27.2, inside it.

**They moved once, and the reason is worth keeping.** They were first
placed 0.5 m *inside* each band's footprint — legal, and invisible. An
anchor tucked under a solid band is hidden by that band from every angle
except directly beneath it, which a review camera made obvious
immediately. A grapple point the player cannot see is not an
opportunity. At the lip they read from the basin floor, from the
walkable collar, and from across the shaft — which is what `O5_overhead`
now shows.

**The walking route does not depend on them.** All nine mandatory
segments are still `walk`, door to exit, with no package installed.

## 2. The collar loop closes

`ring_s_to_ring_e`, optional, `walk`, from **`5.0, 21.0, 27.0`** to
**`7.5, 21.0, 29.0`**.

The walkable ring was declared as a **C**: north to east one way, north
to west to south the other, and the south band a dead end you had to
double back out of. The **band was never a C** — the east band spans
z 25–43 and so already covered the south-east corner. Closing the loop
therefore needed **no geometry at all**, only the declaration that was
missing, and it is proved by the same physical flood as every other
`walk`. It mirrors `ring_w_to_ring_s` in x.

You can now circle the landmark. That is worth most in a fight around a
thing that breaks line of sight.

---

## The contract now

| | before | after |
| --- | --- | --- |
| stand surfaces | 12 | **12** |
| traversal | 11 (9 mandatory) | **12** (9 mandatory, 3 optional) |
| sockets | 10 | **10** |
| offers | 3 | **6** |
| collision pieces | 71 | **71** |
| size | 41.2 × 60.0 × 39.6 m | **unchanged** |

Everything the verdict asked to preserve is preserved: the repaired
flat-tread flights, the plinths as geometry rather than stand surfaces,
the rail, the launch pair, the open central vertical reservation, and
all of Wave 1 untouched. The entry sightline is re-asserted at build
time and still measures 64.7 m.

## Evidence

`tools/blender/traversallaw.py` gained a mirror of Production's grapple
rule — anchor clear, `SWING_ROOM` of air beneath, ground within
`GRAPPLE_DROP` below — reading both constants from Production's own
`movement_package.gd` rather than retyping them. It was calibrated
before it was trusted: **all nine of Wave 1's Production-certified
anchors pass**, and it refuses an anchor buried in the crane, one a
metre over the floor, and one outside the room. It stops the build now,
like the walk law does.

**`RoomAudit` remains the authority.** Production supplies the real
`clear` and `supported` probes and decides.
