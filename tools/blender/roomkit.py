"""Shared authoring helpers for LARGE room shells.

    import roomkit
    roomkit.flight(parts, paint, "west", x0, x1, z0, z1, low, high, axis)

Lifted out of `build_hall.py` so ten rooms share one implementation of
the things that are easy to get subtly wrong once and then wrong ten
times: the Blender/Godot axis convention, a deck by its edges, and a
climb that the import-time evidence can actually see.
"""

from __future__ import annotations

import brushkit


def y(z_godot):
    """Godot depth -> Blender y. The one conversion, spelled out.

    Every room in the library plans in Godot coordinates because that is
    what the manifest, the contract and Production all speak, and every
    room builds in Blender. One function, used everywhere, is the whole
    defence against the axis trap.
    """
    return -z_godot


def slab(parts, paint, name, tag, x0, x1, z0, z1, top, thick=0.70,
         role="floor"):
    """A deck by its EDGES in Godot coordinates.

    Every deck in every room was designed as a rectangle on a plan.
    Converting each one to a centre-and-size by hand is how a 0.5 m
    overlap gets built.
    """
    parts.append(paint(brushkit.block(
        "%s_%s" % (name, tag), (x1 - x0, z1 - z0, thick),
        ((x0 + x1) / 2.0, y((z0 + z1) / 2.0), top - thick / 2.0)),
        name, role))
    return (((x0 + x1) / 2.0, y((z0 + z1) / 2.0)), (x1 - x0, z1 - z0))


#: The tallest a single ramp section may rise.
#:
#: THIS IS THE NUMBER THAT MAKES A CLIMB PROVABLE, and it is not a taste
#: decision. `ShellValidator` proves a `walk` by flooding the collision
#: hulls' AXIS-ALIGNED BOXES, and one wedge spanning an eleven-metre
#: climb is a single box whose top is the high end -- so the evidence
#: sees an eleven-metre cliff wherever the ramp is, and the route is
#: refused. Measured on `shell_hall_transit` at `b37fe07`: along the west
#: ramp the box evidence returned 0.00 or 11.00 at every sample and
#: nothing in between.
#:
#: A section that rises no more than one `MAX_VERTICAL_STEP` has a box
#: the flood can step onto from below and off at the top, so a chain of
#: them climbs. Production's own 23 m sabotage ramp is thirty stacked
#: slabs for exactly this reason.
#:
#: 0.9 rather than 1.0: the bound is `MAX_VERTICAL_STEP + AS_BUILT_SLACK`
#: and a section modelled AT the limit is one float error from refusal.
FLIGHT_RISE = 0.9


def flight(parts, paint, name, tag, x0, x1, z0, z1, low, high, axis,
           flip=False, role="floor"):
    """A climb built as a chain of wedge sections, each rising <= 0.9 m.

    Visually this is the same ramp: the sections are collinear and their
    faces meet, so the silhouette is a continuous slope. What changes is
    that the collision hulls -- one convex hull per section, each exactly
    the section it copies -- present the intermediate heights that a box
    test needs to see. The render mesh and the collider still describe
    the same solid; nothing invisible is added.

    `axis` is the ramp's run direction, `"x"` or `"y"` (Blender y, i.e.
    Godot z), matching `brushkit.wedge`. `flip` reverses which end is
    low, exactly as the wedge does.
    """
    rise = high - low
    if rise <= 0.0:
        raise AssertionError("%s/%s: a flight must climb" % (name, tag))
    steps = max(1, int(-(-rise // FLIGHT_RISE)))    # ceil
    made = []
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        # The section's own low and high, and the slice of the run it
        # occupies. Reversed along the run when `flip` is set, so the
        # low end stays where the caller put it.
        s_low = low + rise * t0
        s_high = low + rise * t1
        if axis == "x":
            a, b = x0 + (x1 - x0) * t0, x0 + (x1 - x0) * t1
            if flip:
                a, b = x1 - (x1 - x0) * t1, x1 - (x1 - x0) * t0
            box = (a, b, z0, z1)
        else:
            a, b = z0 + (z1 - z0) * t0, z0 + (z1 - z0) * t1
            if flip:
                a, b = z1 - (z1 - z0) * t1, z1 - (z1 - z0) * t0
            box = (x0, x1, a, b)
        bx0, bx1, bz0, bz1 = box
        parts.append(paint(brushkit.wedge(
            "%s_%s_%d" % (name, tag, i),
            (bx1 - bx0, bz1 - bz0, s_high - s_low),
            ((bx0 + bx1) / 2.0, y((bz0 + bz1) / 2.0),
             (s_low + s_high) / 2.0),
            rotation_z=180.0 if flip else 0.0, axis=axis), name, role))
        made.append((box, s_low, s_high))
    return made


def flight_footprint(x0, x1, z0, z1, low, high, name="flight"):
    """The one Surface a flight needs, as a `roomcontract.surface` triple.

    ONE, not one per metre. The declared rectangles BOUND the physical
    search and prove nothing (`b37fe07`), so a climb needs its plan
    footprint inside the domain and nothing more -- the geometry supplies
    every height in between. Measured: adding this surface to the hall
    changed the flood's node count by exactly zero, because the basin and
    gallery rects already covered the footprint. It is declared anyway
    where a flight sits outside them, and its height is the mid-rise,
    which is a real standable spot on the flight and therefore a truthful
    C(ii) claim.
    """
    return {"name": name,
            "center": [(x0 + x1) / 2.0, (low + high) / 2.0, (z0 + z1) / 2.0],
            "extent": [x1 - x0, z1 - z0]}
