"""The advertised upgrade headroom has to be true.

A field bound is not the whole rule. `TraitComponent.multiplier` is
`ge=0.1, le=4.0`, but `_traversal_stats_may_only_help` refuses a gravity
trait above 1.0. A provider told "0.1 to 4.0" for a gravity trait at 0.9 is
being told it may raise by 0.15 — and the fold then refuses the upgrade it
was invited to make.

That was not hypothetical. The deterministic fallback took the advertised
range at face value, `_as_sequel` emitted `multiplier +0.15`, and every
validator in the generation pipeline passed it: none of them range-checked
the RESULT. It failed inside `append_interpretation`, where a `FoldError`
is a crash rather than a recoverable rejection — and it failed
deterministically, so the Check could never be granted and reconciliation
aborted every single time.

Two fixes, and this file holds both to account:

* `upgradable_field_info` probes the model instead of reading the field
  bound, so what a provider is told it may do is what it may do.
* `target_errors` checks where an upgrade LANDS, so a provider that gets
  it wrong anyway gets a repair prompt rather than crashing the save.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge.epsilon.fallback import fallback_echo
from archipepsi_bridge.epsilon.requests import (
    EchoGenerationRequest, EchoPlayerState, EchoSource, OwnedComponentSummary)
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.echo import (
    EchoInterpretation, UPGRADABLE_FIELDS, target_errors,
    upgradable_field_info)
from archipepsi_bridge.schemas.protocol import CampaignSave

#: One of every component kind that declares an upgradable field, with a
#: value chosen to sit near whatever extra rule applies to it.
CASES = {
    "gravity trait": {
        "kind": "trait", "component_id": "trait_float", "display_name": "F",
        "description": "d", "stat": "gravity", "multiplier": 0.9},
    "speed trait": {
        "kind": "trait", "component_id": "trait_fast", "display_name": "F",
        "description": "d", "stat": "move_speed", "multiplier": 1.2},
    "damage trait": {
        "kind": "trait", "component_id": "trait_hurt", "display_name": "H",
        "description": "d", "stat": "damage_dealt", "multiplier": 1.5},
    "resource": {
        "kind": "resource", "component_id": "res_mp", "display_name": "MP",
        "description": "d", "max_value": 100.0, "initial_fraction": 1.0,
        "presentation": "bar", "palette_color": "moss"},
    "action": {
        "kind": "action", "component_id": "act_gun", "display_name": "G",
        "description": "d", "slot": "echo_a", "cooldown": 1.0,
        "primitive": {"type": "hitscan_damage", "damage": 8.0, "pellets": 1,
                      "spread_degrees": 1.0, "range": 30.0},
        "modifiers": []},
}


def _component(spec: dict):
    from pydantic import TypeAdapter

    from archipepsi_bridge.schemas.echo import Component
    return TypeAdapter(Component).validate_python(spec)


@pytest.mark.parametrize("name", sorted(CASES))
def test_both_ends_of_the_advertised_range_are_actually_reachable(name):
    """The whole contract in one assertion: a provider that takes the
    request at its word must not be refused."""
    component = _component(CASES[name])
    info = upgradable_field_info(component)
    assert info, name
    for field, current, low, high in info:
        assert low <= current <= high, (name, field, low, current, high)
        assert M.upgrade_is_legal(component, field, high - current), (
            f"{name}: advertised ceiling {high} for '{field}' is not legal")
        assert M.upgrade_is_legal(component, field, low - current), (
            f"{name}: advertised floor {low} for '{field}' is not legal")


def test_a_traversal_cap_narrows_what_is_advertised():
    """The specific case that broke. The field says 4.0; the model says
    1.0; the request must say the model's answer."""
    trait = _component(CASES["gravity trait"])
    field, current, _low, high = upgradable_field_info(trait)[0]
    assert field == "multiplier"
    assert high < 1.01, (
        f"gravity is capped at 1.0 by the model but advertised up to {high}")
    # ...and the cap is specific to gravity: a stat with no extra rule
    # keeps its full field range, so this is a narrowing rather than a
    # blanket tightening that would quietly shrink every upgrade.
    speed = _component(CASES["speed trait"])
    assert upgradable_field_info(speed)[0][3] == 4.0


def test_a_resource_max_value_is_advertised_at_all():
    """`max_value` is `gt=0`, not `ge=0`, and the first version of this
    function only read `ge`/`le` — so the most obvious resource upgrade in
    the game was invisible to every provider."""
    resource = _component(CASES["resource"])
    fields = {f for f, _c, _l, _h in upgradable_field_info(resource)}
    assert "max_value" in fields
    assert fields <= set(UPGRADABLE_FIELDS["resource"])


def test_an_upgrade_that_lands_out_of_range_is_refused_at_generation():
    """Where it can still become a repair prompt, rather than at fold
    where it is a crash."""
    trait = _component(CASES["gravity trait"])
    live = M.derive_mechanics([_interpretation_creating(trait)])
    illegal = _interpretation_upgrading("trait_float", "multiplier", 0.15, seq=1)
    errors = target_errors(illegal, live)
    assert any("lands outside" in e for e in errors), errors
    # The message has to carry the numbers, or the repair round is a guess.
    assert any("0.1" in e and "multiplier" in e for e in errors), errors
    # ...and a legal one still passes, so this is a gate rather than a wall.
    legal = _interpretation_upgrading("trait_float", "multiplier", -0.2, seq=1)
    assert target_errors(legal, live) == []


def test_the_fallback_cannot_build_a_log_that_refuses_to_fold():
    """The end-to-end property, over the item names that reach the trait
    ladder. A campaign that cannot fold is a campaign that cannot be
    saved, and the fallback is the generator of last resort — its output
    failing is a `RuntimeError` by construction, not something a retry
    fixes."""
    save = CampaignSave(seed_name="S", team=0, slot_id=1, slot_name="P")
    names = ["Wing Cap", "Cape Feather", "Vanish Cap", "Metal Cap",
             "Feather", "Winged Boots", "Cape", "Metal Box", "Wing Cap",
             "Cape Feather", "Vanish Cap", "Metal Cap"]
    for index, name in enumerate(names):
        live = save.derive()
        state = EchoPlayerState(owned_components=tuple(
            OwnedComponentSummary(
                component_id=o.component_id, kind=o.kind,
                display_name=o.component.display_name, mk=o.mk,
                upgradable=upgradable_field_info(o.component), detail="")
            for o in live.owned))
        location = 89100001 + index
        raw = fallback_echo(EchoGenerationRequest(
            source=EchoSource(location_id=location, item_name=name,
                              source_game="Super Mario 64",
                              recipient_name="P", item_flags=1),
            player_state=state,
            required_echo_id=f"echo_{location}"), mechanics=live)
        echo = EchoInterpretation.model_validate(raw)
        assert target_errors(echo, live) == [], (name, target_errors(echo, live))
        # The transition folds on the way in; a bad upgrade raises here.
        save = T.append_interpretation(save, echo)
    assert len(save.interpretations) == len(names)


def _interpretation_creating(component) -> EchoInterpretation:
    return EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": 0, "source_location_id": 89100001,
        "source_item_name": "Wing Cap", "source_game": "Super Mario 64",
        "source_recipient_name": "P", "concepts": ["flight"],
        "mode": "conceptual", "display_name": "Float", "description": "d.",
        "operations": [{"op": "create",
                        "component": component.model_dump()}]})


def _interpretation_upgrading(target: str, field: str, delta: float,
                              *, seq: int) -> EchoInterpretation:
    location = 89100001 + seq
    return EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": f"echo_{location}",
        "interpretation_seq": seq, "source_location_id": location,
        "source_item_name": "Cape Feather", "source_game": "Super Mario 64",
        "source_recipient_name": "P", "concepts": ["flight"],
        "mode": "mechanical", "display_name": "More Float",
        "description": "d.",
        "operations": [{"op": "upgrade", "target": target, "field": field,
                        "delta": delta}]})
