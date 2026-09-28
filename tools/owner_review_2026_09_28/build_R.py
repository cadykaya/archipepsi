#!/usr/bin/env python3
"""Owner review 2026-09-28 -- the ordinary-room reuse sheet.

    python3 tools/owner_review_2026_09_28/build_R.py

Existing rooms only: geometry and contract, never an encounter layout.
Plans come from plan_from_glb.py (the model's own faces); eye views are
existing renders whose geometry is unchanged since (checked), except the
cross, re-rendered tonight because its geometry moved.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sheets import Panel, Sheet  # noqa: E402

REV = "docs/art/review"
OUT = f"{REV}/owner_review_2026-09-28/sheets"
RM = f"{REV}/owner_review_2026-09-28/evidence/rooms"
PC = f"{REV}/owner_review_2026-09-28/evidence/prod_c12a72f"
FOOT = ("Geometry only: no shell here establishes enemy navigation, spawns or "
        "encounter pacing. Art source 32df699; Production read at c12a72fbc625. "
        "Nothing is relabelled, resized, promoted or re-weighted.")

ROOMS = [
    ("corridor_bays", "1 · shell_corridor_bays (015)", "WITHHELD",
     "REUSE, small / connector",
     "9.6 x 4.5 x 16 m. A 6 x 16 m lane at grade, with four 1.6 x 2.8 m bays at "
     "grade, alternating sides. Entry and exit at grade, at the two ends. "
     "Beyond a box: pockets off a clear lane, so cover, a Check or an enemy "
     "can sit off the route. Contract: the old manifest (no surfaces, sockets "
     "or size class), and an open-ended tube where Production's corridors "
     "have end walls."),
    ("corridor_gallery", "2 · shell_corridor_gallery (015)", "WITHHELD",
     "REUSE, standard",
     "8.8 x 5.9 x 20 m. An 8 x 20 m floor at grade, plus a 2.6 x 14 m side "
     "deck at +2.6 m with a rail, reached by an 8-step stair (0.325 m risers). "
     "Doors at grade. Beyond a box: two routes and high ground at corridor "
     "scale. The Check anchor is on the deck."),
    ("arena_pillars", "3 · shell_arena_pillars (016)", "WITHHELD",
     "REUSE, standard / large",
     "22.8 x 5.9 x 22.8 m. 22 x 22 m at grade, a 4 x 4 grid of columns at a "
     "4.4 m pitch, 3.2 m aisles, the centre aisle clear (open floor 0.915). "
     "Doors at grade, front and back. Beyond a box: cover that is structure, "
     "not scattered props."),
    ("arena_balcony", "4 · shell_arena_balcony (016)", "WITHHELD",
     "REUSE, large",
     "26.8 x 8.9 x 24.8 m. An open plate at grade, with a 2.4 m walkway at "
     "+3.2 m on three sides and a stair. Doors at grade. Beyond a box: height "
     "without clutter; a 24 m sightline. It sits inside the fallback's "
     "landmark-arena range (24-28 x 22-26 x 6.5-8.0 m)."),
    ("junction_triad", "5 · shell_junction_triad (044)", "CANDIDATE",
     "REUSE, large (a through-room)",
     "26 x 8.7 x 26 m. A 12 m spine, a 6.4 x 7 m arm to the east and a "
     "6.4 x 7 m bay to the west, all at grade, plus an overlook block with a "
     "raised enemy socket at +2.8 m. Entry, exit and branch_east, all at grade. "
     "Beyond a box: the plan, not props, makes the spaces. Not in Production's "
     "registry, and no chamber type is declared."),
    ("tower_collapsed", "6 · shell_tower_collapsed (018)", "OFFERABLE",
     "ADAPT",
     "12.8 x 11.5 x 14.6 m. 12 x 12 m at grade, half-floors 10.8 x 6.6 m at "
     "+3 and +6 m, and a 7.4 x 4 m deck at +6 m. Entry at grade; EXIT AT "
     "+6.0 m, by 1 m rises (walkable). Beyond a box: the one live split-level "
     "room below large. But Production's fallback never creates a tower "
     "chamber, and an exit 6 m up is not an ordinary room's exit."),
]


def status_of(state: str) -> tuple:
    return {"WITHHELD": ("held", "Withheld on purpose: fixed size vs per-chamber "
                         "size (req 35 / the 015-019 owner blocker)."),
            "CANDIDATE": ("pending", "Candidate: 044 PENDING, 13 Sept."),
            "OFFERABLE": ("yes", "Offerable: PASS, and Production's gate "
                          "passes it.")}[state]


def r0() -> None:
    s = Sheet("R0 · Ordinary rooms today",
              "What Production builds now, photographed by its own zone-shot "
              "driver at c12a72f, and the rules that decide when an authored "
              "shell can replace it.")
    s.statuses(
        visual=("yes", "12 shells PASS and exported; 11 more PASS but "
                "withheld (015-017); 3 candidates (044)."),
        compat=("partial", "adopt() now writes a shell's size into the chamber "
                "(shells.py:544), which is req 35's own second option. Nothing "
                "has re-ruled 015-017 since."),
        binding=("partial", "The 12 exported shells are offered in every live "
                 "request (epsilon/requests.py:167)."),
        play=("partial", "Offerable is not frequent: see the fallback rules "
              "below."))
    s.row([Panel(f"{PC}/zone_00_room_c002_gallery_left.jpg", "A gallery-band "
                 "room today.", tag="PLACEHOLDER"),
           Panel(f"{PC}/zone_02_room_c005_pit_left.jpg", "A pit-band room today.",
                 tag="PLACEHOLDER")])
    s.row([Panel(f"{PC}/zone_01_room_c020_gallery_left.jpg", "Crates and a "
                 "pillar in a gallery room.", tag="PLACEHOLDER"),
           Panel(f"{PC}/zone_04_room_c011_gallery_left.jpg", "Another ordinary "
                 "room, with its activity.", tag="PLACEHOLDER")])
    s.text("How the fallback picks rooms at the pin (read from its code)",
           "It never creates a tower or treasure_room chamber. A corridor whose "
           "features fit a 6 m interior becomes a 6 x 6 m corner shell. 55% of "
           "arenas get a gallery or pit band, and no shell declares "
           "provides_elevation, so a banded arena always stays procedural. "
           "Authored footprint is capped at 4000 m2 per Zone "
           "(AUTHORED_AREA_BUDGET). The player now steps up 1.0 m unaided; enemy "
           "footing tolerates 0.6 m per sample, so a 1 m level change is not yet "
           "shown walkable for enemies.")
    s.footer(FOOT)
    print(s.save(f"{OUT}/R0_ordinary_rooms_today.jpg"))


def r_examples(part: int, rooms: list) -> None:
    s = Sheet(f"R{part} · Existing rooms we could reuse ({'1-3' if part == 1 else '4-6'} of 6)",
              "Each: the room at eye height (an existing render; geometry "
              "unchanged since, checked) and a roof-off plan from the model's "
              "own faces. Pale = grade, amber = raised, cream = steps, dark = "
              "solid.")
    for key, title, state, verdict, body in rooms:
        st, words = status_of(state)
        s.text(f"{title} — {verdict}", f"{state}. {words}")
        extra = ""
        s.row([Panel(f"{RM}/R_eye_{key}.jpg", "At eye height.", tag="RENDER",
                     note="rendered before the 24 Sept texture re-bake; shape "
                          "unchanged" if key != "junction_triad" else
                          "13 Sept render; shape unchanged"),
               Panel(f"{RM}/R_plan_{key}.png", "Roof-off plan, with doors and "
                     "levels.", tag="PLAN")])
        s.text("", body + extra)
    if part == 2:
        s.decision(
            ask="Which of these go into the small / standard / large ordinary-room "
                "discussion as REUSE candidates, before anything new is "
                "commissioned?",
            recommend="Bays (small), gallery and pillars (standard), balcony and "
                      "triad (large; the triad only once branching rooms are "
                      "ruled on). The tower is an ADAPT reference.",
            risk="None of these is an encounter layout. The withheld ones also "
                 "need the old manifests brought up to the room contract "
                 "(surfaces, sockets, traversal, size class, colliders), which is "
                 "retrofit work, as P2 was.",
            engineering="Re-rule req 35 now that adopt() exists; a chamber type "
                        "for the 044 rooms; a provider that makes tower "
                        "chambers, if a tower is ever wanted. No selection-"
                        "frequency change is proposed.")
    s.footer(FOOT)
    print(s.save(f"{OUT}/R{part}_room_reuse_{'a' if part == 1 else 'b'}.jpg"))


def r3() -> None:
    s = Sheet("R3 · Alternates and poor fits (for the record)",
              "Three more, compactly, then the ones that do not help the box "
              "problem.")
    for key, title, verdict, body in [
            ("arena_pit", "shell_arena_pit (016, withheld)", "REUSE, standard",
             "18.8 x 7.9 x 18.8 m: a 3 m rim at grade around a 12 x 12 m pit at "
             "-1.0 m. It overlaps Production's own procedural pit band."),
            ("junction_cross", "shell_junction_cross (044, candidate)",
             "ADAPT",
             "30 x 9.7 x 30 m: an 18 x 18 m ring around an 8 x 8 m plant, with "
             "four doors at grade. The strongest non-box plan, but bigger than "
             "any procedural arena (28 m max), and half the ring is a 2.5 m "
             "passage. Re-rendered tonight: the old frames showed the "
             "pre-redesign cross."),
            ("treasure_coffer", "shell_treasure_coffer (019, offerable)",
             "POOR FIT for the box complaint",
             "8.8 x 6.3 x 8.8 m: an 8 x 8 m floor and a 0.8 m plinth. The same "
             "envelope as the procedural treasure room, and the fallback never "
             "makes treasure rooms.")]:
        s.text(f"{title} — {verdict}", body)
        s.row([Panel(f"{RM}/R_eye_{key}{'_rerender' if key == 'junction_cross' else ''}.jpg",
                     "At eye height.", tag="NEW" if key == "junction_cross"
                     else "RENDER"),
               Panel(f"{RM}/R_plan_{key}.png", "Roof-off plan.", tag="PLAN")])
    s.text("Poor fits, not illustrated",
           "shell_corridor_narrow (it IS the box). The three platform paths "
           "(017), which are jumps over a void and have no floor. The spiral "
           "and gantry towers (9 m and 15 m climbs). The two corners, which are "
           "connectors and are already adopted by fallback corridors. "
           "shell_corridor_stepped is ADAPT: its Check anchor is on a 2.6 m ledge, "
           "1.6 m above the high half, more than the 1.333 m jump apex, so "
           "reaching it is unproven.")
    s.footer(FOOT)
    print(s.save(f"{OUT}/R3_room_alternates.jpg"))


if __name__ == "__main__":
    r0()
    r_examples(1, ROOMS[:3])
    r_examples(2, ROOMS[3:])
    r3()
