"""Checking what the engine placed, without re-placing it.

The bridge never runs a shape query. Everything needing a physics world
is measured in the engine and returned as evidence; these tests are
arithmetic and identity on that evidence.
"""

from __future__ import annotations

from archipepsi_bridge import layout, topology
from archipepsi_bridge.schemas.zone import Zone


def _arena(rid: str, width: float = 16.0, reward: int | None = None) -> dict:
    return {"id": rid, "type": "arena", "width": width, "depth": 15.0,
            "wall_height": 5.0, "objective": "kill_all",
            "reward_location_id": reward,
            "enemies": [{"archetype": "melee", "count": 1}]}


def _zone(n: int = 8) -> Zone:
    z = Zone(zone_id="z1", display_name="T", target_game="T",
             theme="void_glitch",
             chambers=tuple(_arena(f"c{i:03d}", reward=89100000 + i)
                            for i in range(1, n + 1)))
    return topology.apply(z, topology.compose_with_branch(list(z.chambers)))


def _ok_result(zone, **over) -> dict:
    """What a successful engine placement looks like on the wire."""
    rooms, bounds, apertures = {}, {}, {}
    for i, c in enumerate(zone.chambers):
        # The shape `zone_builder.gd` actually emits: bounds and arrival
        # nested in the room's own entry, not as sibling maps.
        rooms[c.id] = {"position": [0.0, 0.0, i * 40.0], "yaw": 0.0,
                       "bounds": {"position": [-8.0, 0.0, i * 40.0],
                                  "size": [16.0, 5.0, 15.0]},
                       "arrival": [0.0, 0.0, i * 40.0 + 3.0]}
        bounds[c.id] = {"position": [-8.0, 0.0, i * 40.0],
                        "size": [16.0, 5.0, 15.0]}
        for d in c.doors:
            apertures[f"{c.id}/{d.socket_id}"] = d.passable_geometry
    anchors = {"zone_start": [0.0, 0.0, 0.0]}
    arrival = {"zone_start": True}
    for p in zone.plugs:
        anchors[p.source_anchor] = [0.0, 0.0, 5.0]
        anchors[p.destination] = [0.0, 0.0, 0.0]
        arrival[p.source_anchor] = True
        arrival[p.destination] = True
    out = {"status": "LAYOUT_OK", "rooms": rooms, "bounds": bounds,
           "links": {c.id: [] for c in zone.chambers},
           "anchors": anchors, "arrival": arrival, "apertures": apertures}
    out.update(over)
    return out


# --- the happy path and its digest ----------------------------------------

def test_a_sound_layout_is_accepted_and_gets_a_digest():
    z = _zone()
    v = layout.validate(z, _ok_result(z))
    assert v.accepted, v.errors
    assert v.manifest["manifest_digest"]
    assert set(v.manifest["rooms"]) == {c.id for c in z.chambers}


def test_the_digest_pins_the_whole_layout_not_just_the_rooms():
    z = _zone()
    base = layout.validate(z, _ok_result(z)).manifest["manifest_digest"]
    moved = _ok_result(z)
    moved["links"]["c002"] = [
        {"kind": "CONNECTOR", "position": [0.0, 0.0, 20.0], "yaw": 0.0}]
    other = layout.validate(z, moved).manifest["manifest_digest"]
    assert base != other, (
        "a manifest that ignores the connector chain cannot replay it, "
        "and would have to re-run the search it promises never to run")


def test_a_failing_proposal_never_acquires_a_digest():
    """Validate, then commit — not the other way round."""
    z = _zone()
    broken = _ok_result(z)
    del broken["rooms"]["c003"]
    v = layout.validate(z, broken)
    assert not v.accepted
    assert v.manifest is None
    assert any("no transform" in e for e in v.errors)


# --- a timeout is a timeout -----------------------------------------------

def test_a_timeout_is_passed_through_as_a_timeout():
    z = _zone()
    v = layout.validate(z, {"status": "LAYOUT_TIMEOUT", "elapsed_ms": 3000.0,
                            "nodes_explored": 12,
                            "candidates_remaining": 4})
    assert v.status == "LAYOUT_TIMEOUT"
    assert v.manifest is None
    assert v.engine["candidates_remaining"] == 4, (
        "the evidence that it was a clock and not a wall must survive")


def test_infeasibility_carries_the_policy_it_exhausted():
    z = _zone()
    v = layout.validate(z, {
        "status": "LAYOUT_INFEASIBLE", "exhausted": True,
        "policy": {"max_route_turns": 2, "explore_connectors": 40},
        "blocking_rooms": ["c004"]})
    assert v.status == "LAYOUT_INFEASIBLE"
    assert v.engine["policy"]["max_route_turns"] == 2, (
        "a bounded search may never report that a design is impossible, "
        "so the bounds travel with the claim")


def test_an_unknown_status_is_refused_rather_than_guessed():
    z = _zone()
    v = layout.validate(z, {"status": "MAYBE"})
    assert v.status == "LAYOUT_REFUSED"


# --- the checks that catch a wrong layout ---------------------------------

def test_overlapping_rooms_are_caught():
    z = _zone()
    bad = _ok_result(z)
    bad["rooms"]["c002"]["bounds"] = bad["rooms"]["c001"]["bounds"]
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("overlap" in e for e in v.errors)


def test_a_sealed_door_measured_as_a_hole_is_caught():
    """A shortcut past a lock, which is what the inverted probe exists for."""
    z = _zone()
    bad = _ok_result(z)
    sealed = next(f"{c.id}/{d.socket_id}" for c in z.chambers
                  for d in c.doors if d.usage == "SEALED")
    bad["apertures"][sealed] = True
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("disagree" in e for e in v.errors)


def test_a_used_door_measured_as_solid_is_caught():
    """A room with no way out."""
    z = _zone()
    bad = _ok_result(z)
    used = next(f"{c.id}/{d.socket_id}" for c in z.chambers
                for d in c.doors if d.usage == "USED")
    bad["apertures"][used] = False
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("disagree" in e for e in v.errors)


def test_a_plug_anchor_the_engine_did_not_resolve_is_caught():
    z = _zone()
    bad = _ok_result(z)
    bad["anchors"].pop(z.plugs[0].destination)
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("did not resolve" in e for e in v.errors)


def test_a_plug_landing_where_a_body_does_not_fit_is_caught():
    z = _zone()
    bad = _ok_result(z)
    bad["arrival"][z.plugs[0].destination] = False
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("does not fit" in e for e in v.errors)


def test_two_inbound_joined_edges_make_room_keyed_links_ambiguous():
    """The slice-1 accommodation, asserted rather than assumed."""
    z = _zone()
    doubled = z.model_copy(update={"edges": z.edges + (
        type(z.edges[0])(edge_id="e:extra", room_a="c001",
                         room_b=z.edges[0].room_b),)})
    v = layout.validate(doubled, _ok_result(doubled))
    assert not v.accepted
    assert any("key chains by edge_id" in e for e in v.errors)


def test_the_engine_nests_bounds_and_arrival_in_the_room_entry():
    """The shape the engine emits, not the one an earlier draft asked for."""
    z = _zone()
    nested = _ok_result(z)
    nested.pop("bounds")           # no sibling map at all
    v = layout.validate(z, nested)
    assert v.accepted, v.errors
    # and the overlap check still has something to work on
    nested["rooms"]["c002"]["bounds"] = nested["rooms"]["c001"]["bounds"]
    assert not layout.validate(z, nested).accepted


def test_relative_transforms_would_make_closure_stop_being_free():
    z = _zone()
    bad = _ok_result(z)
    bad["rooms"]["c001"] = ["relative", "to", "c002"]
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("cycle closure is only free" in e for e in v.errors)
