#!/usr/bin/env python3
"""Track A, slice 1 -- the interface family's NUMERALS, authored in Glyph.

    GLYPH_ROOT=<checkout> python3 tools/glyphui/author_numerals.py [out-dir]

`out-dir` defaults to `assets/ui/`, and receives only the two files that
are the deliverable: the `.fnt` and its page. Both are byte-identical
across runs, which is what lets them be
committed and checked by `tools/check_art_current.sh` like any other
generated asset.

The `.glyph` project is NOT one of them. Its revision identifiers are
fresh on every run, so it can never rebuild byte-identical and has no
business in the tree pretending to be a source. The source is this file:
the glyph rows above are the art, in text, diffable.

## Why numerals first, and why only numerals

`04` section 9 asks for a typography FAMILY -- body text, distinguishable
numerals, headings, keycaps. Numerals are the part a menu cannot fake: a
quantity, a charge count, a `3/8`, an `x12`. They are also the part most
likely to be unreadable at panel scale, because a `6` and an `8` and a
`0` differ by two pixels at this size.

And they are the smallest thing that proves the PIPELINE. The open
technical risk named in the plan is the bitmap-font import into Godot
**4.5.1** -- the Glyph guide's own proof names 4.3. Twelve glyphs with
deliberately unequal advances answer it: if `"11"` measures narrower
than `"00"` in the engine, the advances composed and the metrics
survived the trip.

## What this does NOT do

It does not open, verify or migrate any existing `.glyph`. Arty's
September trial recorded that opening a project checkpoints its WAL and
modified six tracked fixtures; this authors a NEW project in a scratch
directory and never touches the approved sources.

Owner and artist are distinct identities, as the handoff requires, and
the artist holds a granted `edit` -- it does not approve its own work.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile

import fontkit
import glyphrun

#: 6 x 8 cells. Small enough to be pixel art at panel scale, tall enough
#: for a digit to have a distinguishable waist -- which is the whole
#: difference between a legible 8 and a legible 0.
W, H = 6, 8
#: The row the ink rests ON. A glyph with no descender has its lowest
#: ink one row above it. Declared, never measured off the art: a font
#: whose baseline the tool guessed would be the tool making the
#: typography.
BASELINE = 6

OWNER = "act_owner_arty"
ARTIST = "act_agent_arty"

#: Twelve glyphs. The ten digits, plus the two characters a count is
#: actually written with.
CHARACTERS = "0123456789/x"

#: Each glyph as rows of the 6x8 cell, `#` for ink. Drawn on rows 1..5
#: so every one rests on BASELINE = 6 and none descends -- the check
#: refuses a set whose baselines disagree rather than straightening it,
#: and agreeing here is the point of a numeral set.
#:
#: `1` is deliberately narrow -- three columns of ink where `0` has four
#: -- and so gets a narrower advance. If a menu renders "11" the same
#: width as "00", the advances did not survive the export and the proof
#: has failed. Narrow means narrow in the INK: a `1` with a four-column
#: base serif is not a narrow glyph, whatever its advance claims.
#:
#: `x` is lowercase and only three rows tall, with no blank rows to pad
#: it -- a trailing blank row would lift it a pixel off the baseline and
#: `x12` would read as a floating multiplication sign.
GLYPHS = {
    "0": ["####", "#..#", "#..#", "#..#", "####"],
    "1": [".#", "##", ".#", ".#", "###"],
    "2": ["####", "...#", "####", "#...", "####"],
    "3": ["####", "...#", "####", "...#", "####"],
    "4": ["#..#", "#..#", "####", "...#", "...#"],
    "5": ["####", "#...", "####", "...#", "####"],
    "6": ["####", "#...", "####", "#..#", "####"],
    "7": ["####", "...#", "..#.", ".#..", ".#.."],
    "8": ["####", "#..#", "####", "#..#", "####"],
    "9": ["####", "#..#", "####", "...#", "####"],
    "/": ["...#", "..#.", "..#.", ".#..", "#..."],
    "x": ["#..#", ".##.", "#..#"],
}
def _advance(rows):
    """The pen's travel: past the rightmost ink in ANY row, plus nothing.

    The ink starts at x = 1, so a glyph whose widest row's last `#` is at
    index `i` has ink out to x = i + 1 and the pen must reach i + 2. The
    blank column between two glyphs is then the NEXT glyph's own left
    bearing, which is why no second column is added here.

    The first version of this measured `len(rows[0])` -- the top row --
    and `x-glyph.check_font` refused the set: `1`'s top row is 2 columns
    and its base serif is 3, so the pen stopped inside its own ink and
    the following character would have overlapped it. A glyph is as wide
    as its widest row, never as wide as its first.
    """
    return max(row.rindex("#") for row in rows if "#" in row) + 2


ADVANCE = {c: _advance(rows) for c, rows in GLYPHS.items()}


#: The two files that are the deliverable. Everything else the authoring
#: leaves behind -- the project, the batch scripts, the raw command
#: results -- stays in the scratch work directory.
#:
#: The export also writes `ui_numerals.json`, the sprite sheet's own
#: metadata, and it is NOT here. It rebuilds identical in every field
#: except `revision`, which is a fresh per-run identifier, so committing
#: it would mean a currency check that has to know to ignore one key --
#: and for a FONT it is redundant anyway: the `.fnt` already carries
#: every character's rect and advance. When the nine-slice panels need
#: sheet metadata that question comes back, with a real need behind it.
ARTIFACTS = ("ui_numerals.fnt", "ui_numerals.png")

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))


def main():
    out_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1
                              else os.path.join(REPO, "assets", "ui"))
    os.makedirs(out_dir, exist_ok=True)
    work = tempfile.mkdtemp(prefix="glyphui_")
    ses = glyphrun.Session(
        os.environ.get("GLYPH_ROOT", "/home/user/glyph-trial"),
        work, "archipepsi_ui.glyph", OWNER, ARTIST)
    ses.create("the art lane draws the interface family")
    print("[ui] granted %s edit; lead owner stays %s" % (ARTIST, OWNER))
    txn = ses.txn

    # --- the canvas, the palette, and frame 0 ---------------------------
    made = txn({"creates": ["asset", "palette", "variant"]}, [
        ("palette.create", {"entries": [
            {"name": "ink", "value": dict(zip("rgba", fontkit.TEXT_INK + (255,)))},
        ]}),
        ("asset.create", {"name": "ui_numerals"}),
    ], "the interface family's ink")
    palette = made[0]["palette"]["id"]
    entry = made[0]["palette"]["order"][0]
    asset = made[1]["asset"]["id"]

    made = txn({"creates": ["variant"]}, [
        ("variant.create", {"name": "numerals", "width": W, "height": H,
                            "color_mode": "indexed", "palette": palette,
                            "asset": asset, "representation": "glyph"}),
    ], "the numerals canvas")
    variant = made[0]["variant"]["id"]
    frames = list(made[0]["variant"]["frames"])
    cels = list(made[0]["variant"]["cels"])

    # --- one frame per glyph, in CHARACTERS order -----------------------
    for i in range(1, len(CHARACTERS)):
        made = txn({"variants": [variant]}, [
            ("frame.create", {"variant": variant, "position": i}),
        ], "frame %d" % i)
        frames.append(made[0]["frame"]["id"])
        cels.append(made[0]["cels"][0]["cel"])
    print("[ui] %d frame(s) for %d character(s)" % (len(frames), len(CHARACTERS)))

    # --- the ink, one pixel run at a time -------------------------------
    for i, ch in enumerate(CHARACTERS):
        rows = GLYPHS[ch]
        runs = []
        for dy, row in enumerate(rows):
            y = BASELINE - len(rows) + dy
            x = 1
            while x - 1 < len(row):
                if row[x - 1] == "#":
                    start = x
                    while x - 1 < len(row) and row[x - 1] == "#":
                        x += 1
                    runs.append(((start, y), (x - 1, y)))
                else:
                    x += 1
        txn({"cels": [cels[i]]}, [
            ("pixels.draw", {"cel": cels[i], "shape": "line",
                             "points": [list(a), list(b)],
                             "value": {"entry": entry}})
            for a, b in runs
        ], "glyph %r" % ch)
    print("[ui] %d glyph(s) drawn" % len(CHARACTERS))

    # --- the metrics, as anchors. Glyph will not invent them. -----------
    for name, role, at in (
            ("baseline", "typography",
             {frames[i]: [0, BASELINE] for i in range(len(CHARACTERS))}),
            ("advance", "typography",
             {frames[i]: [ADVANCE[c], 0]
              for i, c in enumerate(CHARACTERS)})):
        txn({"variants": [variant], "semantics": True}, [
            ("anchor.set", {"variant": variant, "name": name,
                            "role": role, "positions": at}),
        ], "the %s" % name)
    print("[ui] baseline and advance declared on every glyph")

    # --- the sheet preset, then the two font calls, IN ONE PROCESS ----
    #
    # "A preset identifier lives only for the life of the server that
    # declared it" -- the CLI's own help says so, and declaring it in one
    # `glyph run` and citing it from the next got
    # `TARGET_NOT_FOUND: export preset ... does not resolve`. So the
    # preset, the check and the write are one batch: three inspections
    # that have to agree about the same rectangles.
    preset_spec = ses.sheet_preset("ui_numerals", [variant], 128, 128)
    font_args = {"preset": "$1.preset", "characters": CHARACTERS,
                 "baseline_anchor": "baseline", "advance_anchor": "advance"}
    results = ses.batch([
        {"command": "export.define_preset", "input": preset_spec},
        {"command": "x-glyph.check_font", "input": font_args},
        {"command": "x-glyph.bitmap_font", "input": font_args},
        {"command": "export.run",
         "input": {"preset": "$1.preset", "destination": work}},
    ], label="font")
    check, written, exported = results[1], results[2], results[3]

    faults = check.get("faults", [])
    for f in faults:
        print("[ui] FONT FAULT: %s %r %s"
              % (f.get("kind"), f.get("character"), f.get("detail")))
    if faults:
        raise SystemExit("[ui] the alphabet disagrees with itself; "
                         "the .fnt was written anyway and must not ship")
    print("[ui] check_font: no faults across %d glyph(s)"
          % len(check.get("measures", [])))
    for m in check.get("measures", []):
        print("[ui]   %r advance %s ink %s above %s below %s"
              % (m.get("character"), m.get("advance"), m.get("ink"),
                 m.get("above_baseline"), m.get("below_baseline")))

    with open(os.path.join(work, "numerals.fnt.json"), "w") as fh:
        json.dump(written, fh, indent=2, sort_keys=True)
    print("[ui] bitmap_font written; page %r"
          % (written.get("font", written).get("page", {}) or {}).get("file"))
    # `export.run` "returns bytes. Whether anything reaches a disk is your
    # call." -- so the sheet is written by the CLI's own `export`
    # subcommand, in a SECOND process, which is only possible because an
    # export record carries its `preset_declaration`: the documented way
    # to re-run a preset whose id died with the server that declared it.
    # The alternative -- decoding the base64 out of the record here --
    # would make this script the PNG writer, and then a bug in my
    # decoding would look like a bug in Glyph's export.
    ses.write_export(exported["record"], label="sheet")

    # The .fnt is Glyph's text, written verbatim under the name Glyph
    # suggested, beside the page under the name the .fnt itself cites.
    fnt = written["fnt"] if "fnt" in written else written["font"]["fnt"]
    fnt_path = os.path.join(work, fnt["suggested_path"])
    with open(fnt_path, "w") as fh:
        fh.write(fnt["text"])
    page = os.path.basename(
        fnt["text"].split('file="', 1)[1].split('"', 1)[0])
    if not os.path.exists(os.path.join(work, page)):
        raise SystemExit("the .fnt cites page %r and no such file was "
                         "written; exported: %s"
                         % (page, sorted(os.listdir(work))))
    print("[ui] wrote %s and its page %s" % (fnt["suggested_path"], page))

    # --- the deliverable, and only the deliverable ----------------------
    revision = ses.head()
    for name in ARTIFACTS:
        src = os.path.join(work, name)
        if not os.path.exists(src):
            raise SystemExit("the export produced no %r; it wrote %s"
                             % (name, sorted(os.listdir(work))))
        shutil.copyfile(src, os.path.join(out_dir, name))
    print("[ui] %d artifact(s) -> %s" % (len(ARTIFACTS), out_dir))
    if os.environ.get("GLYPH_KEEP_WORK"):
        print("[ui] project kept at %s, revision %s"
              % (ses.project, revision))
    else:
        shutil.rmtree(work)
        print("[ui] project built and discarded; revision was %s" % revision)


if __name__ == "__main__":
    main()
