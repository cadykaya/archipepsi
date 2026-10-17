# The Shunter's look: seven variants and a control, at gameplay distances

*Arty — 2026-10-17*

**Status: a VARIANT SHEET, disposable. Nothing is approved. For Skyiah to pick from after she has played the fight. Stopped.**
- There is **no production model**. The 2026-10-09 rule stands: no model until the combat is proven fun.
- These are blocks and flat colours, written outside `assets/`, on the art branch `claude/archipepsi-art-shunter-look-2026-10-17`.
- The sheets were sent to Skyiah in chat and are **not committed**, to save git space (her rule, relayed by Condi, 2026-10-17). `tools/shunter_looks.sh` regenerates them. `docs/art/review/shunter_look_2026-10-17/` holds the README and every number.
- Nothing of Prod's was edited, and `integration/unified-1` was not touched.

**The brief.** Skyiah, relayed by Condi on 2026-10-17 and confirmed by the owner in this session:
- about seven variants, plus the current graybox / pose-study B as a labelled control;
- one variable at a time;
- the same scale and camera, at gameplay distances, with the numbers beside each;
- the losing options kept in the source;
- inside D-20 rev 2's silhouette and telegraph needs: the horn, the brace with the plough down, the lit lane, the vents;
- with the larger plough and the upward vent flagged on 10-08.

## What was compared

**What every row keeps:**
- **The poses:** pose-study B's table, which D-20 rev 2 adopted.
  - The plough travels 0.37 m. That is the "larger plough" of 10-08, already part of B.
  - The horn: a rear-up with the lamps red.
  - The brace: the plough on the deck with its red edge, and the lit lane, 14.3 m along the rush.
  - The recovery: the vents open upward and a warm plume rises. That is the "upward vent" of 10-08.
- **The envelope:** 0.90 × 1.05 × 1.90 m.
- **D-19's colours:** red only for hostile, amber points for work, warm white for vulnerable. No orange, no green on the body, no yellow-and-black.

**What changes, one thing per row:**

| Row | One variable, against C0 |
|---|---|
| **C0, CONTROL** | pose-study B as it stands: three brow lamps, a flat plough, two vent flaps, piston legs, pale with a small dark lane plate |
| L1 | **plough shape:** a V-prow, two half-plates meeting forward |
| L2 | **plough lip:** a bright bare-steel band across the plough's foot |
| L3 | **lamps:** one 0.60 m bar for three lamps, as Prod's blockout has it |
| L4 | **vent:** one central stack whose cap lifts 0.25 m, for two flaps |
| L5 | **hull:** 8 cm lower and 20 cm longer, a tug |
| L6 | **legs:** reverse-knee for straight pistons |
| L7 | **livery:** two-tone, pale over a steel skirt, with the lane number large on the flanks and the plough's back |
| **R, REFERENCE** | Prod's graybox as it is in `unified-1`: his dimensions and dark colours, posed by the same table. A replica in the maquette, not his scene. |

**Where it was photographed.**
- Each pose stands alone in Crossing D's empty yard, at the 10-09 pose study's spot.
- It is rendered on the game's own renderer (Forward+) at its own 90° view, in a read-only Production checkout.
- The cameras are the pose study's:
  - **F20:** front, 20 m, where it notices you.
  - **F14:** front, 14 m, the rush reach.
  - **S8:** side, 8 m.
  - **R6:** rear quarter, 6 m, where a sidestepped player stands.
- **One correction:** F20 is 1.2 m east of the 10-09 spot. There, a yard column beside the camera hid half the pose, in both studies.
- Crops are enlarged nearest-neighbour, so nothing is invented.

**The numbers** are counted in grey, inside each crop, wherever a pixel moves by more than 24 grey levels:
- **For work:** the silhouette, the pixels that differ from the empty yard.
- **For the other states:** the pixels that differ from the same look's work frame, that is, how loudly the state reads.
- The brace is measured without its lane, because the lane is the same in every look and would swamp the body's change. The sheets still show it with the lane.

## What it shows

Pixels changed, with the change against C0 in brackets:

| | Horn, 20 m | Horn, 14 m | Brace, 14 m | Recover, front 14 m | Side silhouette, 8 m | Recover, side 8 m | Recover, rear 6 m |
|---|---|---|---|---|---|---|---|
| **C0** | 105 | 211 | 633 | 241 | 3,088 | 1,699 | 4,470 |
| L1 V-prow | 104 (−1%) | 212 (0%) | 644 (+2%) | **315 (+31%)** | 3,180 (+3%) | 1,720 (+1%) | 4,501 (+1%) |
| L2 lip band | **133 (+27%)** | **276 (+31%)** | **801 (+27%)** | 248 (+3%) | 3,092 (0%) | 1,706 (0%) | 4,472 (0%) |
| L3 one bar | 101 (−4%) | 205 (−3%) | 639 (+1%) | 243 (+1%) | 3,091 (0%) | 1,701 (0%) | 4,497 (+1%) |
| L4 stack | 99 (−6%) | 207 (−2%) | 627 (−1%) | 277 (+15%) | 3,105 (+1%) | **1,844 (+9%)** | **4,662 (+4%)** |
| L5 low hull | 99 (−6%) | 209 (−1%) | 588 (−7%) | 268 (+11%) | 3,013 (−2%) | 1,643 (−3%) | 4,320 (−3%) |
| L6 reverse-knee | 107 (+2%) | 213 (+1%) | 633 (0%) | 251 (+4%) | 3,204 (+4%) | 1,750 (+3%) | 4,492 (0%) |
| L7 two-tone | 91 (−13%) | 183 (−13%) | 576 (−9%) | 152 (−37%) | **2,312 (−25%)** | 1,990 (+17%) | 4,632 (+4%) |
| R Prod's graybox | 75 (−29%) | 206 (−2%) | 530 (−16%) | 242 (0%) | 3,957 (+28%) | 1,340 (−21%) | 3,067 (−31%) |

**Readings:**
- **L2, the bright lip band, is the one change that makes the telegraphs louder everywhere they matter.** The horn reads +27% at 20 m and +31% at 14 m, and the brace +27%, at no cost to the silhouette. The band rides the plough's lip, so the lip's travel, from 0.48 m when it rears, down to the deck when it braces, is drawn in the brightest value on the body. The travel that carries the state becomes the easiest thing to see.
- **L4, the lifting stack, makes "punish now" read further round the machine:** +9% from the side and +4% from behind. It costs a little on the horn.
- **L1, the V-prow, gives the strongest front read of the recovery (+31%)**, because the angled halves show more of their face when folded high. It changes nothing else much, and it adds a clear "this end is the ram" shape.
- **L3, Prod's single bar,** reads the same as three lamps (within 4%). Either is fine; it is a matter of taste.
- **L6, reverse-knee legs,** change the read by under 5%. It is a pure style choice.
- **Watch out for L5, the low hull.** Its brow drops behind the raised plough, so **the red horn lamps disappear from the front at 20 m** (see `SL1`), and the brace is 7% weaker.
- **Watch out for L7, the two-tone livery.** The steel skirt merges with the grey yard, so the **side silhouette shrinks by a quarter**, and the horn and brace weaken by 9–13%. The 10-08 finding stands: the pale livery is what separates the class.
- **R, Prod's dark graybox,** has the biggest silhouette, dark on a light yard. But **every telegraph is weaker:**
  - horn −29% at 20 m;
  - brace −16%;
  - vents from behind −31%.

  When the art model comes, the pale livery should carry its telegraphs better than the graybox does. His graybox is right for testing the fight. It is not a vote on the colour.

**If it helps the choice** (a suggestion, not a decision): **L2 + L4** add telegraph read where the fight needs it, without costing silhouette, and **L1** is worth considering for identity. **L5 and L7 cost reads** and are better left out. L3 and L6 are taste. The pick is Skyiah's, after she has played the fight.

## Not done, on purpose

- No production model, no rig, no textures, no budget, and no asset in `assets/`.
- No change to D-20's timings, colours or poses.
- The states Dess's D-20 marks as placeholders (docked, tend, wall crumple, heavy jolt, death) are not studied here.
- The real arena, the Freight Bay, is on `unified-1`, which is being rebuilt. The same source can re-shoot it there later.

## How it was made (reproducible)

```
tools/shunter_looks.sh <read-only Production checkout with Crossing D> WORK OUT
  # tools/blender/study_shunter_looks.py   the 9 x 4 maquettes (+ lane-less braces)
  # tools/crossing_capture/shunter_looks.py specs, crops, numbers, sheets
  # tools/crossing_capture/dcap.gd          the yard photographs (copied in, parse-checked, removed)
```

The losing options stay in `study_shunter_looks.py`, one flag each, so any combination can be built and shot again.
