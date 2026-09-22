"""Batch 060 -- T06, the sixth game pack's CONTENT. DOOM 1993.

    .tools/blender/blender -b --python tools/blender/build_foundry.py

## The subtheme is chosen, and saying which is half the job

DOOM 1993 has three episodes and they are three different places: a
techbase, a military installation and Hell. **This pack is THE UAC
TECHBASE, CONTAINMENT LEVEL** -- grey-green plate, computer banks, a
containment trough with its grating lifted, and the recessed light
panels that are the game's real architectural signature.

Not Hell. Hell is the famous half and it is also the half that is
TERRAIN -- rock, flesh, fire. The techbase is the architecture, and
architecture is what a theme pack ships. The packet's concept for T06 is
"Foundry Containment", which names the same choice.

## THE FAMILY RUNWAY HAS TWO PACKS LEFT IN IT AFTER THIS ONE

T05 proved that two packs sharing a house family read as one place, and
that the shapes cannot save them: `docs/art/review/twilight_2026-09-22/`.
The workaround since has been to give each pack a family nobody has used.

Count it. There are **six** house families. After this pack:

    temple_ruin        T01, T05      (already doubled -- T05 is the proof)
    rusted_industrial  T02, T04      (already doubled)
    neon_transit       T03
    concrete_facility  T06           <- this one
    gothic_stone       --
    void_glitch        --

**Two families are unused. There are 75 packs behind this one.** So the
"pick a family nobody has used" workaround runs out at T08, and every
pack from T09 on must share pixels with an earlier pack or wait.

That is a deadline rather than an opinion, and it is the sharpest form
the namespace argument has taken. See `COVERAGE.md` section 3.

## The band, checked before it was used

`concrete_facility`'s `trim` is an institutional kick rail with no hazard
semantics -- only `rusted_industrial` splits `trim` from `trim_plain`.
And its `accent` is a MARKED surface, not a painted one: its own
docstring says a colour that marks everything marks nothing. So the
accent is spent where DOOM spends it -- the blast frame's chevrons and
the keycard reader -- and nowhere else.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import packgates  # noqa: E402
import packkit  # noqa: E402

THEME = "concrete_facility"
#: Super Mario 64's hint names this family. DOOM 1993 has no hint at all
#: -- one of 75 of 81. See T04's report.
THEME_HINT = None
OUT = "batch060/foundry"
SIZE = packkit.SIZE
DENSITY = packkit.DENSITY
PAINT = packkit.Painter(THEME, "dm")

DOOR_W = packgates.DOOR_W
DOOR_H = packgates.DOOR_H


# --------------------------------------------------------------- assets

def bank_column():
    """A computer bank pilaster: a column you can READ STATE off.

    Every other pack's column carries something -- a roof, a torque, a
    cable, a hull. This one carries INFORMATION, and the card racks
    stepping up it are the only column in the set whose job is to be
    looked at rather than looked past.
    """
    h = 3.6
    body = PAINT.block("dm_bk_case", (0.52, 0.40, h), (0.0, 0.0, h / 2.0),
                       "wall")
    parts = [
        PAINT.block("dm_bk_plinth", (0.74, 0.62, 0.22), (0.0, 0.0, 0.11),
                    "trim"),
        PAINT.block("dm_bk_cap", (0.66, 0.54, 0.16), (0.0, 0.0, 3.52),
                    "trim"),
    ]
    # Four racks, each with its indicator strip recessed behind a lip.
    # The strip is `wall` -- the palest surface the family has -- and
    # NOT `accent`: this family's accent marks significance, and four
    # racks on a column are not four significant things.
    for i, z in enumerate((1.02, 1.62, 2.22, 2.82)):
        parts.append(PAINT.block("dm_bk_rack_%d" % i, (0.60, 0.46, 0.34),
                                 (0.0, -0.05, z), "trim"))
        parts.append(PAINT.block("dm_bk_strip_%d" % i, (0.44, 0.05, 0.08),
                                 (0.0, -0.26, z + 0.09), "wall", "trim"))
    return body, parts


def screen_wall():
    """The wall piece: an INTERFACE. Same 2.16 x 3.00 footprint as
    T01-T05's wall pieces.

    T01's is split, T02's parted, T03's dark, T04's blown open, T05's
    covered over. This one is WIRED -- monitors and patch panels with
    hand-run cable looping below them, and one screen cracked.

    The loops are the subject. A rack of screens is furniture; a rack of
    screens with cable somebody ran by hand and never tidied is a place
    where people were solving something.
    """
    body = PAINT.block("dm_sw_frame", (2.16, 0.16, 3.00), (0.0, 0.0, 1.50),
                       "wall")
    parts = [
        PAINT.block("dm_sw_desk", (2.00, 0.44, 0.14), (0.0, -0.14, 1.02),
                    "trim"),
        PAINT.block("dm_sw_kick", (2.00, 0.20, 0.90), (0.0, -0.04, 0.45),
                    "trim"),
    ]
    for i, (x, z, w) in enumerate((
            (-0.62, 1.86, 0.74), (0.24, 1.86, 0.74), (-0.20, 2.52, 1.10))):
        parts.append(PAINT.block("dm_sw_screen_%d" % i, (w, 0.10, 0.50),
                                 (x, -0.12, z), "trim"))
    # The cracked one, standing a little proud of its bezel because the
    # glass is no longer flush.
    parts.append(PAINT.block("dm_sw_cracked", (0.60, 0.07, 0.38),
                             (0.24, -0.19, 1.86), "wall", "trim",
                             rotation_z=3.0))
    # Hand-run cable, looping. Two segments at opposed angles: one is a
    # cable, two is a loop, and a loop is what says "by hand".
    # They loop just ABOVE THE DESK and drop behind it, which is where
    # hand-run cable actually goes and is also the only place it touches
    # anything: at 1.30 m they hung in free air 6 cm off the nearest
    # part and `assert_parts_touch` said so. A cable that touches
    # nothing is not untidy, it is floating.
    parts.append(PAINT.block("dm_sw_loop_a", (0.62, 0.09, 0.09),
                             (-0.38, -0.30, 1.12), "trim", rotation_z=22.0))
    parts.append(PAINT.block("dm_sw_loop_b", (0.54, 0.09, 0.09),
                             (0.16, -0.30, 1.10), "trim", rotation_z=-28.0))
    return body, parts


def blast_frame():
    """Dressing AROUND the engine's opening: a blast-door frame, marked.

    The chevrons are where this pack spends its `accent`, because
    `concrete_facility`'s accent marks a thing as SIGNIFICANT and a
    blast door is the most significant thing in a containment level.

    Nothing reaches across the opening and nothing hangs below its head.
    T01's boss grew sideways into the doorway, T04's coaming laid floor
    in it and T05's valance hung into it; three refusals, one rule, and
    by now the shape of a legal surround is well understood.
    """
    jamb = 0.34
    body = PAINT.block("dm_bf_header", (DOOR_W + jamb * 2.0, 0.34, 0.36),
                       (0.0, 0.0, DOOR_H + 0.18), "trim")
    parts = []
    for sign, tag in ((-1.0, "l"), (1.0, "r")):
        x = sign * (DOOR_W / 2.0 + jamb / 2.0)
        parts.append(PAINT.block("dm_bf_jamb_%s" % tag,
                                 (jamb, 0.34, DOOR_H),
                                 (x, 0.0, DOOR_H / 2.0)))
        # The chevron block projects in DEPTH, toward the player.
        parts.append(PAINT.block("dm_bf_chevron_%s" % tag,
                                 (jamb, 0.50, 1.40), (x, 0.0, 1.55),
                                 "accent", "trim"))
    # The recessed track the door would slide into, above the head.
    parts.append(PAINT.block("dm_bf_track", (DOOR_W + 0.30, 0.50, 0.14),
                             (0.0, -0.10, DOOR_H + 0.09), "trim"))
    return body, parts


def spill_trough():
    """Floor dressing that CONTAINS something.

    T01's grew, T02's fell, T03's was ridden off, T04's blew out, T05's
    was laid and neglected. This one is a containment trough with its
    grating dragged off and dropped skewed beside it, and a stain
    fanning from the open end.

    The grating is PRESENT and not missing, for the same reason T04's
    hatch is still on one hinge: a cover somebody took off is an event,
    and a hole in a floor is a hole in a floor.
    """
    body = PAINT.block("dm_sp_trough", (1.24, 0.34, 0.11), (0.0, 0.0, 0.055),
                       "trim", rotation_z=3.0)
    parts = [
        PAINT.block("dm_sp_lip_a", (1.24, 0.07, 0.15), (0.0, -0.19, 0.075),
                    "trim", rotation_z=3.0),
        PAINT.block("dm_sp_lip_b", (1.24, 0.07, 0.15), (0.0, 0.19, 0.075),
                    "trim", rotation_z=3.0),
        # DRAGGED OFF AND DROPPED FLAT, not leaned. Leaned it stood
        # 0.16 m in a 0.72 x 0.47 m footprint, which the no-foothold
        # rule counts and is right to: 0.16 m is above the 0.12 m
        # walk-up, so a player stands on it. A 0.66 m grating cannot
        # shrink under the 0.35 m plan limit and `brushkit.block` only
        # turns about Z, so there is no steep lean to be had. Flat and
        # skewed says "somebody took this off" just as well, and the
        # skew is what stops it reading as replaced.
        PAINT.block("dm_sp_grating", (0.66, 0.30, 0.05), (-0.20, -0.32, 0.025),
                    "trim_plain", "trim", rotation_z=-16.0),
        # The stain, fanning from the open end. Thin, so nothing here is
        # a step: 0.02 m is far under the 0.12 m walk-up.
        PAINT.block("dm_sp_stain_a", (0.52, 0.30, 0.02), (0.70, 0.08, 0.01),
                    "trim_plain", "trim", rotation_z=18.0),
        PAINT.block("dm_sp_stain_b", (0.40, 0.24, 0.02), (0.92, -0.12, 0.01),
                    "trim_plain", "trim", rotation_z=-12.0),
    ]
    return body, parts


def light_recess():
    """The light HOUSING, and it is a RECESS rather than a fitting.

    Every other pack in this set hangs its light on a wall: a torch
    alcove, a pendulum, a batten, a caged lamp, a bracket lantern. DOOM's
    signature light is a STEPPED HOLE -- the wall goes back in two or
    three courses and the panel sits at the bottom of it -- and that is
    the one thing this pack has that none of the others could copy.

    No light rides along. `assert_no_emitters` keeps that true at build
    time rather than discovering it at export.
    """
    body = PAINT.block("dm_lr_surround", (1.00, 0.10, 0.80),
                       (0.0, 0.0, 0.40), "wall")
    parts = [
        PAINT.block("dm_lr_step_a", (0.84, 0.12, 0.64), (0.0, 0.08, 0.40),
                    "trim"),
        PAINT.block("dm_lr_step_b", (0.68, 0.12, 0.48), (0.0, 0.18, 0.40),
                    "trim"),
        # The panel itself, at the BACK of the recess -- the palest
        # surface the family has, and unlit, because the light is the
        # engine's.
        PAINT.block("dm_lr_panel", (0.54, 0.06, 0.36), (0.0, 0.26, 0.40),
                    "wall", "trim"),
        PAINT.block("dm_lr_bar", (0.58, 0.05, 0.05), (0.0, 0.21, 0.40),
                    "trim"),
    ]
    return body, parts


def keycard_reader():
    """Batch 043's wall-switch contract as a KEYCARD READER.

    Same envelope and the same place on the same wall as T01's timber
    switch, T02's winding key, T03's ticket validator, T04's dogging
    lever and T05's tram call -- the one control a player must
    recognise, recognisably the same control six times in six material
    cultures.

    The state a player reads is the lamp column beside the slot, and the
    slot's bevel is what says "card" rather than "button". The lamp
    column carries this family's `accent`, because a locked door IS the
    significant thing on a containment level.
    """
    body = PAINT.block("dm_kc_plate", (0.44, 0.08, 0.54), (0.0, 0.0, 0.27),
                       "wall")
    parts = [
        PAINT.block("dm_kc_bevel", (0.30, 0.08, 0.30), (-0.04, -0.07, 0.32),
                    "trim"),
        PAINT.block("dm_kc_slot", (0.20, 0.05, 0.05), (-0.04, -0.11, 0.32),
                    "trim_plain", "trim"),
        PAINT.block("dm_kc_lamps", (0.08, 0.06, 0.30), (0.16, -0.07, 0.32),
                    "accent", "trim"),
        PAINT.block("dm_kc_kick", (0.44, 0.10, 0.08), (0.0, -0.03, 0.04),
                    "trim"),
    ]
    return body, parts


ASSETS = [
    ("tp_dm_bank_column", bank_column, ["route"]),
    ("tp_dm_screen_wall", screen_wall, ["emitters", "route"]),
    ("tp_dm_blast_frame", blast_frame, ["opening", "route"]),
    ("tp_dm_spill_trough", spill_trough, ["route"]),
    ("tp_dm_light_recess", light_recess, ["emitters", "route"]),
    ("tp_dm_keycard_reader", keycard_reader, ["emitters", "route"]),
]

DISTINCT = {
    "tp_dm_bank_column": "a column that carries INFORMATION -- card racks "
                         "with indicator strips, the one column in the set "
                         "whose job is to be looked AT",
    "tp_dm_screen_wall": "the wall is an INTERFACE, and the hand-run cable "
                         "LOOPS are the subject: screens are furniture, "
                         "loops are people solving something",
    "tp_dm_blast_frame": "the opening is dressed as a MARKED blast door, "
                         "and the chevrons are where this family's accent "
                         "is spent because a blast door is the significant "
                         "thing on a containment level",
    "tp_dm_spill_trough": "floor dressing that CONTAINS something, with its "
                          "grating dragged off and dropped SKEWED beside it "
                          "-- a cover somebody took off is an event, a hole "
                          "is a hole",
    "tp_dm_light_recess": "the light is a stepped RECESS, not a fitting on "
                          "a wall; the only pack in the set whose lamp is a "
                          "hole rather than an object",
    "tp_dm_keycard_reader": "batch043's wall-switch contract as a keycard "
                            "reader: a bevelled slot and a lamp column",
}


def main():
    packkit.build(ASSETS, OUT, PAINT, DISTINCT, {
        "batch": "060",
        "kind": "theme_pack_content",
        "pack": "tp_doom_1993",
        "subtheme": "THE UAC TECHBASE, CONTAINMENT LEVEL -- grey-green "
                    "plate, computer banks, a containment trough with its "
                    "grating lifted, and the recessed light panels that are "
                    "the game's real architectural signature",
        "subtheme_is_a_choice": "DOOM 1993 has three episodes and they are "
                                "three different places. Hell is the famous "
                                "half and it is also the half that is "
                                "TERRAIN -- rock, flesh, fire. The techbase "
                                "is the architecture.",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "painted_with": THEME,
        "theme_hint_says": THEME_HINT,
        "theme_hint_coverage": "NONE. Constants.THEME_BY_GAME_HINT holds 6 "
                               "entries against 81 catalogued games, and "
                               "this is one of the 75 without.",
        "family_runway": "TWO PACKS LEFT. T05 proved two packs sharing a "
                         "house family read as one place and that different "
                         "shapes cannot save them. The workaround since has "
                         "been one unused family per pack. There are six "
                         "families: temple_ruin (T01, T05), "
                         "rusted_industrial (T02, T04), neon_transit (T03), "
                         "concrete_facility (T06). gothic_stone and "
                         "void_glitch are unused, and 75 packs remain. The "
                         "workaround runs out at T08 and every pack from "
                         "T09 must share pixels with an earlier one or "
                         "wait. See COVERAGE.md section 3.",
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
    }, log="foundry")


if __name__ == "__main__":
    main()
