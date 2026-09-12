"""`measure_doorways` against geometry built to make it fail.

    python3 tools/content/test_measure_doorways.py

## Why a synthetic fixture and not the shipped shells

The aperture probe read the wall's mid-thickness by stepping
`along - inward * thickness / 2`, which is a step OUTWARD -- past the face,
into open air, where nothing is solid. Every doorway passed the obstruction
check however completely a wall filled it, and no shipped shell could show
it, because none of the twelve has a blocked doorway. A check whose only
evidence is "it passes on art we already believe" has not been tested; it
has been agreed with.

So this builds rooms on purpose. For each of the four wall orientations it
makes an OPEN control and a BLOCKED twin differing by one box, and asserts
the check tells them apart. With the old sign every blocked case passes and
this file fails eight times.

It also checks the other two rules the same way, and -- the point of a
control -- that none of the three fires on the room that is simply correct.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_doorways import (                              # noqa: E402
    doorway_problems, ENVELOPE, OBSTRUCTION, SUPPORT)

W, D, H, T = 8.0, 10.0, 4.0, 0.6      # room, and its wall thickness
DW, DH = 2.4, 3.2                      # the declared opening


def box(name, x0, x1, y0, y1, z0, z1):
    return (name, [x0, y0, z0], [x1, y1, z1])


def room(yaw, blocked=False, floored=True):
    """A room with one doorway in the wall that `yaw` faces.

    Returns (socket, parts). The four orientations are spelled out rather
    than generated, because a fixture that shares the checker's own
    arithmetic would agree with a sign error as readily as the checker.
    """
    parts = []
    if floored:
        # Floor across the whole footprint INCLUDING the wall thickness,
        # so the support rule is satisfied and only the opening is at
        # issue.
        parts.append(box("floor", -W / 2, W / 2, -1.0, 0.0, 0.0, D))

    if yaw in (0.0, 180.0):
        at = (0.0, 0.0, D if yaw == 0.0 else 0.0)
        z0, z1 = (D - T, D) if yaw == 0.0 else (0.0, T)
        parts += [
            box("wall_a", -W / 2, -DW / 2, 0.0, H, z0, z1),
            box("wall_b", DW / 2, W / 2, 0.0, H, z0, z1),
            box("head", -DW / 2, DW / 2, DH, H, z0, z1),
        ]
        if blocked:
            parts.append(box("blocker", -DW / 2, DW / 2, 0.0, DH, z0, z1))
    else:
        sign = 1.0 if yaw == 90.0 else -1.0
        at = (sign * W / 2, 0.0, D / 2)
        x0, x1 = ((W / 2 - T, W / 2) if sign > 0
                  else (-W / 2, -W / 2 + T))
        c0, c1 = D / 2 - DW / 2, D / 2 + DW / 2
        parts += [
            box("wall_a", x0, x1, 0.0, H, 0.0, c0),
            box("wall_b", x0, x1, 0.0, H, c1, D),
            box("head", x0, x1, DH, H, c0, c1),
        ]
        if blocked:
            parts.append(box("blocker", x0, x1, 0.0, DH, c0, c1))

    socket = {"kind": "doorway", "name": "exit", "position": list(at),
              "yaw": yaw, "width": DW, "height": DH}
    return socket, parts


def kinds(socket, parts):
    got = doorway_problems("fixture", [W, D, H], [socket], parts)
    return sorted(kind for _, kind, _ in got)


def main():
    failures = []

    def expect(what, got, want):
        if got != want:
            failures.append("%s: measured %s, expected %s"
                            % (what, got or "nothing", want or "nothing"))

    for yaw in (0.0, 90.0, 180.0, 270.0):
        # The control. A correct room must trip nothing at all -- a check
        # that fires here is worse than one that never fires.
        socket, parts = room(yaw)
        expect("yaw %3.0f open control" % yaw, kinds(socket, parts), [])

        # One box, filling exactly the opening the socket declares.
        socket, parts = room(yaw, blocked=True)
        expect("yaw %3.0f blocked" % yaw, kinds(socket, parts),
               [OBSTRUCTION])

        # No floor under the threshold.
        socket, parts = room(yaw, floored=False)
        expect("yaw %3.0f unfloored" % yaw, kinds(socket, parts), [SUPPORT])

    # THE ENVELOPE RULE, ISOLATED FROM THE SUPPORT RULE. 0.405 m is
    # Production's own slack, WALL_THICKNESS + SPAN_TOLERANCE.
    #
    # These assert only whether ENVELOPE fires, because a socket past the
    # wall face has no floor under it either and would otherwise be graded
    # on two rules at once. That is not a fixture convenience -- it is the
    # yard's exact situation: 0.40 m out, INSIDE the slack, so its
    # coordinate is not a defect, while the missing floor at its threshold
    # still is. Conflating the two is what made an earlier version of the
    # checker report the yard as a fourth instance of Production's bug.
    for out, want in ((0.40, False), (2.00, True)):
        socket, parts = room(0.0)
        socket["position"][2] = D + out
        got = ENVELOPE in kinds(socket, parts)
        if got != want:
            failures.append(
                "%.2f m outside the face: ENVELOPE %s, expected %s "
                "(the slack is 0.405 m)"
                % (out, "fired" if got else "did not fire",
                   "it to" if want else "it not to"))

    for line in failures:
        print("test-doorways: FAIL -- %s" % line, file=sys.stderr)
    if failures:
        return 1
    print("test-doorways: 14 cases -- open, blocked and unfloored in all "
          "four orientations, plus both sides of the envelope slack.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
