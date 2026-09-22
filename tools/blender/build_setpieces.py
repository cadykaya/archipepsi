"""Batch 045 — visual kits for the four 0.4 setpieces.

    .tools/blender/blender -b -noaudio --python tools/blender/build_setpieces.py

**WHAT THIS IS.** The 0.4 rooms work and they are built out of `BoxMesh`.
`RailCarrier` makes a 4 x 0.4 x 4 box and calls it a skiff; the docks are
slabs; the gantry is a plate. This batch gives those working machines a
visual identity WITHOUT touching one number they run on.

**WHAT IT IS NOT.** No collider, body, trigger, light, camera or script
rides along. Production owns gameplay geometry, collision, state timing and
placement; these are meshes with named parts and declared anchors. Where a
piece needs to be driven, it exports as its own node so a script can fetch
it by name -- a material slot is not a hinge.

## The three numbers everything here is fitted to

`railway_scenario.gd` at Production `claude/archipepsi-0-4-blindside`:

    RAIL_Y      0.6     the path's height above the yard floor
    DECK        (4.0, 0.4, 4.0)
    GANTRY_Y    3.1     "Out of reach on purpose"

`RailCarrier.pose()` returns `Transform3D(basis, here + basis.y * (deck.y *
0.5))`, so THE NODE ORIGIN IS THE DECK BOX'S CENTRE -- not its floor. In
world terms the deck spans 0.6 to 1.0 and the origin sits at 0.8. Every
asset here is authored about that origin, because an asset authored about
its floor arrives 0.2 m low and nobody notices until a passenger clips.

Local axes come from `pose()`: `basis.x` is the side the docks stand on,
`basis.z` is the direction of travel. In Blender's z-up authoring space
that is x = across, y = along the track, z = up.

## THE 0.95 CEILING, AND WHY IT IS NOT A STYLE CHOICE

Nothing this batch adds above a rideable deck rises past **+0.95 in node
space**, which is 1.75 m in the world.

The scenario's own comment says there is no walking bypass to the gantry,
and the arithmetic behind it is: a standing jump tops out at 1.33 m and
there is no mantle, so from the deck top at 1.0 a player reaches 2.33 and
the gantry at 3.1 is safe. A handrail at a natural 1.1 m would put its cap
at world 2.1 -- and 2.1 + 1.33 = 3.43, which is ABOVE THE GANTRY.

These meshes carry no collision, so today that is moot. It is capped anyway
because "it is only a visual" is one refactor away from being false, and a
railing that silently becomes a step is exactly the art-added route the
assignment forbids. 1.75 + 1.33 = 3.08, under 3.1 with 2 cm to spare, so
the guarantee holds under EITHER collision decision. If Production ever
wants a solid rail, the number to argue with is here rather than
rediscovered from a playtest.
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
OUT = "batch045/setpieces"
DENSITY = materials.ARCH_DENSITY
SIZE = materials.ARCH_SIZE

#: Production's numbers, mirrored rather than re-derived. Changing one of
#: these here changes nothing in the game -- it only makes this batch lie.
RAIL_Y = 0.6
DECK = (4.0, 0.4, 4.0)      # runtime x, y, z
GANTRY_Y = 3.1
#: `counterfire_arcade.gd` -- the height the receiver's throat is centred
#: on, so the hood is built around it rather than around its own base.
RECEIVER_Y = 0.85
JUMP_APEX = 1.3333333333333333

#: See the module docstring. Node-space z, above the deck-box centre.
REACH_CAP = 0.95

_IMAGES = {}
_MATERIALS = {}


def _image(role):
    if role not in _IMAGES:
        canvas, _ = materials.paint(THEME, role)
        _IMAGES[role] = canvas.to_blender("sp_%s_%s" % (THEME, role))
    return _IMAGES[role]


def _paint(obj, role, collide=None):
    """Texture role and collision class are two different questions.

    Same split `build_junctions.py` uses: `roomcollision.paint_role` knows
    floor/wall/ceiling/trim, and `accent` is a TEXTURE role that still has
    to say what it structurally is. Nothing in this batch is exported with
    collision -- the class is carried so the tag on each piece stays
    honest and so a later structural use does not have to guess.
    """
    if role not in _MATERIALS:
        _MATERIALS[role] = common.make_textured_material(
            role, _image(role), roughness=pal.roughness(THEME))
    common.assign(obj, _MATERIALS[role])
    return roomcollision.paint_role(obj, collide or role)


def _b(tag, size, at, role="wall", collide=None):
    return _paint(brushkit.block(tag, size, at), role, collide)


def assert_under_cap(objects, label):
    """No visual on a rideable deck may become a step to the gantry."""
    top = max((o.matrix_world @ __import__("mathutils").Vector(c)).z
              for o in objects for c in o.bound_box)
    if top > REACH_CAP + 1e-6:
        raise SystemExit(
            "%s reaches z %.3f in node space (world %.3f). The cap is "
            "%.2f (world %.2f) because %.2f + %.4f of jump is %.3f and "
            "the gantry is at %.1f -- a step onto this would skip the "
            "acquisition loop."
            % (label, top, RAIL_Y + DECK[1] * 0.5 + top, REACH_CAP,
               RAIL_Y + DECK[1] * 0.5 + REACH_CAP,
               RAIL_Y + DECK[1] * 0.5 + REACH_CAP, JUMP_APEX,
               RAIL_Y + DECK[1] * 0.5 + REACH_CAP + JUMP_APEX, GANTRY_Y))
    return top


def skiff():
    """`sp_skiff_deck` -- the Blindside railway skiff.

    A service flat that carries one person through a working yard. The
    two SIDES stay open because that is where the docks are: `DOCK_OUT`
    puts a platform against the deck's outer edge and the inner edges
    meet exactly, so a railing across them would be a railing across the
    door. The ENDS get the guard, which is also where a vehicle's ends
    are.
    """
    hx, hy = DECK[0] * 0.5, DECK[2] * 0.5      # 2.0, 2.0
    top = DECK[1] * 0.5                         # +0.2, the deck surface
    parts = []

    # THE DECK IS THE FLOOR ROLE, AND THAT IS THE FIRST FIX. Painted in
    # `trim` -- the theme's ribbed plating -- the walking surface read as
    # corrugated siding laid flat, and the first render came back looking
    # like a stack of slats on a pallet. `floor` is the role for a
    # surface you stand on, and the structure keeps `trim`.
    #
    # Exactly the box the carrier collides with: same size, same centre,
    # so this mesh REPLACES `Deck` one for one.
    body = _b("skiff_deck", (DECK[0], DECK[2], DECK[1]), (0, 0, 0), "floor")

    # A skirt inside the deck's own thickness. Not under it: the deck's
    # underside is at world 0.6 and the rail pieces span 0.425-0.775, so
    # anything hanging below the deck is inside the rail it rides.
    parts.append(_b("skiff_skirt", (DECK[0] - 0.24, DECK[2] - 0.24, 0.14),
                    (0, 0, -top + 0.03), "accent", "trim"))
    # A curb along the two OPEN sides. It makes the deck read as a pan
    # with a floor in it rather than a slab with things on it, and at
    # 0.08 it is under the 0.12 m walk-up, so boarding is unaffected even
    # if somebody later collides this.
    for side in (-1.0, 1.0):
        parts.append(_b("skiff_curb_%d" % int(side),
                        (0.12, DECK[2] - 0.02, 0.08),
                        (side * (hx - 0.06), 0, top + 0.04), "trim"))
    # Corner bumpers: a working vehicle has been hit, and four blunt
    # corners give the silhouette something to end on.
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.append(_b("skiff_bumper_%d%d" % (int(sx), int(sy)),
                            (0.34, 0.34, 0.26),
                            (sx * (hx - 0.17), sy * (hy - 0.17),
                             top + 0.13), "accent", "trim"))

    for end, tag in ((1.0, "fore"), (-1.0, "aft")):
        y = end * (hy - 0.06)
        # A SOLID LOWER PANEL, not a kick strip. Thin rails at both
        # heights read as scaffolding; a vehicle's end is a plate with a
        # rail over it, and that is also what stops a passenger's foot.
        parts.append(_b("skiff_end_%s" % tag, (DECK[0] - 0.16, 0.12, 0.42),
                        (0, y, top + 0.21), "trim"))
        parts.append(_b("skiff_band_%s" % tag, (DECK[0] - 0.16, 0.16, 0.1),
                        (0, y, top + 0.40), "accent", "trim"))
        parts.append(_b("skiff_cap_%s" % tag, (DECK[0] - 0.1, 0.16, 0.1),
                        (0, y, REACH_CAP - 0.05), "trim"))
        for side in (-1.0, 1.0):
            parts.append(_b("skiff_post_%s%d" % (tag, int(side)),
                            (0.16, 0.16, REACH_CAP - top),
                            (side * (hx - 0.12), y, (REACH_CAP + top) * 0.5),
                            "trim"))
        # DIRECTION LAMPS, one per end, as their own nodes. `RailCarrier`
        # already has FORWARD / BACK / HOLD and emits `departed(from, dir)`
        # -- a runtime that wants to show which way the skiff is about to
        # go has somewhere to put it now. Art declares the node; Prod
        # decides what lights it and when.
        # ON the mid rail, not floating above it: `assert_parts_touch`
        # refused the first cut at 0.47 m clear of the body, which is the
        # same defect as a handle a hand cannot reach.
        parts.append(_b("lamp_%s" % tag, (0.34, 0.16, 0.16),
                        (0, end * hy, top + 0.40), "accent", "trim"))

    # The driving stand. Set in a corner so the deck's walking area stays
    # the 4 x 4 the passenger-carry measurement was made on, and capped
    # like everything else -- a console you can stand on is a step.
    cx, cy = hx - 0.62, -(hy - 0.72)
    parts.append(_b("console", (0.54, 0.44, REACH_CAP - top - 0.16),
                    (cx, cy, (REACH_CAP + top) * 0.5 - 0.08),
                    "trim"))
    # A face, so the stand is a control and not a crate: a proud head
    # with a readout in it and a grab bar down one side.
    parts.append(_b("console_head", (0.66, 0.56, 0.16),
                    (cx, cy, REACH_CAP - 0.08), "accent", "trim"))
    parts.append(_b("console_readout", (0.4, 0.1, 0.12),
                    (cx, cy + 0.28, REACH_CAP - 0.2), "accent", "trim"))
    parts.append(_b("console_grab", (0.08, 0.5, 0.08),
                    (cx - 0.31, cy, REACH_CAP - 0.3), "accent", "trim"))
    # HOLD is a real state in the carrier, not "no input". It gets a lamp.
    # Set INTO the console's top rather than standing on it. The first
    # cut perched it 6 cm proud and `assert_under_cap` refused the asset
    # at 1.070 -- which is the gate doing its job on its own author.
    parts.append(_b("beacon_hold", (0.2, 0.2, 0.12),
                    (cx + 0.18, cy - 0.12, REACH_CAP - 0.09),
                    "accent", "trim"))
    return body, parts


# --- Passing Platforms -------------------------------------------------
#
# `passing_platforms.gd` uses THE SAME `DECK = (4.0, 0.4, 4.0)` as the
# railway. That is a gift and a trap: the envelope is shared, so one
# footprint serves both, and the owner explicitly accepts visually
# distinct variants of one mechanism -- but a recoloured skiff is not a
# second asset family. These two are built differently because they DO
# different things.
#
#   TRANSFER_Y  4.0   where the two routes meet
#   H_RAIL_Y    3.6   the crossing carrier's deck top
#   GAP         0.2   the hop between decks -- NOTHING here bridges it

def hoist_car():
    """`sp_hoist_car` -- the vertical carrier in the transport well.

    A cage that climbs: the structure runs UP, because that is the axis
    it works in and because a rider watching it arrive should read its
    direction before it moves. Corner channels and a cross-braced back,
    open on the two faces a rider steps through.
    """
    hx, hy = DECK[0] * 0.5, DECK[2] * 0.5
    top = DECK[1] * 0.5
    parts = []
    body = _b("hoist_deck", (DECK[0], DECK[2], DECK[1]), (0, 0, 0), "trim")
    parts.append(_b("hoist_apron", (DECK[0] - 0.3, DECK[2] - 0.3, 0.1),
                    (0, 0, -top + 0.02), "accent", "trim"))
    # Corner channels: the climbing structure, and the piece that says
    # "this one goes up" from across the well.
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.append(_b("hoist_channel_%d%d" % (int(sx), int(sy)),
                            (0.16, 0.16, REACH_CAP - top),
                            (sx * (hx - 0.12), sy * (hy - 0.12),
                             (REACH_CAP + top) * 0.5), "trim"))
    # The back wall is the one closed face -- a cage rider has something
    # behind them. The other three stay open: two are the transfer faces
    # and one looks out over the well.
    parts.append(_b("hoist_back", (DECK[0] - 0.2, 0.1, REACH_CAP - top),
                    (0, -(hy - 0.1), (REACH_CAP + top) * 0.5), "trim"))
    for i, z in enumerate((top + 0.26, top + 0.52)):
        parts.append(_b("hoist_brace_%d" % i, (DECK[0] - 0.24, 0.07, 0.07),
                        (0, -(hy - 0.1), z), "accent", "trim"))
    # Which way it is about to travel, as its own node.
    for tag, sy in (("up", 1.0), ("down", -1.0)):
        parts.append(_b("lamp_%s" % tag, (0.22, 0.14, 0.14),
                        (hx - 0.14, sy * (hy - 0.12), REACH_CAP - 0.1),
                        "accent", "trim"))
    return body, parts


def crossing_carrier():
    """`sp_crossing_carrier` -- the horizontal carrier that passes it.

    A flatbed, not a cage: the structure runs ALONG, it is low, and the
    two ends carry buffers. Beside the hoist the difference reads at a
    glance, which is the point -- `H_RAIL_Y` and `TRANSFER_Y` are 0.4 m
    apart and a player has to know which deck is arriving.
    """
    hx, hy = DECK[0] * 0.5, DECK[2] * 0.5
    top = DECK[1] * 0.5
    parts = []
    body = _b("cross_deck", (DECK[0], DECK[2], DECK[1]), (0, 0, 0), "trim")
    # Solebars along the run, inside the deck's own thickness.
    for sy in (-1.0, 1.0):
        parts.append(_b("cross_solebar_%d" % int(sy),
                        (DECK[0] - 0.1, 0.22, 0.16),
                        (0, sy * (hy - 0.16), -top + 0.06), "accent", "trim"))
    # Buffers at the ends: low, so the transfer edges stay legible, and
    # nowhere near the cap.
    for tag, sx in (("west", -1.0), ("east", 1.0)):
        parts.append(_b("cross_buffer_%s" % tag, (0.2, DECK[2] - 0.5, 0.34),
                        (sx * (hx - 0.08), 0, top + 0.17), "trim"))
        parts.append(_b("lamp_%s" % tag, (0.12, 0.3, 0.12),
                        (sx * (hx - 0.08), 0, top + 0.4), "accent", "trim"))
    # A single spine rib so the flatbed is not a plank.
    parts.append(_b("cross_spine", (DECK[0] - 0.6, 0.3, 0.12),
                    (0, 0, top + 0.06), "accent", "trim"))
    return body, parts


# --- Counterfire Arcade -------------------------------------------------
#
#   LANE_HALF   1.5    the lane is 3 m wide
#   RECEIVER_Z -7.0    RECEIVER_Y 0.85
#   SHUTTER     (0.4, 2.6, 2.4)
#
# THE HOOD EXPLAINS WHERE A PROJECTILE MAY TRAVEL, which is the whole
# visual job: a receiver that is a box in a wall teaches nothing, and a
# hood that narrows toward its mouth teaches the lane without a label.

def receiver_hood():
    """`sp_receiver_hood` -- the thing a shot is supposed to reach."""
    parts = []
    # The throat, centred on RECEIVER_Y. Open toward the gunner (+y here;
    # the caller yaws it), so the aperture faces the lane.
    body = _b("hood_shell", (2.2, 1.0, 1.7), (0, 0, RECEIVER_Y), "wall")
    parts.append(_b("hood_lip_top", (2.4, 0.18, 0.2),
                    (0, 0.5, RECEIVER_Y + 0.75), "trim"))
    for sx in (-1.0, 1.0):
        parts.append(_b("hood_cheek_%d" % int(sx), (0.28, 0.9, 1.5),
                        (sx * 1.02, 0.02, RECEIVER_Y), "trim"))
    # The mouth: the one part a runtime may want to light when the
    # receiver accepts, and its own node so it can be driven.
    parts.append(_b("receiver_mouth", (1.3, 0.14, 0.9),
                    (0, 0.5, RECEIVER_Y), "accent", "trim"))
    parts.append(_b("hood_base", (2.4, 1.1, 0.35),
                    (0, 0, 0.175), "trim"))
    return body, parts


def shutter_leaf():
    """`sp_shutter_leaf` -- the 0.4 x 2.6 x 2.4 door, exactly.

    Authored about its BOX CENTRE and nothing else. A shutter that slides
    and a shutter that hinges want different origins, and guessing costs
    a door that opens through its own frame -- so the centre is declared,
    `OPEN_SECONDS` stays Production's, and the handoff asks for the pivot
    rather than inventing one.
    """
    sx, sy, sz = 0.4, 2.4, 2.6    # runtime (0.4, 2.6, 2.4) -> blender
    parts = []
    body = _b("shutter_plate", (sx, sy, sz), (0, 0, 0), "trim")
    for i in range(3):
        z = -sz * 0.5 + sz * (i + 1) / 4.0
        parts.append(_b("shutter_rib_%d" % i, (sx + 0.06, sy - 0.2, 0.14),
                        (0, 0, z), "accent", "trim"))
    parts.append(_b("shutter_edge", (sx + 0.08, sy - 0.1, 0.16),
                    (0, 0, sz * 0.5 - 0.08), "accent", "trim"))
    return body, parts


def lane_screen():
    """`sp_lane_screen` -- protection along the firing lane.

    `LANE_HALF` is 1.5, so the screen stands at 1.5 and shows the lane's
    edge rather than crossing it. Chest height, like `SHIELD_HEIGHT` in
    the railway: cover you stand behind, not a wall you hide in.
    """
    parts = []
    body = _b("screen_panel", (0.22, 3.0, 1.25), (0, 0, 0.625), "wall")
    parts.append(_b("screen_cap", (0.34, 3.0, 0.12), (0, 0, 1.31), "trim"))
    for sy in (-1.0, 1.0):
        parts.append(_b("screen_post_%d" % int(sy), (0.3, 0.3, 1.37),
                        (0, sy * 1.35, 0.685), "trim"))
    # A sight slot, so a screen at chest height is readable as a firing
    # position and not as a fence.
    parts.append(_b("screen_slot", (0.26, 1.2, 0.18), (0, 0, 1.0),
                    "accent", "trim"))
    return body, parts


# --- Unweighted Switch --------------------------------------------------
#
#   PLATE  (2.4, 0.12, 2.4)   CRATE (2.0, 1.0, 2.0) at 200 kg
#   LIGHTENED_SECONDS 8.0     LIGHTENED_MAGNITUDE 0.40
#
# THE CRATE STAYS A STEP. `MAX_VERTICAL_STEP` is 1.0 and the crate is
# exactly 1.0 tall, so the model is 1.0 tall in every state. LIGHTENED is
# shown by a part that lights, never by a model that shrinks -- a crate
# that dissolves to look lighter is a step that stopped existing.

def weight_plate():
    """`sp_weight_plate` -- the weight-class sensor, 2.4 x 0.12 x 2.4."""
    parts = []
    body = _b("plate_deck", (2.4, 2.4, 0.12), (0, 0, 0.06), "trim")
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.append(_b("plate_pad_%d%d" % (int(sx), int(sy)),
                            (0.34, 0.34, 0.16),
                            (sx * 0.95, sy * 0.95, 0.08), "accent", "trim"))
    # What the sensor currently reads. Its own node: the runtime knows
    # the class, the art only promises somewhere to show it.
    parts.append(_b("plate_readout", (1.1, 0.26, 0.14), (0, 0, 0.07),
                    "accent", "trim"))
    return body, parts


def ballast_crate():
    """`sp_ballast_crate` -- 2.0 x 1.0 x 2.0, in every state."""
    parts = []
    body = _b("crate_body", (2.0, 2.0, 1.0), (0, 0, 0.5), "wall")
    for i, z in enumerate((0.22, 0.78)):
        parts.append(_b("crate_band_%d" % i, (2.06, 2.06, 0.1),
                        (0, 0, z), "trim"))
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.append(_b("crate_foot_%d%d" % (int(sx), int(sy)),
                            (0.28, 0.28, 0.14),
                            (sx * 0.82, sy * 0.82, 0.07), "trim"))
    # THE ONLY THING THAT CHANGES WHEN THE CRATE IS LIGHTENED. Four
    # inset panels, one per face, exported as their own nodes. The
    # silhouette does not move and the top stays at 1.0.
    for i, (sx, sy) in enumerate(((0, 1), (0, -1), (1, 0), (-1, 0))):
        parts.append(_b("lightened_panel_%d" % i,
                        (0.9 if sy else 0.12, 0.12 if sy else 0.9, 0.34),
                        (sx * 1.0, sy * 1.0, 0.5), "accent", "trim"))
    return body, parts


# --- Blindside dock -----------------------------------------------------

def dock_stand():
    """`sp_dock_stand` -- the control a rider actually walks up to.

    Stands ON a dock platform whose top is `RAIL_Y + DECK.y` = 1.0, so
    this is authored floor-anchored and placed on that surface. It is
    beside the track, not on the deck, so the deck cap does not apply --
    but it is kept under 1.2 m anyway because a dock is 4 m from the
    gantry's reach arc and a tall stand is a thing to climb.
    """
    parts = []
    body = _b("stand_column", (0.5, 0.5, 0.95), (0, 0, 0.475), "trim")
    parts.append(_b("stand_base", (0.8, 0.8, 0.12), (0, 0, 0.06), "trim"))
    parts.append(_b("stand_head", (0.74, 0.5, 0.2), (0, 0.06, 1.04),
                    "accent", "trim"))
    # Two faces, because a dock serves both directions and `RailCarrier`
    # refuses a command with a reason a player can act on.
    for tag, sy in (("fore", 1.0), ("aft", -1.0)):
        parts.append(_b("lever_%s" % tag, (0.16, 0.16, 0.3),
                        (sy * 0.16, 0.2, 1.12), "accent", "trim"))
    parts.append(_b("stand_readout", (0.44, 0.1, 0.22), (0, 0.28, 0.78),
                    "accent", "trim"))
    return body, parts


#: TIER IS ARCHITECTURE, NOT PROP, AND THAT IS A FIT DECISION.
#:
#: The first export declared `prop` and was refused at 32 texels/m against
#: a 48-80 band. The refusal was right and the tier was the wrong half to
#: keep: a 4 m skiff stands against docks, rails and yard walls that are
#: all painted at `ARCH_DENSITY`, and a vehicle at 64 next to a platform at
#: 32 reads as a different game's asset pasted in. Raising the texture to
#: chase the prop band would have doubled the map to fix a coherence
#: problem it does not have.
#: `capped` marks an asset a player RIDES, where the gantry-reach rule
#: applies. A receiver hood in a wall is not a step to anywhere.
ASSETS = [
    ("sp_skiff_deck", skiff, "centre", "architecture", True),
    ("sp_hoist_car", hoist_car, "centre", "architecture", True),
    ("sp_crossing_carrier", crossing_carrier, "centre", "architecture", True),
    ("sp_receiver_hood", receiver_hood, "floor", "architecture", False),
    ("sp_shutter_leaf", shutter_leaf, "centre", "architecture", False),
    ("sp_lane_screen", lane_screen, "floor", "architecture", False),
    ("sp_weight_plate", weight_plate, "floor", "architecture", False),
    ("sp_ballast_crate", ballast_crate, "floor", "architecture", False),
    ("sp_dock_stand", dock_stand, "floor", "architecture", False),
]


def main():
    made = {}
    for name, build, anchor, tier, capped in ASSETS:
        common.reset_scene()
        # `reset_scene` purges datablocks, so a material or image cached
        # for the previous asset is a dangling StructRNA. Caching across
        # the loop cost "StructRNA of type Material has been removed" on
        # the second asset; the cache is per-asset and says so.
        _IMAGES.clear()
        _MATERIALS.clear()
        body, parts = build()
        # NO set_origin_group. The origin is already the carrier's own --
        # the deck box's centre -- and re-anchoring to a bounding box
        # would move it up by however tall the railings happen to be.
        if capped:
            assert_under_cap([body] + parts, name)
        for obj in [body] + parts:
            common.uv_project_world(obj, DENSITY, SIZE)
        common.assert_parts_touch(body, parts, name)
        entry = common.export_glb(body, "%s/%s.glb" % (OUT, name), "prop",
                                  tier=tier, texture_size=SIZE,
                                  anchor=anchor, parts=parts)
        entry["parts"] = [p.name for p in parts]
        entry["origin_means"] = "RailCarrier node origin: the deck box centre"
        made[name] = entry
        print("[setpiece] %-18s %4d tris, %d part(s)"
              % (name, entry["triangles"], len(parts)))

    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    shared = {
        "batch": "045", "kind": "setpiece_visual",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "carries": "mesh and named parts only. No collider, body, trigger, "
                   "light, camera or script.",
        "fitted_to": {
            "production_ref": "claude/archipepsi-0-4-blindside",
            "rail_y": RAIL_Y, "deck": list(DECK), "gantry_y": GANTRY_Y,
            "reach_cap_node_z": REACH_CAP,
        },
        "texels_per_metre": DENSITY,
        "not_changed": ["collision", "speeds", "timings", "placement",
                        "room topology", "any approved asset"],
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({k: dict(shared, **v) for k, v in made.items()},
                  handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)


if __name__ == "__main__":
    main()
