"""Batch 059 -- T05, the fifth game pack's CONTENT. Kingdom Hearts 2.

    .tools/blender/blender -b --python tools/blender/build_twilight.py

## The subtheme is chosen, and saying which is half the job

Kingdom Hearts 2 has a dozen worlds. **This pack is TWILIGHT TOWN, THE
SERVICE ALLEY BEHIND TRAM COMMON** -- brick piers carrying tram cable,
a hoarding nailed over a bricked-up window, a shop awning, and a length
of tram rail nobody has relaid.

Not Hollow Bastion, not The World That Never Was, not Beast's Castle.
Those are three different games' worth of architecture and blending them
is the average the owner ruled out. The packet's concept for T05 is
"Twilight Service District", which names this choice already.

## The second pack in `temple_ruin`, and that is deliberate

T01 is painted in `temple_ruin` too. **Reuse is not a defect** -- the
owner's completion criteria say so directly: shared architectural
families, base meshes, materials and machinery are encouraged, and a
useful visual variant is not a duplicate merely because its construction
is shared.

So this pack is the test of that claim rather than an accident of it. A
forest temple and a town alley share warm weathered masonry and share
nothing else, and if the two read as one place in the same shell under
the same four cameras then the claim was wrong and the packs need
separating. **That is a judgement for the owner and the frames are set up
to make it.**

Kingdom Hearts 2 has **no entry** in `Constants.THEME_BY_GAME_HINT`, like
74 other catalogued games -- see T04's report. `temple_ruin` is Art's
choice by material culture, not a hint being followed.

## The band, checked before it was used

`temple_ruin`'s `trim` carries no hazard semantics -- only
`rusted_industrial` splits `trim` from `trim_plain` -- so `trim` is safe
here. Checked, as T03 and T04 checked, because T02 shipped a clock
movement in warning stripes before anyone looked.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import packgates  # noqa: E402
import packkit  # noqa: E402

THEME = "temple_ruin"
THEME_HINT = None
OUT = "batch059/twilight"
SIZE = packkit.SIZE
DENSITY = packkit.DENSITY
PAINT = packkit.Painter(THEME, "tw")

DOOR_W = packgates.DOOR_W
DOOR_H = packgates.DOOR_H


# --------------------------------------------------------------- assets

def alley_buttress():
    """A brick pier that carries a WIRE, not a roof.

    That is the whole difference from T01's column and from the house
    family's. A temple column holds something up; a street pier holds
    something ACROSS, and the bracket bolted to its face at 3.0 m is
    what says which kind of street this is.
    """
    h = 3.6
    body = PAINT.block("tw_bt_pier", (0.46, 0.46, h), (0.0, 0.0, h / 2.0),
                       "wall")
    parts = [
        PAINT.block("tw_bt_base", (0.66, 0.66, 0.26), (0.0, 0.0, 0.13),
                    "trim"),
        # A corbel, not a capital: two courses stepping out, which is
        # how a brick pier finishes and how a stone one does not.
        PAINT.block("tw_bt_corbel_a", (0.58, 0.58, 0.12), (0.0, 0.0, 3.34),
                    "trim"),
        PAINT.block("tw_bt_corbel_b", (0.70, 0.70, 0.12), (0.0, 0.0, 3.46),
                    "trim"),
        # The cable bracket and its stay. The bracket reaches OUT of the
        # pier and the stay triangulates back into it, which is the
        # shape of every real catenary fixing and reads at any distance.
        PAINT.block("tw_bt_bracket", (0.10, 0.62, 0.09), (0.0, -0.40, 3.02),
                    "accent", "trim"),
        PAINT.block("tw_bt_stay", (0.08, 0.44, 0.44), (0.0, -0.30, 2.72),
                    "accent", "trim", rotation_z=0.0),
        PAINT.block("tw_bt_eye", (0.12, 0.12, 0.16), (0.0, -0.66, 2.98),
                    "trim"),
    ]
    return body, parts


def hoarding():
    """The wall piece: timber NAILED OVER a bricked-up window, in
    LAYERS. Same 2.16 x 3.00 footprint as T01-T04's wall pieces.

    T01's panel is split, T02's is parted, T03's is dark, T04's is blown
    open. This one is COVERED, and the layers are the subject: brick
    infill behind, boards across it, a batten holding the boards, and
    torn bills over the lot. A single flat board is a board; four
    thicknesses is a wall somebody keeps having to deal with.
    """
    body = PAINT.block("tw_hd_wall", (2.16, 0.14, 3.00), (0.0, 0.0, 1.50),
                       "wall")
    parts = [
        # The window opening, bricked up in a different bond -- which is
        # the mark that says "this was a window" without drawing one.
        PAINT.block("tw_hd_infill", (1.30, 0.08, 1.60), (-0.10, -0.08, 1.70),
                    "trim"),
        PAINT.block("tw_hd_sill", (1.46, 0.20, 0.12), (-0.10, -0.06, 0.84),
                    "trim"),
    ]
    for i, z in enumerate((1.16, 1.60, 2.04, 2.48)):
        parts.append(PAINT.block("tw_hd_board_%d" % i, (1.42, 0.06, 0.34),
                                 (-0.10, -0.13, z), "accent", "trim"))
    parts.append(PAINT.block("tw_hd_batten", (0.10, 0.09, 1.56),
                             (0.46, -0.17, 1.72), "trim"))
    parts.append(PAINT.block("tw_hd_bill", (0.52, 0.04, 0.66),
                             (-0.54, -0.18, 1.46), "accent", "trim",
                             rotation_z=4.0))
    return body, parts


def awning_gate():
    """Dressing AROUND the engine's opening: a shop awning on a brick
    arch. Soft goods on a hard frame, which no other pack in this set
    has and no house family has either.

    The awning projects in DEPTH and its arms fold back against the
    jambs. Nothing reaches across the opening -- T01's door boss grew
    sideways and overhung the doorway by 0.04 m, the gate caught it, and
    every pack since has grown its dressing toward the player.
    """
    jamb = 0.34
    body = PAINT.block("tw_aw_arch", (DOOR_W + jamb * 2.0, 0.30, 0.34),
                       (0.0, 0.0, DOOR_H + 0.17), "trim")
    parts = []
    for sign, tag in ((-1.0, "l"), (1.0, "r")):
        x = sign * (DOOR_W / 2.0 + jamb / 2.0)
        parts.append(PAINT.block("tw_aw_jamb_%s" % tag,
                                 (jamb, 0.30, DOOR_H),
                                 (x, 0.0, DOOR_H / 2.0)))
        # The folded arm, lying back along its own jamb.
        parts.append(PAINT.block("tw_aw_arm_%s" % tag, (0.10, 0.38, 1.10),
                                 (x, -0.22, DOOR_H - 0.60), "trim"))
    # The canopy, rolled. A DEPLOYED awning over a doorway is a ceiling
    # the player walks under at 2.4 m and a thing art has no business
    # putting in Production's headroom; rolled, it lives above the head
    # of the door where the arch already is.
    parts.append(PAINT.block("tw_aw_roll", (DOOR_W + 0.40, 0.46, 0.30),
                             (0.0, -0.20, DOOR_H + 0.19), "accent", "trim"))
    # AND THE VALANCE HANGS ABOVE THE HEAD, NOT BELOW IT. The first cut
    # put it at DOOR_H + 0.05, so its lower edge sat at 3.14 m -- six
    # centimetres inside the opening -- and the gate refused it by
    # 2.550 m. That is what a valance DOES on a real shopfront, and it
    # is still headroom, and headroom in Production's doorway is
    # Production's. T04's pressure-door coaming is the same lesson at
    # the other end of the same hole.
    parts.append(PAINT.block("tw_aw_valance", (DOOR_W + 0.30, 0.10, 0.20),
                             (0.0, -0.40, DOOR_H + 0.12), "accent", "trim"))
    return body, parts


def tram_track():
    """Floor dressing. T01's grew, T02's fell, T03's was ridden off,
    T04's blew out -- this one was LAID AND THEN NEGLECTED.

    A DISPLACED section, deliberately, and not a continuous track. A
    continuous rail across a floor is infrastructure the player would
    read as walkable, and floor is Production's; a lifted sett and a
    rail end nobody relaid is dressing that says the same thing about
    the place and claims nothing about the ground.
    """
    body = PAINT.block("tw_tt_rail", (1.10, 0.09, 0.08), (0.0, 0.0, 0.04),
                       "trim", rotation_z=4.0)
    parts = [
        PAINT.block("tw_tt_chair", (0.16, 0.26, 0.10), (-0.34, 0.0, 0.05),
                    "trim"),
        PAINT.block("tw_tt_end", (0.22, 0.10, 0.11), (0.60, 0.03, 0.055),
                    "accent", "trim", rotation_z=14.0),
    ]
    #   the setts: one lifted and leaning, the rest still bedded
    for i, (size, at, yaw) in enumerate((
            # Bedded AGAINST the rail, not near it. At -0.22 to -0.28
            # the two furthest setts cleared the rail's own edge by
            # 3-4 cm and `assert_parts_touch` called them floating,
            # which is what they were: a sett that is not touching the
            # rail is a stone lying in a street, and the whole read of
            # this piece is that the rail was BEDDED in them.
            ((0.26, 0.24, 0.07), (-0.58, -0.17, 0.035), 12.0),
            ((0.24, 0.22, 0.06), (-0.26, -0.19, 0.03), -18.0),
            ((0.25, 0.23, 0.13), (0.08, -0.18, 0.065), 26.0),
            ((0.24, 0.22, 0.06), (0.42, -0.17, 0.03), -6.0))):
        parts.append(PAINT.block("tw_tt_sett_%d" % i, size, at, "trim_plain",
                                 "trim", rotation_z=yaw))
    return body, parts


def street_lantern():
    """The light HOUSING: a bracket lantern on a swan neck, one pane
    gone. No light rides along -- `assert_no_emitters` keeps that true
    at build time rather than discovering it at export.

    The missing pane is the tell, and it is a HOLE rather than a
    different colour: the lantern is four uprights and a cap with three
    panes between them, so the fourth face is simply absent. A pane
    painted dark would be a dark pane; an absent one is a lantern
    somebody broke.
    """
    body = PAINT.block("tw_sl_bracket", (0.10, 0.34, 0.10), (0.0, -0.12, 0.92),
                       "trim")
    parts = [
        PAINT.block("tw_sl_neck", (0.09, 0.09, 0.26), (0.0, -0.27, 0.80),
                    "trim"),
        PAINT.block("tw_sl_cap", (0.32, 0.32, 0.10), (0.0, -0.27, 0.66),
                    "trim"),
        PAINT.block("tw_sl_finial", (0.10, 0.10, 0.12), (0.0, -0.27, 0.99),
                    "trim"),
        PAINT.block("tw_sl_base", (0.26, 0.26, 0.08), (0.0, -0.27, 0.26),
                    "trim"),
    ]
    # Three panes of four. The gap is at -Y, the face that meets the
    # street, because a pane nobody can see is broken for no one.
    for tag, size, at in (
            ("l", (0.05, 0.24, 0.32), (-0.13, -0.27, 0.46)),
            ("r", (0.05, 0.24, 0.32), (0.13, -0.27, 0.46)),
            ("b", (0.24, 0.05, 0.32), (0.0, -0.15, 0.46))):
        parts.append(PAINT.block("tw_sl_pane_%s" % tag, size, at,
                                 "accent", "trim"))
    return body, parts


def tram_call():
    """Batch 043's wall-switch contract as a TRAM CALL PLATE.

    Same envelope and the same place on the same wall as T01's timber
    switch, T02's winding key, T03's ticket validator and T04's dogging
    lever -- the one control a player must recognise, recognisably the
    same control five times in five material cultures.

    The state a player reads is the PULL's position in its slot, and the
    cast surround is what says this is municipal rather than somebody's
    doorbell.
    """
    body = PAINT.block("tw_tc_plate", (0.44, 0.08, 0.54), (0.0, 0.0, 0.27),
                       "wall")
    parts = [
        PAINT.block("tw_tc_surround", (0.36, 0.07, 0.42), (0.0, -0.07, 0.29),
                    "trim"),
        PAINT.block("tw_tc_slot", (0.08, 0.06, 0.28), (-0.06, -0.10, 0.30),
                    "accent", "trim"),
        PAINT.block("tw_tc_pull", (0.10, 0.11, 0.10), (-0.06, -0.12, 0.22),
                    "trim"),
        PAINT.block("tw_tc_label", (0.16, 0.05, 0.14), (0.10, -0.10, 0.34),
                    "accent", "trim"),
    ]
    return body, parts


ASSETS = [
    ("tp_tw_alley_buttress", alley_buttress, ["route"]),
    ("tp_tw_hoarding", hoarding, ["emitters", "route"]),
    ("tp_tw_awning_gate", awning_gate, ["opening", "route"]),
    ("tp_tw_tram_track", tram_track, ["route"]),
    ("tp_tw_street_lantern", street_lantern, ["emitters", "route"]),
    ("tp_tw_tram_call", tram_call, ["emitters", "route"]),
]

DISTINCT = {
    "tp_tw_alley_buttress": "a brick pier that carries a WIRE, not a roof: "
                            "corbelled, with a catenary bracket and stay",
    "tp_tw_hoarding": "the wall is COVERED, in four thicknesses -- brick "
                      "infill, boards, batten, torn bills -- where one flat "
                      "board would just be a board",
    "tp_tw_awning_gate": "SOFT GOODS on a hard frame: a rolled shop awning "
                         "and its folded arms, which no other pack and no "
                         "house family has",
    "tp_tw_tram_track": "floor dressing that was LAID AND THEN NEGLECTED -- "
                        "a DISPLACED section with a lifted sett, never a "
                        "continuous rail, because continuous rail reads as "
                        "walkable infrastructure and floor is Production's",
    "tp_tw_street_lantern": "one pane of four simply ABSENT; a dark pane is "
                            "a dark pane, a hole is a lantern somebody broke",
    "tp_tw_tram_call": "batch043's wall-switch contract as a municipal tram "
                       "call: a pull in a slot, in a cast surround",
}


def main():
    packkit.build(ASSETS, OUT, PAINT, DISTINCT, {
        "batch": "059",
        "kind": "theme_pack_content",
        "pack": "tp_kingdom_hearts_2",
        "subtheme": "TWILIGHT TOWN, THE SERVICE ALLEY BEHIND TRAM COMMON "
                    "-- brick piers carrying tram cable, a hoarding nailed "
                    "over a bricked-up window, a shop awning, and a length "
                    "of rail nobody has relaid",
        "subtheme_is_a_choice": "Kingdom Hearts 2 has a dozen worlds and "
                                "three of them are whole architectures on "
                                "their own. Blending Twilight Town, Hollow "
                                "Bastion and The World That Never Was is "
                                "the average the owner ruled out.",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "painted_with": THEME,
        "theme_hint_says": THEME_HINT,
        "theme_hint_coverage": "NONE. Constants.THEME_BY_GAME_HINT holds 6 "
                               "entries against 81 catalogued games, and "
                               "this is one of the 75 without. See "
                               "docs/art/theme-packs/COVERAGE.md section 2.",
        "shares_family_with": "tp_ocarina_of_time (T01), deliberately. The "
                              "owner's completion criteria say reuse is "
                              "encouraged and a useful variant is not a "
                              "duplicate merely because its construction is "
                              "shared. Two packs in one family, in one "
                              "shell, under the same four cameras, is the "
                              "TEST of that claim rather than an accident "
                              "of it.",
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
    }, log="twilight")


if __name__ == "__main__":
    main()
