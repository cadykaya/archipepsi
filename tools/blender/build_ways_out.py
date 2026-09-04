"""Batch 006 -- the ways out: the portal's two states, and the door.

    .tools/blender/blender -b --python tools/blender/build_ways_out.py

Tier 2's remaining Pri-A rows in `ASSET_INVENTORY.md` section 2 that do not
need a new visual language. Both are openings the player walks through, and
both are still procedural boxes in the engine:

| Row | Replaces | State |
| --- | --- | --- |
| `portal_core_states` | `exit_portal.gd` `Core` | a `BoxMesh` with two glow colours |
| `door_standard` | the gaps `chamber_builders.gd` cuts | nothing at all -- a hole |

`objective_marker` and `signage_module` are the other two unbuilt rows and
are deliberately NOT here. Both are a navigation *language* rather than a
fixture -- a vocabulary that has to mean the same thing in all six themes --
and that is new visual DNA. `ART_FRONTIER.md` says to surface those and
continue elsewhere, so they are surfaced there and this is elsewhere.

## The portal frame is already built, and stays built

`portal_b2_wound` is the owner's approved breach and this batch does not
rebuild it. `exit_portal.gd` names two meshes, `Frame` and `Core`, and only
the Core changes at runtime -- so only the Core needed producing.

## What "locked" looks like, and why it is not a new colour

`exit_portal.gd` paints the core green when unlocked and a dark desaturated
red when sealed. The palette has no red family, and the three that could be
borrowed all mean something else: `hazard` is *what is about to happen*,
`dead` is *spent*, `send` is *this leaves for the multiworld*. A sealed exit
is none of those; it is the same alien wound, shut.

So both states stay in `identity`, which the approved concept already uses
for this object, and the difference is **form** plus the family's own value
range -- the same lesson the Check paid for at 39.6 m (`ART_LESSONS` L-44):
at the distance a portal is first seen, brightness alone is a weak channel
and a hole is not.

    locked      the wound has grown over. A ridged, lopsided, opaque
                membrane filling the whole aperture. Nearly black.
    unlocked    the same growth torn open. The material is pulled to the
                edges and there is a way through, lit.

Solid against holed reads at any distance, in any tint, and to a player who
cannot tell the two hues apart.

## Two things the engine has to change, and one it does not

`Core` is a `BoxMesh` 2.4 x 3.4 x 0.2 at y 1.9, so it spans 0.2 to 3.6 --
which is fine inside a solid 4.2 m box `Frame` and wrong inside an authored
frame whose aperture is a real hole from the floor to a 3.4 m lintel. The
authored core is built at its true height in the frame's own space and
anchored `module_floor`, so `Core.position` becomes `Vector3.ZERO`. Same
contract as `check_item_*`; interface requirement 12 records it.

What does NOT change: the node names. `Frame`, `Core` and `StateLabel` are
engineering's, and the label stays engineering's too -- the remaining-Checks
count is an unbounded integer and a mesh cannot carry one. A row of pips
that saturated at eight would be lying at nine.
"""

from __future__ import annotations

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import brushkit  # noqa: E402
import common  # noqa: E402
import materials  # noqa: E402
import palette as pal  # noqa: E402

THEME = "concrete_facility"
OUT = "batch006"

#: build_concept_portal.APERTURE -- the opening the approved breach leaves.
APERTURE = (2.4, 3.4)
#: exit_portal.gd: the Core is 0.2 m deep.
CORE_DEPTH = 0.2

DOOR_W = common.DIM["door_width"]          # 2.4
DOOR_H = common.DIM["door_height"]         # 3.2
WALL_T = common.DIM["wall_thickness"]      # 0.4
JAMB = 0.16
HEAD = 0.18


# ----------------------------------------------------------------------
# the portal core, in two states
# ----------------------------------------------------------------------
#
# Both are built from the same list of growth slabs. `spread` moves each
# slab outward from the aperture's centre line: at 0.0 they overlap into a
# closed membrane, at 1.0 they are pulled to the edges and the middle is
# open. One number, two states, and the family is obvious because it is
# literally the same geometry.

#: (x, z, w, h, rot). Lopsided toward -X on purpose: the approved mass
#: piles up on one side and crosses the lintel, and a symmetric membrane
#: behind an asymmetric wound would read as two different objects.
#:
#: Two explicit lists rather than one parameterised family. The first pass
#: interpolated a `spread` between them, which is tidier to write and made a
#: worse object: slabs near the centre line have almost no offset to push
#: along, so the "open" state still had its middle covered. An aperture that
#: is open has to actually be open.
CLOSED = (
    (-0.42, 2.62, 1.28, 0.92, 6.0),
    (-0.18, 1.86, 1.50, 0.86, -4.0),
    (-0.46, 1.02, 1.12, 0.94, 9.0),
    (0.40, 2.34, 1.02, 1.14, -8.0),
    (0.48, 1.16, 0.90, 1.02, 5.0),
    (-0.06, 3.00, 1.18, 0.70, -3.0),
    (0.10, 0.44, 1.36, 0.70, 2.0),
)

#: The same wound, torn open: the material has retreated to the aperture's
#: edges and there is a way through. Three teeth are left pointing inward,
#: because growth that opened is not growth that was cut.
OPEN = (
    (-0.96, 1.70, 0.32, 2.60, 3.0),
    (0.96, 1.80, 0.30, 2.40, -4.0),
    (-0.10, 3.10, 1.60, 0.42, 2.0),
    (0.06, 0.30, 1.80, 0.44, -2.0),
    (-0.62, 2.72, 0.60, 0.34, 12.0),
    (0.52, 0.86, 0.52, 0.30, -14.0),
    (-0.48, 0.74, 0.40, 0.26, 8.0),
)


def portal_core(state, slabs, depth_scale):
    width, height = APERTURE
    parts = []
    for i, (x, z, w, h, rot) in enumerate(slabs):
        # STAGGERED IN DEPTH, and that is not decoration. The first pass put
        # every slab at y 0 with one depth, so their front faces were
        # coplanar and seven modelled slabs rendered as one flat green
        # rectangle -- every ridge in the growth invisible, the silhouette
        # doing all the work alone. Relief is what makes a membrane read as
        # grown rather than fitted.
        dy = ((i % 3) - 1) * 0.035
        depth = CORE_DEPTH * depth_scale * (0.5 + 0.15 * (i % 3))
        slab = brushkit.block("pc_%s_%d" % (state, i), (w, depth, h),
                              (x, dy, z))
        parts.append(brushkit.spin(slab, "Y", rot))
    # A rim that keeps the growth attached to the jambs in BOTH states. An
    # open portal whose membrane has floated free of the wall is a portal
    # that has stopped being a wound in something.
    for sx in (-1.0, 1.0):
        parts.append(brushkit.block(
            "pc_%s_rim_%d" % (state, int(sx)),
            (0.14, CORE_DEPTH * 0.8, height * 0.92),
            (sx * (width / 2.0 - 0.08), 0.0, height / 2.0)))
    obj = common.join(parts, "portal_core_%s" % state)
    common.set_origin(obj, "module_floor")
    common.assert_fits(obj, "portal_core_%s" % state,
                       (width + 0.05, CORE_DEPTH + 0.05, height + 0.05),
                       "the core fills exit_portal.gd's aperture and may "
                       "not grow past the frame that holds it.")
    return obj


def build_core(state, slabs, depth_scale, material):
    obj = portal_core(state, slabs, depth_scale)
    # ONE material, like `check_item_*`: whichever way engineering goes --
    # swapping the two meshes, or keeping `material_override` on one -- an
    # authored core with two materials would work under only one of them.
    common.assign(obj, material("portal_core_%s" % state))
    return common.export_glb(obj, "%s/portal/portal_core_%s.glb" % (OUT, state),
                             "interactable", anchor="module_floor")


# ----------------------------------------------------------------------
# the standard door
# ----------------------------------------------------------------------

def door_standard():
    """The lining for the gap `chamber_builders.gd` cuts, at its own numbers.

    `DOOR_WIDTH` 2.4, `DOOR_HEIGHT` 3.2, `WALL_THICKNESS` 0.4 -- all read
    from the engine. The gap is currently nothing at all: four boxes with a
    hole between them and raw wall material on the reveal, which is the one
    surface in a chamber the player looks straight at while walking through.

    It is STRUCTURE, so it wears the theme's trim and not a universal
    family. A door lining in `signal` teal would be claiming to be an
    interactable, and the one thing a corridor full of doorways must not do
    is promise seven interactions a room does not have.

    Built symmetric front-to-back on purpose: `_walls_with_doors` puts a gap
    in the entrance wall and another in the exit wall, and the player meets
    each from both sides across a run.
    """
    parts = []
    # The reveal: a full lining around the bore, so the 0.4 m wall thickness
    # reads as a thickness rather than as a cut edge.
    for sx in (-1.0, 1.0):
        parts.append(brushkit.block("dr_reveal_%d" % int(sx),
                                    (0.06, WALL_T, DOOR_H),
                                    (sx * (DOOR_W / 2.0 - 0.03), 0.0,
                                     DOOR_H / 2.0)))
    parts.append(brushkit.block("dr_soffit", (DOOR_W, WALL_T, 0.06),
                                (0.0, 0.0, DOOR_H - 0.03)))
    # Jambs and head, standing proud of the wall on BOTH faces.
    for face in (-1.0, 1.0):
        y = face * (WALL_T / 2.0 + 0.05)
        for sx in (-1.0, 1.0):
            parts.append(brushkit.block(
                "dr_jamb_%d_%d" % (int(face), int(sx)),
                (JAMB, 0.10, DOOR_H + HEAD),
                (sx * (DOOR_W + JAMB) / 2.0, y, (DOOR_H + HEAD) / 2.0)))
        parts.append(brushkit.block(
            "dr_head_%d" % int(face), (DOOR_W + JAMB * 2.0, 0.10, HEAD),
            (0.0, y, DOOR_H + HEAD / 2.0)))
    # No bolt bosses, and that is the budget deciding rather than taste:
    # eight of them cost 96 triangles against an `architecture_module`
    # ceiling of 250, and `assert_budget`'s own message is the rule --
    # over budget means DELETE geometry and paint it instead. `materials
    # .paint` already puts bolts on the trim surface this wears.
    #
    # What the triangles buy instead is a KICK PLATE on each face: the part
    # of a doorway that actually takes damage is the bottom 400 mm, and a
    # lining with a scuffed plate there reads as used where a lining with
    # modelled bolt heads reads as drawn.
    for face in (-1.0, 1.0):
        parts.append(brushkit.block(
            "dr_kick_%d" % int(face), (DOOR_W + JAMB * 2.0, 0.06, 0.40),
            (0.0, face * (WALL_T / 2.0 + 0.08), 0.22)))
    # A threshold plate. `exit_gap_y` can raise a door's sill to a tower's
    # summit, so the sill is part of the lining and not a floor decal --
    # a decal at 6 m would be lying on nothing.
    parts.append(brushkit.block("dr_threshold", (DOOR_W + JAMB, WALL_T + 0.16,
                                                 0.05), (0.0, 0.0, 0.025)))
    obj = common.join(parts, "door_standard")
    common.uv_project_world(obj, materials.ARCH_DENSITY, materials.ARCH_SIZE)
    # The theme's TRIM, painted by the same function the architecture kit
    # uses, so a door lining and the wall it is cut into are one surface
    # rather than two paintings of the same idea.
    canvas, _ = materials.paint(THEME, "trim")
    common.assign(obj, common.make_textured_material(
        "door_standard", canvas.to_blender("door_standard_tex"),
        roughness=pal.roughness(THEME)))
    common.set_origin(obj, "floor")
    common.assert_fits(obj, "door_standard",
                       (DOOR_W + JAMB * 2.0 + 0.05, WALL_T + 0.35,
                        common.DIM["corridor_height"]),
                       "a door lining taller than CORRIDOR_HEIGHT does not "
                       "fit the corridor it is cut into.")
    return common.export_glb(obj, "%s/architecture/door_standard.glb" % OUT,
                             "architecture_module", tier="architecture",
                             texture_size=materials.ARCH_SIZE)


def main():
    common.reset_scene()
    portal = {}
    # identity step 1 at a fifth saturation: still the alien family, but at
    # a value the eye reads as shut rather than off. exit_portal.gd runs the
    # sealed core at 0.5 emission energy against the open one's 2.0.
    # Both states go through `make_signal_material`, and the reason is the
    # part of it that is NOT about emission: it scales the albedo down until
    # `albedo * irradiance` is at most half the lighting budget. Skipping
    # that was the first pass's mistake -- `make_material` with a dark green
    # albedo and a token 0.15 emission still rendered a bright green slab,
    # because `identity[0]` is `#23660c` and its green channel alone is 0.40,
    # which clips at any irradiance over 2.5. The albedo was the problem the
    # whole time; the emission was never the loud part.
    #
    # Saturation is doing the state work. At 0.06 the solved strength is
    # 0.075 and the surface is a dark scab; at 0.55 it is a lit membrane.
    # exit_portal.gd's own energies are 0.5 sealed against 2.0 open, and the
    # authored pair should not invert that ratio.
    #
    # 0.55 rather than the 0.92 every other emitter in the project uses,
    # because this is the LARGEST emissive surface in the game: 2.4 x 3.4 m
    # against a band 100 mm tall or an eye 60 mm across. A saturation tuned
    # on an eye is a saturation that floods a doorway.
    portal["portal_core_locked"] = build_core(
        "locked", CLOSED, 1.0,
        lambda n: common.make_signal_material(
            n, pal.universal("identity", 0), pal.universal("identity", 0),
            saturation=0.06, roughness=0.55))
    # And it emits identity step 2, not step 3. Step 3 is `#57ff1f`, and
    # emitting the family's brightest step is what turned the Check's
    # available state into a white hexagon (ART_LESSONS L-42).
    portal["portal_core_unlocked"] = build_core(
        "unlocked", OPEN, 0.7,
        lambda n: common.make_signal_material(
            n, pal.universal("identity", 0), pal.universal("identity", 2),
            saturation=0.55, roughness=0.35))
    arch = {"door_standard": door_standard()}

    for family, report in (("portal", portal), ("architecture", arch)):
        out = os.path.join(common.REPO_ROOT, "assets", "models", OUT,
                           family, "manifest.json")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2, sort_keys=True)
            handle.write("\n")


if __name__ == "__main__":
    main()
