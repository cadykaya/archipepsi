"""The Shunter's six readable states, as a throwaway pose maquette.
DISPOSABLE CONCEPT, NOT THE ENEMY MODEL. (Arty, 2026-10-09.)

    .tools/blender/blender -b --python tools/blender/study_shunter_poses.py -- <out_dir>

Writes `shunter_<variant>_<state>.glb` (12 files) into the directory it
is given, never under `assets/`: blocks and flat colours, no textures, no
budget, no manifest, no rig. They exist to be photographed in Crossing
D's empty yard at the distances the fight happens at, so Prod's later
combat prototype starts from poses that are known to read.

From Dess's D-19 (`21cc00a4`); her encounter brief does not exist yet,
so anything that waits on her is marked DESS in the report. States:
WORK (tend / patrol), NOTICE (the 0.3 s horn), BRACE (0.7 s), CHARGE
(the 1.1 s rush), MISS (an overrun skid -- DESS: what a miss does is
hers) and RECOVER (1.4 s, helpless).

Two variants on one body, so the difference is only the cues:
  A -- D-19 as written: the plough drops 18 cm into the brace, lamps
       under the plough lip, the rear pack glows warm white in recovery.
  B -- the recommended cues: the plough TRAVELS (lip 0.40 m up when
       working, 0.48 m when it rears or recovers, on the deck when
       committed), an up-then-down anticipation
       (it rears on NOTICE before it drops into BRACE), lamps on the brow
       where the lowered plough cannot hide them, a nose-down skid on a
       MISS, and in RECOVER the plough folds high, two vent flaps open
       UPWARD and a warm-white plume rises -- a cue that reads from
       above, from behind and over low cover.

Frame: Crossing D's (x right, y up), the shunter faces -Z, origin on the
floor at the 0.90 x 1.05 x 1.90 m envelope's centre. The body never
leaves the envelope; only B's recovery plume and open flaps rise above
it, and they are light, not collision.
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
OFF = "#3a3a3e"

STATES = ("work", "notice", "brace", "charge", "miss", "recover")

#: Per state: body lift (m), pitch (deg, + = nose up), plough lip height
#: (m) and lean (deg, + = lip forward), the lip's z, legs, lamp colour and
#: energy, plough-edge red, rear glow, vents open.
POSES = {
    "A": {
        "work":    dict(dy=0.0, pitch=0, lip=0.20, lean=28, zl=-0.92,
                        legs="stand", lamp=(AMBER, 1.5), edge=False),
        "notice":  dict(dy=0.0, pitch=0, lip=0.20, lean=28, zl=-0.92,
                        legs="stand", lamp=(RED, 2.5), edge=False),
        "brace":   dict(dy=-0.07, pitch=-3, lip=0.02, lean=39, zl=-0.93,
                        legs="splay", lamp=(RED, 2.5), edge=True),
        "charge":  dict(dy=-0.03, pitch=-2, lip=0.04, lean=37, zl=-0.93,
                        legs="gallop", lamp=(RED, 2.5), edge=True),
        "miss":    dict(dy=-0.07, pitch=-3, lip=0.02, lean=39, zl=-0.93,
                        legs="splay", lamp=(RED, 1.0), edge=True),
        "recover": dict(dy=-0.04, pitch=5, lip=0.20, lean=28, zl=-0.92,
                        legs="buckle", lamp=(OFF, 0.0), edge=False,
                        rear=2.5),
    },
    "B": {
        "work":    dict(dy=0.0, pitch=0, lip=0.40, lean=-8, zl=-0.80,
                        legs="stand", lamp=(AMBER, 1.5), edge=False),
        "notice":  dict(dy=0.06, pitch=6, lip=0.48, lean=-14, zl=-0.80,
                        legs="tall", lamp=(RED, 3.5), edge=False,
                        horn=True),
        "brace":   dict(dy=-0.07, pitch=-4, lip=0.03, lean=12, zl=-0.92,
                        legs="splay", lamp=(RED, 2.5), edge=True),
        "charge":  dict(dy=-0.03, pitch=-6, lip=0.05, lean=15, zl=-0.92,
                        legs="gallop", lamp=(RED, 3.0), edge=True),
        "miss":    dict(dy=-0.05, pitch=-9, lip=0.00, lean=20, zl=-0.93,
                        legs="skid", lamp=(RED, 1.0), edge=True),
        "recover": dict(dy=-0.06, pitch=4, lip=0.48, lean=-30, zl=-0.66,
                        legs="buckle", lamp=(OFF, 0.0), edge=False,
                        rear=2.5, vents=True),
    },
}

PLOUGH = 0.55          # plate height, hinge-ish top to lip
PIVOT = (0.0, 0.55, 0.0)


def _rot(p, deg):
    """Rotate a point about the body pivot, about x; + = nose up."""
    a = math.radians(deg)
    y, z = p[1] - PIVOT[1], p[2] - PIVOT[2]
    return (p[0], PIVOT[1] + y * math.cos(a) - z * math.sin(a),
            PIVOT[2] + z * math.cos(a) + y * math.sin(a))


def build(variant, state):
    box, mat = ov.box, ov.mat
    p = POSES[variant][state]
    dy, pitch = p["dy"], p["pitch"]
    o = []

    def body(name, size, at, colour, emit=0.0, own=0.0):
        c = _rot((at[0], at[1] + dy, at[2]), pitch)
        o.append(box(name, size, c, mat(colour, emit), 0.0, (pitch + own, 0.0)))

    # Hull, spine, lane plate, the open rear frame and its pack.
    body("hull", (0.86, 0.46, 1.20), (0.0, 0.55, -0.05), PALE)
    body("spine", (0.56, 0.14, 0.62), (0.0, 0.85, 0.0), PALE)
    body("lane_plate", (0.02, 0.16, 0.40), (0.44, 0.61, 0.0), DARK)
    for x in (-0.40, 0.40):
        body("rear_bar", (0.06, 0.48, 0.06), (x, 0.57, 0.92), STEEL)
    body("rear_bar_top", (0.86, 0.06, 0.30), (0.0, 0.79, 0.80), STEEL)
    rear = p.get("rear", 0.0)
    body("pack", (0.50, 0.30, 0.22), (0.0, 0.55, 0.76),
         WARM if rear else DARK, rear)
    # The lamps. A: a low cluster under the plough lip (D-19). B: on the
    # brow, above the plough's top, where a lowered plough cannot hide
    # them.
    colour, energy = p["lamp"]
    for x in (-0.22, 0.0, 0.22):
        if variant == "A":
            body("lamp", (0.10, 0.08, 0.04),
                 (x, 0.42 - (0.20 - p["lip"]) * 0.4, -0.74), colour, energy)
        else:
            body("lamp", (0.12, 0.07, 0.04), (x, 0.90, -0.33), colour, energy)
    if p.get("horn"):
        for x in (-0.12, 0.12):
            body("horn", (0.08, 0.06, 0.10), (x, 0.90, -0.28), WARM, 2.0)
    # B's vents: two flaps on the top of the rear frame. Closed, they lie
    # flat; open, they stand up and back, and the plume rises between.
    if variant == "B":
        if p.get("vents"):
            for x in (-0.16, 0.16):
                body("vent_flap", (0.26, 0.30, 0.02), (x, 0.97, 0.74),
                     STEEL, 0.0, 70.0)
            body("vent_glow", (0.40, 0.04, 0.24), (0.0, 0.83, 0.80), WARM,
                 3.0)
            body("plume", (0.26, 0.70, 0.22), (0.0, 1.20, 0.82), WARM, 1.2)
        else:
            for x in (-0.16, 0.16):
                body("vent_flap", (0.26, 0.02, 0.24), (x, 0.83, 0.80), STEEL)
    # The plough: a full-width plate from its lip up, leaning.
    lean = math.radians(p["lean"])
    lip = (0.0, p["lip"], p["zl"])
    top = (0.0, lip[1] + PLOUGH * math.cos(lean),
           lip[2] + PLOUGH * math.sin(lean))
    mid = tuple((lip[i] + top[i]) / 2 for i in range(3))
    # Placed in the world, not through the body's pitch: the lip height
    # is the state, so it is exact.
    o.append(box("plough", (0.90, PLOUGH, 0.06), mid, mat(STEEL), 0.0,
                 (p["lean"], 0.0)))
    if p["edge"]:
        edge = (0.0, lip[1] + 0.025 * math.cos(lean) + 0.001,
                lip[2] + 0.025 * math.sin(lean) - 0.035)
        o.append(box("plough_edge", (0.90, 0.05, 0.02), edge, mat(RED, 2.5),
                     0.0, (p["lean"], 0.0)))
    # Four short piston legs: a box from hip to foot, and a foot pad.
    feet = {"stand": ((-0.48, 0.0), (0.48, 0.0)),
            "tall": ((-0.48, 0.0), (0.48, 0.0)),
            "splay": ((-0.70, 0.0), (0.70, 0.0)),
            "gallop": ((-0.82, 0.04), (0.78, 0.0)),
            "skid": ((-0.72, 0.0), (0.56, 0.10)),
            "buckle": ((-0.40, 0.0), (0.40, 0.0))}[p["legs"]]
    for x in (-0.36, 0.36):
        for hip_z, (foot_z, foot_y) in zip((-0.48, 0.48), feet):
            hip = _rot((x, 0.36 + dy, hip_z), pitch)
            foot = (x, foot_y + 0.03, foot_z)
            d = [foot[i] - hip[i] for i in range(3)]
            length = math.sqrt(d[1] ** 2 + d[2] ** 2)
            angle = math.degrees(math.atan2(-d[2], -d[1]))
            centre = tuple((hip[i] + foot[i]) / 2 for i in range(3))
            o.append(box("leg", (0.10, length, 0.10), centre, mat(DARK), 0.0,
                         (angle, 0.0)))
            o.append(box("foot", (0.16, 0.05, 0.20),
                         (x, foot_y + 0.025, foot_z), mat(DARK)))
    return o


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    os.makedirs(out, exist_ok=True)
    for variant in ("A", "B"):
        for state in STATES:
            common.reset_scene()
            ov._MATS.clear()
            objs = build(variant, state)
            bpy.ops.object.select_all(action="DESELECT")
            for obj in objs:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            bpy.ops.export_scene.gltf(
                filepath=os.path.join(out, "shunter_%s_%s.glb"
                                      % (variant, state)),
                export_format="GLB", use_selection=True, export_apply=True,
                export_materials="EXPORT", export_yup=True)
            print("[shunter] %s %s" % (variant, state))


if __name__ == "__main__":
    main()
