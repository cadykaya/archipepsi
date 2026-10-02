"""HB-F4b sabotages: break one rule, confirm a named failure, restore.

Same protocol as the H-BOMBS and H-RAIL-BREADTH runners: each row edits
chamber_builders.gd in the wt-hbf4 work tree, runs
`make godot-room-contract` (its doorway census), records every FAIL line,
and restores the file byte for byte (sha256 checked). A row is CAUGHT only
when the check it names is among the failures. `--dry` only counts the
anchors. Run only when no other Godot suite is running.

Rows marked REPRO put back the code as it stood before this change.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("HB_TREE",
                           Path(__file__).resolve().parent / "wt-hbf4"))
CB = "godot/scripts/generation/chamber_builders.gd"
TARGET = "godot-room-contract"
OWNERS = "the owner's two rooms"
CENSUS = "and none measures solid"

ROWS = [
    ("HF-1", "REPRO: the oil drum stands wherever it was rolled", CB,
     "\t\t\t\t\tvar drum_z := _clear_of_side_door(z, 2.0 * 0.42,\n"
     "\t\t\t\t\t\t\tspan_z) if door_cut else z\n",
     "\t\t\t\t\tvar drum_z := z\n",
     OWNERS),
    ("HF-2", "REPRO: the column stump stands wherever it was rolled", CB,
     "\t\t\t\t\tvar stump_z := _clear_of_side_door(z, 2.0 * 0.55,\n"
     "\t\t\t\t\t\t\tspan_z) if door_cut else z\n",
     "\t\t\t\t\tvar stump_z := z\n",
     CENSUS),
    ("HF-3", "a corridor's props never told which doors it has", CB,
     "\t\t\t_greeble_rng(chamber, theme), corridor_cut)\n",
     "\t\t\t_greeble_rng(chamber, theme))\n",
     OWNERS),
    ("HF-4", "an arena's props never told which doors it has", CB,
     "\t_theme_props(root, theme, rng, width, depth, height, cut)\n",
     "\t_theme_props(root, theme, rng, width, depth, height)\n",
     OWNERS),
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
            lines.append(f"      FAIL: {f[:400]}")
        print("\n".join(lines[-(len(fails) + 2):]), flush=True)
    if not dry:
        lines.append(f"\n{caught} of {total} sabotages caught")
        print(lines[-1])
    return 0 if dry or caught == total else 1


if __name__ == "__main__":
    sys.exit(main())
