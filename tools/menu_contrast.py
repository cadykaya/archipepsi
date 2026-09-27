#!/usr/bin/env python3
"""MENU-INT: the menu's text contrast, measured on the game's own renders.

    python3 tools/menu_contrast.py <dir-of-renders> [...]

Every `*.png` a menu suite's shots mode writes has a `*.words.json` beside
it (`MenuShell.words_on_screen`): each word drawn on the front wall, its
rectangle on the screen and its ink. A word's glyphs are unshaded, so its
pixels are its ink; what is behind it is lit, so the only honest reading
of that is the render. For each word this takes, inside its rectangle:

- the text: the pixels within reach of the ink, averaged;
- the ground: the pixels well away from the ink, their median.

and reports the WCAG contrast ratio between the two -- per render, the
least, the median and every word under 4.5:1 and under 3:1. Nothing is
judged here: the numbers are for the report and the reviewer.
"""

from __future__ import annotations

import json
import statistics
import sys
from pathlib import Path

from PIL import Image

NEAR = 48.0      # a pixel this close to the ink is the ink
FAR = 96.0       # a pixel this far from it is the ground


def _lin(c: float) -> float:
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(rgb) -> float:
    r, g, b = rgb
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)


def ratio(a, b) -> float:
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def _dist(p, q) -> float:
    return ((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2) ** 0.5


def measure(png: Path) -> list[dict]:
    words = json.loads((png.parent / (png.stem + ".words.json")).read_text())
    image = Image.open(png).convert("RGB")
    w, h = image.size
    px = image.load()
    out = []
    for word in words:
        x, y, rw, rh = word["rect"]
        x0, y0 = max(0, int(x)), max(0, int(y))
        x1, y1 = min(w, int(x + rw) + 1), min(h, int(y + rh) + 1)
        if x1 - x0 < 2 or y1 - y0 < 2:
            continue
        ink = tuple(max(0.0, min(1.0, c)) * 255.0 for c in word["ink"])
        text, ground = [], []
        for yy in range(y0, y1):
            for xx in range(x0, x1):
                p = px[xx, yy]
                d = _dist(p, ink)
                if d <= NEAR:
                    text.append(p)
                elif d >= FAR:
                    ground.append(p)
        if len(text) < 3 or len(ground) < 3:
            continue
        mean = tuple(sum(p[i] for p in text) / len(text) for i in range(3))
        med = tuple(statistics.median(p[i] for p in ground) for i in range(3))
        out.append({"text": word["text"], "ratio": round(ratio(mean, med), 2)})
    return out


def main(dirs: list[str]) -> None:
    for d in dirs:
        for png in sorted(Path(d).glob("*.png")):
            if not (png.parent / (png.stem + ".words.json")).exists():
                continue
            rows = measure(png)
            if not rows:
                print(f"{png.name}: no words measured")
                continue
            ratios = [r["ratio"] for r in rows]
            under45 = [r for r in rows if r["ratio"] < 4.5]
            under3 = [r for r in rows if r["ratio"] < 3.0]
            print(f"{png.name}: {len(rows)} words, least {min(ratios):.2f}:1, "
                  f"median {statistics.median(ratios):.2f}:1, "
                  f"{len(under45)} under 4.5:1, {len(under3)} under 3:1")
            for r in sorted(under3, key=lambda r: r["ratio"])[:8]:
                print(f"    {r['ratio']:5.2f}:1  {r['text'][:60]}")


if __name__ == "__main__":
    main(sys.argv[1:] or ["."])
