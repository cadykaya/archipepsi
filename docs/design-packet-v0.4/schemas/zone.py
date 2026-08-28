"""Archipepsi v0.4 — Zone contract.

This module IS the Zone specification. The prose in EPSILON_SPEC.md
describes it; where they disagree, this file wins.

Two layers of checking, deliberately separated:

* Structural  — Pydantic. Shape, types, enums, numeric bounds, per-chamber
  rules. Runs on parse.
* Semantic    — `validate_zone()`. Facts that need the request context:
  which AP locations were allocated, which Echoes are owned. Returns a list
  of human-readable error strings, which are fed verbatim into the single
  repair request.

The chamber union is discriminated on `type`, which means each chamber
carries only the fields that mean something for it. v0.3 had one flat field
bag shared by all five types; the model then had to guess which fields
applied, and the validator had to police combinations that the schema
should have made unrepresentable.
"""

from __future__ import annotations

from typing import Annotated, Literal, Union

from pydantic import BaseModel, ConfigDict, Field, model_validator

try:  # works both standalone and when copied into a package
    from . import constants as C
except ImportError:  # pragma: no cover
    import constants as C

SCHEMA_VERSION = 4

Theme = Literal[
    "grass_block", "stone_dungeon", "neon_city",
    "gothic_castle", "desert_scrap", "void_glitch",
]
Archetype = Literal["melee", "ranged", "brute"]

_ID = Field(min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")


class Strict(BaseModel):
    # extra="forbid" is load-bearing: it rejects invented fields outright
    # rather than silently dropping them, so a model hallucinating a
    # mechanic fails validation instead of quietly doing nothing.
    model_config = ConfigDict(extra="forbid")


class EnemyGroup(Strict):
    archetype: Archetype
    count: int = Field(ge=1, le=C.MAX_ENEMIES_PER_CHAMBER)


class ChamberBase(Strict):
    id: str = _ID
    flavor: str | None = Field(default=None, max_length=C.MAX_TEXT_LEN)
    reward_location_id: int | None = Field(
        default=None, ge=C.FIRST_LOCATION_ID, le=C.LAST_LOCATION_ID
    )

    @property
    def enemy_total(self) -> int:
        return sum(g.count for g in getattr(self, "enemies", []))

    @property
    def brute_total(self) -> int:
        return sum(g.count for g in getattr(self, "enemies", []) if g.archetype == "brute")


class CorridorChamber(ChamberBase):
    """Connector. Objective is implicitly reach_reward when it holds a reward."""
    type: Literal["corridor"]
    length: float = Field(ge=6, le=30)
    width: float = Field(ge=4, le=10)
    enemies: list[EnemyGroup] = Field(default_factory=list, max_length=4)


class ArenaChamber(ChamberBase):
    """Rectangular combat room. A boss room is an arena holding one brute."""
    type: Literal["arena"]
    width: float = Field(ge=10, le=28)
    depth: float = Field(ge=10, le=28)
    wall_height: float = Field(ge=4, le=8)
    objective: Literal["kill_all", "reach_reward"]
    enemies: list[EnemyGroup] = Field(default_factory=list, max_length=4)

    @model_validator(mode="after")
    def _kill_all_needs_enemies(self):
        if self.objective == "kill_all" and self.enemy_total == 0:
            raise ValueError("arena with objective 'kill_all' must contain at least one enemy")
        return self


class PlatformPathChamber(ChamberBase):
    """Base-movement platforming. Gaps are clamped to the derived safe jump."""
    type: Literal["platform_path"]
    segment_count: int = Field(ge=3, le=8)
    gap_size: float = Field(ge=0.5, le=C.SAFE_BASE_JUMP_GAP)
    vertical_step: float = Field(ge=0.0, le=C.MAX_VERTICAL_STEP)
    objective: Literal["platform_to_goal"] = "platform_to_goal"
    enemies: list[EnemyGroup] = Field(default_factory=list, max_length=2)


class TowerChamber(ChamberBase):
    """Vertical traversal. The template always emits a base-movement route."""
    type: Literal["tower"]
    floors: int = Field(ge=2, le=5)
    objective: Literal["reach_reward", "kill_all"]
    enemies: list[EnemyGroup] = Field(default_factory=list, max_length=4)

    @model_validator(mode="after")
    def _kill_all_needs_enemies(self):
        if self.objective == "kill_all" and self.enemy_total == 0:
            raise ValueError("tower with objective 'kill_all' must contain at least one enemy")
        return self


class TreasureRoomChamber(ChamberBase):
    """Small safe reward room. Always holds exactly one reward, never enemies."""
    type: Literal["treasure_room"]
    objective: Literal["reach_reward"] = "reach_reward"
    reward_location_id: int = Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_LOCATION_ID)


Chamber = Annotated[
    Union[
        CorridorChamber, ArenaChamber, PlatformPathChamber,
        TowerChamber, TreasureRoomChamber,
    ],
    Field(discriminator="type"),
]


class Zone(Strict):
    schema_version: Literal[4] = 4
    zone_id: str = _ID
    display_name: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)
    target_game: str = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)
    theme: Theme
    designer_note: str | None = Field(default=None, max_length=C.MAX_DESIGNER_NOTE_LEN)
    featured_echo_ids: list[str] = Field(default_factory=list, max_length=4)
    chambers: list[Chamber] = Field(
        min_length=C.ZONE_MIN_CHAMBERS, max_length=C.ZONE_MAX_CHAMBERS
    )

    # NOTE: there is deliberately no `required_echo_ids` field and no field
    # anywhere in this schema capable of expressing a mandatory Echo
    # requirement. That guarantee is structural, not a validation rule.

    @model_validator(mode="after")
    def _zone_wide_limits(self):
        ids = [c.id for c in self.chambers]
        if len(set(ids)) != len(ids):
            raise ValueError("duplicate chamber id")

        total = sum(c.enemy_total for c in self.chambers)
        if total > C.MAX_ENEMIES_PER_ZONE:
            raise ValueError(
                f"zone has {total} enemies, limit is {C.MAX_ENEMIES_PER_ZONE}"
            )

        brutes = sum(c.brute_total for c in self.chambers)
        if brutes > C.MAX_BRUTES_PER_ZONE:
            raise ValueError(
                f"zone has {brutes} brutes, limit is {C.MAX_BRUTES_PER_ZONE}"
            )

        rewards = [c.reward_location_id for c in self.chambers if c.reward_location_id]
        if len(set(rewards)) != len(rewards):
            raise ValueError("duplicate reward_location_id")
        return self

    @property
    def reward_location_ids(self) -> list[int]:
        return [c.reward_location_id for c in self.chambers if c.reward_location_id]


# ---------------------------------------------------------------------------
# Semantic validation
# ---------------------------------------------------------------------------

def validate_zone(
    zone: Zone,
    *,
    expected_zone_id: str,
    allocated_location_ids: list[int],
    owned_echo_ids: list[str],
) -> list[str]:
    """Check a structurally-valid Zone against its request.

    Returns [] if acceptable, else concise error strings for the repair
    request. Never mutates the Zone: v0.4 rejects and repairs rather than
    silently clamping, so an accepted Zone is always something Epsilon
    actually chose.
    """
    errors: list[str] = []

    if zone.zone_id != expected_zone_id:
        errors.append(
            f"zone_id must be exactly '{expected_zone_id}', got '{zone.zone_id}'"
        )

    got = zone.reward_location_ids
    want = set(allocated_location_ids)
    missing = want - set(got)
    extra = set(got) - want

    if missing:
        errors.append(
            "these allocated AP locations are missing a reward chamber: "
            + ", ".join(str(i) for i in sorted(missing))
        )
    if extra:
        errors.append(
            "these AP location ids were not allocated to this Zone and must not appear: "
            + ", ".join(str(i) for i in sorted(extra))
        )

    unowned = [e for e in zone.featured_echo_ids if e not in owned_echo_ids]
    if unowned:
        errors.append(
            "featured_echo_ids must all be owned; unknown: " + ", ".join(unowned)
        )

    return errors
