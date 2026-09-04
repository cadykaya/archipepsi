#!/usr/bin/env python3
"""Generate THIRD_PARTY_NOTICES.md from the asset licence manifest.

    make notices

Generated, never hand-edited: a credits file maintained by hand is a
credits file that is wrong, and being wrong about attribution is the one
kind of wrong that has consequences beyond the repository.

`assets/LICENSES.json` is the source. `test_packaging.py` fails if the
generated file is stale, the same way the schema exports are guarded.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets" / "LICENSES.json"
NOTICES = ROOT / "THIRD_PARTY_NOTICES.md"


def render() -> str:
    data = json.loads(MANIFEST.read_text())
    third_party = data.get("third_party", [])

    lines = [
        "# Third-party notices",
        "",
        "**Generated from `assets/LICENSES.json` — do not edit.**",
        "Regenerate with `make notices`.",
        "",
    ]

    if not third_party:
        lines += [
            "Archipepsi currently bundles **no third-party assets**.",
            "",
            "Everything shipped is first-party, which includes assets a",
            "developer authored with Claude and then reviewed, approved,",
            "committed and registered under a stable id",
            "(`docs/design-packet-v0.9/OWNER_DECISIONS.md` D2).",
            "",
            "This file exists and is checked so that the first",
            "third-party asset to arrive cannot arrive unattributed.",
        ]
        return "\n".join(lines) + "\n"

    lines.append(f"Archipepsi bundles {len(third_party)} third-party "
                 f"asset(s).\n")
    for entry in sorted(third_party, key=lambda e: e.get("path", "")):
        lines += [
            f"## {entry.get('name', entry.get('path', '?'))}",
            "",
            f"- **File:** `{entry.get('path', '?')}`",
            f"- **Author:** {entry.get('author', '?')}",
            f"- **Licence:** {entry.get('license', '?')}",
        ]
        if entry.get("source_url"):
            lines.append(f"- **Source:** {entry['source_url']}")
        if entry.get("attribution_required"):
            lines.append(
                f"- **Attribution shown in:** "
                f"{entry.get('attribution_location', 'UNSPECIFIED')}")
        lines.append("")
    return "\n".join(lines) + "\n"


def main() -> int:
    NOTICES.write_text(render())
    print(f"  wrote {NOTICES.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
