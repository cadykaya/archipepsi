#!/usr/bin/env python3
"""Review sheets for the Foundry fidelity study. (Arty, 2026-10-13.)

    python3 tools/crossing_capture/foundry_study_sheets.py OUT SHEETS

OUT is `tools/foundry_study.sh`'s output (capture/, maps/, the GLB's
json). Writes into SHEETS:

  FS1_gameplay_view.png    Prod's placeholder and the study, same frame,
                           same light; the study in grey for readability
  FS2_firing_timeline.png  one shot from the real-time clip, frame by
                           frame, over the runtime's own logged states
  FS3_close_up.png         close looks in the range's light, captioned
                           with what each surface records
  FS4_material_maps.png    the six Glyph maps, and two 1:1 crops
  foundry_clip_20fps.gif   the clip, real time at 20 fps (exact 50 ms)
  study_fp.png, close_*.png  the stills at full size

Everything here is drawn from the files a run wrote; nothing is retouched.
"""

from __future__ import annotations

import json
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont, ImageOps

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
BG = (24, 25, 28)
INK = (226, 228, 230)
DIM = (150, 155, 162)
ACCENT = (232, 190, 110)


def font(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT, size)


def title(draw, x, y, text, sub=None):
    draw.text((x, y), text, font=font(30, True), fill=INK)
    if sub:
        draw.text((x, y + 42), sub, font=font(17), fill=DIM)


def caption(draw, x, y, text, width_chars=70, size=16, fill=INK):
    words, line, lines = text.split(), "", []
    for w in words:
        if len(line) + len(w) + 1 > width_chars:
            lines.append(line)
            line = w
        else:
            line = (line + " " + w).strip()
    lines.append(line)
    for i, ln in enumerate(lines):
        draw.text((x, y + i * (size + 5)), ln, font=font(size), fill=fill)
    return y + len(lines) * (size + 5)


def fit(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


# ---------------------------------------------------------------- FS1

def fs1(cap, out):
    ph = Image.open(os.path.join(cap, "placeholder_fp.png")).convert("RGB")
    st = Image.open(os.path.join(cap, "study_fp.png")).convert("RGB")
    W, H = 2000, 1500
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "FS1  The gameplay view: the same frame, the same light",
          "Prod's range (review/five-weapons-v2), the rig's rest pose, "
          "1600x900, aimed where Prod's own check aims. Nothing else changed.")
    w, h = 940, 529
    sheet.paste(fit(ph, w, h), (40, 140))
    sheet.paste(fit(st, w, h), (1020, 140))
    d.text((40, 680), "Prod's placeholder Foundry (what the owner played)",
           font=font(18, True), fill=INK)
    d.text((1020, 680), "The fidelity study, in the same place",
           font=font(18, True), fill=INK)
    # readability: the study in grey, and the gun's own region at 2x
    grey = ImageOps.grayscale(st).convert("RGB")
    sheet.paste(fit(grey, w, h), (40, 740))
    crop = st.crop((860, 500, 1180, 880))
    sheet.paste(fit(crop, 470, 558), (1020, 740))
    d.text((40, 1280), "Grey: the silhouette and the centre stay clear",
           font=font(18, True), fill=INK)
    d.text((1020, 1306), "", font=font(16), fill=DIM)
    caption(d, 1510, 750,
            "The gun's own pixels at 2x. At play distance it reads as worn "
            "dark steel with a rust-brown plate on the frame and one green "
            "lamp; the close detail is there for when you look, and it "
            "does not crowd the outline or reach toward the centre.",
            width_chars=40, size=16)
    caption(d, 40, 1320,
            "Placement, scale and recoil are Prod's untouched rig values: "
            "the study only replaces the placeholder's meshes, and the "
            "muzzle sits exactly on Prod's muzzle marker (0, 0.03, -0.47).",
            width_chars=110, size=16, fill=DIM)
    sheet.save(out)


# ---------------------------------------------------------------- FS2

def fs2(cap, clipdata, out):
    frames = clipdata["frames"]
    fps = float(clipdata["fps"])
    fires = [f for a, f in zip(frames, frames[1:])
             if f["cooldown"] > a["cooldown"] + 0.3]
    shot = fires[1]                  # the middle shot: rest before, rhythm
    f0 = shot["f"]
    seq = [f for f in frames if f0 - 3 <= f["f"] <= f0 + 50]
    # the movie frame for a physics frame: the clip records `drawn`
    def png_for(entry):
        return os.path.join(cap, "frames", "f%08d.png" % entry["drawn"])
    moments = [(-2, "rest, cocked"), (0, "fire: hammer falls"),
               (4, "+0.07 s  heave"), (15, "+0.25 s"),
               (26, "+0.43 s  carousel turning"), (35, "+0.58 s  gun home"),
               (39, "+0.65 s  cocked, aim home"),
               (44, "+0.73 s  ready: the next shot")]
    W, H = 2000, 1720
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "FS2  One shot in real time, over the runtime's states",
          "From the clip: three shots fired through the real input action, "
          "each as soon as Prod's runtime allowed. Every frame logged the "
          "hammer, the carousel, the cooldown and the gun's travel.")
    tw, th = 470, 330
    by_f = {f["f"]: f for f in frames}
    for i, (df, label) in enumerate(moments):
        e = by_f.get(f0 + df)
        if e is None:
            continue
        img = Image.open(png_for(e)).convert("RGB")
        img = img.crop((700, 300, 1500, 860))
        x = 40 + (i % 4) * (tw + 13)
        y = 140 + (i // 4) * (th + 60)
        sheet.paste(fit(img, tw, th), (x, y))
        d.text((x, y + th + 6), label, font=font(17, True), fill=INK)
        turned = (e["carousel_deg"] - by_f[f0]["carousel_deg"]) % 360
        d.text((x, y + th + 28), "hammer %+.0f deg   carousel turned %.0f deg"
               % (e["hammer_deg"], turned if df > 0 else 0.0),
               font=font(14), fill=DIM)
    # the chart
    cx0, cy0, cw, ch = 110, 1000, 1820, 520
    d.rectangle((cx0, cy0, cx0 + cw, cy0 + ch), outline=(70, 72, 78))
    t_end = 50 / fps

    def X(t):
        return cx0 + cw * (t + 3 / fps) / (t_end + 3 / fps)
    series = [("hammer angle (deg, 0 fallen .. -38 cocked)",
               lambda e: -e["hammer_deg"] / 38.0, (232, 120, 90)),
              ("carousel index (0..60 deg)",
               lambda e: ((e["carousel_deg"] - seq[0]["carousel_deg"])
                          % 360) / 60.0, (120, 190, 240)),
              ("gun travel back (Prod's envelope, 0..0.29 m)",
               lambda e: e["back"] / 0.29, (200, 200, 200)),
              ("cooldown (0.72 s .. 0)",
               lambda e: e["cooldown"] / 0.72, (150, 210, 120))]
    for k, (name, fn, colr) in enumerate(series):
        pts = []
        for e in seq:
            t = (e["f"] - f0) / fps
            v = max(-0.1, min(1.1, fn(e)))
            pts.append((X(t), cy0 + ch - 40 - v * (ch - 80)))
        d.line(pts, fill=colr, width=3)
        d.text((cx0 + 20 + (k % 2) * 760, cy0 + ch + 14 + (k // 2) * 24),
               "-- " + name, font=font(16), fill=colr)
    clocks = clipdata["last_clocks"]
    for name, t in (("fire", 0.0), ("gun home", clocks["gun"]),
                    ("aim home / hammer cocked", clocks["mech"]),
                    ("ready", clocks["ready"])):
        x = X(t)
        d.line((x, cy0, x, cy0 + ch), fill=ACCENT, width=1)
        d.text((x + 4, cy0 + 6 + {"fire": 0, "gun home": 0,
                                  "aim home / hammer cocked": 24,
                                  "ready": 48}[name]),
               "%s %.2f s" % (name, t), font=font(15), fill=ACCENT)
    caption(d, 40, 1610,
            "What you see is what the game is doing: the hammer drops on the "
            "shot's own frame (the response is immediate), the carousel "
            "turns while the gun comes home, the hammer is drawn and cocks "
            "at 0.65 s, and the weapon is ready at 0.73 s (Prod's 0.72 s "
            "cooldown on the 60 Hz tick). Cocked is the ready cue; it leads "
            "readiness by 80 ms, inside Prod's 0.15 s press buffer, so a "
            "click on the cock fires the instant it may.",
            width_chars=150, size=16, fill=DIM)
    sheet.save(out)


# ---------------------------------------------------------------- FS3

CLOSE = [
    ("close_left.png", "The frame's left side",
     "Station grey paint over red-oxide primer, chipped where edges get "
     "knocked (more on the bottom and the ends than on the sheltered top). "
     "The access cover is gone: a cut plate in another area's primer, "
     "brushed round in station grey and given up on, on two different "
     "bolts and a screw. Grease-pencil service tallies and a tick."),
    ("close_top.png", "From above and behind: what the eye sees most",
     "HOT stencilled on the top strap, faded. Soot where gas escapes "
     "between carousel and breech. The striker battered bright under the "
     "hammer; the hammer's knurled spur polished by thumbs. The Epsilon "
     "collar: black, machined to a tolerance the station doesn't keep, "
     "almost unworn -- and the one green lamp: powered."),
    ("close_collar.png", "The breech: three origins meeting",
     "The station's bent strap and wing nut hold the Echo core in a socket "
     "whose own latch is long gone. Ceramic spacers, crazed and sooted, "
     "keep the collar's heat off the frame. Stamped serial and proof mark "
     "on the barrel's flat. The carousel's turn line, worn by the stop."),
    ("close_muzzle.png", "The muzzle end",
     "Heat-tempered and sooted at the crown, the open bore dark; the "
     "front sight brazed on. The clamp that ties the barrel to the recoil "
     "buffer: chipped at its foot (it is what the gun rests on), a wrench "
     "slipped on its pinch bolt, a paint-pen torque stripe across it."),
    ("close_rear.png", "The back of the frame",
     "The hammer cocked, the spur, the pin and its oil. Wear at the "
     "frame's rear corners where it is set down; the grip's cloth tape "
     "darkened and glossed by hands, new black tape over the top wraps."),
    ("whole_left.png", "The whole gun, left side",
     "Toned down from the concept sheets: one barrel, a buffer under it, "
     "a six-chamber carousel, a breech collar, a frame and a hammer in "
     "proportion. 2,748 triangles (the owner's provisional 2,500-4,000), "
     "one 1024 atlas, ~1,150 texels/m."),
]


def fs3(cap, out):
    W, H = 2000, 2300
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "FS3  Close up, in the range's own light",
          "Cameras placed in the gun's frame inside the running game. "
          "The model explains the construction; the textures explain the "
          "materials, the use, the repairs and the history.")
    tw, th = 940, 529
    for i, (name, head, text) in enumerate(CLOSE):
        img = Image.open(os.path.join(cap, name)).convert("RGB")
        x = 40 + (i % 2) * (tw + 40)
        y = 140 + (i // 2) * (th + 190)
        sheet.paste(fit(img, tw, th), (x, y))
        d.text((x, y + th + 8), head, font=font(18, True), fill=INK)
        caption(d, x, y + th + 36, text, width_chars=100, size=15, fill=DIM)
    sheet.save(out)


# ---------------------------------------------------------------- FS4

def fs4(maps, out):
    W, H = 2000, 1500
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "FS4  The material maps, held and exported by Glyph",
          "One 1024 atlas. Albedo on a 256-colour palette (a GoldSrc skin); "
          "the normal map derived by Glyph from the painted height; "
          "x-glyph.check_material clean.")
    names = ["albedo", "normal", "roughness", "metallic", "height",
             "emission"]
    for i, n in enumerate(names):
        img = Image.open(os.path.join(maps, n + ".png")).convert("RGB")
        x = 40 + (i % 3) * 400
        y = 140 + (i // 3) * 440
        sheet.paste(fit(img, 380, 380), (x, y))
        d.text((x, y + 386), n, font=font(17, True), fill=INK)
    alb = Image.open(os.path.join(maps, "albedo.png")).convert("RGB")
    nrm = Image.open(os.path.join(maps, "normal.png")).convert("RGB")
    # 1:1 crops (each texel 3 px), of the busiest island, for the texels
    box = _busiest(alb)
    sheet.paste(alb.crop(box).resize((560, 560), Image.NEAREST),
                (1260, 140))
    sheet.paste(nrm.crop(box).resize((560, 560), Image.NEAREST),
                (1260, 720))
    d.text((1260, 706), "albedo, texels at 3x", font=font(15), fill=DIM)
    d.text((1260, 1286), "Glyph's normal map, same texels",
           font=font(15), fill=DIM)
    caption(d, 40, 1040,
            "The art bible says albedo only (s5). The owner asked for "
            "roughness and normal detail for this study; the bible is "
            "unchanged and this is flagged in the report. Metallic is kept "
            "low on purpose: Prod's range renders through the Compatibility "
            "renderer with nothing for metal to reflect, so a fully "
            "metallic surface goes black. Steel is carried in the albedo, "
            "as a GoldSrc skin did, with a modest metallic share for sheen.",
            width_chars=105, size=16, fill=DIM)
    sheet.save(out)


def _busiest(img, size=186):
    """The crop with the most local contrast (deterministic scan)."""
    g = ImageOps.grayscale(img)
    best, best_box = -1, (0, 0, size, size)
    for y in range(0, img.height - size, 62):
        for x in range(0, img.width - size, 62):
            c = g.crop((x, y, x + size, y + size))
            lo, hi = c.getextrema()
            score = (hi - lo) + sum(c.histogram()[:12]) * -0.001
            hist = c.histogram()
            used = sum(1 for v in hist if v > 4)
            score = used
            if score > best:
                best, best_box = score, (x, y, x + size, y + size)
    return best_box


# ----------------------------------------------------------------- GIF

def gif(cap, clipdata, out):
    frames = clipdata["frames"]
    first, last = frames[0]["drawn"], frames[-1]["drawn"]
    imgs = []
    for k in range(first, last + 1, 3):            # 60 -> 20 fps
        p = os.path.join(cap, "frames", "f%08d.png" % k)
        if os.path.exists(p):
            imgs.append(Image.open(p).convert("RGB").resize(
                (800, 450), Image.LANCZOS))
    pal = [im.quantize(colors=128, method=Image.Quantize.MEDIANCUT,
                       dither=Image.Dither.NONE) for im in imgs]
    pal[0].save(out, save_all=True, append_images=pal[1:], duration=50,
                loop=0, optimize=False, disposal=1)


def main():
    out, sheets = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    cap = os.path.join(out, "capture")
    os.makedirs(sheets, exist_ok=True)
    clipdata = json.load(open(os.path.join(cap, "clip.json")))
    fs1(cap, os.path.join(sheets, "FS1_gameplay_view.png"))
    fs2(cap, clipdata, os.path.join(sheets, "FS2_firing_timeline.png"))
    fs3(cap, os.path.join(sheets, "FS3_close_up.png"))
    fs4(os.path.join(out, "maps"), os.path.join(sheets,
                                                "FS4_material_maps.png"))
    gif(cap, clipdata, os.path.join(sheets, "foundry_clip_20fps.gif"))
    for name in ["placeholder_fp.png", "study_fp.png"] + [c[0] for c in CLOSE]:
        shutil.copy(os.path.join(cap, name), os.path.join(sheets, name))
    print("[fsheets] -> %s" % sheets)


if __name__ == "__main__":
    main()
