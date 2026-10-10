#!/usr/bin/env python3
"""Owner review 2026-09-28 -- Group B, manipulation objects (043 + 053).

    python3 tools/owner_review_2026_09_28/build_B.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sheets import Panel, Sheet  # noqa: E402

REV = "docs/art/review"
OUT = f"{REV}/owner_review_2026-09-28/sheets"
EV = f"{REV}/owner_review_2026-09-28/evidence"
PR = f"{REV}/props_2026-09-11/room"
FOOT = ("Art source 32df699. The prop renders were regenerated with Batch 053 "
        "(e70eb68e); every model is byte-identical since (checked). Production "
        "read at c12a72fbc625 (pinned). Nothing here changes a status.")


def b1() -> None:
    s = Sheet("B1 · Pickup, qualified, immovable, decoration",
              "Twelve physics props against Production's own rules. The class "
              "comes from the object's carriable flag and kilograms, never from "
              "a handle or a mass label painted on it.")
    s.statuses(
        visual=("pending", "043 is in the pending band; 053 PENDING, 22 Sept "
                "(ART_REVIEW.md:4287). The owner's correction was about meaning: "
                "'nothing needs redesigning'."),
        compat=("partial", "Checked against Production's constants (no "
                "problems); sizes match to 0.5 mm; no collision shipped."),
        binding=("none", "None: 'Nothing loads these' (manipulation handoff)."),
        play=("partial", "Normal play has a body-shoved 60 kg code crate and "
              "code-built dressing. Pickup exists only in candidate or fixture "
              "rooms, and no Echo delivers qualified PUSH/PULL/HOLD yet."))
    s.row([Panel(f"{PR}/PROPS_lineup_bright.png",
                 "The twelve, grouped by class; the numbers are kilograms.",
                 tag="RENDER", note="high oblique review view, not eye height")])
    s.text("The rule in Production today",
           "ORDINARY PICKUP: carriable AND at most 60 kg, a property of the "
           "OBJECT that no gear widens (constants.gd:228-233): key component 8, "
           "generic 15, power cell 40, mechanical part 55. QUALIFIED: what a "
           "host with the 120 kg envelope may push, pull or hold (plate 60 not "
           "carriable, drum 70, girder 95, weighted 140 push only, cart 180 at "
           "the limit). BEYOND the minimum envelope: cover 220, ballast 320. "
           "FIXED: not manipulable, or 400 kg and up (mass_class.gd:47-51): "
           "anchor block 500. DECORATION: the approved prop_crate and "
           "prop_oil_drum.")
    s.row([Panel(f"{PR}/PROPS_close_phys_power_cell.png",
                 "Pickup: power cell, 40 kg; one hand grip on top.", tag="RENDER"),
           Panel(f"{PR}/PROPS_close_phys_plate.png",
                 "Qualified: plate, 60 kg, NOT carriable; lifting slots, no grip.",
                 tag="RENDER")])
    s.row([Panel(f"{PR}/PROPS_close_phys_weighted.png",
                 "Qualified, push only: weighted, 140 kg; two push faces.",
                 tag="RENDER"),
           Panel(f"{PR}/PROPS_fixed_vs_movable_bright.png",
                 "Fixed vs heavy: anchor block 500 kg (one tether eye) beside "
                 "ballast 320 kg.", tag="RENDER",
                 note="this frame's caption says the ballast is 'meant to move'; "
                      "053's own table says ballast push: no")])
    s.row([Panel(f"{PR}/PROPS_candidate_vs_decorative_bright.png",
                 "Decoration vs candidate: the approved crate and drum beside "
                 "their manipulable twins.", tag="RENDER"),
           Panel(f"{EV}/prod_c12a72f/candidate_04_the_power_cell_at_home.jpg",
                 "Today: Production's carriable cell, a glowing box.",
                 tag="PLACEHOLDER", note="candidate profile (off by default)")])
    s.decision(
        ask="(1) Give the four carriables an object-scale silhouette tell (for "
            "example 035-R's bail arch), so 'you can pick this up' reads at room "
            "distance? (2) Should the objects beyond the minimum envelope look "
            "anchored? (3) Do prop_crate and prop_oil_drum stay decoration?",
        recommend="(1) Yes. (2) Not yet: defer any fitting keyed to the envelope "
                  "until an Echo actually delivers PUSH/PULL/HOLD. (3) Yes.",
        risk="(1) Four props re-authored, and their sizes feed Production's box "
             "colliders. Today the 15 kg grip reads like the 140 kg push pads: "
             "both share one handling material and differ only at hand scale.",
        engineering="A loader for these props, the carriable flag set per object, "
                    "and a verb that delivers qualified PUSH/PULL/HOLD. Permissions "
                    "stay the object's flag and kilograms, never the art.")
    s.footer(FOOT)
    print(s.save(f"{OUT}/B1_manipulation_classes.jpg"))


def b2() -> None:
    s = Sheet("B2 · The 'lightened' panels (Batch 053)",
              "053 gave eleven props a pair of lightened panels for the one "
              "status that acts on objects. The panels are nodes, so a runtime "
              "can show or hide them.")
    s.statuses(
        visual=("pending", "053 PENDING, 22 Sept."),
        compat=("partial", "Node names are stable; each prop's lightened class "
                "is in manipulation.json."),
        binding=("none", "None."),
        play=("partial", "'lightened' exists on objects only in the Unweighted "
              "Switch room, which is candidate-hosted."))
    s.row([Panel(f"{PR}/PROPS_close_phys_generic.png",
                 "Generic, 15 kg: the panel covers the hand grip on the same "
                 "face, and the two merge into one patch.", tag="RENDER"),
           Panel(f"{PR}/PROPS_close_phys_ballast.png",
                 "Ballast, 320 kg: four attach pads, skids, no hand grip.",
                 tag="RENDER")])
    s.decision(
        ask="Keep the lightened panels as a visible node on these props?",
        recommend="Yes, but repair them first (below). They are the only place "
                  "the object status can show.",
        risk="As exported, all 22 panels use each prop's GRIP material, which the "
             "family keeps for 'the surfaces the player's device touches'. On "
             "five props a panel overlaps a fitting or sits within 1 cm of it.",
        engineering="A status display that toggles the node. Also ask Production "
                    "whether 'lightened' can apply to a non-manipulable object "
                    "(the table lists the anchor block as 'heavy').")
    s.footer(FOOT + " Smallest repair: give the panels their own material slot "
             "and move them off the fitting faces.")
    print(s.save(f"{OUT}/B2_lightened_panels.jpg"))


if __name__ == "__main__":
    b1()
    b2()
