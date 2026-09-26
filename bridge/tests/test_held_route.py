"""D13 1d — a door held open by a declared weight on a plate.

D-07: "Pressure plates are held sensors [...] A plate that must stay down
needs a guaranteed movable weight." So `plate -> shutter`, open only
while pressed, is legal exactly when the plate names its weight
(`SensorNode.held_by`) and that weight can really hold it:

  declared      a `TransportedObject` of this Zone;
  hand carry    carriable, at most 60 kg (§10.3), not a manipulation;
  heavy enough  its class at least the plate's;
  in reach      the plate's room inside its volume, the far side not --
                it can never be carried through the door it holds;
  its own       not also what a receiver installs; one plate per weight;
  fetchable     homed where the route search reaches without the door,
                with a plain carry to the plate inside its volume.

The player's own body is never the solution. Built on M-1's legacy
fixture's spine, whose door `e:c002:c003` the plate in c002 opens.
"""
from __future__ import annotations

import copy
import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from archipepsi_bridge import topology as TP
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.map_view import map_view
from archipepsi_bridge.schemas.zone import Zone, validate_zone

LEGACY = (Path(__file__).resolve().parents[2]
          / "godot/tests/fixtures/latched_route_zone.json")
DOOR = "e:c002:c003"


def _held(*, mass=40.0, home="c002", volume=("c001", "c002"),
          carriable=True, requires="MEDIUM", counts_player=False,
          held_by="counterweight", nodes=None, extra_sensors=(),
          consumers=()) -> dict:
    raw = copy.deepcopy(json.loads(LEGACY.read_text(encoding="utf-8")))
    raw = raw.get("zone", raw)
    raw["room_graphs"] = [{
        "room_id": "c002",
        "sensors": [{"node_id": "weight_plate", "kind": "PRESSURE_PLATE",
                     "requires_class": requires,
                     "counts_player": counts_player,
                     "held_by": held_by}, *extra_sensors],
        "nodes": nodes or [],
        "actuators": [{"actuator_id": "route_shutter",
                       "driven_by": "held" if nodes else "weight_plate"}]}]
    raw["transported_objects"] = [{
        "object_id": "counterweight", "allowed_volume": list(volume),
        "home_room_id": home, "carriable": carriable, "mass_kg": mass}]
    raw["object_consumers"] = list(consumers)
    return raw


def test_a_plate_held_by_a_proper_weight_is_a_legal_route():
    zone = Zone.model_validate(_held())
    assert TP.reachability(zone).ok, TP.reachability(zone).errors
    errors = validate_zone(zone, expected_zone_id=zone.zone_id,
                           allocated_location_ids=list(
                               zone.reward_location_ids),
                           owned_echo_ids=[])
    assert not any("held sensor" in e for e in errors), errors


def test_without_its_weight_the_same_plate_is_the_held_requirement():
    """The weight is what makes it legal: the same chain with nothing
    named is refused as before, whoever stands on it."""
    with pytest.raises(ValidationError, match="object-only"):
        Zone.model_validate(_held(held_by=None))


@pytest.mark.parametrize("change, says", [
    (dict(held_by="ghost"), "does not declare"),
    # Refused by the object's own model today (a hand carry is carriable
    # and at most 60 kg, and `manipulated` is unbuilt). The plate's rule
    # keeps the guarantee once manipulation is built.
    (dict(carriable=False), "is not `carriable`"),
    (dict(mass=70.0), "over §10.3's 60 kg carry line"),
    (dict(mass=10.0), "would rest on the plate and not press it"),
    (dict(home="c001", volume=("c001", "c004")), "outside the volume"),
    (dict(volume=("c002", "c003")), "through that door"),
    (dict(nodes=[{"node_id": "held", "kind": "LATCH",
                  "inputs": ["weight_plate"]}]), "DIRECTLY"),
    (dict(extra_sensors=[{"node_id": "second_plate",
                          "kind": "PRESSURE_PLATE", "requires_class": "LIGHT",
                          "held_by": "counterweight"}]),
     "one weight holds one plate"),
    (dict(consumers=[{"mechanism_id": "weight_socket", "room_id": "c001",
                      "accepts": "counterweight"}]),
     "also what a receiver installs"),
])
def test_a_weight_that_cannot_hold_the_plate_is_refused(change, says):
    with pytest.raises(ValidationError, match=says):
        Zone.model_validate(_held(**change))


def test_only_a_plate_is_held_down():
    raw = _held()
    raw["room_graphs"][0]["sensors"].append({
        "node_id": "target", "kind": "SHOOTABLE_TARGET", "mode": "PULSE",
        "held_by": "counterweight"})
    with pytest.raises(ValidationError, match="only a pressure plate"):
        Zone.model_validate(raw)


def test_a_weight_homed_behind_the_door_it_holds_is_refused():
    """c004 lies past c003: the weight could only be fetched through the
    very door it must first hold open."""
    zone = Zone.model_validate(_held(home="c004", volume=("c002", "c004")))
    verdict = TP.reachability(zone)
    assert not verdict.ok
    assert any("behind the route it holds" in e for e in verdict.errors), \
        verdict.errors


def test_a_held_door_is_shut_in_the_search_until_its_plate_is_reached():
    """The route search models the held door as closed until its plate's
    room is reached -- so a plate behind its own door is named, not
    certified by a search that thought the door was open."""
    raw = _held(home="c003", volume=("c003", "c004"))
    raw["room_graphs"][0]["room_id"] = "c003"
    verdict = TP.reachability(Zone.model_validate(raw))
    assert any("the trigger is behind the route it opens" in e
               for e in verdict.errors), verdict.errors
    assert any("behind the route it holds" in e for e in verdict.errors)


def test_the_carry_must_stay_inside_the_volume_on_plain_doorways():
    zone = Zone.model_validate(_held())
    assert TP._carry_path(zone, "c001", "c002", {"c001", "c002"}, DOOR)
    assert not TP._carry_path(zone, "c004", "c002", {"c002", "c004"}, DOOR)
    # Never through the door it holds, even when both sides are allowed.
    assert not TP._carry_path(zone, "c003", "c002", {"c002", "c003"}, DOOR)


def _save(zone: Zone) -> P.CampaignSave:
    top = max(zone.reward_location_ids) - 89100000
    save = P.CampaignSave(
        seed_name="Seed", team=0, slot_id=1, slot_name="Skyiah",
        scale=P.CampaignScale(location_count=max(top + 1, 30),
                              zone_target_checks=15, zone_budget=1000))
    save = T.start_generation(
        save, zone_id=zone.zone_id,
        allocated_location_ids=tuple(zone.reward_location_ids),
        target_game=zone.target_game)
    return T.enter_zone(T.accept_zone(save, zone), zone.zone_id)


def test_the_map_reads_a_held_door_as_live():
    """Whether the weight is on the plate right now is the engine's to
    say: the map reads `unknown` with its reason, never a guess."""
    zone = Zone.model_validate(_held())
    view = map_view(_save(zone), zone.zone_id,
                    visited={c.id for c in zone.chambers})
    door = next(c for c in view.connectors if c.edge_id == DOOR)
    assert door.state == "unknown"
    assert "live" in door.reason


# --- the composer and its fixture (for Prod's acceptance) ------------------

def test_the_composer_puts_a_sound_held_route_on_the_real_zone():
    from archipepsi_bridge.latched_route import compose_held_route
    from archipepsi_bridge.playtest import played_zone
    out = compose_held_route(played_zone())
    assert out.emitted, out.note
    zone = out.zone
    assert TP.reachability(zone).ok, TP.reachability(zone).errors
    (graph,) = zone.room_graphs
    (plate,) = graph.sensors
    assert plate.held_by == "counterweight" and not plate.counts_player
    assert graph.nodes == ()                 # no latch: held, not stepped
    weight = next(o for o in zone.transported_objects
                  if o.object_id == plate.held_by)
    edge = next(e for e in zone.edges if e.opened_by)
    far = edge.room_b if graph.room_id == edge.room_a else edge.room_a
    assert weight.home_room_id == graph.room_id
    assert far not in weight.allowed_volume
    errors = validate_zone(zone, expected_zone_id=zone.zone_id,
                           allocated_location_ids=list(
                               zone.reward_location_ids),
                           owned_echo_ids=[])
    assert not any("held sensor" in e for e in errors), errors


def test_the_held_route_fixture_is_the_zone_the_composer_emits():
    from archipepsi_bridge.playtest import held_route_zone
    fixture = LEGACY.parent / "held_route_zone.json"
    assert fixture.is_file(), (
        f"{fixture} is missing; run `python -m archipepsi_bridge.playtest "
        "dump-held --out ../godot/tests/fixtures/held_route_zone.json` "
        "from bridge/")
    live = held_route_zone()
    assert live is not None
    assert json.loads(fixture.read_text(encoding="utf-8")) == json.loads(
        live.model_dump_json()), (
        "the held-route fixture is stale; regenerate it with `python -m "
        "archipepsi_bridge.playtest dump-held --out "
        "../godot/tests/fixtures/held_route_zone.json` from bridge/")
