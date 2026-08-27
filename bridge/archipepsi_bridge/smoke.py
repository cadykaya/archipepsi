"""Headless full-loop smoke test — no Godot, no server, no API key.

    python -m archipepsi_bridge.smoke

Drives: connect (mock AP) → scout → allocate → fallback-generate → enter →
claim → confirm → Echo → equip → quit → reload → verify nothing duplicated.
Exits non-zero on any assertion failure.
"""

from __future__ import annotations

import asyncio
import logging
import sys
import tempfile
from pathlib import Path

from .campaign import CampaignEngine
from .epsilon import FallbackEpsilonProvider
from .mock_ap import MockAPBackend, MockServerState
from .schemas import constants as C


async def _drain() -> None:
    """Let spawned confirm/notify tasks settle."""
    for _ in range(20):
        await asyncio.sleep(0)


def _engine(save_dir: Path) -> CampaignEngine:
    return CampaignEngine(provider=FallbackEpsilonProvider(),
                          provider_name="fallback", save_dir=save_dir)


async def run() -> None:
    logging.basicConfig(level=logging.INFO,
                        format="%(name)s %(levelname)s %(message)s")
    log = logging.getLogger("smoke")
    save_dir = Path(tempfile.mkdtemp(prefix="archipepsi_smoke_"))
    server_state = MockServerState()

    engine = _engine(save_dir)
    backend = MockAPBackend(engine, server_state=server_state)
    engine.backend = backend
    await backend.connect("", "Skyiah", "")
    await _drain()

    snap = engine.snapshot()
    assert snap.ap_connected and len(snap.scouted) == 30, "scout failed"
    assert snap.hub.mode == "ZONE_AVAILABLE", snap.hub.mode
    log.info("connected; 30 locations scouted; hub %s", snap.hub.mode)

    await engine.handle_request_next_zone(False)
    await engine._generation_task
    await _drain()
    snap = engine.snapshot()
    assert snap.hub.mode == "ZONE_READY", snap.hub.mode
    zone = snap.active_zone
    log.info("zone %s generated: '%s' (%s), checks %s", zone.zone_id,
             zone.zone.display_name, zone.zone.theme,
             list(zone.allocated_location_ids))

    await engine.handle_enter_zone(zone.zone_id)
    assert engine.snapshot().hub.mode == "ZONE_ACTIVE"

    from . import transactions
    for loc in zone.allocated_location_ids:
        await transactions.claim_check(engine, zone.zone_id, loc)
        await _drain()
    snap = engine.snapshot()
    assert not snap.pending_checks, "pending checks left over"
    assert snap.completed_zone_count == 1, "zone did not auto-complete"
    assert snap.hub.mode in ("ZONE_AVAILABLE", "WAITING_FOR_AP"), snap.hub.mode

    foreign = [l for l in zone.allocated_location_ids
               if not backend.data.scouts[l].recipient_is_self]
    assert len(snap.echoes) == len(foreign), (
        f"{len(foreign)} foreign checks but {len(snap.echoes)} echoes")
    log.info("zone complete; %d echoes; coins %d; keys %d",
             len(snap.echoes), snap.coins_received, snap.signal_keys)

    if snap.echoes:
        await engine.handle_equip_echo(snap.echoes[0].echo_id)
        assert engine.snapshot().equipped_echo_id == snap.echoes[0].echo_id
        log.info("equipped %s", snap.echoes[0].display_name)

    before = engine.snapshot()

    # Quit and reload: fresh engine, same save dir, same mock server truth.
    engine2 = _engine(save_dir)
    backend2 = MockAPBackend(engine2, server_state=server_state)
    engine2.backend = backend2
    await backend2.connect("", "Skyiah", "")
    await _drain()
    after = engine2.snapshot()

    assert after.coins_received == before.coins_received, "coins duplicated"
    assert after.coins_spent == before.coins_spent
    assert len(after.echoes) == len(before.echoes), "echoes duplicated"
    assert after.equipped_echo_id == before.equipped_echo_id
    assert after.completed_zone_count == 1
    assert len(after.checked_location_ids) == len(before.checked_location_ids)
    log.info("reload OK: state identical (coins %d, echoes %d, %d checked)",
             after.coins_received, len(after.echoes),
             len(after.checked_location_ids))

    # One more zone to prove the loop continues after reload.
    await engine2.handle_request_next_zone(False)
    await engine2._generation_task
    await _drain()
    snap = engine2.snapshot()
    assert snap.hub.mode == "ZONE_READY"
    request_echoes = len(snap.echoes)
    log.info("second zone '%s' generated with %d owned echoes in context",
             snap.active_zone.zone.display_name, request_echoes)

    print("\nSMOKE OK — full loop: connect, scout, allocate, generate, "
          "claim, confirm, echo, equip, save, reload, regenerate.")


def main() -> None:
    try:
        asyncio.run(run())
    except AssertionError as exc:
        print(f"\nSMOKE FAILED: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
