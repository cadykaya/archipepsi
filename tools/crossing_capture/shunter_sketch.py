"""The Shunter, explored as drawings. DISPOSABLE CONCEPT, not the enemy model.
(Arty, 2026-10-08.)

    python3 tools/crossing_capture/shunter_sketch.py OUT.png

From Dess's D-19 (`21cc00a4`), identity approved by the owner: a station
freight shunter whose routing the Crossing scrambled. Its shape has to
explain three things -- the freight work (a broad hinged plough that
butts crates into bays, four short piston legs for decks full of
thresholds), the charge (the plough DROPS 15-20 cm into a brace; the
plough's position is the state), and the recovery (the open rear frame,
whose power pack glows warm white while it is helpless).

Two rows, side view, inside the unchanged 1.90 x 1.05 m envelope (dashed):
  1. silhouettes, in black: the six states the fight is read by;
  2. livery and lamps on two of them: pale freight paint, a stencilled
     lane number, amber lamps working / red when committed, a red plough
     edge only when committed, the warm rear pack, and the Crossing's
     scramble as Bloom veins through the frame.
Colour rules from D-19: red is the enemy cue; no orange (breakable), no
green (the dock's), no yellow-and-black (hazard) on its body.
Drawn by hand-placed polygons: an authored sketch, not AI output.
"""

import math
import sys

from PIL import Image, ImageDraw, ImageFont

PX = 150
ENV = (1.90, 1.05)
INK = (22, 21, 26)
INK_FAR = (92, 92, 104)
PALE = (214, 216, 208)
STEEL = (120, 126, 132)
DARK = (48, 50, 56)
AMBER = (255, 176, 64)
RED = (235, 40, 36)
WARM = (255, 236, 200)
BLOOM = (255, 63, 191)


def pose(name):
    """Return the shapes for a state: a dict of parameters."""
    p = {"drop": 0.0, "body_dy": 0.0, "tilt": 0.0, "legs": "stand",
         "lamp": "amber", "pack": 0.15, "edge": False, "dx": 0.0}
    if name == "docked":
        p.update(body_dy=-0.10, drop=0.18, legs="fold", lamp="dim", pack=0.05)
    if name == "brace":
        p.update(drop=0.18, body_dy=-0.07, tilt=-3, legs="splay", lamp="red",
                 edge=True)
    if name == "rush":
        p.update(drop=0.16, body_dy=-0.03, tilt=-2, legs="gallop",
                 lamp="red", edge=True, dx=0.04)
    if name == "recover":
        p.update(drop=0.0, body_dy=-0.04, tilt=5, legs="buckle", lamp="dim",
                 pack=1.0)
    if name == "dead":
        p.update(drop=0.20, body_dy=-0.16, tilt=-4, legs="fold", lamp="off",
                 pack=0.0)
    return p


def build(p):
    """Polygons in metres: x forward, y up; centre of rotation mid-body."""
    out = []
    cx, cy = 0.95, 0.55 + p["body_dy"]
    ang = math.radians(p["tilt"])

    def T(x, y):
        x0, y0 = x - 0.95, y - 0.55
        return (cx + x0 * math.cos(ang) - y0 * math.sin(ang) + p["dx"],
                cy + x0 * math.sin(ang) + y0 * math.cos(ang))

    # Far legs first (behind), then hull, then near legs.
    def legs(colour, offset):
        feet = {"stand": [(0.40, 0.0), (1.32, 0.0)],
                "fold": [(0.52, 0.06), (1.20, 0.06)],
                "splay": [(0.20, 0.0), (1.52, 0.0)],
                "gallop": [(0.02, 0.06), (1.70, 0.0)],
                "buckle": [(0.30, 0.0), (1.42, 0.0)]}[p["legs"]]
        for (hip_x, (fx, fy)) in zip((0.42, 1.30), feet):
            hx, hy = T(hip_x + offset, 0.36)
            fx += p["dx"] + offset
            knee = ((hx + fx) / 2.0 + (-0.10 if hip_x < 1 else 0.10),
                    (hy + fy) / 2.0 + 0.10)
            out.append(("line", [(hx, hy), knee], colour, 10))
            out.append(("line", [knee, (fx, fy + 0.03)], colour, 7))
            out.append(("poly", [(fx - 0.07, fy), (fx + 0.07, fy),
                                 (fx + 0.05, fy + 0.05),
                                 (fx - 0.05, fy + 0.05)], colour))
    legs(INK_FAR, 0.05)
    # The hull: a long low deck, a raised spine, the open rear frame.
    hull = [(0.30, 0.34), (1.50, 0.34), (1.56, 0.62), (1.40, 0.86),
            (0.62, 0.90), (0.44, 0.80), (0.30, 0.80)]
    out.append(("hull", [T(*v) for v in hull], None))
    spine = [(0.64, 0.86), (1.24, 0.86), (1.16, 0.98), (0.72, 0.98)]
    out.append(("spine", [T(*v) for v in spine], None))
    # The rear frame: bars round an open bay, the power pack inside.
    for a, b in (((0.04, 0.34), (0.30, 0.34)), ((0.04, 0.80), (0.30, 0.80)),
                 ((0.04, 0.34), (0.04, 0.80)), ((0.17, 0.34), (0.17, 0.80))):
        out.append(("bar", [T(*a), T(*b)], None))
    out.append(("pack", [T(0.08, 0.42), T(0.27, 0.42), T(0.27, 0.70),
                         T(0.08, 0.70)], p["pack"]))
    # The plough: hinged at the front top, a broad face down to the deck.
    piv = T(1.46, 0.84)
    edge_y = 0.20 - p["drop"]
    tip = T(1.90, max(edge_y, 0.02))
    plough = [piv, T(1.62, 0.86), (tip[0] + 0.02, tip[1] + 0.06), tip,
              T(1.62, 0.30 - p["drop"] * 0.6)]
    out.append(("plough", plough, None))
    if p["edge"]:
        out.append(("edge", [tip, (tip[0] + 0.02, tip[1] + 0.06)], RED))
    lamps = {"amber": AMBER, "red": RED, "dim": (110, 90, 60),
             "off": (40, 40, 44)}[p["lamp"]]
    for k in range(3):
        out.append(("lamp", T(1.50 + 0.06 * k, 0.44 - p["drop"] * 0.5),
                    lamps))
    legs(INK, -0.05)
    return out


STATES = [("TEND / PATROL", "plough up, lamps amber:\nworking, not hunting", "work"),
          ("DOCKED", "settled at its socket, plough\non the deck: the ambush", "docked"),
          ("BRACE 0.7 s", "PLOUGH DROPS 18 cm, legs splay,\nlamps red: move now", "brace"),
          ("RUSH 1.1 s", "plough down, gallop:\nstraight, cannot turn", "rush"),
          ("RECOVER 1.4 s", "plough up, rear pack white-hot:\npunish the rear", "recover"),
          ("POWER DOWN", "plough drops, lamps fade", "dead")]


def draw(d, shapes, ox, oy, colour_mode):
    def P(x, y):
        return (ox + int(x * PX), oy - int(y * PX))
    for item in shapes:
        kind, data, extra = item[0], item[1], item[2]
        if kind == "line":
            far = extra == INK_FAR
            colour = ((STEEL if far else DARK) if colour_mode else extra)
            d.line([P(*data[0]), P(*data[1])], fill=colour, width=item[3])
        elif kind == "poly":
            d.polygon([P(*v) for v in data],
                      fill=(DARK if colour_mode else extra))
        elif kind in ("hull", "spine"):
            d.polygon([P(*v) for v in data],
                      fill=(PALE if colour_mode else INK))
        elif kind == "bar":
            d.line([P(*data[0]), P(*data[1])],
                   fill=(STEEL if colour_mode else INK), width=7)
        elif kind == "pack":
            if colour_mode:
                t = extra
                fill = tuple(int(DARK[i] + (WARM[i] - DARK[i]) * t)
                             for i in range(3))
                d.polygon([P(*v) for v in data], fill=fill)
        elif kind == "plough":
            d.polygon([P(*v) for v in data],
                      fill=(STEEL if colour_mode else INK))
        elif kind == "edge" and colour_mode:
            d.line([P(*data[0]), P(*data[1])], fill=extra, width=6)
        elif kind == "lamp" and colour_mode:
            x, y = P(*data)
            d.ellipse([x - 5, y - 4, x + 5, y + 4], fill=extra)


def main(out):
    cw = int(2.25 * PX)
    ch = int(1.35 * PX)
    sheet = Image.new("RGB", (cw * 6 + 40, 2 * (ch + 92) + 120),
                      (236, 236, 232))
    d = ImageDraw.Draw(sheet)
    try:
        title = ImageFont.truetype("DejaVuSans-Bold.ttf", 21)
        font = ImageFont.truetype("DejaVuSans.ttf", 14)
    except OSError:
        title = font = ImageFont.load_default()
    d.text((20, 12), "SHUNTER (D-19) -- DISPOSABLE CONCEPT SKETCH, not the "
           "enemy model. Side view in the 1.90 x 1.05 m envelope (dashed).",
           fill=INK, font=title)
    d.text((20, 42), "The plough's height is the state. The open rear is the "
           "weak point. Authored polygons, not AI output.", fill=(70, 70, 76),
           font=font)
    for row, colour_mode in enumerate((False, True)):
        for i, (name, note, key) in enumerate(STATES):
            ox = 20 + i * cw
            oy = 90 + row * (ch + 92) + int(1.12 * PX)

            def P(x, y):
                return (ox + int(x * PX), oy - int(y * PX))
            x0, y0 = P(0, 0)
            x1, y1 = P(*ENV)
            for x in range(x0, x1, 10):
                d.line([(x, y0), (x + 5, y0)], fill=(150, 150, 160))
                d.line([(x, y1), (x + 5, y1)], fill=(150, 150, 160))
            for y in range(y1, y0, 10):
                d.line([(x0, y), (x0, y + 5)], fill=(150, 150, 160))
                d.line([(x1, y), (x1, y + 5)], fill=(150, 150, 160))
            d.line([P(-0.05, 0), P(2.05, 0)], fill=(120, 120, 128), width=2)
            draw(d, build(pose(key)), ox, oy, colour_mode)
            if colour_mode and key in ("work", "rush"):
                # Station identity: a lane number on the flank.
                d.text(P(0.70, 0.66), "LANE 07", fill=(60, 64, 70),
                       font=font)
            if colour_mode and key in ("brace", "recover"):
                # The Crossing's scramble: Bloom veins through the frame.
                for a, b in (((0.48, 0.52), (0.92, 0.52)),
                             ((0.92, 0.52), (0.92, 0.80)),
                             ((0.92, 0.66), (1.24, 0.66))):
                    d.line([P(*a), P(*b)], fill=BLOOM, width=4)
            if row == 0:
                d.text((ox + 4, oy + 10), name, fill=INK, font=title)
                d.multiline_text((ox + 4, oy + 38), note, fill=(60, 60, 66),
                                 font=font)
            else:
                d.text((ox + 4, oy + 10), name.lower() + ": livery",
                       fill=(60, 60, 66), font=font)
    d.text((20, sheet.height - 26), "Colour (row 2): pale freight livery; "
           "amber lamps working, RED when committed (lamps + plough edge); "
           "warm-white rear pack = vulnerable; magenta = the Crossing's "
           "scramble. No orange, green or yellow-black on the body.",
           fill=(60, 60, 66), font=font)
    sheet.save(out)
    print("[shunter] %s" % out)


if __name__ == "__main__":
    main(sys.argv[1])
