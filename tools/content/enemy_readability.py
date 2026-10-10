#!/usr/bin/env python3
"""Track B -- how far apart are the ten silhouettes, really?

    python3 tools/content/enemy_readability.py <dir with MASK_*.png>

`run_enemy_silhouettes.sh` renders each role's outline at the project's
own review distance, at native size. This measures how far apart those
outlines are, three ways, because "these look different" and "these are
different shapes" are not the same claim:

  raw         the masks as rendered, centred on a common canvas. This
              is what the player's eye gets, size included.
  scaled      each mask scaled to a common HEIGHT, aspect preserved. Two
              roles that are the same object at two sizes land on top of
              each other here and nowhere else.
  stretched   each mask stretched to a common BOX. Two roles that are
              the same shape at different PROPORTIONS land on top of
              each other here.

The third one is what `02` PT-10's complaint needs -- **artillery is a
wider version of another robot**, and a different width is not a
different silhouette -- and it is also the one that lies if you let it.

Squashed into the same square, almost any two solid outlines overlap:
the first run of this tool reported `bulwark / diver` as "the same
shape" at 0.888, and a flat disc is not the same shape as a tall box.
So `stretched` is only computed for pairs whose ASPECT RATIOS are
within `ASPECT_GATE` of each other. Beyond that the two outlines are
not the same thing at different proportions; they are different things,
and stretching them into a common box compares two blobs.

Roles are compared AT THE SAME YAW -- like for like -- and the score
reported is the worst (most similar) of the angles rendered. A pair
that is distinct head-on and identical in profile is still a pair the
player cannot tell apart.

Intersection over union throughout, on binary masks. 1.00 is "the same
outline"; 0.00 is "no overlap at all".
"""

import json
import os
import sys

from PIL import Image

#: Above this, two outlines are the same shape as far as this measure is
#: concerned. Not a threshold anybody has approved -- it is here to sort
#: the list and to make the report say WHICH pairs to look at, and the
#: numbers are printed so a reader can disagree with it.
CONFUSABLE = 0.80
#: How far two aspect ratios may differ before stretching them into one
#: box stops meaning anything. 2.0 is a judgement, printed with the
#: numbers so a reader can disagree with it.
ASPECT_GATE = 2.0
#: A common height for the normalised passes. Large enough that the
#: resampling is not the measurement, small enough to stay honest about
#: a 48 px subject.
NORM = 96


def mask_of(path):
    im = Image.open(path).convert("RGBA")
    return im.split()[3].point(lambda a: 255 if a > 127 else 0)


def iou(a, b):
    """Intersection over union of two equal-sized binary masks."""
    pa, pb = a.load(), b.load()
    inter = union = 0
    for y in range(a.size[1]):
        for x in range(a.size[0]):
            ia, ib = pa[x, y] > 0, pb[x, y] > 0
            if ia or ib:
                union += 1
                if ia and ib:
                    inter += 1
    return (inter / union) if union else 0.0


def on_canvas(mask, size):
    """The mask centred on a common canvas, unscaled."""
    out = Image.new("L", size, 0)
    out.paste(mask, ((size[0] - mask.size[0]) // 2,
                     (size[1] - mask.size[1]) // 2))
    return out


def scaled(mask, height):
    """Scaled to a common height, aspect preserved."""
    w = max(1, int(round(mask.size[0] * height / float(mask.size[1]))))
    return mask.resize((w, height), Image.NEAREST)


def load_masks(root):
    """{role: {yaw: mask}} from MASK_<role>_y<yaw>.png."""
    out = {}
    for f in sorted(os.listdir(root)):
        if not (f.startswith("MASK_") and f.endswith(".png")):
            continue
        stem = f[5:-4]
        if "_y" not in stem:
            continue
        role, yaw = stem.rsplit("_y", 1)
        out.setdefault(role, {})[int(yaw)] = mask_of(os.path.join(root, f))
    return out


def compare(a, b):
    """The three scores for one pair of masks at one yaw."""
    canvas = (max(a.size[0], b.size[0]) + 2, max(a.size[1], b.size[1]) + 2)
    raw = iou(on_canvas(a, canvas), on_canvas(b, canvas))
    sa, sb = scaled(a, NORM), scaled(b, NORM)
    fit = (max(sa.size[0], sb.size[0]) + 2, NORM + 2)
    by_h = iou(on_canvas(sa, fit), on_canvas(sb, fit))
    aspect_a = a.size[0] / float(a.size[1])
    aspect_b = b.size[0] / float(b.size[1])
    ratio = max(aspect_a, aspect_b) / max(1e-6, min(aspect_a, aspect_b))
    stretched = None
    if ratio <= ASPECT_GATE:
        stretched = iou(a.resize((NORM, NORM), Image.NEAREST),
                        b.resize((NORM, NORM), Image.NEAREST))
    return raw, by_h, stretched, ratio


def sheet(root, masks, names, yaws, zoom=4, pad=10):
    """One contact sheet of every outline, so the numbers can be argued
    with. Black on white at `zoom`x, native pixels preserved -- the
    resample is nearest and the shapes are not smoothed into agreeing
    with each other."""
    cells = {}
    wide = tall = 0
    for n in names:
        for y in yaws:
            m = masks[n][y]
            a = m.point(lambda v: 0 if v > 127 else 255)
            a = a.resize((a.size[0] * zoom, a.size[1] * zoom), Image.NEAREST)
            cells[(n, y)] = a
            wide = max(wide, a.size[0])
            tall = max(tall, a.size[1])
    cw, ch = wide + pad, tall + pad
    out = Image.new("L", (cw * len(yaws), ch * len(names)), 255)
    for i, n in enumerate(names):
        for j, y in enumerate(yaws):
            a = cells[(n, y)]
            out.paste(a, (j * cw + (cw - a.size[0]) // 2,
                          i * ch + (ch - a.size[1]) // 2))
    path = os.path.join(root, "SHEET_silhouettes.png")
    out.save(path)
    print("\n  contact sheet: %s (rows %s; columns yaw %s)"
          % (os.path.basename(path), ", ".join(names),
             "/".join(str(y) for y in yaws)))


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    masks = load_masks(root)
    names = sorted(masks)
    if len(names) < 2:
        print("enemy-readability: FAIL -- found %d role(s) in %s; there is "
              "nothing to compare" % (len(names), root), file=sys.stderr)
        return 1
    yaws = sorted(set.intersection(*(set(masks[n]) for n in names)))
    if not yaws:
        print("enemy-readability: FAIL -- the roles share no common yaw",
              file=sys.stderr)
        return 1

    rows = []
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            best = None
            for yaw in yaws:
                raw, by_h, stretched, ratio = compare(
                    masks[a][yaw], masks[b][yaw])
                cand = {"pair": [a, b], "yaw": yaw,
                        "raw": round(raw, 3), "scaled": round(by_h, 3),
                        "stretched": (None if stretched is None
                                      else round(stretched, 3)),
                        "aspect_ratio": round(ratio, 2)}
                # The WORST angle -- the one where they look most alike.
                if best is None or cand["scaled"] > best["scaled"]:
                    best = cand
            rows.append(best)

    print("enemy-readability: %d role(s), %d pair(s), yaws %s, at native "
          "size\n" % (len(names), len(rows), yaws))
    print("  %-22s %4s %6s %7s %10s %7s"
          % ("pair", "yaw", "raw", "scaled", "stretched", "aspect"))
    for r in sorted(rows, key=lambda r: -r["scaled"])[:10]:
        st = "  --  " if r["stretched"] is None else "%6.3f" % r["stretched"]
        flag = ""
        if r["scaled"] >= CONFUSABLE:
            flag = "  <- same outline"
            if r["stretched"] is not None and r["raw"] < CONFUSABLE:
                flag = "  <- same outline; size is what separates them"
        print("  %-22s %4d %6.3f %7.3f %10s %7.2f%s"
              % ("%s / %s" % tuple(r["pair"]), r["yaw"], r["raw"],
                 r["scaled"], st, r["aspect_ratio"], flag))

    close = [r for r in rows if r["scaled"] >= CONFUSABLE]
    gated = [r for r in rows if r["stretched"] is None]
    print("\n  %d of %d pair(s) share an outline at %.2f or above."
          % (len(close), len(rows), CONFUSABLE))
    for r in sorted(close, key=lambda r: -r["scaled"]):
        print("    %s / %s -- scaled %.3f at yaw %d, raw %.3f"
              % (r["pair"][0], r["pair"][1], r["scaled"], r["yaw"],
                 r["raw"]))
    print("  %d pair(s) were NOT stretch-compared: their aspect ratios "
          "differ by more than %.1fx, and squashing those into one box "
          "compares two blobs." % (len(gated), ASPECT_GATE))

    sheet(root, masks, names, yaws)

    out = os.path.join(root, "readability.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump({"threshold": CONFUSABLE, "aspect_gate": ASPECT_GATE,
                   "norm_px": NORM, "yaws": yaws,
                   "pairs": sorted(rows, key=lambda r: -r["scaled"])},
                  fh, indent=1, sort_keys=True)
        fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
