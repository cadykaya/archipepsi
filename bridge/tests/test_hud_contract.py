"""The client half of the S3 resource-HUD contract, checked from Python.

Three agreements cross the language boundary, and none of them is carried
by the export step, so each gets the `test_runner_coverage.py` treatment:
read the GDScript, compare against the schema module that owns the truth.

1. The palette NAMES. `PALETTE_COLORS` is what the schema lets an
   interpretation declare; `ResourcePalette.HUES` is what the client can
   render. A name on one side only is either a colour Epsilon can pick
   that silently falls back to bone, or dead paint.
2. The channel COUNT. The hard resource budget IS the channel count — a
   sixteenth resource would have nowhere to render — and `ResourceMeters`
   pre-lays its rows from its own constant.
3. The glyph RULE. ECHOES.md §12: source identity derives from the game
   name by the sha256 rule both sides already share (`constants.prng_seed`
   / `_prng_seed_mod`). The pins here are the same table
   `hud_driver.gd::PINNED_GLYPHS` holds as glyphs; here they are indices,
   so this side never has to agree with GDScript about fonts, only about
   arithmetic.
"""

from __future__ import annotations

import re
from pathlib import Path

from archipepsi_bridge.schemas import constants as C
from archipepsi_bridge.schemas.echo import HUD_CHANNELS, PALETTE_COLORS

GODOT_UI = Path(__file__).resolve().parents[2] / "godot" / "scripts" / "ui"


def _palette_source() -> str:
    return (GODOT_UI / "resource_palette.gd").read_text()


def test_palette_names_agree_in_both_directions():
    # `\t"name":` at line start — a HUES key, not a string in an expression.
    client = set(re.findall(r'^\t"([a-z]+)":\s+\{"fill"', _palette_source(),
                            re.MULTILINE))
    assert client == set(PALETTE_COLORS), (
        f"schema palette {sorted(PALETTE_COLORS)} vs client palette "
        f"{sorted(client)}; a colour Epsilon may declare must be one the "
        "client can actually mix")


def test_the_prelaid_channel_count_is_the_hard_resource_budget():
    source = (GODOT_UI / "resource_meters.gd").read_text()
    match = re.search(r"^const CHANNELS := (\d+)$", source, re.MULTILINE)
    assert match, "ResourceMeters no longer declares `const CHANNELS := N`"
    assert int(match.group(1)) == HUD_CHANNELS, (
        f"ResourceMeters pre-lays {match.group(1)} rows but the hard "
        f"resource budget is {HUD_CHANNELS}; the two must never drift, "
        "because the budget exists so every resource has a row")


#: 16 glyphs on the client; only the COUNT and the index rule live here.
GLYPH_COUNT = 16

#: Must stay identical (as indices) to `hud_driver.gd::PINNED_GLYPHS`.
PINNED_GLYPH_INDICES = {
    "Ocarina of Time": 7,
    "Dark Souls": 2,
    "Borderlands 2": 14,
    "Archipepsi": 8,
    "Hollow Knight": 1,
    "Some Game": 4,
}


def test_glyph_indices_match_the_client_pins():
    for game, index in PINNED_GLYPH_INDICES.items():
        derived = C.prng_seed(game, "source_glyph") % GLYPH_COUNT
        assert derived == index, (
            f"{game!r} now derives glyph index {derived}, pinned {index}; "
            "update hud_driver.gd::PINNED_GLYPHS in the same commit or the "
            "player's world marks silently change")


def test_the_client_glyph_table_has_the_pinned_length():
    match = re.search(r"const GLYPHS := \[(.*?)\]", _palette_source(), re.S)
    assert match, "ResourcePalette no longer declares `const GLYPHS := [...]`"
    count = len(re.findall(r'"([^"]+)"', match.group(1)))
    assert count == GLYPH_COUNT, (
        f"the client has {count} glyphs, this side pins indices modulo "
        f"{GLYPH_COUNT}; change both together or every pin is wrong")
