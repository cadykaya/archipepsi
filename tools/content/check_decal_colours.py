"""Ordinary decoration may not impersonate a signal.

    python3 tools/content/check_decal_colours.py [decal_kit.json ...]

`assets/art_palette.json` reserves six UNIVERSAL colours that do not vary by
theme, and `AUTHORED_CONTENT.md`'s rule is that "can I use this?" is never a
guess. A grime patch that lands near the affordance teal, or a scorch that
drifts toward the hazard orange, teaches a player that dirt is interactive.

WHAT THIS GUARDS, AND WHAT IT DELIBERATELY DOES NOT
---------------------------------------------------
The first version of this file compared every decal texel against every step
of all six reserved ramps in CIE L*a*b* and failed anything within 25 dE. It
failed all six decals, 62 times, and almost every hit was `dead`.

`dead` is `#4a4f57` -- "unpowered, locked, spent, offline. The value a
fixture drops to". It is a DESATURATED SLATE, and its ramp spans neutral grey
from `#26292d` to `#9ba5b6`. Every dark neutral in the game is near some step
of it, including the whole shared `grime` family that every theme already
uses and that the SHIPPED textures are painted with. So the rule forbade
dirt for being dirt-coloured, which is a category error, not a finding.

And `dead` does not signal by colour arriving somewhere. It signals by being
applied to a KNOWN OBJECT that was lit and now is not. A stain cannot
impersonate that; only a fixture can.

So the guarded set is the five CHROMATIC families -- `signal`, `hazard`,
`identity`, `send`, `glitch` -- and the test is the one that matches the real
failure: a decoration is refused when it is saturated enough to read as a
COLOUR rather than as dirt AND its hue sits inside a window around a reserved
anchor. Desaturated is safe at any hue, which is what lets grime be brown;
saturated-and-near-in-hue is refused however dark it is.

`dead`'s exclusion is recorded here rather than silently dropped, and the
threshold was chosen once, from the palette's own separation rules, not
tuned until the art passed.

The gate proves it BITES: `--selftest` drives colours that must fail through
the same rule, and a run in which the negative controls pass is itself a
failure.

TRIAL ART. This checks the decal kit under `docs/art/review/`, which ships
nowhere, is in no content manifest and is wired into no build.
"""
from __future__ import annotations

import json
import math
import os
import sys
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

#: Guarded: the five reserved families that signal BY COLOUR.
GUARDED = ("signal", "hazard", "identity", "send", "glitch")
#: Not guarded, and why. See the module docstring.
UNGUARDED = {"dead": "a desaturated slate whose ramp is neutral grey; it "
                     "signals by being applied to a known fixture, not by "
                     "its colour appearing on a surface"}

#: Below this LCh chroma a colour reads as dirt, not as a hue. Grime's own
#: most saturated step (#7b6a60) sits at about 8, so 18 leaves the whole
#: shared family comfortably below the line without being chosen to.
CHROMA_FLOOR = 18.0
#: Hue window, degrees either side of a reserved anchor's hue. Narrower than
#: a layman's "similar colour" because a reserved colour is learned, and a
#: learned colour is recognised from further away.
HUE_WINDOW = 30.0
#: A decoration may be near in hue if it is far less saturated: a colour at
#: this fraction of the anchor's chroma or less cannot carry the signal.
CHROMA_RATIO = 0.45
#: Alpha at or below which a texel is barely on the surface at all.
FAINT_ALPHA = 40


def srgb_to_lab(rgb):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(float(c)) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 1.00000
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else (7.787 * t + 16 / 116)
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def lch(rgb):
    """(lightness, chroma, hue-degrees). Chroma is the whole question here."""
    L, a, b = srgb_to_lab(rgb)
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360.0


def hue_gap(h1, h2):
    d = abs(h1 - h2) % 360.0
    return min(d, 360.0 - d)


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def anchors():
    """The guarded anchors, as (name, hex, chroma, hue)."""
    palette = json.load(open(os.path.join(REPO, "assets/art_palette.json")))
    out = []
    for name in GUARDED:
        spec = palette["universal"][name]
        _L, c, h = lch(hexrgb(spec["anchor"]))
        out.append((name, spec["anchor"], c, h))
    return out


def judge(rgb, guard):
    """(ok, why) for one colour. `why` names the anchor when it is refused."""
    _L, c, h = lch(rgb)
    if c < CHROMA_FLOOR:
        return True, "chroma %.1f < %.1f, reads as dirt" % (c, CHROMA_FLOOR)
    worst = None
    for name, hexv, ac, ah in guard:
        gap = hue_gap(h, ah)
        if gap > HUE_WINDOW:
            continue
        if c <= ac * CHROMA_RATIO:
            continue
        why = ("chroma %.1f at hue %.0f is %.0f deg from %s %s (chroma %.1f)"
               % (c, h, gap, name, hexv, ac))
        if worst is None:
            worst = why
    return (worst is None), worst or ("chroma %.1f at hue %.0f, clear of "
                                      "every guarded hue" % (c, h))


def pixels(path):
    from PIL import Image
    with Image.open(path) as im:
        return Counter(im.convert("RGBA").getdata())  # noqa: PIL deprecation


def selftest(guard):
    """The gate must BITE. A run where these pass is a broken gate."""
    must_fail = [
        ((0x39, 0xd7, 0xc8), "the affordance teal itself"),
        ((0xe8, 0x54, 0x1f), "the hazard orange itself"),
        ((0xc7, 0x52, 0x2c), "a scorch drifted toward hazard"),
        ((0x4a, 0xb8, 0xac), "a grime patch drifted toward signal"),
        ((0xff, 0xd4, 0x5c), "the send yellow itself"),
    ]
    must_pass = [
        ((0x4e, 0x43, 0x3c), "grime mid, the shared family"),
        ((0x24, 0x1f, 0x1c), "grime dark"),
        ((0x7b, 0x6a, 0x60), "grime light"),
        ((0x4a, 0x4f, 0x57), "the `dead` slate, deliberately unguarded"),
        ((0x31, 0x45, 0x59), "concrete accent, the stencil paint"),
        ((0xe8, 0xec, 0xe4), "concrete base light, the scuff substrate"),
    ]
    bad = 0
    for rgb, label in must_fail:
        ok, why = judge(rgb, guard)
        if ok:
            bad += 1
        print("      %-4s must FAIL  %-38s %s"
              % ("ok" if not ok else "BROKEN", label, why))
    for rgb, label in must_pass:
        ok, why = judge(rgb, guard)
        if not ok:
            bad += 1
        print("      %-4s must PASS  %-38s %s"
              % ("ok" if ok else "BROKEN", label, why))
    print("      %d control(s) wrong" % bad)
    return bad


def main(argv):
    guard = anchors()
    print("[decal-colour] guarding %s" % ", ".join(n for n, _, _, _ in guard))
    for name, why in UNGUARDED.items():
        print("[decal-colour] NOT guarding `%s`: %s" % (name, why))
    print("[decal-colour] chroma floor %.0f, hue window +/-%.0f deg, "
          "chroma ratio %.2f" % (CHROMA_FLOOR, HUE_WINDOW, CHROMA_RATIO))

    print("[decal-colour] negative controls:")
    if selftest(guard):
        print("[decal-colour] FAIL -- the gate does not bite")
        return 1

    kits = [a for a in argv[1:] if not a.startswith("-")] or [os.path.join(
        REPO, "docs/art/review/glyph_layers_2026-09-10/decal_kit.json")]
    if "--selftest" in argv:
        print("[decal-colour] PASS (controls only)")
        return 0
    bad = checked = faint = 0
    for kit_path in kits:
        kit = json.load(open(kit_path))
        base = os.path.dirname(os.path.abspath(kit_path))
        print("[decal-colour] %s" % os.path.relpath(kit_path, REPO))
        # A repeating FIELD is decoration too, and the rule that it may not
        # impersonate a signal is the same one. The two records name their
        # entries differently, so both keys are read rather than a second
        # copy of this file existing.
        entries = kit.get("decals", []) + kit.get("fields", [])
        for entry in entries:
            png = os.path.join(base, entry["images"]["native"])
            shown = []
            for (r, g, b, a), _n in sorted(pixels(png).items()):
                if a == 0:
                    continue
                if a <= FAINT_ALPHA:
                    faint += 1
                    continue
                checked += 1
                ok, why = judge((r, g, b), guard)
                if not ok:
                    bad += 1
                    print("      FAIL %-16s rgba(%d,%d,%d,%d) %s"
                          % (entry["id"], r, g, b, a, why))
                else:
                    shown.append("%.1f" % lch((r, g, b))[1])
            print("      %-16s %d colour(s) clear; chroma %s"
                  % (entry["id"], len(shown), "/".join(shown)))
    print("[decal-colour] %d colour(s) checked, %d skipped as faint "
          "(alpha <= %d), %d refused" % (checked, faint, FAINT_ALPHA, bad))
    if bad:
        print("[decal-colour] FAIL -- decoration must not impersonate a signal")
        return 1
    print("[decal-colour] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
