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
from .options import ArchipepsiOptions

GAME_NAME = "Archipepsi"


def check_name(location_id: int) -> str:
    return f"Archipepsi Check {location_id - C.LOCATION_ID_BASE:03d}"


#: THE STABLE UNIVERSE. Declared once at the maximum and never smaller.
#:
#: Archipelago requires `location_name_to_id` to be a class attribute, the
#: same for every player, so this cannot depend on anybody's option. That
#: is the right shape anyway: `Archipepsi Check 007` must be id 89100007 in
#: every seed ever generated, whatever campaign size produced it. A world
#: INSTANTIATES a prefix of this map (`create_regions`); it never renumbers
#: an entry because somebody chose a different size, because a renumbered
#: id hands a player the item belonging to a different Check.
location_name_to_id = {
    check_name(i): i
    for i in range(C.LOCATION_ID_BASE + 1,
                   C.LOCATION_ID_BASE + C.LOCATION_UNIVERSE + 1)
}

item_name_to_id = {
    C.ITEM_NAME_SIGNAL_KEY: C.ITEM_ID_SIGNAL_KEY,
    C.ITEM_NAME_EPSILON_COIN: C.ITEM_ID_EPSILON_COIN,
    C.ITEM_NAME_EPSILON_STATIC: C.ITEM_ID_EPSILON_STATIC,
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

    options_dataclass = ArchipepsiOptions
    options: ArchipepsiOptions

    @property
    def campaign(self) -> C.CampaignConfig:
        """This player's campaign scale. Everything else derives from it."""
        return C.CampaignConfig(
            location_count=self.options.location_count.value,
            zone_target_checks=self.options.zone_target_checks.value,
            zone_budget=self.options.zone_budget.value)

    def create_regions(self) -> None:
        campaign = self.campaign
        menu = Region("Menu", self.player, self.multiworld)
        tiers = [Region(name, self.player, self.multiworld)
                 for name in TIER_REGION_NAMES]
        for tier_index, region in enumerate(tiers):
            region.add_locations(
                {check_name(i): i
                 for i in campaign.locations_in_tier(tier_index)},
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
        """Exactly one item per active location.

        Archipelago fills one item per location; a pool off by one fails
        deep in `fill` with a message about something else entirely, so
        the count is asserted here where the cause is still visible.
        """
        counts = self.campaign.item_counts()
        pool = [self.create_item(name)
                for name, count in counts.items()
                for _ in range(count)]
        assert len(pool) == self.campaign.location_count, (
            f"item pool is {len(pool)}, campaign has "
            f"{self.campaign.location_count} locations")
        self.multiworld.itempool += pool

    def get_filler_item_name(self) -> str:
        return C.ITEM_NAME_EPSILON_STATIC

    def fill_slot_data(self) -> dict:
        campaign = self.campaign
        return {
            "schema_version": 7,
            #: The campaign's immutable scale. The client consumes THIS
            #: rather than a build-time default; a bridge quietly using 30
            #: while the seed is 450 is a divergence, not a default.
            "campaign_scale": {
                "location_count": campaign.location_count,
                "zone_target_checks": campaign.zone_target_checks,
                "zone_budget": campaign.zone_budget,
            },
            #: ACTIVE locations only, not the stable universe. The client
            #: must never treat an uninstantiated id as a Check it can go
            #: and find.
            "location_ids": campaign.active_location_ids(),
            "tiers": {str(t): campaign.locations_in_tier(t)
                      for t in range(C.TIER_COUNT)},
            "goal_location_id": campaign.goal_location_id,
            "item_names": {
                "signal_key": C.ITEM_NAME_SIGNAL_KEY,
                "epsilon_coin": C.ITEM_NAME_EPSILON_COIN,
                "epsilon_static": C.ITEM_NAME_EPSILON_STATIC,
            },
        }
