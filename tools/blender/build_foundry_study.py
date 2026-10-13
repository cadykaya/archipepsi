"""Foundry fidelity study -- ONE non-production first-person Foundry.
(Arty, 2026-10-13.)

    .tools/blender/blender -b --python tools/blender/build_foundry_study.py -- bake OUT
    .tools/blender/blender -b --python tools/blender/build_foundry_study.py -- assemble OUT

`bake` builds the model, unwraps it into one atlas and bakes the masks the
painter places wear from (OUT/bake/*.npy, plus a UV fingerprint).
`assemble` rebuilds the same model, checks the UVs still match that
fingerprint, loads the Glyph-exported maps from OUT/maps/ and writes
OUT/foundry_study.glb and OUT/foundry_study.json. `tools/foundry_study.sh`
runs the whole chain.

WHAT IT IS. The owner's next deliverable (2026-10-13): one Foundry, at the
provisional 2,500-4,000-triangle range, in the real renderer, to calibrate
detail and texture before anything else is modelled. The hybrid is kept --
a station-built frame, an Epsilon converter, a swappable Echo core -- but
toned down from the concept sheets: believable proportions, sturdy
construction, no oversized novelty machinery.

WHAT IT IS NOT. Not production: written outside `assets/`, no registry
entry, no budget category added (the art bible has none for viewmodels;
the 2,500-4,000 range is the owner's provisional number for THIS study and
is asserted here, locally). Not a change to Prod's runtime.

THE MECHANISM, mapped onto Prod's runtime states (review/five-weapons-v2,
`range_weapons.gd`), so every visible motion is one the game already makes:

    t = 0       fire: the hammer falls (Prod snaps `foundry/hammer` to 0).
                Its head strikes the striker on the rear block; a bell crank
                drives the ram into the top chamber and the Epsilon collar
                dumps its charge into the heated slug's base.
    0.38-0.58   the carousel indexes 60 deg (Prod's `foundry/cylinder`):
                the next cold blank turns into the collar to heat.
    0.56-0.66   the hammer is drawn back (Prod tweens x to -38 deg) by the
                index cam, and the sear catches: the click.
    0.72        ready (the cooldown). The hammer has been cocked for 60 ms.

THE FRAME. Godot viewmodel space: Prod's RangeRig model origin, -Z forward,
+Y up. The muzzle sits exactly at Prod's MUZZLES.foundry (0, 0.03, -0.47).
Authored here through `g2b`; the glTF exporter flips back.

NODES: `Body` (static), `Hammer` (origin = its pivot; rotation x 0 = fallen,
-38 deg = cocked, Prod's own numbers), `Carousel` (origin = its axis centre,
axis along Godot Z), `Muzzle` (empty).
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402

#: The owner's provisional range for this one study (2026-10-13). NOT a
#: budget category: the art bible is unchanged and has no viewmodel tier.
TRI_RANGE = (2500, 4000)
#: One atlas, 1024 square: ~1,000 texels/m measured, about 1.3 screen
#: pixels a texel at the rig's distance at 1080p. The art bible's reserved
#: viewmodel tier is 256 (DEFERRED); 512 would leave the frame's whole side
#: face ~50 texels square, too few for welds, chips and stamped serials.
#: The density is part of the open budget question, not settled here.
ATLAS = 1024
#: Prod's numbers (range_rig.gd / range_weapons.gd on review/five-weapons-v2).
MUZZLE = (0.0, 0.03, -0.47)
HAMMER_COCKED = -38.0
BORE_Y = 0.030

#: Material classes the painter reads from the ID bake (red channel).
CLASSES = {
    "painted": 1,      # station frame steel, painted, worn to metal
    "bare": 2,         # machined working steel: carousel, hammer, pins
    "barrel": 3,       # the barrel and its crown: heat-blued steel
    "epsilon": 4,      # the converter collar: Epsilon manufacture
    "ceramic": 5,      # insulator spacers
    "core": 6,         # the Echo core cartridge (placeholder material)
    "tape": 7,         # the grip's cloth wrap
    "cable": 8,        # armoured power lead
    "patch": 9,        # a replacement plate that does not match
    "fastener": 10,    # bolt heads and nuts
    "lamp": 11,        # the one power lamp (emissive green = active power)
    "strap": 12,       # bent mild-steel repair straps and clamps
    "rubber": 13,      # cable boots
}

PARTS = {}          # part name -> part id (green channel of the ID bake)


# ===================================================================== maths

def g2b(p):
    """Godot viewmodel space -> Blender authoring space (Z up, -Y back)."""
    x, y, z = p
    return (x, -z, y)


def ngon(r, n, cx=0.0, cy=0.0, phase=0.0):
    return [(cx + r * math.cos(phase + 2 * math.pi * i / n),
             cy + r * math.sin(phase + 2 * math.pi * i / n)) for i in range(n)]


# ================================================================ geometry

def _obj(name, bm, cls, part=None):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj["cls"] = CLASSES[cls]
    key = part or name
    if key not in PARTS:
        PARTS[key] = len(PARTS) + 1
    obj["part"] = PARTS[key]
    return obj


def _bm_prism(profile, axis, a0, a1):
    """A straight prism. `profile` is a closed polygon in the plane across
    `axis` ('x': (z, y); 'y': (x, z); 'z': (x, y)), extruded a0 -> a1."""
    bm = bmesh.new()

    def place(u, v, a):
        if axis == "z":
            return g2b((u, v, a))
        if axis == "x":
            return g2b((a, v, u))
        return g2b((u, a, v))
    back = [bm.verts.new(place(u, v, a0)) for u, v in profile]
    front = [bm.verts.new(place(u, v, a1)) for u, v in profile]
    n = len(profile)
    bm.faces.new(back)
    bm.faces.new(list(reversed(front)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], front[j], front[i]))
    return bm


def prism(name, profile, axis, a0, a1, cls, part=None, bevel=0.0,
          bevel_pred=None):
    bm = _bm_prism(profile, axis, a0, a1)
    if bevel:
        _bevel(bm, bevel, bevel_pred)
    return _obj(name, bm, cls, part)


def box(name, x0, x1, y0, y1, z0, z1, cls, part=None, bevel=0.0,
        bevel_pred=None):
    """A box. With `bevel` and no predicate, every edge is chamfered, built
    as the convex hull of the chamfered corners (bmesh's bevel can drop a
    face on a small box, which renders as a hole)."""
    if bevel and bevel_pred is None:
        c = bevel
        pts = []
        for sx in (x0, x1):
            ix = x0 + c if sx == x0 else x1 - c
            for sy in (y0, y1):
                iy = y0 + c if sy == y0 else y1 - c
                for sz in (z0, z1):
                    iz = z0 + c if sz == z0 else z1 - c
                    pts += [(sx, iy, iz), (ix, sy, iz), (ix, iy, sz)]
        return hull(name, pts, cls, part)
    prof = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    return prism(name, prof, "z", z0, z1, cls, part, bevel, bevel_pred)


def hull(name, pts, cls, part=None):
    """The convex hull of Godot points, coplanar triangles merged."""
    bm = bmesh.new()
    verts = [bm.verts.new(g2b(p)) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=verts)
    for v in res["geom_interior"] + res["geom_unused"]:
        if isinstance(v, bmesh.types.BMVert) and v.is_valid:
            bm.verts.remove(v)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0),
                             verts=bm.verts[:], edges=bm.edges[:])
    return _obj(name, bm, cls, part)


def cyl(name, r, n, cx, cy, z0, z1, cls, part=None, bevel=0.0, phase=None,
        bevel_pred=None):
    """A prism along Godot Z (the line of fire)."""
    phase = math.pi / n if phase is None else phase
    return prism(name, ngon(r, n, cx, cy, phase), "z", z0, z1, cls, part,
                 bevel, bevel_pred)


def tube(name, r_out, r_in, n, cx, cy, z0, z1, cls, part=None, arc=None,
         bevel=0.0):
    """An annulus along Godot Z; `arc` = (a0, a1) radians leaves it open
    (a horseshoe), measured from +X toward +Y."""
    bm = bmesh.new()
    if arc is None:
        angs = [2 * math.pi * i / n + math.pi / n for i in range(n)]
        closed = True
    else:
        angs = [arc[0] + (arc[1] - arc[0]) * i / n for i in range(n + 1)]
        closed = False

    def ring(r, z):
        return [bm.verts.new(g2b((cx + r * math.cos(a), cy + r * math.sin(a),
                                  z))) for a in angs]
    ob, ib = ring(r_out, z0), ring(r_in, z0)
    of, if_ = ring(r_out, z1), ring(r_in, z1)
    m = len(angs)
    segs = range(m) if closed else range(m - 1)
    for i in segs:
        j = (i + 1) % m
        bm.faces.new((ob[i], ob[j], of[j], of[i]))      # outer
        bm.faces.new((ib[j], ib[i], if_[i], if_[j]))     # inner
        bm.faces.new((ob[j], ob[i], ib[i], ib[j]))       # back
        bm.faces.new((of[i], of[j], if_[j], if_[i]))     # front
    if not closed:
        for k in (0, m - 1):
            bm.faces.new((ob[k], ib[k], if_[k], of[k]))
    if bevel:
        _bevel(bm, bevel)
    return _obj(name, bm, cls, part)


def sweep(name, pts, r, n, cls, part=None):
    """A prism of `n` sides along a polyline (Godot points)."""
    bm = bmesh.new()
    P = [Vector(p) for p in pts]
    rings = []
    up = Vector((0, 1, 0))
    for i, p in enumerate(P):
        if i == 0:
            t = (P[1] - P[0]).normalized()
        elif i == len(P) - 1:
            t = (P[-1] - P[-2]).normalized()
        else:
            t = ((P[i] - P[i - 1]).normalized()
                 + (P[i + 1] - P[i]).normalized()).normalized()
        a = up if abs(t.dot(up)) < 0.9 else Vector((1, 0, 0))
        u = t.cross(a).normalized()
        v = t.cross(u).normalized()
        ring = []
        for k in range(n):
            ang = 2 * math.pi * k / n + math.pi / n
            q = p + u * (r * math.cos(ang)) + v * (r * math.sin(ang))
            ring.append(bm.verts.new(g2b(tuple(q))))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    return _obj(name, bm, cls, part)


def loft(name, rings, cls, part=None, caps=True):
    """Quads between consecutive rings of Godot points (equal counts)."""
    bm = bmesh.new()
    vr = [[bm.verts.new(g2b(p)) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vr, vr[1:]):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((a[k], a[j], b[j], b[k]))
    if caps:
        bm.faces.new(vr[0])
        bm.faces.new(list(reversed(vr[-1])))
    return _obj(name, bm, cls, part)


def oct_ring(c, u, v, ru, rv, n=8, phase=None):
    """A ring of n points round centre c in the plane of unit vectors u, v
    (Godot tuples), half-sizes ru, rv."""
    phase = math.pi / n if phase is None else phase
    out = []
    for k in range(n):
        a = phase + 2 * math.pi * k / n
        out.append(tuple(c[i] + u[i] * ru * math.cos(a) + v[i] * rv
                         * math.sin(a) for i in range(3)))
    return out


def _bevel(bm, offset, pred=None):
    """One-segment chamfer on the edges `pred` picks (default: every edge
    between faces meeting at more than 30 deg)."""
    bm.normal_update()
    edges = []
    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        ang = e.link_faces[0].normal.angle(e.link_faces[1].normal, 0.0)
        if ang < math.radians(30):
            continue
        if pred is None or pred(e):
            edges.append(e)
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=1,
                        profile=0.5, affect="EDGES", clamp_overlap=True)


def hexhead(name, at, axis, sign, r, h, part=None, cls="fastener"):
    """A hex bolt head (or nut) standing `h` proud along +/-`axis`."""
    x, y, z = at
    if axis == "x":
        prof = ngon(r, 6, z, y, 0.0)
        a0, a1 = (x, x + sign * h)
    elif axis == "y":
        prof = ngon(r, 6, x, z, 0.0)
        a0, a1 = (y, y + sign * h)
    else:
        prof = ngon(r, 6, x, y, 0.0)
        a0, a1 = (z, z + sign * h)
    return prism(name, prof, axis, min(a0, a1), max(a0, a1), cls,
                 part or "fasteners")


def rotate(obj, axis_g, deg, pivot_g):
    """Rotate a part's mesh about a Godot-space axis through a pivot."""
    ax = Vector(g2b(axis_g)).normalized()
    m = (Matrix.Translation(Vector(g2b(pivot_g)))
         @ Matrix.Rotation(math.radians(deg), 4, ax)
         @ Matrix.Translation(-Vector(g2b(pivot_g))))
    obj.data.transform(m)
    obj.data.update()
    return obj


# ================================================================== the gun

def build():
    """Every piece, as its own object, tagged with class and part."""
    P = {}
    by = BORE_Y

    # ---- barrel: octagonal, heavy-walled, threaded into the breech -------
    P["barrel"] = cyl("barrel", 0.0225, 8, 0, by, -0.440, -0.168, "barrel",
                      phase=math.pi / 8)
    # the crown: a heavier collar round the muzzle, open at the bore
    P["crown"] = tube("crown", 0.0265, 0.0112, 8, 0, by, -0.470, -0.438,
                      "barrel", bevel=0.0018)
    # the bore: the rifling's dark throat, closed well inside
    P["bore"] = tube("bore", 0.0113, 0.0100, 8, 0, by, -0.4695, -0.441,
                     "barrel")
    P["bore_end"] = cyl("bore_end", 0.0102, 8, 0, by, -0.4425, -0.4405,
                        "barrel", part="bore")
    # barrel nut: a spanner-notched collar where barrel meets breech
    P["barrel_nut"] = cyl("barrel_nut", 0.0272, 8, 0, by, -0.172, -0.156,
                          "bare", phase=math.pi / 8, bevel=0.0015)
    # front sight blade, brazed on the crown
    P["front_sight"] = box("front_sight", -0.0016, 0.0016, by + 0.024,
                           by + 0.036, -0.463, -0.447, "bare",
                           part="crown")

    # ---- recoil buffer under the barrel ----------------------------------
    P["buffer"] = cyl("buffer", 0.0135, 8, 0, -0.030, -0.335, -0.160,
                      "painted", phase=math.pi / 8)
    P["buffer_cap"] = cyl("buffer_cap", 0.0155, 8, 0, -0.030, -0.350,
                          -0.333, "bare", phase=math.pi / 8, bevel=0.002)
    P["buffer_nut"] = hexhead("buffer_nut", (0, -0.030, -0.350), "z", -1,
                              0.008, 0.008, part="buffer_cap")

    # ---- the clamp that ties barrel to buffer ----------------------------
    outline = [(0.0290 * math.cos(math.radians(a)),
                by + 0.0290 * math.sin(math.radians(a)))
               for a in (-30, 10, 50, 90, 130, 170, 210)]
    outline += [(0.0195 * math.cos(math.radians(a)),
                 -0.030 + 0.0195 * math.sin(math.radians(a)))
                for a in (200, 240, 270, 300, 340)]
    P["clamp"] = prism("clamp", outline, "z", -0.318, -0.298, "painted",
                       bevel=0.0018, bevel_pred=_across)
    # the pinch bolt through the clamp's waist, head on the left
    P["clamp_bolt"] = hexhead("clamp_bolt", (-0.0225, 0.0, -0.308), "x", -1,
                              0.0052, 0.0042)

    # ---- breech block and the Epsilon converter collar -------------------
    P["breech"] = cyl("breech", 0.031, 8, 0, by, -0.158, -0.096, "painted",
                      phase=math.pi / 8, bevel=0.002)
    # the collar: a horseshoe over the top and both flanks, open beneath
    arc = (math.radians(-38), math.radians(218))
    P["collar"] = tube("collar", 0.0445, 0.0315, 10, 0, by, -0.152, -0.101,
                       "epsilon", arc=arc, bevel=0.0012)
    # its rear lip, a thinner ring the station could clamp to
    P["collar_lip"] = tube("collar_lip", 0.0465, 0.0405, 10, 0, by, -0.108,
                           -0.100, "epsilon", part="collar", arc=arc)
    # the Echo core: a cartridge pushed radially into a socket on the
    # collar's left flank, raked back toward the eye, held by a station
    # strap and a wing nut because the socket's own latch is long gone
    ca = math.radians(152)
    rad = (math.cos(ca), math.sin(ca), 0.0)
    back = math.radians(22)
    ax = (rad[0] * math.cos(back), rad[1] * math.cos(back), math.sin(back))
    base = (0.040 * rad[0], by + 0.040 * rad[1], -0.127)

    def along(t):
        return tuple(base[i] + ax[i] * t for i in range(3))
    u = (0.0, 0.0, 1.0)
    w = (ax[1] * u[2] - ax[2] * u[1], ax[2] * u[0] - ax[0] * u[2],
         ax[0] * u[1] - ax[1] * u[0])
    wl = math.sqrt(sum(c * c for c in w))
    w = tuple(c / wl for c in w)
    v = (w[1] * ax[2] - w[2] * ax[1], w[2] * ax[0] - w[0] * ax[2],
         w[0] * ax[1] - w[1] * ax[0])
    P["core_socket"] = loft("core_socket", [oct_ring(along(t), w, v, r, r)
                                            for t, r in ((0.000, 0.0118),
                                                         (0.012, 0.0118),
                                                         (0.014, 0.0102))],
                            "epsilon", part="collar")
    P["core"] = loft("core", [oct_ring(along(t), w, v, r, r)
                              for t, r in ((0.010, 0.0086), (0.030, 0.0086),
                                           (0.034, 0.0072))], "core")
    P["core_cap"] = loft("core_cap", [oct_ring(along(t), w, v, r, r)
                                      for t, r in ((0.033, 0.0094),
                                                   (0.040, 0.0094),
                                                   (0.042, 0.0080))],
                         "bare", part="core_cap")
    # the strap: over the core's cap and round the collar's top
    cap = along(0.037)
    pts = [(cap[0] - 0.004, cap[1] - 0.012, cap[2]),
           (cap[0] - 0.006, cap[1] + 0.002, cap[2]),
           (cap[0] + 0.004, cap[1] + 0.014, cap[2]),
           (-0.026, by + 0.043, cap[2]), (0.000, by + 0.0485, cap[2]),
           (0.024, by + 0.0420, cap[2])]
    P["core_strap"] = sweep("core_strap", pts, 0.0026, 4, "strap")
    P["wing_nut"] = hexhead("wing_nut", (cap[0] - 0.0035, cap[1] - 0.013,
                                         cap[2]), "x", -1, 0.0042, 0.005,
                            part="core_strap")
    # the one power lamp: a lens on the collar's rear lip, facing the eye
    la = math.radians(62)
    lx, ly = 0.0435 * math.cos(la), by + 0.0435 * math.sin(la)
    P["lamp_bezel"] = cyl("lamp_bezel", 0.0052, 6, lx, ly, -0.104, -0.097,
                          "epsilon", part="collar")
    P["lamp"] = cyl("lamp", 0.0034, 6, lx, ly, -0.098, -0.095, "lamp")
    # ceramic insulators under the collar's open ends, on the frame web
    for side, sx in (("l", -1), ("r", 1)):
        P["ceramic_" + side] = box("ceramic_" + side, sx * 0.041 - 0.0055,
                                   sx * 0.041 + 0.0055, -0.004, 0.009,
                                   -0.146, -0.108, "ceramic", bevel=0.0016)
    # the station's own bracket that holds the collar down: a strap over
    # the top, legs down to bolts on the web -- a little crooked, as fitted
    br = [math.radians(a) for a in (-24, 10, 45, 80, 115, 150, 185, 205)]
    bpts = [(0.0478 * math.cos(a), by + 0.0478 * math.sin(a), -0.131)
            for a in br]
    bpts = [(0.052, -0.012, -0.131)] + bpts + [(-0.052, -0.014, -0.132)]
    P["bracket"] = sweep("bracket", bpts, 0.0032, 4, "strap")
    for side, sx in (("l", -1), ("r", 1)):
        P["bracket_bolt_" + side] = hexhead(
            "bracket_bolt_" + side, (sx * 0.0545, -0.013, -0.131), "x", sx,
            0.0042, 0.0035, part="bracket")

    # ---- the frame: rear block, straps, web ------------------------------
    frame_prof = [(-0.026, 0.046), (-0.026, -0.050), (0.016, -0.050),
                  (0.030, -0.047), (0.050, -0.041), (0.063, -0.028),
                  (0.069, -0.008), (0.067, 0.014), (0.059, 0.031),
                  (0.047, 0.038), (0.020, 0.038), (-0.006, 0.040),
                  (-0.016, 0.046)]
    P["rear_block"] = prism("rear_block", frame_prof, "x", -0.0215, 0.0215,
                            "painted", bevel=0.0028,
                            bevel_pred=lambda e: _across_x(e))
    # cheeks that make the hammer's slot, and the pin through them
    for side, sx in (("l", -1), ("r", 1)):
        # inset 0.3 mm from the block's side: coplanar faces z-fight
        x0, x1 = sorted((sx * 0.0115, sx * 0.0212))
        P["cheek_" + side] = prism(
            "cheek_" + side,
            [(-0.034, 0.030), (0.050, 0.030), (0.050, 0.050), (0.012, 0.062),
             (-0.034, 0.062)], "x", x0, x1, "painted", part="rear_block",
            bevel=0.0015)
    P["pin"] = prism("pin", ngon(0.0042, 8, -0.022, 0.052), "x", -0.0245,
                     0.0245, "bare", part="hammer_pin")
    P["top_strap"] = box("top_strap", -0.0135, 0.0135, 0.046, 0.057,
                         -0.099, -0.025, "painted", bevel=0.002)
    P["bottom_strap"] = box("bottom_strap", -0.021, 0.021, -0.050, -0.035,
                            -0.160, -0.022, "painted", bevel=0.002)
    P["web"] = box("web", -0.019, 0.019, -0.036, 0.004, -0.160, -0.098,
                   "painted")
    # a gusset welded in where the top strap meets the rear block, after
    # the first one cracked (its twin, on the right, is the original)
    P["gusset"] = prism("gusset", [(-0.040, 0.046), (-0.026, 0.046),
                                   (-0.026, 0.060)], "x", -0.0133, -0.0095,
                        "painted", part="top_strap")
    # rear sight: a notch milled in a block on the top strap
    for side, sx in (("l", -1), ("r", 1)):
        x0, x1 = sorted((sx * 0.0030, sx * 0.0075))
        P["rsight_" + side] = box("rsight_" + side, x0, x1, 0.057, 0.066,
                                  -0.040, -0.030, "bare", part="rear_sight")
    # the striker the hammer lands on, in the block's top
    P["striker"] = box("striker", -0.0085, 0.0085, 0.038, 0.0445, 0.020,
                       0.046, "bare", bevel=0.001)

    # the replacement side cover: the block's left access plate was lost,
    # and this is a cut plate on four fasteners that do not match
    P["patch"] = prism("patch", [(-0.015, -0.034), (0.044, -0.034),
                                 (0.050, -0.026), (0.050, 0.024),
                                 (-0.015, 0.027)], "x", -0.0240, -0.0213,
                       "patch", bevel=0.0007)
    P["patch_bolt0"] = hexhead("patch_bolt0", (-0.0240, 0.020, -0.008), "x",
                               -1, 0.0042, 0.003, part="patch")
    P["patch_bolt1"] = hexhead("patch_bolt1", (-0.0240, -0.027, 0.042), "x",
                               -1, 0.0036, 0.0028, part="patch")

    # ---- welds, laid where the station welded it: raised beads, a little
    # uneven, partly sunk into the joint they fill
    def bead(name, pts, r=0.0021):
        return sweep(name, pts, r, 6, "painted", part=name)
    P["weld_strap_breech"] = bead("weld_strap_breech", [
        (-0.0140, 0.0470, -0.0975), (-0.0150, 0.0515, -0.0985),
        (-0.0138, 0.0565, -0.0978), (-0.0060, 0.0585, -0.0982),
        (0.0060, 0.0583, -0.0979), (0.0136, 0.0562, -0.0984)])
    P["weld_web_breech"] = bead("weld_web_breech", [
        (-0.0195, -0.0300, -0.0985), (-0.0201, -0.0180, -0.0980),
        (-0.0196, -0.0060, -0.0987), (-0.0205, 0.0040, -0.0981)])
    P["weld_block_strap"] = bead("weld_block_strap", [
        (-0.0218, -0.0490, -0.0255), (-0.0222, -0.0420, -0.0262),
        (-0.0217, -0.0360, -0.0256)], r=0.0019)
    # the loading gate, on the right where a gloved thumb opens it
    P["gate"] = box("gate", 0.0200, 0.0232, -0.020, 0.018, -0.088, -0.034,
                    "bare", bevel=0.0007)
    P["gate_hinge"] = prism("gate_hinge", ngon(0.0028, 6, -0.090, -0.001),
                            "x", 0.0195, 0.0240, "bare", part="gate")

    # ---- the carousel -----------------------------------------------------
    cyl_y = by - 0.024
    land, flute = 0.0400, 0.0352
    prof = []
    for i in range(6):
        a = math.radians(60 * i)
        prof.append((land * math.cos(a - 0.21), cyl_y + land * math.sin(a - 0.21)))
        prof.append((land * math.cos(a + 0.21), cyl_y + land * math.sin(a + 0.21)))
        prof.append((flute * math.cos(a + math.radians(30)),
                     cyl_y + flute * math.sin(a + math.radians(30))))
    P["carousel"] = prism("carousel", prof, "z", -0.094, -0.028, "bare",
                          bevel=0.0018,
                          bevel_pred=lambda e: _across(e))
    P["axle"] = cyl("axle", 0.0068, 8, 0, cyl_y, -0.100, -0.022, "bare",
                    part="carousel")

    # ---- grip, guard, trigger ---------------------------------------------
    rake = math.radians(17.0)
    d = (0.0, -math.cos(rake), math.sin(rake))       # down the grip
    fv = (0.0, math.sin(rake), math.cos(rake))       # across it, fore-aft
    top = (0.0, -0.044, 0.022)

    def at(t):
        return tuple(top[i] + d[i] * t for i in range(3))
    X = (1.0, 0.0, 0.0)
    P["grip"] = loft("grip", [oct_ring(at(t), X, fv, ru, rv) for t, ru, rv
                              in ((0.000, 0.0160, 0.0215),
                                  (0.045, 0.0150, 0.0200),
                                  (0.100, 0.0162, 0.0215),
                                  (0.112, 0.0156, 0.0208))], "tape")
    P["grip_cap"] = loft("grip_cap", [oct_ring(at(t), X, fv, ru, rv) for
                                      t, ru, rv in ((0.110, 0.0170, 0.0225),
                                                    (0.124, 0.0164, 0.0216))],
                         "painted", part="grip_cap")
    P["hose_clamp"] = loft("hose_clamp", [oct_ring(at(t), X, fv, ru, rv) for
                                          t, ru, rv in
                                          ((0.016, 0.0163, 0.0218),
                                           (0.022, 0.0162, 0.0216))],
                           "strap")
    P["clamp_screw"] = hexhead("clamp_screw", (-0.0164, -0.062, 0.028), "x",
                               -1, 0.0030, 0.0035, part="hose_clamp")
    guard = [(0, -0.049, -0.052), (0, -0.070, -0.048), (0, -0.080, -0.030),
             (0, -0.080, -0.010), (0, -0.068, 0.006)]
    P["guard"] = sweep("guard", guard, 0.0032, 4, "painted")
    P["trigger"] = prism("trigger", [(-0.030, -0.046), (-0.022, -0.046),
                                     (-0.018, -0.062), (-0.022, -0.070),
                                     (-0.026, -0.062)], "x", -0.0035,
                         0.0035, "bare")

    # ---- power: switch box, armoured lead, clips -------------------------
    P["switch"] = box("switch", -0.027, -0.019, -0.052, -0.034, -0.030,
                      -0.008, "painted", bevel=0.0015)
    lead = [(-0.023, -0.044, -0.031), (-0.025, -0.046, -0.060),
            (-0.026, -0.040, -0.098), (-0.038, -0.016, -0.118),
            (-0.047, -0.004, -0.124)]
    P["lead"] = sweep("lead", lead, 0.0038, 6, "cable")
    P["boot0"] = cyl("boot0", 0.0052, 6, -0.023, -0.044, -0.040, -0.030,
                     "rubber", part="lead")
    for i, z in enumerate((-0.062, -0.094)):
        P["lead_clip%d" % i] = box("lead_clip%d" % i, -0.0305, -0.0195,
                                   -0.052 if i == 0 else -0.046, -0.038
                                   if i == 0 else -0.033, z - 0.003,
                                   z + 0.003, "strap", part="lead_clips")

    # ---- the hammer (its own node) ----------------------------------------
    # a forged hammer: a boss round the pin, a neck that thickens toward
    # a tapered head, and a raked thumb spur for clearing it by hand
    boss = [(x, 0.052 + 0.0078 * math.sin(a), -0.022 + 0.0078 * math.cos(a))
            for x in (-0.0085, 0.0085)
            for a in [2 * math.pi * k / 8 + math.pi / 8 for k in range(8)]]
    neck = [(x, y, 0.024) for x in (-0.0095, 0.0095)
            for y in (0.0455, 0.0620)]
    head = []
    for z, hw, y0, y1 in ((0.0225, 0.0118, 0.0445, 0.0675),
                          (0.0255, 0.0124, 0.0445, 0.0700),
                          (0.0470, 0.0120, 0.0445, 0.0705),
                          (0.0505, 0.0108, 0.0465, 0.0680)):
        head += [(x, y, z) for x in (-hw, hw) for y in (y0, y1)]
    spur = [(x, y, z) for x in (-0.0068, 0.0068)
            for y, z in ((0.0690, 0.0400), (0.0690, 0.0500),
                         (0.0775, 0.0600), (0.0805, 0.0570),
                         (0.0760, 0.0440))]
    hammer = [
        hull("hammer_arm", boss + neck, "bare", part="hammer"),
        hull("hammer_head", head, "bare", part="hammer"),
        hull("hammer_spur", spur, "bare", part="hammer_spur"),
    ]
    return P, hammer


def _across_x(e):
    """Edges lying in a side face of an X-extruded profile."""
    a, b = e.verts[0].co, e.verts[1].co
    return abs(a.x - b.x) < 1e-6


def _across(e):
    """Edges of the carousel's end faces (not its long flute edges)."""
    a, b = e.verts[0].co, e.verts[1].co
    return abs(a.y - b.y) < 1e-6


# ================================================================ assembly

def assemble_objects():
    """Build, join into Body / Hammer / Carousel, place pivots and the
    muzzle. Returns (body, hammer, carousel, muzzle, pieces)."""
    P, hammer_parts = build()
    carousel_bits = [P.pop("carousel"), P.pop("axle")]
    pieces = list(P.values()) + hammer_parts + carousel_bits
    _shade(pieces)
    for o in pieces:
        _id_material(o)
    body = common.join(list(P.values()), "Body")
    hammer = common.join(hammer_parts, "Hammer")
    carousel = common.join(carousel_bits, "Carousel")
    _pivot(hammer, (0.0, 0.052, -0.022))
    _pivot(carousel, (0.0, BORE_Y - 0.024, -0.061))
    muzzle = bpy.data.objects.new("Muzzle", None)
    muzzle.location = Vector(g2b(MUZZLE))
    bpy.context.scene.collection.objects.link(muzzle)
    return body, hammer, carousel, muzzle


def _shade(objs):
    for o in objs:
        for poly in o.data.polygons:
            poly.use_smooth = False


def _pivot(obj, at):
    p = Vector(g2b(at))
    obj.data.transform(Matrix.Translation(-p))
    obj.data.update()
    obj.location = p


def _id_material(obj):
    """A per-piece material whose emission encodes (class, part) for the
    ID bake. Replaced by the one atlas material at assembly."""
    cls, part = obj["cls"], obj["part"]
    name = "id_%02d_%02d" % (cls, part)
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (cls / 255.0, part / 255.0, 0, 1)
        nt.links.new(em.outputs[0], out.inputs[0])
        mat["cls"], mat["part"] = cls, part
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def unwrap(objs):
    """Smart-project every node, average island scale across all of them
    (one density for the whole gun), pack into one atlas."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.0,
                             area_weight=0.0, correct_aspect=True,
                             scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    # a 4-texel gutter: enough for the bake's margin and the first mips
    bpy.ops.uv.pack_islands(udim_source="CLOSEST_UDIM", rotate=True,
                            rotate_method="ANY", scale=True,
                            merge_overlap=False, margin_method="FRACTION",
                            margin=0.004, pin=False, shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")


def uv_fingerprint(objs):
    h = hashlib.sha256()
    for o in objs:
        uv = o.data.uv_layers.active.data
        arr = np.zeros(len(uv) * 2, dtype=np.float32)
        uv.foreach_get("uv", arr)
        h.update(np.round(arr, 5).tobytes())
    return h.hexdigest()[:16]


def texel_density(objs):
    """Measured texels per metre (sqrt of UV area over world area)."""
    uv_area = world = 0.0
    for o in objs:
        me = o.data
        me.calc_loop_triangles()
        uv = me.uv_layers.active.data
        mw = o.matrix_world
        for tri in me.loop_triangles:
            a, b, c = (uv[i].uv for i in tri.loops)
            uv_area += abs((b - a).cross(c - a)) / 2.0
            pa, pb, pc = (mw @ me.vertices[i].co for i in tri.vertices)
            world += (pb - pa).cross(pc - pa).length / 2.0
    return ATLAS * math.sqrt(uv_area / world), uv_area


def triangles(objs):
    n = 0
    for o in objs:
        o.data.calc_loop_triangles()
        n += len(o.data.loop_triangles)
    return n


# ==================================================================== bakes

def _bake_image(name):
    img = bpy.data.images.get(name)
    if img is None:
        img = bpy.data.images.new(name, ATLAS, ATLAS, alpha=True,
                                  float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    return img


def _set_bake_shader(objs, kind, img):
    """Point every material at `img` and wire the emission `kind` emits."""
    for o in objs:
        for mat in o.data.materials:
            nt = mat.node_tree
            for n in list(nt.nodes):
                if n.name.startswith("bake_"):
                    nt.nodes.remove(n)
            out = next(n for n in nt.nodes
                       if n.type == "OUTPUT_MATERIAL")
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.name = "bake_target"
            tex.image = img
            nt.nodes.active = tex
            em = nt.nodes.new("ShaderNodeEmission")
            em.name = "bake_em"
            if kind == "id":
                em.inputs["Color"].default_value = (mat["cls"] / 255.0,
                                                    mat["part"] / 255.0,
                                                    0, 1)
            elif kind in ("pos", "nrm"):
                geo = nt.nodes.new("ShaderNodeNewGeometry")
                geo.name = "bake_geo"
                xf = nt.nodes.new("ShaderNodeVectorTransform")
                xf.name = "bake_xf"
                xf.vector_type = "POINT" if kind == "pos" else "NORMAL"
                xf.convert_from = "WORLD"
                xf.convert_to = "WORLD"
                nt.links.new(geo.outputs["Position" if kind == "pos"
                                         else "Normal"], xf.inputs[0])
                nt.links.new(xf.outputs[0], em.inputs["Color"])
            elif kind == "edge":
                # the bevel shader's normal leans across an edge; how far
                # it leans from the true normal is how near the edge is
                geo = nt.nodes.new("ShaderNodeNewGeometry")
                geo.name = "bake_geo"
                bev = nt.nodes.new("ShaderNodeBevel")
                bev.name = "bake_bevel"
                bev.samples = 16
                bev.inputs["Radius"].default_value = 0.0035
                dot = nt.nodes.new("ShaderNodeVectorMath")
                dot.name = "bake_dot"
                dot.operation = "DOT_PRODUCT"
                nt.links.new(bev.outputs[0], dot.inputs[0])
                nt.links.new(geo.outputs["Normal"], dot.inputs[1])
                inv = nt.nodes.new("ShaderNodeMath")
                inv.name = "bake_inv"
                inv.operation = "SUBTRACT"
                inv.inputs[0].default_value = 1.0
                nt.links.new(dot.outputs["Value"], inv.inputs[1])
                nt.links.new(inv.outputs[0], em.inputs["Color"])
            nt.links.new(em.outputs[0], out.inputs[0])


def bake_all(objs, out_dir):
    """The masks the painter reads, as float arrays (row 0 = UV v = 1,
    i.e. image top, like a PNG)."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.seed = 7
    scene.cycles.use_denoising = False
    scene.render.bake.margin = 8
    scene.render.bake.margin_type = "EXTEND"
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(out_dir, exist_ok=True)
    for kind, samples in (("id", 1), ("pos", 1), ("nrm", 1), ("edge", 32),
                          ("ao", 96)):
        img = _bake_image("bake_" + kind)
        if kind == "ao":
            _set_bake_shader(objs, "id", img)    # any target; AO ignores it
            scene.cycles.samples = samples
            scene.world = scene.world or bpy.data.worlds.new("w")
            scene.world.light_settings.distance = 0.03
            bpy.ops.object.bake(type="AO", margin=8)
        else:
            _set_bake_shader(objs, kind, img)
            scene.cycles.samples = samples
            bpy.ops.object.bake(type="EMIT", margin=8)
        px = np.empty(ATLAS * ATLAS * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        arr = px.reshape(ATLAS, ATLAS, 4)[::-1]          # top row first
        np.save(os.path.join(out_dir, kind + ".npy"), arr)
        common.log("baked %-4s" % kind)
    # coverage: which texels belong to a face at all (no margin)
    np.save(os.path.join(out_dir, "cover.npy"), _coverage(objs))


def _coverage(objs):
    """Rasterise every UV triangle: True where a face owns the texel."""
    cover = np.zeros((ATLAS, ATLAS), dtype=bool)
    ys, xs = np.mgrid[0:ATLAS, 0:ATLAS]
    cx = (xs + 0.5) / ATLAS
    cy = 1.0 - (ys + 0.5) / ATLAS
    for o in objs:
        me = o.data
        me.calc_loop_triangles()
        uv = me.uv_layers.active.data
        for tri in me.loop_triangles:
            a, b, c = (uv[i].uv for i in tri.loops)
            x0 = int(max(0, math.floor(min(a.x, b.x, c.x) * ATLAS)))
            x1 = int(min(ATLAS, math.ceil(max(a.x, b.x, c.x) * ATLAS) + 1))
            y0 = int(max(0, math.floor((1 - max(a.y, b.y, c.y)) * ATLAS)))
            y1 = int(min(ATLAS, math.ceil((1 - min(a.y, b.y, c.y)) * ATLAS)
                         + 1))
            if x1 <= x0 or y1 <= y0:
                continue
            px, py = cx[y0:y1, x0:x1], cy[y0:y1, x0:x1]
            d = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
            if abs(d) < 1e-12:
                continue
            l1 = ((b.y - c.y) * (px - c.x) + (c.x - b.x) * (py - c.y)) / d
            l2 = ((c.y - a.y) * (px - c.x) + (a.x - c.x) * (py - c.y)) / d
            l3 = 1 - l1 - l2
            inside = (l1 >= -1e-4) & (l2 >= -1e-4) & (l3 >= -1e-4)
            cover[y0:y1, x0:x1] |= inside
    return cover


# =============================================================== the export

def _final_material(maps_dir, normal="normal.png"):
    mat = bpy.data.materials.new("foundry_study")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    def tex(name, colour):
        node = nt.nodes.new("ShaderNodeTexImage")
        img = bpy.data.images.load(os.path.join(maps_dir, name))
        img.colorspace_settings.name = "sRGB" if colour else "Non-Color"
        node.image = img
        node.interpolation = "Closest"       # NEAREST, as the bible asks
        return node
    nt.links.new(tex("albedo.png", True).outputs[0],
                 bsdf.inputs["Base Color"])
    nt.links.new(tex("roughness.png", False).outputs[0],
                 bsdf.inputs["Roughness"])
    nt.links.new(tex("metallic.png", False).outputs[0],
                 bsdf.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex(normal, False).outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    nt.links.new(tex("emission.png", True).outputs[0],
                 bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    return mat


def triangulate(objs):
    """Triangles for export, so tangents are MikkTSpace from the same
    triangles the engine draws (UVs are carried through)."""
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY",
                              ngon_method="BEAUTY")
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()


def export(objs, muzzle, maps_dir, path):
    triangulate(objs)
    mat = _final_material(maps_dir)
    mat.use_backface_culling = True
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
    root = bpy.data.objects.new("FoundryStudy", None)
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


# ================================================================= previews

#: Prod's RangeRig rest pose in the camera's frame.
RIG_POS = (0.30, -0.27, -0.55)
RIG_ROT = (0.0, 6.0, -3.0)


def _rig_matrix():
    """Model -> camera, in Godot space (Euler YXZ, as Godot applies it)."""
    rx, ry, rz = (math.radians(a) for a in RIG_ROT)
    r = (Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X")
         @ Matrix.Rotation(rz, 4, "Z"))
    return Matrix.Translation(Vector(RIG_POS)) @ r


def preview(objs, out, material=None):
    """Grey clay renders: the player's eye, a side elevation, a close
    three-quarter. For checking proportion before anything is painted."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    if material is None:
        material = bpy.data.materials.new("clay")
        material.use_nodes = True
        material.node_tree.nodes["Principled BSDF"].inputs["Roughness"]\
            .default_value = 0.6
    else:
        scene.cycles.samples = 64
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(material)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world
    for i, (e, rot) in enumerate(((3.0, (40, -20, 30)),
                                  (1.6, (55, 25, -150)))):
        sun = bpy.data.objects.new("sun%d" % i,
                                   bpy.data.lights.new("sun%d" % i, "SUN"))
        sun.data.energy = e
        sun.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    g2b_m = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    inv = _rig_matrix().inverted()
    views = {
        # the eye: camera at the camera origin, looking down -Z
        "fp": (inv, 75.0),
        "side": (Matrix.Translation(Vector((-0.95, -0.03, -0.20)))
                 @ Matrix.Rotation(math.radians(-90), 4, "Y"), 22.0),
        # the player's own eye, a long lens on the gun
        "fp_zoom": (inv @ Matrix.Rotation(math.radians(-28), 4, "X")
                    @ Matrix.Rotation(math.radians(-14), 4, "Y"), 28.0),
        "close": (Matrix.Translation(Vector((-0.22, 0.20, 0.16)))
                  @ Matrix.Rotation(math.radians(-50), 4, "Y")
                  @ Matrix.Rotation(math.radians(-38), 4, "X"), 40.0),
    }
    def look_at(eye, target, roll=0.0):
        """A Godot-space camera matrix (looks down -Z, +Y up)."""
        e, t = Vector(eye), Vector(target)
        f = (t - e).normalized()
        r = f.cross(Vector((0, 1, 0))).normalized()
        u = r.cross(f)
        m = Matrix(((r.x, u.x, -f.x, e.x), (r.y, u.y, -f.y, e.y),
                    (r.z, u.z, -f.z, e.z), (0, 0, 0, 1)))
        return m @ Matrix.Rotation(math.radians(roll), 4, "Z")
    # close looks at the materials, from where a curious player would look
    views["macro_side"] = (look_at((-0.16, 0.03, 0.06), (-0.02, 0.0, 0.0)),
                           24.0)
    views["macro_top"] = (look_at((-0.06, 0.20, 0.16), (0.0, 0.045, -0.04)),
                          24.0)
    views["macro_collar"] = (look_at((-0.15, 0.10, -0.03),
                                     (-0.02, 0.02, -0.13)), 26.0)
    views["macro_muzzle"] = (look_at((-0.10, 0.07, -0.56),
                                     (0.0, 0.02, -0.42)), 26.0)
    for name, (m, fov) in views.items():
        cam.matrix_world = g2b_m @ m
        cam.data.angle_y = math.radians(fov)
        cam.data.sensor_fit = "VERTICAL"
        cam.data.clip_start = 0.01
        scene.render.filepath = os.path.join(out, "clay_%s.png" % name)
        bpy.ops.render.render(write_still=True)


# ===================================================================== main

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2 or argv[0] not in ("bake", "assemble", "preview",
                                        "look"):
        raise SystemExit("usage: -- bake|assemble|preview OUT | "
                         "look OUT MAPS [NORMAL]")
    mode, out = argv[0], os.path.abspath(argv[1])
    os.makedirs(out, exist_ok=True)
    common.reset_scene()
    body, hammer, carousel, muzzle = assemble_objects()
    objs = [body, hammer, carousel]
    tris = triangles(objs)
    if mode == "preview":
        common.log("foundry study: %d tris (preview)" % tris)
        hammer.rotation_euler.x = math.radians(HAMMER_COCKED)
        preview(objs, out)
        return
    if mode == "look":
        # the painted maps on the model, in Cycles, before Glyph and Godot
        hammer.rotation_euler.x = math.radians(HAMMER_COCKED)
        unwrap(objs)
        maps = os.path.abspath(argv[2])
        normal = argv[3] if len(argv) > 3 else "normal.png"
        mat = _final_material(maps, normal)
        preview(objs, os.path.join(out, "look"), material=mat)
        return
    if not TRI_RANGE[0] <= tris <= TRI_RANGE[1]:
        raise SystemExit("foundry study: %d triangles, outside the owner's "
                         "provisional %d-%d" % ((tris,) + TRI_RANGE))
    # the hammer cocked, as the gun rests, for the bakes' occlusion
    hammer.rotation_euler.x = math.radians(HAMMER_COCKED)
    bpy.context.view_layer.update()
    unwrap(objs)
    density, fill = texel_density(objs)
    fp = uv_fingerprint(objs)
    common.log("foundry study: %d tris, %.0f texels/m, atlas fill %.0f%%, "
               "uv %s" % (tris, density, 100 * fill, fp))
    if mode == "bake":
        bake_all(objs, os.path.join(out, "bake"))
        parts = {k: v for k, v in PARTS.items()}
        with open(os.path.join(out, "bake", "bake.json"), "w") as fh:
            json.dump({"uv": fp, "atlas": ATLAS, "classes": CLASSES,
                       "parts": parts, "triangles": tris,
                       "texels_per_metre": round(density, 1)}, fh,
                      indent=1, sort_keys=True)
        return
    with open(os.path.join(out, "bake", "bake.json")) as fh:
        baked = json.load(fh)
    if baked["uv"] != fp:
        raise SystemExit("UVs changed since the bake (%s, now %s): bake "
                         "again" % (baked["uv"], fp))
    hammer.rotation_euler.x = 0.0          # the exported rest is identity
    export(objs, muzzle, os.path.join(out, "maps"),
           os.path.join(out, "foundry_study.glb"))
    record = {
        "status": "NON-PRODUCTION FIDELITY STUDY (Arty, 2026-10-13). Not "
                  "registered, not a budget category, not for shipping.",
        "triangles": tris,
        "provisional_range": list(TRI_RANGE),
        "atlas": ATLAS,
        "texels_per_metre": round(density, 1),
        "nodes": {
            "Body": "static",
            "Hammer": {"pivot": [0.0, 0.052, -0.022], "axis": "x",
                       "fallen_deg": 0.0, "cocked_deg": HAMMER_COCKED,
                       "drives": "foundry/hammer"},
            "Carousel": {"centre": [0.0, BORE_Y - 0.024, -0.061],
                         "axis": "z", "index_deg": 60.0,
                         "drives": "foundry/cylinder"},
            "Muzzle": {"at": list(MUZZLE)},
        },
        "frame": "Godot viewmodel space (RangeRig model origin), -Z forward",
    }
    with open(os.path.join(out, "foundry_study.json"), "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")
    common.log("wrote %s" % os.path.join(out, "foundry_study.glb"))


if __name__ == "__main__":
    main()
