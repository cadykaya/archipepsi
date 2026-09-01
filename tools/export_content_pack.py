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

#: The review state each family EXPORTS with, and why.
#:
#: `VisualOwnership.is_shippable()` refuses an entry whose `review` is
#: "pending", so this field is the switch that decides whether a family
#: actually substitutes at runtime or falls back to the engine placeholder.
#: It is therefore the ART SOURCE OF TRUTH for that decision, and the place
#: a reversal has to be recorded -- otherwise the next regeneration silently
#: re-enables something the owner turned off.
#:
#: FIXTURES: "pass". The A/B kept them.
#:
#: PROJECTILES: "pending". Production deliberately reverted the authored
#: projectile substitutions after the A/B because the silhouettes and tint
#: regressed against the engine's own `ProjectileSilhouette`. The source art
#: is NOT deleted and NOT redesigned -- Batch 008 remains a PASS as ART, and
#: this says only that the RUNTIME SUBSTITUTION is not currently approved.
#: Those are two different verdicts and conflating them is what caused the
#: drift: a batch verdict was being read as a shipping decision.
#:
#: Flipping a family back to "pass" is an owner decision, not a maintenance
#: one.
FIXTURE_REVIEW = "pass"
PROJECTILE_REVIEW = "pending"

#: Each authored shell falls back to the procedural entry for its chamber
#: type, so a missing scene degrades to the builder rather than to nothing.
_SHELL_FALLBACK = {
    "tower": "shell_tower_proc",
    "treasure_room": "shell_treasure_room_proc",
    "corridor": "shell_corridor_proc",
}

#: THE SEMANTIC SIZE, AND WHERE IT COMES FROM.
#:
#: This is an OWNER DESIGN ASSIGNMENT applied at Production's `eda4fd9`,
#: and it is written out as a table on purpose: none of it is derived
#: from the geometry and no future maintainer should reach for `size` to
#: "check" it. A treasure room is 8.8 m across and a corner 6.8 m, and
#: both are "small"; a tower is 12.8 m across and 20.5 m tall and is
#: "medium", not "large". `SizeClass` is the vocabulary Epsilon asks in,
#: and what it means is a prototype decision about the ROLE these rooms
#: play, not a measurement of them. Deriving it from metres would quietly
#: turn taste into arithmetic and get a different answer.
#:
#: P1 made the field optional (`SizeClass | None = None`), so P2 shipped
#: nothing rather than a guess. The guess is no longer needed: the owner
#: has decided, so the decision is recorded here and its provenance
#: travels with it in `provenance.json`.
_SIZE_CLASS = {
    "tower": "medium",
    "treasure_room": "small",
    "corridor": "small",
}
_SIZE_CLASS_SOURCE = ("owner design assignment applied at Production "
                      "eda4fd9; NOT derived from geometry")

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

#: The eight DIMENSIONLESS F3 shells (P2). Retrofitted to Production's P1
#: room contract at `99379e5` from the variables that built them --
#: `stones` for the towers, `_plinth`'s literals for the treasure rooms,
#: `_corner`'s turn for the corners. No GLB is remodelled.
#:
#: They export `review: "pending"` like everything else new: §16 of the
#: room-architecture study is explicit that the owner flips per entry, and
#: the projectile reversal is the proof that per-entry review is the
#: working kill switch.
#: id -> (source manifest dir, CHAMBER TYPE, shape tags).
#:
#: THE CORNERS ARE CORRIDORS. Production measured the consequence of the
#: old table at `eda4fd9`: the two corner shells were tagged `corner`,
#: which is not a chamber type -- `zone.py` has `corridor`, `arena`,
#: `tower`, `treasure_room` and has never had a fifth -- so even once
#: approved they could never be offered to anything. A tag no selector
#: can ask for is not metadata, it is a shell that never ships.
#:
#: `corner()` was always a corridor that turns. What makes it a corner is
#: authored spatial form plus `exit_yaw`, and both of those now travel in
#: the entry itself. So the chamber type is `corridor` -- that is the
#: progression truth, the thing a selector matches and the chain rotates
#: through -- and `corner` survives as a SHAPE TAG beside it, describing
#: the room without claiming to be a type. Nothing here approves them;
#: they stay `review: "pending"` and the owner still decides.
SHELLS = {
    "shell_tower_collapsed": ("batch018/shells", "tower", ("collapse",)),
    "shell_tower_spiral":    ("batch018/shells", "tower", ("spiral",)),
    "shell_tower_gantry":    ("batch018/shells", "tower", ("gantry",)),
    "shell_treasure_vault":  ("batch019/shells", "treasure_room",
                              ("protected",)),
    "shell_treasure_cache":  ("batch019/shells", "treasure_room",
                              ("stored",)),
    "shell_treasure_coffer": ("batch019/shells", "treasure_room",
                              ("displayed",)),
    "shell_corner_left":     ("batch019/shells", "corridor",
                              ("corner", "turn_left")),
    "shell_corner_right":    ("batch019/shells", "corridor",
                              ("corner", "turn_right")),
}

SHELL_REVIEW = "pending"

#: silhouette -> asset id. `ProjectileSilhouette.content_id()` is
#: "projectile_%s", and the family is closed at these three.
PROJECTILES = {
    "straight": ("batch008/enemy", "enemy_projectile_straight"),
    "falling":  ("batch008/enemy", "enemy_projectile_falling"),
    "lobbed":   ("batch008/enemy", "enemy_projectile_lobbed"),
}


#: Mirrors `ContentEntry` in Production's `schemas/content.py` AS OF
#: P1 (99379e5), which added `surfaces`. Duplicated
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
#:
#: Resynced from `ContentEntry.model_fields` at `eda4fd9`, which added
#: `exit_yaw` and `fits_floors` -- the two P2-C fields Production had to
#: apply by hand because this exporter did not emit them.
ENTRY_FIELDS = frozenset({
    "affordance_tag", "category", "clearances", "cost", "display_name",
    "exit_yaw", "fallback", "fits_floors", "id", "level",
    "procedural_fallback", "requires_capabilities", "review", "scene",
    "semantic_tags", "size", "size_class", "sockets", "surfaces",
    "theme_tags", "traversal", "variants", "volumes",
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
    # Traversal markers, per content id. `ShellValidator._check_segment`
    # refuses a MANDATORY segment with no `<name>_start` / `<name>_end`
    # Marker3D in the scene -- an unverifiable mandatory route is refused
    # rather than assumed good. The eight GLBs carry no markers and are
    # not being remodelled, so the markers go in the .tscn WRAPPER, which
    # this exporter generates. The mesh stays byte-identical.
    _markers = {}

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
            # The art-lane gate in visual_ownership.gd. See FIXTURE_REVIEW.
            "review": FIXTURE_REVIEW,
            # Degrade to the procedural slab if the scene ever goes missing.
            # Production renames the current procedural entry to this id as
            # part of the same change -- see the handoff document.
            "fallback": "%s_proc" % cid,
            "semantic_tags": ["light", "fixture", theme],
            "size": [round(v, 3) for v in m["size"]],
        })
        prov.append({"content_id": cid, "source_asset": "%s/%s" % (rel, asset),
                     "source_batch_review": "PASS",
                     "runtime_substitution": FIXTURE_REVIEW,
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
            # PENDING on purpose -- see PROJECTILE_REVIEW. The entry is still
            # exported so the asset stays wired and reviewable; it just does
            # not pass the shippable gate, so `_authored_projectile` returns
            # null and the engine's own silhouette is used.
            "review": PROJECTILE_REVIEW,
            # No `fallback`: no procedural registry entry exists for a
            # projectile, and a fallback naming an id no pack defines is a
            # hard registry failure. An unavailable scene resolves to "",
            # which `_authored_projectile` already reads as "use the
            # placeholder".
            "semantic_tags": ["projectile", silhouette],
            "size": [round(v, 3) for v in m["size"]],
        })
        prov.append({"content_id": cid, "source_asset": "%s/%s" % (rel, asset),
                     # The BATCH passed as art. The RUNTIME SUBSTITUTION was
                     # reverted after the A/B. Two verdicts, recorded apart.
                     "source_batch_review": "PASS",
                     "runtime_substitution": PROJECTILE_REVIEW,
                     "runtime_reverted_reason":
                         "silhouette and tint regressed against the engine's "
                         "own ProjectileSilhouette in the A/B",
                     "triangles": m.get("triangles")})

    for cid, (rel, family, shape_tags) in sorted(SHELLS.items()):
        m = _metrics(rel, cid)
        _copy(rel, cid, "shells")
        plan.append((cid, "shells", cid,
                     "res://content/shells/%s.glb" % cid))
        entry = {
            "id": cid,
            "level": 3,
            "category": "room_shell",
            "display_name": cid.replace("shell_", "").replace("_", " "),
            "scene": "res://content/shells/%s.tscn" % cid,
            "review": SHELL_REVIEW,
            "fallback": _SHELL_FALLBACK[family],
            # The CHAMBER TYPE first -- that is what a selector asks
            # for -- then the shape tags that describe the room without
            # claiming to be a type. No intent tag is invented here.
            "semantic_tags": [family] + list(shape_tags),
            # GODOT ORDER, and this is the axis trap: the art manifest's
            # `size` is Blender-ordered [outer_width, LENGTH, outer_height]
            # and `ShellValidator._check_envelope` reads this field as a
            # Godot Vector3. `roomcontract.assert_axis_order` proves the
            # swap at build time.
            "size": m["size_godot"],
            "surfaces": m["surfaces"],
            "sockets": m["sockets"],
            "volumes": m["volumes"],
        }
        if m.get("traversal"):
            entry["traversal"] = m["traversal"]
            _markers[cid] = [
                {"name": "%s_%s" % (seg["name"], end),
                 "position": seg[end]}
                for seg in m["traversal"] for end in ("start", "end")]
        # --- the three P2-C fields, each from its own source ---------
        #
        # `size_class` is the owner's assignment (see `_SIZE_CLASS`), not
        # a reading of `size`.
        entry["size_class"] = _SIZE_CLASS[family]

        # `exit_yaw` is the builder's own `turn * 90`, carried through
        # verbatim. Production proved the sign end to end at `eda4fd9` --
        # a two-room Zone measures the second room rotated +90 for
        # shell_corner_left -- so it is COPIED, never recomputed. There
        # is no second opinion about which way a corner turns.
        if m.get("exit_yaw") is not None:
            entry["exit_yaw"] = float(m["exit_yaw"])

        # `fits_floors` is the tower's authored floor count, read from
        # the value the builder used to lay out the climb. Not parsed
        # from the id, not counted off the platforms: `floors` is the
        # variable `_spiral`/`_gantry`/`_collapsed` were given. A room
        # that does not depend on the parameter emits nothing, which is
        # the schema's own "does not care" (empty tuple).
        if m.get("floors") is not None:
            entry["fits_floors"] = [int(m["floors"])]

        # `cost` still keeps the schema default: it is a balance number
        # and nobody has decided it.
        entries.append(entry)
        prov.append({"content_id": cid, "source_asset": "%s/%s" % (rel, cid),
                     "source_batch_review": "PASS",
                     "runtime_substitution": SHELL_REVIEW,
                     "p1_contract": {
                         "surfaces": len(m["surfaces"]),
                         "traversal": len(m.get("traversal", [])),
                         "volumes": len(m["volumes"]),
                         "sockets": len(m["sockets"]),
                         "exit_yaw": m.get("exit_yaw"),
                         "size_class": _SIZE_CLASS[family],
                         "size_class_source": _SIZE_CLASS_SOURCE,
                         "fits_floors": entry.get("fits_floors", []),
                         "chamber_type": family,
                         "shape_tags": list(shape_tags),
                         "collision": m.get("colliders"),
                         # Where the source-side probe mirror disagrees
                         # with what the shell declares. Provenance, not
                         # a schema field: `ContentEntry` forbids extras
                         # and this is evidence for review, not content.
                         "surface_probe": m.get("surface_probe", []),
                     },
                     "triangles": m.get("triangles")})

    manifest = {
        "schema_version": 1,
        "pack": "authored_art",
        # <= C.MAX_TEXT_LEN (160). `_check` refuses a longer one.
        "description": (
            "Approved light housings, plus projectile visuals held PENDING "
            "after the A/B reverted them. GENERATED by "
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
            "scenes": [{"content_id": c, "kind": k, "asset": a, "glb": g,
                        "markers": _markers.get(c, [])}
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
