"""HB-F4: the owner's candidate campaign, walked as the live client walks it.

Offline, but on the real paths at both ends: each Zone is laid out by this
revision's Godot `ZoneBuilder` (headless, `layout_walk_tmp.tscn`), and the
bridge's own handlers take the result -- `layout_result` through
`handle_layout_result` (acceptance), `build_failed` through
`handle_build_failed`. A Zone the bridge gives up on (ZONE_FAILED) is
abandoned, as the Hub tells a player to. An accepted Zone has every Check
claimed through `transactions.claim_check` and is left through its exit.

    cd <tree>/bridge && python3 layout_walk_tmp.py [ZONES]

Installed for the run and removed after: this file as
`bridge/layout_walk_tmp.py`, `HB-F4_layout_walk_tool.gd` as
`godot/layout_walk_tmp.gd` and `HB-F4_layout_walk_tool.tscn` as
`godot/layout_walk_tmp.tscn`.

Prints one line per attempt and per Zone, and where the first Bomb Bag
Check lands. Each attempt carries a digest of the Zone content the bridge
composed for it (sha256 of the sorted JSON, 12 hex digits), so a retry
that composed the same Zone is visible as a repeated digest; with
`HBF4_DUMP=<dir>` each attempt's content is written there too.
Read-only: saves go to a temporary folder.
"""
from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path.cwd()))

from pydantic import TypeAdapter                           # noqa: E402

from archipepsi_bridge import candidate                    # noqa: E402
from archipepsi_bridge import transactions as TX           # noqa: E402
from archipepsi_bridge.__main__ import MOCK_SCALES         # noqa: E402
from archipepsi_bridge.campaign import CampaignEngine      # noqa: E402
from archipepsi_bridge.epsilon.fallback import (            # noqa: E402
    FallbackEpsilonProvider)
from archipepsi_bridge.mock_ap import MockAPBackend        # noqa: E402
from archipepsi_bridge.schemas.protocol import ClientMessage  # noqa: E402

TREE = Path.cwd().parent
GODOT = TREE / "godot-bin" / "godot"
ADAPTER = TypeAdapter(ClientMessage)
#: Where to write each attempt's Zone content (`HBF4_DUMP`), or None.
DUMP = Path(os.environ["HBF4_DUMP"]) if os.environ.get("HBF4_DUMP") else None


class _Said(logging.Handler):
    """The engine's own words for a refusal, as it logs them."""

    def __init__(self) -> None:
        super().__init__(logging.WARNING)
        self.lines: list[str] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.lines.append(record.getMessage())


SAID = _Said()
logging.getLogger("archipepsi").addHandler(SAID)


async def drain(rounds: int = 25) -> None:
    for _ in range(rounds):
        await asyncio.sleep(0)


def engine_layout(zone: dict, tmp: Path) -> dict:
    zin, zout = tmp / "zone.json", tmp / "layout.json"
    zin.write_text(json.dumps(zone))
    zout.unlink(missing_ok=True)
    subprocess.run([str(GODOT), "--headless", "--path", str(TREE / "godot"),
                    "res://layout_walk_tmp.tscn", "--", str(zin), str(zout)],
                   capture_output=True, timeout=600)
    if not zout.exists():
        return {"failed": "the layout tool wrote nothing"}
    return json.loads(zout.read_text())


async def settle(engine) -> None:
    if engine._generation_task is not None:
        await engine._generation_task
    await drain()


async def main(limit: int) -> None:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        engine = CampaignEngine(
            provider=FallbackEpsilonProvider(), provider_name="fallback",
            save_dir=tmp / "saves", candidate_steps=candidate.parse("all"))
        backend = MockAPBackend(engine, config=MOCK_SCALES["default"])
        engine.backend = backend
        await backend.connect("", "Skyiah", "")
        await drain()
        played = 0
        first_bag = None
        for _ in range(limit * 12):
            hub = engine.hub_status()
            if hub.mode == "ZONE_AVAILABLE":
                if played >= limit:
                    break
                await engine.handle_request_next_zone(hub.finale_offered)
                await settle(engine)
                continue
            if hub.mode == "GENERATING":
                await settle(engine)
                continue
            if hub.mode == "ZONE_FAILED":
                zid = hub.discard_zone_id
                await engine.handle_abandon_zone(zid)
                await settle(engine)
                print(f"{zid}: ZONE_FAILED -> abandoned, its Checks back "
                      "to the pool", flush=True)
                played += 1
                continue
            if hub.mode not in ("ZONE_READY", "ZONE_ACTIVE", "ZONE_DORMANT"):
                print(f"hub mode {hub.mode}: stop")
                break
            zid = hub.resume_zone_id or engine.save.active_zone.zone_id
            await engine.handle_enter_zone(zid)
            await drain()
            record = engine.save.zone_by_id(zid)
            content = record.zone.model_dump(mode="json")
            digest = hashlib.sha256(json.dumps(
                content, sort_keys=True).encode()).hexdigest()[:12]
            if DUMP is not None:
                (DUMP / f"{zid}_{digest}.json").write_text(
                    json.dumps(content, indent=1, sort_keys=True))
            result = engine_layout(content, tmp)
            if "failed" in result:
                await engine.handle_build_failed(ADAPTER.validate_python(
                    {"type": "build_failed", "zone_id": zid,
                     "reason": result["failed"][:400]}))
                await settle(engine)
                print(f"{zid} [{digest}]: BUILD FAILED ({result['ms']} ms): "
                      f"{result['failed']}", flush=True)
                continue
            before = record.layout_refusals
            heard = len(SAID.lines)
            await engine.handle_layout_result(ADAPTER.validate_python(
                {"type": "layout_result", "zone_id": zid,
                 "layout": result["layout"]}))
            await settle(engine)
            record = engine.save.zone_by_id(zid)
            if record.layout_refusals > before:
                why = [l for l in SAID.lines[heard:] if "refused" in l]
                print(f"{zid} [{digest}]: LAYOUT REFUSED: "
                      f"{why[-1][:400] if why else '?'}",
                      flush=True)
                continue
            bags = sorted(loc for loc in record.allocated_location_ids
                          if engine.ap.scouts[loc].item_name == "Bomb Bag")
            print(f"{zid} [{digest}]: ACCEPTED ({result['ms']} ms, layout_state "
                  f"{record.layout_state}), {len(record.allocated_location_ids)}"
                  f" Checks{', Bomb Bag at ' + str(bags) if bags else ''}",
                  flush=True)
            if bags and first_bag is None:
                first_bag = (zid, bags)
            for loc in sorted(record.allocated_location_ids):
                await TX.claim_check(engine, zid, loc)
                await drain()
            await engine.handle_exit_zone(zid)
            await drain()
            played += 1
        print(f"FIRST BOMB BAG: {first_bag}")


if __name__ == "__main__":
    asyncio.run(main(int(sys.argv[1]) if len(sys.argv) > 1 else 8))
