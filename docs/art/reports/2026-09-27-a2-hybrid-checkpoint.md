# Track A2: the hybrid visual checkpoint — original station hardware, kept alive by Epsilon

*Arty*

**Branch `claude/archipepsi-art`, PR #5. This is one hybrid for you to
confirm before the deeper interactive implementation. I have stopped here.**

- Nothing is integrated, and no Production-owned file was edited.
- The four studies (`8b13aa7`) and the working prototype (build `66e18b2`)
  are untouched. The prototype's 225 checks pass.
- The hybrid uses the same sample, states, comparison, map place and
  Journal link as the four studies.

**In this archive:**

| Item | What it is |
|---|---|
| `review/H_0_overview.png` | **Start here.** The four walls as one device. It shows the harness and the Journal → Map link, and the Equipment → Settings transition, both marked and each seen in 3D. |
| `review/H_1_equipment_normal.png`, `H_2_equipment_stress.png` | Equipment, normal and long-name, at 1280 × 720. |
| `review/H_3_map_detail.png`, `H_4_journal.png`, `H_5_settings.png` | The Map, the Journal and Settings, at 1280 × 720. |
| `review/H_6_turn_journal_map.png`, `H_7_turn_equipment_settings.png` | The two joins at full size. |
| `review/README.md` | **The note:** how original and salvaged parts relate, Epsilon's point, and the proposed motion. |

## The hybrid in brief

| Part | Role |
|---|---|
| **B, the harness** | The shared infrastructure. One laced trunk round every wall and corner; the warm titles and tags; the Journal's ivory link round the corner into the Map, over the passage. |
| **C, the cabinet** | Equipment's composition. The inspection window above; the formal key selector and the rack below; the brass bus between them. Seated means equipped; pulled means inspected. |
| **D, the salvage** | Equipment's rack, rebuilt: an adapter plate in the cabinet's cut-down old bay, and a phenolic backplane wired back to the bus through an adapter board. Its ribbon runs round the corner into Settings, which is three salvaged boards with repurposed controls at their real values, labelled by hand. |
| **A** | Retired as a visual treatment. |

## One decision you may want to overrule

The art bible's Style Lock says **"Green means Epsilon. Nothing else may be
green."** So the salvaged boards here are phenolic, black and bare FR4,
instead of D's green. Epsilon's one restrained point, on Settings, is the
only green in the menu. It is near-black plating bursting through a bolted
grey plate, lit from inside through its seams, with one aperture, and the
harness's drop runs through it. Putting D's green boards back is one
constant.

## Evidence

| Scope | Status |
|---|---|
| Implemented | Stills from `tools/menu_proto/studies/dir_h.gd`, an isolated study scene. |
| Exercised by scripted input | **None.** The scene reads no input. |
| Hands-on | **Not done.** |

Motion is proposed in the note, not animated.

To regenerate the images:

    tools/menu_proto/studies/stage_hybrid.sh docs/art/review/hybrid_checkpoint_2026-09-27

## Stopping point

Confirm the composition, or say what to change. The deeper interactive
implementation starts only after that. There are no watchers, no
subscriptions and no scheduled check-ins.
