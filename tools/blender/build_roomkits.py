"""Batch 048 — the other three 0.4 rooms: A06, A07, A08.

    .tools/blender/blender -b -noaudio --python tools/blender/build_roomkits.py

Blindside got A03-A05. This is the same treatment for Passing Platforms,
Counterfire Arcade and Unweighted Switch: the structures that make each
room's mechanism legible, fitted to the constants those rooms run on.

**WHAT IT IS NOT.** No collider, body, trigger, light, camera or script.
No route added or removed. Production owns gameplay geometry, collision,
state timing and placement.

## The three rules this batch is gated on

**1. A06.2 -- decorative structure must not read as a climbable route.**
The transport well's whole proposition is that the two carriers are how
you move. A counterweight with a 0.6 m ledge on it is a staircase
somebody will find. `assert_no_footholds` refuses any upward face big
enough to stand on, above the measured 0.12 m walk-up, on every asset
that lives in open space.

**2. A06.2 -- the tested deck separation is 0.2 m and nothing bridges
it.** `GAP` is the hop between the two decks at the rendezvous, and it
is the room's central question. `assert_spans_no_gap` refuses anything
long enough to lie across it.

**3. A07.3 -- a lane marking may not obscure a projectile.** The bait
lane is where a shot travels at `RECEIVER_Y` 0.85. Floor markings stay
flat, and `assert_below_shot_line` refuses anything that rises into the
path a player has to read.

Everything else is fitted by measurement: the envelopes come from their
constants, and where a number has a frame it is stated (the Blindside
correction was a constant read in the wrong frame, and it cost that
batch its headline).
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402
import roomcollision  # noqa: E402

THEME = common.THEME
OUT = "batch048/roomkits"
DENSITY = materials.ARCH_DENSITY
SIZE = materials.ARCH_SIZE

#: Measured by `run_controller_limits.sh` against the shipped constants.
WALK_UP = 0.12
JUMP_APEX = 1.3333333333333333
PLAYER_RADIUS = 0.4

# --- passing_platforms.gd ----------------------------------------------
PP_TRANSFER_Y = 4.0
PP_SHELF_Y = 8.0
PP_DECK = (4.0, 0.4, 4.0)
PP_GAP = 0.2
PP_RAIL_HEIGHT = 1.1
PP_RAIL_THICK = 0.15
PP_ROOM_HEIGHT = 12.0
#: `H_RAIL_Y := TRANSFER_Y - DECK.y` -- the horizontal carrier's rail
#: height, so its deck TOP lands level with `TRANSFER_Y`.
PP_H_RAIL_Y = PP_TRANSFER_Y - PP_DECK[1]

# --- counterfire_arcade.gd ---------------------------------------------
CF_LANE_HALF = 1.5
CF_GALLERY_Y = 1.0
CF_RECEIVER_Y = 0.85
CF_SHUTTER = (0.4, 2.6, 2.4)
CF_OPEN_SECONDS = 8.0
#: The ranged enemy's published envelope -- the gunner is one.
CF_GUNNER_ENVELOPE = (0.7, 1.4, 0.7)

# --- unweighted_switch.gd ----------------------------------------------
UW_PLATE = (2.4, 0.12, 2.4)
UW_CRATE = (2.0, 1.0, 2.0)
UW_CRATE_KG = 200.0
UW_PARK_Z = 1.0
UW_RECESS_Z = 5.6
UW_SILL_Y = 1.9
UW_DOOR_HALF = 1.2
UW_LIGHTENED_SECONDS = 8.0

_IMAGES = {}
_MATERIALS = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("rk_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, role, collide=None):
    if role not in _MATERIALS:
        _MATERIALS[role] = common.make_textured_material(
            role, _image(role), roughness=pal.roughness(THEME))
    common.assign(obj, _MATERIALS[role])
    return roomcollision.paint_role(obj, collide or role)


def _b(tag, size, at, role="wall", collide=None):
    return _paint(brushkit.block(tag, size, at), role, collide)


def assert_no_footholds(objects, label, floor_z=0.0):
    """Nothing here is a step to anywhere.

    A06.2: "decorative cables and counterweights must not look like
    alternate climbable routes." An upward face at least 0.35 m square,
    standing more than the measured 0.12 m walk-up above the floor, is
    somewhere a 0.4 m-radius body can be put. Whether it is COLLIDED is
    Production's; whether it LOOKS like a way up is Art's, and this is
    the rule Art can hold itself to.
    """
    vec = __import__("mathutils").Vector
    for obj in objects:
        corners = [obj.matrix_world @ vec(c) for c in obj.bound_box]
        top = max(c.z for c in corners) - floor_z
        if top <= WALK_UP:
            continue
        # BOUNDED ABOVE BY THE JUMP, and the first version was not.
        # A standing jump tops out at 1.333 m with no mantle, so a face
        # higher than that is not somewhere a player can get from the
        # floor -- and a rule that refuses the TOP of a two-metre
        # cabinet is a rule that will be switched off. It fired on
        # exactly that. What it is for is a ledge at knee or waist
        # height, and that is the band it checks.
        wide = max(c.x for c in corners) - min(c.x for c in corners)
        deep = max(c.y for c in corners) - min(c.y for c in corners)
        if wide >= 0.35 and deep >= 0.35 and top <= JUMP_APEX:
            raise SystemExit(
                "%s: %s presents a %.2f x %.2f m upward face %.3f m up. "
                "That is somewhere a 0.4 m body can stand, and this "
                "asset lives in open space where the carriers are meant "
                "to be the only way to move."
                % (label, obj.name, wide, deep, top))


def assert_stops_at_edge(objects, label, margin=0.001):
    """Nothing crosses the deck's edge line into the hop.

    `GAP` is 0.2 m and it is the room's central question: the two decks
    meet at the rendezvous with a hop between them, and art that lies
    across it has answered the question for the player.

    **The rule is the EDGE, not a length**, and the first version of
    this got that wrong. It refused anything whose span fell between
    the gap and half a metre past it, on the theory that such a piece
    was "bridge-sized" -- and it duly refused a 0.3 m nosing strip
    lying flat ON the deck, growing backwards, nowhere near the gap. A
    rule about size cannot tell a bridge from a doormat. A rule about
    position can: this asset is authored with local y = 0 ON the edge
    line and everything behind it, so anything at positive y is over
    the hop.
    """
    vec = __import__("mathutils").Vector
    for obj in objects:
        far = max((obj.matrix_world @ vec(c)).y for c in obj.bound_box)
        if far > margin:
            raise SystemExit(
                "%s: %s reaches %.3f m past the deck's edge line. The "
                "hop between the decks is %.2f m and it is what the "
                "room asks; nothing here may lie across it."
                % (label, obj.name, far, PP_GAP))


def assert_below_shot_line(objects, label, shot_y=CF_RECEIVER_Y,
                           clearance=0.25):
    """A lane marking may not stand in the shot's way.

    A07.3: the marking must not obscure a projectile at normal speed.
    The shot travels at `RECEIVER_Y` 0.85, so anything in the lane stays
    a clear 0.25 m below it -- a player reading the path should never
    lose it behind dressing.
    """
    vec = __import__("mathutils").Vector
    for obj in objects:
        top = max((obj.matrix_world @ vec(c)).z for c in obj.bound_box)
        if top > shot_y - clearance + 1e-6:
            raise SystemExit(
                "%s: %s tops out at %.3f and the shot travels at %.2f. "
                "A marking that reaches within %.2f m of the line is a "
                "marking a projectile disappears behind."
                % (label, obj.name, top, shot_y, clearance))


def assert_clear_of_corridor(objects, label, y_range, half_width):
    """Nothing intrudes on the crate's guided travel path.

    A08.3: protect the travel path, parked and engaged positions and
    the footprint the room tests. The crate runs from `PARK_Z` to
    `RECESS_Z` and it is 2.0 m square; anything inside that corridor is
    something the crate drives through.
    """
    vec = __import__("mathutils").Vector
    for obj in objects:
        corners = [obj.matrix_world @ vec(c) for c in obj.bound_box]
        y0, y1 = min(c.y for c in corners), max(c.y for c in corners)
        x0, x1 = min(c.x for c in corners), max(c.x for c in corners)
        if y1 < y_range[0] or y0 > y_range[1]:
            continue
        if x1 < -half_width or x0 > half_width:
            continue
        raise SystemExit(
            "%s: %s occupies x %.3f..%.3f, y %.3f..%.3f, inside the "
            "crate's travel corridor (x +-%.2f, y %.2f..%.2f). The "
            "crate drives through there."
            % (label, obj.name, x0, x1, y0, y1, half_width,
               y_range[0], y_range[1]))


# === A06 -- Passing Platforms ==========================================

def pp_lift_guide():
    """`pp_lift_guide` -- the vertical carrier's guide and drive.

    A06.1. The lift's structure runs UP and says so: a paired mast with
    a ladder of tie plates, a head sheave at the top and a counterweight
    running in its own channel. A 2 m tiling section, so the well's
    full height is a stack rather than one fixed mast.

    **Nothing on it is standable**, which `assert_no_footholds` enforces:
    every tie is 0.14 m deep and every plate is on the mast's face, not
    across it. The room's proposition is that the carriers are how you
    move.
    """
    parts = []
    body = _b("lift_mast", (0.26, 0.26, 2.0), (0, 0, 1.0), "trim")
    parts.append(_b("lift_mast_b", (0.26, 0.26, 2.0), (0.9, 0, 1.0),
                    "trim"))
    for i in range(4):
        z = 0.32 + i * 0.5
        parts.append(_b("lift_tie_%d" % i, (0.64, 0.12, 0.1), (0.45, 0, z),
                        "wall"))
    # The rope run, between the masts and clear of both.
    parts.append(_b("lift_rope", (0.07, 0.07, 2.0), (0.45, 0, 1.0),
                    "accent", "trim"))
    # The counterweight, in its own channel: a heavy thing that moves
    # the other way, which is the readable half of a lift.
    # The channel runs against the second mast, and the weight runs in
    # the channel. The first cut hung both in mid-air between the masts
    # and `assert_parts_touch` refused the weight -- a counterweight
    # that touches nothing is a box floating beside a lift.
    parts.append(_b("lift_channel", (0.14, 0.3, 2.0), (0.7, 0.2, 1.0),
                    "trim"))
    parts.append(_b("lift_weight", (0.3, 0.22, 0.85), (0.7, 0.2, 0.7),
                    "accent", "trim"))
    return body, parts


def pp_shuttle_guide():
    """`pp_shuttle_guide` -- the horizontal carrier's guide and drive.

    A06.1's other half, and it must NOT be the same object turned on its
    side. The lift hangs from a rope; the shuttle is pushed along a
    screw. A 2 m tiling section of beam, screw and carrier saddle.

    `H_RAIL_Y` is `TRANSFER_Y - DECK.y` = 3.6, which is where this rides
    so the shuttle's deck TOP lands level with the transfer at 4.0.
    """
    parts = []
    body = _b("shuttle_beam", (0.34, 2.0, 0.2), (0, 0, -0.1), "trim")
    # The screw: the drive that is visibly not a rope.
    screw = brushkit.prism("shuttle_screw", 0.08, 2.0, 8, (0, 0, 0.12))
    brushkit.spin(screw, "x", 90.0)
    parts.append(_paint(screw, "accent", "trim"))
    for i in range(4):
        y = -0.75 + i * 0.5
        parts.append(_b("shuttle_collar_%d" % i, (0.2, 0.1, 0.2),
                        (0, y, 0.12), "wall"))
    parts.append(_b("shuttle_shoe", (0.3, 0.5, 0.1), (0, 0, 0.05),
                    "wall"))
    return body, parts


def pp_transfer_edge():
    """`pp_transfer_edge` -- the rendezvous edge, with the hop intact.

    A06.2. `RAIL_HEIGHT` 1.1 and `RAIL_THICK` 0.15 are Production's, so
    the railing is authored to them. The marking runs to the deck's own
    edge and STOPS: the 0.2 m gap between decks is the room's question
    and no part of this reaches across it.

    Authored about the deck edge with local y = 0 ON the edge line,
    growing back onto the deck.
    """
    parts = []
    body = _b("edge_nosing", (PP_DECK[0] - 0.2, 0.3, 0.04),
              (0, -0.15, 0.02), "accent", "trim")
    parts.append(_b("edge_band", (PP_DECK[0] - 0.2, 0.1, 0.02),
                    (0, -0.42, 0.01), "trim"))
    # The railing, at Production's own height, on the deck's sides --
    # never across the transfer face.
    for side in (-1.0, 1.0):
        x = side * (PP_DECK[0] * 0.5 - PP_RAIL_THICK * 0.5)
        parts.append(_b("edge_post_%d" % int(side),
                        (PP_RAIL_THICK, PP_RAIL_THICK, PP_RAIL_HEIGHT),
                        (x, -0.3, PP_RAIL_HEIGHT * 0.5), "trim"))
        parts.append(_b("edge_cap_%d" % int(side),
                        (PP_RAIL_THICK + 0.04, 0.5, 0.08),
                        (x, -0.3, PP_RAIL_HEIGHT - 0.04), "accent",
                        "trim"))
    return body, parts


def pp_call_post():
    """`pp_call_post` -- call, stop, and which way it is going.

    A06.3, and the indicators are separate nodes because the same
    housing has to say four different things. `call_lamp` is the
    request; `travel_up` and `travel_down` are the direction; `stop_face`
    is the interrupt. What lights them and when is Production's.

    **The patient alternative is preserved**: nothing here says a
    carrier is the only way, and there is no label claiming a wait is
    wasted.
    """
    parts = []
    body = _b("call_base", (0.34, 0.34, 0.1), (0, 0, 0.05), "trim")
    parts.append(_b("call_post", (0.18, 0.18, 1.0), (0, 0, 0.6), "wall"))
    parts.append(_b("call_head", (0.32, 0.26, 0.34), (0, 0.02, 1.27),
                    "wall"))
    parts.append(_b("call_lamp", (0.16, 0.06, 0.1), (0, 0.15, 1.36),
                    "accent", "trim"))
    parts.append(_b("travel_up", (0.1, 0.06, 0.1), (-0.08, 0.15, 1.2),
                    "accent", "trim"))
    parts.append(_b("travel_down", (0.1, 0.06, 0.1), (0.08, 0.15, 1.2),
                    "accent", "trim"))
    parts.append(_b("stop_face", (0.2, 0.05, 0.14), (0, 0.15, 1.06),
                    "accent", "trim"))
    return body, parts


def pp_recovery_mark():
    """`pp_recovery_mark` -- the recovery floor reads as a place to land.

    A06.4: "Recovery must read as intentional accessible space, not a
    visually lethal pit the runtime treats as safe." So this is a
    LANDING PAD, not a hazard border: a bordered square with a soft
    centre and a way-back arrow, all flat.

    Nothing covers the landing surface -- the tallest part is 0.03 m,
    a quarter of the walk-up limit.
    """
    parts = []
    body = _b("recovery_pad", (3.4, 3.4, 0.03), (0, 0, 0.015), "floor")
    for side in (-1.0, 1.0):
        parts.append(_b("recovery_edge_x%d" % int(side),
                        (0.22, 3.4, 0.02), (side * 1.59, 0, 0.025),
                        "accent", "trim"))
        parts.append(_b("recovery_edge_y%d" % int(side),
                        (3.4, 0.22, 0.02), (0, side * 1.59, 0.025),
                        "accent", "trim"))
    # The way back, so the floor says where to go rather than that you
    # failed.
    parts.append(_b("recovery_arrow", (0.7, 1.1, 0.02), (0, 0.6, 0.025),
                    "trim"))
    return body, parts


# === A07 -- Counterfire Arcade =========================================

def cf_gunner_mount():
    """`cf_gunner_mount` -- the emplacement, on the ranged envelope.

    A07.2. The gunner is a `ranged` enemy and its published envelope is
    0.7 x 1.4 x 0.7, so the mount is built around that and not around a
    shape Art preferred. It sits on the gallery at `GALLERY_Y` 1.0.

    **Art supports the telegraph hook and does not retime the shot.**
    `muzzle_mount` is where a muzzle flash belongs and `telegraph_face`
    is a flat plate at the enemy's own collider centre -- the same point
    `enemy.gd` puts its `TelegraphOrigin` on. Neither decides when.
    """
    parts = []
    w, h, d = CF_GUNNER_ENVELOPE
    body = _b("gunner_deck", (w + 1.0, d + 1.0, 0.16), (0, 0, 0.08),
              "floor")
    # A parapet the gunner shoots over, on the lane side only: the back
    # and flanks stay open so the alternate solution -- killing it --
    # is not barricaded by art.
    parts.append(_b("gunner_parapet", (w + 1.0, 0.18, 0.62),
                    (0, -(d + 1.0) * 0.5 + 0.09, 0.47), "wall"))
    parts.append(_b("gunner_coping", (w + 1.04, 0.24, 0.08),
                    (0, -(d + 1.0) * 0.5 + 0.09, 0.82), "accent", "trim"))
    # Where a muzzle flash belongs: on the lane side, at the enemy's
    # own centre height.
    parts.append(_b("muzzle_mount", (0.26, 0.3, 0.2),
                    (0, -(d + 1.0) * 0.5 + 0.2, 0.16 + h * 0.5), "trim"))
    parts.append(_b("telegraph_face", (0.4, 0.06, 0.4),
                    (0, -(d + 1.0) * 0.5 + 0.34, 0.16 + h * 0.5),
                    "accent", "trim"))
    parts.append(_b("gunner_ammo", (0.34, 0.34, 0.4),
                    (w * 0.5 + 0.2, 0.3, 0.36), "trim"))
    return body, parts


def cf_lane_mark():
    """`cf_lane_mark` -- the bait lane, readable without colour.

    A07.3, and the two constraints are both shapes rather than hues.

    **It does not require colour discrimination**: the lane edge is a
    RIBBED band and the safe side is smooth, so the difference survives
    a greyscale render and a colour-blind player.

    **It does not obscure the shot**: the tallest part is 0.04 m against
    a shot travelling at `RECEIVER_Y` 0.85, and `assert_below_shot_line`
    refuses anything within 0.25 m of that line.

    A 2 m tiling run laid along the lane, authored with local x = 0 on
    the lane's edge at `LANE_HALF`.
    """
    parts = []
    body = _b("lane_band", (0.5, 2.0, 0.03), (0.25, 0, 0.015), "accent",
              "trim")
    for i in range(4):
        parts.append(_b("lane_rib_%d" % i, (0.5, 0.16, 0.04),
                        (0.25, -0.75 + i * 0.5, 0.02), "trim"))
    # Inboard of the band, the lane floor stays smooth and unmarked --
    # which is the other half of the read.
    parts.append(_b("lane_kerb", (0.1, 2.0, 0.04), (0.55, 0, 0.02),
                    "trim"))
    return body, parts


def cf_alcove_frame():
    """`cf_alcove_frame` -- the safe alcove, legible from the lane.

    A07.3: the alcove and the lane have to read as a pair without an
    instruction wall. So the frame is a deep reveal with a lintel, and
    the reveal is what says "you can be in here and not there".

    `ALCOVE_X` spans 3.1 m and `ALCOVE_Z` 2.2 m in their room; this is
    the mouth, authored about its own centre at floor level.
    """
    parts = []
    body = _b("alcove_sill", (3.1, 0.5, 0.05), (0, 0, 0.025), "floor")
    for side in (-1.0, 1.0):
        parts.append(_b("alcove_jamb_%d" % int(side), (0.34, 0.5, 2.4),
                        (side * 1.38, 0, 1.2), "wall"))
        parts.append(_b("alcove_reveal_%d" % int(side), (0.12, 0.5, 2.4),
                        (side * 1.15, 0, 1.2), "accent", "trim"))
    parts.append(_b("alcove_lintel", (3.1, 0.5, 0.36), (0, 0, 2.58),
                    "trim"))
    return body, parts


def cf_shutter_track():
    """`cf_shutter_track` -- exposed tracks and an interval indicator.

    A07.4, and the second sentence of it is the one that matters: "Use
    the runtime interval as data; a looping animation is not the
    countdown authority."

    So there is no animation here. `interval_pips` is a row of eight
    separately named blocks -- one per second of `OPEN_SECONDS` -- and
    what lights how many of them, and when, is Production reading its
    own timer. Art supplies eight addressable things and no clock.

    Built around `SHUTTER` (0.4, 2.6, 2.4), authored about the leaf's
    own centre so it drops in beside `sp_shutter_leaf`.
    """
    parts = []
    w, h, d = CF_SHUTTER
    body = _b("track_head", (w + 0.3, d + 0.4, 0.26), (0, 0, h * 0.5 + 0.13),
              "trim")
    for side in (-1.0, 1.0):
        parts.append(_b("track_rail_%d" % int(side), (0.16, 0.16, h),
                        (0, side * (d * 0.5 + 0.1), 0), "wall"))
    # Eight pips, one per second of OPEN_SECONDS. Named, not animated.
    for i in range(int(CF_OPEN_SECONDS)):
        parts.append(_b("interval_pip_%d" % i, (0.1, 0.16, 0.1),
                        (w * 0.5 + 0.06, -d * 0.5 + 0.28 + i * 0.26,
                         h * 0.5 + 0.13), "accent", "trim"))
    return body, parts


def cf_release_bolt():
    """`cf_release_bolt` -- permanently open, and visibly not a timer.

    A07.5: the far release's state must be visibly different from a
    briefly powered opening. A timed shutter shows pips counting; this
    shows a BOLT DRIVEN HOME -- a mechanical commitment that cannot be
    read as a countdown, which is the whole distinction.

    `bolt_shot` is the part that moves between the two states and
    `bolt_seat` is where it lands. Two positions, no third, and no
    animation.
    """
    parts = []
    body = _b("bolt_case", (0.5, 0.8, 0.44), (0, 0, 0.22), "wall")
    parts.append(_b("bolt_shot", (0.18, 0.5, 0.18), (0, 0.3, 0.22),
                    "accent", "trim"))
    parts.append(_b("bolt_seat", (0.3, 0.16, 0.3), (0, 0.62, 0.22),
                    "trim"))
    parts.append(_b("bolt_lever", (0.1, 0.1, 0.36), (0.2, -0.2, 0.5),
                    "accent", "trim"))
    parts.append(_b("bolt_plate", (0.56, 0.86, 0.06), (0, 0, 0.03),
                    "trim"))
    return body, parts


# === A08 -- Unweighted Switch ==========================================

def uw_plate_frame():
    """`uw_plate_frame` -- the HEAVY-class sensor, and it is not a scale.

    A08.2's sharpest line: "do not reuse the accumulating-kilogram gauge
    as though the two sensors mean the same thing." A kilogram gauge is
    a needle that sweeps; this reads a CLASS. So the carrier is a single
    glyph seat with three discrete class marks and no continuous scale
    anywhere on it -- `class_mark_0..2`, not a dial.

    Built round `PLATE` (2.4, 0.12, 2.4), authored about the plate's own
    centre at floor level.
    """
    parts = []
    w, t, d = UW_PLATE
    body = _b("plate_frame", (w + 0.5, d + 0.5, 0.14), (0, 0, 0.07),
              "trim")
    for side in (-1.0, 1.0):
        parts.append(_b("recess_wall_x%d" % int(side), (0.25, d + 0.5, 0.4),
                        (side * (w * 0.5 + 0.12), 0, 0.2), "wall"))
        parts.append(_b("recess_wall_y%d" % int(side), (w + 0.5, 0.25, 0.4),
                        (0, side * (d * 0.5 + 0.12), 0.2), "wall"))
    # The glyph carrier: a seat for the class read, on the frame's
    # approach side.
    parts.append(_b("glyph_carrier", (0.7, 0.24, 0.5),
                    (0, -(d * 0.5 + 0.12), 0.65), "wall"))
    for i in range(3):
        parts.append(_b("class_mark_%d" % i, (0.14, 0.06, 0.14),
                        (-0.22 + i * 0.22, -(d * 0.5 + 0.24), 0.68),
                        "accent", "trim"))
    return body, parts


def uw_drive_housing():
    """`uw_drive_housing` -- the guided drive, and the corridor it keeps.

    A08.3. The crate runs from `PARK_Z` 1.0 to `RECESS_Z` 5.6 and is
    2.0 m square, so the corridor is 4.6 m long and 2.0 m wide. Nothing
    here enters it -- `assert_clear_of_corridor` refuses anything that
    does, because the crate drives through there.

    **It does not imply freehand carrying is the only solution.** The
    housing has a lever and a guided screw: a machine for MOVING the
    thing, which is the point the room is making before the Status
    answer arrives.

    Authored beside the corridor, with local y = 0 at the park end.
    """
    parts = []
    body = _b("drive_case", (0.7, 1.4, 0.8), (1.6, 0, 0.4), "wall")
    parts.append(_b("drive_cap", (0.78, 1.48, 0.08), (1.6, 0, 0.84),
                    "trim"))
    parts.append(_b("drive_lever", (0.1, 0.1, 0.5), (1.35, -0.4, 1.05),
                    "accent", "trim"))
    parts.append(_b("drive_grip", (0.24, 0.1, 0.1), (1.35, -0.4, 1.28),
                    "accent", "trim"))
    # The guide rail runs the corridor's length, OUTSIDE it.
    parts.append(_b("drive_rail", (0.16, 4.6, 0.16), (1.22, 2.3, 0.2),
                    "trim"))
    for i in range(4):
        parts.append(_b("drive_stanchion_%d" % i, (0.2, 0.2, 0.2),
                        (1.22, 0.4 + i * 1.4, 0.1), "trim"))
    return body, parts


def uw_applicator():
    """`uw_applicator` -- where LIGHTENED comes from, and for how long.

    A08.4/A08.5. `LIGHTENED_SECONDS` is 8.0 and `LIGHTENED_MAGNITUDE`
    0.40, and neither is Art's to display as a countdown: the marker is
    Production's state hook. What Art supplies is the HOUSING and a
    named `applicator_emitter` for the moment it is applied.

    The crate keeps its apparent physical height, solid corners and
    stepping surface throughout -- that is `sp_ballast_crate`'s
    contract from Batch 045 and nothing here touches it.
    """
    parts = []
    body = _b("applicator_case", (0.6, 0.6, 1.1), (0, 0, 0.55), "wall")
    parts.append(_b("applicator_cowl", (0.72, 0.72, 0.2), (0, 0, 1.2),
                    "trim"))
    parts.append(_b("applicator_emitter", (0.3, 0.16, 0.3),
                    (0, -0.34, 0.86), "accent", "trim"))
    parts.append(_b("applicator_feed", (0.14, 0.14, 0.9), (0.26, 0.26, 0.45),
                    "trim"))
    parts.append(_b("applicator_foot", (0.72, 0.72, 0.1), (0, 0, 0.05),
                    "trim"))
    return body, parts


def uw_return_rail():
    """`uw_return_rail` -- the return release, and NOT a stair.

    A08.5 is explicit: do not add a base-kit stair before completion.
    So this is the RELEASE HARDWARE -- a gate frame across the return
    with a drop bar, and `release_bar` is the one part that moves. There
    is no tread on it, nothing to climb, and `assert_no_footholds`
    checks that rather than trusting the description.

    `RETURN_X` spans 3.0 to 6.0 in their room; this is authored about
    the gate's own centre at floor level.
    """
    parts = []
    body = _b("return_sill", (3.0, 0.3, 0.06), (0, 0, 0.03), "floor")
    for side in (-1.0, 1.0):
        parts.append(_b("return_post_%d" % int(side), (0.2, 0.3, 1.5),
                        (side * 1.4, 0, 0.75), "wall"))
    parts.append(_b("release_bar", (2.7, 0.12, 0.12), (0, 0, 1.0),
                    "accent", "trim"))
    parts.append(_b("return_head", (3.0, 0.3, 0.16), (0, 0, 1.58),
                    "trim"))
    parts.append(_b("release_catch", (0.22, 0.2, 0.22), (1.35, 0, 1.0),
                    "accent", "trim"))
    return body, parts


#: What "as-built" means, per asset. These three are authored about a
#: LINE in their room rather than about their own bounding box, and
#: `set_origin_group` would move it -- which is how the edge gate came
#: to report a nosing 0.275 m over a gap it is nowhere near, and the
#: corridor gate to report a guide rail inside a corridor it runs
#: beside.
ORIGIN_MEANS = {
    "pp_transfer_edge": "local y = 0 is the deck's EDGE LINE; "
                        "everything grows back onto the deck",
    "cf_lane_mark": "local x = 0 is the lane edge at LANE_HALF; "
                    "everything grows outward, away from the lane",
    "uw_drive_housing": "local y = 0 is the crate's PARK position and "
                        "+y runs toward the recess; x = 0 is the "
                        "corridor's centre line",
}

#: name, builder, anchor, checks
ASSETS = [
    ("pp_lift_guide", pp_lift_guide, "floor", ("footholds",)),
    ("pp_shuttle_guide", pp_shuttle_guide, "centre", ("footholds",)),
    # "as-built": the origin is NOT re-anchored, because this asset's
    # whole contract is that local y = 0 IS the deck's edge line.
    # `set_origin_group` centres on the bounding box and would move it,
    # which is how the edge gate came to report a nosing 0.275 m over a
    # gap it is nowhere near.
    ("pp_transfer_edge", pp_transfer_edge, "as-built", ("gap",)),
    ("pp_call_post", pp_call_post, "floor", ()),
    ("pp_recovery_mark", pp_recovery_mark, "floor", ()),
    ("cf_gunner_mount", cf_gunner_mount, "floor", ()),
    ("cf_lane_mark", cf_lane_mark, "as-built", ("shot",)),
    ("cf_alcove_frame", cf_alcove_frame, "floor", ()),
    ("cf_shutter_track", cf_shutter_track, "centre", ()),
    ("cf_release_bolt", cf_release_bolt, "floor", ()),
    ("uw_plate_frame", uw_plate_frame, "floor", ()),
    ("uw_drive_housing", uw_drive_housing, "as-built", ("corridor",)),
    ("uw_applicator", uw_applicator, "floor", ()),
    ("uw_return_rail", uw_return_rail, "floor", ("footholds",)),
]


def main():
    made = {}
    for name, build, anchor, checks in ASSETS:
        common.reset_scene()
        _IMAGES.clear()
        _MATERIALS.clear()
        body, parts = build()
        objects = [body] + parts
        if anchor == "floor":
            common.set_origin_group(objects, "floor")
        if "footholds" in checks:
            assert_no_footholds(objects, name)
        if "gap" in checks:
            assert_stops_at_edge(objects, name)
        if "shot" in checks:
            assert_below_shot_line(objects, name)
        if "corridor" in checks:
            assert_clear_of_corridor(objects, name,
                                     (0.0, UW_RECESS_Z - UW_PARK_Z),
                                     UW_CRATE[0] * 0.5)
        for obj in objects:
            common.uv_project_world(obj, DENSITY, SIZE)
        common.assert_parts_touch(body, parts, name)
        entry = common.export_glb(body, "%s/%s.glb" % (OUT, name), "prop",
                                  tier="architecture", texture_size=SIZE,
                                  anchor=anchor, parts=parts)
        entry["parts"] = [p.name for p in parts]
        entry["room"] = {"pp": "passing_platforms",
                         "cf": "counterfire_arcade",
                         "uw": "unweighted_switch"}[name[:2]]
        entry["checks"] = list(checks)
        if anchor == "as-built":
            entry["origin_means"] = ORIGIN_MEANS[name]
        made[name] = entry
        print("[roomkit] %-20s %4d tris, %d part(s)"
              % (name, entry["triangles"], len(parts)))

    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    shared = {
        "batch": "048", "kind": "room_visual",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "carries": "mesh and named parts only. No collider, body, trigger, "
                   "light, camera, script or animation.",
        "fitted_to": {
            "production_ref": "claude/archipepsi-0-4-blindside",
            "pp_transfer_y": PP_TRANSFER_Y, "pp_gap": PP_GAP,
            "pp_rail_height": PP_RAIL_HEIGHT,
            "cf_receiver_y": CF_RECEIVER_Y,
            "cf_open_seconds": CF_OPEN_SECONDS,
            "cf_gunner_envelope": list(CF_GUNNER_ENVELOPE),
            "uw_plate": list(UW_PLATE), "uw_crate": list(UW_CRATE),
            "uw_travel": [UW_PARK_Z, UW_RECESS_Z],
        },
        "texels_per_metre": DENSITY,
        "not_changed": ["collision", "speeds", "timings", "placement",
                        "route availability", "any approved asset"],
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


if __name__ == "__main__":
    main()
