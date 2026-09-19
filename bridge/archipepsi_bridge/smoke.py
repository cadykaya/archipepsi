"""Headless BRIDGE-ONLY smoke test — no Godot, no server, no API key.

    python -m archipepsi_bridge.smoke

Drives: connect (mock AP) → scout → allocate → fallback-generate → enter
→ and stops there, because that is the last thing a process with no
client can honestly do.

**WHY IT STOPS THERE.** A graph Zone is ACTIVE the moment it is entered
and UNCERTIFIED until its layout comes back; `claim_zone_check` refuses a
Check against geometry the bridge has not validated. Nothing here sends a
`layout_result` — there is no engine in this process to measure one — so
no Zone is ever certified, and the claim/Echo/equip/reload half of the
old smoke had been failing at its first claim since that guard landed.

The guard is right, so this asserts it rather than working around it: the
last thing this file does is prove that a Check claimed against an
uncertified layout is REFUSED. Fabricating a layout to get past it would
be validation constructing gameplay (F-4), and would turn a smoke test
into a test of its own scaffolding.

**WHERE THE REST WENT, unchanged and with the layout really accepted:**

* `bridge/tests/test_full_loop.py` — claim, one Echo per foreign Check,
  equip, quit, reload, nothing duplicated, second Zone generated. It
  certifies through `engine.handle_layout_result`, the same handler a
  client's layout goes through.
* `make godot-integration` — the same loop against a live bridge with a
  real Godot client measuring real geometry, driven to
  `ALL_CHECKS_CLEARED`.

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
    log.info("entered %s; layout_state %s", zone.zone_id,
             engine.save.zone_by_id(zone.zone_id).layout_state)

    # THE GUARD, ASSERTED RATHER THAN WORKED AROUND.
    #
    # This is the boundary of what a client-less process may claim about
    # a campaign, and it is worth a test of its own: a Check claimed
    # against a layout nobody validated must be refused, and the refusal
    # must name the reason rather than failing somewhere vague.
    from . import transactions
    from .campaign import IntentError

    rec = engine.save.zone_by_id(zone.zone_id)
    assert rec.layout_state == "UNCERTIFIED", rec.layout_state
    loc = sorted(zone.allocated_location_ids)[0]
    try:
        await transactions.claim_check(engine, zone.zone_id, loc)
    except IntentError as exc:
        assert "layout" in str(exc).lower(), exc
        log.info("claim against an uncertified layout refused: %s", exc)
    else:  # pragma: no cover - reached only if the guard regresses
        raise AssertionError(
            f"check {loc} was claimed against an UNCERTIFIED layout; the "
            "rule that a Zone's geometry is validated before its Checks "
            "count has regressed")
    await _drain()
    assert loc not in engine.snapshot().checked_location_ids, (
        "a refused claim still marked the location checked")

    print("\nSMOKE OK — bridge-only loop: connect, scout, allocate, "
          "generate, enter, and a Check refused against an uncertified "
          "layout.\n  The claim/Echo/equip/reload half needs an accepted "
          "layout and lives in bridge/tests/test_full_loop.py and "
          "`make godot-integration`.")


def main() -> None:
    try:
        asyncio.run(run())
    except AssertionError as exc:
        print(f"\nSMOKE FAILED: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
