#!/usr/bin/env python3
"""Owner review 2026-09-28 -- Group A, controls and machinery feedback.

    python3 tools/owner_review_2026_09_28/build_A.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sheets import Panel, Sheet  # noqa: E402

REV = "docs/art/review"
OUT = f"{REV}/owner_review_2026-09-28/sheets"
EV = f"{REV}/owner_review_2026-09-28/evidence"
FOOT = ("Art source 32df699. Production read at c12a72fbc625 (pinned); its "
        "frames come from its own drivers (make candidate-shots / zone-shots), "
        "run on a scratch copy. Nothing here changes a status.")


def a1() -> None:
    s = Sheet("A1 · Controls: momentary, held, reversible, permanent",
              "What the game draws today, beside the candidate controls. The "
              "owner's D-07 ruling (24 Sept, quoted in Production's code) already "
              "asks for 'a visibly different permanent control such as a lever, "
              "locking bolt'.")
    s.statuses(
        visual=("pending", "028 PENDING (ART_REVIEW.md:3412). 043 is in the "
                "pending band. 049 PENDING, 22 Sept (:4562)."),
        compat=("partial", "043's switch has a working hinge and a "
                "'how_to_drive' contract. The 049 parts have names but no "
                "pivots, poses or colliders. 028 changes state only by "
                "recolouring."),
        binding=("none", "None. The registry names no int_/mach_/conn_ asset."),
        play=("partial", "Normal play has held plates and the warp-station "
              "repair, both code-built. The permanent lever and the reversible "
              "setter exist only in the opt-in candidate profile."))
    s.row([Panel(f"{EV}/prod_c12a72f/candidate_01_lever_and_its_doorway_shut.jpg",
                 "Today: Production's lever, a box plinth and a box arm.",
                 tag="PLACEHOLDER", note="candidate profile (off by default); "
                 "call_lever.gd:20-21"),
           Panel(f"{EV}/prod_c12a72f/candidate_02_lever_pulled_doorway_open.jpg",
                 "Pulled with the interact ray: the doorway opens.",
                 tag="PLACEHOLDER", note="a real pull; the frame is Production's own")])
    s.row([Panel(f"{EV}/prod_c12a72f/zone_close_pressure_routing.jpg",
                 "Today, in normal play: pressure pads, live only while weighted.",
                 tag="PLACEHOLDER"),
           Panel(f"{EV}/prod_c12a72f/zone_close_switch_sequence.jpg",
                 "Today, in normal play: switch posts you walk into.",
                 tag="PLACEHOLDER")])
    s.row([Panel(f"{EV}/A/connect_conn_hold_paddle_rerender.jpg",
                 "049 sprung paddle: meant as HELD.", tag="POSED", crop="auto",
                 note="one pose only; no pivot"),
           Panel(f"{EV}/A/connect_conn_set_dial_rerender.jpg",
                 "049 detent dial: a SETTING.", tag="POSED", crop="auto",
                 note="8 detents; no pivot"),
           Panel(f"{EV}/A/connect_conn_repair_seal_rerender.jpg",
                 "049 frangible seal: PERMANENT.", tag="POSED", crop="auto",
                 note="the tabs are nodes; broken = hidden")])
    s.row([Panel(f"{REV}/machinery_2026-09-11/room/MACH_switch_off.png",
                 "043 wall switch, OFF: the lever's pose is the state.",
                 tag="POSED", note="the only candidate with a working hinge"),
           Panel(f"{REV}/machinery_2026-09-11/room/MACH_switch_on.png",
                 "043 wall switch, ON.", tag="POSED",
                 note="receiver lamp beside the door")])
    s.row([Panel(f"{EV}/A/A_028_switch_and_plate_new.jpg",
                 "OLDER, 028 as revised at 035-R: the switch post and the weight "
                 "plate. Their state shows only in the plate's colour.", tag="NEW"),
           Panel(f"{EV}/A/connect_a_source_rerender.jpg",
                 "049 in place on the source wall: paddle, dial, seal, plaque, "
                 "and the run leaving.", tag="RENDER",
                 note="re-rendered tonight: the textures were re-baked on 24 Sept; "
                      "geometry is unchanged")])
    s.text("The words already mean something in Production",
           "LATCH = permanent: 'set by a true input and never reset' "
           "(signal_graph.gd:495). A reversible setting is ZoneState, set with the "
           "same CallLever. 'Held' = a pressure plate (PoweredLink: 'a door that "
           "opens when it is held'). A lever is momentary and springs back in "
           "0.35 s (call_lever.gd:23). No hand control is held down anywhere.")
    s.decision(
        ask="(1) Give each commitment its own silhouette (momentary, reversible, "
            "permanent), starting with the permanent control D-07 asks for? "
            "(2) Is the 049 paddle Production's momentary spring-back control, "
            "with 'held' kept for plates?",
        recommend="(1) Yes, permanent first: a lever that visibly locks, or the "
                  "049 seal. (2) Recaption the paddle as momentary; say 'held' "
                  "with the plate language (028 weight plate plus a sign).",
        risk="The tells (spring, teeth, tabs) are hand-scale, and 035-R ruled that "
             "a distinction must live in the object-scale SILHOUETTE. At room "
             "distance the 049 pieces read as grey blocks. Plates are 0.96 m in art "
             "and 1.4 / 2.4 m in Production.",
        engineering="Pivots and declared poses for the 049 moving parts (none "
                    "today), colliders, a placement contract (Production's levers "
                    "stand on the floor; this art mounts on walls), and a state "
                    "driver.")
    s.footer(FOOT + " D-07: prod@c12a72f room_graphs.gd:250-255.")
    print(s.save(f"{OUT}/A1_controls_commitments.jpg"))


def a2() -> None:
    s = Sheet("A2 · Machine state: conduits, receivers, plaques",
              "043's conduit band carries five states. The 049 fittings extend it "
              "round corners and walls, and 049 says it 'extends' 043, not "
              "replaces it.")
    s.statuses(
        visual=("pending", "043 is in the pending band; 049 PENDING, 22 Sept."),
        compat=("partial", "state_band and fill_band nodes; the tee has two "
                "bands. The reader panel has 4 state nodes and no 'refused'."),
        binding=("none", "None. Nothing drives signal-graph visuals."),
        play=("no", "No. Production shows signal state with prompts and a remote "
              "box lamp or barrier."))
    s.row([Panel(f"{REV}/machinery_2026-09-11/room/MACH_five_states.png",
                 "043 band: inactive, active, pulse travelling, blocked, delayed.",
                 tag="POSED"),
           Panel(f"{REV}/machinery_2026-09-11/room/MACH_close_inactive_vs_blocked.png",
                 "Inactive vs blocked: brightness AND pattern, not hue.",
                 tag="POSED")])
    s.row([Panel(f"{EV}/A/connect_b_route_rerender.jpg",
                 "049 route: the band carried along the wall.", tag="POSED"),
           Panel(f"{EV}/A/connect_e_reverse_rerender.jpg",
                 "049 reverse view: the same route from the far end.", tag="POSED")])
    s.row([Panel(f"{EV}/A/connect_c_destination_rerender.jpg",
                 "049 destination, powered.", tag="POSED"),
           Panel(f"{EV}/A/connect_d_destination_unpowered_rerender.jpg",
                 "Unpowered: only the band tint differs.", tag="POSED",
                 note="the green tint previews addressability; it is not runtime")])
    s.row([Panel(f"{EV}/prod_c12a72f/candidate_03_the_lamp_past_the_doorway_lit.jpg",
                 "Today: a lamp past the doorway lights when the lever is pulled.",
                 tag="PLACEHOLDER", note="candidate profile; the setter's state "
                 "shows only in the prompt: '(now X · PENDING/ACCEPTED)'"),
           Panel(f"{EV}/A/connect_conn_id_plaque_rerender.jpg",
                 "049 relationship plaque: its id field is blank for a runtime to "
                 "fill. 'R-14' is only the harness caption.", tag="POSED",
                 crop="auto")])
    s.decision(
        ask="(1) Judge the 043 band with the 049 fittings as ONE family: is this "
            "the machine-state vocabulary? (2) Is cross-room identity carried by "
            "a world plaque, by the map's circuit colour (H-CIRCUITS), or both?",
        recommend="(1) Yes as a candidate family, 043's node contract (hinge plus "
                  "how_to_drive) as the baseline. (2) Settle H-CIRCUITS first; add "
                  "a plaque only if the map is not enough.",
        risk="Five states share one band. 'Delayed' also wants audio that does "
             "not exist. The 11 Sept 'disagreeing' frame lights a hazard-orange "
             "lens, which that README says the kit never uses (evidence defect).",
        engineering="A visual driver on the signal graph, something that fills "
                    "the plaque's field, and the delayed-state audio.")
    s.footer(FOOT)
    print(s.save(f"{OUT}/A2_machine_state_language.jpg"))


if __name__ == "__main__":
    a1()
    a2()
