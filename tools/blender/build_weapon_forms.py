"""The other four weapons: a comparative FORM pass. (Arty, 2026-10-13.)
NOT FINAL MODELS. Proposals to choose between, before production.

    .tools/blender/blender -b --python tools/blender/build_weapon_forms.py -- OUT

Writes, per proposal, OUT/<key>/ with clay renders (left elevation at one
shared scale, the player's eye, a three-quarter look) and a GLB for the
in-engine eye check, plus OUT/forms.json (triangles, runtime nodes, sight
lines). `tools/crossing_capture/weapon_forms_sheets.py` lays them out.

THE STANDARD. The owner approved the Foundry study as the benchmark
(2026-10-13): purposeful geometry, believable construction, station work
round Epsilon technology, an Echo core. Not every gun is to look like the
Foundry: each gets its own silhouette, mechanism and material character.
These are forms only -- no textures yet; the clay is tinted by material
(station paint, working steel, Epsilon black, the core, tape) so the
material character reads.

WHAT EACH ONE IS BUILT ON (Prod's runtime, review/five-weapons-v3), so a
chosen form can be finished without asking his runtime to move:

  sightline   `handle` slides back 22 mm on each shot (the bolt); ring
              sights on the line y = 0.075 (his ADS pose); muzzle at
              (0, 0.025, -0.74)
  switchback  `bolt` slides 35 mm a round on the right; ring sight on
              y = 0.065; muzzle (0, 0.02, -0.42)
  bulkhead    `pump` slides back 100 mm (Breacher); `feed` is shown only
              for the Sweeper -- ONE model carries both; muzzle
              (0, 0.02, -0.50)
  driver      `coils` spins about the bore with the charge; `core` glows
              with it (its material is driven); the charge orb sits at
              (0, 0, -0.40); ring sight on y = 0.13; muzzle (0, 0, -0.62)

Same frame as the Foundry study: Godot RangeRig model space, -Z forward.
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
import common  # noqa: E402
from build_foundry_study import (box, cyl, g2b, hexhead, hull, loft,  # noqa
                                 ngon, oct_ring, prism, rotate, sweep, tube)

# --------------------------------------------------------------- helpers

def ring_sight(name, y, z, r, base_y, part=None):
    """An open ring on the sight line, on a post down to `base_y`."""
    out = [tube(name, r + 0.0035, r, 8, 0.0, y, z - 0.0022, z + 0.0022,
                "bare", part=part or name)]
    out.append(box(name + "_post", -0.0022, 0.0022, base_y, y - r, z - 0.003,
                   z + 0.003, "bare", part=part or name))
    return out


def weld(name, pts, r=0.0018):
    return sweep(name, pts, r, 6, "painted", part="welds")


def cartridge(name, base, axis, length, r, socket_cls="epsilon"):
    """An Echo core cartridge pushed into a socket along `axis`."""
    ax = Vector(axis).normalized()
    up = Vector((0, 1, 0)) if abs(ax.y) < 0.9 else Vector((1, 0, 0))
    u = ax.cross(up).normalized()
    v = ax.cross(u).normalized()
    b = Vector(base)

    def at(t):
        return tuple(b + ax * t)
    U, V = tuple(u), tuple(v)
    return [
        loft(name + "_socket", [oct_ring(at(t), U, V, rr, rr) for t, rr in
                                ((0.0, r + 0.0032), (0.012, r + 0.0032),
                                 (0.014, r + 0.0018))], socket_cls,
             part=name + "_socket"),
        loft(name, [oct_ring(at(t), U, V, rr, rr) for t, rr in
                    ((0.008, r), (length - 0.006, r), (length - 0.002,
                                                       r * 0.85))], "core"),
        loft(name + "_cap", [oct_ring(at(t), U, V, rr, rr) for t, rr in
                             ((length - 0.003, r + 0.0010),
                              (length + 0.005, r + 0.0010),
                              (length + 0.007, r * 0.9))], "bare",
             part=name + "_cap"),
    ]


def lamp(name, x, y, z, axis="x", sign=-1):
    """The one green lamp: powered."""
    if axis == "x":
        return [prism(name + "_bezel", ngon(0.0050, 6, z, y), "x",
                      x if sign > 0 else x - 0.004,
                      x + 0.004 if sign > 0 else x, "epsilon",
                      part=name + "_bezel"),
                prism(name, ngon(0.0032, 6, z, y), "x",
                      x + (0.004 if sign > 0 else -0.006),
                      x + (0.006 if sign > 0 else -0.004), "lamp")]
    return [cyl(name + "_bezel", 0.0050, 6, x, y, z - 0.002, z + 0.004,
                "epsilon", part=name + "_bezel"),
            cyl(name, 0.0032, 6, x, y, z - 0.004, z - 0.002, "lamp")]


def grip(name, top, rake_deg, length, ru=0.0155, rv=0.0205):
    rk = math.radians(rake_deg)
    d = (0.0, -math.cos(rk), math.sin(rk))
    fv = (0.0, math.sin(rk), math.cos(rk))

    def at(t):
        return tuple(top[i] + d[i] * t for i in range(3))
    X = (1.0, 0.0, 0.0)
    return [loft(name, [oct_ring(at(t), X, fv, a, b) for t, a, b in
                        ((0.0, ru, rv), (length * 0.4, ru * 0.94, rv * 0.93),
                         (length * 0.9, ru * 1.03, rv * 1.02),
                         (length, ru, rv))], "tape"),
            loft(name + "_cap", [oct_ring(at(t), X, fv, a, b) for t, a, b in
                                 ((length - 0.002, ru * 1.08, rv * 1.07),
                                  (length + 0.012, ru * 1.04, rv * 1.03))],
                 "painted", part=name + "_cap")]


# ------------------------------------------------- construction kit
# The Foundry read as built because it was built: plates with edges,
# straps, bolts, welds, collars. These make the same moves cheaply.

def plated_receiver(name, profile, hw, plate=0.0025, lip=0.0008,
                    slot=None, slot_side=1):
    """A fabricated receiver: a core prism and two side plates proud of it
    by `lip`, so the plate edges read. `slot` = (z0, z1, y0, y1) leaves an
    open raceway in the RIGHT plate (the bolt shows through it)."""
    out = [prism(name, profile, "x", -hw + plate, hw - plate, "painted",
                 bevel=0.0015, bevel_pred=fs._across_x)]
    big = [(z, y) for z, y in profile]
    solid_side = -slot_side if slot is not None else None
    for side in (-1, 1):
        if slot is not None and side == slot_side:
            continue
        xa, xb = sorted((side * (hw - plate), side * (hw + lip)))
        out.append(prism(name + "_plate_%s" % ("l" if side < 0 else "r"),
                         big, "x", xa, xb, "painted",
                         part=name + "_plates", bevel=0.0012,
                         bevel_pred=fs._across_x))
    if slot is not None:
        z0, z1, y0, y1 = slot
        zs = [z for z, _ in profile]
        ys = [y for _, y in profile]
        zmin, zmax, ymin, ymax = min(zs), max(zs), min(ys), max(ys)
        # the slotted plate in pieces round the raceway (the profile's
        # outline is kept by the core prism behind it)
        xa, xb = sorted((slot_side * (hw - plate), slot_side * (hw + lip)))
        ins = [(z, y) for z, y in profile]
        zs = [z for z, _ in ins]
        ys = [y for _, y in ins]
        zmin, zmax = min(zs) + 0.004, max(zs) - 0.004
        ymin, ymax = min(ys) + 0.004, max(ys) - 0.004
        for k, (za, zb, ya, yb) in enumerate((
                (zmin, z0, ymin, ymax), (z1, zmax, ymin, ymax),
                (z0, z1, ymin, y0), (z0, z1, y1, ymax))):
            if zb - za < 1e-4 or yb - ya < 1e-4:
                continue
            out.append(box(name + "_plate_s%d" % k, xa, xb, ya, yb, za, zb,
                           "painted", part=name + "_plates"))
        ra, rb = sorted((slot_side * (hw - plate - 0.006),
                         slot_side * (hw - plate)))
        out.append(box(name + "_raceway", ra, rb, y0, y1, z0, z1, "bare",
                       part=name + "_raceway"))
    return out


def shaped_profile(z0, z1, y0, y1, rear_r=0.020, front_ch=0.010,
                   step=None):
    """A receiver's side outline: a chamfered front, a back rounded on a
    radius (top and bottom), and an optional lower `step` = (z, y) where
    the top drops toward the front."""
    pts = [(z0, y0 + front_ch * 0.6)]
    pts.append((z0 + front_ch * 0.6, y0))
    for k in range(4):                       # bottom-rear arc
        a = math.radians(270 + 22.5 * k)
        pts.append((z1 - rear_r + rear_r * math.cos(a) * 0 + rear_r *
                    math.sin(math.radians(22.5 * k)),
                    y0 + rear_r - rear_r * math.cos(math.radians(22.5 * k))))
    for k in range(4):                       # top-rear arc
        t = math.radians(90 - 22.5 * k)
        pts.append((z1 - rear_r + rear_r * math.cos(t) * 0 + rear_r *
                    math.cos(math.radians(22.5 * k)),
                    y1 - rear_r + rear_r * math.sin(math.radians(22.5 * k))))
    pts.append((z1 - rear_r, y1))
    if step:
        sz, sy = step
        pts.append((sz + 0.006, y1))
        pts.append((sz, sy))
        pts.append((z0 + front_ch, sy))
        pts.append((z0, sy - front_ch))
    else:
        pts.append((z0 + front_ch, y1))
        pts.append((z0, y1 - front_ch))
    # drop coincident neighbours
    out = []
    for p in pts:
        if not out or abs(out[-1][0] - p[0]) + abs(out[-1][1] - p[1]) > 1e-5:
            out.append(p)
    return out


def receiver(name, z0, z1, y0, y1, hw, rear_r=0.020, front_ch=0.010,
             step=None, slot=None, slot_side=1, cover=None, housing=None,
             ribs=(), panel=None):
    """A built receiver: plated, shaped, with a raised top cover on
    screws, a welded trigger housing and stiffener ribs on the left."""
    prof = shaped_profile(z0, z1, y0, y1, rear_r, front_ch, step)
    out = plated_receiver(name, prof, hw, slot=slot, slot_side=slot_side)
    top = step[1] if step else y1
    if cover:
        c0, c1 = cover
        ytop = y1 if (step is None or c0 >= step[0]) else top
        out.append(box(name + "_cover", -hw + 0.004, hw - 0.004, ytop,
                       ytop + 0.0028, c0, c1, "painted", bevel=0.0010))
        for k, z in enumerate((c0 + 0.006, c1 - 0.006)):
            for sx in (-1, 1):
                out.append(hexhead("%s_cs%d%d" % (name, k, sx > 0),
                                   (sx * (hw - 0.009), ytop + 0.0028, z),
                                   "y", 1, 0.0020, 0.0010,
                                   part=name + "_cover"))
    if housing:
        h0, h1, depth, hh = housing
        out.append(box(name + "_housing", -hh, hh, y0 - depth, y0 + 0.002,
                       h0, h1, "painted", bevel=0.0025))
        out.append(weld(name + "_housing_weld",
                        [(-hh - 0.0003, y0 - 0.0005, h0 + 0.004),
                         (-hh - 0.0006, y0 - 0.0005, (h0 + h1) / 2),
                         (-hh - 0.0003, y0 - 0.0005, h1 - 0.004)]))
    for k, z in enumerate(ribs):
        out.append(box("%s_rib%d" % (name, k), -hw - 0.0030, -hw - 0.0006,
                       y0 + 0.006, top - 0.006, z - 0.0022, z + 0.0022,
                       "painted", part=name + "_ribs"))
        out.append(weld("%s_ribweld%d" % (name, k),
                        [(-hw - 0.0008, y0 + 0.008, z + 0.0035),
                         (-hw - 0.0010, (y0 + top) / 2, z + 0.0037),
                         (-hw - 0.0008, top - 0.008, z + 0.0035)],
                        r=0.0012))
    if panel:
        pz0, pz1, py0, py1, cls = panel
        out += side_panel(name + "_panel", -hw - 0.0008, pz0, pz1, py0, py1,
                          -1, cls)
    return out


def side_panel(name, x, z0, z1, y0, y1, sign=-1, cls="patch",
               bolts=True):
    """A bolted cover plate on a side face, with hex heads at its corners."""
    t = 0.0022
    xa, xb = (x - t, x) if sign < 0 else (x, x + t)
    out = [box(name, xa, xb, y0, y1, z0, z1, cls, bevel=0.0006)]
    if bolts:
        xo = xa if sign < 0 else xb
        for k, (zz, yy) in enumerate(((z0 + 0.005, y0 + 0.005),
                                      (z1 - 0.005, y0 + 0.005),
                                      (z0 + 0.005, y1 - 0.005),
                                      (z1 - 0.005, y1 - 0.005))):
            out.append(hexhead("%s_bolt%d" % (name, k), (xo, yy, zz), "x",
                               sign, 0.0026, 0.0016, part=name + "_bolts"))
    return out


def clamp_band(name, cx, cy, z, r, width=0.010, ear_side=-1, cls="strap"):
    """A two-piece clamp band with a bolted ear on one side."""
    out = [tube(name, r + 0.0032, r - 0.0004, 8, cx, cy, z - width / 2,
                z + width / 2, cls, bevel=0.0006)]
    ex = cx + ear_side * (r + 0.0045)
    out.append(box(name + "_ear", min(ex, ex + ear_side * 0.006),
                   max(ex, ex + ear_side * 0.006), cy - 0.006, cy + 0.006,
                   z - width / 2, z + width / 2, cls, part=name))
    out.append(hexhead(name + "_bolt", (ex + ear_side * 0.006, cy, z), "x",
                       ear_side, 0.0026, 0.002, part=name))
    return out


def barrel_run(name, cx, cy, z0, z1, r, cls="barrel", nut=True):
    """A barrel with a nut where it threads into the receiver."""
    out = [cyl(name, r, 8, cx, cy, z0, z1, cls, phase=math.pi / 8)]
    if nut:
        out.append(cyl(name + "_nut", r + 0.0045, 8, cx, cy, z1 - 0.014,
                       z1, "bare", phase=math.pi / 8, bevel=0.0012))
    return out


def node(name, at):
    e = bpy.data.objects.new(name, None)
    e.location = Vector(g2b(at))
    bpy.context.scene.collection.objects.link(e)
    return e


# ============================================================ SIGHTLINE

def sightline_a():
    """THE ACCELERATOR RIFLE. A long, heavy bolt rifle; three Epsilon
    stator packs clamped along the barrel give the slug its last push --
    the 'substantial, powerful' read is mass along the line of fire. The
    Echo core is a slab cartridge seated from below like a magazine."""
    P = []
    P += receiver("receiver", -0.210, 0.074, -0.034, 0.040, 0.023,
                  rear_r=0.026, front_ch=0.012,
                  slot=(-0.140, -0.024, 0.008, 0.032), slot_side=-1,
                  housing=(-0.060, 0.030, 0.010, 0.016),
                  ribs=(-0.180, 0.012, 0.044),
                  panel=(-0.130, -0.034, -0.028, 0.002, "painted"))
    # a welded trunnion where the barrel enters
    P.append(box("trunnion", -0.026, 0.026, -0.030, 0.040, -0.214, -0.196,
                 "painted", bevel=0.002))
    P.append(box("rail", -0.0100, 0.0100, 0.040, 0.0465, -0.150, 0.046,
                 "bare", bevel=0.0012))
    for k, z in enumerate((-0.140, -0.080, -0.020, 0.034)):
        P.append(hexhead("rail_screw%d" % k, (0.0, 0.0465, z), "y", 1,
                         0.0022, 0.0012, part="rail"))
    # a heavy barrel and a machined brake
    P += barrel_run("barrel", 0, 0.025, -0.700, -0.196, 0.0185)
    for k, (za, zb) in enumerate(((-0.708, -0.700), (-0.722, -0.713),
                                  (-0.740, -0.727))):
        P.append(tube("brake%d" % k, 0.0245, 0.0108, 8, 0, 0.025, za, zb,
                      "barrel", bevel=0.0010, part="brake"))
    for x in (-0.006, 0.006):
        P.append(box("brake_tie%d" % int(x * 1e3), x - 0.003, x + 0.003,
                     0.043, 0.0495, -0.740, -0.700, "barrel", part="brake"))
    # the accelerator: three Epsilon stator packs on a station spine
    for i, z in enumerate((-0.350, -0.440, -0.530)):
        P.append(tube("stator%d" % i, 0.0315, 0.0190, 8, 0, 0.025,
                      z - 0.017, z + 0.017, "epsilon", bevel=0.0012))
        for j, dz in enumerate((-0.019, 0.019)):
            P.append(tube("stator_lip%d%d" % (i, j), 0.0330, 0.0280, 8, 0,
                          0.025, z + dz - 0.002, z + dz + 0.002, "epsilon",
                          part="stator%d" % i))
        P += clamp_band("stator_saddle%d" % i, 0, 0.025, z, 0.0318,
                        width=0.008, ear_side=-1)
        P.append(box("stator_foot%d" % i, -0.007, 0.007, -0.022, -0.006,
                     z - 0.008, z + 0.008, "strap"))
    P.append(box("bus", -0.0255, -0.0215, 0.040, 0.046, -0.548, -0.332,
                 "epsilon"))
    P.append(box("spine", -0.0060, 0.0060, -0.031, -0.022, -0.560, -0.196,
                 "painted", bevel=0.0012))
    P.append(sweep("lead", [(-0.016, -0.030, -0.206), (-0.028, -0.010,
                                                       -0.300),
                            (-0.028, 0.030, -0.336)], 0.0034, 6, "cable"))
    P += lamp("lamp", -0.0330, 0.034, -0.440, "x", -1)
    # the Echo core: a slab cartridge seated from below, with its latch
    P.append(box("core_well", -0.018, 0.018, -0.070, -0.033, -0.252,
                 -0.192, "painted", bevel=0.0018))
    P.append(box("core_slab", -0.0140, 0.0140, -0.098, -0.068, -0.246,
                 -0.198, "core", bevel=0.0028))
    P.append(box("core_latch", -0.0205, -0.0180, -0.066, -0.046, -0.228,
                 -0.214, "bare", bevel=0.0006))
    P.append(box("core_tab", -0.006, 0.006, -0.106, -0.096, -0.230,
                 -0.214, "bare", bevel=0.0012))
    # the rear sight tower, welded to the rail, and the front post
    P.append(box("rear_tower", -0.008, 0.008, 0.0465, 0.058, -0.052,
                 -0.030, "painted", bevel=0.0012))
    P += ring_sight("rear_ring", 0.075, -0.040, 0.0115, 0.058)
    P.append(box("front_base", -0.007, 0.007, 0.040, 0.047, -0.310,
                 -0.290, "bare", bevel=0.001))
    P += ring_sight("front_ring", 0.075, -0.300, 0.0090, 0.047)
    # grip, guard, a skeletal stock with a cheek plate
    P += grip("grip", (0.0, -0.034, 0.004), 16, 0.100)
    P.append(sweep("guard", [(0, -0.034, -0.062), (0, -0.064, -0.056),
                             (0, -0.072, -0.032), (0, -0.064, -0.008)],
                   0.0030, 4, "painted"))
    P.append(box("trigger", -0.003, 0.003, -0.056, -0.036, -0.038, -0.032,
                 "bare"))
    P.append(weld("weld_well", [(-0.0185, -0.034, -0.250),
                                (-0.0188, -0.034, -0.222),
                                (-0.0185, -0.034, -0.194)]))
    P.append(weld("weld_tower", [(-0.0082, 0.0465, -0.053),
                                 (-0.0085, 0.0465, -0.041),
                                 (-0.0082, 0.0465, -0.029)]))
    # the bolt and its handle: Prod's `handle`, sliding back 22 mm
    # on the LEFT, where the eye sees it work every shot
    H = [cyl("bolt_body", 0.0085, 8, -0.0145, 0.020, -0.136, -0.030,
             "bare", part="handle", bevel=0.0010),
         box("handle_arm", -0.0420, -0.0220, 0.017, 0.025, -0.086, -0.074,
             "bare", part="handle", bevel=0.0010),
         prism("handle_knob", ngon(0.0085, 8, -0.080, 0.021), "x", -0.0545,
               -0.040, "bare", part="handle", bevel=0.0015)]
    return P, {"Handle": (H, (0.0, 0.021, -0.080))}, {
        "muzzle": (0, 0.025, -0.74), "sights": [0.075]}


def sightline_b():
    """THE RESERVOIR RIFLE. Barrel over a long Epsilon pressure reservoir,
    joined by a station regulator block with a hand wheel, a broad slab
    brake: twin tubes, a different line from A and from every other gun.
    The bolt works on the left; the core screws into the reservoir's
    tail."""
    P = []
    P += receiver("receiver", -0.160, 0.068, -0.030, 0.044, 0.023,
                  rear_r=0.024, front_ch=0.012,
                  slot=(-0.130, -0.026, 0.010, 0.034), slot_side=-1,
                  housing=(-0.060, 0.030, 0.010, 0.016),
                  ribs=(-0.148, 0.012, 0.044))
    P.append(box("rail", -0.0095, 0.0095, 0.044, 0.0505, -0.140, 0.040,
                 "bare", bevel=0.0012))
    P += barrel_run("barrel", 0, 0.025, -0.700, -0.150, 0.0160)
    # the reservoir: a long Epsilon vessel, capped, banded to the barrel
    P.append(cyl("reservoir", 0.0205, 8, 0, -0.026, -0.560, -0.122,
                 "epsilon", bevel=0.002, bevel_pred=fs._across))
    P.append(tube("reservoir_cap", 0.0222, 0.0100, 8, 0, -0.026, -0.578,
                  -0.556, "epsilon", bevel=0.0015, part="reservoir"))
    P.append(cyl("reservoir_plug", 0.0100, 8, 0, -0.026, -0.584, -0.570,
                  "bare", part="reservoir"))
    for i, z in enumerate((-0.210, -0.470)):
        P += clamp_band("band_res%d" % i, 0, -0.026, z, 0.0205, ear_side=-1)
        P += clamp_band("band_bar%d" % i, 0, 0.025, z, 0.0160, ear_side=-1)
        P.append(box("band_web%d" % i, -0.004, 0.004, -0.006, 0.010,
                     z - 0.004, z + 0.004, "strap"))
    # the regulator: a station block bridging both, its wheel on the left
    P += plated_receiver("regulator", [(-0.336, -0.050), (-0.284, -0.050),
                                       (-0.284, 0.040), (-0.300, 0.046),
                                       (-0.320, 0.046), (-0.336, 0.040)],
                         0.022)
    P.append(prism("valve_stem", ngon(0.0040, 8, -0.310, -0.004), "x",
                   -0.040, -0.022, "bare"))
    P.append(tube_x("valve_wheel", -0.0465, -0.0405, -0.310, -0.004, 0.0165,
                    0.0125))
    for k in range(4):
        a = math.radians(45 + 90 * k)
        P.append(box("spoke%d" % k, -0.046, -0.041, -0.004 - 0.0015,
                     -0.004 + 0.0015, -0.310 - 0.0015, -0.310 + 0.0015,
                     "bare", part="valve_wheel"))
        rotate(P[-1], (1, 0, 0), 45 + 90 * k, (0, -0.004, -0.310))
        P[-1].data.transform(Matrix.Translation(Vector(g2b(
            (0, 0.0072 * math.sin(a), -0.0072 * math.cos(a))))))
    P += lamp("lamp", -0.0225, 0.030, -0.296, "x", -1)
    P.append(weld("weld_reg_t", [(-0.0225, 0.046, -0.334), (-0.0228, 0.046,
                                                           -0.310),
                                 (-0.0225, 0.046, -0.286)]))
    # a broad slab brake with three fins a side
    P.append(box("brake", -0.020, 0.020, 0.008, 0.042, -0.742, -0.700,
                 "barrel", bevel=0.002))
    for i in range(3):
        z = -0.734 + 0.012 * i
        P.append(box("fin%d" % i, -0.027, 0.027, 0.012, 0.038, z - 0.002,
                     z + 0.002, "barrel", part="brake"))
    # the core: a canister screwed into the reservoir's tail, raked back
    P += cartridge("core", (-0.014, -0.040, -0.124),
                   (-0.55, -0.30, 0.78), 0.040, 0.0092)
    P.append(box("rear_tower", -0.008, 0.008, 0.0505, 0.060, -0.052,
                 -0.030, "painted", bevel=0.0012))
    P += ring_sight("rear_ring", 0.075, -0.040, 0.0115, 0.060)
    P += ring_sight("front_ring", 0.075, -0.300, 0.0090, 0.041)
    P += grip("grip", (0.0, -0.030, 0.000), 14, 0.100)
    P.append(sweep("guard", [(0, -0.030, -0.062), (0, -0.060, -0.056),
                             (0, -0.068, -0.032), (0, -0.060, -0.010)],
                   0.0030, 4, "painted"))
    H = [cyl("bolt_body", 0.0085, 8, -0.0145, 0.022, -0.126, -0.030,
             "bare", part="handle", bevel=0.0010),
         box("handle_arm", -0.0400, -0.0220, 0.019, 0.027, -0.086, -0.074,
             "bare", part="handle", bevel=0.0010),
         hull("handle_knob", [(x, 0.023 + 0.0085 * math.sin(a),
                               -0.080 + 0.0085 * math.cos(a))
                              for x in (-0.052, -0.038)
                              for a in [k * math.pi / 4 for k in range(8)]],
              "bare", part="handle")]
    return P, {"Handle": (H, (0.0, 0.023, -0.080))}, {
        "muzzle": (0, 0.025, -0.74), "sights": [0.075]}


def tube_x(name, x0, x1, cz, cy, r_out, r_in, cls="bare"):
    """An 8-sided ring whose axis runs along X (a wheel, a pan rim)."""
    import bmesh as _bm
    bm = _bm.new()
    n = 8

    def ring(r, x):
        return [bm.verts.new(g2b((x, cy + r * math.sin(2 * math.pi * k / n
                                                        + math.pi / 8),
                                  cz + r * math.cos(2 * math.pi * k / n
                                                    + math.pi / 8))))
                for k in range(n)]
    o0, i0, o1, i1 = ring(r_out, x0), ring(r_in, x0), ring(r_out, x1), \
        ring(r_in, x1)
    for k in range(n):
        j = (k + 1) % n
        bm.faces.new((o0[k], o0[j], o1[j], o1[k]))
        bm.faces.new((i0[j], i0[k], i1[k], i1[j]))
        bm.faces.new((o0[j], o0[k], i0[k], i0[j]))
        bm.faces.new((o1[k], o1[j], i1[j], i1[k]))
    return fs._obj(name, bm, cls)


# =========================================================== SWITCHBACK

def switchback_a():
    """THE JACKETED CARBINE. Compact and busy: a slatted cooling jacket
    round the barrel (it is the gun that sustains fire, so it is the gun
    that runs hot), a ribbed box magazine ahead of the grip, the Epsilon
    feed motor on the left with the core in its end, and the bolt racing
    in an open port on the LEFT, where the eye sees every round."""
    P = []
    P += receiver("receiver", -0.200, 0.064, -0.030, 0.036, 0.026,
                  rear_r=0.028, front_ch=0.014,
                  slot=(-0.150, -0.050, 0.008, 0.032), slot_side=-1,
                  cover=(0.000, 0.050), housing=(-0.050, 0.040, 0.010,
                                                 0.019),
                  ribs=(-0.180, 0.030))
    P += barrel_run("barrel", 0, 0.020, -0.420, -0.196, 0.0095)
    for i, z in enumerate((-0.212, -0.392)):
        P.append(tube("jacket_collar%d" % i, 0.0215, 0.0098, 8, 0, 0.020,
                      z - 0.008, z + 0.008, "painted", bevel=0.0008))
    P.append(tube("jacket_mid", 0.0210, 0.0185, 8, 0, 0.020, -0.305,
                  -0.299, "painted", part="jacket_collar0"))
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        cx, cy = 0.0185 * math.cos(a), 0.020 + 0.0185 * math.sin(a)
        P.append(prism("slat%d" % k, ngon(0.0030, 4, cx, cy, a), "z",
                       -0.392, -0.212, "bare", part="jacket"))
    P.append(tube("comp", 0.0130, 0.0070, 8, 0, 0.020, -0.420, -0.400,
                  "barrel", bevel=0.0008))
    for x in (-0.009, 0.009):
        P.append(box("comp_port%d" % int(x * 1e3), x - 0.0015, x + 0.0015,
                     0.030, 0.034, -0.416, -0.404, "barrel", part="comp"))
    # the ribbed magazine, raked forward, in a welded well
    mag = [box("magazine", -0.011, 0.011, -0.150, -0.028, -0.135, -0.090,
               "painted", bevel=0.0018)]
    for k, y in enumerate((-0.070, -0.110)):
        mag.append(box("mag_rib%d" % k, -0.0125, 0.0125, y - 0.003, y + 0.003,
                       -0.136, -0.089, "strap", part="magazine"))
    for o in mag:
        rotate(o, (1, 0, 0), 9.0, (0, -0.030, -0.112))
    P += mag
    P.append(box("mag_well", -0.0145, 0.0145, -0.044, -0.026, -0.140,
                 -0.084, "painted", bevel=0.0015))
    P.append(box("mag_catch", -0.0170, -0.0145, -0.040, -0.030, -0.082,
                 -0.074, "bare"))
    # the Epsilon feed motor low on the left, its core sticking out
    P.append(prism("motor", ngon(0.0190, 8, -0.020, -0.006), "x", -0.044,
                   -0.026, "epsilon", bevel=0.0015))
    P += cartridge("core", (-0.044, -0.006, -0.020), (-1, 0, 0), 0.026,
                   0.0078)
    P += lamp("lamp", -0.0265, 0.028, -0.172, "x", -1)
    P.append(sweep("motor_lead", [(-0.030, -0.022, -0.034),
                                  (-0.030, -0.030, -0.080)], 0.0030, 6,
                   "cable"))
    # carry handle with the rear ring; front post on the jacket collar
    P.append(box("handle_bar", -0.0060, 0.0060, 0.050, 0.057, -0.170,
                 -0.004, "painted", bevel=0.0015))
    for z in (-0.164, -0.010):
        P.append(box("handle_leg%d" % int(-z * 1000), -0.0050, 0.0050,
                     0.036, 0.050, z - 0.006, z + 0.006, "painted"))
    P += ring_sight("rear_ring", 0.065, -0.020, 0.0110, 0.057)
    P += ring_sight("front_post", 0.065, -0.392, 0.0060, 0.041)
    P += grip("grip", (0.0, -0.030, 0.012), 14, 0.095)
    P.append(sweep("guard", [(0, -0.030, -0.040), (0, -0.056, -0.036),
                             (0, -0.062, -0.016), (0, -0.056, 0.004)],
                   0.0028, 4, "painted"))
    P.append(weld("weld_well", [(-0.0150, -0.030, -0.139),
                                (-0.0153, -0.030, -0.112),
                                (-0.0150, -0.030, -0.086)]))
    P.append(weld("weld_legs", [(-0.0052, 0.050, -0.170), (-0.0055, 0.0435,
                                                          -0.170),
                                (-0.0052, 0.037, -0.170)]))
    B = [box("bolt", -0.0310, -0.0230, 0.012, 0.030, -0.140, -0.084, "bare",
             part="bolt", bevel=0.0012),
         box("bolt_lug", -0.0400, -0.0310, 0.017, 0.026, -0.108, -0.096,
             "bare", part="bolt")]
    return P, {"Bolt": (B, (-0.032, 0.021, -0.112))}, {
        "muzzle": (0, 0.02, -0.42), "sights": [0.065]}


def switchback_b():
    """THE PAN GUN. A flat pan magazine on the left, its hub the Epsilon
    feed motor with the core at its centre: the biggest single shape any
    of the five carries, and the one the eye sees most. A finned barrel
    instead of a jacket; the bolt works on the right."""
    P = []
    P += receiver("receiver", -0.180, 0.066, -0.028, 0.034, 0.024,
                  rear_r=0.026, front_ch=0.014,
                  slot=(-0.140, -0.060, 0.008, 0.030), slot_side=1,
                  housing=(-0.040, 0.044, 0.010, 0.018),
                  ribs=(0.020, 0.046))
    P += barrel_run("barrel", 0, 0.020, -0.420, -0.176, 0.0110)
    for i in range(6):
        z = -0.214 - 0.026 * i
        P.append(tube("fin%d" % i, 0.0225, 0.0112, 8, 0, 0.020, z - 0.0035,
                      z + 0.0035, "barrel", part="fins"))
    P.append(tube("comp", 0.0140, 0.0075, 8, 0, 0.020, -0.420, -0.394,
                  "barrel", bevel=0.0008))
    # the pan: a flat drum on the left; station shell, Epsilon hub
    P.append(prism("pan", ngon(0.0560, 12, -0.064, 0.004), "x", -0.046,
                   -0.028, "painted", bevel=0.0018))
    P.append(tube_x("pan_rim", -0.042, -0.032, -0.064, 0.004, 0.0600,
                    0.0555, "strap"))
    P.append(prism("pan_hub", ngon(0.0180, 8, -0.064, 0.004), "x", -0.052,
                   -0.044, "epsilon", bevel=0.0012))
    P += cartridge("core", (-0.052, 0.004, -0.064), (-1, 0, 0), 0.020,
                   0.0080)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        P.append(hexhead("pan_rivet%d" % k, (-0.046, 0.004 + 0.042 *
                                             math.sin(a), -0.064 + 0.042 *
                                             math.cos(a)), "x", -1, 0.0024,
                         0.0016, part="pan_rivets"))
    P.append(box("pan_feed", -0.032, -0.022, -0.014, 0.022, -0.100, -0.030,
                 "painted", bevel=0.0012))
    P.append(box("pan_latch", -0.050, -0.046, 0.050, 0.064, -0.070, -0.058,
                 "bare", bevel=0.0006))
    P += lamp("lamp", -0.0245, 0.026, -0.150, "x", -1)
    P.append(box("rail", -0.0080, 0.0080, 0.034, 0.040, -0.170, 0.030,
                 "bare", bevel=0.001))
    P += ring_sight("rear_ring", 0.065, -0.020, 0.0110, 0.040)
    P += ring_sight("front_post", 0.065, -0.360, 0.0060, 0.043)
    P += grip("grip", (0.0, -0.028, 0.014), 16, 0.095)
    P.append(sweep("guard", [(0, -0.028, -0.034), (0, -0.054, -0.030),
                             (0, -0.060, -0.010), (0, -0.054, 0.008)],
                   0.0028, 4, "painted"))
    P.append(box("fore", -0.016, 0.016, -0.052, -0.026, -0.176, -0.112,
                 "tape", bevel=0.004))
    P.append(weld("weld_feed", [(-0.0322, 0.022, -0.100), (-0.0325, 0.004,
                                                           -0.100),
                                (-0.0322, -0.014, -0.100)]))
    B = [box("bolt", 0.0230, 0.0310, 0.012, 0.028, -0.130, -0.074, "bare",
             part="bolt", bevel=0.0012),
         box("bolt_lug", 0.0310, 0.0400, 0.016, 0.024, -0.090, -0.080,
             "bare", part="bolt")]
    return P, {"Bolt": (B, (0.030, 0.020, -0.100))}, {
        "muzzle": (0, 0.02, -0.42), "sights": [0.065]}


# ============================================================= BULKHEAD

def _pump(z0=-0.420, z1=-0.322, y_tube=-0.016, half=0.032):
    out = [box("pump_body", -half, half, y_tube - 0.020, y_tube + 0.012,
               z0, z1, "tape", part="pump", bevel=0.005)]
    for k, z in enumerate((z0 + 0.009, z1 - 0.009)):
        out.append(box("pump_band%d" % k, -half - 0.0015, half + 0.0015,
                       y_tube - 0.0215, y_tube + 0.0135, z - 0.003,
                       z + 0.003, "strap", part="pump"))
    out.append(hexhead("pump_bolt", (-half - 0.0015, y_tube - 0.004,
                                     (z0 + z1) / 2), "x", -1, 0.0026, 0.002,
                       part="pump"))
    return out


def _feed(z0=-0.180, z1=-0.090, pivot_y=-0.040):
    f = [box("feed_box", -0.026, 0.026, -0.190, -0.040, z0, z1, "painted",
             part="feed", bevel=0.0025),
         box("feed_lip", -0.028, 0.028, -0.052, -0.036, z0 - 0.004,
             z1 + 0.004, "strap", part="feed"),
         box("feed_base", -0.028, 0.028, -0.198, -0.186, z0 - 0.003,
             z1 + 0.003, "bare", part="feed", bevel=0.0015)]
    for k, y in enumerate((-0.090, -0.140)):
        f.append(box("feed_rib%d" % k, -0.0275, 0.0275, y - 0.003,
                     y + 0.003, z0 - 0.001, z1 + 0.001, "strap",
                     part="feed"))
    for o in f:
        rotate(o, (1, 0, 0), 6.0, (0, pivot_y, (z0 + z1) / 2))
    return f


def bulkhead_a():
    """THE TWIN-BORE BREACHER. Broad and squat: two short bores side by
    side under a welded rib, one heavy muzzle plate, an Epsilon charger
    block riding on top with the core standing in it -- right where the
    eye looks. One platform, two configurations: the Breacher works the
    pump; the Sweeper takes a feed box under the receiver and leaves the
    pump alone (Prod shows `feed` for the Sweeper only)."""
    P = []
    P += receiver("receiver", -0.200, 0.066, -0.040, 0.044, 0.046,
                  rear_r=0.034, front_ch=0.012, cover=(-0.100, 0.034),
                  housing=(-0.040, 0.050, 0.012, 0.020),
                  ribs=(-0.186, 0.022),
                  panel=(-0.170, -0.060, -0.032, 0.018, "patch"))
    for side, x in (("l", -0.0245), ("r", 0.0245)):
        P += barrel_run("bore_" + side, x, 0.020, -0.480, -0.196, 0.0205,
                        nut=False)
    P.append(box("rib", -0.008, 0.008, 0.036, 0.046, -0.470, -0.196,
                 "painted", bevel=0.0015))
    P.append(box("muzzle_plate", -0.050, 0.050, -0.004, 0.044, -0.500,
                 -0.476, "painted", bevel=0.003))
    for side, x in (("l", -0.0245), ("r", 0.0245)):
        P.append(tube("bore_mouth_" + side, 0.0170, 0.0140, 8, x, 0.020,
                      -0.5005, -0.486, "barrel", part="muzzle_plate"))
    for k, (x, y) in enumerate(((-0.044, 0.038), (0.044, 0.038),
                                (-0.044, 0.002), (0.044, 0.002))):
        P.append(hexhead("plate_bolt%d" % k, (x, y, -0.500), "z", -1,
                         0.0028, 0.002, part="plate_bolts"))
    P.append(cyl("mag_tube", 0.0130, 8, 0, -0.016, -0.470, -0.196,
                 "barrel"))
    P += clamp_band("tube_band", 0, -0.016, -0.455, 0.0130, ear_side=-1)
    # the Epsilon charger on top, the core standing in it
    P.append(box("charger", -0.026, 0.026, 0.044, 0.070, -0.190, -0.110,
                 "epsilon", bevel=0.0025))
    P.append(box("charger_fins", -0.020, 0.020, 0.070, 0.074, -0.184,
                 -0.150, "epsilon", part="charger"))
    P += cartridge("core", (-0.012, 0.070, -0.130), (-0.25, 1.0, 0.35),
                   0.034, 0.0095)
    P += lamp("lamp", 0.012, 0.0705, -0.124, "y", 1)
    for k, z in enumerate((-0.184, -0.116)):
        P.append(box("charger_strap%d" % k, -0.0285, 0.0285, 0.040, 0.0735,
                     z - 0.004, z + 0.004, "strap"))
        P.append(hexhead("charger_bolt%d" % k, (-0.0285, 0.048, z), "x",
                         -1, 0.0024, 0.0016, part="charger_strap%d" % k))
    P.append(box("bead", -0.003, 0.003, 0.046, 0.052, -0.470, -0.462,
                 "bare"))
    P += grip("grip", (0.0, -0.040, 0.020), 18, 0.100, 0.0170, 0.0220)
    P.append(sweep("guard", [(0, -0.040, -0.044), (0, -0.068, -0.038),
                             (0, -0.074, -0.014), (0, -0.064, 0.006)],
                   0.0032, 4, "painted"))
    P.append(weld("weld_rib", [(-0.0082, 0.046, -0.198), (0.0, 0.0475,
                                                           -0.199),
                               (0.0082, 0.046, -0.198)]))
    P.append(weld("weld_plate", [(-0.050, 0.044, -0.4755),
                                 (0.0, 0.0455, -0.4752),
                                 (0.050, 0.044, -0.4755)]))
    return P, {"Pump": (_pump(), (0.0, -0.016, -0.371)),
               "Feed": (_feed(), (0.0, -0.110, -0.135))}, {
        "muzzle": (0, 0.02, -0.50), "sights": []}


def bulkhead_b():
    """THE DRUM GUN. One fat bore with a flared choke, fed from a station
    pressure drum with hoop bands: round and heavy where A is flat and
    wide. The Epsilon compressor rides under the drum, the core screwed
    into its side. Same two configurations."""
    P = []
    P += receiver("receiver", -0.090, 0.066, -0.038, 0.042, 0.030,
                  rear_r=0.032, front_ch=0.012, cover=(-0.060, 0.034),
                  housing=(-0.040, 0.050, 0.012, 0.020), ribs=(0.022,))
    P.append(cyl("drum", 0.0470, 8, 0, 0.012, -0.210, -0.090, "painted",
                 bevel=0.004, bevel_pred=fs._across))
    for i, z in enumerate((-0.110, -0.150, -0.190)):
        P += clamp_band("hoop%d" % i, 0, 0.012, z, 0.0472, width=0.009,
                        ear_side=-1 if i != 1 else 1)
    P.append(prism("drum_gauge", ngon(0.0110, 8, -0.150, 0.042), "x",
                   -0.050, -0.040, "bare", bevel=0.0010))
    P.append(prism("drum_gauge_face", ngon(0.0085, 8, -0.150, 0.042), "x",
                   -0.0515, -0.0500, "ceramic", part="drum_gauge"))
    P += barrel_run("bore", 0, 0.020, -0.470, -0.206, 0.0270, nut=True)
    P.append(tube("choke", 0.0340, 0.0200, 8, 0, 0.020, -0.500, -0.470,
                  "barrel", bevel=0.002))
    P.append(cyl("mag_tube", 0.0120, 8, 0, -0.024, -0.450, -0.210,
                 "barrel"))
    P += clamp_band("tube_band", 0, -0.024, -0.440, 0.0120, ear_side=-1)
    P.append(box("compressor", -0.024, 0.024, -0.066, -0.030, -0.200,
                 -0.100, "epsilon", bevel=0.0025))
    P += cartridge("core", (-0.024, -0.048, -0.150), (-1.0, -0.2, 0.25),
                   0.030, 0.0090)
    P += lamp("lamp", -0.0245, -0.036, -0.112, "x", -1)
    P.append(sweep("charge_line", [(0.020, -0.034, -0.190), (0.034, -0.010,
                                                             -0.200),
                                   (0.034, 0.012, -0.205)], 0.0038, 6,
                   "cable"))
    P.append(box("bead", -0.003, 0.003, 0.054, 0.060, -0.468, -0.460,
                 "bare"))
    P += grip("grip", (0.0, -0.038, 0.020), 18, 0.100, 0.0170, 0.0220)
    P.append(sweep("guard", [(0, -0.038, -0.044), (0, -0.066, -0.038),
                             (0, -0.072, -0.014), (0, -0.062, 0.006)],
                   0.0032, 4, "painted"))
    P.append(weld("weld_drum", [(-0.031, 0.040, -0.0905), (-0.040, 0.020,
                                                           -0.0905),
                                (-0.031, -0.020, -0.0905)]))
    return P, {"Pump": (_pump(-0.420, -0.322, -0.024, 0.030),
                        (0.0, -0.024, -0.371)),
               "Feed": (_feed(-0.080, 0.010), (0.0, -0.110, -0.035))}, {
        "muzzle": (0, 0.02, -0.50), "sights": []}


# =========================================================== MASS DRIVER

def driver_a():
    """THE ROTOR DRIVER. A heavy rotor round the line of fire spins up
    inside a station guard cage (Prod's `coils` spin with the charge) and
    dumps its momentum through open twin rails. The mass is in the rotor,
    which is why it barely kicks. The accumulator under it glows with the
    charge (Prod's `core`); the Echo core seats in its end."""
    P = []
    P += receiver("housing", -0.060, 0.080, -0.042, 0.044, 0.034,
                  rear_r=0.034, front_ch=0.012, cover=(-0.014, 0.056),
                  housing=(0.022, 0.074, 0.008, 0.020),
                  panel=(-0.050, 0.030, -0.034, 0.030, "painted"))
    for i, z in enumerate((-0.064, -0.236)):
        P.append(tube("cage_ring%d" % i, 0.0640, 0.0570, 8, 0, 0.0, z - 0.006,
                      z + 0.006, "painted", bevel=0.0010))
    for k in range(4):
        a = math.radians(45 + 90 * k)
        cx, cy = 0.0605 * math.cos(a), 0.0605 * math.sin(a)
        P.append(prism("cage_bar%d" % k, ngon(0.0040, 4, cx, cy, a), "z",
                       -0.236, -0.064, "painted", part="cage"))
        for z in (-0.064, -0.236):
            P.append(hexhead("cage_bolt%d_%d" % (k, int(-z * 1e3)),
                             (cx * 1.07, cy * 1.07, z), "z",
                             1 if z > -0.1 else -1, 0.0022, 0.0014,
                             part="cage_bolts"))
    for side, x in (("l", -0.026), ("r", 0.026)):
        P.append(box("rail_" + side, x - 0.007, x + 0.007, -0.012, 0.012,
                     -0.620, -0.236, "barrel", bevel=0.0015))
    for i, z in enumerate((-0.300, -0.460, -0.600)):
        P.append(box("bridge%d" % i, -0.034, 0.034, 0.012, 0.022, z - 0.010,
                     z + 0.010, "epsilon", bevel=0.0015))
        for side, x in (("l", -0.026), ("r", 0.026)):
            P.append(box("insul%d%s" % (i, side), x - 0.0085, x + 0.0085,
                         -0.016, -0.012, z - 0.008, z + 0.008, "ceramic",
                         bevel=0.0008))
    P.append(box("spine", -0.010, 0.010, -0.030, -0.016, -0.600, -0.236,
                 "painted", bevel=0.0015))
    P.append(box("sight_post", -0.0040, 0.0040, 0.044, 0.114, -0.036,
                 -0.024, "painted", bevel=0.0010))
    P += ring_sight("rear_ring", 0.130, -0.030, 0.0155, 0.114)
    P += ring_sight("front_post", 0.130, -0.585, 0.0050, 0.022)
    P.append(weld("weld_post", [(-0.0042, 0.045, -0.037), (-0.0045, 0.045,
                                                           -0.030),
                                (-0.0042, 0.045, -0.023)]))
    P += lamp("lamp", -0.0345, 0.032, 0.040, "x", -1)
    P += grip("grip", (0.0, -0.042, 0.050), 14, 0.100)
    P.append(sweep("guard", [(0, -0.042, 0.004), (0, -0.068, 0.010),
                             (0, -0.074, 0.032), (0, -0.064, 0.050)],
                   0.0030, 4, "painted"))
    P.append(weld("weld_cage", [(-0.034, 0.030, -0.058), (-0.040, 0.0,
                                                          -0.058),
                                (-0.034, -0.030, -0.058)]))
    R = [tube("rotor", 0.0530, 0.0180, 8, 0, 0.0, -0.225, -0.075, "bare",
              part="coils", bevel=0.002)]
    for k in range(4):
        w = box("weight%d" % k, -0.009, 0.009, 0.048, 0.058, -0.200, -0.100,
                "painted", part="coils")
        rotate(w, (0, 0, 1), 90 * k + 45, (0, 0, 0))
        R.append(w)
    R.append(cyl("rotor_hub", 0.0185, 8, 0, 0.0, -0.232, -0.068,
                 "epsilon", part="coils"))
    A = [cyl("accumulator", 0.0170, 8, 0, -0.062, -0.150, 0.040, "core",
             bevel=0.002)]
    P += cartridge("echo", (0.0, -0.062, 0.040), (0, -0.25, 1.0), 0.026,
                   0.0080)
    for z in (-0.120, 0.010):
        P += clamp_band("acc_band%d" % int(-z * 1000), 0, -0.062, z, 0.0172,
                        width=0.008, ear_side=-1)
    return P, {"Coils": (R, (0.0, 0.0, -0.150)),
               "Core": (A, (0.0, -0.062, -0.055))}, {
        "muzzle": (0, 0.0, -0.62), "sights": [0.13], "orb": (0, 0, -0.40)}


def driver_b():
    """THE COIL DRIVER. Three heavy wound coils in steel cages, spaced
    along twin rails, spin up together (Prod's `coils`): the motion is
    spread down the gun rather than gathered in one rotor. A long, open
    silhouette; the accumulator under the rear glows."""
    P = []
    P += receiver("housing", -0.080, 0.080, -0.040, 0.042, 0.032,
                  rear_r=0.034, front_ch=0.012, cover=(-0.014, 0.056),
                  housing=(0.022, 0.074, 0.008, 0.020), ribs=(-0.060,))
    for side, x in (("l", -0.026), ("r", 0.026)):
        P.append(box("rail_" + side, x - 0.007, x + 0.007, -0.012, 0.012,
                     -0.620, -0.080, "barrel", bevel=0.0015))
    P.append(box("spine", -0.010, 0.010, -0.032, -0.016, -0.600, -0.080,
                 "painted", bevel=0.0015))
    for i, z in enumerate((-0.250, -0.380, -0.510)):
        P.append(box("cradle%d" % i, -0.012, 0.012, -0.052, -0.030,
                     z - 0.014, z + 0.014, "strap", bevel=0.001))
        P.append(hexhead("cradle_bolt%d" % i, (-0.012, -0.041, z), "x", -1,
                         0.0024, 0.0016, part="cradle%d" % i))
    P.append(box("sight_post", -0.0040, 0.0040, 0.042, 0.114, -0.036,
                 -0.024, "painted", bevel=0.0010))
    P += ring_sight("rear_ring", 0.130, -0.030, 0.0155, 0.114)
    P += ring_sight("front_post", 0.130, -0.590, 0.0050, 0.012)
    P += lamp("lamp", -0.0325, 0.030, 0.040, "x", -1)
    P += grip("grip", (0.0, -0.040, 0.050), 14, 0.100)
    P.append(sweep("guard", [(0, -0.040, 0.004), (0, -0.066, 0.010),
                             (0, -0.072, 0.032), (0, -0.062, 0.050)],
                   0.0030, 4, "painted"))
    R = []
    for i, z in enumerate((-0.250, -0.380, -0.510)):
        R.append(tube("coil%d" % i, 0.0450, 0.0330, 8, 0, 0.0, z - 0.020,
                      z + 0.020, "ceramic", part="coils", bevel=0.0015))
        for j, dz in enumerate((-0.0215, 0.0215)):
            R.append(tube("coil_cage%d%d" % (i, j), 0.0480, 0.0300, 8, 0,
                          0.0, z + dz - 0.0025, z + dz + 0.0025, "bare",
                          part="coils"))
        for k in range(4):
            t = box("coil_tie%d%d" % (i, k), -0.003, 0.003, 0.044, 0.050,
                    z - 0.024, z + 0.024, "bare", part="coils")
            rotate(t, (0, 0, 1), 90 * k + 45, (0, 0, 0))
            R.append(t)
        R.append(box("coil_tab%d" % i, -0.004, 0.004, 0.044, 0.056,
                     z - 0.010, z + 0.010, "epsilon", part="coils"))
    A = [cyl("accumulator", 0.0180, 8, 0, -0.064, -0.180, 0.040, "core",
             bevel=0.002)]
    P += cartridge("echo", (0.0, -0.064, 0.040), (0, -0.25, 1.0), 0.026,
                   0.0080)
    for z in (-0.150, 0.010):
        P += clamp_band("acc_band%d" % int(-z * 1000), 0, -0.064, z, 0.0182,
                        width=0.008, ear_side=-1)
    return P, {"Coils": (R, (0.0, 0.0, -0.380)),
               "Core": (A, (0.0, -0.064, -0.070))}, {
        "muzzle": (0, 0.0, -0.62), "sights": [0.13], "orb": (0, 0, -0.40)}


PROPOSALS = {
    "sightline_a": ("Sightline", "A  Accelerator rifle", sightline_a),
    "sightline_b": ("Sightline", "B  Reservoir rifle", sightline_b),
    "switchback_a": ("Switchback", "A  Jacketed carbine", switchback_a),
    "switchback_b": ("Switchback", "B  Pan gun", switchback_b),
    "bulkhead_a": ("Bulkhead", "A  Twin-bore breacher", bulkhead_a),
    "bulkhead_b": ("Bulkhead", "B  Drum gun", bulkhead_b),
    "driver_a": ("Mass Driver", "A  Rotor driver", driver_a),
    "driver_b": ("Mass Driver", "B  Coil driver", driver_b),
}


def foundry_reference():
    """THE APPROVED FOUNDRY, in the same clay and at the same scale, so the
    lineup compares the four proposals against the benchmark. Built from
    the study's own source (build_foundry_study.build); rendered only."""
    P, hammer = fs.build()
    static = list(P.values())
    return static, {"Hammer": (hammer, (0.0, 0.052, -0.022))}, \
        {"muzzle": fs.MUZZLE, "sights": []}


#: rendered beside the proposals, never exported as one
REFERENCES = {
    "foundry": ("Foundry", "Approved benchmark", foundry_reference),
}

# ------------------------------------------------------------ the clay

CLAY = {  # flat material tints, so material character reads in clay
    "painted": ("#4b525a", 0.62), "bare": ("#33373c", 0.40),
    "barrel": ("#2b2e33", 0.42), "epsilon": ("#141517", 0.30),
    "ceramic": ("#aea795", 0.80), "core": ("#262833", 0.12),
    "tape": ("#6f6656", 0.88), "cable": ("#3a3d40", 0.50),
    "patch": ("#5e4434", 0.70), "fastener": ("#7a7e82", 0.40),
    "lamp": ("#57ff1f", 0.10), "strap": ("#45484b", 0.55),
    "rubber": ("#151515", 0.85),
}
_CLAY_BY_ID = {v: k for k, v in fs.CLASSES.items()}


def clay_material(cls_name):
    name = "clay_" + cls_name
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    hexc, rough = CLAY[cls_name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    rgb = [int(hexc[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
           for c in rgb]
    bsdf.inputs["Base Color"].default_value = lin + [1.0]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0
    if cls_name == "lamp":
        bsdf.inputs["Emission Color"].default_value = lin + [1.0]
        bsdf.inputs["Emission Strength"].default_value = 4.0
    mat.use_backface_culling = True
    return mat


def dress(objs):
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(clay_material(_CLAY_BY_ID[o["cls"]]))
        for poly in o.data.polygons:
            poly.use_smooth = False


def build(key):
    """Build a proposal: Body plus its runtime nodes, all dressed."""
    common.reset_scene()
    fs.PARTS.clear()
    static, moving, meta = {**PROPOSALS, **REFERENCES}[key][2]()
    dress(static + [o for parts, _ in moving.values() for o in parts])
    body = common.join(static, "Body")
    nodes = {}
    for name, (parts, pivot) in moving.items():
        obj = common.join(parts, name)
        fs._pivot(obj, pivot)
        nodes[name] = obj
    muzzle = node("Muzzle", meta["muzzle"])
    return body, nodes, muzzle, meta


# ------------------------------------------------------------ the views

#: one scale for every left elevation, so sizes compare across the family
SIDE_ORTHO = 1.05
SIDE_CENTRE = (-0.27, -0.02)          # (z, y) the camera looks at


def _scene_setup():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.seed = 3
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (
        0.20, 0.21, 0.23, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    scene.world = world
    for i, (e, rot) in enumerate(((3.2, (40, -20, 30)),
                                  (1.4, (55, 25, -150)),
                                  (0.8, (-60, 0, 90)))):
        sun = bpy.data.objects.new("sun%d" % i,
                                   bpy.data.lights.new("sun%d" % i, "SUN"))
        sun.data.energy = e
        sun.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


G2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def _look_at(eye, target):
    e, t = Vector(eye), Vector(target)
    f = (t - e).normalized()
    r = f.cross(Vector((0, 1, 0))).normalized()
    u = r.cross(f)
    return Matrix(((r.x, u.x, -f.x, e.x), (r.y, u.y, -f.y, e.y),
                   (r.z, u.z, -f.z, e.z), (0, 0, 0, 1)))


def render_views(out, label):
    scene, cam = _scene_setup()
    views = {
        "side": ("ORTHO", Matrix.Translation(Vector(
            (-0.9, SIDE_CENTRE[1], SIDE_CENTRE[0]))) @ Matrix.Rotation(
            math.radians(-90), 4, "Y"), SIDE_ORTHO, (1600, 760)),
        "eye": ("PERSP", fs._rig_matrix().inverted(), 75.0, (1600, 900)),
        "three_q": ("PERSP", _look_at((-0.34, 0.22, 0.26),
                                      (0.0, -0.01, -0.22)), 34.0,
                    (1600, 900)),
    }
    for name, (kind, m, lens, res) in views.items():
        scene.render.resolution_x, scene.render.resolution_y = res
        cam.data.type = kind
        if kind == "ORTHO":
            cam.data.ortho_scale = lens
        else:
            cam.data.sensor_fit = "VERTICAL"
            cam.data.angle_y = math.radians(lens)
        cam.data.clip_start = 0.01
        cam.matrix_world = G2B @ m
        scene.render.filepath = os.path.join(out, name + ".png")
        bpy.ops.render.render(write_still=True)


def export_glb(body, nodes, muzzle, path):
    objs = [body] + list(nodes.values())
    fs.triangulate(objs)
    root = bpy.data.objects.new("WeaponForm", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs + [muzzle]:
        o.parent = root
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs + [muzzle, root]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                              use_selection=True, export_apply=False,
                              export_materials="EXPORT", export_yup=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = os.path.abspath(argv[0])
    only = argv[1:] or list(PROPOSALS)
    record = {}
    if os.path.exists(os.path.join(out, "forms.json")):
        record = json.load(open(os.path.join(out, "forms.json")))
    for key in only:
        weapon, label, _ = {**PROPOSALS, **REFERENCES}[key]
        body, nodes, muzzle, meta = build(key)
        if key in REFERENCES:
            d = os.path.join(out, key)
            os.makedirs(d, exist_ok=True)
            render_views(d, label)
            continue
        tris = fs.triangles([body] + list(nodes.values()))
        d = os.path.join(out, key)
        os.makedirs(d, exist_ok=True)
        render_views(d, label)
        export_glb(body, nodes, muzzle, os.path.join(d, key + ".glb"))
        record[key] = {"weapon": weapon, "label": label, "triangles": tris,
                       "nodes": {n: list(map(lambda v: round(v, 4),
                                             (o.location.x, o.location.z,
                                              -o.location.y)))
                                 for n, o in nodes.items()},
                       "muzzle": list(meta["muzzle"]),
                       "sight_lines_y": meta["sights"]}
        common.log("%-14s %-24s %4d tris" % (key, label, tris))
    with open(os.path.join(out, "forms.json"), "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")


if __name__ == "__main__":
    main()
