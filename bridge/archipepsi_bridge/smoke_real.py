"""Full-loop smoke against a REAL Archipelago server.

    python -m archipepsi_bridge.smoke_real [server] [slot] [password]

Defaults to localhost:38281 / Skyiah (the demo multiworld seed from
`make seed-multi && make host`). Connects, scouts 30, generates a Zone with
the fallback provider, claims its Checks, reconciles the confirmations,
verifies Echo grants for foreign recipients, then reloads and verifies
nothing duplicated.
"""

from __future__ import annotations

import asyncio
import logging
import sys
import tempfile
from pathlib import Path

from .ap_client import RealAPBackend
from .campaign import CampaignEngine
from .epsilon import FallbackEpsilonProvider
from . import transactions as TX


async def wait_for(predicate, timeout: float, what: str) -> None:
    deadline = asyncio.get_event_loop().time() + timeout
    while not predicate():
        if asyncio.get_event_loop().time() > deadline:
            raise TimeoutError(f"timed out waiting for {what}")
        await asyncio.sleep(0.2)


def _engine(save_dir: Path) -> CampaignEngine:
    return CampaignEngine(provider=FallbackEpsilonProvider(),
                          provider_name="fallback", save_dir=save_dir)


async def run(server: str, slot: str, password: str) -> None:
    logging.basicConfig(level=logging.INFO,
                        format="%(name)s %(levelname)s %(message)s")
    log = logging.getLogger("smoke_real")
    save_dir = Path(tempfile.mkdtemp(prefix="archipepsi_smoke_real_"))

    engine = _engine(save_dir)
    backend = RealAPBackend(engine)
    engine.backend = backend
    await backend.connect(server, slot, password)
    await wait_for(lambda: engine.save is not None, 30, "connect + scout")
    assert len(engine.ap.scouts) == 30, f"scouted {len(engine.ap.scouts)}"
    log.info("connected to %s as %s: seed %s, %d checked / %d missing",
             server, slot, engine.ap.seed_name, len(engine.ap.checked),
             len(engine.ap.missing))

    assert engine.hub_status().mode in ("ZONE_AVAILABLE", "ZONE_READY",
                                        "ZONE_ACTIVE"), engine.hub_status()
    if engine.save.active_zone is None:
        await engine.handle_request_next_zone(False)
        await engine._generation_task
    zone = engine.save.active_zone
    assert zone is not None and zone.state in ("GENERATED", "ACTIVE")
    log.info("zone %s: '%s' holds %s", zone.zone_id, zone.zone.display_name,
             list(zone.allocated_location_ids))

    if zone.state == "GENERATED":
        await engine.handle_enter_zone(zone.zone_id)
    for loc in zone.allocated_location_ids:
        await TX.claim_check(engine, zone.zone_id, loc)
    await wait_for(lambda: not engine.save.pending_checks, 30,
                   "check confirmations")
    completed = engine.save.completed_zone_count
    assert completed >= 1, "zone did not complete"

    foreign = [l for l in zone.allocated_location_ids
               if not engine.ap.scouts[l].recipient_is_self]
    assert len(engine.save.echoes) >= len(foreign), (
        f"{len(foreign)} foreign checks, {len(engine.save.echoes)} echoes")
    snap = engine.snapshot()
    log.info("zone complete; %d echoes; %d coins; %d keys; hub %s",
             len(snap.echoes), snap.coins_received, snap.signal_keys,
             snap.hub.mode)

    before = snap
    await backend.disconnect()

    engine2 = _engine(save_dir)
    backend2 = RealAPBackend(engine2)
    engine2.backend = backend2
    await backend2.connect(server, slot, password)
    await wait_for(lambda: engine2.save is not None
                   and not engine2.save.pending_checks, 30, "reload")
    after = engine2.snapshot()
    assert after.coins_received == before.coins_received, "coins duplicated"
    assert len(after.echoes) == len(before.echoes), "echoes duplicated"
    assert after.completed_zone_count == before.completed_zone_count
    assert set(after.checked_location_ids) == set(before.checked_location_ids)
    log.info("reload OK: identical state after reconnect")
    await backend2.disconnect()

    print(f"\nREAL AP SMOKE OK against {server} as {slot}: scout, allocate, "
          f"generate, claim, confirm, {len(after.echoes)} echo(es), reload — "
          "no duplication.")


def main() -> None:
    server = sys.argv[1] if len(sys.argv) > 1 else "localhost:38281"
    slot = sys.argv[2] if len(sys.argv) > 2 else "Skyiah"
    password = sys.argv[3] if len(sys.argv) > 3 else ""
    try:
        asyncio.run(run(server, slot, password))
    except (AssertionError, TimeoutError) as exc:
        print(f"\nREAL AP SMOKE FAILED: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
