#!/usr/bin/env python3
"""Did adding a character leave every other character exactly as it was?

    python3 tools/glyphui/verify_face_unchanged.py [old-ref] [face]

Compares `assets/ui/<face>.fnt` and its page, as they are now, with the
same two files at <old-ref> (default HEAD). The default face is
`ui_text`. For every character the old face had, it requires:

  - the same cell pixels: the glyph's rectangle, read off each page,
    compared RGBA for RGBA;
  - the same width, height, x/y offset and advance in the `.fnt`;
  - the same line height, base and page size.

Only a character's position ON THE PAGE may differ. Frames are in code
point order (`author_text.py`), so a new character moves every later one
by one slot. The `.fnt` carries the new positions, so the page and the
`.fnt` are a pair and must be taken together.

Prints each character that was added, with its pixels. Read-only; exit 1
on any change to an existing character.
"""

from __future__ import annotations

import io
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
METRICS = ("width", "height", "xoffset", "yoffset", "xadvance", "page")


def read(ref, path):
    if ref is None:
        with open(os.path.join(ROOT, path), "rb") as handle:
            return handle.read()
    return subprocess.run(["git", "show", "%s:%s" % (ref, path)], cwd=ROOT,
                          check=True, capture_output=True).stdout


def parse(text):
    """-> (common, {id: {field: int}})"""
    common, chars = {}, {}
    for line in text.splitlines():
        head, _, rest = line.partition(" ")
        fields = {}
        for part in rest.split():
            key, _, value = part.partition("=")
            fields[key] = value
        if head == "common":
            common = {k: fields[k] for k in ("lineHeight", "base", "scaleW",
                                              "scaleH", "pages")}
        elif head == "char":
            chars[int(fields["id"])] = {k: int(v) for k, v in fields.items()
                                        if v.lstrip("-").isdigit()}
    return common, chars


def cell(page, c):
    """The glyph's rectangle as rows of RGBA tuples."""
    return [[page.getpixel((c["x"] + x, c["y"] + y))
             for x in range(c["width"])] for y in range(c["height"])]


def main():
    ref = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
    face = sys.argv[2] if len(sys.argv) > 2 else "ui_text"
    fnt, png = "assets/ui/%s.fnt" % face, "assets/ui/%s.png" % face
    old_common, old = parse(read(ref, fnt).decode("utf-8"))
    new_common, new = parse(read(None, fnt).decode("utf-8"))
    old_page = Image.open(io.BytesIO(read(ref, png))).convert("RGBA")
    new_page = Image.open(io.BytesIO(read(None, png))).convert("RGBA")
    problems, moved = [], 0
    for key in old_common:
        if old_common[key] != new_common.get(key):
            problems.append("common %s: %s, was %s"
                            % (key, new_common.get(key), old_common[key]))
    if old_page.size != new_page.size:
        problems.append("page size %s, was %s" % (new_page.size,
                                                  old_page.size))
    for cid, was in sorted(old.items()):
        now = new.get(cid)
        label = "%r (U+%04X)" % (chr(cid), cid)
        if now is None:
            problems.append("%s is gone" % label)
            continue
        for k in METRICS:
            if was.get(k) != now.get(k):
                problems.append("%s %s: %s, was %s"
                                % (label, k, now.get(k), was.get(k)))
        if cell(old_page, was) != cell(new_page, now):
            problems.append("%s: its pixels changed" % label)
        if (was["x"], was["y"]) != (now["x"], now["y"]):
            moved += 1
    added = sorted(set(new) - set(old))
    print("%s against %s: %d character(s) before, %d now; %d kept their "
          "slot, %d moved one or more slots on the page"
          % (face, ref, len(old), len(new), len(old) - moved, moved))
    for cid in added:
        c = new[cid]
        print("  added %r (U+%04X): advance %d, cell %dx%d at (%d, %d)"
              % (chr(cid), cid, c["xadvance"], c["width"], c["height"],
                 c["x"], c["y"]))
        for row in cell(new_page, c):
            print("    " + "".join("#" if p[3] else "." for p in row))
    if problems:
        for p in problems:
            print("FAIL: %s" % p)
        return 1
    print("PASS: every existing character has the same pixels, size, "
          "offsets and advance; only page positions moved")
    return 0


if __name__ == "__main__":
    sys.exit(main())
