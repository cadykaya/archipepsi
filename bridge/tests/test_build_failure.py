"""A build that never happened, reported as itself.

**The hole this closes.** `ZoneController.setup` calls `ZoneBuilder`,
and when the router cannot place the rooms it returns — correctly,
because entering a level whose Check is inside a wall is worse than not
entering it. Returning was all it did. No `layout_result` is ever sent
for a build that did not happen, so the record sat ACTIVE waiting for a
verdict that was not coming: the Hub stayed ZONE_ACTIVE, offered a way
back into a Zone that cannot be built, and the campaign could not move.
On the client the same early return left `Main._to_zone` dereferencing a
player that was never created.

**Three failures, not one, and they are not interchangeable.**

* A **generation-stage rejection** is refused before the proposal is
  ever offered; no client sees it and `last_generation_error` reports
  it.
* A **refused layout** is geometry the engine DID build and the
  validator then rejected; `LayoutResult` carries it.
* A **build failure** is this: composed, offered, entered, and the
  engine could not construct it. There is no geometry, so nothing is
  validated and nothing may be synthesised to borrow the refusal path —
  an empty or part-built layout would have the validator report a
  geometry error for geometry that was never laid down.

What FOLLOWS from a build failure is the refusal ladder, because that
ladder is already right: charge the attempt, compose a fresh proposal
again inside `MAX_LAYOUT_REFUSALS`, park a committed one with its
manifest intact, and past the budget go DORMANT so the Hub offers
ABANDON. The Checks are never given back here — that is
`abandon_zone`'s act and only its.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge import layout
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas import transitions as T
from archipepsi_bridge.schemas.protocol import ClientMessage
from archipepsi_bridge.server import IntentError
from pydantic import TypeAdapter

from .conftest import connected_engine, drain, run
from .test_amalgam_end_to_end import (_movable, _place, _placement,
                                      _zone_with_branches)

_ADAPTER = TypeAdapter(ClientMessage)

#: What `ZoneBuilder` actually says when it gives up, near enough: it
#: names rooms and budgets and is not a short string.
_REASON = ("could not place c013 after 7 attempt(s); the branch under "
           "c010 is wedged and the spine has no spare socket")


async def _failed(engine, zid, reason=_REASON, **extra):
    await engine.handle_build_failed(_ADAPTER.validate_python(
        {"type": "build_failed", "zone_id": zid, "reason": reason,
         **extra}))
    await drain()


def test_a_build_failure_is_what_moves_the_record(tmp_path):
    """THE CONTROL. Before the message the Zone is ACTIVE and un-charged;
    the message is the only thing that changes that.

    Without this the rest of the file could pass against a bridge that
    moved the record for some other reason.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, _zone = await _zone_with_branches(engine)
        # ENTERED, because that is when a client builds. A Zone that was
        # only offered never reaches `ZoneController.setup`.
        await engine.handle_enter_zone(zid)
        await drain()
        before = engine.save.zone_by_id(zid)
        assert before.layout_refusals == 0
        assert before.state == "ACTIVE"
        assert engine.snapshot().hub.mode == "ZONE_ACTIVE"

        await _failed(engine, zid)
        after = engine.save.zone_by_id(zid)
        assert after.layout_refusals == 1, (
            "the engine's failure did not reach the record, so the Zone "
            "is still waiting for a verdict that is not coming")
    run(go())


def test_a_fresh_proposal_is_composed_again_and_keeps_its_checks(tmp_path):
    """BOUNDED RECOVERY. A different proposal, the same allocation."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, zone = await _zone_with_branches(engine)
        await engine.handle_enter_zone(zid)
        await drain()
        held = set(engine.save.zone_by_id(zid).allocated_location_ids)
        assert held, "a Zone holding nothing proves nothing about recovery"
        first = layout.proposal_digest(zone)

        await _failed(engine, zid)
        rec = engine.save.zone_by_id(zid)
        assert rec.layout_refusals == 1
        # OFFERED AGAIN, not still being played. The player is back in
        # the Hub and the replacement is waiting there for them; a Zone
        # left ACTIVE would be one the client is expected to be standing
        # in, which is the state this whole path exists to get out of.
        assert rec.state == "GENERATED", (
            "the recovery did not run; the campaign is stuck on a Zone "
            "the engine cannot build")
        assert rec.zone is not None, "nothing was composed to replace it"
        assert set(rec.allocated_location_ids) == held, (
            "a build failure gave the Zone's Checks back; that is "
            "`abandon_zone`'s act and only its")
        # NOT AN ACCEPTANCE. Nothing was validated, so nothing committed.
        assert rec.manifest is None
        assert layout.proposal_digest(rec.zone) is not None
        assert first  # the digest the failed build was about
    run(go())


def test_the_hub_stays_usable_while_the_zone_recovers(tmp_path):
    """A usable Hub is the point: the player is out of a Zone that could
    not be built, and the Hub still reports a mode they can act on."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, _zone = await _zone_with_branches(engine)
        await engine.handle_enter_zone(zid)
        await drain()
        await _failed(engine, zid)
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_READY", (
            f"the Hub reported {hub.mode!r} after a recoverable build "
            "failure; the replacement should be waiting to be entered")
    run(go())


def test_a_zone_the_engine_never_builds_exhausts_safely(tmp_path):
    """SAFE EXHAUSTION. DORMANT, ZONE_FAILED, every Check still held."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, _zone = await _zone_with_branches(engine)
        held = set(engine.save.zone_by_id(zid).allocated_location_ids)
        for _ in range(T.MAX_LAYOUT_REFUSALS):
            await _failed(engine, zid)
        rec = engine.save.zone_by_id(zid)
        assert rec.layout_refusals == T.MAX_LAYOUT_REFUSALS
        assert rec.layout_exhausted
        assert rec.state == "DORMANT"
        assert set(rec.allocated_location_ids) == held, (
            "exhaustion stranded or released the Zone's Checks")
        hub = engine.snapshot().hub
        assert hub.mode == "ZONE_FAILED"
        assert hub.discard_zone_id == zid, (
            "the Hub does not offer a way out of a Zone that cannot be "
            "built, so the player is stuck in front of it")
    run(go())


def test_past_the_budget_a_repeat_changes_nothing(tmp_path):
    """A client retrying after a dropped connection is the ordinary
    case, and a Zone that has given up has nothing left to spend."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, _zone = await _zone_with_branches(engine)
        for _ in range(T.MAX_LAYOUT_REFUSALS):
            await _failed(engine, zid)
        before = engine.save.zone_by_id(zid)
        spent, state = before.layout_refusals, before.state

        await _failed(engine, zid)
        after = engine.save.zone_by_id(zid)
        assert after.layout_refusals == spent
        assert after.state == state
    run(go())


def test_a_committed_zone_keeps_its_manifest_and_is_not_recomposed(tmp_path):
    """FRESH-PROPOSAL RECOVERY IS NOT COMMITTED-SAVE FAILURE.

    A Zone that laid out once and was accepted is a solved Zone the
    player may be part-way through; every later load replays its
    manifest and their progress is recorded against its rooms. If the
    replay of that manifest fails to build, composing a DIFFERENT Zone
    under the same id would strand all of it. It is parked instead —
    out of the player's hands, with everything it holds intact.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, zone = await _zone_with_branches(engine)
        good = _placement(_place(zone), zone, _movable(zone), "PLACED")
        await engine.handle_layout_result(_ADAPTER.validate_python(
            {"type": "layout_result", "zone_id": zid, "layout": good}))
        await drain()
        rec = engine.save.zone_by_id(zid)
        assert rec.manifest is not None, "this test needs a committed Zone"
        digest = rec.manifest["manifest_digest"]
        content = layout.proposal_digest(rec.zone)
        held = set(rec.allocated_location_ids)

        await _failed(engine, zid, reason="the committed manifest "
                                          "could not be replayed")
        after = engine.save.zone_by_id(zid)
        assert after.manifest is not None, (
            "the committed manifest was thrown away")
        assert after.manifest["manifest_digest"] == digest
        assert layout.proposal_digest(after.zone) == content, (
            "a saved Zone was replaced by a different one under its id")
        assert after.state == "DORMANT"
        assert set(after.allocated_location_ids) == held
        assert engine.save.active_zone_id != zid
    run(go())


def test_a_failure_for_a_replaced_proposal_is_ignored(tmp_path):
    """The same guard `layout_result` carries, for the same harm: a late
    failure must not spend the replacement's budget."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, zone = await _zone_with_branches(engine)
        current = layout.proposal_digest(zone)
        # A WELL-FORMED DIGEST THAT IS NOT THIS ZONE'S. The deterministic
        # provider composes identical content after a recovery, so the
        # digest of a real replaced proposal MATCHES -- which is exactly
        # why `attempt` exists and is covered separately. Taking the
        # stale id from a recompose here would test nothing, so the
        # mismatch is made directly.
        stale = "0" * 16 if current != "0" * 16 else "1" * 16
        before = engine.save.zone_by_id(zid)
        spent, state = before.layout_refusals, before.state

        await _failed(engine, zid, proposal_id=stale, attempt=0)
        after = engine.save.zone_by_id(zid)
        assert after.layout_refusals == spent, (
            "a replaced proposal's failure spent the replacement's budget")
        assert after.state == state
        assert layout.proposal_digest(after.zone) == current, (
            "a stale failure recomposed the Zone it was not about")
    run(go())


def test_a_failure_from_a_past_attempt_is_ignored(tmp_path):
    """`proposal_id` cannot answer this: a deterministic provider
    composes identical content, so the digest still matches. The ordinal
    is what separates the two tries."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, _zone = await _zone_with_branches(engine)
        await _failed(engine, zid, attempt=0)
        rec = engine.save.zone_by_id(zid)
        spent = rec.layout_refusals
        assert spent == 1

        await _failed(engine, zid, attempt=0)
        after = engine.save.zone_by_id(zid)
        assert after.layout_refusals == spent, (
            "one failure was charged twice")
    run(go())


def test_a_client_that_sends_no_identity_behaves_as_before(tmp_path):
    """Absent means "cannot be checked", never "stale" — the rule every
    optional identity field on this protocol follows."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, _zone = await _zone_with_branches(engine)
        await _failed(engine, zid)
        assert engine.save.zone_by_id(zid).layout_refusals == 1
    run(go())


def test_an_over_long_reason_cannot_break_the_snapshot(tmp_path):
    """THE HANG CLASS, guarded on this side too.

    A refusal message longer than `MAX_TEXT_LEN` made `CampaignSnapshot`
    raise on construction, which killed the generation task AND the
    broadcast, and left the client in GENERATING forever. The reason a
    router gives names rooms and budgets and is not short. The field is
    bounded, so an over-long one is refused at the door rather than
    carried to the cliff.
    """
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        zid, _zone = await _zone_with_branches(engine)
        with pytest.raises(Exception):
            _ADAPTER.validate_python(
                {"type": "build_failed", "zone_id": zid,
                 "reason": "x" * (C.MAX_TEXT_LEN + 1)})
        # And a reason exactly at the bound goes through, snapshot and all.
        await _failed(engine, zid, reason="x" * C.MAX_TEXT_LEN)
        assert engine.snapshot() is not None
        assert engine.save.zone_by_id(zid).layout_refusals == 1
    run(go())


def test_a_build_failure_for_a_zone_that_does_not_exist_is_an_error(tmp_path):
    """A report naming nothing is a protocol error, not a silent no-op:
    the two ways to be wrong here are worth telling apart."""
    async def go():
        engine, _ = await connected_engine(tmp_path, config=C.DEFAULT_CONFIG)
        with pytest.raises(IntentError):
            await _failed(engine, "zone_999")
    run(go())
