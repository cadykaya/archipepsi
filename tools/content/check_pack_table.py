#!/usr/bin/env python3
"""D-11 -- the art lane's game-pack rows, judged by Production's own code.

    python3 tools/content/check_pack_table.py

## Why this fetches somebody else's module

`pack_table_problems` is the contract. Retyping its rules here would
produce a check that agrees with my READING of D-11, which is exactly
the thing that needs testing. So the two files that carry the contract
-- `theme_packs.py` and `schemas/constants.py` -- are fetched verbatim
and read-only from Production's branch and imported from a scratch
directory. Nothing of theirs is edited, vendored or committed here, and
the package shells around them are empty files this script writes, so
importing the contract does not drag their whole bridge in.

## What it asserts

1. `pack_table_problems(descriptor)` is empty.
2. The descriptor actually HAS the rows. This one matters more than it
   looks: a descriptor with no pack table is legal and returns no
   problems, so a gate that only ran step 1 would pass loudest at the
   moment the art went missing.
3. `resolution_order` behaves as D-11 says -- a pack contributes its
   exact role and no hop of its own, and a role the pack does not ship
   falls through to the family chain unchanged.
4. Three planted failures are each caught. Without this, steps 1-3 would
   also pass against a `pack_table_problems` that returned `[]`
   unconditionally.
"""

import copy
import json
import os
import subprocess
import sys
import tempfile

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DESCRIPTOR = os.path.join(REPO, "assets", "textures", "theme",
                          "THEME_PACK.json")
PACK_MANIFEST = os.path.join(REPO, "assets", "textures", "theme",
                             "pack_manifest.json")
REF = os.environ.get("PROD_04_REF", "origin/claude/archipepsi-0-4-blindside")

#: destination inside the scratch package -> path in Production's tree.
CONTRACT = {
    "archipepsi_bridge/theme_packs.py":
        "bridge/archipepsi_bridge/theme_packs.py",
    "archipepsi_bridge/schemas/constants.py":
        "bridge/archipepsi_bridge/schemas/constants.py",
}


def fetch(root):
    for dest, src in CONTRACT.items():
        out = subprocess.run(["git", "-C", REPO, "show", "%s:%s" % (REF, src)],
                             capture_output=True, text=True)
        if out.returncode != 0:
            raise SystemExit(
                "check-pack-table: cannot read %s from %s. Fetch it:\n"
                "    git fetch origin %s\n%s"
                % (src, REF, REF.split("/", 1)[-1], out.stderr[-400:]))
        path = os.path.join(root, dest)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(out.stdout)
    # Empty package shells, written here rather than fetched: their real
    # __init__ files pull in the rest of the bridge, and this script
    # needs the contract, not the bridge.
    for pkg in ("archipepsi_bridge", "archipepsi_bridge/schemas"):
        open(os.path.join(root, pkg, "__init__.py"), "w").close()


def main():
    if not os.path.exists(DESCRIPTOR):
        print("check-pack-table: FAIL -- no descriptor at %s" % DESCRIPTOR,
              file=sys.stderr)
        return 1
    with open(DESCRIPTOR, encoding="utf-8") as handle:
        descriptor = json.load(handle)

    root = tempfile.mkdtemp(prefix="d11_")
    fetch(root)
    sys.path.insert(0, root)
    from archipepsi_bridge import theme_packs  # noqa: E402
    from archipepsi_bridge.schemas import constants as C  # noqa: E402

    bad = 0

    # --- 1. the gate itself -------------------------------------------
    problems = theme_packs.pack_table_problems(descriptor)
    for problem in problems:
        print("check-pack-table: FAIL -- %s" % problem, file=sys.stderr)
    bad += len(problems)

    # --- 2. the rows are actually there -------------------------------
    table = descriptor.get(C.THEME_PACK_TABLE) or {}
    expected = {}
    if os.path.exists(PACK_MANIFEST):
        with open(PACK_MANIFEST, encoding="utf-8") as handle:
            expected = json.load(handle)
    if expected and not table:
        print("check-pack-table: FAIL -- pack_manifest.json declares %d row(s) "
              "and the descriptor carries none. A descriptor with no pack "
              "table is LEGAL, so this gate would otherwise pass at the exact "
              "moment the pack art went missing. Run\n"
              "    python3 tools/content/verify_theme_set.py --write"
              % len(expected), file=sys.stderr)
        bad += 1
    missing = sorted(set(expected) - set(table))
    if missing:
        print("check-pack-table: FAIL -- authored but not described: %s"
              % ", ".join(missing), file=sys.stderr)
        bad += len(missing)

    # --- 3. the resolution, as D-11 states it -------------------------
    for key in sorted(table):
        pack, theme, role = key.split("/")
        order = theme_packs.resolution_order(descriptor, theme, role, pack)
        want_first = theme_packs.pack_row_key(pack, theme, role)
        if not order or order[0] != want_first:
            print("check-pack-table: FAIL -- %s resolves %s first, not itself"
                  % (key, order[0] if order else "nothing"), file=sys.stderr)
            bad += 1
        if sum(1 for k in order if k.startswith(pack + "/")) != 1:
            print("check-pack-table: FAIL -- %s contributes %d pack keys; a "
                  "pack contributes exactly one and takes no hop of its own"
                  % (key, sum(1 for k in order if k.startswith(pack + "/"))),
                  file=sys.stderr)
            bad += 1
        # And a role the pack does NOT ship falls through untouched.
        plain = theme_packs.resolution_order(descriptor, theme, role)
        if order[1:] != plain:
            print("check-pack-table: FAIL -- %s changes the family chain "
                  "behind it: %s vs %s" % (key, order[1:], plain),
                  file=sys.stderr)
            bad += 1

    # --- 4. the planted failures --------------------------------------
    sample = sorted(table)[0] if table else None
    if sample is None:
        print("check-pack-table: FAIL -- no pack row to sabotage, so the "
              "gate above was never shown to refuse anything",
              file=sys.stderr)
        bad += 1
    else:
        _, theme, role = sample.split("/")
        plants = {
            "a universal role a pack may not paint":
                ("np/%s/%s" % (theme, C.THEME_UNIVERSAL_ROLES[0]),
                 copy.deepcopy(table[sample])),
            "a house family's name used as a pack id":
                ("%s/%s/%s" % (C.THEMES[0], theme, role),
                 copy.deepcopy(table[sample])),
            "a row missing a key the family rows carry":
                ("np2/%s/%s" % (theme, role),
                 {k: v for k, v in list(table[sample].items())[:-1]}),
        }
        for why, (key, value) in plants.items():
            rigged = copy.deepcopy(descriptor)
            rigged[C.THEME_PACK_TABLE][key] = value
            if not theme_packs.pack_table_problems(rigged):
                print("check-pack-table: FAIL -- the gate accepted %s (%r). "
                      "It is not checking what this script claims it checks, "
                      "and every pass above is meaningless" % (why, key),
                      file=sys.stderr)
                bad += 1

    if bad:
        print("check-pack-table: FAIL -- %d problem(s)" % bad, file=sys.stderr)
        return 1
    packs = sorted({k.split("/")[0] for k in table})
    print("check-pack-table: %d row(s) across %d pack(s) (%s) pass "
          "Production's own pack_table_problems at %s, resolve themselves "
          "first with no hop, and the gate refuses all three planted faults."
          % (len(table), len(packs), ", ".join(packs), REF))
    return 0


if __name__ == "__main__":
    sys.exit(main())
