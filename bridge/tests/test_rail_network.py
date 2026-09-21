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
