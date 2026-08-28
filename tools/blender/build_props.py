"""Batch 001 G -- the universal prop mini-kit.

    .tools/blender/blender -b --python tools/blender/build_props.py

Seven props: the dressing vocabulary a room needs before it stops reading as
an empty test level. Universal, not theme-specific -- these are the pieces
that appear in every theme wearing that theme's paint, which is what makes
six material families read as one game.

Sizes are chosen against real things the player does. A crate is 1.0 m
because the player is 1.8 m and `MAX_VERTICAL_STEP` is 1.0 m, so a crate is
exactly the largest thing you can step onto without jumping -- and a crate
you can climb is a crate the level designer can use.
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

DIM = common.DIM
THEME = "concrete_facility"


def _finish(obj, name, canvas, relative, category="prop", bevel=None,
            anchor="floor"):
    if bevel:
        brushkit.bevel_prop(obj, bevel)
    common.set_origin(obj, anchor)
    common.uv_project_world(obj, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    image = canvas.to_blender(name)
    common.assign(obj, common.make_textured_material(
        name, image, roughness=pal.roughness(THEME)))
    info = common.export_glb(obj, relative, category, tier="prop",
                             texture_size=propkit.PROP_SIZE, anchor=anchor)
    common.save_texture(image, "batch001/%s.png" % name)
    return info


# ----------------------------------------------------------------------

def crate():
    """1.0 m. Exactly `MAX_VERTICAL_STEP`, so it is climbable by design."""
    size = DIM["max_vertical_step"]
    body = brushkit.block("crate_body", (size, size, size),
                          (0.0, 0.0, size / 2.0))
    parts = [body]
    # Corner irons: four thin plates that break the outline. A plain cube at
    # this scale reads as a placeholder no matter how well it is painted.
    iron = 0.09
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.append(brushkit.block(
                "crate_iron_%d_%d" % (int(sx), int(sy)),
                (iron, iron, size * 0.96),
                (sx * (size / 2.0 - iron / 2.0),
                 sy * (size / 2.0 - iron / 2.0), size / 2.0)))
    parts.append(brushkit.block("crate_lid", (size * 1.04, size * 1.04, 0.07),
                                (0.0, 0.0, size - 0.02)))
    return common.join(parts, "prop_crate"), 0.07


def utility_box():
    """A wall-mounted junction box with a hinged door and a conduit stub."""
    parts = [
        brushkit.block("ub_body", (0.52, 0.26, 0.72), (0.0, 0.0, 0.36)),
        brushkit.block("ub_door", (0.46, 0.05, 0.62), (0.0, -0.14, 0.36)),
        brushkit.block("ub_hinge", (0.05, 0.07, 0.62), (-0.22, -0.14, 0.36)),
        brushkit.block("ub_latch", (0.06, 0.08, 0.12), (0.20, -0.16, 0.36)),
        brushkit.prism("ub_conduit", 0.05, 0.30, 8, (0.14, 0.0, 0.86),
                       asset_name="prop_utility_box"),
    ]
    return common.join(parts, "prop_utility_box"), 0.05


def terminal():
    """A floor console: angled face, a plinth, a hood over the screen.

    The angled face is the whole design. A vertical screen at 1.2 m reads as
    a picture on a box; a face raked back 20 degrees reads as something a
    person stands at, and the player has to know which of those it is from
    the doorway.
    """
    parts = [
        brushkit.block("term_plinth", (0.86, 0.62, 0.18), (0.0, 0.0, 0.09)),
        brushkit.block("term_body", (0.78, 0.54, 0.82), (0.0, 0.0, 0.59)),
        brushkit.wedge("term_rake", (0.78, 0.42, 0.34),
                       (0.0, -0.06, 1.17), axis="y", rotation_z=180.0),
        brushkit.block("term_hood", (0.82, 0.30, 0.09), (0.0, -0.14, 1.36)),
    ]
    for side in (-1.0, 1.0):
        parts.append(brushkit.block("term_leg_%d" % int(side),
                                    (0.08, 0.58, 0.20),
                                    (side * 0.35, 0.0, 0.28)))
    return common.join(parts, "prop_terminal"), 0.08


def pipe_cluster():
    """Three pipes on a common bracket, with a valve wheel on the middle one."""
    parts = []
    for i, (offset, radius) in enumerate(((-0.26, 0.10), (0.0, 0.14),
                                          (0.26, 0.08))):
        parts.append(brushkit.prism("pc_pipe_%d" % i, radius, 2.2, 8,
                                    (offset, 0.0, 1.1),
                                    asset_name="prop_pipe_cluster"))
        parts.append(brushkit.prism("pc_flange_%d" % i, radius * 1.5, 0.08, 8,
                                    (offset, 0.0, 1.55),
                                    asset_name="prop_pipe_cluster"))
    for z in (0.55, 1.85):
        parts.append(brushkit.block("pc_bracket_%.2f" % z,
                                    (0.72, 0.10, 0.12), (0.0, 0.0, z)))
    # The valve: a wheel and a stem, the one part of a pipe run that says a
    # person operates this.
    parts.append(brushkit.spin(
        brushkit.prism("pc_stem", 0.04, 0.22, 8, (0.0, -0.20, 1.25),
                       asset_name="prop_pipe_cluster"), "X", 90.0))
    parts.append(brushkit.spin(
        brushkit.tube("pc_wheel", 0.17, 0.12, 0.05, 8, (0.0, -0.30, 1.25),
                      asset_name="prop_pipe_cluster"), "X", 90.0))
    obj = common.join(parts, "prop_pipe_cluster")
    common.assert_fits(obj, "prop_pipe_cluster",
                       (DIM["prop_footprint"], DIM["prop_footprint"], None),
                       "PROP_FOOTPRINT is the spacing chamber_builders.gd "
                       "reserves for a prop.")
    return obj, None


def machinery_unit():
    """A floor-standing machine: housing, cowl, drum, service panel.

    Built by LAYERING discrete forms -- a plate on a housing on a base --
    rather than by scattering small ornament. Every added form breaks the
    outline or catches light differently; one that does neither is noise
    with a triangle cost.
    """
    parts = [
        brushkit.block("mach_base", (1.30, 0.94, 0.16), (0.0, 0.0, 0.08)),
        brushkit.block("mach_housing", (1.14, 0.82, 1.28), (0.0, 0.0, 0.80)),
        brushkit.block("mach_panel", (0.72, 0.06, 0.78), (-0.22, -0.44, 0.82)),
        brushkit.block("mach_cowl", (1.20, 0.88, 0.20), (0.0, 0.0, 1.54)),
        brushkit.wedge("mach_shoulder", (1.20, 0.5, 0.26),
                       (0.0, 0.19, 1.77), axis="y"),
    ]
    parts.append(brushkit.spin(
        brushkit.prism("mach_drum", 0.28, 0.40, 8, (0.34, -0.30, 1.10),
                       asset_name="prop_machinery_unit"), "X", 90.0))
    parts.append(brushkit.grate("mach_vent", (0.5, 0.05, 0.34), 6, 0.045,
                                (0.30, -0.44, 0.42), axis="x"))
    for side in (-1.0, 1.0):
        parts.append(brushkit.block("mach_foot_%d" % int(side),
                                    (0.16, 0.98, 0.24),
                                    (side * 0.54, 0.0, 0.12)))
    obj = common.join(parts, "prop_machinery_unit")
    common.assert_fits(obj, "prop_machinery_unit",
                       (DIM["prop_footprint"], DIM["prop_footprint"], None),
                       "PROP_FOOTPRINT is the spacing chamber_builders.gd "
                       "reserves for a prop.")
    return obj, None


def debris_pile():
    """The broken variant: a collapsed version of the kit's own vocabulary.

    Deliberately made of pieces the player has already seen intact. Debris
    invented from scratch reads as scenery; debris made of a crate that lost
    a side and a length of the pipe run reads as something having HAPPENED
    here, which is the only reason to spend a prop slot on rubble.
    """
    parts = [
        brushkit.block("deb_slab", (0.92, 0.74, 0.22), (0.0, 0.0, 0.11),
                       rotation_z=17.0),
        brushkit.block("deb_crate", (0.60, 0.56, 0.50), (0.22, 0.18, 0.33),
                       rotation_z=-24.0),
        brushkit.wedge("deb_panel", (0.66, 0.50, 0.40), (-0.22, -0.10, 0.28),
                       axis="y", rotation_z=52.0),
        brushkit.block("deb_plate", (0.48, 0.36, 0.07), (0.10, -0.30, 0.55),
                       rotation_z=-8.0),
    ]
    pipe = brushkit.prism("deb_pipe", 0.10, 0.92, 8, (-0.08, 0.26, 0.15),
                          asset_name="prop_debris")
    parts.append(brushkit.spin(brushkit.spin(pipe, "X", 90.0), "Z", 20.0))
    parts.append(brushkit.block("deb_chunk_a", (0.24, 0.22, 0.19),
                                (0.42, -0.26, 0.10), rotation_z=33.0))
    parts.append(brushkit.block("deb_chunk_b", (0.19, 0.28, 0.16),
                                (-0.41, 0.28, 0.08), rotation_z=-41.0))
    obj = common.join(parts, "prop_debris")
    common.assert_fits(obj, "prop_debris",
                       (DIM["prop_footprint"], DIM["prop_footprint"], None),
                       "PROP_FOOTPRINT is the spacing chamber_builders.gd "
                       "reserves for a prop.")
    return obj, None


def warning_sign():
    """A wall placard on a bracket. Universal hazard colours only."""
    parts = [
        brushkit.block("sign_face", (0.62, 0.04, 0.44), (0.0, 0.0, 0.0)),
        brushkit.block("sign_bracket", (0.10, 0.14, 0.10), (0.0, 0.08, 0.0)),
    ]
    for sx in (-1.0, 1.0):
        parts.append(brushkit.block("sign_ear_%d" % int(sx),
                                    (0.05, 0.06, 0.10),
                                    (sx * 0.30, 0.04, 0.0)))
    return common.join(parts, "prop_warning_sign"), None


PROPS = [
    ("prop_crate", crate, lambda: propkit.painted_metal(
        THEME, "crate", label="04")),
    ("prop_utility_box", utility_box, lambda: propkit.painted_metal(
        THEME, "utility_box", label="hv", band=False)),
    ("prop_terminal", terminal, lambda: propkit.console(
        THEME, "terminal", label="rdy")),
    ("prop_pipe_cluster", pipe_cluster, lambda: propkit.bare_metal(
        THEME, "pipe_cluster")),
    ("prop_machinery_unit", machinery_unit, lambda: propkit.painted_metal(
        THEME, "machinery_unit", label="p 12", wear=0.18)),
    ("prop_debris", debris_pile, lambda: propkit.bare_metal(
        THEME, "debris", wear=0.3)),
    # A sign is bolted to a wall, not stood on the floor: anchor "wall" puts
    # its BACK face at Y 0 so it sits flush against a wall plane.
    ("prop_warning_sign", warning_sign, lambda: propkit.placard(
        THEME, "warning_sign", label="danger"), "wall"),
]


def main():
    common.reset_scene()
    report = {}
    for entry in PROPS:
        name, builder, painter = entry[0], entry[1], entry[2]
        anchor = entry[3] if len(entry) > 3 else "floor"
        obj, bevel = builder()
        report[name] = _finish(obj, name, painter(),
                               "batch001/props/%s.glb" % name, bevel=bevel,
                               anchor=anchor)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch001",
                       "props", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
