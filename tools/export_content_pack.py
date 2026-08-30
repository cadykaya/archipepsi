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
            "source_asset": "%s/%s" % (rel, asset),
            "source_batch_review": "PASS",
        })

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
            "source_asset": "%s/%s" % (rel, asset),
            "source_batch_review": "PASS",
        })

    manifest = {
        "schema_version": 1,
        "pack": "authored_art",
        "description": (
            "Approved art exposed through the two seams that cannot move "
            "gameplay: light HOUSINGS (the engine keeps the light) and "
            "projectile VISUALS (the engine keeps the hitbox). GENERATED by "
            "tools/export_content_pack.py -- never hand-edited."),
        "entries": entries,
    }
    reg_dir = os.path.join(CONTENT, "registry")
    os.makedirs(reg_dir, exist_ok=True)
    with open(os.path.join(reg_dir, "authored_art.json"), "w") as fh:
        json.dump(manifest, fh, indent=1, sort_keys=False)
        fh.write("\n")

    with open(os.path.join(CONTENT, "SCENE_PLAN.json"), "w") as fh:
        json.dump([{"content_id": c, "kind": k, "asset": a, "glb": g}
                   for c, k, a, g in plan], fh, indent=1)
        fh.write("\n")

    print("[content] %d entries -> godot/content/registry/authored_art.json"
          % len(entries))
    for c, k, a, _ in plan:
        print("[content]   %-30s <- %s/%s.glb" % (c, k, a))
    return 0


if __name__ == "__main__":
    sys.exit(main())
