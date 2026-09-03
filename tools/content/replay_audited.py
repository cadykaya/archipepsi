"""Replay the pre-repair pack and require the gate to condemn it.

    python3 tools/content/replay_audited.py

WHY THIS EXISTS. `measure_offers.py` is a gate now, and a gate that has
only ever been run against art that passes it has not been shown to do
anything. The cheap version of this test is to break a number by hand
and watch the check go red, which proves that the check reacts to
something. It does not prove it reacts to THE THING.

So this replays the real audited state instead. Every shell and every
manifest is read out of git at `AUDITED`, unmodified, and measured by
the same functions the gate calls -- and the run FAILS unless each
finding comes back, by collider name and to the centimetre.

Two properties follow that a hand-broken number cannot give:

  * the gate is calibrated against Production's own audit. Every
    expectation below is a number Production measured first, and the
    art-side mirror had to reproduce all of them before a line of the
    repair was written.
  * the repair cannot be undone quietly. If a later change puts any of
    these back, this file is the thing that says so, in the language of
    the original finding.

IT ALSO REFUSES TO PASS TOO EASILY. An expectation that stops matching
is a failure whether the geometry got worse OR better: `nonconvex`
returning nothing for the old collars would mean this is no longer
reading the audited art.

TWO PARTS, BECAUSE ONE OF THE AUDITED COLLIDERS CANNOT BE MEASURED.
`Hull` reads a collider's own face planes, which is the shape Godot
ships only when the mesh is already convex. The audited plenum's three
collars are annuli, and an annulus's planes describe its HOLE rather
than its ring -- so the ride cannot be measured against them at all,
and pretending otherwise would be the same mistake in a test that the
repair took out of the art.

  part 1  the audited artifacts, as they shipped. Everything whose
          colliders were convex already: both other rails, the launch,
          the grapple -- and the non-convexity of the collars, which is
          the finding those colliders ARE.
  part 2  the audited declarations against today's collision. The
          plenum's rail points as the owner passed them, measured
          against the repaired convex sectors -- which is how the
          0.1668 m was reproduced in the first place, and is a fact
          about the ROUTE rather than about the old hull.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import measure_offers as M  # noqa: E402

#: The art head this repair started from -- the state Production's audit
#: was taken against, and the last commit before any of it was moved.
AUDITED = "accdd2e"

SHELLS = ("assets/models/batch039/shells/shell_hall_transit.glb",
          "assets/models/batch040/shells/shell_plenum_helix.glb",
          "assets/models/batch040/shells/shell_span_basin.glb")
MANIFESTS = ("assets/models/batch039/shells/manifest.json",
             "assets/models/batch040/shells/manifest.json")

#: (shell, collider prefix, how many) -- colliders whose own mesh was
#: not its convex hull, so Godot shipped collision LARGER than the art.
#: The three plenum collars: annuli 4.00 to 6.75 whose hull is a disc.
NONCONVEX = (("shell_plenum_helix", "pl_collar_", 3),)

#: PART 1. (shell, offer, collider, gap) -- the baked rail curve too
#: close to solid geometry, measured on the audited art itself. Gaps are
#: metres; negative is inside, and `ramp1_tread5` is outside but nearer
#: than the beam's own half-thickness plus margin.
RAILS = (
    ("shell_hall_transit", "rail_helix", "hl_east_gantry", -0.2490),
    ("shell_hall_transit", "rail_helix", "hl_ramp1_tread3", -0.1053),
    ("shell_hall_transit", "rail_helix", "hl_ramp1_tread4", -0.3890),
    ("shell_hall_transit", "rail_helix", "hl_ramp1_tread5", 0.0585),
    ("shell_span_basin", "rail_underdeck", "sp_pylon_0", -1.9911),
    ("shell_span_basin", "rail_underdeck", "sp_pylon_1", -1.9911),
)

#: PART 2. Rails whose audited conflict is with a collider the audited
#: art could not be measured against, so the audited POINTS are replayed
#: against today's shipped collision instead.
RAILS_TODAY = (
    ("shell_plenum_helix", "rail_descent", "pl_collar_0", -0.1668),
    ("shell_plenum_helix", "rail_descent", "pl_collar_1", -0.1668),
    ("shell_plenum_helix", "rail_descent", "pl_collar_2", -0.1668),
)

#: Offers skipped in part 1 because part 2 owns them.
LATER = frozenset((r[0], r[1]) for r in RAILS_TODAY)

#: (shell, offer) -- launch targets that were not a landing surface, and
#: launch arcs the body could not fly.
LAUNCHES = (("shell_plenum_helix", "launch_floor"),)

#: (shell, offer, drop) -- a grapple anchor with the ground too close
#: underneath it for the swing the package needs.
GRAPPLES = (("shell_plenum_helix", "grapple_1", 0.762),)

TOL = 0.01


def _checkout(into):
    for rel in SHELLS + MANIFESTS:
        dst = os.path.join(into, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as handle:
            subprocess.run(["git", "show", "%s:%s" % (AUDITED, rel)],
                           check=True, stdout=handle)
    return into


def main():
    bad = []
    with tempfile.TemporaryDirectory() as tmp:
        _checkout(tmp)
        entries = {}
        for rel in MANIFESTS:
            entries.update(M.json.load(open(os.path.join(tmp, rel),
                                            encoding="utf-8")))
        hulls, seen_rail, seen_grap = {}, set(), set()
        for rel in SHELLS:
            cid = os.path.basename(rel)[:-4]
            path = os.path.join(tmp, rel)
            hulls[cid] = M.hulls(path)

            found = [n for n, _ in M.nonconvex(path)]
            for shell, prefix, count in NONCONVEX:
                if shell != cid:
                    continue
                hit = [n for n in found if n.startswith(prefix)]
                if len(hit) != count:
                    bad.append("%s: expected %d non-convex '%s*' colliders "
                               "in the audited art, found %d"
                               % (cid, count, prefix, len(hit)))

            for off in entries[cid].get("offers", []):
                name, kind = off["name"], off["kind"]
                if kind == "rail_route":
                    if (cid, name) in LATER:
                        continue
                    for who, gap, _ in M.rail_conflicts(
                            hulls[cid], [tuple(p) for p in off["points"]]):
                        want = [r for r in RAILS if r[0] == cid
                                and r[1] == name and who.startswith(r[2])]
                        if not want:
                            bad.append("%s/%s: the audited pack is inside "
                                       "'%s' by %.4f m and nothing here "
                                       "expects it" % (cid, name, who, gap))
                            continue
                        seen_rail.add(want[0])
                        if abs(gap - want[0][3]) > TOL:
                            bad.append("%s/%s vs '%s': audited at %.4f m, "
                                       "replays at %.4f m"
                                       % (cid, name, who, want[0][3], gap))
                elif kind == "launch_source":
                    tgt = [o for o in entries[cid]["offers"]
                           if o["name"] == off["target"]][0]
                    src, dst = tuple(off["position"]), tuple(tgt["position"])
                    _, _, hits = M.launch_conflicts(hulls[cid], src, dst)
                    pad = M.landing_truth(hulls[cid], dst)
                    if (cid, name) in LAUNCHES and not hits and pad is None:
                        bad.append("%s/%s: the audited launch is expected to "
                                   "be refused and it flies" % (cid, name))
                elif kind == "grapple_point":
                    at = tuple(off["position"])
                    for shell, offer, drop in GRAPPLES:
                        if (shell, offer) != (cid, name):
                            continue
                        seen_grap.add((shell, offer))
                        got = M.grapple_drop(hulls[cid], at)
                        if got is None or abs(got - drop) > TOL:
                            bad.append("%s/%s: audited hanging %.3f m over "
                                       "the ground, replays at %s"
                                       % (cid, name, drop,
                                          "nothing" if got is None
                                          else "%.3f m" % got))
                        elif M.grapple_truth(hulls[cid], at) is None:
                            bad.append("%s/%s: %.3f m of drop is expected to "
                                       "be refused and it is accepted"
                                       % (cid, name, got))

        today = {}
        for cid, name, _, _ in RAILS_TODAY:
            if cid in today:
                continue
            today[cid] = M.hulls(
                [r for r in SHELLS if r.endswith("%s.glb" % cid)][0])
        for cid, name, collider, gap in RAILS_TODAY:
            pts = [tuple(p) for o in entries[cid]["offers"]
                   if o["name"] == name for p in o["points"]]
            hit = [(w, g) for w, g, _ in M.rail_conflicts(today[cid], pts)
                   if w.startswith(collider)]
            if not hit:
                bad.append("%s/%s: the audited route is expected inside "
                           "'%s' by %.4f m and today's collision does not "
                           "find it" % (cid, name, collider, gap))
            elif abs(min(g for _, g in hit) - gap) > TOL:
                bad.append("%s/%s vs '%s': audited at %.4f m, replays at "
                           "%.4f m against today's collision"
                           % (cid, name, collider, gap,
                              min(g for _, g in hit)))

        for want in RAILS:
            if want not in seen_rail:
                bad.append("%s/%s vs '%s': audited at %.4f m and the replay "
                           "does not find it at all"
                           % (want[0], want[1], want[2], want[3]))
        for want in GRAPPLES:
            if (want[0], want[1]) not in seen_grap:
                bad.append("%s/%s: audited and not replayed" % want[:2])

    for line in bad:
        print("[replay]   %s" % line)
    total = (len(RAILS) + len(RAILS_TODAY) + len(LAUNCHES)
             + len(GRAPPLES) + len(NONCONVEX))
    print("[replay] %d audited findings replayed against %s" % (total, AUDITED))
    if bad:
        print("[replay] FAIL -- the gate no longer condemns the art it was "
              "built from, so it is not measuring what it claims to")
        return 1
    print("[replay] PASS -- every audited finding is still found, so the "
          "gate that clears today's pack would have refused the old one")
    return 0


if __name__ == "__main__":
    sys.exit(main())
