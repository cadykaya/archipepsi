"""Archipepsi v0.7 — Zone contract.

This module IS the Zone specification. EPSILON_SPEC.md describes it; where
they disagree, this file wins.

Two layers, deliberately separated:

* Structural  — Pydantic. Shape, enums, bounds, per-chamber rules. Runs on
  parse AND on assignment, so a model cannot be mutated out of validity
  after construction.
* Semantic    — `validate_zone()`. Facts needing request context: which AP
  locations were allocated, which Echoes are owned. Returns error strings
  fed verbatim into the single repair request.
"""

from __future__ import annotations

from typing import Annotated, Literal, Union

from pydantic import BaseModel, ConfigDict, Field, model_validator

try:  # works standalone and when copied into a package
    from . import constants as C
except ImportError:  # pragma: no cover
    import constants as C

SCHEMA_VERSION = 7

Theme = Literal[
    "concrete_facility", "rusted_industrial", "neon_transit",
    "gothic_stone", "temple_ruin", "void_glitch",
]
Archetype = Literal["melee", "ranged", "brute"]

_ID = Field(min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")
_ECHO_ID = Annotated[str, Field(max_length=32, pattern=r"^echo_\d+$")]


class Strict(BaseModel):
    # extra="forbid" rejects invented fields outright rather than dropping
    # them silently, so a hallucinated mechanic fails loudly.
    # validate_assignment closes the v0.4 hole where post-parse mutation
    # walked straight through every bound.
    model_config = ConfigDict(extra="forbid", frozen=True)


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
        return sum(g.count for g in getattr(self, "enemies", [])
                   if g.archetype == "brute")


class _WithEnemies(ChamberBase):
    @model_validator(mode="after")
    def _chamber_enemy_budget(self):
        # v0.4 bounded each GROUP at 8 and allowed 4 groups, so a chamber
        # could legally hold 14 while the prose and the constraints sent to
        # Epsilon both said 8.
        if self.enemy_total > C.MAX_ENEMIES_PER_CHAMBER:
            raise ValueError(
                f"chamber '{self.id}' has {self.enemy_total} enemies, "
                f"limit is {C.MAX_ENEMIES_PER_CHAMBER}"
            )
        objective = getattr(self, "objective", None)
        if objective == "kill_all" and self.enemy_total == 0:
            raise ValueError(
                f"chamber '{self.id}': objective 'kill_all' needs at least one enemy"
            )
        return self


class CorridorChamber(_WithEnemies):
    """Connector. Has no objective, so enemies here gate nothing."""
    type: Literal["corridor"]
    length: float = Field(ge=6, le=30)
    width: float = Field(ge=4, le=10)
    enemies: tuple[EnemyGroup, ...] = Field(default=(), max_length=4)

    @model_validator(mode="after")
    def _reward_needs_a_gate(self):
        if self.reward_location_id is not None and self.enemy_total > 0:
            raise ValueError(
                f"chamber '{self.id}': a corridor has no objective, so its enemies "
                "cannot gate a reward. Use an arena with objective 'kill_all'."
            )
        return self


class ArenaChamber(_WithEnemies):
    """Rectangular combat room. A boss room is an arena holding one brute."""
    type: Literal["arena"]
    width: float = Field(ge=10, le=28)
    depth: float = Field(ge=10, le=28)
    wall_height: float = Field(ge=4, le=8)
    objective: Literal["kill_all", "reach_reward"]
    enemies: tuple[EnemyGroup, ...] = Field(default=(), max_length=4)


class PlatformPathChamber(_WithEnemies):
    """Base-movement platforming.

    `gap_size` and `vertical_step` are bounded JOINTLY: the reachable gap
    shrinks as the landing rises. v0.4 bounded them independently, so both
    could be maxed and the real margin was 1.17x rather than the 1.56x the
    flat-jump derivation advertised.
    """
    type: Literal["platform_path"]
    segment_count: int = Field(ge=3, le=8)
    gap_size: float = Field(ge=0.5, le=C.SAFE_BASE_JUMP_GAP)
    vertical_step: float = Field(ge=0.0, le=C.MAX_VERTICAL_STEP)
    objective: Literal["platform_to_goal"] = "platform_to_goal"
    enemies: tuple[EnemyGroup, ...] = Field(default=(), max_length=2)

    @model_validator(mode="after")
    def _gap_reachable_at_this_step(self):
        allowed = C.max_safe_gap(self.vertical_step)
        if self.gap_size > allowed:
            raise ValueError(
                f"chamber '{self.id}': gap_size {self.gap_size} exceeds {allowed}, "
                f"the furthest a base jump reaches landing {self.vertical_step}m "
                "higher. Lower gap_size or vertical_step."
            )
        return self


class TowerChamber(_WithEnemies):
    """Vertical traversal. The template always emits a base-movement route."""
    type: Literal["tower"]
    floors: int = Field(ge=2, le=5)
    objective: Literal["reach_reward", "kill_all"]
    enemies: tuple[EnemyGroup, ...] = Field(default=(), max_length=4)


class TreasureRoomChamber(ChamberBase):
    """Small safe reward room. Exactly one reward, never enemies."""
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
    #: Still 7, and deliberately. The Zone contract did not change in v0.8 —
    #: Echoes 2.0 changes what an Echo means, not what a Zone is — and
    #: bumping a version to match its neighbours would say a change happened
    #: where none did.
    schema_version: Literal[7] = 7
    zone_id: str = _ID
    display_name: str = Field(min_length=1, max_length=C.MAX_TEXT_LEN)
    target_game: str = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)
    theme: Theme
    designer_note: str | None = Field(default=None, max_length=C.MAX_DESIGNER_NOTE_LEN)
    featured_echo_ids: tuple[_ECHO_ID, ...] = Field(default=(), max_length=4)
    chambers: tuple[Chamber, ...] = Field(
        min_length=C.ZONE_MIN_CHAMBERS, max_length=C.ZONE_MAX_CHAMBERS
    )

    # NOTE: no `required_echo_ids`, and no field anywhere in this schema can
    # express a mandatory Echo requirement. Structural, not a rule.

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

        rewards = self.reward_location_ids
        if len(set(rewards)) != len(rewards):
            raise ValueError("duplicate reward_location_id")
        return self

    @property
    def reward_location_ids(self) -> list[int]:
        return [c.reward_location_id for c in self.chambers
                if c.reward_location_id is not None]


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

    Returns [] if acceptable, else concise errors for the repair request.
    Never mutates: v0.5 rejects and repairs rather than clamping, so an
    accepted Zone is always something Epsilon actually chose.
    """
    errors: list[str] = []

    if zone.zone_id != expected_zone_id:
        errors.append(
            f"zone_id must be exactly '{expected_zone_id}', got '{zone.zone_id}'"
        )

    # Multiset comparison: v0.4 compared sets, so two allocated slots could
    # be satisfied by one chamber.
    got = sorted(zone.reward_location_ids)
    want = sorted(allocated_location_ids)
    if got != want:
        missing = sorted(set(want) - set(got))
        extra = sorted(set(got) - set(want))
        if missing:
            errors.append(
                "these allocated AP locations are missing a reward chamber: "
                + ", ".join(str(i) for i in missing)
            )
        if extra:
            errors.append(
                "these AP location ids were not allocated to this Zone and must "
                "not appear: " + ", ".join(str(i) for i in extra)
            )
        if not missing and not extra:
            errors.append(
                "each allocated AP location must appear exactly once; "
                f"expected {want}, got {got}"
            )

    unowned = [e for e in zone.featured_echo_ids if e not in owned_echo_ids]
    if unowned:
        errors.append(
            "featured_echo_ids must all be owned; unknown: " + ", ".join(unowned)
        )

    return errors
