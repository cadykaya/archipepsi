"""Design pass 2's sheets: the hybrid direction at mechanism-approval
detail. EXPLORATION ONLY -- not models. (Arty, 2026-10-10.)

    python3 tools/concept_art/weapon_detail_sheets.py OUT_DIR

  WC0  the hybrid language: the power train, who owns what, materials,
       and the test every detail has to pass
  WC1  the fidelity ladder: blockout / intentional simplicity / functional
       detail / decorative noise, on the same hammer
  WC2-WC6  one sheet per weapon: the elevation with numbered parts, the
       parts list (owner and reason), the power train in section, the
       key mechanism exploded, and its states
  WC7  first-person readability: at speed, in play, up close
"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import detail_kit as dk  # noqa: E402
import weapon_concepts as wc  # noqa: E402
import weapon_details as wd  # noqa: E402

PAPER = dk.PAPER
INK = dk.INK
SOFT = (110, 106, 98)
SIGN = ("Arty, 2026-10-10. Design pass 2 for mechanism approval: not final "
        "art, not models, not canon.")
ORDER = ["foundry", "sightline", "switchback", "bulkhead", "massdriver"]
OWNER_FILL = {"yours": "yours", "station": "station", "epsilon": "epsilon",
              "echo": "echo", "ceramic": "ceramic", "heat": "heat",
              "steel": "steel", "glass": "glass", "energy": "glass"}
OWNER_NAME = {"yours": "yours", "station": "station", "epsilon": "Epsilon",
              "echo": "Echo core", "ceramic": "station", "heat": "station",
              "steel": "station", "glass": "station", "energy": "station"}


def text(d, xy, s, size=16, bold=False, fill=INK, width=None, gap=4,
         mono=False):
    f = dk.font(size, bold, mono)
    x, y = xy
    lines = []
    for para in s.split("\n"):
        if width is None:
            lines.append(para)
            continue
        cur = ""
        for word in para.split(" "):
            trial = (cur + " " + word).strip()
            if d.textlength(trial, font=f) <= width:
                cur = trial
            else:
                lines.append(cur)
                cur = word
        lines.append(cur)
    for ln in lines:
        d.text((x, y), ln, font=f, fill=fill)
        y += size + gap
    return y


def page(w, h, title, sub=None):
    img = Image.new("RGB", (w, h), PAPER)
    d = ImageDraw.Draw(img)
    text(d, (40, 24), title, 32, True)
    if sub:
        text(d, (40, 68), sub, 17, fill=SOFT, width=w - 80)
    text(d, (40, h - 32), SIGN, 13, fill=SOFT)
    return img, d


def frame(d, x, y, w, h):
    d.rectangle([x - 1, y - 1, x + w, y + h], outline=(196, 190, 178))


def paste(img, sub, x, y):
    img.paste(sub.convert("RGB"), (x, y))


def auto_balloons(img, P, g, numbers, ox, oy, box):
    """Balloons pushed outward from the drawing's centre, nudged apart."""
    x0, y0, x1, y1 = g.bounds()
    cx, cy = P((x0 + x1) / 2, (y0 + y1) / 2)
    placed = []
    place = {}
    for n in numbers:
        if n not in g.anchors:
            continue
        ax, ay = P(*g.anchors[n])
        dx, dy = ax - cx, ay - cy
        ln = math.hypot(dx, dy) or 1.0
        ux, uy = dx / ln, dy / ln
        dist = 64
        for _ in range(60):
            bx, by = ax + ux * dist, ay + uy * dist
            bx = min(max(bx, 16), box[0] - 16)
            by = min(max(by, 16), box[1] - 16)
            if all(math.hypot(bx - px, by - py) > 34 for px, py in placed):
                break
            dist += 10
        placed.append((bx, by))
        place[n] = (bx - ax, by - ay)
    dk.balloons(img, lambda x, y: P(x, y), g, numbers, place, ox, oy)


def parts_table(d, x, y, w, parts):
    f = dk.font(14)
    for n, name, owner, kind, why in parts:
        d.ellipse([x, y, x + 24, y + 24], fill=(255, 252, 244),
                  outline=dk.CALL, width=2)
        t = str(n)
        d.text((x + 12 - d.textlength(t, font=dk.font(13, True)) / 2, y + 4),
               t, font=dk.font(13, True), fill=dk.CALL)
        sw = dk.FILL[OWNER_FILL.get(owner, "station")]
        d.rectangle([x + 32, y + 4, x + 48, y + 20], fill=sw,
                    outline=INK)
        d.text((x + 56, y + 1), name, font=dk.font(14, True), fill=INK)
        tag = "%s / %s" % (OWNER_NAME.get(owner, owner), kind)
        d.text((x + 56, y + 19), tag, font=dk.font(12), fill=SOFT)
        yy = text(d, (x + 56, y + 36), why, 13, width=w - 60, gap=2)
        y = max(y + 56, yy + 6)
    return y


def frame_for(fn, states, w, h, pad=14):
    xs0, ys0, xs1, ys1 = [], [], [], []
    for _, st in states:
        b = fn(**st).bounds()
        xs0.append(b[0])
        ys0.append(b[1])
        xs1.append(b[2])
        ys1.append(b[3])
    b = (min(xs0), min(ys0), max(xs1), max(ys1))
    return b, min((w - 2 * pad) / (b[2] - b[0]), (h - 2 * pad) /
                  (b[3] - b[1]))


# ------------------------------------------------------------------ WC0

POWER = [
    ("Foundry", "an ingot cartridge", "heat lattice", "crucible, hammer",
     "heat + a raised mass"),
    ("Sightline", "a tuning seed", "resonance drivers", "tines, dampers",
     "tension in a resonator"),
    ("Switchback", "a rotor", "motor", "governor, shuttle, cutter",
     "regulated rotation"),
    ("Bulkhead", "a pressure charge", "compressor", "drum, hatch, dogs",
     "pressure behind a door"),
    ("Mass Driver", "a dense hub", "field drive", "flywheel, clutch",
     "momentum"),
]

KIND_TESTS = [
    ("mechanical", "it moves, or makes something move: pawl, strut, cam, "
     "clutch"),
    ("structural", "it carries a load: rail, post, hoop band, cradle"),
    ("thermal", "heat leaves or is kept out here: fins, spacers, vents"),
    ("energy", "power or force travels through it: core, converter, loom"),
    ("mounting", "it fixes the family to your device: clamps"),
    ("maintenance", "a person could service it: screws, inserts, hinges"),
    ("readout", "it tells the player a state: gauge, flyballs, bead"),
    ("safety", "it protects someone: guard ring, relief valve, tip caps"),
]


def wc0(out):
    img, d = page(2100, 1260, "WC0: the hybrid language",
                  "The owner's choice: station-built engineering, Epsilon "
                  "technology and foreign-world Echo cores. Each weapon "
                  "becomes a three-stage power train, one stage per origin, "
                  "so the hybrid is a story the player can follow along the "
                  "gun, not a mix of styles.")
    y = 130
    boxes = [("ECHO CORE", "the visiting world", "the SOURCE of the "
              "capability. Swappable. Its material and accent come from "
              "the source game's identity package.", "echo"),
             ("EPSILON", "the converter", "turns that source into one form "
              "of energy. Dense black plate at a manufacture the station "
              "doesn't use; lit only through its seams; it bursts through "
              "station plate (it is embedded, never placed).", "epsilon"),
             ("STATION", "the mechanism", "stores the energy, delivers it, "
              "and survives it: frames, linkages, guards, fasteners, "
              "stencils, paint worn to metal where it works.", "station")]
    for i, (title, sub, body, role) in enumerate(boxes):
        x = 40 + i * 640
        d.rectangle([x, y, x + 560, y + 230], fill=dk.FILL[role],
                    outline=INK, width=3)
        col = (240, 240, 240) if role == "epsilon" else INK
        text(d, (x + 20, y + 16), title, 26, True, fill=col)
        text(d, (x + 20, y + 52), sub, 17, fill=col)
        text(d, (x + 20, y + 86), body, 15, fill=col, width=520)
        if i < 2:
            d.polygon([(x + 575, y + 100), (x + 620, y + 115),
                       (x + 575, y + 130)], fill=dk.ENERGY)
    text(d, (40, y + 244), "The player's own device is the fourth owner: "
         "every family clamps round it (pale blue-white in the drawings).",
         16, fill=SOFT)
    # the five power trains
    y = 420
    text(d, (40, y), "The five power trains", 22, True)
    cols = [40, 300, 600, 900, 1260]
    heads = ["weapon", "Echo core (source)", "Epsilon (converter)",
             "station (mechanism)", "the energy it stores"]
    for c, h in zip(cols, heads):
        text(d, (c, y + 36), h, 15, True)
    for r, row in enumerate(POWER):
        yy = y + 64 + r * 30
        for c, v in zip(cols, row):
            text(d, (c, yy), v, 15)
    # materials
    y = 640
    text(d, (40, y), "Materials, by owner (concept colours)", 22, True)
    sw = [("yours", "your device"), ("station", "station paint"),
          ("station_dark", "station dark steel"), ("steel", "bare steel"),
          ("dark", "dark steel, ports"), ("rubber", "rubber"),
          ("ceramic", "ceramic heat-breaks"), ("heat", "heat-tinted steel"),
          ("epsilon", "Epsilon plate"), ("echo", "Echo core (placeholder)")]
    for i, (role, name) in enumerate(sw):
        x = 40 + (i % 5) * 400
        yy = y + 40 + (i // 5) * 50
        d.rectangle([x, yy, x + 36, yy + 36], fill=dk.FILL[role],
                    outline=INK, width=2)
        text(d, (x + 48, yy + 8), name, 15)
    text(d, (40, y + 150), "Epsilon's light is its seams only (green, the "
         "art bible's identity hue; green-for-power overlap is FU-4, still "
         "open). Heat glows where heat is. No other light, no strips.", 15,
         fill=SOFT, width=1960)
    # the detail test
    y = 860
    text(d, (40, y), "The test every detail has to pass: name its job", 22,
         True)
    for i, (kind, test) in enumerate(KIND_TESTS):
        x = 40 + (i % 2) * 1000
        yy = y + 40 + (i // 2) * 34
        text(d, (x, yy), kind, 16, True)
        text(d, (x + 140, yy), test, 16)
    text(d, (40, y + 190), "A part that answers none of these is "
         "decoration, and it goes. Ordering, from the owner: functional "
         "sci-fi detail > intentional simplicity > meaningless decorative "
         "detail.", 17, True, width=1960)
    img.save(os.path.join(out, "WC0_hybrid_language.png"))


# ------------------------------------------------------------------ WC1

def _simple_hammer():
    g = dk.D("intentional simplicity")
    g.rect(-12, -2.6, 16, 4.6, "station", chamfer=0.8, lw=1.5)
    g.poly([(-10.5, 4.6), (-3.4, 4.6), (-4.4, 17.8), (-9.6, 17.8)],
           "station", lw=1.5)
    a = math.radians(68)
    px, py = -6.8, 17.0
    hx, hy = px + 19.5 * math.cos(a), py + 19.5 * math.sin(a)
    g.bar((px, py), (hx, hy), 3.0, "steel", lw=1.4)
    g.poly(dk.rot([(hx - 4, hy - 3.6), (hx + 4, hy - 3.6), (hx + 4, hy + 3.8),
                   (hx - 4, hy + 3.8)], hx, hy, 68), "steel", lw=1.5)
    g.circle(px, py, 2.4, "steel", lw=1.0)
    g.rect(9.6, 13.0, 17.8, 16.4, "steel", chamfer=0.6, lw=1.0)
    g.poly([(10, -4.6), (36, -3.0), (37.6, 12.2), (11, 13.0)], "station",
           lw=1.6)
    return g


def _noise_hammer():
    """What the owner ruled out: decoration that does nothing."""
    g = _simple_hammer()
    g.name = "decorative noise"
    for y in (-1.0, 1.6):
        g.seam([(-11, y), (15, y)], 1.0)
    g.seam([(11.5, 9.5), (35.5, 9.0)], 1.0)
    g.seam([(-9.6, 8), (-4.8, 8)], 1.0)
    for x in (14, 18, 22, 26, 30):
        g.rect(x, 1.0, x + 2.6, 6.0, "dark", lw=0.4)
        for k in range(4):
            g.line([(x + 0.2, 1.6 + k * 1.2), (x + 2.4, 1.6 + k * 1.2)],
                   (150, 150, 150), 0.3)
    g.poly([(36, 11.8), (40, 16.0), (37.4, 12.6)], "dark", lw=0.6)
    g.poly([(36.2, -2.6), (40.4, -6.8), (37.6, -2.4)], "dark", lw=0.6)
    g.line([(-11.4, 3.8), (-4, 3.8), (-4, -2.0)], (100, 100, 100), 0.4)
    g.line([(12, 0), (20, 0), (22, 4), (34, 4)], (100, 100, 100), 0.4)
    for x in (13, 20, 27, 34):
        g.circle(x, 11.0, 0.5, "dark", n_sides=8, lw=0.2)
    return g


def wc1(out):
    w, h = 470, 560
    img, d = page(4 * (w + 20) + 60, h + 330, "WC1: the fidelity ladder",
                  "The same forge hammer and breech at four levels, in the "
                  "owner's order of preference. The target is the third: "
                  "detail that is mechanism. The fourth is what we will not "
                  "do.")
    bounds = (-14, -6, 40, 36)
    panels = []
    old, _ = wc.render(wc.foundry_hammer({"hammer": 68}, ""), w, h,
                       "sketch", bounds=bounds, pad=20)
    panels.append(("1. Blockout (pass 1)", "Enough to judge a silhouette and "
                   "a motion. Not a style: it is what Unturned-like reads "
                   "come from if it ships.", old, "NOT FOR PRODUCTION"))
    simple, _ = dk.render(_simple_hammer(), w, h, bounds=bounds)
    panels.append(("2. Intentional simplicity", "Clean, chamfered, honest "
                   "forms. Readable, but it can't tell you how it works, so "
                   "it reads as a prop.", simple, "ACCEPTABLE, NOT THE GOAL"))
    full, _ = dk.render(wd.foundry(), w, h, bounds=bounds)
    panels.append(("3. Functional detail (the target)", "Every added part "
                   "has a job: the strut that re-cocks it, the pawl that "
                   "holds it, the spacer that keeps the frame cool, the "
                   "fins where the heat is, the Epsilon lattice where the "
                   "impossible happens, wear where hands and heat work.",
                   full, "THE TARGET"))
    noise, _ = dk.render(_noise_hammer(), w, h, bounds=bounds)
    panels.append(("4. Decorative noise (ruled out)", "Glowing lines that "
                   "carry nothing, vents where there is no heat, panel lines "
                   "and spikes that change nothing. More detail, less "
                   "design.", noise, "RULED OUT"))
    for i, (title, body, im, verdict) in enumerate(panels):
        x = 40 + i * (w + 20)
        y = 130
        paste(img, im, x, y)
        frame(d, x, y, w, h)
        col = {"THE TARGET": (40, 120, 60), "RULED OUT": (160, 50, 40)}.get(
            verdict, SOFT)
        text(d, (x, y + h + 10), title, 18, True)
        text(d, (x, y + h + 38), verdict, 14, True, fill=col)
        text(d, (x, y + h + 62), body, 14, width=w)
    img.save(os.path.join(out, "WC1_fidelity_ladder.png"))


# ------------------------------------------------------------ WC2-WC6

def weapon_sheet(key, out, index):
    spec = wd.WEAPONS[key]
    W, H = 2240, 1560
    img, d = page(W, H, "WC%d: %s, hybrid design (mechanism for approval)"
                  % (index, spec["name"]),
                  "Echo core (source) -> Epsilon (converter) -> station "
                  "(mechanism). Every numbered part has an owner and a job; "
                  "the list on the right says which.")
    # the elevation
    bw, bh = 1400, 860
    g = spec["draw"](**spec["states"][0][1])
    big, P = dk.render(g, bw, bh, pad=70)
    paste(img, big, 40, 120)
    frame(d, 40, 120, bw, bh)
    numbers = [p[0] for p in spec["parts"]]
    auto_balloons(img, P, g, numbers, 40, 120, (bw, bh))
    # the parts list
    tx = 40 + bw + 30
    text(d, (tx, 120), "Parts: owner / job / why", 20, True)
    parts_table(d, tx, 156, W - tx - 40, spec["parts"])
    # under the elevation: the power train in section, the key mechanism
    # exploded, and what it does (fixed frame)
    y = 120 + bh + 30
    cw, ew, stw, ph = 560, 420, bw - 560 - 420 - 40, 470
    cut, _ = dk.render(spec["cutaway"](), cw, ph, pad=26)
    paste(img, cut, 40, y + 30)
    frame(d, 40, y + 30, cw, ph)
    text(d, (40, y), "The power train, in section (orange: energy)", 17,
         True)
    exp, _ = dk.render(spec["exploded"](), ew, ph, pad=26)
    paste(img, exp, 60 + cw, y + 30)
    frame(d, 60 + cw, y + 30, ew, ph)
    text(d, (60 + cw, y), "The key mechanism, exploded", 17, True)
    sx = 80 + cw + ew
    text(d, (sx, y), "What it does", 17, True)
    th = (ph - 3 * 26) // 3
    b, sc = frame_for(spec["draw"], spec["states"], stw, th)
    for i, (cap, st) in enumerate(spec["states"]):
        yy = y + 30 + i * (th + 26)
        im, _ = dk.render(spec["draw"](**st), stw, th, scale=sc, bounds=b,
                          pad=8)
        paste(img, im, sx, yy)
        frame(d, sx, yy, stw, th)
        text(d, (sx, yy + th + 3), cap, 13, width=stw)
    names = {"massdriver": "mass_driver"}
    img.save(os.path.join(out, "WC%d_%s.png" % (index, names.get(key, key))))


# ------------------------------------------------------------------ WC7

def wc7(out):
    img, d = page(2160, 1260, "WC7: first-person readability, three distances",
                  "Detail must reward inspection without blurring the read in "
                  "play. AT SPEED: small, grey, motion-blurred, roughly what "
                  "peripheral vision gets while moving and firing; only the "
                  "silhouette and the moving cue should survive. IN PLAY: "
                  "the size a viewmodel takes on screen. UP CLOSE: the zone "
                  "nearest the eye, where texture and fastener detail belong.")
    for r, key in enumerate(ORDER):
        spec = wd.WEAPONS[key]
        g = spec["draw"](**spec["states"][0][1])
        y = 140 + r * 210
        text(d, (40, y + 70), spec["name"], 20, True)
        small, _ = dk.render(g, 220, 140, pad=8)
        small = small.convert("L").filter(ImageFilter.BoxBlur(0)).convert(
            "RGB")
        k = Image.new("RGB", small.size, PAPER)
        for dx in range(-6, 7, 2):
            k = Image.blend(k, small.transform(small.size, Image.AFFINE,
                                               (1, 0, dx, 0, 1, 0),
                                               fillcolor=PAPER), 0.3)
        paste(img, k.resize((300, 190)), 230, y)
        frame(d, 230, y, 300, 190)
        mid, _ = dk.render(g, 520, 190, pad=10)
        paste(img, mid, 560, y)
        frame(d, 560, y, 520, 190)
        full, P = dk.render(g, 2000, 1250, pad=60)
        x0, y0, x1, y1 = g.bounds()
        # the rear-upper third: nearest the eye in first person
        ax, ay = P(x0 + (x1 - x0) * 0.05, y1)
        bx, by = P(x0 + (x1 - x0) * 0.45, y0 + (y1 - y0) * 0.35)
        crop = full.crop((int(ax), int(ay), int(bx), int(by))).convert("RGB")
        crop = crop.resize((int(190 * crop.size[0] / max(1, crop.size[1])),
                            190))
        crop = crop.crop((0, 0, min(crop.size[0], 1020), 190))
        paste(img, crop, 1110, y)
        frame(d, 1110, y, crop.size[0], 190)
    text(d, (230, 1200), "at speed", 15, True, fill=SOFT)
    text(d, (560, 1200), "in play", 15, True, fill=SOFT)
    text(d, (1110, 1200), "up close: the rear-upper zone nearest the eye",
         15, True, fill=SOFT)
    img.save(os.path.join(out, "WC7_readability.png"))


def main(out):
    os.makedirs(out, exist_ok=True)
    wc0(out)
    wc1(out)
    for i, key in enumerate(ORDER):
        weapon_sheet(key, out, 2 + i)
    wc7(out)
    print("[wc] sheets in %s" % out)


if __name__ == "__main__":
    main(sys.argv[1])
