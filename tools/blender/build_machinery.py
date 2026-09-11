"""Batch 043 -- the reusable machinery feedback kit. PROPOSAL.

    .tools/blender/blender -b --python tools/blender/build_machinery.py -- \
        docs/art/review/machinery_2026-09-11

VISUAL LANGUAGE ONLY. Design 1 §19.5, pinned by Design 6 §19: conduits are
presentation, never destructible, and carry no state. Nothing here is a
signal graph, a node type, an evaluation order or a package validator, and
this script does not invent a gameplay state machine so that a preview can
move. The five states are the five §19.5 already specifies.

## THE DEFECT THIS KIT EXISTS TO FIX

Batch 028's interaction kit declared a `state_visual` region on every
primitive and then exported each primitive as ONE mesh node with three
material slots. Measured, at this revision, with
`tools/content/inspect_glb_nodes.py`:

    int_wall_switch    1 mesh node, 3 surfaces:
                       ..._body, ..._accent, ..._cores

So the only handle a runtime has on that state region is
`set_surface_override_material(2, mat)`. That recolours it. It cannot hide
it, move it, scale it, give it its own shader, or animate it independently
of the body -- and four of the five conduit states need at least one of
those (a scrolling band, a growing fill, a lever that swings).

Every piece here exports its state regions as SEPARATE NAMED NODES as well
as separate material slots, through `common.export_glb(parts=...)`. A
runtime gets both handles and picks. The names are written into the manifest
so integration reads a contract instead of opening the .glb.

## WHAT IS NOT SETTLED HERE

Sizes, mounting heights and the 0.5 m clamp pitch are PROPOSED ART
DIMENSIONS. No runtime contract exists for machinery yet; when one arrives
these move to fit it, not the other way round.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import bmesh  # noqa: E402
import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"
OUT = "batch043/machinery"
DENSITY = 32.0                       # texels per metre, architecture budget
BAND_TILE = (64, 16)                 # the Glyph band, 2.00 m x 0.50 m
REVIEW = (sys.argv[sys.argv.index("--") + 1]
          if "--" in sys.argv else "docs/art/review/machinery_2026-09-11")


def _planar_uv(obj, origin, span, axis="y"):
    """Map every loop by a planar projection, so one texture pixel is
    exactly 1/DENSITY metres on both axes.

    The kit's band texture is 64x16, not a square atlas, so
    `common.uv_project_world` -- which solves one density against one
    `texture_size` -- cannot express it. This does, and `_assert_band_uv`
    below checks the result rather than trusting it.
    """
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv = mesh.uv_layers.active.data
    ox, oy, oz = origin
    su, sv = span
    for poly in mesh.polygons:
        for loop in poly.loop_indices:
            v = mesh.vertices[mesh.loops[loop].vertex_index].co
            if axis == "y":
                uv[loop].uv = ((v.x - ox) / su, (v.z - oz) / sv)
            else:
                uv[loop].uv = ((v.y - oy) / su, (v.z - oz) / sv)


def _assert_band_uv(obj, metres, tile):
    """One texture pixel is one 1/DENSITY-metre square. Both axes."""
    for i, (m, px) in enumerate(zip(metres, tile)):
        density = px / m
        if abs(density - DENSITY) > 0.01:
            raise AssertionError(
                "%s: %.2f texels/m on axis %d against the architecture "
                "budget of %.1f. A conduit that tiles at a different pitch "
                "from the wall behind it is a conduit that never lines up."
                % (obj.name, density, i, DENSITY))


def _attach(child, parent):
    """Parent without moving the child.

    Blender re-interprets a child's local matrix in its new parent's space
    the moment `.parent` is set, so a part attached AFTER `set_origin` moved
    the parent gets displaced by exactly that amount. Measured: the first
    conduit build put the state band 13 cm inside the wall, and the
    five-state render came back showing bare painted metal with no band on
    any of them. `matrix_parent_inverse` is the standard cancellation and
    it belongs in one helper, not at five call sites.
    """
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def _image(path, name):
    img = bpy.data.images.load(os.path.abspath(path))
    img.name = name
    return img


# ----------------------------------------------------------------------
# the three pieces
# ----------------------------------------------------------------------

def conduit_run():
    """A 2.00 m wall-mounted conduit: channel, clamps, and ONE band node.

    The band is the state. It is a separate object, so a runtime can scroll
    its UV for `active` and `pulse_travelling`, scale it from one end for
    `delayed`, and swap its texture for all five -- none of which a material
    slot on a merged mesh can do.
    """
    length, height, depth = 2.00, 0.50, 0.14
    body = [
        brushkit.block("cr_back", (length, depth * 0.45, height),
                       (0.0, depth * 0.28, height / 2.0)),
        brushkit.block("cr_rail_top", (length, depth, 0.07),
                       (0.0, 0.0, height - 0.035)),
        brushkit.block("cr_rail_bottom", (length, depth, 0.07),
                       (0.0, 0.0, 0.035)),
    ]
    for i in range(5):
        x = -length / 2.0 + 0.25 + i * 0.50        # the 0.5 m clamp pitch
        body.append(brushkit.block("cr_clamp_%d" % i,
                                   (0.06, depth * 1.25, height),
                                   (x, 0.0, height / 2.0)))
    shell = common.join(body, "mach_conduit_run")

    # The band quad is the channel's WHOLE face, not just the trough. The
    # 64x16 state texture is authored to register with the channel -- its
    # own transparency decides which rows light up -- so a band cropped to
    # the trough would have to crop the texture too, and then the channel
    # and the state would be two things that have to be kept in step by
    # hand. One footprint, one registration, no drift.
    # 13 mm proud of the rails' front face. The first build had it 1.6 mm
    # proud, which is inside the depth buffer's own noise at this range.
    band = brushkit.block("state_band", (length, 0.016, height),
                          (0.0, -0.075, height / 2.0))
    band.name = "state_band"
    _planar_uv(band, (-length / 2.0, 0.0, 0.0), (length, height))
    _assert_band_uv(band, (length, height), BAND_TILE)
    return shell, band, (length, depth * 1.25, height)


def wall_switch():
    """A setter. §33.8 requires the LEVER'S PHYSICAL POSITION to read, plus a
    legible indicator of its current target -- so the arm is its own node and
    can actually be turned, and the lens is its own node and can actually be
    lit."""
    body = [
        brushkit.block("ws_plate", (0.36, 0.07, 0.52), (0.0, 0.035, 0.26)),
        brushkit.block("ws_hood", (0.36, 0.13, 0.07), (0.0, 0.0, 0.50)),
        brushkit.block("ws_pivot", (0.10, 0.10, 0.10), (0.0, -0.04, 0.30)),
    ]
    shell = common.join(body, "mach_wall_switch")
    arm = brushkit.block("lever_arm", (0.06, 0.06, 0.26), (0.0, -0.09, 0.40))
    arm.name = "lever_arm"
    common.uv_project_world(arm, DENSITY, propkit.PROP_SIZE)
    # Proud of the plate face, not flush with it. At y=-0.005 the lens sat
    # INSIDE the plate and the first switch render had no visible indicator
    # at all -- a state region buried in the thing it reports on.
    lens = brushkit.block("state_lens", (0.22, 0.02, 0.09),
                          (0.0, -0.022, 0.13))
    lens.name = "state_lens"
    common.uv_project_world(lens, DENSITY, propkit.PROP_SIZE)
    return shell, [arm, lens], (0.36, 0.19, 0.52)


def receiver_lamp():
    """The thing a setter controls, reporting its own state back. Two lenses,
    not one: §33.8's "impassable predicated edge" wants a barrier that reads
    as a barrier of its type, and a receiver with a single lamp can only say
    on or off. Two say on, off, and disagreeing-with-its-input."""
    body = [
        brushkit.block("rl_housing", (0.44, 0.20, 0.34), (0.0, 0.0, 0.17)),
        brushkit.block("rl_cowl", (0.48, 0.24, 0.05), (0.0, 0.0, 0.345)),
        brushkit.block("rl_foot", (0.50, 0.26, 0.04), (0.0, 0.0, 0.02)),
    ]
    shell = common.join(body, "mach_receiver_lamp")
    lenses = []
    for i, x in enumerate((-0.10, 0.10)):
        lens = brushkit.block("state_lens_%d" % i, (0.14, 0.02, 0.14),
                              (x, -0.105, 0.18))
        lens.name = "state_lens_%d" % i
        common.uv_project_world(lens, DENSITY, propkit.PROP_SIZE)
        lenses.append(lens)
    return shell, lenses, (0.50, 0.26, 0.38)


# ----------------------------------------------------------------------

def main():
    common.reset_scene()
    made = []

    band_png = os.path.join(REVIEW, "png", "band_inactive.png")
    # A LENS IS NOT A CONDUIT. The band texture is authored to register with
    # the conduit channel at 32 texels/m; a 22 cm lens wearing it would show
    # one seventh of a chevron. Lenses ship a flat driven colour instead and
    # the runtime changes it -- which is the honest shape of "this region
    # reports a state" for a region too small to carry a pattern.
    LENS_DIM = "#4a5058"

    # 1. the conduit run
    shell, band, size = conduit_run()
    common.set_origin_group([shell, band], "wall")
    common.uv_project_world(shell, DENSITY, propkit.PROP_SIZE)
    canvas = propkit.painted_metal(THEME, "mach_conduit_run", wear=0.18)
    common.assign(shell, common.make_textured_material(
        "mach_conduit_run", canvas.to_blender("mach_conduit_run_t"),
        roughness=pal.roughness(THEME)))
    _attach(band, shell)
    common.assign(band, common.make_textured_material(
        "mach_conduit_run_state", _image(band_png, "band_inactive"),
        roughness=0.55))
    made.append(common.export_glb(shell, "%s/mach_conduit_run.glb" % OUT,
                                  "prop", anchor="wall", parts=[band]))
    common.save_texture(canvas.to_blender("mach_conduit_run_save"),
                        "batch043/mach_conduit_run.png")

    # 2. the wall switch
    common.reset_scene()
    shell, parts, size = wall_switch()
    common.set_origin_group([shell] + parts, "wall")
    common.uv_project_world(shell, DENSITY, propkit.PROP_SIZE)
    canvas = propkit.painted_metal(THEME, "mach_wall_switch", wear=0.16)
    common.assign(shell, common.make_textured_material(
        "mach_wall_switch", canvas.to_blender("mach_wall_switch_t"),
        roughness=pal.roughness(THEME)))
    mat_arm = common.make_textured_material(
        "mach_wall_switch_arm", canvas.to_blender("mach_wall_switch_a"),
        roughness=pal.roughness(THEME))
    for part in parts:
        _attach(part, shell)
    common.assign(parts[0], mat_arm)
    common.assign(parts[1], common.make_material(
        "mach_wall_switch_state", LENS_DIM, roughness=0.5))
    made.append(common.export_glb(shell, "%s/mach_wall_switch.glb" % OUT,
                                  "prop", anchor="wall", parts=parts))
    common.save_texture(canvas.to_blender("mach_wall_switch_save"),
                        "batch043/mach_wall_switch.png")

    # 3. the receiver
    common.reset_scene()
    shell, lenses, size = receiver_lamp()
    common.set_origin_group([shell] + lenses, "floor")
    common.uv_project_world(shell, DENSITY, propkit.PROP_SIZE)
    canvas = propkit.painted_metal(THEME, "mach_receiver_lamp", wear=0.20)
    common.assign(shell, common.make_textured_material(
        "mach_receiver_lamp", canvas.to_blender("mach_receiver_lamp_t"),
        roughness=pal.roughness(THEME)))
    state_mat = common.make_material(
        "mach_receiver_lamp_state", LENS_DIM, roughness=0.5)
    for lens in lenses:
        _attach(lens, shell)
        common.assign(lens, state_mat)
    made.append(common.export_glb(shell, "%s/mach_receiver_lamp.glb" % OUT,
                                  "prop", anchor="floor", parts=lenses))
    common.save_texture(canvas.to_blender("mach_receiver_lamp_save"),
                        "batch043/mach_receiver_lamp.png")

    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    with open(path, "w", encoding="utf-8") as handle:
        # Keyed by asset id, like every other batch manifest. The batch-wide
        # facts are repeated per entry rather than hoisted to the top level:
        # `check_docs_metrics.py` reads a manifest's keys AS asset ids, so a
        # top-level "batch" key would be reported as an undocumented asset
        # called "batch". Convention over tidiness, and the convention is a
        # checker's input.
        shared = {
            "batch": "043",
            "kind": "machinery_feedback",
            "status": "PROPOSAL -- presentation only; no signal graph, no "
                      "node types, no gameplay state machine",
            "design": "Design 1 §19.5 five conduit states, pinned by "
                      "Design 6 §19; Design 3 §33.8 in-world readability",
            "texels_per_metre": DENSITY,
            "band_tile_pixels": list(BAND_TILE),
            "band_tile_metres": [BAND_TILE[0] / DENSITY,
                                 BAND_TILE[1] / DENSITY],
            "how_to_drive": {
                "named_nodes": "every state region is its own node under the "
                               "asset root; fetch it by name and drive it "
                               "directly",
                "material_slots": "each named node also owns exactly one "
                                  "material slot, so "
                                  "`set_surface_override_material(0, m)` on "
                                  "the NODE is enough for a texture swap",
                "scroll": "set `uv1_offset.x` on the band's material for "
                          "`active` and `pulse_travelling`",
                "fill": "scale the band node on X from its -X end for "
                        "`delayed`; the texture does not move",
                "lever": "rotate `lever_arm` about its own X axis; the "
                         "pivot sits at the arm's base",
                "audio": "NOT SUPPLIED. §19.5's hum, arrival click and "
                         "rising pitch do not exist in this kit.",
            },
        }
        keyed = {}
        for entry in made:
            asset_id = os.path.basename(entry["path"])[:-4]
            keyed[asset_id] = dict(shared, **entry)
        json.dump(keyed, handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


main()
