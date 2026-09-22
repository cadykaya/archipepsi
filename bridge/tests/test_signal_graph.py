"""P14 first slice — the chain that already runs, declared.

`unweighted_switch.gd` wires a HEAVY `ClassPlate` through `not
satisfied` into `ServiceShutter.command()`. That is a sensor, a §19.2
`NOT`, and an actuator, hard-coded in GDScript. Naming it here is what
lets a Zone ask for it.

Everything else in §19.2's eleven and §20's eighteen is named and
refused -- P14.5's "keep unsupported nodes unoffered", and the rule this
project applies to Statuses, Gear and enemy roles alike.
"""
from __future__ import annotations

import pytest
from pydantic import TypeAdapter, ValidationError

from archipepsi_bridge.schemas import signal_graph as G
from archipepsi_bridge.schemas.zone import Zone


def _chain(**over) -> dict:
    """The real chain: HEAVY plate -> NOT -> shutter."""
    base = {
        "room_id": "c001",
        "sensors": [{"node_id": "recess_plate", "kind": "PRESSURE_PLATE",
                     "requires_class": "HEAVY"}],
        "nodes": [{"node_id": "inverted", "kind": "NOT",
                   "inputs": ["recess_plate"]}],
        "actuators": [{"actuator_id": "service_shutter",
                       "driven_by": "inverted"}],
    }
    base.update(over)
    return base


def _room(rid: str) -> dict:
    return {"id": rid, "type": "arena", "width": 16.0, "depth": 15.0,
            "wall_height": 5.0, "objective": "kill_all",
            "reward_location_id": 89100001 if rid == "c001" else None,
            "enemies": [{"archetype": "melee", "count": 1}]}


def _zone(graphs=None) -> Zone:
    body = {
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [_room("c001"), _room("c002")],
    }
    if graphs is not None:
        body["room_graphs"] = graphs
    return TypeAdapter(Zone).validate_python(body)


# --------------------------------------------------------------------------
# The chain that exists
# --------------------------------------------------------------------------

def test_the_chain_the_room_already_runs_is_declarable():
    graph = G.RoomGraph.model_validate(_chain())
    assert graph.sensors[0].kind == "PRESSURE_PLATE"
    assert graph.sensors[0].requires_class == "HEAVY"
    assert graph.nodes[0].kind == "NOT"
    assert graph.actuators[0].driven_by == "inverted"


def test_a_zone_can_ask_for_it():
    zone = _zone([_chain()])
    assert zone.room_graphs[0].room_id == "c001"


def test_a_graph_in_a_room_the_zone_lacks_is_refused():
    with pytest.raises(ValidationError, match="does not have"):
        _zone([_chain(room_id="c404")])


def test_one_graph_per_room():
    with pytest.raises(ValidationError, match="two signal graphs"):
        _zone([_chain(), _chain()])


# --------------------------------------------------------------------------
# Unsupported is named, not offered
# --------------------------------------------------------------------------

def test_every_other_node_kind_is_named_and_refused():
    """§19.2's eleven exist in the vocabulary; one is implemented."""
    from typing import get_args
    named = set(get_args(G.NodeKind))
    assert len(named) == 11
    assert set(G.SUPPORTED_NODE_KINDS) == {"NOT"}
    for kind in named - {"NOT"}:
        with pytest.raises(ValueError, match="no runtime implements"):
            G.refuse_unsupported_node(kind)


def test_every_other_sensor_kind_is_named_and_refused():
    from typing import get_args
    named = set(get_args(G.SensorKind))
    assert len(named) == 18
    for kind in named - set(G.SUPPORTED_SENSOR_KINDS):
        with pytest.raises(ValueError, match="no runtime implements"):
            G.refuse_unsupported_sensor(kind)


def test_a_typo_and_a_gap_get_different_answers():
    """A single message would make a misspelling read like a feature
    request, which is how one becomes the other."""
    with pytest.raises(ValueError, match="not one of §19.2's eleven"):
        G.refuse_unsupported_node("NAND")
    with pytest.raises(ValueError, match="no runtime implements"):
        G.refuse_unsupported_node("AND")


def test_an_unsupported_node_cannot_be_smuggled_through_a_graph():
    with pytest.raises(ValidationError, match="no runtime implements"):
        G.RoomGraph.model_validate(_chain(
            nodes=[{"node_id": "both", "kind": "AND",
                    "inputs": ["recess_plate", "recess_plate"]}]))


# --------------------------------------------------------------------------
# The structural guarantees
# --------------------------------------------------------------------------

def test_a_cycle_cannot_be_written_down():
    """§19.3 evaluates in topological order. Declaration order IS that
    order, so a node may only name something already declared and a
    cycle has nowhere to be expressed."""
    with pytest.raises(ValidationError, match="not declared before it"):
        G.RoomGraph.model_validate(_chain(nodes=[
            {"node_id": "a", "kind": "NOT", "inputs": ["b"]},
            {"node_id": "b", "kind": "NOT", "inputs": ["a"]}]))


def test_nothing_in_a_graph_can_point_outside_its_own_room():
    """§19.7 rule 2 holds STRUCTURALLY rather than by inspection, and it
    is refused TWICE over.

    A qualified reference like `c002/other_plate` never reaches the
    graph check: the node-ref pattern has no `/` in it, so a cross-room
    name is not a thing this schema can hold. An unqualified name that
    happens to be another room's node is caught by the second rule --
    inputs may only name nodes declared earlier in THIS graph.

    Both are asserted, because the first is the one a reader would
    assume and the second is the one that actually does the work if the
    charset ever widens.
    """
    with pytest.raises(ValidationError):
        G.RoomGraph.model_validate(_chain(nodes=[
            {"node_id": "inverted", "kind": "NOT",
             "inputs": ["c002/other_plate"]}]))
    with pytest.raises(ValidationError, match="not declared before it"):
        G.RoomGraph.model_validate(_chain(nodes=[
            {"node_id": "inverted", "kind": "NOT",
             "inputs": ["other_rooms_plate"]}]))


def test_an_actuator_must_be_driven_by_a_node_this_room_declares():
    with pytest.raises(ValidationError, match="does not declare"):
        G.RoomGraph.model_validate(_chain(
            actuators=[{"actuator_id": "shutter", "driven_by": "elsewhere"}]))


def test_a_not_takes_exactly_one_input():
    with pytest.raises(ValidationError, match="exactly one"):
        G.RoomGraph.model_validate(_chain(nodes=[
            {"node_id": "inverted", "kind": "NOT",
             "inputs": ["recess_plate", "recess_plate"]}]))


def test_a_plate_that_demands_nothing_is_refused():
    """§20.1's sensor reads a semantic class. A plate with no class is
    satisfied by anything, which is not a puzzle."""
    with pytest.raises(ValidationError, match="demands nothing"):
        G.RoomGraph.model_validate(_chain(sensors=[
            {"node_id": "recess_plate", "kind": "PRESSURE_PLATE"}]))


def test_the_plate_reads_a_class_and_not_a_mass():
    """§20.6, and it is the distinction the two implemented mass sensors
    differ by: a PRESSURE_PLATE reads semantic class and never
    accumulates; WEIGHT_THRESHOLD sums kilograms and is the only sensor
    that does. Only the first is offered."""
    field = G.SensorNode.model_fields["requires_class"]
    assert "WEIGHT_THRESHOLD" not in G.SUPPORTED_SENSOR_KINDS
    graph = G.RoomGraph.model_validate(_chain())
    assert graph.sensors[0].requires_class in ("LIGHT", "MEDIUM", "HEAVY")
    assert field is not None


def test_a_zone_declaring_no_graphs_is_unchanged():
    assert _zone().room_graphs == ()
