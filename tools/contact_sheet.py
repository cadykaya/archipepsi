"""Stack rendered views into a phone-readable vertical sheet.

    python3 tools/contact_sheet.py <out.png> <caption> <view.png> ...

WHY VERTICAL. A 4-up grid on a phone is four thumbnails; a single column
at full device width is four pictures you can actually judge architecture
from. The sheet is 1200 px wide -- wider than any phone's CSS pixel
width, so it downsamples cleanly rather than being upscaled -- and each
view keeps its own 16:9, so the sheet is tall and scrolls, which is the
one gesture a phone is good at.

The captions rendered into each view by the shot runner survive, so a
sheet needs no second labelling pass.
"""

import sys
from PIL import Image, ImageDraw

WIDTH = 1200
GAP = 10
BAND = 54


def sheet(out, title, views):
    tiles = []
    for path in views:
        im = Image.open(path).convert("RGB")
        h = round(im.height * WIDTH / im.width)
        tiles.append(im.resize((WIDTH, h), Image.LANCZOS))
    total = BAND + sum(t.height for t in tiles) + GAP * len(tiles)
    canvas = Image.new("RGB", (WIDTH, total), (16, 20, 24))
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 18), title, fill=(224, 232, 238))
    y = BAND
    for t in tiles:
        canvas.paste(t, (0, y))
        y += t.height + GAP
    canvas.save(out, optimize=True)
    print("[sheet] %s  %d x %d  from %d view(s)"
          % (out, WIDTH, total, len(views)))


if __name__ == "__main__":
    sheet(sys.argv[1], sys.argv[2], sys.argv[3:])
