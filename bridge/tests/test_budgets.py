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
