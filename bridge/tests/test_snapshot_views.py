"""The snapshot carries the inventory and the map, as one projection each.

H-UI-DATA and H-MAP-DATA wired: `CampaignSnapshot.inventory` and
`CampaignSnapshot.zone_map` are derived on the model from what the
snapshot already carries, as `available_capabilities` is, so the client
never folds, never computes a gate, and never holds a second version.
"""
from __future__ import annotations

import json

from archipepsi_bridge.schemas.inventory_view import inventory_view
from archipepsi_bridge.schemas.map_view import map_view
from archipepsi_bridge.schemas import transitions as T

from .conftest import connected_engine, drain, enter_zone, run


def test_the_snapshot_sends_the_same_inventory_and_map_the_views_compute(
        tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        await enter_zone(engine, zone_id)
        room = engine.save.zone_by_id(zone_id).zone.chambers[1].id
        engine.save = T.record_room_entered(engine.save, zone_id, room)
        snap = engine.snapshot()
        assert snap.inventory == inventory_view(engine.save)
        assert snap.zone_map == map_view(engine.save, zone_id)
        assert room in {r.room_id for r in snap.zone_map.rooms
                        if r.discovered}
        wire = json.loads(snap.model_dump_json())
        assert wire["zone_map"]["zone_id"] == zone_id
        assert "slots" in wire["inventory"]
    run(go())


def test_there_is_no_map_without_a_zone(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path)
        snap = engine.snapshot()
        assert engine.save.active_zone is None
        assert snap.zone_map is None
        assert json.loads(snap.model_dump_json())["zone_map"] is None
    run(go())
