#!/usr/bin/env python3
"""Track B Tier 1 -- what body value can clear the wall in ALL six rooms?

    python3 tools/content/enemy_value_bands.py <dir with silhouettes.json>

The owner's condition on the Tier-1 candidate: *"do not land it from the
concrete-room result alone. Render and measure the candidate against all
six theme families first and make sure it does not simply move the
collision into a pale environment."*

This is that arithmetic, done once on the measured wall values rather
than guessed. A single body value B clears a threshold T against every
theme only if `min(|B - wall|) >= T` across all six -- which is possible
only OUTSIDE the walls' own span, and only if that span is narrower than
2T. So the answer is two bands, one dark and one pale, and the width of
the gap between them is a fact about the palette rather than an opinion
about enemies.
"""

import json
import os
import sys


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    with open(os.path.join(root, "silhouettes.json"), encoding="utf-8") as fh:
        data = json.load(fh)
    con = data.get("_contrast") or {}
    themes = {k: v for k, v in con.items() if isinstance(v, dict)
              and "wall_lstar" in v}
    if len(themes) < 2:
        print("enemy-value-bands: FAIL -- %d theme(s) measured; this needs "
              "the whole set" % len(themes), file=sys.stderr)
        return 1

    walls = {t: float(v["wall_lstar"]) for t, v in themes.items()}
    body = float(next(iter(themes.values()))["body_lstar"])
    t_value = float(next(iter(themes.values())).get(
        "min_value_separation", 0.10))
    t_inter = float(next(iter(themes.values())).get(
        "min_interactable_separation", 0.18))

    lo, hi = min(walls.values()), max(walls.values())
    print("enemy-value-bands: body L* %.3f, %d walls from %.3f to %.3f "
          "(span %.3f)\n" % (body, len(walls), lo, hi, hi - lo))
    print("  %-20s %8s %11s" % ("theme", "wall L*", "separation"))
    for t in sorted(walls, key=lambda t: walls[t]):
        sep = abs(body - walls[t])
        print("  %-20s %8.3f %11.3f  %s"
              % (t, walls[t], sep,
                 "clears" if sep >= t_inter else
                 "over %.2f" % t_value if sep >= t_value else "SHORT of both"))
        if walls[t] < body:
            print("      (the body is ABOVE this wall, not below it)")

    print()
    for name, t in (("min_value_separation", t_value),
                    ("min_interactable_separation", t_inter)):
        dark, pale = lo - t, hi + t
        span_ok = (hi - lo) < 2 * t
        print("  to clear %s (%.2f) in every theme, one value must be"
              % (name, t))
        print("      at or below L* %.3f, or at or above L* %.3f"
              % (dark, pale))
        if not span_ok:
            print("      -- and a value BETWEEN the walls can also work, "
                  "because the walls span more than 2x the threshold")
        else:
            print("      -- nothing between the walls can work: they span "
                  "%.3f, under 2x%.2f = %.2f" % (hi - lo, t, 2 * t))
        print("      the current %.3f is %s"
              % (body, "inside that gap" if dark < body < pale
                 else "already outside it"))
        print()

    # The theme-aware alternative, which the skin is already shaped for:
    # `enemy_skin` takes the theme, so it CAN answer per room.
    print("  per-theme, if the body value were allowed to differ by room:")
    for t in sorted(walls, key=lambda t: walls[t]):
        print("      %-20s darker than %.3f, or paler than %.3f"
              % (t, walls[t] - t_inter, walls[t] + t_inter))
    return 0


if __name__ == "__main__":
    sys.exit(main())
