# 3A/3B integration — focused audit of `96c450e`

**Independent audit. 2026-09-10. No product changes.**

| | |
| --- | --- |
| **Audited commit** | **`96c450e8ba91ec012fb1e2ce44d269a67a14bf53`** — *The shell is the room, and a player rides one* |
| Branch | `claude/archipepsi-echoes-continuation-b1adno` (this SHA is the branch head) |
| Prior Production head | `67277aa` |
| Report under audit | `docs/reports/2026-09-11-3ab-integration.md` |
| Frozen authority | `docs/ROAD_TO_PLAYABLE_0_3.md` |

**No Godot binary in this environment.** Everything below is labelled
either **[measured]** — computed against the committed `.glb` collision
and the registry, or run — or **[read]** — established by reading the
code and its assertions. The Python suite did run. Godot suite results
are Production's and are not independently confirmed.

**Headline: nothing here blocks trying the checkpoint.** One finding is
latent rather than live, and it is held latent by the area budget. Two of
the report's claims are true but rest on weaker evidence than stated, and
one inference drawn from them is not supported.

---

## 1. Are the room joins actually safe?

### The mechanism [read]

The exemption is **exactly one piece deep, in both places**, and the two
agree:

* the planner — `ZoneBuilder._search` checks each candidate against
  `_all_but_last(chain)`, dropping the most recently laid piece, which is
  always the one the next piece attaches to;
* the test — `test_chambers.gd::_clashes` runs `j` from `i + 2`, so
  consecutive pairs are exempt and every other pair must share less than
  0.5 m³.

That is a correct and necessary design: rooms meet at a shared face, and
a face contact has no volume. The report's INT-2 describes it accurately.

**The exposure is that within that one exempt pair there is no bound at
all.** `origin_for` places a room by its entry socket, and nothing
constrains where that socket sits inside the room's envelope. A shell
whose entry is inset `k` metres extends `k` metres *behind* its own join
plane, and neither the planner nor `_clashes` will look. The backstop is
only the piece one further back, which is checked.

### What the catalog actually does [measured]

| Shell | entry socket | extends behind its join |
| --- | --- | --- |
| 11 of 12 shells | `[0, *, 0]` | **0.00 m** |
| `shell_yard_gantry` | `[-43.0, 0.0, 26.0]` | **26.00 m** |

So for every shell but one the exemption is exactly the shared face, and
the join has no volume to hide anything in.

### A good join, tested with the real capsule [measured]

Zone 1's `c006` join — a 5 m connector into `shell_span_basin`, room
origin at `join − entry`:

* `shell_span_basin`'s real collider extent runs local `z 0.000 … 90.000`
  — **no collider reaches behind its own join plane**;
* a player capsule swept along the entry line from inside the connector
  to 6 m into the room is **blocked at no sample**;
* ground is continuous across the seam: `sp_south_sill` then `sp_deck`,
  both at exactly the connector's floor height.

**This join is clean, and it is clean physically, not just in bounds.**

### Excessive overlap, within the supported contract [measured]

`shell_yard_gantry` at a connector join, placed exactly as `origin_for`
would place it:

* **bounds overlap: 1.60 m × 5.00 m = 8.0 m² of shared footprint** — the
  connector is entirely inside the yard's declared bounds;
* and this one is **not** bounds-only: **30 of the sampled capsule
  positions inside the corridor's walking lane are blocked by
  `yd_west_0`**, the yard's own west wall. Solid geometry, standing in
  the corridor a player has to walk down.
* the join *itself* stays passable — the doorway is open — so the failure
  is not "you cannot get in", it is "the corridor behind you has a wall
  through it".

**This is the distinction you asked for, and it cuts both ways:** a
bounds overlap is not by itself a blocked player (the good join proves
that), but the exemption does not distinguish the two, so it also cannot
tell you when it is.

**It is not reachable today.** `shell_yard_gantry` is excluded from
generation by the area budget (§3), so no generated Zone can adopt it.
It *is* used in the stress tests — `_test_a_chain_of_large_authored_rooms_routes`
places 14 of them — and those tests assert `_clashes` is empty. Since
`_clashes` exempts precisely the pair this overlap lands in, **INT-3's
"120 copies, 465 pieces, zero clashes" does not exclude a yard wall
standing in its own approach connector.** That is a real gap in what INT-3
proves, not evidence that the layouts are wrong.

### When placement fails [read]

Clean. `ZoneBuilder.build` returns `{"failed": "room '…' could not be
placed clear of the N room(s) before it"}`, frees both the partial room
and the root, and attaches nothing. `ZoneController` sets `layout_failed`,
raises `push_error`, and **returns before `add_child`** — so there is no
half-built Zone and no scene handed back. `_test_an_exhausted_layout_is_refused_not_overlapped`
asserts all three properties, including that no `root` comes back.

---

## 2. Do the movement tests prove what the report says?

### The walk-in — real, with a weaker assertion than the claim [read + measured]

The test is genuinely a walk: a real `Player`, real `_physics_process`
frames, velocity set each frame, starting from a point asserted to be
outside the room's bounds. That part is sound.

**Codex is right about the landing.** The loop `break`s the instant
`world.has_point(player.global_position)` is true, then asks
`ground_below(pos + UP*0.5, 4.0) != NO_GROUND`. It never waits for
`is_on_floor()`. As written it would pass with the body 3.9 m above the
floor mid-fall.

**But the fact is true.** `shell_span_basin`'s entry socket is on the
deck at local `y = 14`, and the connector meets it at that height — I
measured ground on both sides of the seam at the same height, so the
player walks in **level, with no fall at all**. The `player_entry` region
is at local `(0, 15.0, 2.2)`, 1 m above the deck and 2.2 m inside, which
is what the walk aims at.

**Verdict: overstated evidence, sound conclusion.** INT-5 is true; the
test does not prove the "lands" half of it.

### The rail — the numbers, checked [measured]

| Claim | Finding |
| --- | --- |
| "34.3 m" | **Displacement**, not distance ridden — the code is `start.distance_to(rode)`. Codex is right. |
| "an 83 m authored path" | **Correct.** The baked Catmull-Rom through the 5 control points is **83.04 m**. |
| "the midpoint of the ride has no ground within `MAX_VERTICAL_STEP`" | The probed point is `start.lerp(rode, 0.5)` — **6.900 m from the nearest point on the actual ride**. Codex is right that it is not on the curve. |

**The underlying fact is stronger than the report claims.** Sampling the
*actual* baked curve rather than the straight midpoint: **41 of 41
samples have no ground within 1.0 m.** Not just the midpoint — the whole
ride is over ground the player does not have at that height.

### But the inference drawn from it is not supported [measured]

The report says *"walking was never going to substitute."* It was.

Walking the basin along the rail's own line, from the ride's start to its
end: **0 samples with no ground, and 0 steps over `MAX_VERTICAL_STEP`,
across the full 80.8 m.** `sp_basin` runs unbroken at `y = 0` beneath the
entire rail. What "no ground within a step" proves is that you cannot
walk *at the rail's height* — not that you cannot reach where it takes
you.

**This does not break A4**, and you already said so: offers stay
optional, and A4 asks that the route differ, not that the rail be the
only way through. It is the report's framing that overreaches.

### The rail/none comparison [read]

Two defects, both in the walker's favour, so the result is conservative:

1. **The frame counts are not equal.** The rider gets `k + frames` where
   `k ≤ 12` is however many catch frames it actually took (the loop
   `break`s on catch); the walker gets `frames + 12`. So the walker is
   given up to **11 extra frames**. Codex's reading is right; the bias is
   safe.
2. **The walker does not walk from an equivalent start — they fall.**
   Both bodies start at the rail lane's own position, which is `y ≈ 2.5`
   in room-local terms, above the basin at `y = 0`. In `none` there is no
   lane to catch them, so `none` is measured as *fall-then-walk*.

**What the 14.8 m separation is made of.** The rider ends on the curve
(`y` between 2.5 and 9.4); the walker ends on the basin floor (`y = 0`).
So between **2.5 m and 9.4 m of that separation is pure height**, and the
horizontal part is between **11.4 m and 14.6 m**. At `WALK_SPEED = 7.0`
the walker covers ~6.6 m/s in plan (the test drives them along the lane's
3-D axis but sets only `x`/`z`), so over the same elapsed time the rail's
advantage is real but is **speed and elevation, not reachability**.

**Verdict: navigation does change — the route differs, measurably.** The
rail carries a body along 83 m of curve at a height where there is no
floor; a walker covers the same span on the basin below, slower and
lower. That satisfies A4 as written. The report's stronger reading does
not survive.

---

## 3. What does the 4,000 m² budget exclude?

### What it measures [read]

`footprint_area(rule) = size[0] × size[2]` — the shell's **declared
bounding footprint**, including the 0.8 m wall envelope. Not walkable
floor, and not interior area. It is a **cumulative running total per
Zone**, tested before each pick as `spent + area(shell) <= 4000`.

### Where it applies [measured]

**Only in the offline provider.** `AUTHORED_AREA_BUDGET` is read in
exactly one place: `bridge/archipepsi_bridge/epsilon/fallback.py:514`.

* not enforced by `validate_zone`;
* not referenced in `shells.py`;
* not referenced in `epsilon/claude.py` — **a live provider is not bound
  by it**, only described to;
* declared in `godot/scripts/autoload/constants.gd` and in the generated
  `constants.gd`, and **read by no Godot code at all**.

### Which rooms it excludes [measured]

| Shell | footprint | effect |
| --- | --- | --- |
| `shell_yard_gantry` | **4430.4 m²** | **permanently excluded** — exceeds the whole budget alone, so it fails even as the first pick in an empty Zone |
| `shell_span_basin` | 2808.0 m² | adoptable, but leaves 1192 m² |
| `shell_hall_transit` | 2472.0 m² | adoptable, but leaves 1528 m² |
| everything else | ≤ 424 m² | fits |

Two consequences worth having in front of you, both stated as
consequences and not as recommendations:

1. **The Yard's exclusion is a side effect, not a decision.** Nothing
   chose to exclude it; a number chosen to bound Zone *pacing* happens to
   sit 430 m² under its footprint, and the test is `spent + area`, so no
   ordering or emptier Zone ever admits it.
2. **Only one large shell per Zone.** `span_basin + hall_transit` is
   5280 m², so a Zone gets one or the other. Zone 1 spends **3085.4 of
   4000** (77%) on `span_basin` plus six corners.
3. **The two open questions are coupled.** Raising the budget past
   4430 m² makes the Yard adoptable — and the Yard is the one shell that
   exercises §1's unbounded join exemption. A pacing decision would
   silently become a placement decision.

---

## 4. A1 / A2 / A4

| | Verdict | Basis |
| --- | --- | --- |
| **A1** — an authored room appears in an actually played Zone | **Supported** | `c006` names `shell_span_basin` through the offline provider path (which you have accepted as intentional), builds its authored scene, and is entered by a walking player. Not a fixture edit, not an override. The join is physically clean [measured]; the walk-in mechanism is real [read]. |
| **A2** — a real Zone is composed from approved authored rooms | **Supported** | 7 of 23 chambers name approved shells — `shell_span_basin` plus six alternating corner shells [measured from the fixture]. All twelve shells are `review: pass`. Connector grammar and entry contract hold at the seam I tested. |
| **A4** — a movement package changes navigation | **Supported, on narrower grounds than the report claims** | A rail is built from an authored offer in a generated Zone and carries a real player along an 83.04 m curve over ground with no floor within a step, anywhere along it [measured]. The route differs from `none`. It is *not* the only way to the far end — the basin floor is continuous beneath it — which A4 does not require and you have explicitly allowed. |

---

## 5. What is broken, what is overstated, what needs you

### Broken

**Nothing that blocks the checkpoint.** No finding here prevents loading
the Zone, walking into `c006`, or riding the rail.

### Latent, not live

**L-1 · The join exemption is unbounded, and INT-3 cannot see it.**
[measured] One shell (`shell_yard_gantry`, 26 m inset) puts solid wall
through its approach corridor when joined, and both the planner and
`_clashes` exempt exactly that pair. Held latent only by the area budget.
*Owner: Production. Blocks the checkpoint: no.*
*Smallest follow-up:* bound the exemption — cap the tolerated join
overlap at the exempt piece's own depth, or assert at load that a shell's
entry inset is zero unless it declares otherwise. Either makes the Yard's
case fail loudly instead of silently.

### Overstated evidence, sound facts

**O-1 · The walk-in never waits for a landing.** [read] The assertion
fires at the crossing frame and accepts ground up to 4 m below. The
arrival is genuinely level and safe [measured], so the claim is true and
the test is weaker than the claim.
*Follow-up:* wait for `is_on_floor()` before asserting.

**O-2 · The rail's ground probe is not on the rail.** [measured] The
probed point is 6.900 m off the ride. The intended fact is true and
stronger — 41/41 samples along the real curve have no ground within a
step — so the fix makes the evidence match a claim that already holds.
*Follow-up:* probe `rail.polyline()` samples instead of `start.lerp(rode, 0.5)`.

**O-3 · "34.3 m" is displacement, and the comparison is not equal-time.**
[read] The number is `start.distance_to(rode)`; the path ridden is longer.
The walker gets up to 11 more frames than the rider, and starts by
falling rather than walking. Both errors favour the walker, so the
conclusion survives.
*Follow-up:* report distance ridden alongside displacement; give both
bodies the same frame count; start the `none` comparison from a standable
point.

**O-4 · "Walking was never going to substitute" is not supported.**
[measured] The basin floor is unbroken for the full 80.8 m under the
ride. Recommend deleting the sentence rather than defending it — A4 does
not need it.

**O-5 · The Python count does not reproduce.** [measured] `make test` in
a clean environment gives **1098 passed, 6 skipped, 0 failed**; the
report says 1144. Same mechanism as the last audit — modules that skip at
import when `make setup` has not run. **Nothing fails either way.**

### Needs your decision

**D-1 · The budget number, and what it is for.** You said not to pick
one, so this is only the consequence: the number is currently doing two
unrelated jobs — bounding Zone pacing, which is what it was chosen for,
and permanently excluding one approved room, which nobody decided. If you
later separate those (a pacing cap, and a per-shell eligibility rule),
the Yard question stops riding on the pacing question. And whichever
number you land on, note that anything above ~4430 m² activates L-1.

**D-2 · Whether the budget should bind a live provider.** Today it does
not — only the offline generator obeys it, and the prompt merely
describes it. That is a real difference in behaviour between the two
providers, and it is your call whether it matters before a live run.

---

## 6. Verified alongside

* **The `SCRIPT ERROR` gate is real.** [read] `godot-playtest3a` now
  greps its own output and exits 1 on `SCRIPT ERROR`, so a test that
  crashes halfway can no longer be reported as a pass. This is the fix
  for how the walk-in proof went silently missing.
* **The failure path attaches nothing.** [read] Verified end to end
  through `build` → `ZoneController`.
* **Zone 1's composition matches the report.** [measured] 7 of 23
  chambers name a shell; `c006` is `shell_span_basin`; the six corridors
  alternate corner shells.
* **Python suite:** 1098 passed, 6 skipped, **0 failed** [measured].
* Not independently confirmed, no engine here: the 18 Godot suites, the
  digests, `make baseline`, and the packet gate.

---

## Verdict

**A1 and A2 are supported. A4 is supported as the Road words it.**
Nothing found here blocks trying the checkpoint — go and ride it.

The one structural gap (L-1) is latent behind the area budget, and the
rest is evidence that is weaker than the claims it carries rather than
claims that are wrong. The single sentence I would change before this
report is quoted onward is *"walking was never going to substitute"*,
because it is the one place the write-up says something the geometry does
not.

This is a checkpoint audit, not a 0.3 completion audit. A3, A5, A6, A7
and A8 were not in scope and are not assessed.
