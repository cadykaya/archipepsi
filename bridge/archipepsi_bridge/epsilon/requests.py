"""Normalized Epsilon request contracts (EPSILON_SPEC §9 and §10).

The packet left these as JSON examples (open item m25); these models pin
them. They are bridge-owned: the provider may change, the request contract
may not. Frozen like every other contract object.
"""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from .. import content_value as V
from ..schemas import constants as C
from ..schemas import echo as E
from ..schemas import zone as Z
from . import capabilities as CAP

_AP_STR = Annotated[str, Field(max_length=C.MAX_AP_STRING_LEN)]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class ZoneSummary(Strict):
    name: str = Field(max_length=C.MAX_TEXT_LEN)
    theme: str = Field(max_length=48)
    target_game: _AP_STR


class EchoSummary(Strict):
    """One owned interpretation, as Epsilon sees it in a request.

    v0.7 carried `archetype` and `activation`, which were properties of an
    Echo when an Echo was one ability. An interpretation contributes
    components, so what a summary reports is which kinds it contributed.
    """
    echo_id: str = Field(max_length=32)
    display_name: str = Field(max_length=C.MAX_TEXT_LEN)
    kinds: tuple[Annotated[str, Field(max_length=16)], ...] = ()
    tags: tuple[Annotated[str, Field(max_length=24)], ...] = ()
    description: str = Field(max_length=C.MAX_TEXT_LEN)


#: Read from the schema rather than retyped, so a family added to the
#: vocabulary reaches Epsilon without anybody remembering to list it.
_ACTIVITY_KINDS = tuple(Z.ActivityKind.__args__)


def _shell_catalog() -> dict:
    """The authored shells on offer. Empty while the registry has none.

    Loaded per request rather than cached at import: the registry is a
    file on disk, a packaged game can ship a different one, and a
    catalog frozen at import time would describe whichever build
    happened to start first.
    """
    from ..shells import shell_catalog
    return shell_catalog()


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

    #: How much content this Zone must contain (CAMPAIGN_SCALE.md 5).
    #:
    #: Defaults to the PROTOTYPE, like everything else that had to keep
    #: working while the options landed. A request that forgets to carry
    #: the campaign's real budget therefore asks for a small Zone, which
    #: is the safe direction: too little content is a Zone that fails its
    #: band and gets repaired, not one the engine cannot hold.
    zone_budget: int = Field(
        default=C.PROTOTYPE_CONFIG.zone_budget,
        ge=C.ZONE_BUDGET_MIN, le=C.ZONE_BUDGET_MAX)


class PlayerContext(Strict):
    signal_keys: int = Field(ge=0)
    coins_available: int = Field(ge=0)
    echoes: tuple[EchoSummary, ...] = ()


class RequestLocation(Strict):
    location_id: int = Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_UNIVERSE_ID)
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
    #: Bounded by the largest campaign anyone can configure, not by the
    #: prototype's three. `zone_target_checks` is a per-seed option now,
    #: so a request carrying fifteen is ordinary rather than exceptional.
    locations: tuple[RequestLocation, ...] = Field(
        min_length=1, max_length=C.ZONE_TARGET_CHECKS_MAX)
    #: §13: the affordance tags this campaign can actually USE, computed
    #: from OWNED mechanics. Epsilon may place matching optional features
    #: and nothing else — a water volume in a run with no way to move
    #: through water is set dressing that looks like content.
    unlocked_affordances: tuple[str, ...] = ()
    catalog: dict = Field(default_factory=lambda: {
        "themes": list(C.THEMES),
        "chamber_types": list(C.CHAMBER_TYPES),
        "enemy_archetypes": list(C.ENEMY_ARCHETYPES),
        "objectives": list(C.OBJECTIVES),
        # Authored room shells Epsilon may name, keyed by chamber type.
        #
        # IDS, NEVER PATHS. An Epsilon that can name a resource path can
        # name any file; Godot resolves the id. A type with no authored
        # shell is absent rather than present-and-empty.
        #
        # `validate_zone` refuses a `shell_id` that is not in here, so
        # this is the offer AND the bound. It was empty everywhere in
        # the live pipeline until now -- the field existed, the
        # validator enforced it, and nothing ever put a shell in it.
        "room_shells": _shell_catalog(),
    })
    #: Filled from the campaign's own budget after validation, because a
    #: `default_factory` cannot see the instance it belongs to -- and
    #: these numbers are exactly the ones that stopped being global when
    #: scale became a per-seed option.
    constraints: dict = Field(default_factory=dict)

    @model_validator(mode="after")
    def _constraints_describe_THIS_campaign(self):
        if self.constraints:
            return self
        budget = self.campaign.zone_budget
        object.__setattr__(self, "constraints", {
        "max_chambers": C.ZONE_MAX_CHAMBERS,
        "rooms_suggested": C.zone_room_envelope(budget),
        "zone_budget": budget,
        "budget_tolerance": V.ZONE_BUDGET_TOLERANCE,
        "activity_kinds": list(_ACTIVITY_KINDS),
        "max_enemies_total": C.max_enemies_per_zone(budget),
        "max_enemies_per_chamber": C.MAX_ENEMIES_PER_CHAMBER,
        "max_brutes": C.max_brutes_per_zone(budget),
        "max_vertical_step": C.MAX_VERTICAL_STEP,
        "gap_bound": (
            "gap_size <= max_safe_gap(vertical_step); "
            f"{C.SAFE_BASE_JUMP_GAP} flat, "
            f"{C.max_safe_gap(C.MAX_VERTICAL_STEP)} at a "
            f"{C.MAX_VERTICAL_STEP}m step"),
        "all_locations_must_appear_once": True,
        "critical_path_requires_echo": False,
        "affordances_are_optional_only": (
            "a chamber may hold Checks AND features, but only where the room is wide enough for the feature to sit clear of the walking lane, "
            "and a feature may never gate an objective or an exit"),
        "content_is_scored_by_the_engine": (
            "room value is recomputed from what a room actually contains; "
            "a Check on its own is worth nothing"),
        })
        return self


class EchoSource(Strict):
    location_id: int = Field(ge=C.FIRST_LOCATION_ID, le=C.LAST_UNIVERSE_ID)
    item_name: _AP_STR
    source_game: _AP_STR
    recipient_name: _AP_STR
    item_flags: int = Field(ge=0)


class OwnedComponentSummary(Strict):
    """One folded component, as a target a disposition may name.

    S6's arrival. An `UPGRADE` needs a component id and a field that
    exists on it; a `MERGE` needs to know which ids are resources. A
    summary of interpretations cannot answer either, so this is the
    "owned component graph" S1 deferred — landing at the stage where a
    provider can finally act on it rather than at S10, because a
    disposition that cannot see its target is not a disposition.

    Deliberately narrow: identity, kind, what it is called, how many
    times it has been touched, and what may still be raised and by how
    much. Not a component dump — everything here is what a disposition
    needs to LAND, and nothing is what it would need to re-derive the
    component itself.
    """
    component_id: str = Field(max_length=32)
    kind: str = Field(max_length=16)
    display_name: str = Field(max_length=C.MAX_TEXT_LEN)
    mk: int = Field(ge=1)
    #: `(field, current, minimum, maximum)` per upgradable field. The
    #: range matters as much as the name: the fold refuses an upgrade
    #: that walks a value out of its declared bounds, so a provider
    #: without the bounds is guessing at the one thing it must not guess.
    upgradable: tuple[tuple[str, float, float, float], ...] = ()
    #: For an action, its primitive verb; for a trait, its stat; for a
    #: resource, its palette colour. What the component "is", in one word.
    detail: str = Field(default="", max_length=32)
    #: Modifier types this action already carries. Here for the same
    #: reason `upgradable` is: a `MODIFY` that adds a modifier must not
    #: duplicate a type and must not be the third one, and a provider
    #: that cannot see the existing two is guessing at exactly the thing
    #: the fold will refuse it for. Empty for every kind but `action`.
    modifiers: tuple[str, ...] = Field(default=(), max_length=2)


class OwnedLinkSummary(Strict):
    link: str = Field(max_length=16)
    source: str = Field(max_length=32)
    target: str = Field(max_length=32)


class EchoPlayerState(Strict):
    existing_echoes: tuple[EchoSummary, ...] = ()
    signal_keys: int = Field(default=0, ge=0)
    coins_available: int = Field(default=0, ge=0)
    #: The graph an interpretation may answer (S6). Empty for every
    #: pre-S6 caller and for a fresh campaign, which is the same thing.
    owned_components: tuple[OwnedComponentSummary, ...] = ()
    owned_links: tuple[OwnedLinkSummary, ...] = ()
    #: absorbed id -> surviving id. A disposition written against an
    #: absorbed id still lands (aliases are permanent, §3.1), but a
    #: provider that can see the table can name the survivor directly.
    aliases: tuple[tuple[str, str], ...] = ()


class EchoGenerationRequest(Strict):
    """What a provider is given to interpret one foreign item.

    S1 kept this narrow on the grounds that context no rule uses is just
    a longer prompt. S5 added the budget steer and S6 the owned component
    graph — each at the stage where an operation could finally obey it,
    which is the same rule applied twice rather than a change of mind.
    What is still absent is Epsilon's own reasoning scaffolding (concepts,
    modes, the interpretation pipeline): that is S10.

    The schema describes the whole v0.8 language, while `allowed` describes
    the subset the runtime can execute *today*. Both this request and the
    post-parse validator read the same staged capability registry; Epsilon is
    never invited to create a mechanic that would validate and then do
    nothing.
    """
    schema_version: Literal[8] = 8
    source: EchoSource
    player_state: EchoPlayerState
    required_echo_id: str = Field(max_length=32, pattern=r"^echo_\d+$")
    #: §16's steer, populated by the campaign from the live fold: the
    #: component kinds already at or past their soft budget. Landed with
    #: S5, the first stage where a provider can genuinely obey it — a
    #: LINK op is implementable now, so "the campaign is resource-rich,
    #: relate instead of duplicating" is advice validation accepts.
    #: S6 completed the vocabulary it steers toward: UPGRADE, MODIFY and
    #: MERGE are all implementable now.
    over_soft_budget: tuple[str, ...] = ()
    #: S10, §16 in full. `over_soft_budget` says WHICH kinds are crowded;
    #: this says by how much and how much room is left, as
    #: `{kind: [owned, soft, hard]}` with `hard` null where §16 has none.
    #: A provider given only the boolean has to guess whether one more
    #: resource is fine or is the sixteenth, and guessing wrong costs a
    #: repair round.
    budget_headroom: dict = Field(default_factory=dict)
    #: S10, §15's reading, offered rather than imposed. The deterministic
    #: lexicon's answer for this item, as a starting point — a provider is
    #: free to read the item differently and usually should, since a model
    #: that only ever echoed this back would be a slower `read_concepts`.
    suggested_concepts: tuple[str, ...] = ()
    #: S10: which readings the creativity setting leans toward, most first
    #: (§15, "influenced by Epsilon's creativity setting"). Steering, like
    #: `over_soft_budget` — the mode that gets stored must describe what
    #: the operations actually did, so this cannot be a rule.
    preferred_modes: tuple[str, ...] = ()
    #: S10, §15's relevance rule, phrased against THIS campaign: what a
    #: disposition could usefully touch. Empty on a fresh campaign, where
    #: there is nothing to relate to and CREATE is the only honest answer.
    relevance_hint: str = Field(default="", max_length=C.MAX_TEXT_LEN)
    allowed: dict = Field(default_factory=lambda: {
        "operations": list(CAP.IMPLEMENTED_OPERATION_KINDS),
        "modes": list(E.INTERPRETATION_MODES),
        "component_kinds": list(CAP.IMPLEMENTED_COMPONENT_KINDS),
        "action_primitives": list(E.IMPLEMENTED_PRIMITIVES),
        "modifiers": list(CAP.IMPLEMENTED_MODIFIER_TYPES),
        "trait_stats": list(CAP.IMPLEMENTED_TRAIT_STATS),
        "slots": list(CAP.IMPLEMENTED_ACTION_SLOTS),
        "rule_events": list(CAP.IMPLEMENTED_RULE_EVENTS),
        "rule_conditions": list(CAP.IMPLEMENTED_CONDITION_KINDS),
        "rule_effects": list(CAP.IMPLEMENTED_EFFECT_KINDS),
    })
    composition_rules: tuple[str, ...] = (
        "an interpretation carries 1-4 operations",
        "a create operation's component id must start with its kind prefix "
        "(act_, trait_, res_, rule_, status_, aff_, info_)",
        "an action has exactly one primitive plus 0-2 modifiers",
        "modifiers require a damage primitive in the same action",
        "a rule's costs, resource conditions and resource effects must name "
        "a resource the campaign owns (creating one in the same "
        "interpretation, before the rule, counts)",
        "a move_speed, jump_height or air_control trait may never fall below "
        "1.0, and a gravity trait may never exceed 1.0",
        "an upgrade, modify or merge must name a component_id from "
        "player_state.owned_components (or one this interpretation creates "
        "before it); an absorbed id resolves to its survivor",
        "only resources may merge, and never into themselves",
    )
    balance_limits: dict = Field(default_factory=lambda: {
        "damage": [1, 25], "pellets": [1, 16],
        "cooldown": [C.ECHO_COOLDOWN_MIN, C.ECHO_COOLDOWN_MAX],
        "gravity_multiplier": [C.GRAVITY_MULT_MIN, C.GRAVITY_MULT_MAX],
        "speed_multiplier": [C.SPEED_MULT_MIN, C.SPEED_MULT_MAX],
    })
