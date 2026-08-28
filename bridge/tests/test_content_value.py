"""The engine scores the room. Epsilon does not.

CAMPAIGN_SCALE.md 5. Two claims here are load-bearing and neither is
obvious from reading the scorer:

1. A provider cannot raise its own score, because none of the inputs IS a
   score. That is stronger than asking it not to lie, and the test for it
   is written as "no field you can set changes the number".
2. A bare Check is worth nothing, so a budget cannot be satisfied with
   pedestals in an empty room. This was REAL before the space rule
   landed: three empty 28x28 rooms holding one Check each scored 42.
"""

from __future__ import annotations

import pytest
from pydantic import TypeAdapter

from archipepsi_bridge import content_value as V
from archipepsi_bridge.schemas import zone as Z


def _zone(chambers: list[dict]) -> Z.Zone:
    return TypeAdapter(Z.Zone).validate_python({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch", "chambers": chambers})


def _arena(**over) -> dict:
    base = {"id": "c1", "type": "arena", "width": 20.0, "depth": 18.0,
            "wall_height": 6.0, "objective": "kill_all",
            "enemies": [{"archetype": "melee", "count": 4}]}
    base.update(over)
    return base


def _empty_huge_check_room() -> dict:
    return {"id": "c1", "type": "arena", "width": 28.0, "depth": 28.0,
            "wall_height": 8.0, "objective": "reach_reward",
            "reward_location_id": 89100001}


def test_a_bare_check_is_worth_nothing():
    """A pedestal is not gameplay. What it takes to reach it is, and that
    is already scored as the encounter or traversal it really is."""
    assert V.CHECK_VALUE == 0
    without = _zone([_arena()])
    with_check = _zone([_arena(reward_location_id=89100005)])
    assert V.zone_value(with_check) == V.zone_value(without), (
        "adding an AP Check changed the content value; a Zone could then "
        "be filled with pedestals instead of gameplay")


def test_an_empty_room_earns_almost_nothing_however_large():
    """The degenerate case, measured.

    Before space was bounded by content, an empty maximum-size arena
    holding one Check scored 14 -- the full space cap for being big and
    nothing for being empty.
    """
    value = V.zone_value(_zone([_empty_huge_check_room()]))
    assert value <= 5, (
        f"an empty 28x28 room with a Check scores {value}; at that rate "
        f"{1000 // max(value, 1)} of them satisfy a 1000-point Zone")

    busy = _zone([_arena(width=28.0, depth=28.0,
                         enemies=[{"archetype": "melee", "count": 6},
                                  {"archetype": "brute", "count": 1}])])
    assert V.zone_value(busy) >= value * 6, (
        "a busy room is not worth meaningfully more than an empty one, so "
        "the scorer is refusing to score anything rather than scoring "
        "content")


def test_a_room_of_pedestals_cannot_reach_a_production_budget():
    """The arithmetic the owner asked to be impossible, stated directly."""
    per_room = V.room_value(_zone([_empty_huge_check_room()]).chambers[0])
    low, _ = V.budget_band(1000)

    # Fifteen is the default Checks-per-Zone, which is the owner's
    # phrasing of the case: "fifteen Checks in an empty warehouse".
    assert per_room * 15 < low, (
        f"fifteen empty Check rooms score {per_room * 15}, reaching the "
        f"{low} floor of a 1000-point Zone")

    # ...and 30, because the room cap is rising. This test was written
    # when six chambers was the maximum, and a claim that only holds at
    # a cap somebody is about to raise is a claim about the cap. Even at
    # the top of the CAMPAIGN_SCALE.md 7 envelope, pedestals must not
    # come close.
    assert per_room * 30 < low // 2, (
        f"thirty empty Check rooms score {per_room * 30}, which is half "
        f"a 1000-point Zone paid for by pedestals")


@pytest.mark.parametrize("forged", [
    "room_value", "content_value", "value", "score", "budget"])
def test_no_field_a_provider_can_set_is_a_score(forged):
    """The forging test.

    Epsilon may be given a target to design toward; it may not satisfy a
    budget by claiming a number. The proof is that it cannot even SEND
    one -- `extra="forbid"` -- which is why this is a schema property and
    not something the scorer has to defend against.
    """
    with pytest.raises(Exception):
        _zone([{**_arena(), forged: 9999}])


def test_the_weights_live_in_exactly_one_place():
    """A second copy of a weight is a second scoring model."""
    import inspect
    from pathlib import Path

    root = Path(inspect.getfile(V)).resolve().parent
    offenders = []
    for path in root.rglob("*.py"):
        if path.name == "content_value.py":
            continue
        text = path.read_text()
        for name in ("ENEMY_VALUE", "AFFORDANCE_VALUE", "OBJECTIVE_VALUE",
                     "SECRET_VALUE", "TRAVERSAL_SEGMENT_VALUE"):
            if f"{name} =" in text:
                offenders.append(f"{path.name}:{name}")
    assert not offenders, (
        "content weights defined outside content_value.py: "
        + ", ".join(offenders))


@pytest.mark.parametrize("budget", [200, 400, 1000, 2000])
def test_the_budget_band_brackets_the_budget(budget):
    low, high = V.budget_band(budget)
    assert low < budget < high
    assert abs((budget - low) - (high - budget)) <= 1
    assert V.budget_errors(_zone([_arena()]), budget), (
        "one four-enemy room satisfied a whole Zone's budget")


def test_a_zone_that_holds_what_it_was_asked_for_passes():
    """The band accepts, or it is a refusal rather than a band."""
    zone = _zone([_arena()])
    actual = V.zone_value(zone)
    assert actual > 0
    assert V.budget_errors(zone, actual) == []


def test_the_error_says_which_way_the_zone_missed():
    """"Wrong size" is not actionable; too empty and too full need
    different fixes."""
    zone = _zone([_arena()])
    actual = V.zone_value(zone)
    too_big = V.budget_errors(zone, actual * 10)
    assert too_big and "emptier" in too_big[0]
    too_small = V.budget_errors(zone, max(V.ZONE_BUDGET_TOLERANCE, 1))
    assert too_small and "maximum" in too_small[0]


def test_the_validator_enforces_a_budget_when_given_one():
    """And recomputes it. The Zone below is nowhere near 1000, and no
    field it could carry would change that."""
    zone = _zone([_arena()])
    assert Z.validate_zone(
        zone, expected_zone_id="zone_001", allocated_location_ids=[],
        owned_echo_ids=[], zone_budget=1000), (
        "a one-room Zone passed validation against a 1000-point budget")


def test_no_budget_means_a_pre_budget_campaign_not_an_opt_out():
    """A campaign generated before budgets existed passes None, and its
    Zones are not judged against a rule that did not exist when they were
    made. That is the ONLY reason None is accepted."""
    zone = _zone([_arena()])
    assert Z.validate_zone(
        zone, expected_zone_id="zone_001", allocated_location_ids=[],
        owned_echo_ids=[]) == []


def test_the_budget_check_reads_components_not_claims():
    """Same rooms, same score, regardless of anything cosmetic Epsilon
    chose. Flavour text is not content."""
    plain = _zone([_arena()])
    dressed = _zone([_arena(flavor="A cathedral of unimaginable scale.")])
    assert V.zone_value(plain) == V.zone_value(dressed)


# --- CS5b: more than one Check in a room ----------------------------------

def test_a_large_room_may_hold_several_checks():
    """CAMPAIGN_SCALE.md 7. Two or three, corresponding to distinct
    activities -- not fifteen, which is the warehouse."""
    zone = _zone([_arena(reward_location_id=89100001,
                         additional_reward_location_ids=[89100002,
                                                         89100003])])
    assert zone.chambers[0].reward_ids == (89100001, 89100002, 89100003)
    assert zone.reward_location_ids == [89100001, 89100002, 89100003]


def test_several_checks_in_a_room_are_still_worth_no_content():
    """The rule that makes multi-Check rooms safe to allow at all.

    If Checks scored, this feature would BE the exploit: three pedestals
    in one room would be three times the budget for one room's work.
    """
    bare = _zone([_arena()])
    three = _zone([_arena(reward_location_id=89100001,
                          additional_reward_location_ids=[89100002,
                                                          89100003])])
    assert V.zone_value(three) == V.zone_value(bare)


def test_two_ids_may_not_share_one_completion_edge():
    """A Check must be earned once, by one thing. A duplicate id would
    send both the moment either was earned -- telling the multiworld a
    player found an item they never reached."""
    with pytest.raises(Exception, match="twice"):
        _zone([_arena(reward_location_id=89100001,
                      additional_reward_location_ids=[89100001])])


def test_extras_without_a_primary_are_refused():
    """`reward_location_id` is the primary, and anything still reading
    only that field must not silently see an empty room."""
    with pytest.raises(Exception, match="no first one"):
        _zone([_arena(additional_reward_location_ids=[89100002])])


def test_a_room_cannot_become_a_pedestal_warehouse():
    """The structural half of the anti-warehouse rule: the schema simply
    does not admit a room with many Checks in it."""
    with pytest.raises(Exception):
        _zone([_arena(reward_location_id=89100001,
                      additional_reward_location_ids=[
                          89100002, 89100003, 89100004, 89100005])])


def test_nothing_outside_the_schema_reads_the_raw_reward_fields():
    """`reward_ids` is the canonical view; the two stored fields are a
    save-compatibility shape. A consumer reading `reward_location_id`
    directly would see a three-Check room as a one-Check room."""
    import inspect
    from pathlib import Path

    root = Path(inspect.getfile(V)).resolve().parent
    offenders = []
    for path in root.rglob("*.py"):
        if path.name in ("zone.py", "requests.py") \
                or path.name.startswith("test_"):
            continue          # the schema itself, prose about it, fixtures
        lines = path.read_text().splitlines()
        for number, line in enumerate(lines, 1):
            if "reward_location_id" not in line \
                    or "reward_location_ids" in line:
                continue
            # Providers WRITE the field when building a Zone; that is the
            # storage shape and is fine. Only READS see one Check where
            # there are three, so only reads are the problem.
            stripped = line.strip()
            if stripped.startswith(('"reward_location_id":',
                                    "'reward_location_id':")) \
                    or "] = " in stripped:
                continue
            # Reading BOTH stored fields together is the correct way to
            # do it without the property -- which a `dict` chamber has to
            # do, because it is not a model yet. Judged over a small
            # window, since the two reads land on adjacent lines.
            window = "\n".join(lines[max(0, number - 3):number + 2])
            if "additional_reward_location_ids" in window:
                continue
            offenders.append(f"{path.name}:{number}: {stripped}")
    assert not offenders, (
        "these read a raw reward field instead of `reward_ids`, so they "
        "see only the first Check in a room: " + "; ".join(offenders))
