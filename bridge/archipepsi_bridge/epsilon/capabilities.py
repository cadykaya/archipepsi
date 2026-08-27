"""Runtime capability gates for staged Echoes 2.0 implementation.

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


# S1 deliberately preserves only the v0.7 mechanical surface. New Actions
# are separately gated by schemas.echo.IMPLEMENTED_PRIMITIVES.
IMPLEMENTED_OPERATION_KINDS = ("create",)
IMPLEMENTED_COMPONENT_KINDS = ("action", "trait")
IMPLEMENTED_TRAIT_STATS = ("gravity", "move_speed")
IMPLEMENTED_ACTION_SLOTS = ("echo_a",)
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
            primitive = component.primitive
            # v8 added optional projectile features before the S2 runner exists.
            # The old S1 projectile path ignores them, so non-default values
            # must be refused rather than accepted as fake mechanics.
            if primitive.type == "projectile_damage":
                if primitive.gravity_scale != 0.0:
                    errors.append(
                        "projectile_damage gravity_scale is not implemented by "
                        "the current runtime"
                    )
                if primitive.bounces != 0:
                    errors.append(
                        "projectile_damage bounces are not implemented by the "
                        "current runtime"
                    )
    return errors
