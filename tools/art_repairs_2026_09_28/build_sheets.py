#!/usr/bin/env python3
"""Repair 2026-09-28 -- the evidence sheets.

    tools/art_repairs_2026_09_28/run_pose_views.sh <frames>/pose
    tools/art_repairs_2026_09_28/run_tint_views.sh <frames>/tint
    tools/art_repairs_2026_09_28/run_gauge_views.sh <frames>/gauge
    tools/art_repairs_2026_09_28/run_tint_views.sh <frames>/tint_fu \
        e4103ba followup
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
    "FIRST": ((128, 52, 52), "BEFORE · first repair, e4103ba"),
    "SOLID": ((128, 52, 52), "BEFORE · 77d33ca, the bezel solid"),
    "FOLLOW": ((46, 125, 84), "AFTER · follow-up, this branch"),
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
        ("conn_hold_paddle", "Paddle · down 22°",
         "Measured: the last whole degree before it bears on its own "
         "spring. A position, not an input.", "the pin travelled 0.275 m"),
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
    s.text("Follow-up, 2026-09-28",
           "The paddle's positions were named 'released' and 'held'. They "
           "are now 'level' and 'down'. A pose names where the part is. It "
           "is not an input or a rule, and it does not settle whether the "
           "control is momentary or permanent (A1, open). The gauge rows "
           "show the bezel before the follow-up opened it: see sheet 5.")
    s.footer(FOOT + " Verified by verify_049_hinges.py: rest geometry, UVs "
             "and materials identical to a1584c8, node for node. The one "
             "exception is the gauge's bezel, which the follow-up reshaped; "
             "verify_049_gauge.py owns that change.")
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
    s.text("Follow-up, 2026-09-28",
           "This sheet is the first round. The thirteen panels it left in "
           "place were clear of the fittings, but ten of them were badly "
           "seated: six hung off the body and four lay flush with it. The "
           "stricter test also caught the ballast's pair, which had slid "
           "onto a band. All twelve are re-seated: see sheet 6.")
    s.footer(FOOT + " Verified by verify_053_panels.py. Thirteen panels "
             "were already clear; they keep their place and only change "
             "material.")
    return s.save(os.path.join(out, "3_lightened_panels.jpg"))


def s_gauge(frames, out):
    s = Sheet("049 · the gauge face shows through its bezel",
              "Before: the bezel was a solid block with the face inside "
              "it, so the needle turned over nothing. After: the same "
              "bezel is a frame, and the face is read through its 0.20 m "
              "window. Real materials, no tint. Both files are turned by "
              "the same hinge to the manifest's own readings.")
    s.statuses(compat=("yes", "Same case, face, needle, pin, axis and "
                              "travel. Same outer size; 64 → 100 tris."),
               **UNCHANGED)
    for pose, deg, clock in (("empty", "+90°", "9 o'clock"),
                             ("half", "0°", "12 o'clock"),
                             ("full", "−90°", "3 o'clock")):
        title = "%s · %s" % (pose.capitalize(), deg)
        s.row([Panel("%s/gauge/gauge_%s_old_front.png" % (frames, pose),
                     title, tag="SOLID",
                     note="No face; the needle is cream on a cream bezel"),
               Panel("%s/gauge/gauge_%s_new_front.png" % (frames, pose),
                     title, tag="FOLLOW",
                     note="The needle at %s over the face" % clock),
               Panel("%s/gauge/gauge_%s_new_side.png" % (frames, pose),
                     "35° to the side", tag="FOLLOW",
                     note="The face sits back; the needle stands in front")])
    s.text("What proves it",
           "verify_049_gauge.py looks straight on through a 2 mm grid of "
           "rays at every degree from −90° to +90°. The dial round the pin "
           "(the needle's 9 cm reach, plus 5 mm) shows only face or "
           "needle. The needle is never covered, and is always seen "
           "against the face. On the old file the face shows 0 cm², and "
           "the needle is seen against the bezel at every angle.")
    s.footer("Review renders through Godot's own GLTFDocument importer, one "
             "rig per sheet, real materials. The build refuses a bezel the "
             "needle touches at any reading. Arty, 2026-09-28.")
    return s.save(os.path.join(out, "5_gauge_face.jpg"))


def s_panels_seated(frames, out):
    s = Sheet("Lightened panels · every panel seated",
              "The follow-up ran the seat and clearance test on all 22 "
              "panels, not only the nine near fittings, and re-seated "
              "twelve. Both frames tint the panels flat magenta so their "
              "place reads. Their real look is the grey-blue on sheet 3, "
              "kept as the working treatment. Each camera is aimed from the "
              "exported files at the first panel that moved, from its old "
              "and new faces; a mirrored partner may be out of frame.")
    s.statuses(compat=("yes", "Bodies, fittings, sizes, attach points, "
                              "masses and classes unchanged."),
               **UNCHANGED)
    rows = [
        ("ballast", "Ballast · both",
         "Slid onto a band, flush with it",
         "Between the bands: 3 cm lower, 60% high"),
        ("cart", "Cart · both",
         "On the deck's sides, partly over no body",
         "On the deck top"),
        ("girder", "Girder · both",
         "Up to 4.5 cm off the web",
         "Seated on the web, 7 cm in"),
        ("key_component", "Key component · one",
         "Flush with its face: the body shows through",
         "On the +X side; the other kept its place"),
        ("mechanical_part", "Mechanical part · hub end",
         "Flush on the uneven hub: the body shows through",
         "On the −X side, like the +X panel"),
        ("plate", "Plate · both",
         "Flush with its long sides: the body shows through",
         "One on the +X end, one on the top"),
        ("power_cell", "Power cell · both",
         "Up to 4.2 cm off the core, across the cage",
         "Seated on the core at 80% width"),
    ]
    for key, name, before, after in rows:
        s.row([Panel("%s/tint_fu/%s_old.png" % (frames, key), name,
                     tag="FIRST", note=before),
               Panel("%s/tint_fu/%s_new.png" % (frames, key), name,
                     tag="FOLLOW", note=after)])
    s.text("What proves it",
           "verify_053_panels.py asks every panel three separate "
           "questions:\n"
           "- MATERIAL: does it wear its own slot?\n"
           "- CLEAR: is it off every fitting?\n"
           "- SEATED: rays 1 cm apart all find the body 2 mm to 3 cm "
           "behind its face, flat to 1 cm.\n"
           "On this branch all 22 pass. On e4103ba's files only SEATED "
           "fails, 12 times. On a1584c8's it fails 22 / 9 / 17. Where a "
           "before frame shows the tint striped, the panel is flush with "
           "the body and the two fight for the same pixels: z-fighting.")
    s.footer(FOOT)
    return s.save(os.path.join(out, "6_panels_seated.jpg"))


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
           "CHARGER · code reading: hit within\n%.1f m of a %.1f m rush: "
           "%.1f × %.1f m\nart lane %.1f × %.1f m" % (
               radius, travel, 2 * radius, travel + 2 * radius, lane[0],
               lane[1]),
           fill=ink, font=f)
    # 2. The artillery: the blast and the art ring.
    ax, ay = 470, 190
    d.ellipse([ax - blast * ppm, ay - blast * ppm, ax + blast * ppm,
               ay + blast * ppm], outline=true_col, width=3)
    d.ellipse([ax - warned * ppm, ay - warned * ppm, ax + warned * ppm,
               ay + warned * ppm], fill=art_col)
    d.text((ax - 150, ay + blast * ppm + 16),
           "ARTILLERY · code reading: blast r %.1f m\n(the runtime already "
           "draws this disc);\nit can burst early, where the arc meets\n"
           "something\n"
           "art ring r %.1f m" % (blast, warned), fill=ink, font=f)
    # 3. The beacon: an ally aura, not player damage.
    bx, by = 1010, 270
    dashed_circle(bx, by, aura * ppm)
    d.ellipse([bx - ring * ppm, by - ring * ppm, bx + ring * ppm,
               by + ring * ppm], fill=art_col)
    d.text((bx - 185, by + aura * ppm + 14),
           "BEACON · code reading: r %.0f m support\naura. ENEMIES inside "
           "hit harder.\nNot damage to the player.\nart ring r %.1f m"
           % (aura, ring), fill=ink, font=f)
    d.text((24, H - 56), "1 m = %d px. White: the reach read from "
           "Production's code at c12a72f, not tested in play.\nBlue: the "
           "candidate art mark. Yellow: the charger at the start of its "
           "rush." % ppm, fill=ink, font=f)
    plan = os.path.join(frames, "danger_plan.png")
    img.save(plan)

    s = Sheet("Danger marks · the runtime's real reach, to scale",
              "The geometry a boundary mark would have to match, as read "
              "from Production's code at c12a72f. These are code readings, "
              "not tested in play and not an approved presentation. No "
              "presentation is chosen here, and no mark was rebuilt.")
    s.statuses(visual=("pending", "PENDING. Presentation is the owner's "
                                  "call."),
               compat=("no", "Undersized for a boundary; the charger lane "
                             "is also too narrow."),
               binding=("none", "None. For the charger and artillery the "
                                "seam would be telegraph_started and "
                                "telegraph_finished. The beacon has no "
                                "telegraph."),
               play=("no", "No. The runtime draws its own blast disc."))
    s.row([Panel(plan, "", tag="SCALE")])
    s.text("A warning or a boundary",
           "A WARNING says an attack is coming, from here, this way, and "
           "claims no reach. A BOUNDARY promises where the danger ends, "
           "which is only honest at the runtime's size, anchor and timing. "
           "At their current sizes all three marks are warnings. Used as "
           "boundaries they would promise safety that does not exist. "
           "Details: DANGER_MARKS.md.")
    s.text("Code readings, not tests",
           "Every reach on this sheet comes from reading Production's code "
           "at c12a72f. That includes the charger's footprint, the "
           "artillery's early burst where its arc meets something, and "
           "the beacon's 12 m support radius. None was tested in play, and "
           "none is an approved presentation.")
    s.text("Correction to my own review",
           "D2 drew the charger's reach as the 0.9 m art lane stretched to "
           "14.3 m. The runtime hits anywhere within %.1f m of the "
           "charger's path, so the footprint is %.1f m wide. (Corrected "
           "2026-09-28.)" % (radius, 2 * radius))
    s.footer("Plan drawn from Production's constants at c12a72f, read with "
             "git show, and from the marks' own manifest; no number is "
             "typed. Corrected 2026-09-28, follow-up: the binding line had "
             "named the seam for all three marks, but the beacon has none; "
             "code-reading labels added. Arty, 2026-09-28.")
    return s.save(os.path.join(out, "4_danger_marks_to_scale.jpg"))


def main():
    """<frames> <out-dir> [sheet function ...]: all sheets, or just those."""
    frames, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    every = (s049, s_skiff, s_panels, s_danger, s_gauge, s_panels_seated)
    only = sys.argv[3:]
    for build in (b for b in every if not only or b.__name__ in only):
        path = build(frames, out)
        print("%s  %.0f KB" % (path, os.path.getsize(path) / 1024.0))


if __name__ == "__main__":
    main()
