"""Batch 068 -- five weapon viewmodels for the five-weapon range. CANDIDATE.
(Arty, 2026-10-10.)

    .tools/blender/blender -b --python tools/blender/build_weapon_viewmodels.py

Writes `assets/models/weapons_five/<weapon>.glb` and `manifest.json`.

WHAT THEY ARE. Five low-to-medium-complexity silhouettes, one per weapon
in the owner's lineup, built to be told apart at a glance from the
player's eye with the reticle clear:

    foundry      a heavy, short hand cannon: fat octagonal barrel, block
                 brake with side ports, a big cylinder
    sightline    a long, slender scout: thin barrel, a scope tube, a
                 skeleton stock stub
    switchback   a compact carbine: boxy receiver, vented shroud, a
                 magazine forward of the grip, a side bolt, a stock stub
    bulkhead     a broad, short scattergun: two barrels side by side under
                 one wide shroud, a pump forend
    massdriver   a charged kinetic driver: open twin rails, a slug chamber,
                 three accumulator rings that MOVE with the charge

WHAT THEY ARE NOT. Not Production's runtime: no script, spring, timing or
input lives here. The recoil signatures in the manifest are proposals in
Prod's own spring format (`hand_cannon.gd` SPRINGS: jump, kick, freq,
zeta), for Prod to adopt or tune; Foundry's are his mode H numbers
unchanged. Not a loot or inventory system; not in the content pack.

THE FRAME. Every node is in the Viewmodel's own space: origin = the
`Viewmodel` node, Godot -Z forward, +Y up (authored here Z-up, +Y forward;
the exporter flips). Foundry's `muzzle` sits exactly at Prod's `MUZZLE`
(0, 0.03, -0.47) so it drops in where his placeholder revolver is.

NAMED NODES (what a runtime can fetch): `body` (static mesh), `muzzle`
(and `muzzle_l`/`muzzle_r`, `brake_port_l`/`brake_port_r`, `ejection`,
`accumulator` where they exist) as Empties, and each moving part as its
own mesh whose ORIGIN IS ITS PIVOT, so Prod rotates or slides it with
one transform.

Colours: neutral metals and polymers only. Blue, green, orange and red
are the game's signals and stay off the guns.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import brushkit as bk  # noqa: E402
import common  # noqa: E402

OUT = "weapons_five"
CATEGORY = "hero"

#: Neutral metals and polymers (value-separated; no signal hues).
SWATCH = {
    "gunmetal": ("#2c2f33", 0.55),
    "steel": ("#555a60", 0.45),
    "edge": ("#8e949a", 0.40),
    "polymer": ("#1e1f21", 0.85),
    "grip": ("#3b3530", 0.80),
    "lens": ("#15171a", 0.20),
}


def _mat(key):
    name = "wf_" + key
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    hexc, rough = SWATCH[key]
    return common.make_material(name, hexc, roughness=rough)


def g2b(p):
    """Godot viewmodel space -> Blender authoring space."""
    x, y, z = p
    return (x, -z, y)


def box(name, size, at, mat, pitch=0.0, yaw=0.0):
    """A box. `size` = (width x, height y, length z) in Godot terms.
    `pitch` > 0 rakes it: top toward the muzzle, bottom back, like a
    pistol grip (Godot rotation_degrees.x = -pitch, as Prod's -16 grip)."""
    w, h, d = size
    obj = bk.block(name, (w, d, h), at=g2b(at))
    if pitch:
        # Godot's X is Blender's X; a Godot rotation about it is the same
        # rotation here. -pitch puts the top forward (+Y here, -Z there).
        bk.spin(obj, "x", -pitch)
    if yaw:
        bk.spin(obj, "z", yaw)
    return common.assign(obj, _mat(mat))


def rod(name, radius, length, at, mat, sides=8, top=None):
    """A prism along the line of fire (Godot Z). `top` tapers the FRONT."""
    obj = bk.prism(name, radius, length, sides, at=(0, 0, 0),
                   top_radius=top)
    bk.spin(obj, "x", -90)          # +Z (top) -> +Y forward
    for v in obj.data.vertices:
        v.co += Vector(g2b(at))
    obj.data.update()
    return common.assign(obj, _mat(mat))


def ring(name, outer, inner, length, at, mat, sides=8):
    obj = bk.tube(name, outer, inner, length, sides, at=(0, 0, 0))
    bk.spin(obj, "x", -90)
    for v in obj.data.vertices:
        v.co += Vector(g2b(at))
    obj.data.update()
    obj.pop(bk.ANNULUS_KEY, None)    # no collision is built from a viewmodel
    return common.assign(obj, _mat(mat))


def node(name, at):
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_size = 0.02
    empty.location = Vector(g2b(at))
    bpy.context.scene.collection.objects.link(empty)
    return empty


def pivot(obj, at):
    """Move a part's origin to its pivot without moving its geometry."""
    p = Vector(g2b(at))
    for v in obj.data.vertices:
        v.co -= p
    obj.data.update()
    obj.location = p
    return obj


def part(name, pieces, at):
    return pivot(common.join(pieces, name), at)


# ---------------------------------------------------------------- the guns

def foundry():
    """Heavy and short. Mass at the front: a fat barrel and a block brake;
    a big cylinder; a hammer that falls. Muzzle = Prod's MUZZLE."""
    body = [
        box("frame", (0.058, 0.088, 0.20), (0, 0.0, -0.09), "gunmetal"),
        box("strap", (0.034, 0.016, 0.20), (0, 0.054, -0.11), "gunmetal"),
        rod("barrel", 0.026, 0.25, (0, 0.03, -0.30), "gunmetal"),
        box("lug", (0.034, 0.03, 0.24), (0, 0.006, -0.30), "steel"),
        box("brake", (0.066, 0.058, 0.07), (0, 0.03, -0.435), "steel"),
        box("brake_slot_l", (0.068, 0.012, 0.012), (0, 0.042, -0.425),
            "polymer"),
        box("brake_slot_r", (0.068, 0.012, 0.012), (0, 0.018, -0.425),
            "polymer"),
        box("sight", (0.008, 0.02, 0.016), (0, 0.068, -0.40), "edge"),
        box("rear_sight", (0.03, 0.012, 0.012), (0, 0.066, -0.015), "edge"),
        box("grip", (0.05, 0.15, 0.065), (0, -0.09, 0.05), "grip",
            pitch=16),
        box("guard", (0.02, 0.032, 0.06), (0, -0.045, -0.02), "steel"),
        box("trigger", (0.008, 0.026, 0.008), (0, -0.044, -0.025), "edge"),
    ]
    cyl = part("cylinder", [
        rod("cyl_drum", 0.046, 0.08, (0, 0.018, -0.06), "steel", sides=8),
        box("cyl_flute", (0.094, 0.01, 0.06), (0, 0.018, -0.06), "polymer"),
    ], (0, 0.018, -0.06))
    hammer = part("hammer", [
        box("hammer_spur", (0.016, 0.036, 0.024), (0, 0.062, 0.022),
            "steel", pitch=-24),
    ], (0, 0.044, 0.015))
    empties = [node("muzzle", (0, 0.03, -0.47)),
               node("brake_port_l", (-0.034, 0.03, -0.43)),
               node("brake_port_r", (0.034, 0.03, -0.43))]
    return body, [cyl, hammer], empties, {
        "cylinder": {"pivot": [0, 0.018, -0.06], "motion": "roll about the "
                     "line of fire, -60 deg per shot (six chambers), eased "
                     "in 90 ms after the shot", "axis": "z"},
        "hammer": {"pivot": [0, 0.044, 0.015], "motion": "rest = cocked; "
                   "falls +38 deg about x on the shot (one frame), re-cocks "
                   "over the cadence's last 120 ms (with Prod's mech_ready)",
                   "axis": "x"}}


def sightline():
    """Long and slender. A thin line ahead of the hand, a scope above it:
    the only gun with a long horizontal read."""
    body = [
        box("receiver", (0.04, 0.06, 0.30), (0, 0.0, -0.06), "gunmetal"),
        rod("barrel", 0.011, 0.52, (0, 0.012, -0.47), "steel", sides=6),
        rod("muzzle_tip", 0.015, 0.04, (0, 0.012, -0.73), "gunmetal",
            sides=6),
        box("forend", (0.034, 0.03, 0.22), (0, -0.012, -0.30), "polymer"),
        rod("scope", 0.017, 0.24, (0, 0.062, -0.08), "polymer"),
        rod("scope_bell", 0.024, 0.05, (0, 0.062, -0.225), "polymer",
            top=0.026),
        rod("scope_eye", 0.02, 0.03, (0, 0.062, 0.05), "polymer"),
        box("lens", (0.03, 0.03, 0.004), (0, 0.062, -0.252), "lens"),
        box("mount_a", (0.012, 0.03, 0.02), (0, 0.038, -0.14), "steel"),
        box("mount_b", (0.012, 0.03, 0.02), (0, 0.038, -0.01), "steel"),
        box("grip", (0.036, 0.12, 0.05), (0, -0.085, 0.06), "grip",
            pitch=22),
        box("stock", (0.022, 0.02, 0.16), (0, -0.02, 0.17), "steel"),
        box("stock_lo", (0.018, 0.016, 0.14), (0, -0.075, 0.175), "steel",
            pitch=-14),
        box("guard", (0.016, 0.026, 0.05), (0, -0.04, 0.01), "steel"),
    ]
    bolt = part("bolt_handle", [
        box("bolt_arm", (0.05, 0.01, 0.012), (0.04, 0.015, 0.03), "edge"),
        box("bolt_knob", (0.018, 0.018, 0.018), (0.066, 0.015, 0.03),
            "steel"),
    ], (0.015, 0.015, 0.03))
    empties = [node("muzzle", (0, 0.012, -0.75)),
               node("ejection", (0.022, 0.02, -0.02))]
    return body, [bolt], empties, {
        "bolt_handle": {"pivot": [0.015, 0.015, 0.03], "motion": "after the "
                        "shot: lift 60 deg about z (80 ms), slide back "
                        "0.05 m (90 ms), forward and down (170 ms). A visible "
                        "re-chamber is the cadence's tell", "axis": "z then "
                        "slide +z"}}


def switchback():
    """Compact and continuous: a boxy receiver, a stubby vented shroud,
    a magazine forward of the grip. Square, not long, not wide."""
    body = [
        box("receiver", (0.056, 0.085, 0.27), (0, 0.0, -0.10), "polymer"),
        box("top_rail", (0.03, 0.012, 0.25), (0, 0.048, -0.11), "gunmetal"),
        box("shroud", (0.044, 0.05, 0.13), (0, 0.006, -0.30), "gunmetal"),
        rod("barrel", 0.011, 0.07, (0, 0.006, -0.395), "steel", sides=6),
        rod("comp", 0.016, 0.03, (0, 0.006, -0.425), "steel", sides=6),
        box("vent_1", (0.046, 0.034, 0.012), (0, 0.006, -0.26), "steel"),
        box("vent_2", (0.046, 0.034, 0.012), (0, 0.006, -0.29), "steel"),
        box("vent_3", (0.046, 0.034, 0.012), (0, 0.006, -0.32), "steel"),
        box("vent_4", (0.046, 0.034, 0.012), (0, 0.006, -0.35), "steel"),
        box("mag", (0.03, 0.13, 0.05), (0, -0.095, -0.15), "gunmetal",
            pitch=-8),
        box("grip", (0.04, 0.12, 0.05), (0, -0.085, 0.01), "grip",
            pitch=14),
        box("sight", (0.02, 0.026, 0.03), (0, 0.068, -0.03), "steel"),
        box("guard", (0.016, 0.022, 0.06), (0, -0.05, -0.05), "steel"),
        # The brief's "medium stock": a short skeleton stock stub.
        box("stock_bar", (0.024, 0.026, 0.13), (0, -0.005, 0.085),
            "gunmetal"),
        box("stock_butt", (0.034, 0.1, 0.022), (0, -0.035, 0.155),
            "polymer"),
    ]
    bolt = part("bolt", [
        box("bolt_handle", (0.034, 0.014, 0.022), (0.042, 0.018, -0.12),
            "edge"),
        box("bolt_face", (0.006, 0.03, 0.07), (0.029, 0.018, -0.10),
            "steel"),
    ], (0.03, 0.018, -0.12))
    empties = [node("muzzle", (0, 0.006, -0.445)),
               node("ejection", (0.03, 0.02, -0.08))]
    return body, [bolt], empties, {
        "bolt": {"pivot": [0.03, 0.018, -0.12], "motion": "slides +0.035 m "
                 "on z (back) and returns inside each shot's interval (a "
                 "saw-tooth at the fire rate); locks back after the last "
                 "round if there is a magazine", "axis": "slide +z"}}


def bulkhead():
    """Broad and short: wider than it is long-looking, two bores under
    one flat shroud, a pump you can see travel."""
    body = [
        box("receiver", (0.11, 0.07, 0.17), (0, 0.0, -0.07), "gunmetal"),
        box("cheek_l", (0.02, 0.05, 0.12), (-0.06, 0.005, -0.06), "steel"),
        box("cheek_r", (0.02, 0.05, 0.12), (0.06, 0.005, -0.06), "steel"),
        rod("barrel_l", 0.024, 0.2, (-0.031, 0.02, -0.255), "steel"),
        rod("barrel_r", 0.024, 0.2, (0.031, 0.02, -0.255), "steel"),
        box("shroud", (0.13, 0.012, 0.21), (0, 0.05, -0.26), "gunmetal"),
        box("shroud_side_l", (0.008, 0.034, 0.21), (-0.066, 0.034, -0.26),
            "gunmetal"),
        box("shroud_side_r", (0.008, 0.034, 0.21), (0.066, 0.034, -0.26),
            "gunmetal"),
        box("choke", (0.136, 0.064, 0.034), (0, 0.022, -0.37), "steel"),
        box("bead", (0.01, 0.012, 0.01), (0, 0.062, -0.365), "edge"),
        box("grip", (0.05, 0.13, 0.065), (0, -0.085, 0.04), "grip",
            pitch=26),
        box("guard", (0.02, 0.03, 0.06), (0, -0.05, -0.03), "steel"),
    ]
    pump = part("pump", [
        box("pump_body", (0.12, 0.05, 0.1), (0, -0.026, -0.25),
            "polymer"),
        box("pump_rib_1", (0.124, 0.008, 0.012), (0, -0.026, -0.22),
            "steel"),
        box("pump_rib_2", (0.124, 0.008, 0.012), (0, -0.026, -0.28),
            "steel"),
    ], (0, -0.026, -0.25))
    empties = [node("muzzle", (0, 0.02, -0.39)),
               node("muzzle_l", (-0.031, 0.02, -0.39)),
               node("muzzle_r", (0.031, 0.02, -0.39)),
               node("ejection", (0.06, 0.02, -0.08))]
    return body, [pump], empties, {
        "pump": {"pivot": [0, -0.026, -0.25], "motion": "after the recoil "
                 "peak: back +0.07 m on z (110 ms), forward (130 ms); a "
                 "hull drops from `ejection` at the back stroke",
                 "axis": "slide +z"}}


def massdriver():
    """An open frame you can see through: twin rails, a slug chamber, and
    three accumulator rings that slide forward and spin as it charges."""
    body = [
        box("housing", (0.07, 0.09, 0.18), (0, -0.004, -0.02), "gunmetal"),
        box("rail_top", (0.03, 0.016, 0.42), (0, 0.044, -0.30), "steel"),
        box("rail_bot", (0.03, 0.016, 0.42), (0, -0.024, -0.30), "steel"),
        box("rail_tie_a", (0.034, 0.084, 0.014), (0, 0.01, -0.14),
            "gunmetal"),
        box("rail_tie_b", (0.034, 0.084, 0.014), (0, 0.01, -0.50),
            "gunmetal"),
        box("chamber", (0.05, 0.05, 0.06), (0, 0.01, -0.12), "polymer"),
        box("cell_l", (0.02, 0.05, 0.14), (-0.045, -0.004, -0.02), "steel"),
        box("cell_r", (0.02, 0.05, 0.14), (0.045, -0.004, -0.02), "steel"),
        box("grip", (0.046, 0.13, 0.06), (0, -0.1, 0.06), "grip", pitch=14),
        box("guard", (0.018, 0.028, 0.06), (0, -0.06, -0.0), "steel"),
    ]
    rings = []
    rest_z = (-0.22, -0.30, -0.38)
    for i, z in enumerate(rest_z):
        rings.append(part("accumulator_ring_%d" % (i + 1), [
            ring("ring_%d_mesh" % (i + 1), 0.05, 0.036, 0.022,
                 (0, 0.01, z), "edge")], (0, 0.01, z)))
    empties = [node("muzzle", (0, 0.01, -0.52)),
               node("accumulator", (0, 0.01, -0.30))]
    return body, rings, empties, {
        "accumulator_ring_N": {"pivot": "each ring's centre on the bore, "
                               "z = -0.22 / -0.30 / -0.38", "motion":
                               "charging 0->100 %: each ring slides 0.025 m "
                               "toward the muzzle (ring 3 first, staggered "
                               "1/3) and spins about z, 0 -> 720 deg/s; "
                               "release: all snap back to rest in 60 ms "
                               "with a 6 deg counter-spin overshoot",
                               "axis": "slide -z, roll z"}}


GUNS = {"foundry": foundry, "sightline": sightline, "switchback": switchback,
        "bulkhead": bulkhead, "massdriver": massdriver}

#: Proposed viewmodel rest per weapon (camera-local), so a long gun does
#: not push its muzzle to the middle of the screen and a broad one does not
#: cover the reticle. Foundry = Prod's REST_POS / REST_ROT unchanged.
REST = {
    "foundry": ([0.34, -0.30, -0.62], [0, 8, -4]),
    "sightline": ([0.30, -0.27, -0.42], [0, 4, -2]),
    "switchback": ([0.32, -0.29, -0.56], [0, 6, -3]),
    "bulkhead": ([0.36, -0.32, -0.58], [0, 9, -5]),
    "massdriver": ([0.34, -0.31, -0.55], [0, 7, -3]),
}

#: Recoil signatures in Prod's spring format (hand_cannon.gd SPRINGS):
#: `jump` = displacement on the shot's frame, `kick` = velocity added,
#: `freq` Hz, `zeta` damping. Foundry is mode H exactly. The others are
#: PROPOSALS shaped to read differently, not tuned by play.
SPRINGS = {
    "foundry": {
        "back": [0.19, 4.5, 6.0, 0.45], "lift": [0.05, 1.6, 6.0, 0.45],
        "pitch": [16.0, 620.0, 5.5, 0.42], "roll": [2.5, 40.0, 6.5, 0.5],
        "cam_lift": [0.03, 0.5, 8.0, 0.6], "cam_roll": [0.9, 25.0, 8.0, 0.6],
        "fov": [3.0, 0.0, 7.0, 0.7]},
    "sightline": {
        "back": [0.07, 1.2, 10.0, 0.75], "lift": [0.01, 0.2, 10.0, 0.75],
        "pitch": [4.0, 90.0, 9.0, 0.7], "roll": [0.4, 4.0, 10.0, 0.8],
        "cam_lift": [0.008, 0.1, 12.0, 0.8], "cam_roll": [0.0, 0.0, 10.0, 1.0],
        "fov": [1.2, 0.0, 10.0, 0.8]},
    "switchback": {
        "back": [0.028, 0.5, 14.0, 0.55], "lift": [0.006, 0.12, 14.0, 0.55],
        "pitch": [1.8, 40.0, 12.0, 0.5], "roll": [0.8, 18.0, 13.0, 0.4],
        "cam_lift": [0.004, 0.05, 14.0, 0.7], "cam_roll": [0.25, 6.0, 14.0, 0.6],
        "fov": [0.4, 0.0, 14.0, 0.8]},
    "bulkhead": {
        "back": [0.24, 5.5, 4.5, 0.5], "lift": [0.07, 1.8, 4.5, 0.5],
        "pitch": [12.0, 420.0, 4.2, 0.48], "roll": [4.0, 60.0, 5.0, 0.45],
        "cam_lift": [0.045, 0.7, 6.0, 0.55], "cam_roll": [1.6, 40.0, 6.0, 0.55],
        "fov": [4.5, 0.0, 5.5, 0.65]},
    "massdriver": {
        "back": [0.30, 3.0, 3.6, 0.7], "lift": [0.015, 0.3, 4.0, 0.7],
        "pitch": [5.0, 120.0, 3.8, 0.7], "roll": [0.0, 0.0, 4.0, 1.0],
        "cam_lift": [0.02, 0.2, 5.0, 0.8], "cam_roll": [0.0, 0.0, 5.0, 1.0],
        "fov": [-4.0, 0.0, 4.0, 0.75]},
}

#: What makes each signature ITS OWN, in words.
SIGNATURE = {
    "foundry": "a heavy flip: big muzzle rise and shove, overshoots past "
               "rest and settles (mode H)",
    "sightline": "a crisp straight jolt, little rise, critically damped: "
                 "the scope comes back on the target fast",
    "switchback": "small per-shot buzz, roll alternating, high frequency; "
                  "Prod adds a held-fire climb (proposal: +0.5 deg pitch "
                  "rest offset a shot, capped at 4 deg, recovering at "
                  "10 deg/s on release)",
    "bulkhead": "the biggest shove and roll, slow, a body-blow; the pump "
                "stroke follows the recoil peak",
    "massdriver": "charge: pull in 0.02 m and a tremble growing with charge "
                  "(0 -> 0.3 deg, 22 Hz); release: a long straight push "
                  "back, very little flip, the FOV DIPS (negative) -- a "
                  "punch, not a bang",
}


def simulate(spring, seconds=1.0):
    """Prod's integrator exactly (`hand_cannon.gd` _process/_step): the
    impulse on the shot's frame, then 60 fps, two half steps a frame. Its
    Foundry peak must match what he measured for H (0.196 m, 19.1 deg)."""
    jump, kick, freq, zeta = spring
    x, v = jump, kick
    w = 2 * math.pi * freq
    out = [(0.0, x)]
    dt = 1.0 / 120.0
    for frame in range(1, int(seconds * 60) + 1):
        for _half in range(2):
            a = -w * w * x - 2 * zeta * w * v
            v += a * dt
            x += v * dt
        out.append((frame / 60.0, x))
    return out


def signature(name):
    rows = {}
    for channel, spring in SPRINGS[name].items():
        trace = simulate(spring)
        peak_t, peak = max(trace, key=lambda r: abs(r[1]))
        thresh = max(abs(peak) * 0.03, 1e-6)
        settle = next((t for t, x in reversed(trace) if abs(x) > thresh),
                      0.0)
        under = min(x for _, x in trace) if peak > 0 else \
            max(x for _, x in trace)
        rows[channel] = {"spring": dict(zip(("jump", "kick", "freq", "zeta"),
                                            spring)),
                         "peak": round(peak, 4),
                         "peak_ms": round(peak_t * 1000),
                         "overshoot": round(under, 4),
                         "reset_ms": round(settle * 1000)}
    return rows


def build(name):
    common.reset_scene()
    for key in list(bpy.data.materials.keys()):
        if key.startswith("wf_"):
            bpy.data.materials.remove(bpy.data.materials[key])
    pieces, moving, empties, motion = GUNS[name]()
    body = common.join(pieces, "body")
    entry = common.export_glb(body, "%s/%s.glb" % (OUT, name), CATEGORY,
                              anchor="viewmodel_origin",
                              parts=moving + empties)
    entry["nodes"] = {e.name: [round(c, 4) for c in
                               (e.location.x, e.location.z, -e.location.y)]
                      for e in empties}
    entry["moving_parts"] = motion
    entry["rest"] = {"position": REST[name][0], "rotation_deg": REST[name][1]}
    entry["recoil"] = signature(name)
    entry["recoil_reads_as"] = SIGNATURE[name]
    entry["size_runtime"] = common.runtime_size(entry["size"])
    return entry


def _profile(objects, cell=0.005):
    """The side (Godot z, y) AND top (z, x) silhouettes as one set of
    filled cells: the player's 3/4-rear view sees both."""
    filled = set()
    for obj in objects:
        if getattr(obj.data, "vertices", None) is None:
            continue
        mw = obj.matrix_world
        pts = [mw @ v.co for v in obj.data.vertices]
        for poly in obj.data.polygons:
            for view in ("side", "top"):
                _fill(filled, view, [(-pts[i].y, pts[i].z if view == "side"
                                      else pts[i].x) for i in poly.vertices],
                      cell)
    return filled


def _fill(filled, view, ring, cell):
    for k in range(1, len(ring) - 1):
        tri = (ring[0], ring[k], ring[k + 1])
        xs = [p[0] for p in tri]
        ys = [p[1] for p in tri]
        for cx in range(int(math.floor(min(xs) / cell)),
                        int(math.floor(max(xs) / cell)) + 1):
            for cy in range(int(math.floor(min(ys) / cell)),
                            int(math.floor(max(ys) / cell)) + 1):
                px, py = (cx + 0.5) * cell, (cy + 0.5) * cell
                if _inside(px, py, tri):
                    filled.add((view, cx, cy))


def _inside(px, py, tri):
    (ax, ay), (bx, by), (cx, cy) = tri
    d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
    d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
    d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)


def main():
    made = {}
    profiles = {}
    for name in GUNS:
        made[name] = build(name)
        profiles[name] = _profile(list(bpy.context.scene.objects))
        e = made[name]
        print("[wvm] %-11s %4d tris  %s  muzzle %s"
              % (name, e["triangles"], e["size_runtime"],
                 e["nodes"]["muzzle"]))
    # The integrator reproduces Prod's own measurement of mode H.
    # (His 0.196 m is the viewmodel's whole displacement, back and lift.)
    springs = SPRINGS["foundry"]
    back = max(math.hypot(b, l) for (_, b), (_, l) in
               zip(simulate(springs["back"]), simulate(springs["lift"])))
    pitch = made["foundry"]["recoil"]["pitch"]["peak"]
    if abs(back - 0.196) > 0.002 or abs(pitch - 19.1) > 0.2:
        raise AssertionError("Foundry's springs no longer give Prod's "
                             "measured H peak: %.3f m, %.1f deg"
                             % (back, pitch))
    if made["foundry"]["nodes"]["muzzle"] != [0.0, 0.03, -0.47]:
        raise AssertionError("Foundry's muzzle left Prod's MUZZLE: %s"
                             % made["foundry"]["nodes"]["muzzle"])
    # Five silhouettes: each gun's side+top profile (all nodes, at rest,
    # 5 mm cells, in the shared Viewmodel frame) must overlap every
    # other's by under 60 %.
    sil = {n: profiles[n] for n in made}
    names = list(sil)
    worst = 0.0
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            iou = len(sil[a] & sil[b]) / float(len(sil[a] | sil[b]))
            worst = max(worst, iou)
            made[a].setdefault("profile_overlap", {})[b] = round(iou, 3)
            if iou > 0.6:
                raise AssertionError("%s and %s share a side profile "
                                     "(%.2f)" % (a, b, iou))
    common.log("profiles (side + top): worst overlap %.2f" % worst)
    shared = {
        "batch": "068",
        "status": "CANDIDATE (Arty, 2026-10-10) for the five-weapon range; "
                  "not integrated, not in the content pack",
        "frame": "Viewmodel-local: origin = the Viewmodel node, Godot -Z "
                 "forward, +Y up; node positions in that frame",
        "contract": "review/hand-cannon hand_cannon.gd: REST_POS "
                    "(0.34, -0.3, -0.62), REST_ROT (0, 8, -4), MUZZLE "
                    "(0, 0.03, -0.47), SPRINGS format",
        "fov": 90,
    }
    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("manifest %s" % path)


if __name__ == "__main__":
    main()
