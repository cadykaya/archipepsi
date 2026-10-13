"""The approved weapons, developed toward the Foundry's fidelity.
(Arty, 2026-10-13.) DEVELOPMENT MODELS: approved concept directions, not
finished weapons; nothing here is registered, merged or shipped.

    .tools/blender/blender -b --python tools/blender/build_weapon_model.py \
        -- preview|bake|assemble|look WEAPON OUT

WEAPON is sightline, switchback or driver (the owner's choices of
2026-10-13: Sightline A Accelerator, Switchback A Jacketed, Mass Driver A
Rotor). The pipeline is the Foundry study's, step for step:

  bake      refined geometry -> one atlas unwrap -> ID/position/normal/
            edge/AO bakes + bake.json (with this weapon's WEAR SPEC)
  (paint)   tools/blender/weapon_paint.py OUT
  (Glyph)   tools/glyphui/author_weapon_maps.py OUT WEAPON
  assemble  the GLB, wearing Glyph's maps, + <weapon>.json (the metrics)
  look      the painted maps on the model in Cycles, before Godot
  preview   clay renders of the refined geometry

The geometry starts from the approved form (`build_weapon_forms.py`) and
adds only what has a job -- each addition below says what it is for. The
WEAR SPEC places the history: where it is hot, where hands polish it, where
oil runs and rust starts, which welds and grinds are repairs, what is
stencilled and stamped. Positions are Godot viewmodel space (metres).

The metrics rule (the owner, 2026-10-13): triangle counts are provisional;
record triangles, materials, textures and draw calls; profile in the game
once designs are approved; no preemptive reduction. The atlas is sized so
the texel density matches the approved Foundry's (~1,150 texels/m).
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import build_foundry_study as fs  # noqa: E402
import build_weapon_forms as wf  # noqa: E402
import common  # noqa: E402
from build_foundry_study import (box, cyl, hexhead, hull, ngon,  # noqa: E402
                                 prism, sweep, tube)
from build_weapon_forms import side_panel, weld  # noqa: E402

#: the approved Foundry's measured density (its study record)
TARGET_DENSITY = 1150.0


def _ring_bolts(name, cx, cy, z, r, n, sign, phase=0.0, hr=0.0024,
                h=0.0016):
    return [hexhead("%s%d" % (name, k), (cx + r * math.cos(phase + k * 2
                                                           * math.pi / n),
                                         cy + r * math.sin(phase + k * 2
                                                           * math.pi / n),
                                         z), "z", sign, hr, h,
                    part=name) for k in range(n)]


# ============================================================ SIGHTLINE

def refine_sightline():
    E = []
    # a recoil buffer at the back of the receiver: the rifle kicks, and the
    # bolt carrier needs something to stop against (also the face nearest
    # the eye, so it should read as built)
    E.append(tube("buffer_flange", 0.0190, 0.0125, 8, 0.0, 0.004, 0.0725,
                  0.0770, "bare", bevel=0.0008))
    E += _ring_bolts("buffer_bolt", 0.0, 0.004, 0.0770, 0.0158, 3, 1,
                     math.pi / 2, 0.0020, 0.0012)
    E.append(cyl("buffer", 0.0125, 8, 0.0, 0.004, 0.0760, 0.0860, "bare",
                 bevel=0.0012))
    E.append(cyl("buffer_pad", 0.0110, 8, 0.0, 0.004, 0.0860, 0.0920,
                 "rubber", bevel=0.0015))
    # each stator pack takes its own lead off the bus, into a terminal
    for i, z in enumerate((-0.350, -0.440, -0.530)):
        E.append(box("stator_term%d" % i, -0.019, -0.008, 0.048, 0.0575,
                      z - 0.006, z + 0.006, "bare", bevel=0.0008))
        E.append(sweep("stator_lead%d" % i, [(-0.0235, 0.046, z + 0.024),
                                             (-0.0215, 0.056, z + 0.014),
                                             (-0.0150, 0.0585, z + 0.004)],
                       0.0021, 6, "cable"))
        E.append(hexhead("stator_post%d" % i, (-0.0135, 0.0575, z), "y", 1,
                         0.0022, 0.0014, part="stator_posts"))
    # the trunnion cracked once and was plated over: a cut plate, bolted
    E += side_panel("repair_plate", -0.0262, -0.212, -0.184, -0.022, 0.008,
                    -1, "patch")
    E.append(weld("weld_repair", [(-0.0284, 0.0085, -0.2115),
                                  (-0.0286, 0.0088, -0.198),
                                  (-0.0284, 0.0085, -0.1845)]))
    return E, {}


SPEC_SIGHTLINE = {
    "bore": [0.0, 0.025], "ends": [-0.745, 0.092], "bottom_y": -0.034,
    "trim": 0.32, "grime": 0.18, "seed": 2201,
    "heat": [
        {"a": [0, 0.025, -0.250], "b": [0, 0.025, -0.205], "r": 0.020,
         "fall": 0.020, "w": 1.0, "burn": True},
        {"a": [0, 0.025, -0.745], "b": [0, 0.025, -0.700], "r": 0.025,
         "fall": 0.015, "w": 1.0},
    ] + [{"a": [0, 0.025, z - 0.017], "b": [0, 0.025, z + 0.017],
          "r": 0.024, "fall": 0.006, "w": 0.45} for z in (-0.35, -0.44,
                                                          -0.53)],
    "soot": [[[0, 0.025, -0.748], [0, 0.025, -0.700], 0.036, 0.9],
             [[-0.024, 0.020, -0.140], [-0.024, 0.020, -0.030], 0.012,
              0.5]],
    "contact": [[[-0.050, 0.021, -0.080], 0.013, 1.0],     # bolt knob
                [[0.0, -0.101, -0.222], 0.010, 0.8],       # core tab
                [[-0.022, 0.036, -0.010], 0.022, 0.5],     # hand rest
                [[0.0, -0.034, 0.060], 0.020, 0.6],        # set down
                [[0.0, 0.002, -0.722], 0.020, 0.5],        # brake, set down
                [[0.0, 0.004, 0.092], 0.014, 0.7]],        # buffer pad
    "oil_segs": [[[-0.024, 0.020, -0.140], [-0.024, 0.020, -0.024],
                  0.009]],
    "oil_runs": [[[-0.0238, 0.010, -0.070], [-1, 0, 0], 0.040]],
    "oil": [[[0.0, 0.004, 0.080], 0.014]],
    "rust": [[[0.0, -0.070, -0.222], 0.012], [[0.0, -0.022, -0.440], 0.010],
             [[0.0, -0.034, -0.205], 0.012], [[0.0, -0.031, -0.500], 0.014]],
    "welds_flat": [[[-0.0262, -0.028, -0.2005], [-0.0262, 0.0, -0.2010],
                    [-0.0262, 0.038, -0.2005]],
                   [[-0.006, -0.0312, -0.2145], [0.006, -0.0312, -0.2145]]],
    "cracks": [[[-0.0238, 0.004, -0.150], [-0.0238, -0.004, -0.146],
                [-0.0238, -0.012, -0.149], [-0.0238, -0.020, -0.144]]],
    "grinds": [[[-0.0238, -0.012, -0.152], [-1, 0, 0], 0.011]],
    "touchup": [[[-0.0238, -0.008, -0.150], 0.017]],
    "torque": [[[0.0, 0.0478, -0.140], [0, 1, 0]],
               [[-0.0443, 0.025, -0.350], [-1, 0, 0]],
               [[-0.0443, 0.025, -0.530], [-1, 0, 0]]],
    "wrenched": [[[-0.0443, 0.025, -0.440], [-1, 0, 0]]],
    "stamps": [["SL-7 0221", [-0.0101, 0.0391, -0.300], [0, 0, 1],
                [0.7071, 0.7071, 0], [-0.7071, 0.7071, 0], 0.0011],
               ["P", [-0.0101, 0.0391, -0.255], [0, 0, 1],
                [0.7071, 0.7071, 0], [-0.7071, 0.7071, 0], 0.0011]],
    "stencils": [["SL-7", [-0.0260, -0.004, -0.122], [0, 0, 1], [0, 1, 0],
                  [-1, 0, 0], 0.0016],
                 ["HOT", [-0.0084, 0.0405, -0.2125], [1, 0, 0], [0, 0, -1],
                  [0, 1, 0], 0.0014]],
    "tallies": [[[-0.0183, -0.040, -0.248], [0, 0, 1], [0, 1, 0],
                 [-1, 0, 0]]],
    "scratch_zones": [
        [[-0.0238, -0.020, 0.040], [-1, 0, 0], [0, 0, 1], [0, 1, 0], 0.020,
         5, [1.0, 0.2]],
        [[-0.0121, 0.0129, -0.450], [-0.7071, -0.7071, 0], [0, 0, 1],
         [0.7071, -0.7071, 0], 0.12, 9, [1.0, 0.02]],
        [[0.0, 0.0465, -0.060], [0, 1, 0], [0, 0, 1], [1, 0, 0], 0.050, 6,
         [1.0, 0.1]]],
    "lathe": [{"parts": ["handle"], "c": [-0.0145, 0.020, 0.0]},
              {"parts": ["buffer", "buffer_flange"], "c": [0.0, 0.004,
                                                           0.0]}],
    "eps_bites": [-0.350, -0.440, -0.530],
    "grip": {"top": [0.0, -0.034, 0.004], "rake": 16},
}


# =========================================================== SWITCHBACK

def refine_switchback():
    E = []
    # a replacement rear plate on the buffer: square, four bolts that do
    # not match -- the original was round
    E.append(box("rear_plate", -0.016, 0.016, -0.006, 0.012, 0.0635,
                 0.0675, "patch", bevel=0.0008))
    for k, (x, y) in enumerate(((-0.011, -0.002), (0.011, -0.002),
                                (-0.011, 0.008), (0.011, 0.008))):
        E.append(hexhead("rear_bolt%d" % k, (x, y, 0.0675), "z", 1, 0.0022,
                         0.0015, part="rear_bolts"))
    # a deflector bent from strip and welded on behind the open port, so
    # the cases the left-side port throws do not come back at the eye
    E.append(hull("deflector", [(-0.0262, 0.006, -0.050),
                                (-0.0262, 0.034, -0.050),
                                (-0.0262, 0.006, -0.041),
                                (-0.0262, 0.034, -0.041),
                                (-0.0335, 0.008, -0.046),
                                (-0.0335, 0.032, -0.046),
                                (-0.0345, 0.008, -0.043),
                                (-0.0345, 0.032, -0.043)], "painted"))
    E.append(weld("weld_deflector", [(-0.0270, 0.006, -0.0505),
                                     (-0.0272, 0.020, -0.0508),
                                     (-0.0270, 0.034, -0.0505)]))
    # the fire selector over the grip: it is an automatic, so it has one
    E.append(prism("selector_hub", ngon(0.0055, 8, -0.004, 0.000), "x",
                   -0.0300, -0.0262, "bare", part="selector"))
    E.append(box("selector_lever", -0.0315, -0.0290, -0.0025, 0.0025,
                 -0.004, 0.014, "bare", part="selector", bevel=0.0006))
    return E, {}


SPEC_SWITCHBACK = {
    "bore": [0.0, 0.020], "ends": [-0.420, 0.068], "bottom_y": -0.030,
    "trim": 0.28, "grime": 0.26, "seed": 4188,
    "heat": [
        {"a": [0, 0.020, -0.240], "b": [0, 0.020, -0.196], "r": 0.012,
         "fall": 0.020, "w": 1.0, "burn": True},
        {"a": [0, 0.020, -0.392], "b": [0, 0.020, -0.212], "r": 0.020,
         "fall": 0.012, "w": 0.85},
        {"a": [0, 0.020, -0.420], "b": [0, 0.020, -0.400], "r": 0.014,
         "fall": 0.012, "w": 1.0},
    ],
    "soot": [[[0, 0.020, -0.422], [0, 0.020, -0.400], 0.026, 0.9],
             [[-0.027, 0.020, -0.150], [-0.027, 0.020, -0.050], 0.013, 0.7],
             [[0, 0.020, -0.392], [0, 0.020, -0.330], 0.024, 0.5],
             [[-0.030, 0.020, -0.050], [-0.034, 0.020, -0.044], 0.012,
              0.6]],
    "contact": [[[0.0, 0.057, -0.090], 0.032, 0.8],        # carry handle
                [[-0.040, 0.021, -0.102], 0.008, 0.9],     # bolt lug
                [[-0.072, -0.006, -0.020], 0.010, 0.7],    # core cap
                [[0.0, -0.148, -0.130], 0.016, 0.6],       # magazine base
                [[-0.031, 0.0, 0.010], 0.008, 0.9],        # selector
                [[0.0, -0.030, 0.050], 0.020, 0.6]],       # set down
    "oil_segs": [[[-0.026, 0.020, -0.150], [-0.026, 0.020, -0.050],
                  0.009]],
    "oil_runs": [[[-0.0268, 0.008, -0.100], [-1, 0, 0], 0.035]],
    "rust": [[[0.0, -0.044, -0.112], 0.012], [[0.0, 0.0, -0.392], 0.010],
             [[0.0, -0.030, -0.030], 0.012]],
    "welds_flat": [[[-0.020, 0.002, -0.2045], [-0.0245, 0.020, -0.2045],
                    [-0.020, 0.038, -0.2045]],
                   [[-0.0146, -0.040, -0.1415], [-0.0146, -0.028,
                                                 -0.1415]]],
    "grinds": [[[-0.0268, 0.000, 0.030], [-1, 0, 0], 0.010]],
    "touchup": [[[-0.0268, 0.004, 0.030], 0.018]],
    "torque": [[[-0.017, 0.0398, 0.006], [0, 1, 0]],
               [[0.011, -0.002, 0.069], [0, 0, 1]]],
    "wrenched": [[[-0.017, 0.0398, 0.044], [0, 1, 0]]],
    "stamps": [["SB-4 1188", [-0.0198, 0.0388, 0.046], [1, 0, 0],
                [0, 0, -1], [0, 1, 0], 0.0011]],
    "stencils": [["SB-4", [-0.0268, 0.003, -0.142], [0, 0, 1], [0, 1, 0],
                  [-1, 0, 0], 0.0016]],
    "tallies": [[[-0.0268, -0.018, 0.008], [0, 0, 1], [0, 1, 0],
                 [-1, 0, 0]]],
    "scratch_zones": [
        [[-0.0268, -0.018, 0.040], [-1, 0, 0], [0, 0, 1], [0, 1, 0], 0.020,
         5, [1.0, 0.25]],
        [[0.0, 0.057, -0.090], [0, 1, 0], [0, 0, 1], [1, 0, 0], 0.060, 7,
         [1.0, 0.1]],
        [[-0.0125, -0.090, -0.112], [-1, 0, 0], [0, 1, 0], [0, 0, 1],
         0.025, 6, [1.0, 0.3]]],
    "lathe": [],
    "eps_bites": [],
    "grip": {"top": [0.0, -0.030, 0.012], "rake": 14},
}


# =========================================================== MASS DRIVER

def refine_driver():
    E = []
    # the rear plate and the hand-crank socket: with the core out, the
    # rotor is spun up (or run down) by hand through the back
    E.append(box("rear_plate", -0.020, 0.020, -0.006, 0.008, 0.0795,
                 0.0835, "bare", bevel=0.0008))
    for k, x in enumerate((-0.016, 0.016)):
        E.append(hexhead("rear_bolt%d" % k, (x, 0.001, 0.0835), "z", 1,
                         0.0020, 0.0014, part="rear_bolts"))
    E.append(prism("crank_socket", ngon(0.0062, 6, 0.0, 0.001), "z",
                   0.0835, 0.0880, "bare", part="crank"))
    E.append(cyl("crank_hole", 0.0030, 6, 0.0, 0.001, 0.0880, 0.0886,
                 "rubber", part="crank"))
    # the pickup lead: the accumulator charges the rotor's field through
    # a terminal on the cage's front ring
    E.append(box("pickup_term", -0.054, -0.040, -0.038, -0.024, -0.247,
                 -0.242, "epsilon", bevel=0.0008))
    E.append(sweep("pickup_lead", [(-0.012, -0.056, -0.150),
                                   (-0.034, -0.050, -0.175),
                                   (-0.050, -0.034, -0.220),
                                   (-0.047, -0.031, -0.243)], 0.0026, 6,
                   "cable"))
    return E, {}


SPEC_DRIVER = {
    "bore": [0.0, 0.0], "ends": [-0.620, 0.088], "bottom_y": -0.042,
    "trim": 0.34, "grime": 0.16, "seed": 9093,
    "heat": [
        {"a": [0, 0, -0.620], "b": [0, 0, -0.500], "r": 0.030,
         "fall": 0.020, "w": 0.8},
        {"a": [0, 0, -0.232], "b": [0, 0, -0.068], "r": 0.020,
         "fall": 0.010, "w": 0.5},
    ] + [{"a": [-0.034, 0.017, z], "b": [0.034, 0.017, z], "r": 0.012,
          "fall": 0.010, "w": 0.6} for z in (-0.300, -0.460, -0.600)],
    "soot": [[[0, 0, -0.625], [0, 0, -0.580], 0.030, 0.6]],
    "contact": [[[-0.030, 0.044, 0.060], 0.020, 0.5],      # hand rest
                [[0.0, 0.064, -0.064], 0.016, 0.6],        # cage ring, held
                [[0.0, -0.069, 0.068], 0.010, 0.8],        # echo cap
                [[0.0, 0.001, 0.088], 0.008, 0.9],         # crank socket
                [[0.0, -0.042, 0.075], 0.020, 0.6]],       # set down
    "oil": [[[0.0, 0.0, -0.068], 0.022], [[0.0, 0.0, -0.232], 0.022]],
    "rust": [[[0.0, -0.030, -0.450], 0.015], [[-0.026, -0.012, -0.400],
                                             0.012],
             [[0.026, -0.012, -0.520], 0.012]],
    "welds_flat": [[[-0.010, -0.0302, -0.2365], [0.010, -0.0302, -0.2365]],
                   [[-0.0332, -0.012, -0.420], [-0.0332, 0.012, -0.420]]],
    "cracks": [[[-0.0348, 0.030, 0.040], [-0.0348, 0.022, 0.044],
                [-0.0348, 0.016, 0.041], [-0.0348, 0.008, 0.046]]],
    "grinds": [[[-0.0348, 0.020, 0.043], [-1, 0, 0], 0.011]],
    "touchup": [[[-0.0348, 0.020, 0.043], 0.018]],
    "torque": [[[-0.0458, 0.0458, -0.0626], [0, 0, 1]],
               [[0.016, 0.001, 0.085], [0, 0, 1]]],
    "wrenched": [[[-0.0458, -0.0458, -0.0626], [0, 0, 1]]],
    "stamps": [["MD-2 0093", [-0.0200, 0.0122, -0.330], [0, 0, 1],
                [1, 0, 0], [0, 1, 0], 0.0011]],
    "stencils": [["MD-2", [-0.0370, 0.024, -0.042], [0, 0, 1], [0, 1, 0],
                  [-1, 0, 0], 0.0018],
                 ["ROTOR", [-0.0370, 0.008, -0.042], [0, 0, 1], [0, 1, 0],
                  [-1, 0, 0], 0.0014]],
    "tallies": [[[-0.0348, -0.020, 0.040], [0, 0, 1], [0, 1, 0],
                 [-1, 0, 0]]],
    "scratch_zones": [
        [[-0.0348, -0.030, 0.060], [-1, 0, 0], [0, 0, 1], [0, 1, 0], 0.020,
         5, [1.0, 0.25]],
        [[-0.033, 0.0, -0.450], [-1, 0, 0], [0, 0, 1], [0, 1, 0], 0.12, 9,
         [1.0, 0.02]]],
    "lathe": [{"parts": ["coils"], "c": [0.0, 0.0, 0.0]}],
    "index_stripes": [["coils", [0.0, 0.0], 0.40, 0.10]],
    "eps_bites": [],
    "grip": {"top": [0.0, -0.042, 0.050], "rake": 14},
}


MODELS = {
    "sightline": {"form": wf.sightline_a, "refine": refine_sightline,
                  "spec": SPEC_SIGHTLINE, "root": "Sightline",
                  "label": "Sightline (A, Accelerator)",
                  "closes": {
                      "close_breech": ((-0.17, 0.08, 0.02),
                                       (-0.02, 0.02, -0.12), 30.0),
                      "close_stators": ((-0.15, 0.10, -0.32),
                                        (-0.01, 0.03, -0.45), 32.0),
                      "close_rear": ((-0.09, 0.10, 0.20),
                                     (0.0, 0.03, 0.02), 30.0),
                  }},
    "switchback": {"form": wf.switchback_a, "refine": refine_switchback,
                   "spec": SPEC_SWITCHBACK, "root": "Switchback",
                   "label": "Switchback (A, Jacketed)",
                   "closes": {
                       "close_port": ((-0.16, 0.07, -0.02),
                                      (-0.02, 0.015, -0.10), 30.0),
                       "close_jacket": ((-0.13, 0.08, -0.22),
                                        (0.0, 0.02, -0.31), 32.0),
                       "close_rear": ((-0.09, 0.10, 0.20),
                                      (0.0, 0.02, 0.0), 30.0),
                   }},
    # the form's balance weights reached r 0.0587 under cage bars whose
    # inner face is at r 0.0565 (they cut through the bars at rest and
    # would clip spinning): lower, and set between the bars at rest
    "driver": {"form": lambda: wf.driver_a(weight_top=0.0545,
                                           weight_phase=0),
               "refine": refine_driver,
               "spec": SPEC_DRIVER, "root": "MassDriver",
               "label": "Mass Driver (A, Rotor)",
               "closes": {
                   "close_rotor": ((-0.20, 0.10, -0.06),
                                   (0.0, 0.0, -0.15), 32.0),
                   "close_rails": ((-0.15, 0.08, -0.36),
                                   (0.0, 0.0, -0.48), 32.0),
                   "close_rear": ((-0.10, 0.12, 0.24),
                                  (0.0, 0.02, 0.03), 30.0),
               }},
}


# ============================================================ assembly

def assemble_objects(key, dress_clay=False):
    M = MODELS[key]
    common.reset_scene()
    fs.PARTS.clear()
    static, moving, meta = M["form"]()
    add_static, add_moving = M["refine"]()
    static = static + add_static
    for name, pieces in add_moving.items():
        moving[name][0].extend(pieces)
    pieces = static + [o for parts, _ in moving.values() for o in parts]
    if dress_clay:
        wf.dress(pieces)
    else:
        fs._shade(pieces)
        for o in pieces:
            fs._id_material(o)
    body = common.join(static, "Body")
    nodes = {}
    for name, (parts, pivot) in moving.items():
        obj = common.join(parts, name)
        fs._pivot(obj, pivot)
        nodes[name] = (obj, pivot)
    muzzle = wf.node("Muzzle", meta["muzzle"])
    return body, nodes, muzzle, meta


def _material(maps_dir, name):
    mat = fs._final_material(maps_dir)
    mat.name = name
    mat.use_backface_culling = True
    return mat


def export(objs, muzzle, maps_dir, path, root_name, mat_name):
    fs.triangulate(objs)
    mat = _material(maps_dir, mat_name)
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
    root = bpy.data.objects.new(root_name, None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs + [muzzle]:
        o.parent = root
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs + [muzzle, root]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                              use_selection=True, export_apply=False,
                              export_texcoords=True, export_normals=True,
                              export_tangents=True,
                              export_materials="EXPORT",
                              export_image_format="AUTO", export_yup=True)


def look(key, objs, maps_dir, out):
    """The painted maps on the model in Cycles: the player's eye, the
    elevation, a three-quarter, and this weapon's close looks."""
    mat = _material(maps_dir, "look")
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
    scene, cam = wf._scene_setup()
    scene.cycles.samples = 64
    views = {
        "look_eye": ("PERSP", fs._rig_matrix().inverted(), 75.0,
                     (1600, 900)),
        "look_side": ("ORTHO", Matrix.Translation(Vector(
            (-0.9, wf.SIDE_CENTRE[1], wf.SIDE_CENTRE[0])))
            @ Matrix.Rotation(math.radians(-90), 4, "Y"), wf.SIDE_ORTHO,
            (1600, 760)),
        "look_three_q": ("PERSP", wf._look_at((-0.34, 0.22, 0.26),
                                              (0.0, -0.01, -0.22)), 34.0,
                         (1600, 900)),
    }
    for name, (eye, target, fov) in MODELS[key]["closes"].items():
        views["look_" + name] = ("PERSP", wf._look_at(eye, target), fov,
                                 (1280, 900))
    os.makedirs(out, exist_ok=True)
    for name, (kind, m, lens, res) in views.items():
        scene.render.resolution_x, scene.render.resolution_y = res
        cam.data.type = kind
        if kind == "ORTHO":
            cam.data.ortho_scale = lens
        else:
            cam.data.sensor_fit = "VERTICAL"
            cam.data.angle_y = math.radians(lens)
        cam.data.clip_start = 0.005
        cam.matrix_world = wf.G2B @ m
        scene.render.filepath = os.path.join(out, name + ".png")
        bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    mode, key, out = argv[0], argv[1], os.path.abspath(argv[2])
    if mode not in ("preview", "bake", "assemble", "look") or \
            key not in MODELS:
        raise SystemExit("usage: -- preview|bake|assemble|look "
                         "sightline|switchback|driver OUT")
    M = MODELS[key]
    os.makedirs(out, exist_ok=True)
    body, nodes, muzzle, meta = assemble_objects(key, mode == "preview")
    objs = [body] + [o for o, _ in nodes.values()]
    tris = fs.triangles(objs)
    if mode == "preview":
        common.log("%s: %d tris (clay preview)" % (key, tris))
        wf.render_views(os.path.join(out, "clay"), M["label"])
        return
    fs.unwrap(objs)
    # size the atlas so the density matches the approved Foundry's
    fs.ATLAS = 1024
    density, fill = fs.texel_density(objs)
    # the smallest power-of-two atlas that holds the Foundry's density
    while density < 0.95 * TARGET_DENSITY and fs.ATLAS < 4096:
        fs.ATLAS *= 2
        density, fill = fs.texel_density(objs)
    fp = fs.uv_fingerprint(objs)
    common.log("%s: %d tris, atlas %d, %.0f texels/m, fill %.0f%%, uv %s"
               % (key, tris, fs.ATLAS, density, 100 * fill, fp))
    bake_dir = os.path.join(out, "bake")
    if mode == "bake":
        fs.bake_all(objs, bake_dir)
        with open(os.path.join(bake_dir, "bake.json"), "w") as fh:
            json.dump({"weapon": key, "uv": fp, "atlas": fs.ATLAS,
                       "classes": fs.CLASSES, "parts": dict(fs.PARTS),
                       "triangles": tris,
                       "texels_per_metre": round(density, 1),
                       "spec": M["spec"]}, fh, indent=1, sort_keys=True)
        return
    with open(os.path.join(bake_dir, "bake.json")) as fh:
        baked = json.load(fh)
    if baked["uv"] != fp:
        raise SystemExit("UVs changed since the bake (%s, now %s): bake "
                         "again" % (baked["uv"], fp))
    maps = os.path.join(out, "maps")
    if mode == "look":
        look(key, objs, maps, os.path.join(out, "look"))
        return
    export(objs, muzzle, maps, os.path.join(out, key + ".glb"), M["root"],
           key + "_dev")
    textures = sorted(f for f in os.listdir(maps) if f.endswith(".png")
                      and f != "height.png")
    record = {
        "status": "DEVELOPMENT MODEL (Arty, 2026-10-13): an approved "
                  "concept direction developed toward the Foundry's "
                  "fidelity. Not registered, not merged, not shipping.",
        "weapon": key,
        "label": M["label"],
        "metrics": {
            "triangles": tris,
            "materials": 1,
            "textures": textures,
            "texture_size": fs.ATLAS,
            "texels_per_metre": round(density, 1),
            "atlas_fill": round(fill, 3),
            "meshes": len(objs),
            "draw_calls_expected": len(objs),
            "note": "Triangle counts are provisional (the owner, "
                    "2026-10-13); measured in the game separately.",
        },
        "nodes": {n: {"pivot": list(p)} for n, (_, p) in nodes.items()},
        "muzzle": list(meta["muzzle"]),
        "sight_lines_y": meta.get("sights", []),
        "frame": "Godot viewmodel space (RangeRig model origin), -Z forward",
    }
    with open(os.path.join(out, key + ".json"), "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")
    common.log("wrote %s" % os.path.join(out, key + ".glb"))


if __name__ == "__main__":
    main()
