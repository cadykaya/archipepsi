"""Batch 017 -- room shells, the platform-path family.

    .tools/blender/blender -b --python tools/blender/build_paths.py

Third of §7's six families, and the only one where getting the numbers
slightly wrong makes the game unfinishable. `PlatformPathChamber` bounds
`gap_size` and `vertical_step` **jointly** -- v0.4 bounded them
independently, both could be maxed, and the real margin was 1.17x rather
than the 1.56x the flat-jump derivation advertised. So no gap in this file
is a literal: every one is checked against `C.max_safe_gap(step)` at the
step it was built at, through `engine_truth`.

## The one thing a path shell must not do

Preserve base-kit solvability. A mandatory jump is measured **edge to
edge** between two platform footprints, not centre to centre, because that
is the jump the player actually has to make:

    dz = max(0, |dZ| - platform)      dx = max(0, |dX| - platform)
    distance = sqrt(dz^2 + dx^2)

`_assert_reachable` runs that over every consecutive pair before anything
is exported. A shell that fails it is a level nobody can finish, and no
render would show it.

## What differs, given how little is free

`platform_path()` fixes more than the other builders do: an 8.0 m width, a
4.0 m ledge at each end, 2.5 m square platforms, a rise of `step` per
segment, enemies waiting on the END LEDGE rather than on the route, and a
40 m void below. What is left to author is the shape of the route and what
the walls say about why the floor is gone.

| Shell | Segments | Step | Gap | What it does |
| --- | --- | --- | --- | --- |
| `shell_path_ascent` | 5 | 1.00 | 1.80 | the climb. Every landing at `MAX_VERTICAL_STEP`, straight up the centre line, walls carrying the stub of the floor that used to be there |
| `shell_path_stagger` | 6 | 0.50 | 2.20 | the same climb made a route: platforms alternate 1.6 m either side, so the jump is diagonal and the line is never straight. Measured 2.31 m against a 2.40 m bound |
| `shell_path_spans` | 3 | 0.00 | 2.40 | not a climb at all. Three wide beams, flat, short: a crossing, where the danger is what is waiting on the far ledge rather than the jumps |

## Two contracts these carry that no earlier shell did

`exit_offset` has a **Y**: `platform_path()` returns `Vector3(0, rise,
total)`, because the chamber exits at the top of what you climbed. Every
shell before this one exited at grade.

`bounds` reaches 40 m **below** the origin. The void is not decoration --
`FALL_KILL_Y` is where a fall stops being a fall -- and it is engine-owned.
These shells model the shaft 8 m down, which is as far as anyone can see
into an 8 m wide slot from above, and carry the real figures in the
manifest rather than modelling forty metres of nothing.

## No ceiling, and this time on purpose

Interface requirement 19 is about ROOM chambers, which are roofed in a
corridor and open in an arena for no stated reason. A platform path is
different: `platform_path()` builds its side walls `wall_height + 40` tall,
running 20 m above the top of the climb. That is a chamber deliberately
open to a shaft, and these shells keep it.
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
import palette as pal  # noqa: E402
import routecheck  # noqa: E402

THEME = "concrete_facility"
OUT = "batch017/shells"

DIM = common.DIM
WALL = DIM["wall_thickness"]
PLAT = DIM["min_platform_size"]              # 2.50
STEP_MAX = DIM["max_vertical_step"]          # 1.00
W = DIM["path_width"]                        # 8.00
LEDGE = DIM["path_ledge"]                    # 4.00
SEG_MIN = DIM["path_segment_min"]            # 3
SEG_MAX = DIM["path_segment_max"]            # 8
FALL_KILL_Y = DIM["fall_kill_y"]             # -30.0
SHAFT = 8.0                                  # how far down these model

_IMAGES = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("path_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, name, role):
    common.assign(obj, common.make_textured_material(
        "%s_%s" % (name, role), _image(role), roughness=pal.roughness(THEME)))
    return obj


def _assert_reachable(name, stones, step):
    """`routecheck`'s rule, so towers and paths cannot disagree about it."""
    return routecheck.assert_reachable(name, stones, step)


def _shaft(name, total, top):
    """Two side walls and no ceiling. The void below is engine-owned.

    Modelled `SHAFT` metres down rather than the forty `bounds` declares:
    an 8 m slot shows nothing past that from above, and forty metres of
    unlit wall is geometry nobody will ever see paying for itself in file
    size.
    """
    mid = -total / 2.0
    height = top + SHAFT
    parts = []
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "%s_wall_%d" % (name, int(side)), (WALL, total, height),
            (side * (W + WALL) / 2.0, mid, top - height / 2.0)),
            name, "wall"))
    # The head wall behind the start ledge and the one behind the end
    # ledge: without them the shell reads as a slice rather than a room.
    return parts


def _ledge(name, tag, y_centre, z_top):
    """One of the two 8 x 4 m ledges, with a nosing so its edge reads."""
    return [
        _paint(brushkit.block("%s_ledge_%s" % (name, tag), (W, LEDGE, 0.60),
                              (0.0, y_centre, z_top - 0.30)), name, "floor"),
        _paint(brushkit.block("%s_nose_%s" % (name, tag), (W, 0.24, 0.20),
                              (0.0, y_centre, z_top - 0.10)), name, "trim"),
    ]


def _platform(name, i, x, y, z, size):
    """A platform, its nosing, and the bracket that stops it floating.

    `platform_path()` puts a wedge under each one so they "read as
    brushwork rather than floating tiles". Same argument, built to the
    surface it hangs from (L-55): the bracket starts at the platform's own
    underside.
    """
    sx, sz = size
    return [
        _paint(brushkit.block("%s_plat_%d" % (name, i), (sx, sz, 0.50),
                              (x, y, z - 0.25)), name, "floor"),
        _paint(brushkit.block("%s_platnose_%d" % (name, i),
                              (sx + 0.16, sz + 0.16, 0.16), (x, y, z - 0.08)),
               name, "trim"),
        _paint(brushkit.block("%s_platfoot_%d" % (name, i),
                              (sx * 0.55, sz * 0.55, 0.9),
                              (x, y, z - 0.50 - 0.45)), name, "trim"),
    ]


def _layout(segments, gap):
    """`platform_path()`'s own spacing, so an authored shell lands where the
    procedural one does."""
    total = LEDGE + (gap + PLAT) * segments + gap + LEDGE
    zs = [LEDGE + gap + (gap + PLAT) * i + PLAT / 2.0 for i in range(segments)]
    return total, zs


def shell_path_ascent():
    """Five platforms, each landing a full `MAX_VERTICAL_STEP` higher.

    The straight one, and the steep one: 1.00 m per segment is the most the
    schema allows, which drops the reachable gap to 2.00 m. Built at 1.80,
    so the hardest jump in the family still keeps 200 mm in hand.

    What makes it a room rather than a stack of tiles is the wall: a stub
    of the original floor slab is left on both sides at the height the
    platforms are climbing toward, broken off at the shaft. The platforms
    are what is left of that floor, and the climb is back up to it.
    """
    segments, step, gap = 5, STEP_MAX, 1.80
    total, zs = _layout(segments, gap)
    rise = step * segments
    top = rise + 6.0
    name = "pa"
    parts = _shaft(name, total, top)
    parts += _ledge(name, "start", -LEDGE / 2.0, 0.0)
    parts += _ledge(name, "end", -total + LEDGE / 2.0, rise)
    stones = [((0.0, -LEDGE / 2.0), (W, LEDGE))]
    anchors = []
    for i, z in enumerate(zs):
        y, h = -z, step * (i + 1)
        parts += _platform(name, i, 0.0, y, h, (PLAT, PLAT))
        stones.append(((0.0, y), (PLAT, PLAT)))
        anchors.append([0.0, round(h, 2), round(z, 2)])
    stones.append(((0.0, -total + LEDGE / 2.0), (W, LEDGE)))
    worst, allowed = _assert_reachable("shell_path_ascent", stones, step)
    # The broken floor the platforms fell out of, at the height they climb
    # to -- the reason this shaft exists, stated in geometry.
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "pa_stub_%d" % int(side), (0.9, total - 2 * LEDGE, 0.55),
            (side * (W / 2.0 - 0.45), -total / 2.0, rise - 0.275)),
            name, "floor"))
        parts.append(_paint(brushkit.block(
            "pa_stubedge_%d" % int(side), (0.22, total - 2 * LEDGE, 0.24),
            (side * (W / 2.0 - 0.9), -total / 2.0, rise - 0.12)),
            name, "trim"))
    meta = {
        "segment_count": segments, "vertical_step": step, "gap_size": gap,
        "worst_jump": worst, "max_safe_gap_at_step": allowed,
        "platform_anchors": anchors,
        "objective": ["platform_to_goal"],
    }
    return "shell_path_ascent", parts, total, rise, top, meta


def shell_path_stagger():
    """Six platforms alternating 1.6 m either side of the centre line.

    Same climb, made into a route. At `step` 0.50 the bound is 2.40 m, and
    a 3.2 m lateral change between neighbours costs 0.7 m of edge-to-edge
    clearance on top of a 2.20 m gap: the measured jump is 2.31 m.

    That is the whole design. A straight path is a sequence of the same
    jump; an alternating one is a sequence of jumps that each turn you, so
    a shooter on the end ledge is never at the same angle twice.
    """
    segments, step, gap, offset = 6, 0.50, 2.20, 1.60
    total, zs = _layout(segments, gap)
    rise = step * segments
    top = rise + 6.0
    name = "ps"
    parts = _shaft(name, total, top)
    parts += _ledge(name, "start", -LEDGE / 2.0, 0.0)
    parts += _ledge(name, "end", -total + LEDGE / 2.0, rise)
    stones = [((0.0, -LEDGE / 2.0), (W, LEDGE))]
    anchors = []
    for i, z in enumerate(zs):
        x = offset * (-1.0 if i % 2 == 0 else 1.0)
        y, h = -z, step * (i + 1)
        parts += _platform(name, i, x, y, h, (PLAT, PLAT))
        stones.append(((x, y), (PLAT, PLAT)))
        anchors.append([round(x, 2), round(h, 2), round(z, 2)])
    stones.append(((0.0, -total + LEDGE / 2.0), (W, LEDGE)))
    worst, allowed = _assert_reachable("shell_path_stagger", stones, step)
    # A rail down each wall at hand height, so the alternation reads as a
    # route somebody laid out rather than as platforms that drifted.
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "ps_rail_%d" % int(side), (0.16, total - 2 * LEDGE, 0.16),
            (side * (W / 2.0 - 0.12), -total / 2.0, rise / 2.0 + 1.1)),
            name, "trim"))
    meta = {
        "segment_count": segments, "vertical_step": step, "gap_size": gap,
        "lateral_offset": offset,
        "worst_jump": worst, "max_safe_gap_at_step": allowed,
        "platform_anchors": anchors,
        "objective": ["platform_to_goal"],
    }
    return "shell_path_stagger", parts, total, rise, top, meta


def shell_path_spans():
    """Three wide beams, flat, over the shortest legal run.

    `vertical_step` may be 0.0, and a path with no rise is a different
    chamber rather than an easier one: nothing is climbed, the landings are
    6.0 m wide instead of 2.5, and the jumps sit at 2.40 against the flat
    bound of 2.60. It is a crossing.

    What makes it dangerous is where `platform_path()` puts its enemies --
    on the END LEDGE, never on the route. Wide beams and no rise mean the
    far ledge is visible from the first step, so this is the one path in
    the family you cross while being shot at rather than while counting
    jumps.
    """
    segments, step, gap, beam = 3, 0.0, 2.40, 6.0
    total, zs = _layout(segments, gap)
    top = 6.0
    name = "pn"
    parts = _shaft(name, total, top)
    parts += _ledge(name, "start", -LEDGE / 2.0, 0.0)
    parts += _ledge(name, "end", -total + LEDGE / 2.0, 0.0)
    stones = [((0.0, -LEDGE / 2.0), (W, LEDGE))]
    anchors = []
    for i, z in enumerate(zs):
        y = -z
        parts += _platform(name, i, 0.0, y, 0.0, (beam, PLAT))
        stones.append(((0.0, y), (beam, PLAT)))
        anchors.append([0.0, 0.0, round(z, 2)])
    stones.append(((0.0, -total + LEDGE / 2.0), (W, LEDGE)))
    worst, allowed = _assert_reachable("shell_path_spans", stones, step)
    # The beams are structure, so they get the girder they would need: a
    # deep web under each one, running the full 6 m.
    for i, z in enumerate(zs):
        parts.append(_paint(brushkit.block(
            "pn_web_%d" % i, (beam, 0.36, 1.30), (0.0, -z, -1.15)),
            name, "wall"))
    meta = {
        "segment_count": segments, "vertical_step": step, "gap_size": gap,
        "beam_width": beam,
        "worst_jump": worst, "max_safe_gap_at_step": allowed,
        "platform_anchors": anchors,
        "objective": ["platform_to_goal"],
    }
    return "shell_path_spans", parts, total, 0.0, top, meta


SHELLS = [shell_path_ascent, shell_path_stagger, shell_path_spans]


def main():
    common.reset_scene()
    report = {}
    for builder in SHELLS:
        name, parts, total, rise, top, meta = builder()
        seg = meta["segment_count"]
        if not (SEG_MIN <= seg <= SEG_MAX):
            raise AssertionError(
                "%s: %d segments is outside zone.py's %d-%d."
                % (name, seg, SEG_MIN, SEG_MAX))
        obj = common.join(parts, name)
        common.uv_project_world(obj, materials.ARCH_DENSITY,
                                materials.ARCH_SIZE)
        entry = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "room",
                                  tier="architecture",
                                  texture_size=materials.ARCH_SIZE,
                                  anchor="entrance", check_flat=False)
        entry.update(meta)
        # THE ONE THAT IS NOT LIKE THE OTHERS. Every shell before this
        # family exited at grade; `platform_path()` returns
        # `Vector3(0, rise, total)`, because you leave at the top of what
        # you climbed.
        entry["exit_offset"] = [0.0, round(rise, 2), round(total, 2)]
        entry["goal_anchor"] = [0.0, round(rise + 1.0, 2),
                                round(total - LEDGE, 2)]
        entry["check_anchor"] = [0.0, round(rise, 2),
                                 round(total - LEDGE / 2.0, 2)]
        entry["enemy_anchors"] = [[0.0, round(rise + 0.3, 2),
                                   round(total - LEDGE + i * 1.5, 2)]
                                  for i in range(2)]
        # The void is engine-owned and 40 m deep; these model 8 of it.
        entry["bounds"] = [[-W / 2.0, -40.0, 0.0],
                           [W, top + 41.0, round(total, 2)]]
        entry["interior"] = [W, top, round(total, 2)]
        entry["modelled_shaft_depth"] = SHAFT
        entry["fall_kill_y"] = FALL_KILL_Y
        report[name] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch017",
                       "shells", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
    print("[art] batch017 manifest -> %s" % out)


if __name__ == "__main__":
    main()
