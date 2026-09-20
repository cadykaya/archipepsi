# Batch 011 — rails that bend

You asked for a spline rail with cool bends that the player can ride. Here
are three, and the constraint that shaped them.

Full write-up: [`ART_REVIEW.md`](../../ART_REVIEW.md) § *Batch 011*.

| Image | What it answers |
| --- | --- |
| `R_rail_family.png` · `_grey` · `_silhouette` | **start here** — rise, launch, weave, plus Batch 009's straight |
| `R_rail_ride.png` | riding at the launch, engine lens |
| `R_rail_launch.png` | where the low point sits |
| `R_rail_weave_above.png` | from above — ± 0.27 m is all the width there is |

## What the footprint allows

`FOOTPRINT["rail"]` is 1.0 m wide × 7.0 long × 3.6 tall.

- **Vertical bends are free** — `rail_arc_rise` climbs 1.30 m,
  `rail_arc_launch` dips 0.75 then rises 1.55 past where it started.
- **Lateral bends are nearly not** — the rail is 0.42 m across, so a swing
  has 0.27 m either side. `rail_arc_weave` is exactly that much.
- **A banked turn needs a wider `half_width`** and is interface
  requirement 16, not a model.

## The bit engineering has to agree to

The lane over a rail is an axis-aligned box `Area3D`, and a box cannot
follow a curve. So these are **polylines**, not swept splines — one box per
straight segment is implementable with the class that already exists — and
each manifest entry carries `ride_path`, the same points the mesh was swept
along.

> The mesh and the ride come from one list of points.

Speed and friction on a curve are yours and engineering's, not this lane's.
A dip that converts height into speed may want different numbers from a
flat rail; `rail_arc_launch` is shaped so the question is worth asking.

Nothing here is approved. `PASS` is yours.
