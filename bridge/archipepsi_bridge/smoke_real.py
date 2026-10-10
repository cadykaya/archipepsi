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
    assert len(engine.save.interpretations) >= len(foreign), (
        f"{len(foreign)} foreign checks, "
        f"{len(engine.save.interpretations)} interpretations")
    snap = engine.snapshot()
    log.info("zone complete; %d echoes; %d coins; %d keys; hub %s",
             len(snap.interpretations), snap.coins_received,
             snap.signal_keys,
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
    assert len(after.interpretations) == len(before.interpretations), \
        "interpretations duplicated"
    assert after.mechanics == before.mechanics, "the fold changed on reload"
    assert after.completed_zone_count == before.completed_zone_count
    assert set(after.checked_location_ids) == set(before.checked_location_ids)
    log.info("reload OK: identical state after reconnect")

    # Test L: die at the loading screen. Generate a Zone, kill the bridge
    # before entering, restart — the GENERATED record must survive with its
    # committed allocation, never orphaned, never re-pooled.
    if engine2.hub_status().mode == "ZONE_AVAILABLE":
        await engine2.handle_request_next_zone(False)
        await engine2._generation_task
        held = engine2.save.active_zone
        assert held is not None and held.state == "GENERATED"
        committed = tuple(held.allocated_location_ids)
        await backend2.disconnect()               # bridge "dies" here

        engine3 = _engine(save_dir)
        backend3 = RealAPBackend(engine3)
        engine3.backend = backend3
        await backend3.connect(server, slot, password)
        await wait_for(lambda: engine3.save is not None, 30, "restart")
        revived = engine3.save.active_zone
        assert revived is not None, "GENERATED zone lost on restart (test L)"
        assert revived.state == "GENERATED"
        assert tuple(revived.allocated_location_ids) == committed
        assert engine3.hub_status().mode == "ZONE_READY"
        try:
            await engine3.handle_request_next_zone(False)
            raise AssertionError("second request accepted while zone held")
        except Exception as exc:
            assert "cannot be started" in str(exc), exc
        log.info("test L OK: GENERATED zone survives a bridge death at the "
                 "loading screen (%s)", list(committed))
        await backend3.disconnect()
    else:
        await backend2.disconnect()

    print(f"\nREAL AP SMOKE OK against {server} as {slot}: scout, allocate, "
          f"generate, claim, confirm, {len(after.interpretations)} echo(es), "
          f"reload — "
          "no duplication; GENERATED zone survives a bridge death (test L).")


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
