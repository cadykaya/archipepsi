"""H-RAIL-BREADTH: the leg curve at a set of points, modelled offline.

A pure-Python copy of what `RailPath.from_points` builds (Godot's Curve3D:
a cubic Bezier per span, handles a third of each Catmull-Rom tangent), used
to choose how long a given end tangent should be before running Godot. It
reproduced the suite's own figure for the clamped half-length (3.5 degrees
in a leg's first 0.1 m). `k` is the given tangent's length as a fraction of
the end span: 0.5 is the clamped Catmull-Rom length, 1.0 what landed.
"""
import math


def add(a, b): return [a[i] + b[i] for i in range(3)]
def sub(a, b): return [a[i] - b[i] for i in range(3)]
def mul(a, s): return [x * s for x in a]
def norm(a): return math.sqrt(sum(x * x for x in a))


def bez(p0, p1, p2, p3, t):
    return [(1 - t) ** 3 * p0[i] + 3 * (1 - t) ** 2 * t * p1[i]
            + 3 * (1 - t) * t ** 2 * p2[i] + t ** 3 * p3[i] for i in range(3)]


def curve(pts, start_dir=None, k=0.5):
    n = len(pts)
    tans = []
    for i in range(n):
        t = mul(sub(pts[min(i + 1, n - 1)], pts[max(i - 1, 0)]), 0.5)
        if i == 0 and start_dir is not None:
            t = mul(start_dir, norm(sub(pts[1], pts[0])) * k)
        tans.append(t)
    out = []
    for i in range(n - 1):
        p0, p3 = pts[i], pts[i + 1]
        p1, p2 = add(p0, mul(tans[i], 1 / 3)), sub(p3, mul(tans[i + 1], 1 / 3))
        steps = 800
        for j in range(steps + (1 if i == n - 2 else 0)):
            out.append(bez(p0, p1, p2, p3, j / steps))
    return out


def report(name, pts, start_dir, k):
    s = curve(pts, start_dir, k)
    arc, angs = [0.0], []
    for i in range(1, len(s)):
        d = sub(s[i], s[i - 1])
        arc.append(arc[-1] + norm(d))
        angs.append(math.degrees(math.atan2(-d[2], d[0])))
    rates = [(arc[i], abs(angs[i] - angs[i - 1]) / (arc[i + 1] - arc[i]))
             for i in range(1, len(angs)) if arc[i + 1] - arc[i] > 1e-9]
    at = next(angs[i] for i in range(len(angs)) if arc[i + 1] >= 0.1)
    print(f"{name:18s} k={k:.2f}  direction 0.1 m in {at:7.2f} deg  "
          f"turn rate, first 6 m {max(r for a, r in rates if a < 6):6.2f} "
          f"deg/m, whole leg {max(r for a, r in rates):6.2f} deg/m")


P = [31, 0, 0]
for k in (0.5, 1.0, 1.5):
    report("leg A (P, A1, A2)", [P, [46, 0, -14], [70, 0, -20]], [1, 0, 0], k)
    report("leg B (P, B1)", [P, [46, 0, 14]], [1, 0, 0], k)
report("an ordered rail", [[0, 0, 0], [18, 0, 4], [34, 0, -3], [52, 0, 2]],
       None, 0.5)
