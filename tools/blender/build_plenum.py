"""Wave 1 — `shell_plenum_helix`: the tall thin one, and the long rail.

    .tools/blender/blender -b --python tools/blender/build_plenum.py

## The spatial job

The owner's strongest standing want is *huge vertical space with a long
smooth spline rail through open air*. `shell_hall_transit` proved a rail
can exist in a LARGE room; it did not prove a rail can be the reason a
room exists. This one is built for it.

20 x 72 x 20 m: an aspect ratio of 1 : 3.6, the most extreme in the
library and the deliberate opposite of the hall's 40 x 38 x 60. A shaft
is the one shape where a rail has somewhere to go for seventy metres
without leaving the room, and where every point of the route is visible
from every other point.

## Entry at the top, exit at the bottom

**The player commits downward.** That is the room's first decision and it
is made at the door: you arrive on a platform seventy metres up and the
floor is a long way below you. Nothing else in the slate opens that way,
and it is what makes the rail an invitation rather than a shortcut --
the walk down is twelve runs of stair, and the rail is one ride.

Descent is also what makes the room cheap in the one budget that matters.
`TraversalLaw` proves a `walk` by flooding geometry, so a climb costs no
declared Surfaces at all -- but a room whose mandatory route descends
still needs no climb anywhere, and the whole 72 m is spent on spectacle.

## The machine, hung and never founded

The landmark is a machine column 8 m square, hanging from the roof and
stopping twelve metres short of the floor. It touches nothing. That is
the point: a founded core would divide the floor into corridors, and
this room wants its floor whole, as the place a missed rail costs you a
climb rather than the level.

Three collars ring it at 46.67, 29.17 and 11.67 m, each reached from the
helix by a short bridge. They are the room's mid-air rooms: somewhere to
stand that is not the wall, and the only places from which the machine
can be touched.

## Falling

The floor at y=0 is one continuous slab under the entire shaft. There is
no pit. A missed rail, a missed launch or a missed step costs height and
a walk back up, never the level -- and the launch pad on the floor exists
so that the walk back is a choice rather than a punishment.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import roomcollision  # noqa: E402
import roomcontract  # noqa: E402
import roomkit  # noqa: E402
import traversallaw  # noqa: E402
import palette as pal  # noqa: E402

OUT = "batch040/shells"
THEME = "rusted_industrial"

#: Godot order for the reader: width, height, depth.
W, H, D = 20.0, 72.0, 20.0
WALL = 0.60
DOOR_W, DOOR_H = 2.40, 3.20

#: The walkway annulus. The wall's inner face, and how wide the helix is.
IN = W / 2.0 - WALL            # 9.4
WALK = 3.0
INNER = IN - WALK              # 6.4

#: The hanging machine: 8 m square, from the roof down to 12 m up.
MACH = 8.0
MACH_BOTTOM = 12.0
MACH_TOP = 68.0

#: Three collars, and how far they reach past the machine.
COLLAR_OUT = 6.75
COLLAR_T = 0.6

#: The helix: three turns, four runs each, entry to floor.
TURNS = 3
RUNS = TURNS * 4
#: The entry platform. 68 rather than 70: the roof is at 72 and a
#: player needs 2.4 m of headroom, so a landing at 70 is a crawlspace.
TOP = 68.0
LAND = 3.0                     # a corner landing is 3 x 3

_IMAGES = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("plen_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, name, role):
    common.assign(obj, common.make_textured_material(
        "%s_%s" % (name, role), _image(role), roughness=pal.roughness(THEME)))
    return roomcollision.paint_role(obj, role)


def _corner(i):
    """The plan centre of landing `i`, going anticlockwise from SW.

    The helix turns the same way for its whole descent, so the corner
    order is fixed and the runs between them follow from it.
    """
    half = LAND / 2.0
    ring = [(-IN + half, WALL + half),      # SW
            (IN - half, WALL + half),       # SE
            (IN - half, D - WALL - half),   # NE
            (-IN + half, D - WALL - half)]  # NW
    return ring[i % 4]


def build():
    name = "pl"
    parts = []
    stones, heights, snames = [], [], []

    def surface(tag, x0, x1, z0, z1, top, thick=0.70, role="floor"):
        stone = roomkit.slab(parts, _paint, name, tag, x0, x1, z0, z1,
                             top, thick, role)
        stones.append(stone)
        heights.append(top)
        snames.append(tag)

    # --- the shaft ----------------------------------------------------
    surface("floor", -IN, IN, WALL, D - WALL, 0.0, 1.0)
    parts.append(_paint(brushkit.block(
        "%s_roof" % name, (W, D, WALL), (0.0, roomkit.y(D / 2.0),
                                         H + WALL / 2.0)), name, "ceiling"))
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "%s_wall_%d" % (name, int(side)), (WALL, D, H),
            (side * (W + WALL) / 2.0, roomkit.y(D / 2.0), H / 2.0)),
            name, "wall"))
    # South wall, with the entry high in it; north wall, with the exit low.
    for tag, z, hole_y in (("south", WALL / 2.0, TOP), ("north", D - WALL / 2.0, 0.0)):
        span = (W - DOOR_W) / 2.0
        for side in (-1.0, 1.0):
            parts.append(_paint(brushkit.block(
                "%s_%s_%d" % (name, tag, int(side)), (span, WALL, H),
                (side * (DOOR_W + span) / 2.0, roomkit.y(z), H / 2.0)),
                name, "wall"))
        if hole_y > 0.0:
            parts.append(_paint(brushkit.block(
                "%s_%s_sill" % (name, tag), (DOOR_W, WALL, hole_y),
                (0.0, roomkit.y(z), hole_y / 2.0)), name, "wall"))
        head = H - hole_y - DOOR_H
        parts.append(_paint(brushkit.block(
            "%s_%s_head" % (name, tag), (DOOR_W, WALL, head),
            (0.0, roomkit.y(z), H - head / 2.0)), name, "wall"))

    # --- the hanging machine ------------------------------------------
    mh = MACH / 2.0
    parts.append(_paint(brushkit.block(
        "%s_machine" % name, (MACH, MACH, MACH_TOP - MACH_BOTTOM),
        (0.0, roomkit.y(D / 2.0), (MACH_TOP + MACH_BOTTOM) / 2.0)),
        name, "wall"))
    for j, off in enumerate((-2.6, 2.6)):
        parts.append(_paint(brushkit.block(
            "%s_hanger_%d" % (name, j), (0.9, 0.9, H - MACH_TOP),
            (off, roomkit.y(D / 2.0), (H + MACH_TOP) / 2.0)), name, "wall"))

    # --- the helix ----------------------------------------------------
    #
    # Twelve runs between twelve corner landings, each descending the
    # same amount. Every run is a `roomkit.flight`, so the collision
    # hulls present the slope one <= 0.9 m section at a time and the
    # import-time flood can see it -- the failure that made every climb
    # in `shell_hall_transit` unprovable at b37fe07.
    drop = TOP / RUNS
    land_y = [TOP - drop * i for i in range(RUNS + 1)]
    for i in range(RUNS + 1):
        cx, cz = _corner(i)
        half = LAND / 2.0
        surface("landing_%d" % i, cx - half, cx + half,
                cz - half, cz + half, land_y[i], 0.5)
    for i in range(RUNS):
        (ax, az), (bx, bz) = _corner(i), _corner(i + 1)
        half = LAND / 2.0
        hi, lo = land_y[i], land_y[i + 1]
        if abs(ax - bx) > abs(az - bz):          # a run along x
            x0, x1 = min(ax, bx) + half, max(ax, bx) - half
            flip = bx < ax
            roomkit.flight(parts, _paint, name, "run_%d" % i,
                           x0, x1, az - WALK / 2.0, az + WALK / 2.0,
                           lo, hi, "x", not flip)
        else:                                    # a run along z
            z0, z1 = min(az, bz) + half, max(az, bz) - half
            flip = bz < az
            roomkit.flight(parts, _paint, name, "run_%d" % i,
                           ax - WALK / 2.0, ax + WALK / 2.0, z0, z1,
                           lo, hi, "y", not flip)

    # --- the three collars, and the bridges that reach them -----------
    collars = []
    for k, li in enumerate((4, 7, 10)):
        top = land_y[li]
        parts.append(_paint(brushkit.tube(
            "%s_collar_%d" % (name, k), COLLAR_OUT, mh, COLLAR_T, 12,
            (0.0, roomkit.y(D / 2.0), top - COLLAR_T / 2.0)), name, "floor"))
        cx, cz = _corner(li)
        # A spur from the landing to the collar. Along whichever axis is
        # shorter, so the bridge crosses open air rather than skimming a
        # wall.
        if abs(cx) > abs(cz - D / 2.0):
            x0, x1 = (cx, -COLLAR_OUT) if cx < 0 else (COLLAR_OUT, cx)
            surface("bridge_%d" % k, min(x0, x1), max(x0, x1),
                    D / 2.0 - 1.2, D / 2.0 + 1.2, top, 0.4)
        else:
            z0, z1 = ((cz, D / 2.0 - COLLAR_OUT) if cz < D / 2.0
                      else (D / 2.0 + COLLAR_OUT, cz))
            surface("bridge_%d" % k, -1.2, 1.2,
                    min(z0, z1), max(z0, z1), top, 0.4)
        collars.append((top, li))
        # THE COLLAR IS A RING, AND ITS CENTRE IS THE MACHINE. A stone
        # spanning the whole outer square would be a `stand` Surface
        # promising a placement inside eight metres of solid steel --
        # measured as 0.00 m of headroom, which is what it deserves. The
        # declared rect is one band of the walkable annulus instead:
        # smaller than the ring, entirely real, and a Surface owes ONE
        # findable placement rather than a full rect (C(ii)).
        # Inset from both edges, because the collar is a TWELVE-GON and
        # not a square: its inradius is COLLAR_OUT * cos(15 deg) = 6.52,
        # so a band declared out to 6.75 hangs off the flats between the
        # vertices. `assert_supports` measured exactly that -- three
        # samples at x = 6.60 with no collider under them.
        lo, hi = mh + 0.3, COLLAR_OUT * math.cos(math.radians(15.0)) - 0.3
        stones.append((((lo + hi) / 2.0, roomkit.y(D / 2.0)),
                       (hi - lo, hi - lo)))
        heights.append(top)
        snames.append("collar_%d" % k)

    return name, parts, stones, heights, snames, land_y, collars


def _rail_points(land_y):
    """One route, three turns, top to bottom, spiralling the machine.

    SPARSE ON PURPOSE. `RailPath` at `b37fe07` builds a Catmull-Rom
    through exactly these points, so hand-authoring dense points to fake
    smoothness would be authoring the spline Production supplies. Twelve
    points for seventy metres of descent: one per run, offset inward from
    the walkway so the ride is over the void rather than over the stair.
    """
    ring = [(-4.8, 5.2), (4.8, 5.2), (4.8, 14.8), (-4.8, 14.8)]
    pts = []
    for i in range(RUNS):
        x, z = ring[i % 4]
        pts.append((x, land_y[i] - 1.6, z))
    pts.append((0.0, 4.0, D / 2.0))
    return pts


def main():
    common.reset_scene()
    name, parts, stones, heights, snames, land_y, collars = build()

    colliders = roomcollision.build(parts, name)
    roomcollision.assert_exact(name, parts, colliders)
    roomcollision.assert_supports(name, colliders, stones, heights, snames)
    roomcollision.assert_standable(name, colliders, stones, heights, snames)
    probe = roomcollision.measure_probe(colliders, stones, heights, snames)

    obj = common.join(parts, name)
    common.uv_project_world(obj, materials.ARCH_DENSITY, materials.ARCH_SIZE)
    cid = "shell_plenum_helix"
    entry = common.export_glb(obj, "%s/%s.glb" % (OUT, cid), "room",
                              tier="architecture",
                              texture_size=materials.ARCH_SIZE,
                              anchor="entrance", check_flat=False,
                              collision=colliders)
    if probe:
        entry["surface_probe"] = probe

    entry["exit_offset"] = [0.0, 0.0, round(D + 2.0, 2)]
    entry["exit_yaw"] = 0.0
    entry["check_anchor"] = [0.0, land_y[7], D / 2.0]
    entry["enemy_anchors"] = [[0.0, t, D / 2.0] for t, _ in collars]
    entry["bounds"] = [[-W / 2.0, -1.0, 0.0], [W, H + 1.0, D + 2.0]]
    entry["interior"] = [W, H, D]
    entry["total_rise"] = 0.0
    entry["surfaces"] = roomcontract.surfaces_from_stones(
        stones, heights, snames)

    def seg(tag, kind, a, b, mandatory=True):
        return {"name": tag, "kind": kind, "mandatory": bool(mandatory),
                "start": [a[0], a[1], a[2]], "end": [b[0], b[1], b[2]]}

    # THE DESCENT, RUN BY RUN. Not one seventy-metre `walk`: the flood
    # fails CLOSED at 8000 samples, and a single segment spanning the
    # whole helix would ask it to prove a 170 m path through a 20 x 20
    # domain. Twelve short proofs are twelve cheap floods, and they are
    # also the truthful description -- each run is its own piece of
    # circulation with a landing at each end.
    #
    # `walk`, not `drop`. The player never leaves the ground on a stair;
    # `drop` claims a fall, and claiming one here would be describing a
    # route nobody has to take.
    entry["traversal"] = []
    for i in range(RUNS):
        (ax, az), (bx, bz) = _corner(i), _corner(i + 1)
        entry["traversal"].append(seg(
            "landing_%d_to_%d" % (i, i + 1), "walk",
            (ax, land_y[i], az), (bx, land_y[i + 1], bz)))
    for k, (top, li) in enumerate(collars):
        cx, cz = _corner(li)
        entry["traversal"].append(seg(
            "landing_%d_to_collar_%d" % (li, k), "walk",
            (cx, top, cz), (0.0, top, D / 2.0), False))

    entry["volumes"] = [
        roomcontract.volume("machine", "no_build",
                            (0.0, roomkit.y(D / 2.0),
                             (MACH_TOP + MACH_BOTTOM) / 2.0),
                            (MACH, MACH, MACH_TOP - MACH_BOTTOM)),
        roomcontract.volume("arrival", "player_entry",
                            (_corner(0)[0], roomkit.y(_corner(0)[1]),
                             TOP + 1.0), (DOOR_W, 2.4, 2.0)),
        roomcontract.volume("reward", "objective",
                            (0.0, roomkit.y(D / 2.0), land_y[7] + 1.0),
                            (2.4, 2.4, 2.0)),
    ]

    entry["sockets"] = [
        roomcontract.socket("entry", "doorway",
                            (0.0, 0.0, TOP), yaw=180.0,
                            width=DOOR_W, height=DOOR_H,
                            surface_id="landing_0"),
        roomcontract.socket("exit", "doorway",
                            (0.0, roomkit.y(D + 2.0), 0.0), yaw=0.0,
                            width=DOOR_W, height=DOOR_H,
                            surface_id="floor"),
    ]
    for i, sname in enumerate([n for n in snames if n.startswith("collar")]
                              + ["landing_2", "landing_9"]):
        k = snames.index(sname)
        spot = roomcollision.stance_spot(colliders, stones[k], heights[k])
        if spot is None:
            raise AssertionError("%s: '%s' fits nothing" % (cid, sname))
        entry["sockets"].append(roomcontract.socket(
            "high_%d" % i, "enemy_high", (spot[0], spot[1], heights[k] + 0.3),
            surface_id=sname))
    for i, (cx, cz) in enumerate(((-5.0, 5.0), (5.0, 15.0))):
        entry["sockets"].append(roomcontract.socket(
            "cover_%d" % i, "cover", (cx, roomkit.y(cz), 0.3),
            surface_id="floor"))

    # --- offers -------------------------------------------------------
    rail = _rail_points(land_y)
    for a, b in zip(rail, rail[1:]):
        run = math.dist(a, b)
        if not 0.5 <= run <= 60.0:
            raise AssertionError("%s: rail segment %.2f m is outside "
                                 "RailPath's 0.5-60.0" % (cid, run))
        flat = math.hypot(b[0] - a[0], b[2] - a[2])
        pitch = math.degrees(math.atan2(abs(b[1] - a[1]), flat))
        if pitch > 75.0:
            raise AssertionError("%s: rail pitch %.1f deg exceeds 75"
                                 % (cid, pitch))
    src = (0.0, 0.5, 6.0)
    dst = (0.0, land_y[7], D / 2.0)
    span = math.dist(src, dst)
    if not 0.5 <= span <= 80.0:
        raise AssertionError("%s: launch pair spans %.2f m" % (cid, span))
    entry["offers"] = [
        {"name": "rail_descent", "kind": "rail_route",
         "points": [[p[0], p[1], p[2]] for p in rail]},
        {"name": "launch_floor", "kind": "launch_source",
         "position": list(src), "radius": 3.0, "target": "launch_collar"},
        {"name": "launch_collar", "kind": "launch_target",
         "position": list(dst), "radius": 3.5},
    ]
    # `grapple_point` is a PLACE, not a mechanic (b37fe07): anchor clear,
    # 4 m of air beneath it, and ground within 30 m below to leave from
    # or arrive at. Each sits over a helix run rather than over the
    # floor, which is what keeps the drop inside GRAPPLE_DROP in a 72 m
    # shaft.
    for k, (ax, ay, az) in enumerate(((-7.0, 20.0, 10.0),
                                      (7.0, 38.0, 10.0),
                                      (-7.0, 56.0, 10.0))):
        entry["offers"].append({"name": "grapple_%d" % k,
                                "kind": "grapple_point",
                                "position": [ax, ay, az], "radius": 1.5})
    entry["rail_span"] = round(sum(math.dist(rail[i], rail[i + 1])
                                   for i in range(len(rail) - 1)), 2)
    entry["launch_span"] = round(span, 2)

    traversallaw.assert_declared(colliders, entry, cid,
                                 roomcollision._world_box)

    entry["size_godot"] = [round(entry["size"][0], 3),
                           round(entry["size"][2], 3),
                           round(entry["size"][1], 3)]
    roomcontract.assert_axis_order(cid, entry["size"], entry["interior"],
                                   entry["size_godot"])

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch040",
                       "shells", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump({cid: entry}, handle, indent=2, sort_keys=True)
    common.log("%s: %d runs, %.1f m of descent, rail %.1f m"
               % (cid, RUNS, TOP, entry["rail_span"]))
    print("[art] batch040 manifest -> %s" % out)


if __name__ == "__main__":
    main()
