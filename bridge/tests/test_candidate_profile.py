"""O05-13: the opt-in CANDIDATE generation profile.

Three things are checked here. The profile runs the supported composers
in the real generation path, after the graph is proved and before
acceptance. It is off by default, and off changes nothing. And it
declines by name rather than laundering a fixture.
"""
from __future__ import annotations

import json

import pytest

from archipepsi_bridge import candidate
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.topology import reachability

from .conftest import connected_engine, drain, run


def _played():
    from archipepsi_bridge.playtest import played_zone
    zone = played_zone()
    assert zone is not None
    return zone


@pytest.mark.parametrize("spec, want", [
    (None, ()), ("", ()), ("off", ()), ("none", ()),
    ("all", candidate.STEPS),
    ("transport", ("transport",)),
    # ORDER IS THE PROFILE'S, whatever order the operator typed.
    ("transport,zone_state", ("zone_state", "transport")),
])
def test_the_profile_is_parsed_as_asked(spec, want):
    assert candidate.parse(spec) == want


def test_an_unknown_step_is_refused_by_name():
    with pytest.raises(ValueError, match="unknown candidate step"):
        candidate.parse("transport,blindside")


def test_all_three_compose_in_order_on_the_played_zone():
    applied = candidate.apply(_played(), candidate.STEPS)
    assert [s for s, _, _ in applied.steps] == list(candidate.STEPS)
    assert applied.emitted == candidate.STEPS, applied.steps
    zone = applied.zone
    assert reachability(zone).ok
    # one gate per doorway, whichever composer put it there (P5-1)
    for e in zone.edges:
        assert not (e.opened_by and e.requires_state), e.edge_id
        assert len(e.requires_state) <= 1, e.edge_id
    assert {v.variable_id for v in zone.zone_state} == {
        "span_alignment", "cell_power"}
    assert len(zone.room_graphs) == 1 and len(zone.transported_objects) == 1


def _control_rooms(zone) -> list[str]:
    """Every room holding a relationship's control, once per control."""
    return ([v.setter.room_id for v in zone.zone_state if v.setter
             and not any(c.sets_variable == v.variable_id
                         for c in zone.object_consumers)]
            + [o.home_room_id for o in zone.transported_objects]
            + [c.room_id for c in zone.object_consumers]
            + [g.room_id for g in zone.room_graphs])


def test_one_control_per_room_across_the_whole_profile():
    """P5-11, found by the first played combination: P14's plate beside
    the lever in c002 had no floor left and the engine refused it."""
    zone = candidate.apply(_played(), candidate.STEPS).zone
    rooms = _control_rooms(zone)
    assert len(rooms) == len(set(rooms)), rooms


def test_the_plate_stands_in_an_open_room_on_its_doorways_floor():
    from archipepsi_bridge import shells
    zone = candidate.apply(_played(), candidate.STEPS).zone
    graph = zone.room_graphs[0]
    room = next(c for c in zone.chambers if c.id == graph.room_id)
    assert room.type in ("arena", "treasure_room"), room.type
    gated = next(e for e in zone.edges if e.opened_by)
    if room.shell_id:
        at = {s.name: s.position[1]
              for s in shells.load_registry()[room.shell_id].sockets}
        used = {d.socket_id for d in room.doors
                if d.edge_id in (gated.edge_id, room.arrive_edge)}
        assert max(at[u] for u in used) - min(at[u] for u in used) <= 0.5


def test_p14_alone_is_unchanged_by_the_new_rules():
    """The rules decline rooms OTHER relationships occupy; alone, P14
    composes exactly the Zone its played acceptance ran on."""
    from archipepsi_bridge.latched_route import compose_latched_route
    out = compose_latched_route(_played())
    assert out.emitted and out.zone.room_graphs[0].room_id == "c002"


def test_the_reversible_control_reads_nearest_not_furthest():
    """O05-04.2: the consequence sits past the gate, by the junction,
    rather than at the far end of the Zone."""
    zone = candidate.apply(_played(), ("zone_state",)).zone
    var = zone.zone_state[0]
    spine = [c.id for c in zone.chambers]
    gated = next(e for e in zone.edges if e.requires_state)
    beyond = gated.room_b if gated.room_a == var.setter.room_id \
        else gated.room_a
    remote = [r.room_id for r in var.readers
              if r.room_id != var.setter.room_id]
    assert remote == [beyond]
    assert spine.index(beyond) == spine.index(var.setter.room_id) + 1
    assert {r.mechanism for r in var.readers} == {"lamp"}, (
        "a mechanism the engine builds; 'span_bolt' is refused there")


def test_transport_alone_is_exactly_the_fixture_the_suites_play():
    from archipepsi_bridge.playtest import transport_zone
    applied = candidate.apply(_played(), ("transport",))
    assert applied.zone.model_dump_json() == \
        transport_zone().model_dump_json()


def test_a_declined_step_leaves_the_zone_as_it_was():
    zone = candidate.apply(_played(), ("transport",)).zone
    again = candidate.apply(zone, ("transport",))
    assert again.steps[0][1] is False
    assert "already declares a transported object" in again.steps[0][2]
    assert again.zone.model_dump_json() == zone.model_dump_json()


def test_strip_removes_everything_the_profile_adds():
    zone = candidate.apply(_played(), candidate.STEPS).zone
    bare = candidate.strip(zone)
    assert not bare.zone_state and not bare.transported_objects
    assert not bare.object_consumers and not bare.room_graphs


# --------------------------------------------------------------------------
# In the real generation path
# --------------------------------------------------------------------------

def _generated(tmp_path, steps):
    async def go():
        engine, _ = await connected_engine(tmp_path,
                                           config=C.DEFAULT_CONFIG)
        engine.candidate_steps = steps
        await engine.handle_request_next_zone(False)
        await drain()
        return engine
    return run(go())


def test_off_by_default_the_engine_composes_what_it_always_did(tmp_path):
    engine = _generated(tmp_path, ())
    zone = engine.save.zone_by_id(engine.save.active_zone_id).zone
    assert not zone.transported_objects and not zone.zone_state
    assert not (tmp_path / "candidate").exists(), (
        "off means the profile is never called")


def test_on_the_engine_applies_it_before_acceptance(tmp_path):
    engine = _generated(tmp_path, ("transport",))
    rec = engine.save.zone_by_id(engine.save.active_zone_id)
    assert rec.state == "GENERATED"
    assert len(rec.zone.transported_objects) == 1
    record = json.loads((tmp_path / "candidate" / f"{rec.zone_id}.json")
                        .read_text(encoding="utf-8"))
    assert record["profile"] == ["transport"]
    assert record["steps"][0]["emitted"] is True
    assert record["provider"]
    assert record["certified"] is True
    assert record["refused_by_validate_zone"] == []


def test_a_profile_result_validation_refuses_is_discarded_whole(
        tmp_path, monkeypatch):
    """O05-13.3: 'rejected hosts/choices must not silently drop allocated
    Checks'. The profile's Zone goes back through `validate_zone` with the
    provider's own offer and allocation; one that lost a Check is thrown
    away, the provider's Zone is kept, and the record says why."""
    real_apply = candidate.apply

    def dropping(zone, steps):
        applied = real_apply(zone, steps)
        chambers = list(applied.zone.chambers)
        i = next(i for i, c in enumerate(chambers)
                 if c.reward_location_id is not None)
        chambers[i] = chambers[i].model_copy(
            update={"reward_location_id": None})
        return candidate.Applied(
            applied.zone.model_copy(update={"chambers": tuple(chambers)}),
            applied.steps)

    monkeypatch.setattr(candidate, "apply", dropping)
    engine = _generated(tmp_path, ("transport",))
    rec = engine.save.zone_by_id(engine.save.active_zone_id)
    assert rec.state == "GENERATED"
    assert not rec.zone.transported_objects, "the provider's Zone, as made"
    assert set(rec.allocated_location_ids) <= set(
        rec.zone.reward_location_ids), "no allocated Check was dropped"
    record = json.loads((tmp_path / "candidate" / f"{rec.zone_id}.json")
                        .read_text(encoding="utf-8"))
    assert record["certified"] is False and record["refused_by_validate_zone"]
    assert all(not step["emitted"] for step in record["steps"])
    assert "validate_zone refused it" in record["steps"][0]["note"]


def test_the_reversible_fixture_is_the_zone_the_profile_emits():
    """`make reversible-fixture`, checked like the other two."""
    from pathlib import Path
    from archipepsi_bridge.playtest import reversible_zone
    fixture = (Path(__file__).resolve().parents[2]
               / "godot/tests/fixtures/reversible_zone.json")
    assert fixture.is_file(), (
        f"{fixture} is missing; run `make reversible-fixture`")
    live = reversible_zone()
    assert live is not None
    assert json.loads(fixture.read_text(encoding="utf-8")) == json.loads(
        live.model_dump_json()), (
        "the reversible fixture is stale; regenerate it with "
        "`make reversible-fixture`")


def test_the_whole_profile_fixture_is_the_zone_the_profile_emits():
    """`make candidate-fixture`: what the candidate launcher's campaign
    plays (O05-15), checked like the other two."""
    from pathlib import Path
    from archipepsi_bridge.playtest import candidate_all_zone
    fixture = (Path(__file__).resolve().parents[2]
               / "godot/tests/fixtures/candidate_zone.json")
    assert fixture.is_file(), (
        f"{fixture} is missing; run `make candidate-fixture`")
    live = candidate_all_zone()
    assert live is not None
    assert json.loads(fixture.read_text(encoding="utf-8")) == json.loads(
        live.model_dump_json()), (
        "the candidate fixture is stale; regenerate it with "
        "`make candidate-fixture`")
