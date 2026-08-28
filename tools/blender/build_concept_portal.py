"""Batch 001 C -- two portal-frame concepts.

    .tools/blender/blender -b --python tools/blender/build_concept_portal.py

The portal is where authored content meets generated content, literally: the
engine "automatically appends an exit portal after the final chamber"
(DESIGN 14.1), so this object always stands at the seam between a room
Epsilon composed and the Hub a human built. Both concepts are about that
seam.

**Silhouette and scale, not effects.** The brief says so and the engine
agrees -- `exit_portal.gd` already drives a core material through four
states and the art does not need to compete with it. What the frame has to
do is be recognisable as a way out from the far end of a 30 m corridor, and
be obviously more permanent than the room around it.

`exit_portal.gd` gives it a 3.0 x 4.0 x 1.0 m collision box and builds a
3.2 x 4.2 x 0.6 m frame. Those are Godot's.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"
#: The binding width is NOT exit_portal.gd's 3.2 m frame -- an authored
#: portal replaces that frame, so it may be wider. It is the narrowest
#: corridor Epsilon may ask for: `zone.py` bounds corridor width at 4.0 m,
#: and a portal wider than 3.6 m leaves under 200 mm of wall each side and
#: clips through it. Height is bounded by CORRIDOR_HEIGHT, which is 3.6 m --
#: so a portal taller than that only fits an arena, and both concepts are
#: built under it plus the arena's headroom.
PORTAL_BOX = (3.6, 1.3, 4.6)
APERTURE = (2.4, 3.4)


def _emissive(name, family="signal", strength=1.0):
    return common.make_signal_material(name, pal.universal(family, 0),
                                       pal.universal(family, 3),
                                       strength=strength, roughness=0.35)


def concept_a_blast():
    """A: BLAST FRAME.

    A manufactured pressure door surround: rams, a lintel beam, hazard
    trim. Its bet is that the exit is EQUIPMENT -- the most legible reading
    at distance, and the one that says most clearly "this was installed
    here", which is what a seam between authored and generated wants.
    """
    width, height = APERTURE
    parts = [
        brushkit.frame("cpa_frame", (width + 0.72, height + 0.60), 0.36, 0.72,
                       (0.0, 0.0, (height + 0.60) / 2.0)),
        brushkit.block("cpa_lintel", (width + 0.94, 0.86, 0.36),
                       (0.0, 0.0, height + 0.72)),
        brushkit.wedge("cpa_hood", (width + 0.94, 0.60, 0.30),
                       (0.0, -0.16, height + 1.05), axis="y",
                       rotation_z=180.0),
        brushkit.block("cpa_sill", (width + 0.90, 0.90, 0.18),
                       (0.0, 0.0, 0.09)),
    ]
    # Rams: the parts that say this thing MOVES, which is what separates a
    # door from a hole.
    for side in (-1.0, 1.0):
        x = side * (width / 2.0 + 0.42)
        parts.append(brushkit.prism("cpa_ram_%d" % int(side), 0.15, 2.10, 8,
                                    (x, -0.40, 1.35),
                                    asset_name="portal_a"))
        parts.append(brushkit.prism("cpa_rod_%d" % int(side), 0.07, 0.90, 8,
                                    (x, -0.40, 2.85),
                                    asset_name="portal_a"))
        parts.append(brushkit.block("cpa_shoe_%d" % int(side),
                                    (0.30, 0.34, 0.22), (x, -0.40, 0.20)))
        parts.append(brushkit.block("cpa_yoke_%d" % int(side),
                                    (0.30, 0.50, 0.20), (x, -0.28, 3.32)))
    band = brushkit.block("cpa_band", (width + 0.60, 0.10, 0.16),
                          (0.0, -0.40, height + 0.36))
    return parts, band


def concept_b_collar():
    """B: EXCAVATED COLLAR.

    A rough opening cut through structure, lined with a fitted metal collar
    that clearly arrived after the hole did. Its bet is that the exit is a
    WOUND IN THE ARCHITECTURE -- less legible as equipment, far more legible
    as the boundary of the space, and much more at home in a theme like
    temple_ruin where a blast door would be an intruder.
    """
    width, height = APERTURE
    parts = []
    # Ragged structural jambs: stepped blocks, no two the same width, which
    # is what stops a cut opening reading as a neatly modelled arch.
    steps = ((0.46, 0.0, 0.9), (0.34, 0.9, 1.9), (0.50, 1.9, 2.7),
             (0.30, 2.7, 3.5), (0.44, 3.5, height + 0.5))
    for side in (-1.0, 1.0):
        for i, (thick, z0, z1) in enumerate(steps):
            parts.append(brushkit.block(
                "cpb_jamb_%d_%d" % (int(side), i),
                (thick, 1.00, z1 - z0),
                (side * (width / 2.0 + thick / 2.0), 0.0, (z0 + z1) / 2.0)))
    parts.append(brushkit.block("cpb_head", (width + 1.10, 1.00, 0.62),
                                (0.0, 0.0, height + 0.31)))
    parts.append(brushkit.wedge("cpb_spall", (width + 0.60, 0.70, 0.34),
                                (0.0, -0.20, height + 0.79), axis="y"))
    # The collar: thin, machined, sitting proud of the ragged hole.
    parts.append(brushkit.frame("cpb_collar", (width + 0.30, height + 0.26),
                                0.16, 0.30, (0.0, -0.42,
                                             (height + 0.26) / 2.0)))
    for side in (-1.0, 1.0):
        for i in range(4):
            parts.append(brushkit.block(
                "cpb_stud_%d_%d" % (int(side), i), (0.11, 0.14, 0.11),
                (side * (width / 2.0 + 0.07), -0.56, 0.55 + i * 0.85)))
    parts.append(brushkit.block("cpb_step", (width + 0.20, 1.10, 0.16),
                                (0.0, -0.20, 0.08)))
    band = brushkit.block("cpb_band", (width + 0.10, 0.09, 0.13),
                          (0.0, -0.56, height + 0.06))
    return parts, band


CONCEPTS = [
    ("portal_a_blast", concept_a_blast),
    ("portal_b_collar", concept_b_collar),
]


def build_one(name, builder):
    parts, band = builder()
    shell = common.join(parts, name + "_shell")
    common.uv_project_world(shell, propkit.HERO_DENSITY, propkit.HERO_SIZE)
    common.assign(shell, common.make_textured_material(
        name + "_shell",
        propkit.hero_shell(THEME, name, "signal", label="out",
                           lit_band=False).to_blender(name + "_shell_tex"),
        roughness=pal.roughness(THEME)))
    common.assign(band, _emissive(name + "_band"))
    obj = common.join([shell, band], name)
    common.set_origin_floor_centre(obj)
    common.assert_fits(obj, name, PORTAL_BOX,
                       "A portal wider than 3.6 m clips the wall of the "
                       "narrowest corridor zone.py permits (4.0 m).")
    return common.export_glb(obj, "batch001/portal/%s.glb" % name,
                             "interactable", check_flat=False)


def main():
    common.reset_scene()
    report = {}
    for name, builder in CONCEPTS:
        report[name] = build_one(name, builder)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch001",
                       "portal", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
