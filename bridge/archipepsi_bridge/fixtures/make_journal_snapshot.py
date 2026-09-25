"""Generate `godot/tests/fixtures/journal_snapshot.json` from the model.

H-JOURNAL's wall reads only what the snapshot carries:
- the Hub's own objective (`hub`);
- the active Zone's record of what was done there
  (`active_zone.progress`);
- the map (`zone_map`), which the model computes from that record;
- the Checks (`checked_location_ids`, `missing_location_ids`);
- the Echo log (`interpretations`), whose reads are the notes.

Every variant is a `CampaignSnapshot` built by the model over a
`CampaignSave` moved by real transitions, on the candidate Zone
(`candidate_zone.json`). The Echo log is the equipment fixture's
(`make_equipment_snapshot.build_log`). Nothing here writes a journal
line by hand.

Variants:

  hub         no Zone: the Hub's objective, two Zones completed, notes
  arrived     in the candidate Zone, nothing done yet
  walked      c001-c005 walked and the red and blue keys picked up, and
              nothing operated: the span, the power door and the blue
              door are still shut, each with the bridge's reason
  progressed  c001-c005 walked; the red and blue keys picked up; the
              blue door in c005 opened; the span lowered; the cell
              carried and installed; two of the Zone's Checks confirmed
  latched     progressed, c006-c009 walked, and the c009 latch held
  stowed      progressed, and the span put back: a setting at its
              declared start again is nothing the player did

Run with `make journal-fixture`. The transitions below are the source;
the JSON is not to be edited.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from archipepsi_bridge.fixtures import make_equipment_snapshot as E  # noqa: E402
from archipepsi_bridge.fixtures import make_map_snapshot as MAP    # noqa: E402
from archipepsi_bridge.schemas import mechanics as M                # noqa: E402
from archipepsi_bridge.schemas import protocol as P                 # noqa: E402
from archipepsi_bridge.schemas import transitions as T              # noqa: E402

FIXTURES = MAP.FIXTURES
OUT = FIXTURES / "journal_snapshot.json"

#: How many Checks of earlier Zones were confirmed before this one: the
#: campaign's count is not only this Zone's. They are the lowest ids the
#: candidate Zone does not hold (a location is never both).
EARLIER_COUNT = 6

#: The Hub's words, as `CampaignEngine.hub_status` writes them for these
#: modes. The wall shows whatever the bridge sends; these are here so the
#: fixture reads like the game.
HUB_READY = dict(mode="ZONE_AVAILABLE", headline="PORTAL READY",
                 detail="Epsilon is waiting to design your next Zone.",
                 ap_online=True, signal_keys=1, finale_progress=8,
                 finale_required=24)
HUB_ACTIVE = dict(mode="ZONE_ACTIVE", headline="ZONE IN PROGRESS",
                  detail="Step back through the portal to resume.",
                  ap_online=True, signal_keys=1, finale_progress=10,
                  finale_required=24, resume_zone_id="zone_001",
                  resume_zone_name="Relay 001: Bomb Rush Cyberfunk")


def _snapshot(save: P.CampaignSave | None, *, hub: dict,
              checked: tuple[int, ...], missing: tuple[int, ...],
              completed: int) -> dict:
    log = E.build_log()
    snap = P.CampaignSnapshot(
        bridge_connected=True, ap_connected=True, ap_mode="mock",
        epsilon_provider="fallback",
        seed_name="JOURNALFIXTURE", slot_name="Pepsi", slot_id=1,
        # The Hub's count mirrors the campaign's; the model refuses a
        # snapshot where they differ.
        signal_keys=int(hub["signal_keys"]),
        unlocked_tier=int(hub["signal_keys"]),
        checked_location_ids=tuple(sorted(checked)),
        missing_location_ids=tuple(sorted(missing)),
        interpretations=tuple(log), interpretation_count=len(log),
        mechanics=M.derive_mechanics(log),
        active_zone=save.active_zone if save is not None else None,
        completed_zone_count=completed,
        hub=hub,
    )
    return json.loads(snap.model_dump_json())


def build_variants() -> dict[str, dict]:
    zone = MAP._zone()
    zid = zone.zone_id
    here = tuple(zone.reward_location_ids)
    earlier = tuple(loc for loc in range(89100001, 89100001 + 100)
                    if loc not in here)[:EARLIER_COUNT]
    arrived = MAP._save(zone)
    walked = MAP._enter(arrived, zid, ["c001", "c002", "c003", "c004",
                                       "c005"])
    keyed = T.record_key(T.record_key(walked, zid, "red"), zid, "blue")
    unlocked = T.record_lock(keyed, zid, "c005", "side_right")
    lowered = T.record_zone_state(unlocked, zid, "span_alignment", "lowered")
    carried = T.record_object_transported(lowered, zid, "power_cell", "c005")
    progressed = T.record_object_consumed(carried, zid, "cell_socket")
    latched = T.record_latch(
        MAP._enter(progressed, zid, ["c006", "c007", "c008", "c009"]),
        zid, "graph_c009", "held")
    confirmed = here[:2]
    everything = earlier + here
    return {
        "hub": _snapshot(None, hub=HUB_READY, checked=earlier,
                         missing=here, completed=2),
        "arrived": _snapshot(arrived, hub=HUB_ACTIVE, checked=earlier,
                             missing=here, completed=2),
        "walked": _snapshot(keyed, hub=HUB_ACTIVE, checked=earlier,
                            missing=here, completed=2),
        "progressed": _snapshot(
            progressed, hub=HUB_ACTIVE, checked=earlier + confirmed,
            missing=tuple(x for x in everything
                          if x not in earlier + confirmed), completed=2),
        "stowed": _snapshot(
            T.record_zone_state(progressed, zid, "span_alignment", "stowed"),
            hub=HUB_ACTIVE, checked=earlier + confirmed,
            missing=tuple(x for x in everything
                          if x not in earlier + confirmed), completed=2),
        "latched": _snapshot(
            latched, hub=HUB_ACTIVE, checked=earlier + confirmed,
            missing=tuple(x for x in everything
                          if x not in earlier + confirmed), completed=2),
    }


def render() -> str:
    return json.dumps(build_variants(), indent=1, sort_keys=True) + "\n"


def main() -> None:
    OUT.write_text(render(), encoding="utf-8")
    print(f"wrote {OUT} ({len(build_variants())} variants)")


if __name__ == "__main__":
    main()
