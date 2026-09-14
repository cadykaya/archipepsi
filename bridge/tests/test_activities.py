"""Puzzles that exist (CAMPAIGN_SCALE.md 9).

"Do not allow Epsilon to write 'puzzle' as flavor text and receive budget
credit." The strong form of that rule is not a check at scoring time --
it is making an unbuildable puzzle impossible to NAME:

* the vocabulary is a closed `Literal`, so there is no free-text field to
  write a puzzle into;
* every kind in it is pinned to a branch in `activities.gd`, so a kind
  the engine cannot build fails a test rather than shipping;
* and difficulty is a set of bounded numbers, so "hard" is something the
  engine builds rather than something Epsilon asserts.

Base-kit solvability is absolute, and the clock is the one dial that can
break it, so the clock is the one with a floor.
"""

from __future__ import annotations

import pytest
from pydantic import TypeAdapter, ValidationError

from archipepsi_bridge import content_value as V
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import zone as Z


def _zone(chambers: list[dict]) -> Z.Zone:
    return TypeAdapter(Z.Zone).validate_python({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch", "chambers": chambers})


def _room(**over) -> dict:
    base = {"id": "c1", "type": "arena", "width": 20.0, "depth": 18.0,
            "wall_height": 6.0, "objective": "kill_all",
            "enemies": [{"archetype": "melee", "count": 3}]}
    base.update(over)
    return base


def test_a_puzzle_cannot_be_described_only_named():
    """There is no prose field. Epsilon picks a family and dials the
    numbers; it cannot write "a fiendish riddle" and be believed.

    `requires` joined the set on 2026-08-30 and is held to the same
    standard rather than exempted from it: it is a CLOSED vocabulary,
    proven below, so the field set is still "no field a provider can
    fill with whatever it likes".
    """
    fields = set(Z.ActivityPrimitive.model_fields)
    assert fields == {"kind", "element_count", "time_limit", "ordered",
                      "requires"}, fields
    with pytest.raises(ValidationError):
        Z.ActivityPrimitive(kind="switch_sequence",
                            description="a fiendish riddle")
    with pytest.raises(ValidationError):
        Z.ActivityPrimitive(kind="switch_sequence",
                            requires=("a fiendish riddle",))


def test_the_capability_literal_and_the_capability_table_are_one_thing():
    """Two spellings of the vocabulary, pinned to each other.

    `ActivityCapability` is a Literal so the closure is visible to static
    inspection; `ACTIVITY_CAPABILITIES` holds what each one MEANS. A
    capability in one and not the other is either a gate nothing can
    satisfy or a capability nothing can ask for, and both look like
    working code.
    """
    import typing
    from archipepsi_bridge.schemas import mechanics as M
    assert (set(typing.get_args(Z.ActivityCapability))
            == set(M.ACTIVITY_CAPABILITIES))


def test_a_capability_requirement_is_semantic_not_an_item_name():
    """The owner ruling, as a property of the table.

    Every capability is satisfied by a SET of primitives, so no
    requirement can mean "the canonical Echo X". A capability satisfied
    by exactly one primitive is legal -- `blink` is -- but it still names
    a primitive that any Echo may carry, never a component id.
    """
    from archipepsi_bridge.schemas import mechanics as M
    from archipepsi_bridge.schemas import echo as E
    for capability, requirement in M.ACTIVITY_CAPABILITIES.items():
        primitives = requirement.get("primitives", ())
        stats = requirement.get("stats", ())
        assert primitives or stats, capability
        for primitive in primitives:
            assert primitive in E.ACTION_PRIMITIVES, (capability, primitive)


def test_a_capability_can_never_be_a_damage_number():
    """Raw combat power is BALANCE, never LOGIC (owner ruling, 2026-08-30).

    Two halves, and the second is the one that bites.

    A requirement carries NO NUMBER: `requires` is a tuple of names and
    the table maps each to sets of names. There is nowhere to put 400, so
    "enter only if your build does 400 DPS" is unspellable rather than
    discouraged.

    And no capability may be keyed on a damage stat. The trait vocabulary
    DOES contain `damage_dealt` and `damage_taken`, so a capability
    defined over one of them would be legal by the first half and would
    still turn combat power into progression logic through the back door.
    """
    from archipepsi_bridge.schemas import mechanics as M
    damage_stats = {"damage_dealt", "damage_taken"}
    for capability, requirement in M.ACTIVITY_CAPABILITIES.items():
        assert set(requirement) <= {"primitives", "stats"}, requirement
        for value in requirement.values():
            assert all(isinstance(v, str) for v in value), capability
        assert not damage_stats & set(requirement.get("stats", ())), (
            f"'{capability}' is gated on combat power, which is balance, "
            "not logic")


def test_an_unknown_activity_kind_is_refused():
    with pytest.raises(ValidationError):
        Z.ActivityPrimitive(kind="tower_of_hanoi")


@pytest.mark.parametrize("kind", ["switch_sequence", "timed_run",
                                  "target_challenge", "pressure_routing"])
def test_every_family_is_expressible_at_its_simplest(kind):
    assert Z.ActivityPrimitive(kind=kind).element_count >= 1


def test_a_clock_too_tight_for_base_movement_is_refused():
    """Base-kit solvability is absolute. Eight ordered switches in three
    seconds validates as a puzzle and plays as a wall."""
    with pytest.raises(ValidationError, match="at base movement speed"):
        Z.ActivityPrimitive(kind="switch_sequence", element_count=8,
                            ordered=True, time_limit=3.0)
    # ...and a generous clock on the same puzzle is fine, so the rule
    # bounds the timing rather than banning timed puzzles.
    ok = Z.ActivityPrimitive(kind="switch_sequence", element_count=8,
                             ordered=True, time_limit=60.0)
    assert ok.time_limit == 60.0


def test_an_ordered_puzzle_gets_more_time_than_an_unordered_one():
    """A mistake means going back, so the floor accounts for it."""
    count = 5
    loose = count * C.SECONDS_PER_ACTIVITY_ELEMENT
    Z.ActivityPrimitive(kind="switch_sequence", element_count=count,
                        time_limit=loose)
    with pytest.raises(ValidationError):
        Z.ActivityPrimitive(kind="switch_sequence", element_count=count,
                            ordered=True, time_limit=loose)


def test_difficulty_comes_from_composition_and_so_does_the_score():
    """Element count, a clock and an order each cost something, because
    each is something the player has to actually do."""
    plain = _zone([_room(activities=[{"kind": "switch_sequence",
                                      "element_count": 1}])])
    more = _zone([_room(activities=[{"kind": "switch_sequence",
                                     "element_count": 4}])])
    timed = _zone([_room(activities=[{"kind": "switch_sequence",
                                      "element_count": 4,
                                      "time_limit": 40.0}])])
    ordered = _zone([_room(activities=[{"kind": "switch_sequence",
                                        "element_count": 4, "ordered": True}])])
    assert V.zone_value(more) > V.zone_value(plain)
    assert V.zone_value(timed) > V.zone_value(more)
    assert V.zone_value(ordered) > V.zone_value(more)


def test_a_room_with_no_activity_scores_nothing_for_puzzles():
    """The absence must cost exactly nothing, or every room is quietly
    paying for a puzzle it does not have."""
    bare = _zone([_room()])
    with_one = _zone([_room(activities=[{"kind": "target_challenge"}])])
    assert V.zone_value(with_one) > V.zone_value(bare)
    assert V.zone_value(bare) == V.zone_value(_zone([_room(activities=[])]))


def test_the_owners_dense_room_is_now_expressible():
    """The sketch from the brief: ~10 enemies, traversal, rails, grapple,
    multiple Checks, a puzzle. It scored 43 when CS3 measured it, because
    the schema could not express most of it -- not because the weights
    were wrong."""
    dense = _zone([{
        "id": "c1", "type": "arena", "width": 26.0, "depth": 24.0,
        "wall_height": 7.0, "objective": "kill_all",
        "enemies": [{"archetype": "melee", "count": 6},
                    {"archetype": "ranged", "count": 3},
                    {"archetype": "brute", "count": 1}],
        "reward_location_id": 89100001,
        "additional_reward_location_ids": [89100002],
        "features": [{"tag": "rail"}, {"tag": "grapple_anchor"}],
        "activities": [
            {"kind": "switch_sequence", "element_count": 4, "ordered": True},
            {"kind": "target_challenge", "element_count": 3,
             "time_limit": 30.0}]}])
    value = V.zone_value(dense)
    assert value >= 80, (
        f"the owner's own dense-room example scores {value}, under the "
        "~80 they sketched; either the vocabulary still cannot express "
        "their room or the weights are wrong")
