#!/usr/bin/env python3
"""Export APPROVED art into the shape Production's ContentRegistry loads.

    assets/models/<batch>/<x>.glb   ->   godot/content/<kind>/<x>.glb
                                    +    godot/content/<kind>/<id>.tscn
                                    +    godot/content/registry/authored_art.json

GENERATED ARTIFACT. Regenerate with:

    python3 tools/export_content_pack.py

Why this exists, and why it is a script rather than a hand-made folder:
`content_registry.gd` requires an authored entry's `scene` to live under
`res://content/` and to be loadable. `res://` is `godot/`, and the art lane
builds into `assets/models/`, which is outside it. So the bytes have to be
copied, and a copied binary is a generated artifact like any other -- it is
regenerated from source, never hand-edited, and `check_art_current.sh` can
prove it still matches.

WHAT THIS DOES NOT DO. It exports only the two seams that cannot move
gameplay:

    fixture_light_<theme>   the HOUSING a light hangs in. The OmniLight3D is
                            built by ChamberBuilders._light either way, and
                            an authored housing carrying its own Light3D is
                            refused by the instantiator. Illumination is
                            engine-owned.
    projectile_<silhouette> the VISUAL of a shot. The hitbox is one engine
                            owned 0.25 m sphere for all three, and a mesh
                            carrying collision is refused.

Room shells are deliberately NOT exported. See docs/art/INTEGRATION_HANDOFF.md:
an authored shell replaces the generator's per-chamber dimensions with one
fixed size, which moves exit offsets, bounds, reward positions and enemy
spawns. That is a Zone topology change and it would contaminate the A/B.
"""
from __future__ import annotations

import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "godot", "content")

#: theme -> (source manifest dir, asset id). The CEILING fixture in each
#: theme, because `ChamberBuilders._light` hangs the housing under a lamp
#: placed just below the ceiling. The wall variants in batch014 are approved
#: too and have no seam to arrive through yet.
FIXTURES = {
    "concrete_facility": ("batch001/architecture", "arch_light_fixture"),
    "rusted_industrial": ("batch014/lights", "light_rusted_cage"),
    "neon_transit":      ("batch014/lights", "light_neon_channel"),
    "gothic_stone":      ("batch014/lights", "light_gothic_corona"),
    "temple_ruin":       ("batch014/lights", "light_temple_bowl"),
    "void_glitch":       ("batch014/lights", "light_void_absent"),
}

#: silhouette -> asset id. `ProjectileSilhouette.content_id()` is
#: "projectile_%s", and the family is closed at these three.
PROJECTILES = {
    "straight": ("batch008/enemy", "enemy_projectile_straight"),
    "falling":  ("batch008/enemy", "enemy_projectile_falling"),
    "lobbed":   ("batch008/enemy", "enemy_projectile_lobbed"),
}


#: Mirrors `ContentEntry` in Production's `schemas/content.py`. Duplicated
#: deliberately and kept deliberately dumb: this is a FAST guard so a bad
#: field fails here instead of at Production's gate, and it is NOT the
#: authority. The authority is Production's own model, run by
#: `tools/verify_content_pack.sh` -> `tools/content/verify_manifest.py`.
#:
#: It exists because the first version of this exporter validated only the
#: GDScript half of a dual-language contract, shipped `source_asset` and
#: `source_batch_review` -- fields the Python schema forbids outright, since
#: `Strict` sets `extra="forbid"` -- and a 231-character pack description
#: against a 160-character limit. Prod's integration stopped on all three.
ENTRY_FIELDS = frozenset({
    "id", "level", "category", "display_name", "scene", "procedural_fallback",
    "theme_tags", "semantic_tags", "size", "clearances", "sockets", "volumes",
    "review", "size_class", "traversal", "requires_capabilities",
    "affordance_tag", "cost", "variants", "fallback",
})

#: `C.MAX_TEXT_LEN` in Production. Applies to the pack `description` and to
#: every entry's `display_name`.
MAX_TEXT_LEN = 160


def _check(manifest):
    """Refuse to write anything Production's schema would reject."""
    problems = []
    if len(manifest["description"]) > MAX_TEXT_LEN:
        problems.append("pack description is %d characters; the limit is %d"
                        % (len(manifest["description"]), MAX_TEXT_LEN))
    for entry in manifest["entries"]:
        extra = sorted(set(entry) - ENTRY_FIELDS)
        if extra:
            problems.append("'%s' carries %s, which ContentEntry forbids"
                            % (entry["id"], extra))
        if len(entry["display_name"]) > MAX_TEXT_LEN:
            problems.append("'%s' display_name is %d characters; limit %d"
                            % (entry["id"], len(entry["display_name"]),
                               MAX_TEXT_LEN))
    if problems:
        raise SystemExit("export-content: refusing to write a manifest "
                         "Production would reject:\n  "
                         + "\n  ".join(problems))


def _metrics(rel_dir, asset):
    path = os.path.join(ROOT, "assets", "models", rel_dir, "manifest.json")
    with open(path) as fh:
        return json.load(fh)[asset]


def _copy(rel_dir, asset, kind):
    src = os.path.join(ROOT, "assets", "models", rel_dir, asset + ".glb")
    dst_dir = os.path.join(CONTENT, kind)
    os.makedirs(dst_dir, exist_ok=True)
    dst = os.path.join(dst_dir, asset + ".glb")
    shutil.copyfile(src, dst)
    return "res://content/%s/%s.glb" % (kind, asset)


def main():
    entries = []
    plan = []
    prov = []

    for theme, (rel, asset) in sorted(FIXTURES.items()):
        m = _metrics(rel, asset)
        glb = _copy(rel, asset, "fixtures")
        cid = "fixture_light_%s" % theme
        plan.append((cid, "fixtures", asset, glb))
        entries.append({
            "id": cid,
            "level": 2,
            "category": "fixture",
            "display_name": "Light housing (%s)" % theme.replace("_", " "),
            "scene": "res://content/fixtures/%s.tscn" % cid,
            # The art-lane gate in visual_ownership.gd. These are inside
            # batches 001-022, which the owner passed; `pending` would mean
            # somebody is still deciding.
            "review": "pass",
            # Degrade to the procedural slab if the scene ever goes missing.
            # Production renames the current procedural entry to this id as
            # part of the same change -- see the handoff document.
            "fallback": "%s_proc" % cid,
            "semantic_tags": ["light", "fixture", theme],
            "size": [round(v, 3) for v in m["size"]],
        })
        prov.append({"content_id": cid, "source_asset": "%s/%s" % (rel, asset),
                     "source_batch_review": "PASS",
                     "triangles": m.get("triangles")})

    for silhouette, (rel, asset) in sorted(PROJECTILES.items()):
        m = _metrics(rel, asset)
        glb = _copy(rel, asset, "projectiles")
        cid = "projectile_%s" % silhouette
        plan.append((cid, "projectiles", asset, glb))
        entries.append({
            "id": cid,
            "level": 0,
            "category": "projectile_visual",
            "display_name": "Projectile silhouette (%s)" % silhouette,
            "scene": "res://content/projectiles/%s.tscn" % cid,
            "review": "pass",
            # No `fallback`: no procedural registry entry exists for a
            # projectile, and a fallback naming an id no pack defines is a
            # hard registry failure. An unavailable scene resolves to "",
            # which `_authored_projectile` already reads as "use the
            # placeholder".
            "semantic_tags": ["projectile", silhouette],
            "size": [round(v, 3) for v in m["size"]],
        })
        prov.append({"content_id": cid, "source_asset": "%s/%s" % (rel, asset),
                     "source_batch_review": "PASS",
                     "triangles": m.get("triangles")})

    manifest = {
        "schema_version": 1,
        "pack": "authored_art",
        # <= C.MAX_TEXT_LEN (160). `_check` refuses a longer one.
        "description": (
            "Approved light housings and projectile visuals; the engine "
            "keeps the light and the hitbox. GENERATED by "
            "tools/export_content_pack.py."),
        "entries": entries,
    }
    _check(manifest)
    reg_dir = os.path.join(CONTENT, "registry")
    os.makedirs(reg_dir, exist_ok=True)
    with open(os.path.join(reg_dir, "authored_art.json"), "w") as fh:
        json.dump(manifest, fh, indent=1, sort_keys=False)
        fh.write("\n")

    # Where the art-side provenance lives now. SCENE_PLAN.json is NOT a
    # manifest and is not under `res://content/registry/`, so the registry
    # never reads it -- which is the point. `source_asset` and
    # `source_batch_review` are review history, not part of the content
    # contract, and Production's schema is right to forbid them.
    by_id = {p["content_id"]: p for p in prov}
    with open(os.path.join(CONTENT, "SCENE_PLAN.json"), "w") as fh:
        json.dump({
            "_comment": [
                "GENERATED by tools/export_content_pack.py. Two jobs:",
                "  1. the wrap step reads `scenes` to build the .tscn files",
                "  2. `provenance` records which APPROVED art each content id",
                "     came from, and under which batch verdict.",
                "Provenance is deliberately NOT in the registry manifest:",
                "ContentEntry forbids unknown fields, and source/review",
                "history is art-lane bookkeeping rather than a content",
                "contract.",
            ],
            "scenes": [{"content_id": c, "kind": k, "asset": a, "glb": g}
                       for c, k, a, g in plan],
            "provenance": [by_id[c] for c, _, _, _ in plan],
        }, fh, indent=1)
        fh.write("\n")

    print("[content] %d entries -> godot/content/registry/authored_art.json"
          % len(entries))
    for c, k, a, _ in plan:
        print("[content]   %-30s <- %s/%s.glb" % (c, k, a))
    return 0


if __name__ == "__main__":
    sys.exit(main())
