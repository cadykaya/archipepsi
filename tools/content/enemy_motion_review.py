#!/usr/bin/env python3
"""The motion-readability review of the ten-role enemy family.

    ENEMY_SIL_YAWS="$(seq -s, 0 15 345)" \\
        tools/content/run_enemy_silhouettes.sh <out>/turn
    python3 tools/content/enemy_motion_review.py <out> <production rev>

RULED 2026-09-26: after Tier 2, *"perform the planned motion-readability
review"*. Track B measured ten static poses at three yaws and said so;
this is the pass it deferred.

The art lane's enemies are rigid meshes. Every motion they will ever have
is a transform Production gives them, so this reviews exactly those, read
from Production's own source at <production rev>:

1. **The turn.** `Enemy._face` snaps every role but the bulwark to the
   player, and a patrol walks with `look_at` its heading, so an enemy is
   seen at every yaw, not three. Track B's scaled overlap is re-measured
   at every 15 degrees, same yaw (Track B's definition), and once across
   yaws: role A at any yaw against role B at any other. The second is the
   stricter question a player asks of one enemy, seen once.
2. **What moves.** Speed, standoff, turn, telegraph and job per role,
   from `ENEMY_STATS`, `TELEGRAPH_SECONDS`, `BULWARK_TURN_RATE_DEG_S` and
   `ENEMY_JOBS`.
3. **The windup and the flinch.** The engine's fallback telegraph scales
   `Visual` by 1 + a*sin(2*pi*t/T), and a hit punches it to f. A walker's
   `Visual` stands on the floor and a flyer's at its own middle, so each
   grows about that point. The script counts how many pixels of outline
   that moves at the review distance.
4. **The openings.** A body moving over a background changes each pixel it
   enters or leaves by exactly body-minus-background, which is the static
   separation. So motion adds no value contrast. All it adds is the rate
   at which pixels change, and for an enemy walking straight at the
   player that rate is the looming rate.

Every Production number is parsed from its source, and a missing one
fails the run. This script draws and tabulates; the owner decides.
"""

import json
import math
import os
import re
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import enemy_readability as er  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONTRAST = os.path.join(ROOT, "docs", "art", "review", "enemies_2026-09-25",
                        "contrast_current", "contrast.json")
FPS = 60.0
BG = (16, 20, 24)
INK = (224, 232, 238)
DIM = (140, 150, 160)
BAR = (255, 96, 80)
GROW = (240, 150, 40)
SHRINK = (70, 140, 230)
LINES = [(240, 150, 40), (70, 140, 230), (120, 220, 140), (220, 120, 220),
         (230, 220, 90), (120, 200, 230)]


def _need(match, what):
    if match is None:
        sys.exit("motion-review: FAIL -- %s not found in Production's "
                 "source; the review would be reading a guess" % what)
    return match


def production(rev):
    """Every Production number this review uses, parsed from `rev`."""
    def show(path):
        return subprocess.run(["git", "show", "%s:%s" % (rev, path)],
                              capture_output=True, text=True, check=True,
                              cwd=ROOT).stdout
    c = show("godot/scripts/autoload/constants.gd")
    e = show("godot/scripts/enemies/enemy.gd")
    stats = json.loads(re.sub(r",\s*\}", "}", _need(re.search(
        r"const ENEMY_STATS = (\{.*?\n\})", c, re.S), "ENEMY_STATS").group(1)))
    out = {
        "rev": rev,
        "stats": stats,
        "archetypes": json.loads(_need(re.search(
            r"const ENEMY_ARCHETYPES = (\[.*?\])", c),
            "ENEMY_ARCHETYPES").group(1)),
        "jobs": json.loads(_need(re.search(
            r"const ENEMY_JOBS = (\{.*?\})\n", c), "ENEMY_JOBS").group(1)),
        "job_speed": float(_need(re.search(
            r"const ENEMY_JOB_SPEED = ([\d.]+)", c),
            "ENEMY_JOB_SPEED").group(1)),
        "bulwark_turn_deg_s": float(_need(re.search(
            r"const BULWARK_TURN_RATE_DEG_S = ([\d.]+)", c),
            "BULWARK_TURN_RATE_DEG_S").group(1)),
        "dive_seconds": float(_need(re.search(
            r"const DIVER_DIVE_SECONDS = ([\d.]+)", c),
            "DIVER_DIVE_SECONDS").group(1)),
        "dive_contact": float(_need(re.search(
            r"const DIVE_CONTACT := ([\d.]+)", e), "DIVE_CONTACT").group(1)),
        "swell": float(_need(re.search(
            r"_set_visual_scale\(1\.0 \+ ([\d.]+) \* sin", e),
            "the windup swell").group(1)),
        "flinch": float(_need(re.search(
            r"visual\.scale = Vector3\.ONE \* ([\d.]+)", e),
            "the hit flinch").group(1)),
    }
    block = _need(re.search(r"const TELEGRAPH_SECONDS := \{(.*?)\n\}", e,
                            re.S), "TELEGRAPH_SECONDS").group(1)
    out["telegraph_s"] = {m.group(1): float(m.group(2)) for m in re.finditer(
        r'^\s*"(\w+)": ([\d.]+),?\s*$', block, re.M)}
    out["envelopes"] = {m.group(1): {
        "bottom_y": float(m.group(2)), "top_y": float(m.group(3)),
        "flying": m.group(4) == "true"} for m in re.finditer(
        r'"(\w+)": \{"size": Vector3\([^)]*\), "centre_y": [\d.]+, '
        r'"bottom_y": ([\d.]+), "top_y": ([\d.]+),.*?"flying": (true|false)\}',
        c)}
    if len(out["envelopes"]) != 10 or len(out["stats"]) != 10:
        sys.exit("motion-review: FAIL -- expected ten roles in "
                 "ENEMY_ENVELOPES and ENEMY_STATS at %s" % rev)
    # `_face`: only the bulwark has a turn rate; everything else snaps.
    _need(re.search(r'if archetype != "bulwark":\s*\n\s*rotation\.y = wanted',
                    e), "the snap-facing rule in _face")
    return out


def standoff(role, p):
    """`Enemy._standoff()`: where the approach stops."""
    s = p["stats"][role]
    if role == "diver":
        return (s["speed"] * p["dive_seconds"] + p["dive_contact"]) * 0.7
    return s["reach"] * 0.8


def _canvas(m):
    """A mask on the metric's common-height canvas, as a 1-bit image."""
    return er.scaled(m, er.NORM).convert("1")


def _iou(a, b):
    w = max(a.size[0], b.size[0]) + 2
    ca = Image.new("1", (w, er.NORM + 2), 0)
    ca.paste(a, ((w - a.size[0]) // 2, 1))
    cb = Image.new("1", (w, er.NORM + 2), 0)
    cb.paste(b, ((w - b.size[0]) // 2, 1))
    inter = ImageChops.logical_and(ca, cb).histogram()[255]
    union = ImageChops.logical_or(ca, cb).histogram()[255]
    return inter / union if union else 0.0


def turn(masks):
    names = sorted(masks)
    yaws = sorted(set.intersection(*(set(masks[n]) for n in names)))
    sc = {(n, y): _canvas(masks[n][y]) for n in names for y in yaws}
    # The fast overlap must BE the metric's: checked on one pair.
    ref = er.compare(masks[names[0]][yaws[0]], masks[names[1]][yaws[0]])[1]
    got = _iou(sc[(names[0], yaws[0])], sc[(names[1], yaws[0])])
    if abs(ref - got) > 1e-9:
        sys.exit("motion-review: FAIL -- the overlap here (%.4f) is not "
                 "enemy_readability's (%.4f)" % (got, ref))
    same, cross = {}, {}
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            key = "%s/%s" % (a, b)
            same[key] = {y: round(_iou(sc[(a, y)], sc[(b, y)]), 3)
                         for y in yaws}
            best = (0.0, 0, 0)
            for ya in yaws:
                for yb in yaws:
                    v = _iou(sc[(a, ya)], sc[(b, yb)])
                    if v > best[0]:
                        best = (v, ya, yb)
            cross[key] = {"scaled": round(best[0], 3), a: best[1],
                          b: best[2]}
    return yaws, same, cross


def _outline(m, s, pivot, fit):
    """The outline at scale `s` about its floor or its middle.

    Every scale of one role is drawn on ONE canvas, sized for the largest
    (`fit`), so rest, peak, trough and flinch line up pixel for pixel.
    """
    w, h = m.size
    W, H = int(math.ceil(w * fit)) + 4, int(math.ceil(h * fit)) + 4
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    grown = m if (nw, nh) == (w, h) else m.resize((nw, nh), Image.NEAREST)
    out = Image.new("L", (W, H), 0)
    if pivot == "floor":       # a walker's Visual stands on the floor
        out.paste(grown, ((W - nw) // 2, H - 2 - nh))
    else:                      # a flyer's Visual sits at its middle
        out.paste(grown, ((W - nw) // 2, (H - nh) // 2))
    return out


def _changed(rest, moved):
    return ImageChops.logical_xor(rest.convert("1"),
                                  moved.convert("1")).histogram()[255]


def motion_table(p, masks, px_per_m, distance):
    rows = {}
    for role in sorted(p["stats"]):
        s = p["stats"][role]
        env = p["envelopes"][role]
        m = masks[role][0]
        pivot = "middle" if env["flying"] else "floor"
        fit = 1.0 + p["swell"]
        rest = _outline(m, 1.0, pivot, fit)
        peak = _outline(m, 1.0 + p["swell"], pivot, fit)
        trough = _outline(m, 1.0 - p["swell"], pivot, fit)
        hit = _outline(m, p["flinch"], pivot, fit)
        speed = float(s["speed"])
        rows[role] = {
            "placeable": role in p["archetypes"],
            "speed_m_s": speed,
            "standoff_m": round(standoff(role, p), 2),
            "turn": ("%.0f deg/s, none while committed"
                     % p["bulwark_turn_deg_s"]) if role == "bulwark"
                    else "snaps to the player",
            "telegraph_s": p["telegraph_s"].get(role),
            "job": p["jobs"].get(role),
            "job_speed_m_s": round(speed * p["job_speed"], 2),
            "flying": env["flying"],
            "height_band_m": [env["bottom_y"], env["top_y"]],
            "px_h_at_review": m.size[1],
            "swell_changed_px": (_changed(rest, peak)
                                 if role in p["telegraph_s"] else None),
            "swell_top_moves_px": (round(p["swell"] * m.size[1]
                                         * (1.0 if pivot == "floor"
                                            else 0.5), 1)
                                   if role in p["telegraph_s"] else None),
            "flinch_changed_px": _changed(rest, hit),
            "lateral_px_per_frame": round(speed * px_per_m / FPS, 2),
            "approach_px_per_frame": round(m.size[1] * speed / distance
                                           / FPS, 2),
        }
        rows[role]["_frames"] = (rest, peak, trough)
    return rows


def _band_apart(a, b, p):
    ea, eb = p["envelopes"][a], p["envelopes"][b]
    return ea["top_y"] <= eb["bottom_y"] or eb["top_y"] <= ea["bottom_y"]


def chart(path, yaws, same, cross, p, top=6):
    keys = sorted(same, key=lambda k: -max(same[k].values()))[:top]
    W, H, L, T, B = 980, 520, 70, 70, 60
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 12), "THE FULL TURN -- scaled outline overlap, same yaw, "
           "every 15 degrees (the %d closest pairs)" % top, fill=INK)
    d.text((16, 30), "Track B measured 0 / 45 / 90 only. The bar is "
           "0.80.  x: yaw of both roles  y: overlap", fill=DIM)
    lo, hi = 0.3, 0.9
    def xy(yaw, v):
        x = L + (W - L - 30) * yaw / 360.0
        y = T + (H - T - B) * (hi - v) / (hi - lo)
        return x, y
    for v in (0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9):
        x0, y0 = xy(0, v)
        x1, _ = xy(360, v)
        d.line((x0, y0, x1, y0), fill=BAR if v == 0.8 else (44, 50, 58),
               width=2 if v == 0.8 else 1)
        d.text((L - 40, y0 - 6), "%.1f" % v, fill=DIM)
    for yaw in range(0, 361, 45):
        x, y = xy(yaw, lo)
        d.text((x - 8, y + 8), "%d" % yaw, fill=DIM)
    for i, k in enumerate(keys):
        col = LINES[i % len(LINES)]
        pts = [xy(y, same[k][y]) for y in yaws] + [xy(360, same[k][yaws[0]])]
        d.line(pts, fill=col, width=2)
        for x, y in pts[:-1]:
            d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=col)
        a, b = k.split("/")
        worst = max(same[k], key=same[k].get)
        note = "  floor / air" if _band_apart(a, b, p) else ""
        d.text((L + 10 + (i % 3) * 300, H - B + 22 + (i // 3) * 16),
               "%s  max %.3f at %d%s" % (k, same[k][worst], worst, note),
               fill=col)
    img.save(path)


def turn_sheet(path, masks, yaws, zoom=2, pad=6):
    names = sorted(masks)
    cw = max(masks[n][y].size[0] for n in names for y in yaws) * zoom + pad
    rh = [max(masks[n][y].size[1] for y in yaws) * zoom + pad
          for n in names]
    W = 90 + cw * len(yaws)
    H = 40 + sum(rh)
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((10, 10), "THE FULL TURN at 18 m, native size x%d -- rows are "
           "roles, columns are yaw 0..345 in 15-degree steps" % zoom,
           fill=INK)
    y0 = 30
    for n, h in zip(names, rh):
        d.text((8, y0 + h // 2 - 6), n, fill=DIM)
        for j, yaw in enumerate(yaws):
            m = masks[n][yaw]
            cell = Image.new("RGB", m.size, BG)
            cell.paste(INK, mask=m)
            cell = cell.resize((m.size[0] * zoom, m.size[1] * zoom),
                               Image.NEAREST)
            img.paste(cell, (90 + j * cw, y0 + h - pad - cell.size[1]))
        y0 += h
    img.save(path)


def swell_sheet(path, rows, p, zoom=4):
    roles = [r for r in sorted(rows) if rows[r]["telegraph_s"]]
    cells = []
    for r in roles:
        rest, peak, trough = rows[r]["_frames"]
        tiles = []
        for moved in (peak, trough):
            t = Image.new("RGB", rest.size, BG)
            both = ImageChops.logical_and(rest.convert("1"), moved.convert("1"))
            grow = ImageChops.subtract(moved, rest)
            shrink = ImageChops.subtract(rest, moved)
            t.paste(INK, mask=both.convert("L"))
            t.paste(GROW, mask=grow)
            t.paste(SHRINK, mask=shrink)
            tiles.append(t.resize((t.size[0] * zoom, t.size[1] * zoom),
                                  Image.NEAREST))
        cells.append((r, tiles))
    cw = max(t.size[0] for _, ts in cells for t in ts) + 16
    ch = max(t.size[1] for _, ts in cells for t in ts) + 40
    W = 16 + cw * 2 * min(3, len(cells))
    H = 60 + ch * math.ceil(len(cells) / 3.0)
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 12), "THE WINDUP SWELL at 18 m, native size x%d -- "
           "Production's fallback telegraph, 1 + %.2f sin, on the art "
           "models" % (zoom, p["swell"]), fill=INK)
    d.text((16, 30), "left: peak (+%d%%)  right: trough (-%d%%).  "
           "white: outline both times  orange: gained  blue: lost"
           % (round(p["swell"] * 100), round(p["swell"] * 100)), fill=DIM)
    for i, (r, tiles) in enumerate(cells):
        x = 16 + (i % 3) * cw * 2
        y = 56 + (i // 3) * ch
        for j, t in enumerate(tiles):
            img.paste(t, (x + j * cw, y))
        row = rows[r]
        d.text((x, y + ch - 34), "%s  %.2f s  top moves %.1f px  %d px "
               "change" % (r, row["telegraph_s"], row["swell_top_moves_px"],
                           row["swell_changed_px"]), fill=INK)
    img.save(path)


def main(out, rev):
    turn_dir = os.path.join(out, "turn")
    masks = er.load_masks(turn_dir)
    if len(masks) != 10:
        sys.exit("motion-review: FAIL -- %d role(s) in %s; render the full "
                 "turn first (see the docstring)" % (len(masks), turn_dir))
    sil = json.load(open(os.path.join(turn_dir, "silhouettes.json")))
    meta = sil["_meta"]
    distance = float(meta["distance_m"])
    # The harness's own scale: Godot's fov is vertical, so a metre at
    # the review distance is shot height / (2 d tan(fov / 2)) pixels.
    px_per_m = float(meta["shot"][1]) / (
        2.0 * distance * math.tan(math.radians(float(meta["fov_deg"])) / 2.0))
    p = production(rev)
    yaws, same, cross = turn(masks)
    rows = motion_table(p, masks, px_per_m, distance)
    contrast = json.load(open(CONTRAST))
    openings = {room: contrast[room]["opening"]["separation"]
                for room in sorted(k for k in contrast
                                   if not k.startswith("_"))}

    worst_same = {k: max(v, key=v.get) for k, v in same.items()}
    over_same = sorted(((k, worst_same[k], same[k][worst_same[k]])
                        for k in same if same[k][worst_same[k]]
                        >= er.CONFUSABLE), key=lambda t: -t[2])
    over_cross = sorted(((k, v) for k, v in cross.items()
                         if v["scaled"] >= er.CONFUSABLE),
                        key=lambda t: -t[1]["scaled"])
    report = {
        "_meta": {"production_rev": rev, "distance_m": distance,
                  "px_per_metre": px_per_m, "fps_assumed": FPS,
                  "yaws": yaws, "bar": er.CONFUSABLE,
                  "swell": p["swell"], "flinch": p["flinch"],
                  "bulwark_turn_deg_s": p["bulwark_turn_deg_s"]},
        "turn_same_yaw": same,
        "turn_same_yaw_worst": {k: {"yaw": worst_same[k],
                                    "scaled": same[k][worst_same[k]]}
                                for k in same},
        "turn_cross_yaw_worst": cross,
        "over_bar_same_yaw": [{"pair": k, "yaw": y, "scaled": v,
                               "floor_vs_air": _band_apart(
                                   *k.split("/"), p)}
                              for k, y, v in over_same],
        "over_bar_cross_yaw": [dict(v, pair=k, floor_vs_air=_band_apart(
                                   *k.split("/"), p))
                               for k, v in over_cross],
        "motion": {r: {k: v for k, v in row.items() if not k.startswith("_")}
                   for r, row in rows.items()},
        "openings_separation": openings,
    }
    with open(os.path.join(out, "motion.json"), "w") as f:
        json.dump(report, f, indent=2, sort_keys=True)
        f.write("\n")
    chart(os.path.join(out, "CHART_turn_overlap.png"), yaws, same, cross, p)
    turn_sheet(os.path.join(out, "SHEET_turn.png"), masks, yaws)
    swell_sheet(os.path.join(out, "SHEET_telegraph_swell.png"), rows, p)

    print("motion-review: Production %s, %d yaws, %.0f px/m at %.0f m"
          % (rev, len(yaws), px_per_m, distance))
    print("  same yaw, at or over %.2f anywhere in the turn: %s"
          % (er.CONFUSABLE, ", ".join("%s %.3f@%d" % (k, v, y)
                                      for k, y, v in over_same) or "none"))
    print("  across yaws, at or over %.2f: %s" % (er.CONFUSABLE, ", ".join(
        "%s %.3f" % (k, v["scaled"]) for k, v in over_cross) or "none"))
    for k in ("melee/ranged", "brute/bulwark"):
        print("  Tier 2 %-14s worst %.3f at %d over the turn"
              % (k, same[k][worst_same[k]], worst_same[k]))
    print("  %-10s %5s %7s %6s %9s %6s %6s %6s" % (
        "role", "m/s", "stand", "tele", "job", "swell", "flinch", "loom"))
    for r, row in sorted(rows.items()):
        print("  %-10s %5.1f %7.1f %6s %9s %6s %6d %6.2f" % (
            r, row["speed_m_s"], row["standoff_m"],
            "-" if row["telegraph_s"] is None else "%.2f" % row["telegraph_s"],
            row["job"], "-" if row["swell_changed_px"] is None
            else row["swell_changed_px"], row["flinch_changed_px"],
            row["approach_px_per_frame"]))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(*sys.argv[1:]))
