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
