"""One placement contract, checked on the bytes the engine really sends.

**Why this file is not in `test_layout.py`.** Every fixture there is
built in Python: a dictionary shaped the way the engine's serializer is
believed to shape one. That is the right tool for "what does the
validator do with X", and it is precisely the wrong tool for the defect
this file exists for — the engine's placement producer spoke
`MEASURED` / `REPAIRED` / `NO_EVIDENCE` keyed by ROOM while this
validator read `PLACED` / `CANDIDATE_REJECTED` / `NO_CANDIDATE` keyed by
EDGE. Both halves had tests. Both halves passed. Nothing on either side
of the wire was ever asked to agree with the other, so every outcome the
engine sent fell through `if outcome not in PLACEMENT_OUTCOMES` and
looked like a payload from an older engine.

So the payloads here are written by `make godot-zone-audit` — by
`ZoneBuilder.layout_to_json`, from a build `RoomAudit.measure_layout`
measured in a real physics space — and committed. They are
**regenerated, never hand-edited**: a fixture somebody adjusts to match
the prose is the same mistake in a new place.

The trace this completes, end to end:

    RoomAudit.measure_layout      the physics query
    -> ZoneController._measure_layout_evidence   onto the build
    -> ZoneBuilder.layout_to_json  the serializer  <- the files below
    -> layout.validate             this file
    -> Verdict.unhostable_rooms
    -> topology.compose_with_branch(barred=...)   the reselection

The host room is `c005` and the plug is `p:c005:start` in both lanes
because `compose_with_branch` names a six-chamber Zone's branch that
way. Nothing is renamed on the way in: the engine's own dictionary is
dropped onto a production Zone's layout under the key the engine itself
wrote, which is the only form of this test that can fail when the two
vocabularies drift apart again.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from archipepsi_bridge import layout, topology
from .test_layout import _ok_result, _zone

#: Written by `godot/tests/zone_audit_driver.gd`; see `make zone-fixtures`
#: in the Makefile for the regeneration command.
PAYLOADS = (Path(__file__).resolve().parents[2]
            / "godot" / "tests" / "fixtures" / "placement")

#: The plug a six-chamber branched Zone carries, and the key the engine
#: writes its report under. Named once so a drift shows up here.
EDGE = "p:c005:start"
HOST = "c005"


def _engine(name: str) -> dict:
    """One committed engine payload, or a skip that says how to make it."""
    path = PAYLOADS / f"{name}.json"
    if not path.is_file():
        pytest.skip(f"{path} is missing; run `make godot-zone-audit`")
    return json.loads(path.read_text())


def _carrying(name: str):
    """A sound layout for a real Zone, carrying the engine's own report.

    `_ok_result` is the accepted control: every room placed, every edge
    routed, every aperture reported. The only thing replaced is the pair
    of fields the placement lane produces — **wholesale, under the keys
    the engine wrote** — so the verdict below is a statement about the
    engine's evidence and about nothing else in the payload.
    """
    zone = _zone(6)
    assert [pl.edge_id for pl in zone.plugs] == [EDGE], (
        "the control Zone must carry exactly the plug the engine "
        "payloads report on, or this test is grafting a report onto "
        "something it was not written about")
    sent = _engine(name)
    result = _ok_result(zone)
    result["plug_clear"] = sent["plug_clear"]
    result["plug_placement"] = sent["plug_placement"]
    return zone, result, sent


# --- the wire identity ----------------------------------------------------

@pytest.mark.parametrize("name", ["placed", "repaired", "barren",
                                  "rejected"])
def test_the_engine_keys_its_report_by_edge_and_speaks_this_vocabulary(name):
    """THE DEFECT ITSELF, on the bytes.

    A room id here, or an outcome spelled any other way, is the two-
    vocabulary bug back again — and it would be invisible in every
    other test in this suite, because a report the validator cannot
    read is one it walks straight past.
    """
    sent = _engine(name)
    assert set(sent["plug_placement"]) == {EDGE}, (
        f"{name}.json keys its placement report "
        f"{sorted(sent['plug_placement'])}; the validator iterates "
        f"`zone.plugs` and looks up `edge_id`, so a report filed under "
        f"a room id ({HOST!r}) is a report nothing reads")
    outcome = sent["plug_placement"][EDGE]["outcome"]
    assert outcome in layout.PLACEMENT_OUTCOMES, (
        f"{name}.json reports {outcome!r}, which this contract does "
        f"not declare: {list(layout.PLACEMENT_OUTCOMES)}")


# --- the four integration controls ---------------------------------------

def test_a_supported_placement_is_accepted():
    """A position with support and clearance, and the layout stands."""
    zone, result, sent = _carrying("placed")
    told = sent["plug_placement"][EDGE]
    assert told["outcome"] == "PLACED" and told["repaired"] is False
    v = layout.validate(zone, result)
    assert v.accepted, v.errors
    assert v.unhostable_rooms == ()
    assert v.manifest["manifest_digest"]


def test_a_rejected_candidate_that_was_replaced_is_accepted():
    """The builder's spot failed and the search found another one.

    **The final outcome is what crosses.** `repaired` and `tried` ride
    along for the log; they do not soften a `PLACED` into a doubt. This
    is the case that used to bar the room outright: a pad on solid
    ground inside the arrival's own trigger reported `plug_clear =
    false`, which read as "this room cannot host a return".
    """
    zone, result, sent = _carrying("repaired")
    told = sent["plug_placement"][EDGE]
    assert told["outcome"] == "PLACED"
    assert told["repaired"] is True and told["tried"] > 0, told
    v = layout.validate(zone, result)
    assert v.accepted, v.errors
    assert v.unhostable_rooms == ()


def test_missing_evidence_refuses_the_layout_and_does_not_bar_the_host():
    """Nothing was measured, so nothing is claimed about the room.

    These bytes come from a build whose arrival anchor is not published:
    the engine files no placement entry AND no clearance verdict, which
    is one room reported consistently rather than two answers about it.
    The layout is refused — for the measurement that is missing — and
    `c005` is not named, because a room nobody measured has not been
    found wanting.
    """
    zone, result, sent = _carrying("absent")
    assert sent["plug_placement"] == {}, sent["plug_placement"]
    assert sent["plug_clear"] == {}, sent["plug_clear"]
    v = layout.validate(zone, result)
    assert not v.accepted
    assert v.unhostable_rooms == (), (
        "absence is not NO_CANDIDATE; barring a host on it would "
        "reselect a branch away from a room the engine never judged")
    assert any("no measured clearance" in e for e in v.errors), v.errors
    assert not any("offers no position" in e for e in v.errors), v.errors


def test_a_finished_search_that_found_nothing_bars_the_host():
    """The one outcome with teeth, and the only one that may reselect.

    Note what these bytes say about clearance: `true`. The device's
    trigger does not overlap the arrival, so the OLD signal — the one a
    room used to be barred on — reports no problem at all here. The bar
    comes from the placement outcome or it does not come, which is the
    whole reason the outcome exists.
    """
    zone, result, sent = _carrying("barren")
    told = sent["plug_placement"][EDGE]
    assert told["outcome"] == "NO_CANDIDATE"
    assert told["tried"] > 0 and told["policy"], told
    assert sent["plug_clear"][EDGE] is True, sent["plug_clear"]
    v = layout.validate(zone, result)
    assert not v.accepted
    assert v.unhostable_rooms == (HOST,), v.unhostable_rooms
    assert any("offers no position" in e for e in v.errors), v.errors


def test_a_search_that_could_not_be_run_refuses_without_barring():
    """`CANDIDATE_REJECTED`: refuse this layout, judge nothing.

    The room has no committed envelope, so the bounded search the
    contract describes has nothing to run inside. A refusal — a return
    with no accepted position is a return that fires on the way in — and
    NOT a bar, because an unrun search establishes nothing about a room.
    """
    zone, result, sent = _carrying("rejected")
    assert sent["plug_placement"][EDGE]["outcome"] == "CANDIDATE_REJECTED"
    v = layout.validate(zone, result)
    assert not v.accepted
    assert v.unhostable_rooms == (), (
        "only a finished search may bar a host; a layout refused on an "
        "unrun one must be retried, not recomposed around")
    assert any("did not finish" in e for e in v.errors), v.errors


# --- compatibility, and what absence is not ------------------------------

def test_a_payload_from_an_engine_that_predates_the_report_is_accepted():
    """THE ROLLOUT. The check is additive; older payloads still pass.

    Constructed rather than measured, and it has to be: the field is
    removed from a real accepted payload, which is exactly what an
    engine built before this contract sends and exactly what no engine
    built after it can produce. Every rule that governed acceptance
    before the report existed still governs, so a layout with sound
    anchors, support and clearance is accepted with nothing said about
    placement.
    """
    zone, result, _ = _carrying("placed")
    del result["plug_placement"]
    v = layout.validate(zone, result)
    assert v.accepted, v.errors
    assert v.unhostable_rooms == ()


@pytest.mark.parametrize("entry", ["NO_CANDIDATE", None, [], 0,
                                   {"outcome": "NO_EVIDENCE"},
                                   {"outcome": "MEASURED"}, {}])
def test_a_malformed_report_does_not_masquerade_as_legacy_absence(entry):
    """A present entry is a report, whatever shape it is in.

    The gate was `isinstance(told, dict)`, so a bare outcome string, a
    null or a list took the compatibility path and was **accepted in
    silence** — and the two spellings this producer briefly used,
    `NO_EVIDENCE` and `MEASURED`, arrive as exactly that: a dictionary
    whose outcome this contract does not declare. An engine that half
    speaks this contract must be louder than one that does not speak it
    at all, not quieter.
    """
    zone, result, _ = _carrying("placed")
    result["plug_placement"] = {EDGE: entry}
    v = layout.validate(zone, result)
    assert not v.accepted, (
        f"{entry!r} was accepted as though the engine had said nothing")
    assert v.unhostable_rooms == (), (
        "a report that cannot be read is not a report that a room "
        "cannot host a return")


def test_a_placement_report_that_is_not_a_mapping_is_refused():
    """And the container itself. `result.get(...) or {}` let a non-empty
    list through to `.get`, which is an AttributeError inside the
    validator rather than a refusal — a malformed payload must be
    answered, not crashed on."""
    zone, result, _ = _carrying("placed")
    result["plug_placement"] = [EDGE]
    v = layout.validate(zone, result)
    assert not v.accepted
    assert any("not a mapping" in e for e in v.errors), v.errors


# --- and on to reselection ------------------------------------------------

def test_the_barred_host_the_engine_named_is_what_reselection_bars():
    """THE LAST LEG, and the one a field name cannot fake.

    `Verdict.unhostable_rooms` is fed straight into the composer as
    `barred`, which is what `campaign._reselect_hosts` does with it. The
    branch moves to another host; it is not dropped, and the count does
    not fall — recomposing a Zone with fewer branches would make the
    device requirement go away rather than satisfy it.
    """
    zone, result, _ = _carrying("barren")
    barred = layout.validate(zone, result).unhostable_rooms
    assert barred == (HOST,)

    before = topology.compose_with_branch(list(zone.chambers))
    after = topology.compose_with_branch(list(zone.chambers),
                                         barred=barred)
    assert [pl.room_id for pl in before.plugs] == [HOST]
    assert len(after.plugs) == len(before.plugs), (
        "reselection moves a branch to a supported host; handing back "
        "a Zone with fewer branches is branch removal")
    assert HOST not in {pl.room_id for pl in after.plugs}, (
        "the room the engine measured and refused is still hosting the "
        "return the engine could not stand in it")
