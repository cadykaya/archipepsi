"""D-8's composer: emitting a cross-room relationship onto a real Zone.

**Why this is a step and not a default.** Wiring relationship emission
into `topology.apply` would change every Zone the campaign composes,
which would move `played_zone_digest`, the placement fixtures and the
0.3 comparison build in one commit. The owner's standing instruction is
to preserve the comparison and the review snapshots, so this is an
explicit step a caller takes -- the same shape `quiet.py` uses for the
lower-budget variant, and for the same reason.

**What makes it a composer rather than a fixture.** It is handed a Zone
the campaign really composed and derives the relationship from that
Zone's own structure: which rooms exist, which are on the spine, where
the featured acquisition sits, which edge lies between the setter and
the consequence. Nothing here names a room. Feed it a differently
composed Zone and you get a different relationship, which is the whole
difference between composing one and hardcoding one.

**And it declines rather than emitting something broken.** Every
candidate is validated through the real `Zone` schema and then through
`topology.reachability`. If the relationship it would emit strands the
player or gates a route nobody can open, it returns the Zone unchanged
and says why. A composer that could emit an unsolvable Zone would move
the failure to whoever ran the seed.
"""
from __future__ import annotations

from dataclasses import dataclass

from .schemas.zone import Zone
from .topology import reachability

#: How far along the spine to look for a setter. The relationship has to
#: sit inside the part of the Zone a player crosses early enough for the
#: consequence to be worth anything, and far enough in that the room is
#: not the entrance itself.
_SETTER_WINDOW = (1, 4)


@dataclass(frozen=True)
class Composed:
    """What the composer produced, and why it produced that."""
    zone: Zone
    #: `None` when nothing was emitted.
    variable_id: str | None
    #: Always populated -- the reason it emitted this, or declined.
    note: str

    @property
    def emitted(self) -> bool:
        return self.variable_id is not None


def _spine(zone: Zone) -> list[str]:
    """Rooms in composed order. `chambers` order IS the spine order."""
    return [c.id for c in zone.chambers]


def compose_zone_state(zone: Zone, *, variable_id: str = "span_alignment",
                       states: tuple[str, str] = ("stowed", "lowered"),
                       mechanism: str = "span_bolt",
                       entry_id: str | None = None,
                       exit_id: str | None = None,
                       declared_capabilities=None,
                       reader_order: str = "furthest") -> Composed:
    """Derive one cross-room relationship from a composed Zone.

    The shape is Blindside's: a control the player works in one room,
    a mechanism it moves in a later one, and the route between them
    closed until they go and work it.

    **The setter's capability comes from the Zone, not from a flag.**
    If the Zone features an acquisition, operating the control requires
    it -- which is the gantry: overhead, out of reach, and the reason
    the branch that supplies the tool exists. If it features none, the
    control needs nothing but the walk.

    **`reader_order`** (O05-04, a bounded addition by the engine lane for
    Dess's review; the default is unchanged). `"furthest"` is the policy
    this composer has always had. `"nearest"` puts the consequence in
    the first room past the gate, which keeps the reveal and the return
    together at the control's own junction. That is the relationship the
    owner asked to preserve "instead of maximizing walk distance"
    (O05-04.2). Both are validated the same way.
    """
    if reader_order not in ("furthest", "nearest"):
        raise ValueError(f"reader_order must be 'furthest' or 'nearest', "
                         f"not {reader_order!r}")
    rooms = _spine(zone)
    if len(rooms) < 4:
        return Composed(zone, None,
                        "fewer than four rooms; there is no room for a "
                        "setter and a consequence with a route between them")
    if getattr(zone, "zone_state", ()):
        return Composed(zone, None,
                        "the Zone already declares Zone state; this step "
                        "composes the first relationship, it does not "
                        "add to one")

    featured = getattr(zone, "featured_acquisition", None)
    needs = featured.capability if featured is not None else None

    lo, hi = _SETTER_WINDOW
    edges_by_pair = {frozenset(e.rooms): e for e in zone.edges}
    # The first refusal that is §29.5a's, if any: the one reason worth
    # naming, because it is a ruling rather than a geometry that did not
    # fit. This composer gates the spine, so the exit is always past its
    # gate: with a capability only this Zone hands over, it declines
    # until H-AP-GATE (owner ruling on DESS-28).
    ruled: str | None = None

    for si in range(lo, min(hi, len(rooms) - 2) + 1):
        setter_room = rooms[si]
        # THE GATE GOES ON THE EDGE THE PLAYER MEETS NEXT, and the
        # consequence lives past it. Both are read off the composed
        # graph: if these two rooms are not actually joined in this
        # Zone, there is no route to gate and the candidate is skipped.
        gated = edges_by_pair.get(frozenset({setter_room, rooms[si + 1]}))
        if gated is None:
            continue
        # ONE GATE PER DOORWAY (finding P5-1, O05). P14's composer already
        # refuses an edge that carries `requires_state`; this is the same
        # rule from the other side. Without it, composing D-8 after a
        # latch route put a second condition on the latch's own doorway,
        # sound in logic and two panels fighting over one opening in the
        # world.
        if gated.opened_by is not None or gated.requires_state:
            continue
        # FURTHEST FIRST. The point of the relationship is that it
        # spans the Zone, so the consequence wants to be as far from the
        # control as the Zone will validate. Taking the first candidate
        # that works would take the nearest, which is the weakest
        # arrangement that still technically crosses a boundary.
        order = (range(len(rooms) - 1, si, -1) if reader_order == "furthest"
                 else range(si + 1, len(rooms)))
        for ri in order:
            reader_room = rooms[ri]
            if reader_room == setter_room:
                continue
            candidate = _emit(zone, variable_id, states, mechanism,
                              setter_room, reader_room, gated.edge_id, needs)
            if candidate is None:
                continue
            reach = reachability(candidate, entry_id, exit_id,
                                 declared_capabilities)
            if ruled is None:
                ruled = next((e for e in reach.errors if "§29.5a" in e),
                             None)
            if reach.ok:
                return Composed(
                    candidate, variable_id,
                    f"control in '{setter_room}'"
                    + (f" needing '{needs}'" if needs else "")
                    + f", consequence in '{reader_room}', gating "
                    f"'{gated.edge_id}'")
    return Composed(zone, None,
                    "no placement validated: every candidate either "
                    "stranded the player or gated a route nothing opens"
                    + (f"; first by ruling: {ruled}" if ruled else ""))


def _emit(zone: Zone, variable_id, states, mechanism, setter_room,
          reader_room, edge_id, needs) -> Zone | None:
    """Build the candidate through the REAL schema, or give up on it.

    `model_validate` rather than `model_copy`, so every D-8 rule -- the
    remote consequence, the lifetime agreeing with what the setter can
    do, the rooms existing -- runs against what this function produced.
    A composer that skipped its own validators would be a composer whose
    output nobody had checked.
    """
    raw = zone.model_dump()
    raw["zone_state"] = [{
        "variable_id": variable_id,
        "states": list(states),
        "initial": states[0],
        "lifetime": "reversible",
        "setter": {"room_id": setter_room,
                   "selects": list(states),
                   "capability": needs},
        "readers": [{"room_id": reader_room, "mechanism": mechanism,
                     "when": [states[1]]}],
    }]
    for e in raw["edges"]:
        if e["edge_id"] == edge_id:
            e["requires_state"] = [{"variable_id": variable_id,
                                    "state": states[1]}]
    try:
        return Zone.model_validate(raw)
    except Exception:
        return None
