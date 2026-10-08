"""Bloom as the connective tissue between realities: a staged study.
(Arty, 2026-10-08.)

    .tools/blender/blender -b --python tools/blender/study_bloom_transition.py -- <out_dir>

REVIEW-ONLY, not assets. The owner's direction (2026-10-08): a Crossing
starts as recognisable station, meets a little Bloom, then more, then
rooms that belong to the visited game, then Bloom again on the way back
to station. Bloom is the TRANSFORMATION -- what turns one reality's
architecture into the other's -- not a decoration of every room.

Five stages, each one .glb authored in Crossing D's Central Hall
coordinates, photographed from the same camera by
`tools/crossing_capture/dcap.gd` on the quieted station (ceilings and the
dead-end stair, the owner's selective correction):

    bloom_s0  station                 nothing added
    bloom_s1  first intrusion         one seed at the way on; three panels
                                      pushed off the wall; light in two seams
    bloom_s2  contamination           veins run the wall courses; panels
                                      peel in a band; the first foreign
                                      structure grows out of the Bloom
    bloom_s3  the visited world       most of the room is the other world;
                                      the station survives as the lift and
                                      the west wall; Bloom only on the seam
    bloom_s4  the way back            all foreign, except round the exit,
                                      where Bloom peels the foreign skin back
                                      off station panels -- s1 in reverse

THE GRAMMAR (what makes it transformation, in order of contact):
  1. a station panel is pushed off its wall along its own normal;
  2. Bloom fills the seam behind it -- light leaks out of the joints first;
  3. a crystal mass grows where the seams cross;
  4. out of that mass, the foreign architecture's own pieces grow in.

THE FOREIGN WORLD IS A PLACEHOLDER: "TEMP-WORLD", cream stone with dark
plum-brown banding, stepped arches and coffered beams. No source game has
been chosen; it is not a canonical look for any game, and it stays clear
of every gameplay colour. Bloom keeps the magenta / pink / plum of the
2026-10-08 studies.
"""

from __future__ import annotations

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import study_crossing_overlays as ov  # noqa: E402

box, spike, mat = ov.box, ov.spike, ov.mat
MAGENTA, PINK, PLUM = ov.MAGENTA, ov.PINK, ov.PLUM
PANEL = "#aeb3b1"        # a station wall panel's lit average (sampled)
CREAM = "#efe2c8"        # TEMP-WORLD stone
BROWN = "#4a2b2f"        # TEMP-WORLD banding and beams
NICHE = "#1c1216"


def vein(name, a, b, thick=0.09, glow=2.6):
    """Bloom light in a seam: a straight run between two points in D's
    frame (one axis), slightly proud of its surface."""
    cx, cy, cz = [(a[i] + b[i]) / 2.0 for i in range(3)]
    size = [max(abs(b[i] - a[i]), thick) for i in range(3)]
    return box(name, size, (cx, cy, cz), mat(MAGENTA, glow))


def seed(tag, base, spokes):
    """A crystal mass where seams cross: (tip, radius, lit) spokes."""
    out = []
    for i, (tip, r, lit) in enumerate(spokes):
        out.append(spike("%s_%d" % (tag, i), base, tip, r,
                         mat(MAGENTA, 2.2) if lit else
                         (mat(PINK, 0.35) if i % 2 else mat(PLUM))))
    return out


def heave(tag, at, size, yaw, tilt):
    """A station panel, pushed off its wall and turned."""
    return box(tag, size, at, mat(PANEL), yaw, tilt)


# --- TEMP-WORLD pieces --------------------------------------------------------

def courses(tag, x0, x1, y0, y1, z, depth=0.35):
    """Cream stone courses on a north-facing wall plane (z), 1 m tall,
    running bond, a brown band every third course."""
    out, row, y = [], 0, y0 + 0.5
    while y < y1:
        brown_row = row % 3 == 2
        u = x0 + (0.0 if row % 2 else 1.0)
        u = max(u, x0)
        while u < x1 - 0.05:
            w = min(2.0, x1 - u)
            out.append(box(tag, (w - 0.08, 0.92, depth),
                           (u + w / 2.0, y, z + depth / 2.0),
                           mat(BROWN if brown_row else CREAM)))
            u += 2.0
        row += 1
        y += 1.0
    return out


def arch(tag, cx, z, width=2.6, height=4.2):
    """A stepped arch niche on the north wall: dark recess, cream jambs,
    a stepped head -- the foreign world's signature shape."""
    out = [box(tag + "_niche", (width, height, 0.1), (cx, height / 2.0,
                                                     z + 0.36),
               mat(NICHE))]
    for side in (-1, 1):
        out.append(box(tag + "_jamb", (0.45, height, 0.55),
                       (cx + side * (width / 2.0 + 0.2), height / 2.0,
                        z + 0.3), mat(CREAM)))
    steps = 4
    for i in range(steps):
        w = width - i * (width / (steps + 1.0))
        out.append(box(tag + "_head", (w + 0.9, 0.35, 0.55),
                       (cx, height + 0.18 + i * 0.35, z + 0.3), mat(CREAM)))
    out.append(box(tag + "_key", (0.5, 0.5, 0.6),
                   (cx, height + 0.18 + steps * 0.35, z + 0.32),
                   mat(BROWN)))
    return out


def floor_tiles(tag, x0, x1, z0, z1):
    out = []
    x = x0
    while x < x1 - 0.1:
        z = z0
        while z < z1 - 0.1:
            w, d = min(2.0, x1 - x), min(2.0, z1 - z)
            out.append(box(tag, (w - 0.1, 0.03, d - 0.1),
                           (x + w / 2.0, 0.02, z + d / 2.0), mat(CREAM)))
            z += 2.0
        x += 2.0
    # Brown bands in the joints every 4 m.
    for x in range(int(math.ceil(x0 / 4.0) * 4), int(x1), 4):
        out.append(box(tag + "_band", (0.22, 0.035, z1 - z0),
                       (x, 0.022, (z0 + z1) / 2.0), mat(BROWN)))
    return out


def coffers(tag, x0, x1, z0, z1, y=15.6):
    out = [box(tag + "_field", (x1 - x0, 0.05, z1 - z0),
               ((x0 + x1) / 2.0, y + 0.3, (z0 + z1) / 2.0), mat(CREAM))]
    x = x0
    while x <= x1 + 0.01:
        out.append(box(tag + "_beam", (0.45, 0.7, z1 - z0),
                       (x, y, (z0 + z1) / 2.0), mat(BROWN)))
        x += 3.0
    z = z0
    while z <= z1 + 0.01:
        out.append(box(tag + "_beam", (x1 - x0, 0.6, 0.4),
                       ((x0 + x1) / 2.0, y + 0.05, z), mat(BROWN)))
        z += 3.0
    return out


def west_courses(tag, z0, z1, y0, y1, x, depth=0.35):
    """The same courses on the west wall (facing +x)."""
    out, row, y = [], 0, y0 + 0.5
    while y < y1:
        u = z0 + (0.0 if row % 2 else 1.0)
        u = max(u, z0)
        while u < z1 - 0.05:
            w = min(2.0, z1 - u)
            out.append(box(tag, (depth, 0.92, w - 0.08),
                           (x + depth / 2.0, y, u + w / 2.0),
                           mat(BROWN if row % 3 == 2 else CREAM)))
            u += 2.0
        row += 1
        y += 1.0
    return out


# --- the stages ---------------------------------------------------------------

def s1():
    """First intrusion, at the way on (the Courtyard opening, east)."""
    o = seed("seed_exit", (11.9, 0.0, -6.3), [
        ((10.2, 3.6, -5.2), 0.8, False), ((10.6, 1.8, -4.4), 0.55, True),
        ((9.8, 1.2, -7.0), 0.5, False), ((11.2, 5.0, -7.2), 0.45, True)])
    # Three panels pushed off the opening's jamb wall beside it.
    o += [heave("heave", (11.75, 2.0, -8.2), (0.12, 1.95, 1.15), 0, (6, -14)),
          heave("heave", (11.7, 4.2, -9.4), (0.12, 1.95, 1.15), 0, (-6, -10)),
          heave("heave", (11.8, 6.3, -7.6), (0.12, 1.95, 1.15), 0, (4, -6))]
    # Light leaking out of the seams it has reached.
    o += [vein("vein", (11.85, 0.0, -6.3), (11.85, 7.0, -6.3)),
          vein("vein", (11.85, 3.1, -6.3), (11.85, 3.1, -11.0)),
          vein("vein", (11.9, 0.012, -6.3), (7.8, 0.012, -6.3))]
    return o


def s2():
    """Contamination: veins run the courses, panels peel in a band, and
    the first foreign structure grows out of the Bloom -- on the wall above
    the stair, where the room is looked at."""
    o = s1()
    for y in (9.4, 11.8, 14.2):
        o.append(vein("vein", (-4.4, y, -11.93), (11.9, y, -11.93)))
    for x in (-1.2, 2.4, 6.0):
        o.append(vein("vein", (x, 6.0, -11.93), (x, 15.6, -11.93)))
    for i, (x, y, yaw, tx, tz) in enumerate([
            (-2.8, 10.6, 5, -14, 5), (-0.4, 13.0, -6, -18, -4),
            (4.4, 10.4, 8, -12, 7), (5.6, 13.2, -3, -16, -6),
            (8.0, 11.0, 4, -10, -4)]):
        o.append(heave("heave", (x, y, -11.5), (1.15, 1.95, 0.12), yaw,
                       (tx, tz)))
    o += seed("seed_floor", (6.0, -0.4, -4.0), [
        ((6.4, 4.2, -3.4), 1.0, False), ((8.0, 2.4, -2.4), 0.65, True),
        ((4.6, 2.2, -3.0), 0.6, False), ((6.2, 1.8, -5.8), 0.45, True)])
    o.append(vein("vein", (6.0, 0.012, -4.0), (11.9, 0.012, -4.0)))
    o.append(vein("vein", (6.0, 0.012, -4.0), (6.0, 0.012, -9.4)))
    # The foreign world arrives: stone courses replacing the panels in a
    # patch above the stair, and a stepped arch growing out of them, its
    # foot still sunk in a Bloom mass.
    o += courses("stone_first", -0.6, 5.0, 9.0, 15.6, -12.0)
    raised = arch("arch_first", 2.2, -11.6, 2.2, 3.0)
    for piece in raised:
        piece.location.z += 9.0      # Blender z = room y: the arch sits high
    o += raised
    o += seed("seed_arch", (0.8, 9.0, -11.6), [
        ((-0.6, 11.4, -10.2), 0.8, False), ((1.6, 10.6, -9.6), 0.55, True),
        ((0.0, 8.2, -9.8), 0.45, True)])
    o.append(vein("vein", (-4.4, 15.95, -6.0), (11.9, 15.95, -6.0)))
    return o


SEAM_X = -4.3


def s3():
    """The visited world: the room is TEMP-WORLD east of a seam at x -4.3;
    the station survives as the lift and the west wall."""
    o = []
    o += courses("stone", SEAM_X + 0.2, 11.9, 0.0, 16.0, -12.0)
    o += arch("arch_a", 1.2, -12.0)
    o += arch("arch_b", 7.0, -12.0)
    o += floor_tiles("tile", SEAM_X + 0.2, 11.9, -9.4, 11.9)
    o += coffers("coffer", SEAM_X + 0.2, 11.9, -11.9, 11.9)
    # Bloom only on the seam between the two realities.
    o.append(vein("seam_floor", (SEAM_X, 0.015, -11.9), (SEAM_X, 0.015, 11.9),
                  thick=0.16, glow=3.0))
    o.append(vein("seam_wall", (SEAM_X, 0.0, -11.9), (SEAM_X, 16.0, -11.9),
                  thick=0.16, glow=3.0))
    o.append(vein("seam_ceiling", (SEAM_X, 15.95, -11.9),
                  (SEAM_X, 15.95, 11.9), thick=0.16, glow=3.0))
    o += seed("seam_seed", (SEAM_X, -0.3, 3.0), [
        ((SEAM_X - 0.6, 2.8, 3.6), 0.7, False),
        ((SEAM_X + 0.8, 1.8, 2.2), 0.5, True)])
    o += seed("seam_seed_hi", (SEAM_X, 13.0, -12.5), [
        ((SEAM_X - 1.2, 10.8, -9.8), 0.8, False),
        ((SEAM_X + 0.9, 12.4, -9.4), 0.5, True)])
    return o


def s4():
    """The way back: all TEMP-WORLD, except round the exit (the lift),
    where Bloom peels the foreign skin back off the station again."""
    o = s3()
    # The west wall goes foreign too (z -12..12, facing +x).
    o += west_courses("stone_w", -12.0, 12.0, 0.0, 16.0, -12.0)
    o += floor_tiles("tile_w", -11.9, SEAM_X + 0.2, -7.4, 11.9)
    o += coffers("coffer_w", -11.9, SEAM_X + 0.2, -11.9, 11.9)
    # Round the lift: foreign stones peeled off and hanging, Bloom in the
    # gap, station panels re-emerging behind -- s1 in reverse.
    for i, (x, y, tx) in enumerate([(-10.6, 3.0, -30), (-10.4, 7.0, -22),
                                    (-3.8, 2.4, 26), (-3.6, 6.6, 18),
                                    (-7.0, 15.0, 30)]):
        o.append(box("peel_%d" % i, (1.8, 0.9, 0.35), (x, y, -7.2),
                     mat(CREAM), 0.0, (tx, 0.0)))
    for x in (-10.0, -4.0):
        o.append(vein("ring", (x, 0.0, -7.75), (x, 14.6, -7.75), thick=0.14))
    o.append(vein("ring", (-10.0, 14.6, -7.75), (-4.0, 14.6, -7.75),
                  thick=0.14))
    o += seed("seed_back", (-10.3, -0.3, -7.2), [
        ((-11.0, 2.2, -6.0), 0.55, True), ((-9.4, 1.4, -5.8), 0.4, False)])
    return o


STAGES = {"bloom_s1": s1, "bloom_s2": s2, "bloom_s3": s3, "bloom_s4": s4}


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    os.makedirs(out, exist_ok=True)
    for name, build in STAGES.items():
        common.reset_scene()
        ov._MATS.clear()
        objs = build()
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"),
                                  export_format="GLB", use_selection=True,
                                  export_apply=True, export_materials="EXPORT",
                                  export_yup=True)
        print("[bloom] %s: %d objects" % (name, len(objs)))


if __name__ == "__main__":
    main()
