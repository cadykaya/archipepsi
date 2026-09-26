"""Generate `godot/tests/fixtures/bomb_snapshots.json` from a PLAYED campaign.

H-BOMBS (PT-09, V-15): "Natural candidate claim, not injected component."
So unlike `make_equipment_snapshot.py`, whose log is written by hand, no
Echo here is typed in. The campaign the owner played is played again:

- mock AP, the deterministic fallback provider, DEFAULT scale, and the
  whole candidate profile (`Diagnostic Campaign - Candidate`);
- every allocated Check claimed, Zone after Zone, as a thorough player
  would, until the Zone holding the campaign's first consumable;
- in that Zone, every Check claimed up to the first Check whose Echo is
  a consumable, which is then claimed through the same transaction.

Each variant is the engine's own `snapshot()` at a point a player
reaches, dumped as the wire carries it:

  none_owned   in that Zone, before the consumable's Check is claimed
  acquired     just after it: owned, and on no key (nothing is ever put
               on a key for the player)
  carried      after `handle_slot_action` puts it on the consumable key
  authorized   after the engine grants use 1 and before its report: the
               snapshot that answers a press
  spent        after every charge is authorised and used through the
               real consumable handlers
  refilled     the rest of that Zone claimed, back to the Hub, the next
               Zone entered: the supply refilled

and one wire message that is not a snapshot:

  refused      the engine's own refusal of a use minted before the
               refill -- use 1 of the supply that was spent -- through the
               real server's `dispatch`: the error frame, `about` key and
               all, that a client whose press crossed the refill receives

`meta` records where the consumable came from, so a reader can check the
provenance without running this.

**Five fields are left out, and `meta.omitted` says which:** the scout
table for every location, the active Zone's document, its map, and the
checked and missing location lists. The consumable's key, count, notice
and inventory read none of them, and together they were four fifths of
a 1.4 MB file. Everything else is the engine's snapshot as the wire
carries it. Deterministic: the mock's placements are
a function of its config and seed, and nothing else here is random.

Run with `make bomb-fixture` (about a minute: it plays several Zones).
The JSON is not to be edited.
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
from archipepsi_bridge.mock_ap import MockAPBackend         # noqa: E402
from archipepsi_bridge.schemas import constants as C        # noqa: E402
from archipepsi_bridge.server import BridgeServer          # noqa: E402
# THE WAY THE GAME WALKS IN: enter, then send the layout, so a graph Zone
# is certified before its first claim (`tests.conftest.enter_zone`).
from tests.conftest import drain, enter_zone                # noqa: E402

OUT = ROOT / "godot" / "tests" / "fixtures" / "bomb_snapshots.json"
#: How many Zones to play before giving up: the owner's candidate reaches
#: its first consumable in its sixth.
ZONE_LIMIT = 12


#: See the module docstring.
OMITTED = ("scouted", "active_zone", "zone_map", "missing_location_ids",
           "checked_location_ids")


def _wire(engine) -> dict:
    snap = json.loads(engine.snapshot().model_dump_json())
    for key in OMITTED:
        snap.pop(key, None)
    return snap


class _Socket:
    """What `BridgeServer.dispatch` answers down: kept, not sent."""

    def __init__(self) -> None:
        self.sent: list[dict] = []

    async def send(self, payload: str) -> None:
        self.sent.append(json.loads(payload))


async def _next_zone(engine, zone_id: str) -> None:
    """Out through the exit and into the next Zone, as the game walks it."""
    await engine.handle_exit_zone(zone_id)
    await drain()
    for _ in range(6):
        hub = engine.hub_status()
        if hub.mode == "ZONE_AVAILABLE":
            await engine.handle_request_next_zone(hub.finale_offered)
        if engine._generation_task is not None:
            await engine._generation_task
        await drain()
        record = engine.save.active_zone
        if engine.hub_status().mode in ("ZONE_READY", "ZONE_ACTIVE") \
                and record is not None and record.state == "GENERATED":
            await enter_zone(engine, record.zone_id)
            await drain()
            return
    raise SystemExit(f"no next Zone to enter (hub {engine.hub_status().mode})")


def _consumable_of(engine, loc: int) -> str:
    """The consumable component a Check's Echo made or grew, "" if none."""
    echo = engine.save.interpretation_by_id(f"echo_{loc}")
    if echo is None:
        return ""
    for owned in engine.save.derive().owned:
        if str(getattr(owned.component, "slot", "") or "") != "consumable":
            continue
        if any(p.source_location_id == loc for p in owned.provenance):
            return owned.component_id
    return ""


async def build() -> dict:
    with tempfile.TemporaryDirectory() as tmp:
        engine = CampaignEngine(
            provider=FallbackEpsilonProvider(), provider_name="fallback",
            save_dir=Path(tmp), candidate_steps=candidate.parse("all"))
        notices: list[dict] = []
        original = engine._notify

        # EVERY NOTICE THE CLAIM PRODUCED, as the wire message the client
        # receives (`Notification`), so a suite can deliver it verbatim.
        async def spy(kind, title, lines=(), **kw):
            notices.append({"type": "notification", "kind": kind,
                            "title": title, "lines": list(lines),
                            **{k: v for k, v in kw.items()
                               if k in ("location_id", "echo_id")}})
            return await original(kind, title, lines, **kw)

        engine._notify = spy
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
            for loc in sorted(record.allocated_location_ids):
                before = _wire(engine)
                heard = len(notices)
                await TX.claim_check(engine, record.zone_id, loc)
                await drain()
                cid = _consumable_of(engine, loc)
                if not cid:
                    continue
                acquired = _wire(engine)
                said = notices[heard:]
                await engine.handle_slot_action("consumable", cid)
                await drain()
                carried = _wire(engine)
                generation = engine.save.consumable_generation
                charges = engine.save.charges_left(cid)
                authorized = None
                for use in range(1, charges + 1):
                    await engine.handle_authorize_consumable(
                        cid, use, generation)
                    await drain()
                    if use == 1:
                        authorized = _wire(engine)
                    await engine.handle_use_consumable(cid, use, generation)
                    await drain()
                spent = _wire(engine)
                # THE REST OF THE ZONE, as a thorough player would, then
                # the next one: entering it refills the supply.
                for rest in sorted(record.allocated_location_ids):
                    if rest > loc:
                        await TX.claim_check(engine, record.zone_id, rest)
                        await drain()
                await _next_zone(engine, record.zone_id)
                refilled = _wire(engine)
                # A PRESS THAT CROSSED THE REFILL, through the real server:
                # use 1 of the old supply, which no longer exists. The
                # refusal a client receives, not one written here.
                socket = _Socket()
                await BridgeServer(engine).dispatch(socket, json.dumps({
                    "type": "authorize_consumable", "component_id": cid,
                    "use_index": 1, "generation": generation}))
                refused = [m for m in socket.sent if m.get("type") == "error"]
                if len(refused) != 1 or _wire(engine) != refilled:
                    raise SystemExit(f"expected one refusal and no change, "
                                     f"got {socket.sent}")
                echo = engine.save.interpretation_by_id(f"echo_{loc}")
                return {
                    "meta": {
                        "profile": "candidate all, mock AP, fallback, "
                                   "default scale",
                        "zone_index": zones,
                        "zone_id": record.zone_id,
                        "location_id": loc,
                        "item_name": engine.ap.scouts[loc].item_name,
                        "component_id": cid,
                        "echo_operations": [type(o).__name__
                                            for o in echo.operations],
                        "charges": charges,
                        "generation": generation,
                        "refilled_generation":
                            engine.save.consumable_generation,
                        "refilled_zone_id": engine.save.active_zone.zone_id,
                        "notices": said,
                        "omitted": list(OMITTED),
                    },
                    "none_owned": before,
                    "acquired": acquired,
                    "carried": carried,
                    "authorized": authorized,
                    "spent": spent,
                    "refused": refused[0],
                    "refilled": refilled,
                }
            # Out through the exit, as a player leaves a Zone they cleared.
            await engine.handle_exit_zone(record.zone_id)
            await drain()
        raise SystemExit(f"no consumable was reached in {zones} Zone(s)")


def render() -> str:
    """The fixture's text, exactly as `main` writes it."""
    return json.dumps(asyncio.run(build()), indent=1, sort_keys=True) + "\n"


def main() -> None:
    text = render()
    OUT.write_text(text, encoding="utf-8")
    meta = json.loads(text)["meta"]
    print(f"wrote {OUT}: {meta['item_name']} ({meta['component_id']}, "
          f"{meta['charges']} charges) from Check {meta['location_id']} in "
          f"Zone {meta['zone_index']} ({meta['zone_id']})")


if __name__ == "__main__":
    main()
