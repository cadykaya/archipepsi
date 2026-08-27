"""Pending-check lifecycle: claim, purchase, finalize, reconcile.

The one rule (TECHNICAL_ARCHITECTURE §5): finalization is RECONCILIATION
against `checked_locations`, never an event wait. `check_locations()`
filters already-checked locations client-side and the server broadcasts
nothing when nothing is new; code that waits hangs forever.

Every pending check has a terminal failure state: a location AP recognises
as neither missing nor checked (evaluated only after a completed
post-`Connected` sync) is released — and a shop record's cost is refunded
in the same step. One code path for both sources.
"""

from __future__ import annotations

import logging
import uuid

from .campaign import CampaignEngine, IntentError
from .schemas import constants as C
from .schemas import transitions as T

log = logging.getLogger("archipepsi.transactions")


def _new_txid() -> str:
    return f"tx_{uuid.uuid4().hex[:16]}"


async def claim_check(engine: CampaignEngine, zone_id: str,
                      location_id: int) -> None:
    """Zone reward claim. Persist the pending record BEFORE the send."""
    engine._require_save()
    if location_id in engine.ap.checked:
        # Already server-confirmed: finalize immediately, send nothing.
        await finalize(engine, location_id)
        await engine.broadcast_snapshot()
        return
    engine._require_online()
    try:
        engine._apply(T.claim_zone_check(
            engine.save, zone_id=zone_id, location_id=location_id,
            transaction_id=_new_txid()))
    except ValueError as exc:
        raise IntentError(str(exc)) from exc

    sent = await engine.backend.check_locations([location_id])
    if location_id in engine.ap.checked:
        await finalize(engine, location_id)
    elif not sent and location_id not in engine.ap.missing:
        await terminal_release(engine, location_id)
    else:
        engine.schedule_reconcile_timers()
    await engine.broadcast_snapshot()


async def buy_shop_stock(engine: CampaignEngine, location_id: int) -> None:
    """§11.7: verify all four conditions, persist cost before send."""
    engine._require_save()
    engine._require_online()
    if location_id not in engine.ap.missing:
        # Server no longer reports it missing: stale stock. Reconcile clears.
        await engine.reconcile()
        await engine.broadcast_snapshot()
        raise IntentError("that offer is stale; the location is not available")
    try:
        engine._apply(T.buy_shop_stock(
            engine.save, location_id=location_id, transaction_id=_new_txid(),
            coins_received=engine.ap.coins_received))
    except ValueError as exc:
        raise IntentError(str(exc)) from exc

    sent = await engine.backend.check_locations([location_id])
    if location_id in engine.ap.checked:
        await finalize(engine, location_id)
    elif not sent and location_id not in engine.ap.missing:
        await terminal_release(engine, location_id)
    else:
        engine.schedule_reconcile_timers()
    await engine.broadcast_snapshot()


async def finalize(engine: CampaignEngine, location_id: int) -> None:
    """The location is in `checked_locations`. Idempotent."""
    save = engine.save
    pending = next((p for p in save.pending_checks
                    if p.location_id == location_id), None)
    was_shop = pending is not None and pending.source == "shop"
    goal_newly_sent = (C.is_goal_location(location_id)
                       and not save.goal_sent)

    engine._apply(T.confirm_check(save, location_id))
    # confirm_check is idempotent via its pending record — a goal confirmed
    # EXTERNALLY (release/!collect, so no pending) returns the save
    # unchanged and would leave goal_sent False forever, re-sending the goal
    # on every pass and making ALL_CHECKS_CLEARED unrepresentable.
    if goal_newly_sent and not engine.save.goal_sent:
        engine._apply(_set_goal_sent(engine.save))

    if goal_newly_sent:
        if engine.backend is not None and engine.ap.connected:
            await engine.backend.send_goal()
        await engine._notify(
            "goal_reached", "TRANSMISSION COMPLETE",
            ("The goal has been reported to Archipelago.",
             "The Hub stays open — remaining Checks are still out there."))

    scout = engine.ap.scouts.get(location_id)
    if pending is not None and scout is not None:
        if scout.recipient_is_self:
            await engine._notify(
                "check_confirmed", "CHECK CONFIRMED",
                (scout.item_name, "Delivered to you."),
                location_id=location_id)
        else:
            echo_id = await engine.grant_echo(location_id)
            echo = engine.save.echo_by_id(echo_id) if echo_id else None
            lines = [scout.item_name, scout.recipient_game]
            if echo is not None:
                lines += ["", "EPSILON ECHO ACQUIRED", echo.display_name,
                          echo.description]
            await engine._notify(
                "reveal", f"SENT TO {scout.recipient_name.upper()}",
                lines, location_id=location_id, echo_id=echo_id)
        if was_shop:
            await engine._notify(
                "shop_purchased", "PURCHASE COMPLETE",
                (scout.item_name, f"→ {scout.recipient_name}"),
                location_id=location_id)

    zone_completion_sweep(engine)


async def terminal_release(engine: CampaignEngine, location_id: int) -> None:
    """§5 terminal failure: AP does not recognise the location as this
    slot's. Release it; refund a shop record in the same step."""
    save = engine.save
    pending = next((p for p in save.pending_checks
                    if p.location_id == location_id), None)
    if pending is None:
        return
    log.error("pending check %s (source=%s) is unknown to Archipelago; "
              "releasing", location_id, pending.source)
    if pending.source == "shop":
        engine._apply(T.rollback_shop_purchase(save, location_id))
    else:
        holder = next((z for z in save.zones if z.holds_locations
                       and location_id in z.allocated_location_ids), None)
        if holder is not None:
            # Drop the pending BEFORE releasing: when this is the zone's
            # last location, release_location abandons the zone, and
            # abandon_zone rejects a zone with checks still in flight.
            engine._apply(_drop_pending(engine.save, location_id))
            engine._apply(T.release_location(engine.save, holder.zone_id,
                                             location_id))
        else:  # unbacked pending cannot exist in a valid save; belt+braces
            engine._apply(_drop_pending(save, location_id))
    await engine._notify(
        "sync_warning", "CHECK RELEASED",
        (f"Archipelago does not recognise location {location_id}.",
         "Refunded and released." if pending.source == "shop"
         else "Released back to the pool."))


def _drop_pending(save, location_id):
    """Bridge-local rebuild dropping one pending record, full validation."""
    from .schemas.protocol import CampaignSave
    return CampaignSave(**{
        **save.model_dump(),
        "pending_checks": tuple(
            p.model_dump() for p in save.pending_checks
            if p.location_id != location_id)})


def _set_goal_sent(save):
    """Bridge-local rebuild for the externally-confirmed-goal path."""
    from .schemas.protocol import CampaignSave
    return CampaignSave(**{**save.model_dump(), "goal_sent": True})


def zone_completion_sweep(engine: CampaignEngine) -> None:
    """§14.5: a Zone with every assigned Check confirmed completes
    automatically, wherever the player is. Idempotent."""
    save = engine.save
    if save is None:
        return
    pending = engine._pending_location_ids()
    for record in save.zones:
        if record.state not in ("ACTIVE", "GENERATED"):
            continue
        ids = set(record.allocated_location_ids)
        if not ids or not ids.issubset(engine.ap.checked) or ids & pending:
            continue
        if record.state == "GENERATED":
            engine._apply(T.enter_zone(engine.save, record.zone_id))
        engine._apply(T.complete_zone(engine.save, record.zone_id))
        engine.apply_shop_cadence()
        log.info("zone %s complete (%d total)", record.zone_id,
                 engine.save.completed_zone_count)


async def reconcile(engine: CampaignEngine) -> None:
    """The post-Connected pass, re-run on every RoomUpdate and timer."""
    if engine.save is None:
        return
    ap = engine.ap
    if not (ap.connected and ap.synced):
        # Both truth sets are meaningful only after `Connected` populates
        # them; evaluating rollback on a raw snapshot refunds live purchases.
        return

    resend: list[int] = []
    for p in list(engine.save.pending_checks):
        if p.location_id in ap.checked:
            await finalize(engine, p.location_id)
        elif p.location_id in ap.missing:
            resend.append(p.location_id)
        else:
            await terminal_release(engine, p.location_id)
    if resend:
        log.info("re-sending %d pending checks: %s", len(resend), resend)
        await engine.backend.check_locations(resend)

    # Goal confirmed externally (e.g. an admin release checked everything).
    # The goal re-send for a reconnect lives in on_ap_ready; here we only
    # react to a fresh confirmation.
    if C.GOAL_LOCATION_ID in ap.checked and not engine.save.goal_sent:
        await finalize(engine, C.GOAL_LOCATION_ID)

    zone_completion_sweep(engine)

    # Shop stock reconciliation: checked or invalid reservations release.
    stale = {i.location_id for i in engine.save.shop.stock
             if i.location_id in ap.checked
             or i.location_id not in (ap.checked | ap.missing)}
    if stale:
        keep = [i.model_dump() for i in engine.save.shop.stock
                if i.location_id not in stale]
        engine._apply(T.restock_shop(engine.save, keep))

    await engine.echo_backlog_sweep()
    engine.release_stock_before_waiting()
