"""O05-02/03: the transport composer and the object's authoritative path.

The composer is handed `playtest.played_zone()`, the Zone the campaign
engine really composes, the way `test_cross_room_composer.py` hands the
D-8 composer the same Zone. The transitions are then driven through the
same save a campaign would hold.

What the bridge cannot prove, and does not pretend to: that the object
physically fits a doorway, that the socket stands where a player can
reach it, that a hand really carried it. Those are the engine's half and
are measured in `make godot-transport`. What is here is identity,
uniqueness, the persisted pose and the refusals.
"""
from __future__ import annotations

import json
import math

import pytest
from pydantic import TypeAdapter

from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.zone import Zone
from archipepsi_bridge.topology import reachability
from archipepsi_bridge import transport_route as TR
from archipepsi_bridge.transport_route import (
    CONSUMER_ID, MASS_KG, OBJECT_ID, STATES, VARIABLE_ID, compose_transport)

_CACHE: dict = {}


def played() -> Zone:
    if "played" not in _CACHE:
        from archipepsi_bridge.playtest import played_zone
        zone = played_zone()
        assert zone is not None
        _CACHE["played"] = zone
    return _CACHE["played"]


def emitted():
    if "emitted" not in _CACHE:
        _CACHE["emitted"] = compose_transport(played())
    return _CACHE["emitted"]


def _save_with(zone: Zone) -> P.CampaignSave:
    """A campaign save holding this Zone, through the real transitions,
    at the playtest campaign's scale (see `test_cross_room_composer`)."""
    from archipepsi_bridge.playtest import PLAYTEST_CONFIG
    save = P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="P",
        scale=P.CampaignScale(
            location_count=PLAYTEST_CONFIG.location_count,
            zone_target_checks=PLAYTEST_CONFIG.zone_target_checks,
            zone_budget=PLAYTEST_CONFIG.zone_budget))
    save = T.start_generation(
        save, zone_id=zone.zone_id, target_game=zone.target_game,
        allocated_location_ids=tuple(sorted(
            {r for c in zone.chambers for r in c.reward_ids})))
    return T.enter_zone(T.accept_zone(save, zone), zone.zone_id)


def _progress(save: P.CampaignSave, zone: Zone) -> P.ZoneProgress:
    return save.zone_by_id(zone.zone_id).progress


def _delivered(zone: Zone) -> P.CampaignSave:
    """Carried from home, through the run, into the consumer's room."""
    out = emitted()
    save = _save_with(zone)
    for room in out.volume[1:]:
        save = T.record_object_transported(save, zone.zone_id, OBJECT_ID,
                                           room)
    return save


# --------------------------------------------------------------------------
# The composer
# --------------------------------------------------------------------------

def test_it_emits_on_the_zone_the_campaign_really_composes():
    out = emitted()
    assert out.emitted, out.note
    zone = out.zone
    (obj,) = zone.transported_objects
    assert (obj.object_id, obj.required, obj.carriable, obj.mass_kg,
            obj.movement) == (OBJECT_ID, True, True, MASS_KG, "hand_carried")
    assert obj.home_room_id == out.volume[0] == out.home_room_id
    (con,) = zone.object_consumers
    assert (con.mechanism_id, con.accepts, con.room_id) == (
        CONSUMER_ID, OBJECT_ID, out.consumer_room_id)
    assert (con.sets_variable, con.sets_state) == (VARIABLE_ID, STATES[1])


def test_the_carry_crosses_two_real_connectors_along_the_spine():
    """O05-02.2: at least two distinct room ids and their real
    connector. The run is three rooms when the Zone has them."""
    out = emitted()
    spine = [c.id for c in played().chambers]
    assert len(out.volume) >= 2
    at = spine.index(out.volume[0])
    assert list(out.volume) == spine[at:at + len(out.volume)], (
        "a contiguous spine run")
    assert at >= 1, "not the entrance: the player meets the Zone first"
    pairs = {frozenset((e.room_a, e.room_b)): e for e in out.zone.edges}
    for a, b in zip(out.volume, out.volume[1:]):
        edge = pairs[frozenset((a, b))]
        assert (edge.realization, edge.direction, edge.capability,
                edge.opened_by, edge.requires_state) == (
            "JOINED", "BIDIRECTIONAL", None, None, ()), edge.edge_id


def test_every_room_of_the_run_is_crossed_on_foot():
    """No platform path, no tower: a required object fumbled over a void
    could come to rest where no recovery reaches it (§10.4's 5 s rule is
    not implemented). The first composition ran the carry through a
    platform path, and the played acceptance found it."""
    out = emitted()
    kinds = {c.id: c.type for c in out.zone.chambers}
    assert all(kinds[r] in ("corridor", "arena", "treasure_room")
               for r in out.volume), {r: kinds[r] for r in out.volume}


def test_a_platform_path_on_the_spine_is_walked_past():
    """The played Zone's c003 is a platform path; the run must not use it."""
    kinds = {c.id: c.type for c in played().chambers}
    assert "platform_path" in kinds.values()
    assert not any(kinds[r] == "platform_path" for r in emitted().volume)


def _used_heights(zone, room_id, edge_ids):
    from archipepsi_bridge import shells
    chamber = next(c for c in zone.chambers if c.id == room_id)
    entry = shells.load_registry()[chamber.shell_id]
    at = {s.name: s.position[1] for s in entry.sockets}
    return {d.socket_id: at[d.socket_id] for d in chamber.doors
            if d.edge_id in edge_ids}


def test_every_room_of_the_journey_is_one_floor():
    """O05-02, found played: a hand carry is a walk. Each run room's way
    in, its carry doorways and the door the delivery opens share a floor,
    read from the registry's own socket heights."""
    out = emitted()
    zone = out.zone
    journey = {e.edge_id for e in zone.edges
               if {e.room_a, e.room_b} <= set(out.volume)}
    journey.add(out.gated_edge_id)
    for c in zone.chambers:
        if c.id not in out.volume or not c.shell_id:
            continue
        used = _used_heights(zone, c.id, journey | {c.arrive_edge})
        assert max(used.values()) - min(used.values()) <= 0.5, (c.id, used)


def test_the_transit_hall_is_walked_past():
    """The played Zone's c006 is `shell_hall_transit`: entered at the
    floor, left 28 m up by a launch arc. The second composition installed
    the cell there and the door it opened was overhead. It is refused by
    name, and the journey goes elsewhere."""
    zone = played()
    hall = next(c for c in zone.chambers if c.shell_id == "shell_hall_transit")
    assert hall.id not in emitted().volume
    why = TR._off_the_floor(zone, hall.id,
                            {d.edge_id for d in hall.doors if d.edge_id},
                            TR._socket_heights())
    assert "'exit' at 28 m" in why and "a hand carry is a walk" in why


def test_the_procedural_carry_rooms_are_one_floor():
    """What `_off_the_floor` relies on for a room with no shell: the
    registry's procedural rows put every doorway at the floor."""
    from archipepsi_bridge import shells
    reg = shells.load_registry()
    for kind in TR._CARRY_ROOM_TYPES:
        row = reg[f"shell_{kind}_proc"]
        heights = {s.name: s.position[1] for s in row.sockets
                   if s.kind in shells.JOINABLE_SOCKET_KINDS}
        assert heights and set(heights.values()) == {0.0}, (kind, heights)


def test_an_unmeasured_shell_is_declined_not_guessed_flat(monkeypatch):
    monkeypatch.setattr(TR, "_socket_heights", lambda: {})
    out = TR.compose_transport(played())
    shelled = {c.id for c in out.zone.chambers if c.shell_id}
    assert not (set(out.volume) & shelled), out.note


def test_the_variable_is_permanent_and_its_setter_is_the_installation():
    var = next(v for v in emitted().zone.zone_state
               if v.variable_id == VARIABLE_ID)
    assert var.lifetime == "permanent"
    assert var.initial == STATES[0]
    assert var.setter.selects == (STATES[1],)
    assert var.setter.room_id == emitted().consumer_room_id
    assert var.setter.capability is None
    remote = [r for r in var.readers if r.room_id != var.setter.room_id]
    assert remote, "a remote consequence exists"
    assert {r.mechanism for r in var.readers} == {"lamp"}


def test_the_gate_it_opens_is_declared_on_the_edge_after_the_socket():
    out = emitted()
    edge = next(e for e in out.zone.edges if e.edge_id == out.gated_edge_id)
    assert out.consumer_room_id in (edge.room_a, edge.room_b)
    assert [(c.variable_id, c.state) for c in edge.requires_state] == [
        (VARIABLE_ID, STATES[1])]


def test_everything_the_carry_needs_is_reachable_before_the_gate_opens():
    """What `topology.py` cannot see for itself: it does not read
    `transported_objects`, so the composer proves the object and its
    whole run are reachable with the variable still dark."""
    out = emitted()
    reach = reachability(out.zone)
    assert reach.ok, reach.errors
    index = [v.variable_id for v in out.zone.zone_state].index(VARIABLE_ID)
    dark = {s[0] for s in reach.states if s[2][index] == STATES[0]}
    assert set(out.volume) <= dark


def test_the_delivery_is_on_the_mandatory_path():
    """`required` is a claim that the mandatory path needs the object.
    With the variable held dark the exit must be out of reach."""
    out = emitted()
    reach = reachability(out.zone)
    index = [v.variable_id for v in out.zone.zone_state].index(VARIABLE_ID)
    exit_room = out.zone.chambers[-1].id
    assert not any(s[0] == exit_room and s[2][index] == STATES[0]
                   for s in reach.states)
    assert any(s[0] == exit_room for s in reach.states)


def test_it_does_not_disturb_what_it_was_handed():
    before = played().model_dump_json()
    compose_transport(played())
    assert played().model_dump_json() == before
    assert not played().transported_objects, (
        "an explicit step, never a default: the composed Zone the campaign "
        "plays carries no transported object until a caller asks")


def test_it_is_deterministic():
    again = compose_transport(played())
    assert again.zone.model_dump_json() == emitted().zone.model_dump_json()


def test_it_declines_rather_than_adding_a_second_object():
    twice = compose_transport(emitted().zone)
    assert not twice.emitted
    assert "already declares a transported object" in twice.note


def test_it_declines_when_the_zone_state_budget_is_spent():
    raw = played().model_dump()
    rooms = [c["id"] for c in raw["chambers"]]
    raw["zone_state"] = [{
        "variable_id": f"v{i}", "states": ["a", "b"], "initial": "a",
        "lifetime": "reversible",
        "setter": {"room_id": rooms[0], "selects": ["a", "b"]},
        "readers": [{"room_id": rooms[1], "mechanism": "lamp",
                     "when": ["b"]}]} for i in range(4)]
    out = compose_transport(Zone.model_validate(raw))
    assert not out.emitted and "four Zone-state variables" in out.note


def test_a_connector_that_needs_mobility_is_not_a_carry_route():
    """Carrying blocks Mobility (§10.3), so a capability edge inside the
    run would be a delivery nobody can make. The composer walks past it
    rather than emitting it."""
    raw = played().model_dump()
    first = emitted().volume
    for e in raw["edges"]:
        if {e["room_a"], e["room_b"]} == {first[0], first[1]}:
            e["capability"] = "grapple"
    zone = Zone.model_validate(raw)
    out = compose_transport(zone)
    if out.emitted:
        pairs = {frozenset((e.room_a, e.room_b)): e for e in zone.edges}
        for a, b in zip(out.volume, out.volume[1:]):
            assert pairs[frozenset((a, b))].capability is None
        assert out.volume != first
    else:
        assert "Mobility" in out.note or "no placement" in out.note


def test_a_zone_with_no_edges_is_declined_with_the_reason():
    """A Zone that declares no edges has no doorway to carry anything
    through. BUILT so that it validates: the played Zone with its edges
    stripped does not (its JOINED doors name those edges), and the first
    version of this test skipped on that every time -- it never ran."""
    def room(rid: str) -> dict:
        return {"id": rid, "type": "arena", "width": 16.0, "depth": 15.0,
                "wall_height": 5.0, "objective": "kill_all",
                "reward_location_id": 89100001 if rid == "c001" else None,
                "enemies": [{"archetype": "melee", "count": 1}]}
    zone = TypeAdapter(Zone).validate_python({
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "void_glitch",
        "chambers": [room("c001"), room("c002")]})
    assert not zone.edges
    out = compose_transport(zone)
    assert not out.emitted and "no edges" in out.note


def test_it_composes_after_the_d8_and_p14_composers():
    """The candidate profile stacks all three. This composer must not
    put its gate in a doorway another one already gates, and its carry
    run must not cross one.

    (Whether the D-8 composer may share a doorway with P14's shutter is
    that composer's question, recorded as finding P5-1 in the ledger; it
    is not asserted here.)"""
    from archipepsi_bridge.cross_room import compose_zone_state
    from archipepsi_bridge.latched_route import compose_latched_route
    zone = played()
    p14 = compose_latched_route(zone)
    if p14.emitted:
        zone = p14.zone
    d8 = compose_zone_state(zone)
    if d8.emitted:
        zone = d8.zone
    before = {e.edge_id: e for e in zone.edges}
    out = compose_transport(zone)
    assert out.emitted, out.note
    mine = next(e for e in out.zone.edges if e.edge_id == out.gated_edge_id)
    was = before[mine.edge_id]
    assert was.opened_by is None and not was.requires_state
    assert [c.variable_id for c in mine.requires_state] == [VARIABLE_ID]
    pairs = {frozenset((e.room_a, e.room_b)): e for e in out.zone.edges}
    for a, b in zip(out.volume, out.volume[1:]):
        carry = pairs[frozenset((a, b))]
        assert carry.opened_by is None and not carry.requires_state
    changed = [e.edge_id for e in out.zone.edges
               if e != before[e.edge_id]]
    assert changed == [mine.edge_id], "it touched only its own doorway"
    assert reachability(out.zone).ok


# --------------------------------------------------------------------------
# The authoritative path (O05-02.4 / O05-03.1)
# --------------------------------------------------------------------------

def test_the_consequence_needs_the_delivery_not_a_message():
    """O05-02.3: a raw client message alone does not stand in for the
    physical operation. The variable a consumer sets is not a control."""
    zone = emitted().zone
    save = _save_with(zone)
    with pytest.raises(ValueError, match="deliver the object"):
        T.record_zone_state(save, zone.zone_id, VARIABLE_ID, STATES[1])
    with pytest.raises(ValueError, match="not anywhere yet"):
        T.record_object_consumed(save, zone.zone_id, CONSUMER_ID)


def test_installation_consumes_the_object_once_and_sets_the_variable():
    zone = emitted().zone
    save = T.record_object_consumed(_delivered(zone), zone.zone_id,
                                    CONSUMER_ID)
    p = _progress(save, zone)
    assert p.consumed(OBJECT_ID)
    assert p.macro(VARIABLE_ID) == STATES[1]
    assert p.object_room(OBJECT_ID) == emitted().consumer_room_id
    again = T.record_object_consumed(save, zone.zone_id, CONSUMER_ID)
    assert _progress(again, zone) == p, "a resend is the same event"


def test_an_installed_object_cannot_be_recovered_moved_or_settled():
    """No second copy: recovery would put one back home, a transfer
    would move the installed one, a pose would describe one lying about."""
    zone = emitted().zone
    save = T.record_object_consumed(_delivered(zone), zone.zone_id,
                                    CONSUMER_ID)
    with pytest.raises(ValueError, match="installed"):
        T.recover_transported_object(save, zone.zone_id, OBJECT_ID)
    with pytest.raises(ValueError, match="does not move"):
        T.record_object_transported(save, zone.zone_id, OBJECT_ID,
                                    emitted().home_room_id)
    with pytest.raises(ValueError, match="installed"):
        T.record_object_settled(save, zone.zone_id, OBJECT_ID,
                                emitted().consumer_room_id,
                                (1.0, 0.5, 2.0), 0.0)
    # the same room again is the same fact again
    same = T.record_object_transported(save, zone.zone_id, OBJECT_ID,
                                       emitted().consumer_room_id)
    assert _progress(same, zone) == _progress(save, zone)


def test_a_second_consumer_cannot_take_an_installed_object():
    raw = emitted().zone.model_dump()
    raw["object_consumers"] = list(raw["object_consumers"])
    raw["object_consumers"].append(dict(raw["object_consumers"][0],
                                        mechanism_id="spare_socket",
                                        sets_variable=None,
                                        sets_state=None))
    zone = Zone.model_validate(raw)
    out = emitted()
    save = _save_with(zone)
    for room in out.volume[1:]:
        save = T.record_object_transported(save, zone.zone_id, OBJECT_ID,
                                           room)
    save = T.record_object_consumed(save, zone.zone_id, CONSUMER_ID)
    with pytest.raises(ValueError, match="already installed in 'cell_socket'"):
        T.record_object_consumed(save, zone.zone_id, "spare_socket")
    assert _progress(save, zone).consumed_by(OBJECT_ID) == CONSUMER_ID


def test_a_settled_pose_is_recorded_and_survives_the_save_file():
    """O05-03.1: a valid settled pose, not a node path. The room and a
    rounded position and yaw, through the same JSON a save is written as."""
    zone = emitted().zone
    mid = emitted().volume[1]
    save = T.record_object_transported(_save_with(zone), zone.zone_id,
                                       OBJECT_ID, mid)
    save = T.record_object_settled(save, zone.zone_id, OBJECT_ID, mid,
                                   (12.34567, 0.35, -8.0004), 1.23456)
    loaded = P.CampaignSave.model_validate_json(save.model_dump_json())
    pose = _progress(loaded, zone).object_pose(OBJECT_ID)
    assert pose is not None
    room, at, yaw = pose
    assert room == mid
    assert at == pytest.approx((12.346, 0.35, -8.0), abs=1e-9)
    assert yaw == pytest.approx(1.2346, abs=1e-9)
    assert _progress(loaded, zone).object_room(OBJECT_ID) == mid


def test_a_pose_is_forgotten_when_the_object_moves_or_is_recovered():
    zone = emitted().zone
    home, far = emitted().volume[0], emitted().volume[-1]
    save = T.record_object_transported(_save_with(zone), zone.zone_id,
                                       OBJECT_ID, far)
    save = T.record_object_settled(save, zone.zone_id, OBJECT_ID, far,
                                   (1.0, 0.35, 1.0), 0.0)
    moved = T.record_object_transported(save, zone.zone_id, OBJECT_ID, home)
    assert _progress(moved, zone).object_pose(OBJECT_ID) is None, (
        "a pose in the room it left would restore it there")
    back = T.recover_transported_object(save, zone.zone_id, OBJECT_ID)
    assert _progress(back, zone).object_pose(OBJECT_ID) is None
    assert _progress(back, zone).object_room(OBJECT_ID) == home


@pytest.mark.parametrize("room, position, yaw, match", [
    ("c099", (0.0, 0.0, 0.0), 0.0, "may not rest"),
    (None, (math.nan, 0.0, 0.0), 0.0, "no room"),
    (None, (0.0, math.inf, 0.0), 0.0, "no room"),
    (None, (20000.0, 0.0, 0.0), 0.0, "no room"),
])
def test_a_pose_nothing_could_hold_is_refused(room, position, yaw, match):
    zone = emitted().zone
    where = room or emitted().volume[1]
    with pytest.raises(ValueError, match=match):
        T.record_object_settled(_save_with(zone), zone.zone_id, OBJECT_ID,
                                where, position, yaw)


def test_an_undeclared_object_cannot_settle():
    zone = emitted().zone
    with pytest.raises(ValueError, match="declares no transported object"):
        T.record_object_settled(_save_with(zone), zone.zone_id, "ghost",
                                emitted().volume[0], (0.0, 0.0, 0.0), 0.0)


def test_the_three_intents_parse_as_the_engine_sends_them():
    adapter = TypeAdapter(P.ClientMessage)
    settled = adapter.validate_python({
        "type": "object_settled", "zone_id": "zone_001",
        "object_id": OBJECT_ID, "room_id": "c003",
        "position": [1.5, 0.35, -2.0], "yaw": 0.5})
    assert settled.position == (1.5, 0.35, -2.0)
    consumed = adapter.validate_python({
        "type": "object_consumed", "zone_id": "zone_001",
        "mechanism_id": CONSUMER_ID})
    assert consumed.mechanism_id == CONSUMER_ID
    recovered = adapter.validate_python({
        "type": "object_recovered", "zone_id": "zone_001",
        "object_id": OBJECT_ID})
    assert recovered.object_id == OBJECT_ID


def test_object_progress_is_zone_persistent():
    """§10.5: a multi-room carryable is `ZONE_PERSISTENT`, so its pose
    and its consumption outlive a doorway, a room unload and a restart."""
    assert P.SAVE_FIELD_CATEGORY["object_poses"] == "ZONE_PERSISTENT"
    assert P.SAVE_FIELD_CATEGORY["consumed_objects"] == "ZONE_PERSISTENT"


def test_other_progress_is_untouched_by_the_object():
    """O05-03.5 at the save layer: installing the object changes its own
    variable and nothing else."""
    zone = emitted().zone
    save = _delivered(zone)
    before = _progress(save, zone).with_key("k_any").with_latch("r/l")
    after = before.with_consumed(OBJECT_ID, CONSUMER_ID).with_macro(
        VARIABLE_ID, STATES[1])
    assert after.collected_keys == before.collected_keys
    assert after.latched == before.latched
    assert after.opened_locks == before.opened_locks


def test_the_emitted_zone_round_trips_through_json():
    zone = emitted().zone
    again = Zone.model_validate(json.loads(zone.model_dump_json()))
    assert again == zone


def test_the_transport_fixture_is_the_zone_the_composer_emits():
    """`make transport-fixture` output, checked like the latch-route
    fixture: a stale fixture would hand Prod's acceptance a Zone the
    bridge no longer produces."""
    from pathlib import Path
    from archipepsi_bridge.playtest import transport_zone
    fixture = (Path(__file__).resolve().parents[2]
               / "godot/tests/fixtures/transport_zone.json")
    assert fixture.is_file(), (
        f"{fixture} is missing; run `make transport-fixture`")
    live = transport_zone()
    assert live is not None
    assert json.loads(fixture.read_text(encoding="utf-8")) == json.loads(
        live.model_dump_json()), (
        "the transport fixture is stale; regenerate it with "
        "`make transport-fixture`")
