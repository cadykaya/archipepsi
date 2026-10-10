"""Regression tests for the adversarial-review findings.

Each of these wedged or crashed the campaign before the fix; they walk the
exact paths the review reproduced.
"""

from __future__ import annotations

from archipepsi_bridge import transactions as TX
from archipepsi_bridge.mock_ap import MockServerState
from archipepsi_bridge.schemas import constants as C

from .conftest import connected_engine, drain, run
from .test_campaign import TIER0

ALL_LOCATIONS = set(range(C.FIRST_LOCATION_ID, C.LAST_LOCATION_ID + 1))


def test_externally_released_goal_sets_goal_sent_and_snapshot_builds(tmp_path):
    """An admin release checks every location with no local pending record.
    confirm_check no-ops without one, so goal_sent must be set by the
    finalize path or ALL_CHECKS_CLEARED becomes unrepresentable and the
    goal re-sends forever."""
    async def scenario():
        state = MockServerState()
        state.checked = set(ALL_LOCATIONS)
        state.delivery_queue = []
        engine, backend = await connected_engine(tmp_path, server_state=state)
        await drain(60)
        assert engine.save.goal_sent is True
        snapshot = engine.snapshot()              # must not raise
        assert snapshot.hub.mode == "ALL_CHECKS_CLEARED"

        reports = backend.server.goal_reports
        assert reports >= 1
        await engine.reconcile()                  # idempotent afterwards
        await engine.reconcile()
        assert backend.server.goal_reports == reports
    run(scenario())


def test_stuck_last_location_releases_without_wedging(tmp_path):
    """A pending claim on a zone's LAST location that AP recognises as
    neither checked nor missing must release cleanly: pending dropped, zone
    abandoned, reconcile never raises."""
    async def scenario():
        state = MockServerState()
        state.checked = set(TIER0[1:])            # only Check 001 remains
        state.delivery_queue = []
        engine, backend = await connected_engine(
            tmp_path, server_state=state, confirm_delay=9999)
        await engine.handle_request_next_zone(False)
        await engine._generation_task
        zone = engine.save.active_zone
        assert list(zone.allocated_location_ids) == [89100001]
        await engine.handle_enter_zone(zone.zone_id)
        await TX.claim_check(engine, zone.zone_id, 89100001)
        assert engine.save.pending_checks

        # AP stops recognising the location as this slot's.
        backend.data.missing.discard(89100001)
        await engine.reconcile()                  # must not raise
        assert not engine.save.pending_checks
        record = engine.save.zone_by_id(zone.zone_id)
        assert record.state == "ABANDONED"
        assert engine.save.active_zone_id is None
        engine.snapshot()                         # still a valid campaign
    run(scenario())


def test_repeat_mock_connect_reuses_server_state(tmp_path):
    """server.py must not build a fresh MockServerState per connect — that
    resets server truth under a persisted save and trips the coin clamp."""
    async def scenario():
        from archipepsi_bridge.server import BridgeServer
        from archipepsi_bridge.mock_ap import MockAPBackend
        from .conftest import make_engine

        engine = make_engine(tmp_path)
        server = BridgeServer(engine, ap_default="mock")
        await server._connect_mock()
        first = engine.backend
        assert isinstance(first, MockAPBackend)
        first.grant_item(C.ITEM_ID_EPSILON_COIN)
        await drain()
        assert engine.ap.coins_received == 1

        await server._connect_mock()              # reconnect
        assert engine.backend is first            # same backend, same truth
        assert engine.ap.coins_received == 1
    run(scenario())
