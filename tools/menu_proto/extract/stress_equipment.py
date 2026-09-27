#!/usr/bin/env python3
"""Track A2 -- the prototype's LAYOUT-STRESS equipment save.

    python3 stress_equipment.py <production worktree> <out.json>

Production's equipment fixture has two candidates for Echo A. The review
has to show long descriptions and more candidates than fit, so this
builds ONE more save the way Production's own fixture is built:
* `make_equipment_snapshot.build_log()` -- the fixture's real Echo log,
  unchanged;
* plus the AUTHORED Echoes below, for keys and fields the log already
  uses;
* folded by the model (`_snapshot` -> `CampaignSnapshot`), so the
  inventory, the fold, every comparison and every refusal the prototype
  shows are Production's own answers.

**The model's own limit is the stress.** `MAX_TEXT_LEN` is 160: no
name or description the game can hold is longer. Two descriptions below
sit at that ceiling and one name runs long, so the review shows the
longest text the game can actually produce -- not text it would refuse.

What is authored is the words and numbers of the Echoes in STRESS below
-- names, descriptions and stats -- and nothing else: no key, slot,
territory, state or rule. The prototype marks every item from them, and
says so on screen. They are not Epsilon's output and not game content.

Runs inside a THROWAWAY worktree of the Production branch; imports only.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

WT = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]).resolve()
sys.path.insert(0, str(WT / "bridge"))

from archipepsi_bridge.fixtures import make_equipment_snapshot as E  # noqa: E402
from archipepsi_bridge.schemas import constants as C  # noqa: E402

#: The authored Echoes. Each row is `_interp`'s arguments after the
#: sequence number: (name, source item, source game, recipient, Echo
#: description, concepts, mode, operations). Every primitive copies the
#: field set of one the fixture already folds (Braided Lash's
#: projectile_damage, Arc Bolt's hitscan_damage), so nothing here asks the
#: model for a shape it has not accepted before.
STRESS = [
    ("Hunter's Draw", "Fairy Bow", "Ocarina of Time", "Link",
     "A drawn shot that flies true for as long as you hold your nerve.",
     ["bow", "draw", "patience"], "literal",
     [E._action("act_s_draw", "Hunter's Draw",
                "A drawn shot that flies true while you hold your nerve. "
                "Slower back to the hand than a lash, and you stand still "
                "for the draw, but nothing else hits this far.",
                "echo_a",
                {"type": "projectile_damage", "damage": 16.0,
                 "speed": 36.0, "lifetime": 1.2}, 1.0)]),
    ("Return Arc", "Magic Boomerang", "A Link to the Past", "Link",
     "It comes back, whatever it met on the way.",
     ["boomerang", "return"], "mechanical",
     [E._action("act_s_arc", "Return Arc",
                "A thrown blade that comes back to the hand.",
                "echo_a",
                {"type": "projectile_damage", "damage": 8.0,
                 "speed": 22.0, "lifetime": 1.8}, 0.7)]),
    ("Storm Lance", "Lightning Spear", "Dark Souls", "Solaire",
     "Sunlight, thrown.",
     ["lightning", "spear", "sun"], "conceptual",
     [E._action("act_s_lance", "Storm Lance",
                "A spear of light thrown down the sight line. It strikes "
                "the first thing it meets, hard; until the charge comes "
                "back there is nothing on this key but waiting.",
                "echo_a",
                {"type": "hitscan_damage", "damage": 22.0, "pellets": 1,
                 "spread_degrees": 0.0, "range": 25.0}, 2.4)]),
    ("Pebble Spray", "Slingshot", "Ocarina of Time", "Link",
     "A fistful of stones, not one.",
     ["stone", "spread"], "literal",
     [E._action("act_s_spray", "Pebble Spray",
                "Scatters stones in a short cone.",
                "echo_a",
                {"type": "hitscan_damage", "damage": 3.0, "pellets": 5,
                 "spread_degrees": 12.0, "range": 18.0}, 0.6)]),
    ("Ember Palm", "Pyromancy Flame", "Dark Souls", "Solaire",
     "A fire held in the hand, let go.",
     ["fire", "palm"], "conceptual",
     [E._action("act_s_palm", "Ember Palm",
                "Throws a slow, heavy ball of fire.",
                "echo_a",
                {"type": "projectile_damage", "damage": 20.0,
                 "speed": 14.0, "lifetime": 0.9}, 1.6)]),
    ("Kiln Rod", "Fire Rod", "A Link to the Past", "Link",
     "A rod that remembers the kiln.",
     ["fire", "rod"], "literal",
     [E._action("act_s_rod", "Kiln Rod",
                "Fires a bolt of heat.",
                "echo_a",
                {"type": "projectile_damage", "damage": 12.0,
                 "speed": 18.0, "lifetime": 1.4}, 1.1)]),
    ("Undead Parish Longshot of the Corridor Where Nothing Answers",
     "Longbow", "Dark Souls", "Solaire",
     "A bow for a long corridor.",
     ["bow", "range", "corridor"], "literal",
     [E._action("act_s_long",
                "Undead Parish Longshot of the Corridor Where Nothing "
                "Answers",
                "Fires a long arrow straight down the sight line.",
                "echo_a",
                {"type": "hitscan_damage", "damage": 14.0, "pellets": 1,
                 "spread_degrees": 0.0, "range": 60.0}, 1.4)]),
]


def main() -> None:
    longest = max(len(op["component"]["description"])
                  for row in STRESS for op in row[7])
    if longest > C.MAX_TEXT_LEN:
        raise SystemExit("an authored description is over the model's %d"
                         % C.MAX_TEXT_LEN)
    print("[stress] the longest authored description is %d of %d"
          % (longest, C.MAX_TEXT_LEN))
    log = E.build_log()
    first = len(log)
    log += [E._interp(first + i, *row) for i, row in enumerate(STRESS)]
    snap = E._snapshot(log, E.BASE_SLOTS, {"act_cinder": 1}, 1)
    ids = sorted(op["component"]["component_id"]
                 for row in STRESS for op in row[7]
                 if op.get("op") == "create")
    OUT.write_text(json.dumps({"snapshot": snap, "authored": ids},
                              indent=1, sort_keys=True) + "\n",
                   encoding="utf-8")
    print("[stress] %d fixture Echoes + %d authored -> %s"
          % (first, len(STRESS), OUT))


if __name__ == "__main__":
    main()
