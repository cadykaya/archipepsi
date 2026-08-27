"""S1.1 regressions found by post-S1 repository review.

Authored by ChatGPT (GPT-5.6 Sol, OpenAI) alongside the S1.1 review patch.
"""

from __future__ import annotations

from types import SimpleNamespace

import asyncio

from archipepsi_bridge import transactions as TX
from archipepsi_bridge.epsilon import capabilities as CAP
from archipepsi_bridge.epsilon.fallback import fallback_echo
from archipepsi_bridge.epsilon.requests import (
    EchoGenerationRequest, EchoPlayerState, EchoSource,
)
from archipepsi_bridge.schemas.echo import EchoInterpretation
from archipepsi_bridge.schemas.migration import (
    component_id_for, migrate_v7_to_v8,
)
from archipepsi_bridge.schemas.protocol import CampaignSave, PendingCheck


LOC_A = 89100001
LOC_B = 89100002
MOBILITY_LOC = 89100020


def _request(location_id: int = LOC_A, item_name: str = "Hookshot"):
    return EchoGenerationRequest(
        source=EchoSource(
            location_id=location_id,
            item_name=item_name,
            source_game="Ocarina of Time",
            recipient_name="Partner",
            item_flags=0,
        ),
        player_state=EchoPlayerState(),
        required_echo_id=f"echo_{location_id}",
    )


def _interpretation_with(component: dict) -> EchoInterpretation:
    return EchoInterpretation.model_validate({
        "schema_version": 8,
        "echo_id": f"echo_{LOC_A}",
        "interpretation_seq": 0,
        "source_location_id": LOC_A,
        "source_item_name": "Test Item",
        "source_game": "Test Game",
        "source_recipient_name": "Partner",
        "concepts": [],
        "mode": "literal",
        "display_name": "Test Echo",
        "description": "Regression fixture.",
        "tags": [],
        "operations": [{"op": "create", "component": component}],
    })


def test_the_request_advertises_only_mechanics_the_runtime_can_execute():
    """The prompt and the validator must read the same registry.

    Written against `capabilities` rather than against a hardcoded list on
    purpose. The literal version had to be edited every time a stage landed,
    and a test you edit to make it pass is a test that eventually gets
    edited into agreeing with a bug. What matters is not which kinds are
    allowed today but that the request never advertises something
    validation would then refuse.
    """
    allowed = _request().allowed
    assert allowed["operations"] == list(CAP.IMPLEMENTED_OPERATION_KINDS)
    assert allowed["component_kinds"] == list(CAP.IMPLEMENTED_COMPONENT_KINDS)
    assert allowed["slots"] == list(CAP.IMPLEMENTED_ACTION_SLOTS)
    assert allowed["modifiers"] == list(CAP.IMPLEMENTED_MODIFIER_TYPES)
    assert allowed["trait_stats"] == list(CAP.IMPLEMENTED_TRAIT_STATS)
    # ...and the registry is a real subset of the contract, not a copy of
    # it, or the assertions above would hold vacuously once it stopped
    # gating anything.
    from archipepsi_bridge.schemas import echo as E
    assert set(CAP.IMPLEMENTED_COMPONENT_KINDS) < set(E.COMPONENT_KINDS)
    assert set(CAP.IMPLEMENTED_ACTION_SLOTS) < set(E.SLOT_NAMES)


def test_s1_stage_gate_rejects_schema_valid_noops():
    # S3 landed the fifteen HUD channels, so a Resource is no longer a
    # definition nothing reads and the gate S1.1 put on it is retired.
    # Asserting it is ACCEPTED is what stops it being reintroduced.
    resource = _interpretation_with({
        "kind": "resource",
        "component_id": "res_test",
        "display_name": "MP",
        "description": "A channel the HUD can actually draw.",
        "max_value": 100,
        "initial_fraction": 1.0,
        "regen_per_second": 0.0,
        "regen_delay": 0.0,
        "presentation": "bar",
        "palette_color": "moss",
    })
    assert CAP.validate_stage_support(resource) == []

    # S4 landed the rule interpreter, so a Rule the runtime can dispatch is
    # accepted now — and the gate moved INSIDE the rule: the S5/S9
    # vocabulary (statuses, trait pulses, local rewards) is still refused
    # per piece rather than per kind. Both directions asserted, so neither
    # the retired gate nor the remaining one can silently drift.
    rule = _interpretation_with({
        "kind": "rule",
        "component_id": "rule_test",
        "display_name": "On Kill",
        "description": "The S4 interpreter dispatches this.",
        "event": "kill",
        "conditions": [],
        "costs": [],
        "effects": [{"type": "heal", "amount": 5.0}],
        "cooldown": 1.0,
    })
    assert CAP.validate_stage_support(rule) == []

    # S5 landed statuses, so that gate is retired too — asserting the
    # ACCEPTANCE is what stops it being reintroduced — and the boundary
    # moved on to affordances, which are S9.
    status = _interpretation_with({
        "kind": "status",
        "component_id": "status_test",
        "display_name": "Burning",
        "description": "The S5 containers apply and tick this.",
        "status": "burning",
        "target": "enemy",
        "duration": 3.0,
        "magnitude": 0.5,
    })
    assert CAP.validate_stage_support(status) == []

    affordance = _interpretation_with({
        "kind": "affordance",
        "component_id": "aff_test",
        "display_name": "Water",
        "description": "Nothing generates or reads an affordance tag until "
                       "the S9 capability registry exists.",
        "tag": "water_volume",
    })
    assert any("component kind 'affordance'" in error
               for error in CAP.validate_stage_support(affordance))

    # S2 landed the bouncing, gravity-affected projectile, so the gate S1.1
    # put on `bounces` is retired rather than kept as a check that no longer
    # describes the engine. Asserting it is now ACCEPTED is what stops the
    # gate from being silently reintroduced.
    bouncy = _interpretation_with({
        "kind": "action",
        "component_id": "act_test",
        "display_name": "Bouncy Shot",
        "description": "The S2 projectile runner bounces and falls.",
        "slot": "echo_a",
        "cooldown": 1.0,
        "primitive": {
            "type": "projectile_damage",
            "damage": 10,
            "speed": 18,
            "lifetime": 3,
            "gravity_scale": 0.5,
            "bounces": 1,
        },
        "modifiers": [],
    })
    assert CAP.validate_stage_support(bouncy) == []

    # The slot gate is the one that has NOT moved: four-slot binding is S7,
    # and until then an Action on `mobility` is owned and unreachable.
    misslotted = _interpretation_with({
        "kind": "action",
        "component_id": "act_slot",
        "display_name": "Unreachable Dash",
        "description": "No key is wired to this slot until S7.",
        "slot": "mobility",
        "cooldown": 1.0,
        "primitive": {"type": "dash", "force": 12.0},
        "modifiers": [],
    })
    assert any("slot 'mobility'" in error
               for error in CAP.validate_stage_support(misslotted))

    # And a verb whose supporting system is still ahead stays refused, so
    # this test still proves the primitive gate fires at all.
    gated = _interpretation_with({
        "kind": "action",
        "component_id": "act_gated",
        "display_name": "Magnet",
        "description": "Local rewards are S9.",
        "slot": "echo_a",
        "cooldown": 1.0,
        "primitive": {"type": "pull_pickup", "radius": 5.0},
        "modifiers": [],
    })
    from archipepsi_bridge.schemas.echo import validate_interpretation
    assert any("not yet implemented" in error for error in
               validate_interpretation(gated, expected_source_location_id=LOC_A))


def test_v7_equipped_mobility_echo_stays_on_the_existing_rmb_control():
    old_echo = {
        "schema_version": 7,
        "echo_id": f"echo_{MOBILITY_LOC}",
        "source_location_id": MOBILITY_LOC,
        "source_item_name": "Hookshot",
        "source_game": "Ocarina of Time",
        "source_recipient_name": "Partner",
        "display_name": "Hookshot",
        "description": "Latch onto geometry.",
        "tags": ["grapple", "mobility"],
        "activation": "primary",
        "archetype": "mobility",
        "cooldown": 2.0,
        "initiator": {
            "type": "grapple_to_surface", "range": 20.0,
            "pull_force": 14.0,
        },
        "modifiers": [],
    }
    raw = {
        "schema_version": 7,
        "seed_name": "MigrationMobility",
        "slot_name": "Player",
        "slot_id": 1,
        "team": 0,
        "echoes": [old_echo],
        "equipped_echo_id": old_echo["echo_id"],
    }
    save = CampaignSave.model_validate(migrate_v7_to_v8(raw))
    action_id = component_id_for("act", MOBILITY_LOC)
    assert save.slots.echo_a == action_id
    assert save.slots.mobility is None
    assert save.derive().by_id(action_id).component.slot == "echo_a"

    # The deterministic S1 fallback follows the same compatibility rule, so
    # a newly generated Hookshot is usable instead of landing in an unwired
    # Shift slot before S2 exists.
    generated = fallback_echo(_request(MOBILITY_LOC, "Hookshot"))
    assert generated["operations"][0]["component"]["slot"] == "echo_a"


def test_reconcile_assigns_batch_order_by_location_id(monkeypatch):
    # Stored claim order is deliberately backwards. Both become checked in
    # the same reconciliation pass; the packet says grant/sequence assignment
    # within that batch is location-id ascending.
    save = CampaignSave(
        seed_name="BatchOrder", team=0, slot_id=1, slot_name="Player",
        coins_spent=2,
        pending_checks=(
            PendingCheck(transaction_id="tx_b", location_id=LOC_B,
                         source="shop", shop_cost=1),
            PendingCheck(transaction_id="tx_a", location_id=LOC_A,
                         source="shop", shop_cost=1),
        ),
    )
    order: list[int] = []

    async def fake_finalize(_engine, location_id: int):
        order.append(location_id)

    class FakeEngine:
        def __init__(self):
            self.save = save
            self.ap = SimpleNamespace(
                connected=True, synced=True,
                checked={LOC_A, LOC_B}, missing=set(),
            )
            self.backend = None

        async def echo_backlog_sweep(self):
            return None

        def release_stock_before_waiting(self):
            return None

    monkeypatch.setattr(TX, "finalize", fake_finalize)
    monkeypatch.setattr(TX, "zone_completion_sweep", lambda _engine: None)
    asyncio.run(TX.reconcile(FakeEngine()))
    assert order == [LOC_A, LOC_B]
