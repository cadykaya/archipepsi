"""Generate `godot/tests/fixtures/equipment_snapshot.json` from real snapshots.

H-INVENTORY's face reads `CampaignSnapshot.inventory` (Dess's H-UI-DATA
projection) joined to `mechanics.owned`. A hand-written snapshot would
let the face be tested against an inventory the bridge cannot produce --
the same reason `rules_snapshot.json` is a real fold. So every variant
here is a `CampaignSnapshot` built by the model itself and dumped the way
the wire carries it: the inventory and the fold are the model's own
computed fields, never typed in.

The log covers what the face has to present honestly:

- a MIXED Echo (an Action and a Trait from one Check), so neither half is
  dropped and each names the other;
- an UPGRADE-ONLY Echo, which must be history on the Action it upgrades
  and never an item of its own;
- two consumables, so "owned but not equipped" and a comparison exist;
- two Actions for the same slot, for the comparison against what is on
  the key;
- a Resource with a two-link chain (always on, with history);
- a Trait that only applies while a given Action is slotted (a usage
  restriction the detail has to state).

Variants, one per consumable state the packet names (04 §5):

  base          Cinder Charge equipped at 2 / 3
  exhausted     equipped and empty, 0 / 3
  unequipped    consumables owned, none on the key
  none_owned    no consumable in the log at all
  acquired      base plus one Echo arriving, for the NEW marker
  swapped       base with Arc Bolt on the key Braided Lash held: what an
                accepted equip's snapshot looks like
  spent_spare   Frost Flask on the key, Cinder Charge off it at 0 / 3:
                an empty supply the face must not offer to equip

Run with `make equipment-fixture`. The log below is the source; the JSON
is not to be edited.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from archipepsi_bridge.schemas import mechanics as M          # noqa: E402
from archipepsi_bridge.schemas.echo import EchoInterpretation  # noqa: E402
from archipepsi_bridge.schemas.protocol import (  # noqa: E402
    CampaignSnapshot, ConsumableUse, SlotAssignment)

OUT = (Path(__file__).resolve().parents[3]
       / "godot" / "tests" / "fixtures" / "equipment_snapshot.json")

SEED = "EQUIPFIXTURE"
PLAYER = "Pepsi"


def _interp(seq: int, name: str, item: str, game: str, recipient: str,
            description: str, concepts: list[str], mode: str,
            ops: list[dict]) -> EchoInterpretation:
    loc = 89100001 + seq
    return EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": f"echo_{loc}",
        "interpretation_seq": seq, "source_location_id": loc,
        "source_item_name": item, "source_game": game,
        "source_recipient_name": recipient, "display_name": name,
        "description": description, "concepts": concepts, "mode": mode,
        "operations": tuple(ops),
    })


def _action(cid: str, name: str, description: str, slot: str,
            primitive: dict, cooldown: float, *,
            charges: int | None = None,
            modifiers: list[dict] | None = None) -> dict:
    component = {
        "kind": "action", "component_id": cid, "display_name": name,
        "description": description, "slot": slot, "cooldown": cooldown,
        "primitive": primitive, "modifiers": modifiers or []}
    if charges is not None:
        component["charges"] = charges
    return {"op": "create", "component": component}


def _trait(cid: str, name: str, description: str, stat: str,
           multiplier: float, requires: str | None = None) -> dict:
    component = {
        "kind": "trait", "component_id": cid, "display_name": name,
        "description": description, "stat": stat,
        "multiplier": multiplier}
    if requires is not None:
        component["requires_equipped"] = requires
    return {"op": "create", "component": component}


def _resource(cid: str, name: str, description: str,
              maximum: float) -> dict:
    return {"op": "create", "component": {
        "kind": "resource", "component_id": cid, "display_name": name,
        "description": description, "max_value": maximum,
        "initial_fraction": 1.0, "regen_per_second": 0.0,
        "regen_delay": 0.0, "presentation": "bar",
        "palette_color": "violet"}}


def _upgrade(target: str, field: str, delta: float) -> dict:
    return {"op": "upgrade", "target": target, "field": field,
            "delta": delta}


def build_log(*, consumables: bool = True,
              acquired: bool = False) -> list[EchoInterpretation]:
    """The campaign's Echo log, oldest first."""
    log: list[tuple] = [
        ("Braided Lash", "Hookshot", "Ocarina of Time", "Link",
         "A cord that bites, and the grip to hold it.",
         ["lash", "reach", "grip"], "mechanical",
         [_action("act_lash", "Braided Lash",
                  "Throws a weighted cord that bites what it hits.",
                  "echo_a",
                  {"type": "projectile_damage", "damage": 14.0,
                   "speed": 30.0, "lifetime": 1.5}, 1.2),
          _trait("trait_grip", "Sure Grip",
                 "Your footing is surer.", "move_speed", 1.1)]),
        ("Leather Grip", "Longshot", "Ocarina of Time", "Link",
         "A longer cord for the lash you already carry.",
         ["grip"], "literal",
         [_upgrade("act_lash", "damage", 4.0)]),
        ("Sprint Coil", "Pegasus Boots", "A Link to the Past", "Link",
         "A burst of speed along the ground.",
         ["speed", "boots"], "literal",
         [_action("act_dash", "Sprint Coil", "Dashes forward.",
                  "mobility", {"type": "dash", "force": 12.0}, 2.0)]),
        ("Arc Bolt", "Crossbow", "Dark Souls", "Solaire",
         "A bolt that flies straight and far.",
         ["bolt", "range"], "literal",
         [_action("act_bolt", "Arc Bolt",
                  "Fires a bolt straight down the sight line.",
                  "echo_a",
                  {"type": "hitscan_damage", "damage": 9.0, "pellets": 1,
                   "spread_degrees": 0.0, "range": 40.0}, 0.8)]),
        ("Magic Meter", "Magic Upgrade", "Ocarina of Time", "Link",
         "A reserve of green power.",
         ["magic", "green", "capacity"], "literal",
         [_resource("res_magic", "Magic Meter", "Green power, held.",
                    60.0)]),
        ("Estus Shard", "Estus Shard", "Dark Souls", "Solaire",
         "The meter holds more.",
         ["capacity", "shard"], "mechanical",
         [_upgrade("res_magic", "max_value", 40.0)]),
        ("Warding Loop", "Mirror Shield", "Ocarina of Time", "Link",
         "Steadier hands while the bolt is on your key.",
         ["ward", "mirror"], "conceptual",
         [_trait("trait_ward", "Warding Loop",
                 "Knocked about less while Arc Bolt is equipped.",
                 "knockback_resist", 1.5, requires="act_bolt")]),
        ("Scan Lens", "Lens of Truth", "Ocarina of Time", "Link",
         "Marks what hides.",
         ["sight", "truth"], "literal",
         [_action("act_lens", "Scan Lens", "Marks enemies in view.",
                  "utility",
                  {"type": "scan_mark", "range": 30.0, "duration": 8.0},
                  6.0)]),
    ]
    if consumables:
        log += [
            ("Cinder Charge", "Bomb Bag", "Ocarina of Time", "Link",
             "A fused charge you throw.",
             ["bomb", "fuse"], "literal",
             [_action("act_cinder", "Cinder Charge",
                      "A lobbed charge that bursts and sets things alight.",
                      "consumable",
                      {"type": "arc_lob", "damage": 30.0, "radius": 3.0,
                       "launch_force": 12.0, "fuse": 1.5}, 1.0,
                      charges=3,
                      modifiers=[{"type": "apply_status_on_hit",
                                  "status": "burning", "duration": 3.0,
                                  "magnitude": 0.5}])]),
            ("Frost Flask", "Ice Trap", "A Link to the Past", "Link",
             "A flask that bursts cold.",
             ["ice", "flask"], "literal",
             [_action("act_flask", "Frost Flask",
                      "A lobbed flask that bursts and slows.",
                      "consumable",
                      {"type": "arc_lob", "damage": 18.0, "radius": 4.0,
                       "launch_force": 11.0, "fuse": 1.0}, 1.0,
                      charges=2,
                      modifiers=[{"type": "apply_status_on_hit",
                                  "status": "slowed", "duration": 4.0,
                                  "magnitude": 0.4}])]),
        ]
    if acquired:
        log += [
            ("Glow Seed", "Deku Nut", "Ocarina of Time", "Link",
             "A seed that bursts in a flash.",
             ["flash", "seed"], "literal",
             [_action("act_glow", "Glow Seed",
                      "A lobbed seed that bursts and stuns.",
                      "consumable",
                      {"type": "arc_lob", "damage": 6.0, "radius": 4.0,
                       "launch_force": 10.0, "fuse": 0.6}, 1.0,
                      charges=4,
                      modifiers=[{"type": "apply_status_on_hit",
                                  "status": "stunned", "duration": 1.5,
                                  "magnitude": 1.0}])]),
        ]
    return [_interp(seq, *row) for seq, row in enumerate(log)]


def _snapshot(log: list[EchoInterpretation], slots: dict,
              spent: dict[str, int], generation: int) -> dict:
    mechanics = M.derive_mechanics(log)
    snap = CampaignSnapshot(
        bridge_connected=True, ap_connected=True, ap_mode="mock",
        epsilon_provider="mock",
        hub={"mode": "ZONE_AVAILABLE", "headline": "A Zone is ready."},
        seed_name=SEED, slot_name=PLAYER,
        interpretations=tuple(log), interpretation_count=len(log),
        mechanics=mechanics,
        slots=SlotAssignment(**slots),
        consumable_uses=tuple(ConsumableUse(component_id=c, spent=n)
                              for c, n in sorted(spent.items()) if n > 0),
        consumable_generation=generation,
    )
    return json.loads(snap.model_dump_json())


BASE_SLOTS = {"echo_a": "act_lash", "mobility": "act_dash",
              "consumable": "act_cinder"}


def build_variants() -> dict[str, dict]:
    full = build_log()
    return {
        "base": _snapshot(full, BASE_SLOTS, {"act_cinder": 1}, 1),
        "exhausted": _snapshot(full, BASE_SLOTS, {"act_cinder": 3}, 1),
        "unequipped": _snapshot(
            full, {k: v for k, v in BASE_SLOTS.items()
                   if k != "consumable"}, {"act_cinder": 1}, 1),
        "none_owned": _snapshot(
            build_log(consumables=False),
            {k: v for k, v in BASE_SLOTS.items() if k != "consumable"},
            {}, 1),
        "acquired": _snapshot(build_log(acquired=True), BASE_SLOTS,
                              {"act_cinder": 1}, 1),
        "swapped": _snapshot(full, {**BASE_SLOTS, "echo_a": "act_bolt"},
                             {"act_cinder": 1}, 1),
        "spent_spare": _snapshot(
            full, {**BASE_SLOTS, "consumable": "act_flask"},
            {"act_cinder": 3}, 1),
    }


def render() -> str:
    return json.dumps(build_variants(), indent=1, sort_keys=True) + "\n"


def main() -> None:
    OUT.write_text(render(), encoding="utf-8")
    print(f"wrote {OUT} ({len(build_variants())} variants)")


if __name__ == "__main__":
    main()
