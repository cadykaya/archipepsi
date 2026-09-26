"""Generate `godot/tests/fixtures/map_snapshot.json` from real map views.

H-MINIMAP, H-3D-MAP and H-JOURNAL read `CampaignSnapshot.zone_map`
(Dess's H-MAP-DATA). Every variant here is `map_view(save, zone_id)` --
the projection the snapshot carries, proven equal to it by Dess's
`test_the_snapshot_sends_the_same_inventory_and_map_the_views_compute` --
on the candidate Zone (`candidate_zone.json`), after real transitions:
nothing here writes a map by hand.

The candidate Zone carries every gate the maps must tell apart:

  e:c002:c003  the span, a reversible Zone-state gate set in c002
  e:c005:c006  the green circuit: the cell homed in c004, installed in
               c005's socket, powers the door (04 §6's example)
  e:c009:c010  a machine shutter worked live by a control
  e:c011:c012  the red lock; its key lies in c002

Variants, in the order a player meets them:

  start         nothing recorded: the save proves the entrance only
  walked        c001-c005 entered, the red key picked up
  carried       walked, and the cell carried into c005 (still blocked)
  powered       carried, and the cell installed (the door opens)
  span_lowered  walked, and the span lowered
  span_stowed   span_lowered, and the span put back (blocked again)
  all_rooms     every room entered

Run with `make map-fixture`. The transitions below are the source; the
JSON is not to be edited.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from archipepsi_bridge.schemas import protocol as P          # noqa: E402
from archipepsi_bridge.schemas import transitions as T       # noqa: E402
from archipepsi_bridge.schemas.map_view import map_view      # noqa: E402
from archipepsi_bridge.schemas.zone import Zone              # noqa: E402

FIXTURES = Path(__file__).resolve().parents[3] / "godot" / "tests" / "fixtures"
ZONE = FIXTURES / "candidate_zone.json"
OUT = FIXTURES / "map_snapshot.json"


def _zone() -> Zone:
    raw = json.loads(ZONE.read_text(encoding="utf-8"))
    return Zone.model_validate(raw.get("zone", raw))


def _save(zone: Zone) -> P.CampaignSave:
    """A campaign in this Zone with its layout committed -- the same
    construction Dess's map tests use."""
    top = max(zone.reward_location_ids) - 89100000
    save = P.CampaignSave(
        seed_name="MAPFIXTURE", team=0, slot_id=1, slot_name="Pepsi",
        scale=P.CampaignScale(location_count=max(top + 1, 30),
                              zone_target_checks=15, zone_budget=1000))
    save = T.start_generation(
        save, zone_id=zone.zone_id,
        allocated_location_ids=tuple(zone.reward_location_ids),
        target_game=zone.target_game)
    save = T.enter_zone(T.accept_zone(save, zone), zone.zone_id)
    return T.commit_layout(save, zone.zone_id, {
        "zone_id": zone.zone_id, "manifest_digest": "e" * 16,
        "rooms": {c.id: {} for c in zone.chambers}, "packages": []})


def _enter(save, zone_id: str, rooms) -> P.CampaignSave:
    for room in rooms:
        save = T.record_room_entered(save, zone_id, room)
    return save


def build_variants() -> dict[str, dict]:
    zone = _zone()
    zid = zone.zone_id
    start = _save(zone)
    walked = T.record_key(
        _enter(start, zid, ["c001", "c002", "c003", "c004", "c005"]),
        zid, "red")
    carried = T.record_object_transported(walked, zid, "power_cell", "c005")
    powered = T.record_object_consumed(carried, zid, "cell_socket")
    lowered = T.record_zone_state(walked, zid, "span_alignment", "lowered")
    stowed = T.record_zone_state(lowered, zid, "span_alignment", "stowed")
    everything = _enter(walked, zid, [c.id for c in zone.chambers])
    saves = {
        "start": start, "walked": walked, "carried": carried,
        "powered": powered, "span_lowered": lowered, "span_stowed": stowed,
        "all_rooms": everything,
    }
    return {name: {"zone_map": json.loads(
                       map_view(save, zid).model_dump_json())}
            for name, save in saves.items()}


def render() -> str:
    return json.dumps(build_variants(), indent=1, sort_keys=True) + "\n"


def main() -> None:
    OUT.write_text(render(), encoding="utf-8")
    print(f"wrote {OUT} ({len(build_variants())} variants)")


if __name__ == "__main__":
    main()
