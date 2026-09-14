"""The physics contract, and the day a runtime landed.

This opened "nothing here can be executed: zero `RigidBody3D` in the
project", and that was true until 2026-09-12. The engine now has
`ManipulableBody` and `Manipulation` and `make godot-physics` measures
them, so the rules below have something to be rules ABOUT.

What is still true: nothing in THIS file executes a body. These prove
the rules are decidable and already refuse what they will have to
refuse, plus — at the end — that the two lanes agree about the numbers,
which is the only part of the contract Python can check on its own.
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from archipepsi_bridge.schemas import physics as P


def _latch(i: int, detail: str = "") -> P.LatchCondition:
    return P.LatchCondition(latch_id=f"l{i}", kind="CONSTRAINT_STATE",
                            detail=detail)


def _setup(mass: float = 80.0, iterations: int = 8,
           scene: str = "0123456789abcdef") -> P.PhysicsSetup:
    return P.PhysicsSetup(
        bodies=(P.BodySpec(body_id="crate_a", mass_kg=mass),),
        solver=P.SolverConfig(iterations=iterations, fixed_step_hz=60.0,
                              settle_timeout_s=8.0),
        scene_digest=scene)


def _package(package_id: str = "p", *, latches=None, promote=(0,),
             required=None, detail: str = "", mass: float = 80.0,
             iterations: int = 8, scene: str = "0123456789abcdef",
             steps=("push_crate",), setup=..., solution=...,
             mandatory: bool = False,
             evidence=None) -> P.PhysicsPackage:
    conditions = latches if latches is not None else (_latch(0, detail),)
    promoted_ids = [conditions[i].latch_id for i in promote]
    return P.PhysicsPackage(
        package_id=package_id,
        latch_conditions=conditions,
        vector_latches=tuple(promote),
        required_latches=tuple(promoted_ids if required is None
                               else required),
        on_mandatory_route=mandatory,
        setup=_setup(mass, iterations, scene) if setup is ... else setup,
        reference_solution=(P.ReferenceSolution(steps=tuple(steps))
                            if solution is ... else solution),
        evidence=evidence)


def _proved(pkg: P.PhysicsPackage, *, runs: int = 3,
            force: float = P.ENVELOPE_FORCE_N,
            latched=None) -> P.PhysicsPackage:
    """The same package, carrying evidence that proves it."""
    ids = tuple(c.latch_id for c in pkg.latch_conditions) \
        if latched is None else tuple(latched)
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
    """A required latch, a real setup, a real solution — and no proof."""
    pkg = _package(mandatory=True)
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


# --- A PROOF OF NOTHING IS NOT A PROOF ------------------------------------
#
# Three green runs against no setup, no solution, or no required outcome
# are three runs of nothing — and a digest over `null` is a perfectly
# consistent digest of an absence.

def test_a_promoted_latch_with_no_setup_is_refused():
    pkg = _proved(_package(setup=None))
    errors = P.check_physics_content([pkg])
    assert any("no physical setup" in e for e in errors), errors


def test_a_promoted_latch_with_no_reference_solution_is_refused():
    pkg = _proved(_package(solution=None))
    assert any("no reference solution" in e
               for e in P.check_physics_content([pkg]))


def test_a_setup_with_no_bodies_is_refused():
    empty = P.PhysicsSetup(
        bodies=(), solver=P.SolverConfig(iterations=8, fixed_step_hz=60.0,
                                         settle_timeout_s=8.0),
        scene_digest="0123456789abcdef")
    assert any("no physical setup" in e
               for e in P.check_physics_content([_proved(_package(setup=empty))]))


def test_a_solution_with_no_steps_is_refused():
    assert any("no reference solution" in e
               for e in P.check_physics_content(
                   [_proved(_package(steps=()))]))


def test_a_mandatory_route_with_no_required_latch_is_refused():
    """Codex's second case. A route that depends on nothing in
    particular cannot be proved passable."""
    pkg = P.PhysicsPackage(package_id="p", on_mandatory_route=True,
                           setup=_setup(),
                           reference_solution=P.ReferenceSolution(
                               steps=("push_crate",)))
    ev = P.ReplayEvidence(
        package_id="p", content_digest=P.package_digest(pkg),
        provider_force_n=P.ENVELOPE_FORCE_N,
        provider_range_m=P.ENVELOPE_RANGE_M,
        provider_mass_kg=P.ENVELOPE_MASS_KG,
        per_run_latched=((), (), ()))
    errors = P.check_physics_content([pkg.model_copy(
        update={"evidence": ev})])
    assert any("names no required latch" in e for e in errors), errors


def test_a_load_bearing_package_with_no_latch_condition_is_refused():
    pkg = P.PhysicsPackage(package_id="p", on_mandatory_route=True,
                           required_latches=(), setup=_setup(),
                           reference_solution=P.ReferenceSolution(
                               steps=("push",)))
    assert P.check_physics_content([pkg])


# --- required outcomes and promoted latches are different things ----------

def test_a_required_latch_must_be_declared():
    with pytest.raises(ValidationError, match="does not declare"):
        P.PhysicsPackage(package_id="p", latch_conditions=(_latch(0),),
                         vector_latches=(0,),
                         required_latches=("nonexistent",))


def test_a_required_latch_must_also_be_promoted():
    """§23.1: a latch left out of `vector_latches` is one nothing on a
    mandatory route depends on. Required therefore implies promoted."""
    with pytest.raises(ValidationError, match="without promoting them"):
        P.PhysicsPackage(package_id="p",
                         latch_conditions=(_latch(0), _latch(1)),
                         vector_latches=(0,),
                         required_latches=("l1",))


def test_a_promoted_latch_need_not_be_required():
    """The distinction, from the other side: a latch the verifier
    reasons about because it opens a shortcut."""
    pkg = _package(latches=(_latch(0), _latch(1)), promote=(0, 1),
                   required=("l0",))
    assert P.check_physics_content([_proved(pkg)]) == ()


# --- the scene is part of what was replayed -------------------------------

def test_moving_the_scene_invalidates_the_evidence():
    """Body id, mass and constrained-ness are what the CONTRACT reasons
    about. Collision geometry and initial placement are not, and a
    solution that latched before the crate moved is not evidence about
    the room as it now stands."""
    original = _proved(_package())
    moved = _package(scene="fedcba9876543210").model_copy(
        update={"evidence": original.evidence})
    assert any("has changed since its replay" in e
               for e in P.check_physics_content([moved]))


def test_re_replaying_in_the_moved_scene_accepts_again():
    assert P.check_physics_content(
        [_proved(_package(scene="fedcba9876543210"))]) == ()


# --- one recipe, two languages --------------------------------------------

def _vectors():
    import json
    from pathlib import Path
    path = (Path(__file__).resolve().parents[2] / "godot" / "tests"
            / "fixtures" / "physics_digest_vectors.json")
    return json.loads(path.read_text(encoding="utf-8"))


def test_the_shared_vectors_run_through_the_production_serializer():
    """Construct from `package`, then compare BYTES and digest.

    Hashing the stored `canonical` string would prove the file is
    self-consistent and nothing about the code — the serializer could
    drift and every vector would still pass. Comparing the canonical
    bytes as well as the hash is also what tells a cross-language
    mismatch apart: differing bytes is a construction difference,
    matching bytes with a differing hash is a hashing one.
    """
    data = _vectors()
    assert data["vectors"], "the shared vectors must not be empty"
    for v in data["vectors"]:
        pkg = P.PhysicsPackage.model_validate(v["package"])
        got_bytes = P.canonical_bytes(pkg).decode("utf-8")
        assert got_bytes == v["canonical"], (
            f"{v['name']}: the production serializer no longer produces "
            "the canonical string this vector records")
        assert P.package_digest(pkg) == v["digest"], v["name"]


def test_the_vectors_cover_things_that_must_and_must_not_change_it():
    """A vector set where everything hashes the same proves nothing, and
    so does one where everything differs."""
    by_name = {v["name"]: v for v in _vectors()["vectors"]}
    base = by_name["a fully specified load-bearing package"]["digest"]

    # Same content, declared differently: the digest must NOT move.
    for name in ("integral floats, which must not print as integers",
                 "declaration order that differs from canonical order"):
        assert by_name[name]["digest"] == base, (
            f"{name}: input formatting reached the output")

    # Different content: the digest MUST move.
    for name in ("the same package with a moved scene",
                 "empty: no setup, no solution, no latches",
                 "unicode and punctuation in a detail"):
        assert by_name[name]["digest"] != base, name

    # The two sequences in the canonical form are treated OPPOSITELY,
    # and with one entry each the difference is invisible. These three
    # vectors carry several, which is what makes `sorted()` on one and
    # `list()` on the other load-bearing rather than interchangeable.
    multi = by_name[
        "several requirements and promotions, declared out of order"]["digest"]
    assert by_name["the same requirements, declared already sorted"][
        "digest"] == multi, (
        "required_latches is a SET of names: two declarations of the "
        "same set must canonicalize the same")
    assert by_name["the same latches promoted in a different bit order"][
        "digest"] != multi, (
        "vector_latches is the state vector's BIT ORDER, so it is "
        "content: sorting it would silently renumber the verifier's "
        "dimensions and this vector would stop noticing")


def test_there_is_one_canonicalization_in_this_language():
    """`package_digest` hashes `canonical_bytes` and does not re-serialize.

    Two implementations in one language is how the two stop agreeing,
    and the generator that writes the vectors calls the same pair.
    """
    import inspect
    src = inspect.getsource(P.package_digest)
    assert "canonical_bytes" in src
    assert "json.dumps" not in src
    assert inspect.getsource(P).count("json.dumps") == 1


def test_nothing_load_bearing_reaches_the_empty_latch_backstop():
    """Why `check_physics_content`'s empty-`must` branch cannot fire.

    A mutation run reports it as unmeasured, correctly: no package can
    reach it. That is a property of three rules rather than an accident,
    so the rules are what get asserted. If one of them loosens this test
    breaks and the backstop becomes live — which is the whole reason it
    is still there.
    """
    setup = P.PhysicsSetup(
        bodies=[P.BodySpec(body_id="b", mass_kg=10.0, constrained=False)],
        solver=P.SolverConfig(iterations=8, fixed_step_hz=60.0,
                              settle_timeout_s=8.0),
        scene_digest="0123456789abcdef")
    solution = P.ReferenceSolution(steps=["push"])

    # 1. Promotion cannot point into an empty tuple.
    with pytest.raises(ValidationError):
        P.PhysicsPackage(package_id="hollow", vector_latches=(0,))

    # 2. A required latch must be one the package declares.
    with pytest.raises(ValidationError):
        P.PhysicsPackage(package_id="hollow", required_latches=("ghost",))

    # 3. Which leaves on_mandatory_route as the only way to be
    #    load-bearing with nothing declared, and that is refused before
    #    the backstop, by its own error rather than the backstop's.
    hollow = P.PhysicsPackage(package_id="hollow", on_mandatory_route=True,
                              setup=setup, reference_solution=solution)
    assert hollow.load_bearing
    errors = P.check_physics_content([hollow])
    assert errors and all("names no required latch" in e for e in errors), \
        errors
    assert not any("no latch condition" in e for e in errors), (
        "if the backstop is what fires, one of the three rules above "
        "has loosened and this test should have caught it first")


# --- the engine builds a provider against these numbers -------------------

GD_CONSTANTS = (__import__("pathlib").Path(__file__).resolve().parents[2]
                / "godot" / "scripts" / "autoload" / "constants.gd")


def test_the_envelope_reaches_the_engine_unchanged():
    """§29.3.2's three minima, as GDScript sees them.

    The bridge never touches a body, so these numbers are useless on this
    side alone: the ENGINE is what has to build a provider at exactly the
    envelope and a body at exactly the limit. They are exported from
    `physics.py` by `export.py` rather than retyped into `constants.py`,
    because two sources for one contract is the drift the export
    mechanism exists to prevent — and a `ManipulableBody` whose friction
    is derived from a stale 700 makes a mandatory route unsolvable by the
    host the verifier says qualifies.
    """
    import re

    gd = GD_CONSTANTS.read_text(encoding="utf-8")
    for name, value in (("ENVELOPE_FORCE_N", P.ENVELOPE_FORCE_N),
                        ("ENVELOPE_RANGE_M", P.ENVELOPE_RANGE_M),
                        ("ENVELOPE_MASS_KG", P.ENVELOPE_MASS_KG)):
        found = re.search(rf"^const {name} = ([-\d.e+]+)$", gd, re.M)
        assert found, (
            f"{name} is no longer exported to GDScript, so the engine is "
            "back to guessing what a guaranteed provider is")
        assert float(found.group(1)) == pytest.approx(value), (
            f"GDScript {name} is {found.group(1)}, Python's is {value}")
    verbs = re.search(r"^const MANIPULATE_VERBS = (\[[^\]]*\])$", gd, re.M)
    assert verbs, "the manipulate verbs are no longer exported"
    assert sorted(eval(verbs.group(1))) == sorted(P.MANIPULATE_VERBS), (
        "the engine and the bridge disagree about which verbs grant "
        f"manipulate: {verbs.group(1)} vs {sorted(P.MANIPULATE_VERBS)}")


def test_the_substrate_can_keep_the_envelope_s_promise():
    """A host at the minimum must be able to move a body at the limit.

    The engine derives a manipulable body's friction from these numbers
    rather than choosing one, and that is not decoration: Godot's default
    friction of 1.0 resists a 120 kg body with about 1176 N against 700 N
    of push, so under the default the contract promised something the
    substrate refused. `make godot-physics` measured exactly that on its
    first run -- "700 N moved 120 kg by 0.00 m" -- and this states the
    arithmetic on the side that owns the numbers, so changing one of them
    to something unkeepable fails here rather than in a playtest.
    """
    gravity = 9.8
    bound = P.ENVELOPE_FORCE_N / (P.ENVELOPE_MASS_KG * gravity)
    assert bound > 0.0, "the envelope admits no friction at all"
    assert bound < 1.0, (
        "the envelope would be kept under Godot's default friction of "
        "1.0, so deriving one in the engine proves nothing -- check "
        "whether these numbers still mean what this test assumes")


HARNESS_GD = (__import__("pathlib").Path(__file__).resolve().parents[2]
              / "godot" / "scripts" / "gameplay" / "replay_harness.gd")


def test_the_harness_emits_exactly_what_the_evidence_model_requires():
    """`ReplayEvidence` is the wire shape and the harness is what fills it.

    The engine is the only side that can produce one and the bridge is
    the only side that can validate one, so neither can catch a field
    that is named differently on the other. A record missing
    `content_digest` is refused as malformed and the engine would have
    no way to know why; one carrying an extra key is refused outright,
    because the model is `extra="forbid"`.

    Read off the harness's own return literal rather than a copy, so a
    field renamed on either side fails here.
    """
    import re

    gd = HARNESS_GD.read_text(encoding="utf-8")
    emitted = set(re.findall(r'^\t\t"([a-z_]+)": ', gd, re.M))
    required = set(ReplayEvidence_fields())
    assert emitted == required, (
        "the harness emits "
        + str(sorted(emitted))
        + " and ReplayEvidence takes "
        + str(sorted(required))
        + "; the engine is the only side that can produce one and the "
        "bridge the only side that can validate one, so a name that "
        "differs is a record neither lane can explain"
    )


def ReplayEvidence_fields():
    return tuple(P.ReplayEvidence.model_fields)


def test_a_harness_record_validates_and_is_bound_to_its_package():
    """The shape `godot-physics` produced, through the real model.

    Exactly the payload the harness returned for its `crate_home`
    package on 2026-09-12, including the digest it computed. It is here
    so that a change to the canonical serializer on EITHER side -- which
    would move `content_digest` -- shows up as evidence that no longer
    matches its package rather than as a green suite on both.
    """
    package = P.PhysicsPackage(
        package_id="crate_home",
        latch_conditions=(P.LatchCondition(
            latch_id="crate_home", kind="POSITION_REGION",
            detail="crate_a in goal"),),
        vector_latches=(0,),
        required_latches=("crate_home",),
        on_mandatory_route=True,
        setup=P.PhysicsSetup(
            bodies=(P.BodySpec(body_id="crate_a", mass_kg=100.0),),
            solver=P.SolverConfig(iterations=8, fixed_step_hz=60.0,
                                  settle_timeout_s=8.0),
            scene_digest="0123456789abcdef"),
        reference_solution=P.ReferenceSolution(
            steps=("push crate_a 0 1 2.0", "settle")))
    evidence = P.ReplayEvidence(
        package_id="crate_home",
        content_digest=P.package_digest(package),
        provider_force_n=P.ENVELOPE_FORCE_N,
        provider_range_m=P.ENVELOPE_RANGE_M,
        provider_mass_kg=P.ENVELOPE_MASS_KG,
        per_run_latched=(("crate_home",), ("crate_home",),
                         ("crate_home",)))
    assert evidence.runs == 3
    assert evidence.at_the_envelope
    assert evidence.latched_every_run(package.required_latches) == ()
    # THE DIGEST THE ENGINE COMPUTED, recorded so a serializer change on
    # either side is caught here rather than in a playtest.
    assert evidence.content_digest == "b42a0d5ef34c8706", (
        "the canonical serializer moved: `godot-physics` computed "
        "b42a0d5ef34c8706 for this package and Python now computes "
        f"{evidence.content_digest}"
    )
