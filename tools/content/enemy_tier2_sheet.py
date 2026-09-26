#!/usr/bin/env python3
"""Tier 2 evidence: the two pairs Track B flagged, before and after.

    python3 tools/content/enemy_tier2_sheet.py <before dir> <after dir> <out.png>

For melee/ranged and brute/bulwark, at each review yaw, the two
silhouettes scaled to a common height -- the metric's own `scaled`
comparison -- and laid over each other: grey where both are, blue where
only the first role is, orange where only the second. The blue and the
orange are the TELL: the only area the metric can tell the pair apart by.
Under each, the scaled overlap, computed here by
`enemy_readability.compare` from the same masks.

Below that, the two re-cut roles as the player gets them: native size at
the review distance (30 px per metre at 18 m), enlarged without
smoothing, before and after.

Before is the models as Track B measured them (frozen masks); after is
whatever the harness last wrote. This draws; the numbers are the metric's.
"""

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import enemy_readability as er  # noqa: E402

PAIRS = [("melee", "ranged"), ("brute", "bulwark")]
RECUT = ["ranged", "bulwark"]
YAWS = [0, 45, 90]
ZOOM = 3
NATIVE_ZOOM = 4
PAD = 14
BG = (16, 20, 24)
INK = (224, 232, 238)
DIM = (140, 150, 160)
BOTH = (112, 120, 128)
A_ONLY = (70, 140, 230)
B_ONLY = (240, 150, 40)
FLAG = (255, 96, 80)
GOOD = (120, 220, 140)


def mask(root, role, yaw):
    return er.mask_of(os.path.join(root, "MASK_%s_y%03d.png" % (role, yaw)))


def overlay(a, b):
    """The pair on the metric's scaled canvas, coloured by who covers what."""
    sa, sb = er.scaled(a, er.NORM), er.scaled(b, er.NORM)
    fit = (max(sa.size[0], sb.size[0]) + 2, er.NORM + 2)
    ca, cb = er.on_canvas(sa, fit), er.on_canvas(sb, fit)
    out = Image.new("RGB", fit, BG)
    pa, pb, po = ca.load(), cb.load(), out.load()
    for y in range(fit[1]):
        for x in range(fit[0]):
            ia, ib = pa[x, y] > 0, pb[x, y] > 0
            if ia and ib:
                po[x, y] = BOTH
            elif ia:
                po[x, y] = A_ONLY
            elif ib:
                po[x, y] = B_ONLY
    return out.resize((fit[0] * ZOOM, fit[1] * ZOOM), Image.NEAREST)


def native(m):
    """A mask as the player sees it at 18 m, enlarged without smoothing."""
    out = Image.new("RGB", m.size, BG)
    out.paste(INK, mask=m)
    return out.resize((m.size[0] * NATIVE_ZOOM, m.size[1] * NATIVE_ZOOM),
                      Image.NEAREST)


def main(before, after, out_path):
    rows = []      # (label, [(image, caption, colour)])
    for a, b in PAIRS:
        for tag, root in (("BEFORE", before), ("AFTER", after)):
            cells = []
            for yaw in YAWS:
                ma, mb = mask(root, a, yaw), mask(root, b, yaw)
                _raw, by_h, _st, _ratio = er.compare(ma, mb)
                close = by_h >= er.CONFUSABLE
                cells.append((overlay(ma, mb),
                              "yaw %d  scaled %.3f%s" % (
                                  yaw, by_h, "  >= 0.80" if close else ""),
                              FLAG if close else GOOD))
            rows.append(("%s  %s (blue) / %s (orange)" % (tag, a, b), cells))
    for role in RECUT:
        for tag, root in (("BEFORE", before), ("AFTER", after)):
            rows.append(("%s  %s at 18 m, native size x%d"
                         % (tag, role, NATIVE_ZOOM),
                         [(native(mask(root, role, yaw)), "yaw %d" % yaw, DIM)
                          for yaw in YAWS]))

    col_w = [max(r[1][i][0].size[0] for r in rows) for i in range(len(YAWS))]
    width = PAD + sum(w + PAD for w in col_w) + 200
    height = 70
    for _label, cells in rows:
        height += max(c[0].size[1] for c in cells) + 44
    sheet = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 12), "TIER 2 -- the two pairs Track B flagged, before and "
           "after the re-cut (same metric, same camera, 18 m)", fill=INK)
    d.text((PAD, 30), "grey: both roles cover it.  blue / orange: only one "
           "does -- the area the pair can be told apart by.  Flag at the "
           "0.80 scaled-overlap bar.", fill=DIM)
    y = 60
    for label, cells in rows:
        d.text((PAD, y), label, fill=INK)
        y += 16
        x = PAD
        tall = max(c[0].size[1] for c in cells)
        for i, (im, caption, colour) in enumerate(cells):
            sheet.paste(im, (x, y))
            d.text((x, y + tall + 4), caption, fill=colour)
            x += col_w[i] + PAD
        y += tall + 28
    sheet.save(out_path)
    print("tier2-sheet: %s (%d x %d)" % (out_path, width, height))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
