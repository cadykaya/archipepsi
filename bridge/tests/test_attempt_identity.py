"""Two tries at the same content are two attempts, and one is stale.

`layout.proposal_digest` is CONTENT identity and stays that: two
proposals with identical bytes hash identically, which is correct — a
Zone is what it is made of — and is also exactly why a digest cannot
separate two tries at that same content.

**Measured live, not reasoned about.** A refusal sends a Zone back to
Epsilon; the deterministic fallback provider composes the SAME content
again; the replaced build's late result then arrives carrying an id that
still matches, and is read as current. In a live campaign that spent the
replacement's refusal budget — `4c1cd2d5405eeadf` before and after,
refusals 1 → 2 for one failure — and any verdict it drew would have
reached a player who is being held for a different build.

So the discriminator sits at the lifecycle boundary rather than in the
digest: `LayoutResult.attempt` is `ZoneRecord.layout_refusals` as it
stood when the client started building. A refusal is precisely what ends
one attempt and begins the next, the count already rides on
`active_zone` in every snapshot, and nothing about what a digest means
changes.

**What is explicitly PERMITTED.** A result from the CURRENT attempt is
current however many times it arrives. A client that reconnects and
resends is sending the same evidence about the same build, not making a
second claim, and the existing commit/refuse handling is idempotent for
it. "Late" is not a synonym for "duplicate": only a result from an
attempt the Zone has already moved past is discarded.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge import layout
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.protocol import ClientMessage
from pydantic import TypeAdapter

from .conftest import connected_engine, drain, run
from .test_amalgam_end_to_end import (_movable, _place, _placement,
                                      _zone_with_branches)

_ADAPTER = TypeAdapter(ClientMessage)


async def _send(engine, zid, layout_payload, **extra):
    await engine.handle_layout_result(_ADAPTER.validate_python(
        {"type": "layout_result", "zone_id": zid,
         "layout": layout_payload, **extra}))
    await drain()


def test_identical_content_really_does_hash_identically(tmp_path):
    """THE PREMISE, asserted rather than assumed.

    If a recompose produced different bytes there would be nothing here
    to fix — `proposal_id` would separate the attempts on its own. It
    does not, and this is the control that says so.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, zone = await _zone_with_branches(engine)
        before = layout.proposal_digest(zone)
        # A refusal with nothing the bar can act on: back to Epsilon,
        # which is deterministic and composes the same Zone again.
        await _send(engine, zid, {"status": "LAYOUT_INFEASIBLE"})
        rec = engine.save.zone_by_id(zid)
        if rec.zone is None:
            pytest.skip("this Zone was not recomposed in place")
        assert layout.proposal_digest(rec.zone) == before, (
            "the provider composed different content; this batch's "
            "premise no longer holds and the attempt field may be "
            "unnecessary")
        assert rec.layout_refusals == 1, rec.layout_refusals
    run(go())


def test_a_result_from_the_replaced_attempt_is_ignored(tmp_path):
    """The measured harm, closed: no budget spent, nothing committed,
    no verdict for a player who is being held for another build."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, zone = await _zone_with_branches(engine)
        await _send(engine, zid, {"status": "LAYOUT_INFEASIBLE"}, attempt=0)
        rec = engine.save.zone_by_id(zid)
        assert rec.layout_refusals == 1
        spent, state = rec.layout_refusals, rec.layout_state
        digest = layout.proposal_digest(rec.zone)

        # THE LATE ONE. Same content, same digest, previous attempt.
        await _send(engine, zid, {"status": "LAYOUT_INFEASIBLE"},
                    proposal_id=digest, attempt=0)
        after = engine.save.zone_by_id(zid)
        assert after.layout_refusals == spent, (
            "a replaced attempt's result spent the replacement's budget")
        assert after.layout_state == state
        assert after.manifest is None
        assert after.unhostable_rooms == ()
    run(go())


def test_a_resend_of_the_current_attempt_is_the_same_evidence(tmp_path):
    """PERMITTED REUSE, stated rather than left to inference.

    A dropped connection and a resend is the ordinary case. The second
    copy is about the same build and must be read as the same evidence:
    taken, not discarded as "late" and not charged twice.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, zone = await _zone_with_branches(engine)
        digest = layout.proposal_digest(zone)
        good = _placement(_place(zone), zone,
                          _movable(zone), "PLACED")

        await _send(engine, zid, good, proposal_id=digest, attempt=0)
        first = engine.save.zone_by_id(zid)
        assert first.manifest is not None, "the layout was accepted"
        committed = first.manifest["manifest_digest"]

        await _send(engine, zid, good, proposal_id=digest, attempt=0)
        again = engine.save.zone_by_id(zid)
        assert again.manifest["manifest_digest"] == committed, (
            "a resend of the same attempt replaced the committed layout")
        assert again.layout_refusals == first.layout_refusals
    run(go())


def test_changed_content_is_still_caught_by_the_digest(tmp_path):
    """The two mechanisms cover two different cases and neither
    replaces the other.

    Re-selection changes the GRAPH without spending a refusal, so the
    attempt ordinal does not move and `proposal_id` is what separates
    them. A recompose after a refusal keeps the content and spends one,
    so the ordinal is what separates those. Both, or one of the two
    replacements goes unnoticed.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, zone = await _zone_with_branches(engine)
        host = _movable(zone)
        stale_digest = layout.proposal_digest(zone)

        await _send(engine, zid,
                    _placement(_place(zone), zone, host, "NO_CANDIDATE"),
                    proposal_id=stale_digest, attempt=0)
        rec = engine.save.zone_by_id(zid)
        assert host in rec.unhostable_rooms, "the host was barred"
        assert rec.layout_refusals == 0, (
            "re-selection is not a refusal, so the attempt ordinal has "
            "not moved and only the digest can tell these apart")
        assert layout.proposal_digest(rec.zone) != stale_digest

        # The replaced build reports late: same attempt, older content.
        barred, plugs = rec.unhostable_rooms, {p.room_id
                                               for p in rec.zone.plugs}
        await _send(engine, zid,
                    _placement(_place(zone), zone, host, "NO_CANDIDATE"),
                    proposal_id=stale_digest, attempt=0)
        after = engine.save.zone_by_id(zid)
        assert after.unhostable_rooms == barred, (
            "a late result for the replaced graph barred another room")
        assert {p.room_id for p in after.zone.plugs} == plugs
        assert after.layout_refusals == 0
    run(go())


def test_a_client_that_sends_no_attempt_behaves_as_before(tmp_path):
    """Optional, and absent means "cannot be checked" — never "stale"."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, zone = await _zone_with_branches(engine)
        await _send(engine, zid, {"status": "LAYOUT_INFEASIBLE"})
        rec = engine.save.zone_by_id(zid)
        assert rec.layout_refusals == 1, (
            "a client with no attempt field is read exactly as before")
    run(go())
