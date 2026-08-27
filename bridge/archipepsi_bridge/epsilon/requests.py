"""Normalized Epsilon request contracts (EPSILON_SPEC §9 and §10).

The packet left these as JSON examples (open item m25); these models pin
them. They are bridge-owned: the provider may change, the request contract
may not. Frozen like every other contract object.
"""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field

from ..schemas import constants as C

_AP_STR = Annotated[str, Field(max_length=C.MAX_AP_STRING_LEN)]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class ZoneSummary(Strict):
    name: str = Field(max_length=C.MAX_TEXT_LEN)
    theme: str = Field(max_length=48)
    target_game: _AP_STR


class EchoSummary(Strict):
    echo_id: str = Field(max_length=32)
    display_name: str = Field(max_length=C.MAX_TEXT_LEN)
    archetype: str = Field(max_length=16)
    activation: Literal["primary", "passive"]
    tags: tuple[Annotated[str, Field(max_length=24)], ...] = ()
    description: str = Field(max_length=C.MAX_TEXT_LEN)


class CampaignContext(Strict):
    seed_name: str = Field(max_length=128)
    slot_name: _AP_STR
    team: int = Field(ge=0)
    slot_id: int = Field(ge=0)
    zone_index: int = Field(ge=0)
    target_game: _AP_STR
    is_finale: bool = False
    static_glitch_units: int = Field(ge=0)
    completed_zone_summaries: tuple[ZoneSummary, ...] = ()


class PlayerContext(Strict):
    signal_keys: int = Field(ge=0)
    coins_available: int = Field(ge=0)
    echoes: tuple[EchoSummary, ...] = ()


class RequestLocation(Strict):
    location_id: int = Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_LOCATION_ID)
    location_name: _AP_STR
    item_name: _AP_STR
    recipient_name: _AP_STR
    recipient_game: _AP_STR
    item_flags: int = Field(ge=0)
    item_name_may_appear_in_player_text: bool = False


class ZoneGenerationRequest(Strict):
    schema_version: Literal[7] = 7
    zone_id: str = Field(min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")
    generation_id: str = Field(max_length=160)
    campaign: CampaignContext
    player: PlayerContext
    locations: tuple[RequestLocation, ...] = Field(
        min_length=1, max_length=C.ZONE_MAX_CHECKS)
    catalog: dict = Field(default_factory=lambda: {
        "themes": list(C.THEMES),
        "chamber_types": list(C.CHAMBER_TYPES),
        "enemy_archetypes": list(C.ENEMY_ARCHETYPES),
        "objectives": list(C.OBJECTIVES),
    })
    constraints: dict = Field(default_factory=lambda: {
        "max_chambers": C.ZONE_MAX_CHAMBERS,
        "max_enemies_total": C.MAX_ENEMIES_PER_ZONE,
        "max_enemies_per_chamber": C.MAX_ENEMIES_PER_CHAMBER,
        "max_brutes": C.MAX_BRUTES_PER_ZONE,
        "max_vertical_step": C.MAX_VERTICAL_STEP,
        "gap_bound": (
            "gap_size <= max_safe_gap(vertical_step); "
            f"{C.SAFE_BASE_JUMP_GAP} flat, "
            f"{C.max_safe_gap(C.MAX_VERTICAL_STEP)} at a "
            f"{C.MAX_VERTICAL_STEP}m step"),
        "all_locations_must_appear_once": True,
        "critical_path_requires_echo": False,
    })


class EchoSource(Strict):
    location_id: int = Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_LOCATION_ID)
    item_name: _AP_STR
    source_game: _AP_STR
    recipient_name: _AP_STR
    item_flags: int = Field(ge=0)


class EchoPlayerState(Strict):
    existing_echoes: tuple[EchoSummary, ...] = ()
    signal_keys: int = Field(default=0, ge=0)
    coins_available: int = Field(default=0, ge=0)


class EchoGenerationRequest(Strict):
    schema_version: Literal[7] = 7
    source: EchoSource
    player_state: EchoPlayerState
    required_echo_id: str = Field(max_length=32, pattern=r"^echo_\d+$")
    allowed: dict = Field(default_factory=lambda: {
        "archetypes": ["weapon", "tool", "mobility", "passive"],
        "activations": ["primary", "passive"],
        "initiators": ["hitscan_damage", "projectile_damage", "dash",
                       "grapple_to_surface", "heal_self", "shield"],
        "modifiers": ["recoil_self", "knockback_target"],
        "passives": ["modify_gravity", "modify_speed"],
    })
    composition_rules: tuple[str, ...] = (
        "a primary Echo has exactly one initiator plus 0-2 modifiers",
        "a passive Echo has 1-2 passives and no cooldown",
        "modifiers require hitscan_damage or projectile_damage in the same Echo",
    )
    balance_limits: dict = Field(default_factory=lambda: {
        "damage": [1, 25], "pellets": [1, 16],
        "cooldown": [C.ECHO_COOLDOWN_MIN, C.ECHO_COOLDOWN_MAX],
        "gravity_multiplier": [C.GRAVITY_MULT_MIN, C.GRAVITY_MULT_MAX],
        "speed_multiplier": [C.SPEED_MULT_MIN, C.SPEED_MULT_MAX],
    })
