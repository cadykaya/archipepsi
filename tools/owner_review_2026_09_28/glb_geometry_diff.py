#!/usr/bin/env python3
"""Owner review, 2026-09-28 -- did a model's GEOMETRY move between two refs?

    python3 tools/owner_review_2026_09_28/glb_geometry_diff.py <old-ref> <new-ref> <glb path>...

Reads each .glb at both git revisions (read-only, `git show`) and compares:
  * geometry: every mesh primitive's POSITION data, byte for byte;
  * textures: every embedded image, byte for byte.

Prints GEOMETRY SAME/MOVED and TEXTURES SAME/CHANGED per file, so a review
can reuse an older render of the SHAPE honestly while saying its surface
has been re-baked since. Isolated review helper: it writes nothing.
"""
import hashlib
import json
import struct
import subprocess
import sys


def read_glb(ref: str, path: str) -> tuple[dict, bytes]:
    raw = subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True,
                         check=True).stdout
    magic, _ver, _len = struct.unpack_from("<III", raw, 0)
    assert magic == 0x46546C67, f"{path}@{ref} is not a GLB"
    off, doc, blob = 12, None, b""
    while off < len(raw):
        clen, ctype = struct.unpack_from("<II", raw, off)
        chunk = raw[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            doc = json.loads(chunk)
        elif ctype == 0x004E4942:
            blob = chunk
        off += 8 + clen
    return doc, blob


def view_bytes(doc: dict, blob: bytes, view_index: int) -> bytes:
    v = doc["bufferViews"][view_index]
    start = v.get("byteOffset", 0)
    return blob[start: start + v["byteLength"]]


def accessor_bytes(doc: dict, blob: bytes, acc_index: int) -> bytes:
    a = doc["accessors"][acc_index]
    if "bufferView" not in a:
        return b""
    return view_bytes(doc, blob, a["bufferView"])[a.get("byteOffset", 0):]


def digests(doc: dict, blob: bytes) -> tuple[str, str]:
    geo = hashlib.sha256()
    for mesh in doc.get("meshes", []):
        for prim in mesh.get("primitives", []):
            geo.update(accessor_bytes(doc, blob, prim["attributes"]["POSITION"]))
            if "indices" in prim:
                geo.update(accessor_bytes(doc, blob, prim["indices"]))
    tex = hashlib.sha256()
    for img in doc.get("images", []):
        if "bufferView" in img:
            tex.update(view_bytes(doc, blob, img["bufferView"]))
    return geo.hexdigest()[:12], tex.hexdigest()[:12]


def main() -> None:
    old, new, paths = sys.argv[1], sys.argv[2], sys.argv[3:]
    for p in paths:
        try:
            g0, t0 = digests(*read_glb(old, p))
            g1, t1 = digests(*read_glb(new, p))
        except subprocess.CalledProcessError:
            print(f"{p}: missing at one ref")
            continue
        print(f"{p}: GEOMETRY {'SAME' if g0 == g1 else 'MOVED'}"
              f"  TEXTURES {'SAME' if t0 == t1 else 'CHANGED'}")


if __name__ == "__main__":
    main()
