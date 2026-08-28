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


def _emissive(name, saturation=0.88):
    # 0.88 rather than the default: the aperture is the single largest
    # emissive surface in the batch, and a large surface at full saturation
    # is a lamp rather than a cue.
    return common.make_signal_material(name, pal.universal("identity", 0),
                                       pal.universal("identity", 3),
                                       saturation=saturation, roughness=0.25)


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
    """B-R: THE INTRUSION. Selected at the Batch 001 review, then revised.

    The owner's direction, verbatim in effect: Epsilon is not part of the
    building style. It is a foreign intelligence inhabiting, infecting and
    embedding itself into old infrastructure. The facility stays cold, grey
    and institutional; this thing has to look wrong and alive inside it.

    What survives from Batch 001's B: the open frame with a void through the
    middle, which is the only silhouette in the whole kit with a hole in it
    and is therefore identifiable in black at any size. The review was
    explicit that this must not be lost.

    What changed, and why:

    * **The core is no longer a cone.** A tapered prism under a hood read as
      a lamp -- the review called it "lamp/cone energy" and it was right.
      It is now a stack of three irregular faceted masses at different
      angles, which reads as growth or computation rather than as a fitting.
    * **A facility host.** The bottom third is ordinary bolted grey plate in
      the theme's own paint, and the alien mass bursts out of it. Epsilon
      reading as an *intrusion* requires something visible for it to intrude
      into; without it, it is just another dark machine.
    * **Asymmetry.** The two cradle arms are now different lengths at
      different angles, and the core sits off the centre line.
    * **Roots.** Conduits leave the base and run into the floor, so the
      thing has clearly reached into the building rather than been placed on
      it.
    * **Neon green, not violet.** See `palette_build.py`.
    """
    # --- the human part: an ordinary facility plinth, violated -----------
    host = [
        brushkit.block("epb_pad", (1.14, 1.14, 0.16), (0.0, 0.0, 0.08)),
        brushkit.block("epb_kerb", (0.96, 0.96, 0.22), (0.0, 0.0, 0.25)),
    ]
    # Conduits leaving the plinth into the floor: it has taken root.
    for i, (dx, dy, rot) in enumerate(((-0.46, 0.30, 26.0), (0.50, -0.22, -38.0),
                                       (0.18, 0.52, 64.0))):
        host.append(brushkit.block("epb_root_%d" % i, (0.13, 0.62, 0.11),
                                   (dx, dy, 0.07), rotation_z=rot))

    # --- the alien part: canted, plated differently, asymmetric ----------
    alien = [
        # A spine that does not stand straight. Nothing in the facility leans.
        brushkit.prism("epb_spine", 0.25, 1.02, 10, (0.0, 0.14, 0.86),
                       top_radius=0.17, asset_name="epsilon_b", organic=True),
    ]
    brushkit.spin(alien[-1], "X", 7.0)
    # A collar where it comes through the plinth -- the wound.
    alien.append(brushkit.prism("epb_collar", 0.36, 0.14, 10, (0.0, 0.10, 0.40),
                                top_radius=0.29, asset_name="epsilon_b",
                                organic=True))

    # Two arms, deliberately unequal. The review asked for asymmetry and a
    # mirrored pair is the one thing that cannot deliver it.
    for side, length, lean, z in ((-1.0, 1.38, 14.0, 1.50), (1.0, 1.12, 8.0, 1.36)):
        arm = brushkit.block("epb_arm_%d" % int(side), (0.15, 0.15, length),
                             (side * 0.36, 0.12, z))
        brushkit.spin(arm, "Y", side * lean)
        alien.append(arm)
        alien.append(brushkit.wedge("epb_claw_%d" % int(side),
                                    (0.20, 0.34, 0.22),
                                    (side * 0.29, 0.02, z + length / 2.0 - 0.05),
                                    axis="y", rotation_z=180.0))
    # A broken yoke across the top -- shorter than the span, so the frame
    # reads as having grown rather than been assembled.
    alien.append(brushkit.block("epb_yoke", (0.78, 0.22, 0.15),
                                (-0.06, 0.12, 2.24)))
    alien.append(brushkit.wedge("epb_crown", (0.62, 0.40, 0.30),
                                (-0.06, 0.10, 2.48), axis="y"))
    # Fins radiating off the spine: hostile, and they break the outline at
    # the height a standing player looks at.
    for i, (ang, z, ln) in enumerate(((-58.0, 1.02, 0.44), (34.0, 1.34, 0.36),
                                      (-24.0, 1.62, 0.30), (72.0, 1.86, 0.26))):
        alien.append(brushkit.wedge("epb_fin_%d" % i, (0.09, ln, 0.20),
                                    (0.0, 0.14, z), axis="y",
                                    rotation_z=ang))

    # --- the cores: angular shards, NOT tapered prisms -------------------
    #
    # The first revision built these as prisms with a smaller top radius --
    # which is a truncated cone, which is a lampshade. The review had
    # already named that failure ("less lamp/cone energy") and the fix
    # reproduced it, because a tapered prism is the obvious way to make a
    # glowing mass and the obvious way was the wrong one.
    #
    # Hard-edged blocks and wedges at unrelated angles instead. No two of
    # them share a rotation, none of them tapers, and they overlap rather
    # than stack -- so the cluster reads as something crystalline or
    # computational that grew, not as a fitting that was screwed on.
    cores = []
    shards = (
        # (w, d, h,   x,     z,    rot_x, rot_y, rot_z)
        (0.30, 0.26, 0.34, -0.07, 1.50,  18.0, -12.0,  27.0),
        (0.22, 0.30, 0.24,  0.11, 1.72, -26.0,  33.0, -41.0),
        (0.26, 0.18, 0.28, -0.03, 1.92,  41.0,  -8.0,  63.0),
        (0.15, 0.17, 0.19,  0.10, 2.10, -14.0,  24.0,  12.0),
    )
    for i, (w, d, h, x, z, rx, ry, rz) in enumerate(shards):
        c = brushkit.block("epb_core_%d" % i, (w, d, h), (x, 0.10, z))
        brushkit.spin(brushkit.spin(brushkit.spin(c, "X", rx), "Y", ry),
                      "Z", rz)
        cores.append(c)
    # One shard set INSIDE the frame void, low and behind the arms. The
    # hole in the silhouette is the thing the review said not to lose, and a
    # light source inside it is what stops the hole reading as empty.
    deep = brushkit.block("epb_core_deep", (0.19, 0.13, 0.23), (-0.02, 0.30, 1.34))
    cores.append(brushkit.spin(brushkit.spin(deep, "Y", -31.0), "X", 16.0))
    return host, alien, cores


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


def _shell(name, canvas):
    return common.make_textured_material(
        name, canvas.to_blender(name + "_tex"), roughness=pal.roughness(THEME))


def build_one(name, builder):
    parts = builder()
    if len(parts) == 2:
        body_parts, aperture = parts
        shell = common.join(body_parts, name + "_shell")
        common.uv_project_world(shell, propkit.HERO_DENSITY, propkit.HERO_SIZE)
        common.assign(shell, _shell(
            name + "_shell",
            propkit.hero_shell(THEME, name, "identity", label="eps")))
        common.assign(aperture, _emissive(name + "_aperture"))
        obj = common.join([shell, aperture], name)
    else:
        # The revised B: three material groups, and the split IS the
        # concept. Facility grey at the bottom, alien plating above it,
        # emissive cores inside that -- so the object shows the building
        # being intruded upon rather than just being a dark machine.
        host_parts, alien_parts, core_parts = parts
        host = common.join(host_parts, name + "_host")
        common.uv_project_world(host, propkit.PROP_DENSITY, propkit.PROP_SIZE)
        common.assign(host, _shell(name + "_host",
                                   propkit.facility_host(THEME, name)))
        alien = common.join(alien_parts, name + "_alien")
        common.uv_project_world(alien, propkit.HERO_DENSITY, propkit.HERO_SIZE)
        common.assign(alien, _shell(name + "_alien",
                                    propkit.alien_shell(THEME, name)))
        core = common.join(core_parts, name + "_core")
        common.assign(core, _emissive(name + "_core", saturation=0.94))
        obj = common.join([host, alien, core], name)

    common.set_origin(obj, "floor")
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
