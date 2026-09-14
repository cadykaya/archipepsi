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
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from archipepsi_bridge import layout as layout_mod   # noqa: E402
from archipepsi_bridge.schemas.zone import Zone      # noqa: E402


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m tools.check_sample_layouts",
        description="Validate emitted sample layouts with the bridge.")
    parser.add_argument(
        "--sample", type=Path,
        default=Path("../godot/tests/fixtures/sample"))
    args = parser.parse_args(argv)

    zones = sorted(p for p in args.sample.glob("zone_*.json"))
    if not zones:
        print(f"no sample Zones under {args.sample}; run `make zone-sample`")
        return 1
    accepted = 0
    missing = 0
    refused: list[str] = []
    for path in zones:
        zone = Zone.model_validate_json(path.read_text(encoding="utf-8"))
        emitted = args.sample / "layouts" / path.name
        if not emitted.exists():
            missing += 1
            print(f"{path.name}  NO MANIFEST -- the router did not "
                  f"produce one")
            continue
        result = json.loads(emitted.read_text(encoding="utf-8"))
        verdict = layout_mod.validate(zone, result)
        if verdict.status == "LAYOUT_OK":
            accepted += 1
            print(f"{path.name}  ACCEPTED")
        else:
            refused.append(path.name)
            why = "; ".join(verdict.errors)
            print(f"{path.name}  {verdict.status}: {why}")
    print(f"\nSAMPLE  {accepted} of {len(zones)} layout(s) accepted by the "
          f"bridge; {missing} never laid out, {len(refused)} refused")
    if refused or missing:
        print("SAMPLE LAYOUTS NOT ACCEPTED: " + ", ".join(
            refused + (["%d with no manifest" % missing] if missing else [])))
        return 1
    print("SAMPLE LAYOUTS OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
