"""Batch 066 -- the station's quiet ceiling, a LOCAL texture. APPROVED
(owner, 2026-10-08) for Crossing D's five ceilings only. (Arty.)

    .tools/blender/blender -b --python tools/blender/build_station_quiet_ceiling.py

Writes `assets/textures/station_local/concrete_facility_ceiling_quiet.png`
and `STATION_LOCAL.json` beside it. Nothing else.

WHAT IT IS. T2's quieter ceiling from the targeted noise study: the
`concrete_facility` ceiling painted by `study_station_quiet.py`'s ceiling
painter with QUIET's five ceiling numbers (rib pitch 0.6 -> 1.2 m, no rib
highlight line, broad patches 0.28 -> 0.12, speckle 0.22 -> 0.04, edge
wear 0.7 -> 0.3) and nothing else changed -- same palette ramp, same
128 px tile at 32 texels/m (4.0 m a tile, as the pack's ceiling row).
The painter is imported, not copied, so the study's A/B and this asset
cannot drift apart; the study's `current_ceiling` must still reproduce
the shipped ceiling, and this builder checks that too before writing.

WHAT IT IS NOT. Not a theme-pack row and not a replacement for
`assets/textures/theme/concrete_facility_ceiling.png`, which stays as
shipped and keeps painting every other ceiling that asks for the role.
The owner's ruling: "Keep it restricted to the intended ceiling
surfaces, not a global material replacement." So it lives in its own
directory, under its own name, and the manifest names the five nodes it
is for: HallCeiling, ArrivalCeiling, CourtCeiling, MachineCeiling and
YardCeiling in `crossing_d_room.gd`.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys

import bpy  # noqa: F401  (Blender provides it; the canvas exports through it)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import study_station_quiet as quiet  # noqa: E402

NAME = "concrete_facility_ceiling_quiet"
REL = "station_local/%s.png" % NAME
NODES = ["HallCeiling", "ArrivalCeiling", "CourtCeiling", "MachineCeiling",
         "YardCeiling"]


def _pixels(path):
    image = bpy.data.images.load(path)
    try:
        return list(image.pixels)
    finally:
        bpy.data.images.remove(image)


def main():
    # Provenance first: the painter this imports must still reproduce the
    # shipped ceiling with QUIET off, or "quiet" is relative to nothing.
    shipped = os.path.join(common.TEXTURE_DIR, "theme",
                           "%s_ceiling.png" % quiet.THEME)
    probe = quiet.paint("ceiling", False).to_blender("probe_current_ceiling")
    assert list(probe.pixels) == _pixels(shipped), \
        "the ceiling painter no longer reproduces the shipped texture"
    canvas = quiet.paint("ceiling", True)
    common.save_texture(canvas.to_blender(NAME), REL)
    out = os.path.join(common.TEXTURE_DIR, REL)
    with open(out, "rb") as handle:
        digest = hashlib.sha256(handle.read()).hexdigest()
    meta = {
        "batch": "066",
        "status": "APPROVED (owner, 2026-10-08) for Crossing D's five "
                  "ceilings only; not a theme-pack row; the shipped "
                  "concrete_facility ceiling is unchanged",
        "texture": REL,
        "sha256": digest,
        "size_px": canvas.size,
        "covers_m": 4.0,
        "texels_per_metre": canvas.size / 4.0,
        "for_nodes": {"crossing_d_room.gd": NODES},
        "not_for": "any other surface, theme or room; never written over "
                   "assets/textures/theme/ or the pack's `ceiling` row",
        "source": "tools/blender/study_station_quiet.py, ceiling painter, "
                  "QUIET on",
        "quiet_numbers": {k: list(v) for k, v in quiet.QUIET.items()
                          if k.startswith("ceiling.")},
        "measured": "T2 hall-stair view: ceiling edge strength 46.7 as "
                    "played -> 29.9 with the shipped ceiling role -> 21.8 "
                    "with this texture (docs/art-requests/"
                    "2026-10-08-station-noise-handoff.md)",
    }
    with open(os.path.join(os.path.dirname(out), "STATION_LOCAL.json"), "w",
              encoding="utf-8") as handle:
        json.dump(meta, handle, indent=2, sort_keys=True)
        handle.write("\n")
    common.log("%s (%s)" % (REL, digest[:16]))


if __name__ == "__main__":
    main()
