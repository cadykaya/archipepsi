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
#: Design 1 §16.1's four territories, in its fixed host order.
TERRITORIES: tuple[str, ...] = get_args(Territory)

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
#: the honest value.** Nothing consumes Gear yet. D16 G1 (owner rulings,
#: 2026-09-25) pairs three domains with runtime stats (`GEAR_EFFECTS`
#: below), and this opens to exactly those in the one commit that follows
#: Prod's StatStack multiplying a worn piece in (note D-8) -- the lever's
#: order: the bridge never admits what the engine cannot yet do.
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
        paired = GEAR_EFFECTS.get(domain)
        raise ValueError(
            f"domain '{domain}' is named by §16 and no runtime implements "
            "it; Gear cannot be composed yet. This is the vocabulary, not "
            "an offer"
            + (f" (it is paired with '{paired[0]}', and opens once the "
               "StatStack applies a worn piece: D16 G1, note D-8)"
               if paired else ""))


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


# --------------------------------------------------------------------------
# D16 G1, as ruled (owner, 2026-09-25): the Legs slice
# --------------------------------------------------------------------------

#: Ruling 1: "Pair speed, jump and landing Gear only with the
#: corresponding runtime stats that already exist. Do not create a second
#: or parallel Gear-stat system." Each paired domain names the stat the
#: runtime's StatStack already moves (`stat_stack.gd`, the nine an Echo
#: trait moves) and Design 1 §16.1's SMALL / MEDIUM / LARGE value for its
#: template, as a multiplier. A worn piece is therefore one more factor in
#: the one stack, under the stack's own floor and envelope; no clamp here
#: is Gear's alone.
#:
#:   dom_speed    INT_MOVE_SPEED       +5 / +11 / +18 %   move_speed
#:   dom_jump     INT_JUMP_HEIGHT      +8 / +18 / +30 %   jump_height
#:                (the runtime launches at the square root of the factor,
#:                so the factor IS the height)
#:   dom_landing  INT_LANDING_CONTROL  air accel          air_control
#:                                     +25 / +55 / +90 %
#:
#: Every other domain is unpaired (D16 §1): twelve have no runtime at
#: all, `dom_mobility_recharge` has no cooldown scaling, and `dom_crit`,
#: `dom_barrier` and `dom_handling` each match two templates.
GEAR_EFFECTS: dict[str, tuple[str, dict[str, float]]] = {
    "dom_speed": ("move_speed", {"mag_slight": 1.05, "mag_marked": 1.11,
                                 "mag_profound": 1.18}),
    "dom_jump": ("jump_height", {"mag_slight": 1.08, "mag_marked": 1.18,
                                 "mag_profound": 1.30}),
    "dom_landing": ("air_control", {"mag_slight": 1.25, "mag_marked": 1.55,
                                    "mag_profound": 1.90}),
}
PAIRED_DOMAINS: tuple[str, ...] = tuple(GEAR_EFFECTS)

#: Ruling 2: "Until a clause catalogue exists, a Gear piece should express
#: one bounded, understandable stat effect." One domain, at the one
#: magnitude that makes a whole piece without a trigger clause: profound
#: puts every paired domain inside USEFUL's band alone (speed 96, jump 90,
#: landing 88), where slight and marked would need a clause nobody has
#: written.
LEGAL_MAGNITUDES: tuple[str, ...] = ("mag_profound",)

assert set(GEAR_EFFECTS) <= set(DOMAIN_COST), "a paired domain has no cost"
assert all(set(factors) == set(MAGNITUDE_COST)
           for _, factors in GEAR_EFFECTS.values()), (
    "a paired template is missing one of §16.1's three magnitudes")
assert all(f >= 1.0 for _, factors in GEAR_EFFECTS.values()
           for f in factors.values()), (
    "Design 1 §16.1: no intrinsic may ever reduce a movement constant")
assert all(USEFUL_BAND[0] <= composition_cost((d,), (m,)) <= USEFUL_BAND[1]
           for d in GEAR_EFFECTS for m in LEGAL_MAGNITUDES), (
    "a legal piece falls outside USEFUL's band without a clause")
assert set(SUPPORTED_GEAR_DOMAINS) <= set(GEAR_EFFECTS), (
    "a supported domain pairs with no runtime stat")


def refuse_illegal_piece(domains, magnitudes) -> None:
    """Why a piece with these atoms may not exist, or nothing.

    In the order a reader needs it: the shape, the pairing (ruling 1), the
    magnitude (ruling 2), and last the gate -- so a piece that could never
    be legal says why, rather than only that the runtime is not ready.
    """
    shape = one_piece_shape(domains, magnitudes)   # arity and territory
    if shape != "USEFUL":
        raise ValueError(
            f"a {shape} piece carries {len(domains)} intrinsics; until a "
            "clause catalogue exists a piece expresses one bounded stat "
            "effect (owner ruling 2, 2026-09-25)")
    for domain in domains:
        territory_of(domain)                        # unknown atom raises
        if domain not in GEAR_EFFECTS:
            raise ValueError(
                f"domain '{domain}' pairs with no runtime stat; Gear is "
                f"paired only with speed, jump and landing "
                f"{sorted(GEAR_EFFECTS)} (owner ruling 1, 2026-09-25)")
    for magnitude in magnitudes:
        if magnitude not in MAGNITUDE_COST:
            raise ValueError(f"'{magnitude}' is not a §16.1 magnitude atom")
        if magnitude not in LEGAL_MAGNITUDES:
            raise ValueError(
                f"'{magnitude}' is not a whole piece without a trigger "
                "clause; the strongest single-stat piece "
                f"{list(LEGAL_MAGNITUDES)} is the only one until a clause "
                "catalogue exists (owner ruling 2, 2026-09-25)")
    for domain in domains:
        refuse_unsupported_domain(domain)           # the gate, last


def effects_of(domains, magnitudes) -> dict[str, float]:
    """The factor each runtime stat takes from one piece.

    Derived from the atoms at read time and never stored on the piece, so
    a rebalance of `GEAR_EFFECTS` moves every save at once, with no
    migration -- the same reason a piece's tier is `one_piece_shape`'s
    answer and not a field (owner ruling 4, 2026-09-25).
    """
    out: dict[str, float] = {}
    for domain, magnitude in zip(domains, magnitudes, strict=True):
        stat, factors = GEAR_EFFECTS[domain]
        out[stat] = out.get(stat, 1.0) * factors[magnitude]
    return out


def worn_effects(pieces) -> dict[str, float]:
    """The factor each runtime stat takes from everything worn.

    `pieces` are worn Gear components. One territory holds one piece, and
    today every paired domain is a LEGS domain, so at most one contributes.
    **When HIGH pieces exist** (ruling 4: "At most one HIGH piece may be
    effective/equipped at once"), this is where the rule is enforced, on
    the derived tier, so reclassifying a piece never touches a save.
    """
    out: dict[str, float] = {}
    for piece in pieces:
        for stat, factor in effects_of(piece.domains,
                                       piece.magnitudes).items():
            out[stat] = out.get(stat, 1.0) * factor
    return out
