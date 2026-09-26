"""H-QUALIFY — the featured Echo is held to a real function (D-02).

The owner: "an Echo must provide the actual traversal capability the room
requires [...] there must be a deterministic guaranteed fallback", and
`grapple_pull_target` must not pass for a crossing. Each case below is an
Echo a provider could really return, judged by folding it onto the log
exactly as it would be appended.
"""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from archipepsi_bridge.schemas import featured as F
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.echo import EchoInterpretation
from archipepsi_bridge.schemas.zone import validate_zone

from .test_featured_acquisition import FEATURED_LOCATION, _featured, _zone

REQ = F.FEATURED_REQUIREMENTS["grapple"]


def _echo(loc: int, *ops, name="Hookshot") -> EchoInterpretation:
    return EchoInterpretation.model_validate({
        "echo_id": f"echo_{loc}", "interpretation_seq": 0,
        "source_location_id": loc, "source_item_name": name,
        "source_game": "Ocarina of Time", "source_recipient_name": "Link",
        "display_name": name, "description": "It pulls.",
        "operations": list(ops)})


def _grapple(cid="act_hook", kind="grapple_to_surface", slot="mobility",
             charges=None, **params) -> dict:
    primitive = {"type": kind, "range": 20.0} | {
        "grapple_to_surface": {"pull_force": 18.0},
        "grapple_swing": {"tether_force": 18.0, "max_duration": 3.0},
        "grapple_pull_target": {"pull_force": 18.0, "max_target_hp": 30.0},
    }[kind] | params
    return {"op": "create", "component": {
        "kind": "action", "component_id": cid, "display_name": "Hook",
        "description": "It pulls.", "slot": slot, "cooldown": 1.5,
        **({"charges": charges} if charges is not None else {}),
        "primitive": primitive, "modifiers": []}}


# --- the requirement ----------------------------------------------------------

def test_the_featured_check_is_held_to_the_proven_grapple():
    zone = _zone(_featured())
    assert F.requirement_for(zone, FEATURED_LOCATION) is REQ
    assert F.requirement_for(zone, FEATURED_LOCATION + 1) is None
    assert F.requirement_for(_zone(), FEATURED_LOCATION) is None
    assert REQ.primitive == "grapple_to_surface"
    assert REQ.minimums == {"range": 20.0, "pull_force": 14.0}


@pytest.mark.parametrize("capability, primitive, says", [
    ("grapple", "grapple_pull_target", "does not move the player"),
    ("grapple", "blink", "does not move the player"),
    ("ranged_hit", "hitscan_damage", "not a traversal capability"),
])
def test_a_requirement_can_only_name_a_crossing(capability, primitive, says):
    with pytest.raises(ValidationError, match=says):
        F.FeaturedRequirement(capability=capability, primitive=primitive,
                              minimums={"range": 1.0}, evidence="test")


def test_a_featured_room_with_no_proven_function_is_not_accepted():
    zone = _zone(_featured(capability="blink"))
    errors = validate_zone(zone, expected_zone_id=zone.zone_id,
                           allocated_location_ids=list(
                               zone.reward_location_ids),
                           owned_echo_ids=[])
    assert any("no proven requirement covers" in e for e in errors), errors


# --- the check ------------------------------------------------------------------

def test_a_real_grapple_that_reaches_the_deck_qualifies():
    assert F.check((), _echo(FEATURED_LOCATION, _grapple()), REQ, 0) == []


@pytest.mark.parametrize("op, says", [
    (_grapple(kind="grapple_pull_target"),
     "is grapple_pull_target, not grapple_to_surface"),
    (_grapple(kind="grapple_swing"), "is grapple_swing, not"),
    (_grapple(range=15.0), "range 15 < 20"),
    (_grapple(pull_force=10.0), "pull_force 10 < 14"),
    (_grapple(slot="consumable", charges=3), "is a consumable"),
])
def test_an_echo_that_misses_the_function_is_told_why(op, says):
    errors = F.check((), _echo(FEATURED_LOCATION, op), REQ, 0)
    assert errors and says in errors[0], errors


def test_an_upgrade_that_makes_an_owned_grapple_reach_counts():
    """What is judged is what the player would own, folded."""
    owned = _echo(89100001, _grapple(range=15.0), name="Short Hook")
    upgrade = _echo(FEATURED_LOCATION, {"op": "upgrade", "target": "act_hook",
                                        "field": "range", "delta": 5.0})
    assert F.check((owned,), upgrade, REQ, 1) == []


def test_owning_a_grapple_already_does_not_excuse_this_echo():
    """The ruling is that THIS Echo provides it."""
    owned = _echo(89100001, _grapple(), name="Old Hook")
    trait = _echo(FEATURED_LOCATION, {"op": "create", "component": {
        "kind": "trait", "component_id": "trait_swift",
        "display_name": "Swift", "description": "Faster.",
        "stat": "move_speed", "multiplier": 1.2}})
    errors = F.check((owned,), trait, REQ, 1)
    assert errors and "creates or changes no Action" in errors[0]


# --- the deterministic fallback ---------------------------------------------------

@pytest.mark.parametrize("item", ["Signal Key", "Epsilon Coin", "Bomb Bag",
                                  "x" * 96])
def test_the_fallback_always_qualifies_whatever_the_item(item):
    """Unlike the name-keyword fallback, a Signal Key yields a working
    grapple: the function is the contract's, the name is the item's."""
    fb = F.fallback_interpretation(
        REQ, location_id=FEATURED_LOCATION, item_name=item,
        source_game="Archipepsi", recipient_name="Skyiah")
    assert F.check((), fb, REQ, 0) == []
    assert fb.echo_id == f"echo_{FEATURED_LOCATION}"
    assert fb == F.fallback_interpretation(
        REQ, location_id=FEATURED_LOCATION, item_name=item,
        source_game="Archipepsi", recipient_name="Skyiah")


def test_the_fallback_appends_and_the_fold_owns_the_crossing():
    save = P.CampaignSave(seed_name="Seed", team=0, slot_id=1,
                          slot_name="Skyiah")
    fb = F.fallback_interpretation(
        REQ, location_id=FEATURED_LOCATION, item_name="Signal Key",
        source_game="Archipepsi", recipient_name="Skyiah")
    save = T.append_interpretation(save, fb)
    from archipepsi_bridge.schemas import mechanics as M
    assert "grapple" in M.owned_capabilities(save.derive())
