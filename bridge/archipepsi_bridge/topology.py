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

#: What a chain needs from any room: a way in and a way out.
#:
#: Not a capacity claim — the capacity of an authored room comes from
#: its catalogue entry (`shells.joinable_sockets`). This is the pair the
#: SPINE uses, and it is named here because a room that cannot offer
#: both cannot sit on a chain at all.
SPINE_SOCKETS = ("entry", "exit")

#: The shortest spine worth branching off: a way in, something between,
#: a way out. Below this every room is load-bearing for the chain.
MIN_SPINE = 3

#: The distinct locks a Zone can hold, which is the key-colour
#: vocabulary and not a number chosen here. `KeyColour` has four values;
#: a fifth branch would reuse a colour, and two doors of one colour are
#: one lock rather than two decisions.
BRANCH_COLOURS: tuple[str, ...] = ("red", "blue", "green", "gold")

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


def _shell_sockets() -> dict[str, tuple[str, ...]]:
    """`shell_id -> declared joinable sockets`, read once per compose."""
    from . import shells
    return shells.sockets_by_shell()


def _sockets_for(chamber, shell_sockets: dict[str, tuple[str, ...]]
                 ) -> tuple[str, ...]:
    """Which joining sockets this room actually declares.

    **Read, not assumed.** This returned a hardcoded `("entry", "exit")`
    for every authored shell, which was true of all twelve and is not a
    property of being authored. A shell declaring a third doorway would
    have been composed as a two-door room, its third opening never
    assigned and therefore SEALED by `_seal_the_rest` — the composer
    walling up geometry an artist had cut, with nothing anywhere saying
    so.

    A procedural room declares four because
    `chamber_builders.procedural_sockets` names four.
    """
    if not chamber.shell_id:
        return PROCEDURAL_SOCKETS
    declared = shell_sockets.get(chamber.shell_id)
    if declared is None:
        # BACKSTOP, unreachable through acceptance: `validate_zone`
        # refuses a `shell_id` outside `all_legal_shell_ids`, which is
        # derived from the same registry this map is. If that ever
        # loosens, the alternative to raising is inventing a socket
        # pair for a room nobody has measured — which is how a door
        # gets assigned to an opening that does not exist.
        raise ValueError(
            f"room '{chamber.id}' names shell '{chamber.shell_id}', "
            "which declares no sockets this composer can read; a shell "
            "with unknown openings cannot be given doors")
    return declared


def capacity_of(chamber, shell_sockets: dict[str, tuple[str, ...]]) -> int:
    """How many JOINED edges this room could carry.

    The count of what it declares, and nothing to do with whether it is
    authored. A plug consumes no socket (`Chamber.door_degree` counts
    JOINED edges only), so a return does not spend capacity and a
    dead end with a way home is still a dead end.
    """
    return len(_sockets_for(chamber, shell_sockets))


def _spare_sockets(chamber, shell_sockets: dict[str, tuple[str, ...]],
                   used: set[str]) -> tuple[str, ...]:
    """Declared sockets this room has not spent, in a stable order."""
    return tuple(s for s in _sockets_for(chamber, shell_sockets)
                 if s not in used)


def _seal_the_rest(chamber, used: dict[str, DoorAssignment],
                   shell_sockets: dict[str, tuple[str, ...]]
                   ) -> tuple[DoorAssignment, ...]:
    """Every socket this room declares, with the unused ones SEALED.

    An unmentioned socket is a contract violation, because "unmentioned"
    is exactly how an unaudited hole gets into a wall. A sealed door is
    measured with the expectation inverted, never skipped.
    """
    out = []
    for socket in _sockets_for(chamber, shell_sockets):
        if socket in used:
            out.append(used[socket])
        else:
            out.append(DoorAssignment(socket_id=socket, usage="SEALED"))
    return tuple(out)


def compose_chain(chambers, shell_sockets=None) -> GraphProduct:
    """The graph the list order always meant, now said out loud.

    This is not new topology. It is the existing chain written as edges
    so that everything downstream — reachability, the manifest, the
    engine's socket resolution — reads one representation instead of
    inferring one from a list index.
    """
    caps = _shell_sockets() if shell_sockets is None else shell_sockets
    edges: list[TopologyEdge] = []
    doors: dict[str, dict[str, DoorAssignment]] = {c.id: {} for c in chambers}
    unfit = [c.id for c in chambers
             if not set(SPINE_SOCKETS) <= set(_sockets_for(c, caps))]
    if unfit:
        # A room that cannot offer a way in AND a way out cannot sit on
        # a chain. Said rather than worked around: the alternative is
        # assigning an edge to a socket the room never declared.
        return GraphProduct(
            edges=(), doors={c.id: _seal_the_rest(c, {}, caps)
                             for c in chambers},
            keys={}, plugs=(),
            notes=("no chain: room(s) %s declare no entry/exit pair"
                   % unfit,))
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
        doors={c.id: _seal_the_rest(c, doors[c.id], caps) for c in chambers},
        keys={}, plugs=(),
        notes=("chain: %d rooms, %d edges" % (len(chambers), len(edges)),))


def _side_socket(chamber, spare: tuple[str, ...]) -> str | None:
    """Which spare socket a side door may use.

    For a procedural room this avoids the wall a raised deck hugs: a
    `left` band's deck reaches the left wall at `rise` — 1.79 m up for a
    2.19 m gallery, inside a standing capsule — so a doorway cut there
    has a floor slab across it at chest height. The engine carves the
    hole, the deck stands in it, and the layout is refused ("door
    'c009/side_left' is LOCKED and the engine measured it as solid").

    For an authored room there is nothing to avoid: the artist placed
    the openings, and every one they declared is one they meant.
    """
    band = getattr(chamber, "elevation", None)
    blocked = f"side_{band.side}" if band is not None else None
    for socket in spare:
        if socket != blocked:
            return socket
    return None


def _branch_plan(chambers, caps) -> tuple[list[tuple], tuple[str, ...]]:
    """Which rooms branch off which, and why the rest do not.

    Derived from what the Zone already has rather than from a template.
    Three things bound it, and each one is a real cost:

    * **The spine keeps its ends.** The first room is where the player
      arrives and the last is the exit; moving either onto a branch
      makes the exit a dead end behind a lock.
    * **A destination must be spare.** Every room pulled off the spine
      shortens it, and a spine below `MIN_SPINE` is not a Zone with a
      branch — it is a fork.
    * **A junction must have a socket to spare.** Capacity comes from
      the room's own declaration, so a two-door authored shell is never
      a junction and a four-socket procedural room can hold two
      branches. Nothing invents an opening.

    Returns `(plan, notes)` where each plan entry is
    `(junction_id, destination_chamber, socket, key_id, colour)`.
    """
    notes: list[str] = []
    order = [c.id for c in chambers]
    if len(chambers) < MIN_SPINE + 1:
        return [], ("no branch: %d rooms, a spine of %d needs every one"
                    % (len(chambers), MIN_SPINE),)

    # A destination has to be worth going to. An empty room that happens
    # to branch is a corridor with a lock on it.
    def worthwhile(c) -> bool:
        return bool(getattr(c, "reward_ids", ()) or getattr(c, "keys", ()))

    interior = [c for c in chambers[1:-1]]
    # THE SPINE KEEPS THE MAJORITY. Every room pulled onto a branch is a
    # room the route no longer passes through, so half the spare rooms
    # is the bound: an eight-room Zone gets up to two branches and stays
    # a journey with side rooms, rather than a three-room spine with
    # five spokes off it — which is what "every spare room" produced,
    # measured, on the first draft of this.
    affordable = min(max(0, len(chambers) - MIN_SPINE) // 2,
                     len(BRANCH_COLOURS))
    if not affordable:
        return [], ("no branch: %d rooms leaves %d spare over a spine of "
                    "%d, and a branch costs two" % (
                        len(chambers), max(0, len(chambers) - MIN_SPINE),
                        MIN_SPINE),)
    # FROM THE FAR END. Taking the earliest worthwhile rooms put every
    # junction near the entrance, which left nowhere ahead of it to put
    # the key — every key landed in the room the player spawns in, where
    # "is this key reachable before its lock" has no content. Branching
    # off the later spine leaves the early rooms to hold keys.
    destinations = [c for c in interior if worthwhile(c)][-affordable:]
    if not destinations:
        # THE CHAIN, INTACT. Affording a branch is not a reason to make
        # one: a detour to an empty room is a lock the player opens to
        # find nothing. The note says which of the three costs was not
        # met, and this one is "nowhere worth going" rather than "not
        # enough rooms" — a different fact, and the two were once
        # reported by the same sentence.
        return [], ("no branch: %d interior room(s), room for %d, none "
                    "carrying a Check or a key"
                    % (len(interior), affordable),)

    # Junctions are chosen from what STAYS on the spine, so a room can
    # be a junction or a destination and never both.
    taken = {c.id for c in destinations}
    used: dict[str, set[str]] = {c.id: set(SPINE_SOCKETS) for c in chambers}
    plan: list[tuple] = []

    for destination in destinations:
        # NESTING: a junction may be a room already reached by a branch,
        # which is what makes a branch off a branch possible at all.
        # Ordered by position so the choice is stable, and restricted to
        # rooms the player reaches BEFORE the destination on the spine.
        reached = [c for c in chambers
                   if c.id not in taken or c.id in
                   {p[1].id for p in plan}]
        candidates = [
            c for c in reached
            if order.index(c.id) < order.index(destination.id)
            and c.id != chambers[-1].id
            # NOT THE ROOM THE PLAYER ARRIVES IN. It has capacity — the
            # entry socket is the Zone's front door and its sides are
            # free — and a lock on it has nowhere its key could go but
            # the room the lock is in, which is a door and a key you
            # pick up in one breath. Found by a Zone of two-door
            # authored rooms branching anyway, off c001.
            and c.id != chambers[0].id
            and _spare_sockets(c, caps, used[c.id])]
        if not candidates:
            notes.append("room '%s' stays on the spine: no room before "
                         "it has a socket to spare" % destination.id)
            continue
        # THE NEAREST ROOM BEFORE IT, which is what makes nesting happen
        # where the shape already supports it: when the previous
        # destination sits immediately before this one and still has a
        # socket spare, the branch hangs off the branch. Preferring the
        # middle candidate instead produced zero nested branches at every
        # Zone size, because a spine room almost always won.
        junction = candidates[-1]
        socket = _side_socket(junction, _spare_sockets(
            junction, caps, used[junction.id]))
        if socket is None:
            notes.append("room '%s' stays on the spine: junction '%s' "
                         "has only its elevated wall spare"
                         % (destination.id, junction.id))
            continue
        used[junction.id].add(socket)
        # One colour per branch, never reused: the plan is capped at the
        # vocabulary above, so this cannot wrap.
        colour = BRANCH_COLOURS[len(plan)]
        plan.append((junction.id, destination, socket, colour, colour))
    if not plan:
        notes.append("no branch: no junction had capacity")
    elif len(plan) == len(BRANCH_COLOURS) and len(destinations) \
            >= len(BRANCH_COLOURS):
        # SAID OUT LOUD when the vocabulary is what bound the count, so
        # "every Zone got four" reads as a stated limit rather than a
        # template nobody noticed.
        notes.append("branch count capped by the %d key colours"
                     % len(BRANCH_COLOURS))
    return plan, tuple(notes)


def compose_with_branch(chambers, shell_sockets=None) -> GraphProduct:
    """The chain, with every room a junction can afford moved onto a
    locked branch off it.

    **Capacity decides, not authorship.** This used to consider only
    procedural rooms wide enough for a side door, because authored
    shells were assumed to be two-door. A room is a junction candidate
    when its own declared sockets leave one spare — so the day a
    three-door shell is authored it becomes usable without a line
    changing here, and until then a Zone of authored rooms composes as a
    chain and SAYS SO in its notes rather than branching silently.

    Returns the plain chain unchanged when nothing can be afforded, with
    a note naming which of the three costs was not met.
    """
    caps = _shell_sockets() if shell_sockets is None else shell_sockets
    base = compose_chain(chambers, caps)
    if not base.edges:
        return base

    plan, why = _branch_plan(chambers, caps)
    if not plan:
        return GraphProduct(
            *(base.edges, base.doors, base.keys, base.plugs),
            notes=base.notes + why)

    order = [c.id for c in chambers]
    moved = {d.id for _, d, _, _, _ in plan}
    spine = [rid for rid in order if rid not in moved]

    edges: list[TopologyEdge] = []
    doors: dict[str, dict[str, DoorAssignment]] = {c.id: {} for c in chambers}
    for a_id, b_id in zip(spine, spine[1:]):
        edge = TopologyEdge(
            edge_id=f"e:{a_id}:{b_id}", room_a=a_id, room_b=b_id,
            direction="BIDIRECTIONAL", realization="JOINED")
        edges.append(edge)
        doors[a_id]["exit"] = DoorAssignment(
            socket_id="exit", usage="USED", edge_id=edge.edge_id)
        doors[b_id]["entry"] = DoorAssignment(
            socket_id="entry", usage="USED", edge_id=edge.edge_id)

    plugs: list[PlugAssignment] = []
    keys: dict[str, tuple[ZoneKeySpec, ...]] = {}
    parent_of = {d.id: j for j, d, _, _, _ in plan}
    for index, (junction_id, destination, socket, key_id, colour) \
            in enumerate(plan):
        vault = TopologyEdge(
            edge_id=f"e:{junction_id}:{destination.id}", room_a=junction_id,
            room_b=destination.id, direction="BIDIRECTIONAL",
            realization="JOINED")
        edges.append(vault)
        doors[junction_id][socket] = DoorAssignment(
            socket_id=socket, usage="LOCKED", edge_id=vault.edge_id,
            key_id=key_id, colour=colour)
        doors[destination.id]["entry"] = DoorAssignment(
            socket_id="entry", usage="USED", edge_id=vault.edge_id)

        # The way back. A dead end that can only be left the way you came
        # is a dead end; one that carries a return is a place you chose
        # to visit. TRAVERSAL_ONLY, so it spends no socket and the room
        # keeps its JOINED degree of 1.
        plug_edge = TopologyEdge(
            edge_id=f"p:{destination.id}:start", room_a=destination.id,
            room_b=spine[0], direction="A_TO_B",
            realization="TRAVERSAL_ONLY")
        edges.append(plug_edge)
        plugs.append(PlugAssignment(
            edge_id=plug_edge.edge_id, room_id=destination.id,
            source_anchor=f"room:{destination.id}:arrival",
            destination="zone_start", device="pad"))

        # The key goes in a room the player passes BEFORE the junction,
        # which is the ordering `R ⊆ E` then proves rather than assumes.
        # WHERE THE KEY MAY GO: the spine before this junction. For a
        # NESTED junction — one that is itself a branch destination —
        # that means the spine before its parent, walked up until a
        # spine room is found. Anything later is a key behind the lock
        # it opens, which `R ⊆ E` would catch and which should never be
        # composed in the first place.
        anchor, seen = junction_id, set()
        while anchor not in spine and anchor not in seen:
            seen.add(anchor)
            anchor = parent_of.get(anchor, spine[0])
        reach = list(spine[:spine.index(anchor)]) if anchor in spine \
            else [spine[0]]
        # NOT THE ROOM YOU ARRIVE IN, where there is anywhere else. A key
        # lying at the player's feet on the first frame is a lock that
        # was never closed, and it makes "is this key reachable before
        # its lock" a question with no content — the first room is
        # reachable by definition.
        # Spread, not stacked: four keys in one room is four locks with
        # one errand. Deterministic, so two runs place them the same.
        choices = reach[1:] or reach or [spine[0]]
        holder = choices[index % len(choices)]
        keys[holder] = keys.get(holder, ()) + (
            ZoneKeySpec(key_id=key_id, colour=colour),)

    nested = sum(1 for j, _, _, _, _ in plan if j in moved)
    return GraphProduct(
        edges=tuple(edges),
        doors={c.id: _seal_the_rest(c, doors[c.id], caps) for c in chambers},
        keys=keys, plugs=tuple(plugs),
        notes=base.notes + why + (
            "branches: %d off %d junction(s), %d nested; spine %d rooms"
            % (len(plan), len({j for j, _, _, _, _ in plan}), nested,
               len(spine)),))


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



def _escapable(real: Reach, ways_out: frozenset[str], edges, doors_by_room,
               keys_by_room, have: frozenset[str]) -> tuple[str, ...]:
    """SOLUTIONS_CATALOGUE §0-bis condition 4, and **it never changes the
    verdict**. It says which KIND of failure a refused Zone has.

    **The correction.** An earlier version of this docstring, and the
    write-up that went with it, said condition 4 "had no rule" and that
    a one-way edge into a dead end "satisfied every check". Both were
    false, and the mistake is worth keeping written down because it is
    not a detail — it is a claim about what a new check bought, made
    without checking what the old ones already caught.

    `R ⊆ E` asks, of every reachable state, whether `exit ∈ onward`.
    This asks whether `{entry, exit} ∩ onward` is non-empty. The first
    condition IMPLIES the second, so **no Zone exists that this refuses
    and `R ⊆ E` accepts** — it is subsumed, by construction, not by
    coincidence. The fixture offered as proof was worse than redundant:
    it deleted two spine edges, so the exit was not merely unreachable
    from the trapped room, it was unreachable from anywhere, and three
    other rules fired first.

    **What it actually adds**, which is real and is why it stays: among
    the states `R ⊆ E` already refuses, it separates the two that matter
    to a player. "You cannot finish from here, and you can walk back to
    the entrance" is §0-bis's *NOT YET is good gameplay* — leave, find
    the capability, return. "You cannot finish and you cannot get back"
    is the dead run the catalogue warns about. `R ⊆ E` reports both with
    one sentence.

    **And it is a backstop.** §0-bis explicitly permits the Zone exit
    itself to sit behind a capability gate. The day `R ⊆ E` is relaxed
    to model a player who does not hold the item yet, this stops being
    subsumed and becomes the only thing between that player and a Zone
    they cannot leave. Deleting it now would delete the guard exactly
    when it is cheapest to keep.
    """
    trapped: dict[str, frozenset[str]] = {}
    memo: dict[tuple[str, frozenset[str]], bool] = {}
    for room, held in sorted(real.states, key=lambda st: (st[0], sorted(st[1]))):
        if room in ways_out:
            continue
        key = (room, held)
        if key not in memo:
            back = _explore(room, edges, doors_by_room, keys_by_room, have,
                            start_held=held)
            memo[key] = bool(back.rooms & ways_out)
        if not memo[key] and room not in trapped:
            trapped[room] = held
    if not trapped:
        return ()
    named = ", ".join(
        f"'{room}'" + (f" holding {sorted(held)}" if held else "")
        for room, held in sorted(trapped.items()))
    return (
        f"room(s) {named} can be entered and not left: no way back to "
        f"{sorted(ways_out)} from there. A capability gate the player "
        "cannot retreat past is not hard progression (§0-bis condition "
        "4); it is a Zone holding its Checks with the player stuck "
        "inside it",)

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
    4b. **Every room can be left again** — from any state the player can
       reach, the entrance or the exit is still reachable
       (SOLUTIONS_CATALOGUE §0-bis condition 4). A gate is allowed to
       stop you; it is not allowed to keep you.
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

    # §0-bis CONDITION 4. The catalogue calls this load-bearing and
    # nothing was enforcing it: every rule above asks whether the player
    # can get somewhere, and none asks whether they can get back. Both
    # the way in and the way out count as a way out — leaving by
    # finishing is still leaving.
    errors.extend(_escapable(real, frozenset({entry, exit_room}),
                             zone.edges, doors_by_room, keys_by_room,
                             have))

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
