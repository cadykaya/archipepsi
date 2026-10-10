"""The theme role convention, DECLARED and ENFORCED over every shell.

    python3 tools/content/check_theme_roles.py [--json <path>]

## The gap this closes

The theme-pack preparation report listed nine gaps and made this one Art's,
at the top of the list: *"The theme role convention is undeclared and
unchecked. F3 proves it holds in all 597 slots today; nothing stops the next
builder breaking it."* It is the cheapest item on that list and every later
step depends on it — a binder cannot resolve a role it cannot find, and a
theme pack cannot be complete against a convention nothing keeps.

Batch 041 reconciled the contract and wrote `role_map.json`, which is a
REPORT: it enumerates twelve shells by name at a pinned revision and records
what they carry. A report is not a gate. Two things it cannot do:

  * **it does not see a thirteenth shell.** There are twenty-three shell
    `.glb` files on disk and the report covers twelve. The other eleven —
    the arenas, corridors and paths from Batches 015–019 — were approved
    vocabulary that nothing had ever classified.
  * **it does not check the themes.** Whether every role a shell uses
    actually exists in every theme, and whether any theme is short a role,
    were the other two halves of the proposed check and neither was built.

This does both, over everything on disk, and exits non-zero.

## What it does NOT do

No asset, schema, manifest or registry field is touched. This reads files
and reports. The material contract itself is Production's to define; this
enforces the convention Art already agreed to and records where it holds.

## Declaring a new shell

A new shell is REFUSED until somebody declares it, and that refusal is the
whole point — a thirteenth shell must not inherit the exemption by looking
similar. Two ways to satisfy it:

  * name its materials canonically — `floor`, `wall`, `trim` (§8.4), which
    is what a shell authored after the authority draft should do; or
  * add it to `inspect_materials.LEGACY_SHELLS` with its prefix, which is a
    deliberate act recorded in a diff.
"""

from __future__ import annotations

import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import inspect_materials as mat  # noqa: E402

REPO = mat.REPO

#: Where a shell may live. Both are searched: the authored sources and the
#: exported content pack, because a convention that holds in one and not the
#: other is a convention that breaks on the way to the game.
SHELL_GLOBS = (
    "assets/models/*/shells/shell_*.glb",
    "godot/content/shells/shell_*.glb",
)

#: The six themes, from the palette rather than from a list here, so a
#: seventh theme is covered the moment it is added.
def themes():
    with open(os.path.join(REPO, "assets", "art_palette.json"),
              "r", encoding="utf-8") as handle:
        return sorted(json.load(handle)["themes"])


#: `hazard` is REQUIRED by §8.1 and no theme paints one.
#:
#: THE OWNER SETTLED THIS on 2026-09-10: every pack must RESOLVE the
#: `hazard` role, but may resolve it to the SAME shared universal material.
#: Separate theme-coloured hazard textures are not required and none was
#: painted. So a theme with no `hazard` texture is complete, and a theme
#: that shipped one would be the finding — it would mean a pack had
#: re-tinted a colour the art lane holds universal.
UNIVERSAL_ROLES = {"hazard": "the shared universal hazard ramp "
                             "(owner ruling, 2026-09-10)"}


def theme_textures():
    """role -> set(themes that ship a texture for it)."""
    have = {}
    for path in glob.glob(os.path.join(REPO, "assets", "textures", "theme",
                                       "*.png")):
        stem = os.path.basename(path)[:-4]
        for theme in themes():
            if stem.startswith(theme + "_"):
                have.setdefault(stem[len(theme) + 1:], set()).add(theme)
                break
    return have


def shells():
    """Every shell on disk, deduplicated by content id, with its paths."""
    found = {}
    for pattern in SHELL_GLOBS:
        for path in sorted(glob.glob(os.path.join(REPO, pattern))):
            cid = os.path.basename(path)[:-4]
            found.setdefault(cid, []).append(os.path.relpath(path, REPO))
    return found


def check(as_json=None):
    problems, notes = [], []
    have = theme_textures()
    all_themes = set(themes())
    report = {"themes": sorted(all_themes), "shells": {}, "roles_used": {}}

    roles_used = {}
    undeclared = []
    for cid, paths in sorted(shells().items()):
        per_shell = {"paths": paths, "slots": 0, "roles": [], "kinds": {},
                     "unresolved": []}
        # One file per content id is enough to classify the naming; the
        # exporter copies rather than re-authors, and `diff_shell_glb.py`
        # is what proves those copies identical.
        found, _images = mat.slots(os.path.join(REPO, paths[0]))
        seen = set()
        for name, _prims, _textured in found:
            per_shell["slots"] += 1
            role, kind, note = mat.resolve(name, cid)
            per_shell["kinds"][kind] = per_shell["kinds"].get(kind, 0) + 1
            if role is None and kind in ("unknown", "refused"):
                per_shell["unresolved"].append({"name": name, "kind": kind,
                                                "why": note})
            elif role:
                seen.add(role)
                roles_used.setdefault(role, set()).add(cid)
        per_shell["roles"] = sorted(seen)
        report["shells"][cid] = per_shell
        if per_shell["unresolved"]:
            if cid not in mat.LEGACY_SHELLS:
                undeclared.append(cid)
            else:
                problems.append(
                    "%s: %d material name(s) do not resolve to a role, and "
                    "it IS declared — so the names themselves are wrong: %s"
                    % (cid, len(per_shell["unresolved"]),
                       ", ".join(u["name"]
                                 for u in per_shell["unresolved"][:4])))

    if undeclared:
        problems.append(
            "%d shell(s) on disk are not declared and do not use canonical "
            "role names, so nothing classifies their surfaces: %s. Either "
            "name their materials canonically (§8.4) or add each to "
            "inspect_materials.LEGACY_SHELLS with its prefix."
            % (len(undeclared), ", ".join(sorted(undeclared))))

    # -- universal roles, checked ALWAYS ----------------------------------
    #
    # Not "for each role some shell uses". A universal role is universal
    # whether or not a shell has reached for it yet, and the failure this
    # guards against -- a pack painting its own `hazard` -- is most likely
    # BEFORE any shell uses one.
    #
    # Found by sabotage: the first version ran this inside the loop over
    # roles in use, no shell uses `hazard`, so dropping a theme-tinted
    # hazard texture into the set passed silently and the final loop even
    # excused it as "a variant or a spare". A check that cannot fire on the
    # case it exists for is not a check.
    for role, resolved_by in sorted(UNIVERSAL_ROLES.items()):
        shipped = sorted(have.get(role, set()))
        if shipped:
            problems.append(
                "role `%s` resolves to %s, but %s ship a theme texture for "
                "it. A pack must not re-tint a universal colour."
                % (role, resolved_by, ", ".join(shipped)))
        else:
            notes.append("`%s` resolved by %s, and no theme paints one — "
                         "which is the required state"
                         % (role, resolved_by))

    # -- theme completeness ------------------------------------------------
    for role in sorted(roles_used):
        users = sorted(roles_used[role])
        report["roles_used"][role] = users
        if role in UNIVERSAL_ROLES:
            continue                      # handled above, unconditionally
        missing = sorted(all_themes - have.get(role, set()))
        if not missing:
            continue
        fallback = mat.OPTIONAL_ROLES.get(role, "__required__")
        if fallback == "__required__":
            problems.append(
                "role `%s` is used by %d shell(s) and %d theme(s) have no "
                "texture for it: %s. §8.1 makes it required."
                % (role, len(users), len(missing), ", ".join(missing)))
        elif fallback is None:
            notes.append("optional `%s` missing from %s; §8.2 sends it to a "
                         "global safe material"
                         % (role, ", ".join(missing)))
        elif fallback in have and not (all_themes - have[fallback]):
            notes.append("optional `%s` missing from %s; falls back to `%s`, "
                         "which every theme has (§8.2)"
                         % (role, ", ".join(missing), fallback))
        else:
            problems.append(
                "optional `%s` is missing from %s and its §8.2 fallback "
                "`%s` is not in every theme either."
                % (role, ", ".join(missing), fallback))

    # -- no theme short a role the others have ----------------------------
    for role in sorted(have):
        if role in mat.VARIANTS or role in UNIVERSAL_ROLES:
            continue                      # a variant owes no theme anything;
                                          # a universal role is judged above
        short = sorted(all_themes - have[role])
        if short and role in roles_used:
            continue                      # already reported above
        if short:
            notes.append("`%s` exists in %d theme(s) and not in %s, and no "
                         "shell uses it — a variant or a spare, not a gap"
                         % (role, len(have[role]), ", ".join(short)))

    report["problems"] = problems
    report["notes"] = notes
    if as_json:
        with open(as_json, "w", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2, sort_keys=True, default=list)

    for line in notes:
        print("[roles] note: %s" % line)
    if problems:
        print("[roles] %d PROBLEM(S)" % len(problems))
        for line in problems:
            print("  - %s" % line)
        return 1
    print("[roles] PASS -- %d shell(s), %d material slot(s), %d role(s) in "
          "use, %d theme(s), 0 unresolved"
          % (len(report["shells"]),
             sum(s["slots"] for s in report["shells"].values()),
             len(report["roles_used"]), len(all_themes)))
    return 0


def main(argv):
    as_json = None
    if "--json" in argv:
        as_json = argv[argv.index("--json") + 1]
    return check(as_json)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
