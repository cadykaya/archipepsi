"""gbkit -- a Blender-free graybox kit for LARGE authored room shells.

    python3 tools/graybox/build.py tools/graybox/rooms/<id>.py

WHAT THIS IS. A room is authored as a short Python spec in GODOT space
(x right, y up, z into the room; entry doorway centred at the origin,
walking plane y = 0, exit on +z).  From that one spec the kit emits:

  * a .glb  -- one merged visual mesh plus one `-convcolonly` twin per
               structural part, which is exactly the shape Art's Blender
               exporter produces (`roomcollision.py`), so Godot's importer
               turns the twins into ConvexPolygonShape3D colliders;
  * a manifest entry in the shape of `assets/models/batch039/shells/
               manifest.json` (surfaces, sockets, traversal, offers,
               volumes, size / size_godot / interior / bounds);
  * plan + section SVGs for review;
  * a PREFLIGHT report that mirrors the contract's own arithmetic:
      - `Surface` minimum span and the C(ii) stance search
        (`roomcollision.measure_stances` / `Placement.find`);
      - the P3.5A walk flood (`TraversalLaw._walk_is_evidenced`) under
        BOTH evidences: hull boxes (what `ShellValidator` sees at import)
        and boxes plus a body test (a stricter stand-in for `RoomAudit`);
      - `max_safe_gap(rise)` on every `gap`/`rise`, drops never rising;
      - `RailPath` bounds on the BAKED Catmull-Rom curve, containment in
        the envelope, clearance from geometry;
      - `LaunchSolver` bounds: range, landing radius, the 3.5 m apex arc
        walked at 24 samples against geometry, floor under the landing;
      - `grapple_point`: anchor clear, 4 m of swing room, ground ≤ 30 m
        below;
      - envelope containment with the shared WALL_ALLOWANCE, doorway
        holes, schema caps, socket/surface name integrity, sightlines.

WHAT THIS IS NOT. A verdict. `room_audit.gd` fires real probes at an
instantiated scene and is the only physical authority.  Everything here
is a PREDICTION so that a room which cannot keep its promises fails at
the spec, where the geometry is still a variable.

AXES.  Everything is authored in Godot metres, so the Blender axis trap
(`roomcontract.godot`) never arises.  The manifest's `size` is emitted in
Blender order [outer_width, LENGTH, outer_height] and `size_godot` in
[outer_width, outer_height, LENGTH], which is what `assert_axis_order`
requires of every shipped shell.
"""
from __future__ import annotations

import json
import math
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, "engine_dims.json"), encoding="utf-8") as _fh:
    DIM = json.load(_fh)

EPS = 1e-4
SOLID_ROLES = ("floor", "wall", "ceiling")
ROLES = SOLID_ROLES + ("trim",)
ROLE_RGBA = {
    "floor": (0.62, 0.64, 0.66, 1.0),
    "wall": (0.42, 0.44, 0.47, 1.0),
    "ceiling": (0.30, 0.31, 0.34, 1.0),
    "trim": (0.85, 0.55, 0.15, 1.0),
}


# ---------------------------------------------------------------------------
# engine law, re-derived from the same constants (never retyped as results)
# ---------------------------------------------------------------------------

def jump_reach(rise: float) -> float:
    """Horizontal reach of a base-kit jump landing `rise` metres higher,
    for the worst legal loadout (gravity x1.0, speed x0.9).  Mirrors
    `constants.jump_reach`: airtime from the launch to the landing height."""
    g, v = DIM["gravity"], DIM["jump_velocity"]
    disc = v * v - 2.0 * g * rise
    if disc < 0.0:
        return 0.0
    airtime = (v + math.sqrt(disc)) / g
    return DIM["walk_speed"] * DIM["speed_mult_min"] * airtime


def max_safe_gap(rise: float) -> float:
    """`constants.max_safe_gap`: reach x margin, floored to one decimal."""
    return math.floor(jump_reach(max(rise, 0.0)) * DIM["safe_gap_margin"] * 10.0 + 1e-9) / 10.0


# self-check against the two values the schema pins
assert abs(max_safe_gap(0.0) - 2.6) < 1e-9, max_safe_gap(0.0)
assert abs(max_safe_gap(1.0) - 2.0) < 1e-9, max_safe_gap(1.0)


# ---------------------------------------------------------------------------
# geometry
# ---------------------------------------------------------------------------

class Box:
    """An axis-aligned block: `lo`/`hi` corners in Godot metres."""
    __slots__ = ("name", "role", "lo", "hi")

    def __init__(self, name, role, lo, hi):
        if role not in ROLES:
            raise ValueError("%s: role %r is not one of %s" % (name, role, ROLES))
        lo = tuple(float(v) for v in lo)
        hi = tuple(float(v) for v in hi)
        for i in range(3):
            if hi[i] - lo[i] < 0.01:
                raise ValueError("%s: degenerate on axis %d (%s..%s)" % (name, i, lo, hi))
        self.name, self.role, self.lo, self.hi = name, role, lo, hi

    @property
    def top(self):
        return self.hi[1]

    @property
    def solid(self):
        return self.role in SOLID_ROLES

    def centre(self):
        return tuple((self.lo[i] + self.hi[i]) / 2.0 for i in range(3))

    def size(self):
        return tuple(self.hi[i] - self.lo[i] for i in range(3))

    def contains(self, p, pad=0.0):
        return all(self.lo[i] - pad <= p[i] <= self.hi[i] + pad for i in range(3))

    def overlaps_xz(self, x, z, pad=0.0):
        return (self.lo[0] - pad <= x <= self.hi[0] + pad
                and self.lo[2] - pad <= z <= self.hi[2] + pad)

    def intersects(self, lo, hi):
        return all(self.lo[i] < hi[i] - EPS and self.hi[i] > lo[i] + EPS for i in range(3))


class Room:
    """Everything a shell declares, accumulated by the spec."""

    def __init__(self, cid, width, height, depth, wall=0.6,
                 size_class="large", theme="concrete_facility", intent=()):
        self.cid = cid
        self.W, self.H, self.D = float(width), float(height), float(depth)
        self.wall = float(wall)
        self.size_class = size_class
        self.theme = theme
        self.intent = list(intent)
        self.parts: list[Box] = []
        self.surfaces: list[dict] = []
        self.sockets: list[dict] = []
        self.traversal: list[dict] = []
        self.offers: list[dict] = []
        self.volumes: list[dict] = []
        self.sightlines: list[tuple] = []
        self.exit_y = 0.0
        self.exit_yaw = 0.0
        self.exit_xz = (0.0, self.D + 2.0)
        self.notes: list[str] = []
        self.thesis = ""
        self.first_read = ""

    # -- parts -----------------------------------------------------------
    def block(self, name, role, lo, hi):
        b = Box(name, role, lo, hi)
        self.parts.append(b)
        return b

    def slab(self, name, x0, x1, z0, z1, top, thick=0.7, role="floor", surface=True):
        """A deck by its plan edges and its TOP face.  Declares a Surface
        of the same rect unless `surface=False` (a slab that is only a
        roof, or one already covered by a larger declared Surface)."""
        b = self.block(name, role, (x0, top - thick, z0), (x1, top, z1))
        if surface:
            self.surface(name, x0, x1, z0, z1, top)
        return b

    def surface(self, name, x0, x1, z0, z1, top):
        ex, ez = x1 - x0, z1 - z0
        self.surfaces.append({"name": name,
                              "center": [r3((x0 + x1) / 2), r3(top), r3((z0 + z1) / 2)],
                              "extent": [r3(ex), r3(ez)]})
        return name

    def stair(self, name, x0, x1, z0, z1, low, high, axis="z", riser=0.5,
              role="floor", surface=True, reverse=False):
        """A CLIMB built as a run of blocks stepping `riser` each, so the
        collision hull tops step by <= MAX_VERTICAL_STEP and the P3.5A
        flood proves it under hull-box evidence (see gbkit.__doc__).
        `axis` is the direction of climb; `reverse` climbs toward -axis.
        Each tread is one block reaching down to `low - 0.7`, so the flank
        reads as a solid mass rather than a stack of floating steps."""
        if riser > DIM["max_vertical_step"] + EPS:
            raise ValueError("%s: riser %.2f exceeds MAX_VERTICAL_STEP" % (name, riser))
        rise = high - low
        n = max(1, int(math.ceil(rise / riser - 1e-9)))
        run = (z1 - z0) if axis == "z" else (x1 - x0)
        tread = run / n
        for i in range(n):
            top = min(high, low + riser * (i + 1))
            t0 = i * tread
            t1 = (i + 1) * tread
            if reverse:
                t0, t1 = run - t1, run - t0
            if axis == "z":
                lo = (x0, low - 0.7, z0 + t0)
                hi = (x1, top, z0 + t1)
            else:
                lo = (x0 + t0, low - 0.7, z0)
                hi = (x0 + t1, top, z1)
            self.block("%s_t%02d" % (name, i), role, lo, hi)
        if surface:
            # One declared Surface over the whole flight: under C(ii) it
            # only promises that a placement can be FOUND, and under P3.5A
            # its rect merely bounds the flood.  Declared at the flight's
            # top so a socket can stand at the landing.
            self.surface(name, x0, x1, z0, z1, high)
        return n

    # -- declarations ----------------------------------------------------
    def socket(self, name, kind, pos, surface_id="", yaw=0.0, width=0.0, height=0.0):
        s = {"name": name, "kind": kind, "position": [r3(v) for v in pos], "yaw": r3(yaw)}
        if width:
            s["width"] = r3(width)
        if height:
            s["height"] = r3(height)
        if surface_id:
            s["surface_id"] = surface_id
        self.sockets.append(s)
        return s

    def seg(self, name, kind, a, b, mandatory=True):
        self.traversal.append({"name": name, "kind": kind, "mandatory": bool(mandatory),
                               "start": [r3(v) for v in a], "end": [r3(v) for v in b]})

    def rail(self, name, points):
        self.offers.append({"name": name, "kind": "rail_route",
                            "points": [[r3(v) for v in p] for p in points]})

    def launch(self, name, source, target_name, radius=3.0):
        self.offers.append({"name": name, "kind": "launch_source",
                            "position": [r3(v) for v in source], "radius": r3(radius),
                            "target": target_name})

    def landing(self, name, pos, radius=3.0):
        self.offers.append({"name": name, "kind": "launch_target",
                            "position": [r3(v) for v in pos], "radius": r3(radius)})

    def grapple(self, name, pos, radius=1.5):
        self.offers.append({"name": name, "kind": "grapple_point",
                            "position": [r3(v) for v in pos], "radius": r3(radius)})

    def volume(self, name, kind, centre, size):
        self.volumes.append({"name": name, "kind": kind,
                             "center": [r3(v) for v in centre], "size": [r3(v) for v in size]})

    def sightline(self, who, eye, target):
        self.sightlines.append((who, tuple(eye), tuple(target)))

    def doors(self, exit_y, exit_yaw=0.0, exit_xz=None, entry_surface="", exit_surface=""):
        """The two joining sockets every chained shell owes: entry at the
        origin facing 180, exit two metres past the far face (hall convention)."""
        self.exit_y = float(exit_y)
        self.exit_yaw = float(exit_yaw)
        if exit_xz is not None:
            self.exit_xz = (float(exit_xz[0]), float(exit_xz[1]))
        dw, dh = DIM["door_width"], DIM["door_height"]
        self.socket("entry", "doorway", (0.0, 0.0, 0.0), entry_surface, 180.0, dw, dh)
        self.socket("exit", "doorway", (self.exit_xz[0], self.exit_y, self.exit_xz[1]),
                    exit_surface, self.exit_yaw, dw, dh)

    # -- derived ---------------------------------------------------------
    def solids(self):
        return [p for p in self.parts if p.solid]

    def outer_size(self):
        lo = [min(p.lo[i] for p in self.parts) for i in range(3)]
        hi = [max(p.hi[i] for p in self.parts) for i in range(3)]
        return lo, hi, [hi[i] - lo[i] for i in range(3)]

    def declared_size(self):
        """The `size` the manifest will declare, Godot order [w, h, LENGTH].

        `_from_authored_scene` centres the envelope on the entry axis
        (`AABB((-size.x/2, -1, 0), size)`), so an asymmetric plan must
        declare the width of its widest excursion on BOTH sides -- an
        L-shaped room reserves its own mirror image.  The exit socket is
        the next room's origin and is included so the chain guard sees it."""
        lo, hi, _ = self.outer_size()
        half_x = max(abs(lo[0]), abs(hi[0]), abs(self.exit_xz[0]))
        top = max(hi[1], self.exit_y + DIM["door_height"])
        length = max(hi[2], self.exit_xz[1])
        return [2.0 * half_x, top, length]

    def envelope(self):
        """`RoomContract.envelope` of the bounds this room will declare."""
        sx, sy, sz = self.declared_size()
        a = DIM["wall_allowance"]
        lo = (-sx / 2 - a, -DIM["floor_allowance"] - a, -a)
        hi = (sx / 2 + a, sy + a, sz + a)
        return lo, hi

    # -- enclosure -------------------------------------------------------
    def enclose(self, wall=None, roof=True, floor=True, plan=None,
                entry_w=None, entry_h=None, exit_w=6.0, exit_h=8.0,
                exit_sill=None, front_z=0.0):
        """Walls, roof and floor slab around a rectangular plan
        (x0, x1, z0, z1) with the entry doorway cut in the front wall and
        the exit portal cut in the face the exit socket looks through
        (yaw 0: back face; yaw +90: +x face; yaw -90: -x face).
        A doorway is an ABSENCE of boxes: the wall is split around it."""
        w = self.wall if wall is None else wall
        x0, x1, z0, z1 = plan if plan else (-self.W / 2, self.W / 2, 0.0, self.D)
        ew = DIM["door_width"] if entry_w is None else entry_w
        eh = DIM["door_height"] if entry_h is None else entry_h
        sill = self.exit_y if exit_sill is None else exit_sill
        H = self.H
        # THE FRONT FACE SITS INSIDE z >= 0 (hall convention): the envelope
        # `_check_envelope` grows is anchored at z = 0, so a wall in front
        # of the origin reaches 0.05 m outside it.
        if floor:
            self.block("floor_slab", "floor", (x0 - w, -1.0, z0), (x1 + w, 0.0, z1 + w))
        if roof:
            self.block("roof", "ceiling", (x0 - w, H, z0), (x1 + w, H + w, z1 + w))
        self._wall_with_hole("front", (x0 - w, x1 + w), (z0, z0 + w), 0.0, ew, 0.0, eh, axis="x")
        # back / side faces, the exit face gets the portal
        ex, ez = self.exit_xz
        if self.exit_yaw == 0.0:
            self._wall_with_hole("back", (x0 - w, x1 + w), (z1, z1 + w), ex, exit_w, sill, sill + exit_h, axis="x")
            self.block("wall_w", "wall", (x0 - w, 0.0, z0), (x0, H, z1 + w))
            self.block("wall_e", "wall", (x1, 0.0, z0), (x1 + w, H, z1 + w))
        elif self.exit_yaw == 90.0:
            self.block("back", "wall", (x0 - w, 0.0, z1), (x1 + w, H, z1 + w))
            self.block("wall_w", "wall", (x0 - w, 0.0, z0), (x0, H, z1 + w))
            self._wall_with_hole("wall_e", (z0, z1 + w), (x1, x1 + w), ez, exit_w, sill, sill + exit_h, axis="z")
        else:
            self.block("back", "wall", (x0 - w, 0.0, z1), (x1 + w, H, z1 + w))
            self.block("wall_e", "wall", (x1, 0.0, z0), (x1 + w, H, z1 + w))
            self._wall_with_hole("wall_w", (z0, z1 + w), (x0 - w, x0), ez, exit_w, sill, sill + exit_h, axis="z")

    def _wall_with_hole(self, name, along, thick, hole_c, hole_w, hole_lo, hole_hi, axis):
        """A wall spanning `along` (in `axis`) and `thick` (the other axis),
        full height, with a hole centred at `hole_c` from `hole_lo` to
        `hole_hi`: two side pieces, a sill piece and a head piece."""
        H = self.H
        a0, a1 = along
        t0, t1 = thick
        h0, h1 = hole_c - hole_w / 2, hole_c + hole_w / 2

        def box(tag, u0, u1, y0, y1):
            if u1 - u0 < 0.01 or y1 - y0 < 0.01:
                return
            if axis == "x":
                self.block("%s_%s" % (name, tag), "wall", (u0, y0, t0), (u1, y1, t1))
            else:
                self.block("%s_%s" % (name, tag), "wall", (t0, y0, u0), (t1, y1, u1))
        box("a", a0, h0, 0.0, H)
        box("b", h1, a1, 0.0, H)
        if hole_lo > 0.0:
            box("sill", h0, h1, 0.0, hole_lo)
        box("head", h0, h1, hole_hi, H)


def r3(v):
    return round(float(v), 3) + 0.0


# ---------------------------------------------------------------------------
# hull-box evidence (the import-time way of seeing)
# ---------------------------------------------------------------------------

def mesh_ground(boxes, at, reach=None):
    """`TraversalLaw.mesh_ground`: the highest hull top under `at` within
    one step above and `reach` below, ground within the player's radius
    counting as under them."""
    reach = DIM["walk_mesh_reach"] if reach is None else reach
    grip = DIM["player_radius"]
    best = -math.inf
    for b in boxes:
        if not b.overlaps_xz(at[0], at[2], grip):
            continue
        top = b.top
        if top > at[1] + DIM["max_vertical_step"]:
            continue
        if top < at[1] - reach:
            continue
        best = max(best, top)
    return best


def boxes_fit(boxes, at_floor):
    """`TraversalLaw.boxes_fit`: only the body ABOVE step height."""
    r = DIM["player_radius"]
    lo = (at_floor[0] - r, at_floor[1] + DIM["max_vertical_step"] + 0.05, at_floor[2] - r)
    hi = (at_floor[0] + r, at_floor[1] + DIM["player_height"] + 0.05, at_floor[2] + r)
    return not any(b.intersects(lo, hi) for b in boxes)


def walk_evidenced(boxes, start, end, surfaces, body=True):
    """`TraversalLaw._walk_is_evidenced`, mirrored.  Returns (ok, reason,
    visited, path_len_m).  `body=False` is the support-only evidence
    `ShellValidator` uses at import; `body=True` adds the box body test."""
    grid = DIM["walk_grid"]
    step = DIM["max_vertical_step"] + 0.01
    fits = (lambda p: boxes_fit(boxes, p)) if body else None

    def stand_at(x, z, ref):
        fy = mesh_ground(boxes, (x, ref, z))
        if fy == -math.inf or abs(fy - ref) > step:
            return None
        if fits and not fits((x, fy, z)):
            return None
        return fy

    def seed(at, use_fits):
        y = stand_at(at[0], at[2], at[1]) if use_fits else _stand_nofit(boxes, at)
        if y is not None:
            return (at[0], at[2], y)
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                if dx == 0 and dz == 0:
                    continue
                nx, nz = at[0] + dx * grid, at[2] + dz * grid
                y = stand_at(nx, nz, at[1]) if use_fits else _stand_nofit(boxes, (nx, at[1], nz))
                if y is not None:
                    return (nx, nz, y)
        return None

    domain = _search_domain(start, end, surfaces)
    begin = seed(start, True)
    if begin is None:
        return False, "nowhere within a step of the start a player can stand", 0, 0.0
    landing = seed(end, False)
    if landing is None:
        return False, "no ground within a step of the end", 0, 0.0
    finish = landing[2]
    seen = {_cell(begin[0], begin[1], start, grid): 0}
    queue = [begin]
    visited = 0
    while queue:
        hx, hz, hy = queue.pop(0)
        if math.hypot(hx - end[0], hz - end[2]) <= grid and abs(hy - finish) <= DIM["max_vertical_step"]:
            return True, "", visited, seen[_cell(hx, hz, start, grid)] * grid
        visited += 1
        if visited > DIM["walk_max_nodes"]:
            return False, "no route proven within %d samples" % DIM["walk_max_nodes"], visited, 0.0
        here_d = seen[_cell(hx, hz, start, grid)]
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                if dx == 0 and dz == 0:
                    continue
                nx, nz = hx + dx * grid, hz + dz * grid
                key = _cell(nx, nz, start, grid)
                if key in seen or not _inside(nx, nz, domain):
                    continue
                seen[key] = here_d + 1
                ny = stand_at(nx, nz, hy)
                if ny is None or abs(ny - hy) > step:
                    continue
                queue.append((nx, nz, ny))
    return False, "no continuous supported route joins the ends", visited, 0.0


def _stand_nofit(boxes, at):
    fy = mesh_ground(boxes, at)
    if fy == -math.inf or abs(fy - at[1]) > DIM["max_vertical_step"] + 0.01:
        return None
    return fy


def _search_domain(start, end, surfaces):
    m = DIM["walk_domain_margin"]
    o = DIM["walk_open_domain"]
    rects = []
    for s in surfaces:
        cx, _, cz = s["center"]
        ex, ez = s["extent"]
        rects.append((cx - ex / 2 - m, cz - ez / 2 - m, cx + ex / 2 + m, cz + ez / 2 + m))
    lo = (min(start[0], end[0]) - o, min(start[2], end[2]) - o)
    hi = (max(start[0], end[0]) + o, max(start[2], end[2]) + o)
    near = (lo[0], lo[1], hi[0], hi[1])
    if not rects:
        return [near]
    clipped = []
    for r in rects:
        ix0, iz0 = max(r[0], near[0]), max(r[1], near[1])
        ix1, iz1 = min(r[2], near[2]), min(r[3], near[3])
        if ix1 > ix0 and iz1 > iz0:
            clipped.append((ix0, iz0, ix1, iz1))
    return clipped or [near]


def _inside(x, z, domain):
    return any(r[0] <= x <= r[2] and r[1] <= z <= r[3] for r in domain)


def _cell(x, z, anchor, grid):
    return (int(round((x - anchor[0]) / grid)), int(round((z - anchor[2]) / grid)))


# ---------------------------------------------------------------------------
# C(ii) stances (roomcollision.measure_stances / Placement.find, mirrored)
# ---------------------------------------------------------------------------

def stance_findings(boxes, surface):
    """Can this Surface keep its C(ii) promise?  Returns (usable, best_headroom)."""
    cx, top, cz = surface["center"]
    ex, ez = surface["extent"]
    stance = DIM["player_radius"] * 2.0
    if ex < stance - EPS or ez < stance - EPS:
        return 0, 0.0
    grid = DIM["placement_grid"]
    half = stance / 2.0
    span_x, span_z = max(ex - stance, 0.0), max(ez - stance, 0.0)
    reach, lift = DIM["audit_ground_reach"], DIM["audit_probe_lift"]
    tol, head = DIM["audit_height_tolerance"], DIM["headroom"]
    usable, best = 0, 0.0
    for xi in range(grid):
        px = cx - span_x / 2 + span_x * (xi / (grid - 1))
        for zi in range(grid):
            pz = cz - span_z / 2 + span_z * (zi / (grid - 1))
            seen = [b.top for b in boxes if b.overlaps_xz(px, pz, EPS)
                    and top - reach - EPS <= b.top <= top + lift + EPS]
            if not seen or abs(max(seen) - top) > tol:
                continue
            f0, f1 = top + DIM["placement_lift"], top + head
            over = [b.lo[1] for b in boxes
                    if _ov(px - half, px + half, b.lo[0], b.hi[0])
                    and _ov(pz - half, pz + half, b.lo[2], b.hi[2])
                    and _ov(f0, f1, b.lo[1], b.hi[1])]
            if over:
                best = max(best, min(over) - top)
                continue
            usable += 1
    return usable, best


def stance_spot(boxes, surface):
    """The clear stance nearest the rect centre, or None (`roomcollision.stance_spot`)."""
    cx, top, cz = surface["center"]
    ex, ez = surface["extent"]
    stance = DIM["player_radius"] * 2.0
    if ex < stance - EPS or ez < stance - EPS:
        return None
    grid = DIM["placement_grid"]
    half = stance / 2.0
    reach, lift = DIM["audit_ground_reach"], DIM["audit_probe_lift"]
    tol, head = DIM["audit_height_tolerance"], DIM["headroom"]

    def ok(px, pz):
        seen = [b.top for b in boxes if b.overlaps_xz(px, pz, EPS)
                and top - reach - EPS <= b.top <= top + lift + EPS]
        if not seen or abs(max(seen) - top) > tol:
            return False
        return not any(_ov(px - half, px + half, b.lo[0], b.hi[0])
                       and _ov(pz - half, pz + half, b.lo[2], b.hi[2])
                       and _ov(top + DIM["placement_lift"], top + head, b.lo[1], b.hi[1])
                       for b in boxes)
    if ok(cx, cz):
        return (cx, top, cz)
    span_x, span_z = max(ex - stance, 0.0), max(ez - stance, 0.0)
    best = None
    for xi in range(grid):
        px = cx - span_x / 2 + span_x * (xi / (grid - 1))
        for zi in range(grid):
            pz = cz - span_z / 2 + span_z * (zi / (grid - 1))
            if ok(px, pz):
                far = (px - cx) ** 2 + (pz - cz) ** 2
                if best is None or far < best[0] - EPS:
                    best = (far, px, pz)
    return None if best is None else (best[1], top, best[2])


def _ov(a0, a1, b0, b1):
    return a0 < b1 + EPS and a1 > b0 - EPS


# ---------------------------------------------------------------------------
# rails and launches (RailPath / LaunchSolver bounds, mirrored)
# ---------------------------------------------------------------------------

def bake_catmull_rom(points, interval=None):
    """Catmull-Rom through every point with Bezier handles a third of the
    neighbour tangent either side (`RailPath`), sampled every `interval`."""
    interval = DIM["rail_bake_interval"] if interval is None else interval
    pts = [tuple(p) for p in points]
    n = len(pts)
    if n < 2:
        return pts
    tangents = []
    for i in range(n):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n - 1)]
        tangents.append(tuple((b[k] - a[k]) / 2.0 for k in range(3)))
    out = []
    for i in range(n - 1):
        p0, p3 = pts[i], pts[i + 1]
        p1 = tuple(p0[k] + tangents[i][k] / 3.0 for k in range(3))
        p2 = tuple(p3[k] - tangents[i + 1][k] / 3.0 for k in range(3))
        seglen = math.dist(p0, p3)
        steps = max(2, int(math.ceil(seglen / interval)))
        for s in range(steps):
            t = s / steps
            u = 1 - t
            out.append(tuple(u ** 3 * p0[k] + 3 * u * u * t * p1[k] + 3 * u * t * t * p2[k] + t ** 3 * p3[k]
                             for k in range(3)))
    out.append(pts[-1])
    return out


def rail_findings(room, offer):
    pts = offer["points"]
    out = []
    if len(pts) < 2:
        return ["fewer than two points"]
    if len(pts) > DIM["caps"]["route_points"]:
        out.append("%d points over the cap of %d" % (len(pts), DIM["caps"]["route_points"]))
    for i in range(len(pts) - 1):
        run = math.dist(pts[i], pts[i + 1])
        if not DIM["rail_min_segment"] <= run <= DIM["rail_max_segment"]:
            out.append("segment %d is %.2f m; RailPath takes %.1f-%.1f" % (
                i, run, DIM["rail_min_segment"], DIM["rail_max_segment"]))
    baked = bake_catmull_rom(pts)
    worst_pitch = 0.0
    for i in range(len(baked) - 1):
        a, b = baked[i], baked[i + 1]
        flat = math.hypot(b[0] - a[0], b[2] - a[2])
        pitch = 90.0 if flat < 1e-6 else abs(math.degrees(math.atan2(b[1] - a[1], flat)))
        worst_pitch = max(worst_pitch, pitch)
    if worst_pitch > DIM["rail_max_pitch_deg"]:
        out.append("baked curve pitches %.1f deg; RailPath tops out at %.0f" % (
            worst_pitch, DIM["rail_max_pitch_deg"]))
    lo, hi = room.envelope()
    outside = sum(1 for p in baked if not all(lo[k] <= p[k] <= hi[k] for k in range(3)))
    if outside:
        out.append("%d of %d baked samples leave the envelope" % (outside, len(baked)))
    clearance = DIM["player_radius"] + 0.3
    hits = [p for p in baked if any(b.contains(p, clearance) for b in room.solids())]
    if hits:
        p = hits[0]
        out.append("%d of %d baked samples pass within %.1f m of geometry (first at %.1f, %.1f, %.1f)" % (
            len(hits), len(baked), clearance, p[0], p[1], p[2]))
    length = sum(math.dist(baked[i], baked[i + 1]) for i in range(len(baked) - 1))
    climb = max(p[1] for p in baked) - min(p[1] for p in baked)
    return out, {"length_m": round(length, 1), "worst_pitch_deg": round(worst_pitch, 1),
                 "baked_samples": len(baked), "height_range_m": round(climb, 1),
                 "control_points": len(pts)}


def launch_arc(src, dst):
    """`LaunchSolver`: apex `APEX_CLEARANCE` over the higher end, sampled."""
    g = DIM["gravity"]
    apex = max(src[1], dst[1]) + DIM["launch_apex_clearance"]
    vy = math.sqrt(2 * g * (apex - src[1]))
    t_up = vy / g
    t_down = math.sqrt(2 * (apex - dst[1]) / g)
    total = t_up + t_down
    dx, dz = dst[0] - src[0], dst[2] - src[2]
    n = DIM["launch_arc_samples"]
    pts = []
    for i in range(n + 1):
        t = total * i / n
        pts.append((src[0] + dx * t / total, src[1] + vy * t - 0.5 * g * t * t, src[2] + dz * t / total))
    return pts, total, apex


def launch_findings(room, source, target):
    out = []
    src = tuple(source["position"])
    dst = tuple(target["position"])
    span = math.dist(src, dst)
    if not 0.5 <= span <= DIM["launch_max_range"]:
        out.append("spans %.2f m; the solver takes 0.5-%.0f" % (span, DIM["launch_max_range"]))
    if target["radius"] < DIM["launch_min_landing_radius"] - EPS:
        out.append("landing radius %.2f under the %.1f minimum" % (
            target["radius"], DIM["launch_min_landing_radius"]))
    pts, flight, apex = launch_arc(src, dst)
    clearance = DIM["player_radius"]
    blocked = [p for p in pts[1:-1] if any(b.contains(p, clearance) for b in room.solids())]
    if blocked:
        p = blocked[0]
        out.append("arc is obstructed at (%.1f, %.1f, %.1f) (%d of %d samples)" % (
            p[0], p[1], p[2], len(blocked), len(pts)))
    ground = mesh_ground(room.solids(), (dst[0], dst[1] + 0.4, dst[2]), reach=1.2)
    if ground == -math.inf or abs(ground - dst[1]) > DIM["audit_height_tolerance"] + 0.4:
        out.append("landing has nothing under it at the declared height")
    elif not boxes_fit(room.solids(), (dst[0], ground, dst[2])):
        out.append("landing has no room for the player")
    return out, {"span_m": round(span, 1), "flight_s": round(flight, 2), "apex_y": round(apex, 1)}


def grapple_findings(room, offer):
    p = tuple(offer["position"])
    out = []
    solids = room.solids()
    if any(b.contains(p) for b in solids):
        out.append("anchor is inside solid geometry")
    swing = DIM["grapple_swing_room"]
    for i in range(1, 9):
        q = (p[0], p[1] - swing * i / 8.0, p[2])
        if any(b.contains(q, DIM["player_radius"]) for b in solids):
            out.append("less than %.1f m of clear air beneath the anchor" % swing)
            break
    ground = mesh_ground(solids, (p[0], p[1], p[2]), reach=DIM["grapple_drop"])
    if ground == -math.inf:
        out.append("no ground within %.0f m below to leave from" % DIM["grapple_drop"])
    return out


# ---------------------------------------------------------------------------
# preflight
# ---------------------------------------------------------------------------

def preflight(room):
    """Every reason the contract might refuse this room, as a report dict."""
    solids = room.solids()
    F = {"errors": [], "warnings": [], "info": {}}
    err, warn = F["errors"].append, F["warnings"].append
    caps = DIM["caps"]

    # caps and names
    for key, items in (("surfaces", room.surfaces), ("traversal", room.traversal),
                       ("offers", room.offers), ("sockets", room.sockets)):
        if len(items) > caps[key]:
            err("%d %s over the schema cap of %d" % (len(items), key, caps[key]))
    names = [s["name"] for s in room.surfaces]
    if len(set(names)) != len(names):
        err("duplicate surface names")
    snames = [s["name"] for s in room.sockets]
    if len(set(snames)) != len(snames):
        err("duplicate socket names")
    for s in room.sockets:
        if s.get("surface_id") and s["surface_id"] not in names:
            err("socket '%s' stands on undeclared surface '%s'" % (s["name"], s["surface_id"]))
    if not any(s["kind"] == "doorway" and s["name"] == "entry" for s in room.sockets):
        err("no entry doorway")
    if not any(s["kind"] == "doorway" and s["name"] == "exit" for s in room.sockets):
        err("no exit doorway")

    # envelope
    lo, hi = room.envelope()
    worst, count = 0.0, 0
    for p in room.parts:
        over = max(max(lo[k] - p.lo[k], p.hi[k] - hi[k]) for k in range(3))
        if over > 0.0:
            count += 1
            worst = max(worst, over)
    if count:
        err("%d part(s) reach up to %.2f m outside the envelope" % (count, worst))
    if any(p.lo[1] < -DIM["floor_allowance"] - EPS for p in room.parts):
        warn("geometry below -%.1f m: legal only inside the wall allowance" % DIM["floor_allowance"])

    # surfaces: span, support, C(ii) stances
    stance = DIM["player_radius"] * 2.0
    for s in room.surfaces:
        if min(s["extent"]) < stance - EPS:
            err("surface '%s' is narrower than the player" % s["name"])
            continue
        usable, best = stance_findings(solids, s)
        if usable == 0:
            err("surface '%s' at %.2f offers nowhere to stand (best headroom %.2f of %.1f)" % (
                s["name"], s["center"][1], best, DIM["headroom"]))
        elif usable < 9:
            F["info"].setdefault("thin_surfaces", {})[s["name"]] = usable

    # doorways are holes
    for s in room.sockets:
        if s["kind"] != "doorway":
            continue
        x, y, z = s["position"]
        w, h = s.get("width", 0.0), s.get("height", 0.0)
        if w < DIM["min_passable_width"] or h < DIM["min_passable_height"]:
            err("doorway '%s' is not passable (%.1f x %.1f)" % (s["name"], w, h))
        yaw = s["yaw"]
        for u in (-w / 2 + 0.1, 0.0, w / 2 - 0.1):
            for v in (0.3, h / 2, h - 0.2):
                if yaw in (0.0, 180.0):
                    q = (x + u, y + v, z)
                else:
                    q = (x, y + v, z + u)
                if any(b.contains(q) for b in solids):
                    err("doorway '%s' is blocked at %s" % (s["name"], [round(c, 1) for c in q]))
                    break

    # traversal
    walk_box_fail = []
    for t in room.traversal:
        a, b = tuple(t["start"]), tuple(t["end"])
        rise = b[1] - a[1]
        span = math.hypot(b[0] - a[0], b[2] - a[2])
        who = "traversal '%s'" % t["name"]
        mand = t["mandatory"]
        if t["kind"] == "drop":
            if rise > 0.01:
                err("%s is a drop and rises %.2f" % (who, rise))
            continue
        if t["kind"] in ("rise", "gap"):
            if t["kind"] == "rise" and rise > DIM["max_vertical_step"] + 0.01:
                (err if mand else warn)("%s rises %.2f; base kit tops out at %.1f" % (
                    who, rise, DIM["max_vertical_step"]))
            allowed = max_safe_gap(max(rise, 0.0))
            if span > allowed + 0.01:
                (err if mand else warn)("%s spans %.2f at %.2f rise; safe reach is %.1f" % (
                    who, span, rise, allowed))
            continue
        # walk: both evidences
        ok_box, why_box, n_box, _ = walk_evidenced(solids, a, b, room.surfaces, body=False)
        ok_body, why_body, n_body, _ = walk_evidenced(solids, a, b, room.surfaces, body=True)
        if not ok_box:
            (err if mand else warn)("%s: import evidence (hull boxes, support only): %s" % (who, why_box))
            walk_box_fail.append(t["name"])
        if not ok_body:
            (err if mand else warn)("%s: body evidence (boxes + player above step): %s" % (who, why_body))
    F["info"]["walks_unproven_at_import"] = walk_box_fail

    # offers
    targets = {o["name"]: o for o in room.offers if o["kind"] == "launch_target"}
    F["info"]["rails"] = {}
    F["info"]["launches"] = {}
    for o in room.offers:
        if o["kind"] == "rail_route":
            res = rail_findings(room, o)
            probs, stats = res if isinstance(res, tuple) else (res, {})
            for p in probs:
                err("rail '%s': %s" % (o["name"], p))
            F["info"]["rails"][o["name"]] = stats
        elif o["kind"] == "launch_source":
            tgt = targets.get(o.get("target"))
            if tgt is None:
                err("launch '%s' names a target that does not exist" % o["name"])
                continue
            probs, stats = launch_findings(room, o, tgt)
            for p in probs:
                err("launch '%s'->'%s': %s" % (o["name"], tgt["name"], p))
            F["info"]["launches"][o["name"]] = stats
        elif o["kind"] == "grapple_point":
            for p in grapple_findings(room, o):
                err("grapple '%s': %s" % (o["name"], p))

    # sightlines
    for who, eye, target in room.sightlines:
        blocked = None
        for i in range(401):
            t = i / 400.0
            p = tuple(eye[k] + (target[k] - eye[k]) * t for k in range(3))
            if any(b.contains(p) for b in solids):
                blocked = p
                break
        if blocked:
            err("sightline '%s' blocked at (%.1f, %.1f, %.1f)" % (who, *blocked))
        else:
            F["info"].setdefault("sightlines", {})[who] = round(math.dist(eye, target), 1)

    # nothing falls forever: the lowest floor top
    floors = [p.top for p in solids if p.role == "floor"]
    F["info"]["lowest_floor_y"] = round(min(floors), 2) if floors else None
    F["info"]["counts"] = {"parts": len(room.parts), "colliders": len(solids),
                           "surfaces": len(room.surfaces), "traversal": len(room.traversal),
                           "offers": len(room.offers), "sockets": len(room.sockets),
                           "volumes": len(room.volumes)}
    lo_, hi_, size = room.outer_size()
    F["info"]["outer_size_m"] = [round(v, 2) for v in size]
    F["info"]["declared_size_m"] = [round(v, 2) for v in room.declared_size()]
    F["info"]["interior_m"] = [room.W, room.H, room.D]
    F["info"]["interior_volume_m3"] = round(room.W * room.H * room.D)
    return F


# ---------------------------------------------------------------------------
# manifest
# ---------------------------------------------------------------------------

def manifest(room, glb_rel):
    lo, hi, outer = room.outer_size()
    size = room.declared_size()
    tris = 12 * len(room.parts)
    entry = {
        "anchor": "entrance",
        "path": glb_rel,
        "triangles": tris,
        "texel_density": None,
        "colliders": len(room.solids()),
        "size": [r3(size[0]), r3(size[2]), r3(size[1])],
        "size_godot": [r3(size[0]), r3(size[1]), r3(size[2])],
        "measured_box": [r3(v) for v in outer],
        "interior": [r3(room.W), r3(room.H), r3(room.D)],
        "bounds": [[r3(-size[0] / 2), -1.0, 0.0],
                   [r3(size[0]), r3(size[1] + 1.0), r3(size[2])]],
        "exit_offset": [r3(room.exit_xz[0]), r3(room.exit_y), r3(room.exit_xz[1])],
        "exit_yaw": r3(room.exit_yaw),
        "total_rise": r3(room.exit_y),
        "size_class": room.size_class,
        "semantic_tags": ["arena", "large"] + list(room.intent),
        "surfaces": room.surfaces,
        "sockets": room.sockets,
        "traversal": room.traversal,
        "offers": room.offers,
        "volumes": room.volumes,
        "graybox": True,
        "review": "pending",
    }
    if any(o["kind"] == "rail_route" for o in room.offers):
        entry["rail_span"] = r3(sum(
            sum(math.dist(o["points"][i], o["points"][i + 1]) for i in range(len(o["points"]) - 1))
            for o in room.offers if o["kind"] == "rail_route"))
    return {room.cid: entry}


# ---------------------------------------------------------------------------
# GLB
# ---------------------------------------------------------------------------

def _box_mesh(b):
    x0, y0, z0 = b.lo
    x1, y1, z1 = b.hi
    faces = [
        ((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (0, 0, 1)),
        ((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (0, 0, -1)),
        ((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (1, 0, 0)),
        ((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0), (-1, 0, 0)),
        ((x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0), (0, 1, 0)),
        ((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1), (0, -1, 0)),
    ]
    pos, nrm, idx = [], [], []
    for a, b_, c, d, n in faces:
        base = len(pos)
        pos += [a, b_, c, d]
        nrm += [n] * 4
        idx += [base, base + 1, base + 2, base, base + 2, base + 3]
    return pos, nrm, idx


def write_glb(room, path):
    """One visual mesh per role-material (merged), plus a collider twin node
    per solid part named `<part>-convcolonly` (Godot importer suffix)."""
    bufs = bytearray()
    views, accessors, meshes, nodes = [], [], [], []

    def push(data, target=None):
        while len(bufs) % 4:
            bufs.append(0)
        off = len(bufs)
        bufs.extend(data)
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            v["target"] = target
        views.append(v)
        return len(views) - 1

    def acc(view, ctype, count, atype, mn=None, mx=None):
        a = {"bufferView": view, "componentType": ctype, "count": count, "type": atype}
        if mn is not None:
            a["min"], a["max"] = mn, mx
        accessors.append(a)
        return len(accessors) - 1

    def prim(pos, nrm, idx, material):
        pdata = struct.pack("<%df" % (3 * len(pos)), *[c for p in pos for c in p])
        ndata = struct.pack("<%df" % (3 * len(nrm)), *[c for n in nrm for c in n])
        idata = struct.pack("<%dI" % len(idx), *idx)
        mn = [min(p[k] for p in pos) for k in range(3)]
        mx = [max(p[k] for p in pos) for k in range(3)]
        pa = acc(push(pdata, 34962), 5126, len(pos), "VEC3", mn, mx)
        na = acc(push(ndata, 34962), 5126, len(nrm), "VEC3")
        ia = acc(push(idata, 34963), 5125, len(idx), "SCALAR")
        return {"attributes": {"POSITION": pa, "NORMAL": na}, "indices": ia, "material": material}

    materials = []
    mat_index = {}
    for role in ROLES:
        mat_index[role] = len(materials)
        materials.append({"name": "gb_%s" % role,
                          "pbrMetallicRoughness": {"baseColorFactor": list(ROLE_RGBA[role]),
                                                   "metallicFactor": 0.0, "roughnessFactor": 0.9},
                          "doubleSided": False})
    materials.append({"name": "gb_collider", "pbrMetallicRoughness": {
        "baseColorFactor": [0.1, 0.9, 0.3, 0.25], "metallicFactor": 0.0, "roughnessFactor": 1.0},
        "alphaMode": "BLEND"})

    # visual: one primitive per role
    prims = []
    for role in ROLES:
        pos, nrm, idx = [], [], []
        for b in room.parts:
            if b.role != role:
                continue
            p, n, i = _box_mesh(b)
            base = len(pos)
            pos += p
            nrm += n
            idx += [base + k for k in i]
        if pos:
            prims.append(prim(pos, nrm, idx, mat_index[role]))
    meshes.append({"name": room.cid, "primitives": prims})
    nodes.append({"name": room.cid, "mesh": 0})
    for b in room.solids():
        p, n, i = _box_mesh(b)
        meshes.append({"name": "%s-convcolonly" % b.name, "primitives": [prim(p, n, i, len(materials) - 1)]})
        nodes.append({"name": "%s-convcolonly" % b.name, "mesh": len(meshes) - 1})

    gltf = {
        "asset": {"version": "2.0", "generator": "archipepsi gbkit (graybox, Godot space)"},
        "scene": 0,
        "scenes": [{"name": room.cid, "nodes": list(range(len(nodes)))}],
        "nodes": nodes, "meshes": meshes, "materials": materials,
        "accessors": accessors, "bufferViews": views,
        "buffers": [{"byteLength": len(bufs)}],
    }
    jdata = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(jdata) % 4:
        jdata += b" "
    while len(bufs) % 4:
        bufs.append(0)
    total = 12 + 8 + len(jdata) + 8 + len(bufs)
    with open(path, "wb") as fh:
        fh.write(struct.pack("<III", 0x46546C67, 2, total))
        fh.write(struct.pack("<II", len(jdata), 0x4E4F534A))
        fh.write(jdata)
        fh.write(struct.pack("<II", len(bufs), 0x004E4942))
        fh.write(bufs)
    return total


# ---------------------------------------------------------------------------
# SVG
# ---------------------------------------------------------------------------

def _svg_header(w, h, title):
    return ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" '
            'font-family="monospace" font-size="11">' % (w, h, w, h),
            '<rect width="100%%" height="100%%" fill="#f4f4f2"/>',
            '<text x="12" y="20" font-size="14" font-weight="bold">%s</text>' % title]


def _shade(role, top, hmax):
    if role == "trim":
        return "#d99a33"
    if role == "wall":
        return "#8d9096"
    if role == "ceiling":
        return "#5c5f66"
    t = 0.0 if hmax <= 0 else max(0.0, min(1.0, top / hmax))
    g = int(120 + 120 * t)
    return "#%02x%02x%02x" % (int(g * 0.9), g, int(g * 0.95))


def write_plan_svg(room, path, scale=6.0):
    pad = 60
    lo, hi, size = room.outer_size()
    W = int((hi[0] - lo[0]) * scale) + pad * 2
    Hh = int((hi[2] - lo[2]) * scale) + pad * 2 + 30
    sx = lambda x: pad + (x - lo[0]) * scale
    sz = lambda z: pad + 30 + (hi[2] - z) * scale
    out = _svg_header(W, Hh, "%s -- PLAN (x right, z up the page; entry at bottom)" % room.cid)
    hmax = max(p.top for p in room.parts)
    ordered = sorted([p for p in room.parts if p.role != "ceiling"], key=lambda p: p.top)
    for p in ordered:
        if p.role == "wall" and (p.hi[1] - p.lo[1]) > room.H * 0.8:
            fill, op = "#8d9096", 0.35
        else:
            fill, op = _shade(p.role, p.top, hmax), 0.85
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" fill-opacity="%.2f" stroke="#333" stroke-width="0.4"/>' % (
            sx(p.lo[0]), sz(p.hi[2]), (p.hi[0] - p.lo[0]) * scale, (p.hi[2] - p.lo[2]) * scale, fill, op))
    for s in room.surfaces:
        cx, y, cz = s["center"]
        ex, ez = s["extent"]
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="none" stroke="#1a6fb0" stroke-width="1.2" stroke-dasharray="4 2"/>' % (
            sx(cx - ex / 2), sz(cz + ez / 2), ex * scale, ez * scale))
        out.append('<text x="%.1f" y="%.1f" fill="#1a6fb0" font-size="10">%s +%.1f</text>' % (
            sx(cx - ex / 2) + 3, sz(cz + ez / 2) + 11, s["name"], y))
    for t in room.traversal:
        a, b = t["start"], t["end"]
        col = {"walk": "#2a9d3a", "rise": "#2a9d3a", "gap": "#d63a3a", "drop": "#8a3ad6"}[t["kind"]]
        dash = "" if t["mandatory"] else ' stroke-dasharray="3 3"'
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="2"%s/>' % (
            sx(a[0]), sz(a[2]), sx(b[0]), sz(b[2]), col, dash))
    for o in room.offers:
        if o["kind"] == "rail_route":
            pts = bake_catmull_rom(o["points"], 1.0)
            d = " ".join("%.1f,%.1f" % (sx(p[0]), sz(p[2])) for p in pts)
            out.append('<polyline points="%s" fill="none" stroke="#e0402b" stroke-width="2.5" stroke-opacity="0.9"/>' % d)
            p0 = o["points"][0]
            out.append('<text x="%.1f" y="%.1f" fill="#e0402b" font-size="10">rail %s</text>' % (sx(p0[0]), sz(p0[2]) - 4, o["name"]))
        elif o["kind"] in ("launch_source", "launch_target", "grapple_point"):
            x, y, z = o["position"]
            r = o["radius"] * scale
            col = {"launch_source": "#f0a020", "launch_target": "#f0a020", "grapple_point": "#8a3ad6"}[o["kind"]]
            out.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" fill-opacity="0.25" stroke="%s"/>' % (sx(x), sz(z), r, col, col))
            out.append('<text x="%.1f" y="%.1f" fill="%s" font-size="10">%s +%.0f</text>' % (sx(x) + r + 2, sz(z) + 4, col, o["name"], y))
    for s in room.sockets:
        x, y, z = s["position"]
        col = {"doorway": "#000", "enemy_high": "#b02020", "cover": "#7a5a20", "reactive": "#e05a00"}.get(s["kind"], "#555")
        out.append('<circle cx="%.1f" cy="%.1f" r="3" fill="%s"/>' % (sx(x), sz(z), col))
        out.append('<text x="%.1f" y="%.1f" font-size="9" fill="%s">%s</text>' % (sx(x) + 4, sz(z) - 3, col, s["name"]))
    out.append('<line x1="%d" y1="%d" x2="%.1f" y2="%d" stroke="#000" stroke-width="2"/>' % (pad, Hh - 15, pad + 10 * scale, Hh - 15))
    out.append('<text x="%d" y="%d">10 m</text>' % (pad + 10 * scale + 6, Hh - 11))
    out.append("</svg>")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))


def write_section_svg(room, path, axis="z", scale=6.0):
    """A projected section: `axis`='z' looks along x (z across, y up);
    'x' looks along z (x across, y up)."""
    pad = 60
    lo, hi, size = room.outer_size()
    a0, a1 = (lo[2], hi[2]) if axis == "z" else (lo[0], hi[0])
    W = int((a1 - a0) * scale) + pad * 2
    Hh = int((hi[1] - lo[1]) * scale) + pad * 2 + 30
    sa = lambda v: pad + (v - a0) * scale
    sy = lambda y: pad + 30 + (hi[1] - y) * scale
    out = _svg_header(W, Hh, "%s -- SECTION (%s across, y up)" % (room.cid, "z" if axis == "z" else "x"))
    hmax = max(p.top for p in room.parts)
    for p in sorted(room.parts, key=lambda p: -(p.hi[0] - p.lo[0]) * (p.hi[2] - p.lo[2])):
        u0, u1 = (p.lo[2], p.hi[2]) if axis == "z" else (p.lo[0], p.hi[0])
        depth_frac = 1.0
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" fill-opacity="%.2f" stroke="#333" stroke-width="0.4"/>' % (
            sa(u0), sy(p.hi[1]), (u1 - u0) * scale, (p.hi[1] - p.lo[1]) * scale,
            _shade(p.role, p.top, hmax), 0.45 if p.role == "wall" else 0.8 * depth_frac))
    for o in room.offers:
        if o["kind"] == "rail_route":
            pts = bake_catmull_rom(o["points"], 1.0)
            d = " ".join("%.1f,%.1f" % (sa(p[2] if axis == "z" else p[0]), sy(p[1])) for p in pts)
            out.append('<polyline points="%s" fill="none" stroke="#e0402b" stroke-width="2.5"/>' % d)
        elif o["kind"] == "launch_source":
            tgt = next((t for t in room.offers if t["kind"] == "launch_target" and t["name"] == o["target"]), None)
            if tgt:
                pts, _, _ = launch_arc(tuple(o["position"]), tuple(tgt["position"]))
                d = " ".join("%.1f,%.1f" % (sa(p[2] if axis == "z" else p[0]), sy(p[1])) for p in pts)
                out.append('<polyline points="%s" fill="none" stroke="#f0a020" stroke-width="2" stroke-dasharray="5 3"/>' % d)
    for y in range(0, int(hi[1]) + 1, 5):
        out.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#999" stroke-width="0.5" stroke-dasharray="2 4"/>' % (pad, sy(y), W - pad, sy(y)))
        out.append('<text x="4" y="%.1f" font-size="9" fill="#666">%d</text>' % (sy(y) + 3, y))
    out.append("</svg>")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))
