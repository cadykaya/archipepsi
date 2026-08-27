"""S1 — the v7 save corpus, replay compatibility, and the fold benchmark.

A migration is the one change that can destroy a campaign somebody already
played, so the bar here is higher than "the models accept it": every save in
the corpus must load through the real `store`, fold, write back, and reload
byte-identically.

The corpus is hand-built rather than captured, because the shapes that
matter are the ones a captured save would only cover by luck: an empty
campaign, a passive equipped, and — the one this whole ordering exists for —
an echo order that does NOT match location order.
"""

from __future__ import annotations

import json
import time
from pathlib import Path

import pytest

from archipepsi_bridge import store
from archipepsi_bridge.replay_archive import replay_one
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas.echo import SCHEMA_VERSION


def _echo(location_id: int, name: str, **over) -> dict:
    base = {
        "schema_version": 7, "echo_id": f"echo_{location_id}",
        "source_location_id": location_id, "source_item_name": name,
        "source_game": "Ocarina of Time", "source_recipient_name": "Someone",
        "display_name": name, "description": f"{name}, reinterpreted.",
        "tags": [], "activation": "primary", "archetype": "weapon",
        "cooldown": 1.0,
        "initiator": {"type": "hitscan_damage", "damage": 10.0, "pellets": 1,
                      "spread_degrees": 2.0, "range": 30.0},
        "modifiers": [],
    }
    return {**base, **over}


_PASSIVE = _echo(
    89100002, "Cape", activation="passive", archetype="passive",
    effects=[{"type": "modify_gravity", "multiplier": 0.6}],
)
_PASSIVE.pop("cooldown"), _PASSIVE.pop("initiator"), _PASSIVE.pop("modifiers")

_GRAPPLE = _echo(
    89100020, "Hookshot", archetype="mobility", cooldown=2.0,
    initiator={"type": "grapple_to_surface", "range": 20.0,
               "pull_force": 14.0},
)


def _save(echoes, equipped=None, **over) -> dict:
    return {
        "schema_version": 7, "seed_name": "CorpusSeed", "slot_name": "Skyiah",
        "slot_id": 3, "team": 0, "echoes": echoes,
        "equipped_echo_id": equipped, **over,
    }


#: Each entry is (label, v7 save). The labels are what a failure reports, so
#: they name the SHAPE rather than the index.
CORPUS = [
    ("empty campaign", _save([])),
    ("one primary, equipped", _save([_echo(89100001, "Conference Call")],
                                    "echo_89100001")),
    ("one primary, nothing equipped", _save([_echo(89100001, "Rifle")])),
    ("passive equipped", _save([_PASSIVE], "echo_89100002")),
    ("mixed, passive equipped",
     _save([_echo(89100001, "Gun"), _PASSIVE, _GRAPPLE], "echo_89100002")),
    # The ordering case: grant order is Hookshot then Cape then Gun, which
    # is NOT location order. A migration that renumbered by location id
    # would silently reorder a campaign somebody already played.
    ("grant order unlike location order",
     _save([_GRAPPLE, _PASSIVE, _echo(89100001, "Gun")], "echo_89100001")),
    ("many echoes",
     _save([_echo(89100000 + i, f"Item {i}") for i in range(1, 27)],
           "echo_89100013")),
]


@pytest.mark.parametrize("label,raw", CORPUS, ids=[c[0] for c in CORPUS])
def test_a_v7_save_loads_folds_and_writes_back_as_v8(tmp_path, label, raw):
    path = tmp_path / "campaign.json"
    path.write_text(json.dumps(raw), encoding="utf-8")

    save = store.load_save(path)
    assert save is not None, f"{label}: the corpus save did not load at all"
    assert save.schema_version == SCHEMA_VERSION
    assert len(save.interpretations) == len(raw["echoes"])

    # Migration is written back immediately. One that only lives in memory
    # runs again on every load, and the first crash after it loses whichever
    # half was in flight.
    on_disk = json.loads(path.read_text(encoding="utf-8"))
    assert on_disk["schema_version"] == SCHEMA_VERSION
    assert "echoes" not in on_disk

    # And the second load is a plain load: nothing left to migrate.
    again = store.load_save(path)
    assert again == save, f"{label}: reload differs from the migrated save"

    mechanics = save.derive()
    assert len(mechanics.owned) >= len(raw["echoes"])


def test_grant_order_survives_migration():
    """The regression the whole ordering rule exists for."""
    raw = dict(CORPUS[5][1])
    from archipepsi_bridge.schemas.migration import migrate_v7_to_v8
    from archipepsi_bridge.schemas.protocol import CampaignSave

    save = CampaignSave.model_validate(migrate_v7_to_v8(raw))
    assert [i.source_item_name for i in save.interpretations] == [
        "Hookshot", "Cape", "Gun"]
    assert [i.interpretation_seq for i in save.interpretations] == [0, 1, 2]
    # Location order would have been Gun, Cape, Hookshot — a different
    # campaign.
    assert sorted(i.source_location_id for i in save.interpretations) != [
        i.source_location_id for i in save.interpretations]


def test_a_v7_generation_archive_still_replays():
    """`make replay` must accept both versions.

    The archive is a benchmark corpus. A schema bump that silently
    invalidated every generation recorded before it would throw away the
    only evidence of how Epsilon actually behaves.
    """
    record = {
        "kind": "echo",
        "request": {
            "schema_version": 7,
            "source": {"location_id": 89100001, "item_name": "Conference Call",
                       "source_game": "Borderlands 2",
                       "recipient_name": "BL2Player", "item_flags": 1},
            "player_state": {"existing_echoes": [
                {"echo_id": "echo_89100002", "display_name": "Cape",
                 "archetype": "passive", "activation": "passive",
                 "tags": [], "description": "Lighter."}],
                "signal_keys": 0, "coins_available": 0},
            "required_echo_id": "echo_89100001",
        },
        "accepted_output": _echo(89100001, "Conference Call"),
    }
    ok, detail = replay_one(record)
    assert ok, detail


def test_the_fold_is_cheap_enough_to_sit_on_the_save_path(capsys):
    """The fold runs on every grant and every load, and `CampaignSave`
    folds in its own validator — so it is on the write path too. Linear
    with a tiny constant, but "tiny" is an assumption until measured.

    The budget is deliberately loose: this guards against an accidental
    quadratic, not against a few microseconds of drift.
    """
    from archipepsi_bridge.schemas.migration import migrate_v7_to_v8
    from archipepsi_bridge.schemas.protocol import CampaignSave

    full = _save([_echo(89100000 + i, f"Item {i}") for i in range(1, 27)])
    save = CampaignSave.model_validate(migrate_v7_to_v8(full))
    assert len(save.interpretations) == 26

    runs = 200
    start = time.perf_counter()
    for _ in range(runs):
        M.derive_mechanics(save.interpretations)
    per_fold_ms = (time.perf_counter() - start) / runs * 1000.0

    with capsys.disabled():
        print(f"\n  fold: {per_fold_ms:.3f} ms for a full 26-echo campaign")
    assert per_fold_ms < 15.0, (
        f"the fold takes {per_fold_ms:.2f} ms on a full campaign, which is "
        f"too much for something on the save path"
    )
