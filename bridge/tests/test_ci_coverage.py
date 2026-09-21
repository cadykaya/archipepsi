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
#
# `godot-return-journey` is the same driver as `godot-integration`, run
# against a live bridge at `--mock-scale=default` because a prototype-scale
# Zone is three rooms and carries no branch to re-select. It is not in the
# headless step for that reason -- there is no bridge there -- and it has no
# step of its own because its last three legs are blocked on the
# `platform_path` side-door defect (`docs/AGENT_FRONTIER.md`). It is run by
# hand and its result is reported there; give it a CI step the day that
# defect is closed.
NOT_A_SUITE = {"godot-import", "godot-integration",
               "godot-return-journey",
               # PARAMETERISED AND DIAGNOSTIC, not a gate.
               # `godot-named-case` puts ONE named sample proposal in
               # front of a live bridge and reports what happened to it;
               # which proposal is the question, and there is no default
               # answer that means anything. It is the tool you reach for
               # when the offline census names a case, and what it
               # reports is a description rather than a pass or a fail.
               "godot-named-case",
               # A REPORT OF AN OPEN FINDING, not yet a gate — and the
               # finding is now MUCH smaller than it was.
               #
               # `godot-target-facing` reproduced a defect the playtest
               # found: 7 of 27 SHOT targets in Zone 1 aimed into a
               # crate, a wall or another target, because the unmounted
               # placement branch never set a yaw. The repair landed at
               # `e13e7e0` (a second pass in `Activities._row` that aims
               # the unmounted targets against the COMPLETE footprint
               # set, with `claimed_size` following the yaw), and it
               # took 7 down to **1**.
               #
               # The one that remains is `ActivityElement_4` in `c002`
               # at (-17.1, 2.2, 29.1): blocked inside 2 m at all 16
               # facings and at both widths, with the census reporting
               # the nearest blocker at 1.90 m. Rotation alone cannot
               # solve it, so it is a PLACEMENT question and the owner
               # has asked for the smallest same-room correction rather
               # than a wider search or a lowered threshold. Until that
               # lands the suite reports one real open case, and a gate
               # that is red for a known-open finding is a decision the
               # owner has not made. **It becomes a gate the moment
               # that placement correction lands**, and this entry comes
               # out with it.
               "godot-target-facing"}


#: HYPHENS INCLUDED. This read `godot-[a-z]+`, which stops dead at the
#: first hyphen -- so `godot-zone-audit` was invisible to the Makefile
#: side and showed up as a phantom on the CI side, and a suite named with
#: two words would have been silently unguarded. The pattern the guard
#: uses has to match the names people actually write.
_TARGET = r"godot-[a-z][a-z-]*"


def _makefile_suites() -> set[str]:
    targets = set(
        re.findall(rf"^({_TARGET}):", MAKEFILE.read_text(), re.MULTILINE)
    )
    return targets - NOT_A_SUITE


def _suites_ci_runs() -> set[str]:
    return set(re.findall(rf"make ({_TARGET})", WORKFLOW.read_text()))


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
