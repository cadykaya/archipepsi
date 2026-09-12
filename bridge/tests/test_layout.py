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
            # THE FIRST ROOM'S `entry` IS THE ZONE'S FRONT DOOR. No edge
            # names it, so it is declared SEALED, and the player walks in
            # through it -- so a sound layout reports it as a hole.
            front = (i == 0 and d.socket_id == "entry")
            apertures[f"{ch.id}/{d.socket_id}"] = (
                True if front else d.passable_geometry)
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
    # NOT the first room's `entry`: that one is the Zone's front door and
    # is a hole on purpose. Picking it would have made this test assert
    # nothing, which is what it did the moment the front-door rule
    # landed.
    ref = next(f"{c.id}/{d.socket_id}" for i, c in enumerate(z.chambers)
               for d in c.doors
               if d.usage == "SEALED"
               and not (i == 0 and d.socket_id == "entry"))
    bad["apertures"][ref] = True
    assert any("disagree" in e for e in layout.validate(z, bad).errors)


def test_the_front_door_may_not_be_solid():
    """The one SEALED door that must be a hole, and it is checked.

    Nothing joins into the head of the spine, so no edge names its entry
    and it is declared SEALED -- and the player arrives through it. A
    rule that exempts it must still say something, or a Zone whose first
    room is walled shut passes validation and strands the player at the
    front door.
    """
    z = _zone()
    bad = _ok_result(z)
    head = z.chambers[0].id
    bad["apertures"][f"{head}/entry"] = False
    errors = layout.validate(z, bad).errors
    assert any("front door" in e for e in errors), errors


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


# --- the walk's inductive step, and four refusals nothing was reading -----
#
# Mutation testing found these: neuter the refusal, run the suite, and it
# stayed green. Every one is reachable and every one was unmeasured. The
# multi-piece cases matter most — the fixture above puts ONE piece in each
# chain, so `piece n -> piece n+1`, the step that makes the walk a walk,
# had never been exercised at all.

def _split(result: dict, eid: str, pieces: int) -> None:
    """Replace a chain's single piece with `pieces` collinear ones."""
    j = result["joins"][eid]
    a, b = j["chain"][0]["entry"], j["chain"][0]["exit"]
    pts = [[a[k] + (b[k] - a[k]) * i / pieces for k in range(3)]
           for i in range(pieces + 1)]
    j["chain"] = [
        {"kind": "CONNECTOR", "entry": pts[i], "exit": pts[i + 1],
         "bounds": {"position": [-2.0, 0.0, min(pts[i][2], pts[i + 1][2])],
                    "size": [4.0, 4.0,
                             abs(pts[i + 1][2] - pts[i][2]) or 0.1]}}
        for i in range(pieces)]


def test_a_sound_multi_piece_chain_is_accepted():
    """The control. A walk that refuses every corridor of more than one
    segment is not a walk, and the real engine emits several."""
    z = _zone()
    good = _ok_result(z)
    for eid in good["joins"]:
        _split(good, eid, 4)
    v = layout.validate(z, good)
    assert v.accepted, v.errors


def test_a_break_in_the_middle_of_a_chain_is_refused():
    """Not the last hop. The fixture's single-piece chains only ever
    tested `last.exit -> socket_b`; a corridor can come apart anywhere,
    and a walk that only checks its own ends is not walking."""
    z = _zone()
    bad = _ok_result(z)
    eid = next(iter(bad["joins"]))
    _split(bad, eid, 4)
    bad["joins"][eid]["chain"][2]["entry"] = [0.0, 0.0, -500.0]
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("piece 2" in e and "broken between" in e for e in v.errors), (
        v.errors)


def test_a_chain_piece_that_is_not_a_piece_is_refused():
    z = _zone()
    bad = _ok_result(z)
    eid = next(iter(bad["joins"]))
    _split(bad, eid, 3)
    bad["joins"][eid]["chain"][1] = "a corridor, honest"
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("piece 1 is not a piece" in e for e in v.errors), v.errors


def test_a_socket_that_does_not_lie_on_its_room_is_refused():
    """The chain stays continuous and the rooms stay put; only the
    doorway has left the wall it is cut into. Continuity cannot see it —
    the route is perfectly connected, to nothing."""
    z = _zone()
    bad = _ok_result(z)
    eid = next(iter(bad["joins"]))
    j = bad["joins"][eid]
    away = [500.0, 0.0, j["socket_a"][2]]
    j["socket_a"] = away
    j["chain"][0]["entry"] = away
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("does not lie on room" in e for e in v.errors), v.errors


def test_a_join_reported_for_an_edge_the_zone_does_not_have_is_refused():
    """Evidence about something that is not in this Zone is evidence the
    validator cannot check, and unchecked evidence must not ride along
    into the manifest."""
    z = _zone()
    bad = _ok_result(z)
    bad["joins"]["e:phantom"] = {"socket_a": [0.0, 0.0, 0.0],
                                 "socket_b": [0.0, 0.0, 0.0], "chain": []}
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("not\na JOINED edge".replace("\n", " ") in e
               for e in v.errors), v.errors


def test_a_layout_that_places_a_room_this_zone_never_declared_is_refused():
    z = _zone()
    bad = _ok_result(z)
    bad["rooms"]["c999"] = {
        "position": [0.0, 0.0, -5000.0], "yaw": 0.0,
        "bounds": {"position": [-8.0, 0.0, -5000.0],
                   "size": [16.0, 5.0, DEPTH]}}
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("unknown room 'c999'" in e for e in v.errors), v.errors


def test_a_room_placed_without_a_yaw_is_refused():
    """A room's facing is not optional. Absent yaw is a room the engine
    placed and did not orient, and every socket on it is then in an
    unknown place — see the door-polarity and socket-on-room checks,
    which read positions this rotation decides."""
    z = _zone()
    bad = _ok_result(z)
    bad["rooms"]["c002"].pop("yaw")
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("reports no yaw" in e for e in v.errors), v.errors


def test_a_chain_that_is_not_a_list_is_refused():
    """`"chain": {...}` is not one piece and `"chain": "corridor"` is
    not a route. Walking either by iteration would read a dict's keys
    or a string's characters and call the result continuity."""
    z = _zone()
    for shape in ({"kind": "CONNECTOR"}, "corridor", 3):
        bad = _ok_result(z)
        eid = next(iter(bad["joins"]))
        bad["joins"][eid]["chain"] = shape
        v = layout.validate(z, bad)
        assert not v.accepted, shape
        assert any("not a list of pieces" in e for e in v.errors), v.errors


def test_a_door_measurement_that_is_not_a_boolean_is_refused():
    """`"passable"` and `1` and `None`-in-a-list are not measurements.
    A truthy string would pass an `if measured:` polarity test for a
    SEALED door, which is the exact case the inverted probe exists for."""
    z = _zone()
    ref = next(f"{c.id}/{d.socket_id}" for c in z.chambers for d in c.doors)
    for measured in ("passable", 1, 0.0, [], {"open": True}):
        bad = _ok_result(z)
        bad["apertures"][ref] = measured
        v = layout.validate(z, bad)
        assert not v.accepted, measured
        assert any("not a boolean" in e for e in v.errors), v.errors


# --- the engine's own rooms, which "reserved" was excusing from every
# --- check ----------------------------------------------------------------
#
# `zone_builder` appends an exit room nobody declared and files its
# approach under `e:__exit__`, plus `r:<room>` for the first room on the
# spine. The validator knew the names and did nothing else with them:
# the exit room's transform was never parsed, so it never reached
# `boxes` and neither the overlap check nor 1b could see it, and the
# reserved joins were `continue`d straight past the walk. An exit room
# with no bounds, an exit room inside `c001`, and an exit corridor
# ending ten kilometres away were all ACCEPTED — and the manifest
# replays exactly that.

def _with_exit(zone, result: dict, pieces: int = 2) -> dict:
    """The two entries the engine appends to every Zone it builds."""
    tail = zone.chambers[-1].id
    z0 = len(zone.chambers) * STEP
    a = (len(zone.chambers) - 1) * STEP + DEPTH
    result["rooms"]["exit"] = {
        "position": [0.0, 0.0, z0], "yaw": 0.0,
        "bounds": {"position": [-8.0, 0.0, z0],
                   "size": [16.0, 5.0, DEPTH]}}
    pts = [[0.0, 0.0, a + (z0 - a) * i / pieces] for i in range(pieces + 1)]
    result["joins"]["e:__exit__"] = {
        "room_a": tail, "room_b": "exit", "synthetic": True,
        "socket_a": [0.0, 0.0, a], "socket_b": [0.0, 0.0, z0],
        "chain": [{"kind": "CONNECTOR", "entry": pts[i], "exit": pts[i + 1]}
                  for i in range(pieces)]}
    return result


def test_the_engines_exit_room_and_approach_are_accepted():
    """The control. These are legitimate and must not be refused."""
    z = _zone()
    v = layout.validate(z, _with_exit(z, _ok_result(z)))
    assert v.accepted, v.errors
    assert "e:__exit__" in v.manifest["joins"], (
        "the last leg has to be in the manifest or re-entry re-solves it")


def test_a_broken_exit_approach_is_refused():
    z = _zone()
    bad = _with_exit(z, _ok_result(z), pieces=3)
    bad["joins"]["e:__exit__"]["chain"][2]["entry"] = [0.0, 0.0, -9999.0]
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("broken between" in e for e in v.errors), v.errors


def test_an_exit_approach_with_no_chain_is_refused():
    z = _zone()
    bad = _with_exit(z, _ok_result(z))
    bad["joins"]["e:__exit__"].pop("chain")
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("reports no chain" in e for e in v.errors), v.errors


@pytest.mark.parametrize("shape", [{"kind": "CONNECTOR"}, "corridor", 7])
def test_an_exit_approach_whose_chain_is_not_a_list_is_refused(shape):
    z = _zone()
    bad = _with_exit(z, _ok_result(z))
    bad["joins"]["e:__exit__"]["chain"] = shape
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("not a list of pieces" in e for e in v.errors), v.errors


def test_an_exit_approach_piece_that_is_not_a_piece_is_refused():
    z = _zone()
    bad = _with_exit(z, _ok_result(z))
    bad["joins"]["e:__exit__"]["chain"][1] = "a corridor, honest"
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("piece 1 is not a piece" in e for e in v.errors), v.errors


def test_an_exit_approach_to_a_room_that_was_not_placed_is_refused():
    z = _zone()
    bad = _with_exit(z, _ok_result(z))
    bad["rooms"].pop("exit")
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("does not place" in e for e in v.errors), v.errors


def test_an_exit_room_with_no_bounds_is_refused():
    """It is a body in the world; without a box nothing can say whether
    it is standing inside `c001`."""
    z = _zone()
    bad = _with_exit(z, _ok_result(z))
    bad["rooms"]["exit"].pop("bounds")
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("reports no bounds" in e for e in v.errors), v.errors


def test_an_exit_room_that_overlaps_a_chamber_is_refused():
    z = _zone()
    bad = _with_exit(z, _ok_result(z))
    # Same box as the first chamber: two rooms in one place.
    bad["rooms"]["exit"]["position"] = [0.0, 0.0, 0.0]
    bad["rooms"]["exit"]["bounds"] = {"position": [-8.0, 0.0, 0.0],
                                      "size": [16.0, 5.0, DEPTH]}
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("overlap" in e for e in v.errors), v.errors


def test_the_first_rooms_approach_is_filed_under_its_reserved_key():
    """`r:<room>` is how the engine files a corridor no edge names —
    nothing joins INTO the first room on the spine. It is a real
    approach and gets walked like one; `room_a` is empty by design and
    an empty name is not a missing one."""
    z = _zone()
    first = z.chambers[0].id
    good = _ok_result(z)
    good["joins"][f"r:{first}"] = {
        "room_a": "", "room_b": first, "synthetic": True,
        "socket_a": [0.0, 0.0, 0.0], "socket_b": [0.0, 0.0, 3.0],
        "chain": [{"kind": "CONNECTOR", "entry": [0.0, 0.0, -6.0],
                   "exit": [0.0, 0.0, -3.0]},
                  {"kind": "CONNECTOR", "entry": [0.0, 0.0, -3.0],
                   "exit": [0.0, 0.0, 0.0]}]}
    assert layout.validate(z, good).accepted

    bad = _ok_result(z)
    bad["joins"][f"r:{first}"] = dict(good["joins"][f"r:{first}"])
    bad["joins"][f"r:{first}"]["chain"] = [
        {"kind": "CONNECTOR", "entry": [0.0, 0.0, -6.0],
         "exit": [0.0, 0.0, -3.0]},
        {"kind": "CONNECTOR", "entry": [0.0, 0.0, 500.0],
         "exit": [0.0, 0.0, 0.0]}]
    v = layout.validate(z, bad)
    assert not v.accepted
    assert any("broken between" in e for e in v.errors), v.errors


def test_a_reserved_join_that_is_not_a_join_is_refused():
    """`"e:__exit__": null` and `"e:__exit__": "yes"` are not approaches.
    Reading either as one would look for a chain on a string."""
    z = _zone()
    for shape in (None, "yes", 3, ["chain"]):
        bad = _with_exit(z, _ok_result(z))
        bad["joins"]["e:__exit__"] = shape
        v = layout.validate(z, bad)
        assert not v.accepted, shape
        assert any("is not a join" in e for e in v.errors), v.errors
