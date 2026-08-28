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


#: ECHOES.md §13. Same seven tags the `affordance` component kind names —
#: one vocabulary, because a Zone feature and an owned capability tag are
#: the same concept seen from the two ends.
AffordanceTag = Literal[
    "grapple_anchor", "breakable_wall", "water_volume", "rail",
    "wind_volume", "bounce_pad", "moving_platform",
]


class EnemyGroup(Strict):
    archetype: Archetype
    #: One group is one encounter, so this is the encounter cap rather
    #: than the room's: a room may hold two or three waves, but the
    #: player fights them one at a time.
    count: int = Field(ge=1, le=C.MAX_ENEMIES_PER_ENCOUNTER)


class AffordanceFeature(Strict):
    """One optional world feature a Zone may offer (ECHOES.md §13).

    Optional is the whole point. A feature may never lie on the mandatory
    path, host an AP reward, an exit or an objective — §13.2, enforced by
    `validate_zone` rather than by good intentions — so a Zone with every
    feature stripped out is still completable with the base kit. That is
    what makes affordances safe to generate against a campaign whose
    capabilities the generator cannot fully predict.
    """
    tag: AffordanceTag
    #: Where in the chamber, as a fraction of its extent. The builder owns
    #: metres; a generator that could name a coordinate could name one
    #: inside the exit lane.
    at: tuple[float, float] = ((0.5, 0.5))
    note: str | None = Field(default=None, max_length=C.MAX_TEXT_LEN)

    @model_validator(mode="after")
    def _inside_the_chamber(self):
        for value in self.at:
            if not 0.0 <= value <= 1.0:
                raise ValueError(
                    f"affordance position {self.at} is outside the chamber"
                )
        return self


class ChamberBase(Strict):
    id: str = _ID
    flavor: str | None = Field(default=None, max_length=C.MAX_TEXT_LEN)
    reward_location_id: int | None = Field(
        default=None, ge=C.FIRST_LOCATION_ID, le=C.LAST_LOCATION_ID
    )
    #: S9. Additive and optional: a Zone generated before affordances
    #: existed is still a valid Zone, which is why `schema_version` stays
    #: 7 — bumping it would fail every Zone already inside a save for a
    #: change that requires nothing and removes nothing.
    features: tuple[AffordanceFeature, ...] = Field(default=(), max_length=3)

    #: CAMPAIGN_SCALE.md 7: a complex room may carry more than one Check.
    #:
    #: Additive for the same reason `features` was — Zones live inside
    #: saves, so a new REQUIRED field would fail every campaign in
    #: progress. `reward_location_id` keeps its meaning; this holds the
    #: rest. Nothing reads either directly: `reward_ids` below is the one
    #: canonical view, and a test asserts no consumer goes around it.
    #:
    #: Bounded low on purpose. Two or three Checks in a genuinely large
    #: room correspond to distinct activities; fifteen in one room is the
    #: warehouse of pedestals CAMPAIGN_SCALE.md 5 forbids, and this is
    #: the cheap structural half of preventing it.
    additional_reward_location_ids: tuple[int, ...] = Field(
        default=(), max_length=2)

    #: D1: authored-shell selection. Epsilon names INTENT, and may pick a
    #: shell id out of the legal catalog it was handed. It never names
    #: metres for an authored shell, and it never names a path -- the
    #: charset here makes the second unspellable rather than merely
    #: discouraged (S19).
    #:
    #: All three are optional and additive. A chamber with none of them
    #: is the procedural path exactly as before, which is why the
    #: continuous `width`/`length`/`gap_size` fields below are untouched:
    #: D1 keeps the safe numeric generator for the fallback and layers
    #: semantic selection on top for authored content.
    shell_id: str | None = Field(
        default=None, max_length=48, pattern=r"^[a-z0-9_]+$")
    size_class: Literal["small", "medium", "large"] | None = None
    intent: tuple[Annotated[str, Field(
        min_length=1, max_length=24, pattern=r"^[a-z0-9_]+$")], ...] = Field(
        default=(), max_length=4)

    @property
    def reward_ids(self) -> tuple[int, ...]:
        """Every AP Check this chamber holds, in a stable order.

        THE canonical view. `reward_location_id` and
        `additional_reward_location_ids` are storage shapes kept apart so
        that saves written before multi-Check rooms still load; nothing
        outside this class should read either one.
        """
        first = () if self.reward_location_id is None \
            else (self.reward_location_id,)
        return first + tuple(self.additional_reward_location_ids)

    @model_validator(mode="after")
    def _each_check_is_its_own_check(self):
        """A Check must be earned once, by one thing.

        Two ids sharing a completion edge would send both the moment
        either was earned -- which is not a duplicate, it is Archipepsi
        telling the multiworld a player found an item they never reached.
        Distinctness is the cheap half; the expensive half is that each
        needs its own acquisition condition, which is the room builder's.
        """
        ids = self.reward_ids
        if len(set(ids)) != len(ids):
            raise ValueError(
                f"chamber '{self.id}' lists Check "
                f"{sorted(i for i in ids if ids.count(i) > 1)[0]} twice; "
                "two ids sharing one completion edge would send a Check "
                "the player never earned")
        if self.reward_location_id is None and \
                self.additional_reward_location_ids:
            raise ValueError(
                f"chamber '{self.id}' has additional Checks but no first "
                "one; `reward_location_id` is the primary, so extras "
                "without it would be invisible to anything reading only "
                "the original field")
        return self

    @model_validator(mode="after")
    def _features_sit_clear_of_the_walking_lane(self):
        """The geometric proof, now applied to EVERY chamber that can hold
        a feature rather than only to corridors.

        `FEATURE_MIN_WIDTH` is `2 * (lane + 2 * reach + wall clearance)`
        per tag: a width covering it is a width with somewhere to put the
        feature that is neither in the masonry nor across the route. That
        is the real statement of "an affordance is never on the mandatory
        path", and it used to run on corridors only -- so every other room
        type got a blanket ban instead (CAMPAIGN_SCALE.md 7).
        """
        width = getattr(self, "width", None)
        if width is None:
            width = getattr(self, "side", None)
        if width is None:
            return self
        for feature in self.features:
            needed = C.FEATURE_MIN_WIDTH.get(
                feature.tag, C.MIN_FEATURE_CHAMBER_WIDTH)
            if width < needed:
                raise ValueError(
                    f"chamber '{self.id}' is {width}m wide and carries "
                    f"a '{feature.tag}', which needs {needed}m to sit clear "
                    "of the walking lane on both sides (ECHOES.md 13.2); "
                    "widen the room or offer a smaller feature"
                )
        return self

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

    @model_validator(mode="after")
    def _features_need_room_beside_the_path(self):
        """A corridor is the only chamber type that may carry a feature —
        every other type has either a Check or a gating objective — and it
        is also the narrowest. One barely wider than its door is entirely
        walking lane, so a feature in it would end up in the masonry or
        across the doorway. Refused here rather than dropped by the
        builder: a silently discarded feature is a Zone that reads richer
        than it plays, and a refusal is something the repair loop can fix.
        """
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

        # The PERFORMANCE ceiling only. How many enemies a Zone may hold
        # by DESIGN depends on its content budget, which is campaign
        # config and not visible from inside a model -- that check lives
        # in `validate_zone`, which has it.
        #
        # Splitting them this way is the point of CAMPAIGN_SCALE.md 8: a
        # design that wants more than the engine can hold is wrong about
        # the target machine and should fail here regardless of budget,
        # while a design that merely wants more than its Zone was paid
        # for is a budget question.
        total = sum(c.enemy_total for c in self.chambers)
        if total > C.MAX_ENEMIES_SPAWNED_CAP:
            raise ValueError(
                f"zone instantiates {total} enemies, past the engine cap "
                f"of {C.MAX_ENEMIES_SPAWNED_CAP}"
            )

        rewards = self.reward_location_ids
        if len(set(rewards)) != len(rewards):
            raise ValueError("duplicate reward_location_id")

        # §13.2 used to be enforced by keeping affordances and rewards in
        # SEPARATE ROOMS. That was the cheapest possible proof that no
        # feature sits between the player and a Check, and it made every
        # reward room sterile: no rails, no grapple, no bounce pad, in the
        # rooms most worth having them (CAMPAIGN_SCALE.md 7).
        #
        # The invariant is unchanged. The proof moved:
        #
        #   - `_features_sit_clear_of_the_walking_lane` (ChamberBase) is
        #     the geometric half, and now runs on every chamber type
        #     rather than only corridors.
        #   - the ownership half stays in `validate_zone`, which has the
        #     campaign and can ask what the player actually has.
        #   - the instantiated half is `godot-legible`, which walks the
        #     built room and checks the reward is reachable with base
        #     movement while the feature is not on the way.
        #
        # Optional capabilities may shortcut, flank and decorate. They may
        # never be REQUIRED for a Check, an objective or the exit.
        return self

    @property
    def reward_location_ids(self) -> list[int]:
        """Every Check in the Zone, across all its rooms."""
        return [rid for c in self.chambers for rid in c.reward_ids]


# ---------------------------------------------------------------------------
# Semantic validation
# ---------------------------------------------------------------------------

def validate_zone(
    zone: Zone,
    *,
    expected_zone_id: str,
    allocated_location_ids: list[int],
    owned_echo_ids: list[str],
    owned_affordance_tags: tuple[str, ...] = (),
    legal_shell_ids: tuple[str, ...] = (),
    zone_budget: int | None = None,
) -> list[str]:
    """Check a structurally-valid Zone against its request.

    Returns [] if acceptable, else concise errors for the repair request.
    Never mutates: v0.5 rejects and repairs rather than clamping, so an
    accepted Zone is always something Epsilon actually chose.

    `zone_budget` is the content the campaign asked for
    (CAMPAIGN_SCALE.md 5). Pass None to skip the check -- which is what a
    campaign generated before budgets existed does, and NOT a way for a
    caller to opt out of it. The value scored is recomputed here from the
    accepted components; nothing the provider sent is read as a score.
    """
    errors: list[str] = []

    # Enemy counts scale with the Zone's content budget: a longer level
    # holds more enemies OVER TIME. `MAX_ENEMIES_ACTIVE` is what bounds
    # the moment, and it does not scale.
    #
    # No budget means a campaign generated before budgets existed, so it
    # gets the prototype's caps rather than none -- "optional" must not
    # be how a limit stops being enforced.
    combat_budget = (zone_budget if zone_budget is not None
                     else C.PROTOTYPE_CONFIG.zone_budget)
    enemy_cap = C.max_enemies_per_zone(combat_budget)
    total_enemies = sum(c.enemy_total for c in zone.chambers)
    if total_enemies > enemy_cap:
        errors.append(
            f"zone has {total_enemies} enemies, limit is {enemy_cap} for a "
            f"{combat_budget}-point Zone")
    brute_cap = C.max_brutes_per_zone(combat_budget)
    brutes = sum(c.brute_total for c in zone.chambers)
    if brutes > brute_cap:
        errors.append(
            f"zone has {brutes} brutes, limit is {brute_cap} for a "
            f"{combat_budget}-point Zone")

    if zone_budget is not None:
        from ..composition import composition_errors
        from ..content_value import budget_errors
        errors.extend(budget_errors(zone, zone_budget))
        # A Zone that holds enough content can still be a hundred
        # identical rooms (CAMPAIGN_SCALE.md 6). Budget is necessary and
        # not sufficient, so both run.
        errors.extend(composition_errors(zone, zone_budget))

    # D1: Epsilon may SELECT among the authored shells it was offered,
    # and only those. The catalog is handed to it in the request; a shell
    # id outside it is either a hallucination or a shell this campaign
    # cannot use, and both produce a zone that cannot be built. Selection
    # is real agency; invention is not.
    #
    # An empty catalog means the campaign offered no authored shells, so
    # naming any is wrong -- rather than meaning "anything goes", which
    # is the reading that would let a hallucinated id through on exactly
    # the runs where nothing was offered.
    for chamber in zone.chambers:
        if chamber.shell_id is None:
            continue
        if chamber.shell_id not in legal_shell_ids:
            errors.append(
                f"chamber '{chamber.id}' selects shell "
                f"'{chamber.shell_id}', which was not offered; choose "
                f"from {sorted(legal_shell_ids)}"
                + ("" if legal_shell_ids
                   else " (no authored shells were offered for this Zone)"))

    # I12: a feature the campaign cannot interact with is set dressing
    # that looks like content, which §13.1 says is worse than nothing.
    # Evaluated over OWNED capability, never equipped — you own the
    # grapple whether or not it is slotted, and you can always slot it.
    for chamber in zone.chambers:
        for feature in chamber.features:
            if feature.tag not in owned_affordance_tags:
                errors.append(
                    f"chamber '{chamber.id}' offers a '{feature.tag}', "
                    f"which this campaign has no capability to use; "
                    f"offer one of {sorted(owned_affordance_tags)} or none"
                )

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
