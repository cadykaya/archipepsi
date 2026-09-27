# Track A2: four direction studies — DIY Echo electronics

*Arty*

**Branch `claude/archipepsi-art`, PR #5. These are four visual directions
for your selection. I have stopped here.**

- Nothing is integrated, and no Production-owned file was edited.
- Nothing here opens 0.5, Track C or Track E.
- **The checkpoint you asked me to keep is safe.** The inventory pass,
  build `66e18b2`, delivered at `91e5d3f`, is untouched. The studies live in
  their own review scene. The prototype gained one additive caption hook,
  and its 225 checks still pass.

**In this archive:**

| Item | What it is |
|---|---|
| `review/00_compare_equipment.png` | **Start here.** The four Equipment screens side by side, in the same state. |
| `review/00_compare_overviews.png` | The four overviews, one above the other. |
| `review/README.md` | **The notes.** For each direction: what is distinct, how selection and a page turn move, and the main usability risk. Also what stays fixed, the evidence and the limits. |
| `review/<A–D>_0_overview.png` | Each direction's four walls as one device, with the Journal → Map link marked where it rounds the corner. |
| `review/<A–D>_1_equipment_normal.png`, `_2_equipment_stress.png`, `_3_map_detail.png` | The three required screens, at 1280 × 720. |
| `review/<A–D>_4_journal.png`, `_5_settings.png` | The rougher studies of the other two walls, at 1280 × 720. |
| `review/<A–D>_6_motion.png` | The annotated motion frames: one press of DOWN (before and after), and two page turns. |

## The four directions

**A — Patchbay / signal bench.** Three instruments stand on a bench. The
focused key's cord arches from RMB's jack to the module in it, and the
readout hangs under that arch, fed by a test lead from the inspected
module. The Journal's cord rounds the post into the Map's bezel.

**B — Routed harness / cable loom.** There are no panels. One laced trunk
runs round all four walls, and everything hangs from it: the titles are
flag labels, and the readouts are hung tags. On Equipment, the focused
key's branch runs round the modules that fit it, and ends in the tag. It
is the strongest "one device" of the four.

**C — Relay cabinet / breaker logic.** A top and bottom split: a wide
inspection window above, and a key selector and card rack below, with a
brass bus between them. The card on RMB is seated; the card being read is
pulled. Every physical state is interface data.

**D — Salvaged Echo workbench / prototype board.** Irregular boards overlap
on standoffs. The inspected module is lifted over the main board, with its
connector edge facing RMB's outlined place. The spares tray leaves empty,
labelled slots for the modules that are out.

The notes for each direction are in `review/README.md`. The same file lists
the elements that would combine, in case you would rather take parts than
a whole direction.

## What you asked for, and where it is

| Asked | Where | Evidence scope |
|---|---|---|
| Four distinct directions, each with its own organizing idea and silhouette | A is a triptych under an arched cord; B is an open board hung from one trunk; C is split into window above and mechanism below; D is overlapping boards with a lifted module | implemented; judged by eye, mine only |
| For each: Equipment normal, Equipment stress, Map with detail | `<d>_1`, `<d>_2`, `<d>_3`, at 1280 × 720 | scripted stills |
| A compact four-face overview with the Journal → Map link | `<d>_0_overview.png`, and `00_compare_overviews.png` | composed from scripted stills |
| Individual screens at gameplay size | 1280 × 720 PNGs, text at the prototype's own sizes | scripted stills |
| A note for each: what is distinct, the motion, the risk | `review/README.md` | written |
| A few annotated motion frames; no videos | `<d>_6_motion.png` | scripted stills with review marks; nothing animates |
| Comparable finish; the same content | the same sample, states, comparison, map place and link in all four; `00_compare_*` | by eye |
| One modest zip with clearly named loose images | this archive: 30 images | — |
| Keep: key / equipped / inspected; truthful previews; comparisons; stable targets; readable text; map context; follow versus travel; reduced motion | every direction keeps the prototype's words, controls and prompt line. The notes describe follow versus travel and reduced motion for each | implemented as stills; not interactive |
| Circuitry must not change meaning | no wiring task; the Map's miniature is the prototype's own, and nothing in its window is restyled; the link is always a neutral colour, never a circuit colour; no invented sockets, slots, capacity or states | by eye; C's indicators checked against the data |

## Evidence and limits

| Scope | Status |
|---|---|
| Implemented | `tools/menu_proto/studies/`: an isolated scene, `study.tscn` with `study_main.gd`; the shared words and geometry, `study_dir.gd` and `study_geo.gd`; the Map, `study_map.gd`; the four directions, `dir_a.gd` to `dir_d.gd`; and the render, compose and stage scripts. |
| Exercised by scripted input through the real input path | **None.** The study scene reads no input. |
| Hands-on | **Not done.** |

- **Motion.** It is shown as stills and described. The study scene does not
  animate.
- **Journal and Settings.** These are rougher, as allowed.
- **C's rack.** It shows 9 of the 13 items, with "4 MORE BELOW"; the
  prototype's own rail also scrolls. The other directions show all 13.
- **Lighting.** The stills' renderer ignores a light's cull mask, so the
  miniature's light also falls on the Map's wall, and at a glancing angle
  on the Journal's. Pale surfaces on those two walls are toned down to
  compensate. This is a correction for the stills only.
- **The Map's frame.** Every direction keeps the prototype's own wall round
  the Map's window. An early version of the study scene dropped it, and the
  miniature showed through above the window.

To regenerate every image from source:

    tools/menu_proto/studies/stage.sh docs/art/review/echo_device_studies_2026-09-27

## Stopping point

The four directions are delivered. Choose one direction, or specific
elements that work together, and I will take the deeper implementation from
there. Until then nothing further is started. There are no watchers,
subscriptions, heartbeat or scheduled check-ins.
