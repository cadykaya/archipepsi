#!/usr/bin/env python3
"""Track A -- the interface family's TEXT FACE.

    GLYPH_ROOT=<checkout> python3 tools/glyphui/author_text.py [out-dir]

The numerals proved the pipeline and answered the engine risk. This is
the face an interface actually talks with: capitals, the digits already
proved, and the punctuation a label needs.

## Why capitals only

A 6x8 cell gives five rows above the baseline. Lowercase needs a
three-row x-height plus ascenders and descenders in the same five, and
at that size the descender either collides with the next line or is one
pixel and reads as dirt. Every interface this game is dressed as used
capitals for the same reason. If body copy later needs a mixed-case
face it wants a taller cell, not a squeezed one.

## Why there is no separate heading face

`run_font_import.sh` measured the imported font scaling to exactly 2x
(`fixed_size_scale_mode`, which the editor's importer sets and a runtime
parse does not). A heading is this face at 16 px. Authoring a second
face at double the size would be two alphabets to keep in step for a
result the engine already gives, and the two would drift the first time
only one of them was corrected.

## The digits are the numerals', unchanged

Byte-for-byte the same rows as `author_numerals.py`. A UI that spells
`12` one way in a label and another in a count has two fonts pretending
to be one.
"""

from __future__ import annotations

import os
import shutil
import sys
import tempfile

import fontkit
import glyphrun

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))

OWNER = "act_owner_arty"
ARTIST = "act_agent_arty"

W, H = 6, 8
BASELINE = 6
#: The space has no ink to measure, so its pen travel is declared.
BLANK_ADVANCE = 3

#: Five rows, resting on the baseline. Ink begins at x = 1, so a glyph
#: may be at most five columns wide -- which is why M, W, X, V and Y are
#: five and everything else is four or three. Variable width is the
#: point: the advance table is what carries it, and the engine was
#: measured composing it.
GLYPHS = {
    " ": ["..", "..", "..", "..", ".."],
    "!": ["#", "#", "#", ".", "#"],
    "'": ["#", ".", ".", ".", "."],
    "(": [".#", "#.", "#.", "#.", ".#"],
    ")": ["#.", ".#", ".#", ".#", "#."],
    "+": ["...", ".#.", "###", ".#.", "..."],
    ",": ["..", "..", "..", "##", ".#"],
    "-": ["....", "....", "####", "....", "...."],
    ".": ["..", "..", "..", "..", "#."],
    "/": ["...#", "..#.", "..#.", ".#..", "#..."],
    ":": ["..", "#.", "..", "#.", ".."],
    "<": ["..#", ".#.", "#..", ".#.", "..#"],
    ">": ["#..", ".#.", "..#", ".#.", "#.."],
    "?": ["###", "..#", ".##", "...", ".#."],
    "%": ["#..#", "...#", "..#.", ".#..", "#..#"],
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
    "A": [".##.", "#..#", "####", "#..#", "#..#"],
    "B": ["###.", "#..#", "###.", "#..#", "###."],
    "C": [".###", "#...", "#...", "#...", ".###"],
    "D": ["###.", "#..#", "#..#", "#..#", "###."],
    "E": ["####", "#...", "###.", "#...", "####"],
    "F": ["####", "#...", "###.", "#...", "#..."],
    "G": [".###", "#...", "#.##", "#..#", ".###"],
    "H": ["#..#", "#..#", "####", "#..#", "#..#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "J": ["..##", "...#", "...#", "#..#", ".##."],
    "K": ["#..#", "#.#.", "##..", "#.#.", "#..#"],
    "L": ["#...", "#...", "#...", "#...", "####"],
    "M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
    "N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
    "O": [".##.", "#..#", "#..#", "#..#", ".##."],
    "P": ["###.", "#..#", "###.", "#...", "#..."],
    "Q": [".##.", "#..#", "#..#", "#.#.", ".#.#"],
    "R": ["###.", "#..#", "###.", "#.#.", "#..#"],
    "S": [".###", "#...", ".##.", "...#", "###."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#..#", "#..#", "#..#", "#..#", ".##."],
    "V": ["#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    "Y": ["#...#", ".#.#.", "..#..", "..#..", "..#.."],
    "Z": ["####", "...#", ".##.", "#...", "####"],
    "x": ["#..#", ".##.", "#..#"],
}

#: Frame order, and therefore the order on the sheet. Sorted so that
#: adding a character does not reshuffle every frame that follows it --
#: a diff of this font should be the glyph that changed.
CHARACTERS = "".join(sorted(GLYPHS))

ADVANCE = {c: (fontkit.advance_of(rows) or BLANK_ADVANCE)
           for c, rows in GLYPHS.items()}

ARTIFACTS = ("ui_text.fnt", "ui_text.png")


def main():
    out_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1
                              else os.path.join(REPO, "assets", "ui"))
    os.makedirs(out_dir, exist_ok=True)
    work = tempfile.mkdtemp(prefix="glyphui_")
    ses = glyphrun.Session(
        os.environ.get("GLYPH_ROOT", "/home/user/glyph-trial"),
        work, "archipepsi_text.glyph", OWNER, ARTIST)
    ses.create("the art lane draws the interface family's text face")
    print("[ui] granted %s edit; lead owner stays %s" % (ARTIST, OWNER))

    _, written, exported = fontkit.build_face(
        ses, work, "ui_text", "text", CHARACTERS, GLYPHS,
        (W, H), BASELINE, ADVANCE, sheet=128)
    fontkit.write_files(ses, work, out_dir, written,
                        exported["record"], "sheet")

    for name in ARTIFACTS:
        shutil.copyfile(os.path.join(work, name),
                        os.path.join(out_dir, name))
    print("[ui] %d character(s), %d artifact(s) -> %s"
          % (len(CHARACTERS), len(ARTIFACTS), out_dir))
    if os.environ.get("GLYPH_KEEP_WORK"):
        print("[ui] project kept at %s" % ses.project)
    else:
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
