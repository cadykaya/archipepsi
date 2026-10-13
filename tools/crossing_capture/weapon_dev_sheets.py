#!/usr/bin/env python3
"""Review sheets for the weapon development pass. (Arty, 2026-10-13.)

    python3 tools/crossing_capture/weapon_dev_sheets.py bulkhead BULK SHEETS
    python3 tools/crossing_capture/weapon_dev_sheets.py dev DEV SHEETS

bulkhead: BULK is `build_bulkhead_concepts.py`'s output (A re-rendered
beside C, D, E; top/side/three_q per concept) with the range stills of
`weapon_forms.gd` in BULK/engine. Writes:
  WB1_bulkhead_silhouettes.png  top and side at one scale: A (provisional)
                                against the three new directions
  WB2_bulkhead_in_use.png       three-quarter, and Breacher and Sweeper
                                from the player's eye in Prod's range

dev: DEV is `tools/weapon_model.sh`'s output (per weapon: look/, the GLB
and <weapon>.json) with the range captures in DEV/engine. Writes:
  WD1_sightline.png .. WD3_mass_driver.png
      the developed model in Cycles (three-quarter, elevation, close
      looks), from the player's eye in Prod's range, and its measured cost
  WD0_metrics.png               the measured numbers, one table
  <weapon>_clip.gif             the range clip, 15 fps (from the 30 fps
                                movie frames in DEV/engine/<weapon>_clip/)

Everything is drawn from files the runs wrote; nothing is retouched.
"""

from __future__ import annotations

import glob
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foundry_study_sheets import (ACCENT, BG, DIM, INK, caption,  # noqa: E402
                                  font, title)

W = 2400


def fitw(img, w):
    return img.resize((w, round(img.height * w / img.width)), Image.LANCZOS)


def _img(path):
    return Image.open(path).convert("RGB")


# ============================================================== Bulkhead

BULK = [
    ("bulkhead_a", "A  Twin-bore (provisional)",
     "The form you marked provisional: a receiver box with two bores on "
     "the front. Shown for comparison only."),
    ("bulkhead_c", "C  Spreader",
     "A hydraulic rescue spreader -- the tool that opens jammed bulkheads "
     "-- made into a gun. A flanged ram cylinder behind; two forged jaws "
     "splayed nine degrees with a bore in each, so the spread is in the "
     "shape; teeth on the jaw tips for bracing on a door; the Epsilon ram "
     "between the jaws on links. Breacher: the pump re-pressurises the "
     "ram. Sweeper: a shell box clamped to the left, heads in its window."),
    ("bulkhead_d", "D  Fan",
     "A debris-clearing manifold: one cast block widening forward, four "
     "short bores fanned fifteen degrees out of its face (a duck's-foot "
     "pistol's spread); an Epsilon distributor sends one charge down four "
     "cables. The breech block hinges to load from behind. Breacher: a "
     "slide hung under the fan. Sweeper: a flat four-shell cassette, one "
     "shell per bore."),
    ("bulkhead_e", "E  Hatch ram",
     "A powder-actuated stud driver grown into a breaching gun: a short, "
     "very thick ram sleeve with a breaching crown and four standoff "
     "claws; disc charges stacked in a slotted tower over the breech; "
     "Epsilon kick-coils at the ram's root. Breacher: the pump IS the "
     "sleeve's collar. Sweeper: a belt of discs from a box on the left."),
]


def _crop_view(path, box=(0, 120, 1600, 700)):
    return _img(path).crop(box)


def bulkhead_silhouettes(bulk, record, out):
    cw = (W - 120) // 2
    # one crop width for both views, so both keep the renders' one scale
    crops = {"top": (250, 250, 1450, 520), "side": (250, 150, 1450, 690)}
    rh = round(540 * cw / 1200)
    H = 220 + len(BULK) * (rh + 70)
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "Bulkhead, revisited: three new silhouettes",
          "From above (left) and the left side (right), one orthographic "
          "scale for all four. Clay forms, not final models. "
          "Arty, 2026-10-13.")
    caption(d, 40, 120, "Your note: “too blocky and visually generic "
            "... something more distinctive and interesting, not simply a "
            "conventional shotgun with futuristic parts attached.” "
            "Each new one starts from a station tool whose job is to open "
            "a bulkhead.", 170, 19, ACCENT)
    for r, (key, label, _) in enumerate(BULK):
        y = 210 + r * (rh + 70)
        tri = record[key]["triangles"]
        d.text((40, y), "%s   (%d triangles)" % (label, tri),
               font=font(24, True), fill=INK if key != "bulkhead_a"
               else DIM)
        for c, view in enumerate(("top", "side")):
            im = fitw(_crop_view(os.path.join(bulk, key, view + ".png"),
                                 crops[view]), cw)
            yo = (rh - im.height) // 2
            sheet.paste(im, (40 + c * (cw + 40), y + 40 + yo))
    sheet.save(out)


def bulkhead_in_use(bulk, out):
    cw = (W - 160) // 3
    rh = round(cw * 9 / 16)
    H = 170 + len(BULK) * (rh + 190)
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "Bulkhead, revisited: the mechanism and both variants",
          "Three-quarter in clay; then the Breacher and the Sweeper from "
          "the player's eye in Prod's v3 range (his rig, his variant "
          "switch). Arty, 2026-10-13.")
    for r, (key, label, note) in enumerate(BULK):
        y = 130 + r * (rh + 190)
        d.text((40, y), label, font=font(24, True),
               fill=INK if key != "bulkhead_a" else DIM)
        tq = fitw(_img(os.path.join(bulk, key, "three_q.png")), cw)
        sheet.paste(tq, (40, y + 40))
        for c, v in enumerate(("breacher", "sweeper")):
            im = _img(os.path.join(bulk, "engine", "%s_%s_rest.png"
                                   % (key, v)))
            im = im.crop((560, 330, 1440, 825)).resize((cw, rh))
            x = 40 + (c + 1) * (cw + 40)
            sheet.paste(im, (x, y + 40))
            d.text((x, y + 44 + rh), v.capitalize(), font=font(17),
                   fill=DIM)
        caption(d, 40, y + 76 + rh, note, 200, 17,
                DIM if key == "bulkhead_a" else INK)
    sheet.save(out)


# =========================================================== development

DEV = [
    ("WD1_sightline", "sightline", "Sightline: A, the Accelerator",
     "Added: a recoil buffer at the back (the face nearest the eye), a "
     "lead and terminal for each stator pack, and a cut plate bolted over "
     "a cracked trunnion. History: a crack beside the bolt raceway, welded "
     "and ground flat and touched up from the wrong tin; heat-straw on "
     "the barrel by the breech and at the brake; soot at the brake and the "
     "raceway; the serial stamped on the barrel; SL-7 stencilled; service "
     "tallies in grease pencil on the core well; a spanner slip on one "
     "saddle bolt.", ["close_breech", "close_stators", "close_rear"]),
    ("WD2_switchback", "switchback", "Switchback: A, the Jacketed carbine",
     "Added: a square replacement plate on the round buffer (the original "
     "lost), a deflector bent from strip and welded behind the open port "
     "so cases do not come back at the eye, and a fire selector. History: "
     "the dirtiest of the three (it is the one that is used most); the "
     "jacket and the compensator heat-blued, soot round the port; the "
     "carry handle polished by hands; a grind on the rear-left touched "
     "up; a welded repair on the magazine well.",
     ["close_port", "close_jacket", "close_rear"]),
    ("WD3_mass_driver", "driver", "Mass Driver: A, the exposed Rotor",
     "Added: a rear plate with a hand-crank socket (with the core out the "
     "rotor is spun or run down by hand) and the pickup lead from the "
     "accumulator to a terminal on the cage. The rotor carries lathe rings "
     "and a painted index stripe, so its spin reads through the cage "
     "without any glow; only the accumulator lights with the charge. "
     "History: a cracked housing corner ground and repainted, a rail "
     "sleeved and welded, heat-straw at the rail mouths.",
     ["close_rotor", "close_rails", "close_rear"]),
]


def dev_sheet(dev, spec, out):
    sheet_name, key, label, note, closes = spec
    look = os.path.join(dev, key, "look")
    rec = json.load(open(os.path.join(dev, key, key + ".json")))
    met = {}
    mp = os.path.join(dev, "engine", key + "_metrics.json")
    if os.path.exists(mp):
        met = json.load(open(mp))
    H = 2350
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, label + ", developed toward the Foundry standard",
          "An approved concept direction, modelled, painted and held in "
          "Glyph through the Foundry study's pipeline. A development model: "
          "not merged, not finished. Arty, 2026-10-13.")
    big = fitw(_img(os.path.join(look, "look_three_q.png")), 1460)
    sheet.paste(big, (40, 110))
    side = fitw(_img(os.path.join(look, "look_side.png")).crop(
        (0, 120, 1600, 700)), 1460)
    sheet.paste(side, (40, 110 + big.height + 20))
    x2 = 1540
    cw = W - x2 - 40
    y0 = 110 + big.height + 20 + side.height + 30
    # the close looks share the column above the range row, centre-cropped
    ch = (y0 - 30 - 110 - 16 * (len(closes) - 1)) // len(closes)
    y = 110
    for c in closes:
        im = fitw(_img(os.path.join(look, "look_%s.png" % c)), cw)
        top = max(0, (im.height - ch) // 2)
        im = im.crop((0, top, cw, top + min(ch, im.height)))
        sheet.paste(im, (x2, y))
        y += im.height + 16
    # the range: rest and (ADS or charge)
    shots = [key + "_rest"]
    for extra in (key + "_ads", key + "_charge"):
        if os.path.exists(os.path.join(dev, "engine", extra + ".png")):
            shots.append(extra)
    sw = (W - 80 - 40 * (len(shots) - 1)) // len(shots)
    for i, s in enumerate(shots):
        im = _img(os.path.join(dev, "engine", s + ".png"))
        im = im.crop((300, 120, 1600, 851)).resize((sw, round(sw * 731
                                                               / 1300)))
        x = 40 + i * (sw + 40)
        sheet.paste(im, (x, y0))
        d.text((x, y0 + im.height + 4), "Prod's v3 range: " + s.split(
            "_", 1)[1], font=font(17), fill=DIM)
    ty = y0 + round(sw * 731 / 1300) + 50
    m = rec["metrics"]
    line = ("%d triangles  ·  1 material  ·  %d textures at "
            "%d²  ·  %.0f texels/m" % (
                m["triangles"], len(m["textures"]), m["texture_size"],
                m["texels_per_metre"]))
    if met:
        line += ("  ·  measured in the range: %d draw calls, %.1f MB "
                 "texture memory added" % (
                     met["draw_calls"],
                     met["texture_mem_added_bytes"] / 1048576.0))
    d.text((40, ty), line, font=font(20, True), fill=ACCENT)
    caption(d, 40, ty + 40, note, 205, 18)
    sheet.save(out)


def metrics_sheet(dev, out, foundry=None):
    rows = []
    for _, key, label, _, _ in DEV:
        rec = json.load(open(os.path.join(dev, key, key + ".json")))
        mp = os.path.join(dev, "engine", key + "_metrics.json")
        met = json.load(open(mp)) if os.path.exists(mp) else {}
        rows.append((label.split(":")[0], rec["metrics"], met))
    if foundry:
        rows.insert(0, ("Foundry (approved)", foundry[0], foundry[1]))
    sheet = Image.new("RGB", (W, 200 + 70 * (len(rows) + 1)), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "What each costs, measured",
          "Provisional, per the owner's rule: recorded now, profiled in the "
          "game once the designs are approved, reduced only where a "
          "measurement says so. Arty, 2026-10-13.")
    cols = ["weapon", "triangles", "materials", "textures", "size",
            "texels/m", "draw calls (range)", "texture memory (range)"]
    xs = [40, 520, 760, 960, 1180, 1360, 1580, 1960]
    y = 150
    for x, c in zip(xs, cols):
        d.text((x, y), c, font=font(19, True), fill=DIM)
    for name, m, met in rows:
        y += 70
        vals = [name, "%d" % m["triangles"], "%d" % m["materials"],
                "%d" % len(m["textures"]), "%d²" % m["texture_size"],
                "%.0f" % m["texels_per_metre"],
                "%d" % met["draw_calls"] if met else "-",
                "%.1f MB" % (met["texture_mem_added_bytes"] / 1048576.0)
                if met else "-"]
        for x, v in zip(xs, vals):
            d.text((x, y), v, font=font(21), fill=INK)
    sheet.save(out)


CLIP_FRAMES = 112


def clip_gif(frames_dir, out, every=2, size=(800, 450), crop=None):
    files = sorted(glob.glob(os.path.join(frames_dir, "*.png")))
    if not files:
        return False
    # the movie maker records from start-up; the clip proper is the last
    # 220 physics ticks (110 frames at 30 fps), after the swap and settle
    files = files[max(0, len(files) - CLIP_FRAMES):]
    frames = []
    for f in files[::every]:
        im = _img(f)
        if crop:
            im = im.crop(crop)
        frames.append(im.resize(size, Image.LANCZOS).quantize(
            128, method=Image.MEDIANCUT, dither=Image.NONE))
    frames[0].save(out, save_all=True, append_images=frames[1:],
                   duration=round(1000 * every / 30), loop=0,
                   optimize=True)
    return True


def main():
    mode, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    if mode == "bulkhead":
        record = json.load(open(os.path.join(src, "forms.json")))
        bulkhead_silhouettes(src, record,
                             os.path.join(out, "WB1_bulkhead_silhouettes.png"))
        bulkhead_in_use(src, os.path.join(out, "WB2_bulkhead_in_use.png"))
    else:
        for spec in DEV:
            dev_sheet(src, spec, os.path.join(out, spec[0] + ".png"))
            clip_gif(os.path.join(src, "engine", spec[1] + "_clip"),
                     os.path.join(out, spec[1] + "_clip.gif"),
                     crop=(500, 280, 1460, 820))
        foundry = None
        fj = os.environ.get("FOUNDRY_METRICS")
        if fj:
            foundry = json.load(open(fj))
        metrics_sheet(src, os.path.join(out, "WD0_metrics.png"), foundry)
    print("[sheets] wrote", sorted(os.listdir(out)))


if __name__ == "__main__":
    main()
