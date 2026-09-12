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
from archipepsi_bridge.schemas.protocol import ClientMessage
from pydantic import TypeAdapter

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
            # THE FIRST ROOM'S `entry` IS THE ZONE'S FRONT DOOR: no edge
            # names it so it is declared SEALED, and the player arrives
            # through it. This helper reported it as solid, which is a
            # Zone whose first room is walled shut -- the engine built
            # exactly that until `cut_plan` learned to carve it.
            front = (ch.id == zone.chambers[0].id
                     and d.socket_id == "entry")
            apertures[f"{ch.id}/{d.socket_id}"] = (
                True if front else d.passable_geometry)
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
