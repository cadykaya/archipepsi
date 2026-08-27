"""The reading half of interpretation (ECHOES §15).

```
item -> concepts -> supported systems -> validated recipe
```

Epsilon thinks in concepts before it reaches for a mechanic, and the
concepts are **stored** rather than merely used: the inventory says
"Epsilon read this as: water / buoyancy / pressure", which is most of the
charm and all of the accountability. An Echo whose concepts do not explain
its mechanics is one the player has no way to argue with.

This module is the *deterministic* reading. It exists for three reasons:

1. `--epsilon=mock` and the fallback need concepts of their own, or the
   integration run proves the pipeline works on empty tuples.
2. A model-authored reading has to be checkable. `plausible_concepts`
   answers "could a reasonable reader have got that from this item", which
   is the only honest question — there is no correct answer to check
   against.
3. The lexicon doubles as the vocabulary the Claude prompt is shown, so
   the model is steered by examples rather than by an abstract
   instruction.

**It reads AP strings; it never touches AP identity.** A concept is
derived from an item's *name*, is stored on the interpretation, and means
nothing to Archipelago. Nothing here can rename, reroute or invent an
item.
"""

from __future__ import annotations

import re

#: Longest a single concept may be, from the schema's own field bound.
MAX_CONCEPT_LEN = 24
MAX_CONCEPTS = 6

#: Keyword -> the concepts a reader plausibly takes from it.
#:
#: Ordered dict semantics matter: the first matches win the leading slots,
#: so an item matching several keywords reads as the most specific one
#: first. Keys are matched against whole lowercase tokens of the item name,
#: never substrings — "sword" must not fire on "swordfish sandwich", and
#: more importantly "art" must not fire on "cart", "start" or "particle".
LEXICON: dict[str, tuple[str, ...]] = {
    # -- water and pressure
    "water": ("water", "buoyancy", "pressure"),
    "tunic": ("protection",),
    "aqua": ("water", "buoyancy"),
    "diving": ("water", "pressure", "descent"),
    "flippers": ("water", "propulsion"),
    "bubble": ("air", "buoyancy", "fragility"),
    # -- movement and momentum
    "blj": ("backwards", "momentum", "acceleration", "exploit"),
    "boots": ("footing", "traversal"),
    "hookshot": ("reach", "tension", "traversal"),
    "grapple": ("reach", "tension"),
    "wing": ("flight", "descent", "lightness"),
    "cape": ("glide", "descent", "flourish"),
    "dash": ("speed", "burst"),
    "rocket": ("thrust", "explosion", "speed"),
    "jump": ("elevation", "traversal"),
    "speed": ("speed", "momentum"),
    "warp": ("displacement", "elsewhere"),
    "teleport": ("displacement", "elsewhere"),
    # -- blades and heroism
    "sword": ("blade", "heroism"),
    "master": ("heroism", "anti-evil", "energy"),
    "blade": ("blade", "precision"),
    "knife": ("blade", "precision", "intimacy"),
    "axe": ("blade", "weight", "cleaving"),
    "hammer": ("weight", "impact", "authority"),
    "spear": ("reach", "puncture"),
    # -- guns
    "gun": ("firearm", "distance"),
    "pistol": ("firearm", "distance", "restraint"),
    "shotgun": ("firearm", "spread", "proximity"),
    "rifle": ("firearm", "distance", "precision"),
    "cannon": ("firearm", "weight", "explosion"),
    "laser": ("beam", "energy", "precision"),
    "beam": ("beam", "energy", "continuity"),
    "bomb": ("explosion", "delay", "area"),
    "missile": ("explosion", "pursuit", "distance"),
    # -- magic and energy
    "magic": ("arcane", "energy"),
    "spell": ("arcane", "invocation"),
    "wand": ("arcane", "focus", "precision"),
    "staff": ("arcane", "focus", "authority"),
    "rune": ("arcane", "inscription", "meaning"),
    "crystal": ("energy", "clarity", "storage"),
    "orb": ("energy", "containment", "roundness"),
    "flame": ("fire", "energy", "spread"),
    "fire": ("fire", "energy"),
    "ice": ("cold", "stillness", "brittleness"),
    "frost": ("cold", "slowness"),
    "storm": ("weather", "violence", "chain"),
    "lightning": ("electricity", "speed", "chain"),
    "shadow": ("concealment", "cold", "absence"),
    "light": ("illumination", "revelation"),
    # -- defence and health
    "shield": ("protection", "interposition"),
    "armor": ("protection", "weight"),
    "armour": ("protection", "weight"),
    "heart": ("vitality", "sentiment"),
    "potion": ("restoration", "consumption"),
    "elixir": ("restoration", "rarity"),
    "medkit": ("restoration", "triage"),
    "bandage": ("restoration", "patience"),
    # -- keys, progress and containers
    "key": ("access", "obligation"),
    "map": ("knowledge", "orientation"),
    "compass": ("orientation", "certainty"),
    "lantern": ("illumination", "warmth", "company"),
    "torch": ("illumination", "fire"),
    "bag": ("capacity", "accumulation"),
    "wallet": ("capacity", "wealth"),
    "coin": ("wealth", "exchange"),
    "gem": ("wealth", "clarity"),
    "ticket": ("permission", "queueing"),
    # -- the mundane, which is funnier
    "seed": ("growth", "patience", "smallness"),
    "hoe": ("labour", "soil", "patience"),
    "fish": ("water", "patience", "slipperiness"),
    "cheese": ("sustenance", "fermentation", "indignity"),
    "hat": ("identity", "flourish"),
    "boot": ("footing", "traversal"),
    "sandwich": ("sustenance", "assembly"),
    "brick": ("weight", "bluntness", "construction"),
    "rope": ("tension", "length", "connection"),
    "ladder": ("elevation", "patience"),
    "battery": ("energy", "storage", "depletion"),
    "wrench": ("repair", "leverage"),
    "radio": ("signal", "distance", "voice"),
}

#: Read from the item's grammar rather than its nouns. A "greater" anything
#: is a statement about scale; a "cursed" anything is a statement about
#: cost. Applied after the noun lexicon so they qualify rather than lead.
QUALIFIERS: dict[str, str] = {
    "greater": "escalation",
    "lesser": "diminishment",
    "ancient": "antiquity",
    "broken": "damage",
    "cursed": "cost",
    "blessed": "favour",
    "golden": "wealth",
    "silver": "purity",
    "infinite": "excess",
    "mini": "smallness",
    "mega": "excess",
    "super": "excess",
    "progressive": "escalation",
    "upgrade": "escalation",
    "double": "duplication",
    "triple": "duplication",
    "false": "deception",
    "true": "authenticity",
    "spare": "redundancy",
    "emergency": "urgency",
}

#: Last resort, so an unrecognised item is still read as *something*. An
#: empty concept list would be a silent hole in §15's chain: the player
#: would see an Echo with no explanation of where it came from.
_GENERIC = ("artifact", "elsewhere", "borrowed")

_TOKEN = re.compile(r"[a-z0-9]+")


def _tokens(text: str) -> list[str]:
    return _TOKEN.findall(text.lower())


def read_concepts(item_name: str, source_game: str = "") -> tuple[str, ...]:
    """The concepts a reasonable reader takes from this item.

    Deterministic, so two runs of the same campaign read the same item the
    same way — the mock and fallback providers are the reproducible half of
    the project, and a wandering reading would make the archive lie about
    what happened last time.

    Order is meaningful: the most specific noun leads, qualifiers follow,
    and the source game contributes at most one trailing concept, because
    "it came from Stardew Valley" is context rather than a reading.
    """
    out: list[str] = []

    def add(concept: str) -> None:
        cleaned = concept.strip().lower()[:MAX_CONCEPT_LEN]
        if cleaned and cleaned not in out and len(out) < MAX_CONCEPTS:
            out.append(cleaned)

    tokens = _tokens(item_name)
    # Nouns first, in the item's own word order, so "Fire Sword" reads as
    # fire before blade and "Sword of Fire" the same way.
    for token in tokens:
        for concept in LEXICON.get(token, ()):
            add(concept)
    for token in tokens:
        qualifier = QUALIFIERS.get(token)
        if qualifier:
            add(qualifier)

    if not out:
        # Nothing recognised. Use the item's own distinctive words — a
        # reading in the item's own vocabulary beats a generic one, and it
        # is honest about having recognised nothing.
        for token in tokens:
            if len(token) >= 4 and token not in _STOPWORDS:
                add(token)
    if not out:
        # Still nothing — a name that is all stopwords and short words. The
        # game is the only other thing known about the item.
        for token in _tokens(source_game):
            if len(token) >= 4 and token not in _STOPWORDS \
                    and token not in QUALIFIERS:
                add(token)
                break
    for concept in _GENERIC:
        if len(out) >= 2:
            break
        add(concept)
    return tuple(out)


_STOPWORDS = frozenset({
    "the", "and", "of", "a", "an", "for", "with", "your", "this", "that",
    "from", "into", "onto", "item", "thing", "some", "very",
})


def plausible_concepts(concepts, item_name: str, source_game: str = "") -> bool:
    """Could a reasonable reader have got these concepts from this item?

    Deliberately weak, and the weakness is the point. There is no correct
    reading to check a model against — "Master Sword reads as heroism" and
    "Master Sword reads as obligation" are both defensible, and a validator
    that insisted on the lexicon's answer would make every provider a
    worse version of `read_concepts`.

    So this only refuses a reading that is *unattached*: one sharing no
    word with the item, the game, or anything the lexicon associates with
    them. That catches concepts pasted from another Echo, which is the
    failure mode worth catching.
    """
    if not concepts:
        return False
    vocabulary: set[str] = set()
    for token in _tokens(item_name) + _tokens(source_game):
        vocabulary.add(token)
        vocabulary.update(LEXICON.get(token, ()))
        qualifier = QUALIFIERS.get(token)
        if qualifier:
            vocabulary.add(qualifier)
    vocabulary.update(_GENERIC)
    if not vocabulary:
        return True
    for concept in concepts:
        for word in _tokens(concept):
            if word in vocabulary or any(word in v for v in vocabulary):
                return True
    return False


# ---------------------------------------------------------------------------
# Modes (§15)
# ---------------------------------------------------------------------------

#: What each mode claims about the distance between item and mechanic.
#: Shown to the model, so the four words mean the same thing to a provider
#: as they do to the archive that displays them.
MODE_MEANINGS: dict[str, str] = {
    "literal": (
        "the mechanic is more or less the item: a sword swings, a potion "
        "heals"),
    "mechanical": (
        "the item's function survives but the mechanism changes: a lantern "
        "becomes a resource that burns down rather than a light"),
    "conceptual": (
        "one concept from the item drives an unrelated mechanic: 'pressure' "
        "from a diving suit becomes a charge that builds while grounded"),
    "systemic": (
        "the item changes how the build relates to itself: it links, merges "
        "or conditions what you already own rather than adding to it"),
}

#: Which readings each creativity setting leans toward, most-preferred
#: first. §15 says modes are "influenced by" the creativity setting, and
#: this is that influence: it goes in the REQUEST as steering, exactly like
#: `over_soft_budget`.
#:
#: Deliberately NOT a validator rule. A hard ceiling would have to reject
#: an otherwise-perfect Echo for being read too imaginatively — and worse,
#: the cheap way to keep such an Echo would be to relabel its mode, which
#: would make the archive misdescribe the thing the player is holding. The
#: mode has to stay a true statement about the operations.
MODE_PREFERENCE: dict[int, tuple[str, ...]] = {
    0: ("literal", "mechanical"),
    1: ("literal", "mechanical", "conceptual"),
    2: ("conceptual", "systemic", "mechanical", "literal"),
}


def mode_for_operations(operations) -> str:
    """The mode an interpretation's own operations put it in.

    A fact about the operations, not a preference: the archive shows this
    to the player as "how Epsilon read it", so a mode disagreeing with what
    the Echo actually does would be the archive lying. The deterministic
    providers derive it here; a model provider declares its own, because it
    knows what it was reaching for.

    `operations` is a sequence of raw operation dicts, so this works on
    provider output that has not been parsed into models yet.
    """
    kinds = {str(op.get("op", "")) for op in operations}
    created = {str(op.get("component", {}).get("kind", ""))
               for op in operations if op.get("op") == "create"}

    # Touching what already exists IS the systemic reading, by definition.
    if kinds & {"link", "merge", "modify"}:
        return "systemic"
    if "rule" in created:
        # A rule conditions the build rather than adding to it, even when
        # it arrives by CREATE.
        return "systemic"
    if kinds == {"upgrade"}:
        return "mechanical"
    if created & {"trait", "resource", "status", "info", "affordance"}:
        return "conceptual"
    return "literal"


def preferred_modes(creativity: int) -> tuple[str, ...]:
    """The readings this creativity setting leans toward, most first.

    Steering for the request, never enforcement — see `MODE_PREFERENCE`.
    """
    return MODE_PREFERENCE.get(creativity, MODE_PREFERENCE[1])
