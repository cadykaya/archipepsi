"""The Shunter's LOOK, as variants on one maquette: a variant sheet, NOT
the enemy model. DISPOSABLE CONCEPT. (Arty, 2026-10-17.)

    .tools/blender/blender -b --python tools/blender/study_shunter_looks.py -- <out_dir>

Writes `shunter_<look>_<state>.glb` (9 looks x 4 states, plus a
lane-less brace per look, for measuring) into the
directory it is given, never under `assets/`: blocks and flat colours, no
textures, no budget, no rig.

The brief (Skyiah, via Condi, 2026-10-17; confirmed by the owner): about
seven variants plus the current design as a labelled control, ONE
VARIABLE AT A TIME, the same scale and camera, at gameplay distances, the
losing options kept in this source. Nothing is approved: the owner picks
after she has played the fight.

What every look keeps (D-20 rev 2 section 5, and the 2026-10-08
approvals):
  * the poses: pose-study B's table exactly (`study_shunter_poses.POSES`),
    with D-20's 0.37 m plough travel (the "larger plough" of 10-08), the
    horn rear-up, the brace with the plough on the deck and its red edge,
    the recovery with the vents open upward and a warm plume (the
    "upward vent" of 10-08);
  * the lit lane in the brace: a red floor strip 14.3 m along the rush;
  * the envelope: 0.90 wide, 1.05 tall, 1.90 long (only the plume and the
    open vents rise above it, as light, not collision);
  * the pale freight livery and D-19's colours: red only for hostile
    (lamps, the committed plough edge, the lane), amber points for work,
    warm white for vulnerable. Never orange bands, green on the body or
    yellow-and-black.

The looks (each differs from C0 in the one thing named):
  C0  the control: pose-study B as it stands (three brow lamps, flat
      plough, two vent flaps, piston legs, pale with a dark lane plate)
  L1  plough SHAPE: a V-prow, two half-plates meeting forward
  L2  plough LIP: a bright bare-steel lip band across the plough's foot
  L3  LAMPS: one 0.60 m bar (as Prod's blockout has it) for three lamps
  L4  VENT: one central stack whose cap lifts 0.25 m, for two flaps
  L5  HULL: lower and longer (a tug), the spine folded in
  L6  LEGS: reverse-knee legs for straight pistons
  L7  LIVERY: two-tone, pale over a steel skirt, with the lane number
      carried large on the flanks and the plough's back
  R   reference, not a variant: Prod's graybox in `integration/unified-1`
      (`godot/scripts/unified/shunter.gd`, `_build_blockout`): his
      dimensions and colours, posed by the same table
"""

from __future__ import annotations

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import study_crossing_overlays as ov  # noqa: E402
import study_shunter_poses as sp  # noqa: E402

PALE, STEEL, DARK = sp.PALE, sp.STEEL, sp.DARK
AMBER, RED, WARM, OFF = sp.AMBER, sp.RED, sp.WARM, sp.OFF
BRIGHT = "#b8bec4"          # bare steel, worn bright (L2's lip band)
PROD_STEEL = "#33363b"      # Prod's Color(0.2, 0.21, 0.23)
PROD_DARK = "#1c1c1f"       # Prod's Color(0.11, 0.11, 0.12)
LANE = "#7a2620"            # his lane, Color(1, 0.12, 0.08, 0.45) on the deck

STATES = ("work", "notice", "brace", "recover")
LOOKS = ("C0", "L1", "L2", "L3", "L4", "L5", "L6", "L7", "R")
LABELS = {
    "C0": "C0 control: pose-study B",
    "L1": "L1 plough shape: V-prow",
    "L2": "L2 plough lip: bright steel band",
    "L3": "L3 lamps: one 0.60 m bar",
    "L4": "L4 vent: one lifting stack",
    "L5": "L5 hull: low and long",
    "L6": "L6 legs: reverse-knee",
    "L7": "L7 livery: two-tone, big lane number",
    "R": "R reference: Prod's graybox (unified-1)",
}
#: the rush lane, D-20: 13 m/s for 1.1 s
LANE_LENGTH = 14.3


def build(look, state):
    """`state` may be `brace_nolane`: the brace without its floor lane,
    which is photographed only to measure the BODY's change (the lane is
    the same in every look and would otherwise swamp the number)."""
    box, mat = ov.box, ov.mat
    lane = state != "brace_nolane"
    state = "brace" if not lane else state
    p = sp.POSES["B"][state]
    dy, pitch = p["dy"], p["pitch"]
    prod = look == "R"
    hull_c = PROD_STEEL if prod else PALE
    trim_c = PROD_DARK if prod else DARK
    o = []

    def body(name, size, at, colour, emit=0.0, own=0.0):
        c = sp._rot((at[0], at[1] + dy, at[2]), pitch)
        o.append(box(name, size, c, mat(colour, emit), 0.0,
                     (pitch + own, 0.0)))

    # ---------------------------------------------------------- hull
    if prod:
        body("hull", (0.80, 0.50, 1.60), (0.0, 0.60, 0.05), hull_c)
        body("cab", (0.70, 0.18, 0.50), (0.0, 0.92, 0.35), trim_c)
    elif look == "L5":
        # lower and longer: 8 cm off the top, 20 cm on the length, the
        # spine folded into a low deck
        body("hull", (0.86, 0.38, 1.40), (0.0, 0.51, -0.02), PALE)
        body("spine", (0.56, 0.06, 0.80), (0.0, 0.73, 0.05), PALE)
    elif look == "L7":
        body("hull_upper", (0.86, 0.26, 1.20), (0.0, 0.65, -0.05), PALE)
        body("hull_skirt", (0.87, 0.20, 1.21), (0.0, 0.42, -0.05), STEEL)
        body("spine", (0.56, 0.14, 0.62), (0.0, 0.85, 0.0), PALE)
    else:
        body("hull", (0.86, 0.46, 1.20), (0.0, 0.55, -0.05), PALE)
        body("spine", (0.56, 0.14, 0.62), (0.0, 0.85, 0.0), PALE)
    # the lane number plate: small on the flank (C0), large on both flanks
    # (L7); Prod's graybox has none
    if look == "L7":
        for x in (-0.44, 0.44):
            body("lane_number", (0.02, 0.22, 0.56),
                 (x, 0.64, -0.05), DARK)
            body("lane_digit", (0.021, 0.14, 0.10),
                 (x * 1.001, 0.64, -0.12), PALE)
            body("lane_digit", (0.021, 0.14, 0.10),
                 (x * 1.001, 0.64, 0.02), PALE)
    elif not prod:
        body("lane_plate", (0.02, 0.16, 0.40), (0.44, 0.61, 0.0), DARK)
    # the open rear frame and its pack
    if not prod:
        top = 0.71 if look == "L5" else 0.79
        for x in (-0.40, 0.40):
            body("rear_bar", (0.06, top - 0.31, 0.06),
                 (x, (top + 0.35) / 2, 0.92), STEEL)
        body("rear_bar_top", (0.86, 0.06, 0.30), (0.0, top, 0.80), STEEL)
        rear = p.get("rear", 0.0)
        body("pack", (0.50, 0.30, 0.22), (0.0, 0.55, 0.76),
             WARM if rear else DARK, rear)

    # ---------------------------------------------------------- lamps
    colour, energy = p["lamp"]
    brow_y = 0.80 if look == "L5" else 0.90
    if prod:
        body("lamp_bar", (0.60, 0.08, 0.06), (0.0, 0.98, -0.62), colour,
             energy)
    elif look == "L3":
        body("lamp_bar", (0.60, 0.08, 0.04), (0.0, brow_y, -0.33), colour,
             energy)
    else:
        for x in (-0.22, 0.0, 0.22):
            body("lamp", (0.12, 0.07, 0.04), (x, brow_y, -0.33), colour,
                 energy)
    if p.get("horn"):
        hy = 1.00 if prod else brow_y
        hz = -0.58 if prod else -0.28
        for x in (-0.12, 0.12):
            body("horn", (0.08, 0.06, 0.10), (x, hy, hz), WARM, 2.0)

    # ---------------------------------------------------------- vents
    vents = p.get("vents")
    if look == "L4":
        # one central stack: a short square chimney whose cap lifts 0.25 m
        body("stack", (0.24, 0.12, 0.24), (0.0, 0.88, 0.80), STEEL)
        if vents:
            body("stack_cap", (0.30, 0.03, 0.30), (0.0, 1.19, 0.80), STEEL)
            body("stack_glow", (0.20, 0.04, 0.20), (0.0, 0.95, 0.80),
                 WARM, 3.0)
            body("plume", (0.22, 0.80, 0.22), (0.0, 1.45, 0.80), WARM, 1.2)
        else:
            body("stack_cap", (0.30, 0.03, 0.30), (0.0, 0.955, 0.80),
                 STEEL)
    else:
        fy = 0.75 if look == "L5" else 0.83
        fx = (-0.18, 0.18) if prod else (-0.16, 0.16)
        fz = 0.73 if prod else 0.80
        flap_c = trim_c if prod else STEEL
        if vents:
            for x in fx:
                body("vent_flap", (0.26, 0.30, 0.02), (x, fy + 0.14, fz - 0.06),
                     flap_c, 0.0, 70.0)
            body("vent_glow", (0.40, 0.04, 0.24), (0.0, fy, fz), WARM, 3.0)
            body("plume", (0.26, 0.70, 0.22), (0.0, fy + 0.37, fz + 0.02),
                 WARM, 1.2)
        else:
            for x in fx:
                body("vent_flap", (0.26, 0.02, 0.24), (x, fy, fz), flap_c)

    # ---------------------------------------------------------- plough
    lean = math.radians(p["lean"])
    h = 0.50 if prod else sp.PLOUGH
    lip = (0.0, p["lip"], p["zl"])
    topp = (0.0, lip[1] + h * math.cos(lean), lip[2] + h * math.sin(lean))
    mid = tuple((lip[i] + topp[i]) / 2 for i in range(3))
    plough_c = PROD_STEEL if prod else STEEL
    if look == "L1":
        # two half-plates, each turned 18 degrees back from the centre
        # line: the prow points along the rush. Same height, same travel,
        # the same 0.90 m overall width
        for side in (-1, 1):
            half = 0.47
            cx = side * half / 2 * math.cos(math.radians(18))
            cz = mid[2] + half / 2 * math.sin(math.radians(18))
            o.append(box("plough_half", (half, h, 0.06), (cx, mid[1], cz),
                         mat(plough_c), side * -18.0, (p["lean"], 0.0)))
    else:
        o.append(box("plough", (0.90, h, 0.08 if prod else 0.06), mid,
                     mat(plough_c), 0.0, (p["lean"], 0.0)))
    if look == "L2":
        band = (0.0, lip[1] + 0.06 * math.cos(lean) + 0.001,
                lip[2] + 0.06 * math.sin(lean) - 0.032)
        o.append(box("plough_lip_band", (0.90, 0.12, 0.01), band,
                     mat(BRIGHT), 0.0, (p["lean"], 0.0)))
    if look == "L7":
        back = tuple(mid[i] + (0.0, 0.0, 0.035)[i] for i in range(3))
        o.append(box("plough_number", (0.36, 0.20, 0.01), back, mat(DARK),
                     0.0, (p["lean"], 0.0)))
    if p["edge"]:
        edge = (0.0, lip[1] + 0.025 * math.cos(lean) + 0.001,
                lip[2] + 0.025 * math.sin(lean) - 0.035)
        o.append(box("plough_edge", (0.90, 0.05, 0.02), edge, mat(RED, 2.5),
                     0.0, (p["lean"], 0.0)))
    if p["edge"] and lane:
        # the lit lane: D-20's floor strip along the locked rush, in the
        # muted red Prod's runtime draws it (red at 45 % over the deck);
        # the same in every look, so it biases no comparison
        o.append(box("lane", (0.90, 0.005, LANE_LENGTH),
                     (0.0, 0.004, lip[2] - LANE_LENGTH / 2),
                     mat(LANE, 0.4), 0.0, (0.0, 0.0)))

    # ---------------------------------------------------------- legs
    if prod:
        for x in (-0.32, 0.32):
            for z in (-0.55, 0.60):
                body("leg", (0.14, 0.38, 0.18), (x, 0.19, z), trim_c)
        return o
    feet = {"stand": ((-0.48, 0.0), (0.48, 0.0)),
            "tall": ((-0.48, 0.0), (0.48, 0.0)),
            "splay": ((-0.70, 0.0), (0.70, 0.0)),
            "buckle": ((-0.40, 0.0), (0.40, 0.0))}[p["legs"]]
    hip_y = 0.30 if look == "L5" else 0.36
    for x in (-0.36, 0.36):
        for hip_z, (foot_z, foot_y) in zip((-0.48, 0.48), feet):
            hip = sp._rot((x, hip_y + dy, hip_z), pitch)
            foot = (x, foot_y + 0.03, foot_z)
            if look == "L6":
                # a reverse knee: the joint sits behind and above the
                # straight line, so the shin rakes forward to the foot
                knee = (x, (hip[1] + foot[1]) / 2 + 0.04,
                        (hip[2] + foot[2]) / 2 + 0.16)
                segs = ((hip, knee), (knee, foot))
            else:
                segs = ((hip, foot),)
            for a, b in segs:
                d = [b[i] - a[i] for i in range(3)]
                length = math.sqrt(d[1] ** 2 + d[2] ** 2)
                angle = math.degrees(math.atan2(-d[2], -d[1]))
                centre = tuple((a[i] + b[i]) / 2 for i in range(3))
                o.append(box("leg", (0.10, length, 0.10), centre, mat(DARK),
                             0.0, (angle, 0.0)))
            o.append(box("foot", (0.16, 0.05, 0.20),
                         (x, foot_y + 0.025, foot_z), mat(DARK)))
    return o


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    os.makedirs(out, exist_ok=True)
    for look in LOOKS:
        for state in STATES + ("brace_nolane",):
            common.reset_scene()
            ov._MATS.clear()
            objs = build(look, state)
            bpy.ops.object.select_all(action="DESELECT")
            for obj in objs:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            bpy.ops.export_scene.gltf(
                filepath=os.path.join(out, "shunter_%s_%s.glb"
                                      % (look, state)),
                export_format="GLB", use_selection=True, export_apply=True,
                export_materials="EXPORT", export_yup=True)
            print("[shunter] %s %s" % (look, state))


if __name__ == "__main__":
    main()
