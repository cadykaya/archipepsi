"""Archipepsi v0.8 — Echo contract.

This module IS the Echo specification. `ECHOES.md` is its prose.

An Echo is no longer a thing you equip. It is an **interpretation** of one
foreign Archipelago item, and it contributes **components**:

    Action      needs a button; occupies one of four slots
    Trait       continuous modifier of a derived stat
    Resource    a HUD channel with its own economy
    Rule        EVENT -> CONDITIONS -> COST -> EFFECTS
    Status      a bounded named condition, on self or on enemies
    Affordance  a tag that widens the level generator's grammar
    Info        a readout

Only Actions occupy a slot. Everything else is true once owned, which is why
a Check can matter for the rest of the run without ever being equipped.

An interpretation carries 1-4 **operations**, and this is where build
evolution comes from: `CREATE` introduces a component, while `UPGRADE`,
`MODIFY`, `LINK` and `MERGE` target something the campaign already owns. The
live mechanical state is a pure fold over the interpretation log in
`interpretation_seq` order — see `mechanics.py`, which is the executable half
of this contract.

What v0.7 got right and v0.8 keeps:

- Structural rules beat validators that have to be remembered. "Exactly one
  primitive per Action" is arity (a field), not a count check, so a provider
  driven by structured output cannot emit two.
- `extra="forbid"` everywhere, so an invented field is rejected outright
  rather than dropped silently.
- Out-of-bounds values are rejected, never clamped.

What v0.8 adds structurally:

- `interpretation_seq` is the ONLY fold ordering. Location ids come from
  Archipelago, not from the order you find them, so ordering by them can
  replay an interpretation before the component it targets exists.
- Movement traits are floored at base. No combination of owned components
  may leave the player worse at clearing a gap than the base kit, so
  `max_safe_gap` stays valid unmodified.
"""

from __future__ import annotations

import math

from typing import Annotated, Literal, Union

from pydantic import BaseModel, ConfigDict, Field, model_validator

try:
    from . import constants as C
except ImportError:  # pragma: no cover
    import constants as C

SCHEMA_VERSION = 8


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


# ---------------------------------------------------------------------------
# Identifiers
# ---------------------------------------------------------------------------

#: Component ids are prefixed by kind so a malformed target is a parse error
#: rather than a runtime surprise, and so a human reading a log can tell what
#: an operation is pointing at.
COMPONENT_ID_PATTERN = r"^(act|trait|res|rule|status|aff|info)_[a-z0-9_]{1,24}$"
ComponentId = Annotated[
    str, Field(min_length=5, max_length=32, pattern=COMPONENT_ID_PATTERN)
]

_NAME = Field(min_length=1, max_length=C.MAX_TEXT_LEN)
_AP_STR = Field(min_length=1, max_length=C.MAX_AP_STRING_LEN)


# ---------------------------------------------------------------------------
# Action primitives — the closed catalog (ECHOES.md 6)
#
# 28 primitives: 3 close combat, 6 ranged, 10 movement, 5 defensive,
# 4 utility. `check_packet.py` derives that count from ACTION_PRIMITIVES and
# fails if the prose disagrees, so the catalog cannot drift.
#
# Force fields are instantaneous velocity change in m/s applied to the
# character body — not an impulse in newtons and not an acceleration.
# ---------------------------------------------------------------------------

# -- close combat -----------------------------------------------------------

class MeleeSwing(Strict):
    type: Literal["melee_swing"]
    damage: float = Field(ge=1, le=40)
    reach: float = Field(ge=1.0, le=3.5)
    arc_degrees: float = Field(ge=20, le=160)


class MeleeThrust(Strict):
    type: Literal["melee_thrust"]
    damage: float = Field(ge=1, le=55)
    reach: float = Field(ge=1.5, le=5.0)


class SlamGround(Strict):
    type: Literal["slam_ground"]
    damage: float = Field(ge=1, le=45)
    radius: float = Field(ge=1.5, le=7.0)
    #: Downward velocity change on activation, in m/s.
    descent_force: float = Field(ge=4, le=30)


# -- ranged -----------------------------------------------------------------

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
    gravity_scale: float = Field(default=0.0, ge=0.0, le=1.0)
    bounces: int = Field(default=0, ge=0, le=4)


class ArcLob(Strict):
    type: Literal["arc_lob"]
    damage: float = Field(ge=1, le=45)
    radius: float = Field(ge=1.0, le=6.0)
    #: Launch velocity in m/s; the projectile is fully gravity-affected.
    launch_force: float = Field(ge=6, le=30)
    fuse: float = Field(ge=0.4, le=5.0)


class BurstFire(Strict):
    type: Literal["burst_fire"]
    damage: float = Field(ge=1, le=18)
    shots: int = Field(ge=2, le=8)
    #: Seconds between shots inside one burst.
    interval: float = Field(ge=0.04, le=0.4)
    spread_degrees: float = Field(ge=0, le=20)
    range: float = Field(ge=5, le=60)


class ChargeShot(Strict):
    type: Literal["charge_shot"]
    #: Damage and speed interpolate from min to max over `charge_time`.
    min_damage: float = Field(ge=1, le=20)
    max_damage: float = Field(ge=1, le=60)
    charge_time: float = Field(ge=0.3, le=3.0)
    speed: float = Field(ge=10, le=60)

    @model_validator(mode="after")
    def _max_beats_min(self):
        if self.max_damage < self.min_damage:
            raise ValueError("charge_shot max_damage is below min_damage")
        return self


class BeamSustained(Strict):
    """Continuous damage while held.

    An unlimited beam is a movement contract rather than an ability, so this
    primitive is only legal with a `powers` link to a resource. That rule is
    enforced by `mechanics.derive_mechanics`, where the links are known.
    """
    type: Literal["beam_sustained"]
    damage_per_second: float = Field(ge=2, le=45)
    range: float = Field(ge=5, le=45)
    #: Resource units drained per second while held.
    drain_per_second: float = Field(ge=1, le=60)


# -- movement ---------------------------------------------------------------

class Dash(Strict):
    type: Literal["dash"]
    #: Instantaneous velocity change in m/s, along view-forward.
    force: float = Field(ge=4, le=20)


class AirDash(Strict):
    type: Literal["air_dash"]
    force: float = Field(ge=4, le=22)
    uses_per_airtime: int = Field(ge=1, le=3)


class DoubleJump(Strict):
    type: Literal["double_jump"]
    #: Upward velocity change in m/s. Bounded above the base jump so the
    #: extra jump is never *weaker* than the one the base kit already has.
    force: float = Field(ge=C.JUMP_VELOCITY * 0.6, le=C.JUMP_VELOCITY * 1.4)
    extra_jumps: int = Field(ge=1, le=2)


class WallKick(Strict):
    type: Literal["wall_kick"]
    force: float = Field(ge=5, le=18)
    #: Fraction of the kick directed away from the wall rather than upward.
    outward_fraction: float = Field(ge=0.1, le=0.8)


class Hover(Strict):
    """Reduced gravity while held. Requires a `powers` link, like the beam."""
    type: Literal["hover"]
    gravity_multiplier: float = Field(ge=0.0, le=0.6)
    drain_per_second: float = Field(ge=1, le=60)
    max_duration: float = Field(ge=0.5, le=8.0)


class Glide(Strict):
    type: Literal["glide"]
    #: Terminal fall speed while gliding, in m/s.
    fall_speed: float = Field(ge=0.5, le=6.0)
    forward_speed: float = Field(ge=2, le=16)


class Blink(Strict):
    """Instant translation along a validated ray to a surface hit.

    Never free-space: the runtime casts along aim, requires a hit, steps back
    from the surface by the player radius, and clearance-tests the landing
    point. Free-space teleport is an out-of-bounds bug waiting to be written.
    """
    type: Literal["blink"]
    range: float = Field(ge=3, le=25)
    #: Clearance required at the landing point, in metres.
    clearance: float = Field(default=C.PLAYER_RADIUS, ge=C.PLAYER_RADIUS, le=1.5)


class GrappleToSurface(Strict):
    type: Literal["grapple_to_surface"]
    range: float = Field(ge=5, le=35)
    #: Instantaneous velocity change in m/s, toward the hit point.
    pull_force: float = Field(ge=4, le=25)


class GrapplePullTarget(Strict):
    type: Literal["grapple_pull_target"]
    range: float = Field(ge=5, le=35)
    pull_force: float = Field(ge=4, le=25)
    #: Enemies at or below this HP maximum can be pulled; a brute cannot.
    max_target_hp: float = Field(ge=1, le=60)


class GrappleSwing(Strict):
    type: Literal["grapple_swing"]
    range: float = Field(ge=5, le=35)
    tether_force: float = Field(ge=4, le=25)
    max_duration: float = Field(ge=0.5, le=6.0)


# -- defensive --------------------------------------------------------------

class Shield(Strict):
    type: Literal["shield"]
    amount: float = Field(ge=5, le=80)
    duration: float = Field(ge=1, le=15)


class Block(Strict):
    type: Literal["block"]
    #: Fraction of incoming damage removed while held.
    reduction: float = Field(ge=0.1, le=0.9)
    drain_per_second: float = Field(ge=1, le=40)


class Parry(Strict):
    type: Literal["parry"]
    #: Seconds of active window. A hit inside it emits `parry_success`.
    window: float = Field(ge=0.08, le=0.6)


class HealSelf(Strict):
    type: Literal["heal_self"]
    amount: float = Field(ge=5, le=60)


class Cleanse(Strict):
    type: Literal["cleanse"]
    #: How many active statuses are removed, worst-first.
    count: int = Field(ge=1, le=4)


# -- utility ----------------------------------------------------------------

class ScanMark(Strict):
    type: Literal["scan_mark"]
    range: float = Field(ge=5, le=60)
    duration: float = Field(ge=2, le=30)


class RestoreResource(Strict):
    """The primitive that turns a consumable into a button.

    It names no resource: the `fills` link says which one, so a later
    interpretation can point it somewhere else without rewriting this one.
    """
    type: Literal["restore_resource"]
    amount: float = Field(ge=1, le=200)


class PullPickup(Strict):
    type: Literal["pull_pickup"]
    radius: float = Field(ge=2, le=20)


class PlaceMarker(Strict):
    type: Literal["place_marker"]
    duration: float = Field(ge=5, le=300)


ActionPrimitive = Annotated[
    Union[
        MeleeSwing, MeleeThrust, SlamGround,
        HitscanDamage, ProjectileDamage, ArcLob, BurstFire, ChargeShot,
        BeamSustained,
        Dash, AirDash, DoubleJump, WallKick, Hover, Glide, Blink,
        GrappleToSurface, GrapplePullTarget, GrappleSwing,
        Shield, Block, Parry, HealSelf, Cleanse,
        ScanMark, RestoreResource, PullPickup, PlaceMarker,
    ],
    Field(discriminator="type"),
]

CLOSE_COMBAT_PRIMITIVES = ("melee_swing", "melee_thrust", "slam_ground")
RANGED_PRIMITIVES = (
    "hitscan_damage", "projectile_damage", "arc_lob", "burst_fire",
    "charge_shot", "beam_sustained",
)
MOVEMENT_PRIMITIVES = (
    "dash", "air_dash", "double_jump", "wall_kick", "hover", "glide",
    "blink", "grapple_to_surface", "grapple_pull_target", "grapple_swing",
)
DEFENSIVE_PRIMITIVES = ("shield", "block", "parry", "heal_self", "cleanse")
UTILITY_PRIMITIVES = (
    "scan_mark", "restore_resource", "pull_pickup", "place_marker",
)

#: The whole catalog, in catalog order. `check_packet.py` asserts the prose
#: count against `len(ACTION_PRIMITIVES)`.
ACTION_PRIMITIVES = (
    CLOSE_COMBAT_PRIMITIVES + RANGED_PRIMITIVES + MOVEMENT_PRIMITIVES
    + DEFENSIVE_PRIMITIVES + UTILITY_PRIMITIVES
)

#: Primitives the ENGINE can actually execute today. The schema declares the
#: whole catalog because the contract is the contract; the runtime catches up
#: stage by stage, and validation refuses anything it cannot honour rather
#: than accepting an Action that silently does nothing.
#:
#: S1 implemented exactly what v0.7 implemented: six verbs. S2 opens the
#: catalog to every primitive whose dependencies actually exist, which is 21
#: of the 28.
#:
#: The remaining seven are held back by a *stage*, not by an oversight, and
#: each names the one that unblocks it. Listing them here rather than
#: quietly omitting them is the point: a primitive missing from this tuple
#: with no stated reason is indistinguishable from a primitive somebody
#: forgot, and `test_schemas.py` asserts this partition covers the catalog
#: exactly, so a new primitive cannot be added without landing on one side.
#:
#: Each names the stage that actually unblocks it, which is the LATEST of
#: its dependencies rather than the first. S2 shipped this list naming S3
#: for the four resource-hungry verbs; that was wrong, and wrong in the
#: direction that misleads — a Resource alone does not make any of them
#: runnable, because none of them names the resource it uses. `powers` and
#: `fills` are LINK kinds, and links land in S5 (`IMPLEMENTATION_PLAN.md`
#: §2.5, "Traits, links, statuses"). So S3 un-gates nothing here, and
#: saying otherwise sets someone up to finish S3 and wonder why four verbs
#: are still refused.
#:
#:   beam_sustained, hover, block   S5 — POWERED_PRIMITIVES: need a Resource
#:                                  (S3) AND a `powers` link to drain it.
#:   restore_resource               S5 — needs a Resource (S3) AND a `fills`
#:                                  link, because it names no resource itself.
#:   scan_mark, cleanse             S5 — both are statuses: one applies
#:                                  `marked`, the other removes statuses.
#:   pull_pickup                    S9 — local rewards are the only thing it
#:                                  is allowed to touch, and they land there.
IMPLEMENTED_PRIMITIVES = (
    # close combat
    "melee_swing", "melee_thrust", "slam_ground",
    # ranged
    "hitscan_damage", "projectile_damage", "arc_lob", "burst_fire",
    "charge_shot", "beam_sustained",
    # movement
    "dash", "air_dash", "double_jump", "wall_kick", "hover", "glide",
    "blink", "grapple_to_surface", "grapple_pull_target", "grapple_swing",
    # defensive
    "shield", "block", "parry", "heal_self", "cleanse",
    # utility
    "scan_mark", "restore_resource", "pull_pickup", "place_marker",
)

#: Why each still-gated primitive is gated, and the stage that lands it.
#: Paired with `IMPLEMENTED_PRIMITIVES` so the two together must account for
#: every entry in the catalog — see `test_schemas.py`.
#: Empty since S9, and kept rather than deleted: the tuple pair is what
#: `test_schemas.py` partitions the catalog with, and an empty half is the
#: honest way to say "every verb runs" — deleting it would make the
#: partition test vacuous instead of true.
DEFERRED_PRIMITIVES: dict[str, str] = {}

#: Primitives that are meaningless without something to spend, so a `powers`
#: link is mandatory rather than encouraged.
POWERED_PRIMITIVES = ("beam_sustained", "hover", "block")

DAMAGE_PRIMITIVES = (
    "melee_swing", "melee_thrust", "slam_ground", "hitscan_damage",
    "projectile_damage", "arc_lob", "burst_fire", "charge_shot",
    "beam_sustained",
)


# ---------------------------------------------------------------------------
# Modifiers — attached to an Action, and meaningless without something that hits
# ---------------------------------------------------------------------------

class RecoilSelf(Strict):
    type: Literal["recoil_self"]
    #: Instantaneous velocity change in m/s, opposite aim.
    force: float = Field(ge=0, le=16)


class KnockbackTarget(Strict):
    type: Literal["knockback_target"]
    #: Instantaneous velocity change in m/s, away from the attack source.
    force: float = Field(ge=0, le=16)


class ApplyStatusOnHit(Strict):
    """How *Fire Flower* becomes an upgrade to a gun you already own."""
    type: Literal["apply_status_on_hit"]
    status: Literal[
        "burning", "slowed", "frozen", "shocked", "poisoned", "marked",
        "stunned", "vulnerable",
    ]
    duration: float = Field(ge=0.5, le=12)
    magnitude: float = Field(ge=0.05, le=3.0)


Modifier = Annotated[
    Union[RecoilSelf, KnockbackTarget, ApplyStatusOnHit],
    Field(discriminator="type"),
]
MODIFIER_TYPES = ("recoil_self", "knockback_target", "apply_status_on_hit")


# ---------------------------------------------------------------------------
# Rules — EVENT -> CONDITIONS -> COST -> EFFECTS
#
# Events are emitted by the engine ONLY, and no effect emits an event, so a
# rule can never trigger another rule inside one dispatch. Threshold events
# are derived at end of tick, on the crossing edge, and deferred at least one
# tick. See ECHOES.md 5.1 and TECHNICAL_ARCHITECTURE.md 14.
# ---------------------------------------------------------------------------

EventKind = Literal[
    "zone_enter", "chamber_enter", "jump", "land", "dash_end", "kill",
    "damage_dealt", "damage_taken", "action_used", "action_ready",
    "parry_success", "check_claimed", "tick_1hz", "resource_full",
    "resource_empty", "low_health", "status_applied",
]

#: Derived by the engine from state at end of tick rather than raised at the
#: moment state changes. Listed separately because the deferral rule applies
#: to exactly these.
EDGE_EVENTS = (
    "resource_full", "resource_empty", "low_health", "status_applied",
)

ConditionKind = Literal[
    "resource_at_least", "resource_at_most", "hp_below", "hp_above",
    "moving_backward", "airborne", "grounded", "speed_above",
    "enemy_within", "slot_is", "zone_is_finale", "status_active",
]

StatusKind = Literal[
    "burning", "slowed", "frozen", "shocked", "poisoned", "marked",
    "stunned", "vulnerable", "empowered", "low_profile", "haste",
    "regenerating",
]

TraitStat = Literal[
    "move_speed", "jump_height", "gravity", "air_control", "ground_friction",
    "damage_dealt", "damage_taken", "knockback_resist", "regen",
]

#: The stats the platforming derivation depends on. A trait may never leave
#: any of these worse than base, which is what keeps `max_safe_gap` valid
#: without recomputation (ECHOES.md 10).
TRAVERSAL_STATS = ("move_speed", "jump_height", "gravity", "air_control")

#: I7's mild band: the largest harmful deviation from base an ALWAYS-ON
#: component may carry. Anything worse must declare `requires_equipped`.
MILD_DOWNSIDE_LIMIT = 1.0 / 3.0


class Condition(Strict):
    type: ConditionKind
    #: Names a resource for the resource conditions, a status for
    #: `status_active`, a slot for `slot_is`. Unused otherwise.
    subject: str | None = Field(default=None, max_length=32)
    #: Fraction for hp/resource comparisons, metres for `enemy_within`,
    #: m/s for `speed_above`. Unused by the flag conditions.
    value: float = Field(default=0.0, ge=0.0, le=100.0)


class ResourceCost(Strict):
    resource_id: ComponentId
    amount: float = Field(gt=0, le=200)


EffectKind = Literal[
    "resource_add", "heal", "grant_shield", "impulse_self", "trait_pulse",
    "damage_around", "fire_projectile", "apply_status",
    "reset_action_cooldown", "refill_resource", "grant_local_reward",
]

ImpulseDirection = Literal["aim", "forward", "backward", "up", "velocity"]


class Effect(Strict):
    type: EffectKind
    #: A resource id, a stat name, a status name or a local-reward kind,
    #: depending on `type`.
    subject: str | None = Field(default=None, max_length=32)
    amount: float = Field(default=0.0, ge=-200.0, le=200.0)
    duration: float = Field(default=0.0, ge=0.0, le=60.0)
    radius: float = Field(default=0.0, ge=0.0, le=20.0)
    direction: ImpulseDirection | None = None


LOCAL_REWARD_KINDS = (
    "epsilon_note", "challenge_marker", "cosmetic_grant", "hub_decoration",
    "lab_fixture", "flavor_log",
)

AFFORDANCE_TAGS = (
    "grapple_anchor", "breakable_wall", "water_volume", "rail",
    "wind_volume", "bounce_pad", "moving_platform",
)

READOUT_KINDS = (
    "enemy_health", "enemy_radar", "threat_direction", "secret_ping",
    "affordance_highlight", "trajectory_preview", "damage_numbers",
    "resource_forecast", "speedometer", "challenge_timer",
)

#: The contextual budgets from ECHOES.md §16, as (soft, hard).
#:
#: Soft steers: over it, the request asks Epsilon for `UPGRADE` / `MODIFY` /
#: `LINK` / `MERGE` instead of another `CREATE`. Hard refuses: `CREATE` is
#: rejected and the existing repair-once loop runs. `None` means no hard
#: ceiling — owned Actions are unbounded because only four can be slotted,
#: so the twelfth one costs screen space rather than balance.
#:
#: These are campaign totals, so they cannot be checked against one Echo in
#: isolation the way every other rule in this module can. `budget_errors`
#: takes the folded mechanics and is called at grant time.
COMPLEXITY_BUDGETS: dict[str, tuple[int, int | None]] = {
    "resource": (6, 15),
    "action": (12, None),
    "rule": (14, 20),
    "affordance": (8, 12),
    "info": (3, 5),
}

#: Fifteen pre-laid HUD channels. Godot owns every pixel of them; Epsilon
#: owns which one is alive and what it means. Named here because the hard
#: resource budget IS the channel count -- a sixteenth resource would have
#: nowhere to render, so the two must never drift apart.
HUD_CHANNELS = COMPLEXITY_BUDGETS["resource"][1]

#: Closed palette for resource fills. Named rather than hex so the client
#: owns the actual light/dark pairs and a chosen colour is legible on both
#: grounds — and so it can never collide with the HUD's reserved semantics.
PALETTE_COLORS = (
    "moss", "signal", "ember", "violet", "bone", "rust", "tide", "sulphur",
)

#: One definition, in `constants.py`, because the client builds a runtime
#: per slot from the exported copy. The Literal below has to be spelled
#: out — a type cannot be built from a runtime tuple — so a test asserts
#: the two agree.
SLOT_NAMES = C.SLOT_NAMES
SlotName = Literal["echo_a", "echo_b", "mobility", "utility"]


# ---------------------------------------------------------------------------
# Components
# ---------------------------------------------------------------------------

class ComponentBase(Strict):
    component_id: ComponentId
    display_name: str = _NAME
    description: str = _NAME


class ActionComponent(ComponentBase):
    """A verb on a slot. Exactly one primitive, by arity."""
    kind: Literal["action"]
    slot: SlotName
    cooldown: float = Field(ge=C.ECHO_COOLDOWN_MIN, le=C.ECHO_COOLDOWN_MAX)
    primitive: ActionPrimitive
    modifiers: tuple[Modifier, ...] = Field(default=(), max_length=2)

    @model_validator(mode="after")
    def _modifiers_need_something_that_hits(self):
        kinds = [m.type for m in self.modifiers]
        if len(set(kinds)) != len(kinds):
            raise ValueError("duplicate modifier effect")
        if kinds and self.primitive.type not in DAMAGE_PRIMITIVES:
            raise ValueError(
                f"'{kinds[0]}' requires a damage primitive; found "
                f"'{self.primitive.type}'"
            )
        return self


class TraitComponent(ComponentBase):
    kind: Literal["trait"]
    stat: TraitStat
    multiplier: float = Field(ge=0.1, le=4.0)
    #: A resource id, `hp_fraction` or `hp_inverse`. The trait interpolates
    #: from 1.0 to `multiplier` across that fraction.
    scaled_by: str | None = Field(default=None, max_length=32)
    #: Set when the trait only applies while a given Action is slotted. A
    #: severe downside MUST set this — enforced by the validator below.
    requires_equipped: ComponentId | None = None

    @model_validator(mode="after")
    def _traversal_stats_may_only_help(self):
        """The floor that keeps every generated jump valid.

        A trait on a traversal stat may never make the player worse than
        base. v0.7 bounded each Echo separately and got away with it because
        one applied at a time; v0.8 traits are always on and stack across
        everything owned, so the rule has to be blunter.
        """
        if self.stat not in TRAVERSAL_STATS:
            return self
        if self.stat == "gravity":
            if self.multiplier > 1.0:
                raise ValueError(
                    "a gravity trait may only ever make the player lighter "
                    f"(multiplier {self.multiplier} > 1.0)"
                )
        elif self.multiplier < 1.0:
            raise ValueError(
                f"a '{self.stat}' trait may not fall below base "
                f"(multiplier {self.multiplier} < 1.0)"
            )
        return self

    @model_validator(mode="after")
    def _severe_downsides_must_be_removable(self):
        """I7: permanent means mild; severe means removable (ECHOES 10).

        A downside is a non-traversal multiplier in the harmful direction:
        under base for ground_friction, damage_dealt, knockback_resist and
        regen; over base for damage_taken. Beyond the mild band it must be
        bound to an Action the player can take off. The band is a third of
        base — wide enough for Iron Boots to feel heavy while equipped,
        narrow enough that an always-on curse never decides a fight.
        """
        if self.requires_equipped is not None or self.stat in TRAVERSAL_STATS:
            return self
        harmful = 0.0
        if self.stat == "damage_taken":
            harmful = self.multiplier - 1.0
        else:
            harmful = 1.0 - self.multiplier
        if harmful > MILD_DOWNSIDE_LIMIT:
            raise ValueError(
                f"an always-on '{self.stat}' trait at {self.multiplier} is "
                "a severe downside; bind it to an Action with "
                "requires_equipped, or soften it past the mild bound"
            )
        return self


class ResourceComponent(ComponentBase):
    kind: Literal["resource"]
    max_value: float = Field(gt=0, le=1000)
    initial_fraction: float = Field(ge=0.0, le=1.0)
    #: Negative is decay. Momentum is a resource with a negative regen.
    regen_per_second: float = Field(default=0.0, ge=-100.0, le=100.0)
    regen_delay: float = Field(default=0.0, ge=0.0, le=10.0)
    presentation: Literal["bar", "pips", "counter"]
    pip_count: int | None = Field(default=None, ge=1, le=12)
    palette_color: Literal[
        "moss", "signal", "ember", "violet", "bone", "rust", "tide", "sulphur"
    ]

    @model_validator(mode="after")
    def _pips_declare_their_count(self):
        if self.presentation == "pips" and self.pip_count is None:
            raise ValueError("a pips resource must declare pip_count")
        if self.presentation != "pips" and self.pip_count is not None:
            raise ValueError("pip_count is only meaningful for pips")
        return self


class RuleComponent(ComponentBase):
    kind: Literal["rule"]
    event: EventKind
    conditions: tuple[Condition, ...] = Field(default=(), max_length=3)
    costs: tuple[ResourceCost, ...] = Field(default=(), max_length=2)
    effects: tuple[Effect, ...] = Field(min_length=1, max_length=3)
    #: Mandatory, and floored: without it a rule pair can oscillate every
    #: tick. See ECHOES.md 5.1.
    cooldown: float = Field(ge=0.1, le=30.0)


class StatusComponent(ComponentBase):
    kind: Literal["status"]
    status: StatusKind
    target: Literal["self", "enemy"]
    duration: float = Field(ge=0.5, le=30.0)
    magnitude: float = Field(ge=0.05, le=3.0)


class AffordanceComponent(ComponentBase):
    kind: Literal["affordance"]
    tag: Literal[
        "grapple_anchor", "breakable_wall", "water_volume", "rail",
        "wind_volume", "bounce_pad", "moving_platform",
    ]


class InfoComponent(ComponentBase):
    kind: Literal["info"]
    readout: Literal[
        "enemy_health", "enemy_radar", "threat_direction", "secret_ping",
        "affordance_highlight", "trajectory_preview", "damage_numbers",
        "resource_forecast", "speedometer", "challenge_timer",
    ]


Component = Annotated[
    Union[
        ActionComponent, TraitComponent, ResourceComponent, RuleComponent,
        StatusComponent, AffordanceComponent, InfoComponent,
    ],
    Field(discriminator="kind"),
]

COMPONENT_KINDS = (
    "action", "trait", "resource", "rule", "status", "affordance", "info",
)

#: Which id prefix each kind must use. Enforced by `CreateOperation`, so a
#: `res_` id can never name an Action.
KIND_PREFIX = {
    "action": "act", "trait": "trait", "resource": "res", "rule": "rule",
    "status": "status", "affordance": "aff", "info": "info",
}


# ---------------------------------------------------------------------------
# Operations
# ---------------------------------------------------------------------------

#: Fields an UPGRADE may move, per component kind. Anything not listed is
#: not numerically upgradable — a change of shape is a MODIFY.
UPGRADABLE_FIELDS = {
    "action": ("cooldown", "damage", "range", "amount", "force",
               "pull_force", "reach", "radius", "duration"),
    "resource": ("max_value", "regen_per_second", "regen_delay",
                 "pip_count"),
    "trait": ("multiplier",),
    "rule": ("cooldown",),
    "status": ("duration", "magnitude"),
}
UpgradableField = Literal[
    "cooldown", "damage", "range", "amount", "force", "pull_force", "reach",
    "radius", "duration", "max_value", "regen_per_second", "regen_delay",
    "pip_count", "multiplier",
]

LinkKind = Literal["powers", "fills", "scales", "gates"]
LINK_KINDS = ("powers", "fills", "scales", "gates")


class CreateOperation(Strict):
    op: Literal["create"]
    component: Component

    @model_validator(mode="after")
    def _id_prefix_matches_kind(self):
        expected = KIND_PREFIX[self.component.kind]
        if not self.component.component_id.startswith(expected + "_"):
            raise ValueError(
                f"a '{self.component.kind}' component id must start with "
                f"'{expected}_', got '{self.component.component_id}'"
            )
        return self


class UpgradeOperation(Strict):
    """Numeric growth of something already owned. This is what Mk II is."""
    op: Literal["upgrade"]
    target: ComponentId
    field: UpgradableField
    #: Signed. Bounds are re-checked against the target's own field bounds
    #: when the fold applies it, so an upgrade cannot walk a value out of
    #: range one small step at a time.
    delta: float = Field(ge=-500.0, le=500.0)


class ModifyOperation(Strict):
    """A new capability on something owned, rather than a bigger number."""
    op: Literal["modify"]
    target: ComponentId
    add_modifier: Modifier | None = None
    add_effect: Effect | None = None
    add_condition: Condition | None = None

    @model_validator(mode="after")
    def _exactly_one_addition(self):
        given = [x for x in (self.add_modifier, self.add_effect,
                             self.add_condition) if x is not None]
        if len(given) != 1:
            raise ValueError("a modify operation adds exactly one thing")
        return self


class LinkOperation(Strict):
    op: Literal["link"]
    link: LinkKind
    source: ComponentId
    target: ComponentId
    strength: float = Field(default=1.0, ge=0.0, le=200.0)

    @model_validator(mode="after")
    def _no_self_link(self):
        if self.source == self.target:
            raise ValueError("a component cannot link to itself")
        return self


class MergeOperation(Strict):
    """Two economies become one.

    The only operation that can change what an id *means*, so it carries the
    most rules — the rest are enforced by the fold, where the alias table and
    the live component set are both known.
    """
    op: Literal["merge"]
    absorbed: ComponentId
    survivor: ComponentId
    capacity: Literal["sum", "keep_survivor"] = "sum"

    @model_validator(mode="after")
    def _no_self_merge(self):
        if self.absorbed == self.survivor:
            raise ValueError("a component cannot be merged into itself")
        return self


Operation = Annotated[
    Union[CreateOperation, UpgradeOperation, ModifyOperation, LinkOperation,
          MergeOperation],
    Field(discriminator="op"),
]

OPERATION_KINDS = ("create", "upgrade", "modify", "link", "merge")
InterpretationMode = Literal["literal", "mechanical", "conceptual", "systemic"]
INTERPRETATION_MODES = ("literal", "mechanical", "conceptual", "systemic")


# ---------------------------------------------------------------------------
# The interpretation
# ---------------------------------------------------------------------------

class EchoInterpretation(Strict):
    """One foreign item, read by Epsilon, expressed as operations.

    `interpretation_seq` is the whole ordering story. It is assigned once, at
    grant time, and never recomputed — see `mechanics.derive_mechanics` and
    ECHOES.md 2.1 for why sorting by `source_location_id` is a corrupt fold.
    """
    schema_version: Literal[8] = 8
    echo_id: str = Field(min_length=1, max_length=32, pattern=r"^echo_\d+$")
    #: Assigned by `transitions.append_interpretation`. Immutable thereafter.
    interpretation_seq: int = Field(ge=0)

    source_location_id: int = Field(
        ge=C.FIRST_LOCATION_ID, le=C.LAST_LOCATION_ID
    )
    source_item_name: str = _AP_STR
    source_game: str = _AP_STR
    source_recipient_name: str = _AP_STR

    #: What Epsilon read the item as. Stored, not merely used: the archive
    #: shows it, and it is most of the charm.
    concepts: tuple[Annotated[str, Field(min_length=1, max_length=24)], ...] = (
        Field(default=(), max_length=6)
    )
    mode: InterpretationMode = "literal"

    display_name: str = _NAME
    description: str = _NAME
    tags: tuple[Annotated[str, Field(max_length=24)], ...] = Field(
        default=(), max_length=6
    )

    operations: tuple[Operation, ...] = Field(min_length=1, max_length=4)

    @model_validator(mode="after")
    def _echo_id_matches_source(self):
        expected = f"echo_{self.source_location_id}"
        if self.echo_id != expected:
            raise ValueError(
                f"echo_id must be '{expected}' for this source location"
            )
        return self

    @property
    def created_ids(self) -> tuple[str, ...]:
        return tuple(
            op.component.component_id
            for op in self.operations
            if op.op == "create"
        )

    @property
    def targets(self) -> tuple[str, ...]:
        out: list[str] = []
        for op in self.operations:
            if op.op in ("upgrade", "modify"):
                out.append(op.target)
            elif op.op == "link":
                out.extend((op.source, op.target))
            elif op.op == "merge":
                out.extend((op.absorbed, op.survivor))
        return tuple(out)


# ---------------------------------------------------------------------------
# Semantic validation — request context, and what the engine can honour
# ---------------------------------------------------------------------------

def budget_errors(interpretation, mechanics) -> list[str]:
    """Contextual validation: what this Echo would make the CAMPAIGN.

    Every other rule in this module judges one interpretation on its own,
    which is what makes them enforceable by the model layer. This one cannot
    be: "is this the sixteenth resource" is only answerable against the
    fold, so it lives here and runs at grant time.

    Only `CREATE` is counted. That is the whole point of the budget —
    `UPGRADE`, `MODIFY`, `LINK` and `MERGE` are the pressure valve, so they
    stay legal at any size. Merging over duplicating is enforced, not
    encouraged (§7).
    """
    errors: list[str] = []
    created: dict[str, int] = {}
    for operation in interpretation.operations:
        if operation.op != "create":
            continue
        created[operation.component.kind] = (
            created.get(operation.component.kind, 0) + 1)

    for kind, count in sorted(created.items()):
        budget = COMPLEXITY_BUDGETS.get(kind)
        if budget is None:
            continue
        _soft, hard = budget
        if hard is None:
            continue
        owned, would_be = _budget_counts(kind, mechanics, interpretation)
        if would_be > hard:
            # Said in the budget's OWN unit. Interpolating `count` (a
            # component count) beside `would_be` (distinct tags, for
            # affordances) produced "creating 2 more 'affordance'
            # component(s) would put the campaign at 3" — a repair prompt
            # whose two numbers cannot both be right.
            unit = "distinct tag" if kind == "affordance" else kind
            errors.append(
                f"this would take the campaign from {owned} to {would_be} "
                f"{unit}(s), over the hard budget of {hard}; upgrade, link "
                f"or merge an existing one instead"
            )
    return errors


def _budget_counts(kind: str, mechanics, interpretation) -> tuple[int, int]:
    """`(owned now, owned after this Echo)` in the unit the budget uses.

    Every kind is counted in components except `affordance`, which §16
    measures in **distinct tags**. That difference is not a detail: an
    affordance tag is a capability, so two Echoes that both grant `rail`
    add one vocabulary to the campaign, not two. Counting components there
    would charge a player twice for a redundant grant.

    A consequence worth stating plainly: only seven tags exist, so the
    affordance budget (soft 8, hard 12) cannot currently be reached. It is
    a ceiling that becomes live if the tag catalog grows — which is the
    right shape for a budget, and better than a number that fires for the
    wrong reason. `test_interpretation.py` asserts this is deliberate.
    """
    if kind != "affordance":
        owned = len([o for o in mechanics.owned if o.kind == kind])
        added = len([op for op in interpretation.operations
                     if op.op == "create" and op.component.kind == kind])
        return owned, owned + added
    owned_tags = {o.component.tag for o in mechanics.owned
                  if o.component.kind == "affordance"}
    new_tags = set(owned_tags)
    for op in interpretation.operations:
        if op.op == "create" and op.component.kind == "affordance":
            new_tags.add(op.component.tag)
    return len(owned_tags), len(new_tags)


def over_soft_budget(mechanics) -> tuple[str, ...]:
    """Kinds the campaign already has enough of, for the request to say so.

    Steering, not enforcement: a provider told the campaign is resource-rich
    can still create one, and the hard budget is what actually refuses.
    """
    out: list[str] = []
    for kind, (soft, _hard) in sorted(COMPLEXITY_BUDGETS.items()):
        if kind == "affordance":
            # Distinct tags, matching the hard budget's unit (§16). The two
            # halves of one budget counting different things would be a
            # steer that fires at a size the refusal never agrees with.
            count = len({o.component.tag for o in mechanics.owned
                         if o.component.kind == "affordance"})
        else:
            count = len([o for o in mechanics.owned if o.kind == kind])
        if count >= soft:
            out.append(kind)
    return tuple(out)


#: Nudge used to step inside an exclusive (`gt`/`lt`) bound. Small enough
#: not to matter to any field here, large enough to survive float noise.
_EPSILON = 1e-6


def _validated_range(component, field: str, current: float,
                     low: float, high: float) -> tuple[float, float]:
    """Narrow a field's declared range to what the MODEL will accept.

    A field bound is not the whole rule. `TraitComponent.multiplier` is
    `ge=0.1, le=4.0`, but `_traversal_stats_may_only_help` refuses a
    gravity trait above 1.0 — so a provider told "0.1 to 4.0" for a
    gravity trait at 0.9 is being told it may raise by 0.15, and the fold
    then refuses the upgrade it was invited to make.

    That is not hypothetical: the deterministic fallback took the
    advertised range at face value, emitted `multiplier +0.15` on a
    gravity trait at 0.9, and every validator in the generation pipeline
    passed it — because none of them range-checks the RESULT. It failed
    inside `append_interpretation`, where a `FoldError` is a crash rather
    than a repairable rejection, and it failed deterministically, so the
    Check could never be granted and reconciliation aborted every time.

    Probing rather than enumerating the validators: the model is the
    authority on what it accepts, and a hand-kept list of which stats have
    extra rules would be a second copy of the rules to keep in sync.
    """
    try:
        from .mechanics import upgrade_is_legal
    except ImportError:                        # pragma: no cover
        from mechanics import upgrade_is_legal

    def reachable(target: float) -> bool:
        return upgrade_is_legal(component, field, target - current)

    # Each end independently: a gravity trait's floor is its plain field
    # bound and only its ceiling is narrowed, and bisecting both would
    # report 0.1001 where 0.1 is exactly right.
    return (low if reachable(low) else _bisect(reachable, current, low),
            high if reachable(high) else _bisect(reachable, current, high))


def _bisect(reachable, current: float, bound: float) -> float:
    """The furthest value toward `bound` the model still accepts.

    `current` is always reachable (it is the component's own value), so
    the search is well-founded. Twenty-four halvings resolve any field in
    this schema to well under its meaningful precision.
    """
    if reachable(bound):
        return bound
    good, bad = current, bound
    for _ in range(24):
        middle = (good + bad) / 2.0
        if reachable(middle):
            good = middle
        else:
            bad = middle
    # Rounded INWARD, toward `current`: a bisected bound carries float
    # noise that reads as false precision in a prompt ("0.10000004768"),
    # and rounding the other way would re-admit the value just proven
    # illegal.
    step = 1e-4
    if bound > current:
        return math.floor(good / step) * step
    return math.ceil(good / step) * step


def upgradable_field_info(component) -> tuple[tuple[str, float, float, float], ...]:
    """`(field, current, minimum, maximum)` for everything upgradable here.

    A provider proposing an `UPGRADE` has to pick a delta that lands
    inside the field's declared range, because the fold re-validates and
    refuses one that does not (that refusal is deliberate: it is what
    stops an upgrade walking a value out of range one small step at a
    time). Without the range, a provider can only guess — so the request
    carries this, and guessing stops being part of the job.

    Bounds come from the models themselves rather than a hand-kept table,
    so a schema that tightens a bound tightens this in the same commit.
    """
    out: list[tuple[str, float, float, float]] = []
    for field in UPGRADABLE_FIELDS.get(component.kind, ()):
        holder = component
        if getattr(component, field, None) is None:
            holder = getattr(component, "primitive", None)
        if holder is None or getattr(holder, field, None) is None:
            continue
        info = type(holder).model_fields.get(field)
        if info is None:
            continue
        low, high = None, None
        for constraint in info.metadata:
            for attribute in ("ge", "gt"):
                bound = getattr(constraint, attribute, None)
                if bound is not None and low is None:
                    # `gt` is exclusive; nudge inside it so the advertised
                    # floor is a value that actually validates.
                    low = float(bound) + (_EPSILON if attribute == "gt" else 0.0)
            for attribute in ("le", "lt"):
                bound = getattr(constraint, attribute, None)
                if bound is not None and high is None:
                    high = float(bound) - (_EPSILON if attribute == "lt" else 0.0)
        if low is None or high is None:
            continue
        current = float(getattr(holder, field))
        low, high = _validated_range(component, field, current,
                                     float(low), float(high))
        out.append((field, current, low, high))
    return tuple(out)


def _has_upgradable_value(component, field: str) -> bool:
    """Whether `field` is a thing this component actually carries.

    An action's upgradable numbers mostly live on its PRIMITIVE (a melee
    swing has `reach`, a hitscan has `range`), with `cooldown` on the
    action itself. `mechanics._apply_upgrade` resolves it exactly this
    way; the two must agree, or this check would reject upgrades the fold
    accepts, or wave through ones it does not.
    """
    if getattr(component, field, None) is not None:
        return True
    primitive = getattr(component, "primitive", None)
    return primitive is not None and getattr(primitive, field, None) is not None


def _upgrade_lands(component, canonical: str, op, where: str) -> list[str]:
    """Would the RESULT of this upgrade validate?

    The three checks above ask whether the target exists and whether the
    field is upgradable at all. Neither asks where the value ENDS UP, and
    that gap had teeth: the deterministic fallback emitted `multiplier
    +0.15` on a gravity trait at 0.9, every validator in the pipeline
    passed it, and it failed inside `append_interpretation` — where a
    `FoldError` is a crash rather than a repairable rejection, and where
    it repeated on every retry, so the Check could never be granted and
    reconciliation aborted each time.

    Asking the model rather than re-deriving the rule: `upgrade_is_legal`
    applies the real upgrade to a copy and reports whether it survives, so
    a validator added to a component tomorrow is honoured here today.
    """
    try:
        from .mechanics import upgrade_is_legal
    except ImportError:                        # pragma: no cover
        from mechanics import upgrade_is_legal
    if upgrade_is_legal(component, op.field, op.delta):
        return []
    headroom = {f: (low, high)
                for f, _current, low, high in upgradable_field_info(component)}
    room = headroom.get(op.field)
    limits = (f"; '{op.field}' accepts {room[0]} to {room[1]} on this "
              f"component" if room else "")
    return [
        f"{where} raises '{op.field}' on '{canonical}' by {op.delta}, "
        f"which lands outside what that component accepts{limits}"
    ]


def target_errors(interpretation, mechanics) -> list[str]:
    """Contextual validation: can this interpretation's operations LAND?

    Sibling of `budget_errors`, and for the same reason — an operation
    naming a component is only answerable against the fold. The fold does
    check it (I11, loudly, and that check stays: it is what makes a
    corrupt log unrepresentable). What this adds is the check happening
    EARLY, at generation, where a wrong target becomes a repair prompt
    naming the mistake instead of a save that refuses to build.

    Providers could not emit `UPGRADE` / `MODIFY` / `MERGE` before S6, so
    a dangling target was not a shape a generation could take. Now it is
    the single likeliest way a disposition goes wrong.

    Ids resolve through the alias table first, exactly as the fold does:
    an operation written against a merged-away resource keeps meaning the
    survivor (§3.1, aliases are permanent).
    """
    errors: list[str] = []
    owned = {o.component_id: o.component for o in mechanics.owned}
    aliases = dict(mechanics.aliases)
    # Components created earlier in THIS interpretation are legal targets:
    # the fold applies operations in order, so an upgrade may follow its
    # own create.
    pending: dict[str, object] = {}

    def resolve(component_id: str):
        canonical = aliases.get(component_id, component_id)
        return pending.get(canonical) or owned.get(canonical), canonical

    for index, op in enumerate(interpretation.operations):
        where = f"operation {index + 1} ({op.op})"
        if op.op == "create":
            pending[op.component.component_id] = op.component
            continue

        if op.op in ("upgrade", "modify"):
            component, canonical = resolve(op.target)
            if component is None:
                errors.append(
                    f"{where} targets '{op.target}', which the campaign "
                    f"does not own; target something in the owned graph or "
                    f"create it first"
                )
                continue
            if op.op == "upgrade":
                allowed = UPGRADABLE_FIELDS.get(component.kind, ())
                if op.field not in allowed:
                    errors.append(
                        f"{where} raises '{op.field}' on '{canonical}', a "
                        f"{component.kind}; that kind upgrades "
                        f"{', '.join(allowed) or 'nothing'}"
                    )
                elif not _has_upgradable_value(component, op.field):
                    errors.append(
                        f"{where} raises '{op.field}' on '{canonical}', "
                        f"which has no such field to raise"
                    )
                else:
                    errors.extend(_upgrade_lands(
                        component, canonical, op, where))
        elif op.op == "link":
            for side in ("source", "target"):
                component, _ = resolve(getattr(op, side))
                if component is None:
                    errors.append(
                        f"{where} names {side} '{getattr(op, side)}', which "
                        f"the campaign does not own"
                    )
        elif op.op == "merge":
            absorbed, absorbed_id = resolve(op.absorbed)
            survivor, survivor_id = resolve(op.survivor)
            for side, component, name in (
                    ("absorbed", absorbed, op.absorbed),
                    ("survivor", survivor, op.survivor)):
                if component is None:
                    errors.append(
                        f"{where} names {side} '{name}', which the campaign "
                        f"does not own"
                    )
                elif component.kind != "resource":
                    errors.append(
                        f"{where} merges {side} '{name}', a "
                        f"{component.kind}; only resources may merge"
                    )
            if (absorbed is not None and survivor is not None
                    and absorbed_id == survivor_id):
                errors.append(
                    f"{where} merges '{op.absorbed}' into '{op.survivor}', "
                    f"but both already resolve to '{survivor_id}'"
                )
    return errors


def validate_interpretation(
    interpretation: EchoInterpretation,
    *,
    expected_source_location_id: int,
    implemented_primitives: tuple[str, ...] = IMPLEMENTED_PRIMITIVES,
) -> list[str]:
    """Check a structurally-valid interpretation against its request.

    Shape rules live in the models. This is the context-dependent half:
    whether it answers the request it was made for, and whether the engine
    can actually execute what it asks for.

    Target liveness is NOT checked here — it depends on the campaign, so it
    belongs to the fold (`mechanics.derive_mechanics`), which is the one
    place that always has the full picture.
    """
    errors: list[str] = []

    if interpretation.source_location_id != expected_source_location_id:
        errors.append(
            f"source_location_id must be {expected_source_location_id}, "
            f"got {interpretation.source_location_id}"
        )

    for op in interpretation.operations:
        if op.op != "create" or op.component.kind != "action":
            continue
        primitive = op.component.primitive.type
        if primitive not in implemented_primitives:
            errors.append(
                f"action primitive '{primitive}' is in the catalog but not "
                f"yet implemented by the engine; it would be an Action that "
                f"silently does nothing"
            )

    return errors
