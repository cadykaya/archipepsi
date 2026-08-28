"""Every Godot suite the Makefile defines must actually run in CI.

The list of `make godot-*` calls in `integration.yml` is hand-maintained,
and a hand-maintained list of tests is a list that silently falls behind
the tests. A suite nobody runs is worse than no suite: it looks like
coverage on the target list and reports nothing.

This is the second guard of its kind, and it exists for the same reason as
the first. On 2026-08-27 a refactor deleted the five lines of `main.gd`
that build the world, and Archipepsi could not start for a day while nine
headless suites, a whole-campaign integration run and both CI tiers stayed
green -- because every one of those suites is a DRIVER, and a driver
returns from `_ready` before the deleted code. `--boot-test` closes that
hole, but only for as long as something makes CI keep calling it.
"""

from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MAKEFILE = REPO / "Makefile"
WORKFLOW = REPO / ".github" / "workflows" / "integration.yml"

# `godot-import` is a dependency of every suite rather than a suite itself,
# and `godot-integration` runs in its own CI step against a live bridge.
NOT_A_SUITE = {"godot-import", "godot-integration"}


def _makefile_suites() -> set[str]:
    targets = set(
        re.findall(r"^(godot-[a-z]+):", MAKEFILE.read_text(), re.MULTILINE)
    )
    return targets - NOT_A_SUITE


def _suites_ci_runs() -> set[str]:
    return set(re.findall(r"make (godot-[a-z]+)", WORKFLOW.read_text()))


def test_ci_runs_every_godot_suite_the_makefile_defines():
    missing = sorted(_makefile_suites() - _suites_ci_runs())
    assert not missing, (
        "these Godot suites exist but CI never runs them, so they can go red "
        "for weeks without anyone finding out: "
        + ", ".join(missing)
        + ". Add them to the 'Headless Godot suites' step in "
        "integration.yml, or -- if one genuinely should not run there -- "
        "say so in NOT_A_SUITE with the reason."
    )


def test_ci_does_not_call_a_suite_the_makefile_dropped():
    """The mirror: a renamed target leaves CI calling a dead name."""
    phantom = sorted(
        _suites_ci_runs() - _makefile_suites() - NOT_A_SUITE
    )
    assert not phantom, (
        "CI calls Godot targets the Makefile no longer defines: "
        + ", ".join(phantom)
    )


def test_the_check_can_actually_see_both_lists():
    """Vacuity guard: two empty sets agree with each other perfectly."""
    suites = _makefile_suites()
    assert len(suites) >= 9, f"only found {len(suites)} suites in the Makefile"
    assert "godot-boot" in suites, "the boot suite is the one this test is for"
    assert len(_suites_ci_runs()) >= 9, "did not find CI's suite list"
