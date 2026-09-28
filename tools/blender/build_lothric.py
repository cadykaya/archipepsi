"""Batch 061 -- T07, the seventh game pack's CONTENT. Dark Souls III.

    .tools/blender/blender -b --python tools/blender/build_lothric.py

## The subtheme is chosen, and saying which is half the job

Dark Souls III has a dozen regions. **This pack is THE HIGH WALL OF
LOTHRIC, THE AQUEDUCT RUN** -- stepped ashlar piers with half-arches
springing off them, a channel that no longer carries water, fallen
voussoirs still keyed to each other, and the braziers that are the only
warm thing in it.

Not Irithyll, not Anor Londo, not Archdragon Peak. Those are three more
architectures and blending them is the average the owner ruled out. The
packet's concept for T07 is "Cinder Aqueduct", which names this already.

## THIS IS THE LAST PACK WITH A FAMILY OF ITS OWN

T06 counted the runway and said two. **It is one, and this is it.**

    temple_ruin        T01, T05      doubled -- T05 is the proof
    rusted_industrial  T02, T04      doubled
    neon_transit       T03
    concrete_facility  T06
    gothic_stone       T07           <- this one
    void_glitch        UNUSABLE

`void_glitch` is not a sixth option. It is Archipepsi's own
missing-texture theme -- an editor checkerboard with the word "null"
written across it -- and `THEME_BY_GAME_HINT` maps it to Archipepsi
itself. Painting The Wind Waker in it would not be a pack wearing
another pack's clothes; it would be a pack wearing the clothes that mean
"this texture failed to load".

**So the workaround ends here, not at T08. Every pack from T08 on must
share pixels with an earlier pack, or wait for the namespace.** 74 packs
are behind this one. See `COVERAGE.md` section 3.

## The hint agrees, which is the third time in seven

`Constants.THEME_BY_GAME_HINT` maps Dark Souls III to `gothic_stone`, and
`gothic_stone` is also the nearest family by material culture. Running
tally across seven packs: agree, **disagree**, agree, none, none, none,
agree. Six of 81 games are hinted at all.

## The band, checked before it was used

`gothic_stone`'s `trim` carries no hazard semantics -- only
`rusted_industrial` splits `trim` from `trim_plain` -- and its `accent`
is a bolted panel rather than a stencil or a warning. Both are safe and
both are used deliberately.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import packgates  # noqa: E402
import packkit  # noqa: E402

THEME = "gothic_stone"
THEME_HINT = "gothic_stone"
OUT = "batch061/lothric"
SIZE = packkit.SIZE
DENSITY = packkit.DENSITY
PAINT = packkit.Painter(THEME, "ds")

DOOR_W = packgates.DOOR_W
DOOR_H = packgates.DOOR_H


# --------------------------------------------------------------- assets

def buttress_pier():
    """A pier that reaches SIDEWAYS. Every other column in this set
    carries a load straight down -- a roof, a torque, a cable, a hull, a
    wire, a rack of cards. This one carries THRUST, and the half-arch
    springing off its shoulder is the whole difference.

    The half-arch is a wedge, because a voussoir is a wedge and a
    buttress is voussoirs. DESIGN 3.4: a room built only from
    axis-aligned cubes reads as Minecraft.
    """
    h = 3.6
    body = PAINT.block("ds_bp_shaft", (0.48, 0.48, h), (0.0, 0.0, h / 2.0),
                       "wall")
    parts = [
        PAINT.block("ds_bp_plinth", (0.78, 0.78, 0.30), (0.0, 0.0, 0.15),
                    "trim"),
        PAINT.block("ds_bp_offset", (0.62, 0.62, 0.16), (0.0, 0.0, 1.30),
                    "trim"),
        PAINT.block("ds_bp_cap", (0.70, 0.70, 0.22), (0.0, 0.0, 3.49),
                    "trim"),
        # ONE springing, not two. The first cut stepped two wedges away
        # from the pier and in `DS_chamber` they read as a staircase
        # hanging in mid-air: a flying buttress is a CONTINUOUS ramp
        # from high at the pier to low where it lands, and two steps of
        # it are two steps. `assert_parts_touch` was satisfied by the
        # pair -- they overlapped by 14 cm -- which is the point worth
        # keeping: a gate can only say a thing is attached, never that
        # it is legible.
        PAINT.wedge("ds_bp_spring", (0.34, 1.34, 0.76),
                    (0.0, -0.81, 2.62), "accent", "trim", axis="y"),
        PAINT.block("ds_bp_haunch", (0.40, 0.30, 0.34), (0.0, -0.30, 2.83),
                    "trim"),
    ]
    return body, parts


def aqueduct_wall():
    """The wall piece: a wall that CARRIED WATER and no longer does.
    Same 2.16 x 3.00 footprint as T01-T06's.

    T01's is split, T02's parted, T03's dark, T04's blown open, T05's
    covered, T06's wired. This one is BROKEN MID-RUN -- the channel's
    lip crosses it and stops, and the corbels under it keep going past
    where the channel ended.

    The corbels are the subject. A broken channel is a broken channel;
    corbels continuing past the break are a channel that USED to go
    further, which is a much longer sentence about the place.
    """
    body = PAINT.block("ds_aw_face", (2.16, 0.16, 3.00), (0.0, 0.0, 1.50),
                       "wall")
    parts = [
        PAINT.block("ds_aw_string", (2.16, 0.30, 0.18), (0.0, -0.07, 1.34),
                    "trim"),
        # The channel: a floor and a lip, ending 0.4 m short of the
        # right-hand edge.
        PAINT.block("ds_aw_channel", (1.60, 0.44, 0.14), (-0.26, -0.16, 1.60),
                    "trim"),
        PAINT.block("ds_aw_lip", (1.60, 0.10, 0.34), (-0.26, -0.33, 1.78),
                    "accent", "trim"),
        # The break: a wedge where the last stone tore out.
        PAINT.wedge("ds_aw_break", (0.34, 0.42, 0.30), (0.62, -0.18, 1.72),
                    "trim", "trim", axis="x"),
    ]
    # Corbels, continuing PAST the break -- two under the channel, one
    # beyond where it stops.
    for i, x in enumerate((-0.72, 0.02, 0.80)):
        parts.append(PAINT.wedge("ds_aw_corbel_%d" % i, (0.26, 0.36, 0.26),
                                 (x, -0.16, 1.32), "trim", "trim", axis="y"))
    return body, parts


def iron_door_arch():
    """Dressing AROUND the engine's opening: a pointed arch with iron
    strap bands.

    A POINTED arch on a rectangular hole is the honest version of this.
    The opening is 2.4 x 3.2 and rectangular because
    `chamber_builders.gd` says so; art does not get to round its
    corners. What art can do is put the arch ABOVE the head, where a
    relieving arch actually sits, and run the jambs plainly below it --
    which is also how a real wall carries a square opening under a
    pointed one.

    Nothing reaches across the opening and nothing hangs below its head.
    Four refusals across six packs taught the shape of a legal surround:
    T01's boss grew sideways into it, T04's coaming laid floor in it,
    T05's valance hung into it, and T03's guide lip taught the gate a
    millimetre.
    """
    jamb = 0.34
    body = PAINT.block("ds_id_impost", (DOOR_W + jamb * 2.0, 0.34, 0.26),
                       (0.0, 0.0, DOOR_H + 0.13), "trim")
    parts = []
    for sign, tag in ((-1.0, "l"), (1.0, "r")):
        x = sign * (DOOR_W / 2.0 + jamb / 2.0)
        parts.append(PAINT.block("ds_id_jamb_%s" % tag,
                                 (jamb, 0.34, DOOR_H),
                                 (x, 0.0, DOOR_H / 2.0)))
        # The strap band and its ring, projecting in DEPTH.
        parts.append(PAINT.block("ds_id_strap_%s" % tag, (jamb, 0.48, 0.16),
                                 (x, 0.0, 1.10), "accent", "trim"))
        # The springer: a wedge rising toward the centre, so the two
        # together read as the start of a point.
        # AT DOOR_H + 0.28, NOT + 0.37. At +0.37 the springers topped
        # out at 3.68 m against a 3.60 m corridor, and the new
        # `assert_fits_corridor` caught it -- a gate that exists
        # BECAUSE T02, T03 and T07 all made this mistake and only a
        # human reading the manifest's `size` field ever noticed. The
        # 0.40 m between the door head and the ceiling is all the room
        # a surround gets, and it has to hold a lintel too.
        parts.append(PAINT.wedge("ds_id_springer_%s" % tag,
                                 (0.52, 0.34, 0.18),
                                 (sign * 0.86, 0.0, DOOR_H + 0.28),
                                 "trim", "trim", axis="x",
                                 rotation_z=0.0 if sign < 0 else 180.0))
    return body, parts


def fallen_voussoir():
    """Floor dressing that COLLAPSED and still shows the joint.

    T01's grew, T02's fell, T03's was ridden off, T04's blew out, T05's
    was laid and neglected, T06's contains something. This one came down
    as an arch comes down: wedges, and two of them still keyed to each
    other because an arch fails as a unit before it fails as stones.

    That pair is the subject. Loose wedges on a floor are rubble; two
    still locked at the joint are an ARCH that fell.
    """
    # THE KEYED PAIR STANDS PROUD AND THE LOOSE ONES LIE FLAT, and the
    # no-foothold rule is what settled it. At 0.34 m deep a voussoir
    # turned 12 degrees measures 0.48 x 0.42 in plan at 0.22 m tall,
    # which is above the 0.12 m walk-up and inside the jump: a step.
    # 0.24 m deep is a real arch-stone proportion and measures 0.32 in
    # the short axis, so the pair keeps its height. The loose stones
    # could not be narrowed enough at any believable proportion, so they
    # lie at 0.11 m -- under the walk-up, and flat is what a stone that
    # bounced does anyway. The rule improved the composition: two
    # standing and two down reads as a collapse, four standing reads as
    # a display.
    body = PAINT.wedge("ds_fv_keyed_a", (0.42, 0.24, 0.22), (0.0, 0.0, 0.11),
                       "trim", "trim", axis="y", rotation_z=12.0)
    parts = [
        PAINT.wedge("ds_fv_keyed_b", (0.40, 0.24, 0.20), (0.34, -0.06, 0.10),
                    "trim", "trim", axis="y", rotation_z=-168.0),
        PAINT.wedge("ds_fv_loose_a", (0.34, 0.28, 0.11), (-0.36, 0.08, 0.055),
                    "trim", "trim", axis="y", rotation_z=54.0),
        PAINT.wedge("ds_fv_loose_b", (0.30, 0.26, 0.11), (0.66, 0.12, 0.055),
                    "accent", "trim", axis="y", rotation_z=-36.0),
        PAINT.block("ds_fv_chip", (0.20, 0.16, 0.07), (0.24, 0.22, 0.035),
                    "trim", rotation_z=22.0),
        PAINT.block("ds_fv_dust", (0.56, 0.38, 0.02), (0.16, 0.06, 0.01),
                    "trim_plain", "trim", rotation_z=-8.0),
    ]
    return body, parts


def brazier():
    """The light HOUSING -- and it stands ON THE FLOOR.

    Every other pack in this set hangs its light on a wall: an alcove, a
    pendulum, a batten, a caged lamp, a bracket lantern, a recess. This
    one is a tripod with a grate bowl, and it is the only fitting in
    seven packs a player could walk around.

    No fire rides along. `assert_no_emitters` keeps that true at build
    time rather than discovering it at export -- the bowl is the housing
    and the flame is the engine's.
    """
    # THE BOWL SITS ABOVE THE JUMP, and the no-foothold rule is why.
    # At 0.86 m a 0.54 m bowl is a 0.47 x 0.54 upward face inside the
    # 1.33 m jump, so a player stands in the fire. Raising it to 1.40 m, where it MEETS the column top
    # puts its top at 1.51, past where the rule cares -- and a brazier
    # at head height on a stand is what Lothric's actually are, so the
    # rule pushed this toward the source rather than away from it.
    body = PAINT.block("ds_br_column", (0.16, 0.16, 1.30), (0.0, 0.0, 0.65),
                       "trim")
    parts = []
    for i, yaw in enumerate((0.0, 120.0, 240.0)):
        parts.append(PAINT.block("ds_br_leg_%d" % i, (0.10, 0.44, 0.30),
                                 (0.0, -0.16, 0.15), "trim",
                                 rotation_z=yaw))
    parts += PAINT.wheel("ds_br_bowl", 0.54, 0.22, (0.0, 0.0, 1.40),
                         "accent", "trim", sides=6)
    parts += PAINT.wheel("ds_br_embers", 0.40, 0.08, (0.0, 0.0, 1.46),
                         "trim_plain", "trim", sides=6)
    return body, parts


def lever_stone():
    """Batch 043's wall-switch contract CARVED INTO THE MASONRY.

    Same envelope and the same place on the same wall as T01's timber
    switch, T02's winding key, T03's ticket validator, T04's dogging
    lever, T05's tram call and T06's keycard reader -- the one control a
    player must recognise, recognisably the same control seven times in
    seven material cultures.

    The state a player reads is the iron's angle in its slot. The
    difference from T04's dogging lever, which is also a lever, is that
    this one has no housing: the recess IS the housing, cut out of the
    wall, because a gothic wall does not get a bolted-on box.
    """
    body = PAINT.block("ds_ls_face", (0.46, 0.10, 0.54), (0.0, 0.0, 0.27),
                       "wall")
    parts = [
        PAINT.block("ds_ls_recess", (0.32, 0.09, 0.40), (0.0, 0.05, 0.28),
                    "trim"),
        PAINT.wedge("ds_ls_sill", (0.36, 0.14, 0.10), (0.0, -0.04, 0.05),
                    "trim", "trim", axis="y"),
        PAINT.block("ds_ls_iron", (0.26, 0.06, 0.06), (0.02, -0.03, 0.30),
                    "accent", "trim", rotation_z=0.0),
        PAINT.block("ds_ls_grip", (0.08, 0.08, 0.14), (0.13, -0.03, 0.30),
                    "trim"),
    ]
    return body, parts


ASSETS = [
    ("tp_ds_buttress_pier", buttress_pier, ["route"]),
    ("tp_ds_aqueduct_wall", aqueduct_wall, ["emitters", "route"]),
    ("tp_ds_iron_door_arch", iron_door_arch, ["opening", "route"]),
    ("tp_ds_fallen_voussoir", fallen_voussoir, ["route"]),
    ("tp_ds_brazier", brazier, ["emitters", "route"]),
    ("tp_ds_lever_stone", lever_stone, ["emitters", "route"]),
]

DISTINCT = {
    "tp_ds_buttress_pier": "a pier that reaches SIDEWAYS: it carries thrust, "
                           "and every other column in the set carries load "
                           "straight down",
    "tp_ds_aqueduct_wall": "a wall that CARRIED WATER -- and the corbels "
                           "continue PAST the break, which says the channel "
                           "used to go further",
    "tp_ds_iron_door_arch": "a pointed arch ABOVE a square head, which is "
                            "how a real wall carries a rectangular opening "
                            "under a pointed one -- plus iron straps",
    "tp_ds_fallen_voussoir": "floor dressing that COLLAPSED with two stones "
                             "STILL KEYED to each other: loose wedges are "
                             "rubble, a keyed pair is an arch that fell",
    "tp_ds_brazier": "the only light in seven packs that stands ON THE "
                     "FLOOR and can be walked around",
    "tp_ds_lever_stone": "batch043's wall-switch contract CARVED IN: the "
                         "recess is the housing, because a gothic wall does "
                         "not get a bolted-on box",
}


def main():
    packkit.build(ASSETS, OUT, PAINT, DISTINCT, {
        "batch": "061",
        "kind": "theme_pack_content",
        "pack": "tp_dark_souls_iii",
        "subtheme": "THE HIGH WALL OF LOTHRIC, THE AQUEDUCT RUN -- stepped "
                    "ashlar piers with half-arches springing off them, a "
                    "channel that no longer carries water, fallen voussoirs "
                    "still keyed to each other, and braziers",
        "subtheme_is_a_choice": "Dark Souls III has a dozen regions and "
                                "Irithyll, Anor Londo and Archdragon Peak "
                                "are three more architectures. Blending "
                                "them is the average the owner ruled out.",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "painted_with": THEME,
        "theme_hint_says": THEME_HINT,
        "theme_hint_agrees": "Yes -- the third agreement in seven packs. "
                             "Running tally: T01 agree, T02 DISAGREE, T03 "
                             "agree, T04/T05/T06 no hint at all, T07 agree. "
                             "Six of 81 games are hinted.",
        "family_runway": "EXHAUSTED. This is the last pack with a house "
                         "family of its own. T06 counted two remaining and "
                         "was wrong: void_glitch is not an option. It is "
                         "Archipepsi's own missing-texture theme -- an "
                         "editor checkerboard with the word 'null' across "
                         "it -- and THEME_BY_GAME_HINT maps it to "
                         "Archipepsi itself. Painting a game pack in it "
                         "would mean 'this texture failed to load'. So "
                         "every pack from T08 on must share pixels with an "
                         "earlier pack or wait for the namespace, and 74 "
                         "packs are behind this one. See "
                         "docs/art/theme-packs/COVERAGE.md section 3.",
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
    }, log="lothric")


if __name__ == "__main__":
    main()
