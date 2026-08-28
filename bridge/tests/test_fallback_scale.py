"""The fallback is what a player without an API key actually plays.

CAMPAIGN_SCALE.md 11: it is the OFFLINE FIXTURE, so a four-room toy here
means human playtesting never exercises production-scale gameplay no
matter what the Claude provider is capable of. It has to satisfy the same
campaign options, the same allocated Check count, the same zone budget,
the same room-value calculation, the same composition requirements and
the same safety constraints as the real provider.

These tests are the proof of that, and they are written against the
CONFIGURED option space rather than against the default: a campaign at
one Check per Zone and a campaign at thirty are both legal, and the
fallback that only works at fifteen is a fallback that works by accident.
"""

from __future__ import annotations

import json

import pytest
from pydantic import TypeAdapter

from archipepsi_bridge import content_value as V
from archipepsi_bridge.epsilon.fallback import (
    _max_enemy_groups, fallback_zone, fallback_zone_attempt)
from archipepsi_bridge.epsilon.requests import (
    CampaignContext, PlayerContext, RequestLocation, ZoneGenerationRequest)
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import zone as Z

_ZONE = TypeAdapter(Z.Zone)


def _request(checks: int, budget: int, *, index: int = 1,
             finale: bool = False,
             affordances: tuple[str, ...] = ()) -> ZoneGenerationRequest:
    locations = tuple(
        RequestLocation(
            location_id=C.FIRST_LOCATION_ID + i,
            location_name=f"Archipepsi Check {i:03d}",
            item_name="Some Item", recipient_name="Player",
            recipient_game="Some Game", item_flags=0)
        for i in range(checks))
    return ZoneGenerationRequest(
        zone_id=f"zone_{index:03d}", generation_id=f"gen-{index}",
        campaign=CampaignContext(
            seed_name="seed", slot_name="Player", team=0, slot_id=1,
            zone_index=index, target_game="Some Game", is_finale=finale,
            static_glitch_units=0, zone_budget=budget),
        player=PlayerContext(signal_keys=0, coins_available=0),
        locations=locations, unlocked_affordances=affordances)


def _zone(request: ZoneGenerationRequest) -> Z.Zone:
    return _ZONE.validate_python(fallback_zone(request))


def _errors(request: ZoneGenerationRequest, zone: Z.Zone) -> list[str]:
    return Z.validate_zone(
        zone, expected_zone_id=request.zone_id,
        allocated_location_ids=[loc.location_id
                                for loc in request.locations],
        owned_echo_ids=[],
        owned_affordance_tags=request.unlocked_affordances,
        zone_budget=request.campaign.zone_budget)


#: The corners of the option space plus the interior, rather than the
#: default alone. `zone_budget_for` produces the odd-looking budgets: a
#: Zone holding fewer Checks than the campaign targets is asked for a
#: proportionally smaller one.
SHAPES = [
    (1, C.ZONE_BUDGET_MIN),                    # a remainder Zone
    (2, C.ZONE_BUDGET_MIN),
    (3, C.ZONE_BUDGET_MIN),                    # the prototype
    (5, 400),
    (8, 533),
    (10, 600),
    (C.DEFAULT_ZONE_TARGET_CHECKS, C.DEFAULT_ZONE_BUDGET),   # the default
    (20, 1500),
    (C.ZONE_TARGET_CHECKS_MAX, C.ZONE_BUDGET_MAX),           # the ceiling
    (1, C.ZONE_BUDGET_MAX),                    # one Check, a huge budget
    #: A campaign configured at one or two Checks per Zone with a real
    #: budget. Not exotic -- `zone_target_checks` goes down to 1 -- and
    #: the shape where the fallback has to buy the most content with the
    #: fewest Checks, which is where its caps get tested hardest.
    (1, 400),
    (1, 700),
    (2, 700),
]


class TestTheFallbackIsARealLevel:
    """The rules, at every shape a campaign can ask for."""

    @pytest.mark.parametrize("checks,budget", SHAPES)
    @pytest.mark.parametrize("index", [1, 2, 7, 31])
    def test_it_satisfies_every_rule_the_provider_must(
            self, checks, budget, index):
        request = _request(checks, budget, index=index)
        assert _errors(request, _zone(request)) == []

    @pytest.mark.parametrize("checks,budget", SHAPES)
    def test_every_allocated_check_is_placed_exactly_once(
            self, checks, budget):
        request = _request(checks, budget)
        placed = [rid for chamber in _zone(request).chambers
                  for rid in chamber.reward_ids]
        assert sorted(placed) == sorted(loc.location_id
                                        for loc in request.locations)

    @pytest.mark.parametrize("checks,budget", SHAPES)
    def test_it_lands_inside_the_budget_band(self, checks, budget):
        low, high = V.budget_band(budget)
        assert low <= V.zone_value(_zone(_request(checks, budget))) <= high

    def test_the_finale_is_a_level_and_not_a_corridor_with_a_boss(self):
        """The last Zone of a twenty-hour campaign is still a Zone.

        It holds one Check -- the goal -- so it is SHORT, but a campaign
        that ends in two rooms after thirty real Zones ends badly, and a
        Zone that misses the budget it was built for fails validation.
        """
        request = _request(1, C.ZONE_BUDGET_MIN, index=31, finale=True)
        zone = _zone(request)
        assert _errors(request, zone) == []
        low, _ = V.budget_band(C.ZONE_BUDGET_MIN)
        assert V.zone_value(zone) >= low
        assert len(zone.chambers) > 2


class TestBudgetBuysRoomsNotJustDensity:
    """CAMPAIGN_SCALE.md 5: Checks do not count as content."""

    @pytest.mark.parametrize("budget", [200, 600, 1000, 2000])
    def test_room_count_follows_the_budget_not_the_check_count(self, budget):
        """One Check and a big budget is a long level, not one big room."""
        low, high = C.zone_room_envelope(budget)
        rooms = len(_zone(_request(1, budget)).chambers)
        assert low <= rooms <= min(high, C.ZONE_MAX_CHAMBERS)

    def test_a_bigger_budget_buys_a_bigger_zone_at_the_same_checks(self):
        """The lever the owner exposed actually moves the level."""
        sizes = [len(_zone(_request(3, b)).chambers)
                 for b in (200, 600, 1200, 2000)]
        assert sizes == sorted(sizes)
        assert sizes[-1] > sizes[0] * 2

    def test_content_rooms_exist_that_hold_no_check(self):
        zone = _zone(_request(1, 1000))
        assert sum(1 for c in zone.chambers if not c.reward_ids) > 5


class TestDeterministicButNotIdentical:
    """Both halves matter: the prototype was deterministic AND identical."""

    @pytest.mark.parametrize("checks,budget", SHAPES)
    def test_the_same_request_replays_exactly(self, checks, budget):
        request = _request(checks, budget, index=4)
        assert fallback_zone(request) == fallback_zone(request)

    def test_consecutive_zones_are_not_the_same_room_list(self):
        """Four Zones in a row that play identically is the bug the owner
        reported: "the levels are the same? i went through 4"."""
        shapes = []
        for index in range(1, 9):
            zone = _zone(_request(C.DEFAULT_ZONE_TARGET_CHECKS,
                                  C.DEFAULT_ZONE_BUDGET, index=index))
            shapes.append(tuple((c.type, round(V.room_value(c) / 10))
                                for c in zone.chambers))
        assert len(set(shapes)) == len(shapes)

    def test_zones_differ_in_size_not_only_in_dressing(self):
        counts = {len(_zone(_request(C.DEFAULT_ZONE_TARGET_CHECKS,
                                     C.DEFAULT_ZONE_BUDGET,
                                     index=i)).chambers)
                  for i in range(1, 13)}
        assert len(counts) > 1


class TestSafetyHoldsAtEveryScale:
    """The caps are the reason a 2000-point Zone is playable at all."""

    @pytest.mark.parametrize("checks,budget", SHAPES)
    def test_enemy_and_brute_ceilings(self, checks, budget):
        zone = _zone(_request(checks, budget))
        total = sum(c.enemy_total for c in zone.chambers)
        brutes = sum(g.count for c in zone.chambers
                     for g in getattr(c, "enemies", ())
                     if g.archetype == "brute")
        assert total <= C.max_enemies_per_zone(budget)
        assert brutes <= C.max_brutes_per_zone(budget)
        assert total <= C.MAX_ENEMIES_SPAWNED_CAP

    @pytest.mark.parametrize("checks,budget", SHAPES)
    def test_no_chamber_exceeds_the_per_chamber_ceiling(self, checks, budget):
        for chamber in _zone(_request(checks, budget)).chambers:
            assert chamber.enemy_total <= C.MAX_ENEMIES_PER_CHAMBER

    @pytest.mark.parametrize("checks,budget", SHAPES)
    def test_the_movement_floor_is_never_violated(self, checks, budget):
        """I3: a gap the base kit cannot clear is an unwinnable Zone."""
        for chamber in _zone(_request(checks, budget)).chambers:
            gap = getattr(chamber, "gap_size", None)
            if gap is None:
                continue
            step = getattr(chamber, "vertical_step", 0.0)
            assert gap <= C.max_safe_gap(step)

    def test_it_places_no_affordance_the_campaign_cannot_use(self):
        """I12, and the reason the owner saw a pointless bounce pad."""
        zone = _zone(_request(C.DEFAULT_ZONE_TARGET_CHECKS,
                              C.DEFAULT_ZONE_BUDGET, index=3))
        tags = {f.affordance_tag for c in zone.chambers
                for f in c.features if f.affordance_tag}
        assert tags == set()

    def test_it_uses_the_affordances_the_campaign_does_have(self):
        request = _request(C.DEFAULT_ZONE_TARGET_CHECKS,
                           C.DEFAULT_ZONE_BUDGET, index=3,
                           affordances=("rail_grind",))
        zone = _zone(request)
        tags = {f.affordance_tag for c in zone.chambers
                for f in c.features if f.affordance_tag}
        assert tags <= {"rail_grind"}
        assert _errors(request, zone) == []


class TestOutputSize:
    """CAMPAIGN_SCALE.md 12: measure it, do not assume it fits.

    A 1000-point Zone is the thing a real provider has to emit in one
    response, and a limit discovered in production is a limit discovered
    by a player whose portal never opened.
    """

    @pytest.mark.parametrize("checks,budget", SHAPES)
    def test_a_zone_serialises_to_a_size_a_provider_can_emit(
            self, checks, budget):
        payload = json.dumps(fallback_zone(_request(checks, budget)))
        #: Roughly 4 characters per token. A Claude response has room for
        #: far more than this; the number is here so that a change which
        #: makes Zones an order of magnitude larger fails a test rather
        #: than a live generation.
        assert len(payload) < 120_000, (
            f"{checks} Checks at {budget} serialises to {len(payload)} "
            "characters")

    def test_the_biggest_legal_zone_is_measured_and_recorded(self):
        payload = json.dumps(fallback_zone(
            _request(C.ZONE_TARGET_CHECKS_MAX, C.ZONE_BUDGET_MAX)))
        #: Recorded so the number is visible rather than folded into a
        #: bound: the largest Zone anyone can configure.
        assert 4_000 < len(payload) < 120_000


class TestItGetsItRightRatherThanEventually:
    """The retry loop is a net, not the mechanism.

    `fallback_zone` rerolls a salted seed up to eight times and keeps the
    first Zone that validates, which by construction hides builder bugs:
    a wrong enemy count on the first attempt is invisible once the third
    one passes. So these tests read the salt. A builder that needs the
    net has eight tries before a player's portal stops opening, and
    nobody would find out until it did.
    """

    @pytest.mark.parametrize("checks,budget", SHAPES)
    @pytest.mark.parametrize("index", [1, 2, 7, 31])
    def test_the_first_attempt_already_satisfies_the_rules(
            self, checks, budget, index):
        request = _request(checks, budget, index=index)
        _, salt = fallback_zone_attempt(request)
        assert salt == 0, (
            f"{checks} Checks at {budget} needed {salt} reroll(s); the "
            "builder is relying on the retry loop")


class TestTheSchemaIsTheSourceOfTheLimits:
    """A limit retyped into the generator is a limit that drifts."""

    @pytest.mark.parametrize("chamber_type,limit", [
        ("corridor", 4), ("arena", 4), ("platform_path", 2),
        ("tower", 4), ("treasure_room", 0)])
    def test_group_limits_are_read_off_the_chamber_models(
            self, chamber_type, limit):
        assert _max_enemy_groups(chamber_type) == limit

    def test_it_agrees_with_the_schema_for_every_chamber_type(self):
        for model in Z.Chamber.__origin__.__args__:
            name = model.model_fields["type"].annotation.__args__[0]
            field = model.model_fields.get("enemies")
            expected = 0
            if field is not None:
                expected = max(
                    (getattr(m, "max_length", 0) for m in field.metadata),
                    default=0)
            assert _max_enemy_groups(name) == expected

    def test_the_group_guard_is_currently_unreachable_and_says_so(self):
        """Honest bookkeeping, not a passing test dressed as a proof.

        `grow` refuses to add a group past the chamber type's own limit.
        That guard fired before the soft per-room cap existed -- a
        one-Check Zone at 700 points used to pile four groups into a
        platform path, which takes two. The soft cap now keeps ordinary
        rooms well below that, so the guard no longer fires at any
        reachable shape and sabotaging it does not fail a test.

        It stays because it is the schema's bound and costs nothing, and
        this test records that it is defence in depth rather than
        pretending it is load bearing.
        """
        worst = 0
        for checks, budget in SHAPES:
            for index in (1, 2, 7):
                for chamber in _zone(
                        _request(checks, budget, index=index)).chambers:
                    if chamber.type == "platform_path":
                        worst = max(worst, len(chamber.enemies))
        assert worst < _max_enemy_groups("platform_path")
