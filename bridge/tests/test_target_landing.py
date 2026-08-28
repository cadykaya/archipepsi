"""`target_errors` waved through five refusals the fold then raised on.

The check had one job — catch a disposition that cannot land, EARLY, where
it becomes a repair prompt naming the mistake instead of a `FoldError`
raised while building the save. `_upgrade_lands` did that job for UPGRADE.
MODIFY got only an existence check and fell straight through; MERGE never
asked where `max_value` ended up.

That gap is worse than it sounds, for two reasons. A `FoldError` inside
`append_interpretation` is a crash, not a rejection: no `reconcile()` call
site has a handler, so the Check could never be granted, and the same
interpretation was retried on the next reconcile and crashed again.

And `capacity` DEFAULTS to `"sum"` — an interpretation that says nothing
about capacity says sum — so the merge case is the likeliest of the five,
not the rarest.

Each test here is a disposition that used to reach the fold. The pair of
assertions is the point: `target_errors` names it, and the fold would have
refused it, so the early check and the backstop agree about what is legal.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas.echo import target_errors

from .test_dispositions import _action, _interp, _merge, _resource


def _mods(cid="act_gun", *modifiers):
    return {"op": "create", "component": {
        "kind": "action", "component_id": cid, "display_name": "Gun",
        "description": "Bang.", "slot": "echo_a", "cooldown": 0.8,
        "modifiers": list(modifiers),
        "primitive": {"type": "hitscan_damage", "damage": 8.0, "pellets": 1,
                      "spread_degrees": 1.0, "range": 35.0}}}


def _dash(cid="act_dash"):
    return {"op": "create", "component": {
        "kind": "action", "component_id": cid, "display_name": "Dash",
        "description": "Zip.", "slot": "echo_a", "cooldown": 0.8,
        "primitive": {"type": "dash", "force": 12.0}}}


def _rule(cid="rule_x", resource="res_mp"):
    return {"op": "create", "component": {
        "kind": "rule", "component_id": cid, "display_name": "Rule",
        "description": "When.", "event": "tick_1hz", "cooldown": 1.0,
        "conditions": [], "costs": [],
        "effects": [{"type": "resource_add", "subject": resource,
                     "amount": 5.0}]}}


def _modify(target, **addition):
    return {"op": "modify", "target": target, **addition}


def _recoil(force=4.0):
    return {"type": "recoil_self", "force": force}


def _knock(force=4.0):
    return {"type": "knockback_target", "force": force}


def _burn():
    return {"type": "apply_status_on_hit", "status": "burning",
            "duration": 2.0, "magnitude": 1.0}


def _refused(log, ops):
    """Both halves: what `target_errors` says, and that the fold agrees."""
    mechanics = M.derive_mechanics(log)
    errors = target_errors(_interp(len(log), ops), mechanics)
    with pytest.raises(M.FoldError):
        M.derive_mechanics(log + [_interp(len(log), ops)])
    return errors


# --- MERGE: the default capacity ----------------------------------------

def test_summing_two_large_bars_past_the_ceiling_is_caught_early():
    """`max_value` is `le=1000`; 600 + 600 is not. And `sum` is what an
    interpretation that says nothing about capacity means."""
    log = [_interp(0, [_resource("res_a", 600.0),
                       _resource("res_b", 600.0)])]
    errors = _refused(log, [_merge("res_a", "res_b")])
    assert any("sums the capacities" in e for e in errors), errors


def test_a_merge_that_fits_is_left_alone():
    log = [_interp(0, [_resource("res_a", 400.0),
                       _resource("res_b", 400.0)])]
    mechanics = M.derive_mechanics(log)
    assert target_errors(_interp(1, [_merge("res_a", "res_b")]),
                         mechanics) == []


def test_capacity_keep_never_touches_max_value_so_it_never_overflows():
    log = [_interp(0, [_resource("res_a", 900.0),
                       _resource("res_b", 900.0)])]
    mechanics = M.derive_mechanics(log)
    assert target_errors(
        _interp(1, [_merge("res_a", "res_b", capacity="keep_survivor")]),
        mechanics) == []


# --- MODIFY: four ways it fails to land ----------------------------------

def test_a_third_modifier_on_an_action_that_holds_two_is_caught_early():
    log = [_interp(0, [_mods("act_gun", _recoil(), _knock())])]
    errors = _refused(log, [_modify("act_gun", add_modifier=_burn())])
    assert any("act_gun" in e and "invalid" in e for e in errors), errors


def test_a_duplicate_modifier_type_is_caught_early():
    log = [_interp(0, [_mods("act_gun", _recoil())])]
    errors = _refused(log, [_modify("act_gun", add_modifier=_recoil(8.0))])
    assert any("duplicate modifier" in e for e in errors), errors


def test_a_modifier_on_a_primitive_that_hits_nothing_is_caught_early():
    """`_modifiers_need_something_that_hits`: a knockback on a dash is a
    knockback with no impact to attach to."""
    log = [_interp(0, [_dash()])]
    errors = _refused(log, [_modify("act_dash", add_modifier=_knock())])
    assert any("damage primitive" in e for e in errors), errors


def test_a_modifier_on_a_component_that_is_not_an_action_is_caught_early():
    log = [_interp(0, [_resource("res_mp")])]
    errors = _refused(log, [_modify("res_mp", add_modifier=_knock())])
    assert any("only be added to" in e for e in errors), errors


def test_an_added_effect_naming_an_unowned_resource_is_caught_early():
    """The reference check, not the shape check: the modified rule
    validates fine on its own and is dead the moment it lands, because a
    missing bar reads as empty and the effect writes into nothing."""
    log = [_interp(0, [_resource("res_mp"), _rule()])]
    errors = _refused(log, [_modify("rule_x", add_effect={
        "type": "resource_add", "subject": "res_ghost", "amount": 3.0})])
    assert any("res_ghost" in e for e in errors), errors


def test_an_added_condition_naming_an_unowned_resource_is_caught_early():
    log = [_interp(0, [_resource("res_mp"), _rule()])]
    errors = _refused(log, [_modify("rule_x", add_condition={
        "type": "resource_at_least", "subject": "res_ghost",
        "value": 10.0})])
    assert any("res_ghost" in e for e in errors), errors


def test_a_modify_that_lands_cleanly_is_still_allowed():
    """The gate must not have become a wall: the ordinary case still
    passes both the early check and the fold."""
    log = [_interp(0, [_mods("act_gun", _recoil())])]
    mechanics = M.derive_mechanics(log)
    ops = [_modify("act_gun", add_modifier=_knock())]
    assert target_errors(_interp(1, ops), mechanics) == []
    folded = M.derive_mechanics(log + [_interp(1, ops)])
    assert len(folded.by_id("act_gun").component.modifiers) == 2


def test_a_modify_may_target_something_created_in_the_same_interpretation():
    """`pending` components are legal targets, and the landing check has
    to see them too or it refuses the operation for the wrong reason."""
    mechanics = M.EMPTY_MECHANICS
    ops = [_mods("act_gun"), _modify("act_gun", add_modifier=_knock())]
    assert target_errors(_interp(0, ops), mechanics) == []


# --- the singular link kinds, caught before the fold raises --------------

def test_a_second_powers_link_is_a_repair_prompt_not_a_crash():
    log = [_interp(0, [_resource("res_a"), _resource("res_b"),
                       _action("act_gun")]),
           _interp(1, [{"op": "link", "link": "powers", "source": "res_a",
                        "target": "act_gun", "strength": 5.0}])]
    errors = _refused(log, [{"op": "link", "link": "powers",
                             "source": "res_b", "target": "act_gun",
                             "strength": 5.0}])
    assert any("two 'powers' links" in e for e in errors), errors


def test_a_merge_that_collapses_two_scales_links_is_caught_early():
    """Both edges were legal when written: they scaled two different
    traits from two different bars. The merge is what makes them one."""
    log = [_interp(0, [_resource("res_a"), _resource("res_b"),
                       {"op": "create", "component": {
                           "kind": "trait", "component_id": "trait_speed",
                           "display_name": "Quick", "description": "Fast.",
                           "stat": "move_speed", "multiplier": 1.2,
                           "scaled_by": None, "requires_equipped": None}}]),
           _interp(1, [{"op": "link", "link": "scales", "source": "res_a",
                        "target": "trait_speed", "strength": 1.0}])]
    mechanics = M.derive_mechanics(log)
    ops = [{"op": "link", "link": "scales", "source": "res_b",
            "target": "trait_speed", "strength": 1.0}]
    assert any("two 'scales' links" in e
               for e in target_errors(_interp(2, ops), mechanics))
