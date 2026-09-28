#!/usr/bin/env python3
"""Repair 2026-09-28, the skiff -- is `fore` the end that goes first?

    python3 tools/art_repairs_2026_09_28/verify_skiff_fore.py [old-ref]

Three things, all read rather than assumed:

  1. THE RUNTIME FRAME, from Production's own file at the pinned revision
     (read-only, `git show`): `RailCarrier.pose()` must still set
     `basis.z = along`, where `along` is the path tangent, the FORWARD
     direction. That is what makes runtime +Z the fore end.
  2. THE EXPORTED FILES: in `sp_skiff_deck` and `sp_skiff_deck_bare`, every
     node named `*_fore` sits at +Z and every `*_aft` at -Z, measured on
     the world-space vertices a loader sees.
  3. NOTHING ELSE MOVED: against <old-ref> (default a1584c8), each
     `*_fore` node now carries exactly the geometry, UVs and material the
     old `*_aft` node did, and the reverse; every other node is unchanged.
     The repair is a rename of two ends, not a new shape.

Read-only. Exit 1 on any failure.
"""

from __future__ import annotations

import json
import os
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
PIN = "c12a72fbc62500f4815d683d66a97f47fe514b06"
CARRIER = "godot/scripts/gameplay/rail_carrier.gd"
DIR = "assets/models/batch045/setpieces"
DECKS = ("sp_skiff_deck", "sp_skiff_deck_bare")


def git_show(ref: str, path: str) -> bytes:
    return subprocess.run(["git", "show", "%s:%s" % (ref, path)], cwd=ROOT,
                          check=True, capture_output=True).stdout


def parse(data: bytes):
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


def accessor(doc, blob, index, width):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 4 * width)
    return [struct.unpack_from("<%df" % width, blob, start + i * stride)
            for i in range(acc["count"])]


def nodes(data: bytes) -> dict:
    """name -> (world vertices, uvs, materials). These decks have no
    rotated or scaled node, so a translation sum is the whole transform,
    and that is asserted rather than assumed."""
    doc, blob = parse(data)
    out = {}

    def visit(i, offset):
        node = doc["nodes"][i]
        if "rotation" in node or "scale" in node or "matrix" in node:
            raise SystemExit("%s is rotated or scaled; this check assumes "
                             "neither" % node.get("name"))
        t = node.get("translation", [0.0, 0.0, 0.0])
        here = [offset[k] + t[k] for k in range(3)]
        if "mesh" in node:
            verts, uvs, mats = [], [], []
            for prim in doc["meshes"][node["mesh"]]["primitives"]:
                verts += [tuple(v[k] + here[k] for k in range(3)) for v in
                          accessor(doc, blob, prim["attributes"]["POSITION"],
                                   3)]
                uvs += accessor(doc, blob, prim["attributes"]["TEXCOORD_0"], 2)
                mats.append(doc["materials"][prim["material"]]["name"])
            out[node["name"]] = (verts, uvs, mats)
        for child in node.get("children", []):
            visit(child, here)

    for i in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        visit(i, [0.0, 0.0, 0.0])
    return out


def swapped(name: str) -> str:
    if "_fore" in name:
        return name.replace("_fore", "_aft")
    if "_aft" in name:
        return name.replace("_aft", "_fore")
    return name


def main() -> int:
    old_ref = sys.argv[1] if len(sys.argv) > 1 else "a1584c8"
    problems: list[str] = []

    source = git_show(PIN, CARRIER).decode("utf-8")
    body = source.split("func pose() -> Transform3D:", 1)[-1].split("\nfunc ")[0]
    if ("path.tangent(offset)" not in body
            or "basis.z = along" not in body):
        problems.append("rail_carrier.gd at %s no longer sets basis.z to "
                        "the path tangent; fore must be re-derived" % PIN[:7])
    else:
        print("runtime: %s@%s RailCarrier.pose() sets basis.z = along "
              "(the path tangent, FORWARD) -> fore is +Z" % (CARRIER, PIN[:7]))

    for deck in DECKS:
        path = "%s/%s.glb" % (DIR, deck)
        with open(os.path.join(ROOT, path), "rb") as handle:
            new = nodes(handle.read())
        old = nodes(git_show(old_ref, path))
        ends = []
        for name, (verts, _uv, _m) in sorted(new.items()):
            z = sum(v[2] for v in verts) / len(verts)
            if "_fore" in name and z <= 0.0:
                problems.append("%s: %s is at z %.3f, behind" % (deck, name, z))
            if "_aft" in name and z >= 0.0:
                problems.append("%s: %s is at z %+.3f, ahead" % (deck, name, z))
            if name.startswith("lamp_"):
                ends.append("%s z %+.3f" % (name, z))
        if sorted(new) != sorted(old):
            problems.append("%s: node names changed" % deck)
        for name in new:
            if new[name] != old.get(swapped(name)):
                problems.append("%s: %s is not the old %s unchanged"
                                % (deck, name, swapped(name)))
        print("%s: %s; %d node(s), every *_fore is the old *_aft and "
              "every other node is untouched" % (deck, ", ".join(ends),
                                                 len(new)))

    if problems:
        for p in problems:
            print("FAIL: %s" % p)
        return 1
    print("PASS: fore is the end that goes first, and nothing else moved")
    return 0


if __name__ == "__main__":
    sys.exit(main())
