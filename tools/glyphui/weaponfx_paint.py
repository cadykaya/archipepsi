"""Painters for the five-weapon effect layers. (Arty, 2026-10-10.)

Pure Python, deterministic: every frame is computed from seeded noise and
the shapes below, then SNAPPED to its layer's authored palette, so a
pixel is always one of the colours chosen for that layer. The author
script (`author_weapon_fx.py`) writes those frames into ECMS Glyph cels
with `pixels.apply_patch` and exports them through Glyph, so Glyph holds
the frames, the clips and the timing; this module holds the drawing.

WHY NOT GLYPH'S PRIMITIVES ALONE. Batch 067 was drawn with line, rect and
ellipse, one flat colour per shape, and the owner rejected it as flat,
single-layer and pixel-sprite-like (2026-10-09). A flame is a gradient
that breaks up; a smoke puff billows; a bullet hole is dark at the bore,
bright where the paint is scraped off and sooty round it. Those need a
value per pixel, so they are painted here and quantized to a ramp --
still palette art, still crisp, but layered and alive.

A frame is a list of rows of (r, g, b, a) floats in 0..255.
"""

from __future__ import annotations

import math
import random

# --- noise --------------------------------------------------------------------


def _hash(ix, iy, seed):
    h = (ix * 374761393 + iy * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, seed=0):
    """Smooth value noise in 0..1."""
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = _hash(ix, iy, seed)
    b = _hash(ix + 1, iy, seed)
    c = _hash(ix, iy + 1, seed)
    d = _hash(ix + 1, iy + 1, seed)
    return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy


def fbm(x, y, seed=0, octaves=3):
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total += amp * vnoise(x, y, seed + 17 * o)
        norm += amp
        x, y, amp = x * 2.03, y * 2.03, amp * 0.5
    return total / norm


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


# --- ramps --------------------------------------------------------------------

def ramp(stops, steps):
    """`steps` colours interpolated through `stops` [(t, (r,g,b,a))]."""
    out = []
    for i in range(steps):
        t = i / (steps - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                f = 0 if t1 == t0 else (t - t0) / (t1 - t0)
                out.append(tuple(int(round(c0[k] + (c1[k] - c0[k]) * f))
                                 for k in range(4)))
                break
    return out


def at(rmp, t, cutoff=0.02):
    """The ramp colour for intensity t (below `cutoff`, transparent)."""
    if t <= cutoff:
        return (0, 0, 0, 0)
    return rmp[min(len(rmp) - 1, int(t * (len(rmp) - 1) + 0.5))]


#: Heat: deep ember -> orange -> amber -> yellow -> white-hot.
FLAME = ramp([(0.0, (110, 32, 18, 60)), (0.25, (200, 70, 24, 150)),
              (0.5, (255, 140, 40, 220)), (0.72, (255, 200, 90, 245)),
              (0.88, (255, 238, 170, 255)), (1.0, (255, 253, 240, 255))], 16)
CORE = ramp([(0.0, (255, 214, 140, 70)), (0.5, (255, 240, 200, 200)),
             (1.0, (255, 255, 252, 255))], 8)
SMOKE = ramp([(0.0, (70, 66, 62, 20)), (0.4, (98, 93, 88, 80)),
              (0.8, (132, 127, 120, 135)), (1.0, (160, 154, 146, 160))], 10)
EMBER = ramp([(0.0, (90, 20, 12, 70)), (0.5, (190, 60, 20, 190)),
              (1.0, (255, 150, 60, 255))], 8)
TRAIL = ramp([(0.0, (110, 104, 98, 30)), (0.35, (150, 120, 96, 90)),
              (0.6, (230, 120, 40, 190)), (0.82, (255, 205, 110, 240)),
              (1.0, (255, 250, 230, 255))], 14)
DUST = ramp([(0.0, (120, 112, 100, 30)), (0.45, (165, 156, 140, 130)),
             (0.8, (196, 188, 172, 200)), (1.0, (222, 215, 200, 230))], 10)
ICHOR = ramp([(0.0, (70, 34, 38, 50)), (0.4, (104, 52, 50, 170)),
              (0.75, (150, 92, 72, 230)), (1.0, (206, 168, 136, 255))], 10)
HEAT = ramp([(0.0, (90, 24, 14, 0)), (0.2, (130, 34, 16, 120)),
             (0.5, (230, 90, 30, 200)), (0.8, (255, 190, 90, 240)),
             (1.0, (255, 250, 220, 255))], 12)
COLD = ramp([(0.0, (150, 170, 190, 50)), (0.5, (205, 220, 235, 190)),
             (1.0, (250, 252, 255, 255))], 9)
VOLT = ramp([(0.0, (90, 70, 150, 40)), (0.4, (150, 120, 230, 140)),
             (0.75, (210, 196, 255, 220)), (1.0, (250, 248, 255, 255))], 12)


# --- shapes -------------------------------------------------------------------

def blank(w, h):
    return [[(0, 0, 0, 0)] * w for _ in range(h)]


def paint(w, h, fn):
    """fn(x, y) -> rgba, sampled at pixel centres."""
    return [[fn(x + 0.5, y + 0.5) for x in range(w)] for y in range(h)]


def over(dst, src):
    """Alpha-composite src over dst (same size)."""
    out = []
    for rd, rs in zip(dst, src):
        row = []
        for d, s in zip(rd, rs):
            sa = s[3] / 255.0
            da = d[3] / 255.0
            oa = sa + da * (1 - sa)
            if oa <= 0:
                row.append((0, 0, 0, 0))
                continue
            row.append(tuple((s[k] * sa + d[k] * da * (1 - sa)) / oa
                             for k in range(3)) + (oa * 255.0,))
        out.append(row)
    return out


def flare(w, h, radius, lobes, seed, breakup=0.0, hot=1.0, stretch=1.0,
          cx=None, cy=None, rmp=FLAME):
    """An irregular flame star: `lobes` uneven tongues round a hot centre,
    the outline modulated by angular noise; `breakup` eats holes into it
    as it dies; `stretch` > 1 widens it sideways."""
    cx = w / 2 if cx is None else cx
    cy = h / 2 if cy is None else cy
    rng = random.Random(seed)
    phase = rng.random() * 6.283
    # Uneven tongues: lengths from a third to full, uneven spacing, so it
    # never reads as a symmetrical flower (the first pass did).
    lengths = [0.3 + 0.7 * rng.random() ** 0.7 for _ in range(lobes)]
    cuts = sorted(rng.uniform(0, 1) for _ in range(lobes))

    def fn(x, y):
        dx, dy = (x - cx) / stretch, y - cy
        r = math.hypot(dx, dy)
        th = math.atan2(dy, dx) + phase
        u = (th / 6.283) % 1.0
        if u < cuts[0]:
            u += 1.0          # before the first cut: the last lobe's wrap
        i0 = 0
        while i0 < lobes - 1 and cuts[i0 + 1] <= u:
            i0 += 1
        nxt = cuts[i0 + 1] if i0 < lobes - 1 else cuts[0] + 1
        span = max(nxt - cuts[i0], 0.02)
        f = ((u - cuts[i0]) % 1.0) / span
        petal = math.sin(math.pi * clamp(f)) ** 0.8
        edge = radius * (0.32 + 0.68 * lengths[i0] * petal) \
            * (0.75 + 0.5 * fbm(math.cos(th) * 3.0 + 7 + r * 0.05,
                                math.sin(th) * 3.0 + 7, seed))
        t = clamp(1 - r / max(edge, 0.001)) ** 1.0
        t *= 0.7 + 0.3 * fbm(x * 0.2, y * 0.2, seed + 3)
        t += 0.45 * math.exp(-(r / (radius * 0.16)) ** 2)
        if breakup:
            t -= breakup * fbm(x * 0.12, y * 0.12, seed + 9) * (r / radius)
        return at(rmp, clamp(t * hot))
    return paint(w, h, fn)


def core(w, h, sigma, rays, ray_len, seed, rmp=CORE, angle=0.0):
    """A white-hot centre with a few thin bright rays."""
    cx, cy = w / 2, h / 2
    rng = random.Random(seed)
    dirs = [angle + i * math.pi / rays + rng.uniform(-0.12, 0.12)
            for i in range(rays)]

    def fn(x, y):
        dx, dy = x - cx, y - cy
        r = math.hypot(dx, dy)
        t = math.exp(-(r / sigma) ** 2)
        for a in dirs:
            along = dx * math.cos(a) + dy * math.sin(a)
            across = -dx * math.sin(a) + dy * math.cos(a)
            t = max(t, math.exp(-(across / 0.9) ** 2)
                    * math.exp(-abs(along) / ray_len) * 0.95)
        return at(rmp, clamp(t))
    return paint(w, h, fn)


def jet(w, h, length, width, seed, breakup=0.0, hot=1.0, rmp=FLAME):
    """A flame tongue from the left edge's middle, widening and breaking
    up along +x: a muzzle-brake port's side jet, seen side-on."""
    cy = h / 2

    def fn(x, y):
        u = x / max(length, 1)
        if u > 1.15:
            return (0, 0, 0, 0)
        half = width * (0.25 + 0.75 * u ** 0.6) \
            * (0.8 + 0.4 * fbm(x * 0.15, 0.5, seed))
        t = math.exp(-((y - cy) / max(half, 0.5)) ** 2) * clamp(1 - u) ** 0.6
        t *= 0.7 + 0.3 * fbm(x * 0.22, y * 0.3, seed + 5)
        if breakup:
            t -= breakup * fbm(x * 0.1, y * 0.25, seed + 7) * u
        return at(rmp, clamp(t * hot))
    return paint(w, h, fn)


def puff(w, h, blobs, seed, density=1.0, rise=0.0, spread=1.0, rmp=SMOKE):
    """Billowing smoke or dust: `blobs` soft lumps round the centre, lifted
    by `rise` (px) and widened by `spread`, eaten at the edges by noise."""
    rng = random.Random(seed)
    lumps = []
    for _ in range(blobs):
        a = rng.random() * 6.283
        d = rng.random() * w * 0.16 * spread
        lumps.append((w / 2 + math.cos(a) * d,
                      h / 2 + math.sin(a) * d * 0.7 - rise * rng.uniform(0.6,
                                                                         1.2),
                      w * rng.uniform(0.10, 0.18) * spread))

    def fn(x, y):
        d = 0.0
        for lx, ly, lr in lumps:
            d += math.exp(-(((x - lx) ** 2 + (y - ly) ** 2) / (lr * lr)))
        # Billow at the EDGE (low-frequency noise on the threshold), not
        # holes in the middle; lit from above; a hard cutoff so the faint
        # tail does not draw a flat disc round it (the first pass did).
        d *= 0.45 + 0.9 * fbm(x * 0.11, y * 0.11, seed + 2)
        t = 1 - math.exp(-1.3 * d * density)
        # Lit from above, with a noisy terminator: a plain vertical
        # gradient quantized into a hard horizontal band (first pass).
        lit = clamp(1.25 - 1.5 * y / h + 0.5 * (fbm(x * 0.2, y * 0.2,
                                                     seed + 6) - 0.5))
        return at(rmp, clamp(t * (0.72 + 0.28 * lit)), cutoff=0.16)
    return paint(w, h, fn)


def shock_ring(w, h, radius, thick, seed, density=1.0, rmp=DUST):
    """A kinetic shock: a ragged annulus of dust thrown OUT from the hit,
    hollow in the middle -- a ring, where a puff is a filled cloud."""
    cx, cy = w / 2, h / 2

    def fn(x, y):
        dx, dy = x - cx, y - cy
        r = math.hypot(dx, dy)
        th = math.atan2(dy, dx)
        # Periodic angular noise, so there is no seam at +-pi.
        wob = fbm(math.cos(th) * 2.5 + 3, math.sin(th) * 2.5 + 3, seed)
        rr = radius * (0.85 + 0.3 * wob)
        d = math.exp(-((r - rr) / (thick * (0.7 + 0.6 * wob))) ** 2)
        d *= 0.5 + 0.8 * fbm(x * 0.13, y * 0.13, seed + 3)
        t = 1 - math.exp(-1.6 * d * density)
        lit = clamp(1.2 - 1.3 * y / h)
        return at(rmp, clamp(t * (0.75 + 0.25 * lit)), cutoff=0.16)
    return paint(w, h, fn)


def drops(w, h, count, radius, size, seed, fall=0.0, rmp=ICHOR, mist=0.0):
    """Droplets flung out round a centre (and a soft mist under them)."""
    rng = random.Random(seed)
    pts = []
    for _ in range(count):
        a = rng.random() * 6.283
        d = radius * rng.uniform(0.55, 1.0)
        pts.append((w / 2 + math.cos(a) * d,
                    h / 2 + math.sin(a) * d + fall * rng.uniform(0.5, 1.0),
                    size * rng.uniform(0.6, 1.3)))

    def fn(x, y):
        t = 0.0
        for px, py, s in pts:
            t = max(t, math.exp(-(((x - px) ** 2 + (y - py) ** 2) / (s * s))))
        if mist:
            r = math.hypot(x - w / 2, y - h / 2)
            t = max(t, mist * math.exp(-(r / (radius * 0.45)) ** 2)
                    * (0.5 + 0.5 * fbm(x * 0.2, y * 0.2, seed + 4)))
        return at(rmp, clamp(t), cutoff=0.12)
    return paint(w, h, fn)


def streak(w, h, head, hot=1.0, rmp=TRAIL, thick=1.0, seed=0, segments=0):
    """A projectile's trail along +x: hottest at the head (right), cooling
    and widening into smoke toward the tail. `segments` > 0 cuts it into
    chevron-like pulses (the Mass Driver's)."""
    cy = h / 2

    def fn(x, y):
        u = x / w
        half = thick * (0.6 + 1.6 * (1 - u)) \
            * (0.85 + 0.3 * fbm(x * 0.08, 0.3, seed))
        t = math.exp(-((y - cy) / max(half, 0.4)) ** 2) * u ** 1.4
        if segments:
            t *= 0.35 + 0.65 * (0.5 + 0.5 * math.cos(u * segments * 6.283))
        if x > w - head:
            t = max(t, math.exp(-((y - cy) / (thick * 0.9)) ** 2))
        return at(rmp, clamp(t * hot))
    return paint(w, h, fn)


def slug(w, h, sx, sy, rmp=FLAME, hot=1.0):
    """A glowing elongated round, hot-white at its centre."""
    cx, cy = w * 0.6, h / 2

    def fn(x, y):
        t = math.exp(-(((x - cx) / sx) ** 2 + ((y - cy) / sy) ** 2))
        return at(rmp, clamp(t * hot))
    return paint(w, h, fn)


def bolts(w, h, n, seed, level, rmp=VOLT):
    """Electric crackle between coils along +x, `level` 0..1 of charge:
    more and brighter arcs as it fills."""
    rng = random.Random(seed)
    lines = []
    for _ in range(max(1, int(n * level))):
        x0 = rng.uniform(0, w * 0.2)
        y = rng.uniform(h * 0.25, h * 0.75)
        pts = []
        x = x0
        while x < w * (0.35 + 0.65 * level):
            pts.append((x, y))
            x += rng.uniform(3, 7)
            y = clamp(y + rng.uniform(-3, 3), 2, h - 3)
        lines.append(pts)

    def fn(x, y):
        t = 0.0
        for pts in lines:
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                vx, vy = x1 - x0, y1 - y0
                L = vx * vx + vy * vy
                u = clamp(((x - x0) * vx + (y - y0) * vy) / L) if L else 0
                d = math.hypot(x - (x0 + u * vx), y - (y0 + u * vy))
                t = max(t, math.exp(-(d / 0.8) ** 2))
        glow = math.exp(-((y - h / 2) / (h * 0.35)) ** 2) * 0.35 * level
        return at(rmp, clamp(max(t * (0.6 + 0.4 * level), glow)))
    return paint(w, h, fn)


def rays(w, h, count, inner, outer, seed, rmp=FLAME, width=1.0, hot=1.0,
         squash=1.0):
    """Radial streaks between `inner` and `outer`: an impact's spark star,
    or the Mass Driver's pressure lines -- uneven, not a ring. `squash` > 1
    flattens the star vertically (a wide spray)."""
    rng = random.Random(seed)
    spokes = [(rng.random() * 6.283, rng.uniform(0.6, 1.0),
               rng.uniform(0.7, 1.3)) for _ in range(count)]
    cx, cy = w / 2, h / 2

    def fn(x, y):
        dx, dy = x - cx, (y - cy) * squash
        t = 0.0
        for a, ln, wd in spokes:
            along = dx * math.cos(a) + dy * math.sin(a)
            across = -dx * math.sin(a) + dy * math.cos(a)
            if inner <= along <= inner + (outer - inner) * ln:
                f = (along - inner) / max(1, (outer - inner) * ln)
                t = max(t, math.exp(-(across / (width * wd)) ** 2)
                        * (1 - f) ** 0.7)
        return at(rmp, clamp(t * hot))
    return paint(w, h, fn)


# --- marks (persistent decals) ------------------------------------------------

def metal_hole(w, h, seed, bore=4.4):
    """A bullet hole in painted steel: a black bore, a bright scraped rim,
    an uneven ring of paint chipped back to bare metal, a soot halo.
    Sized to READ at range: the first pass's 3 px bore and faint soot
    left a 2-3 px dot at 9 m (FW3)."""
    cx, cy = w / 2, h / 2
    rng = random.Random(seed)
    chip = w * 0.2 * rng.uniform(0.9, 1.1)

    def fn(x, y):
        dx, dy = x - cx, y - cy
        r = math.hypot(dx, dy)
        th = math.atan2(dy, dx)
        n = fbm(math.cos(th) * 2 + 5, math.sin(th) * 2 + 5, seed)
        r_chip = chip * (0.7 + 0.6 * n)
        if r < bore:
            return (18, 16, 16, 255)
        if r < bore + 2.0:
            return (196, 196, 190, 255)
        if r < r_chip:
            m = 0.5 + 0.5 * fbm(x * 0.4, y * 0.4, seed + 1)
            return (int(110 + 40 * m), int(112 + 40 * m), int(116 + 38 * m),
                    255)
        soot = clamp(1 - (r - r_chip) / (w * 0.22))
        soot *= 0.6 + 0.4 * fbm(x * 0.25, y * 0.25, seed + 2)
        return (30, 26, 24, int(215 * soot) // 20 * 20) if soot > 0.08 \
            else (0, 0, 0, 0)
    return paint(w, h, fn)


def metal_dent(w, h, seed):
    """A heavy blunt hit that did not go through: a shaded dimple lit from
    the upper left, a scuffed rim, a little soot."""
    cx, cy = w / 2, h / 2
    rad = w * 0.26

    def fn(x, y):
        dx, dy = (x - cx) / rad, (y - cy) / rad
        r2 = dx * dx + dy * dy
        if r2 > 1.7:
            return (0, 0, 0, 0)
        if r2 <= 1.0:
            nz = math.sqrt(1 - r2)
            shade = clamp(0.5 + 0.5 * (dx * 0.6 + dy * 0.6) / max(nz, 0.3))
            v = 60 + 150 * shade
            v *= 0.9 + 0.1 * fbm(x * 0.5, y * 0.5, seed)
            return (int(v), int(v), int(v * 1.02), 255)
        ring = clamp(1 - (math.sqrt(r2) - 1) / 0.3)
        return (40, 36, 34, int(150 * ring))
    return paint(w, h, fn)


def kinetic_mark(w, h, seed):
    """Mass Driver's mark: a broad, shallow, flattened dish (no ball
    shading) with a compressed dark rim and radial stress fractures."""
    cx, cy = w / 2, h / 2
    rad = w * 0.27
    rng = random.Random(seed)
    n = rng.randint(5, 7)
    cracks = [(i + rng.uniform(-0.3, 0.3)) * 6.283 / n for i in range(n)]

    def fn(x, y):
        dx, dy = x - cx, y - cy
        r = math.hypot(dx, dy) / rad
        th = math.atan2(dy, dx)
        for a in cracks:
            da = abs((th - a + math.pi) % 6.283 - math.pi)
            if 0.55 < r < 1.75 and da * r * rad < 0.9 + 0.3 * (1 - r / 1.75):
                return (34, 32, 34, 230)
        if r <= 1.0:
            # A flat floor, slightly darker toward the rim; scuffs.
            v = 118 - 30 * r * r + 30 * (fbm(x * 0.4, y * 0.4, seed) - 0.5)
            v = int(v) // 12 * 12
            return (v, v, v + 4, 255)
        if r <= 1.22:
            return (44, 40, 40, 255)
        if r <= 1.5:
            return (60, 56, 54, int(160 * (1.5 - r) / 0.28) // 40 * 40)
        return (0, 0, 0, 0)
    return paint(w, h, fn)


def stone_crater(w, h, seed):
    """Chipped concrete: an irregular crater of pale fresh break, a dark
    core, three or four cracks running out, a halo of dust."""
    cx, cy = w / 2, h / 2
    rng = random.Random(seed)
    cracks = []
    for _ in range(rng.randint(3, 5)):
        a = rng.random() * 6.283
        pts = [(cx, cy)]
        x, y = cx, cy
        for _ in range(rng.randint(5, 8)):
            a += rng.uniform(-0.5, 0.5)
            x += math.cos(a) * rng.uniform(2, 3.2)
            y += math.sin(a) * rng.uniform(2, 3.2)
            pts.append((x, y))
        cracks.append(pts)
    base = w * 0.2

    def fn(x, y):
        dx, dy = x - cx, y - cy
        r = math.hypot(dx, dy)
        th = math.atan2(dy, dx)
        edge = base * (0.6 + 0.8 * fbm(math.cos(th) * 2.6 + 9,
                                       math.sin(th) * 2.6 + 9, seed))
        for pts in cracks:
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                vx, vy = x1 - x0, y1 - y0
                L = vx * vx + vy * vy
                u = clamp(((x - x0) * vx + (y - y0) * vy) / L) if L else 0
                if math.hypot(x - (x0 + u * vx), y - (y0 + u * vy)) < 0.6:
                    return (52, 50, 47, 235)
        if r < base * 0.28:
            return (58, 55, 52, 255)
        if r < edge:
            m = fbm(x * 0.35, y * 0.35, seed + 3)
            v = 150 + 50 * m - 30 * (r / edge)
            return (int(v), int(v * 0.96), int(v * 0.9), 255)
        halo = clamp(1 - (r - edge) / (w * 0.1))
        halo *= 0.5 + 0.5 * fbm(x * 0.3, y * 0.3, seed + 4)
        return (200, 192, 178, int(110 * halo) // 20 * 20) if halo > 0.1 \
            else (0, 0, 0, 0)
    return paint(w, h, fn)


def soft_mark(w, h, seed):
    """An organic target's mark, kept away from gore: a dark puncture, a
    wet rim, a muted bruise that spreads under the surface."""
    cx, cy = w / 2, h / 2

    def fn(x, y):
        r = math.hypot(x - cx, y - cy)
        th = math.atan2(y - cy, x - cx)
        n = fbm(x * 0.25, y * 0.25, seed)
        rim = 6.4 + 2.6 * fbm(math.cos(th) * 2 + 3, math.sin(th) * 2 + 3,
                              seed + 1)
        if r < 3.6 + n:
            return (40, 20, 24, 255)
        if r < rim:
            return (122, 70, 64, 255 if r < rim - 1.2 else 170)
        bruise = clamp(1 - r / (w * (0.42 + 0.08 * n)))
        # Stepped alpha: a smooth ramp spends the 88-colour palette on
        # invisible differences and starves the rim (it vanished, 1st pass).
        return (70, 40, 54, int(205 * bruise) // 25 * 25) \
            if bruise > 0.1 else (0, 0, 0, 0)
    return paint(w, h, fn)


def wood_mark(w, h, seed):
    """A splintered hole in timber: dark, with pale fibres torn out along
    the grain (horizontal)."""
    cx, cy = w / 2, h / 2
    rng = random.Random(seed)
    fibres = [(rng.uniform(-1.3, 1.3),
               rng.uniform(6, 17) * rng.choice((-1, 1)))
              for _ in range(12)]

    def fn(x, y):
        dx, dy = x - cx, y - cy
        if math.hypot(dx, dy * 1.4) < 4.4:
            return (30, 22, 16, 255)
        for off, ln in fibres:
            if 0 < dx * (1 if ln > 0 else -1) < abs(ln) and abs(dy - off * 2
                                                                 - dx * 0.08) < 1.0:
                return (214, 184, 136, 255)
        r = math.hypot(dx, dy * 1.6)
        scorch = clamp(1 - r / (w * 0.34))
        return (56, 40, 28, int(180 * scorch) // 20 * 20) \
            if scorch > 0.08 else (0, 0, 0, 0)
    return paint(w, h, fn)


def cluster(w, h, seed, count=9, spread=0.32):
    """A scattergun's pattern: one central blast mark and a few pocks
    round it -- one coherent mark, not nine identical holes."""
    rng = random.Random(seed)
    centre = stone_crater(w, h, seed)
    out = [row[:] for row in centre]
    for _ in range(count):
        a = rng.random() * 6.283
        d = w * spread * rng.uniform(0.45, 1.0)
        px, py = w / 2 + math.cos(a) * d, h / 2 + math.sin(a) * d
        rad = rng.uniform(1.2, 2.2)
        for y in range(max(0, int(py - 4)), min(h, int(py + 4))):
            for x in range(max(0, int(px - 4)), min(w, int(px + 4))):
                r = math.hypot(x + 0.5 - px, y + 0.5 - py)
                if r < rad:
                    out[y][x] = (40, 38, 36, 255)
                elif r < rad + 1.2 and out[y][x][3] < 200:
                    out[y][x] = (150, 144, 134, 220)
    return out


# --- quantize -----------------------------------------------------------------

def palette_of(frames, limit=88):
    """The distinct colours a layer's frames use, most-used first, capped;
    every pixel is then snapped to the nearest of them."""
    counts = {}
    for fr in frames:
        for row in fr:
            for p in row:
                if p[3] < 8:
                    continue
                key = tuple(int(round(c)) for c in p)
                counts[key] = counts.get(key, 0) + 1
    ordered = sorted(counts, key=lambda k: (-counts[k], k))
    return ordered[:limit]


def snap(frame, pal, _memo=None):
    memo = {} if _memo is None else _memo
    out = []
    for row in frame:
        line = []
        for p in row:
            if p[3] < 8:
                line.append(None)
                continue
            key = tuple(int(round(c)) for c in p)
            if key not in memo:
                memo[key] = min(pal, key=lambda q: sum((key[i] - q[i]) ** 2
                                                       for i in range(4)))
            line.append(memo[key])
        out.append(line)
    return out
