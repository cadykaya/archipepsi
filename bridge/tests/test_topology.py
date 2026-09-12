"""The Zone graph, and proving you can get around it.

Every test that asserts an ABSENCE is written to fail when the thing it
guards is removed, because a check that passes when its subject is
skipped is not evidence.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge import topology
from archipepsi_bridge.schemas.graph import (
    DoorAssignment, PlugAssignment, TopologyEdge, ZoneKeySpec)
from archipepsi_bridge.schemas.zone import Zone


def _arena(rid: str, width: float = 16.0, reward: int | None = None) -> dict:
    return {"id": rid, "type": "arena", "width": width, "depth": 15.0,
            "wall_height": 5.0, "objective": "kill_all",
            "reward_location_id": reward,
            "enemies": [{"archetype": "melee", "count": 1}]}


def _zone(chambers: list[dict], **kw) -> Zone:
    return Zone(zone_id="z1", display_name="Test", target_game="Test",
                theme="void_glitch", chambers=tuple(chambers), **kw)


def _chain_zone(n: int = 6) -> Zone:
    return _zone([_arena(f"c{i:03d}", reward=89100000 + i)
                  for i in range(1, n + 1)])


# --- production -----------------------------------------------------------

def test_a_zone_with_no_edges_still_means_the_chain_its_order_describes():
    """Additive and optional: nothing already in a save breaks."""
    z = _chain_zone()
    assert z.edges == () and z.plugs == ()
    assert all(c.doors == () for c in z.chambers)
    assert topology.reachability(z).ok


def test_the_chain_graph_says_out_loud_what_the_list_order_meant():
    z = _chain_zone(5)
    out = topology.apply(z, topology.compose_chain(list(z.chambers)))
    assert len(out.edges) == 4
    assert all(e.realization == "JOINED" for e in out.edges)
    first, last = out.chambers[0], out.chambers[-1]
    assert first.door_degree == 1 and last.door_degree == 1
    assert all(c.door_degree == 2 for c in out.chambers[1:-1])
    assert topology.reachability(out).ok, topology.reachability(out).errors


def test_every_unused_socket_is_sealed_and_never_unmentioned():
    """An unmentioned socket is how an unaudited hole gets into a wall."""
    z = _chain_zone(4)
    out = topology.apply(z, topology.compose_chain(list(z.chambers)))
    for c in out.chambers:
        assert {d.socket_id for d in c.doors} == {
            "entry", "exit", "side_left", "side_right"}
        assert any(d.usage == "SEALED" for d in c.doors)


def test_the_branch_producer_makes_a_junction_a_lock_and_a_way_back():
    z = _chain_zone(8)
    product = topology.compose_with_branch(list(z.chambers))
    out = topology.apply(z, product)

    # EVERY branch, not one: how many a Zone gets is derived from what it
    # can afford, so the invariants are stated per branch.
    locked = [(c, d) for c in out.chambers for d in c.doors
              if d.usage == "LOCKED"]
    assert locked, "an eight-room Zone can afford at least one branch"
    joined = [e for e in out.edges if e.realization == "JOINED"]
    for room, door in locked:
        # A junction carries the side door AND whatever else joins it.
        # Not a fixed 3: the first room has no inbound edge, and a NESTED
        # junction is reached by a branch rather than by the spine.
        others = [d for d in room.doors
                  if d.usage != "SEALED" and d.socket_id != door.socket_id]
        assert others, f"'{room.id}' is a junction off nothing"
        assert room.door_degree == len(
            [e for e in joined if room.id in e.rooms]), room.id
        assert door.key_id and door.colour, "a lock needs its key"

    # ONE WAY BACK PER BRANCH — counted off the branches, not off the
    # locks. Those were the same number while every branch was locked,
    # and an open branch needs its way home just as much.
    branch_edges = {d.edge_id for c in out.chambers for d in c.doors
                    if d.socket_id not in ("entry", "exit") and d.edge_id}
    assert len(out.plugs) == len(branch_edges), (
        sorted(branch_edges), [pl.room_id for pl in out.plugs])
    plug_edges = [e for e in out.edges if e.realization == "TRAVERSAL_ONLY"]
    assert len(plug_edges) == len(out.plugs)
    for plug in out.plugs:
        assert plug.destination == "zone_start"
        edge = next(e for e in plug_edges if e.edge_id == plug.edge_id)
        assert edge.direction == "A_TO_B", "a plug is one-way"

    # Distinct keys, so two branches are two decisions rather than one.
    ids = [d.key_id for _, d in locked]
    assert len(set(ids)) == len(ids), ids

    assert topology.reachability(out).ok, topology.reachability(out).errors


def test_an_unlocked_branch_is_a_real_branch_with_a_real_way_back():
    """A branch need not be locked, and an open one is not a lesser one.

    It is the same edge on the same socket with the same return plug;
    what it does not have is a key errand attached. Written because
    "every branch is locked" was true for so long that several checks
    counted locks and called the answer branches — including the one
    directly above this, which counted `len(out.plugs) == len(locked)`
    and would have passed forever while open branches went uncounted.
    """
    z = _chain_zone(20)
    out = topology.apply(z, topology.compose_with_branch(list(z.chambers)))
    side = [(c, d) for c in out.chambers for d in c.doors
            if d.socket_id not in ("entry", "exit") and d.usage != "SEALED"]
    open_side = [(c, d) for c, d in side if d.usage == "USED"]
    locked_side = [(c, d) for c, d in side if d.usage == "LOCKED"]
    assert open_side, "a 20-room Zone should outrun the four key colours"
    assert locked_side, "and should still lock the ones it can key"

    joined = {e.edge_id: e for e in out.edges if e.realization == "JOINED"}
    for room, door in open_side:
        assert door.key_id is None and door.colour is None, (
            f"'{room.id}/{door.socket_id}' is USED and carries a key")
        edge = joined[door.edge_id]
        far = edge.room_b if edge.room_a == room.id else edge.room_a
        assert any(pl.room_id == far for pl in out.plugs), (
            f"open branch to '{far}' has no way back")
    assert topology.reachability(out).ok, topology.reachability(out).errors


def test_one_colour_names_one_lock_in_a_zone():
    """Readable presentation: "the red door" names exactly one door.

    Two locks of one colour opened by different keys read as one lock
    and behave as two, which is the confusion that "more branches" must
    not be paid for with.
    """
    for n in (8, 12, 16, 20, 24):
        z = _chain_zone(n)
        out = topology.apply(z, topology.compose_with_branch(list(z.chambers)))
        locked = [d for c in out.chambers for d in c.doors
                  if d.usage == "LOCKED"]
        colours = [d.colour for d in locked]
        assert len(set(colours)) == len(colours), (n, colours)
        assert len({d.key_id for d in locked}) == len(locked), (n, locked)
        # And one key per lock, wherever it was put.
        spec = [k for c in out.chambers for k in c.keys]
        assert sorted(s.key_id for s in spec) == sorted(
            d.key_id for d in locked), (n, spec, locked)
        assert {s.colour for s in spec} == set(colours), n


def test_a_plug_consumes_no_joining_socket():
    """The whole reason PlugAssignment is not a DoorAssignment."""
    z = _chain_zone(8)
    out = topology.apply(z, topology.compose_with_branch(list(z.chambers)))
    plug = out.plugs[0]
    room = next(c for c in out.chambers if c.id == plug.room_id)
    carried_by_a_door = [d for d in room.doors if d.edge_id == plug.edge_id]
    assert not carried_by_a_door
    # And the room's door degree is its JOINED degree exactly — holding a
    # plug adds nothing. Counted off the edges rather than asserted as a
    # constant, because a destination may itself be a junction for a
    # nested branch and a hardcoded 1 would quietly stop testing this.
    joined = [e for e in out.edges
              if e.realization == "JOINED" and room.id in e.rooms]
    assert room.door_degree == len(joined), (
        room.id, room.door_degree, [e.edge_id for e in joined])


def test_a_zone_too_small_to_branch_returns_the_chain_rather_than_guessing():
    """A spine of `MIN_SPINE` has no room to spare, so every room is
    load-bearing for the chain and the note says which cost was not met
    rather than the Zone silently coming back unbranched."""
    z = _chain_zone(topology.MIN_SPINE)
    product = topology.compose_with_branch(list(z.chambers))
    assert all(e.realization == "JOINED" for e in product.edges)
    assert not product.plugs
    assert any("no branch" in n for n in product.notes)


# --- the invariants a schema can settle -----------------------------------

def test_a_door_naming_an_unknown_edge_is_refused():
    z = _chain_zone(3)
    payload = z.model_dump()
    payload["edges"] = [{"edge_id": "e:a", "room_a": "c001",
                         "room_b": "c002"}]
    payload["chambers"][0]["doors"] = [
        {"socket_id": "exit", "usage": "USED", "edge_id": "e:nope"}]
    with pytest.raises(ValueError, match="unknown edge"):
        Zone.model_validate(payload)


def test_a_traversal_only_edge_carried_by_a_door_is_refused():
    """The contradiction the engine lane caught, as a test."""
    z = _chain_zone(3)
    payload = z.model_dump()
    payload["edges"] = [{"edge_id": "p:x", "room_a": "c003",
                         "room_b": "c001", "direction": "A_TO_B",
                         "realization": "TRAVERSAL_ONLY"}]
    payload["chambers"][2]["doors"] = [
        {"socket_id": "exit", "usage": "USED", "edge_id": "p:x"}]
    with pytest.raises(ValueError, match="named by a door"):
        Zone.model_validate(payload)


def test_a_joined_edge_needs_a_door_at_both_ends():
    z = _chain_zone(3)
    payload = z.model_dump()
    payload["edges"] = [{"edge_id": "e:1", "room_a": "c001",
                         "room_b": "c002"}]
    payload["chambers"][0]["doors"] = [
        {"socket_id": "exit", "usage": "USED", "edge_id": "e:1"},
        {"socket_id": "entry", "usage": "SEALED"},
        {"socket_id": "side_left", "usage": "SEALED"},
        {"socket_id": "side_right", "usage": "SEALED"}]
    with pytest.raises(ValueError, match="named by 1 door"):
        Zone.model_validate(payload)


def test_a_lock_whose_key_no_room_holds_is_refused():
    z = _chain_zone(3)
    payload = z.model_dump()
    payload["edges"] = [{"edge_id": "e:1", "room_a": "c001",
                         "room_b": "c002"}]
    for i, sock in ((0, "exit"), (1, "entry")):
        payload["chambers"][i]["doors"] = [
            {"socket_id": sock, "usage": "LOCKED", "edge_id": "e:1",
             "key_id": "red"} if i == 0 else
            {"socket_id": sock, "usage": "USED", "edge_id": "e:1"},
        ] + [{"socket_id": s, "usage": "SEALED"}
             for s in ("entry", "exit", "side_left", "side_right")
             if s != sock]
    with pytest.raises(ValueError, match="which no room holds"):
        Zone.model_validate(payload)


def test_an_unmentioned_socket_is_refused():
    z = _chain_zone(3)
    payload = z.model_dump()
    payload["edges"] = [{"edge_id": "e:1", "room_a": "c001",
                         "room_b": "c002"}]
    payload["chambers"][0]["doors"] = [
        {"socket_id": "exit", "usage": "USED", "edge_id": "e:1"}]
    payload["chambers"][1]["doors"] = [
        {"socket_id": "entry", "usage": "USED", "edge_id": "e:1"}]
    with pytest.raises(ValueError, match="unmentioned"):
        Zone.model_validate(payload)


# --- reachability ---------------------------------------------------------

def test_a_key_behind_its_own_lock_is_caught():
    """The circular placement check 10 exists for."""
    z = _chain_zone(6)
    product = topology.compose_with_branch(list(z.chambers))
    out = topology.apply(z, product)
    assert topology.reachability(out).ok

    # Move the key into the room the lock guards.
    plug = out.plugs[0]
    moved = []
    for c in out.chambers:
        if c.keys:
            moved.append(c.model_copy(update={"keys": ()}))
        elif c.id == plug.room_id:
            moved.append(c.model_copy(update={
                "keys": (ZoneKeySpec(key_id="red", colour="red"),)}))
        else:
            moved.append(c)
    circular = out.model_copy(update={"chambers": tuple(moved)})
    result = topology.reachability(circular)
    assert not result.ok
    assert any("behind a lock only it opens" in e for e in result.errors)


def test_an_unreachable_check_is_caught():
    z = _chain_zone(6)
    out = topology.apply(z, topology.compose_chain(list(z.chambers)))
    # Seal the third room's entry: everything past it falls off the graph.
    broken = []
    for c in out.chambers:
        if c.id == "c003":
            # Its arrival selector goes with the door. Leaving it behind
            # is a different defect and `ChamberBase` now names it
            # first, which would make this test stop asking its own
            # question.
            broken.append(c.model_copy(update={"arrive_edge": None,
                                               "doors": tuple(
                d.model_copy(update={"usage": "SEALED", "edge_id": None})
                if d.socket_id == "entry" else d for d in c.doors)}))
        else:
            broken.append(c)
    with pytest.raises(ValueError, match="named by 1 door"):
        out.model_copy(update={"chambers": tuple(broken)}).model_validate(
            out.model_copy(update={"chambers": tuple(broken)}).model_dump())


def test_the_return_edge_participates_in_reachability():
    """A plug is not decoration: the search must cross it."""
    z = _chain_zone(8)
    out = topology.apply(z, topology.compose_with_branch(list(z.chambers)))
    plug = out.plugs[0]
    reach = topology.reachability(out)
    assert plug.room_id in reach.rooms

    # Remove the plug edge and the branch room becomes a place you can
    # enter and not leave except back through the lock — still fine here,
    # which is exactly why the plug's VALUE is not reachability alone.
    no_plug = out.model_copy(update={
        "edges": tuple(e for e in out.edges
                       if e.realization != "TRAVERSAL_ONLY"),
        "plugs": ()})
    assert topology.reachability(no_plug).ok

    # But make the lock one-way into the branch and the plug becomes the
    # only way out: without it, R is not a subset of E.
    one_way = no_plug.model_copy(update={"edges": tuple(
        e.model_copy(update={"direction": "A_TO_B"})
        if e.edge_id.startswith("e:") and e.room_b == plug.room_id else e
        for e in no_plug.edges)})
    assert not topology.reachability(one_way).ok
    assert any("R is not a subset of E" in m
               for m in topology.reachability(one_way).errors)


# --- the packet's three local-key rules -----------------------------------
#
# SOLUTIONS_CATALOGUE §2 names three, and each is testable by sabotage:
# build the broken shape and confirm the validator refuses it.

def _locked(z, room, socket, edge_id, key_id):
    """Turn one door into a lock, in place."""
    out = []
    for c in z.chambers:
        if c.id != room:
            out.append(c)
            continue
        out.append(c.model_copy(update={"doors": tuple(
            d.model_copy(update={"usage": "LOCKED", "key_id": key_id})
            if d.socket_id == socket else d for d in c.doors)}))
    return z.model_copy(update={"chambers": tuple(out)})


def _holds(z, room, key_id):
    out = []
    for c in z.chambers:
        out.append(c.model_copy(update={
            "keys": (ZoneKeySpec(key_id=key_id, colour="blue"),)})
            if c.id == room else c)
    return z.model_copy(update={"chambers": tuple(out)})


def test_rule_2_a_cyclic_key_graph_is_refused():
    """Red behind the blue door and blue behind the red one.

    Neither key is behind its OWN lock, so rule 1 does not see it. No
    order of collection opens the Zone.
    """
    z = _chain_zone(8)
    out = topology.apply(z, topology.compose_chain(list(z.chambers)))
    assert topology.reachability(out).ok

    # c003's entry needs red; c006's entry needs blue.
    e3 = next(e for e in out.edges if e.room_b == "c003")
    e6 = next(e for e in out.edges if e.room_b == "c006")
    out = _locked(out, "c003", "entry", e3.edge_id, "red")
    out = _locked(out, "c006", "entry", e6.edge_id, "blue")
    # blue sits past the red door; red sits past the blue one.
    rooms = {c.id: c for c in out.chambers}
    out = out.model_copy(update={"chambers": tuple(
        c.model_copy(update={"keys": (ZoneKeySpec(key_id="blue"),)})
        if c.id == "c004" else
        c.model_copy(update={"keys": (ZoneKeySpec(key_id="red"),)})
        if c.id == "c007" else c
        for c in out.chambers)})

    result = topology.reachability(out)
    assert not result.ok
    assert any("cycle" in e for e in result.errors), result.errors


def test_rule_3_an_undeclared_capability_gate_is_refused():
    """A key MAY sit behind Grapple. The Zone requiring Grapple while
    AP's logic does not say so is the divergence."""
    z = _chain_zone(8)
    out = topology.apply(z, topology.compose_chain(list(z.chambers)))
    gated = out.model_copy(update={"edges": tuple(
        e.model_copy(update={"capability": "grapple"})
        if e.room_b == "c005" else e for e in out.edges)})

    refused = topology.reachability(gated)
    assert not refused.ok
    assert any("does not declare" in e for e in refused.errors)

    # Declared by AP, the same Zone is fine: the gate is not the problem.
    allowed = topology.reachability(
        gated, declared_capabilities={"grapple"})
    assert allowed.ok, allowed.errors


def test_rule_3_ignores_a_gate_on_nothing_ap_relevant():
    """A capability gate that strands no Check and no exit is a
    shortcut, not a divergence."""
    z = _chain_zone(8)
    out = topology.apply(z, topology.compose_chain(list(z.chambers)))
    # An extra edge nothing depends on, gated.
    extra = type(out.edges[0])(
        edge_id="e:shortcut", room_a="c002", room_b="c006",
        realization="TRAVERSAL_ONLY", direction="A_TO_B",
        capability="blink")
    plug = PlugAssignment(edge_id="e:shortcut", room_id="c002",
                          source_anchor="room:c002:arrival",
                          destination="room:c006:arrival")
    shortcut = out.model_copy(update={"edges": out.edges + (extra,),
                                      "plugs": (plug,)})
    assert topology.reachability(shortcut).ok, \
        topology.reachability(shortcut).errors


def test_a_zone_local_key_gating_a_check_is_legal():
    """The distinction rule 3 turns on.

    A local key is obtainable inside the Zone, so Archipelago's claim —
    reach the Zone and you can reach its Checks — stays true with one
    behind a lock. The branch producer relies on this being true.
    """
    z = _chain_zone(8)
    out = topology.apply(z, topology.compose_with_branch(list(z.chambers)))
    locked = [(c.id, d.socket_id) for c in out.chambers
              for d in c.doors if d.usage == "LOCKED"]
    assert locked, "the branch producer should lock the branch"
    assert topology.reachability(out).ok


# --- gates the player cannot use are unavailable TOGETHER ------------------

def _gate(z, room_b, capability, edge_id=None):
    """Put a capability on the edge that arrives at `room_b`."""
    return z.model_copy(update={"edges": tuple(
        e.model_copy(update={"capability": capability})
        if (e.edge_id == edge_id if edge_id else e.room_b == room_b) else e
        for e in z.edges)})


def _shortcut(z, frm, to, capability):
    """A traversal-only bypass, gated."""
    extra = TopologyEdge(edge_id=f"e:{frm}:{to}:cut", room_a=frm,
                         room_b=to, realization="TRAVERSAL_ONLY",
                         direction="A_TO_B", capability=capability)
    plug = PlugAssignment(edge_id=extra.edge_id, room_id=frm,
                          source_anchor=f"room:{frm}:arrival",
                          destination=f"room:{to}:arrival")
    return z.model_copy(update={"edges": z.edges + (extra,),
                                "plugs": z.plugs + (plug,)})


def _chain8():
    z = _chain_zone(8)
    return topology.apply(z, topology.compose_chain(list(z.chambers)))


def test_two_undeclared_gates_do_not_validate_each_other():
    """Codex's case, and the one the old guard got exactly backwards.

    Gate the spine at c004 -> c005 behind grapple and add a blink
    shortcut c002 -> c006. Removing either edge alone leaves the other
    passable, so each route vouched for the other while a player holding
    neither reaches only c001-c004.
    """
    z = _shortcut(_gate(_chain8(), "c005", "grapple"),
                  "c002", "c006", "blink")
    result = topology.reachability(z)
    assert not result.ok, "a Zone nobody can finish was accepted"
    assert any("do not declare" in e or "does not declare" in e
               for e in result.errors), result.errors
    # and the reachable set really does stop at c004
    assert result.rooms == {"c001", "c002", "c003", "c004"}


def test_two_alternatives_needing_the_same_unavailable_capability():
    z = _shortcut(_gate(_chain8(), "c005", "grapple"),
                  "c002", "c006", "grapple")
    assert not topology.reachability(z).ok


def test_two_alternatives_needing_different_unavailable_capabilities():
    z = _shortcut(_gate(_chain8(), "c005", "grapple"),
                  "c002", "c006", "cross_long_gap")
    assert not topology.reachability(z).ok


def test_a_genuinely_ungated_alternative_is_accepted():
    """The control that stops the rule widening into refusing shortcuts."""
    z = _shortcut(_gate(_chain8(), "c005", "grapple"),
                  "c002", "c006", None)
    result = topology.reachability(z)
    assert result.ok, result.errors


def test_declaring_the_capability_makes_the_same_zone_legal():
    z = _shortcut(_gate(_chain8(), "c005", "grapple"),
                  "c002", "c006", "blink")
    ok = topology.reachability(
        z, declared_capabilities={"grapple", "blink"})
    assert ok.ok, ok.errors


def test_a_baseline_capability_is_not_a_gate():
    """`ranged_hit` is Static Pulse: permanent, and every player has it.

    Requiring AP progression logic for something the baseline already
    guarantees would refuse a Zone for a gate that does not exist.
    """
    z = _gate(_chain8(), "c005", "ranged_hit")
    result = topology.reachability(z)
    assert result.ok, result.errors
    assert "ranged_hit" in topology.guaranteed_capabilities()


def test_a_gate_before_a_key_is_caught_too():
    """Keys, Checks, the exit and return safety, all one exploration."""
    z = _chain_zone(8)
    z = topology.apply(z, topology.compose_with_branch(list(z.chambers)))
    holder = next(c.id for c in z.chambers if c.keys)
    gated = _gate(z, holder, "blink")
    result = topology.reachability(gated)
    assert not result.ok
    assert any("key-bearing" in e or "R is not a subset" in e
               for e in result.errors), result.errors


def test_a_room_no_capability_would_reach_is_named_as_simply_unreachable():
    """Mutation testing found this one: every reachability test so far
    stranded rooms behind a GATE, so the branch that says "not reachable
    at all" had never fired. The two blames are not interchangeable —
    one says declare the capability in AP logic, the other says the
    graph is broken — and a validator that only ever reaches the first
    would tell the engine to fix the wrong thing."""
    z = _chain8()
    # One middle edge walkable only backwards. No capability exists that
    # helps, so the strandedness survives granting every one of them.
    z = z.model_copy(update={"edges": tuple(
        e.model_copy(update={"direction": "B_TO_A"})
        if e.edge_id == "e:c004:c005" else e for e in z.edges)})
    result = topology.reachability(z)
    assert not result.ok
    assert any("not reachable at all" in e for e in result.errors), \
        result.errors
    assert not any("does not declare" in e for e in result.errors), (
        "no gate is involved; blaming AP logic would send the engine "
        "lane to fix a declaration that is not the problem")


# --- SOLUTIONS_CATALOGUE §0-bis condition 4, and what the escape check
# --- actually buys ---------------------------------------------------------
#
# THE CORRECTION. These tests previously claimed the escape check caught
# a trap that "satisfied every existing rule". It does not, and cannot:
# `R ⊆ E` asks whether the exit is reachable from every state, the
# escape check asks whether the entrance OR the exit is — and the first
# implies the second. No Zone exists that the escape check refuses and
# `R ⊆ E` accepts. The fixture offered as proof also deleted two spine
# edges, so the exit was unreachable from everywhere and three other
# rules fired first.
#
# What it adds is the distinction between the two failures, which
# `R ⊆ E` reports with one sentence: blocked but able to walk away
# (§0-bis's "NOT YET is good gameplay") versus blocked and stuck (the
# dead run the catalogue warns about).


def test_an_ordinary_zone_can_always_be_left():
    """The control. A rule that refuses everything is as broken as one
    that refuses nothing, and every composed Zone must pass this."""
    for z in (_chain8(), _shortcut(_chain8(), "c002", "c006", None)):
        result = topology.reachability(z)
        assert not any("not left" in e for e in result.errors), result.errors


def test_the_escape_check_never_refuses_what_r_subset_e_accepts():
    """The subsumption, asserted rather than assumed.

    This is the claim the earlier write-up got wrong, so it is a test
    now: across a family of deliberately broken Zones, no state is ever
    named as trapped without `R ⊆ E` also failing. If someone relaxes
    `R ⊆ E` — §0-bis does permit a gated exit — this test stops holding
    and the escape check stops being a backstop and starts being load
    bearing, which is exactly when it needs to be noticed.
    """
    broken = []
    z = _chain8()
    one_way = TopologyEdge(edge_id="e:c002:c007:drop", room_a="c002",
                           room_b="c007", realization="TRAVERSAL_ONLY",
                           direction="A_TO_B")
    broken.append(z.model_copy(update={"edges": tuple(
        e.model_copy(update={"capability": "blink"})
        if e.edge_id in ("e:c006:c007", "e:c007:c008") else e
        for e in z.edges) + (one_way,)}))
    broken.append(z.model_copy(update={"edges": tuple(
        e.model_copy(update={"direction": "B_TO_A"})
        if e.edge_id == "e:c004:c005" else e for e in z.edges)}))
    broken.append(_gate(_chain8(), "c005", "grapple"))
    broken.append(_chain8())

    for bad in broken:
        errors = topology.reachability(bad).errors
        if any("not left" in e for e in errors):
            assert any("R is not a subset of E" in e for e in errors), (
                "the escape check named a trap that R ⊆ E accepted; it is "
                "supposed to be strictly weaker", errors)


def test_a_trap_is_reported_as_a_trap_and_not_only_as_an_unreachable_exit():
    """What the check is FOR. The Zone is refused either way; this says
    the player is stuck rather than merely unable to finish."""
    z = _chain8()
    one_way = TopologyEdge(edge_id="e:c002:c007:drop", room_a="c002",
                           room_b="c007", realization="TRAVERSAL_ONLY",
                           direction="A_TO_B")
    z = z.model_copy(update={"edges": tuple(
        e.model_copy(update={"capability": "blink"})
        if e.edge_id in ("e:c006:c007", "e:c007:c008") else e
        for e in z.edges) + (one_way,)})
    errors = topology.reachability(z).errors
    assert any("R is not a subset of E" in e for e in errors), errors
    assert any("can be entered and not left" in e for e in errors), (
        "R ⊆ E already refuses this; the point of the escape line is to "
        "say the player cannot get back out either", errors)
    assert any("c007" in e for e in errors if "not left" in e)


def test_blocked_but_able_to_walk_away_is_not_reported_as_a_trap():
    """The other half of the distinction, and the case §0-bis is about.

    The exit is gated and the player does not hold the capability, so
    `R ⊆ E` refuses — correctly, the gate is undeclared. But they can
    walk back to the entrance, come back with it, and finish. Reporting
    that as a trap would call the intended gameplay a dead run.
    """
    z = _gate(_chain8(), "c008", "blink", edge_id="e:c007:c008")
    errors = topology.reachability(z).errors
    assert any("R is not a subset of E" in e for e in errors), errors
    assert not any("not left" in e for e in errors), errors


def test_declaring_the_capability_opens_the_way_back_out():
    """And the same Zone with the capability guaranteed is fine."""
    z = _chain8()
    z = z.model_copy(update={"edges": tuple(
        e.model_copy(update={"capability": "blink"})
        if e.edge_id == "e:c006:c007" else e for e in z.edges)})
    assert not topology.reachability(z).ok
    ok = topology.reachability(z, declared_capabilities=["blink"])
    assert ok.ok, ok.errors


def test_a_key_in_hand_counts_toward_getting_back_out():
    """The retreat search starts from the keys the player is holding at
    that point, not from nothing. A locked door behind you that your own
    key opens is not a trap, and a search that forgot the key would call
    it one.

    The gate on the exit is what makes the retreat matter at all: with
    the way forward open, walking out the far end is an escape and the
    door behind you never gets asked about.
    """
    z = _chain8()
    z = _holds(z, "c002", "red")
    z = _locked(z, "c004", "entry", "e:c003:c004", "red")
    z = _gate(z, "c008", "blink", edge_id="e:c007:c008")
    result = topology.reachability(z)
    assert not any("not left" in e for e in result.errors), result.errors
    assert not result.ok, "the undeclared gate is still a refusal"


# --- §11.2: which opening the chain arrives and departs through ----------
#
# `content_instantiator.socket_for_edge` reads `chamber.arrive_edge` /
# `chamber.depart_edge`, finds the door carrying that edge, and returns
# its socket; an empty answer is the legacy `entry`/`exit` fallback. The
# engine's half shipped at Prod's 7adc5e5 and nothing wrote the two
# fields, so every room fell through to the fallback and an authored
# junction would have been entered through the wrong opening.

def _resolve_like_the_engine(chamber: dict, key: str) -> str:
    """`socket_for_edge`, transcribed.

    Not an independent implementation and not a second topology: it is
    the consumer's own lookup — `godot/scripts/content/
    content_instantiator.gd::socket_for_edge` — written out so a test
    can assert what the ENGINE will resolve rather than what the bridge
    meant. `""` is the engine's empty answer, which is the legacy
    fallback.
    """
    want = chamber.get(key) or ""
    if not want:
        return ""
    for door in chamber.get("doors", []):
        if door.get("edge_id") != want or door.get("usage") == "SEALED":
            continue
        return door.get("socket_id", "")
    return ""


def _joined(a: str, sa: str, b: str, sb: str):
    edge = TopologyEdge(edge_id=f"e:{a}:{b}", room_a=a, room_b=b,
                        direction="BIDIRECTIONAL", realization="JOINED")
    return edge, (a, sa), (b, sb)


def _through(n: int, joins):
    """A Zone wired through named sockets on BOTH ends of every edge.

    A capability control, not ordinary generation: no shipped shell
    declares a third joinable socket, so the composer has no reason to
    put the chain anywhere but `entry`/`exit` today. What this asks is
    whether a non-default choice survives composition, the schema and
    the wire — because the day it does not, the failure is a room
    entered through the wrong wall and nothing saying so.
    """
    z = _chain_zone(n)
    edges, doors = [], {c.id: {} for c in z.chambers}
    arrivals, departures = {}, {}
    for a, sa, b, sb in joins:
        edge, (a, sa), (b, sb) = _joined(a, sa, b, sb)
        edges.append(edge)
        doors[a][sa] = DoorAssignment(socket_id=sa, usage="USED",
                                      edge_id=edge.edge_id)
        doors[b][sb] = DoorAssignment(socket_id=sb, usage="USED",
                                      edge_id=edge.edge_id)
        departures[a] = edge.edge_id
        arrivals[b] = edge.edge_id
    caps = topology._shell_sockets()
    return topology.apply(z, topology.GraphProduct(
        edges=tuple(edges),
        doors={c.id: topology._seal_the_rest(c, doors[c.id], caps)
               for c in z.chambers},
        keys={}, plugs=(), arrivals=arrivals, departures=departures))


def test_a_non_default_opening_survives_the_wire_and_names_its_edge():
    """The whole point of §11.2, end to end.

    c002's chain comes in through `side_left` and leaves through
    `side_right` — its `entry` and `exit` are sealed. Serialized,
    re-parsed, and then resolved the way the engine resolves it.
    """
    import json
    z = _through(4, [("c001", "exit", "c002", "side_left"),
                     ("c002", "side_right", "c003", "entry"),
                     ("c003", "exit", "c004", "entry")])
    wire = json.loads(z.model_dump_json())
    back = Zone.model_validate(wire)
    assert back == z, "the selectors did not survive a round trip"

    room = next(c for c in wire["chambers"] if c["id"] == "c002")
    assert room["arrive_edge"] == "e:c001:c002"
    assert room["depart_edge"] == "e:c002:c003"
    # AND THE ENGINE LANDS ON THE INTENDED OPENING, which is the claim
    # that matters. Both of c002's default sockets are sealed, so the
    # legacy fallback would have placed it at `entry` — a wall.
    assert _resolve_like_the_engine(room, "arrive_edge") == "side_left"
    assert _resolve_like_the_engine(room, "depart_edge") == "side_right"
    sealed = {d["socket_id"] for d in room["doors"] if d["usage"] == "SEALED"}
    assert {"entry", "exit"} <= sealed

    # And the ordinary rooms keep the legacy pair, so the fallback is
    # still what a two-door shell gets.
    first = next(c for c in wire["chambers"] if c["id"] == "c001")
    assert first["arrive_edge"] is None, "the first room arrives from outside"
    assert _resolve_like_the_engine(first, "depart_edge") == "exit"


def test_the_selectors_that_ordinary_generation_emits_resolve_to_its_doors():
    """Every room of every composed Zone, against the engine's lookup.

    The claim is not "the field is filled in" — it is that what the
    engine resolves from it is the socket the composer assigned. A
    selector that resolves to `""` is the legacy fallback taken
    silently, which is indistinguishable from the field never existing.
    """
    import json
    for n in (3, 6, 8, 12, 20):
        z = _chain_zone(n)
        for out in (topology.apply(z, topology.compose_chain(
                        list(z.chambers))),
                    topology.apply(z, topology.compose_with_branch(
                        list(z.chambers)))):
            wire = json.loads(out.model_dump_json())
            assert Zone.model_validate(wire) == out
            joined = {e.edge_id: e for e in out.edges
                      if e.realization == "JOINED"}
            for room in wire["chambers"]:
                for key, end in (("arrive_edge", "room_b"),
                                 ("depart_edge", "room_a")):
                    if room[key] is None:
                        continue
                    socket = _resolve_like_the_engine(room, key)
                    assert socket, (n, room["id"], key,
                                    "resolves to the legacy fallback")
                    door = next(d for d in room["doors"]
                                if d["socket_id"] == socket)
                    assert door["edge_id"] == room[key]
                    assert getattr(joined[room[key]], end) == room["id"]
            # THE ZONE'S OWN ENDS. The first room is arrived at from
            # outside the Zone and the last departs to the Hub, so
            # neither carries the selector for that direction.
            assert wire["chambers"][0]["arrive_edge"] is None
            last = wire["chambers"][-1]
            assert last["depart_edge"] is None, (n, last["id"])


def test_a_selector_naming_an_edge_this_room_does_not_carry_is_refused():
    """The engine answers `""` and falls back silently, so the bridge is
    the only place this can be caught."""
    z = _through(4, [("c001", "exit", "c002", "entry"),
                     ("c002", "exit", "c003", "entry"),
                     ("c003", "exit", "c004", "entry")])
    wire = z.model_dump()
    wire["chambers"][1]["arrive_edge"] = "e:c003:c004"
    with pytest.raises(ValueError, match="carries no open door onto it"):
        Zone.model_validate(wire)


def test_a_selector_pointing_the_wrong_way_down_its_edge_is_refused():
    """Arrival is the INBOUND edge (§11.1/§6.5). A room that named its
    outbound edge as its arrival would be placed by the opening it
    leaves through."""
    z = _through(4, [("c001", "exit", "c002", "entry"),
                     ("c002", "exit", "c003", "entry"),
                     ("c003", "exit", "c004", "entry")])
    wire = z.model_dump()
    wire["chambers"][1]["arrive_edge"] = "e:c002:c003"
    wire["chambers"][1]["depart_edge"] = "e:c001:c002"
    with pytest.raises(ValueError, match="the arrival is the inbound edge"):
        Zone.model_validate(wire)


def test_a_selector_naming_a_sealed_door_is_refused():
    """`socket_for_edge` skips SEALED doors, so a selector onto one
    resolves to the fallback — a filled-in field that does nothing."""
    z = _through(4, [("c001", "exit", "c002", "entry"),
                     ("c002", "exit", "c003", "entry"),
                     ("c003", "exit", "c004", "entry")])
    wire = z.model_dump()
    room = wire["chambers"][1]
    for door in room["doors"]:
        if door["socket_id"] == "entry":
            door["usage"], door["edge_id"] = "SEALED", None
    with pytest.raises(ValueError, match="carries no open door onto it"):
        Zone.model_validate(wire)


def test_a_selector_can_never_point_at_a_plug():
    """A plug realizes no geometry, so there is no opening to arrive
    through — and the route to that mistake is closed one step earlier.

    A selector must name an edge one of this room's own OPEN DOORS
    carries, and a door carrying a `TRAVERSAL_ONLY` edge is already
    refused. So the two rules compose: the reason the plug case cannot
    be built is checked here rather than assumed, because "it cannot
    happen" is the sentence that precedes it happening.
    """
    z = _chain_zone(8)
    out = topology.apply(z, topology.compose_with_branch(list(z.chambers)))
    plug = out.plugs[0]

    # One: no door may carry it.
    wire = out.model_dump()
    room = next(c for c in wire["chambers"] if c["id"] == plug.room_id)
    sealed = next(d for d in room["doors"] if d["usage"] == "SEALED")
    sealed["usage"], sealed["edge_id"] = "USED", plug.edge_id
    with pytest.raises(ValueError, match="TRAVERSAL_ONLY edge .* is named"):
        Zone.model_validate(wire)

    # Two: so naming it as an arrival is a selector onto no open door.
    wire = out.model_dump()
    room = next(c for c in wire["chambers"] if c["id"] == plug.room_id)
    room["arrive_edge"] = plug.edge_id
    with pytest.raises(ValueError, match="carries no open door onto it"):
        Zone.model_validate(wire)
