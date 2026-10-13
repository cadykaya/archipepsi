"""The Bulkhead, revisited: three new concept forms. (Arty, 2026-10-13.)
NOT FINAL MODELS. For the owner's review before the Bulkhead's form counts
as approved.

    .tools/blender/blender -b --python tools/blender/build_bulkhead_concepts.py \
        -- OUT [bulkhead_c bulkhead_d bulkhead_e]

Same output as `build_weapon_forms.py` (whose kit, clay, views and GLB
export it reuses): OUT/<key>/{side,three_q,eye}.png, OUT/<key>/<key>.glb,
and entries in OUT/forms.json.

THE BRIEF (the owner, 2026-10-13, on forms A and B): "too blocky and
visually generic ... something more distinctive and interesting, not
simply a conventional shotgun with futuristic parts attached." Revisit the
proportions, the silhouette and how the mechanism is presented; keep the
Breacher (pump) and the Sweeper (feed) on one body.

So none of these starts from a receiver box with tubes on the front. Each
starts from a piece of station equipment whose job is to open a bulkhead,
and the gun is what a crew made of it:

  C  SPREADER   a hydraulic rescue spreader. A fat cast ram body; two
                forged jaws splayed a few degrees, a bore in each -- the
                spread is visible in the shape. An Epsilon ram between
                the jaws; the Breacher's pump re-pressurises it.
  D  FAN        a debris-clearing manifold. One cast block widening
                forward, four short bores fanned out of its face like a
                duck's-foot pistol; an Epsilon distributor on top sends one
                charge down four cables. The Sweeper loads a flat
                four-shell cassette, one shell per bore.
  E  HATCH RAM  a powder-actuated stud driver. A short, very thick ram
                sleeve ending in a breaching crown with standoff claws;
                the Breacher's pump IS the sleeve's collar; disc charges
                stack in a slotted tower over the breech.

Runtime fit (Prod's review/five-weapons-v3, unchanged): `Pump` slides
100 mm back at 0.72 s (Breacher), `Feed` is shown for the Sweeper only,
`Muzzle` at (0, 0.02, -0.50), no ADS.
"""

from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_weapon_forms as wf  # noqa: E402
from build_foundry_study import (box, cyl, hexhead, hull, loft,  # noqa: E402
                                 ngon, oct_ring, prism, sweep, tube)
from build_weapon_forms import (cartridge, clamp_band, grip, lamp,  # noqa
                                side_panel, weld)

X, Y = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)
MUZZLE = (0.0, 0.02, -0.50)


# --------------------------------------------------------------- helpers

def cast(name, stations, cls="painted", n=8, part=None):
    """A cast body lofted along Z: stations are (z, cx, cy, hw, hh)."""
    return loft(name, [oct_ring((cx, cy, z), X, Y, hw, hh, n)
                       for z, cx, cy, hw, hh in stations], cls, part=part)


def bore(name, a, b, r, cls="barrel", mouth=True, part=None, via=()):
    """A barrel from `a` (through `via`) to `b`, a reinforced mouth at `b`
    and the dark of the bore in it."""
    out = [sweep(name, [a, *via, b], r, 8, cls, part=part)]
    a = via[-1] if via else a
    if mouth:
        d = [b[i] - a[i] for i in range(3)]
        L = math.sqrt(sum(c * c for c in d))
        u = [c / L for c in d]
        m0 = tuple(b[i] - u[i] * 0.016 for i in range(3))
        m1 = tuple(b[i] + u[i] * 0.001 for i in range(3))
        out.append(sweep(name + "_mouth", [m0, m1], r + 0.0028, 8, "bare",
                         part=part or name + "_mouth"))
        e0 = tuple(b[i] + u[i] * 0.0005 for i in range(3))
        e1 = tuple(b[i] + u[i] * 0.0016 for i in range(3))
        out.append(sweep(name + "_dark", [e0, e1], r * 0.72, 8, "rubber",
                         part=part or name + "_dark"))
    return out


def along(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def collar(name, a, b, t, r, w=0.008, cls="strap", part=None):
    """A short ring clamped round a barrel at fraction t of a->b."""
    d = [b[i] - a[i] for i in range(3)]
    L = math.sqrt(sum(c * c for c in d))
    u = [c / L for c in d]
    c = along(a, b, t)
    return sweep(name, [tuple(c[i] - u[i] * w / 2 for i in range(3)),
                        tuple(c[i] + u[i] * w / 2 for i in range(3))],
                 r, 8, cls, part=part or name)


def guard(y_top=-0.040):
    return sweep("guard", [(0, y_top, -0.044), (0, y_top - 0.028, -0.038),
                           (0, y_top - 0.034, -0.014),
                           (0, y_top - 0.024, 0.006)], 0.0032, 4, "painted")


def pump_sleeve(z0, z1, cy, r, rod=True, rod_z=None):
    """The Breacher's pump: a ribbed sleeve on a rod. Returns (static rod
    pieces, pump pieces, pivot)."""
    static = []
    if rod:
        rz0, rz1 = rod_z or (z0 - 0.02, z1 + 0.10)
        static.append(cyl("pump_rod", 0.0075, 8, 0.0, cy, rz0, rz1, "bare"))
    pump = [cyl("pump_sleeve", r, 8, 0.0, cy, z0, z1, "tape", part="pump",
                bevel=0.0025)]
    n = 5
    for k in range(n):
        z = z0 + 0.010 + (z1 - z0 - 0.020) * k / (n - 1)
        pump.append(tube("pump_rib%d" % k, r + 0.0018, r - 0.002, 8, 0.0,
                         cy, z - 0.0025, z + 0.0025, "rubber", part="pump"))
    for k, z in enumerate((z0 + 0.003, z1 - 0.003)):
        pump.append(tube("pump_end%d" % k, r + 0.0012, 0.0080, 8, 0.0, cy,
                         z - 0.003, z + 0.003, "strap", part="pump"))
    return static, pump, (0.0, cy, (z0 + z1) / 2)


def shell_rims(name, x, cy, cz, n, pitch, axis_sign=-1, r=0.0085,
               vertical=True, part=None):
    """Shotshell heads seen through a feed's window: short rims proud of
    a face at x, stacked in y (or z)."""
    out = []
    for k in range(n):
        y = cy + (k - (n - 1) / 2) * pitch if vertical else cy
        z = cz if vertical else cz + (k - (n - 1) / 2) * pitch
        xa, xb = sorted((x, x + axis_sign * 0.0015))
        out.append(prism("%s_rim%d" % (name, k), ngon(r, 8, z, y), "x", xa,
                         xb, "bare", part=part or name + "_rims"))
        xa, xb = sorted((x + axis_sign * 0.0015, x + axis_sign * 0.0022))
        out.append(prism("%s_primer%d" % (name, k), ngon(r * 0.32, 6, z, y),
                         "x", xa, xb, "fastener",
                         part=part or name + "_rims"))
    return out


# ============================================================ C SPREADER

def bulkhead_c():
    """THE SPREADER. A station hydraulic rescue spreader -- the tool that
    opens jammed bulkheads -- made into a gun. A fat cast ram body behind;
    two forged jaws splayed five degrees, a bore in each, so the spread is
    in the silhouette; the Epsilon ram sits between the jaws on links. The
    Breacher's pump re-pressurises the ram; the Sweeper clamps a shell box
    to the body's left, the shell heads in its window."""
    P = []
    cy = 0.006
    P.append(cast("body", [(0.040, 0, cy, 0.036, 0.036),
                           (-0.166, 0, cy, 0.036, 0.036)], n=12))
    # bolted end cap and front flange: a hydraulic cylinder, built
    for nm, z0, z1 in (("cap", 0.040, 0.056), ("flange", -0.178, -0.164)):
        P.append(cast(nm, [(z0, 0, cy, 0.0405, 0.0405),
                           (z1, 0, cy, 0.0405, 0.0405)], "bare", n=12))
        zf = z1 if nm == "cap" else z0
        for k in range(8):
            a = math.pi / 8 + k * math.pi / 4
            P.append(hexhead("%s_bolt%d" % (nm, k), (0.034 * math.cos(a),
                                                     cy + 0.034 *
                                                     math.sin(a), zf),
                             "z", 1 if nm == "cap" else -1, 0.0028, 0.0020,
                             part=nm + "_bolts"))
    P.append(hexhead("end_nut", (0.0, cy, 0.056), "z", 1, 0.010, 0.006,
                     part="end_nut"))
    P.append(cyl("end_boss", 0.005, 8, 0.0, cy, 0.062, 0.068, "bare"))
    # a stiffening saddle under the valve, welded on
    P.append(box("saddle", -0.026, 0.026, 0.030, 0.042, -0.120, -0.028,
                 "painted", bevel=0.0012))
    P.append(weld("weld_saddle", [(-0.026, 0.031, -0.118),
                                  (-0.027, 0.031, -0.074),
                                  (-0.026, 0.031, -0.030)]))
    for i, z in enumerate((-0.012, -0.126)):
        P += clamp_band("hoop%d" % i, 0.0, cy, z, 0.0372, width=0.008,
                        ear_side=-1)
    # a cast-in name boss and a service plate on the left
    P += side_panel("body_panel", -0.0352, -0.104, -0.034, -0.016, 0.022,
                    -1, "patch")
    # the Epsilon valve block on top; the core stands in it, toward the eye
    P.append(box("valve", -0.020, 0.020, 0.044, 0.062, -0.112, -0.036,
                 "epsilon", bevel=0.0025))
    P.append(box("valve_seat", -0.024, 0.024, 0.040, 0.046, -0.116,
                 -0.032, "bare", bevel=0.0010))
    P += cartridge("core", (-0.006, 0.062, -0.064), (-0.25, 1.0, 0.45),
                   0.036, 0.0095)
    P += lamp("lamp", 0.010, 0.0625, -0.098, "y", 1)
    # pressure hose from the valve forward to the ram
    P.append(sweep("hose", [(0.016, 0.050, -0.112), (0.022, 0.050, -0.150),
                            (0.016, 0.040, -0.190), (0.008, 0.032, -0.205)],
                   0.0042, 6, "cable"))
    # the yoke that carries the jaw pins
    P.append(box("yoke_top", -0.044, 0.044, 0.046, 0.054, -0.214, -0.170,
                 "painted", bevel=0.0018))
    P.append(box("yoke_bot", -0.044, 0.044, -0.014, -0.006, -0.214, -0.170,
                 "painted", bevel=0.0018))
    P.append(box("yoke_web", -0.030, 0.030, -0.006, 0.046, -0.192, -0.176,
                 "painted"))
    P.append(weld("weld_yoke", [(-0.034, 0.045, -0.170), (0.0, 0.0465,
                                                          -0.169),
                                (0.034, 0.045, -0.170)]))
    jaws = []
    for sx in (-1, 1):
        root = (sx * 0.022, 0.020, -0.192)
        a = math.radians(9.0)
        L = 0.292
        tip = (root[0] + sx * L * math.sin(a), 0.020, root[2] - L *
               math.cos(a))
        u = (sx * math.sin(a), 0.0, -math.cos(a))

        def at(t, root=root, u=u):
            return tuple(root[i] + u[i] * t for i in range(3))
        n = (math.cos(a), 0.0, sx * math.sin(a))        # across the jaw
        side = "l" if sx < 0 else "r"
        rings = [oct_ring(at(t), n, Y, hw, hh, 8) for t, hw, hh in
                 ((0.0, 0.018, 0.036), (0.05, 0.018, 0.036),
                  (0.16, 0.015, 0.027), (0.25, 0.0135, 0.021))]
        # the beak: the last length turns back toward the line of fire
        b0 = at(0.25)
        ain = math.radians(-9.0)
        ub = (sx * math.sin(a + ain), 0.0, -math.cos(a + ain))
        for t, hw, hh in ((0.030, 0.0125, 0.019), (0.046, 0.0105, 0.015)):
            c = tuple(b0[i] + ub[i] * t for i in range(3))
            rings.append(oct_ring(c, n, Y, hw, hh, 8))
        jaws.append(loft("jaw_" + side, rings, "painted"))
        # a forged web along the jaw's outer face
        P.append(sweep("web_" + side, [
            tuple(at(0.02)[i] + n[i] * sx * 0.017 for i in range(3)),
            tuple(at(0.22)[i] + n[i] * sx * 0.0135 for i in range(3))],
            0.0050, 4, "painted", part="webs"))
        tip_b = tuple(b0[i] + ub[i] * 0.050 for i in range(3))
        P += bore("bore_" + side, at(0.10), tip_b, 0.0098, via=(b0,))
        # the breaching teeth on the jaw's outer face
        for k in range(3):
            t = 0.170 + 0.020 * k
            c = at(t)
            o = sx * 0.0155
            pts = []
            for dy in (-0.006, 0.006):
                pts += [(c[0] + o, c[1] + dy - 0.012, c[2] + 0.006),
                        (c[0] + o, c[1] + dy - 0.012, c[2] - 0.006),
                        (c[0] + o + sx * 0.007, c[1] + dy - 0.012, c[2]
                         - 0.002)]
            for dy in (-0.009, 0.009):
                pts += [(c[0] + o, c[1] + dy, c[2] + 0.006),
                        (c[0] + o, c[1] + dy, c[2] - 0.006),
                        (c[0] + o + sx * 0.007, c[1] + dy, c[2] - 0.002)]
            P.append(hull("tooth_%s%d" % (side, k), pts, "bare",
                          part="teeth"))
        # jaw pins through the yoke
        P.append(cyl("pin_" + side, 0.0065, 8, root[0], 0.0, -0.200,
                     -0.184, "bare"))
        P.append(prism("pinhead_" + side, ngon(0.0075, 6, root[0], -0.192),
                       "y", 0.054, 0.058, "fastener", part="pins"))
        P.append(prism("pinfoot_" + side, ngon(0.0075, 6, root[0], -0.192),
                       "y", -0.018, -0.014, "fastener", part="pins"))
        # links from the ram's crosshead to the jaw
        P.append(sweep("link_" + side, [(sx * 0.010, 0.020, -0.302),
                                        at(0.17)], 0.0040, 6, "bare"))
        # a clamp ring on each bore near the mouth
        P.append(collar("jawring_" + side, at(0.0), at(L), 0.80, 0.0150))
    P += jaws
    # the Epsilon ram between the jaws, on its crosshead
    P.append(cyl("ram", 0.0150, 8, 0.0, 0.020, -0.300, -0.192, "epsilon",
                 bevel=0.0015))
    P.append(cyl("ram_rod", 0.0075, 8, 0.0, 0.020, -0.312, -0.298, "bare"))
    P.append(box("crosshead", -0.016, 0.016, 0.010, 0.030, -0.322, -0.308,
                 "bare", bevel=0.0012))
    for k, z in enumerate((-0.270, -0.226)):
        P.append(tube("ram_coil%d" % k, 0.0175, 0.0148, 8, 0.0, 0.020,
                      z - 0.006, z + 0.006, "ceramic"))
    P += grip("grip", (0.0, -0.034, 0.022), 18, 0.100, 0.0170, 0.0220)
    P.append(guard(-0.034))
    rod, pump, pivot = pump_sleeve(-0.300, -0.214, -0.058, 0.0150,
                                   rod_z=(-0.312, -0.112))
    P += rod
    P.append(box("rod_hanger", -0.006, 0.006, -0.058, -0.030, -0.126,
                 -0.112, "painted"))
    P.append(box("rod_hanger_f", -0.006, 0.006, -0.058, -0.012, -0.318,
                 -0.306, "painted"))
    # Sweeper: a shell box clamped to the body's left, heads in a window
    feed = [box("feed_box", -0.078, -0.042, -0.034, 0.030, -0.150, -0.050,
                "painted", part="feed", bevel=0.0025),
            box("feed_window", -0.0795, -0.078, -0.026, 0.022, -0.118,
                -0.098, "rubber", part="feed")]
    feed += shell_rims("feed_shell", -0.0795, -0.002, -0.108, 3, 0.017,
                       part="feed")
    for k, z in enumerate((-0.140, -0.060)):
        feed.append(box("feed_strap%d" % k, -0.080, -0.036, -0.036, 0.032,
                        z - 0.003, z + 0.003, "strap", part="feed"))
    feed.append(weld("feed_weld", [(-0.042, 0.030, -0.146),
                                   (-0.040, 0.031, -0.100),
                                   (-0.042, 0.030, -0.054)]))
    return P, {"Pump": (pump, pivot),
               "Feed": (feed, (-0.060, 0.0, -0.100))}, {
        "muzzle": MUZZLE, "sights": []}


# ================================================================ D FAN

def bulkhead_d():
    """THE FAN. A debris-clearing manifold: one cast block that widens
    toward the front, four short bores fanned out of its face like a
    duck's-foot pistol -- seen from the eye, a spread hand. An Epsilon
    distributor on the block sends one charge down four cables, one to each
    breech. The Breacher pumps a slide hung under the fan; the Sweeper
    loads a flat four-shell cassette, one shell for each bore."""
    P = []
    P.append(cast("manifold", [(0.044, 0, 0.004, 0.020, 0.026),
                               (0.030, 0, 0.004, 0.028, 0.034),
                               (-0.060, 0, 0.006, 0.034, 0.036),
                               (-0.170, 0, 0.012, 0.062, 0.030),
                               (-0.214, 0, 0.016, 0.074, 0.026),
                               (-0.226, 0, 0.016, 0.070, 0.022)]))
    # cast ribs fanning across the block's top, toward each bore
    for k, x0 in enumerate((-0.045, -0.015, 0.015, 0.045)):
        P.append(sweep("rib%d" % k, [(x0 * 0.25, 0.040, -0.060),
                                     (x0 * 0.85, 0.036, -0.180),
                                     (x0, 0.034, -0.218)], 0.0035, 4,
                       "painted", part="ribs"))
    # the breech block: the fan loads from behind, the block hinged below
    # and held shut by a latch lever across its top
    P.append(box("breech_block", -0.030, 0.030, -0.026, 0.036, 0.020,
                 0.052, "bare", bevel=0.0030))
    P.append(cyl("hinge", 0.0060, 8, 0.0, -0.026, 0.024, 0.048, "bare"))
    P.append(prism("hinge_pin", ngon(0.0065, 8, 0.036, -0.026), "x",
                   -0.033, 0.033, "fastener", part="hinge"))
    P.append(sweep("latch", [(0.024, 0.042, 0.046), (0.0, 0.046, 0.044),
                             (-0.026, 0.044, 0.030), (-0.034, 0.036,
                                                      0.012)],
                   0.0034, 6, "bare", part="latch"))
    P.append(cyl("latch_knob", 0.0060, 8, 0.024, 0.042, 0.040, 0.052,
                 "rubber", part="latch"))
    P.append(box("latch_keeper", -0.040, -0.030, 0.026, 0.040, 0.006,
                 0.018, "painted", bevel=0.0010))
    # the face plate the bores are threaded into
    P.append(box("face", -0.076, 0.076, -0.006, 0.040, -0.234, -0.222,
                 "bare", bevel=0.0018))
    for k, x in enumerate((-0.060, 0.060)):
        for j, y in enumerate((-0.001, 0.033)):
            x = x * 1.10 if j == 0 else x
            P.append(hexhead("face_bolt%d%d" % (k, j), (x, y, -0.234), "z",
                             -1, 0.0030, 0.0022, part="face_bolts"))
    roots = (-0.045, -0.015, 0.015, 0.045)
    angs = (-15.0, -5.0, 5.0, 15.0)
    tips = []
    for k, (x0, a) in enumerate(zip(roots, angs)):
        ar = math.radians(a)
        L = 0.248
        r0 = (x0, 0.020, -0.234)
        t = (x0 + L * math.sin(ar), 0.020, -0.234 - L * math.cos(ar))
        tips.append(t)
        P += bore("bore%d" % k, r0, t, 0.0110)
        P.append(collar("bore_nut%d" % k, r0, t, 0.03, 0.0150, w=0.012,
                        cls="bare"))
        P.append(collar("bore_band%d" % k, r0, t, 0.53, 0.0138))
    # the bridge that holds the fan's spacing, welded to each band
    zb = -0.234 - 0.248 * 0.53 * math.cos(math.radians(5))
    xb = 0.045 + 0.248 * 0.53 * math.sin(math.radians(15)) + 0.016
    P.append(box("bridge", -xb, xb, 0.003, 0.009, zb - 0.010, zb + 0.010,
                 "painted", bevel=0.0012))
    P.append(box("bridge_top", -xb + 0.010, xb - 0.010, 0.031, 0.037,
                 zb - 0.008, zb + 0.008, "painted", bevel=0.0010))
    P.append(weld("weld_bridge", [(-xb + 0.012, 0.0095, zb + 0.010),
                                  (0.0, 0.0105, zb + 0.0105),
                                  (xb - 0.012, 0.0095, zb + 0.010)]))
    # the Epsilon distributor on top: one charge, four cables
    P.append(box("distributor", -0.026, 0.026, 0.044, 0.062, -0.150,
                 -0.070, "epsilon", bevel=0.0030))
    P.append(box("dist_seat", -0.030, 0.030, 0.038, 0.045, -0.156, -0.064,
                 "bare", bevel=0.0010))
    P += cartridge("core", (0.0, 0.062, -0.090), (-0.2, 1.0, 0.5), 0.036,
                   0.0095)
    P += lamp("lamp", -0.014, 0.0625, -0.136, "y", 1)
    for k, x0 in enumerate(roots):
        P.append(sweep("charge_line%d" % k, [
            (x0 * 0.4, 0.052, -0.150), (x0 * 0.8, 0.050, -0.190),
            (x0, 0.036, -0.214), (x0, 0.032, -0.226)], 0.0030, 6, "cable"))
    P += grip("grip", (0.0, -0.034, 0.022), 18, 0.100, 0.0170, 0.0220)
    P.append(guard(-0.034))
    # the Breacher's slide, hung under the fan from the face and the bridge
    rod, pump, pivot = pump_sleeve(-0.344, -0.262, -0.050, 0.0135,
                                   rod_z=(-0.362, -0.160))
    P += rod
    P.append(box("hanger_f", -0.005, 0.005, -0.050, 0.004, zb - 0.006,
                 zb + 0.006, "painted"))
    P.append(box("hanger_r", -0.006, 0.006, -0.054, -0.020, -0.172,
                 -0.158, "painted"))
    # Sweeper: a flat four-shell cassette under the manifold
    feed = [box("cassette", -0.040, 0.040, -0.074, -0.030, -0.150, -0.090,
                "painted", part="feed", bevel=0.0025),
            box("cassette_lip", -0.042, 0.042, -0.034, -0.026, -0.154,
                -0.086, "strap", part="feed")]
    for k, x in enumerate((-0.027, -0.009, 0.009, 0.027)):
        feed.append(prism("cassette_rim%d" % k, ngon(0.0075, 8, x, -0.052),
                          "z", -0.0895, -0.0880, "bare", part="feed"))
        feed.append(prism("cassette_primer%d" % k,
                          ngon(0.0025, 6, x, -0.052), "z", -0.0880,
                          -0.0874, "fastener", part="feed"))
    return P, {"Pump": (pump, pivot),
               "Feed": (feed, (0.0, -0.052, -0.120))}, {
        "muzzle": MUZZLE, "sights": []}


# ========================================================== E HATCH RAM

def bulkhead_e():
    """THE HATCH RAM. A powder-actuated stud driver -- the tool that pins
    plates to a hull -- grown into a breaching gun. A short, very thick ram
    sleeve ends in a breaching crown with four standoff claws: you set it
    against a door. The Breacher's pump IS the sleeve's collar, dragged
    back to reseat the ram; disc charges stack in a slotted tower over the
    breech, the Epsilon kick-coils ring the ram's root. The Sweeper feeds
    a belt of discs from a box on the left."""
    P = []
    P.append(cast("body", [(0.046, 0, 0.012, 0.018, 0.034),
                           (0.034, 0, 0.012, 0.026, 0.044),
                           (-0.130, 0, 0.012, 0.028, 0.046),
                           (-0.150, 0, 0.016, 0.034, 0.040),
                           (-0.160, 0, 0.018, 0.036, 0.036)]))
    P.append(box("body_spine", -0.006, 0.006, 0.056, 0.062, -0.128, 0.030,
                 "painted", bevel=0.0012))
    # the firing plunger's rubber cap and its cocking ring, at the back
    P.append(cyl("plunger_ring", 0.0300, 8, 0.0, 0.012, 0.040, 0.052,
                 "bare", bevel=0.0015))
    P.append(cyl("plunger_cap", 0.0255, 8, 0.0, 0.012, 0.052, 0.074,
                 "rubber", bevel=0.0040))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        P.append(hexhead("plunger_bolt%d" % k, (0.024 * math.cos(a), 0.012
                                                + 0.024 * math.sin(a),
                                                0.052), "z", 1, 0.0024,
                         0.0016, part="plunger_bolts"))
    P += side_panel("body_panel", -0.0265, -0.110, -0.040, -0.020, 0.030,
                    -1, "patch")
    # the ram sleeve: thick, short, octagonal, slotted for the collar keys
    P.append(cyl("sleeve", 0.0340, 8, 0.0, 0.020, -0.444, -0.156,
                 "painted", bevel=0.0020))
    for k, z in enumerate((-0.420, -0.172)):
        P.append(tube("sleeve_ring%d" % k, 0.0370, 0.0330, 8, 0.0, 0.020,
                      z - 0.006, z + 0.006, "bare", bevel=0.0008))
    P.append(box("sleeve_key", -0.004, 0.004, 0.052, 0.057, -0.410, -0.180,
                 "bare"))
    # the Epsilon kick-coils at the ram's root
    for k, z in enumerate((-0.190, -0.206, -0.222)):
        P.append(tube("kick_coil%d" % k, 0.0392, 0.0336, 8, 0.0, 0.020,
                      z - 0.005, z + 0.005, "epsilon"))
    P.append(sweep("coil_lead", [(-0.030, 0.040, -0.150),
                                 (-0.036, 0.046, -0.180),
                                 (-0.036, 0.046, -0.206)], 0.0030, 6,
                   "cable"))
    # the crown and its claws, and the ram's face inside it
    P.append(tube("crown", 0.0480, 0.0230, 8, 0.0, 0.020, -0.474, -0.444,
                  "bare", bevel=0.0020))
    P.append(tube("crown_lip", 0.0520, 0.0300, 8, 0.0, 0.020, -0.494,
                  -0.474, "bare", bevel=0.0015))
    P.append(cyl("ram_face", 0.0200, 8, 0.0, 0.020, -0.480, -0.452,
                 "barrel"))
    P.append(cyl("ram_bore", 0.0110, 8, 0.0, 0.020, -0.4815, -0.4795,
                 "rubber"))
    for k in range(4):
        a = math.radians(45 + 90 * k)
        cx, cy = 0.040 * math.cos(a), 0.020 + 0.040 * math.sin(a)
        ox, oy = math.cos(a), math.sin(a)
        pts = []
        for w in (-0.006, 0.006):
            px, py = -oy * w, ox * w
            pts += [(cx + px - ox * 0.006, cy + py - oy * 0.006, -0.494),
                    (cx + px + ox * 0.008, cy + py + oy * 0.008, -0.494),
                    (cx + px - ox * 0.002, cy + py - oy * 0.002, -0.512),
                    (cx + px + ox * 0.003, cy + py + oy * 0.003, -0.508)]
        P.append(hull("claw%d" % k, pts, "bare", part="claws"))
    for k in range(4):
        a = math.radians(90 * k)
        P.append(hexhead("crown_bolt%d" % k, (0.042 * math.cos(a), 0.020
                                              + 0.042 * math.sin(a),
                                              -0.494), "z", -1, 0.0030,
                         0.0020, part="crown_bolts"))
    # the charge tower: discs stacked in a slotted frame over the breech
    P.append(box("tower_back", -0.017, 0.017, 0.058, 0.098, -0.072,
                 -0.066, "painted"))
    for sx in (-1, 1):
        P.append(box("tower_side%d" % (sx > 0), sx * 0.017 - 0.003,
                     sx * 0.017 + 0.003, 0.058, 0.098, -0.110, -0.066,
                     "painted", bevel=0.0008))
    P.append(box("tower_cap", -0.020, 0.020, 0.098, 0.104, -0.112, -0.064,
                 "painted", bevel=0.0012))
    P.append(hexhead("tower_screw", (0.0, 0.104, -0.088), "y", 1, 0.0050,
                     0.0030, part="tower_screw"))
    for k in range(5):
        y = 0.064 + 0.0072 * k
        P.append(prism("disc%d" % k, ngon(0.0135, 8, 0.0, -0.088), "y", y,
                       y + 0.0058, "bare", part="discs"))
    P.append(weld("weld_tower", [(-0.020, 0.0585, -0.110),
                                 (-0.020, 0.0585, -0.088),
                                 (-0.020, 0.0585, -0.066)]))
    # the core in an Epsilon cradle on the body's left, toward the eye
    P.append(box("cradle", -0.044, -0.026, 0.020, 0.048, -0.120, -0.040,
                 "epsilon", bevel=0.0025))
    P += cartridge("core", (-0.040, 0.048, -0.060), (-0.35, 0.9, 0.55),
                   0.034, 0.0090)
    P += lamp("lamp", -0.0445, 0.034, -0.110, "x", -1)
    P += grip("grip", (0.0, -0.030, 0.024), 16, 0.100, 0.0170, 0.0220)
    P.append(guard(-0.030))
    # the Breacher's collar: a heavy ring round the sleeve, two handles
    pump = [tube("collar", 0.0470, 0.0346, 8, 0.0, 0.020, -0.336, -0.258,
                 "tape", part="pump", bevel=0.0025)]
    for k, z in enumerate((-0.330, -0.297, -0.264)):
        pump.append(tube("collar_rib%d" % k, 0.0490, 0.0440, 8, 0.0, 0.020,
                         z - 0.003, z + 0.003, "rubber", part="pump"))
    for sx in (-1, 1):
        pump.append(box("collar_lug%d" % (sx > 0), sx * 0.046 - 0.006,
                        sx * 0.046 + 0.006, 0.010, 0.030, -0.322, -0.272,
                        "strap", part="pump", bevel=0.0012))
    # Sweeper: a belt of discs from a box on the left into the breech
    feed = [box("belt_box", -0.078, -0.046, -0.034, 0.004, -0.136, -0.066,
                "painted", part="feed", bevel=0.0025),
            box("belt_box_lid", -0.080, -0.044, 0.004, 0.008, -0.138,
                -0.064, "strap", part="feed")]
    for k in range(4):
        z = -0.124 + 0.018 * k
        feed.append(prism("belt_disc%d" % k, ngon(0.0110, 8, z, 0.020),
                          "x", -0.044 + 0.004 * k - 0.004,
                          -0.044 + 0.004 * k + 0.0015, "bare",
                          part="feed"))
    feed.append(box("belt_link", -0.046, -0.028, 0.006, 0.010, -0.132,
                    -0.056, "strap", part="feed"))
    return P, {"Pump": (pump, (0.0, 0.020, -0.297)),
               "Feed": (feed, (-0.065, -0.020, -0.095))}, {
        "muzzle": MUZZLE, "sights": []}


wf.PROPOSALS.update({
    "bulkhead_c": ("Bulkhead", "C  Spreader", bulkhead_c),
    "bulkhead_d": ("Bulkhead", "D  Fan", bulkhead_d),
    "bulkhead_e": ("Bulkhead", "E  Hatch ram", bulkhead_e),
})

if __name__ == "__main__":
    if sys.argv[sys.argv.index("--") + 1:][1:] == []:
        sys.argv += ["bulkhead_c", "bulkhead_d", "bulkhead_e"]
    wf.main()
