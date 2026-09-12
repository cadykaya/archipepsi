"""Checking what the engine placed, without re-placing it.

The bridge never runs a shape query. Everything needing a physics world
is measured in the engine and returned as evidence; these tests are
arithmetic and identity on that evidence.

**Half of this file is omission.** An earlier validator skipped every
check whose input was absent, so a layout with no apertures, no bounds
and no arrival verdicts was ACCEPTED and got a digest. Each
`test_..._is_refused` below removes exactly one kind of evidence from an
otherwise sound layout — which is the case that version passed.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge import layout, topology
from archipepsi_bridge.schemas.zone import Zone

STEP = 40.0          # how far apart the fixture puts consecutive rooms
DEPTH = 15.0


def _arena(rid: str, width: float = 16.0, reward: int | None = None) -> dict:
    return {"id": rid, "type": "arena", "width": width, "depth": DEPTH,
            "wall_height": 5.0, "objective": "kill_all",
            "reward_location_id": reward,
            "enemies": [{"archetype": "melee", "count": 1}]}


def _zone(n: int = 8) -> Zone:
    z = Zone(zone_id="z1", display_name="T", target_game="T",
             theme="void_glitch",
             chambers=tuple(_arena(f"c{i:03d}", reward=89100000 + i)
                            for i in range(1, n + 1)))
    return topology.apply(z, topology.compose_with_branch(list(z.chambers)))


def _ok_result(zone) -> dict:
    """A complete, sound layout: every room placed, every edge routed.

    Rooms sit `STEP` apart, so consecutive rooms are NOT adjacent and
    every join runs through a connector chain. That is deliberate: a
    fixture whose sockets happen to touch cannot tell a verified route
    from an assumed one.
    """
    rooms, apertures, anchors, arrival_ok = {}, {}, {}, {}
    at = {}
    for i, ch in enumerate(zone.chambers):
        z0 = i * STEP
        at[ch.id] = z0
        rooms[ch.id] = {
            "position": [0.0, 0.0, z0], "yaw": 0.0,
            "bounds": {"position": [-8.0, 0.0, z0],
                       "size": [16.0, 5.0, DEPTH]},
        }
        for d in ch.doors:
            # Every door, the head's front door included: a sound layout
            # reports exactly what the assignment declares.
            apertures[f"{ch.id}/{d.socket_id}"] = d.passable_geometry
        if any(d.usage != "SEALED" for d in ch.doors):
            anchor = f"room:{ch.id}:arrival"
            anchors[anchor] = [0.0, 0.0, z0 + 3.0]
            arrival_ok[anchor] = True

    # One connector chain per JOINED edge, bridging the gap between the
    # two rooms' socket faces.
    joins = {}
    for e in zone.edges:
        if e.realization != "JOINED":
            continue
        a_face = at[e.room_a] + DEPTH        # room A's far wall
        b_face = at[e.room_b]                # room B's near wall
        joins[e.edge_id] = {
            "socket_a": [0.0, 0.0, a_face],
            "socket_b": [0.0, 0.0, b_face],
            "chain": [{"kind": "CONNECTOR",
                       "entry": [0.0, 0.0, a_face],
                       "exit": [0.0, 0.0, b_face],
                       "bounds": {"position": [-2.0, 0.0, a_face],
                                  "size": [4.0, 4.0, b_face - a_face]}}],
        }

    for p in zone.plugs:
        anchors.setdefault(p.source_anchor, [0.0, 0.0, 1.0])
        anchors.setdefault(p.destination, [0.0, 0.0, 0.0])
        arrival_ok.setdefault(p.source_anchor, True)
        arrival_ok.setdefault(p.destination, True)

    return {"status": "LAYOUT_OK", "rooms": rooms, "joins": joins,
            "anchors": anchors, "arrival_ok": arrival_ok,
            "apertures": apertures, "stations": []}


# --- the happy path -------------------------------------------------------

def test_a_complete_layout_is_accepted_and_gets_a_digest():
    z = _zone()
    v = layout.validate(z, _ok_result(z))
    assert v.accepted, v.errors
    assert v.manifest["manifest_digest"]
    assert set(v.manifest["rooms"]) == {c.id for c in z.chambers}


def test_the_digest_pins_the_route_and_not_only_the_rooms():
    z = _zone()
    base = layout.validate(z, _ok_result(z)).manifest["manifest_digest"]
    moved = _ok_result(z)
    eid = next(iter(moved["joins"]))
    moved["joins"][eid]["chain"][0]["kind"] = "CORNER"
    other = layout.validate(z, moved).manifest["manifest_digest"]
    assert base != other, (
        "a manifest that ignores the chain cannot replay it, and would "
        "have to re-run the search it promises never to run")


def test_a_zone_with_no_graph_is_not_certified_here():
    """"We did not check" and "we checked and it passed" must not look
    the same."""
    plain = Zone(zone_id="z1", display_name="T", target_game="T",
                 theme="void_glitch",
                 chambers=tuple(_arena(f"c{i:03d}") for i in range(1, 6)))
    v = layout.validate(plain, {"status": "LAYOUT_OK"})
    assert not v.accepted
    assert v.legacy and v.manifest is None


# --- MISSING EVIDENCE IS NOT PASSING EVIDENCE -----------------------------

@pytest.mark.parametrize("drop,expect", [
    ("apertures", "carries no measurement"),
    ("joins", "no join evidence"),
    ("arrival_ok", "no measured arrival verdict"),
    ("anchors", "was not resolved"),
])
def test_dropping_a_whole_evidence_map_is_refused(drop, expect):
    z = _zone()
    bad = _ok_result(z)
    bad.pop(drop)
    v = layout.validate(z, bad)
    assert not v.accepted, f"dropping {drop} was accepted"
    assert v.manifest is None
    assert any(expect in e for e in v.errors), v.errors


def test_dropping_every_room_bound_is_refused():
    z = _zone()
    bad = _ok_result(z)
    for entry in bad["rooms"].values():
        entry.pop("bounds")
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("no bounds" in e for e in v.errors)


def test_dropping_one_room_entirely_is_refused():
    z = _zone()
    bad = _ok_result(z)
    bad["rooms"].pop("c003")
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("no placement" in e for e in v.errors)


def test_moving_a_room_without_updating_its_route_is_refused():
    """The case absolute transforms alone cannot catch."""
    z = _zone()
    bad = _ok_result(z)
    bad["rooms"]["c003"]["position"] = [0.0, 0.0, 1000.0]
    v = layout.validate(z, bad)
    assert not v.accepted, "a room 1 km from its own doorway was accepted"


def test_an_empty_chain_between_rooms_that_do_not_touch_is_refused():
    z = _zone()
    bad = _ok_result(z)
    eid = next(iter(bad["joins"]))
    bad["joins"][eid]["chain"] = []
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("broken between" in e for e in v.errors)


def test_a_discontinuous_chain_is_refused():
    z = _zone()
    bad = _ok_result(z)
    eid = next(iter(bad["joins"]))
    bad["joins"][eid]["chain"][0]["exit"] = [0.0, 0.0, -500.0]
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("broken between" in e for e in v.errors)


def test_a_missing_chain_key_is_not_an_empty_chain():
    z = _zone()
    bad = _ok_result(z)
    eid = next(iter(bad["joins"]))
    bad["joins"][eid].pop("chain")
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("never a missing one" in e for e in v.errors)


# --- malformed numbers ----------------------------------------------------

@pytest.mark.parametrize("value", [float("nan"), float("inf"), "3", None,
                                   True, [0.0]])
def test_a_non_finite_room_position_is_refused(value):
    z = _zone()
    bad = _ok_result(z)
    bad["rooms"]["c002"]["position"] = [0.0, value, 0.0]
    v = layout.validate(z, bad)
    assert not v.accepted
    assert v.manifest is None


def test_malformed_bounds_are_refused():
    z = _zone()
    for broken in ({"position": [0, 0, 0]},
                   {"position": [0, 0, 0], "size": [1, 1]},
                   {"position": [0, 0, 0], "size": [-4, 1, 1]},
                   "a box"):
        bad = _ok_result(z)
        bad["rooms"]["c002"]["bounds"] = broken
        assert not layout.validate(z, bad).accepted, broken


def test_an_arrival_coordinate_is_not_an_arrival_verdict():
    """The conflation an earlier version made."""
    z = _zone()
    bad = _ok_result(z)
    anchor = next(iter(bad["arrival_ok"]))
    bad["arrival_ok"][anchor] = [0.0, 0.0, 3.0]     # a point, not a verdict
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("not a boolean" in e for e in v.errors)


# --- the wrong-polarity controls, which already worked --------------------

def test_a_sealed_door_measured_as_a_hole_is_refused():
    z = _zone()
    bad = _ok_result(z)
    ref = next(f"{c.id}/{d.socket_id}" for c in z.chambers
               for d in c.doors if d.usage == "SEALED")
    bad["apertures"][ref] = True
    assert any("disagree" in e for e in layout.validate(z, bad).errors)


def test_the_front_door_is_held_to_its_assignment_like_any_other():
    """The head's `entry` had an exemption. It should not have had one.

    Nothing joins into the head of the spine, so no edge names its entry
    and the composer seals it -- and the exemption carved it open anyway,
    on the stated ground that "the player arrives through it". The player
    does not: `zone_start` is 1.2 m inside the head room, past that wall,
    and nothing is built outside it. So the exemption asked for a hole in
    the Zone's outer wall opening onto nothing.

    Both halves are pinned, because an exemption removed in one lane and
    left in the other is a Zone that can never be accepted: SEALED and
    solid is accepted, SEALED and open is refused, and the message is the
    ordinary one rather than a special case.
    """
    z = _zone()
    head = z.chambers[0].id
    assert any(d.socket_id == "entry" and d.usage == "SEALED"
               for d in z.chambers[0].doors), (
        "the head of this fixture does not seal its entry, so this test "
        "says nothing about the front door")

    ok = _ok_result(z)
    assert ok["apertures"][f"{head}/entry"] is False
    assert layout.validate(z, ok).accepted, layout.validate(z, ok).errors

    bad = _ok_result(z)
    bad["apertures"][f"{head}/entry"] = True
    errors = layout.validate(z, bad).errors
    assert any(f"{head}/entry" in e and "disagree" in e for e in errors), \
        errors


def test_a_used_door_measured_as_solid_is_refused():
    z = _zone()
    bad = _ok_result(z)
    ref = next(f"{c.id}/{d.socket_id}" for c in z.chambers
               for d in c.doors if d.usage == "USED")
    bad["apertures"][ref] = False
    assert any("disagree" in e for e in layout.validate(z, bad).errors)


def test_a_plug_landing_where_a_body_does_not_fit_is_refused():
    z = _zone()
    bad = _ok_result(z)
    bad["arrival_ok"][z.plugs[0].destination] = False
    assert any("does not fit" in e for e in layout.validate(z, bad).errors)


def test_overlapping_rooms_are_refused():
    z = _zone()
    bad = _ok_result(z)
    bad["rooms"]["c002"]["bounds"] = dict(bad["rooms"]["c001"]["bounds"])
    assert any("overlap" in e for e in layout.validate(z, bad).errors)


# --- engine failures travel intact ----------------------------------------

def test_a_timeout_is_passed_through_as_a_timeout():
    z = _zone()
    v = layout.validate(z, {"status": "LAYOUT_TIMEOUT", "elapsed_ms": 3000.0,
                            "nodes_explored": 12,
                            "candidates_remaining": 4})
    assert v.status == "LAYOUT_TIMEOUT" and v.manifest is None
    assert v.engine["candidates_remaining"] == 4


def test_infeasibility_carries_the_policy_it_exhausted():
    z = _zone()
    v = layout.validate(z, {
        "status": "LAYOUT_INFEASIBLE", "exhausted": True,
        "policy": {"max_route_turns": 2}, "blocking_rooms": ["c004"]})
    assert v.status == "LAYOUT_INFEASIBLE"
    assert v.engine["policy"]["max_route_turns"] == 2


def test_an_unknown_status_is_refused_rather_than_guessed():
    assert layout.validate(_zone(), {"status": "MAYBE"}).status \
        == "LAYOUT_REFUSED"


def test_two_inbound_joined_edges_make_room_keyed_evidence_ambiguous():
    z = _zone()
    doubled = z.model_copy(update={"edges": z.edges + (
        type(z.edges[0])(edge_id="e:extra", room_a="c001",
                         room_b=z.edges[0].room_b),)})
    v = layout.validate(doubled, _ok_result(doubled))
    assert not v.accepted
    assert any("key by edge_id" in e for e in v.errors)
