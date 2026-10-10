"""Archipepsi APWorld for Archipelago 0.6.7.

30 addressed locations in three Signal-Key tiers, three addressed items, and
an unaddressed Victory event in Tier 2. Location→item placements are obtained
by scouting at runtime, never from slot data.

The tier structure is built from the vendored `constants.py` (a verbatim copy
of the bridge's `schemas/constants.py`, pinned identical by a test), so the
region rules, the slot-data `tiers` block and the bridge's eligibility logic
all derive from one definition.
"""

from __future__ import annotations

from BaseClasses import Item, ItemClassification, Location, Region

from worlds.AutoWorld import World

from . import constants as C

GAME_NAME = "Archipepsi"


def check_name(location_id: int) -> str:
    return f"Archipepsi Check {location_id - C.LOCATION_ID_BASE:03d}"


location_name_to_id = {
    check_name(i): i
    for i in range(C.FIRST_LOCATION_ID, C.LAST_LOCATION_ID + 1)
}

item_name_to_id = {
    C.ITEM_NAME_SIGNAL_KEY: C.ITEM_ID_SIGNAL_KEY,
    C.ITEM_NAME_EPSILON_COIN: C.ITEM_ID_EPSILON_COIN,
    C.ITEM_NAME_EPSILON_STATIC: C.ITEM_ID_EPSILON_STATIC,
}

ITEM_COUNTS = {
    C.ITEM_NAME_SIGNAL_KEY: C.SIGNAL_KEY_COUNT,
    C.ITEM_NAME_EPSILON_COIN: C.EPSILON_COIN_COUNT,
    C.ITEM_NAME_EPSILON_STATIC: C.EPSILON_STATIC_COUNT,
}

ITEM_CLASSIFICATIONS = {
    C.ITEM_NAME_SIGNAL_KEY: ItemClassification.progression,
    C.ITEM_NAME_EPSILON_COIN: ItemClassification.filler,
    C.ITEM_NAME_EPSILON_STATIC: ItemClassification.filler,
}

#: Region per tier index. Tier N's entrance requires N Signal Keys.
TIER_REGION_NAMES = ("Start", "Tier 1", "Tier 2")

VICTORY_EVENT_NAME = "Archipepsi Victory Event"
VICTORY_ITEM_NAME = "Victory"


class ArchipepsiItem(Item):
    game = GAME_NAME


class ArchipepsiLocation(Location):
    game = GAME_NAME


class ArchipepsiWorld(World):
    """An Archipelago game whose campaign is designed at runtime by Epsilon,
    using the multiworld's own randomized items as its level-design
    vocabulary."""

    game = GAME_NAME
    #: The origin region defaults to "Menu"; naming it explicitly here keeps
    #: the v0.3 hard generation failure (a `Start` origin with no
    #: origin_region_name) impossible to reintroduce.
    origin_region_name = "Menu"

    item_name_to_id = item_name_to_id
    location_name_to_id = location_name_to_id

    def create_regions(self) -> None:
        menu = Region("Menu", self.player, self.multiworld)
        tiers = [Region(name, self.player, self.multiworld)
                 for name in TIER_REGION_NAMES]
        for tier_index, region in enumerate(tiers):
            region.add_locations(
                {check_name(i): i for i in C.locations_in_tier(tier_index)},
                ArchipepsiLocation,
            )

        menu.connect(tiers[0])
        tiers[0].connect(
            tiers[1],
            rule=lambda state: state.has(C.ITEM_NAME_SIGNAL_KEY, self.player, 1),
        )
        tiers[1].connect(
            tiers[2],
            rule=lambda state: state.has(C.ITEM_NAME_SIGNAL_KEY, self.player, 2),
        )

        victory = ArchipepsiLocation(self.player, VICTORY_EVENT_NAME, None, tiers[2])
        victory.place_locked_item(ArchipepsiItem(
            VICTORY_ITEM_NAME, ItemClassification.progression, None, self.player))
        tiers[2].locations.append(victory)
        self.multiworld.completion_condition[self.player] = (
            lambda state: state.has(VICTORY_ITEM_NAME, self.player))

        self.multiworld.regions.extend([menu, *tiers])

    def create_item(self, name: str) -> ArchipepsiItem:
        return ArchipepsiItem(
            name, ITEM_CLASSIFICATIONS[name], item_name_to_id[name], self.player)

    def create_items(self) -> None:
        for name, count in ITEM_COUNTS.items():
            self.multiworld.itempool += [
                self.create_item(name) for _ in range(count)]

    def get_filler_item_name(self) -> str:
        return C.ITEM_NAME_EPSILON_STATIC

    def fill_slot_data(self) -> dict:
        return {
            "schema_version": 7,
            "location_ids": sorted(location_name_to_id.values()),
            "tiers": {str(t): C.locations_in_tier(t)
                      for t in range(C.TIER_COUNT)},
            "goal_location_id": C.GOAL_LOCATION_ID,
            "item_names": {
                "signal_key": C.ITEM_NAME_SIGNAL_KEY,
                "epsilon_coin": C.ITEM_NAME_EPSILON_COIN,
                "epsilon_static": C.ITEM_NAME_EPSILON_STATIC,
            },
        }
