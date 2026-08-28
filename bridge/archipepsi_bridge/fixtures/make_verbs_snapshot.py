"""Generate `godot/tests/fixtures/verbs_snapshot.json` from a real fold.

The companion of `make_rules_snapshot.py`, for the S2/S5 action runner
rather than the rule engine. Four slots, each holding a verb whose press
and release lifecycle had a hole in it: a charge that fired from a key-up
with no press behind it, a blink whose refusal kept the cost and paid the
`fills` link anyway, a hover left running past the slot swap that should
have ended it, and a beam that kept draining after the player died.

Run with `make verbs-fixture`. The log below is the source; the JSON is
not to be edited.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from archipepsi_bridge.schemas import mechanics as M          # noqa: E402
from archipepsi_bridge.schemas.echo import EchoInterpretation  # noqa: E402

OUT = (Path(__file__).resolve().parents[3]
       / "godot" / "tests" / "fixtures" / "verbs_snapshot.json")


def _interp(seq: int, ops: list[dict]) -> EchoInterpretation:
    loc = 89100011 + seq
    return EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": f"echo_{loc}",
        "interpretation_seq": seq, "source_location_id": loc,
        "source_item_name": "Item", "source_game": "Some Game",
        "source_recipient_name": "Somebody", "display_name": "Thing",
        "description": "It does a thing.", "operations": tuple(ops),
    })


def _resource(cid: str, name: str, maximum: float = 100.0,
              regen: float = 0.0, delay: float = 0.0) -> dict:
    return {"op": "create", "component": {
        "kind": "resource", "component_id": cid, "display_name": name,
        "description": "x", "max_value": maximum, "initial_fraction": 1.0,
        "regen_per_second": regen, "regen_delay": delay,
        "presentation": "bar", "palette_color": "tide"}}


def _action(cid: str, name: str, slot: str, primitive: dict,
            cooldown: float = 5.0) -> dict:
    return {"op": "create", "component": {
        "kind": "action", "component_id": cid, "display_name": name,
        "description": "x", "slot": slot, "cooldown": cooldown,
        "primitive": primitive}}


def _link(kind: str, source: str, target: str, strength: float) -> dict:
    return {"op": "link", "link": kind, "source": source, "target": target,
            "strength": strength}


def build_log() -> list[EchoInterpretation]:
    ops: list[list[dict]] = [
        [_resource("res_fuel", "Fuel"),
         _resource("res_spark", "Spark")],
        # A long cooldown throughout: every test here is about whether a
        # press was charged for, and five seconds makes that unambiguous.
        [_action("act_blink", "Blink", "echo_a",
                 {"type": "blink", "range": 12.0})],
        [_action("act_charge", "Charge", "echo_b",
                 {"type": "charge_shot", "min_damage": 2.0,
                  "max_damage": 30.0, "charge_time": 1.0, "speed": 40.0})],
        [_action("act_hover", "Hover", "mobility",
                 {"type": "hover", "gravity_multiplier": 0.2,
                  "drain_per_second": 5.0, "max_duration": 8.0})],
        [_action("act_beam", "Beam", "utility",
                 {"type": "beam_sustained", "damage_per_second": 10.0,
                  "range": 20.0, "drain_per_second": 10.0})],
        # The blink costs 20 a press and fills 15 on a use that resolved:
        # a refused press that kept the cost AND paid the fill was net
        # generation, refunded cooldown and all.
        [_link("powers", "res_fuel", "act_blink", 20.0),
         _link("fills", "act_blink", "res_spark", 15.0)],
        [_link("powers", "res_fuel", "act_hover", 5.0),
         _link("powers", "res_fuel", "act_beam", 10.0)],
        [_link("powers", "res_spark", "act_charge", 10.0)],
    ]
    return [_interp(seq, o) for seq, o in enumerate(ops)]


def main() -> None:
    mechanics = M.derive_mechanics(build_log())
    snapshot = {
        "type": "campaign_snapshot",
        "interpretations": [],
        "mechanics": mechanics.model_dump(mode="json"),
        "slots": {"echo_a": "act_blink", "echo_b": "act_charge",
                  "mobility": "act_hover", "utility": "act_beam"},
    }
    OUT.write_text(json.dumps(snapshot, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {OUT} ({len(mechanics.owned)} components)")


if __name__ == "__main__":
    main()
