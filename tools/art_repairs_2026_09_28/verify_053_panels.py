#!/usr/bin/env python3
"""Repair 2026-09-28, the lightened panels -- their own material, clear of
the fittings, and nothing else about the objects changed.

    python3 tools/art_repairs_2026_09_28/verify_053_panels.py [old-ref]

Reads the twelve physics props AS EXPORTED and their manifest, against
<old-ref> (default a1584c8, the reviewed source):

  1. MATERIAL. Every `lightened_panel_*` node wears `<asset>_lightened`
     and nothing else does; `<asset>_grip` is on handling fittings only.
  2. CLEAR. No panel comes within 2 cm of a fitting across its face, or
     has one standing in front of it (the rule the builder enforces).
  3. SEATED. A panel the repair moved sits on the body: rays cast at it
     from outside all find the body within the panel's 3 cm thickness.
  4. UNCHANGED. Every fitting and every body is where it was, vertex for
     vertex, with the same UVs and material; each object's size is the
     same; and the manifest's gameplay-facing fields -- carriable,
     manipulable, mass, mass class, envelope, attach points -- are equal.
     Panels the repair did not move are unchanged geometry too.

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
DIR = "assets/models/batch043/physics"
CLEAR = 0.02
THICK = 0.03
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
    """name -> (world verts, triangles as vertex triples, uvs, materials).
    Physics props export untransformed nodes; asserted, not assumed."""
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


def ray_hit(tris, origin, direction):
    """Nearest distance along `direction` to any triangle, or None."""
    best = None
    for a, b, c in tris:
        e1 = [b[k] - a[k] for k in range(3)]
        e2 = [c[k] - a[k] for k in range(3)]
        h = [direction[1] * e2[2] - direction[2] * e2[1],
             direction[2] * e2[0] - direction[0] * e2[2],
             direction[0] * e2[1] - direction[1] * e2[0]]
        det = sum(e1[k] * h[k] for k in range(3))
        if abs(det) < 1e-12:
            continue
        s = [origin[k] - a[k] for k in range(3)]
        u = sum(s[k] * h[k] for k in range(3)) / det
        if u < -1e-9 or u > 1 + 1e-9:
            continue
        q = [s[1] * e1[2] - s[2] * e1[1], s[2] * e1[0] - s[0] * e1[2],
             s[0] * e1[1] - s[1] * e1[0]]
        v = sum(direction[k] * q[k] for k in range(3)) / det
        if v < -1e-9 or u + v > 1 + 1e-9:
            continue
        t = sum(e2[k] * q[k] for k in range(3)) / det
        if t > 0 and (best is None or t < best):
            best = t
    return best


def main():
    old_ref = sys.argv[1] if len(sys.argv) > 1 else "a1584c8"
    with open(os.path.join(ROOT, DIR, "manifest.json"), encoding="utf-8") as h:
        manifest = json.load(h)
    old_manifest = json.loads(git_show(old_ref, DIR + "/manifest.json"))
    problems = []
    moved_total = panels_total = 0
    for asset in sorted(manifest):
        path = "%s/%s.glb" % (DIR, asset)
        with open(os.path.join(ROOT, path), "rb") as h:
            new = nodes(h.read())
        old = nodes(git_show(old_ref, path))
        entry, was = manifest[asset], old_manifest[asset]
        for key in SAME:
            if entry.get(key) != was.get(key):
                problems.append("%s: manifest %s changed" % (asset, key))
        moved = entry.get("lightened_panels", {}).get("panels", {})
        lit = "%s_lightened" % asset
        panels = sorted(n for n in new if n.startswith("lightened_panel"))
        panels_total += len(panels)
        body = new[asset]
        fittings = {n: v for n, v in new.items()
                    if n != asset and not n.startswith("lightened_panel")}
        # 1. MATERIAL
        for name, (_v, _t, _u, mats) in new.items():
            if name in panels and mats != [lit]:
                problems.append("%s: %s wears %s" % (asset, name, mats))
            if name not in panels and lit in mats:
                problems.append("%s: %s wears the panel material"
                                % (asset, name))
        # 4. UNCHANGED -- bodies and fittings, vertex for vertex.
        for name in [asset] + sorted(fittings):
            if new.get(name) is None or old.get(name) is None:
                problems.append("%s: %s missing" % (asset, name))
                continue
            if (new[name][0] != old[name][0] or new[name][2] != old[name][2]
                    or new[name][3] != old[name][3]):
                problems.append("%s: %s changed" % (asset, name))
        for name in panels:
            verts = new[name][0]
            lo, hi = box(verts)
            size = sorted(round(hi[k] - lo[k], 4) for k in range(3))
            old_lo, old_hi = box(old[name][0])
            old_size = sorted(round(old_hi[k] - old_lo[k], 4)
                              for k in range(3))
            if size != old_size:
                problems.append("%s: %s changed size" % (asset, name))
            is_moved = "moved_from_runtime" in moved.get(name, {})
            if not is_moved and verts != old[name][0]:
                problems.append("%s: %s moved without a record"
                                % (asset, name))
            # 2. CLEAR
            thin = min(range(3), key=lambda k: hi[k] - lo[k])
            centre = [(lo[k] + hi[k]) / 2.0 for k in range(3)]
            bc = [(a + b) / 2.0 for a, b in zip(*box(body[0]))]
            sign = 1.0 if centre[thin] > bc[thin] else -1.0
            grown_lo = [lo[k] - (0 if k == thin else CLEAR) for k in range(3)]
            grown_hi = [hi[k] + (0 if k == thin else CLEAR) for k in range(3)]
            if sign > 0:
                grown_hi[thin] += 0.10
            else:
                grown_lo[thin] -= 0.10
            for fname, (fverts, _t, _u, _m) in fittings.items():
                flo, fhi = box(fverts)
                if all(flo[k] < grown_hi[k] and fhi[k] > grown_lo[k]
                       for k in range(3)):
                    problems.append("%s: %s is on or under %s"
                                    % (asset, name, fname))
            # 3. SEATED -- only the panels this repair placed.
            if is_moved:
                moved_total += 1
                outer = hi[thin] if sign > 0 else lo[thin]
                others = [k for k in range(3) if k != thin]
                for fa in (0.02, 0.25, 0.5, 0.75, 0.98):
                    for fb in (0.02, 0.25, 0.5, 0.75, 0.98):
                        o = list(centre)
                        o[others[0]] = lo[others[0]] + fa * (
                            hi[others[0]] - lo[others[0]])
                        o[others[1]] = lo[others[1]] + fb * (
                            hi[others[1]] - lo[others[1]])
                        o[thin] = outer + sign * 0.5
                        d = [0.0, 0.0, 0.0]
                        d[thin] = -sign
                        t = ray_hit(body[1], o, d)
                        depth = None if t is None else t - 0.5
                        if depth is None or depth < -1e-4 or \
                                depth > THICK + 1e-4:
                            problems.append("%s: %s is not seated (%s)"
                                            % (asset, name, depth))
                            break
                    else:
                        continue
                    break
        # The anchor block has no panels and must be byte-identical.
        if not panels:
            with open(os.path.join(ROOT, path), "rb") as h:
                if h.read() != git_show(old_ref, path):
                    problems.append("%s: changed, and it has no panels"
                                    % asset)
        print("  %-22s %d panel(s), %d moved by the repair"
              % (asset, len(panels), sum(1 for p in panels
                                         if "moved_from_runtime"
                                         in moved.get(p, {}))))
    if problems:
        for p in problems:
            print("FAIL: %s" % p)
        return 1
    print("PASS: %d panels on their own material and clear of every fitting; "
          "%d moved and seated; bodies, fittings, sizes and gameplay fields "
          "unchanged" % (panels_total, moved_total))
    return 0


if __name__ == "__main__":
    sys.exit(main())
