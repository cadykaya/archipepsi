"""The words for `make_review_pdf.py`. Authored prose, kept separate.

Every NUMBER in the PDF is read from the shipped manifests by the
builder. Everything in this file is judgement, and it is separated so
that the two cannot be confused: if a room changes, the builder's
figures move on their own and these paragraphs have to be re-read by a
person.
"""

COVER = {
    "kicker": "ARCHIPEPSI / ART LANE / FOR REVIEW",
    "title": "The authored room library",
    "notes": [
        ("WHAT THIS IS",
         "Four large rooms, thirty renders, and what I think you should do "
         "about each one. Every picture is an actual shipped render straight "
         "out of the build -- nothing redrawn, recomposed or cropped to "
         "flatter a room."),
        ("THE FOUR ROOMS",
         "<b>Hall</b> (the P3 room, reviewed once already and repaired "
         "twice since), then Wave 1: <b>Plenum</b>, a 72 m shaft; "
         "<b>Yard</b>, an 84 m field; <b>Span</b>, a 90 m bridge over a "
         "walkable basin. Three proportions on purpose -- tall, wide, long "
         "-- so the library cannot become one room built three times."),
        ("WHAT I AM NOT ASKING FOR",
         "None of these promote themselves. All four ship as "
         "<i>review: pending</i> and Art never writes <i>pass</i>. This is "
         "a request for your read on form, plus four decisions I have "
         "flagged and cannot make alone."),
        ("STATE",
         "Built and measured at commit 8fbb916 on branch "
         "claude/archipepsi-art. The hall's three staircases were rebuilt "
         "yesterday after Production's capsule audit refused two of them; "
         "that repair is pages S1 to S4."),
    ],
}

HOWTO = {
    "kicker": "BEFORE YOU SCROLL",
    "title": "How to read this",
    "notes": [
        ("ONE PICTURE PER PAGE",
         "Each render fills the width of the page, with the notes for that "
         "exact picture underneath it. Pinch to zoom -- the images are "
         "1400 px wide, so there is roughly three times more detail in them "
         "than a phone shows at first fit."),
        ("THE VOCABULARY, IN PLAIN TERMS",
         "A <b>stand surface</b> is somewhere the game promises you can "
         "stand. A <b>route segment</b> is a declared way of getting from "
         "one to another; <i>walk</i> means there is continuous ground, "
         "<i>drop</i> means you fall on purpose. An <b>offer</b> is a place "
         "reserved for a movement mechanic -- a rail to ride, a pad to "
         "launch from, an anchor to grapple. Art reserves the place. "
         "Production decides what the mechanic does there."),
        ("WHAT ART NEVER AUTHORS",
         "No trajectories, no velocities, no arcs. The launch pages draw "
         "two pads and deliberately nothing between them, because the "
         "solver derives the flight from the pads and gravity -- and the "
         "first time a drawn curve disagreed with it, the drawing is what "
         "everyone would remember. No enemies are placed and no encounter "
         "is authored either."),
        ("COLOUR",
         "Where I have written a recommendation, <font color='#86c46a'>"
         "green is approve as-is</font> and <font color='#e8894a'>orange is "
         "something I want changed or decided</font>."),
    ],
}

DECISIONS = [
    {
        "kicker": "THE SHORT VERSION",
        "title": "What I would approve",
        "items": [
            ("approve", "ALL FOUR ROOM SHAPES",
             "The three Wave 1 proportions are genuinely different rooms "
             "and not one idea stretched three ways: you arrive at the top "
             "of the Plenum and the whole room is the way down; you cross "
             "the Yard and never have to climb at all; you walk the Span "
             "twice at two heights. Strip out every enemy, pickup and "
             "decoration and you would still know which is which from the "
             "silhouette alone. The Hall still reads as it did at P3."),
            ("approve", "THE STAIRCASE REPAIR",
             "Production refused two of the Hall's three climbs on the real "
             "player capsule. The cause was one missing coordinate "
             "conversion in the shared helper, so the Wave 1 rooms had it "
             "too. All nineteen flights in the library now measure a worst "
             "real step of 0.89 m against a 1.00 m limit, taken from the "
             "collision triangles rather than from bounding boxes. The "
             "Hall's declared contract did not change by a single field."),
            ("approve", "THE OFFER GRAMMAR IN WAVE 1",
             "Each Wave 1 room declares one rail, one launch pair and three "
             "grapple anchors -- the same three-part vocabulary in three "
             "very different spaces. I would keep that as the house pattern "
             "for the remaining six rooms."),
        ],
    },
    {
        "kicker": "THE SHORT VERSION",
        "title": "What I want changed or decided",
        "items": [
            ("change", "1. GIVE THE HALL GRAPPLE POINTS",
             "The Hall is the only one of these four rooms with none, and "
             "not for a design reason: it was authored before grapple "
             "points existed in the contract. Its own overlay (page O5) already "
             "marks the overhead structure an anchor would hang from. I "
             "would add three, on the three collar rings. Small, contained, "
             "and it stops the Hall being the odd one out. <b>My "
             "recommendation: do it.</b>"),
            ("change", "2. CLOSE THE HALL'S COLLAR RING",
             "The walkway around the landmark is a C, not an O. From the "
             "north collar you can go east toward the exit or west to the "
             "south collar, and then you have to come back the way you "
             "came. One more segment would let you circle the landmark. In "
             "a fight around a thing that breaks line of sight, being able "
             "to keep going round is worth a lot. <b>My recommendation: "
             "close it.</b>"),
            ("change", "3. CONFIRM THE SPAN'S ONE-WAY DROP",
             "The Span is the only room with a <i>drop</i> segment: from "
             "the middle of the deck you can commit down to the basin, and "
             "getting back up costs a walk to either end. I think that is "
             "exactly right -- it makes the choice cost something -- but it "
             "is a design decision rather than a build detail, so it should "
             "be yours. <b>My recommendation: keep it, but say so out "
             "loud.</b>"),
            ("change", "4. DECIDE THE YARD'S HEIGHT NOW",
             "The Yard is 84 m across and only 16 m tall, so it is the one "
             "room where climbing is optional and the crane and catwalk do "
             "all the vertical work. That may be exactly the contrast the "
             "library wants. If it is not, the fix is a height change, and "
             "it is far cheaper before Wave 2 copies the proportion than "
             "after. <b>My recommendation: leave it, but look at pages B1 "
             "and B2 and tell me if you disagree.</b>"),
            ("hold", "AND TWO THINGS THAT ARE NOT DECISIONS",
             "All four rooms stay <i>pending</i> until you say otherwise, "
             "and Production still has to re-certify the Hall against the "
             "rebuilt staircases. Wave 2 has not started and will not until "
             "you have given a verdict on these four."),
        ],
    },
]

# --------------------------------------------------------------------
# the rooms
# --------------------------------------------------------------------

HALL_DIR = "docs/art/review/hall_67add07"
W1_DIR = "docs/art/review/wave1"

HALL = {
    "id": "shell_hall_transit",
    "dir": HALL_DIR,
    "subtitle": "ROOM 1 OF 4 / THE P3 ROOM / REVIEWED ONCE, REPAIRED TWICE",
    "title": "Hall",
    "distinct":
        "The landmark in the middle is a FRAME, not a solid. A solid block "
        "would have been the easier sculpture, and it would sit exactly on "
        "the one line the room needs you to see -- the exit, 60 m away and "
        "28 m up, visible from the doorway. So the landmark is four columns "
        "and three rings around a 12 m open shaft, and that sightline is "
        "checked at build time across 64.7 m; the build fails if anything "
        "gets in the way. The rings still hide the west gallery from the "
        "door, so the room keeps revealing pieces of itself as you cross "
        "it. Four occupied heights: floor 0, west gallery 11, the "
        "ring-and-gantry band at 21, exit at 28, roof at 38.",
    "route":
        "In at floor level, out onto the basin, west stair up to the "
        "gallery at 11, a second stair up the back wall to the north "
        "landing at 21, across a bridge onto the collar around the "
        "landmark, round it to the east side, across a second bridge onto "
        "the gantry, then a last stair up to the exit at 28. Every metre of "
        "that is on foot with no movement gear installed -- which is the "
        "condition the offers below are allowed to exist under.",
    "offers":
        "A rail that climbs from head height to 31.5 m, twice around the "
        "landmark. A launch pair that skips the whole middle of the route: "
        "a pad on the basin floor aimed at the east gantry 24.5 m away, so "
        "a player with the launch package trades the two stairs and the "
        "collar walk for one jump. No grapple anchors -- see my note.",
    "verdict":
        "Change, in two small ways. The shape is right and I would approve "
        "it as it stands: keep the frame landmark, the four heights and the "
        "route. But give it grapple anchors on the collar rings, and close "
        "the collar ring so you can circle the landmark instead of "
        "doubling back. Neither touches the geometry you already reviewed.",
    "shots": [
        {"file": "H1_entry.png", "kicker": "HALL / VIEW 1 OF 18",
         "title": "Inside the door",
         "notes": [
             ("WHERE YOU ARE", "At floor level, three metres inside the "
              "only door, looking down the 60 m length of the room."),
             ("WHAT YOU ARE LOOKING AT", "A 10 x 9 x 5.5 m vestibule "
              "opening straight onto the full hall. The small space comes "
              "first deliberately: scale is a comparison, so you are given "
              "the small term before the big one. Dead ahead is the "
              "landmark -- four columns and three rings around an open "
              "shaft."),
             ("THE ROUTE", "Everything starts here. Out onto the basin, "
              "then left to the first stair."),
             ("OFFERS", "None reach you here. The launch pad is out on the "
              "basin floor ahead and to the right."),
             ("MY CALL", "Approve. This is the first read the P3 direction "
              "asked for, and it survived both repairs unchanged."),
         ]},
        {"file": "H2_hero.png", "kicker": "HALL / VIEW 2 OF 18",
         "title": "The whole volume",
         "notes": [
             ("WHERE YOU ARE", "26 m up near the entry end -- not a place "
              "you can stand, a camera placed to show the room at once."),
             ("WHAT YOU ARE LOOKING AT", "All four occupied heights in one "
              "frame, with the roof 38 m up. About 91,000 cubic metres, "
              "roughly forty times the largest of the earlier small rooms."),
             ("THE ROUTE", "The entire climb is visible here: west stair, "
              "back stair, the collar around the landmark, the gantry, and "
              "the last stair to the exit."),
             ("OFFERS", "The rail crosses the upper third of the frame, "
              "twice around the landmark, ending at 31.5 m."),
             ("MY CALL", "Approve. If you only look at two pages, this and "
              "the next one are the two."),
         ]},
        {"file": "H3_over.png", "kicker": "HALL / VIEW 3 OF 18",
         "title": "The arrangement, from under the roof",
         "notes": [
             ("WHERE YOU ARE", "33 m up, five metres below the ceiling, "
              "looking down the room."),
             ("WHAT YOU ARE LOOKING AT", "The plan. The landmark sits in "
              "the middle and everything else is arranged around it rather "
              "than beside it, which is what stops the room reading as one "
              "big rectangle with things in it."),
             ("THE ROUTE", "From up here the route reads as a spiral: up "
              "the west side, across the back, around the collar, out the "
              "east side and up."),
             ("OFFERS", "The rail's two turns around the landmark are "
              "clearest from this angle."),
             ("MY CALL", "Approve. This is the view that answers 'several "
              "local spaces or one big hall'. It is several."),
         ]},
        {"file": "H4_low.png", "kicker": "HALL / VIEW 4 OF 18",
         "title": "On the floor, beside the landmark",
         "notes": [
             ("WHERE YOU ARE", "Standing on the basin floor, 13 m west of "
              "centre, a third of the way into the room."),
             ("WHAT YOU ARE LOOKING AT", "The landmark from underneath, at "
              "its full 30 m. This is the scale contrast the room is built "
              "around -- the same structure that read as a frame from above "
              "reads as a wall of machinery from down here."),
             ("THE ROUTE", "This floor is the retreat space: one continuous "
              "surface under the entire room, shaft included."),
             ("OFFERS", "The launch pad is on this floor. The shaft "
              "overhead is reserved for vertical movement."),
             ("MY CALL", "Approve. Nothing in this room falls forever -- "
              "there is no pit and no void anywhere, so a missed rail or "
              "launch costs you height and a walk back, never the level. "
              "That was a hard requirement and it is met."),
         ]},
        {"file": "H5_mid.png", "kicker": "HALL / VIEW 5 OF 18",
         "title": "The west gallery, at 11 m",
         "notes": [
             ("WHERE YOU ARE", "On the west gallery, 11 m up, with the "
              "first climb behind you."),
             ("WHAT YOU ARE LOOKING AT", "The middle height of the room, "
              "and the back wall the second stair climbs."),
             ("THE ROUTE", "You got here up thirteen steps from the floor. "
              "The next stair leaves from the far end of this gallery and "
              "goes up to the landing at 21."),
             ("OFFERS", "The rail passes overhead; nothing lands on this "
              "gallery. It is a walking floor, on purpose -- one of the "
              "four heights has to be plain."),
             ("MY CALL", "Approve."),
         ]},
        {"file": "H6_high.png", "kicker": "HALL / VIEW 6 OF 18",
         "title": "The east gantry, facing the last climb",
         "notes": [
             ("WHERE YOU ARE", "On the east gantry, 21 m up, one flight "
              "short of the exit."),
             ("WHAT YOU ARE LOOKING AT", "The final staircase, eight steps "
              "up to the exit platform at 28."),
             ("THE ROUTE", "Gantry, stair, exit. This is the last leg."),
             ("OFFERS", "This gantry is the LANDING pad of the launch pair "
              "-- a 3.5 m circle. A player with the launch package arrives "
              "here straight off the basin floor and skips everything "
              "between."),
             ("MY CALL", "Approve. This is the clearest example in the "
              "library of an offer that shortens a route without replacing "
              "it."),
         ]},
        {"file": "H7_reverse.png", "kicker": "HALL / VIEW 7 OF 18",
         "title": "From the exit, looking back",
         "notes": [
             ("WHERE YOU ARE", "On the exit platform, 28 m up at the far "
              "end -- the destination."),
             ("WHAT YOU ARE LOOKING AT", "The whole room from the other "
              "end. Compare it with page 1: the same space, and the door "
              "you came in by is visible from here."),
             ("THE ROUTE", "Everything you just climbed, in reverse."),
             ("OFFERS", "The rail's high end is just above and behind."),
             ("MY CALL", "Approve. The room reads from both ends, which is "
              "what makes it a transit hall rather than a cul-de-sac with a "
              "view."),
         ]},
        {"file": "H8_vertical.png", "kicker": "HALL / VIEW 8 OF 18",
         "title": "Straight up the shaft",
         "notes": [
             ("WHERE YOU ARE", "On the basin floor, dead centre under the "
              "landmark, looking straight up."),
             ("WHAT YOU ARE LOOKING AT", "The 12 m open shaft through the "
              "middle of the machine -- three rings, floor to 30 m, then "
              "roof at 38."),
             ("THE ROUTE", "Nothing goes up here on foot, deliberately. "
              "This column of air is kept clear."),
             ("OFFERS", "It is reserved as a vertical-movement volume: any "
              "future lift, updraught or moving platform wants this space, "
              "and nothing is allowed to be built in it."),
             ("MY CALL", "Approve as a reservation. This is also the space "
              "I most want a grapple anchor to serve -- see page O5."),
         ]},
        {"file": "O1_regions.png", "kicker": "HALL / DIAGRAM A OF 6",
         "title": "Every place you can stand",
         "notes": [
             ("WHERE YOU ARE", "An overhead diagram, not a photograph. It "
              "is built from the shipped data rather than drawn over a "
              "render, so it cannot quietly disagree with the room."),
             ("WHAT YOU ARE LOOKING AT", "All twelve declared stand "
              "surfaces as green plates at their true sizes and heights, "
              "with the five raised enemy positions as violet posts."),
             ("THE ROUTE", "Not shown here -- see the next page."),
             ("OFFERS", "Not shown here."),
             ("MY CALL", "Approve. Twelve distinct places to stand, well "
              "under the limit of thirty-two, and they are different sizes "
              "at four different heights rather than one floor chopped up."),
         ]},
        {"file": "O2_route.png", "kicker": "HALL / DIAGRAM B OF 6",
         "title": "The route on foot",
         "notes": [
             ("WHERE YOU ARE", "Overhead diagram."),
             ("WHAT YOU ARE LOOKING AT", "The eleven declared route "
              "segments that get you from the door to the exit with no "
              "movement package installed at all."),
             ("THE ROUTE", "Every one of the eleven is a <i>walk</i> -- "
              "continuous ground the whole way. There is no point in this "
              "room where the only way forward is a mechanic you might not "
              "have."),
             ("OFFERS", "Nothing here is an offer. That is the point of "
              "this diagram."),
             ("MY CALL", "Change. Look at the walkway around the landmark: "
              "it is a C, not an O. From the north collar you can go east "
              "to the gantry or west to the south collar, and the south "
              "collar is a dead end. One more segment closes the loop and "
              "lets you circle the landmark. I would add it."),
         ]},
        {"file": "O3_rail.png", "kicker": "HALL / DIAGRAM C OF 6",
         "title": "The rail",
         "notes": [
             ("WHERE YOU ARE", "Overhead diagram."),
             ("WHAT YOU ARE LOOKING AT", "The reserved rail route: eleven "
              "control points, 143.9 m, climbing from head height to "
              "31.5 m, twice around the landmark."),
             ("THE ROUTE", "It shadows the walking route without replacing "
              "it -- same journey, one long ride instead of three "
              "staircases."),
             ("OFFERS", "Art places sparse control points only. The smooth "
              "curve through them is Production's, so the ride can be tuned "
              "without re-authoring the room."),
             ("MY CALL", "Approve. Two turns around a landmark is the "
              "single best thing in the room for a rail -- you keep seeing "
              "the same object from changing angles as you climb."),
         ]},
        {"file": "O4_launch.png", "kicker": "HALL / DIAGRAM D OF 6",
         "title": "The launch pair",
         "notes": [
             ("WHERE YOU ARE", "Overhead diagram."),
             ("WHAT YOU ARE LOOKING AT", "Two pads: a filled disc on the "
              "basin floor you launch FROM, and an open ring on the east "
              "gantry you land ON, 24.5 m apart."),
             ("THE ROUTE", "Taking it skips both lower staircases and the "
              "collar walk, dropping you one flight below the exit."),
             ("OFFERS", "There is deliberately NOTHING drawn between the "
              "two pads. The game works out the flight from the two pads "
              "and gravity; if a curve were drawn here and the game "
              "disagreed with it, the drawing is what everyone would "
              "remember."),
             ("MY CALL", "Approve."),
         ]},
        {"file": "O5_overhead.png", "kicker": "HALL / DIAGRAM E OF 6",
         "title": "What a grapple would hang from",
         "notes": [
             ("WHERE YOU ARE", "Looking up from the basin floor."),
             ("WHAT YOU ARE LOOKING AT", "The overhead structure marked "
              "out: the three collar rings, and the undersides of the "
              "gallery, gantry and landing."),
             ("THE ROUTE", "Not a route. This is the figure that asked a "
              "question."),
             ("OFFERS", "When this room was built, grapple anchors did not "
              "exist in the contract, so this diagram marks candidate "
              "structure and says in its own caption that it is a question, "
              "not an offer."),
             ("MY CALL", "Change -- and this is my main recommendation. "
              "Grapple anchors landed in the contract afterwards, and all "
              "three Wave 1 rooms declare three each. The Hall declares "
              "none, purely because of when it was built. I would add three "
              "on the rings marked here."),
         ]},
        {"file": "O6_shaft.png", "kicker": "HALL / DIAGRAM F OF 6",
         "title": "The vertical movement volume",
         "notes": [
             ("WHERE YOU ARE", "Looking up the shaft from the basin."),
             ("WHAT YOU ARE LOOKING AT", "The reserved column of air "
              "through the landmark, continuous and unobstructed from the "
              "floor to the top of the machine."),
             ("THE ROUTE", "No walking route uses it."),
             ("OFFERS", "It is a no-build volume held open for whatever "
              "vertical mechanic arrives -- a lift, an updraught, rising "
              "platforms. Reserving the space costs nothing now and cannot "
              "be recovered later if the room fills in."),
             ("MY CALL", "Approve as a reservation. Nothing uses it yet and "
              "nothing needs to."),
         ]},
        {"file": "S1_ramp1_basin_to_gallery.png",
         "kicker": "HALL / THE REPAIR / 1 OF 4",
         "title": "The first climb, rebuilt",
         "notes": [
             ("WHERE YOU ARE", "Standing on the basin at the foot of the "
              "west staircase, looking up it."),
             ("WHAT YOU ARE LOOKING AT", "Thirteen flat treads climbing "
              "from the floor to the west gallery at 11 m. Until yesterday "
              "these were sloped wedges, and every one of them sloped the "
              "wrong way -- the ground fell away underfoot and then "
              "demanded a 1.4 m step up, which no player can make. "
              "Production caught it with a real player capsule; none of my "
              "own checks could, because they were all measuring bounding "
              "boxes and a box cannot see a slope."),
             ("THE ROUTE", "The first climb of the mandatory route."),
             ("OFFERS", "None. This is the plain way up, and it has to work "
              "before any offer is allowed to exist."),
             ("MY CALL", "Approve. This is one of the two staircases "
              "Production refused. Measured off the collision triangles at "
              "10 cm spacing, the worst real step is now 0.85 m against a "
              "1.00 m limit."),
         ]},
        {"file": "S2_ramp2_gallery_to_landing.png",
         "kicker": "HALL / THE REPAIR / 2 OF 4",
         "title": "The middle climb -- the one that was always fine",
         "notes": [
             ("WHERE YOU ARE", "On the west gallery at 11 m, at the foot of "
              "the back-wall staircase."),
             ("WHAT YOU ARE LOOKING AT", "Twelve treads up to the north "
              "landing at 21 m. This flight was never refused, and it is "
              "here for comparison: it happened to run along the one axis "
              "where the old wedge maths came out right. Side by side with "
              "the page before, the two look the same now -- which is the "
              "point."),
             ("THE ROUTE", "Second climb of the mandatory route."),
             ("OFFERS", "None."),
             ("MY CALL", "Approve. Worst real step 0.83 m."),
         ]},
        {"file": "S3_ramp3_gantry_to_exit.png",
         "kicker": "HALL / THE REPAIR / 3 OF 4",
         "title": "The last climb, rebuilt",
         "notes": [
             ("WHERE YOU ARE", "On the east gantry at 21 m, at the foot of "
              "the final staircase."),
             ("WHAT YOU ARE LOOKING AT", "Eight treads up to the exit "
              "platform at 28 m -- the steepest flight in the room. This "
              "was the second one Production refused."),
             ("THE ROUTE", "The last leg. It is also where a launched "
              "player rejoins the walking route."),
             ("OFFERS", "The launch pad you would have landed on is behind "
              "the camera."),
             ("MY CALL", "Approve. Worst real step 0.88 m -- the largest in "
              "the room, and still comfortably inside the limit."),
         ]},
        {"file": "S4_ramp1_from_the_gallery.png",
         "kicker": "HALL / THE REPAIR / 4 OF 4",
         "title": "The same stair, going down",
         "notes": [
             ("WHERE YOU ARE", "At the top of the west staircase on the "
              "gallery at 11 m, looking back down."),
             ("WHAT YOU ARE LOOKING AT", "The same thirteen treads from "
              "page S1, receding to the floor. Worth its own page because a "
              "staircase is used in both directions and this is the one "
              "players will see most -- coming back down is what you do "
              "after you have been up."),
             ("THE ROUTE", "The descent, and the retreat."),
             ("OFFERS", "None."),
             ("MY CALL", "Approve."),
         ]},
    ],
}

PLENUM = {
    "id": "shell_plenum_helix",
    "dir": W1_DIR,
    "subtitle": "ROOM 2 OF 4 / WAVE 1 / NEVER REVIEWED",
    "title": "Plenum",
    "distinct":
        "A 72 m shaft, and the only room in the library where you arrive at "
        "the TOP and the whole room is the way down. The machine in the "
        "middle hangs from the ceiling and never reaches the floor -- it is "
        "suspended, not founded, which is the single detail that stops it "
        "reading as a tower with a staircase round it. The walls do the "
        "walking: thirteen landings and twelve flights spiral down the "
        "inside face. Three collars branch off the machine as the only "
        "floors that are not the wall.",
    "route":
        "In at the top, 68 m up. Then down, and down, and down: twelve "
        "flights around the four walls, each dropping about 5.7 m, to the "
        "floor at zero. Three of the landings have a bridge out to a collar "
        "on the machine -- those are the only places you leave the wall, "
        "and they are optional detours rather than the route.",
    "offers":
        "A rail that runs the whole descent: 129.4 m of it, falling 62 m "
        "from top to bottom, which is more than twice the vertical range "
        "of any other rail in the library -- so the whole spiral has a "
        "fast alternative. A launch pair from the floor up to the middle collar, "
        "28.1 m, which is the only way back UP that does not retrace the "
        "spiral. Three grapple anchors staggered up the shaft at 20, 38 and "
        "56 m, roughly one per third.",
    "verdict":
        "Approve. This is the room that most aggressively proves the "
        "'huge vertical space' idea and I would not change anything about "
        "its shape. The one thing to be aware of: the LOWEST collar's "
        "headroom is tight -- it passed the clearance check with 3 cm to "
        "spare -- so if anything ever hangs from a ceiling in this room, "
        "check that collar first.",
    "shots": [
        {"file": "A1_plenum_helix.png", "kicker": "PLENUM / VIEW 1 OF 4",
         "title": "Arriving at the top",
         "notes": [
             ("WHERE YOU ARE", "On the entry landing, 68 m up, looking "
              "down."),
             ("WHAT YOU ARE LOOKING AT", "The full drop. The machine "
              "hanging in the middle of it, and the first of twelve flights "
              "leading away along the wall."),
             ("THE ROUTE", "Down. There is no other direction from here, "
              "and that is the room's whole proposition."),
             ("OFFERS", "The rail starts near the top of this shaft; the "
              "first grapple anchor is about a third of the way down."),
             ("MY CALL", "Approve. Compare this with the Hall's page 1: one "
              "room hands you a horizon, the other hands you a hole."),
         ]},
        {"file": "A2_plenum_helix.png", "kicker": "PLENUM / VIEW 2 OF 4",
         "title": "From the floor, all 72 metres",
         "notes": [
             ("WHERE YOU ARE", "Standing on the floor at the bottom, "
              "looking up."),
             ("WHAT YOU ARE LOOKING AT", "The whole shaft from below, and "
              "the machine hanging above you with nothing under it. This is "
              "the view that sells the suspension -- you can see daylight "
              "under a structure that is 56 m tall."),
             ("THE ROUTE", "Where the spiral ends. Also where you start if "
              "the level runs the other way."),
             ("OFFERS", "The launch pad is on this floor, aimed at the "
              "middle collar 28 m up -- the only quick way back up."),
             ("MY CALL", "Approve. If you look at one page for this room, "
              "this is it."),
         ]},
        {"file": "A3_plenum_helix.png", "kicker": "PLENUM / VIEW 3 OF 4",
         "title": "Mid shaft, on the spiral",
         "notes": [
             ("WHERE YOU ARE", "About 40 m up, standing on the helix "
              "halfway down."),
             ("WHAT YOU ARE LOOKING AT", "What the room is actually like to "
              "be in: a walkway with a wall on one side and a very long "
              "drop on the other, and the machine filling the view across "
              "the gap."),
             ("THE ROUTE", "You are six flights in with six to go."),
             ("OFFERS", "A grapple anchor sits out in the shaft at 38 m, "
              "close to here. The rail passes on the machine side."),
             ("MY CALL", "Approve, with one flag for later: this is a lot "
              "of walkway with a lot of drop beside it, and it will want a "
              "railing language when dressing arrives. That is a decoration "
              "job, not a shell change."),
         ]},
        {"file": "A4_plenum_helix.png", "kicker": "PLENUM / VIEW 4 OF 4",
         "title": "A collar -- the only floor that is not the wall",
         "notes": [
             ("WHERE YOU ARE", "Out on one of the three collars, 30 m up, "
              "having left the wall by a short bridge."),
             ("WHAT YOU ARE LOOKING AT", "A ring of floor around the "
              "hanging machine, with open shaft on both sides of you."),
             ("THE ROUTE", "A detour, not the route. You come out, you go "
              "back. That is deliberate -- it makes the collars places you "
              "choose to be rather than places you pass through."),
             ("OFFERS", "The middle collar is where the launch from the "
              "floor lands, so it is both a detour on the way down and a "
              "destination from the bottom."),
             ("MY CALL", "Approve. The collars are the best thing in this "
              "room: they are the only moment the shaft stops being a "
              "corridor."),
         ]},
    ],
}

YARD = {
    "id": "shell_yard_gantry",
    "dir": W1_DIR,
    "subtitle": "ROOM 3 OF 4 / WAVE 1 / NEVER REVIEWED",
    "title": "Yard",
    "distinct":
        "The wide one -- 84 m across and only 16 m tall, which makes it the "
        "exact opposite of the Plenum and the reason both exist. It is the "
        "one room where the main route never climbs at all: you can cross "
        "it end to end on flat ground. All the vertical interest is "
        "optional and hangs from one object, an 84 m gantry crane spanning "
        "the full width, with a catwalk ring below it on all four walls.",
    "route":
        "Straight across. In at one end, out at the other, 84 m of open "
        "floor between them and no climbing required. Two staircases in "
        "opposite corners go up to the catwalk at 8 m -- placed in corners "
        "on purpose so that going up is never the shortest way to anywhere. "
        "The catwalk is a choice, not a route.",
    "offers":
        "A rail that runs the crane itself -- level, 72 m, right across the "
        "room at 14 m. The longest launch in the library at 63.1 m, from "
        "the floor at the west end all the way to the catwalk at the east, "
        "which crosses the entire room in one shot. Three grapple anchors "
        "spaced along the crane at 10.6 m, so the crane is usable as a "
        "handhold as well as a rail.",
    "verdict":
        "Approve, but look hard at the height first. This is the flattest "
        "room in the library by a distance, and that is either exactly the "
        "contrast the set needs or one room too horizontal. I lean strongly "
        "toward keeping it -- a library where every room is tall is as "
        "monotonous as one where every room is a box -- but it is the "
        "cheapest thing to change now and the most expensive to change "
        "after Wave 2 copies the proportion.",
    "shots": [
        {"file": "B1_yard_gantry.png", "kicker": "YARD / VIEW 1 OF 4",
         "title": "Across 84 metres of floor",
         "notes": [
             ("WHERE YOU ARE", "At floor level at one end, looking the full "
              "length of the room."),
             ("WHAT YOU ARE LOOKING AT", "84 m of open floor under a "
              "16 m ceiling, with the crane spanning the width above you "
              "and the catwalk running the walls."),
             ("THE ROUTE", "Dead ahead, on the flat, all the way. This is "
              "the only room in the library where that sentence is true."),
             ("OFFERS", "The launch pad is on this floor, aimed at the far "
              "corner of the catwalk -- 63.1 m, the longest jump in the "
              "library."),
             ("MY CALL", "This is the page to judge the height question "
              "from. My read: the horizontal is doing real work and the "
              "crane gives it a ceiling you notice. Approve -- but if it "
              "reads as squat to you, say so now."),
         ]},
        {"file": "B2_yard_gantry.png", "kicker": "YARD / VIEW 2 OF 4",
         "title": "From the crane, the whole floor",
         "notes": [
             ("WHERE YOU ARE", "Up on the crane bridge at 13.5 m, near the "
              "ceiling."),
             ("WHAT YOU ARE LOOKING AT", "The whole floor at once. In a "
              "room this wide, height buys you information -- you can see "
              "where everything is from up here, which is exactly what a "
              "crane should be worth."),
             ("THE ROUTE", "Nothing about the mandatory route comes up "
              "here. Everything up here is elective."),
             ("OFFERS", "You are standing on the rail. The three grapple "
              "anchors are spaced along this same structure."),
             ("MY CALL", "Approve. The second page for the height question "
              "-- this is what the ceiling buys."),
         ]},
        {"file": "B3_yard_gantry.png", "kicker": "YARD / VIEW 3 OF 4",
         "title": "Along the catwalk at 8 metres",
         "notes": [
             ("WHERE YOU ARE", "On the catwalk that rings all four walls, "
              "8 m up."),
             ("WHAT YOU ARE LOOKING AT", "The middle height of the room, "
              "and the way it frames the floor below."),
             ("THE ROUTE", "You got here up a staircase in a corner. The "
              "catwalk is continuous around all four sides -- unlike the "
              "Hall's collar, this loop actually closes, which is what I "
              "want fixed in the Hall."),
             ("OFFERS", "The far corner of this catwalk is where the long "
              "launch lands."),
             ("MY CALL", "Approve. This is the shape the Hall's collar ring "
              "should be."),
         ]},
        {"file": "B4_yard_gantry.png", "kicker": "YARD / VIEW 4 OF 4",
         "title": "In cover, looking back",
         "notes": [
             ("WHERE YOU ARE", "Down on the floor behind cover, near one "
              "corner, looking back across the room."),
             ("WHAT YOU ARE LOOKING AT", "The room from the position a "
              "player actually takes in a fight -- low, behind something, "
              "with a long sightline."),
             ("THE ROUTE", "Off to one side of the crossing."),
             ("OFFERS", "Nothing lands here. This is the part of the room "
              "that is deliberately plain, so that the crane reads as the "
              "one special object."),
             ("MY CALL", "Approve. No enemies are placed and no encounter "
              "is authored -- what the room provides is the vocabulary: "
              "four cover positions on the floor, five raised positions on "
              "the crane and catwalk, and 84 m to retreat across."),
         ]},
    ],
}

SPAN = {
    "id": "shell_span_basin",
    "dir": W1_DIR,
    "subtitle": "ROOM 4 OF 4 / WAVE 1 / NEVER REVIEWED",
    "title": "Span",
    "distinct":
        "The long one -- a single 90 m deck on two pylons, with a fully "
        "walkable basin underneath all of it. It is the only room in the "
        "library with TWO complete routes over the same ground at two "
        "different heights, and the only one where you can commit from the "
        "upper to the lower and not get straight back. Everything about it "
        "is about that choice: the top is fast and exposed, the bottom is "
        "slow and covered.",
    "route":
        "Two of them. On the deck: in one end, out the other, 90 m straight "
        "across at 14 m. In the basin: the same 90 m on the ground, with "
        "staircases at each end connecting the two. And in the middle of "
        "the deck there is a drop -- you can step off into the basin "
        "whenever you like, but the only ways back up are at the ends.",
    "offers":
        "The rail is slung UNDER the deck, not on it -- 82.9 m through the "
        "basin, so the fast line belongs to the lower route rather than the "
        "obvious upper one. A launch pair from the basin floor back up to "
        "the deck, 22.5 m, at the midpoint, which is the answer to the "
        "one-way drop. Three grapple anchors under the deck at 11.4 m, "
        "evenly spaced along the span.",
    "verdict":
        "Approve, and confirm the drop. The shape is my favourite in Wave 1 "
        "because it is the only room whose geometry poses a question to the "
        "player rather than a task. The one thing I want on the record is "
        "the one-way drop: I think making the descent free and the ascent "
        "cost something is exactly right, but it is a design call and it "
        "should be yours, not mine.",
    "shots": [
        {"file": "C1_span_basin.png", "kicker": "SPAN / VIEW 1 OF 4",
         "title": "On the deck, 90 metres of it",
         "notes": [
             ("WHERE YOU ARE", "At one end of the deck, 14 m up, looking "
              "the full length."),
             ("WHAT YOU ARE LOOKING AT", "The upper route: one continuous "
              "deck running the whole room, on two pylons, with nothing "
              "either side of it."),
             ("THE ROUTE", "Straight across. This is the fast way and the "
              "exposed way -- there is nothing up here to hide behind."),
             ("OFFERS", "None on the deck. Everything is underneath, which "
              "is the room's central joke: the interesting route is the one "
              "you cannot see from here."),
             ("MY CALL", "Approve."),
         ]},
        {"file": "C2_span_basin.png", "kicker": "SPAN / VIEW 2 OF 4",
         "title": "From the basin, under the deck",
         "notes": [
             ("WHERE YOU ARE", "On the basin floor at ground level, under "
              "the span."),
             ("WHAT YOU ARE LOOKING AT", "The lower route, and the "
              "underside of the deck 14 m above -- which is where the rail "
              "and all three grapple anchors are."),
             ("THE ROUTE", "The same 90 m, on the ground, covered. Slower, "
              "and you cannot be seen from above."),
             ("OFFERS", "All of them are here. The rail runs the length of "
              "this space; the launch pad in the middle throws you back up "
              "to the deck."),
             ("MY CALL", "Approve. Putting the rail underneath rather than "
              "on the deck is the decision that makes the lower route worth "
              "choosing instead of just safer."),
         ]},
        {"file": "C3_span_basin.png", "kicker": "SPAN / VIEW 3 OF 4",
         "title": "Both routes at once",
         "notes": [
             ("WHERE YOU ARE", "Off to the side at 18 m, where both levels "
              "are visible together."),
             ("WHAT YOU ARE LOOKING AT", "The whole proposition in one "
              "frame: deck above, basin below, both running the full "
              "length, both complete."),
             ("THE ROUTE", "Either. And the drop in the middle of the deck "
              "that lets you change your mind once, in one direction."),
             ("OFFERS", "The launch pair is the counterweight to that drop "
              "-- it is the only quick way from the lower route back to the "
              "upper one anywhere except the two ends."),
             ("MY CALL", "Approve. This is the page that shows why the room "
              "exists."),
         ]},
        {"file": "C4_span_basin.png", "kicker": "SPAN / VIEW 4 OF 4",
         "title": "Basin floor, looking up at the span",
         "notes": [
             ("WHERE YOU ARE", "Down on the basin floor near one end, "
              "looking back up at the underside of the span."),
             ("WHAT YOU ARE LOOKING AT", "How much structure is over your "
              "head, and how far it runs. The pylons are the only things "
              "touching the ground in the whole 90 m."),
             ("THE ROUTE", "The staircase back up to the deck is at this "
              "end -- one of only two."),
             ("OFFERS", "A grapple anchor is directly overhead."),
             ("MY CALL", "Approve. This is the view that makes the one-way "
              "drop feel like a decision rather than a mistake: from down "
              "here you can see exactly how far it is to the next way up."),
         ]},
    ],
}

ROOMS = [HALL, PLENUM, YARD, SPAN]
