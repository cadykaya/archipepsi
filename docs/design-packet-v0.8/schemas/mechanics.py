"""Archipepsi v0.8 — the fold.

The campaign persists an **append-only log of interpretations**. The live
mechanical state is a **pure fold** over that log, recomputed on load and
after every grant, and never written to disk.

That single decision is what makes provenance, determinism, save safety, Mk
levels and cross-item modification the same mechanism rather than five, and
it is why nothing here mutates: every apply rebuilds and revalidates the
component it touched, so a bound checked at construction is checked at every
point a component ever reaches.

Two rules carry most of the weight, and both exist because the obvious
alternative is silently wrong:

1. **Order by `interpretation_seq`, never by `source_location_id`.** An
   operation may target a component an earlier interpretation created.
   Location ids are assigned by Archipelago, not by the order you find them,
   so ordering by them can replay an interpretation *before* its target
   exists — reachable by ordinary play, not a corner case.

2. **A dangling target raises.** It is never skipped. A skipped operation is
   a build that quietly differs from the one the player earned, and it would
   differ differently on the next load.
"""

from __future__ import annotations

from typing import Literal, Union

from pydantic import BaseModel, ConfigDict, Field, computed_field

try:
    from . import constants as C
    from . import echo as E
except ImportError:  # pragma: no cover
    import constants as C
    import echo as E


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class FoldError(ValueError):
    """A corrupt interpretation log.

    Distinct from a validation error on one interpretation: by the time the
    fold runs, everything in the log was individually valid when it was
    granted. This means the log as a *sequence* no longer makes sense, which
    is a bug in us, not in Epsilon.
    """


# ---------------------------------------------------------------------------
# Derived state
# ---------------------------------------------------------------------------

class ComponentProvenance(Strict):
    """Which AP item is responsible for which part of a component.

    Never deleted, never rewritten. A merged resource carries both sides'
    provenance, in sequence order, so neither source item stops being
    credited.
    """
    interpretation_seq: int = Field(ge=0)
    source_location_id: int
    source_item_name: str
    source_game: str
    source_recipient_name: str
    operation: Literal["create", "upgrade", "modify", "link", "merge"]
    #: One short line for the archive: "+12.0 range", "burning on hit".
    note: str = Field(default="", max_length=96)


class LinkEdge(Strict):
    link: E.LinkKind
    source: str
    target: str
    strength: float


class OwnedComponent(Strict):
    """A folded component plus the display facts a client needs.

    The bridge folds; the client never does. Re-implementing the fold in
    GDScript would be a second source of truth for the one thing that must be
    identical everywhere.
    """
    component: E.Component
    #: Mk I on creation, +1 per upgrade or modify that touched it -- and
    #: on a MERGE the survivor ADDS the absorbed component's Mk to its own,
    #: because provenance is unioned in the same step and a component
    #: crediting two items' worth of history at Mk I would read as newer
    #: than it is.
    mk: int = Field(ge=1)
    provenance: tuple[ComponentProvenance, ...] = Field(min_length=1)

    @property
    def component_id(self) -> str:
        return self.component.component_id

    @property
    def kind(self) -> str:
        return self.component.kind

    @property
    def source_game(self) -> str:
        """The world that created it. Used for tints and glyphs."""
        return self.provenance[0].source_game


class Mechanics(Strict):
    """Everything the campaign's interpretations add up to.

    Not round-trippable through `model_dump()`: `channel_order` is a
    `computed_field`, so it appears in the dump and is rejected on the way
    back in by `extra="forbid"`. That is deliberate rather than an
    oversight -- the dump exists to be SENT to a client, which must read
    channel order and must never reconstruct mechanics -- but it means the
    only way back is `derive_mechanics` over the log, which is the point.
    """
    owned: tuple[OwnedComponent, ...] = ()
    #: absorbed id -> surviving id, fully resolved (never a chain).
    aliases: tuple[tuple[str, str], ...] = ()
    links: tuple[LinkEdge, ...] = ()

    def by_id(self, component_id: str) -> OwnedComponent | None:
        target = self.resolve(component_id)
        return next(
            (o for o in self.owned if o.component_id == target), None
        )

    def resolve(self, component_id: str) -> str:
        for absorbed, survivor in self.aliases:
            if absorbed == component_id:
                return survivor
        return component_id

    def of_kind(self, kind: str) -> tuple[OwnedComponent, ...]:
        return tuple(o for o in self.owned if o.kind == kind)

    @property
    def actions(self) -> tuple[OwnedComponent, ...]:
        return self.of_kind("action")

    @computed_field
    @property
    def channel_order(self) -> tuple[str, ...]:
        """Resource ids in HUD-channel order, serialized for the client.

        The client must not work this out for itself. It could — the list is
        already ordered — but "which resource is channel 3" would then be
        derived in two languages, and the fold exists precisely so that the
        one thing that must be identical everywhere is computed once. Godot
        owns where channel 3 is DRAWN; this owns what channel 3 IS.
        """
        return tuple(o.component_id for o in self.of_kind("resource"))

    @property
    def resources(self) -> tuple[OwnedComponent, ...]:
        """Resources in channel order, which is creation order.

        `owned` is already in `interpretation_seq` ascending, so this needs
        no sort of its own — and must not have one. Ordering resources by
        anything else (name, palette, id) would relay out the dashboard the
        moment an unrelated Echo arrived.
        """
        return self.of_kind("resource")

    def channel_of(self, component_id: str) -> int | None:
        """Which of the fifteen pre-laid HUD channels a resource occupies.

        Derived rather than stored: a channel index that lived on the
        component could disagree with the fold after a MERGE, and there is
        no version of that disagreement the client could resolve. Godot owns
        where channel N is drawn; this owns which resource IS channel N.
        """
        target = self.resolve(component_id)
        for index, owned in enumerate(self.resources):
            if owned.component_id == target:
                return index
        return None

    @property
    def affordance_tags(self) -> tuple[str, ...]:
        return tuple(
            o.component.tag for o in self.owned if o.kind == "affordance"
        )


EMPTY_MECHANICS = Mechanics()


# ---------------------------------------------------------------------------
# The fold
# ---------------------------------------------------------------------------


def _check_rule_references(component, components, aliases, seq: int) -> None:
    """A rule that names a resource nobody owns can never fire: a missing
    bar reads as empty, so it is never affordable and never `at_least`
    anything. A dead rule that validates and persists is exactly the
    failure the staged gates exist to prevent, so the fold refuses it the
    way it refuses a dangling operation target (I11) — loudly, at the
    rule's own point in the log. References resolve through aliases first:
    a rule written against a merged-away resource keeps meaning the
    survivor (TECHNICAL_ARCHITECTURE §9)."""
    if component.kind != "rule":
        return
    refs = [(c.resource_id, "cost") for c in component.costs]
    refs += [(c.subject or "", f"condition '{c.type}'")
             for c in component.conditions
             if c.type in ("resource_at_least", "resource_at_most")]
    refs += [(e.subject or "", f"effect '{e.type}'")
             for e in component.effects
             if e.type in ("resource_add", "refill_resource")]
    for ref, where in refs:
        resolved = aliases.get(ref, ref)
        target = components.get(resolved)
        if target is None or target.kind != "resource":
            raise FoldError(
                f"interpretation_seq {seq}: rule "
                f"'{component.component_id}' {where} names {ref!r}, which "
                f"is not an owned resource at that point in the log"
            )


#: ECHOES.md §13.1. Each affordance tag names the derived capability that
#: makes it *interactable*, as a set of action primitives, trait stats, or
#: neither. A tag with no requirement is base-kit usable.
#:
#: Deliberately expressed over the vocabulary the fold already produces
#: rather than as a second taxonomy: "can this campaign grapple" is
#: "does it own an action whose primitive is in the grapple family", and
#: that question has exactly one right answer, held here.
#: THE PRIMITIVES THAT MOVE THE PLAYER'S OWN BODY -- what a traversal
#: requirement has to be answered with (owner ruling D-02, 2026-09-25:
#: "Moving an enemy does not prove that the player can perform the
#: crossing"). Read off what the runtime does, not the catalog's grouping:
#: `_grapple` bites a `StaticBody3D` and pulls the PLAYER to it and
#: `grapple_swing` is a held tether on one (`echo_runtime.gd`), while
#: `grapple_pull_target` hits only enemies and moves THE ENEMY. The ECHOES
#: catalog files all three under movement (`echo.MOVEMENT_PRIMITIVES`),
#: which is right for authoring and says nothing about a crossing.
PLAYER_TRAVERSAL_PRIMITIVES: tuple[str, ...] = (
    "dash", "air_dash", "double_jump", "wall_kick", "glide", "hover",
    "blink", "grapple_to_surface", "grapple_swing")

#: The anchor-grapples: what bites a fixed surface and carries the player.
_ANCHOR_GRAPPLES: tuple[str, ...] = ("grapple_to_surface", "grapple_swing")

AFFORDANCE_REQUIREMENTS: dict[str, dict[str, tuple[str, ...]]] = {
    # DESS-26: an anchor is used by a grapple that bites it; pulling an
    # enemy never touches one.
    "grapple_anchor": {"primitives": _ANCHOR_GRAPPLES},
    "breakable_wall": {"primitives": (
        "slam_ground", "melee_swing", "melee_thrust", "arc_lob",
        "beam_sustained")},
    "water_volume": {"primitives": ("hover", "glide"),
                     "stats": ("gravity",)},
    "rail": {"primitives": ("dash", "air_dash")},
    "wind_volume": {"primitives": ("glide", "hover")},
    # Base-kit usable: a bounce pad bounces anyone, and a moving platform
    # carries anyone. Requiring nothing is a real entry, not an omission.
    "bounce_pad": {},
    "moving_platform": {},
    # AND THE CRATE IS SHOVED BY A BODY, so this requires nothing either.
    #
    # The temptation is to write `{"capabilities": ("manipulate",)}` here
    # and it would be wrong twice over. `manipulate` is §29.3.1's
    # question -- does a HOST qualify to be relied on by content authored
    # at §29.3.2's 700 N / 20 m / 120 kg envelope -- and the chain does
    # not need a host at all: the player walks into the crate and their
    # own momentum moves it, which every character can do from the first
    # Zone. Requiring a capability here would make a note behind a door
    # into a gate, and `manipulate` is deliberately not in the
    # capability vocabulary precisely so nothing can declare one.
    "powered_door": {},
}


#: SEMANTIC CAPABILITIES (owner ruling, 2026-08-30). What a piece of
#: content may ASK FOR, expressed as "can the player DO x", never as "does
#: the player own item Y".
#:
#: The same shape and the same vocabulary as `AFFORDANCE_REQUIREMENTS`
#: above, and deliberately so: a second taxonomy would be a second answer
#: to a question that already has one. A capability is satisfied by ANY
#: primitive in its set, which is the whole point -- `grapple` is not the
#: canonical Grapple Echo, it is "owns an action whose primitive is in the
#: grapple family", and an Echo the player built themselves that lands in
#: that family satisfies it identically.
#:
#: Kept SMALL on purpose. Four capabilities, each one something an
#: activity the engine already builds could genuinely need. The physics
#: and construction capabilities an owner brief might name --
#: MOVE_OBJECT_*, TETHER_OBJECT, APPLY_UPWARD_FORCE, PLACE_CONSTRUCT --
#: are not here because nothing can satisfy them yet: they wait on the
#: v9 physics tool, and a capability nothing can satisfy is a gate
#: nothing opens.
ACTIVITY_CAPABILITIES: dict[str, dict[str, tuple[str, ...]]] = {
    # Hit a thing at range. Satisfied by the permanent baseline -- Static
    # Pulse is the always-available ranged floor -- so it is a real
    # requirement that is ALWAYS guaranteed, which is case A of the
    # guarantee model and the reason case A is not hypothetical.
    "ranged_hit": {"primitives": E.RANGED_PRIMITIVES},
    # Reach across more than base movement covers.
    "cross_long_gap": {"primitives": (
        "dash", "air_dash", "double_jump", "wall_kick", "glide", "hover",
        "blink", "grapple_to_surface", "grapple_swing")},
    # Pull yourself to, or swing from, a fixed anchor -- the same
    # anchor-grapples `grapple_anchor` names. NOT `grapple_pull_target`
    # (owner ruling D-02, DESS-26): it shares the family and the name,
    # and it moves an enemy, which proves nothing about a crossing.
    "grapple": {"primitives": _ANCHOR_GRAPPLES},
    "blink": {"primitives": ("blink",)},
}

#: WHAT EACH CAPABILITY CERTIFIES -- the affordance a gate asking for it
#: actually requires. A traversal capability is answered only by
#: primitives that move the player (`PLAYER_TRAVERSAL_PRIMITIVES`), which
#: a test holds for every entry, so a future family member cannot slip in
#: on a shared name.
CAPABILITY_AFFORDANCES: dict[str, str] = {
    "ranged_hit": "hit a target at range",
    "cross_long_gap": "move the player across more than base movement "
                      "covers",
    "grapple": "pull the player to, or swing them from, a fixed anchor",
    "blink": "teleport the player a short distance",
}
TRAVERSAL_CAPABILITIES: tuple[str, ...] = ("cross_long_gap", "grapple",
                                           "blink")

#: Capabilities the permanent baseline satisfies for every player in every
#: campaign, forever. Case A of the guarantee model.
#:
#: Exactly one entry, and that is not an oversight. Static Pulse is the
#: permanent always-available RANGED floor, so `ranged_hit` is guaranteed
#: to everyone. Base movement is base movement: it does not cross a long
#: gap, grapple or blink, which is what makes those three capable of
#: gating anything at all. Baseline melee, when it lands, belongs to the
#: permanent starting device and its binding is not decided here.
BASELINE_CAPABILITIES: tuple[str, ...] = ("ranged_hit",)


def _capability_is_satisfied(
    capability: str, primitives: set[str], stats: set[str]
) -> bool:
    """**IDENTITY, not qualification.** Is this a dash at all?

    Deliberately Boolean and deliberately about names, exactly as §29.3.1
    separates the two questions for `manipulate`: membership answers
    "is this a manipulation Ability", never "can this one move the
    crate". Here it answers "does the campaign own something in the dash
    family", never "does that dash cross this gap".

    **No numeric envelope belongs in this intersection.** `stats` is a
    set of stat NAMES off the components — `_primitives_and_stats` adds
    `component.stat`, a label — so putting a floor here would be
    comparing a number against a word. Qualification reads resolved
    provider parameters instead; see `qualifies_for_gap`.
    """
    requirement = ACTIVITY_CAPABILITIES.get(capability)
    if requirement is None:
        return False
    needed_primitives = set(requirement.get("primitives", ()))
    needed_stats = set(requirement.get("stats", ()))
    if not needed_primitives and not needed_stats:
        return True
    return bool(primitives & needed_primitives or stats & needed_stats)


def _primitives_and_stats(components) -> tuple[set[str], set[str]]:
    primitives: set[str] = set()
    stats: set[str] = set()
    for component in components:
        primitive = getattr(component, "primitive", None)
        if primitive is not None:
            primitives.add(primitive.type)
        stat = getattr(component, "stat", None)
        if stat is not None:
            stats.add(stat)
    return primitives, stats


def _runs_out(component) -> bool:
    """A consumable, which is NOT a permanent capability provider.

    `owned_capabilities` is what GENERATION asks, and a Zone composed
    against it may put a required route behind the capability. A charged
    Action cannot carry that: the player may stand in front of the gap
    with zero charges left, and nothing in the contract guarantees a
    resupply before they need it. Owning three grenades is not owning a
    way across.

    The exclusion is here rather than in the caller because both
    `owned_capabilities` and `available_capabilities` have to agree --
    one of them counting charges would make NOT YET mean two things.
    """
    return getattr(component, "charges", None) is not None


def owned_capabilities(mechanics) -> tuple[str, ...]:
    """What this campaign can DO, over everything it owns (case B).

    Over OWNED components rather than slotted ones, for the reason
    `owned_affordance_tags` gives: you own the grapple whether or not it
    is in a slot, and you can always slot it. Generation asks this
    question, because a Zone whose contents depended on the loadout at
    generation time would be a Zone that lies the moment the player
    changes slots.
    """
    primitives, stats = _primitives_and_stats(
        owned.component for owned in mechanics.owned
        if not _runs_out(owned.component))
    return tuple(sorted(
        capability for capability in ACTIVITY_CAPABILITIES
        if capability in BASELINE_CAPABILITIES
        or _capability_is_satisfied(capability, primitives, stats)))


def available_capabilities(mechanics, slots) -> tuple[str, ...]:
    """What the player can do RIGHT NOW, over what is actually equipped.

    The other half of `owned_capabilities`, and the difference between
    them is the whole reason NOT YET is a real state rather than dead
    code: a Zone is generated against what the campaign OWNS, and the
    player may walk into it having slotted something else. Then the
    activity is legitimately there, legitimately theirs, and legitimately
    not doable this minute -- which reads as NOT YET, never as a broken
    switch.
    """
    # Field names read off the model rather than listed here: a fifth
    # slot, or a rename, would otherwise silently stop counting and this
    # function would quietly under-report what the player can do.
    equipped = {getattr(slots, name, None)
                for name in type(slots).model_fields}
    equipped.discard(None)
    primitives, stats = _primitives_and_stats(
        owned.component for owned in mechanics.owned
        if owned.component.component_id in equipped
        and not _runs_out(owned.component))
    return tuple(sorted(
        capability for capability in ACTIVITY_CAPABILITIES
        if capability in BASELINE_CAPABILITIES
        or _capability_is_satisfied(capability, primitives, stats)))


# --- provider qualification, which is not capability identity ------------
#
# §29.3.1, applied to movement. `owned_capabilities` says the campaign
# owns a dash. It does not say the dash crosses the gap in front of the
# player, and §0-bis is explicit that the movement floor still binds: "a
# declared Grapple gate is legal; an undeclared 3-metre jump is still a
# bug." A weak dash is still a dash, and it must not certify a route it
# cannot cross.

#: The resolved parameter each movement primitive carries, and its UNIT.
#:
#: **These are not distances.** `Dash.force` is documented in `echo.py`
#: as "instantaneous velocity change in m/s", bounded 4–20, and
#: `echo_runtime.gd::_dash` spends it as `player.velocity += dir * force`
#: along CAMERA-FORWARD — so it adds to whatever the player was already
#: doing, and its direction carries the camera's pitch. `_air_dash`
#: replaces horizontal velocity instead. How far either carries a body
#: depends on the speed it was already moving at, the look angle, ground
#: friction and air damping, and how long the body stays airborne. There
#: is no closed form to write here and this lane must not invent one.
MOBILITY_PARAMETER_UNITS: dict[str, str] = {
    "dash": "m/s", "air_dash": "m/s", "double_jump": "m/s",
    "wall_kick": "m/s", "blink": "m", "glide": "unitless",
    "hover": "s", "grapple_to_surface": "m", "grapple_swing": "m",
    "grapple_pull_target": "m",
}

#: Which resolved parameter each primitive is qualified on, BY NAME.
#:
#: Explicit rather than a `getattr(force) or getattr(range)` fallback.
#: `Glide` carries a fall-speed fraction and `Hover` carries a duration
#: in seconds; a lookup that shrugged at both would report them as "no
#: envelope measured", which reads as "somebody should measure this"
#: when the truth is "this lane does not know what measuring it would
#: even mean". Those are different answers and a player stranded by the
#: second one is stranded differently.
QUALIFIABLE_PARAMETER: dict[str, str] = {
    "dash": "force",
    "air_dash": "force",
    "double_jump": "force",
    "wall_kick": "force",
    "blink": "range",
    "grapple_to_surface": "range",
    "grapple_swing": "range",
}


class CrossingEvidence(Strict):
    """One measured crossing, and EXACTLY what it certifies.

    **A measurement is not a trend.** The first version of this held
    `(parameter, reach)` points and read "the largest point at or below
    the provider's value", so a crossing measured at force 12 silently
    certified force 14 and force 20. Stronger is not automatically
    suitable: a bigger impulse can overshoot the landing, clip a ceiling,
    or carry the body past a ledge it was meant to arrive on. Whatever a
    measurement covers, it says so here; nothing is extrapolated.

    **And a crossing has conditions.** Reach alone certified a 6 m gap
    whose landing was a hundred metres above the takeoff, because the
    rise only ever reached the base-kit comparison. Evidence names the
    rise band it was executed at, and anything outside that band is
    outside its scope rather than covered by it.
    """

    primitive: str = Field(max_length=32)
    #: Which parameter the ranges below are about — must match
    #: `QUALIFIABLE_PARAMETER[primitive]`, so evidence cannot certify a
    #: field qualification never reads.
    parameter: str = Field(max_length=32)
    parameter_min: float
    parameter_max: float
    #: The landing-height band, in metres relative to takeoff. Negative
    #: is a drop.
    rise_min_m: float
    rise_max_m: float
    #: Horizontal metres the crossing covered, at EVERY point in both
    #: bands above. A floor, not a best case.
    reach_m: float = Field(gt=0)
    #: The controller and scene it was measured against — engine-owned
    #: and opaque here, exactly like `PhysicsSetup.scene_digest`.
    #:
    #: **Recorded provenance, and a comparison waiting on its other
    #: half.** `qualifies_for_gap` compares this against an
    #: `expected_setup` the caller supplies, and refuses a row measured
    #: somewhere else. What is not settled is where that expected
    #: identity comes from — the engine computes it, like
    #: `scene_digest`, and nobody has agreed what it covers or when it
    #: is handed over. Until that is agreed this is not yet working
    #: stale-evidence invalidation; it is a field that records which
    #: setup was measured, and a comparison ready for the day the other
    #: side of it exists.
    setup_digest: str = Field(min_length=16, max_length=16,
                              pattern=r"^[0-9a-f]{16}$")

    def covers(self, value: float, rise_m: float) -> bool:
        return (self.parameter_min - 1e-9 <= value <= self.parameter_max + 1e-9
                and self.rise_min_m - 1e-9 <= rise_m
                <= self.rise_max_m + 1e-9)


#: Measured crossings per primitive. **Engine-owned, and empty.**
#:
#: The pattern is §29.3.2's, which already solved this for `manipulate`:
#: a mandatory-route envelope, content authored against the MINIMUM, and
#: a reference solution replayed at exactly that minimum so anything
#: qualifying can solve it. Only the engine can produce the equivalent
#: here, for the same reason it owns `scene_digest`: the bridge has no
#: body, no controller and no physics frame.
#:
#: Until an entry covers a provider's parameter AND the rise being
#: asked for, NOTHING QUALIFIES. That is the honest state rather than a
#: placeholder: a gate with no measured crossing behind it is a route
#: nobody has shown the player can make.
CROSSING_EVIDENCE: dict[str, tuple[CrossingEvidence, ...]] = {}


class ProviderQualification(Strict):
    """Can THIS provider make THIS crossing, under THESE conditions?

    Separate from `CapabilityGuarantee`, which asks whether the player
    can get a capability at all. Both have to hold, and they are
    different obligations: Archipelago proves the capability is
    OBTAINABLE, a measured crossing proves the provider is SUITABLE.
    Neither substitutes for the other.
    """

    capability: str = Field(max_length=32)
    qualifies: bool
    reason: Literal[
        # The base kit already covers it; no provider is needed and the
        # crossing is not a gate at all.
        "within_base_kit",
        # Evidence covers this provider's parameter and this rise, and
        # its measured reach spans the gap.
        "meets_envelope",
        # Same, and it does not.
        "below_envelope",
        # The campaign owns nothing in the family.
        "no_provider",
        # The family is owned; nothing has been measured for it at all.
        "no_envelope_measured",
        # Measurements exist and none covers this parameter value or
        # this rise. A different answer from the one above: something
        # was measured, just not this.
        "outside_measured_scope",
        # A row filed under this primitive names a different primitive
        # or a parameter this provider is not qualified on. Not a gap in
        # the measurements — a defect in them, and reporting it as
        # "nobody measured this" would send someone to measure a thing
        # that was already measured and misfiled.
        "evidence_misfiled",
        # Every covering row was measured against a different setup.
        "evidence_for_another_setup",
        # No `expected_setup` was supplied, so no row can be tied to the
        # setup the question is being asked about. Refused rather than
        # waved through: evidence that might be about another build is
        # not evidence about this one.
        "setup_identity_unknown",
        # The family member carries no parameter qualification reads —
        # glide, hover. Not a gap in the measurements; a gap in what
        # this lane knows how to ask for.
        "provider_not_qualifiable",
    ]
    #: The gap asked for and the reach proved, both metres, when known.
    gap_m: float | None = None
    reach_m: float | None = None
    rise_m: float | None = None


def qualifies_for_gap(capability: str, mechanics, gap_m: float,
                      rise_m: float = 0.0,
                      expected_setup: str | None = None
                      ) -> ProviderQualification:
    """Does anything the campaign owns actually make this crossing?

    **A TESTED HELPER, NOT YET WIRED.** Nothing in production calls it —
    see `AP_CAPABILITY_LOGIC.md` §8c for the consumer it is waiting on
    and why that consumer is `layout.validate` rather than generation.
    What refuses an undeclared gate today is still
    `topology.reachability`, on the Archipelago side of the question.

    `gap_m` is the crossing the route needs and `rise_m` its landing
    height relative to takeoff, both metres. The base kit's own reach is
    `C.max_safe_gap(rise_m)` — derived from the same constants the
    engine generates its copy from — so a gap inside that needs no
    provider and is not a gate.
    """
    base = C.max_safe_gap(rise_m)
    if gap_m <= base:
        return ProviderQualification(
            capability=capability, qualifies=True,
            reason="within_base_kit", gap_m=gap_m, reach_m=base,
            rise_m=rise_m)

    wanted = set(ACTIVITY_CAPABILITIES.get(capability, {})
                 .get("primitives", ()))
    best: float | None = None
    saw_provider = False
    saw_qualifiable = False
    saw_measurement = False
    misfiled = False
    other_setup = False
    unknown_setup = False
    for owned in mechanics.owned:
        primitive = getattr(owned.component, "primitive", None)
        if primitive is None or primitive.type not in wanted:
            continue
        saw_provider = True
        field = QUALIFIABLE_PARAMETER.get(primitive.type)
        if field is None:
            continue
        value = getattr(primitive, field, None)
        if value is None:
            continue
        saw_qualifiable = True
        for evidence in CROSSING_EVIDENCE.get(primitive.type, ()):
            saw_measurement = True
            # IDENTITY BEFORE SHAPE. A row is evidence about THIS
            # provider only if it says so: filed under the primitive it
            # names, about the parameter this primitive is qualified on.
            # Neither was checked, so a row naming `blink` certified a
            # dash and a row naming `range` certified a `force` reading.
            if (evidence.primitive != primitive.type
                    or evidence.parameter != field):
                misfiled = True
                continue
            if not evidence.covers(float(value), rise_m):
                continue
            # AND MEASURED AGAINST THE SETUP BEING ASKED ABOUT. A
            # well-formed digest from another build is not a crossing in
            # this one.
            if expected_setup is None:
                unknown_setup = True
                continue
            if evidence.setup_digest != expected_setup:
                other_setup = True
                continue
            if best is None or evidence.reach_m > best:
                best = evidence.reach_m

    if not saw_provider:
        return ProviderQualification(
            capability=capability, qualifies=False, reason="no_provider",
            gap_m=gap_m, reach_m=base, rise_m=rise_m)
    if not saw_qualifiable:
        return ProviderQualification(
            capability=capability, qualifies=False,
            reason="provider_not_qualifiable", gap_m=gap_m, rise_m=rise_m)
    if best is None:
        # Ordered by what the answer sends someone to do. A misfiled row
        # is a defect in the evidence; a wrong setup is a re-measure; an
        # unknown setup is a missing input; out of scope is a gap; none
        # at all is work not started.
        if misfiled:
            reason = "evidence_misfiled"
        elif other_setup:
            reason = "evidence_for_another_setup"
        elif unknown_setup:
            reason = "setup_identity_unknown"
        elif saw_measurement:
            reason = "outside_measured_scope"
        else:
            reason = "no_envelope_measured"
        return ProviderQualification(
            capability=capability, qualifies=False, reason=reason,
            gap_m=gap_m, rise_m=rise_m)
    return ProviderQualification(
        capability=capability, qualifies=best >= gap_m,
        reason="meets_envelope" if best >= gap_m else "below_envelope",
        gap_m=gap_m, reach_m=best, rise_m=rise_m)


class CapabilityGuarantee(Strict):
    """Why a capability is available, or that it is not (owner ruling).

    THE INVARIANT: **no requirement before guarantee.** Content may
    require a capability. It may not require one the generator cannot
    prove the player can get. `reason` is what the proof was, so a
    refusal can say which door was shut rather than only that one was.
    """
    capability: str = Field(max_length=32)
    guaranteed: bool
    reason: Literal[
        # A: the permanent baseline satisfies it for everyone, forever.
        "permanent_baseline",
        # B: authoritative campaign state proves the player owns something
        #    that satisfies it.
        "already_possessed",
        # C: the Zone itself establishes it before the requirement. No
        #    producer yet -- see `capability_guarantee`.
        "established_in_zone",
        # D: the Forge can build something that satisfies it. Deferred.
        "forge_constructible",
        "not_guaranteed",
    ]


def capability_guarantee(
    capability: str,
    mechanics,
    established_earlier: tuple[str, ...] = (),
) -> CapabilityGuarantee:
    """Can the generator PROVE the player will be able to do this?

    The four cases are the owner's, in the owner's order, and the order
    matters: the cheapest proof that holds is the one reported, so a
    refusal is only ever reported when every case failed.

    A. PERMANENT BASELINE -- `BASELINE_CAPABILITIES`.
    B. ALREADY POSSESSED -- `owned_capabilities`, over the fold, which is
       the authoritative campaign state. Not over the loadout: the player
       can always slot what they own.
    C. ESTABLISHED EARLIER IN THE ZONE -- the caller passes the
       capabilities every route to this point has already been proven to
       pass through. **`zone.established_in_zone` produces that set**
       (D-2) and `topology._explore_acquiring` is where it is honoured
       (P02.1): the capability is not in hand at the Zone door and not
       in hand on reaching the room, but after the claim -- so the
       search runs from the entrance without it, and onward from the
       featured room with it.

       It stays a parameter rather than a lookup, so a caller with a
       different notion of "already established" can pass its own.
       Passing `()` still means "the Zone establishes nothing", which is
       true of every Zone that features no acquisition.
    D. FORGE-CONSTRUCTIBLE -- **not implemented.** It needs Forge access,
       guaranteed ingredients, and a proof that a legal configuration
       satisfying `capability` can be built from them, none of which
       exist. It is named in `reason` and unreachable, so the day the
       Forge lands the shape of the answer does not have to change.

    An unknown capability is refused rather than defaulted. A typo that
    silently means "no requirement" is the failure this whole invariant
    exists to prevent.
    """
    if capability not in ACTIVITY_CAPABILITIES:
        return CapabilityGuarantee(
            capability=capability, guaranteed=False, reason="not_guaranteed")
    if capability in BASELINE_CAPABILITIES:
        return CapabilityGuarantee(
            capability=capability, guaranteed=True,
            reason="permanent_baseline")
    if capability in owned_capabilities(mechanics):
        return CapabilityGuarantee(
            capability=capability, guaranteed=True,
            reason="already_possessed")
    if capability in established_earlier:
        return CapabilityGuarantee(
            capability=capability, guaranteed=True,
            reason="established_in_zone")
    return CapabilityGuarantee(
        capability=capability, guaranteed=False, reason="not_guaranteed")


def owned_affordance_tags(mechanics) -> tuple[str, ...]:
    """Which affordance tags this campaign can actually USE (§13.1).

    Over owned components, never slotted ones: you own the grapple whether
    or not it is in a slot, and you can always slot it. Evaluating this
    over the loadout would make a Zone's contents depend on what the
    player happened to have equipped when it generated, which is a Zone
    that lies about itself the moment they change slots.
    """
    primitives: set[str] = set()
    stats: set[str] = set()
    granted: set[str] = set()
    for owned in mechanics.owned:
        component = owned.component
        primitive = getattr(component, "primitive", None)
        if primitive is not None:
            primitives.add(primitive.type)
        stat = getattr(component, "stat", None)
        if stat is not None:
            stats.add(stat)
        # An AffordanceComponent grants its tag outright. §13.1's table
        # names the derived capability that makes each tag interactable,
        # and this component kind IS that capability rather than a proxy
        # for it: an Echo that reads "you can grind rails now" has to
        # actually unlock rails, or the component kind means nothing.
        if component.kind == "affordance":
            granted.add(component.tag)
    out: list[str] = []
    for tag, requirement in AFFORDANCE_REQUIREMENTS.items():
        needed_primitives = set(requirement.get("primitives", ()))
        needed_stats = set(requirement.get("stats", ()))
        if tag in granted:
            out.append(tag)
        elif not needed_primitives and not needed_stats:
            out.append(tag)                      # base-kit usable
        elif primitives & needed_primitives or stats & needed_stats:
            out.append(tag)
    return tuple(sorted(out))


def upgrade_is_legal(component, field: str, delta: float) -> bool:
    """Would this upgrade survive the fold?

    `_apply_upgrade` re-validates the component against its own field
    bounds, so an upgrade that would walk a value out of range raises
    rather than clamping. A GENERATOR needs to ask that question before
    emitting, because a fallback whose output validation refuses is a
    RuntimeError by construction, not a recoverable error.

    Public because the deterministic fallback is a first-class consumer:
    it proposes a Mk II and takes this answer for yes.
    """
    try:
        _apply_upgrade(component, field, delta, 0)
    except FoldError:
        return False
    return True


def modify_is_legal(component, op, owned=None, aliases=None) -> str:
    """Would this MODIFY survive the fold? Empty string for yes.

    Sibling of `upgrade_is_legal`, and it exists for the same reason and
    the same bug. `target_errors` checked that a MODIFY's target EXISTS
    and stopped there, so five separate refusals reached the fold instead
    — a third modifier on an action whose list caps at two, a duplicate
    modifier type, a modifier aimed at a primitive that has no damage to
    modify, an effect naming a resource the campaign does not own. Each
    was a `FoldError` inside `append_interpretation`, which is a crash
    rather than a repair prompt, and which repeated on every retry, so the
    Check could never be granted.

    Returns the reason rather than a bool because `_apply_modify` refuses
    for several different reasons and a repair loop can act on which.
    """
    try:
        modified, _ = _apply_modify(component, op, 0)
    except FoldError as exc:
        return str(exc).split(": ", 1)[-1]
    except Exception as exc:                     # pragma: no cover
        return str(exc)
    if owned is None:
        return ""
    # The fold runs this immediately after `_apply_modify`, and it is the
    # half that catches an added effect or condition naming a resource
    # nobody owns. Skipped when the caller has no component set to check
    # against, which keeps the two-argument form honest rather than
    # quietly checking less than it looks like it does.
    try:
        _check_rule_references(modified, owned, aliases or {}, 0)
    except FoldError as exc:
        return str(exc).split(": ", 1)[-1]
    return ""


def merge_capacity_is_legal(survivor, absorbed) -> bool:
    """Would `capacity="sum"` walk the survivor's `max_value` out of range?

    The default is `"sum"` (`echo.py::MergeOperation`), and two resources
    near the top of the allowed range sum past it. `_apply_upgrade`
    re-validates, so the fold raises; asked here, it is a repair prompt.
    """
    return upgrade_is_legal(survivor, "max_value", absorbed.max_value)


def derive_mechanics(log) -> Mechanics:
    """Fold an interpretation log into live mechanics.

    Pure, total on a well-formed log, and deterministic: the same log yields
    the same `Mechanics` on any client, after any reload, whatever order the
    Checks actually confirmed in.

    Raises `FoldError` on a corrupt log rather than producing a partial
    result — see the module docstring.
    """
    entries = sorted(log, key=lambda i: i.interpretation_seq)
    seen_seq: set[int] = set()
    for entry in entries:
        if entry.interpretation_seq in seen_seq:
            raise FoldError(
                f"duplicate interpretation_seq {entry.interpretation_seq} "
                f"({entry.echo_id}); sequence is assigned once and never reused"
            )
        seen_seq.add(entry.interpretation_seq)

    components: dict[str, E.Component] = {}
    provenance: dict[str, list[ComponentProvenance]] = {}
    mk: dict[str, int] = {}
    aliases: dict[str, str] = {}
    links: list[LinkEdge] = []
    #: Creation order, so the HUD lays a campaign out the same way every time.
    order: list[str] = []

    def resolve(component_id: str) -> str:
        seen: set[str] = set()
        current = component_id
        while current in aliases:
            if current in seen:
                raise FoldError(f"alias cycle through '{component_id}'")
            seen.add(current)
            current = aliases[current]
        return current

    def live(component_id: str, what: str, seq: int) -> str:
        target = resolve(component_id)
        if target not in components:
            raise FoldError(
                f"interpretation_seq {seq}: {what} targets "
                f"'{component_id}', which does not exist at that point in "
                f"the log"
            )
        return target

    for entry in entries:
        seq = entry.interpretation_seq

        def record(cid: str, op: str, note: str = "") -> None:
            provenance.setdefault(cid, []).append(ComponentProvenance(
                interpretation_seq=seq,
                source_location_id=entry.source_location_id,
                source_item_name=entry.source_item_name,
                source_game=entry.source_game,
                source_recipient_name=entry.source_recipient_name,
                operation=op, note=note[:96],
            ))

        for op in entry.operations:
            if op.op == "create":
                cid = op.component.component_id
                if cid in components or cid in aliases:
                    raise FoldError(
                        f"interpretation_seq {seq}: component '{cid}' already "
                        f"exists; ids are unique for the life of a campaign"
                    )
                components[cid] = op.component
                order.append(cid)
                mk[cid] = 1
                record(cid, "create", op.component.display_name)
                _check_rule_references(op.component, components, aliases, seq)

            elif op.op == "upgrade":
                cid = live(op.target, "upgrade", seq)
                components[cid] = _apply_upgrade(
                    components[cid], op.field, op.delta, seq
                )
                mk[cid] += 1
                record(cid, "upgrade", f"{op.delta:+g} {op.field}")

            elif op.op == "modify":
                cid = live(op.target, "modify", seq)
                components[cid], note = _apply_modify(components[cid], op, seq)
                _check_rule_references(components[cid], components, aliases, seq)
                mk[cid] += 1
                record(cid, "modify", note)

            elif op.op == "link":
                source = live(op.source, "link source", seq)
                target = live(op.target, "link target", seq)
                if source == target:
                    raise FoldError(
                        f"interpretation_seq {seq}: link source and target "
                        f"resolve to the same component '{source}'"
                    )
                # D16 G1: A PIECE OF GEAR IS ITS ATOMS AND NOTHING ELSE.
                # Powering, filling, gating or scaling one would be the
                # compound effect ruling 2 withholds until a clause
                # catalogue exists. (Upgrade, modify and merge already
                # refuse any kind they do not list.)
                for end, cid in (("source", source), ("target", target)):
                    if components[cid].kind == "gear":
                        raise FoldError(
                            f"interpretation_seq {seq}: link {end} '{cid}' "
                            "is Gear, which links to nothing: one bounded "
                            "stat effect per piece until a clause "
                            "catalogue exists (owner ruling 2)"
                        )
                links.append(LinkEdge(link=op.link, source=source,
                                      target=target, strength=op.strength))
                record(target, "link", f"{op.link} from {source}")

            elif op.op == "merge":
                absorbed = live(op.absorbed, "merge absorbed", seq)
                survivor = live(op.survivor, "merge survivor", seq)
                if absorbed == survivor:
                    raise FoldError(
                        f"interpretation_seq {seq}: '{op.absorbed}' and "
                        f"'{op.survivor}' already resolve to the same "
                        f"component; there is nothing to merge"
                    )
                for side, cid in (("absorbed", absorbed),
                                  ("survivor", survivor)):
                    if components[cid].kind != "resource":
                        raise FoldError(
                            f"interpretation_seq {seq}: merge {side} "
                            f"'{cid}' is a '{components[cid].kind}'; only "
                            f"resources may merge"
                        )
                if op.capacity == "sum":
                    components[survivor] = _apply_upgrade(
                        components[survivor], "max_value",
                        components[absorbed].max_value, seq,
                    )
                # Provenance is unioned, in sequence order, so neither source
                # item stops being credited.
                provenance[survivor] = sorted(
                    provenance.get(survivor, []) + provenance.get(absorbed, []),
                    key=lambda p: p.interpretation_seq,
                )
                mk[survivor] += mk.get(absorbed, 0)
                record(survivor, "merge", f"absorbed {absorbed}")
                # The alias is permanent: every later mention of the absorbed
                # id, and every rule already written against it, keeps
                # resolving here for the rest of the campaign.
                aliases[absorbed] = survivor
                for old, new in list(aliases.items()):
                    if new == absorbed:
                        aliases[old] = survivor
                # Links are rewritten HERE, not resolved at read time. The
                # alias table catches every later MENTION of the absorbed
                # id, but a link written before the merge is not a mention
                # — it is a stored edge, and it kept pointing at a
                # component this fold has just deleted. The client is told
                # the ids it receives are canonical (`echo_runtime.gd`
                # `_powers_link`), and it was not true: a `powers` edge
                # whose source merged away asked the pool to spend from a
                # bar that no longer exists, which always refuses, so the
                # Echo could never fire again — permanently, since aliases
                # are permanent.
                links = _relink(links, absorbed, survivor, seq)
                del components[absorbed]
                order.remove(absorbed)
                provenance.pop(absorbed, None)
                mk.pop(absorbed, None)

    _require_singular_links(links)
    _require_power_links(components, links)
    _require_fill_links(components, links)

    return Mechanics(
        owned=tuple(
            OwnedComponent(
                component=components[cid], mk=mk[cid],
                provenance=tuple(provenance[cid]),
            )
            for cid in order
        ),
        aliases=tuple(sorted(aliases.items())),
        links=tuple(links),
    )


def _apply_upgrade(component, field: str, delta: float, seq: int):
    """Rebuild the component with one field moved, and revalidate it.

    Revalidation is the point: an upgrade cannot walk a value out of its
    declared range one small step at a time, because the bounds run again on
    every apply.
    """
    allowed = E.UPGRADABLE_FIELDS.get(component.kind, ())
    if field not in allowed:
        raise FoldError(
            f"interpretation_seq {seq}: '{field}' is not upgradable on a "
            f"'{component.kind}' component"
        )
    data = component.model_dump()
    if field in data and field != "primitive":
        holder, current = data, data[field]
    elif component.kind == "action" and field in data["primitive"]:
        holder, current = data["primitive"], data["primitive"][field]
    else:
        raise FoldError(
            f"interpretation_seq {seq}: '{component.component_id}' has no "
            f"field '{field}' to upgrade"
        )
    if current is None:
        raise FoldError(
            f"interpretation_seq {seq}: '{component.component_id}' has no "
            f"'{field}' value set, so there is nothing to grow"
        )
    updated = current + delta
    holder[field] = int(round(updated)) if isinstance(current, int) else updated
    try:
        return type(component).model_validate(data)
    except Exception as exc:
        raise FoldError(
            f"interpretation_seq {seq}: upgrading '{field}' on "
            f"'{component.component_id}' by {delta:+g} leaves it invalid: "
            f"{exc}"
        ) from exc


def _apply_modify(component, op, seq: int):
    """Add one capability to an existing component."""
    data = component.model_dump()
    if op.add_modifier is not None:
        if component.kind != "action":
            raise FoldError(
                f"interpretation_seq {seq}: a modifier can only be added to "
                f"an action, not a '{component.kind}'"
            )
        data["modifiers"] = list(data["modifiers"]) + [
            op.add_modifier.model_dump()
        ]
        note = op.add_modifier.type
    elif op.add_effect is not None:
        if component.kind != "rule":
            raise FoldError(
                f"interpretation_seq {seq}: an effect can only be added to a "
                f"rule, not a '{component.kind}'"
            )
        data["effects"] = list(data["effects"]) + [op.add_effect.model_dump()]
        note = op.add_effect.type
    else:
        if component.kind != "rule":
            raise FoldError(
                f"interpretation_seq {seq}: a condition can only be added to "
                f"a rule, not a '{component.kind}'"
            )
        data["conditions"] = list(data["conditions"]) + [
            op.add_condition.model_dump()
        ]
        note = op.add_condition.type
    try:
        return type(component).model_validate(data), note
    except Exception as exc:
        raise FoldError(
            f"interpretation_seq {seq}: modifying "
            f"'{component.component_id}' leaves it invalid: {exc}"
        ) from exc


def _relink(links, absorbed: str, survivor: str, seq: int):
    """Point every stored edge at the survivor, and collapse the twins.

    Rewriting rather than resolving-at-read is deliberate. The alias table
    is consulted for every later MENTION of an id, but a link written
    before the merge is not a mention — it is a stored edge, and the
    client is told (`echo_runtime.gd::_powers_link`) that the ids it
    receives are already canonical. Resolving at read would mean teaching
    four call sites in two languages to do it, and `stat_stack.gd` would
    still be reading a dict keyed by a raw id.

    Rewriting creates twins: two edges of the same kind between what are
    now the same pair. Exact duplicates — same strength — are one edge
    asserted twice, so they collapse. Twins that DISAGREE on strength are
    left alone here; `_require_singular_links` decides whether that is
    legal for the kind, because the answer differs per kind and belongs
    with the other structural checks rather than buried in a merge.
    """
    out = []
    for link in links:
        source = survivor if link.source == absorbed else link.source
        target = survivor if link.target == absorbed else link.target
        if source == target:
            # Only reachable if a link somehow spanned the two merged
            # resources. An edge from a thing to itself has no runtime
            # meaning, and the LINK op refuses to create one.
            raise FoldError(
                f"interpretation_seq {seq}: merging '{absorbed}' into "
                f"'{survivor}' would leave a '{link.link}' link from "
                f"'{survivor}' to itself"
            )
        moved = LinkEdge(link=link.link, source=source, target=target,
                         strength=link.strength)
        if moved not in out:
            out.append(moved)
    return out


#: Link kinds the client reads as at-most-one-per-target, and where.
#: `powers` picks the FIRST match (`echo_runtime.gd::_powers_link`) and
#: `scales` builds a dict keyed by target (`stat_stack.gd::evaluate`), so a
#: second edge of either kind is not combined — it is silently discarded,
#: and which one survives depends on fold order. `fills` and `gates` are
#: genuinely many: both clients iterate, and several actions filling one
#: bar or several bars gating one action are shapes the graph in ECHOES
#: section 4 is meant to express.
SINGULAR_LINK_KINDS = ("powers", "scales")


def _require_singular_links(links) -> None:
    """At most one `powers` per action and one `scales` per trait.

    Enforced here rather than trusted, because the client cannot enforce
    it: by the time `stat_stack` sees two `scales` edges on one trait the
    fold has already published both, and all it can do is pick one. Making
    the second edge unrepresentable is the only place the choice does not
    have to be arbitrary.
    """
    for kind in SINGULAR_LINK_KINDS:
        seen: dict[str, LinkEdge] = {}
        for link in links:
            if link.link != kind:
                continue
            first = seen.get(link.target)
            if first is not None:
                raise FoldError(
                    f"'{link.target}' is the target of two '{kind}' links "
                    f"(from '{first.source}' and '{link.source}'); that kind "
                    f"is at most one per target, because the client reads "
                    f"one and would discard the other"
                )
            seen[link.target] = link


def _require_power_links(components, links) -> None:
    """A beam, a hover or a block with nothing to spend is a movement
    contract, not an ability. The link is what makes it an ability, so it is
    mandatory rather than encouraged — and it can only be checked here,
    where the links are known."""
    powered = {
        link.target for link in links
        if link.link == "powers"
    }
    for cid, component in components.items():
        if component.kind != "action":
            continue
        if component.primitive.type not in E.POWERED_PRIMITIVES:
            continue
        if cid not in powered:
            raise FoldError(
                f"action '{cid}' uses '{component.primitive.type}', which "
                f"must be powered by a resource; no 'powers' link targets it"
            )


def _require_fill_links(components, links) -> None:
    """`restore_resource` names no resource on purpose — the `fills` link
    says which one — so a restore with no fills link is a button that
    refills nothing. Same medicine as the powered verbs."""
    filling = {
        link.source for link in links
        if link.link == "fills"
    }
    for cid, component in components.items():
        if component.kind != "action":
            continue
        if component.primitive.type != "restore_resource":
            continue
        if cid not in filling:
            raise FoldError(
                f"action '{cid}' uses 'restore_resource' but is the source "
                f"of no 'fills' link; it would refill nothing"
            )
