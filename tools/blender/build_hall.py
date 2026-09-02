"""P3 — the first LARGE authored room: a vertical transit hall.

    .tools/blender/blender -b --python tools/blender/build_hall.py

## The spatial job, which is the only thing that fixed the dimensions

The P2 library is eight small enclosed rooms: a 6 m corner, an 8 m
treasure box, a 12 m tower shaft. Useful, and all of one register. The
owner's direction for P3 is the opposite register -- a BIG OPEN AREA with
long sightlines, several elevations, a dominant landmark and room for a
long grind rail -- and a shell that proves Archipepsi can hold one.

So the numbers come from the job rather than from a threshold:

    40 m wide    two galleries of real depth on opposite walls (8 m and
                 6 m), an 18 m machine core between them, and circulation
                 either side of it. Narrower and the core touches a
                 gallery; wider and the cross-room sightline stops being
                 a sightline and becomes a horizon.
    60 m deep    the core has to have open basin BOTH in front of and
                 behind it, or it screens rather than occludes. It is
                 also what lets one launch pair cover meaningful ground
                 while staying inside `LaunchSolver.MAX_RANGE`.
    38 m tall    three occupied layers (0, 11, 21), a 30 m landmark, an
                 exit at 28, and enough air above all of it for a rail to
                 arch over the top. Under about 30 m the rail stops being
                 a route and becomes a handrail.

Interior volume is roughly 91,000 m3 against `shell_tower_gantry`'s
2,160 -- about forty times the largest P2 room. **No new global metre
threshold for LARGE is proposed and none should be read into these.**

## The first read, and why the core is a frame rather than a mass

Entry is a 10 m wide, 5.5 m vestibule: deliberate compression, because
scale is a comparison and the player has to be given the small term
first. It opens on the basin and the hall goes up 38 m at once.

The landmark is a machine armature -- four columns and three collar rings
around a 12 m open shaft. A solid core would have been the easier
sculpture and it would have killed the room: the exit portal is 60 m away
and 28 m up, and the ONE thing the player must be able to see from the
door is where they are going. The armature's central shaft is the
sightline, and it is checked in `main` rather than hoped for -- the line
from the entry eye to the top of the exit portal passes in front of the
first collar, THROUGH the opening of the second, and clear of the third.

The rings also do the occlusion work the brief asks for: from the door
you cannot see the west gallery behind the core, and the room keeps
revealing subspaces as you cross it.

## Circulation is flights, not stones, and not one long wedge

The route is three climbs and two bridges, declared as `walk` segments --
which is what they are, and what the contract's `walk` kind is for.
`rise` and `gap` carry the base-kit reach bounds; `walk` carries the
claim that there is continuous ground, and at `b37fe07` that claim is
PROVEN by a bounded flood over the collision hulls rather than assumed
from a label.

Each climb is therefore a chain of wedge sections rising no more than
`roomkit.FLIGHT_RISE` apiece, and NOT one wedge spanning the whole rise.
A single wedge is a single convex hull whose axis-aligned box tops out
at the high end, so the import-time evidence sees an eleven-metre cliff
wherever the ramp is. Measured before the fix: the box evidence along
the west climb returned 0.00 or 11.00 at every sample and nothing in
between. The sections are collinear and their faces meet, so the room
looks the same; what changes is that the evidence can see the slope.

An earlier note here claimed a climb costs one declared Surface per
metre. That was read off the intermediate rule at `93ddc60` and is
wrong: the declared rectangles bound the search and prove nothing.
Adding a Surface over the west climb changed the flood's node count by
exactly zero.

The route is: vestibule, basin, west gallery (11), north landing (21) by
a ramp along the back wall, the core's own collar ring, the east gantry,
and up to the exit platform (28). Every layer is reachable with NO
movement package installed, which is the condition the offers below are
allowed to exist under.

## Falling

The basin is one continuous floor at y = 0 under the entire hall,
including under the core's shaft. There is no pit and no void: a missed
rail or a missed launch costs height and a walk back, never the level.
Runtime recovery is Production's and nothing here implements any.
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
import roomcollision
import roomkit  # noqa: E402
import traversallaw  # noqa: E402
import roomcontract  # noqa: E402
import palette as pal  # noqa: E402

OUT = "batch039/shells"
THEME = "concrete_facility"

#: The hall, in metres. Godot order for the reader: width, height, depth.
W, H, D = 40.0, 38.0, 60.0
WALL = 0.60
DOOR_W, DOOR_H = 2.40, 3.20

#: The vestibule: the small term in the comparison.
VEST_W, VEST_D, VEST_H = 10.0, 9.0, 5.5

#: The armature. 18 m outer, 12 m open shaft, so the band is 3 m wide and
#: walkable, and the shaft is wide enough to be a sightline rather than a
#: slot.
CORE_Z = 34.0
CORE_OUT, CORE_IN = 18.0, 12.0
COL = 3.0
RING_TOPS = (11.0, 21.0, 29.0)
RING_T = 1.8
CORE_TOP = 30.0

#: Occupied heights.
Y_GALLERY, Y_MID, Y_EXIT, Y_PLINTH = 11.0, 21.0, 28.0, 4.0

_IMAGES = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("hall_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, name, role):
    """Texture a part, and record what that role means for the player."""
    common.assign(obj, common.make_textured_material(
        "%s_%s" % (name, role), _image(role), roughness=pal.roughness(THEME)))
    return roomcollision.paint_role(obj, role)


def _y(z_godot):
    """Godot depth -> Blender y. The one conversion, spelled out."""
    return -z_godot


def _slab(parts, name, tag, x0, x1, z0, z1, top, thick=0.70, role="floor"):
    """A deck by its EDGES in Godot coordinates, because every deck in
    this room was designed as a rectangle on a plan and converting each
    one by hand is how a 0.5 m overlap gets built."""
    parts.append(_paint(brushkit.block(
        "%s_%s" % (name, tag), (x1 - x0, z1 - z0, thick),
        ((x0 + x1) / 2.0, _y((z0 + z1) / 2.0), top - thick / 2.0)),
        name, role))
    return ((( x0 + x1) / 2.0, _y((z0 + z1) / 2.0)), (x1 - x0, z1 - z0))


def build():
    name = "hl"
    parts = []
    stones, heights, snames = [], [], []

    def surface(tag, x0, x1, z0, z1, top, thick=0.70, role="floor"):
        stone = _slab(parts, name, tag, x0, x1, z0, z1, top, thick, role)
        stones.append(stone)
        heights.append(top)
        snames.append(tag)

    # --- the box ------------------------------------------------------
    half = W / 2.0
    surface("basin", -half + WALL, half - WALL, VEST_D, D - WALL, 0.0, 1.0)
    parts.append(_paint(brushkit.block(
        "%s_roof" % name, (W, D, WALL), (0.0, _y(D / 2.0), H + WALL / 2.0)),
        name, "ceiling"))
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "%s_wall_%d" % (name, int(side)), (WALL, D, H),
            (side * (W + WALL) / 2.0, _y(D / 2.0), H / 2.0)), name, "wall"))
    # Front wall, with the vestibule mouth in it.
    for side in (-1.0, 1.0):
        span = (W - VEST_W) / 2.0
        parts.append(_paint(brushkit.block(
            "%s_front_%d" % (name, int(side)), (span, WALL, H),
            (side * (VEST_W + span) / 2.0, _y(WALL / 2.0), H / 2.0)),
            name, "wall"))
    # Back wall, with the exit portal above the platform.
    port_w, port_top = 6.0, 36.0
    for side in (-1.0, 1.0):
        span = (W - port_w) / 2.0
        parts.append(_paint(brushkit.block(
            "%s_back_%d" % (name, int(side)), (span, WALL, H),
            (side * (port_w + span) / 2.0, _y(D - WALL / 2.0), H / 2.0)),
            name, "wall"))
    parts.append(_paint(brushkit.block(
        "%s_back_sill" % name, (port_w, WALL, Y_EXIT),
        (0.0, _y(D - WALL / 2.0), Y_EXIT / 2.0)), name, "wall"))
    parts.append(_paint(brushkit.block(
        "%s_back_head" % name, (port_w, WALL, H - port_top),
        (0.0, _y(D - WALL / 2.0), (H + port_top) / 2.0)), name, "wall"))

    # --- the vestibule ------------------------------------------------
    surface("vestibule", -VEST_W / 2.0, VEST_W / 2.0, 0.0, VEST_D, 0.0, 1.0)
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "%s_vwall_%d" % (name, int(side)), (WALL, VEST_D, VEST_H),
            (side * (VEST_W + WALL) / 2.0, _y(VEST_D / 2.0), VEST_H / 2.0)),
            name, "wall"))
    parts.append(_paint(brushkit.block(
        "%s_vceil" % name, (VEST_W + WALL * 2, VEST_D, WALL),
        (0.0, _y(VEST_D / 2.0), VEST_H + WALL / 2.0)), name, "ceiling"))
    parts.append(_paint(brushkit.block(
        "%s_vlip" % name, (VEST_W + 1.2, 0.5, 0.5),
        (0.0, _y(VEST_D), VEST_H + 0.25)), name, "trim"))

    # --- the armature -------------------------------------------------
    co = CORE_OUT / 2.0
    ci = CORE_IN / 2.0
    # THE COLUMNS STOOD IN THE WALKABLE BAND. At 4.0 m square on
    # (+/-7, CORE_Z +/-7) each one spanned x 5..9 against a collar band
    # of x 6..9 -- so it filled the band's full width at all four
    # corners and the collar was four disconnected arcs, not a ring.
    # `ring_n_to_ring_e` is the mandatory route across one of those
    # corners, and Production's capsule found its start standing inside
    # a column (measured here too: a solid from y=0 to y=30 at the
    # declared start).
    #
    # They move INSIDE the shaft, to its corners, and shrink to 3.0. The
    # band is then clear all the way round, the columns still frame the
    # opening, and the centre stays clear for the entry sightline --
    # which `_assert_sightline` re-checks rather than assumes.
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            cx, cz = sx * 4.5, CORE_Z + sz * 4.0
            parts.append(_paint(brushkit.block(
                "%s_col_%d_%d" % (name, int(sx), int(sz)),
                (COL, COL, CORE_TOP), (cx, _y(cz), CORE_TOP / 2.0)),
                name, "wall"))
    for i, top in enumerate(RING_TOPS):
        walk = abs(top - Y_MID) < 0.01
        for tag, x0, x1, z0, z1 in (
                ("w", -co, -ci, CORE_Z - co, CORE_Z + co),
                ("e", ci, co, CORE_Z - co, CORE_Z + co),
                ("s", -ci, ci, CORE_Z - co, CORE_Z - ci),
                ("n", -ci, ci, CORE_Z + ci, CORE_Z + co)):
            band = "ring_%s" % tag
            if walk:
                surface(band, x0, x1, z0, z1, top, RING_T)
            else:
                _slab(parts, name, "r%d%s" % (i, tag), x0, x1, z0, z1,
                      top, RING_T, "trim" if i == 2 else "wall")

    # --- west gallery, and the ramp to it -----------------------------
    surface("west_gallery", -half + WALL, -12.0, 32.0, 52.0, Y_GALLERY)
    # NOT flipped. The west gallery is at z 32..52, so the climb's HIGH
    # end belongs at z=32. It was built flipped -- high at z=14, rising
    # away from the deck it serves -- and neither the P3 build gates nor
    # the owner's form review could see it, because a backwards ramp is
    # a perfectly ordinary-looking ramp. `traversallaw` saw it in one
    # run: the box evidence descended from 11.00 to 0.85 as z increased.
    roomkit.flight(parts, _paint, name, "ramp1", -half + WALL, -13.0,
                   14.0, 32.0, 0.0, Y_GALLERY, "y", False)
    # --- back-wall ramp to the north landing --------------------------
    roomkit.flight(parts, _paint, name, "ramp2", -16.0, -2.0, 52.0, 58.0,
                   Y_GALLERY, Y_MID, "x", False)
    for j, cx in enumerate((-13.0, -5.0)):
        parts.append(_paint(brushkit.block(
            "%s_r2leg_%d" % (name, j), (1.0, 1.0, Y_GALLERY),
            (cx, _y(55.0), Y_GALLERY / 2.0)), name, "wall"))
    surface("north_landing", -2.0, 12.0, 48.0, 56.0, Y_MID)
    surface("bridge_n", 2.0, 6.0, 43.0, 48.0, Y_MID)

    # --- east gantry, its bridge, and the ramp out --------------------
    surface("east_gantry", 13.0, 19.0, 16.0, 38.0, Y_MID, 0.5)
    surface("bridge_e", 9.0, 13.0, 30.0, 34.0, Y_MID)
    # Also not flipped, and for the same reason: the gantry it leaves is
    # at z 16..38 and the exit platform it reaches is at z 54, so the low
    # end belongs at z=38.
    roomkit.flight(parts, _paint, name, "ramp3", 13.0, 19.0, 38.0, 54.0,
                   Y_MID, Y_EXIT, "y", False)
    for j, cz in enumerate((22.0, 32.0)):
        parts.append(_paint(brushkit.block(
            "%s_gleg_%d" % (name, j), (0.9, 0.9, Y_MID),
            (18.0, _y(cz), Y_MID / 2.0)), name, "wall"))

    # --- the exit platform --------------------------------------------
    surface("exit_platform", -half + WALL, half - WALL, 54.0, D - WALL,
            Y_EXIT)
    parts.append(_paint(brushkit.block(
        "%s_exitnose" % name, (W - WALL * 2, 0.4, 0.5),
        (0.0, _y(54.0), Y_EXIT - 0.25)), name, "trim"))

    # --- basin cover, so the lower floor is a fight and not a field ---
    surface("plinth_west", -7.0, -1.0, 13.0, 19.0, Y_PLINTH)
    surface("plinth_east", 7.0, 13.0, 45.0, 51.0, Y_PLINTH)

    return name, parts, stones, heights, snames


def _rail_points():
    """One route, twice around the armature, entry level to the exit.

    Bounded by `RailPath`: every segment 0.5-60 m, no pitch past 75
    degrees, at least two points. Asserted below rather than trusted.
    """
    return [
        (-15.0, 2.0, 12.0), (-17.0, 5.0, 26.0), (-13.0, 9.0, 40.0),
        (-2.0, 13.0, 49.0), (10.0, 17.0, 45.0), (17.0, 21.0, 33.0),
        (13.0, 25.0, 21.0), (2.0, 28.0, 17.0), (-9.0, 30.0, 25.0),
        (-6.0, 31.0, 45.0), (0.0, 31.5, 56.0),
    ]


def _assert_rail(points):
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        run = math.dist(a, b)
        if not 0.5 <= run <= 60.0:
            raise AssertionError(
                "rail segment %d is %.2f m; RailPath takes 0.5-60.0" % (i, run))
        flat = math.hypot(b[0] - a[0], b[2] - a[2])
        pitch = 90.0 if flat < 1e-6 else abs(
            math.degrees(math.atan2(b[1] - a[1], flat)))
        if pitch > 75.0:
            raise AssertionError(
                "rail segment %d pitches %.1f deg; RailPath tops out at 75"
                % (i, pitch))
    return len(points)


def _assert_sightline(colliders, eye, look, who):
    """The destination really is visible from the door.

    The whole armature decision rests on this: a solid core would have
    hidden the exit, and "you can see through it" is exactly the kind of
    claim that is true on the drawing and false in the mesh. So it is
    measured, against the collider boxes, by walking the segment.

    Conservative on purpose -- a wedge's box is bigger than the wedge, so
    this can only report a blockage that is not there, never miss one.
    """
    boxes = [roomcollision._world_box(c) for c in colliders]
    steps = 400
    for i in range(steps + 1):
        t = i / float(steps)
        p = tuple(eye[k] + (look[k] - eye[k]) * t for k in range(3))
        for lo, hi in boxes:
            if all(lo[k] - 1e-4 <= p[k] <= hi[k] + 1e-4 for k in range(3)):
                raise AssertionError(
                    "%s: the sightline from the entry to %s is blocked at "
                    "(%.1f, %.1f, %.1f) -- the exit is not legible from the "
                    "door" % (who, look, p[0], p[1], p[2]))
    return math.dist(eye, look)


def main():
    common.reset_scene()
    name, parts, stones, heights, snames = build()

    colliders = roomcollision.build(parts, name)
    roomcollision.assert_exact(name, parts, colliders)
    roomcollision.assert_supports(name, colliders, stones, heights, snames)
    roomcollision.assert_standable(name, colliders, stones, heights, snames)
    probe = roomcollision.measure_probe(colliders, stones, heights, snames)

    # THE FIRST READ. Blender coordinates: eye at the vestibule mouth,
    # target the top of the exit portal 60 m away and 36 m up.
    entry_eye = (0.0, _y(4.0), 1.6)
    portal_top = (0.0, _y(D - WALL), 35.0)
    reach = _assert_sightline(colliders, entry_eye, portal_top, name)
    common.log("shell_hall_transit: exit portal legible from the door "
               "across %.1f m, through the armature shaft" % reach)

    obj = common.join(parts, name)
    common.uv_project_world(obj, materials.ARCH_DENSITY, materials.ARCH_SIZE)
    cid = "shell_hall_transit"
    entry = common.export_glb(obj, "%s/%s.glb" % (OUT, cid), "room",
                              tier="architecture",
                              texture_size=materials.ARCH_SIZE,
                              anchor="entrance", check_flat=False,
                              collision=colliders)
    if probe:
        entry["surface_probe"] = probe
        for f in probe:
            common.log("%s: surface '%s' declared %.2f measures %.2f at "
                       "%d of %d%s" % (cid, f["surface"], f["declared"],
                                       f["measured"], f["samples"], f["of"],
                                       "  (grazing)" if f.get("grazing")
                                       else ""))

    entry["exit_offset"] = [0.0, Y_EXIT, round(D + 2.0, 2)]
    entry["exit_yaw"] = 0.0
    entry["check_anchor"] = [0.0, Y_MID, 52.0]
    entry["enemy_anchors"] = [[-16.0, Y_GALLERY, 42.0], [16.0, Y_MID, 27.0],
                              [0.0, Y_MID, 41.5], [5.0, Y_MID, 52.0]]
    entry["bounds"] = [[-W / 2.0, -1.0, 0.0], [W, H + 1.0, D + 2.0]]
    entry["interior"] = [W, H, D]
    entry["total_rise"] = Y_EXIT

    entry["surfaces"] = roomcontract.surfaces_from_stones(
        stones, heights, snames)

    def seg(tag, kind, a, b, mandatory=True):
        return {"name": tag, "kind": kind, "mandatory": mandatory,
                "start": roomcontract.godot(a[0], _y(a[2]), a[1]),
                "end": roomcontract.godot(b[0], _y(b[2]), b[1])}

    # The mandatory route, as WALK: every link is continuous ground -- a
    # ramp, a bridge, or a shared edge -- so none of them is a jump and
    # none needs the base-kit reach bound that `rise` and `gap` carry.
    entry["traversal"] = [
        seg("vestibule_to_basin", "walk", (0, 0, 8.5), (0, 0, 9.5)),
        # Both ends moved off the slope and onto flat deck: the old
        # start sat one metre up the flight, where a body standing on
        # one wedge section overlaps the next.
        seg("basin_to_gallery", "walk", (-16.5, 0, 12.0),
            (-16.0, Y_GALLERY, 35.0)),
        # `ramp2` climbs along x from x=-16, so it is already 1.4 m
        # above the gallery by x=-14: the gallery meets it only at its
        # WEST END. The old start left the gallery before reaching the
        # ramp and crossed the void between them, and the old end sat on
        # the ramp's last section under the landing's lip -- which is
        # the y=20.29 arrival Production measured.
        seg("gallery_to_landing", "walk", (-15.5, Y_GALLERY, 51.0),
            (0.0, Y_MID, 52.0)),
        seg("landing_to_bridge_n", "walk", (4, Y_MID, 49.0),
            (4, Y_MID, 47.0)),
        seg("bridge_n_to_ring_n", "walk", (4, Y_MID, 44.0),
            (4, Y_MID, 42.0)),
        # Was declared inside the north-east column. Now band centre to
        # band centre, with the columns moved clear.
        seg("ring_n_to_ring_e", "walk", (0.0, Y_MID, 41.5),
            (7.5, Y_MID, 34.0)),
        seg("ring_e_to_bridge_e", "walk", (8.0, Y_MID, 32.0),
            (10.0, Y_MID, 32.0)),
        seg("bridge_e_to_gantry", "walk", (12.0, Y_MID, 32.0),
            (14.0, Y_MID, 32.0)),
        # Ends ON the exit platform (z 54..59.4) rather than 1 m short
        # of it on the flight's last section.
        seg("gantry_to_exit", "walk", (16.0, Y_MID, 34.0),
            (16.0, Y_EXIT, 56.0)),
        seg("ring_n_to_ring_w", "walk", (-5.0, Y_MID, 41.0),
            (-7.5, Y_MID, 39.0), False),
        seg("ring_w_to_ring_s", "walk", (-7.5, Y_MID, 29.0),
            (-5.0, Y_MID, 27.0), False),
        # THE TWO PLINTH SEGMENTS ARE GONE, and removing them is the
        # truthful repair rather than a retreat. Both ended 0.5 m OUTSIDE
        # the plinth they named, in air -- but moving them onto the
        # plinth would not have saved them, because a plinth is 4.00 m
        # tall and the base kit steps 1.00 m and jumps `max_safe_gap`,
        # which at a 4 m rise is zero. There is no honest kind for a
        # 4 m step up: it is not a `rise`, and calling it a `gap` claims
        # a jump nobody can make.
        #
        # The plinths stay declared `stand` Surfaces, which is a
        # different claim and a true one -- something can stand up
        # there, arriving by launch, by grapple, or by being placed. A
        # Surface has never promised base-kit reachability, and the
        # traversal list is where that promise would have lived.
    ]

    entry["volumes"] = [
        roomcontract.volume("core", "no_build",
                            (0.0, _y(CORE_Z), CORE_TOP / 2.0),
                            (CORE_OUT, CORE_OUT, CORE_TOP)),
        roomcontract.volume("arrival", "player_entry",
                            (0.0, _y(2.2), 1.0), (DOOR_W, 2.4, 2.0)),
        roomcontract.volume("reward", "objective",
                            (0.0, _y(52.0), Y_MID + 1.0), (2.4, 2.4, 2.0)),
    ]

    entry["sockets"] = [
        roomcontract.socket("entry", "doorway", (0.0, 0.0, 0.0), yaw=180.0,
                            width=DOOR_W, height=DOOR_H,
                            surface_id="vestibule"),
        roomcontract.socket("exit", "doorway", (0.0, _y(D + 2.0), Y_EXIT),
                            yaw=0.0, width=DOOR_W, height=DOOR_H,
                            surface_id="exit_platform"),
    ]
    for i, sname in enumerate(("west_gallery", "east_gantry", "ring_n",
                               "north_landing", "exit_platform")):
        k = snames.index(sname)
        spot = roomcollision.stance_spot(colliders, stones[k], heights[k])
        if spot is None:
            raise AssertionError("%s: '%s' fits nothing" % (cid, sname))
        entry["sockets"].append(roomcontract.socket(
            "high_%d" % i, "enemy_high", (spot[0], spot[1], heights[k] + 0.3),
            surface_id=sname))
    for i, (sname, cx, cz) in enumerate((("basin", -4.0, 21.5),
                                         ("basin", 10.0, 42.5),
                                         ("basin", -9.5, 34.0))):
        k = snames.index(sname)
        entry["sockets"].append(roomcontract.socket(
            "cover_%d" % i, "cover", (cx, _y(cz), heights[k] + 0.3),
            surface_id=sname))

    # --- offers (P3.0, af620d8) ---------------------------------------
    #
    # OFFER_KINDS is CLOSED to these three. `grapple_anchor`,
    # `platform_route` and `wind_column` are named in Production's own
    # comment as the next arrivals through this same field, so no grammar
    # is invented for them here -- the architecture that would host them
    # is described in the review package instead.
    rail = _rail_points()
    _assert_rail(rail)
    src = (12.0, 0.0, 18.0)
    dst = (16.0, Y_MID, 30.0)
    span = math.dist(src, dst)
    if not 0.5 <= span <= 80.0:
        raise AssertionError("launch pair spans %.2f m; the solver takes "
                             "0.5-80.0" % span)
    entry["offers"] = [
        {"name": "rail_helix", "kind": "rail_route",
         "points": [roomcontract.godot(p[0], _y(p[2]), p[1]) for p in rail]},
        {"name": "launch_basin", "kind": "launch_source",
         "position": roomcontract.godot(src[0], _y(src[2]), src[1]),
         "radius": 3.0, "target": "launch_gantry"},
        {"name": "launch_gantry", "kind": "launch_target",
         "position": roomcontract.godot(dst[0], _y(dst[2]), dst[1]),
         "radius": 3.5},
    ]
    entry["rail_span"] = round(sum(
        math.dist(rail[i], rail[i + 1]) for i in range(len(rail) - 1)), 2)
    entry["launch_span"] = round(span, 2)

    # THE LAW, MIRRORED, AS A GATE. `ShellValidator` floods collision
    # hulls to prove a `walk`, and this runs the same flood over the
    # boxes the build just placed. It reproduced all three of the
    # findings Production reported at `b37fe07` before a line was
    # changed, which is the only reason it is trusted enough to stop a
    # build. It is the WEAKER of Production's two evidences -- `RoomAudit`
    # floods with a real capsule and remains the authority.
    traversallaw.assert_declared(colliders, entry, cid,
                                 roomcollision._world_box)

    entry["size_godot"] = [round(entry["size"][0], 3),
                           round(entry["size"][2], 3),
                           round(entry["size"][1], 3)]
    roomcontract.assert_axis_order(cid, entry["size"], entry["interior"],
                                   entry["size_godot"])

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch039",
                       "shells", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump({cid: entry}, handle, indent=2, sort_keys=True)
    print("[art] batch039 manifest -> %s" % out)


if __name__ == "__main__":
    main()
