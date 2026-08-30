"""NO REQUIREMENT BEFORE GUARANTEE (owner ruling, 2026-08-30).

Content may require a capability. It may not require one the generator
cannot PROVE the player will be able to use. These tests are about the
proof, not about the activity: the runtime half lives in
`godot/tests/test_activities.gd`.

The distinction the owner drew, and the reason this file exists:

    Room 1: kill six enemies -> an ordinary shuffled Check -> assume it
    gives Grapple -> a mandatory grapple route.

Archipelago decides what is in that Check. Assuming is not proving, and
a validator that reasons from what would be convenient is a validator
that strands people.
"""
from __future__ import annotations

import typing
from pathlib import Path

import pytest

from archipepsi_bridge.schemas import echo as E
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas import zone as Z


def _primitive_payload(primitive: str) -> dict:
    """A minimal legal payload for any primitive, from its own model.

    Introspected rather than tabulated: a hand-written table of every
    primitive's fields is a second copy of the schema that goes stale
    silently, and this file only cares WHICH primitive it owns.
    """
    for candidate in typing.get_args(
            E.ActionComponent.model_fields["primitive"].annotation):
        fields = candidate.model_fields
        literal = typing.get_args(fields["type"].annotation)
        if not literal or literal[0] != primitive:
            continue
        payload: dict = {"type": primitive}
        for name, field in fields.items():
            if name == "type" or not field.is_required():
                continue
            low = next((m.ge for m in field.metadata
                        if getattr(m, "ge", None) is not None), None)
            high = next((m.le for m in field.metadata
                         if getattr(m, "le", None) is not None), None)
            if low is not None and high is not None:
                payload[name] = type(low)((low + high) / 2)
            else:
                payload[name] = low if low is not None else 1.0
        return payload
    raise AssertionError(f"no model for primitive '{primitive}'")


def _owning(primitive: str) -> M.Mechanics:
    """A campaign that owns exactly one Action, with this primitive.

    Built through the FOLD rather than by constructing `Mechanics`
    directly: a capability read off a hand-built object would prove the
    reader works and nothing about whether a campaign could ever contain
    one.
    """
    return M.derive_mechanics([E.EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": 0, "source_location_id": 89100001,
        "source_item_name": "Conference Call", "source_game": "Borderlands 2",
        "source_recipient_name": "Player", "display_name": "Thing",
        "description": "A thing.",
        "operations": [{"op": "create", "component": {
            "kind": "action", "component_id": "act_1",
            "display_name": "Thing", "description": "A thing.",
            "slot": "mobility", "cooldown": 2.0,
            "primitive": _primitive_payload(primitive),
            "modifiers": []}}]})])


# --- the vocabulary is semantic, not an item list ------------------------

def test_grapple_is_satisfied_by_any_member_of_the_family():
    """The owner's central point. Three different primitives, one
    capability, and no canonical Echo anywhere in the answer."""
    for primitive in ("grapple_to_surface", "grapple_pull_target",
                      "grapple_swing"):
        assert "grapple" in M.owned_capabilities(_owning(primitive)), primitive


def test_owning_the_wrong_thing_does_not_satisfy_it():
    assert "grapple" not in M.owned_capabilities(_owning("double_jump"))


# --- the four guarantee cases -------------------------------------------

def test_case_a_the_permanent_baseline_needs_nothing():
    """Static Pulse is the always-available ranged floor, so a campaign
    that owns nothing at all can still be asked to hit something."""
    guarantee = M.capability_guarantee("ranged_hit", M.Mechanics())
    assert guarantee.guaranteed
    assert guarantee.reason == "permanent_baseline"


def test_case_b_is_read_from_the_fold():
    guarantee = M.capability_guarantee("grapple", _owning("grapple_swing"))
    assert guarantee.guaranteed
    assert guarantee.reason == "already_possessed"


def test_case_c_is_a_seam_with_no_producer_yet():
    """Passing the set is how a future establishment point plugs in.
    Every caller passes nothing today, which is the honest answer: the
    Zone establishes nothing."""
    empty = M.Mechanics()
    assert not M.capability_guarantee("blink", empty).guaranteed
    established = M.capability_guarantee("blink", empty, ("blink",))
    assert established.guaranteed
    assert established.reason == "established_in_zone"


def test_case_d_the_forge_is_named_and_unreachable():
    """Deferred deliberately. The reason exists so the answer's SHAPE
    does not have to change the day the Forge lands."""
    assert "forge_constructible" in M.CapabilityGuarantee.model_fields[
        "reason"].annotation.__args__
    reasons = {M.capability_guarantee(c, _owning(p)).reason
               for c, p in (("grapple", "grapple_swing"),
                            ("blink", "blink"),
                            ("cross_long_gap", "dash"),
                            ("ranged_hit", "dash"))}
    assert "forge_constructible" not in reasons


# --- the negative controls ----------------------------------------------

def test_an_unknown_capability_is_refused_not_defaulted():
    """A typo that silently means "no requirement" is the exact failure
    this invariant exists to prevent."""
    guarantee = M.capability_guarantee("teleport", M.Mechanics())
    assert not guarantee.guaranteed
    assert guarantee.reason == "not_guaranteed"


def test_ownership_is_not_the_loadout():
    """You own the grapple whether or not it is slotted, and you can
    always slot it -- so generation asks what you OWN. A Zone whose
    contents depended on the loadout would lie the moment slots changed.
    """
    mechanics = _owning("grapple_swing")
    empty_slots = _Slots()
    assert "grapple" in M.owned_capabilities(mechanics)
    assert "grapple" not in M.available_capabilities(mechanics, empty_slots)


def test_available_is_what_makes_not_yet_a_real_state():
    """The gap between owned and available is not a bug: it is the only
    thing that makes a NOT YET gate reachable rather than dead code."""
    mechanics = _owning("grapple_swing")
    assert "grapple" in M.available_capabilities(mechanics, _Slots(
        mobility="act_1"))


def test_the_baseline_is_available_with_nothing_equipped():
    assert "ranged_hit" in M.available_capabilities(M.Mechanics(), _Slots())


class _Slots:
    """The four-field slot assignment, minimally. `available_capabilities`
    reads field names off the model, so this stands in for the real one
    without importing the protocol into a schema test."""

    model_fields = {"echo_a": None, "echo_b": None,
                    "mobility": None, "utility": None}

    def __init__(self, **over):
        for name in self.model_fields:
            setattr(self, name, over.get(name))


# --- the validator refuses what cannot be proven -------------------------

def _zone_with(activity: dict) -> Z.Zone:
    return Z.Zone.model_validate({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [{
            "id": "c1", "type": "arena", "width": 20.0, "depth": 18.0,
            "wall_height": 6.0, "objective": "kill_all",
            "reward_location_id": 89100001,
            "enemies": [{"archetype": "melee", "count": 3}],
            "activities": [activity]}]})


def _errors(zone: Z.Zone, guaranteed: tuple[str, ...]) -> list[str]:
    return Z.validate_zone(
        zone, expected_zone_id="zone_001",
        allocated_location_ids=[89100001], owned_echo_ids=[],
        guaranteed_capabilities=guaranteed)


def test_a_requirement_that_is_guaranteed_is_accepted():
    zone = _zone_with({"kind": "target_challenge", "element_count": 3,
                       "requires": ["ranged_hit"]})
    assert not [e for e in _errors(zone, ("ranged_hit",)) if "requiring" in e]


def test_a_requirement_that_is_not_guaranteed_is_refused():
    zone = _zone_with({"kind": "switch_sequence", "element_count": 3,
                       "requires": ["grapple"]})
    refusals = [e for e in _errors(zone, ("ranged_hit",)) if "requiring" in e]
    assert refusals, "an unguaranteed requirement was let through"
    assert "grapple" in refusals[0]


def test_the_default_guarantee_set_refuses_rather_than_permits():
    """A caller that forgets the argument must refuse MORE than it
    should, never less. The default is the permanent baseline."""
    zone = _zone_with({"kind": "switch_sequence", "requires": ["blink"]})
    errors = Z.validate_zone(
        zone, expected_zone_id="zone_001",
        allocated_location_ids=[89100001], owned_echo_ids=[])
    assert [e for e in errors if "requiring" in e]


def test_no_requirement_at_all_is_the_ordinary_case():
    zone = _zone_with({"kind": "pressure_routing", "element_count": 2})
    assert not [e for e in _errors(zone, ()) if "requiring" in e]


@pytest.mark.parametrize("kind", ["switch_sequence", "timed_run",
                                  "target_challenge", "pressure_routing"])
def test_every_kind_can_carry_a_guaranteed_requirement(kind):
    zone = _zone_with({"kind": kind, "element_count": 2,
                       "requires": ["ranged_hit"]})
    assert not [e for e in _errors(zone, ("ranged_hit",)) if "requiring" in e]


# --- an activity can never become Archipelago's business -----------------

def test_an_activity_completion_cannot_reach_ap_truth():
    """The client sends `grant_local_reward` and nothing else.

    Structural, not behavioural: `EarnedLocalReward` has no field that
    could name a location, an item, a Check, a Coin or a Signal Key, so
    the intent an activity sends is INCAPABLE of touching AP truth rather
    than merely careful not to. The Godot half asserts that this is the
    only intent a completion sends.
    """
    from archipepsi_bridge.schemas import protocol as P

    fields = set(P.EarnedLocalReward.model_fields)
    forbidden = {"location_id", "location_ids", "item_name", "check",
                 "coins", "signal_keys", "ap_item", "location"}
    assert not fields & forbidden, sorted(fields & forbidden)


def test_solving_the_same_activity_twice_is_one_reward():
    """An activity is not a farm.

    The bridge half. The client derives `reward_id` from the activity's
    identity; `grant_local_reward` is idempotent by that id, so the
    second solve records nothing new.
    """
    from archipepsi_bridge.schemas import protocol as P
    from archipepsi_bridge.schemas import transitions as T

    save = P.CampaignSave(seed_name="s", slot_id=1, slot_name="P", team=0)
    reward = P.EarnedLocalReward(
        kind="flavor_log", reward_id="activity_c1_0",
        display_name="Switch sequence solved", description="Solved in c1.",
        source_zone_id="zone_001")
    once = T.grant_local_reward(save, reward)
    twice = T.grant_local_reward(once, reward)
    assert len(once.local_rewards) == 1
    assert len(twice.local_rewards) == 1


def test_an_activity_reward_is_not_the_deferred_challenge_marker():
    """`challenge_marker` is the kind an activity completion most
    obviously wants, and it is deliberately without semantics. This
    batch does not resolve that decision as a side effect."""
    driver = (Path(__file__).resolve().parents[2] / "godot" / "scripts"
              / "gameplay" / "activity_runtime.gd").read_text()
    assert '"kind": "flavor_log"' in driver
    assert "challenge_marker" not in driver


def test_the_timing_record_cannot_carry_an_ap_id_through_an_activity():
    """The measurement path is the other way an activity could reach AP
    truth, and it is closed the same way: by having no field for it."""
    from archipepsi_bridge.schemas import protocol as P

    fields = set(P.ActivityOutcome.model_fields)
    assert not fields & {"location_id", "reward_location_id", "check",
                         "item_name", "coins"}, sorted(fields)
