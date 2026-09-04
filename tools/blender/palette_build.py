"""Generate `assets/art_palette.json` from the engine's own theme colours.

    python3 tools/blender/palette_build.py --write

## Why this is generated rather than typed

The engine already owns Archipepsi's colours. `THEME_MATERIALS` in
`bridge/archipepsi_bridge/schemas/constants.py` gives every theme a base, an
accent, a trim and a light colour, and `generation/theme_materials.gd` paints
the whole procedural game from them today. An art palette that invented its
own colours would not be a palette, it would be a second opinion -- and the
moment authored content stands next to procedural content in the same room,
the disagreement is the most visible thing on screen.

So the four anchors are READ, never chosen. What this file adds is the thing
the anchors do not have: a **value ramp** per role, so a painter has a dark,
a mid, a light and a highlight of each colour to work with instead of one
flat value and a `darkened()` call.

## How the ramps are made

Not by eye, and not by blending toward white -- mario-3 paid for that lesson
and got pastel mush. Each ramp is solved in HSV against a target CIE L*:
darken by dropping V, lighten by pushing V to 1.0 first and only desaturating
once there is no value headroom left. The spacing is then exact by
construction rather than by luck.

## The universal families

Six roles do NOT vary by theme, and that is the single most important
decision in this file. `AUTHORED_CONTENT.md` requires that "can I use this?"
is never a guess, and a Check object tinted to match its theme is a Check
object that vanishes in one theme out of six. So `signal`, `hazard`,
`identity`, `dead`, `send` and `glitch` are fixed across the whole game and
are the only colours an interactable is allowed to speak with.
"""

from __future__ import annotations

import colorsys
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine_truth  # noqa: E402

REPO_ROOT = engine_truth.REPO_ROOT
PALETTE_PATH = os.path.join(REPO_ROOT, "assets", "art_palette.json")

#: How many steps each role's ramp gets. The anchor colour ALWAYS appears
#: verbatim in its own ramp -- see `ramp()` for why that is not negotiable.
RAMP_STEPS = {"base": 4, "accent": 3, "trim": 3, "universal": 4, "grime": 3}

#: Ideal L* gap between adjacent steps. Well above art_budgets'
#: `min_value_separation` (0.10) so a ramp stays legal after a theme anchor
#: shifts a little, and `ramp()` refuses to emit one that falls below it.
IDEAL_STEP = 0.17
MIN_STEP = 0.10

#: The usable ends of the range. Not 0 and 1: a step at pure black loses its
#: hue entirely and a step at pure white loses its saturation, and a palette
#: whose extremes are achromatic has two fewer colours than it claims.
L_FLOOR = 0.06
L_CEIL = 0.93

#: Fixed across every theme. These are the game's grammar words: a player
#: learns them once in the first Zone and they must never be re-learned.
UNIVERSAL = {
    "signal": {
        "means": "you can use this -- the only colour an interactable "
                 "prompt, rim or reveal face is allowed to be",
        "base": "#39d7c8",
    },
    "hazard": {
        "means": "this will hurt you. Never used decoratively, in any theme, "
                 "for any reason",
        "base": "#e8541f",
    },
    "identity": {
        "means": "Epsilon. Its presence, its terminal, its voice surfaces "
                 "and nothing else in the game",
        # NEON GREEN, changed from violet #b45cff at the Batch 001 review.
        #
        # The owner's direction: Epsilon is not another machine in the
        # facility, it is a FOREIGN INTELLIGENCE inhabiting old human
        # infrastructure. The facility is cold grey concrete, pale blue
        # paint and yellow utility light; Epsilon has to read as an
        # intrusion into that, not as a fixture within it.
        #
        # Violet was a plausible "computer" colour and it sat too
        # comfortably beside the theme accents -- it read as another
        # institutional signal rather than as something wrong and alive.
        #
        # This green leans YELLOW deliberately, away from
        # void_glitch's #00ffbf trim and away from `signal`'s teal. Those
        # are cyan-family and this must not be mistaken for either: glitch
        # is cosmetic corruption, signal means "you can use this", and
        # identity means Epsilon itself.
        "base": "#57ff1f",
    },
    "dead": {
        "means": "unpowered, locked, spent, offline. The value a fixture "
                 "drops to when it is not for you right now",
        "base": "#4a4f57",
    },
    "send": {
        "means": "this leaves for the multiworld. The Check's transmission "
                 "beam and destination ring",
        "base": "#ffd45c",
    },
    "glitch": {
        "means": "Epsilon Static and the missing-world checker. Cosmetic "
                 "corruption only -- never a mechanic",
        "base": "#ff00e6",
    },
}

#: The grime layer. Every theme darkens and stains with the SAME two values,
#: because dirt is dirt: a theme-tinted grime reads as a coloured gel over a
#: clean surface rather than as a surface with a history.
GRIME = {
    "means": "wear, stain, soot, water streak. Shared by every theme so that "
             "six material families can look like one world",
    "base": "#241f1c",
    "targets": (0.08, 0.16, 0.26),
}


# ----------------------------------------------------------------------
# colour maths
# ----------------------------------------------------------------------

def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return "#%02x%02x%02x" % tuple(
        max(0, min(255, int(round(channel * 255.0)))) for channel in rgb)


def srgb_to_linear(channel):
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def lstar(rgb):
    """CIE L*, normalised to 0..1.

    Perceptually uniform, which is why the separation rule is written
    against it: four of the six themes sit in the dark half of the range,
    where a threshold on linear luminance would demand enormous gaps in
    shadow and wave through mush in the highlights.
    """
    r, g, b = (srgb_to_linear(channel) for channel in rgb)
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    if y <= 0.008856:
        return (903.3 * y) / 100.0
    return (116.0 * (y ** (1.0 / 3.0)) - 16.0) / 100.0


def solve_step(base_rgb, target_l):
    """Move `base_rgb` to `target_l` in HSV, keeping its hue.

    Darkening drops V. Lightening pushes V to 1.0 first and only then
    desaturates -- blending toward white instead spends saturation first and
    produces pastel, which the reference era never does.
    """
    h, s, v = colorsys.rgb_to_hsv(*base_rgb)
    if s == 0.0:
        # Achromatic: solve V directly.
        low, high = 0.0, 1.0
        for _ in range(60):
            mid = (low + high) / 2.0
            if lstar((mid, mid, mid)) < target_l:
                low = mid
            else:
                high = mid
        grey = (low + high) / 2.0
        return (grey, grey, grey)

    # Phase 1: V in [0, 1] at full saturation.
    low, high = 0.0, 1.0
    for _ in range(60):
        mid = (low + high) / 2.0
        if lstar(colorsys.hsv_to_rgb(h, s, mid)) < target_l:
            low = mid
        else:
            high = mid
    candidate = colorsys.hsv_to_rgb(h, s, (low + high) / 2.0)
    if abs(lstar(candidate) - target_l) < 0.004:
        return candidate

    # Phase 2: out of value headroom, so desaturate at V = 1.
    low, high = 0.0, s
    for _ in range(60):
        mid = (low + high) / 2.0
        if lstar(colorsys.hsv_to_rgb(h, mid, 1.0)) > target_l:
            low = mid
        else:
            high = mid
    return colorsys.hsv_to_rgb(h, (low + high) / 2.0, 1.0)


def ramp(base_hex, steps):
    """Extend an anchor colour into a value ramp that CONTAINS the anchor.

    The first version of this function took a table of absolute L* targets
    per role, and it was wrong in a way that took a render to see:
    void_glitch's trim anchor is `#00ffbf`, a deliberately loud neon, and
    the trim table's 0.12-0.36 targets solved it into three dark teals. The
    arithmetic was right and the result deleted the theme's identity -- the
    ramp no longer contained the colour the engine actually paints with.

    So the anchor's own L* decides where the ramp sits. The anchor is placed
    at whichever index keeps the ramp inside the usable range, the spacing is
    the largest that fits up to IDEAL_STEP, and the anchor is written back in
    verbatim so `verify()` can prove every engine colour survives its own
    ramp byte for byte.
    """
    base_rgb = hex_to_rgb(base_hex)
    anchor_l = lstar(base_rgb)

    span = L_CEIL - L_FLOOR
    index = int(round((anchor_l - L_FLOOR) / span * (steps - 1)))
    index = max(0, min(steps - 1, index))

    below = index
    above = steps - 1 - index
    step = IDEAL_STEP
    if below:
        step = min(step, (anchor_l - L_FLOOR) / below)
    if above:
        step = min(step, (L_CEIL - anchor_l) / above)

    # If the anchor sits so near an end that the ramp cannot breathe, slide
    # it one index toward the middle and try again rather than emitting a
    # ramp whose steps are indistinguishable.
    while step < MIN_STEP and steps > 1:
        if below > above and index > 0:
            index -= 1
        elif index < steps - 1:
            index += 1
        else:
            break
        below, above = index, steps - 1 - index
        step = IDEAL_STEP
        if below:
            step = min(step, (anchor_l - L_FLOOR) / below)
        if above:
            step = min(step, (L_CEIL - anchor_l) / above)

    if step < MIN_STEP:
        raise ValueError(
            "palette: anchor %s sits at L*%.2f and cannot carry a %d-step "
            "ramp with %.2f separation. Either the anchor changed in the "
            "engine or this role needs fewer steps -- do not lower MIN_STEP, "
            "which is what makes the ramp readable in greyscale."
            % (base_hex, anchor_l, steps, MIN_STEP))

    out = []
    for i in range(steps):
        if i == index:
            out.append(base_hex.lower())
            continue
        out.append(rgb_to_hex(solve_step(base_rgb, anchor_l + (i - index) * step)))
    return out


# ----------------------------------------------------------------------
# build
# ----------------------------------------------------------------------

def build():
    anchors = engine_truth.theme_anchors()
    payload = {
        "_comment": [
            "Archipepsi art palette. GENERATED -- regenerate with:",
            "    python3 tools/blender/palette_build.py --write",
            "",
            "The four anchor colours per theme are READ from the engine's own",
            "THEME_MATERIALS (schemas/constants.py) and are recorded here so",
            "drift is detectable. Art does not get a second opinion about what",
            "colour concrete_facility is; authored content standing beside",
            "procedural content in the same room would show the disagreement.",
            "",
            "What this file adds is a solved value ramp per role, so a painter",
            "has dark/mid/light steps instead of one value and a darkened()",
            "call. Ramps are solved in HSV against a target CIE L*, never",
            "blended toward white -- that produces pastel.",
            "",
            "The `universal` families do NOT vary by theme. That is the most",
            "important line in this file: AUTHORED_CONTENT.md requires that",
            "'can I use this?' is never a guess, and a Check tinted to match",
            "its theme is a Check that vanishes in one theme out of six.",
        ],
        "min_value_separation": 0.10,
        "min_interactable_separation": 0.18,
        "max_families_per_asset": 4,
        "engine_anchors": anchors,
        # The brightest irradiance the game can put on one surface, read
        # from engineering. A material that must keep its hue is solved
        # against this; see `common.make_signal_material`.
        "lighting": engine_truth.lighting(),
        "universal": {},
        "grime": {
            "means": GRIME["means"],
            "anchor": GRIME["base"],
            "ramp": ramp(GRIME["base"], RAMP_STEPS["grime"]),
        },
        "themes": {},
    }

    for name, spec in UNIVERSAL.items():
        payload["universal"][name] = {
            "means": spec["means"],
            "anchor": spec["base"],
            "ramp": ramp(spec["base"], RAMP_STEPS["universal"]),
        }

    for theme, values in anchors.items():
        payload["themes"][theme] = {
            "base": {
                "anchor": values["base_color"],
                "ramp": ramp(values["base_color"], RAMP_STEPS["base"]),
            },
            "accent": {
                "anchor": values["accent_color"],
                "ramp": ramp(values["accent_color"], RAMP_STEPS["accent"]),
            },
            "trim": {
                "anchor": values["trim_color"],
                "ramp": ramp(values["trim_color"], RAMP_STEPS["trim"]),
            },
            "light": {
                "anchor": values["light_color"],
                "energy": values["light_energy"],
            },
            "roughness": values["roughness"],
            "noise": values["noise"],
        }
    return payload


def main():
    payload = build()
    if "--write" in sys.argv:
        with open(PALETTE_PATH, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)
            handle.write("\n")
        print("wrote %s" % os.path.relpath(PALETTE_PATH, REPO_ROOT))
    for theme, spec in payload["themes"].items():
        print("%-20s base %s  accent %s  trim %s"
              % (theme,
                 " ".join(spec["base"]["ramp"]),
                 " ".join(spec["accent"]["ramp"]),
                 " ".join(spec["trim"]["ramp"])))
    print()
    for name, spec in payload["universal"].items():
        print("%-20s %s   (%s)" % (name, " ".join(spec["ramp"]), spec["means"][:52]))
    print("%-20s %s" % ("grime", " ".join(payload["grime"]["ramp"])))


if __name__ == "__main__":
    main()
