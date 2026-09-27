# Track A2: the interactive hybrid — original station hardware, kept alive by Epsilon

*Arty*

**Branch `claude/archipepsi-art`, PR #5. The approved hybrid is now
interactive, in the isolated menu prototype, for your hands-on review. I
have stopped here.**

- It is not final hands-on acceptance, and not approval for Production
  integration.
- Nothing is integrated, and no Production-owned file was edited.
- It reuses the prototype's own behaviour and data; there is no parallel
  menu logic.
- The four studies (`8b13aa7`), the hybrid stills (`94e219d`) and the
  inventory pass (`91e5d3f`) are safe. The studies re-render pixel for
  pixel.

**In this archive:**

| Item | What it is |
|---|---|
| `build/menu_proto/` | **Run this.** The standalone prototype for Godot 4.5.x. `RUN.md` has the launch line and every control. |
| `review/tour/cap_10_tour.mp4` | **The one tour:** 32 s across all four walls, with the menu's own sound. `cap_10_tour.png` is its marked moments. |
| `review/closeups/fix_1_settings_feed.png` | Refinement 1: Epsilon's feed, before and after, at 1:1. |
| `review/closeups/fix_2_readability.png` | Refinement 2: the quieter words, before and after, at 1:1, with their contrast. |
| `review/README.md` | **The review:** what to try with your hands, what changed from the stills, the motion and sound as built, the evidence, and the limits. |

## What was built

| Part | As built |
|---|---|
| **The harness** (B) | One laced trunk round all four walls and every corner. Each wall's title is a flag on it. |
| **Equipment** (C + D) | The cabinet's inspection window, over a six-position key selector and the brass bus. D's rack is grafted into the cut-down old bay. |
| **Equipment states** | **Seated** is equipped, and its window says ON RMB. **Pulled** is inspected. A preview says **PREVIEW · NOT SENT** on its module, and PREVIEW on the key's window. |
| **Settings** (D) | Three salvaged boards, joined; the rack's ribbon lands on the phenolic one. Production's own options, ranges, steps and words. |
| **Settings, around the options** | RESUME closes the menu. Review controls are on a plate of their own. Epsilon is his one point in the machine: not a slot, a meter or a setting. |
| **Journal → Map** (B) | Runs, flags and a focus tag. The focused finding's ivory link is laced along the harness, round the corner, and down into the Map's riveted port, where the guide carries on to the passage. The Map's detail is a warm tag. |
| **Sound** | A small cue bank: moves, detents, list ends, turns, preview and undo, refusals, values. Reduced motion leaves it alone; MASTER VOLUME sets it. |

**The two refinements:**
1. **Epsilon's feed.** It now runs down the board's empty margin into a
   terminal in its empty foot. It crosses no value and no control, and a
   test checks that on the layout itself.
2. **The quieter words** are a step brighter: the comparison's labels,
   old values and history, and the Journal's unfocused entries and notes.
   Colours only, no sizes. The hierarchy holds.

## What you asked to keep, and where it is checked

| Kept | Checked in |
|---|---|
| Equipped, inspected and previewed, clearly distinct | `test_hybrid`: each state's window words, the pulled module, the readout's kicker |
| Readable at once when the selection changes | `test_hybrid` and `test_more`, mid-flight in rapid selection. The readout already reads the new item; no word is squashed; there is one readout. |
| Keyboard, mouse and pad | `test_inputs` (every prompted binding), and `test_hybrid` (Settings by all three) |
| Stable targets; the whole list reachable | `test_hybrid`: the rack's last item by keyboard, wheel, click, right stick and d-pad; the Journal's longest column to its last entry; hover, click and key changes move no target |
| The selector through ordinary input | `test_hybrid`: ↑ ↓, a click on a key, the wheel; nothing drags |
| Empty keys; consumable counts | `test_hybrid`: MMB, C, Q (2/3 and 2/2), ALWAYS ON |
| Map travel keeps the view | `test_core` |
| The journal follow, framed, with a way back | `test_inputs` and `test_hybrid` |
| Reduced motion, the same information and actions | `test_core`, `test_more` and `test_hybrid`: cuts, and the cues still play |
| Page turns; device switching | `test_core` and `test_hybrid` |

## Evidence

| Scope | Status |
|---|---|
| Implemented | `tools/menu_proto` (`parts.gd`, `cues.gd`, the shell, the four faces, the link) |
| Exercised by scripted input through the real input path | **434 checks in 4 tapes pass.** `test_hybrid` (206) is the new layout's own. `test_core`, `test_inputs` and `test_more` (228) are ported by intent, and none was dropped; the README maps each changed check. Also the tour and the close-up stills. |
| Hands-on | **Not done.** |

## For Production

- **A raw field name in the data.** Magic Meter's Mk II history note is
  `+40 max_value`. The face has no underscore, so the prototype prints
  `+40 MAX VALUE`, and says so.

## Stopping point

Try it with your hands, and tell me what to change. Nothing moves toward
Production until you say so. There are no watchers, no subscriptions and
no scheduled check-ins.

To rebuild everything here from source:

    tools/menu_proto/stage_build.sh <dir>
    tools/menu_proto/test.sh
    tools/menu_proto/stills.sh <dir> 1280x720 "closeup_*"
    python3 tools/menu_proto/closeups.py docs/art/review/hybrid_checkpoint_2026-09-27 <dir> <out>
    tools/menu_proto/capture.sh <out> cap_10_tour
