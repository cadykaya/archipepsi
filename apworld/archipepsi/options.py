"""Campaign-scale options (CAMPAIGN_SCALE.md 1).

Scale is a per-seed choice, so it belongs in the player's YAML rather than
in a build-time constant. The bounds are the ones `CampaignConfig`
enforces, taken from the same module rather than retyped -- a YAML that
Archipelago accepts and the bridge then refuses would fail at connect
time, after generation, with the seed already made.

Small values stay available on purpose: development, CI and short
multiworlds all want a campaign that finishes in minutes.
"""

from __future__ import annotations

from dataclasses import dataclass

from Options import PerGameCommonOptions, Range

from . import constants as C


class LocationCount(Range):
    """Number of Archipepsi Checks in this campaign.

    The last one is the goal, reached only through the finale Zone, so a
    450-location campaign has 449 ordinary Checks to find.
    """

    display_name = "Location Count"
    range_start = C.LOCATION_COUNT_MIN
    range_end = C.LOCATION_COUNT_MAX
    default = C.DEFAULT_LOCATION_COUNT


class ZoneTargetChecks(Range):
    """Checks allocated to one ordinary Zone.

    Together with Location Count this sets how many Zones the campaign
    has: 449 ordinary Checks at 15 per Zone is about 30 Zones plus the
    finale.
    """

    display_name = "Zone Target Checks"
    range_start = C.ZONE_TARGET_CHECKS_MIN
    range_end = C.ZONE_TARGET_CHECKS_MAX
    default = C.DEFAULT_ZONE_TARGET_CHECKS


class ZoneBudget(Range):
    """How much content a Zone must contain.

    Not a room count. The engine scores the actual content a Zone holds --
    encounters, traversal, puzzles, secrets -- and a Zone has to reach
    this. Larger values mean longer, denser levels.
    """

    display_name = "Zone Budget"
    range_start = C.ZONE_BUDGET_MIN
    range_end = C.ZONE_BUDGET_MAX
    default = C.DEFAULT_ZONE_BUDGET


@dataclass
class ArchipepsiOptions(PerGameCommonOptions):
    location_count: LocationCount
    zone_target_checks: ZoneTargetChecks
    zone_budget: ZoneBudget
