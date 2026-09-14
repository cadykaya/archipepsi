"""What retiring `timed_run` and `pressure_routing` would actually cost.

THE OWNER'S DECISION, MEASURED BEFORE IT IS IMPLEMENTED. Skyiah played
the two standalone drills and asked for them to stop being generated.
That is a generation change and a bridge-policy change at the same
time, and the queue this ran from is explicit that the two halves may
not be done separately -- and that nothing may be quietly substituted
to keep the old point total.

So this changes nothing. It composes the same Zones twice, once with
`fallback._KINDS` as it ships and once with the two families removed,
and prints the deltas on the inputs that decide whether a Zone is
acceptable: activities by family, enemies, rooms, room value, Check
allocation and repairable stations.

    python -m tools.family_retirement [--zones 12] [--seed 7]

Read the SUBSTITUTION line first. The composer picks a family by
`kinds[(guard + len(acts)) % len(kinds)]`, so removing two of four does
not remove content -- it doubles how often the other two come up. A
retirement that leaves the same point total with twice as many target
rows is the outcome the owner asked against.
"""

from __future__ import annotations

import argparse
import collections
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from archipepsi_bridge.epsilon import fallback              # noqa: E402
from archipepsi_bridge.epsilon.requests import (            # noqa: E402
    CampaignContext, PlayerContext, RequestLocation,
    ZoneGenerationRequest,
)
from archipepsi_bridge.schemas import constants as C        # noqa: E402

RETIRE = ("timed_run", "pressure_routing")


def _request(index: int, config) -> ZoneGenerationRequest:
    """One Zone request at the campaign's own scale.

    The same shape `test_fallback_scale` builds, so what is measured
    here is the composer the suites already hold to its contract.
    """
    checks = config.zone_target_checks
    locations = tuple(
        RequestLocation(
            location_id=C.FIRST_LOCATION_ID + i,
            location_name=f"Archipepsi Check {i:03d}",
            item_name="Some Item", recipient_name="Player",
            recipient_game="Some Game", item_flags=0)
        for i in range(checks))
    return ZoneGenerationRequest(
        zone_id=f"zone_{index + 1:03d}", generation_id=f"gen-{index}",
        campaign=CampaignContext(
            seed_name="retirement", slot_name="Player", team=0, slot_id=1,
            zone_index=index + 1, target_game="Some Game",
            is_finale=False, static_glitch_units=0,
            zone_budget=config.zone_budget),
        player=PlayerContext(signal_keys=0, coins_available=0),
        locations=locations)


def _census(zone: dict) -> dict:
    families: collections.Counter = collections.Counter()
    enemies = 0
    activities = 0
    repairs = 0
    for chamber in zone.get("chambers", []):
        for activity in chamber.get("activities", []) or ():
            families[activity.get("kind", "?")] += 1
            activities += 1
        for group in chamber.get("enemies", []) or ():
            enemies += int(group.get("count", 0))
        if chamber.get("activities"):
            repairs += 1
    return {
        "rooms": len(zone.get("chambers", [])),
        "activities": activities,
        "families": families,
        "enemies": enemies,
        # A station's repair is attached to a ROOM that has a puzzle in
        # it, so a room that loses its only activity loses its ability
        # to host a repair. That is the recovery path, not decoration.
        "rooms_with_a_puzzle": repairs,
        "checks": sum(
            1 + len(c.get("additional_reward_location_ids", []) or ())
            for c in zone.get("chambers", [])
            if c.get("reward_location_id") is not None),
    }


def _compose(count: int, kinds: list[str], config) -> list[dict]:
    original = fallback.ACTIVITY_KINDS
    fallback.ACTIVITY_KINDS = tuple(kinds)
    try:
        return [fallback.fallback_zone(_request(i, config))
                for i in range(count)]
    finally:
        fallback.ACTIVITY_KINDS = original


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zones", type=int, default=12)
    parser.add_argument("--scale", choices=("prototype", "default"),
                        default="default")
    args = parser.parse_args()
    config = (C.DEFAULT_CONFIG if args.scale == "default"
              else C.PROTOTYPE_CONFIG)

    before = _compose(args.zones, list(fallback.ACTIVITY_KINDS), config)
    kept = [k for k in fallback.ACTIVITY_KINDS if k not in RETIRE]
    after = _compose(args.zones, kept, config)

    def total(zones, key):
        return sum(_census(z)[key] for z in zones)

    print(f"\n  {args.zones} Zones at {args.scale} scale "
          f"({config.location_count} locations, "
          f"{config.zone_target_checks} Checks per Zone)\n")
    print("  input                    before    after   delta")
    print("  " + "-" * 48)
    for key in ("rooms", "activities", "enemies", "rooms_with_a_puzzle",
                "checks"):
        a, b = total(before, key), total(after, key)
        print(f"  {key.ljust(22)} {a:8d} {b:8d} {b - a:+8d}")

    fam_before: collections.Counter = collections.Counter()
    fam_after: collections.Counter = collections.Counter()
    for z in before:
        fam_before.update(_census(z)["families"])
    for z in after:
        fam_after.update(_census(z)["families"])
    print("\n  family                   before    after   delta")
    print("  " + "-" * 48)
    for kind in sorted(set(fam_before) | set(fam_after)):
        a, b = fam_before[kind], fam_after[kind]
        mark = "  <- retired" if kind in RETIRE else ""
        print(f"  {kind.ljust(22)} {a:8d} {b:8d} {b - a:+8d}{mark}")

    retired = sum(fam_before[k] for k in RETIRE)
    grew = sum(max(0, fam_after[k] - fam_before[k]) for k in kept)
    print("\n  SUBSTITUTION: %d retired activities, %d extra of the "
          "families that stay." % (retired, grew))
    if retired and grew >= retired * 0.5:
        print("  More than half the removed content came back as more of "
              "the\n  same two families. The owner asked against exactly "
              "that, so a\n  retirement needs a policy choice about what "
              "fills the budget --\n  not this switch flipped on its own.")
    enemy_delta = total(after, "enemies") - total(before, "enemies")
    if enemy_delta > 0:
        print("  ENEMIES ROSE by %d. The composer tops a room up with a "
              "group\n  when an activity will not fit, so a narrower "
              "family list turns\n  into more fighting." % enemy_delta)
    lost = total(before, "rooms_with_a_puzzle") \
        - total(after, "rooms_with_a_puzzle")
    if lost > 0:
        print("  %d room(s) lost their only puzzle. A warp station's "
              "repair is\n  attached to a room that HAS one, so that is "
              "a recovery route\n  going missing, not decoration." % lost)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
