// The thirteen Statuses and eight compounds, drawn as 16x16 bodies.
//
// EDIT THIS FILE TO REDRAW A GLYPH. `X` is body, `.` is nothing. The dark
// outline is NOT drawn here -- `author_status_kit.mjs` derives it by dilating
// the body one pixel in eight directions, so every glyph gets exactly the
// same weight of outline and a hole inside a body (a crack, a slash) closes
// up into a dark hairline automatically. That split is deliberate: the
// silhouette is a drawing decision and belongs in a human's hands; the
// outline is mechanical and should never vary by glyph.
//
// THE RULE THE FLOOR REVISION TAUGHT, APPLIED HERE: continuous lines survive,
// short marks do not. Every body below is one connected run or a small number
// of chunky ones. Nothing is a scatter of single pixels.
//
// Bodies stay inside x1..x14, y1..y14 so the derived outline never clips.

/** Spec text is the design's, verbatim where it is player-facing. */
export const STATUSES = [
  // -- KINETIC ------------------------------------------------------------
  {
    id: "lightened", family: "KINETIC", duration: 8.0, chance: 0.40,
    targets: ["actor", "object", "player"],
    sentence: "Lighter than it should be.",
    // A small block floating clear of a long ground bar, with a wide gap.
    // Bottom-heavy and MOSTLY EMPTY -- that emptiness is the whole contrast
    // with `updraft`, which fills the same space with rising flow.
    body: [
      "................",
      "................",
      ".....XXXXXX.....",
      ".....XXXXXX.....",
      ".....XXXXXX.....",
      ".....XXXXXX.....",
      "................",
      "................",
      "................",
      "................",
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
      "................",
    ],
  },
  {
    id: "anchored", family: "KINETIC", duration: 4.0, chance: 0.30,
    targets: ["actor", "object", "player"],
    sentence: "Fixed in place.",
    // A capped stake with ONE barb driven straight down into ground. One
    // vertical member, a head on top. `rooted` has no head and splays.
    body: [
      "................",
      "...XXXXXXXXXX...",
      "...XXXXXXXXXX...",
      ".......XX.......",
      ".......XX.......",
      ".......XX.......",
      ".......XX.......",
      "....XXXXXXXX....",
      "....XXXXXXXX....",
      "......XXXX......",
      ".......XX.......",
      ".......XX.......",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
    ],
  },
  {
    id: "slippery", family: "KINETIC", duration: 10.0, chance: 0.45,
    targets: ["object", "surface", "player"],
    sentence: "Nothing holds.",
    // Three slide bars staggered rightward over a ground line. Staggered,
    // not stacked: the offset is what turns three lines into motion.
    body: [
      "................",
      "................",
      "....XXXXXXXX....",
      "....XXXXXXXX....",
      "..XXXXXXXXXX....",
      "..XXXXXXXXXX....",
      "......XXXXXXXX..",
      "......XXXXXXXX..",
      "................",
      "................",
      "................",
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
    ],
  },

  // -- COGNITIVE ----------------------------------------------------------
  {
    id: "confused", family: "COGNITIVE", duration: 5.0, chance: 0.30,
    targets: ["actor"],
    sentence: "Cannot tell friend from foe.",
    // Two crossed arrows, barbed at all four ends: every direction is a
    // target. Long continuous diagonals, which is what survives at size.
    body: [
      "................",
      ".XXXXX....XXXXX.",
      ".XXXXX....XXXXX.",
      ".XXXX......XXXX.",
      ".XX.XX....XX.XX.",
      "......XX.XX.....",
      "......XXXXX.....",
      ".......XXX......",
      ".......XXX......",
      "......XXXXX.....",
      "......XX.XX.....",
      ".XX.XX....XX.XX.",
      ".XXXX......XXXX.",
      ".XXXXX....XXXXX.",
      ".XXXXX....XXXXX.",
      "................",
    ],
  },
  {
    id: "turncoat", family: "COGNITIVE", duration: 8.0, chance: 0.15,
    targets: ["actor"],
    sentence: "Fighting for you now.",
    // A U-turn: up one side, over the top, and back down the other into an
    // arrowhead. It has changed direction and is now pointing your way.
    body: [
      "................",
      ".....XXXXXX.....",
      "...XXXXXXXXXX...",
      "..XXX......XXX..",
      "..XXX......XXX..",
      "..XXX......XXX..",
      "..XXX......XXX..",
      "..XXX......XXX..",
      "..XXX......XXX..",
      "..XXX......XXX..",
      "XXXXXXX....XXX..",
      ".XXXXX.....XXX..",
      "..XXX......XXX..",
      "...X.......XXX..",
      "...........XXX..",
      "................",
    ],
  },
  {
    id: "blinded", family: "COGNITIVE", duration: 6.0, chance: 0.35,
    targets: ["actor"],
    sentence: "Cannot see past arm's reach.",
    // A shut eye: a solid lens with nothing in it, over three lashes. Solid
    // is the point -- there is no pupil, so there is no looking.
    body: [
      "................",
      "................",
      "................",
      "................",
      ".....XXXXXX.....",
      "...XXXXXXXXXX...",
      "..XXXXXXXXXXXX..",
      ".XXXXXXXXXXXXXX.",
      "..XXXXXXXXXXXX..",
      "...XXXXXXXXXX...",
      ".....XXXXXX.....",
      "................",
      "...XX..XX..XX...",
      "...XX..XX..XX...",
      "................",
      "................",
    ],
  },
  {
    id: "exposed", family: "COGNITIVE", duration: 6.0, chance: 0.35,
    targets: ["actor"],
    sentence: "Nothing is covering it.",
    // A shield split down the middle and parted. The gap IS the glyph; it
    // is the only body in the kit with a full-height vertical void.
    body: [
      "................",
      "..XXXX....XXXX..",
      "..XXXX....XXXX..",
      "..XXXX....XXXX..",
      "..XXXX....XXXX..",
      "..XXXX....XXXX..",
      "..XXXX....XXXX..",
      "..XXXX....XXXX..",
      "..XXXX....XXXX..",
      "...XXX....XXX...",
      "...XXX....XXX...",
      "....XX....XX....",
      "....XX....XX....",
      ".....X....X.....",
      "................",
      "................",
    ],
  },

  // -- PERMISSION ---------------------------------------------------------
  {
    id: "silenced", family: "PERMISSION", duration: 6.0, chance: 0.30,
    targets: ["actor"],
    sentence: "No special moves.",
    // The spark of a special move, cut clean through by a diagonal channel.
    // The channel is drawn as ABSENCE: the outline pass closes it into a
    // dark bar, which is why it reads as struck through rather than shaded.
    body: [
      "................",
      "................",
      ".......XX.......",
      "....X..XX.......",
      "...XX..XX...X...",
      "....XX.XX.XX....",
      ".....XXXXX......",
      "..XXXXXX.XXXXX..",
      "..XXXXX.XXXXXX..",
      "......XXXXX.....",
      "....XX.XX.XX....",
      "...X...XX..XX...",
      ".......XX..X....",
      ".......XX.......",
      "................",
      "................",
    ],
  },
  {
    id: "rooted", family: "PERMISSION", duration: 5.0, chance: 0.35,
    targets: ["actor"],
    sentence: "Cannot walk.",
    // A stem with THREE roots splaying below a ground line, and no head.
    // Against `anchored`: branching versus a single spike, and the splay is
    // why this one can still be dragged.
    body: [
      "................",
      ".......XX.......",
      ".......XX.......",
      ".......XX.......",
      ".......XX.......",
      ".......XX.......",
      ".......XX.......",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "...XX..XX..XX...",
      "...XX..XX..XX...",
      "..XX...XX...XX..",
      "..XX...XX...XX..",
      "................",
      "................",
      "................",
    ],
  },
  {
    id: "phased", family: "PERMISSION", duration: 6.0, chance: 0.25,
    targets: ["actor", "object", "surface", "player"],
    sentence: "Passes through.",
    // A box that is solid on one side and hollow on the other, with a bar
    // running clean through it and out both edges. Against `suspended`:
    // this one is PENETRATED, that one is held clear with a gap all round.
    body: [
      "................",
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXX....XX..",
      "..XXXXXX....XX..",
      "..XXXXXX....XX..",
      "XXXXXXXXXXXXXXXX",
      "XXXXXXXXXXXXXXXX",
      "..XXXXXX....XX..",
      "..XXXXXX....XX..",
      "..XXXXXX....XX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
    ],
  },

  // -- MATERIAL -----------------------------------------------------------
  {
    id: "burning", family: "MATERIAL", duration: 6.0, chance: 0.35,
    targets: ["actor", "object", "surface", "volume", "player"],
    sentence: "On fire, and setting fire.",
    requires_trait: "burnable",
    body: [
      "................",
      "........XX......",
      ".......XXX......",
      "......XXXX......",
      ".....XXXXX......",
      ".....XXXXXX.....",
      "....XXXXXXXX....",
      "...XXXXXXXXXX...",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "...XXXXXXXXXX...",
      "....XXXXXXXX....",
      ".....XXXXXX.....",
      "................",
      "................",
    ],
  },
  {
    id: "conductive", family: "MATERIAL", duration: 10.0, chance: 0.40,
    targets: ["actor", "object", "surface", "player"],
    sentence: "Carries a current.",
    requires_trait: "conductive_material",
    // A bolt running DOWN between two terminal pads. Against `grounded`:
    // that one is a symmetric ladder descending to earth; this one is a
    // diagonal with a jog, and it goes pad to pad, not into the ground.
    body: [
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "........XXXX....",
      ".......XXXX.....",
      "......XXXX......",
      ".....XXXX.......",
      "....XXXXXXXX....",
      ".......XXXX.....",
      "......XXXX......",
      ".....XXXX.......",
      "....XXXX........",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
    ],
  },
  {
    id: "brittle", family: "MATERIAL", duration: 8.0, chance: 0.35,
    targets: ["object", "surface"],
    sentence: "About to give.",
    // A plate with ONE wandering crack from edge to edge, and a short
    // branch. The crack is absence; the outline pass darkens it. Against
    // `shatterpoint`: no focus, no radiating star -- just a fault line.
    body: [
      "................",
      "................",
      "..XXXXX..XXXXX..",
      "..XXXXX..XXXXX..",
      "..XXXX..XXXXXX..",
      "..XXX..XXXXXXX..",
      "..XXX..XXX..XX..",
      "..XXXX..X...XX..",
      "..XXXXX....XXX..",
      "..XXXXX..XXXXX..",
      "..XXXX..XXXXXX..",
      "..XXX..XXXXXXX..",
      "..XXX..XXXXXXX..",
      "..XXXX..XXXXXX..",
      "................",
      "................",
    ],
  },
];

export const COMPOUNDS = [
  {
    id: "updraft", components: ["lightened", "burning"], duration: 5.0,
    targets: ["actor", "object"], sentence: "Rising on its own heat.",
    // The slab is pushed to the TOP edge and three tapering streams fill
    // everything under it. `lightened` is the same slab over emptiness.
    body: [
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "...XX..XX..XX...",
      "...XX..XX..XX...",
      "...XX..XX..XX...",
      "..XXX..XXX.XXX..",
      "..XXX..XXX.XXX..",
      "..XXX..XXX.XXX..",
      ".XXXX.XXXX.XXXX.",
      ".XXXX.XXXX.XXXX.",
      ".XXXX.XXXX.XXXX.",
      "................",
      "................",
      "................",
    ],
  },
  {
    id: "grounded", components: ["anchored", "conductive"], duration: 8.0,
    targets: ["actor", "object", "surface"], sentence:
      "Earthed. Current flows through it and past it.",
    // The earth symbol: a stem into three bars of decreasing width. Nothing
    // else in the kit is a symmetric descending ladder.
    body: [
      "................",
      ".......XX.......",
      ".......XX.......",
      ".......XX.......",
      ".......XX.......",
      ".......XX.......",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "....XXXXXXXX....",
      "....XXXXXXXX....",
      "................",
      "......XXXX......",
      "......XXXX......",
      "................",
      "................",
    ],
  },
  {
    id: "spreading", components: ["slippery", "burning"], duration: 8.0,
    targets: ["surface", "object"], sentence: "The fire is travelling.",
    // Three flames growing left to right along a floor: the fire is going
    // somewhere. `burning` is one flame and stays put.
    body: [
      "................",
      "...........X....",
      "..........XX....",
      ".......X..XXX...",
      "......XX.XXXX...",
      "..X...XX.XXXX...",
      "..XX.XXX.XXXXX..",
      ".XXX.XXXX.XXXX..",
      ".XXX.XXXX.XXXX..",
      "..XX..XXX.XXXX..",
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
      "................",
    ],
  },
  {
    id: "arc_path", components: ["slippery", "conductive"], duration: 10.0,
    targets: ["surface"], sentence: "A current runs along it.",
    // The bolt lies DOWN and travels the length of a surface, terminal to
    // terminal. `conductive` stands the same bolt up between two pads.
    body: [
      "................",
      "................",
      "..XX........XX..",
      "..XX........XX..",
      "..XXX..XX..XXX..",
      "...XX.XXXX.XX...",
      "....XXX..XXX....",
      ".....XX..XX.....",
      "................",
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
      "................",
      "................",
    ],
  },
  {
    id: "suspended", components: ["anchored", "phased"], duration: 6.0,
    targets: ["actor", "object"], sentence: "Held out of the world.",
    // Four corner brackets holding a block that touches NONE of them. The
    // clearance is the glyph. `phased` has a bar driven straight through.
    body: [
      "................",
      "..XXXX....XXXX..",
      "..XXXX....XXXX..",
      "..XX........XX..",
      "..XX........XX..",
      "................",
      ".....XXXXXX.....",
      ".....XXXXXX.....",
      ".....XXXXXX.....",
      ".....XXXXXX.....",
      "................",
      "..XX........XX..",
      "..XX........XX..",
      "..XXXX....XXXX..",
      "..XXXX....XXXX..",
      "................",
    ],
  },
  {
    id: "shatterpoint", components: ["anchored", "brittle"], duration: 6.0,
    targets: ["object", "surface"], sentence: "One good hit.",
    // The same plate `brittle` cracks, but punched: a hole at one named
    // point and three straight fractures running from it to the edges. The
    // first version was a radiating star and it read as `silenced`'s spark.
    // A plate with a hole in it cannot be mistaken for a spark.
    body: [
      "................",
      "................",
      "..XXXXX.XXXXXX..",
      "..XXXXX.XXXXXX..",
      "..XXXXX.XXXXXX..",
      "..XXXX....XXXX..",
      "..XXX......XXX..",
      "..XX........XX..",
      "..XXX......XXX..",
      "..XXXX....XXXX..",
      "..XXXXX..XXXXX..",
      "..XXXX....XXXX..",
      "..XXX......XXX..",
      "..XX.XXXXX..XX..",
      "................",
      "................",
    ],
  },
  {
    id: "helpless", components: ["confused", "silenced"], duration: 7.0,
    targets: ["actor"], sentence: "Lost, and out of tricks.",
    // A lid, and under it something collapsing. Nothing points anywhere.
    body: [
      "................",
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
      "..XX........XX..",
      "..XXX......XXX..",
      "...XXX....XXX...",
      "....XXX..XXX....",
      ".....XXXXXX.....",
      "......XXXX......",
      "................",
      "................",
      "................",
      "................",
    ],
  },
  {
    id: "floundering", components: ["blinded", "slippery"], duration: 6.0,
    targets: ["actor"], sentence: "Blind and sliding.",
    // Its two parents' own marks, disagreeing. `blinded`'s shut eye on top;
    // under it `slippery`'s slide bars, but each one pointing the other way
    // and none of them lined up. The first version tried to draw a wandering
    // S-curve and at 16 px it collapsed into a chevron.
    body: [
      "................",
      ".....XXXXXX.....",
      "...XXXXXXXXXX...",
      "..XXXXXXXXXXXX..",
      "...XXXXXXXXXX...",
      ".....XXXXXX.....",
      "................",
      "..XXXXX.........",
      "..XXXXX.........",
      "................",
      ".......XXXXXXX..",
      ".......XXXXXXX..",
      "................",
      "....XXXXXX......",
      "....XXXXXX......",
      "................",
    ],
  },
];
