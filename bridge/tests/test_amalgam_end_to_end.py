"""One ordinary generated Zone, all the way through.

generation -> graph -> physical layout -> returned evidence ->
validation -> persisted manifest -> play -> leave -> reload -> re-enter.

**Every step goes through a real handler.** Earlier progress tests
assigned transition results straight onto `engine.save`, which proves a
function works and says nothing about whether anything calls it. Nothing
here touches `engine.save` except to read it.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge import store
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas.protocol import ClientMessage
from pydantic import TypeAdapter

from archipepsi_bridge import transactions as TX
from archipepsi_bridge.campaign import IntentError
from archipepsi_bridge.schemas import transitions as T

from .conftest import (Collector, connected_engine, drain,
                       enter_zone, place_layout as _place, run)

_ADAPTER = TypeAdapter(ClientMessage)

async def _branching_zone(engine):
    """Generate until one is big enough to carry a branch."""
    for _ in range(3):
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        zone = engine.save.zone_by_id(zid).zone
        if zone.plugs and any(k for c in zone.chambers for k in c.keys):
            return zid, zone
        await engine.handle_enter_zone(zid)
        await engine.handle_abandon_zone(zid)
    pytest.skip("no branching Zone generated in three attempts")


def test_the_whole_path(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        sink = Collector(engine)

        # 1. GENERATION produces a graph, not a list.
        zone_id, zone = await _branching_zone(engine)
        assert zone.edges and zone.plugs
        junction = max(c.door_degree for c in zone.chambers)
        assert junction >= 3, "an ordinary Zone should carry a junction"
        # A Zone being SOLVED for the first time carries no manifest.
        # This is the control for the re-entry assertion in step 6: with
        # nothing to contrast against, `manifest` present would prove
        # only that the field exists.
        born = [m for m in sink.of_type("zone_ready")
                if m.zone.zone_id == zone_id]
        assert born and all(m.manifest is None for m in born), (
            "a first generation has nothing to replay")
        key = next(k.key_id for c in zone.chambers for k in c.keys)
        room, socket = next((c.id, d.socket_id) for c in zone.chambers
                            for d in c.doors if d.usage == "LOCKED")

        # 2. PHYSICAL LAYOUT comes back as evidence and is VALIDATED.
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zone_id,
             "layout": _place(zone)}))
        rec = engine.save.zone_by_id(zone_id)
        assert rec.manifest is not None, "an accepted layout is committed"
        digest = rec.manifest["manifest_digest"]
        assert rec.manifest["joins"], "the route is part of the manifest"

        # 3. PLAY: enter, collect the key, open the lock, claim a Check.
        await engine.handle_enter_zone(zone_id)
        for m in ({"type": "key_collected", "zone_id": zone_id,
                   "key_id": key},
                  {"type": "lock_opened", "zone_id": zone_id,
                   "room_id": room, "socket_id": socket}):
            await engine.handle_progress(_ADAPTER.validate_python(m))
        claimed = sorted(engine.save.zone_by_id(zone_id)
                         .allocated_location_ids)[0]
        import archipepsi_bridge.transactions as TX
        await TX.claim_check(engine, zone_id, claimed)
        await drain()

        outstanding = set(engine.save.zone_by_id(zone_id)
                          .allocated_location_ids)
        assert len(outstanding) > 1, "leave with work still to do"

        # 4. LEAVE through the exit with Checks outstanding.
        await engine.handle_exit_zone(zone_id)
        await drain()
        rec = engine.save.zone_by_id(zone_id)
        assert rec.state == "DORMANT"
        assert set(rec.allocated_location_ids) == outstanding, (
            "a dormant Zone keeps its Check identities; the pool gets "
            "them back only on abandonment")

        # 5. RELOAD FROM DISK, as a new process would. Not a
        # round-tripped model: the bytes the bridge actually wrote.
        reloaded = store.load_save(engine._save_path)
        assert reloaded is not None, "the campaign should be on disk"
        rec = reloaded.zone_by_id(zone_id)
        assert rec.manifest["manifest_digest"] == digest, (
            "the layout is replayed from the manifest, never re-solved")
        assert rec.progress.collected_keys == (key,)
        assert rec.progress.opened_locks == (f"{room}/{socket}",)
        assert set(rec.allocated_location_ids) == outstanding

        # 6. RE-ENTER, and everything is where it was.
        engine.save = reloaded
        sink.messages.clear()
        await engine.handle_enter_zone(zone_id)
        rec = engine.save.zone_by_id(zone_id)
        # THE REPLAY ITSELF, not merely the stored manifest. The record
        # keeping its layout is storage; SENDING it back down is what
        # makes re-entry deterministic (Law 47c, AMALGAM_BRIDGE §5.3),
        # and deleting the emit is invisible to every other assertion
        # here — the save file looks identical either way.
        replayed = [m for m in sink.of_type("zone_ready")
                    if m.zone.zone_id == zone_id]
        assert len(replayed) == 1, (
            "re-entering a laid-out Zone sends the committed layout "
            "back down exactly once")
        assert replayed[0].manifest is not None, (
            "an engine told to enter without a manifest has no choice "
            "but to solve the layout again")
        assert replayed[0].manifest["manifest_digest"] == digest, (
            "the layout replayed is the layout committed")
        assert replayed[0].manifest["joins"] == rec.manifest["joins"]
        assert rec.state == "ACTIVE"
        assert rec.manifest["manifest_digest"] == digest
        assert rec.progress.collected_keys == (key,)
        assert rec.progress.opened_locks == (f"{room}/{socket}",)
        assert set(rec.allocated_location_ids) == outstanding

        # 7. NO REPEATED COMPLETION ACCOUNTING.
        assert engine.save.completed_zone_count == 0
        assert engine.save.zone_history == ()
    run(go())


def test_a_refused_layout_is_never_committed(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zone_id, zone = await _branching_zone(engine)
        bad = _place(zone)
        bad["apertures"].clear()
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zone_id, "layout": bad}))
        assert engine.save.zone_by_id(zone_id).manifest is None, (
            "a refused layout must not reach the save")
    run(go())


def test_a_committed_layout_is_replayed_not_replaced(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zone_id, zone = await _branching_zone(engine)
        good = _place(zone)
        msg = {"type": "layout_result", "zone_id": zone_id,
               "layout": good}
        await engine.handle_layout_result(_ADAPTER.validate_python(msg))
        first = engine.save.zone_by_id(zone_id).manifest["manifest_digest"]
        # The same layout again is the same layout: idempotent.
        await engine.handle_layout_result(_ADAPTER.validate_python(msg))
        assert engine.save.zone_by_id(zone_id).manifest["manifest_digest"] \
            == first
        # A DIFFERENT one is a bug upstream, not an update.
        moved = _place(zone)
        moved["rooms"][zone.chambers[0].id]["yaw"] = 1.5
        with pytest.raises(Exception, match="replayed, never replaced"):
            await engine.handle_layout_result(_ADAPTER.validate_python(
                {"type": "layout_result", "zone_id": zone_id,
                 "layout": moved}))
    run(go())


def test_a_refused_layout_stops_the_zone_and_keeps_its_checks(tmp_path):
    """A refusal must change what the player can do, and cost nothing.

    The first version logged, notified, and left the Zone ACTIVE — so the
    client went on playing geometry the validator had just rejected and
    went on claiming Checks against it. The control is the same path with
    a sound layout, because "the Zone stopped being active" means nothing
    unless an accepted one stays active.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zone_id, zone = await _branching_zone(engine)
        held = set(engine.save.zone_by_id(zone_id).allocated_location_ids)
        assert held, "the Zone should hold locations before any of this"

        # THE CONTROL: a sound layout leaves the Zone in play.
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zone_id,
             "layout": _place(zone)}))
        rec = engine.save.zone_by_id(zone_id)
        assert rec.layout_state == "ACCEPTED", rec.layout_state
        assert engine.save.active_zone_id == zone_id, (
            "an accepted layout must leave the Zone active")
        assert rec.manifest is not None

        # THE REFUSAL, on a fresh campaign so the accepted one is not in
        # the way: the same handler, a layout with no aperture evidence.
        engine2, _ = await connected_engine(tmp_path / "b",
                                            config=C.DEFAULT_CONFIG)
        zid2, zone2 = await _branching_zone(engine2)
        before = set(engine2.save.zone_by_id(zid2).allocated_location_ids)
        bad = _place(zone2)
        bad["apertures"].clear()
        await engine2.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zid2, "layout": bad}))
        after = engine2.save.zone_by_id(zid2)
        assert after.layout_state == "REFUSED", after.layout_state
        assert after.manifest is None, "a refused layout must not commit"
        assert after.state != "ACTIVE", (
            "a refused Zone must not stay ACTIVE; the client would keep "
            f"playing it (state {after.state})")
        # THE CHECKS ARE STILL ITS OWN. Giving them back is abandon's job.
        assert set(after.allocated_location_ids) == before, (
            "a refused layout released the Zone's locations")
        assert after.holds_locations, (
            "a refused Zone stopped reserving its Checks, so the seed "
            "would re-allocate them elsewhere")
        # AND IT CANNOT CLAIM ONE, through the path that claims them.
        #
        # The first version of this called `engine.handle_claim_check`,
        # which does not exist -- so `pytest.raises(Exception)` caught an
        # AttributeError and the assertion was about a typo rather than
        # about the Zone. `transactions.claim_check` is the real one.
        import archipepsi_bridge.transactions as TX
        from archipepsi_bridge.campaign import IntentError
        with pytest.raises((ValueError, IntentError)) as refused:
            await TX.claim_check(engine2, zid2, next(iter(before)))
        assert "not ACTIVE" in str(refused.value), str(refused.value)
    run(go())


def test_a_zone_that_keeps_failing_stops_being_recomposed(tmp_path):
    """Regeneration is a recovery, not a loop.

    A refusal composes the Zone again against the ids it already holds —
    the same recovery a crash mid-generation gets. A client that refuses
    every layout would otherwise ask forever, so it stops and the record
    waits for a human instead of spinning.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zone_id, _ = await _branching_zone(engine)
        held = set(engine.save.zone_by_id(zone_id).allocated_location_ids)
        for _ in range(T.MAX_LAYOUT_REFUSALS + 2):
            engine._apply(T.refuse_layout(engine.save, zone_id))
        rec = engine.save.zone_by_id(zone_id)
        assert rec.layout_refusals >= T.MAX_LAYOUT_REFUSALS
        assert rec.state == "DORMANT", (
            f"after {rec.layout_refusals} refusals the Zone is "
            f"{rec.state}; it should have stopped being recomposed")
        assert set(rec.allocated_location_ids) == held, (
            "giving up on a layout released the Zone's locations")
def test_a_committed_zone_survives_a_refused_replay(tmp_path):
    """A refused REPLAY must not replace the Zone it replayed.

    Regeneration recovery composes the Zone again against the ids it
    already holds — right for a FRESH proposal, and wrong for one that
    has already been solved. Law 47c: the layout is solved once and
    committed, and every later load replays it. `commit_layout` already
    refuses to replace a committed manifest; this is the other door into
    the same room, and it used to be open: the refusal cleared `zone`
    and `manifest`, so a replay the validator rejected sent a DIFFERENT
    Zone back under the same id, holding the same Checks, with the
    player's keys and opened locks recorded against rooms that no longer
    existed.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zone_id, _ = await _branching_zone(engine)
        await enter_zone(engine, zone_id)
        rec = engine.save.zone_by_id(zone_id)
        assert rec.layout_state == "ACCEPTED" and rec.manifest, (
            "this test needs a committed layout to refuse a replay of")
        digest = rec.manifest.get("manifest_digest")
        rooms = tuple(c.id for c in rec.zone.chambers)
        key = rec.zone.chambers[0].keys[0].key_id \
            if rec.zone.chambers[0].keys else None
        if key is not None:
            engine._apply(T.record_key(engine.save, zone_id, key))
        held = set(rec.allocated_location_ids)

        engine._apply(T.refuse_layout(engine.save, zone_id))

        after = engine.save.zone_by_id(zone_id)
        assert after.manifest is not None, (
            "a refused replay threw away the committed manifest")
        assert after.manifest.get("manifest_digest") == digest, (
            "the committed layout changed under a refusal: "
            f"{digest} became {after.manifest.get('manifest_digest')}")
        assert after.zone is not None \
            and tuple(c.id for c in after.zone.chambers) == rooms, (
                "the Zone was recomposed, so the progress below is "
                "recorded against rooms that no longer exist")
        if key is not None:
            assert key in after.progress.collected_keys, (
                "a refused replay lost the player's progress")
        assert set(after.allocated_location_ids) == held, (
            "a refused replay released the Zone's Checks")
        assert after.state == "DORMANT", (
            f"a Zone whose replay was refused is {after.state}; it must "
            "not be left playable and must not be recomposed")
        assert after.layout_state == "REFUSED"
        assert after.layout_refusals == 1

        # AND IT IS STILL ONLY ONE REFUSAL AWAY FROM ITSELF. A second
        # refusal changes nothing else: there is no recomposition to
        # count down to, because there is nothing to recompose.
        engine._apply(T.refuse_layout(engine.save, zone_id))
        again = engine.save.zone_by_id(zone_id)
        assert again.manifest is not None \
            and again.manifest.get("manifest_digest") == digest
        assert again.layout_refusals == 2
    run(go())


# --- the way back in ------------------------------------------------------
#
# The lifecycle existed and the player could not reach it. `rest_zone`
# clears `active_zone_id` — nobody is in the Zone — so the Hub's
# `active_zone()` came back empty, the mode fell through to
# ZONE_AVAILABLE, and the portal offered to design a new Zone. Pressing
# it got "Zone 'zone_001' still holds locations; finish or abandon it
# first". Walk out of a Zone, restart, and the only way forward was to
# abandon it and lose its Checks and its progress.
#
# These tests enter using ONLY what the snapshot exposes. Reaching into
# `save.zones` for the id would prove the transition works and nothing
# about whether the portal can find it, which is the half that was
# broken.

def _portal_target(engine):
    """What `hub.gd` will have: a mode, and the Zone id to send."""
    hub = engine.snapshot().hub
    if hub.mode not in P.ZONE_ENTER_MODES:
        return None
    return hub.resume_zone_id


def test_the_portal_can_find_the_zone_you_walked_out_of(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zone_id, zone = await _branching_zone(engine)
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zone_id,
             "layout": _place(zone)}))
        digest = engine.save.zone_by_id(zone_id).manifest["manifest_digest"]
        await engine.handle_enter_zone(zone_id)
        key = next(k.key_id for c in zone.chambers for k in c.keys)
        await engine.handle_progress(_ADAPTER.validate_python(
            {"type": "key_collected", "zone_id": zone_id, "key_id": key}))
        outstanding = set(engine.save.zone_by_id(zone_id)
                          .allocated_location_ids)
        assert outstanding, "leave with work still to do"

        await engine.handle_exit_zone(zone_id)
        await drain()

        # RESTART. A new process, reading the bytes off disk.
        engine.save = store.load_save(engine._save_path)
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_DORMANT", (
            f"the Hub says {hub.mode} over a Zone holding "
            f"{len(outstanding)} Checks")
        assert not hub.accepts_zone_request, (
            "offering to design a new Zone here is the call the bridge "
            "refuses; the portal must not light up for it")
        target = _portal_target(engine)
        assert target == zone_id, "the portal has no way to name the Zone"
        assert hub.resume_zone_name, "and nothing to put on the sign"

        # ENTER THE WAY THE PORTAL WILL, by the id the Hub handed over.
        await engine.handle_enter_zone(target)
        rec = engine.save.zone_by_id(target)
        assert rec.state == "ACTIVE"
        assert rec.manifest["manifest_digest"] == digest, "manifest kept"
        assert rec.progress.collected_keys == (key,), "progress kept"
        assert set(rec.allocated_location_ids) == outstanding, "Checks kept"
    run(go())


def test_a_finished_zone_is_offered_back_and_counts_nothing_twice(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zone_id, zone = await _branching_zone(engine)
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zone_id,
             "layout": _place(zone)}))
        await engine.handle_enter_zone(zone_id)
        import archipepsi_bridge.schemas.transitions as T
        rec = engine.save.zone_by_id(zone_id)
        for i, loc in enumerate(rec.allocated_location_ids):
            engine._apply(T.claim_zone_check(
                engine.save, zone_id=zone_id, location_id=loc,
                transaction_id=f"t{i}"))
            engine._apply(T.confirm_check(engine.save, loc))
        # `_apply` rather than a bare assignment: it writes the save, so
        # the reload below reads a finished campaign rather than the one
        # from before the last three transitions.
        engine._apply(T.complete_zone(engine.save, zone_id))
        counted = engine.save.completed_zone_count
        history = engine.save.zone_history
        assert counted == 1

        # RESTART, so this is the Hub a returning player actually sees.
        engine.save = store.load_save(engine._save_path)
        offered = {h.zone_id for h in engine.snapshot().hub.revisitable}
        assert zone_id in offered, (
            "a finished Zone stays open; the Hub has to be able to say so")

        await engine.handle_enter_zone(zone_id)
        assert engine.save.zone_by_id(zone_id).state == "VISITING"
        assert engine.snapshot().hub.mode == "ZONE_ACTIVE", (
            "a revisit is the same experience as a first visit")
        # RESERVES nothing — the record keeps the Check identities it
        # held, which is history; what matters is that none of them is
        # still held against the pool, so a revisit cannot block the
        # next Zone the way a dormant one does.
        assert not engine.save.zone_by_id(zone_id).holds_locations, \
            "a revisit reserves nothing"
        assert not (set(engine.save.zone_by_id(zone_id)
                        .allocated_location_ids)
                    & engine._held_location_ids())

        await engine.handle_exit_zone(zone_id)
        await drain()
        assert engine.save.zone_by_id(zone_id).state == "COMPLETE"
        assert engine.save.completed_zone_count == counted, (
            "walking back through a finished Zone completed it again")
        assert engine.save.zone_history == history
    run(go())


def test_a_graph_zone_claims_nothing_while_its_verdict_is_pending(tmp_path):
    """The WAITING PERIOD, which the refusal test does not cover.

    `claim_zone_check` required `state == ACTIVE` and said nothing about
    the layout. A graph Zone is ACTIVE from the moment the player walks
    in and UNCERTIFIED until its layout comes back — so between those two
    moments a reward that fires on its own (a timer, a kill, an activity
    completing) claimed against geometry nobody had checked, sent it to
    Archipelago, and could not take it back when `refuse_layout` sent the
    Zone away to be composed again.

    All three states, through `transactions.claim_check` — the real path
    the `claim_check` intent takes — because a rule proved only on the
    pure transition is a rule nothing calls.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zone_id, zone = await _branching_zone(engine)
        held = list(engine.save.zone_by_id(zone_id).allocated_location_ids)
        loc = held[0]

        # 1. PENDING. Entered, ACTIVE, no layout sent yet.
        await engine.handle_enter_zone(zone_id)
        rec = engine.save.zone_by_id(zone_id)
        assert rec.state == "ACTIVE" and rec.layout_state == "UNCERTIFIED"
        with pytest.raises(IntentError) as caught:
            await TX.claim_check(engine, zone_id, loc)
        assert "has not had its layout accepted" in str(caught.value)
        # AND NOTHING LEAKED: no pending record, nothing sent to AP.
        assert not engine.save.pending_checks, (
            "a claim refused for a pending verdict still entered the ledger")
        assert loc not in engine.ap.checked
        assert set(engine.save.zone_by_id(zone_id).allocated_location_ids) \
            == set(held), "the allocation must survive the refusal"

        # 2. ACCEPTED — the control. The same call, after the same layout
        #    the client sends, succeeds.
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zone_id,
             "layout": _place(zone)}))
        assert engine.save.zone_by_id(zone_id).layout_state == "ACCEPTED"
        await TX.claim_check(engine, zone_id, loc)
        assert loc in engine.ap.checked or engine.save.pending_checks, (
            "an accepted Zone's claim went nowhere")

        # 3. REFUSED, on a second campaign so the accepted one is not in
        #    the way: the allocation is preserved and the claim is still
        #    refused afterwards.
        engine2, _ = await connected_engine(tmp_path / "refused",
                                            config=C.DEFAULT_CONFIG)
        zid2, zone2 = await _branching_zone(engine2)
        before = set(engine2.save.zone_by_id(zid2).allocated_location_ids)
        await engine2.handle_enter_zone(zid2)
        bad = _place(zone2)
        bad["apertures"] = {}
        await engine2.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zid2, "layout": bad}))
        rec2 = engine2.save.zone_by_id(zid2)
        assert rec2.layout_state == "REFUSED" or rec2.state != "ACTIVE"
        assert set(rec2.allocated_location_ids) == before, (
            "a refused layout spent the Zone's Checks")
        with pytest.raises(IntentError):
            await TX.claim_check(engine2, zid2, sorted(before)[0])
        assert not engine2.save.pending_checks

    run(go())


def test_a_legacy_zone_with_no_edges_still_claims(tmp_path):
    """The exemption, stated rather than left to chance.

    A Zone with no `edges` is the pre-graph shape: it sends no
    `layout_result`, so its `layout_state` is UNCERTIFIED forever.
    Requiring acceptance of it would make every such Zone unplayable, and
    a rule with an exemption nothing exercises is a rule that will lose
    the exemption the next time somebody tidies it.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path)
        await engine.handle_request_next_zone(False)
        await drain()
        zone_id = engine.save.active_zone_id
        # Strip the graph, the way a pre-graph provider would have sent it.
        rec = engine.save.zone_by_id(zone_id)
        # The doors go with the graph: an assignment naming an edge that
        # does not exist is refused by `validate_zone`, and rightly.
        legacy = rec.zone.model_copy(update={
            "edges": (), "plugs": (),
            "chambers": tuple(c.model_copy(update={"doors": (), "keys": ()})
                              for c in rec.zone.chambers)})
        engine.save = engine.save.model_copy(update={"zones": tuple(
            r.model_copy(update={"zone": legacy}) if r.zone_id == zone_id
            else r for r in engine.save.zones)})
        await engine.handle_enter_zone(zone_id)
        rec = engine.save.zone_by_id(zone_id)
        assert not rec.zone.edges and rec.layout_state == "UNCERTIFIED"
        loc = sorted(rec.allocated_location_ids)[0]
        await TX.claim_check(engine, zone_id, loc)
        assert loc in engine.ap.checked or engine.save.pending_checks, (
            "a legacy Zone with no graph could not claim its own Check")

    run(go())
