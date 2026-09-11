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

    junction = [c for c in out.chambers if c.door_degree == 3]
    assert len(junction) == 1, "exactly one three-door room"
    locked = [d for d in junction[0].doors if d.usage == "LOCKED"]
    assert len(locked) == 1 and locked[0].key_id == "red"

    assert len(out.plugs) == 1
    plug = out.plugs[0]
    assert plug.destination == "zone_start"
    plug_edges = [e for e in out.edges if e.realization == "TRAVERSAL_ONLY"]
    assert len(plug_edges) == 1
    assert plug_edges[0].edge_id == plug.edge_id
    assert plug_edges[0].direction == "A_TO_B", "a plug is one-way"

    assert topology.reachability(out).ok, topology.reachability(out).errors


def test_a_plug_consumes_no_joining_socket():
    """The whole reason PlugAssignment is not a DoorAssignment."""
    z = _chain_zone(8)
    out = topology.apply(z, topology.compose_with_branch(list(z.chambers)))
    plug = out.plugs[0]
    room = next(c for c in out.chambers if c.id == plug.room_id)
    carried_by_a_door = [d for d in room.doors if d.edge_id == plug.edge_id]
    assert not carried_by_a_door
    # and the branch room's door budget is unaffected by holding a plug
    assert room.door_degree == 1


def test_a_zone_too_small_to_branch_returns_the_chain_rather_than_guessing():
    z = _chain_zone(4)
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
            broken.append(c.model_copy(update={"doors": tuple(
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
