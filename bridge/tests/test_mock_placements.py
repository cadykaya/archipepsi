"""Where the mock put an item is the mock's own scout table, not a guess.

`godot-bombs-live` walks to a Bomb Bag it is told about in advance
(`fixtures/mock_placements.py`), because the client is not told what an
unclaimed Check holds. That is only honest if the list it is handed is
the one the mock multiworld actually serves.
"""

from __future__ import annotations

from archipepsi_bridge.__main__ import MOCK_SCALES
from archipepsi_bridge.fixtures import mock_placements as MP
from archipepsi_bridge.mock_ap import MockAPBackend


def _served(item_name: str, scale: str) -> list[int]:
    backend = MockAPBackend(None, config=MOCK_SCALES[scale])
    return sorted(loc for loc, scout in backend._scout_table().items()
                  if scout.item_name == item_name)


def test_the_list_is_the_scout_table_the_mock_serves():
    for scale in sorted(MOCK_SCALES):
        assert MP.checks_holding("Bomb Bag", scale) \
            == _served("Bomb Bag", scale), scale


def test_the_candidate_scale_holds_bomb_bags():
    assert MP.checks_holding("Bomb Bag", "default")


def test_the_command_prints_the_list_and_refuses_an_absent_item(capsys):
    assert MP.main(["Bomb Bag"]) == 0
    printed = capsys.readouterr().out.strip()
    assert printed == ",".join(
        str(loc) for loc in MP.checks_holding("Bomb Bag", "default"))
    assert MP.main(["No Such Item"]) == 1
