"""CK9-F1 sabotages: break one part of "a fight holds the return plug",
confirm the named failure, restore.

Each row makes one or more edits in the work tree, runs `make
godot-room-contract` (whose `_test_a_fight_holds_the_return` stands a
player on a plug and fires, is hit, uses an Action, and shoots once
mid-charge), records every FAIL line, and restores every file byte for
byte (sha256 checked). A row is CAUGHT only when the check it names is
among the failures; a CONTROL row expects none. `--dry` only counts the
anchors.

    HB_TREE=<tree> python3 CK9-F1_runner.py [ROW ...] [--dry]

Rows marked REPRO put back the behaviour as it stood before this change.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("HB_TREE",
                           Path(__file__).resolve().parent / "wt-hbf4a"))
PLUG = "godot/scripts/gameplay/return_plug.gd"
PLAYER = "godot/scripts/gameplay/player.gd"
CONTRACT = "godot-room-contract"

ROWS = [
    ("RF-1", "REPRO: the plug charges whatever its occupant is doing",
     [(PLUG, '''	if _occupant != null and is_instance_valid(_occupant) \\
			and _occupant.fought_within(FIGHT_QUIET_SECONDS):''',
       '''	if false and _occupant != null and is_instance_valid(_occupant) \\
			and _occupant.fought_within(FIGHT_QUIET_SECONDS):''')],
     "with the Static Pulse held down", CONTRACT),
    ("RF-2", "being hurt is not fighting",
     [(PLAYER, '''	damaged_from.emit(source_position)
	_note_fight()
''', '''	damaged_from.emit(source_position)
''')], "while being hit every 0.5 s does not return", CONTRACT),
    ("RF-3", "a fight pauses the charge instead of dropping it",
     [(PLUG, '''			and _occupant.fought_within(FIGHT_QUIET_SECONDS):
		_held = 0.0
		_held_back()''', '''			and _occupant.fought_within(FIGHT_QUIET_SECONDS):
		_held_back()''')], "into the charge drops it", CONTRACT),
    ("RF-4", "no quiet owed: a fight holds the plug only on its own frame",
     [(PLUG, '''const FIGHT_QUIET_SECONDS := 1.0''',
       '''const FIGHT_QUIET_SECONDS := 0.0''')],
     "with the Static Pulse held down", CONTRACT),
    ("RF-5", "the device does not say why it is not charging",
     [(PLUG, '''	_idle()
	if _label != null:
		_label.text = FIGHTING_LABEL''', '''	_idle()''')],
     "and the device says why", CONTRACT),
    ("RF-6", "using an Action is not fighting",
     [(PLAYER, '''	fired_pulse.connect(_note_fight)
	for runtime: EchoRuntime in runtimes.values():
		runtime.action_used.connect(_note_fight)
''', '''	fired_pulse.connect(_note_fight)
''')], "while using an Action every 0.5 s does not return", CONTRACT),
    ("RF-C1", "CONTROL: a longer hold is still a hold a fight resets",
     [(PLUG, '''const HOLD_SECONDS := 2.0''', '''const HOLD_SECONDS := 2.5''')],
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
