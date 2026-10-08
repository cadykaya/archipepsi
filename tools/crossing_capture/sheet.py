"""Contact sheets for the art lane's review captures (Arty, 2026-10-08).

    python3 tools/crossing_capture/sheet.py OUT.png COLS WIDTH "caption|a.png" ...

Each tile is scaled to WIDTH pixels wide and captioned underneath in
plain text. Reads only the images it is given.
"""

import sys

from PIL import Image, ImageDraw, ImageFont


def main(argv):
    out, cols, width = argv[0], int(argv[1]), int(argv[2])
    items = [a.split("|", 1) for a in argv[3:]]
    tiles = []
    for caption, path in items:
        image = Image.open(path).convert("RGB")
        height = round(image.height * width / image.width)
        tiles.append((caption, image.resize((width, height), Image.LANCZOS)))
    pad, band = 8, 26
    tile_h = max(t.height for _, t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (width + pad) + pad,
                              rows * (tile_h + band + pad) + pad), (24, 26, 30))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    for i, (caption, tile) in enumerate(tiles):
        x = pad + (i % cols) * (width + pad)
        y = pad + (i // cols) * (tile_h + band + pad)
        sheet.paste(tile, (x, y))
        draw.text((x + 2, y + tile_h + 4), caption, fill=(230, 232, 236),
                  font=font)
    sheet.save(out)
    print("[sheet] %s (%d tiles)" % (out, len(tiles)))


if __name__ == "__main__":
    main(sys.argv[1:])
