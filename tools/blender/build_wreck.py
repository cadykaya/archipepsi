"""Batch 058 -- T04, the fourth game pack's CONTENT. Super Metroid.

    .tools/blender/blender -b --python tools/blender/build_wreck.py

## The subtheme is chosen, and saying which is half the job

Super Metroid has six regions. **This pack is the WRECKED SHIP** -- the
derelict: corroded frame members, a hull panel blown open, a pressure
door nobody dogged shut, and the plating that came out with the blast.

Not Brinstar, not Norfair, not Maridia. Those are CAVES, and a cave is
terrain. The Wrecked Ship is the one region of that game which is
architecture, and architecture is what a theme pack ships. The packet's
concept for T04 is "Pressureworks Derelict", which is the same choice
made in other words.

## THIS IS THE FIRST PACK WITH NO HINT AT ALL, and that is the finding

`Constants.THEME_BY_GAME_HINT` holds **six** entries -- Super Mario 64,
Ocarina of Time, Bomb Rush Cyberfunk, Dark Souls III, Borderlands 2 and
Archipepsi. The catalogue holds **81 games**.

**So 75 of 81 have no hint, and Super Metroid is one of them.**

T01 and T03 found the hint agreeing with the pack's material culture and
T02 found it disagreeing, which is already an argument. This is sharper:
for nine games in ten there is nothing to agree or disagree with. A
selection mechanism that covers 7% of the catalogue is not a mechanism
with an exception in it; it is a mechanism for six games. Recorded as
`theme_hint_says: null` with the count, so the gap is a number in the
manifest rather than a sentence in a report.

## The hazard band MEANS something here, which is the contrast with T02

`rusted_industrial`'s `trim` paints a universal hazard band, correct on a
walkway edge, a machinery boundary, a drop or a warning surface. T02
reached for that family and had to refuse the band everywhere, because
nothing in a clock room is a hazard boundary.

**A derelict ship is nothing but hazard boundaries.** The pressure door's
threshold, the lamp cage, the severed conduit -- those are exactly the
surfaces the band was written for, and this pack uses it on those and
`trim_plain` on everything else. Same family as T02, opposite answer,
and the difference is the geometry rather than the taste.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import packgates  # noqa: E402
import packkit  # noqa: E402

THEME = "rusted_industrial"
#: There is none. See the module docstring -- 75 of 81 catalogued games
#: are in the same position and that is the point.
THEME_HINT = None
OUT = "batch058/wreck"
SIZE = packkit.SIZE
DENSITY = packkit.DENSITY
PAINT = packkit.Painter(THEME, "ws")

DOOR_W = packgates.DOOR_W
DOOR_H = packgates.DOOR_H


# --------------------------------------------------------------- assets

def stanchion():
    """A ship's frame member, not a building's column. It carries a hull,
    so it is ribbed and boxed rather than round -- and something has
    burst out of it at shoulder height and never been repaired.

    The burst is the tell. A corroded column is a corroded column in any
    derelict; a column with its own service run torn out of it is a
    column that was PART OF SOMETHING.
    """
    h = 3.6
    body = PAINT.block("ws_st_web", (0.30, 0.46, h), (0.0, 0.0, h / 2.0),
                       "wall")
    parts = [
        PAINT.block("ws_st_flange_f", (0.52, 0.10, h), (0.0, -0.26, h / 2.0),
                    "trim_plain", "trim"),
        PAINT.block("ws_st_flange_b", (0.52, 0.10, h), (0.0, 0.26, h / 2.0),
                    "trim_plain", "trim"),
        PAINT.block("ws_st_foot", (0.74, 0.74, 0.18), (0.0, 0.0, 0.09),
                    "trim_plain", "trim"),
        # The burst: a torn conduit stub and the run it came out of.
        PAINT.block("ws_st_conduit", (0.16, 0.16, 1.30), (0.0, -0.33, 2.15),
                    "trim_plain", "trim"),
        PAINT.block("ws_st_tear", (0.26, 0.30, 0.22), (0.0, -0.36, 1.52),
                    "trim"),
        PAINT.block("ws_st_spill", (0.13, 0.42, 0.13), (0.0, -0.48, 1.40),
                    "trim", rotation_z=18.0),
    ]
    return body, parts


def bulkhead_panel():
    """The wall piece, BLOWN OPEN. Same 2.16 x 3.00 footprint as T01's
    relief, T02's movement and T03's board.

    T01's panel is split, T02's is parted, T03's is dark. This one has
    had its inspection hatch let go -- the hatch hangs on one hinge and
    the conduit behind it is severed. The subject is the HINGE, because
    a hatch lying on the floor is debris and a hatch still attached is
    an accident.
    """
    body = PAINT.block("ws_bp_hull", (2.16, 0.14, 3.00), (0.0, 0.0, 1.50),
                       "wall")
    parts = [
        PAINT.block("ws_bp_rib_low", (2.16, 0.22, 0.16), (0.0, -0.04, 0.52),
                    "trim_plain", "trim"),
        PAINT.block("ws_bp_rib_high", (2.16, 0.22, 0.16), (0.0, -0.04, 2.56),
                    "trim_plain", "trim"),
        # The pocket the hatch came off.
        PAINT.block("ws_bp_pocket", (0.96, 0.10, 0.88), (-0.28, 0.02, 1.62),
                    "trim_plain", "trim"),
        PAINT.block("ws_bp_hinge", (0.10, 0.20, 0.88), (0.22, -0.10, 1.62),
                    "trim_plain", "trim"),
        # The hatch itself, swung out and hanging.
        PAINT.block("ws_bp_hatch", (0.92, 0.12, 0.84), (0.60, -0.34, 1.58),
                    "trim_plain", "trim", rotation_z=24.0),
        # Severed conduit ends inside the pocket. THESE get the band:
        # a cut service run is exactly the surface it was written for.
        PAINT.block("ws_bp_cut", (0.62, 0.14, 0.13), (-0.30, -0.06, 1.36),
                    "trim"),
    ]
    return body, parts


def pressure_door():
    """Dressing AROUND the engine's opening: a pressure boundary.

    Dogging lugs up the jambs, and a banded cheek at the foot of each
    one -- the hazard colour doing its literal job, because a pressure
    threshold is a real trip hazard and a real ship marks it.

    THE COAMING ITSELF IS NOT HERE and the comment below says why: a
    raised sill across the doorway is floor, floor is Production's, and
    the gate refused the first cut of it by 2.74 m.

    The lugs project in DEPTH, out of the wall. T01's door boss grew
    sideways and overhung the doorway by 0.04 m; the gate caught it and
    was right, and it is the reason every pack since has grown its
    dressing toward the player instead.
    """
    jamb = 0.34
    body = PAINT.block("ws_pd_head", (DOOR_W + jamb * 2.0, 0.32, 0.34),
                       (0.0, 0.0, DOOR_H + 0.17), "trim_plain", "trim")
    parts = []
    for sign, tag in ((-1.0, "l"), (1.0, "r")):
        x = sign * (DOOR_W / 2.0 + jamb / 2.0)
        parts.append(PAINT.block("ws_pd_jamb_%s" % tag,
                                 (jamb, 0.32, DOOR_H),
                                 (x, 0.0, DOOR_H / 2.0)))
        for i, z in enumerate((0.70, 1.60, 2.50)):
            parts.append(PAINT.block("ws_pd_lug_%s%d" % (tag, i),
                                     (jamb, 0.48, 0.20), (x, 0.0, z),
                                     "trim_plain", "trim"))
        # THE COAMING IS THE ONE PART OF A PRESSURE DOOR ART CANNOT SHIP.
        # A real one has a raised sill you step over, and the first cut
        # of this asset had one: 0.10 m tall, the full width, right
        # across the doorway. The gate refused it by 2.740 m and was
        # right to. It does not narrow the opening's WIDTH; it lays
        # floor inside an opening the player walks through, and floor is
        # Production's whatever its height. A 0.10 m step is also under
        # the 0.12 m walk-up, which would have made it invisible to the
        # foothold rule -- so the opening rule is the only thing between
        # a plausible detail and art changing a walking surface.
        #
        # What survives is the MARK without the step: a banded cheek at
        # the foot of each jamb, outside the opening, saying a threshold
        # is here. If the coaming should exist, it is Production's to
        # place and collide.
        parts.append(PAINT.block("ws_pd_threshold_%s" % tag,
                                 (jamb, 0.44, 0.12), (x, 0.0, 0.06),
                                 "trim"))
    return body, parts


def debris_fan():
    """Floor dressing. T01's grew, T02's fell, T03's was ridden off --
    this one BLEW OUT, so it fans away from a wall rather than lying
    along one.

    The fan is the whole read: three plates at spreading angles with the
    burst pipe that threw them, all pointing back at one origin. A pile
    is a pile; a fan has a direction and the direction is the story.
    """
    body = PAINT.block("ws_df_pipe", (0.90, 0.15, 0.15), (0.0, 0.0, 0.075),
                       "trim_plain", "trim", rotation_z=10.0)
    parts = [
        PAINT.block("ws_df_flare", (0.24, 0.24, 0.20), (-0.44, -0.06, 0.10),
                    "trim"),
    ]
    #    plate       size                 at                  yaw
    for i, (size, at, yaw) in enumerate((
            ((0.52, 0.34, 0.05), (0.52, -0.26, 0.025), 34.0),
            ((0.46, 0.30, 0.05), (0.62, 0.16, 0.025), -22.0),
            ((0.38, 0.26, 0.04), (0.92, -0.06, 0.02), 8.0))):
        parts.append(PAINT.block("ws_df_plate_%d" % i, size, at,
                                 "trim_plain", "trim", rotation_z=yaw))
    parts.append(PAINT.block("ws_df_shard", (0.30, 0.09, 0.07),
                             (0.36, 0.06, 0.035), "trim_plain", "trim",
                             rotation_z=-48.0))
    return body, parts


def lamp_cage():
    """The light HOUSING: a caged emergency lamp on a gimbal bracket,
    hanging off true. No light rides along -- illumination is
    engine-owned and `assert_no_emitters` keeps that true at build time.

    Off true is the tell. A fitting that is straight is a fitting
    somebody maintains; this one took the same blast the hull panel did.
    The cage gets the band, because a cage IS a machinery boundary.
    """
    body = PAINT.block("ws_lc_bracket", (0.26, 0.30, 0.16), (0.0, 0.0, 0.80),
                       "trim_plain", "trim")
    parts = [
        PAINT.block("ws_lc_gimbal", (0.10, 0.10, 0.18), (0.0, -0.14, 0.70),
                    "trim_plain", "trim"),
        # 0.24 and not 0.30, and the cage bars 0.28 and not 0.34: at
        # 16 degrees a 0.30 box measures 0.37 m in plan and a 0.34 one
        # measures 0.42, and the no-foothold rule counts anything 0.35
        # square above the 0.12 m walk-up. Nothing here is tall enough
        # to cover itself. The lamp hangs on a wall at 2.5 m in the
        # room, so in WORLD terms it is not a step -- but the gate
        # measures the asset's own frame and cannot know where it will
        # be hung, which is the correct thing for it to do. Shrinking a
        # lamp is cheaper than an exception.
        PAINT.block("ws_lc_body", (0.24, 0.24, 0.28), (0.0, -0.20, 0.50),
                    "trim_plain", "trim", rotation_z=16.0),
        PAINT.block("ws_lc_glass", (0.16, 0.10, 0.18), (0.0, -0.30, 0.50),
                    "wall", "trim", rotation_z=16.0),
    ]
    for i, z in enumerate((0.40, 0.50, 0.60)):
        parts.append(PAINT.block("ws_lc_bar_%d" % i, (0.28, 0.28, 0.03),
                                 (0.0, -0.20, z), "trim", rotation_z=16.0))
    return body, parts


def dogging_lever():
    """Batch 043's wall-switch contract as a DOGGING LEVER.

    Same envelope and the same place on the same wall as T01's timber
    switch, T02's winding key and T03's ticket validator -- the one
    control a player must recognise, recognisably the same control four
    times in four material cultures.

    The state a player reads is the lever's throw, and the pocket it
    sits in is what says a passing hull does not knock it open.
    """
    body = PAINT.block("ws_dl_pocket", (0.46, 0.10, 0.54), (0.0, 0.0, 0.27),
                       "wall")
    parts = [
        PAINT.block("ws_dl_reveal", (0.34, 0.08, 0.40), (0.0, -0.06, 0.28),
                    "trim_plain", "trim"),
        PAINT.block("ws_dl_quadrant", (0.26, 0.06, 0.26), (0.0, -0.10, 0.30),
                    "trim_plain", "trim"),
        PAINT.block("ws_dl_lever", (0.28, 0.07, 0.07), (0.02, -0.13, 0.24),
                    "trim", rotation_z=0.0),
        PAINT.block("ws_dl_knob", (0.09, 0.09, 0.09), (0.14, -0.13, 0.24),
                    "trim_plain", "trim"),
    ]
    return body, parts


ASSETS = [
    ("tp_ws_stanchion", stanchion, ["route"]),
    ("tp_ws_bulkhead_panel", bulkhead_panel, ["emitters", "route"]),
    ("tp_ws_pressure_door", pressure_door, ["opening", "route"]),
    ("tp_ws_debris_fan", debris_fan, ["route"]),
    ("tp_ws_lamp_cage", lamp_cage, ["emitters", "route"]),
    ("tp_ws_dogging_lever", dogging_lever, ["emitters", "route"]),
]

DISTINCT = {
    "tp_ws_stanchion": "a ship's FRAME MEMBER with its own service run "
                       "burst out of it -- boxed and flanged, never round",
    "tp_ws_bulkhead_panel": "the inspection hatch let go and is still on one "
                            "HINGE; a hatch on the floor is debris, a hatch "
                            "still attached is an accident",
    "tp_ws_pressure_door": "the opening is dressed as a PRESSURE BOUNDARY: "
                           "dogging lugs, seal channel, marked threshold",
    "tp_ws_debris_fan": "floor dressing that BLEW OUT -- plates at spreading "
                        "angles all pointing back at one origin, where a "
                        "pile would point at nothing",
    "tp_ws_lamp_cage": "a caged emergency lamp hanging OFF TRUE; a straight "
                       "fitting is one somebody maintains",
    "tp_ws_dogging_lever": "batch043's wall-switch contract as a dogging "
                           "lever in a recessed pocket -- thrown, not pressed",
}


def main():
    packkit.build(ASSETS, OUT, PAINT, DISTINCT, {
        "batch": "058",
        "kind": "theme_pack_content",
        "pack": "tp_super_metroid",
        "subtheme": "THE WRECKED SHIP -- the derelict: corroded frame "
                    "members, a hull panel blown open, a pressure door "
                    "nobody dogged shut, and the plating that came out "
                    "with the blast",
        "subtheme_is_a_choice": "Super Metroid has six regions and five of "
                                "them are CAVES, which is terrain. The "
                                "Wrecked Ship is the one that is "
                                "architecture, and architecture is what a "
                                "theme pack ships.",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "painted_with": THEME,
        "theme_hint_says": THEME_HINT,
        "theme_hint_coverage": "NONE. Constants.THEME_BY_GAME_HINT holds 6 "
                               "entries and the catalogue holds 81 games, "
                               "so 75 of 81 -- including this one -- have "
                               "no hint at all. A selection mechanism "
                               "covering 7% of the catalogue is not a "
                               "mechanism with an exception in it. See "
                               "docs/art/theme-packs/COVERAGE.md section 2.",
        "hazard_band": "USED, and deliberately. rusted_industrial's `trim` "
                       "is the universal hazard band; T02 reached for this "
                       "family and had to refuse it everywhere because a "
                       "clock room has no hazard boundaries. A derelict is "
                       "nothing but hazard boundaries -- the pressure "
                       "threshold, the lamp cage, the severed conduit -- so "
                       "those carry the band and everything else carries "
                       "`trim_plain`.",
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
    }, log="wreck")


if __name__ == "__main__":
    main()
