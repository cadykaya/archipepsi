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
        OCCUPIED_ZONE_STATES, REVISITABLE_ZONE_STATES,
        TERMINAL_ZONE_STATES,
        CampaignSave, EarnedLocalReward, PendingCheck, ShopState,
        ShopStockItem, ZoneRecord,
    )
    from .zone import Zone
except ImportError:  # pragma: no cover
    import constants as C
    from echo import EchoInterpretation
    from protocol import (
        OCCUPIED_ZONE_STATES, REVISITABLE_ZONE_STATES,
        TERMINAL_ZONE_STATES,
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
    # THIS campaign's goal. Pinned to the prototype's 89100030 the rule
    # reserved an ordinary Check in every larger campaign and left the
    # real goal unreserved (CAMPAIGN_SCALE.md 2).
    goal_id = save.scale.config().goal_location_id
    if is_finale and ids != (goal_id,):
        raise ValueError(f"the finale Zone holds exactly [{goal_id}]")
    if not is_finale and goal_id in ids:
        raise ValueError(f"{goal_id} is reserved for the finale Zone")

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
    """GENERATED, DORMANT or COMPLETE -> ACTIVE. Idempotent on ACTIVE.

    **Re-entry, not regeneration.** The layout rebuilds from the
    committed manifest and is identical by construction; `progress` is
    untouched, so the keys collected and the locks opened are still
    collected and open. That is what "returning to the same Zone" means:
    familiar rooms, the branch you left, and your progress still there.

    `COMPLETE` is enterable because claiming the final Check does not
    close the place (ruled 2026-09-12). `ABANDONED` is not, because
    abandonment is the deliberate act that gives the Zone back.
    """
    rec = _require_zone(save, zone_id)
    if rec.state in OCCUPIED_ZONE_STATES:
        return save
    if rec.state not in REVISITABLE_ZONE_STATES:
        raise ValueError(
            f"Zone '{zone_id}' is {rec.state}; nothing to enter")
    # A FINISHED ZONE IS VISITED, NOT RE-ENTERED. Sending it back through
    # ACTIVE would make it reserve its old locations again — colliding
    # with whatever Zone is genuinely in flight, and re-opening Checks
    # the campaign already counted. VISITING is the same experience and
    # different accounting.
    state = "VISITING" if rec.state == "COMPLETE" else "ACTIVE"
    return _rebuild(save,
                    zones=_replace_zone(save, zone_id, state=state),
                    active_zone_id=zone_id)


def rest_zone(save: CampaignSave, zone_id: str) -> CampaignSave:
    """ACTIVE -> DORMANT: left with work outstanding, and kept whole.

    Everything survives — the committed layout, the Check identities,
    which of them are claimed, and the player's progress. **Returning
    unclaimed Checks to the allocator is `abandon_zone`'s behaviour and
    only `abandon_zone`'s**; it is an explicit act with an explicit
    cost, never the silent consequence of walking out of a door.

    A Zone with nothing left to claim goes to `COMPLETE` instead, which
    is also revisitable — the two differ only in whether work remains.
    """
    rec = _require_zone(save, zone_id)
    if rec.state in ("DORMANT", "COMPLETE"):
        return save
    # Leaving a VISIT puts the Zone back exactly as it was. No counter
    # moves, no history entry, no cursor: the campaign already recorded
    # this Zone the first time, and walking through it again is not a
    # second completion.
    if rec.state == "VISITING":
        return _rebuild(save,
                        zones=_replace_zone(save, zone_id,
                                            state="COMPLETE"),
                        active_zone_id=None)
    if rec.state != "ACTIVE":
        raise ValueError(f"Zone '{zone_id}' is {rec.state}, not ACTIVE")
    if any(p.location_id in set(rec.allocated_location_ids)
           for p in save.pending_checks):
        raise ValueError(
            f"Zone '{zone_id}' still has Checks in flight; confirm or "
            "release them before leaving it dormant")
    return _rebuild(save,
                    zones=_replace_zone(save, zone_id, state="DORMANT"),
                    active_zone_id=None)


def _chambers_of(rec: ZoneRecord):
    """This record's chambers, however the Zone happens to be stored.

    `ZoneRecord.zone` is a model in a live save and a plain dict when it
    came off disk mid-migration, and a validator that only understood
    one of those would refuse real progress on a real Zone.
    """
    zone = rec.zone
    if zone is None:
        return ()
    chambers = zone.get("chambers", ()) if isinstance(zone, dict) \
        else zone.chambers
    out = []
    for ch in chambers or ():
        out.append(ch if isinstance(ch, dict) else ch.model_dump())
    return out


def _declared_keys(rec: ZoneRecord) -> set[str]:
    return {str(k.get("key_id")) for ch in _chambers_of(rec)
            for k in (ch.get("keys") or ())}


def _declared_locks(rec: ZoneRecord) -> set[tuple[str, str]]:
    return {(str(ch.get("id")), str(d.get("socket_id")))
            for ch in _chambers_of(rec)
            for d in (ch.get("doors") or ())
            if str(d.get("usage")) == "LOCKED"}


def _declared_stations(rec: ZoneRecord) -> set[str]:
    return {str(s) for s in (rec.manifest or {}).get("stations", ())}


def _progress(save: CampaignSave, zone_id: str, change,
              known) -> CampaignSave:
    """Apply a monotone progress change, idempotently and only if real.

    Every progress set only grows, so applying the same event twice is
    applying it once. A resend after a dropped connection is the normal
    case and must never be an error — which is why this returns `save`
    unchanged rather than raising when nothing moved.

    **An unknown identity is refused, not recorded.** A key the Zone
    never declared, a lock on a door that is not locked, a station the
    layout never placed: each would otherwise become permanent save
    data describing something that does not exist, and progress sets are
    monotone, so nothing would ever take it out again.
    """
    rec = _require_zone(save, zone_id)
    if rec.state not in REVISITABLE_ZONE_STATES:
        raise ValueError(
            f"Zone '{zone_id}' is {rec.state}; it records no progress")
    known(rec)
    nxt = change(rec.progress)
    if nxt == rec.progress:
        return save
    return _rebuild(save,
                    zones=_replace_zone(save, zone_id, progress=nxt))


def commit_layout(save: CampaignSave, zone_id: str,
                  manifest: dict) -> CampaignSave:
    """Store a validated layout. Once, and then never recomputed.

    The caller has already validated: this transition is the atomic
    write, not the decision. A Zone that already carries a manifest keeps
    it — a layout is solved once and replayed forever, so a second
    proposal for the same Zone is a bug upstream rather than an update.
    """
    rec = _require_zone(save, zone_id)
    if rec.manifest is not None:
        if rec.manifest.get("manifest_digest") \
                == manifest.get("manifest_digest"):
            return save
        raise ValueError(
            f"Zone '{zone_id}' already carries layout "
            f"{rec.manifest.get('manifest_digest')}; a committed layout "
            "is replayed, never replaced")
    return _rebuild(save,
                    zones=_replace_zone(save, zone_id, manifest=manifest,
                                        layout_state="ACCEPTED"))


#: How many refused layouts a Zone gets before it stops being composed
#: again. Three, because a second attempt is an ordinary bad roll and a
#: fourth is a defect nothing here can fix by trying harder.
MAX_LAYOUT_REFUSALS = 3


def refuse_layout(save: CampaignSave, zone_id: str) -> CampaignSave:
    """The validator rejected this Zone's geometry. Compose it again.

    **A refusal has to change something.** The first version logged,
    notified, and left the Zone ACTIVE — so the client went on playing a
    Zone the validator had just said does not hold together, and went on
    claiming its Checks against it.

    **The Checks are preserved, and the campaign is not stuck.** Giving
    unclaimed locations back to the allocator is `abandon_zone`'s
    behaviour and only its: an explicit act with an explicit cost. A
    refused layout is a generation problem, not a decision the player
    made — so the Zone goes back to `PENDING_GENERATION` against the
    ids it already holds, which is the same recovery a crash
    mid-generation gets. Epsilon composes it again; nothing is
    re-allocated.

    **And it stops.** A client that refuses every layout would otherwise
    compose forever, so after `MAX_LAYOUT_REFUSALS` the Zone goes DORMANT
    instead: still holding its locations, out of the player's way, and
    waiting for a human rather than spinning.

    **A COMMITTED Zone is preserved, not recomposed.** A refused replay
    of an already-accepted layout is a different situation: the Zone was
    solved once, the manifest is the thing every later load replays, and
    the player's progress is recorded against its rooms. That Zone goes
    DORMANT with its manifest, its content and its progress intact.

    Idempotent in the sense that matters: a second refusal counts once
    more and does the same thing.
    """
    rec = _require_zone(save, zone_id)
    if rec.state in TERMINAL_ZONE_STATES:
        return save
    tries = rec.layout_refusals + 1
    # A COMMITTED ZONE IS NOT RECOMPOSED.
    #
    # The recovery below clears `zone` and `manifest` whatever the Zone
    # was — so a refused REPLAY of an already-accepted layout threw the
    # committed manifest away and sent the Zone back to be composed
    # again: a DIFFERENT Zone, under the same id, holding the same
    # Checks, with the player's collected keys and opened locks still
    # recorded against rooms that no longer exist.
    #
    # Law 47c: the layout is solved once and committed, and every later
    # load replays it. `commit_layout` already refuses to replace a
    # committed manifest; this is the other door into the same room.
    # Regeneration recovery is for a FRESH proposal, and a saved Zone is
    # not one.
    #
    # So a Zone that has committed a manifest keeps it, keeps its
    # content and keeps its progress. The refusal still counts, still
    # takes the Zone out of the player's hands, and still stops it being
    # played against geometry the validator rejected — what it does not
    # do is quietly replace the Zone they were halfway through.
    if rec.manifest is not None:
        return _rebuild(save,
                        zones=_replace_zone(save, zone_id,
                                            state="DORMANT",
                                            layout_state="REFUSED",
                                            layout_refusals=tries),
                        active_zone_id=None
                        if save.active_zone_id == zone_id
                        else save.active_zone_id)
    if tries < MAX_LAYOUT_REFUSALS:
        return _rebuild(save,
                        zones=_replace_zone(save, zone_id,
                                            state="PENDING_GENERATION",
                                            zone=None, manifest=None,
                                            layout_state="REFUSED",
                                            layout_refusals=tries),
                        active_zone_id=zone_id)
    # DORMANT WHATEVER IT WAS, because DORMANT is precisely "yours, not
    # finished, still holding its Checks, and you are not in it". That is
    # true of a Zone the player was standing in and of one they had not
    # entered yet: a GENERATED Zone whose geometry does not hold together
    # must not be offered as ready either.
    #
    # And DORMANT is the one non-terminal state that is never the active
    # Zone, so clearing `active_zone_id` is not a choice here -- the save
    # refuses to validate otherwise, which is the invariant doing its job.
    clear = save.active_zone_id == zone_id
    return _rebuild(save,
                    zones=_replace_zone(save, zone_id, state="DORMANT",
                                        layout_state="REFUSED",
                                        layout_refusals=tries),
                    active_zone_id=None if clear else save.active_zone_id)


def record_key(save: CampaignSave, zone_id: str, key_id: str) -> CampaignSave:
    """A Zone-local key collected. Idempotent by `key_id`."""
    def known(rec):
        declared = _declared_keys(rec)
        if key_id not in declared:
            raise ValueError(
                f"Zone '{zone_id}' declares no key '{key_id}'"
                + (f"; it holds {sorted(declared)}" if declared
                   else " and holds none"))
    return _progress(save, zone_id, lambda p: p.with_key(key_id), known)


def _accepted_packages(rec: ZoneRecord) -> dict[str, set[str]]:
    """`package_id -> declared latch ids`, from the COMMITTED manifest.

    The manifest and not the Zone, because a package is a physical fact
    the engine measured and the bridge accepted — `AMALGAM_BRIDGE.md`
    §5.6 option 2. A Zone whose layout has not been committed has no
    accepted packages at all, which is the honest answer: nothing has
    been measured, so nothing can have latched.
    """
    manifest = rec.manifest or {}
    out: dict[str, set[str]] = {}
    for entry in manifest.get("packages") or ():
        pkg = entry.get("package") or {}
        out[str(entry.get("package_id"))] = {
            str(c.get("latch_id"))
            for c in (pkg.get("latch_conditions") or ())}
    return out


def record_latch(save: CampaignSave, zone_id: str, package_id: str,
                 latch_id: str) -> CampaignSave:
    """A physics latch fired. Idempotent by `package_id/latch_id`.

    **The live signal is not the state.** What is persisted is the
    approved consequence: the event is checked against the packages the
    committed manifest accepted, and only then does it join a monotone
    set that survives a reload. Design 2 §5.7 says a satisfied latch is
    never cleared by reset or death, and quitting is a reset.

    Refused rather than recorded when the package is not one this Zone's
    layout accepted, or when it is and does not declare that latch. A
    latch nobody placed would otherwise become permanent save data
    describing nothing — and monotone sets never give anything back.
    """
    def known(rec):
        packages = _accepted_packages(rec)
        if package_id not in packages:
            raise ValueError(
                f"Zone '{zone_id}' accepted no physics package "
                f"'{package_id}'"
                + (f"; it holds {sorted(packages)}" if packages
                   else " and its committed layout holds none"))
        declared = packages[package_id]
        if latch_id not in declared:
            raise ValueError(
                f"package '{package_id}' in Zone '{zone_id}' declares no "
                f"latch '{latch_id}'"
                + (f"; it declares {sorted(declared)}" if declared
                   else " and declares none"))
    ref = f"{package_id}/{latch_id}"
    return _progress(save, zone_id, lambda p: p.with_latch(ref), known)


def record_lock(save: CampaignSave, zone_id: str, room_id: str,
                socket_id: str) -> CampaignSave:
    """A lock opened. Idempotent by `(room_id, socket_id)`.

    Identified by the DOOR, not the key: one key may open several locks,
    so the key is not the identity of the event.
    """
    def known(rec):
        locks = _declared_locks(rec)
        if (room_id, socket_id) not in locks:
            raise ValueError(
                f"Zone '{zone_id}' has no locked door "
                f"'{room_id}/{socket_id}'"
                + (f"; its locks are {sorted(locks)}" if locks
                   else " and has no locks at all"))
    return _progress(save, zone_id,
                     lambda p: p.with_lock(room_id, socket_id), known)


def record_station(save: CampaignSave, zone_id: str,
                   station_id: str) -> CampaignSave:
    """A warp station reached. Idempotent by `station_id`.

    Travel and save. **Never loadout editing** — editing a loadout
    mid-Zone would re-specify the capabilities validated at entry, which
    is why all five proposals deferred it and why this ruling did not
    bring it back.
    """
    def known(rec):
        stations = _declared_stations(rec)
        if station_id not in stations:
            raise ValueError(
                f"Zone '{zone_id}' placed no station '{station_id}'"
                + (f"; it has {sorted(stations)}" if stations
                   else " and its layout records none"))
    return _progress(save, zone_id,
                     lambda p: p.with_station(station_id), known)


def complete_zone(save: CampaignSave, zone_id: str) -> CampaignSave:
    """ACTIVE -> COMPLETE, pointer cleared, counters advanced — atomically.

    v0.6 documented this as numbered steps that mutate `zones` and then
    `active_zone_id`. Both orders raise: the intermediate state is illegal,
    which is correct and is exactly why this must be one transition.
    """
    rec = _require_zone(save, zone_id)
    if zone_id in save.zone_history:
        raise ValueError(
            f"Zone '{zone_id}' is already counted in this campaign's "
            "history; a revisit completes nothing a second time")
    # ACTIVE or DORMANT: §14.5 completes a Zone with every Check
    # confirmed WHEREVER THE PLAYER IS, and a Zone put down with work
    # outstanding is exactly the case where the last Check can land
    # while they stand in the Hub.
    if rec.state not in ("ACTIVE", "DORMANT"):
        raise ValueError(
            f"Zone '{zone_id}' is {rec.state}, not ACTIVE or DORMANT")
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
    # ACTIVE IS NOT ACCEPTED, and the gap between them is a real window.
    #
    # A graph Zone goes ACTIVE the moment the player walks in and stays
    # UNCERTIFIED until its layout comes back and is validated. That gap
    # is where the client is holding the player still, and it is exactly
    # when a reward that fires on its own -- a timer, a kill, an activity
    # completing -- would have claimed against geometry nobody had
    # checked. `refuse_layout` then puts the Zone back to be composed
    # again, and the Check has already gone to Archipelago and cannot be
    # recalled. The refusal test proved what happens AFTER a rejection;
    # this is the waiting period.
    #
    # A ZONE WITH NO `edges` IS EXEMPT, explicitly rather than by
    # accident. It is the pre-graph shape, it sends no `layout_result`,
    # and its `layout_state` is UNCERTIFIED forever -- so requiring
    # acceptance of it would make every legacy Zone unplayable.
    # `ZoneController._await_verdict` draws the line in the same place.
    if rec.zone is not None and rec.zone.edges \
            and rec.layout_state != "ACCEPTED":
        raise ValueError(
            f"Zone '{zone_id}' has not had its layout accepted "
            f"(layout_state {rec.layout_state}); a graph Zone cannot "
            "claim a Check against geometry the bridge has not validated")
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
    # Likewise: at 450 locations, Check 030 is an ordinary Check, and
    # reading the prototype's constant here ENDED THE CAMPAIGN when it
    # confirmed.
    goal = save.scale.config().is_goal_location(location_id)
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
    rest_zone, record_key, record_latch, record_lock, record_station,
    commit_layout, refuse_layout,
)
