"""Do the declared movement offers survive the room's real collision?

    python3 tools/content/measure_offers.py [shell_id ...]

WHY THIS EXISTS. `RoomAudit` never reads `offers` -- its checks cover
surfaces, sockets, arrivals, openings, `player_entry`, traversal and
bounds, and no offer kind is among them. The rules that WOULD catch a bad
offer live in `MovementPackage`, `RailPath` and `LaunchSolver`, and the
independent audit at `802732d` established that those have never been
shown a collider: all eight `MovementPackage.consume` call sites in the
repository pass constant stubs, and the string
`PhysicsDirectSpaceState3D` does not occur in the driver at all.

> The rules and the geometry have never been in the same room.

This is the art-side half of putting them there. It reads the SHIPPED
`.glb` collision, replays Production's own arithmetic over it, and
refuses at build time what would otherwise be found at an integration --
or, worse, not found at all.

WHAT IT IS NOT. Production owns the canonical `clear` / `supported`
binding and remains the authority. This measures the same geometry with
the same constants, read from Production's own files rather than
retyped, and is deliberately CONSERVATIVE wherever the two could differ
(see `Hull.depth`).

THE FOUR THINGS IT MEASURES.

  * **Convexity and open bores.** `-convcolonly` imports as the convex
    HULL of a node's vertices, so a non-convex collider ships collision
    the art does not have. Checked per node, plus an explicit test that
    the plenum's collar bores admit a body.
  * **Rails, on the BAKED curve.** A rail is authored as sparse control
    points and ridden as a Catmull-Rom spline. The curve cuts corners the
    polyline does not, so measuring control points proves nothing: the
    plenum's 12 points all sat 3.8 cm OUTSIDE the collar rings and the
    smoothed curve dipped 16.6 cm inside them.
  * **Launch arcs**, solved by `LaunchSolver`'s own closed form and
    sampled against the room.
  * **Grapple anchors**, continuously. Not on Production's current 2 m
    stride: the audit measured that stride producing 186 false refusals
    AND 49 false acceptances over 2 268 candidate anchors, from
    different causes. A stride cannot answer a continuous question, so
    this sweeps.
"""

from __future__ import annotations

import json
import math
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import measure_flights                                       # noqa: E402

ROOT = measure_flights.ROOT
SHELLS = measure_flights.SHELLS

PROD_REF = os.environ.get(
    "PROD_REF", "origin/claude/archipepsi-echoes-continuation-b1adno")

_CACHE: dict[str, float] = {}


def _consts(path, names):
    """Production's own numbers, read from Production's own files."""
    missing = [n for n in names if n not in _CACHE]
    if not missing:
        return {n: _CACHE[n] for n in names}
    try:
        src = subprocess.run(["git", "show", "%s:%s" % (PROD_REF, path)],
                             capture_output=True, text=True, check=True,
                             cwd=ROOT).stdout
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        raise AssertionError(
            "measure_offers: cannot read %s from %s. This mirror refuses to "
            "run on remembered numbers -- set PROD_REF or fetch the branch."
            % (path, PROD_REF)) from exc
    for name in missing:
        hit = re.search(r"^const %s\s*(?::\s*\w+\s*)?:?=\s*([-0-9.eE]+)"
                        % name, src, re.M)
        if hit is None:
            raise AssertionError("measure_offers: %s does not define %s"
                                 % (path, name))
        _CACHE[name] = float(hit.group(1))
    return {n: _CACHE[n] for n in names}


def rules():
    """Every engine constant this module measures against, in one place."""
    out = {}
    out.update(_consts("godot/scripts/autoload/constants.gd",
                       ("PLAYER_RADIUS", "PLAYER_HEIGHT", "GRAVITY")))
    out.update(_consts("godot/scripts/gameplay/movement_package.gd",
                       ("SWING_ROOM", "GRAPPLE_DROP")))
    out.update(_consts("godot/scripts/generation/affordance_features.gd",
                       ("RAIL_BEAM_THICKNESS",)))
    out.update(_consts("godot/scripts/gameplay/launch_solver.gd",
                       ("APEX_CLEARANCE", "ARC_SAMPLES", "MAX_RANGE",
                        "MIN_LANDING_RADIUS")))
    out.update(_consts("godot/scripts/gameplay/rail_path.gd",
                       ("BAKE_INTERVAL", "TENSION")))
    return out


#: How finely the baked curve and the swing column are swept, in metres.
#: `BAKE_INTERVAL` is 0.2; this is an order finer, because the question
#: is where the curve's DEEPEST point goes and a coarse walk can step
#: over it.
SWEEP = 0.02

#: Clearance a repaired rail must keep beyond its own half-beam. Not a
#: rule of Production's -- an art-side margin, so that a route passing by
#: a millimetre is treated as the accident it is.
RAIL_MARGIN = 0.15


#: Launch arcs this branch has MEASURED, RAISED and deliberately NOT
#: repaired, with the colliders each one fails against.
#:
#: EMPTY, AND THAT IS THE POINT OF KEEPING IT. It carried two entries
#: for one day: the hall's and the span's flights each clipped the
#: underside of the platform they land on, by 0.08 m, and neither was in
#: the audit that repair answered. The owner's ruling was to keep both
#: launches and move both pads the least that clears them, so both were
#: repaired and both lines came out. A ledger nobody empties is a list
#: of things nobody is going to fix.
#:
#: THIS IS NOT A SILENCER, AND IT IS NOT A SKIP. An entry must still be
#: found, and found to be exactly what it says, or the gate fails. A
#: listed arc that comes back clean fails it too -- that is the state
#: this file just went through, and taking the lines out is what a
#: repair looks like from here. A listed offer that no longer exists
#: fails it as well, because a finding waiting on a ruling has to still
#: have a subject.
#:
#: What belongs here: a measured finding that is REAL, outside the brief
#: being worked, and whose repair is somebody else's call -- moving art
#: the owner has passed, or a decision about a route. Not a finding that
#: is merely inconvenient. `tools/content/sabotage_offers.py` proves all
#: four behaviours against a finding it synthesises, so the mechanism
#: stays tested while the ledger is empty.
RAISED = {}


# --------------------------------------------------------------------
# convex colliders
# --------------------------------------------------------------------

class Hull(object):
    """One `-convcolonly` collider, as the half-spaces Godot will use.

    Every shipped collider is convex (`roomcollision.assert_convex`
    refuses anything else at build time), so the imported
    `ConvexPolygonShape3D` IS this mesh and these planes are the shape.
    """

    def __init__(self, name, tris):
        self.name = name
        pts = [p for t in tris for p in t]
        self.verts = sorted(set(tuple(round(c, 6) for c in p) for p in pts))
        n = float(len(self.verts))
        self.centre = tuple(sum(v[i] for v in self.verts) / n
                            for i in range(3))
        self.lo = tuple(min(v[i] for v in self.verts) for i in range(3))
        self.hi = tuple(max(v[i] for v in self.verts) for i in range(3))
        seen, self.planes = set(), []
        for a, b, c in tris:
            u = tuple(b[i] - a[i] for i in range(3))
            v = tuple(c[i] - a[i] for i in range(3))
            nx = u[1] * v[2] - u[2] * v[1]
            ny = u[2] * v[0] - u[0] * v[2]
            nz = u[0] * v[1] - u[1] * v[0]
            ln = math.sqrt(nx * nx + ny * ny + nz * nz)
            if ln < 1e-12:
                continue
            nrm = (nx / ln, ny / ln, nz / ln)
            d = sum(nrm[i] * a[i] for i in range(3))
            # ORIENT BY THE CENTROID, not by the winding. A hull's
            # centroid is inside it, so this cannot be fooled by an
            # exporter's triangle order.
            if sum(nrm[i] * self.centre[i] for i in range(3)) > d:
                nrm, d = tuple(-x for x in nrm), -d
            key = tuple(round(x, 5) for x in nrm) + (round(d, 5),)
            if key not in seen:
                seen.add(key)
                self.planes.append((nrm, d))

    def depth(self, p):
        """Positive INSIDE (true penetration), negative outside.

        Outside, the magnitude is the largest plane distance, which is a
        LOWER bound on the true distance to the hull -- so a clearance
        this reports is a clearance the geometry really has, and the
        error is always in the safe direction. Inside, it is exact: the
        distance to the nearest face.
        """
        return -max(sum(n[i] * p[i] for i in range(3)) - d
                    for n, d in self.planes)

    def ray_down(self, p, reach):
        """Where a ray dropped from `p` first meets this hull, or None."""
        t0, t1 = 0.0, reach
        for n, d in self.planes:
            denom = -n[1]
            num = d - sum(n[i] * p[i] for i in range(3))
            if abs(denom) < 1e-12:
                if num < 0.0:
                    return None
                continue
            t = num / denom
            if denom > 0.0:
                t1 = min(t1, t)
            else:
                t0 = max(t0, t)
            if t0 > t1:
                return None
        return p[1] - t0


def hulls(path):
    """Every collider in a shipped shell, as convex half-space sets."""
    return [Hull(name, tris)
            for name, tris in sorted(measure_flights.triangles(path).items())]


def nonconvex(path):
    """Collider nodes whose own mesh is not its convex hull.

    The importer condition, restated: a vertex outside one of the mesh's
    own face planes means the hull is bigger than the mesh, and the
    difference ships as collision with nothing to see.
    """
    bad = []
    for name, tris in sorted(measure_flights.triangles(path).items()):
        h = Hull(name, tris)
        worst = max(max(sum(n[i] * v[i] for i in range(3)) - d
                        for n, d in h.planes) for v in h.verts)
        if worst > 1e-4:
            bad.append((name, worst))
    return bad


# --------------------------------------------------------------------
# the body
# --------------------------------------------------------------------

def clearance(hs, p, ignore=()):
    """(distance to the nearest solid, which hull), conservative."""
    best, who = float("inf"), None
    for h in hs:
        if h.name in ignore:
            continue
        d = -h.depth(p)
        if d < best:
            best, who = d, h.name
    return best, who


def buried(hs, p):
    """The hull containing `p`, or None."""
    for h in hs:
        if h.depth(p) >= 0.0:
            return h.name
    return None


def body_fits(hs, foot, rules_=None):
    """Does the player's capsule stand with its feet at `foot`?

    Swept, not sampled at the ends: a column of spheres from ankle to
    crown at `SWEEP`, each of which must clear every hull by the player
    radius. Conservative -- `Hull.depth` understates clearance outside --
    so a `True` here is a fit the room really has.
    """
    r = (rules_ or rules())
    radius, height = r["PLAYER_RADIUS"], r["PLAYER_HEIGHT"]
    y = foot[1] + radius
    top = foot[1] + height - radius
    while y <= top + 1e-9:
        far, _ = clearance(hs, (foot[0], y, foot[2]))
        # A HAIR OF TOLERANCE, and it is the owner's launch ruling that
        # needs it: a foot point ON a floor puts the lowest sphere's
        # centre exactly `radius` above the face, which is the 0.000 m
        # contact the audit calls an engine coin toss. Standing on the
        # ground must not be a coin toss.
        if far < radius - 1e-4:
            return False
        y += SWEEP
    return True


def ground_below(hs, p, reach):
    """The height of the first solid under `p`, or None. Continuous.

    No stride and no window: the audit measured Production's 2 m stride
    with a 1.5 m window leaving 0.5 m blind bands -- 25 % of all floor
    depths -- which refused three of the span's real anchors. A ray
    answers the question the stride approximates.
    """
    best = None
    for h in hs:
        if h.depth(p) >= 0.0:
            continue                      # standing in it, not above it
        hit = h.ray_down(p, reach)
        if hit is not None and (best is None or hit > best):
            best = hit
    return best


# --------------------------------------------------------------------
# rails
# --------------------------------------------------------------------

def baked(points, step=SWEEP):
    """`RailPath.from_points`, sampled. The curve, not the polyline.

    Godot's `Curve3D` interpolates each span as a cubic Bezier whose
    handles are the Catmull-Rom tangents `(P[i+1]-P[i-1])/2 * TENSION`,
    a third out either side -- which is exactly what `from_points` sets.
    """
    tension = rules()["TENSION"]
    n = len(points)
    tang = []
    for i in range(n):
        before = points[max(i - 1, 0)]
        after = points[min(i + 1, n - 1)]
        tang.append(tuple((after[k] - before[k]) * 0.5 * tension
                          for k in range(3)))
    out = []
    for i in range(n - 1):
        p0, p3 = points[i], points[i + 1]
        p1 = tuple(p0[k] + tang[i][k] / 3.0 for k in range(3))
        p2 = tuple(p3[k] - tang[i + 1][k] / 3.0 for k in range(3))
        span = math.dist(p0, p3) or 1.0
        steps = max(2, int(span / step) + 1)
        for s in range(steps + 1):
            t = s / float(steps)
            m = 1.0 - t
            out.append(tuple(
                m * m * m * p0[k] + 3 * m * m * t * p1[k]
                + 3 * m * t * t * p2[k] + t * t * t * p3[k]
                for k in range(3)))
    return out


def rail_conflicts(hs, points, margin=RAIL_MARGIN):
    """Where the baked curve plus its beam meets authored collision."""
    r = rules()
    half = r["RAIL_BEAM_THICKNESS"] / 2.0
    need = half + margin
    worst = {}
    for p in baked(points):
        for h in hs:
            gap = -h.depth(p)
            if gap < need:
                if h.name not in worst or gap < worst[h.name][0]:
                    worst[h.name] = (gap, p)
    return sorted((name, gap, p) for name, (gap, p) in worst.items())


# --------------------------------------------------------------------
# launches
# --------------------------------------------------------------------

def solve(source, target):
    """`LaunchSolver.solve`, verbatim."""
    r = rules()
    g = r["GRAVITY"]
    span = math.dist(source, target)
    if span < 0.5:
        return None, "source and target are the same place"
    if span > r["MAX_RANGE"]:
        return None, "%.1f m is past the %.0f m a launch may cover" % (
            span, r["MAX_RANGE"])
    apex = max(source[1], target[1]) + r["APEX_CLEARANCE"]
    rise, fall = apex - source[1], apex - target[1]
    if rise <= 0.0 or fall <= 0.0:
        return None, "the apex does not clear both ends"
    up = math.sqrt(2.0 * g * rise)
    time = up / g + math.sqrt(2.0 * fall / g)
    flat = (target[0] - source[0], 0.0, target[2] - source[2])
    vel = (flat[0] / time, up, flat[2] / time)
    return (vel, time, apex), ""


def arc(source, velocity, time, samples=None):
    """`LaunchSolver.arc`, verbatim."""
    r = rules()
    n = int(samples or r["ARC_SAMPLES"])
    g = r["GRAVITY"]
    out = []
    for i in range(n + 1):
        t = time * float(i) / float(n)
        out.append(tuple(source[k] + velocity[k] * t
                         - (0.5 * g * t * t if k == 1 else 0.0)
                         for k in range(3)))
    return out


def landing_truth(hs, at, rules_=None):
    """Is `at` a landing SURFACE a body could arrive on? None if yes.

    THE OWNER'S RULING, IMPLEMENTED. A `launch_target` names the landing
    surface -- the player's foot-contact point -- and not the capsule
    centre; Production converts it to the canonical standing pose. So the
    truthful test is not "is this point clear" (a foot point never is,
    it is touching the floor) but:

      * there is ground AT it, within a tread's tolerance; and
      * the standing body fits with its feet there.

    Getting this wrong in either direction is expensive. The audit at
    `802732d` measured three of the library's four targets sitting at
    depth exactly 0.0000 m on a floor face -- correctly authored landing
    surfaces that a body-centre reading would have refused, "the single
    most likely way a newly written canonical caller would refuse three
    good rooms on its first run".
    """
    r = rules_ or rules()
    who = buried(hs, (at[0], at[1] + 0.05, at[2]))
    if who is not None:
        return "the landing point is inside '%s'" % who
    ground = ground_below(hs, (at[0], at[1] + 0.05, at[2]), 1.0)
    if ground is None or abs(ground - at[1]) > 0.15:
        return ("nothing to land on: the nearest ground under it is %s"
                % ("%.2f m below" % (at[1] - ground) if ground is not None
                   else "further than 1 m"))
    if not body_fits(hs, at, r):
        return "a standing body does not fit with its feet there"
    return None


def body_depth(hs, foot, rules_=None):
    """How far the worst part of a standing body is inside anything.

    Positive means overlapping, and the magnitude is the deepest of the
    swept spheres. Negative is the clearance of the tightest one.
    """
    r = rules_ or rules()
    radius, height = r["PLAYER_RADIUS"], r["PLAYER_HEIGHT"]
    n = max(2, int(math.ceil((height - 2.0 * radius) / radius)) + 1)
    worst, who = -1e9, None
    for i in range(n):
        c = (foot[0],
             foot[1] + radius + (height - 2.0 * radius) * i / (n - 1),
             foot[2])
        for h in hs:
            over = h.depth(c) + radius
            if over > worst:
                worst, who = over, h.name
    return worst, who


def launch_conflicts(hs, source, target, dense=240):
    """Every arc sample where the player's body would not fit.

    The arc is the FOOT's path, per the owner's ruling, so each sample is
    tested as a stance rather than as a bare point -- which is what makes
    the first and last samples (feet on the pad, feet on the landing)
    pass instead of reading as buried.

    THE SAMPLE REPORTED IS THE DEEPEST, NOT THE FIRST. It used to be the
    first, and that is a different question with a much smaller answer:
    both of the launch findings this file raised on 2026-09-03 were
    reported at 0.08 m, which is where the body TOUCHES the platform it
    lands on. Swept over the whole flight they were 0.643 m and 0.806 m
    in -- those arcs did not graze anything, they went through it, and
    the number that reached a report said otherwise. Where a collision
    starts is not how bad it is.
    """
    shot, why = solve(source, target)
    if shot is None:
        return None, why, []
    vel, time, apex = shot
    hits = {}
    for p in arc(source, vel, time, samples=dense):
        if body_fits(hs, p):
            continue
        who = buried(hs, (p[0], p[1] + 0.9, p[2])) or clearance(hs, p)[1]
        deep = body_depth(hs, p)[0]
        if who not in hits or deep > hits[who][1]:
            hits[who] = (p, deep)
    return (vel, time, apex), "", sorted(
        (who, p, deep) for who, (p, deep) in hits.items())


# --------------------------------------------------------------------
# grapples
# --------------------------------------------------------------------

def grapple_truth(hs, at, rules_=None):
    """The continuous truth about one anchor. None means it is real.

    Production's contract, measured without a stride:
      * the anchor admits the player's body;
      * `SWING_ROOM` of CONTINUOUS clear air hangs beneath it;
      * the first ground below is within `GRAPPLE_DROP`.
    """
    r = rules_ or rules()
    swing, drop_max = r["SWING_ROOM"], r["GRAPPLE_DROP"]
    radius = r["PLAYER_RADIUS"]
    who = buried(hs, at)
    if who is not None:
        return "the anchor is inside %s" % who
    if not body_fits(hs, (at[0], at[1] - r["PLAYER_HEIGHT"] / 2.0, at[2]), r):
        return "the player's body does not fit at the anchor"
    y = at[1]
    while y >= at[1] - swing - 1e-9:
        far, who = clearance(hs, (at[0], y, at[2]))
        if far < radius:
            return ("the swing column is blocked %.2f m below the anchor "
                    "by %s" % (at[1] - y, who))
        y -= SWEEP
    ground = ground_below(hs, at, drop_max + swing + 1.0)
    if ground is None:
        return "nothing within %.0f m under it is ground" % drop_max
    fall = at[1] - ground
    if fall > drop_max:
        return "the first ground is %.2f m down, past %.0f" % (fall, drop_max)
    if fall < swing:
        return ("only %.2f m of hang space; %s requires %.1f"
                % (fall, "SWING_ROOM", swing))
    return None


def grapple_drop(hs, at):
    r = rules()
    ground = ground_below(hs, at, r["GRAPPLE_DROP"] + r["SWING_ROOM"] + 1.0)
    return None if ground is None else at[1] - ground


# --------------------------------------------------------------------
# the report
# --------------------------------------------------------------------

def manifests():
    out = {}
    for d in SHELLS:
        path = os.path.join(d, "manifest.json")
        if os.path.exists(path):
            out.update(json.load(open(path, encoding="utf-8")))
    return out


def main(argv):
    wanted = argv[1:]
    M = manifests()
    paths = sorted(os.path.join(d, f) for d in SHELLS
                   for f in os.listdir(d) if f.endswith(".glb")
                   and (not wanted or any(w in f for w in wanted)))
    problems, raised_notes, checked = [], [], 0
    for path in paths:
        cid = os.path.basename(path)[:-4]
        entry = M.get(cid)
        if entry is None:
            continue
        hs = hulls(path)
        bad = nonconvex(path)
        for name, worst in bad:
            problems.append("%s: collider '%s' is not convex (%.4f m out); "
                            "Godot ships its hull, not this mesh"
                            % (cid, name, worst))
        print("[offer] %-22s %3d colliders, %d non-convex"
              % (cid, len(hs), len(bad)))
        for off in entry.get("offers", []):
            checked += 1
            kind, name = off["kind"], off["name"]
            if kind == "rail_route":
                hits = rail_conflicts(hs, [tuple(p) for p in off["points"]])
                if hits:
                    for who, gap, p in hits:
                        problems.append(
                            "%s/%s: the BAKED curve comes within %.4f m of "
                            "'%s' at (%.2f, %.2f, %.2f); the beam needs "
                            "%.3f" % (cid, name, gap, who, p[0], p[1], p[2],
                                      rules()["RAIL_BEAM_THICKNESS"] / 2.0
                                      + RAIL_MARGIN))
                    print("    %-16s REFUSED  %d collider(s) in the way"
                          % (name, len(hits)))
                else:
                    print("    %-16s ok       baked curve clears everything"
                          % name)
            elif kind == "launch_source":
                tgt = [o for o in entry["offers"]
                       if o["name"] == off["target"]][0]
                src, dst = tuple(off["position"]), tuple(tgt["position"])
                shot, why, hits = launch_conflicts(hs, src, dst)
                if shot is None:
                    problems.append("%s/%s: %s" % (cid, name, why))
                    print("    %-16s REFUSED  %s" % (name, why))
                    continue
                bad_pad = landing_truth(hs, dst)
                if bad_pad is not None:
                    problems.append("%s/%s at %s: %s"
                                    % (cid, tgt["name"], list(dst), bad_pad))
                raised = RAISED.get((cid, name))
                blame = tuple(who for who, _, _ in hits)
                if raised is not None and blame == raised:
                    for who, p, deep in hits:
                        raised_notes.append(
                            "%s/%s: RAISED, not repaired -- the body is "
                            "%.3f m inside '%s' at its deepest, with its "
                            "feet at (%.2f, %.2f, %.2f)"
                            % (cid, name, deep, who, p[0], p[1], p[2]))
                elif raised is not None:
                    problems.append(
                        "%s/%s: the raised finding has CHANGED -- it was "
                        "%s and it is now %s. Re-measure it and re-rule it; "
                        "do not edit the ledger to match."
                        % (cid, name, list(raised), list(blame) or "clean"))
                else:
                    for who, p, deep in hits:
                        problems.append(
                            "%s/%s: the body goes %.3f m inside '%s' on the "
                            "solved arc, deepest with its feet at (%.2f, "
                            "%.2f, %.2f)"
                            % (cid, name, deep, who, p[0], p[1], p[2]))
                ok = bad_pad is None and not hits
                print("    %-16s %s  apex %.1f m, flight %.2f s"
                      % (name, "ok      " if ok else
                         "RAISED  " if raised is not None and blame == raised
                         else "REFUSED ", shot[2], shot[1]))
            elif kind == "grapple_point":
                at = tuple(off["position"])
                why = grapple_truth(hs, at)
                fall = grapple_drop(hs, at)
                if why is not None:
                    problems.append("%s/%s at %s: %s"
                                    % (cid, name, list(at), why))
                print("    %-16s %s  %s"
                      % (name, "ok      " if why is None else "REFUSED ",
                         "ground %.2f m below" % fall if fall is not None
                         else "no ground below"))
    for line in raised_notes:
        print("[offer]   %s" % line)
    for line in problems:
        print("[offer]   %s" % line)
    missing = sorted(k for k in RAISED
                     if k[0] in {os.path.basename(q)[:-4] for q in paths}
                     and not any(k[0] + "/" + k[1] in n for n in raised_notes)
                     and not any(k[0] + "/" + k[1] in n for n in problems))
    for cid, name in missing:
        problems.append(
            "%s/%s is on the raised ledger and was not measured at all -- "
            "the offer is gone or renamed, so the ruling it is waiting for "
            "no longer has a subject" % (cid, name))
        print("[offer]   %s" % problems[-1])
    print("[offer] %d offer(s) measured against real collision, %d refused, "
          "%d raised and not repaired"
          % (checked, len(problems), len(raised_notes)))
    if problems:
        print("[offer] FAIL -- a declared offer that its own room refuses is "
              "a promise the shell cannot keep")
        return 1
    if raised_notes:
        print("[offer] PASS -- every declared offer survives the room it is "
              "in except the %d on the raised ledger, which are exactly as "
              "they were raised" % len(raised_notes))
        return 0
    print("[offer] PASS -- every declared offer survives the room it is in")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
