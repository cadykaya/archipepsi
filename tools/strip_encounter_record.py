"""Make a COPY of a save look like one written before per-enemy records
existed (H-RESUME-R, V-07: "load copied save lacking new fields").

Removes `defeated` from every Zone's `progress` in the campaign save(s)
of ONE directory, in place. It exists for `make godot-resume-live`, whose
`legacy` phase needs a save from before the field -- produced honestly,
from a real save, by deleting exactly the field the old code never wrote.

**It refuses any directory but a resume-test copy.** A real player's
save is never an input: the directory's name must begin
`.resume-saves-legacy`.

    python tools/strip_encounter_record.py .resume-saves-legacy
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2
    target = Path(argv[1]).resolve()
    if not target.name.startswith(".resume-saves-legacy"):
        print(f"refusing {target}: not a resume-test copy")
        return 2
    stripped = 0
    for path in sorted(target.glob("*.json")):
        data = json.loads(path.read_text())
        zones = data.get("zones") if isinstance(data, dict) else None
        if not isinstance(zones, list):
            continue
        for record in zones:
            progress = record.get("progress") if isinstance(record, dict) \
                else None
            if isinstance(progress, dict) and "defeated" in progress:
                del progress["defeated"]
                stripped += 1
        path.write_text(json.dumps(data, indent=2))
    # The one-generation backup would otherwise still hold the field.
    for bak in target.glob("*.json.bak"):
        bak.unlink()
    print(f"stripped the per-enemy record from {stripped} Zone(s) in "
          f"{target.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
