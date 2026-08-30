"""The GDScript action runner must handle exactly what the schema admits.

`IMPLEMENTED_PRIMITIVES` is the promise that an Action the engine cannot
execute is refused at validation rather than accepted as an ability that
does nothing when you press the key. That promise is only as good as the
engine actually having a branch for every verb on the list -- and nothing
could check that, because the list is Python and the runner is GDScript.

So this test reads the runner. It is a source-level check rather than a
behavioural one, which is a real limitation: it proves a branch EXISTS, not
that the branch is correct. What it does prove is the thing that silently
rots -- widening the catalog on the Python side without teaching the engine
the verb, which produces an Echo that validates, persists, occupies a slot
and does nothing at all.
"""

from __future__ import annotations

import re
from pathlib import Path

from archipepsi_bridge.schemas.echo import (
    DEFERRED_PRIMITIVES, IMPLEMENTED_PRIMITIVES,
)

RUNNER = (Path(__file__).resolve().parents[2]
          / "godot" / "scripts" / "gameplay" / "echo_runtime.gd")


def _handled_primitives() -> set[str]:
    """Case labels of the `match _primitive_type()` inside `activate()`."""
    source = RUNNER.read_text()
    start = source.index("func activate()")
    end = source.index("\nfunc ", source.index("match _primitive_type():", start))
    body = source[start:end]
    # `\t\t"name":` — a case label, as opposed to a quoted name appearing in
    # an expression. Anchored to the line so a string inside a call cannot
    # masquerade as a handled verb.
    return set(re.findall(r'^\t\t"([a-z_]+)":', body, re.MULTILINE))


def test_the_runner_handles_every_implemented_primitive():
    handled = _handled_primitives()
    missing = set(IMPLEMENTED_PRIMITIVES) - handled
    assert not missing, (
        f"the schema admits {sorted(missing)} but the GDScript runner has no "
        "branch for them: those Echoes would validate, persist, take a slot "
        "and do nothing"
    )


def test_the_runner_does_not_handle_a_primitive_the_schema_refuses():
    """The other direction, which is the subtler rot.

    A branch for a verb validation rejects is dead code that reads like a
    shipped feature, and it is how a stage boundary quietly stops meaning
    anything.
    """
    handled = _handled_primitives()
    premature = handled & set(DEFERRED_PRIMITIVES)
    assert not premature, (
        f"the runner has branches for {sorted(premature)}, which "
        "validate_interpretation still refuses; either land the stage or "
        "drop the dead branch"
    )


def test_the_check_can_actually_see_the_runner():
    """A parse that silently found nothing would pass both tests above."""
    assert RUNNER.is_file(), RUNNER
    handled = _handled_primitives()
    assert len(handled) >= 20, handled


def test_binding_a_player_clears_the_previous_world_s_prompt():
    """"[E] ENTER ZONE" followed the player into the Zone they entered.

    The player emits `interact_prompt_changed` only when its target
    CHANGES. A fresh player after a view transition starts with a null
    target, so one that spawns looking at nothing compares null to null,
    emits nothing, and the HUD keeps whatever the last world put there.
    The prompt was never wrong; it was never asked to update.

    Source-level, and that is a real limitation -- it proves the clear is
    written, not that it runs. A behavioural version needs a fully wired
    Player (runtimes, camera, readouts), and a bare one raises inside
    `bind_player` before reaching the assertion. Worth revisiting if a
    Player fixture ever exists.
    """
    hud = (Path(__file__).resolve().parents[2] / "godot"
           / "scripts" / "ui" / "hud.gd").read_text()
    body = hud.split("func bind_player(")[1].split("\nfunc ")[0]
    assert '_on_prompt("")' in body, (
        "bind_player no longer clears the prompt, so a stale one from the "
        "previous world survives the transition")


# --- CS7: only implemented activities may be named ------------------------

ACTIVITIES_GD = (Path(__file__).resolve().parents[2] / "godot" / "scripts"
                 / "generation" / "activities.gd")
ACTIVITY_RUNTIME_GD = (Path(__file__).resolve().parents[2] / "godot"
                       / "scripts" / "gameplay" / "activity_runtime.gd")
ACTIVITY_DRIVER_GD = (Path(__file__).resolve().parents[2] / "godot" / "tests"
                      / "activity_driver.gd")


def _activity_kinds() -> list[str]:
    """The schema's vocabulary, read from the model rather than retyped."""
    from archipepsi_bridge.schemas.zone import ActivityKind
    return list(ActivityKind.__args__)


def _rule_kinds() -> set[str]:
    """The kinds `ActivityRuntime.RULES` configures, read from source."""
    source = ACTIVITY_RUNTIME_GD.read_text()
    body = source[source.index("const RULES :="):]
    body = body[:body.index("\n}")]
    return set(re.findall(r'^\t"([a-z_]+)"\s*:', body, re.MULTILINE))


def test_the_engine_builds_every_activity_the_schema_admits():
    """"Do not count an unimplemented puzzle tag toward room_value."

    WHAT THIS TEST USED TO BE, and why it moved. It read
    `activities.gd` as TEXT and asserted every schema kind appeared in
    it, which proved a `match` branch existed. That was the right
    question while the seam was geometry. It was not the right question
    once the branch could build an inert box and return, which is what
    all four branches did: the guard was green over a Zone where 57.7%
    of the content value was scenery, and its NAME read as though it
    guarded the puzzle.

    So the source-level half now pins the schema to the RULES TABLE,
    which is where a family's behaviour is configured, and
    `test_every_activity_kind_is_driven_to_completion_somewhere` below
    is the half that costs something to fake.
    """
    missing = sorted(set(_activity_kinds()) - _rule_kinds())
    assert not missing, (
        "the schema admits activity kinds the engine has no rules for, so "
        "a Zone could name one and score for it while the room comes out "
        "empty: " + ", ".join(missing))


def test_the_engine_does_not_build_an_activity_the_schema_refuses():
    """The mirror. A rule for a kind nobody can request is dead code
    that reads as a supported feature."""
    stray = sorted(_rule_kinds() - set(_activity_kinds()))
    assert not stray, (
        "the engine configures activities the schema cannot express: "
        + ", ".join(stray))


def test_every_activity_kind_is_driven_to_completion_somewhere():
    """The half the source-grep could not do.

    Still a source-level check -- Python cannot run Godot -- but it pins
    a DIFFERENT thing: that the behavioural suite iterates the whole
    rules table rather than spot-checking one family, and that CI runs
    it. `make godot-activity` is what actually drives each family to
    completion and to failure; this is what stops that suite from
    quietly narrowing to the one kind somebody was debugging.
    """
    driver = ACTIVITY_DRIVER_GD.read_text()
    assert "for kind: String in ActivityRuntime.RULES" in driver, (
        "the activity suite no longer sweeps the whole rules table, so a "
        "family could stop working without failing anything")
    for expected in ("_test_every_kind_can_actually_be_finished",
                     "_test_an_untouched_activity_never_completes",
                     "_test_n_minus_one_is_not_n"):
        assert expected in driver, f"{expected} is gone from the suite"


def test_the_activity_pin_can_actually_see_the_builder():
    """Vacuity guard: an empty file would satisfy the mirror above and a
    missing file would make the first test pass for the wrong reason."""
    assert ACTIVITIES_GD.is_file(), ACTIVITIES_GD
    assert ACTIVITY_RUNTIME_GD.is_file(), ACTIVITY_RUNTIME_GD
    assert ACTIVITY_DRIVER_GD.is_file(), ACTIVITY_DRIVER_GD
    assert len(_rule_kinds()) >= 4, "the rules table shrank unnoticed"
    assert len(_activity_kinds()) >= 4, "the vocabulary shrank unnoticed"
    # The builder still has to reach the runtime, or the rules table is a
    # table nothing consults.
    assert "ActivityRuntime.create" in ACTIVITIES_GD.read_text(), (
        "the builder no longer creates a runtime")
