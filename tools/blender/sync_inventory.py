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
    ("batch003", "architecture",
     ["arch_wall_upper", "arch_pilaster", "hub_lab_doorway"]),
    ("batch003", "hub",
     ["hub_shop_counter", "hub_archive_terminal", "hub_abandon_station",
      "hub_campaign_board", "hub_controls_board"]),
    ("batch004", "lab",
     ["lab_dummy", "lab_height_markers", "lab_runway_measure", "lab_hazard",
      "lab_moving_target", "lab_reset_pad", "lab_notice_board"]),
    ("batch005", "check",
     ["check_mast", "check_item_locked", "check_item_available",
      "check_item_sending", "check_item_confirmed",
      "check_destination_ring", "check_send_beam"]),
    ("batch006", "portal", ["portal_core_locked", "portal_core_unlocked"]),
    ("batch006", "architecture", ["door_standard"]),
    ("batch007", "architecture",
     ["arch_stair", "arch_ramp", "arch_ledge", "arch_connector_straight",
      "arch_corner_left", "arch_corner_right"]),
    ("batch008", "enemy",
     ["enemy_projectile_straight", "enemy_projectile_falling",
      "enemy_projectile_lobbed"]),
    ("batch009", "affordance",
     ["breakwall_panel", "water_basin", "rail_beam", "wind_ring",
      "wind_perch", "bounce_pad", "movplat_deck"]),
    ("batch010", "dressing",
     ["prop_wall_plate", "prop_oil_drum", "prop_valve_wheel"]),
]
CAT = {"epsilon": "hero", "check": "hero", "portal": "interactable",
       "door": "module", "breakwall": "interactable",
       "water": "interactable", "rail": "interactable",
       "wind": "interactable", "bounce": "interactable",
       "movplat": "interactable",
       "enemy": "enemy", "anchor": "interactable", "arch": "module",
       "prop": "prop", "hub": "fixture", "lab": "fixture"}
LEVEL = {"epsilon": "L4", "check": "L2", "portal": "L2", "enemy": "L0",
         "door": "L1", "breakwall": "L2", "water": "L2", "rail": "L2",
         "wind": "L2", "bounce": "L2", "movplat": "L2",
         "anchor": "L2", "arch": "L1", "prop": "L0", "hub": "L2",
         "lab": "L1"}


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
        # B1R for what the 001 revision built, B2 for what 002 did. The
        # review column reads PASS because the OWNER passed Style Lock on
        # 2026-08-28 -- see the top of ART_REVIEW.md. It is a transcription
        # of a decision, not one this script is entitled to make, and if a
        # later asset is built before its own review it does not go in this
        # table until it has one.
        # Derived, not tabulated. The literal table said B4 for anything it
        # did not know, so batch005 would have been labelled as batch004's
        # work -- the same shape of staleness as L-33, in the one column
        # that says WHICH REVIEW an asset belongs to.
        rev = "B1R" if batch == "batch001" \
            else "B" + batch.removeprefix("batch").lstrip("0")
        for i in ids:
            m = manifests[i]
            s = m["size"]
            pre = i.split("_")[0]
            # Style Lock's own assets carry the owner's PASS. Anything
            # produced AFTER the lock is NEW: it inherits approved DNA but
            # has not itself been looked at, and writing PASS on it would be
            # this script approving art, which it may never do.
            verdict = "PASS" if batch in ("batch001", "batch002") else "PEND"
            rows.append("| `%s` | %s | %s | %d | %.2f \u00d7 %.2f \u00d7 %.2f | %s "
                        "| %s | %s | %s |"
                        % (i, LEVEL[pre], CAT[pre], m["triangles"],
                           s[0], s[1], s[2], m["anchor"], rev, rev,
                           verdict))
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
