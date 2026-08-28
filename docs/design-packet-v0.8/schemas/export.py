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
    from . import echo as E
    from .echo import EchoInterpretation
    from .protocol import CampaignSnapshot, ClientMessage, ServerMessage
    from .zone import Zone
except ImportError:  # pragma: no cover
    import constants as C
    import echo as E
    from echo import EchoInterpretation
    from protocol import CampaignSnapshot, ClientMessage, ServerMessage
    from zone import Zone

#: Deliberately not exported to GDScript.
#:
#: The two CampaignConfig instances are objects, but the deeper reason is
#: that Godot must not HAVE a build-time campaign scale. It consumes the
#: scale the bridge sends for the campaign actually being played
#: (CAMPAIGN_SCALE.md 2); a client quietly falling back to a baked default
#: while the campaign is 450 is a divergence, not a default. The bounds
#: and the DEFAULT_* numbers still export, because validating a received
#: value against the tested range is exactly what the client should do.
GD_SKIP = ("ENEMY_STATS", "TIER_BOUNDS", "DEFAULT_CONFIG",
           "PROTOTYPE_CONFIG")


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

    # The joint gap/step bound, as a FUNCTION rather than a number.
    #
    # `SAFE_BASE_JUMP_GAP` is the flat-ground case, and exporting only
    # that left every builder placing a raised platform with nothing to
    # ask. The tower's spiral was typed as a flat 2.4 m at a 1.0 m rise,
    # where the safe bound is 2.0 -- the schema enforces that same bound
    # on Epsilon's `platform_path` and the engine broke it in its own
    # geometry. A number cannot be asked a question, so this is a
    # function; `test_schemas.py` pins it against the Python original
    # across the whole legal step range.
    lines += [
        "",
        "## Largest gap a MANDATORY jump may span, landing this much",
        "## higher. The joint bound: gap and step maxed independently is",
        "## not the same as either maxed alone. Mirrors",
        "## `constants.max_safe_gap`, pinned by `test_schemas.py`.",
        "## NOT `static`: `Constants` is an autoload, so every call site "
        "reaches it",
        "## through the singleton INSTANCE. A static function called that "
        "way is",
        "## correct but warns on every one of them, and a warning nobody "
        "can act",
        "## on is a warning everybody learns to scroll past.",
        "func max_safe_gap(vertical_step: float = 0.0) -> float:",
        "\tvar g := GRAVITY * GRAVITY_MULT_MAX",
        "\tvar disc := JUMP_VELOCITY * JUMP_VELOCITY - 2.0 * g * vertical_step",
        "\tif disc < 0.0:",
        "\t\treturn 0.0",
        "\tvar reach := WALK_SPEED * SPEED_MULT_MIN \\",
        "\t\t\t* (JUMP_VELOCITY + sqrt(disc)) / g",
        "\t# Floor to one decimal: a safety bound must never round upward.",
        "\treturn floor(reach * SAFE_GAP_MARGIN * 10.0) / 10.0",
    ]

    lines += ["", "# Tier bounds: tier N holds [TIER_BOUNDS[N], TIER_BOUNDS[N+1]).",
              f"const TIER_BOUNDS = {_gd_literal(list(C.TIER_BOUNDS))}",
              "", "# Enemy stat block, keyed by archetype.", "const ENEMY_STATS = {"]
    for archetype, stats in C.ENEMY_STATS.items():
        lines.append(f'\t"{archetype}": {_gd_literal(stats)},')
    lines.append("}")

    # The Action catalog, so the GDScript runner can be checked against the
    # contract instead of being trusted to match it. `chamber_tests.gd`
    # asserts the runner handles exactly ECHO_IMPLEMENTED_PRIMITIVES: a verb
    # the schema admits but the engine forgot is a live Echo that does
    # nothing when you press the key, and that is precisely the failure
    # IMPLEMENTED_PRIMITIVES exists to prevent -- it just cannot see across
    # the language boundary on its own.
    lines += [
        "",
        "# The closed Action catalog (all 28), in catalog order.",
        f"const ECHO_ACTION_PRIMITIVES = {_gd_literal(list(E.ACTION_PRIMITIVES))}",
        "",
        "# The subset this engine must be able to execute today.",
        "const ECHO_IMPLEMENTED_PRIMITIVES = "
        f"{_gd_literal(list(E.IMPLEMENTED_PRIMITIVES))}",
        "",
        "# Held back by a stage, with the stage that lands each one.",
        f"const ECHO_DEFERRED_PRIMITIVES = {_gd_literal(dict(E.DEFERRED_PRIMITIVES))}",
        "",
        "# The closed status vocabulary, so `StatusEffects.apply` can refuse",
        "# a kind the schema does not admit. An unknown kind is inert --",
        "# nothing reads it -- while still satisfying `status_active`",
        "# conditions and `status_applied` edges, and `cleanse` can never",
        "# remove it, because it is not in the cleanse order.",
        f"const ECHO_STATUS_KINDS = {_gd_literal(list(E.STATUS_KINDS))}",
    ]
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
