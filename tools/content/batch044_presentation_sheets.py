"""Batch 044's presentation pass, as sheets. DISPOSABLE. (Arty, 2026-10-17.)

    python3 batch044_presentation_sheets.py SHOTS WALK OUT

SHOTS/<variant>/<VIEW>.png are `furnished_view.gd`'s stamped previews,
one directory per variant; WALK/<variant>/route_walk.json is
`route_walk.gd`'s log for the same models. Writes one sheet per view (the
control and the seven variants, same camera), an overview of control
against all, and `batch044_presentation_numbers.json`.

The one number per frame is HOW MUCH OF THE VIEW CHANGED against the
control: the share of pixels whose grey moves by more than 24. It says how
loud a variant is from that spot. It does not say better; that is the
owner's eye.
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

VARIANTS = (
    ("control", "CONTROL - as built and committed"),
    ("skin", "1 SKIN - fills in trim plating"),
    ("base", "2 BASE - 0.30 m bund on the floor faces"),
    ("top", "3 TOP - head course, stepped back"),
    ("face", "4 FACE - desk, hatch, pipe heads"),
    ("board", "5 BOARD - gauge boards"),
    ("trunks", "6 TRUNKS - overhead lines"),
    ("all", "7 ALL - 1 to 6 together"),
)
VIEWS = (
    ("JUNCTION_TRIAD_1_the_approach", "TRIAD - the approach, 2 m in"),
    ("JUNCTION_TRIAD_2_the_decision_point",
     "TRIAD - the decision point, looking into the bay"),
    ("BAY_TERMINUS_1_one_neighbour_both_branches_sealed",
     "TERMINUS - from the door, both branches sealed"),
    ("BAY_TERMINUS_3_the_open_branch",
     "TERMINUS - the open branch, from the chamber"),
)
#: Rendered too, and in the package, but no sheet: the same camera as
#: TERMINUS_1 with one branch open, which the presentation parts do not
#: touch.
EXTRA = ("BAY_TERMINUS_2_same_view_one_branch_open",)
TILE = (640, 360)
THRESHOLD = 24


def _font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def changed(a, b):
    """Share of pixels whose grey moves by more than THRESHOLD."""
    ga, gb = a.convert("L"), b.convert("L")
    pa, pb = ga.load(), gb.load()
    w, h = ga.size
    n = sum(1 for y in range(0, h, 2) for x in range(0, w, 2)
            if abs(pa[x, y] - pb[x, y]) > THRESHOLD)
    return n / float(((w + 1) // 2) * ((h + 1) // 2))


def sheet(shots, view, title, numbers):
    font, small = _font(22), _font(16)
    band = 34
    cols, rows = 4, 2
    out = Image.new("RGB", (cols * TILE[0], 56 + rows * (TILE[1] + band)),
                    (22, 22, 24))
    draw = ImageDraw.Draw(out)
    draw.text((14, 14), title + "   (same camera; one variable per tile)",
              fill=(240, 240, 240), font=font)
    for i, (key, label) in enumerate(VARIANTS):
        img = Image.open(os.path.join(shots, key, view + ".png"))
        x = (i % cols) * TILE[0]
        y = 56 + (i // cols) * (TILE[1] + band)
        out.paste(img.convert("RGB").resize(TILE, Image.LANCZOS), (x, y))
        share = numbers[view].get(key)
        tag = "" if key == "control" else "   view changed %.1f%%" % (
            share * 100.0)
        colour = (255, 214, 102) if key == "control" else (230, 230, 230)
        draw.rectangle([x, y + TILE[1], x + TILE[0] - 1,
                        y + TILE[1] + band - 1], fill=(36, 36, 40))
        draw.text((x + 10, y + TILE[1] + 8), label + tag, fill=colour,
                  font=small)
        if key == "control":
            draw.rectangle([x, y, x + TILE[0] - 1, y + TILE[1] - 1],
                           outline=(255, 214, 102), width=3)
    return out


def overview(shots):
    font, small = _font(22), _font(16)
    band = 30
    out = Image.new("RGB", (2 * TILE[0], 56 + len(VIEWS) * (TILE[1] + band)),
                    (22, 22, 24))
    draw = ImageDraw.Draw(out)
    draw.text((14, 14), "Batch 044 presentation pass - CONTROL (left) vs ALL "
              "(right)", fill=(240, 240, 240), font=font)
    for r, (view, title) in enumerate(VIEWS):
        y = 56 + r * (TILE[1] + band)
        for c, key in enumerate(("control", "all")):
            img = Image.open(os.path.join(shots, key, view + ".png"))
            out.paste(img.convert("RGB").resize(TILE, Image.LANCZOS),
                      (c * TILE[0], y))
            draw.rectangle([c * TILE[0], y + TILE[1],
                            (c + 1) * TILE[0] - 1, y + TILE[1] + band - 1],
                           fill=(36, 36, 40))
            draw.text((c * TILE[0] + 10, y + TILE[1] + 6),
                      "%s - %s" % (title, key.upper()),
                      fill=(255, 214, 102) if key == "control"
                      else (230, 230, 230), font=small)
    return out


def main(shots, walk, out):
    os.makedirs(out, exist_ok=True)
    numbers = {}
    for view, _ in VIEWS + tuple((e, "") for e in EXTRA):
        base = Image.open(os.path.join(shots, "control", view + ".png"))
        numbers[view] = {key: round(changed(
            base, Image.open(os.path.join(shots, key, view + ".png"))), 4)
            for key, _ in VARIANTS}
    walks = {}
    for key, _ in VARIANTS:
        with open(os.path.join(walk, key, "route_walk.json"),
                  encoding="utf-8") as handle:
            log = json.load(handle)
        walks[key] = {route: {"completed": got.get("completed"),
                              "jumps": got.get("jumps")}
                      for route, got in log.items()
                      if route.startswith(("triad", "terminus"))}
    for i, (view, title) in enumerate(VIEWS):
        sheet(shots, view, title, numbers).save(
            os.path.join(out, "B44_%d_%s.jpg" % (i + 1, view.lower())),
            quality=92, subsampling=0)
    overview(shots).save(os.path.join(out, "B44_0_overview.jpg"),
                         quality=92, subsampling=0)
    with open(os.path.join(out, "batch044_presentation_numbers.json"), "w",
              encoding="utf-8") as handle:
        json.dump({"view_changed_share": numbers, "route_walk": walks,
                   "threshold_grey": THRESHOLD}, handle, indent=1,
                  sort_keys=True)
    for view, _ in VIEWS:
        print("[b44] %-52s %s" % (view, "  ".join(
            "%s %.1f%%" % (k, numbers[view][k] * 100) for k, _ in VARIANTS
            if k != "control")))
    bad = [(k, r) for k, rs in walks.items() for r, g in rs.items()
           if not g["completed"] or g["jumps"]]
    print("[b44] route walk: %s" % ("every route completes, no jumps"
                                    if not bad else "PROBLEMS %s" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
