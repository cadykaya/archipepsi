"""Batch 001 E -- two grapple-anchor concepts.

    .tools/blender/blender -b --python tools/blender/build_concept_anchor.py

## The dimensions are Godot's and the art does not touch them

`affordance_features.gd` owns every number that matters here and this file
reads them rather than restating them:

    FOOTPRINT["grapple_anchor"] = half_width 0.7, half_depth 0.7, height 5.6
    CEILING_GAP = 0.5      -- the anchor plate hangs this far below the ceiling
    OUT_OF_JUMP_REACH = 2.1 -- the reward lip sits at least this high

The concepts change what the anchor LOOKS like. They do not change where it
is, how big its clearance is, or how far the player can reach -- and
`assert_fits` refuses anything that grows past the 1.4 x 1.4 m footprint,
which is exactly the guess `AUTHORED_CONTENT.md` names: a ledge that is
1.4 m in one Zone and 1.9 m in another has not added variety, it has made
the jump untrustworthy.

## "Readable quickly" has a number

The anchor hangs at 5.1 m (5.6 minus the ceiling gap) and the player is
looking up at it from the floor while moving at 7 m/s. It has to be
identified in about the time it takes to cross a corridor. Both concepts
therefore lead with the same two cues, in the same universal colours:

- a RING, because a ring is the only shape in the whole kit with a hole
  through it, so it is unambiguous in black at any size
- a `signal`-coloured collar, because that is the only colour in the game
  that ever means "you can use this"

What differs is where the mass is and which way it points.
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
FOOT = common.DIM["affordance_footprint"]["grapple_anchor"]
#: The whole fixture must live inside the footprint Godot reserves.
ANCHOR_BOX = (FOOT["half_width"] * 2.0, FOOT["half_depth"] * 2.0, None)


def _signal(name, step=3, saturation=0.95):
    return common.make_signal_material(name, pal.universal("signal", 0),
                                       pal.universal("signal", step),
                                       saturation=saturation)


def concept_a_soffit():
    """A: SOFFIT PLATE.

    A bolted plate flat against the ceiling with a ring hanging from a short
    shackle. Reads from directly underneath, which is where the player is
    when they use it, and reads as PART OF THE BUILDING -- so a room with
    six of them does not look like a room with six pieces of equipment in
    it. Its risk: from a distance, flat to the ceiling, there may be no
    silhouette at all.
    """
    parts = [
        brushkit.block("aa_plate", (1.10, 1.10, 0.14), (0.0, 0.0, -0.07)),
        brushkit.block("aa_boss", (0.46, 0.46, 0.22), (0.0, 0.0, -0.25)),
        brushkit.block("aa_shackle", (0.13, 0.30, 0.26), (0.0, 0.0, -0.47)),
    ]
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.append(brushkit.block(
                "aa_stud_%d_%d" % (int(sx), int(sy)), (0.14, 0.14, 0.12),
                (sx * 0.44, sy * 0.44, -0.20)))
    collar = brushkit.block("aa_collar", (0.50, 0.50, 0.06),
                            (0.0, 0.0, -0.36))
    ring = brushkit.tube("aa_ring", 0.30, 0.20, 0.10, 8, (0.0, 0.0, -0.72),
                         asset_name="anchor_a")
    brushkit.spin(ring, "X", 90.0)
    return parts, collar, ring


def concept_b_jib():
    """B: CANTILEVER JIB.

    A braced arm projecting sideways from a ceiling mount, with the eye at
    its tip. Its bet is HORIZONTAL EXTENSION: the arm breaks the ceiling
    line, so this one reads from across the room as well as from beneath it.
    Its risk: an off-centre eye is harder to aim at, and the arm eats more
    of the footprint than a plate does.
    """
    parts = [
        brushkit.block("ab_mount", (0.60, 0.60, 0.16), (0.0, 0.0, -0.08)),
        brushkit.block("ab_arm", (1.06, 0.20, 0.16), (0.14, 0.0, -0.24)),
        brushkit.wedge("ab_brace", (0.60, 0.16, 0.34), (-0.02, 0.0, -0.30),
                       axis="x", rotation_z=180.0),
        brushkit.block("ab_tip", (0.26, 0.26, 0.28), (0.52, 0.0, -0.36)),
    ]
    for sy in (-1.0, 1.0):
        parts.append(brushkit.block("ab_gusset_%d" % int(sy),
                                    (0.44, 0.06, 0.22),
                                    (0.0, sy * 0.11, -0.26)))
        parts.append(brushkit.block("ab_stud_%d" % int(sy),
                                    (0.13, 0.13, 0.11),
                                    (-0.20, sy * 0.20, -0.19)))
    collar = brushkit.block("ab_collar", (0.30, 0.30, 0.06),
                            (0.52, 0.0, -0.51))
    ring = brushkit.tube("ab_ring", 0.26, 0.17, 0.09, 8, (0.52, 0.0, -0.78),
                         asset_name="anchor_b")
    brushkit.spin(ring, "X", 90.0)
    return parts, collar, ring


CONCEPTS = [
    ("anchor_a_soffit", concept_a_soffit),
    ("anchor_b_jib", concept_b_jib),
]


def build_one(name, builder):
    parts, collar, ring = builder()
    body = common.join(parts, name + "_body")
    common.uv_project_world(body, propkit.PROP_DENSITY, propkit.PROP_SIZE)
    common.assign(body, common.make_textured_material(
        name + "_body",
        propkit.painted_metal(THEME, name, label="grp",
                              band=False).to_blender(name + "_body_tex"),
        roughness=pal.roughness(THEME)))
    common.assign(collar, _signal(name + "_collar", step=1, saturation=0.6))
    common.assign(ring, _signal(name + "_ring"))
    obj = common.join([body, collar, ring], name)
    # Anchored 'ceiling': the plate is at Z 0 and the ring hangs below,
    # so placing the asset at the ceiling height puts it exactly where
    # affordance_features.gd's CEILING_GAP expects it.
    common.set_origin(obj, "ceiling")
    common.assert_fits(obj, name, ANCHOR_BOX,
                       "affordance_features.gd reserves a %.1f x %.1f m "
                       "footprint for a grapple anchor."
                       % (ANCHOR_BOX[0], ANCHOR_BOX[1]))
    return common.export_glb(obj, "batch001/affordance/%s.glb" % name,
                             "interactable", check_flat=False,
                             anchor="ceiling")


def main():
    common.reset_scene()
    report = {}
    for name, builder in CONCEPTS:
        info = build_one(name, builder)
        # The mechanical facts, recorded beside the asset so a reviewer does
        # not have to go and find them: this fixture hangs from the ceiling,
        # it is not a floor object, and its origin is at its LOWEST point.
        info["hangs_from_ceiling"] = True
        info["plate_below_ceiling_m"] = 0.5
        info["clearance_height_m"] = FOOT["height"]
        report[name] = info
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch001",
                       "affordance", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
