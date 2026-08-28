"""The authored material vocabulary: how each theme's surfaces are painted.

`AUTHORED_CONTENT.md` lists materials under "the vocabularies compositions
are made from" -- Epsilon selects from this, it never adds to it. Today
`generation/theme_materials.gd` and `generation/textures.gd` generate the
same vocabulary procedurally at runtime, and that file is explicitly
recorded as debt against the authored-content boundary. This module is the
authored replacement's first three entries.

## What differentiates a theme, and what must NOT

The six themes are **material and dressing vocabularies inside one game**,
not six asset packs. So the split is deliberate and it is enforced by which
module a rule lives in:

**Shared by every theme, and therefore in `paintkit`:**
    the texel density, the panel-seam grammar (one shadow texel then one
    lip texel), where grime gathers, how edge wear reaches in from a module
    boundary, the stencil alphabet, the hazard stripe pitch, and every
    universal signalling colour.

**Different per theme, and therefore in this file:**
    what the structure IS -- concrete pours, steel corrugation, glazed
    tile, coursed ashlar, cut sandstone, or a checkerboard that admits it
    is a checkerboard -- plus what kind of history the surface carries.

If a player can tell two themes apart by their *grammar* rather than by
their *material*, this file has failed and the game has six asset packs.

## Batch 001 scope

Three treatments only: `concrete_facility`, `rusted_industrial`,
`void_glitch`. They are the widest spread the palette can offer -- an
institutional light surface, a warm corroded one, and the deliberately
broken one -- which is what makes them the right three to judge a style on.

**The other three are not built.** Building all six before the owner has
approved a style would be theme production, and theme production is behind
the Style Lock gate. `_TREATMENTS` is where they land afterwards.
"""

from __future__ import annotations

import paintkit
import palette as pal

#: Every architectural surface in the game is painted at this density and
#: every 128px map therefore covers exactly this many metres. Read from the
#: derived budgets rather than typed -- see `derive_budgets.py` section 2.
ARCH_DENSITY = pal.budgets()["texel_density"]["architecture"]["target"]
ARCH_SIZE = 128
ARCH_METRES = ARCH_SIZE / float(ARCH_DENSITY)

BATCH_001_THEMES = ("concrete_facility", "rusted_industrial", "void_glitch")


def _ramps(theme):
    data = pal.palette()["themes"][theme]
    return (data["base"]["ramp"], data["accent"]["ramp"], data["trim"]["ramp"])


# ----------------------------------------------------------------------
# concrete_facility -- poured panels, institutional hardware
# ----------------------------------------------------------------------

def _concrete_wall(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[2])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=1.1)
    # Concrete goes in in lifts and the lifts never match. Low strength on
    # purpose: a pour mark is a shift in value, not a different material.
    paintkit.broad_patches(canvas, surface, [base[1], base[3]],
                           cell_metres=0.55, density=0.22, strength=0.28)
    # Real panels: courses at 1.2 m and vertical joints at 2.0 m, which is
    # a plausible shutter layout and is what stops the tile reading as
    # horizontal stripes.
    paintkit.panel_grid(canvas, surface, base[0], base[3],
                        pitch_metres=1.2, vertical_pitch_metres=2.0)
    # Form-tie holes ON the courses, at the 0.5 m pitch a real shutter needs.
    surface.bolt_pitch = surface.texels(0.5)
    paintkit.bolts(canvas, surface, base[0], base[3])
    # Water finds the ties and runs. Every streak on this wall starts at a
    # hole that is actually drawn.
    for seam in surface.seams:
        for x in range(surface.bolt_pitch // 2, surface.size,
                       surface.bolt_pitch):
            if surface.hash.breaker("weep", x, seam) > 0.22:
                continue
            paintkit.streak(canvas, surface, x, seam + 2,
                            surface.texels(0.7), pal.grime(1), width=2,
                            strength=0.4)
    paintkit.speckle(canvas, surface, base[0],
                     paintkit.zone_or(paintkit.near_seams(surface, 0.08),
                                      paintkit.near_floor(surface, 0.5)),
                     density=0.10, strength=0.4)
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.42)
    paintkit.edge_wear(canvas, surface, base[1], surface.texels(0.10))
    return canvas


def _concrete_floor(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[1])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=1.2)
    paintkit.broad_patches(canvas, surface, [base[0], base[2]],
                           cell_metres=0.8, density=0.20, strength=0.25)
    # Slab joints in both axes at 2 m. A floor is a grid of pours, not a
    # stack of courses -- reusing the wall's grammar made it read as a wall
    # lying down.
    step = surface.texels(2.0)
    for i in range(0, surface.size, step):
        canvas.hline(i, 0, surface.size - 1, base[0])
        canvas.vline(i, 0, surface.size - 1, base[0])
    # Grit collects in the joints and nowhere else.
    def joint_zone(x, y, step=step):
        return 1.0 if (x % step) < 3 or (y % step) < 3 else 0.0
    paintkit.speckle(canvas, surface, base[0], joint_zone,
                     density=0.30, strength=0.45)
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.3)
    return canvas


#: Trim runs as a band along a wall, so its texture is a REPEATING STRIP
#: rather than a picture. The first version painted one safety band at one
#: height on a 4 m x 4 m tile, which meant a 0.4 m trim piece sampled a
#: 13-texel window of a 128-texel map and 90% of the paint was never seen --
#: and which window it got depended on where in the world the piece stood.
#: A 1998 trim texture was a strip that tiled, and so is this: the design
#: repeats every 0.5 m vertically, so any window a trim piece samples shows
#: a complete trim.
TRIM_CYCLE_M = 0.5


def _trim_strip(canvas, surface, rows):
    """Repeat a `rows(canvas, y0, cycle)` design up the whole tile."""
    cycle = surface.texels(TRIM_CYCLE_M)
    for y0 in range(-cycle, surface.size + cycle, cycle):
        rows(canvas, y0, cycle)


def _concrete_trim(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, trim[1])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=1.0)

    def cycle_rows(cv, y0, cycle):
        # A kick rail: dark channel, painted safety band, lit top lip.
        cv.rect(0, y0, surface.size, max(1, cycle // 8), trim[0])
        band_top = y0 + cycle // 8
        band_h = max(2, cycle // 3)
        cv.rect(0, band_top, surface.size, band_h, accent[1])
        cv.hline(band_top - 1, 0, surface.size - 1, trim[0])
        cv.hline(band_top + band_h, 0, surface.size - 1, trim[0])
        # The lit lip is what separates trim from wall in harsh flat light.
        cv.hline(y0 + cycle - 1, 0, surface.size - 1, trim[2])

    _trim_strip(canvas, surface, cycle_rows)

    # Scuffs, all over -- a kick rail is what gets kicked, and here the
    # whole surface genuinely is the thing being kicked.
    paintkit.speckle(canvas, surface, trim[0], lambda x, y: 1.0,
                     density=0.07, strength=0.5)
    paintkit.edge_wear(canvas, surface, trim[0], surface.texels(0.08),
                       strength=0.85)
    return canvas


def _concrete_accent(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, accent[1])
    paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=1.0)
    # Painted steel: a bolted plate with a stencil on it.
    inset = surface.texels(0.12)
    canvas.outline(inset, inset, surface.size - 2 * inset,
                   surface.size - 2 * inset, accent[0])
    surface.bolt_pitch = surface.texels(0.5)
    for x in range(inset + 2, surface.size - inset, surface.bolt_pitch):
        for y in (inset + 2, surface.size - inset - 3):
            canvas.set(x, y, accent[0])
            canvas.set(x, y - 1, accent[2])
    label = "sec 04"
    width = paintkit.text_width(label)
    paintkit.text(canvas, surface, (surface.size - width) // 2,
                  surface.size // 2 - 3, label, base[3])
    paintkit.speckle(canvas, surface, accent[0],
                     paintkit.near_edges(surface, 0.16),
                     density=0.14, strength=0.45)
    paintkit.edge_wear(canvas, surface, accent[0], surface.texels(0.09))
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.35)
    return canvas


# ----------------------------------------------------------------------
# rusted_industrial -- corrugation, oxidation, plate
# ----------------------------------------------------------------------

def _corrugate(canvas, surface, dark, light, pitch_metres=0.22):
    """Vertical corrugation, stepped into whole texels.

    The defining structure of the theme, and the one thing here that is a
    repeating rule rather than a placed mark -- because corrugation IS a
    repeating rule in the real world. Stepped, not shaded: a sine sampled
    at 32 texels/m is a blur.
    """
    pitch = max(3, surface.texels(pitch_metres))
    for x in range(surface.size):
        phase = (x % pitch) / float(pitch)
        if phase < 0.16:
            for y in range(surface.size):
                canvas.mix(x, y, dark, 0.45)
        elif phase > 0.80:
            for y in range(surface.size):
                canvas.mix(x, y, light, 0.30)


def _rust_wall(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[1])
    paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=1.0)
    _corrugate(canvas, surface, base[0], base[3])
    paintkit.broad_patches(canvas, surface, [accent[0], base[0]],
                           cell_metres=0.6, density=0.22, strength=0.30)
    # Sheets lap horizontally; the vertical joint is where two sheets meet.
    paintkit.panel_grid(canvas, surface, base[0], base[3],
                        pitch_metres=1.2, vertical_pitch_metres=1.35)
    surface.bolt_pitch = surface.texels(0.35)
    paintkit.bolts(canvas, surface, base[0], accent[2])
    # Rust bleeds DOWN from the fixings, and only from the fixings. That is
    # the whole difference between a rusted wall and a wall with orange
    # noise on it.
    for seam in surface.seams:
        for x in range(surface.bolt_pitch // 2, surface.size,
                       surface.bolt_pitch):
            if surface.hash.breaker("bleed", x, seam) > 0.5:
                continue
            paintkit.streak(canvas, surface, x - 1, seam + 2,
                            surface.texels(1.0), accent[1], width=3,
                            strength=0.6)
    paintkit.speckle(canvas, surface, accent[0],
                     paintkit.zone_or(paintkit.near_seams(surface, 0.10),
                                      paintkit.near_floor(surface, 0.7)),
                     density=0.14, strength=0.5)
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.5)
    paintkit.edge_wear(canvas, surface, accent[0], surface.texels(0.12),
                       strength=0.9)
    return canvas


def _rust_floor(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[0])
    paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=1.2)
    # Chequer plate: raised lozenges in alternating pairs, drawn as texel
    # runs -- exactly how it was drawn in 1998.
    step = max(4, surface.texels(0.14))
    for cy in range(0, surface.size, step):
        for cx in range(0, surface.size, step):
            flip = ((cx // step) + (cy // step)) % 2
            length = max(2, step - 2)
            for i in range(length):
                x = cx + (i if flip else length - 1 - i)
                y = cy + i
                canvas.set(x, y, base[2])
                canvas.set(x, y + 1, base[0])
    # Plate sections bolt down at their edges.
    plate = surface.texels(2.0)
    for i in range(0, surface.size, plate):
        canvas.hline(i, 0, surface.size - 1, base[0])
        canvas.vline(i, 0, surface.size - 1, base[0])
    paintkit.broad_patches(canvas, surface, [accent[0]],
                           cell_metres=0.7, density=0.22, strength=0.35)

    def plate_joint(x, y, plate=plate):
        return 1.0 if (x % plate) < 3 or (y % plate) < 3 else 0.0
    paintkit.speckle(canvas, surface, accent[1], plate_joint,
                     density=0.28, strength=0.5)
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.4)
    return canvas


def _rust_trim(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, trim[1])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=1.0)

    def cycle_rows(cv, y0, cycle):
        # A hazard band, because this is the theme where a walkway edge is
        # the thing most likely to kill you. UNIVERSAL hazard colours, never
        # the theme's own orange -- a theme-tinted hazard stripe is one the
        # player has to re-learn in every theme, which is the guess
        # AUTHORED_CONTENT.md forbids.
        band_h = max(3, cycle // 2)
        band_top = y0 + cycle // 6
        paintkit.hazard_stripes(cv, 0, band_top, surface.size, band_h,
                                pal.universal("hazard", 0),
                                pal.universal("hazard", 3),
                                pitch=max(3, surface.texels(0.1)))
        cv.hline(band_top - 1, 0, surface.size - 1, trim[0])
        cv.hline(band_top + band_h, 0, surface.size - 1, trim[0])
        cv.hline(y0 + cycle - 1, 0, surface.size - 1, trim[2])

    _trim_strip(canvas, surface, cycle_rows)
    paintkit.speckle(canvas, surface, trim[0], lambda x, y: 1.0,
                     density=0.09, strength=0.6)
    paintkit.edge_wear(canvas, surface, accent[0], surface.texels(0.09),
                       strength=0.95)
    return canvas


def _rust_accent(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, accent[0])
    paintkit.tonal_drift(canvas, surface, amount=0.07, cell_metres=0.9)
    paintkit.broad_patches(canvas, surface, [accent[1], base[0]],
                           cell_metres=0.6, density=0.30, strength=0.4)
    # Oxidised plate: a stencil half eaten away, heavy loss at the rim.
    label = "hot"
    width = paintkit.text_width(label)
    paintkit.text(canvas, surface, (surface.size - width) // 2,
                  surface.size // 2 - 3, label, base[3])
    paintkit.speckle(canvas, surface, base[0],
                     paintkit.near_edges(surface, 0.25),
                     density=0.20, strength=0.5)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.16),
                       strength=1.0)
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.45)
    return canvas


# ----------------------------------------------------------------------
# void_glitch -- the editor showing through
# ----------------------------------------------------------------------

def _void_wall(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    # The missing-texture checker, at a REAL editor's cell size. Half-Life's
    # AAATRIGGER and Quake's notexture were both 16 units on a 64px map;
    # 0.5 m is the same idea expressed in metres.
    cell = surface.texels(0.5)
    for y in range(surface.size):
        for x in range(surface.size):
            on = ((x // cell) + (y // cell)) % 2
            canvas.set(x, y, accent[1] if on else base[0])
    # ...and then the important part: it is a WALL that is missing, not a
    # checkerboard pretending to be a wall. The theme keeps the same panel
    # grammar every other theme has, drawn in the glitch colour, so
    # void_glitch reads as this game's broken room rather than as a
    # different game's texture.
    paintkit.panel_grid(canvas, surface, base[0], trim[2],
                        pitch_metres=1.2, vertical_pitch_metres=2.0)
    surface.bolt_pitch = surface.texels(0.5)
    paintkit.bolts(canvas, surface, base[0], trim[2])
    # Scanline tearing: whole rows displaced by whole texels. A displacement
    # is what a broken renderer does; noise is what a lava lamp does.
    for y in range(surface.size):
        if surface.hash.breaker("tear", 0, y) > 0.05:
            continue
        shift = 1 + int(surface.hash.breaker("shift", 0, y) * cell)
        row = [canvas.get(x, y) for x in range(surface.size)]
        for x in range(surface.size):
            canvas.set(x, y, row[(x + shift) % surface.size])
    paintkit.edge_wear(canvas, surface, trim[2], surface.texels(0.08),
                       strength=0.6)
    return canvas


def _void_floor(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    cell = surface.texels(0.5)
    for y in range(surface.size):
        for x in range(surface.size):
            on = ((x // cell) + (y // cell)) % 2
            canvas.set(x, y, base[1] if on else base[0])
    # A wireframe grid over the checker: the floor of a level nobody
    # compiled. The grid is at 1 m, the unit a 1998 editor snapped to.
    step = surface.texels(1.0)
    for i in range(0, surface.size, step):
        canvas.hline(i, 0, surface.size - 1, trim[2])
        canvas.vline(i, 0, surface.size - 1, trim[2])
    # Vertex dots where the grid crosses -- an editor draws those too.
    for y in range(0, surface.size, step):
        for x in range(0, surface.size, step):
            canvas.rect(x - 1, y - 1, 3, 3, trim[2])
    return canvas


def _void_trim(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[0])

    def cycle_rows(cv, y0, cycle):
        band_h = max(3, cycle // 2)
        band_top = y0 + cycle // 5
        cv.rect(0, band_top, surface.size, band_h, trim[2])
        # Cosmetic corruption only -- never a mechanic.
        for x in range(surface.size):
            if surface.hash.breaker("void_trim", x, y0) > 0.18:
                continue
            cv.vline(x, band_top, band_top + band_h - 1,
                     pal.universal("glitch", 3))
        cv.hline(band_top - 1, 0, surface.size - 1, base[0])
        cv.hline(band_top + band_h, 0, surface.size - 1, base[0])

    _trim_strip(canvas, surface, cycle_rows)
    return canvas


def _void_accent(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, accent[1])
    label = "null"
    width = paintkit.text_width(label)
    paintkit.text(canvas, surface, (surface.size - width) // 2,
                  surface.size // 2 - 3, label, base[0])
    for y in range(surface.size):
        if surface.hash.breaker("tear", 1, y) > 0.09:
            continue
        canvas.hline(y, 0, surface.size - 1, pal.universal("glitch", 3))
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.08),
                       strength=0.5)
    return canvas


# ----------------------------------------------------------------------
# registry
# ----------------------------------------------------------------------

_TREATMENTS = {
    "concrete_facility": {
        "wall": _concrete_wall, "floor": _concrete_floor,
        "trim": _concrete_trim, "accent": _concrete_accent,
    },
    "rusted_industrial": {
        "wall": _rust_wall, "floor": _rust_floor,
        "trim": _rust_trim, "accent": _rust_accent,
    },
    "void_glitch": {
        "wall": _void_wall, "floor": _void_floor,
        "trim": _void_trim, "accent": _void_accent,
    },
    # neon_transit, gothic_stone and temple_ruin are inventoried and NOT
    # built. Three themes is the spread a style is judged on; six is theme
    # production, and theme production is behind the Style Lock gate.
}

ROLES = ("wall", "floor", "trim", "accent")


def surface_for(role, theme, size=ARCH_SIZE, metres=ARCH_METRES):
    """The `Surface` a role is painted against. Structure, before colour."""
    seams = ()
    floor_edge = None
    if role in ("wall", "accent"):
        # Panel courses at 1.2 m, which is a plausible sheet height and puts
        # two seams plus the top edge in a 4 m tile.
        pitch = int(round(size * 1.2 / metres))
        seams = tuple(range(0, size, pitch))
        floor_edge = "bottom"
    elif role == "trim":
        floor_edge = "bottom"
    return paintkit.Surface(size, metres, role, seams=seams,
                            floor_edge=floor_edge,
                            seed="archipepsi/%s/%s" % (theme, role))


def paint(theme, role, size=ARCH_SIZE, metres=ARCH_METRES):
    """Return a painted `Canvas` for one theme/role pair."""
    if theme not in _TREATMENTS:
        raise KeyError(
            "materials: theme '%s' has no authored treatment yet. Built in "
            "Batch 001: %s. The remaining three are inventoried in "
            "docs/art/ASSET_INVENTORY.md and are behind the Style Lock gate."
            % (theme, ", ".join(sorted(_TREATMENTS))))
    if role not in ROLES:
        raise KeyError("materials: role must be one of %s" % (ROLES,))
    surface = surface_for(role, theme, size, metres)
    base = pal.palette()["themes"][theme]["base"]["ramp"][1]
    canvas = paintkit.Canvas(size, base)
    _TREATMENTS[theme][role](canvas, surface, theme)
    return canvas, surface


def built_themes():
    return tuple(sorted(_TREATMENTS))
