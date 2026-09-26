#!/usr/bin/env python3
"""Track A -- the shared interface symbols and the page arrows.

    GLYPH_ROOT=<checkout> python3 tools/glyphui/author_icons.py [out-dir]

## Shapes, not states

Every icon here is ONE ink colour on transparency. That is deliberate,
and it is the line the owner drew: item and state art waits for
Production's real vocabulary. A `control` symbol means "you can operate
this" only when it is operable, and a `blocked` exit is blocked only
until it is not -- so the colour that says which is a STATE, applied by
the interface at runtime, and not something to bake into the art.

`icons.json` records the tint each symbol is meant to take and in what
state, so the intent is written down without being frozen into pixels:
`signal` when a thing can be used (and only then -- signal is reserved
for interactables), `dead` when it is locked or unpowered, and the
chrome's neutral ink otherwise.

## White ink, so a tint lands exactly

RULED 2026-09-26: *"use pure-white source ink for tintable semantic
symbols so ordinary runtime modulation produces the exact palette
colour. Keep the text face's off-white ink for text."* An interface
tints by MULTIPLYING (`modulate`, `self_modulate`, a font colour), and
white times a colour is that colour. The first ink here was the text
face's `#e8eef6`, which lands every tint 3-9% darker per channel than the
palette's value. So the symbols ink in `#ffffff`, and `icons.json`'s
`_tints` names the EXACT colour each tint resolves to -- including the
chrome ink, which is the text face's ink, so a neutral symbol and the
label beside it still match. `run_ui_icons.sh` renders every symbol in
every tint it names and reads the palette colour back.

## Why 12 px

Two text lines are 16 px. A symbol that sits BESIDE a label wants to be
visibly its own object and not a glyph that fell out of the font, and a
12 px cell with a 1 px margin gives a 10 px drawing -- enough for a door
frame to have an inside, which is the whole of the blocked-exit read.

The margin is a rule, not a habit: two symbols side by side, or a symbol
on a keycap, must not touch. The first drawing of four of these ran to
the cell edge while this paragraph said otherwise, so `main` now reads
every EXPORTED page back and refuses ink on the outer ring -- checking
the file Glyph wrote, not the strings below.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile

import fontkit
import glyphrun

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import palette as art_palette  # noqa: E402  (after sys.path)
OWNER = "act_owner_arty"
ARTIST = "act_agent_arty"
W = H = 12

#: 12x12, `#` is ink. Drawn so that the pairs a player must tell apart
#: differ in SHAPE and not only in detail: `exit` and `blocked` share a
#: door frame on purpose, because they are the same place in two
#: states, and the bar across the opening is the whole difference.
ICONS = {
    "arrow_right": [
        "............",
        "...#........",
        "...##.......",
        "...###......",
        "...####.....",
        "...#####....",
        "...#####....",
        "...####.....",
        "...###......",
        "...##.......",
        "...#........",
        "............",
    ],
    "circuit": [
        "............",
        ".....##.....",
        ".....##.....",
        "....####....",
        "...#....#...",
        ".###....###.",
        ".###....###.",
        "...#....#...",
        "....####....",
        ".....##.....",
        ".....##.....",
        "............",
    ],
    "control": [
        "............",
        "............",
        "........##..",
        ".......##...",
        "......##....",
        ".....##.....",
        "...#####....",
        "..#######...",
        ".##########.",
        ".#........#.",
        ".##########.",
        "............",
    ],
    "exit": [
        "............",
        "..########..",
        "..#......#..",
        "..#...#..#..",
        "..#...##.#..",
        "..#.#####...",
        "..#.#####...",
        "..#...##.#..",
        "..#...#..#..",
        "..#......#..",
        ".##......##.",
        "............",
    ],
    "blocked": [
        "............",
        "..########..",
        "..#......#..",
        ".##########.",
        ".##########.",
        "..#......#..",
        "..#......#..",
        ".##########.",
        ".##########.",
        "..#......#..",
        ".##......##.",
        "............",
    ],
}

#: Derived rather than drawn: a mirrored or rotated arrow that was drawn
#: by hand is an arrow that is one pixel off from its partner.
def _mirror(rows):
    return [r[::-1] for r in rows]


def _rotate_left(rows):
    """90 degrees anticlockwise: the right arrow becomes the up arrow."""
    n = len(rows)
    return ["".join(rows[r][n - 1 - c] for r in range(n)) for c in range(n)]


ICONS["arrow_left"] = _mirror(ICONS["arrow_right"])
ICONS["arrow_up"] = _rotate_left(ICONS["arrow_right"])
ICONS["arrow_down"] = list(reversed(ICONS["arrow_up"]))

#: What each symbol is FOR, and the tint the interface is meant to give
#: it by state. Recorded, not applied.
MEANING = {
    "arrow_left": ("page back", {"any": "chrome ink"}),
    "arrow_right": ("page forward", {"any": "chrome ink"}),
    "arrow_up": ("scroll up", {"any": "chrome ink"}),
    "arrow_down": ("scroll down", {"any": "chrome ink"}),
    "circuit": ("a powered junction in the conduit network",
                {"powered": "chrome ink", "unpowered": "dead"}),
    "control": ("a thing the player can operate",
                {"operable": "signal", "not operable": "dead"}),
    "exit": ("a way out of the room", {"open": "chrome ink"}),
    "blocked": ("the same way out, closed", {"blocked": "dead"}),
}

#: Every tint a state names, and the exact colour it resolves to. An
#: interface multiplies the white ink by this and gets this.
TINT_SOURCES = {
    "chrome ink": ("the text face's ink (fontkit.TEXT_INK)", None, None),
    "signal": ("universal.signal.ramp[2] -- the step the selected "
               "panel's outline uses", "signal", 2),
    "dead": ("universal.dead.ramp[1] -- recessive on a well, the "
             "keycap lip's step", "dead", 1),
}


def tints():
    out = {}
    universal = art_palette.palette()["universal"]
    for name, (why, family, step) in TINT_SOURCES.items():
        if family is None:
            hexv = "#%02x%02x%02x" % fontkit.TEXT_INK
        else:
            hexv = universal[family]["ramp"][step]
        out[name] = {"hex": hexv.lower(), "is": why}
        if family is not None:
            out[name].update({"family": family, "step": step})
    return out


NAMES = sorted(ICONS)
ARTIFACTS = tuple("icon_%s.png" % n for n in NAMES)


def runs(rows):
    out = []
    for y, row in enumerate(rows):
        x = 0
        while x < len(row):
            if row[x] == "#":
                start = x
                while x < len(row) and row[x] == "#":
                    x += 1
                out.append(((start, y), (x - 1, y)))
            else:
                x += 1
    return out


def _margin_faults(path):
    """Ink on the outer ring of an EXPORTED page, and ink of more than one
    colour. Reads the PNG Glyph wrote, so a drawing and its file cannot
    disagree without this noticing."""
    from PIL import Image
    with Image.open(path) as page:
        img = page.convert("RGBA")
    if img.size != (W, H):
        return ["size %dx%d, not %dx%d" % (img.size + (W, H))]
    ink = {(x, y): img.getpixel((x, y)) for x in range(W) for y in range(H)
           if img.getpixel((x, y))[3] > 0}
    faults = ["ink at %d,%d" % xy for xy in sorted(ink)
              if xy[0] in (0, W - 1) or xy[1] in (0, H - 1)]
    if len(set(ink.values())) > 1:
        faults.append("%d ink colours" % len(set(ink.values())))
    if not ink:
        faults.append("no ink")
    return faults


def main():
    for name, rows in ICONS.items():
        if len(rows) != H or any(len(r) != W for r in rows):
            raise SystemExit("icon %r is not %dx%d" % (name, W, H))
    out_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1
                              else os.path.join(REPO, "assets", "ui"))
    os.makedirs(out_dir, exist_ok=True)
    work = tempfile.mkdtemp(prefix="glyphui_")
    ses = glyphrun.Session(
        os.environ.get("GLYPH_ROOT", "/home/user/glyph-trial"),
        work, "archipepsi_icons.glyph", OWNER, ARTIST)
    ses.create("the art lane draws the interface family's symbols")

    made = ses.txn({"creates": ["asset", "palette"]}, [
        ("palette.create", {"entries": [
            {"name": "ink", "value": {"r": 255, "g": 255, "b": 255, "a": 255}},
        ]}),
        ("asset.create", {"name": "ui_icons"}),
    ], "the symbols' ink")
    pal, entry = made[0]["palette"]["id"], made[0]["palette"]["order"][0]
    asset = made[1]["asset"]["id"]

    variants = []
    for name in NAMES:
        made = ses.txn({"creates": ["variant"]}, [
            ("variant.create", {"name": name, "width": W, "height": H,
                                "color_mode": "indexed", "palette": pal,
                                "asset": asset, "representation": "icon"}),
        ], "the %s canvas" % name)
        variant = made[0]["variant"]["id"]
        cel = made[0]["variant"]["cels"][0]
        ses.txn({"cels": [cel]}, [
            ("pixels.draw", {"cel": cel, "shape": "line",
                             "points": [list(a), list(b)],
                             "value": {"entry": entry}})
            for a, b in runs(ICONS[name])
        ], "the %s symbol" % name)
        results = ses.batch([
            {"command": "export.define_preset",
             "input": ses.sheet_preset("icon_%s" % name, [variant], W, H)},
            {"command": "export.run",
             "input": {"preset": "$1.preset", "destination": work}},
        ], label=name)
        before = set(f for f in os.listdir(work) if f.endswith(".png"))
        ses.write_export(results[1]["record"], label=name)
        fresh = sorted(set(f for f in os.listdir(work)
                           if f.endswith(".png")) - before)
        if len(fresh) != 1:
            raise SystemExit("%s exported %d page(s): %s"
                             % (name, len(fresh), fresh))
        shutil.move(os.path.join(work, fresh[0]),
                    os.path.join(work, "icon_%s.png" % name))
        variants.append(variant)
        print("[icons] %s" % name)

    same = ses.run("x-glyph.check_set", {"variants": variants,
                                         "require_same_size": True})
    if same.get("faults"):
        raise SystemExit("[icons] not one set: %s" % same["faults"])
    print("[icons] check_set: one set, all %dx%d" % (W, H))

    for name in ARTIFACTS:
        faults = _margin_faults(os.path.join(work, name))
        if faults:
            raise SystemExit("[icons] %s breaks the 1 px margin: %s"
                             % (name, faults))
    print("[icons] every exported page keeps its 1 px margin")

    for name in ARTIFACTS:
        shutil.copyfile(os.path.join(work, name), os.path.join(out_dir, name))
    table = tints()
    used = {t for n in NAMES for t in MEANING[n][1].values()}
    if used - set(table):
        raise SystemExit("[icons] a state names tint(s) %s with no colour"
                         % sorted(used - set(table)))
    record = {n: {"size": [W, H], "means": MEANING[n][0],
                  "tint_by_state": MEANING[n][1],
                  "file": "icon_%s.png" % n} for n in NAMES}
    record["_ink"] = "#ffffff"
    record["_tints"] = table
    with open(os.path.join(out_dir, "icons.json"), "w") as fh:
        json.dump(record, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print("[icons] %d symbol(s) + icons.json -> %s" % (len(NAMES), out_dir))
    if not os.environ.get("GLYPH_KEEP_WORK"):
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
