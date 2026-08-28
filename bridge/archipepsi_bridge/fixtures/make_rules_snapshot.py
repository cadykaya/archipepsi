"""Generate `godot/tests/fixtures/rules_snapshot.json` from a real fold.

The rule suite claims its fixture is "a REAL fold on the Python side", and
that claim is the point: a hand-written snapshot would let the GDScript
interpreter be tested against a shape the bridge cannot actually produce.
It was true and unverifiable — the generator was scratch tooling and did
not survive, leaving a generated artifact in the tree with no source.

Run with `make rules-fixture`. The log below is the source; the JSON is
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
       / "godot" / "tests" / "fixtures" / "rules_snapshot.json")


def _interp(seq: int, ops: list[dict]) -> EchoInterpretation:
    loc = 89100001 + seq
    return EchoInterpretation.model_validate({
        "schema_version": 8, "echo_id": f"echo_{loc}",
        "interpretation_seq": seq, "source_location_id": loc,
        "source_item_name": "Item", "source_game": "Some Game",
        "source_recipient_name": "Somebody", "display_name": "Thing",
        "description": "It does a thing.", "operations": tuple(ops),
    })


def _resource(cid: str, name: str, maximum: float, fraction: float,
              regen: float = 0.0, delay: float = 0.0) -> dict:
    return {"op": "create", "component": {
        "kind": "resource", "component_id": cid, "display_name": name,
        "description": "x", "max_value": maximum,
        "initial_fraction": fraction, "regen_per_second": regen,
        "regen_delay": delay, "presentation": "bar",
        "palette_color": "tide"}}


def _rule(cid: str, event: str, effects: list[dict], *,
          conditions: list[dict] | None = None,
          costs: list[dict] | None = None, cooldown: float = 0.1) -> dict:
    return {"op": "create", "component": {
        "kind": "rule", "component_id": cid, "display_name": cid,
        "description": "x", "event": event, "cooldown": cooldown,
        "conditions": conditions or [], "costs": costs or [],
        "effects": effects}}


def _heal(amount: float) -> dict:
    return {"type": "heal", "amount": amount}


def _add(subject: str, amount: float) -> dict:
    return {"type": "resource_add", "subject": subject, "amount": amount}


def build_log() -> list[EchoInterpretation]:
    """Two resources and a merge whose alias a rule cost still references,
    plus one channel that actually regenerates.

    The regenerating channel is what makes the failed-payment tests mean
    anything: `spend` arms `regen_delay` and the old refund path did not
    disarm it, which is invisible on a channel whose regen is zero.
    """
    ops: list[list[dict]] = [
        # A merge, so `res_old` is a permanent alias for `res_battery` and
        # the interpreter has to resolve it in a rule cost.
        [_resource("res_battery", "Battery", 100.0, 0.5),
         _resource("res_old", "Old Cell", 30.0, 1.0)],
        [{"op": "merge", "absorbed": "res_old", "survivor": "res_battery",
          "capacity": "sum"}],
        [_resource("res_osc", "Osc", 40.0, 1.0)],
        # 25/s from empty with a 5 s delay: a single lost delay window is
        # 125 units of regeneration, which no rounding can hide.
        [_resource("res_bat2", "Cell", 100.0, 1.0, regen=25.0, delay=5.0)],

        [_rule("rule_charge", "check_claimed", [_add("res_battery", 100.0)])],
        [_rule("rule_on_full", "resource_full", [_heal(5.0)])],
        [_rule("rule_fill_on_empty", "resource_empty",
               [{"type": "refill_resource", "subject": "res_osc"}])],
        [_rule("rule_drain_on_full", "resource_full",
               [_add("res_osc", -200.0)],
               conditions=[{"type": "resource_at_least", "subject": "res_osc",
                            "value": 0.999}])],
        [_rule("rule_landing_tax", "land", [_heal(2.0)],
               costs=[{"resource_id": "res_battery", "amount": 30.0}])],
        [_rule("rule_dash_reward", "dash_end",
               [{"type": "impulse_self", "amount": 3.0, "direction": "up"}],
               conditions=[
                   {"type": "resource_at_least", "subject": "res_battery",
                    "value": 0.5},
                   {"type": "grounded"}])],
        [_rule("rule_slow_jump", "jump", [_heal(1.0)], cooldown=0.5)],
        [_rule("rule_low", "low_health",
               [{"type": "grant_shield", "amount": 10.0, "duration": 4.0}])],
        # The cost names the ABSORBED id on purpose.
        [_rule("rule_old_cost", "parry_success", [_heal(1.0)],
               costs=[{"resource_id": "res_old", "amount": 10.0}])],
        [_rule("rule_double_cost", "chamber_enter", [_heal(3.0)],
               costs=[{"resource_id": "res_battery", "amount": 15.0},
                      {"resource_id": "res_osc", "amount": 15.0}])],
        # The same shape against the regenerating channel: cheap first
        # cost, impossible second. Every attempt used to re-arm the delay.
        [_rule("rule_greedy", "chamber_enter", [_heal(3.0)],
               costs=[{"resource_id": "res_bat2", "amount": 1.0},
                      {"resource_id": "res_osc", "amount": 200.0}])],
    ]
    # Ten rules on one event, against a per-tick cap of eight.
    ops += [[_rule(f"rule_cap_{i:02d}", "kill", [_heal(1.0)])]
            for i in range(10)]
    return [_interp(seq, o) for seq, o in enumerate(ops)]


def main() -> None:
    log = build_log()
    mechanics = M.derive_mechanics(log)
    snapshot = {
        "type": "campaign_snapshot",
        "interpretations": [],
        "mechanics": mechanics.model_dump(mode="json"),
        "slots": {"echo_a": None, "echo_b": None, "mobility": None,
                  "utility": None},
    }
    OUT.write_text(json.dumps(snapshot, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {OUT} ({len(mechanics.owned)} components)")


if __name__ == "__main__":
    main()
