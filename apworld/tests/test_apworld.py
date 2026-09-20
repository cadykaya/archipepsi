"""APWorld self-checks — acceptance tests 36–47 plus the constants pin.

Requires the pinned Archipelago checkout (`make setup`); the whole module
skips if it is absent so the schema suite stays runnable standalone.
"""

from __future__ import annotations

import filecmp
import subprocess
import sys
from pathlib import Path

import pytest

from .conftest import AP_ROOT, REPO_ROOT

if not AP_ROOT.is_dir():  # pragma: no cover
    pytest.skip("Archipelago checkout missing; run `make setup`",
                allow_module_level=True)

from test.bases import WorldTestBase  # noqa: E402  (needs AP on sys.path)

from worlds.archipepsi import (  # noqa: E402
    GAME_NAME, VICTORY_EVENT_NAME, VICTORY_ITEM_NAME,
    item_name_to_id, location_name_to_id,
)
from worlds.archipepsi import constants as C  # noqa: E402


def test_vendored_constants_identical_to_schema_constants():
    """The APWorld's constants.py is a verbatim copy of the binding one."""
    vendored = REPO_ROOT / "apworld" / "archipepsi" / "constants.py"
    binding = (REPO_ROOT / "bridge" / "archipepsi_bridge" / "schemas"
               / "constants.py")
    assert filecmp.cmp(vendored, binding, shallow=False), (
        "apworld/archipepsi/constants.py has drifted from "
        "bridge/archipepsi_bridge/schemas/constants.py — recopy it"
    )


class ArchipepsiTestBase(WorldTestBase):
    game = GAME_NAME


#: The prototype campaign, now reached by ASKING for it rather than by it
#: being the only campaign there is. These assertions are still exactly
#: right -- they are the "small dev seed" half of CAMPAIGN_SCALE.md 14, and
#: the numbers below are literal on purpose: a test that recomputes tier
#: bounds the same way the code does would agree with a broken code.
PROTOTYPE_OPTIONS = {
    "location_count": 30,
    "zone_target_checks": 3,
    "zone_budget": C.ZONE_BUDGET_MIN,
}


class TestStructure(ArchipepsiTestBase):
    options = PROTOTYPE_OPTIONS
    def test_exactly_30_addressed_locations(self):  # test 36
        addressed = [loc for loc in self.multiworld.get_locations(self.player)
                     if loc.address is not None]
        assert len(addressed) == 30
        assert sorted(loc.address for loc in addressed) == list(
            range(89100001, 89100031))
        assert location_name_to_id["Archipepsi Check 001"] == 89100001
        assert location_name_to_id["Archipepsi Check 030"] == 89100030

    def test_item_codes(self):  # test 37
        assert item_name_to_id["Signal Key"] == 89200001
        assert item_name_to_id["Epsilon Coin"] == 89200002
        assert item_name_to_id["Epsilon Static"] == 89200003

    def test_item_pool_counts(self):  # test 38
        pool = [i for i in self.multiworld.itempool if i.player == self.player]
        by_name = {name: sum(1 for i in pool if i.name == name)
                   for name in item_name_to_id}
        assert by_name == {"Signal Key": 2, "Epsilon Coin": 10,
                           "Epsilon Static": 18}

    def test_item_count_equals_location_count(self):  # test 39
        pool = [i for i in self.multiworld.itempool if i.player == self.player]
        addressed = [loc for loc in self.multiworld.get_locations(self.player)
                     if loc.address is not None]
        assert len(pool) == len(addressed) == 30

    def test_origin_region(self):  # test 40
        world = self.multiworld.worlds[self.player]
        assert world.origin_region_name == "Menu"
        assert self.multiworld.get_region("Menu", self.player) is not None

    def test_victory_event(self):  # test 42
        loc = self.multiworld.get_location(VICTORY_EVENT_NAME, self.player)
        assert loc.address is None
        assert loc.parent_region.name == "Tier 2"
        assert loc.item is not None and loc.item.name == VICTORY_ITEM_NAME
        assert loc.item.code is None

    def test_completion_condition_uses_victory(self):  # test 43
        state = self.multiworld.state.copy()
        condition = self.multiworld.completion_condition[self.player]
        assert not condition(state)
        state.collect(self.get_item_by_name(VICTORY_ITEM_NAME))
        assert condition(state)

    def test_check_030_in_tier_2(self):  # test 44
        loc = self.multiworld.get_location("Archipepsi Check 030", self.player)
        assert loc.parent_region.name == "Tier 2"

    def test_slot_data(self):  # test 45
        sd = self.multiworld.worlds[self.player].fill_slot_data()
        assert sd["schema_version"] == 7
        assert sorted(sd["location_ids"]) == list(range(89100001, 89100031))
        assert sd["tiers"] == {
            "0": list(range(89100001, 89100011)),
            "1": list(range(89100011, 89100021)),
            "2": list(range(89100021, 89100031)),
        }
        assert sd["goal_location_id"] == 89100030
        assert sd["campaign_scale"] == {
            "location_count": 30, "zone_target_checks": 3,
            "zone_budget": C.ZONE_BUDGET_MIN,
        }, "the client cannot consume a scale the seed did not send"
        assert sd["item_names"] == {
            "signal_key": "Signal Key",
            "epsilon_coin": "Epsilon Coin",
            "epsilon_static": "Epsilon Static",
        }
        # No location→item placements anywhere in slot data. The closed
        # set is the point: a new key has to be added here deliberately,
        # so nobody smuggles a scouted placement in beside the config.
        assert set(sd) == {"schema_version", "location_ids", "tiers",
                           "goal_location_id", "item_names",
                           "campaign_scale"}


class TestTierReachability(ArchipepsiTestBase):
    """Test 41: Tier 0 from start; Tier 1 needs 1 key; Tier 2 needs 2."""

    options = PROTOTYPE_OPTIONS

    def test_tier_gating(self):
        assert self.can_reach_location("Archipepsi Check 001")
        assert self.can_reach_location("Archipepsi Check 010")
        assert not self.can_reach_location("Archipepsi Check 011")

        self.collect(self.get_item_by_name("Signal Key"))
        assert self.can_reach_location("Archipepsi Check 011")
        assert self.can_reach_location("Archipepsi Check 020")
        assert not self.can_reach_location("Archipepsi Check 021")

        self.collect(self.get_item_by_name("Signal Key"))
        assert self.can_reach_location("Archipepsi Check 021")
        assert self.can_reach_location("Archipepsi Check 030")


def _generate(tmp_path: Path, *yaml_names: str) -> None:
    players = tmp_path / "players"
    players.mkdir()
    for name in yaml_names:
        src = REPO_ROOT / "apworld" / "yaml" / name
        (players / name).write_text(src.read_text())
    result = subprocess.run(
        [sys.executable, "Generate.py",
         "--player_files_path", str(players),
         "--outputpath", str(tmp_path / "output"),
         "--seed", "1"],
        cwd=AP_ROOT, capture_output=True, text=True, timeout=300,
    )
    assert result.returncode == 0, result.stderr[-2000:]
    zips = list((tmp_path / "output").glob("*.zip"))
    assert len(zips) == 1


def test_solo_generation_succeeds(tmp_path):  # test 46
    _generate(tmp_path, "solo.yaml")


def test_multiworld_generation_succeeds(tmp_path):  # test 47
    _generate(tmp_path, "demo.yaml", "partner.yaml")


class TestProductionScale(ArchipepsiTestBase):
    """The default campaign: 450 locations, 15 Checks per Zone, 1000 budget.

    The prototype tests above prove Archipepsi still generates SMALL. This
    proves it generates the campaign people will actually play, which is a
    different claim: 450 locations is fifteen times the item pool, fifteen
    times the fill work, and a goal at a different id.
    """

    options = {
        "location_count": C.DEFAULT_LOCATION_COUNT,
        "zone_target_checks": C.DEFAULT_ZONE_TARGET_CHECKS,
        "zone_budget": C.DEFAULT_ZONE_BUDGET,
    }

    def test_450_addressed_locations_instantiated(self):
        addressed = [loc for loc in self.multiworld.get_locations(self.player)
                     if loc.address is not None]
        assert len(addressed) == 450
        assert sorted(loc.address for loc in addressed) == list(
            range(89100001, 89100451))

    def test_the_pool_is_exactly_450(self):
        pool = [i for i in self.multiworld.itempool if i.player == self.player]
        assert len(pool) == 450
        by_name = {name: sum(1 for i in pool if i.name == name)
                   for name in item_name_to_id}
        assert by_name == {"Signal Key": 2, "Epsilon Coin": 160,
                           "Epsilon Static": 288}
        assert sum(by_name.values()) == 450

    def test_the_goal_moved_with_the_campaign(self):
        """Every other id is stable across sizes; this one is not, because
        the goal is defined as the LAST ACTIVE location."""
        sd = self.multiworld.worlds[self.player].fill_slot_data()
        assert sd["goal_location_id"] == 89100450
        loc = self.multiworld.get_location("Archipepsi Check 450", self.player)
        assert loc.parent_region.name == "Tier 2"

    def test_the_tiers_split_evenly(self):
        sd = self.multiworld.worlds[self.player].fill_slot_data()
        assert [len(v) for v in sd["tiers"].values()] == [150, 150, 150]

    def test_slot_data_carries_the_scale_the_client_must_use(self):
        sd = self.multiworld.worlds[self.player].fill_slot_data()
        assert sd["campaign_scale"] == {
            "location_count": 450, "zone_target_checks": 15,
            "zone_budget": 1000,
        }
        # ...and only the ACTIVE range, never the stable universe. A client
        # told about 600 ids would send Checks Archipelago never made.
        assert len(sd["location_ids"]) == 450
        assert max(sd["location_ids"]) == 89100450


class TestAnUnusualSize(ArchipepsiTestBase):
    """A size that divides by neither the tier count nor the item split.

    97 is prime, so nothing here can be right by accident of arithmetic.
    """

    options = {"location_count": 97, "zone_target_checks": 5,
               "zone_budget": 400}

    def test_everything_still_adds_up(self):
        addressed = [loc for loc in self.multiworld.get_locations(self.player)
                     if loc.address is not None]
        pool = [i for i in self.multiworld.itempool if i.player == self.player]
        assert len(addressed) == len(pool) == 97

        sd = self.multiworld.worlds[self.player].fill_slot_data()
        tiers = [len(v) for v in sd["tiers"].values()]
        assert sum(tiers) == 97 and max(tiers) - min(tiers) <= 1, tiers
        assert sd["goal_location_id"] == 89100097


def test_the_stable_universe_is_declared_at_the_maximum():
    """`location_name_to_id` is a CLASS attribute -- the same for every
    player -- so it must cover the largest campaign anyone can pick. A
    world instantiates a prefix of it; a name missing from this map is a
    location no option can ever select."""
    assert len(location_name_to_id) == C.LOCATION_UNIVERSE
    assert location_name_to_id["Archipepsi Check 001"] == 89100001
    assert location_name_to_id["Archipepsi Check 600"] == 89100600
    for name, loc_id in location_name_to_id.items():
        assert name == f"Archipepsi Check {loc_id - C.LOCATION_ID_BASE:03d}"
