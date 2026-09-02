"""shell_bascule -- "the room that hides itself behind its own floor".

A 36 x 36 x 68 m hall whose floor is the landmark.  From an 8 x 4 x 4
porch the floor climbs away from the door as one full-width stair (leaf
A, 24 risers, 28.6 deg) to a crest 12 m up at z 26..28, and the crest is
all you can see: the roof is 36 m up, so the room is obviously much
bigger than the slope in front of you.  Only from crest A does the second
half appear -- a 12 m pit at y 0 with two pocket stairs in it (down on
the west, up on the east), the opposing crest B 12 m away, and beyond it
leaf B descending to the exit at y 0.  Net rise is zero.  The mandatory
route is stairs and slabs only: up leaf A, along crest A, down the west
stair, across the pit, up the east stair, along crest B, down leaf B.
Offers: a rail that dives from leaf A into the pit and runs down leaf B
to the exit; a launch straight across the pit from crest to crest; a
grapple under a truss 28 m over the pit floor.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gbkit


def build():
    W, H, D = 36.0, 36.0, 68.0
    r = gbkit.Room("shell_bascule", W, H, D, wall=0.6,
                   intent=["leaves", "crest", "pit", "withheld", "net_zero"])
    r.thesis = ("Two lifted leaves: the floor rises away from the door to a crest 12 m up, and "
                "only from that crest do you see the second leaf, the pit between them and the "
                "exit down the far slope; the room withholds its second half until you earn it.")
    r.first_read = ("Through a low 8 x 4 m mouth, a full-width stepped slope climbing 12 m to a "
                    "crest edge 26 m away under a 36 m roof; nothing past the crest is visible, "
                    "so the room is plainly larger than what it shows.")
    half = W / 2
    # --- enclosure, porch (the small term) ----------------------------------------
    r.doors(exit_y=0.0, exit_yaw=0.0, entry_surface="porch", exit_surface="apron")
    r.enclose(exit_w=6.0, exit_h=8.0)
    r.surface("porch", -4.0, 4.0, 0.0, 4.0, 0.0)
    r.block("porch_wall_w", "wall", (-4.6, 0.0, 0.0), (-4.0, 4.0, 4.0))
    r.block("porch_wall_e", "wall", (4.0, 0.0, 0.0), (4.6, 4.0, 4.0))
    r.block("porch_ceiling", "ceiling", (-4.6, 4.0, 0.0), (4.6, 4.6, 4.0))
    # --- leaf A: the mandatory climb, and crest A ---------------------------------------
    # 24 risers of 0.5 on 0.917 m treads (28.6 deg); each tread block reaches to -0.7
    # so the leaf reads as one solid mass from the door.
    r.stair("leaf_a", -half, half, 4.0, 26.0, 0.0, 12.0, axis="z", riser=0.5)
    # the crests are solid to the floor: the leaves are masses, not decks on stilts
    r.slab("crest_a", -half, half, 26.0, 28.0, 12.0, thick=12.7)
    # --- the pit (floor = the enclose slab at y 0) with its two pocket stairs -----------
    # west stair: high end at x -18 against crest A, descending east to the pit floor at x 2
    r.stair("stair_down", -half, 2.0, 28.0, 32.0, 0.0, 12.0, axis="x", riser=0.5, reverse=True,
            surface=False)
    # east stair: low end at x -2, climbing east to crest B at x 18
    r.stair("stair_up", -2.0, half, 36.0, 40.0, 0.0, 12.0, axis="x", riser=0.5, surface=False)
    # The pocket stairs' only top tread (0.83 m) sits against the side wall, and the
    # C(ii) stance grid's first column is 0.4 m in from the rect edge, i.e. touching the
    # wall: declared over the geometry's full rect the surface finds no stance.  The
    # declared rect stops 0.1 m short of the wall; the geometry itself still abuts it.
    r.surface("stair_down", -half + 0.1, 2.0, 28.0, 32.0, 12.0)
    r.surface("stair_up", -2.0, half - 0.1, 36.0, 40.0, 12.0)
    r.surface("pit", -half, half, 32.0, 36.0, 0.0)
    r.surface("pit_e", 2.0, half, 28.0, 32.0, 0.0)     # open floor beside the west stair's foot
    r.surface("pit_w", -half, -2.0, 36.0, 40.0, 0.0)   # open floor beside the east stair's foot
    # grapple truss across the pit (trim: look, do not touch)
    r.block("truss_pit", "trim", (-half, 28.5, 33.4), (half, 29.5, 34.6))
    # --- crest B and leaf B: the descending walk to the exit ------------------------------
    r.slab("crest_b", -half, half, 40.0, 42.0, 12.0, thick=12.7)
    r.stair("leaf_b", -half, half, 42.0, 64.0, 0.0, 12.0, axis="z", riser=0.5, reverse=True)
    r.surface("apron", -half, half, 64.0, D, 0.0)
    # --- traversal: the chain, all straight walks --------------------------------------------
    r.seg("porch", "walk", (0.0, 0.0, 1.0), (0.0, 0.0, 3.5))
    r.seg("leaf_a", "walk", (0.0, 0.0, 4.5), (0.0, 12.0, 25.5))
    r.seg("crest_a", "walk", (0.0, 12.0, 27.0), (-16.0, 12.0, 27.0))
    r.seg("stair_down", "walk", (-17.0, 12.0, 30.0), (3.0, 0.0, 30.0))
    r.seg("pit_s", "walk", (3.0, 0.0, 31.0), (3.0, 0.0, 34.0))
    r.seg("pit_x", "walk", (3.0, 0.0, 34.0), (-3.0, 0.0, 34.0))
    r.seg("pit_n", "walk", (-3.0, 0.0, 35.0), (-3.0, 0.0, 37.0))
    r.seg("stair_up", "walk", (-3.0, 0.0, 38.0), (17.0, 12.0, 38.0))
    r.seg("crest_b", "walk", (17.0, 12.0, 41.0), (0.0, 12.0, 41.0))
    r.seg("leaf_b", "walk", (0.0, 12.0, 42.5), (0.0, 0.0, 63.5))
    r.seg("apron", "walk", (0.0, 0.0, 64.5), (0.0, 0.0, 67.0))
    # recovery: a miss off either crest lands in the pit; the pocket stairs are the way back
    r.seg("crest_a_drop", "drop", (8.0, 12.0, 27.5), (8.0, 0.0, 33.0), mandatory=False)
    r.seg("crest_b_drop", "drop", (-8.0, 12.0, 40.5), (-8.0, 0.0, 35.0), mandatory=False)
    # --- offers (all declinable) -------------------------------------------------------------
    # rail_dive: caught 2.0 m over leaf A's tread at z 22 (top 10.0; RAIL_CATCH_BELOW is
    # 2.2), over crest A, diving between the two pocket stairs (at x -2 neither stair is
    # under it; at x -6 the west stair's treads top at 5.0-5.5 under z 28..32) to 4.5 m over
    # the pit floor, up over crest B and down leaf B ~2 m over the treads to 2 m over the
    # apron by the exit.  Crest passes are at 14.5 so the baked curve keeps 0.7 m over the
    # crest lips (at 13 the Catmull-Rom dip started 0.5 m over crest A).
    r.rail("rail_dive", [
        (-6.0, 12.0, 22.0), (-6.0, 14.5, 28.0), (-2.0, 4.5, 34.0), (-6.0, 14.5, 40.0),
        (-6.0, 11.2, 48.0), (-6.0, 6.0, 58.0), (-3.0, 2.0, 66.0)])
    # launch_crest: the shortcut across the pit, crest A to crest B (apex 15.5)
    r.launch("launch_crest", (-8.0, 12.0, 27.0), "land_crest_b", radius=3.0)
    r.landing("land_crest_b", (-8.0, 12.0, 41.0), radius=3.0)
    # grapple_pit: under the truss, 28 m over the pit floor
    r.grapple("grapple_pit", (0.0, 28.0, 34.0), radius=1.5)
    # --- sockets / volumes --------------------------------------------------------------------
    r.socket("high_crest_a", "enemy_high", (-12.0, 12.3, 27.0), surface_id="crest_a")
    r.socket("high_crest_b", "enemy_high", (12.0, 12.3, 41.0), surface_id="crest_b")
    # leaf B tread 15 (z 49.33..50.25) tops at 8.0
    r.socket("high_leaf_b", "enemy_high", (8.0, 8.3, 49.8), surface_id="leaf_b")
    r.socket("cover_0", "cover", (8.0, 0.3, 33.0), surface_id="pit")
    r.socket("cover_1", "cover", (-8.0, 0.3, 35.0), surface_id="pit")
    r.socket("cover_2", "cover", (10.0, 0.3, 30.0), surface_id="pit_e")
    r.socket("reactive_0", "reactive", (-10.0, 0.3, 38.0), surface_id="pit_w")
    r.volume("arrival", "player_entry", (0.0, 1.0, 2.2), (2.4, 2.0, 2.4))
    r.volume("reward", "objective", (0.0, 1.0, 34.0), (2.4, 2.0, 2.4))
    r.volume("pit_air", "no_build", (0.0, 18.0, 34.0), (36.0, 24.0, 12.0))
    # --- the first read, asserted ------------------------------------------------------------------
    r.sightline("entry_to_crest_a", (0.0, 1.6, 2.0), (0.0, 13.0, 26.5))
    r.sightline("crest_a_to_crest_b", (0.0, 13.6, 27.0), (0.0, 13.0, 41.5))
    r.sightline("crest_a_to_pit", (0.0, 13.6, 27.5), (0.0, 0.5, 34.0))
    r.notes.append("Net rise zero: exit and entry on the same plane, so the chain's cumulative height is unchanged by this room.")
    r.notes.append("The exit is deliberately NOT visible from the entry; crest A at 12 m fills the view and the only asserted entry sightline ends 1 m above its edge.")
    r.notes.append("Both crests are solid from -0.7 to 12 so each leaf is one mass; the pit floor is the enclose slab, so no miss falls more than 12 m and nothing falls forever.")
    r.notes.append("Declared length 70 includes the exit socket 2 m past the back wall; declared height 36.6 is the roof, not the exit door.")
    return r


# --- readings ---
# (a) Gameplay-package readings.
#   pit fight:  the pit (36 x 12 at y 0) is the arena; enemy_high on both crests fire
#               down; cover_0..2 on the pit floor, reactive_0 in the west pocket; the
#               two pocket stairs are the only ways out, one per side, so the arena has
#               two exits guarded from above.
#   crest duel: enemies on crest B only (high_crest_b, high_leaf_b); from crest A the
#               player has a 14.5 m sightline to them across the pit; launch_crest is
#               the assault, the pocket stairs the slow flank through the pit.
#   retreat:    reward at the pit floor centre (0,1,34); enemies arrive down leaf B
#               behind the player (high_leaf_b) and hold crest B; rail_dive passes
#               4.5 m over the reward and climbs out over crest B to the exit -- the
#               way out for a player who does not want to climb the east stair under
#               fire; grapple_pit at 28 m is the same escape for the other package.
#   empty:      two slopes and a gap.  A 21 m climb, a 12 m drop, a 21 m descent.
# (b) Strip test.  With every package removed: a stepped slope to a crest that hides
#     the exit, a pit with two stairs, a second slope down.  Still worth walking: the
#     reveal at crest A (the whole second half appearing at once, 12 m below and 12 m
#     across) is geometry, not an offer, and the descent of leaf B is the only walk in
#     the slate that goes down 12 m without a package.
# (c) Recovery geography.  A miss off crest A or crest B lands on the pit floor at
#     y 0 (crest_a_drop / crest_b_drop); from the pit the west stair returns to crest A
#     and the east stair to crest B, so no fall costs more than one 12 m climb.  A
#     miss off the launch lands in the pit; a miss off the rail over the pit lands
#     in the pit; a miss off the rail over leaf B lands on a tread and rolls down to
#     the apron, which IS the route.  Nothing in the room is below y 0.
# (d) Machinery.  launch_crest is the thing a machine enables or removes (a raised
#     bascule leaf, a gate at the crest lip); the pit floor centre is a natural pressure
#     plate (the reward volume sits on it); a gate on the apron (x -3..3 at z 64..68)
#     holds the whole room without touching the shell; a lift in the pit's west pocket
#     (x -18..-2, z 36..40, the open floor beside the east stair) could replace the
#     stair with a slower, holdable ascent to crest B.
