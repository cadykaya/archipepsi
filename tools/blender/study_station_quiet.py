"""Station noise study: concrete_facility, current vs QUIET (Arty, 2026-10-08).

    .tools/blender/blender -b --python tools/blender/study_station_quiet.py -- <out_dir>

REVIEW-ONLY. It writes PNGs into the directory it is given and nothing
into `assets/`: no shipped or candidate texture is touched. Crossing D's
review capture swaps these in memory for an A/B from identical cameras
(`tools/crossing_capture/dcap.gd`, "texture_swap").

PROVENANCE. `current_<role>.png` is painted by `materials.paint`
unchanged, and must equal the shipped theme texture byte for byte in
pixels (checked below against `assets/textures/theme/`). `quiet_<role>.png`
is painted by the SAME painters' structure with the numbers in QUIET
changed and nothing else -- the same palette ramps, seams, panel grid,
bolts, plates and ribs, so colour and landmarks stay put and only
micro-contrast moves.

What the owner reported (2026-10-07): "too much high-frequency visual
noise in walls, trims and ceiling; small repeated patterns pull the eye"
-- while the pale, cold, utilitarian station itself works. So: quieter
planes, not a new look.

The single biggest source, found by reading the painter rather than the
pictures: the wall's dark 0.85 m BASE COURSE is baked into a 4 m tile
that is mapped triplanar. On a 16 m hall wall it repeats at 0, 4, 8 and
12 m -- a floor-level detail stacked up the wall as four dark speckled
bands. QUIET removes it from the tile; a base course belongs in geometry
(a skirting block at the floor), where it happens once.
"""

from __future__ import annotations

import os
import sys

import bpy  # noqa: F401  (Blender provides it; the canvas exports through it)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import materials  # noqa: E402
import paintkit  # noqa: E402

THEME = "concrete_facility"
ROLES = ("wall", "wall_ribbed", "ceiling", "floor", "trim")

#: Every number QUIET changes, current -> quiet. Nothing else differs.
QUIET = {
    "wall.tonal_drift.amount": (0.05, 0.03),
    "wall.broad_patches.cell_metres": (0.55, 1.10),
    "wall.broad_patches.strength": (0.26, 0.10),
    "wall.weep_streak.strength": (0.40, 0.12),
    "wall.base_course.mix": (0.80, 0.00),
    "wall.speckle.density": (0.10, 0.02),
    "wall.grime_pool.strength": (0.50, 0.20),
    "wall.edge_wear.strength": (0.70, 0.30),
    "ceiling.rib_pitch_m": (0.60, 1.20),
    "ceiling.rib_highlight_line": (1, 0),
    "ceiling.broad_patches.strength": (0.28, 0.12),
    "ceiling.speckle.density": (0.22, 0.04),
    "ceiling.edge_wear.strength": (0.70, 0.30),
    "floor.broad_patches.strength": (0.25, 0.12),
    "floor.speckle.density": (0.30, 0.08),
    "trim.cycle_m": (0.50, 1.00),
    "trim.speckle.density": (0.07, 0.00),
    "trim.edge_wear.strength": (0.85, 0.35),
}


def q(key, quiet):
    return QUIET[key][1 if quiet else 0]


def wall(canvas, surface, theme, quiet, ribbed=False):
    base, accent, trim = materials._ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[2])
    for y in range(surface.size):
        for x in range(surface.size):
            canvas.mix(x, y, accent[2], materials.CONCRETE_WALL_TINT)
    paintkit.tonal_drift(canvas, surface,
                         amount=q("wall.tonal_drift.amount", quiet),
                         cell_metres=1.1)
    paintkit.broad_patches(canvas, surface, [base[1], base[3]],
                           cell_metres=q("wall.broad_patches.cell_metres", quiet),
                           density=0.22,
                           strength=q("wall.broad_patches.strength", quiet))
    if ribbed:
        pitch = surface.course(1.0)
        for x in range(0, surface.size, pitch):
            w = surface.texels(0.16)
            canvas.rect(x, 0, w, surface.size, base[1])
            canvas.vline(x - 1, 0, surface.size - 1, base[0])
            canvas.vline(x + w, 0, surface.size - 1, base[0])
            canvas.vline(x, 0, surface.size - 1, base[3])
    else:
        paintkit.panel_grid(canvas, surface, base[0], base[3],
                            pitch_metres=1.2, vertical_pitch_metres=2.0)
        surface.bolt_pitch = surface.course(0.5)
        paintkit.bolts(canvas, surface, base[0], base[3])
        for seam in surface.seams:
            for x in range(surface.bolt_pitch // 2, surface.size,
                           surface.bolt_pitch):
                if surface.hash.breaker("weep", x, seam) > 0.22:
                    continue
                paintkit.streak(canvas, surface, x, seam + 2,
                                surface.texels(0.7), materials.pal.grime(1),
                                width=2,
                                strength=q("wall.weep_streak.strength", quiet))
    mix = q("wall.base_course.mix", quiet)
    if mix > 0.0:
        course = surface.texels(0.85)
        top = surface.size - course
        for y in range(top, surface.size):
            for x in range(surface.size):
                canvas.mix(x, y, base[0], mix)
        canvas.hline(top, 0, surface.size - 1, base[3])
        canvas.hline(top + 1, 0, surface.size - 1, trim[0])
    density = q("wall.speckle.density", quiet)
    if density > 0.0:
        paintkit.speckle(canvas, surface, base[0],
                         paintkit.zone_or(paintkit.near_seams(surface, 0.08),
                                          paintkit.near_floor(surface, 0.5)),
                         density=density, strength=0.4)
    paintkit.grime_pool(canvas, surface, materials.pal.grime(0),
                        strength=q("wall.grime_pool.strength", quiet))
    paintkit.edge_wear(canvas, surface, base[1], surface.texels(0.10),
                       strength=q("wall.edge_wear.strength", quiet))


def ceiling(canvas, surface, theme, quiet):
    base, accent, trim = materials._ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[1])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=1.0)
    paintkit.broad_patches(canvas, surface, [base[0]], cell_metres=0.7,
                           density=0.24,
                           strength=q("ceiling.broad_patches.strength", quiet))
    pitch = surface.course(q("ceiling.rib_pitch_m", quiet))
    for y in range(0, surface.size, pitch):
        canvas.hline(y, 0, surface.size - 1, base[0])
        if q("ceiling.rib_highlight_line", quiet):
            canvas.hline(y + 1, 0, surface.size - 1, base[2])

    def rib_zone(x, y, pitch=pitch):
        return 1.0 if (y % pitch) < 3 else 0.0
    paintkit.speckle(canvas, surface, base[0], rib_zone,
                     density=q("ceiling.speckle.density", quiet), strength=0.45)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.12),
                       strength=q("ceiling.edge_wear.strength", quiet))


def floor(canvas, surface, theme, quiet):
    base, accent, trim = materials._ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[0])
    paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=1.2)
    paintkit.broad_patches(canvas, surface, [base[1]], cell_metres=0.8,
                           density=0.20,
                           strength=q("floor.broad_patches.strength", quiet))
    step = surface.course(2.0)
    for i in range(0, surface.size, step):
        canvas.hline(i, 0, surface.size - 1, trim[0])
        canvas.hline(i + 1, 0, surface.size - 1, base[1])
        canvas.vline(i, 0, surface.size - 1, trim[0])
        canvas.vline(i + 1, 0, surface.size - 1, base[1])

    def joint_zone(x, y, step=step):
        return 1.0 if (x % step) < 3 or (y % step) < 3 else 0.0
    paintkit.speckle(canvas, surface, base[0], joint_zone,
                     density=q("floor.speckle.density", quiet), strength=0.5)
    paintkit.grime_pool(canvas, surface, materials.pal.grime(0), strength=0.35)


def trim(canvas, surface, theme, quiet):
    base, accent, trim_ramp = materials._ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, trim_ramp[1])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=1.0)
    cycle = surface.course(q("trim.cycle_m", quiet))

    def rows(cv, y0):
        cv.rect(0, y0, surface.size, max(1, cycle // 6), trim_ramp[0])
        cv.rect(0, y0 + cycle // 6, surface.size, max(2, cycle // 2),
                trim_ramp[2])
        stripe_top = y0 + cycle // 6 + max(2, cycle // 2)
        cv.rect(0, stripe_top, surface.size, max(1, cycle // 10), accent[1])
        cv.hline(stripe_top - 1, 0, surface.size - 1, trim_ramp[0])
        cv.hline(y0 + cycle - 1, 0, surface.size - 1, trim_ramp[0])

    for y0 in range(-cycle, surface.size + cycle, cycle):
        rows(canvas, y0)
    density = q("trim.speckle.density", quiet)
    if density > 0.0:
        paintkit.speckle(canvas, surface, trim_ramp[0], lambda x, y: 1.0,
                         density=density, strength=0.5)
    paintkit.edge_wear(canvas, surface, trim_ramp[0], surface.texels(0.08),
                       strength=q("trim.edge_wear.strength", quiet))


PAINTERS = {
    "wall": lambda c, s, t, quiet: wall(c, s, t, quiet),
    "wall_ribbed": lambda c, s, t, quiet: wall(c, s, t, quiet, ribbed=True),
    "ceiling": ceiling, "floor": floor, "trim": trim,
}


def paint(role, quiet):
    surface_role = "wall_ribbed" if role == "wall_ribbed" else role
    surface = materials.surface_for(surface_role, THEME)
    base = materials.pal.palette()["themes"][THEME]["base"]["ramp"][1]
    canvas = paintkit.Canvas(surface.size, base)
    PAINTERS[role](canvas, surface, THEME, quiet)
    return canvas


def save(canvas, path):
    image = canvas.to_blender(os.path.basename(path))
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()


def main():
    out = sys.argv[sys.argv.index("--") + 1]
    os.makedirs(out, exist_ok=True)
    shipped = os.path.join(common.REPO_ROOT, "assets", "textures", "theme")
    for role in ROLES:
        for quiet in (False, True):
            path = os.path.join(out, "%s_%s.png"
                                % ("quiet" if quiet else "current", role))
            save(paint(role, quiet), path)
            print("[quiet] %s" % path)
        # Provenance: the "current" painter here must reproduce the shipped
        # texture, or the A/B is comparing against something invented.
        mine = bpy.data.images.load(os.path.join(out, "current_%s.png" % role))
        ship = bpy.data.images.load(os.path.join(
            shipped, "%s_%s.png" % (THEME, role)))
        same = list(mine.pixels) == list(ship.pixels)
        print("[quiet] current_%s reproduces shipped: %s" % (role, same))
        assert same, role
    with open(os.path.join(out, "QUIET.txt"), "w", encoding="utf-8") as fh:
        for key, (now, quiet) in QUIET.items():
            fh.write("%-36s %6s -> %s\n" % (key, now, quiet))


if __name__ == "__main__":
    main()
