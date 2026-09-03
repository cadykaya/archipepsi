"""What does a flight's collision surface ACTUALLY do underfoot?

    python3 tools/content/measure_flights.py [shell_id ...]

WHY THIS EXISTS. Production's capsule audit at `67add07` refused
`basin_to_gallery` and `gantry_to_exit` on the hall: the real collision
surface sawtooths, dipping 0.35-0.70 m between apparent treads and then
demanding climbs of about 1.40 m against a `MAX_VERTICAL_STEP` of 1.0.
Every Art gate had passed them, because every Art gate was reading
COLLIDER AABBs -- and the AABB of a sloped wedge is a box whose top is
the wedge's high end. The box says "flat tread at 11.00 m". The triangle
underfoot says something else entirely.

> An AABB cannot see a slope. That is the whole point of an AABB, and it
> is why one must never be the last word on a walking surface.

So this reads the TRIANGLES. It parses the shipped `.glb`, takes the
`-convcolonly` collider meshes -- which `roomcollision.build` makes as
exact mesh copies, so they are the physics surface, not an approximation
of it -- and drops a dense grid of downward rays through them. What comes
back is the real height field a player's feet meet.

WHAT IT PROVES. For every flight in the shell, the largest upward step
between adjacent samples of that height field, measured on a grid far
finer than the player radius so a dip cannot hide between two samples.
If that number is over `MAX_VERTICAL_STEP` the flight is not walkable,
whatever its AABBs or its declarations say.

SCOPED TO THE FLIGHT'S OWN TREADS, and that scope is load-bearing. The
first version sampled every collider in the room and refused eight of
Wave 1's flights -- all of them ordinary staircases whose bbox happened
to contain a NEIGHBOURING deck at another height: the yard's catwalk at
y=8 abuts the foot of an 8 m stair, so two samples 0.1 m apart read 0.89
and 8.00. That is a floor beside a wall, which is what architecture looks
like, and calling it a step is the L-88 mistake again -- a check that
fires on correct geometry is the suspect. Whether a flight CONNECTS to
what it lands on is a routing question, and `traversallaw` at build time
and `RoomAudit` in the engine both already ask it.

NOT A SUBSTITUTE FOR `RoomAudit`. This measures the surface; Production
floods it with the real capsule and remains the final authority. A flight
that passes here can still fail there for reasons a height field cannot
see -- headroom, a pinch too narrow for a body. It cannot pass there
while failing here.
"""

from __future__ import annotations

import json
import math
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
#: Every directory the room library ships shells from. Not one: the hall
#: is batch039 and Wave 1 is batch040, and a checker that knows about
#: only the batch it was written for is the shape of gap L-33 named.
SHELLS = sorted(
    os.path.join(ROOT, "assets", "models", batch, "shells")
    for batch in os.listdir(os.path.join(ROOT, "assets", "models"))
    if os.path.isdir(os.path.join(ROOT, "assets", "models", batch, "shells")))

#: `Constants.MAX_VERTICAL_STEP`. The height a player can step up without
#: jumping, and therefore the bound a `walk` surface has to keep.
MAX_VERTICAL_STEP = 1.0

#: `TraversalLaw.AS_BUILT_SLACK` -- the float32 round-trip through glTF
#: storage moves a vertex by ~1e-7 m, and a tread built exactly at the
#: bound must not fail for that.
AS_BUILT_SLACK = 0.01

#: Sample spacing for the height field, in metres. `WALK_GRID` is 0.4
#: (the player radius); this is deliberately four times finer, because
#: the defect being hunted is a dip BETWEEN two coarse samples. At 0.4 m
#: the hall's sawtooth reads as an ordinary staircase.
RESOLUTION = 0.1

#: A sample is only compared with a neighbour if both found ground. A
#: flight's footprint is a rectangle and its geometry need not fill it.
NO_GROUND = None


# --------------------------------------------------------------------
# glTF
# --------------------------------------------------------------------

_COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
              5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
          "MAT4": 16}


def _chunks(path):
    data = open(path, "rb").read()
    off, js, blob = 12, None, None
    while off < len(data):
        length, kind = struct.unpack_from("<II", data, off)
        off += 8
        payload = data[off:off + length]
        off += length
        if kind == 0x4E4F534A:
            js = json.loads(payload)
        elif kind == 0x004E4942:
            blob = payload
    return js, blob


def _accessor(js, blob, index):
    acc = js["accessors"][index]
    fmt, size = _COMPONENT[acc["componentType"]]
    per = _COUNT[acc["type"]]
    view = js["bufferViews"][acc["bufferView"]]
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or (size * per)
    out = []
    for i in range(acc["count"]):
        at = base + i * stride
        vals = struct.unpack_from("<" + fmt * per, blob, at)
        out.append(vals if per > 1 else vals[0])
    return out


def _matrix(node):
    """The node's local transform as a 4x4 row-major tuple of tuples."""
    if "matrix" in node:                     # glTF stores column-major
        m = node["matrix"]
        return tuple(tuple(m[c * 4 + r] for c in range(4)) for r in range(4))
    t = node.get("translation", (0.0, 0.0, 0.0))
    s = node.get("scale", (1.0, 1.0, 1.0))
    x, y, z, w = node.get("rotation", (0.0, 0.0, 0.0, 1.0))
    rot = (
        (1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
        (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
        (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)),
    )
    return tuple(tuple(rot[r][c] * s[c] for c in range(3)) + (t[r],)
                 for r in range(3)) + ((0.0, 0.0, 0.0, 1.0),)


def _mul(a, b):
    return tuple(tuple(sum(a[r][k] * b[k][c] for k in range(4))
                       for c in range(4)) for r in range(4))


def _apply(m, v):
    return tuple(m[r][0] * v[0] + m[r][1] * v[1] + m[r][2] * v[2] + m[r][3]
                 for r in range(3))


def triangles(path):
    """Every collider triangle in the shell, in world (== Godot) metres.

    glTF is Y-up and so is Godot, and the Blender exporter applies the
    same (x, z, -y) conversion the art pipeline documents -- so these
    coordinates need no further mapping to compare against the manifest.
    """
    js, blob = _chunks(path)
    out = {}
    stack = []
    for scene in js.get("scenes", []):
        for root in scene.get("nodes", []):
            stack.append((root, ((1, 0, 0, 0), (0, 1, 0, 0),
                                 (0, 0, 1, 0), (0, 0, 0, 1))))
    while stack:
        index, parent = stack.pop()
        node = js["nodes"][index]
        world = _mul(parent, _matrix(node))
        for child in node.get("children", []):
            stack.append((child, world))
        if "mesh" not in node:
            continue
        name = node.get("name", "?")
        if "convcolonly" not in name:
            continue
        tris = out.setdefault(name, [])
        for prim in js["meshes"][node["mesh"]].get("primitives", []):
            pos = _accessor(js, blob, prim["attributes"]["POSITION"])
            pts = [_apply(world, p) for p in pos]
            if "indices" in prim:
                idx = _accessor(js, blob, prim["indices"])
            else:
                idx = list(range(len(pts)))
            for i in range(0, len(idx) - 2, 3):
                tris.append((pts[idx[i]], pts[idx[i + 1]], pts[idx[i + 2]]))
    return out


# --------------------------------------------------------------------
# the height field
# --------------------------------------------------------------------

class Field(object):
    """Downward rays against a triangle soup, bucketed in the xz plane."""

    CELL = 2.0

    def __init__(self, tris):
        self.buckets = {}
        for tri in tris:
            xs = [p[0] for p in tri]
            zs = [p[2] for p in tri]
            for cx in range(int(math.floor(min(xs) / self.CELL)),
                            int(math.floor(max(xs) / self.CELL)) + 1):
                for cz in range(int(math.floor(min(zs) / self.CELL)),
                                int(math.floor(max(zs) / self.CELL)) + 1):
                    self.buckets.setdefault((cx, cz), []).append(tri)

    def top(self, x, z, ceiling):
        """Highest surface at or below `ceiling` over (x, z), or None."""
        key = (int(math.floor(x / self.CELL)), int(math.floor(z / self.CELL)))
        best = NO_GROUND
        for (ax, ay, az), (bx, by, bz), (cx, cy, cz) in \
                self.buckets.get(key, ()):
            # Barycentric containment in the xz plane.
            v0x, v0z = cx - ax, cz - az
            v1x, v1z = bx - ax, bz - az
            v2x, v2z = x - ax, z - az
            den = v0x * v1z - v1x * v0z
            if abs(den) < 1e-12:
                continue                     # a triangle seen edge-on
            u = (v2x * v1z - v1x * v2z) / den
            v = (v0x * v2z - v2x * v0z) / den
            if u < -1e-9 or v < -1e-9 or u + v > 1.0 + 1e-9:
                continue
            y = ay + u * (cy - ay) + v * (by - ay)
            if y <= ceiling + 1e-9 and (best is NO_GROUND or y > best):
                best = y
        return best


def profile(field, x0, x1, z0, z1, ceiling, res=RESOLUTION):
    """A height field over the rectangle, as {(i, j): height or None}."""
    nx = max(2, int(round((x1 - x0) / res)) + 1)
    nz = max(2, int(round((z1 - z0) / res)) + 1)
    grid = {}
    for i in range(nx):
        x = x0 + (x1 - x0) * (i / (nx - 1.0))
        for j in range(nz):
            z = z0 + (z1 - z0) * (j / (nz - 1.0))
            grid[(i, j)] = field.top(x, z, ceiling)
    return grid, nx, nz


def worst_step(grid, nx, nz):
    """The largest rise between 4-adjacent samples that both found ground.

    Direction-free on purpose: a walker may cross a flight at any angle,
    and a step that is too tall going one way is too tall.
    """
    worst, where = 0.0, None
    for (i, j), here in grid.items():
        if here is NO_GROUND:
            continue
        for di, dj in ((1, 0), (0, 1)):
            there = grid.get((i + di, j + dj), NO_GROUND)
            if there is NO_GROUND:
                continue
            step = abs(there - here)
            if step > worst:
                worst, where = step, (i, j, di, dj, here, there)
    return worst, where


# --------------------------------------------------------------------
# flights
# --------------------------------------------------------------------

#: `roomkit.flight` names its treads `<shell>_<tag>_tread<i>`, and
#: `roomcollision` appends the import suffix. The `tread` infix is what
#: makes this exact rather than a guess, and it took two tries to get
#: there. Matching any trailing number swept up the hall's ramp SUPPORT
#: LEGS and reported an 11 m "step" up the side of a column; matching
#: `_step<i>` then swept up the treasure rooms' two-tier plinths, which
#: `build_rooms` has called `<shell>_step0` since long before this
#: module existed. `<tag>_tread<i>`, with NO separator before the index,
#: is produced by `roomkit.flight` alone -- `build_affordances` has an
#: `mp_tread_%d` whose underscore is the only thing keeping it out, which
#: is thin enough to say out loud, though it is a prop and never reaches
#: a shells/ folder.
#:
#: A tool that hunts for a defect must not invent ones of its own.
_SECTION = re.compile(r"^(?P<stem>.+)_tread(?P<n>\d+)-convcolonly$")


def flights(tris):
    """Group collider meshes into flights by their `<tag>_<i>` names."""
    groups = {}
    for name, mesh in tris.items():
        hit = _SECTION.match(name)
        if hit is None:
            continue
        groups.setdefault(hit.group("stem"), []).append((int(hit.group("n")),
                                                         mesh))
    # A flight is a CHAIN. One lone numbered part is a numbered part.
    return {k: [m for _, m in sorted(v)]
            for k, v in groups.items() if len(v) > 1}


def bounds(meshes):
    pts = [p for mesh in meshes for tri in mesh for p in tri]
    return (min(p[0] for p in pts), max(p[0] for p in pts),
            min(p[2] for p in pts), max(p[2] for p in pts),
            min(p[1] for p in pts), max(p[1] for p in pts))


def main(argv):
    wanted = argv[1:]
    paths = sorted(os.path.join(d, f) for d in SHELLS
                   for f in os.listdir(d)
                   if f.endswith(".glb")
                   and (not wanted or any(w in f for w in wanted)))
    bad, seen = [], 0
    for path in paths:
        cid = os.path.basename(path)[:-4]
        tris = triangles(path)
        groups = flights(tris)
        if not groups:
            continue
        for tag in sorted(groups):
            meshes = groups[tag]
            field = Field([t for mesh in meshes for t in mesh])
            x0, x1, z0, z1, _, top = bounds(meshes)
            grid, nx, nz = profile(field, x0, x1, z0, z1, top + 1e-6)
            step, where = worst_step(grid, nx, nz)
            # A HOLE IS INVISIBLE TO `worst_step`, which only compares
            # neighbours that BOTH found ground -- so a flight missing a
            # tread would sail through it. The treads tile their own
            # footprint by construction (`FLIGHT_OVERLAP` reaches each
            # one into the next), and this is what holds them to it.
            holes = sum(1 for v in grid.values() if v is NO_GROUND)
            seen += 1
            ok = step <= MAX_VERTICAL_STEP + AS_BUILT_SLACK and not holes
            # The TREAD TOPS, not the meshes' vertical extent: a tread
            # hangs below its own top by the soffit, and reporting that
            # as the climb would overstate every flight in the room.
            tops = sorted(max(p[1] for tri in mesh for p in tri)
                          for mesh in meshes)
            print("[flight] %-30s %2d treads  tops %6.2f -> %6.2f m  "
                  "worst step %5.2f m  %d hole(s)  %s"
                  % (tag, len(meshes), tops[0], tops[-1], step, holes,
                     "ok" if ok else "REFUSED"))
            if holes:
                bad.append(
                    "%s/%s: %d of %d samples over the flight's own "
                    "footprint find no tread under them. A staircase with "
                    "a hole in it is not a staircase."
                    % (cid, tag, holes, len(grid)))
            if step > MAX_VERTICAL_STEP + AS_BUILT_SLACK:
                i, j, di, dj, here, there = where
                bad.append(
                    "%s/%s: the real surface steps %.2f m between samples "
                    "%.1f m apart (%.2f -> %.2f), against MAX_VERTICAL_STEP "
                    "%.2f. The AABBs do not show this; the triangles do."
                    % (cid, tag, step, RESOLUTION, here, there,
                       MAX_VERTICAL_STEP))
    for line in bad:
        print("[flight]   %s" % line)
    print("[flight] %d flight(s) measured at %.2f m, %d refused"
          % (seen, RESOLUTION, len(bad)))
    if bad:
        print("[flight] FAIL -- a walk surface that steps over "
              "MAX_VERTICAL_STEP is not walkable, whatever it declares")
        return 1
    print("[flight] PASS -- every flight's real collision surface keeps "
          "MAX_VERTICAL_STEP")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
