"""H-KEYS — the key audit reports each class it claims to, on real Zones.

The committed sample reads 80 of 80 keys as met-before-the-lock. A
result that uniform is only evidence if the audit can say anything
else, so every class is produced here from a schema-valid mutation of a
real sample Zone.
"""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import pytest

from archipepsi_bridge.schemas.zone import Zone

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "bridge" / "tools"))
import audit_local_keys as A  # noqa: E402

SAMPLE = ROOT / "godot" / "tests" / "fixtures" / "sample" / "zone_01.json"


def _raw() -> dict:
    return json.loads(SAMPLE.read_text(encoding="utf-8"))


def _row(raw: dict, key: str) -> dict:
    return next(r for r in A.audit_zone(Zone.model_validate(raw))
                if r["key"] == key)


def test_every_sample_key_opens_a_lock_that_guards_a_check():
    rows = A.audit_zone(Zone.model_validate(_raw()))
    assert rows and all(r.get("gates") == "GATES_CHECK" for r in rows)


def test_the_sample_meets_every_key_before_its_lock():
    """The finding itself, on one Zone: keys early on the route, locks
    later, so each door is reached with its key already in hand."""
    rows = A.audit_zone(Zone.model_validate(_raw()))
    assert {r["class"] for r in rows} == {"KEY_FIRST"}


def test_a_key_that_opens_nothing_is_named():
    """The Zone model still loads one, so a save never breaks on it;
    acceptance refuses it (DESS-23), and the composer never makes one
    (0 of 80)."""
    raw = _raw()
    for c in raw["chambers"]:
        for d in c["doors"]:
            if d.get("key_id") == "red" and d["usage"] == "LOCKED":
                d["usage"] = "USED"
                d.pop("key_id")
                d.pop("colour", None)
    assert _row(raw, "red")["class"] == "NO_LOCK"
    from archipepsi_bridge.schemas.zone import validate_zone
    zone = Zone.model_validate(raw)
    errors = validate_zone(zone, expected_zone_id=zone.zone_id,
                           allocated_location_ids=list(
                               zone.reward_location_ids),
                           owned_echo_ids=[])
    assert any("key 'red'" in e and "opens no locked door" in e
               for e in errors), errors


def test_no_committed_zone_holds_a_key_that_opens_nothing():
    from archipepsi_bridge.schemas.zone import _keys_that_open_nothing
    paths = sorted(SAMPLE.parent.glob("zone_*.json")) + [
        ROOT / "godot/tests/fixtures/candidate_zone.json"]
    for path in paths:
        raw = json.loads(path.read_text(encoding="utf-8"))
        zone = Zone.model_validate(raw.get("zone", raw))
        assert _keys_that_open_nothing(zone) == [], path.name


def test_a_key_found_beside_its_own_lock_is_met_with_it():
    raw = _raw()
    home = next(c for c in raw["chambers"]
                if any(k["key_id"] == "red" for k in c["keys"]))
    lock_room = next(c for c in raw["chambers"]
                     if any(d.get("key_id") == "red" for d in c["doors"]))
    key = next(k for k in home["keys"] if k["key_id"] == "red")
    home["keys"].remove(key)
    lock_room["keys"].append(key)
    assert _row(raw, "red")["class"] == "GATES_CHECK"


def test_a_lock_that_guards_nothing_is_named():
    raw = _raw()
    zone = Zone.model_validate(raw)
    behind = set(_row(raw, "red")["behind"])
    moved = []
    for c in raw["chambers"]:
        if c["id"] in behind:
            if c.get("reward_location_id") is not None:
                moved.append(c["reward_location_id"])
                c["reward_location_id"] = None
            c["additional_reward_location_ids"] = []
            c["keys"] = []
    if not moved:
        pytest.skip("red's branch held no primary Check to move")
    try:
        Zone.model_validate(raw)
    except ValueError:
        pytest.skip("the schema refuses this Zone without those Checks")
    assert _row(raw, "red")["class"] == "NOTHING"
    assert zone  # the unmutated Zone was valid too
