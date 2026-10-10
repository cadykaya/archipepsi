import json, math, pathlib

EYE = 1.6
def R(x, y, z): return [round(-x,3)+0.0, round(y,3)+0.0, round(-z,3)+0.0]
def aim(e, at, lift=EYE):
    dx, dy, dz = at[0]-e[0], at[1]-(e[1]+lift), at[2]-e[2]
    return (round(math.degrees(math.atan2(dx, dz)) % 360.0, 1),
            round(math.degrees(math.atan2(dy, math.hypot(dx, dz))), 1))

# The two comparison frames, identical either side of the repair.
#
#   _over   the deck PLAN, from the F3 review's own camera. This is where
#           the well's shape is legible.
#   _arrive the last rung of the climb, at eye level, looking at where the
#           climb lands. This is where "does it read as architecture"
#           gets answered.
SHOTS = {}
for tag, over_y, rise, deck_x, stand in (
        ("collapsed", 17.0, 6.0, 2.3, (-2.8, 6.0, 7.0)),
        ("spiral", 20.0, 9.0, -1.7, (4.3, 9.0, 5.0))):
    e = R(*stand)
    yaw, pitch = aim(e, R(deck_x, rise, 10.0))
    SHOTS[tag] = [
        dict(name="X_%s_over_%%s" % tag, size=[1920, 1080],
             eye=[0, over_y, -6.0], yaw=180, pitch=-72,
             caption="%s DECK PLAN - %%s" % tag.upper(),
             note="THE DECK FOOTPRINT, FROM THE F3 REVIEW'S OWN CAMERA"),
        dict(name="X_%s_arrive_%%s" % tag, size=[1920, 1080],
             eye=e, yaw=yaw, pitch=pitch,
             caption="%s CLIMB ARRIVAL - %%s" % tag.upper(),
             note="THE LAST RUNG, LOOKING AT WHERE THE CLIMB LANDS"),
    ]

for side in ("before", "after"):
    doc = {
      "_comment": [
        "P2 REPAIR COMPARISON -- %s." % side.upper(),
        "",
        "`shell_tower_collapsed` and `shell_tower_spiral` are the only two",
        "shells with an intentional visible change in P2. The deck was a",
        "0.50 m slab across the back 4 m of every tower and it sat over the",
        "last rungs of both climbs; `_deck_well` cuts it out of the column",
        "the climb comes up.",
        "",
        "BEFORE renders a798b2c, AFTER renders 1d22cef, and every camera is",
        "identical between the two files. Nothing is restaged, relit or",
        "reframed to flatter the repair -- what ships is what is shown."
      ],
      "defaults": {"size": [1600, 900], "backdrop": "none",
                   "game_lens": True, "ambient": 0.24, "key_energy": 0.70},
      "shots": []
    }
    for tag, shots in SHOTS.items():
        for sh in shots:
            s = dict(sh)
            s["name"] = s["name"] % side
            s["caption"] = s["caption"] % side.upper()
            s["scene"] = "model:batch018/shells/shell_tower_%s.glb" % tag
            doc["shots"].append(s)
    out = pathlib.Path("tools/shots/p2_repair_%s.json" % side)
    out.write_text(json.dumps(doc, indent=2) + "\n")
    print("wrote", out, len(doc["shots"]), "shots")
