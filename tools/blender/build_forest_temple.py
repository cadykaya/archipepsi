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
import materials  # noqa: E402
import palette as pal  # noqa: E402
import roomcollision  # noqa: E402

#: The nearest existing family. NOT a claim that the pack looks like the
#: house theme -- see the module docstring and COVERAGE.md §3.
THEME = "temple_ruin"
OUT = "batch054/forest_temple"
SIZE = materials.ARCH_SIZE
DENSITY = materials.ARCH_DENSITY

DIM = common.DIM
DOOR_W = DIM["door_width"]
DOOR_H = DIM["door_height"]
WALK_UP = 0.12
JUMP_APEX = DIM["jump_apex"]
#: One millimetre. See assert_opening_clear.
GRAZE = 0.001

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


# ---------------------------------------------------------------- gates

def assert_opening_clear(objects, label, width=DOOR_W, height=DOOR_H):
    """Nothing may narrow the engine's door opening. Not by a millimetre.

    The opening is `chamber_builders.gd`'s and the player walks through
    it. A surround is dressing around a hole; a surround that grows into
    the hole is a capability requirement the art lane invented.

    Measured against the geometry, not against the nominal numbers the
    builder used -- the same distinction `assert_parts_touch` exists for.
    """
    for obj in objects:
        lo, hi = common.world_box(obj)
        # Anything crossing the opening's own volume is refused. The
        # opening is centred on x=0 and rises from the floor.
        if hi[0] <= -width / 2.0 or lo[0] >= width / 2.0:
            continue
        # A TANGENCY IS NOT AN INTRUSION, and this gate made that
        # mistake on its first run. The lintel's underside is authored
        # AT `door_height` exactly; in floating point that arrives as
        # 3.1999999999999997 and a bare `>=` called it a 2.74 m
        # intrusion. `skiff_sweep` learned the same lesson in metres and
        # `manipulation_readiness` in newtons -- a millimetre here is
        # nothing beside a 3.2 m opening and far more than the
        # arithmetic.
        if lo[2] >= height - GRAZE:
            continue
        intrude = min(width / 2.0 - lo[0], hi[0] + width / 2.0)
        raise AssertionError(
            "%s: %s reaches into the %.2f x %.2f m door opening by %.3f m "
            "at height %.2f-%.2f. The opening is chamber_builders.gd's and "
            "the player walks through it; dress around it, never into it."
            % (label, obj.name, width, height, intrude, lo[2], hi[2]))


def assert_no_emitters(objects, label):
    """A housing, never a light.

    `export_content_pack.py` refuses an authored housing that carries its
    own `Light3D` -- illumination is engine-owned. This catches it at
    build time instead of at export, and it also refuses an emissive
    material, which is the same claim made a different way.
    """
    for obj in objects:
        if obj.type == "LIGHT":
            raise AssertionError(
                "%s: %s is a LIGHT. Illumination is engine-owned; this kit "
                "ships the housing a flame sits in and nothing that lights "
                "it." % (label, obj.name))
        for slot in obj.material_slots:
            mat = slot.material
            if mat is None or not mat.use_nodes:
                continue
            for node in mat.node_tree.nodes:
                if node.type == "EMISSION":
                    raise AssertionError(
                        "%s: %s carries an emission node. Same rule: the "
                        "housing is art, the light is the engine's."
                        % (label, obj.name))


def assert_no_footholds(objects, label):
    """No art-added route. Bounded above by the measured jump, because a
    rule with no upper bound refuses the top of a two-metre wall -- the
    correction Batch 049 made and Batch 048 inherited."""
    for obj in objects:
        lo, hi = common.world_box(obj)
        top = hi[2]
        if top <= WALK_UP + 1e-4 or top > JUMP_APEX:
            continue
        w = hi[0] - lo[0]
        d = hi[1] - lo[1]
        if w < 0.35 or d < 0.35:
            continue
        # A PLINTH IS NOT A ROUTE, and this is the refinement that
        # distinguishes them. The rule exists so art does not add a way
        # UP; a foothold with the asset's own body rising past the jump
        # directly above it leads nowhere -- you stand on a column base
        # and what you have reached is more column. Refusing that is
        # refusing correct architecture, and a gate that refuses correct
        # art is a gate that gets switched off.
        #
        # "Directly above" is measured, not assumed: another part of the
        # same asset must overlap this one in plan AND rise more than a
        # jump above its top.
        # ...AND "COVERED FROM ABOVE" MEANS COVERED, NOT GRAZED. The
        # first version of this exemption asked only whether some part
        # overlapped in plan and rose a jump above. Sabotage-tested with
        # a standalone ledge, it DID NOT FIRE: the lintel three metres up
        # overlapped the ledge by two centimetres, and two centimetres
        # bought a 2.16 x 0.58 m shelf an exemption.
        #
        # So the question is whether a STANDABLE PATCH SURVIVES. Subtract
        # the blocker's plan rectangle from the foothold's and look at
        # the four strips that are left; if any of them is still 0.35 m
        # square, the player can stand there and the exemption does not
        # apply.
        blocked = False
        for other in objects:
            if other is obj:
                continue
            olo, ohi = common.world_box(other)
            if ohi[0] <= lo[0] or olo[0] >= hi[0]:
                continue
            if ohi[1] <= lo[1] or olo[1] >= hi[1]:
                continue
            if ohi[2] <= top + JUMP_APEX:
                continue
            strips = (
                (olo[0] - lo[0], d),        # free to the left
                (hi[0] - ohi[0], d),        # free to the right
                (w, olo[1] - lo[1]),        # free in front
                (w, hi[1] - ohi[1]),        # free behind
            )
            if any(sw >= 0.35 and sd >= 0.35 for sw, sd in strips):
                continue                    # this one does not cover it
            blocked = True
            break
        if blocked:
            continue
        if True:
            raise AssertionError(
                "%s: %s gives a %.2f x %.2f m upward face at %.2f m -- "
                "above the %.2f m walk-up and inside the %.2f m jump, so a "
                "player can stand on it. Art does not add routes."
                % (label, obj.name, w, d, top, WALK_UP, JUMP_APEX))


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
    """Dressing. The floor has lost, too."""
    body = _b("ft_root_spine", (1.60, 0.34, 0.10), (0.0, 0.0, 0.05), "trim")
    parts = []
    for i, (x, y, ln) in enumerate((
            (-0.55, 0.26, 0.52), (0.10, -0.30, 0.64), (0.62, 0.22, 0.44))):
        parts.append(_b("ft_root_branch_%d" % i, (0.12, ln, 0.09),
                        (x, y, 0.045), "trim"))
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
    ("tp_ft_root_mass", root_mass, []),
    ("tp_ft_door_surround", door_surround, ["opening", "route"]),
]

#: What makes each one this pack's rather than the house family's.
DISTINCT = {
    "tp_ft_column": "a root has climbed it; the house column is clean",
    "tp_ft_wall_relief": "the panel is SPLIT, and the split is the subject",
    "tp_ft_alcove_torch": "timber hood over a stone bowl, not a metal sconce",
    "tp_ft_switch_housing": "batch043's wall-switch contract in timber",
    "tp_ft_root_mass": "floor dressing the house family has none of",
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
