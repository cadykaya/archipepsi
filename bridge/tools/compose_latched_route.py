"""Put P14's latch route on the Zone a disposable campaign has generated.

**Why this exists.** `make godot-latched-route-live` plays Dess's latch
route through a real bridge and a real restart, and a live campaign does
not compose one: `latched_route.compose_latched_route` is an explicit
step, never a default (D-10 §5), so the Zone the bridge generates carries
no room graph. This is that step, taken on a save the real path made --
the same composer `make latched-route-fixture` runs, on the same Zone.

**Only before the Zone is entered.** A room graph is built off the
committed layout, and a layout committed without the chain would describe
a Zone that no longer exists. So the record must still be `GENERATED`:
no manifest, no verdict, no progress. Anything else is refused rather
than guessed at.

**Identity, checked rather than assumed.** `--expect` names the Zone the
standalone suite plays (`godot/tests/fixtures/latched_route_zone.json`).
The composed Zone has to be exactly that Zone, compared as the schema
serialises it: same id, same rooms and Checks, the same plate, latch and
shutter on the same edge. That is what makes the live subject Dess's
fixture rather than a lookalike. Nothing is re-keyed to make the two
agree: if the live campaign ever drifts from the fixture this says where
and fails.

**Three forms (D-07, D13).** `--form legacy`, the default, is M-1's
replay: the retired step-once plate, as a save made before the ruling
holds it, against `latched_route_zone.json`. `--form lever` is the
production route -- a lever, a LATCH and the shutter (1c) -- against
`lever_route_zone.json`. `--form held` is 1d's plate held down by its
declared weight, against `held_route_zone.json`, so the live suite can
play it across a real restart with the weight's pose saved by the
bridge (Prod's N-8). The default keeps every existing caller exactly as
it was.

It is a DEVELOPMENT tool, like `give_consumable.py`: it edits a save on
disk through the real `CampaignSave` model and `store.write_save`, and
nothing here runs in a shipped path.

    python tools/compose_latched_route.py <save-dir>
        [--form legacy|lever|held] [--expect <zone.json>]
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

from archipepsi_bridge import store
# `legacy` is M-1's replay: the retired step-once chain (D-07), seeded the
# way a save composed before the ruling holds it. `lever` is D13 1c's
# production route; `held` is 1d's weight on a plate.
from archipepsi_bridge.latched_route import (  # noqa: E402
    compose_held_route, compose_latched_route,
    compose_legacy_step_once_route)
from archipepsi_bridge.schemas import protocol as P
from archipepsi_bridge.schemas.zone import Zone


#: `--form`: which route the step composes.
COMPOSERS = {"legacy": compose_legacy_step_once_route,
             "lever": compose_latched_route,
             "held": compose_held_route}
#: What each form puts in the room, for the one line it prints.
CONTROLS = {"legacy": "plate and latch", "lever": "lever and latch",
            "held": "held plate and its weight"}


def only_save(save_dir: Path) -> Path:
    saves = sorted(p for p in save_dir.glob("*.json")
                   if not p.name.endswith((".bak", ".tmp")))
    if not saves:
        raise SystemExit(f"no campaign save in {save_dir}")
    if len(saves) > 1:
        raise SystemExit(
            f"{len(saves)} campaigns in {save_dir}; name one explicitly")
    return saves[0]


def digest(zone: Zone) -> str:
    """`playtest.played_zone_digest`'s id: the same sixteen characters
    mean the same level."""
    return hashlib.sha256(
        zone.model_dump_json().encode("utf-8")).hexdigest()[:16]


def differences(got: Zone, want: Zone) -> list[str]:
    """Where two Zones part, named by field, for a failure message."""
    a, b = got.model_dump(), want.model_dump()
    out = [f"{key}: {a[key]!r:.80} != {b[key]!r:.80}"
           for key in sorted(set(a) | set(b)) if a.get(key) != b.get(key)]
    return out or ["(serialisation differs, fields agree)"]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("save_dir", type=Path)
    ap.add_argument("--expect", type=Path, default=None,
                    help="the Zone JSON the composed Zone must equal")
    ap.add_argument("--form", choices=tuple(COMPOSERS), default="legacy",
                    help="legacy: M-1's step-once plate (the default); "
                    "lever: D13 1c's production route; held: 1d's plate "
                    "held down by its declared weight")
    args = ap.parse_args(argv)

    path = only_save(args.save_dir)
    save = store.load_save(path)
    if save is None:
        raise SystemExit(f"{path} holds no campaign")
    rec = save.active_zone
    if rec is None or rec.zone is None:
        raise SystemExit(f"{path.name} has no generated Zone to compose "
                         "onto; the seed phase makes one")
    if rec.state != "GENERATED" or rec.manifest \
            or rec.layout_state != "UNCERTIFIED" \
            or rec.progress != P.ZoneProgress():
        raise SystemExit(
            f"{rec.zone_id} is {rec.state}, layout {rec.layout_state}: "
            "the route is composed before a Zone is entered, never after")
    if rec.zone.room_graphs:
        raise SystemExit(f"{rec.zone_id} already declares a room graph")

    before = digest(rec.zone)
    out = COMPOSERS[args.form](rec.zone)
    if not out.emitted:
        raise SystemExit(f"the composer declined {rec.zone_id}: {out.note}")
    composed = out.zone

    if args.expect is not None:
        want = Zone.model_validate_json(
            args.expect.read_text(encoding="utf-8"))
        if composed.model_dump_json() != want.model_dump_json():
            print(f"{rec.zone_id} composed to {digest(composed)}, but "
                  f"{args.expect.name} is {digest(want)}:", file=sys.stderr)
            for line in differences(composed, want)[:8]:
                print(f"  {line}", file=sys.stderr)
            return 1

    zones = tuple(r.model_copy(update={"zone": composed})
                  if r.zone_id == rec.zone_id else r for r in save.zones)
    # Validated as a whole, the way `give_consumable.py` does: a save
    # that fails `CampaignSave`'s cross-field checks is one the bridge
    # would refuse to load, which is a worse place to find out.
    grown = P.CampaignSave.model_validate(
        save.model_copy(update={"zones": zones}).model_dump())
    store.write_save(path, grown)
    graph = composed.room_graphs[0]
    edge = next(e for e in composed.edges if e.opened_by)
    print(f"{path.name}: {rec.zone_id} {before} -> {digest(composed)}, "
          f"{CONTROLS[args.form]} in '{graph.room_id}', shutter across "
          f"'{edge.edge_id}'"
          + (f"; identical to {args.expect.name}, no re-keying"
             if args.expect is not None else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
