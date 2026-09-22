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
            "home_room_id": "c001", "required": True,
            # The art lane's POWER_CELL: 40 kg and `carriable`.
            "carriable": True, "mass_kg": 40.0}
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


# --------------------------------------------------------------------------
# P16 reopened — the consuming mechanism.
#
# Ownership and a room were the overbroad part of the first pass: an
# object can arrive somewhere it is allowed to be and have nothing
# happen. The generator in the union's own sentence is this.
# --------------------------------------------------------------------------

def _variable(**over) -> dict:
    base = {
        "variable_id": "generator", "states": ["dark", "lit"],
        "initial": "dark", "lifetime": "permanent",
        "setter": {"room_id": "c001", "selects": ["lit"]},
        "readers": [{"room_id": "c003", "mechanism": "lamp",
                     "when": ["lit"]}],
    }
    base.update(over)
    return base


def _consumer(**over) -> dict:
    base = {"mechanism_id": "generator_socket", "room_id": "c003",
            "accepts": CELL, "sets_variable": "generator",
            "sets_state": "lit"}
    base.update(over)
    return base


def _zone_with_consumer(**over) -> Zone:
    body = {
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [_room(r, 89100001 if i == 0 else None)
                     for i, r in enumerate(("c001", "c002", "c003"))],
        "transported_objects": [_cell()],
        "zone_state": [_variable()],
        "object_consumers": [_consumer()],
    }
    body.update(over)
    return TypeAdapter(Zone).validate_python(body)


def test_a_consumer_must_stand_where_the_object_may_be_carried():
    """§10.5's volume is where the object may go. A consumer outside it
    is a destination nothing may ever legally reach, and the puzzle
    would be unsolvable in a way no route search sees."""
    with pytest.raises(ValidationError, match="outside"):
        _zone_with_consumer(
            transported_objects=[_cell(allowed_volume=["c001", "c002"])])


def test_a_consumer_accepting_an_undeclared_object_is_refused():
    with pytest.raises(ValidationError, match="does not declare"):
        _zone_with_consumer(object_consumers=[_consumer(accepts="ghost")])


def test_a_consequence_is_a_variable_and_the_state_it_is_put_in():
    with pytest.raises(ValidationError, match="a variable AND the state"):
        _zone_with_consumer(
            object_consumers=[_consumer(sets_state=None)])


def test_a_consumer_setting_a_state_the_variable_lacks_is_refused():
    with pytest.raises(ValidationError, match="does not have"):
        _zone_with_consumer(
            object_consumers=[_consumer(sets_state="melted")])


def test_the_mechanism_fires_only_once_the_object_is_actually_there():
    """THE CHECK THAT MAKES TRANSPORT MEAN SOMETHING.

    A mechanism that fired on a message alone would let a client claim a
    delivery it never made, and the carried route would be decorative.
    """
    zone = _zone_with_consumer()
    save = _save(zone)
    with pytest.raises(ValueError, match="not anywhere yet"):
        T.record_object_consumed(save, "zone_001", "generator_socket")

    # delivered to the wrong room: still refused, and it says where
    wrong = T.record_object_transported(save, "zone_001", CELL, "c002")
    with pytest.raises(ValueError, match="in 'c002'"):
        T.record_object_consumed(wrong, "zone_001", "generator_socket")

    delivered = T.record_object_transported(save, "zone_001", CELL, "c003")
    lit = T.record_object_consumed(delivered, "zone_001", "generator_socket")
    assert lit.zone_by_id("zone_001").progress.macro("generator") == "lit"


def test_the_consequence_goes_through_the_declared_handle():
    """Not a second channel. The consumer sets a D-8 variable the rest of
    the Zone already knows how to read, so nothing here is a new way for
    one room to change another."""
    zone = _zone_with_consumer()
    delivered = T.record_object_transported(_save(zone), "zone_001", CELL,
                                            "c003")
    lit = T.record_object_consumed(delivered, "zone_001", "generator_socket")
    progress = lit.zone_by_id("zone_001").progress
    assert progress.macro("generator") == "lit"
    assert progress.object_room(CELL) == "c003", (
        "consuming it does not make the object vanish from the save; what "
        "the mechanism changes is the Zone's state")


def test_a_scenery_consumer_is_legal_and_changes_nothing():
    zone = _zone_with_consumer(object_consumers=[
        _consumer(sets_variable=None, sets_state=None)])
    delivered = T.record_object_transported(_save(zone), "zone_001", CELL,
                                            "c003")
    after = T.record_object_consumed(delivered, "zone_001",
                                     "generator_socket")
    assert after.zone_by_id("zone_001").progress.macro("generator") is None


def test_an_undeclared_mechanism_is_refused():
    with pytest.raises(ValueError, match="declares no object consumer"):
        T.record_object_consumed(_save(_zone_with_consumer()), "zone_001",
                                 "ghost_socket")


# --------------------------------------------------------------------------
# §10.3 — the object the player "carries" must be one a player can carry.
#
# `ENVELOPE_MASS_KG` (120) and `CARRY_MASS_KG` (60) answer different
# questions: the first is one of three numbers a HOST must meet to be a
# qualified manipulation provider, the second is a property of the OBJECT
# and governs ordinary pickup. Until these tests existed, the carry line
# had no consumer anywhere in the bridge or the engine -- it lived in
# design prose and in one art preview's row labels -- so this declaration
# accepted any mass at all.
# --------------------------------------------------------------------------

def test_a_ballast_cannot_be_declared_an_object_the_player_carries():
    """320 kg, `carriable = false`: the art lane's ANCHOR-class prop.

    Before §10.3 was handed this case, the declaration took it.
    """
    with pytest.raises(ValidationError) as e:
        TransportedObject.model_validate(
            _cell(object_id="ballast", carriable=False, mass_kg=320.0))
    assert "not `carriable`" in str(e.value)


def test_the_carry_line_is_inclusive():
    """§10.3 reads `mass_kg <= 60.0`, so 60.0 itself is carriable."""
    obj = TransportedObject.model_validate(_cell(mass_kg=60.0))
    assert obj.mass_kg == 60.0


def test_one_tenth_of_a_kilogram_over_the_line_is_refused():
    with pytest.raises(ValidationError) as e:
        TransportedObject.model_validate(_cell(mass_kg=60.1))
    assert "60 kg carry line" in str(e.value)


def test_the_flag_refuses_on_its_own_and_says_so():
    """`PLATE` is exactly 60 kg and is NOT carriable -- the flag is not
    a restatement of the kilograms, and the refusal must not blame the
    mass of an object that is within the line."""
    with pytest.raises(ValidationError) as e:
        TransportedObject.model_validate(
            _cell(object_id="plate", carriable=False, mass_kg=60.0))
    text = str(e.value)
    assert "not `carriable`" in text
    # The shared tail explains what IS allowed above the line; the
    # reason clause must not blame a mass that is within it.
    assert "over \u00a710.3's" not in text


def test_the_provider_envelope_is_not_a_licence_to_pick_something_up():
    """100 kg is comfortably inside `ENVELOPE_MASS_KG`'s 120 and is
    still not something a hand holds. If these two numbers are ever
    collapsed into one rule, this is the test that fails."""
    from archipepsi_bridge.schemas import physics as PH
    assert 100.0 <= PH.ENVELOPE_MASS_KG
    with pytest.raises(ValidationError) as e:
        TransportedObject.model_validate(_cell(mass_kg=100.0))
    assert "not a licence to pick this up" in str(e.value)


def test_the_carry_rule_is_not_vacuous():
    """Sabotage, with the TARGET FUNCTION confirmed changed.

    A rule that is never reached looks exactly like a rule that holds.
    `str.replace` on a module is not enough -- an identical line
    elsewhere in the file absorbs the edit and the suite stays green
    while nothing is tested -- so this asserts the source of
    `carriable_by_hand` itself is what moved.
    """
    import inspect
    from archipepsi_bridge.schemas import physics as PH

    before = inspect.getsource(PH.carriable_by_hand)
    assert "CARRY_MASS_KG" in before
    original = PH.carriable_by_hand
    try:
        PH.carriable_by_hand = lambda carriable, mass_kg: True
        assert PH.carriable_by_hand is not original
        # zone.py imported the name, so reach it where the validator
        # actually looks it up.
        import archipepsi_bridge.schemas.zone as Z
        z_original = Z.carriable_by_hand
        Z.carriable_by_hand = PH.carriable_by_hand
        try:
            TransportedObject.model_validate(_cell(mass_kg=5000.0))
        finally:
            Z.carriable_by_hand = z_original
    finally:
        PH.carriable_by_hand = original
    # And with the real predicate back, the same case is refused.
    with pytest.raises(ValidationError):
        TransportedObject.model_validate(_cell(mass_kg=5000.0))
