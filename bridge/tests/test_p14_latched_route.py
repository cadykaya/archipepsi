"""P14 — a room-graph latch opens a route, persists, and is checked.

Prod built LATCH in `signal_graph.gd` and it was unreachable from a
declaration: `SUPPORTED_NODE_KINDS` was `("NOT",)`, and
`transitions.record_latch` accepted only physics packages, so a latch
that fired was answered "Zone accepted no physics package 'graph_c001'"
and lost on reload (`docs/D10_P14_PROD_ANSWER.md` §3). This is the
bridge half: the declaration, the route search, and the record.

**WHAT IS NOT HERE.** Walking in, stepping on the plate, stepping off,
walking through and finding it still open after a reload is Prod's
played acceptance, and nothing below stands in for it.
"""
from __future__ import annotations

import pytest

from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.zone import Zone
from archipepsi_bridge.topology import reachability

_COMPOSED: list = []


def composed() -> Zone:
    """The really-composed Zone, built once."""
    if not _COMPOSED:
        from archipepsi_bridge.playtest import played_zone
        zone = played_zone()
        assert zone is not None, "the composition path produced no Zone"
        _COMPOSED.append(zone)
    return _COMPOSED[0]


def latched_route(*, plate_side: str = "near", edge_index: int = 0) -> Zone:
    """`plate -> LATCH -> shutter`, opening one edge of a composed Zone.

    `near` puts the plate in the room the entrance side reaches first;
    `far` puts it past the door it opens.
    """
    zone = composed()
    raw = zone.model_dump()
    edge = raw["edges"][edge_index]
    room = edge["room_a"] if plate_side == "near" else edge["room_b"]
    raw["room_graphs"] = [{
        "room_id": room,
        "sensors": [{"node_id": "step_plate", "kind": "PRESSURE_PLATE",
                     "requires_class": "MEDIUM", "counts_player": True}],
        "nodes": [{"node_id": "held", "kind": "LATCH",
                   "inputs": ["step_plate"]}],
        "actuators": [{"actuator_id": "route_shutter", "driven_by": "held"}],
    }]
    edge["opened_by"] = "route_shutter"
    return Zone.model_validate(raw)


# --------------------------------------------------------------------------
# The route search
# --------------------------------------------------------------------------

def test_the_composed_zone_is_sound_before_anything_is_added():
    """The control: every error below has to be caused by the latch."""
    assert reachability(composed()).ok, reachability(composed()).errors


def test_a_latch_on_the_near_side_opens_a_sound_route():
    zone = latched_route(plate_side="near")
    reach = reachability(zone)
    assert reach.ok, reach.errors
    assert zone.edges[0].room_b in reach.rooms


def test_a_trigger_behind_the_route_it_opens_is_refused_by_name():
    """The plate past the door it opens: the rooms beyond are
    unreachable, and the message has to say WHY rather than only that."""
    reach = reachability(latched_route(plate_side="far"))
    assert not reach.ok
    assert any("the trigger is behind the route it opens" in e
               for e in reach.errors), reach.errors


def test_the_latch_actually_gates_the_edge_in_the_search():
    """Sabotage: without the latch modelling, a far-side plate would
    look fine -- the edge would read as an ordinary open door. Proved by
    asking the search with the latch pre-set: everything opens."""
    from archipepsi_bridge import topology as TP
    zone = latched_route(plate_side="far")
    searched, triggers = TP._route_latches(zone)
    assert triggers, "the latch-opened edge was not modelled at all"
    (_, plate_room, ref), = triggers
    assert ref == f"graph_{plate_room}/held"
    edge = next(e for e in searched.edges if e.edge_id == zone.edges[0].edge_id)
    assert [c.variable_id for c in edge.requires_state][-1] == ref


def test_a_denial_chain_adds_no_condition():
    """`plate -> NOT -> shutter` rests open: the player can leave the
    plate alone, so the search must not make the edge wait on anything."""
    from archipepsi_bridge import topology as TP
    raw = composed().model_dump()
    edge = raw["edges"][0]
    raw["room_graphs"] = [{
        "room_id": edge["room_b"],
        "sensors": [{"node_id": "step_plate", "kind": "PRESSURE_PLATE",
                     "requires_class": "MEDIUM", "counts_player": True}],
        "nodes": [{"node_id": "inverted", "kind": "NOT",
                   "inputs": ["step_plate"]}],
        "actuators": [{"actuator_id": "route_shutter",
                       "driven_by": "inverted"}],
    }]
    edge["opened_by"] = "route_shutter"
    zone = Zone.model_validate(raw)
    _, triggers = TP._route_latches(zone)
    assert triggers == ()
    assert reachability(zone).ok


def test_the_latch_is_permanent_in_the_search_as_it_is_in_the_runtime():
    """Modelled as a permanent variable: set once in the plate's room,
    never back. The same lifetime Prod's latch has, and never the
    reversible kind -- so no search state closes a route it opened."""
    from archipepsi_bridge import topology as TP
    searched, _ = TP._route_latches(latched_route())
    latch = searched.zone_state[-1]
    assert latch.lifetime == "permanent"
    assert latch.initial == "unset" and latch.setter.selects == ("set",)
    assert latch.setter.capability is None


# --------------------------------------------------------------------------
# The record
# --------------------------------------------------------------------------

def _save(zone: Zone, *, committed: bool = True,
          placed: tuple[str, ...] | None = None) -> P.CampaignSave:
    # The composed Zone is default-scale, so the campaign has to be big
    # enough to own the locations it allocates -- and one more, because
    # the campaign's last location is the finale's and no other Zone's.
    top = max(zone.reward_location_ids) - 89100000
    save = P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        scale=P.CampaignScale(location_count=max(top + 1, 30),
                              zone_target_checks=15, zone_budget=1000))
    save = T.start_generation(
        save, zone_id=zone.zone_id,
        allocated_location_ids=tuple(zone.reward_location_ids),
        target_game=zone.target_game)
    save = T.enter_zone(T.accept_zone(save, zone), zone.zone_id)
    if committed:
        rooms = [c.id for c in zone.chambers] if placed is None else placed
        save = T.commit_layout(save, zone.zone_id, {
            "zone_id": zone.zone_id, "manifest_digest": "d" * 16,
            "rooms": {r: {} for r in rooms}, "packages": []})
    return save


def _plate_room(zone: Zone) -> str:
    return zone.room_graphs[0].room_id


def test_a_declared_room_graph_latch_is_recorded():
    zone = latched_route()
    room = _plate_room(zone)
    save = T.record_latch(_save(zone), zone.zone_id, f"graph_{room}", "held")
    assert save.zone_by_id(zone.zone_id).progress.latched == (
        f"graph_{room}/held",)


def test_recording_it_twice_is_recording_it_once():
    zone = latched_route()
    ref = f"graph_{_plate_room(zone)}"
    once = T.record_latch(_save(zone), zone.zone_id, ref, "held")
    assert T.record_latch(once, zone.zone_id, ref, "held") is once


@pytest.mark.parametrize("package,latch,says", [
    ("graph_{room}", "no_such_latch", "declares no LATCH 'no_such_latch'"),
    ("graph_c999", "held", "placed no room 'c999'"),
])
def test_a_graph_name_alone_authorizes_nothing(package, latch, says):
    zone = latched_route()
    with pytest.raises(ValueError, match=says):
        T.record_latch(_save(zone), zone.zone_id,
                       package.format(room=_plate_room(zone)), latch)


def test_a_room_without_a_graph_records_no_latch():
    zone = latched_route()
    other = next(c.id for c in zone.chambers if c.id != _plate_room(zone))
    with pytest.raises(ValueError, match="declares no signal graph"):
        T.record_latch(_save(zone), zone.zone_id, f"graph_{other}", "held")


def test_a_node_that_is_not_a_latch_is_not_recordable():
    """The graph's NOT, named by id, is a node and not a decision."""
    raw = latched_route().model_dump()
    graph = raw["room_graphs"][0]
    graph["nodes"] = [*graph["nodes"],
                      {"node_id": "shown", "kind": "NOT", "inputs": ["held"]}]
    graph["actuators"] = [*graph["actuators"],
                          {"actuator_id": "lamp", "driven_by": "shown"}]
    zone = Zone.model_validate(raw)
    with pytest.raises(ValueError, match="declares no LATCH 'shown'"):
        T.record_latch(_save(zone), zone.zone_id,
                       f"graph_{_plate_room(zone)}", "shown")


def test_nothing_has_latched_before_the_layout_is_committed():
    zone = latched_route()
    with pytest.raises(ValueError, match="no committed layout"):
        T.record_latch(_save(zone, committed=False), zone.zone_id,
                       f"graph_{_plate_room(zone)}", "held")


def test_a_layout_that_never_placed_the_room_is_not_evidence_for_it():
    zone = latched_route()
    room = _plate_room(zone)
    elsewhere = tuple(c.id for c in zone.chambers if c.id != room)
    with pytest.raises(ValueError, match=f"placed no room '{room}'"):
        T.record_latch(_save(zone, placed=elsewhere), zone.zone_id,
                       f"graph_{room}", "held")


def test_the_physics_path_is_unchanged_for_everything_else():
    """A name outside the reserved namespace still goes through the
    committed manifest's packages, and still finds none here."""
    zone = latched_route()
    with pytest.raises(ValueError, match="accepted no physics package"):
        T.record_latch(_save(zone), zone.zone_id, "counterweight", "l0")


def test_no_physics_package_may_take_the_graph_namespace():
    """Otherwise a physics latch and a room-graph latch could share one
    identity in `latched`, and a monotone set never gives one back."""
    from archipepsi_bridge.schemas import physics as PH
    with pytest.raises(ValueError, match="reserved for room-graph latches"):
        PH.refuse_reserved_package_id("graph_c001")
    for model in (PH.PhysicsPackage, PH.ReplayEvidence, PH.PlacedPackage):
        src = __import__("inspect").getsource(model)
        assert "refuse_reserved_package_id" in src, (
            f"{model.__name__} names a physics package and does not "
            "reserve the graph namespace")


def test_the_record_is_room_persistent_and_not_zone_state():
    """The latch's lifetime in the save: `latched`, ROOM_PERSISTENT --
    never `macro_state`, which is where reversible configuration lives."""
    zone = latched_route()
    room = _plate_room(zone)
    save = T.record_latch(_save(zone), zone.zone_id, f"graph_{room}", "held")
    progress = save.zone_by_id(zone.zone_id).progress
    assert progress.macro_state == ()
    assert P.SAVE_FIELD_CATEGORY["latched"] == "ROOM_PERSISTENT"


def test_without_the_latch_modelling_a_far_side_plate_would_pass(monkeypatch):
    """Sabotage, behavioural: take the modelling away and the far-side
    plate is accepted -- the edge reads as an ordinary open door. So the
    refusal above is the modelling's doing and not a side effect."""
    from archipepsi_bridge import topology as TP
    far = latched_route(plate_side="far")
    assert not reachability(far).ok
    monkeypatch.setattr(TP, "_route_latches", lambda zone: (zone, ()))
    assert TP.reachability(far).ok


# --------------------------------------------------------------------------
# The composer: a legal latch route on a real Zone, by an explicit step
# --------------------------------------------------------------------------

def test_the_composer_puts_a_legal_latch_route_on_the_real_zone():
    from archipepsi_bridge.latched_route import compose_latched_route
    out = compose_latched_route(composed())
    assert out.emitted, out.note
    assert reachability(out.zone).ok
    edge = next(e for e in out.zone.edges if e.opened_by)
    graph = out.zone.room_graphs[0]
    order = [c.id for c in out.zone.chambers]
    # The trigger is on the near side of the door it opens.
    other = edge.room_b if graph.room_id == edge.room_a else edge.room_a
    assert order.index(graph.room_id) < order.index(other)
    # And it is the chosen chain: counts the player, latches, no gate.
    assert graph.sensors[0].counts_player is True
    assert [n.kind for n in graph.nodes] == ["LATCH"]
    assert edge.capability is None


def test_the_composer_does_not_stack_onto_a_zone_that_has_one():
    from archipepsi_bridge.latched_route import compose_latched_route
    once = compose_latched_route(composed())
    again = compose_latched_route(once.zone)
    assert not again.emitted and again.zone is once.zone
    assert "does not stack" in again.note


def test_the_composer_declines_rather_than_emitting_something_broken(
        monkeypatch):
    """Sabotage: make every candidate fail the route search, and the
    composer must hand the Zone back unchanged with the reason -- never
    the last candidate it tried."""
    from archipepsi_bridge import latched_route as LR
    from archipepsi_bridge.topology import Reach

    def refuses(zone, *a, **k):
        return Reach(states=frozenset(), rooms=frozenset(),
                     errors=("sabotaged",))
    monkeypatch.setattr(LR, "reachability", refuses)
    out = LR.compose_latched_route(composed())
    assert not out.emitted and out.zone is composed()
    assert "sabotaged" in out.note


def test_the_default_composition_carries_no_latch_route():
    """An explicit step, never a default: the Zone the baseline plays --
    and every Zone the campaign composes -- is unchanged."""
    zone = composed()
    assert zone.room_graphs == ()
    assert all(e.opened_by is None for e in zone.edges)


def test_the_latch_route_fixture_is_the_zone_the_composer_emits():
    """`make latched-route-fixture` output, checked like the zone-audit
    fixture: a stale fixture would hand Prod's acceptance a Zone the
    bridge no longer produces."""
    import json
    from pathlib import Path
    from archipepsi_bridge.playtest import latched_route_zone
    fixture = (Path(__file__).resolve().parents[2]
               / "godot/tests/fixtures/latched_route_zone.json")
    assert fixture.is_file(), (
        f"{fixture} is missing; run `make latched-route-fixture`")
    live = latched_route_zone()
    assert live is not None
    assert json.loads(fixture.read_text(encoding="utf-8")) == json.loads(
        live.model_dump_json()), (
        "the latch-route fixture is stale; regenerate it with "
        "`make latched-route-fixture`")
