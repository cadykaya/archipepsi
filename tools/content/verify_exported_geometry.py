"""Check a manifest's DIMENSIONS and ATTACH POINTS against what shipped.

    python3 tools/content/verify_exported_geometry.py

An attachment point is a promise about a place on an object, and it is made
in a document while the object is made somewhere else. Two things can go
wrong between them and both did:

  * the origin shift. `set_origin_group` re-bases an asset on its anchor by
    moving vertices; a point recorded before that and not moved with it is
    wrong by the shift, and a point moved twice is wrong the other way.
  * the axis convention. Blender authors Z-up; glTF is Y-UP BY DEFINITION.
    A manifest that says "+Z is up" beside geometry exported Y-up describes
    an object nobody can load.

So this does not read the builder. It opens the EXPORTED `.glb` and measures
it.

TWO CHECKS, BECAUSE THE FIRST ONE ALONE WAS NOT ENOUGH.

  * ATTACH POINTS. Find the node the point names, read that node's own
    accessor bounds, and confirm the recorded runtime position lies on or
    inside it. Catches a missing origin shift, a double shift, and a point
    naming a node that is not there.

  * DIMENSIONS. Take the union of every mesh node's bounds, WITH ITS NODE
    TRANSFORM APPLIED, and compare the result to `size_runtime_y_up`.

The second exists because the first passed while every dimension in the
batch was wrong. `size_runtime_y_up` had been filled straight from the
exporter's authoring-axis triple, so Y and Z were swapped in all fifteen
entries: `phys_power_cell` declared 0.34 / 0.34 / 0.60 against an actual
0.34 / 0.60 / 0.34. Attach points are POINTS -- they were converted
correctly and landed correctly -- and a point check cannot see a size.

A swapped axis is only visible on an object that is not square, so the
batch's asymmetric members are what give this check teeth: `phys_plate` is
1.80 / 0.145 / 0.92 and `phys_movable_cover` is 1.326 / 1.72 / 0.26. Swap
any two axes on either and the comparison fails by more than a metre. The
check is self-testing on that point -- it refuses to run unless the manifest
contains an object whose three extents differ enough to expose a swap.

Node transforms are applied because at least one asset has one: the wall
switch's `lever_arm` hangs off a `hinge_lever` node that carries the
pintle's translation, so ignoring it would measure the arm in the wrong
place.
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


def node_chain_offset(gltf, index, parents):
    """The accumulated translation of a node, through its parents.

    Only translation: this batch exports no rotated or scaled nodes, and a
    silent identity assumption about rotation would be exactly the kind of
    thing this file exists to stop. If a rotated node ever appears, the
    assertion below fails loudly rather than measuring it wrong.
    """
    offset = [0.0, 0.0, 0.0]
    seen = set()
    cursor = index
    while cursor is not None and cursor not in seen:
        seen.add(cursor)
        node = gltf["nodes"][cursor]
        for key in ("rotation", "scale", "matrix"):
            if key in node:
                raise SystemExit(
                    "node `%s` carries a %s; this checker only accumulates "
                    "translations and would measure it wrong. Teach it the "
                    "full transform rather than trusting this number."
                    % (node.get("name", cursor), key))
        t = node.get("translation", [0.0, 0.0, 0.0])
        offset = [offset[i] + t[i] for i in range(3)]
        cursor = parents.get(cursor)
    return offset


def measure(gltf):
    """The union AABB of every mesh node, in runtime axes, with transforms."""
    parents = {}
    for i, node in enumerate(gltf.get("nodes", [])):
        for child in node.get("children", []):
            parents[child] = i
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for i, node in enumerate(gltf.get("nodes", [])):
        if node.get("mesh") is None:
            continue
        off = node_chain_offset(gltf, i, parents)
        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            for axis in range(3):
                lo[axis] = min(lo[axis], acc["min"][axis] + off[axis])
                hi[axis] = max(hi[axis], acc["max"][axis] + off[axis])
    return [hi[i] - lo[i] for i in range(3)]


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


#: How far apart two extents may be before it is a disagreement, not
#: rounding. The manifest rounds to 3 dp.
SIZE_TOLERANCE = 0.005

#: A size check can only catch a swapped axis on an object whose extents
#: actually differ. This is the smallest spread the manifest must contain
#: somewhere, or the check has no teeth and says so.
MIN_ASYMMETRY = 0.25


def check(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    problems, checked = [], 0
    sized, best_spread, spread_owner = 0, 0.0, None
    for asset_id, entry in sorted(manifest.items()):
        glb = os.path.join(ROOT, "assets", "models", entry["path"])
        gltf, _ = read_glb(glb)

        declared = entry.get("size_runtime_y_up")
        if declared is not None:
            sized += 1
            want = [declared["x"], declared["y_up"], declared["z"]]
            spread = max(want) - min(want)
            if spread > best_spread:
                best_spread, spread_owner = spread, asset_id
            got = measure(gltf)
            off = [abs(want[i] - got[i]) for i in range(3)]
            if max(off) > SIZE_TOLERANCE:
                swapped = ""
                for a, b in ((0, 1), (1, 2), (0, 2)):
                    trial = list(want)
                    trial[a], trial[b] = trial[b], trial[a]
                    if all(abs(trial[i] - got[i]) <= SIZE_TOLERANCE
                           for i in range(3)):
                        swapped = ("  -- these match with %s and %s swapped, "
                                   "so the axis convention is wrong rather "
                                   "than the geometry"
                                   % ("XYZ"[a], "XYZ"[b]))
                        break
                problems.append(
                    "%s declares size_runtime_y_up %s; the exported geometry "
                    "measures %s%s"
                    % (asset_id, [round(v, 3) for v in want],
                       [round(v, 3) for v in got], swapped))

        points = entry.get("attach_points")
        if not points:
            continue
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
    if sized and best_spread < MIN_ASYMMETRY:
        problems.append(
            "no asset in %s has extents more than %.2f m apart (widest is "
            "`%s`). A size check cannot see a swapped axis on a cube, so "
            "this one currently has no teeth."
            % (os.path.relpath(manifest_path, ROOT), best_spread,
               spread_owner))
    return checked, problems, sized


def main():
    total, sized_total, all_problems = 0, 0, []
    for manifest in sorted(glob.glob(os.path.join(
            ROOT, "assets", "models", "batch043", "*", "manifest.json"))):
        checked, problems, sized = check(manifest)
        total += checked
        sized_total += sized
        all_problems += problems
    if all_problems:
        print("verify-geometry: %d PROBLEM(S)" % len(all_problems))
        for line in all_problems:
            print("  - %s" % line)
        sys.exit(1)
    print("verify-geometry: %d size(s) and %d attach point(s) verified "
          "against the exported geometry, in runtime Y-up coordinates"
          % (sized_total, total))


if __name__ == "__main__":
    main()
