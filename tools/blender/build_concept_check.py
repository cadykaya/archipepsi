"""Batch 001 B -- three Check-object concepts.

    .tools/blender/blender -b --python tools/blender/build_concept_check.py

The Check is the single most repeated moment in the game: thirty of them
across a campaign, and `AUTHORED_CONTENT.md` puts "Check object and reveal
presentation" at the top of the identity list. So three silhouettes are
offered and NONE is chosen here -- picking one is the owner's call.

## What all three must do, and how it is measured

**Read from across a room.** `derive_budgets.py` section 7: the Check's
collision box is 2.6 m tall, the largest arena diagonal is 39.6 m, and at
that range the object is **35 px** on a 1080p screen. That is the number
behind "reads as the same important object from across a room", and the
far-distance review shot is taken at exactly that range.

**Have a clear interaction face.** A separate material, a different value,
and a target the player can aim at -- see `propkit.hero_face`.

**Fit the mechanical box.** `reward.gd` gives the Check a 1.4 x 2.6 x 1.4 m
collision box with its centre at 1.3 m. That is Godot's and does not move
for a nicer proportion; `assert_fits` refuses anything that outgrows it.

## What differs

Only the silhouette, and deliberately only the silhouette. All three wear
the same shell paint, the same `signal` interaction face and the same `send`
destination ring, because a review that varied paint AND form would be
asking two questions and could answer neither.
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
#: reward.gd: BoxShape3D 1.4 x 2.6 x 1.4, centred at y 1.3.
CHECK_BOX = (1.4, 1.4, 2.6)


def _emissive(name, family):
    return common.make_signal_material(name, pal.universal(family, 0),
                                       pal.universal(family, 3))


def concept_a_pedestal():
    """A-R: SIGNAL MAST. Selected at the Batch 001 review, then revised.

    The review: *"A is decisively the strongest at actual room distance"*,
    with one note -- slightly more industrial / signal-device, slightly less
    magical-pedestal.

    What survives: the vertical emphasis and the beacon top. Those are what
    made it read at 39 px across a 40 m arena and the review named both as
    must-keeps.

    What changed: the lathe-turned octagonal plinth and the four radiating
    crown arms were the "magical pedestal" -- a shape from a different genre
    entirely. They are now a bolted box base with a conduit running out of
    it into the floor, and a caged emitter head. Same silhouette family,
    built by an industrial contractor instead of a wizard.
    """
    body = [
        # A bolted base, not a turned plinth.
        brushkit.block("cpa_base", (0.86, 0.86, 0.18), (0.0, 0.0, 0.09)),
        brushkit.block("cpa_riser", (0.62, 0.62, 0.30), (0.0, 0.0, 0.33)),
        brushkit.wedge("cpa_shoulder", (0.62, 0.62, 0.16), (0.0, 0.0, 0.56),
                       axis="y"),
        # The waist stays: it is the vertical emphasis the review kept.
        brushkit.block("cpa_waist", (0.24, 0.24, 0.70), (0.0, 0.0, 1.02)),
    ]
    # A conduit leaving the base: a signal device is wired to something.
    body.append(brushkit.block("cpa_conduit", (0.10, 0.44, 0.10),
                               (0.20, 0.34, 0.06), rotation_z=22.0))
    for side in (-1.0, 1.0):
        body.append(brushkit.block("cpa_stay_%d" % int(side),
                                   (0.07, 0.07, 0.52),
                                   (side * 0.20, 0.0, 0.78)))
        for i in range(2):
            body.append(brushkit.block("cpa_stud_%d_%d" % (int(side), i),
                                       (0.10, 0.10, 0.09),
                                       (side * 0.36, 0.0, 0.20 + i * 0.24)))
    # A caged emitter head, not a crown.
    body.append(brushkit.block("cpa_head", (0.56, 0.56, 0.26), (0.0, 0.0, 1.50)))
    body.append(brushkit.block("cpa_hood", (0.64, 0.64, 0.10), (0.0, 0.0, 1.68)))
    for i in range(4):
        angle = 45.0 + i * 90.0
        body.append(brushkit.block("cpa_cage_%d" % i, (0.05, 0.05, 0.42),
                                   (0.0, 0.0, 1.94), rotation_z=angle))
        body[-1].location = (0.0, 0.0, 0.0)
    # Cage uprights placed on a square, so the lamp is caged rather than crowned.
    body = body[:-4]
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            body.append(brushkit.block("cpa_cage_%d_%d" % (int(sx), int(sy)),
                                       (0.06, 0.06, 0.44),
                                       (sx * 0.20, sy * 0.20, 1.90)))
    body.append(brushkit.block("cpa_cap", (0.50, 0.50, 0.12), (0.0, 0.0, 2.16)))
    face = brushkit.block("cpa_face", (0.40, 0.10, 0.40), (0.0, -0.26, 1.02))
    core = brushkit.block("cpa_core", (0.26, 0.26, 0.34), (0.0, 0.0, 1.90))
    brushkit.spin(core, "Z", 45.0)
    ring = brushkit.tube("cpa_ring", 0.52, 0.43, 0.05, 8, (0.0, 0.0, 0.20),
                         asset_name="check_a")
    return body, face, core, ring


def concept_b_vault():
    """B: ARMOURED VAULT.

    A squat, heavy, wall-adjacent block with a recessed hatch. Its bet is
    MASS AND A HOLE: the interaction face is set INTO the object rather than
    stuck on it, so the shadowed recess reads at distance even before the
    lit face does. Reads as something that has to be opened rather than
    approached.
    """
    body = [
        brushkit.block("cpb_base", (1.30, 1.10, 0.20), (0.0, 0.0, 0.10)),
        brushkit.block("cpb_body", (1.14, 0.92, 1.62), (0.0, 0.0, 1.01)),
        brushkit.wedge("cpb_cap", (1.22, 1.00, 0.34), (0.0, 0.0, 1.99),
                       axis="y"),
    ]
    # The recess: a frame standing proud, so the hatch sits in a shadow.
    body.append(brushkit.frame("cpb_reveal", (0.86, 0.86), 0.13, 0.20,
                               (0.0, -0.50, 1.05)))
    for side in (-1.0, 1.0):
        body.append(brushkit.block("cpb_rib_%d" % int(side),
                                   (0.12, 0.98, 1.66),
                                   (side * 0.60, 0.0, 1.03)))
        body.append(brushkit.block("cpb_bolt_%d" % int(side),
                                   (0.18, 0.16, 0.16),
                                   (side * 0.60, -0.40, 1.72)))
    face = brushkit.block("cpb_face", (0.62, 0.10, 0.62), (0.0, -0.44, 1.05))
    core = brushkit.prism("cpb_core", 0.16, 0.30, 8, (0.0, -0.44, 1.05),
                          asset_name="check_b")
    brushkit.spin(core, "X", 90.0)
    ring = brushkit.tube("cpb_ring", 0.74, 0.64, 0.05, 8, (0.0, 0.0, 0.22),
                         asset_name="check_b")
    return body, face, core, ring


def concept_c_mast():
    """C: TRANSMISSION MAST.

    A leaning lattice mast with a caged emitter head. Its bet is
    ASYMMETRY AND A DIAGONAL: nothing else in the room leans, so the
    silhouette is unmistakable at 35 px even when the lit band is behind
    something. The most legible from distance and the least obviously
    approachable, which is exactly the trade the review is for.
    """
    body = [
        brushkit.block("cpc_pad", (1.10, 1.10, 0.16), (0.0, 0.0, 0.08)),
        brushkit.wedge("cpc_heel", (0.90, 0.80, 0.44), (0.0, 0.18, 0.36),
                       axis="y"),
    ]
    # Two legs and a raker: a mast that is braced reads as a mast, and one
    # that is not reads as a pole somebody left.
    for side in (-1.0, 1.0):
        body.append(brushkit.block("cpc_leg_%d" % int(side),
                                   (0.13, 0.13, 1.70),
                                   (side * 0.30, 0.16, 0.95)))
    body.append(brushkit.block("cpc_raker", (0.12, 0.12, 1.30),
                               (0.0, -0.26, 0.85)))
    brushkit.spin(body[-1], "X", -22.0)
    for i, z in enumerate((0.70, 1.24, 1.72)):
        body.append(brushkit.block("cpc_tie_%d" % i, (0.72, 0.10, 0.08),
                                   (0.0, 0.16, z)))
    body.append(brushkit.block("cpc_head", (0.66, 0.54, 0.40),
                               (0.0, 0.06, 2.02)))
    body.append(brushkit.grate("cpc_cage", (0.60, 0.06, 0.34), 5, 0.05,
                               (0.0, -0.24, 2.02), axis="x"))
    face = brushkit.block("cpc_face", (0.46, 0.10, 0.34), (0.0, -0.14, 1.36))
    core = brushkit.prism("cpc_core", 0.18, 0.34, 8, (0.0, 0.06, 2.02),
                          top_radius=0.04, asset_name="check_c")
    ring = brushkit.tube("cpc_ring", 0.60, 0.50, 0.05, 8, (0.0, 0.0, 0.18),
                         asset_name="check_c")
    return body, face, core, ring


CONCEPTS = [
    ("check_a_pedestal", concept_a_pedestal),
    ("check_b_vault", concept_b_vault),
    ("check_c_mast", concept_c_mast),
]


def build_one(name, builder):
    body_parts, face, core, ring = builder()
    shell = common.join(body_parts, name + "_shell")
    common.uv_project_world(shell, propkit.HERO_DENSITY, propkit.HERO_SIZE)
    common.assign(shell, common.make_textured_material(
        name + "_shell",
        propkit.hero_shell(THEME, name, "signal", label="chk").to_blender(
            name + "_shell_tex"),
        roughness=pal.roughness(THEME)))

    common.uv_project_world(face, propkit.HERO_DENSITY, propkit.HERO_SIZE)
    common.assign(face, common.make_textured_material(
        name + "_face",
        propkit.hero_face(THEME, name, "signal", "use").to_blender(
            name + "_face_tex"),
        roughness=0.5))

    # The item itself and the destination ring are the two emissive parts,
    # and they answer DIFFERENT questions -- reward.gd is explicit that the
    # floating item says how far along the Check is and the ring says which
    # world receives it. Keeping them on separate materials keeps that true.
    common.assign(core, _emissive(name + "_core", "signal"))
    common.assign(ring, _emissive(name + "_ring", "send"))

    obj = common.join([shell, face, core, ring], name)
    common.set_origin_floor_centre(obj)
    common.assert_fits(obj, name, CHECK_BOX,
                       "reward.gd gives the Check a 1.4 x 2.6 x 1.4 m "
                       "collision box.")
    return common.export_glb(obj, "batch001/check/%s.glb" % name,
                             "hero", check_flat=False)


def main():
    common.reset_scene()
    report = {}
    for name, builder in CONCEPTS:
        report[name] = build_one(name, builder)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch001",
                       "check", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
