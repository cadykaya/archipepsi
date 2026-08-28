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
ORDER = [
    ("epsilon", ["epsilon_a_lectern", "epsilon_b_core", "epsilon_c_aperture"]),
    ("check", ["check_a_pedestal", "check_b_vault", "check_c_mast"]),
    ("portal", ["portal_a_blast", "portal_b_collar"]),
    ("enemy", ["enemy_melee_stooped", "enemy_ranged_tripod", "enemy_brute_squat"]),
    ("affordance", ["anchor_a_soffit", "anchor_b_jib"]),
    ("architecture", ["arch_wall_panel", "arch_wall_ribbed", "arch_floor_slab",
                      "arch_ceiling_beam", "arch_doorway", "arch_trim_rail",
                      "arch_railing", "arch_pipe_run", "arch_light_fixture"]),
    ("props", ["prop_crate", "prop_utility_box", "prop_terminal",
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
    for fam, _ in ORDER:
        path = os.path.join(ROOT, "assets/models/batch001", fam, "manifest.json")
        with open(path, encoding="utf-8") as handle:
            manifests.update(json.load(handle))
    rows = ["| ID | L | Category | Tris | Size (m) | Anchor | Model | Tex | Rev |",
            "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for _, ids in ORDER:
        for i in ids:
            m = manifests[i]
            s = m["size"]
            pre = i.split("_")[0]
            rows.append("| `%s` | %s | %s | %d | %.2f \u00d7 %.2f \u00d7 %.2f | %s "
                        "| B1R | B1R | PEND |"
                        % (i, LEVEL[pre], CAT[pre], m["triangles"],
                           s[0], s[1], s[2], m["anchor"]))
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
