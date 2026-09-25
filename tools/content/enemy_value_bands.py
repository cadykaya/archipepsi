#!/usr/bin/env python3
"""Tier 1 -- the fewest theme-dependent VALUE BANDS the measurement permits.

    python3 tools/content/enemy_value_bands.py <sweep dir>

`<sweep dir>` is what `run_enemy_value_sweep.sh` writes: one
`k<lightness>.json` per step of the lightness grid (each a
`run_enemy_contrast.sh` result for the ten enemies with their body ramp's
L* scaled by that factor, hue and chroma held), plus
`limit_black_matte.json`, the same row painted pure black and made fully
matte -- the darkest a body can render in each room, set by the room's own
fog, not by paint.

Owner ruling, 2026-09-25: *"Use the smallest practical set of
theme-dependent VALUE BANDS ... If two bands can satisfy the real rendered
cases, prefer two ... Do not create six independent treatments merely
because there are six themes"*, and *"vary the value treatment only as
far as needed"*.

So, per theme, the LIGHTEST grid step at which the body clears the
threshold in every case the bands are chosen on (wall, floor, dim --
darker is better in all three, measured, so a theme that clears at k clears
below it; the script checks that rather than assuming it). Then, for one,
two and three bands, the grouping that darkens least in total -- a band's
lightness is its most demanding member's. Ties go to the grouping whose
worst OPENING is least bad: the opening case (the room's fogged void behind
the row) is not monotone -- in four rooms the void is darker than the
walls, so darkening passes THROUGH it -- and it is reported beside every
grouping rather than silently chosen on.

A theme no grid step clears is SHORT at that threshold; the black-matte
limit says whether any paint could clear it at all.

Writes `<sweep dir>/../value_bands.json` and prints the derivation.
"""

import glob
import itertools
import json
import os
import sys

THEMES = ["concrete_facility", "rusted_industrial", "neon_transit",
          "gothic_stone", "temple_ruin", "void_glitch"]
CHOSEN_ON = ["wall", "floor", "dim"]
OPENING = "opening"
FLAG = {0.10: "clears_value", 0.18: "clears_interactable"}


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def signed(run, theme, case):
    """Background minus body: positive means the body is the darker."""
    row = run[theme][case]
    return round(row["background_lstar"] - row["body_lstar"], 3)


def clears(run, theme, case, threshold):
    # The harness's own flag, computed on the unrounded separation --
    # re-deriving it from the rounded numbers would pass a 0.0999.
    return bool(run[theme][case][FLAG[threshold]])


def lightest(sweep, grid, theme, threshold):
    """(lightest clearing step or None, the case that binds, monotone?)"""
    ok = [k for k in grid
          if all(clears(sweep[k], theme, c, threshold) for c in CHOSEN_ON)]
    if not ok:
        return None, None, True
    best = max(ok)
    monotone = all(k in ok for k in grid if k <= best)
    lighter = [k for k in grid if k > best]
    binding = None
    if lighter:
        step = min(lighter)
        binding = next(c for c in CHOSEN_ON
                       if not clears(sweep[step], theme, c, threshold))
    return best, binding, monotone


def groupings(need, floor_k, bands):
    """Every split of the themes, ordered by need, into `bands` groups."""
    order = sorted(THEMES, key=lambda t: -(need[t] if need[t] is not None
                                           else -1.0))
    for cuts in itertools.combinations(range(1, len(order)), bands - 1):
        edges = (0,) + cuts + (len(order),)
        groups = [order[a:b] for a, b in zip(edges, edges[1:])]
        by_theme = {}
        for g in groups:
            ks = [need[t] for t in g if need[t] is not None]
            k = min(ks) if len(ks) == len(g) else floor_k
            for t in g:
                by_theme[t] = k
        yield groups, by_theme


def main():
    if len(sys.argv) < 2:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    root = sys.argv[1]
    sweep = {}
    for path in glob.glob(os.path.join(root, "k*.json")):
        k = float(os.path.basename(path)[1:-5])
        sweep[k] = load(path)
    limit = load(os.path.join(root, "limit_black_matte.json"))
    grid = sorted(sweep, reverse=True)
    if len(grid) < 3 or 1.0 not in sweep:
        print("enemy-value-bands: FAIL -- need the shipped skin (k1.00) and "
              "at least two darker steps; found %s" % grid, file=sys.stderr)
        return 1
    for k in grid:
        faults = sweep[k].get("_faults") or []
        missing = [t for t in THEMES if t not in sweep[k]]
        if faults or missing:
            print("enemy-value-bands: FAIL -- k%.2f has faults %s / missing "
                  "%s" % (k, faults, missing), file=sys.stderr)
            return 1
    floor_k = min(grid)
    t_value = float(sweep[1.0]["_meta"]["min_value_separation"])
    t_inter = float(sweep[1.0]["_meta"]["min_interactable_separation"])

    print("separation from the background, body darker = positive, at "
          "each lightness (k) of the body ramp; LIMIT = pure black, matte")
    head = "".join("%8s" % ("%.2f" % k) for k in grid) + "   LIMIT"
    per_theme = {}
    for t in THEMES:
        print("\n%s%s" % (t.ljust(26), head))
        for c in CHOSEN_ON + [OPENING]:
            row = [signed(sweep[k], t, c) for k in grid]
            print("  %-7s bg %.3f %s  %7.3f" % (
                c, sweep[1.0][t][c]["background_lstar"],
                "".join("%8.3f" % v for v in row), signed(limit, t, c)))
        entry = {}
        for thr in (t_value, t_inter):
            best, binding, monotone = lightest(sweep, grid, t, thr)
            if not monotone:
                print("enemy-value-bands: FAIL -- %s clears %.2f at k%.2f but "
                      "not at every darker step; darker-is-better does not "
                      "hold and a band cannot be chosen this way"
                      % (t, thr, best), file=sys.stderr)
                return 1
            lim = all(clears(limit, t, c, thr) for c in CHOSEN_ON)
            entry["%.2f" % thr] = {
                "lightest_clearing": best,
                "binding_case": binding,
                "black_matte_limit_clears": lim}
        entry["opening_by_lightness"] = {
            "%.2f" % k: signed(sweep[k], t, OPENING) for k in grid}
        entry["black_matte_limit"] = {
            c: signed(limit, t, c) for c in CHOSEN_ON + [OPENING]}
        per_theme[t] = entry

    need = {t: per_theme[t]["%.2f" % t_value]["lightest_clearing"]
            for t in THEMES}
    print("\nlightest step clearing %.2f in %s:" % (t_value,
                                                    " + ".join(CHOSEN_ON)))
    for t in THEMES:
        e = per_theme[t]["%.2f" % t_value]
        print("  %-18s %s%s" % (
            t, "k%.2f" % need[t] if need[t] is not None else "SHORT at every "
            "step", "" if need[t] is not None else
            (" (black matte clears)" if e["black_matte_limit_clears"]
             else " (not even black matte clears)")))
    short_inter = [t for t in THEMES
                   if per_theme[t]["%.2f" % t_inter]["lightest_clearing"]
                   is None]
    print("clearing %.2f in all three: SHORT at every step in %d of 6 (%s)"
          % (t_inter, len(short_inter), ", ".join(short_inter) or "none"))

    partitions = {}
    for bands in (1, 2, 3):
        best = None
        for groups, by_theme in groupings(need, floor_k, bands):
            kept = round(sum(by_theme.values()), 3)
            worst = min(signed(sweep[by_theme[t]], t, OPENING)
                        for t in THEMES)
            key = (kept, worst)
            if best is None or key > best[0]:
                best = (key, groups, by_theme)
        (kept, worst), groups, by_theme = best
        bands_out = [{"lightness": by_theme[g[0]], "themes": g}
                     for g in groups]
        short = sorted(
            [{"theme": t, "case": c,
              "separation": signed(sweep[by_theme[t]], t, c)}
             for t in THEMES for c in CHOSEN_ON
             if not clears(sweep[by_theme[t]], t, c, t_value)],
            key=lambda r: (r["theme"], r["case"]))
        openings = {t: signed(sweep[by_theme[t]], t, OPENING) for t in THEMES}
        partitions[str(bands)] = {"bands": bands_out, "by_theme": by_theme,
                                  "lightness_kept": kept,
                                  "short_at_%.2f" % t_value: short,
                                  "opening": openings}
        print("\n%d band(s), lightness kept %.2f of 6.00:" % (bands, kept))
        for b in bands_out:
            print("  k%.2f  %s" % (b["lightness"], ", ".join(b["themes"])))
        for s in short:
            print("  SHORT  %s %s %.3f" % (s["theme"], s["case"],
                                          s["separation"]))
        print("  opening: " + "  ".join(
            "%s %.3f" % (t.split("_")[0], openings[t]) for t in THEMES))

    out = os.path.join(os.path.dirname(os.path.abspath(root.rstrip("/"))),
                       "value_bands.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump({
            "_about": "Derived by tools/content/enemy_value_bands.py from "
                      "the sweep beside this file. A CANDIDATE: nothing "
                      "here is landed or approved.",
            "grid": grid,
            "chosen_on": CHOSEN_ON,
            "reported": OPENING,
            "thresholds": {"value": t_value, "interactable": t_inter},
            "meta": sweep[1.0]["_meta"],
            "per_theme": per_theme,
            "partitions": partitions,
        }, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print("\nwrote %s" % out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
