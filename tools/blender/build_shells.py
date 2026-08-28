"""Batch 015 -- room shells, starting with the corridor family.

    .tools/blender/blender -b --python tools/blender/build_shells.py

`ASSET_INVENTORY.md` §7 is L3 and had nothing in it. It replaces
`chamber_builders.build`'s five procedural chamber types, and it is the
level the owner named as the point of the whole tier: *stop Epsilon from
visibly repeating one room*.

## What a shell asset IS, decided here

The engine's chambers are **parametric** -- `corridor()` reads `length`,
`width` and a height that grows if the chamber carries an affordance -- so a
shell cannot be one mesh that fits every case, and the owner ruled out the
lazy alternative:

> Do not stretch collision-critical shells generically just to create
> variants. Prefer authored discrete forms / size classes where gameplay
> geometry matters.

So a shell is **one glb at one discrete size**, built from the same
primitives as everything else, carrying the interior structure that makes it
that shell rather than a box. And because the owner also asked shells to
*expose semantic intent rather than arbitrary resource paths*, each one's
manifest entry carries what the engine needs to USE it:

    exit_offset        where the next chamber attaches, in Godot metres
    bounds             the AABB, so zone.py can place it without loading it
    check_anchor       where a Check stands, if this chamber carries one
    enemy_anchors      where a fight starts from
    affordance_anchor  corridors are the ONLY chamber that may carry a
                       feature, so only corridors declare this
    sightline          how far down the run the FLOOR stays visible from
                       the entrance at eye height -- measurable off the
                       review render, not a mood word

Four corridors that differ in length and dressing are one corridor; four
that differ in **what you can see and where you can stand** are four rooms.
But `sightline` is only one of the axes the owner named, and it is the one
easiest to claim falsely: recesses cut into the side of a straight lane do
not shorten it. `shell_corridor_bays` earns its place on **routing,
encounter and Check placement** instead, and says 16.0 because that is what
the render shows.

## The four, and the gameplay difference each one is for

| Shell | Size | What it does that the others do not |
| --- | --- | --- |
| `shell_corridor_narrow` | 4.0 × 14 m | `CORRIDOR_WIDTH_MIN`, no cover, total sightline. The pressure corridor: a brute fills the lane and there is nowhere to go |
| `shell_corridor_bays` | 6.0 × 16 m | recessed side bays every 4 m, alternating. The sightline is still total; what changes is that there is somewhere to BE that is not the lane -- cover, a flank, and the only corridor with pockets a Check can sit in off the walking line |
| `shell_corridor_stepped` | 5.0 × 16 m | a 1.0 m step mid-run and a ledge above it. Verticality inside a corridor, and the step is exactly `MAX_VERTICAL_STEP` so it is walkable, not a wall |
| `shell_corridor_gallery` | 8.0 × 20 m | a walkway down one side at 2.6 m, out of jump reach. Two routes, high ground, and the only corridor where a ranged enemy can hold above you |

Every dimension is inside `zone.py`'s corridor bounds -- 6 to 30 m long,
4 to 10 m wide -- and the ceiling is `CORRIDOR_HEIGHT` except where a
feature needs more, which is `corridor()`'s own rule.

## Orientation

`corridor()` returns `exit_offset = Vector3(0, 0, length)`: the run is along
**Godot +Z**. glTF maps Blender +Y to Godot -Z, so these are built along
Blender **-Y** and export running the way the engine expects, with no yaw
for anyone to remember.
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
OUT = "batch015/shells"

DIM = common.DIM
WALL = DIM["wall_thickness"]              # 0.40
CEIL = DIM["corridor_height"]             # 3.60
STEP = DIM["max_vertical_step"]           # 1.00
LANE = DIM["brute_lane"]                  # 2.60
REACH = DIM["out_of_jump_reach"] if "out_of_jump_reach" in DIM else 2.10
W_MIN = DIM["corridor_width_min"]         # 4.00
W_MAX = DIM["corridor_width_max"]         # 10.00
L_MIN = DIM["corridor_length_min"]        # 6.00
L_MAX = DIM["corridor_length_max"]        # 30.00

_IMAGES = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("shell_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, name, role):
    common.assign(obj, common.make_textured_material(
        "%s_%s" % (name, role), _image(role), roughness=pal.roughness(THEME)))
    return obj


def _tube(name, width, length, height, openings=()):
    """Floor, two walls and a ceiling. The envelope every corridor has.

    Built along -Y so the run exports along Godot +Z, which is where
    `corridor()` puts its `exit_offset`.

    `openings` is a list of `(side, centre_y, span)` the walls must SKIP.
    Without it a bay is a sealed room behind a solid wall -- which is what
    the first pass built, and the entry render showed a plain tube with the
    four bays invisible behind it. A recess you cannot see into is not a
    recess; it is wasted geometry with a good docstring.
    """
    mid = -length / 2.0
    parts = [
        _paint(brushkit.block("%s_floor" % name, (width, length, 0.50),
                              (0.0, mid, -0.25)), name, "floor"),
        _paint(brushkit.block("%s_ceil" % name, (width, length, WALL),
                              (0.0, mid, height + WALL / 2.0)), name,
               "ceiling"),
    ]
    for side in (-1.0, 1.0):
        gaps = sorted((c - sp / 2.0, c + sp / 2.0)
                      for s_, c, sp in openings if s_ == side)
        # Wall runs are what is LEFT between the gaps, along -Y from 0.
        edges = [0.0]
        for lo, hi in gaps:
            edges += [lo, hi]
        edges.append(-length)
        for i in range(0, len(edges) - 1, 2):
            top, bottom = edges[i], edges[i + 1]
            span = top - bottom
            if span <= 0.01:
                continue
            centre = (top + bottom) / 2.0
            parts.append(_paint(brushkit.block(
                "%s_wall_%d_%d" % (name, int(side), i),
                (WALL, span, height),
                (side * (width + WALL) / 2.0, centre, height / 2.0)),
                name, "wall"))
            # A skirting, the second rhythm the Batch 001 review asked for.
            parts.append(_paint(brushkit.block(
                "%s_skirt_%d_%d" % (name, int(side), i),
                (0.10, span, 0.22),
                (side * (width / 2.0 - 0.05), centre, 0.11)), name, "trim"))
    return parts


def shell_corridor_narrow():
    """4.0 m of `CORRIDOR_WIDTH_MIN`, 14 m long, and deliberately empty.

    `BRUTE_LANE` is 2.60 and the walls are 4.00 apart, so a brute leaves
    0.70 m either side: this is the corridor you cannot get past. It has no
    cover, no bay and no step, and that absence is the design -- a family of
    four rooms needs one that is pure pressure, or the other three have
    nothing to be a relief from.

    Its only structure is a services band overhead, which is where
    `corridor()` already puts a pipe.
    """
    width, length = W_MIN, 14.0
    parts = _tube("cn", width, length, CEIL)
    parts.append(_paint(brushkit.block("cn_tray", (0.44, length - 0.4, 0.14),
                                       (width / 2.0 - 0.5, -length / 2.0,
                                        CEIL - 0.42)), "cn", "accent"))
    for i in range(4):
        y = -1.8 - i * 3.4
        parts.append(_paint(brushkit.block("cn_hanger_%d" % i,
                                           (0.09, 0.09, 0.40),
                                           (width / 2.0 - 0.5, y, CEIL - 0.2)),
                            "cn", "trim"))
    meta = {
        "sightline": length,
        "check_anchor": [0.0, 0.0, length - 2.0],
        "enemy_anchors": [[0.0, 0.0, length * 0.55]],
        "affordance_anchor": [0.0, 0.0, length * 0.5],
    }
    return "shell_corridor_narrow", parts, width, length, CEIL, meta


def shell_corridor_bays():
    """6.0 x 16 m with recessed bays every 4 m, alternating sides.

    The bays are what a Check needs: `corridor()` places one on the centre
    line, which puts the thing the player must walk up to in the middle of
    the lane a brute is coming down. A 1.6 m deep bay is off the walking
    line, still visible from the run, and gives cover to whoever gets there
    first.

    Alternating sides matters more than the bays themselves. Both sides at
    once is one wide corridor; alternating gives a player crossing under
    fire a reason to zig-zag, and gives whoever holds a bay a flank on the
    lane rather than a head-on stand-off.

    It does NOT break the sightline, and the first version of this file
    claimed it did -- `sightline: 6.4` against a render showing all 16 m of
    clear floor. A recess in the side of a straight lane is cover, not
    occlusion. The number is what the render measures.
    """
    width, length, bay, span = 6.0, 16.0, 1.6, 2.8
    placements = [(-1.0 if i % 2 == 0 else 1.0, -2.6 - i * 3.6)
                  for i in range(4)]
    parts = _tube("cb", width, length, CEIL,
                  openings=[(side, y, span) for side, y in placements])
    anchors = []
    for i, (side, y) in enumerate(placements):
        x = side * (width / 2.0 + bay / 2.0)
        # The bay's own three sides -- back, and one at each end. The fourth
        # is the gap `_tube` left in the corridor wall.
        parts.append(_paint(brushkit.block("cb_bayback_%d" % i,
                                           (WALL, span, CEIL),
                                           (side * (width / 2.0 + bay), y,
                                            CEIL / 2.0)), "cb", "wall"))
        for end in (-1.0, 1.0):
            parts.append(_paint(brushkit.block(
                "cb_bayend_%d_%d" % (i, int(end)), (bay, WALL, CEIL),
                (x, y + end * span / 2.0, CEIL / 2.0)), "cb", "wall"))
        parts.append(_paint(brushkit.block("cb_bayfloor_%d" % i,
                                           (bay, span, 0.50),
                                           (x, y, -0.25)), "cb", "floor"))
        parts.append(_paint(brushkit.block("cb_bayceil_%d" % i,
                                           (bay, span, WALL),
                                           (x, y, CEIL + WALL / 2.0)),
                            "cb", "ceiling"))
        # A head over the opening, so the recess reads as cut rather than
        # as a hole somebody forgot to fill.
        parts.append(_paint(brushkit.block("cb_bayhead_%d" % i,
                                           (0.30, span + 0.4, 0.42),
                                           (side * (width / 2.0), y,
                                            CEIL - 0.21)), "cb", "trim"))
        anchors.append([round(x, 2), 0.0, round(-y, 2)])
    meta = {
        "sightline": length,
        "check_anchor": anchors[1],
        "bay_anchors": anchors,
        "enemy_anchors": [anchors[0], anchors[2]],
        "affordance_anchor": [0.0, 0.0, length * 0.5],
    }
    return "shell_corridor_bays", parts, width, length, CEIL, meta


def shell_corridor_stepped():
    """5.0 x 16 m with a 1.00 m step mid-run and a ledge over the low half.

    The step is exactly `MAX_VERTICAL_STEP`, so it is walkable and reads as
    walkable -- a corridor that raised its floor by 1.2 m would be a wall
    with a lie painted on it. Standing on the high half you can see the
    whole low half; standing on the low half the step hides the far floor,
    which is the only sightline break in the family that costs nothing to
    walk through.

    The ledge above the low half is at 2.60 m, `SAFE_BASE_JUMP_GAP`'s own
    number and above `JUMP_APEX`: reachable from the high side, not from
    the low one.
    """
    width, length = 5.0, 16.0
    parts = _tube("cs", width, length, CEIL + STEP)
    half = length / 2.0
    # The raised half of the floor, and the riser that makes it walkable.
    parts.append(_paint(brushkit.block("cs_high", (width, half, STEP),
                                       (0.0, -length + half / 2.0,
                                        STEP / 2.0)), "cs", "floor"))
    parts.append(_paint(brushkit.block("cs_riser", (width, 0.30, STEP + 0.12),
                                       (0.0, -half - 0.15, (STEP + 0.12) / 2.0)),
                        "cs", "trim"))
    # A ledge over the low half, reachable from the high side only.
    parts.append(_paint(brushkit.block("cs_ledge", (2.2, 4.0, 0.30),
                                       (width / 2.0 - 1.1, -half + 2.0,
                                        2.60)), "cs", "floor"))
    for i in range(2):
        parts.append(_paint(brushkit.block("cs_bracket_%d" % i,
                                           (0.22, 0.22, 0.55),
                                           (width / 2.0 - 0.3,
                                            -half + 0.7 + i * 2.6, 2.18)),
                            "cs", "trim"))
    meta = {
        "sightline": half,
        "check_anchor": [round(width / 2.0 - 1.1, 2), 2.90, round(half - 2.0, 2)],
        "enemy_anchors": [[0.0, STEP, round(length - 3.0, 2)],
                          [0.0, 0.0, 3.0]],
        "affordance_anchor": [0.0, 0.0, round(half - 1.0, 2)],
        "step_height": STEP,
        "ledge_height": 2.60,
    }
    return "shell_corridor_stepped", parts, width, length, CEIL + STEP, meta


def shell_corridor_gallery():
    """8.0 x 20 m with a walkway at 2.60 m down one side.

    The only corridor in the family with two routes, and the only one where
    something can hold above you. 2.60 m is out of a base jump's reach, so
    the gallery is grapple or stair territory -- the stair at its near end
    is `arch_stair`'s own 0.25 m riser, so the two kits agree.

    8.0 m wide is twice `BRUTE_LANE`, which is the point: this is the
    corridor a fight can happen in rather than one a fight happens *to* you
    in.
    """
    width, length = 8.0, 20.0
    parts = _tube("cg", width, length, CEIL + 1.4)
    deck, rail = 2.60, 0.30
    gx = width / 2.0 - 1.3
    parts.append(_paint(brushkit.block("cg_deck", (2.6, 14.0, rail),
                                       (gx, -length + 8.0, deck)),
                        "cg", "floor"))
    parts.append(_paint(brushkit.block("cg_rail", (0.14, 14.0, 0.95),
                                       (gx - 1.3, -length + 8.0, deck + 0.62)),
                        "cg", "trim"))
    for i in range(4):
        parts.append(_paint(brushkit.block("cg_post_%d" % i,
                                           (0.26, 0.26, deck),
                                           (gx - 1.1, -3.0 - i * 3.6,
                                            deck / 2.0)), "cg", "trim"))
    # A stair up at the near end: eight 0.325 m risers over 3.2 m.
    steps = 8
    for i in range(steps):
        rise = deck / steps
        parts.append(_paint(brushkit.block(
            "cg_step_%d" % i, (2.4, 0.40, rise * (i + 1)),
            (gx, -1.2 - i * 0.40, rise * (i + 1) / 2.0)), "cg", "floor"))
    meta = {
        "sightline": length,
        "check_anchor": [round(gx, 2), round(deck + rail / 2.0, 2), 15.0],
        "enemy_anchors": [[round(gx, 2), round(deck + rail / 2.0, 2), 12.0],
                          [round(-gx, 2), 0.0, 8.0]],
        "affordance_anchor": [round(-gx, 2), 0.0, round(length * 0.5, 2)],
        "gallery_height": deck,
    }
    return "shell_corridor_gallery", parts, width, length, CEIL + 1.4, meta


SHELLS = [shell_corridor_narrow, shell_corridor_bays,
          shell_corridor_stepped, shell_corridor_gallery]


def main():
    common.reset_scene()
    report = {}
    for builder in SHELLS:
        name, parts, width, length, height, meta = builder()
        if not (W_MIN <= width <= W_MAX and L_MIN <= length <= L_MAX):
            raise AssertionError(
                "%s: %.1f x %.1f m is outside zone.py's corridor bounds "
                "(%.0f-%.0f m wide, %.0f-%.0f m long). Godot owns these."
                % (name, width, length, W_MIN, W_MAX, L_MIN, L_MAX))
        obj = common.join(parts, name)
        # NO `set_origin`. Every anchor in `common` centres at least one
        # horizontal axis, and a chamber's origin is not its centre: it is
        # its ENTRANCE, on the floor, on the centre line -- which is where
        # `corridor()` puts z 0 and what `exit_offset = (0, 0, length)`
        # counts from. The primitives already build there, so leaving the
        # origin alone is the correct anchor and there is no enum for it.
        common.uv_project_world(obj, materials.ARCH_DENSITY,
                                materials.ARCH_SIZE)
        entry = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "room",
                                  tier="architecture",
                                  texture_size=materials.ARCH_SIZE,
                                  anchor="entrance", check_flat=False)
        # THE CONTRACT. `corridor()` returns exit_offset and bounds today;
        # an authored shell has to hand back the same, plus the intent the
        # procedural version never had -- where a Check stands, where a
        # fight starts, how far you can see.
        entry.update(meta)
        entry["exit_offset"] = [0.0, 0.0, length]
        entry["bounds"] = [[-width / 2.0, -1.0, 0.0], [width, height + 1.0,
                                                       length]]
        entry["interior"] = [width, height, length]
        report[name] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch015",
                       "shells", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
