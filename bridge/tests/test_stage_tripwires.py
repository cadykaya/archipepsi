"""Deliberate tripwires: obligations that come due when a gate opens.

Each test here asserts the CURRENT stage boundary and names the work that
must land in the same change that moves it. They are the executable form
of "worth a note or a test that turns on with S5" — a note gets read by
whoever happens to look, a red test gets read by whoever moves the gate.

Failing one of these is not a regression. It is the reminder firing.
"""

from __future__ import annotations

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


def test_affordances_and_local_rewards_are_gated_until_s9():
    """The next dormant boundary, with the work due when it opens.

    An Affordance is a tag on generated geometry and an Info readout is a
    HUD element; neither exists, so accepting one would persist a
    component that renders nothing. `grant_local_reward` is the rule
    effect that pays one out, and `pull_pickup` the verb that collects
    one — the last deferred primitive.

    When this fails, S9 landed. In the same change: the never-mandatory
    validator (I4), the capability registry the generator grammar reads,
    and I12's water-volume acceptance test.
    """
    assert "affordance" not in IMPLEMENTED_COMPONENT_KINDS
    assert "info" not in IMPLEMENTED_COMPONENT_KINDS
