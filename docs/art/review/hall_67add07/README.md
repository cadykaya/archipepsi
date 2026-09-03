# `shell_hall_transit` — current state after the flight repair

**These are the room as it stands now.** The P3 package in
`docs/art/review/p3_owner/` is the room as it stood when the owner
reviewed it, and it is deliberately left alone — re-rendering it would
erase what was actually reviewed. Where the two disagree, this directory
is the current room.

The shell still exports `review: "pending"`. Nothing here promotes it.

---

## What changed, and why

Production's capsule audit at `67add07` refused two mandatory climbs:

| segment | flight | Production's measurement |
| --- | --- | --- |
| `basin_to_gallery` | `ramp1` | surface falls 0.35–0.70 m between apparent treads, then demands ~1.40 m |
| `gantry_to_exit` | `ramp3` | same |
| *`gallery_to_landing`* | *`ramp2`* | *never refused* |

The flights were chains of sloped wedges. A wedge slopes along a
**Blender** axis; this library plans in **Godot** coordinates, where a
run along `"y"` means Godot z — which is *minus* Blender y. So every
section of a `"y"` flight sloped against the direction its own chain
climbed. `ramp1` and `ramp3` are the two `"y"` flights in the room, and
`ramp2` is the one `"x"` flight. That is the whole of it.

They are **flat treads** now. A box has no slope and so no handedness:
there is no orientation left to get wrong. Each tread is exactly one
riser tall, so the flights occupy the same volume the ramps did — no
headroom, sightline or clearance in the room moved.

Measured on the shipped `.glb`, from the collider triangles, on a 0.10 m
grid:

| flight | treads | tops | worst real step |
| --- | --- | --- | --- |
| `ramp1` basin 0 → west gallery 11 | 13 | 0.85 → 11.00 | **0.85 m** |
| `ramp2` gallery 11 → north landing 21 | 12 | 11.83 → 21.00 | **0.83 m** |
| `ramp3` east gantry 21 → exit platform 28 | 8 | 21.88 → 28.00 | **0.88 m** |

`MAX_VERTICAL_STEP` is 1.00.

## What did NOT change

The contract is identical, field for field: **12 surfaces, 11 traversal
segments (all `walk`), 10 sockets, 3 volumes, 3 offers, 71 colliders**,
same 41.2 × 60.0 × 39.6 m box. No traversal endpoint moved. The
repaired ring/collar, the `gallery_to_landing` repair and the plinths-as-
geometry decision all stand. Only the geometry underfoot is different.

Triangles went 792 → 924, which is the cost of boxes over wedges.

---

## The views

**`S1`–`S4` are the repair.** They are new — no P3 view stands close
enough to a flight to show what a tread is.

| | |
| --- | --- |
| `S1_ramp1_basin_to_gallery` | the refused west climb, looking up it from the basin |
| `S2_ramp2_gallery_to_landing` | the flight that was always correct, for comparison |
| `S3_ramp3_gantry_to_exit` | the refused east climb, the steepest in the room |
| `S4_ramp1_from_the_gallery` | the same 13 treads looking back down — the descent |

Every one stands **on** the flight and looks along it: the player's own
view of the climb, and the only view of a staircase nothing can block.
The cameras are derived from the shipped tread boxes rather than from
the manifest, because a flight is geometry and not a declared object.

`phone/flights.png` stacks all four into one scrolling sheet.

**`H1`–`H8` and `O1`–`O6`** are the same fourteen views and overlays as
the P3 package, re-rendered against the current geometry, so the two
directories can be held side by side. The overlays are still derived from
the shipped manifest by `tools/blender/build_hall_overlay.py` — and since
the manifest did not change, they are unchanged.

## Evidence, not a verdict

`tools/content/measure_flights.py` reads the collider triangles and
proves the surface; it is stage 5 of `verify_content_pack.sh`. It
reproduced Production's finding on the old geometry before anything was
repaired. **`RoomAudit` remains the physical authority** — this measures
a height field, and a height field cannot see a pinch too narrow for a
body.
