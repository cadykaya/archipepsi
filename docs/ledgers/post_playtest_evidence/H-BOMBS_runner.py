"""H-BOMBS sabotages: break one rule, confirm a named failure, restore.

Same protocol as the D-9, D-10, ML-F and H-RAIL-BREADTH runners: each row
edits one file in the wt-bombs work tree, runs `make godot-bombs`, records
every FAIL line, and restores the file byte for byte (sha256 checked). A
row is CAUGHT only when the check it names is among the failures. `--dry`
only counts the anchors. Run only when no other Godot suite is running.

Rows marked REPRO put back the code as it stood before this change: their
failures are the reproduction of that finding on the old code path.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("HB_TREE",
                           Path(__file__).resolve().parent / "wt-bombs"))
HUD = "godot/scripts/ui/hud.gd"
PLAYER = "godot/scripts/gameplay/player.gd"
MAIN = "godot/scripts/main.gd"
TARGET = "godot-bombs"

ROWS = [
    ("HB-1", "REPRO: the consumable row as it was (— or a bare name)", HUD,
     "\t\tif slot == \"consumable\":\n"
     "\t\t\trows.append(\"%s %-5s %s\" % [mark, keycap,\n"
     "\t\t\t\t\t_consumable_row(action)])\n"
     "\t\t\tcontinue\n",
     "",
     "owning a Bomb Bag that is on no key reads differently"),
    ("HB-2", "REPRO: an empty key refuses in silence", PLAYER,
     "\tconsumable_refused.emit(why)\n"
     "\tvar action: Dictionary = BridgeClient.slotted_action(\"consumable\")\n"
     "\tif action.is_empty():\n"
     "\t\treturn\n",
     "\tvar action: Dictionary = BridgeClient.slotted_action(\"consumable\")\n"
     "\tif action.is_empty():\n"
     "\t\treturn\n"
     "\tconsumable_refused.emit(why)\n",
     "none_owned: pressing the key says why nothing happened"),
    ("HB-3", "the refusal never reaches the HUD", HUD,
     "\tplayer.consumable_refused.connect(_on_consumable_refused)\n",
     "",
     "spent: pressing the key says why nothing happened"),
    ("HB-4", "every press toasts, repeated or not", HUD,
     "\tfor child: Node in _toast_box.get_children():\n"
     "\t\tif child is Label and not child.is_queued_for_deletion() \\\n"
     "\t\t\t\tand (child as Label).text == text:\n"
     "\t\t\treturn\n"
     "\ttoast(text, color, seconds)\n",
     "\ttoast(text, color, seconds)\n",
     "pressing it three more times does not stack it"),
    ("HB-5", "REPRO: no word about the key when it arrives", MAIN,
     "\thud.point_at_new_consumables(_snapshot)\n",
     "",
     "a word points at the key it goes on, once"),
    ("HB-6", "the word said on every snapshot, not on arrival", HUD,
     "\t\t\tif not _consumables_owned.has(cid):\n",
     "\t\t\tif true:\n",
     "the next snapshot does not say it again"),
    ("HB-7", "what a campaign first met already owns taken for news", HUD,
     "\tvar fresh: Array = []\n"
     "\tif campaign == _consumables_campaign:\n",
     "\tvar fresh: Array = []\n"
     "\tif campaign != _consumables_campaign:\n"
     "\t\t_consumables_owned = {}\n"
     "\tif true:\n",
     "no word says it just arrived"),
    ("HB-8", "the engine's refusal said a second time", HUD,
     "\tif text == \"\":\n"
     "\t\treturn\n"
     "\tif str(state.get(\"state\", \"\")) == \"owned_not_equipped\":\n",
     "\tif text == \"\":\n"
     "\t\ttext = _why\n"
     "\tif str(state.get(\"state\", \"\")) == \"owned_not_equipped\":\n",
     "the engine's refusal is on screen once, and nothing else is"),
    ("HB-9", "REPRO: the Hub never re-equips on a snapshot", MAIN,
     "\t\t\t\thub.refresh()\n"
     "\t\t\t\t_sync_equipped()\n",
     "\t\t\t\thub.refresh()\n",
     "the engine's answer throws exactly one Bomb Bag"),
    ("HB-10", "a denied use no longer counted as refused", PLAYER,
     "\t\twhy: String) -> void:\n"
     "\t_say_refused(why)\n",
     "\t\twhy: String) -> void:\n"
     "\tpass\n",
     "the refusal still counts as refused"),
    ("HB-11", "an empty supply not marked EMPTY", HUD,
     "\"  EMPTY\" if left <= 0 else \"\"]",
     "\"\"]",
     "spent reads EMPTY on the key"),
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
