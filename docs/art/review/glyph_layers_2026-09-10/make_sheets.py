"""Sheets for the wall-layers and decal-kit batch.

    python3 make_sheets.py [dir]

Three sheets, all from real renders and derived studies, none stretched:
the decal contact sheet, the wall 3x3 tiling sheet, and the layer board that
shows field and skirting apart and together.
"""
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
INK, DIM, OK, BG, PANEL = ((232, 236, 240), (150, 158, 168), (150, 205, 160),
                           (18, 20, 24), (30, 33, 39))


def font(px, bold=True):
    p = ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else
         "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    return ImageFont.truetype(p, px) if os.path.exists(p) else ImageFont.load_default()


def wrap_text(text, width):
    """Greedy wrap. A caption that runs off its own sheet is not a caption."""
    out, line = [], ""
    for w in text.split():
        if line and len(line) + 1 + len(w) > width:
            out.append(line); line = w
        else:
            line = (line + " " + w).strip()
    if line:
        out.append(line)
    return out


def head(dr, title, lines, pad=24):
    dr.text((pad, 18), title, font=font(28), fill=INK)
    for i, s in enumerate(lines):
        dr.text((pad, 56 + i * 23), s, font=font(17), fill=DIM)
    return 56 + len(lines) * 23 + 18


def decal_sheet():
    kit = json.load(open(os.path.join(HERE, "decal_kit.json")))
    d = kit["decals"]
    # One row per decal: native at 4x, the 8x enlargement, and it on the wall.
    CELL, PAD, GAP = 232, 24, 18
    rowh = CELL + 66
    H = 150 + rowh * len(d) + PAD
    W = PAD * 2 + CELL * 3 + GAP * 2 + 430
    im = Image.new("RGB", (W, H), BG)
    dr = ImageDraw.Draw(im)
    y0 = head(dr, "DECAL KIT - six reusable marks, authored in Glyph", [
        "Transparent RGBA. Physical size is authoritative: a card is built "
        "from `metres`, never from the pixel size.",
        "Left: native, enlarged to fit the cell; the label gives the true "
        "native size. Middle: over a checker, so the alpha is visible.",
        "Right: over the wall field it is meant for. Nothing stretched; every "
        "enlargement is an integer multiple.",
    ])
    for i, e in enumerate(d):
        y = y0 + i * rowh
        dr.rectangle([PAD - 8, y - 8, W - PAD + 8, y + CELL + 46], fill=PANEL)
        nw, nh = e["native_size"]
        for j, key in enumerate(("native", "on_checker", "on_wall")):
            src = Image.open(os.path.join(HERE, e["images"][key])).convert("RGBA")
            k = max(1, min(CELL // src.width, CELL // src.height))
            img = src.resize((src.width * k, src.height * k), Image.NEAREST)
            cell = Image.new("RGB", (CELL, CELL), (24, 26, 31))
            cell.paste(img, ((CELL - img.width) // 2, (CELL - img.height) // 2),
                       img)
            im.paste(cell, (PAD + j * (CELL + GAP), y))
            dr.text((PAD + j * (CELL + GAP), y + CELL + 6),
                    ("native %dx%d at %dx" % (nw, nh, k * 1) if key == "native"
                     else "over a checker" if key == "on_checker"
                     else "on the wall field"), font=font(15), fill=DIM)
        tx = PAD + 3 * (CELL + GAP)
        dr.text((tx, y + 4), e["title"], font=font(21), fill=INK)
        dr.text((tx, y + 32), "%.2f x %.2f m   %d x %d texels at %d/m"
                % (*e["metres"], nw, nh, kit["texels_per_metre"]),
                font=font(15), fill=OK)
        dr.text((tx, y + 55), "surfaces: " + ", ".join(e["surfaces"]),
                font=font(16), fill=DIM)
        yy = y + 80
        for s in wrap_text("orientation: " + e["orientation"], 44):
            dr.text((tx, yy), s, font=font(16), fill=DIM)
            yy += 21
        yy += 8
        for s in wrap_text(e["why"], 50)[:3]:
            dr.text((tx, yy), s, font=font(15, False), fill=(120, 128, 138))
            yy += 20
    im.save(os.path.join(OUT, "DECAL_KIT.png"))
    print("[sheet] DECAL_KIT.png  %dx%d" % im.size)


def wall_sheet():
    t = Image.open(os.path.join(HERE, "wall_field_3x3_4x.png")).convert("RGB")
    t = t.resize((t.width // 2, t.height // 2), Image.NEAREST)   # 3x3 at 2x
    PAD = 24
    im = Image.new("RGB", (t.width + PAD * 2, t.height + 150 + PAD), BG)
    dr = ImageDraw.Draw(im)
    y0 = head(dr, "WALL FIELD - 3x3, tiling in both axes", [
        "native 128x128 = 4.00 x 4.00 m at 32 texels/m, shown at 2x. Red "
        "marks the tile boundaries.",
        "Courses at 1.0 m = 32 texels, which divides 128 exactly four times. "
        "At the shipped 1.2 m they did not, and",
        "the base course was hiding the mismatch. No skirting here: it is a "
        "separate texture, placed once at the floor.",
    ])
    im.paste(t, (PAD, y0))
    for i in (1, 2):
        x = PAD + i * 256
        dr.line([(x, y0), (x, y0 + t.height)], fill=(226, 84, 62))
        yy = y0 + i * 256
        dr.line([(PAD, yy), (PAD + t.width, yy)], fill=(226, 84, 62))
    # `_SHEET`, and the suffix is load-bearing: this sheet used to be
    # `WALL_FIELD_3x3.png`, one capital away from the `wall_field_3x3.png`
    # it is rendered from. A Windows checkout cannot hold both -- see
    # ART_LESSONS L-100 and `bridge/tests/test_case_collisions.py`.
    im.save(os.path.join(OUT, "WALL_FIELD_3x3_SHEET.png"))
    print("[sheet] WALL_FIELD_3x3_SHEET.png  %dx%d" % im.size)


def layer_board():
    f = Image.open(os.path.join(HERE, "wall_field.png")).convert("RGB")
    s = Image.open(os.path.join(HERE, "wall_skirt.png")).convert("RGB")
    K = 4
    fi = f.resize((f.width * K, f.height * K), Image.NEAREST)
    si = s.resize((s.width * K, s.height * K), Image.NEAREST)
    # Together: the field, with the skirting laid at its foot ONCE.
    tog = Image.new("RGB", (fi.width, fi.height), (0, 0, 0))
    tog.paste(fi, (0, 0))
    tog.paste(si, (0, fi.height - si.height))
    PAD, GAP = 24, 20
    W = PAD * 2 + fi.width * 2 + GAP
    im = Image.new("RGB", (W, 160 + fi.height + 46 + PAD), BG)
    dr = ImageDraw.Draw(im)
    y0 = head(dr, "THE TWO LAYERS - field and structural trim, apart", [
        "Left: the repeating field alone, 4.00 x 4.00 m, no skirting in it.",
        "Right: the same field with the 4.00 x 1.00 m skirting laid at its "
        "foot, ONCE. Both at 4x, nothing stretched.",
        "The skirting carries the wall's own 2.0 m joints, so trim and field "
        "agree about where the panels are.",
    ])
    im.paste(fi, (PAD, y0))
    im.paste(tog, (PAD + fi.width + GAP, y0))
    dr.text((PAD, y0 + fi.height + 10), "field only - tiles in both axes",
            font=font(20), fill=INK)
    dr.text((PAD + fi.width + GAP, y0 + fi.height + 10),
            "field + skirting at the floor junction", font=font(20), fill=OK)
    im.save(os.path.join(OUT, "WALL_LAYERS.png"))
    print("[sheet] WALL_LAYERS.png  %dx%d" % im.size)


def godot_sheet():
    """Clean beside dressed, four framings, matched camera and light.

    The pairs are the SAME camera geometry relative to each instance -- the
    two rooms stand 40 m apart, so these are translated cameras, not one
    transform, and saying so is cheaper than being caught not saying it.
    """
    names = [("wide", "the room, from the doorway"),
             ("close", "1.4 m from the drip"),
             ("oblique", "a grazing angle along the north wall"),
             ("floor", "down onto the floor marks")]
    a0 = Image.open(os.path.join(HERE, "GODOT_wide_clean.png"))
    PAD, GAP, VGAP = 24, 16, 54
    W = PAD * 2 + a0.width * 2 + GAP
    H = 150 + (a0.height + VGAP) * len(names) + PAD
    im = Image.new("RGB", (W, H), BG)
    dr = ImageDraw.Draw(im)
    y0 = head(dr, "CLEAN AND DRESSED - shell_corner_left, Godot 4.5 "
              "Compatibility", [
        "Left: the Glyph wall field bound to the `wall` role and the "
        "skirting to the `trim` role, nothing else. Right: the same, plus "
        "six decal cards.",
        "Surface-aligned QuadMesh, 6 mm off the surface, alpha-blended, "
        "depth-write off. The projected `Decal` node does nothing in this "
        "renderer.",
        "960x720, no stretching. Same light both sides; the cameras are "
        "translated copies, since the two rooms stand 40 m apart.",
    ])
    for i, (n, caption) in enumerate(names):
        y = y0 + i * (a0.height + VGAP)
        for j, kind in enumerate(("clean", "dressed")):
            img = Image.open(os.path.join(HERE, "GODOT_%s_%s.png" % (n, kind)))
            im.paste(img, (PAD + j * (a0.width + GAP), y))
        dr.text((PAD, y + a0.height + 8), "%s - clean" % caption,
                font=font(19), fill=INK)
        dr.text((PAD + a0.width + GAP, y + a0.height + 8),
                "%s - dressed" % caption, font=font(19), fill=OK)
    im.save(os.path.join(OUT, "GODOT_CLEAN_VS_DRESSED.png"))
    print("[sheet] GODOT_CLEAN_VS_DRESSED.png  %dx%d" % im.size)


decal_sheet()
wall_sheet()
layer_board()
godot_sheet()
