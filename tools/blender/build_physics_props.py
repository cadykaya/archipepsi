"""Batch 043 -- the physics-prop family, four of Design 2's twelve. PROPOSAL.

    .tools/blender/blender -b --python tools/blender/build_physics_props.py

Design 2 §10.1, pinned by Design 6 §4.7, gives twelve object classes with a
typical mass, a carriable flag and a manipulable flag. SIX are built here to
textured, exported candidates: `KEY_COMPONENT`, `POWER_CELL`,
`MECHANICAL_PART`, `GIRDER`, `WEIGHTED` and `BALLAST`. The other six are
mapped against the existing catalogue in
docs/art/review/props_2026-09-11/CLASS_MAP.md and not built.

The six were chosen to make the family's MASS LADDER complete and legible in
one line-up -- 8, 40, 55, 95, 140, 320 kg -- because the question a player
asks of one of these objects is "can I lift that", and the answer is only
learnable by comparison.

## THE FAMILY RULE, AND WHY IT IS CONSTRUCTION AND NOT COLOUR

Design 2 §33.7 requires, always: "Manipulable objects have a consistent
material treatment; `FIXED` objects visibly do not share it." A coloured
sticker would satisfy the letter of that and fail §50's no-hue-alone rule the
moment the player is colour-blind or the room is dark.

So the treatment is UNPAINTED DARK STEEL -- flat, smooth, and far below any
painted body in value -- and it appears in exactly one place: ON THE SURFACES
THE PLAYER'S DEVICE TOUCHES. A body is painted, corroded, cast or crated; a
grip, a lifting eye, a socket lug and an attach pad is bare.

The first attempt used a LIGHT bare metal and it failed in the room: the
painted bodies in `concrete_facility` sit at L* 60-70 and a light steel pad
landed on top of them, so a 16 cm attach pad on the ballast read as a stain.
Dark is not a style choice here, it is the only side of the value axis that
was free. Measured against a painted body it is roughly 45 L* down, which
survives grayscale, distance and a dark room.

Nothing decorative in the existing catalogue carries it -- `prop_crate`,
`prop_oil_drum` and `prop_debris` are painted end to end -- so "has a bare
dark fitting on it" and "you can do something to it" are the same statement.

The second half of the rule is the read between carriable and merely
manipulable, which Design 2 §10.3 draws at 60 kg:

    KEY_COMPONENT     8 kg   carriable      ONE hand-scale grip, on top
    POWER_CELL       40 kg   carriable      ONE hand-scale grip, on top
    MECHANICAL_PART  55 kg   carriable      ONE hand-scale grip, on top
    GIRDER           95 kg   manipulate     attach PADS at both ends, no grip
    WEIGHTED        140 kg   manipulate     attach PADS on two faces, no grip
    BALLAST         320 kg   manipulate     attach PADS on four faces, no grip

A hand grip means a hand can lift it. Its absence, on an object that plainly
has attachment features, means a device has to.

## WHAT IS PROPOSED AND WHAT IS SETTLED

SETTLED, because Design 2 §10.1 states it: the four masses, the carriable and
manipulable flags, and the `mass_class` each derives to under §10.2.

PROPOSED, because nothing states it: every dimension, every attach-point
position and normal, and the bare-metal rule itself. No runtime contract for
object dimensions or attachment interfaces exists yet. These are ART
DIMENSIONS. When a contract arrives, these move to fit it.

NOT TOUCHED: player physics, mass rules, carry limits, package schemas, and
every approved asset. Collision is not derived here at all -- these are
visual candidates, and a collider shipped with them would read as certified
traversal evidence that nobody has produced.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"
OUT = "batch043/physics"
#: The one colour the whole family shares. L* 11.4, low-chroma so it never
#: reads as a signalling family.
#:
#: TWO NUMBERS THAT WERE WRONG BEFORE. It was #252a31 at roughness 0.30, and
#: the comment claimed "L* 18.6 against painted bodies at L* 60-70". Neither
#: half survived measurement once the quiet skin landed:
#:
#:   * a painted body is not L* 60-70 IN THE ROOM. Under the shipped light
#:     model the ballast measured L* 36.3 on bright concrete and 24.6 on
#:     derelict -- the palette value is the albedo, not what reaches the eye.
#:   * at roughness 0.30 the fitting caught the room's own specular and
#:     arrived BRIGHTER than the body it sits on: measured gaps of -1.8 on
#:     the ballast and -3.4 on the anchor block. The rule was inverted on
#:     two of the three objects the owner named, and the palette could not
#:     have shown it.
#:
#: So the albedo is darker, the roughness is up at 0.62 so it stops
#: reflecting, and `tools/content/props_preview.gd` MEASURES the gap in the
#: render on both grounds rather than trusting either number.
HANDLING = "#191d23"
DENSITY = propkit.PROP_DENSITY


# ----------------------------------------------------------------------
# COORDINATE SPACES, STATED ONCE AND CONVERTED ONCE
# ----------------------------------------------------------------------
#
# Blender authors Z-up. glTF is Y-UP BY DEFINITION and the exporter converts
# on the way out, so what a runtime loads is NOT the frame these builders
# work in. An earlier manifest said "+Z is up" beside dimensions that had
# already been exported Y-up, which is a contract that cannot be followed.
#
# There are two transformations between an authored point and a runtime one
# and BOTH have to happen, each exactly once:
#
#   1. the origin shift `set_origin_group` applies when it re-bases the
#      asset on its anchor, and
#   2. the Y-up conversion the exporter applies.
#
# A point authored before the shift and converted without it is wrong by the
# shift; a point shifted twice is wrong by the shift the other way. So the
# shift is returned by `set_origin_group`, subtracted here, and the result
# is converted by `_to_runtime`. Both spaces are written into the manifest
# under their own names so neither can be mistaken for the other, and
# `tools/content/verify_exported_geometry.py` then reads the EXPORTED .glb
# checks each runtime point actually lands on the part it names.

def _to_runtime(v):
    """Blender Z-up -> glTF / Godot Y-up. (x, y, z) -> (x, z, -y)."""
    return [round(v[0], 5), round(v[2], 5), round(-v[1], 5)]


def _shifted(v, shift):
    """An authored point moved by the origin shift, exactly once."""
    return (v[0] - shift[0], v[1] - shift[1], v[2] - shift[2])


def _grip(name, size, at, rotation_z=0.0):
    """A bare-metal feature. Its own object, so it is its own node, its own
    material slot and its own thing a runtime can light when the player is
    close enough to use it (§33.7, "attach point available")."""
    obj = brushkit.block(name, size, at, rotation_z=rotation_z)
    obj.name = name
    return obj


# ----------------------------------------------------------------------

def power_cell():
    """`POWER_CELL`, 40 kg, carriable, goes into power sockets.

    Read from across a room: a canister in a cage with a handle. The cage is
    what says "this is meant to be moved and it is meant to survive being
    dropped"; the base lugs are what say "and it goes into something".
    """
    w, d, h = 0.34, 0.34, 0.52
    body = [
        brushkit.prism("pc_core", 0.125, h * 0.72, 8, (0.0, 0.0, h * 0.40),
                       asset_name="phys_power_cell"),
        brushkit.block("pc_base", (w, d, 0.06), (0.0, 0.0, 0.03)),
        brushkit.block("pc_cap", (w * 0.82, d * 0.82, 0.05),
                       (0.0, 0.0, h - 0.055)),
    ]
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            body.append(brushkit.block(
                "pc_rib_%d_%d" % (int(sx), int(sy)), (0.045, 0.045, h * 0.88),
                (sx * (w / 2.0 - 0.03), sy * (d / 2.0 - 0.03), h * 0.46)))
    shell = common.join(body, "phys_power_cell")
    parts = [
        _grip("grip_bar", (0.22, 0.055, 0.05), (0.0, 0.0, h + 0.055)),
        _grip("grip_post_l", (0.05, 0.055, 0.09), (-0.085, 0.0, h + 0.005)),
        _grip("grip_post_r", (0.05, 0.055, 0.09), (0.085, 0.0, h + 0.005)),
        _grip("attach_socket", (0.19, 0.19, 0.055), (0.0, 0.0, 0.028)),
    ]
    attach = [{"id": "attach_socket", "part": "attach_socket",
               "at": (0.0, 0.0, 0.004), "normal": (0.0, 0.0, -1.0),
               "proposes": "the face that meets a power socket"}]
    return shell, parts, attach


def mechanical_part():
    """`MECHANICAL_PART`, 55 kg, carriable, goes into machinery repair
    sockets. Five kilos under the carry limit, and it should LOOK it: this is
    the heaviest thing in the game a player picks up by hand, so it is dense
    and compact rather than big."""
    w, d, h = 0.44, 0.30, 0.42
    body = [
        brushkit.block("mp_case", (w, d, h * 0.66), (0.0, 0.0, h * 0.33)),
        brushkit.spin(brushkit.prism("mp_hub", 0.11, d + 0.04, 8,
                                     (0.0, 0.0, h * 0.33),
                                     asset_name="phys_mechanical_part"),
                      "x", 90.0),
        brushkit.block("mp_flange", (w * 1.08, 0.05, h * 0.52),
                       (0.0, -d / 2.0 - 0.02, h * 0.33)),
        brushkit.block("mp_shoulder", (w * 0.62, d * 0.74, 0.07),
                       (0.0, 0.0, h * 0.70)),
    ]
    for sx in (-1.0, 1.0):
        body.append(brushkit.block("mp_foot_%d" % int(sx),
                                   (0.07, d * 1.02, 0.045),
                                   (sx * (w / 2.0 - 0.05), 0.0, 0.022)))
    shell = common.join(body, "phys_mechanical_part")
    parts = [
        _grip("grip_bar", (0.19, 0.055, 0.05), (0.0, 0.0, h * 0.70 + 0.11)),
        _grip("grip_post_l", (0.05, 0.055, 0.085),
              (-0.07, 0.0, h * 0.70 + 0.06)),
        _grip("grip_post_r", (0.05, 0.055, 0.085),
              (0.07, 0.0, h * 0.70 + 0.06)),
        _grip("attach_key", (0.13, 0.055, 0.13),
              (0.0, -d / 2.0 - 0.055, h * 0.33)),
    ]
    attach = [{"id": "attach_key", "part": "attach_key",
               "at": (0.0, -d / 2.0 - 0.055, h * 0.33),
               "normal": (0.0, -1.0, 0.0),
               "proposes": "the keyed face that enters a repair socket"}]
    return shell, parts, attach


def key_component():
    """`KEY_COMPONENT`, 8 kg, carriable, "local key loops".

    The lightest thing in the twelve, and the read is entirely scale. At
    0.22 x 0.17 x 0.30 it is the only one that sits inside a silhouette a
    player could close a hand around, and the keyed bit on its nose is the
    whole of what it says: this goes in ONE thing, and you know which.
    """
    w, d, h = 0.22, 0.17, 0.30
    body = [
        brushkit.block("kc_case", (w, d, h * 0.74), (0.0, 0.0, h * 0.40)),
        brushkit.block("kc_collar", (w * 1.12, d * 1.12, 0.045),
                       (0.0, 0.0, h * 0.66)),
        brushkit.block("kc_heel", (w * 0.86, d * 0.86, 0.035),
                       (0.0, 0.0, 0.018)),
        brushkit.block("kc_window", (w * 0.46, 0.02, h * 0.28),
                       (0.0, -d / 2.0 - 0.005, h * 0.40)),
    ]
    shell = common.join(body, "phys_key_component")
    # MEASURED, not nominal. The first version placed these against `h` --
    # the class's nominal height -- while the case actually topped out at
    # 0.231, so the handle exported 43 mm in the air. A fitting sits on the
    # body's real top or it sits on nothing.
    top = common.top_of(shell)
    parts = [
        _grip("grip_bar", (0.11, 0.035, 0.032), (0.0, 0.0, top + 0.058)),
        _grip("grip_post_l", (0.028, 0.035, 0.070), (-0.041, 0.0, top + 0.027)),
        _grip("grip_post_r", (0.028, 0.035, 0.070), (0.041, 0.0, top + 0.027)),
        # The key. Asymmetric on purpose: a symmetric bit would go in either
        # way round, and then it is a plug rather than a key.
        _grip("attach_bit", (0.055, 0.075, 0.075), (-0.028, 0.0, 0.038)),
        _grip("attach_bit_ward", (0.030, 0.075, 0.038), (0.030, 0.0, 0.030)),
    ]
    attach = [{"id": "attach_bit", "part": "attach_bit",
               "at": (-0.028, 0.0, 0.008), "normal": (0.0, 0.0, -1.0),
               "proposes": "a keyed underside; the ward is offset so the "
                           "component enters a receiver one way round only"}]
    return shell, parts, attach


def weighted():
    """`WEIGHTED`, 140 kg, NOT carriable, "pressure plates, counterweights".

    Design 2 changed this class from carriable specifically so it would feel
    different -- §10.1: "Design 1's cube puzzles are walked; Design 2's are
    pushed, pulled, and dropped." So it must not read as a crate that got
    bigger. It is battered, it tapers to a broad base, and it carries push
    pads on two opposite faces and no hand grip at all.
    """
    w, d, h = 0.82, 0.82, 0.74
    body = [
        brushkit.block("wt_base", (w, d, h * 0.24), (0.0, 0.0, h * 0.12)),
        brushkit.block("wt_body", (w * 0.88, d * 0.88, h * 0.60),
                       (0.0, 0.0, h * 0.54)),
        brushkit.block("wt_cap", (w * 0.96, d * 0.96, h * 0.10),
                       (0.0, 0.0, h * 0.89)),
    ]
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            body.append(brushkit.block(
                "wt_post_%d_%d" % (int(sx), int(sy)), (0.075, 0.075, h * 0.72),
                (sx * (w / 2.0 - 0.05), sy * (d / 2.0 - 0.05), h * 0.48)))
    shell = common.join(body, "phys_weighted")
    parts, attach = [], []
    for i, sy in enumerate((-1.0, 1.0)):
        # Against the POSTS, which are what stands proud at pad height --
        # not against the base's outer face, which is 4 cm further out and
        # 30 cm lower. The first version used the latter and the pads
        # floated 10 mm off the body.
        py = sy * (w / 2.0 - 0.05 + 0.0375 + 0.010)
        parts.append(_grip("attach_push_%d" % i, (0.30, 0.045, 0.18),
                           (0.0, py, h * 0.52)))
        attach.append({"id": "attach_push_%d" % i,
                       "part": "attach_push_%d" % i,
                       "at": (0.0, py + sy * 0.022, h * 0.52),
                       "normal": (0.0, sy, 0.0),
                       "proposes": "a push face; two of them, opposite, "
                                   "because this class is pushed along an "
                                   "axis rather than carried"})
    return shell, parts, attach


def girder():
    """`GIRDER`, 95 kg, NOT carriable, "spans gaps; attaches at both ends".

    The whole design is the two ends. A plain beam is a plank; a beam with a
    machined plate, a pin boss and a chamfered nose at each end is a thing
    that obviously goes between two other things. 3.20 m spans Design 2
    §fx_bridge_assembly's 6 m gap in two, which is what the fixture does.
    """
    length, w, h = 3.20, 0.20, 0.26
    web, flange = 0.05, 0.045
    body = [
        brushkit.block("gd_web", (length, web, h - flange * 2.0),
                       (0.0, 0.0, 0.0)),
        brushkit.block("gd_flange_top", (length, w, flange),
                       (0.0, 0.0, (h - flange) / 2.0)),
        brushkit.block("gd_flange_bottom", (length, w, flange),
                       (0.0, 0.0, -(h - flange) / 2.0)),
    ]
    for sx in (-1.0, 1.0):
        body.append(brushkit.block("gd_nose_%d" % int(sx),
                                   (0.10, w * 0.72, h * 0.62),
                                   (sx * (length / 2.0 - 0.05), 0.0, 0.0)))
    shell = common.join(body, "phys_girder")
    parts, attach = [], []
    for sx in (-1.0, 1.0):
        tag = "a" if sx < 0 else "b"
        x = sx * (length / 2.0 - 0.012)
        parts.append(_grip("attach_end_%s" % tag, (0.045, w, h),
                           (sx * (length / 2.0 - 0.022), 0.0, 0.0)))
        attach.append({"id": "attach_end_%s" % tag,
                       "part": "attach_end_%s" % tag,
                       "at": (sx * (length / 2.0 - 0.001), 0.0, 0.0),
                       "normal": (sx, 0.0, 0.0),
                       "proposes": "an end plate that meets a wall or "
                                   "another girder's end plate"})
    return shell, parts, attach


def ballast():
    """`BALLAST`, 320 kg, NOT carriable, counterweight mass, "rarely moved
    far". It has to look like it does not want to be moved: low, wide, cast
    in one piece, on skids rather than feet, and banded so the eye reads
    weight before it reads size."""
    # 1.04 wide and 0.54 tall: a 2:1 footprint-to-height block. The first
    # version was 0.86 x 0.66 x 0.66 -- near enough a cube that it read as
    # `prop_crate` in a bigger size, which is the one thing a 320 kg
    # counterweight must not do. Weight is proportion before it is texture.
    w, d, h = 1.04, 0.74, 0.54
    body = [
        brushkit.block("bl_mass", (w, d, h * 0.62), (0.0, 0.0, h * 0.45)),
        brushkit.block("bl_crown", (w * 0.84, d * 0.84, h * 0.16),
                       (0.0, 0.0, h * 0.84)),
        brushkit.block("bl_skid_l", (w * 1.02, 0.14, 0.14),
                       (0.0, -d / 2.0 + 0.08, 0.07)),
        brushkit.block("bl_skid_r", (w * 1.02, 0.14, 0.14),
                       (0.0, d / 2.0 - 0.08, 0.07)),
    ]
    for i, z in enumerate((h * 0.30, h * 0.58)):
        body.append(brushkit.block("bl_band_%d" % i, (w * 1.02, d * 1.02, 0.05),
                                   (0.0, 0.0, z)))
    shell = common.join(body, "phys_ballast")
    parts, attach = [], []
    for i, (dx, dy) in enumerate(((0.0, -1.0), (0.0, 1.0),
                                  (-1.0, 0.0), (1.0, 0.0))):
        px = dx * (w / 2.0 + 0.020)
        py = dy * (d / 2.0 + 0.020)
        parts.append(_grip("attach_pad_%d" % i,
                           (0.22 if dy else 0.045, 0.045 if dy else 0.22,
                            0.20), (px, py, h * 0.55)))
        attach.append({"id": "attach_pad_%d" % i,
                       "part": "attach_pad_%d" % i,
                       "at": (px, py, h * 0.55), "normal": (dx, dy, 0.0),
                       "proposes": "a device attach pad; four of them so the "
                                   "player is never on the wrong side"})
    return shell, parts, attach


def generic():
    """`GENERIC`, 15 kg, carriable, "general props".

    The catalogue already has `prop_crate`, and `prop_crate` stays exactly
    what it is: DECORATION, painted end to end, with no handling language on
    it. This is the manipulable sibling -- same family of object, carrying
    the fittings that say a player can pick it up. Two candidates rather
    than one contradictory promise.

    Smaller than `prop_crate` on purpose. At 0.62 m it reads as the 15 kg
    §10.1 gives the class; a 1.0 m box reads as furniture.
    """
    size = 0.62
    body = [brushkit.block("gn_body", (size, size, size),
                           (0.0, 0.0, size / 2.0))]
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            body.append(brushkit.block(
                "gn_iron_%d_%d" % (int(sx), int(sy)), (0.06, 0.06, size),
                (sx * (size / 2.0 - 0.03), sy * (size / 2.0 - 0.03),
                 size / 2.0)))
    body.append(brushkit.block("gn_lid", (size * 1.04, size * 1.04, 0.05),
                               (0.0, 0.0, size - 0.02)))
    shell = common.join(body, "phys_generic")
    parts, attach = [], []
    # RECESSED hand grips on two opposite faces -- a crate you lift from the
    # sides, not a crate with a suitcase handle glued to the lid.
    for i, sy in enumerate((-1.0, 1.0)):
        py = sy * (size / 2.0 - 0.012)
        parts.append(_grip("grip_hand_%d" % i, (0.20, 0.05, 0.07),
                           (0.0, py, size * 0.66)))
        attach.append({"id": "grip_hand_%d" % i, "part": "grip_hand_%d" % i,
                       "at": (0.0, py, size * 0.66), "normal": (0.0, sy, 0.0),
                       "proposes": "a recessed hand grip; two of them, "
                                   "opposite, so the object is lifted "
                                   "square"})
    return shell, parts, attach


def movable_cover():
    """`MOVABLE_COVER`, 220 kg, NOT carriable, "sightlines, shields".

    It exists to be got behind, so it is TALLER THAN THE PLAYER'S EYE and
    wide enough to hide a body. Stiffened panel on a low sled: the sled says
    it slides rather than tips, and the stiffeners say it stops something.
    """
    w, d, h = 1.30, 0.26, 1.72
    body = [
        brushkit.block("mc_panel", (w, 0.09, h * 0.92), (0.0, 0.0, h * 0.50)),
        brushkit.block("mc_sled", (w * 1.02, d, 0.14), (0.0, 0.0, 0.07)),
        brushkit.block("mc_cap", (w * 0.98, 0.14, 0.08), (0.0, 0.0, h - 0.04)),
    ]
    for sx in (-1.0, 1.0):
        body.append(brushkit.block("mc_stile_%d" % int(sx),
                                   (0.10, 0.16, h * 0.94),
                                   (sx * (w / 2.0 - 0.05), 0.0, h * 0.50)))
    for i, z in enumerate((h * 0.30, h * 0.62)):
        body.append(brushkit.block("mc_rib_%d" % i, (w * 0.86, 0.14, 0.07),
                                   (0.0, 0.0, z)))
    shell = common.join(body, "phys_movable_cover")
    parts, attach = [], []
    for i, sy in enumerate((-1.0, 1.0)):
        py = sy * 0.088
        parts.append(_grip("attach_push_%d" % i, (0.34, 0.045, 0.20),
                           (0.0, py, h * 0.46)))
        attach.append({"id": "attach_push_%d" % i,
                       "part": "attach_push_%d" % i,
                       "at": (0.0, py + sy * 0.022, h * 0.46),
                       "normal": (0.0, sy, 0.0),
                       "proposes": "a push face on each side, so cover can "
                                   "be moved from behind it as well as "
                                   "from in front"})
    return shell, parts, attach


def cart():
    """`CART`, 180 kg, NOT carriable, "constrained to floor path or rail".

    The constraint is the whole design and it has to be visible standing
    still: four wheels in fixed forks -- no castors, so it runs on ONE axis
    -- and a rail shoe under the deck. A player should be able to see which
    way it will go before touching it.
    """
    w, d, h = 1.36, 0.68, 0.78
    deck = 0.46
    body = [
        brushkit.block("ct_deck", (w, d, 0.09), (0.0, 0.0, deck)),
        brushkit.block("ct_chassis", (w * 0.88, d * 0.60, 0.10),
                       (0.0, 0.0, deck - 0.09)),
        brushkit.block("ct_shoe", (w * 0.40, 0.16, 0.08), (0.0, 0.0, 0.16)),
        brushkit.block("ct_bar_post_l", (0.07, 0.07, h - deck),
                       (-w / 2.0 + 0.10, -d * 0.30, deck + (h - deck) / 2.0)),
        brushkit.block("ct_bar_post_r", (0.07, 0.07, h - deck),
                       (-w / 2.0 + 0.10, d * 0.30, deck + (h - deck) / 2.0)),
    ]
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            body.append(brushkit.prism(
                "ct_wheel_%d_%d" % (int(sx), int(sy)), 0.16, 0.10, 8,
                (sx * (w / 2.0 - 0.22), sy * (d / 2.0 - 0.06), 0.16),
                asset_name="phys_cart"))
            body.append(brushkit.block(
                "ct_fork_%d_%d" % (int(sx), int(sy)), (0.06, 0.14, 0.30),
                (sx * (w / 2.0 - 0.22), sy * (d / 2.0 - 0.06), 0.30)))
    shell = common.join(body, "phys_cart")
    parts = [
        _grip("grip_bar", (0.07, d * 0.72, 0.07),
              (-w / 2.0 + 0.10, 0.0, h - 0.035)),
    ]
    attach = [{"id": "grip_bar", "part": "grip_bar",
               "at": (-w / 2.0 + 0.10, 0.0, h - 0.035),
               "normal": (-1.0, 0.0, 0.0),
               "proposes": "a push bar at one end only -- a cart has a "
                           "front, and the bar is where it is"}]
    return shell, parts, attach


def plate():
    """`PLATE`, 60 kg, NOT carriable, "flat; bridges, ramps, blast shields".

    Exactly on §10.3's 60 kg line and §10.1 puts it on the manipulate side,
    so it gets NO hand grip -- which is the single most informative thing
    about it. Lifting slots instead, and a chamfered leading edge so it
    reads as something that goes down across a gap rather than stands up.
    """
    w, d, t = 1.60, 0.92, 0.10
    body = [
        brushkit.block("pl_slab", (w, d, t), (0.0, 0.0, t / 2.0)),
        brushkit.wedge("pl_nose", (0.20, d, t),
                       (w / 2.0 + 0.10, 0.0, t / 2.0)),
    ]
    for sy in (-1.0, 1.0):
        body.append(brushkit.block("pl_rail_%d" % int(sy), (w, 0.07, 0.05),
                                   (0.0, sy * (d / 2.0 - 0.035), t + 0.02)))
    shell = common.join(body, "phys_plate")
    parts, attach = [], []
    for i, sx in enumerate((-1.0, 1.0)):
        px = sx * (w / 2.0 - 0.16)
        parts.append(_grip("attach_slot_%d" % i, (0.16, 0.24, 0.045),
                           (px, 0.0, t + 0.005)))
        attach.append({"id": "attach_slot_%d" % i,
                       "part": "attach_slot_%d" % i,
                       "at": (px, 0.0, t + 0.028), "normal": (0.0, 0.0, 1.0),
                       "proposes": "a lifting slot a device hooks into; two "
                                   "of them, so a flat object can be lifted "
                                   "level"})
    return shell, parts, attach


def drum():
    """`DRUM`, 70 kg, NOT carriable, "rolls; conveyors, ramps, momentum".

    `prop_oil_drum` stays decoration. This is its manipulable sibling: the
    same object class, given the fittings, and proportioned so the rolling
    axis is obvious -- wider than it is tall, with raised rolling bands at
    both ends so it tracks straight instead of wandering.
    """
    radius, length = 0.34, 0.96
    body = [
        brushkit.spin(brushkit.prism("dr_body", radius, length, 8,
                                     (0.0, 0.0, 0.0),
                                     asset_name="phys_drum"), "y", 90.0),
    ]
    for sx in (-1.0, 1.0):
        body.append(brushkit.spin(
            brushkit.prism("dr_band_%d" % int(sx), radius + 0.03, 0.09, 8,
                           (sx * (length / 2.0 - 0.10), 0.0, 0.0),
                           asset_name="phys_drum"), "y", 90.0))
    shell = common.join(body, "phys_drum")
    # Sit it on the ground: the prism was spun about its own centre.
    for vertex in shell.data.vertices:
        vertex.co.z += radius + 0.03
    parts, attach = [], []
    for i, sx in enumerate((-1.0, 1.0)):
        px = sx * (length / 2.0 + 0.012)
        parts.append(_grip("attach_hub_%d" % i, (0.045, 0.18, 0.18),
                           (px, 0.0, radius + 0.03)))
        attach.append({"id": "attach_hub_%d" % i,
                       "part": "attach_hub_%d" % i,
                       "at": (px + sx * 0.022, 0.0, radius + 0.03),
                       "normal": (sx, 0.0, 0.0),
                       "proposes": "an end hub on the rolling axis, so a "
                                   "device grabs the drum where turning it "
                                   "is free rather than where it fights"})
    return shell, parts, attach


def anchor_block():
    """`ANCHOR_BLOCK`, 500 kg, NOT carriable and NOT manipulable -- `FIXED`.

    §10.1: "a `FIXED` world attachment point that can be revealed or
    destroyed but never moved."

    IT MUST READ AS FIXED, and Design 2 §33.7 says `FIXED` objects visibly
    do NOT share the manipulable treatment. So it has none of the movable
    family's fittings: no hand grip, no push pad, no attach pad, nothing a
    device could take hold of to shift it. It is cast into a skirt that
    spreads onto the floor, it is wider at the bottom than the top, and it
    has no separable parts at all except one.
    
    That one is the point of the object: a bare TETHER EYE. The bare-metal
    rule is "unpainted steel where the player's device touches" -- and a
    device does touch an anchor block, just never to move it. So the eye is
    bare and everything else is cast, which is precisely the sentence the
    class needs: you attach TO this, you do not attach it to anything.
    """
    w, d, h = 0.76, 0.76, 0.62
    body = [
        brushkit.block("ab_skirt", (w * 1.30, d * 1.30, 0.09),
                       (0.0, 0.0, 0.045)),
        brushkit.block("ab_mass", (w, d, h * 0.62), (0.0, 0.0, h * 0.40)),
        brushkit.block("ab_crown", (w * 0.74, d * 0.74, h * 0.22),
                       (0.0, 0.0, h * 0.80)),
    ]
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            body.append(brushkit.wedge(
                "ab_fillet_%d_%d" % (int(sx), int(sy)), (0.16, 0.16, 0.16),
                (sx * (w / 2.0 - 0.02), sy * (d / 2.0 - 0.02), 0.13)))
    shell = common.join(body, "phys_anchor_block")
    parts = [
        _grip("attach_eye", (0.14, 0.14, 0.20), (0.0, 0.0, h * 0.95)),
    ]
    attach = [{"id": "attach_eye", "part": "attach_eye",
               "at": (0.0, 0.0, h * 1.05), "normal": (0.0, 0.0, 1.0),
               "proposes": "the tether eye. The ONLY fitting on the class, "
                           "and it is for attaching something TO the "
                           "anchor, never for moving the anchor"}]
    return shell, parts, attach


# ----------------------------------------------------------------------

#: The seam pitch each class wears, in metres, and the tone of its paint.
#:
#: TONE IS ALSO A READABILITY DECISION, NOT A MOOD ONE. The heavy classes
#: first wore the `dark` tone because heavy things look heavy dark -- and
#: that closed the gap against their own fittings to nothing. A body has to
#: stay well above the handling steel or the family rule stops working on
#: exactly the objects that carry the most fittings. Weight is carried by
#: proportion, banding and skirts instead, which is where it belongs.
#:
#: A fixed grid is the wrong answer for a family spanning 0.25 m to 3.2 m:
#: at 0.5 m a key component gets no seam at all and a girder gets six. So
#: each class names a pitch that divides its own longest axis into two to
#: four panels, and the small carried objects get no bolts, because a bolt
#: at 64 texels/m is 3 px and three of them on a 0.25 m face is a rash.
SKIN = {
    # 0.30 m on a 0.25 m object: at most one seam crosses any face, which
    # is the right answer for a hand-held component rather than a tuning
    # dodge. A 0.14 m pitch panelled it like a housing and the dark seam
    # lines dragged its measured body value to within 11 L* of its own
    # fittings -- the smallest object in the family, with the finest
    # fittings, needing the cleanest field.
    "phys_key_component": {"seam": 0.30, "wear": 0.05, "tone": "light",
                           "bolts": False},
    "phys_generic": {"seam": 0.31, "wear": 0.09, "tone": "light",
                     "bolts": False},
    "phys_power_cell": {"seam": 0.20, "wear": 0.07, "tone": "light",
                        "bolts": False},
    "phys_mechanical_part": {"seam": 0.24, "wear": 0.08, "tone": "light",
                             "bolts": True},
    "phys_plate": {"seam": 0.45, "wear": 0.10, "tone": "light", "bolts": True},
    "phys_drum": {"seam": 0.34, "wear": 0.10, "tone": "light", "bolts": False},
    "phys_girder": {"seam": 0.80, "wear": 0.09, "tone": "light",
                    "bolts": True},
    "phys_weighted": {"seam": 0.41, "wear": 0.12, "tone": "light",
                      "bolts": True},
    "phys_cart": {"seam": 0.45, "wear": 0.12, "tone": "light", "bolts": True},
    "phys_movable_cover": {"seam": 0.57, "wear": 0.12, "tone": "light",
                           "bolts": True},
    "phys_ballast": {"seam": 0.52, "wear": 0.13, "tone": "light",
                     "bolts": True},
    "phys_anchor_block": {"seam": 0.38, "wear": 0.08, "tone": "light",
                          "bolts": True},
}

CLASSES = [
    ("phys_key_component", "KEY_COMPONENT", 8.0, True, True, key_component,
     "floor"),
    ("phys_generic", "GENERIC", 15.0, True, True, generic, "floor"),
    ("phys_power_cell", "POWER_CELL", 40.0, True, True, power_cell, "floor"),
    ("phys_mechanical_part", "MECHANICAL_PART", 55.0, True, True,
     mechanical_part, "floor"),
    ("phys_girder", "GIRDER", 95.0, False, True, girder, "floor"),
    ("phys_plate", "PLATE", 60.0, False, True, plate, "floor"),
    ("phys_drum", "DRUM", 70.0, False, True, drum, "floor"),
    ("phys_weighted", "WEIGHTED", 140.0, False, True, weighted, "floor"),
    ("phys_cart", "CART", 180.0, False, True, cart, "floor"),
    ("phys_movable_cover", "MOVABLE_COVER", 220.0, False, True,
     movable_cover, "floor"),
    ("phys_anchor_block", "ANCHOR_BLOCK", 500.0, False, False, anchor_block,
     "floor"),
    ("phys_ballast", "BALLAST", 320.0, False, True, ballast, "floor"),
]


def mass_class(kg, manipulable):
    """Design 2 §10.2. Derived, never declared."""
    if not manipulable or kg >= 400.0:
        return "FIXED"
    if kg < 30.0:
        return "LIGHT"
    if kg < 120.0:
        return "MEDIUM"
    return "HEAVY"


def main():
    made = []
    for name, klass, kg, carriable, manipulable, build, anchor in CLASSES:
        common.reset_scene()
        shell, parts, attach = build()
        shift = common.set_origin_group([shell] + parts, anchor)
        common.uv_project_world(shell, DENSITY, propkit.PROP_SIZE)
        skin = SKIN[name]
        canvas = propkit.quiet_painted(THEME, name, seam_metres=skin["seam"],
                                       wear=skin["wear"], tone=skin["tone"],
                                       bolts=skin["bolts"])
        common.assign(shell, common.make_textured_material(
            name, canvas.to_blender("%s_t" % name),
            roughness=pal.roughness(THEME)))
        # Flat, not textured. A handling fitting is machined, and a
        # machined surface has no grain at 64 texels/m -- painting one on
        # would only add noise to the one region whose job is to be the
        # quiet dark shape in a speckled field.
        # Fully matte. Every bit of sheen a fitting picks up is value it
        # gains against the body it is supposed to sit under, and at 0.62 it
        # was still catching enough to close the gap on the objects whose
        # bodies are mostly recessed geometry in shadow.
        bare_mat = common.make_material("%s_grip" % name, HANDLING,
                                        roughness=0.95)
        for part in parts:
            common.uv_project_world(part, DENSITY, propkit.PROP_SIZE)
            common.assign(part, bare_mat)
        common.assert_parts_touch(shell, parts, name)
        entry = common.export_glb(shell, "%s/%s.glb" % (OUT, name), "prop",
                                  tier="prop", texture_size=propkit.PROP_SIZE,
                                  anchor=anchor, parts=parts)
        common.save_texture(canvas.to_blender("%s_save" % name),
                            "batch043/%s.png" % name)
        runtime_attach = []
        for point in attach:
            moved = _shifted(point["at"], shift)
            runtime_attach.append({
                "id": point["id"],
                "part": point["part"],
                "position": _to_runtime(moved),
                "normal": _to_runtime(point["normal"]),
                "proposes": point["proposes"],
                "authored_blender_z_up": [round(v, 5) for v in point["at"]],
            })
        # AUTHORING axes out of the exporter; converted once, here.
        rx, ry, rz = common.runtime_size(entry["size"])
        entry.update({
            "class": klass, "mass_kg": kg,
            "mass_class": mass_class(kg, manipulable),
            "carriable": carriable, "manipulable": manipulable,
            "coordinate_space": {
                "authoring": "Blender, Z-up, metres",
                "runtime": "glTF / Godot, Y-UP, metres -- what a loader sees",
                "conversion": "(x, y, z)_blender -> (x, z, -y)_runtime",
                "origin_shift_applied": "once, by set_origin_group, before "
                                        "the conversion",
                "note": "`size` is the EXPORTER's field and is in AUTHORING "
                        "axes, unchanged from every other batch. "
                        "`size_runtime_y_up` is the same object in the frame "
                        "a loader sees, converted once by "
                        "common.runtime_size(). They are not the same "
                        "triple and must not be read as one.",
            },
            "size_runtime_y_up": {"x": rx, "y_up": ry, "z": rz},
            "size_authoring_blender_z_up": {
                "x": entry["size"][0], "y": entry["size"][1],
                "z_up": entry["size"][2],
            },
            "orientation_runtime": "+X is the object's length, +Y is up, "
                                   "+Z is depth; the origin is %s"
                                   % ("floor-centred, on the ground plane"
                                      if anchor == "floor" else anchor),
            "material_roles": {"body": name, "handling": "%s_grip" % name},
            "attach_points": runtime_attach,
            "dimensions_are": "PROPOSED ART DIMENSIONS -- no runtime contract "
                              "for object size or attachment interfaces "
                              "exists; these are not one",
            "collision": "NONE. Not derived, not shipped, not evidence.",
        })
        made.append(entry)

    path = os.path.join(common.MODEL_DIR, OUT, "manifest.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        # Keyed by asset id, like every other batch manifest --
        # `check_docs_metrics.py` reads a manifest's keys AS asset ids.
        shared = {
            "batch": "043", "kind": "physics_props",
            "status": "PROPOSAL -- all twelve of Design 2 §10.1's classes",
            "design": "Design 2 §10.1 classes and masses, §10.2 derived mass "
                      "class, §10.3 the 60 kg carry limit, §33.7 the "
                      "manipulable treatment; pinned by Design 6 §4.7",
            "family_rule": "bare machined metal appears only on surfaces the "
                           "player's device touches; a hand grip means a hand "
                           "can lift it, and its absence on an object with "
                           "attach pads means a device has to",
            "texels_per_metre": DENSITY,
            "not_changed": ["player physics", "object mass rules",
                            "carry limits", "package schemas",
                            "any approved asset"],
        }
        keyed = {}
        for entry in made:
            asset_id = os.path.basename(entry["path"])[:-4]
            keyed[asset_id] = dict(shared, **entry)
        json.dump(keyed, handle, indent=2, sort_keys=True)
    common.log("manifest %s" % path)
    for entry in made:
        common.log("%-24s %-16s %6.1f kg  %s  %s"
                   % (entry["class"], entry["mass_class"], entry["mass_kg"],
                      "carriable" if entry["carriable"]
                      else ("manipulate" if entry["manipulable"] else "FIXED"),
                      "x".join("%.2f" % v for v in entry["size"])))


main()
