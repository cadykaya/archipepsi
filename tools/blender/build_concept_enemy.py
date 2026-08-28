"""Batch 001-R D -- the three enemy archetypes.

    .tools/blender/blender -b --python tools/blender/build_concept_enemy.py

## What the Batch 001 review changed

The three melee concepts were reinterpreted rather than judged against each
other. The review: *"This batch appears to have accidentally found a useful
family"* --

    A STOOPED  ->  MELEE
    B TRIPOD   ->  RANGED
    C SQUAT    ->  BRUTE

so none is discarded, and each is now built to **its own archetype's real
collision box**, which is the part that changes the models rather than the
labels:

    melee    0.8 x 1.6 x 0.8   24 hp   reach 2.0 m   speed 4.0
    ranged   0.7 x 1.4 x 0.7   16 hp   reach 40 m    speed 0.0  -- stationary
    brute    1.8 x 2.6 x 1.8  120 hp   reach 2.5 m   speed 2.2  -- one per Zone

The brute is the real work: it more than doubles on every axis, which is a
rebuild at brute proportions rather than a scale of the squat concept.

## One family, three silhouettes

They have to read as Epsilon's ecosystem rather than as the facility's
machinery, and as completely different threats. The shared cues are
deliberately few, so the silhouettes stay far apart:

* the same dark `grime` plating, which sits below every theme's wall in
  value -- an enemy never wears the room's colours
* **a green optic.** Green is Epsilon's colour, so a green eye says *this
  belongs to the thing in the Hub*. That is the family membership card.
* a green seam or vein somewhere on the body, in the same
  light-from-inside language as Epsilon's own shell

**Hazard orange is deliberately absent, and that is a rule rather than an
omission.** Green says *whose this is*; orange says *what is about to
happen*. Reserving orange for telegraphs means the windup is the only orange
thing an enemy ever shows, which is worth far more than orange trim. See
`ART_BIBLE.md`.

## The number that decides all three

`derive_budgets.py` section 7: these are first seen at
`ENEMY_AGGRO_RADIUS`, 18 m, where a 1.6 m melee is **48 px** on a 1080p
screen. Every shot is taken there, and `tools/enemy_lineup.sh` puts all
three in one frame at that range -- because the review asked to see them
together, and three silhouettes that each work alone can still be
indistinguishable side by side.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import propkit  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"
#: (x, y, z) collision boxes, read from enemy.gd through engine_truth.
def _box(kind):
    w, h, d = common.DIM["enemy_%s_size" % kind]
    return (w, d, h)


MELEE, RANGED, BRUTE = _box("melee"), _box("ranged"), _box("brute")


def _eye(name, saturation=0.95):
    """The one lit cue on the figure, built so its colour survives.

    See `common.make_signal_material`: bright albedo plus bright emission
    clipped to white on the first render, and a white eye is a cue that has
    lost the only information it carries.
    """
    return common.make_signal_material(name, pal.universal("identity", 0),
                                       pal.universal("identity", 3),
                                       saturation=saturation)


def melee_stooped():
    """MELEE -- forward commitment. 0.8 x 1.6 x 0.8 m.

    The whole mass sits ahead of the feet, so at 46 px it reads as something
    already coming at you. Working arms with terminal weight: the fists are
    the second-heaviest forms on the body, which is what a thing that hits
    you looks like at that size.
    """
    h = MELEE[2]
    parts = [
        brushkit.prism("ea_pelvis", 0.22, 0.28, 10, (0.0, 0.04, h * 0.34),
                       top_radius=0.17, asset_name="melee", organic=True),
        brushkit.prism("ea_spine", 0.16, 0.34, 10, (0.0, -0.02, h * 0.56),
                       top_radius=0.23, asset_name="melee", organic=True),
        brushkit.wedge("ea_yoke", (0.68, 0.36, 0.30), (0.0, -0.10, h * 0.76),
                       axis="y", rotation_z=180.0),
        brushkit.wedge("ea_cowl", (0.52, 0.30, 0.22), (0.0, -0.14, h * 0.885),
                       axis="y", rotation_z=180.0),
        brushkit.wedge("ea_back", (0.44, 0.26, 0.26), (0.0, 0.10, h * 0.70),
                       axis="y"),
        brushkit.prism("ea_head", 0.14, 0.19, 10, (0.0, -0.17, h * 0.86),
                       top_radius=0.10, asset_name="melee", organic=True),
    ]
    for side in (-1.0, 1.0):
        x = side * 0.28
        parts.append(brushkit.prism("ea_upper_%d" % int(side), 0.11, 0.44, 10,
                                    (x, -0.10, h * 0.66), top_radius=0.08,
                                    asset_name="melee", organic=True))
        parts.append(brushkit.prism("ea_fore_%d" % int(side), 0.07, 0.40, 10,
                                    (x, -0.15, h * 0.36), top_radius=0.10,
                                    asset_name="melee", organic=True))
        parts.append(brushkit.wedge("ea_fist_%d" % int(side),
                                    (0.21, 0.26, 0.22), (x, -0.17, h * 0.15),
                                    axis="y", rotation_z=180.0))
        parts.append(brushkit.prism("ea_thigh_%d" % int(side), 0.12, 0.36, 10,
                                    (side * 0.14, 0.05, h * 0.24),
                                    top_radius=0.09, asset_name="melee",
                                    organic=True))
        parts.append(brushkit.prism("ea_shin_%d" % int(side), 0.08, 0.28, 10,
                                    (side * 0.14, 0.03, h * 0.06),
                                    top_radius=0.11, asset_name="melee",
                                    organic=True))
    optic = brushkit.block("ea_optic", (0.19, 0.05, 0.045),
                           (0.0, -0.28, h * 0.87))
    vein = brushkit.block("ea_vein", (0.05, 0.05, 0.30), (0.0, -0.13, h * 0.56))
    return parts, [optic, vein], MELEE, "melee"


def ranged_tripod():
    """RANGED -- tall, thin, asymmetric equipment mass. 0.7 x 1.4 x 0.7 m.

    `ENEMY_STATS` gives ranged **speed 0.0** and reach 40 m: it does not
    close, ever. The silhouette has to say so before the player commits to a
    charge, so the read is a fixed emplacement -- three planted legs, a mast,
    and every gram of mass in one asymmetric weapon housing rather than in
    limbs that could carry it anywhere.

    It is also the shortest of the three at 1.4 m, which matters: the player
    scans for the tall thin thing and finds it is not tall at all.
    """
    h = RANGED[2]
    parts = [
        brushkit.prism("eb_mast", 0.075, h * 0.50, 10, (0.0, 0.0, h * 0.60),
                       top_radius=0.06, asset_name="ranged", organic=True),
        brushkit.block("eb_hub", (0.22, 0.22, 0.17), (0.0, 0.0, h * 0.34)),
        brushkit.wedge("eb_crest", (0.13, 0.22, 0.18), (0.0, -0.03, h * 0.90),
                       axis="y", rotation_z=180.0),
        brushkit.prism("eb_head", 0.10, 0.15, 10, (0.0, -0.04, h * 0.83),
                       top_radius=0.08, asset_name="ranged", organic=True),
    ]
    # Three legs, one forward: an even tripod reads as a camera stand.
    for i, (ax, ay) in enumerate(((-0.17, 0.12), (0.17, 0.12), (0.0, -0.19))):
        parts.append(brushkit.block("eb_hip_%d" % i, (0.10, 0.10, 0.13),
                                    (ax * 0.6, ay * 0.6, h * 0.30)))
        parts.append(brushkit.prism("eb_leg_%d" % i, 0.045, h * 0.34, 10,
                                    (ax, ay, h * 0.15), top_radius=0.035,
                                    asset_name="ranged", organic=True))
        parts.append(brushkit.block("eb_foot_%d" % i, (0.12, 0.14, 0.06),
                                    (ax, ay, 0.03)))
    # The weapon: all the mass, on one side only.
    parts.append(brushkit.spin(
        brushkit.prism("eb_shoulder", 0.11, 0.16, 10, (0.17, -0.02, h * 0.70),
                       asset_name="ranged", organic=True), "Y", 90.0))
    parts.append(brushkit.block("eb_housing", (0.17, 0.24, 0.30),
                                (0.24, -0.05, h * 0.62)))
    parts.append(brushkit.block("eb_barrel", (0.07, 0.34, 0.07),
                                (0.24, -0.22, h * 0.62)))
    parts.append(brushkit.block("eb_counter", (0.11, 0.13, 0.20),
                                (-0.19, 0.02, h * 0.66)))
    optic = brushkit.block("eb_optic", (0.13, 0.05, 0.05),
                           (0.0, -0.13, h * 0.84))
    muzzle = brushkit.block("eb_muzzle", (0.045, 0.05, 0.045),
                            (0.24, -0.38, h * 0.62))
    return parts, [optic, muzzle], RANGED, "ranged"


def brute_squat():
    """BRUTE -- broad, squat, one heavy central mass. 1.8 x 2.6 x 1.8 m.

    Not a scaled squat concept: at 2.6 m tall and 1.8 m across it is more
    than twice the melee on every axis, and a shape that reads as *creature*
    at 1.3 m reads as *building* at 2.6 unless the proportions change with
    it. So the mass moved down and out -- the chest is the widest thing on
    the figure and it sits low, on short thick legs, with the head sunk
    almost into it.

    `MAX_BRUTES_PER_ZONE` is 1 and `BRUTE_LANE` reserves 2.6 m, so this is
    the one thing in a Zone that the room has to be built around. It should
    look like it.
    """
    h = BRUTE[2]
    parts = [
        # A chest wider than it is tall, low on the figure.
        brushkit.prism("ec_chest", 0.74, h * 0.34, 10, (0.0, -0.04, h * 0.58),
                       top_radius=0.58, asset_name="brute", organic=True),
        brushkit.prism("ec_gut", 0.66, h * 0.20, 10, (0.0, 0.0, h * 0.32),
                       top_radius=0.76, asset_name="brute", organic=True),
        brushkit.prism("ec_hump", 0.52, h * 0.22, 10, (0.0, 0.16, h * 0.85),
                       top_radius=0.20, asset_name="brute", organic=True),
        # Shoulder slabs: the outline breaks at the widest point.
        brushkit.wedge("ec_pauldron_l", (0.44, 0.52, 0.34),
                       (-0.58, 0.02, h * 0.74), axis="y"),
        brushkit.wedge("ec_pauldron_r", (0.40, 0.48, 0.30),
                       (0.60, 0.04, h * 0.71), axis="y"),
        brushkit.prism("ec_head", 0.24, 0.30, 10, (0.0, -0.32, h * 0.79),
                       top_radius=0.17, asset_name="brute", organic=True),
    ]
    for side in (-1.0, 1.0):
        # Forelimbs planted ahead and outboard: the stance is the silhouette.
        parts.append(brushkit.spin(
            brushkit.prism("ec_arm_%d" % int(side), 0.22, h * 0.32, 10,
                           (side * 0.60, -0.24, h * 0.44), top_radius=0.18,
                           asset_name="brute", organic=True), "X", 22.0))
        parts.append(brushkit.prism("ec_fist_%d" % int(side), 0.26, 0.34, 10,
                                    (side * 0.60, -0.44, h * 0.13),
                                    top_radius=0.21, asset_name="brute",
                                    organic=True))
        parts.append(brushkit.prism("ec_leg_%d" % int(side), 0.23, h * 0.26, 10,
                                    (side * 0.34, 0.14, h * 0.14),
                                    top_radius=0.18, asset_name="brute",
                                    organic=True))
        parts.append(brushkit.block("ec_foot_%d" % int(side),
                                    (0.38, 0.46, 0.11),
                                    (side * 0.34, 0.10, 0.055)))
    optic = brushkit.block("ec_optic", (0.30, 0.06, 0.07),
                           (0.0, -0.52, h * 0.80))
    vent = brushkit.block("ec_vent", (0.52, 0.07, 0.09), (0.0, 0.30, h * 0.68))
    return parts, [optic, vent], BRUTE, "brute"


CONCEPTS = [
    ("enemy_melee_stooped", melee_stooped),
    ("enemy_ranged_tripod", ranged_tripod),
    ("enemy_brute_squat", brute_squat),
]


def build_one(name, builder):
    parts, lit, box, kind = builder()
    body = common.join(parts, name + "_body")
    common.uv_project_world(body, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    common.assign(body, common.make_textured_material(
        name + "_body",
        propkit.enemy_skin(THEME, name).to_blender(name + "_body_tex"),
        roughness=pal.roughness(THEME)))
    # Epsilon green, not hazard orange. Green says whose this is; orange is
    # reserved for the telegraph, so a windup is the only orange an enemy
    # ever shows.
    glow = common.join(lit, name + "_glow")
    common.assign(glow, _eye(name + "_glow"))
    obj = common.join([body, glow], name)
    common.set_origin(obj, "floor")
    common.assert_fits(obj, name, box,
                       "enemy.gd gives '%s' a %.1f x %.1f x %.1f m collision "
                       "box, and a model outside it clips walls the character "
                       "body never touches." % (kind, box[0], box[1], box[2]))
    # An archetype whose model is much shorter than its collider means shots
    # at head height pass visually above a thing they still register on.
    size = common.measure(obj)
    fill = size[2] / box[2]
    if fill < 0.80:
        raise AssertionError(
            "%s fills only %.0f%% of its %.1f m collision height. Below 80%% "
            "the player shoots at empty air and still hits, which reads as a "
            "bug rather than as a design." % (name, fill * 100, box[2]))
    return common.export_glb(obj, "batch001/enemy/%s.glb" % name,
                             "enemy", check_flat=False)


def main():
    common.reset_scene()
    report = {}
    for name, builder in CONCEPTS:
        report[name] = build_one(name, builder)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch001",
                       "enemy", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
