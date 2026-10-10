#!/usr/bin/env python3
"""Owner review 2026-09-28 -- Group C, the 0.4 moving machinery and room kits.

    python3 tools/owner_review_2026_09_28/build_C.py

"Today" frames are Production's own at c12a72f: its railway shot driver
for the Blindside yard, and capture_scenario.gd (this folder) run on a
scratch copy for the three minor rooms.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sheets import Panel, Sheet  # noqa: E402

REV = "docs/art/review"
OUT = f"{REV}/owner_review_2026-09-28/sheets"
PC = f"{REV}/owner_review_2026-09-28/evidence/prod_c12a72f"
SP, YK, SK, RK = (f"{REV}/setpieces_2026-09-22", f"{REV}/yardkit_2026-09-22",
                  f"{REV}/skiffkit_2026-09-22", f"{REV}/roomkits_2026-09-22")
FOOT = ("Art source 32df699. Production read at c12a72fbc625 (pinned). The 22 "
        "Sept fits were made against f404410 and re-checked tonight against "
        "c12a72f. Nothing here changes a status.")


def c1() -> None:
    s = Sheet("C1 · The Blindside yard and the skiff (045, 046, 047)",
              "Production's railway yard as its own shot driver sees it today, "
              "beside the yard kit and the skiff kit. It is the owner-reviewed "
              "dev yard (--railway); no Zone declares rails yet.")
    s.statuses(
        visual=("pending", "All PENDING, candidates of 22 Sept "
                "(ART_REVIEW.md:4064, 4108, 4609)."),
        compat=("partial", "The 22 Sept fit still matches the dev yard at "
                "c12a72f: its sources are unchanged. Zone railways use another "
                "deck (3.4 x 0.35 x 5.0) and gantry, and nothing was fitted to "
                "them."),
        binding=("none", "None. RailCarrier still builds a BoxMesh "
                 "(rail_carrier.gd:129-131); there is no hook."),
        play=("no", "No. --railway is operator-only scaffolding "
              "(railway_scenario.gd:3-20)."))
    s.row([Panel(f"{PC}/railway_1_boarding.jpg", "Today: boarding at S1.",
                 tag="PLACEHOLDER", note="Production's own camera, 4-9 m up, "
                 "not eye height"),
           Panel(f"{PC}/railway_3_the_lever.jpg", "Today: the alignment "
                 "gantry and its lever.", tag="PLACEHOLDER")])
    s.row([Panel(f"{YK}/dock_assembly.png", "Yard kit: the dock and track, on "
                 "Production's own grey greybox.", tag="RENDER", crop="auto"),
           Panel(f"{YK}/gantry_assembly.png", "Yard kit: the gantry.",
                 tag="RENDER", crop="auto", note="the frame adds a soffit that "
                 "Production's open-sky yard does not have")])
    s.row([Panel(f"{YK}/span_stowed.png", "The span stowed (62 deg).",
                 tag="POSED", crop="auto"),
           Panel(f"{YK}/span_aligned.png", "The span aligned: the repair made.",
                 tag="POSED", crop="auto")])
    s.row([Panel(f"{SK}/rider_eye_boarding.png", "Skiff kit, from a rider's eye "
                 "(1.6 m): boarding.", tag="POSED"),
           Panel(f"{SK}/rider_eye_over_shield.png", "Over the shield: 0.35 m "
                 "clearance at eye height.", tag="POSED")])
    s.row([Panel(f"{SK}/loaded_outside.png", "The loaded skiff from outside: "
                 "bare hull, shield, end guard, bogie.", tag="RENDER",
                 crop="auto"),
           Panel(f"{PC}/railway_4_aboard.jpg", "Today: aboard the skiff at S2.",
                 tag="PLACEHOLDER")])
    s.decision(
        ask="(1) Judge the Blindside kit on the dev yard now, and re-fit only "
            "when a Zone declares rails? (2) Skiff: one-piece deck, or bare hull "
            "plus shield and rail? (3) Approve the binding approach (an "
            "optional authored mesh replacing the BoxMesh, with the BoxMesh as "
            "fallback) as the vehicle for H-MACHINE-ART?",
        recommend="(1) Yes. (2) The kit; the bogie is optional, since it can't be "
                  "seen from outside. (3) Yes, meshes only.",
        risk="19 pieces reach no player until a Zone has rails. Each binding "
             "must re-pass Production's claim, V-10 and foothold suites.",
        engineering="A mesh hook in RailCarrier / ShuttleDeck; H-MACHINE-ART "
                    "dispatched (it is 'PLANNED, NOT DISPATCHED'); a switch "
                    "schema before any Zone uses points.")
    s.footer(FOOT + " Defects: sp_skiff_deck(_bare) lamp_fore sits at -Z, which "
             "is the TRAILING end (runtime forward is +Z, rail_carrier.gd:420), "
             "so swap the names. rider_eye_crouched.png shows a crouch the game "
             "does not have.")
    print(s.save(f"{OUT}/C1_blindside_yard_and_skiff.jpg"))


def c2() -> None:
    s = Sheet("C2 · The three rooms: Passing, Counterfire, Unweighted",
              "Each room as Production builds it today (its own scenario, "
              "photographed tonight), beside the candidate kit. The owner has "
              "already ruled on the ROOMS: Passing and Unweighted 'OWNER REJECTS "
              "CURRENT ROOM EXPERIENCE'; Counterfire 'OWNER RECHECK / IDENTITY "
              "UNCERTAIN'.")
    s.statuses(
        visual=("pending", "048 PENDING (ART_REVIEW.md:4152); the room pieces of "
                "045 PENDING."),
        compat=("no", "Changed since 22 Sept: the Unweighted plate is now a "
                "2.4 x 4.5 m weighbridge, the crate a guided service carriage, "
                "and the rails 0.45 m (were 1.4). Passing gained a glass gallery "
                "and gate."),
        binding=("none", "None; only a material hook exists "
                 "(ServiceShutter.panel_material)."),
        play=("no", "No. Hosted only by the opt-in candidate profile."))
    for room, key, kit, cap in [
            ("PASSING PLATFORMS", "passing-platforms", f"{RK}/pp_rendezvous.png",
             "Kit: lift guide, transfer edges and call post at the rendezvous."),
            ("COUNTERFIRE ARCADE", "counterfire", f"{RK}/cf_lane.png",
             "Kit: the gunner mount and lane marks along the exit lane."),
            ("UNWEIGHTED SWITCH", "unweighted", f"{RK}/uw_switch.png",
             "Kit: plate frame, drive housing, applicator and return rail.")]:
        s.row([Panel(f"{PC}/room_{key}_player_eye.jpg", f"{room} today, at "
                     "the player's eye.", tag="PLACEHOLDER",
                     note="from the spawn point, turned to face the room"),
               Panel(f"{PC}/room_{key}_wide_reviewcam.jpg", "Today, from a "
                     "review camera.", tag="PLACEHOLDER",
                     note="a framing aid, not a player view"),
               Panel(kit, cap, tag="RENDER", crop="auto",
                     note="on an art-drawn greybox")])
    s.decision(
        ask="Hold these kits until the rooms are accepted, then re-brief them to "
            "the repaired rooms (weighbridge, guided carriage, glass gate) before "
            "judging the pieces?",
        recommend="Yes, hold. Art should then deliver the glass gate (A06.5; the "
                  "gate state now exists), and decide whether to dress Passing's "
                  "13 labelled levers one by one.",
        risk="Approving pieces fitted to rooms that have since changed, or that "
             "the owner has rejected, would bind the wrong thing.",
        engineering="The room repairs accepted by the owner first; then the same "
                    "optional-mesh hook as C1.")
    s.footer(FOOT + " Measured defects: crossing-carrier buffers on the sides, "
             "not the ends; the hoist car's back on the transfer face; "
             "uw_plate_frame's wall across the drive corridor; uw_drive_housing "
             "over the guide rails; cf_shutter_track's head inside the leaf's "
             "2.6 m rise; cf_lane_mark growing out under the walls. The evidence "
             "frames draw greyboxes Production never built.")
    print(s.save(f"{OUT}/C2_three_rooms.jpg"))


if __name__ == "__main__":
    c1()
    c2()
