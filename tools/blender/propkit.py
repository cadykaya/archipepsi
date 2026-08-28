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


# ----------------------------------------------------------------------
# hero tier -- the objects AUTHORED_CONTENT.md calls identity
# ----------------------------------------------------------------------

HERO_DENSITY = pal.budgets()["texel_density"]["hero"]["target"]
HERO_SIZE = 128
HERO_METRES = HERO_SIZE / float(HERO_DENSITY)


def hero_surface(name):
    return paintkit.Surface(HERO_SIZE, HERO_METRES, "prop",
                            floor_edge="bottom",
                            seed="archipepsi/hero/%s" % name)


def hero_shell(theme, name, family, label=None, lit_band=True):
    """The shared skin every hero object wears, whatever its silhouette.

    `family` is a UNIVERSAL family name -- `signal` for a Check, `identity`
    for Epsilon, `send` for a transmission surface. Never a theme colour:
    these are the objects the player learns once and must recognise in all
    six themes, and a theme-tinted Check is a Check that has to be re-learned
    in temple_ruin.

    Three concepts of one object share this function on purpose. If the
    three Check concepts differed in paint as well as in silhouette, the
    review would be asking two questions at once and could answer neither.
    """
    base, accent, trim = _ramps(theme)
    surf = hero_surface(name)
    canvas = paintkit.Canvas(HERO_SIZE, trim[1])
    paintkit.tonal_drift(canvas, surf, amount=0.05, cell_metres=0.4)
    paintkit.broad_patches(canvas, surf, [trim[0], trim[2]],
                           cell_metres=0.22, density=0.20, strength=0.30)
    # Heavy machined casing: deep panel divisions and real bolts. A hero
    # object has to survive being looked at from 1 m as well as from 40.
    paintkit.panel_grid(canvas, surf, trim[0], trim[2],
                        pitch_metres=0.34, vertical_pitch_metres=0.34)
    surf.seams = tuple(range(0, HERO_SIZE, surf.texels(0.34)))
    surf.bolt_pitch = surf.texels(0.17)
    paintkit.bolts(canvas, surf, trim[0], trim[2], inset=3)
    if lit_band:
        # THE dominant cue. One band, full width, in the universal family --
        # everything else on the object is subordinate to it, and nothing
        # else is allowed to be this bright. If two things compete for the
        # eye at 35 px, neither wins.
        top = surf.texels(0.30)
        height = max(3, surf.texels(0.10))
        canvas.rect(0, top, HERO_SIZE, height, pal.universal(family, 3))
        canvas.hline(top - 1, 0, HERO_SIZE - 1, pal.universal("dead", 0))
        canvas.hline(top + height, 0, HERO_SIZE - 1, pal.universal("dead", 0))
        # A darker echo of the band below it: the value sandwich the palette
        # check exists to guarantee. Whichever way a theme's wall goes, one
        # half of the pair separates from it.
        canvas.rect(0, top + height + 1, HERO_SIZE, max(2, height // 2),
                    pal.universal(family, 0))
    if label:
        width = paintkit.text_width(label)
        paintkit.text(canvas, surf, (HERO_SIZE - width) // 2,
                      surf.texels(0.62), label, pal.universal(family, 2))
    paintkit.speckle(canvas, surf, trim[0],
                     paintkit.zone_or(paintkit.near_seams(surf, 0.04),
                                      paintkit.near_edges(surf, 0.06)),
                     density=0.14, strength=0.5)
    paintkit.edge_wear(canvas, surf, base[0], surf.texels(0.06), strength=0.8)
    paintkit.grime_pool(canvas, surf, pal.grime(0), strength=0.35)
    return canvas


def hero_face(theme, name, family, label):
    """The interaction face: what the player aims at and presses.

    Deliberately a different texture from the shell. AUTHORED_CONTENT.md
    requires that "can I use this?" is never a guess, and the cheapest
    honest answer is that the usable part of an object does not look like
    the rest of it.
    """
    base, accent, trim = _ramps(theme)
    surf = hero_surface(name + "_face")
    canvas = paintkit.Canvas(HERO_SIZE, pal.universal("dead", 0))
    inset = surf.texels(0.06)
    canvas.rect(inset, inset, HERO_SIZE - 2 * inset, HERO_SIZE - 2 * inset,
                pal.universal(family, 0))
    core = surf.texels(0.10)
    canvas.rect(core, core, HERO_SIZE - 2 * core, HERO_SIZE - 2 * core,
                pal.universal(family, 2))
    # Concentric rings, snapped to texels. A target, drawn the way a 1998
    # texture drew a target.
    for i in range(3):
        ring = core + surf.texels(0.05) * (i + 1)
        canvas.outline(ring, ring, HERO_SIZE - 2 * ring, HERO_SIZE - 2 * ring,
                       pal.universal(family, 3 if i % 2 else 0))
    width = paintkit.text_width(label)
    paintkit.text(canvas, surf, (HERO_SIZE - width) // 2, HERO_SIZE // 2 - 3,
                  label, pal.universal(family, 0))
    paintkit.speckle(canvas, surf, trim[0], paintkit.near_edges(surf, 0.05),
                     density=0.16, strength=0.5)
    return canvas


# ----------------------------------------------------------------------
# enemies
# ----------------------------------------------------------------------

def enemy_skin(theme, name, marking="hazard"):
    """An enemy's skin, and the one rule that decides it.

    > **An enemy never wears its room's colours.**

    The first enemy pass painted all three melee concepts with
    `painted_metal`, which builds from the THEME accent -- so in
    concrete_facility they came out institutional steel blue, the same
    family as the wall panels and the doorway trim behind them. At 18 m and
    46 px that is camouflage. `ENEMY_AGGRO_RADIUS` is where the player has
    to see one, and a figure sharing a value and a hue with the architecture
    is a figure the player finds by being hit.

    So enemies are built from the shared `grime` family, which every theme
    also uses for dirt, plus the theme's DARKEST base step. That does two
    things at once: it sits below every theme's wall in value, and it makes
    an enemy read as something that came out of the building's underside
    rather than as part of its finish. The only saturated colour on the body
    is the marking family, and there is very little of it.
    """
    base, accent, trim = _ramps(theme)
    surf = surface(theme, name)
    canvas = paintkit.Canvas(PROP_SIZE, pal.grime(1))
    paintkit.tonal_drift(canvas, surf, amount=0.08, cell_metres=0.30)
    paintkit.broad_patches(canvas, surf, [pal.grime(0), pal.grime(2)],
                           cell_metres=0.18, density=0.32, strength=0.38)
    # Plating: tighter than a prop's, because an enemy is a small object seen
    # close during a fight and far during the approach.
    paintkit.panel_grid(canvas, surf, pal.grime(0), base[0],
                        pitch_metres=0.22, vertical_pitch_metres=0.22)
    surf.seams = tuple(range(0, PROP_SIZE, surf.texels(0.22)))
    surf.bolt_pitch = surf.texels(0.11)
    paintkit.bolts(canvas, surf, pal.grime(0), base[1], inset=2)
    # ONE marking band, narrow. Enough to say "hostile" at close range and
    # not enough to compete with the eye at long range.
    top = surf.texels(0.46)
    height = max(2, surf.texels(0.045))
    canvas.rect(0, top, PROP_SIZE, height, pal.universal(marking, 1))
    canvas.hline(top - 1, 0, PROP_SIZE - 1, pal.grime(0))
    canvas.hline(top + height, 0, PROP_SIZE - 1, pal.grime(0))
    paintkit.speckle(canvas, surf, pal.grime(0),
                     paintkit.zone_or(paintkit.near_seams(surf, 0.03),
                                      paintkit.near_edges(surf, 0.05)),
                     density=0.18, strength=0.55)
    # Wear reaches the LIGHT step here rather than the dark one: a scraped
    # edge on a dark body brightens. Doing it the other way round made the
    # figure lose its outline entirely.
    paintkit.edge_wear(canvas, surf, base[1], surf.texels(0.05), strength=0.9)
    return canvas
