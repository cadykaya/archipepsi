"""S10: the interpretation pipeline (ECHOES §15, §16).

```
item -> concepts -> supported systems -> validated recipe
```

Three things are being defended:

* **The chain connects.** An Echo that reached a mechanic without reading
  anything is one the player has no way to argue with — the archive shows
  "read this as:" and then nothing.
* **The mode is true.** It is displayed as "how Epsilon read it", so a
  mode the operations do not support is the archive lying about the thing
  in the player's hands.
* **The budgets are counted in the units §16 states.** Which matters for
  exactly one kind, and that one is easy to get wrong.
"""

from __future__ import annotations

import re
from pathlib import Path

from archipepsi_bridge.campaign import _relevance_hint, budget_headroom
from archipepsi_bridge.epsilon import base as B
from archipepsi_bridge.epsilon import concepts as K
from archipepsi_bridge.epsilon.fallback import fallback_echo
from archipepsi_bridge.epsilon.requests import (
    EchoGenerationRequest, EchoPlayerState, EchoSource)
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas.echo import (
    COMPLEXITY_BUDGETS, EchoInterpretation, budget_errors, over_soft_budget)

PACKET = Path(__file__).resolve().parents[2] / "docs/design-packet-v0.8"


def _request(item_name="Water Tunic", game="The Legend of Zelda", loc=89100001):
    return EchoGenerationRequest(
        source=EchoSource(location_id=loc, item_name=item_name,
                          source_game=game, recipient_name="Partner",
                          item_flags=1),
        player_state=EchoPlayerState(),
        required_echo_id=f"echo_{loc}")


# --- §15: the reading -----------------------------------------------------

def test_the_echoes_own_worked_examples_read_the_way_it_says():
    """§15 gives three items and what Epsilon reads in them. They are the
    only worked examples of the reading step anywhere in the contract, so
    the lexicon has to reproduce them — otherwise the documentation shows
    behaviour the code does not have.

    Checked as sets: §15's ordering is illustrative (it leads with the
    modifier for *Water Tunic* and with the head noun for *Master Sword*),
    so pinning order would be pinning a coincidence.
    """
    expected = {
        ("Water Tunic", "The Legend of Zelda"):
            {"water", "buoyancy", "pressure", "protection"},
        ("BLJ", "Super Mario 64"):
            {"backwards", "momentum", "acceleration", "exploit"},
        ("Master Sword", "The Legend of Zelda"):
            {"blade", "heroism", "anti-evil", "energy"},
    }
    for (item, game), concepts in expected.items():
        got = set(K.read_concepts(item, game))
        assert concepts <= got, (item, sorted(concepts - got))


def test_the_examples_in_the_prose_are_the_examples_in_the_code():
    """The three items above are quoted from ECHOES §15 itself. If the
    prose changes its examples, this test is how the lexicon finds out —
    `check_packet.py` compares identifiers, not worked examples.
    """
    prose = (PACKET / "ECHOES.md").read_text()
    section = prose.split("# 15. Interpretation", 1)[1].split("# 16.", 1)[0]
    for item in ("Water Tunic", "BLJ", "Master Sword"):
        assert item in section, item


def test_an_item_nothing_recognises_is_still_read_as_something():
    """An empty concept tuple is a hole in the chain, not a modest
    admission: the archive would show the player an Echo with no
    explanation of where it came from."""
    for name in ("Zzyzx Widget", "", "a of the", "!!!"):
        got = K.read_concepts(name, "Some Game")
        assert got, name
        assert all(0 < len(c) <= K.MAX_CONCEPT_LEN for c in got), got
        assert len(got) <= K.MAX_CONCEPTS


def test_reading_is_deterministic():
    """The mock and fallback are the reproducible half of the project. A
    reading that wandered would make the archive disagree with itself
    between two runs of the same campaign."""
    for name in ("Hookshot", "Ancient Cursed Hoe", "Conference Call"):
        assert K.read_concepts(name, "G") == K.read_concepts(name, "G")


def test_the_lexicon_matches_whole_words_only():
    """Substring matching would fire `art` on `cart` and `ice` on `police`.
    The concepts are shown to the player, so a spurious match is visible
    nonsense rather than a silent inefficiency."""
    assert "blade" not in K.read_concepts("Swordfish Sandwich", "G")
    assert "cold" not in K.read_concepts("Police Radio", "G")


def test_a_reading_of_a_different_item_is_refused():
    """The check that earns its place: concepts pasted from another Echo,
    or invented wholesale, are not a reading of THIS item."""
    assert K.plausible_concepts(("water", "buoyancy"), "Water Tunic")
    assert K.plausible_concepts(("obligation",), "Boss Key")
    assert not K.plausible_concepts(("cheese", "fermentation"), "Water Tunic")
    assert not K.plausible_concepts((), "Water Tunic")


def test_the_pipeline_refuses_an_echo_that_read_nothing():
    request = _request()
    good = _echo_with(concepts=["water", "buoyancy"])
    assert B.reading_errors(good, request) == []
    assert B.reading_errors(_echo_with(concepts=[]), request) != []
    assert B.reading_errors(
        _echo_with(concepts=["cheese", "fermentation"]), request) != []


def test_a_reading_is_only_checked_for_attachment_not_for_taste():
    """Deliberately weak. There is no correct reading to check against —
    "Master Sword reads as heroism" and "as obligation" are both
    defensible — and a validator with taste would make every provider a
    worse version of `read_concepts`."""
    request = _request("Master Sword", "The Legend of Zelda")
    # Nothing like the lexicon's answer, but plainly about the item.
    assert B.reading_errors(
        _echo_with(concepts=["sword", "obligation", "weight"]), request) == []


# --- §15: modes -----------------------------------------------------------

def test_the_mode_describes_what_the_operations_did():
    """The archive shows this as "how Epsilon read it", so it has to be a
    true statement about the Echo rather than a claim about intent."""
    assert K.mode_for_operations(
        [{"op": "create", "component": {"kind": "action"}}]) == "literal"
    assert K.mode_for_operations(
        [{"op": "create", "component": {"kind": "trait"}}]) == "conceptual"
    assert K.mode_for_operations([{"op": "upgrade"}]) == "mechanical"
    for op in ({"op": "link"}, {"op": "merge"}, {"op": "modify"}):
        assert K.mode_for_operations([op]) == "systemic", op
    # A rule conditions the build rather than adding to it, even by CREATE.
    assert K.mode_for_operations(
        [{"op": "create", "component": {"kind": "rule"}}]) == "systemic"


def test_creativity_steers_the_mode_and_never_overrides_it():
    """§15 says modes are "influenced by" the creativity setting. A hard
    ceiling would have to either reject a good Echo for being read too
    imaginatively, or — the cheap way out — relabel its mode, which is the
    archive lying. So the influence lives in the request as steering.
    """
    assert K.preferred_modes(0)[0] == "literal"
    assert "systemic" in K.preferred_modes(2)
    assert "systemic" not in K.preferred_modes(0)
    # The derivation takes no creativity argument at all — that is what
    # makes the mode unable to be talked out of the truth.
    import inspect
    assert list(inspect.signature(
        K.mode_for_operations).parameters) == ["operations"]


def test_every_mode_in_the_contract_is_explained_to_a_provider():
    """A mode a provider is asked to declare but never told the meaning of
    is one it will declare at random."""
    from archipepsi_bridge.schemas.echo import INTERPRETATION_MODES
    assert set(K.MODE_MEANINGS) == set(INTERPRETATION_MODES)
    for creativity, modes in K.MODE_PREFERENCE.items():
        assert set(modes) <= set(INTERPRETATION_MODES), creativity


# --- the deterministic providers actually do it ---------------------------

def test_the_fallback_reads_the_item_and_labels_itself_truthfully():
    """The fallback used to ship an empty concept tuple and a hardcoded
    "literal", which left §15's chain unexercised by every deterministic
    run — the integration run included."""
    echo = EchoInterpretation.model_validate(
        fallback_echo(_request("Hookshot", "The Legend of Zelda")))
    assert echo.concepts
    assert K.plausible_concepts(
        echo.concepts, "Hookshot", "The Legend of Zelda")
    assert echo.mode == K.mode_for_operations(
        [op.model_dump() for op in echo.operations])


def test_the_mock_provider_says_out_loud_what_it_read():
    """Mock Epsilon's job is the reading, not new mechanics: it shares one
    validated vocabulary with the fallback, so a mock that could express
    more would be testing a game nobody ships."""
    import asyncio

    from archipepsi_bridge.epsilon.mock import MockEpsilonProvider
    raw = asyncio.run(MockEpsilonProvider().generate_echo(
        _request("Master Sword", "The Legend of Zelda")))
    echo = EchoInterpretation.model_validate(raw)
    assert echo.concepts
    for concept in echo.concepts:
        assert concept in echo.description, (concept, echo.description)


# --- §16: budgets ---------------------------------------------------------

def test_the_budget_table_is_the_one_in_the_prose():
    """§16 is a table of five rows and ten numbers. `check_packet.py`
    compares identifiers, not table cells, so this is what notices if the
    prose and the dict disagree."""
    prose = (PACKET / "ECHOES.md").read_text()
    section = prose.split("# 16. Complexity budgets", 1)[1].split("# 17.", 1)[0]
    for kind, label in (("resource", "Created resources"),
                        ("action", "Owned actions"),
                        ("rule", "Rules"),
                        ("affordance", "Distinct affordance tags"),
                        ("info", "Info readouts")):
        row = next(l for l in section.splitlines() if l.startswith(f"| {label}"))
        cells = [c.strip() for c in row.strip("|").split("|")]
        soft, hard = COMPLEXITY_BUDGETS[kind]
        assert cells[1] == str(soft), (kind, row)
        # The hard cell carries a unit for `resource` ("15 channels"), so
        # compare the leading number rather than the whole cell.
        leading = re.match(r"(\d+)", cells[2])
        if hard is None:
            assert leading is None, (kind, row)
        else:
            assert leading and int(leading.group(1)) == hard, (kind, row)


def test_affordances_are_budgeted_in_distinct_tags():
    """§16 says "Distinct affordance tags", and the unit is the whole
    point: a tag is a capability, so two Echoes both granting `rail` add
    one vocabulary to the campaign rather than two. Counting components
    would charge the player twice for a redundant grant.
    """
    log = [_affordance_echo("rail", seq=0, loc=89100001),
           _affordance_echo("rail", seq=1, loc=89100002)]
    live = M.derive_mechanics(log)
    assert len([o for o in live.owned if o.kind == "affordance"]) == 2
    assert budget_headroom(live)["affordance"][0] == 1, "two grants, one tag"


def test_the_refusal_counts_distinct_tags_too(monkeypatch):
    """`budget_headroom` (the steer) and `budget_errors` (the refusal)
    count affordances in two different functions, so both need proving.

    The affordance budget cannot be reached with only seven tags, so the
    only way to watch the refusal count anything is to narrow the budget —
    the same seam-narrowing the primitive-gate tests use. Without this,
    the refusal could count components while the steer counted tags and
    every real-data test would still pass.
    """
    import archipepsi_bridge.schemas.echo as E
    monkeypatch.setitem(E.COMPLEXITY_BUDGETS, "affordance", (1, 2))

    # Three grants, two distinct tags: inside a budget of 2.
    log = [_affordance_echo(tag, seq=i, loc=89100001 + i) for i, tag in
           enumerate(("rail", "rail", "bounce_pad"))]
    live = M.derive_mechanics(log)
    third_of_the_same = _affordance_echo("rail", seq=3, loc=89100004)
    assert budget_errors(third_of_the_same, live) == [], (
        "a redundant grant adds no vocabulary and must not breach")

    # A THIRD distinct tag is the one that breaches.
    new_tag = _affordance_echo("water_volume", seq=3, loc=89100004)
    assert any("hard budget" in e for e in budget_errors(new_tag, live))


def test_the_affordance_budget_is_a_ceiling_the_catalog_has_not_reached():
    """Stated rather than discovered. Only seven tags exist, so soft 8 and
    hard 12 cannot fire today — which is the right shape for a budget, and
    much better than a number that fires for the wrong reason. If the
    catalog grows past the soft budget, this test says so.
    """
    from archipepsi_bridge.schemas.zone import AffordanceTag
    tags = len(AffordanceTag.__args__)
    soft, hard = COMPLEXITY_BUDGETS["affordance"]
    assert tags < soft, (
        f"the catalog grew to {tags} tags and the affordance budget is live "
        f"now (soft {soft}); this test was the reminder")
    assert hard is not None and soft < hard


def test_the_steer_and_the_refusal_measure_the_same_thing():
    """A soft budget counted in components and a hard one counted in tags
    would fire at sizes that never agree — the steer would say "you have
    enough" while the refusal happily accepted more."""
    log = [_affordance_echo(tag, seq=i, loc=89100001 + i) for i, tag in
           enumerate(("rail", "rail", "bounce_pad", "water_volume"))]
    live = M.derive_mechanics(log)
    headroom = budget_headroom(live)["affordance"]
    assert headroom[0] == 3, "three distinct tags from four grants"
    # `over_soft_budget` reads the same count, so neither can drift.
    assert ("affordance" in over_soft_budget(live)) == (headroom[0] >= headroom[1])


def test_the_hard_budget_still_refuses_what_it_always_did():
    """The counting change must not have quietly opened the resource
    budget, which is the one that maps onto real HUD channels."""
    log = [EchoInterpretation.model_validate(_resource_echo(seq=i, loc=89100001 + i))
           for i in range(15)]
    live = M.derive_mechanics(log)
    assert budget_headroom(live)["resource"][0] == 15
    sixteenth = EchoInterpretation.model_validate(
        _resource_echo(seq=15, loc=89100016))
    assert any("hard budget" in e for e in budget_errors(sixteenth, live))


def test_budget_headroom_reports_every_kind_the_budget_table_names():
    live = M.derive_mechanics([])
    headroom = budget_headroom(live)
    assert set(headroom) == set(COMPLEXITY_BUDGETS)
    for kind, (owned, soft, hard) in headroom.items():
        assert owned == 0
        assert (soft, hard) == COMPLEXITY_BUDGETS[kind]


# --- §15: relevance -------------------------------------------------------

def test_a_fresh_campaign_is_told_to_relate_to_nothing():
    """With nothing owned there is nothing to relate to, and steering a
    provider toward a disposition anyway would push it at an operation
    that cannot validate."""
    assert _relevance_hint(M.derive_mechanics([])) == ""


def test_a_campaign_full_of_guns_says_so():
    """§15's own example: "if you already own three guns, Master Sword
    should not be gun four". The owned graph has been in the request since
    S6; this is the sentence that says what to do with it."""
    log = [_gun_echo(seq=i, loc=89100001 + i) for i in range(3)]
    hint = _relevance_hint(M.derive_mechanics(log))
    assert "hitscan_damage x3" in hint, hint
    assert "relationship" in hint, hint
    # ...and the specific half survives the field's 160-character clamp,
    # which it did not when the generic sentence led.
    assert len(hint) <= 160


# --- fixtures -------------------------------------------------------------

def _echo_with(*, concepts, mode="literal") -> EchoInterpretation:
    return EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": 0, "source_location_id": 89100001,
        "source_item_name": "Water Tunic", "source_game": "The Legend of Zelda",
        "source_recipient_name": "Partner", "concepts": concepts, "mode": mode,
        "display_name": "Tunic", "description": "d.",
        "operations": [{"op": "create", "component": {
            "kind": "action", "component_id": "act_x", "display_name": "X",
            "description": "d", "slot": "echo_a", "cooldown": 1.0,
            "primitive": {"type": "dash", "force": 12.0},
            "modifiers": []}}]})


def _base(seq: int, loc: int, component: dict) -> dict:
    return {
        "schema_version": 8, "echo_id": f"echo_{loc}",
        "interpretation_seq": seq, "source_location_id": loc,
        "source_item_name": f"Item {seq}", "source_game": "Some Game",
        "source_recipient_name": "Partner",
        "concepts": ["item"], "mode": "literal",
        "display_name": f"Echo {seq}", "description": "d.",
        "operations": [{"op": "create", "component": component}]}


def _affordance_echo(tag: str, *, seq: int, loc: int):
    return EchoInterpretation.model_validate(_base(seq, loc, {
        "kind": "affordance", "component_id": f"aff_{seq}",
        "display_name": tag.title(), "description": "d", "tag": tag}))


def _resource_echo(*, seq: int, loc: int) -> dict:
    return _base(seq, loc, {
        "kind": "resource", "component_id": f"res_{seq}",
        "display_name": f"R{seq}", "description": "d",
        "max_value": 100.0, "initial_fraction": 1.0,
        "presentation": "bar", "palette_color": "moss"})


def _gun_echo(*, seq: int, loc: int):
    return EchoInterpretation.model_validate(_base(seq, loc, {
        "kind": "action", "component_id": f"act_{seq}",
        "display_name": f"Gun {seq}", "description": "d",
        "slot": "echo_a", "cooldown": 1.0,
        "primitive": {"type": "hitscan_damage", "damage": 8.0, "pellets": 1,
                      "spread_degrees": 1.0, "range": 30.0},
        "modifiers": []}))
