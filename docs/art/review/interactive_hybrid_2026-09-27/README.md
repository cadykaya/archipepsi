# The interactive hybrid: original station hardware, kept alive by Epsilon

*Arty*

This is the approved hybrid, built into the isolated menu prototype for
your hands-on review. **It is not final hands-on acceptance, and it is not
approval for Production integration.** I have stopped here.

- The prototype's own behaviour and data drive it. There is no parallel
  menu logic.
- Nothing is integrated, and no Production-owned file was edited.
- The previous checkpoints are safe (see [Kept safe](#kept-safe)).

**Start here:**
1. **Run it:** the archive's `build/menu_proto/`. `RUN.md` there has the
   launch line and every control. From the repository, stage the same
   build with `tools/menu_proto/stage_build.sh <dir>`.
2. **Watch the tour:** `tour/cap_10_tour.mp4`, 33 s across all four walls,
   with the menu's own sound. `tour/cap_10_tour.png` is its marked
   moments.
3. **See the two fixes:** `closeups/fix_1_settings_feed.png` and
   `closeups/fix_2_readability.png`. Both are at 1:1 pixels at
   1280 × 720, before and after.

## What to try with your hands

| The ruling asked for | Try |
|---|---|
| Equipped, inspected and previewed, clearly distinct | Equipment, → into the rack, ↓. The module on the key stays **seated**, and its window says ON RMB. The one you read is **pulled** toward you. Press Enter: its window says PREVIEW · NOT SENT, and the key's own window says PREVIEW first. |
| Readable at once when the selection changes | Hold ↓ in the rack. The window's words are whole in the frame each press lands; only the modules slide. |
| Ordinary keyboard, mouse and pad | All of it, on any wall. The prompt line follows the device you last touched. |
| Stable targets; the whole list reachable | Wheel over the rack: a row a notch, to the last item. Then click it. Nothing moves under the pointer. |
| The selector usable through ordinary input | ↑ ↓ on the keys, a click on a key, or the wheel over the selector: one detent a key. There is nothing to drag round. |
| Empty keys and charges | MMB (nothing fits it), C (one thing does), Q (CINDER CHARGE 2/3 on the key and in the rack), ALWAYS ON (no key). |
| Map travel keeps the view | Q / E to and from the Map. It is as you left it. |
| The journal follow, framed, with a way back | Journal, Enter on a shut way: the Map frames it. Backspace, B, or the words on the glass bring your view back. If a place's detail is open, the first press closes it. |
| Reduced motion, same information and actions | Settings → MOTION to OFF (← held, or click its left end), or run with `--reduced`. Everything cuts; the sounds stay. |
| Useful sound, apart from motion | Browse, turn, preview, hit the end of a list. MASTER VOLUME sets them, and 0 is silent. |

## The two refinements

1. **Settings: Epsilon's feed no longer sits on a value.** In the stills,
   the drop through him ended in a terminal on the MOUSE SENSITIVITY
   window, so "100%" could read as his. Now his feed runs down the board's
   empty right margin into a terminal in the board's empty foot, and
   crosses no value and no control.
   - The sensitivity window now reads **X1.00**, Production's own words
     (SettingsFace._describe), not the still's "100%".
   - `test_hybrid` checks the feed is clear on the layout itself, before
     and after the values change (`settings.feed_clear`).
2. **Readability: the quieter words, a step up for 1280 × 720.** Only
   colours changed; no size did. Contrast is measured against what is
   behind the words on screen:

| Words | Before | After |
|---|---|---|
| comparison labels (KIND, DAMAGE …) | `#7b766b`, 4.2:1 | `#978f80`, 5.2:1 |
| comparison old values, key words | `#aaa495`, 7.7:1 | `#c4bdad`, 8.8:1 |
| history lines (MK I ← …) | `#7b766b`, 4.2:1 | `#978f80`, 5.2:1 |
| Journal entries, not focused | `#9da3a8`, 4.2:1 | `#b9bec2`, 5.8:1 |
| Journal notes | `#9da3a8`, 4.2:1 | `#aeb3b8`, 5.1:1 |

The hierarchy holds. New values and names stay brightest, then old
values and descriptions, then labels and history.

## What changed from the approved stills, and why

- **ALWAYS ON is the selector's sixth position.** The strip above the
  window is gone. The prototype already browses the passives like a key,
  so they now sit on the selector with the keys, where each can be read.
- **The rack shows 9 modules at a 28 px pitch** (the still: 30 px). It
  scrolls a whole row at a time, never a partial row, and a repurposed
  slide pot shows where you are. "N MORE ABOVE / BELOW" are silk-screened
  on the backplane.
- **The inspection window carries all of the item.** It shows USE and
  COST as well as DOES and the description. Every block is placed and
  none is dropped:
  - a long column steps its sizes down (the name first, never below 3x);
  - the history moves to whichever column has room.
- **The longest name is at 3x on two lines**, as in the approved still
  (H_2). The pre-hybrid composition had the whole wall and set it at 4x.
  See the check table below.
- **Settings shows Production's own ranges, steps and words.** MOTION is
  Production's 0–1 slider in 0.05 steps, so its window reads 100% (OFF at
  0), not the still's FULL. The prototype's own review controls sit apart,
  on a plate of their own, and the OPTIONS board's foot is cut round it.
  The CAMPAIGN → OPTIONS ribbon moved up to make room.
- **The Map's detail tag is as tall as its words.** It has a SIGNAL edge
  while it is open.

## Motion, as built

Nothing waits for the hardware. Every movement below can be interrupted,
and a new input retargets it.

| Where | Movement | Reduced motion |
|---|---|---|
| Key selector | the pointer turns to the key, 0.1 s | a cut |
| Rack | the read module slides out, 0.1 s; the last one slides home at the same time; the window's words swap in the same frame | a cut |
| Rack scroll | a whole row; the slide pot's knob moves in 0.08 s | a cut |
| Settings sliders | the knob moves, 0.06 s | a cut |
| Journal → Map link | paid out from the tag along the harness, 0.42 s at an even pace; a new link rewinds first (0.14 s) | simply there |
| Page turns | Production's 0.42 s, retargetable | a cut |
| Flags and tags | rigid: they never swing, and their words never move | — |

## Sound

The prototype has a small cue bank, made with Production's own recipe
(Tones: synthesised bursts, arpeggios and thuds). It is a separate bank;
Production's own is unchanged.
- tick, detent, edge, scroll, page, preview, restore, refuse;
- value (its pitch follows the value), toggle, follow, return, open, close.

They are information, so reduced motion leaves them alone. MASTER VOLUME
sets the bus they play on, as Production's `apply_volume` does.

**I have not listened to them.** The tapes' cue log and the tour's audio
track show they play. Their loudness and timbre are first settings for
your ear.

## Evidence

| Scope | Status |
|---|---|
| Implemented | `tools/menu_proto`: `parts.gd`, `cues.gd`, the shell, the four faces, the link. |
| Exercised by scripted input through the real input path | **434 checks in 4 tapes pass** (`Input.parse_input_event`: keys, mouse, pad). Also the tour. |
| Hands-on | **Not done.** |

The 434 checks:
- **`test_hybrid.json` (206)** exercises the hybrid's own layout:
  - equipped, inspected and previewed;
  - rapid selection (no word squashed, one readout, the readout right in
    the frame the press lands);
  - every RMB item's readout fitting;
  - scrolling to the last item by keyboard, wheel, click, right stick and
    d-pad;
  - empty keys, charges and ALWAYS ON;
  - the selector by click and wheel, and rapid key changes;
  - device switching and page turns;
  - every Settings control by keyboard, mouse and pad, and Epsilon's feed;
  - the cues with motion reduced;
  - the journal follow and back;
  - the Journal's longest column, scrolled to its last entry.
- **`test_core` (61), `test_inputs` (55) and `test_more` (112)** are the
  pre-hybrid tapes, ported by intent. Clicks now name what they click
  (`"equipment:row:act_s_arc"`); the face reports where that is, and the
  box projects it to the screen.

**The checks the port changed.** None was dropped. These asserted parts
that the hybrid retired, or the pre-hybrid layout's numbers:

| Pre-hybrid check | Hybrid check | Why |
|---|---|---|
| `strip_positions` unchanged by hover and click | `row_hits` unchanged | the rack's click targets |
| "the route and the echoes are still travelling" (`busy`) | "the pulled modules are still sliding" (`busy`) | the route and echoes are retired; the modules carry the motion |
| `route_moving` true, then false | `rack_moving` true, then false | the same |
| `more` "3 MORE" | "4 MORE BELOW" / "4 MORE ABOVE" | the rack shows 9 rows (the approved composition); the rail showed 10 |
| `name_k` > 3 (a 4x floor) | `name_k` > 2 (a 3x floor), and still 2 lines, whole | the approved inspection window sets the longest name at 3x (H_2) |
| `focus.clear` | `focus.fits` | the readout's own test: every block placed, clear of the action |
| `route_held` "below" | `more.1` "1 MORE BELOW" | where the read module went, said by the rack |
| `route_held` "" | `pulled` "act_s_mote" | back in view, and pulled |
| `settings.focus` 0, "on MOTION" | `settings.row` MOTION, after six ↓ | Settings opens on RESUME now |
| MOTION: → toggles OFF / FULL | a click at the slider's ends (0 is OFF) | MOTION is Production's slider |
| a click focuses row 3 (PROMPTS) | a click on its TEXT value focuses row 11 | the review plate's row |
| "SPACE is ui_accept too: preview on MMB" | the same, on RMB | MMB takes nothing in this sample. The old check passed only because a missing value counted as "not empty". |

**Two harness fixes** came from that last row:
- `empty` now counts a missing value as empty;
- a numeric check on a missing value now fails instead of crashing.

## Found on the way

- **A raw field name in Production's data.** Magic Meter's Mk II history
  note is `+40 max_value`. The face has no underscore, so the prototype
  prints `+40 MAX VALUE`. That is the only substitution, and it is flagged
  here for Production to fix at the source.
- **A vacuous old check:** the SPACE-on-MMB row above.

## Kept safe

- The four studies (`8b13aa7`) and the hybrid stills (`94e219d`) are
  frozen. Their scene no longer takes the interactive harness or port. I
  re-rendered studies H (4 stills) and B (5 stills) from this tree, and
  they match the delivered images pixel for pixel.
- The pre-hybrid build (`66e18b2`) and the inventory pass (`91e5d3f`) are
  in history. Their capture and still tapes describe that layout, so they
  moved to `tapes/pre_hybrid/`, with a note.
- `stage_build.sh` leaves `studies/` out of the build.

## Limits

- **Hands-on use is yours:** I have only driven it by script.
- **The game's own PauseMenu actions are not wired.** RETURN TO HUB,
  ABANDON ZONE… and QUIT GAME say so when pressed; ABANDON ZONE's
  confirmation is not shown. RESUME closes the menu.
- **Some options do nothing in the menu.** Field of view, sensitivity and
  invert show their real values, but there is no player here for them to
  act on.
- **Long names are cut short with "..." in the key windows and module
  rows.** The inspection window always has the whole name.
- **The miniature is MapFace's own** (rooms, tags, frames): its art is not
  part of this pass.
- **Renderer light leak.** The renderer lets the miniature's light fall on
  the Map's and Journal's walls. Their pale surfaces are toned for it, as
  in the studies.

To regenerate this folder's images from source (1280 × 720 stills, then
the close-ups, then the tour):

    tools/menu_proto/stills.sh <dir> 1280x720 "closeup_*"
    python3 tools/menu_proto/closeups.py docs/art/review/hybrid_checkpoint_2026-09-27 <dir> <out>
    tools/menu_proto/capture.sh <out> cap_10_tour
