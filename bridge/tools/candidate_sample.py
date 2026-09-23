"""O05-13.3: a bounded, frozen sample of the CANDIDATE profile's outcomes.

    cd bridge && python3 tools/candidate_sample.py --count 12 \
        --out ../docs/ledgers/ov05_evidence/candidate_sample.json

**What is frozen, before anything runs.** The count, the campaign
configuration (`C.DEFAULT_CONFIG`, the mock multiworld the diagnostic
launcher uses), the provider (the deterministic fallback, the only one
available without credentials), the profile (every step, in its order)
and the revision. They are written at the top of the output, and the
cases follow in the order they were generated.

**What each case records.** The Zone's identity, the provider that
composed it, its proposal digest, every requested step with EMITTED or
DECLINED and the step's own reason, and whether the Zone still carries
every Check it was allocated -- a composer that dropped one to make its
relationship fit would be the failure O05-13.3 names.

**What it does not record, said out loud.** The engine's layout verdict:
this is the bridge half, run without Godot. `godot-candidate-live` is
where one candidate Zone is built, accepted and played. Consecutive
Zones come from ONE campaign, walked out the way the game walks out
(`dump_zones.py` does the same), so re-keying is not involved; a
different seed would compose different geometry, and none is used here.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
if str(ROOT / "tests") not in sys.path:
    sys.path.insert(0, str(ROOT / "tests"))

from archipepsi_bridge import candidate as CP  # noqa: E402
from archipepsi_bridge.schemas import constants as C  # noqa: E402
from archipepsi_bridge.version import build_metadata  # noqa: E402


async def _sample(count: int, steps: tuple[str, ...]) -> dict:
    from conftest import connected_engine, drain      # noqa: E402
    meta = build_metadata()
    frozen = {
        "revision": meta["commit"], "tree": meta["tree"],
        "count": count, "profile": list(steps),
        "config": "C.DEFAULT_CONFIG (mock multiworld, default scale)",
        "provider": "fallback (deterministic; no model credentials used)",
        "layout": "NOT built here -- bridge half only; see "
                  "godot-candidate-live for a built, accepted, played Zone",
    }
    cases = []
    with tempfile.TemporaryDirectory() as save_dir:
        engine, _ = await connected_engine(Path(save_dir),
                                           config=C.DEFAULT_CONFIG)
        engine.candidate_steps = steps
        for n in range(count):
            await engine.handle_request_next_zone(False)
            await drain()
            zid = engine.save.active_zone_id
            rec = engine.save.zone_by_id(zid)
            record_path = Path(save_dir) / "candidate" / f"{zid}.json"
            record = (json.loads(record_path.read_text(encoding="utf-8"))
                      if record_path.is_file() else None)
            allocated = set(rec.allocated_location_ids)
            placed = set(rec.zone.reward_location_ids) if rec.zone else set()
            cases.append({
                "case": n + 1,
                "zone_id": zid,
                "state": rec.state,
                "provider": record.get("provider") if record else None,
                "proposal_digest": (record.get("proposal_digest")
                                    if record else None),
                "steps": record.get("steps") if record else None,
                "certified": record.get("certified") if record else None,
                "checks_allocated": len(allocated),
                "checks_placed": len(placed),
                "every_allocated_check_placed": allocated <= placed,
                "record": "written" if record else "MISSING",
            })
            await engine.handle_enter_zone(zid)
            await engine.handle_abandon_zone(zid)
    emitted = {s: sum(1 for c in cases for x in (c["steps"] or ())
                      if x["step"] == s and x["emitted"]) for s in steps}
    return {"frozen": frozen, "cases": cases,
            "summary": {"emitted_per_step": emitted,
                        "cases": len(cases),
                        "every_case_kept_its_checks": all(
                            c["every_allocated_check_placed"]
                            for c in cases),
                        "every_case_certified": all(
                            c["certified"] for c in cases)}}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="tools/candidate_sample.py",
        description="Generate a bounded, frozen sample of candidate Zones "
                    "and record what the profile did to each.")
    parser.add_argument("--count", type=int, default=12)
    parser.add_argument("--steps", default="all")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    steps = CP.parse(args.steps)
    result = asyncio.run(_sample(args.count, steps))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=1) + "\n",
                        encoding="utf-8")
    for case in result["cases"]:
        marks = ", ".join(
            f"{x['step']}={'EMIT' if x['emitted'] else 'decline'}"
            for x in case["steps"] or ())
        print(f"case {case['case']:2d} {case['zone_id']}: {marks}; "
              f"checks {case['checks_placed']}/{case['checks_allocated']}")
    print("summary:", json.dumps(result["summary"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
