"""Weapon-family CONCEPT geometry and a small sketch renderer. EXPLORATION
ONLY -- not assets, not models. (Arty, 2026-10-10.)

Every concept is a side elevation in centimetres -- x forward (the muzzle
is on the right), y up, the grip near the origin -- built from a few
primitives, each with a ROLE:

    body     the station-built frame, grip and housings
    dark     heat-darkened or shadowed metal, slots, ports
    moving   a part that moves when the weapon works
    heart    the part that stores the energy (Direction C's swappable part)
    energy   where energy actually shows (a glow, a bead, a slug)
    device   the player's Static Pulse device (Direction D)
    line     thin structure: spindles, links, bands

A concept is a function `f(state, direction)`:
  * `state` -- a dict of the weapon's own parameters for one moment
    (hammer angle, bead travel, flyball spread, lever swing, flywheel
    spin...), so a sheet can draw the same concept at rest, firing and
    recovering;
  * `direction` -- "A" station instruments, "B" Epsilon's readings,
    "C" visitor hearts, "D" around the device, or "" for the neutral
    sketch. B swaps in Epsilon's own forms; C and D add their parts; the
    renderer's style does the rest.

Drawn with PIL, supersampled, with a slight double-stroke wobble so it
reads as a sketch, not CAD. Deterministic.
"""

from __future__ import annotations

import math
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SS = 3                       # supersampling


def font(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT, size)


# ------------------------------------------------------------- geometry

def _rot(pts, cx, cy, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s,
             cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


class G:
    """A concept drawing: primitives in cm, plus named anchors for
    callouts."""

    def __init__(self, name):
        self.name = name
        self.items = []
        self.anchors = {}

    def poly(self, pts, role, name=None):
        self.items.append(("poly", [tuple(p) for p in pts], role))
        if name:
            xs, ys = zip(*pts)
            self.anchors[name] = (sum(xs) / len(xs), sum(ys) / len(ys))
        return self

    def rect(self, x0, y0, x1, y1, role, rot=0.0, name=None, pivot=None):
        pts = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        if rot:
            cx, cy = pivot or ((x0 + x1) / 2, (y0 + y1) / 2)
            pts = _rot(pts, cx, cy, rot)
        return self.poly(pts, role, name)

    def bar(self, a, b, width, role, name=None):
        """A straight bar of `width` from point a to point b."""
        (x0, y0), (x1, y1) = a, b
        dx, dy = x1 - x0, y1 - y0
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln * width / 2, dx / ln * width / 2
        return self.poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny),
                          (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], role,
                         name)

    def circle(self, cx, cy, r, role, name=None, sides=28):
        pts = [(cx + r * math.cos(2 * math.pi * i / sides),
                cy + r * math.sin(2 * math.pi * i / sides))
               for i in range(sides)]
        self.items.append(("poly", pts, role))
        if name:
            self.anchors[name] = (cx, cy)
        return self

    def ellipse(self, cx, cy, rx, ry, role, rot=0.0, name=None):
        pts = [(cx + rx * math.cos(2 * math.pi * i / 28),
                cy + ry * math.sin(2 * math.pi * i / 28)) for i in range(28)]
        if rot:
            pts = _rot(pts, cx, cy, rot)
        self.items.append(("poly", pts, role))
        if name:
            self.anchors[name] = (cx, cy)
        return self

    def line(self, pts, role="line", width=0.8, dash=False):
        self.items.append(("line", [tuple(p) for p in pts], role, width,
                           dash))
        return self

    def glow(self, cx, cy, r, strength=1.0, colour=(255, 190, 110)):
        if strength > 0.02:
            self.items.append(("glow", (cx, cy), r, strength, colour))
        return self

    def motion(self, pts, role="line"):
        """Speed lines: a stroke drawn faint and dashed."""
        self.items.append(("line", [tuple(p) for p in pts], role, 0.5, True))
        return self

    def anchor(self, name, x, y):
        self.anchors[name] = (x, y)
        return self

    def bounds(self):
        xs, ys = [], []
        for it in self.items:
            if it[0] in ("poly", "line"):
                for x, y in it[1]:
                    xs.append(x)
                    ys.append(y)
            elif it[0] == "glow":
                (cx, cy), r = it[1], it[2]
                xs += [cx - r * 0.5, cx + r * 0.5]
                ys += [cy - r * 0.5, cy + r * 0.5]
        return min(xs), min(ys), max(xs), max(ys)


def _arc(cx, cy, r, a0, a1, n=12):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


def _grip(g, x, y=-2.0, rake=1.0, h=14.0, w=7.0, role="body"):
    """A raked pistol grip. Kept only to draw what we are moving AWAY
    from: there are no hands in first person, so a grip is vestigial."""
    g.poly([(x - w / 2, y), (x + w / 2, y), (x + w / 2 - 4 * rake, y - h),
            (x - w / 2 - 4 * rake, y - h + 1)], role, "grip")


def _mount(g, x, y, d):
    """How the apparatus is carried, by direction -- never a pistol grip.

    ""/C/D  clamped round the player's own device (the recommendation):
            the device's prism under the frame, its lit tip forward, two
            clamp bands. Drawn at concept scale, not its current size.
    A       a station tool's bail handle: carried equipment.
    B       Epsilon: a stalk that has grown down and back, as if the gun
            were attached to something.
    """
    if d == "A":
        g.line([(x - 7, y), (x - 9, y - 10), (x + 5, y - 11), (x + 5, y)],
               "body", 2.6)
        g.rect(x - 8.5, y - 11.6, x + 4.5, y - 9.6, "dark", name="handle")
        return
    if d == "B":
        g.poly([(x - 4, y), (x + 4, y), (x + 1, y - 6), (x - 6, y - 12),
                (x - 11, y - 13), (x - 8, y - 9), (x - 4, y - 5)], "dark",
               "stalk")
        return
    g.poly([(x - 13, y - 8.5), (x + 9, y - 7.2), (x + 9, y - 2.4),
            (x - 13, y - 1.6)], "device", "device")
    g.line([(x - 13, y - 5), (x + 9, y - 4.8)], "line", 0.35)
    g.rect(x + 9, y - 6.4, x + 11, y - 3.2, "energy", name="device tip")
    g.glow(x + 10, y - 4.8, 4, 0.45, (190, 225, 255))
    for bx in (x - 8, x + 3):
        g.rect(bx - 1.2, y - 2.6, bx + 1.2, y + 0.6, "dark")


def _epsilon_growth(g, pts, seed):
    """Direction B: an asymmetric plate growth breaking out of the body,
    with one internal seam of light."""
    rng = random.Random(seed)
    g.poly(pts, "dark")
    (x0, y0), (x1, y1) = pts[0], pts[len(pts) // 2]
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    g.line([(x0 + rng.uniform(0, 2), y0), (mx, my + rng.uniform(-1, 1)),
            (x1, y1)], "energy", 0.6)


# ------------------------------------------------------------ FOUNDRY
# State: hammer (deg, 0 = struck, ~68 = raised), glow 0..1, flash 0..1.

def foundry_hammer(state=None, d=""):
    s = {"hammer": 68, "glow": 1.0, "flash": 0.0}
    s.update(state or {})
    g = G("Foundry: crucible and drop hammer")
    g.poly([(-10, -3), (14, -3), (15, 5), (-9, 5)], "body", "frame")
    _mount(g, -3, -2.0, d)
    g.rect(-1, -6, 7, -4, "line")
    if d == "B":
        # Epsilon: the crucible is a swollen dark mass; the hammer is a
        # claw that has grown out of it rather than a hinged arm.
        g.poly([(9, -6), (24, -7), (38, -2), (40, 9), (30, 16), (14, 15),
                (8, 8)], "dark", "crucible")
        g.poly([(36, -1), (47, 1), (47, 8), (37, 10)], "dark", "mouth")
        a = s["hammer"]
        claw = _rot([(8, 11), (13, 22), (21, 31), (25, 30), (19, 23),
                     (17, 15)], 10, 15, a - 68)
        g.poly(claw, "moving", "hammer")
        g.line([(14, 2), (24, 6), (34, 4)], "energy", 0.7)
    else:
        g.poly([(10, -5), (36, -3), (38, 11), (12, 13)], "heart",
               "crucible")
        g.line([(18, -4.4), (19, 12.4)], "line", 0.9)
        g.line([(28, -3.6), (29.2, 11.8)], "line", 0.9)
        g.poly([(36, -1), (46, 0), (46, 9), (37, 10)], "dark", "mouth")
        g.rect(10, 13, 17, 15.5, "body", name="anvil")
        # The hammer: a rear hinge on a post, an arm, a heavy head.
        g.poly([(-9, 5), (-3, 5), (-4, 17), (-8, 17)], "body", "post")
        a = math.radians(s["hammer"])
        px, py = -6.0, 17.0
        hx, hy = px + 19 * math.cos(a), py + 19 * math.sin(a)
        g.bar((px, py), (hx, hy), 3.2, "moving", "hammer arm")
        head = _rot([(hx - 3.5, hy - 3.2), (hx + 3.5, hy - 3.2),
                     (hx + 3.5, hy + 3.4), (hx - 3.5, hy + 3.4)], hx, hy,
                    math.degrees(a))
        g.poly(head, "moving", "hammer")
        g.circle(px, py, 2.6, "body", "hinge")
    if d == "C":
        # Visitor heart: the crucible's lining carries the visited world.
        g.poly([(13, -3), (34, -1.5), (35.5, 9.5), (14.5, 11)], "visitor",
               "lining")
    g.glow(46.5, 4.5, 6 + 10 * s["flash"], 0.35 * s["glow"] + s["flash"])
    if s["flash"] > 0:
        g.poly([(46, 1), (60, -2), (54, 4.5), (62, 11), (46, 8)], "energy")
    g.anchor("muzzle", 46, 4.5)
    return g


def foundry_piledriver(state=None, d=""):
    g = G("Foundry: pile driver")
    g.poly([(-10, -3), (14, -3), (15, 5), (-9, 5)], "body", "frame")
    _mount(g, -3, -2.0, d)
    g.poly([(10, -5), (30, -4), (31, 7), (11, 8)], "heart", "anvil")
    g.rect(13, 8, 15, 32, "body")
    g.rect(25, 8, 27, 32, "body")
    g.rect(12, 31, 28, 34, "body", name="column cap")
    for i, y in enumerate((9, 13, 17, 21)):
        g.rect(15.5, y, 24.5, y + 3, "moving", name="pucks" if i == 1
               else None)
    g.rect(30, -1, 46, 6, "dark", name="striker")
    return g


def foundry_kiln(state=None, d=""):
    s = {"door": 0}
    s.update(state or {})
    g = G("Foundry: kiln door")
    g.poly([(-10, -3), (8, -3), (9, 5), (-9, 5)], "body", "frame")
    _mount(g, -3, -2.0, d)
    bell = [(6, -6), (14, -9), (26, -10), (34, -7), (37, 2), (34, 11),
            (26, 15), (14, 14), (6, 9)]
    g.poly(bell, "heart", "kiln bell")
    door = _rot([(36, -6), (39, -5), (39, 10), (36, 11)], 38, 11, -s["door"])
    g.poly(door, "moving", "door")
    return g


# ----------------------------------------------------------- SIGHTLINE
# State: bead 0..1 (yoke -> front stop), ring 0..1 (tine vibration).

def sightline_tines(state=None, d=""):
    s = {"bead": 1.0, "ring": 0.0}
    s.update(state or {})
    g = G("Sightline: resonant tines")
    g.poly([(-12, -3), (14, -2), (14, 4), (-10, 4)], "body", "chassis")
    _mount(g, -2, -2.0, d)
    g.poly([(-12, 1), (-22, -1), (-23, -6), (-19, -6), (-12, -3)], "body",
           "brace")
    amp = 1.4 * s["ring"]
    if d == "B":
        # Epsilon: one tine longer and barbed, the other grown short --
        # asymmetric, with the light running down the slot.
        g.poly([(12, -5), (21, -4), (21, 10), (12, 11)], "dark", "yoke")
        g.poly([(21, 6), (82, 4.4), (79, 6.5), (66, 6.2), (63, 8.5),
                (58, 6.0), (21, 8.5)], "dark", "upper tine")
        g.poly([(21, -2), (60, 0.6), (60, 2.0), (21, 0)], "dark",
               "lower tine")
        g.line([(22, 3), (78, 3.3)], "energy", 0.4)
    else:
        g.poly([(12, -5), (21, -4), (21, 10), (12, 11)], "heart", "yoke")
        g.rect(13, 10.5, 20, 12.5, "body", name="collar")
        # Side by side (left / right): from the side the near tine hides
        # the far one (dashed). The plan inset shows the fork from above.
        for k, off in ((0, 0.0), (1, amp), (2, -amp)) if amp else ((0, 0.0),):
            role = "moving" if k == 0 else "ghost"
            g.poly([(21, 1.6), (77, 2.4 + off), (77, 3.6 + off), (21, 4.4)],
                   role, "upper tine" if k == 0 else None)
        g.line([(21, 5.0), (77, 4.0)], "speed", 0.5, True)
        g.rect(75.5, 3.6, 77, 6.4, "body", name="front post")
        g.rect(16, 12.5, 18.5, 14.5, "body", name="rear notch")
    if d == "C":
        g.poly([(13.5, -3), (19.5, -2.5), (19.5, 8.5), (13.5, 9.5)],
               "visitor", "yoke inlay")
    if s["bead"] is not None and s["bead"] >= 0:
        bx = 23 + 50 * s["bead"]
        g.circle(bx, 3.0, 1.25, "energy", "bead")
        g.glow(bx, 3.0, 4, 0.6)
    if s["ring"] > 0.5:
        g.glow(78, 3, 6, 0.8, (220, 235, 255))
    g.anchor("muzzle", 77, 3)
    return g


def sightline_plan(state=None):
    """The tines FROM ABOVE (an inset): side by side, the slot between
    them is the line of fire, the bead in it."""
    s = {"bead": 1.0}
    s.update(state or {})
    g = G("Sightline: the fork from above")
    g.rect(10, -7.5, 21, 7.5, "heart", name="yoke")
    g.poly([(21, 5.0), (77, 0.9), (77, 2.1), (21, 7.0)], "moving", "tine")
    g.poly([(21, -5.0), (77, -0.9), (77, -2.1), (21, -7.0)], "moving")
    if s["bead"] is not None and s["bead"] >= 0:
        g.circle(23 + 50 * s["bead"], 0, 1.1, "energy", "bead")
    g.rect(-6, -3, 10, 3, "body")
    return g


def sightline_surveyor(state=None, d=""):
    g = G("Sightline: surveyor")
    g.poly([(-12, -3), (24, -2), (24, 4), (-10, 4)], "body", "chassis")
    _mount(g, -2, -2.0, d)
    g.rect(24, 0, 58, 2.5, "dark", name="dart barrel")
    g.poly([(4, 4), (8, 4), (10, 16), (6, 16)], "body")
    g.poly([(20, 4), (24, 4), (22, 16), (18, 16)], "body", "yoke")
    g.rect(2, 15, 30, 22, "heart", rot=-4, name="telescope")
    g.line(_arc(14, 9, 9, 200, 340), "line", 1.0)
    for a in range(205, 340, 15):
        x = 14 + 9 * math.cos(math.radians(a))
        y = 9 + 9 * math.sin(math.radians(a))
        g.line([(x, y), (x + 1.4 * math.cos(math.radians(a)),
                         y + 1.4 * math.sin(math.radians(a)))], "line", 0.5)
    return g


def sightline_baseline(state=None, d=""):
    # Seen FROM ABOVE: a long cross-bar with an optic head at each end.
    g = G("Sightline: long baseline (seen from above)")
    g.rect(-12, -3, 30, 3, "body", name="chassis")
    g.rect(14, -26, 20, 26, "heart", name="baseline bar")
    g.rect(11, -30, 23, -24, "dark", name="optic head")
    g.rect(11, 24, 23, 30, "dark")
    g.rect(30, -1, 62, 1, "dark", name="barrel")
    return g


# ---------------------------------------------------------- SWITCHBACK
# State: spin 0..1 (governor run-up = live spread), shuttle 0..1.

def switchback_governor(state=None, d=""):
    s = {"spin": 0.0, "shuttle": 0.0, "flash": 0.0}
    s.update(state or {})
    g = G("Switchback: governor and shuttle")
    g.poly([(-6, -4), (22, -4), (24, 8), (-4, 9)], "body", "receiver")
    g.poly([(22, -2.5), (36, -1.5), (36, 7), (22, 7.5)], "body",
           "forward housing")
    g.rect(36, 0.6, 42, 5.4, "dark", name="ports")
    _mount(g, 1, -4, d)
    g.poly([(-6, 6), (-20, 4), (-21, -8), (-17, -8), (-16, 1), (-6, 2)],
           "body", "brace")
    g.rect(4, 0.5, 20, 4, "dark", name="shuttle slot")
    sx = 4.5 + 10 * s["shuttle"]
    g.rect(sx, 0.9, sx + 5, 3.6, "moving", name="shuttle")
    if d == "B":
        g.poly([(2, 9), (6, 18), (11, 21), (13, 14), (10, 9)], "dark",
               "bulb")
        g.line([(5, 11), (8, 16), (11, 15)], "energy", 0.7)
    else:
        th = math.radians(14 + 58 * s["spin"])
        top = (7, 26)
        g.line([(7, 9), top], "line", 1.4)
        g.circle(top[0], top[1], 1.2, "body")
        sleeve = 14 + 5 * s["spin"]
        for side in (-1, 1):
            bx = top[0] + side * 13 * math.sin(th)
            by = top[1] - 13 * math.cos(th)
            g.line([top, (bx, by)], "line", 0.9)
            mx = top[0] + side * 6.5 * math.sin(th)
            my = top[1] - 6.5 * math.cos(th)
            g.line([(7, sleeve), (mx, my)], "line", 0.6)
            g.circle(bx, by, 3.2, "visitor" if d == "C" else "heart",
                     "flyballs" if side == 1 else None)
        g.rect(5.8, sleeve - 0.8, 8.2, sleeve + 0.8, "body")
        if s["spin"] > 0.2:
            ry = top[1] - 13 * math.cos(th)
            g.ellipse(7, ry, 13 * math.sin(th) + 3.2, 1.8, "speed")
    g.glow(42, 3, 5 + 6 * s["flash"], s["flash"])
    g.anchor("muzzle", 42, 3)
    return g


def switchback_loom(state=None, d=""):
    g = G("Switchback: shuttle loom")
    g.poly([(-6, -4), (34, -3), (34, 12), (-4, 13)], "body", "harp frame")
    g.rect(34, 1, 42, 5, "dark", name="ports")
    _mount(g, 1, -4, d)
    zz = [(2, 9), (8, 3), (14, 9), (20, 3), (26, 9), (32, 3)]
    g.line(zz, "dark", 1.6)
    g.rect(13, 7.5, 17, 10.5, "moving", name="shuttle")
    return g


def switchback_escapement(state=None, d=""):
    g = G("Switchback: escapement")
    g.poly([(-6, -4), (28, -3), (28, 7), (-4, 8)], "body", "receiver")
    g.rect(28, 1, 40, 5, "dark", name="barrel")
    _mount(g, 1, -4, d)
    cx, cy, r = 9, 16, 9
    teeth = []
    for i in range(30):
        a = 2 * math.pi * i / 30
        rr = r if i % 2 == 0 else r + 2.2
        teeth.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    g.poly(teeth, "heart", "escapement wheel")
    g.circle(cx, cy, 2, "body")
    g.poly([(18, 18), (24, 22), (22, 12), (19, 14)], "moving", "pallet")
    return g


# ------------------------------------------------------------ BULKHEAD
# State: lever (deg, 0 = locked, ~70 = swung out), flash 0..1.

def bulkhead_hatch(state=None, d=""):
    s = {"lever": 0.0, "flash": 0.0}
    s.update(state or {})
    g = G("Bulkhead: pressure hatch")
    g.poly([(-4, -5), (2, -6), (2, 8), (-3, 7)], "body", "rear cap")
    _mount(g, 4, -6, d)
    if d == "B":
        # Epsilon: the clamshell -- two jaws instead of a door.
        g.poly([(2, -6), (32, -9), (36, -3), (30, 0), (2, 0)], "dark",
               "lower jaw")
        g.poly([(2, 1), (30, 2), (37, 10), (32, 15), (2, 9)], "dark",
               "upper jaw")
        g.line([(6, 1), (32, 1.5)], "energy", 0.8)
        g.anchor("muzzle", 36, 2)
        return g
    g.poly([(2, -6), (30, -7), (30, 9), (2, 8)], "body", "pressure drum")
    for x in (8, 16, 24):
        g.rect(x - 0.8, -6.8 + x * -0.02, x + 0.8, 8.8 + x * 0.02, "dark")
    g.circle(20, 2.5, 2.4, "body", "gauge")
    g.line([(20, 2.5), (21.5, 3.8)], "line", 0.5)
    g.rect(30, -13, 34, 15, "visitor" if d == "C" else "heart",
           name="hatch")
    for y in (-8, -2, 4, 10):
        g.rect(34, y - 0.8, 35, y + 0.8, "dark")
    g.rect(28, -12.5, 30, -10.5, "moving")
    g.rect(28, 12.5, 30, 14.5, "moving")
    a = 180 - s["lever"]
    px, py = 28.0, 10.5
    ex = px + 24 * math.cos(math.radians(a))
    ey = py + 24 * math.sin(math.radians(a))
    g.bar((px, py), (ex, ey), 1.8, "moving", "dogging lever")
    g.circle(ex, ey, 1.6, "moving")
    g.circle(px, py, 1.6, "body")
    g.glow(35, 1, 6 + 14 * s["flash"], s["flash"])
    if s["flash"] > 0:
        for yy in (-8, -2, 4, 10):
            g.poly([(35, yy - 1), (46, yy - 2 + yy * 0.3),
                    (46, yy + 2 + yy * 0.3), (35, yy + 1)], "energy")
    g.anchor("muzzle", 34, 1)
    return g


def bulkhead_face(d=""):
    """The hatch seen from the FRONT (an inset): eight ports, four dogs."""
    g = G("Bulkhead: the hatch face")
    g.circle(0, 0, 12, "visitor" if d == "C" else "heart", "hatch face")
    g.circle(0, 0, 10.2, "body")
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        g.circle(6.4 * math.cos(a), 6.4 * math.sin(a), 1.3, "dark",
                 "ports" if i == 0 else None)
    g.circle(0, 0, 2.2, "dark")
    for i in range(4):
        a = 2 * math.pi * i / 4
        g.rect(11.5 * math.cos(a) - 1, 11.5 * math.sin(a) - 1,
               11.5 * math.cos(a) + 1, 11.5 * math.sin(a) + 1, "moving")
    return g


def bulkhead_bellows(state=None, d=""):
    g = G("Bulkhead: bellows")
    _mount(g, 2, -6, d)
    g.rect(-4, -6, 4, 8, "body", name="rear block")
    pleat = [(4, -6)]
    for i in range(7):
        x = 4 + i * 3 + 1.5
        pleat += [(x, -9 if i % 2 == 0 else -6)]
    pleat += [(26, -6), (26, 8)]
    for i in range(7):
        x = 26 - i * 3 - 1.5
        pleat += [(x, 11 if i % 2 == 0 else 8)]
    pleat += [(4, 8)]
    g.poly(pleat, "moving", "bellows")
    g.poly([(26, -4), (34, -8), (40, -12), (40, 16), (34, 12), (26, 6)],
           "heart", "bell mouth")
    return g


def bulkhead_clamshell(state=None, d=""):
    s = {"open": 0.0}
    s.update(state or {})
    g = G("Bulkhead: clamshell")
    _mount(g, 2, -6, d)
    g.rect(-4, -6, 6, 8, "body", name="hinge block")
    up = _rot([(6, 1), (32, 2), (38, 9), (30, 14), (6, 8)], 6, 4,
              18 * s["open"])
    lo = _rot([(6, -6), (32, -8), (37, -2), (30, 0), (6, 0)], 6, -2,
              -12 * s["open"])
    g.poly(up, "heart", "upper jaw")
    g.poly(lo, "heart", "lower jaw")
    return g


# --------------------------------------------------------- MASS DRIVER
# State: spin 0..1 (flywheel blur = charge), lean (deg), slug (bool),
# hopper (bool), clutch 0..1.

def massdriver_flywheel(state=None, d=""):
    s = {"spin": 0.0, "slug": True, "hopper": True, "clutch": 0.0,
         "flash": 0.0}
    s.update(state or {})
    g = G("Mass Driver: flywheel and clutch")
    g.poly([(-8, -4), (14, -4), (14, 4), (-8, 4)], "body", "frame")
    _mount(g, 4, -4, d)
    g.poly([(10, -1.5), (60, -0.5), (60, 6), (10, 7)], "body",
           "launch channel")
    g.line([(14, 2.8), (59, 2.8)], "dark", 1.3)
    if d == "B":
        # Epsilon: the captive mass -- a dense sphere in a closing cage.
        cx, cy = 0, 11
        for a in (200, 240, 280, 320, 360):
            g.line(_arc(cx, cy, 11, a - 18, a + 18, 6), "dark", 1.6)
        g.circle(cx, cy, 6.5, "dark", "captive mass")
        g.glow(cx, cy, 8, 0.6 + 0.4 * s["spin"], (210, 255, 160))
        g.anchor("muzzle", 60, 2.8)
        return g
    g.rect(4, -1, 12, 11, "dark", name="clutch")
    cx, cy, r = -3.0, 9.0, 12.5
    role = "visitor" if d == "C" else "heart"
    g.circle(cx, cy, r, role, "flywheel")
    g.circle(cx, cy, r - 2.6, "body")
    blur = s["spin"]
    if blur < 0.85:
        for i in range(6):
            a = 2 * math.pi * i / 6 + 0.4
            g.bar((cx, cy), (cx + (r - 2.4) * math.cos(a),
                             cy + (r - 2.4) * math.sin(a)), 2.0, "heart"
                  if blur < 0.35 else "ghost")
    if blur > 0.3:
        g.circle(cx, cy, r - 2.6, "blur" if blur < 0.85 else "spun")
        for rr in (r - 4, r - 7):
            g.line(_arc(cx, cy, rr, 20, 140, 10), "speed", 0.5, True)
    g.circle(cx, cy, 3.0, "body")
    g.poly([(15, 7), (24, 7), (27, 17), (12, 17)], "body", "hopper")
    if s["hopper"]:
        g.rect(15.5, 11, 22.5, 14.5, "energy" if False else "moving")
    if s["slug"]:
        g.rect(14, 0.6, 21, 5.2, "moving", name="slug")
    g.glow(60, 2.8, 5 + 10 * s["flash"], s["flash"], (230, 225, 255))
    g.anchor("muzzle", 60, 2.8)
    return g


def massdriver_sling(state=None, d=""):
    g = G("Mass Driver: ballast sling")
    g.poly([(-8, -4), (40, -2), (40, 5), (-8, 6)], "body", "stock rail")
    _mount(g, 4, -4, d)
    g.line([(40, 1.5), (34, 18), (24, 24)], "heart", 2.2)
    g.line([(40, 1.5), (34, -15), (24, -21)], "heart", 2.2)
    g.rect(6, -2, 14, 6, "moving", name="ballast block")
    g.line([(24, 24), (14, 4)], "line", 0.6)
    g.line([(24, -21), (14, 0)], "line", 0.6)
    return g


def massdriver_captive(state=None, d=""):
    g = G("Mass Driver: captive mass")
    g.poly([(-8, -4), (16, -3), (16, 5), (-8, 6)], "body", "frame")
    _mount(g, 4, -4, d)
    g.rect(40, 0, 56, 4, "dark", name="throat")
    cx, cy = 28, 2
    for a in range(0, 360, 45):
        g.line(_arc(cx, cy, 11, a, a + 25, 5), "body", 1.6)
    g.circle(cx, cy, 6, "heart", "mass")
    g.glow(cx, cy, 9, 0.6)
    return g


#: The recommended concept per family, then its two alternatives.
FAMILIES = {
    "foundry": (foundry_hammer, foundry_piledriver, foundry_kiln),
    "sightline": (sightline_tines, sightline_surveyor, sightline_baseline),
    "switchback": (switchback_governor, switchback_loom,
                   switchback_escapement),
    "bulkhead": (bulkhead_hatch, bulkhead_bellows, bulkhead_clamshell),
    "massdriver": (massdriver_flywheel, massdriver_sling,
                   massdriver_captive),
}


# ------------------------------------------------------------- styles
#: role -> (fill RGBA or None, outline RGB or None). "ghost" is a faint
#: copy (vibration), "blur"/"spun" a spinning disc, "speed" speed lines.
PAPER = (236, 232, 222)
INK = (44, 43, 41)

STYLES = {
    "sketch": {
        "body": ((186, 183, 175, 255), INK),
        "dark": ((104, 101, 96, 255), INK),
        "moving": ((150, 166, 172, 255), INK),
        "heart": ((214, 204, 170, 255), INK),
        "energy": ((255, 196, 92, 255), (150, 90, 30)),
        "device": ((214, 226, 236, 255), INK),
        "visitor": ((214, 204, 170, 255), INK),
        "line": (None, INK),
        "ghost": ((150, 166, 172, 70), (90, 100, 105)),
        "blur": ((150, 166, 172, 130), None),
        "spun": ((140, 154, 160, 230), INK),
        "speed": (None, (110, 110, 110)),
    },
    "silhouette": {k: ((20, 20, 22, 255), None) for k in (
        "body", "dark", "moving", "heart", "energy", "device", "visitor",
        "spun")},
    # Direction A: institutional paint, worn to metal where it works.
    "A": {
        "body": ((214, 218, 220, 255), INK),
        "dark": ((96, 98, 100, 255), INK),
        "moving": ((168, 172, 170, 255), INK),
        "heart": ((188, 200, 210, 255), INK),
        "energy": ((255, 196, 92, 255), (150, 90, 30)),
        "device": ((214, 226, 236, 255), INK),
        "visitor": ((188, 200, 210, 255), INK),
        "line": (None, INK),
        "ghost": ((168, 172, 170, 70), (90, 100, 105)),
        "blur": ((168, 172, 170, 130), None),
        "spun": ((160, 164, 162, 230), INK),
        "speed": (None, (110, 110, 110)),
    },
    # Direction B: Epsilon's near-black plate; light only from inside.
    "B": {
        "body": ((150, 150, 148, 255), INK),
        "dark": ((38, 38, 42, 255), (20, 20, 22)),
        "moving": ((58, 58, 64, 255), (20, 20, 22)),
        "heart": ((48, 48, 54, 255), (20, 20, 22)),
        "energy": ((120, 230, 70, 255), (120, 230, 70)),
        "device": ((214, 226, 236, 255), INK),
        "visitor": ((48, 48, 54, 255), INK),
        "line": (None, (30, 30, 32)),
        "ghost": ((58, 58, 64, 70), (40, 40, 44)),
        "blur": ((58, 58, 64, 130), None),
        "spun": ((58, 58, 64, 230), INK),
        "speed": (None, (110, 110, 110)),
    },
    # Direction C: station carrier, the heart in a visiting world's
    # material (a placeholder accent: the real one would come from the
    # source identity package).
    "C": {
        "body": ((186, 183, 175, 255), INK),
        "dark": ((104, 101, 96, 255), INK),
        "moving": ((150, 166, 172, 255), INK),
        "heart": ((214, 204, 170, 255), INK),
        "energy": ((255, 196, 92, 255), (150, 90, 30)),
        "device": ((214, 226, 236, 255), INK),
        "visitor": ((176, 104, 180, 255), (70, 30, 80)),
        "line": (None, INK),
        "ghost": ((150, 166, 172, 70), (90, 100, 105)),
        "blur": ((176, 104, 180, 130), None),
        "spun": ((166, 100, 170, 230), INK),
        "speed": (None, (110, 110, 110)),
    },
}
STYLES["D"] = dict(STYLES["sketch"])
STYLES["D"].update({
    "body": ((200, 198, 192, 150), (90, 90, 88)),
    "heart": ((214, 204, 170, 170), (90, 90, 88)),
    "moving": ((150, 166, 172, 170), (90, 90, 88)),
    "device": ((250, 250, 246, 255), (10, 10, 10)),
})


def render(g, box_w, box_h, style="sketch", scale=None, pad=10, bg=PAPER,
           seed=1, wobble=True, bounds=None):
    """Draw `g` into a new image of box_w x box_h px. Returns the image
    and a function cm -> px for callouts. `scale` (px per cm) fixes the
    size across drawings; otherwise the drawing fits the box."""
    x0, y0, x1, y1 = bounds or g.bounds()
    if scale is None:
        scale = min((box_w - 2 * pad) / (x1 - x0), (box_h - 2 * pad) /
                    (y1 - y0))
    ox = box_w / 2 - (x0 + x1) / 2 * scale
    oy = box_h / 2 + (y0 + y1) / 2 * scale

    def P(x, y):
        return (ox + x * scale, oy - y * scale)

    W, H = box_w * SS, box_h * SS
    base = Image.new("RGBA", (W, H), bg + (255,) if bg else (0, 0, 0, 0))
    styl = STYLES[style]
    rng = random.Random(seed)
    for it in g.items:
        if it[0] == "glow":
            continue
        role = it[2]
        fill, outline = styl.get(role, STYLES["sketch"].get(role,
                                                            (None, INK)))
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        pts = [tuple(v * SS for v in P(x, y)) for x, y in it[1]]
        if it[0] == "poly":
            if fill:
                d.polygon(pts, fill=fill)
            if outline and style != "silhouette":
                for k in range(2 if wobble else 1):
                    jit = [(x + rng.uniform(-1.2, 1.2) * SS * 0.4 * k,
                            y + rng.uniform(-1.2, 1.2) * SS * 0.4 * k)
                           for x, y in pts]
                    d.line(jit + [jit[0]], fill=outline + (220 if k == 0
                                                           else 110,),
                           width=max(1, int(1.6 * SS * (1 if k == 0
                                                        else 0.6))),
                           joint="curve")
        else:
            width, dash = it[3], it[4]
            col = outline or (fill[:3] if fill else INK)
            if style == "silhouette":
                if role in ("speed",):
                    continue
                col = (20, 20, 22)
            w = max(1, int(width * scale * SS * 0.5))
            if dash:
                for (ax, ay), (bx, by) in zip(pts, pts[1:]):
                    n = max(1, int(math.hypot(bx - ax, by - ay) /
                                   (6 * SS)))
                    for i in range(0, n, 2):
                        d.line([(ax + (bx - ax) * i / n,
                                 ay + (by - ay) * i / n),
                                (ax + (bx - ax) * (i + 1) / n,
                                 ay + (by - ay) * (i + 1) / n)],
                               fill=col + (170,), width=max(1, SS))
            else:
                d.line(pts, fill=col + (235,), width=w, joint="curve")
        base = Image.alpha_composite(base, layer)
    if style != "silhouette":
        for it in g.items:
            if it[0] != "glow":
                continue
            (cx, cy), r, strength, colour = it[1], it[2], it[3], it[4]
            if style == "B":
                colour = (150, 255, 90)
            gl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            d = ImageDraw.Draw(gl)
            px, py = P(cx, cy)
            rr = r * scale * SS
            for k in range(10, 0, -1):
                a = int(255 * min(1.0, strength) * (1 - k / 10) ** 1.4)
                d.ellipse([px * SS - rr * k / 10, py * SS - rr * k / 10,
                           px * SS + rr * k / 10, py * SS + rr * k / 10],
                          fill=colour + (a,))
            gl = gl.filter(ImageFilter.GaussianBlur(rr * 0.15))
            base = Image.alpha_composite(base, gl)
    img = base.resize((box_w, box_h), Image.LANCZOS)
    return img, P
