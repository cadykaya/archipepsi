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
#: The one colour the whole family shares. L* 18.6 against painted bodies at
#: L* 60-70, and low-chroma so it never reads as a signalling family.
HANDLING = "#252a31"
DENSITY = propkit.PROP_DENSITY


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
    attach = [{"id": "attach_socket", "at": [0.0, 0.0, 0.0],
               "normal": [0.0, 0.0, -1.0],
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
    attach = [{"id": "attach_key", "at": [0.0, -d / 2.0 - 0.05, h * 0.33],
               "normal": [0.0, -1.0, 0.0],
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
    parts = [
        _grip("grip_bar", (0.11, 0.035, 0.032), (0.0, 0.0, h + 0.034)),
        _grip("grip_post_l", (0.028, 0.035, 0.055), (-0.041, 0.0, h + 0.002)),
        _grip("grip_post_r", (0.028, 0.035, 0.055), (0.041, 0.0, h + 0.002)),
        # The key. Asymmetric on purpose: a symmetric bit would go in either
        # way round, and then it is a plug rather than a key.
        _grip("attach_bit", (0.055, 0.075, 0.075), (-0.028, 0.0, 0.038)),
        _grip("attach_bit_ward", (0.030, 0.075, 0.038), (0.030, 0.0, 0.030)),
    ]
    attach = [{"id": "attach_bit", "at": [0.0, 0.0, 0.0],
               "normal": [0.0, 0.0, -1.0],
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
        py = sy * (d / 2.0 + 0.020)
        parts.append(_grip("attach_push_%d" % i, (0.30, 0.045, 0.18),
                           (0.0, py, h * 0.52)))
        attach.append({"id": "attach_push_%d" % i,
                       "at": [0.0, py, h * 0.52], "normal": [0.0, sy, 0.0],
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
                       "at": [sx * length / 2.0, 0.0, 0.0],
                       "normal": [sx, 0.0, 0.0],
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
                       "at": [px, py, h * 0.55], "normal": [dx, dy, 0.0],
                       "proposes": "a device attach pad; four of them so the "
                                   "player is never on the wrong side"})
    return shell, parts, attach


# ----------------------------------------------------------------------

CLASSES = [
    ("phys_key_component", "KEY_COMPONENT", 8.0, True, True, key_component,
     "floor"),
    ("phys_power_cell", "POWER_CELL", 40.0, True, True, power_cell, "floor"),
    ("phys_mechanical_part", "MECHANICAL_PART", 55.0, True, True,
     mechanical_part, "floor"),
    ("phys_girder", "GIRDER", 95.0, False, True, girder, "floor"),
    ("phys_weighted", "WEIGHTED", 140.0, False, True, weighted, "floor"),
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
        common.set_origin_group([shell] + parts, anchor)
        common.uv_project_world(shell, DENSITY, propkit.PROP_SIZE)
        canvas = propkit.painted_metal(THEME, name, wear=0.22)
        common.assign(shell, common.make_textured_material(
            name, canvas.to_blender("%s_t" % name),
            roughness=pal.roughness(THEME)))
        # Flat, not textured. A handling fitting is machined, and a
        # machined surface has no grain at 64 texels/m -- painting one on
        # would only add noise to the one region whose job is to be the
        # quiet dark shape in a speckled field.
        bare_mat = common.make_material("%s_grip" % name, HANDLING,
                                        roughness=0.30)
        for part in parts:
            common.uv_project_world(part, DENSITY, propkit.PROP_SIZE)
            common.assign(part, bare_mat)
        entry = common.export_glb(shell, "%s/%s.glb" % (OUT, name), "prop",
                                  tier="prop", texture_size=propkit.PROP_SIZE,
                                  anchor=anchor, parts=parts)
        common.save_texture(canvas.to_blender("%s_save" % name),
                            "batch043/%s.png" % name)
        entry.update({
            "class": klass, "mass_kg": kg,
            "mass_class": mass_class(kg, manipulable),
            "carriable": carriable, "manipulable": manipulable,
            "orientation": "+X is the object's length; +Z is up; the origin "
                           "is %s" % ("floor-centred" if anchor == "floor"
                                      else anchor),
            "material_roles": {"body": name, "handling": "%s_grip" % name},
            "attach_points": attach,
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
            "status": "PROPOSAL -- six of Design 2 §10.1's twelve classes",
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
                      "carriable" if entry["carriable"] else "manipulate",
                      "x".join("%.2f" % v for v in entry["size"])))


main()
