"""Tiling and comparison sheets for the Glyph concrete-wall trial.

    python3 make_sheets.py [dir]

A texture that looks right alone and shows a grid when tiled is not a wall
texture, so the tiled arrangement is evidence, not decoration. The shipped
`concrete_facility_wall.png` sits beside it at the same enlargement so the
comparison is of the house language and not of two different zoom levels.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(HERE))))
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
INK, DIM, BG = (232, 236, 240), (150, 158, 168), (18, 20, 24)


def font(px):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, px)
    return ImageFont.load_default()


def tiled(img, n, scale):
    w, h = img.size
    sheet = Image.new("RGB", (w * n, h * n))
    for ty in range(n):
        for tx in range(n):
            sheet.paste(img, (tx * w, ty * h))
    return sheet.resize((w * n * scale, h * n * scale), Image.NEAREST)


def main():
    glyph = Image.open(os.path.join(HERE, "concrete_facility_wall.png")).convert("RGB")
    shipped = Image.open(os.path.join(
        REPO, "assets/textures/theme/concrete_facility_wall.png")).convert("RGB")
    assert glyph.size == shipped.size == (128, 128), (glyph.size, shipped.size)

    # -- the tiling sheet: 3x3, at 2x, with the tile boundaries called out ---
    t = tiled(glyph, 3, 2)
    pad, head = 24, 116
    im = Image.new("RGB", (t.width + pad * 2, t.height + pad + head), BG)
    dr = ImageDraw.Draw(im)
    dr.text((pad, 18), "GLYPH TRIAL - concrete_facility wall, 3x3 tiled",
            font=font(24), fill=INK)
    dr.text((pad, 52), "native 128x128 = 4.00 m at 32 texels/m, shown at 2x.",
            font=font(17), fill=DIM)
    dr.text((pad, 76), "Red marks the tile boundaries: a seam would be a line "
            "that appears only there.", font=font(17), fill=DIM)
    im.paste(t, (pad, head))
    for i in (1, 2):
        x = pad + i * 128 * 2
        dr.line([(x, head), (x, head + t.height)], fill=(226, 84, 62), width=1)
        y = head + i * 128 * 2
        dr.line([(pad, y), (pad + t.width, y)], fill=(226, 84, 62), width=1)
    im.save(os.path.join(OUT, "TILED_3x3.png"))
    print("[sheet] TILED_3x3.png  %dx%d" % im.size)

    # -- glyph beside the shipped painter, same enlargement ----------------
    scale, gap = 4, 28
    a = glyph.resize((128 * scale,) * 2, Image.NEAREST)
    b = shipped.resize((128 * scale,) * 2, Image.NEAREST)
    im = Image.new("RGB", (pad * 2 + a.width * 2 + gap, 116 + a.height + pad + 40), BG)
    dr = ImageDraw.Draw(im)
    dr.text((pad, 18), "SAME WALL, TWO TOOLS - both 128x128 at 4x",
            font=font(24), fill=INK)
    dr.text((pad, 52), "Left: authored in Glyph by act_agent_arty for "
            "act_owner_skyiah. Right: the shipped", font=font(17), fill=DIM)
    dr.text((pad, 76), "tools/blender/materials.py painter, unchanged. "
            "Neither is a rebuild of the other.", font=font(17), fill=DIM)
    im.paste(a, (pad, 116))
    im.paste(b, (pad + a.width + gap, 116))
    for x, label in ((pad, "GLYPH - trial, ships nowhere"),
                     (pad + a.width + gap, "SHIPPED - unchanged")):
        dr.text((x, 116 + a.height + 10), label, font=font(20), fill=INK)
    im.save(os.path.join(OUT, "GLYPH_vs_SHIPPED.png"))
    print("[sheet] GLYPH_vs_SHIPPED.png  %dx%d" % im.size)

    # -- the two Godot renders, side by side -------------------------------
    # The caption is exact about the cameras on purpose. The two instances
    # stand 18 m apart, so these are MIRRORED positions with identical
    # offsets relative to each instance -- not one camera transform. A sheet
    # that overstates its own method teaches the reader to mistrust the next
    # number on it.
    ga = Image.open(os.path.join(HERE, "GODOT_wall_shipped.png")).convert("RGB")
    gb = Image.open(os.path.join(HERE, "GODOT_wall_glyph.png")).convert("RGB")
    ghead, gap2 = 148, 20
    im = Image.new("RGB", (pad * 2 + ga.width + gb.width + gap2,
                           ghead + ga.height + 52 + pad), BG)
    dr = ImageDraw.Draw(im)
    dr.text((pad, 18), "ON REAL GEOMETRY - shell_corner_left, per-surface "
            "override", font=font(28), fill=INK)
    for i, line in enumerate([
            "Two instances of the same shipped scene, themed "
            "concrete_facility. The ONLY difference is which PNG the `wall` "
            "role resolves to.",
            "Both 960x720, no stretching. The instances stand 18 m apart, so "
            "the cameras are at MIRRORED positions with identical offsets",
            "relative to each instance - eye height 1.7 m, 0.6 m inboard, in "
            "the corridor mouth - not one camera transform. Same light both "
            "sides.",
            "Nothing rebuilt, nothing exported; 0 unresolved surfaces either "
            "side."]):
        dr.text((pad, 56 + i * 23), line, font=font(17), fill=DIM)
    im.paste(ga, (pad, ghead))
    im.paste(gb, (pad + ga.width + gap2, ghead))
    dr.text((pad, ghead + ga.height + 12),
            "SHIPPED wall - materials.py, unchanged", font=font(22), fill=INK)
    dr.text((pad + ga.width + gap2, ghead + ga.height + 12),
            "GLYPH wall - the trial texture", font=font(22), fill=(150, 205, 160))
    im.save(os.path.join(OUT, "GODOT_comparison.png"))
    print("[sheet] GODOT_comparison.png  %dx%d" % im.size)


main()
