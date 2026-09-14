"""What a `.glb` actually offers a runtime after import: nodes, meshes,
primitives and the material each primitive wears.

Written for Batch 043. The question it answers is narrow and was asked by
the owner: when art declares a "state region" on a primitive, does that
region arrive in Godot as something a script can *address* -- a named node
it can fetch and swap -- or only as a material slot on one merged mesh?

Those are different contracts. A named node can be hidden, moved, lit,
replaced, or given its own shader. A material slot can only have its
material overridden, and only if the importer kept the surface separate.

    python3 tools/content/inspect_glb_nodes.py assets/models/batch028/interaction/int_wall_switch.glb
"""

from __future__ import annotations

import json
import struct
import sys


def read_glb(path):
    with open(path, "rb") as handle:
        magic, _version, _length = struct.unpack("<4sII", handle.read(12))
        if magic != b"glTF":
            raise SystemExit("%s is not a binary glTF" % path)
        gltf = None
        while True:
            header = handle.read(8)
            if len(header) < 8:
                break
            size, kind = struct.unpack("<I4s", header)
            payload = handle.read(size)
            if kind == b"JSON":
                gltf = json.loads(payload.decode("utf-8"))
        if gltf is None:
            raise SystemExit("%s has no JSON chunk" % path)
        return gltf


def report(path):
    g = read_glb(path)
    meshes = g.get("meshes", [])
    materials = g.get("materials", [])
    nodes = g.get("nodes", [])
    print("== %s" % path)
    print("   nodes %d  meshes %d  materials %d"
          % (len(nodes), len(meshes), len(materials)))
    for index, node in enumerate(nodes):
        mesh = node.get("mesh")
        label = node.get("name", "<unnamed node %d>" % index)
        if mesh is None:
            print("   node %-28s (no mesh -- a transform or a marker)" % label)
            continue
        prims = meshes[mesh].get("primitives", [])
        names = []
        for prim in prims:
            m = prim.get("material")
            names.append(materials[m].get("name", "<unnamed>")
                         if m is not None else "<no material>")
        print("   node %-28s mesh %-24s %d surface(s): %s"
              % (label, meshes[mesh].get("name", "?"), len(prims),
                 ", ".join(names)))
    # The addressability verdict, stated rather than left to the reader.
    addressable = sum(1 for n in nodes if n.get("mesh") is not None)
    print("   -> %d mesh node(s) a script can fetch by name; "
          "%d material slot(s) in total"
          % (addressable, sum(len(meshes[n["mesh"]].get("primitives", []))
                              for n in nodes if n.get("mesh") is not None)))


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        report(arg)
