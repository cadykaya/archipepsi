"""The bridge half of the client/bridge theme agreement.

Godot re-derives a game's theme so the Hub campaign board and the reveal
card can tint by recipient game. The rule is sha256-based on purpose
(`constants.prng_seed`: "never use Python's built-in hash()"), so the
GDScript side must reimplement it exactly rather than reach for Godot's
`hash()`.

These pairs are pinned on BOTH sides — here, and in
`godot/tests/integration_driver.gd::_check_theme_agreement`. If the rule
ever changes, this test fails first and names the new expectations.
"""

from __future__ import annotations

import hashlib

from archipepsi_bridge.epsilon.fallback import _theme_for
from archipepsi_bridge.schemas import constants as C

#: Must stay identical to the table in the Godot driver.
PINNED = {
    "Ocarina of Time": "temple_ruin",       # from THEME_BY_GAME_HINT
    "Archipepsi": "void_glitch",            # from THEME_BY_GAME_HINT
    "Hollow Knight": "void_glitch",         # hashed
    "Celeste": "temple_ruin",
    "Factorio": "void_glitch",
    "A Link to the Past": "rusted_industrial",
    "Slay the Spire": "neon_transit",
}


def test_theme_for_game_pairs_match_the_client_table():
    for game, theme in PINNED.items():
        assert _theme_for(game) == theme, (
            f"{game!r} now themes as {_theme_for(game)!r}; update the table "
            "in godot/tests/integration_driver.gd too")


def test_hashed_rule_is_sha256_not_python_hash():
    """The GDScript side walks the first 8 digest bytes modulo the theme
    count. Prove that byte-walk equals the bridge's own index."""
    for game in ("Hollow Knight", "Celeste", "Factorio", "Slay the Spire"):
        digest = hashlib.sha256(
            f"{game}|fallback_theme".encode("utf-8")).digest()
        accumulator = 0
        for byte in digest[:8]:
            accumulator = (accumulator * 256 + byte) % len(C.THEMES)
        assert C.THEMES[accumulator] == _theme_for(game)
        # And the same value the bridge computes the direct way.
        assert accumulator == (
            C.prng_seed(game, "fallback_theme") % len(C.THEMES))
