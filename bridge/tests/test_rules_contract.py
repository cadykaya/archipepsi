"""The S4 rule-engine contract, checked from Python.

Two halves. The cross-language half gives `rule_runtime.gd` the
`test_runner_coverage.py` treatment: the staged capability tuples admit
exactly what the GDScript interpreter has arms for, in both directions —
a kind admitted but not interpreted is an Echo that validates and does
nothing; an arm for a gated kind is dead code that reads like a shipped
feature. The fold half proves the grant-side guarantees: a rule whose
cost, resource condition or resource effect names nothing the campaign
owns is refused loudly at its own point in the log (the I11 treatment),
and references resolve through merge aliases.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest
from pydantic import TypeAdapter

from archipepsi_bridge.epsilon.capabilities import (
    IMPLEMENTED_CONDITION_KINDS, IMPLEMENTED_EFFECT_KINDS,
    IMPLEMENTED_RULE_EVENTS, validate_stage_support)
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas.echo import (
    EchoInterpretation, EventKind, ConditionKind, EffectKind)
from typing import get_args

RUNTIME = (Path(__file__).resolve().parents[2]
           / "godot" / "scripts" / "gameplay" / "rule_runtime.gd")

EchoAdapter = TypeAdapter(EchoInterpretation)


def _arms_of(function_name: str, indent: str) -> set[str]:
    """Case labels of the `match` inside one function of the runtime."""
    source = RUNTIME.read_text()
    start = source.index(f"func {function_name}(")
    end = source.find("\nfunc ", start)
    body = source[start:end if end != -1 else len(source)]
    return set(re.findall(rf'^{indent}"([a-z_0-9]+)":', body, re.MULTILINE))


def test_the_interpreter_has_an_arm_for_every_implemented_effect():
    arms = _arms_of("_apply_effect", "\t\t")
    missing = set(IMPLEMENTED_EFFECT_KINDS) - arms
    assert not missing, (
        f"effects admitted but not interpreted: {sorted(missing)} — an Echo "
        "carrying one validates, persists, and does nothing")
    extra = arms - set(IMPLEMENTED_EFFECT_KINDS)
    assert not extra, (
        f"interpreter arms for gated effects: {sorted(extra)} — dead code "
        "that reads like a shipped feature")


def test_the_interpreter_has_an_arm_for_every_implemented_condition():
    arms = _arms_of("_conditions_hold", "\t\t\t")
    missing = set(IMPLEMENTED_CONDITION_KINDS) - arms
    assert not missing, f"conditions admitted but not interpreted: {sorted(missing)}"
    extra = arms - set(IMPLEMENTED_CONDITION_KINDS)
    assert not extra, f"interpreter arms for gated conditions: {sorted(extra)}"


def test_implemented_events_are_exactly_push_plus_derived_plus_the_timer():
    source = RUNTIME.read_text()
    push_block = re.search(r"const PUSH_EVENTS := \[(.*?)\]", source, re.S)
    assert push_block, "the runtime no longer declares PUSH_EVENTS"
    push = set(re.findall(r'"([a-z_0-9]+)"', push_block.group(1)))
    derived = {"resource_full", "resource_empty", "low_health",
               "status_applied"}
    for kind in derived:
        assert f'"{kind}"' in source[source.index("func _derive_edges("):], (
            f"{kind} is no longer derived by _derive_edges")
    assert push | derived | {"tick_1hz"} == set(IMPLEMENTED_RULE_EVENTS), (
        "the events the engine can emit and the events validation admits "
        "have drifted apart")


def test_every_gated_kind_is_a_real_schema_kind():
    """The gates must gate the schema's vocabulary, not typos of it."""
    assert set(IMPLEMENTED_RULE_EVENTS) <= set(get_args(EventKind))
    assert set(IMPLEMENTED_CONDITION_KINDS) <= set(get_args(ConditionKind))
    assert set(IMPLEMENTED_EFFECT_KINDS) < set(get_args(EffectKind))
    # S5 opened the status vocabulary; S9 owns what is left.
    assert set(get_args(EventKind)) == set(IMPLEMENTED_RULE_EVENTS)
    assert set(get_args(ConditionKind)) == set(IMPLEMENTED_CONDITION_KINDS)
    assert set(get_args(EffectKind)) - set(IMPLEMENTED_EFFECT_KINDS) \
        == {"grant_local_reward"}


# --- the fold half --------------------------------------------------------

def _interp(seq, ops):
    loc = 89100001 + seq
    return EchoAdapter.validate_python({
        "schema_version": 8, "echo_id": f"echo_{loc}",
        "interpretation_seq": seq, "source_location_id": loc,
        "source_item_name": "Item", "source_game": "Some Game",
        "source_recipient_name": "Somebody", "display_name": "Thing",
        "description": "It does a thing.", "operations": tuple(ops)})


def _resource(cid="res_mp"):
    return {"op": "create", "component": {
        "kind": "resource", "component_id": cid, "display_name": "MP",
        "description": "Magic.", "max_value": 100.0, "initial_fraction": 1.0,
        "presentation": "bar", "palette_color": "moss"}}


def _rule(cid="rule_r", conditions=(), costs=(), effects=None, event="kill"):
    return {"op": "create", "component": {
        "kind": "rule", "component_id": cid, "display_name": "R",
        "description": "A rule.", "event": event,
        "conditions": tuple(conditions), "costs": tuple(costs),
        "effects": tuple(effects or [{"type": "heal", "amount": 1.0}]),
        "cooldown": 0.1}}


def test_a_rule_cost_naming_an_unowned_resource_fails_the_fold_loudly():
    with pytest.raises(M.FoldError, match="cost names 'res_ghost'"):
        M.derive_mechanics([_interp(0, [_rule(
            costs=[{"resource_id": "res_ghost", "amount": 5.0}])])])


def test_a_resource_condition_and_effect_are_checked_too():
    with pytest.raises(M.FoldError, match="condition 'resource_at_least'"):
        M.derive_mechanics([_interp(0, [_rule(
            conditions=[{"type": "resource_at_least",
                         "subject": "res_ghost", "value": 0.5}])])])
    with pytest.raises(M.FoldError, match="effect 'resource_add'"):
        M.derive_mechanics([_interp(0, [_rule(
            effects=[{"type": "resource_add", "subject": "res_ghost",
                      "amount": 5.0}])])])


def test_a_flag_condition_carries_no_resource_and_passes():
    m = M.derive_mechanics([_interp(0, [_rule(
        conditions=[{"type": "grounded"}])])])
    assert m.by_id("rule_r").kind == "rule"


def test_creating_the_resource_earlier_in_the_same_interpretation_counts():
    m = M.derive_mechanics([_interp(0, [
        _resource(), _rule(costs=[{"resource_id": "res_mp",
                                   "amount": 5.0}])])])
    assert len(m.owned) == 2


def test_a_rule_reference_resolves_through_a_merge_alias():
    log = [
        _interp(0, [_resource("res_a"), _resource("res_b")]),
        _interp(1, [{"op": "merge", "absorbed": "res_a",
                     "survivor": "res_b"}]),
        _interp(2, [_rule(costs=[{"resource_id": "res_a", "amount": 5.0}])]),
    ]
    m = M.derive_mechanics(log)
    assert dict(m.aliases)["res_a"] == "res_b"
    assert m.by_id("rule_r").kind == "rule"


def test_a_rule_naming_a_non_resource_component_is_refused():
    action = {"op": "create", "component": {
        "kind": "action", "component_id": "act_gun",
        "display_name": "Gun", "description": "Bang.", "slot": "echo_a",
        "cooldown": 0.8, "primitive": {
            "type": "hitscan_damage", "damage": 8.0, "pellets": 1,
            "spread_degrees": 1.0, "range": 35.0}}}
    with pytest.raises(M.FoldError, match="not an owned resource"):
        M.derive_mechanics([_interp(0, [
            action, _rule(costs=[{"resource_id": "act_gun",
                                  "amount": 5.0}])])])


# --- stage support --------------------------------------------------------

def test_stage_support_admits_a_runnable_rule():
    interpretation = _interp(0, [_resource(), _rule(
        conditions=[{"type": "resource_at_least", "subject": "res_mp",
                     "value": 0.5}],
        costs=[{"resource_id": "res_mp", "amount": 5.0}],
        effects=[{"type": "grant_shield", "amount": 10.0,
                  "duration": 4.0}])])
    assert validate_stage_support(interpretation) == []


def test_stage_support_admits_the_s5_status_vocabulary_now():
    """S5 landed statuses, so the gate moved rather than merely closing."""
    landed = _interp(0, [_rule(
        event="status_applied",
        conditions=[{"type": "status_active", "subject": "burning"}],
        effects=[{"type": "apply_status", "subject": "burning",
                  "amount": 1.0, "duration": 3.0}])])
    assert validate_stage_support(landed) == []


def test_stage_support_still_refuses_the_s9_vocabulary():
    gated = _interp(0, [_rule(
        effects=[{"type": "grant_local_reward", "subject": "epsilon_note",
                  "amount": 1.0}])])
    errors = validate_stage_support(gated)
    assert any("grant_local_reward" in e for e in errors)
