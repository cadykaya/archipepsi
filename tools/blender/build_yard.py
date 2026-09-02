"""Wave 1 — `shell_yard_gantry`: wide, low, and about the ground.

    .tools/blender/blender -b --python tools/blender/build_yard.py

## The spatial job

The deliberate inverse of the plenum. 84 x 16 x 52 m: five times wider
than it is tall, where the plenum is three and a half times taller than
it is wide. If LARGE only works as height, this room is where that shows.

It is here because a library of tall rooms cannot hold a firefight. Long
horizontal sightlines, cover you can move between, and elevated positions
that overlook the floor without dominating it are what ranged enemies
need to control territory, and none of the P2 rooms and neither of the
other two Wave 1 rooms can provide them.

## The crane is the landmark and the ceiling

A gantry crane spans the full 84 m at 12 m, on rails carried by the two
long walls. It reads instantly, it tells the player how wide the room is
before they have crossed any of it, and it puts a hard horizontal line
across a space that would otherwise be a field. Standing under it is
different from standing beside it.

## Three heights, and the floor matters most

Floor at 0 with four cover clusters; a continuous perimeter catwalk at 8;
the crane bridge at 12. Entry and exit are both on the floor at opposite
ends, so the mandatory route is dead flat across 84 m and every metre of
height in the room is optional. The catwalk is reached by two stair
flights in the corners -- an 8 m climb the room does not require.

## Machinery this shape invites later

Two loading docks are recessed into the north wall at floor level, and
the crane bridge passes over them. A carryable object, a weighted floor
button, a powered door, a signal conduit run along the catwalk: this is
the one room in Wave 1 whose floor is open enough to put a puzzle on
without the puzzle fighting the architecture. Nothing of the kind is
built here.
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
THEME = "concrete_facility"

W, H, D = 84.0, 16.0, 52.0
WALL = 0.60
DOOR_W, DOOR_H = 2.40, 3.20

IN_X = W / 2.0 - WALL
CAT_Y, CRANE_Y = 8.0, 12.0
CAT_W = 3.4
DOCK_W, DOCK_D = 10.0, 5.0

_IMAGES = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("yard_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, name, role):
    common.assign(obj, common.make_textured_material(
        "%s_%s" % (name, role), _image(role), roughness=pal.roughness(THEME)))
    return roomcollision.paint_role(obj, role)


def build():
    name = "yd"
    parts = []
    stones, heights, snames = [], [], []

    def surface(tag, x0, x1, z0, z1, top, thick=0.70, role="floor"):
        stones.append(roomkit.slab(parts, _paint, name, tag, x0, x1, z0, z1,
                                   top, thick, role))
        heights.append(top)
        snames.append(tag)

    # --- the box ------------------------------------------------------
    surface("floor", -IN_X, IN_X, WALL, D - WALL, 0.0, 1.0)
    parts.append(_paint(brushkit.block(
        "%s_roof" % name, (W, D, WALL),
        (0.0, roomkit.y(D / 2.0), H + WALL / 2.0)), name, "ceiling"))
    for tag, z in (("south", WALL / 2.0), ("north", D - WALL / 2.0)):
        parts.append(_paint(brushkit.block(
            "%s_%s" % (name, tag), (W, WALL, H),
            (0.0, roomkit.y(z), H / 2.0)), name, "wall"))
    # The two short walls carry the doors, west in and east out.
    for tag, side in (("west", -1.0), ("east", 1.0)):
        for j, off in enumerate((-1.0, 1.0)):
            span = (D - DOOR_W) / 2.0
            parts.append(_paint(brushkit.block(
                "%s_%s_%d" % (name, tag, j), (WALL, span, H),
                (side * (W + WALL) / 2.0,
                 roomkit.y(D / 2.0 + off * (DOOR_W + span) / 2.0), H / 2.0)),
                name, "wall"))
        parts.append(_paint(brushkit.block(
            "%s_%s_head" % (name, tag), (WALL, DOOR_W, H - DOOR_H),
            (side * (W + WALL) / 2.0, roomkit.y(D / 2.0),
             (H + DOOR_H) / 2.0)), name, "wall"))

    # --- the crane ----------------------------------------------------
    #
    # The bridge spans the full width at 12 m on two rail beams. It is
    # the landmark and it is also the room's only overhead structure, so
    # it is what a grapple package would have to hang from.
    parts.append(_paint(brushkit.block(
        "%s_crane_bridge" % name, (W - WALL * 2.0, 4.0, 1.2),
        (0.0, roomkit.y(D / 2.0), CRANE_Y + 0.6), ), name, "floor"))
    for j, cz in enumerate((D / 2.0 - 2.6, D / 2.0 + 2.6)):
        parts.append(_paint(brushkit.block(
            "%s_crane_rail_%d" % (name, j), (W - WALL * 2.0, 0.8, 0.8),
            (0.0, roomkit.y(cz), CRANE_Y - 0.6)), name, "trim"))
    for j, cx in enumerate((-18.0, 18.0)):
        parts.append(_paint(brushkit.block(
            "%s_crane_leg_%d" % (name, j), (1.4, 4.0, CRANE_Y - 1.2),
            (cx, roomkit.y(D / 2.0), (CRANE_Y - 1.2) / 2.0 + 1.2)),
            name, "wall"))
    stones.append(((0.0, roomkit.y(D / 2.0)), (W - 6.0, 3.2)))
    heights.append(CRANE_Y + 1.2)
    snames.append("crane_bridge")

    # --- the perimeter catwalk ----------------------------------------
    surface("catwalk_s", -IN_X, IN_X, WALL, WALL + CAT_W, CAT_Y, 0.5)
    surface("catwalk_n", -IN_X, IN_X, D - WALL - CAT_W, D - WALL, CAT_Y, 0.5)
    surface("catwalk_w", -IN_X, -IN_X + CAT_W, WALL, D - WALL, CAT_Y, 0.5)
    surface("catwalk_e", IN_X - CAT_W, IN_X, WALL, D - WALL, CAT_Y, 0.5)

    # Two stair flights up to it, in opposite corners, so the climb is
    # never the shortest way anywhere -- the catwalk is a choice.
    roomkit.flight(parts, _paint, name, "stair_w",
                   -IN_X + CAT_W, -IN_X + CAT_W + 12.0,
                   WALL + CAT_W, WALL + CAT_W + 3.0, 0.0, CAT_Y, "x", False)
    roomkit.flight(parts, _paint, name, "stair_e",
                   IN_X - CAT_W - 12.0, IN_X - CAT_W,
                   D - WALL - CAT_W - 3.0, D - WALL - CAT_W,
                   0.0, CAT_Y, "x", True)

    # --- cover, and the two docks -------------------------------------
    for j, (cx, cz, sx, sz) in enumerate((
            (-26.0, 16.0, 5.0, 3.0), (-9.0, 34.0, 4.0, 4.0),
            (11.0, 15.0, 6.0, 3.0), (27.0, 33.0, 4.0, 5.0))):
        parts.append(_paint(brushkit.block(
            "%s_cover_%d" % (name, j), (sx, sz, 1.9),
            (cx, roomkit.y(cz), 0.95)), name, "wall"))
    for j, cx in enumerate((-24.0, 24.0)):
        parts.append(_paint(brushkit.block(
            "%s_dock_%d" % (name, j), (DOCK_W, 0.9, 1.1),
            (cx, roomkit.y(D - WALL - DOCK_D), 0.55)), name, "trim"))
    return name, parts, stones, heights, snames


def main():
    common.reset_scene()
    name, parts, stones, heights, snames = build()

    colliders = roomcollision.build(parts, name)
    roomcollision.assert_exact(name, parts, colliders)
    roomcollision.assert_supports(name, colliders, stones, heights, snames)
    roomcollision.assert_standable(name, colliders, stones, heights, snames)
    probe = roomcollision.measure_probe(colliders, stones, heights, snames)

    obj = common.join(parts, name)
    common.uv_project_world(obj, materials.ARCH_DENSITY, materials.ARCH_SIZE)
    cid = "shell_yard_gantry"
    entry = common.export_glb(obj, "%s/%s.glb" % (OUT, cid), "room",
                              tier="architecture",
                              texture_size=materials.ARCH_SIZE,
                              anchor="entrance", check_flat=False,
                              collision=colliders)
    if probe:
        entry["surface_probe"] = probe

    entry["exit_offset"] = [round(W / 2.0 + 2.0, 2), 0.0, round(D / 2.0, 2)]
    entry["exit_yaw"] = 90.0
    entry["check_anchor"] = [0.0, 0.0, D / 2.0]
    entry["enemy_anchors"] = [[-30.0, CAT_Y, 2.3], [30.0, CAT_Y, D - 2.3],
                              [0.0, CRANE_Y + 1.2, D / 2.0]]
    entry["bounds"] = [[-W / 2.0 - 2.0, -1.0, 0.0], [W + 4.0, H + 1.0, D]]
    entry["interior"] = [W, H, D]
    entry["total_rise"] = 0.0
    entry["surfaces"] = roomcontract.surfaces_from_stones(
        stones, heights, snames)

    def seg(tag, kind, a, b, mandatory=True):
        return {"name": tag, "kind": kind, "mandatory": bool(mandatory),
                "start": list(a), "end": list(b)}

    # THE MANDATORY ROUTE IS FLAT. West door to east door across 84 m of
    # open floor, and every metre of height in this room is optional --
    # which is the condition an offer is allowed to exist under.
    entry["traversal"] = [
        seg("entry_to_middle", "walk",
            (-IN_X + 1.0, 0.0, D / 2.0), (0.0, 0.0, D / 2.0)),
        seg("middle_to_exit", "walk",
            (0.0, 0.0, D / 2.0), (IN_X - 1.0, 0.0, D / 2.0)),
        seg("floor_to_catwalk_w", "walk",
            (-IN_X + CAT_W + 1.0, 0.0, WALL + CAT_W + 1.5),
            (-IN_X + 1.0, CAT_Y, WALL + CAT_W - 0.5), False),
        seg("floor_to_catwalk_e", "walk",
            (IN_X - CAT_W - 1.0, 0.0, D - WALL - CAT_W - 1.5),
            (IN_X - 1.0, CAT_Y, D - WALL - CAT_W + 0.5), False),
        seg("catwalk_s_to_w", "walk",
            (-IN_X + 1.0, CAT_Y, WALL + 1.0),
            (-IN_X + 1.0, CAT_Y, D / 2.0), False),
    ]

    entry["volumes"] = [
        roomcontract.volume("crane", "no_build",
                            (0.0, roomkit.y(D / 2.0), CRANE_Y),
                            (W - 6.0, 4.4, 3.0)),
        roomcontract.volume("arrival", "player_entry",
                            (-IN_X + 1.2, roomkit.y(D / 2.0), 1.0),
                            (2.4, DOOR_W, 2.0)),
        roomcontract.volume("reward", "objective",
                            (0.0, roomkit.y(D / 2.0), 1.0), (2.4, 2.4, 2.0)),
    ]

    entry["sockets"] = [
        roomcontract.socket("entry", "doorway",
                            (-W / 2.0 - 1.0, roomkit.y(D / 2.0), 0.0),
                            yaw=-90.0, width=DOOR_W, height=DOOR_H,
                            surface_id="floor"),
        roomcontract.socket("exit", "doorway",
                            (W / 2.0 + 1.0, roomkit.y(D / 2.0), 0.0),
                            yaw=90.0, width=DOOR_W, height=DOOR_H,
                            surface_id="floor"),
    ]
    for i, sname in enumerate(("catwalk_s", "catwalk_n", "catwalk_w",
                               "catwalk_e", "crane_bridge")):
        k = snames.index(sname)
        spot = roomcollision.stance_spot(colliders, stones[k], heights[k])
        if spot is None:
            raise AssertionError("%s: '%s' fits nothing" % (cid, sname))
        entry["sockets"].append(roomcontract.socket(
            "high_%d" % i, "enemy_high", (spot[0], spot[1], heights[k] + 0.3),
            surface_id=sname))
    for i, (cx, cz) in enumerate(((-26.0, 16.0), (-9.0, 34.0),
                                  (11.0, 15.0), (27.0, 33.0))):
        entry["sockets"].append(roomcontract.socket(
            "cover_%d" % i, "cover", (cx, roomkit.y(cz), 0.3),
            surface_id="floor"))

    # --- offers -------------------------------------------------------
    #
    # THE LONGEST LAUNCH IN THE LIBRARY, because this is the only room
    # wide enough to hold one. Floor to the far catwalk, 62 m across --
    # well inside LaunchSolver's 80 and impossible in any other Wave 1
    # shell.
    src = (-28.0, 0.5, D / 2.0)
    dst = (30.0, CAT_Y, D - WALL - CAT_W / 2.0)
    span = math.dist(src, dst)
    if not 0.5 <= span <= 80.0:
        raise AssertionError("%s: launch pair spans %.2f m" % (cid, span))
    # A short rail along the crane bridge: this room is not the rail
    # room and should not pretend to be. Four points, one axis, a ride
    # that exists to cross the yard fast rather than to be the point.
    rail = [(-36.0, CRANE_Y + 2.4, D / 2.0), (-12.0, CRANE_Y + 3.0, D / 2.0),
            (12.0, CRANE_Y + 3.0, D / 2.0), (36.0, CRANE_Y + 2.4, D / 2.0)]
    for a, b in zip(rail, rail[1:]):
        if not 0.5 <= math.dist(a, b) <= 60.0:
            raise AssertionError("%s: rail segment out of bounds" % cid)
    entry["offers"] = [
        {"name": "rail_crane", "kind": "rail_route",
         "points": [list(p) for p in rail]},
        {"name": "launch_west", "kind": "launch_source",
         "position": list(src), "radius": 3.0, "target": "launch_catwalk"},
        {"name": "launch_catwalk", "kind": "launch_target",
         "position": list(dst), "radius": 3.5},
    ]
    for k, cx in enumerate((-20.0, 0.0, 20.0)):
        entry["offers"].append({
            "name": "grapple_%d" % k, "kind": "grapple_point",
            "position": [cx, CRANE_Y - 1.4, D / 2.0], "radius": 1.5})
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
    existing = {}
    if os.path.exists(out):
        with open(out, encoding="utf-8") as handle:
            existing = json.load(handle)
    existing[cid] = entry
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(existing, handle, indent=2, sort_keys=True)
    common.log("%s: 84 m across, launch %.1f m, crane at %.1f"
               % (cid, span, CRANE_Y))
    print("[art] batch040 manifest -> %s" % out)


if __name__ == "__main__":
    main()
