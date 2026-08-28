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
    from . import echo as E
except ImportError:  # pragma: no cover
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
AFFORDANCE_REQUIREMENTS: dict[str, dict[str, tuple[str, ...]]] = {
    "grapple_anchor": {"primitives": (
        "grapple_to_surface", "grapple_pull_target", "grapple_swing")},
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
}


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
