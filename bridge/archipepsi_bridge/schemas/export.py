"""Generate the derived artifacts from the Pydantic models.

    python export.py [outdir]

v0.3 listed three hand-written JSON Schema files alongside a Pydantic model
"equivalent" to an example, plus whatever Godot did defensively. Three
validators that must agree is two too many. Here Pydantic is the source and
everything else is generated:

    zone.schema.json      JSON Schema, for tooling and provider structured output
    echo.schema.json
    protocol.schema.json
    constants.gd          Godot autoload, so the engine cannot drift from
                          the numbers the validator enforces

Regenerate after any schema change; never hand-edit the outputs.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from pydantic import TypeAdapter

try:
    from . import constants as C
    from .echo import EchoInterpretation
    from .protocol import CampaignSnapshot, ClientMessage, ServerMessage
    from .zone import Zone
except ImportError:  # pragma: no cover
    import constants as C
    from echo import EchoInterpretation
    from protocol import CampaignSnapshot, ClientMessage, ServerMessage
    from zone import Zone

GD_SKIP = ("ENEMY_STATS", "TIER_BOUNDS")


def _gd_literal(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (list, tuple)):
        return "[" + ", ".join(_gd_literal(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{" + ", ".join(
            f"{json.dumps(str(k))}: {_gd_literal(v)}" for k, v in value.items()
        ) + "}"
    raise TypeError(f"cannot express {type(value).__name__} in GDScript")


def export_constants_gd() -> str:
    lines = [
        "# GENERATED FILE - do not edit.",
        "# Source: schemas/constants.py. Regenerate with `python export.py`.",
        "#",
        "# Godot reads its gameplay numbers from here so the engine cannot",
        "# drift from the bounds the Python validator enforces.",
        "extends Node",
        "",
    ]
    for name in dir(C):
        if not name.isupper() or name in GD_SKIP:
            continue
        try:
            lines.append(f"const {name} = {_gd_literal(getattr(C, name))}")
        except TypeError as exc:
            # v0.4 swallowed this, so a constant could vanish from the Godot
            # side with no output - inside the mechanism whose whole purpose
            # is preventing exactly that drift.
            raise SystemExit(
                f"export: cannot express constant {name} in GDScript ({exc}). "
                "Add it to GD_SKIP deliberately, or change its type."
            ) from exc

    lines += ["", "# Tier bounds: tier N holds [TIER_BOUNDS[N], TIER_BOUNDS[N+1]).",
              f"const TIER_BOUNDS = {_gd_literal(list(C.TIER_BOUNDS))}",
              "", "# Enemy stat block, keyed by archetype.", "const ENEMY_STATS = {"]
    for archetype, stats in C.ENEMY_STATS.items():
        lines.append(f'\t"{archetype}": {_gd_literal(stats)},')
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "generated")
    out.mkdir(parents=True, exist_ok=True)

    # Direction decides the mode, and it matters. A validation-mode schema
    # omits computed fields, and v0.7 derives half of HubStatus - so Godot
    # would have been handed a snapshot contract with no `portal_enabled`,
    # `finale_offered` or `coins_available` in it, and would have had to
    # re-derive them. Re-deriving a rule on the far side of the wire is the
    # drift this file exists to prevent.
    #
    #   bridge -> Godot   serialization: what the bridge actually emits
    #   Godot  -> bridge  validation:    what the bridge accepts
    #   provider output   validation:    what Epsilon must produce
    artifacts = {
        "zone.schema.json": TypeAdapter(Zone).json_schema(),
        "echo.schema.json": TypeAdapter(EchoInterpretation).json_schema(),
        "protocol.schema.json": {
            "client_message": TypeAdapter(ClientMessage).json_schema(),
            "server_message": TypeAdapter(ServerMessage).json_schema(
                mode="serialization"),
            "campaign_snapshot": TypeAdapter(CampaignSnapshot).json_schema(
                mode="serialization"),
        },
    }
    for name, schema in artifacts.items():
        (out / name).write_text(json.dumps(schema, indent=2) + "\n")
        print(f"wrote {out / name}")

    (out / "constants.gd").write_text(export_constants_gd())
    print(f"wrote {out / 'constants.gd'}")


if __name__ == "__main__":
    main()
