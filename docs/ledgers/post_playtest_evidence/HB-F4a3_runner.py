"""HB-F4a-3 sabotages: break one part of the rule, confirm the named
failure, restore.

Same protocol as the HB-F4a runner: each row edits zone_builder.gd in the
work tree, runs `make godot-room-contract` (whose
`_test_a_junction_keeps_what_it_owes` now lays out the owner's candidate
zone_008 too), records every FAIL line, and restores the file byte for
byte (sha256 checked). A row is CAUGHT only when the check it names is
among the failures. `--dry` only counts the anchors.

    HB_TREE=<tree> python3 HB-F4a3_runner.py [ROW ...] [--dry]

Rows marked REPRO put back the behaviour as it stood before this change.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("HB_TREE",
                           Path(__file__).resolve().parent / "wt-hbf4a3"))
ZB = "godot/scripts/generation/zone_builder.gd"
TARGET = "godot-room-contract"

ROWS = [
    ("RA3-1", "REPRO: the way on is not owed the room it arrives at", ZB,
     '''		if not replaying and not pending.is_empty():
			var spine_list: Array = graph.get("spine", [])
''',
     '''		if false:
			var spine_list: Array = graph.get("spine", [])
''',
     "candidate zone_008 builds"),
    ("RA3-2", "the room is owed at a connector's size, not its own", ZB,
     '''	var bounds: AABB = next.get("bounds", AABB())
''',
     '''	var bounds: AABB = shape["bounds"] as AABB
''',
     "candidate zone_008b builds"),
    ("RA3-3", "the room is owed where the corridor starts, not where it ends",
     ZB,
     '''	for _k in RESERVED_CONNECTORS:
		at += _rot(turn, shape["exit_offset"] as Vector3)
	var room_yaw := yaw + turn
''',
     '''	var room_yaw := yaw + turn
''',
     "candidate zone_008b builds"),
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
