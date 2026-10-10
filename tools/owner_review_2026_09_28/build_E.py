#!/usr/bin/env python3
"""Owner review 2026-09-28 -- Group E, the source-game packs T01-T07.

    python3 tools/owner_review_2026_09_28/build_E.py

Reads existing evidence and tonight's fixed-light renders; writes the E
sheets into docs/art/review/owner_review_2026-09-28/sheets/.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sheets import Panel, Sheet  # noqa: E402

REV = "docs/art/review"
OUT = f"{REV}/owner_review_2026-09-28/sheets"
EV = f"{REV}/owner_review_2026-09-28/evidence/E"
FOOT = ("Art source 32df699 (evidence reused as committed). Production read at "
        "c12a72fbc625 (pinned). Nothing here changes a status.")


def e1() -> None:
    s = Sheet("E1 · T01 and T05: their own textures, in one room",
              "Same shell (junction cross), same camera, same fixed light; only "
              "the texture rows change. Rendered 2026-09-25 after T05's floor "
              "was calmed. No props in frame.")
    s.statuses(
        visual=("partial", "T01: accepted for candidate status (25 Sept). T05: "
                "accent accepted and floor calmed (25 Sept); no candidate-status "
                "sentence was recorded for T05."),
        compat=("partial", "Rows passed Production's own pack-table check and "
                "resolver on 24-25 Sept (art gates; not re-run tonight)."),
        binding=("none", "None. THEME_PACK_STATUS is {} at the pin, and "
                 "Production's copy of THEME_PACK.json has no pack rows."),
        play=("no", "No. Zone composition never names a pack."))
    s.row([Panel(f"{REV}/packs_2026-09-24/PACK_family_backstop.png",
                 "House temple_ruin: what a Zone gets today.", tag="RENDER"),
           Panel(f"{REV}/packs_2026-09-24/PACK_forest_temple.png",
                 "T01 Forest Temple (Ocarina of Time): a darker interior, moss "
                 "rising from below, brass gone green.", tag="RENDER")])
    s.row([Panel(f"{REV}/packs_2026-09-24/PACK_twilight_town.png",
                 "T05 Twilight Town (Kingdom Hearts 2): plaster and timber, a "
                 "brick plinth, flags with a sett border.", tag="RENDER"),
           Panel(f"{REV}/packs_2026-09-24/SHEET_tiles.png",
                 "The tiles flat: accent, floor, wall; family, T01, T05.",
                 tag="RENDER",
                 note="The T05 accent carries the word MARKET baked in.")])
    s.text("Found tonight (nothing repaired)",
           "1. Both packs inherit temple_ruin's unsnapped course pitch "
           "(0.95 m wall, 1.30 m floor on a 4 m tile), leaving a 2-8 px sliver at "
           "each tile edge (tools/blender/packmaterials.py:91, :115). The pending "
           "temple_ruin course ruling (055) decides it for the family and both "
           "packs together. 2. T01's floor has a paler worn band baked into the "
           "tile, so it repeats every 4 m (:120-127). 3. T05's accent bakes the "
           "word MARKET (:307), so every accent surface would say it.")
    s.decision(
        ask="(a) Which id does a Zone name for these packs: forest_temple / "
            "twilight_town (the texture rows) or tp_ocarina_of_time / "
            "tp_kingdom_hearts_2 (the catalogue and the props)? (b) Rule "
            "temple_ruin's course treatment before any T01/T05 status change?",
        recommend="One id per pack, the catalogue's tp_* ids, since the props "
                  "already use them. Keep both at candidate until temple_ruin's "
                  "course is ruled. Say whether MARKET may repeat on every accent "
                  "surface.",
        risk="Status granted to one id while the art sits under the other binds "
             "nothing. Ruling T05 before the course question means repainting it.",
        engineering="Descriptor keys and a THEME_PACK_STATUS entry under the chosen "
                    "id; a selection rule (none exists: 'Composition never sets "
                    "it', zone.py:1518). Then re-export the rows.")
    s.footer(FOOT + " Sources: packs_2026-09-24/README.md:58-86; ART_FRONTIER.md:"
             "2406-2409; prod@c12a72f theme_pack.gd:30-47, constants.gd:203.")
    print(s.save(f"{OUT}/E1_T01_T05_textures_same_room.jpg"))


PACKS = [
    ("T01", "ocarina_of_time", "Ocarina of Time · Forest Temple", "temple_ruin",
     "a place losing to the forest: rooted column, split relief, timber torch"),
    ("T02", "super_mario_64", "Super Mario 64 · Tick Tock Clock", "rusted_industrial",
     "a torque shaft for a column, a parted clock movement, a dial for a door"),
    ("T03", "bomb_rush_cyberfunk", "Bomb Rush Cyberfunk · Brink Terminal",
     "neon_transit", "tags and wear at grind height, a board mid-flip, one tube out"),
    ("T04", "super_metroid", "Super Metroid · the Wrecked Ship", "rusted_industrial",
     "boxed ship frames, a hatch on one hinge, a lamp hanging off true"),
    ("T05", "kingdom_hearts_2", "Kingdom Hearts 2 · Twilight Town", "temple_ruin",
     "soft goods: an awning, a pier carrying a wire, a four-layer hoarding"),
    ("T06", "doom_1993", "DOOM (1993) · UAC techbase", "concrete_facility",
     "a column that carries information, cable loops, light as a recess"),
    ("T07", "dark_souls_iii", "Dark Souls III · High Wall of Lothric", "gothic_stone",
     "a pier taking sideways thrust, a pointed arch, a floor brazier"),
]


def e2() -> None:
    s = Sheet("E2 · The seven prop packs, one light",
              "Re-rendered tonight: the house room alone, then each pack's six "
              "props, all in one shell with one camera and ONE fixed light. The "
              "22 Sept frames each had their own lighting, so they could not be "
              "compared.")
    s.statuses(
        visual=("pending", "No owner verdict on any prop set. 054 PENDING; "
                "056-061 'PROPOSAL. Not imported, not runtime-bound, not "
                "owner-approved.'"),
        compat=("partial", "Loaded in the review scene only; tonight's doorway "
                "check passes for all seven (it also proved it catches a surround "
                "moved 0.5 m into the opening)."),
        binding=("none", "None. ThemePack binds textures only; nothing in "
                 "Production loads a pack prop."),
        play=("no", "No."))
    frames = [("T00", "house_baseline", "HOUSE BASELINE: no pack", "", "")] + PACKS
    for i in range(0, len(frames), 2):
        row = []
        for tag, key, name, fam, line in frames[i:i + 2]:
            cap = name if tag == "T00" else f"{tag} {name}"
            note = ("The house room alone: the grey is Production's shell."
                    if tag == "T00" else
                    (f"{line}. Props painted in {fam}; the pack's own textures "
                     "(E1) are not on them." if tag in ("T01", "T05") else
                     f"{line}. Painted in {fam}: the pack has no pixels of its own."))
            row.append(Panel(f"{EV}/E2_{tag}_{key}_fixed_light.jpg", cap,
                             tag="NEW", note=note))
        s.row(row)
    s.text("Read this before deciding",
           "Every prop is painted in its house family, so for T02, T03, T04, T06 "
           "and T07 the identity is carried by SHAPE alone; only T01 and T05 have "
           "textures of their own (E1). T01 and T05 share temple_ruin, and in "
           "22 Sept's own test the pixels won over the geometry.")
    s.decision(
        ask="For each pack: is this the right architectural identity for its "
            "game? Rule the principle once ('one stated subtheme per game') and "
            "then a yes/no per pack. A yes records 'identity accepted'; status "
            "stays candidate.",
        recommend="Judge silhouettes from this sheet now. Hold 'differs from the "
                  "house family' for T02-T04, T06 and T07 until the pack has its "
                  "own pixels. That is new work, and only on your say-so.",
        risk="A yes can be misread as a status change. Production's fallback "
             "hands Super Mario 64 to concrete_facility and Super Metroid to "
             "neon_transit, not the families these packs were built on, so a "
             "family-keyed pack would bind nothing there.",
        engineering="A runtime seam for pack PROPS (none exists), a selection "
                    "rule, and a status per pack. No mapping change is proposed.")
    s.footer(FOOT + " Renders: tools/owner_review_2026_09_28/run_packs_fixed_light.sh "
             "(layouts copied from tools/content/packlayouts with one light block). "
             "Fallback checked by running prod@c12a72f epsilon/fallback.py _theme_for.")
    print(s.save(f"{OUT}/E2_seven_prop_packs_one_light.jpg"))


def e3() -> None:
    s = Sheet("E3 · Each pack's signature frame (its own mood light)",
              "The 22 Sept close frames, reused as-is: they show each pack's "
              "one idea close up. Their lights differ on purpose, so compare "
              "shapes here and use E2 for anything side by side.")
    s.statuses(
        visual=("pending", "Proposal; not owner-approved."),
        compat=("partial", "Fit-checked in the art harness on 22 Sept."),
        binding=("none", "None."),
        play=("no", "No."))
    sig = [("forest_temple", "FT_relief", "T01 · the split relief with a rooted column"),
           ("clockwork", "CK_movement", "T02 · the parted clock movement"),
           ("brink", "BR_board", "T03 · the departure board, mid-flip"),
           ("wreck", "WS_panel", "T04 · the hull panel, hatch on one hinge"),
           ("twilight", "TW_hoarding", "T05 · the four-layer hoarding"),
           ("foundry", "DM_screens", "T06 · the interface wall and its cable loops"),
           ("lothric", "DS_channel", "T07 · the channel, its corbels, the brazier")]
    for i in range(0, len(sig), 2):
        s.row([Panel(f"{REV}/{d}_2026-09-22/{f}.png", cap, tag="RENDER",
                     note=f"docs/art/review/{d}_2026-09-22/{f}.png")
               for d, f, cap in sig[i:i + 2]])
    s.footer(FOOT)
    print(s.save(f"{OUT}/E3_pack_signature_frames.jpg"))


if __name__ == "__main__":
    e1()
    e2()
    e3()
