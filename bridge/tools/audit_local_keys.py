"""H-KEYS — what each local key opens, and whether a player would notice.

PT-15: "Earlier Zone yielded keys without noticed matching doors." That
is an owner observation, not a diagnosis, and it has at least three
different causes that need three different repairs:

  NO LOCK       the key opens nothing at all -- a generator defect;
  NOTHING       the lock guards a branch with no Check, no exit and no
                further key -- a payoff that is real but empty;
  KEY FIRST     the player holds the key before they can ever stand at
                the lock, so the door opens as they reach it and never
                reads as locked -- a presentation question, not a
                missing lock.

**Read-only, over the DECLARATION.** It validates each Zone through the
real schema and reads the doors the engine is told to realize. Whether
the engine realized each lock as declared is Prod's runtime evidence,
and this does not claim it. No global key-scope conclusion is drawn
from a sample; the report names each key.

    python bridge/tools/audit_local_keys.py            # the committed sample
    python bridge/tools/audit_local_keys.py --json out.json path/*.json
"""

from __future__ import annotations

import argparse
import collections
import glob
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from archipepsi_bridge.schemas.zone import Zone  # noqa: E402

SAMPLE = ROOT.parent / "godot" / "tests" / "fixtures" / "sample"

#: The classes, in the order a reader should worry about them.
CLASSES = ("NO_LOCK", "NOTHING", "KEY_FIRST", "GATES_CHECK", "GATES_EXIT",
           "GATES_KEY")


def _reach(zone: Zone, entry: str, *, without: frozenset[str] = frozenset(),
           keys: frozenset[str] | None = None) -> set[str]:
    """Rooms reachable from `entry`.

    `without` removes edges outright. `keys`, when given, is the set of
    keys held: a LOCKED door whose key is not held blocks its edge.
    `None` means every lock is open -- the question "where can the
    player EVER get" rather than "where can they get right now".
    """
    locked = {}
    for c in zone.chambers:
        for d in c.doors:
            if d.usage == "LOCKED" and d.edge_id:
                locked.setdefault(d.edge_id, set()).add(d.key_id)
    out, stack = {entry}, [entry]
    while stack:
        room = stack.pop()
        for e in zone.edges:
            if e.edge_id in without or room not in e.rooms:
                continue
            if not e.traversable(room):
                continue
            if keys is not None and not locked.get(e.edge_id, set()) <= keys:
                continue
            nxt = e.other(room)
            if nxt not in out:
                out.add(nxt)
                stack.append(nxt)
    return out


def _edges_of(zone: Zone, room: str) -> frozenset[str]:
    return frozenset(e.edge_id for e in zone.edges if room in e.rooms)


def audit_zone(zone: Zone) -> list[dict]:
    """One row per declared key."""
    if not zone.edges:
        return []
    entry = zone.chambers[0].id
    exit_room = zone.chambers[-1].id
    rewards = {c.id for c in zone.chambers
               if c.reward_location_id is not None
               or c.additional_reward_location_ids}
    key_room = {k.key_id: c.id for c in zone.chambers for k in c.keys}
    locks: dict[str, list[tuple[str, str]]] = collections.defaultdict(list)
    for c in zone.chambers:
        for d in c.doors:
            if d.usage == "LOCKED" and d.key_id:
                locks[d.key_id].append((c.id, d.edge_id))
    everywhere = _reach(zone, entry)
    rows = []
    for key, home in sorted(key_room.items()):
        row = {"zone": zone.zone_id, "key": key, "key_room": home,
               "locks": [f"{r}:{e}" for r, e in locks.get(key, ())]}
        if not locks.get(key):
            row["class"] = "NO_LOCK"
            rows.append(row)
            continue
        behind: set[str] = set()
        for _, edge_id in locks[key]:
            behind |= everywhere - _reach(zone, entry,
                                          without=frozenset({edge_id}))
        other_keys = {k for k, r in key_room.items() if r in behind and k != key}
        if exit_room in behind:
            cls = "GATES_EXIT"
        elif behind & rewards:
            cls = "GATES_CHECK"
        elif other_keys:
            cls = "GATES_KEY"
        else:
            cls = "NOTHING"
        # KEY FIRST: does every way to the lock pass through the key's
        # own room? Then the player has walked past the key -- and, keys
        # being pickups, almost certainly holds it -- before they can
        # stand at the lock, and the door opens as they reach it. Asked
        # by taking the key's room out of the graph: a lock room still
        # reachable without it is one the player can meet locked. A key
        # in the same room as its lock is met together with it.
        seen_locked = any(
            r == home or r in _reach(zone, entry, without=_edges_of(zone, home))
            for r, _ in locks[key]) if home != entry else any(
            r == home for r, _ in locks[key])
        row["class"] = cls if seen_locked or cls == "NOTHING" else "KEY_FIRST"
        row["gates"] = cls
        row["behind"] = sorted(behind)
        rows.append(row)
    return rows


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("paths", nargs="*",
                    help="Zone JSON files (default: the committed sample)")
    ap.add_argument("--json", type=Path, default=None,
                    help="also write every row as JSON here")
    args = ap.parse_args(argv)
    paths = args.paths or sorted(glob.glob(str(SAMPLE / "zone_*.json")))
    rows = []
    for path in paths:
        raw = json.loads(Path(path).read_text(encoding="utf-8"))
        rows.extend(audit_zone(Zone.model_validate(raw.get("zone", raw))))
    counts = collections.Counter(r["class"] for r in rows)
    print(f"{len(paths)} Zones, {len(rows)} declared keys")
    for cls in CLASSES:
        print(f"  {cls:12} {counts.get(cls, 0)}")
    for r in rows:
        if r["class"] in ("NO_LOCK", "NOTHING", "KEY_FIRST"):
            print(f"  {r['class']:12} {r['zone']} key '{r['key']}' in "
                  f"{r['key_room']} -> {r['locks'] or 'no door'}"
                  + (f" (gates {r.get('gates')})" if r.get("gates") else ""))
    if args.json:
        args.json.write_text(json.dumps(rows, indent=1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
