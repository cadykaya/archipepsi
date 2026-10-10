"""Replay the generation archive against the current schemas.

    python -m archipepsi_bridge.replay_archive [archive_dir]

`EPSILON_SPEC` §14 says archived generations become "benchmark cases,
prompt regression tests, and evidence of how much intelligence a local
Epsilon actually needs" — and that a local model succeeds when it
satisfies the *same* contracts. Nothing read the archive until now.

This replays every archived generation through the exact validators the
live path uses (structural parse plus `validate_zone` /
`validate_interpretation`
against the recorded request) and reports:

* whether each accepted output still validates — a red line means the
  schemas moved under the archive, which is the regression that would
  silently invalidate the whole benchmark corpus;
* how often the live provider needed a repair or fell back, which is the
  actual measurement of how hard the task is for a given model.

Exits non-zero if any accepted output fails to re-validate.
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

from pydantic import TypeAdapter, ValidationError

from .epsilon.requests import EchoGenerationRequest, ZoneGenerationRequest
from .schemas import migration as MG
from .schemas.echo import EchoInterpretation, validate_interpretation
from .schemas.zone import Zone, validate_zone

_ZONE = TypeAdapter(Zone)
_ECHO = TypeAdapter(EchoInterpretation)


def _upgrade_echo_request(data: dict) -> dict:
    """Accept a v7 archived request against the v8 model.

    The archive is a benchmark corpus: a schema bump that silently
    invalidated every generation recorded before it would throw away the
    only evidence of how Epsilon actually behaves. Only the parts a
    validator uses are carried across — `source`, `required_echo_id`, and
    who owned what. `allowed` and `composition_rules` are prompt
    scaffolding, and replaying them verbatim would re-check the OLD rules
    rather than today's.
    """
    if data.get("schema_version") == 8:
        return data
    out = {k: v for k, v in data.items()
           if k in ("source", "required_echo_id")}
    state = dict(data.get("player_state") or {})
    upgraded = []
    for summary in state.get("existing_echoes", ()):
        kinds = ("trait",) if summary.get("activation") == "passive" \
            else ("action",)
        upgraded.append({
            "echo_id": summary["echo_id"],
            "display_name": summary["display_name"],
            "kinds": kinds,
            "tags": tuple(summary.get("tags", ())),
            "description": summary["description"],
        })
    state["existing_echoes"] = tuple(upgraded)
    out["player_state"] = state
    return out


def _upgrade_echo_output(accepted: dict) -> dict:
    """Accept a v7 archived Echo as the v8 interpretation it migrates to.

    The same function the save migration uses, so an archived v7 Echo and a
    migrated v7 save produce the same component — one conversion, not two
    that can disagree.
    """
    if accepted.get("schema_version") == 8:
        return accepted
    return MG.migrate_echo_v7_to_v8(accepted, seq=0)


def replay_one(record: dict) -> tuple[bool, str]:
    """Re-validate one archived generation. Returns (ok, detail)."""
    kind = record.get("kind")
    accepted = record.get("accepted_output")
    if accepted is None:
        return True, "no accepted output (generation failed outright)"
    try:
        if kind == "zone":
            request = ZoneGenerationRequest.model_validate(record["request"])
            zone = _ZONE.validate_python(accepted)
            errors = validate_zone(
                zone, expected_zone_id=request.zone_id,
                allocated_location_ids=[l.location_id
                                        for l in request.locations],
                owned_echo_ids=[e.echo_id for e in request.player.echoes])
        elif kind == "echo":
            request = EchoGenerationRequest.model_validate(
                _upgrade_echo_request(record["request"]))
            echo = _ECHO.validate_python(_upgrade_echo_output(accepted))
            errors = validate_interpretation(
                echo, expected_source_location_id=request.source.location_id)
        else:
            return False, f"unknown archive kind {kind!r}"
    except ValidationError as exc:
        first = exc.errors()[0]
        return False, "structural: {}: {}".format(
            ".".join(str(p) for p in first["loc"]) or "<root>", first["msg"])
    if errors:
        return False, "semantic: " + "; ".join(errors)
    return True, "ok"


def main() -> None:
    archive_dir = Path(sys.argv[1] if len(sys.argv) > 1
                       else "generation_archive")
    if not archive_dir.is_dir():
        print(f"no archive at {archive_dir} — run the bridge with "
              f"--archive-dir {archive_dir} to collect one")
        raise SystemExit(0)

    records = sorted(archive_dir.glob("*.json"))
    if not records:
        print(f"archive {archive_dir} is empty")
        raise SystemExit(0)

    failures: list[tuple[str, str]] = []
    providers: Counter[str] = Counter()
    kinds: Counter[str] = Counter()
    repaired = fell_back = 0

    for path in records:
        try:
            record = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError) as exc:
            failures.append((path.name, f"unreadable: {exc}"))
            continue
        kinds[str(record.get("kind"))] += 1
        providers[str(record.get("provider"))] += 1
        if record.get("repaired_output") is not None:
            repaired += 1
        if record.get("used_fallback"):
            fell_back += 1
        ok, detail = replay_one(record)
        if not ok:
            failures.append((path.name, detail))

    total = len(records)
    print(f"archive: {archive_dir}  ({total} generations)")
    print("  kinds:     " + ", ".join(f"{k}={v}" for k, v in kinds.items()))
    print("  providers: " + ", ".join(f"{k}={v}"
                                      for k, v in providers.items()))
    model_attempts = total - fell_back
    print(f"  needed a repair:  {repaired}/{total}")
    print(f"  fell back:        {fell_back}/{total}")
    if model_attempts:
        first_try = model_attempts - repaired
        print(f"  first-try accept: {first_try}/{model_attempts} "
              f"({100.0 * first_try / model_attempts:.0f}% of live outputs)")

    if failures:
        print(f"\n{len(failures)} archived generation(s) NO LONGER VALIDATE "
              "against the current schemas:")
        for name, detail in failures[:20]:
            print(f"  {name}: {detail}")
        if len(failures) > 20:
            print(f"  … and {len(failures) - 20} more")
        raise SystemExit(1)
    print("\nevery archived generation still validates against the current "
          "schemas.")


if __name__ == "__main__":
    main()
