"""Batch 001 F -- the common-architecture mini-kit.

    .tools/blender/blender -b --python tools/blender/build_architecture.py

Eight modules: enough to assemble one convincing small late-90s FPS room,
which is the only thing this batch is trying to prove. Every dimension that
touches the player comes from `engine_truth` -- the door is 2.4 x 3.2 m
because `chamber_builders.gd` says so, the wall is 0.4 m thick for the same
reason, and the railing clears the player's 1.8 m height because Godot's
collision does not care how the railing looks.

## The module grid

Modules are **4.0 m** on their long axis, and that is not arbitrary: at the
architecture density of 32 texels/m a 128px map covers exactly 4.0 m, so one
module is one texture tile and a wall of them tiles without a seam. It also
divides the room sizes Epsilon may ask for -- corridors are 6-30 m long and
4-10 m wide, arenas 10-28 m square.

## Why every module is box-mapped

Every asset in Batch 001, props included, is projected from world axes at a
fixed density rather than unwrapped with `smart_project`. A 1998 editor
projected the texture onto each brush face along that face's dominant axis
at a fixed world scale, and that is most of what the era looks like. It also
means modules butt together without a texture discontinuity, which
`smart_project` cannot promise: two independently-unwrapped wall sections
show a break in the grain at every seam.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import paintkit  # noqa: E402
import palette as pal  # noqa: E402

DIM = common.DIM
THEME = "concrete_facility"
MODULE = 4.0
ARCH_DENSITY = materials.ARCH_DENSITY
ARCH_SIZE = materials.ARCH_SIZE

PROP_DENSITY = pal.budgets()["texel_density"]["prop"]["target"]
PROP_SIZE = 64
PROP_METRES = PROP_SIZE / float(PROP_DENSITY)

_IMAGES = {}


def theme_image(role):
    """One shared image per role, painted once and reused by every module."""
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("arch_%s_%s" % (THEME, role))
    return _IMAGES[role]


def finish(obj, name, role, category, relative, tier="architecture",
           size=ARCH_SIZE, density=ARCH_DENSITY, image=None, anchor="floor"):
    """Origin, then UVs, then material, then every assertion, then export.

    The order matters and it is the one thing in this file worth memorising:
    UVs are projected from LOCAL coordinates, so the origin has to be final
    first. Projecting before moving the origin bakes the build position into
    the texture, and two modules that were built at different heights then
    tile against each other with the grain offset.
    """
    common.set_origin(obj, anchor)
    common.uv_project_world(obj, density, size)
    common.assign(obj, common.make_textured_material(
        name, image or theme_image(role), roughness=pal.roughness(THEME)))
    return common.export_glb(obj, relative, category, tier=tier,
                             texture_size=size, anchor=anchor)


# ----------------------------------------------------------------------
# the eight modules
# ----------------------------------------------------------------------

def wall_panel():
    """A plain 4 m wall section, 0.4 m thick -- the engine's own thickness."""
    return brushkit.block("wall_panel",
                          (MODULE, DIM["wall_thickness"], MODULE),
                          (0.0, 0.0, MODULE / 2.0))


def wall_ribbed():
    """A wall bay with four pilasters standing 0.22 m proud of the face.

    Added at the Batch 001 review, which found "every surface exposes the
    same exact 4 m panel rhythm". The fix is not less structure, it is a
    SECOND structure that alternates with the first -- and it is geometry
    rather than paint, because the review also asked for more local shadow
    and a painted rib casts none.

    0.22 m is chosen against the light: shallower than that and the shadow
    it throws under the room's own omni is too soft to read at 4 m.
    """
    parts = [brushkit.block("wr_face", (MODULE, DIM["wall_thickness"], MODULE),
                            (0.0, 0.0, MODULE / 2.0))]
    pitch = MODULE / 4.0
    for i in range(4):
        x = -MODULE / 2.0 + pitch * (i + 0.5)
        parts.append(brushkit.block(
            "wr_pilaster_%d" % i, (0.34, 0.22, MODULE),
            (x, -(DIM["wall_thickness"] / 2.0 + 0.11), MODULE / 2.0)))
        # A capital: the pilaster stops, rather than running off the top.
        parts.append(brushkit.block(
            "wr_cap_%d" % i, (0.46, 0.28, 0.16),
            (x, -(DIM["wall_thickness"] / 2.0 + 0.14), MODULE - 0.26)))
    obj = common.join(parts, "wall_ribbed")
    common.assert_fits(obj, "arch_wall_ribbed", (MODULE, None, None),
                       "A module that overruns its 4 m grid pokes through "
                       "the wall at the end of every corridor.")
    return obj


def floor_slab():
    """A 4 x 4 m floor slab.

    0.4 m thick to match the wall, so a floor edge seen from a lower room
    reads as the same construction as the walls around it -- a thin floor
    plate under a thick wall is the commonest tell that a room was made of
    unrelated parts.
    """
    return brushkit.block("floor_slab",
                          (MODULE, MODULE, DIM["wall_thickness"]),
                          (0.0, 0.0, DIM["wall_thickness"] / 2.0))


def ceiling_beam():
    """A ceiling bay with a downstand beam hanging into the room.

    Built in NEGATIVE Z, anchored "ceiling": the deck is at 0 and everything
    else hangs below it. The first version built it upward from 0 and
    anchored it to its own lowest point, which put the whole bay above the
    ceiling plane -- the room rendered with a flat white lid and the one
    piece of structure that exists to stop it reading as a lid was hidden
    behind it.

    The downstand is 0.45 m deep under a 4 m ceiling, which leaves 3.55 m --
    just under CORRIDOR_HEIGHT, so a bay is never lower than a corridor and
    a 1.8 m player never reads it as something to duck under.
    """
    parts = [
        brushkit.block("ceiling_deck", (MODULE, MODULE, 0.25),
                       (0.0, 0.0, -0.125)),
        # 0.60 deep, up from 0.45. The review asked for more structural
        # depth and local shadow; the downstand is the one piece in the kit
        # that throws a shadow band across the whole ceiling, and at 0.45 it
        # was throwing a thin one. 3.4 m of headroom remains under a 4 m
        # ceiling, still clear of a 1.8 m player and of CORRIDOR_HEIGHT.
        brushkit.block("ceiling_downstand", (MODULE, 0.56, 0.60),
                       (0.0, 0.0, -0.55)),
    ]
    # Haunches: a beam that is holding something up rather than hanging.
    for side in (-1.0, 1.0):
        parts.append(brushkit.wedge(
            "ceiling_haunch_%d" % int(side), (0.5, 0.5, 0.3),
            (side * (MODULE / 2.0 - 0.25), 0.0, -0.42), axis="y",
            rotation_z=0.0 if side > 0 else 180.0))
    return common.join(parts, "ceiling_beam")


def doorway():
    """A wall module carrying the engine's door opening, with a frame.

    2.4 x 3.2 m, from `chamber_builders.gd`. Those numbers are Godot's and
    the art does not get to round them for a nicer proportion: the player
    walks through this, and the AI places it.
    """
    wall = brushkit.wall_with_opening(
        "doorway_wall", (MODULE, DIM["wall_thickness"], MODULE),
        (DIM["door_width"], DIM["door_height"]))
    reveal = brushkit.frame(
        "doorway_frame",
        (DIM["door_width"] + 0.36, DIM["door_height"] + 0.18),
        0.18, DIM["wall_thickness"] + 0.14,
        (0.0, 0.0, (DIM["door_height"] + 0.18) / 2.0))
    # A lintel plate above the opening: the piece that reads as "way through"
    # from across a room, before any of the frame is legible.
    plate = brushkit.block(
        "doorway_plate", (DIM["door_width"] * 0.55, 0.08, 0.34),
        (0.0, -(DIM["wall_thickness"] / 2.0 + 0.04),
         DIM["door_height"] + 0.46))
    return common.join([wall, reveal, plate], "doorway")


def trim_rail():
    """A 4 m kick rail, 0.4 m tall, standing 0.12 m proud of the wall.

    Trim is the piece doing the job a bevel does in other art directions --
    see `derive_budgets.py` section 5. Archipepsi's architecture has no
    geometric bevels at all, because a bevelled module cannot butt flush
    against the next one, so the edge definition has to come from a
    physically separate piece and from paint.
    """
    parts = [
        brushkit.block("trim_body", (MODULE, 0.12, 0.4), (0.0, 0.0, 0.2)),
        brushkit.wedge("trim_cap", (MODULE, 0.12, 0.08),
                       (0.0, 0.0, 0.44), axis="y"),
    ]
    return common.join(parts, "trim_rail")


def railing():
    """A 4 m guard rail. Waist height on a 1.8 m player, so 1.05 m.

    Deliberately NOT tall enough to hide the drop it guards. A railing that
    occludes the hazard behind it is a railing that has made the room less
    readable, and readable gameplay surfaces are the point.
    """
    height = 1.05
    parts = []
    posts = 5
    for i in range(posts):
        # Inset by half a post so the module measures exactly 4.0 m; an
        # end post centred on the boundary makes every railing 4.09 m and
        # two of them in a row overlap by 90 mm.
        span = MODULE - 0.09
        x = -span / 2.0 + span * i / (posts - 1)
        parts.append(brushkit.block("rail_post_%d" % i,
                                    (0.09, 0.09, height), (x, 0.0, height / 2.0)))
    parts.append(brushkit.block("rail_top", (MODULE, 0.11, 0.09),
                                (0.0, 0.0, height - 0.045)))
    parts.append(brushkit.block("rail_mid", (MODULE, 0.07, 0.06),
                                (0.0, 0.0, height * 0.52)))
    parts.append(brushkit.block("rail_toe", (MODULE, 0.05, 0.12),
                                (0.0, 0.0, 0.06)))
    obj = common.join(parts, "railing")
    common.assert_fits(obj, "arch_railing", (MODULE, None, None),
                       "Two railings in a row would overlap.")
    return obj


def pipe_run():
    """A 4 m pipe on brackets, plus a vent box where it enters the wall.

    Eight-sided, because that is the era. `assert_segments` refuses more.

    The pipe is built upright and tipped, so the segment cap still applies
    to a real radius. Note the ORDER: rotate about the geometry's own centre
    FIRST, then translate. The first version rotated an already-positioned
    prism, and because the object's origin was at the world origin the 90
    degree turn swung the pipe's 2.55 m height out along +X -- a 4 m module
    that measured 5.95 m and would have poked through the wall at the end of
    every corridor. Nothing in the render showed it; `measure()` did.
    """
    height = 2.55
    pipe = brushkit.prism("pipe_main", 0.16, MODULE, 8, (0.0, 0.0, height),
                          asset_name="pipe_run")
    brushkit.spin(pipe, "Y", 90.0)
    parts = [pipe]

    for i in range(3):
        x = -MODULE / 2.0 + MODULE * (i + 0.5) / 3.0
        parts.append(brushkit.block("pipe_bracket_%d" % i,
                                    (0.1, 0.34, 0.30), (x, 0.0, height)))
        parts.append(brushkit.block("pipe_collar_%d" % i,
                                    (0.13, 0.40, 0.40), (x, 0.0, height)))
    # The vent box sits INSIDE the module's 4 m span, not past it.
    parts.append(brushkit.block("pipe_vent", (0.62, 0.30, 0.62),
                                (MODULE / 2.0 - 0.35, 0.0, height)))
    parts.append(brushkit.grate("pipe_vent_grate", (0.5, 0.06, 0.5), 5, 0.05,
                                (MODULE / 2.0 - 0.35, -0.17, height), axis="x"))
    obj = common.join(parts, "pipe_run")
    common.assert_fits(obj, "arch_pipe_run", (MODULE, None, None),
                       "A module that overruns its 4 m grid pokes through the "
                       "wall at the end of every corridor Epsilon builds.")
    return obj


def light_fixture():
    """A caged strip light. The one module that emits.

    Kept small and high: `theme_materials.gd` gives every theme a light
    colour and energy, and the fixture's job is to say WHERE the light in
    this room comes from, not to be the light.
    """
    parts = [
        brushkit.block("light_backplate", (1.5, 0.34, 0.14), (0.0, 0.0, 0.0)),
        brushkit.block("light_hood", (1.4, 0.30, 0.10), (0.0, -0.06, -0.10)),
    ]
    for side in (-1.0, 1.0):
        parts.append(brushkit.block("light_end_%d" % int(side),
                                    (0.1, 0.34, 0.26),
                                    (side * 0.7, 0.0, -0.06)))
    parts.append(brushkit.grate("light_cage", (1.36, 0.20, 0.02), 7, 0.035,
                                (0.0, -0.12, -0.16), axis="x"))
    lens = brushkit.block("light_lens", (1.3, 0.2, 0.06), (0.0, -0.05, -0.155))
    return common.join(parts, "light_fixture"), lens


# ----------------------------------------------------------------------
# build
# ----------------------------------------------------------------------

#: (name, builder, paint role, budget category, ANCHOR). The anchor is not
#: cosmetic: see common.ANCHORS for the room this got wrong.
MODULES = [
    ("arch_wall_panel", wall_panel, "wall", "architecture_module", "floor"),
    ("arch_floor_slab", floor_slab, "floor", "architecture_module", "floor"),
    ("arch_ceiling_beam", ceiling_beam, "ceiling", "architecture_module",
     "ceiling"),
    ("arch_wall_ribbed", wall_ribbed, "wall_ribbed", "architecture_module",
     "floor"),
    ("arch_doorway", doorway, "wall", "architecture_module", "floor"),
    ("arch_trim_rail", trim_rail, "trim", "architecture_module", "floor"),
    ("arch_railing", railing, "trim", "architecture_module", "floor"),
    # module_floor: the pipes are at 2.55 m within their bay and that height
    # is part of what the module IS.
    ("arch_pipe_run", pipe_run, "accent", "architecture_module",
     "module_floor"),
]


def main():
    common.reset_scene()
    report = {}
    for name, builder, role, category, anchor in MODULES:
        obj = builder()
        report[name] = finish(obj, name, role, category,
                              "batch001/architecture/%s.glb" % name,
                              anchor=anchor)

    # The light fixture is two materials: a body and an emissive lens, which
    # is the only place in the kit where a second material earns its slot.
    body, lens = light_fixture()
    # Do NOT move the body's origin before joining: the lens is positioned
    # in the same space and shifting one without the other pulls them apart.
    # The origin is set once, on the joined object, below.
    common.uv_project_world(body, ARCH_DENSITY, ARCH_SIZE)
    common.assign(body, common.make_textured_material(
        "arch_light_fixture", theme_image("trim"), roughness=pal.roughness(THEME)))
    light_hex, _energy = pal.light(THEME)
    # Dark albedo under the theme's own light colour -- see
    # make_signal_material.
    # A fixture lens IS meant to read as a lamp, so it goes to full
    # saturation -- the one place in the batch where clipping the brightest
    # channel is the intent rather than a mistake.
    common.assign(lens, common.make_signal_material(
        "arch_light_lens", pal.theme(THEME, "trim", 0), light_hex,
        saturation=1.0, roughness=0.2))
    fixture = common.join([body, lens], "arch_light_fixture")
    common.set_origin(fixture, "ceiling")
    report["arch_light_fixture"] = common.export_glb(
        fixture, "batch001/architecture/arch_light_fixture.glb",
        "architecture_module", anchor="ceiling")

    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch001",
                       "architecture", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
