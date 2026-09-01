"""Blender-side scaffolding for the Archipepsi art lane.

Every builder in `tools/blender/build_*.py` runs inside Blender and imports
this. It owns the boring, dangerous parts: scene state, units, materials,
UV projection, export, and the assertions that fail a build rather than
letting a wrong asset reach a review sheet.

Three principles it exists to enforce, all of them paid for by somebody else
first:

**Art as code.** No `.blend` file is the source of truth for anything. A
model is a Python script plus this module, and `check_art_current.sh`
rebuilds every one of them and fails if the committed `.glb` moved.

**Measure, do not estimate.** `uv_texel_density()` reads the real unwrap and
the real world area. mario-3's estimate here was wrong by a factor of six,
which made every painted cluster smaller than a texel.

**Assert on the effect.** A builder that "sets flat shading" can silently
stop doing it. `assert_flat()` looks at the polygons.
"""

from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine_truth  # noqa: E402
import palette as pal  # noqa: E402

REPO_ROOT = engine_truth.REPO_ROOT
MODEL_DIR = os.path.join(REPO_ROOT, "assets", "models")
TEXTURE_DIR = os.path.join(REPO_ROOT, "assets", "textures")

DIM = engine_truth.dimensions()
BUDGETS = pal.budgets()


def log(message):
    print("[art] %s" % message)


# ----------------------------------------------------------------------
# scene
# ----------------------------------------------------------------------

def reset_scene():
    """A clean, unit-correct scene.

    Godot and Blender agree on metres, and both call +Y up for a glTF, so
    the only real risk is a stale datablock from a previous build in the
    same Blender session. Purge rather than trust.
    """
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images,
                  bpy.data.objects):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


# ----------------------------------------------------------------------
# materials
# ----------------------------------------------------------------------

def make_material(name, hex_color, roughness=0.9, emission_hex=None,
                  emission_strength=1.0):
    """A flat, unlit-leaning material. Albedo only.

    No normal, roughness or AO maps anywhere in this project. The era did
    not have them and they fight the flat read: a normal-mapped brick wall
    is unmistakably a 2010s wall no matter what resolution its albedo is.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = pal.rgba(hex_color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    if emission_hex:
        bsdf.inputs["Emission Color"].default_value = pal.rgba(emission_hex)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def make_textured_material(name, image, roughness=0.9):
    """Albedo texture, NEAREST filtering, mipmaps on.

    NEAREST is not a preference. `godot/scripts/generation/textures.gd`
    generates the procedural half of the game at `texture_filter = NEAREST`,
    so an authored asset that imports with linear filtering makes the seam
    between authored and procedural content the most visible thing in the
    room. Blender sets `Closest`, glTF carries sampler NEAREST, and the
    Godot import is asserted separately by the preview project.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    tex.location = (-360, 240)
    tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def make_signal_material(name, dark_hex, bright_hex, saturation=0.92,
                         roughness=0.3):
    """A lit surface whose COLOUR survives being lit.

    Godot adds `emission * emission_strength` on top of albedo, so an
    emissive material built the obvious way -- bright albedo, bright
    emission, strength above 1 -- clips every channel and renders white.
    Every lit cue in Batch 001 did exactly that on its first render: the
    enemy's eye, which is the ONE cue on the figure and the thing that says
    which way it is facing, came out as a white bar with no hue at all.

    The first fix was a dark albedo under a bright emission, at a strength
    picked by hand. That was better and still wrong -- Epsilon's core, a
    much larger surface than an eye, clipped again at the strength an eye
    was happy with, because a hand-picked strength is a guess about a sum
    nobody computed.

    So `saturation` SOLVED for the strength instead: at 1.0 the brightest
    channel of `albedo + strength * emission` lands exactly at 1.0. That
    still rendered the Epsilon installation's veins as YELLOW BARS, and the
    reason is the third and last one: **that sum is the unlit sum.** The
    surface is also lit, and `albedo * irradiance` is the term the solve
    left out. `identity` is a green whose albedo alone clips its green
    channel under a facility light, so green had nowhere left to go, every
    photon of emission went into red, and the hue walked to yellow-white --
    which in this palette is the telegraph colour. Green says whose this is
    and orange says what is about to happen; a green that renders orange
    inverts the one rule the colour language has.

    So the solve now budgets for the light as well, and the light is not a
    number art gets to choose: `engine_truth.lighting()` reads the
    brightest `light_energy` in `THEME_MATERIALS` and the brightest
    `ambient_light_energy` on the engine's environments. Under that
    irradiance:

    * the albedo is SCALED DOWN until its lit contribution is at most half
      the budget -- the glow has to be the majority of the surface, or the
      thing is a painted panel that happens to be near a lamp; and
    * the strength is then solved against what is left.

    The hue is still the caller's palette colour: scaling darkens the
    albedo without moving it off its hue, so the unlit read is a near-black
    tint of the family and the lit read is the family's brightest step.
    """
    dark = pal.rgb(dark_hex)
    bright = pal.rgb(bright_hex)
    lit = pal.lighting()["max_irradiance"]

    # 1. The albedo may spend at most half the budget once lit. This is not
    #    a taste number: at more than half, `albedo * light` outweighs the
    #    emission and the surface reads as lit-from-outside.
    worst = max(d * lit for d in dark)
    scale = min(1.0, 0.5 / worst) if worst > 1e-6 else 1.0
    albedo = tuple(d * scale for d in dark)

    # 2. Solve per channel for where `albedo * light + s * emission` reaches
    #    1.0, and take the tightest -- that is the channel that would clip
    #    first and turn the colour white.
    headroom = min(
        ((1.0 - a * lit) / b) if b > 1e-6 else 1e6
        for a, b in zip(albedo, bright))
    strength = max(0.05, headroom * saturation)

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = tuple(albedo) + (1.0,)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Emission Color"].default_value = pal.rgba(bright_hex)
    bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def assign(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


# ----------------------------------------------------------------------
# shading
# ----------------------------------------------------------------------

def shade_flat(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def assert_flat(obj, asset_name):
    """Flat shading is the whole look, so it is checked, not intended.

    A builder can stop calling `shade_flat` and nothing else notices: the
    export succeeds, the triangle count is unchanged, and the asset simply
    goes soft.
    """
    smooth = sum(1 for poly in obj.data.polygons if poly.use_smooth)
    if smooth:
        raise AssertionError(
            "%s: %d of %d polygons are smooth-shaded. Archipepsi's hard "
            "surfaces are flat-shaded without exception -- the faceted read "
            "is the 1998 grammar, and a smooth-shaded prism is a modern "
            "prism." % (asset_name, smooth, len(obj.data.polygons)))


# ----------------------------------------------------------------------
# budgets
# ----------------------------------------------------------------------

def triangle_count(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def assert_budget(obj, asset_name, category):
    ceilings = BUDGETS["max_triangles"]
    if category not in ceilings:
        raise KeyError(
            "%s: no triangle ceiling for category '%s'. Categories are %s. A "
            "new category is a budget decision, not a spelling."
            % (asset_name, category, ", ".join(sorted(ceilings))))
    count = triangle_count(obj)
    limit = ceilings[category]
    if count > limit:
        raise AssertionError(
            "%s: %d triangles against the %s ceiling of %d. Over budget means "
            "DELETE geometry and paint it instead -- never optimise the mesh, "
            "and never raise the ceiling to fit one asset."
            % (asset_name, count, category, limit))
    return count


def assert_segments(count, radius, asset_name, organic=False):
    """The radial cap does more work than the triangle cap."""
    if organic:
        limit = BUDGETS["max_radial_segments_enemy"]
    elif radius > BUDGETS["large_radius_threshold"]:
        limit = BUDGETS["max_radial_segments_large"]
    else:
        limit = BUDGETS["max_radial_segments"]
    if count > limit:
        raise AssertionError(
            "%s: %d radial segments at radius %.2f m, cap is %d. A cylinder "
            "with more sides is a cylinder that has stopped being 1998."
            % (asset_name, count, radius, limit))
    return count


# ----------------------------------------------------------------------
# UVs and texel density
# ----------------------------------------------------------------------

def uv_project_world(obj, texels_per_metre, texture_size):
    """Axis-aligned planar projection at a fixed world density.

    This is the single most important rule in the toolchain and it is the
    one place Archipepsi deliberately does NOT do what mario-3 does.

    mario-3 unwraps props with `smart_project`, which is right for discrete
    objects. Archipepsi's architecture is not discrete: Epsilon abuts wall
    modules against each other, and two modules with independent UV islands
    show a texture discontinuity at every seam -- a visible break in the
    grain, exactly where a 1998 level would have had none.

    A 1998 editor projected the texture onto each brush face along that
    face's dominant axis, at a fixed world scale. That is literally what
    makes the look, and it is what this does: every face is projected from
    whichever world axis it most faces, at `texels_per_metre`, so a wall
    tiles seamlessly into the wall next to it whatever order they are
    placed in.
    """
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv_layer = mesh.uv_layers.active.data
    scale = texels_per_metre / float(texture_size)

    for poly in mesh.polygons:
        normal = poly.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        # Pick the two world axes that are NOT the dominant one, in a fixed
        # order, so the projection is deterministic rather than dependent on
        # face winding.
        if axis == 0:      # face points along X -> project ZY
            uy, ux = 1, 2
        elif axis == 1:    # face points along Y (floor/ceiling) -> project XZ
            uy, ux = 2, 0
        else:              # face points along Z -> project XY
            uy, ux = 1, 0
        for loop_index in poly.loop_indices:
            world = obj.matrix_world @ mesh.vertices[
                mesh.loops[loop_index].vertex_index].co
            uv_layer[loop_index].uv = (world[ux] * scale, world[uy] * scale)
    return obj


def uv_unwrap_prop(obj, angle_limit_deg=66.0, island_margin=0.02):
    """`smart_project`, for discrete objects that never tile against anything."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle_limit_deg),
                             island_margin=island_margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return obj


def uv_texel_density(obj, texture_size):
    """Measured texels per world metre. Never estimated.

    Returns (median, minimum, maximum) across the object's polygons,
    weighted by nothing -- the median is what the asset reads as, and the
    spread is what tells you a single face was projected from the wrong
    axis.
    """
    mesh = obj.data
    if not mesh.uv_layers:
        return (0.0, 0.0, 0.0)
    uv_layer = mesh.uv_layers.active.data
    densities = []
    for poly in mesh.polygons:
        world_area = poly.area * _scale_factor(obj)
        if world_area <= 1e-9:
            continue
        uvs = [Vector(uv_layer[i].uv) for i in poly.loop_indices]
        uv_area = 0.0
        for i in range(1, len(uvs) - 1):
            a, b, c = uvs[0], uvs[i], uvs[i + 1]
            uv_area += abs((b - a).cross(c - a)) / 2.0
        if uv_area <= 1e-12:
            continue
        texel_area = uv_area * texture_size * texture_size
        densities.append(math.sqrt(texel_area / world_area))
    if not densities:
        return (0.0, 0.0, 0.0)
    densities.sort()
    return (densities[len(densities) // 2], densities[0], densities[-1])


def _scale_factor(obj):
    scale = obj.matrix_world.to_scale()
    return abs(scale.x * scale.y)


def assert_texel_density(obj, asset_name, tier, texture_size):
    """Fail the build if an asset's real density leaves its tier's band."""
    band = BUDGETS["texel_density"][tier]
    median, low, high = uv_texel_density(obj, texture_size)
    if not band["min"] <= median <= band["max"]:
        raise AssertionError(
            "%s: measured %.1f texels/m (tier '%s' wants %d-%d, target %d) on "
            "a %dpx map. Change the TEXTURE SIZE, not the UVs -- the UVs are "
            "a world-scale projection and moving them breaks tiling against "
            "the next module."
            % (asset_name, median, tier, band["min"], band["max"],
               band["target"], texture_size))
    return median, low, high


# ----------------------------------------------------------------------
# mesh helpers
# ----------------------------------------------------------------------

def mesh_from_bmesh(bm, name):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def join(objects, name):
    """Join into one object. The first object's transform wins.

    Paint functions downstream receive WORLD coordinates, because `join`
    adopts the active object's origin and mesh-local Z can be metres off
    what a builder thinks it is. mario-3 spent two rebuilds on that.
    """
    objects = [o for o in objects if o is not None]
    if not objects:
        raise ValueError("join(%s): nothing to join" % name)
    if len(objects) == 1:
        objects[0].name = name
        return objects[0]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    joined.data.name = name
    return joined


#: Where an asset's origin sits, and therefore what "place it at y = 0"
#: means. Declaring this per asset is not bookkeeping -- getting it wrong is
#: invisible in every turntable shot and catastrophic in a room.
#:
#: The first composed room proved it. Every asset went through a single
#: `set_origin_floor_centre`, which puts the origin at the geometry's own
#: LOWEST point. For a crate that is right. For a pipe run built at 2.55 m
#: it dropped the pipe to ankle height; for a ceiling bay it moved the
#: downstand beams ABOVE the ceiling plane, where they were invisible from
#: inside the room -- so the room rendered with a flat lid and the one piece
#: of structure that was supposed to stop it reading as a lid was hidden
#: behind it. Nothing failed. Every sheet still passed.
ANCHORS = ("floor", "ceiling", "wall", "module_floor", "centre")


def set_origin(obj, anchor="floor"):
    """Move the geometry so the origin means what `anchor` says it means.

    floor         X/Y centred, lowest point at Z 0.  A crate, a terminal, a
                  wall panel -- anything that stands on the ground.
    ceiling       X/Y centred, HIGHEST point at Z 0.  A ceiling bay, a
                  hanging light, a grapple anchor. The asset occupies
                  negative Z, so placing it at the ceiling height puts it
                  where it belongs.
    wall          X centred, lowest point at Z 0, and the BACK face at Y 0,
                  so placing it on a wall plane sits it flush.
    module_floor  X/Y centred, Z LEFT ALONE.  For a module whose height
                  within its bay is part of what it is -- a pipe run at
                  2.55 m is at 2.55 m, and re-basing it to its own lowest
                  point is what put the pipes on the floor.
    centre        all three centred.
    """
    if anchor not in ANCHORS:
        raise ValueError("set_origin: anchor must be one of %s, got '%s'"
                         % (", ".join(ANCHORS), anchor))
    bbox = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_x, max_x = min(v.x for v in bbox), max(v.x for v in bbox)
    min_y, max_y = min(v.y for v in bbox), max(v.y for v in bbox)
    min_z, max_z = min(v.z for v in bbox), max(v.z for v in bbox)
    mid_x, mid_y = (min_x + max_x) / 2.0, (min_y + max_y) / 2.0

    if anchor == "floor":
        shift = Vector((mid_x, mid_y, min_z))
    elif anchor == "ceiling":
        shift = Vector((mid_x, mid_y, max_z))
    elif anchor == "wall":
        shift = Vector((mid_x, max_y, min_z))
    elif anchor == "module_floor":
        shift = Vector((mid_x, mid_y, 0.0))
    else:
        shift = Vector((mid_x, mid_y, (min_z + max_z) / 2.0))

    for vertex in obj.data.vertices:
        vertex.co -= shift
    obj.location = (0.0, 0.0, 0.0)
    return obj


def set_origin_floor_centre(obj):
    """Kept as the common case. Prefer `set_origin(obj, anchor)`."""
    return set_origin(obj, "floor")


def measure(obj):
    """(width_x, depth_y, height_z) in metres. Arithmetic beats staring."""
    bbox = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        max(v.x for v in bbox) - min(v.x for v in bbox),
        max(v.y for v in bbox) - min(v.y for v in bbox),
        max(v.z for v in bbox) - min(v.z for v in bbox),
    )


def assert_fits(obj, asset_name, max_size, why):
    """Fail if an asset is bigger than the mechanical box it must live in.

    Collision and traversal truth are Godot's. An asset that outgrows its
    footprint does not get the footprint changed -- it gets smaller.
    """
    size = measure(obj)
    for axis, actual, limit in zip("XYZ", size, max_size):
        if limit is not None and actual > limit + 1e-4:
            raise AssertionError(
                "%s: %.3f m on %s against a limit of %.3f m. %s Godot owns "
                "this dimension; shrink the asset, never the clearance."
                % (asset_name, actual, axis, limit, why))
    return size


# ----------------------------------------------------------------------
# export
# ----------------------------------------------------------------------

def export_glb(obj, relative_path, category, tier=None, texture_size=None,
               check_flat=True, anchor="floor", collision=()):
    """Write a .glb, after every assertion that can be made has been made.

    `collision` is the collision-only twins from `roomcollision.build`.
    They ride along in the export and are excluded from EVERY assertion
    and from `measure`, because a collider is not part of the asset's
    triangle budget, its texel density or its declared size -- and the
    manifest that Production reads is built from those numbers. Rooms
    that gained collision must not appear to have changed shape.
    """
    name = os.path.basename(relative_path)
    if check_flat:
        assert_flat(obj, name)
    tris = assert_budget(obj, name, category)
    density = None
    if tier and texture_size:
        density = assert_texel_density(obj, name, tier, texture_size)

    out_path = os.path.join(MODEL_DIR, relative_path)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for collider in collision:
        collider.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_yup=True,
    )
    size = measure(obj)
    if density:
        log("%-40s %4d tris  %5.2f x %5.2f x %5.2f m  %5.1f texels/m "
            "(spread %.1f-%.1f)%s"
            % (relative_path, tris, size[0], size[1], size[2],
               density[0], density[1], density[2],
               "" if not collision else "  +%d colliders" % len(collision)))
    else:
        log("%-40s %4d tris  %5.2f x %5.2f x %5.2f m%s"
            % (relative_path, tris, size[0], size[1], size[2],
               "" if not collision
               else "  +%d colliders" % len(collision)))
    entry = {"path": relative_path, "triangles": tris, "anchor": anchor,
             "size": [round(v, 3) for v in size],
             "texel_density": None if not density else round(density[0], 1)}
    if collision:
        # Recorded only when there IS collision, so every asset that
        # never had any keeps the manifest entry it already had.
        entry["colliders"] = len(collision)
    return entry


def save_texture(image, relative_path):
    out_path = os.path.join(TEXTURE_DIR, relative_path)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    image.filepath_raw = out_path
    image.file_format = "PNG"
    image.save()
    return relative_path
