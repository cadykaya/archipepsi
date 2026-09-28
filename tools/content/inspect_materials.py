"""What material slots each shipped asset actually carries.

    python3 tools/content/inspect_materials.py [substring ...]

INSPECTION ONLY. Reads the glTF JSON of every shipped `.glb` and reports
its materials, which mesh primitives use them, whether each carries an
embedded image, and -- since the Theme Pack authority draft of
2026-09-03 -- WHICH SEMANTIC ROLE each name resolves to and by what
route. Changes nothing, decides nothing, and writes no manifest field.

WHY THE SLOT NAMES MATTER. A theme pack that reskins a room without
rebuilding it needs a stable, per-role handle on that room's surfaces.
In glTF that handle is the MATERIAL NAME, and Godot's importer keeps it.

TODAY'S NAMES ARE LEGACY, NOT CANONICAL. The authority draft, section
8.4, requires an imported surface material name to be the EXACT lowercase
role id -- `floor`, not `cl_floor`, and never `floor.001`, which it says
an exporter should refuse rather than silently normalise. Every one of
the twelve approved shells predates that rule and satisfies none of it.

So this resolves a name three ways and never guesses:

  canonical   the name IS a role id, or a declared `hero_` material
  legacy      `<prefix>_<role>[.NNN]`, recognised BECAUSE the twelve
              shells that carry it are enumerated below with the source
              revision they were measured at -- not because the shape
              looks plausible
  refused     a role id carrying a Blender suffix -- 8.4's own case, and
              it resolves to no role at all
  unknown     everything else. A diagnostic, never a role.

`trim_plain` and `wall_ribbed` are Art TEXTURE VARIANTS, not pack roles.
They are deliberately absent from `ROLES` and resolve as variants of
`trim` and `wall` with a note, so that nothing here quietly promotes a
concrete-only texture into a role every future pack owes.
"""

from __future__ import annotations

import json
import os
import glob
import re
import struct
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
ROOTS = ("assets/models", "godot/content")

#: The five REQUIRED pack roles (authority draft, 8.1).
REQUIRED_ROLES = ("floor", "wall", "trim", "accent", "hazard")

#: Optional roles and the role each falls back to (8.2). `glass` falls
#: back to a global safe material rather than to a role, so it maps to
#: None -- recorded, not invented.
OPTIONAL_ROLES = {"ceiling": "wall", "metal": "trim", "glass": None,
                  "emissive": "accent", "decal": "accent"}

ROLES = tuple(REQUIRED_ROLES) + tuple(sorted(OPTIONAL_ROLES))

#: Art texture variants that are NOT pack roles. Kept separate on
#: purpose: `wall_ribbed` exists for `concrete_facility` alone, and
#: making it a role would hand every future pack a seventh obligation
#: for one theme's convenience.
VARIANTS = {"trim_plain": "trim", "wall_ribbed": "wall"}

#: The shells whose legacy `<prefix>_<role>` naming is EXPLICITLY
#: recognised, and the prefix each uses. A name is legacy because it
#: belongs to one of these, measured at the revision the report records
#: -- not because it matched a regular expression. A thirteenth shell
#: does not inherit the exemption by looking similar.
LEGACY_SHELLS = {
    # The twelve approved P2/P3/Wave-1 shells, measured at art `a2b6d59`.
    "shell_corner_left": "cl", "shell_corner_right": "cr",
    "shell_hall_transit": "hl", "shell_plenum_helix": "pl",
    "shell_span_basin": "sp", "shell_tower_collapsed": "tc",
    "shell_tower_gantry": "tg", "shell_tower_spiral": "ts",
    "shell_treasure_cache": "rc", "shell_treasure_coffer": "rf",
    "shell_treasure_vault": "rv", "shell_yard_gantry": "yd",
    # The eleven room-shell vocabulary shells of Batches 015-019, DECLARED
    # 2026-09-11 after `check_theme_roles.py` found that nothing had ever
    # classified them. There are twenty-three shells on disk and the Batch
    # 041 role map covered twelve; these eleven were approved vocabulary
    # sitting outside every check. Each prefix below was read from the
    # shell's own exported material names, not guessed from its id.
    "shell_arena_balcony": "ab", "shell_arena_pillars": "aq",
    "shell_arena_pit": "ap", "shell_arena_split": "as",
    "shell_corridor_bays": "cb", "shell_corridor_gallery": "cg",
    "shell_corridor_narrow": "cn", "shell_corridor_stepped": "cs",
    "shell_path_ascent": "pa", "shell_path_spans": "pn",
    "shell_path_stagger": "ps",
}

SUFFIX = re.compile(r"\.(\d{3})$")


def resolve(name, shell=None):
    """(role, kind, note) for one material name. Never a guess.

    `kind` is `canonical`, `legacy`, `variant`, `hero` or `unknown`.
    An unresolved name returns role None and a note saying why, which is
    what a binder would have to report by scene path and surface index.
    """
    suffixed = SUFFIX.search(name)
    stem = SUFFIX.sub("", name)
    if stem.startswith("hero_"):
        return (None, "hero",
                "protected material; must be declared in the asset's "
                "`protected_materials` (8.4)")
    if stem in ROLES:
        if suffixed:
            # 8.4 says an exporter refuses `floor.001` rather than
            # silently normalising it, so this does not quietly hand back
            # `floor`. A name that ALMOST complies is the one that must
            # fail at authoring time.
            return (None, "refused",
                    "`%s` is a role id carrying a Blender `.%s` suffix; "
                    "8.4 refuses it rather than normalising"
                    % (name, suffixed.group(1)))
        return (stem, "canonical", "")
    if stem in VARIANTS:
        return (VARIANTS[stem], "variant",
                "Art texture variant, not a pack role")
    prefix = LEGACY_SHELLS.get(shell)
    if prefix and stem.startswith(prefix + "_"):
        tail = stem[len(prefix) + 1:]
        if tail in ROLES:
            return (tail, "legacy",
                    "legacy `<prefix>_<role>`%s"
                    % (" with a Blender `.%s` suffix" % suffixed.group(1)
                       if suffixed else ""))
        if tail in VARIANTS:
            return (VARIANTS[tail], "variant",
                    "legacy name carrying an Art texture variant")
        return (None, "unknown",
                "prefix `%s` recognised, but `%s` is not a role or a "
                "known variant" % (prefix, tail))
    if prefix:
        return (None, "unknown",
                "does not start with this shell's recognised prefix "
                "`%s_`" % prefix)
    return (None, "unknown",
            "no recognised prefix for this asset, and `%s` is not a role"
            % stem)


def gltf(path):
    """The JSON chunk of a .glb, plus the byte length of its BIN chunk."""
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:4] != b"glTF":
        raise ValueError("%s is not a .glb" % path)
    off, js, binlen = 12, None, 0
    while off < len(data):
        length, kind = struct.unpack_from("<II", data, off)
        body = data[off + 8:off + 8 + length]
        if kind == 0x4E4F534A:
            js = json.loads(body)
        elif kind == 0x004E4942:
            binlen = len(body)
        off += 8 + length + ((4 - length % 4) % 4)
    return js, binlen


def slots(path):
    """[(material name, primitives using it, has an image)], plus orphans."""
    js, _ = gltf(path)
    mats = js.get("materials", [])
    used = {}
    for mesh in js.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if "material" in prim:
                used[prim["material"]] = used.get(prim["material"], 0) + 1
    out = []
    for i, mat in enumerate(mats):
        pbr = mat.get("pbrMetallicRoughness", {})
        out.append((mat.get("name", "<unnamed>"), used.get(i, 0),
                    "baseColorTexture" in pbr))
    return out, len(js.get("images", []))


def blob_sha(rel):
    """The git object id of a file, so a mapping is tied to a revision."""
    out = subprocess.run(["git", "hash-object", rel], cwd=REPO,
                         capture_output=True, text=True)
    return out.stdout.strip() or "unknown"


def role_map():
    """The compatibility mapping for the twelve, as inspectable data.

    REPORT DATA, NOT A CONTRACT. This is written under `docs/art/review/`
    for a human and for a future binder's author to read. It adds no
    manifest field and changes no schema -- the authority draft's
    material contract is Production's to define, and this only records
    what the shipped files say today, against the revision they say it
    at.
    """
    head = subprocess.run(["git", "rev-parse", "--short", "HEAD"],
                          cwd=REPO, capture_output=True,
                          text=True).stdout.strip()
    shells, totals = {}, {"canonical": 0, "legacy": 0, "variant": 0,
                          "hero": 0, "refused": 0, "unknown": 0}
    for cid, prefix in sorted(LEGACY_SHELLS.items()):
        hit = glob.glob(os.path.join(REPO, "assets/models/*/*/%s.glb" % cid))
        if not hit:
            shells[cid] = {"error": "no .glb found"}
            continue
        rel = os.path.relpath(hit[0], REPO)
        found, images = slots(hit[0])
        by_role, kinds, unresolved = {}, {}, []
        for name, prims, textured in found:
            role, kind, note = resolve(name, cid)
            kinds[kind] = kinds.get(kind, 0) + 1
            totals[kind] = totals.get(kind, 0) + 1
            if role is None:
                unresolved.append({"material": name, "kind": kind,
                                   "why": note})
            else:
                by_role.setdefault(role, []).append(name)
        shells[cid] = {
            "source": rel, "blob": blob_sha(rel), "prefix": prefix,
            "material_slots": len(found), "images": images,
            "naming": "legacy",
            "roles_used": sorted(by_role),
            "slots_per_role": {r: len(v) for r, v in sorted(by_role.items())},
            "kinds": kinds, "unresolved": unresolved,
        }
    return {
        "_comment": [
            "GENERATED by tools/content/inspect_materials.py --map.",
            "Inspection data for the Theme Pack authority draft of",
            "2026-09-03, section 8. NOT a manifest, NOT a schema, and",
            "read by nothing at runtime. Every name below is LEGACY:",
            "8.4 requires the exact lowercase role id, and none of the",
            "twelve carries one.",
        ],
        "art_head": head,
        "required_roles": list(REQUIRED_ROLES),
        "optional_roles": OPTIONAL_ROLES,
        "art_texture_variants": VARIANTS,
        "shells": shells,
        "totals": totals,
    }


# The refusal cases, named rather than described. A binder that GUESSES
# is the failure mode the authority draft's 8.4 exists to prevent, so the
# classifier is exercised on the shapes a real asset can present: the
# canonical id, the Blender suffix 8.4 refuses, an Art texture variant, a
# protected hero name, a typo, and a name from another shell entirely.
PROBES = [
    ("floor", None, "canonical", "the 8.4 name"),
    ("floor.001", None, "refused", "8.4 refuses the Blender suffix"),
    ("trim_plain", None, "variant", "an Art texture, not a pack role"),
    ("hero_reactor_face", None, "hero", "protected, must be declared"),
    ("cl_floor", "shell_corner_left", "legacy", "today's shipped name"),
    ("cl_floor.003", "shell_corner_left", "legacy", "shipped, suffixed"),
    ("cl_flooor", "shell_corner_left", "unknown", "a typo"),
    ("cl_hazard", "shell_corner_left", "legacy", "a role no shell uses"),
    ("yd_floor", "shell_corner_left", "unknown", "another shell's prefix"),
    ("Material.002", "shell_corner_left", "unknown", "Blender's default"),
]


def selftest():
    """Prove the classifier diagnoses rather than guesses."""
    bad = 0
    for name, shell, want, why in PROBES:
        role, kind, note = resolve(name, shell)
        ok = kind == want
        bad += 0 if ok else 1
        print("[sel] %-4s %-20s %-18s -> %-9s %-7s  %s"
              % ("ok" if ok else "FAIL", name, shell or "-", kind,
                 role or "REFUSED", note or why))
    print("[sel] %d probe(s), %d wrong" % (len(PROBES), bad))
    return 1 if bad else 0


def main(argv):
    if "--selftest" in argv:
        return selftest()
    if "--map" in argv:
        out = os.path.join(REPO, "docs/art/review/"
                           "theme_baseline_2026-09-10/role_map.json")
        data = role_map()
        with open(out, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, sort_keys=True)
        print("[mat] %s" % os.path.relpath(out, REPO))
        for cid, d in sorted(data["shells"].items()):
            print("      %-24s %-8s %3d slots  roles: %s%s"
                  % (cid, d.get("naming", "?"), d.get("material_slots", 0),
                     " ".join(d.get("roles_used", [])),
                     "  UNRESOLVED %d" % len(d["unresolved"])
                     if d.get("unresolved") else ""))
        print("[mat] totals: %s" % data["totals"])
        return 1 if (data["totals"].get("unknown")
                     or data["totals"].get("refused")) else 0
    want = argv[1:]
    rows, files = [], 0
    for root in ROOTS:
        base = os.path.join(REPO, root)
        for here, _, names in os.walk(base):
            for name in sorted(names):
                if not name.endswith(".glb"):
                    continue
                rel = os.path.relpath(os.path.join(here, name), REPO)
                if want and not any(w in rel for w in want):
                    continue
                files += 1
                found, images = slots(os.path.join(here, name))
                rows.append((rel, found, images))
    for rel, found, images in rows:
        print("[mat] %-56s %d material(s), %d image(s)"
              % (rel, len(found), images))
        for name, prims, textured in found:
            print("        %-38s %d primitive(s)%s"
                  % (name, prims, "  textured" if textured else ""))
    print("[mat] %d file(s)" % files)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
