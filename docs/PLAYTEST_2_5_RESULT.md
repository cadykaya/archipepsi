# Playtest 2.5 — the authored-art A/B, CLOSED

**Closed 2026-08-30 by owner verdict.** The controlled comparison between
the pre-art and post-art Zone 1 is finished. This is the record.

`docs/PLAYTEST_BASELINE.md` is the operator page for *running* it. This is
what it *found*.

Everything under **MEASURED** is a number the machine produced.
Everything under **INTERPRETATION** is a reading of those numbers and
should be argued with, not cited.

---

## 1. The control held

| | |
|---|---|
| Zone digest | **`98e08663ce6b3b7a`** — identical pre- and post-art |
| Rooms / Checks / value | 23 / 15 / 921 |
| Enemies | 41 |
| Theme / target | `neon_transit` / Bomb Rush Cyberfunk |
| Post-art commit | `30b924b`, tree clean, Windows AMD64 |
| Generator diff | `git diff` over `bridge/`, `apworld/`, `godot/scripts/`, `Makefile` was **EMPTY** |

The level could not have moved, and the digest confirms it did not. **The
A/B is valid.**

---

## 2. MEASURED

### 2.1 Where the content is

- **832 of 921 content points — 90.3% — sit in rooms that hold a Check.**
- The eight corridors carry **89 points between them**, and three of them
  carry **zero**.

Predicted at 89% from six synthetic Zones before the run
(`SOLUTIONS_CATALOGUE.md` design 1). The played Zone came in at 90.3%.

### 2.2 Where the time went

| | rooms | seconds | share | s/point |
|---|---|---|---|---|
| First six rooms | 0–5 | 679.7 | **77%** | 2.81 |
| Last seventeen | 6–22 | 204.8 | 23% | **0.302** |

Whole run: 884.5 s (14m 44s), 1 death, 0.8845 s/point.

Room 3 is a corridor worth **6 points that took 125 seconds**. Room 1 took
180 s.

### 2.3 Combat

- **6 encounters, 32 seconds total.** Median 6 s, longest 9 s.
- Against **41 enemies in 13 arenas, every one `kill_all`**.
- The Zone's set-piece — room 13, a 26 × 24 arena with 7 melee, 1 brute
  and 4 ranged, value 121 — took **20.3 seconds**.

### 2.4 What fifteen Checks produced

- 15 Checks → **5 components and 10 stat bumps**.
- Four `Fresh Rep` upgrades (`force +2` each), three `Spear of Justice`
  (`damage +4`), three `Warp Whistle` (range/cooldown).
- **Two of four Echo slots were empty at the finish** (`echo_b`,
  `utility`).
- Text mismatch: the item named **`REP`** produced the description
  *"The same Fresh Rep, stronger. Mk 5."*

### 2.5 What the authored fixtures exposed

Four engine facts, none of them regressions — all bit-identical to the
pre-art run:

| | measured |
|---|---|
| **Direction** | `OmniLight3D` sits at `height − 0.3`; the ceiling underside is `height − 0.2`. A bulb 0.1 m from the ceiling, radiating up as hard as down |
| **Spacing** | an arena places exactly 3 lights of range 16/16/18 m regardless of size; greeble signage sits 0.2 m below them at a random z with no deconfliction |
| **Leakage** | `light.shadow_enabled = false`, so light passes through walls. An 18 m light reaches through a 5 m connector into the next room |
| **Mounting** | housings attach unconditionally. `platform_path` hangs them **1.85 m** below its ceiling; `tower` hangs them mid-shaft |

### 2.6 What the authored projectiles did

| | pre-art (procedural) | authored |
|---|---|---|
| straight | elongation **4.92** | 1.47 |
| falling | **2.20** | 1.52 |
| lobbed | **0.74** | 1.31 |

`straight` and `falling` matched to within **0.01 m in every axis**; the
manifest declares both as `[0.44, 0.44, ~0.29]`. Measured
`tinted_meshes=0` — `projectile_visual()` returns the authored scene
without applying the source-world tint, so provenance colour was lost.

**Neither was caught by a test**, because
`_the_three_projectiles_read_apart_in_silhouette` measures
`ProjectileSilhouette.profile()` — the *procedural* builder — not the
authored scenes that shipped.

---

## 3. INTERPRETATION

**The pipeline is proven. The art is not the bottleneck.**

- **PIPELINE: PASS.** Authored art travels Art → content pack → both
  validators → Production → runtime without moving gameplay. That was the
  question the A/B existed to answer.
- **FIXTURES: KEEP.** A mild visual improvement, and a large diagnostic
  one. §2.5's four findings are placement-contract gaps, not reasons to
  reject the assets.
- **PROJECTILES: REJECTED.** Reverted to `review: "pending"` in `5f1435f`.
  Assets and Art-side source preserved for redesign.
- **F3 room shells: DEFERRED.** No longer an A/B gate. Their placement and
  topology contracts are ordinary later development.
- **Gameplay freeze: LIFTED.**

**The recurring shape, four times over:** the generator places light
*sources*; authored art assumes it places light *fittings*. Grey boxes
made no promises, so no contract was ever written. Six small housings
surfaced four missing rules — a reasonable prior for what nineteen room
shells would surface.

**The load-bearing reading of §2.1–2.3.** The back half is the honest
window: by then the player had stopped photographing and was simply
playing. At 0.302 s/point a 921-point Zone is roughly **4.6 minutes** of
normal play against a 40-minute target, with **32 seconds of combat** in
it. The front six rooms are conversation, not gameplay, and should not be
read as pacing data.

This is the accidental identity from `SOLUTIONS_CATALOGUE.md` made
visible:

> one Check ≈ one content-heavy room ≈ one unit of gameplay

Nine tenths of the content is stapled to Check pedestals; the remaining
tenth is corridors crossed in five seconds. **Better fixtures on an empty
room are a better-lit empty room.**

**Therefore the next production priority is not art and not the runtime
migration.** It is breaking the relationship between Check count and
player activity.

---

## 4. Still open, recorded here so it is not re-derived

Found during the run, none of it acted on:

1. The Echo Lab's jump gap **is not a hole** — rays at every x hit solid
   floor. `_carve_gap()` builds lip strips, a buried void marker and a
   recovery trigger, but never removes the base slab.
2. Those lip strips are **coplanar with the floor** (both top faces at
   y = 0.00).
3. The Lab doorway has two 0.2 × 0.2 coplanar patches where the corridor
   side walls butt the lintel plane at y = 3.20.
4. The Hub's procedure body is `HORIZONTAL_ALIGNMENT_LEFT` anchored at the
   board's **centre**, so it starts mid-board and overhangs 0.73 m.
5. `_no_hub_sign_is_wider_than_the_board_it_is_on` does not do what its
   name says — it compares width against a single global constant and
   never checks position.
6. Connector seams z-fight: `CONNECTOR_WIDTH` is 4.0 and the schema's
   minimum corridor width is also 4.0, so their side walls are exactly
   coplanar at x = ±2.0.
7. The launcher's `cmd /k` leaves the bridge running after the game
   closes; a relaunch can silently reuse a stale campaign. This put the
   owner on the wrong Zone twice.
8. The launcher never verifies the player is standing in front of the
   **baseline** Zone before they enter.
9. Committed `.png.import` files are not in their settled state, so
   Godot rewrites them on first render and the updater refuses to pull.
   The updater already special-cases `project.godot` for exactly this.
