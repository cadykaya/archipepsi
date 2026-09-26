"""HB-F4: every composition the campaign could not stand in, measured again
on this tree.

Each Zone file is laid out by this revision's engine (the layout walk's
tool: `ZoneBuilder`, `RoomAudit.measure_layout`, `ChainCertificate`) and
judged by this revision's bridge (`layout.validate`), the two halves
`handle_layout_result` joins. Prints the verdict and every reason.

    cd <tree>/bridge && python3 remeasure_tmp.py ZONE.json [...]

Installed as `bridge/remeasure_tmp.py` beside the layout walk's tool
(`HB-F4_layout_walk.py` says where each file goes), and removed after.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path.cwd()))

from archipepsi_bridge import layout as L                  # noqa: E402
from archipepsi_bridge.schemas.zone import Zone            # noqa: E402

TREE = Path.cwd().parent
GODOT = TREE / "godot-bin" / "godot"


def measure(path: Path, tmp: Path) -> dict:
    out = tmp / "layout.json"
    out.unlink(missing_ok=True)
    subprocess.run([str(GODOT), "--headless", "--path", str(TREE / "godot"),
                    "res://layout_walk_tmp.tscn", "--", str(path), str(out)],
                   capture_output=True, timeout=600)
    return json.loads(out.read_text()) if out.exists() \
        else {"failed": "the layout tool wrote nothing"}


def main(paths: list[str]) -> None:
    with tempfile.TemporaryDirectory() as tmp_name:
        for raw in paths:
            path = Path(raw)
            content = json.loads(path.read_text())
            result = measure(path, Path(tmp_name))
            if "failed" in result:
                print(f"{path.name}: BUILD FAILED: {result['failed']}")
                continue
            verdict = L.validate(Zone.model_validate(content),
                                 result["layout"])
            print(f"{path.name}: {verdict.status}"
                  f" (controller {result['layout']['controller_digest']})")
            for error in verdict.errors:
                print(f"    {error}")
            sys.stdout.flush()


if __name__ == "__main__":
    main(sys.argv[1:])
