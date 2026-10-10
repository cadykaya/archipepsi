"""Six themes on one phone-readable sheet, from real captures.

    python3 tools/shots/make_theme_contact_sheet.py <raw_dir> <out_dir>

A BASELINE, NOT A DESIGN. Every tile is a capture the shot runner already
made through the game's own camera; this only lays them out and prints,
under each one, the numbers the capture was made from. Nothing here
recolours, retouches or simulates a binder that does not exist -- if a
theme looks flat in the sheet, it looks flat in the engine.

Two sheets, because they answer different questions:

  colour      what each theme looks like now
  greyscale   whether its VALUE structure reads, which is what survives a
              retheme and what a migration has to preserve

One column on a phone is unreadable at six rows tall and illegible at
three columns wide, so the tiles are stacked two across with the label
block under each -- roughly a phone screen per pair.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))

THEMES = ("concrete_facility", "rusted_industrial", "neon_transit",
          "gothic_stone", "temple_ruin", "void_glitch")

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

TILE_W = 760
COLS = 2
PAD = 26
INK = (232, 234, 238)
DIM = (150, 155, 165)
BG = (18, 19, 23)


def _font(path, size):
    return ImageFont.truetype(path, size)


def specs():
    """`THEME_MATERIALS`, read from Production's own constants."""
    import engine_truth
    return {n: dict(v) for n, v in engine_truth.constants()
            .THEME_MATERIALS.items()}


def swatch(draw, x, y, size, hex_value):
    draw.rectangle([x, y, x + size, y + size],
                   fill=hex_value, outline=(70, 74, 82))


def sheet(raw, kind, out, spec, head, note):
    tiles = []
    for theme in THEMES:
        path = os.path.join(raw, "_raw_%s" % theme,
                            "H_probe_%s_%s.png" % (theme, kind))
        if not os.path.exists(path):
            raise SystemExit("missing capture: %s" % path)
        tiles.append((theme, Image.open(path).convert("RGB")))

    tw = TILE_W
    th = int(tiles[0][1].height * tw / float(tiles[0][1].width))
    label_h = 132
    rows = (len(tiles) + COLS - 1) // COLS
    head_h = 184
    W = COLS * tw + (COLS + 1) * PAD
    H = head_h + rows * (th + label_h + PAD) + PAD

    sheet_im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet_im)
    f_title = _font(FONT_B, 40)
    f_note = _font(FONT, 21)
    f_name = _font(FONT_B, 30)
    f_mono = _font(MONO, 19)

    d.text((PAD, 26), head, font=f_title, fill=INK)
    for i, line in enumerate(note):
        d.text((PAD, 80 + i * 27), line, font=f_note, fill=DIM)

    for i, (theme, im) in enumerate(tiles):
        col, row = i % COLS, i // COLS
        x = PAD + col * (tw + PAD)
        y = head_h + row * (th + label_h + PAD)
        sheet_im.paste(im.resize((tw, th), Image.LANCZOS), (x, y))
        d.rectangle([x, y, x + tw - 1, y + th - 1], outline=(70, 74, 82))
        d.text((x, y + th + 12), theme, font=f_name, fill=INK)
        s = spec[theme]
        d.text((x, y + th + 54),
               "noise %-10s rough %.2f   light %s @ %.1f"
               % (s["noise"], s["roughness"], s["light_color"],
                  s["light_energy"]),
               font=f_mono, fill=DIM)
        sx = x
        for key in ("base_color", "accent_color", "trim_color",
                    "light_color"):
            swatch(d, sx, y + th + 86, 30, s[key])
            d.text((sx + 38, y + th + 90), s[key], font=f_mono, fill=DIM)
            sx += 152
    sheet_im.save(out)
    print("[sheet] %s  %dx%d" % (os.path.relpath(out, REPO), W, H))


def main(argv):
    raw = argv[1] if len(argv) > 1 else os.path.join(
        REPO, "docs/art/review/theme_baseline_2026-09-10")
    out = argv[2] if len(argv) > 2 else raw
    os.makedirs(out, exist_ok=True)
    spec = specs()
    rev = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO,
                         capture_output=True, text=True).stdout.strip()
    stamp = ("art %s  ·  tools/composed_room.sh  ·  Godot 4.5.1 "
             "Compatibility (opengl3)  ·  1280x720  ·  game camera" % rev)
    sheet(raw, "room",
          os.path.join(out, "THEME_BASELINE_colour.png"), spec,
          "Six themes, as they render today",
          [stamp,
           "Each tile is the SAME composed room, rebuilt per theme. The "
           "shell's texture is baked at Blender export;",
           "the fixture housing is the one the pack ships for that theme. "
           "Nothing here is a binder or a proposal."])
    sheet(raw, "greyscale",
          os.path.join(out, "THEME_BASELINE_value.png"), spec,
          "The same six, in value only",
          [stamp,
           "Hue is what a retheme changes; VALUE STRUCTURE is what it has "
           "to preserve. A theme that reads",
           "here reads in the game. concrete_facility, neon_transit and "
           "gothic_stone are near-identical in value:",
           "three of the six read as the same pale grey room. That is a finding, not a capture fault."])
    # A machine-readable sidecar, so the baseline can be diffed later.
    meta = {"art_revision": rev, "godot": "4.5.1.stable",
            "renderer": "Compatibility (opengl3)", "capture": "1280x720",
            "scene": "tools/artpreview/ComposedRoom.gd via "
                     "tools/composed_room.sh",
            "camera": "the game's own camera rig (ComposedRoom probe)",
            "themes": {t: spec[t] for t in THEMES}}
    with open(os.path.join(out, "baseline.json"), "w",
              encoding="utf-8") as fh:
        json.dump(meta, fh, indent=2, sort_keys=True)
    print("[sheet] %s" % os.path.relpath(
        os.path.join(out, "baseline.json"), REPO))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
