"""Generate `godot/tests/fixtures/tour_snapshot.json`: the owner's own
candidate campaign, played into a Zone, for MENU-INT's tour.

MENU-INT's delivery asks for a short tour of the integrated menu "on real
campaign data" -- not the prototype's sample snapshot, and not the
equipment fixture, whose Echo log is written by hand. So the campaign the
owner played is played again, exactly as `make_bomb_snapshots.py` plays
it (mock AP, the deterministic fallback provider, DEFAULT scale, the
whole candidate profile), to the Zone after the one holding its first
consumable. Along the way a player's own choices are made through the
engine's own handlers:

- the first consumable goes on its key, as H-BOMBS puts it there;
- each empty key takes the first Action owned that goes on it (a player
  seven Zones in has a loadout, and the wall compares against it);

and in that Zone:

  before   the snapshot on arriving: what the wall is met with first, so
           what is claimed after it is new
  after    the Zone's freely reachable rooms walked (`room_entered`,
           through the real server's `dispatch`) and two of its Checks
           claimed: the map knows those rooms, the journal what was done

Both are the engine's own `snapshot()` as the wire carries it, with the
scout table left out (`meta.omitted`: nothing on the menu reads it). The
Zone's document travels inside the snapshot (`active_zone.zone`), which
is what the tour builds the Zone from.

Deterministic: the mock's placements are a function of its config and
seed, and nothing else here is random. Run with `make tour-fixture`
(about a minute: it plays several Zones). The JSON is not to be edited.
"""

from __future__ import annotations

import asyncio
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "bridge"))

from archipepsi_bridge import candidate                     # noqa: E402
from archipepsi_bridge import transactions as TX            # noqa: E402
from archipepsi_bridge.campaign import CampaignEngine       # noqa: E402
from archipepsi_bridge.epsilon.fallback import (             # noqa: E402
    FallbackEpsilonProvider)
from archipepsi_bridge.fixtures.make_bomb_snapshots import (  # noqa: E402
    ZONE_LIMIT, _Socket, _consumable_of, _next_zone)
from archipepsi_bridge.mock_ap import MockAPBackend         # noqa: E402
from archipepsi_bridge.schemas import constants as C        # noqa: E402
from archipepsi_bridge.server import BridgeServer          # noqa: E402
from tests.conftest import drain, enter_zone                # noqa: E402

OUT = ROOT / "godot" / "tests" / "fixtures" / "tour_snapshot.json"
OMITTED = ("scouted",)
#: Rooms walked in the tour's Zone, at most, and Checks claimed there.
ROOMS = 6
CLAIMS = 2


def _wire(engine) -> dict:
    snap = json.loads(engine.snapshot().model_dump_json())
    for key in OMITTED:
        snap.pop(key, None)
    return snap


async def _loadout(engine) -> list[str]:
    """Each empty key takes the first owned Action that goes on it."""
    put: list[str] = []
    derived = engine.save.derive()
    slots = dict(engine.save.slots)
    for slot in ("echo_a", "echo_b", "mobility", "utility"):
        if slots.get(slot):
            continue
        for owned in derived.owned:
            component = owned.component
            if getattr(component, "kind", "") != "action" \
                    or str(getattr(component, "slot", "") or "") != slot \
                    or owned.component_id in slots.values():
                continue
            await engine.handle_slot_action(slot, owned.component_id)
            await drain()
            slots = dict(engine.save.slots)
            if slots.get(slot) == owned.component_id:
                put.append(f"{slot}={owned.component_id}")
            break
    return put


def _walkable(zone, limit: int) -> list[str]:
    """The entrance and the rooms reachable from it through ways that
    need nothing (no capability, no opener, no state), in the order a
    player would first come to them."""
    chambers = [c.id for c in zone.chambers]
    if not chambers:
        return []
    free: dict[str, list[str]] = {c: [] for c in chambers}
    for edge in zone.edges:
        if getattr(edge, "capability", None) or getattr(edge, "opened_by", None) \
                or getattr(edge, "requires_state", None):
            continue
        a, b = str(edge.room_a), str(edge.room_b)
        if a in free and b in free:
            free[a].append(b)
            free[b].append(a)
    order = [chambers[0]]
    at = 0
    while at < len(order) and len(order) < limit:
        for nxt in free[order[at]]:
            if nxt not in order and len(order) < limit:
                order.append(nxt)
        at += 1
    return order


async def build() -> dict:
    with tempfile.TemporaryDirectory() as tmp:
        engine = CampaignEngine(
            provider=FallbackEpsilonProvider(), provider_name="fallback",
            save_dir=Path(tmp), candidate_steps=candidate.parse("all"))
        backend = MockAPBackend(engine, config=C.DEFAULT_CONFIG)
        engine.backend = backend
        await backend.connect("", "Skyiah", "")
        await drain()
        zones = 0
        for _ in range(ZONE_LIMIT * 6):
            hub = engine.hub_status()
            if hub.postgame:
                break
            if hub.mode == "ZONE_AVAILABLE":
                await engine.handle_request_next_zone(hub.finale_offered)
                if engine._generation_task is not None:
                    await engine._generation_task
                await drain()
                continue
            if hub.mode == "GENERATING":
                if engine._generation_task is not None:
                    await engine._generation_task
                await drain()
                continue
            if hub.mode not in ("ZONE_READY", "ZONE_ACTIVE"):
                break
            record = engine.save.active_zone
            zones += 1
            if zones > ZONE_LIMIT:
                break
            if record.state == "GENERATED":
                await enter_zone(engine, record.zone_id)
                await drain()
            consumable = ""
            for loc in sorted(record.allocated_location_ids):
                await TX.claim_check(engine, record.zone_id, loc)
                await drain()
                consumable = consumable or _consumable_of(engine, loc)
            if not consumable:
                await engine.handle_exit_zone(record.zone_id)
                await drain()
                continue
            await engine.handle_slot_action("consumable", consumable)
            await drain()
            loadout = await _loadout(engine)
            await _next_zone(engine, record.zone_id)
            here = engine.save.active_zone
            before = _wire(engine)
            server = BridgeServer(engine)
            walked = _walkable(here.zone, ROOMS)
            for room in walked:
                await server.dispatch(_Socket(), json.dumps({
                    "type": "room_entered", "zone_id": here.zone_id,
                    "room_id": room}))
                await drain()
            claimed = []
            for loc in sorted(here.allocated_location_ids)[:CLAIMS]:
                await TX.claim_check(engine, here.zone_id, loc)
                await drain()
                claimed.append(loc)
            after = _wire(engine)
            return {
                "meta": {
                    "profile": "candidate all, mock AP, fallback, default scale",
                    "slot": "Skyiah",
                    "zone_index": zones + 1,
                    "zone_id": here.zone_id,
                    "consumable": consumable,
                    "loadout": loadout,
                    "walked": walked,
                    "claimed": claimed,
                    "omitted": list(OMITTED),
                },
                "before": before,
                "after": after,
            }
        raise SystemExit(f"no consumable was reached in {zones} Zone(s)")


def render() -> str:
    """The fixture's text, exactly as `main` writes it."""
    return json.dumps(asyncio.run(build()), indent=1, sort_keys=True) + "\n"


def main() -> None:
    text = render()
    OUT.write_text(text, encoding="utf-8")
    meta = json.loads(text)["meta"]
    print(f"wrote {OUT}: {meta['zone_id']} (Zone {meta['zone_index']}), "
          f"rooms {meta['walked']}, Checks {meta['claimed']}, keys "
          f"{meta['loadout']} and consumable={meta['consumable']}")


if __name__ == "__main__":
    main()
