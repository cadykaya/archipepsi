"""H-BOMBS (PT-09): absent or unnoticed, on the campaign the owner played.

The owner played `Diagnostic Campaign - Candidate`: mock AP, the
deterministic fallback provider, DEFAULT scale, the whole candidate
profile (`--candidate`, which includes the `consumables` option). Their
save is not available, so this regenerates that campaign from the same
inputs -- the mock's placements are a function of its config and seed
alone -- and plays it the way a thorough player would: every allocated
Check claimed, Zone after Zone. Nothing is arranged and nothing is bought
unless `--buy` is given.

For each Zone it prints what the Checks held, what Echoes they made, what
the acquisition notice said, which slot each new component took, and what
the Hub shop stocks against the coins the player has. It stops when a
consumable is owned, or after `--zones` Zones.

Read-only: it writes only to a temporary save folder.

    cd bridge && python3 ../docs/ledgers/post_playtest_evidence/H-BOMBS_diagnosis.py \
        [--zones N] [--buy]
"""
from __future__ import annotations

import argparse
import asyncio
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path.cwd()))

from archipepsi_bridge import candidate                    # noqa: E402
from archipepsi_bridge import transactions as TX           # noqa: E402
from archipepsi_bridge.__main__ import MOCK_SCALES         # noqa: E402
from archipepsi_bridge.campaign import CampaignEngine      # noqa: E402
from archipepsi_bridge.epsilon.fallback import (            # noqa: E402
    FallbackEpsilonProvider)
from archipepsi_bridge.mock_ap import MockAPBackend        # noqa: E402
from tests.conftest import drain, enter_zone               # noqa: E402


def owned_by_slot(engine) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for owned in engine.save.derive().owned:
        slot = str(getattr(owned.component, "slot", None) or owned.kind)
        out.setdefault(slot, []).append(
            f"{owned.component.display_name} Mk{owned.mk}")
    return out


async def main(zones: int, buy: bool) -> None:
    notes: list[tuple[str, str, tuple]] = []
    with tempfile.TemporaryDirectory() as tmp:
        engine = CampaignEngine(
            provider=FallbackEpsilonProvider(), provider_name="fallback",
            save_dir=Path(tmp),
            candidate_steps=candidate.parse("all"))
        original = engine._notify

        async def spy(kind, title, lines=(), **kw):
            notes.append((kind, title, tuple(lines)))
            return await original(kind, title, lines, **kw)

        engine._notify = spy
        backend = MockAPBackend(engine, config=MOCK_SCALES["default"])
        engine.backend = backend
        await backend.connect("", "Skyiah", "")
        await drain()
        print(f"candidate steps {engine.candidate_steps}, options "
              f"{engine.candidate_options}")
        seen_echoes: set[str] = set()
        zone_index = 0
        first_consumable = None
        for _ in range(zones * 6):
            hub = engine.hub_status()
            if hub.postgame or zone_index > zones:
                break
            if engine.save.shop is not None:
                snap = engine.snapshot()
                stock = [(s.item_name, s.cost) for s in engine.save.shop.stock]
                print(f"  hub shop (coins {snap.coins_available}): {stock}")
                if buy:
                    for s in engine.save.shop.stock:
                        if s.cost <= engine.snapshot().coins_available:
                            await TX.buy_shop_stock(engine, s.location_id)
                            await drain()
                            print(f"    bought {s.item_name} for {s.cost}")
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
                print(f"  hub mode {hub.mode}: stopping")
                break
            record = engine.save.active_zone
            zone_index += 1
            print(f"ZONE {zone_index} {record.zone_id}: "
                  f"{len(record.allocated_location_ids)} Checks")
            if record.state == "GENERATED":
                await enter_zone(engine, record.zone_id)
            for loc in sorted(record.allocated_location_ids):
                before = len(notes)
                await TX.claim_check(engine, record.zone_id, loc)
                await drain()
                item = engine.ap.scouts[loc].item_name
                echo = engine.save.interpretation_by_id(f"echo_{loc}")
                made = ""
                if echo is not None and echo.echo_id not in seen_echoes:
                    seen_echoes.add(echo.echo_id)
                    ops = ", ".join(type(o).__name__ for o in echo.operations)
                    made = f" -> Echo '{echo.display_name}' [{ops}]"
                said = [f"{k}: {t} {l}" for k, t, l in notes[before:]
                        if k in ("echo_acquired", "reveal", "check_confirmed")]
                print(f"  {loc} {item!r}{made}")
                for line in said:
                    print(f"      notice {line}")
            slots = owned_by_slot(engine)
            print(f"  owned after Zone {zone_index}: "
                  f"{ {k: v for k, v in sorted(slots.items())} }")
            print(f"  slotted: {engine.save.slots.model_dump()}")
            if "consumable" in slots and first_consumable is None:
                first_consumable = (zone_index, slots["consumable"])
                print(f"FIRST CONSUMABLE OWNED after Zone {zone_index}: "
                      f"{slots['consumable']}")
                break
            # Leave the Zone for the Hub, as a player does.
            if hasattr(engine, "handle_return_to_hub"):
                await engine.handle_return_to_hub()
                await drain()
        if first_consumable is None:
            print(f"NO CONSUMABLE OWNED in {zone_index} Zone(s)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--zones", type=int, default=8)
    parser.add_argument("--buy", action="store_true")
    args = parser.parse_args()
    asyncio.run(main(args.zones, args.buy))
