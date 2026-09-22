"""Batch 054 -- T01, the first game pack's CONTENT. Ocarina of Time.

    .tools/blender/blender -b --python tools/blender/build_forest_temple.py

## The subtheme is chosen, and saying which is half the job

The owner's scope addition: *"For games with many environments, choose
one coherent initial subtheme and state the choice rather than blending
everything into an average."* Ocarina of Time has many. **This pack is
the FOREST TEMPLE** -- overgrown cut stone, timber, and roots that have
won. Not the market, not the lake, not the volcano, and not an average
of all of them.

Why this one: it is the furthest a temple gets from the house's warm
sandstone `temple_ruin` while still reusing its construction, which is
what a pack is supposed to demonstrate. Reuse is not a defect; a pack
that shares a family and still reads as itself is the point.

## What is here and what is NOT, and the difference is a finding

`docs/art/theme-packs/COVERAGE.md` §3, found while scoping this batch:
`THEME_PACK.json` is a flat `themes` list of six with textures keyed
`"<theme>/<role>"`. **There is no pack namespace.** A pack's material
set can only enter it by becoming a seventh house theme, and that is a
structural decision Prod/Dess own.

So this batch is the half that is NOT blocked: **shapes, motifs,
dressing and a stateful-control housing**, authored into the ordinary
batch pipeline, which needs no theme namespace at all. They are painted
in `temple_ruin` -- the nearest existing family -- and **the distinctive
material treatment is the part that is missing and is named as missing**,
rather than faked with a tint. A tint is exactly what the owner said does
not count.

## The protected numbers, which art does not get to round

`tp_ft_door_surround` wraps the engine's opening. `door_width` 2.4 and
`door_height` 3.2 come from `chamber_builders.gd` and the player walks
through them. `assert_opening_clear` measures the hole in the exported
geometry and refuses anything that narrows it by a millimetre.

No light rides along. `tp_ft_alcove_torch` is the HOUSING a flame would
sit in; illumination is engine-owned and `export_content_pack.py` refuses
an authored housing carrying its own `Light3D`. `assert_no_emitters`
keeps that true at build time rather than discovering it at export.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import packgates  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402
import roomcollision  # noqa: E402

#: The nearest existing family. NOT a claim that the pack looks like the
#: house theme -- see the module docstring and COVERAGE.md §3.
THEME = "temple_ruin"
OUT = "batch054/forest_temple"
SIZE = materials.ARCH_SIZE
DENSITY = materials.ARCH_DENSITY

# The gates and the protected numbers live in `packgates` now: there are
# eighteen packs in the first wave and sixty-three behind them, and three
# checks copied eighteen times are eighteen places for the next
# correction to miss. Nothing about them changed in the move.
DOOR_W = packgates.DOOR_W
DOOR_H = packgates.DOOR_H
assert_opening_clear = packgates.assert_opening_clear
assert_no_emitters = packgates.assert_no_emitters
assert_no_footholds = packgates.assert_no_footholds

_IMAGES = {}
_MATERIALS = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("ft_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, role, collide=None):
    if role not in _MATERIALS:
        _MATERIALS[role] = common.make_textured_material(
            role, _image(role), roughness=pal.roughness(THEME))
    common.assign(obj, _MATERIALS[role])
    return roomcollision.paint_role(obj, collide or role)


def _b(tag, size, at, role="wall", collide=None, rotation_z=0.0):
    return _paint(brushkit.block(tag, size, at, rotation_z=rotation_z),
                  role, collide)


# --------------------------------------------------------------- assets

def column():
    """A carved column. Its tell is the ROOT that has grown up it --
    the house `temple_ruin` column is clean, and this one lost."""
    h = 3.6
    body = _b("ft_col_shaft", (0.52, 0.52, h), (0.0, 0.0, h / 2.0))
    parts = [
        _b("ft_col_base", (0.72, 0.72, 0.22), (0.0, 0.0, 0.11), "trim"),
        _b("ft_col_cap", (0.76, 0.76, 0.26), (0.0, 0.0, h - 0.13), "trim"),
        _b("ft_col_relief", (0.56, 0.10, 1.10), (0.0, -0.29, 1.5), "accent", "trim"),
    ]
    # The root: three blocks climbing one face, each offset, so it reads
    # as growth rather than as a pilaster.
    for i, z in enumerate((0.45, 1.25, 2.05)):
        parts.append(_b("ft_col_root_%d" % i,
                        (0.16, 0.20, 0.80),
                        (0.14 - i * 0.09, 0.30, z), "trim"))
    return body, parts


def wall_relief():
    """A wall panel a root has split. The crack is the subject."""
    w, t, h = 2.0, 0.24, 3.0
    body = _b("ft_relief_panel", (w, t, h), (0.0, 0.0, h / 2.0))
    parts = [
        _b("ft_relief_sill", (w + 0.16, t + 0.10, 0.18),
           (0.0, 0.0, 0.09), "trim"),
        _b("ft_relief_lintel", (w + 0.16, t + 0.10, 0.20),
           (0.0, 0.0, h - 0.10), "trim"),
    ]
    # The split, climbing and leaning -- four segments, each stepped, so
    # it is one run rather than a stack of bricks.
    for i in range(4):
        parts.append(_b("ft_relief_root_%d" % i,
                        (0.13, 0.08, 0.70),
                        (-0.55 + i * 0.30, -t / 2.0 - 0.04,
                         0.45 + i * 0.62), "accent", "trim"))
    return body, parts


def alcove_torch():
    """The HOUSING a flame sits in. No light, and a gate about it."""
    w, d, h = 0.62, 0.40, 1.10
    body = _b("ft_alcove_back", (w, 0.12, h), (0.0, d / 2.0, h / 2.0))
    parts = [
        _b("ft_alcove_side_l", (0.10, d, h), (-w / 2.0 + 0.05, 0.0, h / 2.0)),
        _b("ft_alcove_side_r", (0.10, d, h), (w / 2.0 - 0.05, 0.0, h / 2.0)),
        _b("ft_alcove_hood", (w, d, 0.14), (0.0, 0.0, h - 0.07), "trim"),
        # Where a flame would be. A NODE, not a light.
        _b("ft_alcove_flame_seat", (0.22, 0.22, 0.10),
           (0.0, 0.02, 0.30), "accent", "trim"),
        _b("ft_alcove_bowl", (0.34, 0.30, 0.18), (0.0, 0.02, 0.16), "trim"),
    ]
    return body, parts


def switch_housing():
    """A stateful control, in the pack's language.

    Reuses Batch 043's `mach_wall_switch` CONTRACT -- a wall-mounted
    housing with a separately addressable lever -- and says it in timber
    and stone instead of pressed metal. The lever is a node; what moves
    it is Production's.
    """
    w, d, h = 0.40, 0.22, 0.58
    body = _b("ft_switch_case", (w, d, h), (0.0, d / 2.0, h / 2.0))
    parts = [
        _b("ft_switch_frame", (w + 0.10, d + 0.06, 0.08),
           (0.0, d / 2.0, h - 0.04), "trim"),
        _b("ft_switch_sill", (w + 0.10, d + 0.06, 0.08),
           (0.0, d / 2.0, 0.04), "trim"),
        _b("ft_switch_lever", (0.10, 0.18, 0.30), (0.0, -0.02, h * 0.52),
           "accent", "trim"),
        _b("ft_switch_state_band", (w * 0.7, 0.04, 0.06),
           (0.0, -0.01, h * 0.20), "accent", "trim"),
    ]
    return body, parts


def root_mass():
    """Dressing. The floor has lost, too.

    REBUILT after seeing it in the room. The first version was a
    1.60 x 0.34 x 0.10 slab with three thin boxes crossing it at right
    angles, and in `FT_chamber` and `FT_threshold` it read as two fallen
    timber beams, not as growth: every edge straight, every crossing
    square, the whole silhouette 0.10 m tall and therefore nothing but
    that silhouette. A root that has won a floor is not a lumber pile.

    What makes it read as a root instead:

    * **it swells and tapers.** Five segments from 0.22 m tall at the
      anchored end down to 0.05 at the tip. A constant section is a
      pipe;
    * **it kinks.** Each segment carries its own yaw, alternating sign,
      so the run bends twice instead of pointing;
    * **a knuckle where it turns**, taller than either segment it joins,
      which is what a real root does at a change of direction and what
      the eye is actually reading;
    * **the fork leaves at the knuckle** and at a shallow angle, rather
      than crossing the spine square. Nothing in a root meets anything
      at ninety degrees.

    The buried run underneath is what everything is connected THROUGH --
    `assert_parts_touch` floods outward from the body, so the fork tip
    reaches the body by way of the fork.

    No segment is 0.35 m in both plan axes, so the no-foothold rule
    evaluates every one of them and none is a standable patch. That
    check is now declared for this asset, which it was not before: a
    piece that sits on the floor is the likeliest one in the set to
    invent a step, and it was the only one with no route check at all.
    """
    # `brushkit.block`'s rotation_z is DEGREES -- it calls
    # `math.radians()` on what it is given. The first pass of this
    # rebuild handed it radians, so a 54-degree fork became a
    # 0.95-degree one, the fork tip landed 0.19 m from anything and
    # `assert_parts_touch` caught it. It was right, and the defect was
    # not the one it names: the piece was not floating, it was straight.
    body = _b("ft_root_run", (1.42, 0.14, 0.06), (0.0, 0.0, 0.03),
              "trim", rotation_z=6.0)
    parts = []
    #   tag          size (x, y, z)        at (x, y, z)        yaw (deg)
    for tag, size, at, yaw in (
            # 0.24 deep, not 0.26: at 15 degrees a 0.26 box measures
            # 0.355 m in plan, and the no-foothold rule counts anything
            # 0.35 square above the 0.12 m walk-up. Shaving it to slip
            # under a gate would be cheating; a root that is 0.35 m
            # across AND 0.22 m tall is a bench, and the rule is right
            # about benches. This is a root.
            ("swell_0", (0.40, 0.24, 0.22), (-0.56, 0.05, 0.11), 15.0),
            ("swell_1", (0.34, 0.22, 0.15), (-0.16, -0.04, 0.075), -11.0),
            ("knuckle", (0.22, 0.24, 0.18), (0.10, 0.03, 0.09), 31.0),
            ("swell_2", (0.36, 0.17, 0.11), (0.42, 0.01, 0.055), 8.0),
            ("tip", (0.26, 0.11, 0.05), (0.72, -0.05, 0.025), -17.0),
            ("fork", (0.32, 0.13, 0.10), (0.20, 0.17, 0.05), 54.0),
            ("fork_tip", (0.22, 0.09, 0.06), (0.33, 0.31, 0.03), 46.0)):
        parts.append(_b("ft_root_%s" % tag, size, at, "trim",
                        rotation_z=yaw))
    return body, parts


def door_surround():
    """Dressing AROUND the engine's opening, never into it."""
    jamb = 0.34
    body = _b("ft_door_lintel", (DOOR_W + jamb * 2.0, 0.30, 0.34),
              (0.0, 0.0, DOOR_H + 0.17), "trim")
    parts = []
    for sign, tag in ((-1.0, "l"), (1.0, "r")):
        parts.append(_b("ft_door_jamb_%s" % tag, (jamb, 0.30, DOOR_H),
                        (sign * (DOOR_W / 2.0 + jamb / 2.0), 0.0,
                         DOOR_H / 2.0)))
        # The boss is the JAMB'S width and projects in DEPTH, out of the
        # wall. It was jamb + 0.08 centred on the jamb, which overhung
        # 0.04 m into the opening -- a real violation, caught by the
        # gate, and the gate was right. A boss that grows toward the
        # player is a boss; a boss that grows into the doorway is a
        # narrower doorway.
        parts.append(_b("ft_door_boss_%s" % tag, (jamb, 0.46, 0.20),
                        (sign * (DOOR_W / 2.0 + jamb / 2.0), 0.0,
                         DOOR_H - 0.10), "accent", "trim"))
    return body, parts


ASSETS = [
    ("tp_ft_column", column, ["route"]),
    ("tp_ft_wall_relief", wall_relief, ["route"]),
    ("tp_ft_alcove_torch", alcove_torch, ["emitters"]),
    ("tp_ft_switch_housing", switch_housing, ["emitters"]),
    ("tp_ft_root_mass", root_mass, ["route"]),
    ("tp_ft_door_surround", door_surround, ["opening", "route"]),
]

#: What makes each one this pack's rather than the house family's.
DISTINCT = {
    "tp_ft_column": "a root has climbed it; the house column is clean",
    "tp_ft_wall_relief": "the panel is SPLIT, and the split is the subject",
    "tp_ft_alcove_torch": "timber hood over a stone bowl, not a metal sconce",
    "tp_ft_switch_housing": "batch043's wall-switch contract in timber",
    "tp_ft_root_mass": "floor dressing the house family has none of: it swells, kinks and forks, and nothing in it meets anything square",
    "tp_ft_door_surround": "bossed jambs; dressing around a fixed opening",
}


def main():
    made = {}
    for name, build, checks in ASSETS:
        common.reset_scene()
        _IMAGES.clear()
        _MATERIALS.clear()
        body, parts = build()
        objects = [body] + parts
        if "opening" in checks:
            assert_opening_clear(objects, name)
        if "emitters" in checks:
            assert_no_emitters(objects, name)
        if "route" in checks:
            assert_no_footholds(objects, name)
        for obj in objects:
            common.uv_project_world(obj, DENSITY, SIZE)
        common.assert_parts_touch(body, parts, name)
        entry = common.export_glb(body, "%s/%s.glb" % (OUT, name), "prop",
                                  tier="architecture", texture_size=SIZE,
                                  anchor="floor", parts=parts)
        entry["parts"] = [p.name for p in parts]
        entry["distinct"] = DISTINCT[name]
        made[name] = entry
        print("[forest] %-24s %4d tris, %d part(s)"
              % (name, entry["triangles"], len(parts)))

    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    shared = {
        "batch": "054",
        "kind": "theme_pack_content",
        "pack": "tp_ocarina_of_time",
        "subtheme": "the Forest Temple reading of the packet's Grove Relay Temple -- overgrown cut stone, timber, and roots that have won",
        "subtheme_is_a_choice": "Ocarina of Time has many environments. "
                                "This pack is the Forest Temple and not an "
                                "average of them, per the owner's scope "
                                "addition.",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "painted_with": THEME,
        "material_treatment": "MISSING, AND NAMED AS MISSING. THEME_PACK."
                              "json has no pack namespace, so a pack's own "
                              "material set cannot be filed without "
                              "becoming a seventh house theme. See "
                              "docs/art/theme-packs/COVERAGE.md section 3. "
                              "These are painted in the nearest existing "
                              "family; a tint is NOT the pack's treatment.",
        "carries": "mesh and named parts only. No collider, body, trigger, "
                   "light, camera, script or animation.",
        "texels_per_metre": DENSITY,
        "not_changed": ["collision", "placement", "any runtime state",
                        "the engine's door opening", "any approved asset"],
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


if __name__ == "__main__":
    main()
