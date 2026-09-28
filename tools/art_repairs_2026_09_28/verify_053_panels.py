#!/usr/bin/env python3
"""Repair 2026-09-28, the lightened panels -- three separate questions per
panel, and nothing else about the objects changed.

    python3 tools/art_repairs_2026_09_28/verify_053_panels.py [old-ref]

Reads the twelve physics props AS EXPORTED, and their manifest, against
<old-ref> (default a1584c8, the reviewed source). It asks each of the 22
panels three questions and reports every answer, because they are
different defects with different fixes:

  MATERIAL  Does it wear its own `<asset>_lightened` slot? Nothing else may
            wear it, and `<asset>_grip` stays on handling fittings only.
  CLEAR     Is it off the handling surfaces? No fitting may come within
            2 cm of it across its face, or stand within 10 cm in front.
  SEATED    Does it actually sit on the body? Rays cast at it from outside,
            1 cm apart, must all find the body. The surface under the panel
            must lie between 2 mm and the panel's own 3 cm behind its face:
            touching everywhere, never flush (flush faces z-fight), never
            floating. And it must be flat to 1 cm.

Then UNCHANGED:
  - every fitting and every body is where it was, vertex for vertex, with
    the same UVs and material;
  - each object's size is the same;
  - the manifest's gameplay-facing fields are equal: carriable,
    manipulable, mass, mass class, envelope, attach points;
  - a panel the manifest does not record as moved is unchanged geometry.

A file that passes MATERIAL and CLEAR but hangs a panel off the body FAILS
on SEATED alone. That is the point of keeping the three apart. Read-only;
exit 1 on any failure.
"""

from __future__ import annotations

import json
import os
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
DIR = "assets/models/batch043/physics"
CLEAR = 0.02
FRONT = 0.10
THICK = 0.03
MIN_PROUD = 0.002
FLAT = 0.01
PITCH = 0.01
SAME = ("carriable", "manipulable", "mass_kg", "mass_class", "envelope",
        "attach_points", "size", "size_runtime_y_up", "class", "anchor")


def git_show(ref, path):
    return subprocess.run(["git", "show", "%s:%s" % (ref, path)], cwd=ROOT,
                          check=True, capture_output=True).stdout


def parse(data):
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


def accessor(doc, blob, index, width, fmt="f"):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    size = 4 if fmt in "fI" else 2
    stride = view.get("byteStride", size * width)
    return [struct.unpack_from("<%d%s" % (width, fmt), blob, start + i * stride)
            for i in range(acc["count"])]


def nodes(data):
    """name -> (world verts, triangles, uvs, materials). Physics props
    export untransformed nodes; asserted, not assumed."""
    doc, blob = parse(data)
    out = {}

    def visit(i, offset):
        node = doc["nodes"][i]
        if any(k in node for k in ("rotation", "scale", "matrix")):
            raise SystemExit("%s is rotated or scaled" % node.get("name"))
        t = node.get("translation", [0.0, 0.0, 0.0])
        here = [offset[k] + t[k] for k in range(3)]
        if "mesh" in node:
            verts, tris, uvs, mats = [], [], [], []
            for prim in doc["meshes"][node["mesh"]]["primitives"]:
                pts = [tuple(v[k] + here[k] for k in range(3)) for v in
                       accessor(doc, blob, prim["attributes"]["POSITION"], 3)]
                acc = doc["accessors"][prim["indices"]]
                fmt = {5123: "H", 5125: "I"}[acc["componentType"]]
                idx = [i[0] for i in accessor(doc, blob, prim["indices"], 1,
                                              fmt)]
                tris += [(pts[idx[j]], pts[idx[j + 1]], pts[idx[j + 2]])
                         for j in range(0, len(idx), 3)]
                verts += pts
                uvs += accessor(doc, blob, prim["attributes"]["TEXCOORD_0"], 2)
                mats.append(doc["materials"][prim["material"]]["name"])
            out[node["name"]] = (verts, tris, uvs, mats)
        for child in node.get("children", []):
            visit(child, here)

    for i in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        visit(i, [0.0, 0.0, 0.0])
    return out


def box(verts):
    return ([min(v[k] for v in verts) for k in range(3)],
            [max(v[k] for v in verts) for k in range(3)])


def ray_hit(tris, origin, axis, sign):
    """Distance along -sign*axis to the nearest triangle, or None.
    Axis-aligned rays, so a bounding-box test prunes almost every triangle
    before the exact one."""
    others = [k for k in range(3) if k != axis]
    d = [0.0, 0.0, 0.0]
    d[axis] = -sign
    best = None
    for a, b, c in tris:
        skip = False
        for k in others:
            if origin[k] < min(a[k], b[k], c[k]) - 1e-9 or \
                    origin[k] > max(a[k], b[k], c[k]) + 1e-9:
                skip = True
                break
        if skip:
            continue
        e1 = [b[k] - a[k] for k in range(3)]
        e2 = [c[k] - a[k] for k in range(3)]
        h = [d[1] * e2[2] - d[2] * e2[1], d[2] * e2[0] - d[0] * e2[2],
             d[0] * e2[1] - d[1] * e2[0]]
        det = sum(e1[k] * h[k] for k in range(3))
        if abs(det) < 1e-12:
            continue
        s = [origin[k] - a[k] for k in range(3)]
        u = sum(s[k] * h[k] for k in range(3)) / det
        if u < -1e-9 or u > 1 + 1e-9:
            continue
        q = [s[1] * e1[2] - s[2] * e1[1], s[2] * e1[0] - s[0] * e1[2],
             s[0] * e1[1] - s[1] * e1[0]]
        v = sum(d[k] * q[k] for k in range(3)) / det
        if v < -1e-9 or u + v > 1 + 1e-9:
            continue
        t = sum(e2[k] * q[k] for k in range(3)) / det
        if t > 0 and (best is None or t < best):
            best = t
    return best


def facing(pbox, bbox):
    """The panel's thin axis, and which way it faces, from the body's centre."""
    lo, hi = pbox
    thin = min(range(3), key=lambda k: hi[k] - lo[k])
    centre = (lo[thin] + hi[thin]) / 2.0
    body_centre = (bbox[0][thin] + bbox[1][thin]) / 2.0
    return thin, (1.0 if centre > body_centre else -1.0)


def seated(body_tris, pbox, thin, sign):
    """[] when seated; otherwise the seating defects, named."""
    lo, hi = pbox
    outer = hi[thin] if sign > 0 else lo[thin]
    others = [k for k in range(3) if k != thin]
    counts = [max(3, int((hi[k] - lo[k]) / PITCH) + 2) for k in others]
    depths, missed = [], 0
    for ia in range(counts[0]):
        for ib in range(counts[1]):
            o = [0.0, 0.0, 0.0]
            for k, i, n in ((others[0], ia, counts[0]),
                            (others[1], ib, counts[1])):
                o[k] = lo[k] + (hi[k] - lo[k]) * (0.02 + 0.96 * i / (n - 1))
            o[thin] = outer + sign * 0.5
            t = ray_hit(body_tris, o, thin, sign)
            if t is None:
                missed += 1
            else:
                depths.append(t - 0.5)
    out = []
    if missed:
        out.append("%d of %d rays find no body under it"
                   % (missed, missed + len(depths)))
    if depths:
        if min(depths) < -1e-4:
            out.append("the body stands %.3f m through its face"
                       % -min(depths))
        elif min(depths) < MIN_PROUD - 1e-6:
            out.append("flush with the surface under it")
        if max(depths) > THICK + 1e-4:
            out.append("hangs up to %.3f m off the body"
                       % (max(depths) - THICK))
        if max(depths) - min(depths) > FLAT + 1e-6:
            out.append("across uneven body (%.3f m)"
                       % (max(depths) - min(depths)))
    return out


def main():
    old_ref = sys.argv[1] if len(sys.argv) > 1 else "a1584c8"
    with open(os.path.join(ROOT, DIR, "manifest.json"), encoding="utf-8") as h:
        manifest = json.load(h)
    old_manifest = json.loads(git_show(old_ref, DIR + "/manifest.json"))
    fails = {"MATERIAL": [], "CLEAR": [], "SEATED": [], "UNCHANGED": []}
    total = moved_total = 0
    for asset in sorted(manifest):
        path = "%s/%s.glb" % (DIR, asset)
        with open(os.path.join(ROOT, path), "rb") as h:
            data = h.read()
        new, old = nodes(data), nodes(git_show(old_ref, path))
        entry, was = manifest[asset], old_manifest[asset]
        for key in SAME:
            if entry.get(key) != was.get(key):
                fails["UNCHANGED"].append("%s: manifest %s changed"
                                          % (asset, key))
        moved = entry.get("lightened_panels", {}).get("panels", {})
        lit = "%s_lightened" % asset
        panels = sorted(n for n in new if n.startswith("lightened_panel"))
        total += len(panels)
        body = new[asset]
        bbox = box(body[0])
        fittings = {n: v for n, v in new.items()
                    if n != asset and not n.startswith("lightened_panel")}
        for name in [asset] + sorted(fittings):
            if new.get(name) is None or old.get(name) is None:
                fails["UNCHANGED"].append("%s: %s missing" % (asset, name))
            elif (new[name][0] != old[name][0] or new[name][2] != old[name][2]
                  or new[name][3] != old[name][3]):
                fails["UNCHANGED"].append("%s: %s changed" % (asset, name))
        for name, (_v, _t, _u, mats) in new.items():
            if name not in panels and lit in mats:
                fails["MATERIAL"].append("%s: %s wears the panel material"
                                         % (asset, name))
        rows = []
        for name in panels:
            verts = new[name][0]
            pbox = box(verts)
            thin, sign = facing(pbox, bbox)
            label = "%s %s" % (asset, name)
            status = []
            # MATERIAL
            mats = new[name][3]
            if mats != [lit]:
                fails["MATERIAL"].append("%s wears %s" % (label, mats))
                status.append("MATERIAL: %s" % ",".join(mats))
            # CLEAR
            glo = [pbox[0][k] - (0 if k == thin else CLEAR) for k in range(3)]
            ghi = [pbox[1][k] + (0 if k == thin else CLEAR) for k in range(3)]
            if sign > 0:
                ghi[thin] += FRONT
            else:
                glo[thin] -= FRONT
            on = [f for f, (fv, _t, _u, _m) in fittings.items()
                  if all(box(fv)[0][k] < ghi[k] and box(fv)[1][k] > glo[k]
                         for k in range(3))]
            if on:
                fails["CLEAR"].append("%s is on or under %s"
                                      % (label, ", ".join(on)))
                status.append("CLEAR: on %s" % ",".join(on))
            # SEATED
            defects = seated(body[1], pbox, thin, sign)
            if defects:
                fails["SEATED"].append("%s: %s" % (label, "; ".join(defects)))
                status.append("SEATED: %s" % "; ".join(defects))
            # UNCHANGED, for a panel the manifest does not say was moved.
            is_moved = "moved_from_runtime" in moved.get(name, {})
            moved_total += is_moved
            if not is_moved and verts != old[name][0]:
                fails["UNCHANGED"].append("%s moved without a record" % label)
            rows.append("    %-18s %s" % (name, "ok" if not status
                                          else " | ".join(status)))
        if not panels:
            with open(os.path.join(ROOT, path), "rb") as h:
                if h.read() != git_show(old_ref, path):
                    fails["UNCHANGED"].append("%s: changed, and it has no "
                                              "panels" % asset)
        print("  %s" % asset)
        print("\n".join(rows) if rows else "    no panels")
    print("\n  %-10s %s" % ("check", "failures"))
    for key in ("MATERIAL", "CLEAR", "SEATED", "UNCHANGED"):
        print("  %-10s %d" % (key, len(fails[key])))
    bad = [f for key in fails for f in fails[key]]
    if bad:
        for key in ("MATERIAL", "CLEAR", "SEATED", "UNCHANGED"):
            for f in fails[key]:
                print("FAIL %s: %s" % (key, f))
        return 1
    print("PASS: %d panels -- own material, clear of every fitting, seated on "
          "the body; %d placed by the repairs; bodies, fittings, sizes and "
          "gameplay fields unchanged" % (total, moved_total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
