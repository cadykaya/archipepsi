"""NO STATUS BEFORE ITS EFFECT — the gate that makes D-7 safe to land.

`StatusEffects.apply` refuses kinds outside the generated list because a
kind nothing implements is worse than a kind nobody named: it is inert,
yet `status_active` answers true for it, `status_applied` fires, and
`cleanse` cannot remove it. `echo.STATUS_KINDS`' own comment records the
typo that produced exactly that.

Widening `StatusKind` for a DESIGNED name re-opens that hole on purpose.
So the vocabulary and the guarantee are now two lists, and this is what
proves the second one bites.
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from archipepsi_bridge.schemas import echo as E


def _status(kind: str) -> dict:
    return {"kind": "status", "component_id": "status_probe",
            "display_name": "Probe", "description": "A probe status.",
            "status": kind, "target": "self", "duration": 4.0,
            "magnitude": 0.5}


def test_today_the_two_lists_agree_and_nothing_changes():
    """The gate ships inert on purpose: it refuses nothing until a kind
    is admitted ahead of its runtime."""
    assert tuple(E.IMPLEMENTED_STATUS_KINDS) == tuple(E.STATUS_KINDS)
    for kind in E.STATUS_KINDS:
        E.StatusComponent.model_validate(_status(kind))


def test_a_named_kind_with_no_runtime_effect_cannot_be_emitted(monkeypatch):
    """THE CASE THE GATE EXISTS FOR.

    A kind the design names and the engine cannot honour is refused at
    the component, so it never reaches a campaign. Simulated by removing
    a kind from the implemented set, because today every named kind is
    implemented — the mechanism is what is under test, not the contents.
    """
    unimplemented = E.STATUS_KINDS[0]
    monkeypatch.setattr(
        E, "IMPLEMENTED_STATUS_KINDS",
        tuple(k for k in E.STATUS_KINDS if k != unimplemented))
    with pytest.raises(ValidationError, match="no runtime effect"):
        E.StatusComponent.model_validate(_status(unimplemented))
    # and every kind that IS implemented still passes
    for kind in E.STATUS_KINDS[1:]:
        E.StatusComponent.model_validate(_status(kind))


def test_the_engine_is_told_both_lists():
    """The engine cannot assert it can honour what it was never sent."""
    from pathlib import Path
    gd = Path("godot/scripts/autoload/constants.gd").read_text()
    assert "const ECHO_STATUS_KINDS =" in gd
    assert "const ECHO_STATUS_KINDS_IMPLEMENTED =" in gd
