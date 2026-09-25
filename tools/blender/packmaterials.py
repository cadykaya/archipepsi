"""Track D -- the pixels that make a GAME PACK a different place.

D-11 gave packs a namespace: `pack_textures`, keyed
`<pack>/<theme>/<role>`, tried before the family chain and yielding any
role it does not ship. This module is the art that goes in it.

## Why this exists, in one negative result

T01 (Ocarina of Time, Forest Temple) and T05 (Kingdom Hearts 2, Twilight
Town) were both built on the `temple_ruin` family, deliberately, to find
out whether geometry alone could carry a pack's identity. It cannot:

> The geometry says "boarded-up shopfront". The pixels say "overgrown
> temple". The pixels win.

So the two packs get their own pixels for the roles that carry the
difference, and keep the family for everything else. A partial pack is
legal by the contract and is the right shape here: nothing is gained by
repainting a ceiling both places share.

## The difference is HISTORY, not hue

Both packs keep `temple_ruin`'s ramps. They are the right colours for
both -- warm sandstone, moss green, timber brown -- and inventing a
palette per pack would put the game's colour discipline in the hands of
whichever pack was authored last.

What separates them is what has been happening to the place:

* **forest_temple** is LOSING. Water gets in, moss climbs from the
  floor, roots come through the roof, joints open. Every mark is
  something the building did not choose.
* **twilight_town** is MAINTAINED. Plaster is flat because someone
  flattened it, timber framing is square because someone squared it,
  the brick base is swept. Every mark is somebody's work.

That reads at 128 px in a way a hue shift never does.
"""

import materials as mat
import paintkit
import palette as pal

#: The two packs the owner approved as the first `pack_textures` pair.
#: Both sit on `temple_ruin`; the family stays the backstop for every
#: role neither of them ships.
FAMILY = "temple_ruin"

#: Pack ids must satisfy Production's `^[a-z0-9_]{1,24}$` and must not
#: be one of the six house family names. Checked by the gate, not here,
#: so that the gate is the thing that has to be right.
PACKS = ("forest_temple", "twilight_town")


# ----------------------------------------------------------------------
# forest_temple -- the temple is losing
# ----------------------------------------------------------------------

def _moss_from_below(canvas, surface, colour, reach_metres, tag):
    """Moss climbing the wall from the floor.

    The family's temple wall is scoured PALE at the top by wind. This is
    the opposite gradient and the opposite story: water sits at the
    bottom, so growth starts there and runs out of height. A moss that
    began halfway up a wall is a stain.
    """
    reach = surface.texels(reach_metres)
    for x in range(surface.size):
        # A ragged top edge. A straight one reads as a painted dado.
        lift = surface.hash.breaker(tag, x, 0)
        top = surface.size - int(reach * (0.45 + lift * 0.55))
        for y in range(top, surface.size):
            depth = (y - top) / float(max(1, surface.size - top))
            if surface.hash.breaker(tag, x, y) < 0.25 + depth * 0.55:
                canvas.mix(x, y, colour, 0.25 + depth * 0.45)


def _temple_pack_wall(canvas, surface, theme):
    base, accent, trim = mat.ramps(theme)
    # A step DOWN the ramp from the family's wall, which sits at
    # base[2]. The family is a ruin in daylight; this is the inside of
    # one, where the roof that failed is still mostly overhead. Without
    # this the pack wall is a brighter cousin of the family wall and the
    # row earns nothing -- the family was authored as "temple ruin" and
    # T01 is a temple, so the two start closer than any other pair will.
    canvas.rect(0, 0, surface.size, surface.size, base[1])
    paintkit.tonal_drift(canvas, surface, amount=0.11, cell_metres=1.1)
    # Bigger blocks than the family's: a temple is built of what had to
    # be dragged there, and the scale is half the reason it reads as a
    # temple rather than a wall.
    mat.coursed(canvas, surface, base[0], base[2], 0.95, 1.80,
                tag="templeblock")
    # Water comes down from every joint, because the roof is gone.
    for i in range(7):
        x = int(surface.hash.breaker("weep", i, 0) * surface.size)
        start = surface.texels(0.95 * (1 + i % 3))
        paintkit.streak(canvas, surface, x, start,
                        surface.texels(1.4), trim[0], width=2, strength=0.42)
    _moss_from_below(canvas, surface, accent[0], 2.1, "wallmoss")
    mat.roots(canvas, surface, accent[0], 6, tag="packroot")
    paintkit.speckle(canvas, surface, accent[1],
                     paintkit.near_seams(surface, 0.12),
                     density=0.18, strength=0.45)
    paintkit.grime_pool(canvas, surface, pal.grime(1), strength=0.38)
    return canvas


def _temple_pack_floor(canvas, surface, theme):
    base, accent, trim = mat.ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, base[1])
    paintkit.tonal_drift(canvas, surface, amount=0.10, cell_metres=1.3)
    # Flagstones, and moss in every joint rather than on every face: the
    # floor is walked on, so growth survives only where a foot does not
    # land.
    mat.coursed(canvas, surface, base[0], base[2], 1.30, 1.30,
                stagger=0.0, tag="flag")
    paintkit.speckle(canvas, surface, accent[0],
                     paintkit.near_seams(surface, 0.14),
                     density=0.42, strength=0.55)
    # The path somebody wore, down the middle, polished paler. It is the
    # one thing on this floor that a person made.
    mid = surface.size // 2
    half = surface.texels(0.7)
    for y in range(surface.size):
        for x in range(mid - half, mid + half):
            fade = 1.0 - abs(x - mid) / float(max(1, half))
            canvas.mix(x % surface.size, y, base[3], 0.20 * fade)
    paintkit.grime_pool(canvas, surface, pal.grime(1), strength=0.30)
    return canvas


def _temple_pack_accent(canvas, surface, theme):
    """Brass gone green. The mechanism is the only worked metal here."""
    base, accent, trim = mat.ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, trim[1])
    paintkit.tonal_drift(canvas, surface, amount=0.07, cell_metres=0.6)
    paintkit.panel_grid(canvas, surface, trim[0], trim[2], 1.0)
    paintkit.bolts(canvas, surface, trim[0], trim[2], inset=3)
    # Verdigris runs DOWN from the fixings, because that is where the
    # water finds the copper.
    for i in range(9):
        x = int(surface.hash.breaker("patina", i, 0) * surface.size)
        y = int(surface.hash.breaker("patina", i, 1) * surface.size)
        paintkit.streak(canvas, surface, x, y, surface.texels(0.8),
                        accent[1], width=2, strength=0.5)
    paintkit.speckle(canvas, surface, accent[2],
                     paintkit.near_edges(surface, 0.18),
                     density=0.20, strength=0.40)
    return canvas


# ----------------------------------------------------------------------
# twilight_town -- somebody maintains this
# ----------------------------------------------------------------------

def _timber_frame(canvas, surface, dark, light):
    """Posts, a rail and one diagonal brace, in timber.

    The brace is the whole tell. Posts and rails alone read as a panel
    grid; a diagonal reads as carpentry, because nothing industrial
    braces a wall that way.
    """
    width = max(2, surface.texels(0.16))
    for at in (0.14, 0.52, 0.88):
        x = int(surface.size * at)
        canvas.rect(x, 0, width, surface.size, dark)
        canvas.rect(x, 0, 1, surface.size, light)
    rail = int(surface.size * 0.42)
    canvas.rect(0, rail, surface.size, width, dark)
    canvas.rect(0, rail, surface.size, 1, light)
    # One brace, corner to corner of the left bay.
    x0, y0 = int(surface.size * 0.16), rail
    x1, y1 = int(surface.size * 0.52), int(surface.size * 0.06)
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for s in range(steps):
        x = x0 + (x1 - x0) * s // steps
        y = y0 + (y1 - y0) * s // steps
        for d in range(width):
            canvas.set(min(x + d, surface.size - 1), y, dark)
        canvas.set(x, y, light)


def _town_wall(canvas, surface, theme):
    base, accent, trim = mat.ramps(theme)
    # Plaster: FLAT. The temptation is to give it the same tonal life as
    # stone, and that is exactly what makes a rendered wall read as rock.
    canvas.rect(0, 0, surface.size, surface.size, base[3])
    paintkit.tonal_drift(canvas, surface, amount=0.04, cell_metres=1.6)
    # A brick plinth, where carts and boots hit it.
    plinth = surface.texels(0.75)
    canvas.rect(0, surface.size - plinth, surface.size, plinth, trim[1])
    # The same Surface, a different bond tag. A second Surface would
    # have given the brick its own hash stream, which sounds tidier and
    # buys nothing: the tag already seeds the stagger jitter, and one
    # Surface means the brick and the plaster agree about texel scale.
    mat.coursed(canvas, surface, trim[0], trim[2], 0.22, 0.45, tag="brick")
    # ...but only over the plinth. `coursed` paints the whole tile, so
    # the plaster above is restored and the line between them is a hard
    # edge, which is what a damp course looks like.
    top = surface.size - plinth
    for y in range(top):
        for x in range(surface.size):
            canvas.set(x, y, base[3])
    paintkit.tonal_drift(canvas, surface, amount=0.03, cell_metres=1.2)
    _timber_frame(canvas, surface, trim[0], trim[2])
    # Weathering under the rail only -- rain runs off the timber and hits
    # the plaster in one line. Not everywhere: everywhere is grime, and
    # grime is what the other pack has.
    rail = int(surface.size * 0.42) + max(2, surface.texels(0.16))
    for x in range(surface.size):
        if surface.hash.breaker("dribble", x, 0) > 0.62:
            paintkit.streak(canvas, surface, x, rail,
                            surface.texels(0.45), trim[0], width=1,
                            strength=0.28)
    return canvas


def _town_floor(canvas, surface, theme):
    base, accent, trim = mat.ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, trim[1])
    paintkit.tonal_drift(canvas, surface, amount=0.06, cell_metres=0.8)
    # Setts: small, staggered, regular. A town square is paved by
    # somebody who was paid by the square metre.
    mat.coursed(canvas, surface, trim[0], trim[2], 0.26, 0.26,
                stagger=0.5, tag="sett")
    # A gutter, off centre, because drainage follows the fall of the
    # street and not the middle of the texture.
    gx = int(surface.size * 0.30)
    half = max(1, surface.texels(0.10))
    for y in range(surface.size):
        for d in range(-half, half + 1):
            canvas.mix((gx + d) % surface.size, y, trim[0],
                       0.55 if abs(d) < half else 0.25)
    paintkit.speckle(canvas, surface, base[2],
                     paintkit.near_edges(surface, 0.20),
                     density=0.10, strength=0.30)
    return canvas


def _town_accent(canvas, surface, theme):
    """A painted shop board. Signs are the town's whole visual language.

    OWNER RULING, 2026-09-25: *"Adjust T05's sign accent away from the
    family's look. The pack needs to read as its own place."* The first
    cut filled the board with the family's own `accent` green, so on a
    small accent surface the two read alike -- which is the finding I
    raised about it myself.

    The green is now a single keyline. The board is timber, the field
    is the base ramp's cream, and the thing that makes it a SHOP is
    stencilled lettering, which a temple does not have. `signal`,
    `hazard` and `identity` stay reserved for what they mean, per the
    same ruling.
    """
    base, accent, trim = mat.ramps(theme)
    canvas.rect(0, 0, surface.size, surface.size, trim[1])
    paintkit.tonal_drift(canvas, surface, amount=0.05, cell_metres=0.5)
    # Boards, not a slab: horizontal planks with a dark line between.
    plank = max(3, surface.texels(0.42))
    for y in range(0, surface.size, plank):
        canvas.hline(y, 0, surface.size - 1, trim[0])
        if y + 1 < surface.size:
            canvas.hline(y + 1, 0, surface.size - 1, trim[2])

    # The painted field, and the green reduced to the keyline around it.
    inset = surface.texels(0.30)
    span = surface.size - inset * 2
    canvas.rect(inset, inset, span, span, base[3])
    canvas.outline(inset, inset, span, span, accent[1])
    canvas.outline(inset + 1, inset + 1, span - 2, span - 2, base[2])

    # The lettering. A temple has no signage; a shopfront is nothing
    # else. Generic on purpose -- this is a pack's own vocabulary, not a
    # quotation of anybody's.
    word = "MARKET"
    width = paintkit.text_width(word)
    paintkit.text(canvas, surface,
                  (surface.size - width) // 2, surface.size // 2 - 3,
                  word, trim[0])

    # Paint fails at the corners first, where the board was nailed.
    paintkit.edge_wear(canvas, surface, trim[2], surface.texels(0.18),
                       strength=0.45)
    return canvas


_TREATMENTS = {
    "forest_temple": {
        "wall": _temple_pack_wall,
        "floor": _temple_pack_floor,
        "accent": _temple_pack_accent,
    },
    "twilight_town": {
        "wall": _town_wall,
        "floor": _town_floor,
        "accent": _town_accent,
    },
}


def packs():
    return tuple(sorted(_TREATMENTS))


def roles_for(pack):
    return tuple(sorted(_TREATMENTS[pack]))


def paint(pack, role, theme=FAMILY, size=mat.ARCH_SIZE,
          metres=mat.ARCH_METRES):
    """A painted `Canvas` for one pack/theme/role.

    The `Surface` comes from `materials.surface_for`, so a pack's
    structure -- its course pitch, its floor edge, its seam positions --
    is the family's. A pack that invented its own course pitch would
    stop tiling against the family's walls at the join, and the join is
    exactly where a pack meets the rest of the game.
    """
    if pack not in _TREATMENTS:
        raise KeyError("packmaterials: no pack '%s'. Have: %s"
                       % (pack, ", ".join(packs())))
    if role not in _TREATMENTS[pack]:
        raise KeyError("packmaterials: pack '%s' ships no '%s'. It ships: %s"
                       % (pack, role, ", ".join(roles_for(pack))))
    surface = mat.surface_for(role, theme, size, metres)
    base = pal.palette()["themes"][theme]["base"]["ramp"][1]
    canvas = paintkit.Canvas(size, base)
    _TREATMENTS[pack][role](canvas, surface, theme)
    return canvas, surface
