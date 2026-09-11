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


def _latch(i: int) -> P.LatchCondition:
    return P.LatchCondition(latch_id=f"l{i}", kind="CONSTRAINT_STATE")


def _good_evidence(ids=("l0",)) -> P.ReplayEvidence:
    return P.ReplayEvidence(
        runs=3, latched=3,
        provider_force_n=P.ENVELOPE_FORCE_N,
        provider_range_m=P.ENVELOPE_RANGE_M,
        provider_mass_kg=P.ENVELOPE_MASS_KG,
        latched_ids=tuple(ids))


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
    pkg = P.PhysicsPackage(
        package_id="p",
        latch_conditions=tuple(_latch(i) for i in range(5)),
        vector_latches=(0, 1, 2, 3, 4),
        evidence=_good_evidence([f"l{i}" for i in range(5)]))
    errors = P.check_physics_content(
        [pkg], macro_variables=(4, 4, 4), local_keys=2)
    assert any("past the 4096 bound" in e or "4096 bound" in e
               for e in errors), errors


def test_more_than_eight_promoted_latches_is_refused():
    pkgs = [P.PhysicsPackage(
        package_id=f"p{i}", latch_conditions=(_latch(0), _latch(1)),
        vector_latches=(0, 1),
        evidence=_good_evidence(["l0", "l1"])) for i in range(5)]
    errors = P.check_physics_content(pkgs)
    assert any("past the 8" in e for e in errors), errors


# --- THE EVIDENCE GATE ----------------------------------------------------
#
# The part that matters. A latch the verifier reasons about is a
# progression gate, and accepting one on a declaration would be trusting
# a physical claim nobody has measured.

def test_a_promoted_latch_without_evidence_is_refused():
    pkg = P.PhysicsPackage(package_id="p",
                           latch_conditions=(_latch(0),),
                           vector_latches=(0,))
    errors = P.check_physics_content([pkg])
    assert any("carries no replay evidence" in e for e in errors), errors


def test_a_mandatory_route_package_without_evidence_is_refused():
    pkg = P.PhysicsPackage(package_id="p",
                           latch_conditions=(_latch(0),),
                           on_mandatory_route=True)
    assert any("carries no replay evidence" in e
               for e in P.check_physics_content([pkg]))


def test_evidence_from_a_strong_provider_does_not_prove_solvability():
    """Replaying above the envelope proves a strong provider can solve
    it, which is not the claim check 20 makes."""
    strong = P.ReplayEvidence(runs=3, latched=3, provider_force_n=2000.0,
                              provider_range_m=40.0,
                              provider_mass_kg=400.0,
                              latched_ids=("l0",))
    pkg = P.PhysicsPackage(package_id="p", latch_conditions=(_latch(0),),
                           vector_latches=(0,), evidence=strong)
    assert any("does not prove solvability at the envelope" in e
               for e in P.check_physics_content([pkg]))


def test_two_of_three_runs_latching_is_not_evidence():
    shaky = P.ReplayEvidence(runs=3, latched=2,
                             provider_force_n=P.ENVELOPE_FORCE_N,
                             provider_range_m=P.ENVELOPE_RANGE_M,
                             provider_mass_kg=P.ENVELOPE_MASS_KG,
                             latched_ids=("l0",))
    pkg = P.PhysicsPackage(package_id="p", latch_conditions=(_latch(0),),
                           vector_latches=(0,), evidence=shaky)
    assert any("does not prove solvability" in e
               for e in P.check_physics_content([pkg]))


def test_evidence_that_never_latched_the_promoted_latch_is_refused():
    """Three green runs that latched something ELSE."""
    pkg = P.PhysicsPackage(
        package_id="p", latch_conditions=(_latch(0), _latch(1)),
        vector_latches=(1,), evidence=_good_evidence(["l0"]))
    assert any("its own replay never latched" in e
               for e in P.check_physics_content([pkg]))


def test_evidence_cannot_claim_more_latched_runs_than_runs():
    with pytest.raises(ValidationError, match="latched runs out of"):
        P.ReplayEvidence(runs=3, latched=4, provider_force_n=700.0,
                         provider_range_m=20.0, provider_mass_kg=120.0)


def test_a_fully_proved_package_is_accepted():
    """The control. The gate must be passable or it is just a wall."""
    pkg = P.PhysicsPackage(package_id="p", latch_conditions=(_latch(0),),
                           vector_latches=(0,), on_mandatory_route=True,
                           evidence=_good_evidence(["l0"]))
    assert P.check_physics_content([pkg]) == ()


def test_an_optional_latch_needs_no_evidence():
    """A latch nothing on a mandatory route depends on still latches; it
    is simply not something the verifier spends budget on."""
    pkg = P.PhysicsPackage(package_id="p", latch_conditions=(_latch(0),))
    assert P.check_physics_content([pkg]) == ()


def test_today_every_load_bearing_package_is_refused():
    """The honest current state, asserted so it cannot drift quietly.

    No physics runtime exists, so no engine can produce replay evidence,
    so every package the verifier would reason about is refused. When
    that stops being true it will be because a runtime landed, and this
    test is where that shows up.
    """
    pkg = P.PhysicsPackage(package_id="p", latch_conditions=(_latch(0),),
                           vector_latches=(0,))
    assert P.check_physics_content([pkg]), (
        "with no runtime there is no evidence, and no evidence is a "
        "refusal rather than a pending acceptance")
