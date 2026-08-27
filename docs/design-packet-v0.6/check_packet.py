#!/usr/bin/env python3
"""Check the packet's PROSE against the packet's MODELS.

    python check_packet.py            # from the packet directory

The recurring defect in this design has been an invariant closed on one path
and left open on its neighbour, and the most common neighbour is prose. v0.5
fixed several rules in code and in one document, leaving the other four
documents describing the old behaviour — and then said in a changelog that the
fix had landed everywhere.

This is the mechanical answer. It does not read English; it extracts the
machine-checkable claims the documents make and validates each against
`schemas/`:

1. Every fenced ```json block parses, and any block that identifies itself as
   a Zone, an Echo, a snapshot or a client message validates against that
   model.
2. Every backticked UPPER_SNAKE identifier is a real symbol — a constant, an
   enum member, a model class or field. That shape is almost always ours, so
   a stale one (`PEPSI_KEY`, `CAMPAIGN_COMPLETE`) is drift, not English.
3. Every double-quoted enum-shaped string ("ZONE_AVAILABLE", "kill_all") is a
   real member of some enum in the schemas.
4. Retired terminology stays retired.
5. The schema test count quoted in prose matches the suite.

Anything the packet deliberately names as NOT existing goes in
`DELIBERATE_NON_MEMBERS` with the reason. Changelogs are excluded: they are
historical records of what earlier revisions said, and holding them to the
current models would force us to rewrite history.

Exit status is non-zero on any failure, so this belongs in the Makefile.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import typing
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "schemas"))

import constants as C           # noqa: E402
import echo as echo_mod         # noqa: E402
import protocol as P            # noqa: E402
import zone as zone_mod         # noqa: E402
from pydantic import BaseModel, TypeAdapter, ValidationError   # noqa: E402

DOCS = sorted(d for d in HERE.glob("*.md")
              if not d.name.startswith("CHANGELOG"))

#: Names the packet cites precisely because they do NOT exist. Each one is a
#: rule we are at risk of re-introducing, so the citation is deliberate.
DELIBERATE_NON_MEMBERS = {
    "CAMPAIGN_COMPLETE": "removed in v0.5; goaling no longer ends play",
    "FINALE_AVAILABLE": "the finale is a boolean, never a HubMode",
    "PEPSI_KEY": "renamed to Signal Key in v0.5",
    "PEPSI_POP": "renamed to Static Pulse in v0.5",
}

#: Retired words that must not reappear anywhere in the packet.
BANNED_TERMS = {
    "Pepsi Key": "renamed to Signal Key",
    "Pepsi Pop": "renamed to Static Pulse",
    "blocky": "the visual target is late-90s PC FPS brushwork",
}

failures: list[str] = []


def fail(doc, msg: str) -> None:
    failures.append(f"{getattr(doc, 'name', doc)}: {msg}")


# ---------------------------------------------------------------------------
# The union of every identifier the schemas actually define
# ---------------------------------------------------------------------------

def _models(module):
    return [obj for obj in vars(module).values()
            if isinstance(obj, type) and issubclass(obj, BaseModel)]


def _enum_members() -> set[str]:
    members: set[str] = set()
    for module in (P, zone_mod, echo_mod):
        for name, obj in vars(module).items():
            if typing.get_origin(obj) is typing.Literal:
                members |= {a for a in typing.get_args(obj) if isinstance(a, str)}
            for model in _models(module):
                for field in model.model_fields.values():
                    ann = field.annotation
                    if typing.get_origin(ann) is typing.Literal:
                        members |= {a for a in typing.get_args(ann)
                                    if isinstance(a, str)}
    return members


ENUM_MEMBERS = _enum_members() | set(C.THEMES) | set(C.CHAMBER_TYPES) \
    | set(C.ENEMY_ARCHETYPES) | set(C.OBJECTIVES)

KNOWN: set[str] = set(ENUM_MEMBERS)
KNOWN |= {n for n in dir(C) if not n.startswith("_")}
for _module in (P, zone_mod, echo_mod):
    for _model in _models(_module):
        KNOWN.add(_model.__name__)
        KNOWN |= set(_model.model_fields)
        KNOWN |= {n for n in vars(_model) if not n.startswith("__")}
    KNOWN |= {n for n in vars(_module) if not n.startswith("_")}


# ---------------------------------------------------------------------------
# 1. JSON examples
# ---------------------------------------------------------------------------

ADAPTERS = {
    "Zone": TypeAdapter(zone_mod.Zone),
    "Echo": TypeAdapter(echo_mod.Echo),
    "CampaignSnapshot": TypeAdapter(P.CampaignSnapshot),
    "ClientMessage": TypeAdapter(P.ClientMessage),
}
INTENTS = {
    typing.get_args(m.model_fields["type"].annotation)[0]
    for m in typing.get_args(typing.get_args(P.ClientMessage)[0])
}
_JSON_BLOCK = re.compile(r"```json\n(.*?)\n```", re.S)


def _classify(obj):
    """Which model an example claims to be, or None to skip it.

    Conservative on purpose: an unclassifiable block is skipped rather than
    guessed at, because false failures train the reader to ignore this script.
    """
    if not isinstance(obj, dict):
        return None
    if "chambers" in obj and "theme" in obj:
        return "Zone"
    if "echo_id" in obj and "archetype" in obj:
        return "Echo"
    if obj.get("type") == "campaign_snapshot":
        return "CampaignSnapshot"
    if obj.get("type") in INTENTS:
        return "ClientMessage"
    return None


def check_json_examples(doc: Path, text: str) -> None:
    for raw in _JSON_BLOCK.findall(text):
        if "/*" in raw or "..." in raw:
            continue                      # illustrative, not literal
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError as exc:
            fail(doc, f"json block does not parse: {exc}")
            continue
        name = _classify(obj)
        if name is None:
            continue
        try:
            ADAPTERS[name].validate_python(obj)
        except ValidationError as exc:
            first = exc.errors()[0]
            loc = ".".join(str(p) for p in first["loc"])
            fail(doc, f"{name} example invalid at {loc}: {first['msg']}")


# ---------------------------------------------------------------------------
# 2 & 3. Named identifiers
# ---------------------------------------------------------------------------

_TICKED = re.compile(r"`([A-Za-z_][A-Za-z0-9_.]*)`")
_QUOTED = re.compile(r'"([a-z_]{3,}|[A-Z][A-Z_]{3,})"')

#: UPPER_SNAKE names that are not ours (Archipelago, HTTP, env vars).
FOREIGN_UPPER = {
    "SKIP_REQUIREMENTS_UPDATE", "CLIENT_GOAL", "ANTHROPIC_API_KEY",
    "ARCHIPELAGO_ROOT", "PYTHONPATH", "README", "TODO", "NOTE", "GET", "POST",
    "JSON", "HTTP", "LMB", "RMB", "AP", "UI", "API", "CLI", "URL", "ID", "IDS",
}

#: Cross-references to the packet's own documents, not code symbols.
DOC_NAMES = {d.name for d in HERE.glob("*.md")} | {
    "IMPLEMENTATION_DECISIONS.md", "NEXT_STEPS.md", "IMPLEMENTATION_PLAN",
}


def check_ticked_identifiers(doc: Path, text: str) -> None:
    for ident in sorted(set(_TICKED.findall(text))):
        if ident in DOC_NAMES or ident.endswith(".md"):
            continue
        head = ident.split(".")[0]
        if not (head.isupper() and "_" in head):
            continue                       # lowercase is too ambiguous to judge
        if head in FOREIGN_UPPER or head in KNOWN:
            continue
        if head in DELIBERATE_NON_MEMBERS:
            continue
        fail(doc, f"cites `{ident}`, which no schema or constant defines")


def check_quoted_enum_strings(doc: Path, text: str) -> None:
    for value in sorted(set(_QUOTED.findall(text))):
        if value in ENUM_MEMBERS or value in KNOWN:
            continue
        if value in DELIBERATE_NON_MEMBERS:
            continue
        # Only judge strings that LOOK like enum members: an enum in these
        # schemas is either UPPER_SNAKE or lower_snake with an underscore.
        if "_" not in value:
            continue
        # Near-miss only: a typo or a half-applied rename, not an unrelated
        # lower_snake key. Slot-data keys ("epsilon_coin", "zone_index") are
        # legitimately arbitrary and must not be flagged.
        near = [m for m in ENUM_MEMBERS
                if m.isupper() == value.isupper() and _edits(value, m) <= 2]
        if near:
            fail(doc, f'quotes "{value}", which is not an enum member '
                      f"(did you mean {sorted(near)}?)")


def _edits(a: str, b: str) -> int:
    """Levenshtein distance, small strings only."""
    if abs(len(a) - len(b)) > 2:
        return 99
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1,
                           prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def check_catalog_coverage(all_text: str) -> None:
    """Every catalog member must be named somewhere in the packet.

    The other direction of drift: a member renamed in `constants.py` while the
    prose keeps describing the old one. The rename is invisible to the schema
    tests, which only compare code against code.
    """
    catalogs = {
        "Theme": set(C.THEMES),
        "chamber type": set(C.CHAMBER_TYPES),
        "objective": set(C.OBJECTIVES),
        "enemy archetype": set(C.ENEMY_ARCHETYPES),
        "HubMode": set(typing.get_args(P.HubMode)),
        "ZoneState": set(typing.get_args(P.ZoneState)),
    }
    for label, members in catalogs.items():
        missing = sorted(m for m in members if m not in all_text)
        if missing:
            failures.append(
                f"(packet-wide): {label}(s) defined in code but named nowhere "
                f"in the prose: {missing}")


def check_banned_terms(doc: Path, text: str) -> None:
    for term, why in BANNED_TERMS.items():
        if re.search(rf"\b{re.escape(term)}\b", text, re.I):
            fail(doc, f"still says '{term}' — {why}")


# ---------------------------------------------------------------------------
# 4. Quoted test count
# ---------------------------------------------------------------------------

def check_test_count() -> None:
    proc = subprocess.run(
        [sys.executable, "-m", "pytest", "test_schemas.py", "-q",
         "--collect-only"],
        cwd=HERE / "schemas", capture_output=True, text=True)
    m = re.search(r"(\d+) tests? collected", proc.stdout)
    if not m:
        failures.append("could not collect the schema suite to count tests")
        return
    actual = int(m.group(1))
    for doc in DOCS:
        for n in re.findall(r"(\d+) tests", doc.read_text()):
            if int(n) > 20 and int(n) != actual:
                fail(doc, f"quotes {n} schema tests; the suite has {actual}")


def main() -> int:
    for doc in DOCS:
        text = doc.read_text()
        check_json_examples(doc, text)
        check_ticked_identifiers(doc, text)
        check_quoted_enum_strings(doc, text)
        check_banned_terms(doc, text)
    check_catalog_coverage("\n".join(d.read_text() for d in DOCS))
    check_test_count()

    if failures:
        print(f"{len(failures)} prose/model disagreement(s):\n")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"prose matches the models across {len(DOCS)} documents "
          f"({len(KNOWN)} known identifiers, {len(ENUM_MEMBERS)} enum members)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
