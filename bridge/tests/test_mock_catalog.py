"""`--epsilon=mock` has to exercise the systems S2–S6 built.

EPSILON_SPEC §12.2 says so in as many words, and schedules it for S10:
"the mock provider is the one that must grow — `--epsilon=mock` has to
exercise resources, rules, links, merges and the wider action catalog, or
the headless integration run stops proving anything about the systems
S2–S6 add." It did not grow. Mock delegated its whole echo to
`fallback_echo` and added narration, and its own docstring said so:
"Mock Epsilon does not invent mechanics the fallback cannot."

The cost was measurable rather than theoretical. Across ten full campaigns
the shipped providers reached **8 of the 28 action primitives, one of the
four link kinds, and no Info readout at all**. `make godot-blink` fires
23,000 attempts at a verb no campaign grants. The hover, beam and block
holds in `make godot-verbs` cover presses no player can perform. Every
one of the ten §14.1 readouts is drawn, tested, and turned on by an `info`
component nothing in the tree emitted.

This file holds mock to the standard §12.2 sets. Two levels, because they
fail differently: every ROW of the shape table must be individually valid
(a row that cannot fold is a row that silently never fires), and a real
campaign must actually reach the systems (a table nothing selects from is
the same gap in a new place).
"""

from __future__ import annotations

import pytest

from archipepsi_bridge.epsilon import capabilities as CAP
from archipepsi_bridge.epsilon.fallback import _create_ops
from archipepsi_bridge.epsilon.mock import _MOCK_SHAPES, _mock_echo
from archipepsi_bridge.schemas import echo as E
from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas.echo import EchoInterpretation, target_errors

from .test_dispositions import _request


def _validated(raw: dict, seq: int = 0) -> EchoInterpretation:
    raw = {**raw, "interpretation_seq": seq}
    interpretation = EchoInterpretation.model_validate(raw)
    assert CAP.validate_stage_support(interpretation) == []
    assert target_errors(interpretation, M.EMPTY_MECHANICS) == []
    M.derive_mechanics([interpretation])          # and it folds
    return interpretation


# --- every row, individually ---------------------------------------------

@pytest.mark.parametrize("concept", [c for c, _ in _MOCK_SHAPES])
def test_every_shape_in_the_table_is_one_the_fold_accepts(concept):
    """A row that cannot fold is a row that never fires, and it would
    never say so — the pipeline would repair or fall back and the campaign
    would look fine. Each is checked against the same gates a live model's
    output goes through, and then folded.

    This is also what keeps the three `POWERED_PRIMITIVES` honest: the
    fold REFUSES a beam, hover or block with no `powers` link, so a shape
    that forgot its bar fails here rather than in someone's campaign."""
    build = dict(_MOCK_SHAPES)[concept]
    request = _request(0, "Test Item", None)
    components, phrase = build(request)
    assert phrase, "every shape describes itself for the archive"
    _validated(_create_ops(request, f"x, as {phrase}.", ["mock"], components))


def test_the_table_covers_the_systems_the_fallback_cannot_reach():
    """The point of the table, stated as a property rather than a list, so
    a shape removed tomorrow fails here instead of quietly narrowing what
    `--epsilon=mock` proves."""
    primitives: set[str] = set()
    links: set[str] = set()
    kinds: set[str] = set()
    for _concept, build in _MOCK_SHAPES:
        request = _request(0, "Test Item", None)
        components, _ = build(request)
        for component in components:
            if "op" in component:
                links.add(component["link"])
                continue
            kinds.add(component["kind"])
            if component["kind"] == "action":
                primitives.add(component["primitive"]["type"])

    assert links == {"powers", "fills", "gates", "scales"}, (
        f"all four link kinds, or the client's handling of the missing "
        f"ones is dead code in play; got {sorted(links)}")
    assert "info" in kinds, "no Info component means no §14.1 readout"
    for powered in E.POWERED_PRIMITIVES:
        assert powered in primitives, (
            f"'{powered}' needs a bar and a link, so only a multi-operation "
            f"shape can express it; the fallback never will")
    assert len(primitives) >= 18, (
        f"the table reaches {len(primitives)} primitives; the fallback "
        f"already reaches 10 on its own")


def test_the_readouts_the_table_offers_are_ones_the_client_can_draw():
    """`readouts.gd` pushes an error for a readout it has no display for,
    so a shape naming one would be an Echo that reports a bug on grant."""
    offered = set()
    for _concept, build in _MOCK_SHAPES:
        components, _ = build(_request(0, "Test Item", None))
        for component in components:
            if component.get("kind") == "info":
                offered.add(component["readout"])
    known = set(E.InfoComponent.model_fields["readout"].annotation.__args__)
    assert offered <= known
    assert "challenge_timer" not in offered, (
        "challenge_timer is the readout for a challenge that does not "
        "exist yet; granting it would be an Echo that turns on a timer "
        "nothing ever starts (see the open decision in AGENT_FRONTIER)")


# --- and a real campaign reaches them ------------------------------------

def test_mock_falls_through_to_the_fallback_for_an_item_it_cannot_read():
    """The fallback stays the floor, deliberately: everything it does is
    proved by its own tests, and falling through is what keeps an item
    mock has no shape for from being an item mock gets wrong."""
    echo = _mock_echo(_request(0, "Qqxzzy Widget", None))
    _validated(echo)
    assert all(op["op"] == "create" for op in echo["operations"])


def test_mock_reads_the_item_rather_than_matching_its_name():
    """Two different names for the same idea produce the same shape,
    because the §15 concept reader is what selects it."""
    a = _mock_echo(_request(0, "Glider Cape", None))
    b = _mock_echo(_request(1, "Feather Cape", None))
    kinds_a = [op["component"]["primitive"]["type"] for op in a["operations"]
               if op["component"]["kind"] == "action"]
    kinds_b = [op["component"]["primitive"]["type"] for op in b["operations"]
               if op["component"]["kind"] == "action"]
    assert kinds_a == kinds_b == ["glide"]


def test_mock_still_stamps_the_reading_it_derived():
    """S10's rule: the mode is derived from what the operations DID, so
    the archive cannot describe a draft that no longer exists. A shape
    from the table is a different draft than the fallback's, so it has to
    be re-derived rather than inherited."""
    echo = _mock_echo(_request(0, "Ice Beam", None))
    assert echo["concepts"], "the reading is stamped"
    # A beam is a bar, a verb, and the link between them — three
    # operations, and NOT systemic: a link whose two endpoints this same
    # interpretation created adds a self-contained thing. That rule is
    # what stopped the archive saying "Wired Magic Meter" about an Echo
    # that touched nothing the player already owned, and mock's shapes are
    # exactly the case it was written for.
    assert echo["mode"] == "conceptual", echo["mode"]


# --- and the campaign, which is what §12.2 actually asks about -----------

def test_a_mock_campaign_exercises_the_systems_s2_to_s6_added(tmp_path):
    """§12.2's real claim, measured on real campaigns rather than on the
    table: "or the headless integration run stops proving anything about
    the systems S2–S6 add."

    Before this, eight mock campaigns produced 8 of the 28 primitives, one
    of the four link kinds, and zero Info readouts. The item roster was
    the limit rather than the concept reader — ten names across thirty
    locations — so it was widened alongside the shapes, with names the
    reader already understood rather than names taught to it.
    """
    import archipepsi_bridge.campaign as CE
    from archipepsi_bridge.epsilon.mock import MockEpsilonProvider

    from . import test_campaign_soak as soak

    original = soak.make_engine
    soak.make_engine = lambda path: CE.CampaignEngine(
        provider=MockEpsilonProvider(), provider_name="mock",
        save_dir=path)
    try:
        primitives: set[str] = set()
        links: set[str] = set()
        kinds: set[str] = set()
        operations: set[str] = set()
        evolved = 0
        for seed in soak.SEEDS[:6]:
            watcher = soak.run(soak._play(tmp_path, seed))
            mechanics = M.derive_mechanics(
                watcher.engine.save.interpretations)
            for owned in mechanics.owned:
                kinds.add(owned.kind)
                if owned.kind == "action":
                    primitives.add(owned.component.primitive.type)
                if owned.mk > 1:
                    evolved += 1
            for edge in mechanics.links:
                links.add(edge.link)
            for interpretation in watcher.engine.save.interpretations:
                operations.update(op.op for op in interpretation.operations)
            # The confluence is what keeps the fifteen HUD channels from
            # filling with flasks now that most shapes carry a bar.
            hard = E.COMPLEXITY_BUDGETS["resource"][1]
            assert len(mechanics.resources) <= hard, (
                f"seed {seed} owns {len(mechanics.resources)} resources "
                f"against a hard ceiling of {hard}")
    finally:
        soak.make_engine = original

    assert operations == {"create", "upgrade", "modify", "link", "merge"}, (
        f"a mock campaign produced {sorted(operations)}; the whole "
        f"disposition vocabulary has to be reachable in play, not only in "
        f"a crafted request")
    # Measured: 18 with the chain running on mock's own shapes, 9 without
    # (the fallback's own path accounts for those nine). The threshold sits
    # between, because the failure it guards is silent — mock's catalog
    # shapes are fresh CREATEs, so a mock that skipped the chain would
    # still produce a working campaign, just one that accumulates instead
    # of evolving: seventeen unrelated Actions where twelve is the soft
    # budget, and a provenance chain that never gets longer than one.
    assert evolved >= 14, (
        f"only {evolved} components across six campaigns are past Mk I; "
        f"the fallback's own path alone reaches nine, so mock is not "
        f"running the disposition chain on its catalog shapes")

    assert links == {"powers", "fills", "gates", "scales"}, (
        f"a mock campaign reached {sorted(links)}; the client's handling "
        f"of the rest is dead code in play")
    assert "info" in kinds, (
        "no campaign granted an Info component, so all ten §14.1 readouts "
        "stay dark for every player without an API key")
    assert len(primitives) >= 14, (
        f"a mock campaign reached {len(primitives)} of "
        f"{len(E.ACTION_PRIMITIVES)} primitives")
    for powered in E.POWERED_PRIMITIVES:
        assert powered in primitives, (
            f"'{powered}' never reached a campaign, so `make godot-verbs` "
            f"covers a hold no player can perform")
