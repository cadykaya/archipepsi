"""Read `assets/art_palette.json`, and refuse to let it drift.

Blender builders reach for colour through this module and only through it.
Nothing anywhere in `tools/blender/` writes a hex literal -- the failure that
prevents is the one mario-3 documented in its own palette file: seven ground
greens all within 0.16 of each other, not from bad taste, but because the
values were typed in seven places.

`verify()` is the part that matters. It checks four things a palette can be
wrong about without anybody noticing:

1. **Anchor drift.** Every colour in `engine_anchors` still matches
   `THEME_MATERIALS` exactly. If engineering retunes a theme, the art branch
   finds out on the next check rather than in a screenshot six commits later.
2. **The anchor survives its own ramp.** Each role's ramp must literally
   contain its anchor. A generated ramp that relocates the colour the engine
   paints with is worse than no ramp.
3. **Value separation.** Adjacent steps clear `min_value_separation`, or a
   greyscale screenshot turns to mush.
4. **Family distinctness.** `signal`, `identity` and `glitch` stay at least
   45 degrees apart in hue. They are all saturated, all bright, and all mean
   completely different things.
5. **The value sandwich.** For every wall and trim colour a room is
   actually painted with, some step of every signalling family clears
   `min_interactable_separation`. This is the check that keeps "can I use
   this?" from being a guess, and it is the only one here that can fail
   because of a THEME rather than because of the palette. It is deliberately
   *not* the stricter "one value separates from the whole ramp", which is
   unsatisfiable -- see the comment on the check itself.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine_truth  # noqa: E402
from palette_build import hex_to_rgb, lstar  # noqa: E402
import colorsys  # noqa: E402

REPO_ROOT = engine_truth.REPO_ROOT
PALETTE_PATH = os.path.join(REPO_ROOT, "assets", "art_palette.json")
BUDGETS_PATH = os.path.join(REPO_ROOT, "assets", "art_budgets.json")

_CACHE = {}

#: Colours that are allowed to sit close to a theme in value because they are
#: never the thing the player is looking FOR. `dead` is the value a fixture
#: drops to when it is not for you, so it is supposed to recede.
SIGNALLING = ("signal", "hazard", "identity", "send")

#: Families the player must never confuse with one another, and the minimum
#: hue separation in degrees between their anchors.
#:
#: Added when `identity` moved from violet to neon green at the Batch 001
#: review. These three are all saturated, all bright, and all mean completely
#: different things -- `signal` is "you can use this", `identity` is Epsilon
#: itself, `glitch` is cosmetic corruption that means nothing mechanically. A
#: player who reads Epsilon's green as a usable prompt, or a glitch artefact
#: as Epsilon, has been told something false by the palette.
#:
#: 45 degrees is roughly where two saturated hues stop being nameable as
#: variants of one another. The chosen green sits clear of both; a green that
#: drifted toward void_glitch's #00ffbf trim would not, and that drift is
#: exactly what this catches.
MUST_NOT_CONFUSE = (("signal", "identity"), ("identity", "glitch"),
                    ("signal", "glitch"))
MIN_HUE_SEPARATION_DEG = 45.0


def hue_degrees(hex_value):
    return colorsys.rgb_to_hsv(*hex_to_rgb(hex_value))[0] * 360.0


def hue_gap(a, b):
    """Shortest angular distance between two hues, in degrees."""
    gap = abs(hue_degrees(a) - hue_degrees(b)) % 360.0
    return min(gap, 360.0 - gap)


def palette():
    if "p" not in _CACHE:
        with open(PALETTE_PATH, "r", encoding="utf-8") as handle:
            _CACHE["p"] = json.load(handle)
    return _CACHE["p"]


def budgets():
    if "b" not in _CACHE:
        with open(BUDGETS_PATH, "r", encoding="utf-8") as handle:
            _CACHE["b"] = json.load(handle)
    return _CACHE["b"]


def theme(name, role, step):
    """A theme colour as an sRGB hex string. `role` is base/accent/trim."""
    data = palette()["themes"]
    if name not in data:
        raise KeyError("palette: no theme '%s'. Themes are %s"
                       % (name, ", ".join(data)))
    if role not in ("base", "accent", "trim"):
        raise KeyError("palette: theme role must be base/accent/trim, got '%s'"
                       % role)
    ramp = data[name][role]["ramp"]
    if not 0 <= step < len(ramp):
        raise IndexError("palette: %s.%s has %d steps, asked for %d"
                         % (name, role, len(ramp), step))
    return ramp[step]


def universal(name, step):
    """A grammar colour: signal / hazard / identity / dead / send / glitch."""
    data = palette()["universal"]
    if name not in data:
        raise KeyError("palette: no universal family '%s'. Families are %s"
                       % (name, ", ".join(data)))
    ramp = data[name]["ramp"]
    return ramp[max(0, min(len(ramp) - 1, step))]


def grime(step):
    ramp = palette()["grime"]["ramp"]
    return ramp[max(0, min(len(ramp) - 1, step))]


def light(name):
    spec = palette()["themes"][name]["light"]
    return spec["anchor"], spec["energy"]


def lighting():
    """The lighting budget a hue-critical material has to survive.

    `max_irradiance` is the brightest theme light plus the brightest
    environment ambient, both read from the engine by `engine_truth`.
    """
    return palette()["lighting"]


def roughness(name):
    return palette()["themes"][name]["roughness"]


def rgb(hex_value):
    return hex_to_rgb(hex_value)


def rgba(hex_value, alpha=1.0):
    return hex_to_rgb(hex_value) + (alpha,)


def value(hex_value):
    """CIE L* of a hex colour, 0..1."""
    return lstar(hex_to_rgb(hex_value))


def separation(a, b):
    return abs(value(a) - value(b))


def verify():
    problems = []
    data = palette()
    anchors = engine_truth.theme_anchors()
    min_sep = data["min_value_separation"]
    min_inter = data["min_interactable_separation"]

    # 1. anchor drift
    if data["engine_anchors"] != anchors:
        for name in sorted(set(anchors) | set(data["engine_anchors"])):
            live = anchors.get(name)
            stored = data["engine_anchors"].get(name)
            if live != stored:
                problems.append(
                    "theme '%s': the palette records %s but THEME_MATERIALS "
                    "now says %s. Engineering retuned the theme; regenerate "
                    "with `python3 tools/blender/palette_build.py --write` and "
                    "re-render every affected asset."
                    % (name, stored, live))

    # 2. the anchor survives its own ramp
    for name, spec in data["themes"].items():
        for role in ("base", "accent", "trim"):
            anchor = spec[role]["anchor"].lower()
            if anchor not in [c.lower() for c in spec[role]["ramp"]]:
                problems.append(
                    "theme '%s' role '%s': the ramp %s does not contain its "
                    "own anchor %s. A ramp that relocates the colour the "
                    "engine paints with has deleted the theme's identity."
                    % (name, role, spec[role]["ramp"], anchor))

    # 3. value separation within every ramp
    def check_ramp(label, ramp):
        for i in range(len(ramp) - 1):
            sep = separation(ramp[i], ramp[i + 1])
            if sep < min_sep - 1e-6:
                problems.append(
                    "%s: steps %d and %d (%s, %s) differ by only dL* %.3f, "
                    "below the %.2f floor. Desaturate a screenshot and these "
                    "two are the same colour."
                    % (label, i, i + 1, ramp[i], ramp[i + 1], sep, min_sep))

    for name, spec in data["themes"].items():
        for role in ("base", "accent", "trim"):
            check_ramp("theme %s.%s" % (name, role), spec[role]["ramp"])
    for name, spec in data["universal"].items():
        check_ramp("universal %s" % name, spec["ramp"])
    check_ramp("grime", data["grime"]["ramp"])

    # 4. the value sandwich -- every signalling family pops off every wall
    #
    # The first version of this check asked whether a signalling family had
    # one step that cleared the floor against EVERY step of a theme's base
    # ramp. That is unsatisfiable and was worth finding out: a base ramp
    # spans L* 0.18 to 0.93, so no single value can be far from all of it.
    # The lesson is an art rule rather than a palette fix -- **value alone
    # cannot carry an interactable across six themes.** An interactable is
    # painted as a SANDWICH: a dark surround and a bright signal face from
    # the same family, adjacent, so whichever way a theme goes, one half of
    # the pair separates from it.
    #
    # So the check asks the satisfiable version of the same question: for
    # every surface a room is actually painted with, does SOME step of the
    # family clear the floor? The surfaces are the two engine ANCHORS --
    # `theme_materials.gd` paints walls and trim with exactly those, and the
    # other ramp steps exist for painting inside a texture, not for being a
    # wall.
    for family in SIGNALLING:
        fam_ramp = data["universal"][family]["ramp"]
        for name, spec in data["themes"].items():
            for role in ("base", "trim"):
                surface = spec[role]["anchor"]
                best = max(separation(sig, surface) for sig in fam_ramp)
                if best < min_inter - 1e-6:
                    problems.append(
                        "universal '%s' has no step that clears dL* %.2f "
                        "against theme '%s' %s (%s, L*%.2f); best is %.3f. An "
                        "interactable painted in it would vanish into that "
                        "surface -- which is exactly the guess "
                        "AUTHORED_CONTENT.md forbids."
                        % (family, min_inter, name, role, surface,
                           value(surface), best))
    # 5. the three loud families stay nameable as different colours
    for one, two in MUST_NOT_CONFUSE:
        a = data["universal"][one]["anchor"]
        b = data["universal"][two]["anchor"]
        gap = hue_gap(a, b)
        if gap < MIN_HUE_SEPARATION_DEG:
            problems.append(
                "universal '%s' (%s, hue %.0f deg) and '%s' (%s, hue %.0f) are "
                "only %.0f degrees apart, under the %.0f floor. These mean "
                "completely different things -- %s -- and a palette that lets "
                "them read as variants of each other tells the player "
                "something false."
                % (one, a, hue_degrees(a), two, b, hue_degrees(b), gap,
                   MIN_HUE_SEPARATION_DEG,
                   "usable / Epsilon / cosmetic corruption"))

    return problems


def report():
    data = palette()
    print("palette: %s" % os.path.relpath(PALETTE_PATH, REPO_ROOT))
    for name, spec in data["themes"].items():
        print("  %-18s base %s" % (name, "  ".join(
            "%s(L*%.2f)" % (c, value(c)) for c in spec["base"]["ramp"])))
    print()
    for family in SIGNALLING:
        fam = data["universal"][family]["ramp"]
        worst_label, worst = None, 99.0
        for name, spec in data["themes"].items():
            for role in ("base", "trim"):
                surface = spec[role]["anchor"]
                best = max(separation(sig, surface) for sig in fam)
                if best < worst:
                    worst_label, worst = "%s %s" % (name, role), best
        print("  universal %-9s worst wall separation: %.3f vs %s "
              "(floor %.2f)" % (family, worst, worst_label,
                                data["min_interactable_separation"]))


if __name__ == "__main__":
    report()
    found = verify()
    print()
    if found:
        print("palette-check: FAIL -- %d problem(s):" % len(found))
        for problem in found:
            print("  - %s" % problem)
        raise SystemExit(1)
    print("palette-check: PASS -- anchors live, ramps separated, every "
          "signalling colour readable in every theme.")
