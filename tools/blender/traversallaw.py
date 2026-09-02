"""Production's `TraversalLaw`, mirrored source-side as a build gate.

    import traversallaw
    traversallaw.assert_declared(colliders, entry, cid)

WHY A MIRROR. `shell_hall_transit` shipped three traversal declarations
that Production's gate refused, and the whole round trip -- export, wrap,
integrate, audit, report, repair -- happened because Art had no way to
ask the question at build time. `roomcollision.measure_stances` already
proved the shape of the answer: mirror the authority's rule against the
geometry the build just placed, reproduce its known-bad findings FIRST,
and only then make it a gate.

WHICH EVIDENCE THIS IS, AND WHICH IT IS NOT. Production runs one law over
two evidences. `ShellValidator` floods the collision hulls with
SUPPORT-ONLY evidence at import; `RoomAudit` floods with the real capsule
in a live tree and is the final authority. This module mirrors the FIRST
one -- collider boxes, support only -- because that is the evidence a
Blender build actually has. It is therefore honestly weaker than the
authority, and a shell that passes here can still be refused by
`RoomAudit` for a pinch a box test cannot see. It is not a second
opinion and it never overrides one.

WHAT THE LAW SAYS, at `b37fe07`:

  gap    the player leaves the ground. Bounded by `max_safe_gap(rise)`.
  rise   the player steps up. Bounded by `MAX_VERTICAL_STEP`.
  drop   the player falls. Bounded by nothing.
  walk   the player never leaves the ground, so SPAN is not the question
         and EVIDENCE is: a bounded flood over player-radius samples,
         where a node exists only where geometry supports a stance and an
         edge exists only between neighbours within one step.

THE DECLARED RECTANGLES BOUND THE SEARCH AND PROVE NOTHING. That is the
sentence that matters for authoring, and it is the opposite of what the
intermediate rule at `93ddc60` implied. A ramp does NOT need one declared
Surface per metre of rise; it needs its plan footprint to fall inside the
search domain, and the geometry supplies every height in between.
"""

from __future__ import annotations

import math
import os
import re
import subprocess

#: Production's ref, for the constants. Read rather than retyped: the
#: same rule `verify_content_pack.sh` follows, for the same reason.
PROD_REF = os.environ.get(
    "PROD_REF", "origin/claude/archipepsi-echoes-continuation-b1adno")

#: `TraversalLaw`, verbatim.
WALK_GRID = 0.4          # = Constants.PLAYER_RADIUS
DOMAIN_MARGIN = 1.5
OPEN_DOMAIN = 8.0
MAX_WITNESS_NODES = 8000
AS_BUILT_SLACK = 0.01
GROUND_REACH = 2.0       # `mesh_ground`'s default `reach`

_CONSTANTS: dict[str, float] = {}


def _constants() -> dict[str, float]:
    """Production's own numbers, read from Production's own file.

    Retyping `MAX_VERTICAL_STEP` here would make this mirror agree with a
    remembered engine rather than the running one, which is the failure
    the harness transform in `verify_content_pack.sh` exists to avoid.
    """
    if _CONSTANTS:
        return _CONSTANTS
    try:
        src = subprocess.run(
            ["git", "show", "%s:godot/scripts/autoload/constants.gd" % PROD_REF],
            capture_output=True, text=True, check=True,
            cwd=os.path.dirname(os.path.abspath(__file__))).stdout
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        raise AssertionError(
            "traversallaw: cannot read Production's constants from %s. This "
            "mirror refuses to run on remembered numbers -- set PROD_REF or "
            "fetch the branch." % PROD_REF) from exc
    for name in ("MAX_VERTICAL_STEP", "PLAYER_RADIUS", "GRAVITY",
                 "GRAVITY_MULT_MAX", "JUMP_VELOCITY", "WALK_SPEED",
                 "SPEED_MULT_MIN", "SAFE_GAP_MARGIN"):
        hit = re.search(r"^const %s\s*(?::\s*\w+\s*)?:?=\s*([-0-9.eE]+)" % name,
                        src, re.M)
        if hit is None:
            raise AssertionError(
                "traversallaw: Production's constants.gd does not define %s"
                % name)
        _CONSTANTS[name] = float(hit.group(1))
    return _CONSTANTS


def max_safe_gap(vertical_step: float = 0.0) -> float:
    """`Constants.max_safe_gap`, arithmetic for arithmetic."""
    c = _constants()
    g = c["GRAVITY"] * c["GRAVITY_MULT_MAX"]
    disc = c["JUMP_VELOCITY"] ** 2 - 2.0 * g * vertical_step
    if disc < 0.0:
        return 0.0
    reach = (c["WALK_SPEED"] * c["SPEED_MULT_MIN"]
             * (c["JUMP_VELOCITY"] + math.sqrt(disc)) / g)
    return math.floor(reach * c["SAFE_GAP_MARGIN"] * 10.0) / 10.0


# ---------------------------------------------------------------- evidence

def godot_boxes(colliders, world_box):
    """The collision hulls as Godot-space (min, max) pairs.

    `world_box` is `roomcollision._world_box`, so this reads the boxes
    the build actually placed rather than re-deriving them. Blender
    (x, y, z) -> Godot (x, z, -y), so the y and z extents swap and z
    negates, which reverses min and max on that axis.
    """
    out = []
    for c in colliders:
        lo, hi = world_box(c)
        out.append(((lo[0], lo[2], -hi[1]), (hi[0], hi[2], -lo[1])))
    return out


def mesh_ground(boxes, at, reach=GROUND_REACH):
    """`TraversalLaw.mesh_ground`: the highest box top a player at `at`
    could be standing on, or -inf."""
    grip = _constants()["PLAYER_RADIUS"]
    step = _constants()["MAX_VERTICAL_STEP"]
    best = -math.inf
    ax, ay, az = at
    for lo, hi in boxes:
        if ax < lo[0] - grip or ax > hi[0] + grip:
            continue
        if az < lo[2] - grip or az > hi[2] + grip:
            continue
        top = hi[1]
        if top > ay + step:
            continue
        if top < ay - reach:
            continue
        best = max(best, top)
    return best


# -------------------------------------------------------------------- walk

def _stand_at(boxes, x, z, reference):
    floor_y = mesh_ground(boxes, (x, reference, z))
    if floor_y == -math.inf:
        return -math.inf
    if abs(floor_y - reference) > _constants()["MAX_VERTICAL_STEP"] \
            + AS_BUILT_SLACK:
        return -math.inf
    return floor_y


def _seed(boxes, at):
    """Standable ground within one cell of `at`, or None.

    A walk's endpoint sits at the lip of a surface by nature, so the
    endpoint's own column may be the seam and its neighbour the floor.
    """
    x, y, z = at
    here = _stand_at(boxes, x, z, y)
    if here != -math.inf:
        return (x, z, here)
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            if dx == 0 and dz == 0:
                continue
            nx, nz = x + dx * WALK_GRID, z + dz * WALK_GRID
            ny = _stand_at(boxes, nx, nz, y)
            if ny != -math.inf:
                return (nx, nz, ny)
    return None


def _search_domain(start, end, surfaces):
    """The rects, grown, clipped to the walk's own neighbourhood.

    Bounded twice and both are BOUNDS: the flood stays inside what the
    room declares AND within reach of the walk being proven.
    """
    rects = []
    for s in surfaces:
        px, _, pz = s["position"]
        ex, _, ez = s["extent"]
        rects.append((px - ex / 2.0 - DOMAIN_MARGIN, pz - ez / 2.0 - DOMAIN_MARGIN,
                      px + ex / 2.0 + DOMAIN_MARGIN, pz + ez / 2.0 + DOMAIN_MARGIN))
    lox, loz = min(start[0], end[0]), min(start[2], end[2])
    hix, hiz = max(start[0], end[0]), max(start[2], end[2])
    near = (lox - OPEN_DOMAIN, loz - OPEN_DOMAIN,
            hix + OPEN_DOMAIN, hiz + OPEN_DOMAIN)
    if not rects:
        return [near]
    clipped = []
    for r in rects:
        x0, z0 = max(r[0], near[0]), max(r[1], near[1])
        x1, z1 = min(r[2], near[2]), min(r[3], near[3])
        if x1 > x0 and z1 > z0:
            clipped.append((x0, z0, x1, z1))
    return clipped or [near]


def _inside(x, z, domain):
    return any(r[0] <= x <= r[2] and r[1] <= z <= r[3] for r in domain)


def walk_evidence(boxes, start, end, surfaces, who="walk"):
    """`_walk_is_evidenced`. Empty means proven; otherwise one reason.

    Also returns the flood so a caller can say how big the search was --
    a route proven at 7900 of 8000 nodes is one push from failing closed.
    """
    step = _constants()["MAX_VERTICAL_STEP"]
    domain = _search_domain(start, end, surfaces)
    begin = _seed(boxes, start)
    if begin is None:
        return (["%s: is declared a walk and there is nowhere within a step "
                 "of its start at %s a player can stand"
                 % (who, _fmt(start))], 0)
    landing = _seed(boxes, end)
    if landing is None:
        return (["%s: is declared a walk and there is no ground within a "
                 "step of its end at %s" % (who, _fmt(end))], 0)
    finish = landing[2]

    seen = {_cell(begin[0], begin[1], start)}
    queue = [begin]
    visited = 0
    while queue:
        hx, hz, hy = queue.pop(0)
        if math.hypot(hx - end[0], hz - end[2]) <= WALK_GRID \
                and abs(hy - finish) <= step:
            return ([], visited)
        visited += 1
        if visited > MAX_WITNESS_NODES:
            return (["%s: is declared a walk and no route could be proven "
                     "within %d samples; it is too sprawling to verify, "
                     "not thereby safe" % (who, MAX_WITNESS_NODES)], visited)
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                if dx == 0 and dz == 0:
                    continue
                nx, nz = hx + dx * WALK_GRID, hz + dz * WALK_GRID
                key = _cell(nx, nz, start)
                if key in seen or not _inside(nx, nz, domain):
                    continue
                seen.add(key)
                ny = _stand_at(boxes, nx, nz, hy)
                if ny == -math.inf:
                    continue
                if abs(ny - hy) > step + AS_BUILT_SLACK:
                    continue
                queue.append((nx, nz, ny))
    return (["%s: is declared a walk, and no continuous supported route "
             "joins %s to %s -- the ground the declarations describe does "
             "not connect them" % (who, _fmt(start), _fmt(end))], visited)


def _cell(x, z, origin):
    return (round((x - origin[0]) / WALK_GRID),
            round((z - origin[2]) / WALK_GRID))


def _fmt(v):
    return "(%.2f, %.2f, %.2f)" % tuple(v)


# ------------------------------------------------------------- the whole law

def violations(boxes, kind, start, end, surfaces, who):
    """Every way this MEASURED movement is outside what its kind claims."""
    step = _constants()["MAX_VERTICAL_STEP"]
    rise = end[1] - start[1]
    span = math.hypot(end[0] - start[0], end[2] - start[2])
    out = []
    if kind == "rise":
        if rise > step + AS_BUILT_SLACK:
            out.append("%s: rises %.2f m as a 'rise'; the base kit tops out "
                       "at %.2f" % (who, rise, step))
    if kind in ("gap", "rise"):
        allowed = max_safe_gap(max(rise, 0.0))
        if span > allowed + AS_BUILT_SLACK:
            out.append("%s: spans %.2f m at a %.2f m rise; the base kit's "
                       "safe reach there is %.2f" % (who, span, rise, allowed))
    elif kind == "walk":
        problems, visited = walk_evidence(boxes, start, end, surfaces, who)
        out.extend(problems)
        if not problems and visited > MAX_WITNESS_NODES * 0.75:
            out.append("%s: proven, but at %d of %d samples -- close to the "
                       "cap that fails closed" % (who, visited,
                                                  MAX_WITNESS_NODES))
    return out


def measure(colliders, entry, world_box):
    """Every mandatory segment, against the law. A list of findings."""
    boxes = godot_boxes(colliders, world_box)
    surfaces = [{"position": (s["center"][0], s["center"][1], s["center"][2]),
                 "extent": (s["extent"][0], 0.0, s["extent"][1])}
                for s in entry.get("surfaces", [])]
    out = []
    for seg in entry.get("traversal", []):
        if not seg.get("mandatory", True):
            continue
        out.extend(violations(boxes, seg["kind"], seg["start"], seg["end"],
                              surfaces, "'%s'" % seg["name"]))
    return out


def assert_declared(colliders, entry, cid, world_box):
    """Refuse to export a shell whose mandatory traversal is not evidenced."""
    found = measure(colliders, entry, world_box)
    if found:
        raise AssertionError(
            "%s: %d traversal declaration(s) the law refuses:\n  %s"
            % (cid, len(found), "\n  ".join(found)))
    return len(entry.get("traversal", []))


def reclassify(colliders, entry, world_box, cid):
    """Re-derive a level segment's kind from the EVIDENCE, not the rise.

    `roomcontract.traversal_from_stones` reads the kind off the rise
    alone: level means `walk`. That is right almost everywhere and wrong
    where two decks at the same height do not actually meet --
    `shell_tower_spiral`'s `platform_8_to_deck`, which Production probed
    at `b37fe07` and found a real void between the two decks. Crossing it
    is a hop, and the old law could not see it because it never asked the
    geometry.

    So the geometry is asked. A `walk` the flood cannot prove becomes a
    `gap` IF the crossing is inside the base kit's reach; if it is not,
    nothing is relabelled and the build fails, because an unprovable
    walk that is also too far to jump is a defect rather than a
    mislabel. Deriving the correction is the point: hand-editing one
    word in one manifest would leave the next shell with the same bug.
    """
    boxes = godot_boxes(colliders, world_box)
    surfaces = [{"position": (s["center"][0], s["center"][1], s["center"][2]),
                 "extent": (s["extent"][0], 0.0, s["extent"][1])}
                for s in entry.get("surfaces", [])]
    changed = []
    for seg in entry.get("traversal", []):
        if seg["kind"] != "walk":
            continue
        problems, _ = walk_evidence(boxes, seg["start"], seg["end"],
                                    surfaces, "'%s'" % seg["name"])
        if not problems:
            continue
        rise = seg["end"][1] - seg["start"][1]
        span = math.hypot(seg["end"][0] - seg["start"][0],
                          seg["end"][2] - seg["start"][2])
        allowed = max_safe_gap(max(rise, 0.0))
        if span > allowed + AS_BUILT_SLACK:
            raise AssertionError(
                "%s: '%s' is declared a walk, the geometry does not "
                "connect it, and at %.2f m it is past the %.2f m the base "
                "kit can jump. That is a hole, not a mislabel."
                % (cid, seg["name"], span, allowed))
        seg["kind"] = "gap"
        changed.append("%s: '%s' walk -> gap (%.2f m across, reach %.2f)"
                       % (cid, seg["name"], span, allowed))
    return changed
