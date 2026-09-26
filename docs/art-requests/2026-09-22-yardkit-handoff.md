# Batch 046 — the Blindside junction: track, docks, the span, the gantry

**Arty**

**To:** Prod (integration) and Dess (selection, where it applies)
**Art head:** this commit, branch `claude/archipepsi-art`
**Fitted against:** Production `claude/archipepsi-0-4-blindside` @ `f404410`

**Every asset here is a CANDIDATE.** Imported and fit-checked; **not**
runtime-bound and **not** owner-approved. Three separate states, and
this delivery claims the first two.

---

## What this is

Batch 045 gave the four 0.4 setpieces their vehicles. This is the place
those vehicles run through: track that reads as track, docks with an
edge, a repairable span that is visibly a drawbridge, and a gantry whose
machinery explains why the control is up there.

Fourteen assets, all at **32 texels/m** — the same architecture band as
Batch 045 and the shells, so nothing in the yard reads as pasted in from
a different game.

| id | metrics | parts | for |
|---|---|---|---|
| `yk_track_module` | 72 tris · 0.50 × 1.00 × 0.30 m · 32.0 texels/m | 5 | A04.1 — one metre of track, tiling |
| `yk_track_pier` | 36 tris · 0.80 × 0.80 × 0.42 m · 32.0 texels/m | 2 | A04.1 — what holds the track up |
| `yk_track_end` | 84 tris · 0.54 × 0.60 × 0.48 m · 32.0 texels/m | 6 | A04.1 — the cut end at the gap |
| `yk_dock_edge` | 72 tris · 1.10 × 7.00 × 0.09 m · 32.0 texels/m | 5 | A04.2 — the boarding edge |
| `yk_dock_buffer` | 48 tris · 0.46 × 0.46 × 0.86 m · 32.0 texels/m | 3 | A04.2 — bollard, clear of the controls |
| `yk_dock_locker` | 76 tris · 0.78 × 1.50 × 0.86 m · 32.0 texels/m | 4 | A04.2 — the limited service furniture |
| `yk_span_beam` | 168 tris · 0.57 × 14.05 × 0.66 m · 32.0 texels/m | 13 | A04.3 — the repairable span |
| `yk_switch_stand` | 60 tris · 0.50 × 1.37 × 0.77 m · 32.0 texels/m | 4 | A04.4 — points and indicator, **candidate** |
| `yk_gantry_head` | 72 tris · 3.00 × 1.38 × 0.70 m · 32.0 texels/m | 5 | A05.1 — the machinery under the platform |
| `yk_gantry_winch` | 76 tris · 1.35 × 1.10 × 1.00 m · 32.0 texels/m | 4 | A05.1 — the machine on top |
| `yk_gantry_anchor` | 72 tris · 3.30 × 1.80 × 1.53 m · 32.0 texels/m | 5 | A05.2 — mounting for the grapple plate |
| `yk_lever_housing` | 84 tris · 0.90 × 0.90 × 0.73 m · 32.0 texels/m | 6 | A05.3 — lever, linkage, service panel |
| `yk_branch_mast` | 96 tris · 0.90 × 1.30 × 1.62 m · 32.0 texels/m | 7 | A05.4/A05.5 — the branch landmark |
| `yk_branch_conduit` | 60 tris · 0.46 × 2.00 × 0.30 m · 32.0 texels/m | 4 | A05.4 — continuity back to the junction |

Source: `tools/blender/build_yardkit.py`. Exports:
`assets/models/batch046/yardkit/`. Evidence:
`docs/art/review/yardkit_2026-09-22/`.

---

## 1 · The measurement, which is the part worth keeping

**`assets/models/batch046/yard_fit.json` is Production's yard, measured
with Production's own `RailPath`.** `tools/content/run_yard_measure.sh`
fetches `rail_path.gd` read-only, rebuilds the rail from the same five
control points `_ready()` lays, and evaluates it.

It has to, because **the gap between S2 and S3 is 14.048 m and no
reading of `railway_scenario.gd` will tell you that.** Three of the five
control points sit on a Catmull-Rom corner; the number only exists once
the curve is baked. A span authored at "about fourteen metres" lands
**48 mm short of the far rail**, and nothing in Blender would have said
so — I sabotaged the builder with exactly that constant and it produced
a clean 14.00 m beam without complaint. `run_yardkit_fit.sh` is the
check that catches it, and it did.

The harness **refuses rather than guesses.** Every constant it needs is
checked up front and a missing one exits non-zero with nothing written.
That is also a repair: the first version raised `push_error` from inside
its getters and carried on with a zero, and sabotage-testing showed it
measuring the deck top at 0.60 instead of 1.00 and reporting success.

**If a constant in `railway_scenario.gd` moves, re-run the measurement
and rebuild.** The builder reads the file; it does not remember.

---

## 2 · Three findings

### 2.1 The gantry column stops 0.40 m short of the platform it holds up

`_gantry()` raises the platform to `GANTRY_Y` **above the rail** — world
3.70, underside 3.50 — and stands a column `GANTRY_Y` tall **from the
floor**, topping out at 3.10. Measured from your own constants.

It is yours to decide; it may well be deliberate, and it is invisible
from above. `yk_gantry_head` spans exactly that 0.40 m with a head
casting and brackets so the load path reads, and `run_yardkit_fit.sh`
fails the asset if it stops being tall enough to close the gap. **If you
extend the column, the harness notices and downgrades the casting to
dressing rather than failing.**

`docs/art/review/yardkit_2026-09-22/gantry_assembly.png` is shot from
below for this reason: from above, the thing the frame exists to show is
behind the slab.

### 2.2 The track stands on nothing

`_track()` lays pieces 0.35 m tall centred on the rail at 0.6, so the
visible track floats between 0.425 and 0.775 over a yard floor at 0.00.
A 0.425 m gap with no ballast, pier or trestle in it. Invisible from
above; the first thing the eye finds from the side.

`yk_track_pier` is exactly that 0.425 m. **How often one is placed is
yours** — every metre or every third both read.

### 2.3 A landmark on the acquisition branch is a waymarker, not a tower

A05.4 asks for one memorable **nonblocking** anchor landmark. I built a
2.2 m mast and the sightline gate refused it, correctly.

Near the viewer the eye-to-ring ray bundle **is at head height** — that
is what "the ray starts at the eye" means. At the walkway's end the
corridor's floor is world 2.80 against a branch deck at 1.00, leaving
1.80 m. **Anything on the branch taller than a person crosses somebody's
view of the ring.**

So `yk_branch_mast` is 1.62 m and the blade is made large instead of the
post tall. That is the measurement choosing, not taste, and it is the
"decorative scaffolding" A05.1 names — caught at build time rather than
in a playtest.

---

## 3 · The two gates, and the fact that both of them were wrong first

Kept in the record because each passed review in my own head.

**The sightline gate** refuses art that stands across the eye-to-ring
line. Its first cut refused anything *above* a per-lateral ceiling —
which is not occlusion. A beam hanging over the sightline stands over
the ring, not in front of it; it failed a legal support stay hanging
2.7 m clear. Its second cut fixed the inequality but stayed flat, in
lateral and height only. `branch_lane()` puts the whole branch **3 m
back along the track** while the gantry sits square on it, so every ray
is a diagonal in plan, and a flat gate refuses a mast standing beside
the walkway. What it checks now is a real overlap in all three axes
against a swept ray bundle.

**The no-route gate** refuses an art-added standing surface within a
jump of somewhere the scenario keeps closed. Its first cut compared
heights alone and refused a waymarker standing **six metres** from the
gantry, because 2.50 + 1.33 clears 3.50 — which it does, straight up,
from a surface nowhere near it. Targets now carry footprints and the
reach is derived from your constants: `2 × JUMP_VELOCITY / GRAVITY`
seconds aloft at `WALK_SPEED` is 4.67 m, the flat case, which is the
generous one.

**A gate that keeps refusing correct art gets switched off, and then it
is worse than nothing.** Both were loosened to fix real bugs, so both
were re-proved afterwards:

| sabotage | result |
|---|---|
| winch raised until it crosses the corridor at lateral 8.55 | **refused**, naming 3.900–7.100 against a bundle of 5.382–6.315 |
| locker moved under the gantry and made 2.4 m tall | **refused**, naming 0.00 m horizontal separation |
| `GAP` hard-coded to 14.0 instead of measured | **refused at import**, 14.000 against 14.048, "0.048 m short" |

---

## 4 · What each asset needs from you

| asset | origin | addressable nodes |
|---|---|---|
| `yk_span_beam` | **the beam's own centre**, which is `RailSpan._body.position` = local (0, 0, gap/2) inside the pivot frame — **not** the pivot | `span_heel` (pivot end), `span_toe` (the end that lands on S3's rail), `span_lamp` |
| `yk_dock_edge` | local x = 0 **is** the line where the deck's outer edge arrives, lateral 2.00; everything grows outward | `dock_lip`, `board_mark_0..2`, `dock_band` |
| `yk_gantry_head` | the platform centre, world 3.70 | `gantry_bracket_*`, `gantry_conduit` |
| `yk_gantry_anchor` | the grapple plate's centre, world 7.20 | `anchor_lamp`, `anchor_collar_*` |
| `yk_lever_housing` | the platform top, world 3.90 | `lever_arm` (drawn mid-throw, not at an end), `lever_lamp`, `service_panel`, `service_hinge` |
| `yk_switch_stand` | floor | `switch_indicator` (two declared positions, no third), `switch_tongue` |
| `yk_branch_mast` | floor | `mast_blade_out` / `mast_blade_back`, `mast_chevron_*` |
| `yk_track_module`, `yk_track_pier`, `yk_track_end` | module centre / floor / module centre | `end_stop`, `end_stop_band` |

### Two declared deviations, rather than discovered ones

* **`yk_track_end` exceeds the track envelope on purpose.** Your track
  pieces are 0.35 m tall and live between 0.425 and 0.775; the buffer
  stop tops out at world 0.905, because a stop level with the rail heads
  is a bump. Still 0.10 below the dock top, and nothing stands on it.
* **`yk_switch_stand` is a candidate in the strict sense.**
  `RailCarrier` runs one path and there is no switchable routing for it
  to report. The indicator has **two** declared positions and the asset
  claims no route, no destination and no third state. A04.4's own rule.

---

## 5 · Evidence

`tools/content/run_yardkit_fit.sh` → `.../yardkit_2026-09-22/fit.json`

```
[yardfit] PASS -- 14 asset(s) imported, kept their parts, and fit the
          MEASURED yard
```

`tools/content/run_yardkit_views.sh` → 18 frames under the shipped
Zone's lighting: each asset alone, plus three that are worth more than
the rest —

* **`dock_assembly.png`** — A04.6's greybox comparison. Your pad, your
  carrier deck box (a darker grey, because the two abut exactly and in
  one flat grey they merged into a single slab) and your receiver post,
  with the authored art on top, in one frame at one scale.
* **`gantry_assembly.png`** — shot from below, showing the 0.40 m.
* **`span_stowed / _travelling / _aligned.png`** — A04.3's three forms
  at the angles `RailSpan` really uses, with both rail ends greyed in so
  "meets both" is something the frame shows rather than something this
  document claims.

---

## 6 · What I am NOT claiming

- **Not runtime-bound.** Nothing consumes these. The presentation-seam
  ask from the Batch 045 handoff still stands and covers `RailSpan` and
  the dock furniture equally.
- **Not owner-approved.** Candidates, pending subjective visual review.
- **No route was added or removed.** The no-route gate checks it, and
  the scenario's own arrangement — S3 on an island, the gantry out of
  reach — is untouched.
- **The dock edge's boarding markers are the weakest element.** At 0.02 m
  proud they read as tonal patches rather than markings in the shipped
  fog. Named here rather than left for you to notice; a decal would
  serve better than geometry, and that is a material question, not a
  mesh one.
- **The along-track placement in the manifest is Art's reading of your
  layout, not a placement instruction.** `stands_at_lateral` and
  `stands_at_along` exist so the gates have somewhere to check against.
  Where these actually go is yours.
