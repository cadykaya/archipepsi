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
    branched: int = 0
    nested: int = 0
    authored_junctions: int = 0
    two_door_authored: int = 0
    branch_counts: list[int] = field(default_factory=list)
    room_counts: list[int] = field(default_factory=list)
    #: Why a Zone did not branch, in its own words. A zero that says
    #: nothing is a zero nobody can act on.
    reasons: list[str] = field(default_factory=list)

    def line(self, label: str) -> str:
        return (f"{label}: {self.generated} generated, {self.accepted} "
                f"accepted, {len(self.refused)} refused, {self.fallback} "
                f"fallback; {self.branched} branched "
                f"({self.nested} with nesting), branches per Zone "
                f"{self.branch_counts}, authored junctions "
                f"{self.authored_junctions}; rooms {self.room_counts}"
                + (f"; not branching because {sorted(set(self.reasons))}"
                   if self.reasons else ""))


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
        joined = [e for e in zone.edges if e.realization == "JOINED"]
        spine_ids = {c.id for c in zone.chambers}
        locked = [d for c in zone.chambers for d in c.doors
                  if d.usage == "LOCKED"]
        tally.branch_counts.append(len(locked))
        if locked:
            tally.branched += 1
        # A NESTED branch is one whose junction is itself a branch
        # destination: the junction sits behind a locked door.
        behind = {e.room_b for e in joined
                  for c in zone.chambers if c.id == e.room_a
                  for d in c.doors
                  if d.edge_id == e.edge_id and d.usage == "LOCKED"}
        nested = [c for c in zone.chambers if c.id in behind
                  and any(d.usage == "LOCKED" for d in c.doors)]
        if nested:
            tally.nested += 1
        for c in zone.chambers:
            if not c.shell_id:
                continue
            if len(caps.get(c.shell_id, ())) >= 3:
                if c.door_degree >= 3:
                    tally.authored_junctions += 1
            else:
                tally.two_door_authored += 1
        tally.room_counts.append(len(zone.chambers))
        if not locked:
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

    So this asks the distribution question directly: over the declared
    inputs, ordinary generation has to produce branching, more than one
    branch in a Zone, and at least one branch off a branch.
    """
    async def go():
        tally = await _survey(tmp_path, C.DEFAULT_CONFIG, ZONES_PER_SCALE)
        print("\n" + tally.line("default"))
        assert tally.branched, (
            "no generated Zone branched; the composer is producing "
            "chains and every other test would still pass")
        assert max(tally.branch_counts) > 1, (
            f"no Zone got more than one branch: {tally.branch_counts}")
        assert tally.nested, "no Zone nested a branch off a branch"
    run(go())


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

        plan, notes = topology._branch_plan(chambers, caps)
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
