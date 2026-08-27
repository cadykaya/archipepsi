"""Runtime capability gates for staged Echoes 2.0 implementation.

S1.1 review patch authored by ChatGPT (GPT-5.6 Sol, OpenAI).

The v0.8 schema describes the whole Echo language up front, but the engine
implements it stage by stage. A schema-valid interpretation must therefore
also be *runnable today* before it can be accepted and persisted.

Keep these gates narrow. Each later implementation stage widens them only
when the corresponding runtime exists. Both the Epsilon request and the
post-parse validator consume this module so the prompt cannot advertise a
capability that validation would silently accept as a no-op.
"""

from __future__ import annotations

from ..schemas.echo import EchoInterpretation


# Which *Action verbs* run is gated separately, by
# schemas.echo.IMPLEMENTED_PRIMITIVES — S2 opened that to 21 of 28. What
# follows is everything else about the shape of an interpretation, and S2
# moves none of it: the wider systems are still ahead.
IMPLEMENTED_OPERATION_KINDS = ("create",)
#: S3 added "resource": the fifteen HUD channels exist, so a Resource is
#: now a thing the client can render and tick rather than a definition
#: nothing reads. What it still cannot do is get SPENT — costs are rules
#: (S4) and `powers`/`fills` links are S5 — which is why no Action verb
#: un-gates alongside it. See DEFERRED_PRIMITIVES.
IMPLEMENTED_COMPONENT_KINDS = ("action", "trait", "resource")
IMPLEMENTED_TRAIT_STATS = ("gravity", "move_speed")

#: Still one slot, and this is the line people will reach for first when
#: they read that S2 "ships the catalog". S2 ships the *verbs*; the number
#: of reachable buttons is S7 ("Slots + loadout UX"). Widening this before
#: `main.gd` binds more than `slotted_action()` would let Epsilon place an
#: Action on a slot no key is wired to — owned, slotted, and unreachable.
IMPLEMENTED_ACTION_SLOTS = ("echo_a",)

#: `apply_status_on_hit` waits for statuses in S5.
IMPLEMENTED_MODIFIER_TYPES = ("recoil_self", "knockback_target")


def validate_stage_support(interpretation: EchoInterpretation) -> list[str]:
    """Reject schema-valid mechanics the current runtime cannot execute.

    This is intentionally independent from structural schema validation. A
    Resource, Rule, LINK, etc. is *valid v0.8 data*, but accepting it before
    its stage lands would persist a mechanic that silently does nothing.
    """
    errors: list[str] = []
    for op in interpretation.operations:
        if op.op not in IMPLEMENTED_OPERATION_KINDS:
            errors.append(
                f"operation '{op.op}' is part of the v0.8 contract but is not "
                "implemented by the current runtime"
            )
            continue

        # S1 supports only CREATE, so this branch is exhaustive today. Keep
        # it shaped this way so later stages can add an operation without
        # accidentally bypassing the component gate for CREATE.
        if op.op != "create":
            continue
        component = op.component
        if component.kind not in IMPLEMENTED_COMPONENT_KINDS:
            errors.append(
                f"component kind '{component.kind}' is part of the v0.8 "
                "contract but is not implemented by the current runtime"
            )
            continue

        if component.kind == "trait":
            if component.stat not in IMPLEMENTED_TRAIT_STATS:
                errors.append(
                    f"trait stat '{component.stat}' is not implemented by the "
                    "current runtime"
                )
            continue

        if component.kind == "action":
            if component.slot not in IMPLEMENTED_ACTION_SLOTS:
                errors.append(
                    f"action slot '{component.slot}' is not wired by the "
                    "current runtime"
                )
            for modifier in component.modifiers:
                if modifier.type not in IMPLEMENTED_MODIFIER_TYPES:
                    errors.append(
                        f"modifier '{modifier.type}' is not implemented by the "
                        "current runtime"
                    )
            # v8 added `gravity_scale` and `bounces` to projectile_damage
            # before a runner existed for them, and S1 correctly refused
            # non-default values rather than accepting fake mechanics. The
            # S2 projectile integrates gravity and reflects off surfaces, so
            # that refusal is retired here rather than left as a gate that
            # no longer describes the engine.
    return errors
