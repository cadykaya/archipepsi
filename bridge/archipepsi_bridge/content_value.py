"""How much real content a room holds (CAMPAIGN_SCALE.md 5).

Zone density stopped being "chamber count". A room is worth what is
actually in it, and **the engine decides that, not Epsilon**.

The critical rule, and the reason this module exists at all: a provider
saying `"room_value": 80` is not evidence that a room is worth 80. Epsilon
chooses real structured content and Python scores the components that
were ACCEPTED by the schema. There is no field a provider can set to
raise its own score, which is a stronger guarantee than asking it not to.

The second rule is nearly as important: **an AP Check is not content.** A
pedestal is not gameplay. What the player does to reach, earn or find it
is the gameplay, and that is already scored as the encounter, the
traversal or the secret it really is. Otherwise fifteen pedestals in an
empty warehouse satisfy a 1000-point budget.

WEIGHTS ARE PROVISIONAL. They are reasoned starting values, not measured
ones, and CAMPAIGN_SCALE.md 13 exists to replace them with numbers from
real playtests. What is NOT provisional is that they live here, in one
table, rather than being spread across the validator and the providers.
"""

from __future__ import annotations

from .schemas import constants as C

# ---------------------------------------------------------------------------
# The one authoritative table
# ---------------------------------------------------------------------------

#: Per enemy, by archetype. A brute is worth far more than its head count:
#: it changes how a room is fought, not just how long.
ENEMY_VALUE = {"melee": 3, "ranged": 4, "brute": 10}

#: Per affordance feature. An optional route is real content even though
#: nothing mandatory may depend on it -- arguably especially then.
AFFORDANCE_VALUE = 4

#: Per objective, by kind. `platform_to_goal` scores highest because the
#: whole room IS the activity; `reach_reward` lowest because on its own it
#: is "walk to the thing".
OBJECTIVE_VALUE = {
    "kill_all": 5,
    "platform_to_goal": 6,
    "reach_reward": 2,
}

#: Per platform in a traversal chamber. The gap is what the player
#: actually does, so segments are counted rather than length.
TRAVERSAL_SEGMENT_VALUE = 3

#: Per authored secret. Optional, findable, and the reason to look around.
SECRET_VALUE = 8

#: Activities (CAMPAIGN_SCALE.md 9). A base for existing at all, plus the
#: composition that makes one harder than another -- elements, a clock,
#: an order to get right. Difficulty comes from bounded composition, so
#: the score does too.
#:
#: Only kinds the ENGINE BUILDS may appear here at all: the schema's
#: `ActivityKind` is pinned to `activities.gd` by
#: `test_runner_coverage`, so there is no way to name a puzzle that
#: cannot be built and no way to score one. That is the strong form of
#: "an unimplemented puzzle tag counts for nothing" -- not a rule applied
#: at scoring time, but a thing that cannot be expressed.
ACTIVITY_BASE_VALUE = 6
ACTIVITY_PER_ELEMENT = 3
ACTIVITY_TIMED_BONUS = 4
ACTIVITY_ORDERED_BONUS = 3

#: Floor area per point of space value, and the cap.
#:
#: Space is worth something -- a big room reads and plays differently --
#: but only a little, and it is capped hard. Without the cap, a budget
#: could be met by inflating dimensions, which is the "meaningless
#: repeated geometry" CAMPAIGN_SCALE.md 6 forbids. With it, a maximum
#: arena earns less than four melee enemies.
AREA_PER_POINT = 40.0
MAX_SPACE_VALUE = 12

#: An AP Check. Zero, deliberately and permanently. See the module
#: docstring; there is a test that fails if this stops being zero.
CHECK_VALUE = 0

#: How far a Zone's real total may sit from the budget it was built for.
#: Rooms get tolerance (CAMPAIGN_SCALE.md 5); the Zone does not get much.
ZONE_BUDGET_TOLERANCE = 0.10


def _space_value(chamber) -> int:
    """Floor area, capped. Corridors use length x width; rooms w x d."""
    width = float(getattr(chamber, "width", 0.0) or 0.0)
    other = float(getattr(chamber, "depth", 0.0)
                  or getattr(chamber, "length", 0.0) or 0.0)
    if width <= 0.0 or other <= 0.0:
        # A tower is a shaft: its `side` squared, if it has one.
        side = float(getattr(chamber, "side", 0.0) or 0.0)
        width = other = side
    if width <= 0.0 or other <= 0.0:
        return 0
    return min(MAX_SPACE_VALUE, int(width * other / AREA_PER_POINT))


def room_value(chamber) -> int:
    """The real content value of one accepted chamber.

    Reads only fields the schema validated. A chamber cannot carry a
    number that raises this, because none of the inputs is a score.

    Space is scored LAST and never exceeds the content standing in it.
    An empty room earns nothing for being large.
    """
    total = 0

    for group in getattr(chamber, "enemies", ()) or ():
        total += ENEMY_VALUE.get(group.archetype, 0) * group.count

    total += AFFORDANCE_VALUE * len(getattr(chamber, "features", ()) or ())

    objective = getattr(chamber, "objective", None)
    if objective is not None:
        total += OBJECTIVE_VALUE.get(objective, 0)

    segments = int(getattr(chamber, "segment_count", 0) or 0)
    total += TRAVERSAL_SEGMENT_VALUE * segments

    for activity in getattr(chamber, "activities", ()) or ():
        total += ACTIVITY_BASE_VALUE
        total += ACTIVITY_PER_ELEMENT * activity.element_count
        if activity.time_limit > 0.0:
            total += ACTIVITY_TIMED_BONUS
        if activity.ordered:
            total += ACTIVITY_ORDERED_BONUS

    # Checks add nothing. Stated as an explicit no-op rather than an
    # omission, so that deleting it is a visible decision -- and read
    # through `reward_ids`, so a room with three Checks is worth exactly
    # as much as the same room with none.
    total += CHECK_VALUE * len(getattr(chamber, "reward_ids", ()) or ())

    # Space last, and never more than the content it contains.
    #
    # Measured before this rule existed, three empty 28x28 rooms holding
    # one Check each scored 42 -- each earned the full space cap for
    # being big and nothing for being empty. A room is not content
    # because it is large; it is large SO THAT content has somewhere to
    # happen. Bounding space by the rest makes a cavernous empty hall
    # worth about as much as the walk across it, and leaves a genuinely
    # busy arena scoring exactly as it did.
    return total + min(_space_value(chamber), total)


def zone_value(zone) -> int:
    return sum(room_value(chamber) for chamber in zone.chambers)


def budget_band(budget: int) -> tuple[int, int]:
    """The window a Zone's real content must land in."""
    slack = budget * ZONE_BUDGET_TOLERANCE
    return int(budget - slack), int(budget + slack)


def budget_errors(zone, budget: int) -> list[str]:
    """Empty when the Zone actually contains what it was asked for."""
    low, high = budget_band(budget)
    actual = zone_value(zone)
    if actual < low:
        return [f"zone '{zone.zone_id}' holds {actual} of content but was "
                f"built for {budget} (minimum {low}); it is emptier than "
                "the campaign asked for"]
    if actual > high:
        return [f"zone '{zone.zone_id}' holds {actual} of content but was "
                f"built for {budget} (maximum {high})"]
    return []
