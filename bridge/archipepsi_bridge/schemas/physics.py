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

#: §4.10. The verifier's whole budget, unchanged from Design 3.
STATE_VECTOR_BOUND = 4096

#: §4.10. Latches compete with macro variables for that budget, so the
#: count promoted into the vector is capped on its own as well.
MAX_VECTOR_LATCHES = 8


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
    """

    latch_id: str = Field(min_length=1, max_length=32,
                          pattern=r"^[a-z0-9_]+$")
    kind: Literal["CONSTRAINT_STATE", "WEIGHT_THRESHOLD", "ATTACH_SENSOR",
                  "POSITION_REGION"]
    #: What the engine must observe. Opaque to the bridge: it is measured
    #: in the physics world and the bridge never re-derives it.
    detail: str = Field(default="", max_length=200)


class ReplayEvidence(Strict):
    """The engine's proof that a package's reference solution latches.

    §23.5 check 20: replayed headless three times at fixed solver
    settings against a synthetic provider **at exactly the envelope** —
    `700 N` / `20.0 m` / `120 kg`. All three must latch. A package that
    passes is therefore solvable by every qualifying provider rather
    than merely by a strong one.

    **This is evidence, not a promise.** Nothing in the bridge can
    produce it, and no engine can yet either; a package claiming a
    load-bearing latch without it is refused rather than accepted
    pending.
    """

    runs: int = Field(ge=0, le=16)
    latched: int = Field(ge=0, le=16)
    provider_force_n: float = Field(ge=0.0)
    provider_range_m: float = Field(ge=0.0)
    provider_mass_kg: float = Field(ge=0.0)
    #: Which `latch_id`s actually latched in every run.
    latched_ids: tuple[str, ...] = ()

    @model_validator(mode="after")
    def _evidence_is_self_consistent(self):
        if self.latched > self.runs:
            raise ValueError(
                f"evidence claims {self.latched} latched runs out of "
                f"{self.runs}")
        return self

    @property
    def proves_solvable(self) -> bool:
        """Three runs, all latched, at exactly the envelope.

        Replaying above the envelope proves a strong provider can solve
        it, which is not the claim check 20 makes.
        """
        return (self.runs == 3 and self.latched == 3
                and self.provider_force_n == ENVELOPE_FORCE_N
                and self.provider_range_m == ENVELOPE_RANGE_M
                and self.provider_mass_kg == ENVELOPE_MASS_KG)


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
    on_mandatory_route: bool = False
    #: The engine's replay proof. Absent until a physics runtime exists.
    evidence: ReplayEvidence | None = None

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

    @property
    def promoted(self) -> tuple[LatchCondition, ...]:
        return tuple(self.latch_conditions[i] for i in self.vector_latches)


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

    Three refusals, and the third is the one that matters:

    1. The promoted latch count fits `MAX_VECTOR_LATCHES`.
    2. The whole state vector fits `STATE_VECTOR_BOUND`.
    3. **A package whose latch the verifier reasons about carries engine
       replay evidence.** A latch on a mandatory route is a progression
       gate, and accepting one on the strength of a declaration would be
       trusting a physical claim nobody has measured. With no physics
       runtime, every such package is refused — which is the honest
       state and is the point of writing the rule first.
    """
    errors: list[str] = []
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
        needs_proof = bool(p.vector_latches) or p.on_mandatory_route
        if not needs_proof:
            continue
        if p.evidence is None:
            errors.append(
                f"package '{p.package_id}' puts a latch on a route the "
                "verifier reasons about and carries no replay evidence; "
                "a physical claim nobody has measured is not a "
                "progression guarantee")
        elif not p.evidence.proves_solvable:
            errors.append(
                f"package '{p.package_id}' carries replay evidence that "
                "does not prove solvability at the envelope: "
                f"{p.evidence.latched}/{p.evidence.runs} runs latched at "
                f"{p.evidence.provider_force_n:.0f} N / "
                f"{p.evidence.provider_range_m:.1f} m / "
                f"{p.evidence.provider_mass_kg:.0f} kg")
        else:
            missing = [c.latch_id for c in p.promoted
                       if c.latch_id not in p.evidence.latched_ids]
            if missing:
                errors.append(
                    f"package '{p.package_id}' promotes latch(es) "
                    f"{missing} that its own replay never latched")
    return tuple(errors)
