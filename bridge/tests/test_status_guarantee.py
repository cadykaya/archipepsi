"""NO STATUS BEFORE ITS EFFECT — support is declared, never inherited.

The 0.4 destination is the Amalgam's thirteen Statuses over §15.1's five
target kinds (owner decision 2026-09-21). Naming them is not the same as
implementing them, and the first version of this gate got that wrong:
`IMPLEMENTED_STATUS_KINDS = STATUS_KINDS` made support a consequence of
being named, so each new name admitted itself and the gate protected
nothing at the only moment it mattered.

Support is now `SUPPORTED_STATUS_TARGETS`, edited on purpose in the
change that adds the effect, and checked at **every** path that can
start a Status. Nothing below patches a list to manufacture its case:
twelve §15.2 kinds are genuinely named and genuinely unsupported today.
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from archipepsi_bridge.schemas import echo as E


def _component(kind: str, target: str = "self") -> dict:
    return {"kind": "status", "component_id": "status_probe",
            "display_name": "Probe", "description": "A probe status.",
            "status": kind, "target": target, "duration": 4.0,
            "magnitude": 0.5}


def test_the_vocabulary_is_deliberately_wider_than_the_support():
    """The two lists must NOT be equal — that was the defect."""
    named, supported = set(E.STATUS_KINDS), set(E.IMPLEMENTED_STATUS_KINDS)
    assert supported < named, "support is tracking the vocabulary again"
    assert "lightened" in named and "lightened" not in supported
    assert "exposed" in named, "the Amalgam's thirteenth is missing"
    # And support may never name something the vocabulary does not.
    assert supported <= named


@pytest.mark.parametrize("kind", ["lightened", "anchored", "exposed",
                                  "brittle", "phased"])
def test_a_named_but_unsupported_kind_is_refused_at_every_door(kind):
    """REAL kinds, not a patched list. Three doors into one room."""
    with pytest.raises(ValidationError, match="no runtime effect"):
        E.StatusComponent.model_validate(_component(kind))
    with pytest.raises(ValidationError, match="no runtime effect"):
        E.ApplyStatusOnHit.model_validate({
            "type": "apply_status_on_hit", "status": kind,
            "duration": 2.0, "magnitude": 0.5})
    with pytest.raises(ValidationError, match="no runtime effect"):
        E.Effect.model_validate({"type": "apply_status", "subject": kind,
                                 "duration": 3.0})


def test_a_supported_kind_aimed_at_an_unsupported_target_is_refused():
    """Support is not one fact. `marked` is implemented on an enemy and
    not on the player, and the widened target vocabulary would otherwise
    let a rule aim it anywhere."""
    E.StatusComponent.model_validate(_component("marked", "enemy"))
    with pytest.raises(ValidationError, match="not implemented for target"):
        E.StatusComponent.model_validate(_component("marked", "self"))
    # And the §15.1 targets nothing implements yet are refused for every
    # kind, including the ones that work on creatures.
    for target in ("object", "surface", "volume"):
        with pytest.raises(ValidationError,
                           match="not implemented for target"):
            E.StatusComponent.model_validate(_component("burning", target))


def test_everything_supported_still_works():
    """The gate must not cost the twelve that ship today."""
    for kind, targets in E.SUPPORTED_STATUS_TARGETS.items():
        for target in targets:
            E.StatusComponent.model_validate(_component(kind, target))


def test_the_on_hit_list_is_derived_rather_than_transcribed():
    """It used to be a hand-written eight — a fourth copy of the
    vocabulary that nothing kept in step. Derived now, and the derivation
    reproduces exactly those eight."""
    admitted = []
    for kind in E.STATUS_KINDS:
        try:
            E.ApplyStatusOnHit.model_validate({
                "type": "apply_status_on_hit", "status": kind,
                "duration": 2.0, "magnitude": 0.5})
            admitted.append(kind)
        except ValidationError:
            pass
    assert admitted == ["burning", "slowed", "frozen", "shocked",
                        "poisoned", "marked", "stunned", "vulnerable"]


def test_a_misspelt_status_in_a_rule_effect_is_refused():
    """`subject` is a free string here, so before the gate a rule could
    start `brunning` — the permanent, inert, un-cleansable status the
    vocabulary's own comment records."""
    with pytest.raises(ValidationError, match="no runtime effect"):
        E.Effect.model_validate({"type": "apply_status",
                                 "subject": "brunning", "duration": 3.0})
    with pytest.raises(ValidationError, match="names no status"):
        E.Effect.model_validate({"type": "apply_status", "duration": 3.0})


def test_the_engine_is_told_both_lists():
    from pathlib import Path
    gd = Path("godot/scripts/autoload/constants.gd").read_text()
    assert "const ECHO_STATUS_KINDS =" in gd
    assert "const ECHO_STATUS_KINDS_IMPLEMENTED =" in gd
    assert "lightened" in gd, "the vocabulary did not reach the engine"
