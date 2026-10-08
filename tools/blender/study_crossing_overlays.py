"""Crossing overlay studies on Crossing D's Central Hall (Arty, 2026-10-08).

    .tools/blender/blender -b --python tools/blender/study_crossing_overlays.py -- <out_dir>

REVIEW-ONLY LOOK STUDIES, not assets: three ways a Multiworld game could
take over the station, plus the hybrid recommended for the owner to react
to. Each writes one .glb authored in D's own room coordinates (Godot,
metres), which `tools/crossing_capture/dcap.gd` places at the room origin
and photographs from the SAME camera, so the difference between frames is
the treatment, never the layout.

* `overlay_bloom.glb`   -- INVASION: faceted growths break through the
  wall, floor and ceiling; light leaks along the seams they crack.
* `overlay_cabinet.glb` -- ARCADE REMIX: another game's rules take the
  room over -- a marquee bezel and chaser bulbs round the lift, a score
  readout, a 1 m chequer zone, a ceiling of rhythm bars, bumper rings.
* `overlay_splice.glb`  -- REALITY SPLICE: one clean cut through the hall;
  past it the same room is built in another game's language.
* `overlay_hybrid.glb`  -- the recommendation: the splice's structure,
  growths only along its seam, and the marquee only on the objective.

ONE FOREIGN PALETTE for all three, so it is the grammar that differs:
magenta, plum, cream and ink. It is chosen to stay clear of every
gameplay hue -- movement blue (225 deg), power green (135), destructible
orange (25), hazard yellow (48) and enemy red/orange -- and it is never put
on anything the player interacts with. Source-world colour and affordance
colour stay separate.

Original shapes only; no reference to any specific game's art.
"""

from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
import mathutils

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402

MAGENTA = "#ff3fbf"
PINK = "#ff9ad9"
PLUM = "#3b1240"
CREAM = "#f6e3c4"
INK = "#140a16"
STATION = "#8c939b"     # displaced station panels: the substrate's own grey


def G(x, y, z):
    """D's room frame (Godot, Y up) -> Blender (Z up)."""
    return mathutils.Vector((x, -z, y))


_MATS = {}


def mat(hex_colour, emit=0.0):
    key = (hex_colour, emit)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new("ov_%s_%s" % (hex_colour[1:], emit))
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    rgb = [int(hex_colour[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
           for c in rgb]
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.6
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    _MATS[key] = m
    return m


def _obj(bm, name, material):
    obj = common.shade_flat(common.mesh_from_bmesh(bm, name))
    obj.data.materials.append(material)
    return obj


def box(name, size, at, material, yaw=0.0, tilt=(0.0, 0.0)):
    """`size` and `at` in D's frame (x, y-up, z); yaw about up, tilt about
    the room's x and z, degrees."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(size[0], size[2], size[1]), verts=bm.verts)
    rot = (mathutils.Matrix.Rotation(math.radians(yaw), 3, "Z")
           @ mathutils.Matrix.Rotation(math.radians(tilt[0]), 3, "X")
           @ mathutils.Matrix.Rotation(math.radians(-tilt[1]), 3, "Y"))
    bmesh.ops.rotate(bm, cent=(0, 0, 0), verts=bm.verts, matrix=rot)
    bmesh.ops.translate(bm, vec=G(*at), verts=bm.verts)
    return _obj(bm, name, material)


def spike(name, base, tip, radius, material, sides=6):
    """A faceted crystal from `base` to `tip` (D's frame)."""
    a, b = G(*base), G(*tip)
    length = (b - a).length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides,
                          radius1=radius, radius2=0.0, depth=length)
    bmesh.ops.translate(bm, vec=(0, 0, length / 2.0), verts=bm.verts)
    quat = mathutils.Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    bmesh.ops.rotate(bm, cent=(0, 0, 0), verts=bm.verts,
                     matrix=quat.to_matrix())
    bmesh.ops.translate(bm, vec=a, verts=bm.verts)
    return _obj(bm, name, material)


def ring(name, at, normal_axis, major, minor, material):
    bpy.ops.mesh.primitive_torus_add(major_segments=12, minor_segments=4,
                                     major_radius=major, minor_radius=minor,
                                     location=G(*at))
    obj = bpy.context.active_object
    obj.name = name
    if normal_axis == "x":
        obj.rotation_euler = (0.0, math.radians(90), 0.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(material)
    return common.shade_flat(obj)


# --- the three studies ------------------------------------------------------

def bloom(seam_only=False):
    """INVASION: growths burst through; their light follows the cracks."""
    o = []
    core, shell = mat(MAGENTA, 2.0), mat(PINK, 0.35)
    plum = mat(PLUM)

    def cluster(tag, base, spokes):
        for i, (tip, r, lit) in enumerate(spokes):
            o.append(spike("%s_%d" % (tag, i), base, tip, r,
                           core if lit else (shell if i % 2 else plum)))

    if not seam_only:
        # Through the floor, front right: a spire cluster up to 9 m, the
        # silhouette you remember the room by.
        cluster("floor", (4.0, -0.6, 2.0), [
            ((4.6, 9.0, 1.0), 1.4, False), ((7.0, 6.0, 3.8), 0.95, True),
            ((1.8, 5.2, 3.2), 0.8, False), ((4.2, 3.6, -0.6), 0.7, True),
            ((7.4, 2.8, 0.2), 0.55, False), ((2.2, 2.6, 0.4), 0.45, True)])
        # The floor it broke: station plates heaved up round the breach.
        for i, (x, z, yaw, tx, tz) in enumerate([
                (2.4, 3.6, 10, 14, -8), (5.8, 0.4, -20, -10, 12),
                (6.1, 3.3, 35, 8, 16), (2.7, 0.6, -5, -16, -6)]):
            o.append(box("heave_%d" % i, (1.9, 0.14, 1.9), (x, 0.25, z),
                         mat(STATION), yaw, (tx, tz)))
        # Through the north wall, above the stair head.
        cluster("wall", (4.0, 12.0, -12.8), [
            ((-1.5, 9.5, -8.0), 1.3, False), ((9.0, 14.0, -7.5), 0.9, True),
            ((3.0, 15.5, -6.0), 0.8, False), ((6.5, 8.6, -9.0), 0.6, True)])
        # Down from the ceiling.
        cluster("ceiling", (-4.0, 16.4, -2.0), [
            ((-5.0, 9.5, -0.5), 1.2, False), ((-1.0, 11.5, -4.0), 0.8, True),
            ((-7.0, 12.0, 1.0), 0.7, False)])
        # Light leaking along the cracks: wall seam at 4 m, and a floor
        # crack that runs (in straight jogs) from the floor breach west.
        o.append(box("seam_wall", (11.0, 0.08, 0.06), (-1.0, 4.0, -11.95),
                     mat(MAGENTA, 2.5)))
        for i, (x0, z0, x1, z1) in enumerate([(3.2, 2.0, -1.0, 2.0),
                                              (-1.0, 2.0, -1.0, -3.0),
                                              (-1.0, -3.0, -4.5, -3.0)]):
            cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
            o.append(box("crack_%d" % i,
                         (abs(x1 - x0) + 0.08, 0.02, abs(z1 - z0) + 0.08),
                         (cx, 0.012, cz), mat(MAGENTA, 2.5)))
    else:
        # The hybrid's growths: only along the splice seam (x = 2).
        cluster("seam_floor", (2.0, -0.3, 4.5), [
            ((1.6, 3.8, 4.2), 0.6, False), ((2.6, 2.6, 5.4), 0.45, True),
            ((2.2, 1.6, 3.2), 0.35, False)])
        cluster("seam_wall", (2.0, 11.0, -12.6), [
            ((1.0, 9.6, -8.6), 0.7, False), ((2.8, 12.5, -9.0), 0.45, True)])
    return o


def cabinet(marquee_only=False):
    """ARCADE REMIX: another game's rules, drawn over the room."""
    o = []
    plum, ink = mat(PLUM), mat(INK)
    bulb, neon = mat(CREAM, 1.6), mat(MAGENTA, 2.2)
    # A marquee bezel round the lift: the objective framed like a cabinet.
    # The door opening (x -9..-5, y 0..3.2) stays clear.
    x0, x1, top, z = -9.9, -4.1, 15.2, -7.6
    o.append(box("bezel_l", (0.5, top, 0.5), (x0, top / 2, z), plum))
    o.append(box("bezel_r", (0.5, top, 0.5), (x1, top / 2, z), plum))
    o.append(box("bezel_top", (x1 - x0 + 0.5, 1.2, 0.6), ((x0 + x1) / 2,
                                                          top, z), plum))
    o.append(box("marquee", (x1 - x0 - 0.6, 0.7, 0.1),
                 ((x0 + x1) / 2, top, z + 0.32), neon))
    y = 0.6
    while y < top - 0.6:
        for x in (x0, x1):
            o.append(box("bulb", (0.16, 0.16, 0.08), (x, y, z + 0.29), bulb))
        y += 0.8
    if marquee_only:
        return o
    # A score readout on the north wall: four seven-segment digits.
    segs = {"0": "abcdef", "4": "bcfg", "2": "abdeg"}
    on = {"a": (0, 1, 1, 0.12), "b": (0.5, 0.5, 0.12, 1), "c": (0.5, -0.5, 0.12, 1),
          "d": (0, -1, 1, 0.12), "e": (-0.5, -0.5, 0.12, 1),
          "f": (-0.5, 0.5, 0.12, 1), "g": (0, 0, 1, 0.12)}
    o.append(box("score_panel", (8.6, 3.2, 0.12), (4.6, 12.6, -11.94), ink))
    for i, digit in enumerate("0420"):
        cx = 1.4 + i * 2.1
        for s in segs[digit]:
            dx, dy, w, h = on[s]
            o.append(box("seg", (w * 1.1, h * 1.1, 0.06),
                         (cx + dx * 1.1, 12.6 + dy * 1.1, -11.86), neon))
    # A 1 m chequer zone in the middle of the floor: big, low frequency.
    for i in range(6):
        for j in range(6):
            if (i + j) % 2 == 0:
                o.append(box("check", (1.0, 0.02, 1.0),
                             (-2.5 + i, 0.012, -2.5 + j), mat(CREAM)))
            else:
                o.append(box("check", (1.0, 0.02, 1.0),
                             (-2.5 + i, 0.012, -2.5 + j), ink))
    # Rhythm bars across the ceiling, every 4 m.
    for i, z in enumerate((-10.0, -6.0, -2.0, 2.0, 6.0, 10.0)):
        o.append(box("bar_%d" % i, (23.6, 0.3, 0.6), (0.0, 15.7, z),
                     neon if i % 2 == 0 else mat(CREAM, 1.0)))
    # Bumper rings on the west wall.
    for i, (y, z) in enumerate(((5.0, 2.0), (9.0, -1.5), (6.5, 7.5))):
        o.append(ring("bumper_%d" % i, (-11.8, y, z), "x", 1.1, 0.22,
                      mat(CREAM)))
        o.append(box("bumper_core_%d" % i, (0.08, 1.0, 1.0), (-11.9, y, z),
                     neon, 0.0, (45.0, 0.0)))
    return o


SEAM_X = 2.0


def splice():
    """REALITY SPLICE: one clean cut; past it, another game's room."""
    o = []
    plum, ink, cream = mat(PLUM), mat(INK), mat(CREAM)
    seam = mat(MAGENTA, 3.0)
    # The seam itself, on floor, north wall and ceiling.
    o.append(box("seam_floor", (0.14, 0.02, 21.4), (SEAM_X, 0.015, 1.3), seam))
    o.append(box("seam_wall", (0.14, 12.6, 0.06), (SEAM_X, 9.7, -11.95),
                 seam))
    o.append(box("seam_ceiling", (0.14, 0.06, 24.0), (SEAM_X, 15.95, 0.0),
                 seam))
    # Past it: a 2 m plum-and-ink floor, clear of the stair's footprint.
    for i, x in enumerate(range(3, 12, 2)):
        for j, zz in enumerate(range(-8, 12, 2)):
            o.append(box("tile", (1.96, 0.02, 1.96), (x, 0.01, zz + 0.5),
                         plum if (i + j) % 2 else ink))
    # Past it, the walls are rebuilt in chunky cream courses -- the north
    # wall behind the stair, and the east wall either side of the
    # Courtyard's opening and over it.
    def courses(axis, fixed, lo, hi, y0, y1, inset):
        row, y = 0, y0 + 0.75
        while y < y1:
            u = lo + (0.0 if row % 2 else 1.0)
            u = max(u, lo)
            while u < hi - 0.1:
                w = min(2.0, hi - u)
                if axis == "x":
                    o.append(box("course", (w - 0.12, 1.38, 0.3),
                                 (u + w / 2, y, fixed + inset), cream))
                else:
                    o.append(box("course", (0.3, 1.38, w - 0.12),
                                 (fixed + inset, y, u + w / 2), cream))
                u += 2.0
            row += 1
            y += 1.5
    courses("x", -12.0, SEAM_X + 0.15, 12.0, 0.0, 16.0, 0.15)
    courses("z", 12.0, -12.0, -6.0, 0.0, 16.0, -0.15)
    courses("z", 12.0, 8.0, 12.0, 0.0, 16.0, -0.15)
    courses("z", 12.0, -6.0, 8.0, 12.0, 16.0, -0.15)
    # An inverted terrace hung from the sky: impossible, and plainly
    # nothing to climb.
    for i, (w, d, y) in enumerate(((7.0, 7.0, 15.4), (5.2, 5.2, 14.2),
                                   (3.4, 3.4, 13.0), (1.6, 1.6, 11.8))):
        o.append(box("terrace_%d" % i, (w, 1.2, d), (7.5, y, -1.5),
                     plum if i % 2 == 0 else mat(PINK, 0.3)))
    # The ceiling past the seam: an ink sky with cubes hung in it, turned
    # 45 degrees -- structure the station could not have built.
    o.append(box("sky", (9.9, 0.05, 24.0), (SEAM_X + 5.0, 15.96, 0.0), ink))
    for i, (x, y, z, s) in enumerate([(5.0, 13.0, -4.0, 1.4),
                                      (8.5, 12.0, 1.0, 1.0),
                                      (6.5, 13.8, 6.0, 1.7),
                                      (10.0, 13.2, -7.5, 1.2),
                                      (4.0, 12.4, 9.0, 0.9)]):
        o.append(box("float_%d" % i, (s, s, s), (x, y, z),
                     cream if i % 2 else mat(PINK, 0.4), 45.0, (35.3, 0.0)))
    return o


def hybrid():
    return splice() + bloom(seam_only=True) + cabinet(marquee_only=True)


STUDIES = {"overlay_bloom": bloom, "overlay_cabinet": cabinet,
           "overlay_splice": splice, "overlay_hybrid": hybrid}


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    os.makedirs(out, exist_ok=True)
    for name, build in STUDIES.items():
        common.reset_scene()
        _MATS.clear()
        objs = build()
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        path = os.path.join(out, name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                                  use_selection=True, export_apply=True,
                                  export_materials="EXPORT", export_yup=True)
        tris = sum(len(p.vertices) - 2 for o in objs
                   for p in o.data.polygons)
        print("[overlay] %s: %d objects, %d tris" % (name, len(objs), tris))


if __name__ == "__main__":
    main()
