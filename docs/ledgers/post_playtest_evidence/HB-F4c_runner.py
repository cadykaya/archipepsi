"""HB-F4c sabotages: break one part of the rule, confirm a named failure,
restore.

Same protocol as the HB-F4a runner: each row edits zone_builder.gd in the
HB-F4c work tree, runs `make godot-room-contract` (whose
`_test_a_branch_door_is_kept_for_its_branch` lays out the owner's
candidate zone_006), records every FAIL line, and restores the file byte
for byte (sha256 checked). A row is CAUGHT only when the check it names
is among the failures. `--dry` only counts the anchors.

    HB_TREE=<tree> python3 HB-F4c_runner.py [ROW ...] [--dry]

Rows marked REPRO put back the behaviour as it stood before this change.

RC-3 was first written as a CONTROL, expecting the owed doors to work as
a preference with a fallback, as HB-F4a's spine corridor does. It broke:
the owner's zone_006 needs the rule hard, so it is a sabotage here.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("HB_TREE",
                           Path(__file__).resolve().parent / "wt-hbf4c"))
ZB = "godot/scripts/generation/zone_builder.gd"
TARGET = "godot-room-contract"

ROWS = [
    ("RC-1", "REPRO: no door is owed a branch", ZB,
     '''		if not owed.has(key):
			owed[key] = _owed_bridge(job, shape)
''',
     '''		if not owed.has(key):
			pass
''',
     "every door candidate zone_006 assigns measures a hole"),
    ("RC-2", "a branch's own branches are not owed when they queue", ZB,
     '''			if not replaying:
				_owe_pending(pending, sockets_owed, shape)
''',
     '''			pass
''',
     "every door candidate zone_006 assigns measures a hole"),
    ("RC-3", "an owed door is a preference, dropped by the fallback", ZB,
     '''						b_yaw, owed_doors + placed, 0, b_reserve)
''',
     '''						b_yaw, placed, 0, b_reserve)
''',
     "every door candidate zone_006 assigns measures a hole"),
    ("RC-4", "the owed box ignores the socket's turn", ZB,
     '''			p_yaw + float(mouth["turn"]))]
''',
     '''			p_yaw)]
''',
     "every branch door is owed exactly the connector its branch lays"),
    ("RC-5", "the owed box stands at the room, not at its door", ZB,
     '''	var at: Vector3 = (job["at"] as Vector3) \\
			+ _rot(p_yaw, mouth["position"] as Vector3)
''',
     '''	var at: Vector3 = job["at"] as Vector3
''',
     "every branch door is owed exactly the connector its branch lays"),
    ("RC-6", "REPRO: the blocker report sizes a body unturned",
     "godot/scripts/content/room_audit.gd",
     '''		return fitted.global_transform * local
''',
     '''		return AABB(fitted.global_position - local.size / 2.0, local.size)
''',
     "a 0.4 x 5.0 m wall turned a quarter is reported 5.0 m along x"),
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
