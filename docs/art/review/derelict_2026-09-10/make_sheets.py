"""Sheets for Batch 042, deep_space_derelict.

    python3 make_sheets.py [dir]

Four boards: the theme comparison, the material hierarchy close-up, the
tiling board, and the value study.

GRAYSCALE METHOD. Godot renders are reduced with the same CIE L* the Glyph
`study({value:true})` uses, so the two halves of the batch answer the value
question the same way. A channel average would flatter blues and punish
yellows, which is exactly the confound a value study exists to remove.
"""
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
INK, DIM, OK, BG, PANEL = ((232, 236, 240), (150, 158, 168), (150, 205, 160),
                           (16, 18, 22), (28, 31, 36))


def font(px, bold=True):
    p = ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else
         "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    return ImageFont.truetype(p, px) if os.path.exists(p) else ImageFont.load_default()


def head(dr, title, lines, pad=24):
    dr.text((pad, 18), title, font=font(28), fill=INK)
    for i, s in enumerate(lines):
        dr.text((pad, 56 + i * 23), s, font=font(17), fill=DIM)
    return 56 + len(lines) * 23 + 18


def to_value(im):
    """CIE L*, the same reduction easel.study({value:true}) applies."""
    im = im.convert("RGB")
    px = im.load()
    out = Image.new("RGB", im.size)
    o = out.load()

    def lin(c):
        v = c / 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y]
            Y = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
            L = 116 * (Y ** (1 / 3)) - 16 if Y > 0.008856 else 903.3 * Y
            v = max(0, min(255, round(L / 100 * 255)))
            o[x, y] = (v, v, v)
    return out


def row_board(name, shot, captions, title, lines, value=False):
    imgs = [Image.open(os.path.join(HERE, "GODOT_%s_%s.png" % (shot, k)))
            for k, _ in captions]
    if value:
        imgs = [to_value(i) for i in imgs]
    PAD, GAP = 24, 16
    w, h = imgs[0].size
    W = PAD * 2 + w * len(imgs) + GAP * (len(imgs) - 1)
    im = Image.new("RGB", (W, 150 + h + 46 + PAD), BG)
    dr = ImageDraw.Draw(im)
    y0 = head(dr, title, lines)
    for i, (img, (_, cap)) in enumerate(zip(imgs, captions)):
        x = PAD + i * (w + GAP)
        im.paste(img, (x, y0))
        dr.text((x, y0 + h + 10), cap, font=font(19),
                fill=OK if i > 0 else INK)
    im.save(os.path.join(OUT, name))
    print("[sheet] %s  %dx%d" % (name, *im.size))


def tiling_board():
    rec = json.load(open(os.path.join(HERE, "derelict_fields.json")))
    PAD, GAP, CELL = 24, 18, 384
    cols = 2
    rows = (len(rec["fields"]) + cols - 1) // cols
    W = PAD * 2 + CELL * cols + GAP * (cols - 1)
    im = Image.new("RGB", (W, 160 + rows * (CELL + 74) + PAD), BG)
    dr = ImageDraw.Draw(im)
    y0 = head(dr, "TILING - every repeating field, 3x3", [
        "Each is its native tile laid nine times. A field that carries a "
        "singular event shows it here as a grid; none of these does.",
        "Derived studies, not renders: each names the verified view it was "
        "composed from and reports is_a_render: false.",
    ])
    for i, f in enumerate(rec["fields"]):
        cx = PAD + (i % cols) * (CELL + GAP)
        cy = y0 + (i // cols) * (CELL + 74)
        src = Image.open(os.path.join(HERE, f["images"]["tiled"])).convert("RGB")
        im.paste(src.resize((CELL, int(CELL * src.height / src.width)),
                            Image.NEAREST), (cx, cy))
        hh = int(CELL * src.height / src.width)
        dr.text((cx, cy + hh + 8), "%s  -  %s" % (f["id"], f["title"]),
                font=font(19), fill=INK)
        dr.text((cx, cy + hh + 32), "%.2f x %.2f m at %d texels/m, %d entries"
                % (*f["metres"], f["texels_per_metre"], f["palette_entries"]),
                font=font(16), fill=OK)
    im.save(os.path.join(OUT, "TILING_3x3.png"))
    print("[sheet] TILING_3x3.png  %dx%d" % im.size)


row_board("THEME_COMPARISON.png", "wide",
          [("concrete", "concrete_facility - the approved baseline"),
           ("derelict", "deep_space_derelict - clean"),
           ("dressed", "deep_space_derelict - dressed, 6 cards")],
          "ONE ROOM, TWO THEMES - shell_corner_left, per-surface overrides",
          ["Three instances of the SAME approved scene. Nothing rebuilt, "
           "nothing exported, no manifest or review state touched.",
           "IDENTICAL LIGHT on all three, so any difference is the art and "
           "not the lamp. 960x720, no stretching.",
           "The theme's own proposed lamp is a separate board; a theme that "
           "only works under its own lighting has not been proved."])

row_board("MATERIAL_HIERARCHY.png", "hierarchy",
          [("concrete", "concrete_facility"),
           ("derelict", "deep_space_derelict"),
           ("dressed", "dressed")],
          "MATERIAL HIERARCHY - wall, floor and structural trim, close",
          ["Same camera relative to each instance, same light. The point is "
           "the ORDER of the values, not the colours.",
           "concrete: bright field, mid trim. derelict: near-black frame "
           "(L9-26), floor between (L16-42), and the wall field still",
           "the palest large surface (L48) - dark structure establishes the "
           "room, the pale field keeps it navigable."])

row_board("THEME_LIGHT.png", "wide",
          [("dressed", "under the SHARED lamp - proving the art differs"),
           ("dressed_themelight", "under the theme's PROPOSED lamp - what it is for")],
          "THE LIGHT IS A PROPOSAL, NOT THE PROOF",
          ["Left is the same image as the comparison board: the theme "
           "differs from concrete under concrete's own light.",
           "Right applies derelict_palette.json's `light_colour` proposal "
           "(#b9cfd6, dim) - bound into no runtime and changing no",
           "Constants. A station whose lighting is failing is mostly unlit, "
           "which is also what makes the accent indicators worth having."])

row_board("VALUE_STUDY.png", "wide",
          [("concrete", "concrete_facility, value only"),
           ("derelict", "deep_space_derelict, value only"),
           ("dressed", "dressed, value only")],
          "VALUE ONLY - does the dark theme still navigate",
          ["Reduced to CIE L*, the same reduction Glyph's study({value:true}) "
           "applies to the flat fields. Hue removed entirely.",
           "What has to survive: the doorway, the floor plane, the wall/floor "
           "boundary, and the trim line that says where the room ends.",
           "If the theme were a darkened concrete the two left panels would "
           "be the same picture. They are not."], value=True)

tiling_board()
