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

**O05-07 BROADENS IT THROUGH A REAL CONSUMER** -- EX50-033's own
chain, as the minor's occurrence contract declares it
(`schemas/minors.py`) and the room runs it through `SignalGraph`:

    ClassPlate (HEAVY) --> NOT ------------.
                                            OR --> ServiceShutter.command()
    bolt lever (PULSE_BUTTON) --> LATCH --'

So `PULSE_BUTTON` and `OR` join, and with them §19.1's PORT FORMS: a
button's output is a PULSE, which a Boolean reader sees as OFF, so a
node that reads Booleans refuses a pulse at composition rather than
quietly never seeing it.

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

#: What a Zone may use today: `NOT`, which the EX50-033 chain runs, and
#: `LATCH`, which Prod built in `signal_graph.gd` for D-10's option B.
#:
#: **`LATCH` is set by a true input and never reset in this slice.**
#: One input, no clear: the puzzle it exists for is "step on the plate
#: once and walk through", and a latch that could clear is a door that
#: can shut behind you. §5.4a persists the DECISION, so a set latch is
#: recorded (`transitions.record_latch`, under `graph_<room>`) and the
#: machine is rebuilt from the record rather than restored from itself.
SUPPORTED_NODE_KINDS: tuple[str, ...] = ("NOT", "LATCH", "OR", "TIMER")

#: **`PRESSURE_PLATE` alone**, and §20.6's distinction is the reason it
#: is worth naming: a `PRESSURE_PLATE` reads a semantic `MassClass` and
#: NEVER accumulates -- three `LIGHT` never make a `MEDIUM` -- while
#: `WEIGHT_THRESHOLD` sums kilograms and is the only sensor that does.
#: `class_plate.gd` implements the first and `PoweredLink` the second;
#: only the first is offered, because only the first is what the
#: declared chain uses.
SUPPORTED_SENSOR_KINDS: tuple[str, ...] = ("PRESSURE_PLATE", "PULSE_BUTTON",
                                          "SHOOTABLE_TARGET")

#: §20's `DamageTag`s, which a SHOOTABLE_TARGET's `required_tags` names.
DamageTag = Literal[
    "RANGED", "MELEE", "PROJECTILE", "BEAM", "EXPLOSIVE",
    "PHYSICS", "FIRE", "ENVIRONMENTAL",
]

#: **What a target's `required_tags` may say today: §20.2's default and
#: nothing else.** The runtime has no damage tags: `take_damage` carries
#: an amount, a direction and a knockback, and the SHOT path a target is
#: built on counts ANY hit (`ActivityElement.take_damage`: "Static
#: Pulse, an Echo hitscan, a projectile, a melee swing"). So `[RANGED]`
#: holds as a FLOOR -- every ranged hit operates it, and Static Pulse
#: suffices, which is §20.2's rule for a mandatory target -- but it is
#: not a filter: a swing or a blast operates it too. A target requiring
#: MELEE or EXPLOSIVE would be operated by a Static Pulse, which is the
#: opposite of what it says, so it is refused rather than approximated.
SUPPORTED_TARGET_TAGS: tuple[str, ...] = ("RANGED",)

#: O05-07. What a ZONE's own `room_graphs` may declare: the sensors the
#: Zone builder can PLACE. `RoomGraphs` puts a class plate down beside the
#: doorway its chain serves; a `PULSE_BUTTON` is evaluated by the same
#: runtime but placed only by a room that owns its machine -- EX50-033's
#: bolt lever -- so a Zone declaring one would be asking the builder for
#: something it cannot put down.
ZONE_PLACEABLE_SENSOR_KINDS: tuple[str, ...] = ("PRESSURE_PLATE",)

#: The chains a ROUTE gate may hang on: the shapes the route search and
#: the Zone validator reason about (D-10 §5, `phases`). A gate driven
#: through anything else is refused by name rather than certified by
#: arithmetic that was written for a single plate.
ROUTE_SENSOR_KINDS: tuple[str, ...] = ("PRESSURE_PLATE",)
ROUTE_NODE_KINDS: tuple[str, ...] = ("NOT", "LATCH")

#: §19.1: every port is one form. What each supported sensor PRODUCES.
SENSOR_OUTPUT_FORM: dict[str, str] = {
    "PRESSURE_PLATE": "BOOLEAN",
    "PULSE_BUTTON": "PULSE",
    # §20: "Pulse or Boolean", by `mode`. PULSE only today -- EX50-021's
    # receiver "emits one pulse per valid hit" -- and TOGGLE, the
    # Boolean, is refused until something reads it.
    "SHOOTABLE_TARGET": "PULSE",
}

#: What each supported node's inputs ACCEPT. Every one of them outputs a
#: Boolean (§19.2's table).
#:
#: `LATCH` takes §19.2's PULSE on `set`, and also the Boolean the P14
#: slice already feeds it -- a plate, "set by a true input" (D-10 option
#: B). Neither ever resets.
NODE_INPUT_FORMS: dict[str, tuple[str, ...]] = {
    "NOT": ("BOOLEAN",),
    "OR": ("BOOLEAN",),
    "LATCH": ("BOOLEAN", "PULSE"),
    # §19.2: "1 Pulse". A plate held down is not a pulse, and a TIMER fed
    # one would restart on no tick at all.
    "TIMER": ("PULSE",),
}

#: The longest `duration` a TIMER may declare: `ActivityPrimitive`'s own
#: `time_limit` ceiling, so no window outlasts the longest timed thing a
#: Zone already allows.
TIMER_MAX_SECONDS = 120.0

#: Actuator operations a node may drive. One, for the same reason.
SUPPORTED_ACTUATOR_OPS: tuple[str, ...] = ("command",)

for _k in SUPPORTED_NODE_KINDS:
    assert _k in get_args(NodeKind), f"{_k} is supported but not a node kind"
for _k in SUPPORTED_SENSOR_KINDS:
    assert _k in get_args(SensorKind), f"{_k} is supported but not a sensor"
    assert _k in SENSOR_OUTPUT_FORM, f"{_k} is supported and has no form"
for _k in SUPPORTED_NODE_KINDS:
    assert _k in NODE_INPUT_FORMS, f"{_k} is supported and reads nothing"


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
    #: Whether the PLAYER'S OWN BODY loads this plate. **False by default,
    #: and the default is EX50-033's arrangement preserved exactly:**
    #: *"the player's own mass class does not count toward its threshold
    #: in this arrangement."* `ClassPlate` skips the player unless told
    #: otherwise, and this is where it is told.
    #:
    #: **The player's mass is not evidence on its own.** An object-only
    #: plate does not accept a player however much the player weighs,
    #: and a route validator that reasoned "80 kg is MEDIUM, so the base
    #: kit loads a MEDIUM plate" about such a plate would be describing
    #: an interaction the runtime refuses. `physics.plate_accepts_player`
    #: reads this flag first for exactly that reason.
    counts_player: bool = False
    #: For `SHOOTABLE_TARGET`, §20's `mode: PULSE | TOGGLE`. Named, never
    #: defaulted: a target that pulses and one that toggles are different
    #: machines, and a silent default would pick one for the author.
    mode: Literal["PULSE", "TOGGLE"] | None = None
    #: For `SHOOTABLE_TARGET`, §20.2's `required_tags`, default `[RANGED]`.
    #: See `SUPPORTED_TARGET_TAGS` for why nothing else is accepted.
    required_tags: tuple[DamageTag, ...] | None = None

    @model_validator(mode="after")
    def _the_runtime_has_this_sensor(self):
        refuse_unsupported_sensor(self.kind)
        if self.kind == "SHOOTABLE_TARGET":
            if self.mode is None:
                raise ValueError(
                    f"sensor '{self.node_id}' is a SHOOTABLE_TARGET and "
                    "names no mode; §20 gives it PULSE or TOGGLE")
            if self.mode != "PULSE":
                raise ValueError(
                    f"sensor '{self.node_id}' is a {self.mode} target; no "
                    "runtime implements TOGGLE -- the one that exists "
                    "emits one pulse per valid hit (EX50-021 §3)")
            tags = self.required_tags or ("RANGED",)
            if tuple(tags) != SUPPORTED_TARGET_TAGS:
                raise ValueError(
                    f"sensor '{self.node_id}' requires {list(tags)}; the "
                    "runtime has no damage tags and counts any hit, so "
                    f"only {list(SUPPORTED_TARGET_TAGS)} -- which every "
                    "Static Pulse satisfies -- can be honoured")
        elif self.mode is not None or self.required_tags is not None:
            raise ValueError(
                f"sensor '{self.node_id}' is a {self.kind} and declares a "
                "target's mode or tags; only a SHOOTABLE_TARGET is shot, "
                "so they would describe nothing")
        if self.kind == "PRESSURE_PLATE" and self.requires_class is None:
            raise ValueError(
                f"sensor '{self.node_id}' is a PRESSURE_PLATE and names no "
                "class; a plate that demands nothing is satisfied by "
                "anything, which is not a puzzle and not §20.1's sensor")
        if self.counts_player and self.kind != "PRESSURE_PLATE":
            raise ValueError(
                f"sensor '{self.node_id}' is a {self.kind} and says it "
                "counts the player; only a plate reads bodies standing "
                "on it, so the flag would describe nothing")
        if self.requires_class is not None and self.kind != "PRESSURE_PLATE":
            raise ValueError(
                f"sensor '{self.node_id}' is a {self.kind} and demands "
                f"class {self.requires_class}; only a plate reads a mass "
                "class, so the demand would describe nothing")
        return self


class LogicNode(Strict):
    """One of §19.2's eleven, taking named inputs from earlier nodes."""
    node_id: str = _ID
    kind: NodeKind
    inputs: tuple[_NODE_REF, ...] = Field(min_length=1, max_length=4)
    #: For `TIMER`, §19.2's `duration`: seconds ON after a pulse. The
    #: TIMER is EPHEMERAL (§19.6): nothing of it is saved, and a rebuilt
    #: room starts it OFF.
    duration: float | None = Field(default=None, gt=0.0,
                                   le=TIMER_MAX_SECONDS)

    @model_validator(mode="after")
    def _the_runtime_has_this_node(self):
        refuse_unsupported_node(self.kind)
        if self.kind == "TIMER":
            if len(self.inputs) != 1:
                raise ValueError(
                    f"node '{self.node_id}' is a TIMER with "
                    f"{len(self.inputs)} inputs; §19.2 gives TIMER one "
                    "pulse")
            if self.duration is None:
                raise ValueError(
                    f"node '{self.node_id}' is a TIMER and names no "
                    "duration; §19.2's TIMER is ON for `duration`")
        elif self.duration is not None:
            raise ValueError(
                f"node '{self.node_id}' is a {self.kind} and declares a "
                "duration; only a TIMER has one here")
        if self.kind == "NOT" and len(self.inputs) != 1:
            raise ValueError(
                f"node '{self.node_id}' is a NOT with {len(self.inputs)} "
                "inputs; §19.2 gives NOT exactly one")
        if self.kind == "OR" and not 2 <= len(self.inputs) <= 4:
            raise ValueError(
                f"node '{self.node_id}' is an OR with {len(self.inputs)} "
                "input(s); §19.2 gives OR two to four")
        if self.kind == "LATCH" and len(self.inputs) != 1:
            # The runtime reads `inputs[0]` as SET and has no clear. A
            # second input would be read as nothing at all, so a
            # declared reset would silently never reset -- refused here
            # rather than discovered as a door that will not close.
            raise ValueError(
                f"node '{self.node_id}' is a LATCH with {len(self.inputs)} "
                "inputs; this slice's latch takes exactly one -- the set "
                "input -- and has no reset")
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


def settle(graph, pressed: bool,
           latched: frozenset[str] = frozenset()
           ) -> tuple[dict[str, bool], frozenset[str]]:
    """One tick of this graph with every plate `pressed` or not.

    The runtime's order, restated rather than approximated: sensors,
    then logic in declaration order (which the schema already proves is
    topological order), then actuators. A `LATCH` already in `latched`
    stays true; one whose input is true this tick joins it.

    A pressed PULSE sensor is its pulse on this tick. Pressing every
    sensor at once is a question about a route, and a route's chain is a
    single one (`ROUTE_*_KINDS`), so it asks each route the same thing as
    pressing its own plate; a room-local OR is never asked it.
    """
    values = {s.node_id: pressed for s in graph.sensors}
    now = set(latched)
    for node in graph.nodes:
        feeds = [values[i] for i in node.inputs]
        if node.kind == "NOT":
            values[node.node_id] = not feeds[0]
        elif node.kind == "LATCH":
            if node.node_id in now or feeds[0]:
                now.add(node.node_id)
            values[node.node_id] = node.node_id in now
        elif node.kind == "OR":
            values[node.node_id] = any(feeds)
        elif node.kind == "TIMER":
            # ON on the tick its pulse arrives. "Released" is after the
            # action, when the window has run out: a TIMER is never a
            # state a room rests in.
            values[node.node_id] = feeds[0]
        else:                                       # refused at declaration
            values[node.node_id] = False
    return values, frozenset(now)


def phases(graph, actuator_id: str) -> dict:
    """What an actuator reads before, during and after the one action.

    `rest` is the room as built. `pressed` is the plate loaded.
    `released` is the plate left again, with whatever latched still
    latched -- and since nothing un-latches, every later press and
    release lands back on these two values, so three states are all of
    them.

    The shapes this tells apart, which is why it exists:

      plate -> shutter                 rest closed, released closed:
                                       the player must HOLD it open
      plate -> NOT -> shutter          rest open,   released open:
                                       loading it only ever denies
      plate -> LATCH -> shutter        rest closed, released open:
                                       step on it once, walk through
      plate -> LATCH -> NOT -> shutter rest open,   released closed:
                                       the plate shuts the way for good
      plate -> NOT -> LATCH -> ...     latched at rest: the room decided
                                       before the player arrived
    """
    binding = next(a for a in graph.actuators
                   if a.actuator_id == actuator_id)
    rest_v, rest_l = settle(graph, False)
    press_v, press_l = settle(graph, True, rest_l)
    free_v, _ = settle(graph, False, press_l)
    at = binding.driven_by
    return {"rest": rest_v[at], "pressed": press_v[at],
            "released": free_v[at], "latched_at_rest": rest_l}


def resting_output(graph, actuator_id: str) -> bool:
    """What an actuator reads with nothing touching the room."""
    return phases(graph, actuator_id)["rest"]


def upstream(graph, actuator_id: str) -> tuple[list, list]:
    """The sensors and nodes an actuator is driven through.

    Walked backwards along EVERY input (O05-07: an OR has several), in
    the order a single chain was always walked, so a chain comes back as
    it did. The route validator asks about THESE sensors only: a second
    chain in the same room -- an object-only plate running a scenery
    shutter -- is not the interaction the route depends on, and refusing
    the route because of it would describe the wrong thing.
    """
    by_id = {n.node_id: n for n in graph.nodes}
    by_sensor = {s.node_id: s for s in graph.sensors}
    binding = next(a for a in graph.actuators
                   if a.actuator_id == actuator_id)
    sensors, nodes, seen = [], [], set()
    stack = [binding.driven_by]
    while stack:
        at = stack.pop()
        if at in seen:
            continue
        seen.add(at)
        if at in by_id:
            nodes.append(by_id[at])
            stack.extend(reversed(by_id[at].inputs))
        elif at in by_sensor:
            sensors.append(by_sensor[at])
    return sensors, nodes


def output_form(graph, node_id: str) -> str:
    """§19.1: the form a node or sensor of `graph` produces."""
    for sensor in graph.sensors:
        if sensor.node_id == node_id:
            return SENSOR_OUTPUT_FORM.get(sensor.kind, "BOOLEAN")
    return "BOOLEAN"


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
        # §19.1: "A node's input port accepts only its declared form; a
        # graph connecting mismatched forms fails validation at
        # composition, never at runtime." A pulse read as a Boolean is
        # OFF on every tick, so the mismatch would not fail -- it would
        # silently never fire.
        for node in self.nodes:
            accepts = NODE_INPUT_FORMS.get(node.kind, ("BOOLEAN",))
            for feed in node.inputs:
                form = output_form(self, feed)
                if form not in accepts:
                    raise ValueError(
                        f"node '{node.node_id}' is a {node.kind}, which "
                        f"reads {' or '.join(accepts)}; '{feed}' produces "
                        f"a {form}. §19.1: a node reading a Boolean port "
                        "sees OFF when a pulse occurred")
        for binding in self.actuators:
            form = output_form(self, binding.driven_by)
            if form != "BOOLEAN":
                raise ValueError(
                    f"actuator '{binding.actuator_id}' is driven straight "
                    f"by '{binding.driven_by}', a {form}; a machine "
                    "commanded by a pulse would move for one tick. Put a "
                    "LATCH between them")
        # A LATCH THAT SETS WHEN THE ROOM IS BUILT RECORDS A DECISION
        # NOBODY MADE. Its input is true at rest -- `plate -> NOT ->
        # LATCH` -- so the first tick latches it, the runtime reports it,
        # and the campaign would persist a player choice that happened
        # during loading. Refused for every graph, route or not.
        _, at_rest = settle(self, False)
        if at_rest:
            raise ValueError(
                f"LATCH {sorted(at_rest)} in room '{self.room_id}' is set "
                "the moment the room is built, because its input is true "
                "with nothing on the plate; that records a decision no "
                "player made")
        return self
