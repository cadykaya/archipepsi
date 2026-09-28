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
          "VALUE ONLY - inspecting the value hierarchy and the boundaries",
          ["Reduced to CIE L*, the same reduction Glyph's study({value:true}) "
           "applies to the flat fields. This removes HUE, not brightness:",
           "a lighter and a darker version of one texture stay lighter and "
           "darker here. So it does NOT by itself prove more than a recolour.",
           "What it is for: checking that the trim still separates from the "
           "wall, and that the doorway, the floor plane and the wall/floor",
           "boundary still read. What establishes more than a recolour is the "
           "CHANGED PATTERNS - courses that became stringers, joints that",
           "became welds, a bolt line that moved to the stringers, and a deck "
           "that grew tread it did not have."], value=True)

tiling_board()


# =========================================================================
# BATCH 042 FOLLOW-UP
# =========================================================================
def lighting_board():
    rows = [("wide", "standing in the corridor mouth"),
            ("floor", "looking down the deck")]
    cols = [("1shared", "SHARED light - the material control, unchanged"),
            ("2theme", "proposed theme light - still broadly lit"),
            ("3study", "the lighting study - fixtures, falloff, recesses")]
    PAD, GAP = 24, 16
    first = Image.open(os.path.join(HERE, "LIT_wide_1shared.png"))
    w, h = first.size
    W = PAD * 2 + w * 3 + GAP * 2
    H = 196 + len(rows) * (h + 40) + PAD
    im = Image.new("RGB", (W, H), BG)
    dr = ImageDraw.Draw(im)
    y0 = head(dr, "LIGHTING STUDY - same camera, same materials, three lights", [
        "The materials, decals and dressing are IDENTICAL in all nine panels. "
        "Only the lights differ.",
        "The first preview lit this enclosed room with a DirectionalLight3D "
        "whose shadow_enabled defaulted to false, so it shone through the",
        "hull. A built Zone has no DirectionalLight3D at all - it uses "
        "ambient plus one OmniLight3D per fixture. The study drops the sun",
        "and lights the room the way the game can: placement and falloff. "
        "Static shots cannot show combat visibility or flicker.",
    ])
    for r, (shot, rcap) in enumerate(rows):
        yy = y0 + r * (h + 40)
        for c, (cond, ccap) in enumerate(cols):
            x = PAD + c * (w + GAP)
            im.paste(Image.open(os.path.join(HERE, "LIT_%s_%s.png" % (shot, cond))),
                     (x, yy))
            if r == 0:
                dr.text((x, yy - 26), ccap, font=font(18),
                        fill=OK if c == 2 else DIM)
        dr.text((PAD, yy + h + 8), rcap, font=font(17), fill=INK)
    im.save(os.path.join(OUT, "LIGHTING_STUDY.png"))
    print("[sheet] LIGHTING_STUDY.png  %dx%d" % im.size)


def uv_board():
    """The directional-material board, after the measurement was corrected.

    An earlier version of this function paired UV_ceiling_before/after and
    treated the ceiling as the interesting surface. It was not: the checker
    that pointed there had rotated the coordinates a second time, and once
    that was fixed the defect turned out to be on the X-facing WALL slabs.
    This pairs those, plus the trim, whose density had been measured with
    the wrong image height.
    """
    rows = [("UV_wall", "the WEST wall - an X-facing slab"),
            ("UV_trim", "the skirting, close")]
    PAD, GAP = 24, 16
    a = Image.open(os.path.join(HERE, "UV_wall_before.png"))
    w, h = a.size
    im = Image.new("RGB", (PAD * 2 + w * 2 + GAP,
                           214 + len(rows) * (h + 40) + PAD), BG)
    dr = ImageDraw.Draw(im)
    dr.text((PAD, 18),
            "DIRECTIONAL MATERIALS - corrected, per-surface material only",
            font=font(28), fill=INK)
    for i, line in enumerate([
            "MEASURED with the coordinate handling fixed. glTF is Y-UP by "
            "definition and Godot's frame is Y-up too, so the file's axes "
            "need no",
            "conversion; an earlier version of the checker rotated them a "
            "second time and every direction it reported was wrong.",
            "Four of eight wall slabs are X-thin (east/west). The box unwrap "
            "gives them V along +Z, so authored vertical stringers lie on "
            "their side -",
            "that is the sideways pattern. The four Z-thin slabs (around the "
            "doorway) get V along world up and were always correct.",
            "The trim strip is 128x32 spanning 4 m per UV unit: 32 texels/m "
            "on U but only 8 on V. uv1_scale.y = 4 matches them."]):
        dr.text((PAD, 56 + i * 23), line, font=font(17), fill=DIM)
    y0 = 214
    for r, (stem, cap) in enumerate(rows):
        yy = y0 + r * (h + 40)
        im.paste(Image.open(os.path.join(HERE, stem + "_before.png")), (PAD, yy))
        im.paste(Image.open(os.path.join(HERE, stem + "_after.png")),
                 (PAD + w + GAP, yy))
        if r == 0:
            dr.text((PAD, yy - 26),
                    "AS BOUND - stringers sideways, trim stretched 4x",
                    font=font(18), fill=DIM)
            dr.text((PAD + w + GAP, yy - 26),
                    "CORRECTED - rotation on 4 surfaces, uv1_scale.y on 8",
                    font=font(18), fill=OK)
        dr.text((PAD, yy + h + 8), cap, font=font(17), fill=INK)
    im.save(os.path.join(OUT, "UV_DIRECTION.png"))
    print("[sheet] UV_DIRECTION.png  %dx%d" % im.size)


def floor_board():
    """The deck tread, before and after, in the room.

    Two framings at standing height, because the failure this replaces was
    invisible in the texture and obvious on the floor: short marks broke up
    under minification and came back as confetti. A flat preview would have
    passed it again.
    """
    rows = [("FLOOR_stand", "standing, looking down the deck"),
            ("FLOOR_feet", "closer, near the player's own feet")]
    PAD, GAP = 24, 16
    a = Image.open(os.path.join(HERE, "FLOOR_stand_before.png"))
    w, h = a.size
    im = Image.new("RGB", (PAD * 2 + w * 2 + GAP,
                           214 + len(rows) * (h + 40) + PAD), BG)
    dr = ImageDraw.Draw(im)
    dr.text((PAD, 18), "DECK TREAD - redrawn as manufactured plate",
            font=font(28), fill=INK)
    for i, line in enumerate([
            "ONE texture changed. The corrected wall rotation, the trim "
            "rescale, the lighting rig and the decals are all held.",
            "BEFORE: a 2x1 bright block over a 2x1 dark one, staggered - a "
            "note head with a stem - spanning 26 L* against a field at L32.",
            "AFTER: continuous diagonal grooves, 0.25 m apart, clipped to "
            "their own plate, with the lay alternating plate to plate.",
            "Highlight and shadow now sit +-6 L* either side of the field "
            "instead of +10 / -16, so the deck supports the room.",
            "A middle version used SHORT diagonal bars. Flat and tiled they "
            "read fine; at 1.7 m they broke into dashes. Continuous lines "
            "survive minification, short marks do not."]):
        dr.text((PAD, 56 + i * 23), line, font=font(17), fill=DIM)
    y0 = 214
    for r, (stem, cap) in enumerate(rows):
        yy = y0 + r * (h + 40)
        im.paste(Image.open(os.path.join(HERE, stem + "_before.png")), (PAD, yy))
        im.paste(Image.open(os.path.join(HERE, stem + "_after.png")),
                 (PAD + w + GAP, yy))
        if r == 0:
            dr.text((PAD, yy - 26), "BEFORE - the jazz floor",
                    font=font(18), fill=DIM)
            dr.text((PAD + w + GAP, yy - 26),
                    "AFTER - continuous grooves, alternating lay",
                    font=font(18), fill=OK)
        dr.text((PAD, yy + h + 8), cap, font=font(17), fill=INK)
    im.save(os.path.join(OUT, "FLOOR_TREAD.png"))
    print("[sheet] FLOOR_TREAD.png  %dx%d" % im.size)


lighting_board()
uv_board()
floor_board()
