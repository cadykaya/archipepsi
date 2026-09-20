"""The proposal identity, on the carrier the game actually reads.

`AMALGAM_BRIDGE.md` §5.9 asks the client to capture `proposal_id` when
it STARTS a build and echo it on `layout_result`, so a result that
arrives after the Zone was replaced is recognised and ignored. The
identity is issued on `zone_ready`.

**And `zone_ready` does not reach the build.** Traced in the client
rather than assumed: `main.gd::_to_zone` builds from
`BridgeClient.active_zone()["zone"]`, which is the campaign snapshot,
and `zone_ready_received` has **no connections anywhere in the client**.
The offer is the only carrier on one path and reaches nothing on
another:

| path | offer before the build? |
|---|---|
| fresh entry | yes, at generation |
| re-selection | yes, `_reselect_hosts` re-offers |
| re-entry to a COMMITTED Zone | yes, `handle_enter_zone` replays it |
| **cold restart into a Zone generated but never committed** | **no** |

That last row is an ordinary state — generate a Zone, quit at the Hub,
start the game again, walk in. `handle_enter_zone` only re-offers a
Zone that has a manifest, so the client would bind nothing on exactly
the path a restart takes, send no identity, and be read as a client
that predates the field.

So the snapshot carries it too. Not two copies of a fact: both are
`layout.proposal_digest` of the same record, derived on every send and
stored nowhere, so they cannot disagree — which is the same reason
`ZoneRecord.progress` is not duplicated onto `zone_ready`
(`test_physics_carrier.py`).
"""

from __future__ import annotations

import json

from archipepsi_bridge import layout
from archipepsi_bridge.schemas import constants as C

from .conftest import Collector, connected_engine, drain, run


def _snapshot(engine) -> dict:
    return json.loads(engine.snapshot().model_dump_json())


def test_the_snapshot_carries_the_identity_of_the_zone_it_holds(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        rec = engine.save.zone_by_id(zid)
        snap = _snapshot(engine)
        assert snap["active_zone"]["zone_id"] == zid
        assert snap["active_proposal_id"] == \
            layout.proposal_digest(rec.zone), (
                "the client builds from `active_zone`, so the identity "
                "of what it is building has to be on the same message")
    run(go())


def test_the_offer_and_the_snapshot_agree(tmp_path):
    """One derivation on two messages, never two facts."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        sink = Collector(engine)
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        offers = [m for m in sink.of_type("zone_ready")
                  if m.zone.zone_id == zid]
        assert offers, "a generated Zone is offered"
        assert offers[-1].proposal_id == \
            _snapshot(engine)["active_proposal_id"]
    run(go())


def test_a_restart_into_an_uncommitted_zone_still_binds_an_identity(tmp_path):
    """THE ROW THE OFFER DOES NOT COVER.

    A Zone generated and never entered, then a cold restart: the client
    reconnects, gets a snapshot, and the player walks in.
    `handle_enter_zone` re-offers only a COMMITTED Zone, so no
    `zone_ready` is sent — and the snapshot is the only thing that can
    tell this build which proposal it is of.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        rec = engine.save.zone_by_id(zid)
        assert rec.manifest is None, "generated, never laid out"
        expected = layout.proposal_digest(rec.zone)

        # THE RESTART. A fresh collector is a fresh connection: nothing
        # this client saw before the restart is available to it.
        sink = Collector(engine)
        await engine.handle_enter_zone(zid)
        await drain()
        assert not [m for m in sink.of_type("zone_ready")
                    if m.zone.zone_id == zid], (
            "an uncommitted Zone is not re-offered on entry; if this "
            "ever changes the offer becomes a second valid carrier and "
            "this test should say so rather than quietly still passing")
        assert _snapshot(engine)["active_proposal_id"] == expected
    run(go())


def test_a_reconnect_is_answered_with_the_identity_too(tmp_path):
    """`hello` is answered with `engine.snapshot()` and nothing else.

    A client that loses the connection mid-Zone asks again with
    `hello`, and `server._route` replies with exactly this object — no
    `zone_ready`, no re-offer. So the reconnect path binds an identity
    for the same reason the restart path does: because the identity is
    on the snapshot.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        await engine.handle_enter_zone(zid)
        await drain()
        answered = _snapshot(engine)
        assert answered["active_zone"]["zone_id"] == zid
        assert answered["active_proposal_id"] == layout.proposal_digest(
            engine.save.zone_by_id(zid).zone)
    run(go())


def test_the_identity_changes_when_the_zone_is_replaced(tmp_path):
    """A digest that does not move is an identity that checks nothing.

    The whole serialized Zone, so **content replacement counts as much
    as regraphing**: two Zones with identical edges over different rooms
    are two proposals, and a digest of the graph alone would call them
    one.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        await engine.handle_request_next_zone(False)
        await drain()
        zid = engine.save.active_zone_id
        rec = engine.save.zone_by_id(zid)
        first = _snapshot(engine)["active_proposal_id"]

        regraphed = rec.zone.model_copy(update={
            "display_name": rec.zone.display_name + " (recomposed)"})
        assert layout.proposal_digest(regraphed) != first, (
            "replacing the content must produce a different proposal")
    run(go())


def test_no_zone_held_carries_no_identity(tmp_path):
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        assert _snapshot(engine)["active_proposal_id"] == "", (
            "an empty string is 'no Zone', and a client reads it as "
            "'nothing to bind' rather than binding an empty digest")
    run(go())
