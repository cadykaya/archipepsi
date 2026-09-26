#!/usr/bin/env python3
"""Crop a region of a render and magnify it with NEAREST, no smoothing.

    python3 tools/pixel_inset.py <in.png> <out.png> <cx> <cy> <w> <h> <scale>

A distance shot answers "is it 30 px" with 30 px, which on a review sheet
scrolled past on a phone is a smudge. This shows the SAME pixels the player
gets, six times bigger, with no filtering between them -- so the question
being answered is still "does this read at 30 px" and not "does this read
when resampled".

NEAREST is not a nicety here. Any other filter invents intermediate values
and makes a shape look smoother than the frame the player will see, which
is the one way a magnified inset can lie.
"""
import sys

from PIL import Image


def main(argv):
    if len(argv) != 8:
        print(__doc__.strip())
        return 2
    src, dst = argv[1], argv[2]
    cx, cy, w, h, scale = (int(v) for v in argv[3:8])
    im = Image.open(src).convert("RGB")
    box = (cx - w // 2, cy - h // 2, cx - w // 2 + w, cy - h // 2 + h)
    crop = im.crop(box)
    out = crop.resize((w * scale, h * scale), Image.NEAREST)
    # A one-pixel rule around it, so nobody mistakes the inset for the shot.
    edge = Image.new("RGB", (out.width + 2, out.height + 2), (255, 212, 92))
    edge.paste(out, (1, 1))
    edge.save(dst)
    print("[inset] %s %dx%d from (%d,%d) x%d -> %s"
          % (src.rsplit("/", 1)[-1], w, h, cx, cy, scale, dst))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
