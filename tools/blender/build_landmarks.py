"""Batch 023 -- PROPOSAL: theme landmark language.

    .tools/blender/blender -b --python tools/blender/build_landmarks.py

**Not production, and deliberately not integration-ready.** The audit below
is why, and the manifest says so on every entry.

## The contract audit, before any modelling

The owner's instruction was to find the contract rather than invent one.
There isn't one, and the search is short enough to reproduce:

    grep -rn "landmark" godot/ bridge/ assets/ tools/

Three hits, none of them an engine concept:

  * `derive_budgets.py` and `art_budgets.json` -- a TRIANGLE BUDGET TIER,
    `max_triangles.landmark = 2500`, "an L4 set piece, one per room at
    most, seen from across it".
  * `build_epsilon_installation.py` -- one asset exports under that tier.

So today "landmark" means a polygon ceiling. It is not a chamber property,
not a schema field, and not something Epsilon can select.

  * **Does Epsilon select a landmark ID?** No. `AUTHORED_CONTENT.md` lists
    "Reusable landmarks and hero props" as a category Epsilon would choose
    from, but nothing implements it -- no schema field, no vocabulary entry.
  * **Is there a placement / footprint / anchor contract?** Not for
    landmarks. The room shells (015-019, PASS) carry a real anchor set --
    `check_anchor`, `enemy_anchors`, `affordance_anchor`, `bay_anchors`,
    `bounds`, `interior`, `sightline`, `exit_offset` -- and there is no
    landmark anchor among them.
  * **Is a landmark a room property, an object, a shell feature, or a
    composition idea?** Only the last, plus a budget tier.
  * **What bounds may authored landmark geometry legally own?** Nothing
    reserves any. The only hard numbers are the 2500-triangle landmark
    ceiling and the 12000-triangle room budget.
  * **Does Godot have an integration seam?** **No -- and not only for
    landmarks.** `godot/scripts/` references no `.glb` and reads no
    manifest; `chamber_builders.gd` builds every room from `BoxMesh`
    primitives. The whole authored pipeline is unwired, and the approved
    room shells sit in exactly the same position.

Per the owner's branch: no production placement contract exists, so this is
a VISUAL-LANGUAGE PROPOSAL, the missing seam is recorded as an interface
requirement, and nothing here is registered as integration-ready.

## What a landmark is here

Not a large prop. Each of these changes at least two of silhouette,
navigation, room identity, vertical composition, sightline, traversal,
encounter staging and environmental storytelling -- and each answers "what
was built HERE" from its own theme's construction history rather than being
an Epsilon monument. Epsilon may arrive later as an EVENT; it is not the
identity of a memorable place.

The six take deliberately different spatial jobs, because six variations on
"big object in the middle of the room" would not punctuate a 20-room Zone:

    concrete_facility   drop-test shaft hall     loop around a central void
    rusted_industrial   collapsed process tower  spiral route up a leaning mass
    neon_transit        stacked interchange      two platforms around a void
    gothic_stone        bell breach hall         three levels, one event
    temple_ruin         collapsed ziggurat       the ruin IS the route
    void_glitch         self-intersecting room   space that lies about itself

## Places, not props

The first pass built six OBJECTS -- a ladle, a bell frame, a shaft -- each
standing alone in an empty room. They were decent objects and they were the
wrong deliverable: a landmark you walk around is a prop at landmark scale,
and the target is "the Zone with the giant ___", which is a memory of a
PLACE.

So each of these six is a hero structure PLUS the architecture that makes it
a place: a route at ground level, a route above it, something to look down
from, and in most cases something visible you cannot reach. The support
architecture is not dressing -- it is what turns a shape into somewhere you
were.

## Art provides affordance; the engine owns mechanics

The routes below are SHAPES, not rules. Nothing here invents grapple,
teleport, boss, Check-placement, local-key, checkpoint or reachability
behaviour, and no landmark requires an unapproved capability to traverse.
Where a ledge is unreachable it is unreachable by being high, which is a
fact about geometry rather than a claim about movement.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
from mathutils import Vector  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402

OUT = "batch023/landmarks"

DIM = common.DIM
EYE = DIM["player_eye_height"]
TALL = DIM["player_height"]

_IMAGES = {}
_THEME = "concrete_facility"


def _image(role):
    key = (_THEME, role)
    if key not in _IMAGES:
        canvas, _ = materials.paint(_THEME, role)
        _IMAGES[key] = canvas.to_blender("lm_%s_%s" % (_THEME, role))
    return _IMAGES[key]


def _paint(obj, role):
    common.assign(obj, common.make_textured_material(
        "%s_%s_%s" % (obj.name, _THEME, role), _image(role),
        roughness=pal.roughness(_THEME)))
    return obj




# ----------------------------------------------------------------------
# Place-building helpers
#
# A landmark here is a hero structure plus the architecture that makes it a
# place, so these are the parts that keep recurring: a gallery you look down
# from, a run of catwalk, a rail that says an edge is walkable.
# ----------------------------------------------------------------------

def _ring(name, outer, thickness, height, at, parts=None):
    """A flat rectangular ring in the XY plane -- a gallery, a rim, a court.

    `brushkit.frame` looks like this and is not: it stands in the XZ plane,
    because it was written for doorways. Used as a gallery it builds a wall
    on end.
    """
    half = outer / 2.0
    inner = outer - thickness * 2.0
    out = []
    for side in (-1.0, 1.0):
        out.append(brushkit.block(
            "%s_x%d" % (name, int(side)), (thickness, outer, height),
            (at[0] + side * (half - thickness / 2.0), at[1], at[2])))
        out.append(brushkit.block(
            "%s_y%d" % (name, int(side)), (inner, thickness, height),
            (at[0], at[1] + side * (half - thickness / 2.0), at[2])))
    return out


def _rail(name, outer, at, height=1.05, post=0.09):
    """A guard rail round a ring. What tells the player an edge is a route
    rather than a drop -- and, on an overlook, what says you may stand there."""
    out = []
    half = outer / 2.0
    for side in (-1.0, 1.0):
        out.append(brushkit.block(
            "%s_top_x%d" % (name, int(side)), (post, outer, 0.08),
            (at[0] + side * half, at[1], at[2] + height)))
        out.append(brushkit.block(
            "%s_top_y%d" % (name, int(side)), (outer, post, 0.08),
            (at[0], at[1] + side * half, at[2] + height)))
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            out.append(brushkit.block(
                "%s_post_%d%d" % (name, int(sx), int(sy)),
                (post, post, height),
                (at[0] + sx * half, at[1] + sy * half, at[2] + height / 2.0)))
    return out


def _catwalk(name, length, width, at, axis="y"):
    """A deck with a kick rail each side. The support route that turns a
    hero structure into something you can be above."""
    size = (width, length, 0.14) if axis == "y" else (length, width, 0.14)
    out = [brushkit.block("%s_deck" % name, size, at)]
    for side in (-1.0, 1.0):
        if axis == "y":
            out.append(brushkit.block(
                "%s_rail%d" % (name, int(side)), (0.09, length, 0.95),
                (at[0] + side * width / 2.0, at[1], at[2] + 0.54)))
        else:
            out.append(brushkit.block(
                "%s_rail%d" % (name, int(side)), (length, 0.09, 0.95),
                (at[0], at[1] + side * width / 2.0, at[2] + 0.54)))
    return out


def _tag(objs, role):
    """Pair geometry with the theme role it is painted from.

    Every landmark returns a flat list of these, so a place built from
    thirty blocks still says which parts are structure, which are walked on
    and which are the machinery the room was built around.
    """
    if not isinstance(objs, list):
        objs = [objs]
    return [(o, role) for o in objs]


def lm_drop_test_hall():
    """concrete_facility -- the drop-test shaft, and the hall built to watch it.

    WHAT WAS THIS PLACE FOR: dropping things down a deep shaft and measuring
    what happened. Everything here exists to observe that -- the gallery
    rings the void so you can look down into it, the gantry crosses it so
    you could lower into it, and the booth hangs over it so somebody could
    watch without standing at the edge.

    THE PLACE, not the shaft: a rim you walk at floor level, a gallery loop
    above it to look down from, a gantry bridging the void, and a control
    booth cantilevered over the drop that you can see into and never enter.
    """
    out = []
    shaft, depth = 9.0, 7.0
    for i, z in enumerate((-1.6, -3.4, -5.2)):
        out += _tag(_ring("liner_%d" % i, shaft + 1.4 - i * 0.5, 0.7, 1.7,
                          (0.0, 0.0, z)), "wall")
    out += _tag(brushkit.block("shaft_floor", (shaft - 1.0, shaft - 1.0, 0.4),
                               (0.0, 0.0, -depth)), "floor")
    out += _tag(brushkit.block("impact_table", (3.4, 3.4, 0.55),
                               (0.0, 0.0, -depth + 0.45)), "trim")
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            out += _tag(brushkit.block(
                "table_leg_%d%d" % (int(sx), int(sy)), (0.3, 0.3, 0.9),
                (sx * 1.4, sy * 1.4, -depth + 0.45)), "trim")
    out += _tag(_ring("rim", shaft + 3.0, 1.5, 0.4, (0.0, 0.0, -0.2)), "floor")
    out += _tag(_rail("rim_rail", shaft + 0.2, (0.0, 0.0, 0.0)), "trim")

    gz = 4.4
    out += _tag(_ring("gallery", shaft + 6.2, 2.2, 0.42, (0.0, 0.0, gz)),
                "floor")
    out += _tag(_rail("gallery_rail", shaft + 1.9, (0.0, 0.0, gz + 0.21)),
                "trim")
    for side in (-1.0, 1.0):
        out += _tag(brushkit.block(
            "gallery_leg_%d" % int(side), (0.5, 0.5, gz),
            (side * (shaft / 2.0 + 3.4), side * (shaft / 2.0 + 3.4),
             gz / 2.0)), "wall")

    out += _tag(_catwalk("gantry", shaft + 6.4, 2.0, (0.0, 0.0, gz + 0.9)),
                "trim")
    out += _tag(brushkit.block("hoist_beam", (1.1, shaft + 6.4, 0.55),
                               (0.0, 0.0, gz + 2.3)), "trim")
    out += _tag(brushkit.block("hoist_block", (0.9, 1.2, 1.0),
                               (0.0, -1.2, gz + 1.5)), "accent")

    bz = gz + 3.6
    out += _tag(brushkit.block("booth_floor", (4.2, 3.2, 0.34),
                               (shaft / 2.0 + 0.4, 0.0, bz)), "trim")
    out += _tag(brushkit.block("booth_roof", (4.4, 3.4, 0.3),
                               (shaft / 2.0 + 0.4, 0.0, bz + 2.6)), "trim")
    out += _tag(brushkit.block("booth_back", (0.3, 3.2, 2.6),
                               (shaft / 2.0 + 2.4, 0.0, bz + 1.3)), "wall")
    out += _tag(brushkit.block("booth_glass", (0.12, 3.0, 1.5),
                               (shaft / 2.0 - 1.6, 0.0, bz + 1.5)), "accent")
    out += _tag(brushkit.wedge("booth_brace", (1.6, 2.4, 2.2),
                               (shaft / 2.0 + 1.6, 0.0, bz - 1.1),
                               axis="x"), "wall")
    return out


def lm_process_tower():
    """rusted_industrial -- a distillation column that came down into its
    own support frame, and the service spiral still wrapped round it.

    WHAT HAPPENED HERE: the column sheared above its fourth stage and
    settled into the frame instead of falling clear. The plant kept the
    lower stages standing, so the access spiral that served them is still
    there and still walkable.

    THE PLACE: a spill basin at the bottom you drop into or walk round, a
    spiral of catwalk stages climbing the standing part, and the sheared
    upper column resting overhead at an angle -- visible from everywhere,
    reachable from nowhere.
    """
    out = []
    # The basin: the ground-level route, and the reason the floor is not flat.
    out += _tag(_ring("basin", 13.0, 1.4, 1.1, (0.0, 0.0, -0.55)), "wall")
    out += _tag(brushkit.block("basin_floor", (10.2, 10.2, 0.3),
                               (0.0, 0.0, -1.05)), "floor")
    # Four standing stages of the column.
    for i in range(4):
        z = 1.5 + i * 2.6
        out += _tag(brushkit.prism(
            "stage_%d" % i, 2.3 - i * 0.12, 2.4, 12, (0.0, 0.0, z),
            asset_name="lm_process_tower"), "accent")
        out += _tag(brushkit.tube(
            "stage_band_%d" % i, 2.45 - i * 0.12, 2.15 - i * 0.12, 0.36, 12,
            (0.0, 0.0, z + 1.2), asset_name="lm_process_tower"), "trim")
    # The support frame that caught it.
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            out += _tag(brushkit.block(
                "frame_col_%d%d" % (int(sx), int(sy)), (0.42, 0.42, 12.0),
                (sx * 4.1, sy * 4.1, 6.0)), "trim")
    for i, z in enumerate((3.6, 7.4, 11.2)):
        out += _tag(_ring("frame_belt_%d" % i, 8.6, 0.3, 0.34,
                          (0.0, 0.0, z)), "trim")
    # The service spiral: four quarter-runs climbing the standing stages.
    # This is the route that makes the tower a place rather than a shape.
    for i in range(4):
        z = 1.9 + i * 2.6
        ang = i * 90.0
        rad = 5.4
        import math as _m
        a = _m.radians(ang)
        out += _tag(_catwalk("spiral_%d" % i, 7.4, 1.5,
                             (_m.cos(a) * rad, _m.sin(a) * rad, z),
                             axis="y" if i % 2 == 0 else "x"), "trim")
        out += _tag(brushkit.stair(
            "spiral_step_%d" % i, 0.36, 0.32, 1.4, 8,
            (_m.cos(a) * rad * 0.72, _m.sin(a) * rad * 0.72, z - 2.6)), "trim")
    # The sheared upper column, resting across the frame at an angle.
    upper = brushkit.prism("upper_column", 1.85, 7.6, 12, (0.0, 0.0, 0.0),
                           top_radius=1.6, asset_name="lm_process_tower")
    brushkit.spin(upper, "x", 66.0)
    upper.location = (1.2, -3.4, 12.9)
    out += _tag(upper, "accent")
    out += _tag(brushkit.block("shear_lip", (3.9, 3.9, 0.5),
                               (0.0, 0.0, 11.9)), "trim")
    return out


def lm_stacked_interchange():
    """neon_transit -- two platform levels stacked round an open stair void,
    with a car stopped half out of the tunnel mouth.

    WHAT WAS THIS PLACE FOR: changing trains. The whole geometry is an
    interchange -- lower platform, upper platform, and the void between them
    that let people see which way to go before committing to a stair.

    THE PLACE: a lower platform you arrive on, a mezzanine ring round the
    void, an upper platform above that, and the stopped car -- the one
    object that says this was not always still.
    """
    out = []
    span = 20.0
    # Lower platform and its track trench.
    out += _tag(brushkit.block("lower_deck", (7.0, span, 0.5),
                               (-4.6, 0.0, -0.25)), "floor")
    out += _tag(brushkit.block("trench_floor", (5.2, span, 0.3),
                               (2.2, 0.0, -1.35)), "floor")
    for side in (-1.0, 1.0):
        out += _tag(brushkit.block(
            "rail_%d" % int(side), (0.16, span, 0.16),
            (2.2 + side * 1.5, 0.0, -1.12)), "trim")
    # Platform edge strip: transit's own safety language, and it is TRIM,
    # not hazard -- a platform edge is where you stand, not a warning.
    out += _tag(brushkit.block("edge_strip", (0.5, span, 0.06),
                               (-1.35, 0.0, 0.03)), "accent")
    # The void: the hole between the levels that makes this an interchange
    # rather than two corridors stacked by accident.
    mz = 5.0
    out += _tag(_ring("mezz", 15.0, 2.6, 0.45, (-3.0, 0.0, mz)), "floor")
    out += _tag(_rail("mezz_rail", 9.4, (-3.0, 0.0, mz + 0.22)), "trim")
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            out += _tag(brushkit.block(
                "mezz_col_%d%d" % (int(sx), int(sy)), (0.55, 0.55, mz),
                (-3.0 + sx * 6.6, sy * 6.6, mz / 2.0)), "wall")
    # Stair down into the void, and the escalator run beside it.
    out += _tag(brushkit.stair("void_stair", 0.42, 0.36, 2.2, 13,
                               (-3.0, -3.2, 0.0)), "trim")
    out += _tag(brushkit.wedge("escalator", (2.0, 6.2, mz),
                               (-3.0, 3.4, mz / 2.0), axis="y"), "trim")
    # Upper platform, reached from the mezzanine.
    uz = 9.2
    out += _tag(brushkit.block("upper_deck", (6.0, span * 0.7, 0.45),
                               (-7.2, 0.0, uz)), "floor")
    out += _tag(_rail("upper_rail", 5.4, (-7.2, 0.0, uz + 0.22)), "trim")
    # Tiled wall behind the upper platform: public architecture, not utility.
    out += _tag(brushkit.block("tile_wall", (0.4, span * 0.7, 4.2),
                               (-10.0, 0.0, uz + 2.1)), "wall")
    # The tunnel mouth and the car stopped half inside it.
    out += _tag(brushkit.block("portal_head", (6.2, 0.7, 1.1),
                               (2.2, span / 2.0, 2.6)), "wall")
    for side in (-1.0, 1.0):
        out += _tag(brushkit.block(
            "portal_jamb_%d" % int(side), (0.8, 0.7, 3.2),
            (2.2 + side * 2.7, span / 2.0, 1.6)), "wall")
    out += _tag(brushkit.block("car_body", (2.9, 9.0, 2.6),
                               (2.2, span / 2.0 - 3.4, 0.5)), "accent")
    out += _tag(brushkit.block("car_skirt", (3.1, 9.0, 0.4),
                               (2.2, span / 2.0 - 3.4, -0.9)), "trim")
    for i in range(3):
        out += _tag(brushkit.block(
            "car_window_%d" % i, (0.1, 1.8, 0.9),
            (0.72, span / 2.0 - 6.4 + i * 2.6, 1.1)), "trim")
    return out


def lm_bell_breach():
    """gothic_stone -- the hall the bell fell through.

    WHAT HAPPENED HERE: the bell came out of its frame, went through the
    gallery floor, and stopped in the undercroft. One event, and it is
    legible at three heights at once -- which is the whole reason this is a
    hall and not a bell.

    THE PLACE: an undercroft with the bell in it, a gallery above with a
    ragged hole punched through, the empty frame above THAT, and a
    monumental stair up one side connecting them. You can look down the hole
    from the gallery and up through it from below.
    """
    out = []
    span = 16.0
    # Undercroft: the lowest route, where the bell ended up.
    out += _tag(brushkit.block("undercroft_floor", (span, span, 0.4),
                               (0.0, 0.0, -0.2)), "floor")
    for side in (-1.0, 1.0):
        out += _tag(brushkit.block(
            "nave_wall_%d" % int(side), (0.9, span, 13.0),
            (side * span / 2.0, 0.0, 6.5)), "wall")
        # Engaged piers: the vertical rhythm gothic runs on.
        for i in range(4):
            out += _tag(brushkit.block(
                "pier_%d_%d" % (int(side), i), (1.0, 1.2, 11.0),
                (side * (span / 2.0 - 0.9), -6.0 + i * 4.0, 5.5)), "wall")
    # The gallery floor, with a hole in it. Built as four slabs round the
    # breach rather than one slab, because the hole IS the landmark.
    gz = 6.2
    hole = 5.0
    arm = (span - hole) / 2.0
    for sx in (-1.0, 1.0):
        out += _tag(brushkit.block(
            "gallery_x%d" % int(sx), (arm, span, 0.5),
            (sx * (hole + arm) / 2.0, 0.0, gz)), "floor")
        out += _tag(brushkit.block(
            "gallery_y%d" % int(sx), (hole, arm, 0.5),
            (0.0, sx * (hole + arm) / 2.0, gz)), "floor")
    # Broken slab edges hanging into the breach.
    for i, (x, y) in enumerate(((-2.1, 1.4), (1.8, -2.0), (2.3, 1.9))):
        out += _tag(brushkit.wedge(
            "breach_shard_%d" % i, (1.5, 1.3, 0.7), (x, y, gz - 0.3),
            rotation_z=i * 40.0, axis="x"), "floor")
    out += _tag(_rail("breach_rail", hole + 0.6, (0.0, 0.0, gz + 0.25)),
                "trim")
    # The bell frame above, empty.
    fz = 11.4
    out += _tag(brushkit.block("headstock", (9.0, 0.9, 0.9),
                               (0.0, 0.0, fz)), "trim")
    for side in (-1.0, 1.0):
        out += _tag(brushkit.block(
            "frame_post_%d" % int(side), (1.0, 1.0, 4.4),
            (side * 3.6, 0.0, fz - 2.6)), "wall")
        out += _tag(brushkit.tube(
            "gudgeon_%d" % int(side), 0.36, 0.2, 0.32, 8,
            (side * 1.1, 0.0, fz - 0.55),
            asset_name="lm_bell_breach"), "accent")
    # The bell itself, in the undercroft under the hole it made.
    bell = brushkit.prism("bell", 1.9, 2.5, 12, (0.0, 0.0, 0.0),
                          top_radius=1.05, asset_name="lm_bell_breach")
    brushkit.spin(bell, "x", 74.0)
    bell.location = (0.7, 1.1, 1.25)
    out += _tag(bell, "trim")
    mouth = brushkit.tube("bell_mouth", 2.0, 1.65, 0.34, 12, (0.0, 0.0, 0.0),
                          asset_name="lm_bell_breach")
    brushkit.spin(mouth, "x", 74.0)
    mouth.location = (0.7, -0.05, 1.55)
    out += _tag(mouth, "trim")
    # The monumental stair connecting undercroft to gallery.
    out += _tag(brushkit.stair("great_stair", 0.44, 0.42, 3.0, 15,
                               (-span / 2.0 + 2.6, -2.0, 0.0)), "wall")
    out += _tag(brushkit.block("stair_wall", (0.7, 7.0, 7.4),
                               (-span / 2.0 + 0.9, -2.0, 3.7)), "wall")
    return out


def lm_collapsed_ziggurat():
    """temple_ruin -- a stepped monument whose collapse became the way up.

    WHAT WAS THIS PLACE FOR: a stepped ceremonial platform, climbed on
    ritual occasions by a stair nobody uses now. WHAT HAPPENED HERE: one
    corner gave way, and the rubble of the fall is a slope -- so the ruin
    is more climbable than the monument was.

    THE PLACE, and the reason it is in this set: the collapse IS the route.
    A sunken court at the base, the intact stepped face on one side, the
    fallen corner as a rubble ramp on the other, and a surviving upper
    platform you reach by the failure rather than by the stair.
    """
    out = []
    base, steps, rise = 18.0, 5, 1.7
    tread = 1.5
    # The court the monument stands in -- sunken, so the mass reads taller.
    out += _tag(_ring("court", base + 7.0, 2.0, 1.0, (0.0, 0.0, -0.5)),
                "wall")
    out += _tag(brushkit.block("court_floor", (base + 4.0, base + 4.0, 0.3),
                               (0.0, 0.0, -1.05)), "floor")
    # The monument: five terraces. The +X half of the top two is missing.
    for i in range(steps):
        side = base - i * tread * 2.0
        z = -0.9 + i * rise
        if i < 3:
            out += _tag(brushkit.block(
                "terrace_%d" % i, (side, side, rise), (0.0, 0.0, z + rise / 2.0)),
                "wall")
        else:
            # Sheared: only the -X part of the upper terraces survives.
            keep = side * 0.55
            out += _tag(brushkit.block(
                "terrace_%d" % i, (keep, side, rise),
                (-(side - keep) / 2.0, 0.0, z + rise / 2.0)), "wall")
    # The surviving upper platform, and its shrine stub.
    top_z = -0.9 + steps * rise
    out += _tag(brushkit.block("summit", (5.4, 8.0, 0.4),
                               (-2.6, 0.0, top_z + 0.2)), "floor")
    out += _tag(brushkit.block("shrine", (2.2, 2.2, 2.6),
                               (-3.4, 0.0, top_z + 1.5)), "trim")
    out += _tag(brushkit.wedge("shrine_lintel", (2.6, 2.6, 0.9),
                               (-3.4, 0.0, top_z + 3.2), axis="y"), "trim")
    # The ceremonial stair on the intact face -- steep, formal, and no
    # longer the easiest way up, which is the point.
    out += _tag(brushkit.stair("ritual_stair", 0.5, 0.62, 3.4, 13,
                               (-base / 2.0 - 1.2, 0.0, -0.9)), "trim")
    # The collapse: rubble stepping from the court up to the shear face.
    rubble = [(5.2, -1.4, 0.9, 4.6), (6.4, 2.1, 1.9, 3.8),
              (4.1, 3.4, 3.1, 3.2), (5.9, -3.6, 2.6, 3.0),
              (3.2, 0.6, 4.6, 2.8), (4.4, -0.9, 6.1, 2.4)]
    for i, (x, y, z, sz) in enumerate(rubble):
        out += _tag(brushkit.block(
            "rubble_%d" % i, (sz, sz * 0.8, sz * 0.6), (x, y, z),
            rotation_z=i * 23.0), "wall")
    # Roots binding the ruin -- the reclaiming, structural not decorative.
    for i, (x, y, z, h) in enumerate(((-7.4, 5.2, 2.0, 5.0),
                                      (7.8, -4.4, 1.4, 4.2),
                                      (-2.2, -8.1, 1.0, 3.4))):
        out += _tag(brushkit.block("root_%d" % i, (0.5, 0.44, h), (x, y, z)),
                    "accent")
        out += _tag(brushkit.block("root_arm_%d" % i, (2.6, 0.36, 0.36),
                                   (x + 1.2, y, z + h / 2.0 - 0.4)), "accent")
    return out


def lm_reentrant_room():
    """void_glitch -- a room that intersects itself.

    NOTHING WAS BUILT HERE, and that is this theme's only honest answer.
    The other five places have a history; this one has a FAULT. The same
    chamber has been instanced three times at a rotating offset and the
    copies were never resolved against each other, so the room passes
    through itself and a doorway opens onto its own exterior.

    THE PLACE: the intersections are the route. Where two copies overlap you
    can cross between them, which makes a shortcut that the room's own
    topology says should not exist -- space that lies about itself. Not
    Epsilon: Epsilon is a thing that arrives, and this is the substrate
    failing to finish.
    """
    out = []
    room, height = 11.0, 5.4
    for i in range(3):
        yaw = i * 24.0
        dx, dy, dz = i * 3.1, i * -2.2, i * 1.7
        # Floor and two walls per copy -- an incomplete room, three times.
        out += _tag(brushkit.block(
            "copy%d_floor" % i, (room, room, 0.4), (dx, dy, dz),
            rotation_z=yaw), "floor")
        out += _tag(brushkit.block(
            "copy%d_wall_a" % i, (room, 0.5, height),
            (dx, dy + room / 2.0, dz + height / 2.0), rotation_z=yaw), "wall")
        out += _tag(brushkit.block(
            "copy%d_wall_b" % i, (0.5, room, height),
            (dx - room / 2.0, dy, dz + height / 2.0), rotation_z=yaw), "wall")
        # A doorway in each copy -- which, offset, opens onto the outside of
        # the next one. The specific wrongness worth building.
        out += _tag(brushkit.frame(
            "copy%d_door" % i, (2.6, 3.4), 0.45, 0.6,
            (dx + room / 2.0 - 0.3, dy - 1.4, dz + 1.7)), "trim")
    # A floor that continues at an angle it should not, ending in air.
    ramp = brushkit.block("null_floor", (7.4, 5.0, 0.32), (0.0, 0.0, 0.0))
    brushkit.spin(ramp, "y", 21.0)
    ramp.location = (-6.6, 4.2, 7.6)
    out += _tag(ramp, "floor")
    # The column that should carry it, stopping short of the underside.
    out += _tag(brushkit.block("short_column", (0.9, 0.9, 4.2),
                               (-6.6, 4.2, 2.1)), "wall")
    # A stamped form: one shape repeated with a drifting offset, like a loop
    # that never terminated. Reads as machine error rather than as decay.
    for i in range(5):
        out += _tag(brushkit.block(
            "stamp_%d" % i, (3.2, 0.75, 2.5),
            (7.4 + i * 0.5, -5.0 + i * 0.44, 1.4 + i * 0.66),
            rotation_z=i * 4.0), "accent")
    # Provisional scaffold holding the impossible parts up.
    for i, (x, y, h) in enumerate(((-4.0, 2.4, 6.0), (-8.4, 5.6, 5.2),
                                   (5.6, -3.0, 4.4))):
        out += _tag(brushkit.block("strut_%d" % i, (0.26, 0.26, h),
                                   (x, y, h / 2.0)), "trim")
    return out


#: Each place with its theme, its spatial job, and what the routes are.
#: The routes are SHAPES the engine may or may not use -- art provides
#: affordance, production owns mechanics.
LANDMARKS = [
    (lm_drop_test_hall, "concrete_facility",
     "loop around a central void",
     "rim loop at floor level, gallery loop above it, gantry across the void, "
     "control booth visible and unreachable",
     (-7.6, -7.2, 1.6), (0.0, 0.0, -3.0)),
    (lm_process_tower, "rusted_industrial",
     "spiral route up a leaning mass",
     "basin floor below, spiral of catwalk stages climbing the standing "
     "column, sheared upper column overhead and unreachable",
     (0.5, -9.4, 0.6), (0.5, 1.0, 11.5)),
    (lm_stacked_interchange, "neon_transit",
     "two platforms around a void",
     "lower platform, mezzanine ring round the stair void, upper platform "
     "above it, stopped car at the tunnel mouth",
     (-5.4, -8.6, 1.6), (1.4, 5.0, 5.2)),
    (lm_bell_breach, "gothic_stone",
     "three levels, one event",
     "undercroft with the bell, gallery above with the breach punched "
     "through it, empty frame above that, great stair connecting them",
     (-4.8, -6.4, 1.6), (0.7, 1.6, 7.4)),
    (lm_collapsed_ziggurat, "temple_ruin",
     "the ruin IS the route",
     "sunken court, formal stair up the intact face, rubble ramp up the "
     "collapsed corner, surviving summit platform",
     (12.0, -10.5, 1.0), (0.0, 0.0, 7.0)),
    (lm_reentrant_room, "void_glitch",
     "space that lies about itself",
     "three offset copies of one room whose overlaps are crossable, a floor "
     "continuing at a wrong angle, a door opening onto its own exterior",
     (-13.5, -12.0, 1.6), (2.5, -1.0, 3.4)),
]

#: The last two tuple entries are `eye_from` and `eye_at`, in the builder's
#: own coordinates, before the glTF axis swap.
#:
#: They exist because the first review sheet photographed six INTERIORS from
#: outside their own walls: a hall, an interchange and an undercroft each
#: rendered as a box with a wall facing camera, and the place -- which is
#: the entire deliverable -- was on the other side of it. The builder is the
#: only thing that knows where the hero feature is and therefore where a
#: player would stand to see it, so it says so here rather than leaving a
#: renderer to guess.


def main():
    global _THEME
    report = {}
    for builder, theme, job, routes, eye_from, eye_at in LANDMARKS:
        _THEME = theme
        common.reset_scene()
        _IMAGES.clear()
        tagged = builder()
        for obj, role in tagged:
            _paint(obj, role)
        name = builder.__name__
        obj = common.join([o for o, _ in tagged], name)
        common.set_origin(obj, "module_floor")
        common.uv_project_world(obj, materials.ARCH_DENSITY,
                                materials.ARCH_SIZE)
        entry = common.export_glb(
            obj, "%s/%s.glb" % (OUT, name), "landmark", tier="architecture",
            texture_size=materials.ARCH_SIZE, anchor="module_floor",
            check_flat=False)
        entry["theme"] = theme
        entry["spatial_job"] = job
        entry["routes"] = routes
        # Blender (x, y, z) -> Godot (x, z, -y), matching the glTF export.
        entry["eye_from"] = [eye_from[0], eye_from[2], -eye_from[1]]
        entry["eye_at"] = [eye_at[0], eye_at[2], -eye_at[1]]
        # PROPOSAL SCALE, not runtime truth. There is no landmark placement
        # contract in the engine -- godot/scripts reads no .glb and no
        # manifest at all -- so these dimensions say how big the proposal
        # is, never what it is allowed to own. Interface requirement 24.
        entry["integration_ready"] = False
        entry["scale_basis"] = "proposal scale -- not a reserved footprint"
        entry["placement_contract"] = "none -- see ART_FRONTIER interface req 24"
        zs = [(obj.matrix_world @ v.co).z for v in obj.data.vertices]
        entry["descends_to_m"] = round(min(zs), 2)
        entry["rises_to_m"] = round(max(zs), 2)
        report[name] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch023",
                       "landmarks", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
    print("[art] batch023 manifest -> %s (%d places)" % (out, len(report)))


if __name__ == "__main__":
    main()
