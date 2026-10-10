"""The weapon-family design exploration's sheets. EXPLORATION ONLY.
(Arty, 2026-10-10.)

    python3 tools/concept_art/weapon_concept_sheets.py OUT_DIR [RENDERS_DIR]

Writes WD0-WD7 (and WD8/WD9 when RENDERS_DIR holds the maquette study's
renders from `study_weapon_concepts.py` + `dcap.gd`) into OUT_DIR:

  WD0  where we are: Batch 068's five guns (from its own review sheet)
  WD1  four family directions, the same five mechanisms in each
  WD2  the energy principle: each store, stored / released / recovering
  WD3-WD7  one sheet per family: three mechanisms, the recommendation
       annotated, its states, and whose it could be (A / B / C)
  WD8  the maquettes in first person, four states each
  WD9  the lineup in grey (drawn silhouettes and the maquettes at rest)

Everything drawn here comes from `weapon_concepts.py`; nothing is final.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageOps

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import weapon_concepts as wc  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
PAPER = wc.PAPER
INK = wc.INK
SOFT = (110, 106, 98)
SIGN = "Arty, 2026-10-10. Exploration for the owner's reaction: not final art, not canon."

NAMES = {"foundry": "Foundry", "sightline": "Sightline",
         "switchback": "Switchback", "bulkhead": "Bulkhead",
         "massdriver": "Mass Driver"}
ORDER = ["foundry", "sightline", "switchback", "bulkhead", "massdriver"]


# ------------------------------------------------------------- helpers

def text(d, xy, s, size=17, bold=False, fill=INK, width=None, gap=4):
    """Draw `s`, wrapped to `width` px if given. Returns the bottom y."""
    f = wc.font(size, bold)
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
    text(d, (40, 26), title, 34, True)
    if sub:
        text(d, (40, 72), sub, 18, fill=SOFT, width=w - 80)
    text(d, (40, h - 34), SIGN, 14, fill=SOFT)
    return img, d


def tile(fn, state, d, style, w, h, scale=None, bounds=None):
    img, P = wc.render(fn(state, d), w, h, style, scale=scale,
                       bounds=bounds)
    return img.convert("RGB"), P


def family_frame(fam, w, h, pad=10):
    """One frame (bounds and scale) for all of a family's states, so a
    moving part reads as motion, not as the drawing being re-fitted."""
    xs0, ys0, xs1, ys1 = [], [], [], []
    for _, st in STATES[fam]:
        b = wc.FAMILIES[fam][0](st, "").bounds()
        xs0.append(b[0])
        ys0.append(b[1])
        xs1.append(b[2])
        ys1.append(b[3])
    b = (min(xs0), min(ys0), max(xs1), max(ys1))
    scale = min((w - 2 * pad) / (b[2] - b[0]), (h - 2 * pad) / (b[3] - b[1]))
    return b, scale


def frame(img, d, x, y, w, h):
    d.rectangle([x - 1, y - 1, x + w, y + h], outline=(196, 190, 178))


def callouts(img, d, g, P, items, ox, oy):
    """Leader lines from named anchors to labels. items: (anchor, label,
    dx, dy) with the label's offset from the anchor in px."""
    f = wc.font(16)
    for name, label, dx, dy in items:
        if name not in g.anchors:
            continue
        ax, ay = P(*g.anchors[name])
        ax, ay = ax + ox, ay + oy
        lx, ly = ax + dx, ay + dy
        d.line([(ax, ay), (lx, ly)], fill=(150, 90, 30), width=2)
        d.ellipse([ax - 4, ay - 4, ax + 4, ay + 4], outline=(150, 90, 30),
                  width=2)
        lines = label.split("\n")
        tw = max(d.textlength(t, font=f) for t in lines)
        bx = lx - tw - 8 if dx < 0 else lx + 6
        by = ly - 10
        for i, t in enumerate(lines):
            d.text((bx, by + i * 20), t, font=f, fill=(90, 50, 15))


# ------------------------------------------------------------ the data

STATES = {
    # name -> [(caption, state)] : hold / fire / recover / ready
    "foundry": [("hold: hammer up, crucible glowing", {"hammer": 68,
                                                       "glow": 1.0}),
                ("fire: the hammer falls", {"hammer": 0, "glow": 0.3,
                                            "flash": 1.0}),
                ("recover: it climbs back, re-glowing",
                 {"hammer": 32, "glow": 0.45}),
                ("ready: latched (Prod's mech, 0.5 s)",
                 {"hammer": 68, "glow": 1.0})],
    "sightline": [("hold: the bead at the front stop", {"bead": 1.0}),
                  ("fire: the tines snap and ring", {"bead": -1,
                                                     "ring": 1.0}),
                  ("recover: a new bead rides forward",
                   {"bead": 0.45, "ring": 0.35}),
                  ("ready: bead home, tines still", {"bead": 1.0})],
    "switchback": [("hold: the flyballs hang", {"spin": 0.0}),
                   ("fire (held): run-up, spread climbing",
                    {"spin": 0.45, "shuttle": 0.9, "flash": 1.0}),
                   ("sustained: flung out = 4 deg spread",
                    {"spin": 1.0, "shuttle": 0.1, "flash": 0.7}),
                   ("release: it coasts, the balls drop",
                    {"spin": 0.3, "shuttle": 0.5})],
    "bulkhead": [("hold: the hatch dogged shut", {"lever": 0}),
                 ("fire: eight ports vent at once", {"lever": 0,
                                                     "flash": 1.0}),
                 ("recover: the lever swings out, it hisses",
                  {"lever": 70}),
                 ("ready: the lever home, locked", {"lever": 0})],
    "massdriver": [("hold: the disc still, a slug loaded", {"spin": 0.0}),
                   ("charge: the spokes blur (the lean shows in WD8)",
                    {"spin": 0.6}),
                   ("full: a solid disc", {"spin": 1.0}),
                   ("release: it stops dead, the slug is gone",
                    {"spin": 0.0, "slug": False, "flash": 1.0})],
}

CALLOUTS = {
    "foundry": [("hammer", "forge hammer: raised = ready,\nit falls to fire",
                 -150, -30),
                ("crucible", "crucible (the heart):\nre-glows between shots",
                 60, 150),
                ("mouth", "the mouth is the muzzle:\nthe slug leaves molten",
                 70, -110),
                ("hinge", "rear hinge: the hammer\nclimbs back by itself",
                 -120, 40),
                ("device", "your device is the mount:\nno pistol grip",
                 -60, 110)],
    "sightline": [("upper tine", "two tines, side by side (inset):\ntension, "
                   "then a ring that flings", 0, -150),
                  ("bead", "the bead rides forward:\nits travel is the "
                   "cadence", -60, 120),
                  ("yoke", "resonator yoke (the heart)", -40, -150),
                  ("front post", "sight post: you aim\nthrough the slot",
                   -60, -60),
                  ("device", "your device is the mount", -60, 100)],
    "switchback": [("flyballs", "flyball governor: the spread\nyou can see "
                    "(hang = 1.2 deg, flung = 4)", 60, -40),
                   ("shuttle", "the shuttle switches back and\nforth: "
                    "alternating ports", 40, 130),
                   ("ports", "two short ports,\nleft / right", 30, 90),
                   ("brace", "a short brace\n(D-21's stock)", -40, -90),
                   ("device", "your device is the mount", -40, 110)],
    "bulkhead": [("hatch", "the hatch: eight ports\n= eight pellets", 60,
                  -150),
                 ("pressure drum", "pressure drum: the store", 60, 130),
                 ("dogging lever", "dogging lever, on top: swings up\nto vent, "
                  "home to lock (0.30 s)", 40, -120),
                 ("gauge", "gauge", -170, 70),
                 ("device", "your device is the mount", -80, 90)],
    "massdriver": [("flywheel", "flywheel (the heart): spokes,\nthen blur, "
                    "then solid = charge", -60, -150),
                   ("clutch", "clutch: bangs in on release,\nthe disc stops "
                    "dead", 40, 150),
                   ("hopper", "hopper drops the next slug", 40, -110),
                   ("slug", "slug in its cradle", 220, -30),
                   ("device", "your device is the mount", -70, 120)],
}

ALT_CAPTIONS = {
    "foundry": ["A, recommended: crucible and drop hammer. The wait is a "
                "hammer climbing back.",
                "B: pile driver. A puck drops and a piston punches it.",
                "C: kiln door. The front door swings open to fire."],
    "sightline": ["A, recommended: resonant tines. You aim through the "
                  "weapon.",
                  "B: surveyor. A theodolite head; the shot is a survey dart.",
                  "C: long baseline (from above). Too wide for the view."],
    "switchback": ["A, recommended: governor and shuttle. The spread, made "
                   "visible.",
                   "B: shuttle loom. A zigzag track; shows no spread.",
                   "C: escapement. Lovely, but a third big disc in the family."],
    "bulkhead": ["A, recommended: pressure hatch. The station's own door, "
                 "eight ports.",
                 "B: bellows. It breathes, but the bell is a blunderbuss.",
                 "C: clamshell. A mouth: Epsilon's language."],
    "massdriver": ["A, recommended: flywheel and clutch. Charge as blur, "
                   "release as a dead stop.",
                   "B: ballast sling. A great sag, but a crossbow.",
                   "C: captive mass. Alien, but near the 'charge orb'."],
}

ROLE = {
    "foundry": "D-21: a deliberate single shot, 0.65 s; two shots for 24 HP; "
               "clears a rated panel. The test: do you look forward to "
               "the next shot?",
    "sightline": "D-21: reach (60 m), steady precision, 0.40 s. Its risk "
                 "is overlapping the Static Pulse, so reach must be tangible.",
    "switchback": "D-21: hold to fire at 7 a second, tracking; inaccuracy "
                  "is spread (1.2 to 4 deg in Prod's range), never camera "
                  "climb.",
    "bulkhead": "D-21: close range, 8 pellets, 1.0 s; a heavy kick, then a "
                "pump-like return; one composite mark up close.",
    "massdriver": "D-21: hold to charge 1.2 s, release a visible heavy "
                  "slug, and move the world: crates, the weight, an enemy "
                  "off a ledge.",
}

DIRECTIONS = [
    ("A", "A: Station Instruments",
     "Repurposed facility apparatus. Institutional paint worn to metal, "
     "stencils, a carried tool's handle. Human, trustworthy, this "
     "building's own. Risk: sliding back to real tools."),
    ("B", "B: Epsilon's Readings",
     "Fabricated by Epsilon: machinery told to be a weapon. Near-black "
     "plate, asymmetric growths, one aperture lit from inside. "
     "Memorable and unsettling. Risk: reads as the enemy; green = power."),
    ("C", "C: Visitor Hearts",
     "A station carrier around a heart in a visited world's material "
     "(the accent here is a placeholder for the source identity "
     "package). Endless variants. Risk: ornament."),
    ("D", "D: Around the Device",
     "Every family clamps round the player's own device (the solid white "
     "shape here): the "
     "one constant across all five. Risk: every silhouette shares a "
     "core; whether it shows is Prod's and Dess's call."),
]

ENERGY = {
    "foundry": "HEAT + A RAISED MASS. Stored: the hammer up, the crucible "
               "hot. Released: the blow. Recovering: it climbs and re-glows.",
    "sightline": "TENSION IN A RESONATOR. Stored: tines held, the bead home. "
                 "Released: the snap and ring. Recovering: a bead rides "
                 "forward.",
    "switchback": "REGULATED ROTATION. Running up: the flyballs climb. Held: "
                  "flung out (max spread). Released: they fall back.",
    "bulkhead": "PRESSURE BEHIND A DOOR. Stored: the hatch dogged. Released: "
                "eight ports at once. Recovering: the lever swings, it "
                "re-pressurises.",
    "massdriver": "MOMENTUM IN A FLYWHEEL. Charging: the spokes blur. "
                  "Full: a solid disc. Released: a dead stop; the "
                  "slug carries the momentum.",
}


# ------------------------------------------------------------- sheets

def wd0(out):
    """Batch 068's five guns, cropped from its own review sheet."""
    src = os.path.join(REPO, "docs", "art", "review",
                       "five_weapons_2026-10-10", "FW4_five_guns.png")
    fw4 = Image.open(src).convert("RGB")
    img, d = page(2120, 820, "WD0: where we are",
                  "Batch 068's five guns, beside the head, at rest (from FW4). "
                  "Five different outlines of five familiar answers. Prod's "
                  "range placeholders are the same archetypes.")
    labels = ["Foundry: a revolver", "Sightline: a scoped rifle",
              "Switchback: a carbine", "Bulkhead: a double shotgun",
              "Mass Driver: a railgun with rings"]
    for i in range(5):
        y = 34 + i * (225 + 22 + 6) + 22
        crop = fw4.crop((6, y, 406, y + 225))
        x = 40 + i * 410
        img.paste(crop, (x, 140))
        img.paste(ImageOps.grayscale(crop).convert("RGB"), (x, 400))
        text(d, (x, 372), labels[i], 17, True)
    text(d, (40, 650), "What went wrong: I designed outlines, starting from "
         "\"what does a hand cannon look like?\". This exploration starts "
         "from what each weapon does and what would have to be inside it to "
         "do that.", 19, width=2040)
    img.save(os.path.join(out, "WD0_where_we_are.png"))


def wd1(out):
    tw, th = 300, 190
    img, d = page(40 + 380 + 5 * (tw + 12) + 30, 140 + 4 * (th + 40) + 70,
                  "WD1: four directions for the family",
                  "The same five mechanisms (Foundry, Sightline, Switchback, "
                  "Bulkhead, Mass Driver) drawn in each direction's "
                  "treatment. The recommendation is A's body, C's heart and "
                  "D's core, with B as a rare seasoning.")
    for r, (key, name, blurb) in enumerate(DIRECTIONS):
        y = 140 + r * (th + 40)
        text(d, (40, y), name, 22, True)
        text(d, (40, y + 32), blurb, 15, width=360)
        for c, fam in enumerate(ORDER):
            x = 40 + 380 + c * (tw + 12)
            t, _ = tile(wc.FAMILIES[fam][0], None, key, key, tw, th)
            img.paste(t, (x, y))
            frame(img, d, x, y, tw, th)
            if r == 0:
                text(d, (x, y - 24), NAMES[fam], 16, True)
    img.save(os.path.join(out, "WD1_directions.png"))


def wd2(out):
    tw, th = 330, 190
    cols = {"foundry": [0, 1, 2], "sightline": [0, 1, 2],
            "switchback": [0, 2, 3], "bulkhead": [0, 1, 2],
            "massdriver": [1, 2, 3]}
    img, d = page(40 + 420 + 3 * (tw + 14) + 30, 130 + 5 * (th + 46) + 60,
                  "WD2: stored energy, made visible",
                  "Each family stores its energy a different way, and the "
                  "store is the silhouette. Every state reads from MOTION, "
                  "so it needs no HUD and no colour.")
    for r, fam in enumerate(ORDER):
        y = 130 + r * (th + 46)
        text(d, (40, y), NAMES[fam], 22, True)
        text(d, (40, y + 32), ENERGY[fam], 15, width=400)
        b, sc = family_frame(fam, tw, th)
        for c, k in enumerate(cols[fam]):
            cap, st = STATES[fam][k]
            x = 40 + 420 + c * (tw + 14)
            t, _ = tile(wc.FAMILIES[fam][0], st, "", "sketch", tw, th,
                        scale=sc, bounds=b)
            img.paste(t, (x, y))
            frame(img, d, x, y, tw, th)
            text(d, (x, y + th + 4), cap, 14, fill=SOFT, width=tw)
    img.save(os.path.join(out, "WD2_energy_principle.png"))


def family_sheet(fam, out, index):
    W, H = 1840, 1560
    img, d = page(W, H, "WD%d: %s" % (index, NAMES[fam]), ROLE[fam])
    # Row 1: the three mechanisms.
    aw, ah = 560, 280
    y = 130
    text(d, (40, y), "Three mechanisms explored", 22, True)
    for i, fn in enumerate(wc.FAMILIES[fam]):
        x = 40 + i * (aw + 20)
        t, _ = tile(fn, None, "", "sketch", aw, ah)
        img.paste(t, (x, y + 34))
        frame(img, d, x, y + 34, aw, ah)
        text(d, (x, y + 34 + ah + 6), ALT_CAPTIONS[fam][i], 15,
             bold=(i == 0), width=aw)
    # Row 2: the recommendation, annotated, and its states.
    y = 520
    text(d, (40, y), "The recommendation, annotated", 22, True)
    bw, bh = 1060, 560
    g = wc.FAMILIES[fam][0](STATES[fam][0][1], "")
    big, P = wc.render(g, bw, bh, "sketch", pad=120)
    img.paste(big.convert("RGB"), (40, y + 34))
    frame(img, d, 40, y + 34, bw, bh)
    if fam == "bulkhead":
        face, _ = wc.render(wc.bulkhead_face(""), 200, 200, "sketch", pad=14)
        img.paste(face.convert("RGB"), (54, y + 48))
        text(d, (54, y + 252), "the face, from the front", 14, fill=SOFT)
    if fam == "sightline":
        plan, _ = wc.render(wc.sightline_plan(), 420, 120, "sketch", pad=10)
        img.paste(plan.convert("RGB"), (40 + bw - 434, y + 34 + bh - 150))
        text(d, (40 + bw - 434, y + 34 + bh - 26), "the fork from above: "
             "you look down the slot", 14, fill=SOFT)
    callouts(img, d, g, P, CALLOUTS[fam], 40, y + 34)
    sx = 40 + bw + 30
    text(d, (sx, y), "What the player sees it do", 22, True)
    sw, sh = 340, 200
    b, sc = family_frame(fam, sw, sh)
    for i, (cap, st) in enumerate(STATES[fam]):
        x = sx + (i % 2) * (sw + 16)
        yy = y + 34 + (i // 2) * (sh + 60)
        t, _ = tile(wc.FAMILIES[fam][0], st, "", "sketch", sw, sh,
                    scale=sc, bounds=b)
        img.paste(t, (x, yy))
        frame(img, d, x, yy, sw, sh)
        text(d, (x, yy + sh + 4), cap, 15, width=sw)
    # Row 3: whose it could be.
    y = 1150
    text(d, (40, y), "Whose it could be (design lenses, not lore)", 22, True)
    ww, wh = 420, 250
    for i, key in enumerate(("A", "B", "C")):
        x = 40 + i * (ww + 20)
        t, _ = tile(wc.FAMILIES[fam][0], STATES[fam][0][1], key, key, ww, wh)
        img.paste(t, (x, y + 34))
        frame(img, d, x, y + 34, ww, wh)
        text(d, (x, y + 34 + wh + 4), DIRECTIONS["ABC".index(key)][1], 15,
             bold=True)
    note = {"foundry": "Station: a materials-lab drop hammer. Epsilon: a "
                       "claw that grows back instead of a hinge. A visiting "
                       "world: the crucible's lining (the Foundry pack's "
                       "natural home).",
            "sightline": "Station: a resonance survey instrument. Epsilon: "
                         "tines grown unequal and barbed. A visiting world: "
                         "the yoke's material and the bead.",
            "switchback": "Station: an industrial motor's regulator. "
                          "Epsilon: a regulator that breathes. A visiting "
                          "world: the flyballs and their arms.",
            "bulkhead": "Station: a pressure door and drum. Epsilon: the "
                        "clamshell. A visiting world: the hatch's port "
                        "pattern and rim.",
            "massdriver": "Station: a cargo-handling flywheel. Epsilon: the "
                          "captive mass. A visiting world: the wheel's rim "
                          "and spokes, as material, never a replica."}[fam]
    text(d, (40 + 3 * (ww + 20), y + 40), note, 16, width=W - (40 + 3 *
                                                             (ww + 20)) - 40)
    img.save(os.path.join(out, "WD%d_%s.png" % (index, {
        "massdriver": "mass_driver"}.get(fam, fam))))


MAQ_STATES = {
    "foundry": [("hold", "hold: the hammer up"), ("fire", "fire: it falls, "
                "Batch 068's flash at the new mouth"),
                ("recover", "recover: it climbs back"),
                ("ready", "ready: latched")],
    "sightline": [("hold", "hold: the bead home"),
                  ("fire", "fire: the tines ring"),
                  ("recover", "recover: a bead rides forward"),
                  ("ready", "ready")],
    "switchback": [("hold", "hold: the flyballs hang"),
                   ("runup", "held: running up"),
                   ("sustained", "sustained: flung out = max spread"),
                   ("release", "release: coasting")],
    "bulkhead": [("hold", "hold: dogged shut"),
                 ("fire", "fire: eight ports"),
                 ("vent", "vent: the lever swings out"),
                 ("ready", "ready: locked")],
    "massdriver": [("hold", "hold: the disc still"),
                   ("charge", "charge: spokes blur, it leans"),
                   ("full", "full: a solid disc, leaning"),
                   ("release", "release: a dead stop")],
}


def _reticle(img):
    d = ImageDraw.Draw(img)
    cx, cy = img.size[0] // 2, img.size[1] // 2
    for col, wd in (((0, 0, 0), 3), ((255, 255, 255), 1)):
        for a, b in (((cx - 7, cy), (cx - 3, cy)), ((cx + 3, cy), (cx + 7, cy)),
                     ((cx, cy - 7), (cx, cy - 3)), ((cx, cy + 3), (cx, cy + 7))):
            d.line([a, b], fill=col, width=wd)
    return img


def wd8(out, renders):
    """The maquettes from the player's eye in Prod's range: four states
    each, plus the side elevation."""
    cw, ch = 400, 225
    img, d = page(40 + 5 * (cw + 12) + 30, 130 + 5 * (ch + 52) + 50,
                  "WD8: the five maquettes, from the player's eye",
                  "Throwaway blockouts (study_weapon_concepts.py), posed by "
                  "hand, photographed in Prod's range at his five-weapon rig "
                  "pose. The reticle is an overlay at the screen centre. "
                  "Firing states carry Batch 068's own muzzle sheets, moved "
                  "to each concept's mouth. Frozen poses, not animation.")
    for r, fam in enumerate(ORDER):
        y = 130 + r * (ch + 52)
        for c, (state, cap) in enumerate(MAQ_STATES[fam]):
            x = 40 + c * (cw + 12)
            p = os.path.join(renders, "%s_%s" % (fam, state), "FP.png")
            im = _reticle(Image.open(p).convert("RGB").resize((cw, ch),
                                                              Image.LANCZOS))
            img.paste(im, (x, y))
            text(d, (x, y + ch + 4), "%s, %s" % (NAMES[fam], cap), 14,
                 width=cw)
        x = 40 + 4 * (cw + 12)
        p = os.path.join(renders, "%s_hold" % fam, "INSPECT.png")
        im = Image.open(p).convert("RGB").resize((cw, ch), Image.LANCZOS)
        img.paste(im, (x, y))
        text(d, (x, y + ch + 4), "%s: side elevation (maquette)" %
             NAMES[fam], 14, width=cw)
    img.save(os.path.join(out, "WD8_first_person_states.png"))


def wd9_drawn(out, renders=None):
    """The five recommendations as solid black shapes at ONE scale, then
    (with renders) the maquettes at rest from the eye, in grey."""
    scale = 6.0
    widths = []
    for fam in ORDER:
        x0, _, x1, _ = wc.FAMILIES[fam][0](STATES[fam][0][1], "").bounds()
        widths.append(int((x1 - x0) * scale) + 20)
    img, d = page(max(2000, 80 + sum(widths) + 16 * 4),
                  860 if renders else 520,
                  "WD9: the lineup in grey",
                  "Silhouettes at one scale (6 px per cm): they separate by "
                  "kind, not by proportion. A block with a raised hammer; "
                  "an open fork; a box with a spinning T; a drum with a "
                  "door; a gun with a wheel.")
    x = 40
    for fam in ORDER:
        g = wc.FAMILIES[fam][0](STATES[fam][0][1], "")
        x0, y0, x1, y1 = g.bounds()
        w = int((x1 - x0) * scale) + 20
        t, _ = wc.render(g, w, 300, "silhouette", scale=scale, bg=PAPER)
        img.paste(t.convert("RGB"), (x, 140))
        text(d, (x, 450), NAMES[fam], 17, True)
        x += w + 16
    if renders:
        for i, fam in enumerate(ORDER):
            p = os.path.join(renders, "%s_hold" % fam, "FP_gray.png")
            if os.path.exists(p):
                im = Image.open(p).convert("RGB").resize((380, 214))
                img.paste(im, (40 + i * 392, 520))
                text(d, (40 + i * 392, 740), NAMES[fam] + ", from the eye "
                     "(maquette)", 15)
        text(d, (40, 790), "The maquettes at rest, from the player's eye in "
             "Prod's range, in grey: the dominant cue of each (hammer, tines, "
             "flyballs, hatch, wheel) sits low and right, clear of the "
             "reticle.", 17, width=1900)
    img.save(os.path.join(out, "WD9_lineup_gray.png"))


def main(out, renders=None):
    os.makedirs(out, exist_ok=True)
    wd0(out)
    wd1(out)
    wd2(out)
    for i, fam in enumerate(ORDER):
        family_sheet(fam, out, 3 + i)
    if renders:
        wd8(out, renders)
    wd9_drawn(out, renders)
    print("[wd] sheets in %s" % out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
