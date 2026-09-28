#!/usr/bin/env python3
"""Repair 2026-09-28, follow-up -- can the gauge be read?

    python3 tools/art_repairs_2026_09_28/verify_049_gauge.py [ref]

Reads `conn_gauge.glb` AS EXPORTED and looks at it the way a player
does: straight on from in front (runtime +Z), on a 2 mm grid of rays. The
needle turns about the manifest's own pin to every declared position,
and through the whole sweep between them in 1 degree steps. At each
angle it checks:

  1. FACE. Every ray within the needle's reach of the pin, plus 5 mm,
     lands first on the face or the needle. Nothing stands in front of
     the dial where the needle points.
  2. NEEDLE. Every ray that lands on the needle lands on it first, and
     the part directly behind it is the face. The needle is read against
     the dial, never against the bezel.
  3. KEPT. Compared with the first repair round (77d33ca, hinge
     included):
     - the case, face and needle are the same vertex for vertex, with
       the same UVs and materials;
     - the bezel has the same outer box and material;
     - the manifest's pin, axis, carried part, positions and size are
       the same.

With a ref it checks that revision's model instead, posed by the CURRENT
manifest's hinge. That is how it shows the old solid bezel failing: run
it at 77d33ca or a1584c8.

Read-only: it writes nothing. Exit 1 on any failure.
"""

from __future__ import annotations

import json
import math
import os
import struct
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verify_049_hinges as h  # noqa: E402  (same folder: GLB helpers)

ROOT = h.ROOT
PATH = "assets/models/batch049/connect/conn_gauge.glb"
MANIFEST = "assets/models/batch049/connect/manifest.json"
BASE = "77d33ca"
PITCH = 0.002
MARGIN = 0.005
TOL = 1e-5
FIXED = ("gauge_case", "gauge_face", "gauge_bezel")
KEPT = ("gauge_case", "gauge_face", "gauge_needle")


def indices(doc, blob, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    fmt, size = {5121: ("B", 1), 5123: ("H", 2),
                 5125: ("I", 4)}[acc["componentType"]]
    return [struct.unpack_from("<" + fmt, blob, start + i * size)[0]
            for i in range(acc["count"])]


def parts(doc, blob):
    """name -> world triangles, world vertices, UVs, materials."""
    out = {}

    def visit(i, parent):
        node = doc["nodes"][i]
        m = h.mul(parent, h.trs(node))
        if "mesh" in node:
            tris, world, uv, mats = [], [], [], []
            for prim in doc["meshes"][node["mesh"]]["primitives"]:
                pts = [h.apply(m, v) for v in h.accessor(
                    doc, blob, prim["attributes"]["POSITION"], 3)]
                idx = indices(doc, blob, prim["indices"])
                tris += [(pts[idx[j]], pts[idx[j + 1]], pts[idx[j + 2]])
                         for j in range(0, len(idx), 3)]
                world += pts
                uv += h.accessor(doc, blob,
                                 prim["attributes"]["TEXCOORD_0"], 2)
                mats.append(doc["materials"][prim["material"]]["name"])
            out[node.get("name", "?")] = {"tris": tris, "world": world,
                                          "uv": uv, "materials": mats}
        for child in node.get("children", []):
            visit(child, m)

    ident = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
    for i in doc["scenes"][doc.get("scene", 0)]["nodes"]:
        visit(i, ident)
    return out


def flat(tris):
    """Triangles as seen from +Z: 2D box, and what a ray needs."""
    out = []
    for a, b, c in tris:
        det = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(det) < 1e-12:
            continue  # edge-on to the view: a ray never lands on it
        out.append((min(a[0], b[0], c[0]), max(a[0], b[0], c[0]),
                    min(a[1], b[1], c[1]), max(a[1], b[1], c[1]),
                    a, b, c, det))
    return out


def front(flat_tris, x, y):
    """The highest z a ray straight down -Z meets first, or None."""
    best = None
    for x0, x1, y0, y1, a, b, c, det in flat_tris:
        if x < x0 or x > x1 or y < y0 or y > y1:
            continue
        l1 = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / det
        l2 = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / det
        l3 = 1.0 - l1 - l2
        if min(l1, l2, l3) < -1e-9:
            continue
        z = l1 * a[2] + l2 * b[2] + l3 * c[2]
        if best is None or z > best:
            best = z
    return best


def posed(tris, pin, axis, deg):
    turn = h.mul(h.mul([[1, 0, 0, pin[0]], [0, 1, 0, pin[1]],
                        [0, 0, 1, pin[2]], [0, 0, 0, 1]],
                       h.rotation(axis, deg)),
                 [[1, 0, 0, -pin[0]], [0, 1, 0, -pin[1]],
                  [0, 0, 1, -pin[2]], [0, 0, 0, 1]])
    return [tuple(h.apply(turn, p) for p in tri) for tri in tris]


def edge_distance(p, flat_tris):
    """2D distance from p to the nearest of these triangles (0 inside)."""
    def seg(a, b):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy)
                         / (dx * dx + dy * dy)))
        return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)
    best = float("inf")
    for tri in flat_tris:
        a, b, c = tri[4], tri[5], tri[6]
        if front([tri], p[0], p[1]) is not None:
            return 0.0
        best = min(best, seg(a, b), seg(b, c), seg(c, a))
    return best


def main() -> int:
    ref = sys.argv[1] if len(sys.argv) > 1 else None
    with open(os.path.join(ROOT, MANIFEST), encoding="utf-8") as handle:
        manifest = json.load(handle)["conn_gauge"]
    base_manifest = json.loads(subprocess.run(
        ["git", "show", "%s:%s" % (BASE, MANIFEST)], cwd=ROOT, check=True,
        capture_output=True).stdout)["conn_gauge"]
    hinge = manifest["hinge"]
    pin, axis = tuple(hinge["pivot_runtime"]), hinge["axis"]
    now = parts(*h.load(ref, PATH))
    was = parts(*h.load(BASE, PATH))
    problems: list[str] = []
    print("conn_gauge %s; pin %s, axis %s, positions %s"
          % ("at " + ref if ref else "as built", pin, axis.upper(),
             hinge["positions_degrees"]))

    # 3. KEPT -- everything but the bezel's inside is as it was.
    for key in ("node", "axis", "carries", "pivot_runtime",
                "positions_degrees"):
        if hinge[key] != base_manifest["hinge"][key]:
            problems.append("manifest hinge %s changed: %s, was %s"
                            % (key, hinge[key], base_manifest["hinge"][key]))
    if manifest["size"] != base_manifest["size"]:
        problems.append("manifest size changed: %s, was %s"
                        % (manifest["size"], base_manifest["size"]))
    for name in KEPT:
        a, b = was[name], now.get(name)
        if b is None:
            problems.append("%s is gone" % name)
            continue
        if len(a["world"]) != len(b["world"]) or max(
                max(abs(p - q) for p, q in zip(u, v))
                for u, v in zip(a["world"], b["world"])) > TOL:
            problems.append("%s moved or changed shape" % name)
        if a["uv"] != b["uv"] or a["materials"] != b["materials"]:
            problems.append("%s changed UVs or material" % name)
    lo_a =[min(v[k] for v in was["gauge_bezel"]["world"]) for k in range(3)]
    hi_a = [max(v[k] for v in was["gauge_bezel"]["world"]) for k in range(3)]
    lo_b = [min(v[k] for v in now["gauge_bezel"]["world"]) for k in range(3)]
    hi_b = [max(v[k] for v in now["gauge_bezel"]["world"]) for k in range(3)]
    if max(abs(p - q) for p, q in zip(lo_a + hi_a, lo_b + hi_b)) > TOL:
        problems.append("the bezel's outer box changed: %s..%s, was %s..%s"
                        % (lo_b, hi_b, lo_a, hi_a))
    if was["gauge_bezel"]["materials"] != now["gauge_bezel"]["materials"]:
        problems.append("the bezel changed material")
    if now["gauge_needle"]["materials"] == now["gauge_face"]["materials"]:
        problems.append("the needle and face share a material: no contrast")

    # The view: one depth map of the parts that do not move.
    fixed = {n: flat(now[n]["tris"]) for n in FIXED}
    needle = now["gauge_needle"]["tris"]
    reach = max(math.hypot(p[0] - pin[0], p[1] - pin[1])
                for tri in needle for p in tri)
    radius = reach + MARGIN
    rays = []
    n = int(round(0.3 / PITCH))
    for i in range(n):
        for j in range(n):
            x = -0.15 + (i + 0.5) * PITCH
            y = (j + 0.5) * PITCH
            hits = {k: front(v, x, y) for k, v in fixed.items()}
            top = max((z, k) for k, z in hits.items() if z is not None) \
                if any(z is not None for z in hits.values()) else (None, None)
            rays.append((x, y, top[1], top[0],
                         math.hypot(x - pin[0], y - pin[1])))
    cell = PITCH * PITCH * 1e4  # cm^2 per ray
    dial = [r for r in rays if r[4] <= radius]
    seen = {k: sum(1 for r in rays if r[2] == k) * cell for k in FIXED}
    blocked = [r for r in dial if r[2] != "gauge_face"]
    window = edge_distance(pin, fixed["gauge_bezel"])
    print("  from the front: face %.0f cm^2, bezel %.0f cm^2, case %.0f cm^2"
          % (seen["gauge_face"], seen["gauge_bezel"], seen["gauge_case"]))
    print("  needle reach %.3f m; the dial it reads over is the %.3f m disc "
          "round the pin; bezel %.3f m from the pin"
          % (reach, radius, window))

    # 1 and 2, at every declared position and through the sweep.
    declared = hinge["positions_degrees"]
    lo, hi = min(declared.values()), max(declared.values())
    angles = sorted(set([float(d) for d in declared.values()] + [
        float(d) for d in range(int(math.ceil(lo)), int(hi) + 1)]))
    by_pose = {v: k for k, v in declared.items()}
    worst = {"covered": 0, "backed": 0, "dial": 0}
    for deg in angles:
        turned = flat(posed(needle, pin, axis, deg))
        nx0 = min(t[0] for t in turned)
        nx1 = max(t[1] for t in turned)
        ny0 = min(t[2] for t in turned)
        ny1 = max(t[3] for t in turned)
        on_needle = covered = wrong_back = 0
        dial_blocked = 0
        for x, y, part, z, dist in rays:
            zn = (front(turned, x, y)
                  if nx0 <= x <= nx1 and ny0 <= y <= ny1 else None)
            if zn is not None and (z is None or zn >= z):
                on_needle += 1
                if part != "gauge_face":
                    wrong_back += 1
            elif zn is not None:
                covered += 1
            elif dist <= radius and part != "gauge_face":
                dial_blocked += 1
        worst["covered"] = max(worst["covered"], covered)
        worst["backed"] = max(worst["backed"], wrong_back)
        worst["dial"] = max(worst["dial"], dial_blocked)
        if deg in by_pose:
            print("  %-5s %+4.0f deg: needle %.1f cm^2 seen, %.1f cm^2 "
                  "covered, %.1f cm^2 over something other than the face;"
                  " dial %.0f cm^2 of %.0f cm^2 not face or needle"
                  % (by_pose[deg], deg, on_needle * cell, covered * cell,
                     wrong_back * cell, dial_blocked * cell,
                     len(dial) * cell))
            if on_needle == 0:
                problems.append("at '%s' the needle cannot be seen"
                                % by_pose[deg])
        if covered:
            problems.append("at %+.0f deg %.1f cm^2 of the needle is covered"
                            % (deg, covered * cell))
        if wrong_back:
            problems.append("at %+.0f deg %.1f cm^2 of the needle is seen "
                            "against something other than the face"
                            % (deg, wrong_back * cell))
        if dial_blocked:
            problems.append("at %+.0f deg %.1f cm^2 of the dial round the "
                            "pin is hidden" % (deg, dial_blocked * cell))
    print("  sweep %+.0f..%+.0f deg in 1 deg steps (%d angles): worst "
          "covered %d, worst off-face %d, worst hidden dial %d ray(s)"
          % (lo, hi, len(angles), worst["covered"], worst["backed"],
             worst["dial"]))

    if problems:
        shown = problems[:12]
        for p in shown:
            print("FAIL: %s" % p)
        if len(problems) > len(shown):
            print("FAIL: ... and %d more of the same"
                  % (len(problems) - len(shown)))
        return 1
    print("PASS: the face shows round the needle at every reading from %+.0f "
          "to %+.0f deg; the needle is never covered and is always seen "
          "against the face; case, face, needle, pin and sweep as at %s"
          % (lo, hi, BASE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
