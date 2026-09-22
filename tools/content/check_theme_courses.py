#!/usr/bin/env python3
"""Do the painted courses divide the tile they repeat on?

REPORTS. EXITS 0. It is not a gate, and `--strict` makes it one the day
somebody rules. `--dir <path>` measures another set -- the candidate;
`--lines` prints the detected line positions, which is what
it takes to see that the detector has read the wrong thing.

## CORRECTIONS, 2026-09-22 -- this file named the wrong mechanism TWICE

**First version:** said the courses came from `materials.surface_for()`,
which computes `seams = tuple(range(0, size, 38))`. Told that changing
the metadata does not prove any painted course changed.

**Second version:** said `surface.seams` "paints nothing", because
`panel_seams` -- the only function that draws it as LINES -- is called
zero times, and named `paintkit.panel_grid` as the whole mechanism.
**That was also wrong, and the pixels said so.**
`concrete_facility_wall_ribbed` takes no `panel_grid` call at all (its
branch says so in a comment: "the ribs ARE the rhythm here") and still
measures a 38 px rhythm in the exported PNG. 38 px is `surface_for`'s
seam pitch. `paintkit.near_seams()` reads that tuple to aim speckle at
thirteen call sites, `paintkit.bolts()` puts a bolt row on every seam,
and two treatments run weep streaks down from them. The seams paint
grime, bolts and streaks -- just not lines.

## FOUR paths, of which three are live

1. `surface_for` seams at 1.2 m, consumed by `near_seams`, `bolts` and
   two weep-streak loops. **Live. Paints no line.**
2. `paintkit.panel_grid`, `pitch_metres` differing per treatment: 1.2,
   1.35, 2.0, 0.90, 0.60, 0.55, 0.40, 0.30 m, axes independent.
   **Live. Paints lines.**
3. Inline loops inside the treatments, at dimensions `panel_grid` never
   sees: ribs 1.0 m, floor plates 2.0 m, soffit ribs 0.6 m, chequer
   0.14 m, masonry course/block pairs, station tile 0.30 m, mortar
   joint 0.42 m, editor cell 0.5 m; plus seven bolt pitches from 0.18
   to 0.5 m. **Live. Paints lines, cells and bolts.**
4. `paintkit.panel_seams`. **Dead -- called zero times.**

At 32 texels/m in a 128 px tile the live pitches are 38, 43, 64, 29,
19, 18, 13, 10, 32, 4, 11, 9, 7, 6 px, and **only 64, 32 and 4 divide
128.**

## So this measures the EXPORTED TEXTURE, not the generator

Predicting the pitch from source means tracking twenty-odd call sites
across three paths and being wrong when a twenty-first appears -- which
is precisely the mistake this file made twice. The exported PNG is the
artefact that ships. For each texture it finds the rows and columns that
read as a course, takes the gaps INCLUDING the one across the wrap, and
asks the only question that matters: **is the wrap gap the same as the
others?**

## What it does NOT decide

Whether a break is a defect. Intentional irregularity is a real choice
and so is `void_glitch`'s border; authored does not mean good and a
numerical flag does not mean bad. This prints numbers and a human looks.
"""
from __future__ import annotations

import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
THEME_DIR = os.path.join(ROOT, "godot", "content", "theme")
PAINTKIT = os.path.join(ROOT, "tools", "blender", "paintkit.py")

#: The arithmetic this tool is entitled to describe, required to still
#: be the arithmetic. One line per live path, so that moving a path
#: without telling this file refuses the run instead of silently
#: reporting the previous shape of the generator.
GUARD_LINES = {
    "paintkit.py": [
        "step = surface.course(pitch_metres)",          # panel_grid, path 2
        "for y in range(0, surface.size, step):",       # ...and its wrap
        "def snap_to_tile(step, size, minimum=2):",     # the correction
        "SNAP_COURSES = False",                         # off by default
        "return max(0.0, 1.0 - surface.nearest_seam(y) / float(reach))",
    ],                                                  # near_seams, path 1
    "materials.py": [
        "seams = tuple(range(0, size, pitch))",         # surface_for, path 1
        "for x in range(0, surface.size, pitch):",      # ribs, path 3
    ],
}
#: The courses are drawn for these roles and no others.
COURSED_ROLES = ("wall", "accent", "wall_ribbed")
THEMES = ("concrete_facility", "gothic_stone", "neon_transit",
          "rusted_industrial", "temple_ruin", "void_glitch")


def load(path):
    """(width, height, rows of (r, g, b)) from a PNG, without Pillow."""
    raw = open(path, "rb").read()
    pos, idat, pal = 8, b"", None
    w = h = ct = 0
    while pos < len(raw):
        ln = struct.unpack(">I", raw[pos:pos + 4])[0]
        typ = raw[pos + 4:pos + 8]
        d = raw[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, _bd, ct = struct.unpack(">IIBB", d[:10])
        elif typ == b"PLTE":
            pal = d
        elif typ == b"IDAT":
            idat += d
        pos += 12 + ln
    ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    buf = zlib.decompress(idat)
    stride = w * ch
    rows, prev, p = [], bytearray(stride), 0
    for _ in range(h):
        f = buf[p]
        line = bytearray(buf[p + 1:p + 1 + stride])
        p += 1 + stride
        for i in range(stride):
            a = line[i - ch] if i >= ch else 0
            b = prev[i]
            c = prev[i - ch] if i >= ch else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        rows.append(bytes(line))
        prev = line
    out = []
    for line in rows:
        row = []
        for x in range(w):
            s = line[x * ch:(x + 1) * ch]
            row.append(tuple(pal[s[0] * 3:s[0] * 3 + 3]) if ct == 3
                       else tuple(s[:3]))
        out.append(row)
    return w, h, out


def series(w, h, px, axis):
    """Mean luminance per row (axis 0) or per column (axis 1)."""
    if axis == 0:
        return [sum(sum(px[y][x]) / 3.0 for x in range(w)) / w
                for y in range(h)]
    return [sum(sum(px[y][x]) / 3.0 for y in range(h)) / h
            for x in range(w)]


def course_lines(vals, margin=10.0):
    """Which indices read as a course: markedly darker than the field.

    A DETECTOR, not a predictor. `panel_grid` draws a dark line and a
    light lip, and eight call sites use eight different pitches -- so
    finding the lines in the exported pixels is both simpler and more
    honest than tracking the arguments.

    (A cyclic autocorrelation was tried here first and was WRONG: the
    lowest mean-absolute-difference is always at a short lag on a
    smooth series, and it reported a period of 3 for a texture whose
    courses are 38 apart. Minimising difference is not finding rhythm.)
    """
    n = len(vals)
    body = sum(vals) / n
    dark = [i for i in range(n) if vals[i] < body - margin]
    lines, run = [], []
    for i in dark:
        if run and i - run[-1] > 2:
            lines.append(sum(run) // len(run))
            run = []
        run.append(i)
    if run:
        lines.append(sum(run) // len(run))
    return lines


def cyclic_gaps(lines, n):
    """The gaps between courses, INCLUDING the one across the wrap.

    The wrap gap is the whole question. A tile whose courses are even
    inside it and uneven across its own edge has a rhythm that breaks
    once per repeat, for as long as the surface goes on.
    """
    if len(lines) < 2:
        return []
    gaps = [lines[i + 1] - lines[i] for i in range(len(lines) - 1)]
    gaps.append((lines[0] + n) - lines[-1])
    return gaps


#: A course whose centroid lands a texel either side of the lattice is
#: the run-averaging, not a different rhythm. Wider than that and the
#: detector is looking at something which is not a course.
CENTROID_SLOP = 1
#: Three lines give two inside gaps and a wrap, which is not enough to
#: call a rhythm -- and it is exactly the shape that edge wear at both
#: tile edges plus one mark in the middle produces. `void_glitch_accent`
#: is that shape: a flat field with the word "null" centred in it and no
#: course anywhere, detected as [0, 63, 126] and reported for two
#: versions of this file as a 63 px course breaking at the wrap. It was
#: never a course. Four lines minimum.
MIN_LINES = 4


def verdict(lines, n):
    """('even'|'breaks'|None, inside_pitch, wrap) from detected lines.

    `None` means the detector did not find a rhythm it can speak about,
    which is not the same as finding an even one.

    THE DISCRIMINATOR IS EXACT, not a heuristic. For a lattice of step
    `s` the wrap gap is `n % s` when every line is found, and
    `(n % s) + m*s` when the detector misses `m` of them. So

        wrap % pitch == 0   <=>   n % s == 0   <=>   s divides the tile

    for any number of missed lines, because `n % s` is strictly less
    than `s` and therefore never a positive multiple of it. That matters:
    a detector that misses the course at row 0 -- which happens whenever
    the tile's parity makes that row bright -- inflates the wrap by a
    whole pitch, and two versions of this file called that a break.
    """
    if len(lines) < MIN_LINES:
        return None, 0, 0
    gaps = cyclic_gaps(lines, n)
    inside, wrap = gaps[:-1], gaps[-1]
    pitch = sorted(inside)[len(inside) // 2]
    if any(abs(g - pitch) > CENTROID_SLOP for g in inside):
        return None, 0, 0
    # ...and the wrap gap carries the same centroid slop as the others.
    # The ribs in `concrete_facility_wall_ribbed` are a 32 px lattice --
    # which divides 128 exactly -- detected at 3, 34, 66, 98, because a
    # 5 px rib run centres differently where it meets the tile edge. An
    # exact `wrap % pitch == 0` called that a break. It is not one.
    off = wrap % pitch
    even = min(off, pitch - off) <= CENTROID_SLOP
    return ("even" if even else "breaks"), pitch, wrap


def main() -> int:
    strict = "--strict" in sys.argv
    show_lines = "--lines" in sys.argv
    where = THEME_DIR
    if "--dir" in sys.argv:
        where = os.path.abspath(sys.argv[sys.argv.index("--dir") + 1])

    for filename, lines in sorted(GUARD_LINES.items()):
        source = open(os.path.join(ROOT, "tools", "blender", filename),
                      encoding="utf-8").read()
        for line in lines:
            if line in source:
                continue
            print("check-courses: REFUSED -- %s no longer contains" % filename)
            print("    %s" % line)
            print("  This file describes the generator's course arithmetic")
            print("  and it has already described it wrongly twice. It is")
            print("  not entitled to keep describing arithmetic that has")
            print("  been replaced. Re-read the path and update the guard.")
            return 3

    size = 128
    rel = os.path.relpath(where, ROOT)

    print("check-courses: measuring %s" % rel)
    print()
    print("  THREE live paths draw on a course pitch -- surface_for's")
    print("  seams (grime, bolts, weep streaks), paintkit.panel_grid")
    print("  (lines), and inline loops in the treatments (lines, cells,")
    print("  bolts). Each walks range(0, %d, step). A step %d is not a"
          % (size, size))
    print("  whole multiple of leaves an odd interval at the tile's own")
    print("  edge, so the rhythm breaks once per repeat, forever.")
    print()
    print("  Measured from the EXPORTED PNG, cyclically, so the answer")
    print("  does not depend on tracking twenty-odd call sites:")
    print()

    worst, unread, even_read = [], [], []
    for theme in THEMES:
        for role in COURSED_ROLES:
            path = os.path.join(where, "%s_%s.png" % (theme, role))
            if not os.path.exists(path):
                continue
            w, h, px = load(path)
            name = "%s_%s" % (theme, role)
            cells = []
            read_any = False
            for axis, label in ((0, "v"), (1, "h")):
                n = h if axis == 0 else w
                lines = course_lines(series(w, h, px, axis))
                if show_lines:
                    print("      %s %s" % (label, lines))
                # ONLY CLAIM WHAT IS UNAMBIGUOUS. The detector finds dark
                # rows, which is a proxy: these textures also carry edge
                # wear, grime, text and motif, and where those land it is
                # not tracking courses at all. Reporting a break from a
                # measurement that is not measuring one is worse than
                # reporting nothing.
                call, pitch, wrap = verdict(lines, n)
                if call is None:
                    cells.append("%s not read" % label)
                    continue
                read_any = True
                cells.append("%s %d wrap %d%s"
                             % (label, pitch, wrap,
                                "" if call == "even" else "  BREAKS"))
                if call == "even":
                    even_read.append("%s/%s" % (name, label))
                else:
                    worst.append("%s/%s" % (name, label))
            if not read_any:
                unread.append(name)
            print("  %-30s %s" % (name, " | ".join(cells)))

    print()
    if unread:
        print("check-courses: on %d texture(s) the detector could not read"
              % len(unread))
        print("  every course. It finds rows markedly darker than the")
        print("  texture, which is a proxy, and a course drawn faintly or")
        print("  over a busy motif does not clear that bar. Those pixels")
        print("  neither confirm nor deny a break:")
        print("    " + ", ".join(unread))
        print()
    if worst:
        print("check-courses: %d axis/texture pair(s) measured a wrap gap"
              % len(worst))
        print("  unequal to the courses inside the tile:")
        print("    " + ", ".join(worst))
        print()
        print("  REPORTED, NOT REFUSED. The repair is not one line: three")
        print("  live paths compute a pitch, `paintkit.SNAP_COURSES` turns")
        print("  the snap on for all of them at once, and turning it on")
        print("  moves designed spacing by up to a quarter -- 1.35 m to")
        print("  1.0 m, because the divisors of 128 are the powers of two.")
        print("  That is a look decision for the owner. The candidate set")
        print("  is built by tools/blender/build_theme_candidate.py into")
        print("  assets/textures/theme_candidate/; compare with")
        print("    %s --dir assets/textures/theme_candidate"
              % os.path.relpath(os.path.abspath(__file__), ROOT))
        if strict:
            print("check-courses: --strict, so this is a failure.")
            return 1
    else:
        print("check-courses: no texture measured an uneven wrap. %d"
              % len(even_read))
        print("  axis/texture pair(s) were read and every one of them")
        print("  keeps its rhythm across the tile edge.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
