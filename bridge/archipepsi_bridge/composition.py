"""What stops a valid Zone from being a boring one (CAMPAIGN_SCALE.md 6).

A budget is necessary and not sufficient. A hundred identical connectors
can total 1000 points and still be a bad level, and every rule here
exists to forbid one specific degenerate output the owner named -- not to
script the level.

The distinction matters more than it sounds. Constraints that describe
what a good Zone looks like turn into a template, and Epsilon stops
composing and starts filling in blanks. These say only what a Zone may
not be, and leave everything else free.

Expectations SCALE. A 200-point development Zone is three rooms and is
not required to contain a landmark, a quiet space and combat variety; a
1000-point Zone is a level and is.
"""

from __future__ import annotations

from .content_value import room_value, zone_value

#: Above this budget a Zone is a full-size level and the composition
#: rules apply in full. Below it, only the rules that are about
#: correctness rather than richness.
#:
#: 600 rather than the 1000 default so that a deliberately smaller
#: campaign still gets levels rather than corridors -- the cutoff is
#: "is this meant to be a level", not "is this the default".
FULL_SIZE_BUDGET = 600

#: A room worth less than this is a connector: somewhere to walk, not
#: somewhere to be. They are legitimate and necessary -- quiet space is
#: on the list of things a Zone should have -- but a chain of them is
#: the "long chains of empty rooms" case.
CONNECTOR_VALUE = 12
MAX_CONSECUTIVE_CONNECTORS = 3

#: A landmark is a room meaningfully bigger than a typical one.
#:
#: Measured against the AVERAGE room rather than against the Zone total,
#: which was the first attempt and was quietly weak: with N uniform rooms
#: each holds 1/N of the total, so a share threshold of 12% only notices
#: uniformity above eight rooms and called a five-room Zone of identical
#: arenas fine. "One memorable major room" is a claim about how it
#: compares to the others, so that is what is measured.
LANDMARK_RATIO = 1.8

#: Below this many rooms of a kind, "they are all the same" is not a
#: meaningful complaint.
VARIETY_THRESHOLD = 3


def _encounter_signature(chamber) -> tuple:
    groups = getattr(chamber, "enemies", ()) or ()
    return tuple(sorted((g.archetype, g.count) for g in groups))


def _feature_tags(chamber) -> tuple:
    return tuple(f.tag for f in (getattr(chamber, "features", ()) or ()))


def composition_errors(zone, budget: int) -> list[str]:
    """Empty when the Zone is not one of the shapes we refuse."""
    errors: list[str] = []
    chambers = list(zone.chambers)
    values = [room_value(c) for c in chambers]

    # --- rules that apply at every size ---------------------------------

    # Every Check in one room. The schema's three-per-room cap makes this
    # impossible past three Checks, so this only bites at exactly the
    # sizes where it still could.
    rooms_with_checks = [c for c in chambers if c.reward_ids]
    total_checks = sum(len(c.reward_ids) for c in chambers)
    if total_checks >= 3 and len(rooms_with_checks) == 1:
        errors.append(
            f"zone '{zone.zone_id}' puts all {total_checks} of its Checks in "
            f"one room; they are the reason to explore the others")

    # --- rules for a full-size Zone -------------------------------------

    if budget < FULL_SIZE_BUDGET:
        return errors

    total = zone_value(zone)

    run = 0
    for chamber, value in zip(chambers, values):
        run = run + 1 if value < CONNECTOR_VALUE else 0
        if run > MAX_CONSECUTIVE_CONNECTORS:
            errors.append(
                f"zone '{zone.zone_id}' has {run} connectors in a row ending "
                f"at '{chamber.id}'; that is a corridor with scenery, not a "
                "sequence of places")
            break

    if values and total > 0:
        biggest = max(values)
        average = total / len(values)
        if biggest < average * LANDMARK_RATIO:
            errors.append(
                f"zone '{zone.zone_id}' has no landmark: its largest room is "
                f"worth {biggest} against an average of {average:.0f}, under "
                f"the {LANDMARK_RATIO}x that makes one room memorable. A "
                "level of interchangeable rooms is a level with nowhere in "
                "it")

    fighting = [c for c in chambers if getattr(c, "enemy_total", 0)]
    if len(fighting) >= VARIETY_THRESHOLD:
        signatures = {_encounter_signature(c) for c in fighting}
        if len(signatures) == 1:
            errors.append(
                f"zone '{zone.zone_id}' uses one encounter in all "
                f"{len(fighting)} of its fights; the second is already the "
                "same fight again")

    tagged = [t for c in chambers for t in _feature_tags(c)]
    if len(tagged) >= VARIETY_THRESHOLD and len(set(tagged)) == 1:
        errors.append(
            f"zone '{zone.zone_id}' offers '{tagged[0]}' {len(tagged)} times "
            "and nothing else; one idea repeated is not optional content")

    # A level needs somewhere to fight and somewhere to breathe. Stated as
    # two presences rather than a ratio, because a ratio is a template.
    if not fighting:
        errors.append(
            f"zone '{zone.zone_id}' at {budget} points contains no combat")
    if not any(v < CONNECTOR_VALUE for v in values):
        errors.append(
            f"zone '{zone.zone_id}' is dense in every room; a level with no "
            "quiet space is exhausting rather than full")

    return errors
