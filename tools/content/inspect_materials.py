"""What material slots each shipped asset actually carries.

    python3 tools/content/inspect_materials.py [substring ...]

INSPECTION ONLY. Reads the glTF JSON of every shipped `.glb` and reports
its materials, which mesh primitives use them, and whether each carries
an embedded image. Changes nothing, decides nothing, and proposes no
binding contract -- it exists so a reskin conversation can start from
what the files contain rather than from what the builders intend.

WHY THE SLOT NAMES MATTER. A theme pack that reskins a room without
rebuilding it needs a stable, per-role handle on that room's surfaces.
In glTF that handle is the MATERIAL NAME, and Godot's importer keeps it.
So the question this answers is: does every shell expose the same set of
role-named slots, or does each one expose names of its own?
"""

from __future__ import annotations

import json
import os
import struct
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
ROOTS = ("assets/models", "godot/content")


def gltf(path):
    """The JSON chunk of a .glb, plus the byte length of its BIN chunk."""
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:4] != b"glTF":
        raise ValueError("%s is not a .glb" % path)
    off, js, binlen = 12, None, 0
    while off < len(data):
        length, kind = struct.unpack_from("<II", data, off)
        body = data[off + 8:off + 8 + length]
        if kind == 0x4E4F534A:
            js = json.loads(body)
        elif kind == 0x004E4942:
            binlen = len(body)
        off += 8 + length + ((4 - length % 4) % 4)
    return js, binlen


def slots(path):
    """[(material name, primitives using it, has an image)], plus orphans."""
    js, _ = gltf(path)
    mats = js.get("materials", [])
    used = {}
    for mesh in js.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if "material" in prim:
                used[prim["material"]] = used.get(prim["material"], 0) + 1
    out = []
    for i, mat in enumerate(mats):
        pbr = mat.get("pbrMetallicRoughness", {})
        out.append((mat.get("name", "<unnamed>"), used.get(i, 0),
                    "baseColorTexture" in pbr))
    return out, len(js.get("images", []))


def main(argv):
    want = argv[1:]
    rows, files = [], 0
    for root in ROOTS:
        base = os.path.join(REPO, root)
        for here, _, names in os.walk(base):
            for name in sorted(names):
                if not name.endswith(".glb"):
                    continue
                rel = os.path.relpath(os.path.join(here, name), REPO)
                if want and not any(w in rel for w in want):
                    continue
                files += 1
                found, images = slots(os.path.join(here, name))
                rows.append((rel, found, images))
    for rel, found, images in rows:
        print("[mat] %-56s %d material(s), %d image(s)"
              % (rel, len(found), images))
        for name, prims, textured in found:
            print("        %-38s %d primitive(s)%s"
                  % (name, prims, "  textured" if textured else ""))
    print("[mat] %d file(s)" % files)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
