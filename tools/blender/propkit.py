"""Prop surfaces: painted at the prop density, on prop structure.

Architecture is painted in `materials.py` because a wall's structure is the
theme's structure. A prop's structure is its own -- a crate has a lid and
corner irons, a terminal has a screen and a bezel -- so its paint lives
here, and the two never share a treatment function.

Props run at **64 texels/m on a 128px map, covering 2.0 m**, double the
architecture density. `derive_budgets.py` section 2 has the arithmetic: a
1 m crate face at the wall density gets 32 texels across, which cannot hold
a lid seam and a stencil and wear at once, and in 1998 a model's skin was
genuinely sharper than the brush behind it.
"""

from __future__ import annotations

import paintkit
import palette as pal

PROP_DENSITY = pal.budgets()["texel_density"]["prop"]["target"]
PROP_SIZE = 128
PROP_METRES = PROP_SIZE / float(PROP_DENSITY)


def surface(theme, name, kind="prop"):
    return paintkit.Surface(PROP_SIZE, PROP_METRES, kind,
                            floor_edge="bottom",
                            seed="archipepsi/prop/%s/%s" % (theme, name))


def _ramps(theme):
    data = pal.palette()["themes"][theme]
    return (data["base"]["ramp"], data["accent"]["ramp"], data["trim"]["ramp"])


def painted_metal(theme, name, label=None, band=True, wear=0.14):
    """The default prop skin: painted sheet with a stencil and worn corners.

    One treatment covers most of the kit on purpose. A crate, a utility box
    and a machinery housing in a 1998 facility were all the same painted
    steel; giving each its own material would be six asset packs at prop
    scale, which is the same failure the theme rules exist to prevent one
    level up.
    """
    base, accent, trim = _ramps(theme)
    surf = surface(theme, name)
    canvas = paintkit.Canvas(PROP_SIZE, accent[1])
    paintkit.tonal_drift(canvas, surf, amount=0.06, cell_metres=0.5)
    paintkit.broad_patches(canvas, surf, [accent[0], accent[2]],
                           cell_metres=0.28, density=0.22, strength=0.28)
    # Panel divisions at 0.5 m: a prop-scale seam, not a wall-scale one.
    paintkit.panel_grid(canvas, surf, trim[0], accent[2],
                        pitch_metres=0.5, vertical_pitch_metres=0.5)
    surf.seams = tuple(range(0, PROP_SIZE, surf.texels(0.5)))
    surf.bolt_pitch = surf.texels(0.25)
    paintkit.bolts(canvas, surf, trim[0], accent[2], inset=3)
    if band:
        # A painted identification band at a fixed height, which is what
        # makes a row of otherwise-identical boxes read as a row rather than
        # as one box repeated.
        top = surf.texels(0.62)
        height = surf.texels(0.12)
        canvas.rect(0, top, PROP_SIZE, height, base[0])
        canvas.hline(top - 1, 0, PROP_SIZE - 1, accent[2])
        canvas.hline(top + height, 0, PROP_SIZE - 1, trim[0])
    if label:
        width = paintkit.text_width(label)
        paintkit.text(canvas, surf, (PROP_SIZE - width) // 2,
                      surf.texels(0.34), label, base[3])
    paintkit.speckle(canvas, surf, trim[0],
                     paintkit.zone_or(paintkit.near_seams(surf, 0.06),
                                      paintkit.near_edges(surf, 0.10)),
                     density=0.16, strength=0.5)
    paintkit.edge_wear(canvas, surf, base[0], surf.texels(wear), strength=0.9)
    paintkit.grime_pool(canvas, surf, pal.grime(0), strength=0.4)
    return canvas


def bare_metal(theme, name, wear=0.2):
    """Unpainted, oxidised steel: pipes, braces, debris, broken machinery."""
    base, accent, trim = _ramps(theme)
    surf = surface(theme, name)
    canvas = paintkit.Canvas(PROP_SIZE, base[1])
    paintkit.tonal_drift(canvas, surf, amount=0.08, cell_metres=0.4)
    paintkit.broad_patches(canvas, surf, [base[0], accent[0]],
                           cell_metres=0.24, density=0.30, strength=0.35)
    paintkit.speckle(canvas, surf, base[0], lambda x, y: 1.0,
                     density=0.06, strength=0.45)
    paintkit.edge_wear(canvas, surf, accent[0], surf.texels(wear), strength=1.0)
    paintkit.grime_pool(canvas, surf, pal.grime(0), strength=0.55)
    return canvas


def console(theme, name, label="rdy"):
    """A terminal face: dark bezel, a lit screen, a row of indicator marks.

    The screen is the `signal` family, never the theme's accent. A terminal
    is an interactable, and an interactable that speaks in its theme's colour
    is one the player has to re-learn in every theme.
    """
    base, accent, trim = _ramps(theme)
    surf = surface(theme, name)
    canvas = paintkit.Canvas(PROP_SIZE, trim[0])
    paintkit.tonal_drift(canvas, surf, amount=0.05, cell_metres=0.4)
    # Bezel, then screen recess, then the screen itself: three values, so
    # the screen reads as set INTO something rather than stuck on.
    inset = surf.texels(0.10)
    canvas.rect(inset, inset, PROP_SIZE - 2 * inset, PROP_SIZE - 2 * inset,
                trim[1])
    recess = surf.texels(0.16)
    canvas.rect(recess, recess, PROP_SIZE - 2 * recess, PROP_SIZE - 2 * recess,
                pal.universal("dead", 0))
    screen = surf.texels(0.20)
    canvas.rect(screen, screen, PROP_SIZE - 2 * screen, PROP_SIZE - 2 * screen,
                pal.universal("signal", 0))
    # Scanlines, drawn as whole texel rows because that is what a CRT is.
    for y in range(screen, PROP_SIZE - screen, 2):
        canvas.hline(y, screen, PROP_SIZE - screen - 1,
                     pal.universal("signal", 1))
    # Readout blocks: a machine saying something, in a language nobody has
    # to read. Rows are placed on a grid, never scattered.
    row_h = surf.texels(0.07)
    for i in range(5):
        y = screen + surf.texels(0.06) + i * row_h * 2
        if y + row_h >= PROP_SIZE - screen:
            break
        width = int((0.3 + 0.6 * surf.hash.breaker("row", 0, i))
                    * (PROP_SIZE - 2 * screen - surf.texels(0.12)))
        canvas.rect(screen + surf.texels(0.06), y, width, row_h,
                    pal.universal("signal", 3))
    width = paintkit.text_width(label)
    paintkit.text(canvas, surf, PROP_SIZE - screen - width - 3,
                  PROP_SIZE - screen - 8, label, pal.universal("send", 3))
    paintkit.speckle(canvas, surf, trim[0], paintkit.near_edges(surf, 0.10),
                     density=0.14, strength=0.5)
    paintkit.edge_wear(canvas, surf, base[0], surf.texels(0.08), strength=0.7)
    return canvas


def placard(theme, name, label="warn"):
    """A wall sign: hazard border, one short word, universal colours only."""
    base, accent, trim = _ramps(theme)
    surf = surface(theme, name)
    canvas = paintkit.Canvas(PROP_SIZE, pal.universal("hazard", 3))
    border = surf.texels(0.08)
    paintkit.hazard_stripes(canvas, 0, 0, PROP_SIZE, border,
                            pal.universal("hazard", 0),
                            pal.universal("hazard", 3),
                            pitch=max(3, surf.texels(0.06)))
    paintkit.hazard_stripes(canvas, 0, PROP_SIZE - border, PROP_SIZE, border,
                            pal.universal("hazard", 0),
                            pal.universal("hazard", 3),
                            pitch=max(3, surf.texels(0.06)))
    canvas.rect(0, border, PROP_SIZE, PROP_SIZE - 2 * border,
                pal.universal("hazard", 2))
    width = paintkit.text_width(label)
    paintkit.text(canvas, surf, (PROP_SIZE - width) // 2, PROP_SIZE // 2 - 3,
                  label, pal.universal("hazard", 0))
    paintkit.speckle(canvas, surf, trim[0], paintkit.near_edges(surf, 0.06),
                     density=0.18, strength=0.55)
    paintkit.edge_wear(canvas, surf, trim[0], surf.texels(0.06), strength=0.8)
    paintkit.grime_pool(canvas, surf, pal.grime(0), strength=0.35)
    return canvas
