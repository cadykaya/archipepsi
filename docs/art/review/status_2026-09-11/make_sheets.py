"""Batch 043 review sheets. Regenerated from the exported PNGs, never drawn.

    python3 docs/art/review/status_2026-09-11/make_sheets.py

Every sheet below is composed from `png/` and `status_kit.json`. If a glyph
changes, re-run `author_status_kit.mjs` and then this, and the sheets follow.
Nothing here is hand-assembled and nothing here is the asset -- the
individual transparent PNGs are.
"""

import json
import os
import textwrap

from PIL import Image, ImageDraw, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = json.load(open(os.path.join(HERE, "status_kit.json")))
INK = (18, 20, 24)
LIT = (233, 238, 242)
DIMTEXT = (150, 158, 168)

#: The three grounds the brief names. Bright concrete, dark derelict, and a
#: mid grey that flatters nothing -- the value a marker is least visible
#: against, included because a sheet that only shows the flattering cases is
#: a sheet that has not been checked.
GROUNDS = [("bright concrete", (196, 193, 186)),
           ("dark derelict", (38, 42, 47)),
           ("mid grey -- the worst case", (112, 116, 120))]


def png(name):
    return Image.open(os.path.join(HERE, "png", "%s.png" % name)).convert("RGBA")


def label(draw, xy, text, fill=LIT):
    draw.text(xy, text, fill=fill)


def sheet_families():
    """The four family frames and the compound frame, large, with the rule
    each one carries."""
    cell, scale, pad = 32, 7, 26
    rows = KIT["frames"]
    w = pad * 2 + len(rows) * (cell * scale + pad)
    h = 120 + cell * scale
    im = Image.new("RGB", (w, h), INK)
    d = ImageDraw.Draw(im)
    label(d, (pad, 18), "FAMILY FRAMES -- shape carries the family, never "
                        "colour (Design 5 §33.7)")
    label(d, (pad, 36), "32 x 32 native. The 12 px clear radius is what lets "
                        "a 16 x 16 glyph sit inside without touching.",
          DIMTEXT)
    x = pad
    for f in rows:
        g = png(f["id"]).resize((cell * scale, cell * scale), Image.NEAREST)
        im.paste(g, (x, 66), g)
        label(d, (x, 72 + cell * scale), "%s" % f["family"])
        label(d, (x, 88 + cell * scale), "%s" % f["treatment"], DIMTEXT)
        x += cell * scale + pad
    im.save(os.path.join(HERE, "SHEET_frames.png"))


def sheet_markers(grey=False):
    """Every composed marker, 5x, on the three grounds.

    THE GRID IS DERIVED. It used to be `cols = 7, rows = 3`, which was
    exactly the 21 markers the kit had; the eleven added in Batch 052
    pasted straight past the band and eleven statuses vanished from the
    sheet without the sheet saying so. A review image that silently drops
    a third of what it claims to show is worse than no image.
    """
    cell, scale, gap = 32, 5, 10
    marks = KIT["markers"]
    cols = 8
    rows = -(-len(marks) // cols)
    bw = cols * (cell * scale + gap) + gap
    bh = rows * (cell * scale + gap) + gap
    order = ", ".join(m["id"].replace("marker_", "") for m in marks)
    lines = textwrap.wrap("reading order: " + order, width=bw // 6)
    head = 36 + 16 * len(lines)
    im = Image.new("RGB", (bw, head + len(GROUNDS) * (bh + 42)), INK)
    d = ImageDraw.Draw(im)
    statuses = sum(1 for g in KIT["glyphs"] if g.get("family") != "COMPOUND")
    label(d, (gap, 16), "THE %d STATUSES AND %d COMPOUNDS%s"
          % (statuses, len(marks) - statuses,
             " -- GRAYSCALE" if grey else ""))
    for i, line in enumerate(lines):
        label(d, (gap, 32 + 16 * i), line, DIMTEXT)
    y = head
    for name, colour in GROUNDS:
        band = Image.new("RGB", (bw, bh), colour)
        for n, m in enumerate(KIT["markers"]):
            g = png(m["id"]).resize((cell * scale, cell * scale),
                                    Image.NEAREST)
            band.paste(g, (gap + (n % cols) * (cell * scale + gap),
                           gap + (n // cols) * (cell * scale + gap)), g)
        if grey:
            band = ImageOps.grayscale(band).convert("RGB")
        im.paste(band, (0, y))
        label(d, (gap, y + bh + 12), name, DIMTEXT)
        y += bh + 42
    im.save(os.path.join(HERE,
            "SHEET_markers%s.png" % ("_grayscale" if grey else "")))


def sheet_native():
    """1:1. The only sheet that answers the question the brief actually
    asked -- whether these read at the size they are drawn."""
    marks = [m["id"] for m in KIT["markers"]]
    glyphs = [g["id"] for g in KIT["glyphs"]]
    step = 36
    w = len(marks) * step + 16
    im = Image.new("RGB", (w, 40 + len(GROUNDS) * 92), INK)
    d = ImageDraw.Draw(im)
    label(d, (8, 12), "NATIVE SIZE, 1:1 -- markers 32 px, reduced glyphs 16 px")
    y = 40
    for name, colour in GROUNDS:
        band = Image.new("RGB", (w, 76), colour)
        for n, m in enumerate(marks):
            g = png(m)
            band.paste(g, (8 + n * step, 6), g)
        for n, g_id in enumerate(glyphs):
            g = png(g_id)
            band.paste(g, (8 + n * step + 8, 48), g)
        im.paste(band, (0, y))
        label(d, (8, y + 78), name, DIMTEXT)
        y += 92
    im.save(os.path.join(HERE, "SHEET_native_size.png"))


def sheet_pairs():
    """The six pairs the brief named, side by side at 6x and at 1:1.

    A pair sheet is the only fair test of "these are different shapes": two
    glyphs judged one at a time always look distinct, and the confusion only
    appears when they are adjacent.
    """
    pairs = [("anchored", "rooted"), ("lightened", "updraft"),
             ("blinded", "confused"), ("conductive", "grounded"),
             ("brittle", "shatterpoint"), ("phased", "suspended")]
    scale, cell = 6, 32
    cw = cell * scale * 2 + 24
    im = Image.new("RGB", (34 + len(pairs) * (cw + 18), 300), INK)
    d = ImageDraw.Draw(im)
    label(d, (16, 14), "THE SIX PAIRS THAT MUST NOT BE CONFUSED -- different "
                       "SHAPES, not different colours")
    x = 20
    for a, b in pairs:
        for i, which in enumerate((a, b)):
            g = png("marker_%s" % which).resize((cell * scale, cell * scale),
                                                Image.NEAREST)
            im.paste(g, (x + i * (cell * scale + 24), 44), g)
            n = png("marker_%s" % which)
            im.paste(n, (x + i * (cell * scale + 24) + 80, 248), n)
        label(d, (x, 42 + cell * scale + 8), a)
        label(d, (x + cell * scale + 24, 42 + cell * scale + 8), b)
        x += cw + 18
    label(d, (20, 282), "bottom row is the same pair at 1:1", DIMTEXT)
    im.save(os.path.join(HERE, "SHEET_pairs.png"))


def sheet_components():
    """Duration, the player tick, and the compound hint -- the three reusable
    components, which are rules rather than 21 more assets."""
    im = Image.new("RGB", (1120, 420), INK)
    d = ImageDraw.Draw(im)
    label(d, (16, 14), "REUSABLE COMPONENTS")
    strip = png("deplete_kinetic")
    strip = strip.resize((strip.width * 3, strip.height * 3), Image.NEAREST)
    im.paste(strip, (16, 46), strip)
    label(d, (16, 52 + strip.height), "DURATION: the frame's own outer edge "
          "is the track. 100% to 12.5%, clockwise from 12 o'clock.", DIMTEXT)
    label(d, (16, 70 + strip.height), "No second ring exists, so there is "
          "nothing to keep aligned with the frame.", DIMTEXT)
    hint = png("hint_updraft_needs_burning")
    hint = hint.resize((hint.width * 4, hint.height * 4), Image.NEAREST)
    im.paste(hint, (16, 250), hint)
    label(d, (16 + hint.width + 30, 250), "COMPOUND HINT (§33.8)")
    label(d, (16 + hint.width + 30, 270),
          "the missing component, dimmed, beside what it would become",
          DIMTEXT)
    tick = png("example_slippery_38pct_player")
    tick = tick.resize((tick.width * 4, tick.height * 4), Image.NEAREST)
    im.paste(tick, (700, 250), tick)
    label(d, (700 + tick.width + 20, 250), "PLAYER TICK + 38% SPENT")
    label(d, (700 + tick.width + 20, 270),
          "the tick marks what you caused; its absence is information too",
          DIMTEXT)
    im.save(os.path.join(HERE, "SHEET_components.png"))


for fn in (sheet_families, sheet_native, sheet_pairs, sheet_components):
    fn()
sheet_markers(False)
sheet_markers(True)
print("sheets written")
