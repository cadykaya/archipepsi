"""Archipepsi v0.7 — Echo contract.

This module IS the Echo specification.

Effects fall into three classes:

    Initiators  do something when the player presses the Echo button
    Modifiers   change what an initiator just did
    Passives    apply continuously while the Echo is equipped

v0.4 claimed three rules were "enforced by the type system rather than by a
validator that has to remember them." Only one was. `PrimaryEffect` was a
flat union of initiators and modifiers, so "exactly one initiator" and
"modifiers need a damage initiator" were runtime `model_validator` code that
appending to `effects` walked straight past.

v0.5 makes them structural for real:

    PrimaryEcho  initiator: Initiator          <- exactly one, by arity
                 modifiers: list[Modifier]           <- 0-2, and only modifiers
                 cooldown: float               <- required
    PassiveEcho  effects: list[Passive]        <- 1-2, no cooldown field

"Exactly one initiator" is now a field, not a count check. The remaining
rule — modifiers need something that hits — is the one genuine validator,
and `validate_assignment` means it re-runs on mutation.

This also makes the exported JSON Schema carry the rules, so a provider
driven by structured output cannot emit two initiators.
"""

from __future__ import annotations

from typing import Annotated, Literal, Union

from pydantic import BaseModel, ConfigDict, Field, model_validator

try:
    from . import constants as C
except ImportError:  # pragma: no cover
    import constants as C

SCHEMA_VERSION = 7


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


# ---------------------------------------------------------------------------
# Initiators
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
    #: Instantaneous velocity change in m/s, along view-forward.
    force: float = Field(ge=4, le=20)


class GrappleToSurface(Strict):
    type: Literal["grapple_to_surface"]
    range: float = Field(ge=5, le=35)
    #: Instantaneous velocity change in m/s, toward the hit point.
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
# Modifiers
# ---------------------------------------------------------------------------

class RecoilSelf(Strict):
    type: Literal["recoil_self"]
    #: Instantaneous velocity change in m/s, opposite aim.
    force: float = Field(ge=0, le=16)


class KnockbackTarget(Strict):
    type: Literal["knockback_target"]
    #: Instantaneous velocity change in m/s, away from the attack source.
    force: float = Field(ge=0, le=16)


Modifier = Annotated[Union[RecoilSelf, KnockbackTarget], Field(discriminator="type")]


# ---------------------------------------------------------------------------
# Passives — bounds come from constants, which derives them from traversal
# ---------------------------------------------------------------------------

class ModifyGravity(Strict):
    type: Literal["modify_gravity"]
    #: Capped at 1.0: a gravity Echo may only ever make you lighter. Above
    #: that it lowers jump apex below the mandatory step height.
    multiplier: float = Field(ge=C.GRAVITY_MULT_MIN, le=C.GRAVITY_MULT_MAX)


class ModifySpeed(Strict):
    type: Literal["modify_speed"]
    #: Floored so the worst legal loadout still clears every mandatory gap.
    multiplier: float = Field(ge=C.SPEED_MULT_MIN, le=C.SPEED_MULT_MAX)


Passive = Annotated[Union[ModifyGravity, ModifySpeed], Field(discriminator="type")]


# ---------------------------------------------------------------------------
# Echo
# ---------------------------------------------------------------------------

class EchoBase(Strict):
    schema_version: Literal[7] = 7
    echo_id: str = Field(min_length=1, max_length=32, pattern=r"^echo_\d+$")
    source_location_id: int = Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_LOCATION_ID)
    source_item_name: str = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)
    source_game: str = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)
    source_recipient_name: str = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)

    display_name: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)
    description: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)
    tags: list[Annotated[str, Field(max_length=24)]] = Field(
        default=(), max_length=6
    )

    @model_validator(mode="after")
    def _echo_id_matches_source(self):
        expected = f"echo_{self.source_location_id}"
        if self.echo_id != expected:
            raise ValueError(f"echo_id must be '{expected}' for this source location")
        return self


class PrimaryEcho(EchoBase):
    """Activated with RMB, subject to cooldown. LMB stays Static Pulse."""
    activation: Literal["primary"]
    archetype: Literal["weapon", "tool", "mobility"]
    cooldown: float = Field(ge=C.ECHO_COOLDOWN_MIN, le=C.ECHO_COOLDOWN_MAX)
    initiator: Initiator
    modifiers: tuple[Modifier, ...] = Field(default=(), max_length=2)

    @model_validator(mode="after")
    def _modifiers_need_something_that_hits(self):
        kinds = [m.type for m in self.modifiers]
        if len(set(kinds)) != len(kinds):
            raise ValueError("duplicate modifier effect")
        if kinds and self.initiator.type not in DAMAGE_INITIATORS:
            raise ValueError(
                f"'{kinds[0]}' requires a damage initiator (hitscan_damage or "
                f"projectile_damage); found '{self.initiator.type}'"
            )
        if 1 + len(self.modifiers) > C.ECHO_EFFECTS_MAX:
            raise ValueError(f"at most {C.ECHO_EFFECTS_MAX} effects per Echo")
        return self

    @property
    def effects(self) -> list:
        """Flat view, for runtime code that just wants to iterate."""
        return [self.initiator, *self.modifiers]


class PassiveEcho(EchoBase):
    """Applies while equipped. RMB does nothing. No cooldown field exists."""
    activation: Literal["passive"]
    archetype: Literal["passive", "mobility"]
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
    """Check a structurally-valid Echo against its request.

    The archetype/activation rules that lived here in v0.4 are now
    structural (each variant declares its legal archetypes), so this is
    request-context only.
    """
    errors: list[str] = []
    if echo.source_location_id != expected_source_location_id:
        errors.append(
            f"source_location_id must be {expected_source_location_id}, "
            f"got {echo.source_location_id}"
        )
    return errors
