# Track A2: the inventory visual pass — ROUTE AND ECHO

*Arty*

**Branch `claude/archipepsi-art`, PR #5. For your review, before any
production integration. I have stopped here.**

- Nothing is integrated, and no Production-owned file was edited.
- It does not open 0.5, Track C or Track E.
- Settings/Pause is still an explicit unfinished design item.
- The functional checkpoint, `f5dd9f7` (build `076cad7`), is safe in
  history. This pass builds on it, and none of the interaction you asked
  to keep was restarted.

**In this archive:**

| Item | What it is |
|---|---|
| `review/stills/still_inv_1_normal.png` | **Start here.** The inventory at rest: RMB, what is on it, and its echoes. |
| `review/stills/still_inv_2_compare.png` | The comparison state: a MK III candidate against what is on RMB. |
| `review/stills/still_inv_3_long.png` | The long-name, long-description state. |
| `review/clip/cap_09_inventory.mp4` (16 s) | **The one interaction clip.** `review/sheets/` has its marked moments. |
| `review/stills_720p/` | The same frames at 1280 × 720. |
| `review/stills/still_thread_map.png`, `still_map_follow.png`, `still_map_edges.png` | The thread; SHOW ON THE MAP with its way back; the edge marks. |
| `review/README.md` | **The review:** the direction, the motion, the evidence, the limits. |
| `build/menu_proto/` | The interactive build (Godot 4.5.x); `RUN.md` has every control. |
| `handoff/` | Both handoffs, revised: state and transition (with your decisions), and Glyph. |

## What you asked for, and where it is

| Asked | Where | Evidence scope |
|---|---|---|
| One coherent, strongly art-directed inventory, in the existing prototype | ROUTE AND ECHO: `review/README.md` §2–3 | implemented; judged by eye, mine only |
| Normal, comparison, and long-name/long-description states | the three `still_inv_*` stills, at 1080p and 720p | scripted |
| A resting screenshot and ONE short clip; not the eight again | `still_inv_*`; `cap_09_inventory.mp4` | scripted |
| An original shape language from connections, transformation, Echoes and relationships | the route; the name plate and one echo plate per Mk; the key's own keycap in the composition; the provenance lines | implemented |
| No circles, hexagons, clipped corners, neon, rivets, tiny labels or clutter | none are used; rectangles only where they mean something (plates, keycaps) | by eye |
| The selected ability shapes the composition | its name at 6× on a plate, its echoes, its read, its history | implemented |
| Readable body text, aligned values, stable targets | 2× body; the comparison is a table aligned on its arrow; stations never move on selection | scripted: hover and click leave every station where it was |
| Rapid selection: framing carries the motion, text stays clean | the route glides and the echoes slide; the words are rebuilt whole | scripted: no word's scale below 1 mid-flight; one composition at a time |
| The thread: one deliberate guide with designed corners | the route's own stroke, 45° corners, no casing; in level with its passage | scripted: one stroke |
| Travel keeps the map view; "show this on the map" frames the target, with a way back | E/Q travel; Enter/A SHOW ON THE MAP; BACK TO YOUR VIEW (Backspace, B, click) | scripted: framed; exact return; nothing to return from after travel |
| Offscreen indicators useful, revealing nothing | YOU and the picked place at the window's edge; the thread's arrow | scripted: marks appear; zero point at unknown rooms |
| The approved Glyph characters, menu first | `· “ ” ← ↑ ↓` backtick `✓ ✗ ✕ ▸ ▾ ★ ☆` (`b2e94c4`); HUD geometry deferred | font-import verifier; the tapes find no missing character |
| Your six handoff decisions, as proposed Production changes | `handoff/HANDOFF_STATE_TRANSITIONS.md` §6 | — |

## The direction, in one paragraph

An Archipepsi ability is an item from another world, read into this one
and carried on a key, and the composition is built from exactly that.

- **The route.** One stroke runs from the key you press, through what is
  on it, to what you are looking at.
- **The plate and its echoes.** That ability's name stands off the wall on
  a light plate like the keycaps. Behind it stands one echo plate for
  each item that went into it, stepping back toward the wall.
- **Level information.** Everything you read stays square to the wall and
  aligned. Only relations take the diagonal.

It uses what Persona 5 shows about scale contrast, value contrast,
overlap and motion carried by framing, without its colours, collage or
screens.

## Found and fixed on the way

1. **Grey slivers beside W on the name plate** at 1920 × 1080. The text
   face's 6-wide cell let ink reach the glyph quad's edge, and the next
   glyph on the sheet bled in. The cell is now 7 × 8 (`5e05728`). Ink,
   advances and offsets are identical glyph by glyph, regeneration is
   byte-identical, and the font-import verifier passes.
2. **The rail's spine ran past the foot of the wall.** It is now one line,
   held to the rail's view.
3. **A zoomed Map showed a picked room's frame through a centimetre-wide
   gap** between the map wall and the box's ceiling. The gap is shut. This
   predates this pass.
4. **An edge mark hid under BACK TO YOUR VIEW, and the off-view thread
   ended in a tangle.** Both are fixed: the marks step past the control,
   and the thread ends in its arrow.

## What changed in the sample, and in the tapes

- **The sample.** The layout-stress set has four more authored Echoes,
  one at MK III, and the longest name now carries a long description.
  They are regenerated through Production's model at `a2b9df6`, and the
  base fixture, the saves and the layout are unchanged.
  - Why: the rail holds more than the old drawer, and "more candidates
    than fit" had to stay true and tested.
- **The tapes.** The old drawer checks are re-expressed for the rail, and
  none is weakened. `review/README.md` §9 has the mapping.
  - New checks cover the squash, the overlap, the long name, the stroke,
    the follow and return, travel, and the edge marks.
  - **225 checks pass** (61 + 110 + 54), against 195 before.

## For Production — recommendations only, none implemented there

All of these are in `handoff/HANDOFF_STATE_TRANSITIONS.md` §6.

- **Your six decisions:**
  1. reduced motion covers every secondary motion;
  2. links carry explicit identifiers;
  3. Esc and B back out before closing, with a clear direct resume;
  4. navigation during a turn is not lost, and confirmations are never
     replayed;
  5. 720p text is a concern to improve, and important text is never
     shrunk;
  6. the dimmed overview, with the single-floor view kept.
- **New from this pass:**
  - SHOW ON THE MAP and BACK TO YOUR VIEW (Backspace is a proposed
    binding);
  - the edge marks;
  - the 7 × 8 text cell, which changes nothing Production draws.

## What I need from you

1. **Is ROUTE AND ECHO the visual direction?** If it is, the next step is
   to extend its language to the Map and Journal faces. Settings/Pause
   stays open until you open it.
2. **Hands-on use of the build**, with a mouse and with a controller.
   These are the questions scripted input cannot answer:
   - Does the plate read as *the ability* at a glance?
   - Does the echo count read as its Mk without the label?
   - Is the white route a guide, or does it compete with the text?
   - Is the rail comfortable with a mouse?
   - Is 2× body text legible at your screen size?
3. **Any of the new proposals to reject:** SHOW ON THE MAP and its way
   back, the edge marks, and Backspace as the binding.

## Evidence, in three separate scopes

1. **Implemented:** everything above.
2. **Exercised by scripted input through the real input path**
   (`Input.parse_input_event`: keys, mouse, pad):
   - 225 checks pass;
   - the clip and the stills are scripted too.
3. **Hands-on:** **not done by me.**

The art suite, `tools/check_art_current.sh`, passes: every generated asset
matches its source, including the revised text face. Blender is not in this
container, so the suite's Blender rebuild step is skipped, and the suite
says so itself.

## Commits

| Commit | What |
|---|---|
| `2605924` | the second ruling recorded |
| `b2e94c4` | Glyph: the approved menu characters |
| `bd7c872` | the inventory composition, ROUTE AND ECHO; the sample and the tapes |
| `eb4c18c` | the thread: one stroke, designed corners |
| `39ef168` | the Map: SHOW ON THE MAP, BACK TO YOUR VIEW, edge marks |
| `5e05728` | Glyph: the 7 × 8 text cell |
| `d9404a8` | the spine held to the view; the review's still tapes |
| `66e18b2` | the Map's top gap shut; the clip's tape. **The build, the clip and the stills in this archive are from this commit.** |
