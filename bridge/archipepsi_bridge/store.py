"""Atomic campaign persistence.

Write: temp file, flush, fsync, os.replace; keep one previous generation as
`.bak`. Load: primary, falling back to `.bak` loudly. The save is a
`CampaignSave` value object; this module never edits one.
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import shutil
from pathlib import Path

from .schemas.echo import SCHEMA_VERSION
from .schemas.migration import migrate_save_dict
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


class SaveUnreadable(Exception):
    """Save files exist and none of them could be read.

    Distinct from "no save", and the distinction is the whole point: an
    absent campaign should be created, an unreadable one must never be
    silently replaced by an empty one. `load_save` returns None only for
    the first case.
    """


def write_save(path: Path, save: CampaignSave) -> None:
    """Atomic: tmp + fsync + replace, keeping one `.bak` generation.

    The backup is COPIED rather than renamed. Renaming the primary aside
    first leaves a window — between the two renames — in which no primary
    exists at all; a crash there produced a directory holding a `.bak` and
    a complete, fsynced `.tmp`, and a `load_save` that reported no
    campaign. Copying means the primary is only ever replaced, never
    absent.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = save.model_dump_json(indent=2)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
        f.flush()
        os.fsync(f.fileno())
    if path.exists():
        bak = path.with_suffix(path.suffix + ".bak")
        shutil.copy2(path, bak)
        _fsync_file(bak)
    os.replace(tmp, path)
    # The renames themselves need syncing, or the ordering above is only
    # true in the page cache: a power loss can otherwise land the new
    # payload without the directory entry that names it.
    _fsync_dir(path.parent)
    log.debug("wrote save %s (%d zones, %d interpretations)", path,
              len(save.zones), len(save.interpretations))


def _fsync_file(path: Path) -> None:
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError:                              # pragma: no cover
        return
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _fsync_dir(directory: Path) -> None:
    """Not every platform can fsync a directory; the ones that cannot are
    the ones where it was never the durability barrier."""
    try:
        fd = os.open(directory, os.O_RDONLY)
    except OSError:                              # pragma: no cover
        return
    try:
        os.fsync(fd)
    except OSError:                              # pragma: no cover
        pass
    finally:
        os.close(fd)


def load_save(path: Path) -> CampaignSave | None:
    """Load the primary, falling back loudly. None only if NOTHING is there.

    Raises `SaveUnreadable` when files exist but none of them load. The
    caller must not treat that as an absent campaign: `CampaignEngine`
    creates a fresh save when this returns None, and its next write moves
    the player's real save into the `.bak` slot. A save that cannot be read
    is a problem to report, not a campaign to replace.

    The `.tmp` is a candidate too, and last. It is fsynced before either
    rename, so a crash mid-write can leave a complete newer payload sitting
    there while the primary is the previous generation — worth preferring
    over nothing at all, and worth trying only after the two files that are
    supposed to hold the save.
    """
    candidates = ((path, "primary"),
                  (path.with_suffix(path.suffix + ".bak"), "backup"),
                  (path.with_suffix(path.suffix + ".tmp"), "in-flight"))
    tried = 0
    for candidate, label in candidates:
        if not candidate.exists():
            continue
        tried += 1
        try:
            raw = json.loads(candidate.read_text(encoding="utf-8"))
            version = raw.get("schema_version")
            if version != SCHEMA_VERSION:
                # Migrate BEFORE validating, and validate the result like any
                # other save. A migration that produced something the models
                # reject is a migration that failed, and it should fail here,
                # at load, rather than somewhere downstream.
                raw = migrate_save_dict(raw)
                log.info("migrated %s save %s from schema_version %s to %s",
                         label, candidate, version, SCHEMA_VERSION)
                migrated = True
            else:
                migrated = False
            save = CampaignSave.model_validate(raw)
        except Exception:
            log.exception("failed to load %s save %s", label, candidate)
            continue
        if migrated or label != "primary":
            # Written back immediately. A migration that only lives in
            # memory runs again on every load, and the first crash after it
            # loses whichever half was in flight.
            #
            # A RECOVERY is written back for a sharper reason: without it
            # the unreadable primary survives, and the very next ordinary
            # write promotes it into the `.bak` slot — destroying the good
            # copy that was just used to recover.
            write_save(path, save)
        if label != "primary":
            log.error("primary save unreadable; recovered from %s copy %s",
                      label, candidate)
        return save
    if tried:
        raise SaveUnreadable(
            f"{tried} save file(s) exist at {path} and none could be read; "
            "refusing to start a fresh campaign over them")
    return None
