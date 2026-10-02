"""P16's composer: a required object carried between rooms to the machine
that takes it (O05-02).

**The same discipline as `cross_room.py` and `latched_route.py`**, and for
the same reasons: it is an explicit step, never a default (wiring it into
`topology.apply` would move `played_zone_digest`, the placement fixtures
and the 0.3 comparison in one commit), it derives everything from a Zone
the campaign really composed, and it declines rather than emit something
broken. Nothing here names a room.

**What it emits, all of it through declarations that already exist:**

- a `TransportedObject` -- `power_cell`, hand carried, `required`, 40 kg
  (under §10.3's 60 kg line, and `MEDIUM`, so carrying it costs the
  0.85 walk and a `LIGHTENED` cell costs nothing);
- its `allowed_volume`: a contiguous run of the spine, home first,
  crossing real connectors -- two of them when the Zone has the rooms;
- an `ObjectConsumer` in the run's last room, accepting that object and
  setting a declared D-8 variable;
- the variable itself, `permanent` (a cell once installed stays
  installed, so its setter selects exactly one non-initial state), with
  a lamp in the consumer's room and one past the door it opens;
- `requires_state` on the spine edge leaving the consumer's room.

**Why the delivery gates a route, and why that is safe.** `required`
says a puzzle on the mandatory path needs the object; an object whose
arrival opened nothing would make that a false declaration. So the
consumer's variable gates the next spine edge -- DECLARED on the edge,
which `topology.reachability` reads, and physically realised in the
engine as that doorway's own shutter. A gate the route logic knows about
is exactly what §0-bis permits; the thing it forbids is the undeclared
one.

What `reachability` cannot see is the carry itself: `topology.py` does
not read `transported_objects`, so it treats reaching the consumer's
room as enough to set the variable. That is only true if the object and
every room it is carried through are reachable BEFORE the gate opens,
and every connector on the way can be crossed with Mobility blocked.
This composer proves both from the same search rather than assuming
them: each room of the run must appear in a reachable state with the
variable still at its initial value, and every carry edge must be a
plain joined, two-way, capability-free, unlatched, unlocked connector.
And because §10.4's recovery returns a lost required object home, the
object cannot be permanently lost either.
"""
from __future__ import annotations

from dataclasses import dataclass

from .schemas.zone import Zone
from .topology import reachability

OBJECT_ID = "power_cell"
CONSUMER_ID = "cell_socket"
VARIABLE_ID = "cell_power"
STATES = ("dark", "powered")
#: MEDIUM (30 <= m < 120) and under the 60 kg carry line.
MASS_KG = 40.0
#: Where along the spine the object's home may sit. Not the entrance, so
#: the player has met the Zone before being handed a job, and early
#: enough that the gate it opens is worth something.
_HOME_WINDOW = (1, 4)
#: Rooms in the carry run, longest first: two connectors crossed when the
#: Zone has them, one when it does not.
_RUN_LENGTHS = (3, 2)
#: WHERE A REQUIRED OBJECT MAY BE CARRIED: rooms a player crosses on foot.
#: A `platform_path` is jumps over a void and a `tower` is floors above a
#: drop; a cell fumbled there can come to rest where nobody reaches it,
#: and §10.4's "at rest 5 s, unreachable" recovery -- the rule that would
#: bring it back -- needs a reachability answer the engine does not have
#: for an arbitrary resting point. So those rooms are not carry routes.
#: (Found by the played acceptance, O05-02: the first composition ran the
#: carry through c003, a platform path.)
_CARRY_ROOM_TYPES = ("corridor", "arena", "treasure_room")
#: HOW FAR APART, VERTICALLY, THE DOORWAYS A JOURNEY USES IN ONE ROOM MAY
#: SIT and still be one floor. A hand carry is a walk. An authored shell
#: can join at very different heights -- `shell_hall_transit` leaves 28 m
#: above where it is entered, by a launch arc, and the tower shells 6 to
#: 15 m up -- and a 40 kg cell does not go up a launch arc in a player's
#: hands, nor is a door the delivery opens a consequence when it is 27 m
#: over the socket. Read from the registry's own socket positions, never
#: assumed from the room type. (Found by the played acceptance, O05-02:
#: the second composition installed the cell in the transit hall, and
#: the door it opened was out of reach overhead.)
_ONE_FLOOR_M = 0.5


@dataclass(frozen=True)
class Transport:
    """What the composer produced, and why."""
    zone: Zone
    #: `None` when nothing was emitted.
    object_id: str | None
    #: Always populated -- the reason it emitted this, or declined.
    note: str
    home_room_id: str | None = None
    consumer_room_id: str | None = None
    gated_edge_id: str | None = None
    volume: tuple[str, ...] = ()

    @property
    def emitted(self) -> bool:
        return self.object_id is not None


def _spine(zone: Zone) -> list[str]:
    """Rooms in composed order. `chambers` order IS the spine order."""
    return [c.id for c in zone.chambers]


def _doors_for(zone: Zone, edge_id: str) -> list:
    return [d for c in zone.chambers for d in c.doors
            if d.edge_id == edge_id]


def _socket_heights() -> dict[str, dict[str, float]]:
    """`shell_id -> joinable socket name -> height above the shell's
    origin`, read from the same registry the Zone's shells come from."""
    from . import shells
    return {sid: {s.name: float(s.position[1]) for s in entry.sockets
                  if s.kind in shells.JOINABLE_SOCKET_KINDS}
            for sid, entry in shells.load_registry().items()}


def _off_the_floor(zone: Zone, room_id: str, edge_ids: set[str],
                   heights: dict[str, dict[str, float]]) -> str:
    """Why `room_id`'s doorways onto `edge_ids` are not on one floor, or "".

    A procedural room of a carry type is one floor: every doorway its
    builder cuts is at floor level (the registry's `shell_*_proc` rows
    say so, and `test_transport_route` holds them to it). An AUTHORED
    shell is read, not assumed: an unmeasured socket declines rather
    than being guessed flat.
    """
    chamber = next(c for c in zone.chambers if c.id == room_id)
    if not chamber.shell_id:
        return ""
    measured = heights.get(chamber.shell_id)
    used = sorted({d.socket_id for d in chamber.doors
                   if d.edge_id in edge_ids})
    if measured is None or any(s not in measured for s in used):
        return (f"'{room_id}' is shell '{chamber.shell_id}', whose doorway "
                "heights the registry does not give")
    ys = {s: measured[s] for s in used}
    if max(ys.values(), default=0.0) - min(ys.values(), default=0.0) \
            <= _ONE_FLOOR_M:
        return ""
    return (f"'{room_id}' is shell '{chamber.shell_id}', whose doorways "
            + ", ".join(f"'{s}' at {y:g} m" for s, y in ys.items())
            + " are not one floor; a hand carry is a walk")


def _plain(zone: Zone, edge) -> str:
    """Why `edge` cannot be crossed carrying something, or "".

    Carrying blocks Mobility (§10.3), so a connector that asks for a
    capability cannot be crossed with the object in hand; a latched or
    state-gated one is a second puzzle in the middle of this one; a
    locked one needs a key the composer has not placed. A one-way or
    traversal-only link may not be walkable back, and a recovery that
    returns the object home should not leave the player on the wrong
    side of one.
    """
    if edge.realization != "JOINED":
        return f"'{edge.edge_id}' is {edge.realization}, not a doorway"
    if edge.direction != "BIDIRECTIONAL":
        return f"'{edge.edge_id}' is one-way ({edge.direction})"
    if edge.capability is not None:
        return (f"'{edge.edge_id}' needs '{edge.capability}', and "
                "carrying blocks Mobility")
    if edge.opened_by is not None:
        return f"'{edge.edge_id}' is opened by '{edge.opened_by}'"
    if edge.requires_state:
        return f"'{edge.edge_id}' is already gated on Zone state"
    if any(d.usage == "LOCKED" for d in _doors_for(zone, edge.edge_id)):
        return f"'{edge.edge_id}' is behind a locked door"
    return ""


def compose_transport(zone: Zone, *, entry_id: str | None = None,
                      exit_id: str | None = None,
                      declared_capabilities=None) -> Transport:
    """Derive one required carry-and-install journey from a composed Zone.

    Searched home-first along the spine inside `_HOME_WINDOW`, longest
    run first. A candidate is kept only if the real `Zone` schema
    accepts it, `reachability` finds no error, the run is reachable
    with the gate still shut, and the gate really is on the way to the
    exit -- otherwise `required` would be a claim nothing needs.
    """
    rooms = _spine(zone)
    if not zone.edges:
        return Transport(zone, None,
                         "the Zone declares no edges, so there is no "
                         "connector to carry anything across")
    if len(rooms) < 3:
        return Transport(zone, None,
                         "fewer than three rooms; a carry across a "
                         "connector and a door it opens need at least three")
    if zone.transported_objects or zone.object_consumers:
        return Transport(zone, None,
                         "the Zone already declares a transported object; "
                         "this step composes the first one, it does not "
                         "add to one")
    if len(zone.zone_state) >= 4:
        return Transport(zone, None,
                         "the Zone already declares four Zone-state "
                         "variables, the most a Zone may have")
    if any(v.variable_id == VARIABLE_ID for v in zone.zone_state):
        return Transport(zone, None,
                         f"the Zone already declares '{VARIABLE_ID}'")

    edges_by_pair = {frozenset((e.room_a, e.room_b)): e for e in zone.edges}
    kinds = {c.id: c.type for c in zone.chambers}
    arrive = {c.id: c.arrive_edge for c in zone.chambers}
    heights = _socket_heights()
    # ONE CONTROL PER ROOM (P5-11): the object's home and its socket take
    # floor, and so does another relationship's control -- a Zone-state
    # setter, or a room graph's plate.
    occupied = ({v.setter.room_id for v in zone.zone_state if v.setter}
                | {g.room_id for g in zone.room_graphs})
    exit_room = exit_id or rooms[-1]
    index = len(zone.zone_state)
    why_not: list[str] = []
    lo, hi = _HOME_WINDOW
    for length in _RUN_LENGTHS:
        for h in range(lo, hi + 1):
            # THE CONSUMER'S ROOM MUST HAVE A ROOM AFTER IT: the door the
            # delivery opens leads there.
            c = h + length - 1
            if c + 1 >= len(rooms):
                break
            run = rooms[h:c + 1]
            unwalkable = [r for r in run
                          if kinds.get(r) not in _CARRY_ROOM_TYPES]
            if unwalkable:
                why_not.append(f"{run}: {unwalkable[0]} is a "
                               f"{kinds.get(unwalkable[0])}, not a room a "
                               "carried object crosses on foot")
                continue
            crowded = [r for r in (run[0], run[-1]) if r in occupied]
            if crowded:
                why_not.append(f"{run}: '{crowded[0]}' already holds another "
                               "relationship's control")
                continue
            carry = [edges_by_pair.get(frozenset((a, b)))
                     for a, b in zip(run, run[1:])]
            if any(e is None for e in carry):
                why_not.append(f"{run}: not joined along the spine")
                continue
            blocked = [w for w in (_plain(zone, e) for e in carry) if w]
            if blocked:
                why_not.append(f"{run}: {blocked[0]}")
                continue
            gated = edges_by_pair.get(frozenset((rooms[c], rooms[c + 1])))
            if gated is None:
                why_not.append(f"'{rooms[c]}' is not joined to "
                               f"'{rooms[c + 1]}'")
                continue
            # THE GATE IS A SHUTTER IN A DOORWAY, so the edge must be one.
            if gated.realization != "JOINED":
                why_not.append(f"'{gated.edge_id}' is {gated.realization}; "
                               "there is no doorway to gate")
                continue
            # The gated doorway gets one shutter. A second gate in the
            # same doorway (a latch, a lock, another variable) would make
            # the two fight over it.
            if (gated.opened_by is not None or gated.requires_state
                    or any(d.usage == "LOCKED"
                           for d in _doors_for(zone, gated.edge_id))):
                why_not.append(f"'{gated.edge_id}' already carries a gate")
                continue
            # ONE FLOOR PER ROOM: the doorway each run room is entered by
            # (where the object rests and the socket stands), the carry
            # doorways, and the door the delivery opens.
            journey = {e.edge_id for e in carry} | {gated.edge_id}
            steep = [w for w in (
                _off_the_floor(zone, r, ({arrive[r]} if arrive[r] else set())
                               | journey, heights) for r in run) if w]
            if steep:
                why_not.append(f"{run}: {steep[0]}")
                continue
            candidate = _emit(zone, run, rooms[c + 1], gated.edge_id)
            if candidate is None:
                why_not.append(f"{run}: the schema refused it")
                continue
            reach = reachability(candidate, entry_id, exit_id,
                                 declared_capabilities)
            if not reach.ok:
                why_not.append(f"{run}: {reach.errors[0]}")
                continue
            dark = {s[0] for s in reach.states
                    if len(s[2]) > index and s[2][index] == STATES[0]}
            unreached = [r for r in run if r not in dark]
            if unreached:
                why_not.append(f"{run}: {unreached} not reachable before "
                               "the delivery")
                continue
            if exit_room in dark:
                why_not.append(f"{run}: the exit is reachable without the "
                               f"delivery, so '{gated.edge_id}' is not on "
                               "the mandatory path")
                continue
            return Transport(
                candidate, OBJECT_ID,
                f"'{OBJECT_ID}' at home in '{run[0]}', carried "
                f"{' -> '.join(run)}, installed in '{run[-1]}', opening "
                f"'{gated.edge_id}'",
                home_room_id=run[0], consumer_room_id=run[-1],
                gated_edge_id=gated.edge_id, volume=tuple(run))
    return Transport(zone, None,
                     "no placement validated: "
                     + ("; ".join(why_not[:4]) if why_not
                        else "no run fits inside the home window"))


def _emit(zone: Zone, run: list[str], beyond: str,
          edge_id: str) -> Zone | None:
    """Build the candidate through the REAL schema, or give up on it.

    `model_validate`, as `cross_room._emit` does, so every P16 and D-8
    rule runs against what this produced: the carry line, home inside
    the volume, the consumer inside it, the lifetime agreeing with the
    setter, a reader somewhere other than the setter's room.
    """
    raw = zone.model_dump()
    consumer_room = run[-1]
    raw["transported_objects"] = [{
        "object_id": OBJECT_ID,
        "allowed_volume": list(run),
        "home_room_id": run[0],
        "required": True,
        "carriable": True,
        "mass_kg": MASS_KG,
        "movement": "hand_carried",
    }]
    raw["object_consumers"] = [{
        "mechanism_id": CONSUMER_ID,
        "room_id": consumer_room,
        "accepts": OBJECT_ID,
        "sets_variable": VARIABLE_ID,
        "sets_state": STATES[1],
    }]
    raw["zone_state"] = list(raw.get("zone_state", [])) + [{
        "variable_id": VARIABLE_ID,
        "states": list(STATES),
        "initial": STATES[0],
        "lifetime": "permanent",
        # THE INSTALLATION IS THE SETTER. D-8's setter is "where the
        # player performs the interaction", and here that interaction is
        # putting the cell in the socket. There is no lever: the engine
        # builds none for a variable a consumer sets, and the bridge
        # refuses a `zone_state_selected` for it.
        "setter": {"room_id": consumer_room, "selects": [STATES[1]],
                   "capability": None},
        "readers": [
            {"room_id": consumer_room, "mechanism": "lamp",
             "when": [STATES[1]]},
            {"room_id": beyond, "mechanism": "lamp", "when": [STATES[1]]},
        ],
        "mandatory": True,
    }]
    for e in raw["edges"]:
        if e["edge_id"] == edge_id:
            e["requires_state"] = [{"variable_id": VARIABLE_ID,
                                    "state": STATES[1]}]
    try:
        return Zone.model_validate(raw)
    except Exception:
        return None
