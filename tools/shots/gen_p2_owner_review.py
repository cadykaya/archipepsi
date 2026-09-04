import json, math, pathlib

# RENDER SPACE and the yaw convention, both DERIVED from the F3 shot lists
# rather than guessed, because the first attempt guessed and put three
# cameras inside walls.
#
#   render = (-x, y, -z) of a Godot manifest point            (L-52)
#   a rig yaw of theta looks along (sin theta, 0, cos theta)
#
# The second line is what `R_corner_turning` proves: from render (0,0,-3)
# at yaw 250 it "faces the exit", and corner_left's exit is at render
# (-3.4, 0, -3.0) -- straight along -x, which is yaw 270, and the shot is
# framed 20 degrees off it. `T_gantry_landing` at yaw 0 looking back at
# the door confirms the other end.
EYE = 1.6


def R(x, y, z):
    return [round(-x, 3) + 0.0, round(y, 3) + 0.0, round(-z, 3) + 0.0]


def aim(eye_r, at_r, lift=EYE):
    """yaw and pitch from one render-space point to another.

    `eye` adds `lift` to the camera but not to the target, so the pitch
    has to account for it or every shot tilts down by an eye height.
    """
    dx = at_r[0] - eye_r[0]
    dy = at_r[1] - (eye_r[1] + lift)
    dz = at_r[2] - eye_r[2]
    yaw = math.degrees(math.atan2(dx, dz)) % 360.0
    flat = math.hypot(dx, dz)
    pitch = math.degrees(math.atan2(dy, flat)) if flat > 1e-6 else 0.0
    return round(yaw, 1), round(pitch, 1)


T = "model:batch018/shells/%s.glb"
S = "model:batch019/shells/%s.glb"
TOWER = {"ambient": 0.24, "key_energy": 0.70}
ROOM = {"ambient": 0.16}

main = {
  "_comment": [
    "P2 OWNER REVIEW -- the eight certified shells, as they ship at 1d22cef.",
    "",
    "Production certified them at 6640d86: all eight satisfy the room",
    "contract with ZERO physical findings. This package is for the OTHER",
    "question -- spatial quality, readability, and whether each room looks",
    "intentionally designed. Nothing here changes a review state.",
    "",
    "CAMERA FRAME (L-52): every point is a manifest anchor with x and z",
    "negated, so a camera is read off the shipped registry rather than",
    "guessed, and yaw/pitch are COMPUTED from two such points rather than",
    "eyeballed. LIGHTING (L-56): towers get key 0.70 and ambient 0.24",
    "because they have no roof; the roofed rooms get the bench standard.",
    "",
    "The entry and climb cameras are the F3 review's own, unchanged, so a",
    "frame here can be held against the frame the owner passed."
  ],
  "defaults": {"size": [1600, 900], "backdrop": "none", "game_lens": True},
  "shots": []
}
add = main["shots"].append

# ---------------------------------------------------------------- towers
for name, pitch, over_y, rise, deck_x, extra in (
    ("collapsed", 14, 17.0, 6.0, 2.3,
     dict(name="T_collapsed_climb", eye=[0, 6.0, -3.9], yaw=180, pitch=-10,
          caption="COLLAPSED - ON THE UPPER HALF-FLOOR, OVER THE TEAR",
          note="THE CLIMB HAPPENS ON THE SLAB BELOW IT")),
    ("spiral", 16, 20.0, 9.0, -1.7,
     dict(name="T_spiral_climb", eye=[4.3, 3.0, -9.2], yaw=130, pitch=8,
          caption="SPIRAL - PART WAY UP, WHERE THE HELIX TURNS",
          note="EVERY SLAB IS CARRIED BY TWO BRACKETS INTO THE WALL")),
    ("gantry", 22, 26.0, 15.0, 0.0,
     dict(name="T_gantry_climb", eye=[0, 9.0, -10.6], yaw=0, pitch=-8,
          caption="GANTRY - ON THE THIRD LANDING, TWO STOREYS UP",
          note="A FULL LANDING EVERY 3.0 M - SOMEWHERE TO STAND AND FIGHT")),
):
    glb = T % ("shell_tower_%s" % name)
    add(dict(name="T_%s_entry" % name, scene=glb, size=[1920, 1080],
             eye=[0, 0, -2.5], yaw=180, pitch=pitch, **TOWER,
             caption="%s - ENTRY, FROM THE DOOR" % name.upper(),
             note="THE QUESTION A TOWER ASKS IS ANSWERED LOOKING UP"))
    add(dict(name="T_%s_over" % name, scene=glb, size=[1920, 1080],
             eye=[0, over_y, -6.0], yaw=180, pitch=-72, **TOWER,
             caption="%s - THE WHOLE ROUTE, INTO THE SHAFT FROM ABOVE"
                     % name.upper(),
             note="PRIMARY SPATIAL READ - THE DECK PLAN IS VISIBLE HERE"))
    e = R(deck_x, rise, 10.0)
    yaw, pitch_ = aim(e, R(0.0, rise + EYE, 14.2))
    add(dict(name="T_%s_exit" % name, scene=glb, eye=e, yaw=yaw,
             pitch=pitch_, **TOWER,
             caption="%s - FROM THE DECK, OUT TO THE BRIDGE" % name.upper(),
             note="THE EXIT IS THROUGH THE BACK WALL AT SUMMIT HEIGHT"))
    add(dict(extra, scene=glb, **TOWER))

# -------------------------------------------------------------- treasure
for name, pitch, blurb in (("vault", -2, "THIS WAS PROTECTED"),
                           ("cache", -2, "THIS WAS STORED"),
                           ("coffer", 4, "THIS WAS DISPLAYED")):
    glb = S % ("shell_treasure_%s" % name)
    add(dict(name="R_%s_entry" % name, scene=glb, size=[1920, 1080],
             eye=[0, 0, -1.4], yaw=180, pitch=pitch, **ROOM,
             caption="%s - ENTRY. %s" % (name.upper(), blurb),
             note="8.0 M SQUARE, REWARD AT THE CENTRE - THE ENGINE'S OWN"))
    e = R(3.0, 0.0, 1.5)
    yaw, pit = aim(e, R(0.0, 1.0, 4.0))
    add(dict(name="R_%s_interior" % name, scene=glb, eye=e, yaw=yaw,
             pitch=pit, **ROOM,
             caption="%s - THE PLINTH, ACROSS THE ROOM" % name.upper(),
             note="ONE STANDABLE TIER AT 0.80 M - THE 0.40 M RISER IS A STEP"))
    e = R(0.0, 0.0, 6.8)
    yaw, pit = aim(e, R(0.0, 1.6, 0.5))
    add(dict(name="R_%s_exit" % name, scene=glb, eye=e, yaw=yaw, pitch=pit,
             **ROOM,
             caption="%s - FROM THE BACK WALL, LOOKING AT THE DOOR"
                     % name.upper(),
             note="THE REVERSE READ - THE ROOM ON THE WAY OUT"))

# --------------------------------------------------------------- corners
for name, turn, yaw_turn, exit_x in (("left", "+90", 250, 3.4),
                                     ("right", "-90", 110, -3.4)):
    glb = S % ("shell_corner_%s" % name)
    add(dict(name="C_%s_entry" % name, scene=glb, size=[1920, 1080],
             eye=[0, 0, -1.2], yaw=180, pitch=0, **ROOM,
             caption="CORNER %s - ARRIVING. THE TURN IS MARKED BY FORM"
                     % name.upper(),
             note="A CORRIDOR THAT TURNS - exit_yaw %s" % turn))
    add(dict(name="C_%s_turn" % name, scene=glb, eye=[0, 0, -3.0],
             yaw=yaw_turn, pitch=0, **ROOM,
             caption="CORNER %s - MID-TURN, FACING THE EXIT" % name.upper(),
             note="THE OPENING ITSELF IS THE CUE - NO HAZARD ORANGE"))
    e = R(exit_x * 0.62, 0.0, 3.0)
    yaw, pit = aim(e, R(0.0, EYE, 0.3))
    add(dict(name="C_%s_back" % name, scene=glb, eye=e, yaw=yaw, pitch=pit,
             **ROOM,
             caption="CORNER %s - FROM THE EXIT, LOOKING BACK IN"
                     % name.upper(),
             note="THE REVERSE READ - A CONNECTOR, NOT A DESTINATION"))

# The connector context, at EYE LEVEL. An overhead of roofed rooms shows
# only their ceilings -- the first attempt tried it and photographed two
# white lids. Standing in a corridor looking through into the turn is what
# actually answers "is this a link in a chain".
#
# The composition offset was settled by RENDERING it, not by deriving it:
# `+14` and `-14` were both tried and only one puts the corridor in front
# of the corner. A camera convention that has to be guessed is a camera
# convention that should be measured, and probe frames are cheap.
add(dict(name="C_chain_context", size=[1920, 1080], **ROOM,
         scene=("model:batch019/shells/shell_corner_left.glb"
                " + batch015/shells/shell_corridor_narrow.glb@0,0,-14"),
         eye=[0, 0, 7.0], yaw=180, pitch=0,
         caption="THE CORNER AS A CONNECTOR - APPROACHED DOWN A CORRIDOR",
         note="CONTEXT ONLY. THE CORRIDOR SHELL IS APPROVED, NOT EXPORTED"))

out = pathlib.Path("tools/shots/p2_owner_review.json")
out.write_text(json.dumps(main, indent=2) + "\n")
print("wrote", out, "with", len(main["shots"]), "shots")
