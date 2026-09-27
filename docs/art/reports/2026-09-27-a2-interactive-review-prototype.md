# Track A2: the combined interactive review prototype

*Arty*

**Branch `claude/archipepsi-art`, PR #5. For your review, before any
production integration. I have stopped here.**

- Nothing is integrated, and no Production-owned file was edited.
- It does not open 0.5, Track C or Track E.
- Settings/Pause is reachable, and its treatment is still yours to open.

**In this archive:**

| Item | What it is |
|---|---|
| `build/menu_proto/` | **The interactive build.** Needs Godot 4.5.x. `build/menu_proto/RUN.md` says how to open it, with every option and control. |
| `review/` | `docs/art/review/menu_proto_2026-09-27/`. `review/README.md` is the review. |
| `review/captures/cap_04_travel.mp4` (15 s) | **Start here.** A pick on the Map, then the Journal: the thread runs round the corner onto the passage. Follow it, and the Map is exactly as it was left. |
| the other seven captures, 10–15 s each | one demonstration each: `review/README.md` §2 |
| `review/stills_720p/` | every face at Production's window default, 1280×720 |
| `review/HANDOFF_STATE_TRANSITIONS.md` | the state/transition handoff |
| `review/HANDOFF_GLYPH_ASSETS.md` | the Glyph asset requirements |

## What you asked for, and where it is

| Asked | Where | Evidence scope |
|---|---|---|
| One interactive prototype: Inventory, Map, Journal | `build/menu_proto` | implemented; scripted |
| Real mouse and keyboard; controller included; tested kept apart from implemented | every control in RUN.md | Every binding the prompts name is **pressed by a scripted tape through the real input path**; `HANDOFF_STATE_TRANSITIONS.md` §7 lists which tape presses which, and the two that are never pressed. Hands-on: **not done**. |
| Representative sample data, labelled; equipping a labelled local preview | sample from Production at CK9 `a2b9df6`; the 7 layout-stress Echoes tagged AUTHORED; PREVIEW… NOT SENT | scripted |
| Rapid selection · an interrupted transition · details opened and closed · travel and return with context intact · reduced motion · long text and overflow | captures 01–06; `review/README.md` §2 maps each one to its checks | scripted: **195 checks** pass (58 + 94 + 43) |
| A first deliberate visual pass: focal item, headings, controls, cross-face connection; no neon, rivets, clipped corners or extra panels | `review/README.md` §3; the stills | implemented; judged by eye, mine only |
| Settings/Pause in the four-face order, left open | the Settings wall, marked NOT DESIGNED IN THIS PASS | implemented |
| Glyph: `; — → [ ]`, without changing a binding or a meaning | commit `48e6b76` | the font-import verifier; the tapes assert that no character is missing |
| Glyph: device symbols with readable text fallbacks | 21 symbols plus `you`; PROMPTS: TEXT | scripted on both devices |
| Glyph: focus, circuit and you told apart by shape and placement | frame, symbol on its gate, and figure with a tag | implemented; shown in the stills |
| Reduced motion covers secondary motion; the MapFace pulse finding | the pulse is held; `HANDOFF_STATE_TRANSITIONS.md` §6.1 | scripted (the pulse is exactly 1.0 at two times) |
| Isolated, with no Production runtime edits | `tools/menu_proto`, its own Godot project | — |
| Reconciled against the stable checkpoint, and recorded | CK9 `a2b9df6`; the menu, query and fixture files are byte-identical from CK8 to `152d777`; `SUPPORTED_GEAR_DOMAINS = ()` | recorded in `sample/SOURCE.json` and both handoffs |
| The Glyph requirements and the state/transition handoff, with the build | `review/HANDOFF_*.md` | — |
| Scripted capture kept apart from hands-on verification | every capture is captioned SCRIPTED INPUT on screen | — |

## What changed from the studies

**Inventory: LEAF, recomposed around the module and its key.**

- The drawer opens out of the selected key's socket, and a line joins
  them.
- The chosen module unfolds **in place** as a raised, lit card: what it
  is and does on the left, and on the right what changes if it goes on
  that key, "AGAINST <what is there>, ON <cap> NOW".
- Hover only lights a strip, and a click opens the strip under the
  pointer where it is. The drawer's order is fixed (the saved occupant
  first), and a preview never reorders it.

**Map: LENS, with short answers on the glass.**

- The picked room gets its name, its open/shut count and one word per
  exit ("TO ARENA 1", "SHUT — TO PLATFORM PATH 1", "A WAY ON, NOT YET
  WALKED").
- Those words are placed every frame, clear of each other, of the room and
  of the exits. The long answer (MapFace's own detail) docks at the edge
  on request, and the miniature slides aside for it.

**Journal → Map: THREAD, round the real corner.**

- It is bound to the passage's identity, not to the row, and the entry
  keeps the full explanation.
- It follows the lens, stops at the window's edge with an arrow when its
  target is off view, and follows the passage through a save change.

## Found and fixed on the way

Every one of these was the prototype's own fault; none is in Production.

1. **The Map's labels were invisible.** A Label3D keeps its parent's scale
   even when it is fixed-size and billboarded, and the miniature is scaled
   down about a hundredfold. The labels are now words on the window's
   glass, placed from the projected geometry.
2. **The thread could cast to an entry you had already left.** Press Down,
   then Up at once, and the recast queued for the entry in between
   survived. The new tape fails without the fix and passes with it.
3. **The Map banded floors by a 0.5 m tolerance**, which put Arena 2
   (1.53 m) on no floor at all. It now reads Production's own answer,
   `MapFace.band_of_room`. That answer was added to the extraction and the
   sample regenerated from CK9, and only those fields changed.
4. **The pad prompt promised "R-STICK: SCROLL" in the drawer, and nothing
   read the stick.** It is implemented now, and a check proves it.
5. **Faults found at gameplay size:**
   - a long name collided with the layout-stress tag;
   - the overflow count was covered by an open card;
   - a printed arrow cast a shadow blob;
   - an exit tag touched its own gate symbol;
   - the layout-stress tag sat at 1.4:1 contrast.

   Each is fixed, and **no text is now below 3:1 against its ground.**
6. **The first full capture run showed a hole in the drawer.** Wheel the
   drawer up by hand with the long card open at its foot, and the card,
   now only partly in view, was hidden whole, leaving an empty stretch of
   drawer.
   - The drawer is now a window. Patches of the wall itself lie just in
     front of the list at its top and bottom edges, with the grain aligned
     texel for texel, and whatever scrolls past slides under them.
   - The open card is cut a line at a time, so it is never half-hidden as a
     hole and never spills past the wall.
   - A new measure, `holes`, is checked to be zero on every scroll.
   - All eight captures were then recorded again.

## For Production — recommendations only, none implemented there

These are in `HANDOFF_STATE_TRANSITIONS.md` §6.

1. **MapFace's gate pulse ignores reduced motion.** At `a2b9df6`, `_pulse()`
   scales every blocker regardless of the setting, while MenuShell already
   reads `motion_intensity`. A suggested shape is in the handoff.
2. **JournalQuery should return structured rows**, carrying `edge_id`,
   `edges`, `circuits` and `room_id` beside the unchanged text. Today, a
   link to a passage can only be made by re-deriving each line through
   JournalQuery's *private* helpers and matching the text exactly.
3. **Esc and B could back out of a detail before closing the menu.** The
   prototype keeps Production's rule (Esc closes); this is offered for
   your decision.
4. **Face input during a turn is dropped** for 0.42 s, in Production and in
   the prototype alike. Delivering it to the face being turned to would
   stop a quick "turn, then ↓" losing the press.
5. **Legibility at 1280×720 with no stretch:** 2× text is about 8.6 px
   caps. It is legible in `stills_720p/`, but that is the floor.
6. **One floor at a time:** Production hides the other floors, and the
   LENS dims them to keep orientation.

## What I need from you

1. **Hands-on use of the build**, with keyboard and mouse and with a
   controller. These are the questions scripted input cannot answer:
   - Does the unfolded card read as *belonging to its key*?
   - At a glance, is the thread a pointer, or noise?
   - Is 2× text on the glass too small at your screen size?
   - Does anything you need disappear with MOTION off?
   - Does any transition make routine use wait?
2. **The Glyph characters Production still needs**
   (`HANDOFF_GLYPH_ASSETS.md` §3): `· “ ” ← ↑ ↓` and the backtick in the
   text face, and `✓ ✗ ✕ ▸ ▾ ★ ☆` and the HUD geometry as symbols. I did
   not add them: they go beyond the four you asked for.
3. **The six Production deltas** above: take them, or leave them.
4. **The visual pass:** is it the character to carry into production, or
   does it need another pass first? Settings/Pause stays open until you
   open it.

## Evidence, in three separate scopes

1. **Implemented:** everything above.
2. **Exercised by scripted input through the real input path**
   (`Input.parse_input_event`, with keys, mouse and pad):
   - `test_core` has **58** checks, `test_more` **94** and `test_inputs`
     **43** (every binding pressed): **195**, all passing;
   - the staged build passes `test_core` on its own;
   - the 8 captures and 6 gameplay-size stills are scripted too.
3. **Hands-on:** **not done by me.**

## Commits

| Commit | What |
|---|---|
| `a3e37cd` | the ruling recorded |
| `48e6b76` | Glyph: the characters and the device symbols |
| `70776d0` | the sample, reconciled at CK9 |
| `b36bc03` | the first working build |
| `a6149c6` | the visual pass |
| `fbfa5c6` | the remaining demonstrations under test, and two fixes |
| `15e5d3d` | the capture pipeline, the gameplay-size stills and the handoff drafts |
| `ee052a9` | every binding under test; the review README, this report and the frontiers |
| `5738865` | the drawer clips at its edges; two caption fixes. **The captures and the build in this archive are from this commit.** |
