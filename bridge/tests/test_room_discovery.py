"""H-MAP-DATA — which rooms the player has found, kept like a station.

`ZoneProgress.visited_rooms` is the map's discovery record:
- `RoomEntered` adds to it, checked against the accepted Zone;
- a Zone with no record yet (every save before the field) starts it
  with the rooms the save already proves, plus the one entered, so
  nothing is invented and nothing the map showed disappears;
- the map joins the record with that proof, so a missed report never
  hides a room a recorded fact names.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.map_view import map_view
from archipepsi_bridge.schemas.zone import Zone
from archipepsi_bridge.server import BridgeServer

from .conftest import connected_engine, drain, enter_zone, run

FIXTURE = (Path(__file__).resolve().parents[2]
           / "godot/tests/fixtures/candidate_zone.json")


def _zone() -> Zone:
    raw = json.loads(FIXTURE.read_text(encoding="utf-8"))
    return Zone.model_validate(raw.get("zone", raw))


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


@pytest.fixture()
def zone() -> Zone:
    return _zone()


def _visited(save, zone):
    return save.zone_by_id(zone.zone_id).progress.visited_rooms


def test_a_room_the_zone_does_not_declare_is_refused(zone):
    with pytest.raises(ValueError, match="declares no room 'c999'"):
        T.record_room_entered(_save(zone), zone.zone_id, "c999")


def test_entering_a_room_twice_is_entering_it_once(zone):
    once = T.record_room_entered(_save(zone), zone.zone_id, "c001")
    assert T.record_room_entered(once, zone.zone_id, "c001") is once


def test_the_first_entry_keeps_what_the_save_already_proves(zone):
    """No record yet: the key room the save proves joins the record with
    the room entered -- facts, not guesses -- and the map shows no
    fewer rooms afterwards than before."""
    save = T.record_key(_save(zone), zone.zone_id, "red")        # in c002
    assert _visited(save, zone) is None
    before = {r.room_id for r in map_view(save, zone.zone_id).rooms
              if r.discovered}
    save = T.record_room_entered(save, zone.zone_id, "c010")
    assert _visited(save, zone) == ("c001", "c002", "c010")
    after = {r.room_id for r in map_view(save, zone.zone_id).rooms
             if r.discovered}
    assert before <= after and "c010" in after


def test_a_save_written_before_the_record_loads_without_one(zone):
    save = T.record_room_entered(_save(zone), zone.zone_id, "c001")
    raw = save.model_dump(mode="json")
    for rec in raw["zones"]:
        rec["progress"].pop("visited_rooms")
    old = P.CampaignSave.model_validate(raw)
    assert _visited(old, zone) is None


def test_the_map_joins_the_record_with_what_the_save_proves(zone):
    """A report the engine missed never hides a room a fact names."""
    save = T.record_room_entered(_save(zone), zone.zone_id, "c010")
    save = T.record_key(save, zone.zone_id, "blue")              # in c003
    found = {r.room_id for r in map_view(save, zone.zone_id).rooms
             if r.discovered}
    assert {"c001", "c003", "c010"} <= found
    assert "c020" not in found


def test_room_entered_travels_the_wire_into_the_save(tmp_path):
    """Parse, route, handle, record: the whole path a client uses."""
    async def go():
        engine, _ = await connected_engine(tmp_path)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await enter_zone(engine, zone_id)
        room = engine.save.zone_by_id(zone_id).zone.chambers[1].id
        server = BridgeServer(engine)

        class FakeWS:
            def __init__(self):
                self.sent = []

            async def send(self, payload):
                self.sent.append(payload)

        ws = FakeWS()
        await server.dispatch(ws, json.dumps({
            "type": "room_entered", "zone_id": zone_id, "room_id": room}))
        visited = engine.save.zone_by_id(zone_id).progress.visited_rooms
        assert visited is not None and room in visited
        assert not any('"error"' in p for p in ws.sent), ws.sent
    run(go())
