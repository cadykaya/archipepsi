"""The 1998 level-editor vocabulary, as code.

Every shape in this module is something you could have made in Worldcraft
by dragging a block out and clipping it. That constraint is the whole point:
`DESIGN.md` 3.4 asks for "GoldSrc/Quake-era brushwork, not voxels", and the
difference between the two is not resolution, it is what the primitives ARE.
A voxel world is boxes on a grid. A brush world is boxes, wedges, ramps,
clipped prisms and low-segment cylinders at whatever angle the level
designer felt like.

**This module contains no proportions.** Not one asset dimension lives here,
by construction -- the same discipline `charkit.py` uses in mario-3 for the
same reason. A builder can reach for the METHOD and physically cannot reach
for another asset's numbers, because they are not here to reach for. A doc
telling people not to copy proportions loses to a deadline; a module that
does not contain them does not.

Axes, once, so no builder has to guess:

    +X  right        (width)
    +Y  forward      (depth, the direction a Zone chains along)
    +Z  up           (height)

Blender is Z-up and glTF is Y-up; `export_glb` sets `export_yup=True`, so
Godot receives +Y up and +Z forward as it expects. Build in Z-up and do not
think about it again.
"""

from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import common


# ----------------------------------------------------------------------
# the primitives
# ----------------------------------------------------------------------

def block(name, size, at=(0.0, 0.0, 0.0), rotation_z=0.0):
    """A box. The brush every 1998 level is mostly made of.

    `at` is the CENTRE, matching how a level editor reports a brush, not
    Blender's habit of leaving things at the origin.
    """
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if rotation_z:
        bmesh.ops.rotate(bm, cent=(0, 0, 0), verts=bm.verts,
                         matrix=Matrix.Rotation(math.radians(rotation_z), 3, "Z"))
    bmesh.ops.translate(bm, vec=Vector(at), verts=bm.verts)
    obj = common.mesh_from_bmesh(bm, name)
    return common.shade_flat(obj)


def wedge(name, size, at=(0.0, 0.0, 0.0), rotation_z=0.0, axis="y"):
    """A box with one face clipped to a slope. A ramp, a buttress, a lintel.

    `axis` names the horizontal direction the slope RISES along: "y" gives a
    ramp you walk up going forward, "x" one you walk up going right.

    Wedges matter as much as boxes. DESIGN 3.4 is explicit that "a room
    built only from axis-aligned cubes reads as Minecraft, which is the
    thing to avoid", and a wedge is the cheapest thing that breaks the cube
    read -- it is why a Quake room does not look like a Minecraft room even
    though both are made of straight lines.
    """
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((sx, sy, sz)), verts=bm.verts)
    key = 1 if axis == "y" else 0
    for vert in bm.verts:
        if vert.co.z > 0 and vert.co[key] < 0:
            vert.co.z = -sz / 2.0
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    if rotation_z:
        bmesh.ops.rotate(bm, cent=(0, 0, 0), verts=bm.verts,
                         matrix=Matrix.Rotation(math.radians(rotation_z), 3, "Z"))
    bmesh.ops.translate(bm, vec=Vector(at), verts=bm.verts)
    obj = common.mesh_from_bmesh(bm, name)
    return common.shade_flat(obj)


def prism(name, radius, height, sides, at=(0.0, 0.0, 0.0), rotation_z=0.0,
          top_radius=None, asset_name=None, organic=False):
    """An N-sided prism. Every cylinder, pipe, column and drum in the game.

    `sides` is capped by `common.assert_segments`, because this is where the
    era actually lives: an 8-sided pipe is a 1998 pipe and the same pipe at
    24 sides is a modern pipe that happens to be cheap. No texture rescues
    it.

    `top_radius` makes a frustum -- a taper is the cheapest way to stop a
    prism reading as a parallel-sided extrusion, which is what made an early
    mario-3 pass read as "baby's first squares in Blender".
    """
    common.assert_segments(sides, max(radius, top_radius or radius),
                           asset_name or name, organic=organic)
    top = radius if top_radius is None else top_radius
    bm = bmesh.new()
    lower, upper = [], []
    for i in range(sides):
        angle = (i + 0.5) * 2.0 * math.pi / sides
        lower.append(bm.verts.new((radius * math.cos(angle),
                                   radius * math.sin(angle), -height / 2.0)))
        upper.append(bm.verts.new((top * math.cos(angle),
                                   top * math.sin(angle), height / 2.0)))
    bm.verts.ensure_lookup_table()
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((lower[i], lower[j], upper[j], upper[i]))
    bm.faces.new(list(reversed(lower)))
    bm.faces.new(upper)
    if rotation_z:
        bmesh.ops.rotate(bm, cent=(0, 0, 0), verts=bm.verts,
                         matrix=Matrix.Rotation(math.radians(rotation_z), 3, "Z"))
    bmesh.ops.translate(bm, vec=Vector(at), verts=bm.verts)
    obj = common.mesh_from_bmesh(bm, name)
    return common.shade_flat(obj)


def tube(name, outer, inner, height, sides, at=(0.0, 0.0, 0.0),
         asset_name=None):
    """An open ring: a pipe mouth, a vent bore, a portal aperture."""
    common.assert_segments(sides, outer, asset_name or name)
    bm = bmesh.new()
    rings = {}
    for label, radius in (("out", outer), ("in", inner)):
        for level, z in (("lo", -height / 2.0), ("hi", height / 2.0)):
            rings[(label, level)] = [
                bm.verts.new((radius * math.cos((i + 0.5) * 2 * math.pi / sides),
                              radius * math.sin((i + 0.5) * 2 * math.pi / sides),
                              z))
                for i in range(sides)]
    bm.verts.ensure_lookup_table()
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((rings[("out", "lo")][i], rings[("out", "lo")][j],
                      rings[("out", "hi")][j], rings[("out", "hi")][i]))
        bm.faces.new((rings[("in", "hi")][i], rings[("in", "hi")][j],
                      rings[("in", "lo")][j], rings[("in", "lo")][i]))
        bm.faces.new((rings[("out", "hi")][i], rings[("out", "hi")][j],
                      rings[("in", "hi")][j], rings[("in", "hi")][i]))
        bm.faces.new((rings[("in", "lo")][i], rings[("in", "lo")][j],
                      rings[("out", "lo")][j], rings[("out", "lo")][i]))
    bmesh.ops.translate(bm, vec=Vector(at), verts=bm.verts)
    obj = common.mesh_from_bmesh(bm, name)
    return common.shade_flat(obj)


def frame(name, outer_size, thickness, depth, at=(0.0, 0.0, 0.0)):
    """A rectangular frame standing in the XZ plane. Doorways, portals, signs.

    Built as four blocks rather than a boolean: a boolean leaves n-gons and
    stray vertices that make the triangle count unpredictable, and an
    unpredictable count is a budget you cannot enforce.
    """
    width, height = outer_size
    parts = [
        block("%s_left" % name, (thickness, depth, height),
              (-(width - thickness) / 2.0, 0.0, 0.0)),
        block("%s_right" % name, (thickness, depth, height),
              ((width - thickness) / 2.0, 0.0, 0.0)),
        block("%s_top" % name, (width - 2 * thickness, depth, thickness),
              (0.0, 0.0, (height - thickness) / 2.0)),
        block("%s_bottom" % name, (width - 2 * thickness, depth, thickness),
              (0.0, 0.0, -(height - thickness) / 2.0)),
    ]
    obj = common.join(parts, name)
    for vertex in obj.data.vertices:
        vertex.co += Vector(at)
    return common.shade_flat(obj)


def wall_with_opening(name, size, opening_size, opening_at_x=0.0,
                      opening_from_floor=0.0):
    """A wall panel with a rectangular hole, built from four blocks.

    Same reason as `frame`: no booleans anywhere in this toolchain. Every
    module's triangle count is arithmetic, which is what makes the budget a
    limit rather than a hope.
    """
    width, depth, height = size
    ow, oh = opening_size
    left_w = (width / 2.0 + opening_at_x - ow / 2.0)
    right_w = (width / 2.0 - opening_at_x - ow / 2.0)
    below_h = opening_from_floor
    above_h = height - opening_from_floor - oh
    parts = []
    if left_w > 1e-4:
        parts.append(block("%s_l" % name, (left_w, depth, height),
                           (-width / 2.0 + left_w / 2.0, 0.0, height / 2.0)))
    if right_w > 1e-4:
        parts.append(block("%s_r" % name, (right_w, depth, height),
                           (width / 2.0 - right_w / 2.0, 0.0, height / 2.0)))
    if below_h > 1e-4:
        parts.append(block("%s_b" % name, (ow, depth, below_h),
                           (opening_at_x, 0.0, below_h / 2.0)))
    if above_h > 1e-4:
        parts.append(block("%s_a" % name, (ow, depth, above_h),
                           (opening_at_x, 0.0, height - above_h / 2.0)))
    return common.join(parts, name)


def stair(name, run, rise, width, steps, at=(0.0, 0.0, 0.0)):
    """A stepped flight. Real steps, because the player collides with them.

    `MAX_VERTICAL_STEP` is Godot's, and a step above it is a wall the player
    cannot climb. The caller passes `rise` and this refuses to build one
    that lies about being walkable.
    """
    if rise > common.DIM["max_vertical_step"] + 1e-6:
        raise ValueError(
            "%s: %.2f m rise per step exceeds MAX_VERTICAL_STEP (%.2f m). A "
            "step the player cannot climb is a wall, and making it prettier "
            "does not make it climbable."
            % (name, rise, common.DIM["max_vertical_step"]))
    parts = []
    for i in range(steps):
        parts.append(block(
            "%s_%d" % (name, i), (width, run, rise * (i + 1)),
            (0.0, -((steps - 1) / 2.0) * run + i * run, rise * (i + 1) / 2.0)))
    obj = common.join(parts, name)
    for vertex in obj.data.vertices:
        vertex.co += Vector(at)
    return obj


def grate(name, size, bars, thickness, at=(0.0, 0.0, 0.0), axis="x"):
    """A slatted cover: floor grating, a vent face, a cage panel.

    Real slats, not a painted grid, because a grate's whole job is to be a
    silhouette you can see light and geometry through -- painting it flat is
    the one case where the paint-it-do-not-model-it rule loses.
    """
    width, depth, height = size
    parts = []
    span = width if axis == "x" else depth
    for i in range(bars):
        offset = -span / 2.0 + span * (i + 0.5) / bars
        if axis == "x":
            parts.append(block("%s_%d" % (name, i),
                               (thickness, depth, height), (offset, 0.0, 0.0)))
        else:
            parts.append(block("%s_%d" % (name, i),
                               (width, thickness, height), (0.0, offset, 0.0)))
    obj = common.join(parts, name)
    for vertex in obj.data.vertices:
        vertex.co += Vector(at)
    return obj


def spin(obj, axis, degrees):
    """Rotate an object's GEOMETRY about its own centre, in place.

    Use this and never `obj.rotation_euler` on a part that is already
    positioned. Every primitive here builds its geometry at absolute
    coordinates with the object left at the world origin, so setting
    `rotation_euler` rotates about the WORLD origin -- and `join` then bakes
    that in. A pipe built 2.55 m up and tipped 90 degrees does not lie down,
    it swings 2.55 m sideways.

    That bug shipped three times in one session before this function
    existed: a 4 m corridor module that measured 5.95 m, a pipe cluster
    1.55 m deep, and a machinery unit 2.48 m tall. None of them looked wrong
    in a render. All three were obvious in one line of `measure()`.
    """
    bbox = [Vector(corner) for corner in obj.bound_box]
    centre = Vector((
        (min(v.x for v in bbox) + max(v.x for v in bbox)) / 2.0,
        (min(v.y for v in bbox) + max(v.y for v in bbox)) / 2.0,
        (min(v.z for v in bbox) + max(v.z for v in bbox)) / 2.0,
    ))
    matrix = Matrix.Rotation(math.radians(degrees), 3, axis.upper())
    for vertex in obj.data.vertices:
        vertex.co = matrix @ (vertex.co - centre) + centre
    obj.data.update()
    return obj


def bevel_prop(obj, smallest_dimension):
    """The one permitted bevel: hand-scale props the player walks up to.

    Architecture gets none -- see `derive_budgets.py` section 5. A bevelled
    wall module reads as extruded modern geometry AND stops butting flush
    against the module beside it, which shows up as a groove at every seam.
    """
    budgets = common.BUDGETS
    if smallest_dimension < budgets["prop_bevel_min_size"]:
        return obj
    low, high = budgets["prop_bevel_fraction"]
    width = smallest_dimension * (low + high) / 2.0
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new(name="bevel", type="BEVEL")
    modifier.width = width
    modifier.segments = 1
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(30.0)
    bpy.ops.object.modifier_apply(modifier="bevel")
    obj.select_set(False)
    return common.shade_flat(obj)
