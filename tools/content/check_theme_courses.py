#!/usr/bin/env python3
"""Do the panel courses divide the tile they are drawn on?

REPORTS. EXITS 0. It is not a gate, deliberately, and the reason is the
finding it exists for.

`materials.surface_for()` gives every `wall`, `accent` and `wall_ribbed`
its panel courses at a 1.2 m pitch, starting at row 0:

    pitch = int(round(size * 1.2 / metres))
    seams = tuple(range(0, size, pitch))

With the shipped 128 px / 4 m tile that is a 38 px pitch, and 128 is not
a multiple of 38. The courses land at 0, 38, 76, 114 and then the tile
wraps -- putting the next course 14 px after the last instead of 38. On
a tall wall the rhythm is even for 3.6 m and then breaks, once every
4 m, for as long as the wall goes on. It is in every wall and accent
texture in all six themes and has been since Batch 001, because nothing
had ever looked at a repeat.

THE REPAIR IS ONE LINE and it regenerates every wall and accent in six
themes. The owner's 2026-09-22 note says not to mass-regenerate reviewed
assets, and a rhythm change across the whole theme set is a look
decision rather than a defect fix. So this prints the condition on every
run -- it cannot be forgotten -- and refuses to become a gate until
somebody rules. When they do, `--strict` is one flag away.

WHAT IT REFUSES TO ASSUME. The two lines above are required to still be
in `materials.py`. This tool computes what they compute; it is not
entitled to keep doing that against arithmetic that has been replaced.
"""
from __future__ import annotations

import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
THEME_DIR = os.path.join(ROOT, "godot", "content", "theme")
MATERIALS = os.path.join(ROOT, "tools", "blender", "materials.py")

#: `surface_for`'s own arithmetic, required to still be its arithmetic.
PITCH_LINE = "pitch = int(round(size * 1.2 / metres))"
SEAM_LINE = "seams = tuple(range(0, size, pitch))"
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


def courses(w, h, px, margin=12.0):
    """The rows that read as a course: markedly darker than the texture."""
    means = [sum(sum(px[y][x]) / 3.0 for x in range(w)) / w for y in range(h)]
    body = sum(means) / h
    dark = [y for y in range(h) if means[y] < body - margin]
    bands, run = [], []
    for y in dark:
        if run and y - run[-1] > 2:
            bands.append(sum(run) // len(run))
            run = []
        run.append(y)
    if run:
        bands.append(sum(run) // len(run))
    return bands


def main() -> int:
    strict = "--strict" in sys.argv
    source = open(MATERIALS, encoding="utf-8").read()
    for line in (PITCH_LINE, SEAM_LINE):
        if line not in source:
            print("check-courses: REFUSED -- materials.py no longer contains")
            print("    %s" % line)
            print("  This tool computes what surface_for computes and is not")
            print("  entitled to keep doing that against arithmetic that has")
            print("  been replaced. Re-read surface_for().")
            return 3

    size, metres = 128, 4.0
    pitch = int(round(size * 1.2 / metres))
    seams = tuple(range(0, size, pitch))
    divides = size % pitch == 0
    wrap_expected = (seams[0] + size) - seams[-1]

    # THE FINDING IS THE ARITHMETIC, AND IT IS CERTAIN.
    #
    # It does not depend on reading a pixel: `surface_for` computes the
    # course positions, and whether they divide the tile is a fact about
    # that computation. The pixel pass below CORROBORATES it where the
    # textures have enough contrast for a dark-row detector to find all
    # four courses, and says so plainly where they do not. An earlier
    # version of this file led with the pixel count, which made a
    # certain finding look like a two-out-of-eighteen sample.
    print("check-courses: surface_for lays courses at a 1.2 m pitch")
    print("  %d px tile, %.1f m  ->  pitch %d px, courses %s"
          % (size, metres, pitch, list(seams)))
    print("  %d %% %d = %d  ->  the tile %s divided by the pitch"
          % (size, pitch, size % pitch,
             "IS" if divides else "IS NOT"))
    if not divides:
        print("  so the gap ACROSS THE WRAP is %d px, not %d."
              % (wrap_expected, pitch))
    print()

    worst, unread = [], []
    for theme in THEMES:
        for role in COURSED_ROLES:
            path = os.path.join(THEME_DIR, "%s_%s.png" % (theme, role))
            if not os.path.exists(path):
                continue
            w, h, px = load(path)
            bands = courses(w, h, px)
            if len(bands) < 2:
                print("  %-34s no courses read" % ("%s_%s" % (theme, role)))
                continue
            # COMPARE AGAINST WHERE THE COURSES SHOULD BE, rather than
            # inferring a rhythm from what was detected. Two things went
            # wrong when this inferred:
            #
            #   * the gap list was summarised to its first six entries
            #     while the verdict used all of them, so a texture whose
            #     gaps read "13,13,13,13,13,13..." was reported as having
            #     no rhythm -- true (the tail was 14, 6) and unreadable;
            #   * a course the detector missed for lack of contrast turned
            #     into a fake 52 px wrap gap on two textures.
            #
            # `surface_for` says where it puts them. That is the truth to
            # check the pixels against.
            name = "%s_%s" % (theme, role)
            tol = 2
            found = []
            for want in seams:
                near = [b for b in bands if abs(b - want) <= tol]
                found.append(near[0] if near else None)
            hit = sum(1 for f in found if f is not None)
            if hit < len(seams):
                print("  %-34s %d of %d courses read (contrast); "
                      "not counted" % (name, hit, len(seams)))
                unread.append(name)
                continue
            got = [f for f in found if f is not None]
            gaps = [got[i + 1] - got[i] for i in range(len(got) - 1)]
            wrap = (got[0] + h) - got[-1]
            even = wrap == gaps[0] and len(set(gaps)) == 1
            print("  %-34s courses %-18s inside %-12s wrap %3d  %s"
                  % (name, ",".join(str(g) for g in got),
                     ",".join(str(g) for g in gaps), wrap,
                     "even" if even else "BREAKS"))
            if not even:
                worst.append(name)

    print()
    if not divides:
        print("THE FINDING, WHICH IS ARITHMETIC AND NEEDS NO PIXELS:")
        print("  every `wall`, `accent` and `wall_ribbed` texture in every")
        print("  theme has its course rhythm broken at the tile edge, by")
        print("  construction. Courses at %s, tile %d, so the wrap gap is"
              % (list(seams), size))
        print("  %d px against a pitch of %d. On a tall wall the rhythm is"
              % (wrap_expected, pitch))
        print("  even for %.1f m and then breaks, once every %.1f m."
              % (seams[-1] * metres / size, metres))
        print()
        print("  The pixel pass below is corroboration, not the finding.")
        print()
    if unread:
        print("check-courses: on %d texture(s) the detector could not read"
              % len(unread))
        print("  every course. It finds rows markedly darker than the")
        print("  texture, which is a proxy, and a course drawn faintly or")
        print("  over a busy motif does not clear that bar. The arithmetic")
        print("  above still applies to them -- it applies by construction")
        print("  -- but these pixels do not independently confirm it:")
        print("    " + ", ".join(unread))
        print()
    if worst:
        print("check-courses: the pixels confirm it on %d texture(s) where"
              % len(worst))
        print("  all four courses could be read. This is REPORTED, not")
        print("  refused: the repair is")
        print("  one line in surface_for and it regenerates every wall and")
        print("  accent in six themes, which is a look decision for the")
        print("  owner. See docs/art/reports/2026-09-22-glyph-toolchain-"
              "trial.md.")
        if strict:
            print("check-courses: --strict, so this is a failure.")
            return 1
    elif divides:
        print("check-courses: the courses divide the tile and every texture"
              " read keeps its rhythm.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
