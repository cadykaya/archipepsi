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
    """§19.2's eleven exist in the vocabulary; four are implemented."""
    from typing import get_args
    named = set(get_args(G.NodeKind))
    assert len(named) == 11
    # LATCH joined NOT once Prod's runtime evaluated it (D-10 answer); OR
    # joined once the runtime evaluated it for EX50-033's own chain
    # (O05-07), its first consumer; TIMER joined with EX50-021's window
    # (O05-07, second slice), its first.
    assert set(G.SUPPORTED_NODE_KINDS) == {"NOT", "LATCH", "OR", "TIMER"}
    for kind in named - {"NOT", "LATCH", "OR", "TIMER"}:
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


def gated(zone: Zone, *, requires_class="MEDIUM", counts_player=True,
          nodes=None, actuator="service_shutter", driven_by=None,
          graph_room=None, edge_index=0, opened_by=None) -> Zone:
    """Re-validate a composed Zone whose first edge a machine opens.

    The default is the chain D-10 chose: a plate that counts the player,
    a LATCH, the shutter. `Zone.model_validate`, never `model_copy`: a
    copy skips every validator, and a test that skipped them would be
    asserting that a dictionary can hold a key.
    """
    raw = zone.model_dump()
    edge = raw["edges"][edge_index]
    room = edge["room_a"] if graph_room is None else graph_room
    chain = ([{"node_id": "held", "kind": "LATCH", "inputs": ["recess_plate"]}]
             if nodes is None else nodes)
    raw["room_graphs"] = [{
        "room_id": room,
        "sensors": [{"node_id": "recess_plate", "kind": "PRESSURE_PLATE",
                     "requires_class": requires_class,
                     "counts_player": counts_player}],
        "nodes": chain,
        "actuators": [{"actuator_id": actuator,
                       "driven_by": (driven_by if driven_by is not None
                                     else (chain[-1]["node_id"] if chain
                                           else "recess_plate"))}],
    }]
    edge["opened_by"] = actuator if opened_by is None else opened_by
    return Zone.model_validate(raw)


_NOT = [{"node_id": "inverted", "kind": "NOT", "inputs": ["recess_plate"]}]


def test_the_chosen_chain_may_open_a_route():
    """D-10's option B: step on a plate that counts the player, once,
    and the latch holds the shutter open. No capability on the edge --
    the guaranteed base kit is the whole requirement."""
    zone = gated(composed())
    edge = zone.edges[0]
    assert edge.opened_by == "service_shutter"
    assert edge.capability is None


def test_an_object_only_plate_may_not_open_a_route_whatever_the_player_weighs():
    """THE OWNER'S LINE: the player's mass alone is not evidence that an
    object-only plate accepts them.

    80 kg is MEDIUM, and the plate demands MEDIUM, and it still does not
    count: `ClassPlate` skips the player unless told otherwise. An
    earlier revision of this file asserted the opposite -- that a MEDIUM
    plate was base kit because of what the player weighs -- which was a
    claim about an interaction the runtime refuses. Replaced, not
    loosened.
    """
    with pytest.raises(ValidationError) as e:
        gated(composed(), counts_player=False)
    text = str(e.value)
    assert "object-only" in text and "whatever they weigh" in text


def test_a_plate_that_counts_the_player_but_demands_more_than_they_weigh():
    with pytest.raises(ValidationError) as e:
        gated(composed(), requires_class="HEAVY")
    text = str(e.value)
    assert "demands HEAVY" in text and "MEDIUM" in text


def test_ex50_033s_object_only_chain_is_still_legal_as_a_machine_in_a_room():
    """It is the ROUTE that is refused, never the machine, and the
    default keeps the room exactly as it was."""
    zone = _zone([_chain()])
    sensor = zone.room_graphs[0].sensors[0]
    assert sensor.requires_class == "HEAVY"
    assert sensor.counts_player is False
    assert all(e.opened_by is None for e in zone.edges)


def test_only_a_plate_reads_bodies_so_only_a_plate_may_count_the_player():
    from archipepsi_bridge.schemas import signal_graph as SGm
    old = SGm.SUPPORTED_SENSOR_KINDS
    try:
        SGm.SUPPORTED_SENSOR_KINDS = ("PRESSURE_PLATE", "LEVER")
        with pytest.raises(ValidationError, match="only a plate reads bodies"):
            G.SensorNode.model_validate(
                {"node_id": "pull", "kind": "LEVER", "counts_player": True})
    finally:
        SGm.SUPPORTED_SENSOR_KINDS = old


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


# ---- the shapes a chain can take, and which of them a route may hang on

def test_a_plate_straight_to_the_shutter_is_the_held_requirement():
    """Closed at rest and closed again once the plate is left: the
    player would have to stand on it and walk through at once."""
    with pytest.raises(ValidationError) as e:
        gated(composed(), nodes=[])
    text = str(e.value)
    # D-07 retired the old advice, "put a LATCH between the plate and the
    # machine" (DESS-24): a permanent opening is a lever's, and a held
    # one needs a declared weight.
    assert "hold it open" in text and "needs a lever" in text
    assert "D-07" in text and "put a LATCH between" not in text


def test_a_not_chain_only_denies_and_may_still_gate():
    """Open at rest, closed only while loaded: it strands nobody,
    because the player can leave the plate alone."""
    zone = gated(composed(), nodes=_NOT)
    assert zone.edges[0].opened_by == "service_shutter"


def test_a_latch_after_an_inversion_shuts_the_way_for_good():
    """Open at rest, and the player's own step seals it permanently."""
    with pytest.raises(ValidationError) as e:
        gated(composed(), nodes=[
            {"node_id": "held", "kind": "LATCH", "inputs": ["recess_plate"]},
            {"node_id": "inverted", "kind": "NOT", "inputs": ["held"]}])
    assert "SHUT FOR GOOD" in str(e.value)


def test_a_latch_that_sets_when_the_room_is_built_is_refused_everywhere():
    """`plate -> NOT -> LATCH` latches on the first tick with nothing on
    the plate, which would record a decision no player made -- refused
    for any graph, route or not."""
    with pytest.raises(ValidationError, match="decision no player made"):
        G.RoomGraph.model_validate(_chain(
            nodes=[{"node_id": "inverted", "kind": "NOT",
                    "inputs": ["recess_plate"]},
                   {"node_id": "held", "kind": "LATCH",
                    "inputs": ["inverted"]}],
            actuators=[{"actuator_id": "service_shutter",
                        "driven_by": "held"}]))


def test_a_latch_takes_one_input_and_has_no_reset():
    with pytest.raises(ValidationError, match="exactly one"):
        G.LogicNode.model_validate(
            {"node_id": "held", "kind": "LATCH",
             "inputs": ["recess_plate", "other"]})


def test_the_three_phases_are_the_runtimes_order():
    """`phases` settles the way `signal_graph.gd` evaluates: sensors,
    then logic in declaration order, then actuators -- rest, pressed,
    released."""
    graph = G.RoomGraph.model_validate(_chain(
        sensors=[{"node_id": "recess_plate", "kind": "PRESSURE_PLATE",
                  "requires_class": "MEDIUM", "counts_player": True}],
        nodes=[{"node_id": "held", "kind": "LATCH",
                "inputs": ["recess_plate"]}],
        actuators=[{"actuator_id": "service_shutter", "driven_by": "held"}]))
    shape = G.phases(graph, "service_shutter")
    assert (shape["rest"], shape["pressed"], shape["released"]) == (
        False, True, True)
    assert shape["latched_at_rest"] == frozenset()


def test_the_resting_value_counts_inversions_rather_than_guessing():
    """Two NOTs is an inversion of an inversion, which rests closed
    again -- so the check has to count them, not look for the word."""
    one = G.RoomGraph.model_validate(_chain())
    assert G.resting_output(one, "service_shutter") is True
    two = G.RoomGraph.model_validate(_chain(nodes=[
        {"node_id": "inverted", "kind": "NOT", "inputs": ["recess_plate"]},
        {"node_id": "again", "kind": "NOT", "inputs": ["inverted"]}],
        actuators=[{"actuator_id": "service_shutter",
                    "driven_by": "again"}]))
    assert G.resting_output(two, "service_shutter") is False


def test_the_route_asks_about_its_own_plate_and_not_the_rooms_other_one():
    """A second chain in the same room -- EX50-033's object-only HEAVY
    plate running a scenery shutter -- is not the interaction the route
    depends on, and must not get the route refused."""
    raw = composed().model_dump()
    edge = raw["edges"][0]
    raw["room_graphs"] = [{
        "room_id": edge["room_a"],
        "sensors": [
            {"node_id": "step_plate", "kind": "PRESSURE_PLATE",
             "requires_class": "MEDIUM", "counts_player": True},
            {"node_id": "recess_plate", "kind": "PRESSURE_PLATE",
             "requires_class": "HEAVY"}],
        "nodes": [
            {"node_id": "held", "kind": "LATCH", "inputs": ["step_plate"]},
            {"node_id": "inverted", "kind": "NOT",
             "inputs": ["recess_plate"]}],
        "actuators": [
            {"actuator_id": "route_shutter", "driven_by": "held"},
            {"actuator_id": "service_shutter", "driven_by": "inverted"}],
    }]
    edge["opened_by"] = "route_shutter"
    zone = Zone.model_validate(raw)
    assert zone.edges[0].opened_by == "route_shutter"


# ---- the player, as the runtime reads them

def test_the_player_counts_only_where_the_plate_says_so():
    from archipepsi_bridge.schemas import physics as PH
    assert PH.mass_class(PH.PLAYER_MASS_KG) == "MEDIUM"
    for cls in ("LIGHT", "MEDIUM", "HEAVY"):
        assert PH.plate_accepts_player(cls, counts_player=False) is False
    assert PH.plate_accepts_player("LIGHT", counts_player=True)
    assert PH.plate_accepts_player("MEDIUM", counts_player=True)
    assert not PH.plate_accepts_player("HEAVY", counts_player=True)


def test_the_predicate_reads_the_flag_before_the_mass():
    """Sabotage, target confirmed: a version that compared classes first
    would answer MEDIUM-and-object-only with a yes."""
    import inspect
    from archipepsi_bridge.schemas import physics as PH
    src = inspect.getsource(PH.plate_accepts_player)
    body = src.split('"""')[-1]
    assert body.index("counts_player") < body.index("mass_class("), (
        "the class comparison runs before the flag, so the player's "
        "mass can answer for a plate that ignores the player")
    original = PH.PLAYER_MASS_KG
    try:
        PH.PLAYER_MASS_KG = 500.0      # a player heavier than any plate
        assert PH.plate_accepts_player("HEAVY", counts_player=False) is False
    finally:
        PH.PLAYER_MASS_KG = original


# --------------------------------------------------------------------------
# O05-07: PULSE_BUTTON and OR, through a real consumer -- EX50-033's chain
# --------------------------------------------------------------------------

_BUTTON = {"node_id": "bolt_lever", "kind": "PULSE_BUTTON"}
_PLATE = {"node_id": "recess_plate", "kind": "PRESSURE_PLATE",
          "requires_class": "HEAVY"}


def _ex50_033():
    from archipepsi_bridge.schemas.minors import CONTRACTS
    return CONTRACTS["minor_unweighted_switch"].graph


def test_the_minor_declares_its_own_chain_in_the_shared_vocabulary():
    """The room's hand-wired chain, now a declaration the schema checks:
    HEAVY plate -> NOT, bolt lever -> LATCH, both -> OR -> shutter."""
    graph = _ex50_033()
    assert isinstance(graph, G.RoomGraph)
    assert {s.kind for s in graph.sensors} == {"PRESSURE_PLATE",
                                               "PULSE_BUTTON"}
    assert [n.kind for n in graph.nodes] == ["NOT", "LATCH", "OR"]
    assert graph.actuators[0].driven_by == "open"


def test_a_minor_s_latches_are_exactly_its_contract_s():
    """A fired LATCH is recorded as `minor_<room>/<latch>`, which the
    bridge accepts only for the contract's latches -- so the graph may
    not name one the contract does not, nor miss one it does."""
    from archipepsi_bridge.schemas.minors import CONTRACTS
    graphs = 0
    for shell_id, contract in CONTRACTS.items():
        if contract.graph is None:
            continue
        graphs += 1
        latches = {n.node_id for n in contract.graph.nodes
                   if n.kind == "LATCH"}
        assert latches == set(contract.latches), shell_id
    assert graphs >= 1


def test_each_kind_joined_with_a_consumer_and_nothing_else_did():
    """OR and PULSE_BUTTON joined with EX50-033's chain; TIMER and
    SHOOTABLE_TARGET with EX50-021's. Nothing joined on its own."""
    assert set(G.SUPPORTED_NODE_KINDS) == {"NOT", "LATCH", "OR", "TIMER"}
    assert set(G.SUPPORTED_SENSOR_KINDS) == {"PRESSURE_PLATE",
                                             "PULSE_BUTTON",
                                             "SHOOTABLE_TARGET"}
    for kind in ("AND", "DIRECT", "SEQUENCE", "COUNTER", "DELAY"):
        with pytest.raises(ValueError, match="no runtime implements"):
            G.refuse_unsupported_node(kind)


def test_or_takes_two_to_four_inputs():
    with pytest.raises(ValidationError, match="two to four"):
        G.RoomGraph.model_validate(_chain(
            nodes=[{"node_id": "any", "kind": "OR",
                    "inputs": ["recess_plate"]}],
            actuators=[{"actuator_id": "s", "driven_by": "any"}]))
    with pytest.raises(ValidationError):
        G.RoomGraph.model_validate(_chain(
            nodes=[{"node_id": "any", "kind": "OR",
                    "inputs": ["recess_plate"] * 5}],
            actuators=[{"actuator_id": "s", "driven_by": "any"}]))


def test_a_pulse_cannot_feed_a_boolean_reader():
    """§19.1: a node reading a Boolean port sees OFF when a pulse
    occurred -- so an OR fed by a button would never fire. Refused at
    composition, which is where §19.1 says the mismatch fails."""
    with pytest.raises(ValidationError, match="produces a PULSE"):
        G.RoomGraph.model_validate(_chain(
            sensors=[_PLATE, _BUTTON],
            nodes=[{"node_id": "any", "kind": "OR",
                    "inputs": ["recess_plate", "bolt_lever"]}],
            actuators=[{"actuator_id": "s", "driven_by": "any"}]))
    with pytest.raises(ValidationError, match="produces a PULSE"):
        G.RoomGraph.model_validate(_chain(
            sensors=[_BUTTON],
            nodes=[{"node_id": "inverted", "kind": "NOT",
                    "inputs": ["bolt_lever"]}],
            actuators=[{"actuator_id": "s", "driven_by": "inverted"}]))


def test_a_pulse_cannot_drive_a_machine_by_itself():
    with pytest.raises(ValidationError, match="move for one tick"):
        G.RoomGraph.model_validate(_chain(
            sensors=[_BUTTON], nodes=[],
            actuators=[{"actuator_id": "s", "driven_by": "bolt_lever"}]))


def test_a_latch_is_set_by_a_pulse_and_still_by_a_plate():
    """§19.2's LATCH takes a pulse on `set`; the P14 slice's takes a
    plate's Boolean. Both, and neither resets."""
    G.RoomGraph.model_validate(_chain(
        sensors=[_BUTTON],
        nodes=[{"node_id": "bolt", "kind": "LATCH", "inputs": ["bolt_lever"]}],
        actuators=[{"actuator_id": "s", "driven_by": "bolt"}]))
    G.RoomGraph.model_validate(_chain(
        nodes=[{"node_id": "held", "kind": "LATCH",
                "inputs": ["recess_plate"]}],
        actuators=[{"actuator_id": "s", "driven_by": "held"}]))


def test_a_button_reads_no_class_and_counts_no_body():
    with pytest.raises(ValidationError, match="only a plate reads a mass"):
        G.SensorNode.model_validate({"node_id": "b", "kind": "PULSE_BUTTON",
                                     "requires_class": "HEAVY"})
    with pytest.raises(ValidationError, match="only a plate reads bodies"):
        G.SensorNode.model_validate({"node_id": "b", "kind": "PULSE_BUTTON",
                                     "counts_player": True})


def test_or_settles_as_any_of_its_inputs():
    graph = G.RoomGraph.model_validate(_chain(
        sensors=[_PLATE, {**_PLATE, "node_id": "other_plate"}],
        nodes=[{"node_id": "any", "kind": "OR",
                "inputs": ["recess_plate", "other_plate"]}],
        actuators=[{"actuator_id": "s", "driven_by": "any"}]))
    rest, _ = G.settle(graph, False)
    pressed, _ = G.settle(graph, True)
    assert (rest["any"], pressed["any"]) == (False, True)


def test_the_minor_s_chain_settles_the_way_the_room_behaves():
    """At rest the crate is parked, the plate is off and the crossing is
    open; the bolt, once pulled, holds it open for good."""
    graph = _ex50_033()
    rest, latched = G.settle(graph, False)
    assert rest["open"] is True and not latched
    _, latched = G.settle(graph, True)
    assert latched == {"bolt"}
    after, _ = G.settle(graph, False, latched)
    assert after["open"] is True and after["unloaded"] is True


def test_upstream_walks_every_input_and_a_chain_as_before():
    graph = _ex50_033()
    sensors, nodes = G.upstream(graph, "shutter")
    assert {s.node_id for s in sensors} == {"plate", "bolt_lever"}
    assert [n.node_id for n in nodes] == ["open", "unloaded", "bolt"]
    chain = G.RoomGraph.model_validate(_chain())
    sensors, nodes = G.upstream(chain, "service_shutter")
    assert [s.node_id for s in sensors] == ["recess_plate"]
    assert [n.node_id for n in nodes] == ["inverted"]


def test_a_zone_asks_only_for_what_its_builder_places():
    """`RoomGraphs` puts plates and levers down -- the lever is D-07's
    visibly permanent control (owner ruling, 2026-09-24; D13 1c). A shot
    target is run by the same runtime and placed only by a room that owns
    its machine, so a Zone may not ask the builder for one."""
    _zone([_chain(
        sensors=[_BUTTON],
        nodes=[{"node_id": "held", "kind": "LATCH",
                "inputs": ["bolt_lever"]}],
        actuators=[{"actuator_id": "s", "driven_by": "held"}])])
    with pytest.raises(ValidationError, match="Zone builder places"):
        _zone([_chain(
            sensors=[{"node_id": "mark", "kind": "SHOOTABLE_TARGET",
                      "mode": "PULSE"}],
            nodes=[{"node_id": "held", "kind": "LATCH",
                    "inputs": ["mark"]}],
            actuators=[{"actuator_id": "s", "driven_by": "held"}])])


def test_a_route_may_not_hang_on_an_or():
    """The route search and `phases` reason about one plate through NOT
    and LATCH. A route gate driven through an OR is refused by name
    rather than certified by arithmetic written for a single plate; the
    same OR as a machine in a room is legal."""
    with pytest.raises(ValidationError, match="certified only for"):
        gated(composed(), nodes=[
            {"node_id": "held", "kind": "LATCH", "inputs": ["recess_plate"]},
            {"node_id": "any", "kind": "OR",
             "inputs": ["held", "recess_plate"]}])
    zone = composed()
    raw = zone.model_dump()
    room = raw["chambers"][0]["id"]
    raw["room_graphs"] = [_chain(
        room_id=room,
        nodes=[{"node_id": "held", "kind": "LATCH",
                "inputs": ["recess_plate"]},
               {"node_id": "any", "kind": "OR",
                "inputs": ["held", "recess_plate"]}],
        actuators=[{"actuator_id": "lamp", "driven_by": "any"}])]
    assert Zone.model_validate(raw).room_graphs[0].nodes[-1].kind == "OR"


# --------------------------------------------------------------------------
# O05-07, second slice: SHOOTABLE_TARGET and TIMER, through EX50-021
# --------------------------------------------------------------------------

_TARGET = {"node_id": "receiver", "kind": "SHOOTABLE_TARGET",
           "mode": "PULSE"}


def _ex50_021():
    from archipepsi_bridge.schemas.minors import CONTRACTS
    return CONTRACTS["minor_counterfire_arcade"].graph


def _timed(duration=8.0, sensors=None, feed="receiver"):
    return _chain(
        sensors=sensors or [_TARGET],
        nodes=[{"node_id": "window", "kind": "TIMER", "inputs": [feed],
                "duration": duration}],
        actuators=[{"actuator_id": "s", "driven_by": "window"}])


def test_the_arcade_declares_its_own_chain():
    """EX50-021 §3, as a declaration: the receiver's pulse into an
    eight-second TIMER, the release lever into a LATCH, both into an OR
    that opens the shutter."""
    graph = _ex50_021()
    assert {s.node_id: s.kind for s in graph.sensors} == {
        "receiver": "SHOOTABLE_TARGET", "release_lever": "PULSE_BUTTON"}
    assert [(n.node_id, n.kind) for n in graph.nodes] == [
        ("window", "TIMER"), ("release", "LATCH"), ("open", "OR")]
    assert graph.nodes[0].duration == 8.0
    assert graph.actuators[0].driven_by == "open"


def test_the_arcade_settles_the_way_the_room_behaves():
    """Shut at rest; a hit opens it; the window is not a state the room
    rests in; the release holds it open for good."""
    graph = _ex50_021()
    rest, latched = G.settle(graph, False)
    assert rest["open"] is False and not latched
    hit, latched = G.settle(graph, True)
    assert hit["window"] is True and latched == {"release"}
    after, _ = G.settle(graph, False, latched)
    assert after["window"] is False and after["open"] is True


def test_a_timer_reads_a_pulse_and_nothing_else():
    """§19.2: TIMER takes 1 Pulse. A plate held down is a Boolean; fed to
    a TIMER it would restart on no tick at all."""
    G.RoomGraph.model_validate(_timed())
    with pytest.raises(ValidationError, match="reads PULSE"):
        G.RoomGraph.model_validate(_timed(sensors=[
            {"node_id": "recess_plate", "kind": "PRESSURE_PLATE",
             "requires_class": "HEAVY"}], feed="recess_plate"))


def test_a_timer_names_its_duration_and_only_a_timer_has_one():
    with pytest.raises(ValidationError, match="names no duration"):
        G.LogicNode.model_validate({"node_id": "w", "kind": "TIMER",
                                    "inputs": ["receiver"]})
    with pytest.raises(ValidationError, match="only a TIMER has one"):
        G.LogicNode.model_validate({"node_id": "n", "kind": "NOT",
                                    "inputs": ["plate"], "duration": 2.0})
    with pytest.raises(ValidationError, match="one pulse"):
        G.LogicNode.model_validate({"node_id": "w", "kind": "TIMER",
                                    "inputs": ["a", "b"], "duration": 2.0})
    for bad in (0.0, -1.0, G.TIMER_MAX_SECONDS + 1.0):
        with pytest.raises(ValidationError):
            G.RoomGraph.model_validate(_timed(duration=bad))


def test_a_timer_s_output_is_a_boolean_a_machine_can_follow():
    """The TIMER is what turns one pulse into a window a machine can be
    commanded by -- where a pulse alone would move it for one tick."""
    graph = G.RoomGraph.model_validate(_timed())
    assert G.output_form(graph, "window") == "BOOLEAN"
    with pytest.raises(ValidationError, match="move for one tick"):
        G.RoomGraph.model_validate(_chain(
            sensors=[_TARGET], nodes=[],
            actuators=[{"actuator_id": "s", "driven_by": "receiver"}]))


def test_a_target_names_its_mode_and_only_pulse_has_a_runtime():
    with pytest.raises(ValidationError, match="names no mode"):
        G.SensorNode.model_validate({"node_id": "t",
                                     "kind": "SHOOTABLE_TARGET"})
    with pytest.raises(ValidationError, match="no runtime implements TOGGLE"):
        G.SensorNode.model_validate({**_TARGET, "mode": "TOGGLE"})


def test_a_target_requires_ranged_as_a_floor_and_nothing_else():
    """§20.2's default is [RANGED], and every mandatory target has it. The
    runtime has no damage tags -- its SHOT path counts any hit -- so
    [RANGED] holds as a floor (a Static Pulse always operates it), and a
    target requiring MELEE or EXPLOSIVE, which a Static Pulse would
    operate anyway, is refused rather than approximated."""
    assert G.SensorNode.model_validate(_TARGET).required_tags is None
    G.SensorNode.model_validate({**_TARGET, "required_tags": ["RANGED"]})
    for tags in (["EXPLOSIVE"], ["MELEE"], ["RANGED", "MELEE"]):
        with pytest.raises(ValidationError, match="can be honoured"):
            G.SensorNode.model_validate({**_TARGET, "required_tags": tags})
    with pytest.raises(ValidationError):
        G.SensorNode.model_validate({**_TARGET, "required_tags": ["LASER"]})


def test_only_a_target_is_shot():
    for extra in ({"mode": "PULSE"}, {"required_tags": ["RANGED"]}):
        with pytest.raises(ValidationError, match="only a SHOOTABLE_TARGET"):
            G.SensorNode.model_validate({"node_id": "b",
                                         "kind": "PULSE_BUTTON", **extra})


def test_a_zone_may_not_ask_its_builder_for_a_target():
    """`RoomGraphs` places plates and levers; a target is placed by the
    room that owns its receiver."""
    with pytest.raises(ValidationError, match="Zone builder places"):
        _zone([_timed()])


def test_the_arcade_s_latch_is_its_contract_s_and_the_timer_is_not_saved():
    """§19.6: a LATCH is PUZZLE_LOCAL and a TIMER is EPHEMERAL. The only
    thing of this graph that can reach a save is the release, and it is
    exactly the contract's latch."""
    from archipepsi_bridge.schemas.minors import CONTRACTS
    contract = CONTRACTS["minor_counterfire_arcade"]
    kept = {n.node_id for n in contract.graph.nodes if n.kind == "LATCH"}
    assert kept == set(contract.latches) == {"release"}
