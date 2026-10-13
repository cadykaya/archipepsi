#!/usr/bin/env python3
"""Review sheets for the four-weapon form pass. (Arty, 2026-10-13.)

    python3 tools/crossing_capture/weapon_forms_sheets.py FORMS SHEETS

FORMS is `tools/blender/build_weapon_forms.py`'s output (one folder per
proposal with side/eye/three_q renders, plus `foundry/` and forms.json)
with the range captures of `tools/crossing_capture/weapon_forms.gd` in
FORMS/engine. Writes into SHEETS:

  WF0_family_lineup.png      the approved Foundry and all eight proposals,
                             left elevations at one shared scale
  WF1_sightline.png .. WF4_mass_driver.png
                             one weapon each: A beside B, three-quarter,
                             elevation, in Prod's range (rest, then ADS,
                             variant or charge), what drives it, the
                             runtime parts it gives Prod, triangles, and
                             a recommendation
  WF5_in_range.png           every proposal from the player's eye in
                             Prod's v3 range, same frame

Everything is drawn from the files the runs wrote; nothing is retouched.
"""

from __future__ import annotations

import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foundry_study_sheets import (ACCENT, BG, DIM, INK, caption,  # noqa: E402
                                  font, title)

W = 2400
COL = (W - 120) // 2

# what each weapon was asked for (the owner, 2026-10-13) and what Prod's
# v3 runtime gives it to move
WEAPONS = [
    ("WF1_sightline", "Sightline", "sightline",
     "Owner: “a substantial, powerful long-range rifle.”",
     "v3: `handle` strokes 0.022 m back at 0.13 s (Condi's two bolt "
     "clicks); ADS sight line y 0.075; muzzle (0, 0.025, −0.74); "
     "recoil peak 0.10 m / 9°.",
     [("sightline_a", ["rest", "ads"]), ("sightline_b", ["rest", "ads"])]),
    ("WF2_switchback", "Switchback", "switchback",
     "Owner: “preserve its successful automatic-fire personality.”",
     "v3: `bolt` strokes 0.035 m every shot at about 7 rounds a second; "
     "ADS sight line y 0.065; muzzle (0, 0.02, −0.42).",
     [("switchback_a", ["rest", "ads"]), ("switchback_b", ["rest", "ads"])]),
    ("WF3_bulkhead", "Bulkhead", "bulkhead",
     "Owner: “accommodate both the quick scattergun and heavy shotgun "
     "possibilities.”",
     "v3: Breacher works `pump` 0.1 m at 0.72 s; Sweeper shows `feed` "
     "(that variant only) and never pumps; muzzle (0, 0.02, −0.5); "
     "no ADS.",
     [("bulkhead_a", ["breacher_rest", "sweeper_rest"]),
      ("bulkhead_b", ["breacher_rest", "sweeper_rest"])]),
    ("WF4_mass_driver", "Mass Driver", "driver",
     "Owner: “charged kinetic weapon with reduced recoil and strong "
     "mechanical identity.”",
     "v3: `coils` spin about the bore with the charge; `core` glows "
     "through its material_override; ADS sight line y 0.13; muzzle "
     "(0, 0, −0.62); recoil peak 0.12 m / 3.5°.",
     [("driver_a", ["rest", "charge"]), ("driver_b", ["rest", "charge"])]),
]

NOTES = {
    "sightline_a": (
        "Mass along the line of fire. Three Epsilon stator packs are "
        "clamped down a long barrel, each wired back to the receiver: "
        "they give the slug its last push. The Echo core is a slab "
        "cartridge seated from below like a magazine. The bolt handle "
        "works in a raceway on the LEFT, where the eye sees Prod's "
        "stroke. Ring sights sit on his ADS line.",
        "For: the most ‘substantial, powerful’ read; the stators "
        "say ‘long range’ without a scope. Against: 4,112 "
        "triangles, the top of the budget; three repeated packs need "
        "distinct wear so they read worked, not decorative."),
    "sightline_b": (
        "A twin-tube line. The barrel rides over a long Epsilon pressure "
        "reservoir, joined by a station regulator block with a hand "
        "wheel; a broad slab brake. The core screws into the reservoir's "
        "tail; the bolt works on the left.",
        "For: a silhouette no other gun has; 2,864 triangles. Against: "
        "reads more pneumatic than powerful, and the hand wheel sits "
        "close to the sight picture."),
    "switchback_a": (
        "Compact and busy. A slatted cooling jacket round the barrel (the "
        "gun that sustains fire runs hot), a ribbed box magazine, the "
        "Epsilon feed motor on the left with the core in its end, and "
        "the bolt racing in an open port on the LEFT, where the eye sees "
        "every round.",
        "For: the automatic personality is on screen: Prod's 0.035 m "
        "stroke at 7 a second, in plain view. Against: the most "
        "conventional silhouette of the eight."),
    "switchback_b": (
        "A flat pan magazine on the left, its hub the Epsilon feed motor "
        "with the core at its centre: the biggest single shape any of "
        "the five carries. A finned barrel instead of a jacket; the bolt "
        "works on the right.",
        "For: the strongest identity in the family. Against: the bolt is "
        "hidden from the eye, so the per-shot motion is lost unless the "
        "port moves to the top (a form change, not a runtime one)."),
    "bulkhead_a": (
        "Broad and squat: two short bores side by side under a welded "
        "rib, one heavy muzzle plate, an Epsilon charger block riding on "
        "top with the core standing in it, right where the eye looks. "
        "One platform, two configurations: the Breacher works the pump; "
        "the Sweeper takes the feed box under the receiver.",
        "For: ‘scatter’ reads from the twin bores; both "
        "configurations sit on one body; 2,012 triangles leave the most "
        "for texture. Against: flat from the side."),
    "bulkhead_b": (
        "One fat bore with a flared choke, fed from a station pressure "
        "drum with hoop bands and a gauge; the Epsilon compressor rides "
        "under the drum, the core screwed into its side. Same two "
        "configurations.",
        "For: round and heavy, the ‘heavy shotgun’ read. "
        "Against: the drum can read as a grenade launcher, and the "
        "Sweeper's feed box crowds it."),
    "driver_a": (
        "A heavy rotor round the line of fire spins up inside a station "
        "guard cage (Prod's `coils`) and dumps its momentum through open "
        "twin rails on Epsilon bridges and ceramic insulators. The "
        "accumulator under it glows with the charge (Prod's `core`); the "
        "Echo core seats in its end. Raised sight post on the ADS line.",
        "For: one heavy flywheel tells the reduced-recoil story (the "
        "mass is in the rotor); unlike anything else in the family. "
        "Against: the cage hides some of the spin at the hip."),
    "driver_b": (
        "Three heavy wound coils in steel cages, spaced along twin rails, "
        "spin up together (Prod's `coils`): the motion spread down the "
        "gun. A long, open silhouette; the accumulator under the rear "
        "glows.",
        "For: the classic coilgun read, the spin visible all along the "
        "barrel. Against: closest to the old placeholder's three rings; "
        "less ‘mechanical identity’ than A."),
}

RECOMMEND = {
    "sightline": "Recommend A, trimmed toward 3,600 triangles in "
                 "production; B's regulator block could return as A's "
                 "repair layer.",
    "switchback": "Recommend B's pan for identity, with the bolt port "
                  "moved to the top-left so the per-shot stroke stays "
                  "in view; A if the owner prefers the motion over the "
                  "silhouette.",
    "bulkhead": "Recommend A: both configurations on one platform, the "
                "cheapest geometry, the core where the eye looks.",
    "driver": "Recommend A: the rotor is the strongest mechanical "
              "identity and carries the reduced-recoil story.",
}

PARTS_BY_KEY = {
    "sightline": "Handle", "switchback": "Bolt", "bulkhead": "Pump, Feed",
    "driver": "Coils, Core",
}


def fitw(img, w):
    """Scale to a width, keeping the aspect: no sheet stretches a view."""
    return img.resize((w, round(img.height * w / img.width)), Image.LANCZOS)


def _img(path):
    return Image.open(path).convert("RGB")


def _label(draw, x, y, text, size=18, fill=DIM):
    draw.text((x, y), text, font=font(size), fill=fill)


def weapon_sheet(forms, record, spec, out):
    name, weapon, wkey, ask, runtime, props = spec[1], spec[1], spec[2], \
        spec[3], spec[4], spec[5]
    H = 2050
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "%s: two proposed forms" % name,
          "Forms for review, in clay; not final models. Arty, 2026-10-13.")
    y = caption(d, 40, 120, ask, 160, 20, ACCENT)
    caption(d, 40, y + 6, runtime, 170, 17, DIM)
    for i, (key, shots) in enumerate(props):
        x = 40 + i * (COL + 40)
        r = record[key]
        top = 230
        d.text((x, top), r["label"], font=font(26, True), fill=INK)
        _label(d, x + 520, top + 6, "%d triangles  ·  nodes: %s"
               % (r["triangles"], ", ".join(sorted(r["nodes"]))))
        tq = fitw(_img(os.path.join(forms, key, "three_q.png")), COL)
        sheet.paste(tq, (x, top + 44))
        side = _img(os.path.join(forms, key, "side.png"))
        side = side.crop((0, 120, side.width, side.height - 60))
        side = fitw(side, COL)
        sheet.paste(side, (x, top + 700))
        _label(d, x, top + 1112, "left elevation, shared scale with the "
               "family lineup")
        sw = (COL - 20) // 2
        for j, shot in enumerate(shots):
            im = _img(os.path.join(forms, "engine", "%s_%s.png" % (key, shot)))
            im = im.crop((400, 180, 1600, 855)).resize((sw, int(sw * 675 / 1200)))
            sheet.paste(im, (x + j * (sw + 20), top + 1150))
            _label(d, x + j * (sw + 20), top + 1150 + im.height + 4,
                   "Prod's v3 range: " + shot.replace("_", " "))
        ny = top + 1150 + int(sw * 675 / 1200) + 40
        what, judge = NOTES[key]
        ny = caption(d, x, ny, what, 108, 17)
        caption(d, x, ny + 8, judge, 108, 17, ACCENT)
    d.line((40, H - 90, W - 40, H - 90), fill=(60, 62, 68), width=2)
    d.text((40, H - 70), RECOMMEND[wkey], font=font(21, True), fill=INK)
    sheet.save(out)


def lineup(forms, record, out):
    rows = [("foundry", "Foundry: approved benchmark", None)]
    for spec in WEAPONS:
        a, b = spec[5][0][0], spec[5][1][0]
        rows.append((a, record[a]["label"], b))
    cw, ch = 1120, 406
    H = 140 + len(rows) * (ch + 20)
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "The family at one scale",
          "Left elevations, one orthographic scale for all nine; the "
          "Foundry is the approved standard (in the same clay). Bulkhead "
          "elevations show the Sweeper's feed box fitted. Arty, 2026-10-13.")
    for r, (a, label, b) in enumerate(rows):
        y = 130 + r * (ch + 20)
        for c, key in enumerate([a, b] if b else [a]):
            im = _img(os.path.join(forms, key, "side.png"))
            im = im.crop((0, 120, im.width, im.height - 60))
            im = fitw(im, cw)
            x = 40 + c * (cw + 80) if b else (W - cw) // 2
            sheet.paste(im, (x, y))
            text = record[key]["label"] if key in record else label
            weapon = record[key]["weapon"] if key in record else ""
            d.text((x + 10, y + 8), ("%s  %s" % (weapon, text)).strip(),
                   font=font(20, True), fill=ACCENT if not b else INK)
    sheet.save(out)


def in_range(forms, out):
    shots = ["sightline_a_rest", "sightline_b_rest", "switchback_a_rest",
             "switchback_b_rest", "bulkhead_a_breacher_rest",
             "bulkhead_b_breacher_rest", "driver_a_rest", "driver_b_rest"]
    cw, ch = 1160, 520
    sheet = Image.new("RGB", (W, 130 + 4 * (ch + 50)), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "From the player's eye, in Prod's v3 range",
          "Each proposal swapped in memory for Prod's placeholder; his rig "
          "holds and moves it. Same frame for all eight.")
    for i, n in enumerate(shots):
        im = _img(os.path.join(forms, "engine", n + ".png"))
        im = im.crop((500, 280, 1600, 900)).resize((cw, ch))
        x, y = 40 + (i % 2) * (cw + 40), 130 + (i // 2) * (ch + 50)
        sheet.paste(im, (x, y))
        _label(d, x, y + ch + 6, n.replace("_rest", "").replace("_", " "),
               19, INK)
    sheet.save(out)


def main():
    forms, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    record = json.load(open(os.path.join(forms, "forms.json")))
    lineup(forms, record, os.path.join(out, "WF0_family_lineup.png"))
    for spec in WEAPONS:
        weapon_sheet(forms, record, spec, os.path.join(out, spec[0] + ".png"))
    in_range(forms, os.path.join(out, "WF5_in_range.png"))
    print("[sheets] wrote", sorted(os.listdir(out)))


if __name__ == "__main__":
    main()
