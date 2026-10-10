#!/usr/bin/env python3
"""Heavy Report's effects, drawn in ECMS Glyph. CANDIDATE KIT. (Arty, 2026-10-10.)

    GLYPH_ROOT=/home/user/glyph-trial python3 tools/glyphui/author_heavy_report_fx.py [OUT_DIR]

Writes the sheets and `fx.json` into `assets/fx/heavy_report/` (or OUT_DIR).

FOR WHAT. The owner chose Mode 2, Heavy Report, as the hand-cannon's feel
(2026-10-10). Prod built it on `review/weapon-feel` (`weapon_feel_
treatments.gd`, treatment "a"): it answers the shot's two existing
signals, `Player.fired_pulse` and `Player.hit_confirmed`, and draws its
flash, sparks and splash from generic debug geometry -- a SphereMesh
fireball, 18 BoxMesh grains, an OmniLight. This replaces the GEOMETRY
with authored sprites, and changes none of Prod's numbers: every
flipbook here fits inside the time his treatment already gives it.

  sheet                  frames (ms)          answers
  fx_heavy_muzzle        17 33 100            fired_pulse: the muzzle bloom
  fx_heavy_tracer        17 33                fired_pulse: Tracer.spawn's beam
  fx_impact_metal        17 33 67 100         the impact, on metal
  fx_spark_streak        one                  the impact's particles, on metal
  fx_impact_stone        17 50 83 117         the impact, on stone/concrete
  fx_decal_chip          one                  stays on stone
  fx_impact_organic      17 50 83 117         the impact, on organic surfaces
  fx_decal_sap           one                  stays on organic

THREE MATERIALS, THREE ANSWERS, TOLD APART BY SHAPE AND VALUE, NOT HUE
(A12.4: a refused hit and a damaging one must not look alike; the same
rule keeps three surfaces apart for a colour-blind player or a dark room):
  * METAL sparks: thin bright radial streaks, the brightest of the three,
    and a short warm light. Streak particles under gravity.
  * STONE gives a lobed grey dust puff with pale concrete fragments
    flung out and falling, a brief small flash only on the first frame,
    and a chip mark.
  * ORGANIC gives a dark wound with pale ichor droplets and strands, no
    light at all, droplets that fall, and a sap mark. Not red: red is
    the enemy cue (D-19).
The checks below hold them to it: metal's ink is the brightest, organic's
the darkest, and no two materials share their first frames' silhouette.

THE TRACER IS NEUTRAL. `Player._spawn_tracer` colours the beam from pale
blue toward magenta as Static accumulates; that is a game signal, so the
streak is white and grey and the runtime's colour stays the tint.

No orange bands: the warm colours here are white-hot to amber, and only
in the flash and the sparks, which last a fraction of a second.
"""

from __future__ import annotations

import json
import math
import os
import shutil
import sys
import tempfile

import glyphrun

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
OWNER = "act_owner_arty"
ARTIST = "act_agent_arty"

PALETTE = [
    ("hot", (255, 251, 234, 255)), ("yellow", (255, 227, 154, 255)),
    ("amber", (255, 179, 92, 255)),
    ("smoke_l", (154, 150, 143, 150)), ("smoke_d", (94, 91, 87, 130)),
    ("dust_l", (201, 192, 174, 200)), ("dust_d", (142, 133, 116, 220)),
    ("chip", (63, 60, 56, 255)), ("chip_l", (218, 210, 194, 255)),
    ("sap_d", (59, 38, 32, 255)), ("sap_m", (110, 68, 52, 255)),
    ("sap_l", (168, 119, 91, 255)),
    ("ichor_m", (140, 98, 74, 255)), ("ichor_l", (198, 164, 132, 255)),
    ("white", (255, 255, 255, 255)), ("grey_hi", (255, 255, 255, 170)),
    ("grey_lo", (255, 255, 255, 90)),
]


def L(a, b, e, t=1):
    return ("line", [list(a), list(b)], e, None, t)


def E(a, b, e, filled=True):
    return ("ellipse", [list(a), list(b)], e, filled, 1)


def R(a, b, e, filled=True):
    return ("rect", [list(a), list(b)], e, filled, 1)


def _polar(c, r, deg):
    a = math.radians(deg)
    return (int(round(c + r * math.cos(a))), int(round(c + r * math.sin(a))))


def _dot(p, e, size=1):
    return E((p[0], p[1]), (p[0] + size, p[1] + size), e)


# --- the drawings, frame by frame ---------------------------------------------

def muzzle():
    f0 = [E((11, 14), (35, 32), "amber", False),
          L((2, 23), (44, 23), "yellow", 3), L((23, 8), (23, 38), "yellow", 3),
          L((10, 12), (36, 34), "amber"), L((10, 34), (36, 12), "amber"),
          E((16, 17), (30, 29), "yellow"), E((19, 20), (27, 26), "hot"),
          L((2, 23), (7, 23), "hot"), L((39, 23), (44, 23), "hot")]
    f1 = [E((12, 15), (34, 31), "smoke_l", False),
          L((9, 23), (37, 23), "amber", 2), L((23, 13), (23, 33), "amber", 2),
          E((17, 18), (29, 28), "yellow"), E((20, 21), (26, 25), "hot")]
    f2 = [E((14, 24), (28, 34), "smoke_d"), E((12, 13), (30, 29), "smoke_l"),
          E((20, 16), (36, 30), "smoke_l"), E((22, 21), (24, 23), "amber")]
    return [f0, f1, f2]


def tracer():
    f0 = [L((0, 3), (20, 3), "grey_lo", 2), L((20, 3), (44, 3), "grey_hi", 2),
          L((44, 3), (63, 3), "white", 2), E((55, 1), (63, 6), "white")]
    f1 = [L((16, 3), (40, 3), "grey_lo"), L((40, 3), (63, 3), "grey_hi"),
          E((58, 2), (63, 5), "grey_hi")]
    return [f0, f1]


def spark_streak():
    return [[L((0, 1), (2, 1), "amber"), L((3, 1), (5, 1), "yellow"),
             R((6, 0), (7, 2), "hot")]]


def impact_metal():
    c = 16
    f0 = [L((8, 8), (24, 24), "yellow"), L((8, 24), (24, 8), "yellow"),
          L((16, 4), (16, 28), "hot"), L((4, 16), (28, 16), "hot"),
          E((13, 13), (19, 19), "hot")]
    f1 = [E((14, 14), (18, 18), "yellow")]
    for k in range(8):
        deg = k * 45 + 22.5
        f1.append(L(_polar(c, 5, deg), _polar(c, 11, deg), "yellow"))
        f1.append(L(_polar(c, 11, deg), _polar(c, 13, deg), "hot"))
    f2 = []
    for k in (0, 1, 3, 4, 5, 7):
        deg = k * 45 + 10
        f2.append(L(_polar(c, 9, deg), _polar(c, 14, deg), "amber"))
    f3 = [_dot(p, "amber") for p in ((6, 20), (25, 21), (10, 26), (21, 27),
                                     (15, 29))]
    return [f0, f1, f2, f3]


def impact_stone():
    """Concrete: a dust puff in LOBES (one ellipse read as a solid disc,
    2026-10-10), PALE fragments (dark chips vanished on the dark floor)
    and a few dark ones, and a flash only on the first frame."""
    c = 16
    f0 = [E((14, 14), (18, 18), "yellow"), E((15, 15), (17, 17), "hot")]
    # Mid-grey, not pale: pale radial lines round a hot dot read as a
    # small spark star, and sparks are metal's alone (2026-10-10).
    for deg in (200, 245, 290, 335, 20, 160, 110):
        f0.append(L(_polar(c, 4, deg), _polar(c, 7, deg), "dust_d"))
    f1 = [E((9, 14), (19, 22), "dust_d"), E((8, 10), (18, 20), "dust_l"),
          E((14, 9), (25, 18), "dust_l"), E((12, 14), (23, 22), "dust_l")]
    f1 += [_dot(_polar(c, 11, d), "chip_l") for d in range(0, 360, 45)]
    f1 += [_dot(_polar(c, 9, d), "chip") for d in (70, 250)]
    f2 = [E((6, 13), (18, 25), "dust_d"), E((5, 8), (18, 20), "dust_l"),
          E((13, 6), (27, 19), "dust_l"), E((10, 13), (25, 24), "dust_l")]
    f2 += [_dot((p[0], min(29, p[1] + 3)), "chip_l")
           for p in (_polar(c, 13, d) for d in range(20, 360, 60))]
    f3 = [E((4, 8), (17, 21), "smoke_l"), E((13, 5), (28, 18), "smoke_l")]
    f3 += [_dot(p, "chip_l") for p in ((8, 27), (23, 28), (15, 29))]
    return [f0, f1, f2, f3]


def impact_organic():
    """Organic: a dark wound and PALE ichor -- dark sap alone vanished on
    a dark organic surface (2026-10-10). Strands, round droplets that
    fall, no glow, no red."""
    c = 16
    f0 = [E((11, 11), (21, 21), "sap_d"), E((13, 12), (17, 15), "sap_m")]
    for d in range(15, 360, 60):
        p = _polar(c, 9, d)
        f0.append(E((p[0] - 1, p[1] - 1), (p[0] + 1, p[1] + 1), "ichor_l"))
    f1 = [E((13, 13), (19, 19), "sap_d")]
    for d in (30, 100, 170, 240, 310):
        f1.append(L(_polar(c, 4, d), _polar(c, 10, d), "ichor_m"))
        p = _polar(c, 11, d)
        f1.append(E((p[0] - 1, p[1] - 1), (p[0] + 1, p[1] + 1), "ichor_l"))
    f2 = [E((15, 15), (17, 17), "sap_d")]
    for d in range(30, 360, 55):
        p = _polar(c, 13, d)
        y = min(28, p[1] + 2)
        f2.append(E((p[0] - 1, y - 1), (p[0] + 1, y + 1), "ichor_m"))
    f3 = [E((p[0] - 1, p[1] - 1), (p[0] + 1, p[1] + 1), "ichor_m")
          for p in ((9, 25), (21, 26), (14, 28), (25, 28))]
    return [f0, f1, f2, f3]


def decal_chip():
    """Bigger and harder than the first pass, which vanished on the
    floor: a dark crater, a pale ring of crushed concrete, cracks."""
    return [[E((3, 3), (12, 12), "chip_l"), E((5, 5), (10, 10), "chip"),
             L((6, 6), (1, 3), "chip"), L((9, 6), (13, 2), "chip"),
             L((9, 9), (14, 12), "chip"), L((6, 9), (3, 14), "chip"),
             _dot((2, 8), "chip_l"), _dot((12, 7), "chip_l")]]


def decal_sap():
    return [[E((3, 4), (12, 12), "sap_d"), E((5, 6), (10, 10), "ichor_m"),
             E((12, 2), (14, 4), "ichor_l"), E((1, 11), (3, 13), "ichor_l"),
             E((11, 12), (13, 14), "ichor_m"), L((6, 6), (7, 6), "ichor_l")]]


#: name: (width, height, drawing, frame durations ms, loop, what, runtime)
SHEETS = {
    "fx_heavy_muzzle": (48, 48, muzzle, [17, 33, 100], "once",
                        "fired_pulse: the muzzle bloom, replacing the "
                        "SphereMesh fireball",
                        {"node": "Sprite3D, billboard, additive, unshaded",
                         "at": "the viewmodel muzzle (the tracer's origin, "
                               "camera basis * (0.15, -0.12, -0.3))",
                         "world_size_m": 0.34, "frame0_on": "the shot frame",
                         "light": "keep Prod's flash light (5.0, warm, "
                                  "0.14 s)"}),
    "fx_heavy_tracer": (64, 8, tracer, [17, 33], "once",
                        "fired_pulse: Tracer.spawn's beam, replacing the "
                        "glowing BoxMesh",
                        {"node": "a quad from muzzle to hit, axis-billboarded "
                                 "along the beam, additive",
                         "head": "+X is the far (hit) end",
                         "tint": "the runtime's own colour (pale blue toward "
                                 "magenta with Static): the sheet is neutral",
                         "width_m": 0.08}),
    "fx_impact_metal": (32, 32, impact_metal, [17, 33, 67, 100], "once",
                        "the impact on a METAL surface",
                        {"node": "Sprite3D at hit + normal * 0.02, billboard, "
                                 "additive", "world_size_m": 0.6,
                         "particles": "10-14 fx_spark_streak, velocity-"
                                      "aligned, 2.5-6 m/s, 40 deg off the "
                                      "normal, gravity, 0.3 s",
                         "light": "Prod's warm splash, 2.5, half of 0.30 s"}),
    "fx_spark_streak": (8, 3, spark_streak, [300], "hold_last",
                        "one spark, for the metal impact's particles",
                        {"node": "CPUParticles3D mesh quad, velocity-aligned "
                                 "(particle flag align_y), additive",
                         "world_size_m": 0.08}),
    "fx_impact_stone": (32, 32, impact_stone, [17, 50, 83, 117], "once",
                        "the impact on STONE / concrete",
                        {"node": "Sprite3D, billboard, ALPHA blend (dust is "
                                 "not light)", "world_size_m": 0.7,
                         "particles": "6-8 fragments (a 2 px quad, mostly "
                                      "`chip_l`), gravity, 1.5-3 m/s",
                         "light": "none, or under 0.6 for the first 17 ms",
                         "decal": "fx_decal_chip"}),
    "fx_decal_chip": (16, 16, decal_chip, [3000], "hold_last",
                      "the mark a shot leaves on stone",
                      {"node": "Decal, onto the hit surface", "world_size_m":
                       0.28, "life": "fades over the last 1 s of 3 s; cap the "
                                     "count (oldest first)"}),
    "fx_impact_organic": (32, 32, impact_organic, [17, 50, 83, 117], "once",
                          "the impact on an ORGANIC surface",
                          {"node": "Sprite3D, billboard, ALPHA blend",
                           "world_size_m": 0.55,
                           "particles": "4-6 droplets (`ichor_m`), gravity, "
                                        "1-2.5 m/s, no glow",
                           "light": "none", "decal": "fx_decal_sap"}),
    "fx_decal_sap": (16, 16, decal_sap, [3000], "hold_last",
                     "the mark a shot leaves on organic surfaces",
                     {"node": "Decal", "world_size_m": 0.24,
                      "life": "as fx_decal_chip"}),
}

#: Beams and particles run to their own edges on purpose: a stretched
#: beam and a velocity-aligned streak are drawn edge to edge.
EDGE_TO_EDGE = {"fx_heavy_tracer", "fx_spark_streak"}


def _check(work, files):
    """Read the PNGs Glyph wrote and hold them to the kit's rules."""
    from PIL import Image
    faults, value = [], {}
    for name, (w, h, draw, durations, *_rest) in SHEETS.items():
        with Image.open(os.path.join(work, files[name])) as page:
            img = page.convert("RGBA")
        n = len(durations)
        if img.size != (w * n, h):
            faults.append("%s is %dx%d, not %dx%d" % ((name,) + img.size
                                                      + (w * n, h)))
            continue
        for f in range(n):
            ink = [(x, y) for x in range(w) for y in range(h)
                   if img.getpixel((f * w + x, y))[3] > 0]
            if not ink:
                faults.append("%s frame %d is empty" % (name, f))
            if name not in EDGE_TO_EDGE and any(
                    x in (0, w - 1) or y in (0, h - 1) for x, y in ink):
                faults.append("%s frame %d touches its cell's edge "
                              "(it would bleed in an atlas)" % (name, f))
        # The two frames that carry the read: mean ink luminance.
        px = [img.getpixel((f * w + x, y)) for f in range(min(2, n))
              for x in range(w) for y in range(h)]
        px = [p for p in px if p[3] > 0]
        value[name] = sum(0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
                          for p in px) / max(1, len(px))
    if not (value["fx_impact_metal"] > value["fx_impact_stone"]
            > value["fx_impact_organic"]):
        faults.append("the impacts must step down in value metal > stone > "
                      "organic: %s" % {k: round(v, 1) for k, v in value.items()
                                       if k.startswith("fx_impact")})
    # Three materials, three silhouettes: frame 0 and 1 overlap under half.
    masks = {}
    for name in ("fx_impact_metal", "fx_impact_stone", "fx_impact_organic"):
        with Image.open(os.path.join(work, files[name])) as page:
            img = page.convert("RGBA")
        masks[name] = {(f, x, y) for f in (0, 1) for x in range(32)
                       for y in range(32) if img.getpixel((f * 32 + x, y))[3]}
    names = sorted(masks)
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            a, b = masks[names[i]], masks[names[j]]
            iou = len(a & b) / max(1, len(a | b))
            if iou >= 0.5:
                faults.append("%s and %s share their silhouette (IoU %.2f)"
                              % (names[i], names[j], iou))
    return faults, value


def _revision(root):
    """The Glyph checkout's revision, so an upgrade that changes a pixel
    also changes this record -- and the art check sees the drift."""
    import subprocess
    out = subprocess.run(["git", "-C", root, "rev-parse", "--short=7",
                          "HEAD"], capture_output=True, text=True)
    return out.stdout.strip() or "unknown"


def main():
    out_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else
                              os.path.join(REPO, "assets", "fx",
                                           "heavy_report"))
    os.makedirs(out_dir, exist_ok=True)
    root = os.environ.get("GLYPH_ROOT", "/home/user/glyph-trial")
    work = tempfile.mkdtemp(prefix="glyphfx_")
    ses = glyphrun.Session(root, work, "archipepsi_heavy_report_fx.glyph",
                           OWNER, ARTIST)
    ses.create("the art lane draws Heavy Report's effects")
    # RGBA canvases, not indexed: smoke, dust and the tracer's falloff need
    # partial alpha, and Glyph's CLI refuses a part-alpha entry in an
    # indexed palette unless the project was opened with
    # `indexedPartialAlpha`, which only the easel API can declare
    # (PRECONDITION_FAILED, 2026-10-10). So PALETTE is the kit's palette,
    # named here and written as literal RGBA values.
    made = ses.txn({"creates": ["asset"]}, [
        ("asset.create", {"name": "heavy_report_fx"}),
    ], "Heavy Report's effects")
    rgba = {n: list(c) for n, c in PALETTE}
    asset = made[0]["asset"]["id"]

    files, record = {}, {}
    for name, (w, h, draw, durations, loop, what, runtime) in SHEETS.items():
        frames = draw()
        assert len(frames) == len(durations), name
        made = ses.txn({"creates": ["variant"]}, [
            ("variant.create", {"name": name, "width": w, "height": h,
                                "color_mode": "rgba", "asset": asset,
                                "representation": "effect"}),
        ], "the %s canvas" % name)
        variant = made[0]["variant"]["id"]
        cels = [made[0]["variant"]["cels"][0]]
        frame_ids = [made[0]["variant"]["frames"][0]["id"]
                     if isinstance(made[0]["variant"]["frames"][0], dict)
                     else made[0]["variant"]["frames"][0]]
        if len(frames) > 1:
            more = ses.txn({"variants": [variant]}, [
                ("frame.create", {"variant": variant})
                for _ in range(len(frames) - 1)], "%s's frames" % name)
            for m in more:
                cels.append(m["cels"][0]["cel"])
                frame_ids.append(m["frame"]["id"])
        for cel, shapes in zip(cels, frames):
            steps = []
            for shape, points, entry, filled, thick in shapes:
                step = {"cel": cel, "shape": shape, "points": points,
                        "value": {"rgba": rgba[entry]}}
                if filled is not None:
                    step["filled"] = filled
                if thick > 1:
                    step["thickness"] = thick
                steps.append(("pixels.draw", step))
            ses.txn({"cels": [cel]}, steps, "%s, a frame" % name)
        ses.txn({"creates": ["clip"]}, [
            ("clip.create", {"variant": variant, "name": name,
                             "frames": [{"frame": f, "duration": d}
                                        for f, d in zip(frame_ids, durations)],
                             "loop": loop,
                             "timing": {"unit": "milliseconds"}}),
        ], "%s's timing" % name)
        results = ses.batch([
            {"command": "export.define_preset",
             "input": ses.sheet_preset("fx_%s" % name, [variant],
                                       w * len(frames), h)},
            {"command": "export.run",
             "input": {"preset": "$1.preset", "destination": work}},
        ], label=name)
        before = set(f for f in os.listdir(work) if f.endswith(".png"))
        ses.write_export(results[1]["record"], label=name)
        fresh = sorted(set(f for f in os.listdir(work)
                           if f.endswith(".png")) - before)
        if len(fresh) != 1:
            raise SystemExit("%s exported %d page(s): %s"
                             % (name, len(fresh), fresh))
        files[name] = "%s.png" % name
        shutil.move(os.path.join(work, fresh[0]),
                    os.path.join(work, files[name]))
        record[name] = {"file": files[name], "cell": [w, h],
                        "frames": len(frames), "durations_ms": durations,
                        "total_ms": sum(durations) if loop == "once" else None,
                        "loop": loop, "layout": "one row, frame 0 at the left",
                        "answers": what, "runtime": runtime}
        print("[fx] %s: %d frame(s)" % (name, len(frames)))

    faults, value = _check(work, files)
    if faults:
        raise SystemExit("[fx] refused:\n  " + "\n  ".join(faults))
    print("[fx] value metal %.0f > stone %.0f > organic %.0f; three "
          "silhouettes" % (value["fx_impact_metal"], value["fx_impact_stone"],
                           value["fx_impact_organic"]))

    for name in SHEETS:
        shutil.copyfile(os.path.join(work, files[name]),
                        os.path.join(out_dir, files[name]))
    record["_kit"] = {
        "status": "CANDIDATE (Arty, 2026-10-10) for Heavy Report "
                  "(review/weapon-feel, treatment 'a'); not integrated",
        "events": {"fired_pulse": ["fx_heavy_muzzle", "fx_heavy_tracer"],
                   "impact": "Prod's _impact(at, normal, collider), on "
                             "fired_pulse's own ray: pick the sheet by the "
                             "collider's surface (fx_impact_metal | stone | "
                             "organic)",
                   "hit_confirmed": "unchanged: Prod's marker and sound"},
        "fits": "every once-clip ends inside Prod's own time: muzzle 150 ms "
                "(flash decays at 140, bloom gone at 67), impacts 217-267 ms "
                "(impact_time 300)",
        "filter": "nearest, no mipmaps, as the interface kit",
        "palette": {n: "#%02x%02x%02x/%d" % c for n, c in PALETTE},
        "glyph": "ECMS Glyph CLI, revision %s" % _revision(root),
    }
    with open(os.path.join(out_dir, "fx.json"), "w") as fh:
        json.dump(record, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print("[fx] %d sheet(s) + fx.json -> %s" % (len(SHEETS), out_dir))
    if not os.environ.get("GLYPH_KEEP_WORK"):
        shutil.rmtree(work)


if __name__ == "__main__":
    main()
