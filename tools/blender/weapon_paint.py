"""Material maps for the approved weapons, painted from their bakes.
(Arty, 2026-10-13.) Development toward the Foundry's approved fidelity.

    .tools/blender/4.5/python/bin/python3.11 tools/blender/weapon_paint.py OUT

Reads OUT/bake/*.npy and OUT/bake/bake.json (from
`build_weapon_model.py -- <weapon> bake`) and writes
OUT/paint/{albedo,height,roughness,metallic,emission}.png for Glyph
(`tools/glyphui/author_weapon_maps.py`), as the Foundry study did.

The Foundry painter (`foundry_paint.py`, approved, untouched) placed its
history by hand, in constants about one gun. This painter applies the same
material rules -- the same palette, the same chips, polish, temper, soot,
oil and dirt, the same raised-weld and texture-weld treatment -- and takes
every PLACED mark from the weapon's own wear spec, written beside its
geometry in `build_weapon_model.py` and carried here in bake.json: where it
gets hot, where hands polish it, where oil runs, which welds were repaired,
where a crack was ground out, what is stencilled and stamped, which bolts
a mechanic marked and which one a spanner slipped on. The rule is the
owner's: the model explains the construction; the textures explain the
materials, use, repairs and history. Noise only breaks up the EDGE of a
mask something else placed.
"""

from __future__ import annotations

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import foundry_paint as fp  # noqa: E402
from foundry_paint import (BLUED, CERAMIC, CHALK, CORE_BAND,  # noqa: E402
                           CORE_DARK, DEAD, ETAPE, FACILITY_LIGHT,
                           FACILITY_TRIM, GRIME, IDENTITY, METAL_SHOW,
                           PRIMER, RUST_BASE, RUST_TRIM, STEEL_BRIGHT,
                           STEEL_MID, TAPE, TAPE_DARK, TEMPER, cellhash, fbm,
                           hx, lettering, mix, poly_dist, ramp, seg_dist,
                           smooth, vnoise)


def _arr(v):
    return np.asarray(v, float)


def scratches(P, N, H, W, zones, seed):
    """Thin scratches through a coating, where use put them (the Foundry
    painter's strokes, from this weapon's own zones)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((H, W))
    for c0, nrm, ua, ub, spread, count, (da, db) in zones:
        c0, nrm, ua, ub = _arr(c0), _arr(nrm), _arr(ua), _arr(ub)
        face = (N @ nrm) > 0.8
        for _ in range(count):
            a = c0 + ua * rng.uniform(-spread, spread) + ub * rng.uniform(
                -spread * 0.4, spread * 0.4)
            d = ua * (da + rng.normal(0, 0.25)) + ub * (db + rng.normal(0,
                                                                     0.25))
            d /= np.linalg.norm(d)
            ln = rng.uniform(0.010, 0.032)
            dd, t = seg_dist(P, a - d * ln / 2, a + d * ln / 2)
            # finer than the Foundry's: at this density a 1 mm stroke
            # reads as a chalk mark, not a scratch
            depth = np.sin(np.pi * t) ** 0.5
            out = np.maximum(out, smooth(0.0007, 0.0002, dd) * depth * face)
    return out


def paint(D):
    P, N, cls, part = D["P"], D["N"], D["cls"], D["part"]
    edge, ao = D["edge"], D["ao"]
    meta = D["meta"]
    S = meta["spec"]
    CLS = meta["classes"]
    pid = meta["parts"]
    H, W = cls.shape

    def is_part(*names):
        m = np.zeros((H, W), bool)
        for n in names:
            if n in pid:
                m |= part == pid[n]
        return m

    def parts_like(prefix):
        m = np.zeros((H, W), bool)
        for n, v in pid.items():
            if n.startswith(prefix):
                m |= part == v
        return m

    col = np.zeros((H, W, 3))
    rough = np.full((H, W), 0.6)
    metal = np.zeros((H, W))
    height = np.full((H, W), 0.5)
    emit = np.zeros((H, W, 3))

    bx, by = S["bore"]
    zf, zr = S["ends"]
    convex = edge * smooth(0.45, 0.8, ao)
    bottom = smooth(S["bottom_y"] + 0.012, S["bottom_y"] - 0.004, P[..., 1])
    ends = (smooth(zf + 0.06, zf, P[..., 2])
            + smooth(zr - 0.03, zr, P[..., 2]))
    exposure = np.clip(0.15 + 0.65 * bottom + 0.5 * ends
                       + 0.35 * (fbm(P, 60.0, 3) - 0.5), 0.0, 1.0)
    cavity = 1.0 - smooth(0.25, 0.85, ao)
    up = np.clip(N[..., 1], 0, 1)

    # ---------------------------------------------------------- fields
    burn = np.zeros((H, W))          # hot enough to burn paint
    tint = np.zeros((H, W))          # hot enough to temper steel
    for h in S.get("heat", []):
        d, _ = seg_dist(P, h["a"], h["b"])
        f = h["w"] * np.exp(-np.maximum(d - h["r"], 0) / h["fall"])
        tint = np.maximum(tint, f)
        if h.get("burn"):
            burn = np.maximum(burn, f)
    contact = np.zeros((H, W))
    for c, r, s in S.get("contact", []):
        d = np.linalg.norm(P - _arr(c), axis=-1)
        contact = np.maximum(contact, s * smooth(r, r * 0.35, d))
    oil = np.zeros((H, W))
    for c, r in S.get("oil", []):
        oil = np.maximum(oil, smooth(r, r * 0.3,
                                     np.linalg.norm(P - _arr(c), axis=-1)))
    for a, b, r in S.get("oil_segs", []):
        d, _ = seg_dist(P, a, b)
        oil = np.maximum(oil, smooth(r, r * 0.3, d))
    # runs: oil that ran down a side face from a pivot
    for c, nrm, length in S.get("oil_runs", []):
        c, nrm = _arr(c), _arr(nrm)
        wob = c[2] + 0.004 * np.sin(P[..., 1] * 260)
        run_x = np.abs(P[..., 2] - wob)
        run = (smooth(0.0030, 0.0008, run_x)
               * smooth(c[1] + 0.004, c[1] - 0.004, P[..., 1])
               * smooth(c[1] - length, c[1] - length + 0.012, P[..., 1])
               * ((N @ nrm) > 0.7))
        oil = np.maximum(oil, 0.8 * run)
    soot = np.zeros((H, W))
    for a, b, r, w in S.get("soot", []):
        d, _ = seg_dist(P, a, b)
        soot = np.maximum(soot, w * smooth(r, r * 0.35, d))
    rust_zone = np.zeros((H, W))
    for c0, r in S.get("rust", []):
        rust_zone = np.maximum(rust_zone, smooth(
            r, r * 0.3, np.linalg.norm(P - _arr(c0), axis=-1)))
    pits = smooth(0.56, 0.66, fbm(P, 420.0, 13)) * rust_zone
    n1 = fbm(P, 180.0, 1)
    n2 = fbm(P, 520.0, 2)
    n3 = fbm(P, 60.0, 3)
    scr = scratches(P, N, H, W, S.get("scratch_zones", []),
                    S.get("seed", 1013))

    # ======================================================== painted steel
    m = cls == CLS["painted"]
    steel = mix(STEEL_MID, STEEL_BRIGHT, 0.35 + 0.3 * n2)
    fade = 0.5 * smooth(0.2, 0.9, up) + 0.5 * (n3 - 0.5)
    # each weapon wears the station trim at its own depth of grime
    coat = ramp(FACILITY_TRIM, S.get("trim", 0.30) + 0.10 * fade)
    coat = mix(coat, GRIME[1], S.get("grime", 0.20) + 0.10 * (1 - fade))
    streaks = vnoise(P * np.array([1.0, 0.08, 1.0]), 420.0, 5)
    side = (np.abs(N[..., 1]) < 0.5).astype(float)
    coat = mix(coat, GRIME[0], 0.12 * smooth(0.55, 0.8, streaks) * side)
    # touch-ups from another tin: close, not the same
    brush = 0.5 + 0.5 * np.sin((P[..., 2] * 1.0 + P[..., 1] * 0.25) * 2400.0
                               + 6.0 * n1)
    for c0, r in S.get("touchup", []):
        touch = (np.linalg.norm(P - _arr(c0), axis=-1)
                 < r * (1 + 0.25 * (n1 - 0.5))) & m
        coat = np.where(touch[..., None],
                        ramp([FACILITY_TRIM[0], hx("#4b5048"),
                              hx("#6a6e64")], 0.45 + 0.1 * brush), coat)
    flake = fbm(P, 240.0, 7)
    wear_n = (flake + 0.32 * convex * exposure + 0.10 * burn - 0.27
              + 0.6 * scr)
    to_primer = smooth(0.47, 0.50, wear_n)
    to_metal = smooth(0.52, 0.55, wear_n)
    thin = smooth(0.25, 0.95, contact)
    to_primer = np.maximum(to_primer, smooth(0.45, 0.8, thin
                                             + 0.15 * (n3 - 0.5)))
    to_metal = np.maximum(to_metal, smooth(0.75, 0.95, thin
                                           + 0.1 * (flake - 0.5)))
    c = mix(coat, PRIMER, to_primer)
    c = mix(c, steel, to_metal)
    burnt = smooth(0.45, 0.9, burn + 0.15 * (n1 - 0.5))
    c = mix(c, mix(c * 0.55, GRIME[1], 0.5), burnt * (1 - to_metal) * 0.8)
    temper = ramp(TEMPER, np.clip(1.2 - burn * 1.3 + 0.2 * n2, 0, 1))
    c = mix(c, temper, to_metal * smooth(0.3, 0.8, burn))
    col[m] = c[m]
    rough[m] = (0.62 - 0.22 * to_metal - 0.2 * thin + 0.15 * burnt)[m]
    metal[m] = (METAL_SHOW * to_metal)[m]
    height[m] = (0.5 + 0.025 * (1 - to_metal) + 0.012 * (1 - to_primer)
                 + 0.02 * burnt * (n2 - 0.5)
                 + 0.004 * (n2 - 0.5) * (1 - to_metal))[m]

    # raised welds (geometry): rippled beads, painted over, chipped
    wm = (is_part("welds") | parts_like("weld")) & m
    if wm.any():
        ph = (P[..., 0] * 37 + P[..., 1] * 53 + P[..., 2] * 41) * 280.0
        rip = 0.5 + 0.5 * np.sin(ph + 2.0 * n1)
        hgt = 0.55 + 0.08 * rip + 0.03 * (0.5 + 0.5 * n2)
        chipped = smooth(0.62, 0.75, rip * 0.6 + n1 * 0.6)
        wc = mix(mix(coat, GRIME[0], 0.3),
                 mix(STEEL_MID, TEMPER[1], 0.5) * 0.8, 0.7 * chipped)
        col[wm] = wc[wm]
        height[wm] = hgt[wm]
        rough[wm] = (0.55 - 0.15 * chipped)[wm]
        metal[wm] = (METAL_SHOW * chipped)[wm]
    # texture-only welds and their heat halo, on any station steel
    steelish = np.isin(cls, [CLS["painted"], CLS["strap"], CLS["bare"]])
    for pts in S.get("welds_flat", []):
        d, arc = poly_dist(P, pts)
        bead = smooth(0.0030, 0.0012, d) * steelish
        halo = smooth(0.010, 0.003, d) * steelish * (1 - bead)
        rip = 0.5 + 0.5 * np.sin(arc * 2600.0 + 3 * n1)
        col = mix(col, mix(col, TEMPER[1], 0.45), halo)
        col = mix(col, mix(STEEL_MID, GRIME[1], 0.4 + 0.3 * rip), bead)
        height = height + bead * (0.05 + 0.04 * rip)
        rough = np.where(bead > 0.5, 0.5, rough)
    for pts in S.get("cracks", []):
        d, arc = poly_dist(P, pts)
        scar = smooth(0.0030, 0.0012, d + 0.0008 * (n1 - 0.5)) * m
        halo = smooth(0.008, 0.003, d) * m * (1 - scar)
        col = mix(col, mix(col, TEMPER[1], 0.5), halo)
        rip = 0.5 + 0.5 * np.sin(arc * 2600)
        col = mix(col, mix(STEEL_MID, TEMPER[0], 0.3 + 0.2 * rip), scar)
        height = height + 0.02 * scar + 0.012 * scar * rip
        metal = np.maximum(metal, METAL_SHOW * scar)
        rough = np.where(scar > 0.5, 0.3, rough)
    for c0, ax, r in S.get("grinds", []):
        rel = P - _arr(c0)
        axv = _arr(ax)
        rr = np.linalg.norm(rel - (rel @ axv)[..., None] * axv, axis=-1)
        face = (N @ axv) > 0.7
        disc = smooth(r, r * 0.7, rr + 0.004 * (n1 - 0.5)) * face * m
        rings = 0.5 + 0.5 * np.sin(rr * 2600.0 + 4 * n1)
        redone = smooth(0.45, 0.6, n1)
        bare_ = mix(STEEL_MID, STEEL_BRIGHT, 0.2 + 0.25 * rings) * 0.9
        col = mix(col, mix(bare_, coat, 0.8 * redone), disc * 0.85)
        height = height + disc * 0.010 * (rings - 0.5)
        rough = mix(rough, 0.35 + 0.15 * rings, disc)
        metal = np.maximum(metal, METAL_SHOW * disc)

    # ============================================================== patches
    m = cls == CLS["patch"]
    blot = fbm(P, 150.0, 17)
    prim = ramp(RUST_TRIM, 0.18 + 0.35 * (blot - 0.5) + 0.1 * (n3 - 0.5))
    prim = mix(prim, GRIME[1], 0.25 + 0.2 * smooth(0.5, 0.7, blot))
    cut = smooth(0.55, 0.9, edge) * (1 - smooth(0.5, 0.8, ao) * 0.3)
    c = mix(prim, ramp(FACILITY_TRIM, 0.35), smooth(0.6, 0.9, edge) * 0.5)
    c = mix(c, GRIME[0], cut * 0.5)
    chips = smooth(0.55, 0.65, 0.8 * convex + 0.6 * (n1 - 0.5) + 0.2)
    c = mix(c, STEEL_MID, chips * (1 - cut))
    c = mix(c, ramp(RUST_BASE, 0.4 + 0.3 * n1), pits)
    col[m] = c[m]
    rough[m] = (0.72 - 0.25 * chips + 0.15 * cut + 0.1 * pits)[m]
    metal[m] = (METAL_SHOW * chips)[m]
    height[m] = (0.5 + 0.02 * (1 - chips) - 0.03 * cut * n2)[m]

    # ========================================================== bare steel
    m = cls == CLS["bare"]
    blued = mix(BLUED, DEAD[1], 0.3 + 0.2 * n3)
    chip = smooth(0.50, 0.56, fbm(P, 240.0, 8)
                  + 0.40 * convex * (0.3 + exposure) - 0.30)
    polish = smooth(0.3, 0.95, contact) * (0.75 + 0.25 * n3)
    bright = np.maximum(chip, polish)
    c = mix(blued, mix(STEEL_MID, STEEL_BRIGHT, 0.35 + 0.3 * n1), bright)
    rust = pits * (1 - oil)
    c = mix(c, ramp(RUST_BASE, 0.3 + 0.4 * n2), rust * 0.55)
    tm = smooth(0.25, 0.75, tint * (0.7 + 0.6 * n1))
    c = mix(c, ramp(TEMPER, 0.55 - 0.45 * np.clip(tint, 0, 1)), tm * 0.35)
    col[m] = c[m]
    rough[m] = (0.42 - 0.18 * bright - 0.15 * oil + 0.25 * rust)[m]
    metal[m] = (METAL_SHOW + 0.1 * bright - 0.25 * rust)[m]
    height[m] = (0.5 - 0.01 * rust * n2)[m]
    # lathe work: rings on the faces of turned parts
    for lt in S.get("lathe", []):
        lm = is_part(*lt["parts"]) & m
        rel = P - _arr(lt["c"])
        rr = np.linalg.norm(rel[..., :2], axis=-1)
        rings = 0.5 + 0.5 * np.sin(rr * 2400.0)
        face = np.abs(N[..., 2]) > 0.8
        height[lm & face] = (height + 0.006 * (rings - 0.5))[lm & face]
        # turning marks along the length on the round faces
        along = 0.5 + 0.5 * np.sin(P[..., 2] * 3000.0 + 2 * n1)
        side_ = lm & ~face
        height[side_] = (height + 0.004 * (along - 0.5))[side_]
    # knurling on handled parts: relief, not colour
    for name in S.get("knurl", []):
        km = is_part(name) & np.isin(cls, [CLS["bare"]])
        kn = ((np.sin((P[..., 0] + P[..., 2]) * 2200) > 0.55)
              | (np.sin((P[..., 0] - P[..., 2]) * 2200) > 0.55))
        height[km] = np.where(kn, 0.47, 0.53)[km]
        col[km] = mix(col, GRIME[0], 0.25 * kn)[km]

    # ============================================================== barrel
    m = cls == CLS["barrel"]
    blue = mix(hx("#353a40"), DEAD[1], 0.3 + 0.3 * n3)
    streak = 0.5 + 0.5 * np.sin(P[..., 0] * 2200 + P[..., 1] * 1800
                                + 9 * n1)
    bw = (fbm(P, 240.0, 7) + 0.40 * convex * exposure + 0.35 * contact
          + 0.03 * streak - 0.32 + 0.9 * scr)
    bright = smooth(0.50, 0.56, bw)
    c = mix(blue, mix(STEEL_MID, STEEL_BRIGHT, 0.6), bright)
    tm = np.clip(tint * (0.7 + 0.6 * n1), 0, 1)
    c = mix(c, ramp(TEMPER, 0.55 - 0.45 * tm), smooth(0.35, 0.85, tm) * 0.35)
    c = mix(c, GRIME[0], soot * 0.8)
    col[m] = c[m]
    rough[m] = (0.38 - 0.12 * bright + 0.45 * soot + 0.05 * streak)[m]
    metal[m] = (METAL_SHOW + 0.1 * bright - 0.3 * soot)[m]
    height[m] = (0.5 + 0.004 * (streak - 0.5))[m]

    # stamps: maker's and proof marks, dents in steel
    for text, origin, u, v, facing, cell in S.get("stamps", []):
        st = lettering(P, N, text, origin, u, v, facing, cell)
        st &= np.isin(cls, [CLS["barrel"], CLS["bare"], CLS["painted"],
                            CLS["strap"]])
        height[st] = 0.43
        col[st] = mix(col, GRIME[0], 0.55)[st]

    # ============================================================= Epsilon
    # dense, satin, machined to a tolerance the station does not work to;
    # almost no wear, except where the station's straps bite into it
    m = cls == CLS["epsilon"]
    ang = np.arctan2(P[..., 1] - by, P[..., 0] - bx)
    fine = 0.5 + 0.5 * np.sin(ang * 110.0 + P[..., 2] * 900.0 * S.get(
        "eps_helix", 0.0))
    c = mix(hx("#16171a"), hx("#24262a"), 0.4 + 0.3 * fine)
    edge_lit = smooth(0.6, 0.95, convex)
    c = mix(c, hx("#4a4e55"), edge_lit * 0.6)
    bite = np.zeros((H, W))
    for z0 in S.get("eps_bites", []):
        bite = np.maximum(bite, smooth(0.006, 0.0015,
                                       np.abs(P[..., 2] - z0)
                                       + 0.002 * (n1 - 0.5)))
    c = mix(c, mix(hx("#5c5f62"), GRIME[1], 0.3), bite * 0.7)
    c = mix(c, GRIME[0], soot * 0.6)
    # heat-straw on Epsilon nearest the work: a faint bloom, not a glow
    c = mix(c, hx("#3a3226"), smooth(0.4, 0.9, tint) * 0.35)
    col[m] = c[m]
    rough[m] = (0.30 + 0.06 * fine + 0.2 * bite + 0.3 * soot)[m]
    metal[m] = (0.25 + 0.15 * bite)[m]
    height[m] = (0.5 + 0.004 * (fine - 0.5) - 0.012 * bite)[m]

    # ============================================================== ceramic
    m = cls == CLS["ceramic"]
    craze = smooth(0.012, 0.004, np.abs(fbm(P, 220.0, 21) - 0.5))
    c = mix(CERAMIC, FACILITY_LIGHT[0], 0.3 * n3)
    c = mix(c, GRIME[0], (0.25 + 0.6 * smooth(0.0, 0.02, P[..., 1] - by
                                                + 0.026))
            * (0.6 + 0.4 * n1) * 0.8)
    c = mix(c, GRIME[0], craze * 0.35)
    c = mix(c, GRIME[0], smooth(0.4, 0.9, tint) * 0.3)
    chip = smooth(0.62, 0.7, convex * exposure + 0.3 * (n1 - 0.5))
    c = mix(c, hx("#e6e2d8"), chip)
    col[m] = c[m]
    rough[m] = 0.82
    height[m] = (0.5 - 0.015 * craze - 0.03 * chip)[m]

    # ================================================================ core
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
    g = S["grip"]
    gtop = _arr(g["top"])
    rk = np.radians(g["rake"])
    gdir = np.array([0.0, -np.cos(rk), np.sin(rk)])
    gfv = np.array([0.0, np.sin(rk), np.cos(rk)])
    rel = P - gtop
    t = rel @ gdir
    a = np.arctan2(rel @ gfv, P[..., 0])
    on_grip = is_part("grip")
    # other taped parts (pump sleeves, fore-grips) wrap round Z
    ax_t = np.zeros((H, W))
    ax_a = np.zeros((H, W))
    for name, (cx, cy) in S.get("tape_axes", {}).items():
        pm = is_part(name)
        ax_t = np.where(pm, -P[..., 2], ax_t)
        ax_a = np.where(pm, np.arctan2(P[..., 1] - cy, P[..., 0] - cx),
                        ax_a)
    tt = np.where(on_grip, t, ax_t)
    aa = np.where(on_grip, a, ax_a)
    wrap_ph = (tt / 0.016 + aa / (2 * np.pi)) % 1.0
    ridge = smooth(0.0, 0.08, wrap_ph) * smooth(1.0, 0.85, wrap_ph)
    weave = ((np.sin(tt * 2400) > 0) ^ (np.sin(aa * 30) > 0)).astype(float)
    held = np.where(on_grip, smooth(0.0, 0.03, t) * smooth(0.11, 0.07, t),
                    0.6 * smooth(0.0, 0.6, contact + 0.3))
    palm = held * np.where(on_grip, 0.5 + 0.5 * np.clip(-(rel @ gfv) / 0.02,
                                                        0, 1), 0.7)
    c = mix(TAPE, TAPE_DARK, 0.12 * (1 - ridge) + 0.5 * palm + 0.12 * n1)
    et = on_grip & (t < S.get("etape", 0.016))
    c = np.where(et[..., None], mix(ETAPE, GRIME[1], 0.2 * n2), c)
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
    c = mix(c, TEMPER[1], burn * 0.4)
    col[m] = c[m]
    rough[m] = (0.62 - 0.2 * convex)[m]
    metal[m] = METAL_SHOW
    height[m] = (0.5 - 0.025 * bentd)[m]

    m = cls == CLS["fastener"]
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

    # torque stripes across checked bolts
    for cen, ax in S.get("torque", []):
        rel = P - _arr(cen)
        on = (N @ _arr(ax)) > 0.6
        axv = _arr(ax)
        # a stroke across the head in the face's plane
        u = np.cross(axv, [0.3, 0.9, 0.3])
        u /= np.linalg.norm(u)
        line = (np.abs(rel @ u) < 0.0011) & (np.linalg.norm(rel, axis=-1)
                                             < 0.009) & on
        col[line] = mix(col, CHALK, 0.85)[line]
        rough[line] = 0.7
    for cen, ax in S.get("wrenched", []):
        rel = P - _arr(cen)
        axv = _arr(ax)
        rr = np.linalg.norm(rel - (rel @ axv)[..., None] * axv, axis=-1)
        u = np.cross(axv, [0.3, 0.9, 0.3])
        u /= np.linalg.norm(u)
        v = np.cross(axv, u)
        ang = np.arctan2(rel @ v, rel @ u)
        arc = ((rr > 0.0058) & (rr < 0.0072) & (np.sin(ang + 1.1) > 0.35)
               & ((N @ axv) > 0.7) & station)
        col[arc] = mix(col, STEEL_BRIGHT, 0.7)[arc]
        metal[arc] = METAL_SHOW
        rough[arc] = 0.3
        height[arc] = height[arc] - 0.015
    # grease-pencil tallies: services counted in fives
    for origin, u, v, facing in S.get("tallies", []):
        origin, u, v = _arr(origin), _arr(u), _arr(v)
        pen = np.zeros((H, W), bool)
        strokes = []
        for k in range(7):
            o = 0.0034 * k + (0.0026 if k >= 5 else 0.0)
            strokes.append((o, 0.010, o + 0.0008, 0.0))
        strokes.append((-0.001, 0.002, 0.016, 0.009))
        for ua, va, ub, vb in strokes:
            d, _ = seg_dist(P, origin + u * ua + v * va,
                            origin + u * ub + v * vb)
            pen |= d < 0.00055
        pen &= ((N @ _arr(facing)) > 0.7) & (n1 > 0.33) & station
        col[pen] = mix(col, CHALK, 0.38)[pen]
        rough[pen] = 0.85
    # stencils, station style: faded, worn thinner where handled
    for text, origin, u, v, facing, cell in S.get("stencils", []):
        st = lettering(P, N, text, origin, u, v, facing, cell)
        st &= np.isin(cls, [CLS["painted"], CLS["patch"]])
        col[st] = mix(col, CHALK, 0.25 + 0.25 * n1 - 0.2 * thin)[st]
    # index stripes: paint pen down a rotating part, so its turning reads
    for p_name, axis_c, ang0, width in S.get("index_stripes", []):
        im_ = is_part(p_name) & ~np.isin(cls, [CLS["core"], CLS["lamp"]])
        a_ = np.arctan2(P[..., 1] - axis_c[1], P[..., 0] - axis_c[0])
        d_ = np.abs((a_ - ang0 + np.pi) % (2 * np.pi) - np.pi)
        stripe = im_ & (d_ < width) & (n1 > 0.25)
        col[stripe] = mix(col, hx("#c9a227"), 0.75)[stripe]
        rough[stripe] = 0.6
        metal[stripe] = 0.0

    return col, rough, metal, height, emit


def load(bake):
    D = fp.load(bake)
    return D


def main():
    out = os.path.abspath(sys.argv[1])
    D = load(os.path.join(out, "bake"))
    col, rough, metal, height, emit = paint(D)
    cov = D["cover"]
    os.makedirs(os.path.join(out, "paint"), exist_ok=True)
    height = np.clip(0.5 + (height - 0.5) * fp.HEIGHT_GAIN, 0.0, 1.0)
    maps = {"albedo": col, "roughness": rough, "metallic": metal,
            "height": height, "emission": emit}
    for name, arr in maps.items():
        fp.write_png(os.path.join(out, "paint", name + ".png"),
                     fp.dilate(arr, cov, 8))
    hgt = np.clip(np.rint(fp.dilate(height, cov, 8) * 255), 0, 255) / 255.0
    fp.write_png(os.path.join(out, "paint", "normal_preview.png"),
                 fp.sobel_normal(hgt, fp.NORMAL_STRENGTH))
    print("[paint] %s: %d texels painted -> %s"
          % (D["meta"].get("weapon", "?"), int(cov.sum()),
             os.path.join(out, "paint")))


if __name__ == "__main__":
    main()
