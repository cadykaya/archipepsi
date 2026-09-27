"""HB-F4f sabotages: break one part of "no two features on one stretch of
floor", confirm the named failure, restore.

Each row makes one or more edits in the work tree, runs `make
godot-room-contract` (whose `_test_no_two_features_share_a_floor` lays
out every pair of tags declared at one point and builds the owner's
zone_012 `c001`, and whose `_test_no_prop_stands_in_a_feature` checks
each built feature stands on the floor `footprints` reports), records
every FAIL line, and restores every file byte for byte (sha256 checked).
A row is CAUGHT only when the check it names is among the failures; a
CONTROL row expects none. `--dry` only counts the anchors.

    HB_TREE=<tree> python3 HB-F4f_runner.py [ROW ...] [--dry]

Rows marked REPRO put back the behaviour as it stood before this change.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("HB_TREE",
                           Path(__file__).resolve().parent / "wt-hbf4f"))
AF = "godot/scripts/generation/affordance_features.gd"
CONTRACT = "godot-room-contract"

ROWS = [
    ("RF4f-1", "REPRO: each feature is placed alone, as it stood",
     [(AF, '''	if not _crosses(taken, floor_of(tag, origin)):
		return origin
''', '''	if true or not _crosses(taken, floor_of(tag, origin)):
		return origin
''')],
     "and no two floors cross", CONTRACT),
    ("RF4f-2", "a crossing feature looks only along its own wall",
     [(AF, '''	for x: float in [origin.x, -origin.x]:''',
       '''	for x: float in [origin.x]:''')],
     "and no two floors cross", CONTRACT),
    ("RF4f-3", "the props are told where a feature resolved, not where it stands",
     [(AF, '''		if is_finite(origin.z):
			origin = _clear_of_features(origin, tag, chamber, depth, taken)
			taken.append(floor_of(tag, origin))
		out.append({"index": index, "tag": tag, "origin": origin})''',
       '''		var moved := origin
		if is_finite(origin.z):
			moved = _clear_of_features(origin, tag, chamber, depth, taken)
			taken.append(floor_of(tag, moved))
		out.append({"index": index, "tag": tag, "origin": moved,
				"resolved": origin})'''),
      (AF, '''	for placed: Dictionary in _placements(chamber, width, depth):
		var origin: Vector3 = placed["origin"]
		if not is_finite(origin.z):
			continue
		out.append(floor_of(str(placed["tag"]), origin))''',
       '''	for placed: Dictionary in _placements(chamber, width, depth):
		var origin: Vector3 = placed.get("resolved", placed["origin"])
		if not is_finite(origin.z):
			continue
		out.append(floor_of(str(placed["tag"]), origin))''')],
     "every feature `place_all` builds stands inside a floor", CONTRACT),
    ("RF4f-C1", "CONTROL: a coarser walk along the wall still finds a clear stretch",
     [(AF, '''const CLEAR_STEP := 0.25''', '''const CLEAR_STEP := 0.5''')],
     None, CONTRACT),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    args = sys.argv[1:]
    dry = "--dry" in args
    only = {a for a in args if not a.startswith("--")}
    lines, caught, total, held, controls = [], 0, 0, 0, 0
    for rid, what, edits, expect, target in ROWS:
        if only and rid not in only:
            continue
        originals: dict[str, bytes] = {}
        texts: dict[str, str] = {}
        bad = ""
        for rel, old, new in edits:
            path = TREE / rel
            if rel not in originals:
                originals[rel] = path.read_bytes()
                texts[rel] = originals[rel].decode("utf-8")
            n = texts[rel].count(old)
            if n != 1:
                bad = f"anchor found {n} times in {rel}: {old[:60]!r}"
                break
            texts[rel] = texts[rel].replace(old, new)
        if bad:
            lines.append(f"{rid} SETUP ERROR: {bad}")
            print(lines[-1], flush=True)
            continue
        files = ", ".join(sorted({r.split('/')[-1] for r, _, _ in edits}))
        if dry:
            print(f"{rid} anchors ok ({files})", flush=True)
            continue
        if expect is None:
            controls += 1
        else:
            total += 1
        anchors = {rel: hashlib.sha256(b).hexdigest()
                   for rel, b in originals.items()}
        try:
            for rel, text in texts.items():
                (TREE / rel).write_bytes(text.encode("utf-8"))
            out = subprocess.run(["make", target], cwd=TREE,
                                 capture_output=True, text=True, timeout=900)
            log = out.stdout + out.stderr
        finally:
            for rel, original in originals.items():
                (TREE / rel).write_bytes(original)
        restored = all(sha(TREE / rel) == h for rel, h in anchors.items())
        fails = [l[6:] for l in log.splitlines() if l.startswith("FAIL: ")]
        errors = sum(1 for l in log.splitlines()
                     if l.lstrip().startswith("SCRIPT ERROR"))
        lines.append(f"{rid} [{files}; make {target}] {what}")
        if expect is None:
            hold = not fails and out.returncode == 0
            held += hold
            lines.append(f"    {'CONTROL HOLDS' if hold else 'CONTROL BROKEN'}"
                         f" -- exit {out.returncode}, {len(fails)} failing "
                         f"check(s), {errors} script error(s); restored byte "
                         f"for byte: {restored}")
        else:
            hit = any(expect in f for f in fails)
            caught += hit
            lines.append(f"    {'CAUGHT' if hit else 'NOT CAUGHT'} by "
                         f"\"{expect}\" -- exit {out.returncode}, "
                         f"{len(fails)} failing check(s), {errors} script "
                         f"error(s); restored byte for byte: {restored}")
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
