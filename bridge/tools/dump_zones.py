"""Dump several ORDINARY generated Zones, for the engine's physical pass.

`playtest dump` writes the one Zone the baseline walks. This writes a
run of consecutive Zones from a real campaign -- the same
`CampaignEngine` path the game drives -- so the engine lane can compose
and WALK more than one shape rather than proving everything about a
single committed fixture.

DIAGNOSTIC, and the fixture is not the evidence: what these are for is
to be built, entered and walked. The report printed here is the graph
half of that; the player half is `godot-room-contract`.
"""

from __future__ import annotations

import argparse
import asyncio
import collections
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
if str(ROOT / "tests") not in sys.path:
    sys.path.insert(0, str(ROOT / "tests"))

from archipepsi_bridge.schemas import constants as C  # noqa: E402


def _shape(zone) -> dict:
    """Degree, junctions, dead ends and side rooms, off the graph."""
    adjacency: dict[str, set[str]] = collections.defaultdict(set)
    for edge in zone.edges:
        if edge.realization != "JOINED":
            continue
        adjacency[edge.room_a].add(edge.room_b)
        adjacency[edge.room_b].add(edge.room_a)
    degree = collections.Counter(
        len(adjacency[ch.id]) for ch in zone.chambers)
    return {
        "rooms": len(zone.chambers),
        "edges": sum(1 for e in zone.edges if e.realization == "JOINED"),
        "plugs": len(zone.plugs),
        "degree_histogram": {str(k): v for k, v in sorted(degree.items())},
        "junctions": sorted(ch.id for ch in zone.chambers
                            if len(adjacency[ch.id]) >= 3),
        "dead_ends": sorted(ch.id for ch in zone.chambers
                            if len(adjacency[ch.id]) == 1),
        "locked_doors": sorted(
            f"{ch.id}/{d.socket_id}" for ch in zone.chambers
            for d in ch.doors if d.usage == "LOCKED"),
        "features": sorted(
            f"{ch.id}:{f.tag}" for ch in zone.chambers
            for f in ch.features),
    }


async def _generate(count: int, out: Path) -> int:
    from conftest import connected_engine, drain      # noqa: E402

    out.mkdir(parents=True, exist_ok=True)
    index = []
    with tempfile.TemporaryDirectory() as save_dir:
        engine, _ = await connected_engine(Path(save_dir),
                                           config=C.DEFAULT_CONFIG)
        for n in range(count):
            await engine.handle_request_next_zone(False)
            await drain()
            zid = engine.save.active_zone_id
            zone = engine.save.zone_by_id(zid).zone
            path = out / f"zone_{n + 1:02d}.json"
            path.write_text(zone.model_dump_json(indent=1),
                            encoding="utf-8")
            shape = _shape(zone)
            shape["file"] = path.name
            shape["zone_id"] = zone.zone_id
            index.append(shape)
            print(f"{path.name}  {shape['rooms']} rooms, "
                  f"{shape['edges']} joined edges, "
                  f"degrees {shape['degree_histogram']}, "
                  f"{len(shape['junctions'])} junction(s), "
                  f"{len(shape['dead_ends'])} dead end(s)")
            # Walk out the way the game does, so the next Zone is the
            # next one a player would be given.
            await engine.handle_enter_zone(zid)
            await engine.handle_abandon_zone(zid)
    (out / "INDEX.json").write_text(
        json.dumps(index, indent=1) + "\n", encoding="utf-8")
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m tools.dump_zones",
        description="Write several ordinary generated Zones as JSON.")
    parser.add_argument("--count", type=int, default=5)
    parser.add_argument(
        "--out", type=Path,
        default=Path("../godot/tests/fixtures/generated"))
    args = parser.parse_args(argv)
    return asyncio.run(_generate(args.count, args.out))


if __name__ == "__main__":
    sys.exit(main())
