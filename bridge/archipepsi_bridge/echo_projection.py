"""A bounded, deterministic PROVIDER VIEW of the complete Echo history.

The immutable interpretation log is complete local campaign truth and
stays that way. Nothing here truncates it, discards an interpretation,
changes the fold, or creates a second mechanics truth. **No campaign
behaviour depends on what happens to fit inside a prompt.**

What this fixes is the other direction: at the prototype's thirty
locations a campaign accumulated ~29 Echoes, and every Zone request
carried all of them -- about 6 KB. At the 450-location default it can
accumulate ~449, and the same code sent 96 KB of Echo summaries, roughly
24,000 tokens, before the prompt began. That is the CS8b failure again:
the options scaled and a consumer did not.

The obvious fix -- "send the most relevant N" -- is the wrong one, and
deliberately not what this does. **Accumulated world influence is
intentional.** A late Zone must not forget an early capability because
that Echo fell outside a detail window. So the projection is three
things, and only the third is a window:

1. **Complete derived state.** Capabilities and affordance tags come
   from the fold over the WHOLE log. Nothing is forgotten, because
   nothing is sampled.
2. **Accumulated influence.** A deterministic aggregate over the whole
   history -- which source worlds shaped this campaign, which concepts
   and kinds recur, how much of it there is. Bounded by construction:
   the vocabularies are closed or top-N'd, so 30, 450 and 600 all
   produce the same shape.
3. **Bounded examples.** A handful of real Echoes for flavour and
   specificity. Explicitly NOT campaign truth, and chosen to span the
   history rather than to be the last few.

Nothing here is a new semantic system. Every field is read off
`Mechanics` or off the interpretations themselves.
"""

from __future__ import annotations

from .schemas.mechanics import Mechanics, owned_affordance_tags

#: How many detailed Echoes cross to the provider, at any campaign size.
#: Small on purpose: they are flavour, and the capabilities above them
#: are what Epsilon must compose against.
MAX_DETAIL_EXAMPLES = 12

#: How many of those are the most recent. The rest span the history, so
#: an early Echo can still appear in a late Zone -- which is the whole
#: reason this is not a recency window.
RECENT_EXAMPLES = 6

#: Bounds on the influence aggregate. Source worlds and concepts are open
#: vocabularies, so they are top-N'd by count with ties broken by name;
#: a campaign with 200 distinct source games still produces a fixed-size
#: summary.
MAX_INFLUENCE_SOURCES = 10
MAX_INFLUENCE_CONCEPTS = 16
MAX_INFLUENCE_TAGS = 16


def _top(counts: dict[str, int], limit: int) -> tuple[tuple[str, int], ...]:
    """The most frequent entries, deterministically.

    Sorted by count descending then name ascending, so two campaigns with
    the same history always produce the same list -- a summary that
    reorders makes two identical campaigns generate differently.
    """
    ranked = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    return tuple(ranked[:limit])


def accumulated_influence(interpretations) -> dict:
    """What the WHOLE history adds up to, in a fixed-size shape.

    Aggregate rather than sample: every interpretation contributes,
    including the first one, at every campaign size. That is what
    preserves "the world builds on what came before" when the detail
    window cannot.
    """
    sources: dict[str, int] = {}
    concepts: dict[str, int] = {}
    tags: dict[str, int] = {}
    modes: dict[str, int] = {}
    for echo in interpretations:
        sources[echo.source_game] = sources.get(echo.source_game, 0) + 1
        modes[echo.mode] = modes.get(echo.mode, 0) + 1
        for concept in echo.concepts:
            concepts[concept] = concepts.get(concept, 0) + 1
        for tag in echo.tags:
            tags[tag] = tags.get(tag, 0) + 1
    return {
        "total_echoes": len(interpretations),
        # Every distinct source world is COUNTED even when it does not
        # make the top ten, so "this campaign has touched 23 games" is
        # true rather than "ten".
        "distinct_source_games": len(sources),
        "source_games": [{"name": n, "count": c}
                         for n, c in _top(sources, MAX_INFLUENCE_SOURCES)],
        "recurring_concepts": [n for n, _ in
                               _top(concepts, MAX_INFLUENCE_CONCEPTS)],
        "recurring_tags": [n for n, _ in _top(tags, MAX_INFLUENCE_TAGS)],
        "interpretation_modes": dict(sorted(modes.items())),
    }


def detail_examples(interpretations, limit: int = MAX_DETAIL_EXAMPLES,
                    recent: int = RECENT_EXAMPLES) -> tuple:
    """A bounded, deterministic, history-SPANNING sample.

    The most recent few, plus an evenly spaced walk back through
    everything before them. Deterministic without a seed: the same log
    always yields the same examples.

    Spanning rather than recent because a campaign's early Echoes are
    part of what the world became, and a provider shown only the last
    six would compose as though the first four hundred never happened.
    """
    log = list(interpretations)
    if len(log) <= limit:
        return tuple(log)
    tail = log[-recent:] if recent else []
    head = log[:len(log) - len(tail)]
    want = limit - len(tail)
    if want <= 0 or not head:
        return tuple(tail)
    # Evenly spaced across the earlier history, endpoints included, so
    # the very first Echo is always among them.
    step = (len(head) - 1) / max(1, want - 1) if want > 1 else 0
    spread = [head[min(len(head) - 1, round(i * step))] for i in range(want)]
    # De-duplicated while keeping order: a short history can land on the
    # same index twice, and the same Echo twice is a wasted slot.
    seen: set[str] = set()
    out = []
    for echo in spread + list(tail):
        if echo.echo_id not in seen:
            seen.add(echo.echo_id)
            out.append(echo)
    return tuple(out)


def capability_view(mechanics: Mechanics) -> dict:
    """What the complete fold says the player can DO.

    Read off `Mechanics`, which is the fold over the whole log, so this
    is complete by construction rather than by sampling. This is the
    part Epsilon must compose legally against; everything else in the
    projection is context.
    """
    kinds: dict[str, int] = {}
    primitives: set[str] = set()
    for owned in mechanics.owned:
        kinds[owned.kind] = kinds.get(owned.kind, 0) + 1
        primitive = getattr(owned.component, "primitive", None)
        if isinstance(primitive, str):
            primitives.add(primitive)
    return {
        "owned_components": len(mechanics.owned),
        "components_by_kind": dict(sorted(kinds.items())),
        "primitives": sorted(primitives),
        "affordance_tags": list(owned_affordance_tags(mechanics)),
        "links": len(mechanics.links),
    }


def history_view(interpretations, mechanics: Mechanics) -> dict:
    """The whole provider view: complete state, whole-history influence,
    bounded examples.

    ONE projection, used by every path that shows a provider the Echo
    history. Two subtly different summaries is how one of them ends up
    forgotten and unbounded -- which is exactly what
    `EchoGenerationRequest.existing_echoes` was.
    """
    return {
        "capabilities": capability_view(mechanics),
        "influence": accumulated_influence(interpretations),
        # Stated in the payload, so a provider reading twelve examples
        # knows it is looking at twelve of four hundred rather than at
        # all of them.
        "examples_are_a_sample": len(interpretations) > MAX_DETAIL_EXAMPLES,
    }
