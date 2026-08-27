"""Archipepsi — save migration.

v7 -> v8 is the only migration that exists, and it runs at the **dict**
level, before validation, rather than by keeping a second tree of v7 models
alive. Two reasons:

- A v7 save's shape is known and small. Converting it as JSON is a few dozen
  lines; maintaining `CampaignSave_v7`, `Echo_v7`, `PrimaryEcho_v7` and
  friends forever is not.
- The output is validated as a v8 save like any other. A migration that
  produced something the v8 models reject is a migration that failed, and it
  fails loudly at the point of load rather than at the point of use.

The one thing this must get right is ordering. `interpretation_seq` is
assigned in the v7 save's own echo order, which IS grant order — `add_echo`
appended — so a migrated campaign folds exactly as it played.
"""

from __future__ import annotations

from typing import Any

try:
    from . import echo as E
except ImportError:  # pragma: no cover
    import echo as E

#: v7 archetypes mapped onto v8 slots. Public because the fallback provider
#: uses the same mapping: a v7 save migrated and a fresh fallback for the
#: same location then produce the same component id, which is one less way
#: for two paths to disagree. A weapon or tool goes to the primary
#: Echo slot because that is where RMB was; mobility gets the slot it was
#: always really asking for.
ARCHETYPE_SLOT = {
    "weapon": "echo_a",
    "tool": "echo_a",
    "mobility": "mobility",
    "passive": "echo_a",
}

#: v7 passive effects, as v8 trait stats.
PASSIVE_STAT = {"modify_gravity": "gravity", "modify_speed": "move_speed"}


def component_id_for(prefix: str, location_id: int, suffix: str = "") -> str:
    tail = f"_{suffix}" if suffix else ""
    return f"{prefix}_l{location_id}{tail}"


def migrate_echo_v7_to_v8(entry: dict[str, Any], seq: int) -> dict[str, Any]:
    """One v7 Echo becomes one v8 interpretation with CREATE operations."""
    location_id = entry["source_location_id"]
    common = {
        "schema_version": 8,
        "echo_id": entry["echo_id"],
        "interpretation_seq": seq,
        "source_location_id": location_id,
        "source_item_name": entry["source_item_name"],
        "source_game": entry["source_game"],
        "source_recipient_name": entry["source_recipient_name"],
        "concepts": (),
        # A v7 Echo was a direct reading of the item, with no concept step
        # and no choice of mode. Saying so is more honest than inventing a
        # richer interpretation the player never actually received.
        "mode": "literal",
        "display_name": entry["display_name"],
        "description": entry["description"],
        "tags": tuple(entry.get("tags", ())),
    }

    if entry["activation"] == "primary":
        slot = ARCHETYPE_SLOT.get(entry.get("archetype", "weapon"), "echo_a")
        return {**common, "operations": ({
            "op": "create",
            "component": {
                "kind": "action",
                "component_id": component_id_for("act", location_id),
                "display_name": entry["display_name"],
                "description": entry["description"],
                "slot": slot,
                "cooldown": entry["cooldown"],
                "primitive": dict(entry["initiator"]),
                "modifiers": tuple(dict(m) for m in entry.get("modifiers", ())),
            },
        },)}

    operations = []
    for index, effect in enumerate(entry["effects"]):
        operations.append({
            "op": "create",
            "component": {
                "kind": "trait",
                "component_id": component_id_for("trait", location_id, str(index)),
                "display_name": entry["display_name"],
                "description": entry["description"],
                "stat": PASSIVE_STAT[effect["type"]],
                "multiplier": effect["multiplier"],
            },
        })
    return {**common, "operations": tuple(operations)}


def migrate_v7_to_v8(data: dict[str, Any]) -> dict[str, Any]:
    """Pure and total on a valid v7 save. Returns a v8 save dict.

    A v7 save with no echoes migrates to a v8 save with an empty log, which
    is exactly right: nothing was earned, so nothing folds.
    """
    if data.get("schema_version") == 8:
        return data
    if data.get("schema_version") != 7:
        raise ValueError(
            f"cannot migrate a save at schema_version "
            f"{data.get('schema_version')!r}; only 7 -> 8 exists"
        )

    out = {k: v for k, v in data.items()
           if k not in ("echoes", "equipped_echo_id", "schema_version")}
    out["schema_version"] = 8

    echoes = list(data.get("echoes", ()))
    interpretations = [
        migrate_echo_v7_to_v8(entry, seq) for seq, entry in enumerate(echoes)
    ]
    out["interpretations"] = tuple(interpretations)
    out["next_interpretation_seq"] = len(interpretations)

    equipped = data.get("equipped_echo_id")
    slots: dict[str, str | None] = {
        "echo_a": None, "echo_b": None, "mobility": None, "utility": None,
    }
    if equipped is not None:
        source = next(
            (e for e in echoes if e["echo_id"] == equipped), None
        )
        # A passive Echo contributed traits, and traits are always on, so
        # there is nothing to slot. That is not a loss: the v7 player had
        # its effect while it was equipped, and the v8 player has it always.
        if source is not None and source["activation"] == "primary":
            slot = ARCHETYPE_SLOT.get(source.get("archetype", "weapon"),
                                       "echo_a")
            slots[slot] = component_id_for("act", source["source_location_id"])
    out["slots"] = slots
    return out


def migrate_save_dict(data: dict[str, Any]) -> dict[str, Any]:
    """Bring any supported save version up to current."""
    version = data.get("schema_version")
    if version == E.SCHEMA_VERSION:
        return data
    if version == 7:
        return migrate_v7_to_v8(data)
    raise ValueError(f"unsupported save schema_version {version!r}")
