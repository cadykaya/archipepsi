"""H-BOMBS slice 2 sabotages: break one link of the live receipt, confirm
the live phase names it, restore.

Same protocol as the slice 1 runner, run against one phase of
`godot-bombs-live` rather than the whole walk: each row edits one file in
the slice 2 work tree, puts back the save that phase starts from (taken
from a clean run of the phase before it), runs that phase exactly as the
Makefile does (a new bridge beside a new client), records every FAIL
line, and restores the file byte for byte (sha256 checked). A row is
CAUGHT only when the check it names is among the failures.

    HB_TREE=<slice 2 tree> HB_SAVES=<dir with after_reach/ after_claim/> \\
        python3 H-BOMBS2_runner.py [ROW ...] [--dry]

The start saves are the tree's `.bombs-saves` copied after a clean
`H-BOMBS2_phase.sh <tree> reach` (as `after_reach/`) and after a clean
`claim` from that (as `after_claim/`). `H-BOMBS2_phase.sh` is one phase
exactly as the Makefile runs it, plus the harness's Bomb Bag ids.

Rows marked REPRO put back the code as it stood before this slice.
"""
from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

TREE = Path(os.environ.get("HB_TREE",
                           Path(__file__).resolve().parent / "wt-bombs"))
SAVES = Path(os.environ.get("HB_SAVES",
                            Path(__file__).resolve().parent / "saves"))
_HERE = Path(__file__).resolve().parent
PHASE = next((p for p in (_HERE / "H-BOMBS2_phase.sh", _HERE / "phase.sh")
              if p.exists()), _HERE / "H-BOMBS2_phase.sh")

MAIN = "godot/scripts/main.gd"
REVEAL = "godot/scripts/ui/reveal.gd"
PLAYER = "godot/scripts/gameplay/player.gd"
CAMPAIGN = "bridge/archipepsi_bridge/campaign.py"
TRANSITIONS = "bridge/archipepsi_bridge/schemas/transitions.py"

ROWS = [
    ("SL-1", "the arrival points at nothing (HB-F2's word about the key)",
     MAIN, "claim",
     "\thud.point_at_new_consumables(_snapshot)\n",
     "\tpass\n",
     "one word points at the key"),
    ("SL-2", "REPRO: the card is drawn once, before the Echo is known (HB-F5)",
     REVEAL, "claim",
     "\tBridgeClient.snapshot_received.connect(_on_snapshot)\n",
     "",
     "the card shows the Bomb Bag and its slot"),
    ("SL-3", "Q asks the bridge for nothing",
     PLAYER, "claim",
     "\tBridgeClient.authorize_consumable(component_id)\n",
     "\tpass\n",
     "Q: one authorisation asked"),
    ("SL-4", "the bridge hears the request and grants nothing",
     CAMPAIGN, "claim",
     "            self._apply(T.authorize_consumable(\n"
     "                self.save, component_id, use_index=use_index,\n"
     "                generation=generation))\n",
     "            pass\n",
     "Q: one authorisation asked"),
    ("SL-5", "entering a new Zone refills nothing",
     TRANSITIONS, "refill",
     "def _refill_is_due(save: CampaignSave, zone_id: str) -> bool:\n",
     "def _refill_is_due(save: CampaignSave, zone_id: str) -> bool:\n"
     "    return False\n",
     "entering it refilled the supply"),
]

#: The save each phase starts from: the one the phase before it left.
START = {"claim": "after_reach", "refill": "after_claim"}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def restore_saves(phase: str) -> None:
    live = TREE / ".bombs-saves"
    if live.exists():
        shutil.rmtree(live)
    shutil.copytree(SAVES / START[phase], live)


def main() -> int:
    args = sys.argv[1:]
    dry = "--dry" in args
    only = {a for a in args if not a.startswith("--")}
    lines, caught, total = [], 0, 0
    for rid, what, rel, phase, old, new, expect in ROWS:
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
            print(f"{rid} anchor ok ({rel}, phase {phase})", flush=True)
            continue
        before = hashlib.sha256(original).hexdigest()
        restore_saves(phase)
        log_path = Path(f"/tmp/h-bombs2-{rid}.log")
        path.write_bytes(text.replace(old, new).encode("utf-8"))
        try:
            out = subprocess.run(["bash", str(PHASE), str(TREE), phase,
                                  str(log_path)],
                                 capture_output=True, text=True, timeout=1500)
        finally:
            path.write_bytes(original)
        restored = sha(path) == before
        log = log_path.read_text(errors="replace") \
            if log_path.exists() else out.stdout
        fails = [l[6:] for l in log.splitlines() if l.startswith("FAIL: ")]
        errors = sum(1 for l in log.splitlines()
                     if l.lstrip().startswith("SCRIPT ERROR"))
        hit = any(expect in f for f in fails)
        caught += hit
        lines.append(f"{rid} [{rel.split('/')[-1]}, {phase}] {what}")
        lines.append(f"    {'CAUGHT' if hit else 'NOT CAUGHT'} by \"{expect}\""
                     f" -- exit {out.returncode}, {len(fails)} failing "
                     f"check(s), {errors} script error(s); restored byte for "
                     f"byte: {restored}")
        for f in dict.fromkeys(fails):
            lines.append(f"      FAIL: {f[:400]}")
        print("\n".join(lines[-(len(dict.fromkeys(fails)) + 2):]), flush=True)
    if not dry:
        lines.append(f"\n{caught} of {total} sabotages caught")
        print(lines[-1])
    return 0 if dry or caught == total else 1


if __name__ == "__main__":
    sys.exit(main())
