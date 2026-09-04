"""Batch 016 -- room shells, the arena family.

    .tools/blender/blender -b --python tools/blender/build_arenas.py

Batch 015 built the corridor family. This is the second of the six §7
families, and the one the game spends its fights in: `zone.py`'s
`ArenaChamber` is 10-28 m square with walls 4-8 m, carries up to four enemy
groups, and takes one of two objectives -- `kill_all` or `reach_reward`. A
boss room is an arena holding one brute.

## What makes four arenas four rooms

A corridor differs from a corridor in what you can SEE. An arena differs
from an arena in what you can DO in it, because an arena is a floor plate
with a fight on it and the only real variables are:

    where cover is        -- and therefore where a fight can be won from
    what is above         -- and therefore who can hold it
    how the plate divides -- and therefore whether an approach is a problem

So the four here are one subtraction (a pit), one addition (columns), one
storey (a balcony) and one division (a barrier). None of them is another
one at a different size, and none is the procedural version's answer --
`arena()` scatters three random boxes and a wedge, which is cover in the
sense that a coin toss is a plan.

| Shell | Size | What it does that the others do not |
| --- | --- | --- |
| `shell_arena_pit` | 18 x 18 x 6 m | the middle drops exactly `MAX_VERTICAL_STEP`, so the fight is in a bowl and the rim is high ground you can walk to. The Check is down in it |
| `shell_arena_pillars` | 22 x 22 x 5 m | a 4x4 column grid on a 4.4 m pitch. Cover in the MIDDLE of the plate, not hugged to the walls, and every gap is wide enough for a brute |
| `shell_arena_balcony` | 26 x 24 x 8 m | `arena_span` and `wall_height` near their ceilings, with a walkway at 3.2 m on three sides. The boss room: one open plate below, ranged ground above |
| `shell_arena_split` | 20 x 20 x 5 m | a 1.8 m barrier across the middle -- above `JUMP_APEX`, so it must be gone around -- with two gaps. The Check is on the far side |

## Numbers, and where each one comes from

    arena_span 10-28, wall_height 4-8      zone.py ArenaChamber
    DOOR_WIDTH 2.4, DOOR_HEIGHT 3.2        constants; _perimeter carves this
    MAX_VERTICAL_STEP 1.00                 the pit depth, so it is walkable
    JUMP_APEX 1.333                        the barrier is 1.8, above it
    SAFE_BASE_JUMP_GAP 2.6                 the balcony is 3.2, out of reach
    brute 1.8 x 2.6 x 1.8                  every gap clears a brute
    enemy_aggro_radius 18.0                 why 26 m has corners outside it

## What this batch does NOT decide

**Arenas have no ceiling in the engine.** `_perimeter` builds a floor and
four walls; `_greeble_room` mounts corner buttresses and floor crates and
nothing overhead. The corridors that chain into an arena DO have ceilings,
so the join would show sky. These shells include a ceiling at `wall_height`
and the question is recorded as an interface requirement rather than
answered here -- if open-sky arenas are intended, the ceiling comes out and
nothing else changes.

Nor does this batch place cover randomly. `arena()`'s three rng boxes and
`_greeble_room`'s two-to-four crates are the engine's dressing pass and
still are; a shell's structure is the part that has to be the same every
time a Check is placed against it.
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
OUT = "batch016/shells"

DIM = common.DIM
WALL = DIM["wall_thickness"]                 # 0.40
STEP = DIM["max_vertical_step"]              # 1.00
APEX = DIM["jump_apex"]                      # 1.333
GAP = DIM["safe_base_jump_gap"]              # 2.60
DOOR_W = DIM["door_width"]                   # 2.40
DOOR_H = DIM["door_height"]                  # 3.20
BRUTE = DIM["enemy_brute_size"][0]           # 1.80
AGGRO = DIM["enemy_aggro_radius"]            # 18.0
S_MIN = DIM["arena_span_min"]                # 10.0
S_MAX = DIM["arena_span_max"]                # 28.0
H_MIN = DIM["arena_wall_height_min"]         # 4.0
H_MAX = DIM["arena_wall_height_max"]         # 8.0

_IMAGES = {}
#: Every footprint that stands on the floor plate, as (x0, x1, y0, y1) in
#: Blender metres. `open_floor` is measured off this, not asserted.
_FOOTPRINTS = []


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("arena_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, name, role):
    common.assign(obj, common.make_textured_material(
        "%s_%s" % (name, role), _image(role), roughness=pal.roughness(THEME)))
    return obj


def _obstacle(size, centre):
    """Record a floor footprint so `open_floor` can be measured."""
    _FOOTPRINTS.append((centre[0] - size[0] / 2.0, centre[0] + size[0] / 2.0,
                        centre[1] - size[1] / 2.0, centre[1] + size[1] / 2.0))


def _open_floor(width, depth):
    """Fraction of the floor plate with nothing standing on it.

    Sampled on a 0.10 m grid rather than summed, because summing areas is
    only right while nothing overlaps and nothing here guarantees that.
    This is the arena's honest version of the corridor's `sightline`: a
    number a render can be held against, not a mood word (L-51).
    """
    if not _FOOTPRINTS:
        return 1.0
    step, blocked, total = 0.10, 0, 0
    nx, ny = int(width / step), int(depth / step)
    for ix in range(nx):
        x = -width / 2.0 + (ix + 0.5) * step
        for iy in range(ny):
            y = -(iy + 0.5) * step
            total += 1
            for x0, x1, y0, y1 in _FOOTPRINTS:
                if x0 <= x <= x1 and y0 <= y <= y1:
                    blocked += 1
                    break
    return round(1.0 - blocked / float(total), 3)


def _cover_reach(width, depth, radius):
    """Fraction of the floor plate within `radius` of something to hide behind.

    `open_floor` says how much plate a shell gives back; it does not say
    whether the plate is worth standing on. Sixteen columns eat 8% of a
    22 m arena and change every fight in it, so the number that separates
    these four is not area consumed but **how much of the floor has cover
    in reach** -- measured at `brute_reach`, because that is the distance a
    brute closes and therefore the distance cover has to be within to be
    cover at all.
    """
    if not _FOOTPRINTS:
        return 0.0
    step, near, total = 0.10, 0, 0
    nx, ny = int(width / step), int(depth / step)
    for ix in range(nx):
        x = -width / 2.0 + (ix + 0.5) * step
        for iy in range(ny):
            y = -(iy + 0.5) * step
            total += 1
            for x0, x1, y0, y1 in _FOOTPRINTS:
                dx = max(x0 - x, 0.0, x - x1)
                dy = max(y0 - y, 0.0, y - y1)
                if dx * dx + dy * dy <= radius * radius:
                    near += 1
                    break
    return round(near / float(total), 3)


def _room(name, width, depth, height, floor=True):
    """Floor, ceiling, four walls, and a door gap front and back.

    `_perimeter` carves DOOR_WIDTH x DOOR_HEIGHT out of the entrance and
    exit walls and leaves the side walls solid. An arena that sealed itself
    would be a room the Zone cannot chain, so the gaps are not decoration.

    `floor=False` is for a shell that builds its own plate in pieces. The
    doorway is still at grade either way -- a chamber whose entrance sits a
    step above the corridor feeding it does not chain, whatever the step is
    worth as a room.
    """
    mid = -depth / 2.0
    parts = [
        _paint(brushkit.block("%s_ceil" % name, (width, depth, WALL),
                              (0.0, mid, height + WALL / 2.0)), name,
               "ceiling"),
    ]
    if floor:
        parts.insert(0, _paint(brushkit.block(
            "%s_floor" % name, (width, depth, 0.50), (0.0, mid, -0.25)),
            name, "floor"))
    for side in (-1.0, 1.0):                       # side walls, solid
        parts.append(_paint(brushkit.block(
            "%s_wall_%d" % (name, int(side)), (WALL, depth, height),
            (side * (width + WALL) / 2.0, mid, height / 2.0)), name, "wall"))
        parts.append(_paint(brushkit.block(
            "%s_skirt_%d" % (name, int(side)), (0.10, depth, 0.22),
            (side * (width / 2.0 - 0.05), mid, 0.11)), name, "trim"))
    jamb = (width - DOOR_W) / 2.0
    for end, y in (("in", WALL / 2.0), ("out", -depth - WALL / 2.0)):
        for side in (-1.0, 1.0):
            parts.append(_paint(brushkit.block(
                "%s_%s_%d" % (name, end, int(side)), (jamb, WALL, height),
                (side * (DOOR_W + jamb) / 2.0, y, height / 2.0)),
                name, "wall"))
        parts.append(_paint(brushkit.block(
            "%s_%s_lintel" % (name, end), (DOOR_W, WALL, height - DOOR_H),
            (0.0, y, DOOR_H + (height - DOOR_H) / 2.0)), name, "wall"))
        parts.append(_paint(brushkit.block(
            "%s_%s_head" % (name, end), (DOOR_W + 0.6, 0.24, 0.30),
            (0.0, y, DOOR_H + 0.15)), name, "trim"))
    return parts


def _ring(width, depth, count=4, y=0.0):
    """`arena()`'s own spawn ring: radius 0.3 about the plate centre."""
    import math
    out = []
    for i in range(count):
        a = 2.0 * math.pi * i / 8.0
        out.append([round(math.cos(a) * width * 0.3, 2), round(y, 2),
                    round(depth / 2.0 + math.sin(a) * depth * 0.3, 2)])
    return out


def shell_arena_pit():
    """18 x 18 x 6 m with the middle 12 x 12 sunk exactly one step.

    A pit is the only way to add verticality to a fighting floor without
    taking any of the floor away. At `MAX_VERTICAL_STEP` it is walkable in
    and out from every side, so it reads as a bowl rather than a trap, and
    the rim is high ground a player can take without a jump.

    The Check sits at `reward_position` -- depth * 0.72 -- which lands
    inside the pit. That is the point: the reward is at the bottom of the
    room the fight is in, not on a shelf beside it.
    """
    width, depth, height = 18.0, 18.0, 6.0
    parts = _room("ap", width, depth, height, floor=False)
    rim, sunk = 3.0, STEP
    # The rim is at GRADE and the middle is the hole, not the other way
    # round: the first version raised the rim instead, which put both
    # doorways a step above the corridor chaining into them. A chamber that
    # does not meet its neighbour's floor is not a chamber.
    for size, centre in (((width, rim), (0.0, -rim / 2.0)),
                         ((width, rim), (0.0, -depth + rim / 2.0)),
                         ((rim, depth - 2 * rim), (-width / 2.0 + rim / 2.0,
                                                   -depth / 2.0)),
                         ((rim, depth - 2 * rim), (width / 2.0 - rim / 2.0,
                                                   -depth / 2.0))):
        parts.append(_paint(brushkit.block(
            "ap_rim_%.0f_%.0f" % (centre[0] + 20, centre[1] + 20),
            (size[0], size[1], 0.50), (centre[0], centre[1], -0.25)),
            "ap", "floor"))
    # The sunken plate, one step down.
    parts.append(_paint(brushkit.block(
        "ap_pit", (width - 2 * rim, depth - 2 * rim, 0.50),
        (0.0, -depth / 2.0, -sunk - 0.25)), "ap", "floor"))
    # The four faces of the drop, plus a lip so it reads as one.
    for size, centre in (((width - 2 * rim, 0.30), (0.0, -rim + 0.15)),
                         ((width - 2 * rim, 0.30), (0.0, -depth + rim - 0.15)),
                         ((0.30, depth - 2 * rim), (-width / 2.0 + rim - 0.15,
                                                    -depth / 2.0)),
                         ((0.30, depth - 2 * rim), (width / 2.0 - rim + 0.15,
                                                    -depth / 2.0))):
        parts.append(_paint(brushkit.block(
            "ap_face_%.0f_%.0f" % (centre[0] + 20, centre[1] + 20),
            (size[0], size[1], sunk), (centre[0], centre[1], -sunk / 2.0)),
            "ap", "wall"))
        parts.append(_paint(brushkit.block(
            "ap_lip_%.0f_%.0f" % (centre[0] + 20, centre[1] + 20),
            (size[0] + 0.24, size[1] + 0.24, 0.16), (centre[0], centre[1],
                                                     -0.08)),
            "ap", "trim"))
    # The rim is walkable floor and the pit is walkable floor: nothing is
    # recorded as a footprint, and `open_floor` is 1.0 on purpose. A pit
    # takes no floor away, which is the whole argument for building one --
    # and `cover_reach` is 0.0, which is the price.
    meta = {
        "open_floor": 1.0,
        "cover_reach": 0.0,
        "pit_depth": sunk,
        "rim_width": rim,
        "check_anchor": [0.0, round(-sunk, 2), round(depth * 0.72, 2)],
        "enemy_anchors": _ring(width, depth, y=-sunk),
        "high_anchors": [[0.0, 0.0, round(rim / 2.0, 2)],
                         [0.0, 0.0, round(depth - rim / 2.0, 2)]],
        "pit_anchor": [0.0, round(-sunk, 2), round(depth / 2.0, 2)],
        "objective": ["kill_all", "reach_reward"],
        "sightline": depth,
    }
    return "shell_arena_pit", parts, width, depth, height, meta


def shell_arena_pillars():
    """22 x 22 x 5 m under a 4 x 4 grid of columns on a 4.4 m pitch.

    `arena()` scatters three random boxes and `_greeble_room` hugs its
    crates to the walls so the floor "stays fightable". That produces a
    plate with cover only at its edges, which is a shooting gallery with
    hiding places rather than a room you fight across.

    A grid puts cover in the MIDDLE and is honest about it: every aisle is
    3.2 m, which clears a 1.8 m brute with room, so nothing here quietly
    invents a wall only the player fits through. The centre aisle is left
    clear of columns because `reward_position` is on it.

    22 m also puts the far corners at 15.6 m from the centre, inside
    `enemy_aggro_radius`: this is a room a fight happens in all at once.
    """
    width, depth, height = 22.0, 22.0, 5.0
    parts = _room("aq", width, depth, height)
    col, pitch = 1.2, 4.4
    xs = [-1.5 * pitch, -0.5 * pitch, 0.5 * pitch, 1.5 * pitch]
    ys = [-3.3 - i * pitch for i in range(4)]
    assert pitch - col > BRUTE + 1.0, "an aisle a brute cannot use"
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            parts.append(_paint(brushkit.block(
                "aq_col_%d_%d" % (i, j), (col, col, height),
                (x, y, height / 2.0)), "aq", "wall"))
            # A base that SITS on the floor and a capital that MEETS the
            # ceiling. Centring these on 0.30 and height-0.30 left both
            # floating 0.15 m clear, which at this value range reads as a
            # collar hovering in shadow rather than as a column footing.
            for z, flare in ((0.15, 0.34), (height - 0.15, 0.24)):
                parts.append(_paint(brushkit.block(
                    "aq_cap_%d_%d_%.0f" % (i, j, z * 10), (col + flare,
                                                           col + flare, 0.30),
                    (x, y, z)), "aq", "trim"))
            _obstacle((col + 0.34, col + 0.34), (x, y))
    meta = {
        "open_floor": _open_floor(width, depth),
        "cover_reach": _cover_reach(width, depth, DIM["brute_reach"]),
        "column_pitch": pitch,
        "aisle_width": round(pitch - col, 2),
        "check_anchor": [0.0, 0.0, round(depth * 0.72, 2)],
        "enemy_anchors": _ring(width, depth),
        "cover_anchors": [[round(x, 2), 0.0, round(-y, 2)]
                          for x in (xs[0], xs[3]) for y in (ys[0], ys[3])],
        "objective": ["kill_all", "reach_reward"],
        "sightline": depth,
    }
    return "shell_arena_pillars", parts, width, depth, height, meta


def shell_arena_balcony():
    """26 x 24 x 8 m with a walkway at 3.2 m down three sides.

    Both spans and the wall height sit near `zone.py`'s ceilings, which is
    what a boss room is for: `ArenaChamber`'s docstring says a boss room is
    an arena holding one brute, and a 1.8 x 2.6 m brute in an 18 m room is
    a room with a brute in it rather than a fight.

    The floor is left as ONE open plate -- no columns, no pit -- because a
    brute's whole problem is that it closes distance and there is nowhere
    to break line of sight. The answer to it is the balcony, at 3.2 m:
    above `SAFE_BASE_JUMP_GAP` and well above `JUMP_APEX`, so it is stair
    or grapple ground, and holding it is a decision rather than a default.

    26 m across also puts the corners 17.7 m from the centre, at the edge
    of `enemy_aggro_radius` -- the only shell in the family where standing
    in one corner is meaningfully different from standing in another.
    """
    width, depth, height = 26.0, 24.0, 8.0
    parts = _room("ab", width, depth, height)
    deck, run, rail = 3.2, 2.4, 0.30
    assert deck > GAP, "a balcony a base jump reaches is a step"
    # Three sides: both long walls and the back.
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "ab_deck_%d" % int(side), (run, depth - 0.4, rail),
            (side * (width / 2.0 - run / 2.0), -depth / 2.0, deck)),
            "ab", "floor"))
        parts.append(_paint(brushkit.block(
            "ab_rail_%d" % int(side), (0.16, depth - 0.4, 0.95),
            (side * (width / 2.0 - run), -depth / 2.0, deck + 0.62)),
            "ab", "trim"))
    parts.append(_paint(brushkit.block(
        "ab_deck_back", (width - 2 * run, run, rail),
        (0.0, -depth + run / 2.0, deck)), "ab", "floor"))
    parts.append(_paint(brushkit.block(
        "ab_rail_back", (width - 2 * run, 0.16, 0.95),
        (0.0, -depth + run, deck + 0.62)), "ab", "trim"))
    # Posts under the two long runs, and the stair up at the near right.
    for side in (-1.0, 1.0):
        for i in range(5):
            x = side * (width / 2.0 - run)
            y = -3.0 - i * 4.4
            parts.append(_paint(brushkit.block(
                "ab_post_%d_%d" % (int(side), i), (0.28, 0.28, deck),
                (x, y, deck / 2.0)), "ab", "trim"))
            _obstacle((0.28, 0.28), (x, y))
    steps, rise = 10, deck / 10.0
    for i in range(steps):
        y = -1.0 - i * 0.44
        parts.append(_paint(brushkit.block(
            "ab_step_%d" % i, (run - 0.2, 0.44, rise * (i + 1)),
            (width / 2.0 - run / 2.0, y, rise * (i + 1) / 2.0)),
            "ab", "floor"))
    _obstacle((run, steps * 0.44), (width / 2.0 - run / 2.0,
                                    -1.0 - steps * 0.22))
    meta = {
        "open_floor": _open_floor(width, depth),
        "cover_reach": _cover_reach(width, depth, DIM["brute_reach"]),
        "balcony_height": deck,
        "balcony_sides": 3,
        "check_anchor": [0.0, 0.0, round(depth * 0.72, 2)],
        "enemy_anchors": _ring(width, depth),
        "high_anchors": [[round(s * (width / 2.0 - run / 2.0), 2), deck,
                          round(depth * f, 2)]
                         for s in (-1.0, 1.0) for f in (0.35, 0.75)],
        "objective": ["kill_all"],
        "sightline": depth,
    }
    return "shell_arena_balcony", parts, width, depth, height, meta


def shell_arena_split():
    """20 x 20 x 5 m cut across the middle by a 1.8 m barrier with two gaps.

    `JUMP_APEX` is 1.333, so 1.80 cannot be cleared and the barrier is not
    a suggestion. The two 3.2 m gaps are where an approach has to happen,
    which turns an open brawl into a room with a near half and a far half
    -- and `reward_position` at depth * 0.72 puts the Check in the FAR one,
    so `reach_reward` here means committing through a gap under fire.

    Each half also carries a 0.90 m cover run. That is under
    `MAX_VERTICAL_STEP`, so it is cover you can step onto rather than cover
    you are stuck behind -- the difference between a wall and a decision.

    From the entrance the barrier hides the far floor: `sightline` 10.0,
    the only arena in the family where it is not the full depth.
    """
    width, depth, height = 20.0, 20.0, 5.0
    parts = _room("as", width, depth, height)
    barrier, gap_w, gap_x = 1.80, 3.20, 5.0
    assert barrier > APEX, "a barrier a base jump clears is a kerb"
    assert gap_w > BRUTE + 1.0, "a gap a brute cannot use"
    mid = -depth / 2.0
    runs = [(-width / 2.0, -gap_x - gap_w / 2.0),
            (-gap_x + gap_w / 2.0, gap_x - gap_w / 2.0),
            (gap_x + gap_w / 2.0, width / 2.0)]
    for i, (x0, x1) in enumerate(runs):
        span = x1 - x0
        if span <= 0.01:
            continue
        parts.append(_paint(brushkit.block(
            "as_bar_%d" % i, (span, 0.60, barrier),
            ((x0 + x1) / 2.0, mid, barrier / 2.0)), "as", "wall"))
        parts.append(_paint(brushkit.block(
            "as_barcap_%d" % i, (span, 0.76, 0.18),
            ((x0 + x1) / 2.0, mid, barrier + 0.09)), "as", "trim"))
        _obstacle((span, 0.76), ((x0 + x1) / 2.0, mid))
    # One steppable cover run per half, offset so they do not line up.
    for i, (x, y) in enumerate(((-4.2, -4.6), (4.2, -15.4))):
        parts.append(_paint(brushkit.block(
            "as_cover_%d" % i, (4.0, 0.90, 0.90), (x, y, 0.45)),
            "as", "floor"))
        parts.append(_paint(brushkit.block(
            "as_covercap_%d" % i, (4.2, 1.06, 0.14), (x, y, 0.97)),
            "as", "trim"))
        _obstacle((4.2, 1.06), (x, y))
    meta = {
        "open_floor": _open_floor(width, depth),
        "cover_reach": _cover_reach(width, depth, DIM["brute_reach"]),
        "barrier_height": barrier,
        "gap_width": gap_w,
        "gap_anchors": [[-gap_x, 0.0, depth / 2.0], [gap_x, 0.0, depth / 2.0]],
        "cover_height": 0.90,
        "check_anchor": [0.0, 0.0, round(depth * 0.72, 2)],
        "enemy_anchors": _ring(width, depth),
        "objective": ["kill_all", "reach_reward"],
        "sightline": depth / 2.0,
    }
    return "shell_arena_split", parts, width, depth, height, meta


SHELLS = [shell_arena_pit, shell_arena_pillars,
          shell_arena_balcony, shell_arena_split]


def main():
    common.reset_scene()
    report = {}
    for builder in SHELLS:
        _FOOTPRINTS.clear()
        name, parts, width, depth, height, meta = builder()
        if not (S_MIN <= width <= S_MAX and S_MIN <= depth <= S_MAX):
            raise AssertionError(
                "%s: %.1f x %.1f m is outside zone.py's arena bounds "
                "(%.0f-%.0f m each way). Godot owns these."
                % (name, width, depth, S_MIN, S_MAX))
        if not (H_MIN <= height <= H_MAX):
            raise AssertionError(
                "%s: wall_height %.1f is outside zone.py's %.0f-%.0f."
                % (name, height, H_MIN, H_MAX))
        obj = common.join(parts, name)
        # NO `set_origin` -- see build_shells.main. A chamber's origin is
        # its entrance on the centre line, which is where these build.
        common.uv_project_world(obj, materials.ARCH_DENSITY,
                                materials.ARCH_SIZE)
        entry = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "room",
                                  tier="architecture",
                                  texture_size=materials.ARCH_SIZE,
                                  anchor="entrance", check_flat=False)
        entry.update(meta)
        entry["exit_offset"] = [0.0, 0.0, depth]
        entry["bounds"] = [[-width / 2.0, -1.0, 0.0],
                           [width, height + 1.0, depth]]
        entry["interior"] = [width, height, depth]
        report[name] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch016",
                       "shells", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
    print("[art] batch016 manifest -> %s" % out)


if __name__ == "__main__":
    main()
