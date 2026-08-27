"""Atomic campaign persistence.

Write: temp file, flush, fsync, os.replace; keep one previous generation as
`.bak`. Load: primary, falling back to `.bak` loudly. The save is a
`CampaignSave` value object; this module never edits one.
"""

from __future__ import annotations

import hashlib
import logging
import os
import re
from pathlib import Path

from .schemas.protocol import CampaignSave

log = logging.getLogger("archipepsi.store")

DEFAULT_SAVE_DIR = Path(
    os.environ.get("ARCHIPEPSI_SAVE_DIR", Path.cwd() / "saves"))


def campaign_key(seed_name: str, team: int, slot_id: int) -> str:
    raw = f"{seed_name}|{team}|{slot_id}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


def _sanitize_slot(slot_name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_-]", "_", slot_name)[:32] or "slot"


def save_path(save_dir: Path, seed_name: str, team: int, slot_id: int,
              slot_name: str) -> Path:
    key = campaign_key(seed_name, team, slot_id)
    return save_dir / f"{key}__{_sanitize_slot(slot_name)}.json"


def write_save(path: Path, save: CampaignSave) -> None:
    """Atomic: tmp + fsync + replace, keeping one `.bak` generation."""
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = save.model_dump_json(indent=2)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
        f.flush()
        os.fsync(f.fileno())
    if path.exists():
        bak = path.with_suffix(path.suffix + ".bak")
        os.replace(path, bak)
    os.replace(tmp, path)
    log.debug("wrote save %s (%d zones, %d echoes)", path,
              len(save.zones), len(save.echoes))


def load_save(path: Path) -> CampaignSave | None:
    """Load the primary, falling back to `.bak` loudly. None if neither."""
    for candidate, label in ((path, "primary"),
                             (path.with_suffix(path.suffix + ".bak"), "backup")):
        if not candidate.exists():
            continue
        try:
            save = CampaignSave.model_validate_json(
                candidate.read_text(encoding="utf-8"))
        except Exception:
            log.exception("failed to load %s save %s", label, candidate)
            continue
        if label == "backup":
            log.error("primary save unreadable; recovered from backup %s",
                      candidate)
        return save
    return None
