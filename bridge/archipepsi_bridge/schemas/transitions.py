"""Archipepsi v0.7 — the only supported way to change a campaign.

`protocol.py` models are frozen value objects. Every persistent change goes
through a function here, and every function has the same shape:

    take the current CampaignSave -> build the COMPLETE next one -> validate

Nothing is edited in place, so an invariant checked at construction is
checked at every point the campaign ever reaches. That is the whole design.

WHY THIS MODULE EXISTS
----------------------
v0.6 relied on `validate_assignment=True`, which re-validates TOP-LEVEL
assignment only. `save.zones["z1"].state = "COMPLETE"` and
`save.pending_checks.append(...)` ran no validators at all — and both are
exactly what a bridge does. The resulting save serialized fine and then
failed to load, so the bridge fell back to `.bak` and silently rolled the
campaign back. Worse, the documented completion and abandon procedures were
written as two sequential field assignments, and BOTH orders raised, because
the intermediate state is illegal by design.

That is not a validator bug. It is what happens when validated models are
used as live mutable state. So they are not, any more.

Each function raises `ValueError` for an illegal request (the bridge answers
with a recoverable `error`) and `pydantic.ValidationError` if the resulting
campaign would be invalid — which should never happen and means this module
has a bug, not the caller.
"""

from __future__ import annotations

try:
    from . import constants as C
    from .echo import EchoInterpretation
    from .protocol import (
        CampaignSave, EarnedLocalReward, PendingCheck, ShopState,
        ShopStockItem, ZoneRecord,
    )
    from .zone import Zone
except ImportError:  # pragma: no cover
    import constants as C
    from echo import EchoInterpretation
    from protocol import (
        CampaignSave, EarnedLocalReward, PendingCheck, ShopState,
        ShopStockItem, ZoneRecord,
    )
    from zone import Zone


def _rebuild(save: CampaignSave, **changes) -> CampaignSave:
    """The one primitive. Never `model_copy(update=...)`, which skips
    validation entirely and would reintroduce the whole problem."""
    return CampaignSave(**{**save.model_dump(), **changes})


def _replace_zone(save: CampaignSave, zone_id: str, **changes) -> tuple:
    out = []
    for z in save.zones:
        if z.zone_id == zone_id:
            out.append(ZoneRecord(**{**z.model_dump(), **changes}))
        else:
            out.append(z)
    return tuple(out)


def _require_zone(save: CampaignSave, zone_id: str) -> ZoneRecord:
    z = save.zone_by_id(zone_id)
    if z is None:
        raise ValueError(f"no Zone '{zone_id}' in this campaign")
    return z


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

def start_generation(save: CampaignSave, *, zone_id: str,
                     allocated_location_ids, target_game: str,
                     is_finale: bool = False) -> CampaignSave:
    """Reserve locations and enter PENDING_GENERATION. Save before calling
    the provider — that is what makes a crash mid-generation recoverable.

    The one-Zone-at-a-time rule lives here, not only in the Hub mode, so a
    debug command or a replayed intent cannot route around it.
    """
    if any(z.holds_locations for z in save.zones):
        held = next(z.zone_id for z in save.zones if z.holds_locations)
        raise ValueError(
            f"Zone '{held}' still holds locations; finish or abandon it first"
        )
    ids = tuple(allocated_location_ids)
    if is_finale and ids != (C.GOAL_LOCATION_ID,):
        raise ValueError(f"the finale Zone holds exactly [{C.GOAL_LOCATION_ID}]")
    if not is_finale and any(C.is_goal_location(i) for i in ids):
        raise ValueError(f"{C.GOAL_LOCATION_ID} is reserved for the finale Zone")

    in_flight = {p.location_id for p in save.pending_checks}
    clash = sorted(set(ids) & in_flight)
    if clash:
        raise ValueError(f"locations already in flight: {clash}")

    rec = ZoneRecord(zone_id=zone_id, state="PENDING_GENERATION",
                     allocated_location_ids=ids, target_game=target_game,
                     is_finale=is_finale,
                     generation_index=save.generation_counter)
    # Stock overlapping the new allocation is released, not left to clash.
    stock = tuple(i for i in save.shop.stock if i.location_id not in set(ids))
    return _rebuild(
        save,
        zones=save.zones + (rec,),
        active_zone_id=zone_id,
        generation_counter=save.generation_counter + 1,
        shop={**save.shop.model_dump(), "stock": stock},
    )


def accept_zone(save: CampaignSave, zone: Zone, *,
                used_fallback: bool = False) -> CampaignSave:
    """PENDING_GENERATION -> GENERATED, content attached, in one step.

    `zone.validate_zone()` must already have passed: it is the accept-time
    check that the Zone's rewards are EXACTLY the allocation. `ZoneRecord`
    only requires containment, because the allocation legitimately shrinks
    later when a stuck location is released.
    """
    rec = _require_zone(save, zone.zone_id)
    if rec.state != "PENDING_GENERATION":
        raise ValueError(f"Zone '{zone.zone_id}' is {rec.state}, not pending")
    return _rebuild(save, zones=_replace_zone(
        save, zone.zone_id, state="GENERATED", zone=zone.model_dump(),
        used_fallback=used_fallback))


def enter_zone(save: CampaignSave, zone_id: str) -> CampaignSave:
    """GENERATED -> ACTIVE. Idempotent on an already-ACTIVE Zone."""
    rec = _require_zone(save, zone_id)
    if rec.state == "ACTIVE":
        return save
    if rec.state != "GENERATED":
        raise ValueError(f"Zone '{zone_id}' is {rec.state}; nothing to enter")
    return _rebuild(save, zones=_replace_zone(save, zone_id, state="ACTIVE"))


def complete_zone(save: CampaignSave, zone_id: str) -> CampaignSave:
    """ACTIVE -> COMPLETE, pointer cleared, counters advanced — atomically.

    v0.6 documented this as numbered steps that mutate `zones` and then
    `active_zone_id`. Both orders raise: the intermediate state is illegal,
    which is correct and is exactly why this must be one transition.
    """
    rec = _require_zone(save, zone_id)
    if rec.state != "ACTIVE":
        raise ValueError(f"Zone '{zone_id}' is {rec.state}, not ACTIVE")
    if any(p.location_id in set(rec.allocated_location_ids)
           for p in save.pending_checks):
        raise ValueError(
            f"Zone '{zone_id}' still has Checks in flight; confirm or release "
            "them before completing it"
        )
    return _rebuild(
        save,
        zones=_replace_zone(save, zone_id, state="COMPLETE"),
        active_zone_id=None,
        completed_zone_count=save.completed_zone_count + 1,
        zone_history=save.zone_history + (zone_id,),
        track_cursor=save.track_cursor + 1,
    )


def abandon_zone(save: CampaignSave, zone_id: str) -> CampaignSave:
    """Any non-terminal state -> ABANDONED, returning unclaimed locations.

    Legal from PENDING_GENERATION too: a Zone whose generation failed past
    repair and fallback has no content and must still give its locations
    back. Checks already confirmed inside it stay confirmed — they are
    Archipelago's truth, not ours.
    """
    rec = _require_zone(save, zone_id)
    if not rec.holds_locations:
        raise ValueError(f"Zone '{zone_id}' is already {rec.state}")
    in_flight = [p.location_id for p in save.pending_checks
                 if p.location_id in set(rec.allocated_location_ids)]
    if in_flight:
        raise ValueError(
            f"Zone '{zone_id}' has Checks in flight ({sorted(in_flight)}); "
            "they must finalize or roll back before it can be abandoned"
        )
    return _rebuild(
        save,
        zones=_replace_zone(save, zone_id, state="ABANDONED"),
        active_zone_id=None,
        zone_history=save.zone_history + (zone_id,),
    )


def release_location(save: CampaignSave, zone_id: str,
                     location_id: int) -> CampaignSave:
    """Drop one location from a live Zone's reservation, keeping the Zone.

    The reconciliation escape for a Check that can neither finalize nor
    re-send. v0.6 pinned `allocated_location_ids` equal to the accepted
    Zone's rewards for the record's whole life, so the only way out was
    abandoning the Zone and discarding its other unclaimed Checks.

    **Releasing the LAST location abandons the Zone**, by delegating to
    `abandon_zone`. A Zone record that holds no locations is not a state
    this schema has -- `holds_locations` is what ACTIVE means -- so the
    alternative is not "an empty live Zone", it is a refusal that would
    wedge the one caller this exists for. Said here because the call site
    cannot see it: `release_location` reads like it always keeps the Zone,
    and the two tests that pin this behaviour are elsewhere.
    """
    rec = _require_zone(save, zone_id)
    remaining = tuple(i for i in rec.allocated_location_ids if i != location_id)
    if len(remaining) == len(rec.allocated_location_ids):
        raise ValueError(f"Zone '{zone_id}' does not hold {location_id}")
    if not remaining:
        return abandon_zone(save, zone_id)
    pending = tuple(p for p in save.pending_checks
                    if p.location_id != location_id)
    return _rebuild(save,
                    zones=_replace_zone(save, zone_id,
                                        allocated_location_ids=remaining),
                    pending_checks=pending)


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

def claim_zone_check(save: CampaignSave, *, zone_id: str, location_id: int,
                     transaction_id: str) -> CampaignSave:
    """Persist a Zone claim BEFORE sending it to Archipelago."""
    rec = _require_zone(save, zone_id)
    if rec.state != "ACTIVE":
        raise ValueError(f"Zone '{zone_id}' is {rec.state}, not ACTIVE")
    if location_id not in rec.allocated_location_ids:
        raise ValueError(f"Zone '{zone_id}' does not hold {location_id}")
    if any(p.location_id == location_id for p in save.pending_checks):
        raise ValueError(f"{location_id} is already in flight")
    return _rebuild(save, pending_checks=save.pending_checks + (
        PendingCheck(transaction_id=transaction_id, location_id=location_id,
                     source="zone"),))


def buy_shop_stock(save: CampaignSave, *, location_id: int,
                   transaction_id: str, coins_received: int) -> CampaignSave:
    """Leave stock and enter the ledger in ONE transition.

    The cost is persisted before the send, so a crash between the two cannot
    hand out a free item. v0.6 kept the item in `stock` with a `status` field
    beside the ledger — two opinions about one purchase, and a restock could
    evict the pending one.
    """
    item = next((i for i in save.shop.stock if i.location_id == location_id),
                None)
    if item is None:
        raise ValueError(f"{location_id} is not currently in stock")
    if any(p.location_id == location_id for p in save.pending_checks):
        raise ValueError(f"{location_id} is already in flight")
    available = max(0, coins_received - save.coins_spent)
    if available < item.cost:
        raise ValueError(
            f"{item.cost} coins needed, {available} available"
        )
    return _rebuild(
        save,
        coins_spent=save.coins_spent + item.cost,
        pending_checks=save.pending_checks + (
            PendingCheck(transaction_id=transaction_id,
                         location_id=location_id, source="shop",
                         shop_cost=item.cost),),
        shop={**save.shop.model_dump(),
              "stock": tuple(i for i in save.shop.stock
                             if i.location_id != location_id)},
    )


def confirm_check(save: CampaignSave, location_id: int) -> CampaignSave:
    """Archipelago confirmed it. Drop the pending record; the cost stays spent."""
    pending = tuple(p for p in save.pending_checks
                    if p.location_id != location_id)
    if len(pending) == len(save.pending_checks):
        return save                       # already reconciled; idempotent
    goal = C.is_goal_location(location_id)
    return _rebuild(save, pending_checks=pending,
                    goal_sent=save.goal_sent or goal)


def rollback_shop_purchase(save: CampaignSave, location_id: int) -> CampaignSave:
    """The purchase failed. Refund the coins and return the item to stock.

    The only path that decrements `coins_spent`. v0.6 documented the
    decrement as a field assignment, which raised on `ge=0` whenever the
    ledger and the pending record had drifted — an unhandled crash inside the
    error path.
    """
    p = next((p for p in save.pending_checks
              if p.location_id == location_id and p.source == "shop"), None)
    if p is None:
        raise ValueError(f"no pending shop purchase for {location_id}")
    return _rebuild(
        save,
        coins_spent=save.coins_spent - p.shop_cost,
        pending_checks=tuple(x for x in save.pending_checks if x is not p),
    )


# ---------------------------------------------------------------------------
# Shop, Echoes, misc
# ---------------------------------------------------------------------------

def restock_shop(save: CampaignSave, items) -> CampaignSave:
    """Replace the purchasable offers. In-flight purchases are untouched —
    they left `stock` when they were bought."""
    stock = tuple(i if isinstance(i, ShopStockItem) else ShopStockItem(**i)
                  for i in items)
    return _rebuild(save, shop={
        "stock": tuple(s.model_dump() for s in stock),
        "created_after_zone_count": save.completed_zone_count,
    })


def append_interpretation(
    save: CampaignSave, interpretation: EchoInterpretation
) -> CampaignSave:
    """Append one interpretation to the log and advance the counter.

    Replaces v0.7's `add_echo`. Two things it must get right:

    - **The sequence is assigned here, once.** The caller does not choose it;
      whatever `interpretation_seq` arrives is overwritten with the
      campaign's next number, and the counter moves. Nothing downstream ever
      renumbers it.
    - **The fold has to survive it.** `CampaignSave` folds in its validator,
      so an interpretation whose operations dangle cannot be appended — the
      `ValueError` reaches the bridge as a recoverable error, and the
      campaign on disk is untouched.

    Idempotent: an Echo is keyed by its source location, and duplicate
    confirmation of one location must not mint a second."""
    if save.interpretation_by_id(interpretation.echo_id) is not None:
        return save
    seq = save.next_interpretation_seq
    # Revalidated, not `model_copy(update=...)`: the packet bans that
    # everywhere for the same reason, and stamping a sequence is exactly the
    # kind of "one small field" change that skips a validator.
    stamped = EchoInterpretation.model_validate(
        {**interpretation.model_dump(), "interpretation_seq": seq}
    )
    return _rebuild(
        save,
        interpretations=save.interpretations + (stamped,),
        next_interpretation_seq=seq + 1,
    )


def slot_action(
    save: CampaignSave, slot: str, component_id: str | None
) -> CampaignSave:
    """Put an owned Action in a slot, or clear it with a null id.

    Replaces v0.7's `equip_echo`. The checks that matter — the component is
    owned, it is an Action, and its declared slot matches — live in
    `CampaignSave`'s validator, so they hold on every path that can ever
    build a save, not just this one.
    """
    return _rebuild(save, slots=save.slots.with_slot(slot, component_id))


def grant_local_reward(
    save: CampaignSave, reward: EarnedLocalReward
) -> CampaignSave:
    """Record a local reward as earned (ECHOES.md §14.2).

    Idempotent by `reward_id`: finding the same note twice is one note.
    A `challenge_marker` is the exception that proves the rule — it is
    replaced rather than ignored when the new time is better, because a
    personal best that could not improve would be a trophy rather than a
    challenge.

    Nothing here can touch AP: `EarnedLocalReward` has no field that could
    name a location, an item or a Check, so this transition is incapable
    of the mistake §14.2 forbids rather than merely avoiding it.
    """
    if (len(save.local_rewards) >= C.MAX_LOCAL_REWARDS
            and not any(r.reward_id == reward.reward_id
                        for r in save.local_rewards)):
        # Refused HERE, as a ValueError, like every other refusal in this
        # module. Left to `_rebuild`, the 121st reward came back as a
        # pydantic `ValidationError` raised from inside the rebuild -- a
        # different exception type from a different place, which a caller
        # catching this module's refusals does not catch.
        raise ValueError(
            f"the campaign already holds {C.MAX_LOCAL_REWARDS} local rewards, "
            f"which is the limit; '{reward.reward_id}' cannot be added"
        )
    existing = {r.reward_id: r for r in save.local_rewards}
    previous = existing.get(reward.reward_id)
    if previous is not None:
        improved = (reward.kind == "challenge_marker"
                    and previous.best_seconds > 0.0
                    and 0.0 < reward.best_seconds < previous.best_seconds)
        if not improved:
            return save
        existing[reward.reward_id] = reward
        return _rebuild(save, local_rewards=tuple(
            existing[r.reward_id] for r in save.local_rewards))
    return _rebuild(save, local_rewards=save.local_rewards + (reward,))


#: Every transition, for the census test. A new one fails the suite until it
#: is listed — the same shape as the location-field and HubMode censuses.
TRANSITIONS = (
    start_generation, accept_zone, enter_zone, complete_zone, abandon_zone,
    release_location, claim_zone_check, buy_shop_stock, confirm_check,
    rollback_shop_purchase, restock_shop, append_interpretation,
    slot_action, grant_local_reward,
)
