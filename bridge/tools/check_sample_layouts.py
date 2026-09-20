"""Judge the engine's sample layouts with the real bridge validator.

`--sample` in the Godot graph driver composes every Zone of the declared
sample and writes the committed manifest out. **A router returning
`LAYOUT_OK` is not the same claim as a bridge accepting what it
produced**, and only one of those two is measured inside the engine. This
runs the other one: `layout.validate`, the same function the live bridge
calls, over each emitted manifest.

Every result is reported, including the refusals.

**A REPORT, NOT A GATE, and the reason is worth knowing.** These
manifests come from Zones that were composed and measured but never
PLAYED: `ZoneController.setup` does more to a Zone than `ZoneBuilder`
does, so probing a side doorway here is not probing the doorway a player
walks through, and every refusal of the "door X is USED and the engine
measured it as solid" kind is a fact about this harness. Layout
acceptance is gated live, by `godot-integration`, against a real bridge
and a real controller.

What this pass is still good for is the manifest-only classes -- room
overlap, chain continuity, anchors inside their rooms -- which need no
probe. Those found something: `zone_10` and `zone_12` overlapped by less
than the router's half-cubic-metre tolerance and more than the
validator's millimetre. The router now asks the validator's question
itself, before it claims `LAYOUT_OK`.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from archipepsi_bridge import layout as layout_mod   # noqa: E402
from archipepsi_bridge.schemas.zone import Zone      # noqa: E402


def _engine_revision() -> str:
    """WHICH ENGINE BUILT THESE MANIFESTS, as far as this can know.

    An old file on disk is not new evidence, and a census that does not
    say which revision produced it cannot be told apart from one that
    does. The router runs inside Godot out of the working tree, so the
    tree's own revision is the honest answer -- with `-dirty` when it
    has uncommitted changes, because then it is not any revision.
    """
    try:
        head = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
            capture_output=True, text=True, timeout=10)
        dirty = subprocess.run(
            ["git", "status", "--porcelain"], cwd=ROOT,
            capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return "unknown"
    if head.returncode != 0:
        return "unknown"
    return head.stdout.strip() + ("-dirty" if dirty.stdout.strip() else "")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m tools.check_sample_layouts",
        description="Validate emitted sample layouts with the bridge.")
    parser.add_argument(
        "--sample", type=Path,
        default=Path("../godot/tests/fixtures/sample"))
    parser.add_argument(
        "--json", type=Path, default=None,
        help="also write the census as JSON, with per-case identity")
    args = parser.parse_args(argv)
    revision = _engine_revision()

    zones = sorted(p for p in args.sample.glob("zone_*.json"))
    if not zones:
        print(f"no sample Zones under {args.sample}; run `make zone-sample`")
        return 1
    accepted = 0
    missing = 0
    refused: list[str] = []
    census: list[dict] = []
    print(f"SAMPLE  engine revision {revision}; {len(zones)} source "
          f"case(s) under {args.sample}")
    for path in zones:
        zone = Zone.model_validate_json(path.read_text(encoding="utf-8"))
        # WHICH CASE, UNDER WHICH IDENTITY. Placement is seeded by
        # `hash("<zone_id>|<theme>|layout")`, so the id and the theme
        # ARE the seed inputs -- a census that names only the filename
        # cannot be matched to the experiment that produced it.
        row = {"case": path.name, "zone_id": zone.zone_id,
               "theme": zone.theme,
               "proposal_digest": layout_mod.proposal_digest(zone),
               "engine_revision": revision}
        ident = (f"{path.name}  [{zone.zone_id} | {zone.theme} | "
                 f"{row['proposal_digest']}]")
        emitted = args.sample / "layouts" / path.name
        if not emitted.exists():
            missing += 1
            row["outcome"] = "NO_MANIFEST"
            census.append(row)
            print(f"{ident}  NO MANIFEST -- the router did not "
                  f"produce one")
            continue
        result = json.loads(emitted.read_text(encoding="utf-8"))
        verdict = layout_mod.validate(zone, result)
        # `verdict.accepted`, not a status string guessed at. This read
        # `status == "LAYOUT_OK"` -- the ROUTER's word for success, which
        # `layout.validate` never returns; its statuses are `ACCEPTED`
        # and `LAYOUT_REFUSED`. So this branch could not be reached, and
        # every run this tool has ever made reported 0 accepted BY
        # CONSTRUCTION. It was invisible while a missing evidence class
        # refused everything anyway.
        if verdict.accepted:
            accepted += 1
            row["outcome"] = "ACCEPTED"
            row["manifest_digest"] = verdict.manifest["manifest_digest"]
            print(f"{ident}  ACCEPTED  "
                  f"manifest {row['manifest_digest']}")
        else:
            refused.append(path.name)
            why = "; ".join(verdict.errors)
            row["outcome"] = verdict.status
            row["errors"] = list(verdict.errors)
            print(f"{ident}  {verdict.status}: {why}")
        census.append(row)
    built = len(zones) - missing
    print(f"\nSAMPLE  {built} of {len(zones)} Zone(s) physically laid out "
          f"and emitted a manifest; of those, {accepted} were ACCEPTED by "
          f"the validator on this single pass and {len(refused)} refused; "
          f"{missing} never laid out")
    print("SAMPLE  this is ONE validation pass over a manifest built "
          "offline. It is not the live acceptance loop: retries, eventual "
          "acceptance after recomposition, and exhaustion of the refusal "
          "budget belong to `godot-integration`, and a refusal here is "
          "not a failed campaign.")
    if args.json is not None:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(
            {"engine_revision": revision,
             "source": str(args.sample),
             "sources": len(zones), "laid_out": built,
             "accepted": accepted, "refused": len(refused),
             "no_manifest": missing, "cases": census},
            indent=1, sort_keys=True) + "\n", encoding="utf-8")
        print(f"SAMPLE  census written to {args.json}")
    if refused or missing:
        print("SAMPLE LAYOUTS NOT ACCEPTED: " + ", ".join(
            refused + (["%d with no manifest" % missing] if missing else [])))
        return 1
    print("SAMPLE LAYOUTS OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
