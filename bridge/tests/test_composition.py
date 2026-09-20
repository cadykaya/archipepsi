"""A valid Zone can still be a bad one (CAMPAIGN_SCALE.md 6).

Every rule here forbids one degenerate shape the owner named. None of
them describes a good Zone -- that distinction is the whole design.
Constraints that say what a level should look like become a template, and
a template is Epsilon filling in blanks instead of composing.

So each test below is "this specific bad thing is refused", and there is
one at the end asserting the rules do NOT refuse an ordinary good Zone,
because a constraint set that rejects everything is indistinguishable
from a broken one.
"""

from __future__ import annotations

import pytest
from pydantic import TypeAdapter

from archipepsi_bridge import composition as X
from archipepsi_bridge.schemas import zone as Z

FULL = 1000


def _zone(chambers: list[dict]) -> Z.Zone:
    return TypeAdapter(Z.Zone).validate_python({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch", "chambers": chambers})


def _connector(i: int, **over) -> dict:
    base = {"id": f"k{i}", "type": "corridor", "length": 10.0, "width": 5.0}
    base.update(over)
    return base


def _fight(i: int, melee: int = 4, **over) -> dict:
    base = {"id": f"a{i}", "type": "arena", "width": 20.0, "depth": 18.0,
            "wall_height": 6.0, "objective": "kill_all",
            "enemies": [{"archetype": "melee", "count": melee}]}
    base.update(over)
    return base


def _good_zone() -> Z.Zone:
    """An ordinary, unremarkable, acceptable Zone."""
    return _zone([
        _connector(1),
        _fight(1, melee=4),
        _connector(2, width=8.0, features=[{"tag": "bounce_pad"}]),
        _fight(2, melee=6, enemies=[{"archetype": "melee", "count": 5},
                                    {"archetype": "brute", "count": 1}]),
        _connector(3),
        _fight(3, width=26.0, depth=24.0,
               enemies=[{"archetype": "ranged", "count": 4},
                        {"archetype": "melee", "count": 6}]),
    ])


def test_an_ordinary_zone_passes():
    """The most important test here. A constraint set that refuses
    everything is indistinguishable from a broken one, and it is far
    easier to write than one that refuses only the bad shapes."""
    assert X.composition_errors(_good_zone(), FULL) == []


def test_a_zone_of_connectors_is_refused():
    """"an entire 1000-point Zone made from tiny connectors"."""
    zone = _zone([_connector(i) for i in range(1, 7)])
    errors = X.composition_errors(zone, FULL)
    assert errors
    assert any("in a row" in e or "landmark" in e for e in errors), errors


def test_a_long_chain_of_empty_rooms_is_refused():
    """"long chains of empty rooms". Three is a rhythm; five is a
    corridor with scenery."""
    zone = _zone([_fight(1)] + [_connector(i) for i in range(1, 6)]
                 + [_fight(2, melee=6)])
    assert any("in a row" in e for e in X.composition_errors(zone, FULL))


def test_every_check_in_one_room_is_refused():
    """"every Check placed in the same room". Only reachable at exactly
    three Checks -- the schema's per-room cap forbids it above that -- so
    this closes the last size where it is possible."""
    zone = _zone([
        _connector(1),
        _fight(1, reward_location_id=89100001,
               additional_reward_location_ids=[89100002, 89100003]),
        _connector(2),
    ])
    assert any("one room" in e for e in X.composition_errors(zone, FULL))


def test_one_encounter_repeated_is_refused():
    """"every room using the same encounter". The second identical fight
    is already the same fight again."""
    zone = _zone([_connector(1)] + [_fight(i, melee=4) for i in range(1, 4)])
    assert any("one encounter" in e for e in X.composition_errors(zone, FULL))


def test_one_affordance_repeated_is_refused():
    """"every room using the same affordance"."""
    zone = _zone([
        _fight(1),
        _connector(1, width=8.0, features=[{"tag": "bounce_pad"}]),
        _connector(2, width=8.0, features=[{"tag": "bounce_pad"}]),
        _connector(3, width=8.0, features=[{"tag": "bounce_pad"}]),
        _fight(2, melee=6),
    ])
    assert any("and nothing else" in e
               for e in X.composition_errors(zone, FULL))


def test_a_zone_with_no_landmark_is_refused():
    """"at least one memorable major room". Uniform rooms mean a level
    with nowhere in it."""
    zone = _zone([_fight(i, melee=4) for i in range(1, 6)])
    errors = X.composition_errors(zone, FULL)
    assert any("landmark" in e for e in errors), errors


def test_a_zone_with_no_quiet_space_is_refused():
    """Dense in every room is exhausting rather than full."""
    zone = _zone([
        _fight(1, melee=3),
        _fight(2, melee=6, enemies=[{"archetype": "brute", "count": 1},
                                    {"archetype": "melee", "count": 4}]),
        _fight(3, width=28.0, depth=26.0,
               enemies=[{"archetype": "ranged", "count": 5}]),
    ])
    assert any("quiet space" in e for e in X.composition_errors(zone, FULL))


def test_a_development_zone_is_not_held_to_a_level_s_standards():
    """Expectations scale. A 200-point Zone is three rooms for testing
    something, not a level, and demanding a landmark and a quiet space
    and combat variety of it would make small campaigns ungenerateable --
    which is how a bound stops being available in practice."""
    tiny = _zone([_connector(1), _fight(1, melee=2)])
    assert X.composition_errors(tiny, 200) == []
    # ...but the size-independent rule still applies to it.
    all_checks = _zone([_fight(1, reward_location_id=89100001,
                               additional_reward_location_ids=[89100002,
                                                               89100003])])
    assert X.composition_errors(all_checks, 200)


@pytest.mark.parametrize("budget", [200, 400, 599, 600, 1000, 2000])
def test_the_rules_never_refuse_a_good_zone_at_any_budget(budget):
    """The cutoff must not be a cliff a reasonable Zone falls off."""
    assert X.composition_errors(_good_zone(), budget) == []


def test_the_landmark_rule_catches_uniformity_at_any_room_count():
    """The first version of this rule was quietly weak.

    Measured as a share of the Zone total, N uniform rooms each hold 1/N
    of it -- so a 12% threshold only noticed uniformity above eight rooms
    and passed a five-room Zone of identical arenas. Measured against the
    average room, uniformity is uniformity at any size.
    """
    for count in (3, 5, 9, 15):
        uniform = _zone([_connector(0)]
                        + [_fight(i, melee=4) for i in range(1, count)])
        errors = X.composition_errors(uniform, FULL)
        assert any("landmark" in e for e in errors), (
            f"{count} interchangeable rooms passed the landmark rule: "
            f"{errors}")


def test_a_zone_with_one_standout_room_passes():
    """And the rule accepts, or it is a refusal rather than a rule."""
    zone = _zone([
        _connector(1),
        _fight(1, melee=3),
        _connector(2),
        _fight(2, width=28.0, depth=26.0,
               enemies=[{"archetype": "melee", "count": 8},
                        {"archetype": "brute", "count": 1}]),
    ])
    assert not any("landmark" in e for e in X.composition_errors(zone, FULL))
