# Shunter pose study: six states at gameplay distances

*Arty — 2026-10-09*

**Status: a disposable concept study, with recommendations for Prod's later combat prototype. STOP.**
- There is **no production model** and no animation library: blocks and flat colour only, written outside `assets/`.
- G1's art and the station materials are unchanged, and nothing was merged.

**Sources:** Dess's D-19 (`21cc00a4`, the identity the owner approved).
**Her encounter brief does not exist yet.** I searched every branch on 2026-10-09 and her branch is still at `21cc00a4`. So this works from D-19, and anything that waits on her is marked **DESS**.

## What was compared

**One maquette body, D-19's 0.90 × 1.05 × 1.90 m envelope, six states, two variants of the cues:**

| | A: D-19 as written | B: recommended |
|---|---|---|
| Plough | drops 18 cm into the brace | **travels**: lip 0.40 m up when working, 0.48 m when rearing or recovering, on the deck (0.00–0.05 m) when committed |
| Lamps | a cluster under the plough lip | **a bar on the brow**, above the plough |
| Notice | lamps turn red | **rears**: body up 6 cm and nose up 6°, plough highest, lamps red, a horn flash |
| Brace and charge | plough down, red edge, legs splay or gallop | the same, plus nose down 4–6° |
| Miss (**DESS**) | the brace pose, skidded 20° | **nose dug in** (−9°), rear legs off the deck, skidded 20°, lamps dimmed |
| Recover | plough up, rear pack warm white | plough folded high, lamps off, rear pack warm white, **two vent flaps open upward and a warm plume rises** |

**Where it was photographed:** each pose alone in Crossing D's empty yard, in the engine, with **the game's own default 90° field of view** (`player_settings.gd`). So the frames are the pixels a player gets: about 32 px per metre at 14 m and 22 at 20 m. The six views:
- **F20:** the front at 20 m, where D-19 notices you;
- **F14:** the front at 14 m, the rush reach;
- **S8:** the side at 8 m;
- **R6:** the rear quarter at 6 m, where a sidestepped player stands after a miss;
- **H12:** 4.6 m up, about 13 m off;
- **C10:** 10 m off, over a 1.1 m stand-in crate.

Enlargements are nearest-neighbour only, so no detail is invented.

## Findings

**Measured:** the number of pixels that change by more than 24 grey levels from the same variant's WORK frame. Zero means the player cannot tell the state from work, in grey, from that spot.

| View | | notice | brace | charge | miss | recover |
|---|---|---|---|---|---|---|
| Front, 20 m | A | **0** | 145 | 114 | 211 | **13** |
| | B | 57 | 178 | 173 | 271 | 66 |
| Front, 14 m | A | **0** | 526 | 471 | 881 | **57** |
| | B | 236 | 753 | 699 | 1108 | 246 |
| Raised, 13 m | A | **0** | 632 | 479 | 1153 | 176 |
| | B | 288 | 1011 | 974 | 1546 | 537 |
| Over a crate, 10 m | A | **0** | 93 | 37 | 93 | 111 |
| | B | 125 | 83 | 39 | 50 | **458** |
| Rear quarter, 6 m | A | **0** | 2327 | 1929 | 4378 | 2847 |
| | B | 1677 | 2719 | 3327 | 5079 | 4736 |

1. **D-19's lamps under the plough lip are hidden from the front by the plough itself.** A's notice changes nothing from any view, and its work and recover look alike from the front. **Move the lamps to the brow.**
2. **An 18 cm drop is about 4 px at 20 m and 6 px at 14 m.** B's 37 cm of travel is about 8 and 12 px, and with the legs it shows or hides, brace reads clearly at the rush reach. The **red plough edge on the deck** is the strongest single brace cue at range, in both variants.
3. **Notice is the weakest state at range**, even in B: 57 px at 20 m. Three lamps turning red are a few pixels. The rear-up helps, but notice has to lean on the **horn sound** (D-19) and a **brief bright flash**, not on lamp colour alone.
4. **Brace and charge share a silhouette in both variants.** Speed and the leg cycle separate them, so no extra art is needed.
5. **Recovery is where the upward cue earns its place.**
   - A's warm rear pack reads only from behind (R6).
   - From the front it's 13 px at 20 m, and over a crate 111 px.
   - B's plume and open flaps read from **every** view: 458 px over the crate, where the body is hidden, and 537 px from above.
   - Keep both: the rear glow marks the weak point, and the plume announces the window.
6. **The miss skid reads everywhere**: the biggest change in every view. Whether a miss looks like that is **DESS**'s call (§4: overrun, ledges).

Evidence:
- [SH1: front at 14 m](../review/shunter_poses_2026-10-09/SH1_front_14m_rush_reach_x4_DISPOSABLE.png)
- [SH2: front at 20 m](../review/shunter_poses_2026-10-09/SH2_front_20m_notice_x5_DISPOSABLE.png)
- [SH3: side at 8 m](../review/shunter_poses_2026-10-09/SH3_side_8m_DISPOSABLE.png)
- [SH4: the recovery reads](../review/shunter_poses_2026-10-09/SH4_recovery_reads_DISPOSABLE.png)
- [SH5: true scale at 14 m](../review/shunter_poses_2026-10-09/SH5_true_scale_14m_DISPOSABLE.png)

## Recommendations for Prod's combat prototype

**Build it as a code blockout, like your other placeholders,** not from these GLBs: they are disposable. **Four driven parts are enough:**
- **the body**, with lift and pitch;
- **the plough**, with lip height and lean, placed in the world so the lip height is exact;
- **a lamp bar** on the brow, about 0.6 m wide, with colour and energy;
- **a vent**: two flaps, plus a warm light or plume.

Drive them from the enemy's existing state machine with simple tweens. No animation library is needed.

| State (D-19 timing) | Plough lip / lean | Body | Lamps | Extra |
|---|---|---|---|---|
| **Work** (tend / patrol) | 0.40 m / −8° | level | amber, steady, low | legs visible under the raised plough |
| **Notice** (horn, 0.3 s) | 0.48 m / −14° in the first 0.1 s, then hold | +6 cm, nose up 6° | red, bright | a 0.15 s white flash on the brow with the horn. **DESS:** a rear-up on notice is my proposal |
| **Brace** (0.7 s) | drops to 0.03 m / +12° in the **first 0.25 s**, so the drop starts the telegraph | −7 cm, nose down 4°, legs splay | red, steady | the plough's edge goes red; scrape sound (D-19) |
| **Charge** (1.1 s, 13 m/s) | holds 0.05 m / +15° | nose down 6°, gallop | red | sparks along the lip are FX, optional |
| **Miss** (**DESS**) | 0.00 m / +20° | nose dug in −9°, rear up, 15–20° skid yaw | red, dimmed | it reads as lost control. Ledge and wall cases follow Dess's §4 |
| **Recover** (1.4 s) | lifts to 0.48 m / −30° in 0.3 s | −6 cm, nose up 4°, legs buckled | **off** | flaps open by 0.2 s; warm plume and rear glow for the whole 1.4 s, fading in the last 0.2 s. Then back to work over 0.3 s |

**Colour stays D-19's.** Red is the enemy cue, amber means working, and warm white means vulnerable. No orange bands, no green on the body (that's the dock's), no yellow-and-black. Keep the amber lamps **small points**, never a band, so they can't be mistaken for orange-breakable.

**Envelope:** every B pose stays inside 0.90 × 1.05 × 1.90 m, within about 2 cm. Only the recovery plume and the open flaps rise above it, by about 0.5 m. They're light and FX, not collision.

## Waits on Dess (DESS)

These are marked; I haven't decided them:
- what a miss does (overrun distance, the ledge drop, the wall clang versus a skid);
- whether notice gets a rear-up and flash, or the horn alone;
- moving D-19's lamps from under the lip to the brow (it's her spec);
- the recovery plume rising above the envelope;
- how the rear-hit stagger (+0.4 s) looks;
- not studied here: docked, tending, the crate butt, wall impact and death.

Her encounter brief may change any of them.

## Files and checks

- `tools/blender/study_shunter_poses.py`: the 12 maquette GLBs, written to a directory you name, never `assets/`.
- `tools/crossing_capture/shunter_pose_study.py`: the capture specs, and `--crops` for the enlargements.
- The earlier `study_shunter_maquette.py` and `shunter_sketch.py` are unchanged.
- No asset, builder, manifest or station texture changed, and `git status` shows only the files above. Because no generated asset changed, I didn't run the full art check for this pass.

**STOP.** No production model, no merge, no watchers.
