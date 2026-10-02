"""P19.1 — the accepted Gear grammar, and the nine atoms nobody costed.

Amalgam §16 pinning Design 4 §16.1–§16.3. The grammar is declared; no
Gear can be composed, because nothing implements one.
"""
from __future__ import annotations

import pytest

from archipepsi_bridge.schemas import gear as G


# --------------------------------------------------------------------------
# The vocabulary, checked against the design's own arithmetic
# --------------------------------------------------------------------------

def test_the_catalogue_is_twenty_five_atoms_across_four_territories():
    assert len(G.ALL_DOMAINS) == 25
    assert set(G.DOMAINS_BY_TERRITORY) == {"HEAD", "TORSO", "ARMS", "LEGS"}
    assert len(set(G.ALL_DOMAINS)) == 25, "an atom is legal in two territories"


def test_the_designs_own_worked_example_reproduces():
    """§16.1 states it outright: *"`dom_crit` (26) + `mag_marked` (44) =
    70, leaving 30"*. If the tables were mistranscribed this is the
    arithmetic that would say so."""
    assert G.composition_cost(["dom_crit"], ["mag_marked"]) == 70
    assert 100 - 70 == 30
    assert 30 > G.CLAUSE_ALLOWANCE, (
        "which is why §16.1 completes the piece with a second domain atom")


def test_a_territory_constrains_its_domains_one_way():
    assert G.territory_of("dom_crit") == "HEAD"
    assert G.territory_of("dom_rail_control") == "LEGS"
    with pytest.raises(KeyError, match="not a §16 domain atom"):
        G.territory_of("dom_invented")


# --------------------------------------------------------------------------
# The nine uncosted atoms, named rather than guessed
# --------------------------------------------------------------------------

def test_nine_atoms_have_no_recovered_cost():
    """The Amalgam adds them "at the magnitudes that proposal gave it",
    and those numbers live in Designs 2, 3 and 5. A cost invented here
    would be a balance decision wearing a schema's clothes."""
    assert len(G.UNCOSTED_DOMAINS) == 9
    assert len(G.DOMAIN_COST) == 16
    assert set(G.UNCOSTED_DOMAINS) & set(G.DOMAIN_COST) == set()


def test_costing_an_uncosted_atom_raises_rather_than_scoring_zero():
    """Same rule as `content_value.enemy_value`: a free atom passes the
    budget check and makes the piece a fiction."""
    for atom in G.UNCOSTED_DOMAINS:
        with pytest.raises(KeyError, match="no recovered cost"):
            G.composition_cost([atom], ["mag_slight"])


def test_the_uncosted_list_is_derived_not_maintained():
    """Recovering one cost must remove it from the list without anyone
    editing the list -- the two-lists-for-one-fact defect, refused."""
    assert set(G.UNCOSTED_DOMAINS) == set(G.ALL_DOMAINS) - set(G.DOMAIN_COST)


# --------------------------------------------------------------------------
# The shapes §16.1 defines, and only those
# --------------------------------------------------------------------------

def test_one_atom_is_useful_and_two_from_one_territory_is_high():
    assert G.one_piece_shape(["dom_crit"], ["mag_marked"]) == "USEFUL"
    assert G.one_piece_shape(["dom_crit", "dom_targeting"],
                             ["mag_marked", "mag_slight"]) == "HIGH"


def test_a_high_piece_may_not_span_two_territories():
    with pytest.raises(ValueError, match="SAME"):
        G.one_piece_shape(["dom_crit", "dom_speed"],
                          ["mag_marked", "mag_slight"])


def test_each_domain_carries_its_own_magnitude():
    with pytest.raises(ValueError, match="each domain carries"):
        G.one_piece_shape(["dom_crit", "dom_targeting"], ["mag_marked"])


def test_three_atoms_is_not_a_shape_the_design_defines():
    with pytest.raises(ValueError, match="is neither"):
        G.one_piece_shape(["dom_crit", "dom_targeting", "dom_information"],
                          ["mag_slight"] * 3)


# --------------------------------------------------------------------------
# The gate: a vocabulary is not an offer
# --------------------------------------------------------------------------

def test_no_domain_is_implemented_and_every_one_is_refused():
    """NO GEAR BEFORE ITS RUNTIME, the same rule the Status vocabulary
    follows. The support table is empty and that is the honest value."""
    assert G.SUPPORTED_GEAR_DOMAINS == ()
    for atom in G.ALL_DOMAINS:
        with pytest.raises(ValueError, match="no runtime implements"):
            G.refuse_unsupported_domain(atom)


def test_an_unknown_atom_is_refused_before_the_support_question():
    """A typo must not come back as "not implemented yet", which reads
    like something that will arrive."""
    with pytest.raises(KeyError, match="not a §16 domain atom"):
        G.refuse_unsupported_domain("dom_typo")


def test_the_gate_would_admit_a_domain_the_moment_one_is_supported():
    """The gate must be the support table's shape, not a blanket refusal
    that happens to look the same while the table is empty."""
    import unittest.mock as mock
    with mock.patch.object(G, "SUPPORTED_GEAR_DOMAINS", ("dom_crit",)):
        G.refuse_unsupported_domain("dom_crit")          # admitted
        with pytest.raises(ValueError, match="no runtime implements"):
            G.refuse_unsupported_domain("dom_targeting")  # still refused
