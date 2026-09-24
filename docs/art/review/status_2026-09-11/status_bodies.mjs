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
    runtime_targets: ["object"],
    runtime_targets_source: "runtime -- verified against ECHO_STATUS_SUPPORTED_TARGETS",
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
    runtime_targets: ["enemy"],
    runtime_targets_source:
      "runtime -- ECHO_STATUS_SUPPORTED_TARGETS at a745637, which IMPLEMENTED it after this glyph was authored",
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
    runtime_targets: [],
    runtime_targets_source: "none -- apply() refuses it: NO STATUS BEFORE ITS EFFECT",
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
    runtime_targets: [],
    runtime_targets_source: "none -- apply() refuses it: NO STATUS BEFORE ITS EFFECT",
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
    runtime_targets: [],
    runtime_targets_source: "none -- apply() refuses it: NO STATUS BEFORE ITS EFFECT",
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
    runtime_targets: [],
    runtime_targets_source: "none -- apply() refuses it: NO STATUS BEFORE ITS EFFECT",
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
    runtime_targets: [],
    runtime_targets_source: "none -- apply() refuses it: NO STATUS BEFORE ITS EFFECT",
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
    runtime_targets: [],
    runtime_targets_source: "none -- apply() refuses it: NO STATUS BEFORE ITS EFFECT",
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
    runtime_targets: ["enemy"],
    runtime_targets_source:
      "runtime -- ECHO_STATUS_SUPPORTED_TARGETS at a745637, which IMPLEMENTED it after this glyph was authored",
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
    runtime_targets: [],
    runtime_targets_source: "none -- apply() refuses it: NO STATUS BEFORE ITS EFFECT",
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
    runtime_targets: ["self", "enemy"],
    runtime_targets_source: "runtime -- verified against ECHO_STATUS_SUPPORTED_TARGETS",
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
    runtime_targets: [],
    runtime_targets_source: "none -- apply() refuses it: NO STATUS BEFORE ITS EFFECT",
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
    runtime_targets: [],
    runtime_targets_source: "none -- apply() refuses it: NO STATUS BEFORE ITS EFFECT",
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
  // -- THE ELEVEN THE RUNTIME CAN ALREADY RAISE -------------------------
  //
  // Everything above is Design 6 §15.2's thirteen. These eleven are
  // ECHOES §8's, and the difference matters: §15.2's thirteen are the
  // DESTINATION, and `Constants.ECHO_STATUS_KINDS_IMPLEMENTED` says the
  // runtime implements exactly two of them. These eleven are the rest of
  // what it implements -- statuses the game can put on a target today,
  // which until this batch had nothing on screen to say so.
  //
  // ECHOES §8 names them and stops there: no family, no target list, no
  // duration, no sentence. So three fields below are NOT quoted from a
  // design and each one says where it came from:
  //
  //   family          Art's proposal, argued per glyph from what the
  //                   runtime measurably DOES. No fifth family is
  //                   invented -- §15.2 settled the count at four.
  //   targets         the runtime's own `ECHO_STATUS_SUPPORTED_TARGETS`,
  //                   translated into §15.2's words. The design is silent;
  //                   inventing a wider list would have been Art writing
  //                   design.
  //   sentence        Art's, in §15.2's voice. Marked `sentence_source`.
  //
  // `duration: 5.0` throughout is the figure Production's own drivers
  // apply (`lab_driver.gd`, `stats_driver.gd`), not a tuned design value,
  // and `chance` is omitted because nothing publishes one.

  // -- KINETIC ------------------------------------------------------------
  {
    id: "slowed", family: "KINETIC", duration: 5.0,
    targets: ["actor", "player"],
    runtime_targets: ["self", "enemy"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Losing way.",
    // KINETIC because the runtime puts it on `ground_friction`, the same
    // channel as `slippery` and with the same sign convention -- see
    // `stat_stack.gd::_status_factor`.
    //
    // Three motion lines SHORTENING into a stop post, over the ground
    // bar. Deliberately the inverse of `slippery`, whose three lines
    // stagger FORWARD and hit nothing: same family, same furniture,
    // opposite reading.
    body: [
      "................",
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "...........XXX..",
      "....XXXXXXXXXX..",
      "....XXXXXXXXXX..",
      "...........XXX..",
      "......XXXXXXXX..",
      "......XXXXXXXX..",
      "...........XXX..",
      "...........XXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
    ],
  },
  {
    id: "frozen", family: "KINETIC", duration: 5.0,
    targets: ["actor", "player"],
    runtime_targets: ["self", "enemy"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Sealed where it stands.",
    // KINETIC, and it is the SAME channel as `slowed` at a larger
    // coefficient -- 0.6 against 0.4 on `ground_friction`. Splitting a
    // severity ladder across two families would hide that they are one
    // thing. (Its enemy-side attack lock is a consequence of being
    // frozen solid, not a second mechanic; `enemy.gd` reads it beside
    // `stunned`, which is the PERMISSION glyph for exactly that denial.)
    //
    // A crystal with a body sealed inside it, on the ground bar. Against
    // `anchored` (a driven stake) and `rooted` (a post with splayed
    // roots): those two hold something DOWN from outside. This encloses.
    body: [
      "................",
      "......XXXX......",
      ".....XXXXXX.....",
      "....XXXXXXXX....",
      "...XXX....XXX...",
      "..XXX.XXXX.XXX..",
      "..XXX.XXXX.XXX..",
      "..XXX.XXXX.XXX..",
      "...XXX....XXX...",
      "....XXXXXXXX....",
      ".....XXXXXX.....",
      "......XXXX......",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
    ],
  },
  {
    id: "haste", family: "KINETIC", duration: 5.0,
    targets: ["player"],
    runtime_targets: ["self"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Faster than it was.",
    // KINETIC: the one status the runtime puts on `move_speed` itself.
    //
    // A solid wedge driving right with two trailing bars, over the
    // ground bar. It is a WEDGE and not an arrow on a shaft, so that
    // `empowered`'s double chevron cannot be mistaken for it with the
    // family frame stripped off (§33.10 rule 2 shows glyphs bare).
    body: [
      "................",
      "................",
      "................",
      ".......XX.......",
      "..XXX..XXX......",
      ".......XXXXX....",
      ".......XXXXXXX..",
      ".......XXXXXXX..",
      ".......XXXXX....",
      "..XXX..XXX......",
      ".......XX.......",
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
    ],
  },

  // -- COGNITIVE ----------------------------------------------------------
  {
    id: "marked", family: "COGNITIVE", duration: 5.0,
    targets: ["actor"],
    runtime_targets: ["enemy"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Chosen, and it knows.",
    // COGNITIVE: §15.2's own definition is the family of Statuses that
    // change how a target RELATES to the fight, and a designation is
    // exactly that. It is also the one status the runtime already draws
    // -- `enemy.gd::_refresh_damage_tint` reads `marked` beside the hurt
    // fraction -- so this glyph joins an existing signal rather than
    // starting one.
    //
    // A pointer driven down at a body, clear of it. Against
    // `low_profile`, which also puts something above a body: that one is
    // a shelter the body is INSIDE, this one is aimed at it from above.
    body: [
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "...XXXXXXXXXX...",
      "....XXXXXXXX....",
      ".....XXXXXX.....",
      "......XXXX......",
      ".......XX.......",
      "................",
      "................",
      "....XXXXXXXX....",
      "....XXXXXXXX....",
      "....XXXXXXXX....",
      "....XXXXXXXX....",
      "................",
      "................",
    ],
  },
  {
    id: "vulnerable", family: "COGNITIVE", duration: 5.0,
    targets: ["actor", "player"],
    runtime_targets: ["self", "enemy"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Everything lands harder.",
    // COGNITIVE, on the same axis §15.2 chose for `exposed` -- the guard
    // is down. THEY ARE NOT THE SAME STATUS AND THE KIT MUST NOT LET
    // THEM LOOK LIKE IT: `exposed` sets the Defense stat to 0.0 and is
    // actor-only (§15.3 rule 3, the union's single named exception);
    // `vulnerable` multiplies damage taken by 1.5 and applies to both
    // sides. See DECISIONS_FOR_OWNER item 6.
    //
    // A shield still standing, notched, with a spike entering the notch.
    // `exposed` is two parted halves and no shield at all.
    body: [
      "................",
      ".......XX.......",
      ".......XX.......",
      "......XXXX......",
      "......XXXX......",
      "................",
      "..XXXX....XXXX..",
      "..XXXXX..XXXXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "...XXXXXXXXXX...",
      "....XXXXXXXX....",
      "......XXXX......",
      "................",
      "................",
    ],
  },
  {
    id: "empowered", family: "COGNITIVE", duration: 5.0,
    targets: ["actor", "player"],
    runtime_targets: ["self", "enemy"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Hitting harder than it should.",
    // THE WEAKEST OF THE ELEVEN FAMILY ASSIGNMENTS, and it is named as
    // such rather than argued into looking solid. `damage_dealt` x1.5 is
    // not kinetic, not permission, and not a material property.
    // COGNITIVE takes it on §15.2's "what it can do" clause. If the
    // owner reads it otherwise, the frame changes and the drawing does
    // not. DECISIONS_FOR_OWNER item 7.
    //
    // A double chevron over a base plate -- the universal "raised",
    // chosen over an arrow precisely because `haste` is a wedge.
    body: [
      "................",
      ".......XX.......",
      "......XXXX......",
      ".....XXXXXX.....",
      "....XXX..XXX....",
      "...XXX....XXX...",
      "................",
      ".......XX.......",
      "......XXXX......",
      ".....XXXXXX.....",
      "....XXX..XXX....",
      "...XXX....XXX...",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
    ],
  },
  {
    id: "low_profile", family: "COGNITIVE", duration: 5.0,
    targets: ["player"],
    runtime_targets: ["self"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Harder to notice.",
    // COGNITIVE, and it is literally about perception: `enemy.gd` halves
    // its own aggro radius by the player's `low_profile` magnitude. It is
    // `marked`'s exact inverse and the two glyphs are built to say so --
    // one aims at a body from above, the other buries it.
    //
    // A slab wider than the thing under it, and a gap. Nothing is
    // enclosed and nothing is being crushed: there is simply something
    // over it, and it is small.
    //
    // REDRAWN, for the same gate that redrew `shocked`, and this one is
    // the more interesting case because it was never REFUSED. The first
    // version was a deep open-bottomed shelter -- correct art, 0.364
    // from its nearest neighbour, comfortably past the 0.25 floor. But
    // it was a tall rectangle with interior structure, and so are
    // `brittle`, `phased`, `shatterpoint` and `updraft`: it sat in the
    // kit's top twenty closest pairs FIVE times over. No single pair was
    // wrong; the shape was just crowded. The measurement is what showed
    // that, and the redraw took its nearest neighbour to 0.608 -- from
    // the busiest part of the kit to the emptiest.
    body: [
      "................",
      ".XXXXXXXXXXXXXX.",
      ".XXXXXXXXXXXXXX.",
      ".XXXXXXXXXXXXXX.",
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
      "................",
    ],
  },

  // -- PERMISSION ---------------------------------------------------------
  {
    id: "stunned", family: "PERMISSION", duration: 5.0,
    targets: ["actor"],
    runtime_targets: ["enemy"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Switched off, briefly.",
    // PERMISSION, and it is the family's widest denial: `enemy.gd` reads
    // it in the same two guards that stop an attack AND stop a move, so
    // it denies at once what `silenced` and `rooted` each deny alone.
    //
    // A spiral, inward. Nothing else in the kit is a spiral, and the
    // three PERMISSION glyphs it has to separate from are a crossed-out
    // burst, a splayed post and a pierced block.
    body: [
      "................",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "..XX........XX..",
      "..XX..XXXX..XX..",
      "..XX..XXXX..XX..",
      "..XX..XX....XX..",
      "..XX..XX....XX..",
      "..XX..XXXXXXXX..",
      "..XX..XXXXXXXX..",
      "..XX............",
      "..XX............",
      "..XX............",
      "..XX............",
      "................",
      "................",
    ],
  },

  // -- MATERIAL -----------------------------------------------------------
  {
    id: "shocked", family: "MATERIAL", duration: 5.0,
    targets: ["actor", "player"],
    runtime_targets: ["self", "enemy"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Current still in it.",
    // MATERIAL, and it is `conductive`'s other half: that one is a rail
    // that CARRIES current, this is a body that TOOK it. They share the
    // bolt on purpose, inverted -- conductive hangs it below a rail,
    // this one stands it on top of a mass -- because the pair is the
    // point and up/down is never ambiguous on a HUD.
    //
    // REDRAWN, and the gate below is why. The first version cut the bolt
    // as a VOID through a solid block, which is a handsome drawing and
    // is also, measurably, `brittle`: 0.295 apart, the closest pair in
    // the whole kit, against a floor of 0.25. Both would have been "a
    // block with a jagged fault in it" on a 32 px marker, and both are
    // MATERIAL, so the frame could not have told them apart either. The
    // discharge moved outside the body and the pair went to 0.51.
    body: [
      "................",
      "........XXX.....",
      ".......XXX......",
      "......XXX.......",
      "....XXXXXXX.....",
      "......XXX.......",
      ".....XXX........",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "................",
      "................",
      "................",
      "................",
    ],
  },
  {
    id: "poisoned", family: "MATERIAL", duration: 5.0,
    targets: ["actor", "player"],
    runtime_targets: ["self", "enemy"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Eating away at it.",
    // MATERIAL because the runtime itself pairs it with `burning`:
    // `dot_per_second()` is 4.0 x burning + 2.0 x poisoned and nothing
    // else is in that sum.
    //
    // A drop falling on a bar the drops have already eaten through.
    // Against `burning`: a flame is wide at the base and tapers UPWARD;
    // this tapers DOWNWARD. Same MATERIAL frame, opposite silhouette.
    body: [
      "................",
      "....XXXXXXXX....",
      "...XXXXXXXXXX...",
      "...XXXXXXXXXX...",
      "....XXXXXXXX....",
      ".....XXXXXX.....",
      "......XXXX......",
      "................",
      "..XXX.XXXX.XXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "..XXXX..XXXXXX..",
      "................",
      "................",
      "................",
      "................",
    ],
  },
  {
    id: "regenerating", family: "MATERIAL", duration: 5.0,
    targets: ["player"],
    runtime_targets: ["self"],
    targets_source: "runtime -- ECHOES §8 names no targets",
    sentence_source: "Art's, in §15.2's voice",
    sentence: "Coming back.",
    // MATERIAL: the two damage-over-time statuses are MATERIAL, and this
    // is `regen_per_second()` -- the same channel, the other sign.
    //
    // A cross, and nothing else in the kit is one. The period argument
    // is on its side too: a 1998 shooter's health pickup is a cross.
    body: [
      "................",
      "................",
      ".....XXXXXX.....",
      ".....XXXXXX.....",
      ".....XXXXXX.....",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      "..XXXXXXXXXXXX..",
      ".....XXXXXX.....",
      ".....XXXXXX.....",
      ".....XXXXXX.....",
      "................",
      "................",
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
