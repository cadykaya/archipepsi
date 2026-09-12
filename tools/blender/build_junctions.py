"""Batch 044 -- the first branching rooms: two junctions and a terminus.

    .tools/blender/blender -b --python tools/blender/build_junctions.py

The post-3AB goal is rooms with choices rather than longer hallways. Three
shells: a three-connection junction, a four-connection junction, and a
side-destination that reads as the end of a line.

## EVERY ROUTE IN ALL THREE IS FLAT, AND THAT IS A MEASUREMENT

`tools/content/run_controller_limits.sh` drives a capsule of Production's
dimensions at a step under Production's gravity and reports what it mounts:

    walking          0.12 m
    jumping          1.50 m
    a ramp           walkable to 46 degrees, which is floor_max_angle

`move_and_slide` has no step-up, so **0.12 m is the whole budget for a
walking route**. A 0.6 m shelf is a jump, not a step, and the span's
0.875 m risers cost sixteen jumps apiece. So none of these rooms puts a
height change on a route: they are single-level, and their areas are told
apart by enclosure, ceiling, fittings and light instead of by elevation.

Raised geometry still exists -- the triad's overlook, the cross's machine
deck -- but it is scenery and perch, never floor a route crosses, exactly
as `shell_span_basin`'s shoulders are.

## THE GROOVE SHOWS THE ROUTES

Every floor is laid as panels around a 0.40 m channel recessed 0.06 m --
inside the 0.12 m budget, so stepping out of one is free. The channel runs
from each doorway to the room's middle, so **the choices are legible from
the floor**: standing in the centre you can see, without a map, that three
or four ways leave this room and where they go. That is the continuous
groove the existing rooms already use as a surface language, doing a
second job.

Each panel is declared as its own `stand` Surface, because the panels are
where a body actually stands and the channel is 0.40 m wide -- narrower
than a player.

## SOCKETS

`entry` and `exit` keep their names and their meaning, so every one of
these rooms still works as an ordinary through-room under today's
two-socket router (`ContentInstantiator.ALIASES` maps them to `end_a` /
`end_b`). The branches are additional, stably named, and a composer that
does not know about them simply does not assign them -- and an unassigned
socket is `SEALED`, which the engine already closes with a slab.

That is the degradation that matters: **these rooms are not a flag day.**

## CLOSURES SEAT ON A COLLAR

`ContentInstantiator._place_closures` builds a slab of the aperture plus
0.6 m, 0.5 m deep, at the socket. So every doorway here carries a collar --
wall all round the opening, at least 0.30 m proud of it on each side and
above -- and 0.25 m of clear floor inside the face, so a closure, a lock or
a return pad seats against something instead of hanging in the hole.

What a socket BECOMES is the runtime's: an ordinary door, a seal, a local
lock, a return device or the Zone exit are placements with their own look.
The shell cannot know which, so it gives them all the same clean seat and
does not pretend to distinguish them in the mesh.
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import roomcollision  # noqa: E402
import roomcontract  # noqa: E402
import roomkit  # noqa: E402
import palette as pal  # noqa: E402

OUT = "batch044/shells"
THEME = common.THEME

WALL = 0.60
DOOR_W, DOOR_H = 2.40, 3.20
#: The floor channel: wide enough to read, shallow enough to step out of.
#: 0.06 m against a measured 0.12 m walk-up budget.
GROOVE_W, GROOVE_D = 0.40, 0.06
#: A closure is the aperture + 0.6 m, so the collar clears it by 0.30 m.
COLLAR = 0.30

_IMAGES = {}
#: ONE material object per role, shared by every block that wears it.
#: Making a fresh material called `floor` for each of a hundred blocks gets
#: Blender's own `.001` suffixes, and §8.4 refuses `floor.001` by name --
#: the suffix is its worked example of a name a pack cannot classify.
_MATERIALS = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("junc_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, name, role, collide=None):
    """Texture role and collision role are two different questions.

    `roomcollision.paint_role` knows four classes -- floor, wall, ceiling,
    trim -- and decides what gets a collider. `accent` is a THEME TEXTURE
    role and not one of them, so a door frame painted in accent still has
    to say whether it is structure. `collide` says which class it is; it
    defaults to the texture role for the four that are both.
    """
    # THE MATERIAL IS NAMED FOR ITS ROLE AND NOTHING ELSE. §8.4 asks an
    # imported surface material to be the exact lowercase role id;
    # `<prefix>_<role>` is the LEGACY form, and the twenty-three shells
    # that use it are declared one by one in
    # `inspect_materials.LEGACY_SHELLS` because they were approved before
    # the convention was. New art does not get to grow that list --
    # `check_theme_roles.py` refused these three until they were renamed,
    # which is the gap-2 gate doing exactly what it was built for.
    if role not in _MATERIALS:
        _MATERIALS[role] = common.make_textured_material(
            role, _image(role), roughness=pal.roughness(THEME))
    common.assign(obj, _MATERIALS[role])
    return roomcollision.paint_role(obj, collide or role)


class Room:
    """A rectangular shell with doorways in any of its four walls.

    The walls sit INSIDE the declared envelope, so every socket lands on an
    outer face and nothing stands proud of the room -- the convention the
    hall, plenum and span use, and the one the yard did not.
    """

    def __init__(self, name, w, d, h):
        self.name = name
        self.w, self.d, self.h = w, d, h
        self.parts = []
        self.stones, self.heights, self.snames = [], [], []
        self.sockets = []
        #: side -> (centre along the wall) for every doorway cut.
        self.doors = {}

    # -- geometry -------------------------------------------------------
    def slab(self, tag, x0, x1, z0, z1, top, thick=0.70, role="floor",
             declare=True):
        stone = roomkit.slab(self.parts, _paint, self.name, tag,
                             x0, x1, z0, z1, top, thick, role)
        if declare:
            self.stones.append(stone)
            self.heights.append(top)
            self.snames.append(tag)
        return stone

    def block(self, tag, size_xyz, centre_xyz, role="wall", collide=None):
        self.parts.append(_paint(brushkit.block(
            "%s_%s" % (self.name, tag), size_xyz, centre_xyz), self.name,
            role, collide))

    def shell(self, doors):
        """Four walls, a roof, and an aperture wherever `doors` says.

        `doors` is `{side: along}` -- the centre of the opening measured
        along that wall, in Godot metres.
        """
        self.doors = dict(doors)
        half_w = self.w / 2.0
        # The roof, and the floor-to-roof walls with their apertures.
        self.block("roof", (self.w, self.d, WALL),
                   (0.0, roomkit.y(self.d / 2.0), self.h + WALL / 2.0),
                   "ceiling")
        for side in ("south", "north", "west", "east"):
            along = doors.get(side)
            if side in ("south", "north"):
                z = WALL / 2.0 if side == "south" else self.d - WALL / 2.0
                span, thick = self.w, WALL
                if along is None:
                    self.block("%s" % side, (span, thick, self.h),
                               (0.0, roomkit.y(z), self.h / 2.0))
                    continue
                for tag, a, b in (("%s_0" % side, -half_w,
                                   along - DOOR_W / 2.0),
                                  ("%s_1" % side, along + DOOR_W / 2.0,
                                   half_w)):
                    self.block(tag, (b - a, thick, self.h),
                               ((a + b) / 2.0, roomkit.y(z), self.h / 2.0))
                self.block("%s_head" % side,
                           (DOOR_W, thick, self.h - DOOR_H),
                           (along, roomkit.y(z),
                            (self.h + DOOR_H) / 2.0))
            else:
                x = (half_w - WALL / 2.0) * (1.0 if side == "east" else -1.0)
                thick = WALL
                if along is None:
                    self.block("%s" % side, (thick, self.d, self.h),
                               (x, roomkit.y(self.d / 2.0), self.h / 2.0))
                    continue
                for tag, a, b in (("%s_0" % side, 0.0,
                                   along - DOOR_W / 2.0),
                                  ("%s_1" % side, along + DOOR_W / 2.0,
                                   self.d)):
                    self.block(tag, (thick, b - a, self.h),
                               (x, roomkit.y((a + b) / 2.0), self.h / 2.0))
                self.block("%s_head" % side,
                           (thick, DOOR_W, self.h - DOOR_H),
                           (x, roomkit.y(along), (self.h + DOOR_H) / 2.0))

    #: How far a threshold reaches INTO the room past the wall's inner
    #: face. Not zero, and the reason is the groove: the channel runs to
    #: every doorway, so a threshold that stopped at the wall would leave
    #: the door opening onto a 0.06 m trough along its own centre line. A
    #: player would step down and back up in the doorway. This covers the
    #: channel's mouth so the door gives onto flat floor, and the groove
    #: emerges just inside -- which still points at the door and is a
    #: better threshold.
    DOOR_REACH = 0.80

    def surrounds(self):
        """An accent frame standing proud of every aperture.

        Two jobs, and the second is why it is 0.30 m wide. Visually it is
        what makes a way out READABLE FROM ACROSS THE ROOM: a flat wall
        with a 2.4 m hole in it reads as a shadow, and the first interior
        view of this room proved it -- from the entry you could not tell
        the east branch existed. Structurally it is the COLLAR: a closure
        is the aperture plus 0.6 m, so a frame that clears the opening by
        0.30 m on each side and above is exactly the seat that slab needs.
        """
        half_w = self.w / 2.0
        for side, along in sorted(self.doors.items()):
            top = DOOR_H + COLLAR
            if side in ("south", "north"):
                z = (WALL + 0.15) if side == "south" else (self.d - WALL - 0.15)
                for tag, cx in (("a", -(DOOR_W + COLLAR) / 2.0),
                                ("b", (DOOR_W + COLLAR) / 2.0)):
                    self.block("frame_%s_%s" % (side, tag),
                               (COLLAR, 0.30, top),
                               (along + cx, roomkit.y(z), top / 2.0),
                               "accent", "wall")
                self.block("frame_%s_head" % side,
                           (DOOR_W + COLLAR * 2.0, 0.30, COLLAR),
                           (along, roomkit.y(z), top - COLLAR / 2.0),
                           "accent", "wall")
            else:
                x = ((half_w - WALL - 0.15) if side == "east"
                     else -(half_w - WALL - 0.15))
                for tag, cz in (("a", -(DOOR_W + COLLAR) / 2.0),
                                ("b", (DOOR_W + COLLAR) / 2.0)):
                    self.block("frame_%s_%s" % (side, tag),
                               (0.30, COLLAR, top),
                               (x, roomkit.y(along + cz), top / 2.0),
                               "accent", "wall")
                self.block("frame_%s_head" % side,
                           (0.30, DOOR_W + COLLAR * 2.0, COLLAR),
                           (x, roomkit.y(along), top - COLLAR / 2.0),
                           "accent", "wall")

    def fill(self, tag, x0, x1, z0, z1):
        """Solid mass, floor to roof, where the room is NOT.

        This is the whole reason these read as junctions rather than as
        halls. A 26 m square with a door in each of three walls is a hall:
        from the entry you are looking ALONG the side wall, and no amount
        of framing makes a hole in it visible. Filling the corners turns
        the square into a cross, so the approach is narrow, the middle
        opens out, and both side arms appear at the moment you arrive --
        which is the moment the choice is made.

        The first interior view of this room was the evidence: the east
        branch was invisible from the door.
        """
        self.block(tag, (x1 - x0, z1 - z0, self.h),
                   ((x0 + x1) / 2.0, roomkit.y((z0 + z1) / 2.0),
                    self.h / 2.0))

    def ceiling_relief(self, beams_z, soffit=1.1, band=3.0):
        """A soffit round the perimeter and beams across the middle.

        One flat lid at 7 m over a 26 m room reads as a warehouse and gives
        the eye nothing to measure the space against. Dropping the edge
        makes the middle the tall part -- which is where the choice is made
        -- and the beams put a rhythm on the walk in.
        """
        half_w = self.w / 2.0
        lid = self.h - soffit
        for tag, x0, x1, z0, z1 in (
                ("soffit_w", -half_w, -half_w + band, 0.0, self.d),
                ("soffit_e", half_w - band, half_w, 0.0, self.d),
                ("soffit_s", -half_w + band, half_w - band, 0.0, band),
                ("soffit_n", -half_w + band, half_w - band,
                 self.d - band, self.d)):
            self.block(tag, (x1 - x0, z1 - z0, soffit),
                       ((x0 + x1) / 2.0, roomkit.y((z0 + z1) / 2.0),
                        lid + soffit / 2.0), "ceiling")
        for j, cz in enumerate(beams_z):
            self.block("beam_%d" % j, (self.w - band * 2.0, 0.7, 0.55),
                       (0.0, roomkit.y(cz), lid + 0.275), "trim", "ceiling")

    def pilasters(self, at_z, depth=0.35, width=0.9):
        """Ribs up the long walls, so the wall has a measure in it."""
        half_w = self.w / 2.0
        for j, cz in enumerate(at_z):
            for side in (-1.0, 1.0):
                self.block("pilaster_%d_%d" % (j, int(side)),
                           (depth, width, self.h),
                           (side * (half_w - WALL - depth / 2.0),
                            roomkit.y(cz), self.h / 2.0), "trim", "wall")

    def thresholds(self):
        """Floor through each wall's thickness, under every aperture.

        The panels stop at the walls' inner faces, which is right for a
        floor and wrong for a threshold -- the lesson the plenum and the
        yard both taught this month. Geometry only; it declares no Surface,
        the same as the hall's and the span's sill tops.
        """
        half_w = self.w / 2.0
        reach = WALL + self.DOOR_REACH
        for side, along in sorted(self.doors.items()):
            if side in ("south", "north"):
                z0, z1 = ((0.0, reach) if side == "south"
                          else (self.d - reach, self.d))
                self.slab("threshold_%s" % side, along - DOOR_W / 2.0,
                          along + DOOR_W / 2.0, z0, z1, 0.0, 1.0,
                          declare=False)
            else:
                x0, x1 = ((half_w - reach, half_w) if side == "east"
                          else (-half_w, -half_w + reach))
                self.slab("threshold_%s" % side, x0, x1,
                          along - DOOR_W / 2.0, along + DOOR_W / 2.0,
                          0.0, 1.0, declare=False)

    def socket_at(self, socket_name, side, along, surface_id):
        """A doorway socket on the OUTER face of its wall."""
        half_w = self.w / 2.0
        if side == "south":
            pos, yaw = (along, 0.0, 0.0), 180.0
        elif side == "north":
            pos, yaw = (along, 0.0, self.d), 0.0
        elif side == "east":
            pos, yaw = (half_w, 0.0, along), 90.0
        else:
            pos, yaw = (-half_w, 0.0, along), 270.0
        self.sockets.append(roomcontract.socket(
            socket_name, "doorway",
            (pos[0], roomkit.y(pos[2]), pos[1]), yaw=yaw,
            width=DOOR_W, height=DOOR_H, surface_id=surface_id))


def _groove_floor(room, spine_x, spine_z, arms):
    """Floor panels around a channel that runs to every doorway.

    `arms` is a list of `("x"|"z", fixed, from, to)` channel runs in Godot
    metres. The panels are whatever rectangle is left, declared one by one.
    """
    half = GROOVE_W / 2.0
    in_x = room.w / 2.0 - WALL
    z0, z1 = WALL, room.d - WALL
    # The channel bed, one slab under the whole footprint, then panels on
    # top of it. Two layers rather than a boolean: every piece stays an
    # axis-aligned box, which is what the collision derivation wants.
    room.slab("bed", -in_x, in_x, z0, z1, -GROOVE_D, 1.0, declare=False)
    return in_x, z0, z1


def triad():
    """`shell_junction_triad` -- three ways out of a sorting floor.

    A transfer room where a line splits. The middle is open and lit and is
    where the choice is made; the west bay is a quiet recess behind a
    parapet, off the flow, and holds whatever the runtime puts here; the
    east overlook is a supervisor's shelf at 2.6 m that is scenery and a
    firing position, never floor.
    """
    r = Room("tri", 26.0, 26.0, 7.0)
    mid_x, mid_z = 0.0, 13.0
    r.shell({"south": mid_x, "north": mid_x, "east": mid_z})
    in_x = r.w / 2.0 - WALL
    z0, z1 = WALL, r.d - WALL
    half = GROOVE_W / 2.0
    #: The plan. A 12 m spine from door to door, a 6.4 m arm east to the
    #: branch, and a bay of the same size opposite it -- so arriving at
    #: the middle opens the room left and right at once.
    spine, arm_z0, arm_z1 = 6.0, 9.5, 16.5

    r.slab("bed", -in_x, in_x, z0, z1, -GROOVE_D, 1.0, declare=False)
    # The spine, split by the groove and by the spur that crosses it.
    r.slab("spine_ws", -spine, -half, z0, mid_z - half, 0.0, 0.20)
    r.slab("spine_wn", -spine, -half, mid_z + half, z1, 0.0, 0.20)
    r.slab("spine_es", half, spine, z0, mid_z - half, 0.0, 0.20)
    r.slab("spine_en", half, spine, mid_z + half, z1, 0.0, 0.20)
    r.slab("arm_east", spine, in_x, arm_z0, arm_z1, 0.0, 0.20)
    r.slab("bay_west", -in_x, -spine, arm_z0, arm_z1, 0.0, 0.20)
    # The groove: a spine from door to door and a spur to each side, both
    # stopping at the arm mouths so the arms are unbroken floor.
    r.slab("spur_e", half, spine, mid_z - half, mid_z + half,
           -GROOVE_D + 0.001, 0.20, declare=False)
    r.slab("spur_w", -spine, -half, mid_z - half, mid_z + half,
           -GROOVE_D + 0.001, 0.20, declare=False)

    # The four corners are mass, and that is what makes this a junction.
    for tag, x0, x1, za, zb in (
            ("fill_sw", -in_x, -spine, z0, arm_z0),
            ("fill_se", spine, in_x, z0, arm_z0),
            ("fill_nw", -in_x, -spine, arm_z1, z1),
            ("fill_ne", spine, in_x, arm_z1, z1)):
        r.fill(tag, x0, x1, za, zb)

    r.ceiling_relief(beams_z=(5.0, 21.0), soffit=1.2, band=3.2)

    # --- the west bay: the quiet end of the room ----------------------
    r.block("bay_bench", (1.6, 4.0, 0.75),
            (-11.4, roomkit.y(13.0), 0.375), "trim", "wall")
    r.block("bay_header", (0.5, 7.0, 1.0),
            (-6.2, roomkit.y(13.0), DOOR_H + 0.9), "trim", "wall")
    for j, cz in enumerate((arm_z0 + 0.4, arm_z1 - 0.4)):
        r.block("bay_post_%d" % j, (0.5, 0.8, 3.7),
                (-6.2, roomkit.y(cz), 1.85), "trim", "wall")

    # --- the east arm: the branch, and it is a room you can see into --
    r.block("arm_header", (0.5, 7.0, 1.0),
            (6.2, roomkit.y(13.0), DOOR_H + 0.9), "trim", "wall")
    for j, cz in enumerate((arm_z0 + 0.4, arm_z1 - 0.4)):
        r.block("arm_post_%d" % j, (0.5, 0.8, 3.7),
                (6.2, roomkit.y(cz), 1.85), "trim", "wall")
    r.block("overlook", (4.0, 2.4, 0.5),
            (10.4, roomkit.y(10.8), 2.35), "trim", "wall")
    for j, cx in enumerate((8.6, 12.2)):
        r.block("overlook_leg_%d" % j, (0.4, 0.4, 2.1),
                (cx, roomkit.y(10.8), 1.05), "trim", "wall")

    # --- the approaches, each with its own tell -----------------------
    for j, side in enumerate((-1.0, 1.0)):
        r.block("gate_post_%d" % j, (0.5, 0.5, 2.6),
                (side * 2.2, roomkit.y(3.0), 1.3), "accent", "wall")
    r.block("north_lintel", (6.0, 0.5, 0.7),
            (0.0, roomkit.y(22.6), DOOR_H + 0.9), "accent", "wall")
    r.block("east_shutter", (0.5, 3.4, 0.8),
            (11.9, roomkit.y(13.0), DOOR_H + 0.5), "accent", "wall")

    r.socket_at("entry", "south", mid_x, "spine_ws")
    r.socket_at("exit", "north", mid_x, "spine_wn")
    r.socket_at("branch_east", "east", mid_z, "arm_east")
    volumes = [
        roomcontract.volume("arrival", "player_entry",
                            (0.0, roomkit.y(3.0), 1.0), (DOOR_W, 2.4, 2.0)),
        # ON THE SORTING FLOOR, not in a corner and not in a doorway. A
        # shell with no enemy_spawn gets its enemies scattered over the
        # largest declared surface, which for this room would be the whole
        # west panel including the doorways.
        roomcontract.volume("fight", "enemy_spawn",
                            (0.0, roomkit.y(13.0), 1.0), (10.0, 8.0, 2.0)),
        # The west bay: whatever the runtime chooses to put here.
        roomcontract.volume("bay", "objective",
                            (-9.6, roomkit.y(13.0), 1.0), (4.4, 5.0, 2.0)),
        roomcontract.volume("overlook", "no_build",
                            (10.4, roomkit.y(10.8), 1.3), (4.0, 2.4, 2.6)),
    ]
    return r, volumes, "medium", ("junction", "branching")


def cross():
    """`shell_junction_cross` -- four ways, around a machine.

    The choice is not visible from one spot on purpose: a plant block fills
    the middle and you walk the ambulatory around it, so the room is
    learned by crossing it rather than read from the door. Each corner bay
    is doing a different job, which is what tells you where you are.
    """
    r = Room("crs", 30.0, 30.0, 8.0)
    mid = 15.0
    r.shell({"south": 0.0, "north": 0.0, "east": mid, "west": mid})
    in_x = r.w / 2.0 - WALL
    z0, z1 = WALL, r.d - WALL
    half = GROOVE_W / 2.0
    #: The plan: a square ambulatory round a plant block, with a 8 m arm
    #: to each of the four doors. The corners are mass, so you never see
    #: all four ways at once -- you learn this room by walking it, which
    #: is the difference between a crossroads and a hall with four doors.
    hub, arm, plant = 9.0, 4.0, 4.0

    r.slab("bed", -in_x, in_x, z0, z1, -GROOVE_D, 1.0, declare=False)
    # The ambulatory: a ring of four panels round the plant.
    r.slab("amb_south", -hub, hub, r.d / 2.0 - hub, mid - plant, 0.0, 0.20)
    r.slab("amb_north", -hub, hub, mid + plant, r.d / 2.0 + hub, 0.0, 0.20)
    r.slab("amb_west", -hub, -plant, mid - plant, mid + plant, 0.0, 0.20)
    r.slab("amb_east", plant, hub, mid - plant, mid + plant, 0.0, 0.20)
    # Four arms, each split by the groove that runs down it to its door.
    for tag, a0, a1 in (("s", z0, r.d / 2.0 - hub),
                        ("n", r.d / 2.0 + hub, z1)):
        r.slab("arm_%s_w" % tag, -arm, -half, a0, a1, 0.0, 0.20)
        r.slab("arm_%s_e" % tag, half, arm, a0, a1, 0.0, 0.20)
    for tag, sign in (("w", -1.0), ("e", 1.0)):
        x0, x1 = ((hub, in_x) if sign > 0 else (-in_x, -hub))
        r.slab("arm_%s_s" % tag, x0, x1, mid - arm, mid - half, 0.0, 0.20)
        r.slab("arm_%s_n" % tag, x0, x1, mid + half, mid + arm, 0.0, 0.20)

    # The corners, and the shoulders beside the north and south arms.
    for tag, x0, x1, za, zb in (
            ("fill_sw", -in_x, -hub, z0, mid - arm),
            ("fill_se", hub, in_x, z0, mid - arm),
            ("fill_nw", -in_x, -hub, mid + arm, z1),
            ("fill_ne", hub, in_x, mid + arm, z1),
            ("fill_s_w", -hub, -arm, z0, r.d / 2.0 - hub),
            ("fill_s_e", arm, hub, z0, r.d / 2.0 - hub),
            ("fill_n_w", -hub, -arm, r.d / 2.0 + hub, z1),
            ("fill_n_e", arm, hub, r.d / 2.0 + hub, z1)):
        r.fill(tag, x0, x1, za, zb)

    r.ceiling_relief(beams_z=(4.0, 26.0), soffit=1.4, band=3.6)

    # --- the plant block: walked around, never over -------------------
    r.block("plant", (plant * 2.0, plant * 2.0, 5.4),
            (0.0, roomkit.y(mid), 2.7))
    for j, (cx, cz) in enumerate(((-plant, mid - plant), (plant, mid - plant),
                                  (-plant, mid + plant), (plant, mid + plant))):
        r.block("plant_stack_%d" % j, (0.8, 0.8, 8.0),
                (cx, roomkit.y(cz), 4.0), "trim", "wall")

    # --- four bays on the ambulatory, four jobs -----------------------
    #
    # ALL OF IT AGAINST THE OUTER WALL. The first version stood the desk
    # in the middle of the south ambulatory and a body walking west to
    # east climbed onto it and stopped -- `run_route_walk.sh` found it,
    # at (-6.51, 1.05, 8.01). The ambulatory is the room's only
    # circulation and furniture does not get to stand in it.
    r.block("desk", (3.0, 0.9, 1.05),                 # S: a control desk
            (-6.4, roomkit.y(6.6), 0.525), "trim", "wall")
    for j, cx in enumerate((5.2, 7.0)):               # S: a pipe bank
        r.block("pipe_%d" % j, (0.6, 0.6, 6.4),
                (cx, roomkit.y(6.5), 3.2), "trim", "wall")
    for j, cx in enumerate((-7.4, -5.0)):             # N: racking
        r.block("rack_%d" % j, (1.8, 0.9, 2.4),
                (cx, roomkit.y(23.4), 1.2), "trim", "wall")
    r.block("sump_lip", (3.6, 3.6, 0.10),             # N: a grating
            (6.6, roomkit.y(21.8), 0.05), "accent", "trim")
    # Headers over the four arm mouths, so each one reads as a way out
    # rather than as a gap.
    for tag, sx, sz, size in (("s", 0.0, r.d / 2.0 - hub, (9.0, 0.5, 1.0)),
                              ("n", 0.0, r.d / 2.0 + hub, (9.0, 0.5, 1.0)),
                              ("w", -hub, mid, (0.5, 9.0, 1.0)),
                              ("e", hub, mid, (0.5, 9.0, 1.0))):
        r.block("arm_header_%s" % tag, size,
                (sx, roomkit.y(sz), DOOR_H + 1.1), "trim", "wall")

    r.socket_at("entry", "south", 0.0, "arm_s_w")
    r.socket_at("exit", "north", 0.0, "arm_n_w")
    r.socket_at("branch_east", "east", mid, "arm_e_s")
    r.socket_at("branch_west", "west", mid, "arm_w_s")
    volumes = [
        roomcontract.volume("arrival", "player_entry",
                            (0.0, roomkit.y(3.0), 1.0), (DOOR_W, 2.4, 2.0)),
        # TWO, one per side of the plant, because a single box that spanned
        # the ambulatory would also cover the machine standing in it.
        roomcontract.volume("fight_west", "enemy_spawn",
                            (-6.5, roomkit.y(mid), 1.0), (4.6, 7.6, 2.0)),
        roomcontract.volume("fight_east", "enemy_spawn",
                            (6.5, roomkit.y(mid), 1.0), (4.6, 7.6, 2.0)),
        roomcontract.volume("north_bay", "objective",
                            (6.4, roomkit.y(21.6), 1.0), (3.6, 3.6, 2.0)),
        roomcontract.volume("plant", "no_build",
                            (0.0, roomkit.y(mid), 2.7),
                            (plant * 2.0, plant * 2.0, 5.4)),
    ]
    return r, volumes, "medium", ("junction", "branching")


def terminus():
    """`shell_bay_terminus` -- a side destination that reads as an end.

    One connection is used and the other two are closed by the composer.
    No special schema: an unassigned socket is `SEALED` and the engine
    already lays a slab over it.

    What makes it read as a dead end is the floor. The channel comes in
    from the entry, opens into a turning circle, and stops -- at a blank
    end wall with a maintenance recess in it. There is nowhere else for
    the groove to go, and you can see that from the door.
    """
    r = Room("bay", 18.0, 22.0, 6.0)
    side_z = 16.0
    r.shell({"south": 0.0, "east": side_z, "west": side_z})
    in_x = r.w / 2.0 - WALL
    z0, z1 = WALL, r.d - WALL
    half = GROOVE_W / 2.0
    #: Narrow in, then it opens, then it stops. The approach is 8 m wide
    #: and the chamber is the full 16.8, so the room announces itself
    #: once -- and the end wall is the only thing in front of you.
    arm, mouth = 4.0, 11.0

    r.slab("bed", -in_x, in_x, z0, z1, -GROOVE_D, 1.0, declare=False)
    r.slab("approach_w", -arm, -half, z0, mouth, 0.0, 0.20)
    r.slab("approach_e", half, arm, z0, mouth, 0.0, 0.20)
    r.slab("chamber_w", -in_x, -half, mouth, z1, 0.0, 0.20)
    r.slab("chamber_e", half, in_x, mouth, z1, 0.0, 0.20)
    for tag, x0, x1 in (("fill_sw", -in_x, -arm), ("fill_se", arm, in_x)):
        r.fill(tag, x0, x1, z0, mouth)

    r.ceiling_relief(beams_z=(5.0, 18.0), soffit=1.0, band=2.8)
    r.block("mouth_header", (9.0, 0.6, 1.0),
            (0.0, roomkit.y(mouth), DOOR_H + 0.9), "trim", "wall")

    # --- the end wall does the talking --------------------------------
    #
    # The groove arrives, opens into the chamber and stops here. A
    # maintenance recess in the end wall, a bench under it and two drums
    # on the floor say the line ENDS rather than continues -- which is
    # what a side destination has to say from its own door.
    r.block("recess_head", (5.6, 0.5, 1.0),
            (0.0, roomkit.y(z1 - 0.25), 4.3), "accent", "wall")
    for j, side in enumerate((-1.0, 1.0)):
        r.block("recess_jamb_%d" % j, (0.5, 0.5, 3.8),
                (side * 3.05, roomkit.y(z1 - 0.25), 1.9), "accent", "wall")
    r.block("end_bench", (5.0, 1.1, 0.8),
            (0.0, roomkit.y(z1 - 1.2), 0.4), "trim", "wall")
    for j, cx in enumerate((-6.6, 6.6)):
        r.block("drum_%d" % j, (1.2, 1.2, 1.4),
                (cx, roomkit.y(19.6), 0.7), "trim", "wall")

    r.socket_at("entry", "south", 0.0, "approach_w")
    r.socket_at("branch_east", "east", side_z, "chamber_e")
    r.socket_at("branch_west", "west", side_z, "chamber_w")
    volumes = [
        roomcontract.volume("arrival", "player_entry",
                            (0.0, roomkit.y(3.0), 1.0), (DOOR_W, 2.4, 2.0)),
        roomcontract.volume("fight", "enemy_spawn",
                            (0.0, roomkit.y(14.5), 1.0), (12.0, 6.0, 2.0)),
        # THE DESTINATION'S USABLE SPACE, and deliberately not a Check.
        # An encounter, an activity, a reward or a local-key objective all
        # fit here; baking one campaign's Check into the mesh would make
        # the room useful once.
        roomcontract.volume("prize", "objective",
                            (0.0, roomkit.y(18.6), 1.0), (6.0, 4.0, 2.2)),
    ]
    return r, volumes, "small", ("destination", "dead_end")


SHELLS = (("shell_junction_triad", triad),
          ("shell_junction_cross", cross),
          ("shell_bay_terminus", terminus))


def main():
    report = {}
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch044",
                       "shells", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    manifest = {}
    if os.path.exists(out):
        with open(out, encoding="utf-8") as handle:
            manifest = json.load(handle)
    for cid, builder in SHELLS:
        common.reset_scene()
        _IMAGES.clear()
        _MATERIALS.clear()
        r, volumes, size_class, tags = builder()
        r.thresholds()
        r.surrounds()

        colliders = roomcollision.build(r.parts, r.name)
        roomcollision.assert_exact(r.name, r.parts, colliders)
        roomcollision.assert_supports(r.name, colliders, r.stones,
                                      r.heights, r.snames)
        roomcollision.assert_standable(r.name, colliders, r.stones,
                                       r.heights, r.snames)
        probe = roomcollision.measure_probe(colliders, r.stones, r.heights,
                                            r.snames)

        obj = common.join(r.parts, r.name)
        common.uv_project_world(obj, materials.ARCH_DENSITY,
                                materials.ARCH_SIZE)
        entry = common.export_glb(obj, "%s/%s.glb" % (OUT, cid), "room",
                                  tier="architecture",
                                  texture_size=materials.ARCH_SIZE,
                                  anchor="entrance", check_flat=False,
                                  collision=colliders)
        if probe:
            entry["surface_probe"] = probe
        entry["exit_offset"] = [0.0, 0.0, round(r.d, 2)]
        entry["exit_yaw"] = 0.0
        entry["check_anchor"] = None
        entry["enemy_anchors"] = []
        entry["bounds"] = [[-r.w / 2.0, -1.0, 0.0],
                           [r.w, r.h + 1.0, r.d]]
        entry["interior"] = [r.w, r.h, r.d]
        entry["total_rise"] = 0.0
        entry["size_class"] = size_class
        entry["shape_tags"] = list(tags)
        entry["surfaces"] = roomcontract.surfaces_from_stones(
            r.stones, r.heights, r.snames)
        entry["traversal"] = []
        entry["volumes"] = volumes
        entry["sockets"] = r.sockets
        entry["size_godot"] = [round(entry["size"][0], 3),
                               round(entry["size"][2], 3),
                               round(entry["size"][1], 3)]
        roomcontract.assert_axis_order(cid, entry["size"], entry["interior"],
                                       entry["size_godot"])
        manifest[cid] = entry
        report[cid] = {
            "size": entry.get("size"),
            "triangles": entry.get("triangles"),
            "surfaces": len(entry["surfaces"]),
            "sockets": len(entry["sockets"]),
            "volumes": len(entry["volumes"]),
            "colliders": len(colliders),
        }
        common.log("%s: %d surface(s), %d socket(s), %d volume(s)"
                   % (cid, len(entry["surfaces"]), len(entry["sockets"]),
                      len(entry["volumes"])))
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
    print("[art] batch044 manifest -> %s" % out)
    print(json.dumps(report, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
