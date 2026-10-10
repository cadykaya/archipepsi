"""A technical-illustration kit for DETAILED weapon concepts (design pass 2).
EXPLORATION ONLY -- drawings to approve mechanisms, not models. (Arty,
2026-10-10.)

The first pass drew blocks. This kit draws machines: fasteners, springs,
gas struts, hoses, fin arrays, section hatching, energy-path arrows,
travel arcs, wear, stencils and numbered balloons, with line weights
(heavy silhouette, light internal) and fills by OWNER:

    yours     the player's own device                    pale, cool
    station   station-built engineering: frame, linkage  institutional paint
    steel     bare machined steel (wear faces, pins)     mid grey
    dark      dark steel, rubber, ports                  near black
    epsilon   Epsilon technology: dense black plate,     near-black, with
              lit only through its seams                 green seams
    echo      the Echo core: foreign-world material      a PLACEHOLDER accent
              (its real accent comes from the source      (violet)
              game's identity package)
    ceramic   heat breaks, liners                         pale warm
    heat      heat-tinted metal (blued / straw)           dusky blue
    glass     a window or gauge face                      pale

Side elevations in centimetres: x forward (the muzzle on the right), y up.
Deterministic.
"""

from __future__ import annotations

import math
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_M = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
SS = 3

PAPER = (238, 235, 227)
INK = (36, 36, 38)

FILL = {
    "yours": (226, 233, 238),
    "station": (208, 206, 196),
    "station_dark": (126, 130, 134),
    "steel": (160, 164, 168),
    "dark": (70, 72, 76),
    "rubber": (44, 44, 46),
    "epsilon": (40, 40, 46),
    "echo": (176, 128, 196),
    "ceramic": (226, 214, 190),
    "heat": (112, 104, 132),
    "glass": (214, 226, 228),
    "slug": (190, 186, 178),
    "white": (250, 250, 246),
}
SEAM = (120, 236, 70)          # Epsilon's light, through seams only
ENERGY = (232, 120, 40)        # the energy path arrows (a diagram colour)
TRAVEL = (60, 110, 170)        # travel arcs (a diagram colour)
CALL = (150, 80, 20)


def font(size, bold=False, mono=False):
    return ImageFont.truetype(FONT_M if mono else (FONT_B if bold else FONT),
                              size)


def rot(pts, cx, cy, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s,
             cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def circle_pts(cx, cy, r, n=28, a0=0.0):
    return [(cx + r * math.cos(a0 + 2 * math.pi * i / n),
             cy + r * math.sin(a0 + 2 * math.pi * i / n)) for i in range(n)]


def arc_pts(cx, cy, r, a0, a1, n=16):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


class D:
    """A detailed drawing: an ordered list of items (painter's order) and
    numbered anchors for balloons."""

    def __init__(self, name):
        self.name = name
        self.items = []
        self.anchors = {}

    # -- shapes
    def poly(self, pts, role, lw=1.1, hatch=False, n=None, alpha=255):
        self.items.append({"k": "poly", "pts": [tuple(p) for p in pts],
                           "role": role, "lw": lw, "hatch": hatch,
                           "alpha": alpha})
        if n is not None:
            xs, ys = zip(*pts)
            self.anchors.setdefault(n, (sum(xs) / len(xs),
                                        sum(ys) / len(ys)))
        return self

    def rect(self, x0, y0, x1, y1, role, chamfer=0.0, deg=0.0, pivot=None,
             **kw):
        c = chamfer
        if c:
            pts = [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c),
                   (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]
        else:
            pts = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        if deg:
            px, py = pivot or ((x0 + x1) / 2, (y0 + y1) / 2)
            pts = rot(pts, px, py, deg)
        return self.poly(pts, role, **kw)

    def circle(self, cx, cy, r, role, n_sides=28, **kw):
        return self.poly(circle_pts(cx, cy, r, n_sides), role, **kw)

    def bar(self, a, b, w, role, **kw):
        (x0, y0), (x1, y1) = a, b
        dx, dy = x1 - x0, y1 - y0
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln * w / 2, dx / ln * w / 2
        return self.poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny),
                          (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], role, **kw)

    def line(self, pts, colour=INK, lw=0.9, dash=False, alpha=230):
        self.items.append({"k": "line", "pts": [tuple(p) for p in pts],
                           "colour": colour, "lw": lw, "dash": dash,
                           "alpha": alpha})
        return self

    # -- hardware
    def bolt(self, cx, cy, r=0.9):
        """A hex-head bolt seen end-on."""
        self.poly(circle_pts(cx, cy, r, 6, math.pi / 6), "steel", lw=0.6)
        self.circle(cx, cy, r * 0.45, "dark", n_sides=10, lw=0.3)
        return self

    def screw(self, cx, cy, r=0.6, deg=30):
        self.circle(cx, cy, r, "steel", n_sides=12, lw=0.5)
        a = math.radians(deg)
        self.line([(cx - r * 0.8 * math.cos(a), cy - r * 0.8 * math.sin(a)),
                   (cx + r * 0.8 * math.cos(a), cy + r * 0.8 * math.sin(a))],
                  INK, 0.35)
        return self

    def rivets(self, pts, r=0.35):
        for x, y in pts:
            self.circle(x, y, r, "steel", n_sides=8, lw=0.3)
        return self

    def spring(self, a, b, coils=8, r=1.0, lw=0.5):
        (x0, y0), (x1, y1) = a, b
        dx, dy = x1 - x0, y1 - y0
        ln = math.hypot(dx, dy) or 1.0
        ux, uy, nx, ny = dx / ln, dy / ln, -dy / ln, dx / ln
        pts = [a]
        for i in range(1, 2 * coils):
            t = i / (2 * coils)
            s = r if i % 2 else -r
            pts.append((x0 + dx * t + nx * s, y0 + dy * t + ny * s))
        pts.append(b)
        return self.line(pts, INK, lw)

    def strut(self, a, b, frac=0.55, r_body=1.1, r_rod=0.45, n=None):
        """A gas strut / damper: a body cylinder from a, a rod to b."""
        (x0, y0), (x1, y1) = a, b
        m = (x0 + (x1 - x0) * frac, y0 + (y1 - y0) * frac)
        self.bar(a, m, 2 * r_body, "dark", lw=0.8, n=n)
        self.bar(m, b, 2 * r_rod, "steel", lw=0.6)
        self.circle(x0, y0, r_body * 0.8, "steel", n_sides=10, lw=0.5)
        self.circle(x1, y1, r_body * 0.7, "steel", n_sides=10, lw=0.5)
        return self

    def hose(self, pts, w=1.2, role="rubber", ribs=True):
        for a, b in zip(pts, pts[1:]):
            self.bar(a, b, w, role, lw=0.6)
            self.circle(b[0], b[1], w / 2, role, n_sides=10, lw=0)
        if ribs:
            for a, b in zip(pts, pts[1:]):
                ln = math.hypot(b[0] - a[0], b[1] - a[1])
                k = max(1, int(ln / 1.4))
                for i in range(1, k):
                    t = i / k
                    cx, cy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                    nx, ny = -(b[1] - a[1]) / ln, (b[0] - a[0]) / ln
                    self.line([(cx + nx * w / 2, cy + ny * w / 2),
                               (cx - nx * w / 2, cy - ny * w / 2)],
                              (110, 110, 112), 0.25)
        return self

    def fins(self, x0, x1, y0, y1, n, role="steel", vertical=True):
        """n thin plates: heat leaves where the heat is."""
        for i in range(n):
            if vertical:
                x = x0 + (x1 - x0) * (i + 0.5) / n
                w = (x1 - x0) / n * 0.45
                self.rect(x - w / 2, y0, x + w / 2, y1, role, lw=0.5)
            else:
                y = y0 + (y1 - y0) * (i + 0.5) / n
                h = (y1 - y0) / n * 0.45
                self.rect(x0, y - h / 2, x1, y + h / 2, role, lw=0.5)
        return self

    def seam(self, pts, strength=1.0):
        """Epsilon's light, out through a seam -- never a strip of paint."""
        self.items.append({"k": "seam", "pts": [tuple(p) for p in pts],
                           "s": strength})
        return self

    def glow(self, cx, cy, r, strength=1.0, colour=(255, 176, 96)):
        if strength > 0.02:
            self.items.append({"k": "glow", "c": (cx, cy), "r": r,
                               "s": strength, "colour": colour})
        return self

    def stencil(self, x, y, txt, size=1.2, deg=0.0, colour=(60, 60, 62)):
        self.items.append({"k": "text", "xy": (x, y), "t": txt, "size": size,
                           "deg": deg, "colour": colour})
        return self

    def chips(self, pts, size=0.5, seed=1):
        """Paint chipped back to steel where hands, tools and heat work."""
        rng = random.Random(seed)
        for x, y in pts:
            s = size * rng.uniform(0.6, 1.3)
            self.poly([(x - s, y), (x - s * 0.2, y + s * 0.7),
                       (x + s * 0.9, y + s * 0.2), (x + s * 0.3, y - s * 0.6)],
                      "steel", lw=0)
        return self

    # -- diagram marks
    def energy(self, pts, lw=0.9):
        self.items.append({"k": "arrow", "pts": [tuple(p) for p in pts],
                           "colour": ENERGY, "lw": lw})
        return self

    def travel(self, cx, cy, r, a0, a1):
        self.items.append({"k": "arrow", "pts": arc_pts(cx, cy, r, a0, a1),
                           "colour": TRAVEL, "lw": 0.6, "dash": True})
        return self

    def travel_line(self, a, b):
        self.items.append({"k": "arrow", "pts": [a, b], "colour": TRAVEL,
                           "lw": 0.6, "dash": True})
        return self

    def anchor(self, n, x, y):
        self.anchors[n] = (x, y)
        return self

    def bounds(self):
        xs, ys = [], []
        for it in self.items:
            if it["k"] in ("poly", "line", "seam", "arrow"):
                for x, y in it["pts"]:
                    xs.append(x)
                    ys.append(y)
        return min(xs), min(ys), max(xs), max(ys)


def _hatch(layer, pts, colour, spacing, width):
    """Section hatching (45 deg) clipped to a polygon."""
    W, H = layer.size
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    lines = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lines)
    xs, ys = zip(*pts)
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    k = x0 - (y1 - y0)
    while k < x1:
        d.line([(k, y1), (k + (y1 - y0), y0)], fill=colour + (200,),
               width=width)
        k += spacing
    clear = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.alpha_composite(Image.composite(lines, clear, mask))


def _shade(layer, pts):
    """Volume: each part lit from above -- a lighter top, a darker lower
    third -- so a form reads as a solid, not a flat cut-out."""
    xs, ys = zip(*pts)
    x0, x1 = int(min(xs)), int(max(xs)) + 1
    y0, y1 = int(min(ys)), int(max(ys)) + 1
    if y1 - y0 < 6 or x1 - x0 < 2:
        return
    W, H = layer.size
    grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    hgt = y1 - y0
    for i in range(0, hgt, 2):
        t = i / hgt
        if t < 0.18:
            col = (255, 255, 255, int(46 * (1 - t / 0.18)))
        elif t > 0.62:
            col = (0, 0, 0, int(52 * (t - 0.62) / 0.38))
        else:
            continue
        gd.line([(x0, y0 + i), (x1, y0 + i)], fill=col, width=2)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    clear = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.alpha_composite(Image.composite(grad, clear, mask))


def render(g, w, h, scale=None, bounds=None, pad=20, bg=PAPER, grey=False):
    """Draw `g` into a w x h image. Returns (image, cm -> px)."""
    x0, y0, x1, y1 = bounds or g.bounds()
    if scale is None:
        scale = min((w - 2 * pad) / (x1 - x0), (h - 2 * pad) / (y1 - y0))
    ox = w / 2 - (x0 + x1) / 2 * scale
    oy = h / 2 + (y0 + y1) / 2 * scale

    def P(x, y):
        return (ox + x * scale, oy - y * scale)

    W, H = w * SS, h * SS
    base = Image.new("RGBA", (W, H), (bg + (255,)) if bg else (0, 0, 0, 0))

    def px(pts):
        return [tuple(v * SS for v in P(x, y)) for x, y in pts]

    glows = []
    for it in g.items:
        k = it["k"]
        if k == "glow":
            glows.append(it)
            continue
        # Each item draws into a layer the size of its own bounds (plus a
        # margin for strokes and seam glow), then composites in place.
        if k == "text":
            gx, gy = P(*it["xy"])
            fsz = max(6, int(it["size"] * scale * SS * 0.85))
            allp = [(gx * SS, gy * SS),
                    (gx * SS + fsz * len(it["t"]) * 0.7, gy * SS + fsz * 1.4)]
        else:
            allp = px(it["pts"])
        mx = int(14 * SS + 3 * scale * SS / 9) + 8
        xs, ys = zip(*allp)
        lx0, ly0 = max(0, int(min(xs)) - mx), max(0, int(min(ys)) - mx)
        lx1, ly1 = min(W, int(max(xs)) + mx), min(H, int(max(ys)) + mx)
        if lx1 <= lx0 or ly1 <= ly0:
            continue
        layer = Image.new("RGBA", (lx1 - lx0, ly1 - ly0), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)

        def loc(pts):
            return [(x - lx0, y - ly0) for x, y in pts]

        if k == "poly":
            pts = loc(px(it["pts"]))
            fill = FILL[it["role"]]
            d.polygon(pts, fill=fill + (it["alpha"],))
            if it["role"] not in ("white", "glass") and len(pts) > 2:
                _shade(layer, pts)
            if it["hatch"]:
                _hatch(layer, pts, (70, 66, 60), int(1.1 * scale * SS),
                       max(1, SS))
            d = ImageDraw.Draw(layer)
            if it["lw"]:
                d.line(pts + [pts[0]], fill=INK + (235,),
                       width=max(1, int(it["lw"] * SS * scale / 9)),
                       joint="curve")
        elif k in ("line", "arrow"):
            pts = loc(px(it["pts"]))
            wpx = max(1, int(it["lw"] * SS * scale / 9))
            col = it["colour"]
            if it.get("dash"):
                for (ax, ay), (bx, by) in zip(pts, pts[1:]):
                    n = max(1, int(math.hypot(bx - ax, by - ay) / (5 * SS)))
                    for i in range(0, n, 2):
                        d.line([(ax + (bx - ax) * i / n,
                                 ay + (by - ay) * i / n),
                                (ax + (bx - ax) * (i + 1) / n,
                                 ay + (by - ay) * (i + 1) / n)],
                               fill=col + (it.get("alpha", 230),), width=wpx)
            else:
                d.line(pts, fill=col + (it.get("alpha", 230),), width=wpx,
                       joint="curve")
            if k == "arrow":
                (ax, ay), (bx, by) = pts[-2], pts[-1]
                ang = math.atan2(by - ay, bx - ax)
                s = 2.2 * SS * scale / 9 + 6 * SS
                d.polygon([(bx, by),
                           (bx - s * math.cos(ang - 0.45),
                            by - s * math.sin(ang - 0.45)),
                           (bx - s * math.cos(ang + 0.45),
                            by - s * math.sin(ang + 0.45))], fill=col + (240,))
        elif k == "seam":
            pts = loc(px(it["pts"]))
            wpx = max(1, int(0.5 * SS * scale / 9))
            glow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
            ImageDraw.Draw(glow).line(pts, fill=SEAM + (int(150 * it["s"]),),
                                      width=wpx * 5)
            layer.alpha_composite(glow.filter(ImageFilter.GaussianBlur(
                wpx * 2.5)))
            d = ImageDraw.Draw(layer)
            d.line(pts, fill=(210, 255, 180, 255), width=wpx)
        elif k == "text":
            x, y = P(*it["xy"])
            f = font(max(6, int(it["size"] * scale * SS * 0.85)), mono=True)
            d.text((x * SS - lx0, y * SS - ly0), it["t"], font=f,
                   fill=it["colour"] + (210,))
            if it["deg"]:
                layer = layer.rotate(it["deg"], center=(x * SS - lx0,
                                                        y * SS - ly0))
        base.alpha_composite(layer, dest=(lx0, ly0))
    for it in glows:
        (cx, cy), r, s, colour = it["c"], it["r"], it["s"], it["colour"]
        x, y = P(cx, cy)
        rr = r * scale * SS
        m = int(rr * 1.4) + 4
        lx0, ly0 = max(0, int(x * SS - m)), max(0, int(y * SS - m))
        lx1, ly1 = min(W, int(x * SS + m)), min(H, int(y * SS + m))
        if lx1 <= lx0 or ly1 <= ly0:
            continue
        gl = Image.new("RGBA", (lx1 - lx0, ly1 - ly0), (0, 0, 0, 0))
        d = ImageDraw.Draw(gl)
        cx2, cy2 = x * SS - lx0, y * SS - ly0
        for k2 in range(10, 0, -1):
            a = int(255 * min(1.0, s) * (1 - k2 / 10) ** 1.5)
            d.ellipse([cx2 - rr * k2 / 10, cy2 - rr * k2 / 10,
                       cx2 + rr * k2 / 10, cy2 + rr * k2 / 10],
                      fill=colour + (a,))
        base.alpha_composite(gl.filter(ImageFilter.GaussianBlur(rr * 0.12)),
                             dest=(lx0, ly0))
    img = base.resize((w, h), Image.LANCZOS)
    if grey:
        img = img.convert("L").convert("RGBA")
    return img, P


def balloons(img, P, g, numbers, place, ox=0, oy=0):
    """Numbered balloons with leaders. `place`: n -> (dx, dy) px offset of
    the balloon from its anchor."""
    d = ImageDraw.Draw(img)
    f = font(15, bold=True)
    for n in numbers:
        if n not in g.anchors:
            continue
        ax, ay = P(*g.anchors[n])
        ax, ay = ax + ox, ay + oy
        dx, dy = place.get(n, (30, -30))
        bx, by = ax + dx, ay + dy
        d.line([(ax, ay), (bx, by)], fill=CALL, width=2)
        d.ellipse([ax - 3, ay - 3, ax + 3, ay + 3], fill=CALL)
        d.ellipse([bx - 13, by - 13, bx + 13, by + 13], fill=(255, 252, 244),
                  outline=CALL, width=2)
        t = str(n)
        tw = d.textlength(t, font=f)
        d.text((bx - tw / 2, by - 9), t, font=f, fill=CALL)
