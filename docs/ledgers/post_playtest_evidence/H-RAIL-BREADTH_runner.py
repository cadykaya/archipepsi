"""H-RAIL-BREADTH sabotages: break one rule, confirm a named failure, restore.

Same protocol as the D-9, D-10 and ML-F runners: each row edits one file in
the wt-rail work tree, runs `make godot-rail-network`, records every FAIL
line, and restores the file byte for byte (sha256 checked). A row is CAUGHT
only when the check it names is among the failures. `--dry` only counts the
anchors. Run only when no other Godot suite is running.

Rows marked REPRO put back the code as it stood before this slice (RB-F2,
RB-F3): their failures are the reproduction of those findings on the old
code path.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("RB_TREE",
                           Path(__file__).resolve().parent / "wt-rail"))
AC = "godot/scripts/gameplay/actuator.gd"
RC = "godot/scripts/gameplay/rail_carrier.gd"
NC = "godot/scripts/gameplay/rail_network_carrier.gd"
PT = "godot/scripts/gameplay/rail_points.gd"
RP = "godot/scripts/gameplay/rail_path.gd"
TARGET = "godot-rail-network"

ROWS = [
    ("RB-1", "the route lock ignored by the switch", AC,
     "\tif not _route_locks.is_empty():\n\t\treturn false\n",
     "",
     "but it is committed to them, so the throw to B1 is QUEUED"),
    ("RB-2", "the crossing check gone (the carrier follows its plan, not "
     "the tongue)", NC,
     "\t\t\tif k >= 0 and not _joins(k, piece, _pieces[i + 1]):\n",
     "\t\t\tif false and k >= 0 and not _joins(k, piece, _pieces[i + 1]):\n",
     "CONTROL (the lock off"),
    ("RB-3", "a leg counted as joined while the tongue is still moving", AC,
     "\tif kind != \"RAIL_SWITCH\" or path.size() < 2 or direction != 0:\n"
     "\t\treturn -1\n"
     "\tvar at_branch := float(_branch) / float(path.size() - 1)\n"
     "\treturn _branch if absf(t - at_branch) <= EPSILON else -1\n",
     "\tif kind != \"RAIL_SWITCH\" or path.size() < 2:\n"
     "\t\treturn -1\n"
     "\treturn _branch\n",
     "until the tongue arrives, joins neither leg"),
    ("RB-4", "a carrier on a leg routed through points set for the other",
     NC,
     "\t\t\tif live != mine:\n",
     "\t\t\tif false and live != mine:\n",
     "BACK from B1 is refused"),
    ("RB-5", "commissioning not read by the walk", NC,
     "\t\tif commissioned[e]:\n\t\t\tcontinue\n\t\tif minf(hi,",
     "\t\tif true:\n\t\t\tcontinue\n\t\tif minf(hi,",
     "the points set for A1 but S-A1 not commissioned"),
    ("RB-6", "REPRO RB-F2: the reset row as it was", AC,
     "\tif kind == \"RAIL_SWITCH\" and path.size() > 1:\n"
     "\t\t_want_branch(int(round(clampf(initial_t, 0.0, 1.0)\n"
     "\t\t\t\t* float(path.size() - 1))))\n"
     "\t\treturn\n"
     "\t_resetting = true",
     "\t_resetting = true",
     "a reset is QUEUED like any throw"),
    ("RB-7", "REPRO RB-F3: the ordered carrier's request as it was", RC,
     "\tif _unpowered:\n"
     "\t\trefused.emit(\"unpowered\", \"the carrier has no power and holds \"\n"
     "\t\t\t\t+ \"where it stands\")\n"
     "\t\treturn false\n\n\tvar here := at_dock()",
     "\n\tvar here := at_dock()",
     "with no power, a travel command is refused"),
    ("RB-8", "a restore that throws instead", NC,
     "\t\tpt.restore(leg)\n\t\tcount += 1\n",
     "\t\tpt.throw_to(leg)\n\t\tcount += 1\n",
     "nothing is reported"),
    ("RB-9", "no clearance rule at layout", NC,
     "\t\t\tif gap < Constants.RAIL_SWITCH_CLEARANCE_M:\n",
     "\t\t\tif false:\n",
     "a leg dock inside the points' clearance is refused by name"),
    ("RB-10", "a call that does not set the points it needs", NC,
     "\t\tif pt.set_leg() != int(need[1]) or pt.queued_leg() >= 0:\n"
     "\t\t\tpt.throw_to(int(need[1]))\n",
     "",
     "calls the carrier from each"),
    ("RB-11", "the points AT the fork dock", NC,
     "const POINTS_LEAD := Constants.RAIL_SWITCH_CLEARANCE_M + 1.0\n",
     "const POINTS_LEAD := 0.5\n",
     "the Y network lays out"),
    ("RB-12", "a tongue that does not move (a flag, not track)", PT,
     "\tactuator.driven = pivot\n",
     "",
     "the tongue MOVED"),
    ("RB-14", "the deck faces each line in turn (no carry-over)", NC,
     "\t\t\t\t_facing = 1.0 if path.tangent(from).dot(was) >= 0.0 else -1.0\n",
     "\t\t\t\t_facing = 1.0\n",
     "every dock calls the carrier from every other"),
    ("RB-15", "REPRO RB-F5: the rail sampler as it was", RP,
     "\tvar n := int(ceil(span / walk - 0.001))\n",
     "\tvar n := int(ceil(span / walk))\n",
     "201 straight, level rails"),
    ("RB-13", "a leg leaves its points toward its dock, not along the heel",
     NC,
     "\t\t\tif i == 0 and seq[1] != int(spec[\"dock\"]):\n"
     "\t\t\t\tstart_dir = dir\n",
     "\t\t\tif false:\n\t\t\t\tstart_dir = dir\n",
     "every leg starts where the heel ends"),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    args = sys.argv[1:]
    dry = "--dry" in args
    only = {a for a in args if not a.startswith("--")}
    lines, caught, total = [], 0, 0
    for rid, what, rel, old, new, expect in ROWS:
        if only and rid not in only:
            continue
        total += 1
        path = TREE / rel
        original = path.read_bytes()
        text = original.decode("utf-8")
        if text.count(old) != 1:
            lines.append(f"{rid} SETUP ERROR: anchor found {text.count(old)}"
                         f" times in {rel}")
            print(lines[-1], flush=True)
            continue
        if dry:
            print(f"{rid} anchor ok ({rel})", flush=True)
            continue
        before = hashlib.sha256(original).hexdigest()
        path.write_bytes(text.replace(old, new).encode("utf-8"))
        try:
            out = subprocess.run(["make", TARGET], cwd=TREE,
                                 capture_output=True, text=True, timeout=1500)
            log = out.stdout + out.stderr
        finally:
            path.write_bytes(original)
        restored = sha(path) == before
        fails = [l[6:] for l in log.splitlines() if l.startswith("FAIL: ")]
        errors = sum(1 for l in log.splitlines()
                     if l.lstrip().startswith("SCRIPT ERROR"))
        hit = any(expect in f for f in fails)
        caught += hit
        lines.append(f"{rid} [{rel.split('/')[-1]}] {what}")
        lines.append(f"    {'CAUGHT' if hit else 'NOT CAUGHT'} by \"{expect}\""
                     f" -- exit {out.returncode}, {len(fails)} failing check(s),"
                     f" {errors} script error(s); restored byte for byte:"
                     f" {restored}")
        for f in fails:
            lines.append(f"      FAIL: {f[:300]}")
        print("\n".join(lines[-(len(fails) + 2):]), flush=True)
    if not dry:
        lines.append(f"\n{caught} of {total} sabotages caught")
        print(lines[-1])
    return 0 if dry or caught == total else 1


if __name__ == "__main__":
    sys.exit(main())
