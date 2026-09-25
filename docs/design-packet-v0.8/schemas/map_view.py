"""H-MAP-DATA — one map projection for the minimap, the 3D map and the journal.

C-MAP: "Separate unknown, blocked with known reason, transitioning/unsafe,
and open. Item possession does not equal a completed power circuit.
Names do not replace save IDs. The map can explain known state without
revealing hidden content simply because the backend knows it."

**One projection, read by every view.** The minimap and the 3D map draw
the same facts, so neither computes a second version of progression.

**Gate state reads recorded consequences only**:
- an opened lock (`opened_locks`);
- Zone state (`macro_state`);
- a recorded latch (`latched`).

It never reads what the player HOLDS or CARRIES. Owning the green cell
leaves the green door blocked; installing it changes the Zone-state
variable the receiver sets, and that is what opens the door (04 §6).

**`transitioning` is not produced here.** A door mid-swing, a jammed
shutter and the pressure on a live plate are runtime facts. The bridge
knows the settled state, so a live gate reads `unknown` with its reason,
and the engine overlays what is happening now. That is a split of
authority, not a fifth state faked from settled data.

**What is not revealed:**
- a connector that cannot be walked from a discovered room (a one-way
  return arriving in a found room shows once its origin is found);
- an undiscovered room's name (an authored minor's name would give it
  away);
- the room holding the control for a gate, until that room is
  discovered;
- a circuit none of whose members has been discovered.

**Names are presentation only (M-3).** A room's authored name is its
hosted minor's contract name; otherwise it is its type plus a number.
The name is computed on every call and never stored or used as an
identity. Ids stay the save's.
"""
from __future__ import annotations

import collections
from typing import Literal

from pydantic import BaseModel, ConfigDict

try:
    from . import mechanics as M
    from . import minors
    from . import signal_graph as SG
    from .physics import GRAPH_PACKAGE_PREFIX, MINOR_PACKAGE_PREFIX
except ImportError:  # pragma: no cover
    import mechanics as M
    import minors
    import signal_graph as SG
    from physics import GRAPH_PACKAGE_PREFIX, MINOR_PACKAGE_PREFIX

GateKind = Literal["none", "key", "zone_state", "machine", "capability"]
GateState = Literal["unknown", "blocked", "open"]


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class MapRoom(_Strict):
    room_id: str
    #: Presentation only (M-3); `None` while undiscovered.
    name: str | None = None
    type: str
    discovered: bool


class MapConnector(_Strict):
    edge_id: str
    room_a: str
    room_b: str
    realization: str
    #: The save's own value: `BIDIRECTIONAL`, `A_TO_B` or `B_TO_A`.
    direction: str
    gates: tuple[GateKind, ...] = ("none",)
    circuits: tuple[str, ...] = ()
    state: GateState
    reason: str = ""


class MapCircuit(_Strict):
    circuit_id: str
    kind: Literal["key", "setting", "machine"]
    #: Stable ids of the members the player has discovered: rooms,
    #: connectors, objects.
    rooms: tuple[str, ...] = ()
    connectors: tuple[str, ...] = ()
    objects: tuple[str, ...] = ()


class MapView(_Strict):
    zone_id: str
    rooms: tuple[MapRoom, ...] = ()
    connectors: tuple[MapConnector, ...] = ()
    circuits: tuple[MapCircuit, ...] = ()


def room_names(zone) -> dict[str, str]:
    """M-3: the authored name where the room has one, else type + number.

    **Authored** means a hosted minor's contract name ("Unweighted
    Switch"). A generic shell's registry label ("corner left") describes
    geometry, not a room, so it is not used: every corner would share it.
    Numbers count the unnamed rooms of each type in declaration order,
    and an authored name used twice in one Zone is numbered too, so no
    two rooms read alike. Presentation only -- recomputed on each call
    and never stored.
    """
    authored = {c.id: getattr(minors.contract_for(c.shell_id), "name", None)
                for c in zone.chambers}
    repeats = collections.Counter(n for n in authored.values() if n)
    names: dict[str, str] = {}
    counts: collections.Counter = collections.Counter()
    for c in zone.chambers:
        label = authored[c.id] or c.type.replace("_", " ").title()
        if authored[c.id] and repeats[label] == 1:
            names[c.id] = label
        else:
            counts[label] += 1
            names[c.id] = f"{label} {counts[label]}"
    return names


def derived_discovery(zone, progress) -> frozenset[str]:
    """Rooms the save PROVES the player reached, for a save that has no
    discovery record: the entrance, and every room a recorded fact
    names. An undercount by design -- no room is claimed discovered
    that the save cannot show."""
    rooms = {zone.chambers[0].id}
    key_room = {k.key_id: c.id for c in zone.chambers for k in c.keys}
    rooms |= {key_room[k] for k in progress.collected_keys if k in key_room}
    rooms |= {ref.split("/", 1)[0] for ref in progress.opened_locks}
    for ref in progress.latched:
        package = ref.split("/", 1)[0]
        for prefix in (GRAPH_PACKAGE_PREFIX, MINOR_PACKAGE_PREFIX):
            if package.startswith(prefix):
                rooms.add(package[len(prefix):])
    rooms |= {m.split("/", 1)[0] for m in (progress.defeated or ())}
    rooms |= {room for _, room in progress.object_rooms}
    for v in zone.zone_state:
        if progress.macro(v.variable_id) not in (None, v.initial):
            rooms.add(v.setter.room_id)
    known = {c.id for c in zone.chambers}
    return frozenset(r for r in rooms if r in known)


def map_view(save, zone_id: str, *, visited=None) -> MapView:
    """The map of one Zone, as far as the player has discovered it.

    Discovery is the Zone's record (`ZoneProgress.visited_rooms`) joined
    with what the save proves (`derived_discovery`), so a missed report
    never hides a room a recorded fact names. Before any record exists,
    as in a save written before the field, the proof alone. `visited`
    overrides both, for a caller asking about a hypothetical.

    Capabilities are read here, from the save, rather than passed in: a
    view that took them as an argument could be handed a different
    answer from the one the snapshot shows.
    """
    return map_of(save.zone_by_id(zone_id), save.derive(), save.slots,
                  visited=visited)


def map_of(rec, mechanics, slots, *, visited=None) -> MapView:
    """The same map from a Zone record and what a snapshot carries."""
    zone_id = rec.zone_id
    zone, progress = rec.zone, rec.progress
    can_now = set(M.available_capabilities(mechanics, slots))
    owned = set(M.owned_capabilities(mechanics))
    found = (frozenset(visited) if visited is not None
             else frozenset(progress.visited_rooms or ())
             | derived_discovery(zone, progress))
    names = room_names(zone)
    rooms = tuple(MapRoom(room_id=c.id, type=c.type,
                          discovered=c.id in found,
                          name=names[c.id] if c.id in found else None)
                  for c in zone.chambers)

    variables = {v.variable_id: v for v in zone.zone_state}
    def holds(var_id: str) -> str | None:
        v = variables.get(var_id)
        return progress.macro(var_id) or (v.initial if v else None)

    locks = {}
    for c in zone.chambers:
        for d in c.doors:
            if d.usage == "LOCKED" and d.edge_id:
                locks[d.edge_id] = (c.id, d)
    graphs = {a.actuator_id: g for g in zone.room_graphs for a in g.actuators}
    opened = set(progress.opened_locks)  # `room_id/socket_id`
    latched = set(progress.latched)
    circuits: dict[str, dict] = {}

    def join(cid: str, kind: str, *, room=None, edge=None, obj=None):
        c = circuits.setdefault(cid, {"kind": kind, "rooms": set(),
                                      "connectors": set(), "objects": set()})
        if room in found:
            c["rooms"].add(room)
        if edge:
            c["connectors"].add(edge)
        if obj:
            c["objects"].add(obj)

    connectors = []
    for e in zone.edges:
        # Seen from a room it can be walked FROM. A one-way return
        # plug arriving in the entrance does not show until the room it
        # leaves from is found: its arrival end is no map of the rest.
        if not ((e.room_a in found and e.traversable(e.room_a))
                or (e.room_b in found and e.traversable(e.room_b))
                or (e.room_a in found and e.room_b in found)):
            continue
        gates, cids, states, reasons = [], [], [], []
        if e.edge_id in locks:
            room, door = locks[e.edge_id]
            cid = f"key:{door.key_id}"
            gates.append("key"); cids.append(cid)
            join(cid, "key", edge=e.edge_id, room=room)
            if f"{room}/{door.socket_id}" in opened:
                states.append("open")
            else:
                states.append("blocked")
                held = door.key_id in progress.collected_keys
                reasons.append(f"locked -- {door.colour or door.key_id} key"
                               + ("; you hold it" if held else ""))
        for cond in e.requires_state:
            cid = f"state:{cond.variable_id}"
            gates.append("zone_state"); cids.append(cid)
            join(cid, "setting", edge=e.edge_id)
            if holds(cond.variable_id) == cond.state:
                states.append("open")
            else:
                states.append("blocked")
                setter = variables[cond.variable_id].setter.room_id
                reasons.append("set by a control " + (
                    f"in {names[setter]}" if setter in found
                    else "somewhere else"))
        if e.opened_by and e.opened_by in graphs:
            g = graphs[e.opened_by]
            cid = f"machine:{g.room_id}:{e.opened_by}"
            gates.append("machine"); cids.append(cid)
            join(cid, "machine", edge=e.edge_id, room=g.room_id)
            _, nodes = SG.upstream(g, e.opened_by)
            if not any(n.kind == "LATCH" for n in nodes):
                # Held open only while something holds it: whether it is
                # held right now is the engine's to say.
                states.append("unknown")
                reasons.append("worked live by a control"
                               + (f" in {names[g.room_id]}"
                                  if g.room_id in found else ""))
            else:
                # Settled with nothing pressed and the latches this save
                # recorded -- the runtime's own restore, not a guess.
                package = f"{GRAPH_PACKAGE_PREFIX}{g.room_id}/"
                recorded = frozenset(ref[len(package):] for ref in latched
                                     if ref.startswith(package))
                values, _ = SG.settle(g, False, recorded)
                driven = next(a.driven_by for a in g.actuators
                              if a.actuator_id == e.opened_by)
                if values[driven]:
                    states.append("open")
                else:
                    states.append("blocked")
                    reasons.append("worked by a control" + (
                        f" in {names[g.room_id]}" if g.room_id in found
                        else " somewhere else"))
        if e.capability:
            gates.append("capability")
            need = e.capability.replace("_", " ")
            if e.capability in can_now:
                states.append("open")
            elif e.capability in owned:
                # NOT YET: theirs, and not in a slot.
                states.append("blocked")
                reasons.append(f"needs {need} -- you own it; equip it")
            else:
                states.append("blocked")
                reasons.append(f"needs {need}")
        state = ("blocked" if "blocked" in states
                 else "unknown" if "unknown" in states else "open")
        connectors.append(MapConnector(
            edge_id=e.edge_id, room_a=e.room_a, room_b=e.room_b,
            realization=e.realization.lower(), direction=e.direction,
            gates=tuple(gates) or ("none",), circuits=tuple(cids),
            state=state, reason="; ".join(reasons)))

    # A supply and its receiver belong to the circuit of the variable
    # the receiver sets -- green supply, green receiver, green door.
    for con in zone.object_consumers:
        if con.sets_variable:
            cid = f"state:{con.sets_variable}"
            join(cid, "setting", room=con.room_id)
            obj = next((o for o in zone.transported_objects
                        if o.object_id == con.accepts), None)
            if obj is not None and (con.room_id in found
                                    or obj.home_room_id in found):
                join(cid, "setting", obj=obj.object_id)
    for v in zone.zone_state:
        join(f"state:{v.variable_id}", "setting", room=v.setter.room_id)
    key_room = {k.key_id: c.id for c in zone.chambers for k in c.keys}
    for key, room in key_room.items():
        join(f"key:{key}", "key", room=room)

    shown = {c.edge_id for c in connectors}
    out = []
    for cid, c in sorted(circuits.items()):
        edges = tuple(sorted(c["connectors"] & shown))
        if not c["rooms"] and not edges:
            continue
        out.append(MapCircuit(circuit_id=cid, kind=c["kind"],
                              rooms=tuple(sorted(c["rooms"])),
                              connectors=edges,
                              objects=tuple(sorted(c["objects"]))))
    return MapView(zone_id=zone_id, rooms=rooms,
                   connectors=tuple(connectors), circuits=tuple(out))
