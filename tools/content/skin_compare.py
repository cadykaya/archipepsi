"""Before/after on the prop skins, at the texture and in the room.

    python3 tools/content/skin_compare.py <out-dir>

The flat sheet is not the judgement -- the room is -- but it is where the
DIAGNOSIS lives, because it shows the feature frequencies the room only shows
the consequences of.
"""

from __future__ import annotations

import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def sheet(out, pairs, scale=3):
    tiles = []
    for before, after, label in pairs:
        b = Image.open(before).convert("RGB")
        a = Image.open(after).convert("RGB")
        tiles.append((b, a, label))
    w = tiles[0][0].width * scale
    sheet_img = Image.new("RGB", (w * 2 + 24, (w + 8) * len(tiles)),
                          (18, 20, 24))
    y = 0
    for b, a, _label in tiles:
        sheet_img.paste(b.resize((w, w), Image.NEAREST), (0, y))
        sheet_img.paste(a.resize((w, w), Image.NEAREST), (w + 24, y))
        y += w + 8
    sheet_img.save(out)
    return sheet_img.size


if __name__ == "__main__":
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    before_dir = sys.argv[2]
    names = sys.argv[3:]
    pairs = [(os.path.join(before_dir, "%s.png" % n),
              os.path.join(ROOT, "assets", "textures", "batch043",
                           "%s.png" % n), n) for n in names]
    print(sheet(os.path.join(out_dir, "SKIN_before_after.png"), pairs))
