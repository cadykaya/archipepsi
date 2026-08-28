"""Regenerate the built-assets table in ASSET_INVENTORY.md from the manifests.

    python3 tools/blender/sync_inventory.py

The table is the only part of the art documents that is pure transcription,
and transcription is where the 10 mm errors `check_docs_metrics.py` caught
came from. Generating it removes the class of mistake rather than catching
it again. Run it after any build that changes a size, a count or an anchor,
then re-run check_docs_metrics.py.
"""
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
#: (batch, family, [ids]) in the order the table reads. The batch is part of
#: the row, not a guess: an asset revised in 002 sits beside the 001 concept
#: it revises rather than replacing it, because the review rule is that
#: nothing already shown is deleted.
ORDER = [
    ("batch001", "epsilon",
     ["epsilon_a_lectern", "epsilon_b_core", "epsilon_c_aperture"]),
    ("batch002", "epsilon", ["epsilon_installation"]),
    ("batch001", "check", ["check_a_pedestal", "check_b_vault", "check_c_mast"]),
    ("batch001", "portal", ["portal_a_blast", "portal_b_collar"]),
    ("batch002", "portal", ["portal_b2_wound"]),
    ("batch001", "enemy",
     ["enemy_melee_stooped", "enemy_ranged_tripod", "enemy_brute_squat"]),
    ("batch002", "enemy",
     ["enemy_scuttler", "enemy_charger", "enemy_bulwark", "enemy_artillery",
      "enemy_beacon", "enemy_drifter", "enemy_diver"]),
    ("batch001", "affordance", ["anchor_a_soffit", "anchor_b_jib"]),
    ("batch002", "affordance", ["anchor_b_wall_jib"]),
    ("batch001", "architecture",
     ["arch_wall_panel", "arch_wall_ribbed", "arch_floor_slab",
      "arch_ceiling_beam", "arch_doorway", "arch_trim_rail",
      "arch_railing", "arch_pipe_run", "arch_light_fixture"]),
    ("batch002", "architecture", ["arch_utility_lamp"]),
    ("batch001", "props",
     ["prop_crate", "prop_utility_box", "prop_terminal",
      "prop_pipe_cluster", "prop_machinery_unit", "prop_debris",
      "prop_warning_sign"]),
]
CAT = {"epsilon": "hero", "check": "hero", "portal": "interactable",
       "enemy": "enemy", "anchor": "interactable", "arch": "module",
       "prop": "prop"}
LEVEL = {"epsilon": "L4", "check": "L2", "portal": "L2", "enemy": "L0",
         "anchor": "L2", "arch": "L1", "prop": "L0"}


def main():
    manifests = {}
    for batch, fam, _ in ORDER:
        path = os.path.join(ROOT, "assets/models", batch, fam, "manifest.json")
        with open(path, encoding="utf-8") as handle:
            for key, value in json.load(handle).items():
                value = dict(value)
                value["batch"] = batch
                manifests[key] = value
    rows = ["| ID | L | Category | Tris | Size (m) | Anchor | Model | Tex | Rev |",
            "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for batch, _, ids in ORDER:
        # B1R for what the 001 revision built, B2 for what 002 did. Every
        # row stays PEND: only the owner turns PENDING into PASS.
        rev = "B1R" if batch == "batch001" else "B2"
        for i in ids:
            m = manifests[i]
            s = m["size"]
            pre = i.split("_")[0]
            rows.append("| `%s` | %s | %s | %d | %.2f \u00d7 %.2f \u00d7 %.2f | %s "
                        "| %s | %s | PEND |"
                        % (i, LEVEL[pre], CAT[pre], m["triangles"],
                           s[0], s[1], s[2], m["anchor"], rev, rev))
    table = "\n".join(rows)

    path = os.path.join(ROOT, "docs/art/ASSET_INVENTORY.md")
    with open(path, encoding="utf-8") as handle:
        doc = handle.read()
    head = doc.index("<!-- GENERATED TABLE")
    head = doc.index("\n\n", head) + 2
    tail = doc.index("\n\n| Theme material |", head)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(doc[:head] + table + doc[tail:])
    print("sync-inventory: %d assets written" % (len(rows) - 2))


if __name__ == "__main__":
    main()
