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


#: The tallest a single tread may rise above the one before it.
#:
#: The bound is `MAX_VERTICAL_STEP`, which is 1.0. This is 0.9 because a
#: tread modelled AT the limit is one float error from refusal, and the
#: glTF float32 round-trip moves a vertex by about 1e-7 m.
#:
#: THE NUMBER IS NOT THE HARD PART. An earlier version of this module got
#: `FLIGHT_RISE` right and the geometry wrong, and the reason is worth
#: keeping: it reasoned about what the IMPORT-TIME EVIDENCE would see --
#: collider AABBs -- rather than about what the surface does underfoot.
#: A chain of sloped wedges has exactly the AABBs a box flood wants, one
#: per 0.9 m of climb, and Art's gates all passed. The wedges themselves
#: were sloping the wrong way, and an AABB cannot see a slope. Production
#: put a real capsule on it at `67add07` and the surface sawtoothed.
#:
#: So the treads are FLAT and they are BOXES. A box has no slope and
#: therefore no handedness: there is no orientation left to get wrong,
#: which is the only reason to prefer a staircase over a ramp here.
FLIGHT_RISE = 0.9

#: How far each tread reaches FORWARD, into the slice of the run its
#: successor covers. The successor is taller and buries the extension, so
#: it changes neither the walking surface nor the silhouette -- it exists
#: so that two treads meeting at a plan boundary cannot open a hairline
#: seam under float32. Ten centimetres is far more than that error and
#: far less than anything a player could notice.
FLIGHT_OVERLAP = 0.10

#: A tread is exactly one riser tall -- no soffit, no stringer, nothing
#: hanging below.
#:
#: THIS IS WHAT KEEPS THE REPAIR TO THE SURFACE. A tread of height `per`
#: whose top is at `top_i` occupies exactly the band the wedge section it
#: replaces occupied, so a flight fills precisely the volume it filled
#: before: no room loses headroom under a stair, no sightline closes, no
#: clearance moves. The defect was the shape of the TOP; changing the
#: volume as well would have been a second, unasked-for change.
#:
#: It was briefly 0.30 m thicker, to make consecutive treads overlap
#: vertically. `shell_plenum_helix` refused the build immediately:
#: `bridge_2` had 2.43 m of headroom under run 9 against the 2.40 a
#: player needs, and the extra 0.30 took it to 2.13. Vertical overlap
#: buys nothing anyway -- treads abut face-to-face at the plan boundary,
#: and it is the PLAN overlap that makes a seam impossible to fall
#: through.


def flight(parts, paint, name, tag, x0, x1, z0, z1, low, high, axis,
           flip=False, role="floor"):
    """A climb built as flat-topped treads, each rising <= `FLIGHT_RISE`.

    An ordinary staircase: the physical top surface is a sequence of
    level treads whose tops rise monotonically in increments no larger
    than one `MAX_VERTICAL_STEP`. That is the property the walk law
    actually tests, and here it is a property of the SOLID rather than of
    a declaration or of a bounding box.

    `axis` names the run direction -- `"x"` or `"y"` -- and `"y"` means
    the run is along GODOT Z, because every room in this library plans in
    Godot coordinates. `flip` puts the low end at the far end of the run
    instead of the near one.

    WHY THERE IS NO WEDGE HERE ANY MORE. This built a chain of
    `brushkit.wedge` sections until `67add07`. A wedge slopes along a
    BLENDER axis, and for `axis="y"` the run is Godot z, which is
    *minus* Blender y -- so every section sloped against the direction
    its chain climbed. Walking up, each section fell away underfoot and
    the next one began nearly two metres higher. The room's own gates
    could not see it because they measured collider AABBs, and the AABB
    of a wedge is the box it was cut from. See L-95.

    Returns the treads as `(box, top)` pairs, low to high.
    """
    rise = high - low
    if rise <= 0.0:
        raise AssertionError("%s/%s: a flight must climb" % (name, tag))
    run = (x1 - x0) if axis == "x" else (z1 - z0)
    if run <= 0.0:
        raise AssertionError(
            "%s/%s: a flight needs a run to climb along; %s is %.2f m"
            % (name, tag, "x1-x0" if axis == "x" else "z1-z0", run))
    steps = max(1, int(-(-rise // FLIGHT_RISE)))    # ceil
    per = rise / steps
    thick = per
    made = []
    for i in range(steps):
        top = low + per * (i + 1)
        # The slice of the run this tread covers, plus the forward reach
        # into the next one. The last tread has no successor to bury an
        # overhang, so it stops at the end of the run.
        t0 = run * (i / float(steps))
        t1 = run * ((i + 1) / float(steps))
        if i < steps - 1:
            t1 += FLIGHT_OVERLAP
        # `flip` measures the run from the far end, so the caller's `low`
        # end stays where the caller put it. No geometry is mirrored --
        # there is nothing to mirror.
        if axis == "x":
            a, b = (x1 - t1, x1 - t0) if flip else (x0 + t0, x0 + t1)
            box = (a, b, z0, z1)
        else:
            a, b = (z1 - t1, z1 - t0) if flip else (z0 + t0, z0 + t1)
            box = (x0, x1, a, b)
        bx0, bx1, bz0, bz1 = box
        parts.append(paint(brushkit.block(
            "%s_%s_tread%d" % (name, tag, i),
            (bx1 - bx0, bz1 - bz0, thick),
            ((bx0 + bx1) / 2.0, y((bz0 + bz1) / 2.0), top - thick / 2.0)),
            name, role))
        made.append((box, top))
    assert_walkable(name, tag, low, made)
    return made


def assert_walkable(name, tag, low, made):
    """No tread may sit more than `FLIGHT_RISE` above the one before it.

    Cheap, and it holds the SOLID to the claim rather than the claim to
    itself: `made` carries the tops the boxes were actually built with,
    so a future change to how a tread is placed has to keep this true or
    stop the build. It is the assertion whose absence let a sawtoothed
    ramp ship.
    """
    previous = low
    for box, top in made:
        step = top - previous
        if step > FLIGHT_RISE + 1e-9:
            raise AssertionError(
                "%s/%s: a tread rises %.3f m above the one before it, past "
                "FLIGHT_RISE %.2f. A climb has to be walkable as BUILT, not "
                "as declared." % (name, tag, step, FLIGHT_RISE))
        if step <= 0.0:
            raise AssertionError(
                "%s/%s: tread tops must ascend; this one steps %.3f m."
                % (name, tag, step))
        previous = top


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
