"""The P3 owner-review shot list: one LARGE room, eight views and six
overlays.

    python3 tools/shots/gen_p3_owner_review.py
    tools/shoot.sh tools/shots/p3_owner_review.json docs/art/review/p3_owner

CAMERA FRAME. Identical to the P2 package and derived the same way (L-52):
a Godot manifest point is negated in x and z to reach render space, a rig
yaw of theta looks along `(sin theta, 0, cos theta)`, and `eye` adds an
eye height that `look` does not -- so every yaw and pitch here is COMPUTED
by `aim()` from two manifest anchors rather than eyeballed. The P2 package
was re-shot three times before that was written down.

EVERY CAMERA ANCHOR IS READ FROM THE MANIFEST. A camera standing on the
east gantry is placed at the gantry's own declared centre, so if the
gantry moves the camera moves with it and the picture cannot quietly
become a picture of somewhere else.

LIGHTING. The hall is roofed, 38 m tall, and lit by the bench's three-light
rig rather than by fixtures it does not have. Ambient 0.30 and key 1.10
against the P2 rooms' 0.16/1.25: the extra ambient is what stops a 91,000
m3 interior going black four storeys up, and it is a BENCH setting, not a
claim about how the room is lit in game. Nothing in this shell places a
light.

OVERLAYS. Composed from `batch039/overlays/*.glb`, which
`tools/blender/build_hall_overlay.py` derives from the shipped manifest.
They are explanatory figures: they change no geometry, ship nowhere, and
carry no review state.
"""

import json
import math
import pathlib

EYE = 1.6
SHELL = "model:batch039/shells/shell_hall_transit.glb"
OV = "batch039/overlays/hall_ov_%s.glb"
LIGHT = {"ambient": 0.30, "key_energy": 1.10}

MANIFEST = pathlib.Path("assets/models/batch039/shells/manifest.json")
M = json.loads(MANIFEST.read_text())["shell_hall_transit"]


def R(x, y, z):
    """A Godot manifest point in render space."""
    return [round(-x, 3) + 0.0, round(y, 3) + 0.0, round(-z, 3) + 0.0]


def aim(eye_r, at_r, lift=EYE):
    dx = at_r[0] - eye_r[0]
    dy = at_r[1] - (eye_r[1] + lift)
    dz = at_r[2] - eye_r[2]
    yaw = math.degrees(math.atan2(dx, dz)) % 360.0
    flat = math.hypot(dx, dz)
    return round(yaw, 1), round(math.degrees(math.atan2(dy, flat))
                                if flat > 1e-6 else 0.0, 1)


def surface(name):
    for s in M["surfaces"]:
        if s["name"] == name:
            return s
    raise SystemExit("no surface %r in the shipped manifest" % name)


def top(name):
    """The standing height of a named surface, from the manifest."""
    return surface(name)["center"][1]


def on(name, dx=0.0, dz=0.0):
    """A camera standing ON a declared surface, offset in its own plane."""
    c = surface(name)["center"]
    return R(c[0] + dx, c[1], c[2] + dz)


shots = []


def add(**kw):
    kw.setdefault("size", [1920, 1080])
    shots.append(dict(LIGHT, **kw))


def view(name, eye_r, at_r, caption, note, **kw):
    yaw, pitch = aim(eye_r, at_r)
    add(name=name, scene=kw.pop("scene", SHELL), eye=eye_r, yaw=yaw,
        pitch=pitch, caption=caption, note=note, **kw)


# ------------------------------------------------------------ the eight
#
# EVERY CAMERA STANDS IN OPEN SPACE. The first pass put four of them
# within a few metres of a wall or a 4 m column, and a 1998 FOV in a 40 m
# room turns that into a photograph of concrete: two frames were half
# column and one was two walls meeting. The columns are at x = +/-7,
# z = 27 and 41, and the walls at |x| = 19.7 and z = 0.6 / 59.4, so the
# clear lanes are the centre line and the basin either side of the core.

# 1. THE FIRST READ. The one question a big room must answer at the door:
#    where am I going. The exit portal is 60 m away and 28 m up, and the
#    build asserts the sightline to it -- this is that assertion, seen.
view("H1_entry", R(0.0, 0.0, 3.0), R(0.0, 30.0, 59.0),
     "1  ENTRY - THE FIRST READ, FROM INSIDE THE DOOR",
     "THE VESTIBULE IS 5.5 M. THE HALL IS 38. THE EXIT IS ALREADY VISIBLE")

# 2. THE PRIMARY SPATIAL READ, high on the centre line looking down the
#    long axis. If the room is a big empty rectangle it is one here.
view("H2_hero", R(0.0, 26.0, 6.0), R(0.0, 12.0, 44.0),
     "2  PRIMARY - THE WHOLE VOLUME, DOWN THE LONG AXIS",
     "FOUR OCCUPIED LAYERS AND A LANDMARK STANDING IN THE MIDDLE")

# 3. THE PLAN. Not a true top-down: the hall has a roof, so a camera
#    above it photographs the roof. This is the steepest angle that still
#    reads which spaces exist and how they sit around the core.
view("H3_over", R(0.0, 33.0, 12.0), R(0.0, 4.0, 42.0),
     "3  OVER - THE ARRANGEMENT, FROM JUST UNDER THE ROOF",
     "GALLERY WEST, GANTRY EAST, LANDING NORTH, CORE IN THE MIDDLE")

# 4. FROM THE FLOOR. Scale contrast, and the answer to "is the basin a
#    place or a pit".
view("H4_low", R(-13.0, top("basin"), 34.0), R(2.0, 26.0, 34.0),
     "4  LOW - STANDING ON THE BASIN, BESIDE THE ARMATURE",
     "ONE CONTINUOUS FLOOR AT Y=0. A MISS COSTS HEIGHT, NEVER THE LEVEL")

# 5. MID ELEVATION, on the west gallery -- the first thing the route
#    climbs to, and where the core starts hiding the far side.
view("H5_mid", on("west_gallery", dx=1.7, dz=-2.0), R(10.0, 16.0, 34.0),
     "5  MID - ON THE WEST GALLERY AT Y=11, THE FIRST CLIMB",
     "THE CORE OCCLUDES THE EAST SIDE FROM HERE. THE ROOM KEEPS GIVING")

# 6. HIGH, on the east gantry at 21: where the launch lands and the last
#    ramp starts.
view("H6_high", on("east_gantry", dz=-2.0), R(2.0, 27.0, 54.0),
     "6  HIGH - ON THE EAST GANTRY AT Y=21, FACING THE LAST RAMP",
     "THE LANDING REGION OF THE LAUNCH PAIR IS THIS DECK")

# 7. THE REVERSE READ, from the exit looking back in -- whether the room
#    is worth crossing twice.
view("H7_reverse", on("exit_platform", dz=-2.0), R(0.0, 12.0, 8.0),
     "7  REVERSE - FROM THE EXIT PLATFORM AT Y=28, LOOKING BACK",
     "60 M BACK TO THE DOOR, AND EVERY LAYER VISIBLE FROM HERE")

# 8. THE VERTICAL READ, straight up the armature's open shaft -- the
#    room's whole argument for vertical movement.
view("H8_vertical", R(0.0, 0.0, 31.0), R(0.0, 37.0, 35.0),
     "8  VERTICAL - UP THE ARMATURE SHAFT FROM THE BASIN",
     "12 M OF OPEN AIR THROUGH THREE COLLARS, FLOOR TO ROOF")


# ----------------------------------------------------------- overlays
def overlay(name, fig, eye_r, at_r, caption, note):
    view(name, eye_r, at_r, caption, note,
         scene="%s + %s@0,0,0" % (SHELL, OV % fig))


# A. THE LOCAL SPACES. The owner's "several gameplay spaces, not one
#    rectangle" test, drawn as the shipped stand surfaces at their own
#    sizes with the enemy_high sockets standing on them.
overlay("O1_regions", "regions", R(0.0, 33.0, 12.0), R(0.0, 4.0, 42.0),
        "A  SPATIAL REGIONS - EVERY DECLARED STAND SURFACE",
        "GREEN: WALKABLE. VIOLET: ENEMY_HIGH SOCKETS. FROM THE MANIFEST")

# B. THE ROUTE WITH NOTHING INSTALLED -- the condition every offer below
#    is allowed to exist under.
# From the EAST side, because the two long ramps run up the west wall
# and the back wall: photographed from the centre line the west gallery
# deck is edge-on and hides the climb it carries.
overlay("O2_route", "route", R(14.0, 30.0, 7.0), R(-6.0, 12.0, 42.0),
        "B  THE MANDATORY ROUTE - ON FOOT, NO MOVEMENT PACKAGE",
        "THICK: THE NINE DECLARED LINKS. THIN: THE CROSSINGS BETWEEN THEM")

# C. THE RAIL OFFER. Ordered points, so the SHAPE is what to look at.
overlay("O3_rail", "rail", R(0.0, 30.0, 7.0), R(0.0, 16.0, 40.0),
        "C  OFFER: RAIL_ROUTE - ELEVEN POINTS, TWICE AROUND THE CORE",
        "AN OFFER, NOT A RAIL. NOTHING EXISTS UNTIL A PACKAGE BUILDS IT")

# D. THE LAUNCH PAIR: two regions, and deliberately nothing between them.
overlay("O4_launch", "launch", R(-9.0, 25.0, 9.0), R(14.0, 12.0, 26.0),
        "D  OFFER: LAUNCH PAIR - BASIN TO GANTRY, 24.5 M APART",
        "NO ARC IS DRAWN. LAUNCHSOLVER OWNS THE TRAJECTORY, NOT ART")

# E. THE GRAPPLE QUESTION. Not an offer: `grapple_anchor` is not in
#    OFFER_KINDS. This is the structure a future anchor would hang from.
overlay("O5_overhead", "overhead", R(-15.0, 1.0, 34.0), R(2.0, 25.0, 34.0),
        "E  OVERHEAD STRUCTURE - THE GRAPPLE QUESTION, NOT AN OFFER",
        "GRAPPLE_ANCHOR IS NOT IN OFFER_KINDS. THIS IS WHAT IT WOULD USE")

# F. THE VERTICAL MOVEMENT COLUMN.
overlay("O6_shaft", "shaft", R(0.0, 0.0, 31.0), R(0.0, 37.0, 35.0),
        "F  VERTICAL MOVEMENT REGION - THE SHAFT, FLOOR TO CORE TOP",
        "CONTINUOUS AND UNOBSTRUCTED. WIND, LIFT OR PLATFORMS ALL WANT THIS")


main = {
    "_comment": [
        "P3 OWNER REVIEW -- shell_hall_transit, the first LARGE authored",
        "room. GENERATED by tools/shots/gen_p3_owner_review.py; edit that.",
        "",
        "The shell exports review: 'pending' and nothing in this package",
        "changes that. It is for the owner's form review: is this the big",
        "open area the P3 direction asked for.",
        "",
        "Views 1-8 are the room as it ships. Overlays A-F add explanatory",
        "geometry DERIVED from the shipped manifest -- no view has been",
        "composed to flatter the room, and the overlay figures cannot",
        "disagree with the data because they are built from it.",
    ],
    "defaults": {"size": [1920, 1080], "backdrop": "none", "game_lens": True},
    "shots": shots,
}

out = pathlib.Path("tools/shots/p3_owner_review.json")
out.write_text(json.dumps(main, indent=2) + "\n")
print("wrote", out, "with", len(shots), "shots")
