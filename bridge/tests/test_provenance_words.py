"""A provenance note is words a player reads, not an identifier.

The equipment wall's HISTORY prints each Mk's note after it: "Mk II +40
max_value ← Estus Shard" put a raw field name in front of the player, and
the wall's font has no underscore, so it drew "MAX?VALUE". The owner's
MENU-INT instruction is to fix raw field names at their source, and the
source is the fold's note (Prod's N-21 to Dess records the change).
"""

from __future__ import annotations

from pydantic import TypeAdapter

from archipepsi_bridge.schemas import mechanics as M
from archipepsi_bridge.schemas.echo import (
    MODIFIER_TYPES, UPGRADABLE_FIELDS, EchoInterpretation)

EchoAdapter = TypeAdapter(EchoInterpretation)


def _interp(seq, ops):
    loc = 89100001 + seq
    return EchoAdapter.validate_python({
        "schema_version": 8, "echo_id": f"echo_{loc}",
        "interpretation_seq": seq, "source_location_id": loc,
        "source_item_name": "Item", "source_game": "Some Game",
        "source_recipient_name": "Somebody", "display_name": "Thing",
        "description": "It does a thing.", "operations": tuple(ops)})


def test_every_upgradable_field_and_modifier_is_said_in_words():
    names = {f for fields in UPGRADABLE_FIELDS.values() for f in fields}
    names |= set(MODIFIER_TYPES)
    for name in sorted(names):
        said = M.note_words(name)
        assert said and "_" not in said, (name, said)


def test_the_fold_writes_the_words():
    mechanics = M.derive_mechanics([
        _interp(0, [
            {"op": "create", "component": {
                "kind": "resource", "component_id": "res_mp",
                "display_name": "MP", "description": "Magic.",
                "max_value": 100.0, "initial_fraction": 1.0,
                "presentation": "bar", "palette_color": "moss"}},
            {"op": "create", "component": {
                "kind": "action", "component_id": "act_gun",
                "display_name": "Gun", "description": "Bang.",
                "slot": "echo_a", "cooldown": 0.8,
                "primitive": {"type": "hitscan_damage", "damage": 8.0,
                              "pellets": 1, "spread_degrees": 1.0,
                              "range": 35.0}}}]),
        _interp(1, [{"op": "upgrade", "target": "res_mp",
                     "field": "max_value", "delta": 40.0}]),
        _interp(2, [{"op": "modify", "target": "act_gun",
                     "add_modifier": {"type": "knockback_target",
                                      "force": 4.0}}]),
    ])
    notes = {o.component_id: [p.note for p in o.provenance]
             for o in mechanics.owned}
    assert notes["res_mp"] == ["MP", "+40 maximum"]
    assert notes["act_gun"] == ["Gun", "knockback"]
