"""Progress the engine reports, and the Zone you can come back to.

The engine has been sending `key_collected` and `lock_opened` since the
slice landed and the bridge dropped both, so a key survived exactly as
long as the process did. These tests close that path and keep it closed.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.protocol import (
    REVISITABLE_ZONE_STATES, TERMINAL_ZONE_STATES, ClientMessage,
    ZoneProgress)
from pydantic import TypeAdapter

from archipepsi_bridge.schemas import constants as C

from .conftest import connected_engine, drain, run

_ADAPTER = TypeAdapter(ClientMessage)


# --- the wire shapes the engine already sends -----------------------------

def test_the_engine_intents_parse_as_sent():
    """Exactly the payloads `zone_controller.gd` puts on the wire."""
    key = _ADAPTER.validate_python(
        {"type": "key_collected", "zone_id": "zone_001", "key_id": "red"})
    assert key.key_id == "red"
    lock = _ADAPTER.validate_python(
        {"type": "lock_opened", "zone_id": "zone_001",
         "room_id": "c014", "socket_id": "side_left"})
    assert (lock.room_id, lock.socket_id) == ("c014", "side_left")
    station = _ADAPTER.validate_python(
        {"type": "station_reached", "zone_id": "zone_001",
         "station_id": "room:c014:arrival"})
    assert station.station_id == "room:c014:arrival"


# --- monotone, therefore idempotent ---------------------------------------

def test_progress_only_ever_grows():
    p = ZoneProgress()
    once = p.with_key("red").with_lock("c014", "side_left")
    twice = once.with_key("red").with_lock("c014", "side_left")
    assert once == twice, "the same event twice is one event"
    assert once.collected_keys == ("red",)
    assert once.opened_locks == ("c014/side_left",)


def test_a_station_sets_the_resume_anchor_and_a_key_does_not():
    p = ZoneProgress().with_key("red")
    assert p.resume_anchor is None
    p = p.with_station("room:c014:arrival")
    assert p.resume_anchor == "room:c014:arrival"


# --- the real path, end to end --------------------------------------------


def _identities(engine, zone_id):
    """The key and lock THIS Zone declares.

    Hardcoding "red" tested the validator against a Zone that might not
    hold it, which is how a progress test passes while recording
    something the Zone never had.
    """
    zone = engine.save.zone_by_id(zone_id).zone
    key = next((k.key_id for c in zone.chambers for k in c.keys), None)
    lock = next(((c.id, d.socket_id) for c in zone.chambers
                 for d in c.doors if d.usage == "LOCKED"), None)
    return key, lock


def _live_zone(engine):
    return engine.save.zone_by_id(engine.save.active_zone_id)


def test_a_collected_key_reaches_the_save(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        key, lock = _identities(engine, zone_id)
        assert key and lock, "this Zone should carry a branch"

        msg = _ADAPTER.validate_python(
            {"type": "key_collected", "zone_id": zone_id, "key_id": key})
        await engine.handle_progress(msg)
        assert _live_zone(engine).progress.collected_keys == (key,)

        # A resend after a dropped connection is the normal case.
        await engine.handle_progress(msg)
        assert _live_zone(engine).progress.collected_keys == (key,)

        room, socket = lock
        await engine.handle_progress(_ADAPTER.validate_python(
            {"type": "lock_opened", "zone_id": zone_id,
             "room_id": room, "socket_id": socket}))
        assert _live_zone(engine).progress.opened_locks \
            == (f"{room}/{socket}",)
    run(go())


def test_an_undeclared_key_never_becomes_save_data(tmp_path):
    """Progress sets are monotone, so a wrong entry is permanent."""
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        with pytest.raises(Exception, match="declares no key"):
            await engine.handle_progress(_ADAPTER.validate_python(
                {"type": "key_collected", "zone_id": zone_id,
                 "key_id": "chartreuse"}))
        assert _live_zone(engine).progress.collected_keys == ()
    run(go())


def test_a_lock_on_a_door_that_is_not_locked_is_refused(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        with pytest.raises(Exception, match="no locked door"):
            await engine.handle_progress(_ADAPTER.validate_python(
                {"type": "lock_opened", "zone_id": zone_id,
                 "room_id": "c001", "socket_id": "exit"}))
        assert _live_zone(engine).progress.opened_locks == ()
    run(go())


def test_a_station_the_layout_never_placed_is_refused(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        with pytest.raises(Exception, match="placed no station"):
            await engine.handle_progress(_ADAPTER.validate_python(
                {"type": "station_reached", "zone_id": zone_id,
                 "station_id": "room:c999:arrival"}))
        assert _live_zone(engine).progress.reached_stations == ()
    run(go())


def test_progress_lands_in_the_zone_it_happened_in(tmp_path):
    """Not in whichever Zone is current."""
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        msg = _ADAPTER.validate_python(
            {"type": "key_collected", "zone_id": "zone_999",
             "key_id": "red"})
        with pytest.raises(Exception, match="no Zone"):
            await engine.handle_progress(msg)
    run(go())


def test_progress_survives_a_save_round_trip(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        key, lock = _identities(engine, zone_id)
        room, socket = lock
        for m in ({"type": "key_collected", "zone_id": zone_id,
                   "key_id": key},
                  {"type": "lock_opened", "zone_id": zone_id,
                   "room_id": room, "socket_id": socket}):
            await engine.handle_progress(_ADAPTER.validate_python(m))

        reloaded = type(engine.save).model_validate_json(
            engine.save.model_dump_json())
        got = reloaded.zone_by_id(zone_id).progress
        assert got.collected_keys == (key,)
        assert got.opened_locks == (f"{room}/{socket}",)
    run(go())


# --- leaving, and coming back ---------------------------------------------

def test_a_cleared_zone_is_still_revisitable():
    """Ruled 2026-09-12. Claiming the final Check does not close the place."""
    assert "COMPLETE" in REVISITABLE_ZONE_STATES
    assert "COMPLETE" in TERMINAL_ZONE_STATES, (
        "COMPLETE reserves no locations — that is a different question "
        "from whether you can walk back in, and conflating the two is "
        "what broke the one-holder invariant")
    assert "ABANDONED" not in REVISITABLE_ZONE_STATES


def test_leaving_with_checks_outstanding_keeps_them(tmp_path):
    """The round trip the coupling exists for, not the presence of an enum."""
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        key, _ = _identities(engine, zone_id)
        await engine.handle_progress(_ADAPTER.validate_python(
            {"type": "key_collected", "zone_id": zone_id, "key_id": key}))

        rec = engine.save.zone_by_id(zone_id)
        outstanding = set(rec.allocated_location_ids)
        assert outstanding, "the fixture must leave Checks to come back for"

        # Leave through the exit with work still to do.
        engine.save = T.rest_zone(engine.save, zone_id)
        rec = engine.save.zone_by_id(zone_id)
        assert rec.state == "DORMANT"
        assert set(rec.allocated_location_ids) == outstanding, (
            "a dormant Zone keeps its Check identities; returning them to "
            "the pool is abandonment's job and only abandonment's")
        assert rec.progress.collected_keys == (key,)

        # Walk back in.
        engine.save = T.enter_zone(engine.save, zone_id)
        rec = engine.save.zone_by_id(zone_id)
        assert rec.state == "ACTIVE"
        assert set(rec.allocated_location_ids) == outstanding
        assert rec.progress.collected_keys == (key,)
        assert engine.save.active_zone_id == zone_id
    run(go())


def test_an_abandoned_zone_is_the_one_you_cannot_return_to(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        engine.save = T.abandon_zone(engine.save, zone_id)
        assert engine.save.zone_by_id(zone_id).state == "ABANDONED"
        with pytest.raises(ValueError, match="nothing to enter"):
            T.enter_zone(engine.save, zone_id)
    run(go())


def test_a_dormant_zone_still_records_progress(tmp_path):
    """You may not be standing in it, but it is still yours."""
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        engine.save = T.rest_zone(engine.save, zone_id)
        key, _ = _identities(engine, zone_id)
        engine.save = T.record_key(engine.save, zone_id, key)
        assert engine.save.zone_by_id(zone_id).progress.collected_keys \
            == (key,)
    run(go())


# --- visiting is not completing -------------------------------------------

def _finish(save, zone_id):
    """Drive a Zone to COMPLETE the way the campaign does."""
    rec = save.zone_by_id(zone_id)
    for i, loc in enumerate(rec.allocated_location_ids):
        save = T.claim_zone_check(save, zone_id=zone_id, location_id=loc,
                                  transaction_id=f"t{i}")
        save = T.confirm_check(save, loc)
    return T.complete_zone(save, zone_id)


def test_visiting_a_finished_zone_counts_nothing_twice(tmp_path):
    """complete -> enter -> leave -> and the campaign has moved once."""
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        save = _finish(engine.save, zone_id)

        counted = save.completed_zone_count
        history = save.zone_history
        cursor = save.track_cursor
        allocated = set(save.zone_by_id(zone_id).allocated_location_ids)

        save = T.enter_zone(save, zone_id)
        assert save.zone_by_id(zone_id).state == "VISITING", (
            "a finished Zone is VISITED; sending it through ACTIVE would "
            "make it reserve its old locations again")
        assert not save.zone_by_id(zone_id).holds_locations
        assert set(save.zone_by_id(zone_id).allocated_location_ids) \
            == allocated, "the Check identities are still the same Checks"

        save = T.rest_zone(save, zone_id)
        assert save.zone_by_id(zone_id).state == "COMPLETE"
        assert save.completed_zone_count == counted
        assert save.zone_history == history
        assert save.track_cursor == cursor
    run(go())


def test_a_finished_zone_cannot_be_completed_twice(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        save = _finish(engine.save, zone_id)
        save = T.enter_zone(save, zone_id)
        with pytest.raises(ValueError, match="already counted"):
            T.complete_zone(save, zone_id)
    run(go())


def test_a_finished_zone_is_visitable_while_another_is_dormant(tmp_path):
    """The case that used to fail with 'more than one Zone holds
    locations'. A visit reserves nothing, so it cannot collide with the
    Zone that is genuinely in flight."""
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        first = engine.save.active_zone_id
        await engine.handle_enter_zone(first)
        engine.save = _finish(engine.save, first)

        await engine.handle_request_next_zone(False)
        await drain()
        second = engine.save.active_zone_id
        assert second != first
        await engine.handle_enter_zone(second)
        engine.save = T.rest_zone(engine.save, second)
        assert engine.save.zone_by_id(second).state == "DORMANT"

        save = T.enter_zone(engine.save, first)
        assert save.zone_by_id(first).state == "VISITING"
        assert save.active_zone_id == first
        assert save.zone_by_id(second).state == "DORMANT", (
            "the outstanding Zone keeps its Checks while another is "
            "being revisited")
        save = T.rest_zone(save, first)
        assert save.zone_by_id(first).state == "COMPLETE"
        assert save.active_zone_id is None
    run(go())


def test_one_unfinished_zone_holds_locations_at_a_time(tmp_path):
    """The current implementation limit, recorded as one.

    It is not a frozen Amalgam rule: allowing several dormant Zones is a
    real allocation change, and this asserts the boundary that exists so
    that lifting it is a deliberate act rather than a surprise.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                          config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        first = engine.save.active_zone_id
        await engine.handle_enter_zone(first)
        engine.save = T.rest_zone(engine.save, first)
        holders = [z for z in engine.save.zones if z.holds_locations]
        assert [z.zone_id for z in holders] == [first]
    run(go())
