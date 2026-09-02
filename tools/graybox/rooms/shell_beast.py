"""shell_beast -- "the ribcage".

A 40 x 34 x 80 m nave under an arched section.  Nine ribs, one every 8 m,
spring from 1 m pilasters on the side walls at y 20 and step inward in
five leaning blocks to a keystone at y 30-31.5, with a spine beam running
the whole length beneath the roof.  Vertebra-decks alternate west (+9)
and east (+18) and are joined by four open cross-flights of thin treads
that zigzag the mandatory route back and forth across the nave; the
exit leaves from a full-width apse at +9.  The rail runs the spine.  The
nave floor beneath it all is one continuous surface from the 8 m porch
(the small term) to the back wall: the fast lane nobody is made to take.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gbkit

RIB_Z = (8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 56.0, 64.0, 72.0)
RIB_T = 0.6          # half thickness in z
TREADS = 18          # per cross-flight: 0.5 m risers on 1.333 m treads over 24 m


def rib(r, z):
    """A stepped block arch in the plane z: pilasters, four leaning blocks
    a side, one keystone.  Nothing below y 20 but the 1 m pilasters."""
    k = int(z)
    z0, z1 = z - RIB_T, z + RIB_T
    for side, sx in (("w", -1.0), ("e", 1.0)):
        def blk(tag, xa, xb, ya, yb):
            xs = sorted((sx * xa, sx * xb))
            r.block("rib%02d_%s_%s" % (k, side, tag), "wall", (xs[0], ya, z0), (xs[1], yb, z1))
        blk("pil", 19.0, 20.0, 0.0, 20.0)
        blk("l1", 15.0, 19.0, 20.0, 24.0)
        blk("l2", 11.0, 15.0, 24.0, 27.0)
        blk("l3", 7.0, 11.0, 27.0, 29.0)
        blk("l4", 3.0, 7.0, 29.0, 30.5)
    r.block("rib%02d_key" % k, "wall", (-3.0, 30.0, z0), (3.0, 31.5, z1))


def flight(r, name, z0, z1, y_lo=9.0, riser=0.5, x_lo=-12.0, x_hi=12.0):
    """An open cross-flight of thin treads spanning the nave from x_lo (at
    y_lo) to x_hi (at y_lo + TREADS*riser).  Tread k sits at
    x_lo + k*tread .. +1 with its top at y_lo + riser*(k+1), so the
    underside is open air and the long sightline passes beneath it.
    Built from slabs (surface=False), then declared as ONE surface at its
    high end, the way Room.stair declares a flight."""
    tread = (x_hi - x_lo) / TREADS
    for k in range(TREADS):
        r.slab("%s_t%02d" % (name, k), x_lo + k * tread, x_lo + (k + 1) * tread, z0, z1,
               y_lo + riser * (k + 1), thick=0.5, surface=False)
    r.surface(name, x_lo, x_hi, z0, z1, y_lo + riser * TREADS)


def build():
    W, H, D = 40.0, 34.0, 80.0
    r = gbkit.Room("shell_beast", W, H, D, wall=0.6,
                   intent=["long", "arched", "nave", "ribs", "zigzag", "spine_rail"])
    r.thesis = ("A long nave under an arched section: ribs every 8 m meet at a spine 30 m up, "
                "vertebra-decks alternate left and right so the walk zigzags across the nave "
                "on open flights while the rail runs the spine; the floor is the fast lane "
                "nobody is made to take.")
    r.first_read = ("An 8 m porch 4 m high opens onto a tunnel of nine stepped arches receding "
                    "80 m; the exit portal at +9 is visible through all of them, under every "
                    "cross-flight; decks jut from alternate sides at +9 and +18 like teeth.")
    half = W / 2
    # --- enclosure, porch (the small term) --------------------------------------------
    r.doors(exit_y=9.0, exit_yaw=0.0, entry_surface="porch", exit_surface="apse")
    r.enclose(exit_w=6.0, exit_h=8.0)
    r.block("porch_wall_w", "wall", (-4.6, 0.0, 0.6), (-4.0, 4.0, 4.0))
    r.block("porch_wall_e", "wall", (4.0, 0.0, 0.6), (4.6, 4.0, 4.0))
    r.block("porch_ceiling", "ceiling", (-4.6, 4.0, 0.6), (4.6, 4.6, 4.0))
    r.surface("porch", -4.0, 4.0, 0.6, 4.0, 0.0)
    r.surface("nave", -half, half, 4.0, D, 0.0)
    # --- the ribs and the spine --------------------------------------------------------
    for z in RIB_Z:
        rib(r, z)
    r.block("spine_beam", "trim", (-1.0, 31.5, 4.0), (1.0, 33.0, D))
    # --- decks ---------------------------------------------------------------------------
    # west_1 is cut around the stair well: a 3 m strip beside the flight, then full width
    r.slab("west_1_strip", -15.0, -12.0, 8.0, 17.5, 9.0)
    r.slab("west_1", -19.0, -12.0, 17.5, 30.0, 9.0)
    r.slab("east_1", 12.0, 19.0, 24.0, 40.0, 18.0)
    r.slab("west_2", -19.0, -12.0, 34.0, 56.0, 9.0)
    r.slab("east_2", 12.0, 19.0, 50.0, 68.0, 18.0)
    r.slab("apse", -19.0, 19.0, 70.0, D, 9.0)
    # --- stairs: one solid floor stair, four open cross-flights ---------------------------
    r.stair("stair_w1", -19.0, -15.0, 4.0, 17.5, 0.0, 9.0, axis="z", riser=0.5)
    flight(r, "cross_1", 26.0, 30.0)   # west_1 -> east_1   (bay 24/32)
    flight(r, "cross_2", 34.0, 38.0)   # east_1 -> west_2   (bay 32/40), walked downhill
    flight(r, "cross_3", 50.0, 54.0)   # west_2 -> east_2   (bay 48/56)
    flight(r, "cross_4", 66.0, 70.0)   # east_2 -> apse     (bay 64/72), walked downhill
    # --- traversal: the mandatory zigzag, all straight --------------------------------------
    r.seg("porch", "walk", (0.0, 0.0, 1.0), (0.0, 0.0, 3.5))
    r.seg("floor_w", "walk", (0.0, 0.0, 4.5), (-17.0, 0.0, 4.5))
    r.seg("stair_w1", "walk", (-17.0, 0.0, 5.0), (-17.0, 9.0, 17.0))
    r.seg("west_1", "walk", (-14.0, 9.0, 18.0), (-14.0, 9.0, 27.5))
    r.seg("cross_1", "walk", (-11.5, 9.0, 28.0), (11.5, 18.0, 28.0))
    r.seg("east_1", "walk", (14.0, 18.0, 29.0), (14.0, 18.0, 35.5))
    r.seg("cross_2", "walk", (11.5, 18.0, 36.0), (-11.5, 9.0, 36.0))
    r.seg("west_2", "walk", (-14.0, 9.0, 37.0), (-14.0, 9.0, 51.5))
    r.seg("cross_3", "walk", (-11.5, 9.0, 52.0), (11.5, 18.0, 52.0))
    r.seg("east_2", "walk", (14.0, 18.0, 53.0), (14.0, 18.0, 67.5))
    r.seg("cross_4", "walk", (11.5, 18.0, 68.0), (-11.5, 9.0, 69.0))
    r.seg("apse", "walk", (-11.5, 9.0, 71.0), (0.0, 9.0, 71.0))
    r.seg("exit", "walk", (0.0, 9.0, 71.0), (0.0, 9.0, 79.5))
    # optional: the fast lane in three straight pieces, and a drop from every deck
    r.seg("nave_a", "walk", (0.0, 0.0, 5.0), (0.0, 0.0, 32.0), mandatory=False)
    r.seg("nave_b", "walk", (0.0, 0.0, 32.0), (0.0, 0.0, 60.0), mandatory=False)
    r.seg("nave_c", "walk", (0.0, 0.0, 60.0), (0.0, 0.0, 79.0), mandatory=False)
    r.seg("drop_west_1", "drop", (-13.0, 9.0, 22.0), (-10.0, 0.0, 22.0), mandatory=False)
    r.seg("drop_east_1", "drop", (13.0, 18.0, 34.0), (10.0, 0.0, 34.0), mandatory=False)
    r.seg("drop_west_2", "drop", (-13.0, 9.0, 44.0), (-10.0, 0.0, 44.0), mandatory=False)
    r.seg("drop_east_2", "drop", (13.0, 18.0, 58.0), (10.0, 0.0, 58.0), mandatory=False)
    r.seg("drop_apse", "drop", (0.0, 9.0, 71.0), (0.0, 0.0, 68.0), mandatory=False)
    # --- offers ---------------------------------------------------------------------------
    # the spine rail: caught 2.5 m over west_1, swoops over east_1, rises to the spine,
    # dips to west_2, over east_2, and lands 2.5 m over the apse.  East points sit in the
    # bays between ribs so the baked curve keeps 0.7 m from the leaning blocks.
    # The rail crosses the nave only in the bays where no cross-flight hangs (the
    # flights occupy x -12..12 at z 26-30, 34-38, 50-54, 66-70 and top out at 18), and
    # runs the spine at 24+ everywhere else, so the baked curve keeps its 0.7 m.
    r.rail("rail_spine", [(-14.0, 11.5, 14.0), (-6.0, 18.0, 20.0), (0.0, 24.0, 30.0),
                          (0.0, 27.5, 44.0), (0.0, 24.0, 58.0), (-6.0, 18.0, 70.0),
                          (0.0, 11.5, 76.0)])
    r.launch("launch_w2", (0.0, 0.0, 44.0), "land_west_2", radius=2.5)
    r.landing("land_west_2", (-15.0, 9.0, 44.0), radius=2.5)
    r.grapple("grapple_spine_a", (0.0, 28.5, 20.0), radius=1.5)
    r.grapple("grapple_spine_b", (0.0, 28.5, 60.0), radius=1.5)
    # --- sockets / volumes -------------------------------------------------------------------
    highs = (("west_1", (-15.5, 9.3, 24.0)), ("east_1", (15.5, 18.3, 36.0)),
             ("west_2", (-15.5, 9.3, 45.0)), ("east_2", (15.5, 18.3, 59.0)),
             ("apse", (10.0, 9.3, 75.0)))
    for i, (sn, p) in enumerate(highs):
        r.socket("high_%d" % i, "enemy_high", p, surface_id=sn)
    for i, p in enumerate(((-18.5, 0.3, 24.0), (18.5, 0.3, 16.0), (-18.5, 0.3, 64.0), (18.5, 0.3, 48.0))):
        r.socket("cover_%d" % i, "cover", p, surface_id="nave")
    for i, p in enumerate(((6.0, 0.3, 20.0), (-6.0, 0.3, 60.0))):
        r.socket("reactive_%d" % i, "reactive", p, surface_id="nave")
    r.volume("arrival", "player_entry", (0.0, 1.0, 2.2), (2.4, 2.0, 2.4))
    r.volume("reward", "objective", (0.0, 10.0, 76.0), (2.4, 2.0, 2.4))
    r.volume("spine_air", "no_build", (0.0, 26.0, 42.0), (10.0, 10.0, 72.0))
    # --- the first read, asserted ------------------------------------------------------------
    r.sightline("entry_to_exit_portal", (0.0, 1.6, 2.0), (0.0, 12.0, 79.4))
    r.sightline("entry_to_far_keystone", (0.0, 1.6, 2.0), (0.0, 29.5, 71.4))
    r.notes.append("Cross-flights are 18 thin 0.5 m treads (surface=False) plus one declared surface each; "
                   "Room.stair would have walled the nave with its solid flank.")
    r.notes.append("Decks at +18 stand under rib blocks whose soffit is y 20: 0.15 m over the body test's head.")
    r.notes.append("Recovery is by the floor: any miss lands at y 0 and walks back to stair_w1 (or takes launch_w2).")
    return r


# --- readings ---
# (a) Four gameplay-package readings.
#   gauntlet: enemy_high on every deck and the apse; the player declines the zigzag and
#     runs the nave floor (optional nave_a/b/c) under fire, then must still climb stair_w1
#     or take launch_w2 to rejoin the route at west_2 -- the floor is fast, not free.
#   swallowed: the apse portal is gated until the reward (moved to east_2) is taken; enemies
#     arrive from the porch behind, and the four decks become a retreat ladder.
#   spine ride: rail_spine from west_1 to the apse is the one quiet way through; the two
#     spine grapples let a player rejoin it after a drop; the flights are the loud way.
#   empty: a nave.  Nine arches and a spine, the exit framed by all of them.
# (b) Strip test: with every offer removed there remain nine arches, five decks, one stair
#   and four open flights; the route is the same zigzag and the tallest point is still the
#   centre line you walk beneath.  Still worth walking: the section changes at every rib.
# (c) Recovery geography: a fall from any deck or flight lands on the nave floor at y 0
#   (no fall damage; nothing falls forever).  From west_1 / cross_1 walk back to stair_w1
#   (under 25 m).  From east_1 / cross_2 / west_2 / cross_3 / east_2 the nearest way back
#   on route is stair_w1 (up to 60 m) or launch_w2 to west_2 if the package is held.  From
#   cross_4 or the apse edge a drop lands under the apse and the walk back is 70 m -- the
#   cost of the room's length, and the strongest reason for the machinery in (d).
# (d) Machinery without touching the shell: the apse portal (x -3..3, y 9..17) is the natural
#   sealed door; any deck can be raised or dropped 1-2 m without moving a flight end more
#   than a riser; a lift in the bay under the apse (z 70..80, floor to +9) would close the
#   recovery loop; a switch on east_2 can gate cross_4; a bridge across the nave at +18 in
#   the free bay z 40..48 would join east_1 to west_2 directly.
