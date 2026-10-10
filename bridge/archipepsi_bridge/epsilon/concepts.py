"""The reading half of interpretation (ECHOES §15).

```
item -> concepts -> supported systems -> validated recipe
```

Epsilon thinks in concepts before it reaches for a mechanic, and the
concepts are **stored** rather than merely used: the inventory says
"Epsilon read this as: water / buoyancy / pressure", which is most of the
charm and all of the accountability. An Echo whose concepts do not explain
its mechanics is one the player has no way to argue with.

This module is the *deterministic* reading. It exists for two reasons:

1. `--epsilon=mock` and the fallback need concepts of their own, or the
   integration run proves the pipeline works on empty tuples.
2. It is what the request offers a model provider as `suggested_concepts`
   — a starting point to disagree with, so the model is steered by an
   example rather than by an abstract instruction.

It does **not** validate a model's reading. `shares_vocabulary_with` once
did, and was wrong in both directions at once; see its docstring, which is
worth reading before anyone tries again.

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
    # An ember is fire that has not gone out, and *Ember* is a real item
    # in a real game. Missing it made every Dark Souls run's most obviously
    # elemental item read as an inert "artifact".
    "ember": ("fire", "energy", "persistence"),
    "ash": ("fire", "residue", "ending"),
    "ice": ("cold", "stillness", "brittleness"),
    "frost": ("cold", "slowness"),
    "venom": ("decay", "patience"),
    "poison": ("decay", "patience", "spread"),
    "spark": ("electricity", "smallness", "beginning"),
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

    Order is meaningful: nouns lead in the item's own word order, then
    qualifiers. The source game contributes only when the item name yields
    nothing at all — "it came from Stardew Valley" is context rather than a
    reading, and adding it to a reading that already worked just made every
    concept list end in a franchise name.
    """
    out: list[str] = []

    def add(concept: str) -> None:
        cleaned = concept.strip().lower()[:MAX_CONCEPT_LEN]
        if cleaned and cleaned not in out and len(out) < MAX_CONCEPTS:
            out.append(cleaned)

    tokens = _tokens(item_name)
    # Nouns first, in the ITEM'S OWN word order: "Fire Sword" leads with
    # fire, "Sword of Fire" leads with blade. Word order is the only signal
    # available about which half of a name matters, and following it beats
    # imposing an order of our own — but the two do NOT read alike, which
    # an earlier version of this comment claimed.
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


def shares_vocabulary_with(concepts, item_name: str,
                          source_game: str = "") -> bool:
    """Does this reading reuse any word the item or its lexicon entry uses?

    A **diagnostic, not a gate.** It was briefly used to validate provider
    output and it was wrong in both directions at once, which is worth
    recording because the shape of the mistake is instructive.

    Too loose: it asked whether a concept was a substring of any
    vocabulary word, and seeded the vocabulary with `artifact`,
    `elsewhere` and `borrowed` unconditionally — so `art`, `row` and
    `here` passed for every item in every game, and a reading pasted
    wholesale from another Echo passed as soon as one of its words
    happened to contain `art`.

    Too strict: §15's whole argument is that the best reading is *not* the
    one most similar to the source item. "Master Sword reads as
    obligation" is a defensible reading that shares no word with the item,
    the lexicon or the game, and refusing it burns the one repair round
    and can drop a good Echo to the fallback.

    Attachment is not decidable from an item name, so nothing validates it
    now: the prompt carries §15's rule, the archive shows the reading, and
    a dull reading is visible to the player rather than corrupting
    anything. What IS still refused is an empty reading — see
    `base.reading_errors` — because that breaks the chain outright.

    Kept because the lexicon's own tests want to ask this question, and
    fixed to match whole words rather than substrings.
    """
    if not concepts:
        return False
    vocabulary: set[str] = set()
    for token in _tokens(item_name) + _tokens(source_game):
        vocabulary.add(token)
        for concept in LEXICON.get(token, ()):
            vocabulary.update(_tokens(concept))
        qualifier = QUALIFIERS.get(token)
        if qualifier:
            vocabulary.add(qualifier)
    for concept in concepts:
        for word in _tokens(concept):
            if word in vocabulary:
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
    made_here = {str(op.get("component", {}).get("component_id", ""))
                 for op in operations if op.get("op") == "create"}

    # Touching what ALREADY EXISTS is the systemic reading, by definition —
    # `MODE_MEANINGS` says "rather than adding to it". A link whose two
    # endpoints this same interpretation created adds a self-contained
    # thing, so it is not systemic however many operations it took.
    #
    # That distinction is not pedantic: every resource-bearing fallback
    # outcome is `create action + create resource + link`, so without it
    # the archive told the player "Wired Magic Meter" about an Echo that
    # touched nothing they already had.
    for op in operations:
        if str(op.get("op", "")) not in ("link", "merge", "modify"):
            continue
        references = [str(op.get(key, ""))
                      for key in ("source", "target", "absorbed", "survivor")
                      if op.get(key)]
        # No references at all means a malformed operation, which will not
        # validate anyway; call it systemic rather than quietly reporting
        # the mildest reading of something that cannot be read.
        if not references or any(r not in made_here for r in references):
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
