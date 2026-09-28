# MENU-INT delivery: Arty's approved menu, in the game

**Prod, engine lane, 2026-09-28.**
- **Code revision:** `ce6ea3bd` on `wip/0.4-menu-integration` (draft PR #14).
- **Full frontier:** CK11 on that revision, running at the time of this commit (steps 1–18 of 92 green, none red); its result replaces this line.
- **Not merged:** CK10 (`867f742`) remains the accepted checkpoint until
  you review this.

The menu is now the box from Arty's tour, built as a real 3D device and
working on the game's own data:
- the enclosure, the harness round all four walls, and the corner posts;
- the cables that run round the corners;
- the rack whose modules slide out.

It is not a set of flat panels, and the game's renderer is unchanged.
This report covers what works, what is limited, and what to try.

**The delivery:**
- **The build:** `archipepsi-0.4-MENU-INT-ce6ea3b.zip`. How to run it, how
  to update, and how your saves are kept safe are in
  `MENU-INT_BUILD_NOTE.txt` inside it, and briefly under **How to get it**
  below.
- **The tour:** `tour.mp4`, 50 seconds, on your candidate campaign's own
  data (details under **The tour** below).
- **This report,** with pictures, in one archive.

---

## How to get it

- **A fresh folder (safest):** unpack the zip into a new folder. That copy
  keeps its own saves inside it, so it cannot touch your clone's
  campaigns.
  1. Run "Diagnostic Campaign - Candidate (Windows).bat" and leave its
     window open.
  2. Open `godot\project.godot` with Godot 4.5.1 and run it.
  - The first open imports the menu's font and icons, which takes a few
    seconds.
- **Your own clone:**
  1. Run `git fetch origin`, then `git switch wip/0.4-menu-integration`.
  2. "Update Archipepsi (Windows).bat" then follows that branch.
  - To go back: `git switch claude/archipepsi-0-4-blindside`.
  - Nothing migrates or rewrites a save. The menu reads your campaign as
    it is. An equip, a setting or an Abandon goes through the same
    requests as before.

## The tour

- **Recording:** the game itself recorded it, with Godot's Movie Maker, at
  a fixed 30 fps. Every turn and slide plays at a player's speed. Every
  move in it is a key press.
- **The data:** your candidate campaign, played again by the bridge's own
  engine into its seventh Zone, with 60 items and the Bomb Bag on its
  key.
  - There it makes a first walk a player can make: six rooms, taking the
    keys, lowering the span in Arena 1 and opening the blue door in Arena
    2.
  - It claims two Checks in rooms it walked.
- **What it shows:**
  - Settings;
  - a page turn;
  - Equipment's keys, with modules pulled out of the rack one after
    another;
  - the Bomb Bag's history;
  - the ALWAYS ON rack scrolling;
  - a page turn round the corner post to the Map, and the lens turning;
  - the Journal, whose wire runs round the corner into the Map;
  - an entry shown on the Map, then back to your view.
- **Revision:** it was recorded on `c3bc1039`. The commits after that
  change no game code and no pixels. Renders were checked identical.

## What works

**The box.**
- **Opening it:**
  - Escape, or Start on a pad, opens it on Settings.
  - Tab, or Select, opens it on Equipment.
- **Turning it:** Q and E turn it round its corner posts, or the arrows at
  its edges.
- **Backing out:** Escape, or B, backs out of whatever is open (a detail,
  a rack, a search, a followed entry), then closes. Start closes at once.
- **Input during a turn:** a direction pressed mid-turn arrives on the wall
  you are turning to. A confirming press or a click made during the turn
  is dropped, never replayed on the next wall.
- **Clicks:** the mouse picks by what is drawn under the pointer, raised
  parts included. The suites aim every click where the part is drawn and
  check that it lands there.

**Settings and Pause** are the PAUSED board and the OPTIONS board.
- **The actions are real:**
  - in a Zone: RESUME, RETURN TO HUB, ABANDON ZONE and QUIT GAME;
  - in the Hub: only RESUME and QUIT GAME.
- **ABANDON ZONE arms first.** It shows the game's own warning, puts the
  focus on CANCEL, and asks for a fresh press on CONFIRM ABANDON. A held
  key or a double click cannot confirm it.
- **Sliders:** holding Left or Right steps once, then faster the longer you
  hold. Separate presses stay one step each.
- **MOTION** applies at once, including to a turn already in flight.

**Equipment** is the cabinet: the key selector, the inspection window, the
rack, and the FIND and SORT strip.
- **An equip is a request.** A key's window keeps showing what the bridge
  last confirmed, next to the request's state: SENT, then accepted,
  refused, not sent or lost.
  - Accepted changes the key only when the bridge's answer arrives.
  - A refusal says why.
  - With the bridge down, a notice says OFFLINE, and the keys still show
    their last confirmed state.
- **The consumable key** reads its state in its own sentence and colour,
  in all six states:
  - none owned;
  - owned but not on the key;
  - ready, with its count;
  - a use waiting for the bridge's answer;
  - empty (0 / 3);
  - offline, with no link to authorise a use.
- **ALWAYS ON** is a sixth position on the knob, for browsing what needs no
  key. It is not a key, a binding, a slot or Gear.
- **Kept from the old wall:**
  - FIND with `/`;
  - SORT with S (as found, newest, name, game);
  - NEW stickers until an item is read;
  - H for an item's whole HISTORY;
  - Delete to clear a key;
  - undo, which sends another request.
- **Readable text:** raw field names are gone at their source. For
  example, "+40 max_value" now reads "+40 maximum" (N-21, in the bridge's
  fold). A cost names its resource, not its id.

**The Map** is the lens: a live miniature of the Zone behind a riveted
port.
- **Moving the lens:**
  - `]` and `[` step through the places you have found, and a click picks
    one;
  - ENTER opens a place's detail;
  - the arrows turn and tilt, `+` and `-` zoom, and C (or Home) goes to the
    overview.
- **Floors:** PgUp and PgDn step floors. Your floor shows at full tone,
  then one floor with the rest dimmed, then that floor alone.
- **YOU** stands where you are standing.
- **Nothing hidden is shown:** a room you have not found is never drawn or
  named. A way on into one says "a way on, not yet walked".
- **Ways back:** a return device reads as a way out only in the room it
  stands in ("a way back to Corridor 1"). Where it lands, the place's
  detail says "the way back from Platform Path 4 lands here". It is not
  counted as an exit there, and it has no tag on the glass.

**The Journal**
- **Two columns of real entries:**
  - what is still shut, and why;
  - what you did here;
  - the places found.
- **The wire:** each entry that has a place on the Map runs an ivory wire
  round the corner post into the map window, to that place.
- **Following an entry:** ENTER shows it on the Map, framed.
  - Escape, or Backspace, is BACK TO YOUR VIEW, and the view comes back
    exactly as you left it.
  - The glass always says what the next back press will do.
- **A passage that vanishes:** if a passage a Journal entry points to is
  gone, the entry says so and loses its wire.

**Around the box**
- **Epsilon** is in the machine once, embedded in the enclosure, as
  presentation only. It is not a control, a slot, a meter or a light, and
  nothing clicks on it.
  - This pass implements no new lore. That is not a statement that
    Epsilon has no connection to the suit.
- **Cues:** every sound the menu makes comes from the game's one cue bank.

## What is limited

- **Brief hitches at two moments.** Measured in this container on your
  campaign's data:
  - opening the box takes about 55–65 ms of work;
  - a bridge update that arrives while the box is open takes about
    55–85 ms, because the box redraws what it shows (about 15 ms while it
    is closed).

  Each is a hitch of a few frames at that moment. The open box adds
  nothing measurable to an ordinary frame, and a turn's slowest frame was
  9 ms. Rebuilding only the wall you are looking at would cut the second
  hitch. I have not done that, because it is a change to test in its own
  right. It is yours to ask for once you have felt it on your machine.
- **The world keeps rendering behind the box.**
  - The box adds 120–323 draw calls, depending on the wall.
  - The Zone behind it keeps rendering: 2,549 draw calls in the tour's
    Zone.
  - So an open menu costs about 5–13% more to draw than play does. It is
    not slower than play itself.
- **The Map wall's lighting has a residual.** Arty's captures were made
  with Godot's simpler "Compatibility" renderer, and the game uses
  Forward+. I did not switch the game's renderer. The box adds:
  - a soft straight-on fill on the Map and Journal walls;
  - 20% more light on pale surfaces;
  - calibrated room tones.

  Measured wall by wall against the prototype's own renders, whole walls
  now match within about 5%. The Map wall's harness band and window frame
  are still somewhat darker (about 1.3 to 1.5 times, in linear light).
  The calibration was done on a software renderer; on your GPU it should
  look the same, but nobody has looked.
- **Text contrast** was measured on the renders.
  - **Medians:**

    | Wall | Median contrast |
    |---|---|
    | Settings | 11:1 |
    | Map | 9 to 12:1 |
    | Equipment | 6.4 to 7.5:1 |
    | Journal | 4.6 to 4.9:1 |

  - **Low spots:**
    - The faintest words are Equipment's small silkscreen labels, at
      3.3:1.
    - The Journal's grey entries go down to 3.8:1. About a third of the
      Journal's words sit between 3.8 and 4.5:1, which is the approved
      grey-on-graphite look.
    - On the Map at 720p, "YOU" over a picked room's pale floor measures
      2.0:1, though it is drawn with a dark outline the measure does not
      credit. At 1080p it measures 4.3:1.
  - **Your decision:** brighter Journal ink would be a change to the
    approved look, so it is for you to decide.
- **A 4-floor Zone's overview is small** in the window. Showing one floor
  alone does not reframe the view to that floor.
- **Favourites** (F, and the WHEEL toggle) are keyboard and mouse only. No
  pad button is assigned to them.
- **Refusal messages quote bridge ids** (for example an item id), shown
  with underscores as spaces. The words come from the bridge's refusal
  text.
- **The HUD's Echo feed** outside the menu still shows raw ids, such as
  "Upgrades res_magic (+40 max_value)". It is not part of the menu, so I
  left it.
- **"What you did here" is listed by kind** (keys, locks, controls), not in
  the order you did it. The save keeps what was done, not when.
- **Known in the game, unchanged from CK10:**
  - later candidate Zones can fail placement (HB-F4g);
  - zone_012 `c001`'s rail note sits in the powered door's alcove
    (HB-F4f);
  - flyers' circling varies with the machine (CK9-F2).

## What to try

1. **Page turns.** Press Escape, then Q and E round all four walls. Try a
   direction or a click in the middle of a turn.
2. **Equip with and without the bridge.** On Equipment, equip something
   while the bridge is running. Watch the key's window keep its old item
   next to SENT until the answer lands. Then close the bridge window and
   try again: OFFLINE.
3. **The Bomb Bag.** Put it on the consumable key, throw it in a Zone,
   and reopen Equipment. The key's sentence follows it: ready with its
   count, a use waiting, then empty at 0 / 3. The next Zone refills it.
4. **Search and history.** Press `/` and type part of a name. Press S to
   sort. Press H on an item for its history. Press Escape to back out one
   step at a time.
5. **Settings.** Hold Left on MOUSE SENSITIVITY. Turn MOTION all the way
   down and turn the box. Arm ABANDON ZONE, then CANCEL.
6. **The Map.** Step places with `]`, open one with ENTER, turn it with the
   arrows, and step floors with PgUp.
7. **The Journal.** Move down the entries and watch the wire follow. Press
   ENTER on one, then Escape to come back to your view.
8. **A pad,** if you have one. Start closes at once, B backs out, and the
   sticks and d-pad move everything. This is simulated in the suites and
   untested on a real controller.
9. **Feel.** Notice the moment the box opens, and an equip's answer
   arriving while it is open. Tell me if the hitches above are noticeable
   on your machine.

## Choices I made without asking

These are routine calls inside the brief. Say if you want any of them
changed.

- **Equipment layout:**
  - FIND and SORT sit on a strip under the bus;
  - NEW is a yellow sticker, and a key holding something new has its name
    in the same yellow;
  - HISTORY replaces the reading in the same window;
  - the OFFLINE and unattributed-refusal notices hang as a warm tag from
    the harness above the cabinet.
- **A long reading keeps the key's decision on screen.** On real items a
  reading can overrun its window. USE and COST then move into the right
  column's free space before anything is cut, and HISTORY always has them
  whole.
- **ABANDON ZONE arms on the board itself** (warning, CANCEL, CONFIRM
  ABANDON), with a 0.35-second guard before a confirm counts.
- **No keyboard "close at once".** Escape backs out and then closes.
  Start does the pad's direct close.
- **Map keys and marks:**
  - C (or Home) is the overview;
  - `[` and `]` step places, and a click picks one;
  - floors cycle all, then dimmed, then alone;
  - YOU is at your live position;
  - an Echo gate (E) and a gate only its room can explain (?) are drawn as
    letters, because the kit has no icons for them yet.
- **Removed:** the prototype's REVIEW plate.
- **Lighting and sound:**
  - the wall-shade compensation is set per renderer;
  - the menu's cues come from the game's one cue bank (Tones);
  - slider acceleration happens on held repeats only.

## Found and fixed on the way

**By the rewritten suites:**
- A reading ran over its window on real campaign data. See the USE/COST
  rule above.
- The typing caret and underscores drew as "?", because the font has no
  "_". The caret is now a bar, and an underscore reads as a space.
- The consumable key's state was missing from its item's reading.
- A cost named its resource by id.
- Map turns and zooms pressed quickly did not add up.
- The Journal sometimes read the Map before the Map had seen the same
  snapshot.
- **N-21:** the bridge's fold wrote raw field names into history notes.
  - This is Dess's file, changed under your instruction to fix names at
    their source, and recorded for Dess.
  - The fixtures were regenerated from source.

**While checking the tour:**
- The start room listed four other rooms' return devices as its own exits.
  This came from the old Map's wording, and is fixed as described under
  **Ways back** above.
- **The tour's own data.** My first tour fixture "walked" backwards
  through one-way return devices, into rooms not reachable on foot.
  - It now makes a walk a player can make.
  - A bridge test judges that walk by the bridge's own map.

**By the first full-frontier run (stopped, fixed, then run again):**
- **`godot-boot`** still measured the pause menu as a 2D panel. It now
  asks the same things of the box, opened the way Escape opens it:
  - it covers the window opaquely;
  - the Settings wall is centred (0.0 px off);
  - every pause action is on screen, whole.
- **The design packet's copy of Dess's schema** needed N-21 as well. It
  now matches the bridge's, as Dess's own schema commits keep it.
- **Two import files for the font's images.** On a fresh unpack Godot
  hands these images to the font, so the game changed two tracked files
  the first time it opened. The committed files are now what Godot
  itself writes, and the renders are pixel-identical either way.

## How this was checked

**Scripted, automated,** on Linux in this container:
- **Menu suites:** the four suites run through the game's `Main`, rewritten
  by what each old check guaranteed, with the brief's new cases added.

  | Suite | Checks |
  |---|---|
  | Shell | 44 |
  | Equipment | 151 |
  | Map | 71 |
  | Journal and Settings | 76 |

  They send real key, pad-axis and mouse events, and every click is
  aimed where the part is drawn.
- **Live suites,** run one at a time with the real bridge: the candidate
  campaign, bombs, consumables, resume and more (part of CK11).
- **CK11,** the full frontier (92 steps) on `ce6ea3bd`, in a fresh
  worktree whose Godot import started from nothing, as your unpack will:
  running at the time of this commit (steps 1–18 of 92 green, none red); its result replaces this line.
- **Renders** of all four walls under Forward+ at 720p and 1080p, with
  contrast measured on the renders themselves.
- **Pixel checks:** the renders are pixel-identical between a fresh import
  and this tree.
- **Performance:** a probe of the box on your campaign's data (above).
- **The recorded tour.**
- **The build:** checked from a clean unpack (the Godot import changes no shipped file; `godot-boot` passes; the candidate launcher's `--dry-run` keeps its saves inside the unpack).

**Human:**
- Nobody has played this build yet.
- Your approval of Arty's tour was on a phone, and visual only.
- How the keys, the pad and the mouse feel in the integrated game is
  untested by a person.

**Platform:**
- **Tested on:**
  - Linux only, Godot 4.5.1;
  - Forward+ through a software Vulkan (Mesa's lavapipe) under a virtual
    display;
  - the suites also run headless.
- **Untested on Windows:**
  - the launchers with this build;
  - your GPU's rendering of the calibrated light;
  - a real controller;
  - mouse feel;
  - the cues through speakers (checked only as calls to the cue bank);
  - frame rate, hitches and input latency on real hardware;
  - high-DPI and fullscreen.

## Boundaries kept, and what I did not do

- **Kept:**
  - no renderer switch;
  - no save migration;
  - Epsilon's live model unchanged;
  - no purchases or keys.
- **Nothing running in the background:** no watcher, subscription,
  schedule or heartbeat. PR #14 is not subscribed.
- **Held for you, not begun:**
  - HB-F4g;
  - the CK9-F1 sweep;
  - HB-F4f;
  - 0.5.
- **Stopped here for your review.** Merging onto
  `claude/archipepsi-0-4-blindside` waits on it.

## Pictures

In the delivery archive, under `images/`.

**From the tour** (your campaign):

| File | What it shows |
|---|---|
| `tour-01-settings.png` | The PAUSED and OPTIONS boards. |
| `tour-02-equipment-module-pulled.png` | Clarity Draught pulled from the MOBILITY rack, compared with REP on SHIFT. |
| `tour-03-bomb-bag-history.png` | The Bomb Bag's whole history, Mk I to Mk V. |
| `tour-04-always-on.png` | The ALWAYS ON rack, scrolled. |
| `tour-05-page-turn.png` | A page turn: the Map comes round the corner post as Equipment leaves. |
| `tour-06-map-detail.png` | Corridor 1's detail on the Map: "the way back from Platform Path 4 lands here". |
| `tour-07-journal-wire.png` | A Journal entry's wire running round the corner into the Map. |
| `tour-08-shown-on-the-map.png` | That entry shown on the Map, with BACK TO YOUR VIEW. |

**From the suites' fixture** (hand-written data, for states the tour does
not reach):

| File | What it shows |
|---|---|
| `render-09-equipment-pending.png` | An equip SENT, with the key still holding what the bridge confirmed. |
| `render-10-equipment-offline.png` | The OFFLINE notice. |
| `render-11-consumable-empty.png` | The consumable key empty: "it stays on Q, and entering a Zone refills it". |
| `render-12-map-floors-dimmed.png` | A 4-floor Zone: your floor, the others dimmed (the small overview noted above). |
