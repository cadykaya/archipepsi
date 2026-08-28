"""Batch 001 D -- three melee-enemy silhouette concepts.

    .tools/blender/blender -b --python tools/blender/build_concept_enemy.py

## The number this batch is really about

`derive_budgets.py` section 7: a melee enemy is 1.6 m tall, it is first seen
at `ENEMY_AGGRO_RADIUS` (18 m), and at that range it is **48 px tall on a
1080p screen.** Forty-eight pixels is the whole design problem. Everything
below is chosen to survive it, and every review shot of these three is taken
at 18 m -- never only at a portrait distance, which is the bench mario-3
built, believed, and sent to its owner as proof that a design worked at a
size nobody plays at.

## What "hostile and melee-oriented before texture detail" means here

Three silhouette cues, and each concept spends its budget on a different
one:

- **Forward commitment.** The mass leans toward you. Nothing in the
  architecture kit leans, so a lean reads as intent.
- **Terminal weight.** The heaviest part of the figure is at the end of a
  limb. That is what a thing that hits you looks like at 48 px.
- **A low, wide stance.** Reads as braced rather than as standing.

A ranged enemy would get the opposite of all three, which is how we will
know these are doing anything.

## The family question these are also asking

Archipepsi's enemies are not obviously organic and not obviously machines.
`ART_BIBLE.md` proposes a third family -- FABRICATED ORGANIC, built like
machinery that was told to be a creature -- and does not settle it. These
three probe it: A is nearly a machine, C is nearly a creature, B sits
between. The answer is the owner's.

`enemy.gd` gives melee a 0.8 x 1.6 x 0.8 m collision box. That is Godot's.
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
SIZE = common.DIM["enemy_melee_size"]          # 0.8 x 1.6 x 0.8
BOX = (SIZE[0], SIZE[2], SIZE[1])              # x, y, z


def _eye(name, saturation=0.95):
    """The one lit cue on the figure, built so its colour survives.

    See `common.make_signal_material`: bright albedo plus bright emission
    clipped to white on the first render, and a white eye is a cue that has
    lost the only information it carries.
    """
    return common.make_signal_material(name, pal.universal("hazard", 0),
                                       pal.universal("hazard", 3),
                                       saturation=saturation)


def concept_a_stooped():
    """A: STOOPED HAULER -- forward commitment.

    A heavy shoulder yoke carried ahead of the hips, head sunk between the
    shoulders, arms hanging past the knees. The whole mass is in front of
    the feet, which at 48 px reads as something already coming at you.
    Nearly a machine: every part is a plate or a drum.
    """
    h = SIZE[1]
    # Tapered prisms and wedges, NOT a stack of boxes. The first version of
    # this concept was seven axis-aligned rectangular prisms and it rendered
    # as exactly what ART_BIBLE.md names as the failure to avoid: a cube-man.
    # The lean it was built to have was invisible, because a stack of boxes
    # has no direction. Every mass below now changes cross-section along its
    # length, and no two faces of a form are the same width.
    parts = [
        brushkit.prism("ea_pelvis", 0.22, 0.28, 10, (0.0, 0.04, h * 0.34),
                       top_radius=0.17, asset_name="enemy_a", organic=True),
        brushkit.prism("ea_spine", 0.16, 0.34, 10, (0.0, -0.02, h * 0.56),
                       top_radius=0.23, asset_name="enemy_a", organic=True),
        # The yoke is the widest mass and it is AHEAD of the hips. The
        # offset plus the wedge is the concept: a shoulder line that is
        # already committed forward.
        brushkit.wedge("ea_yoke", (0.68, 0.36, 0.30), (0.0, -0.10, h * 0.76),
                       axis="y", rotation_z=180.0),
        brushkit.wedge("ea_cowl", (0.52, 0.30, 0.22), (0.0, -0.14, h * 0.885),
                       axis="y", rotation_z=180.0),
        brushkit.wedge("ea_back", (0.44, 0.26, 0.26), (0.0, 0.10, h * 0.70),
                       axis="y"),
    ]
    head = brushkit.prism("ea_head", 0.14, 0.19, 10, (0.0, -0.17, h * 0.86),
                          top_radius=0.10, asset_name="enemy_a", organic=True)
    parts.append(head)
    for side in (-1.0, 1.0):
        x = side * 0.28
        # A limb built from two radii is four cones. Each segment tapers the
        # other way from the one above it, which is what makes an arm read as
        # an arm rather than as a pipe.
        parts.append(brushkit.prism("ea_upper_%d" % int(side), 0.11, 0.44, 10,
                                    (x, -0.10, h * 0.66), top_radius=0.08,
                                    asset_name="enemy_a", organic=True))
        parts.append(brushkit.prism("ea_fore_%d" % int(side), 0.07, 0.40, 10,
                                    (x, -0.15, h * 0.36), top_radius=0.10,
                                    asset_name="enemy_a", organic=True))
        # Terminal weight: the fist is the second-heaviest form on the body,
        # and it is a wedge so it has a striking face.
        parts.append(brushkit.wedge("ea_fist_%d" % int(side),
                                    (0.21, 0.26, 0.22), (x, -0.17, h * 0.15),
                                    axis="y", rotation_z=180.0))
        parts.append(brushkit.prism("ea_thigh_%d" % int(side), 0.12, 0.36, 10,
                                    (side * 0.14, 0.05, h * 0.24),
                                    top_radius=0.09, asset_name="enemy_a",
                                    organic=True))
        parts.append(brushkit.prism("ea_shin_%d" % int(side), 0.08, 0.28, 10,
                                    (side * 0.14, 0.03, h * 0.06),
                                    top_radius=0.11, asset_name="enemy_a",
                                    organic=True))
    eye = brushkit.block("ea_eye", (0.19, 0.05, 0.045), (0.0, -0.28, h * 0.87))
    return parts, eye


def concept_b_tripod():
    """B: TRIPOD CUTTER -- terminal weight on a narrow frame.

    A thin vertical spine on three splayed legs, carrying one oversized
    cutting arm. Its bet is CONTRAST: almost nothing, and then one very
    heavy thing. At 48 px the frame nearly disappears and the arm does not,
    which is either the most legible read of the three or the most fragile.
    Between machine and creature: manufactured parts in an animal posture.
    """
    h = SIZE[1]
    parts = [
        brushkit.prism("eb_spine", 0.09, h * 0.52, 8, (0.0, 0.0, h * 0.58),
                       top_radius=0.07, asset_name="enemy_b", organic=True),
        brushkit.block("eb_hub", (0.26, 0.26, 0.20), (0.0, 0.0, h * 0.34)),
        brushkit.wedge("eb_crest", (0.16, 0.26, 0.22), (0.0, -0.04, h * 0.92),
                       axis="y", rotation_z=180.0),
    ]
    head = brushkit.block("eb_head", (0.22, 0.22, 0.16), (0.0, -0.04, h * 0.84))
    parts.append(head)
    # Three legs, one of them forward: an even tripod reads as a stand.
    for i, (ax, ay) in enumerate(((-0.20, 0.14), (0.20, 0.14), (0.0, -0.22))):
        parts.append(brushkit.block("eb_hip_%d" % i, (0.12, 0.12, 0.16),
                                    (ax * 0.6, ay * 0.6, h * 0.30)))
        leg = brushkit.block("eb_leg_%d" % i, (0.09, 0.09, 0.42),
                             (ax, ay, h * 0.14))
        parts.append(leg)
        parts.append(brushkit.block("eb_foot_%d" % i, (0.14, 0.16, 0.07),
                                    (ax, ay, 0.035)))
    # The arm: one shoulder drum, one heavy forearm, one blade. All the mass.
    parts.append(brushkit.prism("eb_shoulder", 0.15, 0.20, 8,
                                (0.22, -0.02, h * 0.72),
                                asset_name="enemy_b", organic=True))
    brushkit.spin(parts[-1], "Y", 90.0)
    parts.append(brushkit.block("eb_arm", (0.19, 0.21, 0.40),
                                (0.30, -0.06, h * 0.50)))
    parts.append(brushkit.wedge("eb_blade", (0.10, 0.44, 0.34),
                                (0.32, -0.14, h * 0.24), axis="y",
                                rotation_z=180.0))
    parts.append(brushkit.block("eb_counter", (0.14, 0.16, 0.24),
                                (-0.22, 0.02, h * 0.66)))
    eye = brushkit.block("eb_eye", (0.16, 0.05, 0.06), (0.0, -0.15, h * 0.85))
    return parts, eye


def concept_c_squat():
    """C: SQUAT BRAWLER -- a low, wide, braced stance.

    Almost no neck, a barrel chest wider than it is tall, short legs set
    outside the hips, two heavy forelimbs planted forward. Its bet is that
    at 48 px the FOOTPRINT is what reads, not the height -- a wide dark
    shape low in the frame, which is a different silhouette problem from the
    other two. Nearest to a creature: tapered volumes, no flat plates.
    """
    h = SIZE[1]
    parts = [
        brushkit.prism("ec_chest", 0.32, 0.46, 10, (0.0, -0.02, h * 0.55),
                       top_radius=0.26, asset_name="enemy_c", organic=True),
        brushkit.prism("ec_gut", 0.30, 0.26, 10, (0.0, 0.0, h * 0.30),
                       top_radius=0.33, asset_name="enemy_c", organic=True),
        # A tapered dorsal mass, not a wedge. As a wedge its flat top face
        # was fully exposed from behind and above and read as a broken fin
        # bolted on, rather than as part of the animal.
        brushkit.prism("ec_hump", 0.24, 0.22, 10, (0.0, 0.09, h * 0.74),
                       top_radius=0.11, asset_name="enemy_c", organic=True),
    ]
    head = brushkit.prism("ec_head", 0.15, 0.18, 10, (0.0, -0.16, h * 0.72),
                          top_radius=0.11, asset_name="enemy_c", organic=True)
    parts.append(head)
    for side in (-1.0, 1.0):
        # Forelimbs planted ahead: the pose is the silhouette.
        parts.append(brushkit.prism("ec_arm_%d" % int(side), 0.12, 0.42, 10,
                                    (side * 0.26, -0.14, h * 0.42),
                                    top_radius=0.10, asset_name="enemy_c",
                                    organic=True))
        brushkit.spin(parts[-1], "X", 26.0)
        parts.append(brushkit.prism("ec_hand_%d" % int(side), 0.14, 0.20, 10,
                                    (side * 0.26, -0.24, h * 0.16),
                                    top_radius=0.12, asset_name="enemy_c",
                                    organic=True))
        parts.append(brushkit.prism("ec_leg_%d" % int(side), 0.11, 0.34, 10,
                                    (side * 0.24, 0.06, h * 0.16),
                                    top_radius=0.09, asset_name="enemy_c",
                                    organic=True))
        parts.append(brushkit.block("ec_foot_%d" % int(side),
                                    (0.19, 0.24, 0.09),
                                    (side * 0.24, 0.03, 0.045)))
    eye = brushkit.block("ec_eye", (0.17, 0.05, 0.05), (0.0, -0.26, h * 0.73))
    return parts, eye


CONCEPTS = [
    ("enemy_melee_a_stooped", concept_a_stooped),
    ("enemy_melee_b_tripod", concept_b_tripod),
    ("enemy_melee_c_squat", concept_c_squat),
]


def build_one(name, builder):
    parts, eye = builder()
    body = common.join(parts, name + "_body")
    common.uv_project_world(body, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    common.assign(body, common.make_textured_material(
        name + "_body",
        propkit.enemy_skin(THEME, name).to_blender(name + "_body_tex"),
        roughness=pal.roughness(THEME)))
    # ONE lit cue per figure, and it is the widest lit thing on the body.
    # Which way an enemy faces is what the player reads before deciding
    # whether to swing, so nothing is allowed to compete with it.
    common.assign(eye, _eye(name + "_eye"))
    obj = common.join([body, eye], name)
    common.set_origin_floor_centre(obj)
    common.assert_fits(obj, name, BOX,
                       "enemy.gd gives melee a 0.8 x 1.6 x 0.8 m collision "
                       "box, and a model outside it clips walls the "
                       "character body never touches.")
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
