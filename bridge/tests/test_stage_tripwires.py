"""Deliberate tripwires: obligations that come due when a gate opens.

Each test here asserts the CURRENT stage boundary and names the work that
must land in the same change that moves it. They are the executable form
of "worth a note or a test that turns on with S5" — a note gets read by
whoever happens to look, a red test gets read by whoever moves the gate.

Failing one of these is not a regression. It is the reminder firing.
"""

from __future__ import annotations

from archipepsi_bridge.epsilon.capabilities import IMPLEMENTED_OPERATION_KINDS
from archipepsi_bridge.epsilon.requests import EchoGenerationRequest


def test_links_are_gated_so_cost_relevance_is_dormant():
    """§7's third relevance leg sleeps until `powers`/`fills` links exist.

    `ResourceMeters._is_cost_of_slotted_action` reads the fold's links and
    can never answer true today: LINK operations are stage-gated, so the
    fold's `links` tuple is always empty. One third of the pressure-valve
    relevance rule is therefore intentionally dead code — correct, but
    unprovable.

    When this fails, LINK operations just landed. In the same change:
    add the case to `godot/tests/hud_driver.gd::_pressure_valve` proving a
    FULL, quiet resource stays expanded while a slotted Action is powered
    by it, then repoint this test at the next dormant boundary (statuses)
    or delete it.
    """
    assert "link" not in IMPLEMENTED_OPERATION_KINDS


def test_create_only_requests_carry_no_soft_budget_steer():
    """`over_soft_budget()` stays out of the request until it can be obeyed.

    §16's soft budget steers a provider toward UPGRADE / LINK / MERGE once
    the campaign is rich in some kind. Today the capability gate refuses
    every one of those operations, so carrying the steer would invite the
    provider to do the one thing validation then rejects — a prompt that
    manufactures its own repair loop. The staging table places budget
    context in the provider at S10 ("concepts, modes and budgets"), after
    dispositions land in S6. Decision recorded in
    docs/IMPLEMENTATION_DECISIONS.md (S3).

    When this fails, a non-CREATE operation just became implementable.
    In the same change: put `over_soft_budget(mechanics)` on
    `EchoGenerationRequest` (and into the prompt), and prove a steered
    request still validates.
    """
    assert IMPLEMENTED_OPERATION_KINDS == ("create",)
    assert "over_soft_budget" not in EchoGenerationRequest.model_fields
