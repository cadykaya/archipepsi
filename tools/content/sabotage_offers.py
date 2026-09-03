"""Prove the offer gate and its replay can fail, in-process.

    python3 tools/content/sabotage_offers.py

`sabotage_checks.sh` sabotages guards by editing the working tree and
restoring it with `git checkout`, which is right for a guard that reads
a source file and wrong for these two: the pack's manifests carry the
declarations under test, and a script that `git checkout`s a manifest
can eat an export somebody has not committed yet. So every case here
substitutes its bug in MEMORY -- the tree is never written.

Each case reintroduces something real: an audited declaration the repair
moved, or a way the raised-findings ledger could rot. A case that does
not fire is reported, and the run fails.
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import measure_offers as M  # noqa: E402
import replay_audited as R  # noqa: E402

CASES, BAD = [], []


def _audited_manifests():
    out = {}
    for rel in R.MANIFESTS:
        out.update(json.loads(subprocess.run(
            ["git", "show", "%s:%s" % (R.AUDITED, rel)],
            check=True, capture_output=True, text=True).stdout))
    return out


def _run(fn):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        try:
            rc = fn()
        except SystemExit as exc:                # pragma: no cover
            rc = exc.code or 0
    return rc, buf.getvalue()


def case(name, fn, want, needle=""):
    rc, out = _run(fn)
    ok = (rc != 0) if want == "fail" else (rc == 0)
    if ok and needle:
        ok = needle in out
    CASES.append(name)
    if ok:
        print("  %-54s %s" % (name, "caught" if want == "fail" else "clean"))
        return
    BAD.append(name)
    print("  %-54s %s" % (name, "NOT CAUGHT" if want == "fail"
                          else "FALSE POSITIVE"))
    for line in out.strip().splitlines()[-6:]:
        print("      %s" % line)


@contextlib.contextmanager
def patched(**kw):
    old = {k: getattr(M, k) for k in kw}
    for k, v in kw.items():
        setattr(M, k, v)
    try:
        yield
    finally:
        for k, v in old.items():
            setattr(M, k, v)


def with_ledger(key, blame):
    """`RAISED` plus one entry. Not `dict(..., **{...})`: these keys are
    tuples, and `**` only takes strings."""
    out = dict(M.RAISED)
    out[key] = blame
    return out


def gate(*rooms):
    """The gate, over the shells a case is about.

    Narrowed on purpose: `main` walks every shell in the pack, and a
    case that measures eighteen rooms it is not testing turns a
    negative-control suite into something nobody runs.
    """
    return lambda: M.main(["measure_offers.py"] + list(rooms))


def with_audited_offers(only=None):
    """Today's manifests, with the audited offers put back."""
    live, old = M.manifests(), _audited_manifests()

    def fake():
        out = json.loads(json.dumps(live))
        for cid, entry in old.items():
            if only and cid != only:
                continue
            if cid in out and "offers" in entry:
                out[cid]["offers"] = entry["offers"]
        return out
    return fake


def main():
    print("sabotage-offers: the gate, against the declarations it replaced")
    for cid, label in (("shell_hall_transit", "hall rail through the gantry "
                        "and ramp1"),
                       ("shell_span_basin", "span rail through both pylons"),
                       ("shell_plenum_helix", "plenum rail, launch and "
                        "grapple as audited")):
        room = cid.split("_", 1)[1]
        with patched(manifests=with_audited_offers(cid)):
            case(label, gate(room), "fail")
    with patched(manifests=with_audited_offers()):
        case("all three rooms at once", gate("hall", "span", "plenum"), "fail")

    print()
    print("sabotage-offers: today's pack is not accidentally passing")
    case("the whole shipped pack", gate(), "pass")

    print()
    print("sabotage-offers: the raised ledger cannot rot")
    with patched(RAISED={}):
        case("an emptied ledger stops excusing anything",
             gate("hall", "span"), "fail")
    with patched(RAISED=with_ledger(("shell_hall_transit", "launch_basin"),
                                    ("hl_roof-convcolonly",))):
        case("a ledger entry blaming the wrong collider",
             gate("hall", "span"), "fail", "has CHANGED")
    with patched(RAISED=with_ledger(("shell_yard_gantry", "launch_west"),
                                    ("yd_crane-convcolonly",))):
        case("a ledger entry for an offer that is fine",
             gate("hall", "span", "yard"), "fail", "has CHANGED")
    with patched(RAISED=with_ledger(("shell_yard_gantry", "launch_nowhere"),
                                    ("yd_crane-convcolonly",))):
        case("a ledger entry whose offer no longer exists",
             gate("hall", "span", "yard"), "fail", "no longer has a subject")

    print()
    print("sabotage-offers: the replay of the audited pack")

    def replay():
        return R.main()
    case("the audited pack, unmodified", replay, "pass")

    for label, attr, value in (
            ("a rail gap off by 5 cm", "RAILS",
             tuple((a, b, c, d + 0.05) for a, b, c, d in R.RAILS)),
            ("the plenum sag off by a third of a metre", "RAILS_TODAY",
             tuple((a, b, c, -0.5) for a, b, c, _ in R.RAILS_TODAY)),
            ("the old collars called convex", "NONCONVEX",
             (("shell_plenum_helix", "pl_collar_", 0),)),
            ("an audited finding left off the list", "RAILS", R.RAILS[1:]),
            ("the audited grapple given today's drop", "GRAPPLES",
             (("shell_plenum_helix", "grapple_1", 9.67),))):
        keep = getattr(R, attr)
        setattr(R, attr, value)
        case(label, replay, "fail")
        setattr(R, attr, keep)

    print()
    if BAD:
        print("sabotage-offers: FAIL -- %d of %d case(s) did not behave"
              % (len(BAD), len(CASES)))
        return 1
    print("sabotage-offers: PASS -- all %d cases behaved" % len(CASES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
