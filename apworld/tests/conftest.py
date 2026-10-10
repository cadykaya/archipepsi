"""Make the pinned Archipelago checkout importable for APWorld tests.

SKIP_REQUIREMENTS_UPDATE must be set BEFORE anything imports CommonClient or
Generate; ModuleUpdate.update() otherwise drops into a bare input().
"""

import os
import sys
from pathlib import Path

os.environ.setdefault("SKIP_REQUIREMENTS_UPDATE", "1")

REPO_ROOT = Path(__file__).resolve().parents[2]
AP_ROOT = Path(
    os.environ.get("ARCHIPELAGO_ROOT", REPO_ROOT / ".archipelago")
).resolve()

if AP_ROOT.is_dir() and str(AP_ROOT) not in sys.path:
    sys.path.insert(0, str(AP_ROOT))

# Ensure the world is installed in the checkout (same as `make world-install`).
_world_link = AP_ROOT / "worlds" / "archipepsi"
_world_src = REPO_ROOT / "apworld" / "archipepsi"
if AP_ROOT.is_dir() and not _world_link.exists():
    _world_link.symlink_to(_world_src)
