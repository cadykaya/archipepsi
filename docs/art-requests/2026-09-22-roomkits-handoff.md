# Batch 048 — A06, A07, A08: the other three 0.4 rooms

**Arty**

**To:** Prod (integration)
**Art head:** this commit, branch `claude/archipepsi-art`
**Fitted against:** Production `claude/archipepsi-0-4-blindside` @ `f404410`

**Every asset here is a CANDIDATE.** Imported and fit-checked; **not**
runtime-bound and **not** owner-approved.

---

## What this is

Blindside got A03–A05. This is the same treatment for Passing
Platforms, Counterfire Arcade and Unweighted Switch: the structures
that make each room's mechanism legible, fitted to the constants those
rooms run on.

Fourteen assets, all at 32 texels/m. Source
`tools/blender/build_roomkits.py`; exports
`assets/models/batch048/roomkits/`; evidence
`docs/art/review/roomkits_2026-09-22/` (17 frames).

---

## 1 · A06 — Passing Platforms

| id | for |
|---|---|
| `pp_lift_guide` | the vertical carrier's guide and drive |
| `pp_shuttle_guide` | the horizontal carrier's guide and drive |
| `pp_transfer_edge` | the rendezvous edge |
| `pp_call_post` | call, stop, direction |
| `pp_recovery_mark` | the recovery floor |

**The two drives are told apart by MECHANISM, not by colour.** The lift
hangs from a rope with a counterweight in its own channel; the shuttle
is pushed along a screw. A06.1 says the carriers may share manufacturing
language but must not be indistinguishable slabs, and a recoloured pair
would be exactly that.

**Nothing in open space is standable.** A06.2's "decorative cables and
counterweights must not look like alternate climbable routes" is held as
a build-time rule: `assert_no_footholds` refuses any upward face 0.35 m
square standing more than the measured 0.12 m walk-up above the floor.
Whether these are collided is yours; whether they *look* like a way up
is Art's, and that is the rule Art can hold itself to.

**Nothing crosses the edge line.** `GAP` is 0.2 m and it is the room's
central question. `pp_transfer_edge` is exported **as-built** — local
y = 0 **is** the deck's edge, everything grows back onto the deck — and
`assert_stops_at_edge` refuses anything at positive y. Its railing is at
your `RAIL_HEIGHT` 1.10 and `RAIL_THICK` 0.15, not at a height Art
preferred.

**The recovery floor is a landing pad, not a hazard border.** A06.4 asks
that recovery read as intentional accessible space rather than a
visually lethal pit the runtime treats as safe, so it is a bordered
square with a way-back arrow, and the tallest part is 0.03 m — a quarter
of the walk-up limit — so nothing covers the landing surface.

**The patient alternative is preserved.** Nothing on `pp_call_post` says
a carrier is the only way, and there is no label implying a wait is
wasted.

---

## 2 · A07 — Counterfire Arcade

| id | for |
|---|---|
| `cf_gunner_mount` | the emplacement and muzzle mounting |
| `cf_lane_mark` | the bait lane's edge |
| `cf_alcove_frame` | the safe alcove's mouth |
| `cf_shutter_track` | the service shutter's tracks and indicator |
| `cf_release_bolt` | the far release |

**The lane marking reads without colour.** A07.3 says it must not
require colour discrimination alone, so the lane edge is a **ribbed**
band and the safe side is smooth. The difference survives a greyscale
render and a colour-blind player.

**And it does not obscure the shot.** The tallest part is 0.04 m against
a projectile travelling at `RECEIVER_Y` 0.85; `assert_below_shot_line`
refuses anything within 0.25 m of that line. A player reading the path
should never lose it behind dressing.

**The emplacement is built on your envelope, not on a shape I liked.**
The gunner is a `ranged` enemy and `ENEMY_ENVELOPES["ranged"]` is
0.7 × 1.4 × 0.7. The parapet is on the **lane side only**: the back and
flanks stay open, because A07.5 says the alternate completion — killing
the gunner — must not be barricaded by art.

**`muzzle_mount` and `telegraph_face` support your telegraph hook and
decide nothing.** `telegraph_face` sits at the enemy's own collider
centre, the same point `enemy.gd` puts `TelegraphOrigin` on. Art does
not retime the shot or decide where its aim commits.

**The interval indicator is eight named things and no clock.** A07.4's
second sentence is the one that matters — "use the runtime interval as
data; a looping animation is not the countdown authority" — so
`cf_shutter_track` carries `interval_pip_0` through `interval_pip_7`,
one per second of `OPEN_SECONDS`, and **contains no animation at all**.
What lights how many of them, and when, is you reading your own timer.
The fit harness fails the asset if the pip count stops matching
`OPEN_SECONDS`.

**The permanent release is visibly not a timer.** A07.5 asks that the
far release be distinguishable from a briefly powered opening. A timed
shutter counts pips; `cf_release_bolt` shows a **bolt driven home** — a
mechanical commitment that cannot be read as a countdown. `bolt_shot` is
the part with two positions, and there is no third.

---

## 3 · A08 — Unweighted Switch

| id | for |
|---|---|
| `uw_plate_frame` | the HEAVY-class plate, recess and glyph carrier |
| `uw_drive_housing` | the guided drive and its lever |
| `uw_applicator` | the applicator housing |
| `uw_return_rail` | the return release |

**The class sensor is not a kilogram gauge, and the harness enforces
the distinction by name.** A08.2's sharpest line is "do not reuse the
accumulating-kilogram gauge as though the two sensors mean the same
thing". A kilogram gauge is a needle that sweeps; this reads a **class**.
So the carrier has three **discrete** `class_mark_*` positions and no
continuous scale anywhere — and `roomkit_fit.gd` fails the asset if any
part is named `gauge`, `needle`, `dial`, `scale`, `meter`, `kg` or
`kilo`. Sabotage-tested by renaming the marks: refused.

**The drive housing stays out of the crate's path.** The crate runs
`PARK_Z` 1.0 → `RECESS_Z` 5.6 and is 2.0 m square, so the corridor is
4.6 × 2.0. `assert_clear_of_corridor` refuses anything inside it, and
the guide rail runs **beside** it. The asset is exported **as-built**:
local y = 0 is the park position, +y runs toward the recess, x = 0 is
the corridor's centre line.

**It does not imply freehand carrying is the only solution.** There is a
lever and a guided screw — a machine for *moving* the thing, which is
the point the room makes before the Status answer arrives.

**The crate is untouched.** `sp_ballast_crate` from Batch 045 keeps its
contract: exactly 1.0 m in every state, solid corners, a stepping
surface, and only the four `lightened_panel_*` nodes change. Nothing in
this batch shrinks it, ghosts it, floats it or relabels its mass.

**The return release is not a stair.** A08.5 says no base-kit stair
before completion, so `uw_return_rail` is a gate with a drop bar —
`release_bar` is the part that moves — and `assert_no_footholds` checks
that rather than trusting the description. Sabotage-tested by fattening
the bar into a tread: refused by the builder, and refused again by the
import harness when the builder's gate was disabled.

---

## 4 · Two gates that were wrong before they were right

Kept in the record, same as the last two batches.

**`assert_stops_at_edge`** began as a rule about *size*: anything whose
span fell between the 0.2 m gap and half a metre past it was
"bridge-sized". It duly refused a 0.3 m nosing strip lying flat **on**
the deck, growing backwards, nowhere near the gap. **A rule about size
cannot tell a bridge from a doormat.** The rule is about position now —
the edge line — and the asset is authored about it.

**`assert_clear_of_corridor`** reported the drive's guide rail *inside*
the corridor it runs beside. The rail is authored at x 1.22, outside the
crate's ±1.0; `set_origin_group` had recentred the whole asset on its
own bounding box and moved it to −0.335. **An asset whose origin is its
contract must not be re-anchored.** Three assets are exported as-built
now, each carrying an `origin_means` string.

---

## 5 · Evidence

```
[roomfit] PASS -- 14 asset(s) imported, kept their parts, and keep the
          promises A06-A08 asked for
```

Sabotage-tested, four ways: five interval pips instead of eight; a
`kg_gauge_*` part on the class plate; a lane rib raised into the shot
line; a tread on the return gate. All four refused — the last two by the
builder before the export happened, which is the earlier and better
gate.

`run_roomkit_views.sh` renders 14 solos plus **three room frames with
your geometry in plain grey**, because a fit should be something the
picture shows rather than something this document claims:

* **`pp_rendezvous.png`** — A06.6's closest approach: both decks at the
  transfer, 0.2 m apart, with the edges on them and the lift's masts
  running the well below. Shot level with the hop, because a frame from
  thirty metres up cannot show 0.2 m.
* **`cf_lane.png`** — the lane walls and receiver in grey, the ribbed
  edge marking, the emplacement and the alcove.
* **`uw_switch.png`** — your plate and crate in grey, with the drive's
  rail visibly running beside the corridor.

---

## 6 · What I am NOT claiming

- **Not runtime-bound.** The presentation-seam ask stands and covers
  these too.
- **Not owner-approved.**
- **A06.5's gate/interlock assemblies are NOT delivered.** A06.5 says to
  provide them "only against actual agreed runtime states", and to
  label the missing hookup rather than adding an animated fake lock. I
  could not find an agreed gate state in `passing_platforms.gd`, so
  there is no gate here and this line is the label.
- **A07.6's "art-off/on alignment views" are half done.** The three room
  frames show your greybox and the art together, which is the alignment;
  there is no matched pair with the art removed. If you want the
  strict before/after, say so — it is a shot-list change, not a rebuild.
- **`cf_alcove_frame`'s mouth width is Art's reading.** `ALCOVE_X` spans
  3.1 m in your room and I took the whole of it; if the alcove wants a
  narrower opening with returns, that is a placement decision I have
  guessed at.
