"""P19.1 — the accepted Gear grammar, as data.

Amalgam §16, pinning Design 4 §16.1–§16.3. Gear composes across a
**territory**, one or two **domain** atoms and a matching number of
**magnitude** atoms, and the composition is costed against the same
budget every other piece of content is.

**Why the grammar comes first and alone.** Nothing in the runtime
consumes Gear yet. This module therefore declares the vocabulary and the
composition rules and **refuses to mint anything**, exactly as the
Status vocabulary refused kinds before their effects existed: the rule
this project keeps arriving at is that a name without an
implementation must not be offered to Epsilon. `SUPPORTED_GEAR_DOMAINS`
is the gate, it is empty, and `refuse_unsupported_domain` is what
publishes that fact rather than hiding it.

**Nine of the twenty-five atoms have no recovered cost**, and they are
listed rather than guessed. The Amalgam says the atoms it added arrive
"at the magnitudes that proposal gave it" — those numbers live in
Designs 2, 3 and 5 and have not been carried across. A cost invented
here would be a balance decision wearing a schema's clothes.
"""
from __future__ import annotations

from typing import Literal, get_args

Territory = Literal["HEAD", "TORSO", "ARMS", "LEGS"]
MagnitudeAtom = Literal["mag_slight", "mag_marked", "mag_profound"]

#: Design 4 §16.1. What a magnitude atom costs, and which of Design 1
#: §16.1's three scalars it selects on the chosen domain.
MAGNITUDE_COST: dict[str, int] = {
    "mag_slight": 20,      # the domain's SMALL value
    "mag_marked": 44,      # MEDIUM
    "mag_profound": 72,    # LARGE
}

#: §16.1's four territories and the domain atoms legal in each. The
#: territory is NOT costed; it constrains which domains may appear.
#:
#: Twenty-five atoms: Design 4's sixteen, plus eight from the intrinsic
#: templates Designs 2, 3 and 5 replaced, plus `dom_rail_control` from
#: Design 1 §16.1 which Design 4 dropped when it cut its catalog.
DOMAINS_BY_TERRITORY: dict[str, tuple[str, ...]] = {
    "HEAD": ("dom_targeting", "dom_information", "dom_crit",
             "dom_status_potency", "dom_read_stress", "dom_read_machine",
             "dom_read_compounds"),
    "TORSO": ("dom_health", "dom_barrier", "dom_defense", "dom_resource",
              "dom_status_duration"),
    "ARMS": ("dom_melee", "dom_handling", "dom_physics", "dom_interaction",
             "dom_relation_count", "dom_signal_range", "dom_transfer_range"),
    "LEGS": ("dom_speed", "dom_jump", "dom_mobility_recharge", "dom_landing",
             "dom_rail_control", "dom_impact_resistance"),
}

#: Design 4 §16.1's costed sixteen, verbatim.
DOMAIN_COST: dict[str, int] = {
    "dom_targeting": 18, "dom_information": 16, "dom_crit": 26,
    "dom_status_potency": 22,
    "dom_health": 24, "dom_barrier": 26, "dom_defense": 22,
    "dom_resource": 20,
    "dom_melee": 20, "dom_handling": 18, "dom_physics": 20,
    "dom_interaction": 14,
    "dom_speed": 24, "dom_jump": 18, "dom_mobility_recharge": 22,
    "dom_landing": 16,
}

#: The atoms the Amalgam added whose cost has NOT been carried across
#: from the proposal that defined them. Derived, never hand-listed, so
#: recovering one cost removes it from here automatically.
UNCOSTED_DOMAINS: tuple[str, ...] = tuple(
    atom for atoms in DOMAINS_BY_TERRITORY.values() for atom in atoms
    if atom not in DOMAIN_COST)

#: Which domains the runtime actually implements. **Empty, and that is
#: the honest value.** Nothing consumes Gear yet.
SUPPORTED_GEAR_DOMAINS: tuple[str, ...] = ()

ALL_DOMAINS: tuple[str, ...] = tuple(
    atom for atoms in DOMAINS_BY_TERRITORY.values() for atom in atoms)

assert len(ALL_DOMAINS) == len(set(ALL_DOMAINS)), (
    "a domain atom is legal in two territories; §16.1 says the territory "
    "constrains the domain, which only means something if the mapping is "
    "one way")
assert len(ALL_DOMAINS) == 25, f"§16 is twenty-five atoms, found {len(ALL_DOMAINS)}"
assert set(DOMAIN_COST) <= set(ALL_DOMAINS), "a cost for an atom nobody lists"
assert set(DOMAINS_BY_TERRITORY) == set(get_args(Territory))

#: §16.1's tier bands. A USEFUL piece lands in [85, 100] from one domain,
#: one magnitude and one trigger clause within the 22 allowance.
USEFUL_BAND = (85, 100)
CLAUSE_ALLOWANCE = 22


def territory_of(domain: str) -> str:
    """Which territory a domain atom belongs to. Raises on an unknown one."""
    for territory, atoms in DOMAINS_BY_TERRITORY.items():
        if domain in atoms:
            return territory
    raise KeyError(
        f"'{domain}' is not a §16 domain atom; the twenty-five are "
        f"{sorted(ALL_DOMAINS)}")


def composition_cost(domains, magnitudes) -> int:
    """What this composition costs, or a refusal naming what is missing.

    Raises on an uncosted atom rather than scoring it zero -- the same
    rule `content_value.enemy_value` follows, and for the same reason: a
    free atom passes the budget check and makes the piece a fiction.
    """
    total = 0
    for domain in domains:
        territory_of(domain)                     # raises on an unknown atom
        if domain not in DOMAIN_COST:
            raise KeyError(
                f"domain atom '{domain}' has no recovered cost. The Amalgam "
                "says it arrives 'at the magnitudes that proposal gave it' "
                "and those numbers live in Designs 2, 3 and 5; they have "
                f"not been carried across. Uncosted: {sorted(UNCOSTED_DOMAINS)}")
        total += DOMAIN_COST[domain]
    for magnitude in magnitudes:
        if magnitude not in MAGNITUDE_COST:
            raise KeyError(f"'{magnitude}' is not a §16.1 magnitude atom")
        total += MAGNITUDE_COST[magnitude]
    return total


def refuse_unsupported_domain(domain: str) -> None:
    """The gate. Nothing implements Gear, so everything is refused.

    Named rather than absent so the day a domain gains a runtime the
    shape of the answer does not change -- and so a test cannot quietly
    start passing because the vocabulary grew.
    """
    territory_of(domain)                         # unknown atom raises first
    if domain not in SUPPORTED_GEAR_DOMAINS:
        raise ValueError(
            f"domain '{domain}' is named by §16 and no runtime implements "
            "it; Gear cannot be composed yet. This is the vocabulary, not "
            "an offer")


def one_piece_shape(domains, magnitudes) -> str:
    """`USEFUL` or `HIGH`, per §16.1, or a refusal.

    A HIGH piece carries **exactly two** domain atoms and two magnitude
    atoms -- Design 4's expression of Design 1 §4.5's "high-tier Gear has
    exactly two intrinsics". Anything else is not a shape §16 defines.
    """
    if len(domains) != len(magnitudes):
        raise ValueError(
            f"{len(domains)} domain atom(s) against {len(magnitudes)} "
            "magnitude atom(s); each domain carries its own magnitude")
    if len(domains) == 1:
        return "USEFUL"
    if len(domains) == 2:
        if len({territory_of(d) for d in domains}) != 1:
            raise ValueError(
                "a two-atom piece takes both domains from the SAME "
                "territory (§16.1's completion rule); these span "
                f"{sorted({territory_of(d) for d in domains})}")
        return "HIGH"
    raise ValueError(
        f"§16.1 defines one-atom and two-atom pieces; {len(domains)} is "
        "neither")
