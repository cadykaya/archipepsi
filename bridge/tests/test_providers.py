"""Provider pipeline tests 13–15 (ACCEPTANCE_TESTS §2)."""

from __future__ import annotations

from archipepsi_bridge.epsilon import (
    CampaignContext, PlayerContext, RequestLocation, ZoneGenerationRequest,
    fallback_echo, fallback_zone,
    generate_echo_validated, generate_zone_validated,
)
from archipepsi_bridge.epsilon.requests import (
    EchoGenerationRequest, EchoPlayerState, EchoSource,
)
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.echo import Echo
from archipepsi_bridge.schemas.zone import Zone, validate_zone
from pydantic import TypeAdapter

from .conftest import ScriptedProvider, run


def zone_request(location_ids=(89100001, 89100002)) -> ZoneGenerationRequest:
    return ZoneGenerationRequest(
        zone_id="zone_001", generation_id="Seed-0-1-zone_001",
        campaign=CampaignContext(
            seed_name="Seed", slot_name="Skyiah", team=0, slot_id=1,
            zone_index=1, target_game="Borderlands 2", is_finale=False,
            static_glitch_units=0),
        player=PlayerContext(signal_keys=0, coins_available=0),
        locations=tuple(
            RequestLocation(location_id=loc,
                            location_name=f"Archipepsi Check {loc % 100:03d}",
                            item_name="Conference Call",
                            recipient_name="BL2Player",
                            recipient_game="Borderlands 2", item_flags=1)
            for loc in location_ids))


def echo_request() -> EchoGenerationRequest:
    return EchoGenerationRequest(
        source=EchoSource(location_id=89100001, item_name="Conference Call",
                          source_game="Borderlands 2",
                          recipient_name="BL2Player", item_flags=1),
        player_state=EchoPlayerState(),
        required_echo_id="echo_89100001")


def test_13_invalid_model_json_falls_back():
    async def scenario():
        provider = ScriptedProvider(
            zone_outputs=[{"complete": "garbage"}, ["still", "garbage"]])
        outcome = await generate_zone_validated(
            provider, zone_request(),
            allocated_location_ids=[89100001, 89100002], owned_echo_ids=[])
        assert outcome.used_fallback is True
        assert provider.zone_repairs == 1
        errors = validate_zone(
            outcome.value, expected_zone_id="zone_001",
            allocated_location_ids=[89100001, 89100002], owned_echo_ids=[])
        assert errors == []
    run(scenario())


def test_14_unsupported_echo_effect_one_repair_then_fallback():
    async def scenario():
        bad_echo = {
            "schema_version": 7, "echo_id": "echo_89100001",
            "source_location_id": 89100001,
            "source_item_name": "Conference Call",
            "source_game": "Borderlands 2",
            "source_recipient_name": "BL2Player",
            "display_name": "Dragonmaster", "description": "no.",
            "activation": "primary", "archetype": "weapon", "cooldown": 1.0,
            "initiator": {"type": "summon_dragon", "dragons": 7},
        }
        provider = ScriptedProvider(zone_outputs=[],
                                    echo_outputs=[bad_echo, bad_echo])
        outcome = await generate_echo_validated(provider, echo_request())
        assert outcome.used_fallback is True
        assert provider.echo_repairs == 1          # exactly one repair
        assert provider.echo_calls == 2
        # The unsupported mechanic never reaches gameplay: the accepted
        # object is a validated Echo with a real initiator.
        assert outcome.value.initiator.type != "summon_dragon"
    run(scenario())


def test_15_timeout_falls_back_without_repair():
    async def scenario():
        provider = ScriptedProvider(zone_outputs=[{"x": 1}], delay=5.0)
        outcome = await generate_zone_validated(
            provider, zone_request(),
            allocated_location_ids=[89100001, 89100002], owned_echo_ids=[],
            timeout=0.05)
        assert outcome.used_fallback is True
        assert provider.zone_repairs == 0          # repair skipped on timeout
    run(scenario())


# -- fallback generators are themselves always valid -----------------------

def test_fallback_zone_valid_for_all_check_counts():
    zone_adapter = TypeAdapter(Zone)
    for ids in ([89100001], [89100001, 89100002],
                [89100001, 89100002, 89100003]):
        raw = fallback_zone(zone_request(tuple(ids)))
        zone = zone_adapter.validate_python(raw)
        assert validate_zone(zone, expected_zone_id="zone_001",
                             allocated_location_ids=list(ids),
                             owned_echo_ids=[]) == []


def test_mock_provider_zones_are_varied_and_always_valid():
    """Mock Epsilon designs real shapes. Every one must still satisfy the
    same validators as live model output, at every Check count, for many
    seeds — and the set must actually vary."""
    from archipepsi_bridge.epsilon import MockEpsilonProvider

    async def scenario():
        provider = MockEpsilonProvider()
        adapter = TypeAdapter(Zone)
        shapes_seen: set[str] = set()
        names_seen: set[str] = set()
        for seed_index in range(30):
            for count in (1, 2, 3):
                ids = [89100001 + i for i in range(count)]
                request = zone_request(tuple(ids))
                request = request.model_copy(update={
                    "zone_id": f"zone_{seed_index:03d}"})
                raw = await provider.generate_zone(request)
                zone = adapter.validate_python(raw)
                assert validate_zone(
                    zone, expected_zone_id=request.zone_id,
                    allocated_location_ids=ids, owned_echo_ids=[]) == []
                shapes_seen.add("|".join(c.type for c in zone.chambers))
                names_seen.add(zone.display_name)
        assert len(shapes_seen) > 10, (
            f"mock zones barely vary: {len(shapes_seen)} distinct shapes")
        assert len(names_seen) > 10
    run(scenario())


def test_mock_finale_keeps_the_reserved_shape():
    from archipepsi_bridge.epsilon import MockEpsilonProvider

    async def scenario():
        request = zone_request((C.GOAL_LOCATION_ID,))
        request = request.model_copy(update={
            "campaign": request.campaign.model_copy(
                update={"is_finale": True})})
        raw = await MockEpsilonProvider().generate_zone(request)
        zone = TypeAdapter(Zone).validate_python(raw)
        assert zone.reward_location_ids == [C.GOAL_LOCATION_ID]
        assert validate_zone(
            zone, expected_zone_id=request.zone_id,
            allocated_location_ids=[C.GOAL_LOCATION_ID],
            owned_echo_ids=[]) == []
    run(scenario())


def test_fallback_echo_heuristics_all_valid():
    echo_adapter = TypeAdapter(Echo)
    names = ["Conference Call", "Master Sword", "Hookshot", "Jet Boots",
             "Wing Cap", "Hylian Shield", "Estus Flask", "Bomb Bag",
             "Progressive Glove", "REP", "Mystery Trinket 9000"]
    for name in names:
        req = EchoGenerationRequest(
            source=EchoSource(location_id=89100005, item_name=name,
                              source_game="Test Game",
                              recipient_name="Someone", item_flags=0),
            player_state=EchoPlayerState(),
            required_echo_id="echo_89100005")
        echo = echo_adapter.validate_python(fallback_echo(req))
        assert echo.echo_id == "echo_89100005"
