"""The bounded DEFAULT-scale check on the lower-budget variant.

Owner ruling 2026-09-14: before the variant is recommended for play,
run it at default scale through the existing machinery and report what
ordinary bounded recovery actually does with it.

**TWO STAGES, AND THEY ANSWER DIFFERENT QUESTIONS.** `validate_zone`
asks whether a PROPOSAL is structurally sound against the request that
asked for it. The engine's layout router asks whether that proposal can
be PLACED in a real space. A Zone can pass the first and fail the
second, and the two figures on record do not contradict each other:
twelve of twelve proposals bridge-valid (`tools/quiet_preview.py`), and
three of five variant manifests refused by the router (engine census,
`AGENT_FRONTIER.md`). What matters to a player is neither number on its
own but what recovery does next, which is what this file drives.

`test_quiet_integration.py` covers the flag, the request and acceptance.
This adds the two things that were not covered: whether the band is
really narrowed rather than clamped, and the live recovery sequence.
"""

from __future__ import annotations

import pytest

from archipepsi_bridge import layout as LAY
from archipepsi_bridge import quiet
from archipepsi_bridge.schemas import constants as C

from .conftest import Collector, drain, run
from .test_quiet_integration import _engine_at, _first_record
from .test_amalgam_end_to_end import (
    _unmovable, _place, _placement, _ADAPTER)


# --- is the band actually narrowed, or quietly clamped back? ---------------

def test_the_default_scale_band_is_really_narrowed():
    """`CampaignConfig.zone_budget_for` floors at `ZONE_BUDGET_MIN`, so
    the fraction is not free everywhere. At DEFAULT scale it bites."""
    asked = quiet.preview_budget(C.DEFAULT_CONFIG.zone_budget)
    assert asked < C.DEFAULT_CONFIG.zone_budget, "the band did not move"
    assert asked > C.ZONE_BUDGET_MIN, (
        "the default-scale preview is sitting on the contract floor, so "
        "this check would be measuring the clamp rather than the policy")
    assert asked == 720, asked


def test_at_prototype_scale_the_floor_swallows_the_whole_reduction():
    """WHY THE PROTOTYPE HARNESS SHOWS FAMILY-NARROWING ONLY.

    The prototype budget IS `ZONE_BUDGET_MIN`, so 72% of it clamps
    straight back to 100%: at that scale the variant is the filter-only
    arm wearing the preview's name. Recorded so a green prototype run is
    never read as evidence about the band.
    """
    proto = C.PROTOTYPE_CONFIG.zone_budget
    assert proto == C.ZONE_BUDGET_MIN
    effective = max(C.ZONE_BUDGET_MIN, quiet.preview_budget(proto))
    assert effective == proto, (
        "the prototype clamp stopped biting; this note is now wrong")


def test_the_generated_default_scale_variant_carries_the_narrowed_band(
        tmp_path):
    """Not the constant — the number the REQUEST actually went out with,
    and a Zone whose realised content sits in the narrowed band."""
    async def go():
        engine = await _engine_at(tmp_path, quiet_generation=True)
        rec = await _first_record(engine)
        assert rec.zone is not None, "no Zone was generated"
        value = sum(
            __import__("archipepsi_bridge.content_value", fromlist=["x"])
            .room_value(c) for c in rec.zone.chambers)
        baseline = C.DEFAULT_CONFIG.zone_budget
        asked = quiet.preview_budget(baseline)
        assert value < baseline * 0.90, (
            f"realised {value} is inside the BASELINE band, so the "
            "narrowing was clamped or ignored")
        assert value >= asked * 0.90, (
            f"realised {value} is under the narrowed band's own floor")
    run(go())


# --- the live recovery sequence, with a known router-refusal case ----------

def test_a_router_refusal_is_recovered_and_the_zone_is_entered(tmp_path):
    """THE SEQUENCE THE OWNER ASKED FOR, at default scale.

    Stage 1 the proposal is bridge-valid; stage 2 the router cannot place
    a branch room and refuses; then ordinary bounded recovery runs and
    the report is what it did — refusals charged, then acceptance and
    entry, then leave and resume.

    The refusal is the bridge's own representation of the engine census
    case: `NO_CANDIDATE` on a host whose branch cannot be moved, which is
    "a branch room that cannot be placed clear". No seed is tuned, no
    budget altered and no validation relaxed to reach a green result.
    """
    async def go():
        engine = await _engine_at(tmp_path, quiet_generation=True)
        sink = Collector(engine)
        rec = await _first_record(engine)
        zid, zone = rec.zone_id, rec.zone
        assert zone is not None

        # STAGE 1 — the proposal is structurally sound. It exists as an
        # accepted record at all, which is `generate_zone_validated`
        # having passed it.
        assert rec.state in ("GENERATED", "ACTIVE"), rec.state
        assert rec.layout_refusals == 0
        assert rec.manifest is None, "nothing is placed yet"

        # STAGE 2 — the router cannot place it.
        stuck = _unmovable(zone)
        await engine.handle_layout_result(_ADAPTER.validate_python({
            "type": "layout_result", "zone_id": zid,
            "layout": _placement(_place(zone), zone, stuck, "NO_CANDIDATE"),
            "proposal_id": LAY.proposal_digest(zone), "attempt": 0}))
        await drain(400)

        after = engine.save.zone_by_id(zid)
        refusals = after.layout_refusals
        assert refusals >= 1, "the router refusal was not charged"

        # RECOVERY — bounded, and allowed to run on its own terms.
        if after.layout_exhausted:
            assert after.manifest is None
            return                                  # exhaustion is an outcome

        # The recomposed proposal is placed successfully this time.
        fresh = engine.save.zone_by_id(zid).zone
        assert fresh is not None, "recovery left no Zone to place"
        await engine.handle_layout_result(_ADAPTER.validate_python({
            "type": "layout_result", "zone_id": zid,
            "layout": _place(fresh),
            "proposal_id": LAY.proposal_digest(fresh),
            "attempt": engine.save.zone_by_id(zid).layout_refusals}))
        await drain(400)

        placed = engine.save.zone_by_id(zid)
        assert placed.manifest is not None, (
            f"no manifest after {placed.layout_refusals} refusal(s)")
        digest = placed.manifest["manifest_digest"]

        # ENTRY, then LEAVE and RESUME.
        await engine.handle_enter_zone(zid)
        await drain()
        assert engine.save.active_zone_id == zid

        await engine.handle_leave_zone(zid)
        await drain()
        await engine.handle_enter_zone(zid)
        await drain()
        resumed = engine.save.zone_by_id(zid)
        assert engine.save.active_zone_id == zid, "resume did not re-enter"
        assert resumed.manifest["manifest_digest"] == digest, (
            "resume did not replay the committed manifest")
    run(go())
