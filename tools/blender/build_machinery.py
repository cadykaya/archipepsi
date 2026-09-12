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
import mathutils  # noqa: E402
import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

THEME = common.THEME
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


def _hinge(name, arm, pivot):
    """Give a moving part a REAL pivot, as an Empty it hangs from.

    ## The defect this repairs

    `mach_wall_switch` exported `lever_arm` as a node whose vertices ran from
    Y 0.27 to Y 0.53 with an IDENTITY transform. Rotating that node rotates
    it about the ASSET origin at Y 0, half a metre below the arm -- so the
    lever swept through the wall instead of turning on its pintle, while the
    manifest promised "the pivot sits at the arm's base". The preview looked
    plausible because a big enough swing hides a wrong centre.

    ## What this does instead

    An Empty is created AT the pivot, the arm's vertices are re-based so the
    pivot is its local origin, and the arm is parented to the Empty with an
    identity parent-inverse. The exporter then writes the Empty as a node
    carrying the pivot's translation and the arm as its child at identity,
    so `hinge_lever.rotate_x(a)` turns the arm about the pintle for any `a`,
    and the attachment point -- the Empty's own origin -- cannot move,
    because rotating a transform never moves its own origin.

    Call it AFTER `set_origin_group`, with `pivot` already in the asset's
    final frame.
    """
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.empty_display_size = 0.05
    bpy.context.collection.objects.link(empty)
    empty.location = pivot
    offset = mathutils.Vector(pivot)
    for vertex in arm.data.vertices:
        vertex.co -= offset
    arm.location = (0.0, 0.0, 0.0)
    arm.parent = empty
    arm.matrix_parent_inverse = mathutils.Matrix.Identity(4)
    # The pivot has to be INSIDE the arm, or it is a pivot the arm is merely
    # near. Checked rather than assumed.
    lo = [min(v.co[i] for v in arm.data.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in arm.data.vertices) for i in range(3)]
    for i, axis in enumerate("XYZ"):
        if not (lo[i] - 1e-4 <= 0.0 <= hi[i] + 1e-4):
            raise AssertionError(
                "%s: the pivot is outside the arm on %s (local %.4f..%.4f). "
                "A hinge the geometry does not contain is a hinge in the air."
                % (name, axis, lo[i], hi[i]))
    return empty


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
    # Five clamps at the 0.5 m pitch, at the run's ENDS and its midpoints.
    # The first version ran `-1.0 + 0.25 + 0.5i` and put the fifth clamp at
    # x = +1.25 -- 25 cm past the end of a 2.00 m run. That asymmetry moved
    # the asset's centre by 12.5 cm when `set_origin_group` centred it, and
    # the state band exported spanning -1.14..+0.86 instead of -1.00..+1.00,
    # which is what made the preview's growth compensation wrong.
    for i in range(5):
        x = -length / 2.0 + i * 0.50
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

    # THE FILL IS GEOMETRY, AND THAT IS WHY `delayed` HAS FIXED ENDPOINTS.
    #
    # `state_band` carries the per-state TEXTURE, including `delayed`'s
    # graduated track and both its end stops -- static, full length, every
    # frame. `fill_band` is a separate untextured quad that grows across it.
    #
    # The alternative, which this replaces, was to draw the fill into the
    # texture and scale the whole band. That scaled the track's own end
    # stops with it, so at 0% the arrival stop sat 12% along the run and the
    # span the fill was a fraction OF moved with the fill. A player cannot
    # read a fraction off a ruler that shrinks.
    #
    # It sits inside the trough rather than over the whole face, so it never
    # covers the end stops it is measured against.
    fill = brushkit.block("fill_band", (length, 0.012, height * 0.30),
                          (0.0, -0.083, height / 2.0))
    fill.name = "fill_band"
    common.uv_project_world(fill, DENSITY, propkit.PROP_SIZE)
    return shell, [band, fill], (length, depth * 1.25, height)


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
    # The arm reaches DOWN from its pintle as well as up, so the pivot is
    # inside the geometry rather than at its very end -- a lever with no
    # heel below the pin has nothing to press against.
    arm = brushkit.block("lever_arm", (0.06, 0.06, 0.30), (0.0, -0.09, 0.38))
    arm.name = "lever_arm"
    common.uv_project_world(arm, DENSITY, propkit.PROP_SIZE)
    pivot = (0.0, -0.09, 0.30)
    # Proud of the plate face, not flush with it. At y=-0.005 the lens sat
    # INSIDE the plate and the first switch render had no visible indicator
    # at all -- a state region buried in the thing it reports on.
    lens = brushkit.block("state_lens", (0.22, 0.02, 0.09),
                          (0.0, -0.022, 0.13))
    lens.name = "state_lens"
    common.uv_project_world(lens, DENSITY, propkit.PROP_SIZE)
    return shell, [arm, lens], pivot


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
    shell, bands, size = conduit_run()
    common.set_origin_group([shell] + bands, "wall")
    common.uv_project_world(shell, DENSITY, propkit.PROP_SIZE)
    # Quiet housings, for the same reason the object family got them: the
    # default prop skin's patch, bolt and speckle frequencies are tuned for
    # 1-2 m props and these are 0.18-0.50 m in section. Here it matters
    # twice over, because a conduit's job is to carry a STATE DISPLAY and a
    # noisy channel competes with the band lying on it.
    #
    # The band, the fill and the lenses are NOT touched -- they are the
    # state and they keep every value they had.
    canvas = propkit.quiet_painted(THEME, "mach_conduit_run",
                                   seam_metres=0.50, wear=0.09, tone="mid",
                                   bolts=True)
    common.assign(shell, common.make_textured_material(
        "mach_conduit_run", canvas.to_blender("mach_conduit_run_t"),
        roughness=pal.roughness(THEME)))
    common.assert_parts_touch(shell, bands, "mach_conduit_run")
    for part in bands:
        _attach(part, shell)
    common.assign(bands[0], common.make_textured_material(
        "mach_conduit_run_state", _image(band_png, "band_inactive"),
        roughness=0.55))
    common.assign(bands[1], common.make_material(
        "mach_conduit_run_fill", "#eef3f7", roughness=0.5))
    made.append(common.export_glb(shell, "%s/mach_conduit_run.glb" % OUT,
                                  "prop", anchor="wall", parts=bands))
    common.save_texture(canvas.to_blender("mach_conduit_run_save"),
                        "batch043/mach_conduit_run.png")

    # 2. the wall switch
    common.reset_scene()
    shell, parts, pivot = wall_switch()
    common.set_origin_group([shell] + parts, "wall")
    # The pivot is
    # re-derived from the arm's own moved geometry: its centre on X and Y,
    # and the height the pintle was authored at, measured off the arm's top.
    arm = parts[0]
    arm_top = common.top_of(arm)
    arm_lo, arm_hi = common.world_box(arm)
    pivot_now = (0.0, (arm_lo[1] + arm_hi[1]) / 2.0, arm_top - 0.20)
    common.uv_project_world(shell, DENSITY, propkit.PROP_SIZE)
    canvas = propkit.quiet_painted(THEME, "mach_wall_switch",
                                   seam_metres=0.22, wear=0.06, tone="light",
                                   bolts=False)
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
    common.assert_parts_touch(shell, parts, "mach_wall_switch")
    _ = pivot
    hinge = _hinge("hinge_lever", arm, pivot_now)
    made.append(common.export_glb(shell, "%s/mach_wall_switch.glb" % OUT,
                                  "prop", anchor="wall",
                                  parts=[hinge, arm, parts[1]]))
    common.save_texture(canvas.to_blender("mach_wall_switch_save"),
                        "batch043/mach_wall_switch.png")

    # 3. the receiver
    common.reset_scene()
    shell, lenses, size = receiver_lamp()
    common.set_origin_group([shell] + lenses, "floor")
    common.uv_project_world(shell, DENSITY, propkit.PROP_SIZE)
    canvas = propkit.quiet_painted(THEME, "mach_receiver_lamp",
                                   seam_metres=0.26, wear=0.07, tone="light",
                                   bolts=False)
    common.assign(shell, common.make_textured_material(
        "mach_receiver_lamp", canvas.to_blender("mach_receiver_lamp_t"),
        roughness=pal.roughness(THEME)))
    state_mat = common.make_material(
        "mach_receiver_lamp_state", LENS_DIM, roughness=0.5)
    common.assert_parts_touch(shell, lenses, "mach_receiver_lamp")
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
            "coordinate_space": {
                "authoring": "Blender, Z-up, metres",
                "runtime": "glTF / Godot, Y-UP, metres -- what a loader sees",
                "conversion": "(x, y, z)_blender -> (x, z, -y)_runtime; for "
                              "a size triple, (x, y, z) -> (x, z, y)",
                "note": "`size` is the exporter's field and is in AUTHORING "
                        "axes, unchanged from every other batch. "
                        "`size_runtime_y_up` is the same object in runtime "
                        "axes. A node's own translation -- `hinge_lever` "
                        "carries one -- is already in runtime axes.",
            },
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
                "fill": "for `delayed`, scale the `fill_band` NODE on X from "
                        "its -X end and leave `state_band` alone. "
                        "`state_band` carries the graduated track and both "
                        "end stops, which must not move; `fill_band` is the "
                        "only thing that grows. Derive the fixed end from "
                        "the node's own AABB rather than assuming -1..+1.",
                "fill_band": "hidden for every state except `delayed`",
                "lever": "rotate the `hinge_lever` NODE about its X axis. "
                         "It is an empty at the pintle and `lever_arm` is "
                         "its child at identity, so the hinge's own origin "
                         "is the attachment point and cannot move. Do NOT "
                         "rotate `lever_arm` itself -- that is the child "
                         "and its origin is the hinge, so it would work, "
                         "but the hinge is the named handle.",
                "audio": "NOT SUPPLIED. §19.5's hum, arrival click and "
                         "rising pitch do not exist in this kit.",
            },
        }
        keyed = {}
        for entry in made:
            asset_id = os.path.basename(entry["path"])[:-4]
            rx, ry, rz = common.runtime_size(entry["size"])
            entry = dict(entry)
            entry["size_runtime_y_up"] = {"x": rx, "y_up": ry, "z": rz}
            entry["size_authoring_blender_z_up"] = {
                "x": entry["size"][0], "y": entry["size"][1],
                "z_up": entry["size"][2],
            }
            keyed[asset_id] = dict(shared, **entry)
        json.dump(keyed, handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


main()
