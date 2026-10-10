"""The Shunter as a throwaway maquette, to test READ at game scale.
DISPOSABLE CONCEPT, NOT THE ENEMY MODEL. (Arty, 2026-10-08.)

    .tools/blender/blender -b --python tools/blender/study_shunter_maquette.py -- <out_dir>

Writes `shunter_work.glb`, `shunter_brace.glb` and `shunter_recover.glb`
into the directory it is given, never under `assets/`: blocks and
colours only, no textures, no budget, no manifest. They exist to be
photographed in Crossing D's yard beside today's charger, at 8 and 18 m,
in colour and grey -- the one question a drawing cannot answer: does the
plough's drop (D-19: "the plough position is the state, readable from
20 m") and the white-hot rear read at the distance the fight starts?

Authored in Godot's frame directly (x right, y up, the shunter faces -Z),
inside D-19's envelope: 0.90 wide, 1.05 tall, 1.90 long, origin on the
floor at the envelope's centre.
"""

from __future__ import annotations

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import study_crossing_overlays as ov  # noqa: E402

PALE = "#d6d8d0"
STEEL = "#7a8086"
DARK = "#30333a"
AMBER = "#ffb040"
RED = "#eb2824"
WARM = "#ffecc8"
BLOOM = "#ff3fbf"


def maquette(state):
    box, mat = ov.box, ov.mat
    o = []
    drop = {"work": 0.0, "brace": 0.18, "recover": 0.0}[state]
    sink = {"work": 0.0, "brace": 0.07, "recover": 0.03}[state]
    tilt = {"work": 0.0, "brace": -3.0, "recover": 5.0}[state]
    y0 = 0.55 - sink
    # Hull (front is -Z): a long low deck and a raised spine.
    o.append(box("hull", (0.86, 0.46, 1.20), (0.0, y0, -0.05), mat(PALE),
                 0.0, (tilt, 0.0)))
    o.append(box("spine", (0.56, 0.14, 0.62), (0.0, y0 + 0.30, 0.0),
                 mat(PALE), 0.0, (tilt, 0.0)))
    o.append(box("lane_plate", (0.02, 0.16, 0.40), (0.44, y0 + 0.06, 0.0),
                 mat(DARK)))
    # The open rear frame and its pack (warm white in recovery).
    for x in (-0.40, 0.40):
        o.append(box("rear_bar", (0.06, 0.48, 0.06), (x, y0 + 0.02, 0.92),
                     mat(STEEL)))
    o.append(box("rear_bar_top", (0.86, 0.06, 0.30), (0.0, y0 + 0.24, 0.80),
                 mat(STEEL)))
    o.append(box("pack", (0.50, 0.30, 0.22), (0.0, y0, 0.76),
                 mat(WARM, 2.5) if state == "recover" else mat(DARK)))
    # The plough: a broad hinged face, full width, its lower lip DROPPING
    # into the brace. Red edge only when committed.
    lip_y = 0.20 - drop
    angle = 28.0 + drop * 60.0
    o.append(box("plough", (0.90, 0.70, 0.06),
                 (0.0, lip_y + 0.33, -0.86 - drop * 0.05), mat(STEEL), 0.0,
                 (angle, 0.0)))
    if state == "brace":
        o.append(box("plough_edge", (0.90, 0.05, 0.08),
                     (0.0, lip_y + 0.03, -0.95), mat(RED, 2.0)))
    lamp = mat(RED, 2.5) if state == "brace" else (
        mat(AMBER, 1.5) if state == "work" else mat("#5a4630"))
    for x in (-0.22, 0.0, 0.22):
        o.append(box("lamp", (0.10, 0.08, 0.04), (x, 0.42 - drop * 0.4,
                                                   -0.74), lamp))
    # Four short piston legs: upright working, splayed bracing, buckled
    # behind when recovering.
    spread = {"work": 0.0, "brace": 0.20, "recover": 0.06}[state]
    for x in (-0.36, 0.36):
        for z, sign in ((-0.48, -1), (0.48, 1)):
            foot_z = z + sign * spread
            o.append(box("leg", (0.10, 0.36, 0.10),
                         (x, 0.18, (z + foot_z) / 2.0), mat(DARK), 0.0,
                         (sign * spread * 120.0, 0.0)))
            o.append(box("foot", (0.16, 0.05, 0.20), (x, 0.025, foot_z),
                         mat(DARK)))
    # The Crossing's scramble: Bloom veins through the flank.
    if state in ("brace", "recover"):
        o.append(box("vein", (0.02, 0.04, 0.70), (0.44, y0 + 0.12, -0.05),
                     mat(BLOOM, 2.5)))
        o.append(box("vein", (0.02, 0.30, 0.04), (0.44, y0 + 0.02, 0.28),
                     mat(BLOOM, 2.5)))
    return o


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    os.makedirs(out, exist_ok=True)
    for state in ("work", "brace", "recover"):
        common.reset_scene()
        ov._MATS.clear()
        objs = maquette(state)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(
            filepath=os.path.join(out, "shunter_%s.glb" % state),
            export_format="GLB", use_selection=True, export_apply=True,
            export_materials="EXPORT", export_yup=True)
        print("[shunter] %s" % state)


if __name__ == "__main__":
    main()
