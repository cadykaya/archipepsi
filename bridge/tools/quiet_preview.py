"""The quieter-generation PREVIEW, measured against the same twelve cases.

Follow-up 02 item D. `family_retirement.py` measured what narrowing the
family list does ON ITS OWN -- 161 retired activities came back as 176
more of the two that stay. This does not repeat that; it reuses those
same twelve inputs and adds the policy the note in
`fallback.ACTIVITY_KINDS` left to the bridge lane.

**The policy: retirement is a REDUCTION, not a REALLOCATION**
(`archipepsi_bridge.quiet`). The retired families' measured share of a
Zone -- 27.4% over these twelve cases -- is not handed to the survivors,
to enemies, to more rooms or to a topped-up score. It is not spent.

Three arms, because the trade-off is the finding:

    baseline      what ships today
    filter-only   families narrowed, band unchanged  -> compensation
    preview       families narrowed, band reduced    -> the policy

    python -m tools.quiet_preview [--zones 12]

**An unavoidable difference, reported rather than hidden.** The
provider seeds its rng with the budget
(`random.Random(f".../{n}/{budget}")`), so the preview arm -- which
lowers the band on purpose -- does not compose the same ROOMS as the
baseline. Room-level content is therefore matched in the filter-only arm
and NOT matched in the preview arm. Holding both at once is not
available without changing how the seed is derived, which is a
generation change this experiment may not make.
"""

from __future__ import annotations

import argparse
import collections
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from archipepsi_bridge import quiet                          # noqa: E402
from archipepsi_bridge import content_value as CV            # noqa: E402
from archipepsi_bridge.epsilon import fallback               # noqa: E402
from archipepsi_bridge.schemas import constants as C         # noqa: E402
from archipepsi_bridge.schemas.zone import Zone, validate_zone  # noqa: E402
from tools.family_retirement import _census, _request        # noqa: E402


def _compose(count, config, *, kinds=None, budget=None):
    """One arm. `kinds` narrows the OFFER; `budget` sets the band."""
    out = []
    for i in range(count):
        req = _request(i, config)
        if budget is not None:
            req = req.model_copy(update={
                "campaign": req.campaign.model_copy(
                    update={"zone_budget": budget})})
        if kinds is not None:
            req = req.model_copy(update={
                "constraints": {**req.constraints,
                                "activity_kinds": list(kinds)}})
        out.append((fallback.fallback_zone(req), req))
    return out


def _score(zone: dict) -> int:
    return sum(CV.room_value(fallback._AsChamber(c))
               for c in zone["chambers"])


def _per_room(zone: dict) -> collections.Counter:
    return collections.Counter(
        len(c.get("activities") or ()) for c in zone["chambers"])


def _accepts(zone: dict, budget: int) -> bool:
    try:
        z = Zone.model_validate(zone)
    except Exception:
        return False
    errs = validate_zone(
        z, expected_zone_id=z.zone_id,
        allocated_location_ids=list(z.reward_location_ids),
        owned_echo_ids=[], zone_budget=budget)
    return not [e for e in errs if "shell" not in e]


def _arm(name, pairs, budget):
    fams: collections.Counter = collections.Counter()
    rooms = acts = enemies = checks = repairs = score = 0
    per_room: collections.Counter = collections.Counter()
    accepted = 0
    for zone, _req in pairs:
        c = _census(zone)
        fams.update(c["families"])
        rooms += c["rooms"]
        acts += c["activities"]
        enemies += c["enemies"]
        checks += c["checks"]
        repairs += c["rooms_with_a_puzzle"]
        score += _score(zone)
        per_room.update(_per_room(zone))
        accepted += 1 if _accepts(zone, budget) else 0
    return {"name": name, "families": fams, "rooms": rooms,
            "activities": acts, "enemies": enemies, "checks": checks,
            "repairs": repairs, "score": score, "per_room": per_room,
            "accepted": accepted, "n": len(pairs), "budget": budget}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--zones", type=int, default=12)
    args = ap.parse_args()
    cfg = C.DEFAULT_CONFIG
    n = args.zones
    normal_budget = cfg.zone_budget
    prev_budget = quiet.preview_budget(normal_budget)
    kinds = quiet.preview_kinds()

    arms = [
        _arm("baseline", _compose(n, cfg), normal_budget),
        _arm("filter-only", _compose(n, cfg, kinds=kinds), normal_budget),
        _arm("preview", _compose(n, cfg, kinds=kinds, budget=prev_budget),
             prev_budget),
    ]

    print(f"\n  {n} Zones at default scale. "
          f"baseline/filter-only band {normal_budget}, "
          f"preview band {prev_budget} "
          f"({int(quiet.PREVIEW_BUDGET_FRACTION*100)}% of it)\n")
    head = f"  {'':24s}" + "".join(f"{a['name']:>14s}" for a in arms)
    print(head)
    print("  " + "-" * (24 + 14 * len(arms)))
    for key, label in [("rooms", "rooms"), ("activities", "activities"),
                       ("enemies", "enemies"), ("checks", "Checks"),
                       ("repairs", "rooms with a puzzle"),
                       ("score", "raw score")]:
        print(f"  {label:24s}"
              + "".join(f"{a[key]:>14d}" for a in arms))
    print(f"  {'accepted':24s}"
          + "".join(f"{a['accepted']:>11d}/{a['n']:<2d}" for a in arms))
    print()
    for fam in sorted({f for a in arms for f in a["families"]}):
        mark = "  <- retired" if fam in quiet.RETIRED_FAMILIES else ""
        print(f"  {fam:24s}"
              + "".join(f"{a['families'].get(fam, 0):>14d}" for a in arms)
              + mark)
    print("\n  rooms by activity count")
    for k in sorted({k for a in arms for k in a["per_room"]}):
        label = f"    {k} activit{'y' if k == 1 else 'ies'}"
        print(f"  {label:24s}"
              + "".join(f"{a['per_room'].get(k, 0):>14d}" for a in arms))

    base, filt, prev = arms
    print("\n  STATION CONSEQUENCE. A solved activity switches on the "
          "broken station\n  in its own room, so a room with no activity "
          "can host no repair.")
    for a in arms:
        print(f"    {a['name']:12s} rooms that can host a repair: "
              f"{a['repairs']:4d} of {a['rooms']:4d}")
    print(f"    preview leaves {base['repairs'] - prev['repairs']} fewer "
          "repairable rooms than the baseline;\n    the engine lane must "
          "not place a repair-gated station in one of them.")

    print("\n  SUBSTITUTION CHECK (the thing the owner asked against)")
    kept = [k for k in base["families"] if k not in quiet.RETIRED_FAMILIES]
    for arm in (filt, prev):
        extra = sum(arm["families"].get(k, 0) - base["families"].get(k, 0)
                    for k in kept)
        gone = sum(base["families"].get(k, 0)
                   for k in quiet.RETIRED_FAMILIES)
        print(f"    {arm['name']:12s} {gone} retired, "
              f"{extra:+d} of the families that stay, "
              f"enemies {arm['enemies'] - base['enemies']:+d}, "
              f"rooms {arm['rooms'] - base['rooms']:+d}, "
              f"score {arm['score'] - base['score']:+d}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
