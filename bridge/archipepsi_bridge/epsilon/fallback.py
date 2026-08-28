"""Deterministic fallback generators (EPSILON_SPEC §12).

Failure recovery AND the test oracle for engine-side generation: the whole
loop with no API cost and no nondeterminism. Output goes through the same
validators as model output — no exceptions.
"""

from __future__ import annotations

import random

from ..schemas import constants as C
from ..schemas import migration as MG
from ..schemas import echo as E
from ..schemas.echo import COMPLEXITY_BUDGETS
from .concepts import mode_for_operations, read_concepts
from .requests import EchoGenerationRequest, ZoneGenerationRequest


def _theme_for(target_game: str) -> str:
    theme = C.THEME_BY_GAME_HINT.get(target_game)
    if theme is None:
        theme = C.THEMES[C.prng_seed(target_game, "fallback_theme")
                         % len(C.THEMES)]
    return theme


def _clamp(text: str, limit: int) -> str:
    return text if len(text) <= limit else text[: limit - 1] + "…"


def fallback_zone(request: ZoneGenerationRequest) -> dict:
    """Linear corridor→arena→corridor→platform→brute-arena, trimmed to the
    allocated Check count. The finale is a single brute arena with Check 030."""
    locations = list(request.locations)
    theme = _theme_for(request.campaign.target_game)
    n = request.campaign.zone_index

    if request.campaign.is_finale:
        return {
            "schema_version": 7,
            "zone_id": request.zone_id,
            "display_name": _clamp(
                f"Terminal Relay {n:03d}", C.MAX_TEXT_LEN),
            "target_game": request.campaign.target_game,
            "theme": theme,
            "designer_note": "Deterministic fallback finale.",
            "chambers": [
                {"id": "c1", "type": "corridor", "length": 14.0, "width": 6.0},
                {"id": "c2", "type": "arena", "width": 22.0, "depth": 22.0,
                 "wall_height": 6.0, "objective": "kill_all",
                 "enemies": [{"archetype": "brute", "count": 1}],
                 "reward_location_id": locations[0].location_id},
            ],
        }

    # Deterministic, but not IDENTICAL. Every Zone used to be the same
    # five rooms at the same five sizes, so playing four in a row was
    # playing one four times -- with only the theme changing. The
    # dimensions and the order of the reward rooms are now drawn from the
    # zone index, so zone 3 differs from zone 4 while zone 3 is still
    # always zone 3. Reproducibility is the point of this provider; the
    # sameness never was.
    #
    # This is still the OFFLINE FIXTURE. Real variety is the Claude
    # provider composing from the vocabulary; widening this one is about
    # making a keyless campaign bearable, not about replacing that.
    rng = random.Random(f"archipepsi/fallback/zone/{n}")

    step = round(rng.uniform(0.4, 0.9), 2)
    # I3/I4: the mandatory gap stays inside the base kit's safe reach at
    # whatever rise was drawn. The bound moves with `step`, so it is
    # asked rather than assumed.
    gap = round(min(rng.uniform(1.4, 2.4), C.max_safe_gap(step)), 2)

    reward_chambers = [
        {"id": "c2", "type": "arena",
         "width": round(rng.uniform(14.0, 24.0), 1),
         "depth": round(rng.uniform(12.0, 22.0), 1),
         "wall_height": round(rng.uniform(4.5, 7.0), 1),
         "objective": "kill_all",
         "enemies": [{"archetype": "melee", "count": rng.randint(2, 4)}]},
        {"id": "c4", "type": "platform_path",
         "segment_count": rng.randint(3, 7),
         "gap_size": gap, "vertical_step": step,
         "objective": "platform_to_goal"},
        {"id": "c5", "type": "arena",
         "width": round(rng.uniform(16.0, 26.0), 1),
         "depth": round(rng.uniform(14.0, 24.0), 1),
         "wall_height": round(rng.uniform(5.0, 7.5), 1),
         "objective": "kill_all",
         # ONE brute. `MAX_BRUTES_PER_ZONE` is a zone-wide cap, not a
         # per-room one, and drawing 1-2 here put zone 6 over it: the
         # repair loop could not fix a fallback, so generation failed
         # outright. Variety inside the rules, or it is not variety.
         "enemies": [{"archetype": "brute", "count": 1},
                     {"archetype": "melee", "count": rng.randint(1, 3)}]},
    ]
    # Which room you meet first changes too, so the shape of a Zone is
    # not just its measurements.
    rng.shuffle(reward_chambers)

    chambers: list[dict] = [
        {"id": "c1", "type": "corridor",
         "length": round(rng.uniform(10.0, 20.0), 1),
         "width": round(rng.uniform(4.5, 8.0), 1)}]
    for i, loc in enumerate(locations[:3]):
        chamber = dict(reward_chambers[i])
        chamber["reward_location_id"] = loc.location_id
        if i == 1:
            chambers.append({"id": "c3", "type": "corridor",
                             "length": round(rng.uniform(8.0, 18.0), 1),
                             "width": round(rng.uniform(4.0, 7.0), 1)})
        chambers.append(chamber)

    _add_features(chambers, request.unlocked_affordances, n)

    return {
        "schema_version": 7,
        "zone_id": request.zone_id,
        "display_name": _clamp(
            f"Relay {n:03d}: {request.campaign.target_game}", C.MAX_TEXT_LEN),
        "target_game": request.campaign.target_game,
        "theme": theme,
        "designer_note": "Deterministic fallback zone.",
        "chambers": chambers,
    }


#: The schema's own upper bound on a corridor (`CorridorChamber.width`).
#: Widening past it would make a Zone the validator refuses, which is the
#: opposite of what the widening is for.
MAX_CORRIDOR_WIDTH = 10.0


def _add_features(chambers: list[dict], unlocked: tuple[str, ...],
                  zone_index: int = 0) -> None:
    """Hang the unlocked affordances (§13) off the plain chambers.

    Only chambers with nothing riding on them: a feature may not share a
    chamber with an AP reward or a gating objective (§13.2), and
    `validate_zone` refuses the Zone if one does. Placing them only where
    they are legal keeps the fallback's Zones acceptable by construction
    rather than by a validator catching it afterwards.

    Every tag here is one the campaign can already USE — `unlocked` comes
    from `owned_affordance_tags`, over owned mechanics. A campaign that has
    interpreted nothing still gets the two base-kit tags, so even the first
    Zone has something optional in it.
    """
    if not unlocked:
        return
    # A corridor is the only chamber type that may carry one: every other
    # type has a Check or a gating objective. It also has to be wide
    # enough to hold something beside the walking lane, so widen the ones
    # that will carry a feature rather than emitting a Zone the validator
    # would refuse. Widening a connector costs nothing.
    plain = [c for c in chambers
             if c.get("reward_location_id") is None
             and not c.get("objective")]
    if not plain:
        return
    # Widen enough for the WIDEST tag this Zone will actually place, and
    # never past the schema's corridor cap. A single conservative width
    # would refuse a rail from a corridor it fits in perfectly well.
    wanted = [t for t in unlocked if t in C.FEATURE_MIN_WIDTH]
    if not wanted:
        return
    widest = min(MAX_CORRIDOR_WIDTH,
                 max(C.FEATURE_MIN_WIDTH[t] for t in wanted))
    for chamber in plain:
        chamber["width"] = max(float(chamber.get("width", 5.0)), widest)
    # Deal round-robin so a run that unlocks five tags does not stack all
    # five in the first corridor. Both loops are ordered, so the same
    # campaign lays out the same Zone twice — the fallback is the
    # deterministic provider, and a feature set that wandered between runs
    # would make the integration run's assertions unreproducible.
    # Rotated by the Zone's index. Both the tag order and the corridor
    # list are fixed, so a plain round-robin dealt the same hand every
    # time: a fully-unlocked campaign has 7 tags, a fallback Zone has 2
    # corridors capped at 3 features each, and the sixth tag in sorted
    # order was dropped from EVERY Zone, forever. Rotating means each
    # Zone drops a different one, so all seven appear across a campaign.
    ordered = sorted(unlocked)
    if ordered:
        offset = zone_index % len(ordered)
        ordered = ordered[offset:] + ordered[:offset]
    for index, tag in enumerate(ordered):
        chamber = plain[index % len(plain)]
        # A tag the corridor cannot hold is skipped rather than emitted
        # for the validator to refuse: the fallback's job is to always
        # produce something acceptable.
        if float(chamber["width"]) < C.FEATURE_MIN_WIDTH.get(
                tag, C.MIN_FEATURE_CHAMBER_WIDTH):
            continue
        features = list(chamber.get("features", []))
        # The schema's per-chamber cap is the only cap there is; when the
        # plain chambers are full the remaining tags simply do not appear
        # in this Zone. They are optional content, so dropping one costs
        # nothing — and the next Zone deals from the same ordered set.
        if len(features) >= 3:
            continue
        # Off-centre and staggered down the length. The builder pushes a
        # feature clear of the walking lane whatever it is handed, but
        # asking for the lane and relying on that would be writing a bug
        # that another file happens to correct.
        lateral = 0.18 if index % 2 == 0 else 0.82
        along = 0.3 + 0.2 * (index // 2 % 3)
        features.append({"tag": tag, "at": (lateral, along)})
        chamber["features"] = features


# ---------------------------------------------------------------------------
# Echo
# ---------------------------------------------------------------------------

def _common(request: EchoGenerationRequest, description: str,
            tags: list[str]) -> dict:
    src = request.source
    return {
        "schema_version": 8,
        "echo_id": request.required_echo_id,
        # Overwritten by `transitions.append_interpretation`, which owns
        # sequence assignment. A provider never chooses its own number.
        "interpretation_seq": 0,
        "source_location_id": src.location_id,
        "source_item_name": src.item_name,
        "source_game": src.source_game,
        "source_recipient_name": src.recipient_name,
        # Both are stamped by `_read_and_label` once the operations are
        # settled — the mode is derived FROM them, so choosing it here
        # would describe a draft rather than the finished Echo.
        "concepts": (),
        "mode": "literal",
        "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
        "description": _clamp(description, C.MAX_TEXT_LEN),
        "tags": tags,
    }


def _primary(request: EchoGenerationRequest, *, archetype: str, cooldown: float,
             initiator: dict, modifiers: list[dict] | None = None,
             description: str, tags: list[str]) -> dict:
    """One CREATE, one Action. The v8 shape; the same §12.2 decisions.

    The heuristics below are pinned by the packet and did not change — only
    what they emit did. Keeping the signature means the mapping table stays
    readable as a mapping table rather than becoming a wall of component
    dictionaries.
    """
    src = request.source
    return {**_common(request, description, tags), "operations": [{
        "op": "create",
        "component": {
            "kind": "action",
            "component_id": MG.component_id_for("act", src.location_id),
            "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
            "description": _clamp(description, C.MAX_TEXT_LEN),
            "slot": MG.ARCHETYPE_SLOT.get(archetype, "echo_a"),
            "cooldown": cooldown,
            "primitive": initiator,
            "modifiers": modifiers or [],
        },
    }]}


def _primary_and_resource(
        request: EchoGenerationRequest, *, archetype: str, cooldown: float,
        initiator: dict, resource: dict, description: str,
        tags: list[str], powers: float | None = None) -> dict:
    """One Action and one Resource, from one item.

    The recorded S1 decision is that the fallback stays deliberately boring,
    and this does not breach it: still `CREATE` only, still no links, merges
    or rules, still nothing that can dangle a target or fail a fold. What it
    adds is a second component from a single interpretation, which is the
    only way the resource pipeline — grant, fold, channel assignment,
    snapshot, HUD — is exercised end to end by the integration run.

    S5 closed the loop: `powers` names the press cost the resource pays
    for the action, so the button finally spends the bar it arrived with.
    Starting below full with a slow regen keeps the pressure valve visible.
    """
    src = request.source
    return {**_common(request, description, tags), "operations": [
        {
            "op": "create",
            "component": {
                "kind": "action",
                "component_id": MG.component_id_for("act", src.location_id),
                "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
                "description": _clamp(description, C.MAX_TEXT_LEN),
                "slot": MG.ARCHETYPE_SLOT.get(archetype, "echo_a"),
                "cooldown": cooldown,
                "primitive": initiator,
                "modifiers": [],
            },
        },
        {
            "op": "create",
            "component": {
                "kind": "resource",
                "component_id": MG.component_id_for("res", src.location_id),
                **resource,
            },
        },
    ] + ([] if powers is None else [{
        "op": "link", "link": "powers",
        "source": MG.component_id_for("res", src.location_id),
        "target": MG.component_id_for("act", src.location_id),
        "strength": powers,
    }])}


def _create_ops(request: EchoGenerationRequest, description: str,
                tags: list[str], components: list[dict]) -> dict:
    """1-4 operations, in the order given. An entry carrying its own `op`
    passes through (S5 links); anything else is wrapped as a CREATE. Still
    the boring shape — nothing reaches backward into the campaign — but the
    fold requires a rule's resource, and a link's endpoints, to exist
    EARLIER in the interpretation, so order here is load-bearing."""
    return {**_common(request, description, tags), "operations": [
        component if "op" in component
        else {"op": "create", "component": component}
        for component in components
    ]}


def _passive(request: EchoGenerationRequest, *, effects: list[dict],
             description: str, tags: list[str]) -> dict:
    """One CREATE per passive, each a Trait. Traits are always on, so a
    fallback passive is strictly better for the player than v0.7's was."""
    src = request.source
    return {**_common(request, description, tags), "operations": [{
        "op": "create",
        "component": {
            "kind": "trait",
            "component_id": MG.component_id_for("trait", src.location_id,
                                                str(index)),
            "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
            "description": _clamp(description, C.MAX_TEXT_LEN),
            "stat": MG.PASSIVE_STAT[effect["type"]],
            "multiplier": effect["multiplier"],
        },
    } for index, effect in enumerate(effects)]}


def _budget_room(mechanics, *, resources: int = 0, rules: int = 0,
                 request=None) -> bool:
    """Whether the campaign can absorb this many more without breaching a
    hard budget (§16). The fallback is the last resort AFTER validation has
    already refused the provider — a fallback the same validation then
    refuses is a RuntimeError in `_pipeline` ("a bug in our own
    generator"), so a resource- or rule-bearing outcome must step aside
    near the ceiling and let the item read as its budget-free shape.

    Reads the REQUEST when no fold is handed over, which is the case that
    actually matters. `FallbackEpsilonProvider` and `MockEpsilonProvider`
    are called through the provider protocol, which has no `mechanics`
    parameter — so both were asking this question with `None` and always
    hearing "yes". At a full resource budget that produced an Echo the
    validator refused, burned the one repair round, and only then reached
    the last-resort builder (which does get the fold). With
    `--epsilon=mock` the player watched a run that never involved a model
    report "EPSILON OFFLINE — FALLBACK USED".

    S10 put `budget_headroom` in the request for exactly this shape of
    question, and a provider reading what it was given is the right way
    round: it sees what any other provider sees.
    """
    owned_counts: dict[str, int] = {}
    if mechanics is not None:
        for component in mechanics.owned:
            owned_counts[component.kind] = owned_counts.get(
                component.kind, 0) + 1
    elif request is not None and getattr(request, "budget_headroom", None):
        for kind, (owned, _soft, _hard) in request.budget_headroom.items():
            owned_counts[kind] = int(owned)
    else:
        return True

    return (owned_counts.get("resource", 0) + resources
            <= COMPLEXITY_BUDGETS["resource"][1]
            and owned_counts.get("rule", 0) + rules
            <= COMPLEXITY_BUDGETS["rule"][1])


#: What to raise when an item turns out to be a sequel, per field, and by
#: how much. Ordered: the first field the target actually has, wins.
#: Deltas are deliberately modest — a Mk II should read as "the same thing,
#: better", not as a replacement — and every one is checked against the
#: target's own bounds before it is emitted.
_UPGRADE_LADDER = (
    ("damage", 4.0),
    ("damage_per_second", 6.0),
    ("range", 6.0),
    ("reach", 0.6),
    ("radius", 1.0),
    ("pull_force", 3.0),
    ("force", 2.0),
    ("amount", 8.0),
    ("max_value", 25.0),
    ("multiplier", 0.15),
    ("cooldown", -0.2),
)


def _family_of_summary(summary) -> str:
    """What makes two components "the same thing" for evolution.

    ECHOES §11: ancestry is semantic, not textual — *Hookshot* and
    *Longshot* are one grapple because they resolve to the same verb, not
    because their names rhyme. The request's `detail` carries that verb
    for an action and the stat for a trait, which is exactly the key.
    """
    if summary.kind not in ("action", "trait"):
        return ""
    return f"{summary.kind}:{summary.detail}"


def _as_sequel(interpretation: dict, request: EchoGenerationRequest):
    """Turn a CREATE into an UPGRADE when the campaign already owns the
    family — the *Hookshot → Longshot* rule, ECHOES §11.

    Works from the REQUEST, not from the fold: a provider sees what it is
    given and nothing else, and the fallback is a provider. Everything it
    needs is in `player_state.owned_components` — the family key, and the
    bounds each field still has room inside.

    Returns None when there is nothing to evolve, when the item is not a
    single-component interpretation, or when every rung of the ladder
    would leave the target's declared range. In all three cases the caller
    keeps its ordinary CREATE, so this can only make the fallback richer,
    never invalid.
    """
    operations = interpretation.get("operations", [])
    if len(operations) != 1 or operations[0].get("op") != "create":
        return None
    component = operations[0]["component"]
    if component["kind"] not in ("action", "trait"):
        return None
    primitive = component.get("primitive")
    family = (f"action:{primitive['type']}" if primitive
              else f"trait:{component.get('stat')}")

    for owned in request.player_state.owned_components:
        if _family_of_summary(owned) != family:
            continue
        headroom = {field: (current, low, high)
                    for field, current, low, high in owned.upgradable}
        for field, delta in _UPGRADE_LADDER:
            if field not in headroom:
                continue
            current, low, high = headroom[field]
            if not (low <= current + delta <= high):
                continue
            return {
                **interpretation,
                "description": _clamp(
                    "The same %s, %s. Mk %d."
                    % (owned.display_name,
                       "sharper" if delta >= 0 else "quicker", owned.mk + 1),
                    C.MAX_TEXT_LEN),
                "tags": list(interpretation.get("tags", [])) + ["evolution"],
                "operations": [{
                    "op": "upgrade",
                    "target": owned.component_id,
                    "field": field,
                    "delta": delta,
                }],
            }
    return None


#: A concept the §15 reader produces -> the status an item carrying it
#: makes a weapon apply. ECHOES §3's own MODIFY example is *Fire Flower*
#: making the gun's hits apply `burning`, and this is that rule written
#: down: the concept the item reads as decides the status, so the
#: disposition is derived from the reading rather than from the name.
_CONCEPT_STATUS = {
    "fire": ("burning", 1.2, 3.0),
    "cold": ("slowed", 0.8, 4.0),
    "electricity": ("shocked", 1.0, 2.5),
    "slowness": ("slowed", 0.6, 5.0),
    "brittleness": ("vulnerable", 0.9, 3.0),
    "decay": ("poisoned", 1.0, 5.0),
}


def _as_enhancement(interpretation: dict, request: EchoGenerationRequest):
    """Turn a CREATE into a MODIFY when the item reads as an element and
    the campaign already owns something that hits — the *Fire Flower*
    rule, ECHOES §3.

    Like `_as_sequel`, this works from the REQUEST alone and returns None
    whenever it cannot land, so the caller keeps its ordinary CREATE. The
    three ways it can fail to land are all visible from the summary: the
    target must be an action on a damage primitive, it must have room
    (`modifiers` caps at two), and the type must not already be there.

    Preferring MODIFY over another CREATE is what stops a campaign full of
    elemental items from being a campaign full of guns.
    """
    concepts = read_concepts(request.source.item_name,
                             request.source.source_game)
    match = next((c for c in concepts if c in _CONCEPT_STATUS), None)
    if match is None:
        return None
    status, magnitude, duration = _CONCEPT_STATUS[match]

    for owned in request.player_state.owned_components:
        if owned.kind != "action" or owned.detail not in E.DAMAGE_PRIMITIVES:
            continue
        if len(owned.modifiers) >= 2 or "apply_status_on_hit" in owned.modifiers:
            continue
        return {
            **interpretation,
            "description": _clamp(
                "%s now leaves %s behind. Mk %d."
                % (owned.display_name, status, owned.mk + 1),
                C.MAX_TEXT_LEN),
            "tags": list(interpretation.get("tags", [])) + ["enhancement"],
            "operations": [{
                "op": "modify",
                "target": owned.component_id,
                "add_modifier": {
                    "type": "apply_status_on_hit",
                    "status": status,
                    "duration": duration,
                    "magnitude": magnitude,
                },
            }],
        }
    return None


def _as_confluence(interpretation: dict, request: EchoGenerationRequest):
    """Turn a resource CREATE into a CREATE + MERGE once the campaign is
    at its resource budget — the *Blue Estus* rule, ECHOES §3.

    §16 says that over soft budget the request asks for `MERGE`, and this
    is the shape that answers it: the new economy is created and folded
    into an existing one, so the item is genuinely credited (provenance
    unions, Mk sums) while the channel count does not move. Fifteen HUD
    channels is the hard ceiling, and a campaign that spent them on
    sixteen flasks would have nowhere left to put the interesting ones.

    Returns None unless the merge would LAND: `capacity="sum"` walks the
    survivor's `max_value` up by the absorbed's, and the fold re-validates
    rather than clamping, so a survivor near the 1000 ceiling is not a
    candidate. That bound is in the summary already, as `upgradable`.
    """
    if "resource" not in (request.over_soft_budget or ()):
        return None
    operations = list(interpretation.get("operations", []))
    # The merge is APPENDED, so there has to be room for it under §2's
    # four-operation ceiling. The fallback's resource shapes are two and
    # three operations wide (a bar plus what spends it, plus the `powers`
    # link between them), which is what makes appending the right move:
    # the link keeps naming the absorbed id, and the fold rewrites both
    # endpoints onto the survivor when the merge lands.
    if len(operations) >= C.ECHO_MAX_OPERATIONS:
        return None
    created = [op for op in operations
               if op.get("op") == "create"
               and op["component"]["kind"] == "resource"]
    if len(created) != 1:
        return None
    component = created[0]["component"]
    incoming = float(component.get("max_value", 0.0))

    for owned in request.player_state.owned_components:
        if owned.kind != "resource":
            continue
        room = {field: (current, low, high)
                for field, current, low, high in owned.upgradable}
        if "max_value" not in room:
            continue
        current, low, high = room["max_value"]
        if not (low <= current + incoming <= high):
            continue
        return {
            **interpretation,
            "description": _clamp(
                "Folded into %s rather than adding a sixteenth meter."
                % owned.display_name, C.MAX_TEXT_LEN),
            "tags": list(interpretation.get("tags", [])) + ["confluence"],
            "operations": operations + [
                {"op": "merge",
                 "absorbed": component["component_id"],
                 "survivor": owned.component_id,
                 "capacity": "sum"},
            ],
        }
    return None


def fallback_echo(request: EchoGenerationRequest, *,
                  mechanics=None) -> dict:
    """The §12.2 heuristics, then one question: is this a sequel?

    S6. Every outcome below is a fresh CREATE, which is what made a
    26-Check campaign twenty-six unrelated things. Running the answer
    through `_as_sequel` first means an item whose verb the campaign
    already owns evolves it instead — *Longshot* after *Hookshot* is one
    grapple at Mk II, exactly as ECHOES §11 describes, and the archive's
    provenance chain becomes something real play produces rather than
    something only a fixture ever showed.
    """
    interpretation = _fallback_echo_create(request, mechanics=mechanics)
    return _read_and_label(as_disposition(interpretation, request), request)


def as_disposition(interpretation: dict, request: EchoGenerationRequest, *,
                   enhancement: bool = True) -> dict:
    """The strongest claim this interpretation can make on what is already
    owned, or the interpretation unchanged.

    Tried most-specific first. A sequel is the strongest claim (the
    campaign owns this exact verb already); an enhancement is next (it
    owns something the element can attach to); a confluence is last,
    because it fires on a budget condition rather than on a reading. Each
    returns None when it cannot land, so the ordinary CREATE survives and
    none of them can make a provider invalid.

    Public because mock is the other caller. A provider that skips this
    accumulates: mock's own catalog shapes are fresh CREATEs, and without
    the chain a ten-Zone campaign ended with seventeen unrelated Actions
    against a soft budget of twelve, and eight upgrades where the fallback
    produced thirty-one. Evolving is not decoration — it is what keeps a
    26-Check campaign from being 26 unrelated things.

    `enhancement=False` for a caller that has already made a specific
    reading of this item. Mock's catalog is that caller: "Ice Beam" reads
    as both `cold` and `beam`, and letting the generic enhancement (cold,
    so chill an owned weapon) outrank the specific shape (a beam and the
    charge it burns) swallowed every elemental item and put
    `beam_sustained` back out of reach. Sequel still applies, because
    owning the same verb is a fact about identity rather than a rival
    reading; confluence still applies, because it is about capacity.
    """
    return (_as_sequel(interpretation, request)
            or (_as_enhancement(interpretation, request)
                if enhancement else None)
            or _as_confluence(interpretation, request)
            or interpretation)


def _read_and_label(interpretation: dict, request: EchoGenerationRequest) -> dict:
    """The §15 reading, stamped on last.

    Concepts and mode are stamped after the operations are settled rather
    than chosen up front, because both are *about* the finished
    interpretation: the mode is derived from what the operations actually
    did (`mode_for_operations`), so it cannot end up describing an earlier
    draft. The fallback used to ship an empty concept tuple and a hardcoded
    "literal", which made §15's chain unexercised by every deterministic
    run — including the integration run.
    """
    interpretation["concepts"] = read_concepts(
        request.source.item_name, request.source.source_game)
    interpretation["mode"] = mode_for_operations(
        interpretation.get("operations", []))
    return interpretation


def _fallback_echo_create(request: EchoGenerationRequest, *,
                          mechanics=None) -> dict:
    """Deterministic heuristics on the lowercased item name (§12.2).

    `mechanics` is the campaign's current fold, for the hard budgets; None
    means "assume room", which every pre-S4 caller meant. Determinism is
    per (item, campaign state), which is the same determinism the archive
    replays: the same log prefix always yields the same interpretation.
    """
    name = request.source.item_name.lower()

    def has(*words: str) -> bool:
        return any(w in name for w in words)

    def room(**counts: int) -> bool:
        return _budget_room(mechanics, request=request, **counts)

    if has("conference call", "shotgun"):
        return _primary(
            request, archetype="weapon", cooldown=1.2,
            initiator={"type": "hitscan_damage", "damage": 12.0, "pellets": 12,
                       "spread_degrees": 12.0, "range": 25.0},
            modifiers=[{"type": "recoil_self", "force": 10.0},
                       {"type": "knockback_target", "force": 8.0}],
            description="A ridiculous scattergun. The recoil is a travel plan.",
            tags=["shotgun", "recoil", "mobility"])
    if has("gun", "rifle", "pistol", "cannon", "blaster", "bow"):
        return _primary(
            request, archetype="weapon", cooldown=0.6,
            initiator={"type": "hitscan_damage", "damage": 10.0, "pellets": 1,
                       "spread_degrees": 2.0, "range": 40.0},
            description="A straightforward sidearm, reinterpreted from static.",
            tags=["weapon"])
    if has("sword", "blade", "knife", "dagger", "axe"):
        # Was a 6-metre hitscan, because in S1 there was nothing else a
        # sword could be. It is a sword now.
        return _primary(
            request, archetype="weapon", cooldown=0.7,
            initiator={"type": "melee_swing", "damage": 24.0, "reach": 2.6,
                       "arc_degrees": 110.0},
            description="Short reach, serious opinion.",
            tags=["melee", "weapon"])
    if has("spear", "lance", "pike", "halberd", "trident"):
        return _primary(
            request, archetype="weapon", cooldown=0.9,
            initiator={"type": "melee_thrust", "damage": 34.0, "reach": 4.2},
            modifiers=[{"type": "apply_status_on_hit",
                        "status": "vulnerable", "duration": 4.0,
                        "magnitude": 0.6}],
            description="Reach beats width, and a pierced guard stays "
                        "pierced.",
            tags=["melee", "weapon", "status"])
    if has("hammer", "mallet", "stomp", "smash", "quake"):
        return _primary(
            request, archetype="weapon", cooldown=3.5,
            initiator={"type": "slam_ground", "damage": 32.0, "radius": 5.0,
                       "descent_force": 20.0},
            description="Only works from up there. Bring yourself down hard.",
            tags=["melee", "slam"])
    if has("magic", "mana", "ether", "spell", "meter", "essence") \
            and room(resources=1):
        return _primary_and_resource(
            request, archetype="weapon", cooldown=0.5,
            initiator={"type": "charge_shot", "min_damage": 5.0,
                       "max_damage": 34.0, "charge_time": 1.0, "speed": 28.0},
            resource={
                "display_name": "MP",
                "description": "A meter, reinterpreted as a meter.",
                "max_value": 100.0, "initial_fraction": 0.35,
                "regen_per_second": 4.0, "regen_delay": 1.0,
                "presentation": "bar", "palette_color": "tide",
            },
            description="A meter and something that spends it.",
            tags=["magic", "resource", "linked"], powers=12.0)
    if has("stamina", "vigor", "endurance", "breath") \
            and room(resources=1):
        return _primary_and_resource(
            request, archetype="mobility", cooldown=1.2,
            initiator={"type": "dash", "force": 13.0},
            resource={
                "display_name": "STAMINA",
                "description": "Spent on moving, in a world that allows it.",
                "max_value": 60.0, "initial_fraction": 0.5,
                "regen_per_second": 8.0, "regen_delay": 0.6,
                "presentation": "pips", "pip_count": 6,
                "palette_color": "moss",
            },
            description="Borrowed wind, spent a lungful per dash.",
            tags=["stamina", "resource", "linked"], powers=15.0)
    if has("staff", "wand", "charge", "rod", "focus"):
        return _primary(
            request, archetype="weapon", cooldown=0.5,
            initiator={"type": "charge_shot", "min_damage": 6.0,
                       "max_damage": 38.0, "charge_time": 1.1, "speed": 30.0},
            description="Hold it. It gets angrier. Let go.",
            tags=["charge", "weapon"])
    if has("smg", "burst", "repeater", "machine", "uzi"):
        return _primary(
            request, archetype="weapon", cooldown=0.9,
            initiator={"type": "burst_fire", "damage": 7.0, "shots": 4,
                       "interval": 0.08, "spread_degrees": 4.0,
                       "range": 35.0},
            description="Four opinions in rapid succession.",
            tags=["burst", "weapon"])
    if has("teleport", "warp", "blink", "recall", "portal"):
        return _primary(
            request, archetype="mobility", cooldown=2.5,
            initiator={"type": "blink", "range": 14.0, "clearance": 0.4},
            description="You are looking at somewhere. Now you are there.",
            tags=["blink", "mobility"])
    if has("glider", "glide", "parachute", "sail", "umbrella"):
        return _primary(
            request, archetype="mobility", cooldown=0.6,
            initiator={"type": "glide", "fall_speed": 2.0,
                       "forward_speed": 10.0},
            description="Hold it and the fall becomes a decision.",
            tags=["glide", "mobility"])
    if has("jet", "thruster", "rocket boot", "booster", "jump"):
        return _primary(
            request, archetype="mobility", cooldown=1.2,
            initiator={"type": "double_jump", "force": 8.0, "extra_jumps": 1},
            description="One more jump than the world budgeted for.",
            tags=["jump", "mobility"])
    # "clawshot" is a grapple that happens to contain "claw", and the
    # generic bucket would otherwise swallow it before the specific one
    # below ever ran. Specificity beats generality in a name mapper.
    if has("claw", "gecko", "climb", "wall", "gauntlet") \
            and not has("clawshot"):
        return _primary(
            request, archetype="mobility", cooldown=0.8,
            initiator={"type": "wall_kick", "force": 12.0,
                       "outward_fraction": 0.45},
            description="Walls are just floors you have not argued with.",
            tags=["wall", "mobility"])
    if has("parry", "riposte", "counter", "deflect"):
        return _primary(
            request, archetype="tool", cooldown=2.0,
            initiator={"type": "parry", "window": 0.35},
            description="A short window and a lot of confidence.",
            tags=["parry", "defense"])
    if has("compass", "map", "marker", "flag", "beacon"):
        return _primary(
            request, archetype="tool", cooldown=1.0,
            initiator={"type": "place_marker", "duration": 120.0},
            description="Somewhere worth remembering. Now it is marked.",
            tags=["marker", "utility"])
    # "longshot"/"clawshot" are named here for the same reason "hookshot"
    # is: this maps names to verbs, and those names mean grapple. It is
    # also what makes ECHOES §11's own example — Hookshot → Longshot →
    # Clawshot as one grapple — reachable from the shipped fallback.
    if has("hook", "grapple", "chain", "longshot", "clawshot"):
        return _primary(
            request, archetype="mobility", cooldown=2.0,
            initiator={"type": "grapple_to_surface", "range": 25.0,
                       "pull_force": 15.0},
            description="Latch onto geometry and get yanked there.",
            tags=["grapple", "mobility"])
    if has("boot", "shoe", "skate", "rep", "sprint"):
        return _primary(
            request, archetype="mobility", cooldown=2.0,
            initiator={"type": "dash", "force": 12.0},
            description="A burst of borrowed momentum.",
            tags=["dash", "mobility"])
    if has("wing", "feather", "cape", "cap"):
        return _passive(
            request,
            effects=[{"type": "modify_gravity", "multiplier": 0.6}],
            description="Gravity applies to you less than it used to.",
            tags=["float", "passive"])
    if has("shield", "armor", "armour", "guard"):
        return _primary(
            request, archetype="tool", cooldown=12.0,
            initiator={"type": "shield", "amount": 40.0, "duration": 8.0},
            description="A temporary layer of somebody else's protection.",
            tags=["shield", "defense"])
    if has("estus", "potion", "flask", "food", "heart", "heal", "shard") \
            and room(resources=1, rules=1):
        # S4: the drink kept its button, and gained an economy — three
        # charges a Zone, one of which spends ITSELF when you are about to
        # die. The first fallback outcome where a rule, a cost and a
        # resource meet.
        src = request.source
        return _create_ops(
            request,
            "Drink the interpretation of a drink. One drinks itself.",
            ["heal", "resource", "rule"],
            [
                {
                    "kind": "resource",
                    "component_id": MG.component_id_for("res",
                                                        src.location_id),
                    "display_name": "FLASK",
                    "description": "Charges of somebody's recovery item.",
                    "max_value": 3.0, "initial_fraction": 1.0,
                    "presentation": "pips", "pip_count": 3,
                    "palette_color": "ember",
                },
                {
                    "kind": "rule",
                    "component_id": MG.component_id_for("rule",
                                                        src.location_id),
                    "display_name": "Reflex Sip",
                    "description": "Falling low uncorks one on its own.",
                    "event": "low_health",
                    "conditions": [],
                    "costs": [{"resource_id": MG.component_id_for(
                        "res", src.location_id), "amount": 1.0}],
                    "effects": [{"type": "heal", "amount": 25.0}],
                    "cooldown": 5.0,
                },
                {
                    "kind": "action",
                    "component_id": MG.component_id_for("act",
                                                        src.location_id),
                    "display_name": _clamp(src.item_name, C.MAX_TEXT_LEN),
                    "description": "Drink the interpretation of a drink.",
                    "slot": MG.ARCHETYPE_SLOT.get("tool", "echo_a"),
                    "cooldown": 10.0,
                    "primitive": {"type": "heal_self", "amount": 30.0},
                    "modifiers": [],
                },
                # S5: the button spends a charge too, so the meter is the
                # same economy whether you drink deliberately or the rule
                # drinks for you. Without this the charges only ever left
                # by the reflex, which read as two unrelated things.
                {
                    "op": "link", "link": "powers",
                    "source": MG.component_id_for("res", src.location_id),
                    "target": MG.component_id_for("act", src.location_id),
                    "strength": 1.0,
                },
            ])
    if has("star", "orb", "battery", "cell", "core", "dynamo") \
            and room(resources=1, rules=2):
        # A pure economy, no button at all: kills feed the cell, and a full
        # cell discharges itself into a shield. Exercises the edge-derived
        # events end to end in the shipped campaign.
        src = request.source
        cell = MG.component_id_for("res", src.location_id)
        return _create_ops(
            request,
            "It wants to be full. It has opinions about what happens then.",
            ["energy", "resource", "rule"],
            [
                {
                    "kind": "resource",
                    "component_id": cell,
                    "display_name": _clamp(src.item_name.upper(),
                                           C.MAX_TEXT_LEN),
                    "description": "Charged by violence, spent on your "
                                   "behalf.",
                    "max_value": 100.0, "initial_fraction": 0.0,
                    "presentation": "bar", "palette_color": "signal",
                },
                {
                    "kind": "rule",
                    "component_id": MG.component_id_for("rule",
                                                        src.location_id,
                                                        "feed"),
                    "display_name": "Kinetic Intake",
                    "description": "Every kill feeds the cell.",
                    "event": "kill",
                    "conditions": [],
                    "costs": [],
                    "effects": [{"type": "resource_add", "subject": cell,
                                 "amount": 15.0}],
                    "cooldown": 0.3,
                },
                {
                    "kind": "rule",
                    "component_id": MG.component_id_for("rule",
                                                        src.location_id,
                                                        "burst"),
                    "display_name": "Overflow Ward",
                    "description": "A full cell discharges into a shield.",
                    "event": "resource_full",
                    "conditions": [{"type": "resource_at_least",
                                    "subject": cell, "value": 0.999}],
                    "costs": [],
                    "effects": [
                        {"type": "grant_shield", "amount": 20.0,
                         "duration": 4.0},
                        {"type": "resource_add", "subject": cell,
                         "amount": -100.0},
                    ],
                    "cooldown": 2.0,
                },
            ])
    if has("bomb", "grenade", "mine", "explosive"):
        return _primary(
            request, archetype="weapon", cooldown=3.0,
            initiator={"type": "arc_lob", "damage": 34.0, "radius": 4.0,
                       "launch_force": 17.0, "fuse": 1.4},
            description="Lob it, count, regret nothing.",
            tags=["explosive", "weapon"])
    if has("rocket", "missile", "cannonball", "mortar"):
        return _primary(
            request, archetype="weapon", cooldown=3.0,
            initiator={"type": "projectile_damage", "damage": 22.0,
                       "speed": 26.0, "lifetime": 3.0,
                       "gravity_scale": 0.15, "bounces": 0},
            description="A slow, regrettable projectile.",
            tags=["projectile", "weapon"])

    # Most items reach here — nothing in a multiworld is named for what
    # Epsilon does with it — so this branch, not the table above, is what
    # variety means in play. S1 hashed to three outcomes: a gun, a dash, or
    # walking slightly faster. A whole campaign of that is one verb repeated
    # 26 times.
    #
    # Still deterministic (the same Check always yields the same Echo) and
    # still structurally boring: one CREATE, one component, no links. Only
    # the vocabulary widened.
    choice = C.prng_seed(request.source.source_game, request.source.item_name,
                         request.source.location_id) % 8
    if choice == 0:
        return _primary(
            request, archetype="weapon", cooldown=0.8,
            initiator={"type": "hitscan_damage", "damage": 12.0, "pellets": 3,
                       "spread_degrees": 6.0, "range": 30.0},
            description="Epsilon squints at the name and hands you a gun.",
            tags=["weapon"])
    if choice == 1:
        return _primary(
            request, archetype="mobility", cooldown=2.5,
            initiator={"type": "dash", "force": 10.0},
            description="Whatever it was, now it makes you faster briefly.",
            tags=["dash", "mobility"])
    if choice == 2:
        return _primary(
            request, archetype="weapon", cooldown=0.9,
            initiator={"type": "burst_fire", "damage": 6.0, "shots": 3,
                       "interval": 0.09, "spread_degrees": 5.0,
                       "range": 32.0},
            description="It stutters when it speaks. Three times, quickly.",
            tags=["burst", "weapon"])
    if choice == 3:
        return _primary(
            request, archetype="mobility", cooldown=3.0,
            initiator={"type": "blink", "range": 11.0, "clearance": 0.4},
            description="Epsilon could not place it, so it moved you instead.",
            tags=["blink", "mobility"])
    if choice == 4:
        return _primary(
            request, archetype="weapon", cooldown=1.0,
            initiator={"type": "melee_swing", "damage": 18.0, "reach": 2.4,
                       "arc_degrees": 120.0},
            description="Held wrong, swung anyway.",
            tags=["melee", "weapon"])
    if choice == 5:
        return _primary(
            request, archetype="mobility", cooldown=1.4,
            initiator={"type": "air_dash", "force": 14.0,
                       "uses_per_airtime": 1},
            description="It only means anything once you have left the floor.",
            tags=["dash", "mobility"])
    if choice == 6:
        return _primary(
            request, archetype="weapon", cooldown=2.6,
            initiator={"type": "arc_lob", "damage": 26.0, "radius": 3.5,
                       "launch_force": 15.0, "fuse": 1.2},
            description="Epsilon decided the safest reading was 'throw it'.",
            tags=["explosive", "weapon"])
    return _passive(
        request,
        effects=[{"type": "modify_speed", "multiplier": 1.2}],
        description="Worn quietly. You walk with more purpose.",
        tags=["speed", "passive"])


class FallbackEpsilonProvider:
    """Deterministic provider — the `--epsilon=fallback` axis value."""

    name = "fallback"

    async def generate_zone(self, request: ZoneGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict:
        return fallback_zone(request)

    async def generate_echo(self, request: EchoGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict:
        return fallback_echo(request)

    # No `mechanics` here, and none is needed: `_budget_room` reads the
    # request's own `budget_headroom` when no fold is passed, so this
    # provider obeys §16 from what it was given like any other.
