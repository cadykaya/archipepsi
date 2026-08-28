"""Batch 001 A -- three Epsilon-presence concepts.

    .tools/blender/blender -b --python tools/blender/build_concept_epsilon.py

`AUTHORED_CONTENT.md`: "Epsilon's physical and presentational identity -- a
character, not a style." And: "An Epsilon that is a different character each
time you meet it" is one of the three named failure modes.

So the three concepts differ in SILHOUETTE and agree on IDENTITY. Every one
of them carries the same `identity` colour, the same single dominant
aperture cue, and the same height, because those are the parts the player
learns. What is being asked is what shape Epsilon is, not what Epsilon is.

## One dominant cue, and nothing competes with it

Each concept has exactly ONE lit aperture, and it is the widest lit thing on
the object. Secondary detail was cut until that was true. This is the rule
mario-3's Walker pass arrived at -- if every edge is lit, none of them is
the one to look at -- and it matters more here, because Epsilon's aperture
is the thing the player looks at while being talked to.

## No engineering interface yet

`hub.gd` builds a generic `_Terminal` at 2.0 x 3.0 x 0.8 m and Epsilon
currently speaks through `ui/epsilon_voice.gd` with no dedicated fixture.
There is therefore no committed footprint for an Epsilon presence. These are
built to 1.4 x 1.4 x 2.8 m -- inside the Hub's existing terminal envelope on
every axis -- so that whichever contract lands, the asset already fits.
Recorded as an interface requirement in ART_FRONTIER.md.
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
#: Provisional. Inside hub.gd's existing terminal envelope on every axis.
EPSILON_BOX = (1.4, 1.4, 2.8)


def _emissive(name, strength=1.15):
    return common.make_signal_material(name, pal.universal("identity", 0),
                                       pal.universal("identity", 3),
                                       strength=strength, roughness=0.25)


def concept_a_lectern():
    """A: LECTERN.

    Epsilon as something you stand AT. A raked console on a plinth under a
    tall backing slab, with the aperture set high in the slab so it is at
    the player's eye line at conversational distance. The most furniture-like
    of the three and the least strange, which is the trade.
    """
    body = [
        brushkit.block("epa_plinth", (1.16, 0.86, 0.22), (0.0, 0.0, 0.11)),
        brushkit.block("epa_desk", (1.00, 0.66, 0.80), (0.0, -0.06, 0.62)),
        brushkit.wedge("epa_rake", (1.00, 0.44, 0.30), (0.0, -0.18, 1.17),
                       axis="y", rotation_z=180.0),
        brushkit.block("epa_slab", (1.04, 0.26, 1.72), (0.0, 0.22, 1.60)),
        brushkit.block("epa_cap", (1.16, 0.36, 0.16), (0.0, 0.22, 2.54)),
    ]
    for side in (-1.0, 1.0):
        body.append(brushkit.block("epa_buttress_%d" % int(side),
                                   (0.14, 0.50, 1.10),
                                   (side * 0.52, 0.10, 1.20)))
    aperture = brushkit.block("epa_aperture", (0.74, 0.08, 0.20),
                              (0.0, 0.07, 1.94))
    surround = brushkit.frame("epa_surround", (0.94, 0.40), 0.10, 0.14,
                              (0.0, 0.10, 1.94))
    return body + [surround], aperture


def concept_b_core():
    """B: SUSPENDED CORE.

    Epsilon as something hanging in a cradle, not standing on the floor. Its
    bet is a VOID IN THE MIDDLE: the silhouette has a hole in it, which no
    other object in the kit does, so it is identifiable in black at any size.
    Reads least like furniture and most like a thing that was installed.
    """
    body = [
        brushkit.block("epb_base", (0.96, 0.96, 0.24), (0.0, 0.0, 0.12)),
        brushkit.prism("epb_column", 0.22, 0.90, 8, (0.0, 0.30, 0.68),
                       asset_name="epsilon_b"),
    ]
    # The cradle: two arms reaching forward and up, holding nothing visible.
    for side in (-1.0, 1.0):
        arm = brushkit.block("epb_arm_%d" % int(side), (0.13, 0.13, 1.34),
                             (side * 0.40, 0.16, 1.44))
        brushkit.spin(arm, "Y", side * 14.0)
        body.append(arm)
        body.append(brushkit.block("epb_claw_%d" % int(side),
                                   (0.16, 0.30, 0.16),
                                   (side * 0.34, 0.02, 2.06)))
    body.append(brushkit.block("epb_yoke", (0.94, 0.20, 0.14),
                               (0.0, 0.16, 2.22)))
    body.append(brushkit.wedge("epb_hood", (0.80, 0.44, 0.26),
                               (0.0, 0.12, 2.42), axis="y"))
    # The core hangs in the gap between the claws. It IS the aperture.
    aperture = brushkit.prism("epb_core", 0.26, 0.44, 8, (0.0, 0.02, 1.86),
                              top_radius=0.10, asset_name="epsilon_b")
    return body, aperture


def concept_c_aperture():
    """C: WALL APERTURE.

    Epsilon as a slot in the architecture rather than an object in front of
    it -- a heavy recessed frame with a single lit horizontal band. Its bet
    is that Epsilon is PART OF THE BUILDING, which is the reading the fiction
    most supports and the one that gives the Hub the least clutter.

    The risk this concept is offered to test: a wall fixture may be too easy
    to walk past, and the Hub needs Epsilon to be findable.
    """
    body = [
        brushkit.block("epc_backing", (1.26, 0.30, 2.50), (0.0, 0.14, 1.25)),
        brushkit.block("epc_sill", (1.34, 0.44, 0.18), (0.0, 0.06, 0.09)),
        brushkit.wedge("epc_lintel", (1.34, 0.44, 0.30), (0.0, 0.06, 2.62),
                       axis="y"),
    ]
    for side in (-1.0, 1.0):
        body.append(brushkit.block("epc_jamb_%d" % int(side),
                                   (0.16, 0.42, 2.44),
                                   (side * 0.58, 0.04, 1.30)))
        for i in range(3):
            body.append(brushkit.block("epc_stud_%d_%d" % (int(side), i),
                                       (0.10, 0.10, 0.10),
                                       (side * 0.58, -0.16, 0.60 + i * 0.72)))
    body.append(brushkit.frame("epc_surround", (1.00, 0.62), 0.13, 0.22,
                               (0.0, -0.02, 1.62)))
    aperture = brushkit.block("epc_aperture", (0.80, 0.08, 0.24),
                              (0.0, 0.02, 1.62))
    return body, aperture


CONCEPTS = [
    ("epsilon_a_lectern", concept_a_lectern),
    ("epsilon_b_core", concept_b_core),
    ("epsilon_c_aperture", concept_c_aperture),
]


def build_one(name, builder):
    body_parts, aperture = builder()
    shell = common.join(body_parts, name + "_shell")
    common.uv_project_world(shell, propkit.HERO_DENSITY, propkit.HERO_SIZE)
    common.assign(shell, common.make_textured_material(
        name + "_shell",
        propkit.hero_shell(THEME, name, "identity", label="eps").to_blender(
            name + "_shell_tex"),
        roughness=pal.roughness(THEME)))
    common.assign(aperture, _emissive(name + "_aperture"))
    obj = common.join([shell, aperture], name)
    common.set_origin_floor_centre(obj)
    common.assert_fits(obj, name, EPSILON_BOX,
                       "Provisional envelope: hub.gd's existing terminal is "
                       "2.0 x 3.0 x 0.8 m and these must fit inside it on "
                       "every axis until a real contract exists.")
    return common.export_glb(obj, "batch001/epsilon/%s.glb" % name,
                             "hero", check_flat=False)


def main():
    common.reset_scene()
    report = {}
    for name, builder in CONCEPTS:
        report[name] = build_one(name, builder)
    out = os.path.join(common.REPO_ROOT, "assets", "models", "batch001",
                       "epsilon", "manifest.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
