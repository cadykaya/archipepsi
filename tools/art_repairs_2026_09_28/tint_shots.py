#!/usr/bin/env python3
"""Repair 2026-09-28 -- the shot list for the skiff and panel before/afters.

    python3 tools/art_repairs_2026_09_28/tint_shots.py <old-models> <new-models>

Prints the JSON `tint_views.gd` reads. Every shot appears twice with the
same camera: once from <old-models> (the reviewed files) and once from
<new-models> (the repaired ones), so a pair differs only in the model.

    ... tint_shots.py <old-models> <new-models> followup [old-ref]

The follow-up set: the seven props whose panels were re-seated after the
first repair (<old-ref>, default e4103ba). No camera is placed by hand.
Each is aimed from the two manifests at the panels that moved, from the
face they now sit on, so the before and after frames look at the same
place.
"""

import json
import math
import os
import subprocess
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


ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
PHYS = "assets/models/batch043/physics/manifest.json"
NORMAL = {"+Z": (0, 0, 1), "-Z": (0, 0, -1), "+X": (1, 0, 0),
          "-X": (-1, 0, 0), "+Y (top)": (0, 1, 0)}


def _boxes(path):
    """Mesh node -> (lo, hi), runtime, from the POSITION accessors' own
    min/max. The physics props export their nodes unrotated (asserted by
    verify_053_panels.py), so a translation is all there is to add."""
    with open(path, "rb") as handle:
        data = handle.read()
    length = int.from_bytes(data[12:16], "little")
    doc = json.loads(data[20:20 + length])
    out = {}
    for node in doc["nodes"]:
        if "mesh" not in node:
            continue
        t = node.get("translation", [0.0, 0.0, 0.0])
        lo, hi = [9e9] * 3, [-9e9] * 3
        for prim in doc["meshes"][node["mesh"]]["primitives"]:
            acc = doc["accessors"][prim["attributes"]["POSITION"]]
            lo = [min(lo[k], acc["min"][k] + t[k]) for k in range(3)]
            hi = [max(hi[k], acc["max"][k] + t[k]) for k in range(3)]
        out[node["name"]] = (lo, hi)
    return out


def _facing(boxes, name):
    """The outward normal of the face a panel sits on: its thin axis,
    pointing away from the middle of the whole model."""
    lo, hi = boxes[name]
    k = min(range(3), key=lambda i: hi[i] - lo[i])
    mid = (min(b[0][k] for b in boxes.values())
           + max(b[1][k] for b in boxes.values())) / 2.0
    n = [0, 0, 0]
    n[k] = 1 if (lo[k] + hi[k]) / 2.0 > mid else -1
    return tuple(n)


def followup(ref, old_root, new_root):
    """One shot per prop whose panels moved after `ref`: from the face the
    first moved panel sits on now AND the face it sat on before, so both
    frames of the pair can show it."""
    was = json.loads(subprocess.run(
        ["git", "show", "%s:%s" % (ref, PHYS)], cwd=ROOT, check=True,
        capture_output=True).stdout)
    with open(os.path.join(ROOT, PHYS), encoding="utf-8") as handle:
        now = json.load(handle)
    shots = []
    for asset in sorted(now):
        panels = now[asset].get("lightened_panels", {}).get("panels", {})
        if not panels:
            continue
        before = was[asset]["lightened_panels"]["panels"]
        names = [n for n, p in sorted(panels.items())
                 if p["centre_runtime"] != before[n]["centre_runtime"]]
        if not names:
            continue
        glb = "batch043/physics/%s.glb" % asset
        old_boxes = _boxes("%s/%s" % (old_root, glb))
        new_boxes = _boxes("%s/%s" % (new_root, glb))
        moved = [(before[n]["centre_runtime"], panels[n]["centre_runtime"],
                  _facing(new_boxes, n), _facing(old_boxes, n))
                 for n in names]
        for n, m in zip(names, moved):
            if NORMAL[panels[n]["face_runtime"]] != m[2]:
                raise SystemExit("%s %s: the model says %s, the manifest %s"
                                 % (asset, n, m[2],
                                    panels[n]["face_runtime"]))
        # The first panel that moved sets the view: from its face now and
        # its face before, at the middle of its two places. A mirrored
        # partner on the far side may be out of frame; pairs are symmetric.
        before_at, now_at, face_now, face_before = moved[0]
        total = [face_now[k] + face_before[k] for k in range(3)]
        if math.hypot(*total) < 0.5:
            total = list(face_now)
        d = [c / math.hypot(*total) for c in total]
        lift = (0.5, 0.6, 0.5)
        along = sum(a * b for a, b in zip(lift, d))
        eye_dir = [2.0 * d[k] + lift[k] - along * d[k] for k in range(3)]
        n = math.hypot(*eye_dir)
        look = [(before_at[k] + now_at[k]) / 2.0 for k in range(3)]
        reach = max(now[asset]["size"])
        # Close enough to read a panel on a long prop, far enough to
        # show the body round it.
        dist = min(1.8, max(0.9, 1.2 * reach + 0.45))
        # The review tint marks every panel, moved or not, in both frames:
        # in its real grey-blue a panel on a pale deck is hard to find, and
        # these frames are about WHERE it sits. Sheet 3 shows the real look.
        shots.append({"name": asset[len("phys_"):],
                      "glb": glb,
                      "tint": dict((n, AFT) for n in sorted(panels)),
                      "eye": [round(look[k] + dist * eye_dir[k] / n, 3)
                              for k in range(3)],
                      "look": [round(c, 3) for c in look]})
    return shots


def main():
    old, new = sys.argv[1], sys.argv[2]
    shots = SHOTS
    if len(sys.argv) > 3 and sys.argv[3] == "followup":
        shots = followup(sys.argv[4] if len(sys.argv) > 4 else "e4103ba",
                         old, new)
    out = []
    for shot in shots:
        for tag, root in (("old", old), ("new", new)):
            s = dict(shot)
            s["name"] = "%s_%s" % (shot["name"], tag)
            s["glb"] = "%s/%s" % (root, shot["glb"])
            out.append(s)
    json.dump(out, sys.stdout, indent=1)


if __name__ == "__main__":
    main()
