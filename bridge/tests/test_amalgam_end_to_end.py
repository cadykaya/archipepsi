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

from archipepsi_bridge.schemas import transitions as T

from .conftest import Collector, connected_engine, drain, run

_ADAPTER = TypeAdapter(ClientMessage)

SPACING = 50.0
HALF_W = 9.0
DEPTH = 16.0
BRANCH_X = 90.0


def _corridor(a, b) -> dict:
    """One chain piece in the shape `zone_builder` emits one.

    Pose and kind as well as endpoints: the engine refuses to replay a
    committed chain whose pieces carry no `position`/`yaw` or an unknown
    `kind` (`malformed_pieces`), so a fixture without them stands in for
    a payload the engine could not rebuild.
    """
    return {"kind": "CONNECTOR", "position": list(a), "yaw": 0.0,
            "entry": list(a), "exit": list(b),
            "bounds": {"position": [min(a[0], b[0]) - 1.5, 0.0,
                                    min(a[2], b[2])],
                       "size": [3.0, 4.0, max(abs(b[2] - a[2]), 0.1)]}}


def _place(zone) -> dict:
    """A physically sound layout for this Zone, in the engine's shape.

    Stands in for `zone_builder.build()` until the engine serializes its
    result. The geometry is deliberately spread out — rooms 50 m apart
    with real connector chains between them — so that no join passes by
    happening to touch.
    """
    order = [c.id for c in zone.chambers]
    joined = [e for e in zone.edges if e.realization == "JOINED"]
    # A room reached only by the vault edge is the branch; it goes to one
    # side so it cannot overlap the spine.
    spine = [r for r in order]
    off_spine = {e.room_b for e in joined
                 if sum(1 for x in joined if e.room_b in x.rooms) == 1
                 and order.index(e.room_b) < order.index(e.room_a)}

    centre: dict[str, tuple[float, float]] = {}
    slot = 0
    for rid in spine:
        if rid in off_spine:
            continue
        centre[rid] = (0.0, slot * SPACING)
        slot += 1
    for rid in off_spine:
        centre[rid] = (BRANCH_X, order.index(rid) * SPACING)

    rooms, apertures, anchors, arrival_ok = {}, {}, {}, {}
    for ch in zone.chambers:
        x, z = centre[ch.id]
        rooms[ch.id] = {
            "position": [x, 0.0, z], "yaw": 0.0,
            "bounds": {"position": [x - HALF_W, 0.0, z - DEPTH / 2],
                       "size": [HALF_W * 2, 5.0, DEPTH]},
        }
        for d in ch.doors:
            # Every door reports exactly what its assignment declares,
            # the head's `entry` included: the player arrives 1.2 m
            # inside the first room, so its front wall is a wall.
            apertures[f"{ch.id}/{d.socket_id}"] = d.passable_geometry
        if any(d.usage != "SEALED" for d in ch.doors):
            a = f"room:{ch.id}:arrival"
            anchors[a] = [x, 0.0, z]
            arrival_ok[a] = True

    joins = {}
    for e in joined:
        ax, az = centre[e.room_a]
        bx, bz = centre[e.room_b]
        # Each socket sits on its own room's boundary, facing the other.
        sa = [ax, 0.0, az + (DEPTH / 2 if bz >= az else -DEPTH / 2)] \
            if abs(bx - ax) < 1e-6 else \
            [ax + (HALF_W if bx > ax else -HALF_W), 0.0, az]
        sb = [bx, 0.0, bz + (-DEPTH / 2 if bz >= az else DEPTH / 2)] \
            if abs(bx - ax) < 1e-6 else \
            [bx + (-HALF_W if bx > ax else HALF_W), 0.0, bz]
        joins[e.edge_id] = {
            "socket_a": sa, "socket_b": sb, "chain": [_corridor(sa, sb)]}

    stations = []
    for p in zone.plugs:
        anchors.setdefault(p.source_anchor, [0.0, 0.0, 1.0])
        anchors.setdefault(p.destination, [0.0, 0.0, 0.0])
        arrival_ok.setdefault(p.source_anchor, True)
        arrival_ok.setdefault(p.destination, True)

    # THE ENGINE'S OWN GEOMETRY, which every finished build appends: an
    # exit room with the portal in it, and the approach to it filed
    # under the reserved edge id. A payload without them is not one
    # `zone_builder` could have produced.
    far = max(z for _, z in centre.values()) + SPACING
    rooms["exit"] = {
        "position": [0.0, 0.0, far], "yaw": 0.0,
        "bounds": {"position": [-HALF_W, 0.0, far - DEPTH / 2],
                   "size": [HALF_W * 2, 5.0, DEPTH]}}
    tail = max((c.id for c in zone.chambers),
               key=lambda rid: centre[rid][1])
    tz = centre[tail][1] + DEPTH / 2
    joins["e:__exit__"] = {
        "room_a": tail, "room_b": "exit", "synthetic": True,
        "socket_a": [0.0, 0.0, tz], "socket_b": [0.0, 0.0, far],
        "chain": [_corridor([0.0, 0.0, tz], [0.0, 0.0, far])]}
    return {"status": "LAYOUT_OK", "rooms": rooms, "joins": joins,
            "anchors": anchors, "arrival_ok": arrival_ok,
            "apertures": apertures, "stations": stations}


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

        # AND WHAT THE PLAYER ALREADY DID IN IT, on the carrier the game
        # actually reads: `main.gd::_to_zone` is driven by `_on_snapshot`
        # and takes both the layout and the progress from
        # `BridgeClient.active_zone()`. Asserting a second copy on
        # `zone_ready` would test a field nothing consumes.
        snap = json.loads(engine.snapshot().model_dump_json())
        assert snap["active_zone"]["progress"]["collected_keys"] == [key]
        assert snap["active_zone"]["progress"]["opened_locks"] == [
            f"{room}/{socket}"]
        assert snap["active_zone"]["manifest"]["manifest_digest"] == digest
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
        # and lighting the button were two constants, and the second one
        # was never updated, so the Hub said "your Zone is waiting" over
        # a portal that was greyed out. A mode branch in the consumer
        # would not have fixed that.
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
    run(go())
