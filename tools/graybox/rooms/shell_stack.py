"""shell_stack -- "the room you fall through".

A 36 x 44 m building 38 m tall in section (roof 14 m over the entry plane,
floors at 0, -12 and -24) whose three full plates each carry a 14 x 14 well
cut in a different place, so from anywhere inside it the room shows its own
section.  You enter on the TOP plate under a low hood; the mandatory route
is two sheer DROPS -- through well A (front half of plate 0) onto plate 1,
then through well B (back half of plate 1) onto plate 2 -- and the exit is
on the bottom plate.  The only way back up is a pair of switchback stairs in
an east pocket, optional.  This is the slate's descending room: `drop` is the
traversal kind that exists for descent (Production 301374d), and the room's
one preflight warning is the authored-envelope field it waits on.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gbkit


def build():
    W, H, D = 36.0, 14.0, 44.0
    r = gbkit.Room("shell_stack", W, H, D, wall=0.6, floor_depth=24.0,
                   intent=["vertical", "descent", "plates", "wells", "drop"])
    r.thesis = ("Three full floor plates 12 m apart, each with a 14 x 14 well cut in a "
                "different place: the room shows its own section from anywhere inside it, "
                "and the mandatory route is two drops through the offset wells.")
    r.first_read = ("A low hood over the door, then a 6 m strip of floor ending at a 14 m hole; "
                    "through it the middle plate with its own hole further back, and through "
                    "that the far wall of the bottom level 24 m down. Two holes and a far wall.")
    half = W / 2
    # --- enclosure: walls -24..14, floor slab -25..-24 (= plate 2), doors -----------
    r.doors(exit_y=-24.0, exit_yaw=0.0, entry_surface="plate_0_front", exit_surface="plate_2")
    r.enclose(exit_w=6.0, exit_h=8.0, floor=False)
    # plate 2 is laid in four pieces AROUND flight_lower's footprint (x 10..14, z 8..32):
    # under hull-box evidence a floor box beneath a stair is walkable ground, and the
    # flood claims the cells under the treads before the climb reaches them (the 2-D
    # cell grid is shared), so the optional flight walk failed at import until the
    # floor under it was removed.  The treads reach down to -24.7, so nothing shows.
    w = r.wall
    r.block("floor_w", "floor", (-half - w, -25.0, 0.0), (10.0, -24.0, D + w))
    r.block("floor_e", "floor", (14.0, -25.0, 0.0), (half + w, -24.0, D + w))
    r.block("floor_s", "floor", (10.0, -25.0, 0.0), (14.0, -24.0, 8.0))
    r.block("floor_n", "floor", (10.0, -25.0, 32.0), (14.0, -24.0, D + w))
    r.surface("plate_2", -half, half, 0.0, D, -24.0)
    # the small term: a 10 x 3.8 x 6 hood over the door before the 38 m section opens
    r.block("entry_soffit", "ceiling", (-5.0, 3.8, 0.0), (5.0, 4.4, 6.0))
    # --- PLATE 0 (top 0): whole plan except well A (x -7..7, z 6..20) and the
    #     flight_upper headroom hole (x 14..18, z 8..17) ---------------------------------
    r.slab("plate_0_front", -half, half, 0.0, 6.0, 0.0)
    r.slab("plate_0_w", -half, -7.0, 6.0, 20.0, 0.0)
    r.slab("plate_0_e", 7.0, 14.0, 6.0, 20.0, 0.0)
    r.slab("plate_0_pocket_s", 14.0, 18.0, 6.0, 8.0, 0.0)
    r.slab("plate_0_pocket_n", 14.0, 18.0, 17.0, 20.0, 0.0)
    r.slab("plate_0", -half, half, 20.0, D, 0.0)
    # --- PLATE 1 (top -12): whole plan except well B (x -7..7, z 24..38) and the
    #     flight_lower headroom hole (x 10..14, z 22..32) ---------------------------------
    #     No slab under flight_upper (x 14..18, z 8..32) for the same reason as plate 2;
    #     its treads reach down to -12.7 and close the underside themselves.
    r.slab("plate_1", -half, 10.0, 0.0, 24.0, -12.0)
    r.slab("plate_1_ne", 10.0, 14.0, 0.0, 22.0, -12.0)
    r.slab("plate_1_pocket", 14.0, 18.0, 0.0, 8.0, -12.0)
    r.slab("plate_1_w", -half, -7.0, 24.0, 38.0, -12.0)
    r.slab("plate_1_e", 7.0, 10.0, 24.0, 32.0, -12.0)
    r.slab("plate_1_landing", 7.0, 18.0, 32.0, 38.0, -12.0)
    r.slab("plate_1_back", -half, half, 38.0, D, -12.0)
    # --- STAIRS (optional way up): two flights side by side in the east pocket -------
    # flight_lower rises +z from plate 2 (z 8) to plate 1 (z 32); flight_upper
    # rises -z from plate 1's landing (z 32) to plate 0 (z 8).
    r.stair("flight_lower", 10.0, 14.0, 8.0, 32.0, -24.0, -12.0, axis="z", riser=0.5)
    r.stair("flight_upper", 14.0, 18.0, 8.0, 32.0, -12.0, 0.0, axis="z", riser=0.5, reverse=True)
    # --- mandatory route: walk, drop, walk, drop, walk ---------------------------------
    r.seg("plate_0_walk", "walk", (0.0, 0.0, 1.0), (0.0, 0.0, 4.5))
    r.seg("well_a", "drop", (0.0, 0.0, 5.3), (0.0, -12.0, 8.0))
    r.seg("plate_1_walk", "walk", (0.0, -12.0, 8.5), (0.0, -12.0, 22.5))
    r.seg("well_b", "drop", (0.0, -12.0, 23.3), (0.0, -24.0, 26.0))
    r.seg("plate_2_walk", "walk", (0.0, -24.0, 26.5), (0.0, -24.0, 43.0))
    # --- optional: the flights up, and the ring round well B ----------------------------
    r.seg("flight_lower", "walk", (12.0, -24.0, 7.5), (12.0, -12.0, 31.5), mandatory=False)
    r.seg("flight_upper", "walk", (16.0, -12.0, 32.5), (16.0, 0.0, 8.5), mandatory=False)
    r.seg("plate_1_ring_w", "walk", (-12.0, -12.0, 22.5), (-12.0, -12.0, 41.0), mandatory=False)
    r.seg("plate_1_ring_e", "walk", (8.5, -12.0, 22.5), (8.5, -12.0, 41.0), mandatory=False)
    r.seg("plate_1_ring_back", "walk", (-12.0, -12.0, 41.0), (8.5, -12.0, 41.0), mandatory=False)
    # --- offers -------------------------------------------------------------------------
    # rail: 2.2 m over the entry strip, in through well A's west rim, under plate 0,
    # through well B, ending 1.5 m over plate 2 by the exit
    r.rail("rail_wells", [(-12.0, 2.2, 3.0), (-2.0, 0.0, 12.0), (0.0, -8.0, 18.0),
                          (4.0, -11.0, 26.0), (0.0, -18.0, 32.0), (-3.0, -22.5, 42.0)])
    # upward launch through well B: source under the well (outside every deck's plan)
    r.launch("launch_up", (0.0, -24.0, 31.0), "land_plate_1", radius=2.5)
    r.landing("land_plate_1", (0.0, -12.0, 21.0), radius=2.5)
    r.grapple("grapple_under_0", (0.0, -2.0, 30.0), radius=1.5)   # under plate 0, over well B's column
    r.grapple("grapple_roof", (0.0, 12.0, 13.0), radius=1.5)       # under the roof, over well A
    # --- sockets / volumes --------------------------------------------------------------
    highs = (("plate_0_w", (-10.0, 0.3, 13.0)), ("plate_0_e", (10.0, 0.3, 13.0)),
             ("plate_1_w", (-10.0, -11.7, 31.0)), ("plate_1_e", (8.5, -11.7, 30.0)))
    for i, (sn, p) in enumerate(highs):
        r.socket("high_%d" % i, "enemy_high", p, surface_id=sn)
    for i, p in enumerate(((-8.0, -23.7, 14.0), (8.0, -23.7, 20.0), (-6.0, -23.7, 38.0))):
        r.socket("cover_%d" % i, "cover", p, surface_id="plate_2")
    r.socket("reactive_0", "reactive", (-12.0, -11.7, 10.0), surface_id="plate_1")
    r.volume("arrival", "player_entry", (0.0, 1.0, 2.2), (2.4, 2.0, 2.4))
    r.volume("reward", "objective", (0.0, -23.0, 40.0), (2.4, 2.0, 2.4))
    r.volume("well_a_air", "no_build", (0.0, -6.0, 13.0), (14.0, 12.0, 14.0))
    r.volume("well_b_air", "no_build", (0.0, -18.0, 31.0), (14.0, 12.0, 14.0))
    # --- the first read, asserted ----------------------------------------------------
    # from the door: down through well A to the far wall of the middle level
    r.sightline("entry_through_well_a", (0.0, 1.6, 2.0), (0.0, -8.0, 43.4))
    # from the end of the entry strip: through BOTH wells to the far wall of the
    # bottom level (the exit portal's head is at -16)
    r.sightline("lip_through_both_wells", (0.0, 1.6, 4.5), (0.0, -16.5, 43.4))
    # from plate 1's well lip: down through well B to plate 2
    r.sightline("plate_1_down_well_b", (0.0, -10.4, 23.0), (0.0, -23.5, 37.0))
    # --- contract observations ----------------------------------------------------------
    r.notes.append(
        "CONTRACT DEPENDENCY: Room('shell_stack', 36, 14, 44, floor_depth=24.0); entry plane y 0 "
        "(top plate), plates at y 0, -12, -24, roof 14 m above the top plate. Under Production "
        "301374d the traversal law (drop) and ZoneBuilder (exit_offset.y = -24) accept this room, "
        "but the authored-shell envelope (_from_authored_scene bounds; _check_envelope) is built "
        "from `size` alone with the floor 1 m below the entry plane, so the shell is refused at "
        "import until a `floor_depth` field exists. The preflight keeps exactly ONE warning "
        "saying so; that warning is expected.")
    r.notes.append(
        "FALL_KILL_Y is WORLD y -30 (player.gd). This room's floor is at -25 relative to its own "
        "entry, so the chain must bring the entry in at world y > -5 for plate 2 to be survivable; "
        "a 24 m descent needs ~24 m of prior rise in the chain to be safe.")
    r.notes.append(
        "A drop from plate 0 straight to plate 2 through both wells is NOT possible: well A (z 6..20) "
        "and well B (z 24..38) are offset, so every fall from plate 0 lands on plate 1.")
    r.notes.append(
        "Sightlines: from the door (z 2) the well-A window spans slopes -0.13..-0.40, so well B is "
        "not visible until the player reaches the strip's end (z 4.5); the through-both-wells line "
        "is asserted from there, aimed at the bottom level's far wall (-16.5, the portal head), "
        "because from z 2 the brief's (0,-15,43.4) grazes plate 0's lip at z 6 within 4 mm.")
    r.notes.append(
        "Plate 1's east enemy_high sits at (8.5, -11.7, 30) on the 3 m rim strip between well B "
        "and the flight_lower headroom hole; the brief's x 10 is that hole's edge.")
    r.notes.append(
        "Headroom holes: plate 0 is cut x 14..18 z 8..17 over flight_upper (treads within 2.4 m of "
        "its underside end at z 15; body evidence pinches to z 14), plate 1 is cut x 10..14 "
        "z 22..32 over flight_lower (pinch at z 25/26); both carry 2-3 m of margin.")
    return r


# --- readings ---
# (a) Four gameplay-package readings.
#     floor by floor: each plate is a held room; enemies on the plate above rain
#       through the well onto the player, who can only answer by finding the
#       switchback (east pocket) or by dropping again.
#     snipers' stack: enemy_high on the four well rims (two per plate); the player
#       runs the bottom plate under two rings of fire, and well B's air column is
#       the only place all four can see at once.
#     descent chase: reward on plate 2 (0,-23,40); enemies above, the wells are the
#       fast way down (two drops, ~10 s), the rail is faster still (55 m in ~6 s),
#       the grapple under plate 0 shortcuts well B for anyone with the package.
#     empty: a building with its floors cut open; a section made walkable.
# (b) Strip test.  With rail, launch and both grapples removed: two full plates,
#     two wells, two drops and a switchback stair.  The room is still exactly
#     itself -- the drops ARE the route, and the stairs still give the way back up
#     and the ring round well B.  Worth walking: yes; the offers add speed and a
#     way UP, never the descent.
# (c) Recovery geography.  A miss from plate 0 lands on plate 1 (never plate 2:
#     the wells are offset); a miss from plate 1 lands on plate 2.  Every fall is
#     12 m onto a full plate and lands the player CLOSER to the exit.  From plate 2
#     the flight_lower (east pocket, z 8..32) returns you to plate 1's landing;
#     flight_upper (z 32..8) returns you to plate 0's front strip.  A launch miss
#     lands in well B's column on plate 2, i.e. on the route.
# (d) Machinery.  A hatch in any plate is a new route (the plates are full, so a
#     second well anywhere is a second drop).  The two flights are the thing a lift
#     could replace: a 24 m car in the east pocket x 10..18.  A gate at the well
#     lips (z 6 on plate 0, z 24 on plate 1) would hold a floor; a bridge across
#     well B at plate 1 would make the ring a crossing; a switch on plate 2 could
#     open the exit portal head (-16) without touching the shell.
