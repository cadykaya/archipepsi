"""What the UVs actually do on a shipped shell, per surface.

    python3 tools/content/inspect_uvs.py [shell_id]

WHY THIS EXISTS. A wall texture authored with vertical ribs came back
horizontal on one wall of a preview and vertical on another. Declaring
"32 texels/m" in an asset record says what the AUTHOR intended; it does not
establish what the mesh's UVs do with it. This measures the mapping instead
of assuming it.

METHOD. For each triangle take two edges in POSITION and the same two edges
in TEXCOORD_0, and solve the 2x2 system for the Jacobian dP/dU and dP/dV --
the world-space direction and length that one unit of U, and one of V, run
in.

GROUPED BY FACE NORMAL, and that grouping is the whole point. Every piece of
these shells is a BOX, and a box's six faces each get their own unwrap. A
first version of this file took the modal axis over all of a primitive's
triangles and reported the same answer for the floor, the ceiling, a wall
and a trim rail -- which is impossible for surfaces lying in different
planes, and was the giveaway that it was averaging six faces together. What
a viewer sees is ONE face, so one face is the unit of measurement.

From each group:

  * `u_world` / `v_world`  which way the texture's axes point in the room
  * `metres_per_uv`        so texels/m is size_px / metres_per_uv, MEASURED
  * `v_up`                 whether the texture's V axis runs along world up,
                           which is what decides if a vertical rib reads as
                           vertical

Reads the .glb only. Changes nothing.
"""
import collections
import json
import math
import os
import struct
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools", "content"))
import inspect_materials as I  # noqa: E402

COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2),
             5125: ("I", 4), 5126: ("f", 4)}
COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def blob(path):
    with open(path, "rb") as fh:
        data = fh.read()
    off, js, bin_ = 12, None, b""
    while off < len(data):
        length, kind = struct.unpack_from("<II", data, off)
        body = data[off + 8:off + 8 + length]
        if kind == 0x4E4F534A:
            js = json.loads(body)
        elif kind == 0x004E4942:
            bin_ = body
        off += 8 + length + ((4 - length % 4) % 4)
    return js, bin_


def read(js, bin_, index):
    acc = js["accessors"][index]
    view = js["bufferViews"][acc["bufferView"]]
    fmt, size = COMPONENT[acc["componentType"]]
    n = COUNT[acc["type"]]
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or size * n
    out = []
    for i in range(acc["count"]):
        at = base + i * stride
        out.append(struct.unpack_from("<" + fmt * n, bin_, at))
    return out


def jacobian(p0, p1, p2, t0, t1, t2):
    """dP/dU and dP/dV for one triangle, or None if the UVs are degenerate."""
    du1, dv1 = t1[0] - t0[0], t1[1] - t0[1]
    du2, dv2 = t2[0] - t0[0], t2[1] - t0[1]
    det = du1 * dv2 - du2 * dv1
    if abs(det) < 1e-12:
        return None
    e1 = [p1[i] - p0[i] for i in range(3)]
    e2 = [p2[i] - p0[i] for i in range(3)]
    dpdu = [(dv2 * e1[i] - dv1 * e2[i]) / det for i in range(3)]
    dpdv = [(-du2 * e1[i] + du1 * e2[i]) / det for i in range(3)]
    return dpdu, dpdv


def norm(v):
    n = math.sqrt(sum(c * c for c in v))
    return [c / n for c in v] if n > 1e-9 else v, n


def axis_name(v):
    """The dominant world axis of a direction, in Godot's frame.

    The .glb is Blender-handed: Godot imports (x, y, z) as (x, z, -y), so
    what is +Z in the file is UP in the room.
    """
    gx, gy, gz = v[0], v[2], -v[1]
    names = [("+X", gx), ("+Y(up)", gy), ("+Z", gz)]
    k, val = max(names, key=lambda kv: abs(kv[1]))
    return ("-" + k[1:]) if val < 0 else k


def main():
    want = sys.argv[1] if len(sys.argv) > 1 else "shell_corner_left"
    hit = [p for p in I.LEGACY_SHELLS if p == want]
    if not hit:
        raise SystemExit("unknown shell %s" % want)
    import glob
    src = glob.glob(os.path.join(REPO, "assets/models/*/*/%s.glb" % want))[0]
    js, bin_ = blob(src)
    print("[uv] %s" % os.path.relpath(src, REPO))
    rows = []
    for mesh in js.get("meshes", []):
        for prim in mesh.get("primitives", []):
            attrs = prim.get("attributes", {})
            if "POSITION" not in attrs or "TEXCOORD_0" not in attrs:
                continue
            name = js["materials"][prim["material"]].get("name", "?")
            pos = read(js, bin_, attrs["POSITION"])
            uv = read(js, bin_, attrs["TEXCOORD_0"])
            idx = [i[0] for i in read(js, bin_, prim["indices"])]
            faces = collections.defaultdict(list)
            for t in range(0, len(idx) - 2, 3):
                a, b, c = idx[t], idx[t + 1], idx[t + 2]
                j = jacobian(pos[a], pos[b], pos[c], uv[a], uv[b], uv[c])
                if j is None:
                    continue
                e1 = [pos[b][i] - pos[a][i] for i in range(3)]
                e2 = [pos[c][i] - pos[a][i] for i in range(3)]
                n = [e1[1] * e2[2] - e1[2] * e2[1],
                     e1[2] * e2[0] - e1[0] * e2[2],
                     e1[0] * e2[1] - e1[1] * e2[0]]
                nn, _ = norm(n)
                faces[axis_name(nn)].append(j)
            for facing, js_ in sorted(faces.items()):
                us = [axis_name(norm(j[0])[0]) for j in js_]
                vs = [axis_name(norm(j[1])[0]) for j in js_]
                mpu = [norm(j[0])[1] for j in js_]
                mpv = [norm(j[1])[1] for j in js_]
                v_axis = collections.Counter(vs).most_common(1)[0][0]
                rows.append({
                    "material": name,
                    "role": I.resolve(name, want)[0],
                    "face_normal": facing,
                    "u_axis": collections.Counter(us).most_common(1)[0][0],
                    "v_axis": v_axis,
                    # Does the texture's V run along world up on this face?
                    # For a wall that is what decides whether an authored
                    # vertical rib reads as vertical.
                    "v_is_world_up": v_axis in ("+Y(up)", "-Y(up)"),
                    "metres_per_u": round(sum(mpu) / len(mpu), 4),
                    "metres_per_v": round(sum(mpv) / len(mpv), 4),
                    "tris": len(js_),
                })
    by_role = collections.defaultdict(list)
    for r in rows:
        by_role[r["role"]].append(r)
    print("%-14s %-8s %-8s %-8s %-8s %-7s %8s %8s" % (
        "material", "role", "faces", "U runs", "V runs", "V=up?",
        "tex/m U", "tex/m V"))
    for role in sorted(by_role):
        seen = set()
        for r in sorted(by_role[role], key=lambda x: (x["material"],
                                                      x["face_normal"])):
            size = 128.0
            key = (r["role"], r["face_normal"], r["u_axis"], r["v_axis"])
            if key in seen:      # one line per distinct behaviour per role
                continue
            seen.add(key)
            print("%-14s %-8s %-8s %-8s %-8s %-7s %8.1f %8.1f" % (
                r["material"], r["role"], r["face_normal"],
                r["u_axis"], r["v_axis"],
                "yes" if r["v_is_world_up"] else "NO",
                size / r["metres_per_u"] if r["metres_per_u"] else 0,
                size / r["metres_per_v"] if r["metres_per_v"] else 0))
    upright = [r for r in rows if r["role"] == "wall" and r["v_is_world_up"]]
    rotated = [r for r in rows if r["role"] == "wall" and not r["v_is_world_up"]]
    print("[uv] wall faces: %d with V along world up, %d rotated"
          % (len(upright), len(rotated)))
    dens = collections.Counter(
        (round(128 / r["metres_per_u"], 1), round(128 / r["metres_per_v"], 1))
        for r in rows)
    print("[uv] measured texel density, all faces: %s"
          % ", ".join("%sx%s on %d face(s)" % (a, b, n)
                      for (a, b), n in dens.most_common()))
    out = os.path.join(REPO, "docs/art/review/derelict_2026-09-10/uv_survey.json")
    with open(out, "w") as fh:
        json.dump({"_comment": [
            "MEASURED from the shipped .glb, not declared. Axis names are in",
            "Godot's frame: the .glb is Blender-handed and imports as",
            "(x, z, -y), so +Z in the file is UP in the room.",
            "texels/m is 128 / metres_per_uv -- what the MESH does with the",
            "texture, which an asset record cannot establish.",
        ], "shell": want, "source": os.path.relpath(src, REPO),
            "surfaces": rows}, fh, indent=2)
    print("[uv] -> %s" % os.path.relpath(out, REPO))


main()
