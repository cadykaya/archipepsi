"""shell_cleft -- "the room that is a crack".

A 12 m-wide, 44 m-tall slot, 52 m long, that turns +x at its far end
into a second 28 m leg; the exit is 24 m up the end face.  Both faces
carry stairs and ledges, and the crossing between them is by CHOCKSTONES
-- boulders jammed in the crack -- so the mandatory route zig-zags up the
slot in short hops (never over 1.8 m span, never over 1.0 m rise) and the
whole climb is the room.  Compression register: the opposite of a hall.
The floor is continuous, so a fall costs the climb and never the level.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gbkit


def build():
    H = 44.0
    r = gbkit.Room("shell_cleft", 40.0, H, 52.0, wall=0.6,
                   intent=["narrow", "tall", "bend", "climb", "chockstones"])
    r.thesis = ("A crack, not a hall: LARGE by height and length, 12 m wide, with a bend that "
                "hides the exit; the route climbs the faces and crosses on boulders jammed "
                "between them.")
    r.first_read = ("Two rock faces 12 m apart rising 44 m to a slot of light; a boulder wedged "
                    "high across the crack at the far bend, 46 m away, is the only destination "
                    "in sight.")
    w = 0.6
    # --- enclosure, hand-built because the plan is an L --------------------------------
    r.doors(exit_y=24.0, exit_yaw=90.0, exit_xz=(36.0, 46.0), entry_surface="floor_1", exit_surface="landing_exit")
    r.block("floor_slab_1", "floor", (-6.0 - w, -1.0, 0.0), (6.0 + w, 0.0, 52.0 + w))
    r.block("floor_slab_2", "floor", (6.0, -1.0, 40.0 - w), (34.0 + w, 0.0, 52.0 + w))
    r.block("roof_1", "ceiling", (-6.0 - w, H, 0.0), (6.0 + w, H + w, 52.0 + w))
    r.block("roof_2", "ceiling", (6.0, H, 40.0 - w), (34.0 + w, H + w, 52.0 + w))
    r._wall_with_hole("front", (-6.0 - w, 6.0 + w), (0.0, w), 0.0, 2.4, 0.0, 3.2, axis="x")
    r.block("face_w", "wall", (-6.0 - w, 0.0, 0.0), (-6.0, H, 52.0 + w))
    r.block("face_e", "wall", (6.0, 0.0, 0.0), (6.0 + w, H, 40.0 - w))
    r.block("face_n", "wall", (-6.0 - w, 0.0, 52.0), (34.0 + w, H, 52.0 + w))
    r.block("face_s2", "wall", (6.0, 0.0, 40.0 - w), (34.0 + w, H, 40.0))
    r._wall_with_hole("face_end", (40.0 - w, 52.0 + w), (34.0, 34.0 + w), 46.0, 6.0, 24.0, 32.0, axis="z")
    # light slot: trim only, the roof stays closed (enclosed by default)
    r.block("light_slot", "trim", (-1.0, H - 0.4, 2.0), (1.0, H - 0.1, 50.0))
    r.surface("floor_1", -6.0, 6.0, 0.0, 52.0, 0.0)
    r.surface("floor_2", 6.0, 34.0, 40.0, 52.0, 0.0)
    # --- leg 1: zig-zag up the faces on stairs, ledges and chockstones -----------------
    r.stair("stair_1", 3.0, 6.0, 6.0, 18.0, 0.0, 6.0, axis="z", riser=0.5)          # east face 0 -> 6
    r.slab("ledge_e1", 3.0, 6.0, 18.0, 24.0, 6.0, thick=1.0)
    r.block("chock_1", "floor", (-2.0, 3.5, 24.0), (2.0, 6.5, 28.0))                  # boulder, top 6.5
    r.surface("chock_1", -2.0, 2.0, 24.0, 28.0, 6.5)
    r.slab("ledge_w1", -6.0, -3.0, 26.0, 32.0, 7.0, thick=1.0)
    r.stair("stair_2", -6.0, -3.0, 32.0, 44.0, 7.0, 13.0, axis="z", riser=0.5)     # west face 7 -> 13
    r.slab("ledge_w2", -6.0, -3.0, 44.0, 48.0, 13.0, thick=1.0)
    r.block("chock_2", "floor", (-2.0, 10.0, 44.0), (2.0, 13.5, 48.0))               # the boulder seen from the door
    r.surface("chock_2", -2.0, 2.0, 44.0, 48.0, 13.5)
    # --- leg 2: along the south face, up, across, up to the end-face landing --------------
    r.slab("ledge_s1", 2.0, 14.0, 40.0, 43.0, 14.0, thick=1.0)
    r.stair("stair_3", 14.0, 26.0, 40.0, 43.0, 14.0, 20.0, axis="x", riser=0.5)     # 14 -> 20
    r.slab("ledge_s2", 26.0, 34.0, 40.0, 43.0, 20.0, thick=1.0)
    r.block("chock_3", "floor", (28.0, 17.0, 44.5), (32.0, 21.0, 48.5))              # top 21
    r.surface("chock_3", 28.0, 32.0, 44.5, 48.5, 21.0)
    r.slab("ledge_n1", 26.0, 34.0, 49.0, 52.0, 22.0, thick=1.0)
    r.stair("stair_4", 30.0, 34.0, 49.0, 52.0, 22.0, 24.0, axis="z", riser=0.5, reverse=True)  # up toward -z? no: keep low at z52
    r.slab("landing_exit", 30.0, 34.0, 43.0, 49.0, 24.0, thick=1.0)
    # --- traversal: the chain -----------------------------------------------------------
    r.seg("entry_to_stair_1", "walk", (0.0, 0.0, 1.0), (4.5, 0.0, 5.5))
    r.seg("stair_1", "walk", (4.5, 0.0, 6.5), (4.5, 6.0, 17.5))
    r.seg("ledge_e1", "walk", (4.5, 6.0, 18.5), (4.5, 6.0, 23.5))
    r.seg("e1_to_chock_1", "rise", (3.0, 6.0, 24.5), (2.0, 6.5, 25.5))
    r.seg("chock_1_to_w1", "rise", (-2.0, 6.5, 27.0), (-3.0, 7.0, 27.5))
    r.seg("ledge_w1", "walk", (-4.5, 7.0, 27.5), (-4.5, 7.0, 31.5))
    r.seg("stair_2", "walk", (-4.5, 7.0, 32.5), (-4.5, 13.0, 43.5))
    r.seg("ledge_w2", "walk", (-4.5, 13.0, 44.5), (-4.5, 13.0, 46.0))
    r.seg("w2_to_chock_2", "rise", (-3.0, 13.0, 46.0), (-2.0, 13.5, 46.0))
    r.seg("chock_2_to_s1", "rise", (2.0, 13.5, 43.5), (3.0, 14.0, 42.5))
    r.seg("ledge_s1", "walk", (3.5, 14.0, 41.5), (13.5, 14.0, 41.5))
    r.seg("stair_3", "walk", (14.5, 14.0, 41.5), (25.5, 20.0, 41.5))
    r.seg("ledge_s2", "walk", (26.5, 20.0, 41.5), (30.0, 20.0, 42.5))
    r.seg("s2_to_chock_3", "rise", (30.0, 20.0, 43.0), (30.0, 21.0, 44.5))
    r.seg("chock_3_to_n1", "rise", (30.0, 21.0, 48.5), (30.0, 22.0, 49.0))
    r.seg("n1_to_stair_4", "walk", (28.0, 22.0, 50.5), (30.5, 22.0, 51.5))
    r.seg("stair_4", "walk", (32.0, 22.0, 51.5), (32.0, 24.0, 49.5))
    r.seg("landing_to_exit", "walk", (32.0, 24.0, 48.5), (33.5, 24.0, 46.0))
    r.seg("fall_recovery", "drop", (0.0, 6.5, 26.0), (0.0, 0.0, 22.0), mandatory=False)
    # --- offers -----------------------------------------------------------------------
    r.rail("rail_face_w", [(-4.0, 2.0, 4.0), (-4.5, 6.0, 14.0), (-4.0, 10.0, 24.0), (-4.5, 14.0, 34.0),
                           (-1.0, 18.0, 44.0), (8.0, 21.0, 50.0), (20.0, 24.0, 50.0), (30.0, 25.5, 47.5),
                           (32.5, 25.5, 46.0)])
    r.launch("launch_floor", (0.0, 0.0, 32.0), "land_chock_2", radius=2.5)
    r.landing("land_chock_2", (0.0, 13.5, 46.0), radius=2.5)
    r.grapple("grapple_slot", (0.0, 20.0, 30.0), radius=1.5)
    r.grapple("grapple_bend", (16.0, 28.0, 46.0), radius=1.5)
    # --- sockets / volumes ----------------------------------------------------------------
    for i, (sn, p) in enumerate((("ledge_w1", (-4.5, 7.3, 29.0)), ("ledge_s1", (8.0, 14.3, 41.5)),
                                 ("ledge_n1", (28.0, 22.3, 50.5)), ("chock_2", (0.0, 13.8, 46.0)))):
        r.socket("high_%d" % i, "enemy_high", p, surface_id=sn)
    for i, p in enumerate(((0.0, 0.3, 12.0), (0.0, 0.3, 36.0), (20.0, 0.3, 46.0))):
        r.socket("cover_%d" % i, "cover", p, surface_id="floor_1" if p[0] == 0.0 else "floor_2")
    r.socket("reactive_0", "reactive", (2.5, 0.3, 20.0), surface_id="floor_1")
    r.volume("arrival", "player_entry", (0.0, 1.0, 2.2), (2.4, 2.0, 2.4))
    r.volume("reward", "objective", (0.0, 14.5, 46.0), (2.4, 2.0, 2.4))
    r.volume("chock_1_mass", "no_build", (0.0, 5.0, 26.0), (4.0, 3.0, 4.0))
    r.sightline("entry_to_chock_2", (0.0, 1.6, 2.0), (0.0, 14.5, 45.5))
    r.notes.append("Plan is an L; the declared size is x-symmetric about the entry axis, so the room reserves a mirror image it does not use (contract observation).")
    return r
