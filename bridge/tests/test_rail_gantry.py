"""D-6 steps 1 and 2 -- Blindside's gantry, and a span as a ride.

Proposed as note D-6 and confirmed by Prod's N-14 (2026-09-25):
`RailSpan.control_placement` is `ground` (today's lever) or `gantry` (the
development scenario's deck, 3.1 m up with its hookshot plate 7.2 m up,
no stairs, no mantle). A gantry needs `grapple` -- DESS-26's anchor
grapple, derived, never declared -- and an arena at the top of the
procedural range. The route search now rides a span between its docks'
rooms once commissioned, and D-03 holds beyond a gantry: until the
Archipelago logic declares the grapple, nothing AP-relevant lies there.

The Zone below is a four-room chain -- c001, c002, c003, c004, the exit --
and c005, joined to nothing but the railway: a dock in c002 and a dock in
c005, and one span between them commissioned from c002.
"""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from archipepsi_bridge import topology as TP
from archipepsi_bridge.schemas.featured import FEATURED_REQUIREMENTS
from archipepsi_bridge.schemas.zone import (CONTROL_PLACEMENT_CAPABILITY,
                                            GANTRY_MIN_WALL_HEIGHT,
                                            RailSpan, Zone)


def _arena(rid: str, reward: int | None = None, height: float = 5.0) -> dict:
    return {"id": rid, "type": "arena", "width": 16.0, "depth": 15.0,
            "wall_height": height, "objective": "kill_all",
            "reward_location_id": reward,
            "enemies": [{"archetype": "melee", "count": 1}]}


def _span(**over) -> dict:
    return {"span_id": "s2s5", "from_dock": "s2", "to_dock": "s5",
            "control_room_id": "c002", "latch_id": "span_out", **over}


def _zone(*, rail=True, far_reward=None, control_height=8.0,
          featured=None, **span) -> Zone:
    rooms = [_arena("c001", 89100001), _arena("c002", height=control_height),
             _arena("c005", far_reward), _arena("c003", 89100003),
             _arena("c004", 89100004)]
    body = {"zone_id": "z1", "display_name": "T", "target_game": "T",
            "theme": "void_glitch", "chambers": rooms}
    if rail:
        body["rail_networks"] = [{
            "network_id": "yard",
            "docks": [{"dock_id": "s2", "room_id": "c002"},
                      {"dock_id": "s5", "room_id": "c005"}],
            "spans": [_span(**span)]}]
    if featured is not None:
        body["featured_acquisition"] = featured
    zone = Zone.model_validate(body)
    chain = [c for c in zone.chambers if c.id != "c005"]
    return TP.apply(zone, TP.compose_chain(chain))


# --- step 1: the field ---------------------------------------------------------

def test_a_span_declared_before_the_field_is_a_ground_lever():
    span = RailSpan.model_validate(_span())
    assert span.control_placement == "ground"
    assert CONTROL_PLACEMENT_CAPABILITY["ground"] is None


def test_a_gantry_needs_the_proven_grapple_and_nothing_declares_it_twice():
    """DESS-26's contract, derived from the placement: the capability the
    gantry demands is the one whose crossing the room has been shown to
    need (`FEATURED_REQUIREMENTS`), and a span has no field to say
    otherwise."""
    assert CONTROL_PLACEMENT_CAPABILITY["gantry"] == "grapple"
    assert FEATURED_REQUIREMENTS["grapple"].primitive == "grapple_to_surface"
    assert "capability" not in RailSpan.model_fields


def test_a_gantry_is_always_somewhere():
    with pytest.raises(ValidationError, match="names no room for it"):
        RailSpan.model_validate(_span(control_room_id=None,
                                      control_placement="gantry"))


@pytest.mark.parametrize("height", [5.0, 7.9])
def test_a_gantry_room_too_low_for_its_plate_is_refused(height):
    with pytest.raises(ValidationError, match="at least 8 m tall"):
        _zone(control_placement="gantry", control_height=height)


def test_a_gantry_fits_an_arena_at_the_top_of_the_range():
    assert GANTRY_MIN_WALL_HEIGHT == 8.0
    zone = _zone(control_placement="gantry", control_height=8.0)
    assert zone.rail_networks[0].spans[0].control_placement == "gantry"


# --- step 2: a span is a ride ---------------------------------------------------

def test_a_room_joined_only_by_rail_is_reached_by_riding():
    """The control: without the railway, c005's Check is stranded; with
    a ground lever in c002, the ride reaches it."""
    stranded = TP.reachability(_zone(rail=False, far_reward=89100005))
    assert any("['c005'] are not reachable at all" in e
               for e in stranded.errors), stranded.errors
    ridden = TP.reachability(_zone(far_reward=89100005))
    assert ridden.ok, ridden.errors
    assert "c005" in ridden.rooms


def test_a_ride_waits_for_the_control_that_commissions_it():
    """A control on the far side of its own span can never be reached
    first: the ride stays shut, and what is past it is stranded."""
    verdict = TP.reachability(_zone(far_reward=89100005,
                                    control_room_id="c005"))
    assert not verdict.ok
    assert "c005" not in verdict.rooms


def test_a_span_with_no_control_ships_commissioned():
    assert TP.reachability(_zone(far_reward=89100005,
                                 control_room_id=None)).ok


def test_a_commissioned_ride_is_a_permanent_latch_under_its_handle():
    searched, gantry = TP._route_rails(_zone(control_placement="gantry"))
    (latch,) = [v for v in searched.zone_state
                if v.variable_id == "yard/span_out"]
    assert latch.lifetime == "permanent"
    assert latch.setter.room_id == "c002"
    assert latch.setter.capability == "grapple"
    assert gantry == {"rail:yard/s2s5"}


# --- step 2: beyond a gantry, local rewards only --------------------------------

def test_a_gantry_is_a_gate_the_ap_logic_must_declare():
    """Without the grapple, a Check past the gantry is stranded -- by a
    gate the AP logic does not declare, and said so. Declared, it is as
    visible to that logic as any gate, and the Zone is sound."""
    undeclared = TP.reachability(_zone(control_placement="gantry",
                                       far_reward=89100005))
    assert not undeclared.ok
    assert any("c005" in e and "declare" in e for e in undeclared.errors), \
        undeclared.errors
    declared = TP.reachability(_zone(control_placement="gantry",
                                     far_reward=89100005),
                               declared_capabilities={"grapple"})
    assert declared.ok, declared.errors


_HERE = {"capability": "grapple", "location_id": 89100001,
         "room_id": "c001"}


def test_no_check_beyond_a_gantry_opened_by_this_zone_s_own_grapple():
    """D-03: the Zone hands the grapple over (its featured acquisition),
    so the ride is crossable -- and the AP logic still cannot see that a
    Check past it needs the grapple. Refused by name."""
    verdict = TP.reachability(_zone(control_placement="gantry",
                                    far_reward=89100005, featured=_HERE))
    assert any("Check-bearing room 'c005' lies beyond gantry" in e
               and "D-03" in e for e in verdict.errors), verdict.errors


def test_beyond_a_gantry_local_rewards_only_is_sound():
    """The same Zone with nothing AP-relevant past the gantry: the ride
    is taken, the room is reached, and nothing is refused."""
    verdict = TP.reachability(_zone(control_placement="gantry",
                                    featured=_HERE))
    assert verdict.ok, verdict.errors
    assert "c005" in verdict.rooms


def test_a_ground_lever_imposes_nothing_ap_can_miss():
    """The rule is the gantry's: a ground ride needs only the base kit,
    so a Check past it is an ordinary Check."""
    assert TP.reachability(_zone(far_reward=89100005, featured=_HERE)).ok

