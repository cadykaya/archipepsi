"""A save must survive everything short of the disk going away.

Save integrity sits second in the correctness order, behind only AP
integrity, and this file holds the two ways a campaign was actually
destroyable.

**Migration.** v7 bounded each Echo separately and let a passive make you
SLOWER (`SPEED_MULT_MIN` was 0.9). v8 traits are always on and stack, so
`_traversal_stats_may_only_help` forbids `move_speed` below 1.0 outright.
The migration copied the multiplier straight across — so a save holding one
legal v7 Echo, anything that read as "heavy", produced a v8 save the model
refuses.

**What happened next is the part that destroys things.** `load_save`
caught, tried the `.bak` (the same v7 file, failing the same way), and
returned None. The engine read None as "no campaign", built a fresh empty
one, and the next write moved the player's real save into the `.bak` slot.
Zones, coins, Echoes, track order — gone, behind one logged exception.

Both halves are fixed and both are tested here: the migration clamps, and
"unreadable" is no longer spelled the same way as "absent".
"""

from __future__ import annotations

import json

import pytest

from archipepsi_bridge import store
from archipepsi_bridge.schemas.migration import (
    migrate_v7_to_v8, traversal_multiplier)
from archipepsi_bridge.schemas.protocol import CampaignSave


def _v7_save(effect_type: str, multiplier: float) -> dict:
    return {
        "save_version": 1, "schema_version": 7, "seed_name": "Seed",
        "team": 0, "slot_id": 1, "slot_name": "Skyiah",
        "completed_zone_count": 4, "coins_spent": 3,
        "generation_counter": 9, "track_order": ["Some Game"],
        "echoes": [{
            "schema_version": 7, "echo_id": "echo_89100002",
            "source_location_id": 89100002, "source_item_name": "Lead Boots",
            "source_game": "Some Game", "source_recipient_name": "P",
            "display_name": "Lead Boots", "description": "Heavy.",
            "archetype": "passive", "activation": "passive", "cooldown": 0.0,
            "effects": [{"type": effect_type, "multiplier": multiplier}],
            "tags": []}]}


# --- migration ------------------------------------------------------------

@pytest.mark.parametrize("multiplier", [0.9, 0.95, 0.99, 1.0, 1.3, 1.6])
def test_every_legal_v7_speed_passive_migrates_to_a_save_that_validates(
        multiplier):
    """The whole v7 legal range, not just the half that happened to be
    legal in v8 too. The migration corpus only ever exercised
    `modify_gravity`, whose v7 ceiling of 1.0 coincides with v8's — which
    is exactly why this shape went unnoticed."""
    migrated = migrate_v7_to_v8(_v7_save("modify_speed", multiplier))
    save = CampaignSave.model_validate(migrated)
    # It folds, too: a save that validates but cannot fold is the other
    # way to lose a campaign.
    assert save.derive() is not None
    assert len(save.interpretations) == 1


@pytest.mark.parametrize("multiplier", [0.35, 0.5, 1.0])
def test_every_legal_v7_gravity_passive_migrates_too(multiplier):
    migrated = migrate_v7_to_v8(_v7_save("modify_gravity", multiplier))
    assert CampaignSave.model_validate(migrated).derive() is not None


def test_the_clamp_keeps_the_echo_rather_than_dropping_it():
    """Clamping loses the downside; dropping would lose the Echo. The
    component stays owned so provenance and the archive remain truthful
    about what the player earned — and what is lost is a penalty the new
    rules would not have let anyone be given in the first place."""
    save = CampaignSave.model_validate(
        migrate_v7_to_v8(_v7_save("modify_speed", 0.9)))
    trait = save.interpretations[0].operations[0].component
    assert trait.stat == "move_speed"
    assert trait.multiplier == 1.0
    assert trait.display_name == "Lead Boots"


def test_the_clamp_only_touches_what_the_floor_forbids():
    """A narrowing, not a flattening: a v7 speed BOOST must survive
    untouched, or the migration would quietly erase every upside too."""
    assert traversal_multiplier("move_speed", 1.6) == 1.6
    assert traversal_multiplier("move_speed", 0.9) == 1.0
    assert traversal_multiplier("gravity", 0.35) == 0.35
    assert traversal_multiplier("gravity", 1.4) == 1.0
    # A stat with no traversal floor keeps whatever it had.
    assert traversal_multiplier("damage_dealt", 0.5) == 0.5


# --- the store ------------------------------------------------------------

def _save(tmp_path, zones: int = 0):
    return CampaignSave(seed_name="Seed", team=0, slot_id=1, slot_name="P",
                        completed_zone_count=zones)


def test_an_unreadable_save_is_not_an_absent_one(tmp_path):
    """The distinction that stops the destruction. An absent campaign
    should be created; an unreadable one must never be silently
    replaced."""
    path = tmp_path / "c.json"
    assert store.load_save(path) is None, "nothing there is still None"

    path.write_text("{ not json")
    with pytest.raises(store.SaveUnreadable):
        store.load_save(path)


def test_a_recovery_repairs_the_primary_it_recovered_from(tmp_path):
    """Without the write-back the corrupt primary survives, and the very
    next ordinary write promotes it into the `.bak` slot — destroying the
    good copy that was just used to recover."""
    path = tmp_path / "c.json"
    store.write_save(path, _save(tmp_path, zones=7))
    store.write_save(path, _save(tmp_path, zones=7))     # make a .bak
    path.write_text("{ torn")

    recovered = store.load_save(path)
    assert recovered is not None and recovered.completed_zone_count == 7
    # The primary is healed, so the next write cannot promote the wreck.
    assert json.loads(path.read_text())["completed_zone_count"] == 7
    store.write_save(path, _save(tmp_path, zones=8))
    backup = json.loads((tmp_path / "c.json.bak").read_text())
    assert backup["completed_zone_count"] == 7, "the .bak is a real save"


def test_a_crash_between_the_renames_leaves_a_primary(tmp_path, monkeypatch):
    """The backup is COPIED rather than renamed for this reason. Renaming
    the primary aside first leaves a window in which no primary exists at
    all, and a crash there produced a directory holding a `.bak` and a
    complete fsynced `.tmp` — with `load_save` reporting no campaign."""
    path = tmp_path / "c.json"
    store.write_save(path, _save(tmp_path, zones=5))

    real_replace = store.os.replace

    def crash_on_install(src, dst):
        if str(dst) == str(path):
            raise OSError("power loss")
        return real_replace(src, dst)

    monkeypatch.setattr(store.os, "replace", crash_on_install)
    with pytest.raises(OSError):
        store.write_save(path, _save(tmp_path, zones=6))
    monkeypatch.undo()

    assert path.exists(), "the primary must never be absent mid-write"
    survived = store.load_save(path)
    assert survived is not None and survived.completed_zone_count == 5


def test_an_in_flight_write_is_read_rather_than_lost(tmp_path):
    """The `.tmp` is fsynced before either rename, so a crash can leave a
    complete newer payload there. Tried last, after the two files that are
    supposed to hold the save."""
    path = tmp_path / "c.json"
    tmp = tmp_path / "c.json.tmp"
    tmp.write_text(_save(tmp_path, zones=11).model_dump_json())
    recovered = store.load_save(path)
    assert recovered is not None and recovered.completed_zone_count == 11


def test_the_engine_refuses_to_start_fresh_over_an_unreadable_save(tmp_path):
    """The whole point, end to end: a campaign that will not parse must not
    be quietly replaced by an empty one.

    The engine reached `store.load_save` returning None and read it as "no
    campaign here". Now the store raises and the engine reports it. What
    matters is not the exception — it is that after the failed connect the
    files on disk are byte-for-byte what they were."""
    from .conftest import connected_engine, run
    from archipepsi_bridge.campaign import IntentError

    engine, _ = run(connected_engine(tmp_path))
    path = engine._save_path
    assert path is not None and path.exists()

    # A real campaign, then a corruption that hits every copy of it.
    wreck = "{ this is not json"
    path.write_text(wreck, encoding="utf-8")
    bak = path.with_suffix(path.suffix + ".bak")
    bak.write_text(wreck, encoding="utf-8")
    before = {p.name: p.read_bytes() for p in tmp_path.iterdir() if p.is_file()}

    async def reconnect():
        with pytest.raises(IntentError) as caught:
            await connected_engine(tmp_path)
        return caught.value

    run(reconnect())

    after = {p.name: p.read_bytes() for p in tmp_path.iterdir() if p.is_file()}
    assert after == before, "a refused load must not write anything"
