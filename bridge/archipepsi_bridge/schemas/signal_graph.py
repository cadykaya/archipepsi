"""P14 — the room signal graph, declared for a chain that already runs.

Design 1 §19: an acyclic typed graph, eleven node types, evaluated in
topological order within one tick. Amalgam §20: eighteen sensor types.
Amalgam §19.7: **room graphs read macro state and never write it**, and
the machine layer has no logic nodes at all -- so everything here is
room-local by construction and there is no channel through which one
room could address another.

**THE FIRST SLICE IS ONE REAL CHAIN, NOT THE CATALOGUE.** P14.5 says a
framework no current room uses is not the package's completion, so this
declares what `unweighted_switch.gd` actually runs today:

    ClassPlate (semantic HEAVY) --> NOT --> ServiceShutter.command()

Three nodes, one sensor, one logic node, one actuator, wired in GDScript
as a signal handler. Naming it here is what lets a Zone ASK for that
chain instead of a scenario hard-coding it -- the same move
`RailNetwork` made for the railway.

**Everything else is named and refused.** `NODE_KINDS` is §19.2's
complete eleven and `SENSOR_KINDS` is §20's eighteen, because a
vocabulary with holes in it cannot tell "not supported yet" from "not a
thing"; `SUPPORTED_NODE_KINDS` and `SUPPORTED_SENSOR_KINDS` are what a
Zone may actually use, and they are small on purpose. Broadening them is
one edit per node once its runtime exists -- the rule this project keeps
arriving at, applied before the first mistake instead of after it.
"""
from __future__ import annotations

from typing import Annotated, Literal, get_args

from pydantic import BaseModel, ConfigDict, Field, model_validator


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


_ID = Field(min_length=1, max_length=32, pattern=r"^[a-z0-9_]+$")

#: A node id as a tuple ELEMENT. `test_epsilon_vocabulary` refuses a bare
#: `tuple[str, ...]` here and it is right to: an input that resolves to a
#: node is not prose, and left free Epsilon could name anything at all --
#: including something outside this room, which is the one thing the
#: graph must never be able to say.
_NODE_REF = Annotated[str, Field(min_length=1, max_length=32,
                                 pattern=r"^[a-z0-9_]+$")]

#: §19.2's complete eleven. The set, not a subset.
NodeKind = Literal[
    "DIRECT", "AND", "OR", "NOT", "TIMER", "LATCH",
    "SEQUENCE", "COUNTER", "SELECTOR", "DELAY", "THRESHOLD",
]

#: Amalgam §20's eighteen. Design 1's nine plus nine from D2/D3/D5.
SensorKind = Literal[
    "PRESSURE_PLATE", "PULSE_BUTTON", "TIMED_BUTTON", "LEVER",
    "SHOOTABLE_TARGET", "OBJECT_SOCKET", "PROXIMITY_SENSOR",
    "ENCOUNTER_CLEAR", "HACK_TERMINAL",
    "WEIGHT_THRESHOLD", "CONSTRAINT_STATE", "ATTACH_SENSOR",
    "MACRO_STATE", "MACRO_SELECTOR", "ROOM_VISITED",
    "STATUS_SENSOR", "STATUS_VOLUME_SENSOR", "COMPOUND_SENSOR",
]

#: What a Zone may use today. **`NOT` alone**, because `NOT` is the only
#: logic node the one chain that exists runs.
SUPPORTED_NODE_KINDS: tuple[str, ...] = ("NOT",)

#: **`PRESSURE_PLATE` alone**, and §20.6's distinction is the reason it
#: is worth naming: a `PRESSURE_PLATE` reads a semantic `MassClass` and
#: NEVER accumulates -- three `LIGHT` never make a `MEDIUM` -- while
#: `WEIGHT_THRESHOLD` sums kilograms and is the only sensor that does.
#: `class_plate.gd` implements the first and `PoweredLink` the second;
#: only the first is offered, because only the first is what the
#: declared chain uses.
SUPPORTED_SENSOR_KINDS: tuple[str, ...] = ("PRESSURE_PLATE",)

#: Actuator operations a node may drive. One, for the same reason.
SUPPORTED_ACTUATOR_OPS: tuple[str, ...] = ("command",)

for _k in SUPPORTED_NODE_KINDS:
    assert _k in get_args(NodeKind), f"{_k} is supported but not a node kind"
for _k in SUPPORTED_SENSOR_KINDS:
    assert _k in get_args(SensorKind), f"{_k} is supported but not a sensor"


def refuse_unsupported_node(kind: str) -> None:
    """A named node with no runtime is refused, not offered.

    Two different answers on purpose: a kind §19.2 does not define is a
    typo, and a kind it defines that nothing implements is a gap. A
    single message would make the first read like the second, which is
    how a misspelling becomes a feature request.
    """
    if kind not in get_args(NodeKind):
        raise ValueError(
            f"'{kind}' is not one of §19.2's eleven node types: "
            f"{sorted(get_args(NodeKind))}")
    if kind not in SUPPORTED_NODE_KINDS:
        raise ValueError(
            f"node '{kind}' is named by §19.2 and no runtime implements "
            f"it; supported today: {sorted(SUPPORTED_NODE_KINDS)}")


def refuse_unsupported_sensor(kind: str) -> None:
    if kind not in get_args(SensorKind):
        raise ValueError(
            f"'{kind}' is not one of §20's eighteen sensor types")
    if kind not in SUPPORTED_SENSOR_KINDS:
        raise ValueError(
            f"sensor '{kind}' is named by §20 and no runtime implements "
            f"it; supported today: {sorted(SUPPORTED_SENSOR_KINDS)}")


class SensorNode(Strict):
    """A source. Produces a value; reads nothing from the graph."""
    node_id: str = _ID
    kind: SensorKind
    #: For `PRESSURE_PLATE`, the semantic class it demands. The plate
    #: never accumulates, so this is a class name and not a mass.
    requires_class: Literal["LIGHT", "MEDIUM", "HEAVY"] | None = None

    @model_validator(mode="after")
    def _the_runtime_has_this_sensor(self):
        refuse_unsupported_sensor(self.kind)
        if self.kind == "PRESSURE_PLATE" and self.requires_class is None:
            raise ValueError(
                f"sensor '{self.node_id}' is a PRESSURE_PLATE and names no "
                "class; a plate that demands nothing is satisfied by "
                "anything, which is not a puzzle and not §20.1's sensor")
        return self


class LogicNode(Strict):
    """One of §19.2's eleven, taking named inputs from earlier nodes."""
    node_id: str = _ID
    kind: NodeKind
    inputs: tuple[_NODE_REF, ...] = Field(min_length=1, max_length=4)

    @model_validator(mode="after")
    def _the_runtime_has_this_node(self):
        refuse_unsupported_node(self.kind)
        if self.kind == "NOT" and len(self.inputs) != 1:
            raise ValueError(
                f"node '{self.node_id}' is a NOT with {len(self.inputs)} "
                "inputs; §19.2 gives NOT exactly one")
        return self


class ActuatorBinding(Strict):
    """What a graph value drives. The machine, named, in this room."""
    actuator_id: str = _ID
    #: The node whose output commands it.
    driven_by: str = _ID
    operation: str = Field(default="command", min_length=1, max_length=24,
                           pattern=r"^[a-z_]+$")

    @model_validator(mode="after")
    def _the_runtime_has_this_operation(self):
        if self.operation not in SUPPORTED_ACTUATOR_OPS:
            raise ValueError(
                f"actuator '{self.actuator_id}' is driven by "
                f"'{self.operation}', which no runtime implements; "
                f"supported today: {sorted(SUPPORTED_ACTUATOR_OPS)}")
        return self


def resting_output(graph, actuator_id: str) -> bool:
    """What an actuator reads with nothing touching the room.

    Every supported sensor is FALSE at rest -- a `PRESSURE_PLATE` with
    nothing on it -- and the one supported logic node is `NOT`, so the
    resting value of any chain is decided by how many inversions stand
    between the sensor and the machine. Counting them is the whole
    computation, and it is exact rather than approximate because the
    supported vocabulary is two entries wide.

    **Why anything cares.** An actuator that gates a route and rests
    CLOSED is a door the player has to hold open. The base-kit way to
    load a plate is to stand on it, and standing on a plate and walking
    through a doorway are not simultaneous -- which is D-8 §11.2's
    held cross-room requirement arriving in a room graph. `LATCH` is
    §19.2's answer and nothing implements it yet.
    """
    by_id = {n.node_id: n for n in graph.nodes}
    binding = next(a for a in graph.actuators if a.actuator_id == actuator_id)
    value = False           # every supported sensor rests false
    at = binding.driven_by
    seen = 0
    while at in by_id and seen <= len(by_id):
        node = by_id[at]
        if node.kind == "NOT":
            value = not value
        at = node.inputs[0]
        seen += 1
    return value


class RoomGraph(Strict):
    """One room's signal graph. Acyclic, room-local, evaluated in a tick.

    **It cannot reach another room, and not because a rule forbids it.**
    Every input names a node of this graph, so there is nothing an edge
    could point at outside it -- §19.7's rule 2 holds structurally
    rather than by inspection, which is what keeps the forbidden global
    signal bus unwritable rather than merely banned.
    """
    room_id: str = Field(min_length=1, max_length=24,
                         pattern=r"^[a-z0-9_]+$")
    sensors: tuple[SensorNode, ...] = Field(min_length=1, max_length=8)
    nodes: tuple[LogicNode, ...] = Field(default=(), max_length=8)
    actuators: tuple[ActuatorBinding, ...] = Field(min_length=1, max_length=8)

    @model_validator(mode="after")
    def _every_input_names_an_earlier_node_and_the_graph_is_acyclic(self):
        seen: set[str] = set()
        for sensor in self.sensors:
            if sensor.node_id in seen:
                raise ValueError(f"two nodes are both '{sensor.node_id}'")
            seen.add(sensor.node_id)
        # DECLARATION ORDER IS TOPOLOGICAL ORDER, and that is what makes
        # the graph acyclic by construction rather than by a search: a
        # node may only name something already declared, so a cycle has
        # no way to be written down. §19.3 evaluates in topological
        # order; this is the same order, fixed at declaration.
        for node in self.nodes:
            if node.node_id in seen:
                raise ValueError(f"two nodes are both '{node.node_id}'")
            missing = [i for i in node.inputs if i not in seen]
            if missing:
                raise ValueError(
                    f"node '{node.node_id}' takes input from {missing}, "
                    "which is not declared before it. Inputs name earlier "
                    "nodes only -- that is what makes the graph acyclic")
            seen.add(node.node_id)
        for binding in self.actuators:
            if binding.driven_by not in seen:
                raise ValueError(
                    f"actuator '{binding.actuator_id}' is driven by "
                    f"'{binding.driven_by}', which this room's graph does "
                    "not declare")
        return self
