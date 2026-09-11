"""Check every attach point in a manifest against the geometry that shipped.

    python3 tools/content/verify_attach_points.py

An attachment point is a promise about a place on an object, and it is made
in a document while the object is made somewhere else. Two things can go
wrong between them and both did:

  * the origin shift. `set_origin_group` re-bases an asset on its anchor by
    moving vertices; a point recorded before that and not moved with it is
    wrong by the shift, and a point moved twice is wrong the other way.
  * the axis convention. Blender authors Z-up; glTF is Y-UP BY DEFINITION.
    A manifest that says "+Z is up" beside geometry exported Y-up describes
    an object nobody can load.

So this does not read the builder. It opens the EXPORTED `.glb`, finds the
node the attach point names, reads that node's own vertices, and checks the
recorded runtime position lies on or inside that part's box. It would catch
a missing shift, a double shift, and a wrong axis convention -- because each
puts the point somewhere the part is not.
"""

from __future__ import annotations

import glob
import json
import os
import struct
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TOLERANCE = 0.030          # metres; a pad's own thickness, roughly


def read_glb(path):
    with open(path, "rb") as handle:
        struct.unpack("<4sII", handle.read(12))
        gltf, binary = None, b""
        while True:
            header = handle.read(8)
            if len(header) < 8:
                break
            size, kind = struct.unpack("<I4s", header)
            payload = handle.read(size)
            if kind == b"JSON":
                gltf = json.loads(payload.decode("utf-8"))
            elif kind == b"BIN\x00":
                binary = payload
    return gltf, binary


def part_box(gltf, name):
    """The min/max of the named node's mesh, from the accessor's own bounds.

    glTF requires POSITION accessors to carry `min` and `max`, so the box is
    read rather than recomputed -- there is nothing to get wrong.
    """
    for node in gltf.get("nodes", []):
        if node.get("name") != name or node.get("mesh") is None:
            continue
        mesh = gltf["meshes"][node["mesh"]]
        lo = [1e9] * 3
        hi = [-1e9] * 3
        for prim in mesh["primitives"]:
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            for i in range(3):
                lo[i] = min(lo[i], acc["min"][i])
                hi[i] = max(hi[i], acc["max"][i])
        # A node may carry its own translation (a hinge's child does not,
        # but be exact rather than lucky).
        t = node.get("translation", [0.0, 0.0, 0.0])
        return ([lo[i] + t[i] for i in range(3)],
                [hi[i] + t[i] for i in range(3)])
    return None


def check(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    problems, checked = [], 0
    for asset_id, entry in sorted(manifest.items()):
        points = entry.get("attach_points")
        if not points:
            continue
        glb = os.path.join(ROOT, "assets", "models", entry["path"])
        gltf, _ = read_glb(glb)
        for point in points:
            checked += 1
            name = point.get("part")
            if name is None:
                problems.append("%s/%s names no part" % (asset_id,
                                                         point["id"]))
                continue
            box = part_box(gltf, name)
            if box is None:
                problems.append("%s/%s names part `%s`, which the exported "
                                ".glb does not contain"
                                % (asset_id, point["id"], name))
                continue
            lo, hi = box
            pos = point["position"]
            gaps = []
            for i, axis in enumerate("XYZ"):
                if pos[i] < lo[i] - TOLERANCE:
                    gaps.append("%s %.4f below %.4f" % (axis, pos[i], lo[i]))
                elif pos[i] > hi[i] + TOLERANCE:
                    gaps.append("%s %.4f above %.4f" % (axis, pos[i], hi[i]))
            if gaps:
                problems.append(
                    "%s/%s at %s is off its own part `%s` (%s..%s): %s"
                    % (asset_id, point["id"], pos, name,
                       [round(v, 3) for v in lo], [round(v, 3) for v in hi],
                       "; ".join(gaps)))
            n = point.get("normal")
            if n is None or abs(sum(c * c for c in n) - 1.0) > 1e-3:
                problems.append("%s/%s has no unit normal (%s)"
                                % (asset_id, point["id"], n))
    return checked, problems


def main():
    total, all_problems = 0, []
    for manifest in sorted(glob.glob(os.path.join(
            ROOT, "assets", "models", "batch043", "*", "manifest.json"))):
        checked, problems = check(manifest)
        total += checked
        all_problems += problems
    if all_problems:
        print("verify-attach: %d PROBLEM(S)" % len(all_problems))
        for line in all_problems:
            print("  - %s" % line)
        sys.exit(1)
    print("verify-attach: %d attach point(s) verified against the exported "
          "geometry, in runtime Y-up coordinates" % total)


if __name__ == "__main__":
    main()
