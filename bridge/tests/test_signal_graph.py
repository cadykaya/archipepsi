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


def _zone(graphs=None, edges=None) -> Zone:
    body = {
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [_room("c001"), _room("c002")],
    }
    if graphs is not None:
        body["room_graphs"] = graphs
    if edges is not None:
        body["edges"] = edges
    return TypeAdapter(Zone).validate_python(body)


def _edge(**over) -> dict:
    base = {"edge_id": "e_c001_c002", "room_a": "c001", "room_b": "c002"}
    base.update(over)
    return base


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


# --------------------------------------------------------------------------
# P14 — the chain on a route, and what it may cost the player.
#
# Prod named this half in 5124695: "Putting a graph on the route needs the
# declaration to carry the gate, and that is a schema change with Dess's
# half in it." The gate goes on the EDGE, because reachability reads
# edges; the Zone ties it to the actuator so neither end can exist alone.
# --------------------------------------------------------------------------

_COMPOSED: list = []


def composed() -> Zone:
    """The really-composed Zone, built once.

    A hand-built body cannot carry these cases: a `JOINED` edge must be
    named by two door assignments, and inventing a pair here would be
    inventing the layout the composer produces.
    """
    if not _COMPOSED:
        from archipepsi_bridge.playtest import played_zone
        zone = played_zone()
        assert zone is not None, "the composition path produced no Zone"
        _COMPOSED.append(zone)
    return _COMPOSED[0]


def gated(zone: Zone, *, requires_class="MEDIUM", actuator="service_shutter",
          graph_room=None, edge_index=0, opened_by=None) -> Zone:
    """Re-validate a composed Zone whose first edge a machine opens.

    `Zone.model_validate`, never `model_copy`: a copy skips every
    validator, and a test that skipped them would be asserting that a
    dictionary can hold a key.
    """
    raw = zone.model_dump()
    edge = raw["edges"][edge_index]
    room = edge["room_a"] if graph_room is None else graph_room
    raw["room_graphs"] = [{
        "room_id": room,
        "sensors": [{"node_id": "recess_plate", "kind": "PRESSURE_PLATE",
                     "requires_class": requires_class}],
        "nodes": [{"node_id": "inverted", "kind": "NOT",
                   "inputs": ["recess_plate"]}],
        "actuators": [{"actuator_id": actuator, "driven_by": "inverted"}],
    }]
    edge["opened_by"] = actuator if opened_by is None else opened_by
    return Zone.model_validate(raw)


def test_a_medium_plate_may_gate_a_route():
    """The base kit solves it: the player weighs 80 kg, which is MEDIUM,
    so standing on the plate is the whole interaction."""
    zone = gated(composed())
    edge = zone.edges[0]
    assert edge.opened_by == "service_shutter"
    assert edge.capability is None, (
        "a machine in the room is operable from inside the room, so it "
        "imposes no ordering on the multiworld and needs no capability")


def test_a_heavy_plate_may_not_gate_a_route():
    """And the refusal says why, rather than inventing a prerequisite.

    `HEAVY` starts at 120 kg. The player is 80 and §10.3 caps what they
    carry at 60, so satisfying it needs a pushed object and therefore a
    qualified manipulation provider. `graph.Capability` deliberately
    cannot name that, so the honest answer is that this chain may not
    gate a route -- not that it gates one on something unwritable.
    """
    with pytest.raises(ValidationError) as e:
        gated(composed(), requires_class="HEAVY")
    text = str(e.value)
    assert "demands HEAVY" in text
    assert "manipulation provider" in text
    assert "class the base kit can load" in text


def test_the_heavy_chain_is_still_legal_when_it_gates_nothing():
    """It is the ROUTE that is refused, not the machine. The chain the
    room has run since EX50-033 keeps working as a machine in a room."""
    zone = _zone([_chain()])
    assert zone.room_graphs[0].sensors[0].requires_class == "HEAVY"
    assert all(e.opened_by is None for e in zone.edges)


def test_an_edge_opened_by_a_machine_nobody_declares_is_refused():
    with pytest.raises(ValidationError, match="no room graph declares"):
        gated(composed(), opened_by="ghost_shutter")


def test_a_machine_in_a_room_the_edge_does_not_touch_is_refused():
    """A door operated from elsewhere is a cross-room relationship, and
    those go through D-8's declared Zone state -- not through a room
    graph, which §19.7 rule 2 keeps room-local by construction."""
    zone = composed()
    edge = zone.edges[0]
    far = next(c.id for c in zone.chambers
               if c.id not in (edge.room_a, edge.room_b))
    with pytest.raises(ValidationError, match="does not touch|Zone state"):
        gated(zone, graph_room=far)


def test_a_gate_that_rests_closed_is_the_held_requirement_again():
    """The case the NOT chain never reaches, which is why it is written.

    Drive the shutter straight off the plate and it rests CLOSED: the
    player must stand on the plate to open the door and then walk
    through it, which is not one action. That is D-8 §11.2's held
    cross-room requirement wearing a room graph, and §19.2's answer is
    `LATCH`, which nothing implements.
    """
    raw = composed().model_dump()
    edge = raw["edges"][0]
    raw["room_graphs"] = [{
        "room_id": edge["room_a"],
        "sensors": [{"node_id": "recess_plate", "kind": "PRESSURE_PLATE",
                     "requires_class": "MEDIUM"}],
        "nodes": [],
        # Driven by the SENSOR, with no inversion in between.
        "actuators": [{"actuator_id": "service_shutter",
                       "driven_by": "recess_plate"}],
    }]
    edge["opened_by"] = "service_shutter"
    with pytest.raises(ValidationError) as e:
        Zone.model_validate(raw)
    text = str(e.value)
    assert "rests CLOSED" in text
    assert "LATCH" in text


def test_the_resting_value_counts_inversions_rather_than_guessing():
    """Two NOTs is an inversion of an inversion, which rests closed
    again -- so the check has to count them, not look for the word."""
    from archipepsi_bridge.schemas import signal_graph as G
    one = G.RoomGraph.model_validate(_chain())
    assert G.resting_output(one, "service_shutter") is True
    two = G.RoomGraph.model_validate(_chain(nodes=[
        {"node_id": "inverted", "kind": "NOT", "inputs": ["recess_plate"]},
        {"node_id": "again", "kind": "NOT", "inputs": ["inverted"]}],
        actuators=[{"actuator_id": "service_shutter",
                    "driven_by": "again"}]))
    assert G.resting_output(two, "service_shutter") is False


def test_the_base_kit_derivation_is_arithmetic_not_opinion():
    """Both routes to a loaded plate, and neither reaches HEAVY."""
    from archipepsi_bridge.schemas import physics as PH
    assert PH.mass_class(PH.PLAYER_MASS_KG) == "MEDIUM"
    assert PH.mass_class(PH.CARRY_MASS_KG) == "MEDIUM"
    assert PH.mass_class(PH.MASS_MEDIUM_BELOW) == "HEAVY"
    assert PH.base_kit_can_satisfy("MEDIUM")
    assert not PH.base_kit_can_satisfy("HEAVY")


def test_raising_the_carry_line_would_change_the_answer():
    """Sabotage: the refusal must follow the arithmetic, not a literal.

    If someone moved §10.3's line past 120 kg, a HEAVY plate WOULD be
    loadable by hand and this gate would become legal. The check has to
    notice that rather than refusing `HEAVY` by name.
    """
    from archipepsi_bridge.schemas import physics as PH
    original = PH.CARRY_MASS_KG
    try:
        PH.CARRY_MASS_KG = 200.0
        assert PH.base_kit_can_satisfy("HEAVY"), (
            "the derivation refuses HEAVY by name rather than by mass")
    finally:
        PH.CARRY_MASS_KG = original
    assert not PH.base_kit_can_satisfy("HEAVY")
