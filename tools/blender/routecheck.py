"""The one place the art lane checks that a route can be walked.

Batch 017 needed this for platform paths and Batch 018 needs the same rule
for towers, so it lives here rather than in either builder. Two authored
shells disagreeing about how far a jump reaches would be worse than not
checking at all: it would look checked.

## Why the check is edge to edge

The player jumps from the near edge of one platform to the near edge of the
next, so centre-to-centre flatters every layout that has any platform width
at all. For two axis-aligned footprints:

    dz = max(0, |dZ| - (depth_a + depth_b) / 2)
    dx = max(0, |dX| - (width_a + width_b) / 2)
    distance = sqrt(dz^2 + dx^2)

which has the useful property that a lateral offset costs nothing until it
exceeds the platforms' own width, and costs the difference after that.

## Why the bound is a function

`zone.py` bounds `gap_size` and `vertical_step` **jointly**. v0.4 bounded
them independently, both could be maxed, and the real margin was 1.17x
rather than the 1.56x the flat-jump derivation advertised. `engine_truth`
therefore carries `C.max_safe_gap` as a callable, and every caller here
asks it at the rise it actually built.
"""

from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402

DIM = common.DIM
MAX_SAFE_GAP = DIM["max_safe_gap"]
GAP_MIN = DIM["path_gap_min"]
STEP_MAX = DIM["max_vertical_step"]


def jump_distance(a, b, size_a, size_b):
    """Edge-to-edge distance between two footprints, in metres.

    `a` and `b` are (x, y) centres in the horizontal plane; `size_a` and
    `size_b` are (width_x, depth_y).
    """
    dz = max(0.0, abs(a[1] - b[1]) - (size_a[1] + size_b[1]) / 2.0)
    dx = max(0.0, abs(a[0] - b[0]) - (size_a[0] + size_b[0]) / 2.0)
    return math.sqrt(dz * dz + dx * dx)


def assert_reachable(name, stones, step, require_gap=True):
    """Check every consecutive pair of `stones` against the joint bound.

    `stones` is a list of ((x, y), (width, depth)) in route order. `step`
    is the rise between consecutive stones, which sets the bound.

    `require_gap=False` is for a route whose platforms deliberately OVERLAP
    -- `tower()`'s spiral spaces its 2.6 m platforms 2.4 m apart, so the
    mandatory climb is very nearly a staircase. That is the engine's own
    guarantee and not something to fail a shell for; what must never pass
    is the other direction.

    Returns (worst_measured, allowed).
    """
    if step > STEP_MAX + 1e-9:
        raise AssertionError(
            "%s: a rise of %.3f m exceeds MAX_VERTICAL_STEP %.2f. The "
            "mandatory route would need more than the base kit."
            % (name, step, STEP_MAX))
    allowed = MAX_SAFE_GAP(step)
    worst = 0.0
    for (a, sa), (b, sb) in zip(stones, stones[1:]):
        d = jump_distance(a, b, sa, sb)
        worst = max(worst, d)
        if d > allowed + 1e-9:
            raise AssertionError(
                "%s: a mandatory jump of %.3f m exceeds max_safe_gap(%.2f) = "
                "%.3f. This shell would be unfinishable with the base kit."
                % (name, d, step, allowed))
        if require_gap and d < GAP_MIN - 1e-9:
            raise AssertionError(
                "%s: a jump of %.3f m is under zone.py's gap_size floor of "
                "%.2f -- that is a step, not a gap." % (name, d, GAP_MIN))
    return round(worst, 3), allowed
