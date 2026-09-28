#!/usr/bin/env python3
"""Repair 2026-09-28, family 049 -- do the new hinges do what the manifest says?

    python3 tools/art_repairs_2026_09_28/verify_049_hinges.py [old-ref]

Reads the six hinged 049 models AS EXPORTED -- the .glb a loader sees --
and the manifest beside them, and checks each one:

  1. REST. Every mesh node's world-space vertices, UVs and materials are
     what they were at <old-ref> (default a1584c8, the reviewed source).
     The repair moves no shape; it only gives the moving parts a real pin.
  2. HINGE. The hinge node is a root node at the manifest's
     `pivot_runtime` with no rotation or scale, it carries exactly the
     manifest's parts at identity, and the pin lies inside the first part
     it carries.
  3. POSITIONS. For every declared angle this prints what the OLD file
     did with the same angle -- the part's own node turned about the
     asset origin -- as the distance its pin travels. With the hinge that
     distance is zero by construction; the old number is the defect.
  4. DIAL. At each detent the pointer points at its tooth.

Read-only: it writes nothing. Exit 1 on any failure.
"""

from __future__ import annotations

import json
import math
import os
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
DIR = "assets/models/batch049/connect"
AXES = {"x": (1.0, 0.0, 0.0), "z": (0.0, 0.0, 1.0)}
TOL = 1e-5


def parse(data: bytes) -> tuple[dict, bytes]:
    doc, blob, off = None, b"", 12
    while off < len(data):
        length, kind = struct.unpack_from("<I4s", data, off)
        chunk = data[off + 8:off + 8 + length]
        if kind == b"JSON":
            doc = json.loads(chunk)
        elif kind == b"BIN\x00":
            blob = chunk
        off += 8 + length
    return doc, blob


def load(ref: str | None, path: str) -> tuple[dict, bytes]:
    if ref:
        data = subprocess.run(["git", "show", "%s:%s" % (ref, path)],
                              cwd=ROOT, check=True,
                              capture_output=True).stdout
    else:
        with open(os.path.join(ROOT, path), "rb") as handle:
            data = handle.read()
    return parse(data)


def trs(node: dict) -> list[list[float]]:
    t = node.get("translation", [0.0, 0.0, 0.0])
    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    s = node.get("scale", [1.0, 1.0, 1.0])
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[i][0] * s[0], r[i][1] * s[1], r[i][2] * s[2], t[i]]
            for i in range(3)] + [[0.0, 0.0, 0.0, 1.0]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)]
            for i in range(4)]


def apply(m, v):
    return tuple(m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2] + m[i][3]
                 for i in range(3))


def rotation(axis: str, degrees: float):
    """Right-hand rotation about a unit axis, as a 4x4."""
    x, y, z = AXES[axis]
    a = math.radians(degrees)
    c, s, t = math.cos(a), math.sin(a), 1 - math.cos(a)
    return [[t * x * x + c, t * x * y - s * z, t * x * z + s * y, 0.0],
            [t * x * y + s * z, t * y * y + c, t * y * z - s * x, 0.0],
            [t * x * z - s * y, t * y * z + s * x, t * z * z + c, 0.0],
            [0.0, 0.0, 0.0, 1.0]]


def accessor(doc, blob, index, width):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 4 * width)
    fmt = "<%df" % width
    return [struct.unpack_from(fmt, blob, start + i * stride)
            for i in range(acc["count"])]


def meshes(doc, blob):
    """name -> world vertices, local vertices, uvs, materials, parent, node."""
    out = {}

    def visit(i, parent_m, parent_name):
        node = doc["nodes"][i]
        m = mul(parent_m, trs(node))
        name = node.get("name", "?")
        if "mesh" in node:
            local, uv, mats = [], [], []
            for prim in doc["meshes"][node["mesh"]]["primitives"]:
                local += accessor(doc, blob, prim["attributes"]["POSITION"], 3)
                if "TEXCOORD_0" in prim["attributes"]:
                    uv += accessor(doc, blob,
                                   prim["attributes"]["TEXCOORD_0"], 2)
                if "material" in prim:
                    mats.append(doc["materials"][prim["material"]]["name"])
            out[name] = {"world": [apply(m, v) for v in local],
                         "local": local, "uv": uv, "materials": mats,
                         "parent": parent_name, "node": node, "matrix": m}
        else:
            out[name] = {"parent": parent_name, "node": node, "matrix": m}
        for child in node.get("children", []):
            visit(child, m, name)

    ident = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
    for i in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        visit(i, ident, None)
    return out


def centroid(points):
    n = float(len(points))
    return tuple(sum(p[k] for p in points) / n for k in range(3))


def main() -> int:
    old_ref = sys.argv[1] if len(sys.argv) > 1 else "a1584c8"
    with open(os.path.join(ROOT, DIR, "manifest.json"),
              encoding="utf-8") as handle:
        manifest = json.load(handle)
    problems: list[str] = []
    hinged = sorted(k for k, v in manifest.items() if "hinge" in v)
    print("049 hinges: %d model(s) declare one; old ref %s"
          % (len(hinged), old_ref))
    for asset in hinged:
        h = manifest[asset]["hinge"]
        path = "%s/%s.glb" % (DIR, asset)
        old = meshes(*load(old_ref, path))
        new = meshes(*load(None, path))

        # 1. REST -- nothing moved.
        for name, was in old.items():
            if "world" not in was:
                continue
            now = new.get(name)
            if now is None or "world" not in now:
                problems.append("%s: mesh node %s is gone" % (asset, name))
                continue
            drift = max(max(abs(a - b) for a, b in zip(p, q))
                        for p, q in zip(was["world"], now["world"]))
            if len(was["world"]) != len(now["world"]) or drift > TOL:
                problems.append("%s: %s moved at rest (%.6f m)"
                                % (asset, name, drift))
            if was["uv"] != now["uv"] or was["materials"] != now["materials"]:
                problems.append("%s: %s changed UVs or material"
                                % (asset, name))

        # 2. HINGE -- where the manifest says, carrying what it says.
        hinge = new.get(h["node"])
        if hinge is None or hinge["parent"] is not None:
            problems.append("%s: no root hinge node %s" % (asset, h["node"]))
            continue
        node = hinge["node"]
        at = node.get("translation", [0.0, 0.0, 0.0])
        if any(abs(a - b) > TOL for a, b in zip(at, h["pivot_runtime"])):
            problems.append("%s: hinge at %s, manifest says %s"
                            % (asset, at, h["pivot_runtime"]))
        if node.get("rotation", [0, 0, 0, 1]) != [0, 0, 0, 1] and any(
                abs(a - b) > TOL for a, b in
                zip(node["rotation"], [0.0, 0.0, 0.0, 1.0])):
            problems.append("%s: the hinge is rotated as built" % asset)
        carried = sorted(n for n, v in new.items() if v["parent"] == h["node"])
        if carried != sorted(h["carries"]):
            problems.append("%s: hinge carries %s, manifest says %s"
                            % (asset, carried, h["carries"]))
        for name in carried:
            child = new[name]["node"]
            if any(k in child for k in ("translation", "rotation", "scale")):
                problems.append("%s: %s is not at identity under its hinge"
                                % (asset, name))
        first = new[h["carries"][0]]["local"]
        inside = all(min(v[k] for v in first) - 1e-4 <= 0.0
                     <= max(v[k] for v in first) + 1e-4 for k in range(3))
        if not inside:
            problems.append("%s: the pin is outside %s"
                            % (asset, h["carries"][0]))

        # 3. POSITIONS -- the pin stays; the old way, it travelled.
        pin = tuple(h["pivot_runtime"])
        rows = []
        for pose, deg in sorted(h["positions_degrees"].items(),
                                key=lambda kv: kv[1]):
            moved = apply(rotation(h["axis"], deg), pin)
            travel = math.dist(moved, pin)
            rows.append("%s %+.0f deg: old pin travel %.3f m"
                        % (pose, deg, travel))
        print("  %-18s %-16s pin %s axis %s -- %s"
              % (asset, h["node"], pin, h["axis"].upper(), "; ".join(rows)))

        # 4. DIAL -- each detent points the pointer at its tooth.
        if asset == "conn_set_dial":
            pointer = new["dial_pointer"]["local"]
            for pose, deg in h["positions_degrees"].items():
                turned = [apply(rotation("z", deg), v) for v in pointer]
                c = centroid(turned)
                aim = math.degrees(math.atan2(c[1], c[0]))
                tooth = centroid(new["dial_tooth_%s" % pose[-1]]["world"])
                want = math.degrees(math.atan2(tooth[1] - pin[1],
                                               tooth[0] - pin[0]))
                off = (aim - want + 180.0) % 360.0 - 180.0
                if abs(off) > 0.5:
                    problems.append("conn_set_dial: %s points %.1f deg off "
                                    "its tooth" % (pose, off))
            print("  conn_set_dial: every detent points at its own tooth"
                  if not any("points" in p for p in problems) else "")

    if problems:
        for p in problems:
            print("FAIL: %s" % p)
        return 1
    print("PASS: %d hinged model(s); rest geometry, UVs and materials "
          "unchanged; every hinge where the manifest says" % len(hinged))
    return 0


if __name__ == "__main__":
    sys.exit(main())
