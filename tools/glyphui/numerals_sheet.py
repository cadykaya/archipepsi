#!/usr/bin/env python3
"""Track A -- the numerals, big enough to look at.

    python3 tools/glyphui/numerals_sheet.py [out dir]

`assets/ui/ui_numerals.png` is 72x8. It is the right size for the
engine and the wrong size for a person, so this draws the same pixels
magnified, one cell per character, with the advance each glyph declares
marked on it.

Nothing here is authored: the sheet is composed from the committed page
and the committed `.fnt`, so it cannot disagree with the font. If a
glyph changes, this changes with it or it does not build.
"""

import os
import re
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
UI = os.path.join(REPO, "assets", "ui")
ZOOM = 8
PAD = 10
INK = (232, 238, 246)
BACK = (24, 26, 29)
CELL_BG = (38, 41, 45)
PEN = (57, 215, 200)


def glyphs():
    """(char, x, y, w, h, advance) for every character in the .fnt."""
    text = open(os.path.join(UI, "ui_numerals.fnt"), encoding="utf-8").read()
    out = []
    for line in text.splitlines():
        if not line.startswith("char id="):
            continue
        f = dict(re.findall(r"(\w+)=(-?\d+)", line))
        out.append((chr(int(f["id"])), int(f["x"]), int(f["y"]),
                    int(f["width"]), int(f["height"]), int(f["xadvance"])))
    return sorted(out, key=lambda g: g[0])


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        REPO, "docs", "art", "review", "interface_2026-09-24")
    page = Image.open(os.path.join(UI, "ui_numerals.png")).convert("RGBA")
    cells = glyphs()
    if not cells:
        print("numerals-sheet: FAIL -- the .fnt declares no characters",
              file=sys.stderr)
        return 1

    cw = cells[0][3] * ZOOM
    ch = cells[0][4] * ZOOM
    cols = 6
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (PAD + cols * (cw + PAD),
                              PAD + rows * (ch + PAD + 14)), BACK)
    px = sheet.load()
    for i, (char, x, y, w, h, adv) in enumerate(cells):
        cx = PAD + (i % cols) * (cw + PAD)
        cy = PAD + (i // cols) * (ch + PAD + 14)
        sheet.paste(Image.new("RGB", (cw, ch), CELL_BG), (cx, cy))
        crop = page.crop((x, y, x + w, y + h))
        src = crop.load()
        for gy in range(h):
            for gx in range(w):
                if src[gx, gy][3] <= 127:
                    continue
                for dy in range(ZOOM):
                    for dx in range(ZOOM):
                        px[cx + gx * ZOOM + dx, cy + gy * ZOOM + dy] = INK
        # The pen's travel, drawn where it lands: everything left of
        # this line is this character's, and the next one starts on it.
        for dy in range(ch):
            sx = cx + adv * ZOOM
            if sx < sheet.size[0]:
                px[sx, cy + dy] = PEN
    path = os.path.join(out_dir, "SHEET_numerals.png")
    sheet.save(path)
    print("numerals-sheet: %d glyph(s) at %dx -> %s"
          % (len(cells), ZOOM, os.path.relpath(path, REPO)))
    print("  advances: %s" % ", ".join("%s=%d" % (c[0], c[5]) for c in cells))
    return 0


if __name__ == "__main__":
    sys.exit(main())
