"""HB-F4a sabotages: break one rule, confirm a named failure, restore.

Same protocol as the HB-F4b runner: each row edits zone_builder.gd in the
HB-F4a work tree, runs `make godot-room-contract` (whose
`_test_a_junction_keeps_what_it_owes` lays out the three compositions),
records every FAIL line, and restores the file byte for byte (sha256
checked). A row is CAUGHT only when the check it names is among the
failures. `--dry` only counts the anchors.

    HB_TREE=<tree> python3 HB-F4a_runner.py [ROW ...] [--dry]

Rows marked REPRO put back the code as it stood before this change.

Rows marked CONTROL name no check: they change a part of the rule that
the census found changes no outcome (the fallback, and the whole
subtree's share of the spine's way on), and HOLD when the suite still
passes. They are here so that finding stays measured, not assumed.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("HB_TREE",
                           Path(__file__).resolve().parent / "wt-hbf4a"))
ZB = "godot/scripts/generation/zone_builder.gd"
TARGET = "godot-room-contract"

ROWS = [
    ("RA-1", "REPRO: the exit room's failure carries no wedge", ZB,
     '''		return {"status": "LAYOUT_INFEASIBLE", "exhausted": true,
				"policy": routing_policy(placed, policy_override),
				"blocking_rooms": [EXIT_ROOM_ID], "blocking_pairs": [],
				"wedge": true,
				"failed": "the exit room could not be placed clear of "
''',
     '''		return {
				"failed": "the exit room could not be placed clear of "
''',
     "candidate zone_011 builds"),
    ("RA-2", "the ladder does not know where the exit room joins", ZB,
     '''	if stuck == EXIT_ROOM_ID:
		at = spine.size() - 1
''',
     '''	if stuck == EXIT_ROOM_ID:
		pass
''',
     "candidate zone_011 builds"),
    ("RA-3", "REPRO: a branch is not told the spine's way on", ZB,
     '''		var spine_owed := [] if replaying \\
				else _owed_exit(result, shape, origin, yaw)
''',
     '''		var spine_owed: Array = []
''',
     "candidate zone_004 builds"),
    ("RA-4", "CONTROL: the spine's way on kept clear by direct branches only", ZB,
     '''			elif not spine_owed.is_empty():
''',
     '''			elif not spine_owed.is_empty() and str(parent.get("id", "")) == rid:
''',
     None),
    ("RA-5", "CONTROL: no fallback; a branch that cannot keep the corridor is refused",
     ZB,
     '''			if not b_replaying and not bool(b_plan["ok"]):
				b_plan = _plan_route(shape, corners,
''',
     '''			if false and not b_replaying and not bool(b_plan["ok"]):
				b_plan = _plan_route(shape, corners,
''',
     None),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    args = sys.argv[1:]
    dry = "--dry" in args
    only = {a for a in args if not a.startswith("--")}
    lines, caught, total, held, controls = [], 0, 0, 0, 0
    for rid, what, rel, old, new, expect in ROWS:
        if only and rid not in only:
            continue
        if expect is None:
            controls += 1
        else:
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
        if expect is None:
            hold = not fails and out.returncode == 0
            held += hold
            lines.append(f"{rid} [{rel.split('/')[-1]}] {what}")
            lines.append(f"    {'CONTROL HOLDS' if hold else 'CONTROL BROKEN'}"
                         f" -- exit {out.returncode}, {len(fails)} failing "
                         f"check(s), {errors} script error(s); restored byte "
                         f"for byte: {restored}")
            for f in fails:
                lines.append(f"      FAIL: {f[:400]}")
            print("\n".join(lines[-(len(fails) + 2):]), flush=True)
            continue
        hit = any(expect in f for f in fails)
        caught += hit
        lines.append(f"{rid} [{rel.split('/')[-1]}] {what}")
        lines.append(f"    {'CAUGHT' if hit else 'NOT CAUGHT'} by \"{expect}\""
                     f" -- exit {out.returncode}, {len(fails)} failing check(s),"
                     f" {errors} script error(s); restored byte for byte:"
                     f" {restored}")
        for f in fails:
            lines.append(f"      FAIL: {f[:400]}")
        print("\n".join(lines[-(len(fails) + 2):]), flush=True)
    if not dry:
        lines.append(f"\n{caught} of {total} sabotages caught; {held} of "
                     f"{controls} controls hold")
        print(lines[-1])
    return 0 if dry or (caught == total and held == controls) else 1


if __name__ == "__main__":
    sys.exit(main())
