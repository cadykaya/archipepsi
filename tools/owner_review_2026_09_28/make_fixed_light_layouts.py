#!/usr/bin/env python3
"""Owner review 2026-09-28 -- the seven T01-T07 layouts under ONE light.

Reads tools/content/packlayouts/<pack>.json (unchanged) and writes copies to
tools/owner_review_2026_09_28/packs_fixed_light/ in which:
  * the light block is the same fixed rig for every pack;
  * only the shared approach camera is kept (the seven layouts already
    share its eye and look), renamed so no file collides with the
    published 2026-09-22 frames;
  * one extra layout, `house_baseline`, places no pack at all: the house
    room alone, same camera, same light.
Props, positions and the opening check are the layouts' own.
"""
import json
import os

SRC = "tools/content/packlayouts"
OUT = "tools/owner_review_2026_09_28/packs_fixed_light"
PACKS = ["tp_ocarina_of_time", "tp_super_mario_64", "tp_bomb_rush_cyberfunk",
         "tp_super_metroid", "tp_kingdom_hearts_2", "tp_doom_1993",
         "tp_dark_souls_iii"]
TAG = {"tp_ocarina_of_time": "T01", "tp_super_mario_64": "T02",
       "tp_bomb_rush_cyberfunk": "T03", "tp_super_metroid": "T04",
       "tp_kingdom_hearts_2": "T05", "tp_doom_1993": "T06",
       "tp_dark_souls_iii": "T07"}
# One neutral rig for all seven: a warm key, a cool fill, a soft front
# fill, and the same ambient and fog. Chosen to show form, not mood.
FIXED = {
    "ambient": [0.62, 0.64, 0.68], "ambient_energy": 0.32,
    "fog": 0.018, "fog_color": [0.22, 0.24, 0.26],
    "lamps": [
        {"at": [3.6, 2.4, -1.0], "range": 8.0, "energy": 2.6,
         "color": [1.0, 0.93, 0.84], "why": "fixed review key, the same for every pack"},
        {"at": [-3.6, 2.4, -3.0], "range": 8.0, "energy": 2.0,
         "color": [0.88, 0.93, 1.0], "why": "fixed review fill"},
        {"at": [0.0, 2.8, 2.5], "range": 9.0, "energy": 0.9,
         "color": [1.0, 1.0, 1.0], "why": "fixed front fill"},
    ],
}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    approach = None
    for pack in PACKS:
        lay = json.load(open(os.path.join(SRC, pack + ".json")))
        shot = dict(lay["shots"][0])
        assert shot["name"].endswith("_approach"), shot["name"]
        approach = approach or (shot["eye"], shot["look"])
        assert (shot["eye"], shot["look"]) == approach, pack + ": camera differs"
        shot["name"] = "E2_%s_%s_fixed_light" % (TAG[pack], pack[3:])
        shot["caption"] = "%s -- same shell, camera and light as the house baseline" % TAG[pack]
        lay["light"] = FIXED
        lay["shots"] = [shot]
        json.dump(lay, open(os.path.join(OUT, pack + ".json"), "w"), indent=1)
    base = json.load(open(os.path.join(SRC, PACKS[0] + ".json")))
    base.update({"pack": "house_baseline", "baseline": True, "place": [],
                 "surround": "", "light": FIXED,
                 "caption_note": "No pack: the house room alone.",
                 "shots": [{"name": "E2_T00_house_baseline_fixed_light",
                            "eye": approach[0], "look": approach[1],
                            "caption": "HOUSE BASELINE -- no pack, same shell, camera and light"}]})
    json.dump(base, open(os.path.join(OUT, "house_baseline.json"), "w"), indent=1)
    print("wrote %d layouts to %s" % (len(PACKS) + 1, OUT))


if __name__ == "__main__":
    main()
