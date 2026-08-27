"""ECHOES.md §16: contextual budgets, and §7's merge-over-duplicate rule.

Every other rule in the contract judges one interpretation in isolation,
which is what lets the model layer enforce it. These cannot be: "is this the
sixteenth resource" is only answerable against the fold. So they run at
grant time, and this is where they are held honest.

The hard resource budget is the same number as the HUD channel count on
purpose. A sixteenth resource would have nowhere to render, and a bar with
no channel is worse than a refusal — it is a mechanic the player owns and
cannot see.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge.schemas.echo import (
    COMPLEXITY_BUDGETS, EchoInterpretation, HUD_CHANNELS, budget_errors,
    over_soft_budget,
)
from archipepsi_bridge.schemas.mechanics import EMPTY_MECHANICS, derive_mechanics

from .conftest import ScriptedProvider, run


def _resource_echo(seq: int, *, ops: int = 1) -> EchoInterpretation:
    # Location ids are bounded to the campaign's 30 Checks, so the probe
    # for "one more" wraps into the range rather than running past it.
    location = 89100001 + (seq % 30)
    return EchoInterpretation.model_validate({
        "schema_version": 8,
        "echo_id": f"echo_{location}",
        "interpretation_seq": seq,
        "source_location_id": location,
        "source_item_name": f"Item {seq}",
        "source_game": "Some Game",
        "source_recipient_name": "Partner",
        "concepts": [], "mode": "literal",
        "display_name": f"Echo {seq}",
        "description": "A resource-bearing interpretation.",
        "tags": [],
        "operations": [{
            "op": "create",
            "component": {
                "kind": "resource",
                "component_id": f"res_{seq}_{n}",
                "display_name": f"MP{seq}{n}",
                "description": "A channel.",
                "max_value": 100.0,
                "initial_fraction": 1.0,
                "regen_per_second": 0.0,
                "regen_delay": 0.0,
                "presentation": "bar",
                "palette_color": "moss",
            },
        } for n in range(ops)],
    })


def _campaign(count: int):
    return derive_mechanics([_resource_echo(i) for i in range(count)])


def test_the_hard_budget_is_the_channel_count():
    """Two numbers that must never drift, so they are one number."""
    assert HUD_CHANNELS == COMPLEXITY_BUDGETS["resource"][1] == 15


def test_a_resource_is_accepted_right_up_to_the_last_channel():
    mechanics = _campaign(HUD_CHANNELS - 1)
    assert budget_errors(_resource_echo(99), mechanics) == []


def test_the_sixteenth_resource_is_refused():
    mechanics = _campaign(HUD_CHANNELS)
    errors = budget_errors(_resource_echo(99), mechanics)
    assert errors and "hard budget" in errors[0], errors
    # The refusal has to say what to do instead, because it is fed straight
    # back into the repair-once loop as the provider's only instruction.
    assert "merge" in errors[0], errors[0]


def test_one_interpretation_creating_several_counts_all_of_them():
    """The budget counts components, not Echoes.

    An interpretation carries up to four operations, so checking "is there
    room for one more" would let a single Echo step over the ceiling.
    """
    mechanics = _campaign(HUD_CHANNELS - 2)
    assert budget_errors(_resource_echo(99, ops=2), mechanics) == []
    assert budget_errors(_resource_echo(99, ops=3), mechanics) != []


def test_an_empty_campaign_budgets_nothing():
    assert budget_errors(_resource_echo(0), EMPTY_MECHANICS) == []


def test_the_soft_budget_steers_before_the_hard_one_refuses():
    soft = COMPLEXITY_BUDGETS["resource"][0]
    assert "resource" not in over_soft_budget(_campaign(soft - 1))
    assert "resource" in over_soft_budget(_campaign(soft))
    # Steering only: still accepted, because the pressure valve is advice
    # until the ceiling.
    assert budget_errors(_resource_echo(99), _campaign(soft)) == []


def test_actions_have_no_hard_ceiling():
    """Only four can be slotted, so the twelfth costs screen space, not
    balance. A hard cap there would refuse a Check for owning too much."""
    assert COMPLEXITY_BUDGETS["action"][1] is None


@pytest.mark.parametrize("count", [0, 1, 7, 15])
def test_channels_are_assigned_in_creation_order(count):
    """Deterministic layout: the same campaign lays out the same dashboard.

    Ordered by `interpretation_seq`, never by name, id or palette — an
    unrelated Echo arriving must not move a bar the player has learned.
    """
    mechanics = _campaign(count)
    assert len(mechanics.resources) == count
    for index, owned in enumerate(mechanics.resources):
        assert mechanics.channel_of(owned.component_id) == index
    assert mechanics.channel_of("res_nonexistent") is None


# --- Invariant I8: a breaching CREATE is rejected and repair steers -------

def _echo_request(item_name="Magic Meter"):
    from archipepsi_bridge.epsilon.requests import (
        EchoGenerationRequest, EchoPlayerState, EchoSource)
    return EchoGenerationRequest(
        source=EchoSource(location_id=89100001, item_name=item_name,
                          source_game="Ocarina of Time",
                          recipient_name="oot_player", item_flags=0),
        player_state=EchoPlayerState(),
        required_echo_id="echo_89100001")


def _sixteenth_resource_echo() -> dict:
    return {
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": 0, "source_location_id": 89100001,
        "source_item_name": "Magic Meter", "source_game": "Ocarina of Time",
        "source_recipient_name": "oot_player",
        # S10: an Echo with no reading is refused (§15), so a
        # scripted provider has to supply one like any other.
        "concepts": ["arcane", "energy", "capacity"],
        "display_name": "One Meter Too Many", "description": "no.",
        "operations": [{"op": "create", "component": {
            "kind": "resource", "component_id": "res_overflow",
            "display_name": "MP", "description": "The 16th.",
            "max_value": 100.0, "initial_fraction": 1.0,
            "presentation": "bar", "palette_color": "moss"}}],
    }


def _plain_action_echo() -> dict:
    return {
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": 0, "source_location_id": 89100001,
        "source_item_name": "Magic Meter", "source_game": "Ocarina of Time",
        "source_recipient_name": "oot_player",
        # S10: an Echo with no reading is refused (§15), so a
        # scripted provider has to supply one like any other.
        "concepts": ["arcane", "energy", "capacity"],
        "display_name": "Meter, Reread", "description": "ok.",
        "operations": [{"op": "create", "component": {
            "kind": "action", "component_id": "act_meter",
            "display_name": "Meter", "description": "ok.",
            "slot": "echo_a", "cooldown": 1.0,
            "primitive": {"type": "hitscan_damage", "damage": 8.0,
                          "pellets": 1, "spread_degrees": 1.0,
                          "range": 30.0}}}],
    }


def test_i8_a_breaching_create_is_rejected_and_repaired():
    """The hard budget refuses; the repair prompt carries the reason; a
    repaired answer that stops breaching is accepted with no fallback."""
    from archipepsi_bridge.epsilon.base import generate_echo_validated

    async def scenario():
        provider = ScriptedProvider(
            echo_outputs=[_sixteenth_resource_echo(), _plain_action_echo()])
        outcome = await generate_echo_validated(
            provider, _echo_request(), mechanics=_campaign(15))
        assert provider.echo_repairs == 1
        assert outcome.used_fallback is False
        assert outcome.value.operations[0].component.kind == "action"
        assert any("hard budget" in e
                   for e in outcome.archive["validation_errors"])
    run(scenario())


def test_i8_the_fallback_steps_aside_at_the_hard_budget():
    """A resource-hinted item at 15/15 resources must not make the fallback
    breach — `_pipeline` treats a refused fallback as a RuntimeError. The
    outcome degrades to the item's budget-free shape instead."""
    from archipepsi_bridge.epsilon.base import generate_echo_validated

    async def scenario():
        provider = ScriptedProvider(
            echo_outputs=[_sixteenth_resource_echo(),
                          _sixteenth_resource_echo()])
        outcome = await generate_echo_validated(
            provider, _echo_request(), mechanics=_campaign(15))
        assert outcome.used_fallback is True
        kinds = [op.component.kind for op in outcome.value.operations]
        assert "resource" not in kinds
    run(scenario())


def test_the_fallback_rule_outcomes_fold_and_pass_stage_support():
    """The flask and the cell are the first fallback outcomes carrying
    rules; each must fold from an empty log (resource created BEFORE the
    rule that names it) and clear the staged gates."""
    from archipepsi_bridge.epsilon import capabilities as CAP
    from archipepsi_bridge.epsilon.fallback import fallback_echo

    for name in ["Estus Shard", "Power Star"]:
        raw = fallback_echo(_echo_request(name))
        echo = EchoInterpretation.model_validate(raw)
        assert CAP.validate_stage_support(echo) == [], name
        mechanics = derive_mechanics([echo])
        kinds = sorted(o.kind for o in mechanics.owned)
        assert "rule" in kinds, name


def test_the_fallback_rule_outcomes_step_aside_at_the_rule_budget():
    from archipepsi_bridge.epsilon.fallback import fallback_echo

    rule_hard = COMPLEXITY_BUDGETS["rule"][1]
    base = _resource_echo(0)
    rules = [EchoInterpretation.model_validate({
        **base.model_dump(exclude={"operations", "interpretation_seq",
                                   "echo_id", "source_location_id"}),
        "interpretation_seq": 1 + i,
        "source_location_id": 89100002 + i,
        "echo_id": f"echo_{89100002 + i}",
        "operations": [{"op": "create", "component": {
            "kind": "rule", "component_id": f"rule_{i}",
            "display_name": "R", "description": "r", "event": "kill",
            "conditions": [], "costs": [],
            "effects": [{"type": "heal", "amount": 1.0}],
            "cooldown": 0.1}}]}) for i in range(rule_hard)]
    full = derive_mechanics([base] + rules)
    degraded = fallback_echo(_echo_request("Power Star"), mechanics=full)
    kinds = [op["component"]["kind"] for op in degraded["operations"]]
    assert "rule" not in kinds


def test_the_request_carries_the_soft_budget_steer_and_it_validates():
    """S5's discharge of the S3 decision: the steer is on the request, and
    a provider that obeys it produces something validation ACCEPTS.

    Before links, "relate instead of duplicating" named only operations
    the capability gate refused, so the advice manufactured repair loops.
    A LINK is implementable now, so the steer is honest."""
    from archipepsi_bridge.epsilon import capabilities as CAP
    from archipepsi_bridge.epsilon.requests import EchoGenerationRequest

    rich = _campaign(COMPLEXITY_BUDGETS["resource"][0])
    steer = over_soft_budget(rich)
    assert "resource" in steer
    request = _echo_request()
    assert isinstance(request.over_soft_budget, tuple)

    obedient = EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": "echo_89100007",
        "interpretation_seq": 6, "source_location_id": 89100007,
        "source_item_name": "Magic Meter", "source_game": "Ocarina of Time",
        "source_recipient_name": "oot_player",
        # S10: an Echo with no reading is refused (§15), so a
        # scripted provider has to supply one like any other.
        "concepts": ["arcane", "energy", "capacity"],
        "display_name": "Related, Not Duplicated",
        "description": "It powers what you already own.",
        "operations": [
            {"op": "create", "component": {
                "kind": "action", "component_id": "act_wand",
                "display_name": "Wand", "description": "Zap.",
                "slot": "echo_a", "cooldown": 1.0,
                "primitive": {"type": "hitscan_damage", "damage": 8.0,
                              "pellets": 1, "spread_degrees": 1.0,
                              "range": 30.0}}},
            {"op": "link", "link": "powers", "source": "res_0_0",
             "target": "act_wand", "strength": 10.0}],
    })
    assert CAP.validate_stage_support(obedient) == []
    assert budget_errors(obedient, rich) == []
    assert len(derive_mechanics(
        [_resource_echo(i) for i in range(COMPLEXITY_BUDGETS["resource"][0])]
        + [obedient]).links) == 1
