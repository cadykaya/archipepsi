"""Batch 002 D -- the enemy family, expanded.

    .tools/blender/blender -b --python tools/blender/build_batch002_enemies.py

## What this is answering

The 001-R review kept all three archetypes and asked for the roster around
them:

> Expand the enemy family, but as ORIGINAL DESIGNS only. [...] Flying
> enemies are especially wanted because the grapple hook creates
> verticality.

and set the method: study what a classic FPS roster COVERS -- the jobs the
enemies do between them -- and then design Archipepsi's own animals to do
those jobs. So this file starts from the JOB, never from a remembered
picture. Each role below is written as a sentence about what it does to the
player, and the silhouette is derived from that sentence afterwards.

Nothing here is copied from any existing game's enemy. Where a job has an
obvious shape -- a thing that lobs indirect fire has a tube pointing up --
that shape is arrived at from the job.

## The ten jobs

The three the owner already has:

    MELEE      closes and commits. Punishes standing still in the open.
    RANGED     stationary, long reach. Punishes ignoring the room's edges.
    BRUTE      one per Zone, slow, enormous. Punishes fighting in a corner.

and the seven this batch proposes:

    SCUTTLER   knee-high, many, fast. Costs attention, not health -- its
               job is to be a second thing happening while you deal with a
               first.
    CHARGER    one long telegraphed straight-line rush. Punishes holding a
               lane; rewards stepping aside.
    BULWARK    frontal armour wider than its body. Cannot be fought from
               the front, so it teaches flanking and it makes the grapple
               a positioning tool rather than a movement toy.
    ARTILLERY  static, indirect, arcing fire into where you are standing.
               Denies ground. The only enemy that makes cover a mistake.
    BEACON     fragile, harmless alone, makes everything near it worse.
               Teaches target selection: the right answer is to kill the
               weakest thing on the field first.
    DRIFTER    a FLYER. Slow, high, lobs downward. Owns the ceiling, so
               the player has to look up and eventually grapple up.
    DIVER      a FLYER. Fast, small, intercepts. It contests the grapple
               ARC itself -- the moment you are committed to a swing and
               cannot steer is the moment it is designed to arrive.

## Reading them apart at 18 m

`ENEMY_AGGRO_RADIUS` is 18 m and a 1.6 m melee is 48 px there. Ten enemies
is a lot to tell apart in 48 px, so the silhouettes are allocated
deliberately, and no two share a governing shape:

    MELEE      mass ahead of the feet, upright
    RANGED     tall thin tripod, asymmetric equipment mass
    BRUTE      squat and enormous, wider than tall
    SCUTTLER   wide and LOW, under knee height, legs out sideways
    CHARGER    LONG and low, horizontal, head down and forward
    BULWARK    a walking SLAB -- flat, vertical, wider than its own body
    ARTILLERY  a squat base with one long tube pointing UP
    BEACON     a thin MAST with a broad head, nothing else
    DRIFTER    a horizontal DISC with a hanging tail, no legs, high up
    DIVER      a narrow forward DART, swept back, no vertical mass

Six of the ten never touch the ground plane the same way, which does more
for reading them apart than any amount of surface detail.

## Collision boxes are a PROPOSAL

`enemy.gd` defines exactly three sizes. Everything past the trio is an art
proposal with no engine counterpart, so its box is declared here, marked as
proposed, and listed in ART_FRONTIER as an interface item. This file never
pretends a number is engineering's when it is not.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import build_concept_enemy as trio  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"

#: PROPOSED collision boxes, in Blender order (x, y, z) = (width, depth,
#: height). Engineering has agreed none of these; see the module docstring.
#: They are sized against the three real boxes so the proposal is at least
#: internally consistent: nothing is smaller than half a melee on a side and
#: nothing is larger than the brute.
PROPOSED = {
    "scuttler": (1.30, 1.20, 0.62),
    "charger": (0.90, 1.90, 1.05),
    "bulwark": (1.45, 0.85, 2.05),
    "artillery": (1.25, 1.25, 1.55),
    "beacon": (0.62, 0.62, 2.20),
    "drifter": (1.35, 1.35, 0.95),
    "diver": (0.70, 1.20, 0.50),
}

#: The two flyers do not stand on anything, so their model is anchored at
#: its own centre and the height engineering would hover them at is stated
#: rather than baked into the mesh.
HOVER = {"drifter": 2.55, "diver": 1.90}


def _eye(name, saturation=0.45):
    """One lit optic, in Epsilon's green, solved so it survives being lit."""
    # 0.45, down from the 0.9-plus this was authored at.
    # `make_signal_material` solves so the AUTHORED sum stays under 1.0; the
    # renderer then tonemaps and sRGB-encodes on top of that, which lifts
    # everything. A five-bar sweep through the review bench put the clip
    # point between 0.40 and 0.60: above it the green channel pins at 255
    # and the hue walks toward yellow, which is the TELEGRAPH colour. A
    # green cue that renders orange inverts the rule the whole palette is
    # built on. See build_epsilon_installation.py for the sweep.
    return common.make_signal_material(name, pal.universal("identity", 0),
                                       pal.universal("identity", 3),
                                       saturation=saturation)


# ----------------------------------------------------------------------
# the seven
# ----------------------------------------------------------------------

def scuttler():
    """SCUTTLER -- costs attention. Wide, LOW, legs out sideways.

    The whole design is one constraint: it has to be unmistakable in
    peripheral vision while the player is looking at something else. So it
    lives entirely below knee height, where nothing else in the roster is,
    and its legs come out SIDEWAYS rather than down -- a low body with a
    wide leg span reads as an insect footprint at any distance, and it is
    the only footprint in the family.
    """
    box = PROPOSED["scuttler"]
    h = box[2]
    parts = [
        brushkit.prism("sc_body", 0.26, 0.20, 8, (0.0, 0.0, h * 0.52),
                       top_radius=0.19, asset_name="scuttler", organic=True),
        # A carapace plate over the back, canted forward -- the thing you
        # actually see from above, which is where the player sees it from.
        brushkit.wedge("sc_shell", (0.46, 0.40, 0.16), (0.0, 0.02, h * 0.74),
                       axis="y"),
        brushkit.wedge("sc_head", (0.20, 0.22, 0.13), (0.0, -0.24, h * 0.50),
                       axis="y", rotation_z=180.0),
    ]
    # Three legs a side, splayed. Uneven lengths so the stance is not a
    # machine's: the front pair reaches furthest forward.
    for side in (-1.0, 1.0):
        for j, (dy, reach, drop) in enumerate(((-0.16, 0.40, 0.30),
                                               (0.04, 0.36, 0.26),
                                               (0.20, 0.30, 0.22))):
            femur = brushkit.block("sc_femur_%d_%d" % (int(side), j),
                                   (reach, 0.07, 0.07),
                                   (side * (0.16 + reach * 0.5), dy,
                                    h * 0.55))
            parts.append(brushkit.spin(femur, "Y", side * -22.0))
            parts.append(brushkit.block(
                "sc_tibia_%d_%d" % (int(side), j), (0.07, 0.07, drop),
                (side * (0.16 + reach), dy, drop * 0.5)))
    optic = brushkit.block("sc_optic", (0.13, 0.04, 0.035),
                           (0.0, -0.33, h * 0.52))
    vein = brushkit.block("sc_vein", (0.05, 0.30, 0.04), (0.0, 0.0, h * 0.83))
    return parts, [optic, vein], box, "scuttler"


def charger():
    """CHARGER -- one telegraphed straight line. LONG and low, head down.

    A rush is only fair if the player can see it coming and see where it is
    going, so the body is a horizontal arrow: 1.9 m of length against 1.05 m
    of height, the head carried below the shoulder line, and the mass
    stacked toward the front. There is nothing vertical on it at all -- at
    18 m the family's only horizontal reading is this one.
    """
    box = PROPOSED["charger"]
    h = box[2]
    parts = [
        # Shoulder mass at the front, tapering back to a light hindquarter.
        brushkit.prism("ch_chest", 0.34, 0.62, 10, (0.0, -0.34, h * 0.62),
                       top_radius=0.22, asset_name="charger", organic=True,
                       rotation_z=0.0),
        brushkit.prism("ch_barrel", 0.24, 0.70, 10, (0.0, 0.34, h * 0.58),
                       top_radius=0.17, asset_name="charger", organic=True),
        # The ram: a wedge carried low and forward. This is the part that
        # arrives, and it is the heaviest form on the animal.
        # The ram, and the shoulders behind it. A long low animal is
        # foreshortened to nothing from the front -- and the front is the
        # only view a charge ever gives you -- so what has to read at 18 m
        # is WIDE AND LOW with a braced face, not the profile.
        brushkit.wedge("ch_ram", (0.72, 0.46, 0.42), (0.0, -0.70, h * 0.34),
                       axis="y", rotation_z=180.0),
        brushkit.wedge("ch_crest", (0.34, 0.36, 0.22), (0.0, -0.44, h * 0.86),
                       axis="y"),
    ]
    for side in (-1.0, 1.0):
        parts.append(brushkit.wedge("ch_shoulder_%d" % int(side),
                                    (0.26, 0.44, 0.40),
                                    (side * 0.30, -0.30, h * 0.60),
                                    axis="y", rotation_z=180.0))
    for part in parts[:2]:
        brushkit.spin(part, "X", 90.0)
    for side in (-1.0, 1.0):
        # Four short legs, the front pair braced further forward than the
        # rear -- a stance that is already leaning into the run.
        for j, (dy, drop, lean) in enumerate(((-0.42, h * 0.40, -14.0),
                                              (0.36, h * 0.44, 9.0))):
            leg = brushkit.block("ch_leg_%d_%d" % (int(side), j),
                                 (0.14, 0.16, drop),
                                 (side * 0.26, dy, drop * 0.5))
            parts.append(brushkit.spin(leg, "X", lean))
    optic = brushkit.block("ch_optic", (0.05, 0.05, 0.16),
                           (0.0, -0.62, h * 0.60))
    vein = brushkit.block("ch_vein", (0.05, 1.10, 0.05), (0.0, 0.0, h * 0.84))
    return parts, [optic, vein], box, "charger"


def bulwark():
    """BULWARK -- cannot be fought from the front. A walking SLAB.

    The plate is 1.45 m across on a body 0.85 m deep, which makes it wider
    than anything else at eye level and makes the flat face the whole
    silhouette. The legs are set BEHIND the plate so that from the front you
    see armour and nothing else, and from the side you see how thin the
    thing actually is -- the shape itself tells the player where to go.
    """
    box = PROPOSED["bulwark"]
    h = box[2]
    parts = [
        # The plate. One piece, deliberately flat and deliberately boring:
        # its job is to be a wall, and a wall with detail on it reads as a
        # body.
        brushkit.block("bw_plate", (box[0], 0.16, h * 0.74),
                       (0.0, -0.30, h * 0.52)),
        brushkit.block("bw_plate_rim", (box[0], 0.10, 0.10),
                       (0.0, -0.36, h * 0.89)),
        # Two ribs bracing the plate back to the body, visible only in
        # profile.
        brushkit.wedge("bw_brace_l", (0.12, 0.34, h * 0.40),
                       (-0.40, -0.10, h * 0.44), axis="x"),
        brushkit.wedge("bw_brace_r", (0.12, 0.34, h * 0.40),
                       (0.40, -0.10, h * 0.44), axis="x"),
        brushkit.prism("bw_body", 0.28, h * 0.46, 10, (0.0, 0.14, h * 0.55),
                       top_radius=0.22, asset_name="bulwark", organic=True),
        # The head is BEHIND and ABOVE the plate: the one thing a flanker
        # can see, and the one thing worth shooting.
        brushkit.prism("bw_head", 0.17, 0.24, 10, (0.0, 0.12, h * 0.88),
                       top_radius=0.12, asset_name="bulwark", organic=True),
    ]
    for side in (-1.0, 1.0):
        parts.append(brushkit.prism("bw_thigh_%d" % int(side), 0.13, h * 0.32,
                                    10, (side * 0.22, 0.18, h * 0.30),
                                    top_radius=0.10, asset_name="bulwark",
                                    organic=True))
        parts.append(brushkit.prism("bw_shin_%d" % int(side), 0.09, h * 0.16,
                                    10, (side * 0.22, 0.14, h * 0.08),
                                    top_radius=0.12, asset_name="bulwark",
                                    organic=True))
    # The optic is on the HEAD, behind the plate, so the green cue itself
    # says "this is the side that can be hurt".
    optic = brushkit.block("bw_optic", (0.15, 0.05, 0.04),
                           (0.0, 0.24, h * 0.89))
    # A seam down the plate's centre. It is the only thing on the front, and
    # it is a line rather than a shape so the plate stays flat.
    vein = brushkit.block("bw_vein", (0.05, 0.05, h * 0.60),
                          (0.0, -0.39, h * 0.52))
    return parts, [optic, vein], box, "bulwark"


def artillery():
    """ARTILLERY -- indirect fire onto where you are standing. Tube UP.

    Static, like the ranged archetype, and distinguished from it by pointing
    at the CEILING. A weapon aimed at the sky is the clearest possible
    statement that its shot is going to come down somewhere else, and it is
    the only upward-pointing form in the roster. The base is squat and
    braced because the thing has to look like it does not need to move.
    """
    box = PROPOSED["artillery"]
    h = box[2]
    parts = [
        # Base and turret are kept SMALL. The first version had a 0.46 m
        # base under a short tube and read as a lumpy cone -- the one thing
        # the role needs is a long barrel against the sky, and a barrel is
        # only long relative to what it sits on.
        brushkit.prism("ar_base", 0.34, h * 0.26, 8, (0.0, 0.0, h * 0.13),
                       top_radius=0.28, asset_name="artillery", organic=True),
        brushkit.prism("ar_turret", 0.25, h * 0.20, 8, (0.0, 0.0, h * 0.36),
                       top_radius=0.22, asset_name="artillery", organic=True),
    ]
    # Three braced feet, splayed, so the base reads as planted.
    for j in range(3):
        foot = brushkit.wedge("ar_foot_%d" % j, (0.20, 0.52, 0.20),
                              (0.0, 0.0, 0.10), axis="y",
                              rotation_z=120.0 * j)
        parts.append(foot)
    # The tube. Long, canted back, and thick enough to read as a bore rather
    # than as an antenna -- the beacon already owns thin verticals.
    tube = brushkit.prism("ar_tube", 0.13, h * 0.70, 8,
                          (0.0, 0.12, h * 0.62), top_radius=0.15,
                          asset_name="artillery", organic=False)
    parts.append(brushkit.spin(tube, "X", -20.0))
    parts.append(brushkit.block("ar_collar", (0.30, 0.30, 0.11),
                                (0.0, 0.06, h * 0.44)))
    optic = brushkit.block("ar_optic", (0.13, 0.04, 0.035),
                           (0.0, -0.27, h * 0.38))
    # The bore mouth glows: the thing you want to see is where the shot
    # comes from.
    vein = brushkit.block("ar_mouth", (0.15, 0.15, 0.05),
                          (0.0, 0.34, h * 0.92))
    return parts, [optic, vein], box, "artillery"


def beacon():
    """BEACON -- makes everything near it worse. A thin MAST, broad head.

    It has to be recognisable at a glance and obviously fragile, because the
    lesson it teaches is "shoot the weak one first" and a lesson the player
    cannot see is not a lesson. So: nothing but a stalk and a head. It is
    the thinnest thing in the roster and the only one with no mass at chest
    height at all, which is what makes it read even in a crowd.
    """
    box = PROPOSED["beacon"]
    h = box[2]
    parts = [
        brushkit.prism("bc_foot", 0.24, 0.16, 8, (0.0, 0.0, 0.08),
                       top_radius=0.14, asset_name="beacon", organic=True),
        brushkit.prism("bc_mast", 0.07, h * 0.66, 8, (0.0, 0.0, h * 0.46),
                       top_radius=0.06, asset_name="beacon", organic=True),
        # The head: a broad shallow dish, the widest thing on the model and
        # the only wide thing above 1.8 m anywhere in the family.
        brushkit.prism("bc_head", 0.30, 0.14, 10, (0.0, 0.0, h * 0.86),
                       top_radius=0.20, asset_name="beacon", organic=True),
    ]
    # Three thin stays from the head back down to the foot. They make the
    # mast read as strung rather than solid, which is the fragility cue.
    for j, ang in enumerate((0.0, 120.0, 240.0)):
        stay = brushkit.block("bc_stay_%d" % j, (0.04, 0.04, h * 0.56),
                              (0.0, 0.19, h * 0.52), rotation_z=ang)
        parts.append(brushkit.spin(stay, "X", 9.0))
    optic = brushkit.block("bc_optic", (0.10, 0.04, 0.03),
                           (0.0, -0.20, h * 0.80))
    # The emitter itself, on top, facing up: what it is doing to the room.
    vein = brushkit.block("bc_emitter", (0.22, 0.22, 0.05),
                          (0.0, 0.0, h * 0.95))
    return parts, [optic, vein], box, "beacon"


def drifter():
    """DRIFTER -- a FLYER that owns the ceiling. Horizontal DISC, hanging tail.

    The grapple makes verticality a mechanic and this is the enemy that
    makes the player use it. Everything about the shape says "not standing
    on anything": a broad horizontal mantle with no legs under it, and a
    tail hanging straight down, which is a shape gravity could not hold up.
    Seen from directly below -- which is where the player first sees it --
    it is a disc, and nothing else in the roster is a disc.

    Anchored at its CENTRE, not the floor. See `HOVER`.
    """
    box = PROPOSED["drifter"]
    parts = [
        # The mantle: wide, shallow, slightly domed by stacking two prisms.
        brushkit.prism("dr_mantle", 0.62, 0.22, 10, (0.0, 0.0, 0.06),
                       top_radius=0.46, asset_name="drifter", organic=True),
        brushkit.prism("dr_dome", 0.44, 0.16, 10, (0.0, 0.0, 0.22),
                       top_radius=0.24, asset_name="drifter", organic=True),
        brushkit.prism("dr_gut", 0.30, 0.18, 10, (0.0, 0.0, -0.12),
                       top_radius=0.20, asset_name="drifter", organic=True),
    ]
    # Tendrils hanging straight down at uneven lengths. Uneven matters: an
    # even fringe reads as manufactured, and this is the half of the family
    # that is not.
    for j, (ang, ln) in enumerate(((20.0, 0.34), (95.0, 0.24), (168.0, 0.30),
                                   (238.0, 0.19), (305.0, 0.27))):
        parts.append(brushkit.block("dr_tendril_%d" % j, (0.05, 0.05, ln),
                                    (0.0, 0.30, -0.20 - ln * 0.5),
                                    rotation_z=ang))
    # Two fins on the mantle rim, so it is not radially symmetric and the
    # player can tell which way it is facing.
    for side in (-1.0, 1.0):
        fin = brushkit.wedge("dr_fin_%d" % int(side), (0.14, 0.34, 0.20),
                             (side * 0.52, 0.10, 0.10), axis="y")
        parts.append(brushkit.spin(fin, "Y", side * 26.0))
    optic = brushkit.block("dr_optic", (0.05, 0.05, 0.16), (0.0, 0.0, -0.20))
    vein = brushkit.block("dr_ring", (0.90, 0.05, 0.05), (0.0, 0.0, -0.02))
    return parts, [optic, vein], box, "drifter"


def diver():
    """DIVER -- a FLYER that contests the grapple ARC. A narrow DART.

    A swing is a commitment: for most of it the player cannot steer and
    cannot stop. This is the enemy designed to arrive during one, so it has
    to be readable while the camera is moving fast, which means the
    silhouette has to survive motion: one long axis, swept back, no vertical
    mass at all. It is the smallest thing in the roster and the only one
    whose depth is more than twice its width.

    Anchored at its CENTRE, not the floor. See `HOVER`.
    """
    box = PROPOSED["diver"]
    parts = [
        brushkit.prism("dv_body", 0.14, 0.72, 8, (0.0, 0.0, 0.0),
                       top_radius=0.05, asset_name="diver", organic=True),
    ]
    brushkit.spin(parts[0], "X", 90.0)
    # The point, ahead of the body.
    tip = brushkit.wedge("dv_tip", (0.14, 0.30, 0.12), (0.0, -0.50, 0.0),
                         axis="y", rotation_z=180.0)
    parts.append(tip)
    # Swept vanes, angled back hard. Two long, one short: asymmetry is what
    # keeps it from reading as a thrown object.
    for name, side, ln, sweep in (("dv_vane_l", -1.0, 0.40, 38.0),
                                  ("dv_vane_r", 1.0, 0.40, -38.0),
                                  ("dv_vane_t", 0.0, 0.24, 0.0)):
        vane = brushkit.wedge(name, (0.06, ln, 0.16),
                              (side * 0.16, 0.22, 0.02 if side else 0.14),
                              axis="y")
        parts.append(brushkit.spin(vane, "Z", sweep))
    optic = brushkit.block("dv_optic", (0.06, 0.05, 0.05), (0.0, -0.60, 0.0))
    vein = brushkit.block("dv_vein", (0.04, 0.50, 0.04), (0.0, 0.10, 0.09))
    return parts, [optic, vein], box, "diver"


CONCEPTS = [
    ("enemy_scuttler", scuttler),
    ("enemy_charger", charger),
    ("enemy_bulwark", bulwark),
    ("enemy_artillery", artillery),
    ("enemy_beacon", beacon),
    ("enemy_drifter", drifter),
    ("enemy_diver", diver),
]


def build_one(name, builder):
    parts, lit, box, kind = builder()
    body = common.join(parts, name + "_body")
    common.uv_project_world(body, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    common.assign(body, common.make_textured_material(
        name + "_body",
        propkit.enemy_skin(THEME, name).to_blender(name + "_body_tex"),
        roughness=pal.roughness(THEME)))
    glow = common.join(lit, name + "_glow")
    common.assign(glow, _eye(name + "_glow"))
    obj = common.join([body, glow], name)
    # A flyer has no floor contact, so anchoring it at one would bake a
    # hover height into the mesh that engineering never agreed to.
    common.set_origin(obj, "centre" if kind in HOVER else "floor")
    common.assert_fits(obj, name, box,
                       "'%s' is a PROPOSED %.2f x %.2f x %.2f m box. It has "
                       "no counterpart in enemy.gd yet, and a concept that "
                       "does not fit its own proposal is not a proposal."
                       % (kind, box[0], box[1], box[2]))
    size = common.measure(obj)
    if kind not in HOVER:
        fill = size[2] / box[2]
        if fill < 0.80:
            raise AssertionError(
                "%s fills only %.0f%% of its %.2f m proposed height. Below "
                "80%% the player shoots at empty air and still hits."
                % (name, fill * 100, box[2]))
    return common.export_glb(obj, "batch002/enemy/%s.glb" % name,
                             "enemy", check_flat=False)


def main():
    common.reset_scene()
    report = {}
    for name, builder in CONCEPTS:
        report[name] = build_one(name, builder)
        if builder.__name__ in HOVER:
            report[name]["proposed_hover_height_m"] = HOVER[builder.__name__]
        report[name]["proposed_box_m"] = list(PROPOSED[builder.__name__])
        report[name]["engine_box"] = False
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch002",
                       "enemy", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    # The trio is NOT rebuilt here. It is the owner's approved silhouette
    # logic and this batch does not touch it; `trio` is imported only so the
    # family sheet can name the same three builders the batch001 manifest
    # was built from.
    common.log("family: %d proposed roles + %d approved archetypes"
               % (len(CONCEPTS), len(trio.CONCEPTS)))


if __name__ == "__main__":
    main()
