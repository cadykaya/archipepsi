"""One ordinary generated Zone, all the way through.

generation -> graph -> physical layout -> returned evidence ->
validation -> persisted manifest -> play -> leave -> reload -> re-enter.

**Every step goes through a real handler.** Earlier progress tests
assigned transition results straight onto `engine.save`, which proves a
function works and says nothing about whether anything calls it. Nothing
here touches `engine.save` except to read it.
"""

from __future__ import annotations

import json

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
    if hub.mode not in P.ZONE_ENTERABLE_MODES:
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

        # THE WHOLE OFFER, AS THE GAME RECEIVES IT. `hub.gd` reads
        # `portal_enabled` off the serialized snapshot — naming the Zone
        # and lighting the button were one question under two names, and
        # only one of them learned about ZONE_DORMANT, so the Hub said
        # "your Zone is waiting" over a portal that was greyed out. A
        # mode branch in the consumer would not have fixed that.
        wire = json.loads(engine.snapshot().model_dump_json())["hub"]
        assert wire["mode"] == "ZONE_DORMANT"
        assert wire["resume_zone_id"] == zone_id
        assert wire["portal_enabled"] is True, "the button is dark"
        assert wire["accepts_zone_request"] is False, (
            "offering to generate here is the call the bridge refuses")

        # AND WITH ARCHIPELAGO DOWN. The Zone is already on disk;
        # entering it needs no round-trip, and a returning player during
        # an outage is exactly who this is for.
        engine.ap.connected = False
        offline = json.loads(engine.snapshot().model_dump_json())["hub"]
        assert offline["mode"] == "ZONE_DORMANT", "an outage moves no mode"
        assert offline["ap_online"] is False
        assert offline["portal_enabled"] is True, (
            "an outage must not shut the door on a local Zone")
        assert offline["resume_zone_id"] == zone_id
        engine.ap.connected = True

        # ENTER THE WAY THE PORTAL WILL, by the id the Hub handed over.
        await engine.handle_enter_zone(target)
        rec = engine.save.zone_by_id(target)
        assert rec.state == "ACTIVE"
        assert rec.manifest["manifest_digest"] == digest, "manifest kept"
        assert rec.progress.collected_keys == (key,), "progress kept"
        assert set(rec.allocated_location_ids) == outstanding, "Checks kept"

        # ON THE CARRIER THE GAME READS. `main.gd::_to_zone` is driven by
        # `_on_snapshot` and takes both the layout and the progress from
        # `BridgeClient.active_zone()`, so that is where they have to be.
        snap = json.loads(engine.snapshot().model_dump_json())
        assert snap["active_zone"]["progress"]["collected_keys"] == [key]
        assert snap["active_zone"]["manifest"]["manifest_digest"] == digest
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


# --- when no layout is ever accepted --------------------------------------
#
# Every existing test of this path calls `T.refuse_layout` on the save
# directly, which is the thing this file's own docstring warns about: it
# proves the transition works and says nothing about what a player
# reaches. These go through `handle_layout_result` and read the Hub the
# way `hub.gd` reads it.

_UNPLACEABLE = {"status": "LAYOUT_OK"}     # OK, and not one room placed


async def _exhausted(tmp_path):
    """A Zone that never lays out, refused until the bridge stops trying."""
    engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
    await engine.handle_request_next_zone(False)
    await drain()
    zid = engine.save.active_zone_id
    held = set(engine.save.zone_by_id(zid).allocated_location_ids)
    assert held, "a Zone holding nothing proves nothing about recovery"
    for _ in range(T.MAX_LAYOUT_REFUSALS):
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zid,
             "layout": dict(_UNPLACEABLE)}))
        await drain()
    return engine, zid, held


def test_a_zone_that_never_lays_out_keeps_its_checks_and_stops_composing(
        tmp_path):
    """DORMANT, holding everything it was allocated.

    The locations are NOT returned here: giving them back is
    `abandon_zone`'s behaviour and only its, because it is a decision
    with a cost and a refused layout is not the player's doing.
    """
    async def go():
        engine, zid, held = await _exhausted(tmp_path)
        rec = engine.save.zone_by_id(zid)
        assert rec.state == "DORMANT"
        assert rec.layout_state == "REFUSED"
        assert rec.layout_refusals == T.MAX_LAYOUT_REFUSALS
        assert set(rec.allocated_location_ids) == held
        assert rec.manifest is None, "nothing was ever committed"
        # AND IT STOPS COMPOSING. A fourth attempt would otherwise run
        # the provider again on a Zone that has already failed three.
        assert rec.state != "PENDING_GENERATION"
    run(go())


def test_the_hub_will_not_start_a_new_zone_over_an_exhausted_one(tmp_path):
    """The one-Zone rule holds through the failure path too: the Checks
    are still reserved, so a new Zone would collide with them."""
    async def go():
        engine, zid, _held = await _exhausted(tmp_path)
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_FAILED"
        assert not hub.accepts_zone_request
        with pytest.raises(IntentError):
            await engine.handle_request_next_zone(False)
    run(go())


def test_abandoning_an_exhausted_zone_recovers_its_locations(tmp_path):
    """**The campaign is never permanently stuck.** Confirmed through
    the handlers rather than inferred from the transition: abandon the
    Zone and the next one generates."""
    async def go():
        engine, zid, held = await _exhausted(tmp_path)
        await engine.handle_abandon_zone(zid)
        await drain()
        assert engine.save.zone_by_id(zid).state == "ABANDONED"
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_AVAILABLE" and hub.accepts_zone_request

        await engine.handle_request_next_zone(False)
        await drain()
        fresh = engine.save.active_zone_id
        assert fresh and fresh != zid
        # The reserved ids came back to the pool rather than being lost
        # with the Zone that could not be built.
        assert set(engine.save.zone_by_id(fresh).allocated_location_ids) & held
    run(go())


def test_a_refused_replay_never_costs_a_committed_zone_its_manifest(tmp_path):
    """The distinction that must not blur.

    A Zone that has NEVER been accepted is recomposed — a fresh
    proposal, and nothing is lost. A Zone that HAS committed a manifest
    is a different thing entirely: it was solved once, Law 47c says
    every later load replays it, and the player's keys and locks are
    recorded against its rooms. Refusing its replay must not send it
    back to be composed again as a different Zone under the same id.
    """
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

        # Now refuse a replay of the layout that was already committed.
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zone_id,
             "layout": dict(_UNPLACEABLE)}))
        await drain()

        rec = engine.save.zone_by_id(zone_id)
        assert rec.state == "DORMANT", "it is out of the player's hands"
        assert rec.layout_state == "REFUSED"
        assert rec.manifest is not None, "the committed layout was thrown away"
        assert rec.manifest["manifest_digest"] == digest
        assert rec.zone is not None, "its content was thrown away"
        assert rec.zone.zone_id == zone_id
        assert rec.progress.collected_keys == (key,), "progress was lost"
        assert rec.state != "PENDING_GENERATION", (
            "a committed Zone was sent back to be composed again")
    run(go())


# --- the budget is spent exactly once -------------------------------------
#
# `layout_refusals` is persisted and bounded at 99, and `refuse_layout`
# incremented it on every refusal without limit — so a client that kept
# sending `layout_result` reached the hundredth and got a pydantic
# `ValidationError` out of a transition, which is a schema exception
# where a domain refusal belongs. It was reachable because the Hub then
# offered the failed Zone as a way back in, so the loop had somewhere to
# come from.

def test_the_final_allowed_refusal_lands_exactly_on_the_budget(tmp_path):
    async def go():
        engine, zid, _ = await _exhausted(tmp_path)
        rec = engine.save.zone_by_id(zid)
        assert rec.layout_refusals == T.MAX_LAYOUT_REFUSALS
        assert rec.layout_exhausted
        assert engine.snapshot().hub.mode == "ZONE_FAILED"
    run(go())


def test_one_refusal_beyond_the_budget_changes_nothing(tmp_path):
    async def go():
        engine, zid, _ = await _exhausted(tmp_path)
        before = engine.save
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zid,
             "layout": dict(_UNPLACEABLE)}))
        await drain()
        assert engine.save is before, "a stale result moved the save"
        assert engine.save.zone_by_id(zid).layout_refusals == \
            T.MAX_LAYOUT_REFUSALS
    run(go())


def test_a_client_that_never_stops_retrying_never_leaves_the_bound(tmp_path):
    """The defect, at the scale that produced it. The hundredth refusal
    used to raise; none of these may."""
    async def go():
        engine, zid, _ = await _exhausted(tmp_path)
        for _ in range(120):
            await engine.handle_layout_result(_ADAPTER.validate_python(
                {"type": "layout_result", "zone_id": zid,
                 "layout": dict(_UNPLACEABLE)}))
        await drain()
        rec = engine.save.zone_by_id(zid)
        assert rec.layout_refusals == T.MAX_LAYOUT_REFUSALS
        # And the save still round-trips, which is what the bound is for.
        assert store.load_save(engine._save_path).zone_by_id(zid) \
            .layout_refusals == T.MAX_LAYOUT_REFUSALS
    run(go())


def test_the_transition_itself_saturates(tmp_path):
    """Asserted at the transition as well as through the handler: the
    handler's stale-result guard and the transition's are two answers to
    one question and both have to be right."""
    async def go():
        engine, zid, _ = await _exhausted(tmp_path)
        save = engine.save
        for _ in range(200):
            save = T.refuse_layout(save, zid)
        assert save.zone_by_id(zid).layout_refusals == T.MAX_LAYOUT_REFUSALS
        assert save is engine.save, "an exhausted Zone was rebuilt anyway"
    run(go())


def test_an_exhausted_zone_cannot_be_entered(tmp_path):
    """Owner decision, 2026-09-12. Refused at the transition too, so a
    replayed intent or a debug command cannot route around the Hub."""
    async def go():
        engine, zid, _ = await _exhausted(tmp_path)
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_FAILED"
        assert not hub.portal_enabled, "the portal offered a way in"
        assert hub.resume_zone_id == "", "it named a Zone it cannot enter"
        assert hub.discard_zone_id == zid
        assert hub.discard_zone_name

        with pytest.raises(IntentError, match="cannot be entered"):
            await engine.handle_enter_zone(zid)
        assert engine.save.zone_by_id(zid).state == "DORMANT"
    run(go())


def test_an_exhausted_zone_survives_a_reload_still_failed(tmp_path):
    async def go():
        engine, zid, held = await _exhausted(tmp_path)
        await drain()
        engine.save = store.load_save(engine._save_path)
        rec = engine.save.zone_by_id(zid)
        assert rec.layout_exhausted
        assert rec.layout_refusals == T.MAX_LAYOUT_REFUSALS
        assert set(rec.allocated_location_ids) == held
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_FAILED" and hub.discard_zone_id == zid
        with pytest.raises(IntentError):
            await engine.handle_enter_zone(zid)
    run(go())


def test_discarding_an_exhausted_zone_is_the_offer_and_it_works(tmp_path):
    """The affordance the Hub now advertises, exercised end to end.

    Nothing abandons it automatically: releasing the locations is a
    decision with a cost and the player makes it.
    """
    async def go():
        engine, zid, held = await _exhausted(tmp_path)
        target = engine.snapshot().hub.discard_zone_id
        assert target == zid

        await engine.handle_abandon_zone(target)
        await drain()
        assert engine.save.zone_by_id(zid).state == "ABANDONED"
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_AVAILABLE" and hub.accepts_zone_request
        assert hub.discard_zone_id == ""

        await engine.handle_request_next_zone(False)
        await drain()
        fresh = engine.save.active_zone_id
        assert fresh and fresh != zid
        assert set(engine.save.zone_by_id(fresh).allocated_location_ids) & held
        # The discarded Zone stays discarded.
        assert engine.save.zone_by_id(zid).state == "ABANDONED"
    run(go())


def test_a_committed_zone_is_never_swept_into_this(tmp_path):
    """The distinction, asserted against the same machinery.

    A committed Zone whose replay is refused keeps its manifest, stays
    re-enterable, and never becomes `ZONE_FAILED` however many times its
    replay is rejected.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zone_id, zone = await _branching_zone(engine)
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zone_id,
             "layout": _place(zone)}))
        digest = engine.save.zone_by_id(zone_id).manifest["manifest_digest"]

        for _ in range(T.MAX_LAYOUT_REFUSALS + 5):
            await engine.handle_layout_result(_ADAPTER.validate_python(
                {"type": "layout_result", "zone_id": zone_id,
                 "layout": dict(_UNPLACEABLE)}))
            await drain()

        rec = engine.save.zone_by_id(zone_id)
        assert not rec.layout_exhausted, "a committed Zone was swept in"
        assert rec.manifest["manifest_digest"] == digest
        assert rec.layout_refusals <= T.MAX_LAYOUT_REFUSALS, "the bound"
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_DORMANT", hub.mode
        assert hub.resume_zone_id == zone_id and hub.discard_zone_id == ""
        # And it is still a way back in, which is the point.
        await engine.handle_enter_zone(zone_id)
        assert engine.save.zone_by_id(zone_id).state == "ACTIVE"
    run(go())


# --- a composition that did not happen -------------------------------------
#
# The composer's refusal paths returned an edge-less `GraphProduct` with
# sealed doors and a note. Nothing read it: `apply` drops notes,
# `reachability` cannot tell an edge-less refusal from the legacy chain
# it MUST keep accepting, and `_with_graph` handed the result back as a
# good Zone. The only thing that noticed was the `Zone` schema refusing
# doors-without-edges when `accept_zone` rebuilt the record — which
# protects the save and is a pydantic exception out of a background
# task, not a handled refusal.
#
# These drive the real generation handler. A test that asserted "no
# edges and a note" proved the composer had an opinion, not that
# anything acted on it.

from archipepsi_bridge import topology as TOPO


TERMINUS = ("entry", "branch_east", "branch_west")


def _caps_with(shell_id: str, sockets):
    """The real socket map plus one shell of a chosen capacity."""
    caps = dict(TOPO._shell_sockets())
    caps[shell_id] = sockets
    return caps


def _zone_with_leaf(index: int, shell_id="shell_bay_terminus",
                    sockets=TERMINUS, rooms=8):
    from .test_topology import _chain_zone
    z = _chain_zone(rooms)
    chambers = list(z.chambers)
    i = index if index >= 0 else len(chambers) + index
    chambers[i] = chambers[i].model_copy(update={"shell_id": shell_id})
    return z.model_copy(update={"chambers": tuple(chambers)})


@pytest.mark.parametrize("index,shell,sockets,code", [
    # No eligible host: a destination in the second room, where the only
    # earlier room is the one the player arrives in.
    (1, "shell_bay_terminus", TERMINUS, "destination_unreachable"),
    # An invalid first/last assignment: it would have to carry the chain.
    (0, "shell_bay_terminus", TERMINUS, "destination_is_an_end"),
    (-1, "shell_bay_terminus", TERMINUS, "destination_is_an_end"),
    # Unsupported by the arrival contract: nothing can reach it.
    (3, "shell_no_way_in", ("branch_east",), "no_arrival"),
])
def test_the_campaign_wrapper_refuses_rather_than_returning_a_zone(
        index, shell, sockets, code):
    """`campaign._with_graph` is the wrapper, and this is what it does now.

    It used to hand the refusal back as a good Zone: `apply` drops
    `notes`, `reachability` cannot tell an edge-less refusal from the
    legacy chain it must keep accepting, and the only thing that noticed
    was the `Zone` schema refusing doors-without-edges when
    `accept_zone` rebuilt the record.
    """
    from archipepsi_bridge import campaign as CAMP
    zone = _zone_with_leaf(index, shell, sockets)
    caps = _caps_with(shell, sockets)
    real = TOPO._shell_sockets
    TOPO._shell_sockets = lambda: caps
    try:
        with pytest.raises(TOPO.GraphRefused) as caught:
            CAMP._with_graph(zone)
    finally:
        TOPO._shell_sockets = real
    # THE CODE, not the sentence.
    assert caught.value.refusal.code == code
    assert caught.value.refusal.rooms


def test_the_generation_handler_recovers_from_a_refusal(tmp_path):
    """End to end through `handle_request_next_zone`, with the REAL
    provider and no stand-in anywhere on the path.

    Every authored shell is declared unreachable for the length of the
    run — a capacity a registered shell could genuinely declare, and one
    the composer must refuse wherever the room lands. What is asserted
    is the recovery: nothing accepted, nothing published, no uncaught
    exception, and the Checks back in the pool.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        sink = Collector(engine)
        real = TOPO._shell_sockets
        # A registered shell that declares no `entry`: nothing can reach
        # it, whichever room adopts it.
        TOPO._shell_sockets = lambda: {
            sid: ("branch_east",) for sid in real()}
        try:
            await engine.handle_request_next_zone(False)
            await drain()
        finally:
            TOPO._shell_sockets = real

        assert engine.save.zones, "a Zone was reserved and then refused"
        # NOTHING ACCEPTED and NOTHING PUBLISHED.
        assert all(r.state == "ABANDONED" for r in engine.save.zones), [
            r.state for r in engine.save.zones]
        assert not sink.of_type("zone_ready")
        # Reported as a refusal, not swallowed, and not a schema
        # exception out of a background task.
        assert engine.last_generation_error.startswith(
            "composition refused"), engine.last_generation_error
        assert "no_arrival" in engine.last_generation_error
        assert any(n.kind == "zone_abandoned"
                   for n in sink.of_type("notification"))

        # LOCATION ACCOUNTING SURVIVES, through `abandon_zone` and no
        # other path, and the save still loads.
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_AVAILABLE" and hub.accepts_zone_request
        assert store.load_save(engine._save_path) is not None

        # THE BOUNDED RECOVERY ACTUALLY RECOVERS: ask again, unpatched,
        # and the next Zone composes a real graph on released ids.
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        assert zid is not None
        rec = engine.save.zone_by_id(zid)
        assert rec.zone is not None and rec.zone.edges
        assert rec.allocated_location_ids
    run(go())


def test_a_genuine_legacy_zone_with_no_graph_still_loads(tmp_path):
    """The shape the refusal must NOT be confused with.

    A Zone carrying no edges, no doors and no plugs is the chain its
    list order describes — every save written before graphs existed.
    `reachability` accepts it, and that is why the refusal had to become
    an explicit code rather than "there are no edges".
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        zone = engine.save.zone_by_id(zid).zone

        legacy = zone.model_copy(update={
            "edges": (), "plugs": (),
            "chambers": tuple(c.model_copy(update={
                "doors": (), "arrive_edge": None, "depart_edge": None})
                for c in zone.chambers)})
        assert TOPO.reachability(legacy).ok, "a legacy Zone must load"
        # And a refusal is NOT that: it says so in a field, which is why
        # "there are no edges" could never have been the test.
        again = TOPO.compose_with_branch(list(legacy.chambers))
        assert not again.refused, "an ordinary Zone refuses nothing"
        assert again.edges, "and it composes a graph"
    run(go())
