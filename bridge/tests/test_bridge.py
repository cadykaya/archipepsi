"""Bridge tests 1–12, 16–20 (ACCEPTANCE_TESTS §2). Providers: 13–15 live in
test_providers.py."""

from __future__ import annotations

import os
from pathlib import Path
from types import SimpleNamespace

import pytest

from archipepsi_bridge import store
from archipepsi_bridge import transactions as TX
from archipepsi_bridge.ap_client import (
    ALL_LOCATION_IDS, RealAPBackend, scout_message,
)
from archipepsi_bridge.mock_ap import MockAPBackend, MockServerState, SELF_SLOT
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.protocol import CampaignSave
from archipepsi_bridge.server import BridgeServer

from .conftest import (
    BlockedProvider, Collector, connected_engine, drain, make_engine, run,
)

AP_AVAILABLE = Path(
    os.environ.get("ARCHIPELAGO_ROOT",
                   Path(__file__).resolve().parents[2] / ".archipelago")
).is_dir()

needs_ap = pytest.mark.skipif(not AP_AVAILABLE,
                              reason="no Archipelago checkout (make setup)")


# -- 1, 2: connection configuration ---------------------------------------

@needs_ap
def test_1_2_context_configuration(tmp_path):
    from archipepsi_bridge.ap_client import build_context_class
    engine = make_engine(tmp_path)
    backend = RealAPBackend(engine)
    cls = build_context_class(backend, "Skyiah")
    assert cls.game == "Archipepsi"                       # test 1
    assert cls.items_handling == 0b111                    # test 2
    assert cls.want_slot_data is True
    assert cls.tags == {"AP"}


# -- 3: scout packet -------------------------------------------------------

def test_3_scout_packet():
    msg = scout_message()
    assert msg["cmd"] == "LocationScouts"
    assert msg["create_as_hint"] == 0
    assert sorted(msg["locations"]) == list(ALL_LOCATION_IDS)
    assert len(msg["locations"]) == 30


# -- 4: recipient-game resolution ------------------------------------------

def test_4_scout_resolution_uses_recipient_game(tmp_path):
    """Item id 55 means different things in different games; the name must
    come from the RECIPIENT's game table."""
    engine = make_engine(tmp_path)
    backend = RealAPBackend(engine)

    per_game = {
        "Ocarina of Time": {55: "Hookshot"},
        "Borderlands 2": {55: "Conference Call"},
    }

    class StubNames:
        def lookup_in_slot(self, code, slot):
            game = {2: "Borderlands 2", 3: "Ocarina of Time"}[slot]
            return per_game[game][code]

    loc = C.FIRST_LOCATION_ID
    backend.ctx = SimpleNamespace(
        locations_info={loc: SimpleNamespace(item=55, location=loc,
                                             player=3, flags=1)},
        slot_info={3: SimpleNamespace(game="Ocarina of Time")},
        player_names={3: "Sage"},
        slot_concerns_self=lambda s: False,
        item_names=StubNames())
    backend._resolve_scouts()
    scout = backend.data.scouts[loc]
    assert scout.item_name == "Hookshot"          # not Conference Call
    assert scout.recipient_game == "Ocarina of Time"
    assert scout.recipient_name == "Sage"


# -- 5: snapshot carries all 30 scouts ------------------------------------

def test_5_snapshot_has_all_30_scouts(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        snap = engine.snapshot()
        assert len(snap.scouted) == 30
        assert {s.location_id for s in snap.scouted} == set(ALL_LOCATION_IDS)
    run(scenario())


# -- 6: stable ordinals ----------------------------------------------------

def test_6_received_items_stable_ordinals(tmp_path):
    async def scenario():
        engine, backend = await connected_engine(tmp_path)
        for _ in range(3):
            backend.grant_item(C.ITEM_ID_EPSILON_COIN)
        await drain()
        ordinals = [i.ordinal for i in engine.ap.received]
        assert ordinals == list(range(len(ordinals)))
    run(scenario())


# -- 7: reconnect does not duplicate coins ---------------------------------

def test_7_reconnect_no_duplicate_coins(tmp_path):
    async def scenario():
        engine, backend = await connected_engine(tmp_path)
        for _ in range(4):
            backend.grant_item(C.ITEM_ID_EPSILON_COIN)
        await drain()
        before = engine.ap.coins_received
        assert before == 4
        await backend.disconnect()
        await drain()
        await backend.connect("", "Skyiah", "")
        await drain()
        assert engine.ap.coins_received == before
    run(scenario())


# -- 8: still-missing pending is resent ------------------------------------

def test_8_pending_still_missing_is_resent(tmp_path):
    async def scenario():
        engine, backend = await connected_engine(tmp_path,
                                                 confirm_delay=9999)
        await engine.handle_request_next_zone(False)
        await engine._generation_task
        zone = engine.save.active_zone
        await engine.handle_enter_zone(zone.zone_id)
        loc = zone.allocated_location_ids[0]
        await TX.claim_check(engine, zone.zone_id, loc)
        assert engine.save.pending_checks           # in flight, unconfirmed

        sent_calls: list[list[int]] = []
        original = backend.check_locations

        async def spy(ids):
            sent_calls.append(list(ids))
            return await original(ids)

        backend.check_locations = spy
        await engine.reconcile()
        assert any(loc in call for call in sent_calls), "pending not resent"
    run(scenario())


# -- 9: already-checked pending finalizes with no event --------------------

def test_9_checked_pending_finalizes_without_event(tmp_path):
    async def scenario():
        engine, backend = await connected_engine(tmp_path,
                                                 confirm_delay=9999)
        await engine.handle_request_next_zone(False)
        await engine._generation_task
        zone = engine.save.active_zone
        await engine.handle_enter_zone(zone.zone_id)
        loc = zone.allocated_location_ids[0]
        await TX.claim_check(engine, zone.zone_id, loc)
        assert engine.save.pending_checks

        # The server confirmed while we were away; no packet will ever come.
        backend.server.checked.add(loc)
        backend._sync_from_server()
        await engine.reconcile()
        assert not any(p.location_id == loc
                       for p in engine.save.pending_checks)
        if not backend.data.scouts[loc].recipient_is_self:
            assert engine.save.interpretation_by_id(f"echo_{loc}") is not None
    run(scenario())


# -- 10: claim of an already-checked location finalizes immediately --------

def test_10_claim_already_checked_finalizes_immediately(tmp_path):
    async def scenario():
        engine, backend = await connected_engine(tmp_path,
                                                 confirm_delay=9999)
        await engine.handle_request_next_zone(False)
        await engine._generation_task
        zone = engine.save.active_zone
        await engine.handle_enter_zone(zone.zone_id)
        loc = zone.allocated_location_ids[0]
        backend.server.checked.add(loc)
        backend._sync_from_server()

        calls = []
        original = backend.check_locations

        async def spy(ids):
            calls.append(list(ids))
            return await original(ids)

        backend.check_locations = spy
        await TX.claim_check(engine, zone.zone_id, loc)
        assert not calls, "sent a packet for an already-checked location"
        assert not engine.save.pending_checks
    run(scenario())


# -- 11: race mode refuses before scouting ---------------------------------

@needs_ap
def test_11_race_mode_refuses_before_scout(tmp_path):
    async def scenario():
        engine = make_engine(tmp_path)
        collector = Collector(engine)
        backend = RealAPBackend(engine)
        sent = []
        backend.ctx = SimpleNamespace(
            send_msgs=lambda msgs: _record(sent, msgs),
            checked_locations=set(), missing_locations=set(),
            seed_name="X", team=0, slot=1, auth="Skyiah")
        await backend._on_package("Retrieved",
                                  {"keys": {"_read_race_mode": 1}})
        assert backend.data.race_mode is True
        assert not sent, "scouted a race-mode room"
        errors = collector.of_type("error")
        assert errors and "race" in errors[0].message.lower()

    async def _record(sink, msgs):
        sink.extend(msgs)

    run(scenario())


# -- 12: malformed client message ------------------------------------------

def test_12_malformed_message_recoverable(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        server = BridgeServer(engine)

        class FakeWS:
            def __init__(self):
                self.sent = []

            async def send(self, payload):
                self.sent.append(payload)

        ws = FakeWS()
        await server.dispatch(ws, "this is not json")
        assert any('"error"' in p and '"protocol"' in p for p in ws.sent)
        ws.sent.clear()
        await server.dispatch(ws, '{"type": "definitely_not_an_intent"}')
        assert any('"error"' in p for p in ws.sent)
        ws.sent.clear()
        await server.dispatch(
            ws, '{"type": "hello", "client_version": "test"}')
        assert any('"campaign_snapshot"' in p for p in ws.sent)
    run(scenario())


# -- 16: auth failure surfaces readable status -----------------------------

def test_16_auth_failure_readable(tmp_path):
    async def scenario():
        engine = make_engine(tmp_path)
        collector = Collector(engine)
        backend = RealAPBackend(engine)
        backend.ctx = SimpleNamespace()
        await backend._on_package(
            "ConnectionRefused", {"errors": ["InvalidPassword"]})
        errors = collector.of_type("error")
        assert errors
        assert "InvalidPassword" in errors[0].message
        assert errors[0].recoverable
    run(scenario())


# -- 17: atomic saves ------------------------------------------------------

def test_17_atomic_save_survives_corruption(tmp_path):
    path = Path(tmp_path) / "campaign.json"
    s1 = CampaignSave(seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah")
    store.write_save(path, s1)
    s2 = CampaignSave(seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
                      coins_spent=0, generation_counter=3)
    store.write_save(path, s2)
    # Simulated crash mid-write: the primary is garbage, .bak is the
    # previous generation.
    path.write_text("{ totally corrupted", encoding="utf-8")
    recovered = store.load_save(path)
    assert recovered is not None
    assert recovered.generation_counter == 0      # the .bak generation (s1)


def test_17b_interrupted_tmp_write_leaves_previous_loadable(tmp_path,
                                                            monkeypatch):
    path = Path(tmp_path) / "campaign.json"
    s1 = CampaignSave(seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah")
    store.write_save(path, s1)

    def explode(fd):
        raise OSError("simulated crash during fsync")

    monkeypatch.setattr(os, "fsync", explode)
    with pytest.raises(OSError):
        store.write_save(path, CampaignSave(
            seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
            generation_counter=9))
    monkeypatch.undo()
    assert store.load_save(path).generation_counter == 0


# -- 18: PENDING_GENERATION regenerates against committed ids --------------

def test_18_pending_generation_reload_uses_committed_ids(tmp_path):
    async def scenario():
        state = MockServerState()
        blocked = BlockedProvider()
        engine, backend = await connected_engine(
            tmp_path, provider=blocked, server_state=state)
        await engine.handle_request_next_zone(False)
        record = engine.save.active_zone
        assert record.state == "PENDING_GENERATION"
        committed = tuple(record.allocated_location_ids)
        engine._generation_task.cancel()

        # "Crash", reload with a working provider.
        engine2, _ = await connected_engine(tmp_path, server_state=state)
        assert engine2._generation_task is not None, "no regeneration started"
        await engine2._generation_task
        zone = engine2.save.active_zone
        assert zone.state == "GENERATED"
        assert tuple(zone.allocated_location_ids) == committed
        assert sorted(zone.zone.reward_location_ids) == sorted(committed)
        # And it did NOT re-allocate: the generation counter moved once.
        assert engine2.save.generation_counter == 1
    run(scenario())


# -- 19: pending-generation locations excluded from shop eligibility -------

def test_19_shop_excludes_held_locations(tmp_path):
    async def scenario():
        engine, backend = await connected_engine(tmp_path,
                                                 provider=BlockedProvider())
        await engine.handle_request_next_zone(False)
        held = set(engine.save.active_zone.allocated_location_ids)
        assert engine.save.active_zone.state == "PENDING_GENERATION"
        assert not (engine.shop_candidates() & held)
        assert not (engine.zone_candidates() & held)
        engine._generation_task.cancel()
    run(scenario())


# -- 20: bulk confirmation echo guard --------------------------------------

def test_20_bulk_confirmation_max_3_echoes(tmp_path):
    async def scenario():
        state = MockServerState()
        # 25 foreign locations confirmed before we ever connect (!collect).
        placements = MockAPBackend(make_engine(tmp_path),
                                   server_state=MockServerState()).placements
        foreign = [loc for loc, (_n, _i, slot, _f) in placements.items()
                   if slot != SELF_SLOT]
        state.checked = set(foreign[:25])
        engine, _ = await connected_engine(tmp_path, server_state=state)
        await drain(50)
        assert len(engine.save.interpretations) <= 3
    run(scenario())
