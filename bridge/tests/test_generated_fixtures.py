"""The rule suite's fixture must still be what its generator produces.

`godot/tests/fixtures/rules_snapshot.json` is a generated artifact: the
GDScript rule interpreter is tested against a REAL fold, so that it can
never be tested against a shape the bridge cannot actually produce. That
claim was true and unverifiable — the generator was scratch tooling and
did not survive, leaving a generated file in the tree with no source and
nothing stopping the next hand-edit.

This is the guard. It regenerates in memory and compares.
"""

from __future__ import annotations

import json
from pathlib import Path

from archipepsi_bridge.fixtures import make_rules_snapshot as gen
from archipepsi_bridge.schemas import mechanics as M


def test_the_committed_fixture_matches_its_generator():
    on_disk = json.loads(gen.OUT.read_text(encoding="utf-8"))
    fresh = M.derive_mechanics(gen.build_log()).model_dump(mode="json")
    assert on_disk["mechanics"] == fresh, (
        "run `make rules-fixture`; the JSON is generated, not edited")


def test_the_log_is_one_the_bridge_could_really_have_produced():
    """Not just that the fold accepts it — that every interpretation in it
    would have survived the same validation a granted Echo does."""
    from archipepsi_bridge.schemas.echo import target_errors

    log = gen.build_log()
    for index, interpretation in enumerate(log):
        so_far = M.derive_mechanics(log[:index])
        assert target_errors(interpretation, so_far) == [], (
            f"interpretation {index} could not have been granted")


def test_the_fixture_carries_a_channel_that_regenerates():
    """The suite's failed-payment tests are blind on a channel whose
    `regen_per_second` is zero, and every channel in the original fixture
    was. A refund that left `regen_delay` armed cost nothing measurable."""
    mechanics = M.derive_mechanics(gen.build_log())
    regenerating = [o for o in mechanics.resources
                    if o.component.regen_per_second > 0
                    and o.component.regen_delay > 0]
    assert regenerating, "no channel would notice a lost regen window"
