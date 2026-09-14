"""A 450-location campaign, played through the engine.

CS8 surfaced this: the options, the item pool and the apworld all scaled,
and the ENGINE did not. It scouted `range(89100001, 89100031)`, allocated
`ZONE_MAX_CHECKS = 3` Checks per Zone, recorded at most three of them in
the save, and reserved 89100030 as the goal -- so a 450-location campaign
scouted the first thirty locations, played them three at a time, and
treated an ordinary Check as the finale.

Every test here would have passed at prototype scale, which is exactly
why the prototype-scale suite never caught any of it. They run the real
engine against a mock seed generated at the production default.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge.mock_ap import MockAPBackend, MockServerState
from archipepsi_bridge.schemas import constants as C

from .conftest import Collector, drain, make_engine, run

PROD = C.DEFAULT_CONFIG


async def _engine_at(tmp_path, config: C.CampaignConfig):
    engine = make_engine(tmp_path)
    backend = MockAPBackend(engine, server_state=MockServerState(config),
                            config=config)
    engine.backend = backend
    await backend.connect("", "Skyiah", "")
    await drain()
    return engine, backend


def test_the_bridge_scouts_every_location_the_seed_has(tmp_path):
    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        assert len(engine.ap.scouts) == PROD.location_count
        assert max(engine.ap.scouts) == PROD.goal_location_id
    run(scenario())


def test_the_campaign_is_created_at_the_seeds_scale(tmp_path):
    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        assert engine.save is not None
        assert engine.save.scale.config() == PROD
        assert engine.config == PROD
    run(scenario())


def test_a_zone_holds_a_full_zones_worth_of_checks(tmp_path):
    """The bug that made the whole redesign inert.

    `zone_target_checks` is the owner's lever, and the allocator was
    reading the prototype's constant -- so a campaign configured for
    fifteen Checks per Zone played three at a time, which is 150 Zones
    of two minutes rather than 30 Zones of forty.
    """
    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        ids, _ = engine._select_zone_locations()
        assert len(ids) == PROD.zone_target_checks
    run(scenario())


def test_the_generation_request_carries_the_full_budget(tmp_path):
    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        Collector(engine)
        await engine.handle_request_next_zone(False)
        await drain(200)
        record = engine.save.zones[-1]
        assert len(record.allocated_location_ids) == PROD.zone_target_checks
        request = engine._zone_request(record)
        assert request.campaign.zone_budget == PROD.zone_budget
    run(scenario())


def test_a_generated_zone_is_a_production_scale_level(tmp_path):
    """End to end: the engine asks, the fallback builds, the Zone is
    accepted by the same validator a real provider's output goes through.
    """
    from archipepsi_bridge import content_value as V

    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        Collector(engine)
        await engine.handle_request_next_zone(False)
        await drain(400)
        record = engine.save.zones[-1]
        assert record.zone is not None, "generation did not complete"
        low, high = V.budget_band(PROD.zone_budget)
        assert low <= V.zone_value(record.zone) <= high
        assert len(record.zone.chambers) >= 10
        assert (sorted(record.zone.reward_location_ids)
                == sorted(record.allocated_location_ids))
    run(scenario())


def test_the_allocator_reaches_past_the_prototypes_thirty(tmp_path):
    """Tier 0 of a 450-location campaign is 150 Checks, not 10."""
    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        pool = engine.zone_candidates()
        assert len(pool) == len(PROD.locations_in_tier(0))
        assert max(pool) > C.PROTOTYPE_CONFIG.last_location_id
    run(scenario())


def test_the_finale_is_this_campaigns_goal(tmp_path):
    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        assert engine.config.goal_location_id == 89100450
        assert engine.config.goal_location_id not in engine.zone_candidates()
        assert C.GOAL_LOCATION_ID in engine.zone_candidates(), (
            "the prototype's goal is an ORDINARY Check at this size")
    run(scenario())


def test_the_finale_needs_most_of_a_450_check_campaign(tmp_path):
    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        assert engine.hub_status().finale_offered is False
        # 80% of 449 non-goal Checks, not the prototype's 24 of 29.
        assert PROD.finale_required_checks() == 360
    run(scenario())


@pytest.mark.parametrize("size,per_zone", [(30, 3), (90, 5), (600, 30)])
def test_other_configured_sizes_play_too(tmp_path, size, per_zone):
    """Not just the default: the owner asked for a bounded RANGE."""
    config = C.CampaignConfig(location_count=size, zone_target_checks=per_zone,
                              zone_budget=max(C.ZONE_BUDGET_MIN,
                                              per_zone * 60))

    async def scenario():
        engine, _ = await _engine_at(tmp_path, config)
        assert len(engine.ap.scouts) == size
        assert engine.save.scale.config() == config
        ids, _ = engine._select_zone_locations()
        # Bounded ABOVE by the campaign's target, not equal to it: the
        # allocator draws one track at a time, so a small campaign whose
        # current track holds fewer Checks legitimately gets fewer.
        assert 1 <= len(ids) <= per_zone
    run(scenario())


def test_the_finale_beat_names_this_campaigns_goal(tmp_path):
    """The whole endgame reads `goal_location_id`, not a constant.

    Pinned to the prototype's 89100030, a 450-location campaign would
    offer the finale over an ordinary Check and never claim its real one.
    """
    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        goal = PROD.goal_location_id
        # Everything but the goal cleared: the finale is the only thing
        # left, which is the branch `goal_missing` decides.
        ap = engine.ap
        ap.checked = {i for i in PROD.active_location_ids() if i != goal}
        ap.missing = {goal}
        ap.signal_keys = C.FINALE_REQUIRED_SIGNAL_KEYS
        hub = engine.hub_status()
        assert hub.mode == "FINALE_ONLY"
        assert hub.finale_offered is True
        # `goal_missing` picks this line. Pinned to 89100030 it reads
        # the OTHER branch, because the prototype's goal is a Check this
        # campaign has already cleared.
        assert hub.detail == ("Nothing ordinary remains. "
                              "The last transmission waits.")

        Collector(engine)
        await engine.handle_request_next_zone(True)
        await drain(400)
        record = engine.save.zones[-1]
        assert record.is_finale
        assert record.allocated_location_ids == (goal,)
    run(scenario())


def test_every_check_the_campaign_has_is_reachable(tmp_path):
    """Not just the first thirty: walk the allocator to exhaustion.

    A prototype-pinned pool, a prototype-pinned scout range or a
    prototype-pinned save cap each strand the campaign partway through,
    and each one looks fine on the first Zone.
    """
    async def scenario():
        config = C.CampaignConfig(location_count=90, zone_target_checks=5,
                                  zone_budget=400)
        engine, _ = await _engine_at(tmp_path, config)
        engine.ap.signal_keys = C.TIER_COUNT      # everything unlocked
        seen: set[int] = set()
        for _ in range(200):
            pool = engine.zone_candidates()
            if not pool:
                break
            ids, _ = engine._select_zone_locations()
            assert ids, "the allocator stalled with Checks still available"
            seen.update(ids)
            engine.ap.checked.update(ids)
            engine.ap.missing.difference_update(ids)
        expected = set(config.eligible_location_ids(C.TIER_COUNT))
        assert seen == expected, (
            f"{len(expected - seen)} Checks were never offered")
    run(scenario())


def test_confirming_check_030_does_not_end_a_450_check_campaign(tmp_path):
    """The worst of the prototype pins.

    `confirm_check` set `goal_sent` from `C.is_goal_location`, which is
    89100030 -- so a 450-location campaign declared victory on its 30th
    Check and spent the other 420 in the postgame.
    """
    from archipepsi_bridge.schemas import transitions as T
    from archipepsi_bridge.schemas.protocol import (
        CampaignSave, CampaignScale, PendingCheck)

    from archipepsi_bridge.schemas.protocol import ZoneRecord

    def save_holding(location_id: int, is_finale: bool,
                     **scale) -> CampaignSave:
        return CampaignSave(
            seed_name="S", team=0, slot_id=1, slot_name="Skyiah",
            scale=CampaignScale(**scale),
            zones=(ZoneRecord(zone_id="z", state="PENDING_GENERATION",
                              allocated_location_ids=(location_id,),
                              target_game="X", is_finale=is_finale,
                              generation_index=0),),
            active_zone_id="z",
            pending_checks=(PendingCheck(transaction_id="t",
                                         location_id=location_id,
                                         source="zone"),))

    big = dict(location_count=450, zone_target_checks=15, zone_budget=1000)
    assert not T.confirm_check(
        save_holding(C.GOAL_LOCATION_ID, False, **big),
        C.GOAL_LOCATION_ID).goal_sent
    assert T.confirm_check(
        save_holding(PROD.goal_location_id, True, **big),
        PROD.goal_location_id).goal_sent
    # ...and a prototype campaign is unchanged.
    assert T.confirm_check(save_holding(C.GOAL_LOCATION_ID, True),
                           C.GOAL_LOCATION_ID).goal_sent


def test_the_hub_reports_this_campaigns_finale_threshold(tmp_path):
    """The number the player reads has to be the number the gate uses."""
    async def scenario():
        engine, _ = await _engine_at(tmp_path, PROD)
        hub = engine.hub_status()
        assert hub.finale_required == PROD.finale_required_checks() == 360
        assert hub.finale_required != C.FINALE_REQUIRED_OTHER_CHECKS
        # ...and the gate agrees with the readout, at the boundary.
        ap = engine.ap
        ap.checked = set(list(PROD.eligible_location_ids(C.TIER_COUNT))
                         [:hub.finale_required - 1])
        ap.signal_keys = C.FINALE_REQUIRED_SIGNAL_KEYS
        assert engine.hub_status().finale_unlocked is False
        ap.checked = set(list(PROD.eligible_location_ids(C.TIER_COUNT))
                         [:hub.finale_required])
        assert engine.hub_status().finale_unlocked is True
    run(scenario())
