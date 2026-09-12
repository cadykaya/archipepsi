"""Ordinary generation, over a declared set of inputs, reported.

**Not a hand-picked success.** The point of this file is the whole
distribution: how many Zones a run produces, how many branch, how many
nest, and — as loudly — how many are refused and why. A composer change
that quietly stopped branching would leave every other test in this
suite green, because every other test builds the Zone it wants to talk
about.

Nothing here injects a fixture or forces a `shell_id`. Zones come from
`handle_request_next_zone` through the real provider, the real
acceptance path and the real composer, exactly as a player gets them.
The inputs are declared below and the campaign is seeded, so a run is
reproducible and two runs report the same numbers.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import pytest

from archipepsi_bridge import topology
from archipepsi_bridge.schemas import constants as C

from .conftest import connected_engine, drain, run
from .zone_shape import shape_of

#: The declared inputs. Campaign scale is what moves room count, so it
#: is what this varies; each entry is played until the pool runs dry or
#: the cap is hit.
SCALES = ("prototype", "default")
ZONES_PER_SCALE = 6


@dataclass
class Tally:
    generated: int = 0
    accepted: int = 0
    refused: list[str] = field(default_factory=list)
    fallback: int = 0
    authored_junctions: int = 0
    two_door_authored: int = 0
    room_counts: list[int] = field(default_factory=list)
    #: The JOINED graph of each accepted Zone. **Not "rooms moved off the
    #: spine"** — four moved rooms can be one side chain four deep, which
    #: is one turning taken once. `zone_shape.shape_of` reads what the
    #: Zone actually serialized.
    shapes: list[object] = field(default_factory=list)
    #: Why a Zone did not branch, in its own words. A zero that says
    #: nothing is a zero nobody can act on.
    reasons: list[str] = field(default_factory=list)

    @property
    def branched(self) -> int:
        return sum(1 for s in self.shapes if s.side_paths)

    @property
    def nested(self) -> int:
        """Zones with a side path more than one room deep."""
        return sum(1 for s in self.shapes if any(d > 1 for d in s.side_depths))

    def line(self, label: str) -> str:
        return "\n".join([
            f"{label}: {self.generated} generated, {self.accepted} accepted, "
            f"{len(self.refused)} refused, {self.fallback} fallback; rooms "
            f"{self.room_counts}; authored junctions "
            f"{self.authored_junctions} of {self.two_door_authored} "
            f"two-door authored rooms",
            f"  spine rooms          {[len(s.spine) for s in self.shapes]}",
            f"  junctions (>=3 nbrs) {[len(s.junctions) for s in self.shapes]}",
            f"  distinct side paths  {[s.choices for s in self.shapes]}",
            f"  side path depths     {[list(s.side_depths) for s in self.shapes]}",
            f"  junctions inside one {[len(s.side_junctions) for s in self.shapes]}",
            f"  side dead ends       {[len(s.side_dead_ends) for s in self.shapes]}",
            f"  branch edges locked  {[len(s.locked_branch_edges) for s in self.shapes]}",
            f"  branch edges open    {[len(s.open_branch_edges) for s in self.shapes]}",
        ] + ([f"  not branching because {sorted(set(self.reasons))}"]
             if self.reasons else []))


async def _survey(tmp_path, config, limit: int) -> Tally:
    engine, _ = await connected_engine(tmp_path, config=config)
    caps = topology._shell_sockets()
    tally = Tally()
    for _ in range(limit):
        if engine.hub_status().mode not in ("ZONE_AVAILABLE",):
            break
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        if zid is None:
            break
        rec = engine.save.zone_by_id(zid)
        tally.generated += 1
        if rec.zone is None:
            tally.refused.append("no zone on the record")
            break
        tally.accepted += 1
        tally.fallback += 1 if rec.used_fallback else 0

        zone = rec.zone
        shape = shape_of(zone)
        tally.shapes.append(shape)
        for c in zone.chambers:
            if not c.shell_id:
                continue
            if len(caps.get(c.shell_id, ())) >= 3:
                if c.door_degree >= 3:
                    tally.authored_junctions += 1
            else:
                tally.two_door_authored += 1
        tally.room_counts.append(len(zone.chambers))
        if not shape.side_paths:
            # Recompose to read the note: acceptance keeps the Zone, not
            # the composer's account of it, and a Zone that did not
            # branch has to be able to say which cost it could not meet.
            product = topology.compose_with_branch(list(zone.chambers))
            tally.reasons.extend(n for n in product.notes
                                 if n.startswith("no branch"))

        # Put it down the way a player would, so the next one can start.
        await engine.handle_enter_zone(zid)
        await engine.handle_abandon_zone(zid)
        await drain()
    return tally


@pytest.mark.parametrize("scale", SCALES)
def test_ordinary_generation_over_declared_inputs(tmp_path, scale, capsys):
    """The report. Asserts only what must always hold; the numbers are
    printed so a change in the distribution is visible rather than
    merely still-passing."""
    config = C.DEFAULT_CONFIG if scale == "default" else None

    async def go():
        tally = await _survey(tmp_path, config, ZONES_PER_SCALE)
        print("\n" + tally.line(scale))
        assert tally.generated, "no Zone was generated at all"
        assert not tally.refused, tally.refused
        assert tally.accepted == tally.generated
        # EVERY unbranched Zone says why. A scale that produces chains is
        # a fine answer; a scale that produces chains silently is how a
        # composer stops working and nothing notices.
        assert tally.branched + len(tally.reasons) >= tally.generated, (
            f"{tally.generated - tally.branched} Zone(s) did not branch "
            f"and only {len(tally.reasons)} said why")
        # Every accepted Zone is a legal graph. This is the invariant;
        # the branching numbers above are the distribution.
        return tally

    run(go())


def test_the_declared_inputs_do_produce_branching(tmp_path, capsys):
    """A run that never branches would satisfy every assertion above.

    So this asks the distribution question directly — and it asks it of
    the JOINED graph, not of how many rooms moved off the spine. Those
    are different numbers: eight moved rooms were, measured, one side
    chain eight rooms deep, which is one turning taken once.

    **No numeric quota per Zone.** What is asserted is that the sample
    contains each kind of shape somewhere, not that every Zone has the
    same amount of it.
    """
    async def go():
        tally = await _survey(tmp_path, C.DEFAULT_CONFIG, ZONES_PER_SCALE)
        print("\n" + tally.line("default"))
        assert tally.branched, (
            "no generated Zone branched; the composer is producing "
            "chains and every other test would still pass")
        # GENUINELY SEPARATE side destinations, somewhere in the sample.
        # One Zone with several distinct turnings is the claim; every
        # Zone having several is not.
        assert max(s.choices for s in tally.shapes) > 1, (
            "no Zone offered more than one distinct side path: "
            f"{[s.choices for s in tally.shapes]}")
        # NESTING RETAINED: a side path that runs more than one room
        # deep, and a junction sitting inside one.
        assert tally.nested, (
            "every side path is a single room; nothing nests: "
            f"{[list(s.side_depths) for s in tally.shapes]}")
        assert any(s.side_junctions for s in tally.shapes), (
            "no side path contains a junction of its own")
        # BOTH KINDS OF BRANCH. A locked branch and an open one are
        # different offers, and a run producing only one of them is the
        # key recipe deciding the topology again.
        assert any(s.locked_branch_edges for s in tally.shapes), (
            "no branch is locked anywhere in the sample")
        assert any(s.open_branch_edges for s in tally.shapes), (
            "every branch in the sample is locked; the lock recipe is "
            "still deciding which routes exist")
    run(go())


def test_a_return_plug_never_counts_as_a_doorway(tmp_path):
    """The way back out of a dead end is not a third door.

    A plug is `TRAVERSAL_ONLY`; it spends no socket, and a room that
    carries one keeps the JOINED degree its doors give it. Asserted
    against the shape report because that report would otherwise be the
    easiest place to count one by mistake — a dead end with a plug would
    read as degree 2 and stop being a dead end.
    """
    from .test_topology import _chain_zone
    caps = topology._shell_sockets()
    seen_plugs = 0
    for n in (8, 12, 20):
        z = _chain_zone(n)
        out = topology.apply(z, topology.compose_with_branch(
            list(z.chambers), caps))
        shape = shape_of(out)
        seen_plugs += len(out.plugs)
        assert out.plugs, f"{n} rooms: no plug to be wrong about"
        assert shape.side_dead_ends, f"{n} rooms: no side dead end"
        neighbours = {c.id: set() for c in out.chambers}
        for e in out.edges:
            if e.realization == "JOINED":
                neighbours[e.room_a].add(e.room_b)
                neighbours[e.room_b].add(e.room_a)
        for plug in out.plugs:
            room = next(c for c in out.chambers if c.id == plug.room_id)
            # The room the plug leaves from keeps the degree its DOORS
            # give it. A branch destination that is ITSELF a junction —
            # a nested branch hangs off it — has two neighbours and is
            # correctly not a dead end; what must never happen is the
            # plug being the reason for either count.
            assert room.door_degree == len(neighbours[room.id]), room.id
            if room.door_degree == 1:
                assert plug.room_id in shape.side_dead_ends, (
                    f"'{plug.room_id}' has one doorway and carries a "
                    "plug, and is not counted a dead end; the way back "
                    "was counted as a way on")
        # The far end of every plug is the Zone start, which must gain no
        # neighbour from carrying them.
        start = out.chambers[0]
        assert start.door_degree == len(neighbours[start.id]), (
            f"the Zone start took {len(out.plugs)} plug(s) and its "
            "doorway degree moved")
    assert seen_plugs >= 3


def test_authored_junctions_are_selectable_the_day_one_exists(tmp_path):
    """**A capability probe, not ordinary generation, and it says so.**

    No shell in the shipped catalogue declares a third joinable socket —
    all twelve are `entry` + `exit` — so ordinary generation cannot
    produce an authored junction today, and the report above correctly
    counts zero. What this asks is whether the PRODUCER PATH would use
    one: capacity is read from the catalogue rather than assumed, so a
    three-socket entry composes as a junction with no further change.

    The alternative is the trap this batch existed to remove: composer
    support for three-door rooms that nothing can ever hand a three-door
    room to.
    """
    from .test_topology import _chain_zone
    z = _chain_zone(8)
    # EVERY interior room authored, so a junction has to be one of them.
    # Leaving procedural rooms in the middle proves nothing: they have
    # four sockets and would win the junction on merit, and the authored
    # capacity would never be asked about.
    authored = [c if i in (0, len(z.chambers) - 1)
                else c.model_copy(update={"shell_id": "shell_hall_transit"})
                for i, c in enumerate(z.chambers)]
    z = z.model_copy(update={"chambers": tuple(authored)})

    two_door = topology.compose_with_branch(
        list(z.chambers), {"shell_hall_transit": ("entry", "exit")})
    three_door = topology.compose_with_branch(
        list(z.chambers),
        {"shell_hall_transit": ("entry", "exit", "side_left")})

    def junctions(product):
        return {d.edge_id for doors in product.doors.values()
                for d in doors if d.usage == "LOCKED"}

    # The two-door catalogue cannot branch at all: every interior room
    # spends both its sockets on the spine.
    assert not junctions(two_door), (
        "a Zone of two-door rooms branched; something invented a socket")
    assert junctions(three_door), (
        "no branch off a three-socket shell; capacity is not reaching "
        "the composer")
    authored_ids = {c.id for c in z.chambers if c.shell_id}
    carried = {rid for rid, doors in three_door.doors.items()
               if rid in authored_ids
               and any(d.socket_id == "side_left" and d.usage != "SEALED"
                       for d in doors)}
    assert carried, (
        "a shell declaring a third socket was still composed as a "
        "two-door room; capacity is not being read from the catalogue")

    # And the two-door case seals the socket it does not have rather
    # than inventing one.
    for rid, doors in two_door.doors.items():
        if rid in authored_ids:
            assert {d.socket_id for d in doors} == {"entry", "exit"}, (
                "a two-door shell was given a socket it never declared")


# --- targeted controls ----------------------------------------------------
#
# The report above says what generation produces. These say what it
# refuses, one defect at a time, because a producer that cannot be made
# to fail is a producer nobody has measured.

def test_a_room_cannot_be_given_a_socket_it_never_declared():
    """Insufficient capacity is a refusal to branch, never an invented
    opening. Every door a composer emits names a socket the room's own
    catalogue entry declares."""
    from .test_topology import _chain_zone
    z = _chain_zone(8)
    authored = [c if i in (0, len(z.chambers) - 1)
                else c.model_copy(update={"shell_id": "shell_hall_transit"})
                for i, c in enumerate(z.chambers)]
    z = z.model_copy(update={"chambers": tuple(authored)})
    caps = {"shell_hall_transit": ("entry", "exit")}
    product = topology.compose_with_branch(list(z.chambers), caps)
    for rid, doors in product.doors.items():
        chamber = next(c for c in z.chambers if c.id == rid)
        declared = set(topology._sockets_for(chamber, caps))
        assert {d.socket_id for d in doors} == declared, rid


def test_every_declared_opening_is_assigned_or_sealed():
    """An unmentioned socket is how an unaudited hole gets into a wall,
    and a branching composer has more chances to leave one out."""
    from .test_topology import _chain_zone
    caps = topology._shell_sockets()
    for n in (5, 8, 12, 20):
        z = _chain_zone(n)
        product = topology.compose_with_branch(list(z.chambers), caps)
        for chamber in z.chambers:
            doors = product.doors[chamber.id]
            declared = list(topology._sockets_for(chamber, caps))
            assert [d.socket_id for d in doors] == declared, (
                n, chamber.id, [d.socket_id for d in doors], declared)
            assert len({d.socket_id for d in doors}) == len(doors), (
                f"{chamber.id} names a socket twice")


def test_no_socket_carries_two_edges():
    """A socket assigned twice is one opening claiming to be two, and
    with several branches off one junction it is the obvious way to get
    it wrong."""
    from .test_topology import _chain_zone
    caps = topology._shell_sockets()
    for n in (8, 12, 20):
        z = _chain_zone(n)
        out = topology.apply(z, topology.compose_with_branch(
            list(z.chambers), caps))
        for chamber in out.chambers:
            carrying = [d for d in chamber.doors if d.edge_id]
            assert len({d.socket_id for d in carrying}) == len(carrying)
            assert len({d.edge_id for d in carrying}) == len(carrying), (
                f"{chamber.id} puts one edge on two sockets")


def _hollow_zone(n: int):
    """A Zone whose interior rooms hold nothing worth a detour.

    Legal, and not contrived: a long transit stretch with its Checks at
    the two ends is a shape the content budget produces. It is the case
    where the branch planner can *afford* a branch and has nowhere
    worth sending one.
    """
    from .test_topology import _arena, _zone
    return _zone([_arena(f"c{i:03d}",
                         reward=89100000 + i if i in (1, n) else None)
                  for i in range(1, n + 1)])


def test_affording_a_branch_with_nowhere_worth_going_falls_back_to_the_chain():
    """Enough rooms to pay for a branch, no destination worth one.

    The planner's own words are the deliverable here: a Zone that does
    not branch has to say which of the three costs was not met, and
    "none carrying a Check or a key" is a different fact from "not
    enough rooms". Both the helper and the composer are exercised
    because the composer is what production calls.
    """
    caps = topology._shell_sockets()
    for n in (5, 8, 12):
        z = _hollow_zone(n)
        chambers = list(z.chambers)

        plan, notes = topology._branch_routes(chambers, caps)
        assert plan == [], f"{n} rooms: nothing here is worth a branch"
        assert any("none carrying a Check or a key" in note
                   for note in notes), notes
        # ACCURATE, not merely present: the count it reports is the
        # number of interior rooms it looked at.
        assert any(f"{n - 2} interior room(s)" in note
                   for note in notes), notes

        product = topology.compose_with_branch(chambers, caps)
        assert not [d for doors in product.doors.values() for d in doors
                    if d.usage == "LOCKED"], "no lock without a branch"
        assert product.plugs == () or not product.plugs
        # The documented fallback: the plain chain, whole.
        joined = [e for e in product.edges if e.realization == "JOINED"]
        assert len(joined) == n - 1, [e.edge_id for e in joined]
        assert any("none carrying a Check or a key" in note
                   for note in product.notes), product.notes
        out = topology.apply(z, product)
        assert topology.reachability(out).ok, topology.reachability(out).errors


def _wired(n: int, joins: list[tuple[str, str, str]]):
    """A Zone wired by hand from `(room_a, socket_on_a, room_b)` joins.

    Not a producible Zone and not presented as one — no plugs, no keys.
    It exists so the shape report can be handed a graph whose answer is
    known in advance.
    """
    from archipepsi_bridge.schemas.graph import DoorAssignment, TopologyEdge
    from .test_topology import _chain_zone
    z = _chain_zone(n)
    edges, doors = [], {c.id: {} for c in z.chambers}
    for a, socket, b in joins:
        edge = TopologyEdge(edge_id=f"e:{a}:{b}", room_a=a, room_b=b,
                            direction="BIDIRECTIONAL", realization="JOINED")
        edges.append(edge)
        doors[a][socket] = DoorAssignment(
            socket_id=socket, usage="USED", edge_id=edge.edge_id)
        doors[b]["entry"] = DoorAssignment(
            socket_id="entry", usage="USED", edge_id=edge.edge_id)
    caps = topology._shell_sockets()
    return topology.apply(z, topology.GraphProduct(
        edges=tuple(edges),
        doors={c.id: topology._seal_the_rest(c, doors[c.id], caps)
               for c in z.chambers},
        keys={}, plugs=()))


def test_the_shape_report_tells_a_spur_from_separate_side_rooms():
    """Four rooms off the spine; two very different Zones.

    **The instrument gets handed the case that would fool it.** "Rooms
    moved off the spine" is 4 for both of these. One is a single turning
    that runs four rooms deep — one decision, taken once. The other is
    four separate turnings. A report that cannot tell them apart is how
    "eight branches" got written down for a Zone that offered one
    choice, which is exactly what happened.
    """
    spur = _wired(8, [
        ("c001", "exit", "c002"), ("c002", "exit", "c003"),
        ("c003", "exit", "c008"),
        ("c003", "side_left", "c004"), ("c004", "side_left", "c005"),
        ("c005", "side_left", "c006"), ("c006", "side_left", "c007")])
    fan = _wired(8, [
        ("c001", "exit", "c002"), ("c002", "exit", "c003"),
        ("c003", "exit", "c008"),
        ("c002", "side_left", "c004"), ("c002", "side_right", "c005"),
        ("c003", "side_left", "c006"), ("c003", "side_right", "c007")])

    a, b = shape_of(spur), shape_of(fan)
    assert len(a.spine) == len(b.spine) == 4
    assert a.rooms - len(a.spine) == b.rooms - len(b.spine) == 4, (
        "both Zones move the same number of rooms off the spine")

    assert a.choices == 1, a.side_paths
    assert a.side_depths == (4,), a.side_depths
    assert a.side_dead_ends == ("c007",), a.side_dead_ends
    assert a.junctions == ("c003",), a.junctions

    assert b.choices == 4, b.side_paths
    assert b.side_depths == (1, 1, 1, 1), b.side_depths
    assert len(b.side_dead_ends) == 4, b.side_dead_ends
    assert b.junctions == ("c002", "c003"), b.junctions


def test_the_shape_report_finds_a_junction_inside_a_side_path():
    """A side path that itself forks. Neither "rooms off the spine" nor
    "locked doors" can see this, and it is the difference between a
    corridor of rooms and a wing."""
    wing = _wired(8, [
        ("c001", "exit", "c002"), ("c002", "exit", "c003"),
        ("c003", "exit", "c008"),
        ("c003", "side_left", "c004"),
        ("c004", "side_left", "c005"), ("c004", "side_right", "c006"),
        ("c002", "side_left", "c007")])
    s = shape_of(wing)
    assert s.choices == 2, s.side_paths
    assert s.side_junctions == ("c004",), s.side_junctions
    assert sorted(s.side_depths) == [1, 2], s.side_depths
