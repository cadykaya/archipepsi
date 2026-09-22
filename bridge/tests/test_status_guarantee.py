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
    assert "anchored" in named and "anchored" not in supported
    assert "exposed" in named, "the Amalgam's thirteenth is missing"
    # And support may never name something the vocabulary does not.
    assert supported <= named


def test_lightened_crossed_from_named_to_supported_on_one_target():
    """THE FIRST CROSSING, and the shape every later one must take.

    `lightened` stood here as the example of named-and-unsupported until
    the engine implemented it on an object — mass class down one step,
    incoming impulse doubled, influence volumes reaching it, and
    manipulation eligibility reading the class. It crossed in the change
    that landed those effects, which is this table's own rule working.

    What must NOT travel with it is the other four targets. `lightened`
    on an actor, a surface or a volume is three different unbuilt
    runtimes, and a kind that works on one target is not thereby working
    on another — so the crossing is ONE cell, not a row.
    """
    assert E.SUPPORTED_STATUS_TARGETS["lightened"] == ("object",)
    E.StatusComponent.model_validate(_component("lightened", "object"))
    for target in ("self", "enemy", "surface", "volume"):
        with pytest.raises(ValidationError,
                           match="not implemented for target"):
            E.StatusComponent.model_validate(_component("lightened", target))
    # And the on-hit door asks about an ENEMY, so it still refuses it.
    with pytest.raises(ValidationError, match="not implemented for target"):
        E.ApplyStatusOnHit.model_validate({
            "type": "apply_status_on_hit", "status": "lightened",
            "duration": 2.0, "magnitude": 0.5})


def test_vulnerable_is_declared_on_both_sides_because_both_implement_it():
    """DECLARED TO MATCH THE RUNTIME, not the other way about.

    This read `("enemy",)` while `stat_stack.gd:93` multiplied the
    PLAYER's `damage_taken` by it and `enemy.gd:434` multiplied the
    enemy's. The under-declaration was invisible while the engine asked
    about support per KIND; asking per TARGET turned `godot-stats` red on
    three cases, including the cleanse order's own "`vulnerable`, which
    the player does suffer". A target the runtime implements may not be
    refused, exactly as one it does not implement may not be allowed.
    """
    assert E.SUPPORTED_STATUS_TARGETS["vulnerable"] == ("self", "enemy")
    E.StatusComponent.model_validate(_component("vulnerable", "self"))
    E.StatusComponent.model_validate(_component("vulnerable", "enemy"))


#: DERIVED, NOT TRANSCRIBED — the same lesson `test_the_on_hit_list_...`
#: below already learned. Written by hand, this list named `lightened`,
#: and the day `lightened` gained an effect the list went on asserting it
#: had none: a test that fails for being out of date rather than for
#: finding anything. Derived, a kind leaves this sweep at exactly the
#: moment it stops belonging in it.
_NAMED_ONLY = sorted(set(E.STATUS_KINDS) - set(E.IMPLEMENTED_STATUS_KINDS))


def test_the_sweep_below_is_not_empty():
    """A derived parametrize list that came out empty would pass by
    running nothing at all, which is the failure mode of deriving."""
    assert len(_NAMED_ONLY) >= 10, _NAMED_ONLY


@pytest.mark.parametrize("kind", _NAMED_ONLY)
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
    # THE EXPECTATION IS DERIVED TOO, and it had to become so: the
    # hand-written eight was the last transcription of the vocabulary,
    # and it went stale the moment `empowered` gained `enemy` support --
    # which is the beacon buffing its allies, exactly what that role is
    # for. A test that transcribes what it is checking is the defect it
    # was written to catch.
    expected = [kind for kind in E.STATUS_KINDS
                if "enemy" in E.SUPPORTED_STATUS_TARGETS.get(kind, ())]
    assert admitted == expected
    assert "burning" in admitted and "vulnerable" in admitted


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


def test_the_engine_is_told_which_targets_each_kind_supports():
    """The kind list cannot answer target applicability.

    A boundary guarding on `ECHO_STATUS_KINDS_IMPLEMENTED` alone admits
    `lightened` on a surface the moment `lightened` works on an object.
    The map is what lets the Godot boundary refuse the PAIR.
    """
    from pathlib import Path
    import re
    gd = Path("godot/scripts/autoload/constants.gd").read_text()
    line = next(l for l in gd.split("\n")
                if l.startswith("const ECHO_STATUS_SUPPORTED_TARGETS"))
    for kind, targets in E.SUPPORTED_STATUS_TARGETS.items():
        assert f'"{kind}": [' in line, f"{kind} missing from the exported map"
        for target in targets:
            assert f'"{target}"' in line
    # and nothing unsupported is advertised as supported anywhere in it
    for kind in set(E.STATUS_KINDS) - set(E.IMPLEMENTED_STATUS_KINDS):
        assert f'"{kind}": [' not in line, (
            f"{kind} is advertised as supported and is not")


# --------------------------------------------------------------------------
# P10.5 — the compact matrix, and the count that was hiding a family.
# --------------------------------------------------------------------------

def test_the_supported_thirteen_are_not_the_amalgams_thirteen():
    """THE COUNT MATCHED BY COINCIDENCE.

    `SUPPORTED_STATUS_TARGETS` has thirteen entries and Amalgam §15.2's
    family has thirteen members, and reading the first number as the
    second is exactly what P10.5 means by *"a fixed catalogue count must
    never hide an incomplete family"*. Eleven of the supported kinds are
    retained ECHOES vocabulary; only two are §15.2 Statuses.
    """
    family = set(E.AMALGAM_STATUS_TARGETS)
    supported = set(E.SUPPORTED_STATUS_TARGETS)
    assert len(family) == len(supported) == 13
    assert family & supported == {"lightened", "burning"}


def test_no_status_in_the_family_is_finished_yet_and_the_gaps_are_named():
    """The matrix, as an assertion rather than a report.

    This is expected to CHANGE as Prod lands adapters, and changing it
    is the point: each row that empties is a row that closed. What it
    refuses is a silent regression and a quiet claim of completeness.
    """
    gaps = E.amalgam_status_coverage()
    assert set(gaps) == set(E.AMALGAM_STATUS_TARGETS)

    finished = sorted(k for k, missing in gaps.items() if not missing)
    assert finished == [], (
        f"{finished} now cover every §15.2 target -- update this control "
        "to record the progress rather than deleting it")

    # The two with partial support, named exactly. `lightened` crossed on
    # `object` (D-7) and `burning` predates the family as an on-hit kind.
    assert gaps["lightened"] == ("enemy", "self")
    assert gaps["burning"] == ("object", "surface", "volume")

    no_support = sorted(k for k in gaps
                        if k not in E.SUPPORTED_STATUS_TARGETS)
    assert len(no_support) == 11


def test_brittle_never_admits_an_actor_target():
    """Law 27's protection, in the catalogue rather than in prose.

    `brittle` is the one Status that touches a damage number and it is
    object-and-surface only -- things that are destroyed rather than
    killed. A row that admitted an actor would put a damage multiplier
    on a combatant, which is what §15.3 rule 2 exists to forbid.
    """
    assert set(E.AMALGAM_STATUS_TARGETS["brittle"]) == {"object", "surface"}
    assert "enemy" not in E.AMALGAM_STATUS_TARGETS["brittle"]
    assert "self" not in E.AMALGAM_STATUS_TARGETS["brittle"]


def test_exposed_is_actor_only_because_objects_have_no_defense_stat():
    """§15.2's own correction. An earlier revision listed `exposed` as
    actor and object; objects resolve through the destructible classes
    and have no Defense curve, so an object row would have silently
    invented a field."""
    assert E.AMALGAM_STATUS_TARGETS["exposed"] == ("enemy",)


def test_the_target_translation_is_declared_and_not_assumed():
    """P09.4: *"self is not automatically every player/actor target."*

    Design 5 writes actor/player; the runtime kinds are enemy/self. A
    row listing only `actor` must not acquire `self` on the way in --
    `confused` is the case, and it is a cognitive effect on an NPC.
    """
    assert E.AMALGAM_STATUS_TARGETS["confused"] == ("enemy",)
    assert "self" not in E.AMALGAM_STATUS_TARGETS["blinded"]
    # and a row listing BOTH gets both
    assert {"enemy", "self"} <= set(E.AMALGAM_STATUS_TARGETS["lightened"])
