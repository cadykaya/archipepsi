#!/usr/bin/env python3
"""Tier 1 evidence sheets, drawn from the measurement folders.

    python3 tools/content/enemy_band_sheet.py grid <out.png> <title> \\
        <label>=<contrast dir> [<label>=<contrast dir> ...]
    python3 tools/content/enemy_band_sheet.py chart <out.png> <value_bands dir>

`grid`: six rooms down, the four cases across; in every cell each run's
cropped frame stacked with its separation, so TODAY and a candidate are
read in the same place. `chart`: separation against body lightness, one
panel per room, the four cases as lines, the 0.10 and 0.18 rules and the
zero line drawn in -- the shape of the problem in one picture: three
cases rise as the body darkens, and in four rooms the opening crosses
zero on the way.

Every number is read from the harness's contrast.json / the sweep; this
draws, it does not measure.
"""

import json
import os
import sys

from PIL import Image, ImageDraw

THEMES = ["concrete_facility", "rusted_industrial", "neon_transit",
          "gothic_stone", "temple_ruin", "void_glitch"]
CASES = ["wall", "floor", "dim", "opening"]
BG = (16, 20, 24)
INK = (224, 232, 238)
DIM_INK = (150, 158, 166)
SHORT = (236, 120, 96)
CELL_W = 420
LABEL_W = 150
HEAD = 64


def load(d):
    with open(os.path.join(d, "contrast.json"), encoding="utf-8") as fh:
        return json.load(fh)


def grid(out, title, runs):
    runs = [(label, d, load(d)) for label, d in runs]
    tiles = {}
    tile_h = 0
    for t in THEMES:
        for c in CASES:
            for label, d, _ in runs:
                im = Image.open(os.path.join(
                    d, "CONTRAST_%s_%s.png" % (t, c))).convert("RGB")
                h = round(im.height * CELL_W / im.width)
                tiles[(t, c, label)] = im.resize((CELL_W, h), Image.LANCZOS)
                tile_h = max(tile_h, h)
    line = 16
    block = (tile_h + line + 4) * len(runs) + 10
    W = LABEL_W + CELL_W * len(CASES) + 10 * (len(CASES) + 1)
    H = HEAD + block * len(THEMES) + 10
    sheet = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 10), title, fill=INK)
    draw.text((12, 28), "separation = |background L* - body L*|, CIE, "
              "at 18 m under each room's own light and fog. 0.10 is the "
              "palette's value rule, 0.18 its interactable rule.",
              fill=DIM_INK)
    for i, c in enumerate(CASES):
        draw.text((LABEL_W + 10 + i * (CELL_W + 10), HEAD - 18), c.upper(),
                  fill=INK)
    for r, t in enumerate(THEMES):
        y0 = HEAD + r * block
        draw.text((10, y0 + 6), t, fill=INK)
        for i, c in enumerate(CASES):
            x = LABEL_W + 10 + i * (CELL_W + 10)
            y = y0
            for label, d, data in runs:
                row = data[t][c]
                sep = row["separation"]
                mark = "clears 0.18" if row["clears_interactable"] else \
                    "clears 0.10" if row["clears_value"] else "SHORT"
                side = "" if not row["body_above_background"] else \
                    " (body LIGHTER)"
                draw.text((x, y), "%s  %.3f  %s%s" % (label, sep, mark, side),
                          fill=SHORT if mark == "SHORT" else INK)
                sheet.paste(tiles[(t, c, label)], (x, y + line))
                y += tile_h + line + 4
    sheet.save(out, optimize=True)
    print("[band-sheet] %s  %d x %d" % (out, W, H))


def chart(out, root):
    with open(os.path.join(root, "value_bands.json"), encoding="utf-8") as fh:
        bands = json.load(fh)
    grid_k = bands["grid"]
    sweep = {}
    for k in grid_k:
        with open(os.path.join(root, "sweep", "k%.2f.json" % k),
                  encoding="utf-8") as fh:
            sweep[k] = json.load(fh)
    with open(os.path.join(root, "sweep", "limit_black_matte.json"),
              encoding="utf-8") as fh:
        limit = json.load(fh)
    two = bands["partitions"]["2"]["by_theme"]
    PW, PH, PAD = 460, 300, 46
    cols, rows = 3, 2
    W = cols * PW + 20
    H = 70 + rows * PH + 30
    sheet = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 10), "Tier 1 -- separation from the background as the "
              "enemy body darkens (CIE L*, 18 m, each room's own light and "
              "fog)", fill=INK)
    draw.text((12, 28), "x: body ramp lightness k (1.00 = today) and LIMIT "
              "= pure black, matte. Above zero = body darker than what is "
              "behind it. Ring = the two-band candidate's step.",
              fill=DIM_INK)
    colour = {"wall": (120, 170, 230), "floor": (200, 170, 110),
              "dim": (170, 130, 200), "opening": (230, 230, 230)}
    lx = 12
    for c in CASES:
        draw.line([(lx, 52), (lx + 22, 52)], fill=colour[c], width=3)
        draw.text((lx + 28, 46), c, fill=colour[c])
        lx += 110
    xs = list(grid_k) + ["LIMIT"]
    lo, hi = -0.10, 0.35
    for n, t in enumerate(THEMES):
        ox = 10 + (n % cols) * PW
        oy = 70 + (n // cols) * PH
        x0, x1 = ox + PAD, ox + PW - 16
        y0, y1 = oy + 22, oy + PH - 30

        def X(i):
            return x0 + (x1 - x0) * i / (len(xs) - 1)

        def Y(v):
            return y1 - (y1 - y0) * (v - lo) / (hi - lo)
        draw.rectangle([x0, y0, x1, y1], outline=(60, 66, 72))
        draw.text((ox + PAD, oy + 4), t, fill=INK)
        for v, style in ((0.0, (110, 116, 122)), (0.10, (150, 150, 110)),
                         (0.18, (110, 150, 110))):
            yy = Y(v)
            for xx in range(int(x0), int(x1), 8 if v else 2):
                draw.line([(xx, yy), (min(xx + 4, x1), yy)], fill=style)
            draw.text((ox + 4, yy - 6), "%.2f" % v, fill=style)
        for i, k in enumerate(xs):
            draw.text((X(i) - 12, y1 + 6),
                      "%.2f" % k if k != "LIMIT" else "LIM", fill=DIM_INK)
        for c in CASES:
            pts = []
            for i, k in enumerate(xs):
                run = limit if k == "LIMIT" else sweep[k]
                row = run[t][c]
                pts.append((X(i), Y(row["background_lstar"]
                                   - row["body_lstar"])))
            draw.line(pts, fill=colour[c], width=2)
            for p in pts:
                draw.ellipse([p[0] - 2, p[1] - 2, p[0] + 2, p[1] + 2],
                             fill=colour[c])
        k = two[t]
        i = xs.index(k)
        for c in CASES:
            row = sweep[k][t][c]
            p = (X(i), Y(row["background_lstar"] - row["body_lstar"]))
            draw.ellipse([p[0] - 6, p[1] - 6, p[0] + 6, p[1] + 6],
                         outline=INK, width=2)
    sheet.save(out, optimize=True)
    print("[band-sheet] %s  %d x %d" % (out, W, H))


def main():
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    mode, out = sys.argv[1], sys.argv[2]
    if mode == "grid":
        runs = []
        for arg in sys.argv[4:]:
            label, _, d = arg.partition("=")
            runs.append((label, d))
        grid(out, sys.argv[3], runs)
    elif mode == "chart":
        chart(out, sys.argv[3])
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
