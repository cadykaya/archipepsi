# Batch 044's triad and terminus: the presentation pass, as seven variants and a control

*Arty — 2026-10-17*

**Status: a VARIANT SHEET, disposable. Nothing is approved, and nothing shipped has changed. For Skyiah to pick from. Stopped.**
- **The committed rooms are untouched.** `assets/models/batch044/shells/*.glb` and `manifest.json` are byte-for-byte what they were. Every variant, the control included, was built into scratch by a new option, `build_junctions.py --presentation=… --out=…`, which refuses to write under `assets/`. The plain build still writes the exact committed bytes; that was checked, and the runner checks it again on every run.
- The sheets were sent in chat and are **not committed**, per the git-space rule (Skyiah, relayed by Condi, 2026-10-17). `tools/batch044_presentation.sh` regenerates them. `docs/art/review/batch044_presentation_2026-10-17/` holds the README and every number.
- **The rooms themselves are still PROPOSALS** (AF 1131). Whether they are in the release's Crossings is Condi's question 3, still open. This pass is the next art task named in AF 163–168, done as variants, so whichever answer comes back costs nothing.
- Nothing of Prod's was edited, and `integration/unified-1` was not touched.

## The problem it answers

AF 163–168: the cross had the presentation pass on 2026-09-13. The triad and the terminus have **not**, *"and their surfaces carry the same defect the cross's did — the block painted in the room's architecture material, so it reads as corridor wall."*

In these two rooms the "block" is the **corner fills**: the solid mass that turns a square hall into a junction (four in the triad, two in the terminus). They are floor-to-roof boxes in `wall`, so the triad's spine and the terminus's approach read as a corridor between two walls.

## What was compared

**Every variant keeps:**
- the plan, the doors, the sockets, the volumes and the floor;
- the theme and its four textures, with no new colour;
- the same cameras, which are `furnished_view.gd`'s existing shots, unchanged;
- the same stamped preview: props only at the points the shell declares, red capsules standing in for occupancy.

**What changes, one thing per tile.** Each part is one of the cross's stage-3 changes (`2026-09-13-presentation-study.md`), refitted to a room whose mass is its fills rather than a free-standing plant.

| Tile | One variable, against the control | Fitted how |
|---|---|---|
| **CONTROL** | the rooms as built and committed | — |
| 1 SKIN | the fills in **`trim` plating** instead of `wall` | the cross's plant skin |
| 2 BASE | a **bund**, 0.30 m proud and 0.40 m tall, along every face a fill turns to the floor, wrapped round its corner | the cross's bund |
| 3 TOP | the fills **step back above a head course**: triad at 4.8 m, set back 0.9 m; terminus at 4.0 m, set back 0.5 m | the cross's hood. The terminus's set-back is smaller so its mouth header still meets the face above it. |
| 4 FACE | the cross's **desk, hatch and pipe heads**: triad on the west side of the spine; terminus on both faces of the approach | the cross's working face, same parts and same offsets |
| 5 BOARD | **gauge boards**, `readable`, at 2.05 m. Triad: on the north fills' south faces. Terminus: on the end wall, and on the east fill's chamber face. | the cross's gauge board and placard |
| 6 TRUNKS | **overhead lines** that do what the room does. Triad: they come in over the entry and **split**, one on to the north door and one east to the branch. Terminus: they come in and **stop** in the recess head. | the cross's trunk lines, clear of every header and under every soffit and beam |
| 7 ALL | 1 to 6 together | — |

## Checks: every variant passes them all

- **Collision**: `roomcollision`'s exact, supports and standable asserts pass for all 16 builds, 8 variants × 2 rooms.
- **The route walk**: `route_walk.gd` runs a Production-sized body through every route in the triad and the terminus, with the committed cross linked in. **Every route completes, with zero jumps, in every variant.** The triad routes are entry to exit, to the east branch and to the west bay; the terminus routes are to the prize and to the west door.
- **The control is byte-identical** to the committed GLBs (`cmp`).

**Budget, in triangles:**

| | Control | All |
|---|---|---|
| Triad | 672 | 924 |
| Terminus | 516 | 684 |

The cross is 948.

**Floor given up.** All parts are off the routes; this is the narrowest clear width.

| | Control | Base | Face | All |
|---|---|---|---|---|
| Triad spine | 12.0 m | 11.4 m | 9.75 m at the desk | 9.45 m |
| Triad arms | 7.0 m | 6.4 m | — | 6.4 m |
| Terminus approach | 8.0 m | 7.4 m | **5.75 m** at the desk | **5.45 m** |

## What it shows

**How much of the view each part changes,** as a share of the frame whose grey moves by more than 24 against the control. This measures how **loud** a part is from that spot; it does not say whether the part is better. That judgement is Skyiah's.

| View | Skin | Base | Top | Face | Board | Trunks | All |
|---|---|---|---|---|---|---|---|
| Triad: the approach | **27.7%** | 2.0% | 3.9% | 3.2% | 0.8% | 2.9% | 28.7% |
| Triad: the decision point | **30.6%** | 1.7% | 5.0% | 4.0% | 0.7% | 0.0% | 28.5% |
| Terminus: from the door | **38.1%** | 3.8% | 4.7% | **12.9%** | 0.3% | 0.9% | 38.2% |
| Terminus: the open branch | **8.6%** | 0.1% | 1.1% | 0.0% | 4.7% | 0.0% | 11.7% |

**Readings:**
- **SKIN is the fix the frontier names, and it carries most of the change by itself.** Plated, the fills stop being the room's walls and become **masses standing in the room**. The triad reads as a floor between four plant blocks, and the terminus approach as a way in between two. It is also the **loudest** part: about a third of every view becomes ribbed plating.
  - That runs against the direction of the 2026-10-08 noise pass. Its targeted variant quietened the ceilings and the non-critical stairs and kept the loud surfaces for what matters.
  - So it is worth judging at full size, not only in the thumbnails.
- **TOP is the cheapest structural read.** About 4–5% of the view changes. The masses get a top, so they stop running flat into the ceiling. It is clearest at the triad's decision point.
- **BASE is small**, at 2–4%. It reads as a foot where the floor meets the mass, and it costs 0.30 m off each face.
- **FACE is a good fit in the triad and a poor one in the terminus.**
  - In the triad it marks the west side of the spine as the worked side, as on the cross, and the spine stays 9.75 m wide.
  - In the terminus it squeezes the 8 m approach to **5.75 m**, and the desk fills the lower left of the door view: 12.9%, the biggest change after the skin.
  - The desk's stencil also reads **sideways** at 1 m. This comes from the world-axis projection the whole library shares; the cross's desk carries the same projection.
- **BOARD barely registers from the door** (0.3–0.8%), because the boards are 15–18 m away. It reads clearly where you stand near it: 4.7% in the terminus's open-branch view, and both boards read **the right way round** there.
- **TRUNKS** in the triad draw the split **overhead** from the door (2.9%): one line goes on and one turns to the branch. That is the room's job stated without colour. They are out of frame at the decision point (0.0%). In the terminus the lines are thinner (0.35 m, under a 5.0 m soffit) and register less (0.9%).

**If it helps the choice** (a suggestion, not a decision):
- **TOP + BASE + TRUNKS** for both rooms, with **SKIN** if the noise cost is acceptable to her. Together these are the cross's recipe, minus the parts that don't fit these rooms.
- **FACE** for the triad only.
- **BOARD** is optional.

The pick is Skyiah's. Any combination is one run (`--presentation=top,base,trunks`), and the chosen one is then built into `assets/` by the normal build and checked again.

## Not done, on purpose

- **No shipped asset changed.** The default build is unchanged and byte-identical.
- **No change to the plan, the doors, sockets, volumes, surfaces or arrival regions.**
- **No new colours and no new textures:** the theme's `wall`, `trim` and `accent` only.
- **The cross is not touched.**
- **The desk's sideways stencil is not fixed.** It is the library-wide projection rule, already recorded on 2026-09-13 as a decision above this pass.
- **Stills are stills.** They show framing and legibility in the stamped preview harness, on its `opengl3` renderer, the same one as the cross's stage 3. They do not show combat visibility or motion, and they are not a playtest.

## How it was made (reproducible)

```
tools/batch044_presentation.sh WORK OUT
  # tools/blender/build_junctions.py --presentation=<v> --out=<scratch> --only=triad,terminus
  # tools/content/run_furnished_view.sh <shell> <out> <models>   (new optional 3rd arg)
  # tools/content/run_route_walk.sh <out> <models>
  # tools/content/batch044_presentation_sheets.py   sheets + numbers
```

The parts stay in `build_junctions.py`, one name each (`PRESENT_PARTS`), so any combination can be built and shot again.
