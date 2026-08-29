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

    concrete_facility   a shaft            reads UP, across two elevations
    rusted_industrial   a curved mass      the only curve in a boxy theme
    neon_transit        a level link       vertical circulation you can use
    gothic_stone        an upper frame     occupies the volume overhead
    temple_ruin         a cut void         reads DOWN -- negative, not mass
    void_glitch         a broken construct the theme admitting it is built
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


def lm_freight_shaft():
    """concrete_facility -- a freight lift stalled between floors.

    What was built here: a facility that had to move heavy things
    vertically. What happened here: it stopped mid-job.

    The spatial job is UP. A shaft is the cheapest honest way to make a room
    read at two elevations at once -- you see the cage from below and the
    same cage from the floor above, so "the room with the stuck lift" is one
    place rather than two. The open sides are what make it a landmark and
    not a box: a closed shaft is a column.

    Supports, without requiring: the stalled cage is a platform, the
    counterweight is a second one at a different height, and the open shaft
    is a sightline between floors.
    """
    shaft, height = 4.2, 9.0
    wall = 0.34
    parts = []
    # Two solid sides, two open -- the openings are the whole point.
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "shaft_wall_%d" % int(side), (wall, shaft, height),
            (side * (shaft / 2.0 - wall / 2.0), 0.0, height / 2.0)), "wall"))
    # Guide rails up the open faces, so the openings still read structural.
    for x in (-shaft / 2.0 + 0.5, shaft / 2.0 - 0.5):
        for y in (-shaft / 2.0 + 0.18, shaft / 2.0 - 0.18):
            parts.append(_paint(brushkit.block(
                "shaft_rail_%d_%d" % (int(x * 10), int(y * 10)),
                (0.16, 0.16, height), (x, y, height / 2.0)), "trim"))
    # Floor plates the shaft passes through: this is what says TWO storeys.
    for z in (4.3, 8.6):
        for side in (-1.0, 1.0):
            parts.append(_paint(brushkit.block(
                "shaft_deck_%d_%d" % (int(z * 10), int(side)),
                (2.6, shaft + 1.2, 0.36),
                (side * (shaft / 2.0 + 1.3), 0.0, z)), "floor"))
    # The cage, stopped between them.
    cage_z = 6.1
    parts.append(_paint(brushkit.block(
        "cage_floor", (shaft - 0.9, shaft - 0.9, 0.22),
        (0.0, 0.0, cage_z)), "trim"))
    parts.append(_paint(brushkit.block(
        "cage_roof", (shaft - 0.9, shaft - 0.9, 0.18),
        (0.0, 0.0, cage_z + 2.5)), "trim"))
    for cx in (-(shaft - 1.0) / 2.0, (shaft - 1.0) / 2.0):
        for cy in (-(shaft - 1.0) / 2.0, (shaft - 1.0) / 2.0):
            parts.append(_paint(brushkit.block(
                "cage_post_%d_%d" % (int(cx * 10), int(cy * 10)),
                (0.14, 0.14, 2.5), (cx, cy, cage_z + 1.25)), "trim"))
    parts.append(_paint(brushkit.grate(
        "cage_back", (shaft - 0.9, 2.3, 0.08), 7, 0.06,
        (0.0, -(shaft - 0.9) / 2.0, cage_z + 1.3), axis="x"), "trim"))
    # The counterweight, hanging at the height the cage is not.
    parts.append(_paint(brushkit.block(
        "counterweight", (0.7, 0.7, 1.9),
        (shaft / 2.0 - 0.5, 0.0, 3.2)), "trim"))
    # Head frame and sheave: the silhouette that tops the whole thing.
    parts.append(_paint(brushkit.block(
        "head_beam", (shaft + 1.0, 0.5, 0.5), (0.0, 0.0, height + 0.25)),
        "trim"))
    parts.append(_paint(brushkit.prism(
        "sheave", 0.85, 0.24, 8, (0.0, 0.0, height + 0.95),
        asset_name="lm_freight_shaft"), "trim"))
    return common.join(parts, "lm_freight_shaft")


def lm_pour_ladle():
    """rusted_industrial -- a tapped ladle, frozen mid-pour.

    What was built here: a plant that moved molten metal. What happened
    here: a pour that never finished, and the spill set where it fell.

    The spatial job is MASS, and specifically a CURVE. Every other module in
    this project is a box or a box with one face clipped, so a two-metre
    barrel on a trunnion ring is the only round silhouette a player will
    meet all game -- which is most of why the room is memorable.

    Supports, without requiring: the hardened flow is a ramp onto the
    ladle's shoulder, the body is hard cover mid-room, and the tilt aims the
    whole composition at one corner.
    """
    parts = []
    body_z = 3.4
    # The vessel. A frustum, so it is not a parallel-sided drum.
    parts.append(_paint(brushkit.prism(
        "ladle_body", 1.95, 3.1, 12, (0.0, 0.0, body_z), top_radius=1.62,
        asset_name="lm_pour_ladle"), "accent"))
    parts.append(_paint(brushkit.tube(
        "ladle_lip", 2.05, 1.72, 0.34, 12, (0.0, 0.0, body_z + 1.72),
        asset_name="lm_pour_ladle"), "trim"))
    # The trunnion ring and its two bearing towers -- what lets it tilt, and
    # what stops it reading as a drum somebody left there.
    parts.append(_paint(brushkit.tube(
        "trunnion_ring", 2.25, 1.98, 0.5, 12, (0.0, 0.0, body_z + 0.2),
        asset_name="lm_pour_ladle"), "trim"))
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "bearing_%d" % int(side), (0.66, 0.9, 0.9),
            (side * 2.5, 0.0, body_z + 0.2)), "trim"))
        parts.append(_paint(brushkit.block(
            "tower_%d" % int(side), (0.9, 1.1, body_z + 0.2),
            (side * 2.5, 0.0, (body_z + 0.2) / 2.0)), "wall"))
        parts.append(_paint(brushkit.wedge(
            "brace_%d" % int(side), (0.7, 1.6, 1.7),
            (side * 3.1, 0.0, 0.85), rotation_z=0.0 if side < 0 else 180.0,
            axis="x"), "wall"))
    # The pour: a spout, then the flow hardened into a ramp on the floor.
    parts.append(_paint(brushkit.wedge(
        "spout", (0.9, 1.0, 0.7), (0.0, -1.9, body_z + 1.5), axis="y"),
        "trim"))
    flow = [(0.0, -2.3, 0.10), (0.0, -3.6, 0.34), (0.6, -5.2, 0.62),
            (1.1, -6.6, 0.30), (1.3, -7.8, 0.12)]
    for i, (x, y, h) in enumerate(flow):
        parts.append(_paint(brushkit.block(
            "flow_%d" % i, (2.4 - i * 0.18, 1.6, h), (x, y, h / 2.0)),
            "accent"))
    return common.join(parts, "lm_pour_ladle")


def lm_escalator_bank():
    """neon_transit -- a dead escalator bank under a departure board.

    What was built here: public infrastructure for moving crowds between
    levels. What happened here: it stopped, and the board still holds a
    destination.

    The spatial job is a LEVEL LINK. This is the one landmark whose whole
    reason to exist is circulation, and it is also the one that ties to
    approved work: the board is a housing for runtime wording, exactly as
    Batch 022's signage is, so the theme's memory of where you could go is
    written by the game and not baked into a mesh.

    One of the three flights is collapsed into a ramp -- so the composition
    reads as three states of the same object, which is what stops a bank of
    identical escalators reading as wallpaper.
    """
    parts = []
    rise, run, width = 4.4, 7.6, 1.5
    for i, x in enumerate((-2.1, 0.0, 2.1)):
        if i == 1:
            # The collapsed flight: a clean slope where the steps used to be.
            parts.append(_paint(brushkit.wedge(
                "flight_ramp", (width, run, rise), (x, 0.0, rise / 2.0),
                axis="y"), "trim"))
        else:
            # Per-step, not total: 14 treads of run/14 by rise/14, which
            # keeps every step under MAX_VERTICAL_STEP by construction
            # rather than by hoping.
            parts.append(_paint(brushkit.stair(
                "flight_%d" % i, run / 14.0, rise / 14.0, width, 14,
                (x, 0.0, 0.0)), "trim"))
        # Balustrades give the bank its stripes at distance.
        for side in (-1.0, 1.0):
            # Trim, not accent. neon_transit's accent is a saturated cyan
            # and at balustrade size it filled the whole flight, so the bank
            # read as one glowing slab with the steps -- the entire point of
            # an escalator -- hidden behind it.
            parts.append(_paint(brushkit.wedge(
                "balus_%d_%d" % (i, int(side)),
                (0.14, run, rise + 0.95),
                (x + side * (width / 2.0 + 0.07), 0.0, (rise + 0.95) / 2.0),
                axis="y"), "trim"))
    # The upper deck the bank arrives at.
    parts.append(_paint(brushkit.block(
        "upper_deck", (7.6, 3.0, 0.42), (0.0, run / 2.0 + 1.5, rise + 0.21)),
        "floor"))
    # The board: a housing, blank. Runtime owns the wording (Batch 022).
    board_z = rise + 1.95
    parts.append(_paint(brushkit.block(
        "board_back", (6.4, 0.30, 2.0), (0.0, run / 2.0 + 1.2, board_z)),
        "wall"))
    parts.append(_paint(brushkit.block(
        "board_field", (6.0, 0.12, 1.65),
        (0.0, run / 2.0 + 1.0, board_z)), "accent"))
    parts.append(_paint(brushkit.block(
        "board_hood", (6.7, 0.62, 0.24),
        (0.0, run / 2.0 + 1.05, board_z + 1.12)), "trim"))
    # Hangers reaching UP to a soffit, short enough that the board reads as
    # belonging to the deck below it. At 3.5 m they made it a separate
    # object floating in the room.
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "board_hanger_%d" % int(side), (0.14, 0.14, 1.1),
            (side * 2.6, run / 2.0 + 1.2, board_z + 1.6)), "trim"))
    return common.join(parts, "lm_escalator_bank")


def lm_bell_frame():
    """gothic_stone -- a bell frame, and the bell on the floor below it.

    What was built here: a stone and iron headstock heavy enough to swing a
    tonne of bronze. What happened here: the bell came down.

    The spatial job is the VOLUME OVERHEAD. Every other landmark here stands
    on the floor and is read against a wall; this one occupies the air above
    the player's head, so the room's memorable feature is something you walk
    UNDER. The fallen bell puts the other half of the same event at floor
    level, which is what makes it one story told at two heights rather than
    two props.

    Supports, without requiring: the frame beams are a high route, the bell
    is cover, and the gap the bell fell through is a sightline.
    """
    parts = []
    span, head = 6.4, 6.2
    # Two stone piers carrying the frame.
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.block(
            "pier_%d" % int(side), (1.25, 1.25, head),
            (side * span / 2.0, 0.0, head / 2.0)), "wall"))
        parts.append(_paint(brushkit.block(
            "pier_cap_%d" % int(side), (1.55, 1.55, 0.4),
            (side * span / 2.0, 0.0, head + 0.2)), "trim"))
        # A raking buttress, so the piers read as carrying a load.
        parts.append(_paint(brushkit.wedge(
            "buttress_%d" % int(side), (0.9, 1.9, 3.4),
            (side * (span / 2.0 + 1.0), 0.0, 1.7),
            rotation_z=180.0 if side < 0 else 0.0, axis="x"), "wall"))
    # The headstock frame itself: iron over stone.
    parts.append(_paint(brushkit.block(
        "headstock", (span + 1.6, 0.85, 0.85), (0.0, 0.0, head + 0.75)),
        "trim"))
    for y in (-0.62, 0.62):
        parts.append(_paint(brushkit.block(
            "frame_rail_%d" % int(y * 10), (span + 0.4, 0.3, 0.34),
            (0.0, y, head - 0.5)), "trim"))
    for i, x in enumerate((-1.9, 0.0, 1.9)):
        parts.append(_paint(brushkit.block(
            "frame_strut_%d" % i, (0.26, 1.5, 1.3), (x, 0.0, head + 0.05)),
            "trim"))
    # The empty gudgeons -- the bell's absence, made specific.
    for side in (-1.0, 1.0):
        parts.append(_paint(brushkit.tube(
            "gudgeon_%d" % int(side), 0.34, 0.19, 0.3, 8,
            (side * 1.05, 0.0, head + 0.75),
            asset_name="lm_bell_frame"), "accent"))
    # The bell, down, tilted, part-buried where it struck.
    # Bronze, not the theme accent -- gothic_stone's accent is a cold blue
    # and a blue bell reads as a slab. And it needs a MOUTH: a truncated
    # cone on its side is a wedge, so the flared rim is what says "bell".
    bell = brushkit.prism("bell", 1.72, 2.2, 12, (0.9, 2.9, 0.75),
                          top_radius=0.95, asset_name="lm_bell_frame")
    brushkit.spin(bell, "x", 78.0)
    parts.append(_paint(bell, "trim"))
    mouth = brushkit.tube("bell_mouth", 1.80, 1.48, 0.34, 12,
                          (0.9, 2.9, 0.75), asset_name="lm_bell_frame")
    brushkit.spin(mouth, "x", 78.0)
    for v in mouth.data.vertices:
        v.co.y -= 1.02
        v.co.z += 0.22
    parts.append(_paint(mouth, "trim"))
    # The crown it hung from, now on the floor beside its own frame.
    crown = brushkit.block("bell_crown", (0.5, 0.5, 0.6), (0.9, 4.55, 1.35))
    parts.append(_paint(crown, "accent"))
    parts.append(_paint(brushkit.block(
        "impact_slab", (3.4, 3.0, 0.3), (0.9, 2.9, 0.15)), "floor"))
    return common.join(parts, "lm_bell_frame")


def _ring(name, outer, thickness, height, at):
    """A flat rectangular ring lying in the XY plane.

    `brushkit.frame` looks like this and is not: it stands in the XZ plane,
    because it was written for doorways and portals. Used for a terrace it
    builds a nine-metre wall on end, which is exactly what the first cistern
    build did -- a 4 m pit that measured 10.6 m tall.

    Four blocks, so the middle stays open and the terrace reads as cut away
    rather than stacked up.
    """
    half = outer / 2.0
    inner = outer - thickness * 2.0
    parts = []
    for side in (-1.0, 1.0):
        parts.append(brushkit.block(
            "%s_x%d" % (name, int(side)), (thickness, outer, height),
            (side * (half - thickness / 2.0), 0.0, 0.0)))
        parts.append(brushkit.block(
            "%s_y%d" % (name, int(side)), (inner, thickness, height),
            (0.0, side * (half - thickness / 2.0), 0.0)))
    obj = common.join(parts, name)
    for vertex in obj.data.vertices:
        vertex.co += Vector(at)
    return obj


def lm_stepped_cistern():
    """temple_ruin -- a dry stepped cistern, cut down into the floor.

    What was built here: a tank that stored water and let people walk down
    to whatever level it had reached. What happened here: it went dry, and
    roots came in through the joints.

    The spatial job is DOWN, and it is the only one of the six that is a
    VOID rather than a mass. That matters more than any individual shape:
    five set pieces you walk around plus one you walk into is a set with
    range; six masses is a set with one idea. It also gives a room a
    sightline nothing else here can -- from the rim you see the entire
    geometry and everything standing in it at once.

    Supports, without requiring: a legible descent, a bowl to fight down
    into, and a floor whose lowest point is visible from its highest.
    """
    parts = []
    rim, depth, steps = 9.0, 4.0, 5
    tread = (rim / 2.0 - 1.1) / steps
    riser = depth / steps
    # Terraces down. Each ring is a frame, so the middle stays open and the
    # whole thing reads as cut away rather than stacked up.
    for i in range(steps):
        outer = rim - i * tread * 2.0
        z = -i * riser
        parts.append(_paint(_ring(
            "terrace_%d" % i, outer, tread, riser,
            (0.0, 0.0, z - riser / 2.0)), "wall"))
    floor_side = rim - steps * tread * 2.0
    parts.append(_paint(brushkit.block(
        "cistern_floor", (floor_side, floor_side, 0.3),
        (0.0, 0.0, -depth - 0.15)), "floor"))
    # The rim course: what you see first, standing on the room floor.
    parts.append(_paint(_ring(
        "rim_course", rim + 1.1, 0.55, 0.34, (0.0, 0.0, 0.17)), "trim"))
    # One stair cutting the terraces, so the descent is a route and not a
    # scramble -- and so the symmetry is broken on exactly one side.
    treads = 8
    parts.append(_paint(brushkit.stair(
        "descent", (rim / 2.0 - 0.6) / treads, depth / treads, 1.8, treads,
        (0.0, -rim / 4.0 - 0.3, -depth)), "trim"))
    # Root intrusion at the joints: the reclaiming, not decoration.
    roots = [(-3.4, 3.1, -0.9, 2.2), (3.9, -2.2, -1.9, 2.8),
             (-4.1, -3.6, -2.7, 1.9), (2.6, 3.8, -0.4, 1.6)]
    for i, (x, y, z, h) in enumerate(roots):
        parts.append(_paint(brushkit.block(
            "root_%d" % i, (0.34, 0.30, h), (x, y, z)), "accent"))
        parts.append(_paint(brushkit.block(
            "rootlet_%d" % i, (0.9, 0.20, 0.20), (x + 0.3, y, z - h / 2.0)),
            "accent"))
    return common.join(parts, "lm_stepped_cistern")


def lm_unfinished_room():
    """void_glitch -- a room that failed to finish loading.

    Nothing was built here. That is the point, and it is the one honest
    answer this theme can give to "what happened HERE": the world admitting
    it is a construct.

    A fragment of another theme's architecture intersects at the wrong scale
    and the wrong angle, held up by a scaffold of untextured shells, with
    one form stamped several times as though a loop never terminated.

    The spatial job is WRONGNESS, and it is memorable for the reason the
    other five are not: every other landmark answers its theme's history,
    and this one refuses to have a history. It also earns its place as the
    sixth by quoting the other five -- a fragment here can be any of their
    languages, arriving at a scale that does not belong.

    Deliberately NOT Epsilon. Epsilon green is Epsilon's identity, and a
    room that failed to load is not an intrusion by anything -- it is the
    substrate showing through, which is this theme's own material.
    """
    parts = []
    # The stamp: one form repeated with a drifting offset, like a loop that
    # never terminated. Reads instantly as machine error, not decay.
    for i in range(5):
        parts.append(_paint(brushkit.block(
            "stamp_%d" % i, (3.0, 0.7, 2.4),
            (i * 0.55 - 1.1, i * 0.42, 1.2 + i * 0.62),
            rotation_z=i * 3.5), "wall"))
    # A fragment at the wrong scale and angle: an arch that belongs to
    # gothic_stone, arriving four times too small and rotated off every axis.
    frag = brushkit.frame("fragment", (3.4, 3.4), 0.62, 0.7, (0.0, 0.0, 0.0))
    brushkit.spin(frag, "x", 24.0)
    brushkit.spin(frag, "y", 38.0)
    frag.location = (3.4, -2.6, 4.1)
    parts.append(_paint(frag, "trim"))
    # Scaffold shells holding it: untextured checkerboard is this theme's
    # own material, so the support is provisional too.
    struts = [((3.4, -2.6, 2.0), (0.22, 0.22, 4.0)),
              ((2.3, -1.7, 1.6), (0.22, 0.22, 3.2)),
              ((4.4, -3.4, 1.4), (0.22, 0.22, 2.8))]
    for i, (at, size) in enumerate(struts):
        parts.append(_paint(brushkit.block(
            "strut_%d" % i, size, at), "accent"))
    # A floor plane that stops mid-air, edge-on, going nowhere.
    slab = brushkit.block("null_slab", (5.6, 4.2, 0.24), (0.0, 0.0, 0.0))
    brushkit.spin(slab, "y", 17.0)
    slab.location = (-3.2, 2.4, 3.0)
    parts.append(_paint(slab, "floor"))
    # And the column that should have carried it, ending 1.2 m short.
    parts.append(_paint(brushkit.block(
        "short_column", (0.8, 0.8, 1.8), (-3.2, 2.4, 0.9)), "wall"))
    return common.join(parts, "lm_unfinished_room")


#: Each landmark with the theme it belongs to and the spatial job it does.
#: The job is recorded in the manifest because it is the reason the asset
#: exists -- a landmark that cannot name its job is a large prop.
LANDMARKS = [
    (lm_freight_shaft, "concrete_facility", "vertical shaft, reads at two elevations"),
    (lm_pour_ladle, "rusted_industrial", "curved mass, ramp and mid-room cover"),
    (lm_escalator_bank, "neon_transit", "level link, circulation between floors"),
    (lm_bell_frame, "gothic_stone", "overhead volume, one story at two heights"),
    (lm_stepped_cistern, "temple_ruin", "cut void, descends -- negative not mass"),
    (lm_unfinished_room, "void_glitch", "broken construct, the theme admitting it is built"),
]


def main():
    global _THEME
    report = {}
    for builder, theme, job in LANDMARKS:
        _THEME = theme
        common.reset_scene()
        _IMAGES.clear()
        obj = builder()
        name = obj.name
        common.set_origin(obj, "module_floor")
        common.uv_project_world(obj, materials.ARCH_DENSITY, materials.ARCH_SIZE)
        entry = common.export_glb(
            obj, "%s/%s.glb" % (OUT, name), "landmark", tier="architecture",
            texture_size=materials.ARCH_SIZE, anchor="module_floor",
            check_flat=False)
        entry["theme"] = theme
        entry["spatial_job"] = job
        # Said on every entry, not once in a README: there is no landmark
        # placement contract in the engine, so nothing here may be treated
        # as ready to place. See interface requirement 24.
        # A landmark that is a VOID needs the room floor opened for it.
        # Recorded so a scene does not have to know which of the six is a
        # hole -- the first review sheet laid one slab over everything and
        # sealed the cistern's four terraces under it.
        if name == "lm_stepped_cistern":
            entry["cuts_floor"] = 10.1
        entry["integration_ready"] = False
        entry["placement_contract"] = "none -- see ART_FRONTIER interface req 24"
        report[name] = entry
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch023",
                       "landmarks", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
    print("[art] batch023 manifest -> %s (%d landmarks)" % (out, len(report)))


if __name__ == "__main__":
    main()
