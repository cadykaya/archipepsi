"""The Foundry study's material maps, painted from its bakes.
(Arty, 2026-10-13.) NON-PRODUCTION FIDELITY STUDY.

    .tools/blender/4.5/python/bin/python3.11 tools/blender/foundry_paint.py OUT

Reads OUT/bake/*.npy (from `build_foundry_study.py -- bake`) and writes
OUT/paint/{albedo,height,roughness,metallic,emission}.png. Those go to
Glyph (`tools/glyphui/author_foundry_study_maps.py`), which holds the maps,
derives the normal map from the height field, checks the set and exports
what the model wears. Pure numpy, deterministic: every random choice is a
hash of a world position or a fixed seed.

THE RULE THIS PAINTER IS WRITTEN AGAINST (the owner, 2026-10-13): "The
model explains the construction. The textures explain the materials, use,
repairs and history." So wear is placed where the gun's construction and
operation put it, never sprinkled:

  edges        paint chips where convex edges meet hands, holsters, benches
  contact      polish where something rubs: the hammer in its cheeks, the
               carousel's stop ring, the striker under the hammer, the grip
               under a palm, the wing nut and core cap under fingers
  heat         temper colours and scorched paint where the breech and the
               muzzle get hot; soot where gas escapes (the muzzle, and the
               gap between carousel and breech, as on any revolver)
  oil, grease  at pivots and slides, and the runs they leave
  dirt, dust   in recesses, on upward faces
  repairs      welds, a ground-out crack, a touched-up gusset, a plate that
               does not match on fasteners that do not match
  maintenance  torque stripes, a service note in grease pencil, stamped and
               stencilled marks, some of them faded

Noise only breaks up the EDGE of a mask that something else placed (the
bible's §6: "a hash on a broad surface is digital camouflage").

The art bible says albedo only (§5). The owner asked for roughness and
normal detail where supported, for this study only; the bible is unchanged
and the conflict is stated in the report.
"""

from __future__ import annotations

import json
import os
import struct
import sys
import zlib

import numpy as np

# ------------------------------------------------------------------ palette
# Ramps from assets/art_palette.json, so the gun is painted from the same
# world: the station's trim for its paint, the shared grime for its dirt.

def hx(h):
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)])


FACILITY_TRIM = [hx("#2e3338"), hx("#525a63"), hx("#788592")]
RUST_TRIM = [hx("#3d2a1e"), hx("#704d37"), hx("#a77352")]
RUST_BASE = [hx("#543724"), hx("#8a5a3b")]
GRIME = [hx("#241f1c"), hx("#4e433c"), hx("#7b6a60")]
DEAD = [hx("#26292d"), hx("#4a4f57"), hx("#717985"), hx("#9ba5b6")]
FACILITY_LIGHT = [hx("#b9bcb6"), hx("#e8ece4")]
IDENTITY = [hx("#23660c"), hx("#45c918"), hx("#57ff1f")]

STEEL_BRIGHT = hx("#b4b8ba")     # freshly worn steel
STEEL_MID = hx("#7a7e82")
BLUED = hx("#33373d")            # oxide finish on working parts
PRIMER = hx("#4f4038")           # red-oxide primer, dulled (not hazard)
CERAMIC = hx("#d9d6cc")
CORE_DARK = hx("#1b1c21")
CORE_BAND = hx("#4a4740")
TAPE = hx("#6f6656")
TAPE_DARK = hx("#3a342c")
ETAPE = hx("#17181a")
CHALK = hx("#cfcabd")            # paint pen, grease pencil, stencils

# Temper colours, desaturated so they sit below the signal hues.
TEMPER = [hx("#8f8466"), hx("#80664a"), hx("#5d4a52"), hx("#3f4654")]

#: How metallic exposed steel is drawn. Prod's range renders through the
#: Compatibility renderer with nothing for a metal to reflect, so a fully
#: metallic surface goes black (Prod's own steel placeholders do). Steel is
#: carried by its albedo, as a GoldSrc skin did, with a modest metallic
#: share for the sheen.
METAL_SHOW = 0.35

CLS = {"painted": 1, "bare": 2, "barrel": 3, "epsilon": 4, "ceramic": 5,
       "core": 6, "tape": 7, "cable": 8, "patch": 9, "fastener": 10,
       "lamp": 11, "strap": 12, "rubber": 13}


# -------------------------------------------------------------------- maths

def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _hash3(ix, iy, iz, seed):
    h = (ix * 374761393 + iy * 668265263 + iz * 1440662683
         + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(P, scale, seed=0):
    """Smooth 3D value noise in 0..1 at `scale` cells per metre."""
    q = P * scale
    i = np.floor(q).astype(np.int64)
    f = q - i
    u = f * f * (3 - 2 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                h = _hash3(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz,
                           seed)
                w = ((u[..., 0] if dx else 1 - u[..., 0])
                     * (u[..., 1] if dy else 1 - u[..., 1])
                     * (u[..., 2] if dz else 1 - u[..., 2]))
                out = out + h * w
    return out


def fbm(P, scale, seed=0, octaves=3):
    tot, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        tot = tot + amp * vnoise(P, scale * (2.03 ** o), seed + 31 * o)
        norm += amp
        amp *= 0.5
    return tot / norm


def cellhash(P, size, seed=0):
    """A value constant over cubes of `size` metres (for per-patch choices)."""
    i = np.floor(P / size).astype(np.int64)
    return _hash3(i[..., 0], i[..., 1], i[..., 2], seed)


def seg_dist(P, a, b):
    a, b = np.asarray(a, float), np.asarray(b, float)
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
    d = np.linalg.norm(P - (a + t[..., None] * ab), axis=-1)
    return d, t


def poly_dist(P, pts):
    """Distance to a polyline and arclength (metres) at the nearest point."""
    best = np.full(P.shape[:-1], 1e9)
    arc = np.zeros(P.shape[:-1])
    run = 0.0
    for a, b in zip(pts, pts[1:]):
        d, t = seg_dist(P, a, b)
        ln = float(np.linalg.norm(np.subtract(b, a)))
        closer = d < best
        best = np.where(closer, d, best)
        arc = np.where(closer, run + t * ln, arc)
        run += ln
    return best, arc


def mix(a, b, t):
    """Blend a -> b by t. A colour (last axis 3) takes a per-texel t on a
    new axis; a single-channel map takes it as it is."""
    a, b, t = np.asarray(a, float), np.asarray(b, float), np.asarray(t,
                                                                       float)
    colour = (a.ndim and a.shape[-1] == 3 and a.ndim != t.ndim) or \
        (b.ndim and b.shape[-1] == 3 and b.ndim != t.ndim)
    if t.ndim and colour:
        t = t[..., None]
    return a * (1 - t) + b * t


def ramp(stops, t):
    """Piecewise-linear colour ramp; t in 0..1."""
    t = np.clip(t, 0.0, 1.0) * (len(stops) - 1)
    i = np.clip(np.floor(t).astype(int), 0, len(stops) - 2)
    f = (t - i)[..., None]
    S = np.array(stops)
    return S[i] * (1 - f) + S[i + 1] * f


# ------------------------------------------------------------- stencil font
# The project's own 3x5 face (paintkit.GLYPHS), so the gun's lettering is
# the same hand as every sign in the station.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
GLYPHS = {
    "A": ["###", "# #", "###", "# #", "# #"], "B": ["## ", "# #", "## ", "# #", "## "],
    "C": ["###", "#  ", "#  ", "#  ", "###"], "D": ["## ", "# #", "# #", "# #", "## "],
    "E": ["###", "#  ", "## ", "#  ", "###"], "F": ["###", "#  ", "## ", "#  ", "#  "],
    "G": ["###", "#  ", "# #", "# #", "###"], "H": ["# #", "# #", "###", "# #", "# #"],
    "I": ["###", " # ", " # ", " # ", "###"], "K": ["# #", "# #", "## ", "# #", "# #"],
    "L": ["#  ", "#  ", "#  ", "#  ", "###"], "M": ["# #", "###", "###", "# #", "# #"],
    "N": ["# #", "###", "###", "###", "# #"], "O": ["###", "# #", "# #", "# #", "###"],
    "P": ["###", "# #", "###", "#  ", "#  "], "R": ["###", "# #", "###", "## ", "# #"],
    "S": ["###", "#  ", "###", "  #", "###"], "T": ["###", " # ", " # ", " # ", " # "],
    "U": ["# #", "# #", "# #", "# #", "###"], "V": ["# #", "# #", "# #", "# #", " # "],
    "W": ["# #", "# #", "###", "###", "# #"], "X": ["# #", "# #", " # ", "# #", "# #"],
    "Y": ["# #", "# #", "###", " # ", " # "], "Z": ["###", "  #", " # ", "#  ", "###"],
    "0": ["###", "# #", "# #", "# #", "###"], "1": [" # ", "## ", " # ", " # ", "###"],
    "2": ["###", "  #", "###", "#  ", "###"], "3": ["###", "  #", "###", "  #", "###"],
    "4": ["# #", "# #", "###", "  #", "  #"], "5": ["###", "#  ", "###", "  #", "###"],
    "6": ["###", "#  ", "###", "# #", "###"], "7": ["###", "  #", "  #", "  #", "  #"],
    "8": ["###", "# #", "###", "# #", "###"], "9": ["###", "# #", "###", "  #", "###"],
    "-": ["   ", "   ", "###", "   ", "   "], "/": ["  #", "  #", " # ", "#  ", "#  "],
    " ": ["   ", "   ", "   ", "   ", "   "], ".": ["   ", "   ", "   ", "   ", " # "],
}


def lettering(P, N, text, origin, u_dir, v_dir, facing, cell):
    """A mask where `text` lands on surfaces facing `facing`: planar, from
    `origin` along `u_dir` (reading direction) and `v_dir` (up), each glyph
    pixel `cell` metres square."""
    u_dir, v_dir = np.asarray(u_dir, float), np.asarray(v_dir, float)
    rel = P - np.asarray(origin, float)
    u = rel @ u_dir / cell
    v = -(rel @ v_dir) / cell                 # rows run downward
    ok = (N @ np.asarray(facing, float)) > 0.7
    ok &= np.abs(rel @ np.cross(u_dir, v_dir)) < 0.004
    out = np.zeros(P.shape[:-1], bool)
    col = np.floor(u).astype(int)
    row = np.floor(v).astype(int)
    x = 0
    for ch in text.upper():
        g = GLYPHS.get(ch, GLYPHS[" "])
        for r, line in enumerate(g):
            for c, pix in enumerate(line):
                if pix == "#":
                    out |= ok & (col == x + c) & (row == r)
        x += 4
    return out


# ------------------------------------------------------------------ the gun
# Places, in Godot viewmodel space (metres), where construction and use put
# things. They come from build_foundry_study.py and are kept in step with it.

BORE_Y = 0.030
BREECH = ((0.0, BORE_Y, -0.158), (0.0, BORE_Y, -0.096))
MUZZLE = ((0.0, BORE_Y, -0.470), (0.0, BORE_Y, -0.440))
GAP_Z = -0.096                      # carousel front face meets the breech
CAROUSEL_C = (0.0, BORE_Y - 0.024, -0.061)
HAMMER_PIN = ((-0.025, 0.052, -0.022), (0.025, 0.052, -0.022))
AXLE_ENDS = [(0.0, BORE_Y - 0.024, -0.100), (0.0, BORE_Y - 0.024, -0.022)]
BUFFER_FRONT = (0.0, -0.030, -0.335)
GRIP_TOP = np.array([0.0, -0.044, 0.022])
GRIP_DIR = np.array([0.0, -np.cos(np.radians(17)), np.sin(np.radians(17))])
GRIP_FV = np.array([0.0, np.sin(np.radians(17)), np.cos(np.radians(17))])

#: Texture-only welds (the three raised beads are geometry, painted below).
WELDS_FLAT = [
    # bottom strap to front web, left
    [(-0.0212, -0.0352, -0.158), (-0.0212, -0.0355, -0.130),
     (-0.0212, -0.0350, -0.101)],
    # clamp to buffer: a tack the armourer added after it walked
    [(-0.0185, -0.040, -0.296), (-0.0150, -0.046, -0.296)],
]
#: A crack in the front web, welded and ground roughly flat.
CRACK = [(-0.0192, -0.031, -0.150), (-0.0192, -0.025, -0.1465),
         (-0.0192, -0.020, -0.1445), (-0.0192, -0.013, -0.1395),
         (-0.0192, -0.008, -0.1380), (-0.0192, -0.001, -0.1330)]
#: Angle-grinder discs: centre, axis (face normal), radius.
GRINDS = [((-0.0192, -0.016, -0.135), (-1, 0, 0), 0.014),
          ((-0.006, 0.0575, -0.088), (0, 1, 0), 0.010)]
#: Where water sits and rust starts: (centre, radius).
RUST_ZONES = [((-0.0235, -0.033, 0.018), 0.012),    # patch's lower edge
              ((0.0, -0.035, -0.060), 0.020),       # floor of the window
              ((0.0, -0.030, -0.348), 0.010),       # buffer cap
              ((0.0, -0.046, -0.318), 0.010)]       # clamp foot
#: Wrench marks: (bolt centre, face normal) -- a spanner slipped here.
WRENCHED = [((-0.0225, 0.0, -0.308), (-1, 0, 0)),
            ((-0.0545, -0.013, -0.131), (-1, 0, 0)),
            ((-0.0240, 0.020, -0.008), (-1, 0, 0))]
#: Contact zones: (centre, radius, strength).
CONTACT = [((0.0, 0.118, 0.024), 0.012, 1.0),      # hammer spur (cocked)
           ((-0.0656, 0.0649, -0.1131), 0.012, 0.7),  # core cap, by hand
           ((-0.0215, 0.050, 0.010), 0.020, 0.6),  # cheek tops, hand rest
           ((-0.020, -0.050, 0.004), 0.016, 0.7),  # frame under-edge, holster
           ((0.0, 0.0115, -0.470), 0.022, 0.5),    # crown, set down on it
           ((0.0, -0.046, -0.318), 0.016, 0.6)]    # clamp foot, rests on it


#: Scratch fields: where the gun is set down, drawn and leaned on. Each is
#: (a point on the face, its normal, its two in-face axes, spread (m),
#: count, main direction in-face as (along a, along b)).
SCRATCH_ZONES = [
    # frame's left side, low and to the rear: set down on benches
    ((-0.0215, -0.028, 0.028), (-1, 0, 0), (0, 0, 1), (0, 1, 0), 0.020,
     9, (1.0, 0.25)),
    # top strap's left face
    ((-0.0136, 0.0515, -0.062), (-1, 0, 0), (0, 0, 1), (0, 1, 0), 0.030,
     7, (1.0, 0.05)),
    # barrel, lower-left flat: drawn from a holster, along its length
    ((-0.0147, 0.0153, -0.300), (-0.7071, -0.7071, 0), (0, 0, 1),
     (0.7071, -0.7071, 0), 0.10, 8, (1.0, 0.02)),
]
_SCRATCH_CACHE = {}


def scratches(P, N, H, W):
    """Thin scratches through a coating, in the zones use put them. A
    mask in 0..1 (cached: the painted and barrel passes both read it)."""
    if "m" in _SCRATCH_CACHE:
        return _SCRATCH_CACHE["m"]
    rng = np.random.default_rng(1013)
    out = np.zeros((H, W))
    for c0, nrm, ua, ub, spread, count, (da, db) in SCRATCH_ZONES:
        c0, nrm = np.asarray(c0, float), np.asarray(nrm, float)
        ua, ub = np.asarray(ua, float), np.asarray(ub, float)
        face = (N @ nrm) > 0.8
        for _ in range(count):
            a = c0 + ua * rng.uniform(-spread, spread) + ub * rng.uniform(
                -spread * 0.4, spread * 0.4)
            d = ua * (da + rng.normal(0, 0.25)) + ub * (db + rng.normal(0,
                                                                     0.25))
            d /= np.linalg.norm(d)
            ln = rng.uniform(0.010, 0.032)
            dd, t = seg_dist(P, a - d * ln / 2, a + d * ln / 2)
            # deeper in the middle of the stroke, lifting off at its ends;
            # at least a texel wide (0.86 mm) or it renders as dots
            depth = np.sin(np.pi * t) ** 0.5
            out = np.maximum(out, smooth(0.0011, 0.0005, dd) * depth * face)
    _SCRATCH_CACHE["m"] = out
    return out


def load(bake):
    B = {k: np.load(os.path.join(bake, k + ".npy"))
         for k in ("id", "pos", "nrm", "edge", "ao")}
    cover = np.load(os.path.join(bake, "cover.npy"))
    meta = json.load(open(os.path.join(bake, "bake.json")))
    # Blender (x, y, z) -> Godot (x, z, -y)
    pb, nb = B["pos"][..., :3], B["nrm"][..., :3]
    P = np.stack([pb[..., 0], pb[..., 2], -pb[..., 1]], -1).astype(np.float64)
    N = np.stack([nb[..., 0], nb[..., 2], -nb[..., 1]], -1).astype(np.float64)
    N /= np.maximum(np.linalg.norm(N, axis=-1, keepdims=True), 1e-9)
    cls = np.rint(B["id"][..., 0] * 255).astype(int)
    part = np.rint(B["id"][..., 1] * 255).astype(int)
    edge = np.clip(B["edge"][..., 0] * 2.6, 0.0, 1.0)
    ao = np.clip(B["ao"][..., 0], 0.0, 1.0)
    return dict(P=P, N=N, cls=cls, part=part, edge=edge, ao=ao, cover=cover,
                meta=meta)


def paint(D):
    P, N, cls, part = D["P"], D["N"], D["cls"], D["part"]
    edge, ao = D["edge"], D["ao"]
    parts = D["meta"]["parts"]
    pid = {k: v for k, v in parts.items()}
    H, W = cls.shape

    def is_part(*names):
        m = np.zeros((H, W), bool)
        for n in names:
            if n in pid:
                m |= part == pid[n]
        return m

    col = np.zeros((H, W, 3))
    rough = np.full((H, W), 0.6)
    metal = np.zeros((H, W))
    height = np.full((H, W), 0.5)
    emit = np.zeros((H, W, 3))

    convex = edge * smooth(0.45, 0.8, ao)
    # which edges take knocks: the bottom (set down), the two ends (the
    # muzzle and the frame's back), the outermost corners -- not the
    # sheltered top edges by the hammer
    bottom = smooth(0.0, -0.045, P[..., 1])
    ends = smooth(-0.40, -0.47, P[..., 2]) + smooth(0.040, 0.068, P[..., 2])
    exposure = np.clip(0.15 + 0.65 * bottom + 0.5 * ends
                       + 0.35 * (fbm(P, 60.0, 3) - 0.5), 0.0, 1.0)
    cavity = 1.0 - smooth(0.25, 0.85, ao)
    up = np.clip(N[..., 1], 0, 1)
    down = np.clip(-N[..., 1], 0, 1)

    # ---------------------------------------------------------- fields
    hb, _ = seg_dist(P, *BREECH)
    hm, _ = seg_dist(P, *MUZZLE)
    heat_breech = np.exp(-np.maximum(hb - 0.028, 0) / 0.016)
    heat_muzzle = np.exp(-np.maximum(hm - 0.022, 0) / 0.012)
    heat = np.maximum(heat_breech, 0.8 * heat_muzzle)
    contact = np.zeros((H, W))
    for c, r, s in CONTACT:
        d = np.linalg.norm(P - np.asarray(c), axis=-1)
        contact = np.maximum(contact, s * smooth(r, r * 0.35, d))
    # oil: pivots and slides, and the runs they leave downward
    oil = np.zeros((H, W))
    d, _ = seg_dist(P, *HAMMER_PIN)
    oil = np.maximum(oil, smooth(0.016, 0.004, d))
    for a in AXLE_ENDS:
        oil = np.maximum(oil, smooth(0.020, 0.006,
                                     np.linalg.norm(P - np.asarray(a), axis=-1)))
    oil = np.maximum(oil, smooth(0.018, 0.005, np.linalg.norm(
        P - np.asarray(BUFFER_FRONT), axis=-1)))
    # a run from the hammer pin, down the left cheek and frame
    run_x = np.abs(P[..., 2] - (-0.018 + 0.004 * np.sin(P[..., 1] * 260)))
    run = (smooth(0.0030, 0.0008, run_x) * smooth(0.055, 0.020, P[..., 1])
           * smooth(-0.030, 0.000, P[..., 1]) * (N[..., 0] < -0.7))
    oil = np.maximum(oil, 0.8 * run)
    # gas: the muzzle face and the carousel-breech gap (flame cutting)
    gap = np.exp(-np.abs(P[..., 2] - GAP_Z) / 0.010) * smooth(
        0.06, 0.03, np.linalg.norm(P[..., :2] - [0, BORE_Y], axis=-1))
    soot = np.maximum(0.9 * heat_muzzle * smooth(-0.42, -0.465, P[..., 2]),
                      0.8 * gap)
    soot = np.maximum(soot, 0.55 * heat_breech * (P[..., 2] < -0.150))

    rust_zone = np.zeros((H, W))
    for c0, r in RUST_ZONES:
        rust_zone = np.maximum(rust_zone, smooth(
            r, r * 0.3, np.linalg.norm(P - np.asarray(c0), axis=-1)))
    pits = smooth(0.56, 0.66, fbm(P, 420.0, 13)) * rust_zone
    n1 = fbm(P, 180.0, 1)          # breakup of mask edges, ~5 mm
    n2 = fbm(P, 520.0, 2)          # finer, ~2 mm
    n3 = fbm(P, 60.0, 3)           # broad, ~16 mm

    # ======================================================== painted steel
    m = cls == CLS["painted"]
    weld_parts = is_part("weld_strap_breech", "weld_web_breech",
                         "weld_block_strap")
    # base metal under the paint
    steel = mix(STEEL_MID, STEEL_BRIGHT, 0.35 + 0.3 * n2)
    # the topcoat: station trim, dulled by years -- darker than new, warmer
    # where grime has worked in, a little bleached on the faces that look up
    fade = 0.5 * smooth(0.2, 0.9, up) + 0.5 * (n3 - 0.5)
    coat = ramp(FACILITY_TRIM, 0.30 + 0.10 * fade)
    coat = mix(coat, GRIME[1], 0.20 + 0.10 * (1 - fade))
    # runs: faint vertical streaks where condensation and oil ran down
    streaks = vnoise(P * np.array([1.0, 0.08, 1.0]), 420.0, 5)
    side = (np.abs(N[..., 1]) < 0.5).astype(float)
    coat = mix(coat, GRIME[0], 0.12 * smooth(0.55, 0.8, streaks) * side)
    # touch-up: the gusset and the strap round it were brushed with paint
    # from another tin after the weld -- close, not the same
    touch = (np.linalg.norm(P - [-0.010, 0.052, -0.034], axis=-1) < 0.016)
    touch &= m
    brush = 0.5 + 0.5 * np.sin((P[..., 2] * 1.0 + P[..., 1] * 0.25) * 2400.0
                               + 6.0 * n1)
    coat = np.where(touch[..., None],
                    ramp([FACILITY_TRIM[0], hx("#4b5048"), hx("#6a6e64")],
                         0.45 + 0.1 * brush), coat)
    # wear: chips at convex edges and where it is handled; primer rings
    # the bare metal, as a chip in a two-coat finish does
    # broken into flakes by a ~4 mm field, so an edge is chipped in places
    # and intact in others: never one continuous bright line
    # The flake field decides WHERE along an edge it chipped; edges and
    # contact only raise the odds: about a quarter of an exposed chamfer
    # is through to metal, open faces almost never, handled zones mostly.
    flake = fbm(P, 240.0, 7)
    wear_n = (flake + 0.32 * convex * exposure + 0.10 * heat_breech - 0.27
              + 0.9 * scratches(P, N, H, W))
    to_primer = smooth(0.47, 0.50, wear_n)
    to_metal = smooth(0.52, 0.55, wear_n)
    # hands do not chip paint, they polish it thin: a soft gradient to
    # primer, then to metal where the hold is hardest
    thin = smooth(0.25, 0.95, contact)
    to_primer = np.maximum(to_primer, smooth(0.45, 0.8, thin
                                             + 0.15 * (n3 - 0.5)))
    to_metal = np.maximum(to_metal, smooth(0.75, 0.95, thin
                                           + 0.1 * (flake - 0.5)))
    c = mix(coat, PRIMER, to_primer)
    c = mix(c, steel, to_metal)
    # heat: paint near the breech burnt brown and lifting, steel tempered
    burnt = smooth(0.45, 0.9, heat_breech + 0.15 * (n1 - 0.5))
    c = mix(c, mix(c * 0.55, GRIME[1], 0.5), burnt * (1 - to_metal) * 0.8)
    temper = ramp(TEMPER, np.clip(1.2 - heat_breech * 1.3 + 0.2 * n2, 0, 1))
    c = mix(c, temper, to_metal * smooth(0.3, 0.8, heat_breech))
    col[m] = c[m]
    rough[m] = (0.62 - 0.22 * to_metal - 0.2 * thin + 0.15 * burnt)[m]
    metal[m] = (METAL_SHOW * to_metal)[m]
    height[m] = (0.5 + 0.025 * (1 - to_metal) + 0.012 * (1 - to_primer)
                 + 0.02 * burnt * (n2 - 0.5)
                 + 0.004 * (n2 - 0.5) * (1 - to_metal))[m]

    # the raised welds: rippled beads, painted over, chipped on the ridges
    for name in ("weld_strap_breech", "weld_web_breech", "weld_block_strap"):
        wm = is_part(name)
        if not wm.any():
            continue
        # ripple along the bead: a coarse phase from the world position
        ph = (P[..., 0] * 37 + P[..., 1] * 53 + P[..., 2] * 41) * 280.0
        rip = 0.5 + 0.5 * np.sin(ph + 2.0 * n1)
        lump = 0.5 + 0.5 * n2
        hgt = 0.55 + 0.08 * rip + 0.03 * lump
        chipped = smooth(0.62, 0.75, rip * 0.6 + n1 * 0.6)
        wc = mix(mix(coat, GRIME[0], 0.3),
                 mix(STEEL_MID, TEMPER[1], 0.5) * 0.8, 0.7 * chipped)
        col[wm] = wc[wm]
        height[wm] = hgt[wm]
        rough[wm] = (0.55 - 0.15 * chipped)[wm]
        metal[wm] = (METAL_SHOW * chipped)[wm]

    # texture-only welds and the halo of heat they left in the paint
    for pts in WELDS_FLAT:
        d, arc = poly_dist(P, pts)
        bead = smooth(0.0030, 0.0012, d) * m
        halo = smooth(0.010, 0.003, d) * m * (1 - bead)
        rip = 0.5 + 0.5 * np.sin(arc * 2600.0 + 3 * n1)
        col = mix(col, mix(col, TEMPER[1], 0.45), halo)
        col = mix(col, mix(STEEL_MID, GRIME[1], 0.4 + 0.3 * rip), bead)
        height = height + bead * (0.05 + 0.04 * rip)
        rough = np.where(bead > 0.5, 0.5, rough)
    # the ground crack: a flat, bright, swirl-marked scar along a zig-zag
    d, arc = poly_dist(P, CRACK)
    scar = smooth(0.0030, 0.0012, d + 0.0008 * (n1 - 0.5)) * (cls == 1)
    halo = smooth(0.008, 0.003, d) * (cls == 1) * (1 - scar)
    col = mix(col, mix(col, TEMPER[1], 0.5), halo)
    rip = 0.5 + 0.5 * np.sin(arc * 2600)
    col = mix(col, mix(STEEL_MID, TEMPER[0], 0.3 + 0.2 * rip), scar)
    height = height + 0.02 * scar + 0.012 * scar * rip
    metal = np.maximum(metal, METAL_SHOW * scar)
    rough = np.where(scar > 0.5, 0.3, rough)
    # grinder discs: concentric arcs in bare steel, paint feathered off
    for c0, ax, r in GRINDS:
        rel = P - np.asarray(c0)
        axv = np.asarray(ax, float)
        rr = np.linalg.norm(rel - (rel @ axv)[..., None] * axv, axis=-1)
        face = (N @ axv) > 0.7
        disc = smooth(r, r * 0.7, rr + 0.004 * (n1 - 0.5)) * face * (cls == 1)
        rings = 0.5 + 0.5 * np.sin(rr * 2600.0 + 4 * n1)
        # ground bright, then half painted over again by a hurried brush
        redone = smooth(0.45, 0.6, n1)
        bare_ = mix(STEEL_MID, STEEL_BRIGHT, 0.2 + 0.25 * rings) * 0.9
        col = mix(col, mix(bare_, coat, 0.8 * redone), disc * 0.85)
        height = height + disc * 0.010 * (rings - 0.5)
        rough = mix(rough, 0.35 + 0.15 * rings, disc)
        metal = np.maximum(metal, METAL_SHOW * disc)

    # ============================================================== the patch
    # a cut plate in another area's primer, edges brushed in station grey
    m = cls == CLS["patch"]
    blot = fbm(P, 150.0, 17)
    prim = ramp(RUST_TRIM, 0.18 + 0.35 * (blot - 0.5) + 0.1 * (n3 - 0.5))
    prim = mix(prim, GRIME[1], 0.25 + 0.2 * smooth(0.5, 0.7, blot))
    # someone ran a brush of station grey round its edges to blend it in,
    # and gave up: strokes along the edge, thinning toward the middle
    rel_e = np.minimum(np.abs(P[..., 1] - 0.027), np.abs(P[..., 1] + 0.034))
    rel_e = np.minimum(rel_e, np.minimum(np.abs(P[..., 2] + 0.015),
                                         np.abs(P[..., 2] - 0.050)))
    strokes = vnoise(P * np.array([1.0, 1.0, 0.15]), 900.0, 19)
    edge_paint = smooth(0.012, 0.003, rel_e + 0.006 * (strokes - 0.5))
    c = mix(prim, ramp(FACILITY_TRIM, 0.35), edge_paint * 0.85)
    # oxy-cut edges: dark, rough, slag-pitted
    cut = smooth(0.55, 0.9, edge) * (1 - smooth(0.5, 0.8, ao) * 0.3)
    c = mix(c, GRIME[0], cut * 0.6)
    chips = smooth(0.55, 0.65, 0.8 * convex + 0.6 * (n1 - 0.5) + 0.2)
    c = mix(c, STEEL_MID, chips * (1 - cut))
    c = mix(c, ramp(RUST_BASE, 0.4 + 0.3 * n1), pits)
    col[m] = c[m]
    rough[m] = (0.72 - 0.25 * chips + 0.15 * cut + 0.1 * pits)[m]
    metal[m] = (METAL_SHOW * chips)[m]
    height[m] = (0.5 + 0.02 * (1 - chips) - 0.03 * cut * n2)[m]
    # a service note in grease pencil, and the screw and rivet the plate
    # also wears (texture only: they are below the geometry budget)
    # (a left face reads along +Z, seen from outside)
    # grease-pencil service tallies: four strokes and a cross-stroke per
    # five services, then two more, and a tick -- drawn, not typed
    strokes = []
    for k in range(7):
        z0 = -0.004 + 0.0034 * k + (0.0026 if k >= 5 else 0.0)
        strokes.append(((z0, 0.020), (z0 + 0.0008, 0.010)))
    strokes.append(((-0.005, 0.012), (0.012, 0.019)))      # the gate
    strokes.append(((0.024, 0.016), (0.026, 0.013)))       # the tick
    strokes.append(((0.026, 0.013), (0.031, 0.021)))
    pen = np.zeros((H, W), bool)
    for (za, ya), (zb, yb) in strokes:
        d, _ = seg_dist(P, (-0.0241, ya, za), (-0.0241, yb, zb))
        pen |= d < 0.00055
    pen &= m & (N[..., 0] < -0.7) & (n1 > 0.33)
    col[pen] = mix(col, CHALK, 0.38)[pen]
    rough[pen] = 0.85
    for (cy, cz, kind) in ((0.020, 0.042, "screw"), (-0.027, -0.008, "rivet")):
        dd = np.linalg.norm(P[..., 1:] - [cy, cz], axis=-1)
        head = (dd < 0.0034) & m & (N[..., 0] < -0.7)
        dome = np.clip(1 - dd / 0.0034, 0, 1)
        height[head] = (0.5 + 0.06 * np.sqrt(dome))[head]
        col[head] = mix(STEEL_MID, GRIME[1], 0.3 + 0.3 * n2)[head]
        metal[head] = METAL_SHOW
        rough[head] = 0.45
        if kind == "screw":
            slot = head & (np.abs((P[..., 1] - cy) + 0.6 * (P[..., 2] - cz))
                           < 0.0006)
            height[slot] = 0.44
            col[slot] = GRIME[0]

    # ========================================================== bare steel
    m = cls == CLS["bare"]
    blued = mix(BLUED, DEAD[1], 0.3 + 0.2 * n3)
    # knocks chip the oxide at exposed edges; thumbs and fingers polish it
    # off smoothly -- a gradient, not flakes
    chip = smooth(0.50, 0.56, fbm(P, 240.0, 8)
                  + 0.40 * convex * (0.3 + exposure) - 0.30)
    polish = smooth(0.3, 0.95, contact) * (0.75 + 0.25 * n3)
    bright = np.maximum(chip, polish)
    c = mix(blued, mix(STEEL_MID, STEEL_BRIGHT, 0.35 + 0.3 * n1), bright)
    # rust bloom only deep in recesses, away from the oil
    rust = pits * (1 - oil)
    c = mix(c, ramp(RUST_BASE, 0.3 + 0.4 * n2), rust * 0.55)
    col[m] = c[m]
    rough[m] = (0.42 - 0.18 * bright - 0.15 * oil + 0.25 * rust)[m]
    metal[m] = (METAL_SHOW + 0.1 * bright - 0.25 * rust)[m]
    height[m] = (0.5 - 0.01 * rust * n2)[m]
    # the carousel: lathe rings on its faces and the turn line the stop
    # drags round it
    cm = is_part("carousel") & m
    rel = P - np.asarray(CAROUSEL_C)
    rr = np.linalg.norm(rel[..., :2], axis=-1)
    lathe = 0.5 + 0.5 * np.sin(rr * 2400.0)
    face = np.abs(N[..., 2]) > 0.8
    height[cm & face] = (height + 0.006 * (lathe - 0.5))[cm & face]
    turn = cm & ~face & (np.abs(rel[..., 2] - 0.026) < 0.0022)
    col[turn] = mix(col, STEEL_MID, 0.55)[turn]
    rough[turn] = 0.25
    height[turn] = 0.49
    # chamber mouths on the front face: the slug blanks seated in ceramic
    # cups, five of six visible (the sixth is in the collar)
    for k in range(6):
        a = np.radians(90 + 60 * k)
        cc = np.array([0.024 * np.cos(a), CAROUSEL_C[1] + 0.024 * np.sin(a)])
        dd = np.linalg.norm(P[..., :2] - cc, axis=-1)
        fm = cm & (N[..., 2] < -0.8)
        rim = fm & (dd < 0.0105)
        cup = fm & (dd < 0.0090)
        blank = fm & (dd < 0.0072)
        col[rim] = mix(STEEL_BRIGHT, GRIME[0], 0.2)
        col[cup] = mix(CERAMIC, GRIME[1], 0.35 + 0.3 * n2)[cup]
        col[blank] = mix(STEEL_MID, GRIME[0], 0.25 + 0.3 * n2)[blank]
        height[rim] = 0.47
        height[cup] = 0.44
        height[blank] = 0.43 + 0.01 * n2[blank]
        metal[cup] = 0.0
        rough[cup] = 0.8
    # soot on the carousel's front face: gas through the gap
    sm = cm & (N[..., 2] < -0.8)
    col[sm] = mix(col, GRIME[0], 0.45 * smooth(0.2, 0.8, n1))[sm]
    # hammer: forged dents on its flanks, knurled spur, peened face
    hm_ = is_part("hammer") & m
    dents = smooth(0.64, 0.76, fbm(P, 350.0, 9))
    height[hm_] = (height - 0.012 * dents)[hm_]
    sp = is_part("hammer_spur") & m
    # knurling: crossed diagonal grooves, read as relief, not as colour
    kn = ((np.sin((P[..., 0] + P[..., 2]) * 2200) > 0.55)
          | (np.sin((P[..., 0] - P[..., 2]) * 2200) > 0.55))
    height[sp & (N[..., 1] > 0.3)] = np.where(kn, 0.47, 0.53)[sp & (N[..., 1]
                                                                  > 0.3)]
    col[sp] = mix(col, GRIME[0], 0.25 * kn)[sp]
    # the striker: battered, mushroomed edge, bright on top
    st = is_part("striker") & m
    top_ = st & (N[..., 1] > 0.8)
    peen = smooth(0.40, 0.85, fbm(P, 420.0, 11))
    col[top_] = mix(mix(STEEL_BRIGHT, STEEL_MID, 0.45), STEEL_MID, 0.2 * peen)[top_]
    height[top_] = (0.5 - 0.025 * peen)[top_]
    rough[top_] = 0.25

    # ============================================================== barrel
    m = cls == CLS["barrel"]
    blue = mix(hx("#353a40"), DEAD[1], 0.3 + 0.3 * n3)
    # polishing scratches along the bore, finer than a paint chip
    streak = 0.5 + 0.5 * np.sin(P[..., 0] * 2200 + P[..., 1] * 1800
                                + 9 * n1)
    bw = (fbm(P, 240.0, 7) + 0.40 * convex * exposure + 0.35 * contact
          + 0.03 * streak - 0.32 + 0.9 * scratches(P, N, H, W))
    bright = smooth(0.50, 0.56, bw)
    c = mix(blue, mix(STEEL_MID, STEEL_BRIGHT, 0.6), bright)
    # temper: straw to bronze to violet-grey outward from each hot end
    tm = np.clip(np.maximum(heat_muzzle, 0.7 * heat_breech)
                 * (0.7 + 0.6 * n1), 0, 1)
    c = mix(c, ramp(TEMPER, 0.55 - 0.45 * tm), smooth(0.25, 0.75, tm) * 0.45)
    c = mix(c, GRIME[0], soot * 0.8)
    col[m] = c[m]
    rough[m] = (0.38 - 0.12 * bright + 0.45 * soot + 0.05 * streak)[m]
    metal[m] = (METAL_SHOW + 0.1 * bright - 0.3 * soot)[m]
    height[m] = (0.5 + 0.004 * (streak - 0.5))[m]
    # the bore: dark, sooted
    bore = is_part("bore") & m
    col[bore] = GRIME[0] * 0.6
    rough[bore] = 0.9
    # stamped on the barrel's upper-left flat near the breech: maker's
    # number and a proof mark -- dents, not paint
    flat_v = (0.7071, 0.7071, 0.0)
    stamp = lettering(P, N, "FDY-3 0417", (-0.0128, 0.0466, -0.236),
                      (0, 0, 1), flat_v, (-0.7071, 0.7071, 0), 0.0011)
    stamp |= lettering(P, N, "P", (-0.0128, 0.0466, -0.250),
                       (0, 0, 1), flat_v, (-0.7071, 0.7071, 0), 0.0011)
    stamp &= m
    height[stamp] = 0.43
    col[stamp] = mix(col, GRIME[0], 0.55)[stamp]

    # ====================================================== Epsilon collar
    # dense, satin, machined to a tolerance the station doesn't work to:
    # a fine regular texture visible only close up, crisp edges, almost no
    # wear -- except where the station's own strap and bracket bit into it
    m = cls == CLS["epsilon"]
    ang = np.arctan2(P[..., 1] - BORE_Y, P[..., 0])
    fine = 0.5 + 0.5 * np.sin(ang * 110.0)              # radial facets
    c = mix(hx("#16171a"), hx("#24262a"), 0.4 + 0.3 * fine)
    edge_lit = smooth(0.6, 0.95, convex)
    c = mix(c, hx("#4a4e55"), edge_lit * 0.6)
    bite = np.zeros((H, W))
    for z0 in (-0.131, -0.118):
        bite = np.maximum(bite, smooth(0.006, 0.0015,
                                       np.abs(P[..., 2] - z0)
                                       + 0.002 * (n1 - 0.5)))
    c = mix(c, mix(hx("#5c5f62"), GRIME[1], 0.3), bite * 0.7)
    c = mix(c, GRIME[0], soot * 0.6)
    col[m] = c[m]
    rough[m] = (0.30 + 0.06 * fine + 0.2 * bite + 0.3 * soot)[m]
    metal[m] = (0.25 + 0.15 * bite)[m]
    height[m] = (0.5 + 0.004 * (fine - 0.5) - 0.012 * bite)[m]

    # ============================================================== ceramic
    m = cls == CLS["ceramic"]
    # crazing: a thin network of hairline cracks, not a speckle
    craze = smooth(0.012, 0.004, np.abs(fbm(P, 220.0, 21) - 0.5))
    c = mix(CERAMIC, FACILITY_LIGHT[0], 0.3 * n3)
    c = mix(c, GRIME[0], (0.25 + 0.6 * smooth(0.0, 0.02, P[..., 1] + 0.004))
            * (0.6 + 0.4 * n1) * 0.8)
    c = mix(c, GRIME[0], craze * 0.35)
    chip = smooth(0.62, 0.7, convex * exposure + 0.3 * (n1 - 0.5))
    c = mix(c, hx("#e6e2d8"), chip)
    col[m] = c[m]
    rough[m] = 0.82
    height[m] = (0.5 - 0.015 * craze - 0.03 * chip)[m]

    # ================================================================ core
    # placeholder material: dense, glassy, banded like something grown --
    # the source identity package will replace it. Clean: it is handled
    # with care, so only smudges on its gloss
    m = cls == CLS["core"]
    rel = P - P[m].mean(0) if m.any() else P
    band = 0.5 + 0.5 * np.sin((rel @ np.array([0.3, 0.2, 0.93])) * 900.0
                              + 5 * n1)
    c = mix(CORE_DARK, CORE_BAND, 0.25 * band + 0.1 * n2)
    col[m] = c[m]
    rough[m] = (0.10 + 0.25 * smooth(0.55, 0.8, fbm(P, 300.0, 33)))[m]
    metal[m] = 0.1
    height[m] = 0.5

    # ================================================================ tape
    m = cls == CLS["tape"]
    rel = P - GRIP_TOP
    t = rel @ GRIP_DIR                       # down the grip
    a = np.arctan2(rel @ GRIP_FV, P[..., 0])
    wrap_ph = (t * 1.0 / 0.016 + a / (2 * np.pi)) % 1.0   # helical wraps
    ridge = smooth(0.0, 0.08, wrap_ph) * smooth(1.0, 0.85, wrap_ph)
    weave = ((np.sin(t * 2400) > 0) ^ (np.sin(a * 30) > 0)).astype(float)
    held = smooth(0.0, 0.03, t) * smooth(0.11, 0.07, t)
    palm = held * (0.5 + 0.5 * np.clip(-(rel @ GRIP_FV) / 0.02, 0, 1))
    c = mix(TAPE, TAPE_DARK, 0.12 * (1 - ridge) + 0.5 * palm + 0.12 * n1)
    # the top wraps are newer black electrical tape over the old cloth
    et = t < 0.016
    c = np.where(et[..., None], mix(ETAPE, GRIME[1], 0.2 * n2), c)
    frayed = (np.abs(t - 0.106) < 0.003) & (n1 > 0.6)
    c = np.where(frayed[..., None], mix(TAPE, CHALK, 0.2), c)
    col[m] = c[m]
    rough[m] = np.where(et, 0.45, 0.88 - 0.3 * palm)[m]
    metal[m] = 0.0
    height[m] = np.where(et, 0.5 + 0.02 * ridge,
                         0.5 + 0.02 * ridge + 0.008 * weave)[m]

    # ========================================================= cable, rubber
    m = cls == CLS["cable"]
    braid = ((np.sin((P[..., 2] + P[..., 1]) * 2400) > 0)
             ^ (np.sin((P[..., 2] - P[..., 1]) * 2400) > 0)).astype(float)
    c = mix(hx("#3a3d40"), hx("#686c70"), 0.35 * braid + 0.2 * convex)
    c = mix(c, GRIME[0], cavity * 0.6)
    col[m] = c[m]
    rough[m] = 0.5
    metal[m] = METAL_SHOW
    height[m] = (0.5 + 0.02 * braid)[m]
    m = cls == CLS["rubber"]
    col[m] = mix(hx("#141414"), GRIME[1], 0.15 * n2)[m]
    rough[m] = 0.85
    height[m] = (0.5 - 0.01 * smooth(0.6, 0.7, fbm(P, 900.0, 41)))[m]

    # ======================================================= straps, nuts
    m = cls == CLS["strap"]
    scale_ = mix(hx("#2b2d30"), hx("#55585b"), smooth(0.4, 0.6, n1))
    bentd = smooth(0.6, 0.72, fbm(P, 650.0, 51))
    c = mix(scale_, ramp(RUST_BASE, 0.4), cavity * 0.6 * (1 - oil))
    c = mix(c, STEEL_MID, smooth(0.5, 0.8, convex) * 0.6)
    c = mix(c, TEMPER[1], heat_breech * 0.4)
    col[m] = c[m]
    rough[m] = (0.62 - 0.2 * convex)[m]
    metal[m] = METAL_SHOW
    height[m] = (0.5 - 0.025 * bentd)[m]

    m = cls == CLS["fastener"]
    # mismatched: each fastener picks its finish from its own position
    pick = cellhash(P, 0.02, 61)
    zinc = mix(hx("#9a9a8c"), hx("#b9b39a"), n2)
    black = mix(hx("#1e1f21"), hx("#3a3c3f"), n2)
    rusty = ramp(RUST_BASE, 0.3 + 0.5 * n1)
    fin = np.where((pick < 0.4)[..., None], zinc,
                   np.where((pick < 0.8)[..., None], black, rusty))
    fin = mix(fin, STEEL_BRIGHT, smooth(0.5, 0.85, convex) * 0.7)
    col[m] = fin[m]
    rough[m] = np.where(pick < 0.4, 0.35, np.where(pick < 0.8, 0.5, 0.8))[m]
    metal[m] = np.where(pick < 0.8, METAL_SHOW, 0.2)[m]
    height[m] = 0.5

    # ======================================================== the one lamp
    m = cls == CLS["lamp"]
    col[m] = IDENTITY[0]
    emit[m] = IDENTITY[2] * 0.85
    rough[m] = 0.1
    metal[m] = 0.0
    height[m] = 0.52

    # ================================================= over everything
    # dirt and dust where it collects; grease near the pivots; soot
    station = np.isin(cls, [CLS[k] for k in ("painted", "bare", "patch",
                                             "strap", "fastener", "cable")])
    dirt = smooth(0.30, 0.90, cavity) * (0.75 + 0.25 * n3) * station
    col = mix(col, GRIME[0], 0.55 * dirt)
    dust = cavity * up * smooth(0.45, 0.65, n1) * station
    col = mix(col, GRIME[2], 0.45 * dust)
    rough = np.maximum(rough, 0.85 * dust)
    grease = oil * station
    col = mix(col, GRIME[0] * 0.8, 0.6 * grease)
    rough = mix(rough, 0.18, grease)
    soot_all = soot * station
    col = mix(col, GRIME[0] * 0.7, 0.55 * soot_all * (cls != CLS["barrel"]))
    rough = mix(rough, 0.9, soot_all * 0.6)

    # torque stripes: paint pen across bolt heads onto the part, where a
    # mechanic checked them (bracket and clamp bolts, not the patch's)
    for cen, ax in (((-0.0545, -0.013, -0.131), (-1, 0, 0)),
                    ((-0.0225, 0.0, -0.308), (-1, 0, 0))):
        rel = P - np.asarray(cen)
        on = (N @ np.asarray(ax, float)) > 0.6
        line = (np.abs(rel[..., 1] * 0.9 + rel[..., 2] * 0.45) < 0.0011) & (
            np.linalg.norm(rel, axis=-1) < 0.009) & on
        col[line] = mix(col, CHALK, 0.85)[line]
        rough[line] = 0.7
    for cen, ax in WRENCHED:
        rel = P - np.asarray(cen)
        axv = np.asarray(ax, float)
        rr = np.linalg.norm(rel - (rel @ axv)[..., None] * axv, axis=-1)
        ang = np.arctan2(rel[..., 1], rel[..., 2])
        arc = ((rr > 0.0058) & (rr < 0.0072) & (np.sin(ang * 1.0 + 1.1) > 0.35)
               & ((N @ axv) > 0.7) & station)
        col[arc] = mix(col, STEEL_BRIGHT, 0.7)[arc]
        metal[arc] = METAL_SHOW
        rough[arc] = 0.3
        height[arc] = height[arc] - 0.015
    # stencils, station style: the gun's number on the top strap, a heat
    # warning on the breech block, both faded and partly worn through
    st1 = lettering(P, N, "F3", (-0.0136, 0.0535, -0.075), (0, 0, 1),
                    (0, 1, 0), (-1, 0, 0), 0.0013)
    # on the top strap's top, read from behind: across the strap
    st2 = lettering(P, N, "HOT", (-0.0080, 0.0570, -0.066), (1, 0, 0),
                    (0, 0, -1), (0, 1, 0), 0.0014)
    # faded unevenly, worn thinner where it is handled, never lost whole
    sten = (st1 | st2) & (cls == CLS["painted"])
    col[sten] = mix(col, CHALK, 0.25 + 0.25 * n1 - 0.2 * thin)[sten]

    return col, rough, metal, height, emit


def dilate(img, cover, steps=6):
    """Pull colour into the gutters so seams and mips do not bleed black."""
    out = img.copy()
    have = cover.copy()
    for _ in range(steps):
        acc = np.zeros_like(out)
        cnt = np.zeros(have.shape)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            sh = np.roll(np.roll(out, dy, 0), dx, 1)
            sv = np.roll(np.roll(have, dy, 0), dx, 1)
            acc[sv] += sh[sv]
            cnt[sv] += 1
        grow = (~have) & (cnt > 0)
        out[grow] = (acc[grow].T / cnt[grow]).T if out.ndim == 3 else \
            acc[grow] / cnt[grow]
        have = have | grow
    return out


#: The height map is written with this gain about mid-grey, so its relief
#: uses ~200 of the 256 levels instead of ~50 (eight-bit steps would show
#: as terracing in the normals). Glyph's `strength` is divided by the same.
HEIGHT_GAIN = 4.0
#: How pronounced the relief reads (Glyph's `strength`; ~1 subtle, 4 strong),
#: for the gained height map.
NORMAL_STRENGTH = 1.0


def sobel_normal(h, strength):
    """OpenGL-handed tangent normals from a height field (edges clamped)."""
    p = np.pad(h, 1, mode="edge")
    tl, t, tr = p[:-2, :-2], p[:-2, 1:-1], p[:-2, 2:]
    l, r = p[1:-1, :-2], p[1:-1, 2:]
    bl, b, br = p[2:, :-2], p[2:, 1:-1], p[2:, 2:]
    dx = (tr + 2 * r + br) - (tl + 2 * l + bl)
    dy = (bl + 2 * b + br) - (tl + 2 * t + tr)
    n = np.stack([-dx * strength, dy * strength, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def write_png(path, arr):
    """8-bit PNG, grey (H, W) or RGB (H, W, 3); arr in 0..1."""
    a = np.clip(np.rint(arr * 255), 0, 255).astype(np.uint8)
    h, w = a.shape[:2]
    ctype = 0 if a.ndim == 2 else 2
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as fh:
        fh.write(png)


def to_srgb(lin):
    """The ramps are sRGB already; the mixes were done in sRGB too, as
    paint is mixed on a palette. Kept as one place to change that."""
    return lin


def main():
    out = os.path.abspath(sys.argv[1])
    D = load(os.path.join(out, "bake"))
    col, rough, metal, height, emit = paint(D)
    cov = D["cover"]
    os.makedirs(os.path.join(out, "paint"), exist_ok=True)
    height = np.clip(0.5 + (height - 0.5) * HEIGHT_GAIN, 0.0, 1.0)
    maps = {"albedo": to_srgb(col), "roughness": rough, "metallic": metal,
            "height": height, "emission": emit}
    for name, arr in maps.items():
        write_png(os.path.join(out, "paint", name + ".png"),
                  dilate(arr, cov, 8))
    # PREVIEW ONLY, for looking at the paint in Blender before Glyph has
    # run: the same Sobel Glyph's x-glyph.normal_from_height uses. The
    # model wears Glyph's normal map, never this one.
    hgt = np.clip(np.rint(dilate(height, cov, 8) * 255), 0, 255) / 255.0
    write_png(os.path.join(out, "paint", "normal_preview.png"),
              sobel_normal(hgt, NORMAL_STRENGTH))
    print("[paint] %d texels painted -> %s" % (int(cov.sum()),
                                               os.path.join(out, "paint")))


if __name__ == "__main__":
    main()
