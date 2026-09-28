#!/usr/bin/env python3
"""Owner review 2026-09-28 -- a roof-off plan of a room shell, from its GLB.

    python3 tools/owner_review_2026_09_28/plan_from_glb.py <shell.glb> <out.png>
        [--ceiling H] [--mark name:x,y,z ...] [--title TEXT]

Every UPWARD-facing triangle below the ceiling is drawn from above,
coloured by its height, highest on top -- what you could stand on, and how
high. Nothing is inferred: the plan is the model's own geometry. Marks
(entrances, exits, sockets) are placed from the manifest, in the shell's
own coordinates, and labelled with their height.

Isolated review helper; it writes only the PNG it is given.
"""
import argparse
import json
import math
import struct

from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2),
        5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    raw = open(path, "rb").read()
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


def accessor(doc, blob, i):
    a = doc["accessors"][i]
    v = doc["bufferViews"][a["bufferView"]]
    fmt, size = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride", size * n)
    out = []
    for k in range(a["count"]):
        out.append(struct.unpack_from("<" + fmt * n, blob, start + k * stride))
    return out


def quat_rot(q, p):
    x, y, z, w = q
    px, py, pz = p
    # v' = q v q*
    ix = w * px + y * pz - z * py
    iy = w * py + z * px - x * pz
    iz = w * pz + x * py - y * px
    iw = -x * px - y * py - z * pz
    return (ix * w + iw * -x + iy * -z - iz * -y,
            iy * w + iw * -y + iz * -x - ix * -z,
            iz * w + iw * -z + ix * -y - iy * -x)


def triangles(doc, blob):
    tris = []
    for node in doc.get("nodes", []):
        if "mesh" not in node:
            continue
        t = node.get("translation", [0, 0, 0])
        r = node.get("rotation", [0, 0, 0, 1])
        s = node.get("scale", [1, 1, 1])
        name = node.get("name", "")
        for prim in doc["meshes"][node["mesh"]]["primitives"]:
            pos = accessor(doc, blob, prim["attributes"]["POSITION"])
            pos = [quat_rot(r, (p[0] * s[0], p[1] * s[1], p[2] * s[2])) for p in pos]
            pos = [(p[0] + t[0], p[1] + t[1], p[2] + t[2]) for p in pos]
            idx = [i[0] for i in accessor(doc, blob, prim["indices"])] \
                if "indices" in prim else list(range(len(pos)))
            for k in range(0, len(idx) - 2, 3):
                tris.append((name, pos[idx[k]], pos[idx[k + 1]], pos[idx[k + 2]]))
    return tris


def colour(h, hmax):
    # grade: pale concrete; raised: towards amber; below grade: blue
    if h < -0.05:
        return (90, 130, 185)
    if h < 0.05:
        return (200, 202, 205)
    k = min(1.0, h / max(hmax, 0.1))
    return (int(214 + 30 * k), int(188 - 70 * k), int(120 - 80 * k))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("glb")
    ap.add_argument("out")
    ap.add_argument("--ceiling", type=float, default=None)
    ap.add_argument("--mark", action="append", default=[])
    ap.add_argument("--title", default="")
    ap.add_argument("--levels", default="0",
                    help="declared walkable levels, comma-separated (m). Faces at a "
                         "level are coloured by it; faces between levels read as "
                         "steps; faces above the top level read as solid structure")
    ap.add_argument("--flipz", action="store_true",
                    help="draw +z upward instead of -z (entry at the bottom)")
    a = ap.parse_args()
    doc, blob = read_glb(a.glb)
    tris = [t for t in triangles(doc, blob) if "colonly" not in t[0].lower()]
    xs = [p[0] for t in tris for p in t[1:]]
    zs = [p[2] for t in tris for p in t[1:]]
    ys = [p[1] for t in tris for p in t[1:]]
    ceiling = a.ceiling if a.ceiling is not None else max(ys) - 0.3
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    span = max(x1 - x0, z1 - z0)
    ppm = max(8, min(40, int(760 / span)))
    W = int((x1 - x0) * ppm) + 300
    H = int((z1 - z0) * ppm) + 200
    img = Image.new("RGB", (W, H), (26, 28, 32))
    d = ImageDraw.Draw(img)
    f, fs, fb = ImageFont.truetype(FONT, 16), ImageFont.truetype(FONT, 14), \
        ImageFont.truetype(FONT_B, 18)

    def to_px(x, z):
        u = 80 + (x - x0) * ppm
        v = (100 + (z1 - z) * ppm) if a.flipz else (100 + (z - z0) * ppm)
        return (u, v)

    ups, walls = [], []
    for name, p0, p1, p2 in tris:
        ux, uy, uz = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
        vx, vy, vz = (p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2])
        nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        h = (p0[1] + p1[1] + p2[1]) / 3.0
        if ny / ln > 0.7 and h < ceiling:
            ups.append((h, p0, p1, p2))
        elif abs(ny / ln) < 0.3 and min(p0[1], p1[1], p2[1]) < ceiling:
            walls.append((p0, p1, p2))
    levels = sorted(float(v) for v in a.levels.split(","))
    top = max(levels)

    def classify(h):
        for lv in levels:
            if abs(h - lv) <= 0.35:
                return colour(lv, max(top, 0.1))
        if h < -0.05:
            return (90, 130, 185)
        if h < top:
            return (236, 214, 160)          # a step or ramp between levels
        return (58, 61, 66)                 # solid: a wall, column or mass top
    for h, p0, p1, p2 in sorted(ups, key=lambda u: u[0]):
        d.polygon([to_px(p[0], p[2]) for p in (p0, p1, p2)], fill=classify(h))
    # Walls and columns, from their vertical faces seen edge-on from above.
    for p0, p1, p2 in walls:
        pts = [to_px(p[0], p[2]) for p in (p0, p1, p2)]
        d.line(pts + [pts[0]], fill=(40, 42, 46), width=3)
    # height labels: one per distinct level
    seen = []
    for h, p0, p1, p2 in sorted(ups, key=lambda u: -abs(u[0])):
        if abs(h) < 0.05 or any(abs(h - s) < 0.25 for s in seen):
            continue
        seen.append(h)
    d.text((16, 14), a.title, fill=(240, 240, 240), font=fb)
    lv = "walkable levels (m): " + ", ".join(
        "grade" if abs(v) < 0.05 else f"{v:+.1f}" for v in levels)
    d.text((16, 40), lv, fill=(200, 200, 200), font=fs)
    d.text((16, 60), "roof-off plan from the model's own upward faces. Pale = "
           "grade; amber = raised level; cream = steps; blue = below grade; "
           "dark = solid", fill=(150, 150, 150), font=fs)
    for m in a.mark:
        label, xyz = m.split(":")
        x, y, z = (float(c) for c in xyz.split(","))
        u, v = to_px(x, z)
        d.ellipse([u - 9, v - 9, u + 9, v + 9], fill=(60, 200, 190), outline=(0, 0, 0))
        tag = f"{label} ({'grade' if abs(y) < 0.05 else f'+{y:.1f} m'})"
        d.text((u + 12, v - 9), tag, fill=(120, 240, 230), font=f)
    # scale bar: 5 m
    bx, by = 80, H - 40
    d.rectangle([bx, by, bx + 5 * ppm, by + 6], fill=(230, 230, 230))
    d.text((bx + 5 * ppm + 8, by - 6), "5 m", fill=(230, 230, 230), font=f)
    img.save(a.out)
    print(f"plan: {a.out} ({W}x{H}, {ppm} px/m, {len(ups)} upward faces)")


if __name__ == "__main__":
    main()
