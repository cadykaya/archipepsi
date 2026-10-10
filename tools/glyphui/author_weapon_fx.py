#!/usr/bin/env python3
"""Five weapons' layered effects, through ECMS Glyph. CANDIDATE (Batch 068).
(Arty, 2026-10-10.)

    GLYPH_ROOT=/home/user/glyph-trial python3 tools/glyphui/author_weapon_fx.py [OUT_DIR]

Writes `assets/fx/weapons/<weapon>/*.png` and `assets/fx/weapons/fx.json`.

THE BRIEF (owner, five-weapon overnight, 2026-10-09). Batch 067 is NOT
approved: flat, single-layer, one colour a shape. The new standard is
HYBRID: authored 2D layers here (a white-hot core, an irregular coloured
flare, side tongues, smoke, an afterglow; layered impacts per material;
persistent marks), and 3D in Prod's runtime (a dynamic light, sparks and
chips under physics, the target's reaction). This script owns the 2D;
`fx.json` says exactly where each layer sits in the 3D event.

HOW. `weaponfx_paint.py` paints every frame from shapes and seeded noise
and snaps it to the layer's own palette (at most 88 colours). Each frame
is written into a Glyph cel with `pixels.apply_patch`, each sheet gets a
timed clip, and Glyph's sprite-sheet export writes the PNG. Glyph is the
source of record for the frames and their timing; the painting is
reproducible from this file.

FOUNDRY FIRST, as the brief orders: the hand cannon gets the full layer
stack and the material impacts; the other four get distinct, simpler
sets that serve their mechanics (a cold needle, alternating compact
flashes, a wide fan and a pellet pattern, a charge-and-release). The
material impacts and marks are shared by material, scaled per weapon:
the SURFACE decides the response, not the gun.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile

import glyphrun
import weaponfx_paint as wp

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
OWNER = "act_owner_arty"
ARTIST = "act_agent_arty"
ALPHABET = [chr(c) for c in range(0x21, 0x7f) if chr(c) not in '.-"\\ ']


def _comp(*frames):
    out = frames[0]
    for f in frames[1:]:
        out = wp.over(out, f)
    return out


def _glow(w, h, sigma, rmp, hot=1.0):
    import math
    return wp.paint(w, h, lambda x, y: wp.at(rmp, wp.clamp(hot * math.exp(
        -(((x - w / 2) ** 2 + (y - h / 2) ** 2) / (sigma * sigma))))))


def _ring(w, h, r0, r1, rmp, hot):
    import math

    def fn(x, y):
        r = math.hypot(x - w / 2, y - h / 2)
        t = 0.0 if r > r1 else (1.0 if r < r0 else 1 - (r - r0) / (r1 - r0))
        return wp.at(rmp, wp.clamp(t * hot))
    return wp.paint(w, h, fn)


def _chips(w, h, seed):
    """Three pebble variants side by side, lit from above."""
    import math
    import random
    rng = random.Random(seed)
    shapes = [[0.6 + 0.4 * rng.random() for _ in range(7)] for _ in range(3)]
    cell = w // 3

    def fn(x, y):
        k = int(x // cell)
        cx, cy = k * cell + cell / 2, h / 2
        dx, dy = x - cx, y - cy
        th = math.atan2(dy, dx)
        i = int(((th + math.pi) / 6.283) * 7) % 7
        rad = (h / 2 - 0.6) * shapes[k][i]
        if math.hypot(dx, dy) > rad:
            return (0, 0, 0, 0)
        v = 200 - 110 * wp.clamp((dy + rad) / (2 * rad))
        return (int(v), int(v * 0.96), int(v * 0.9), 255)
    return wp.paint(w, h, fn)


def F(*frames):
    return list(frames)


# name: (weapon, w, h, frames(), durations ms, loop, spec)
#   spec: event, blend (add|mix), orient, size_m, order, note
def sheets():
    S = {}

    def add(name, weapon, w, h, frames, durations, loop, **spec):
        S[name] = dict(weapon=weapon, w=w, h=h, frames=frames,
                       durations=durations, loop=loop, spec=spec)

    # --------------------------------------------------------- FOUNDRY
    add("foundry_flash_core", "foundry", 32, 32, lambda: F(
        wp.core(32, 32, 4.5, 4, 6.0, 1), wp.core(32, 32, 3.0, 4, 4.0, 2)),
        [17, 17], "once", event="fired", blend="add", orient="billboard",
        size_m=0.18, order=4, at="muzzle",
        note="white-hot centre; drawn last, on top")
    add("foundry_flash_flare", "foundry", 96, 96, lambda: F(
        wp.flare(96, 96, 40, 7, 11, 0.0, 1.25),
        wp.flare(96, 96, 46, 7, 12, 0.5, 0.95),
        wp.flare(96, 96, 48, 6, 13, 1.0, 0.6)),
        [17, 17, 33], "once", event="fired", blend="add",
        orient="billboard", size_m=0.5, order=3, at="muzzle",
        note="irregular orange flare; roll it randomly per shot")
    add("foundry_brake_tongue", "foundry", 96, 32, lambda: F(
        wp.jet(96, 32, 70, 7, 21), wp.jet(96, 32, 88, 9, 22, 0.5, 0.9),
        wp.jet(96, 32, 92, 10, 23, 1.0, 0.6)),
        [17, 17, 33], "once", event="fired", blend="add",
        orient="plane, +X out of each brake port (two, mirrored)",
        size_m=0.36, order=2, at="brake_port_l / brake_port_r",
        note="side tongues out of the muzzle brake's ports")
    add("foundry_smoke", "foundry", 64, 64, lambda: [
        wp.puff(64, 64, 5, 31, 1.0 - 0.13 * i, rise=2.5 * i,
                spread=0.8 + 0.16 * i) for i in range(6)],
        [60, 80, 100, 140, 180, 240], "once", event="fired", blend="mix",
        orient="billboard, world-anchored where the shot left the barrel",
        size_m=0.4, order=1, at="muzzle (world)",
        note="residual smoke; starts 0.25 m ahead of the muzzle, drifts up "
             "~0.3 m over 0.8 s")
    add("foundry_afterglow", "foundry", 16, 16, lambda: [
        wp.core(16, 16, s, 0, 1.0, 3, rmp=wp.EMBER)
        for s in (3.2, 2.7, 2.2, 1.7)],
        [50, 80, 120, 200], "once", event="fired", blend="add",
        orient="billboard", size_m=0.05, order=5, at="muzzle",
        note="the bore's ember after the flash")
    add("foundry_slug", "foundry", 32, 16, lambda: F(
        wp.slug(32, 16, 7, 2.4), wp.slug(32, 16, 6, 2.0, hot=0.9)),
        [17, 17], "loop", event="projectile", blend="add",
        orient="axis: +X along travel, face the camera", size_m=0.16,
        order=2, at="the round, muzzle -> resolved hit",
        note="the hot round itself")
    add("foundry_trail", "foundry", 128, 16, lambda: F(
        wp.streak(128, 16, 10, thick=1.6, seed=41)),
        [60], "hold_last", event="projectile", blend="mix",
        orient="axis ribbon: +X head end", size_m=1.6, order=1,
        at="behind the round", note="hot near the round, smoke behind")

    # ------------------------------------------------ MATERIAL IMPACTS
    add("impact_metal_flash", "impacts", 64, 64, lambda: F(
        _comp(wp.rays(64, 64, 9, 3, 26, 51, width=0.9),
              wp.core(64, 64, 4.0, 3, 6.0, 52)),
        _comp(wp.rays(64, 64, 11, 6, 30, 53, width=0.8, hot=0.85),
              _glow(64, 64, 3.0, wp.FLAME, 0.8)),
        wp.rays(64, 64, 8, 12, 31, 54, width=0.7, hot=0.55)),
        [17, 17, 33], "once", event="impact:metal", blend="add",
        orient="billboard at hit + normal * 0.03", size_m=0.5, order=3,
        note="white-hot star breaking into streaks; Prod's 3D sparks fly "
             "from the same point")
    add("impact_metal_heat", "impacts", 32, 32, lambda: [
        _ring(32, 32, 3.0, 9.0, wp.HEAT, h) for h in (1.0, 0.75, 0.5, 0.28)],
        [120, 300, 600, 1000], "once", event="impact:metal",
        blend="add", orient="surface (on the normal), over the hole decal",
        size_m=0.16, order=2, note="the hole's hot rim cooling over ~2 s, "
                                  "then gone; the hole stays")
    add("impact_metal_smoke", "impacts", 48, 48, lambda: [
        wp.puff(48, 48, 3, 55, 0.9 - 0.15 * i, rise=2 * i,
                spread=0.6 + 0.15 * i) for i in range(5)],
        [60, 80, 120, 160, 220], "once", event="impact:metal", blend="mix",
        orient="billboard", size_m=0.35, order=1,
        note="a wisp off the struck steel")
    add("impact_stone_dust", "impacts", 96, 96, lambda: [
        _comp(wp.puff(96, 96, 6, 61, 1.0, 0, 0.8, rmp=wp.DUST),
              wp.rays(96, 96, 9, 6, 42, 62, rmp=wp.DUST, width=4.0,
                      hot=0.75))
    ] + [wp.puff(96, 96, 6, 61, 1.0 - 0.18 * i, rise=2 * i,
                 spread=0.8 + 0.25 * i, rmp=wp.DUST) for i in range(1, 5)],
        [33, 50, 83, 117, 167], "once", event="impact:stone", blend="mix",
        orient="billboard at hit + normal * 0.05", size_m=0.8, order=2,
        note="dust jets, then a billowing cloud; no light, no sparks")
    add("impact_stone_chips", "impacts", 24, 8, lambda: F(
        _chips(24, 8, 63)), [1], "variants", event="impact:stone",
        blend="mix", orient="particle quad (three variants side by side)",
        size_m=0.03, order=1, note="Prod's chip particles: pick a variant")
    add("impact_flesh_splash", "impacts", 64, 64, lambda: [
        wp.drops(64, 64, 14, 9 + 5 * i, 3.0 - 0.4 * i, 71, fall=2.5 * i,
                 mist=0.8 - 0.25 * i) for i in range(4)],
        [33, 50, 83, 117], "once", event="impact:flesh", blend="mix",
        orient="billboard", size_m=0.45, order=2,
        note="a soft wet burst, muted, not gore; no light, no sparks")

    # --------------------------------------------------- PERSISTENT MARKS
    # GAME SCALE, not real scale: a true 7 cm hole is 2-4 px at the range's
    # 9 m. Sizes are the whole cell (soot and scrape included), in line
    # with Prod's own Decal sizes (0.22-0.4 m); the bore stays small inside.
    add("decal_metal_hole", "marks", 48, 48, lambda: F(
        wp.metal_hole(48, 48, 81), wp.metal_hole(48, 48, 82)),
        [1, 1], "variants", event="mark:metal", blend="mix",
        orient="decal on the hit normal; random roll", size_m=0.16,
        order=1, note="black bore, bright scraped rim, chipped paint, soot")
    add("decal_metal_dent", "marks", 48, 48, lambda: F(
        wp.metal_dent(48, 48, 83)), [1], "variants", event="mark:metal",
        blend="mix", orient="decal on the hit normal", size_m=0.2,
        order=1, note="heavy blunt hits (Mass Driver; Bulkhead's centre)")
    add("decal_stone_crater", "marks", 48, 48, lambda: F(
        wp.stone_crater(48, 48, 84), wp.stone_crater(48, 48, 85)),
        [1, 1], "variants", event="mark:stone", blend="mix",
        orient="decal on the hit normal; random roll", size_m=0.24,
        order=1, note="chipped crater, cracks, dust halo")
    add("decal_flesh_mark", "marks", 48, 48, lambda: F(
        wp.soft_mark(48, 48, 86)), [1], "variants", event="mark:flesh",
        blend="mix", orient="decal on the hit normal", size_m=0.18,
        order=1, note="puncture, wet rim, muted bruise; no gore")
    add("decal_wood_mark", "marks", 48, 48, lambda: F(
        wp.wood_mark(48, 48, 87)), [1], "variants", event="mark:wood",
        blend="mix", orient="decal; +X along the grain", size_m=0.18,
        order=1, note="for Prod's timber crate")

    # ------------------------------------------------------- SIGHTLINE
    add("sightline_flash", "sightline", 48, 48, lambda: F(
        wp.core(48, 48, 2.2, 2, 10.0, 91, rmp=wp.COLD),
        wp.core(48, 48, 1.6, 2, 6.0, 92, rmp=wp.COLD)),
        [17, 17], "once", event="fired", blend="add", orient="billboard",
        size_m=0.22, order=3, at="muzzle", note="a cold, narrow flick")
    add("sightline_tracer", "sightline", 128, 4, lambda: F(
        wp.streak(128, 4, 6, thick=0.6, seed=93, rmp=wp.COLD)),
        [33], "hold_last", event="projectile", blend="add",
        orient="axis ribbon", size_m=1.2, order=1,
        note="a thin needle, fast")
    add("sightline_pop", "sightline", 32, 32, lambda: F(
        _comp(wp.rays(32, 32, 6, 2, 12, 94, rmp=wp.COLD, width=0.6),
              wp.core(32, 32, 2.5, 3, 5.0, 95, rmp=wp.COLD)),
        wp.rays(32, 32, 5, 5, 14, 96, rmp=wp.COLD, width=0.5, hot=0.6)),
        [17, 33], "once", event="impact:any", blend="add",
        orient="billboard", size_m=0.2, order=4,
        note="a precise cold pop over the material's own response at 0.5 "
             "scale")
    add("sightline_mark", "sightline", 24, 24, lambda: F(
        wp.metal_hole(24, 24, 97, bore=1.6)), [1], "variants",
        event="mark:metal", blend="mix", orient="decal", size_m=0.08,
        order=1, note="a small clean hole")

    # ------------------------------------------------------ SWITCHBACK
    add("switchback_flash_a", "switchback", 48, 48, lambda: F(
        wp.flare(48, 48, 16, 3, 101), wp.flare(48, 48, 18, 3, 101, 0.7)),
        [17, 17], "once", event="fired (odd rounds)", blend="add",
        orient="billboard", size_m=0.24, order=3, at="muzzle",
        note="three-prong; alternates with B so the stream flickers")
    add("switchback_flash_b", "switchback", 48, 48, lambda: F(
        wp.flare(48, 48, 15, 4, 102), wp.flare(48, 48, 17, 4, 102, 0.7)),
        [17, 17], "once", event="fired (even rounds)", blend="add",
        orient="billboard", size_m=0.24, order=3, at="muzzle",
        note="four-prong partner of A")
    add("switchback_tracer", "switchback", 48, 6, lambda: F(
        wp.streak(48, 6, 6, thick=0.7, seed=103, hot=0.9)),
        [33], "hold_last", event="projectile", blend="add",
        orient="axis ribbon", size_m=0.5, order=1,
        note="short speck; every second round only")
    add("switchback_pock", "switchback", 16, 16, lambda: F(
        wp.stone_crater(16, 16, 104)), [1], "variants", event="mark:any",
        blend="mix", orient="decal", size_m=0.07, order=1,
        note="a small pock; cap these hard, they come fast")

    # -------------------------------------------------------- BULKHEAD
    add("bulkhead_flash", "bulkhead", 128, 64, lambda: F(
        _comp(wp.flare(128, 64, 19, 13, 111, 0.0, 1.0, stretch=3.1),
              wp.rays(128, 64, 11, 10, 60, 131, width=0.8, hot=0.9,
                      squash=2.4)),
        _comp(wp.flare(128, 64, 20, 13, 112, 0.5, 0.85, stretch=3.1),
              wp.rays(128, 64, 11, 16, 62, 132, width=0.7, hot=0.6,
                      squash=2.4)),
        wp.flare(128, 64, 20, 12, 113, 1.0, 0.55, stretch=3.1)),
        [17, 25, 40], "once", event="fired", blend="add",
        orient="billboard (wide)", size_m=0.7, order=3, at="muzzle",
        note="a flat, wide spray with pellet spikes, much wider than tall")
    add("bulkhead_smoke", "bulkhead", 96, 64, lambda: [
        wp.puff(96, 64, 7, 114, 1.0 - 0.12 * i, rise=1.5 * i,
                spread=0.75 + 0.1 * i) for i in range(6)],
        [70, 90, 120, 160, 200, 260], "once", event="fired", blend="mix",
        orient="billboard", size_m=0.6, order=1, at="muzzle (world)",
        note="a thick wide cloud")
    add("bulkhead_pellet", "bulkhead", 64, 4, lambda: F(
        wp.streak(64, 4, 4, thick=0.5, seed=115)), [25], "hold_last",
        event="projectile (per pellet)", blend="add", orient="axis ribbon",
        size_m=0.4, order=1, note="thin, many, short-lived")
    add("bulkhead_blast", "bulkhead", 96, 96, lambda: F(
        _comp(wp.rays(96, 96, 14, 4, 40, 116, rmp=wp.DUST, width=1.6),
              wp.core(96, 96, 5.0, 4, 8.0, 117)),
        wp.puff(96, 96, 7, 118, 1.0, 1, 1.0, rmp=wp.DUST),
        wp.puff(96, 96, 7, 118, 0.7, 4, 1.4, rmp=wp.DUST),
        wp.puff(96, 96, 7, 118, 0.4, 7, 1.8, rmp=wp.DUST)),
        [33, 50, 83, 117], "once", event="impact:pattern centre",
        blend="mix", orient="billboard at the pattern's centre",
        size_m=0.9, order=2,
        note="ONE central blast per shot per surface, not one per pellet")
    add("bulkhead_mark", "bulkhead", 64, 64, lambda: F(
        wp.cluster(64, 64, 119)), [1], "variants",
        event="mark:pattern", blend="mix", orient="decal at the centre",
        size_m=0.45, order=1,
        note="one coherent pattern: a centre and its pocks")

    # ----------------------------------------------------- MASS DRIVER
    add("massdriver_charge", "massdriver", 64, 32, lambda: [
        wp.bolts(64, 32, 6, 121, lv) for lv in (0.25, 0.5, 0.75, 1.0)],
        [1, 1, 1, 1], "by_charge", event="charging",
        blend="add", orient="plane along the accumulator rails",
        size_m=0.3, order=2, at="accumulator",
        note="frame = charge quarter (0-25-50-75-100 %)")
    add("massdriver_release", "massdriver", 96, 96, lambda: F(
        _comp(wp.rays(96, 96, 16, 8, 46, 122, rmp=wp.VOLT, width=1.0),
              wp.core(96, 96, 6.0, 6, 14.0, 123, rmp=wp.VOLT)),
        wp.rays(96, 96, 16, 14, 47, 124, rmp=wp.VOLT, width=0.9, hot=0.8),
        wp.rays(96, 96, 12, 22, 47, 125, rmp=wp.VOLT, width=0.8, hot=0.5)),
        [17, 33, 50], "once", event="released", blend="add",
        orient="billboard", size_m=0.5, order=3, at="muzzle",
        note="pressure lines bursting outward -- not a ring")
    add("massdriver_slug", "massdriver", 48, 16, lambda: F(
        wp.slug(48, 16, 9, 3.0, rmp=wp.VOLT),
        wp.slug(48, 16, 8, 2.6, rmp=wp.VOLT, hot=0.85)),
        [33, 33], "loop", event="projectile", blend="add",
        orient="axis", size_m=0.25, order=2, note="a dense slug, slower")
    add("massdriver_trail", "massdriver", 128, 16, lambda: F(
        wp.streak(128, 16, 10, thick=1.8, rmp=wp.VOLT, seed=126,
                  segments=6)), [60], "hold_last", event="projectile",
        blend="add", orient="axis ribbon", size_m=2.0, order=1,
        note="pulsed segments: its mass, made visible")
    add("massdriver_impact", "massdriver", 96, 96, lambda: F(
        _comp(wp.rays(96, 96, 18, 10, 46, 127, rmp=wp.DUST, width=2.2),
              wp.core(96, 96, 7.0, 4, 10.0, 128, rmp=wp.VOLT)),
        wp.shock_ring(96, 96, 16, 6.0, 129, 1.0),
        wp.shock_ring(96, 96, 28, 7.0, 129, 0.75),
        wp.shock_ring(96, 96, 38, 7.0, 129, 0.45)),
        [33, 50, 83, 133], "once", event="impact:any", blend="mix",
        orient="billboard", size_m=1.1, order=3,
        note="a kinetic shock: a dust ring outward, a brief violet-white "
             "flash")
    add("massdriver_mark", "massdriver", 64, 64, lambda: F(
        wp.kinetic_mark(64, 64, 130)), [1], "variants", event="mark:any",
        blend="mix", orient="decal", size_m=0.4, order=1,
        note="a broad flattened dish with stress fractures; any surface")
    return S


def _revision(root):
    out = subprocess.run(["git", "-C", root, "rev-parse", "--short=7", "HEAD"],
                         capture_output=True, text=True)
    return out.stdout.strip() or "unknown"


def main():
    out_dir = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else
                              os.path.join(REPO, "assets", "fx", "weapons"))
    root = os.environ.get("GLYPH_ROOT", "/home/user/glyph-trial")
    work = tempfile.mkdtemp(prefix="glyphwfx_")
    ses = glyphrun.Session(root, work, "archipepsi_weapon_fx.glyph", OWNER,
                           ARTIST)
    ses.create("the art lane draws the five weapons' layered effects")
    asset = ses.txn({"creates": ["asset"]}, [
        ("asset.create", {"name": "weapon_fx"})], "the weapons' effects"
    )[0]["asset"]["id"]

    record = {}
    for name, s in sheets().items():
        w, h, durations = s["w"], s["h"], s["durations"]
        frames = s["frames"]()
        assert len(frames) == len(durations), name
        pal = wp.palette_of(frames)
        if len(pal) > len(ALPHABET):
            raise SystemExit("%s needs %d colours" % (name, len(pal)))
        sym = {c: ALPHABET[i] for i, c in enumerate(pal)}
        memo = {}
        made = ses.txn({"creates": ["variant"]}, [
            ("variant.create", {"name": name, "width": w, "height": h,
                                "color_mode": "rgba", "asset": asset,
                                "representation": "effect"})],
            "the %s canvas" % name)
        variant = made[0]["variant"]["id"]
        first = made[0]["variant"]["frames"][0]
        frame_ids = [first["id"] if isinstance(first, dict) else first]
        cels = [made[0]["variant"]["cels"][0]]
        if len(frames) > 1:
            for m in ses.txn({"variants": [variant]}, [
                    ("frame.create", {"variant": variant})
                    for _ in range(len(frames) - 1)], "%s's frames" % name):
                cels.append(m["cels"][0]["cel"])
                frame_ids.append(m["frame"]["id"])
        steps = []
        for cel, fr in zip(cels, frames):
            snapped = wp.snap(fr, pal, memo)
            rows = ["".join("." if p is None else sym[p] for p in row)
                    for row in snapped]
            used = {ch for row in rows for ch in row if ch != "."}
            steps.append(("pixels.apply_patch", {"cel": cel, "patch": {
                "form": "dense", "origin": [0, 0], "size": [w, h],
                "symbols": {sym[c]: {"rgba": list(c)} for c in pal
                            if sym[c] in used},
                "rows": rows}}))
        ses.txn({"cels": cels}, steps, "%s, painted" % name)
        loop = s["loop"] if s["loop"] in ("once", "loop", "hold_last") \
            else "hold_last"
        ses.txn({"creates": ["clip"]}, [
            ("clip.create", {"variant": variant, "name": name,
                             "frames": [{"frame": f, "duration": d}
                                        for f, d in zip(frame_ids,
                                                        durations)],
                             "loop": loop,
                             "timing": {"unit": "milliseconds"}})],
            "%s's timing" % name)
        results = ses.batch([
            {"command": "export.define_preset",
             "input": ses.sheet_preset("wfx_%s" % name, [variant],
                                       w * len(frames), h)},
            {"command": "export.run",
             "input": {"preset": "$1.preset", "destination": work}},
        ], label=name)
        before = set(f for f in os.listdir(work) if f.endswith(".png"))
        ses.write_export(results[1]["record"], label=name)
        fresh = sorted(set(f for f in os.listdir(work)
                           if f.endswith(".png")) - before)
        if len(fresh) != 1:
            raise SystemExit("%s exported %d page(s)" % (name, len(fresh)))
        dest = os.path.join(out_dir, s["weapon"], "%s.png" % name)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.move(os.path.join(work, fresh[0]), dest)
        spec = dict(s["spec"])
        record[name] = dict(spec, weapon=s["weapon"],
                            file="%s/%s.png" % (s["weapon"], name),
                            cell=[w, h], frames=len(frames),
                            durations_ms=durations, loop=s["loop"],
                            colours=len(pal))
        print("[wfx] %-22s %d frame(s), %d colours" % (name, len(frames),
                                                       len(pal)))

    faults = _check(out_dir, record)
    if faults:
        raise SystemExit("[wfx] refused:\n  " + "\n  ".join(faults))
    record["_kit"] = {
        "status": "CANDIDATE (Arty, 2026-10-10), Batch 068, for the "
                  "five-weapon range; supersedes Batch 067 (not approved)",
        "glyph": "ECMS Glyph CLI, revision %s" % _revision(root),
        "layout": "one row a sheet, frame 0 at the left; nearest filter",
        "loops": "'variants' = pick a frame (random or by rule), not a "
                 "clip; 'by_charge' = frame by charge quarter",
        "material_tag": "Prod's `impact_material` meta (metal | stone | "
                        "wood | flesh), as on review/hand-cannon",
    }
    with open(os.path.join(out_dir, "fx.json"), "w") as fh:
        json.dump(record, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print("[wfx] %d sheet(s) + fx.json -> %s" % (len(record) - 1, out_dir))
    if not os.environ.get("GLYPH_KEEP_WORK"):
        shutil.rmtree(work)


def _check(out_dir, record):
    """Read what Glyph wrote: sizes, no empty frame, the three materials
    told apart by value, the five muzzle flashes told apart by shape."""
    from PIL import Image
    faults, value, masks = [], {}, {}
    for name, r in record.items():
        with Image.open(os.path.join(out_dir, r["file"])) as page:
            img = page.convert("RGBA")
        w, h = r["cell"]
        if img.size != (w * r["frames"], h):
            faults.append("%s is %s" % (name, img.size))
            continue
        for f in range(r["frames"]):
            if not img.crop((f * w, 0, f * w + w, h)).getbbox():
                faults.append("%s frame %d is empty" % (name, f))
        fr0 = img.crop((0, 0, w, h))
        px = [p for p in fr0.getdata() if p[3] > 0]
        value[name] = sum(0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
                          for p in px) / max(1, len(px))
        masks[name] = {i for i, p in enumerate(
            fr0.resize((32, 32), Image.NEAREST).getdata()) if p[3] > 60}
    if not (value["impact_metal_flash"] > value["impact_stone_dust"]
            > value["impact_flesh_splash"]):
        faults.append("materials must step down metal > stone > flesh: %s"
                      % {k: round(value[k]) for k in ("impact_metal_flash",
                                                      "impact_stone_dust",
                                                      "impact_flesh_splash")})
    flashes = ["foundry_flash_flare", "sightline_flash", "switchback_flash_a",
               "bulkhead_flash", "massdriver_release"]
    for i, a in enumerate(flashes):
        for b in flashes[i + 1:]:
            iou = len(masks[a] & masks[b]) / max(1, len(masks[a] | masks[b]))
            if iou > 0.6:
                faults.append("%s and %s share a silhouette (%.2f)"
                              % (a, b, iou))
    return faults


if __name__ == "__main__":
    main()
