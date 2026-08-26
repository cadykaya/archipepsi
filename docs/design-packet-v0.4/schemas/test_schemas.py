"""Archipepsi v0.4 — schema tests.

These are not decoration. Each test pins a rule that v0.3 stated in prose
and could not enforce. Run with `pytest -q` from this directory.
"""

from __future__ import annotations

import pytest
from pydantic import TypeAdapter, ValidationError

import constants as C
from echo import Echo, PrimaryEcho, validate_echo
from zone import Zone, validate_zone

EchoAdapter = TypeAdapter(Echo)


# ---------------------------------------------------------------------------
# Constants: the derived traversal guarantee
# ---------------------------------------------------------------------------

def test_safe_gap_is_derived_from_the_jump_arc():
    """v0.3 B4: the safe gap was 'measured in engine'. Now it is computed."""
    assert C.JUMP_APEX_HEIGHT == pytest.approx(1.333, abs=0.001)
    assert C.JUMP_AIRTIME == pytest.approx(0.667, abs=0.001)
    assert C.JUMP_FLAT_REACH == pytest.approx(4.667, abs=0.001)
    assert C.SAFE_BASE_JUMP_GAP == 3.0
    assert C.MAX_VERTICAL_STEP == 1.0


def test_safe_gap_leaves_real_margin():
    assert C.SAFE_BASE_JUMP_GAP < C.JUMP_FLAT_REACH * 0.7
    assert C.MAX_VERTICAL_STEP < C.JUMP_APEX_HEIGHT


def test_worst_legal_zone_is_not_a_plinkfest():
    """v0.3 F2: 8 enemies per chamber with no damage numbers anywhere."""
    ttk = C.worst_case_zone_ttk()
    assert ttk < C.WORST_CASE_ZONE_TTK_BUDGET
    assert ttk == pytest.approx(25.2, abs=0.5)


def test_a_good_echo_meaningfully_beats_pepsi_pop():
    """DESIGN: 'Epsilon should prefer making Echo weapons much more
    satisfying than Pepsi Pop.' Check that the bounds actually allow it."""
    echo_dps = (12.0 * 3) / 0.8
    assert echo_dps / C.PEPSI_POP_DPS > 2.0


def test_item_pool_matches_location_count():
    assert (
        C.PEPSI_KEY_COUNT + C.EPSILON_COIN_COUNT + C.EPSILON_STATIC_COUNT
        == C.LOCATION_COUNT
    )


def test_goal_location_is_the_last_check():
    assert C.GOAL_LOCATION_ID == 89100030


def test_prng_is_stable_across_processes():
    """v0.3 C8: 'deterministically shuffle' with no defined recipe."""
    a = C.deterministic_shuffle(list(range(10)), "SeedName", 0, 6, "track_order")
    b = C.deterministic_shuffle(list(range(10)), "SeedName", 0, 6, "track_order")
    c = C.deterministic_shuffle(list(range(10)), "SeedName", 0, 7, "track_order")
    assert a == b
    assert a != c
    assert sorted(a) == list(range(10))
    # Pinned so a refactor that changes the shuffle is caught immediately.
    assert C.prng_seed("SeedName", 0, 6, "track_order") == 4540422911836592657


# ---------------------------------------------------------------------------
# Zone
# ---------------------------------------------------------------------------

def _zone(**over):
    base = {
        "schema_version": 4,
        "zone_id": "zone_003",
        "display_name": "Cathedral of Excessive Firepower",
        "target_game": "Dark Souls III",
        "theme": "gothic_castle",
        "chambers": [
            {"id": "c1", "type": "corridor", "length": 12.0, "width": 5.0},
            {
                "id": "c2", "type": "arena", "width": 18.0, "depth": 18.0,
                "wall_height": 6.0, "objective": "kill_all",
                "enemies": [{"archetype": "melee", "count": 3}],
                "reward_location_id": 89100012,
            },
            {
                "id": "c3", "type": "tower", "floors": 3,
                "objective": "reach_reward",
                "enemies": [{"archetype": "ranged", "count": 2}],
                "reward_location_id": 89100013,
            },
        ],
    }
    base.update(over)
    return base


def test_valid_zone_parses():
    z = Zone.model_validate(_zone())
    assert z.reward_location_ids == [89100012, 89100013]


def test_zone_rejects_unknown_chamber_type():
    bad = _zone()
    bad["chambers"][0]["type"] = "lava_maze"
    with pytest.raises(ValidationError):
        Zone.model_validate(bad)


def test_zone_rejects_invented_fields():
    """A hallucinated mechanic must fail loudly, not be silently dropped."""
    bad = _zone()
    bad["chambers"][0]["teleporter_destination"] = "c3"
    with pytest.raises(ValidationError):
        Zone.model_validate(bad)


def test_platform_gap_cannot_exceed_the_derived_safe_jump():
    """The v0.3 traversal guarantee, now enforced by the type."""
    bad = _zone(chambers=[{
        "id": "p1", "type": "platform_path", "segment_count": 4,
        "gap_size": C.SAFE_BASE_JUMP_GAP + 0.5, "vertical_step": 0.5,
        "reward_location_id": 89100012,
    }])
    with pytest.raises(ValidationError):
        Zone.model_validate(bad)


def test_kill_all_requires_enemies():
    bad = _zone()
    bad["chambers"][1]["enemies"] = []
    with pytest.raises(ValidationError):
        Zone.model_validate(bad)


def test_zone_enemy_budget_enforced():
    bad = _zone()
    bad["chambers"][1]["enemies"] = [{"archetype": "melee", "count": 8}]
    bad["chambers"][2]["enemies"] = [{"archetype": "melee", "count": 8}]
    with pytest.raises(ValidationError, match="limit is 14"):
        Zone.model_validate(bad)


def test_one_brute_per_zone():
    bad = _zone()
    bad["chambers"][1]["enemies"] = [{"archetype": "brute", "count": 2}]
    with pytest.raises(ValidationError, match="brutes"):
        Zone.model_validate(bad)


def test_zone_has_no_way_to_express_a_mandatory_echo_gate():
    """v0.3 §54 as a structural property rather than a validation rule."""
    bad = _zone(required_echo_ids=["echo_89100004"])
    with pytest.raises(ValidationError):
        Zone.model_validate(bad)


def test_semantic_validation_accepts_a_matching_zone():
    z = Zone.model_validate(_zone())
    assert validate_zone(
        z, expected_zone_id="zone_003",
        allocated_location_ids=[89100012, 89100013],
        owned_echo_ids=[],
    ) == []


def test_semantic_validation_catches_a_smuggled_location():
    """Epsilon may not add, remove, replace or renumber AP locations."""
    bad = _zone()
    bad["chambers"][2]["reward_location_id"] = 89100030
    z = Zone.model_validate(bad)
    errs = validate_zone(
        z, expected_zone_id="zone_003",
        allocated_location_ids=[89100012, 89100013],
        owned_echo_ids=[],
    )
    assert any("not allocated" in e for e in errs)
    assert any("missing a reward chamber" in e for e in errs)


def test_semantic_validation_catches_unowned_featured_echo():
    z = Zone.model_validate(_zone(featured_echo_ids=["echo_89100004"]))
    errs = validate_zone(
        z, expected_zone_id="zone_003",
        allocated_location_ids=[89100012, 89100013],
        owned_echo_ids=[],
    )
    assert any("must all be owned" in e for e in errs)


def test_semantic_validation_catches_zone_id_mismatch():
    z = Zone.model_validate(_zone())
    errs = validate_zone(
        z, expected_zone_id="zone_004",
        allocated_location_ids=[89100012, 89100013],
        owned_echo_ids=[],
    )
    assert any("zone_id must be exactly" in e for e in errs)


# ---------------------------------------------------------------------------
# Echo
# ---------------------------------------------------------------------------

CONFERENCE_CALL = {
    "schema_version": 4,
    "echo_id": "echo_89100004",
    "source_location_id": 89100004,
    "source_item_name": "Conference Call",
    "source_game": "Borderlands 2",
    "source_recipient_name": "BL2Player",
    "display_name": "Conference Call",
    "description": "A ridiculous shotgun with enough kick to double as movement.",
    "archetype": "weapon",
    "activation": "primary",
    "cooldown": 0.8,
    "effects": [
        {"type": "hitscan_damage", "damage": 8.0, "pellets": 12,
         "spread_degrees": 10.0, "range": 35.0},
        {"type": "recoil_self", "force": 8.0},
        {"type": "knockback_target", "force": 5.0},
    ],
    "tags": ["weapon", "shotgun", "recoil", "mobility"],
}


def test_the_canonical_echo_still_parses():
    """The design's flagship example must survive the stricter v0.4 rules."""
    e = EchoAdapter.validate_python(CONFERENCE_CALL)
    assert isinstance(e, PrimaryEcho)
    assert e.cooldown == 0.8


def test_modifier_alone_is_rejected():
    """v0.3 gap: knockback_target with nothing to knock back was legal."""
    bad = dict(CONFERENCE_CALL, effects=[{"type": "knockback_target", "force": 5.0}])
    with pytest.raises(ValidationError, match="exactly one initiator"):
        EchoAdapter.validate_python(bad)


def test_recoil_on_a_heal_is_rejected():
    """v0.3 gap: recoil_self + heal_self was legal and incoherent."""
    bad = dict(CONFERENCE_CALL, effects=[
        {"type": "heal_self", "amount": 30.0},
        {"type": "recoil_self", "force": 8.0},
    ])
    with pytest.raises(ValidationError, match="requires a damage initiator"):
        EchoAdapter.validate_python(bad)


def test_two_initiators_are_rejected():
    bad = dict(CONFERENCE_CALL, effects=[
        {"type": "dash", "force": 10.0},
        {"type": "heal_self", "amount": 30.0},
    ])
    with pytest.raises(ValidationError, match="exactly one initiator"):
        EchoAdapter.validate_python(bad)


def test_passive_echo_has_no_cooldown_field():
    """v0.3 gap: passives carried a bounded cooldown that never applied."""
    wing_cap = {
        "schema_version": 4,
        "echo_id": "echo_89100003",
        "source_location_id": 89100003,
        "source_item_name": "Wing Cap",
        "source_game": "Super Mario 64",
        "source_recipient_name": "MarioPlayer",
        "display_name": "Wing Cap",
        "description": "The world stops taking your weight quite so seriously.",
        "archetype": "passive",
        "activation": "passive",
        "effects": [{"type": "modify_gravity", "multiplier": 0.55}],
        "tags": ["passive", "gravity"],
    }
    e = EchoAdapter.validate_python(wing_cap)
    assert not hasattr(e, "cooldown")

    with pytest.raises(ValidationError):
        EchoAdapter.validate_python(dict(wing_cap, cooldown=1.0))


def test_passive_echo_cannot_carry_an_attack():
    bad = {
        "schema_version": 4, "echo_id": "echo_89100003",
        "source_location_id": 89100003, "source_item_name": "Wing Cap",
        "source_game": "Super Mario 64", "source_recipient_name": "MarioPlayer",
        "display_name": "Wing Cap", "description": "No.",
        "archetype": "passive", "activation": "passive",
        "effects": [{"type": "hitscan_damage", "damage": 8.0, "pellets": 1,
                     "spread_degrees": 0.0, "range": 20.0}],
    }
    with pytest.raises(ValidationError):
        EchoAdapter.validate_python(bad)


def test_out_of_bounds_numbers_are_rejected_not_clamped():
    bad = dict(CONFERENCE_CALL, effects=[
        {"type": "hitscan_damage", "damage": 9999.0, "pellets": 12,
         "spread_degrees": 10.0, "range": 35.0},
    ])
    with pytest.raises(ValidationError):
        EchoAdapter.validate_python(bad)


def test_unsupported_effect_name_is_rejected():
    """Test F: an invented mechanic must never reach gameplay code."""
    bad = dict(CONFERENCE_CALL, effects=[
        {"type": "summon_black_hole", "radius": 12.0},
    ])
    with pytest.raises(ValidationError):
        EchoAdapter.validate_python(bad)


def test_echo_id_is_derived_from_its_source_location():
    """Echo identity is source-location based; that is the dedupe key."""
    bad = dict(CONFERENCE_CALL, echo_id="echo_89100999")
    with pytest.raises(ValidationError, match="echo_id must be"):
        EchoAdapter.validate_python(bad)


def test_semantic_echo_validation_catches_wrong_source():
    e = EchoAdapter.validate_python(CONFERENCE_CALL)
    assert validate_echo(e, expected_source_location_id=89100004) == []
    assert validate_echo(e, expected_source_location_id=89100011) != []


# ---------------------------------------------------------------------------
# Protocol
# ---------------------------------------------------------------------------

def test_campaign_save_round_trips():
    from protocol import CampaignSave, ZoneRecord

    save = CampaignSave(
        seed_name="ExampleSeed", team=0, slot_id=6, slot_name="Skyiah",
        track_order=["Dark Souls III", "Ocarina of Time"],
        zones={"zone_001": ZoneRecord(
            zone_id="zone_001", state="PENDING_GENERATION",
            allocated_location_ids=[89100001, 89100002, 89100003],
            target_game="Borderlands 2", generation_index=1,
        )},
    )
    again = CampaignSave.model_validate_json(save.model_dump_json())
    assert again.zones["zone_001"].state == "PENDING_GENERATION"
    assert again.zones["zone_001"].zone is None
    assert again.campaign_key == save.campaign_key


def test_pending_generation_zone_holds_its_allocation():
    """v0.3 G13: the crash window between allocate and generate was
    unrepresentable, so the shop could re-sell committed locations."""
    from protocol import ZoneRecord

    rec = ZoneRecord(
        zone_id="zone_004", state="PENDING_GENERATION",
        allocated_location_ids=[89100012, 89100013, 89100014],
        target_game="Ocarina of Time", generation_index=4,
    )
    assert rec.zone is None
    assert 89100013 in rec.allocated_location_ids


def test_client_messages_are_discriminated():
    from pydantic import TypeAdapter
    from protocol import ClaimCheck, ClientMessage

    adapter = TypeAdapter(ClientMessage)
    msg = adapter.validate_python(
        {"type": "claim_check", "zone_id": "zone_003", "location_id": 89100012}
    )
    assert isinstance(msg, ClaimCheck)

    with pytest.raises(ValidationError):
        adapter.validate_python({"type": "definitely_not_a_real_intent"})


def test_finale_and_normal_zone_can_be_offered_together():
    """Found in the v0.4 self-audit: the finale unlocks at 24 of 29, so up to
    5 ordinary Checks remain. A single enum would either hide the finale or
    strand that content."""
    from protocol import HubStatus

    hub = HubStatus(
        mode="ZONE_AVAILABLE", headline="x", portal_enabled=True,
        finale_available=True, finale_progress=26,
    )
    assert hub.mode == "ZONE_AVAILABLE" and hub.finale_available


def test_waiting_for_ap_cannot_coexist_with_an_available_finale():
    from protocol import HubStatus

    with pytest.raises(ValidationError, match="not waiting on Archipelago"):
        HubStatus(
            mode="WAITING_FOR_AP", headline="x", portal_enabled=False,
            finale_available=True,
        )


def test_finale_only_requires_the_finale_to_be_available():
    from protocol import HubStatus

    with pytest.raises(ValidationError, match="FINALE_ONLY"):
        HubStatus(mode="FINALE_ONLY", headline="x", portal_enabled=True)


def test_request_next_zone_carries_the_finale_choice():
    from pydantic import TypeAdapter
    from protocol import ClientMessage, RequestNextZone

    msg = TypeAdapter(ClientMessage).validate_python(
        {"type": "request_next_zone", "finale": True}
    )
    assert isinstance(msg, RequestNextZone) and msg.finale
    default = TypeAdapter(ClientMessage).validate_python({"type": "request_next_zone"})
    assert default.finale is False
