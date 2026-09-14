"""No active unclaimed location may be orphaned by Zone lifecycle state.

FINAL_FINAL_FINAL_PLAN §16 says, in capitals, to write this test FIRST --
before CLEARED != EXHAUSTED lands, not after. §23 lists "CLEARED terminal
behavior that strands remaining Checks" as a hard rejection. This is that
rejection expressed as a test, written against today's lifecycle so it
passes now and fails the moment Phase 2 gets it wrong.

SCOPE, deliberately narrow. This proves a LOCAL campaign/allocator
property. It does NOT prove Archipelago `Accessibility: full` logical
solvability, and nothing here should be cited as if it did -- AP's model
of Archipepsi is three Signal-Key tiers and knows nothing about Zones, so
only real `Generate.py` / apworld tests can speak to that. Those belong
in Phase 2, once Architecture D capability logic actually exists in the
apworld (today: zero references).

THE PROPERTY, stated once:

    Every ACTIVE, UNCLAIMED location has at least one live route to
    being claimed.

The routes are enumerated in `claim_routes()`. A location with no route
is ORPHANED, and an orphan is the bug: a Check the campaign still counts
but the player can no longer get to.

The assertions are written against SEMANTIC accessors -- `holds_locations`,
`zone_candidates()` -- and never against lifecycle state NAMES. Phase 2
may rename or re-shape states freely; it may not orphan a location. If
this file needs editing to make Phase 2 pass, read the diff carefully:
that is either a genuine model change or the bug this file exists for.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge.mock_ap import MockAPBackend, MockServerState
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.protocol import ZoneRecord

from .conftest import drain, make_engine, run

#: The three scales the campaign is actually configurable across. CS8b's
#: lesson was that a suite which only runs at one scale certifies one
#: scale, so this runs at the floor, the production default and the
#: ceiling.
SCALES = [
    ("prototype", C.PROTOTYPE_CONFIG),
    ("default", C.DEFAULT_CONFIG),
    ("max", C.CampaignConfig(location_count=C.LOCATION_COUNT_MAX,
                             zone_target_checks=C.ZONE_TARGET_CHECKS_MAX,
                             zone_budget=C.ZONE_BUDGET_MAX)),
]

#: The Phase-2 target: a Zone is CLEARED at five Checks plus the exit,
#: not at fifteen. Used by the lifecycle policies below.
CLEAR_AT = 5


# ---------------------------------------------------------------------------
# The property
# ---------------------------------------------------------------------------

def player_can_still_claim_from(engine, record: ZoneRecord) -> bool:
    """Whether the player can still claim the Checks this Zone holds.

    TEST-OWNED CONTRACT, and the single place Phase 2 must update.

    Today a Zone that still reserves its locations is one the player is
    standing in or can resume, so reserving and being claimable-from
    coincide. Phase 2 separates them: a CLEARED Zone may keep holding
    its remaining Checks *and* be re-enterable (the target), or keep
    holding them while being unreachable (the bug). When real re-entry
    truth exists, point this at it -- do not point it at a state name.
    """
    return record.holds_locations


def claim_routes(engine, location_id: int) -> frozenset[str]:
    """Every live route by which `location_id` can still be claimed.

    Empty means orphaned. The routes are not mutually exclusive; a
    location needs at least one.
    """
    config = engine.config
    routes: set[str] = set()

    if location_id in engine.zone_candidates(ignore_stock=True):
        routes.add("ALLOCATABLE")          # the allocator can hand it out

    for record in engine.save.zones:
        if location_id not in record.allocated_location_ids:
            continue
        if player_can_still_claim_from(engine, record):
            routes.add("HELD_AND_CLAIMABLE")

    if location_id in engine._pending_location_ids():
        routes.add("PENDING")              # a claim already in flight

    if location_id in engine._stocked_location_ids():
        routes.add("STOCKED")              # buyable in the shop

    # Behind a Signal-Key tier the player has not opened yet. Tiers only
    # ever open, so this is a real future route rather than an excuse.
    if location_id not in config.eligible_location_ids(engine.ap.signal_keys):
        routes.add("NOT_YET_ELIGIBLE")

    return frozenset(routes)


def orphans(engine) -> dict[int, frozenset[str]]:
    """Active, unclaimed locations with no route left. Empty is correct."""
    config = engine.config
    out: dict[int, frozenset[str]] = {}
    for location_id in config.active_location_ids():
        if location_id in engine.ap.checked:
            continue
        if config.is_goal_location(location_id):
            continue                       # the goal has its own gate
        routes = claim_routes(engine, location_id)
        if not routes:
            out[location_id] = routes
    return out


# ---------------------------------------------------------------------------
# Lifecycle policies: how a Zone behaves once its Checks are claimed
# ---------------------------------------------------------------------------
#
# These are TEST fixtures, not production code. They let one walk exercise
# today's lifecycle and the two Phase-2 candidates without the production
# allocator knowing anything about them.

def policy_today(record: ZoneRecord, claimed: int, allocated: int) -> str:
    """Today: a Zone is finished only when every Check is confirmed."""
    return "COMPLETE" if claimed >= allocated else "PENDING_GENERATION"


def policy_cleared_at_5_releases(record: ZoneRecord, claimed: int,
                                 allocated: int) -> str:
    """SABOTAGE A -- CLEARED at five behaves terminally.

    The Zone goes terminal once five Checks are claimed, so its other ten
    are released back to the allocator (measured: 15 of 15 return).
    """
    return "COMPLETE" if claimed >= min(CLEAR_AT, allocated) \
        else "PENDING_GENERATION"


def policy_cleared_at_5_holds(record: ZoneRecord, claimed: int,
                              allocated: int) -> str:
    """The Phase-2 target: CLEARED at five, still holding, re-enterable."""
    return "PENDING_GENERATION"


def walk_campaign(engine, policy, *, clear_at: int | None = None,
                  max_zones: int = 400):
    """Allocate Zones until the pool runs dry, claiming Checks as we go.

    Returns the list of snapshots taken after every step, so a test can
    assert the property CONTINUOUSLY rather than only at the end -- the
    Echo-log sabotage taught that a suite reading only the final state
    passes through a bug that healed itself.
    """
    seen_orphans: list[dict[int, frozenset[str]]] = []
    zones = 0
    while zones < max_zones:
        # Signal Keys arrive from the multiworld and open the next tier.
        # Without this the walk exhausts tier 0 and stops, leaving two
        # thirds of the campaign NOT_YET_ELIGIBLE -- correctly un-orphaned
        # but never actually walked, which would certify a third of the
        # campaign and call it all of it.
        while (not engine.zone_candidates()
               and engine.ap.signal_keys < C.TIER_COUNT - 1):
            engine.ap.signal_keys += 1
        if not engine.zone_candidates():
            break
        ids, target = engine._select_zone_locations()
        if not ids:
            break
        record = ZoneRecord(
            zone_id="zone_%03d" % zones, state="PENDING_GENERATION",
            allocated_location_ids=tuple(ids), target_game=target,
            generation_index=zones)
        engine.save = engine.save.model_copy(
            update={"zones": engine.save.zones + (record,)})
        seen_orphans.append(orphans(engine))

        # Claim the Checks this Zone gives up, then apply the policy.
        take = len(ids) if clear_at is None else min(clear_at, len(ids))
        for location_id in ids[:take]:
            engine.ap.checked.add(location_id)
            engine.ap.missing.discard(location_id)
        state = policy(record, take, len(ids))
        updated = record.model_copy(update={"state": state})
        engine.save = engine.save.model_copy(
            update={"zones": engine.save.zones[:-1] + (updated,)})
        seen_orphans.append(orphans(engine))
        zones += 1
    return zones, seen_orphans


async def engine_at(tmp_path, config: C.CampaignConfig):
    engine = make_engine(tmp_path)
    backend = MockAPBackend(engine, server_state=MockServerState(config),
                            config=config)
    engine.backend = backend
    await backend.connect("", "Skyiah", "")
    await drain()
    return engine


# ---------------------------------------------------------------------------
# 1. The property holds at rest, at every configured scale
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("name,config", SCALES, ids=[s[0] for s in SCALES])
def test_a_fresh_campaign_orphans_nothing(tmp_path, name, config):
    """Before anything is allocated, every active Check has a route."""
    async def scenario():
        engine = await engine_at(tmp_path, config)
        assert orphans(engine) == {}, (
            "%s scale orphans locations before the campaign even starts"
            % name)
    run(scenario())


@pytest.mark.parametrize("name,config", SCALES, ids=[s[0] for s in SCALES])
def test_an_allocated_zone_holds_rather_than_orphans(tmp_path, name, config):
    """Allocation removes ids from the pool; the holding Zone is the route.

    This is the step where a location stops being ALLOCATABLE. If nothing
    picked up the other end of it, that is the orphan.
    """
    async def scenario():
        engine = await engine_at(tmp_path, config)
        ids, target = engine._select_zone_locations()
        record = ZoneRecord(
            zone_id="zone_hold", state="PENDING_GENERATION",
            allocated_location_ids=tuple(ids), target_game=target,
            generation_index=0)
        engine.save = engine.save.model_copy(update={"zones": (record,)})

        assert orphans(engine) == {}, "%s scale orphaned on allocation" % name
        for location_id in ids:
            assert "HELD_AND_CLAIMABLE" in claim_routes(engine, location_id), (
                "%d is allocated but nothing can claim it" % location_id)
    run(scenario())


# ---------------------------------------------------------------------------
# 2. The whole campaign, walked to exhaustion
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("name,config", SCALES, ids=[s[0] for s in SCALES])
def test_walking_the_campaign_to_exhaustion_orphans_nothing(
        tmp_path, name, config):
    """Today's lifecycle: allocate, claim everything, retire, repeat.

    Checked after EVERY step, not only at the end.
    """
    async def scenario():
        engine = await engine_at(tmp_path, config)
        zones, seen = walk_campaign(engine, policy_today)
        assert zones > 0, "%s scale allocated no Zones at all" % name
        for step, found in enumerate(seen):
            assert found == {}, (
                "%s scale orphaned %d location(s) at step %d: %s"
                % (name, len(found), step, sorted(found)[:5]))
        remaining = [i for i in config.active_location_ids()
                     if i not in engine.ap.checked
                     and not config.is_goal_location(i)]
        assert not remaining, (
            "%s scale finished the walk with %d unclaimed non-goal Checks"
            % (name, len(remaining)))
    run(scenario())


@pytest.mark.parametrize("name,config", SCALES, ids=[s[0] for s in SCALES])
def test_clearing_early_while_holding_orphans_nothing(tmp_path, name, config):
    """The Phase-2 TARGET: CLEARED at five, remaining Checks still held.

    This is the shape the plan wants, so it must be orphan-free BEFORE it
    is implemented. It exhausts the pool (each Zone permanently holds its
    unclaimed ten), and every one of those ids must stay claimable through
    the Zone that holds it.
    """
    async def scenario():
        engine = await engine_at(tmp_path, config)
        _, seen = walk_campaign(engine, policy_cleared_at_5_holds,
                                clear_at=CLEAR_AT)
        for step, found in enumerate(seen):
            assert found == {}, (
                "%s scale orphaned %d location(s) at step %d under "
                "clear-at-%d: %s"
                % (name, len(found), step, CLEAR_AT, sorted(found)[:5]))

        # ...and the unclaimed remainder really is held, not merely absent.
        held = {i for z in engine.save.zones if z.holds_locations
                for i in z.allocated_location_ids}
        unclaimed = [i for i in config.active_location_ids()
                     if i not in engine.ap.checked
                     and not config.is_goal_location(i)]
        assert set(unclaimed) <= held, (
            "%s scale left %d unclaimed Checks held by nothing"
            % (name, len(set(unclaimed) - held)))
    run(scenario())


# ---------------------------------------------------------------------------
# 3. The guard's own guard
# ---------------------------------------------------------------------------
#
# A test that passes because it cannot fail is worse than no test. These
# two prove what this file does and does not catch.

def test_a_zone_that_holds_but_cannot_be_reached_is_caught(tmp_path):
    """SABOTAGE B -- the orphan this file exists for.

    A Zone keeps reserving its unclaimed Checks and the player can no
    longer claim from it. Nothing releases them and nothing can reach
    them: they are held by a dead Zone forever.

    Simulated by breaking the test's own re-enterability contract rather
    than by touching production code -- which is the point, since the
    production model has no way to express this yet. Phase 2 will.
    """
    async def scenario():
        engine = await engine_at(tmp_path, C.DEFAULT_CONFIG)
        ids, target = engine._select_zone_locations()
        record = ZoneRecord(
            zone_id="zone_dead", state="PENDING_GENERATION",
            allocated_location_ids=tuple(ids), target_game=target,
            generation_index=0)
        engine.save = engine.save.model_copy(update={"zones": (record,)})
        assert orphans(engine) == {}, "sabotage started from a broken state"

        global player_can_still_claim_from
        original = player_can_still_claim_from
        try:
            player_can_still_claim_from = lambda _e, _r: False
            found = orphans(engine)
        finally:
            player_can_still_claim_from = original

        assert len(found) == len(ids), (
            "a Zone holding %d Checks that the player cannot claim from "
            "was not reported as orphaning them (got %d)"
            % (len(ids), len(found)))
        assert orphans(engine) == {}, "the sabotage did not clean up"
    run(scenario())


def test_clearing_early_and_releasing_does_not_orphan_and_here_is_why(
        tmp_path):
    """SABOTAGE A -- and it does NOT fail. Recorded deliberately.

    The brief asked for a sabotage where a Zone clears at five, behaves
    terminally, and releases its remaining ten, expecting this file to go
    red. It does not, and pretending otherwise would be the more harmful
    outcome, so the real behaviour is pinned here instead.

    A terminal Zone returns all of its unclaimed Checks to the allocator
    (measured: 15 of 15; a non-terminal one returns 0). Released is one of
    the two OUTCOMES THE PROPERTY EXPLICITLY ALLOWS, so no location is
    orphaned -- they simply reappear in later Zones, and the walk still
    reaches every Check.

    What that behaviour actually costs is not stranding. It is the
    metroidvania promise: the ledge you could not reach stops existing,
    and the Check turns up somewhere else. That is a design consequence,
    visible in this test as a Zone COUNT, and it is what the assertion
    below records.
    """
    async def scenario():
        engine = await engine_at(tmp_path, C.DEFAULT_CONFIG)
        zones, seen = walk_campaign(engine, policy_cleared_at_5_releases,
                                    clear_at=CLEAR_AT)
        for found in seen:
            assert found == {}, (
                "release-on-clear orphaned %d location(s), which would "
                "mean the property is stated wrong" % len(found))

        baseline_zones = -(-C.DEFAULT_CONFIG.non_goal_count
                           // C.DEFAULT_CONFIG.zone_target_checks)
        assert zones > baseline_zones, (
            "clearing at %d should need MORE Zones than claiming all %d "
            "(got %d against a %d-Zone baseline); if it does not, the "
            "release path is not doing what was measured"
            % (CLEAR_AT, C.DEFAULT_CONFIG.zone_target_checks,
               zones, baseline_zones))
        print("\nclear-at-%d with release: %d Zones against a %d-Zone "
              "baseline -- no orphans, %d Checks claimed"
              % (CLEAR_AT, zones, baseline_zones, len(engine.ap.checked)))
    run(scenario())
