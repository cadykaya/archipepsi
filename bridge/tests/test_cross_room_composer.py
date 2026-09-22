"""D-8's composer path and its authoritative state-update path.

The owner's next-checkpoint ask: *"Dess supplies an actual composer path
that emits the declared relationship, plus the authoritative
state-update/save path"*, and *"test the real setter access and return
route, not just room membership or a directly assigned flag"*.

Everything here runs against `playtest.played_zone()` -- the Zone the
campaign engine really composes -- and the composer is handed that Zone
rather than a fixture standing in for one.
"""
import pytest
from pydantic import ValidationError

from archipepsi_bridge.cross_room import compose_zone_state
from archipepsi_bridge.schemas.protocol import ZoneProgress
from archipepsi_bridge.topology import reachability

_CACHE: list = []


def composed():
    if not _CACHE:
        from archipepsi_bridge.playtest import played_zone
        z = played_zone()
        assert z is not None
        _CACHE.append(z)
    return _CACHE[0]


def emitted():
    if len(_CACHE) < 2:
        composed()
        _CACHE.append(compose_zone_state(_CACHE[0]))
    return _CACHE[1]


# --------------------------------------------------------------------------
# The composer emits, and does not disturb what it was handed
# --------------------------------------------------------------------------

def test_the_composer_emits_a_relationship_onto_a_really_composed_zone():
    out = emitted()
    assert out.emitted, out.note
    assert len(out.zone.zone_state) == 1
    v = out.zone.zone_state[0]
    assert v.setter.room_id != v.readers[0].room_id


def test_the_relationship_actually_spans_the_zone():
    """Distinct rooms is the floor, not the goal. The consequence should
    be as far from the control as the Zone will validate."""
    out = emitted()
    order = [c.id for c in out.zone.chambers]
    v = out.zone.zone_state[0]
    apart = order.index(v.readers[0].room_id) - order.index(v.setter.room_id)
    assert apart >= 10, f"only {apart} rooms apart; that is barely cross-room"


def test_the_composer_gates_a_real_edge_of_the_composed_graph():
    """The gate has to be an edge this Zone actually has, or the
    relationship changes nothing about any route."""
    out = emitted()
    gated = [e for e in out.zone.edges if e.requires_state]
    assert len(gated) == 1
    v = out.zone.zone_state[0]
    assert gated[0].requires_state[0].variable_id == v.variable_id
    assert v.setter.room_id in gated[0].rooms


def test_the_emitted_zone_is_still_solvable():
    assert reachability(emitted().zone).ok


def test_the_composer_does_not_touch_the_zone_it_was_given():
    """Preserve the comparison and the review snapshots. The step is
    explicit precisely so default composition is byte-identical."""
    before = composed().model_dump_json()
    compose_zone_state(composed())
    assert composed().model_dump_json() == before
    assert composed().zone_state == ()


def _recomposed(n: int):
    """A smaller Zone built through the REAL composition path.

    `topology.compose_chain` + `topology.apply` is how a chain Zone gets
    its edges, doors and arrive/depart refs. Slicing a finished Zone by
    hand instead leaves dangling edge references, which is a fixture
    defect rather than a finding -- and the validators say so.
    """
    from archipepsi_bridge import topology
    from archipepsi_bridge.schemas.zone import Zone
    base = composed()
    sub = base.model_copy(update={"chambers": base.chambers[:n],
                                  "edges": (), "plugs": (),
                                  "rail_networks": ()})
    built = topology.apply(sub, topology.compose_chain(list(sub.chambers)))
    return Zone.model_validate(built.model_dump())


def test_nothing_is_hardcoded_the_rooms_come_from_the_zone():
    """*"Do not hardcode one scenario and call cross-room composition
    complete."*

    Two differently sized Zones, both really composed, produce
    relationships between different rooms -- and in each case the rooms
    are that Zone's own. A composer with a scenario baked into it would
    give the same answer twice or fail on the second.
    """
    big = emitted()
    small = compose_zone_state(_recomposed(8))
    assert small.emitted, small.note

    big_v, small_v = big.zone.zone_state[0], small.zone.zone_state[0]
    assert small_v.readers[0].room_id != big_v.readers[0].room_id, (
        "the consequence must follow the Zone, not a constant")

    for out, v in ((big, big_v), (small, small_v)):
        rooms = {c.id for c in out.zone.chambers}
        assert {v.setter.room_id, v.readers[0].room_id} <= rooms


def test_the_composer_declines_rather_than_emitting_something_broken():
    """A composer that could emit an unsolvable Zone would move the
    failure to whoever ran the seed."""
    out = compose_zone_state(_recomposed(3))
    assert not out.emitted
    assert "four rooms" in out.note, out.note


def test_a_second_pass_does_not_stack_a_second_relationship():
    once = emitted()
    twice = compose_zone_state(once.zone)
    assert not twice.emitted
    assert "already declares" in twice.note


# --------------------------------------------------------------------------
# The authoritative state-update path
# --------------------------------------------------------------------------

def _save_with(zone):
    """A campaign save holding this Zone, through the real transitions."""
    from archipepsi_bridge.schemas.protocol import CampaignSave
    from archipepsi_bridge.schemas.transitions import (
        accept_zone, enter_zone, start_generation)
    # THE PLAYTEST CAMPAIGN'S SCALE, not the 30-location prototype
    # default. `CampaignScale` defaults small on purpose, and a save at
    # that default refuses the Checks this composed Zone actually holds.
    from archipepsi_bridge.playtest import PLAYTEST_CONFIG
    from archipepsi_bridge.schemas.protocol import CampaignScale
    save = CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="P",
        scale=CampaignScale(
            location_count=PLAYTEST_CONFIG.location_count,
            zone_target_checks=PLAYTEST_CONFIG.zone_target_checks,
            zone_budget=PLAYTEST_CONFIG.zone_budget))
    save = start_generation(
        save, zone_id=zone.zone_id, target_game=zone.target_game,
        allocated_location_ids=tuple(sorted(
            {r for c in zone.chambers for r in c.reward_ids})))
    save = accept_zone(save, zone)
    return enter_zone(save, zone.zone_id)


def test_the_state_update_path_records_through_the_real_transition():
    from archipepsi_bridge.schemas.transitions import record_zone_state
    out = emitted()
    v = out.zone.zone_state[0]
    save = _save_with(out.zone)
    after = record_zone_state(save, out.zone.zone_id, v.variable_id,
                              v.states[1])
    rec = [z for z in after.zones if z.zone_id == out.zone.zone_id][0]
    assert rec.progress.macro(v.variable_id) == v.states[1]


def test_a_state_no_control_can_select_is_refused():
    """The refusal a latch analogy would miss. `states` is what the
    variable can HOLD; `selects` is what a player can PUT it in."""
    from archipepsi_bridge.schemas.zone import Zone
    from archipepsi_bridge.schemas.transitions import record_zone_state
    out = emitted()
    raw = out.zone.model_dump()
    # A control that can only ever lower it -- declared permanent, so the
    # lifetime rule is satisfied and only the SELECT rule can refuse.
    raw["zone_state"][0]["lifetime"] = "permanent"
    raw["zone_state"][0]["setter"]["selects"] = ["lowered"]
    one_way = Zone.model_validate(raw)
    save = _save_with(one_way)
    with pytest.raises(ValueError, match="no control can put"):
        record_zone_state(save, one_way.zone_id, "span_alignment", "stowed")


def test_an_undeclared_variable_is_refused():
    from archipepsi_bridge.schemas.transitions import record_zone_state
    out = emitted()
    save = _save_with(out.zone)
    with pytest.raises(ValueError, match="declares no Zone-state variable"):
        record_zone_state(save, out.zone.zone_id, "ghost", "on")


def test_a_state_the_variable_does_not_have_is_refused():
    from archipepsi_bridge.schemas.transitions import record_zone_state
    out = emitted()
    save = _save_with(out.zone)
    with pytest.raises(ValueError, match="has no state"):
        record_zone_state(save, out.zone.zone_id, "span_alignment", "melted")


def test_the_update_survives_a_save_reload_and_can_be_reversed():
    """Partial progress, then reversal -- through the save, not in memory."""
    from archipepsi_bridge.schemas.protocol import CampaignSave
    from archipepsi_bridge.schemas.transitions import record_zone_state
    out = emitted()
    v = out.zone.zone_state[0]
    save = record_zone_state(_save_with(out.zone), out.zone.zone_id,
                             v.variable_id, v.states[1])
    back = CampaignSave.model_validate_json(save.model_dump_json())
    rec = [z for z in back.zones if z.zone_id == out.zone.zone_id][0]
    assert rec.progress.macro(v.variable_id) == v.states[1]

    undone = record_zone_state(back, out.zone.zone_id, v.variable_id,
                               v.states[0])
    rec2 = [z for z in undone.zones if z.zone_id == out.zone.zone_id][0]
    assert rec2.progress.macro(v.variable_id) == v.states[0]
    assert rec2.progress.latched == (), (
        "a reversible variable must never have ridden the monotone set")


# --------------------------------------------------------------------------
# Real setter access, not room membership
# --------------------------------------------------------------------------

def test_the_return_route_is_searched_not_assumed():
    """*"Test the real setter access and return route, not just room
    membership or a directly assigned flag."*

    The emitted relationship is reversible, so the player must be able
    to get back to the control from every state the Zone can be in.
    `R subset E` over the macro component is what proves it, and the
    proof is destroyed by making the gate one-way -- which is the
    control that shows the assertion is not vacuous.
    """
    from archipepsi_bridge.schemas.zone import Zone
    out = emitted()
    assert reachability(out.zone).ok

    raw = out.zone.model_dump()
    raw["zone_state"][0]["lifetime"] = "permanent"
    raw["zone_state"][0]["setter"]["selects"] = ["lowered"]
    # and the gate now needs the state the player just left behind
    for e in raw["edges"]:
        if e["requires_state"]:
            e["requires_state"] = [{"variable_id": "span_alignment",
                                    "state": "stowed"}]
    trap = Zone.model_validate(raw)
    assert not reachability(trap).ok, (
        "a one-way control that shuts the route behind the player has to "
        "be caught by the search, not by reading the declaration")


# --------------------------------------------------------------------------
# The composer's reachability validation, given a case that fails it.
#
# A sabotage run exposed this as vacuous: removing `if reach.ok` from the
# composer left all fourteen controls green, because on a Zone with no
# featured acquisition every candidate is solvable and the check never
# fires. A guarantee nothing can falsify is not a guarantee.
# --------------------------------------------------------------------------

def _featuring(capability: str = "grapple"):
    """A really composed Zone that grants a capability in an early room."""
    from archipepsi_bridge.schemas.zone import Zone
    z = _recomposed(8)
    # `reward_ids` is a property over `reward_location_id` and the
    # additional ids, so it is read off the MODEL; the dump has the
    # fields it is computed from, not the property.
    host = next(c for c in z.chambers if c.reward_ids)
    raw = z.model_dump()
    raw["featured_acquisition"] = {
        "capability": capability,
        "location_id": host.reward_ids[0],
        "room_id": host.id,
    }
    return Zone.model_validate(raw)


def test_the_composer_reads_the_setters_cost_off_the_featured_acquisition():
    """Correction 2 reaching the composer: if the Zone grants a
    capability, the control it composes is the one you need it for --
    Blindside's gantry, overhead and out of reach."""
    out = compose_zone_state(_featuring(),
                             declared_capabilities=["grapple"])
    assert out.emitted, out.note
    assert out.zone.zone_state[0].setter.capability == "grapple"
    assert "needing 'grapple'" in out.note


def test_the_composer_declines_when_nothing_could_open_the_gate():
    """THE CASE THAT MAKES `if reach.ok` DO SOMETHING.

    Same Zone, same relationship, but the capability the control needs
    is not one the run is guaranteed. The gate would then be a route
    nothing opens, so the composer must refuse to emit rather than hand
    the seed out and let the player find it.
    """
    out = compose_zone_state(_featuring())
    assert not out.emitted, (
        "a control needing a capability the run has not got opens no gate; "
        "emitting it would move the failure to whoever ran the seed")
    assert "no placement validated" in out.note
    assert out.zone.zone_state == ()


def test_the_two_differ_only_in_what_the_run_is_guaranteed():
    """The pair, side by side, so neither can drift into passing for a
    reason that has nothing to do with the capability."""
    zone = _featuring()
    assert compose_zone_state(zone).emitted is False
    assert compose_zone_state(
        zone, declared_capabilities=["grapple"]).emitted is True
