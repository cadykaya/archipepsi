"""Batch 019 -- room shells, the last two families: treasure rooms and corners.

    .tools/blender/blender -b --python tools/blender/build_rooms.py

These two finish §7. They are also the two with the least room to move, and
that is the interesting part: `TreasureRoomChamber` has **no dimensional
parameters at all** -- `side` 8.0 and `height` 4.5 are literals in
`treasure_room()` -- and `corner()` takes one argument, `turn`, which is +1
or -1. Nothing here can differ by being bigger.

## Treasure rooms: three answers to WHY THE REWARD IS HERE

> Small safe reward room. Exactly one reward, never enemies.

`reward_position` is `Vector3(0, 1.0, side / 2)` -- the centre of the room,
on a two-step plinth. That is the engine's, so all three shells put the
reward in exactly the same place and differ in the room AROUND it. With no
size to vary and no enemies to place, what is left is the story the room
tells about the thing standing in the middle of it:

| Shell | The room says |
| --- | --- |
| `shell_treasure_vault` | *this was protected* -- a strongroom: heavy frames on both doors, a curb ring around the plinth, a coffered ceiling |
| `shell_treasure_cache` | *this was stored* -- racking on three walls and empties on the shelves. The plinth reads as the one pallet nobody took |
| `shell_treasure_coffer` | *this was displayed* -- the ceiling steps up into a closed pocket over the plinth, so the reward stands under the deepest part of the one warm light in the building |

The pocket is **closed**. A light well open to the sky in a windowless
facility would be a hole, and `treasure_room()` roofs itself deliberately.

## Corners: two, and they are mirrors on purpose

`corner()` produces a left turn and a right turn and nothing else. Two
mirrored shells is the honest answer rather than a thin one: a player who
learns to read one turn should read the other without relearning it.

Which of `turn` +1 and -1 is "left" is derived in `shell_corner_left`'s
docstring rather than guessed. The first version of this file had the two
names swapped, and the thing that caught it was the review render
disagreeing with its own caption -- so the fix was the NAME, not the
camera, which is the opposite of where the search started.

### What these do NOT copy

`corner()` marks its turn with a stripe in `ThemeMaterials.hazard_mat` --
hazard orange, used as a navigation cue. The owner's Batch 010 ruling is
that **orange must remain warning / hazard language**, and a turn is not a
warning. These corners mark the turn with **form** instead: the inner
corner is chamfered, the skirting carries around it, and a deep reveal on
the exit jamb throws the opening's shadow. No hazard material appears.

That is interface requirement 20, and it is surfaced rather than decided:
if the engine keeps its stripe, a chamber will contradict the asset
standing in it.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"
OUT = "batch019/shells"

DIM = common.DIM
WALL = DIM["wall_thickness"]                 # 0.40
DOOR_W = DIM["door_width"]                   # 2.40
DOOR_H = DIM["door_height"]                  # 3.20
CORRIDOR_H = DIM["corridor_height"]          # 3.60
PROP = DIM["prop_footprint"]                 # 1.40

T_SIDE, T_HEIGHT = 8.0, 4.5                  # treasure_room()'s literals
C_SIDE = 6.0                                 # corner()'s literal

_IMAGES = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("room_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, name, role):
    common.assign(obj, common.make_textured_material(
        "%s_%s" % (name, role), _image(role), roughness=pal.roughness(THEME)))
    return obj


def _door_wall(name, tag, axis, at, span, height):
    """One wall with a centred DOOR_W x DOOR_H opening.

    `axis` is "y" for a wall across the run (front/back) or "x" for a side
    wall. `at` is that wall's plane, `span` the wall's length.
    """
    jamb = (span - DOOR_W) / 2.0
    parts = []
    for side in (-1.0, 1.0):
        off = side * (DOOR_W + jamb) / 2.0
        size = (jamb, WALL, height) if axis == "y" else (WALL, jamb, height)
        pos = ((off, at, height / 2.0) if axis == "y"
               else (at, off, height / 2.0))
        parts.append(_paint(brushkit.block(
            "%s_%s_%d" % (name, tag, int(side)), size, pos), name, "wall"))
    lintel = height - DOOR_H
    size = (DOOR_W, WALL, lintel) if axis == "y" else (WALL, DOOR_W, lintel)
    pos = ((0.0, at, DOOR_H + lintel / 2.0) if axis == "y"
           else (at, 0.0, DOOR_H + lintel / 2.0))
    parts.append(_paint(brushkit.block(
        "%s_%s_lintel" % (name, tag), size, pos), name, "wall"))
    return parts


def _solid_wall(name, tag, axis, at, span, height, centre):
    size = (span, WALL, height) if axis == "y" else (WALL, span, height)
    pos = ((centre, at, height / 2.0) if axis == "y"
           else (at, centre, height / 2.0))
    return [_paint(brushkit.block("%s_%s" % (name, tag), size, pos),
                   name, "wall")]


# ----------------------------------------------------------------------
# Treasure rooms
# ----------------------------------------------------------------------

def _treasure_shell(name, ceiling="flat"):
    """8 x 8 x 4.5 with a door front and back, and a ceiling.

    `treasure_room()` closes its own top -- a trim-material slab at
    `height` -- unlike `arena()` and `tower()`, which is worth saying out
    loud because it is the evidence that the open ones are an oversight
    rather than a rule (interface requirement 19).
    """
    mid = -T_SIDE / 2.0
    parts = [_paint(brushkit.block("%s_floor" % name, (T_SIDE, T_SIDE, 0.50),
                                   (0.0, mid, -0.25)), name, "floor")]
    parts += _door_wall(name, "in", "y", WALL / 2.0, T_SIDE, T_HEIGHT)
    parts += _door_wall(name, "out", "y", -T_SIDE - WALL / 2.0, T_SIDE,
                        T_HEIGHT)
    for side in (-1.0, 1.0):
        parts += _solid_wall(name, "side_%d" % int(side), "x",
                             side * (T_SIDE + WALL) / 2.0, T_SIDE, T_HEIGHT,
                             mid)
        parts.append(_paint(brushkit.block(
            "%s_skirt_%d" % (name, int(side)), (0.10, T_SIDE, 0.22),
            (side * (T_SIDE / 2.0 - 0.05), mid, 0.11)), name, "trim"))
    if ceiling == "coffer":
        # A closed pocket 0.9 m deep over the middle 3.6 m, so the room's
        # one warm light sits at the top of a recess instead of flat on a
        # slab. The pocket does not open to anything.
        ring = 3.6
        for axis, sx, sy, px, py in (
                ("a", T_SIDE, (T_SIDE - ring) / 2.0, 0.0,
                 -(T_SIDE - ring) / 4.0),
                ("b", T_SIDE, (T_SIDE - ring) / 2.0, 0.0,
                 -T_SIDE + (T_SIDE - ring) / 4.0),
                ("c", (T_SIDE - ring) / 2.0, ring, -(T_SIDE + ring) / 4.0, mid),
                ("d", (T_SIDE - ring) / 2.0, ring, (T_SIDE + ring) / 4.0, mid)):
            parts.append(_paint(brushkit.block(
                "%s_ceil_%s" % (name, axis), (sx, sy, WALL),
                (px, py, T_HEIGHT + WALL / 2.0)), name, "ceiling"))
            parts.append(_paint(brushkit.block(
                "%s_reveal_%s" % (name, axis), (sx, sy, 0.90),
                (px, py, T_HEIGHT + 0.45)), name, "trim"))
        parts.append(_paint(brushkit.block(
            "%s_ceil_pocket" % name, (ring, ring, WALL),
            (0.0, mid, T_HEIGHT + 0.90 + WALL / 2.0)), name, "ceiling"))
    else:
        parts.append(_paint(brushkit.block(
            "%s_ceil" % name, (T_SIDE, T_SIDE, WALL),
            (0.0, mid, T_HEIGHT + WALL / 2.0)), name, "ceiling"))
    return parts


def _plinth(name, style):
    """`treasure_room()`'s two steps: 3.0 square at 0.4, 2.2 square at 0.8.

    The reward sits at y 1.0 on top. Same in all three shells -- it is the
    engine's `reward_position` and not art's to move.
    """
    mid = -T_SIDE / 2.0
    parts = [
        _paint(brushkit.block("%s_step0" % name, (3.0, 3.0, 0.40),
                              (0.0, mid, 0.20)), name, "floor"),
        _paint(brushkit.block("%s_step1" % name, (2.2, 2.2, 0.40),
                              (0.0, mid, 0.60)), name, "floor"),
    ]
    if style == "curb":
        for dx, dy, sx, sy in ((0.0, 2.35, 5.0, 0.30), (0.0, -2.35, 5.0, 0.30),
                               (2.35, 0.0, 0.30, 5.0), (-2.35, 0.0, 0.30, 5.0)):
            parts.append(_paint(brushkit.block(
                "%s_curb_%.0f_%.0f" % (name, dx + 5, dy + 5), (sx, sy, 0.18),
                (dx, mid + dy, 0.09)), name, "trim"))
    elif style == "pallet":
        for i in range(4):
            parts.append(_paint(brushkit.block(
                "%s_bearer_%d" % (name, i), (3.2, 0.22, 0.16),
                (0.0, mid - 1.2 + i * 0.8, 0.08)), name, "trim"))
    elif style == "riser":
        for i, (s, z) in enumerate(((3.4, 0.10), (2.6, 0.30))):
            parts.append(_paint(brushkit.block(
                "%s_riser_%d" % (name, i), (s, s, 0.12), (0.0, mid, z)),
                name, "trim"))
    return parts


def shell_treasure_vault():
    """A strongroom. The room says the reward was protected.

    Heavy frames on both doors -- a reveal deep enough to throw a shadow --
    a curb ring around the plinth so the floor reads as kept clear, and a
    coffered ceiling. Nothing here is bigger than any other treasure room,
    because nothing can be.
    """
    name = "rv"
    parts = _treasure_shell(name) + _plinth(name, "curb")
    mid = -T_SIDE / 2.0
    for tag, y in (("in", 0.0), ("out", -T_SIDE)):
        for side in (-1.0, 1.0):
            parts.append(_paint(brushkit.block(
                "rv_frame_%s_%d" % (tag, int(side)), (0.36, 0.55, DOOR_H + 0.5),
                (side * (DOOR_W / 2.0 + 0.18), y, (DOOR_H + 0.5) / 2.0)),
                name, "trim"))
        parts.append(_paint(brushkit.block(
            "rv_head_%s" % tag, (DOOR_W + 0.72, 0.55, 0.42),
            (0.0, y, DOOR_H + 0.29)), name, "trim"))
    # Coffers: a grid of ribs under the ceiling slab.
    for i in range(3):
        off = -2.4 + i * 2.4
        parts.append(_paint(brushkit.block(
            "rv_rib_x_%d" % i, (T_SIDE, 0.26, 0.24), (0.0, mid + off,
                                                      T_HEIGHT - 0.12)),
            name, "trim"))
        parts.append(_paint(brushkit.block(
            "rv_rib_y_%d" % i, (0.26, T_SIDE, 0.24), (off, mid,
                                                      T_HEIGHT - 0.12)),
            name, "trim"))
    meta = {"story": "protected", "plinth": "curb", "ceiling": "coffered"}
    return "shell_treasure_vault", parts, T_SIDE, T_HEIGHT, meta


def shell_treasure_cache():
    """A store. The room says the reward was left here.

    Racking on the two side walls and the back, with a few empties on the
    shelves and the plinth reading as the one pallet nobody took. Every
    shelf is behind the plinth's 3.0 m footprint and clear of both 2.4 m
    door lanes, so the room stays a room the player walks through.
    """
    name = "rc"
    parts = _treasure_shell(name) + _plinth(name, "pallet")
    mid = -T_SIDE / 2.0
    depth = 0.55
    for side in (-1.0, 1.0):
        x = side * (T_SIDE / 2.0 - depth / 2.0)
        for level, z in enumerate((0.9, 1.9, 2.9)):
            parts.append(_paint(brushkit.block(
                "rc_shelf_%d_%d" % (int(side), level), (depth, 5.6, 0.12),
                (x, mid, z)), name, "trim"))
        for i in range(3):
            parts.append(_paint(brushkit.block(
                "rc_upright_%d_%d" % (int(side), i), (depth, 0.16, 3.1),
                (x, mid - 2.6 + i * 2.6, 1.55)), name, "trim"))
    # The back wall's rack, kept out of the exit door's lane.
    for level, z in enumerate((0.9, 1.9)):
        for side in (-1.0, 1.0):
            parts.append(_paint(brushkit.block(
                "rc_backshelf_%d_%d" % (level, int(side)),
                (2.2, depth, 0.12),
                (side * (DOOR_W / 2.0 + 1.3), -T_SIDE + depth / 2.0, z)),
                name, "trim"))
    # Empties: boxes at PROP_FOOTPRINT, on the shelves, never on the floor.
    for i, (sx, lvl, dy) in enumerate(((-1.0, 0, -1.6), (-1.0, 2, 1.4),
                                       (1.0, 1, -0.4), (1.0, 0, 2.2))):
        z = (0.9, 1.9, 2.9)[lvl]
        parts.append(_paint(brushkit.block(
            "rc_empty_%d" % i, (0.42, PROP * 0.7, 0.66),
            (sx * (T_SIDE / 2.0 - depth / 2.0), mid + dy, z + 0.39)),
            name, "floor"))
    meta = {"story": "stored", "plinth": "pallet", "ceiling": "flat",
            "shelf_depth": depth}
    return "shell_treasure_cache", parts, T_SIDE, T_HEIGHT, meta


def shell_treasure_coffer():
    """A display. The room says the reward was meant to be looked at.

    The ceiling steps up into a closed pocket 0.9 m deep over the middle
    3.6 m, so `treasure_room()`'s one warm light sits at the top of a
    recess rather than flat on a slab, and the plinth stands under the
    deepest part of it.

    The pocket does not open to anything. A light well to the sky in a
    windowless facility would be a hole, and the treasure room roofs itself
    on purpose.
    """
    name = "rf"
    parts = _treasure_shell(name, ceiling="coffer") + _plinth(name, "riser")
    mid = -T_SIDE / 2.0
    # Four pilasters carrying the pocket down to the floor, so the recess
    # reads as structure rather than as a hole in the ceiling.
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.append(_paint(brushkit.block(
                "rf_pil_%d_%d" % (int(sx), int(sy)), (0.34, 0.34, T_HEIGHT),
                (sx * 1.8, mid + sy * 1.8, T_HEIGHT / 2.0)), name, "wall"))
            parts.append(_paint(brushkit.block(
                "rf_pilcap_%d_%d" % (int(sx), int(sy)), (0.52, 0.52, 0.22),
                (sx * 1.8, mid + sy * 1.8, T_HEIGHT - 0.11)), name, "trim"))
    meta = {"story": "displayed", "plinth": "riser", "ceiling": "coffer",
            "coffer_depth": 0.90}
    return "shell_treasure_coffer", parts, T_SIDE, T_HEIGHT, meta


# ----------------------------------------------------------------------
# Corners
# ----------------------------------------------------------------------

def _corner(turn):
    """`corner()`'s 6 x 6 piece: in at z 0, out through the ±X wall at z 3.

    Marked by FORM, never by hazard orange -- see interface requirement 20.
    The inner corner is chamfered, the skirting carries around it, and the
    exit jamb has a reveal deep enough to throw the opening's own shadow.
    """
    name = "cr" if turn < 0 else "cl"
    S, H = C_SIDE, CORRIDOR_H
    mid = -S / 2.0
    exit_x = turn * S / 2.0
    parts = [
        _paint(brushkit.block("%s_floor" % name, (S, S, 0.50),
                              (0.0, mid, -0.25)), name, "floor"),
        _paint(brushkit.block("%s_ceil" % name, (S, S, WALL),
                              (0.0, mid, H + WALL / 2.0)), name, "ceiling"),
    ]
    parts += _door_wall(name, "in", "y", WALL / 2.0, S, H)
    parts += _solid_wall(name, "back", "y", -S - WALL / 2.0, S, H, 0.0)
    # Exit wall: two segments either side of a door centred at z = S/2.
    ex = exit_x + turn * WALL / 2.0
    for tag, lo, hi in (("a", 0.0, -(S / 2.0 - DOOR_W / 2.0)),
                        ("b", -(S / 2.0 + DOOR_W / 2.0), -S)):
        span = abs(hi - lo)
        parts.append(_paint(brushkit.block(
            "%s_exit_%s" % (name, tag), (WALL, span, H),
            (ex, (lo + hi) / 2.0, H / 2.0)), name, "wall"))
    parts.append(_paint(brushkit.block(
        "%s_exit_lintel" % name, (WALL, DOOR_W, H - DOOR_H),
        (ex, mid, DOOR_H + (H - DOOR_H) / 2.0)), name, "wall"))
    # The solid side wall opposite the turn.
    parts += _solid_wall(name, "solid", "x", -exit_x - turn * WALL / 2.0,
                         S, H, mid)
    # THE MARKER, in form. A stepped chamfer on the corner where the exit
    # wall meets the back wall -- the FAR edge of the opening, which is the
    # one a player sees head-on walking in. The first version put it on the
    # near corner beside the door, where it was 0.3 m of trim at the very
    # edge of frame doing no work at all.
    #
    # It is secondary and this file says so: the opening itself is the cue,
    # and 6 m is close enough that nothing has to announce it. What the
    # chamfer replaces is `corner()`'s hazard stripe, which was a "look
    # here" flag in a colour that is supposed to mean warning.
    for i, inset in enumerate((0.10, 0.34, 0.58)):
        w = 0.34 - i * 0.10
        parts.append(_paint(brushkit.block(
            "%s_chamfer_%d" % (name, i), (w, w, H),
            (exit_x - turn * (inset + w / 2.0), -S + inset + w / 2.0,
             H / 2.0)), name, "trim"))
    for tag, size, pos in (
            ("sk_back", (S, 0.10, 0.22), (0.0, -S + 0.05, 0.11)),
            ("sk_solid", (0.10, S, 0.22), (-exit_x + turn * 0.05, mid, 0.11))):
        parts.append(_paint(brushkit.block(
            "%s_%s" % (name, tag), size, pos), name, "trim"))
    for sy in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "%s_reveal_%d" % (name, int(sy)), (0.30, 0.34, DOOR_H + 0.4),
            (exit_x - turn * 0.15, mid + sy * (DOOR_W / 2.0 + 0.17),
             (DOOR_H + 0.4) / 2.0)), name, "trim"))
    parts.append(_paint(brushkit.block(
        "%s_reveal_head" % name, (0.30, DOOR_W + 0.68, 0.34),
        (exit_x - turn * 0.15, mid, DOOR_H + 0.17)), name, "trim"))
    meta = {"turn": turn, "marker": "form",
            "exit_offset": [round(exit_x + turn * WALL, 2), 0.0, S / 2.0]}
    return name, parts, S, H, meta


def shell_corner_left():
    """A LEFT turn, which is `corner(+1)` -- out through the +X wall.

    Worth deriving rather than assuming, because the first version of this
    file had the two names swapped and the RENDER is what caught it.

    A chamber runs along its local +Z. `zone_builder._rot` is
    `Basis(Vector3.UP, yaw)`, and a +90 degree rotation about +Y maps +Z to
    +X, so after `corner(+1)` -- whose `yaw_after` is `yaw + PI/2` -- the
    zone heads off along +X. In Godot a node's basis is (right +X, up +Y,
    forward -Z), so a player FACING +Z has been yawed 180 degrees and their
    right is world -X: +X is their left.

    `corner(+1)` therefore turns left, and `corner(-1)` turns right.
    """
    _, parts, side, height, meta = _corner(1)
    return "shell_corner_left", parts, side, height, meta


def shell_corner_right():
    """A right turn, `corner(-1)`. The mirror of the left one, deliberately.

    A player who learns to read one turn should read the other without
    relearning it, so these are not two designs -- they are one design and
    its reflection, which is what `corner(turn)` is.
    """
    _, parts, side, height, meta = _corner(-1)
    return "shell_corner_right", parts, side, height, meta


SHELLS = [shell_treasure_vault, shell_treasure_cache, shell_treasure_coffer,
          shell_corner_left, shell_corner_right]


def main():
    common.reset_scene()
    report = {}
    for builder in SHELLS:
        name, parts, side, height, meta = builder()
        obj = common.join(parts, name)
        common.uv_project_world(obj, materials.ARCH_DENSITY,
                                materials.ARCH_SIZE)
        entry = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "room",
                                  tier="architecture",
                                  texture_size=materials.ARCH_SIZE,
                                  anchor="entrance", check_flat=False)
        entry.update(meta)
        if name.startswith("shell_treasure"):
            # treasure_room()'s own numbers, none of them art's to move.
            entry["exit_offset"] = [0.0, 0.0, side]
            entry["check_anchor"] = [0.0, 1.0, side / 2.0]
            entry["enemy_anchors"] = []
            entry["objective"] = ["reach_reward"]
        else:
            entry["check_anchor"] = None
            entry["enemy_anchors"] = []
        entry["bounds"] = [[-side / 2.0, -1.0, 0.0], [side, height + 1.0,
                                                      side]]
        entry["interior"] = [side, height, side]
        report[name] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch019",
                       "shells", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
    print("[art] batch019 manifest -> %s" % out)


if __name__ == "__main__":
    main()
