"""D-11 — game-pack identity, the bridge half.

Agreed in `docs/D11_THEME_PACK_PROD_ANSWER.md`: an optional
`Zone.theme_pack` beside an unchanged `Zone.theme`; a flat
`pack_textures` table keyed `<pack>/<theme>/<role>` with the family
rows' own schema; one key tried first and no hop of its own; universal
roles refused for a pack exactly as for a family.

**Nothing here selects a pack, regenerates an asset, or reads the art
lane's pixels.** The resolver and its cache are Prod's; the descriptor
is written by the art toolchain.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from archipepsi_bridge import theme_packs as TP
from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.zone import Zone

DESCRIPTOR = (Path(__file__).resolve().parents[2]
              / "godot/content/theme/THEME_PACK.json")


def _zone(**over) -> Zone:
    body = {
        "schema_version": 7, "zone_id": "zone_001", "display_name": "Relay",
        "target_game": "Game", "theme": "gothic_stone",
        "chambers": [{"id": "c001", "type": "arena", "width": 16.0,
                      "depth": 15.0, "wall_height": 5.0,
                      "objective": "kill_all",
                      "reward_location_id": 89100001,
                      "enemies": [{"archetype": "melee", "count": 1}]}],
    }
    body.update(over)
    return Zone.model_validate(body)


def _descriptor() -> dict:
    return json.loads(DESCRIPTOR.read_text(encoding="utf-8"))


# --------------------------------------------------------------------------
# The identity: separate, optional, and inert until reviewed
# --------------------------------------------------------------------------

def test_the_six_house_families_are_unchanged():
    assert C.THEMES == ("concrete_facility", "rusted_industrial",
                        "neon_transit", "gothic_stone", "temple_ruin",
                        "void_glitch")


def test_a_zone_without_a_pack_is_the_zone_it_always_was():
    zone = _zone()
    assert zone.theme_pack is None
    assert zone.theme == "gothic_stone"


def test_an_unreviewed_pack_is_nameable_by_no_zone():
    """Authored rows make a candidate, and a candidate is not selected."""
    with pytest.raises(ValidationError, match="is candidate"):
        _zone(theme_pack="dark_souls_iii")


@pytest.mark.parametrize("status", ["selectable", "approved"])
def test_a_reviewed_pack_may_be_named(monkeypatch, status):
    monkeypatch.setitem(C.THEME_PACK_STATUS, "dark_souls_iii", status)
    zone = _zone(theme_pack="dark_souls_iii")
    assert (zone.theme, zone.theme_pack) == ("gothic_stone", "dark_souls_iii")


def test_a_candidate_stays_a_candidate_when_registered_as_one(monkeypatch):
    monkeypatch.setitem(C.THEME_PACK_STATUS, "dark_souls_iii", "candidate")
    with pytest.raises(ValidationError, match="is candidate"):
        _zone(theme_pack="dark_souls_iii")


def test_a_pack_may_not_take_a_house_familys_name():
    with pytest.raises(ValidationError, match="name of a house family"):
        _zone(theme_pack="gothic_stone")


def test_nothing_is_registered_and_nothing_in_composition_selects_one():
    """No pack has been reviewed, and there is no approved selection
    rule -- so the registry is empty and the composed Zone names none."""
    from archipepsi_bridge.playtest import played_zone
    assert C.THEME_PACK_STATUS == {}
    assert set(C.THEME_PACK_STATES) == {"candidate", "selectable", "approved"}
    assert played_zone().theme_pack is None


# --------------------------------------------------------------------------
# The descriptor contract
# --------------------------------------------------------------------------

def test_the_shipped_descriptor_has_no_pack_table_and_is_valid():
    """Backward compatibility in the file format: no table, no change."""
    d = _descriptor()
    assert C.THEME_PACK_TABLE not in d
    assert TP.pack_table_problems(d) == []


def _with_packs(rows: dict) -> dict:
    d = _descriptor()
    d[C.THEME_PACK_TABLE] = rows
    return d


def _family_row() -> dict:
    return dict(next(iter(_descriptor()["textures"].values())))


def test_a_well_formed_pack_row_is_accepted():
    d = _with_packs({"dark_souls_iii/gothic_stone/wall": _family_row()})
    assert TP.pack_table_problems(d) == []


@pytest.mark.parametrize("key,says", [
    ("dark_souls_iii/gothic_stone/hazard", "is universal"),
    ("dark_souls_iii/castle_keep/wall", "not one of the six"),
    ("dark_souls_iii/wall", "is not '<pack>/<theme>/<role>'"),
    ("gothic_stone/gothic_stone/wall", "house family's name"),
    ("dark_souls_iii/gothic_stone/walll", "would override nothing"),
])
def test_a_malformed_pack_row_is_named(key, says):
    problems = TP.pack_table_problems(_with_packs({key: _family_row()}))
    assert any(says in p for p in problems), problems


def test_a_pack_row_carries_the_family_rows_schema_exactly():
    """Checked against the descriptor's own `textures` rows, not a list
    retyped here -- so "same schema" is what is actually verified."""
    row = _family_row()
    row.pop("sha256_16")
    problems = TP.pack_table_problems(
        _with_packs({"dark_souls_iii/gothic_stone/wall": row}))
    assert any("share one schema" in p for p in problems), problems


# --------------------------------------------------------------------------
# The resolution: one key first, no hop of its own
# --------------------------------------------------------------------------

def test_without_a_pack_the_family_chain_is_exactly_as_before():
    d = _descriptor()
    assert TP.resolution_order(d, "gothic_stone", "ceiling") == [
        "gothic_stone/ceiling", "gothic_stone/wall"]
    assert TP.resolution_order(d, "gothic_stone", "floor") == [
        "gothic_stone/floor"]


def test_a_pack_adds_its_exact_role_and_takes_no_hop():
    """Never `(pack, theme, fallback_role)`: that texture was chosen for
    neither this pack's role nor by this family."""
    d = _descriptor()
    order = TP.resolution_order(d, "gothic_stone", "ceiling", "dark_souls_iii")
    assert order == ["dark_souls_iii/gothic_stone/ceiling",
                     "gothic_stone/ceiling", "gothic_stone/wall"]
    assert sum(k.startswith("dark_souls_iii/") for k in order) == 1


def test_a_universal_role_resolves_from_no_table_at_all():
    d = _descriptor()
    assert TP.resolution_order(d, "gothic_stone", "hazard",
                               "dark_souls_iii") == []


def test_the_contract_reaches_the_engine():
    gd = (Path(__file__).resolve().parents[2]
          / "godot/scripts/autoload/constants.gd").read_text(encoding="utf-8")
    for line in ('const THEME_PACK_TABLE = "pack_textures"',
                 'const THEME_UNIVERSAL_ROLES = ["hazard"]',
                 "const THEME_PACK_STATUS = {}",
                 'const THEME_PACK_STATES = ["candidate", "selectable", '
                 '"approved"]'):
        assert line in gd, f"missing from constants.gd: {line}"
