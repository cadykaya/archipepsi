"""Batch 056 -- T02, the second game pack's CONTENT. Super Mario 64.

    .tools/blender/blender -b --python tools/blender/build_clockwork.py

## The subtheme is chosen, and saying which is half the job

The owner's scope addition: *"For games with many environments, choose
one coherent initial subtheme and state the choice rather than blending
everything into an average."* Super Mario 64 has fifteen courses.
**This pack is TICK TOCK CLOCK** -- the inside of a running movement:
gear trains, pendulums, dial marks, and a clock hand that came off.

The packet's concept for T02 is "Clockwork Garden", which has two halves.
**This is the clockwork half.** The garden -- Peach's hedged courtyard --
is the deliberate second subtheme and it is NOT built here. Building both
at once would produce the average the owner ruled out; a courtyard and a
movement do not share a material culture and pretending they do is how a
pack stops reading as a place.

Why Tick Tock Clock and not Bob-omb Battlefield, which is the more famous
course: a green hill reads as *no theme at all* in a 1998 shooter's
palette, and the house already owns institutional grey and rusted metal.
A movement is unmistakable from any angle, at any distance, in any light
-- which is the test a pack has to pass.

## The pack is painted in the WRONG family on purpose, and that is a finding

`Constants.THEME_BY_GAME_HINT` maps `"Super Mario 64" -> concrete_facility`.
That is the runtime's answer for this game today. But a clock movement is
brass, steel and oil, and `rusted_industrial` is the nearest existing
family **by material culture** -- so the hint and the subject disagree,
and for T01 they happened to agree.

**That disagreement is the clearest argument yet for the pack namespace**
(`COVERAGE.md` §3): the hint picks a family by GAME, and a pack's
treatment follows what the pack is MADE OF. They are different questions
and today there is only one field to answer both. Recorded in the
manifest as `theme_hint_says` beside `painted_with`, so the mismatch is
data rather than a remark in a report.

Neither is this pack's own treatment. A tint is exactly what the owner
said does not count, and none is claimed.

## Nothing here wears the hazard band, and that is a rule

`rusted_industrial`'s `trim` role paints a **universal hazard band**,
which is correct on a walkway edge, a machinery boundary, a drop or a
warning surface -- and **the colour is never decorative, in any theme,
for any reason**. `trim_plain` exists for exactly this: trim, minus
danger.

The first pass of this pack painted its gear wheels and its door marks
with `trim` and `accent`, and the room showed the cost immediately: a
clock movement wearing warning stripes, and a dial mark stencilled
`hot`. Nothing in a clock room is a hazard boundary, so nothing in this
pack carries the band. They paint `trim_plain` and collide as `trim`,
because `roomcollision.paint_role` knows four classes and
`trim_plain` is not one of them.

**This is the first pack to hit that**, because `temple_ruin` -- T01's
family -- never carried hazard semantics in its trim. Every later pack
that reaches for `rusted_industrial` will hit it too.

## The gates

`packgates` -- shared, because there are eighteen packs in the first wave
and sixty-three behind them. The opening, the emitters and the footholds.
Nothing here is allowed to narrow `chamber_builders.gd`'s 2.4 x 3.2
doorway, carry its own light, or add a step.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import packgates  # noqa: E402
import packkit  # noqa: E402

#: The nearest existing family BY MATERIAL, which is not the family the
#: per-game hint names. See the module docstring -- the disagreement is
#: the point, not an oversight.
THEME = "rusted_industrial"
THEME_HINT = "concrete_facility"
OUT = "batch056/clockwork"
SIZE = packkit.SIZE
DENSITY = packkit.DENSITY
PAINT = packkit.Painter(THEME, "ck")

DOOR_W = packgates.DOOR_W
DOOR_H = packgates.DOOR_H

# --------------------------------------------------------------- assets

def gear_column():
    """A column that is a SHAFT. The house column holds a roof up; this
    one transmits torque, and the wheel hanging off it says so.

    THE FIRST VERSION DID NOT READ AS A GEAR AND THE ROOM SAID SO. It
    stacked three flat discs on the shaft, and a disc on a vertical
    shaft seen from eye height is a horizontal line: in `CK_approach`
    they read as flanges on a pipe. A gear is only a gear FACE ON, so
    the wheel now stands upright on the shaft's side, with a pinion
    meshing below it -- which is also what a clock tower's shaft
    actually carries.

    The wheels sit above 1.65 m, which is the no-foothold rule rather
    than a composition choice: a 1.1 m wheel low on the shaft is a step
    the shaft is far too narrow to cover. Above the 1.33 m jump the rule
    stops caring, and the works belong up where the eye goes anyway.
    """
    h = 3.6
    body = PAINT.block("ck_col_shaft", (0.34, 0.34, h), (0.0, 0.0, h / 2.0), "wall")
    parts = [
        # The plinth is exempt: the shaft rises a full jump above it and
        # leaves no 0.35 m patch to stand on. That exemption is measured
        # by the gate, not asserted here.
        PAINT.block("ck_col_plinth", (0.72, 0.72, 0.22), (0.0, 0.0, 0.11),
           "trim_plain", "trim"),
        PAINT.block("ck_col_bearing", (0.46, 0.46, 0.14), (0.0, 0.0, 3.53),
           "trim_plain", "trim"),
        PAINT.block("ck_col_collar", (0.44, 0.44, 0.10), (0.0, 0.0, 1.12),
           "trim_plain", "trim"),
    ]
    parts += PAINT.wheel("ck_col_wheel", 1.10, 0.10, (0.0, -0.16, 2.20),
                    "trim_plain", "trim", upright=True, hub=True)
    parts += PAINT.wheel("ck_col_pinion", 0.44, 0.09, (0.62, -0.16, 1.72),
                    "trim_plain", "trim", upright=True, hub=True)
    return body, parts


def wall_movement():
    """The wall panel, OPEN. T01's relief is split and the split is the
    subject; here the panel is parted and what shows through is the
    works -- a gear train caught mid-mesh behind a bridge.

    Same 2.16 x 3.0 footprint as `tp_ft_wall_relief`, on purpose: the
    packs are meant to be comparable piece for piece.
    """
    body = PAINT.block("ck_mv_plate_l", (0.90, 0.12, 3.0), (-0.63, 0.0, 1.5), "wall")
    parts = [
        PAINT.block("ck_mv_plate_r", (0.90, 0.12, 3.0), (0.63, 0.0, 1.5), "wall"),
        # The rails are what hold the two plates apart AND what connects
        # them: `assert_parts_touch` floods outward from the body and a
        # right-hand plate 0.36 m from the left one reaches it by way of
        # these.
        PAINT.block("ck_mv_rail_top", (2.16, 0.12, 0.22), (0.0, 0.0, 2.89), "trim_plain", "trim"),
        PAINT.block("ck_mv_rail_low", (2.16, 0.12, 0.22), (0.0, 0.0, 0.11), "trim_plain", "trim"),
    ]
    parts += PAINT.wheel("ck_mv_gear_big", 0.62, 0.10, (-0.10, -0.11, 1.95),
                    "trim_plain", "trim", upright=True, hub=True)
    parts += PAINT.wheel("ck_mv_gear_small", 0.36, 0.09, (0.40, -0.11, 1.62),
                    "trim_plain", "trim", upright=True, hub=True)
    # The bridge: a clock's gears are held by a plate over them, and
    # without one a gear train reads as decoration stuck to a wall.
    # It spans BOTH wheels, 1.50 to 2.00, because that is what a bridge
    # does -- and because a plate that reaches neither of them touches
    # nothing, which `assert_parts_touch` said plainly on the first run.
    parts.append(PAINT.block("ck_mv_bridge", (0.78, 0.07, 0.50), (0.12, -0.12, 1.75),
                    "trim_plain", "trim"))
    return body, parts


def pendulum_lamp():
    """The light HOUSING. No light: illumination is engine-owned and
    `assert_no_emitters` keeps that true at build time.

    T01's fitting is a timber hood over a stone bowl. This one hangs and
    swings -- the bob is the lamp, and a fitting that is also a moving
    part is the thing this pack has that no house family does.
    """
    body = PAINT.block("ck_pd_bracket", (0.34, 0.30, 0.14), (0.0, 0.0, 0.93), "trim_plain", "trim")
    parts = [
        PAINT.block("ck_pd_cap", (0.20, 0.20, 0.07), (0.0, -0.10, 0.865), "trim_plain", "trim"),
        PAINT.block("ck_pd_rod", (0.05, 0.05, 0.60), (0.0, -0.10, 0.54), "trim_plain", "trim"),
    ]
    # UPRIGHT, so the bob faces the room the way a pendulum does -- and
    # so its plan footprint is 0.26 x 0.10 rather than 0.26 square. A
    # flat-lying bob would be a 0.26 m disc at 0.21 m with nothing above
    # it wide enough to cover it, which the no-foothold rule counts and
    # is right to count. Standing it up is not a way around the rule; it
    # is what a pendulum bob actually does.
    parts += PAINT.wheel("ck_pd_bob", 0.26, 0.10, (0.0, -0.10, 0.16),
                    "trim_plain", "trim", upright=True)
    return body, parts


def key_escutcheon():
    """Batch 043's wall-switch contract, wound rather than pressed.

    Same envelope as `tp_ft_switch_housing` so the two packs' controls
    are the same object in two material cultures. The state a player
    reads is the KEY SPOKE's angle -- a square arbor with a handle on it
    is the one control in the world that says "turn" without a label.
    """
    body = PAINT.block("ck_ky_plate", (0.46, 0.08, 0.54), (0.0, 0.0, 0.27), "wall")
    parts = [
        PAINT.block("ck_ky_bezel", (0.34, 0.07, 0.34), (0.0, -0.075, 0.32), "trim_plain", "trim"),
        PAINT.block("ck_ky_dial", (0.22, 0.09, 0.22), (0.0, -0.085, 0.32),
           "trim_plain", "trim"),
        PAINT.block("ck_ky_arbor", (0.10, 0.10, 0.10), (0.0, -0.115, 0.32), "trim_plain", "trim"),
        PAINT.block("ck_ky_spoke", (0.24, 0.05, 0.05), (0.0, -0.125, 0.32),
           "trim_plain", "trim"),
    ]
    return body, parts


def fallen_hand():
    """Floor dressing the house family has none of, and the counterpart
    to T01's root mass: where that one GREW, this one FELL.

    It is bent. A clock hand that came off a dial and hit a stone floor
    does not lie straight, and a straight one reads as a prop laid out
    for a photograph -- which is exactly the failure T01's first root
    mass had, found by photographing it in a room rather than by
    thinking about it.
    """
    body = PAINT.block("ck_hd_shaft", (1.20, 0.10, 0.07), (0.0, 0.0, 0.035),
              "trim_plain", "trim", rotation_z=8.0)
    parts = [
        PAINT.block("ck_hd_boss", (0.16, 0.16, 0.11), (-0.60, -0.04, 0.055), "trim_plain", "trim"),
        # The buckle. Two segments meeting at an angle is the whole
        # difference between a fallen hand and a length of bar stock.
        PAINT.block("ck_hd_bend", (0.30, 0.09, 0.06), (0.24, -0.06, 0.03),
           "trim_plain", "trim", rotation_z=24.0),
        PAINT.block("ck_hd_spade", (0.32, 0.20, 0.07), (0.50, -0.11, 0.035),
           "trim_plain", "trim", rotation_z=20.0),
        PAINT.block("ck_hd_tip", (0.28, 0.07, 0.05), (0.78, -0.18, 0.025),
           "trim_plain", "trim", rotation_z=20.0),
    ]
    parts += PAINT.wheel("ck_hd_tail", 0.28, 0.09, (-0.60, -0.04, 0.045),
                    "trim_plain", "trim")
    return body, parts


def door_bezel():
    """Dressing AROUND the engine's opening, marked like a dial.

    The jamb bars carry the minute marks and project in DEPTH, out of
    the wall toward the player. Projecting them sideways is how T01's
    door boss ended up 0.04 m inside the doorway, which the gate caught
    and was right about: a boss that grows toward the player is a boss,
    and one that grows into the opening is a narrower opening.
    """
    jamb = 0.34
    body = PAINT.block("ck_dr_lintel", (DOOR_W + jamb * 2.0, 0.30, 0.34),
              (0.0, 0.0, DOOR_H + 0.17), "trim_plain", "trim")
    parts = []
    for sign, tag in ((-1.0, "l"), (1.0, "r")):
        x = sign * (DOOR_W / 2.0 + jamb / 2.0)
        parts.append(PAINT.block("ck_dr_jamb_%s" % tag, (jamb, 0.30, DOOR_H),
                        (x, 0.0, DOOR_H / 2.0)))
        parts.append(PAINT.block("ck_dr_marks_%s" % tag, (jamb, 0.44, 2.20),
                        (x, 0.0, 1.55), "trim_plain", "trim"))
    # XII, over the head of the door, which is where a dial puts it --
    # but ON the lintel's face, projecting in depth, not stacked above
    # it. Stacked, the mark topped out at 3.78 m and the chamber ceiling
    # is at 3.60: the manifest said 3.78 before any render did. A pack
    # that does not fit the room it dresses is not dressing it.
    parts.append(PAINT.block("ck_dr_crown", (0.80, 0.46, 0.24),
                    (0.0, 0.0, DOOR_H + 0.17), "trim_plain", "trim"))
    return body, parts


ASSETS = [
    ("tp_ck_gear_column", gear_column, ["route"]),
    ("tp_ck_wall_movement", wall_movement, ["route"]),
    ("tp_ck_pendulum_lamp", pendulum_lamp, ["emitters", "route"]),
    ("tp_ck_key_escutcheon", key_escutcheon, ["emitters", "route"]),
    ("tp_ck_fallen_hand", fallen_hand, ["route"]),
    ("tp_ck_door_bezel", door_bezel, ["opening", "route"]),
]

#: What makes each one this pack's rather than the house family's.
DISTINCT = {
    "tp_ck_gear_column": "the column is a SHAFT: it transmits torque, and "
                         "the house column holds a roof up",
    "tp_ck_wall_movement": "the panel is PARTED and the works show through, "
                           "held by a bridge the way a movement is",
    "tp_ck_pendulum_lamp": "the fitting hangs and swings; no house family "
                           "has a light that is also a moving part",
    "tp_ck_key_escutcheon": "batch043's wall-switch contract WOUND, not "
                            "pressed: a square arbor with a handle on it",
    "tp_ck_fallen_hand": "floor dressing that FELL, where T01's grew -- and "
                         "it is bent, because a straight one is bar stock",
    "tp_ck_door_bezel": "the opening is dressed as a DIAL: minute marks up "
                        "the jambs and XII over the head",
}


def main():
    packkit.build(ASSETS, OUT, PAINT, DISTINCT, {
        "batch": "056",
        "kind": "theme_pack_content",
        "pack": "tp_super_mario_64",
        "subtheme": "TICK TOCK CLOCK -- the inside of a running movement: "
                    "gear trains, pendulums, dial marks, and a hand that "
                    "came off",
        "subtheme_is_a_choice": "Super Mario 64 has fifteen courses and the "
                                "packet's concept for T02 is 'Clockwork "
                                "Garden', which has two halves. This pack "
                                "is the CLOCKWORK half. The garden -- "
                                "Peach's hedged courtyard -- is the "
                                "deliberate second subtheme and is not "
                                "built here, because a courtyard and a "
                                "movement do not share a material culture.",
        "status": "PROPOSAL -- visual only, review-pending, not a "
                  "production default",
        "painted_with": THEME,
        "theme_hint_says": THEME_HINT,
        "theme_hint_disagrees": "Constants.THEME_BY_GAME_HINT maps this "
                                "game to %s; the nearest family BY "
                                "MATERIAL is %s. The hint picks a family "
                                "by GAME and a treatment follows what the "
                                "pack is MADE OF -- two questions, one "
                                "field. For T01 they happened to agree. "
                                "See COVERAGE.md section 3."
                                % (THEME_HINT, THEME),
        "material_treatment": "MISSING, AND NAMED AS MISSING. THEME_PACK.json "
                              "has no pack namespace, so a pack's own "
                              "material set cannot be filed without becoming "
                              "a seventh house theme. See "
                              "docs/art/theme-packs/COVERAGE.md section 3. "
                              "These are painted in the nearest existing "
                              "family; a tint is NOT the pack's treatment.",
        "carries": "mesh and named parts only. No collider, body, trigger, "
                   "light, camera, script or animation.",
        "not_changed": ["collision", "placement", "any runtime state",
                        "the engine's door opening", "any approved asset"],
    }, log="clock")


if __name__ == "__main__":
    main()
