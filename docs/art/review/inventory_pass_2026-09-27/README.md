# Track A2 — the inventory visual pass: ROUTE AND ECHO

*Arty, art lane — 2026-09-27*

**One art-directed inventory composition, in the existing prototype**,
shown in the three states you asked for, at rest and in one short clip.
With it: the thread's stroke, the Map's SHOW ON THE MAP and its way back,
offscreen marks that reveal nothing, the approved Glyph characters, and
your handoff decisions recorded as proposed Production changes.

**For owner review, before any production integration.** Nothing is
integrated, and no Production-owned file was edited. It does not open
0.5, Track C or Track E. Settings/Pause is still an explicit unfinished
design item. The functional checkpoint, `f5dd9f7` (build `076cad7`), is
kept in history, and this pass builds on it without restarting any of the
interaction you asked to keep.

---

## 1. Look at these first

| File | What it shows |
|---|---|
| `stills/still_inv_1_normal.png` | **Normal selected item, at rest.** RMB, what is on it (BRAIDED LASH, MK II, two echoes), selected on the rail. |
| `stills/still_inv_2_compare.png` | **Comparison.** SILVER VOLLEY, MK III (three echoes), against what is on RMB now. |
| `stills/still_inv_3_long.png` | **Long name, long description.** The longest name the sample holds, with a 157-character description. |
| `clip/cap_09_inventory.mp4` | **The one interaction clip**, 16 s: at rest; one selection at a time; seven rapid ones; the MK III echoes; the long item; a local preview; another key. |
| `sheets/cap_09_inventory.png` | The clip's eight marked moments on one sheet, including one 0.1 s after a press and one mid-flight in the rapid run. |

The stills are 1920 × 1080; `stills_720p/` has the same frames at
Production's window default, 1280 × 720, for legibility. Everything here is
**scripted input**, not hands-on use.

For the refinements: `stills/still_thread_map.png` (the thread at rest on
the Map), `stills/still_map_follow.png` (SHOW ON THE MAP, with BACK TO
YOUR VIEW) and `stills/still_map_edges.png` (panned away on purpose: YOU
and the picked place at the window's edge, and the thread's arrow).

## 2. The direction

The shape language is taken from what an Archipepsi ability *is*: an item
from another world, read into this one, and carried on a key. Three
rules, and nothing else:

1. **Relations run on the route.** One stroke — 6 px, every turn cut at 45
   degrees, mitred — runs from the key you press, down the rail to the
   selected item, and into that item's name plate. It is the comparison
   made visible: from what is on the key to what you are looking at. When
   the selection moves, the route moves; the words do not. The Journal's
   thread is now the same stroke. *(Connections; relationships between
   objects.)*
2. **An echo repeats.** The selected ability's name is printed large (6×)
   on a light plate like the keycaps — the thing you put on a key —
   standing off the wall. Behind it stands one plate for every item that
   went into it: its Mk. Each echo is a step further down the diagonal and
   nearer the wall, fading to the wall's grey. A frozen frame says what the
   ability is and how many things made it, without reading a word.
   *(Echoes; spatial transformation — the stack recedes in real depth, in
   the box's own light.)*
3. **Information stays square.** Everything you read is level, aligned
   and at the face's own sizes. Only relations take the diagonal.

Read against the plate, the rest of the composition answers in order:

- **The kicker:** the key's own keycap, where this item stands with it
  (ON THIS KEY NOW, FITS THIS KEY, PREVIEW ON THIS KEY, NOT SENT, SAVED ON
  THIS KEY), and its family and Mk.
- **How it was read**, at 3×: the concepts of the Echo that made it
  (BOW / DRAW / PATIENCE).
- **Where it came from:** one line per item that went into it, in
  Production's history form, "MK  note ← item (game)" — one line per echo
  plate.
- **What it is:** the description; DOES, HOW IT IS USED and COST.
- **What changes on the key:** Production's comparison lines set as a
  table, with the values aligned on the arrow.
- **The action**, always in the same place at the foot, in signal.

**What Persona 5 taught, not copied.** Its colours, collage and screens
are not used. What is used is how its menus make shape, type, contrast,
overlap and motion work together:

- scale contrast: a 6× name against 2× body text;
- value contrast: a light plate with dark type is the one light mass on
  a dark wall;
- overlap: the echo stack overlaps the route, which plugs in behind it;
- diagonal energy at rest: the echo steps and the route's corners;
- movement carried by the framing.

**What it is not.** No circles, hexagons or clipped-corner panels stand in
for rectangles. There is no neon, no rivets, no tiny technical label and
no ornament. Rectangles are used where they mean something: the plate and
its echoes, and the keycaps. The gray card and the strip list are gone.

## 3. The rail and the keys

- **Down the left, the keys:** Production's five, and ALWAYS ON. Each
  stands on a faint shelf. The focused key's shelf is where the route
  begins, under what is on the key.
- **The rail:** the focused key's candidates, as stations on a spine, in
  a fixed order, with the save's occupant first.
  - What is on the key has a solid node; its second line says ON RMB.
  - Every station's second line gives its Mk, and AUTHORED where the
    sample authored it.
  - **Selecting never moves a station.** The detail is composed beside the
    rail, not unfolded inside it. So a mouse target is exactly where it
    was, before and after every press.
- The rail is still a window. Wheel or right stick scroll it under patches
  of the wall at its top and bottom, with no hole (`holes`). A selection
  scrolled out of view by hand stays composed, and the route turns at the
  rail's edge toward it.

## 4. Motion

| What | Full motion | Reduced motion |
|---|---|---|
| A new selection | The composition is rebuilt **at once, whole**. The route glides to the new station (0.14 s) and into the new plate. The echo plates slide out from behind the plate, nearest first (0.20 s, 30 ms apart). | all a cut |
| Rapid selection | The same, from wherever things are: the route and the echoes retarget, the words are already right. | cut |
| Another key | The route's key end glides to the new shelf (0.16 s). The stations appear down the spine, each whole, 16 ms apart. | cut |
| Keyboard selection out of view | The rail scrolls (0.18 s); the route follows its station. | cut |

**No word is ever scaled to animate.** The first pass unfolded a card by
scaling it, and rapid selection squashed and overlapped the text; that is
gone. A tape measures the smallest vertical scale of any word on the wall
**mid-flight in a run of rapid presses**, and requires exactly 1. It also
requires exactly one composition on the wall at every moment.

## 5. The other refinements

**The thread is one deliberate guide.** It is the route's own stroke: one
solid line, 6 px as seen from the eye wherever it runs, 45-degree corners,
and no casing or second line (a tape checks `strokes` = 1). On the Map it
runs down the margin beside the window and goes in **level with its
passage**, stopping just short with a terminus bar so the passage's mark
stays visible. Off the view, it ends at the window's edge in its arrow.

**Ordinary travel and SHOW ON THE MAP are now different.**

- **Travel** (E, Q, the edge arrows, Tab) turns to the Map exactly as it
  was left. A tape proves there is nothing to go back to afterwards.
- **SHOW ON THE MAP** is Enter or A on a linked Journal entry. The Map
  frames what the entry names:
  - a place is picked;
  - a passage is centred, at a zoom that shows what is round it, with
    every floor shown and the detail closed.
- **BACK TO YOUR VIEW** restores the view, the pick, the detail and the
  floor the Map had before. It is Backspace, or B, or a click on the words
  at the window's top left.

**What you look away from stays findable, and nothing is revealed.** Pan,
orbit or zoom away on purpose, and **YOU** and **the picked place** stand
at the window's edge with an arrow toward them; the thread keeps its own
arrow. Only these are marked:

- By construction, a mark can name only your own room and the room you
  picked, and both are known.
- A tape checks, panned away, that no shown mark points at a room the save
  does not know.
- There are no marks for undiscovered rooms, for solutions, or for where
  to go next.

## 6. Glyph

- **The approved characters are in the text face** (`b2e94c4`), the
  menu's needs first:
  - the punctuation and arrows `· “ ” ← ↑ ↓` and the backtick;
  - the marks `✓ ✗ ✕ ▸ ▾ ★ ☆`.

  Production prints each of them inline in an existing string, so in the
  face they render as written, with no change to code, binding or
  behaviour. The HUD geometry set is recorded and deferred: the ruling put
  the menu first. See `handoff/HANDOFF_GLYPH_ASSETS.md` §3.
- **The text face's cell is 7 × 8** (`5e05728`), which gives every glyph a
  clear column on both sides.
  - In the 6-wide cell, the name plate showed grey slivers beside W at
    1920 × 1080: the ink reached the quad's edge, and the next glyph on the
    sheet bled in.
  - Every glyph's ink, advance and offsets are unchanged, checked glyph by
    glyph. Regeneration is byte-identical, and the font-import verifier
    passes.

## 7. The handoff decisions

They are carried into `handoff/HANDOFF_STATE_TRANSITIONS.md` §6 as
**proposed Production changes**. Nothing in Production is edited until that
file ownership is handed over.

1. Reduced motion includes the gate pulse and all other secondary motion.
2. Journal links consume explicit passage and room identifiers.
3. Esc and B back out of an open detail first, then close the menu when
   there is no deeper view, and a clear direct resume stays.
   - The prototype does this for B.
   - It keeps Production's Esc, because that file is Production's.
4. Navigation pressed during a turn is not lost. An equip, a quit or any
   other confirmation is never replayed into a control the player has not
   seen.
5. 720p text size is a concern to improve, not a guarantee. The new
   composition never shrinks important text: a long name wraps rather than
   going below 4×.
6. Dimmed other floors are for overview; a genuine single-floor view is
   kept.

**New from this pass:**

- SHOW ON THE MAP and BACK TO YOUR VIEW (Backspace is a proposed binding);
- the edge marks;
- the 7 × 8 text cell.

## 8. Run it

`build/menu_proto/` in the archive is the interactive build (Godot 4.5.x).
Its `RUN.md` has every option and control. It opens on Equipment, at
Production's window default.

**The sample changed in one place.** The stress set gained four authored
Echoes, one raised to MK III by two upgrade Echoes in the way the fixture
raises BRAIDED LASH to MK II. The longest name now carries a long
description. The reasons:

- the rail fits more than the old drawer, and "more candidates than fit"
  had to stay true and testable;
- the review needed a Mk above II to show the echoes.

The set is regenerated through Production's own model at `a2b9df6`. The
base fixture, the saves and the layout are unchanged, and every authored
item is tagged AUTHORED wherever it appears.

## 9. Evidence — three scopes, kept apart

1. **Implemented:** everything above.
2. **Exercised by scripted input through the real input path**
   (`Input.parse_input_event`: keys, mouse, pad):
   - **225** checks pass: `test_core` 61, `test_more` 110 and
     `test_inputs` 54 (the first pass had 195);
   - the clip and the stills are scripted too, and each capture says so on
     screen.
3. **Hands-on use: not done by me.** Nobody has used this pass with a real
   keyboard, mouse or controller.

**What changed in the tapes, and why no check was weakened.** The first
pass's drawer checks tested a card unfolding inside the list. The list no
longer holds the detail, so the same guarantees are checked in the new
layout:

| Guarantee | How it is checked now |
|---|---|
| More candidates than fit | The count is 13; the N MORE markers. |
| A long description is set in full | It is set in full and clear of the action (`focus.clear`). |
| No hole on a hand scroll | `holes` is still under 19 px on every notch. |
| A half-scrolled card is still drawn | The selection stays composed when its station is scrolled out, and the route turns at the rail's edge (`route_held`). |

The hover and click coordinates moved from the old strips to the rail's
stations. **New checks:**

- no squashed word mid-flight, and one composition at a time;
- the route moves, then comes to rest;
- the long name wraps, 4× at the least;
- the thread is one stroke;
- SHOW ON THE MAP frames the passage; BACK TO YOUR VIEW (key, click)
  restores the exact zoom and target; travel leaves nothing to return to;
- the edge marks appear, and point only at known rooms.

## 10. Known limits

- **Only the inventory has the new language.** The Map, Journal and
  Settings faces keep the first pass's treatment until you choose this
  one. The thread's stroke is the one shared piece.
- **The plate's colour and the echo tones are provisional.** The plate is
  lit by the box's ceiling light, so it is brightest at the wall's top
  middle.
- **The route is white.** Signal is kept for focus and action. Whether a
  white guide competes with the text is a question for your screen.
- **The Map's edge marks can sit on the window's corner reveal**, when a
  target is off both a side and the top or bottom.
- **The thread's final run crosses what lies left of its passage.** It
  enters at the passage's height, so on a busy row it passes over rooms on
  the way in.
- **Captures are rendered in software**, at a fixed 30 fps. Timing is
  exact, but this is not a performance measure.

## 11. Reproduce

The commands, from the repository root:

```
tools/menu_proto/test.sh                                     # the three tapes, headless
tools/menu_proto/capture.sh <out> cap_09_inventory           # the clip and its sheet
tools/menu_proto/stills.sh <out> 1920x1080 "still_inv_*"     # the three states
tools/menu_proto/stills.sh <out> 1280x720  "still_inv_*"     # ... at 720p
tools/menu_proto/stage_build.sh <out> [rev]                  # the build
tools/menu_proto/extract_sample.sh a2b9df6                   # the sample, from Production
```
