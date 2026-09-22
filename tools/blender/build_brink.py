"""Batch 057 -- T03, the third game pack's CONTENT. Bomb Rush Cyberfunk.

    .tools/blender/blender -b --python tools/blender/build_brink.py

## The subtheme is chosen, and saying which is half the job

Bomb Rush Cyberfunk has six boroughs. **This pack is BRINK TERMINAL,
AFTER HOURS** -- the concourse with the shutters down, the departure
board dark, one strip light out, and the tags that only happen when
nobody is watching.

The packet's concept for T03 is "Afterhours Municipal Transit", and for
once the concept, the subtheme and the house family all point the same
way. Not Versum Hill's rooftops, not Mataan, not Pyramid Island: a
terminal is the half of that game which is ARCHITECTURE rather than
terrain, and architecture is what a theme pack ships.

## The hint, the material and the subject all agree -- which is the point

`Constants.THEME_BY_GAME_HINT` maps this game to `neon_transit`. The
nearest family by material culture is `neon_transit`. The subtheme is a
transit terminal. **Three for three.**

That matters because T02 was none of the above: its hint said
`concrete_facility` and a clock movement's material culture said
`rusted_industrial`. Two agreements and one disagreement is the shape of
the argument for `COVERAGE.md` §3 -- **the hint is usually right and
cannot be relied on**, which is a worse problem than a hint that is
always wrong, because nobody notices the one case.

The manifest records `theme_hint_says` beside `painted_with` either way,
so agreement is data too rather than a silence.

## What is here and what is NOT

Shapes, motifs, dressing and a stateful-control housing. **No material
treatment**, for T01 and T02's reason: `THEME_PACK.json` has no pack
namespace. These are painted in `neon_transit` and a tint is not this
pack's treatment.

## The hazard band, checked rather than assumed

T02 shipped a clock movement in warning stripes before anyone noticed
that `rusted_industrial`'s `trim` IS the universal hazard band. So this
pack checked first: only `rusted_industrial` splits `trim` from
`trim_plain`, and `neon_transit`'s trim is a **signage band** with no
danger semantics. `trim` is safe here, and `accent` is a tiled panel
rather than a stencil. Both are used deliberately and neither is a
warning.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import packgates  # noqa: E402
import packkit  # noqa: E402

THEME = "neon_transit"
THEME_HINT = "neon_transit"
OUT = "batch057/brink"
SIZE = packkit.SIZE
DENSITY = packkit.DENSITY
PAINT = packkit.Painter(THEME, "br")

DOOR_W = packgates.DOOR_W
DOOR_H = packgates.DOOR_H


# --------------------------------------------------------------- assets

def concourse_pillar():
    """A tiled transit pillar, TAGGED and SCUFFED at grind height.

    The house `neon_transit` pillar is clean tile, because the house
    family is a station that still has staff in it. This one has a kick
    band worn through at 0.6-0.9 m -- which is where a coping meets a
    pillar, and the one height a skater's damage actually lands -- and a
    tag on the face that gets the least light.

    The scuff bars are 0.06 m deep on purpose: a plan footprint under
    0.35 m in either axis is not a step, and a band you could stand on
    would be a ledge the art lane invented.
    """
    h = 3.6
    body = PAINT.block("br_pil_shaft", (0.44, 0.44, h), (0.0, 0.0, h / 2.0),
                       "wall")
    parts = [
        PAINT.block("br_pil_plinth", (0.80, 0.80, 0.20), (0.0, 0.0, 0.10),
                    "trim"),
        PAINT.block("br_pil_capital", (0.62, 0.62, 0.18), (0.0, 0.0, 3.51),
                    "trim"),
        PAINT.block("br_pil_kick", (0.50, 0.50, 0.30), (0.0, 0.0, 0.62),
                    "accent", "trim"),
        PAINT.block("br_pil_tag", (0.34, 0.03, 0.46), (0.0, -0.235, 1.55),
                    "accent", "trim"),
    ]
    for i, y in enumerate((-0.25, 0.25)):
        parts.append(PAINT.block("br_pil_scuff_%d" % i, (0.54, 0.06, 0.05),
                                 (0.0, y, 0.70), "trim"))
    return body, parts


def board_panel():
    """The departure board, DARK. Same 2.16 x 3.00 wall footprint as
    T01's relief and T02's movement, so the three packs' wall pieces are
    the same object in three material cultures.

    The subject is the ONE FLIPPED SLAT. A board that is merely off is a
    black rectangle and reads as a missing texture; a board caught
    mid-flip is a board that was running until recently, which is the
    whole of "after hours".
    """
    body = PAINT.block("br_bd_backing", (2.16, 0.10, 3.00),
                       (0.0, 0.0, 1.50), "wall")
    parts = [
        PAINT.block("br_bd_case", (1.90, 0.22, 1.10), (0.0, -0.12, 2.20),
                    "trim"),
        PAINT.block("br_bd_screen", (1.70, 0.05, 0.86), (0.0, -0.245, 2.20),
                    "accent", "trim"),
        PAINT.block("br_bd_shelf", (1.98, 0.26, 0.10), (0.0, -0.13, 1.60),
                    "trim"),
    ]
    for i, z in enumerate((2.52, 2.20, 1.88)):
        parts.append(PAINT.block("br_bd_row_%d" % i, (1.70, 0.07, 0.05),
                                 (0.0, -0.27, z), "trim"))
    # The one that is still turning. It stands proud of the rows either
    # side of it, which is the only way a flipped slat reads at 32
    # texels/m -- a tilt would need a rotation `brushkit.block` cannot
    # make about this axis, and a painted "tilt" is a lie in a silhouette.
    parts.append(PAINT.block("br_bd_flipped", (0.42, 0.13, 0.13),
                             (-0.50, -0.30, 2.20), "wall"))
    return body, parts


def shutter_head():
    """Dressing AROUND the engine's opening: a roller shutter, UP.

    The shutter is fully retracted into its head box and its bottom rail
    sits just above the door head. Anything else is a narrower doorway,
    and the doorway is `chamber_builders.gd`'s.

    The head box is 0.36 m tall and not 0.42: at 0.42 it topped out at
    3.62 m against the review chamber's 3.60 m ceiling. T02 shipped the
    same mistake with a dial mark and the manifest caught it there too.
    A pack that does not fit the room it dresses is not dressing it.
    """
    guide = 0.34
    body = PAINT.block("br_sh_head", (DOOR_W + guide * 2.0, 0.40, 0.36),
                       (0.0, 0.0, DOOR_H + 0.18), "trim")
    parts = []
    for sign, tag in ((-1.0, "l"), (1.0, "r")):
        x = sign * (DOOR_W / 2.0 + guide / 2.0)
        parts.append(PAINT.block("br_sh_guide_%s" % tag,
                                 (guide, 0.30, DOOR_H), (x, 0.0, DOOR_H / 2.0)))
        # The lip runs down the INNER edge of each guide and stops
        # exactly at the opening. Tangent, never over: the gate treats
        # `hi[0] <= -width/2` as clear and a millimetre the other way as
        # an intrusion, correctly.
        parts.append(PAINT.block("br_sh_lip_%s" % tag, (0.14, 0.44, DOOR_H),
                                 (sign * 1.27, 0.0, DOOR_H / 2.0),
                                 "accent", "trim"))
    parts.append(PAINT.block("br_sh_rail", (DOOR_W, 0.46, 0.10),
                             (0.0, -0.03, DOOR_H + 0.05), "trim"))
    return body, parts


def torn_rail():
    """Floor dressing. T01's grew, T02's fell, and this one was RIDDEN
    OFF -- a handrail section torn from its stanchions, still carrying
    one of them and the ripped baseplate of another.

    Bent, for the reason T01's root mass had to be rebuilt and T02's
    clock hand was bent from the start: a straight length on a floor
    reads as stock laid out for a photograph, not as damage.
    """
    body = PAINT.block("br_rl_tube", (1.30, 0.10, 0.10), (0.0, 0.0, 0.09),
                       "trim", rotation_z=6.0)
    parts = [
        PAINT.block("br_rl_bend", (0.40, 0.10, 0.10), (0.72, 0.09, 0.09),
                    "trim", rotation_z=38.0),
        PAINT.block("br_rl_post_a", (0.10, 0.10, 0.26), (-0.40, -0.02, 0.13),
                    "trim"),
        PAINT.block("br_rl_post_b", (0.10, 0.10, 0.18), (0.30, 0.02, 0.09),
                    "trim", rotation_z=12.0),
        PAINT.block("br_rl_flange", (0.24, 0.20, 0.05), (-0.60, -0.05, 0.025),
                    "accent", "trim", rotation_z=-14.0),
        PAINT.block("br_rl_sticker", (0.26, 0.12, 0.12), (-0.05, 0.0, 0.09),
                    "accent", "trim"),
    ]
    return body, parts


def strip_light():
    """The light HOUSING, with ONE TUBE OUT.

    No light rides along: illumination is engine-owned and
    `assert_no_emitters` keeps that true at build time rather than
    discovering it at export.

    The dead tube is `trim` and the live one is `wall`, which is the
    palest surface the family has. That is the whole tell, and it is a
    material difference rather than an emissive one precisely because an
    emissive material is the same claim a `Light3D` makes.
    """
    body = PAINT.block("br_lt_batten", (1.20, 0.16, 0.10), (0.0, 0.0, 0.90),
                       "trim")
    parts = [
        PAINT.block("br_lt_tube_live", (1.06, 0.06, 0.06), (0.0, -0.05, 0.84),
                    "wall"),
        PAINT.block("br_lt_tube_dead", (1.06, 0.06, 0.06), (0.0, 0.05, 0.84),
                    "trim"),
    ]
    for i, x in enumerate((-0.40, 0.0, 0.40)):
        parts.append(PAINT.block("br_lt_cage_%d" % i, (0.03, 0.20, 0.16),
                                 (x, 0.0, 0.85), "trim"))
    for sign, tag in ((-1.0, "l"), (1.0, "r")):
        parts.append(PAINT.block("br_lt_cap_%s" % tag, (0.08, 0.20, 0.16),
                                 (sign * 0.60, 0.0, 0.86), "accent", "trim"))
    return body, parts


def validator_plate():
    """Batch 043's wall-switch contract as a TICKET VALIDATOR.

    Same envelope as T01's timber switch and T02's winding key, in the
    same place on the same wall in all three review frames, so the one
    control the player has to recognise is recognisably the same control
    three times.

    The state a player reads is the PADDLE's angle, and the bezel above
    it is where the engine would put a lamp. Neither is lit here.
    """
    body = PAINT.block("br_vl_plate", (0.44, 0.08, 0.54), (0.0, 0.0, 0.27),
                       "wall")
    parts = [
        PAINT.block("br_vl_pad", (0.28, 0.07, 0.18), (0.0, -0.075, 0.36),
                    "accent", "trim"),
        PAINT.block("br_vl_paddle", (0.30, 0.12, 0.06), (0.0, -0.10, 0.16),
                    "trim", rotation_z=14.0),
        PAINT.block("br_vl_bezel", (0.10, 0.06, 0.10), (0.0, -0.07, 0.48),
                    "trim"),
        PAINT.block("br_vl_kick", (0.44, 0.10, 0.08), (0.0, -0.03, 0.04),
                    "trim"),
    ]
    return body, parts


ASSETS = [
    ("tp_br_concourse_pillar", concourse_pillar, ["route"]),
    ("tp_br_board_panel", board_panel, ["emitters", "route"]),
    ("tp_br_shutter_head", shutter_head, ["opening", "route"]),
    ("tp_br_torn_rail", torn_rail, ["route"]),
    ("tp_br_strip_light", strip_light, ["emitters", "route"]),
    ("tp_br_validator_plate", validator_plate, ["emitters", "route"]),
]

DISTINCT = {
    "tp_br_concourse_pillar": "tagged and worn through at grind height; the "
                              "house pillar is clean tile because the house "
                              "station still has staff in it",
    "tp_br_board_panel": "a departure board caught MID-FLIP: one slat still "
                         "turning is what says 'until recently', where a "
                         "board merely off reads as a missing texture",
    "tp_br_shutter_head": "the opening is dressed as a shuttered concourse "
                          "gate -- head box, guide lips, and the bottom rail "
                          "parked above the head",
    "tp_br_torn_rail": "floor dressing that was RIDDEN OFF, where T01's grew "
                       "and T02's fell: a rail section still carrying one "
                       "stanchion and another's ripped baseplate",
    "tp_br_strip_light": "a municipal batten with ONE TUBE OUT -- the tell is "
                         "a material difference, never an emissive one",
    "tp_br_validator_plate": "batch043's wall-switch contract as a ticket "
                             "validator: tap pad, paddle, lamp bezel",
}


def main():
    packkit.build(ASSETS, OUT, PAINT, DISTINCT, {
        "batch": "057",
        "kind": "theme_pack_content",
        "pack": "tp_bomb_rush_cyberfunk",
        "subtheme": "BRINK TERMINAL, AFTER HOURS -- the concourse with the "
                    "shutters down, the board dark, one strip light out, "
                    "and the tags that only happen when nobody is watching",
        "subtheme_is_a_choice": "Bomb Rush Cyberfunk has six boroughs. A "
                                "terminal is the half of that game which is "
                                "ARCHITECTURE rather than terrain, and "
                                "architecture is what a theme pack ships. "
                                "Not Versum Hill's rooftops, not Mataan, "
                                "not Pyramid Island.",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "painted_with": THEME,
        "theme_hint_says": THEME_HINT,
        "theme_hint_agrees": "Constants.THEME_BY_GAME_HINT names the same "
                             "family this pack's material culture points "
                             "at. T01 agreed too; T02 did not. The hint is "
                             "USUALLY right and cannot be relied on, which "
                             "is worse than always wrong because nobody "
                             "notices the one case. See COVERAGE.md "
                             "section 3.",
        "material_treatment": "MISSING, AND NAMED AS MISSING. THEME_PACK."
                              "json has no pack namespace, so a pack's own "
                              "material set cannot be filed without "
                              "becoming a seventh house theme. See "
                              "docs/art/theme-packs/COVERAGE.md section 3. "
                              "These are painted in the nearest existing "
                              "family; a tint is NOT the pack's treatment.",
        "carries": "mesh and named parts only. No collider, body, trigger, "
                   "light, camera, script or animation.",
        "not_changed": ["collision", "placement", "any runtime state",
                        "the engine's door opening", "any approved asset"],
    }, log="brink")


if __name__ == "__main__":
    main()
