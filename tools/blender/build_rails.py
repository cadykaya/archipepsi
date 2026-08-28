"""Batch 011 -- rails that bend, and what it costs to ride one.

    .tools/blender/blender -b --python tools/blender/build_rails.py

Batch 009 built `rail_beam`: 6.0 m of straight beam, at the engine's own
numbers. The owner asked for rails with bends in them that the player can
actually ride, and the interesting part of that request is not the mesh --
it is which bends the game can afford today.

## The constraint, before the fun

`affordance_features.FOOTPRINT["rail"]` is `half_width 0.5, half_depth 3.5`
with a height of 3.6. So a rail's whole footprint is **1.0 m wide, 7.0 m
long, 3.6 m tall**, and that decides everything:

* **A bend in the VERTICAL plane fits today.** There is 3.6 m of headroom
  and a straight rail uses 1.7 of it. Rises, dips and launches are free.
* **A bend in the HORIZONTAL plane does not.** A rail is 0.46 m across, so
  a lateral swing has 0.27 m either side of the centreline before the
  footprint is broken -- enough for a weave, nowhere near a turn.

So two of the three built here are vertical, the third is the widest weave
that still fits, and a proper banked turn is interface requirement 16
rather than a model nobody can place.

## The ride, and why these are polylines

`_rail` hangs an `AffordanceNodes.Volume` over the beam --
`extents = Vector3(1.1, 1.4, length)`, an axis-aligned box Area3D. A box
cannot follow a curve, so a swept spline would be a rail the player falls
straight through.

A **polyline** can: one box per segment, each oriented along its own
segment, is implementable with the class that already exists. So each rail
here is built from an explicit chain of straight segments, and its
manifest entry carries `ride_path` -- the same points the mesh was swept
along, in metres, in the asset's own space. Engineering builds the volume
chain from that rather than from a second description that can drift.

That is the whole contract: **the mesh and the ride come from one list of
points.**

## What is NOT decided here

Speed, friction and lift on a curve are gameplay. `_rail`'s lane runs
`{friction_scale: 0.05, speed_scale: 1.25, gravity_scale: 0.85}` and a dip
that converts height into speed may well want different numbers. This lane
does not pick them; `rail_arc_launch` is shaped so the question is worth
asking.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"
OUT = "batch011/affordance"

#: FOOTPRINT["rail"] -- half_width 0.5, half_depth 3.5, height 3.6.
HALF_W = 0.5
HALF_D = 3.5
MAX_H = 3.6
#: The straight rail's own numbers, kept so a bent rail is the same object.
SPAN = 2.0 * HALF_D - 1.0        # 6.0
SECTION = 0.35
DECK = 0.24
#: How far a rail may swing sideways before it breaks the footprint:
#: half_width, less half the rail's own widest part (the 0.42 m stops).
SWING = HALF_W - 0.23            # 0.27


def _ease(t):
    """Smoothstep. A bend that starts and ends flat is a bend you keep
    speed through; a circular arc has a corner at each end."""
    return t * t * (3.0 - 2.0 * t)


def path_rise(count=10):
    """Climbs 1.30 m over the run. Ride it up and step off higher."""
    return [(0.0, -SPAN / 2.0 + SPAN * (i / count),
             1.10 + 1.30 * _ease(i / count)) for i in range(count + 1)]


def path_launch(count=12):
    """Dips, then rises past where it started. A valley into a ramp.

    The low point is at 40% of the run, not the middle: a symmetric valley
    gives back exactly what it took and reads as a decoration. Off-centre,
    the second half is longer and shallower than the first, so the rail
    trades height for distance -- which is what a launch is.
    """
    points = []
    for i in range(count + 1):
        t = i / count
        if t <= 0.4:
            z = 1.70 - 0.75 * _ease(t / 0.4)
        else:
            z = 0.95 + 1.55 * _ease((t - 0.4) / 0.6)
        points.append((0.0, -SPAN / 2.0 + SPAN * t, z))
    return points


def path_weave(count=12):
    """The widest lateral swing the footprint allows: +/- 0.27 m.

    One full S. It is a gentle weave rather than a turn, and that is the
    footprint's decision, not a design one -- see interface requirement 16.
    """
    return [(SWING * math.sin(2.0 * math.pi * (i / count)),
             -SPAN / 2.0 + SPAN * (i / count), 1.20)
            for i in range(count + 1)]


def build_rail(name, points, label):
    beam = brushkit.sweep(name + "_beam", points, SECTION, DECK)
    shell = [beam]
    # A post wherever the rail is high enough to need one, on the 1.2 m
    # spacing the straight rail's ties use. Generated FROM the path, so a
    # rail that changes shape cannot end up with its posts in mid-air.
    step = max(1, len(points) // 5)
    for i in range(0, len(points), step):
        x, y, z = points[i]
        foot = z - DECK / 2.0
        if foot < 0.45:
            continue
        shell.append(brushkit.block("%s_post_%d" % (name, i),
                                    (0.25, 0.25, foot),
                                    (x, y, foot / 2.0)))
        shell.append(brushkit.block("%s_cleat_%d" % (name, i),
                                    (0.40, 0.20, 0.10),
                                    (x, y, foot + 0.02)))
    # Hard stops at both ends: a rail you can overshoot is a rail that
    # kills you. Batch 009's rule, and it applies harder on a launch.
    for end, point in ((-1.0, points[0]), (1.0, points[-1])):
        x, y, z = point
        shell.append(brushkit.block("%s_stop_%d" % (name, int(end)),
                                    (0.42, 0.18, 0.46),
                                    (x, y + end * 0.09, z + 0.11)))
    # The lit lane, riding 60 mm over the deck along the same path. One
    # unbroken line: anything crossing it reads as something to catch on.
    lane = brushkit.sweep(name + "_lane",
                          [(x, y, z + 0.06) for x, y, z in points], 0.20, 0.05)

    shell_obj = common.join(shell, name + "_shell")
    common.uv_project_world(shell_obj, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    common.assign(shell_obj, common.make_textured_material(
        name, propkit.hero_shell(THEME, name, "signal",
                                 label=label).to_blender(name + "_tex"),
        roughness=pal.roughness(THEME)))
    common.assign(lane, common.make_signal_material(
        name + "_lane", pal.universal("signal", 0), pal.universal("signal", 3),
        saturation=0.9))

    obj = common.join([shell_obj, lane], name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, (2.0 * HALF_W, 2.0 * HALF_D, MAX_H),
                       "FOOTPRINT['rail'] is 0.5 x 3.5 half-extents and "
                       "3.6 m of height.")
    entry = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "interactable",
                              check_flat=False)
    # THE CONTRACT: the same points the mesh was swept along, so the ride's
    # volume chain is built from one description rather than two.
    entry["ride_path"] = [[round(v, 3) for v in p] for p in points]
    return entry


RAILS = [
    ("rail_arc_rise", path_rise, "up"),
    ("rail_arc_launch", path_launch, "go"),
    ("rail_arc_weave", path_weave, "rail"),
]


def main():
    common.reset_scene()
    report = {}
    for name, path, label in RAILS:
        report[name] = build_rail(name, path(), label)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch011",
                       "affordance", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
