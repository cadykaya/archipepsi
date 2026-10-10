"""Deliberate tripwires: obligations that come due when a gate opens.

Each test here asserts the CURRENT stage boundary and names the work that
must land in the same change that moves it. They are the executable form
of "worth a note or a test that turns on with S5" — a note gets read by
whoever happens to look, a red test gets read by whoever moves the gate.

Failing one of these is not a regression. It is the reminder firing.
"""

from __future__ import annotations

from pathlib import Path

from archipepsi_bridge.epsilon.capabilities import (
    IMPLEMENTED_COMPONENT_KINDS, IMPLEMENTED_OPERATION_KINDS)
from archipepsi_bridge.epsilon.requests import EchoGenerationRequest


def test_the_s5_obligations_were_discharged_when_links_landed():
    """Both S3-era tripwires fired at S5, and both were paid.

    They asserted that LINK was gated (so §7's third relevance leg was
    dead code) and that the request carried no soft-budget steer (so a
    provider could not be told to do what validation refused). S5 landed
    LINK, so this is the discharge receipt: the request carries the steer,
    and `hud_driver.gd::_pressure_valve` now proves a FULL, quiet channel
    stays expanded while it powers a slotted Action.
    """
    assert "link" in IMPLEMENTED_OPERATION_KINDS
    assert "over_soft_budget" in EchoGenerationRequest.model_fields


def test_the_s9_obligations_were_discharged():
    """The last tripwire fired at S9, and was paid.

    It asserted that affordances and Info readouts were gated, and named
    the work due when they opened: the capability registry, the
    never-mandatory validator, and I12's acceptance test. All three
    landed with the gate, so this is the receipt.

    Nothing is gated any more — the registry equals its contract in every
    dimension — so there is no next dormant boundary to point at. The
    remaining guard is `test_the_registry_still_runs` below: a mechanism
    that gates nothing is one refactor away from being deleted, and the
    thing it protects against is the NEXT schema addition.
    """
    assert "affordance" in IMPLEMENTED_COMPONENT_KINDS
    assert "info" in IMPLEMENTED_COMPONENT_KINDS


def test_the_registry_still_runs_even_though_it_gates_nothing():
    """The capability gate must still be wired, and still be capable of
    refusing something, or the next schema addition lands unguarded."""
    from archipepsi_bridge.epsilon.capabilities import validate_stage_support
    from archipepsi_bridge.schemas.echo import EchoInterpretation

    # Schema-legal in every respect, and accepted today. The registry is
    # what would catch a schema that grew a new modifier, primitive or
    # component kind before a runtime learned to run it.
    fake = EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": "echo_89100001",
        "interpretation_seq": 0, "source_location_id": 89100001,
        "source_item_name": "I", "source_game": "G",
        "source_recipient_name": "P", "display_name": "T",
        "description": "d.", "operations": [{"op": "create", "component": {
            "kind": "action", "component_id": "act_x", "display_name": "X",
            "description": "d", "slot": "echo_a", "cooldown": 1.0,
            "primitive": {
                "type": "melee_swing", "damage": 12.0,
                "reach": 2.0, "arc_degrees": 90.0},
            "modifiers": [{"type": "recoil_self", "force": 5.0}]}}],
    })
    assert validate_stage_support(fake) == []
    import archipepsi_bridge.epsilon.capabilities as CAP
    original = CAP.IMPLEMENTED_MODIFIER_TYPES
    CAP.IMPLEMENTED_MODIFIER_TYPES = ()
    try:
        assert validate_stage_support(fake) != []
    finally:
        CAP.IMPLEMENTED_MODIFIER_TYPES = original


def test_the_challenge_marker_still_has_no_challenge():
    """A deliberate gap, named so it cannot be forgotten.

    §14.2 lists `challenge_marker` as "an optional timed or scored
    challenge; records a personal best", and §14.1 lists a
    `challenge_timer` readout showing "elapsed time and best on an active
    challenge marker". Neither says what the challenge IS — where a run
    starts, what ends it, what counts as a run — so the world half is not
    built and `Readouts.set_challenge` has no callers.

    Everything that does not need that decision works: the reward kind is
    grantable, it is recorded, and `best_seconds` only improves. What is
    missing is a decision, not code.

    **When that decision is made,** this test comes due: give the marker a
    start and an end in the world, call `set_challenge` from it, and
    assert the readout draws — then delete this.
    """
    from archipepsi_bridge.schemas.protocol import EarnedLocalReward
    kinds = EarnedLocalReward.model_fields["kind"].annotation.__args__
    assert "challenge_marker" in kinds
    assert "best_seconds" in EarnedLocalReward.model_fields

    readouts = (Path(__file__).resolve().parents[2]
                / "godot/scripts/ui/readouts.gd").read_text()
    assert "func set_challenge(" in readouts, (
        "the clock is wired and waiting; if it has gone, the decision was "
        "made and this tripwire is stale")
    callers = [line for line in readouts.splitlines()
               if "set_challenge(" in line and "func " not in line]
    assert not callers, (
        "something calls set_challenge now, so the challenge exists — "
        "assert the readout draws and delete this tripwire", callers)
