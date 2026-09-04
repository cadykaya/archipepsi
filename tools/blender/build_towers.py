"""Batch 018 -- room shells, the tower family.

    .tools/blender/blender -b --python tools/blender/build_towers.py

Fourth of §7's six families. A tower is a 12 m square shaft climbed from
the floor to a deck at the top of the back wall, and `TowerChamber` gives
art exactly one number: `floors`, 2 to 5. Everything else -- the side, the
3.0 m floor spacing, the central column, where the exit is carved -- is
`tower()`'s, and the three shells here keep all of it.

## The guarantee that cannot be broken

> Each platform rises `step_rise` <= MAX_VERTICAL_STEP, so the mandatory
> route needs only base jumping -- the template's guarantee.

`routecheck` enforces that, the same module the platform paths use, so the
two families cannot drift apart on what a legal climb is. Towers pass
`require_gap=False`: `tower()` spaces 2.6 m platforms 2.4 m apart, so its
own spiral OVERLAPS and the mandatory climb is very nearly a staircase.
Failing a shell for being *easier* than a jump would be inventing a rule
the engine does not have.

## What one number buys

`floors` moves `total_rise` between 6 and 15 m inside a 12 m square, which
is the whole range from a room with a gallery to a genuine shaft. So the
three shells sit at the bottom, middle and top of it -- and each answers
the climb differently, because a 6 m rise and a 15 m rise are not the same
problem at different scales.

| Shell | Floors | Rise | The climb is |
| --- | --- | --- | --- |
| `shell_tower_collapsed` | 2 | 6 m | two storeys of floor slab that fell in. You climb over the wreckage of the building, and each half-floor is somewhere a fight can stand |
| `shell_tower_spiral` | 3 | 9 m | the canonical square spiral, built as architecture: cantilevered slabs on brackets off the wall. A stairwell whose stairs are gone |
| `shell_tower_gantry` | 5 | 15 m | maintenance access up the core: full landings every 3.0 m -- `tower()`'s own floor spacing -- joined by short flights. The tall one, and the only one where the top is out of sight from the bottom |

## What all three keep

The **central column**. `tower()` builds a 2.2 m square core and says why:
it "blocks straight-line ranged fire across it". That is a gameplay
property, not decoration, so every shell here has one and they differ in
how it is dressed rather than in whether it exists.

The **exit at the summit**, carved in the back wall at `top_y`, with a top
deck across the back and a bridge strip out through it. A tower that exited
at grade would be a room.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402
import roomcollision
import traversallaw  # noqa: E402
import roomcontract
import routecheck  # noqa: E402

THEME = "concrete_facility"
OUT = "batch018/shells"

DIM = common.DIM
WALL = DIM["wall_thickness"]
DOOR_W = DIM["door_width"]
DOOR_H = DIM["door_height"]
STEP = DIM["max_vertical_step"]              # 1.00
SIDE = DIM["tower_side"]                     # 12.0
PER_FLOOR = DIM["tower_per_floor"]           # 3.0
F_MIN = DIM["tower_floors_min"]              # 2
F_MAX = DIM["tower_floors_max"]              # 5
#: The route starts on the WHOLE ground floor, not in the doorway. A tower's
#: first platform is reached by walking under it and stepping up; measuring
#: from the door instead put a false 1.93 m jump at the entrance of every
#: shell in this batch, against a 2.00 m bound -- a number that would have
#: read as "nearly illegal" for a step the player never has to make.
_GROUND = ((0.0, -DIM["tower_side"] / 2.0),
           (DIM["tower_side"], DIM["tower_side"]))

CORE = 2.2                                   # tower()'s central column
PLAT = 2.6                                   # tower()'s spiral platform

_IMAGES = {}


#: Corrections Art CANNOT derive, because the evidence Art has cannot
#: see them. Each one is a measurement Production made with the
#: authority, recorded here with its citation rather than guessed.
#:
#: `platform_8_to_deck` is the whole reason this table exists.
#: `traversallaw.reclassify` PROVES that crossing walkable -- there is
#: floor at 8.00 between two decks at 9.00, a metre down and a metre
#: back up, both inside `MAX_VERTICAL_STEP` -- and it is wrong, because
#: the box evidence is support-only and a player's BODY does not fit in
#: a 0.4 m slot. That is Production's S6 "pinch" case exactly:
#: `ShellValidator` floods it and `RoomAudit`'s capsule does not.
#: Production probed it at `b37fe07` and reported the void; the span is
#: 1.75 m against a 2.60 m reach, so it is an ordinary hop.
#:
#: A mirror that is honestly weaker than the authority must SAY where it
#: is weaker instead of quietly overruling it. Deriving this one would
#: mean deriving the wrong answer.
MEASURED_BY_PRODUCTION = {
    "platform_8_to_deck": (
        "gap",
        "Production b37fe07 probed a real void between the two decks; "
        "the support-only box evidence Art has cannot see the pinch"),
}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("tower_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, name, role):
    """Texture a part, and record what that role means for the player.

    The role argument already decides the treatment; `roomcollision` reads
    the same argument to decide whether the piece is structure the player
    stands on and stops at, or trim they only look at. One statement, made
    once, at the point where the part is placed.
    """
    common.assign(obj, common.make_textured_material(
        "%s_%s" % (name, role), _image(role), roughness=pal.roughness(THEME)))
    return roomcollision.paint_role(obj, role)


def _shaft(name, height, summit):
    """Floor, four walls, no roof, a door in at grade and one out at the top.

    `_perimeter(root, side, side, shaft_height, theme, true, true, summit)`
    -- the exit gap starts at `summit`, because the tower is climbed and its
    way out is at the top of the back wall.
    """
    mid = -SIDE / 2.0
    parts = [_paint(brushkit.block("%s_floor" % name, (SIDE, SIDE, 0.50),
                                   (0.0, mid, -0.25)), name, "floor")]
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "%s_wall_%d" % (name, int(side)), (WALL, SIDE, height),
            (side * (SIDE + WALL) / 2.0, mid, height / 2.0)), name, "wall"))
    jamb = (SIDE - DOOR_W) / 2.0
    # Entrance wall: a door at grade.
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "%s_in_%d" % (name, int(side)), (jamb, WALL, height),
            (side * (DOOR_W + jamb) / 2.0, WALL / 2.0, height / 2.0)),
            name, "wall"))
    parts.append(_paint(brushkit.block(
        "%s_in_lintel" % name, (DOOR_W, WALL, height - DOOR_H),
        (0.0, WALL / 2.0, DOOR_H + (height - DOOR_H) / 2.0)), name, "wall"))
    # Back wall: the door starts at the summit, so the sill is a solid
    # panel from the floor all the way up to the deck.
    back = -SIDE - WALL / 2.0
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "%s_out_%d" % (name, int(side)), (jamb, WALL, height),
            (side * (DOOR_W + jamb) / 2.0, back, height / 2.0)),
            name, "wall"))
    parts.append(_paint(brushkit.block(
        "%s_out_sill" % name, (DOOR_W, WALL, summit),
        (0.0, back, summit / 2.0), ), name, "wall"))
    top = summit + DOOR_H
    if height > top:
        parts.append(_paint(brushkit.block(
            "%s_out_lintel" % name, (DOOR_W, WALL, height - top),
            (0.0, back, top + (height - top) / 2.0)), name, "wall"))
    parts.append(_paint(brushkit.block(
        "%s_out_head" % name, (DOOR_W + 0.6, 0.24, 0.30),
        (0.0, back, top + 0.15)), name, "trim"))
    return parts


def _core(name, rise, treatment):
    """`tower()`'s central column, which blocks fire across the shaft.

    Not optional and not decoration -- the engine says what it is for. The
    three shells differ in how it is dressed, never in whether it is there.
    """
    h = rise + 2.0
    mid = -SIDE / 2.0
    parts = [_paint(brushkit.block("%s_core" % name, (CORE, CORE, h),
                                   (0.0, mid, h / 2.0 - 0.5)), name, "wall")]
    if treatment == "banded":
        for i in range(int(rise // PER_FLOOR) + 1):
            z = PER_FLOOR * i + 0.4
            parts.append(_paint(brushkit.block(
                "%s_coreband_%d" % (name, i), (CORE + 0.30, CORE + 0.30, 0.26),
                (0.0, mid, z)), name, "trim"))
    elif treatment == "capital":
        for z, flare in ((0.15, 0.40), (h - 0.65, 0.30)):
            parts.append(_paint(brushkit.block(
                "%s_corecap_%.0f" % (name, z * 10),
                (CORE + flare, CORE + flare, 0.30), (0.0, mid, z)),
                name, "trim"))
    elif treatment == "riven":
        # A column the collapse took a bite out of, on one side only. Not
        # symmetric, because nothing that fell down is.
        for i, (dz, dx) in enumerate(((1.6, 0.5), (3.4, 0.8), (4.9, 0.35))):
            parts.append(_paint(brushkit.block(
                "%s_corebite_%d" % (name, i), (dx, CORE * 0.7, 0.5),
                (CORE / 2.0 - dx / 2.0 + 0.12, mid + 0.3, dz)), name, "trim"))
    return parts


#: The deck's depth and thickness, named because the well arithmetic
#: below needs both and a literal 4.0 in three places is how they drift.
DECK_DEPTH = 4.0
DECK_THICK = 0.50


def _deck_well(stones, heights, rise, margin=0.4):
    """The x-band the deck must NOT roof, or None.

    THE DEFECT THIS EXISTS TO PREVENT, measured by Production at
    `1648fa9`: `shell_tower_collapsed`'s last two rubble rungs and
    `shell_tower_spiral`'s `platform_6` each offered NOWHERE a player
    could stand, all three for one reason -- the deck was directly over
    them. A rung under a deck has `rise - DECK_THICK - h` metres of
    headroom and no more, so any rung above `rise - DECK_THICK -
    HEADROOM` is crushed by a slab 0.5 m thick.

    The fix is not to move the climb. The spiral's helix is the ENGINE's
    -- `inset`, `margin` and `spacing` are `tower()`'s own numbers so an
    authored spiral climbs where a procedural one does -- and the
    collapsed tower's alternating half-floors are what that shell IS. It
    is the deck that is in the wrong place, and a deck that stops short
    of the column the climb comes up is what both a stairwell opening
    and a collapsed floor actually look like.

    So: find the rungs the deck would roof, and cut the deck out of
    their x-band. Derived from `stones` and `heights` -- the same two
    lists that become the Surfaces -- rather than named per shell, so a
    ninth tower gets the same treatment without being told.
    """
    crushed = rise - DECK_THICK - roomcollision.HEADROOM
    lo, hi = None, None
    for (centre, extent), h in zip(stones, heights):
        if h <= crushed or h >= rise:
            continue
        y0, y1 = centre[1] - extent[1] / 2.0, centre[1] + extent[1] / 2.0
        if y1 <= -SIDE or y0 >= -SIDE + DECK_DEPTH:
            continue                      # not under the deck's footprint
        x0, x1 = centre[0] - extent[0] / 2.0, centre[0] + extent[0] / 2.0
        lo = x0 if lo is None else min(lo, x0)
        hi = x1 if hi is None else max(hi, x1)
    if lo is None:
        return None
    lo, hi = lo - margin, hi + margin
    # A sliver of deck narrower than a player is not a deck. When the
    # well comes that close to a wall, it takes the rest.
    edge = SIDE / 2.0
    if lo + edge < roomcollision.STANCE_XZ:
        lo = -edge
    if edge - hi < roomcollision.STANCE_XZ:
        hi = edge
    return (max(lo, -edge), min(hi, edge))


def _deck(name, top_y, well=None):
    """The top deck across the back, and the bridge out through the wall.

    `well` is an (x_min, x_max) band the deck does not cover -- the
    column the climb comes up through. Returns the parts AND the deck's
    real rect, because with a well the deck is no longer `SIDE` wide and
    the Surface, the routecheck stone and the sockets on it all have to
    be the rect that was actually built.
    """
    edge = SIDE / 2.0
    spans = [(-edge, edge)] if well is None else [
        span for span in ((-edge, well[0]), (well[1], edge))
        if span[1] - span[0] > 0.01]
    parts = []
    for i, (x0, x1) in enumerate(spans):
        width = x1 - x0
        mid = (x0 + x1) / 2.0
        parts.append(_paint(brushkit.block(
            "%s_deck%d" % (name, i), (width, DECK_DEPTH, DECK_THICK),
            (mid, -SIDE + DECK_DEPTH / 2.0, top_y - DECK_THICK / 2.0)),
            name, "floor"))
        parts.append(_paint(brushkit.block(
            "%s_decknose%d" % (name, i), (width, 0.24, 0.20),
            (mid, -SIDE + DECK_DEPTH, top_y - 0.10)), name, "trim"))
    parts.append(_paint(brushkit.block(
        "%s_bridge" % name, (3.0, 2.4, DECK_THICK),
        (0.0, -SIDE - 1.0, top_y - DECK_THICK / 2.0)), name, "floor"))
    # The rect the CLIMB arrives on: the widest span, which is the one
    # the bridge and the exit are reached across.
    x0, x1 = max(spans, key=lambda s: s[1] - s[0])
    return parts, ((x0 + x1) / 2.0, -SIDE + DECK_DEPTH / 2.0), \
        (x1 - x0, DECK_DEPTH)


def _slab(name, tag, x, y, z, size, thickness=0.40):
    """A platform, its nose, and the bracket that carries it.

    Built from the surface it hangs off rather than from its own centre
    (L-55): the bracket starts at the slab's underside.
    """
    sx, sy = size
    return [
        _paint(brushkit.block("%s_p_%s" % (name, tag), (sx, sy, thickness),
                              (x, y, z - thickness / 2.0)), name, "floor"),
        _paint(brushkit.block("%s_pn_%s" % (name, tag),
                              (sx + 0.14, sy + 0.14, 0.14),
                              (x, y, z - 0.07)), name, "trim"),
    ]


def _spiral(name, rise, step):
    """`tower()`'s square spiral: 2.6 m platforms every 2.4 m of perimeter.

    The corners, inset and spacing are the engine's -- `inset = side/2 -
    1.7`, `margin = 2.0`, `spacing = 2.4` -- so an authored spiral climbs
    the same helix the procedural one does and a Check placed against
    either lands in the same place.
    """
    inset, margin, spacing = SIDE / 2.0 - 1.7, 2.0, 2.4
    corners = [(-inset, -margin), (-inset, -SIDE + margin),
               (inset, -SIDE + margin), (inset, -margin)]
    count = int(round(rise / step))
    leg, along = 0, 0.0
    out = []
    for i in range(count):
        a, b = corners[leg % 4], corners[(leg + 1) % 4]
        length = max(abs(b[0] - a[0]), abs(b[1] - a[1]))
        along += spacing
        while along > length:
            along -= length
            leg += 1
            a, b = corners[leg % 4], corners[(leg + 1) % 4]
            length = max(abs(b[0] - a[0]), abs(b[1] - a[1]))
        t = along / length
        out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t,
                    step * (i + 1)))
    return out


def shell_tower_spiral():
    """3 floors, 9 m of rise, on the square spiral built as architecture.

    The engine's own layout, authored: each 2.6 m platform is a slab
    cantilevered off the wall on two brackets, with a nose. `tower()`'s
    boxes float; a slab that is carried by something reads as a stairwell
    whose stairs are gone rather than as tiles that happen to be there.
    """
    floors = 3
    rise = PER_FLOOR * floors
    height = rise + 5.0
    name = "ts"
    parts = _shaft(name, height, rise) + _core(name, rise, "capital")
    # `stones` is routecheck's own ordered list. P1 needs the SAME list as
    # Surfaces and TraversalSegments, so the height and the name of each
    # stone are tracked beside it rather than re-derived later.
    stones, anchors = [_GROUND], []
    heights, snames = [0.0], ["ground"]
    for i, (x, y, z) in enumerate(_spiral(name, rise, STEP)):
        parts += _slab(name, str(i), x, y, z, (PLAT, PLAT))
        # Two brackets into the nearest wall, so the slab is carried.
        wall_x = (SIDE / 2.0) * (1.0 if x > 0 else -1.0)
        for j, dy in ((0, -0.9), (1, 0.9)):
            parts.append(_paint(brushkit.block(
                "ts_br_%d_%d" % (i, j), (abs(wall_x - x) + 0.2, 0.20, 0.42),
                ((wall_x + x) / 2.0, y + dy, z - 0.55)), name, "trim"))
        stones.append(((x, y), (PLAT, PLAT)))
        heights.append(z)
        snames.append("platform_%d" % i)
        anchors.append([round(x, 2), round(z, 2), round(-y, 2)])
    deck_parts, deck_at, deck_size = _deck(
        name, rise, _deck_well(stones, heights, rise))
    parts += deck_parts
    stones.append((deck_at, deck_size))
    heights.append(rise)
    snames.append("deck")
    worst, allowed = routecheck.assert_reachable(
        "shell_tower_spiral", stones, STEP, require_gap=False)
    meta = {"floors": floors, "climb": "spiral", "core": "capital",
            "worst_jump": worst, "max_safe_gap_at_step": allowed,
            "platform_anchors": anchors,
            "_stones": stones, "_heights": heights, "_snames": snames,
            "_rise": rise}
    return "shell_tower_spiral", parts, floors, rise, height, meta


def shell_tower_gantry():
    """5 floors, 15 m -- the tallest a tower may be -- on maintenance access.

    At `floors` 5 the shaft is taller than it is wide, and a spiral of
    fifteen identical slabs up a 12 m box is a staircase pretending to be a
    climb. This one is honest about the height instead: a full landing at
    every 3.0 m, which is `tower()`'s own `per_floor`, joined by short
    flights of three slabs.

    The landings are what the other two do not have. They are somewhere to
    stand and fight at five different heights, and they are why this is the
    only tower where the top is out of sight from the bottom.
    """
    floors = F_MAX
    rise = PER_FLOOR * floors
    height = rise + 5.0
    name = "tg"
    parts = _shaft(name, height, rise) + _core(name, rise, "banded")
    stones, anchors, landings = [_GROUND], [], []
    heights, snames = [0.0], ["ground"]
    run, depth = 4.2, 2.8
    for level in range(floors):
        z = PER_FLOOR * (level + 1)
        side = -1.0 if level % 2 == 0 else 1.0
        # Three slabs of 1.00 m rise each, up the side wall, to the landing.
        for k in range(3):
            sz = z - PER_FLOOR + STEP * (k + 1)
            sy = -3.0 - k * 2.4 if side < 0 else -SIDE + 3.0 + k * 2.4
            sx = side * (SIDE / 2.0 - 1.6)
            parts += _slab(name, "%d_%d" % (level, k), sx, sy, sz,
                           (PLAT, PLAT))
            stones.append(((sx, sy), (PLAT, PLAT)))
            heights.append(sz)
            snames.append("step_%d_%d" % (level, k))
        ly = -SIDE + depth / 2.0 if side < 0 else -depth / 2.0
        parts += _slab(name, "L%d" % level, 0.0, ly, z, (run * 2.0, depth),
                       thickness=0.50)
        for j, sx in enumerate((-run + 0.4, run - 0.4)):
            parts.append(_paint(brushkit.block(
                "tg_post_%d_%d" % (level, j), (0.26, 0.26, PER_FLOOR - 0.5),
                (sx, ly, z - 0.25 - (PER_FLOOR - 0.5) / 2.0)), name, "trim"))
        stones.append(((0.0, ly), (run * 2.0, depth)))
        heights.append(z)
        snames.append("landing_%d" % level)
        landings.append([0.0, round(z, 2), round(-ly, 2)])
        anchors.append([0.0, round(z, 2), round(-ly, 2)])
    deck_parts, deck_at, deck_size = _deck(
        name, rise, _deck_well(stones, heights, rise))
    parts += deck_parts
    stones.append((deck_at, deck_size))
    heights.append(rise)
    snames.append("deck")
    worst, allowed = routecheck.assert_reachable(
        "shell_tower_gantry", stones, STEP, require_gap=False)
    meta = {"floors": floors, "climb": "gantry", "core": "banded",
            "worst_jump": worst, "max_safe_gap_at_step": allowed,
            "platform_anchors": anchors, "landing_anchors": landings,
            "_stones": stones, "_heights": heights, "_snames": snames,
            "_rise": rise}
    return "shell_tower_gantry", parts, floors, rise, height, meta


def shell_tower_collapsed():
    """2 floors, 6 m -- the shortest a tower may be -- climbed on wreckage.

    At the bottom of the range the shaft is half as tall as it is wide, and
    a spiral in it is a ramp with gaps. What 6 m of rise is good for is a
    room with two broken storeys still in it: each floor slab survives over
    HALF THE DEPTH and has torn away over the other, alternating far and
    near, so the two survivors overlap in the middle with 3.0 m of headroom
    between them.

    Those half-floors are the point. 10.8 x 6.6 m against a 2.6 m spiral
    platform is somewhere a fight can happen, twice, at two heights. A
    2-floor tower should be a room twice rather than a short climb, and a
    scaled-down spiral is not that.

    The first version of this shell alternated the survivors LEFT and RIGHT
    instead, which put a 3.60 m crossing between them -- `routecheck`
    refused it against a 2.00 m bound, which is exactly what that module is
    for. Alternating in depth means each climb happens ON the slab below
    it, so no jump ever crosses open shaft.
    """
    floors = F_MIN
    rise = PER_FLOOR * floors
    height = rise + 5.0
    name = "tc"
    parts = _shaft(name, height, rise) + _core(name, rise, "riven")
    stones, anchors = [_GROUND], []
    heights, snames = [0.0], ["ground"]
    span, depth = SIDE - 1.2, 6.6
    for level in range(floors):
        z = PER_FLOOR * (level + 1)
        far = level % 2 == 0
        cy = -SIDE + depth / 2.0 + 0.6 if far else -depth / 2.0 - 0.6
        parts += _slab(name, "F%d" % level, 0.0, cy, z, (span, depth),
                       thickness=0.55)
        # The rubble climbs on the surface BELOW this slab, in the half
        # that this slab does not cover: the ground for level 0, level 0's
        # own floor for level 1.
        climb_y0 = -2.0 if far else -SIDE + 2.0
        sign = -1.0 if far else 1.0
        for k in range(3):
            rz = z - PER_FLOOR + STEP * (k + 1)
            ry = climb_y0 + sign * k * 1.5
            rx = (SIDE / 2.0 - 2.2) * (1.0 if level % 2 == 0 else -1.0) \
                - (0.5 * k if level % 2 == 0 else -0.5 * k)
            parts += _slab(name, "R%d_%d" % (level, k), rx, ry, rz,
                           (PLAT + 0.4, PLAT), thickness=0.5)
            stones.append(((rx, ry), (PLAT + 0.4, PLAT)))
            heights.append(rz)
            snames.append("rubble_%d_%d" % (level, k))
        stones.append(((0.0, cy), (span, depth)))
        heights.append(z)
        snames.append("floor_%d" % level)
        # The tear: a run of stubs along the edge the rest of the slab went
        # over, uneven because nothing that fell is uniform.
        edge_y = cy + (depth / 2.0 if far else -depth / 2.0)
        for k in range(5):
            parts.append(_paint(brushkit.block(
                "tc_tear_%d_%d" % (level, k),
                (1.4, 0.55 + 0.18 * (k % 3), 0.55),
                (-4.4 + k * 2.2, edge_y, z - 0.28)), name, "trim"))
        anchors.append([0.0, round(z, 2), round(-cy, 2)])
    deck_parts, deck_at, deck_size = _deck(
        name, rise, _deck_well(stones, heights, rise))
    parts += deck_parts
    stones.append((deck_at, deck_size))
    heights.append(rise)
    snames.append("deck")
    worst, allowed = routecheck.assert_reachable(
        "shell_tower_collapsed", stones, STEP, require_gap=False)
    meta = {"floors": floors, "climb": "collapse", "core": "riven",
            "worst_jump": worst, "max_safe_gap_at_step": allowed,
            "platform_anchors": anchors, "half_floor": [span, depth],
            "_stones": stones, "_heights": heights, "_snames": snames,
            "_rise": rise}
    return "shell_tower_collapsed", parts, floors, rise, height, meta


SHELLS = [shell_tower_collapsed, shell_tower_spiral, shell_tower_gantry]


def main():
    common.reset_scene()
    report = {}
    for builder in SHELLS:
        name, parts, floors, rise, height, meta = builder()
        if not (F_MIN <= floors <= F_MAX):
            raise AssertionError(
                "%s: %d floors is outside zone.py's %d-%d."
                % (name, floors, F_MIN, F_MAX))
        # --- collision, before the join ------------------------------
        #
        # `common.join` fuses `parts` into one mesh and the individual
        # boxes stop existing. Each collider is a copy of one box, so the
        # twins are taken while there are still boxes to copy; a convex
        # hull of the joined tower would be a solid lump with the doorway
        # and the whole shaft filled in.
        #
        # The support check walks the surfaces this shell is about to
        # declare -- `stones` plus the bridge that `_deck` builds -- and
        # refuses to ship a manifest claiming a floor with no collider
        # under it. That is the defect `eda4fd9` measured, checked here
        # where it is cheap.
        walkable = list(zip(meta["_stones"], meta["_heights"],
                            meta["_snames"]))
        walkable.append((((0.0, -SIDE - 1.0), (3.0, 2.4)), rise, "bridge"))
        colliders = roomcollision.build(parts, name)
        roomcollision.assert_exact(name, parts, colliders)
        roomcollision.assert_supports(
            name, colliders, [w[0] for w in walkable],
            [w[1] for w in walkable], [w[2] for w in walkable])
        probe = roomcollision.measure_probe(
            colliders, [w[0] for w in walkable], [w[1] for w in walkable],
            [w[2] for w in walkable])
        roomcollision.assert_standable(
            name, colliders, [w[0] for w in walkable],
            [w[1] for w in walkable], [w[2] for w in walkable])

        obj = common.join(parts, name)
        common.uv_project_world(obj, materials.ARCH_DENSITY,
                                materials.ARCH_SIZE)
        entry = common.export_glb(obj, "%s/%s.glb" % (OUT, name), "room",
                                  tier="architecture",
                                  texture_size=materials.ARCH_SIZE,
                                  anchor="entrance", check_flat=False,
                                  collision=colliders)
        entry.update(meta)
        if probe:
            # RECORDED, not corrected and not hidden -- see build_rooms.
            entry["surface_probe"] = probe
            for f in probe:
                common.log("%s: surface '%s' declared %.2f measures %.2f "
                           "at %d of %d samples%s"
                           % (name, f["surface"], f["declared"],
                              f["measured"], f["samples"], f["of"],
                              "  (grazing -- ask the engine)"
                              if f.get("grazing") else ""))
        # `tower()` exits through the BACK WALL at summit height, 2.2 m
        # beyond the shaft -- the bridge strip's far end.
        entry["exit_offset"] = [0.0, round(rise, 2), round(SIDE + 2.2, 2)]
        # The Check and its reward volume sit ON the deck, so they are
        # derived from the deck rect rather than from a literal that was
        # true only while the deck was the full width. `_deck_well` cuts
        # the collapsed tower's deck back to x >= -1.4, and x = -2.0 was
        # then a Check hanging in the opening.
        (deck_cx, _deck_cy), (deck_w, _deck_d) = meta["_stones"][-1]
        reward_x = min(max(-2.0, deck_cx - deck_w / 2.0 + 1.0),
                       deck_cx + deck_w / 2.0 - 1.0)
        entry["check_anchor"] = [round(reward_x, 2), round(rise, 2),
                                 round(SIDE - 2.0, 2)]
        entry["enemy_anchors"] = [[round(a[0] * 0.6, 2), round(a[1] + 0.3, 2),
                                   a[2]] for a in meta["platform_anchors"][:4]]
        entry["bounds"] = [[-SIDE / 2.0, -1.0, 0.0],
                           [SIDE, height + 1.0, SIDE + 2.2]]
        entry["interior"] = [SIDE, height, SIDE]
        entry["total_rise"] = rise

        # --- P1 room contract (Production 99379e5) ---------------------
        #
        # Every value below comes from the variable that PLACED the
        # geometry. `stones` is routecheck's own ordered list: it was
        # computed, validated against `max_safe_gap`, and then thrown
        # away. P1 is what finally reads it.
        stones = meta.pop("_stones")
        heights = meta.pop("_heights")
        snames = meta.pop("_snames")
        meta.pop("_rise")
        entry["surfaces"] = roomcontract.surfaces_from_stones(
            stones, heights, snames)
        # The bridge is walked, so it is a surface like any other; it is
        # built by `_deck` and is not in `stones` because the climb ends
        # at the deck.
        entry["surfaces"].append(roomcontract.surface(
            "bridge", (0.0, -SIDE - 1.0), (3.0, 2.4), rise))
        entry["traversal"] = roomcontract.traversal_from_stones(
            stones, heights, snames, STEP)
        # THE KIND COMES FROM THE RISE, AND THE RISE DOES NOT KNOW ABOUT
        # VOIDS. Asking the evidence corrects that for every tower and
        # every future shell, rather than editing one word in one
        # manifest.
        for note in traversallaw.reclassify(colliders, entry,
                                            roomcollision._world_box, name):
            common.log(note)
        for seg in entry["traversal"]:
            if seg["name"] in MEASURED_BY_PRODUCTION:
                was = seg["kind"]
                seg["kind"], why = MEASURED_BY_PRODUCTION[seg["name"]]
                common.log("%s: '%s' %s -> %s -- %s"
                           % (name, seg["name"], was, seg["kind"], why))
        # `_core` is the central column `tower()` requires. CORE square,
        # rise + 2.0 tall, centred on the shaft -- the one interior mass
        # in the family, and nothing may be placed inside it.
        core_h = rise + 2.0
        entry["volumes"] = [
            roomcontract.volume("core", "no_build",
                                (0.0, -SIDE / 2.0, core_h / 2.0 - 0.5),
                                (CORE, CORE, core_h)),
            roomcontract.volume("arrival", "player_entry",
                                (0.0, -1.6, 1.0), (DOOR_W, 2.0, 2.0)),
            roomcontract.volume("reward", "objective",
                                (reward_x, -(SIDE - 2.0), rise + 1.0),
                                (2.0, 2.0, 2.0)),
        ]
        entry["sockets"] = [
            roomcontract.socket("entry", "doorway", (0.0, 0.0, 0.0),
                                yaw=180.0, width=DOOR_W, height=DOOR_H,
                                surface_id="ground"),
            # `exit` IS the next room's origin: `_exit_offset` reads this
            # socket's position, not a door face.
            roomcontract.socket("exit", "doorway",
                                (0.0, -(SIDE + 2.2), rise),
                                yaw=0.0, width=DOOR_W, height=DOOR_H,
                                surface_id="bridge"),
        ]
        # An elevated ranged stance on the four widest raised surfaces,
        # derived from `stones` so each one NAMES the surface it stands
        # on. Taking them from `platform_anchors` instead would tie the
        # socket to a parallel list that means a different thing in each
        # of the three shells.
        raised = [(sn, st, h) for sn, st, h
                  in zip(snames, stones, heights) if h > 0.5]
        raised.sort(key=lambda r: -(r[1][1][0] * r[1][1][1]))
        for i, (sn, stone, h) in enumerate(raised[:4]):
            # WHERE ON the surface, not merely which surface. Taking the
            # centre put `shell_tower_collapsed`'s `high_3` 0.05 m inside
            # the next rubble stone up, because consecutive rungs overlap
            # in plan and the socket was never asked whether anything was
            # already there. `first_stance` keeps the centre when the
            # centre is clear -- which it is for every socket but that
            # one -- and otherwise returns a spot a player fits in, which
            # is stricter than the audit's "not buried" and cannot be
            # looser.
            spot = roomcollision.stance_spot(colliders, stone, h)
            if spot is None:
                raise AssertionError(
                    "%s: surface '%s' carries an 'enemy_high' socket and "
                    "has nowhere anything fits; the surface itself is the "
                    "defect" % (name, sn))
            entry["sockets"].append(roomcontract.socket(
                "high_%d" % i, "enemy_high",
                (spot[0], spot[1], h + 0.3), surface_id=sn))
        entry["size_godot"] = [round(entry["size"][0], 3),
                               round(entry["size"][2], 3),
                               round(entry["size"][1], 3)]
        roomcontract.assert_axis_order(name, entry["size"],
                                       entry["interior"],
                                       entry["size_godot"])
        report[name] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch018",
                       "shells", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
    print("[art] batch018 manifest -> %s" % out)


if __name__ == "__main__":
    main()
