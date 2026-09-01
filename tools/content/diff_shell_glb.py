"""Prove a rebuilt shell gained collision and nothing else.

    python3 tools/content/diff_shell_glb.py <old-git-ref>

The eight room shells were rebuilt to carry authored collision, so their
.glb files are EXPECTED to differ -- which is exactly the situation in
which "trust me, only the collision changed" is worth nothing. This reads
both revisions of each file and says which of the two possible changes
actually happened:

    the visible mesh, its materials, its textures      MUST NOT change
    collision-only nodes, and the bytes they add       may appear

A shell whose bytes did not move at all is reported as such and not
examined further, which is how the second half of the claim -- that the
rebuild reached the eight packed shells and nothing else -- is evidence
rather than assertion.

The check is on the glTF itself rather than on the Blender script,
because the script is not what Godot imports. Accessor payloads are
compared as raw bytes: same vertex data, same normals, same UVs, same
indices, same PNG, or it is not the same room.
"""
from __future__ import annotations

import hashlib
import json
import os
import struct
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(_HERE))
SUFFIX = "-convcolonly"


def _read_glb(blob):
    magic, _version, _length = struct.unpack_from("<III", blob, 0)
    if magic != 0x46546C67:
        raise ValueError("not a GLB")
    offset, doc, binary = 12, None, b""
    while offset < len(blob):
        size, kind = struct.unpack_from("<II", blob, offset)
        chunk = blob[offset + 8:offset + 8 + size]
        if kind == 0x4E4F534A:
            doc = json.loads(chunk.decode("utf-8"))
        elif kind == 0x004E4942:
            binary = chunk
        offset += 8 + size + (-size % 4)
    return doc, binary


def _accessor_bytes(doc, binary, index):
    """The raw payload of one accessor, stride-aware."""
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    comp = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    count_of = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
                "MAT4": 16}
    width = comp[acc["componentType"]] * count_of[acc["type"]]
    stride = view.get("byteStride", width)
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = bytearray()
    for i in range(acc["count"]):
        start = base + i * stride
        out += binary[start:start + width]
    return bytes(out)


def _mesh_fingerprint(doc, binary, mesh_index):
    """Everything about one mesh that a player can see."""
    mesh = doc["meshes"][mesh_index]
    parts = []
    for prim in mesh["primitives"]:
        for name in sorted(prim.get("attributes", {})):
            digest = hashlib.sha256(
                _accessor_bytes(doc, binary,
                                prim["attributes"][name])).hexdigest()
            parts.append("%s=%s" % (name, digest))
        if "indices" in prim:
            parts.append("IDX=%s" % hashlib.sha256(
                _accessor_bytes(doc, binary, prim["indices"])).hexdigest())
        parts.append("MODE=%s" % prim.get("mode", 4))
        if "material" in prim:
            mat = doc["materials"][prim["material"]]
            parts.append("MAT=%s" % json.dumps(mat, sort_keys=True))
        else:
            parts.append("MAT=none")
    return "|".join(parts)


def _images(doc, binary):
    out = {}
    for i, img in enumerate(doc.get("images", [])):
        if "bufferView" in img:
            view = doc["bufferViews"][img["bufferView"]]
            start = view.get("byteOffset", 0)
            data = binary[start:start + view["byteLength"]]
        else:
            data = b""
        out[img.get("name", "image_%d" % i)] = (
            hashlib.sha256(data).hexdigest(), len(data))
    return out


def _nodes(doc):
    """name -> mesh index, for every node that carries a mesh."""
    return {n.get("name", "node_%d" % i): n["mesh"]
            for i, n in enumerate(doc.get("nodes", [])) if "mesh" in n}


def describe(blob):
    doc, binary = _read_glb(blob)
    nodes = _nodes(doc)
    visible = {n: m for n, m in nodes.items() if not n.endswith(SUFFIX)}
    colliders = sorted(n for n in nodes if n.endswith(SUFFIX))
    return {
        "visible": {n: _mesh_fingerprint(doc, binary, m)
                    for n, m in visible.items()},
        "colliders": colliders,
        "images": _images(doc, binary),
        "bytes": len(blob),
    }


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    ref = argv[1]
    listing = subprocess.run(
        ["git", "ls-files", "assets/models/*/shells/*.glb"],
        cwd=REPO, capture_output=True, text=True, check=True)
    paths = sorted(p for p in listing.stdout.split() if p)
    if not paths:
        print("no shell .glb files tracked")
        return 2
    bad = 0
    for path in paths:
        old_blob = subprocess.run(["git", "show", "%s:%s" % (ref, path)],
                                  cwd=REPO, capture_output=True, check=True)
        with open(os.path.join(REPO, path), "rb") as fh:
            new_blob = fh.read()
        name = os.path.basename(path)
        if old_blob.stdout == new_blob:
            # The eleven F3 exploration shells are not in the content
            # pack and were not rebuilt. Saying so here is the other half
            # of the proof: the change reached the eight and no further.
            print("[diff] SAME %-34s byte-identical, not rebuilt" % name)
            continue
        old, new = describe(old_blob.stdout), describe(new_blob)
        problems = []
        if set(old["visible"]) != set(new["visible"]):
            problems.append("visible nodes changed: %s -> %s"
                            % (sorted(old["visible"]), sorted(new["visible"])))
        for node, fingerprint in old["visible"].items():
            if new["visible"].get(node) != fingerprint:
                problems.append("visible mesh '%s' CHANGED" % node)
        if old["images"] != new["images"]:
            problems.append("textures changed: %s -> %s"
                            % (old["images"], new["images"]))
        if old["colliders"]:
            problems.append("the old revision already had colliders: %s"
                            % old["colliders"])
        if not new["colliders"]:
            problems.append("no collision-only nodes were added")
        grew = new["bytes"] - old["bytes"]
        if problems:
            bad += 1
            print("[diff] FAIL %-34s" % name)
            for problem in problems:
                print("[diff]      %s" % problem)
        else:
            print("[diff] OK   %-34s visible mesh identical (%d node, "
                  "%d texture), +%d colliders, +%d bytes"
                  % (name, len(new["visible"]), len(new["images"]),
                     len(new["colliders"]), grew))
    print("[diff] %d file(s), %d problem(s)" % (len(paths), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
