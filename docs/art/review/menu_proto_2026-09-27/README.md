# Track A2 — the combined interactive review prototype

*Arty, art lane — 2026-09-27*

**Inventory, Map and Journal, built on the principles selected on
2026-09-27:**

- **LEAF**'s local unfolding and slot-tied comparison, in a revised
  composition, for Inventory;
- **LENS** for the Map;
- **THREAD** for Journal → Map, running round the physical corner onto the
  LENS map.

Settings/Pause is reachable in the four-face order, and its treatment is
still an open design item.

**For owner review, before any production integration.** Nothing is
integrated, and no Production-owned file was edited. This does not open
0.5, Track C or Track E.

---

## 1. Run it

In the archive, **`build/menu_proto/`** is the interactive build: the
prototype project as committed, with the Glyph files it loads.

- It needs **Godot 4.5.x** (made with 4.5.1).
- Open `project.godot` in the editor and press Play, or run
  `godot --path build/menu_proto`.
- `build/menu_proto/RUN.md` has the options (`--reduced`, `--text-prompts`,
  `--save=`, `--equipment=`, `--page=`) and every control.
- The window opens at Production's default, 1280×720.

It is not an exported executable: there are no export templates in the art
lane's environment.

**Sample data, labelled on screen:**

- Production's own saves and fixtures, answered by Production's own code at
  CK9 `a2b9df6`;
- plus 7 layout-stress Echoes, tagged AUTHORED wherever they appear.

**Equipping is a local preview:** it is labelled PREVIEW… NOT SENT, and it
is never sent. There is no second inventory or save system. The Settings
wall's REVIEW CONTROLS switch between the sample saves and between symbol
and text prompts.

## 2. The demonstrations you asked for, and where each is shown

| Demonstration | Capture (scripted) | Scripted checks |
|---|---|---|
| Selecting, and changing selection rapidly | `captures/cap_01_rapid.mp4` · `cap_02` | `test_core`: three presses 40 ms apart land on the third; `test_more`: eight Downs land on the last; five `]` land on the fifth place |
| Interrupting a transition | `captures/cap_02_interrupt.mp4` | turn retargeted mid-turn; unfold interrupted; the thread's rewind interrupted (Down then Up), and only the newest link is cast; lens glides interrupted |
| Inspecting and closing details | `captures/cap_03_map_details.mp4` | the Map's detail opens and closes; tags stay clear of it; the lens slides aside instead of covering the rooms |
| Leaving a face and returning with its context intact | `captures/cap_04_travel.mp4` | the Map keeps its pick, zoom and turn across Journal travel; Equipment keeps its key across a close |
| Reduced motion | `captures/cap_05_reduced.mp4` | a cut on every face (turn, unfold, lens, thread); the gate pulse holds at exactly 1.0 |
| Long descriptions, and more candidates than fit | `captures/cap_06_long.mp4` · `stills_720p/still_equipment_long.png` | 9 candidates with "3 MORE"; the whole card kept in view; the longest description (158 of `MAX_TEXT_LEN` 160) in full; wheel and right-stick scroll |
| *Also:* a passage changes state under the thread | `captures/cap_07_state.mp4` | the focus follows the same passage; `NOW OPEN.`; a vanished passage is said, and not re-pointed |
| *Also:* the controller, and text fallbacks | `captures/cap_08_pad.mp4` | pad symbols on its first press; sticks, triggers, Y; PROMPTS: TEXT on both devices |

- `sheets/` has one image per capture, showing its marked moments in order.
- `stills/` has those moments at full 1920×1080.
- `stills_720p/` has each face at Production's window default, **1280×720**:
  the legibility check.

## 3. The first deliberate visual pass

**The focal item.**

- The selected module unfolds **where it is**, as a card raised off the
  wall on a lit plate, with a soft two-layer shadow and a signal bar down
  its edge.
- A line runs from the key's socket to the drawer, so the card visibly
  belongs to its key.
- The comparison is named against the key's own cap, for example "AGAINST
  BRAIDED LASH, ON RMB NOW".
- The action sits at the card's foot, where the eye already is.

**Headings.**

- Each wall's name, and its number painted large and quiet at the top
  right, like a facility's room sign. The number is the one thing a turn
  changes.
- Section headings are faint ink on the wall and a brighter heading ink on
  raised plates.
- No text falls below 3:1 against its ground; the handoff §1 has the
  table. The layout-stress tag was 1.4:1, and is now readable.

**Controls.**

- Keycaps carry the device's own symbol: a mouse for RMB and MMB, pad
  glyphs on the pad.
- The prompt line follows the last device used, and every symbol has a
  text fallback.

**The cross-face connection.**

- The thread is ink on a casing of the wall's own colour, so it is never
  mistaken for a route.
- It wraps the corner post, and lands on the passage in the miniature.
- A bead at its start says whether the passage is shut (the circuit's own
  symbol and colour) or open (the way-out symbol).

**What gives the character: one wall grain and one ceiling light.** Each
wall is brightest at its top middle and falls away to its corners, and
raised things shade the wall behind them. No neon, rivets, clipped corners
or extra panels.

**Map labels are words on the glass.** They are placed every frame from
what they name:

- YOU beside the figure;
- each exit's tag beside its gate, never over another exit or the
  Journal's ring;
- the room's name and its open/shut count just outside the room.

The scripted tapes count clashes, and found **0** across every place,
orbit, tilt and detail state tried.

## 4. Evidence — three scopes, kept apart

1. **Implemented:** everything above, and everything in
   `HANDOFF_STATE_TRANSITIONS.md` §§2–5.
2. **Exercised by scripted input through the real input path:**
   - `Input.parse_input_event` carries keys, mouse buttons and motion, pad
     buttons and axes, with points carried through the viewport's
     transform;
   - `tapes/test_core.json` has **58** checks, `tapes/test_more.json` **87**
     and `tapes/test_inputs.json` **43**: **188**, all passing;
   - `test_inputs` presses every binding the prompts name at least once,
     and the handoff §7 lists which tape presses which;
   - the staged build passes `test_core` on its own, outside the
     repository;
   - the eight captures and the stills are scripted too. Each capture says
     so on screen, in yellow: `SCRIPTED INPUT -- …`.
3. **Hands-on use: not done by me.** Nobody has used this build with a real
   keyboard, mouse or controller. That review is yours. The questions it
   can answer that scripts cannot are in the report.

## 5. The handoff, alongside the build

- **`HANDOFF_STATE_TRANSITIONS.md`**, for each face: its states and
  transitions; the durations, what interrupts each and what reduced motion
  does; the inputs per device; the data bindings to EquipmentQuery,
  MapFace and JournalQuery; the Production deltas proposed (§6), including
  the **MapFace pulse finding**; the evidence scopes.
- **`HANDOFF_GLYPH_ASSETS.md`**: the characters added (`; — → [ ]`, and
  `° × …`, which Production already prints); the 21 device symbols plus
  `you`, each with its fallback; the characters Production's screens still
  need, each cited to its line at `a2b9df6`; the provisional circuit
  symbols; the shape and placement rules; the signal near-twin flag.

## 6. Reconciliation

| | |
|---|---|
| Stable checkpoint | CK9 `a2b9df6`, code `22fdbda` |
| Production head at the start | `152d777` |
| Menu, query, contract, binding and fixture files | byte-identical CK8 `3b96bc4` → `152d777` |
| Gear | `SUPPORTED_GEAR_DOMAINS = ()`, so no gear is shown |

The sample is regenerated from CK9 by `tools/menu_proto/extract_sample.sh
a2b9df6`; `sample/SOURCE.json` records the revision. This pass added
`MapFace.band_of_room` and `player_floor` to it, and nothing else changed.

## 7. Known limits

- **Settings/Pause is not designed.** It shows Production's items plainly,
  and only MOTION works.
- **Pad fallbacks name the Xbox layout.** That is what Production binds.
- **The map window's ground is plain dark.** Whether the miniature should
  stand on a visible floor for orientation is an open visual question.
- **The captures are 1920×1080** at 30 fps, rendered in software. Timing
  is exact (a fixed 30 fps), but this is not a performance measurement.

## 8. Reproduce

The commands, from the repository root:

```
tools/menu_proto/test.sh                        # both tapes, headless
tools/menu_proto/capture.sh <out>               # the eight captures, sheets, stills
tools/menu_proto/stills.sh <out> 1280x720       # gameplay-size stills
tools/menu_proto/stage_build.sh <out> [rev]     # the build in this archive
tools/menu_proto/extract_sample.sh a2b9df6      # the sample, from Production
```
