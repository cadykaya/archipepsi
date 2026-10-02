"""Put a consumable Action into an existing campaign save.

**Why this exists.** `make godot-consumable-live` drives one charge from
a real keypress in Godot, through the real socket, to a real
`spend_charge` on a real `CampaignSave` -- and the question it answers is
"how many activations did the SAVE authorise", which no amount of client
bookkeeping can answer by itself. To ask it the campaign has to own a
consumable, and the fallback provider does not emit one yet: the slot is
staged, `IMPLEMENTED_ACTION_SLOTS` does not advertise `consumable`, and
nothing in a mock campaign will hand one over.

**It is not a back door into the protocol.** The consumable arrives the
only way any Echo arrives -- one more entry in the interpretation log,
appended through the real `EchoInterpretation` model and written by the
real `store.write_save`. What the bridge loads afterwards is an ordinary
save, folded by the ordinary `derive()`, spent through the ordinary
transition. No new intent, no test-only field, and nothing here runs in a
shipped path.

**It is a DEVELOPMENT tool** and lives in `tools/` with the other ones
for that reason. It edits a save file on disk, so it refuses to touch a
directory holding more than one campaign rather than guessing which.

    python tools/give_consumable.py <save-dir> [--charges 3] [--cooldown 1.0]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from archipepsi_bridge import store
from archipepsi_bridge.schemas import protocol as P

#: The id the live driver presses for. Domain-derived like every other
#: component id, and stable so both ends can name the same thing.
COMPONENT_ID = "act_live_charge"
ECHO_ID = "echo_89100001"
SOURCE_LOCATION = 89100001


def interpretation(seq: int, charges: int, cooldown: float) -> dict:
    """One Echo whose single operation creates the consumable.

    `hitscan_damage` rather than something exotic: the point of the live
    sequence is the expenditure, and a primitive the runtime already
    implements keeps the effect from being the thing under test.
    """
    return {
        "schema_version": 8,
        "echo_id": ECHO_ID,
        "interpretation_seq": seq,
        "source_location_id": SOURCE_LOCATION,
        "source_item_name": "Throwing Charge",
        "source_game": "Archipepsi",
        "source_recipient_name": "Skyiah",
        "display_name": "Throwing Charge",
        "description": "It runs out. That is the whole point of it.",
        "concepts": ["blast"],
        "mode": "literal",
        "operations": [{
            "op": "create",
            "component": {
                "kind": "action",
                "component_id": COMPONENT_ID,
                "display_name": "THROWING CHARGE",
                "description": "Spends one of a countable supply.",
                "slot": "consumable",
                "cooldown": cooldown,
                "charges": charges,
                "primitive": {"type": "hitscan_damage", "damage": 8.0,
                              "pellets": 1, "spread_degrees": 1.0,
                              "range": 35.0},
            },
        }],
    }


def only_save(save_dir: Path) -> Path:
    saves = sorted(p for p in save_dir.glob("*.json")
                   if not p.name.endswith((".bak", ".tmp")))
    if not saves:
        raise SystemExit(f"no campaign save in {save_dir}")
    if len(saves) > 1:
        raise SystemExit(
            f"{len(saves)} campaigns in {save_dir}; name one explicitly")
    return saves[0]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("save_dir", type=Path)
    ap.add_argument("--charges", type=int, default=3)
    ap.add_argument("--cooldown", type=float, default=1.0)
    args = ap.parse_args(argv)

    path = only_save(args.save_dir)
    save = store.load_save(path)
    if save is None:
        raise SystemExit(f"{path} holds no campaign")
    if save.derive().by_id(COMPONENT_ID) is not None:
        print(f"{path.name} already owns {COMPONENT_ID}")
        return 0

    seq = save.next_interpretation_seq
    grown = save.model_copy(update={
        "interpretations": save.interpretations + (
            P.EchoInterpretation.model_validate(
                interpretation(seq, args.charges, args.cooldown)),),
        "next_interpretation_seq": seq + 1,
        # EQUIPPED, because the runtime presses a SLOT and not an id.
        "slots": save.slots.model_copy(update={"consumable": COMPONENT_ID}),
    })
    # Validated as a whole, not just field by field: `CampaignSave` has
    # cross-field checks (a use cannot exceed its charges, a slot must
    # hold something owned) and a save that fails them is one the bridge
    # would refuse to load, which is a worse place to find out.
    grown = P.CampaignSave.model_validate(grown.model_dump())
    store.write_save(path, grown)
    print(f"{path.name}: {COMPONENT_ID} owned and equipped, "
          f"{grown.charges_left(COMPONENT_ID)} charges, "
          f"supply generation {grown.consumable_generation}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
