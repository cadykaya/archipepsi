"""P14's composer: a room-graph latch opening a route on a real Zone.

**The same discipline as D-8's `cross_room.compose_zone_state`, and for
the same reasons.** It is a step a caller takes, never a default:
wiring it into `topology.apply` would change every Zone the campaign
composes, and the runtime half -- `ClassPlate` honouring
`counts_player`, the shutter placed across the named doorway -- is
Prod's and not finished. A default that emitted this today would ship a
door the engine cannot yet open.

**It is derived, not hardcoded.** Handed a Zone the campaign really
composed, it picks the edge from that Zone's own structure -- the spine
order, which edges are real doorways, which already carry a gate.
Nothing here names a room.

**And it declines rather than emitting something broken.** Every
candidate goes through the real `Zone` schema (which refuses an
object-only plate, a held requirement, a latch that seals the way, a
latch that sets on build) and then through `topology.reachability`
(which refuses a trigger behind the route it opens, and anything that
strands). If nothing passes, the Zone comes back unchanged with the
reason.

**D-07 retired what it used to emit** (owner ruling, 2026-09-24):
"Pressure plates are held sensors [...] If a puzzle needs a permanent
change, use a visibly different permanent control such as a lever". D-10
chose a `MEDIUM` plate that counted the player, a `LATCH` and a shutter:
step on it once and walk through. Two entry points now share one search:

  `compose_latched_route`         the production step. It **declines**
                                  until `RoomGraphs` can place a lever
                                  (D13 1c); then it emits
                                  `lever -> LATCH -> shutter`.
  `compose_legacy_step_once_route` the retired plate chain, kept ONLY to
                                  regenerate M-1's legacy fixture and to
                                  seed its replay suite. No production
                                  path calls it, a test says so, and
                                  `validate_zone` refuses its output at
                                  acceptance (D13 1a).

M-1: a Zone saved with the plate chain loads and plays as saved. That is
the model validators' business, and they did not change.
"""
from __future__ import annotations

from dataclasses import dataclass

from .schemas.zone import Zone
from .topology import reachability

#: Room-local ids; the graph is room-local by construction, so they
#: cannot collide with anything in another room.
PLATE_ID = "step_plate"
LATCH_ID = "held"
SHUTTER_ID = "route_shutter"

#: WHERE A PLATE MAY STAND (P5-11): rooms with open floor. A
#: `platform_path` is islands over a kill pit and a `tower` is floors over
#: a drop, and a corridor is a lane -- its floor is the way through, and
#: the engine's clear-floor search keeps 2.6 m from everything placed.
#: P14's own played acceptance stands its plate in an arena.
_PLATE_ROOM_TYPES = ("arena", "treasure_room")

#: Prefer a plate that is not in the entrance itself -- a latch at spawn
#: is stepped on before the player knows it is there -- and fall back to
#: the entrance only if nothing further in is legal.
_PREFER_FROM = 1


@dataclass(frozen=True)
class LatchedRoute:
    zone: Zone
    #: `None` when nothing was emitted.
    edge_id: str | None
    note: str

    @property
    def emitted(self) -> bool:
        return self.edge_id is not None


def _step_once_graph(room_id: str) -> dict:
    """D-10's plate chain, which D-07 retired. Legacy input only."""
    return {
        "room_id": room_id,
        "sensors": [{"node_id": PLATE_ID, "kind": "PRESSURE_PLATE",
                     "requires_class": "MEDIUM", "counts_player": True}],
        "nodes": [{"node_id": LATCH_ID, "kind": "LATCH",
                   "inputs": [PLATE_ID]}],
        "actuators": [{"actuator_id": SHUTTER_ID, "driven_by": LATCH_ID}],
    }


#: Why the production step emits nothing today (D13 1b).
DECLINED_UNTIL_LEVERS = (
    "D-07: a pressure plate is a held sensor, so a permanent route needs a "
    "lever; the Zone builder cannot place one yet (D13 1c lands with "
    "RoomGraphs' lever placement), so no latch route is composed")


def compose_latched_route(zone: Zone) -> LatchedRoute:
    """The production step. Declines until a lever can be placed."""
    return LatchedRoute(zone, None, DECLINED_UNTIL_LEVERS)


def compose_legacy_step_once_route(zone: Zone) -> LatchedRoute:
    """M-1's LEGACY input: the retired `plate -> LATCH -> shutter`.

    For the legacy fixture (`make latched-route-fixture`) and the replay
    suite that seeds from it (`tools/compose_latched_route.py`) only.
    """
    return _compose(zone, _step_once_graph, "plate and latch")


def _compose(zone: Zone, graph_for, what: str) -> LatchedRoute:
    """Put the chain `graph_for(room)` builds on one legal doorway."""
    if zone.room_graphs or any(e.opened_by for e in zone.edges):
        return LatchedRoute(zone, None,
                            "the Zone already declares a room graph or a "
                            "machine-opened edge; this step does not stack")
    order = {c.id: i for i, c in enumerate(zone.chambers)}
    # ONE CONTROL PER ROOM (O05-13, P5-11). A room already holding another
    # relationship's control -- a Zone-state setter, a carried object's
    # home, the socket it goes into -- has spent the clear floor a plate
    # needs. In the candidate profile's first played combination the
    # lever took c002's floor and the engine refused this plate by name
    # ("no clear floor for sensor 'step_plate'"). Declined here, where the
    # room is chosen, instead of being left for the engine to refuse.
    kinds = {c.id: c.type for c in zone.chambers}
    arrive = {c.id: c.arrive_edge for c in zone.chambers}
    from .transport_route import _off_the_floor, _socket_heights
    heights = _socket_heights()
    occupied = ({v.setter.room_id for v in zone.zone_state if v.setter}
                | {o.home_room_id for o in zone.transported_objects}
                | {c.room_id for c in zone.object_consumers})
    candidates = []
    for index, edge in enumerate(zone.edges):
        if edge.realization != "JOINED":
            continue          # a plug has no doorway for a shutter to cross
        if edge.capability or edge.requires_state:
            continue          # one gate per edge
        if edge.room_a not in order or edge.room_b not in order:
            continue
        near, far = sorted((edge.room_a, edge.room_b), key=order.__getitem__)
        if near in occupied:
            continue          # one control per room
        if kinds.get(near) not in _PLATE_ROOM_TYPES:
            continue          # a plate needs clear walkable floor
        # AND THE DOOR IT OPENS ON THE PLATE'S FLOOR (P5-8's rule): a
        # shutter 28 m over the plate, across a launch arc, is not the
        # consequence a player standing on it can see.
        if _off_the_floor(zone, near, {edge.edge_id}
                          | ({arrive[near]} if arrive.get(near) else set()),
                          heights):
            continue
        candidates.append((order[near] < _PREFER_FROM, order[near], index,
                           near, far))
    refusals = []
    base = zone.model_dump()
    for _, _, index, near, far in sorted(candidates):
        raw = {**base, "edges": [dict(e) for e in base["edges"]]}
        raw["edges"][index]["opened_by"] = SHUTTER_ID
        raw["room_graphs"] = [graph_for(near)]
        try:
            candidate = Zone.model_validate(raw)
        except ValueError as exc:
            refusals.append(f"{raw['edges'][index]['edge_id']}: {exc}")
            continue
        verdict = reachability(candidate)
        if not verdict.ok:
            refusals.append(f"{raw['edges'][index]['edge_id']}: "
                            + "; ".join(verdict.errors))
            continue
        edge_id = raw["edges"][index]["edge_id"]
        return LatchedRoute(
            candidate, edge_id,
            f"{what} in '{near}', shutter across '{edge_id}' "
            f"into '{far}'; reachable before the route it opens")
    return LatchedRoute(
        zone, None,
        "no doorway in this Zone can carry the latch legally"
        + (f": {refusals[0]}" if refusals else " (no candidate edges)"))
