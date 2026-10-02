"""HB-O1 sabotages: break one part of the owner's ruling, confirm the named
failure, restore.

Each row makes one or more edits in the work tree, runs its suite --
`make godot-bombs` (whose `_a_granted_use` presses Q the way the owner did,
under the claim's card after EQUIPMENT closed, and whose
`_a_held_press_says_why` presses under the layout hold) or `make
godot-carry` (the Static Pulse pressed while carrying) -- records every
FAIL line, and restores every file byte for byte (sha256 checked). A row is CAUGHT only when the check it
names is among the failures; a CONTROL row expects none. `--dry` only
counts the anchors.

    HB_TREE=<tree> python3 HB-O1_runner.py [ROW ...] [--dry]

Rows marked REPRO put back the behaviour as it stood before this change.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("HB_TREE",
                           Path(__file__).resolve().parent / "wt-bombs"))
MAIN = "godot/scripts/main.gd"
CARD = "godot/scripts/ui/reveal.gd"
PLAYER = "godot/scripts/gameplay/player.gd"
HUD = "godot/scripts/ui/hud.gd"
F3 = "godot/scripts/ui/debug_overlay.gd"
BOMBS = "godot-bombs"
CARRY = "godot-carry"

# The card back on the modal list, and its coming and going telling Main
# again, as they stood.
MODAL_AGAIN = [
    (MAIN,
     '''	# A pickup card is not modal (HB-O1), so its coming and going changes
	# nothing `_update_modal` decides.
	shop.closed.connect(_update_modal)''',
     '''	reveal.reveal_started.connect(_update_modal)
	reveal.reveal_finished.connect(_update_modal)
	shop.closed.connect(_update_modal)'''),
    (MAIN,
     '''			or shop.visible or station_panel.visible
	var player: Player = null''',
     '''			or shop.visible or reveal.visible or station_panel.visible
	var player: Player = null'''),
]
NO_HURRY = [
    (CARD,
     '''func _physics_process(_delta: float) -> void:
	if not visible or _hurried:
		return''',
     '''func _physics_process(_delta: float) -> void:
	if true:
		return'''),
]

ROWS = [
    ("RO-1", "REPRO: the card is modal again and does not see a press",
     MODAL_AGAIN + NO_HURRY, "Q under the card asks the bridge for a use",
     BOMBS),
    ("RO-2", "the card's controls keep their default mouse filters",
     [(CARD, '''	add_child(_flash)
	_let_input_through(self)
''', '''	add_child(_flash)
''')], "and takes no mouse movement anywhere on screen", BOMBS),
    ("RO-3", "Q merely closes the card: modal, and a press dismisses it",
     MODAL_AGAIN, "Q under the card asks the bridge for a use", BOMBS),
    ("RO-4", "a press cuts the card short and throws the queue away",
     [(CARD, '''	_hurried = true
	_serial += 1
''', '''	_hurried = true
	_queue.clear()
	_serial += 1
''')], "the next card follows in full", BOMBS),
    ("RO-5", "a press the layout hold stops is lost without a word",
     [(PLAYER, '''	_tell_why_held()
	if not input_frozen:''', '''	if not input_frozen:''')],
     "Q under the layout hold asks for nothing and says why", BOMBS),
    ("RO-6", "said on every press, a column of it",
     [(HUD, '''	say_once(held_words(reason), Color(1.0, 0.85, 0.55), 2.5)''',
       '''	toast(held_words(reason), Color(1.0, 0.85, 0.55), 2.5)''')],
     "once on screen, however often it is pressed", BOMBS),
    ("RO-7", "a walk key held down since before the hold is not told",
     [(PLAYER, '''	if not pressed and _told_hold != reason:''',
       '''	if false:''')],
     "a walk key held down since before the hold is told too", BOMBS),
    ("RO-8", "a menu's own hold is told too, over the open menu",
     [(PLAYER, '''	if _holds.is_empty() or _holds.has(MODAL_HOLD):''',
       '''	if _holds.is_empty():''')],
     "under a menu's hold a press asks for nothing and adds nothing",
     BOMBS),
    ("RO-9", "the F3 readout's panel keeps its default mouse filter",
     [(F3, '''	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
''', '''	add_child(panel)
''')], "the F3 readout and the navigation schematic, open over it, take "
     "none either", BOMBS),
    ("RO-10", "REPRO: the Static Pulse blocked while carrying says nothing",
     [(PLAYER, '''			elif Input.is_action_just_pressed("fire_pulse"):
				carry_feedback.emit("PULSE BLOCKED WHILE CARRYING", false)
''', '''			elif false:
				carry_feedback.emit("PULSE BLOCKED WHILE CARRYING", false)
''')], "and says so, once for a press held down 40 frames", CARRY),
    ("RO-11", "…said on every frame the button is down",
     [(PLAYER, '''			elif Input.is_action_just_pressed("fire_pulse"):
				carry_feedback.emit("PULSE BLOCKED WHILE CARRYING", false)
''', '''			else:
				carry_feedback.emit("PULSE BLOCKED WHILE CARRYING", false)
''')], "and says so, once for a press held down 40 frames", CARRY),
    ("RO-C1", "CONTROL: a faster fade is still a card making way",
     [(CARD, '''const HURRY_SECONDS := 0.25''', '''const HURRY_SECONDS := 0.1''')],
     None, BOMBS),
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
