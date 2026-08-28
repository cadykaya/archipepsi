"""Archipepsi v0.4 — Echo contract.

This module IS the Echo specification.

v0.3 had one flat Echo object with an `activation` string, a `cooldown`
that was meaningless for passives, and a free list of effects drawn from a
ten-name vocabulary. That made a lot of nonsense legal: `knockback_target`
alone (knock back what?), `recoil_self` + `heal_self` (recoil from drinking
a potion), a passive Echo with an attack.

v0.4 makes the rules structural. Effects fall into three classes:

    Initiators  do something when the player presses the Echo button
    Modifiers   change what an initiator just did
    Passives    apply continuously while the Echo is equipped

and the Echo itself is a discriminated union on `activation`:

    PrimaryEcho  exactly 1 initiator + 0-2 modifiers, cooldown required
    PassiveEcho  1-2 passives, no cooldown field at all

Modifiers additionally require a *damage* initiator in the same Echo, since
neither recoil nor knockback means anything without something that hits.

Three rules, all enforced by the type system rather than by a validator
that has to remember them.
"""

from __future__ import annotations

from typing import Annotated, Literal, Union

from pydantic import BaseModel, ConfigDict, Field, model_validator

try:  # works both standalone and when copied into a package
    from . import constants as C
except ImportError:  # pragma: no cover
    import constants as C

SCHEMA_VERSION = 4


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


# ---------------------------------------------------------------------------
# Initiators — an Echo does exactly one of these on activation
# ---------------------------------------------------------------------------

class HitscanDamage(Strict):
    type: Literal["hitscan_damage"]
    damage: float = Field(ge=1, le=25)
    pellets: int = Field(ge=1, le=16)
    spread_degrees: float = Field(ge=0, le=30)
    range: float = Field(ge=5, le=60)


class ProjectileDamage(Strict):
    type: Literal["projectile_damage"]
    damage: float = Field(ge=1, le=25)
    speed: float = Field(ge=5, le=45)
    lifetime: float = Field(ge=0.5, le=6)


class Dash(Strict):
    type: Literal["dash"]
    force: float = Field(ge=4, le=20)


class GrappleToSurface(Strict):
    type: Literal["grapple_to_surface"]
    range: float = Field(ge=5, le=35)
    pull_force: float = Field(ge=4, le=25)


class HealSelf(Strict):
    type: Literal["heal_self"]
    amount: float = Field(ge=5, le=60)


class Shield(Strict):
    type: Literal["shield"]
    amount: float = Field(ge=5, le=80)
    duration: float = Field(ge=1, le=15)


Initiator = Annotated[
    Union[HitscanDamage, ProjectileDamage, Dash, GrappleToSurface, HealSelf, Shield],
    Field(discriminator="type"),
]
DAMAGE_INITIATORS = ("hitscan_damage", "projectile_damage")


# ---------------------------------------------------------------------------
# Modifiers — only meaningful alongside a damage initiator
# ---------------------------------------------------------------------------

class RecoilSelf(Strict):
    type: Literal["recoil_self"]
    force: float = Field(ge=0, le=16)


class KnockbackTarget(Strict):
    type: Literal["knockback_target"]
    force: float = Field(ge=0, le=16)


Modifier = Annotated[
    Union[RecoilSelf, KnockbackTarget], Field(discriminator="type")
]


# ---------------------------------------------------------------------------
# Passives — apply while equipped
# ---------------------------------------------------------------------------

class ModifyGravity(Strict):
    type: Literal["modify_gravity"]
    multiplier: float = Field(ge=0.35, le=1.5)


class ModifySpeed(Strict):
    type: Literal["modify_speed"]
    multiplier: float = Field(ge=0.65, le=1.6)


Passive = Annotated[
    Union[ModifyGravity, ModifySpeed], Field(discriminator="type")
]

PrimaryEffect = Annotated[
    Union[
        HitscanDamage, ProjectileDamage, Dash, GrappleToSurface, HealSelf, Shield,
        RecoilSelf, KnockbackTarget,
    ],
    Field(discriminator="type"),
]


# ---------------------------------------------------------------------------
# Echo
# ---------------------------------------------------------------------------

class EchoBase(Strict):
    schema_version: Literal[4] = 4
    echo_id: str = Field(min_length=1, max_length=32, pattern=r"^echo_\d+$")
    source_location_id: int = Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_LOCATION_ID)
    source_item_name: str = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)
    source_game: str = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)
    source_recipient_name: str = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)

    display_name: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)
    description: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)
    archetype: Literal["weapon", "tool", "mobility", "passive"]
    tags: list[str] = Field(default_factory=list, max_length=6)

    @model_validator(mode="after")
    def _echo_id_matches_source(self):
        expected = f"echo_{self.source_location_id}"
        if self.echo_id != expected:
            raise ValueError(f"echo_id must be '{expected}' for this source location")
        return self


class PrimaryEcho(EchoBase):
    """Activated with RMB, subject to cooldown. LMB stays Pepsi Pop."""
    activation: Literal["primary"]
    cooldown: float = Field(ge=C.ECHO_COOLDOWN_MIN, le=C.ECHO_COOLDOWN_MAX)
    effects: list[PrimaryEffect] = Field(
        min_length=C.ECHO_EFFECTS_MIN, max_length=C.ECHO_EFFECTS_MAX
    )

    @model_validator(mode="after")
    def _composition(self):
        kinds = [e.type for e in self.effects]
        initiators = [k for k in kinds if k not in ("recoil_self", "knockback_target")]
        modifiers = [k for k in kinds if k in ("recoil_self", "knockback_target")]

        if len(initiators) != 1:
            raise ValueError(
                "a primary Echo must contain exactly one initiator effect "
                "(hitscan_damage, projectile_damage, dash, grapple_to_surface, "
                f"heal_self or shield); found {len(initiators)}"
            )
        if len(set(modifiers)) != len(modifiers):
            raise ValueError("duplicate modifier effect")
        if modifiers and initiators[0] not in DAMAGE_INITIATORS:
            raise ValueError(
                f"'{modifiers[0]}' requires a damage initiator (hitscan_damage or "
                f"projectile_damage) in the same Echo; found '{initiators[0]}'"
            )
        return self


class PassiveEcho(EchoBase):
    """Applies while equipped. RMB does nothing. No cooldown field exists."""
    activation: Literal["passive"]
    effects: list[Passive] = Field(min_length=1, max_length=2)

    @model_validator(mode="after")
    def _no_duplicate_passives(self):
        kinds = [e.type for e in self.effects]
        if len(set(kinds)) != len(kinds):
            raise ValueError("duplicate passive effect")
        return self


Echo = Annotated[Union[PrimaryEcho, PassiveEcho], Field(discriminator="activation")]


# ---------------------------------------------------------------------------
# Semantic validation
# ---------------------------------------------------------------------------

def validate_echo(echo, *, expected_source_location_id: int) -> list[str]:
    """Check a structurally-valid Echo against its request."""
    errors: list[str] = []
    if echo.source_location_id != expected_source_location_id:
        errors.append(
            f"source_location_id must be {expected_source_location_id}, "
            f"got {echo.source_location_id}"
        )
    if echo.archetype == "passive" and echo.activation != "passive":
        errors.append("archetype 'passive' requires activation 'passive'")
    if echo.activation == "passive" and echo.archetype == "weapon":
        errors.append("archetype 'weapon' cannot have activation 'passive'")
    return errors
