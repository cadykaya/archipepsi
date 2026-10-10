"""Compose the five-weapon study's renders into review sheets. REVIEW ONLY.
(Arty, 2026-10-10.)

    python3 tools/crossing_capture/five_weapon_sheets.py RENDERS SPECS OUT

RENDERS holds one folder per `five_weapon_study.py` moment (dcap.gd output),
SPECS the study's spec folder (for `recoil_signatures.png`). Writes FW1-FW8
into OUT. The reticle drawn on first-person frames is an OVERLAY marking
the screen centre (dcap hides the HUD); it is not the game's reticle art.
"""

import json
import os
import sys

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
FX = os.path.join(REPO, "assets", "fx", "weapons")
GUNS = ["foundry", "sightline", "switchback", "bulkhead", "massdriver"]
FOUNDRY_T = (0, 17, 33, 50, 67, 100, 150, 233, 350, 550)
BG = (24, 25, 28)
INK = (225, 225, 225)


def shot(renders, moment, view, w=640, h=360, reticle=False):
    img = Image.open(os.path.join(renders, moment, view + ".png")).convert(
        "RGB").resize((w, h), Image.LANCZOS)
    if reticle:
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, h // 2
        for c, wd in (((0, 0, 0), 3), ((255, 255, 255), 1)):
            d.line([(cx - 7, cy), (cx - 3, cy)], fill=c, width=wd)
            d.line([(cx + 3, cy), (cx + 7, cy)], fill=c, width=wd)
            d.line([(cx, cy - 7), (cx, cy - 3)], fill=c, width=wd)
            d.line([(cx, cy + 3), (cx, cy + 7)], fill=c, width=wd)
    return img


def grid(cells, cols, title, label_h=22, pad=6):
    """cells: [(image, label)], row-major."""
    w, h = cells[0][0].size
    rows = (len(cells) + cols - 1) // cols
    out = Image.new("RGB", (cols * (w + pad) + pad,
                            34 + rows * (h + label_h + pad) + pad), BG)
    d = ImageDraw.Draw(out)
    d.text((pad, 10), title, fill=INK)
    for i, (img, label) in enumerate(cells):
        x = pad + (i % cols) * (w + pad)
        y = 34 + (i // cols) * (h + label_h + pad)
        d.text((x, y + 4), label, fill=INK)
        out.paste(img, (x, y + label_h))
    return out


def gif(frames, delays, path):
    frames[0].save(path, save_all=True, append_images=frames[1:],
                   duration=delays, loop=0, optimize=True)


def layer_breakdown(path):
    """FW2: Foundry's layers, each sheet's frames x4 with their times,
    in draw order (back to front)."""
    sheets = json.load(open(os.path.join(FX, "fx.json")))
    names = sorted((k for k, v in sheets.items()
                    if k != "_kit" and v.get("weapon") == "foundry"),
                   key=lambda k: sheets[k]["order"])
    rows = []
    for name in names:
        s = sheets[name]
        img = Image.open(os.path.join(FX, s["file"])).convert("RGBA")
        cw, ch = s["cell"]
        k = 4 if cw <= 64 else 3 if cw <= 96 else 2
        strip = Image.new("RGBA", (s["frames"] * (cw * k + 8), ch * k), BG)
        for f in range(s["frames"]):
            cell = img.crop((f * cw, 0, (f + 1) * cw, ch)).resize(
                (cw * k, ch * k), Image.NEAREST)
            under = Image.new("RGBA", cell.size, BG + (255,))
            strip.paste(Image.alpha_composite(under, cell),
                        (f * (cw * k + 8), 0))
        rows.append((name, s, strip.convert("RGB")))
    width = max(r[2].size[0] for r in rows) + 330
    height = sum(r[2].size[1] + 26 for r in rows) + 40
    out = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(out)
    d.text((8, 10), "Foundry: the layers in draw order (1 = back). Frame "
           "times in ms; blend; size at the gun", fill=INK)
    y = 40
    for name, s, strip in rows:
        d.text((8, y + 4), "%d  %s" % (s["order"], name), fill=INK)
        d.text((8, y + 20), "%s  %s  %.2f m" % (
            "/".join(str(x) for x in s["durations_ms"]), s["blend"],
            s["size_m"]), fill=(160, 160, 160))
        d.text((8, y + 36), s["at"] if "at" in s else "", fill=(160, 160,
                                                                  160))
        out.paste(strip, (320, y))
        y += strip.size[1] + 26
    out.save(path)


def effect_sets(path):
    """FW8: every other weapon's sheets and the shared impacts and marks,
    frame 0..n, x3, on the dark ground."""
    sheets = json.load(open(os.path.join(FX, "fx.json")))
    order = ["sightline", "switchback", "bulkhead", "massdriver", "impacts",
             "marks"]
    rows = []
    for group in order:
        for name in sorted(k for k, v in sheets.items()
                           if k != "_kit" and v["weapon"] == group):
            s = sheets[name]
            img = Image.open(os.path.join(FX, s["file"])).convert("RGBA")
            cw, ch = s["cell"]
            k = 3 if cw <= 96 else 2
            strip = Image.new("RGB", (s["frames"] * (cw * k + 6),
                                      max(ch * k, 14)), BG)
            for f in range(s["frames"]):
                cell = img.crop((f * cw, 0, (f + 1) * cw, ch)).resize(
                    (cw * k, ch * k), Image.NEAREST)
                under = Image.new("RGBA", cell.size, BG + (255,))
                strip.paste(Image.alpha_composite(under, cell).convert("RGB"),
                            (f * (cw * k + 6), 0))
            rows.append(("%s  (%s ms)" % (name, "/".join(
                str(x) for x in s["durations_ms"])), strip))
    width = max(r[1].size[0] for r in rows) + 280
    height = sum(r[1].size[1] + 12 for r in rows) + 40
    out = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(out)
    d.text((8, 10), "The other four weapons' sets, and the shared material "
           "impacts and marks", fill=INK)
    y = 40
    for label, strip in rows:
        d.text((8, y + 2), label, fill=INK)
        out.paste(strip, (270, y))
        y += strip.size[1] + 12
    out.save(path)


def main(renders, specs, out):
    os.makedirs(out, exist_ok=True)
    # FW1: the Foundry time-lapse, three views a moment.
    cells = []
    for t in FOUNDRY_T:
        m = "foundry_t%03d" % t
        cells += [(shot(renders, m, "FP", 400, 225, True), "t = %d ms  FP" % t),
                  (shot(renders, m, "SIDE", 400, 225), "SIDE"),
                  (shot(renders, m, "CU", 400, 225), "CU (38 deg lens)")]
    grid(cells, 3, "FW1 Foundry: one shot at the steel plate, frozen at "
         "ten times (Prod's range, review/hand-cannon)").save(
        os.path.join(out, "FW1_foundry_timelapse.png"))
    # The GIFs: real time (each frame held until the next moment) and a
    # slow read (150 ms a moment).
    fp = [shot(renders, "foundry_t%03d" % t, "FP", 640, 360, True)
          for t in FOUNDRY_T]
    rest = shot(renders, "foundry_rest", "FP", 640, 360, True)
    real = [max(20, b - a) for a, b in zip(FOUNDRY_T, FOUNDRY_T[1:])]
    gif([rest] + fp + [rest], [400] + real + [300, 600],
        os.path.join(out, "FW1_foundry_fp_realtime.gif"))
    gif([rest] + fp, [500] + [180] * len(fp),
        os.path.join(out, "FW1_foundry_fp_slow.gif"))
    side = [shot(renders, "foundry_t%03d" % t, "SIDE", 640, 360)
            for t in FOUNDRY_T]
    gif(side, [180] * len(side), os.path.join(out, "FW1_foundry_side_slow.gif"))
    layer_breakdown(os.path.join(out, "FW2_foundry_layers.png"))
    # FW3: materials -- the hits, then only the marks, and in grey.
    cells = []
    for view, label in (("FP", "the player's view"), ("CU_METAL", "metal"),
                        ("CU_STONE", "stone floor"), ("CU_WALL", "stone wall"),
                        ("CU_FLESH", "gel (organic)"), ("CU_WOOD", "timber")):
        cells += [(shot(renders, "mat_hit", view, 400, 225, view == "FP"),
                   "%s: hit, 30 ms in" % label),
                  (shot(renders, "mat_after", view, 400, 225, view == "FP"),
                   "%s: the mark that stays" % label),
                  (shot(renders, "mat_hit", view + "_gray", 400, 225),
                   "%s: hit, grey" % label)]
    grid(cells, 3, "FW3 One Foundry hit on every material at once, then "
         "only the persistent marks (game scale)").save(
        os.path.join(out, "FW3_materials.png"))
    # FW3b: the same close-ups at NATIVE pixels, cropped at the centre
    # (each close-up camera looks straight at its hit, so the mark is
    # there): FW3's small cells hide what a mark actually draws.
    cells = []
    for view, label in (("CU_METAL", "metal"), ("CU_STONE", "stone floor"),
                        ("CU_WALL", "stone wall"), ("CU_FLESH", "gel"),
                        ("CU_WOOD", "timber")):
        for moment, when in (("mat_hit", "hit"), ("mat_after", "mark")):
            img = Image.open(os.path.join(renders, moment, view + ".png"))
            w, h = img.size
            cells.append((img.convert("RGB").crop(
                (w // 2 - 150, h // 2 - 150, w // 2 + 150, h // 2 + 150)),
                "%s: %s" % (label, when)))
    grid(cells, 4, "FW3b The close-ups at native pixels, centre crop "
         "(1600 x 900 frame, 38 deg lens, about 3 m)").save(
        os.path.join(out, "FW3b_marks_native.png"))
    # FW4: the five guns.
    cells = []
    for g in GUNS:
        cells += [(shot(renders, g + "_rest", "INSPECT", 400, 225),
                   "%s: beside the head, at rest" % g),
                  (shot(renders, g + "_rest", "FP", 400, 225, True),
                   "%s: rest" % g),
                  (shot(renders, g + "_fire", "FP", 400, 225, True),
                   "%s: the shot's frame (peak)" % g),
                  (shot(renders, g + "_m050", "FP", 400, 225, True),
                   "%s: 50 ms" % g)]
    grid(cells, 4, "FW4 The five guns: silhouette, rest, the shot's own "
         "frame and 50 ms later (reticle = overlay at screen centre)").save(
        os.path.join(out, "FW4_five_guns.png"))
    cells = [(shot(renders, g + "_fire", "FP_gray", 400, 225, True), g)
             for g in GUNS]
    cells += [(shot(renders, g + "_rest", "FP_gray", 400, 225, True),
               g + " rest") for g in GUNS]
    grid(cells, 5, "FW5 In grey: the shot's frame (top) and rest "
         "(bottom)").save(os.path.join(out, "FW5_five_guns_gray.png"))
    Image.open(os.path.join(specs, "recoil_signatures.png")).save(
        os.path.join(out, "FW6_recoil_signatures.png"))
    cells = []
    for m, label in (("massdriver_c000", "charge 0 %"),
                     ("massdriver_c050", "charge 50 %"),
                     ("massdriver_c100", "charge 100 %"),
                     ("massdriver_fire", "release")):
        cells += [(shot(renders, m, "INSPECT", 400, 225), label),
                  (shot(renders, m, "FP", 400, 225, True), label + ", FP")]
    grid(cells, 2, "FW7 Mass Driver: the accumulator rings slide and spin "
         "with the charge; the release").save(
        os.path.join(out, "FW7_massdriver_charge.png"))
    effect_sets(os.path.join(out, "FW8_effect_sets.png"))
    print("[sheets] FW1-FW8 in %s" % out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
