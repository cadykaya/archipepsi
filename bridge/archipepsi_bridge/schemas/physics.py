"""The physics contract, bridge side, ahead of the physics.

Design 6 §29.3.1, §29.3.2, §4.10 and §23.1's `vector_latches`.

**There is no physics runtime.** Zero `RigidBody3D` in the project, so
nothing here can be executed or physically proved. What CAN exist now is
the contract: what counts as a `manipulate` provider, what a latch is
allowed to be, what the state vector can afford, and — the part that
matters most — **what evidence content must carry before it is
accepted**. Building that first means the day the runtime lands, the
rules it has to satisfy are already written down and already tested,
rather than being invented under pressure to make a demo work.

**Two questions that must never merge.** §29.3's whole repair is that
capability IDENTITY and provider QUALIFICATION are different:

* *identity* — does this host grant `manipulate` at all? A **Boolean**,
  decided by verb-set membership. This is what the verifier sees, and
  the only thing it sees.
* *qualification* — does this host count as the guaranteed provider for
  a MANDATORY route? A **numeric envelope**, evaluated at Zone entry
  from the resolved loadout and nowhere else.

A sub-envelope host is real content: it manipulates, it solves optional
routes, it is composable and Forgeable. It simply is not the thing that
unlocks a gated Zone — exactly as a `DASH` under `8.0 m` does not
satisfy `long_gap`. Keeping them apart is what keeps a newton out of the
state vector.
"""

from __future__ import annotations

import hashlib
import json
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


#: §29.3.1. A host grants `manipulate` when its verb set contains one of
#: these, and never for any other reason. Design 2 §29.1: granted only by
#: a `PUSH`, `PULL` or `HOLD` verb and never by the other nine.
MANIPULATE_VERBS: frozenset[str] = frozenset({"PUSH", "PULL", "HOLD"})

#: §29.3.2's mandatory-route envelope, exactly.
ENVELOPE_FORCE_N = 700.0
ENVELOPE_RANGE_M = 20.0
ENVELOPE_MASS_KG = 120.0

#: Design 2 §10.3's ordinary-pickup line, and **not a fourth envelope
#: number**.
#:
#: These two masses answer different questions and collapsing them into
#: one rule would be wrong in both directions. `ENVELOPE_MASS_KG` (120)
#: is one of THREE numbers -- with force and range -- that a *host* must
#: meet to count as a qualified manipulation provider (§29.3.2); it
#: bounds what a `PUSH`, `PULL` or `HOLD` may act on. `CARRY_MASS_KG`
#: (60) is a property of the *object* and governs ordinary pickup:
#: §10.3, *"an object is carriable if `carriable = true` and
#: `mass_kg <= 60.0`. Above that it is manipulable only."*
#:
#: A 100 kg crate sits inside the provider envelope and is still not
#: something the player picks up. Reading 120 as the carry limit would
#: hand the player a crate in both hands; reading 60 as the envelope
#: would refuse a qualified host the crate it is authored to push.
CARRY_MASS_KG = 60.0

#: Design 2 §10.2's class ladder, and §6.1's player.
#:
#: Transcribed onto the bridge because something here has to DERIVE
#: what a mechanism demands of a player, and a ladder that lives only
#: in `mass_class.gd` is a ladder this side has to guess at. Two
#: spellings of one fact is the failure; one spelling, exported, is the
#: fix.
#:
#: `PLAYER_MASS_KG` is not decoration: a `PRESSURE_PLATE` reads a
#: semantic class, so whether the player's own body satisfies one is a
#: question about this number, and it is the difference between a
#: puzzle the base kit solves and a puzzle that needs a capability.
MASS_LIGHT_BELOW = 30.0
MASS_MEDIUM_BELOW = 120.0
MASS_HEAVY_BELOW = 400.0
PLAYER_MASS_KG = 80.0

MASS_CLASSES = ("LIGHT", "MEDIUM", "HEAVY", "FIXED")


def mass_class(mass_kg: float, manipulable: bool = True) -> str:
    """§10.2, derived and never declared.

    A thing that cannot be manipulated at all is `FIXED` whatever it
    weighs -- §10.2's second clause, and the reason a bolted 5 kg
    bracket is not `LIGHT`.
    """
    if not manipulable or mass_kg >= MASS_HEAVY_BELOW:
        return "FIXED"
    if mass_kg >= MASS_MEDIUM_BELOW:
        return "HEAVY"
    if mass_kg >= MASS_LIGHT_BELOW:
        return "MEDIUM"
    return "LIGHT"


def base_kit_can_satisfy(required_class: str) -> bool:
    """Can a player carrying only the guaranteed kit load a plate that
    demands this class?

    Two ways, and both are arithmetic rather than opinion:

      THE PLAYER'S OWN BODY. `PLAYER_MASS_KG` is 80, which is `MEDIUM`,
      so standing on the plate satisfies `LIGHT` and `MEDIUM`.
      SOMETHING THEY CARRIED. §10.3 caps ordinary pickup at
      `CARRY_MASS_KG`, which is 60 -- also `MEDIUM`. So a carried
      object can reach no further up the ladder than the player
      standing on it already does.

    `HEAVY` starts at 120 kg. Nothing under the carry line reaches it
    and the player does not weigh it, so a `HEAVY` plate demands a
    pushed object, which demands a qualified manipulation provider.
    That is a capability, and it is one `graph.Capability` deliberately
    cannot name.
    """
    heaviest = mass_class(max(PLAYER_MASS_KG, CARRY_MASS_KG))
    return MASS_CLASSES.index(required_class) <= MASS_CLASSES.index(heaviest)

#: §4.10. The verifier's whole budget, unchanged from Design 3.
STATE_VECTOR_BOUND = 4096

#: §4.10. Latches compete with macro variables for that budget, so the
#: count promoted into the vector is capped on its own as well.
MAX_VECTOR_LATCHES = 8


# --------------------------------------------------------------------------
# Ordinary pickup — a property of the OBJECT, not of the host.
# --------------------------------------------------------------------------

def carriable_by_hand(carriable: bool, mass_kg: float) -> bool:
    """§10.3's ordinary-pickup test: the flag AND the kilograms.

    **Both clauses, and the flag is not redundant.** `PLATE` is exactly
    60 kg -- on the line, not over it -- and is still not carriable,
    because §10.1's flag says it is handled with lifting slots rather
    than a grip. A kilogram test on its own would put a grip on it.

    **Nothing about the host reaches this function**, which is the
    point: no Gear, Mod or Ability widens ordinary pickup. A host that
    clears §29.3.2's envelope may push a 100 kg crate; it still may not
    pick one up. The two rules live in one module so the distinction is
    written down where a reader will meet both, and they take different
    arguments so neither can be called with the other's data.

    The kilogram comparison is `<=`: 60.0 itself passes.
    """
    return bool(carriable) and float(mass_kg) <= CARRY_MASS_KG


# --------------------------------------------------------------------------
# Identity — Boolean, and the only thing the verifier ever sees.
# --------------------------------------------------------------------------

def grants_manipulate(verbs) -> bool:
    """Does a host with these verbs grant `capability:core:manipulate`?

    **Returns a Boolean and nothing else, deliberately.** §30.6 sees one
    Boolean whose value is fixed for the Zone, and §29.5's monotonicity
    argument holds verbatim because a richer loadout can only add
    providers. The moment this returned a number, the verifier would
    have a newton in it.
    """
    return bool(MANIPULATE_VERBS & {str(v).upper() for v in verbs})


# --------------------------------------------------------------------------
# Qualification — numeric, at Zone entry, never stored.
# --------------------------------------------------------------------------

class ProviderEnvelope(Strict):
    """A resolved host's manipulation numbers.

    **Not a stored field.** §4.2: this is a pure function of
    `(host composition, equipped Gear, active Mods)` evaluated at the
    entry check, so a player cannot qualify by equipping Gear they then
    remove.
    """

    force_n: float = Field(ge=0.0, le=100_000.0)
    range_m: float = Field(ge=0.0, le=1_000.0)
    mass_limit_kg: float = Field(ge=0.0, le=100_000.0)

    @property
    def qualifies(self) -> bool:
        """Does this host count as a guaranteed provider?

        All three, not two of three: a puzzle authored at the envelope
        can need the reach and the force and the mass in one motion.
        """
        return (self.force_n >= ENVELOPE_FORCE_N
                and self.range_m >= ENVELOPE_RANGE_M
                and self.mass_limit_kg >= ENVELOPE_MASS_KG)

    def shortfall(self) -> tuple[str, ...]:
        """Which minima this host misses, for §34.4's message.

        A player refused entry is owed the reason, and "your PUSH is too
        weak" is not one.
        """
        out = []
        if self.force_n < ENVELOPE_FORCE_N:
            out.append(f"force {self.force_n:.0f} N below "
                       f"{ENVELOPE_FORCE_N:.0f} N")
        if self.range_m < ENVELOPE_RANGE_M:
            out.append(f"range {self.range_m:.1f} m below "
                       f"{ENVELOPE_RANGE_M:.1f} m")
        if self.mass_limit_kg < ENVELOPE_MASS_KG:
            out.append(f"mass limit {self.mass_limit_kg:.0f} kg below "
                       f"{ENVELOPE_MASS_KG:.0f} kg")
        return tuple(out)


def qualifying_providers(hosts) -> tuple[int, ...]:
    """Indices of the hosts that count for a mandatory route.

    §29.4's entry validation counts only these. A player whose only
    `PUSH` Ability resolves below the envelope does not satisfy the
    check and is told why.
    """
    return tuple(i for i, h in enumerate(hosts)
                 if h.qualifies)


# --------------------------------------------------------------------------
# Latches — monotone Booleans, and the budget they compete for.
# --------------------------------------------------------------------------

class LatchCondition(Strict):
    """One condition that, once satisfied, stays satisfied.

    **Monotone by construction, not by convention.** Design 2 §5.7:
    once satisfied, never re-evaluated, never cleared by reset or death.
    That is exactly the shape Design 3's verifier already handles for
    keys and shortcuts, and it is why physics can gate progression at
    all — latching is the bridge between simulated physics and provable
    progression.

    **`latch_id` is unique within its package and nowhere wider.** Two
    packages may both call a latch `bridge_down`; the same package may
    not. Globally a latch is `package_id/latch_id` — see `latch_ref`.
    """

    latch_id: str = Field(min_length=1, max_length=32,
                          pattern=r"^[a-z0-9_]+$")
    kind: Literal["CONSTRAINT_STATE", "WEIGHT_THRESHOLD", "ATTACH_SENSOR",
                  "POSITION_REGION"]
    #: What the engine must observe. Opaque to the bridge: it is measured
    #: in the physics world and the bridge never re-derives it. It IS
    #: part of the content digest, so changing it invalidates evidence.
    detail: str = Field(default="", max_length=200)


def latch_ref(package_id: str, latch_id: str) -> str:
    """The global identity of a latch.

    A bare `latch_id` is not one. Two packages naming a latch
    `bridge_down` mean two different latches, and a state vector that
    conflated them would prove reachability across a condition nobody
    satisfied.
    """
    return f"{package_id}/{latch_id}"


class BodySpec(Strict):
    """A manipulable body, as far as the contract reasons about it."""

    body_id: str = Field(min_length=1, max_length=32,
                         pattern=r"^[a-z0-9_]+$")
    mass_kg: float = Field(gt=0.0, le=100_000.0)
    constrained: bool = False


class SolverConfig(Strict):
    """The solver settings a replay ran under.

    §23.5 check 20 replays at FIXED settings. Fixed means stated: a
    solution that latches at sixteen iterations and not at eight is a
    solution that depends on the solver, and evidence that does not say
    which it ran under cannot distinguish those.
    """

    iterations: int = Field(ge=1, le=64)
    fixed_step_hz: float = Field(gt=0.0, le=1000.0)
    settle_timeout_s: float = Field(gt=0.0, le=120.0)


class PhysicsSetup(Strict):
    """The bodies and solver a package's solution is authored against.

    **`scene_digest` is the engine's, and it has to be.** Body id, mass
    and constrained-ness are what the CONTRACT reasons about; they are
    not what a replay ran against. Collision geometry, initial
    transforms, static obstacles, gravity, layer masks — all of it can
    change while every field here stays identical, and a solution that
    latched before the crate was moved two metres left is not evidence
    about the room as it now stands.

    The bridge cannot compute this: it has no scene. The engine computes
    it over the actual replay setup and supplies it, and the bridge
    folds it into `package_digest` so that a scene change invalidates
    the evidence exactly as a solver change does. **Opaque here on
    purpose** — the bridge never re-derives a physical fact.
    """

    bodies: tuple[BodySpec, ...] = Field(default=(), max_length=40)
    solver: SolverConfig
    #: Sixteen hex characters, computed by the engine over the scene the
    #: replay ran in. See `AMALGAM_BRIDGE.md` §6.2b for what it covers.
    scene_digest: str = Field(min_length=16, max_length=16,
                              pattern=r"^[0-9a-f]{16}$")


class ReferenceSolution(Strict):
    """The authored solution check 20 replays.

    `steps` is opaque to the bridge — it is the engine's script — but it
    is part of the digest, so editing the solution invalidates the
    evidence that the old one latched.
    """

    steps: tuple[str, ...] = Field(default=(), max_length=64)


class PhysicsPackage(Strict):
    """A physics puzzle, as far as the bridge is concerned.

    Deliberately a fragment of Design 6 §23.1: constraints, macro
    setters and Status solutions belong to systems that are not built,
    and inventing schema for them here would be guessing. What is here
    is what `vector_latches` and the evidence gate need.
    """

    package_id: str = Field(min_length=1, max_length=32,
                            pattern=r"^[a-z0-9_]+$")
    latch_conditions: tuple[LatchCondition, ...] = Field(default=(),
                                                         max_length=16)
    #: Which of `latch_conditions`, by index, the verifier reasons about.
    #:
    #: A latch not named here still latches — it is simply not something
    #: the state vector spends budget on, because nothing on a mandatory
    #: route depends on it. Naming them makes the allocation a
    #: composition decision rather than an accident of package selection.
    vector_latches: tuple[int, ...] = Field(default=(),
                                            max_length=MAX_VECTOR_LATCHES)
    #: Does a mandatory route depend on this package?
    #: Which latches a MANDATORY ROUTE depends on, by `latch_id`.
    #:
    #: Distinct from `vector_latches`, which is the verifier's budget
    #: question — what it reasons about as a state dimension. A latch can
    #: be promoted without a required route depending on it (it opens a
    #: shortcut the search should know about). **The reverse cannot
    #: hold**: §23.1 says a latch left out of `vector_latches` is one
    #: "nothing on a mandatory route depends on", so anything required is
    #: necessarily promoted, and `_required_latches_are_promoted`
    #: enforces that rather than leaving it to prose.
    required_latches: tuple[str, ...] = Field(default=(), max_length=16)
    on_mandatory_route: bool = False
    setup: PhysicsSetup | None = None
    reference_solution: ReferenceSolution | None = None
    #: The engine's replay proof. Absent until a physics runtime exists.
    evidence: "ReplayEvidence | None" = None

    @model_validator(mode="after")
    def _latch_ids_are_unique_within_the_package(self):
        ids = [c.latch_id for c in self.latch_conditions]
        twice = sorted({i for i in ids if ids.count(i) > 1})
        if twice:
            raise ValueError(
                f"package '{self.package_id}' declares latch id(s) "
                f"{twice} more than once; a latch is identified by name "
                "within its package, so two conditions sharing one are "
                "indistinguishable to every consumer")
        return self

    @model_validator(mode="after")
    def _promoted_latches_exist_and_are_distinct(self):
        n = len(self.latch_conditions)
        for i in self.vector_latches:
            if not 0 <= i < n:
                raise ValueError(
                    f"package '{self.package_id}' promotes latch index "
                    f"{i}, and it declares {n} latch condition(s)")
        if len(set(self.vector_latches)) != len(self.vector_latches):
            raise ValueError(
                f"package '{self.package_id}' promotes the same latch "
                "twice; a Boolean counted twice buys no reachability and "
                "spends the budget anyway")
        return self

    @model_validator(mode="after")
    def _required_latches_are_promoted(self):
        declared = {c.latch_id for c in self.latch_conditions}
        unknown = sorted(set(self.required_latches) - declared)
        if unknown:
            raise ValueError(
                f"package '{self.package_id}' requires latch(es) "
                f"{unknown} it does not declare")
        promoted = {c.latch_id for c in self.promoted}
        unpromoted = sorted(set(self.required_latches) - promoted)
        if unpromoted:
            raise ValueError(
                f"package '{self.package_id}' requires latch(es) "
                f"{unpromoted} without promoting them; a latch a "
                "mandatory route depends on is by definition one the "
                "verifier must reason about (§23.1)")
        return self

    @property
    def promoted(self) -> tuple[LatchCondition, ...]:
        return tuple(self.latch_conditions[i] for i in self.vector_latches)

    @property
    def load_bearing(self) -> bool:
        """Does anything the verifier or a route depends on ride on this?"""
        return bool(self.vector_latches or self.on_mandatory_route
                    or self.required_latches)


# --------------------------------------------------------------------------
# THE CONTENT DIGEST — one function, both sides.
# --------------------------------------------------------------------------

def canonical_bytes(package: PhysicsPackage) -> bytes:
    """Exactly what gets hashed. **The only canonicalization here.**

    Split out from `package_digest` so a test can compare the BYTES and
    not merely the hash. A vector that only checks digests cannot say
    whether two implementations built different objects or serialized
    the same object differently, and a test that hashes a stored string
    instead of calling this cannot catch the serializer drifting at all.

    Anything that wants a canonical form calls this. A second
    implementation in the same language is how the two stop agreeing.
    """
    body = {
        "package_id": package.package_id,
        "latch_conditions": [
            {"latch_id": c.latch_id, "kind": c.kind, "detail": c.detail}
            for c in package.latch_conditions],
        "vector_latches": list(package.vector_latches),
        "required_latches": sorted(package.required_latches),
        "setup": None if package.setup is None else {
            "bodies": [{"body_id": b.body_id, "mass_kg": b.mass_kg,
                        "constrained": b.constrained}
                       for b in package.setup.bodies],
            "scene_digest": package.setup.scene_digest,
            "solver": {
                "iterations": package.setup.solver.iterations,
                "fixed_step_hz": package.setup.solver.fixed_step_hz,
                "settle_timeout_s": package.setup.solver.settle_timeout_s},
        },
        "reference_solution": None if package.reference_solution is None
        else list(package.reference_solution.steps),
    }
    return json.dumps(body, sort_keys=True,
                      separators=(",", ":")).encode("utf-8")


def package_digest(package: PhysicsPackage) -> str:
    """What a replay ran against, as sixteen hex characters.

    **This is identity and freshness, not authentication.** It does not
    stop anyone forging a record; it stops a record that was true of one
    thing being read as true of another. Those are different problems
    and only the second one is the bridge's.

    Evidence names counts, provider values and latch names. None of that
    describes the CONTENT replayed, so a successful record from one
    package passed for a different package with different conditions —
    which is the whole of the defect this closes.

    **Producer and validator call this same function.** The engine
    computes it over the package it is about to replay and returns it
    with the result; the bridge recomputes it over the package it is
    about to accept and compares. Everything that could change what a
    replay proves is in it: the latch conditions including their detail,
    which are promoted, the bodies, the solver settings, and the
    reference solution's steps. Change any and the evidence is stale.
    """
    return hashlib.sha256(canonical_bytes(package)).hexdigest()[:16]


class ReplayEvidence(Strict):
    """The engine's proof that a package's reference solution latches.

    §23.5 check 20: replayed headless three times at fixed solver
    settings against a synthetic provider **at exactly the envelope** —
    `700 N` / `20.0 m` / `120 kg`. All three must latch. A package that
    passes is therefore solvable by every qualifying provider rather
    than merely by a strong one.

    **Bound to what it replayed.** `package_id` says which package and
    `content_digest` says which revision of it — the conditions, the
    promotion, the bodies, the solver and the solution. Evidence that
    does not match the package in front of the validator is refused as
    copied or stale rather than read as a pass.

    **`per_run_latched` is per run, not a union.** A record saying "all
    three runs latched, and here is the set of things that latched
    somewhere" cannot distinguish three good runs from three runs that
    each latched a different third of the requirement.

    **This is evidence, not a promise.** Nothing in the bridge can
    produce it, and no engine can yet either; a package claiming a
    load-bearing latch without it is refused rather than accepted
    pending.
    """

    package_id: str = Field(min_length=1, max_length=32,
                            pattern=r"^[a-z0-9_]+$")
    content_digest: str = Field(min_length=16, max_length=16,
                                pattern=r"^[0-9a-f]{16}$")
    provider_force_n: float = Field(ge=0.0)
    provider_range_m: float = Field(ge=0.0)
    provider_mass_kg: float = Field(ge=0.0)
    #: One tuple of latched `latch_id`s per run, in run order.
    per_run_latched: tuple[tuple[str, ...], ...] = Field(default=(),
                                                        max_length=16)

    @property
    def runs(self) -> int:
        return len(self.per_run_latched)

    @property
    def at_the_envelope(self) -> bool:
        """Replaying ABOVE the envelope proves a strong provider can
        solve it, which is not the claim check 20 makes."""
        return (self.provider_force_n == ENVELOPE_FORCE_N
                and self.provider_range_m == ENVELOPE_RANGE_M
                and self.provider_mass_kg == ENVELOPE_MASS_KG)

    def latched_every_run(self, required) -> tuple[str, ...]:
        """Which required latches failed to latch in at least one run."""
        need = set(required)
        missed: set[str] = set()
        for run in self.per_run_latched:
            missed |= need - set(run)
        return tuple(sorted(missed))


class PlacedPackage(Strict):
    """One physics package, instantiated in one room of one Zone.

    **This is where a package travels, and why it is not on the Zone.**
    `AMALGAM_BRIDGE.md` §5.6 put three carriers to the engine lane;
    option 2 was taken. A package is a PHYSICAL fact, like the layout:
    the engine resolves the Zone's bounded intent into a real setup,
    measures it, replays it, and offers the result inside
    `layout_result` — so it reaches the bridge through the same
    validate-then-commit path the layout does, and travels afterwards
    inside the committed manifest.

    Putting it on the Zone instead was tried and refused, correctly, by
    `test_epsilon_vocabulary`: the Zone is **Epsilon's output surface**,
    and `LatchCondition.detail` and `ReferenceSolution.steps` are what
    the engine must observe and the engine's own script. A provider that
    can write those is a provider authoring a physical claim, which is
    the lane boundary itself. Epsilon's surface stays bounded intent;
    the engine resolves it; a provider-authored proposal is never an
    accepted physical certificate.

    The three identities are all checked, because a package that is
    valid in itself and attached to the wrong thing is the failure this
    record exists to make impossible:

    * `zone_id` — the Zone the layout was proposed for;
    * `room_id` — a room that Zone actually declares;
    * `content_ref` — a piece of content that room actually declares.
    """

    package_id: str = Field(min_length=1, max_length=32,
                            pattern=r"^[a-z0-9_]+$")
    zone_id: str = Field(min_length=1, max_length=32,
                         pattern=r"^[a-z0-9_]+$")
    room_id: str = Field(min_length=1, max_length=24,
                         pattern=r"^[a-z0-9_]+$")
    #: `feature:<tag>` or `shell:<shell_id>` — which declared piece of
    #: that room's content this package realizes. Charset-constrained and
    #: resolved against the Zone, exactly like `edge_id`: a reference
    #: that names nothing is refused rather than stored.
    content_ref: str = Field(min_length=1, max_length=64,
                             pattern=r"^(feature|shell):[a-z0-9_]+$")
    package: PhysicsPackage

    @model_validator(mode="after")
    def _the_wrapper_and_the_package_name_the_same_thing(self):
        if self.package.package_id != self.package_id:
            raise ValueError(
                f"placement names package '{self.package_id}' and carries "
                f"'{self.package.package_id}'; two spellings of one fact "
                "is how a latch comes to be filed under the wrong thing")
        return self

    @property
    def ref(self) -> str:
        return f"{self.room_id}/{self.package_id}"


PhysicsPackage.model_rebuild()
PlacedPackage.model_rebuild()


def evidence_fault(package: PhysicsPackage,
                   evidence: ReplayEvidence) -> str:
    """Why `evidence` is not a sound record of `package`, or `""`.

    **One implementation, two consumers.** `check_physics_content` asks
    it of a load-bearing package, where unsound evidence means a
    progression gate nobody measured. `layout.validate` asks it of every
    `powered_door` chain a generated room built and the engine
    certified (`AMALGAM_BRIDGE.md` §5.6a), where it means an affordance
    the engine says works and has not shown to. The question is the
    same one and it must not grow two answers.

    At most one fault, because they compound: a digest that does not
    match says nothing about whether the runs were at the envelope, and
    listing both invites fixing the second.
    """
    if evidence.package_id != package.package_id:
        return (f"package '{package.package_id}' carries evidence "
                f"recorded for '{evidence.package_id}'; a replay proves "
                "something about the thing it replayed and nothing "
                "about anything else")
    want = package_digest(package)
    if evidence.content_digest != want:
        return (f"package '{package.package_id}' has changed since its "
                f"replay (evidence {evidence.content_digest}, content "
                f"{want}); the conditions, the promotion, the bodies, "
                "the solver or the solution are not what was measured")
    if evidence.runs != 3:
        return (f"package '{package.package_id}' carries "
                f"{evidence.runs} replay run(s); check 20 replays three")
    if not evidence.at_the_envelope:
        return (f"package '{package.package_id}' was replayed at "
                f"{evidence.provider_force_n:.0f} N / "
                f"{evidence.provider_range_m:.1f} m / "
                f"{evidence.provider_mass_kg:.0f} kg, not at the "
                "envelope; a stronger provider solving it is not the "
                "claim")
    # §23.5 check 20: the reference solution latches EVERY latch
    # condition, not merely the promoted ones. A package whose optional
    # latch never fires has a solution that does not do what it says,
    # and the verifier reasons about the promoted ones on the strength
    # of the same solution.
    must = {c.latch_id for c in package.latch_conditions}
    if not must:
        return (f"package '{package.package_id}' declares no latch "
                "condition; there is no outcome to require")
    missed = evidence.latched_every_run(must)
    if missed:
        return (f"package '{package.package_id}' declares latch(es) "
                f"{list(missed)} that did not latch in every run; three "
                "runs each latching a different part is not three "
                "successes")
    return ""



def state_vector_product(*, macro_variables: tuple[int, ...] = (),
                         local_keys: int = 0, encounter_flags: int = 0,
                         shortcut_flags: int = 0, visited_flags: int = 0,
                         physics_latches: int = 0) -> int:
    """§4.10's product, computed rather than discovered.

    `macro_variables` is a state count per variable (2 to 4 each);
    everything else is a count of Booleans. §30.5 check 12 proves this
    product rather than finding the overflow at search time.
    """
    product = 1
    for states in macro_variables:
        product *= states
    for booleans in (local_keys, encounter_flags, shortcut_flags,
                     visited_flags, physics_latches):
        product *= 2 ** booleans
    return product


def check_physics_content(packages, *, macro_variables=(), local_keys=0,
                          encounter_flags=0, shortcut_flags=0,
                          visited_flags=0) -> tuple[str, ...]:
    """Everything the bridge can refuse about physics content today.

    1. The promoted latch count fits `MAX_VECTOR_LATCHES`.
    2. The whole state vector fits `STATE_VECTOR_BOUND`.
    3. **A package whose latch the verifier reasons about carries engine
       replay evidence, for THAT package and THAT revision of it.** A
       latch on a mandatory route is a progression gate, and accepting
       one on the strength of a declaration — or on a record that was
       true of something else — would be trusting a physical claim
       nobody has measured. With no physics runtime, every such package
       is refused, which is the honest state and the point of writing
       the rule first.
    """
    errors: list[str] = []
    seen_ids: set[str] = set()
    for p in packages:
        if p.package_id in seen_ids:
            errors.append(
                f"two packages share the id '{p.package_id}'; a latch is "
                "identified by package and name, so duplicate package "
                "ids make its global identity ambiguous")
        seen_ids.add(p.package_id)

    promoted = sum(len(p.vector_latches) for p in packages)
    if promoted > MAX_VECTOR_LATCHES:
        errors.append(
            f"{promoted} latches are promoted into the state vector, past "
            f"the {MAX_VECTOR_LATCHES} the budget allows")

    product = state_vector_product(
        macro_variables=tuple(macro_variables), local_keys=local_keys,
        encounter_flags=encounter_flags, shortcut_flags=shortcut_flags,
        visited_flags=visited_flags, physics_latches=promoted)
    if product > STATE_VECTOR_BOUND:
        errors.append(
            f"the state vector is {product} configurations, past the "
            f"{STATE_VECTOR_BOUND} bound; latches and macro variables "
            "compete for the same budget")

    for p in packages:
        if not p.load_bearing:
            continue

        # A PROOF OF NOTHING IS NOT A PROOF. Three green runs against no
        # setup, no solution, or no required outcome are three runs of
        # nothing, and a digest over `null` is a consistent digest of an
        # absence. Load-bearing content has to have something to replay
        # and something the replay must show.
        if p.setup is None or not p.setup.bodies:
            errors.append(
                f"package '{p.package_id}' is load-bearing and declares "
                "no physical setup; there is nothing for a replay to have "
                "run against")
            continue
        if p.reference_solution is None \
                or not p.reference_solution.steps:
            errors.append(
                f"package '{p.package_id}' is load-bearing and declares "
                "no reference solution; a replay needs something to "
                "replay")
            continue
        if p.on_mandatory_route and not p.required_latches:
            errors.append(
                f"package '{p.package_id}' sits on a mandatory route and "
                "names no required latch; a route that depends on nothing "
                "in particular cannot be proved passable")
            continue

        ev = p.evidence
        if ev is None:
            errors.append(
                f"package '{p.package_id}' puts a latch on a route the "
                "verifier reasons about and carries no replay evidence; "
                "a physical claim nobody has measured is not a "
                "progression guarantee")
            continue
        if not p.latch_conditions:
            # BACKSTOP, and unreachable today — deliberately kept.
            # Three separate rules have to hold for it to stay that way:
            # a promoted index cannot point into an empty tuple, a
            # required latch must be declared, and the mandatory-route
            # guard above already refuses the only remaining way to be
            # load-bearing with nothing declared. Loosen any one and a
            # package proving nothing arrives here, where
            # `latched_every_run(set())` would find nothing missing and
            # accept it. `test_nothing_load_bearing_reaches_the_empty_
            # latch_backstop` pins all three, so this branch showing up
            # as unmeasured in a mutation run is the expected result and
            # not an invitation to write a test that cannot exist.
            errors.append(
                f"package '{p.package_id}' is load-bearing and declares "
                "no latch condition; there is no outcome to require")
            continue
        fault = evidence_fault(p, ev)
        if fault:
            errors.append(fault)
    return tuple(errors)
