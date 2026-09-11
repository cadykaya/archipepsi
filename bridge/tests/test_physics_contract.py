"""The physics contract, written before the physics.

Nothing here can be executed: zero `RigidBody3D` in the project. What
these prove is that the RULES are decidable and already refuse the
things they will have to refuse — so the day a runtime lands, what it
has to satisfy is written down and tested rather than invented under
pressure to make a demo work.
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from archipepsi_bridge.schemas import physics as P


def _latch(i: int, detail: str = "") -> P.LatchCondition:
    return P.LatchCondition(latch_id=f"l{i}", kind="CONSTRAINT_STATE",
                            detail=detail)


def _setup(mass: float = 80.0, iterations: int = 8) -> P.PhysicsSetup:
    return P.PhysicsSetup(
        bodies=(P.BodySpec(body_id="crate_a", mass_kg=mass),),
        solver=P.SolverConfig(iterations=iterations, fixed_step_hz=60.0,
                              settle_timeout_s=8.0))


def _package(package_id: str = "p", *, latches=None, promote=(0,),
             detail: str = "", mass: float = 80.0,
             iterations: int = 8, steps=("push_crate",),
             evidence=None) -> P.PhysicsPackage:
    return P.PhysicsPackage(
        package_id=package_id,
        latch_conditions=latches if latches is not None
        else (_latch(0, detail),),
        vector_latches=tuple(promote),
        setup=_setup(mass, iterations),
        reference_solution=P.ReferenceSolution(steps=tuple(steps)),
        evidence=evidence)


def _proved(pkg: P.PhysicsPackage, *, runs: int = 3,
            force: float = P.ENVELOPE_FORCE_N,
            latched=None) -> P.PhysicsPackage:
    """The same package, carrying evidence that proves it."""
    ids = tuple(c.latch_id for c in pkg.promoted) if latched is None \
        else tuple(latched)
    ev = P.ReplayEvidence(
        package_id=pkg.package_id,
        content_digest=P.package_digest(pkg),
        provider_force_n=force, provider_range_m=P.ENVELOPE_RANGE_M,
        provider_mass_kg=P.ENVELOPE_MASS_KG,
        per_run_latched=tuple(ids for _ in range(runs)))
    return pkg.model_copy(update={"evidence": ev})


# --- identity and qualification are different questions -------------------

def test_identity_is_a_boolean_and_nothing_else():
    """The verifier sees one Boolean. A newton in it is the failure."""
    assert P.grants_manipulate(["PUSH"]) is True
    assert P.grants_manipulate(["pull"]) is True
    assert P.grants_manipulate(["HOLD", "ROTATE"]) is True
    assert P.grants_manipulate(["ROTATE", "ALIGN", "TETHER"]) is False
    assert P.grants_manipulate([]) is False
    assert isinstance(P.grants_manipulate(["PUSH"]), bool)


def test_a_sub_envelope_host_still_grants_the_capability():
    """A weak PUSH is real content. It manipulates, it solves optional
    routes, it is composable — it simply is not the guarantee."""
    weak = P.ProviderEnvelope(force_n=120.0, range_m=4.0,
                              mass_limit_kg=30.0)
    assert P.grants_manipulate(["PUSH"]) is True
    assert weak.qualifies is False


def test_the_envelope_needs_all_three():
    """Two of three is not a guarantee: a puzzle authored at the envelope
    can need the reach and the force and the mass in one motion."""
    base = dict(force_n=P.ENVELOPE_FORCE_N, range_m=P.ENVELOPE_RANGE_M,
                mass_limit_kg=P.ENVELOPE_MASS_KG)
    assert P.ProviderEnvelope(**base).qualifies
    for field, under in (("force_n", 699.9), ("range_m", 19.9),
                         ("mass_limit_kg", 119.9)):
        assert not P.ProviderEnvelope(**{**base, field: under}).qualifies


def test_a_refused_player_is_told_which_minimum_they_miss():
    weak = P.ProviderEnvelope(force_n=400.0, range_m=8.0,
                              mass_limit_kg=120.0)
    said = " ".join(weak.shortfall())
    assert "force" in said and "range" in said
    assert "mass" not in said, "only the ones actually missed"


def test_qualification_counts_only_qualifying_providers():
    hosts = [P.ProviderEnvelope(force_n=700.0, range_m=20.0,
                                mass_limit_kg=120.0),
             P.ProviderEnvelope(force_n=200.0, range_m=20.0,
                                mass_limit_kg=120.0),
             P.ProviderEnvelope(force_n=900.0, range_m=25.0,
                                mass_limit_kg=200.0)]
    assert P.qualifying_providers(hosts) == (0, 2)


# --- latches, and the budget they compete for -----------------------------

def test_a_promoted_latch_must_exist():
    with pytest.raises(ValidationError, match="promotes latch index"):
        P.PhysicsPackage(package_id="p", latch_conditions=(_latch(0),),
                         vector_latches=(3,))


def test_the_same_latch_cannot_be_promoted_twice():
    with pytest.raises(ValidationError, match="same latch twice"):
        P.PhysicsPackage(package_id="p",
                         latch_conditions=(_latch(0), _latch(1)),
                         vector_latches=(0, 0))


def test_the_worked_allocation_lands_exactly_on_the_bound():
    """§4.10's own table: 3 macro variables at 4, 2 keys, 4 latches."""
    assert P.state_vector_product(
        macro_variables=(4, 4, 4), local_keys=2,
        physics_latches=4) == P.STATE_VECTOR_BOUND


def test_latches_and_macro_variables_compete_for_one_budget():
    """A Zone wanting eight macro variables gets very few latches."""
    pkg = _proved(_package(latches=tuple(_latch(i) for i in range(5)),
                           promote=(0, 1, 2, 3, 4)))
    errors = P.check_physics_content(
        [pkg], macro_variables=(4, 4, 4), local_keys=2)
    assert any("past the 4096 bound" in e or "4096 bound" in e
               for e in errors), errors


def test_more_than_eight_promoted_latches_is_refused():
    pkgs = [_proved(_package(f"p{i}", latches=(_latch(0), _latch(1)),
                             promote=(0, 1))) for i in range(5)]
    errors = P.check_physics_content(pkgs)
    assert any("past the 8" in e for e in errors), errors


# --- latch identity -------------------------------------------------------

def test_a_latch_id_is_unique_within_its_package():
    """Two conditions sharing a name are indistinguishable downstream."""
    with pytest.raises(ValidationError, match="more than once"):
        P.PhysicsPackage(
            package_id="p",
            latch_conditions=(
                P.LatchCondition(latch_id="same", kind="CONSTRAINT_STATE",
                                 detail="the bridge falls"),
                P.LatchCondition(latch_id="same", kind="WEIGHT_THRESHOLD",
                                 detail="the plate holds")))


def test_a_latch_is_identified_by_package_and_name():
    """Two packages may both call a latch `bridge_down`."""
    assert P.latch_ref("alpha", "bridge_down") \
        != P.latch_ref("beta", "bridge_down")
    a = _proved(_package("alpha", latches=(
        P.LatchCondition(latch_id="bridge_down", kind="CONSTRAINT_STATE"),)))
    b = _proved(_package("beta", latches=(
        P.LatchCondition(latch_id="bridge_down", kind="CONSTRAINT_STATE"),)))
    assert P.check_physics_content([a, b]) == ()


def test_two_packages_sharing_an_id_are_refused():
    a = _proved(_package("dup"))
    b = _proved(_package("dup"))
    assert any("share the id" in e for e in P.check_physics_content([a, b]))


# --- THE EVIDENCE GATE ----------------------------------------------------
#
# The part that matters. A latch the verifier reasons about is a
# progression gate, and accepting one on a declaration — or on a record
# that was true of something else — would be trusting a physical claim
# nobody has measured.

def test_a_promoted_latch_without_evidence_is_refused():
    assert any("carries no replay evidence" in e
               for e in P.check_physics_content([_package()]))


def test_a_mandatory_route_package_without_evidence_is_refused():
    pkg = _package(promote=()).model_copy(
        update={"on_mandatory_route": True})
    assert any("carries no replay evidence" in e
               for e in P.check_physics_content([pkg]))


def test_evidence_copied_from_another_package_is_refused():
    """Codex's case. A replay proves something about the thing it
    replayed and nothing about anything else."""
    source = _proved(_package("alpha"))
    target = _package("beta", latches=(_latch(0, "a different job"),))
    borrowed = target.model_copy(update={"evidence": source.evidence})
    errors = P.check_physics_content([borrowed])
    assert any("recorded for 'alpha'" in e for e in errors), errors


def test_evidence_copied_with_the_package_id_patched_is_still_refused():
    """Renaming the record does not make it about this content."""
    source = _proved(_package("alpha"))
    target = _package("beta", latches=(_latch(0, "a different job"),))
    faked = target.model_copy(update={"evidence": source.evidence.model_copy(
        update={"package_id": "beta"})})
    errors = P.check_physics_content([faked])
    assert any("has changed since its replay" in e for e in errors), errors


@pytest.mark.parametrize("change", [
    {"detail": "the bridge now falls the other way"},
    {"mass": 200.0},
    {"iterations": 16},
    {"steps": ("push_crate", "and_again")},
])
def test_changing_what_was_replayed_makes_the_evidence_stale(change):
    """Conditions, bodies, solver settings and the solution are all in
    the digest, because changing any changes what a replay proves."""
    original = _proved(_package())
    edited = _package(**change).model_copy(
        update={"evidence": original.evidence})
    errors = P.check_physics_content([edited])
    assert any("has changed since its replay" in e for e in errors), errors


def test_changing_which_latch_is_promoted_makes_the_evidence_stale():
    original = _proved(_package(latches=(_latch(0), _latch(1)),
                                promote=(0,)))
    repromoted = original.model_copy(update={"vector_latches": (1,)})
    assert any("has changed since its replay" in e
               for e in P.check_physics_content([repromoted]))


def test_evidence_from_a_strong_provider_does_not_prove_solvability():
    """Replaying above the envelope proves a strong provider can solve
    it, which is not the claim check 20 makes."""
    pkg = _proved(_package(), force=2000.0)
    assert any("not at the envelope" in e
               for e in P.check_physics_content([pkg]))


def test_two_runs_are_not_three():
    pkg = _proved(_package(), runs=2)
    assert any("replay run(s); check 20 replays three" in e
               for e in P.check_physics_content([pkg]))


def test_three_runs_each_latching_a_different_part_is_not_three_successes():
    """A union would have called this a pass."""
    pkg = _package(latches=(_latch(0), _latch(1), _latch(2)),
                   promote=(0, 1, 2))
    ev = P.ReplayEvidence(
        package_id=pkg.package_id, content_digest=P.package_digest(pkg),
        provider_force_n=P.ENVELOPE_FORCE_N,
        provider_range_m=P.ENVELOPE_RANGE_M,
        provider_mass_kg=P.ENVELOPE_MASS_KG,
        per_run_latched=(("l0",), ("l1",), ("l2",)))
    errors = P.check_physics_content([pkg.model_copy(
        update={"evidence": ev})])
    assert any("did not latch in every run" in e for e in errors), errors


def test_evidence_that_never_latched_the_promoted_latch_is_refused():
    pkg = _package(latches=(_latch(0), _latch(1)), promote=(1,))
    proved = _proved(pkg, latched=("l0",))
    assert any("did not latch in every run" in e
               for e in P.check_physics_content([proved]))


# --- the controls, so the gate is passable rather than a wall -------------

def test_a_fully_proved_package_is_accepted():
    assert P.check_physics_content([_proved(_package())]) == ()


def test_a_fully_proved_mandatory_route_package_is_accepted():
    pkg = _package().model_copy(update={"on_mandatory_route": True})
    assert P.check_physics_content([_proved(pkg)]) == ()


def test_several_proved_packages_are_accepted_together():
    pkgs = [_proved(_package(f"p{i}")) for i in range(4)]
    assert P.check_physics_content(pkgs) == ()


def test_an_optional_latch_needs_no_evidence():
    """A latch nothing on a mandatory route depends on still latches; it
    is simply not something the verifier spends budget on."""
    assert P.check_physics_content([_package(promote=())]) == ()


def test_re_replaying_after_a_change_accepts_again():
    """Staleness is about freshness, not about never editing anything."""
    edited = _package(detail="the bridge now falls the other way")
    assert P.check_physics_content([_proved(edited)]) == ()


def test_today_every_load_bearing_package_is_refused():
    """The honest current state, asserted so it cannot drift quietly.

    No physics runtime exists, so no engine can produce replay evidence,
    so every package the verifier would reason about is refused. When
    that stops being true it will be because a runtime landed, and this
    test is where that shows up.
    """
    assert P.check_physics_content([_package()]), (
        "with no runtime there is no evidence, and no evidence is a "
        "refusal rather than a pending acceptance")
