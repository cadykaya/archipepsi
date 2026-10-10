"""The five weapon-family concepts as THROWAWAY maquettes, to test the
first-person read. EXPLORATION ONLY: not models, not assets. (Arty,
2026-10-10.)

    .tools/blender/blender -b --python tools/blender/study_weapon_concepts.py -- <out_dir>

Writes `<family>_<state>.glb` (four states each) and `concepts.json` into
the directory it is given, never under `assets/`: boxes, prisms and
faceted balls with flat colours, no textures, no budget. They exist to
be photographed from the player's eye in Prod's range, which a drawing
cannot do: does the dominant cue read low and right, clear of the
reticle, in grey?

The concepts are the recommendations in
`docs/art/reports/2026-10-10-weapon-design-exploration.md`, drawn in 2D by
`tools/concept_art/weapon_concepts.py`; the numbers below follow those
elevations (centimetres: x forward, y up, s to the player's left/right).
Authored in the Viewmodel's frame (Godot: x right, y up, -Z forward),
origin at the mount. There is NO pistol grip: there are no hands in
first person, so each one is clamped round the player's device.
"""

from __future__ import annotations

import json
import math
import os
import sys

import bmesh
import bpy
import mathutils

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import study_crossing_overlays as ov  # noqa: E402

# Neutral station paint and metals; the device pale; heat and the bead
# the only lit things. No gameplay hues.
PAINT = "#c3c6c4"
STEEL = "#6c7176"
DARK = "#36383c"
DEVICE = "#e4e8ea"
HEART = "#9a917e"
HOT = "#ffb060"
COLD = "#dfe8ff"


def C(x, y, s=0.0):
    """Concept cm (forward, up, side) -> the Viewmodel's metres."""
    return (s / 100.0, y / 100.0, -x / 100.0)


def mat(hexc, emit=0.0):
    return ov.mat(hexc, emit)


def box(name, x, y, s, w, h, l, m, pitch=0.0):
    """A box centred at concept (x, y, s): width w (side), height h,
    length l (forward), cm; pitch in degrees (top toward the muzzle)."""
    return ov.box(name, (w / 100.0, h / 100.0, l / 100.0), C(x, y, s), m,
                  0.0, (-pitch, 0.0))


def cyl(name, a, b, r, m, sides=8):
    """A prism of radius r (cm) from concept point a to b (x, y, s)."""
    pa = ov.G(*C(*a))
    pb = ov.G(*C(*b))
    length = (pb - pa).length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides,
                          radius1=r / 100.0, radius2=r / 100.0,
                          depth=length)
    quat = mathutils.Vector((0, 0, 1)).rotation_difference(
        (pb - pa).normalized())
    bmesh.ops.rotate(bm, cent=(0, 0, 0), verts=bm.verts,
                     matrix=quat.to_matrix())
    bmesh.ops.translate(bm, vec=(pa + pb) / 2.0, verts=bm.verts)
    return ov._obj(bm, name, m)


def ball(name, at, r, m):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r / 100.0)
    bmesh.ops.translate(bm, vec=ov.G(*C(*at)), verts=bm.verts)
    return ov._obj(bm, name, m)


def device(o, x=0.0, y=-2.0):
    """The player's device, under the frame, its tip forward, clamped."""
    o.append(box("device", x - 2, y - 5, 0, 5, 5.5, 22, mat(DEVICE)))
    o.append(box("device_tip", x + 10, y - 5, 0, 3, 3, 2,
                 mat("#cfe6ff", 1.4)))
    for bx in (x - 8, x + 3):
        o.append(box("clamp", bx, y - 1, 0, 6.4, 3.2, 2.4, mat(DARK)))


# ---------------------------------------------------------------- the five

def foundry(st):
    o = []
    device(o, -3)
    o.append(box("frame", 2, 1, 0, 5, 8, 24, mat(PAINT)))
    o.append(box("crucible", 24, 4, 0, 9, 16, 26, mat(HEART)))
    for x in (18, 28):
        o.append(box("band", x, 4, 0, 9.6, 16.6, 1.2, mat(DARK)))
    o.append(cyl("mouth", (36, 4.5, 0), (46, 4.5, 0), 4.6, mat(DARK)))
    glow = st.get("glow", 1.0)
    o.append(cyl("mouth_glow", (45.8, 4.5, 0), (46.2, 4.5, 0), 2.6,
                 mat(HOT, 0.4 + 2.6 * glow)))
    o.append(box("anvil", 13.5, 14.2, 0, 6, 2.4, 7, mat(STEEL)))
    o.append(box("post", -6, 11, 0, 4, 12, 4, mat(PAINT)))
    a = math.radians(st.get("hammer", 68))
    px, py = -6.0, 17.0
    hx, hy = px + 19 * math.cos(a), py + 19 * math.sin(a)
    o.append(cyl("hinge", (px, py, -3), (px, py, 3), 2.6, mat(STEEL)))
    o.append(cyl("hammer_arm", (px, py, 0), (hx, hy, 0), 1.5, mat(STEEL),
                 6))
    o.append(box("hammer_head", hx, hy, 0, 6, 7, 7, mat(STEEL),
                 math.degrees(a)))
    return o, C(46, 4.5)


def sightline(st):
    o = []
    device(o, -2)
    o.append(box("chassis", -4, 1, 0, 4, 6, 16, mat(PAINT)))
    o.append(box("brace", -17, -2, 0, 2.4, 3, 12, mat(STEEL), -20))
    o.append(box("yoke", 6.5, 4, 0, 14, 7, 7, mat(HEART)))
    o.append(box("rear_notch", 7, 8.5, 0, 3, 2, 2.4, mat(STEEL)))
    ring = st.get("ring", 0.0)
    # The tines side by side (left / right), NOT stacked: stacked, they
    # collapse into one line from the eye (the first maquette pass). From
    # behind, the player now looks down the slot between them.
    # ...and splayed wide at the root, above a LOW yoke: a long thin
    # thing pointing away from the eye foreshortens to nothing (second
    # pass), so the read is a V converging on the target.
    for side in (-1, 1):
        off = 1.4 * ring * side
        o.append(cyl("tine", (9, 8, side * 6.0), (72, 4, side * 1.4 + off),
                     1.0, mat(STEEL), 6))
    o.append(box("front_post", 71.3, 5.6, -1.4, 1, 2.6, 1.4, mat(STEEL)))
    o.append(box("front_post", 71.3, 5.6, 1.4, 1, 2.6, 1.4, mat(STEEL)))
    bead = st.get("bead", 1.0)
    if bead is not None and bead >= 0:
        o.append(ball("bead", (12 + 56 * bead, 7.4 - 3.0 * bead, 0), 1.5,
                      mat(COLD, 3.0)))
    return o, C(72, 4)


def switchback(st):
    o = []
    device(o, 1, -4)
    o.append(box("receiver", 9, 2, 0, 7, 12, 28, mat(PAINT)))
    o.append(box("housing", 29, 2.5, 0, 7, 9, 14, mat(PAINT)))
    for s in (-1.7, 1.7):
        o.append(cyl("port", (36, 3, s), (42, 3, s), 1.4, mat(DARK), 6))
    o.append(box("brace_bar", -13, 3, 0, 2, 2.4, 14, mat(STEEL)))
    o.append(box("brace_butt", -20, -2, 0, 3, 11, 2.2, mat(DARK)))
    o.append(box("shuttle_slot", 12, 2.2, -3.6, 0.6, 3.6, 16, mat(DARK)))
    sx = 7 + 10 * st.get("shuttle", 0.0)
    o.append(box("shuttle", sx, 2.2, -3.9, 1.2, 2.8, 5, mat(STEEL)))
    spin = st.get("spin", 0.0)
    th = math.radians(14 + 58 * spin)
    k = 1.35        # a third bigger than drawn: it read small from the eye
    top = (7, 8 + 18 * k)
    o.append(cyl("spindle", (7, 8, 0), (7, top[1], 0), 0.8, mat(STEEL), 6))
    o.append(ball("cap", (7, top[1] + 0.6, 0), 1.3, mat(STEEL)))
    sleeve = 8 + (6 + 5 * spin) * k
    o.append(cyl("sleeve", (7, sleeve - 0.8, 0), (7, sleeve + 0.8, 0), 1.2,
                 mat(DARK), 6))
    # The balls fling outward across the gun (side to side), so the
    # spread opens toward and away from the player's eye.
    for side in (-1, 1):
        bs = side * 13 * k * math.sin(th)
        by = top[1] - 13 * k * math.cos(th)
        o.append(cyl("arm", (7, top[1], 0), (7, by, bs), 0.45, mat(STEEL),
                     4))
        mx = 6.5 * k * math.sin(th) * side
        my = top[1] - 6.5 * k * math.cos(th)
        o.append(cyl("link", (7, sleeve, 0), (7, my, mx), 0.3, mat(STEEL),
                     4))
        o.append(ball("flyball", (7, by, bs), 3.0 * k, mat(HEART)))
    return o, C(42, 3)


def bulkhead(st):
    o = []
    device(o, 4, -6)
    o.append(cyl("rear_cap", (-4, 1, 0), (2, 1, 0), 6.2, mat(PAINT), 10))
    o.append(cyl("drum", (2, 1, 0), (30, 1, 0), 7.8, mat(PAINT), 10))
    for x in (8, 16, 24):
        o.append(cyl("band", (x - 0.8, 1, 0), (x + 0.8, 1, 0), 8.3,
                     mat(DARK), 10))
    # The flange is much wider than the drum, so from BEHIND its rim and
    # dogs frame the drum (the first pass hid the hatch behind its drum).
    o.append(cyl("hatch", (30, 1, 0), (34, 1, 0), 14.0, mat(HEART), 12))
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        y, s = 1 + 6.4 * math.sin(a), 6.4 * math.cos(a)
        o.append(cyl("port", (33.6, y, s), (34.6, y, s), 1.3, mat(DARK), 6))
    for i in range(4):
        a = 2 * math.pi * i / 4 + math.pi / 4
        o.append(box("dog", 29.0, 1 + 12.5 * math.sin(a), 12.5 * math.cos(a),
                     2.4, 2.4, 3, mat(STEEL)))
    o.append(cyl("gauge", (16, 8.6, 3.5), (16, 10.6, 3.5), 2.4, mat(STEEL),
                 8))
    # The dogging lever ON TOP, where the eye sees it: along the drum when
    # locked, swung up and back to vent.
    a = math.radians(180 - st.get("lever", 0.0))
    px, py, ps = 28.0, 10.0, -2.5
    ex, ey = px + 24 * math.cos(a), py + 24 * math.sin(a)
    o.append(cyl("lever", (px, py, ps), (ex, ey, ps), 0.9, mat(STEEL), 6))
    o.append(ball("lever_knob", (ex, ey, ps), 1.8, mat(STEEL)))
    o.append(cyl("lever_pivot", (px, py, ps - 1.5), (px, py, ps + 1.5), 1.6,
                 mat(DARK), 8))
    return o, C(34.6, 1)


def massdriver(st):
    o = []
    device(o, 4, -4)
    o.append(box("frame", 3, 0, 0, 6, 8, 22, mat(PAINT)))
    o.append(box("channel", 35, 2.5, 0, 6, 7.5, 50, mat(PAINT)))
    o.append(box("channel_slot", 37, 6.4, 0, 1.6, 0.8, 44, mat(DARK)))
    o.append(box("clutch", 8, 5, 0, 7, 12, 8, mat(DARK)))
    spin = st.get("spin", 0.0)
    # The flywheel, on the NEAR (left) side, facing the player's eye.
    cx, cy, s0 = -3.0, 9.0, -6.5
    o.append(cyl("flywheel_rim", (cx, cy, s0 - 1.4), (cx, cy, s0 + 1.4),
                 12.5, mat(HEART), 12))
    face = mat("#8c8f92") if spin < 0.85 else mat("#7c7f82")
    o.append(cyl("flywheel_web", (cx, cy, s0 - 1.6), (cx, cy, s0 - 1.4),
                 10.0, face, 12))
    if spin < 0.85:
        for i in range(6):
            a = 2 * math.pi * i / 6 + 0.4 + spin * 0.6
            o.append(box("spoke", cx + 5 * math.cos(a), cy + 5 * math.sin(a),
                         s0 - 1.9, 0.6, 2.0, 10, mat(DARK) if spin < 0.35
                         else mat("#55585c"), -math.degrees(a) + 90))
    o.append(cyl("hub", (cx, cy, s0 - 2.4), (cx, cy, 0), 2.6, mat(STEEL), 8))
    o.append(box("hopper", 19.5, 12, 0, 6, 9, 10, mat(PAINT)))
    if st.get("slug", True):
        o.append(box("slug", 17.5, 2.9, 0, 4.4, 4.4, 7, mat(STEEL)))
    return o, C(60, 2.8)


FAMILIES = {"foundry": foundry, "sightline": sightline,
            "switchback": switchback, "bulkhead": bulkhead,
            "massdriver": massdriver}

#: Four states each, the same as the 2D sheets (WD2-WD7): the hold, the
#: action, the recovery, ready again. `fx` names a Batch 068 muzzle sheet
#: to show at the muzzle; `pose` nudges the viewmodel (metres, degrees).
STATES = {
    "foundry": [("hold", {"hammer": 68, "glow": 1.0}, {}),
                ("fire", {"hammer": 0, "glow": 0.2},
                 {"fx": ["foundry_flash_flare", "foundry_flash_core"],
                  "kick": True}),
                ("recover", {"hammer": 32, "glow": 0.45}, {}),
                ("ready", {"hammer": 68, "glow": 1.0}, {})],
    "sightline": [("hold", {"bead": 1.0}, {}),
                  ("fire", {"bead": -1, "ring": 1.0},
                   {"fx": ["sightline_flash"], "kick": True}),
                  ("recover", {"bead": 0.45, "ring": 0.35}, {}),
                  ("ready", {"bead": 1.0}, {})],
    "switchback": [("hold", {"spin": 0.0}, {}),
                   ("runup", {"spin": 0.45, "shuttle": 0.9},
                    {"fx": ["switchback_flash_a"], "kick": True}),
                   ("sustained", {"spin": 1.0, "shuttle": 0.1},
                    {"fx": ["switchback_flash_b"], "kick": True}),
                   ("release", {"spin": 0.3, "shuttle": 0.5}, {})],
    "bulkhead": [("hold", {"lever": 0}, {}),
                 ("fire", {"lever": 0},
                  {"fx": ["bulkhead_flash"], "kick": True}),
                 ("vent", {"lever": 70}, {}),
                 ("ready", {"lever": 0}, {})],
    "massdriver": [("hold", {"spin": 0.0}, {}),
                   ("charge", {"spin": 0.6}, {"lean": 0.6}),
                   ("full", {"spin": 1.0}, {"lean": 1.0}),
                   ("release", {"spin": 0.0, "slug": False},
                    {"fx": ["massdriver_release"], "kick": True})],
}


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    os.makedirs(out, exist_ok=True)
    meta = {}
    for fam, build in FAMILIES.items():
        meta[fam] = {}
        for state, params, extra in STATES[fam]:
            common.reset_scene()
            ov._MATS.clear()
            objs, muzzle = build(params)
            bpy.ops.object.select_all(action="DESELECT")
            for obj in objs:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            path = os.path.join(out, "%s_%s.glb" % (fam, state))
            bpy.ops.export_scene.gltf(
                filepath=path, export_format="GLB", use_selection=True,
                export_apply=True, export_materials="EXPORT",
                export_yup=True)
            meta[fam][state] = dict(extra, glb=path,
                                    muzzle=[round(v, 4) for v in muzzle])
            print("[concepts] %s %s" % (fam, state))
    with open(os.path.join(out, "concepts.json"), "w") as handle:
        json.dump(meta, handle, indent=1)


if __name__ == "__main__":
    main()
