#!/usr/bin/env python3
"""Repair 2026-09-28 -- the shot list for the skiff and panel before/afters.

    python3 tools/art_repairs_2026_09_28/tint_shots.py <old-models> <new-models>

Prints the JSON `tint_views.gd` reads. Every shot appears twice with the
same camera: once from <old-models> (the reviewed files) and once from
<new-models> (the repaired ones), so a pair differs only in the model.
"""

import json
import sys

FORE = [0.30, 0.85, 0.45]   # review tint: the node NAMED lamp_fore
AFT = [0.86, 0.36, 0.78]    # review tint: the node NAMED lamp_aft

#: Every node the repair renamed: the lamp and the end guard at each end.
END = ["lamp_%s", "skiff_end_%s", "skiff_band_%s", "skiff_cap_%s",
       "skiff_post_%s-1", "skiff_post_%s1"]

SHOTS = [
    # The skiff, from the side and above. The arrow is RailCarrier's
    # FORWARD: the node's +Z (rail_carrier.gd:420 at c12a72f).
    {"name": "skiff", "glb": "batch045/setpieces/sp_skiff_deck.glb",
     "eye": [5.6, 4.2, 0.9], "look": [0.0, 0.2, 0.9], "floor_y": -0.2,
     "tint": dict([(n % "fore", FORE) for n in END]
                  + [(n % "aft", AFT) for n in END]),
     "arrow": [0.0, 2.4, 0.0, 1.0, 2.2]},
    # The five objects whose panels moved, each framed on the moved panel.
    {"name": "generic", "glb": "batch043/physics/phys_generic.glb",
     "eye": [0.75, 0.75, 1.55], "look": [0.0, 0.32, 0.3]},
    {"name": "ballast", "glb": "batch043/physics/phys_ballast.glb",
     "eye": [1.05, 0.95, 2.05], "look": [0.12, 0.25, 0.37]},
    {"name": "mechanical_part",
     "glb": "batch043/physics/phys_mechanical_part.glb",
     "eye": [0.95, 0.7, 0.95], "look": [0.05, 0.18, 0.05]},
    {"name": "movable_cover", "glb": "batch043/physics/phys_movable_cover.glb",
     "eye": [1.3, 1.45, 2.4], "look": [0.0, 0.95, 0.1]},
    {"name": "weighted", "glb": "batch043/physics/phys_weighted.glb",
     "eye": [1.55, 1.1, 1.55], "look": [0.1, 0.35, 0.1]},
]


def main():
    old, new = sys.argv[1], sys.argv[2]
    out = []
    for shot in SHOTS:
        for tag, root in (("old", old), ("new", new)):
            s = dict(shot)
            s["name"] = "%s_%s" % (shot["name"], tag)
            s["glb"] = "%s/%s" % (root, shot["glb"])
            out.append(s)
    json.dump(out, sys.stdout, indent=1)


if __name__ == "__main__":
    main()
