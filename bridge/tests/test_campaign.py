"""Allocation and campaign tests 21–35 (ACCEPTANCE_TESTS §3)."""

from __future__ import annotations

import errno

import pytest

from archipepsi_bridge import store
from archipepsi_bridge import transactions as TX
from archipepsi_bridge.ap_backend import NormalizedItem
from archipepsi_bridge.mock_ap import MockAPBackend, MockServerState, SELF_SLOT
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.protocol import CampaignSave

from .conftest import (
    Collector, connected_engine, drain, make_engine, run,
)

TIER0 = list(range(89100001, 89100011))
NON_GOAL = list(range(89100001, 89100030))


def preload_items(state: MockServerState, *item_ids: int) -> None:
    for iid in item_ids:
        state.received.append(NormalizedItem(
            ordinal=len(state.received), item_id=iid, item_name="preloaded",
            sender_player=2, sender_name="BL2Player",
            sender_game="Borderlands 2", flags=0))


# -- 21 --------------------------------------------------------------------

def test_21_track_order_stable_and_slot_dependent():
    games = sorted(["Borderlands 2", "Ocarina of Time", "Super Mario 64",
                    "Dark Souls III", "Bomb Rush Cyberfunk", "Archipepsi"])
    a1 = C.deterministic_shuffle(games, *C.track_order_seed("Seed", 0, 1))
    a2 = C.deterministic_shuffle(games, *C.track_order_seed("Seed", 0, 1))
    b = C.deterministic_shuffle(games, *C.track_order_seed("Seed", 0, 2))
    assert a1 == a2
    assert a1 != b


# -- 22 --------------------------------------------------------------------

def test_22_goal_never_in_allocation(tmp_path):
    for keys in range(5):
        assert C.GOAL_LOCATION_ID not in C.eligible_location_ids(keys)

    async def scenario():
        state = MockServerState()
        preload_items(state, C.ITEM_ID_SIGNAL_KEY, C.ITEM_ID_SIGNAL_KEY)
        engine, _ = await connected_engine(tmp_path, server_state=state)
        assert C.GOAL_LOCATION_ID in engine.ap.missing
        assert C.GOAL_LOCATION_ID not in engine.zone_candidates()
        ids, _ = engine._select_zone_locations()
        assert C.GOAL_LOCATION_ID not in ids
    run(scenario())


# -- 24 --------------------------------------------------------------------

def test_24_one_check_zone_only_when_one_remains(tmp_path):
    async def scenario():
        state = MockServerState()
        state.checked = set(TIER0[1:])            # only 001 remains eligible
        engine, _ = await connected_engine(tmp_path, server_state=state)
        ids, _ = engine._select_zone_locations()
        assert ids == [89100001]

        state2 = MockServerState()
        state2.checked = set(TIER0[2:])           # 001 and 002 remain
        engine2, _ = await connected_engine(tmp_path / "b",
                                            server_state=state2)
        ids2, _ = engine2._select_zone_locations()
        assert len(ids2) == 2
    run(scenario())


# -- 25 / 26 ---------------------------------------------------------------

def test_25_26_tier_gating(tmp_path):
    async def scenario():
        engine, backend = await connected_engine(tmp_path)
        assert engine.zone_candidates() <= set(TIER0)     # test 25
        backend.grant_item(C.ITEM_ID_SIGNAL_KEY)
        await drain()
        candidates = engine.zone_candidates()
        assert any(loc in candidates
                   for loc in range(89100011, 89100021))  # test 26
        assert not any(loc in candidates
                       for loc in range(89100021, 89100031))
    run(scenario())


# -- 29 / 30 ---------------------------------------------------------------

def test_29_30_waiting_for_ap(tmp_path):
    async def scenario():
        state = MockServerState()
        state.checked = set(TIER0)                # all of tier 0 done, 0 keys
        state.delivery_queue = []                 # nothing flows in
        engine, backend = await connected_engine(tmp_path, server_state=state)
        hub = engine.hub_status()
        assert hub.mode == "WAITING_FOR_AP"       # test 29
        assert hub.portal_enabled is False
        snap = engine.snapshot()                  # must validate
        assert snap.hub.mode == "WAITING_FOR_AP"

        backend.grant_item(C.ITEM_ID_SIGNAL_KEY)  # test 30
        await drain()
        assert engine.hub_status().mode == "ZONE_AVAILABLE"
    run(scenario())


# -- 31 --------------------------------------------------------------------

def test_31_finale_unlock_thresholds(tmp_path):
    async def scenario():
        state = MockServerState()
        state.checked = set(NON_GOAL[:23])
        preload_items(state, C.ITEM_ID_SIGNAL_KEY, C.ITEM_ID_SIGNAL_KEY)
        engine, backend = await connected_engine(tmp_path, server_state=state)
        assert engine.hub_status().finale_unlocked is False   # 23 is not 24

        backend.server.checked.add(NON_GOAL[23])
        backend._sync_from_server()
        await drain()
        assert engine.hub_status().finale_unlocked is True

        # 24 checks but only 1 key: locked again.
        state2 = MockServerState()
        state2.checked = set(NON_GOAL[:24])
        preload_items(state2, C.ITEM_ID_SIGNAL_KEY)
        engine2, _ = await connected_engine(tmp_path / "k1",
                                            server_state=state2)
        assert engine2.hub_status().finale_unlocked is False
    run(scenario())


# -- 32 / 33 ---------------------------------------------------------------

def test_32_33_finale_zone_and_goal_once(tmp_path):
    async def scenario():
        state = MockServerState()
        state.checked = set(NON_GOAL[:24])
        state.delivery_queue = []
        preload_items(state, C.ITEM_ID_SIGNAL_KEY, C.ITEM_ID_SIGNAL_KEY)
        engine, backend = await connected_engine(tmp_path, server_state=state)
        hub = engine.hub_status()
        assert hub.finale_offered is True

        await engine.handle_request_next_zone(True)
        await engine._generation_task
        zone = engine.save.active_zone
        assert zone.is_finale
        assert tuple(zone.allocated_location_ids) == (C.GOAL_LOCATION_ID,)
        assert zone.zone.reward_location_ids == [C.GOAL_LOCATION_ID]  # test 32

        await engine.handle_enter_zone(zone.zone_id)
        await TX.claim_check(engine, zone.zone_id, C.GOAL_LOCATION_ID)
        await drain()
        assert engine.save.goal_sent is True
        assert backend.server.goal_reports == 1                # test 33

        # Postgame: the portal keeps working, remaining checks allocatable.
        hub = engine.hub_status()
        assert hub.postgame is True
        assert hub.mode == "ZONE_AVAILABLE"
        assert hub.portal_enabled is True
    run(scenario())


# -- 34 --------------------------------------------------------------------

def test_34_coins_available_derived_not_stored(tmp_path):
    assert "coins_available" not in CampaignSave.model_fields

    async def scenario():
        engine, backend = await connected_engine(tmp_path)
        for _ in range(3):
            backend.grant_item(C.ITEM_ID_EPSILON_COIN)
        await drain()
        snap = engine.snapshot()
        assert snap.coins_available == max(
            0, snap.coins_received - snap.coins_spent) == 3
        assert "coins_available" not in engine.save.model_dump()
    run(scenario())


# -- 35 --------------------------------------------------------------------

def test_35_fewer_coins_than_history_clamps(tmp_path):
    async def scenario():
        engine, backend = await connected_engine(tmp_path)
        collector = Collector(engine)
        engine._apply(CampaignSave(**{
            **engine.save.model_dump(), "coins_spent": 5}))
        backend.grant_item(C.ITEM_ID_EPSILON_COIN)
        backend.grant_item(C.ITEM_ID_EPSILON_COIN)
        await drain()
        snap = engine.snapshot()
        assert snap.coins_received == 2
        assert snap.coins_spent == 5              # history preserved
        assert snap.coins_available == 0          # clamped, never negative
        assert collector.notifications("sync_warning")
    run(scenario())


# -- 27 / 28: shop cadence and starvation ----------------------------------

def _crafted_completed(engine, count: int) -> None:
    engine._apply(CampaignSave(**{
        **engine.save.model_dump(), "completed_zone_count": count}))


def test_27_stock_respects_min_remaining(tmp_path):
    async def scenario():
        state = MockServerState()
        state.checked = set(TIER0[4:])            # 001–004 remain, all foreign
        state.delivery_queue = []
        engine, _ = await connected_engine(tmp_path, server_state=state)
        _crafted_completed(engine, 2)
        engine.apply_shop_cadence()
        # pool of 4: stocking may take at most 4-3=1
        assert len(engine.save.shop.stock) == 1

        state2 = MockServerState()
        state2.checked = set(TIER0[3:])           # 3 remain
        state2.delivery_queue = []
        engine2, _ = await connected_engine(tmp_path / "b",
                                            server_state=state2)
        _crafted_completed(engine2, 2)
        engine2.apply_shop_cadence()
        assert len(engine2.save.shop.stock) == 0  # would leave fewer than 3
    run(scenario())


def test_28_reservations_release_before_waiting(tmp_path):
    async def scenario():
        state = MockServerState()
        state.checked = set(TIER0[5:])            # 5 remain
        state.delivery_queue = []
        engine, backend = await connected_engine(tmp_path, server_state=state)
        _crafted_completed(engine, 2)
        engine.apply_shop_cadence()
        assert len(engine.save.shop.stock) == 2

        # Everything unstocked gets checked; only reservations remain.
        stocked = engine._stocked_location_ids()
        for loc in set(TIER0) - state.checked - stocked:
            backend.server.checked.add(loc)
        backend._sync_from_server()
        assert not engine.zone_candidates()
        await engine.reconcile()
        assert not engine.save.shop.stock         # released
        assert engine.hub_status().mode == "ZONE_AVAILABLE"
    run(scenario())


# -- 23: the shop cannot express the goal (also regression 60 shares this) --

def test_23_shop_cannot_stock_goal(tmp_path):
    import pytest
    from archipepsi_bridge.schemas.protocol import ShopStockItem
    with pytest.raises(Exception):
        ShopStockItem(location_id=C.GOAL_LOCATION_ID, cost=6,
                      item_name="x", recipient_name="y", recipient_game="z")

    async def scenario():
        state = MockServerState()
        preload_items(state, C.ITEM_ID_SIGNAL_KEY, C.ITEM_ID_SIGNAL_KEY)
        engine, _ = await connected_engine(tmp_path, server_state=state)
        assert C.GOAL_LOCATION_ID not in engine.shop_candidates()
    run(scenario())


def test_a_failed_save_does_not_strand_the_campaign_in_generating(
        tmp_path, monkeypatch):
    """Playtest 1's softlock, which was the fsync bug's real damage.

    `_apply` used to assign `self.save` and THEN persist. When the write
    raised -- a Windows-only fsync error, in the event -- the mode had
    already advanced to GENERATING in memory, the save never landed, and
    the generation task that runs AFTER `_apply` never launched. The
    player got a Hub whose portal answered "a Zone cannot be started
    right now (mode GENERATING)" forever, for a generation that was not
    running and never would be.

    Any IO failure must leave a legal, retryable Hub. The write is the
    commit point: state that did not persist did not happen.
    """
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        before = engine.hub_status().mode
        assert before != "GENERATING"

        def disk_is_full(path, save):
            raise OSError(errno.ENOSPC, "No space left on device")

        monkeypatch.setattr(store, "write_save", disk_is_full)
        with pytest.raises(OSError):
            await engine.handle_request_next_zone(False)
        monkeypatch.undo()

        assert engine.hub_status().mode == before, (
            f"the failed save left the campaign in "
            f"{engine.hub_status().mode}; the portal will refuse every "
            "future press")

        # And the real proof: the player can just press it again.
        await engine.handle_request_next_zone(False)
        await drain()
        assert engine.hub_status().mode != before, (
            "the retry after a failed save did nothing")

    run(scenario())
