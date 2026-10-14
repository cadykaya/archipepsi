#!/usr/bin/env python3
"""Comparison sheets for the five-weapon integration package.
(Arty, 2026-10-14.)

    python3 tools/crossing_capture/five_integration_sheets.py ART CAP OUT \
        [PREV_METRICS [PREV_DEV]]

ART is the art build (per weapon <w>/<w>.json, <w>/lean/lean.json and
<w>/look/; tools/weapon_model.sh). CAP is tools/five_integration.sh's
output from Prod's range. PREV_METRICS is the folder of the 2026-10-13
in-range metrics (`<w>_metrics.json`); PREV_DEV the 10-13 development
build (per weapon <w>/look/), the "before" of the memory sheet.
Writes, into OUT:

  IW0_lineup.jpg            the five at rest and firing, from the eye
  IW2_bulkhead_d.jpg        Bulkhead D (Fan) developed: Cycles looks,
                            close looks, the elevation, and Breacher and
                            Sweeper in the range
  IW1_<config>.jpg          per weapon (the Bulkhead per variant): Prod's
                            placeholder against the art at rest, aimed and
                            firing; the impact on four materials from a
                            second eye 1.8 m off the target, in the same
                            frame; and the mark each leaves
  IW6_memory.jpg            the 10-13 model beside the repacked one, same
                            camera, whole and in the close looks: the
                            memory came off, the detail did not
  IW7_costs.png             triangles, materials, draw calls, texture
                            memory before and after, clearance
  IW8_timing.png            when each moving part moves against the shot,
                            the readiness and the Glyph flash, placeholder
                            against art, from the per-frame clip logs
  <config>_clip.gif         placeholder | art, side by side, 15 fps, the
                            gun's part of the frame
  integration_summary.json  every number on the sheets

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
CONFIGS = [
    ("foundry", "", "Foundry", "Hand Cannon"),
    ("sightline", "", "Sightline", "Precision"),
    ("switchback", "", "Switchback", "Pulse Carbine"),
    ("bulkhead", "breacher", "Bulkhead D (Fan): Breacher", "Scattergun"),
    ("bulkhead", "sweeper", "Bulkhead D (Fan): Sweeper", "Scattergun"),
    ("driver", "", "Mass Driver", "Charge"),
]
MATS = ["metal", "stone", "wood", "gel"]
PARTS = {"foundry": ["hammer", "cylinder"], "sightline": ["handle"],
         "switchback": ["bolt"], "bulkhead": ["pump", "feed"],
         "driver": ["coils", "core"]}
TICK_MS = 1000.0 / 60.0
#: the movie frames of the clip proper (the last 220 physics ticks at 30
#: fps = 110 frames, plus the frames that land the last ticks)
CLIP_FRAMES = 112


def base(w, v):
    return w + ("_" + v if v else "")


def _img(path):
    return Image.open(path).convert("RGB")


def fit(img, w):
    return img.resize((w, round(img.height * w / img.width)), Image.LANCZOS)


def _load(path):
    return json.load(open(path)) if os.path.exists(path) else {}


def _label(d, x, y, text, sub=None, colour=INK):
    d.text((x, y), text, font=font(20, True), fill=colour)
    if sub:
        d.text((x, y + 26), sub, font=font(16), fill=DIM)


# ================================================================ lineup

def lineup(cap, out):
    """The five at rest and at the shot, the gun's corner of the frame."""
    box = (640, 380, 1600, 900)          # the viewmodel's part of 1600x900
    cols = [c for c in CONFIGS if c[1] != "sweeper"]
    cw = W // len(cols)
    ch = round(cw * (box[3] - box[1]) / (box[2] - box[0]))
    sheet = Image.new("RGB", (W, 150 + 2 * (ch + 50)), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "The five, in Prod's range, from the player's eye",
          "The art on his v3 runtime with the layered Glyph effects: at "
          "rest, and one frame after the shot (the Driver after a full "
          "charge). Forward+, the game's renderer. Arty, 2026-10-14.")
    for i, (w, v, name, _) in enumerate(cols):
        tag = base(w, v) + "_art"
        for r, shot in enumerate(("rest", "fire")):
            p = os.path.join(cap, "%s_%s.png" % (tag, shot))
            if not os.path.exists(p):
                continue
            y = 150 + r * (ch + 50)
            sheet.paste(_img(p).crop(box).resize((cw, ch), Image.LANCZOS),
                        (i * cw, y + 40))
            _label(d, i * cw + 14, y + 6, name.split(":")[0]
                   if r == 0 else "the shot", None, ACCENT if r else INK)
    _save(sheet, out)


# ======================================================== Bulkhead D

BULKHEAD_NOTE = (
    "Developed from the chosen concept D, keeping its four splayed bores "
    "and its mechanism. Added: tie collars and a strap bolted across the "
    "four bores at the front; four outlet terminals on the distributor "
    "that feeds them; hinge knuckles on the breech block; a shell clip "
    "with two spare shells on the block's left. History: heat-straw along "
    "each bore and darkest at its mouth, with soot there; the distributor "
    "line scorched; a crack on the receiver's left flank, welded, ground "
    "flat and touched up; a clamp bolt at the bores' roots chewed by a "
    "spanner; BH-6 "
    "stencilled and stamped, service tallies, tape on the pump grip, and "
    "the strap's mill scale left on. One model for both variants: the "
    "Breacher works the Pump, and the Sweeper shows the cassette Feed. "
    "Prod's runtime already does both.")


def bulkhead_sheet(art, cap, out):
    look = os.path.join(art, "bulkhead", "look")
    rec = _load(os.path.join(art, "bulkhead", "bulkhead.json"))
    sheet = Image.new("RGB", (W, 2420), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "Bulkhead D (Fan), developed to the Foundry standard",
          "The owner's choice of 2026-10-14, modelled, painted and held "
          "in Glyph through the same pipeline as the other four. One "
          "model; Breacher and Sweeper. Arty, 2026-10-14.")
    big = fit(_img(os.path.join(look, "look_three_q.png")), 1460)
    sheet.paste(big, (40, 110))
    side = fit(_img(os.path.join(look, "look_side.png")).crop(
        (320, 160, 1520, 600)), 1460)
    sheet.paste(side, (40, 110 + big.height + 20))
    x2, cw = 1540, W - 1540 - 40
    y0 = 110 + big.height + 20 + side.height + 30
    closes = ["close_fan", "close_breech", "close_manifold"]
    ch = (y0 - 30 - 110 - 16 * (len(closes) - 1)) // len(closes)
    y = 110
    for c in closes:
        im = fit(_img(os.path.join(look, "look_%s.png" % c)), cw)
        top = max(0, (im.height - ch) // 2)
        im = im.crop((0, top, cw, top + min(ch, im.height)))
        sheet.paste(im, (x2, y))
        y += im.height + 16
    shots = [("bulkhead_breacher_art_rest", "Breacher, at rest"),
             ("bulkhead_sweeper_art_rest", "Sweeper, at rest: the Feed "
              "cassette shown"),
             ("bulkhead_breacher_art_fire", "Breacher, the shot: a flash "
              "at each bore")]
    sw = (W - 80 - 40 * (len(shots) - 1)) // len(shots)
    for i, (s, lab) in enumerate(shots):
        p = os.path.join(cap, s + ".png")
        x = 40 + i * (sw + 40)
        if os.path.exists(p):
            im = _img(p).crop((300, 120, 1600, 851)).resize(
                (sw, round(sw * 731 / 1300)), Image.LANCZOS)
            sheet.paste(im, (x, y0))
        d.text((x, y0 + round(sw * 731 / 1300) + 4),
               "Prod's v3 range: " + lab, font=font(17), fill=DIM)
    ty = y0 + round(sw * 731 / 1300) + 50
    m = rec.get("metrics", {})
    if m:
        d.text((40, ty), "%d triangles  ·  1 material  ·  5 maps at %d²  ·  "
               "%.0f texels/m" % (m["triangles"], m["texture_size"],
                                  m["texels_per_metre"]),
               font=font(20, True), fill=ACCENT)
    caption(d, 40, ty + 40, BULKHEAD_NOTE, 205, 18)
    _save(sheet, out)


# ============================================================ per weapon

def weapon_sheet(cap, w, v, name, role, out):
    tags = {s: base(w, v) + "_" + s for s in ("placeholder", "art")}
    rec = {s: _load(os.path.join(cap, t + "_stills.json"))
           for s, t in tags.items()}
    imp = {s: _load(os.path.join(cap, t + "_impacts.json"))
           for s, t in tags.items()}
    views = ["rest", "ads", "charge", "fire"]
    views = [vw for vw in views
             if os.path.exists(os.path.join(cap, "%s_%s.png"
                                            % (tags["art"], vw)))]
    half = (W - 60) // 2
    vh = round(half * 9 / 16)
    quarter = (W - 100) // 4
    qh = round(quarter * 9 / 16)
    H = 170 + len(views) * (vh + 60) + 2 * 60 + 4 * (qh + 48) + 40
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "%s (%s): Prod's placeholder → the art" % (name, role),
          "Both on his v3 runtime, unchanged: his recoil, timing, ADS, "
          "muzzle and effects. The art swaps the model and adds the layered "
          "Glyph effects on top of his. Arty, 2026-10-14.")
    say = {"rest": "at rest", "ads": "aimed down the sights",
           "charge": "full charge (held)", "fire": "one frame after the shot"}
    y = 170
    for vw in views:
        for k, side in enumerate(("placeholder", "art")):
            p = os.path.join(cap, "%s_%s.png" % (tags[side], vw))
            x = 20 + k * (half + 20)
            if os.path.exists(p):
                sheet.paste(fit(_img(p), half), (x, y + 44))
            key = {"fire": "fire_peak"}.get(vw, vw)
            c = rec[side].get(key, {})
            sub = ""
            if c:
                sub = "nearest point %.3f m (near plane %.2f m)" % (
                    c["nearest_m"], c["near_plane_m"])
                if "screen_share" in c:
                    sub += "; %.1f%% of the screen; crosshair %s" % (
                        100 * c["screen_share"],
                        ("under the sights, as aimed" if vw == "ads"
                         else "COVERED") if c["covers_crosshair"]
                        else "clear")
            _label(d, x, y - 4, "%s, %s" % (
                "Placeholder" if side == "placeholder" else "Art", say[vw]))
            d.text((x, y + 22), sub, font=font(16), fill=DIM)
        y += vh + 60
    for block, (suffix, what) in enumerate((
            ("impact_%s_near", "THE HIT, from a second eye 1.8 m off the "
             "target, rendered in the same frame as the player's"),
            ("mark_%s", "THE MARK it leaves, 1.7 s later (after the "
             "metal's hot rim has cooled), 0.55 m off the surface"))):
        d.text((40, y + 14), what, font=font(19, True), fill=ACCENT)
        y += 60
        for side in ("placeholder", "art"):
            ev = {}
            for e in rec[side].get("fx_events", []) + \
                    imp[side].get("fx_events", []):
                if e["event"] == "mark":
                    ev[e["material"]] = e["sheet"]
            for i, m in enumerate(MATS):
                x = 20 + i * (quarter + 20)
                p = os.path.join(cap, ("%s_" + suffix + ".png")
                                 % (tags[side], m))
                if os.path.exists(p):
                    sheet.paste(fit(_img(p), quarter), (x, y + 34))
                row = imp[side].get("impacts", {}).get(m, {})
                lab = "%s, %s" % ("Placeholder" if side == "placeholder"
                                  else "Art", m)
                if block == 1 and row:
                    lab += ": mark %.2f m" % row.get("mark_size_m", 0)
                    tex = row.get("mark_texture", "")
                    if side == "art" and tex:
                        lab += ", " + tex.split("#")[0]
                if row and not row.get("marks_added"):
                    lab += "  (NO MARK)"
                d.text((x, y + 6), lab, font=font(17), fill=INK)
            y += qh + 48
    _save(sheet, out)


# ================================================================ clips

#: the gun and the crosshair's part of the 1600x900 frame (16:9)
CLIP_CROP = (480, 240, 1600, 870)


def _save(img, out):
    if out.endswith(".jpg"):
        save_photo(img, out)
    else:
        img.save(out, optimize=True)


def save_photo(img, out):
    """The capture sheets as JPEG at q92 without chroma subsampling: side
    by side with the PNG no difference shows at 1:1, at a third of the
    size (the delivery has a 30 MiB limit)."""
    img.save(out, quality=92, subsampling=0, optimize=True)


def clip_gif(cap, w, v, out, every=2, size=(400, 225)):
    frames = []
    sides = []
    for side in ("placeholder", "art"):
        files = sorted(glob.glob(os.path.join(
            cap, "%s_%s_clip" % (base(w, v), side), "*.png")))
        sides.append(files[max(0, len(files) - CLIP_FRAMES):])
    n = min(len(s) for s in sides)
    if n == 0:
        return False
    for i in range(0, n, every):
        c = Image.new("RGB", (size[0] * 2 + 8, size[1]), BG)
        for k, files in enumerate(sides):
            c.paste(_img(files[i]).crop(CLIP_CROP).resize(
                size, Image.LANCZOS), (k * (size[0] + 8), 0))
        frames.append(c.quantize(128, method=Image.MEDIANCUT,
                                 dither=Image.NONE))
    frames[0].save(out, save_all=True, append_images=frames[1:],
                   duration=round(1000 * every / 30), loop=0, optimize=True)
    return True


# =============================================================== timing

def _runs(ticks, gap=2):
    """Runs of ticks, joining gaps of up to `gap` ticks: the clip renders
    at 30 fps over 60 physics ticks a second, so an animation advances on
    every other tick and a still tick between two moves is not a stop."""
    runs = []
    for t in ticks:
        if runs and t - runs[-1][1] <= gap:
            runs[-1][1] = t
        else:
            runs.append([t, t])
    return runs


def timing(clip, events, w):
    """From the per-tick rows: each shot's tick, each part's motion runs,
    when the runtime says ready (cooldown 0) and the gun is at rest, and
    the Glyph flash's frame against the shot's."""
    rows = clip.get("frames", [])
    if not rows:
        return {}
    shots = []
    for a, b in zip(rows, rows[1:]):
        if b["shots"] > a["shots"]:
            shots.append(b["t"])
    parts = {}
    for key in PARTS.get(w, []):
        if key not in rows[0]:
            continue
        moved = [b["t"] for a, b in zip(rows, rows[1:])
                 if b[key][:4] != a[key][:4]]
        shown = [r["t"] for r in rows if r[key][4]]
        parts[key] = {"moving_ticks": _runs(moved),
                      "visible": bool(shown),
                      "rest": rows[0][key][:4]}
    ready = []
    for s in shots:
        for r in rows:
            if r["t"] > s and r["cooldown"] <= 0.0:
                ready.append(r["t"])
                break
    rest_at = []
    for s in shots:
        for r in rows:
            if r["t"] > s + 2 and r["gun_at_rest"]:
                rest_at.append(r["t"])
                break
    flash = [e["frame"] for e in events if e["event"] == "fired"]
    energy = [r.get("core_energy") for r in rows if "core_energy" in r]
    return {"shots": shots, "ready": ready, "gun_at_rest": rest_at,
            "parts": parts, "fx_fired_frames": flash,
            "core_energy_peak": max(energy) if energy else None,
            "clearance_min_m": min(r["clearance"] for r in rows)}


def _ms(tick, s0):
    return round((tick - s0) * TICK_MS)


def _shots_text(r):
    s0 = r["shots"][0]
    shots = [_ms(t, s0) for t in r["shots"]]
    if len(shots) > 3:
        gaps = sorted({b - a for a, b in zip(shots, shots[1:])})
        return "%d shots, %s ms apart" % (len(shots), "-".join(
            str(g) for g in (gaps[0], gaps[-1])) if len(gaps) > 1
            else str(gaps[0]))
    return "shots at " + ", ".join("%d" % x for x in shots) + " ms"


def _parts_text(r):
    s0 = r["shots"][0]
    out = []
    for key, p in r["parts"].items():
        runs = p["moving_ticks"]
        if not runs:
            out.append("%s still%s" % (key, "" if p["visible"]
                                       else " (hidden)"))
            continue
        txt = ", ".join("%d" % _ms(a, s0) if a == b else "%d-%d" % (
            _ms(a, s0), _ms(b, s0)) for a, b in runs[:4])
        if len(runs) > 4:
            txt += ", … (%d runs)" % len(runs)
        out.append("%s %s" % (key, txt))
    return ";  ".join(out)


def _same(a, b):
    """The art moves exactly when the placeholder does: the same shots,
    readiness, rest, and the same motion runs for every part."""
    if not a or not b:
        return None
    if a["shots"] != b["shots"] or a["ready"] != b["ready"] \
            or a["gun_at_rest"] != b["gun_at_rest"]:
        return False
    return all(a["parts"][k]["moving_ticks"] == b["parts"].get(
        k, {}).get("moving_ticks") for k in a["parts"])


def timing_sheet(summary, out):
    sheet = Image.new("RGB", (W, 330 + 180 * len(CONFIGS)), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "Timing: the art moves when the runtime says, not "
          "on its own clock",
          "Per-tick logs of one burst through the real fire input (60 "
          "ticks a second, 16.7 ms each); Prod's placeholder and the art on "
          "the same runtime. Times in ms from the first shot.")
    caption(d, 40, 120,
            "Ready = the runtime's cooldown reaches zero. At rest = his rig "
            "says the gun is home. A part 'moves 617-683' between those "
            "times; a lone number is a snap (the hammer falling on the "
            "shot). Glyph flash = the authored muzzle flash started on the "
            "shot's own tick. Identical = the art's shots, readiness, rest "
            "and every part's motion match the placeholder's tick for "
            "tick.", width_chars=210, size=17, fill=DIM)
    y = 220
    for w, v, name, _ in CONFIGS:
        t = summary[base(w, v)]
        pl, art = t.get("placeholder", {}), t.get("art", {})
        same = _same(pl, art)
        d.text((40, y), name, font=font(22, True), fill=INK)
        verdict = {True: "IDENTICAL to the placeholder", False:
                   "DIFFERS from the placeholder", None: "not captured"}[same]
        d.text((900, y + 2), verdict, font=font(19, True),
               fill=ACCENT if same else (230, 120, 110))
        yy = y + 38
        for label, r in (("PL", pl), ("ART", art)):
            if not r or not r.get("shots"):
                continue
            s0 = r["shots"][0]
            line = "%-4s %s;  ready %s;  at rest %s" % (
                label, _shots_text(r),
                ", ".join(str(_ms(x, s0)) for x in r["ready"][:2]),
                ", ".join(str(_ms(x, s0)) for x in r["gun_at_rest"][:2]))
            if label == "ART":
                fl = r.get("fx_fired_frames", [])
                line += ";  Glyph flash on the shot's tick: %s" % (
                    "every shot" if len(fl) == len(r["shots"])
                    else "%d of %d" % (len(fl), len(r["shots"])))
            d.text((70, yy), line, font=font(17),
                   fill=INK if label == "ART" else DIM)
            d.text((110, yy + 26), _parts_text(r), font=font(16), fill=DIM)
            yy += 60
        y += 180
    _save(sheet, out)


# ================================================================ costs

def costs_sheet(art, cap, prev, summary, out):
    cols = ["weapon", "triangles", "materials", "draw calls",
            "texture memory: 10-13 → now", "maps", "texels/m",
            "nearest point: rest / ADS / shot", "screen", "crosshair"]
    xs = [40, 420, 580, 720, 880, 1260, 1520, 1680, 2100, 2260]
    rows = []
    for w, v, name, _ in CONFIGS:
        s = summary[base(w, v)]
        rows.append((name, s))
    sheet = Image.new("RGB", (W, 360 + 64 * (len(rows) + 1)), BG)
    d = ImageDraw.Draw(sheet)
    title(d, 40, 30, "What each costs, and whether it fits",
          "Measured in Prod's range, Forward+ on software Vulkan "
          "(RenderingServer counters with the art in view; texture memory "
          "is the counter's rise when the model loads). Arty, 2026-10-14.")
    y = 140
    for x, c in zip(xs, cols):
        d.text((x, y), c, font=font(17, True), fill=DIM)
    for name, s in rows:
        y += 64
        a = s.get("art_cost", {})
        p = s.get("placeholder_cost", {})
        before = s.get("tex_before_mb")
        cl = s.get("clearance", {})
        vals = [
            name.replace("Bulkhead D (Fan): ", "Bulkhead "),
            "%s  (PL %s)" % (a.get("triangles", "-"), p.get("triangles", "-")),
            "%s" % a.get("materials", "-"),
            "%s  (PL %s)" % (a.get("draw_calls", "-"),
                             p.get("draw_calls", "-")),
            "%s → %.1f MB" % ("%.1f" % before if before else "-",
                              a.get("texture_mem_added_bytes", 0) / 2 ** 20),
            "%d²" % s.get("size", 0),
            "%.0f" % s.get("texels_per_metre", 0),
            " / ".join("%.3f" % cl[k] if cl.get(k) is not None else "-"
                       for k in ("rest", "ads", "fire")),
            "%.1f%%" % (100 * cl.get("screen", 0)),
            "covered" if cl.get("crosshair") else "clear",
        ]
        for x, val in zip(xs, vals):
            d.text((x, y), val, font=font(19), fill=INK)
    y += 90
    caption(d, 40, y,
            "Texture memory, 10-13: four RGBA8 maps embedded in the GLB, "
            "2048² for Sightline, Switchback and Mass Driver (96.0 MB each in "
            "the range), 1024² for the Foundry (24.0 MB). Now: the same "
            "texels in the formats they need (colour and normal RGB8; "
            "roughness, metallic and the lamp mask one byte each), a "
            "geometry-only GLB so no RGBA copy loads, and an atlas sized to "
            "the density the owner reviewed (packed square to the axes, "
            "which fills more of it). No map was resampled below that "
            "density; nothing was compressed. Nearest point: the model's "
            "closest corner to the eye, against the camera's 0.05 m near "
            "plane; 'shot' is the nearest over the whole recoil. PL = "
            "Prod's placeholder.", width_chars=200, size=17, fill=DIM)
    _save(sheet, out)


# ================================================================= main

def main():
    art, cap, out = sys.argv[1], sys.argv[2], sys.argv[3]
    prev = sys.argv[4] if len(sys.argv) > 4 else ""
    prev_dev = sys.argv[5] if len(sys.argv) > 5 else ""
    os.makedirs(out, exist_ok=True)
    summary = {}
    for w, v, name, role in CONFIGS:
        b = base(w, v)
        s = {"name": name}
        for side in ("placeholder", "art"):
            st = _load(os.path.join(cap, "%s_%s_stills.json" % (b, side)))
            cl = _load(os.path.join(cap, "%s_%s_clip.json" % (b, side)))
            im = _load(os.path.join(cap, "%s_%s_impacts.json" % (b, side)))
            s[side + "_cost"] = st.get("cost", {})
            s[side] = timing(cl, cl.get("fx_events", []), w)
            s[side + "_impacts"] = im.get("impacts", {})
            if side == "art":
                s["clearance"] = {
                    "rest": st.get("rest", {}).get("nearest_m"),
                    "ads": st.get("ads", {}).get("nearest_m"),
                    "fire": min([x for x in (
                        st.get("fire_peak", {}).get("nearest_m"),
                        s["art"].get("clearance_min_m")) if x is not None],
                        default=None),
                    "screen": st.get("rest", {}).get("screen_share", 0),
                    "crosshair": st.get("rest", {}).get("covers_crosshair"),
                }
        lean = _load(os.path.join(art, w, "lean", "lean.json"))
        s["size"] = lean.get("size", [0])[0]
        s["lean_bytes_with_mips"] = lean.get("bytes_with_mips", {})
        model = _load(os.path.join(art, w, w + ".json")).get("metrics", {})
        s["texels_per_metre"] = model.get("texels_per_metre",
                                          1319.0 if w == "foundry" else 0)
        s["model_triangles"] = model.get("triangles")
        # the "before": the 10-13 GLB measured in this run's renderer when
        # five_integration.sh ran it (`before=`), else the 10-13 record
        bf = _load(os.path.join(cap, w + "_before_stills.json"))
        pm = _load(os.path.join(prev, w + "_metrics.json")) if prev else {}
        if bf.get("cost"):
            s["tex_before_mb"] = bf["cost"]["texture_mem_added_bytes"] \
                / 2 ** 20
            s["before_cost"] = bf["cost"]
            s["before_source"] = "this run, the 10-13 GLB"
        elif pm:
            s["tex_before_mb"] = pm["texture_mem_added_bytes"] / 2 ** 20
            s["before_source"] = "the 10-13 record (Compatibility)"
        summary[b] = s
        weapon_sheet(cap, w, v, name, role,
                     os.path.join(out, "IW1_%s.jpg" % b))
        clip_gif(cap, w, v, os.path.join(out, "%s_clip.gif" % b))
    lineup(cap, os.path.join(out, "IW0_lineup.jpg"))
    bulkhead_sheet(art, cap, os.path.join(out, "IW2_bulkhead_d.jpg"))
    costs_sheet(art, cap, prev, summary, os.path.join(out, "IW7_costs.png"))
    timing_sheet(summary, os.path.join(out, "IW8_timing.png"))
    if prev_dev:
        memory_sheet(art, prev_dev, summary, os.path.join(out,
                                                          "IW6_memory.jpg"))
    with open(os.path.join(out, "integration_summary.json"), "w") as fh:
        json.dump(summary, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print("[sheets] %s" % out)


if __name__ == "__main__":
    main()
