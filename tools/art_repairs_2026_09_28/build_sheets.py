#!/usr/bin/env python3
"""Repair 2026-09-28 -- the four evidence sheets.

    tools/art_repairs_2026_09_28/run_pose_views.sh <frames>/pose
    tools/art_repairs_2026_09_28/run_tint_views.sh <frames>/tint
    python3 tools/art_repairs_2026_09_28/build_sheets.py <frames> <out-dir>

Composes the before/after frames into phone-width sheets with the owner
review's own sheet builder, and draws the danger-mark plan to scale from
Production's constants at the pinned revision (read with `git show`) and
the marks' own manifest. No number on the plan is typed here.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools", "owner_review_2026_09_28"))
import sheets  # noqa: E402
from sheets import Panel, Sheet  # noqa: E402

PIN = "c12a72fbc62500f4815d683d66a97f47fe514b06"
sheets.TAGS.update({
    "REST": ((92, 96, 104), "AS BUILT · identical in both files at rest"),
    "BEFORE": ((128, 52, 52), "BEFORE · reviewed file a1584c8"),
    "AFTER": ((46, 125, 84), "AFTER · repaired file, this branch"),
})
FOOT = ("Review renders through Godot's own GLTFDocument importer, one rig "
        "per sheet. Magenta and green are REVIEW TINTS, never a colour "
        "proposal. Arty, 2026-09-28.")
UNCHANGED = dict(
    visual=("pending", "PENDING, unchanged. A technical repair approves "
                       "nothing."),
    binding=("none", "None. Nothing loads these models."),
    play=("no", "No."))


def s049(frames, out):
    s = Sheet("049 · the six moving parts turn on real hinges",
              "Before: each part's own node turned to the declared angle, "
              "the only thing the reviewed file allowed, so it swung "
              "about the foot of its mount. After: the hinge node turned "
              "by the same angle.")
    s.statuses(compat=("partial", "Hinges and declared positions in the "
                                  "manifest. No colliders; no driver."),
               **UNCHANGED)
    rows = [
        ("conn_hold_paddle", "Paddle · held 22°",
         "Measured: the last whole degree before it bears on its own "
         "spring.", "the pin travelled 0.275 m"),
        ("conn_repair_seal", "Seal lever · thrown 90°",
         "Declared: pulled straight out; the tab halves hide.",
         "the pin travelled 0.179 m"),
        ("conn_breaker", "Breaker · thrown 30°",
         "Declared: tipped down, stopping clear of its window.",
         "the pin travelled 0.197 m"),
        ("conn_flag_ack", "Flag · up 90°",
         "Declared: down as built, up vertical.",
         "the pin travelled 0.880 m"),
        ("conn_set_dial", "Dial · detent 3, +45°",
         "Measured: eight positions, one per tooth.",
         "the pin travelled 0.130 m"),
        ("conn_gauge", "Gauge · full, −90°",
         "Declared: a half-dial sweep, empty at 9 o'clock.",
         "the pin travelled 0.212 m"),
    ]
    for asset, title, how, travel in rows:
        s.row([Panel("%s/pose/%s_0_rest.png" % (frames, asset),
                     title.split(" · ")[0], tag="REST"),
               Panel("%s/pose/%s_1_old.png" % (frames, asset),
                     "Turned about the asset origin", tag="BEFORE",
                     note=travel),
               Panel("%s/pose/%s_2_new.png" % (frames, asset),
                     title, tag="AFTER", note=how)])
    s.footer(FOOT + " Verified by verify_049_hinges.py: rest geometry, UVs "
             "and materials identical to a1584c8, node for node.")
    return s.save(os.path.join(out, "1_049_hinges.jpg"))


def s_skiff(frames, out):
    s = Sheet("The skiff · fore is the end that goes first",
              "The white arrow is RailCarrier's FORWARD, the node's +Z "
              "(rail_carrier.gd:420 at c12a72f). Green tints every node "
              "NAMED *_fore and magenta every node named *_aft: the lamp, "
              "end plate, band, cap and posts.")
    s.statuses(compat=("yes", "Names now agree with the pinned runtime "
                              "frame. The geometry is identical; only "
                              "names moved."), **UNCHANGED)
    s.row([Panel("%s/tint/skiff_old.png" % frames,
                 "a1584c8: `lamp_fore` trails", tag="BEFORE"),
           Panel("%s/tint/skiff_new.png" % frames,
                 "Repaired: `lamp_fore` leads", tag="AFTER")])
    s.text("", "sp_skiff_deck_bare is the same hull and is repaired the "
               "same way. verify_skiff_fore.py reads the pinned line and "
               "the exported files, and fails on the old ones.")
    s.footer(FOOT)
    return s.save(os.path.join(out, "2_skiff_fore.jpg"))


def s_panels(frames, out):
    s = Sheet("Lightened panels · their own material, clear of the fittings",
              "Before: the panels wore the grip material and sat on or "
              "under a fitting. After: they wear `<asset>_lightened` "
              "(#4a5058 at rest) and moved the shortest clear distance. "
              "Shown as exported, no tint.")
    s.statuses(compat=("yes", "Addressable: one slot per panel node. No "
                              "size, fitting, mass or class changed."),
               **UNCHANGED)
    rows = [
        ("generic", "Generic crate", "Dropped 0.07 m below the hand grip."),
        ("ballast", "Ballast", "Slid 0.30 m along its face, off the pad."),
        ("mechanical_part", "Mechanical part",
         "The keyed face has no room; the panel turned onto the side."),
        ("movable_cover", "Movable cover",
         "Hung 5.5 cm off the face on the push pad; now seated above "
         "the rib."),
        ("weighted", "Weighted block",
         "Both faces are pads; the panels turned onto the free sides."),
    ]
    for key, name, moved in rows:
        s.row([Panel("%s/tint/%s_old.png" % (frames, key), name,
                     tag="BEFORE"),
               Panel("%s/tint/%s_new.png" % (frames, key), name,
                     tag="AFTER", note=moved)])
    s.footer(FOOT + " Verified by verify_053_panels.py. Thirteen panels "
             "were already clear; they keep their place and only change "
             "material.")
    return s.save(os.path.join(out, "3_lightened_panels.jpg"))


def _pinned(path):
    return subprocess.run(["git", "show", "%s:%s" % (PIN, path)], cwd=ROOT,
                          check=True, capture_output=True, text=True).stdout


def s_danger(frames, out):
    consts = _pinned("godot/scripts/autoload/constants.gd")
    enemy = _pinned("godot/scripts/enemies/enemy.gd")

    def const(name):
        return float(re.search(r"^const %s = ([0-9.]+)" % name, consts,
                               re.M).group(1))

    def reach(role):
        return float(re.search(r'"%s": \{[^}]*"reach": ([0-9.]+)' % role,
                               consts).group(1))

    hit = float(re.search(r'stats\["reach"\]\) \* ([0-9.]+):', enemy)
                .group(1))
    travel = const("CHARGER_RUSH_SPEED") * const("CHARGER_RUSH_SECONDS")
    radius = reach("charger") * hit
    blast = const("ARTILLERY_BLAST_RADIUS")
    aura = const("BEACON_RADIUS")
    with open(os.path.join(ROOT, "assets/models/batch051/combatfx/"
                                 "manifest.json"), encoding="utf-8") as h:
        fx = json.load(h)
    lane = fx["fx_charger_lane"]["size"]
    warned = fx["fx_warned_ground"]["size"][0] / 2.0
    ring = max(fx["fx_beacon_range"]["size"][:2]) / 2.0

    ppm = 17.0
    W, H = 1344, 640
    img = Image.new("RGB", (W, H), (24, 26, 30))
    d = ImageDraw.Draw(img)
    f = sheets.F_SMALL
    true_col, art_col, ink = (236, 238, 240), (120, 170, 220), (170, 176, 184)

    def dashed_circle(cx, cy, r):
        for a in range(0, 360, 6):
            d.arc([cx - r, cy - r, cx + r, cy + r], a, a + 3, fill=true_col,
                  width=3)

    # 1. The charger: the stadium its hit reaches, and the art lane.
    cx, top = 150, 60
    L, r = travel * ppm, radius * ppm
    d.rounded_rectangle([cx - r, top, cx + r, top + L + 2 * r], int(r),
                        outline=true_col, width=3)
    d.rectangle([cx - lane[0] * ppm / 2, top + r, cx + lane[0] * ppm / 2,
                 top + r + lane[1] * ppm], fill=art_col)
    d.ellipse([cx - 6, top + r - 6, cx + 6, top + r + 6], fill=(255, 216, 77))
    d.text((cx - 130, top + L + 2 * r + 12),
           "CHARGER · hit within %.1f m of\na %.1f m rush: %.1f × %.1f m\n"
           "art lane %.1f × %.1f m" % (radius, travel, 2 * radius,
                                       travel + 2 * radius, lane[0], lane[1]),
           fill=ink, font=f)
    # 2. The artillery: the blast and the art ring.
    ax, ay = 470, 250
    d.ellipse([ax - blast * ppm, ay - blast * ppm, ax + blast * ppm,
               ay + blast * ppm], outline=true_col, width=3)
    d.ellipse([ax - warned * ppm, ay - warned * ppm, ax + warned * ppm,
               ay + warned * ppm], fill=art_col)
    d.text((ax - 150, ay + blast * ppm + 16),
           "ARTILLERY · blast r %.1f m\n(the runtime already draws this disc)"
           "\nart ring r %.1f m" % (blast, warned), fill=ink, font=f)
    # 3. The beacon: an ally aura, not player damage.
    bx, by = 1010, 270
    dashed_circle(bx, by, aura * ppm)
    d.ellipse([bx - ring * ppm, by - ring * ppm, bx + ring * ppm,
               by + ring * ppm], fill=art_col)
    d.text((bx - 185, by + aura * ppm + 14),
           "BEACON · r %.0f m: ENEMIES inside hit\nharder. Not damage to "
           "the player.\nart ring r %.1f m" % (aura, ring), fill=ink, font=f)
    d.text((24, H - 34), "1 m = %d px. White: the runtime's reach at "
           "c12a72f. Blue: the candidate art mark. Yellow dot: the "
           "charger at the start of its rush." % ppm, fill=ink, font=f)
    plan = os.path.join(frames, "danger_plan.png")
    img.save(plan)

    s = Sheet("Danger marks · the runtime's real reach, to scale",
              "The geometry a boundary mark would have to match, read from "
              "Production at c12a72f. No presentation is chosen here, and "
              "no mark was rebuilt.")
    s.statuses(visual=("pending", "PENDING. Presentation is the owner's "
                                  "call."),
               compat=("no", "Undersized for a boundary; the charger lane "
                             "is also too narrow."),
               binding=("none", "None; the seam would be telegraph_started "
                                "and telegraph_finished."),
               play=("no", "No. The runtime draws its own blast disc."))
    s.row([Panel(plan, "", tag="SCALE")])
    s.text("A warning or a boundary",
           "A WARNING says an attack is coming, from here, this way, and "
           "claims no reach. A BOUNDARY promises where the danger ends, "
           "which is only honest at the runtime's size, anchor and timing. "
           "At their current sizes all three marks are warnings. Used as "
           "boundaries they would promise safety that does not exist. "
           "Details: DANGER_MARKS.md.")
    s.text("Correction to my own review",
           "D2 drew the charger's reach as the 0.9 m art lane stretched to "
           "14.3 m. The runtime hits anywhere within %.1f m of the "
           "charger's path, so the footprint is %.1f m wide. (Corrected "
           "2026-09-28.)" % (radius, 2 * radius))
    s.footer("Plan drawn from Production's constants at c12a72f, read with "
             "git show, and from the marks' own manifest; no number is "
             "typed. Arty, 2026-09-28.")
    return s.save(os.path.join(out, "4_danger_marks_to_scale.jpg"))


def main():
    frames, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for build in (s049, s_skiff, s_panels, s_danger):
        path = build(frames, out)
        print("%s  %.0f KB" % (path, os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
