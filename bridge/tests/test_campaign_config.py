"""Campaign scale is a per-seed choice, and everything derives from it.

`CAMPAIGN_SCALE.md` is the model; this is the executable half. The rules
that matter are the ones that would silently corrupt a multiworld rather
than crash it:

- an id must mean the same Check in every seed ever generated
- the item pool must be EXACTLY the location count, not approximately
- the goal must never be allocatable
- an old campaign must never be reinterpreted at the new defaults

Each of those is quiet when wrong. A pool one item short fails deep in
Archipelago's fill with a message about the wrong thing; a renumbered id
hands a player someone else's item.
"""

from __future__ import annotations

import math

import pytest

from archipepsi_bridge.schemas import constants as C

#: Sizes worth checking: both bounds, the two defaults, an odd number that
#: does not divide by the tier count, and a prime.
SIZES = [30, 31, 32, 97, 100, 450, 599, 600]


def test_the_prototype_config_reproduces_the_legacy_constants():
    """The migration is lossless or it is not a migration.

    Every not-yet-migrated call site still reads the module constants, so
    these two descriptions of the same campaign have to agree for as long
    as both exist. When the last caller moves over, the constants go and
    this test goes with them.
    """
    p = C.PROTOTYPE_CONFIG
    assert p.location_count == C.LOCATION_COUNT
    assert p.zone_target_checks == C.ZONE_TARGET_CHECKS
    assert p.first_location_id == C.FIRST_LOCATION_ID
    assert p.last_location_id == C.LAST_LOCATION_ID
    assert p.goal_location_id == C.GOAL_LOCATION_ID
    assert p.tier_bounds() == C.TIER_BOUNDS
    assert p.finale_required_checks() == C.FINALE_REQUIRED_OTHER_CHECKS, (
        "the derived finale fraction no longer reproduces the prototype's "
        "literal 24, so an existing campaign would change requirement "
        "under a player mid-run")
    assert p.item_counts() == {
        C.ITEM_NAME_SIGNAL_KEY: C.SIGNAL_KEY_COUNT,
        C.ITEM_NAME_EPSILON_COIN: C.EPSILON_COIN_COUNT,
        C.ITEM_NAME_EPSILON_STATIC: C.EPSILON_STATIC_COUNT,
    }
    for tier in range(C.TIER_COUNT):
        assert p.locations_in_tier(tier) == C.locations_in_tier(tier)
    for keys in range(0, C.TIER_COUNT + 1):
        assert p.unlocked_location_ids(keys) == C.unlocked_location_ids(keys)
        assert p.eligible_location_ids(keys) == C.eligible_location_ids(keys)


@pytest.mark.parametrize("size", SIZES)
def test_the_item_pool_is_exactly_the_location_count(size):
    """Not approximately. Archipelago fills one item per location, and a
    pool off by one fails in `fill` with a message about something else."""
    counts = C.CampaignConfig(location_count=size).item_counts()
    assert sum(counts.values()) == size, counts
    assert all(n >= 0 for n in counts.values()), counts


@pytest.mark.parametrize("size", SIZES)
def test_the_tiers_partition_the_active_range_exactly(size):
    """Every active location is in exactly one tier, and no tier reaches
    past the campaign. An uneven count gives its remainder to the earliest
    tiers rather than dropping it."""
    cfg = C.CampaignConfig(location_count=size)
    seen: list[int] = []
    for tier in range(C.TIER_COUNT):
        seen.extend(cfg.locations_in_tier(tier))
    assert seen == cfg.active_location_ids(), (
        f"tiers do not cover [{cfg.first_location_id}, "
        f"{cfg.last_location_id}] exactly at size {size}")
    assert len(set(seen)) == len(seen), "a location is in two tiers"
    for loc in seen:
        cfg.tier_of(loc)          # raises if it belongs to none


@pytest.mark.parametrize("size", SIZES)
def test_the_goal_is_the_last_active_location_and_never_allocatable(size):
    cfg = C.CampaignConfig(location_count=size)
    assert cfg.goal_location_id == cfg.active_location_ids()[-1]
    for keys in range(0, C.TIER_COUNT + 1):
        assert cfg.goal_location_id not in cfg.eligible_location_ids(keys), (
            "the goal leaked into ordinary allocation; a Zone or the shop "
            "could hand out the win")
    # ...and it IS reachable to Archipelago, which sees an ordinary Tier 2
    # location. Those two views differing is the whole point of the split.
    assert cfg.goal_location_id in cfg.unlocked_location_ids(C.TIER_COUNT - 1)


@pytest.mark.parametrize("size", SIZES)
def test_the_finale_needs_more_than_tier_one_can_supply(size):
    """The finale must require reaching Tier 2. If a substantial majority
    of Checks were available before the last Signal Key, the key would
    stop being progression."""
    cfg = C.CampaignConfig(location_count=size)
    required = cfg.finale_required_checks()
    assert required == math.ceil(
        cfg.non_goal_count * C.FINALE_REQUIRED_FRACTION)
    assert required <= cfg.non_goal_count, "unreachable finale"
    assert required > len(cfg.unlocked_location_ids(1)), (
        f"at size {size} the finale opens on Tier 1 locations alone")


def test_an_id_means_the_same_check_in_every_campaign_size():
    """The stable universe. A location's id may NEVER move because someone
    chose a different campaign size -- a renumbered id hands a player an
    item that belongs to a different Check."""
    reference = C.CampaignConfig(location_count=C.LOCATION_COUNT_MAX)
    for size in SIZES:
        cfg = C.CampaignConfig(location_count=size)
        active = cfg.active_location_ids()
        assert active == reference.active_location_ids()[:size], (
            f"size {size} does not instantiate a PREFIX of the stable "
            "universe; ids have been renumbered")


@pytest.mark.parametrize("field,bad", [
    ("location_count", C.LOCATION_COUNT_MIN - 1),
    ("location_count", C.LOCATION_COUNT_MAX + 1),
    ("zone_target_checks", C.ZONE_TARGET_CHECKS_MIN - 1),
    ("zone_target_checks", C.ZONE_TARGET_CHECKS_MAX + 1),
    ("zone_budget", C.ZONE_BUDGET_MIN - 1),
    ("zone_budget", C.ZONE_BUDGET_MAX + 1),
])
def test_out_of_range_options_are_refused(field, bad):
    """Bounds are tested, not advisory. A call site does not get to widen
    the campaign space by passing a bigger number."""
    with pytest.raises(ValueError, match=field):
        C.CampaignConfig(**{field: bad})


def test_the_universe_is_the_maximum_so_a_prefix_is_always_available():
    assert C.LOCATION_UNIVERSE == C.LOCATION_COUNT_MAX
    assert C.DEFAULT_LOCATION_COUNT <= C.LOCATION_UNIVERSE


def test_the_defaults_are_the_documented_campaign():
    """CAMPAIGN_SCALE.md quotes 450 / 15 / 1000 and does the arithmetic
    from them. If the code drifts, the document is wrong and nobody finds
    out from reading either one."""
    d = C.DEFAULT_CONFIG
    assert (d.location_count, d.zone_target_checks, d.zone_budget) == (
        450, 15, 1000)
    ordinary = d.non_goal_count / d.zone_target_checks
    assert 29 <= ordinary <= 31, (
        f"the default no longer produces ~30 ordinary Zones ({ordinary:.1f})")


def test_every_legal_campaign_size_holds_the_exactness_rules():
    """The whole range, not a sample.

    The parametrized cases above are readable and were NOT sufficient: a
    deliberately broken pool -- rounding both halves instead of giving the
    remainder to Static -- passed all eight of them, and breaks at 25
    sizes in the range, the first being 37. None of the sampled sizes was
    one of those.

    "Exactly" is a claim about every size a player can pick, so it is
    checked at every size a player can pick. 571 cases of cheap
    arithmetic is not a cost worth sampling away.
    """
    for size in range(C.LOCATION_COUNT_MIN, C.LOCATION_COUNT_MAX + 1):
        cfg = C.CampaignConfig(location_count=size)

        counts = cfg.item_counts()
        assert sum(counts.values()) == size, (
            f"size {size}: pool is {sum(counts.values())}, not {size}")
        assert all(n >= 0 for n in counts.values()), (size, counts)

        covered: list[int] = []
        for tier in range(C.TIER_COUNT):
            covered.extend(cfg.locations_in_tier(tier))
        assert covered == cfg.active_location_ids(), (
            f"size {size}: tiers do not partition the active range")

        assert cfg.goal_location_id not in cfg.eligible_location_ids(
            C.TIER_COUNT), f"size {size}: the goal is allocatable"

        assert cfg.finale_required_checks() > len(
            cfg.unlocked_location_ids(1)), (
            f"size {size}: the finale opens on Tier 1 alone")


def test_a_save_written_before_the_options_is_a_prototype_campaign():
    """The migration rule, and it is load-bearing.

    An old save has no `scale` block. It must load as the 30-location
    campaign it actually was. Reading it as 450 would invent 420 locations
    the seed never had, and every item the multiworld placed on them would
    be unreachable -- for the other players too, since their progression
    can sit on our Checks.
    """
    from archipepsi_bridge.schemas.protocol import CampaignSave

    legacy = {
        "save_version": 1, "schema_version": 8,
        "seed_name": "Seed", "team": 0, "slot_id": 1, "slot_name": "Skyiah",
    }
    save = CampaignSave.model_validate(legacy)
    assert save.scale.config() == C.PROTOTYPE_CONFIG, (
        "a pre-options save was reinterpreted at a scale it never had")
    assert save.scale.location_count == 30
    assert save.scale.zone_target_checks == 3


def test_a_save_records_the_scale_it_was_generated_with():
    from archipepsi_bridge.schemas.protocol import CampaignSave, CampaignScale

    save = CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        scale=CampaignScale(location_count=450, zone_target_checks=15,
                            zone_budget=1000))
    assert save.scale.config() == C.DEFAULT_CONFIG
    # ...and it survives a round trip, because reconnecting must not
    # silently resize the campaign.
    again = CampaignSave.model_validate_json(save.model_dump_json())
    assert again.scale.config() == C.DEFAULT_CONFIG


def test_a_save_cannot_hold_a_scale_the_system_would_refuse():
    """The save is not a back door around the bounds."""
    from archipepsi_bridge.schemas.protocol import CampaignScale

    with pytest.raises(Exception, match="location_count"):
        CampaignScale(location_count=C.LOCATION_COUNT_MAX + 1)


# ----------------------------------------------------------------------
# A Zone is built for the content its Checks are worth
# ----------------------------------------------------------------------

@pytest.mark.parametrize("size", [30, 100, 450, 600])
def test_a_full_zone_gets_the_whole_budget(size):
    config = C.CampaignConfig(location_count=size)
    assert config.zone_budget_for(config.zone_target_checks) \
        == config.zone_budget
    # More than a full Zone's worth cannot ask for more than the budget:
    # the ceiling is what the engine and the provider were sized for.
    assert config.zone_budget_for(config.zone_target_checks + 5) \
        == config.zone_budget


def test_a_remainder_zone_asks_for_a_proportional_budget():
    """449 Checks at 15 per Zone leaves a last Zone holding 14 of them,
    and a campaign at 20 per Zone can leave one holding a single Check.

    A short Zone is a short level, not a broken one -- asking for a
    full-length level around one Check demands content the Zone has no
    reason to contain, and the Zone then fails its own budget band.
    """
    config = C.DEFAULT_CONFIG
    assert config.zone_budget_for(15) == 1000
    assert config.zone_budget_for(12) == 800
    assert config.zone_budget_for(8) == 533
    # ...and never below the floor the whole system is bounded by.
    assert config.zone_budget_for(1) == C.ZONE_BUDGET_MIN
    assert config.zone_budget_for(0) == C.ZONE_BUDGET_MIN


@pytest.mark.parametrize("size", [30, 90, 200, 450, 600])
def test_every_reachable_zone_budget_is_a_legal_one(size):
    """Every Zone a campaign of this size can produce asks for a budget
    the schema, the provider and the engine all accept."""
    config = C.CampaignConfig(location_count=size)
    for allocated in range(0, config.zone_target_checks + 2):
        budget = config.zone_budget_for(allocated)
        assert C.ZONE_BUDGET_MIN <= budget <= C.ZONE_BUDGET_MAX
        assert budget >= allocated * C.MIN_BUDGET_PER_CHECK, (
            f"{allocated} Checks cannot fit in {budget} points")


def test_the_campaign_asks_for_the_budget_the_zone_is_worth(tmp_path):
    """The wiring, not the arithmetic: a Zone request has to CARRY it.

    `zone_budget_for` computing the right number changes nothing if the
    request still asks the provider for the campaign's full budget --
    the provider builds a full-length level around one Check, and the
    Zone fails its band on the way back in.
    """
    from archipepsi_bridge.schemas import protocol as P
    from .conftest import make_engine

    engine = make_engine(tmp_path)
    engine.save = P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        scale=P.CampaignScale(location_count=450, zone_target_checks=15,
                              zone_budget=1000))
    config = engine.save.scale.config()

    def budget_for(allocated: int, *, finale: bool = False) -> int:
        record = P.ZoneRecord(
            zone_id="zone_001", state="PENDING_GENERATION",
            allocated_location_ids=tuple(
                C.FIRST_LOCATION_ID + i for i in range(allocated)),
            target_game="Some Game", is_finale=finale, generation_index=0)
        return engine._zone_request(record).campaign.zone_budget

    assert budget_for(15) == config.zone_budget
    assert budget_for(8) == config.zone_budget_for(8)
    assert budget_for(1) == C.ZONE_BUDGET_MIN
    assert budget_for(1, finale=True) == C.ZONE_BUDGET_MIN


def test_a_prototype_campaign_still_asks_for_a_prototype_zone(tmp_path):
    """A save from before the options is not resized by the new default."""
    from archipepsi_bridge.schemas import protocol as P
    from .conftest import make_engine

    engine = make_engine(tmp_path)
    engine.save = P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah")
    record = P.ZoneRecord(
        zone_id="zone_001", state="PENDING_GENERATION",
        allocated_location_ids=(C.FIRST_LOCATION_ID, C.FIRST_LOCATION_ID + 1,
                                C.FIRST_LOCATION_ID + 2),
        target_game="Some Game", generation_index=0)
    assert (engine._zone_request(record).campaign.zone_budget
            == C.PROTOTYPE_CONFIG.zone_budget)
