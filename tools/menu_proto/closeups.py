#!/usr/bin/env python3
"""Track A2 -- the close-up evidence for the fifth ruling's two refinements.

    python3 tools/menu_proto/closeups.py <before dir> <after dir> <out dir>

<before dir> holds the approved hybrid checkpoint's stills (H_1, H_4, H_5, at
1280 x 720); <after dir> holds the interactive build's stills from the
closeup_* tapes (stills.sh, 1280 x 720). Every crop is at 1:1 -- the
refinements are about what reads at 1280 x 720, so nothing is enlarged.

  fix_1_settings_feed.png  Epsilon's feed and terminal, before and after.
  fix_2_readability.png    the comparison's and the Journal's quieter words,
                           before and after, with the colours and their
                           measured contrast against what is behind them.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

BG = "#0b0d10"
INK = "#e8eef6"
DIM = "#9ba5b6"
MARK = "#ffd84d"


def lum(c):
    def ch(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])


def contrast(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def behind(img, box):
    """The colour behind the words: the median of a patch with none."""
    patch = img.crop(box).convert("RGB")
    px = sorted((patch.getpixel((x, y)) for y in range(patch.height)
                 for x in range(patch.width)), key=lum)
    return px[len(px) // 2]


def panel(pairs, title, notes, out):
    """Rows of (label, before crop, after crop), side by side, 1:1."""
    big = ImageFont.load_default(size=18)
    small = ImageFont.load_default(size=15)
    pad = 16
    w = max(max(b.width + a.width for _, b, a in pairs) + pad * 3, 900)
    h = 70 + sum(max(b.height, a.height) + 70 for _, b, a in pairs) + 24 * len(notes) + 24
    sheet = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 12), title, fill=MARK, font=big)
    d.text((pad, 38), "1:1 PIXELS AT 1280 x 720 -- NOTHING ENLARGED", fill=DIM, font=small)
    y = 70
    for label, b, a in pairs:
        d.text((pad, y), label, fill=INK, font=small)
        y += 24
        d.text((pad, y), "BEFORE: the approved checkpoint (a still)", fill=DIM, font=small)
        d.text((pad * 2 + b.width, y), "AFTER: the interactive build", fill=MARK, font=small)
        y += 22
        sheet.paste(b, (pad, y))
        sheet.paste(a, (pad * 2 + b.width, y))
        d.rectangle([pad - 1, y - 1, pad + b.width, y + b.height], outline="#3a3f47")
        d.rectangle([pad * 2 + b.width - 1, y - 1, pad * 2 + b.width + a.width,
                     y + a.height], outline=MARK)
        y += max(b.height, a.height) + 24
    for line in notes:
        d.text((pad, y), line, fill=INK, font=small)
        y += 24
    sheet.save(out, optimize=True)
    print("closeups: %s (%d x %d)" % (out, sheet.width, sheet.height))


def main():
    before, after, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    B = lambda n: Image.open(os.path.join(before, n)).convert("RGB")
    A = lambda n: Image.open(os.path.join(after, n)).convert("RGB")
    # ---- fix 1: the feed below Epsilon, and the value it sat on
    box = (820, 88, 1200, 640)
    panel([("SETTINGS, EPSILON AND THE OPTIONS' VALUES", B("H_5_settings.png").crop(box),
            A("closeup_settings.png").crop(box))],
          "FIX 1 -- EPSILON'S FEED NO LONGER SITS ON A VALUE",
          ["Before: the drop through Epsilon ended in a terminal on the MOUSE SENSITIVITY "
           "window, so '100%' could read as his.",
           "After: his feed runs down the board's empty margin into a terminal in the board's "
           "empty foot. It crosses no value and no control;",
           "test_hybrid checks that on the layout itself (settings.feed_clear), before and "
           "after the values change."],
          os.path.join(out, "fix_1_settings_feed.png"))
    # ---- fix 2: the quieter words, lifted
    cb = (640, 150, 1160, 330)
    jb = (130, 285, 1120, 560)
    eq_b, eq_a = B("H_1_equipment_normal.png"), A("closeup_compare.png")
    jn_b, jn_a = B("H_4_journal.png"), A("closeup_journal.png")
    wall_b = behind(jn_b, (560, 600, 575, 640))
    wall_a = behind(jn_a, (560, 600, 575, 640))
    win_b = behind(eq_b, (1080, 290, 1140, 320))
    win_a = behind(eq_a, (1080, 290, 1140, 320))
    rows = [
        ("comparison labels (KIND, DAMAGE ...)", "#7b766b", "#978f80", win_b, win_a),
        ("comparison old values, key words", "#aaa495", "#c4bdad", win_b, win_a),
        ("history line (MK I <- ...)", "#7b766b", "#978f80", win_b, win_a),
        ("Journal entries (not focused)", "#9da3a8", "#b9bec2", wall_b, wall_a),
        ("Journal notes", "#9da3a8", "#aeb3b8", wall_b, wall_a),
    ]
    notes = ["The lift, colour by colour, with its contrast against what is measured behind "
             "it on screen:"]
    for name, cb_, ca_, gb, ga in rows:
        notes.append("    %s:  %s  %.1f:1   ->   %s  %.1f:1" % (
            name, cb_, contrast(hexrgb(cb_), gb), ca_, contrast(hexrgb(ca_), ga)))
    notes.append("The hierarchy holds: new values and names stay the brightest, then old "
                 "values and descriptions, then labels and history.")
    notes.append("No size changed: nothing was shrunk to make room, and nothing was made "
                 "as loud as the rest.")
    panel([("EQUIPMENT'S COMPARISON", eq_b.crop(cb), eq_a.crop(cb)),
           ("THE JOURNAL'S ENTRIES", jn_b.crop(jb), jn_a.crop(jb))],
          "FIX 2 -- THE QUIETER WORDS, A STEP UP FOR 1280 x 720", notes,
          os.path.join(out, "fix_2_readability.png"))


if __name__ == "__main__":
    main()
