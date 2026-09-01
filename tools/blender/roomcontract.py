"""Derive P1 room-contract metadata from the variables that built the room.

    tools/blender/roomcontract.py

Production landed the room contract at `99379e5` ("A valid room means the
same thing whoever produced it"). An authored shell now has to answer the
same questions a procedural one always did: where the floor is, what the
player does to cross it, and what nothing may occupy.

Every one of those answers is already a local variable in the Blender build
script that placed the geometry. This module is the translation layer, and
it exists so the translation happens ONCE rather than once per builder --
in particular the axis conversion, which is the single most dangerous line
in the retrofit.

WHAT THIS IS NOT. It does not measure geometry and it does not decide
whether a room is valid. `room_audit.gd` fires real probes at the
instantiated scene and is the only physical authority. This module produces
a CLAIM; Godot vetoes it.
"""
from __future__ import annotations

import json
import os

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(os.path.dirname(_HERE))
with open(os.path.join(_REPO, "assets", "art_budgets.json"),
          encoding="utf-8") as _fh:
    _DIM = json.load(_fh)["dimensions"]

#: `Surface._you_can_actually_stand_on_it` refuses an extent narrower than
#: the player's own capsule. Read from the same engine truth the schema
#: reads, so the two cannot hold different views of how wide a player is.
MIN_SURFACE_SPAN = _DIM["player_radius"] * 2.0

#: `RoomAudit.HEADROOM` = PLAYER_HEIGHT + 0.6. Used only by the preflight
#: PREDICTION, never to decide what to declare.
HEADROOM = _DIM["player_height"] + 0.6


def godot(x, y, z):
    """Blender (x, y, z) -> Godot (x, z, -y). THE conversion, once.

    Blender is Z-up and the shells are built in it; Godot is Y-up and -Z
    forward. The rooms are authored running along Blender -Y, which is
    Godot +Z, so a room's depth is a NEGATED Blender coordinate.

    This is the axis trap the P2 preparation measured, and it has a second
    face that is easier to trip over than this function: the art manifests
    carry THREE different orders.

        size      Blender  [outer_width, LENGTH, outer_height]
        interior  Godot    [width, HEIGHT, length]
        bounds    Godot    [[min_x, min_y, min_z], [size_x, size_y, size_z]]

    `size` comes from Blender's bounding box and is the one a converter
    reaches for by reflex. Feeding it verbatim into a Godot Vector3 sets
    `shell_tower_gantry`'s height to 14.6 m -- its LENGTH -- instead of
    20.5 m. Seven of the eight shells have square footprints and would hide
    it. `assert_axis_order` below is the guard.
    """
    # `+ 0.0` normalises -0.0, which is equal to 0.0 but serialises as
    # "-0.0" and makes a byte-comparison diff look like a change.
    return [round(float(x), 3) + 0.0, round(float(z), 3) + 0.0,
            round(-float(y), 3) + 0.0]


def assert_axis_order(name, size, interior, size_godot):
    """Refuse a manifest whose axis orders have been mixed up.

    Stated as INVARIANTS rather than a tolerance, because the first
    version of this used "they must agree within the wall thickness" and
    `shell_treasure_coffer` failed it honestly: its coffered ceiling
    pocket puts the outer height 1.8 m above the interior, which is the
    shell being itself rather than an axis error.

    What is actually true of every shell, whatever it is shaped like:

        size      Blender  [outer_width, LENGTH, outer_height]
        interior  Godot    [width, HEIGHT, length]
        size_godot         [outer_width, outer_height, LENGTH]

    So the outer box must CONTAIN the interior on the matching axis, and
    the Godot-ordered height must come from `size[2]` and never `size[1]`.
    """
    if size[2] < interior[1] - 0.01:
        raise AssertionError(
            "%s: outer height size[2]=%.2f is less than the interior "
            "height interior[1]=%.2f; the room does not fit in its own "
            "envelope, or the axes are crossed" % (name, size[2], interior[1]))
    if size[1] < interior[2] - 0.01:
        raise AssertionError(
            "%s: outer length size[1]=%.2f is less than the interior "
            "length interior[2]=%.2f" % (name, size[1], interior[2]))
    want = [round(size[0], 3), round(size[2], 3), round(size[1], 3)]
    if [round(v, 3) for v in size_godot] != want:
        raise AssertionError(
            "%s: size_godot is %s but the Godot order of `size` is %s; a "
            "raw Blender `size` array has been used where a Vector3 was "
            "wanted" % (name, size_godot, want))


def surface(name, centre_xy, extent_xy, top_y):
    """One `Surface`: a named patch of floor, by its TOP FACE.

    `centre_xy` and `extent_xy` are Blender (x, y) -- exactly the shape
    `routecheck` already consumes as a "stone" -- and `top_y` is the
    walkable height in Godot metres. The schema takes two extent numbers
    and not three on purpose: a top face has no thickness.
    """
    ex, ey = float(extent_xy[0]), float(extent_xy[1])
    if ex < MIN_SURFACE_SPAN or ey < MIN_SURFACE_SPAN:
        raise AssertionError(
            "%s: surface %.2f x %.2f m is narrower than the player's own "
            "%.2f m capsule; the schema refuses it and it would be a ledge "
            "nobody can stand on" % (name, ex, ey, MIN_SURFACE_SPAN))
    return {
        "name": name,
        "center": godot(centre_xy[0], centre_xy[1], top_y),
        # extent is (x, z) in GODOT terms. Blender's y-extent is Godot's
        # z-extent, and depth is negated but an EXTENT has no sign.
        "extent": [round(ex, 3), round(ey, 3)],
    }


def surfaces_from_stones(stones, heights, names):
    """The tower case: `routecheck`'s own ordered stone list, as Surfaces.

    `stones` is `[((x, y), (w, d)), ...]` in ROUTE ORDER -- the exact
    variable `routecheck.assert_reachable` already validated against
    `max_safe_gap`. It was computed, used, and thrown away; P1 is what
    finally has a use for it.
    """
    if not (len(stones) == len(heights) == len(names)):
        raise AssertionError("stones/heights/names disagree: %d/%d/%d"
                             % (len(stones), len(heights), len(names)))
    return [surface(n, c, e, y)
            for (c, e), y, n in zip(stones, heights, names)]


def _closest_pair(ac, ae, bc, be):
    """The take-off and landing points between two footprints, per axis.

    Matches `routecheck.jump_distance` exactly, which is the point: that
    function is what already validated these routes, and a segment whose
    endpoints imply a different distance from the one that was checked is
    a segment describing a jump nobody measured.

    Overlapping on an axis means the crossing is a STEP there, so both
    points sit in the middle of the overlap and the distance is zero.
    Separated means each point sits on its own near edge.
    """
    out = []
    for i in (0, 1):
        half = (ae[i] + be[i]) / 2.0
        delta = bc[i] - ac[i]
        if abs(delta) <= half:
            lo = max(ac[i] - ae[i] / 2.0, bc[i] - be[i] / 2.0)
            hi = min(ac[i] + ae[i] / 2.0, bc[i] + be[i] / 2.0)
            mid = (lo + hi) / 2.0
            out.append((mid, mid))
        else:
            sign = 1.0 if delta > 0 else -1.0
            out.append((ac[i] + sign * ae[i] / 2.0,
                        bc[i] - sign * be[i] / 2.0))
    return out


def traversal_from_stones(stones, heights, names, step, mandatory=True):
    """Consecutive stones as `TraversalSegment`s, in the contract's shape.

    Endpoints are the EDGE points `routecheck.jump_distance` measures
    between, not the surface centres. The first version of this used
    centres and the preflight caught it immediately: a spiral's last
    platform to its deck came out as a 6.59 m "jump" against a 2.60 m
    base-kit reach, when the two footprints actually overlap and the
    crossing is a step. `ShellValidator` measures marker to marker, so a
    centre-to-centre segment would have declared an impossible route for
    every tower.

    `kind` is derived from the rise, not asserted. Nothing here invents a
    `gap`: the tower routes deliberately overlap -- which is why
    `routecheck` was called with `require_gap=False` -- and calling an
    overlapping step a jump would be the contract lying in the direction
    that matters most.
    """
    out = []
    for i in range(len(stones) - 1):
        (ac, ae) = stones[i]
        (bc, be) = stones[i + 1]
        (ax, bx), (ay, by) = _closest_pair(ac, ae, bc, be)
        rise = heights[i + 1] - heights[i]
        if rise > 0.01:
            kind = "rise"
        elif rise < -0.01:
            kind = "drop"
        else:
            kind = "walk"
        out.append({
            "name": "%s_to_%s" % (names[i], names[i + 1]),
            "kind": kind,
            "mandatory": bool(mandatory),
            "start": godot(ax, ay, heights[i]),
            "end": godot(bx, by, heights[i + 1]),
        })
    return out


def volume(name, kind, centre_xyz, size_xyz):
    """One `Volume`. `no_build` is the authored equivalent of `reserved`."""
    return {
        "name": name,
        "kind": kind,
        "center": godot(centre_xyz[0], centre_xyz[1], centre_xyz[2]),
        # A SIZE is not a position: it is never negated, and its Blender
        # y-extent becomes its Godot z-extent.
        "size": [round(float(size_xyz[0]), 3), round(float(size_xyz[2]), 3),
                 round(float(size_xyz[1]), 3)],
    }


def socket(name, kind, position_xyz, yaw=0.0, width=0.0, height=0.0,
           surface_id=""):
    """One `Socket`, in Godot coordinates."""
    out = {
        "name": name,
        "kind": kind,
        "position": godot(position_xyz[0], position_xyz[1], position_xyz[2]),
        "yaw": round(float(yaw), 3),
    }
    if width:
        out["width"] = round(float(width), 3)
    if height:
        out["height"] = round(float(height), 3)
    if surface_id:
        out["surface_id"] = surface_id
    return out
