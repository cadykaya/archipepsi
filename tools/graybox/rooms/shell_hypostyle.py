"""shell_hypostyle -- "the room with the forest of columns and the lattice above".

56 x 18 x 56 m: LARGE by footprint, deliberately low.  Thirty-six 2 m
columns on an 8 m pitch make a ground floor of short sightlines and
ambush; a 3 m-wide walkway lattice at +8 threads BETWEEN the columns and
gives the same room from above: long avenues, overwatch, and every
pressure plate on the floor visible at once.  The one stair to the
lattice is the landmark, in the middle of the forest.  The exit is on
the lattice at the far wall.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gbkit


def build():
    W, H, D = 56.0, 18.0, 56.0
    r = gbkit.Room("shell_hypostyle", W, H, D, wall=0.6,
                   intent=["wide", "low", "columns", "lattice", "overwatch"])
    r.thesis = ("Two plans of the same floor: a column forest that hides everything and a "
                "walkway lattice that shows everything; the room is the argument between them.")
    r.first_read = ("A wall of columns 14 m tall, 8 m apart, receding in every direction; the "
                    "lattice at +8 catches the eye through the gaps; no destination is visible "
                    "until the central stair reveals the whole field from above.")
    half = W / 2
    r.doors(exit_y=8.0, exit_yaw=0.0, entry_surface="floor", exit_surface="landing_exit")
    r.enclose(exit_w=6.0, exit_h=3.2)
    r.surface("floor", -half, half, 0.0, D, 0.0)
    # --- the forest -------------------------------------------------------------
    cols_x = (-20.0, -12.0, -4.0, 4.0, 12.0, 20.0)
    cols_z = (8.0, 16.0, 24.0, 32.0, 40.0, 48.0)
    for i, x in enumerate(cols_x):
        for j, z in enumerate(cols_z):
            r.block("col_%d_%d" % (i, j), "wall", (x - 1.0, 0.0, z - 1.0), (x + 1.0, 14.0, z + 1.0))
    # --- the lattice at +8, between the columns -------------------------------------
    for k, z in enumerate((12.0, 20.0, 28.0, 36.0, 44.0)):
        # walkways stop at x = +-22 so the avenues at +-24 stay open for rails,
        # and every walkway crossing the stair well (x -3..3, z 22..38) is cut:
        # a walkway at head height over a tread is a headroom bug the kit
        # refused before anyone walked it.
        if k == 2:
            # one avenue broken twice: two 2.4 m gaps (optional jumps)
            r.slab("walk_x%d_a" % k, -22.0, -10.0, z - 1.5, z + 1.5, 8.0, thick=0.5)
            r.slab("walk_x%d_b" % k, -7.6, -3.0, z - 1.5, z + 1.5, 8.0, thick=0.5)
            r.slab("walk_x%d_c" % k, 3.0, 10.0, z - 1.5, z + 1.5, 8.0, thick=0.5)
            r.slab("walk_x%d_d" % k, 12.4, 22.0, z - 1.5, z + 1.5, 8.0, thick=0.5)
        elif k == 3:
            r.slab("walk_x%d_a" % k, -22.0, -3.0, z - 1.5, z + 1.5, 8.0, thick=0.5)
            r.slab("walk_x%d_b" % k, 3.0, 22.0, z - 1.5, z + 1.5, 8.0, thick=0.5)
        else:
            r.slab("walk_x%d" % k, -22.0, 22.0, z - 1.5, z + 1.5, 8.0, thick=0.5)
    for k, x in enumerate((-16.0, -8.0, 8.0, 16.0)):
        r.slab("walk_z%d" % k, x - 1.5, x + 1.5, 4.0, 52.0, 8.0, thick=0.5)
    # the spine at x = 0 is cut around the stair well
    r.slab("walk_z_s", -1.5, 1.5, 4.0, 22.0, 8.0, thick=0.5)
    r.slab("walk_z_n", -1.5, 1.5, 38.0, 52.0, 8.0, thick=0.5)
    r.stair("stair_c", -1.5, 1.5, 22.0, 38.0, 0.0, 8.0, axis="z", riser=0.5)
    # lantern: four trim posts round the stair well so the landmark reads from the floor
    for x in (-2.2, 2.2):
        for z in (21.0, 39.0):
            r.block("lantern_%d_%d" % (int(x * 10), int(z)), "trim", (x - 0.3, 8.0, z - 0.3), (x + 0.3, 17.0, z + 0.3))
    r.slab("landing_exit", -6.0, 6.0, 52.0, D, 8.0, thick=0.5)
    # --- traversal ---------------------------------------------------------------
    r.seg("entry_to_stair", "walk", (0, 0, 1.0), (0, 0, 21.0))
    r.seg("stair_c", "walk", (0, 0, 22.5), (0, 8.0, 37.5))
    r.seg("spine_n", "walk", (0, 8.0, 38.5), (0, 8.0, 51.5))
    r.seg("landing_to_exit", "walk", (0, 8.0, 52.5), (0, 8.0, 55.0))
    r.seg("avenue_gap_w", "gap", (-10.0, 8.0, 28.0), (-7.6, 8.0, 28.0), mandatory=False)
    r.seg("avenue_gap_e", "gap", (10.0, 8.0, 28.0), (12.4, 8.0, 28.0), mandatory=False)
    r.seg("lattice_w", "walk", (-16.0, 8.0, 5.0), (-16.0, 8.0, 51.0), mandatory=False)
    r.seg("lattice_x1", "walk", (-21.0, 8.0, 20.0), (21.0, 8.0, 20.0), mandatory=False)
    r.seg("lattice_drop", "drop", (-16.0, 8.0, 12.0), (-16.0, 0.0, 10.0), mandatory=False)
    # --- offers ---------------------------------------------------------------
    r.rail("rail_avenue_e", [(24.0, 9.5, 6.0), (24.0, 9.5, 50.0)])
    r.rail("rail_avenue_w", [(-24.0, 9.5, 50.0), (-24.0, 6.5, 34.0), (-24.0, 3.5, 20.0), (-22.0, 1.8, 8.0)])
    # source in the west avenue (outside the walkway plan) so the rising limb is in open air;
    # the arc lands on the west end of the z = 12 walkway
    r.launch("launch_floor", (-25.0, 0.0, 12.0), "land_lattice", radius=2.5)
    r.landing("land_lattice", (-18.0, 8.0, 12.0), radius=2.5)
    r.grapple("grapple_canopy_e", (16.0, 16.0, 28.0), radius=1.5)
    r.grapple("grapple_canopy_w", (-16.0, 16.0, 28.0), radius=1.5)
    # --- sockets / volumes -------------------------------------------------------
    highs = (("walk_x0", (-8.0, 8.3, 12.0)), ("walk_x1", (8.0, 8.3, 20.0)), ("walk_x3_a", (-16.0, 8.3, 36.0)),
             ("walk_x4", (16.0, 8.3, 44.0)), ("walk_z3", (16.0, 8.3, 30.0)))
    for i, (sn, p) in enumerate(highs):
        r.socket("high_%d" % i, "enemy_high", p, surface_id=sn)
    for i, p in enumerate(((-8.0, 0.3, 28.0), (8.0, 0.3, 36.0), (-16.0, 0.3, 44.0), (16.0, 0.3, 12.0))):
        r.socket("cover_%d" % i, "cover", p, surface_id="floor")
    for i, p in enumerate(((8.0, 0.3, 12.0), (-8.0, 0.3, 44.0))):
        r.socket("reactive_%d" % i, "reactive", p, surface_id="floor")
    r.volume("arrival", "player_entry", (0.0, 1.0, 2.2), (2.4, 2.0, 2.4))
    r.volume("reward", "objective", (0.0, 9.0, 54.0), (2.4, 2.0, 2.4))
    r.volume("stair_well", "no_build", (0.0, 4.0, 30.0), (3.0, 8.0, 16.0))
    # the lattice avenue is a sightline the floor never has
    r.sightline("lattice_avenue", (-21.0, 9.6, 20.0), (21.0, 9.6, 20.0))
    r.notes.append("From the floor no sightline exceeds one 8 m bay; from the lattice every avenue is 52 m.")
    return r
