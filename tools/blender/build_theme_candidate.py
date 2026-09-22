"""A BOUNDED CORRECTED CANDIDATE for the tile-edge course break. Batch 055.

    .tools/blender/blender -b --python tools/blender/build_theme_candidate.py

## The defect

Anything drawn with `for y in range(0, surface.size, step)` repeats at
`step` INSIDE the tile and at `size % step` across the tile's own edge.
At 128 px a 38 px course gives 38, 38, 38, 14. The rhythm is even for
3.5 m of wall and then stumbles, once every 4 m, forever.

## FOUR paths draw on a course pitch, and only one was obvious

It took two wrong corrections to find them all, and both wrong turns are
worth keeping because each one looked complete at the time:

1. **`materials.surface_for()`** computes `seams = range(0, size, 38)`
   for every `wall`, `accent` and `wall_ribbed`. The first correction
   named this as the cause, was told that changing the metadata does not
   prove any painted course changed, and over-corrected to "that metadata
   paints nothing" -- because `panel_seams`, the only thing that draws
   `surface.seams` as LINES, is called zero times.
   **That was also wrong.** `paintkit.near_seams()` reads the same tuple
   to aim speckle at thirteen call sites, `paintkit.bolts()` puts a bolt
   row on every seam, and two treatments run weep streaks down from them.
   The seams paint grime, bolts and streaks on a 38 px pitch even where
   no line is drawn on it.
2. **`paintkit.panel_grid`** computes its own `step` from a
   `pitch_metres` that differs per treatment: 1.2, 1.35, 2.0, 0.90,
   0.60, 0.55, 0.40, 0.30 m, and not always the same on both axes.
3. **Inline loops in the treatments themselves**, at course dimensions
   `panel_grid` never sees: ribs at 1.0 m, floor plates at 2.0 m, soffit
   ribs at 0.6 m, chequer at 0.14 m, masonry courses and blocks, station
   tiles at 0.30 m, mortar joints at 0.42 m, editor cells at 0.5 m.
4. **`paintkit.panel_seams`** -- genuinely dead, called zero times.

The second correction shimmed path 2 alone. `concrete_facility_wall_ribbed`
came out BYTE-IDENTICAL, because the ribbed branch takes no `panel_grid`
call at all: its measured 38 px rhythm is path 1. That byte-identical
texture is the evidence that a one-path shim is not the correction.

## So the candidate is built from the real generator, not a shim

`paintkit.SNAP_COURSES` is a module flag, off by default. Every wrapping
pitch in `materials.py` and `paintkit.py` now asks `Surface.course()`
for its step instead of `texels()`, and with the flag off `course()`
returns exactly what those call sites computed before it existed --
which is checked by rebuilding the shipped set and diffing it, not
asserted.

This script turns the flag ON and writes to
`assets/textures/theme_candidate/`. **It never writes the shipped set.**
The owner's instruction is explicit: prepare a corrected candidate and
the evidence to judge it, do not mass-regenerate reviewed production
assets.

## The correction is a snap, and the snap has a real cost

An earlier note proposed starting the courses at `pitch // 2`. That does
not work and the owner said so: moving where the run starts relocates
the odd interval without removing it. Only a pitch the tile is a whole
multiple of removes it.

The divisors of 128 are the powers of two, which is coarse. 43 px
(1.35 m) has nowhere nearer than 32 (1.0 m) to go, so correcting the
break changes the designed course spacing by up to a quarter. **That is
a real change to the look, and it is why this is a candidate for
judgement rather than a fix to apply.**
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import materials  # noqa: E402
import paintkit  # noqa: E402

OUT = os.path.join(common.REPO_ROOT, "assets", "textures", "theme_candidate")
THEMES = ("concrete_facility", "gothic_stone", "neon_transit",
          "rusted_industrial", "temple_ruin", "void_glitch")

#: Every pitch the paint actually asked for, and what the snap did to it.
#: Recorded by watching `Surface.course` rather than by listing call sites
#: from memory, because listing them from memory is what produced two
#: incomplete corrections already.
SNAPS = {}
_REAL_COURSE = paintkit.Surface.course


def _watched_course(self, metres, minimum=2):
    step = _REAL_COURSE(self, metres, minimum)
    plain = max(minimum, self.texels(metres))
    SNAPS[round(metres, 3)] = {"was_px": plain, "now_px": step,
                               "divides": self.size % step == 0}
    return step


def main():
    os.makedirs(OUT, exist_ok=True)
    paintkit.SNAP_COURSES = True
    paintkit.Surface.course = _watched_course
    written = []
    try:
        for theme in THEMES:
            for role in sorted(materials._TREATMENTS[theme]):
                canvas, _ = materials.paint(theme, role)
                name = "%s_%s" % (theme, role)
                # Relative to assets/textures/, and `save_texture` carries
                # its own `_refuse_shipped_path` guard -- so the shipped
                # set cannot be written by accident from here.
                common.save_texture(canvas.to_blender("cand_%s" % name),
                                    "theme_candidate/%s.png" % name)
                written.append(name)
                print("[cand] %s" % name)
    finally:
        paintkit.Surface.course = _REAL_COURSE
        paintkit.SNAP_COURSES = False

    # The seam pitch is not asked for through `course()` -- `surface_for`
    # snaps it directly, because it has a size and a metres and no Surface
    # yet. Record it here so the table is the whole live set.
    seam_was = int(round(materials.ARCH_SIZE * 1.2 / materials.ARCH_METRES))
    SNAPS["1.2 (surface_for seams)"] = {
        "was_px": seam_was,
        "now_px": paintkit.snap_to_tile(seam_was, materials.ARCH_SIZE),
        "divides": True,
    }

    meta = {
        "batch": "055",
        "status": "CANDIDATE -- not a production asset, not applied, not "
                  "approved, not runtime-selected. The shipped set under "
                  "assets/textures/theme/ is untouched and was rebuilt "
                  "byte-identical with SNAP_COURSES off.",
        "what_changed": "Every WRAPPING pitch in the generator asks "
                        "Surface.course() for its step, and with "
                        "paintkit.SNAP_COURSES on that step is the divisor "
                        "of the 128 px tile nearest the designed one. Four "
                        "paths draw on such a pitch: surface_for's seams "
                        "(read by near_seams, bolts and weep streaks), "
                        "paintkit.panel_grid, inline loops in the "
                        "treatments, and bolt pitches along a seam.",
        "why": "range(0, size, step) with a step the size is not a multiple "
               "of leaves an odd interval across the tile's own edge, so "
               "the rhythm breaks once per repeat.",
        "not_a_fix": "pitch // 2 was proposed first and does not work: "
                     "moving where the run starts relocates the odd "
                     "interval without removing it. A panel_grid-only shim "
                     "was tried second and does not work either: "
                     "concrete_facility_wall_ribbed came out byte-identical "
                     "because its 38 px rhythm is surface_for's seams, not "
                     "panel_grid.",
        "cost": "The divisors of 128 are the powers of two. 1.35 m (43 px) "
                "snaps to 1.0 m (32 px) because there is nowhere nearer. "
                "Correcting the break changes designed course spacing by up "
                "to a quarter, which is a look decision for the owner.",
        "snaps": {str(k): v for k, v in sorted(SNAPS.items(), key=str)},
        "textures": sorted(written),
    }
    with open(os.path.join(OUT, "CANDIDATE.json"), "w",
              encoding="utf-8") as handle:
        json.dump(meta, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("candidate set %s (%d textures)" % (OUT, len(written)))


if __name__ == "__main__":
    main()
