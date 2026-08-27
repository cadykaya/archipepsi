"""Provider protocol and the validate → repair-once → fallback pipeline.

TECHNICAL_ARCHITECTURE §10.1:
    call (60s timeout) → parse → semantic validation → ONE repair carrying
    the concise errors → re-validate → deterministic fallback.
    On provider error or timeout: skip repair, use fallback.
    Reject and repair; never silently clamp.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Protocol

from pydantic import TypeAdapter, ValidationError

from ..schemas import constants as C
from ..schemas.echo import EchoInterpretation, validate_interpretation
from ..schemas.zone import Zone, validate_zone
from . import capabilities as CAP
from .fallback import fallback_echo, fallback_zone
from .requests import EchoGenerationRequest, ZoneGenerationRequest

log = logging.getLogger("archipepsi.epsilon")

_ZONE_ADAPTER = TypeAdapter(Zone)
_ECHO_ADAPTER = TypeAdapter(EchoInterpretation)


class EpsilonProvider(Protocol):
    name: str

    async def generate_zone(self, request: ZoneGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict: ...

    async def generate_echo(self, request: EchoGenerationRequest, *,
                            repair_errors: list[str] | None = None) -> dict: ...


@dataclass
class GenerationOutcome:
    value: object                      # validated Zone or Echo
    used_fallback: bool
    error: str | None = None           # last provider/validation error, if any
    archive: dict = field(default_factory=dict)


def _concise_validation_errors(exc: ValidationError) -> list[str]:
    out = []
    for err in exc.errors():
        loc = ".".join(str(part) for part in err["loc"])
        out.append(f"{loc or '<root>'}: {err['msg']}")
    return out[:12]


def _archive_write(archive_dir: Path | None, kind: str, generation_id: str,
                   payload: dict) -> None:
    """Generation archive (§13.1): benchmark cases for a future local Epsilon."""
    if archive_dir is None:
        return
    try:
        archive_dir.mkdir(parents=True, exist_ok=True)
        safe_id = "".join(c if c.isalnum() or c in "-_" else "_"
                          for c in generation_id)[:80]
        path = archive_dir / f"{int(time.time())}_{kind}_{safe_id}.json"
        path.write_text(json.dumps(payload, indent=2, default=str))
    except OSError:
        log.exception("generation archive write failed (non-fatal)")


async def _pipeline(provider: EpsilonProvider, request, *, kind: str,
                    generation_id: str, adapter: TypeAdapter,
                    semantic, build_fallback, archive_dir: Path | None,
                    timeout: float = C.PROVIDER_TIMEOUT_SECONDS,
                    ) -> GenerationOutcome:
    archive: dict = {"kind": kind, "generation_id": generation_id,
                     "provider": provider.name,
                     "request": request.model_dump(mode="json")}

    async def call(repair_errors: list[str] | None):
        method = getattr(provider, f"generate_{kind}")
        return await asyncio.wait_for(
            method(request, repair_errors=repair_errors), timeout)

    def check(raw: dict) -> tuple[object | None, list[str]]:
        try:
            value = adapter.validate_python(raw)
        except ValidationError as exc:
            return None, _concise_validation_errors(exc)
        errors = semantic(value)
        return (value, errors) if not errors else (None, errors)

    last_error: str | None = None
    raw: dict | None = None
    try:
        raw = await call(None)
        archive["raw_output"] = raw
    except Exception as exc:                     # error/timeout: no repair
        last_error = f"provider error: {type(exc).__name__}: {exc}"
        log.warning("%s generation failed (%s); using fallback",
                    kind, last_error)

    if raw is not None:
        value, errors = check(raw)
        if value is not None:
            archive["accepted_output"] = raw
            archive["used_fallback"] = False
            _archive_write(archive_dir, kind, generation_id, archive)
            return GenerationOutcome(value, used_fallback=False,
                                     archive=archive)
        archive["validation_errors"] = errors
        last_error = "; ".join(errors)
        log.warning("%s generation invalid (%s); attempting one repair",
                    kind, last_error)
        try:
            repaired = await call(errors)
            archive["repaired_output"] = repaired
            value, errors2 = check(repaired)
            if value is not None:
                archive["accepted_output"] = repaired
                archive["used_fallback"] = False
                _archive_write(archive_dir, kind, generation_id, archive)
                return GenerationOutcome(value, used_fallback=False,
                                         archive=archive)
            archive["repair_validation_errors"] = errors2
            last_error = "; ".join(errors2)
        except Exception as exc:
            last_error = f"repair error: {type(exc).__name__}: {exc}"
        log.warning("%s repair failed (%s); using fallback", kind, last_error)

    fallback_raw = build_fallback(request)
    value, errors = check(fallback_raw)
    if value is None:                            # a bug in our own generator
        raise RuntimeError(
            f"fallback {kind} generator produced invalid output: {errors}")
    archive["accepted_output"] = fallback_raw
    archive["used_fallback"] = True
    _archive_write(archive_dir, kind, generation_id, archive)
    return GenerationOutcome(value, used_fallback=True, error=last_error,
                             archive=archive)


async def generate_zone_validated(
        provider: EpsilonProvider, request: ZoneGenerationRequest, *,
        allocated_location_ids: list[int], owned_echo_ids: list[str],
        archive_dir: Path | None = None,
        timeout: float = C.PROVIDER_TIMEOUT_SECONDS) -> GenerationOutcome:
    return await _pipeline(
        provider, request, kind="zone", generation_id=request.generation_id,
        adapter=_ZONE_ADAPTER,
        semantic=lambda z: validate_zone(
            z, expected_zone_id=request.zone_id,
            allocated_location_ids=allocated_location_ids,
            owned_echo_ids=owned_echo_ids),
        build_fallback=fallback_zone, archive_dir=archive_dir,
        timeout=timeout)


async def generate_echo_validated(
        provider: EpsilonProvider, request: EchoGenerationRequest, *,
        archive_dir: Path | None = None,
        timeout: float = C.PROVIDER_TIMEOUT_SECONDS) -> GenerationOutcome:
    return await _pipeline(
        provider, request, kind="echo",
        generation_id=request.required_echo_id, adapter=_ECHO_ADAPTER,
        semantic=lambda e: (
            validate_interpretation(
                e, expected_source_location_id=request.source.location_id)
            + CAP.validate_stage_support(e)
        ),
        build_fallback=fallback_echo, archive_dir=archive_dir,
        timeout=timeout)
