"""shell_lemniscate -- "the room where the rail crosses itself".

A 44 x 40 x 72 m void: one continuous basin at y = 0, two island towers
(A at +7, B at +14), a west gallery (+7), a north landing (+14, the exit)
and an east catwalk (+24).  The mandatory route is stairs and galleries
only.  The offer that names the room is a 167 m figure-of-eight rail
that starts on the east catwalk, crosses the void twice -- over island
B, back under its own first pass with 6.5 m of air between -- and ends
1.5 m over the exit landing.  Two launch pairs and two grapple points
give the same void three other readings; declined, it is a tall room
with two towers in it and galleries round the walls.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gbkit


def build():
    W, H, D = 44.0, 40.0, 72.0
    r = gbkit.Room("shell_lemniscate", W, H, D, wall=0.6,
                   intent=["vertical", "rail", "void", "islands"])
    r.thesis = ("A rail-first void: the figure-of-eight through open air is the room's "
                "signature, and the two island towers exist to be crossed between.")
    r.first_read = ("A 10 m vestibule opens onto a 44 x 72 m basin 40 m tall; the exit portal "
                    "is visible dead ahead 72 m away and 14 m up, framed between the two towers.")
    half = W / 2
    # --- enclosure + vestibule ------------------------------------------
    r.doors(exit_y=14.0, exit_yaw=0.0, entry_surface="vestibule", exit_surface="landing_n")
    r.enclose(entry_w=10.0, entry_h=5.5, exit_w=6.0, exit_h=8.0)
    r.slab("vestibule", -5.0, 5.0, 0.0, 8.0, 0.0, thick=1.0, surface=True)
    r.block("vest_wall_w", "wall", (-5.6, 0.0, 0.0), (-5.0, 5.5, 8.0))
    r.block("vest_wall_e", "wall", (5.0, 0.0, 0.0), (5.6, 5.5, 8.0))
    r.block("vest_ceiling", "ceiling", (-5.6, 5.5, 0.0), (5.6, 6.1, 8.0))
    # basin: one continuous floor; nothing falls forever
    r.surface("basin", -half, half, 8.0, D, 0.0)
    # --- islands -----------------------------------------------------------
    r.block("island_a", "floor", (-14.0, 0.0, 22.0), (-4.0, 7.0, 32.0))
    r.surface("island_a", -14.0, -4.0, 22.0, 32.0, 7.0)
    r.block("island_b", "floor", (4.0, 0.0, 44.0), (14.0, 14.0, 54.0))
    r.surface("island_b", 4.0, 14.0, 44.0, 54.0, 14.0)
    # --- mandatory circulation: west stair, west gallery, north stair, landing
    r.stair("stair_w", -half, -half + 4.0, 10.0, 24.0, 0.0, 7.0, axis="z", riser=0.5)
    r.slab("gallery_w", -half, -16.0, 24.0, 52.0, 7.0)
    r.stair("stair_n", -half, -half + 4.0, 52.0, 66.0, 7.0, 14.0, axis="z", riser=0.5)
    r.slab("landing_n", -half, half, 66.0, D, 14.0)
    # --- optional: bridges to the islands, east stair and catwalk ---------
    r.slab("bridge_a", -16.0, -14.0, 25.0, 29.0, 7.0, thick=0.5)
    r.slab("bridge_b", 7.0, 11.0, 54.0, 66.0, 14.0, thick=0.5)
    r.slab("catwalk_e", 16.0, half, 8.0, 46.0, 24.0, thick=0.7)
    r.stair("stair_e", half - 4.0, half, 46.0, 66.0, 14.0, 24.0, axis="z", riser=0.5, reverse=True)
    # ceiling trusses the grapple points hang from (trim: look, do not touch)
    for z in (20.0, 38.0, 56.0):
        r.block("truss_%d" % int(z), "trim", (-half, 36.5, z - 0.6), (half, 37.5, z + 0.6))
    # --- traversal --------------------------------------------------------
    r.seg("vestibule_to_basin", "walk", (0, 0, 7.0), (0, 0, 9.0))
    r.seg("basin_to_stair_w", "walk", (0, 0, 9.5), (-20.0, 0, 9.5))
    r.seg("stair_w", "walk", (-20.0, 0, 10.5), (-20.0, 7.0, 23.5))
    r.seg("gallery_w", "walk", (-18.5, 7.0, 25.0), (-18.5, 7.0, 51.0))
    r.seg("stair_n", "walk", (-20.0, 7.0, 52.5), (-20.0, 14.0, 65.5))
    r.seg("landing_n", "walk", (-19.0, 14.0, 68.0), (0.0, 14.0, 68.0))
    r.seg("landing_to_exit", "walk", (0.0, 14.0, 68.0), (0.0, 14.0, 71.0))
    r.seg("gallery_to_island_a", "walk", (-17.0, 7.0, 27.0), (-13.0, 7.0, 27.0), mandatory=False)
    r.seg("landing_to_island_b", "walk", (9.0, 14.0, 65.0), (9.0, 14.0, 53.0), mandatory=False)
    r.seg("landing_to_catwalk", "walk", (20.0, 14.0, 65.5), (20.0, 24.0, 46.5), mandatory=False)
    r.seg("catwalk_e", "walk", (18.5, 24.0, 45.0), (18.5, 24.0, 10.0), mandatory=False)
    r.seg("island_a_drop", "drop", (-9.0, 7.0, 22.0), (-9.0, 0.0, 19.0), mandatory=False)
    # --- offers ------------------------------------------------------------
    r.rail("rail_lemniscate", [
        (18.0, 26.5, 44.0), (12.0, 24.0, 46.0), (0.0, 19.0, 38.0), (-12.0, 15.0, 28.0),
        (-17.0, 12.0, 16.0), (-8.0, 9.0, 8.5), (6.0, 8.0, 12.0), (14.0, 10.0, 24.0),
        (6.0, 12.5, 36.0), (-6.0, 14.0, 48.0), (-14.0, 16.0, 60.0), (-4.0, 15.5, 68.0),
        (4.0, 15.5, 70.0)])
    r.launch("launch_island_a", (-9.0, 7.0, 27.0), "land_island_b", radius=3.0)
    r.landing("land_island_b", (9.0, 14.0, 49.0), radius=3.5)
    r.launch("launch_basin", (0.0, 0.0, 40.0), "land_island_a", radius=3.0)
    r.landing("land_island_a", (-9.0, 7.0, 27.0), radius=3.5)
    r.grapple("grapple_centre", (0.0, 29.0, 38.0), radius=1.5)
    r.grapple("grapple_island_a", (-9.0, 20.0, 27.0), radius=1.5)
    # --- sockets / volumes ---------------------------------------------------
    for i, (sn, p) in enumerate((("island_a", (-9.0, 7.3, 27.0)), ("island_b", (9.0, 14.3, 49.0)),
                                 ("gallery_w", (-18.5, 7.3, 40.0)), ("catwalk_e", (18.5, 24.3, 28.0)),
                                 ("landing_n", (12.0, 14.3, 69.0)))):
        r.socket("high_%d" % i, "enemy_high", p, surface_id=sn)
    for i, p in enumerate(((-6.0, 0.3, 14.0), (10.0, 0.3, 30.0), (-2.0, 0.3, 58.0))):
        r.socket("cover_%d" % i, "cover", p, surface_id="basin")
    for i, p in enumerate(((12.0, 0.3, 16.0), (-12.0, 0.3, 44.0))):
        r.socket("reactive_%d" % i, "reactive", p, surface_id="basin")
    r.volume("arrival", "player_entry", (0.0, 1.0, 2.2), (2.4, 2.0, 2.4))
    r.volume("reward", "objective", (9.0, 15.0, 49.0), (2.4, 2.0, 2.4))
    r.volume("core_a", "no_build", (-9.0, 3.5, 27.0), (10.0, 7.0, 10.0))
    r.volume("core_b", "no_build", (9.0, 7.0, 49.0), (10.0, 14.0, 10.0))
    # --- the first read, asserted -----------------------------------------------
    r.sightline("entry_to_exit_portal", (0.0, 1.6, 4.0), (0.0, 21.5, D - 0.6))
    r.sightline("island_a_to_island_b", (-9.0, 8.6, 27.0), (9.0, 16.5, 48.0))
    r.notes.append("Rail crosses itself in plan near (1, z 37): first pass y 19.0, second y 12.5 -> 6.5 m of air between.")
    return r
