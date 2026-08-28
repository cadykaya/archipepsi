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
    """base, accent, trim -- and they are NOT the same length.

    `base` has four steps; `accent` and `trim` have three. Reaching for
    `accent[3]` is an IndexError at build time, which is the good outcome;
    the bad one would have been a silent clamp giving two themes a
    highlight the palette never defined.
    """
    data = pal.palette()["themes"][theme]
    return (data["base"]["ramp"], data["accent"]["ramp"], data["trim"]["ramp"])


# ----------------------------------------------------------------------
# concrete_facility -- poured panels, institutional hardware
# ----------------------------------------------------------------------

#: The revised concrete_facility value hierarchy, and the reason it exists.
#:
#: Batch 001 read as "too uniformly pale and clinical". The cause was
#: measurable rather than a matter of taste: floor sat at L* 0.59, wall at
#: 0.76, and the ceiling borrowed the wall, so the three surfaces filling
#: most of the frame spanned 0.17 of value between them. The palette check
#: passed the whole time -- 0.17 clears the 0.10 floor -- which is a good
#: example of a check telling you the thing matches its description without
#: telling you the description was worth matching.
#:
#: Four separated values now, spanning 0.56 rather than 0.17:
#:
#:   trim     L* 0.20   structural, the darkest thing in the room
#:   floor    L* 0.42   walked on, dirtiest, and no longer the mid value
#:   ceiling  L* 0.59   between, so it never reads as a wall lying down
#:   wall     L* 0.76   pale institutional paint -- the brightest surface
#:
#: The owner's facility language is "cold gray concrete, white / pale blue
#: painted walls", so the wall paint carries a slight cool cast toward the
#: theme accent rather than being neutral grey. That is a TINT, a few
#: percent, not the accent used as a fill.
CONCRETE_WALL_TINT = 0.10


def _concrete_wall(canvas, surface, theme, ribbed=False):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[2])
    # Pale blue institutional paint, not neutral grey.
    for y in range(surface.size):
        for x in range(surface.size):
            canvas.mix(x, y, accent[2], CONCRETE_WALL_TINT)
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=1.1)
    paintkit.broad_patches(canvas, surface, [base[1], base[3]],
                           cell_metres=0.55, density=0.22, strength=0.26)

    if ribbed:
        # A pilaster variant. The room read as "every surface exposes the
        # same exact 4 m panel rhythm"; the fix is not less structure, it is
        # a SECOND structure that alternates with the first.
        pitch = surface.texels(1.0)
        for x in range(0, surface.size, pitch):
            w = surface.texels(0.16)
            canvas.rect(x, 0, w, surface.size, base[1])
            canvas.vline(x - 1, 0, surface.size - 1, base[0])
            canvas.vline(x + w, 0, surface.size - 1, base[0])
            canvas.vline(x, 0, surface.size - 1, base[3])
        # No horizontal courses: the ribs ARE the rhythm here.
    else:
        paintkit.panel_grid(canvas, surface, base[0], base[3],
                            pitch_metres=1.2, vertical_pitch_metres=2.0)
        surface.bolt_pitch = surface.texels(0.5)
        paintkit.bolts(canvas, surface, base[0], base[3])
        for seam in surface.seams:
            for x in range(surface.bolt_pitch // 2, surface.size,
                           surface.bolt_pitch):
                if surface.hash.breaker("weep", x, seam) > 0.22:
                    continue
                paintkit.streak(canvas, surface, x, seam + 2,
                                surface.texels(0.7), pal.grime(1), width=2,
                                strength=0.4)

    # A dark base course along the bottom metre. Real institutional
    # buildings have one, it grounds a pale wall, and it puts a hard
    # horizontal value break exactly where the eye meets the floor -- which
    # is most of what "stronger separation between floor and walls" means in
    # a room you view from 1.6 m.
    course = surface.texels(0.85)
    top = surface.size - course
    for y in range(top, surface.size):
        for x in range(surface.size):
            # Mixed toward the concrete's own dark step, not toward trim.
            # Mixing toward trim stacked a second blue band on top of the
            # kick rail and put a ring of colour round the whole room at
            # exactly eye-to-floor height.
            canvas.mix(x, y, base[0], 0.80)
    canvas.hline(top, 0, surface.size - 1, base[3])
    canvas.hline(top + 1, 0, surface.size - 1, trim[0])

    paintkit.speckle(canvas, surface, base[0],
                     paintkit.zone_or(paintkit.near_seams(surface, 0.08),
                                      paintkit.near_floor(surface, 0.5)),
                     density=0.10, strength=0.4)
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.5)
    paintkit.edge_wear(canvas, surface, base[1], surface.texels(0.10))
    return canvas


def _concrete_wall_ribbed(canvas, surface, theme):
    return _concrete_wall(canvas, surface, theme, ribbed=True)


def _concrete_floor(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    # base[0], not base[1]. The floor is now the second-darkest large
    # surface rather than the mid value, which is what stops the room
    # reading as one continuous pale field.
    canvas.rect(0, 0, surface.size, surface.size, base[0])
    paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=1.2)
    paintkit.broad_patches(canvas, surface, [base[1]],
                           cell_metres=0.8, density=0.20, strength=0.25)
    step = surface.texels(2.0)
    for i in range(0, surface.size, step):
        canvas.hline(i, 0, surface.size - 1, trim[0])
        canvas.hline(i + 1, 0, surface.size - 1, base[1])
        canvas.vline(i, 0, surface.size - 1, trim[0])
        canvas.vline(i + 1, 0, surface.size - 1, base[1])

    def joint_zone(x, y, step=step):
        return 1.0 if (x % step) < 3 or (y % step) < 3 else 0.0
    paintkit.speckle(canvas, surface, base[0], joint_zone,
                     density=0.30, strength=0.5)
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.35)
    return canvas


def _concrete_ceiling(canvas, surface, theme):
    """A deck, not a wall lying down.

    Sits at the middle value so it separates from both the pale wall and the
    dark floor, and its structure runs one way only -- a deck spans, and a
    surface with a grid on it reads as a floor seen from underneath.
    """
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[1])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=1.0)
    paintkit.broad_patches(canvas, surface, [base[0]],
                           cell_metres=0.7, density=0.24, strength=0.28)
    # Ribbed soffit: spanning ribs at 0.6 m, one direction only.
    pitch = surface.texels(0.6)
    for y in range(0, surface.size, pitch):
        canvas.hline(y, 0, surface.size - 1, base[0])
        canvas.hline(y + 1, 0, surface.size - 1, base[2])

    def rib_zone(x, y, pitch=pitch):
        return 1.0 if (y % pitch) < 3 else 0.0
    paintkit.speckle(canvas, surface, base[0], rib_zone,
                     density=0.22, strength=0.45)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.12),
                       strength=0.7)
    return canvas


#: Trim runs as a band along a wall, so its texture is a REPEATING STRIP
#: rather than a picture -- a 0.4 m trim piece samples only a 13-texel
#: window of a 128-texel map, and which window depends on where in the world
#: the piece stands. A 1998 trim texture tiled; so does this.
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
        # A kick rail is dark structural metal with a THIN painted stripe --
        # not a painted rail. The first version gave the accent a third of
        # every cycle, and since the rail runs round the entire room that
        # made it the most saturated thing in shot: the review's "accent
        # carrying too much of the scene", concentrated in one module.
        cv.rect(0, y0, surface.size, max(1, cycle // 6), trim[0])
        cv.rect(0, y0 + cycle // 6, surface.size, max(2, cycle // 2), trim[2])
        stripe_top = y0 + cycle // 6 + max(2, cycle // 2)
        cv.rect(0, stripe_top, surface.size, max(1, cycle // 10), accent[1])
        cv.hline(stripe_top - 1, 0, surface.size - 1, trim[0])
        cv.hline(y0 + cycle - 1, 0, surface.size - 1, trim[0])

    _trim_strip(canvas, surface, cycle_rows)
    paintkit.speckle(canvas, surface, trim[0], lambda x, y: 1.0,
                     density=0.07, strength=0.5)
    paintkit.edge_wear(canvas, surface, trim[0], surface.texels(0.08),
                       strength=0.85)
    return canvas


def _concrete_accent(canvas, surface, theme):
    """The accent, used as a MARKED surface rather than a painted one.

    The review found the accent "carrying too much of the scene" -- nearly
    every manufactured object in the room came out steel blue, because both
    this role and the prop skin filled with `accent[1]`. The accent's job is
    to mark a thing as significant, and a colour that marks everything marks
    nothing.
    """
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[1])
    paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=1.0)
    inset = surface.texels(0.12)
    canvas.outline(inset, inset, surface.size - 2 * inset,
                   surface.size - 2 * inset, base[0])
    # ONE accent band, not an accent fill.
    band = surface.texels(0.30)
    top = surface.size // 2 - band // 2
    canvas.rect(0, top, surface.size, band, accent[1])
    canvas.hline(top - 1, 0, surface.size - 1, base[3])
    canvas.hline(top + band, 0, surface.size - 1, base[0])
    surface.bolt_pitch = surface.texels(0.5)
    for x in range(inset + 2, surface.size - inset, surface.bolt_pitch):
        for y in (inset + 2, surface.size - inset - 3):
            canvas.set(x, y, base[0])
            canvas.set(x, y - 1, base[3])
    label = "sec 04"
    width = paintkit.text_width(label)
    paintkit.text(canvas, surface, (surface.size - width) // 2,
                  top + band // 2 - 2, label, base[3])
    paintkit.speckle(canvas, surface, base[0],
                     paintkit.near_edges(surface, 0.16),
                     density=0.14, strength=0.45)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.09))
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

# ----------------------------------------------------------------------
# shared masonry
# ----------------------------------------------------------------------

def _coursed(canvas, surface, joint, highlight, course_metres, block_metres,
             stagger=0.5, tag="course"):
    """Staggered masonry: horizontal courses, offset vertical joints.

    `panel_grid` draws a REGULAR grid, which is right for a panelled wall
    and wrong for a wall that was laid. The whole read of coursed stone is
    that no vertical joint continues past its own course -- a grid of
    squares is tiling, and the eye names it as tiling instantly.

    Each course gets its own offset, jittered off the nominal stagger by a
    hash, because a perfectly alternating bond is a machine's bond.
    """
    course = max(2, surface.texels(course_metres))
    block = max(3, surface.texels(block_metres))
    for index, y in enumerate(range(0, surface.size, course)):
        canvas.hline(y, 0, surface.size - 1, joint)
        if y + 1 < surface.size:
            canvas.hline(y + 1, 0, surface.size - 1, highlight)
        jitter = int((surface.hash.breaker(tag, index, 0) - 0.5) * block * 0.4)
        offset = int(block * stagger * (index % 2)) + jitter
        for x in range(offset % block, surface.size, block):
            for row in range(y + 2, min(y + course, surface.size)):
                canvas.set(x, row, joint)


# ----------------------------------------------------------------------
# neon_transit -- glazed tile, grout, signage. Stained from above, wet
# underfoot, and the dirt lives in the grout where dirt actually lives.
# ----------------------------------------------------------------------

def _neon_wall(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[3])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=0.8)
    # Glazed tile at 0.30 m: a station tile you could name the size of.
    paintkit.panel_grid(canvas, surface, base[0], base[3],
                        pitch_metres=0.30, vertical_pitch_metres=0.30)
    # Individual tiles vary. A tiled wall where every tile matches is a
    # printed tiled wall, and the variation has to be PER TILE rather than
    # per texel or it reads as noise laid over tiles.
    tile = max(3, surface.texels(0.30))
    for ty in range(0, surface.size, tile):
        for tx in range(0, surface.size, tile):
            shade = surface.hash.breaker("tile", tx, ty)
            if shade > 0.72:
                tone, amount = base[2], 0.30
            elif shade < 0.16:
                tone, amount = accent[0], 0.14
            else:
                continue
            for y in range(ty + 1, min(ty + tile, surface.size)):
                for x in range(tx + 1, min(tx + tile, surface.size)):
                    canvas.mix(x, y, tone, amount)
    # The dirt is IN THE GROUT. That is the whole difference between a
    # tiled wall that has been used and one that has been rendered.
    paintkit.speckle(canvas, surface, pal.grime(0),
                     paintkit.near_seams(surface, 0.03),
                     density=0.42, strength=0.55)
    # Stains from above: this is a station, and stations leak.
    for i in range(4):
        x = int(surface.hash.breaker("leak", i, 0) * surface.size)
        paintkit.streak(canvas, surface, x, 0,
                        surface.texels(1.4 + i * 0.35), pal.grime(1),
                        width=2 + i % 2, strength=0.45)
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.30)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.06),
                       strength=0.6)
    return canvas


def _neon_floor(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[0])
    paintkit.tonal_drift(canvas, surface, amount=0.08, cell_metres=1.1)
    # Smaller tiles underfoot than on the wall, which is what a real
    # concourse does -- and it stops floor and wall reading as one surface
    # folded at the skirting.
    paintkit.panel_grid(canvas, surface, pal.grime(0), base[1],
                        pitch_metres=0.20, vertical_pitch_metres=0.20)
    # Wet: broad pools that are DARKER and slightly bluer, not shinier.
    # A specular sheen is not available at this era and a painted highlight
    # is a lie that moves with the camera.
    paintkit.broad_patches(canvas, surface, [pal.grime(0), accent[0]],
                           cell_metres=0.9, density=0.34, strength=0.34)
    paintkit.speckle(canvas, surface, pal.grime(1),
                     paintkit.near_seams(surface, 0.025),
                     density=0.5, strength=0.6)
    return canvas


def _neon_ceiling(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[1])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=0.9)
    # A panelled soffit, not tile: the ceiling of a station is the one
    # surface that was never glazed, and it sits between floor and wall in
    # value so it never reads as a wall lying down (the Batch 001 lesson).
    paintkit.panel_grid(canvas, surface, base[0], base[2],
                        pitch_metres=0.60, vertical_pitch_metres=0.60)
    paintkit.speckle(canvas, surface, pal.grime(0),
                     paintkit.near_seams(surface, 0.05),
                     density=0.20, strength=0.45)
    return canvas


def _neon_trim(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, trim[1])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=1.0)

    def cycle_rows(cv, y0, cycle):
        # The signage band gets a TENTH of the cycle, not a third. Same
        # lesson the concrete kick rail paid for: this trim runs round the
        # whole room, so a generous stripe is the most saturated thing in
        # shot everywhere at once.
        cv.rect(0, y0, surface.size, max(1, cycle // 6), trim[0])
        cv.rect(0, y0 + cycle // 6, surface.size, max(2, cycle // 2), trim[2])
        stripe = y0 + cycle // 6 + max(2, cycle // 2)
        cv.rect(0, stripe, surface.size, max(1, cycle // 10), accent[2])
        cv.hline(stripe - 1, 0, surface.size - 1, trim[0])
        cv.hline(y0 + cycle - 1, 0, surface.size - 1, trim[0])

    _trim_strip(canvas, surface, cycle_rows)
    paintkit.speckle(canvas, surface, pal.grime(0),
                     paintkit.near_edges(surface, 0.05),
                     density=0.18, strength=0.5)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.05),
                       strength=0.8)
    return canvas


def _neon_accent(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, accent[1])
    paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=0.5)
    paintkit.panel_grid(canvas, surface, accent[0], accent[2],
                        pitch_metres=0.40, vertical_pitch_metres=0.40)
    paintkit.speckle(canvas, surface, accent[0],
                     paintkit.near_seams(surface, 0.04),
                     density=0.22, strength=0.5)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.05),
                       strength=0.7)
    return canvas


# ----------------------------------------------------------------------
# gothic_stone -- coursed ashlar and iron banding. Soot, chipped arrises,
# mortar loss. Everything here is subtractive: this theme's history is
# things having been TAKEN from it.
# ----------------------------------------------------------------------

def _gothic_wall(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[2])
    paintkit.tonal_drift(canvas, surface, amount=0.09, cell_metres=0.7)
    # Blocks vary before the joints are cut, because a course of identical
    # blocks is a course nobody quarried.
    paintkit.broad_patches(canvas, surface, [base[1], base[3]],
                           cell_metres=0.45, density=0.40, strength=0.28)
    _coursed(canvas, surface, base[0], base[3], 0.42, 0.86, tag="ashlar")
    # Mortar loss: the joint opens out in places rather than staying a
    # clean line. This is the mark that says the wall is old rather than
    # merely dark.
    joint = surface.texels(0.42)
    for y in range(0, surface.size, joint):
        for x in range(surface.size):
            if surface.hash.breaker("mortar", x, y) > 0.86:
                for d in range(1, 3):
                    canvas.mix(x, min(y + d, surface.size - 1), base[0], 0.7)
    # Chipped arrises: the corners go first, and only the corners.
    paintkit.speckle(canvas, surface, base[3],
                     paintkit.near_seams(surface, 0.04),
                     density=0.16, strength=0.7)
    # Soot from above. Gothic interiors were lit by fire for centuries.
    for i in range(5):
        x = int(surface.hash.breaker("soot", i, 0) * surface.size)
        paintkit.streak(canvas, surface, x, 0,
                        surface.texels(1.8 + i * 0.3), pal.grime(0),
                        width=3, strength=0.40)
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.45)
    return canvas


def _gothic_floor(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[1])
    paintkit.tonal_drift(canvas, surface, amount=0.10, cell_metres=1.3)
    # Flags, larger than the wall's blocks and laid square: a floor is not
    # bonded, it is paved.
    paintkit.panel_grid(canvas, surface, base[0], base[2],
                        pitch_metres=0.90, vertical_pitch_metres=0.90)
    paintkit.broad_patches(canvas, surface, [base[0], base[2]],
                           cell_metres=1.1, density=0.34, strength=0.30)
    paintkit.speckle(canvas, surface, pal.grime(0),
                     paintkit.near_seams(surface, 0.05),
                     density=0.34, strength=0.55)
    return canvas


def _gothic_ceiling(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[0])
    paintkit.tonal_drift(canvas, surface, amount=0.07, cell_metres=1.0)
    _coursed(canvas, surface, pal.grime(0), base[1], 0.55, 1.10, tag="vault")
    # The darkest surface in the room, and the sootiest: heat rises and so
    # does everything it carries.
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.55)
    return canvas


def _gothic_trim(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, trim[1])
    paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=0.9)

    def cycle_rows(cv, y0, cycle):
        # Iron banding: a deep band with a worked edge above and below.
        # No painted stripe -- nothing in this theme was ever painted.
        cv.rect(0, y0, surface.size, max(1, cycle // 8), trim[0])
        cv.rect(0, y0 + cycle // 8, surface.size, max(3, cycle // 2), trim[2])
        cv.rect(0, y0 + cycle // 8 + max(3, cycle // 2), surface.size,
                max(1, cycle // 8), trim[0])
        cv.hline(y0 + cycle - 1, 0, surface.size - 1, pal.grime(0))

    _trim_strip(canvas, surface, cycle_rows)
    # Riveted. The rivets are the theme's only regular rhythm, which is what
    # makes the stone around them read as irregular.
    surface.bolt_pitch = surface.texels(0.22)
    paintkit.bolts(canvas, surface, trim[0], accent[2])
    paintkit.speckle(canvas, surface, accent[0],
                     paintkit.near_edges(surface, 0.06),
                     density=0.24, strength=0.6)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.07),
                       strength=0.9)
    return canvas


def _gothic_accent(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, accent[1])
    paintkit.tonal_drift(canvas, surface, amount=0.08, cell_metres=0.6)
    paintkit.panel_grid(canvas, surface, accent[0], accent[2],
                        pitch_metres=0.55, vertical_pitch_metres=1.1)
    surface.bolt_pitch = surface.texels(0.28)
    paintkit.bolts(canvas, surface, accent[0], accent[2])
    paintkit.speckle(canvas, surface, pal.grime(0),
                     paintkit.near_seams(surface, 0.05),
                     density=0.26, strength=0.55)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.06),
                       strength=0.8)
    return canvas


# ----------------------------------------------------------------------
# temple_ruin -- cut sandstone and brass mechanism. Cracks, root intrusion,
# wind polish and drift. The only theme whose history is still HAPPENING:
# the roots are getting further in.
# ----------------------------------------------------------------------

def _roots(canvas, surface, colour, count, tag="root"):
    """Roots crawling down from the top edge, forking as they go.

    They come from ABOVE, always, because that is where the roof failed.
    A root that started halfway down a wall is a squiggle.
    """
    for i in range(count):
        x = int(surface.hash.breaker(tag, i, 0) * surface.size)
        y = 0
        length = surface.texels(1.6 + surface.hash.breaker(tag, i, 1) * 1.6)
        for step in range(length):
            if y >= surface.size:
                break
            canvas.mix(x % surface.size, y, colour, 0.62)
            canvas.mix((x + 1) % surface.size, y, colour, 0.30)
            drift = surface.hash.breaker(tag, i, step + 2)
            if drift > 0.72:
                x += 1
            elif drift < 0.28:
                x -= 1
            y += 1
            # A fork, occasionally. Two roots from one is what makes it
            # read as growth rather than as a crack.
            if drift > 0.94 and step > 4:
                branch = x
                for j in range(surface.texels(0.5)):
                    branch += 1 if drift > 0.97 else -1
                    if 0 <= branch < surface.size and y + j < surface.size:
                        canvas.mix(branch, y + j, colour, 0.45)


def _temple_wall(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[2])
    paintkit.tonal_drift(canvas, surface, amount=0.08, cell_metres=0.9)
    _coursed(canvas, surface, base[0], base[3], 0.60, 1.20, tag="sandstone")
    # Wind polish: the UPPER part of a ruin wall is scoured pale and the
    # lower part holds drift. Two opposite gradients, which is why this is
    # not one `tonal_drift` call.
    for y in range(surface.size):
        height = 1.0 - (y / float(surface.size))
        if height > 0.55:
            for x in range(surface.size):
                canvas.mix(x, y, base[3], (height - 0.55) * 0.5)
    paintkit.speckle(canvas, surface, base[3],
                     paintkit.near_floor(surface, 0.8),
                     density=0.26, strength=0.5)
    # Cracks follow the courses and then leave them, which is what a crack
    # in laid stone does: it finds the joint, then gives up and crosses.
    for i in range(3):
        x = int(surface.hash.breaker("crack", i, 0) * surface.size)
        paintkit.streak(canvas, surface, x, surface.texels(0.4),
                        surface.texels(2.2), base[0], width=1, strength=0.75)
    _roots(canvas, surface, accent[0], 4)
    paintkit.grime_pool(canvas, surface, pal.grime(1), strength=0.30)
    return canvas


def _temple_floor(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[1])
    paintkit.tonal_drift(canvas, surface, amount=0.09, cell_metres=1.2)
    paintkit.panel_grid(canvas, surface, base[0], base[2],
                        pitch_metres=1.20, vertical_pitch_metres=1.20)
    # Drift: sand collects in the joints first and then spreads out of
    # them. Painted the other way round -- a wash with joints on top -- it
    # reads as a dirty floor rather than a floor with sand on it.
    paintkit.speckle(canvas, surface, base[3],
                     paintkit.near_seams(surface, 0.10),
                     density=0.44, strength=0.55)
    paintkit.broad_patches(canvas, surface, [base[3], base[0]],
                           cell_metres=1.4, density=0.30, strength=0.26)
    return canvas


def _temple_ceiling(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[0])
    paintkit.tonal_drift(canvas, surface, amount=0.08, cell_metres=1.0)
    _coursed(canvas, surface, pal.grime(0), base[1], 0.75, 1.50, tag="lintel")
    _roots(canvas, surface, accent[0], 3, tag="ceilroot")
    paintkit.grime_pool(canvas, surface, pal.grime(0), strength=0.40)
    return canvas


def _temple_trim(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, trim[1])
    paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=0.8)

    def cycle_rows(cv, y0, cycle):
        # A brass band with a bright fillet: the fillet is thin because it
        # is the only clean thing left in the room and it should read as
        # rare rather than as a stripe.
        cv.rect(0, y0, surface.size, max(1, cycle // 8), trim[0])
        cv.rect(0, y0 + cycle // 8, surface.size, max(3, cycle // 2), trim[2])
        fillet = y0 + cycle // 8 + max(3, cycle // 2)
        cv.rect(0, fillet, surface.size, max(1, cycle // 12), base[3])
        cv.hline(y0 + cycle - 1, 0, surface.size - 1, pal.grime(0))

    _trim_strip(canvas, surface, cycle_rows)
    # Brass mechanism: the one MADE thing in a theme of weathered stone,
    # so it gets the regular rhythm and the stone gets none.
    surface.bolt_pitch = surface.texels(0.18)
    paintkit.bolts(canvas, surface, trim[0], trim[2])
    # Verdigris, in the recesses, because that is where water sits.
    paintkit.speckle(canvas, surface, accent[1],
                     paintkit.near_seams(surface, 0.05),
                     density=0.30, strength=0.55)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.06),
                       strength=0.8)
    return canvas


def _temple_accent(canvas, surface, theme):
    base, accent, trim = _ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, accent[1])
    paintkit.tonal_drift(canvas, surface, amount=0.09, cell_metres=0.7)
    paintkit.broad_patches(canvas, surface, [accent[0], accent[2]],
                           cell_metres=0.5, density=0.38, strength=0.32)
    _roots(canvas, surface, accent[0], 3, tag="accroot")
    paintkit.speckle(canvas, surface, base[3],
                     paintkit.near_floor(surface, 0.6),
                     density=0.20, strength=0.45)
    paintkit.edge_wear(canvas, surface, base[0], surface.texels(0.06),
                       strength=0.7)
    return canvas


_TREATMENTS = {
    "concrete_facility": {
        "wall": _concrete_wall, "floor": _concrete_floor,
        "ceiling": _concrete_ceiling,
        "trim": _concrete_trim, "accent": _concrete_accent,
        "wall_ribbed": _concrete_wall_ribbed,
    },
    "rusted_industrial": {
        "wall": _rust_wall, "floor": _rust_floor,
        "ceiling": _rust_floor,
        "trim": _rust_trim, "accent": _rust_accent,
    },
    "void_glitch": {
        "wall": _void_wall, "floor": _void_floor,
        "ceiling": _void_wall,
        "trim": _void_trim, "accent": _void_accent,
    },
    # Built in Batch 012, once Style Lock passed and theme production
    # opened. Each follows the identity §9 of ASSET_INVENTORY.md already
    # recorded for it, rather than one invented here.
    "neon_transit": {
        "wall": _neon_wall, "floor": _neon_floor,
        "ceiling": _neon_ceiling,
        "trim": _neon_trim, "accent": _neon_accent,
    },
    "gothic_stone": {
        "wall": _gothic_wall, "floor": _gothic_floor,
        "ceiling": _gothic_ceiling,
        "trim": _gothic_trim, "accent": _gothic_accent,
    },
    "temple_ruin": {
        "wall": _temple_wall, "floor": _temple_floor,
        "ceiling": _temple_ceiling,
        "trim": _temple_trim, "accent": _temple_accent,
    },
}

#: `ceiling` was added at the Batch 001 review. The room read as uniformly
#: pale because the ceiling borrowed the WALL texture, so three of the four
#: large surfaces in shot sat at the same value. A ceiling is its own role.
ROLES = ("wall", "floor", "ceiling", "trim", "accent")


def surface_for(role, theme, size=ARCH_SIZE, metres=ARCH_METRES):
    """The `Surface` a role is painted against. Structure, before colour."""
    seams = ()
    floor_edge = None
    if role in ("wall", "accent", "wall_ribbed"):
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
    if role not in _TREATMENTS[theme]:
        raise KeyError(
            "materials: theme '%s' has no '%s' treatment. It has: %s"
            % (theme, role, ", ".join(sorted(_TREATMENTS[theme]))))
    surface = surface_for(role, theme, size, metres)
    base = pal.palette()["themes"][theme]["base"]["ramp"][1]
    canvas = paintkit.Canvas(size, base)
    _TREATMENTS[theme][role](canvas, surface, theme)
    return canvas, surface


def roles_for(theme):
    """The roles this theme actually defines, in a stable order."""
    have = _TREATMENTS[theme]
    ordered = [r for r in ROLES if r in have]
    ordered += [r for r in sorted(have) if r not in ordered]
    return tuple(ordered)


def built_themes():
    return tuple(sorted(_TREATMENTS))
