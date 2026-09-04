"""Campaign-integrity regression tests 60–70 (ACCEPTANCE_TESTS §5.5)."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from archipepsi_bridge import transactions as TX
from archipepsi_bridge.campaign import IntentError
from archipepsi_bridge.mock_ap import MockServerState
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.protocol import (
    BuyShopStock, CampaignSave, HubStatus, PendingCheck, ShopState,
    ShopStockItem, ZoneRecord,
)

from .conftest import (
    BlockedProvider, connected_engine, drain, run,
)
from .test_campaign import NON_GOAL, TIER0, _crafted_completed, preload_items

GOAL = C.GOAL_LOCATION_ID


# -- 60 --------------------------------------------------------------------

def test_60_no_acquisition_path_names_the_goal(tmp_path):
    """The rule survived a move; the coverage has to move with it.

    Until campaign scale became an option, every acquisition-capable
    field was typed to a closed range ending one below the goal, so the
    four constructions below raised on their own. Which id is the goal
    now depends on `location_count`, which a single record cannot see --
    so the rule lives on `CampaignSave`, which knows its own scale, and
    that is where it is checked. The point of the test is unchanged: no
    path except the finale Zone can name the goal.
    """
    def save(**kw):
        return CampaignSave(seed_name="S", team=0, slot_id=1,
                            slot_name="Skyiah", **kw)

    with pytest.raises(ValidationError, match="finale"):
        save(shop=ShopState(stock=(ShopStockItem(
            location_id=GOAL, cost=6, item_name="x",
            recipient_name="y", recipient_game="z"),)))
    with pytest.raises(ValidationError, match="finale"):
        save(pending_checks=(PendingCheck(
            transaction_id="t", location_id=GOAL, source="shop",
            shop_cost=6),), coins_spent=6)
    with pytest.raises(ValidationError, match="finale"):
        save(zones=(ZoneRecord(
            zone_id="z", state="PENDING_GENERATION",
            allocated_location_ids=(GOAL,), target_game="X",
            is_finale=False, generation_index=0),),
            active_zone_id="z")
    # A finale Zone holds the goal and NOTHING else -- the one rule a
    # record can still enforce alone, because it counts rather than
    # compares.
    with pytest.raises(ValidationError, match="exactly one location"):
        ZoneRecord(zone_id="z", state="PENDING_GENERATION",
                   allocated_location_ids=(GOAL, GOAL - 1), target_game="X",
                   is_finale=True, generation_index=0)
    for keys in range(4):
        assert GOAL not in C.eligible_location_ids(keys)
    # The one legal path: a zone-source pending check (the finale).
    PendingCheck(transaction_id="t", location_id=GOAL, source="zone")


def test_60b_the_goal_moves_with_the_campaign_size(tmp_path):
    """A 450-location campaign reserves 89100450, not 89100030.

    The old range hardcoded the prototype's goal, so at any other size it
    would have reserved an ordinary Check and left the real goal buyable.
    """
    from archipepsi_bridge.schemas.protocol import CampaignScale

    big = dict(seed_name="S", team=0, slot_id=1, slot_name="Skyiah",
               scale=CampaignScale(location_count=450, zone_target_checks=15,
                                   zone_budget=1000))
    goal = C.DEFAULT_CONFIG.goal_location_id
    assert goal != GOAL

    with pytest.raises(ValidationError, match="finale"):
        CampaignSave(**big, shop=ShopState(stock=(ShopStockItem(
            location_id=goal, cost=6, item_name="x",
            recipient_name="y", recipient_game="z"),)))
    # ...and the prototype's goal is an ORDINARY Check at this size.
    CampaignSave(**big, shop=ShopState(stock=(ShopStockItem(
        location_id=GOAL, cost=6, item_name="x",
        recipient_name="y", recipient_game="z"),)))


# -- 61 --------------------------------------------------------------------

def test_61_allocator_pool_is_goal_free():
    for keys in range(4):
        unlocked = set(C.unlocked_location_ids(keys))
        eligible = set(C.eligible_location_ids(keys))
        assert eligible == unlocked - {GOAL}


# -- 62 --------------------------------------------------------------------

def test_62_unbacked_pending_rejected():
    base = dict(seed_name="S", team=0, slot_id=1, slot_name="Skyiah")
    with pytest.raises(ValidationError, match="pending Zone checks"):
        CampaignSave(**base, pending_checks=(
            PendingCheck(transaction_id="t", location_id=89100001,
                         source="zone"),))
    many = tuple(
        PendingCheck(transaction_id=f"t{i}", location_id=89100001 + i,
                     source="zone")
        for i in range(29))
    with pytest.raises(ValidationError):
        CampaignSave(**base, pending_checks=many)


# -- 63 --------------------------------------------------------------------

def test_63_coin_ledger_covers_in_flight(tmp_path):
    base = dict(seed_name="S", team=0, slot_id=1, slot_name="Skyiah")
    with pytest.raises(ValidationError, match="coins_spent"):
        CampaignSave(**base, coins_spent=2, pending_checks=(
            PendingCheck(transaction_id="t", location_id=89100001,
                         source="shop", shop_cost=4),))
    with pytest.raises(ValidationError):
        PendingCheck(transaction_id="t", location_id=89100001,
                     source="zone", shop_cost=2)   # a zone claim never costs
    with pytest.raises(ValidationError):
        PendingCheck(transaction_id="t", location_id=89100001,
                     source="shop", shop_cost=0)   # a purchase always costs
    with pytest.raises(ValidationError):
        ShopStockItem(location_id=89100001, cost=0, item_name="x",
                      recipient_name="y", recipient_game="z")

    async def scenario():
        state = MockServerState()
        state.checked = set(TIER0[6:])
        state.delivery_queue = []
        preload_items(state, *(C.ITEM_ID_EPSILON_COIN,) * 6)
        engine, backend = await connected_engine(
            tmp_path, server_state=state, confirm_delay=9999)
        _crafted_completed(engine, 2)
        engine.apply_shop_cadence()
        item = engine.save.shop.stock[0]
        before = engine.save.coins_spent
        await TX.buy_shop_stock(engine, item.location_id)
        assert engine.save.coins_spent == before + item.cost
        rolled = T.rollback_shop_purchase(engine.save, item.location_id)
        assert rolled.coins_spent == before        # never below zero
    run(scenario())


# -- 64 --------------------------------------------------------------------

def test_64_second_request_during_generation_refused(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path,
                                           provider=BlockedProvider())
        await engine.handle_request_next_zone(False)
        hub = engine.hub_status()
        assert hub.mode == "GENERATING"
        assert hub.portal_enabled is False
        assert hub.accepts_zone_request is False
        with pytest.raises(IntentError):
            await engine.handle_request_next_zone(False)
        with pytest.raises(IntentError):
            await engine.handle_request_next_zone(True)   # finale path too
        # The transition layer refuses independently of the Hub mode.
        with pytest.raises(ValueError):
            T.start_generation(engine.save, zone_id="rogue",
                               allocated_location_ids=[89100009],
                               target_game="X")
        engine._generation_task.cancel()
    run(scenario())


# -- 65 --------------------------------------------------------------------

def test_65_hub_mode_agrees_with_zone_state(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        assert engine.snapshot().hub.mode == "ZONE_AVAILABLE"
        await engine.handle_request_next_zone(False)
        await engine._generation_task
        snap = engine.snapshot()
        assert snap.active_zone.state == "GENERATED"
        assert snap.hub.mode == "ZONE_READY"
        await engine.handle_enter_zone(snap.active_zone.zone_id)
        snap = engine.snapshot()
        assert snap.active_zone.state == "ACTIVE"
        assert snap.hub.mode == "ZONE_ACTIVE"
        assert snap.hub.holding_finale is False
        await engine.handle_abandon_zone(snap.active_zone.zone_id)
        snap = engine.snapshot()
        assert snap.active_zone is None           # terminal, never presented
        assert snap.hub.mode == "ZONE_AVAILABLE"
    run(scenario())


# -- 66 --------------------------------------------------------------------

def test_66_purchase_is_atomic_and_unique(tmp_path):
    async def scenario():
        state = MockServerState()
        state.checked = set(TIER0[6:])
        state.delivery_queue = []
        preload_items(state, *(C.ITEM_ID_EPSILON_COIN,) * 8)
        engine, backend = await connected_engine(
            tmp_path, server_state=state, confirm_delay=9999)
        _crafted_completed(engine, 2)
        engine.apply_shop_cadence()
        item = engine.save.shop.stock[0]
        before_spent = engine.save.coins_spent

        await TX.buy_shop_stock(engine, item.location_id)
        assert all(s.location_id != item.location_id
                   for s in engine.save.shop.stock)      # left stock
        assert any(p.location_id == item.location_id and p.source == "shop"
                   for p in engine.save.pending_checks)  # entered ledger
        assert engine.save.coins_spent == before_spent + item.cost

        # A restock in flight cannot evict the purchase.
        engine._apply(T.restock_shop(engine.save, []))
        assert any(p.location_id == item.location_id
                   for p in engine.save.pending_checks)

        # A second buy for the same location is refused, charged once.
        with pytest.raises(IntentError):
            await TX.buy_shop_stock(engine, item.location_id)
        assert engine.save.coins_spent == before_spent + item.cost
        assert sum(1 for p in engine.save.pending_checks
                   if p.location_id == item.location_id) == 1
    run(scenario())


# -- 67 --------------------------------------------------------------------

def test_67_campaign_state_is_immutable(tmp_path):
    save = CampaignSave(seed_name="S", team=0, slot_id=1, slot_name="Skyiah")
    with pytest.raises(ValidationError):
        save.coins_spent = 5
    with pytest.raises(ValidationError):
        save.active_zone_id = "z"
    assert isinstance(save.pending_checks, tuple)
    assert isinstance(save.zones, tuple)
    assert isinstance(save.shop.stock, tuple)
    assert not hasattr(save.pending_checks, "append")
    with pytest.raises(ValidationError):
        save.shop.created_after_zone_count = 3    # nested assignment too


# -- 68 --------------------------------------------------------------------

def test_68_connectivity_is_not_campaign_state(tmp_path):
    async def scenario():
        engine, backend = await connected_engine(tmp_path)
        assert engine.snapshot().hub.mode == "ZONE_AVAILABLE"
        await backend.disconnect()
        await drain()
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_AVAILABLE"       # mode untouched
        assert hub.ap_online is False
        assert hub.portal_enabled is False        # generation needs scouts
        assert "ARCHIPELAGO OFFLINE" in hub.detail
        assert engine.snapshot().ap_state_is_current is False

        # A held Zone stays enterable offline.
        await backend.connect("", "Skyiah", "")
        await drain()
        await engine.handle_request_next_zone(False)
        await engine._generation_task
        await backend.disconnect()
        await drain()
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_READY"
        assert hub.portal_enabled is True
    run(scenario())


# -- 69 --------------------------------------------------------------------

def test_69_release_location_keeps_zone(tmp_path):
    async def scenario():
        engine, _ = await connected_engine(tmp_path)
        await engine.handle_request_next_zone(False)
        await engine._generation_task
        zone = engine.save.active_zone
        await engine.handle_enter_zone(zone.zone_id)
        ids = list(zone.allocated_location_ids)
        assert len(ids) >= 2

        engine._apply(T.release_location(engine.save, zone.zone_id, ids[0]))
        rec = engine.save.zone_by_id(zone.zone_id)
        assert rec.state == "ACTIVE"              # zone survives
        assert ids[0] not in rec.allocated_location_ids

        for loc in ids[1:]:
            engine._apply(T.release_location(engine.save, zone.zone_id, loc))
        rec = engine.save.zone_by_id(zone.zone_id)
        assert rec.state == "ABANDONED"           # releasing the last abandons
        assert engine.save.active_zone_id is None
    run(scenario())


# -- 70 --------------------------------------------------------------------

def test_70_finale_gate_is_executable(tmp_path):
    with pytest.raises(ValidationError):
        HubStatus(mode="FINALE_ONLY", headline="x", finale_progress=0,
                  signal_keys=0)

    async def scenario():
        state = MockServerState()
        state.checked = set(NON_GOAL[:24])
        state.delivery_queue = []
        preload_items(state, C.ITEM_ID_SIGNAL_KEY, C.ITEM_ID_SIGNAL_KEY)
        engine, _ = await connected_engine(tmp_path, server_state=state)
        await engine.handle_request_next_zone(False)
        await engine._generation_task
        hub = engine.hub_status()
        assert hub.finale_unlocked is True        # threshold met, never hidden
        assert hub.finale_offered is False        # but a Zone is held
    run(scenario())
