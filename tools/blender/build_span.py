"""Wave 1 — `shell_span_basin`: a bridge over somewhere you can fall to.

    .tools/blender/blender -b --python tools/blender/build_span.py

## The spatial job

The third proportion. 30 x 22 x 90 m: long and comparatively low, where
the plenum is a shaft and the yard is a field. Its identity is a single
90 m deck on two pylons, and the fact that there is a whole second room
underneath it.

## Two routes, and both of them arrive

Entry and exit are BOTH on the bridge at 14 m, so the mandatory route is
dead level from end to end. But the basin at 0 runs the full length too,
reachable by a flight at each end, and it also arrives. That is the whole
design: the player picks a height, and neither choice is the detour.

Above, you are exposed for ninety metres with nothing to break line of
sight but the two pylons. Below, you are covered, slower, and you cannot
see what is waiting at the far end. Ranged enemies on the bridge make the
basin the flank; ranged enemies in the basin make the bridge a gauntlet.
Nothing here places either.

## Falling is a route, not a punishment

The bridge has no railing on purpose. A fall from 14 m lands on the
basin floor, which is continuous under the entire span, and the basin
has its own way back up at both ends -- so falling off the bridge puts
the player on the other route rather than at a reload. That is what
"recovery geography" has to mean before any of the movement offers are
allowed to be interesting.

## The rail runs UNDER the deck

The rail is slung beneath the bridge, basin to basin, so riding it is a
third way down the room at a third height, and so that the room's most
photogenic line is one the player only finds by leaving the obvious
route.
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

W, H, D = 30.0, 22.0, 90.0
WALL = 0.60
DOOR_W, DOOR_H = 2.40, 3.20

IN_X = W / 2.0 - WALL
DECK_Y = 14.0
DECK_W = 7.0
PYLON = 4.0
SHOULDER_Y = 7.0
RAMP_RUN = 16.0

_IMAGES = {}


#: The basin's cover clusters: (centre x, centre z, size x, size z) in
#: Godot metres. ONE list, read by both the geometry and the socket
#: declaration.
COVER = ((-9.0, 22.0, 4.0, 3.0), (8.0, 44.0, 3.0, 5.0),
         (-7.0, 66.0, 5.0, 3.0))


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("span_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, name, role):
    common.assign(obj, common.make_textured_material(
        "%s_%s" % (name, role), _image(role), roughness=pal.roughness(THEME)))
    return roomcollision.paint_role(obj, role)


def build():
    name = "sp"
    parts = []
    stones, heights, snames = [], [], []

    def surface(tag, x0, x1, z0, z1, top, thick=0.70, role="floor"):
        stones.append(roomkit.slab(parts, _paint, name, tag, x0, x1, z0, z1,
                                   top, thick, role))
        heights.append(top)
        snames.append(tag)

    # --- the box ------------------------------------------------------
    surface("basin", -IN_X, IN_X, WALL, D - WALL, 0.0, 1.0)
    parts.append(_paint(brushkit.block(
        "%s_roof" % name, (W, D, WALL),
        (0.0, roomkit.y(D / 2.0), H + WALL / 2.0)), name, "ceiling"))
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "%s_wall_%d" % (name, int(side)), (WALL, D, H),
            (side * (W + WALL) / 2.0, roomkit.y(D / 2.0), H / 2.0)),
            name, "wall"))
    # Both end walls carry a door at DECK level, because both ends of the
    # mandatory route are on the bridge.
    for tag, z in (("south", WALL / 2.0), ("north", D - WALL / 2.0)):
        span = (W - DOOR_W) / 2.0
        for j, off in enumerate((-1.0, 1.0)):
            parts.append(_paint(brushkit.block(
                "%s_%s_%d" % (name, tag, j), (span, WALL, H),
                (off * (DOOR_W + span) / 2.0, roomkit.y(z), H / 2.0)),
                name, "wall"))
        parts.append(_paint(brushkit.block(
            "%s_%s_sill" % (name, tag), (DOOR_W, WALL, DECK_Y),
            (0.0, roomkit.y(z), DECK_Y / 2.0)), name, "wall"))
        head = H - DECK_Y - DOOR_H
        parts.append(_paint(brushkit.block(
            "%s_%s_head" % (name, tag), (DOOR_W, WALL, head),
            (0.0, roomkit.y(z), H - head / 2.0)), name, "wall"))

    # --- the span -----------------------------------------------------
    #
    # ONE DECK, END TO END, NO RAILING. The fall is a route to the other
    # half of the room, not a death, and a parapet would take that away
    # while adding nothing the silhouette needs.
    surface("deck", -DECK_W / 2.0, DECK_W / 2.0, WALL, D - WALL, DECK_Y, 0.9)
    for j, cz in enumerate((D * 0.3, D * 0.7)):
        parts.append(_paint(brushkit.block(
            "%s_pylon_%d" % (name, j), (PYLON, PYLON, DECK_Y - 0.9),
            (0.0, roomkit.y(cz), (DECK_Y - 0.9) / 2.0)), name, "wall"))
        # A shoulder halfway up each pylon: a mid-height perch that is
        # neither route, reachable only by grapple or launch.
        surface("shoulder_%d" % j, -PYLON, PYLON,
                cz - PYLON, cz + PYLON, SHOULDER_Y, 0.5)
    # Deck stringers, so the underside reads as structure from the basin.
    for j, off in enumerate((-DECK_W / 2.0 + 0.4, DECK_W / 2.0 - 0.4)):
        parts.append(_paint(brushkit.block(
            "%s_stringer_%d" % (name, j), (0.5, D - WALL * 2.0, 0.9),
            (off, roomkit.y(D / 2.0), DECK_Y - 1.35)), name, "trim"))

    # --- the two end flights, basin to deck ---------------------------
    for j, (z0, z1, flip) in enumerate(
            ((WALL + 1.0, WALL + 1.0 + RAMP_RUN, False),
             (D - WALL - 1.0 - RAMP_RUN, D - WALL - 1.0, True))):
        roomkit.flight(parts, _paint, name, "ramp_%d" % j,
                       IN_X - 5.0, IN_X, z0, z1, 0.0, DECK_Y, "y", flip)
        # A landing joining the flight's head to the deck edge.
        surface("landing_%d" % j,
                -DECK_W / 2.0, IN_X,
                (z1 - 3.0) if not flip else z0,
                (z1) if not flip else (z0 + 3.0), DECK_Y, 0.5)

    # --- basin cover --------------------------------------------------
    for j, (cx, cz, sx, sz) in enumerate(COVER):
        parts.append(_paint(brushkit.block(
            "%s_cover_%d" % (name, j), (sx, sz, 1.9),
            (cx, roomkit.y(cz), 0.95)), name, "wall"))
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
    cid = "shell_span_basin"
    entry = common.export_glb(obj, "%s/%s.glb" % (OUT, cid), "room",
                              tier="architecture",
                              texture_size=materials.ARCH_SIZE,
                              anchor="entrance", check_flat=False,
                              collision=colliders)
    if probe:
        entry["surface_probe"] = probe

    entry["exit_offset"] = [0.0, DECK_Y, round(D + 2.0, 2)]
    entry["exit_yaw"] = 0.0
    entry["check_anchor"] = [0.0, 0.0, D / 2.0]
    entry["enemy_anchors"] = [[0.0, DECK_Y, D * 0.3], [0.0, DECK_Y, D * 0.7],
                              [0.0, SHOULDER_Y, D * 0.3]]
    entry["bounds"] = [[-W / 2.0, -1.0, 0.0], [W, H + 1.0, D + 2.0]]
    entry["interior"] = [W, H, D]
    entry["total_rise"] = 0.0
    entry["surfaces"] = roomcontract.surfaces_from_stones(
        stones, heights, snames)

    def seg(tag, kind, a, b, mandatory=True):
        return {"name": tag, "kind": kind, "mandatory": bool(mandatory),
                "start": list(a), "end": list(b)}

    # THE MANDATORY ROUTE IS THE BRIDGE, AND IT IS LEVEL. The basin is a
    # complete alternative and is declared optional, which is the honest
    # description: a player who never leaves the deck finishes the room,
    # and a player who drops into the basin also finishes it.
    entry["traversal"] = [
        seg("entry_to_deck", "walk", (0.0, DECK_Y, WALL + 1.0),
            (0.0, DECK_Y, D / 2.0)),
        seg("deck_to_exit", "walk", (0.0, DECK_Y, D / 2.0),
            (0.0, DECK_Y, D - WALL - 1.0)),
        seg("basin_south_to_deck", "walk",
            (IN_X - 2.5, 0.0, WALL + 2.0),
            (IN_X - 2.5, DECK_Y, WALL + RAMP_RUN), False),
        seg("basin_north_to_deck", "walk",
            (IN_X - 2.5, 0.0, D - WALL - 2.0),
            (IN_X - 2.5, DECK_Y, D - WALL - RAMP_RUN), False),
        seg("deck_to_basin", "drop", (2.0, DECK_Y, D / 2.0),
            (6.0, 0.0, D / 2.0), False),
    ]

    entry["volumes"] = [
        roomcontract.volume("pylon_s", "no_build",
                            (0.0, roomkit.y(D * 0.3), (DECK_Y - 0.9) / 2.0),
                            (PYLON, PYLON, DECK_Y - 0.9)),
        roomcontract.volume("arrival", "player_entry",
                            (0.0, roomkit.y(2.2), DECK_Y + 1.0),
                            (DOOR_W, 2.4, 2.0)),
        roomcontract.volume("reward", "objective",
                            (0.0, roomkit.y(D / 2.0), 1.0), (2.4, 2.4, 2.0)),
    ]

    entry["sockets"] = [
        roomcontract.socket("entry", "doorway", (0.0, 0.0, DECK_Y),
                            yaw=180.0, width=DOOR_W, height=DOOR_H,
                            surface_id="deck"),
        roomcontract.socket("exit", "doorway",
                            (0.0, roomkit.y(D + 2.0), DECK_Y), yaw=0.0,
                            width=DOOR_W, height=DOOR_H, surface_id="deck"),
    ]
    for i, sname in enumerate(("deck", "shoulder_0", "shoulder_1",
                               "landing_0", "landing_1")):
        k = snames.index(sname)
        spot = roomcollision.stance_spot(colliders, stones[k], heights[k])
        if spot is None:
            raise AssertionError("%s: '%s' fits nothing" % (cid, sname))
        entry["sockets"].append(roomcontract.socket(
            "high_%d" % i, "enemy_high", (spot[0], spot[1], heights[k] + 0.3),
            surface_id=sname))
    # BESIDE the block, not inside it -- the same defect the yard had,
    # from the same cause. The span is long in z, so the stance steps in
    # x, away from the basin's centre line, which leaves the block
    # between the player and the open middle.
    for i, (cx, cz, sx, sz) in enumerate(COVER):
        sxp, szp = roomkit.cover_stance(cx, cz, sx, sz, "x", 0.0)
        entry["sockets"].append(roomcontract.socket(
            "cover_%d" % i, "cover", (sxp, roomkit.y(szp), 0.3),
            surface_id="basin"))

    # --- offers -------------------------------------------------------
    #
    # THE RAIL IS SLUNG UNDER THE DECK. Basin to basin at about 9 m, so
    # it is a third height and a third route, and it is the line the
    # player only finds by leaving the obvious one.
    #
    # UNDER THE EAST STRINGER, NOT DOWN THE CENTRE LINE. At x = 0 the
    # rail ran through both pylons -- 4 m square, x -2..2, floor to
    # deck -- and the audit measured the ride 1.9911 m inside each of
    # them. There is no vertical way past: the pylons run from the
    # basin floor to the deck soffit with no gap, so the fix is
    # lateral, and 3.1 is where the deck's own stringer is. The beam
    # rides under structure instead of through it, still wholly beneath
    # a deck that is 7 m wide, and clears each pylon by 1.100 m against
    # the 0.325 it needs. A constant offset on purpose: give the
    # control points different x and the Catmull-Rom overshoots
    # sideways between them, and the overshoot is what put the beam
    # past the deck edge in the versions that wove around the pylons.
    rail = [(3.1, 2.5, WALL + 4.0), (3.1, 8.6, 22.0), (3.1, 9.4, 45.0),
            (3.1, 8.6, 68.0), (3.1, 2.5, D - WALL - 4.0)]
    for a, b in zip(rail, rail[1:]):
        run = math.dist(a, b)
        if not 0.5 <= run <= 60.0:
            raise AssertionError("%s: rail segment %.2f m out of bounds"
                                 % (cid, run))
        flat = math.hypot(b[0] - a[0], b[2] - a[2])
        if math.degrees(math.atan2(abs(b[1] - a[1]), flat)) > 75.0:
            raise AssertionError("%s: rail pitch exceeds 75" % cid)
    src = (0.0, 0.5, D / 2.0)
    dst = (0.0, DECK_Y, D * 0.7)
    span = math.dist(src, dst)
    if not 0.5 <= span <= 80.0:
        raise AssertionError("%s: launch pair spans %.2f m" % (cid, span))
    entry["offers"] = [
        {"name": "rail_underdeck", "kind": "rail_route",
         "points": [list(p) for p in rail]},
        {"name": "launch_basin", "kind": "launch_source",
         "position": list(src), "radius": 3.0, "target": "launch_deck"},
        {"name": "launch_deck", "kind": "launch_target",
         "position": list(dst), "radius": 3.5},
    ]
    # Under the deck, so the 4 m of swing room is real and the basin is
    # well inside the 30 m an anchor may stand above.
    for k, cz in enumerate((18.0, 45.0, 72.0)):
        entry["offers"].append({
            "name": "grapple_%d" % k, "kind": "grapple_point",
            "position": [0.0, DECK_Y - 2.6, cz], "radius": 1.5})
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
    common.log("%s: %.0f m span at %.0f m, basin underneath, rail %.1f m"
               % (cid, D, DECK_Y, entry["rail_span"]))
    print("[art] batch040 manifest -> %s" % out)


if __name__ == "__main__":
    main()
