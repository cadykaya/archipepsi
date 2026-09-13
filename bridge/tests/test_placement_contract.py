"""One placement contract, checked on the bytes the engine really sends.

**Why this file is not in `test_layout.py`.** Every fixture there is
built in Python: a dictionary shaped the way the engine's serializer is
believed to shape one. That is the right tool for "what does the
validator do with X", and it is precisely the wrong tool for the defect
this file exists for. Both lanes shipped a `plug_placement`. The engine
keyed it by ROOM id with `MEASURED`/`REPAIRED`/`NO_EVIDENCE`/
`NO_CANDIDATE`; this side keyed it by EDGE id with `PLACED`/
`CANDIDATE_REJECTED`/`NO_CANDIDATE`. Both halves had tests. Both halves
passed. Nothing on either side of the wire was ever asked to agree with
the other, so every lookup missed, every plug read as a payload
predating the field, and a `NO_CANDIDATE` was ACCEPTED — a Zone
committing with a return device that was never placed.

So the payloads here are written by `make godot-zone-audit` — by
`ZoneBuilder.layout_to_json`, from a build `RoomAudit.measure_layout`
measured in a real physics space — and committed alongside
`captures.json`, which records for each one the exact Zone proposal
handed to `ZoneBuilder.build`, the outcome it demonstrates, the
controller build that measured it and the commit the tree was on. They
are **regenerated, never hand-edited**: a fixture somebody adjusts to
match the prose is the same mistake in a new place. Nothing below
rewrites a key or an outcome on the way in.

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

**Scope.** This file is the engine-evidence half: four captured
payloads, the compatibility rule, and the reselection they feed. The
decoder's own shape rules — a container that is not a mapping, a report
whose keys name nothing this Zone has, a mixed report — are
`test_amalgam_end_to_end.py`'s, on the lane that owns the decoder.

**And what these payloads are NOT.** They are INTERFACE evidence: they
prove the engine's placement report crosses the wire in a shape this
validator reads, and that each outcome reaches the recovery it belongs
to. They are not physical-layout acceptance. A captured
`plug_placement` says what the engine measured about return devices; it
says nothing about whether every room in that Zone was built, whether
the player can cross it, or whether the rest of the manifest holds
together. `layout.validate` judges those from the whole layout, and a
player walking the Zone is what judges the crossing. Reading a green
run here as "the layout is accepted" is the same confusion in a new
place: a subsystem proving its own interface and being mistaken for the
game.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from archipepsi_bridge import layout, topology
from .test_layout import _ok_result, _zone

#: Written by `godot/tests/zone_audit_driver.gd`; `make godot-zone-audit`
#: regenerates every file in here, `captures.json` included.
PAYLOADS = (Path(__file__).resolve().parents[2]
            / "godot" / "tests" / "fixtures" / "placement")

#: The plug a six-chamber branched Zone carries, and the key the engine
#: writes its report under. Named once so a drift shows up here.
EDGE = "p:c005:start"
HOST = "c005"

#: The four the engine was asked to capture, by what each demonstrates.
CAPTURES = {"supported": "PLACED", "repaired": "PLACED",
            "no_evidence": "NO_EVIDENCE", "exhausted": "NO_CANDIDATE"}


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


# --- the captures, and where they came from -------------------------------

def test_the_captures_say_what_they_are_and_how_to_remake_them():
    """A payload with no provenance is one nobody can re-derive.

    `captures.json` is the engine's own record of what it measured: the
    Zone proposal each payload came from, the outcome it demonstrates,
    the controller digest that measured it, the commit the tree was on
    and the single command that rebuilds all of it. Checked against the
    bytes, so a manifest that drifts from its own captures fails here
    rather than misleading whoever reads it next.
    """
    index = json.loads((PAYLOADS / "captures.json").read_text())
    assert index["reproduce"] == "make godot-zone-audit"
    assert index["controller_digest"]
    assert index["source_commit"] and "unknown" not in index["source_commit"], (
        "a capture with no commit cannot be traced back to the engine "
        "that produced it; `make godot-zone-audit` sets it")
    by_file = {c["file"]: c for c in index["captures"]}
    assert set(by_file) == {f"{n}.json" for n in CAPTURES}
    for name, outcome in CAPTURES.items():
        claim = by_file[f"{name}.json"]
        assert claim["outcome"] == outcome
        assert claim["edge_id"] == EDGE and claim["room_id"] == HOST
        assert claim["proposal"], "every capture says what it captured"
        assert claim["zone"]["chambers"], "and the exact Zone proposal"
        told = _engine(name)["plug_placement"][EDGE]
        assert told["outcome"] == outcome, (
            f"{name}.json reports {told['outcome']!r} and its manifest "
            f"entry claims {outcome!r}")


@pytest.mark.parametrize("name", sorted(CAPTURES))
def test_the_engine_keys_its_report_by_edge_and_speaks_this_vocabulary(name):
    """THE DEFECT ITSELF, on the bytes.

    A room id here, or an outcome spelled any other way, is the two-
    vocabulary bug back again. It would not be invisible any more —
    §5.9 made a report keyed by something else a loud refusal rather
    than a silent miss — but the refusal would take every Zone with it,
    so the producer is held to the key here as well.
    """
    sent = _engine(name)
    assert set(sent["plug_placement"]) == {EDGE}, (
        f"{name}.json keys its placement report "
        f"{sorted(sent['plug_placement'])}; the validator iterates "
        f"`zone.plugs` and looks up `edge_id`, so a report filed under "
        f"a room id ({HOST!r}) is a report about something else")
    outcome = sent["plug_placement"][EDGE]["outcome"]
    assert outcome in layout.PLACEMENT_OUTCOMES, (
        f"{name}.json reports {outcome!r}, which this contract does "
        f"not declare: {list(layout.PLACEMENT_OUTCOMES)}")


# --- the four integration controls ---------------------------------------

def test_a_supported_placement_is_accepted():
    """A position with support and clearance, and the layout stands."""
    zone, result, sent = _carrying("supported")
    told = sent["plug_placement"][EDGE]
    assert told["outcome"] == "PLACED" and told["repaired"] is False
    v = layout.validate(zone, result)
    assert v.accepted, v.errors
    assert v.unhostable_rooms == ()
    assert v.manifest["manifest_digest"]


def test_a_replaced_candidate_is_accepted_and_says_it_was_replaced():
    """The builder's spot failed and the search found another one.

    **`MEASURED` and `REPAIRED` are one outcome**: the device is
    placed. Which position it ended on rides along in `repaired` and
    `how` and changes nothing about the verdict. This is the case that
    used to bar the room outright — a pad on solid ground inside the
    arrival's own trigger reported `plug_clear = false`, which read as
    "this room cannot host a return".
    """
    zone, result, sent = _carrying("repaired")
    told = sent["plug_placement"][EDGE]
    assert told["outcome"] == "PLACED"
    assert told["repaired"] is True and told["how"], told
    assert told["searched"] > 0 and told["probed"] > 0, told
    v = layout.validate(zone, result)
    assert v.accepted, v.errors
    assert v.unhostable_rooms == ()


def test_missing_evidence_refuses_the_layout_and_does_not_bar_the_host():
    """The engine measured nothing, and SAYS so rather than falling silent.

    These bytes come from a build whose arrival anchor is not published.
    Silence would be indistinguishable from a client that predates the
    field, so the engine reports `NO_EVIDENCE` — and omits the clearance
    verdict for the same room in the same breath, which is one room
    reported consistently rather than two answers about it. The layout
    is refused, twice and for the two things that are missing, and
    `c005` is not named: a room nobody measured has not been found
    wanting.
    """
    zone, result, sent = _carrying("no_evidence")
    told = sent["plug_placement"][EDGE]
    assert told["outcome"] == "NO_EVIDENCE"
    assert told["searched"] == 0, (
        "an unmeasured room must not claim a search it did not run")
    assert sent["plug_clear"] == {}, sent["plug_clear"]
    v = layout.validate(zone, result)
    assert not v.accepted
    assert v.unhostable_rooms == (), (
        "NO_EVIDENCE is never NO_CANDIDATE; barring a host on it would "
        "reselect a branch away from a room the engine never judged")
    assert any("was not measured" in e for e in v.errors), v.errors
    assert any("no measured clearance" in e for e in v.errors), v.errors
    assert not any("offers no position" in e for e in v.errors), v.errors


def test_a_finished_search_that_found_nothing_bars_the_host():
    """The one outcome with teeth, and the only one that may reselect.

    Note what these bytes say about clearance: `true`. The device's
    trigger does not overlap the arrival, so the OLD signal — the one a
    room used to be barred on — reports no problem at all here. The bar
    comes from the placement outcome or it does not come, which is the
    whole reason the outcome exists.

    And the search is stated rather than asserted: 80 candidates
    enumerated across the declared lattice, 14 of them inside the room's
    envelope and put to the physics world. `searched` without `probed`
    cannot tell a finished search from one that never ran a query, which
    is exactly how a lattice with a missing axis passed for months.
    """
    zone, result, sent = _carrying("exhausted")
    told = sent["plug_placement"][EDGE]
    assert told["outcome"] == "NO_CANDIDATE"
    assert told["searched"] > 0 and told["probed"] > 0, told
    assert told["policy"], told
    assert sent["plug_clear"][EDGE] is True, sent["plug_clear"]
    v = layout.validate(zone, result)
    assert not v.accepted
    assert v.unhostable_rooms == (HOST,), v.unhostable_rooms
    assert any("offers no position" in e for e in v.errors), v.errors


# --- compatibility, and what absence is not ------------------------------

def test_a_payload_from_an_engine_that_predates_the_report_is_accepted():
    """THE ROLLOUT. The check is additive; older payloads still pass.

    Constructed rather than measured, and it has to be: the field is
    removed from a real accepted payload, which is exactly what an
    engine built before this contract sends and exactly what no engine
    built after it can produce — this one says `NO_EVIDENCE` when it has
    nothing, and absence is reserved for clients that never learned the
    word. Every rule that governed acceptance before the report existed
    still governs.
    """
    zone, result, _ = _carrying("supported")
    del result["plug_placement"]
    v = layout.validate(zone, result)
    assert v.accepted, v.errors
    assert v.unhostable_rooms == ()


@pytest.mark.parametrize("entry", ["NO_CANDIDATE", None,
                                   {"outcome": "NO_EVIDENCE_"},
                                   {"outcome": "MEASURED"},
                                   {"outcome": "CANDIDATE_REJECTED"}, {}])
def test_a_malformed_record_does_not_masquerade_as_legacy_absence(entry):
    """A present entry is a report, whatever shape it is in.

    The two spellings this producer used before §5.9 arrive as exactly
    this: a record whose outcome the contract does not declare. So does
    `CANDIDATE_REJECTED`, the word the consumer briefly had and nothing
    ever produced. An engine that half speaks this contract must be
    louder than one that does not speak it at all, not quieter.
    """
    zone, result, _ = _carrying("supported")
    result["plug_placement"] = {EDGE: entry}
    v = layout.validate(zone, result)
    assert not v.accepted, (
        f"{entry!r} was accepted as though the engine had said nothing")
    assert v.unhostable_rooms == (), (
        "a report that cannot be read is not a report that a room "
        "cannot host a return")


# --- and on to reselection ------------------------------------------------

def test_the_barred_host_the_engine_named_is_what_reselection_bars():
    """THE LAST LEG, and the one a field name cannot fake.

    `Verdict.unhostable_rooms` is fed straight into the composer as
    `barred`, which is what `campaign._reselect_hosts` does with it. The
    branch moves to another host; it is not dropped, and the count does
    not fall — recomposing a Zone with fewer branches would make the
    device requirement go away rather than satisfy it.
    """
    zone, result, _ = _carrying("exhausted")
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
