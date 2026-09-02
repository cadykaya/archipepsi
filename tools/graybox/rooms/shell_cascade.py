"""shell_cascade -- "the bowl you climb out of".

64 x 30 x 64 m.  Four concentric square terraces rise around a central
stage.  The player arrives through a 4 x 4 m tunnel driven under the
front of every ring and steps out at the bottom of the bowl, where the
whole room looks at them; the exit is in the top ring, 20 m up and 64 m
away, and the route out is ring by ring on four stairs set alternately
east and west.  The stage is the one place every terrace can see, and
the two rails cross above it at right angles rather than spiralling.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gbkit

# (inner half-extent, outer half-extent, top) -- the bowl, from the stage out.
RINGS = ((10.0, 16.0, 5.0), (16.0, 22.0, 10.0), (22.0, 28.0, 15.0), (28.0, 32.0, 20.0))
CZ = 32.0          # the stage's centre in z; the bowl is concentric on it
TUNNEL_HALF = 2.0  # the arrival slot driven under the front of every ring
TUNNEL_H = 4.0


def build():
    W, H, D = 64.0, 30.0, 64.0
    r = gbkit.Room("shell_cascade", W, H, D, wall=0.6,
                   intent=["bowl", "terraces", "concentric", "stage"])
    r.thesis = ("Concentric terraces rising away from a stage: the one room in the "
                "slate where every part of the room looks at the same place.")
    r.first_read = ("A 4 m tunnel opens at the foot of a bowl; four terraces step up "
                    "and back, 5 m at a time, and the exit portal sits in the topmost "
                    "one, 20 m up and 64 m away, in line with the tunnel.")
    r.doors(exit_y=20.0, exit_yaw=0.0, entry_surface="tunnel", exit_surface="ring4_back")
    r.enclose(exit_w=6.0, exit_h=8.0)
    # --- the stage and its arrival slot -------------------------------------------
    r.surface("stage", -10.0, 10.0, CZ - 10.0, CZ + 10.0, 0.0)
    r.surface("tunnel", -TUNNEL_HALF, TUNNEL_HALF, 0.6, CZ - 10.0, 0.0)
    # --- the four terraces -----------------------------------------------------------
    # Each ring is a solid annulus of four strips; the front strip is split around the
    # tunnel and carries a head block over it, so the terrace top stays one continuous
    # walkable rect while the slot runs beneath it from the door to the stage.
    for k, (inner, outer, top) in enumerate(RINGS, start=1):
        z_f0, z_f1 = CZ - outer, CZ - inner
        z_b0, z_b1 = CZ + inner, CZ + outer
        r.block("ring%d_front_w" % k, "floor", (-outer, 0.0, z_f0), (-TUNNEL_HALF, top, z_f1))
        r.block("ring%d_front_e" % k, "floor", (TUNNEL_HALF, 0.0, z_f0), (outer, top, z_f1))
        r.block("ring%d_front_head" % k, "floor",
                (-TUNNEL_HALF, TUNNEL_H, z_f0), (TUNNEL_HALF, top, z_f1))
        r.surface("ring%d_front" % k, -outer, outer, z_f0, z_f1, top)
        r.block("ring%d_back" % k, "floor", (-outer, 0.0, z_b0), (outer, top, z_b1))
        r.surface("ring%d_back" % k, -outer, outer, z_b0, z_b1, top)
        r.block("ring%d_west" % k, "floor", (-outer, 0.0, z_f1), (-inner, top, z_b0))
        r.surface("ring%d_west" % k, -outer, -inner, z_f1, z_b0, top)
        r.block("ring%d_east" % k, "floor", (inner, 0.0, z_f1), (outer, top, z_b0))
        r.surface("ring%d_east" % k, inner, outer, z_f1, z_b0, top)
    # --- four stairs, alternating east and west ---------------------------------------
    r.stair("stair_1", 6.0, 10.0, 22.0, 32.0, 0.0, 5.0, axis="z", riser=0.5)
    r.stair("stair_2", -16.0, -12.0, 34.0, 44.0, 5.0, 10.0, axis="z", riser=0.5, reverse=True)
    r.stair("stair_3", 18.0, 22.0, 14.0, 24.0, 10.0, 15.0, axis="z", riser=0.5)
    r.stair("stair_4", -28.0, -24.0, 46.0, 56.0, 15.0, 20.0, axis="z", riser=0.5, reverse=True)
    # the truss the stage grapple hangs from (trim: look, do not touch)
    r.block("truss", "trim", (-32.0, 28.0, CZ - 0.6), (32.0, 29.0, CZ + 0.6))
    # --- mandatory circulation: straight walks, ring by ring ---------------------------
    r.seg("tunnel", "walk", (0.0, 0.0, 1.5), (0.0, 0.0, 20.5))
    r.seg("stage_to_stair_1", "walk", (0.0, 0.0, 23.0), (8.0, 0.0, 23.0))
    r.seg("stair_1", "walk", (8.0, 0.0, 23.0), (8.0, 5.0, 31.5))
    r.seg("ring1_east", "walk", (13.0, 5.0, 32.0), (13.0, 5.0, 45.0))
    r.seg("ring1_back", "walk", (12.0, 5.0, 45.0), (-13.0, 5.0, 45.0))
    r.seg("stair_2", "walk", (-14.0, 5.0, 43.5), (-14.0, 10.0, 34.5))
    r.seg("ring2_west", "walk", (-19.0, 10.0, 34.0), (-19.0, 10.0, 13.0))
    r.seg("ring2_front_w", "walk", (-18.0, 10.0, 13.0), (0.0, 10.0, 13.0))
    r.seg("ring2_front_e", "walk", (0.0, 10.0, 13.0), (19.0, 10.0, 13.0))
    r.seg("stair_3", "walk", (20.0, 10.0, 14.5), (20.0, 15.0, 23.5))
    r.seg("ring3_east", "walk", (25.0, 15.0, 24.0), (25.0, 15.0, 50.0))
    r.seg("ring3_corner", "walk", (25.0, 15.0, 50.0), (25.0, 15.0, 57.0))
    r.seg("ring3_back_e", "walk", (24.0, 15.0, 57.0), (0.0, 15.0, 57.0))
    r.seg("ring3_back_w", "walk", (0.0, 15.0, 57.0), (-25.0, 15.0, 57.0))
    r.seg("stair_4", "walk", (-26.0, 15.0, 55.5), (-26.0, 20.0, 46.5))
    r.seg("ring4_west", "walk", (-30.0, 20.0, 47.0), (-30.0, 20.0, 62.0))
    r.seg("ring4_back", "walk", (-29.0, 20.0, 62.0), (0.0, 20.0, 62.0))
    r.seg("landing_to_exit", "walk", (0.0, 20.0, 62.0), (0.0, 20.0, 63.5))
    # optional: every terrace is one 5 m drop above the next one in
    r.seg("drop_ring2", "drop", (-19.0, 10.0, 45.0), (-13.0, 5.0, 45.0), mandatory=False)
    r.seg("drop_ring1", "drop", (-13.0, 5.0, 45.0), (-8.0, 0.0, 41.0), mandatory=False)
    # --- offers: two straight crossings over the bowl, not a spiral -------------------
    r.rail("rail_chord_x", [(25.0, 17.5, 26.0), (0.0, 18.5, CZ), (-25.0, 17.5, 38.0)])
    r.rail("rail_chord_z", [(0.0, 12.5, 12.0), (0.0, 13.5, CZ), (0.0, 12.5, 52.0)])
    r.launch("launch_stage", (0.0, 0.0, CZ), "land_ring_3w", radius=3.0)
    r.landing("land_ring_3w", (-25.0, 15.0, CZ), radius=3.0)
    r.grapple("grapple_stage", (0.0, 27.0, CZ), radius=1.5)
    # --- sockets / volumes --------------------------------------------------------------
    highs = (("ring2_back", (0.0, 10.3, 51.0)), ("ring3_east", (25.0, 15.3, 40.0)),
             ("ring3_west", (-25.0, 15.3, 24.0)), ("ring4_back", (0.0, 20.3, 62.0)),
             ("ring4_front", (-20.0, 20.3, 2.3)))
    for i, (sn, p) in enumerate(highs):
        r.socket("high_%d" % i, "enemy_high", p, surface_id=sn)
    for i, p in enumerate(((-6.0, 0.3, 27.0), (6.0, 0.3, 37.0))):
        r.socket("cover_%d" % i, "cover", p, surface_id="stage")
    r.socket("reactive_0", "reactive", (0.0, 0.3, 36.0), surface_id="stage")
    r.volume("arrival", "player_entry", (0.0, 1.0, 2.2), (2.4, 2.0, 2.4))
    r.volume("reward", "objective", (0.0, 1.0, CZ), (2.4, 2.0, 2.4))
    r.volume("stage_air", "no_build", (0.0, 12.0, CZ), (20.0, 24.0, 20.0))
    # --- the first read, asserted --------------------------------------------------------
    r.sightline("tunnel_to_exit", (0.0, 1.6, 20.5), (0.0, 24.0, 63.4))
    r.sightline("stage_to_top_ring", (0.0, 1.6, CZ), (0.0, 21.0, 60.5))
    r.sightline("top_ring_to_stage", (0.0, 21.6, 62.0), (0.0, 0.5, CZ))
    r.notes.append("The tunnel is the small term: 4 x 4 m for 21 m, driven under four "
                   "terraces, so the bowl is met from its lowest point.")
    r.notes.append("Every terrace is a solid mass, so the bowl has no underside and no "
                   "part of the room is hollow: a fall lands on the ring below or the stage.")
    r.notes.append("The two rails cross at right angles 5 m apart over the stage; neither "
                   "turns, which is the opposite of the helix a bowl invites.")
    return r


# --- readings -----------------------------------------------------------------------------
# (a) Gameplay packages, four ways with the same geometry:
#   the mob above: enemy_high on rings 2, 3 and 4; the player climbs into fire with the
#     stage at their back and every stair exposed to the ring above it.
#   stage fight: enemies spawn on the stage instead, and the rings become the player's
#     high ground -- the same room read from the outside in.
#   the public reward: the objective sits on the stage under every eye; taking it is
#     visible from all four terraces, and rail_chord_x is the way out over their heads.
#   empty: an amphitheatre.  The tunnel, the bowl and the portal at the top.
# (b) Strip test: with every offer and package removed there remain four terraces, a
#   stage, a tunnel and four stairs.  Still worth walking: the room is the only one in
#   the slate where every surface looks at one place, and the climb is a slow reveal of
#   how far down you started -- the stage shrinks behind you at each ring.
# (c) Recovery geography: nothing is below y 0 and no terrace overhangs, so a miss from
#   any ring lands on the ring below (5 m) or on the stage (up to 20 m, survivable: there
#   is no fall damage).  From the stage the mandatory route restarts at stair_1; from any
#   ring, walking the ring to its own stair rejoins the route.  Both optional drops are
#   declared so the composer knows the shortcut down exists.
# (d) Future machinery, acting at a distance without changing the shell: any single ring
#   stair is a gate point that holds the whole climb; the stage is watched by every ring,
#   so a switch there is a public event; the stage_air no_build volume is where a rising
#   platform would go if the library ever gets a lift.
