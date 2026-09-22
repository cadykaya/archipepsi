"""P16 — transported objects: identity, authority, persistence, recovery.

D-8 lifetime 5, and it was an explicit unfinished 0.4 row until now. Two
settled rules meet here and only one needed an amendment: §10.5 already
said a multi-room carryable is `ZONE_PERSISTENT` with an
`allowed_volume`, and Prod's question 1 -- accepted and narrowed in D-8
§11.1 -- settled AUTHORITY: the owning room is the current room, and
crossing a boundary is a transfer rather than a machine-layer write.

Prod owns moving it physically (P16.2). What is here is identity, the
volume, the save, the authority rule and recovery.
"""
from __future__ import annotations

import pytest
from pydantic import TypeAdapter, ValidationError

from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.zone import TransportedObject, Zone

CELL = "power_cell"


def _room(rid: str, reward: int | None = None) -> dict:
    return {"id": rid, "type": "arena", "width": 16.0, "depth": 15.0,
            "wall_height": 5.0, "objective": "kill_all",
            "reward_location_id": reward,
            "enemies": [{"archetype": "melee", "count": 1}]}


def _zone(objects=None, rooms=("c001", "c002", "c003")) -> Zone:
    body = {
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [_room(r, 89100001 if i == 0 else None)
                     for i, r in enumerate(rooms)],
    }
    if objects is not None:
        body["transported_objects"] = objects
    return TypeAdapter(Zone).validate_python(body)


def _cell(**over) -> dict:
    base = {"object_id": CELL, "allowed_volume": ["c001", "c002", "c003"],
            "home_room_id": "c001", "required": True}
    base.update(over)
    return base


def _save(zone: Zone) -> P.CampaignSave:
    save = P.CampaignSave(seed_name="Seed", team=0, slot_id=1,
                          slot_name="Skyiah")
    save = T.start_generation(save, zone_id=zone.zone_id,
                              allocated_location_ids=(89100001,),
                              target_game=zone.target_game)
    return T.enter_zone(T.accept_zone(save, zone), zone.zone_id)


# --------------------------------------------------------------------------
# P16.1 — stable identity, and a volume that means something
# --------------------------------------------------------------------------

def test_an_object_that_can_only_be_in_one_room_is_not_transported():
    with pytest.raises(ValidationError):
        TransportedObject.model_validate(_cell(allowed_volume=["c001"]))


def test_it_must_come_home_somewhere_it_is_allowed_to_be():
    with pytest.raises(ValidationError, match="would put it somewhere"):
        TransportedObject.model_validate(_cell(home_room_id="c009"))


def test_a_volume_naming_a_room_the_zone_lacks_is_refused():
    with pytest.raises(ValidationError, match="which this Zone does not have"):
        _zone([_cell(allowed_volume=["c001", "c404"])])


def test_two_objects_may_not_share_an_id():
    with pytest.raises(ValidationError, match="both called"):
        _zone([_cell(), _cell()])


# --------------------------------------------------------------------------
# P16.3 — persistence, and what is NOT persisted
# --------------------------------------------------------------------------

def test_where_it_is_survives_a_restart():
    save = T.record_object_transported(_save(_zone([_cell()])), "zone_001",
                                       CELL, "c003")
    back = P.CampaignSave.model_validate_json(save.model_dump_json())
    assert back.zone_by_id("zone_001").progress.object_room(CELL) == "c003"


def test_carrying_it_back_is_an_event_and_not_a_replay():
    """Not monotone, like `macro_state` and unlike `latched`."""
    save = _save(_zone([_cell()]))
    there = T.record_object_transported(save, "zone_001", CELL, "c003")
    again = T.record_object_transported(there, "zone_001", CELL, "c003")
    assert again is there, "a repeat of the same arrival is absorbed"
    home = T.record_object_transported(again, "zone_001", CELL, "c001")
    assert home.zone_by_id("zone_001").progress.object_room(CELL) == "c001"


def test_the_save_records_the_room_and_nothing_else_about_the_object():
    """P16.5. Its Statuses are EPHEMERAL (§5.1), so they are not written
    to the save: a cell alight when the player quits is not alight when
    they load.

    **That is about saves, not doorways** (owner correction,
    2026-09-22). Carrying the object between rooms in live play is not
    a reload -- a Status follows its own duration and removal rules, and
    the union's own example sentence, a BURNING cell carried three rooms
    to a generator, depends on it arriving still alight.
    """
    p = P.ZoneProgress().with_object_in(CELL, "c003")
    stored = dict(p.object_rooms)
    assert stored == {CELL: "c003"}
    assert not any(k in P.ZoneProgress.model_fields
                   for k in ("object_statuses", "object_transforms"))


# --------------------------------------------------------------------------
# P16.4 / authority — the volume is enforced, and recovery is its own event
# --------------------------------------------------------------------------

def test_an_arrival_outside_the_volume_is_refused_not_recorded():
    save = _save(_zone([_cell(allowed_volume=["c001", "c002"])]))
    with pytest.raises(ValueError, match="may not be in room"):
        T.record_object_transported(save, "zone_001", CELL, "c003")


def test_an_object_the_zone_does_not_declare_is_refused():
    save = _save(_zone([_cell()]))
    with pytest.raises(ValueError, match="declares no transported object"):
        T.record_object_transported(save, "zone_001", "ghost", "c002")


def test_recovery_puts_it_back_where_the_declaration_says_it_comes_home():
    save = T.record_object_transported(_save(_zone([_cell()])), "zone_001",
                                       CELL, "c003")
    home = T.recover_transported_object(save, "zone_001", CELL)
    assert home.zone_by_id("zone_001").progress.object_room(CELL) == "c001"


def test_recovery_is_a_separate_event_from_an_ordinary_arrival():
    """Folding recovery into the arrival path would make every illegal
    arrival silently correct itself with nothing to notice."""
    save = _save(_zone([_cell(allowed_volume=["c001", "c002"])]))
    with pytest.raises(ValueError):
        T.record_object_transported(save, "zone_001", CELL, "c003")
    assert save.zone_by_id("zone_001").progress.object_room(CELL) is None, (
        "the refused arrival recorded nothing, including no recovery")


def test_the_transfer_reaches_the_save_through_the_real_intent():
    from archipepsi_bridge.schemas.protocol import ClientMessage
    msg = TypeAdapter(ClientMessage).validate_python({
        "type": "object_transported", "zone_id": "zone_001",
        "object_id": CELL, "room_id": "c002"})
    save = T.record_object_transported(_save(_zone([_cell()])), msg.zone_id,
                                       msg.object_id, msg.room_id)
    assert save.zone_by_id("zone_001").progress.object_room(CELL) == "c002"


def test_carrying_an_object_does_not_disturb_any_other_progress():
    """The transfer is room-layer. It writes nothing to the machine
    layer and nothing to any other lifetime."""
    save = _save(_zone([_cell()]))
    before = save.zone_by_id("zone_001").progress \
        .with_latch("yard/span_one").with_key("k_yard")
    moved = before.with_object_in(CELL, "c003")
    assert moved.latched == before.latched
    assert moved.collected_keys == before.collected_keys
    assert moved.macro_state == before.macro_state
