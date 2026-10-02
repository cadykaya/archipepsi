"""D-11. The descriptor contract for game packs, stated once.

`theme_pack.gd` resolves textures and `tools/content/verify_theme_set.py`
writes the descriptor it reads. This module is neither: it is the
contract the two meet at, as code, so the resolver, the art toolchain
and the tests all check one spelling of it. **It writes nothing and
selects nothing** -- no asset is regenerated here, and no pack becomes
nameable by anything in this file.

THE SHAPE (Prod's D-11 answer §2). A sibling of `textures`, flat:

    "pack_textures": {
        "<pack>/<theme>/<role>": {<exactly the keys a `textures` row has>}
    }

**The same row schema is checked against the descriptor's own family
rows**, not against a list retyped here -- "same schema as `textures`"
is then literally what is verified, and the day the art lane adds a
key to its rows, pack rows are expected to carry it too.

THE RESOLUTION (answer §1). One more key, tried first, and **no hop of
its own**: a pack either ships the exact role or yields the whole role
to the family, whose existing chain -- its one role hop included -- is
unchanged. `resolution_order` states it as a list so it can be asserted.

UNIVERSAL ROLES (answer §3). A pack painting `hazard` is refused the way
a family is.
"""
from __future__ import annotations

import re

from .schemas import constants as C

_PACK_ID = re.compile(r"^[a-z0-9_]{1,24}$")


def pack_row_key(pack: str, theme: str, role: str) -> str:
    return f"{pack}/{theme}/{role}"


def resolution_order(descriptor: dict, theme: str, role: str,
                     pack: str | None = None) -> list[str]:
    """Every key the resolver may try, in order, and nothing else.

    The pack contributes ONE key: its exact role. The family then
    contributes exactly what it did before a pack existed -- its exact
    role and, if the descriptor names one, one fallback role. There is
    no `(pack, theme, fallback_role)`: that would be a texture chosen for
    neither this pack's role nor by this family, and it is the hop
    Prod's clause 2 exists to forbid.
    """
    if role in C.THEME_UNIVERSAL_ROLES:
        return []
    order = [pack_row_key(pack, theme, role)] if pack else []
    order.append(f"{theme}/{role}")
    variants = descriptor.get("variants") or {}
    fallbacks = descriptor.get("optional_role_fallbacks") or {}
    hop = variants.get(role, fallbacks.get(role))
    if hop:
        order.append(f"{theme}/{hop}")
    return order


def pack_table_problems(descriptor: dict) -> list[str]:
    """What is wrong with a descriptor's pack table, or nothing.

    A descriptor with no pack table is a descriptor that works exactly
    as it did -- the backward-compatibility requirement discharged in
    the file format as well as in the resolver.
    """
    table = descriptor.get(C.THEME_PACK_TABLE)
    if table is None:
        return []
    if not isinstance(table, dict):
        return [f"'{C.THEME_PACK_TABLE}' is not a flat table"]
    family_rows = [r for r in (descriptor.get("textures") or {}).values()
                   if isinstance(r, dict)]
    schema = set(family_rows[0]) if family_rows else None
    known_roles = (set(descriptor.get("roles_shipped") or ())
                   | set(descriptor.get("optional_role_fallbacks") or {})
                   | set(descriptor.get("variants") or {}))
    problems = []
    for key, row in table.items():
        parts = str(key).split("/")
        if len(parts) != 3:
            problems.append(f"'{key}' is not '<pack>/<theme>/<role>'")
            continue
        pack, theme, role = parts
        if not _PACK_ID.match(pack):
            problems.append(f"'{key}': pack id '{pack}' is not a valid id")
        elif pack in C.THEMES:
            problems.append(f"'{key}': '{pack}' is a house family's name, "
                            "not a game pack's")
        if theme not in C.THEMES:
            problems.append(f"'{key}': '{theme}' is not one of the six "
                            "house families")
        if role in C.THEME_UNIVERSAL_ROLES:
            problems.append(f"'{key}': '{role}' is universal and resolved "
                            "from the shared material; a pack may not "
                            "paint it, or the shared signal becomes one "
                            "per pack")
        elif known_roles and role not in known_roles:
            problems.append(f"'{key}': '{role}' is not a role the family "
                            "table knows, so it would override nothing")
        if not isinstance(row, dict):
            problems.append(f"'{key}': the row is not a table")
        elif schema is not None and set(row) != schema:
            problems.append(
                f"'{key}': the row carries {sorted(row)}, and a `textures` "
                f"row carries {sorted(schema)}; pack rows share one schema")
    return problems
