"""HB-F4e sabotages: break one part of the rule, confirm the named checks
fail, restore.

Same protocol as the HB-F4a and HB-F4b runners. Each row edits one file in
the HB-F4e work tree and runs `make godot-room-contract`, whose
`_test_no_prop_stands_in_a_feature` holds the census and certifies the
owner's two rooms. It records every FAIL line, then restores the file byte
for byte (sha256 checked). A row is CAUGHT only when EVERY check it names
is among the failures. `--dry` only counts the anchors.

    HB_TREE=<tree> python3 HB-F4e_runner.py [ROW ...] [--dry]

Rows marked REPRO put back the behaviour as it stood before this change.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("HB_TREE",
                           Path(__file__).resolve().parent / "wt-hbf4e"))
CB = "godot/scripts/generation/chamber_builders.gd"
AF = "godot/scripts/generation/affordance_features.gd"
TARGET = "godot-room-contract"

CENSUS = "no prop stands on a feature's floor"
RADIUS = "within a body's radius of it"
DOORWAY = "no prop stands within a body's radius of an open side doorway"
ASTRAY = "every feature `place_all` builds stands inside a floor"
OWNER_010 = "zone_010 c001: its powered door's plate latches in all three runs"
OWNER_012 = "zone_012 c001: its powered door's plate latches in all three runs"

ROWS = [
    ("RE-1", "REPRO: the corridor tells its props nothing about its features",
     CB,
     '''			AffordanceFeatures.footprints(chamber, width, length))
''',
     '''			[])
''',
     [CENSUS, OWNER_010, OWNER_012]),
    ("RE-2", "a column stump ignores the features", CB,
     '''					var stump_z := _floor_prop_z(z, side * (wall_x - 0.85),
							0.55, span_z, door_cut, keep_out)
''',
     '''					var stump_z := _floor_prop_z(z, side * (wall_x - 0.85),
							0.55, span_z, door_cut, [])
''',
     [CENSUS, OWNER_010, OWNER_012]),
    ("RE-3", "an oil drum ignores the features", CB,
     '''					var drum_z := _floor_prop_z(z, side * (wall_x - 0.75),
							0.42, span_z, door_cut, keep_out)
''',
     '''					var drum_z := _floor_prop_z(z, side * (wall_x - 0.75),
							0.42, span_z, door_cut, [])
''',
     [CENSUS]),
    ("RE-4", "a prop may stand against a feature, with no body's width between",
     CB,
     '''	var reach := radius + Constants.PLAYER_RADIUS
''',
     '''	var reach := radius
''',
     [RADIUS]),
    ("RE-5", "the footprint forgets the side-doorway move place_all makes", AF,
     '''		var origin: Vector3 = placed["origin"]
		if not is_finite(origin.z):
			continue
		var reach: Dictionary = FOOTPRINT.get(str(placed["tag"]), {})
''',
     '''		var origin: Vector3 = resolve_position((chamber["features"][
				int(placed["index"])] as Dictionary).get("at", [0.5, 0.5]),
				width, depth, str(placed["tag"]))
		if not is_finite(origin.z):
			continue
		var reach: Dictionary = FOOTPRINT.get(str(placed["tag"]), {})
''',
     [ASTRAY]),
    ("RE-6", "a prop moved off a feature may land in a side doorway", CB,
     '''		if door_cut and _clear_of_side_door(at, 2.0 * radius,
				span_z) != at:
			continue
''',
     '',
     [DOORWAY]),
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
        census = [l.strip() for l in log.splitlines()
                  if "features across" in l and not l.startswith("FAIL")]
        missing = [e for e in expect if not any(e in f for f in fails)]
        hit = not missing
        caught += hit
        lines.append(f"{rid} [{rel.split('/')[-1]}] {what}")
        lines.append(f"    {'CAUGHT' if hit else 'NOT CAUGHT'} by "
                     + " + ".join(f'"{e}"' for e in expect)
                     + f" -- exit {out.returncode}, {len(fails)} failing "
                     f"check(s), {errors} script error(s); restored byte for "
                     f"byte: {restored}")
        if missing:
            lines.append(f"      not failing: {missing}")
        for c in census:
            lines.append(f"      census: {c}")
        for f in fails:
            lines.append(f"      FAIL: {f[:400]}")
        print("\n".join(lines[-(len(fails) + len(census) + 2
                                + (1 if missing else 0)):]), flush=True)
    if not dry:
        lines.append(f"\n{caught} of {total} sabotages caught")
        print(lines[-1])
    return 0 if dry or caught == total else 1


if __name__ == "__main__":
    sys.exit(main())
