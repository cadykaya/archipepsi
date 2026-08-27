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
#: S5 added "link": the four kinds have runtime meaning now — `powers`
#: costs and drains, `fills` refills, `gates` withholds, `scales`
#: interpolates a trait. S6 opens the rest: the fold has folded UPGRADE,
#: MODIFY and MERGE since S1, and `target_errors` now checks a
#: disposition can land BEFORE the save refuses it, so a provider may
#: finally answer an item the campaign already owns. This tuple is now
#: the whole v0.8 operation vocabulary.
IMPLEMENTED_OPERATION_KINDS = ("create", "upgrade", "modify", "link",
                               "merge")
#: S3 added "resource": the fifteen HUD channels exist, so a Resource is
#: now a thing the client can render and tick rather than a definition
#: nothing reads. S4 added "rule": the ECHOES §5 interpreter runs in the
#: client (`rule_runtime.gd`, proven by `make godot-rules`), so a rule can
#: watch events, hold conditions, SPEND a resource and apply effects.
#: S5 added "status": the per-target containers run in the client, and an
#: owned definition floors applications of its kind.
IMPLEMENTED_COMPONENT_KINDS = ("action", "trait", "resource", "rule",
                               "status")
#: S5: the full derived stat stack (`stat_stack.gd`, `make godot-stats`).
IMPLEMENTED_TRAIT_STATS = (
    "move_speed", "jump_height", "gravity", "air_control",
    "ground_friction", "damage_dealt", "damage_taken", "knockback_resist",
    "regen",
)

#: The §5 allowlists, minus what later stages own. `status_applied` /
#: `status_active` / `apply_status` are S5 (statuses), `trait_pulse` is S5
#: (the derived stat stack), `grant_local_reward` is S9. The three tuples
#: are pinned against the GDScript interpreter's actual arms in both
#: directions by `test_rules_contract.py` — a kind admitted here that the
#: interpreter cannot run is an Echo that validates and does nothing.
IMPLEMENTED_RULE_EVENTS = (
    "zone_enter", "chamber_enter", "jump", "land", "dash_end", "kill",
    "damage_dealt", "damage_taken", "action_used", "action_ready",
    "parry_success", "check_claimed", "tick_1hz", "resource_full",
    "resource_empty", "low_health", "status_applied",
)
IMPLEMENTED_CONDITION_KINDS = (
    "resource_at_least", "resource_at_most", "hp_below", "hp_above",
    "moving_backward", "airborne", "grounded", "speed_above",
    "enemy_within", "slot_is", "zone_is_finale", "status_active",
)
IMPLEMENTED_EFFECT_KINDS = (
    "resource_add", "heal", "grant_shield", "impulse_self", "damage_around",
    "fire_projectile", "reset_action_cooldown", "refill_resource",
    "apply_status", "trait_pulse",
)

#: Still one slot, and this is the line people will reach for first when
#: they read that S2 "ships the catalog". S2 ships the *verbs*; the number
#: of reachable buttons is S7 ("Slots + loadout UX"). Widening this before
#: `main.gd` binds more than `slotted_action()` would let Epsilon place an
#: Action on a slot no key is wired to — owned, slotted, and unreachable.
IMPLEMENTED_ACTION_SLOTS = ("echo_a",)

IMPLEMENTED_MODIFIER_TYPES = ("recoil_self", "knockback_target",
                              "apply_status_on_hit")


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

        # A LINK op carries no component; the component gates below are
        # CREATE's. Keep the explicit skip so a later op kind cannot
        # accidentally bypass them.
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

        if component.kind == "rule":
            if component.event not in IMPLEMENTED_RULE_EVENTS:
                errors.append(
                    f"rule event '{component.event}' is not implemented by "
                    "the current runtime"
                )
            for condition in component.conditions:
                if condition.type not in IMPLEMENTED_CONDITION_KINDS:
                    errors.append(
                        f"rule condition '{condition.type}' is not "
                        "implemented by the current runtime"
                    )
            for effect in component.effects:
                if effect.type not in IMPLEMENTED_EFFECT_KINDS:
                    errors.append(
                        f"rule effect '{effect.type}' is not implemented by "
                        "the current runtime"
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
