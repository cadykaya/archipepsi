"""Producing the Zone graph, and proving you can get around it.

`09_ROOM_CONTRACT.md` Layer 2 production plus the logical half of §5.5.
Everything here is a graph question. **Nothing here touches geometry** —
whether a door is walkable, whether a key can physically be reached, and
where any room ends up are the engine's to measure and this module never
guesses at them.

Two halves:

* `compose_graph` turns a composed chamber list into edges, door
  assignments, keys and plugs.
* `reachability` answers the questions a composer has to answer before
  it may send a Zone: can the player reach the exit, every Check and
  every key, and is every key obtainable without passing its own lock.
"""

from __future__ import annotations

from dataclasses import dataclass, field

try:
    from .schemas.graph import (
        DoorAssignment, PlugAssignment, TopologyEdge, ZoneKeySpec)
    from .schemas import mechanics as M
    from .schemas.zone import PROCEDURAL_SOCKETS
except ImportError:  # pragma: no cover
    from schemas.graph import (
        DoorAssignment, PlugAssignment, TopologyEdge, ZoneKeySpec)
    from schemas import mechanics as M
    from schemas.zone import PROCEDURAL_SOCKETS

#: The two openings an authored shell declares. Every one of the twelve
#: authored shells is exactly `entry` + `exit`, so a shell room can carry
#: a chain and nothing more until three-door geometry is authored.
AUTHORED_SOCKETS = ("entry", "exit")

#: Wide enough to carry a side door without the opening landing on the
#: room's own furniture. Matches `Slice1Fixture.MIN_SPAN`, deliberately:
#: two lanes disagreeing about which rooms can branch is a defect that
#: only shows up as a wall in the wrong place.
MIN_JUNCTION_SPAN = 13.0


@dataclass(frozen=True)
class GraphProduct:
    """What a composer hands the engine, minus the chambers themselves."""

    edges: tuple[TopologyEdge, ...]
    doors: dict[str, tuple[DoorAssignment, ...]]
    keys: dict[str, tuple[ZoneKeySpec, ...]]
    plugs: tuple[PlugAssignment, ...]
    #: What the producer did and why, for a log rather than for logic.
    notes: tuple[str, ...] = ()


def _sockets_for(chamber) -> tuple[str, ...]:
    """Which joining sockets this room actually declares.

    An authored shell declares its openings in its manifest and all
    twelve declare two. A procedural room declares four, because
    `chamber_builders.procedural_sockets` names four.
    """
    return AUTHORED_SOCKETS if chamber.shell_id else PROCEDURAL_SOCKETS


def _seal_the_rest(chamber, used: dict[str, DoorAssignment]
                   ) -> tuple[DoorAssignment, ...]:
    """Every socket this room declares, with the unused ones SEALED.

    An unmentioned socket is a contract violation, because "unmentioned"
    is exactly how an unaudited hole gets into a wall. A sealed door is
    measured with the expectation inverted, never skipped.
    """
    out = []
    for socket in _sockets_for(chamber):
        if socket in used:
            out.append(used[socket])
        else:
            out.append(DoorAssignment(socket_id=socket, usage="SEALED"))
    return tuple(out)


def compose_chain(chambers) -> GraphProduct:
    """The graph the list order always meant, now said out loud.

    This is not new topology. It is the existing chain written as edges
    so that everything downstream — reachability, the manifest, the
    engine's socket resolution — reads one representation instead of
    inferring one from a list index.
    """
    edges: list[TopologyEdge] = []
    doors: dict[str, dict[str, DoorAssignment]] = {c.id: {} for c in chambers}
    for a, b in zip(chambers, chambers[1:]):
        edge = TopologyEdge(
            edge_id=f"e:{a.id}:{b.id}", room_a=a.id, room_b=b.id,
            direction="BIDIRECTIONAL", realization="JOINED")
        edges.append(edge)
        doors[a.id]["exit"] = DoorAssignment(
            socket_id="exit", usage="USED", edge_id=edge.edge_id)
        doors[b.id]["entry"] = DoorAssignment(
            socket_id="entry", usage="USED", edge_id=edge.edge_id)
    return GraphProduct(
        edges=tuple(edges),
        doors={c.id: _seal_the_rest(c, doors[c.id]) for c in chambers},
        keys={}, plugs=(),
        notes=("chain: %d rooms, %d edges" % (len(chambers), len(edges)),))


def compose_with_branch(chambers) -> GraphProduct:
    """The chain, with one room moved onto a locked branch off a junction.

    **The branch is logically real and not yet physically real.** The
    engine at `82d500f` still places rooms by walking a chain, so the
    branch room is currently built in line. Nothing here depends on that:
    the graph says what the topology *is*, and placement says where the
    rooms *go*, and the two become the same thing when the engine's
    placement lands. Sending the honest graph now is what lets that
    happen without a second migration.

    Returns the plain chain unchanged when the Zone has no room wide
    enough to be a junction, or too few rooms to spare one for a branch.
    """
    base = compose_chain(chambers)
    by_id = {c.id: c for c in chambers}

    # THE ENTRY AND THE EXIT STAY ON THE SPINE. Moving the last room onto
    # a branch makes the exit the dead end, which reads as sound to a
    # reachability search -- you are never stranded *at* the exit -- and
    # is a Zone whose exit is behind a lock with a plug next to it.
    interior = chambers[1:-1]
    wide = [c for c in interior
            if not c.shell_id
            and float(getattr(c, "width", 0.0) or 0.0) >= MIN_JUNCTION_SPAN]
    if len(wide) < 2 or len(chambers) < 5:
        return GraphProduct(
            *(base.edges, base.doors, base.keys, base.plugs),
            notes=base.notes + (
                "no branch: %d wide rooms, %d chambers" % (
                    len(wide), len(chambers)),))

    order = [c.id for c in chambers]
    # The junction is a wide room with a room after it to spare, and the
    # branch room is the LAST wide room, so the chain keeps its ends.
    branch = wide[-1]
    candidates = [c for c in wide[:-1]
                  if 0 < order.index(c.id) < order.index(branch.id) - 1]
    if not candidates:
        return GraphProduct(
            *(base.edges, base.doors, base.keys, base.plugs),
            notes=base.notes + ("no branch: no junction before the "
                                "branch room",))
    junction = candidates[len(candidates) // 2]

    # Re-wire: the chain skips the branch room, and the branch hangs off
    # the junction's side door behind a lock.
    edges: list[TopologyEdge] = []
    doors: dict[str, dict[str, DoorAssignment]] = {c.id: {} for c in chambers}
    spine = [rid for rid in order if rid != branch.id]
    for a_id, b_id in zip(spine, spine[1:]):
        edge = TopologyEdge(
            edge_id=f"e:{a_id}:{b_id}", room_a=a_id, room_b=b_id,
            direction="BIDIRECTIONAL", realization="JOINED")
        edges.append(edge)
        doors[a_id]["exit"] = DoorAssignment(
            socket_id="exit", usage="USED", edge_id=edge.edge_id)
        doors[b_id]["entry"] = DoorAssignment(
            socket_id="entry", usage="USED", edge_id=edge.edge_id)

    vault = TopologyEdge(
        edge_id=f"e:{junction.id}:{branch.id}", room_a=junction.id,
        room_b=branch.id, direction="BIDIRECTIONAL", realization="JOINED")
    edges.append(vault)
    # NOT ALWAYS `side_left`. A room's elevation band hugs one wall, and
    # a `left` band's deck reaches the left wall at `rise` -- 1.79 m up
    # for a 2.19 m gallery, which is inside a standing capsule. So the
    # doorway cut into that wall is a doorway with a floor slab across
    # it at chest height: the engine carves the hole, the deck stands in
    # it, and the bridge refuses the layout ("door 'c009/side_left' is
    # LOCKED and the engine measured it as solid").
    #
    # The junction has two side walls and a band uses at most one, so
    # there is always a free one to choose.
    band = getattr(junction, "elevation", None)
    side = "side_right" if band is not None and band.side == "left" \
        else "side_left"
    doors[junction.id][side] = DoorAssignment(
        socket_id=side, usage="LOCKED", edge_id=vault.edge_id,
        key_id="red", colour="red")
    doors[branch.id]["entry"] = DoorAssignment(
        socket_id="entry", usage="USED", edge_id=vault.edge_id)

    # The way back. A dead end that can only be left the way you came is
    # a dead end; a dead end that carries a return is a place you chose
    # to visit.
    plug_edge = TopologyEdge(
        edge_id=f"p:{branch.id}:start", room_a=branch.id,
        room_b=spine[0], direction="A_TO_B", realization="TRAVERSAL_ONLY")
    edges.append(plug_edge)
    plug = PlugAssignment(
        edge_id=plug_edge.edge_id, room_id=branch.id,
        source_anchor=f"room:{branch.id}:arrival",
        destination="zone_start", device="pad")

    # The key goes in a room the player passes BEFORE the junction, which
    # is the ordering `R ⊆ E` then proves rather than assumes.
    before = spine[:spine.index(junction.id)]
    holder = before[len(before) // 2] if before else spine[0]
    keys = {holder: (ZoneKeySpec(key_id="red", colour="red"),)}

    return GraphProduct(
        edges=tuple(edges),
        doors={c.id: _seal_the_rest(c, doors[c.id]) for c in chambers},
        keys=keys, plugs=(plug,),
        notes=(
            "branch: junction '%s', branch room '%s', key in '%s'"
            % (junction.id, branch.id, holder),
            "the branch is logically real; the engine still places a "
            "chain, so it is not yet physically off to one side",
        ))


def apply(zone, product: GraphProduct):
    """Return `zone` carrying `product`. The input is never mutated."""
    chambers = []
    for c in zone.chambers:
        chambers.append(c.model_copy(update={
            "doors": product.doors.get(c.id, ()),
            "keys": product.keys.get(c.id, ()),
        }))
    return zone.model_copy(update={
        "chambers": tuple(chambers),
        "edges": product.edges,
        "plugs": product.plugs,
    })

# --------------------------------------------------------------------------
# Reachability — the logical half, and only the logical half.
# --------------------------------------------------------------------------
#
# `R ⊆ E` is a GRAPH property over edges the bridge believes exist. It
# cannot see that a key stands inside a crate, on a ledge with no ramp, or
# behind a trim lip. **It is necessary and it is not sufficient**, and a
# previous revision of the contract treated it as both. Physical
# reachability is the engine's to define and prove; this module states
# the logical obligation and nothing more.
#
# **ONE EXPLORATION, AND IT KNOWS WHAT THE PLAYER HAS.** A previous
# version asked about capability gates by removing one edge at a time
# while leaving every other gate passable, so two undeclared gates each
# validated the other: remove the grapple route and the blink shortcut
# covers it, remove the blink shortcut and the grapple route covers it,
# and a Zone whose exit needs one of two things nobody has passed. Gates
# the player cannot use are unavailable TOGETHER or the question is not
# being asked.


@dataclass(frozen=True)
class Reach:
    """What a graph search can establish, and the errors it found."""

    #: Every `(room, keys)` the player can get into.
    states: frozenset[tuple[str, frozenset[str]]]
    #: Every room appearing in any reachable state.
    rooms: frozenset[str]
    errors: tuple[str, ...] = ()

    @property
    def ok(self) -> bool:
        return not self.errors


def guaranteed_capabilities(declared=None) -> frozenset[str]:
    """What a player is certain to have on an AP-relevant route.

    `BASELINE_CAPABILITIES` is the existing guarantee: Static Pulse is
    permanent, so `ranged_hit` needs no Archipelago progression logic
    behind it and an edge requiring it is not a gate at all. Anything
    Archipelago declares as a prerequisite joins it.
    """
    return frozenset(M.BASELINE_CAPABILITIES) | frozenset(declared or ())


def _door_on(doors_by_room, room: str, edge_id: str):
    for d in doors_by_room.get(room, ()):
        if d.edge_id == edge_id:
            return d
    return None


def _passable(edge, frm: str, held: frozenset[str], doors_by_room,
              ignore_keys: frozenset[str], have: frozenset[str]) -> bool:
    """Can the player cross `edge` from `frm`, holding `held` and `have`?

    `ignore_keys` names keys treated as never held, which is how "is this
    key obtainable without passing its own lock" is asked.

    `have` is the capability set the question is being asked under. An
    edge requiring something outside it is impassable — not skipped, not
    assumed, impassable — which is what makes two undeclared gates fail
    together instead of covering for each other.
    """
    if not edge.traversable(frm):
        return False
    if edge.capability and edge.capability not in have:
        return False
    if edge.realization == "TRAVERSAL_ONLY":
        return True          # a plug binds no geometry and carries no lock
    for side in edge.rooms:
        door = _door_on(doors_by_room, side, edge.edge_id)
        if door is None:
            return False     # an edge with no door is not a way through
        if door.usage == "SEALED":
            return False
        if door.usage == "LOCKED":
            key = door.key_id
            if key in ignore_keys or key not in held:
                return False
    return True


def _explore(start: str, edges, doors_by_room, keys_by_room,
             have: frozenset[str],
             ignore_keys: frozenset[str] = frozenset(),
             start_held: frozenset[str] = frozenset()) -> Reach:
    """Every `(room, keys)` reachable from `start`, under `have`.

    One function for both questions a search here ever asks — from the
    entrance empty-handed, and from a room mid-run with keys already in
    hand — because two of them drifted apart once already.
    """
    incident: dict[str, list] = {}
    for e in edges:
        incident.setdefault(e.room_a, []).append(e)
        incident.setdefault(e.room_b, []).append(e)

    def collect(room: str, held: frozenset[str]) -> frozenset[str]:
        got = {k.key_id for k in keys_by_room.get(room, ())}
        return held | (got - ignore_keys)

    first = (start, collect(start, start_held))
    seen = {first}
    queue = [first]
    while queue:
        room, held = queue.pop()
        for e in incident.get(room, ()):
            if not _passable(e, room, held, doors_by_room, ignore_keys,
                             have):
                continue
            nxt_room = e.other(room)
            nxt = (nxt_room, collect(nxt_room, held))
            if nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)
    return Reach(states=frozenset(seen),
                 rooms=frozenset(r for r, _ in seen))


def _key_graph_is_acyclic(zone, doors_by_room, keys_by_room,
                          have: frozenset[str]) -> list[str]:
    """SOLUTIONS_CATALOGUE §2 rule 2, asked directly.

    A key behind its own lock is caught by rule 1. A CHAIN is not the
    same shape: red behind the blue door and blue behind the red one
    leaves both rooms unreachable, and a search that only ever withholds
    one key at a time reports that as two unrelated failures rather than
    as the cycle it is.

    The graph here is `key -> the keys you must already hold to fetch
    it`, and a cycle in it is a Zone nobody can open.
    """
    where = {k.key_id: c.id for c in zone.chambers for k in c.keys}
    if len(where) < 2:
        return []          # one key cannot form a chain with itself
    entry = zone.chambers[0].id

    needs: dict[str, set[str]] = {}
    for key_id, room in where.items():
        blocking = set()
        for other in where:
            if other == key_id:
                continue
            got = _explore(entry, zone.edges, doors_by_room, keys_by_room,
                           have, ignore_keys=frozenset({other}))
            if room not in got.rooms:
                blocking.add(other)
        needs[key_id] = blocking

    out: list[str] = []
    seen: set[str] = set()
    for start in sorted(needs):
        stack = [(start, [start])]
        while stack:
            at, path = stack.pop()
            for nxt in sorted(needs.get(at, ())):
                if nxt == start:
                    loop = " -> ".join(path + [start])
                    if start not in seen:
                        seen.update(path)
                        out.append(
                            f"the key graph has a cycle: {loop}; no order "
                            "of collection opens it")
                elif nxt not in path:
                    stack.append((nxt, path + [nxt]))
    return out


def reachability(zone, entry_id: str | None = None,
                 exit_id: str | None = None,
                 declared_capabilities=None) -> Reach:
    """Prove you can get around this Zone, or say exactly why not.

    Five properties, each an outcome rather than a method:

    1. **The exit is reachable**, with what the player is guaranteed.
    2. **`R ⊆ E`** — from every state the player can get into, the exit
       is still reachable. This is what rejects a Zone that strands.
    3. **Every allocated Check sits in a reachable room.**
    4. **Every key is obtainable without passing its own lock**, and the
       key graph is acyclic.
    5. **Every capability gate on the way to any of the above is
       declared** in the matching Archipelago logic
       (SOLUTIONS_CATALOGUE §2 rule 3, `06` §29.5a, check 23).

    The fifth is not a separate pass. Everything above is searched with
    the capability set the player actually has, so an undeclared gate
    shows up as the thing it causes: an unreachable exit, a stranded
    Check, a key nobody can fetch. The diagnosis then says whether a gate
    was the reason, by asking the same question again with every gate
    open and reporting the difference.

    A Zone with no edges is the chain its list order describes and
    trivially satisfies all five; it is not searched.
    """
    if not zone.edges:
        return Reach(states=frozenset(), rooms=frozenset())

    chambers = list(zone.chambers)
    entry = entry_id or chambers[0].id
    exit_room = exit_id or chambers[-1].id
    doors_by_room = {c.id: c.doors for c in chambers}
    keys_by_room = {c.id: c.keys for c in chambers}

    have = guaranteed_capabilities(declared_capabilities)
    every = have | {e.capability for e in zone.edges if e.capability}
    undeclared = sorted(every - have)

    errors: list[str] = []
    real = _explore(entry, zone.edges, doors_by_room, keys_by_room, have)
    ideal = (real if not undeclared else
             _explore(entry, zone.edges, doors_by_room, keys_by_room,
                      every))

    def blame(what: str, rooms_needed) -> None:
        """Say what is unreachable, and whether a gate is why."""
        stranded = sorted(set(rooms_needed) - real.rooms)
        if not stranded:
            return
        by_gate = sorted(set(stranded) & ideal.rooms)
        if by_gate:
            errors.append(
                f"{what} {by_gate} are reachable only through capability "
                f"gate(s) {undeclared}, which the Archipelago logic does "
                "not declare; the physical graph and the logical graph "
                "would disagree about what is reachable")
        rest = sorted(set(stranded) - set(by_gate))
        if rest:
            errors.append(f"{what} {rest} are not reachable at all")

    blame("the exit", [exit_room])
    blame("Check-bearing room(s)",
          [c.id for c in chambers if c.reward_ids])
    blame("key-bearing room(s)", [c.id for c in chambers if c.keys])

    # R subset E, over STATES rather than rooms: a room you can stand in
    # holding the wrong keys is a different situation from the same room
    # holding the right ones, and only the state form catches it.
    stranded = []
    for room, held in sorted(real.states):
        if room == exit_room:
            continue
        onward = _explore(room, zone.edges, doors_by_room, keys_by_room,
                          have, start_held=held)
        if exit_room not in onward.rooms:
            stranded.append(f"{room} holding {sorted(held) or 'nothing'}")
    if stranded:
        errors.append(
            "R is not a subset of E; the exit is unreachable from: "
            + "; ".join(stranded[:4])
            + (f" (+{len(stranded) - 4} more)" if len(stranded) > 4 else ""))

    for c in chambers:
        for k in c.keys:
            # THE CIRCULAR CASE, ASKED DIRECTLY. Withhold the key and see
            # whether its own room still comes up; grant it for free and
            # see whether that is what unlocks it. A key you can only
            # fetch by already holding it is the defect, and it is a
            # different fault from a room nothing reaches.
            without = _explore(entry, zone.edges, doors_by_room,
                               keys_by_room, have,
                               ignore_keys=frozenset({k.key_id}))
            if c.id in without.rooms:
                continue
            granted = _explore(entry, zone.edges, doors_by_room,
                               keys_by_room, have,
                               start_held=frozenset({k.key_id}))
            if c.id in granted.rooms:
                errors.append(
                    f"key '{k.key_id}' is behind a lock only it opens; "
                    f"room '{c.id}' is reachable holding it and not "
                    "reachable without it")

    errors.extend(_key_graph_is_acyclic(zone, doors_by_room, keys_by_room,
                                        have))
    return Reach(states=real.states, rooms=real.rooms,
                 errors=tuple(errors))
