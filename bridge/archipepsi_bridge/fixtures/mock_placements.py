"""Which Checks the mock multiworld filled with a given item.

HARNESS KNOWLEDGE, AND IT IS NAMED AS SUCH. A player learns what a Check
holds by claiming it: the snapshot's `scouted` table carries no item name
for a Check that is neither claimed nor stocked in the shop
(`CampaignEngine._scouted_for_snapshot`). A live suite that must walk to a
particular item cannot learn that from the client, and should not.

The candidate launcher's mock AP places its items as a function of its
config alone (`mock_ap._build_placements`), so a suite can be told in
advance where they are, the way a test knows its expected answer. Whoever
uses this says so in its notes and still earns the item through the real
claim; `godot-bombs-live` also checks the client is NOT told before it is.

    python -m archipepsi_bridge.fixtures.mock_placements "Bomb Bag"
    python -m archipepsi_bridge.fixtures.mock_placements "Bomb Bag" --scale default

prints the location ids, lowest first, comma-separated.
"""
from __future__ import annotations

import argparse
import sys

from archipepsi_bridge.__main__ import MOCK_SCALES
from archipepsi_bridge.mock_ap import _build_placements


def checks_holding(item_name: str, scale: str = "default") -> list[int]:
    """Every location the mock at `scale` fills with `item_name`."""
    placements = _build_placements(MOCK_SCALES[scale])
    return sorted(loc for loc, (name, _item_id, _slot, _flags)
                  in placements.items() if name == item_name)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("item_name")
    parser.add_argument("--scale", default="default",
                        choices=sorted(MOCK_SCALES))
    args = parser.parse_args(argv)
    found = checks_holding(args.item_name, args.scale)
    if not found:
        print(f"no Check holds {args.item_name!r} at scale {args.scale}",
              file=sys.stderr)
        return 1
    print(",".join(str(loc) for loc in found))
    return 0


if __name__ == "__main__":
    sys.exit(main())
