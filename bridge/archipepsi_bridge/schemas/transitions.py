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
        MAX_LAYOUT_REFUSALS,
        OCCUPIED_ZONE_STATES, REVISITABLE_ZONE_STATES,
        TERMINAL_ZONE_STATES,
        CampaignSave, ConsumableAuthorization, ConsumableUse,
        EarnedLocalReward, PendingCheck,
        ShopState,
        ShopStockItem, ZoneRecord,
    )
    from .physics import GRAPH_PACKAGE_PREFIX
    from .zone import Zone
except ImportError:  # pragma: no cover
    import constants as C
    from echo import EchoInterpretation
    from protocol import (
        MAX_LAYOUT_REFUSALS,
        OCCUPIED_ZONE_STATES, REVISITABLE_ZONE_STATES,
        TERMINAL_ZONE_STATES,
        CampaignSave, ConsumableAuthorization, ConsumableUse,
        EarnedLocalReward, PendingCheck,
        ShopState,
        ShopStockItem, ZoneRecord,
    )
    from physics import GRAPH_PACKAGE_PREFIX
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
    # A FRESH PROPOSAL REMEMBERS NOTHING ABOUT THE OLD ONE. Room ids
    # repeat across generations — `c004` in this Zone is not the `c004`
    # the engine measured in the last one — so a placement verdict
    # against replaced content is not evidence about the replacement.
    return _rebuild(save, zones=_replace_zone(
        save, zone.zone_id, state="GENERATED", zone=zone.model_dump(),
        unhostable_rooms=(),
        used_fallback=used_fallback))


def _refill_is_due(save: CampaignSave, zone_id: str) -> bool:
    """Whether entering `zone_id` hands back a fresh consumable supply.

    **PROPOSED BY THIS LANE; NOT DECIDED BY THE OWNER.** What the owner
    chose is "consumables refill on entering a Zone", and nothing finer.
    Everything below — what counts as *entering*, and what a same-Zone
    return does — is this lane's proposal, isolated in one predicate so
    the owner can replace the policy by rewriting one function and its
    tests rather than unpicking the spend transaction.

    The rule as written: **refill when the deployment target changes.**
    `enter_zone` is not the same thing as a deployment beginning — it
    runs again on re-entry, on a generation retry and on a reconnect —
    so the refill is keyed to `consumable_deployment`, the Zone the
    current expenditure belongs to.

    What that actually delivers, stated in full rather than left to be
    discovered in play:

      A -> A (re-entry, reload, Hub round trip): no refill. The trip is
        the same deployment continued, and the alternative is a free
        refill behind two loading screens.
      A -> B: refill. This is what makes charges a per-Zone resource
        rather than a per-campaign one.
      **A -> B -> A: refills BOTH times.** Returning to A does not
        restore what A had left — it hands over a fresh supply. So
        Hub -> B -> A is a working restock loop at the price of one
        extra Zone, and the same-Zone rule above closes the cheap
        version of that loop without closing the loop.

    That last line is the honest cost of a one-string rule, and it is
    why this is a proposal rather than a ruling. PER-ZONE EXPENDITURE
    PERSISTENCE — where what A had left waits for you while you are in B
    — is a different policy, not a bug fix for this one: it needs a
    record per Zone instead of one deployment id, every record has to
    survive a save round trip, and abandoning a Zone has to decide
    whether its record goes with it. The owner has that decision.
    """
    return save.consumable_deployment != zone_id


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
    # A ZONE THAT NEVER LAID OUT IS NOT ENTERABLE (owner decision,
    # 2026-09-12). It is DORMANT like any other, and the only thing
    # behind the portal is geometry the validator has already refused
    # three times: entering it gets the layout refused again and puts it
    # straight back. Refused here rather than only in the Hub, so a
    # replayed intent or a debug command cannot route around it.
    if rec.layout_exhausted:
        raise ValueError(
            f"Zone '{zone_id}' never laid out after "
            f"{rec.layout_refusals} attempts; it cannot be entered. "
            "Discard it to release its Checks.")
    # A FINISHED ZONE IS VISITED, NOT RE-ENTERED. Sending it back through
    # ACTIVE would make it reserve its old locations again — colliding
    # with whatever Zone is genuinely in flight, and re-opening Checks
    # the campaign already counted. VISITING is the same experience and
    # different accounting.
    state = "VISITING" if rec.state == "COMPLETE" else "ACTIVE"
    # CONSUMABLES REFILL ON ENTERING A ZONE (owner decision, 2026-09-22).
    # WHICH entries count as one is `_refill_is_due` — this lane's
    # PROPOSAL, not the owner's ruling, and the whole of it lives in that
    # predicate together with the consequences it has not been asked to
    # accept yet.
    #
    # Expenditure is tracked by component id, so swapping the supply out
    # and back within a deployment preserves what has been spent.
    #
    # A refill MINTS A NEW GENERATION, and that is the only thing that
    # ever does. A use minted against the old supply carries a number
    # that no longer exists, so `spend_charge` refuses it on identity
    # instead of hoping the arithmetic disagrees — which, on an old
    # index 1 arriving at a fresh supply, it does not.
    fresh = _refill_is_due(save, zone_id)
    return _rebuild(save,
                    zones=_replace_zone(save, zone_id, state=state),
                    consumable_uses=() if fresh else save.consumable_uses,
                    # A refill retires the old supply outright, so an
                    # authorization that was outstanding against it goes
                    # with it rather than lingering to be released
                    # against a supply it was never minted for.
                    consumable_authorizations=(
                        () if fresh else save.consumable_authorizations),
                    consumable_generation=(save.consumable_generation + 1
                                           if fresh
                                           else save.consumable_generation),
                    consumable_deployment=zone_id,
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
    waiting for the player to discard it. `ZoneRecord.layout_exhausted`
    is that state, `hub_mode_for` turns it into `ZONE_FAILED`, and the
    Hub offers ABANDON rather than a way back into geometry it already
    refused. Nothing abandons it automatically: that releases the Zone's
    locations, which is the player's call and has a cost.

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
    # A STALE RESULT FOR A ZONE THAT ALREADY GAVE UP CHANGES NOTHING.
    #
    # The budget stopped the RECOMPOSING and not the counting: a client
    # that kept sending `layout_result` kept incrementing a field bounded
    # at 99, and the hundredth refusal raised `ValidationError` out of
    # this function — a schema exception where a domain refusal belongs.
    # Reachable because the Hub then offered the failed Zone as a way
    # back in, so the loop had somewhere to come from.
    #
    # Ignored rather than refused, because a resend after a dropped
    # connection is the ordinary case and never an error — the same
    # reasoning `_progress` is written under.
    if rec.layout_exhausted:
        return save
    # SATURATING, not wrapping and not unbounded. Past the budget the
    # count answers no question anyone asks: it is spent either way, and
    # the alternative is a persisted field that grows until it leaves
    # its own bounds.
    tries = min(rec.layout_refusals + 1, MAX_LAYOUT_REFUSALS)
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


def reselect_hosts(save: CampaignSave, zone_id: str, rooms,
                   zone: Zone) -> CampaignSave:
    """The engine could not host a required return; try other rooms.

    **A different host, not a different Zone.** A branch destination is
    a dead end and takes a return device, and whether a body can stand
    somewhere in that room is a measurement only the engine takes.
    Until now the answer "not in this room" cost the whole Zone: the
    layout was refused, the record went back to PENDING_GENERATION, and
    Epsilon composed a different Zone against the same Checks. Measured
    in a live campaign: a Zone exhausted on a return-location failure.

    So the content and the allocation stay exactly as they are and only
    the GRAPH changes — `zone` is the same chambers recomposed with
    those rooms barred as destinations. The branch is not dropped and
    branching is not suppressed; it moves.

    **Only a fresh proposal.** A record holding a committed manifest is
    a solved Zone the player may be part-way through, and Law 47c says
    every later load replays it; that one keeps its manifest and is
    handled by `refuse_layout`. This raises rather than quietly doing
    the wrong thing to it.

    **Monotone, which is what makes it terminate.** Every refused room
    accumulates, so no host is offered twice and the composer cannot
    oscillate between two of them. The set is finite, so the worst case
    is a Zone with fewer branches — or none, which is the chain it was
    always allowed to be — rather than a Zone that is lost.
    """
    rec = _require_zone(save, zone_id)
    if rec.manifest is not None:
        raise ValueError(
            f"Zone '{zone_id}' has a committed manifest; a solved Zone "
            "is replayed, never recomposed")
    if rec.state in TERMINAL_ZONE_STATES:
        raise ValueError(f"Zone '{zone_id}' is {rec.state}")
    known = set(rec.unhostable_rooms)
    fresh = {str(r) for r in rooms} - known
    if not fresh:
        raise ValueError(
            f"Zone '{zone_id}' was already told about {sorted(known)}; "
            "re-selecting on the same rooms would not terminate")
    if zone.zone_id != zone_id:
        raise ValueError(
            f"recomposed zone '{zone.zone_id}' is not '{zone_id}'")
    return _rebuild(save, zones=_replace_zone(
        save, zone_id, state="GENERATED", zone=zone.model_dump(),
        layout_state="UNCERTIFIED",
        unhostable_rooms=tuple(sorted(known | fresh))),
        active_zone_id=zone_id)


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


def _accepted_graph_latches(rec: ZoneRecord, room_id: str) -> set[str]:
    """The LATCH nodes a room graph may record, or why it may record none.

    Four facts have to hold, and a `graph_<room>` name establishes none
    of them on its own:

    1. **The Zone was accepted** and this is it -- the declaration read
       is `rec.zone`, the one the campaign accepted, not anything the
       engine says it built.
    2. **Its layout was committed** -- `layout_state` ACCEPTED, with a
       manifest for this Zone. A room graph is built off the committed
       layout, so a Zone with none has built nothing and nothing in it
       can have latched. The same honest answer `_accepted_packages`
       gives for physics.
    3. **The committed layout placed that room.** The manifest's `rooms`
       is the layout evidence: a latch in a room the layout never
       placed is a machine nobody built.
    4. **The accepted Zone declares a graph in that room, and it has
       LATCH nodes.** Only those ids are recordable.

    Nothing here consults a physics package, fabricates a certificate,
    or reaches around `record_latch`: a room-graph latch is a different
    kind of accepted fact, checked against its own evidence.
    """
    zone = rec.zone
    manifest = rec.manifest or {}
    if zone is None:
        raise ValueError(f"Zone '{rec.zone_id}' holds no accepted Zone")
    if rec.layout_state != "ACCEPTED" or not manifest:
        raise ValueError(
            f"Zone '{rec.zone_id}' has no committed layout, so no room "
            "graph in it has been built and nothing can have latched")
    if manifest.get("zone_id") != rec.zone_id:
        raise ValueError(
            f"Zone '{rec.zone_id}' carries a manifest for "
            f"'{manifest.get('zone_id')}'")
    if room_id not in (manifest.get("rooms") or {}):
        raise ValueError(
            f"Zone '{rec.zone_id}''s committed layout placed no room "
            f"'{room_id}'")
    graph = next((g for g in zone.room_graphs if g.room_id == room_id),
                 None)
    if graph is None:
        raise ValueError(
            f"room '{room_id}' in Zone '{rec.zone_id}' declares no "
            "signal graph")
    return {n.node_id for n in graph.nodes if n.kind == "LATCH"}


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
        # P14. A ROOM-GRAPH LATCH, under the reserved `graph_` namespace
        # no physics package may take. Checked against the accepted
        # Zone's declaration and the committed layout; the physics path
        # below is untouched.
        if package_id.startswith(GRAPH_PACKAGE_PREFIX):
            room_id = package_id[len(GRAPH_PACKAGE_PREFIX):]
            latches = _accepted_graph_latches(rec, room_id)
            if latch_id not in latches:
                raise ValueError(
                    f"the signal graph in room '{room_id}' of Zone "
                    f"'{zone_id}' declares no LATCH '{latch_id}'"
                    + (f"; it declares {sorted(latches)}" if latches
                       else " and declares none"))
            return
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


def record_zone_state(save: CampaignSave, zone_id: str, variable_id: str,
                      state: str) -> CampaignSave:
    """D-8. A player operated a setter and the Zone's state changed.

    **The authoritative state-update path.** The engine reports that a
    control was worked; what becomes save data is the accepted
    consequence, checked against the Zone the campaign actually
    accepted — the same shape as `record_latch`, and for the same
    reason.

    Three refusals, each a different way of being wrong:

    1. **The Zone declares no such variable.** Otherwise a typo becomes
       persistent save data describing nothing.
    2. **The variable has no such state.** A state outside its declared
       set is a value no reader has a rule for.
    3. **No setter can select that state.** This is the one a latch
       analogy would miss. `states` is what the variable can HOLD;
       `setter.selects` is what a player can PUT it in. A state that is
       declared but unselectable is reachable only by something other
       than a player operating a control, and §19.7 is explicit that
       nothing else may move Zone state.

    **Not monotone, and deliberately not on `latched`.** A reversible
    variable set back is a legitimate transition, so this overwrites.
    `ZoneProgress.macro_state` exists to hold exactly that, and the
    resume-safety argument for the monotone sets is untouched by it.

    **What this does NOT check, and the boundary matters.** It does not
    assert the player was physically able to reach and work that
    control. Whether Blindside's gantry is genuinely out of reach at
    4.6 m is a measurement the engine owns; what the bridge settles is
    that the Zone declares this control, that it can choose this state,
    and that the route validation at acceptance already proved the
    configuration is not self-locking.
    """
    def known(rec):
        zone = rec.zone
        declared = {v.variable_id: v for v in getattr(zone, "zone_state", ())
                    } if zone is not None else {}
        var = declared.get(variable_id)
        if var is None:
            raise ValueError(
                f"Zone '{zone_id}' declares no Zone-state variable "
                f"'{variable_id}'"
                + (f"; it declares {sorted(declared)}" if declared
                   else " and declares none"))
        if state not in var.states:
            raise ValueError(
                f"variable '{variable_id}' in Zone '{zone_id}' has no state "
                f"'{state}'; it has {sorted(var.states)}")
        if state not in var.setter.selects:
            raise ValueError(
                f"no control can put '{variable_id}' into '{state}'; the "
                f"setter in room '{var.setter.room_id}' selects "
                f"{sorted(var.setter.selects)}. Zone state changes only "
                "when a player operates a setter (§19.7), so a state "
                "nothing selects is one nothing could have set")
        # O05-02. A STATE A CONSUMER OWNS IS SET BY DELIVERING ITS
        # OBJECT, and by nothing else. The consumer IS that variable's
        # setter -- installing the object is the interaction -- so a bare
        # `zone_state_selected` naming it is a claim of a delivery that
        # `record_object_consumed` would have checked, arriving by a
        # path that checks nothing.
        for con in getattr(zone, "object_consumers", ()):
            if con.sets_variable == variable_id \
                    and con.sets_state == state:
                raise ValueError(
                    f"'{variable_id}' = '{state}' is set by consumer "
                    f"'{con.mechanism_id}' taking '{con.accepts}' in room "
                    f"'{con.room_id}'; deliver the object -- it is not a "
                    "control a message can operate")
    return _progress(save, zone_id,
                     lambda p: p.with_macro(variable_id, state), known)


def record_object_transported(save: CampaignSave, zone_id: str,
                              object_id: str, room_id: str) -> CampaignSave:
    """P16. A transported object arrived somewhere, authoritatively.

    Three refusals:

    1. **The Zone declares no such object.** A room recorded against an
       id nothing placed is save data describing nothing.
    2. **The room is outside the object's `allowed_volume`.** §10.5's
       volume is the composer's statement of where the object may go,
       and accepting an arrival outside it would describe a world the
       composer never allowed.
    3. *(not a refusal, but the same rule)* a repeat of the room it is
       already in is absorbed.

    **Recovery is `home_room_id`, not a refusal.** P16.4's lost or
    invalid object is put back where the declaration says it comes home
    to, and `recover_transported_object` below is that path -- kept
    separate so "it went somewhere illegal" and "put it back" are two
    events rather than one silent correction.
    """
    def known(rec):
        zone = rec.zone
        declared = {o.object_id: o
                    for o in getattr(zone, "transported_objects", ())
                    } if zone is not None else {}
        obj = declared.get(object_id)
        if obj is None:
            raise ValueError(
                f"Zone '{zone_id}' declares no transported object "
                f"'{object_id}'"
                + (f"; it declares {sorted(declared)}" if declared
                   else " and declares none"))
        if room_id not in obj.allowed_volume:
            raise ValueError(
                f"object '{object_id}' may not be in room '{room_id}'; its "
                f"volume is {sorted(obj.allowed_volume)}")
        # O05-02.4: AN INSTALLED OBJECT DOES NOT TRAVEL. Its consumer's
        # room is the last room it was in; a report of the same room is
        # the same fact again, anything else would describe a second copy.
        if rec.progress.consumed(object_id) \
                and rec.progress.object_room(object_id) != room_id:
            raise ValueError(
                f"'{object_id}' is installed in its consumer and does not "
                f"move; it cannot arrive in '{room_id}'")
    return _progress(save, zone_id,
                     lambda p: p.with_object_in(object_id, room_id), known)


def record_object_consumed(save: CampaignSave, zone_id: str,
                           mechanism_id: str) -> CampaignSave:
    """P16. A consuming mechanism took the object it was waiting for.

    **The object must actually be there.** This is the check that makes
    transport mean something: the consumer fires only when the save says
    its object is in the consumer's own room. A mechanism that fired on
    a message alone would let a client claim a delivery it never made,
    and the whole carried route would be decorative.

    The consequence goes through D-8's handle -- `with_macro` on the
    declared variable -- so nothing here is a second way for one room to
    change another.
    """
    def known(rec):
        zone = rec.zone
        consumers = {c.mechanism_id: c
                     for c in getattr(zone, "object_consumers", ())
                     } if zone is not None else {}
        con = consumers.get(mechanism_id)
        if con is None:
            raise ValueError(
                f"Zone '{zone_id}' declares no object consumer "
                f"'{mechanism_id}'"
                + (f"; it declares {sorted(consumers)}" if consumers
                   else " and declares none"))
        # A REPEAT OF THE SAME DELIVERY IS ABSORBED BELOW; anything else
        # about an object already taken is refused, because it would be
        # a second consumption of one object.
        held = rec.progress.consumed_by(con.accepts)
        if held == mechanism_id:
            return      # the same delivery, reported again: absorbed
        if held is not None:
            raise ValueError(
                f"'{con.accepts}' is already installed in '{held}'; "
                f"consumer '{mechanism_id}' cannot take it as well")
        where = rec.progress.object_room(con.accepts)
        if where != con.room_id:
            raise ValueError(
                f"consumer '{mechanism_id}' is in room '{con.room_id}' and "
                f"'{con.accepts}' is "
                + (f"in '{where}'" if where else "not anywhere yet")
                + "; the object has to be delivered before it is consumed")

    rec = _require_zone(save, zone_id)
    # LOOK IT UP SAFELY. `next()` on an empty generator raises
    # StopIteration before `known` ever runs, so an unknown mechanism
    # came back as a bare traceback instead of the refusal written for
    # it -- an error path that swallowed its own error message.
    con = next((c for c in getattr(rec.zone, "object_consumers", ())
                if c.mechanism_id == mechanism_id), None)

    def apply(p):
        if con is None:
            return p        # `known` refuses first; this never runs
        # CONSUMED, and never rebuilt loose (§30.6.1). Monotone, so the
        # same delivery reported twice changes nothing the second time.
        taken = p.with_consumed(con.accepts, mechanism_id)
        if con.sets_variable is None:
            return taken    # scenery: legal, and it changes nothing else
        return taken.with_macro(con.sets_variable, con.sets_state)

    return _progress(save, zone_id, apply, known)


def recover_transported_object(save: CampaignSave, zone_id: str,
                               object_id: str) -> CampaignSave:
    """P16.4. Put a lost or unreachable object back where it comes home.

    Separate from `record_object_transported` on purpose: recovery is a
    decision about a broken situation, and folding it into the ordinary
    arrival path would make every illegal arrival silently correct
    itself with nothing to notice.
    """
    def known(rec):
        zone = rec.zone
        declared = {o.object_id: o
                    for o in getattr(zone, "transported_objects", ())
                    } if zone is not None else {}
        if object_id not in declared:
            raise ValueError(
                f"Zone '{zone_id}' declares no transported object "
                f"'{object_id}'")
        if rec.progress.consumed(object_id):
            raise ValueError(
                f"'{object_id}' is installed in its consumer; an installed "
                "object is not lost, and recovering it would put a second "
                "copy back home")

    rec = _require_zone(save, zone_id)
    obj = next((o for o in getattr(rec.zone, "transported_objects", ())
                if o.object_id == object_id), None)

    def apply(p):
        if obj is None:
            return p        # `known` refuses first; this never runs
        # HOME, AND NO LONGER WHERE IT WAS LOST: the pose goes with it.
        return p.with_object_in(object_id, obj.home_room_id) \
            .without_object_pose(object_id)

    return _progress(save, zone_id, apply, known)


def record_object_settled(save: CampaignSave, zone_id: str, object_id: str,
                          room_id: str, position: tuple[float, float, float],
                          yaw: float) -> CampaignSave:
    """O05-03. A transported object came to rest where the hand left it.

    The same refusals as `record_object_transported` -- a declared
    object, a room inside its volume -- plus two of its own:

    - **A consumed object does not settle anywhere.** It is installed,
      and a pose for it would describe a second copy.
    - **A pose must be a number a room could hold.** The engine measures
      it; the bridge has no geometry and does not pretend to, but it
      refuses a non-finite or absurd coordinate rather than storing it.
    """
    import math

    def known(rec):
        zone = rec.zone
        declared = {o.object_id: o
                    for o in getattr(zone, "transported_objects", ())
                    } if zone is not None else {}
        obj = declared.get(object_id)
        if obj is None:
            raise ValueError(
                f"Zone '{zone_id}' declares no transported object "
                f"'{object_id}'")
        if room_id not in obj.allowed_volume:
            raise ValueError(
                f"object '{object_id}' may not rest in room '{room_id}'; "
                f"its volume is {sorted(obj.allowed_volume)}")
        if rec.progress.consumed(object_id):
            raise ValueError(
                f"'{object_id}' is installed in its consumer and rests "
                "nowhere else")
        if not all(math.isfinite(c) and abs(c) < 10_000.0
                   for c in (*position, yaw)):
            raise ValueError(
                f"'{object_id}' reported a pose {position}/{yaw} no room "
                "could hold")

    return _progress(save, zone_id,
                     lambda p: p.with_object_pose(object_id, room_id,
                                                  position, yaw),
                     known)


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


def spend_charge(save: CampaignSave, component_id: str,
                 use_index: int, generation: int) -> CampaignSave:
    """Spend one use of a consumable. It stays equipped when empty.

    **The supply is permanently owned** (owner decision, 2026-09-22).
    Spending the last charge does not clear the slot -- the item stays
    selected at `0 / max`, says it is exhausted and says what refills it,
    and the refill makes it usable again with no inventory visit. The
    thing that is refused is USING an empty one, which is this function,
    not holding one.

    **THE TRANSACTION IS A COMPARE-AND-SWAP ON TWO THINGS: WHICH SUPPLY,
    AND WHICH USE OF IT.** `generation` is the supply the caller was
    looking at when it acted; `use_index` is which use of that supply
    this is meant to be -- the first, the second. The spend is accepted
    only if the generation is still current AND the index is the next one
    due. What each half catches:

      TWO PRESSES ON THE LAST CHARGE (index). Both mint the same index
      because neither has seen a snapshot yet. The first moves `spent`
      past it; the second no longer matches and is refused. At most one
      activation succeeds.
      A DUPLICATE OR RETRIED MESSAGE (index). Same index, already
      consumed, same refusal -- so a retry can never spend twice or
      replay an effect.
      A USE MINTED BEFORE A REFILL (generation). **The index cannot
      catch this one, which is why the generation exists.** An old use 1
      arriving at a fresh supply IS the next index due (`1 == 0 + 1`);
      an old use 3 is the next one due again once two legitimate new uses
      have brought `spent` to 2. Both would eat a charge from a supply
      they were never minted against. The generation no longer exists, so
      both are refused on identity instead.

    The Zone id could not have stood in for the generation: it is reused
    every time you walk back in, so a use from the last visit to A would
    still name A. Minted only by a refill, never reused.

    Refuses rather than saturating. A caller that has lost count should
    find out here, not by watching the number stay at zero.
    """
    charges = _consumable_charges(save, component_id)
    # THE GENERATION IS CHECKED FIRST, and it is checked before the
    # count, so a stale use is reported as stale rather than as bad
    # arithmetic. Three tests in this lane have now passed for the wrong
    # reason; a refusal that names the wrong cause is how that happens.
    if generation != save.consumable_generation:
        raise ValueError(
            f"'{component_id}' use {use_index} was minted against supply "
            f"{generation}; the current supply is "
            f"{save.consumable_generation}. It was refilled after the "
            f"press, so this use no longer exists")
    # AN AUTHORIZED CHARGE IS ALREADY COUNTED, so the report that
    # follows it settles the record rather than spending again. Without
    # this, authorizing and then reporting the same use would take two
    # charges for one effect -- the opposite failure to the one
    # authorizing was introduced to close, and just as silent.
    held = save.consumable_authorizations
    settled = next((a for a in held
                    if a.component_id == component_id
                    and a.generation == generation
                    and a.use_index == use_index), None)
    if settled is not None:
        return _rebuild(save, consumable_authorizations=tuple(
            a for a in held if a is not settled))
    spent = charges - save.charges_left(component_id)
    if spent >= charges:
        raise ValueError(
            f"'{component_id}' has no charges left ({spent} of {charges})")
    if use_index != spent + 1:
        raise ValueError(
            f"'{component_id}' use {use_index} is not the next one due "
            f"({spent + 1}); a duplicate or a retry")
    uses = tuple(u for u in save.consumable_uses
                 if u.component_id != component_id)
    uses += (ConsumableUse(component_id=component_id, spent=spent + 1),)
    # THE SLOT IS NOT CLEARED. A consumable is a permanently owned
    # refillable supply: spending the last charge leaves it selected at
    # `0 / max` with exhausted feedback, and the refill makes the same
    # equipped item usable again without another trip to the inventory.
    # Only an explicit equipment change replaces it.
    return _rebuild(save, consumable_uses=uses)


def _consumable_charges(save: CampaignSave, component_id: str) -> int:
    """How many charges this component has, or the refusal saying why it
    has none. Shared by the three functions that move a charge, because
    three copies of one lookup is three places to stop agreeing."""
    owned = save.derive().by_id(component_id)
    if owned is None or owned.kind != "action":
        raise ValueError(f"'{component_id}' is not an owned Action")
    charges = getattr(owned.component, "charges", None)
    if charges is None:
        raise ValueError(f"'{component_id}' is not a consumable")
    return charges


def authorize_consumable(save: CampaignSave, component_id: str, *,
                         use_index: int, generation: int) -> CampaignSave:
    """Count a charge BEFORE the client launches the effect.

    **PROPOSED, NOT AGREED.** The client half is Prod's and is
    unwritten, so this is the bridge's side of a contract that has
    one owner per file and must have one shape. The proposal, the
    two boundaries it distinguishes and what it asks of the client
    are in `docs/D9_CONSUMABLE_ACCOUNTING_PROD.md`; if the engine
    lane prefers another accounting shape, this is the half that
    moves.

    The whole point is that this reaches the disk before anything
    irreversible happens. `spend_charge` learns about expenditure from a
    report, and a report is exactly what a crash loses: launch, lose the
    report, kill the client, relaunch into the same unrefilled
    deployment, and a report-driven bridge still believes the charge is
    there. Retaining and retransmitting an in-memory list survives a
    dropped socket and does not survive the process.

    So `spent` moves here. The record this writes exists only so an
    attempt that never launched can be cancelled
    (`release_consumable_authorization`); a crash between this call and
    the launch BURNS the charge, which is the conservative direction and
    the cost of authorizing first.

    Same compare-and-swap as the spend, checked in the same order and
    for the same reasons -- generation before count, so a stale
    authorization is reported as stale rather than as bad arithmetic.
    """
    charges = _consumable_charges(save, component_id)
    if generation != save.consumable_generation:
        raise ValueError(
            f"'{component_id}' authorization {use_index} was minted "
            f"against supply {generation}; the current supply is "
            f"{save.consumable_generation}. It was refilled after the "
            "press, so this use no longer exists")
    spent = charges - save.charges_left(component_id)
    if spent >= charges:
        raise ValueError(
            f"'{component_id}' has no charges left ({spent} of {charges})")
    if use_index != spent + 1:
        raise ValueError(
            f"'{component_id}' authorization {use_index} is not the next "
            f"one due ({spent + 1}); a duplicate or a retry")
    uses = tuple(u for u in save.consumable_uses
                 if u.component_id != component_id)
    uses += (ConsumableUse(component_id=component_id, spent=spent + 1),)
    held = save.consumable_authorizations + (
        ConsumableAuthorization(component_id=component_id,
                                generation=generation,
                                use_index=use_index),)
    return _rebuild(save, consumable_uses=uses,
                    consumable_authorizations=held)


def release_consumable_authorization(
        save: CampaignSave, component_id: str, *, use_index: int,
        generation: int) -> CampaignSave:
    """Cancel an attempt that never launched, and ONLY that attempt.

    **PROPOSED, NOT AGREED.** The client half is Prod's and is
    unwritten, so this is the bridge's side of a contract that has
    one owner per file and must have one shape. The proposal, the
    two boundaries it distinguishes and what it asks of the client
    are in `docs/D9_CONSUMABLE_ACCOUNTING_PROD.md`; if the engine
    lane prefers another accounting shape, this is the half that
    moves.

    **The defect this shape does not have.** A reservation held as one
    entry per component is overwritten by the next press, so cancelling
    the second forgets the first -- and the first had already launched.
    Here an authorization is keyed by `(component, generation,
    use_index)`, so two presses inside one cooldown are two records and
    cancelling the later one leaves the earlier expenditure standing.

    **Only the newest may be released.** Releasing an authorization that
    is not the last one spent would leave a hole in the index sequence
    that `use_consumable`'s "next one due" check could never fill again.
    This is also what makes a release from a FRESH process harmless: by
    the time such a client has pressed anything, the index it could name
    is no longer the newest.

    Whether the effect launched is a thing only the process that
    launched it knows, so that claim is the caller's and this function
    takes it at its word. What it refuses to do is let a claim be made
    about an attempt the caller cannot have made.
    """
    charges = _consumable_charges(save, component_id)
    held = save.consumable_authorizations
    match = next((a for a in held
                  if a.component_id == component_id
                  and a.generation == generation
                  and a.use_index == use_index), None)
    if match is None:
        raise ValueError(
            f"'{component_id}' has no outstanding authorization "
            f"{use_index} against supply {generation}; it was already "
            "reported, already released, or never made")
    spent = charges - save.charges_left(component_id)
    if use_index != spent:
        raise ValueError(
            f"'{component_id}' authorization {use_index} is not the "
            f"newest ({spent}); releasing it would leave a gap in the "
            "use sequence that nothing could fill")
    uses = tuple(u for u in save.consumable_uses
                 if u.component_id != component_id)
    if spent - 1 > 0:
        uses += (ConsumableUse(component_id=component_id, spent=spent - 1),)
    return _rebuild(
        save, consumable_uses=uses,
        consumable_authorizations=tuple(a for a in held if a is not match))


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
    spend_charge,
    authorize_consumable,
    release_consumable_authorization,
    start_generation, accept_zone, enter_zone, complete_zone, abandon_zone,
    release_location, claim_zone_check, buy_shop_stock, confirm_check,
    rollback_shop_purchase, restock_shop, append_interpretation,
    slot_action, grant_local_reward,
    rest_zone, record_key, record_latch, record_lock, record_station,
    record_zone_state, record_object_transported, record_object_consumed,
    record_object_settled,
    recover_transported_object,
    reselect_hosts,
    commit_layout, refuse_layout,
)
