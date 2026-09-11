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

def _live_zone(engine):
    return engine.save.zone_by_id(engine.save.active_zone_id)


def test_a_collected_key_reaches_the_save(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)

        msg = _ADAPTER.validate_python(
            {"type": "key_collected", "zone_id": zone_id, "key_id": "red"})
        await engine.handle_progress(msg)
        assert _live_zone(engine).progress.collected_keys == ("red",)

        # A resend after a dropped connection is the normal case.
        await engine.handle_progress(msg)
        assert _live_zone(engine).progress.collected_keys == ("red",)

        lock = _ADAPTER.validate_python(
            {"type": "lock_opened", "zone_id": zone_id,
             "room_id": "c014", "socket_id": "side_left"})
        await engine.handle_progress(lock)
        assert _live_zone(engine).progress.opened_locks == ("c014/side_left",)
    run(go())


def test_progress_lands_in_the_zone_it_happened_in(tmp_path):
    """Not in whichever Zone is current."""
    async def go():
        engine, _ = await connected_engine(tmp_path)
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
        engine, _ = await connected_engine(tmp_path)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        for m in ({"type": "key_collected", "zone_id": zone_id,
                   "key_id": "red"},
                  {"type": "lock_opened", "zone_id": zone_id,
                   "room_id": "c014", "socket_id": "side_left"},
                  {"type": "station_reached", "zone_id": zone_id,
                   "station_id": "zone_start"}):
            await engine.handle_progress(_ADAPTER.validate_python(m))

        reloaded = type(engine.save).model_validate_json(
            engine.save.model_dump_json())
        got = reloaded.zone_by_id(zone_id).progress
        assert got.collected_keys == ("red",)
        assert got.opened_locks == ("c014/side_left",)
        assert got.reached_stations == ("zone_start",)
        assert got.resume_anchor == "zone_start"
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
        engine, _ = await connected_engine(tmp_path)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        await engine.handle_progress(_ADAPTER.validate_python(
            {"type": "key_collected", "zone_id": zone_id, "key_id": "red"}))

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
        assert rec.progress.collected_keys == ("red",)

        # Walk back in.
        engine.save = T.enter_zone(engine.save, zone_id)
        rec = engine.save.zone_by_id(zone_id)
        assert rec.state == "ACTIVE"
        assert set(rec.allocated_location_ids) == outstanding
        assert rec.progress.collected_keys == ("red",)
        assert engine.save.active_zone_id == zone_id
    run(go())


def test_an_abandoned_zone_is_the_one_you_cannot_return_to(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path)
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
        engine, _ = await connected_engine(tmp_path)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await engine.handle_enter_zone(zone_id)
        engine.save = T.rest_zone(engine.save, zone_id)
        engine.save = T.record_key(engine.save, zone_id, "blue")
        assert engine.save.zone_by_id(zone_id).progress.collected_keys \
            == ("blue",)
    run(go())
