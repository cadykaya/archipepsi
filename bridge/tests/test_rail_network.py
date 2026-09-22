"""D-4 — a composed Zone can declare rail content, so a junction can be
ASKED FOR rather than invented.

**Why this is first class and not a `feature:` tag.** A physics package
binds to `feature:<tag>` or `shell:<id>` (`layout._content_refs`), and
§13.2 forbids a feature from lying on the mandatory path, hosting a
reward, an exit or an objective. A span the player must cross is exactly
a thing on the mandatory path, so as a feature it would have to be
optional — and an optional span is not a railway. That is what left
`M1-zone` blocked: nothing in the Zone schema declared rail content, so
the composer could not ask and the engine was not allowed to invent.

Shaped after what `RailJunction` already runs — docks it parks at, spans
between them, one alignment control per span, a latch per span — rather
than after a second idea about railways.
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from archipepsi_bridge import layout as LAY
from archipepsi_bridge.schemas.zone import RailNetwork, Zone


def _arena(rid: str, reward: int | None = None) -> dict:
    return {"id": rid, "type": "arena", "width": 16.0, "depth": 15.0,
            "wall_height": 5.0, "objective": "kill_all",
            "reward_location_id": reward,
            "enemies": [{"archetype": "melee", "count": 1}]}


def _net(**over) -> dict:
    base = {
        "network_id": "yard",
        "docks": [{"dock_id": "s1", "room_id": "c001"},
                  {"dock_id": "s2", "room_id": "c002"},
                  {"dock_id": "s3", "room_id": "c003"}],
        "spans": [
            {"span_id": "s1s2", "from_dock": "s1", "to_dock": "s2",
             "latch_id": "span_one", "mandatory": True},
            {"span_id": "s2s3", "from_dock": "s2", "to_dock": "s3",
             "control_room_id": "c002", "latch_id": "span_two",
             "mandatory": True},
        ],
    }
    base.update(over)
    return base


def _zone(**over) -> dict:
    base = {"zone_id": "z1", "display_name": "T", "target_game": "T",
            "theme": "void_glitch",
            "chambers": [_arena("c001", 89100001), _arena("c002"),
                         _arena("c003", 89100003)]}
    base.update(over)
    return base


def test_a_zone_can_declare_a_railway():
    z = Zone.model_validate(_zone(rail_networks=[_net()]))
    net = z.rail_networks[0]
    assert [d.dock_id for d in net.docks] == ["s1", "s2", "s3"]
    assert net.spans[1].control_room_id == "c002"
    assert net.spans[0].mandatory is True


def test_a_zone_without_the_field_still_loads():
    """Additive: a save composed before D-4 has no `rail_networks`."""
    z = Zone.model_validate(_zone())
    assert z.rail_networks == ()


def test_a_package_may_bind_to_the_railway():
    """THE POINT OF D-4. `rail:<network_id>` is a content ref a package
    can realize, which `feature:`/`shell:` could not express for
    something load-bearing."""
    z = Zone.model_validate(_zone(rail_networks=[_net()]))
    assert "rail:yard" in LAY._rail_refs(z)
    # and a Zone with no railway offers no rail ref to bind to
    assert LAY._rail_refs(Zone.model_validate(_zone())) == set()


def test_a_dock_in_a_room_that_does_not_exist_is_refused():
    with pytest.raises(ValidationError, match="which this Zone does not have"):
        Zone.model_validate(_zone(rail_networks=[_net(
            docks=[{"dock_id": "s1", "room_id": "c001"},
                   {"dock_id": "s9", "room_id": "c999"}],
            spans=[{"span_id": "a", "from_dock": "s1", "to_dock": "s9",
                    "latch_id": "one"}])]))


def test_a_control_in_a_room_that_does_not_exist_is_refused():
    with pytest.raises(ValidationError, match="which this Zone does not have"):
        Zone.model_validate(_zone(rail_networks=[_net(spans=[
            {"span_id": "a", "from_dock": "s1", "to_dock": "s2",
             "control_room_id": "c404", "latch_id": "one"}])]))


def test_a_span_must_join_docks_the_network_declares():
    with pytest.raises(ValidationError, match="does not declare"):
        RailNetwork.model_validate(_net(spans=[
            {"span_id": "a", "from_dock": "s1", "to_dock": "s7",
             "latch_id": "one"}]))


def test_a_span_may_not_leave_and_arrive_at_the_same_dock():
    with pytest.raises(ValidationError, match="leaves and arrives"):
        RailNetwork.model_validate(_net(spans=[
            {"span_id": "a", "from_dock": "s1", "to_dock": "s1",
             "latch_id": "one"}]))


def test_two_spans_may_not_share_a_latch():
    """A latch is the handle a commissioned span persists under; two
    spans sharing one cannot be told apart on reload."""
    with pytest.raises(ValidationError, match="reuses a latch id"):
        RailNetwork.model_validate(_net(spans=[
            {"span_id": "a", "from_dock": "s1", "to_dock": "s2",
             "latch_id": "same"},
            {"span_id": "b", "from_dock": "s2", "to_dock": "s3",
             "latch_id": "same"}]))


def test_two_networks_may_not_share_a_name():
    with pytest.raises(ValidationError, match="both called"):
        Zone.model_validate(_zone(rail_networks=[_net(), _net()]))


# --------------------------------------------------------------------------
# F-22's three questions, answered. Prod found these by building the
# engine half against the contract: the schema described a GRAPH and the
# carrier runs ONE ORDERED ROUTE.
# --------------------------------------------------------------------------

def test_a_span_between_non_consecutive_docks_is_refused():
    """Question 1, answered YES, and refused HERE rather than in the engine.

    `s1` to `s3` skips `s2`. The carrier has a link between each
    consecutive pair and none between these two, so the engine would
    have to route through the dock in between -- deciding what the Zone
    meant -- or refuse. It refuses. A Zone that cannot be built should
    not validate.
    """
    with pytest.raises(ValidationError, match="no link to commission"):
        RailNetwork.model_validate(_net(spans=[
            {"span_id": "a", "from_dock": "s1", "to_dock": "s3",
             "latch_id": "one"}]))


def test_the_refusal_names_the_docks_the_route_passes_in_between():
    """A refusal that does not say WHICH dock was skipped sends whoever
    reads it back to count the list by hand."""
    with pytest.raises(ValidationError, match=r"\['s2'\]"):
        RailNetwork.model_validate(_net(spans=[
            {"span_id": "a", "from_dock": "s1", "to_dock": "s3",
             "latch_id": "one"}]))


def test_a_span_declared_against_the_route_order_is_still_consecutive():
    """THE CONTROL THAT KEEPS THE RULE FROM BEING STRICTER THAN THE FACT.

    `docks` order is the ROUTE order, not a direction of travel. `s2` to
    `s1` is the same link as `s1` to `s2` and must be accepted, or the
    rule would refuse half the legal declarations for a reason that has
    nothing to do with what the carrier can run.
    """
    net = RailNetwork.model_validate(_net(spans=[
        {"span_id": "a", "from_dock": "s2", "to_dock": "s1",
         "latch_id": "one"}]))
    assert net.spans[0].from_dock == "s2"


def test_two_spans_may_not_join_the_same_pair_of_docks():
    """The same finding taken one step further than the question asked.

    Consecutive docks have ONE link. Two spans naming the same pair are
    two latches and two controls over one piece of track, and the second
    has nothing of its own to commission -- the same defect as a skipped
    dock, arrived at from the other side.
    """
    with pytest.raises(ValidationError, match="no link of its own"):
        RailNetwork.model_validate(_net(spans=[
            {"span_id": "a", "from_dock": "s1", "to_dock": "s2",
             "latch_id": "one"},
            {"span_id": "b", "from_dock": "s2", "to_dock": "s1",
             "latch_id": "two"}]))


def test_a_home_dock_the_network_does_not_declare_is_refused():
    with pytest.raises(ValidationError, match="which it does not declare"):
        RailNetwork.model_validate(_net(home_dock="s9"))


def test_a_home_dock_may_be_declared():
    """Question 3: the engine parked at dock 0 and no Zone could say
    otherwise. Now one can."""
    assert RailNetwork.model_validate(_net(home_dock="s3")).home_dock == "s3"


def test_no_home_dock_means_the_first_dock_and_the_order_is_declared():
    """Question 2 and question 3 together, as data rather than prose.

    `None` is the default the engine already implements, so nothing that
    is built today changes. What changes is that `docks[0]` is now a
    stated route start instead of an invisible engine assumption.
    """
    net = RailNetwork.model_validate(_net())
    assert net.home_dock is None
    assert net.docks[0].dock_id == "s1"
