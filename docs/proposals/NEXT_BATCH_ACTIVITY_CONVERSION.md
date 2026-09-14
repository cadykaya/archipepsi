# Proposal: the next Production batch

**Status: PROPOSED, NOT IMPLEMENTED.** Nothing in this document has been
built. It exists so the batch is chosen from evidence rather than from
memory of a session. Awaiting owner review.

Follows `docs/PLAYTEST_2_5_RESULT.md`, which closed the authored-art A/B
and set the priority:

> **PLAYER ACTIVITY MUST BE FUNDED INDEPENDENTLY OF CHECK COUNT.**

---

## 1. Measured

New measurement, same Zone. Everything here comes from
`playtest.played_zone()` — the same call whose digest (`98e08663ce6b3b7a`,
23 rooms / 921 value / 41 enemies / 15 Checks) the A/B was taken against —
scored through `content_value.py`. These are facts, not readings.

### 1.1 Where the 921 points of content value actually go

| Category | Points | Share |
|---|---:|---:|
| Activities | 531 | 57.7% |
| Enemies | 158 | 17.2% |
| Objectives | 80 | 8.7% |
| Traversal segments | 69 | 7.5% |
| Space (capped, scored last) | 75 | 8.1% |
| Affordance features | 8 | 0.9% |

### 1.2 Room shape

- 23 chambers: 8 corridor, 10 arena, 5 platform_path.
- Rooms holding no Check: **8, and all 8 are corridors.**
  Every single non-corridor room holds a Check.
- Checks per room: **max 1**, in every room that has one. The schema
  admits 3 (`additional_reward_location_ids`, max_length=2).

### 1.3 The activities

- 32 activity instances: 9 `pressure_routing`, 8 `target_challenge`,
  8 `switch_sequence`, 7 `timed_run`.
- **0 of 32 carry a time limit. 0 of 32 are ordered.**
  `ACTIVITY_TIMED_BONUS` and `ACTIVITY_ORDERED_BONUS` were never earned.
  Seven of them are of kind `timed_run` with `time_limit = 0`.
- `Activities._row()` (`godot/scripts/generation/activities.gd:46-75`)
  builds, per element: a `StaticBody3D`, a `BoxMesh`, a glow material and
  a `BoxShape3D`. No `Area3D`, no group, no script, no signal.
- `Activities` is referenced from exactly one place in the whole client,
  `content_instantiator.gd:255`, which calls `build()` and stores the
  returned dictionary in a result the caller does not act on.
- Grepping `godot/scripts/` for `switch_sequence`, `target_challenge` and
  `pressure_routing` returns `activities.gd` and nothing else.

### 1.4 Combat

- 41 enemies (28 ranged, 12 melee, 1 brute) placed across 10 of 23 rooms.
- The run recorded **6 encounters totalling 32 s** of an 884 s Zone.
  10 rooms hold enemies; 6 encounters were recorded. The gap is not
  explained and is listed as open below.

### 1.5 One measurement-hygiene defect

`fixtures/make_playtest_baseline.py:91` hardcodes
`unlocked_affordances=()`. The live path
(`campaign.py:772`) computes it properly via `owned_affordance_tags`, so
the *played* Zone carried 2 features and the *archived baseline file*
carries 0. `docs/baselines/playtest_2_5.json` therefore under-reports
optional content relative to what was played.

---

## 2. Interpretation

Marked as interpretation. Section 1 stands without it.

**The obvious reading of the priority is wrong, or at least premature.**
"Fund activity independently of Check count" reads as "make rooms that
have no Check in them". Section 1.1 says the Zone *already* spends 57.7%
of its content budget on something that is not a Check and not an enemy.

That spending buys nothing. The activity vocabulary was built to the
geometry seam and stopped there. 531 points of the budget are glowing
boxes you bump into.

So the binding constraint is not funding. It is **conversion**: the
budget already flows to non-Check activity, and none of it becomes
gameplay. Adding more rooms first would scale a conversion rate of zero.

This also explains the owner's report verbatim — *"some areas like this
are big, and have a single check, a single enemy, and a bunch of
meaningless static shapes lol."* The static shapes ARE the activities.
The description was exact.

**And the guard inherited the blind spot of the fix.**
`test_the_engine_builds_every_activity_the_schema_admits`
(`bridge/tests/test_runner_coverage.py:110`) reads `activities.gd` as
text and asserts each schema kind appears in it. That was the right
question when the seam was geometry. It proves a `match` branch exists.
It cannot see that the branch produces something inert, and its name
reads as though it guards the puzzle. The same shape again.

---

## 3. Recommended next batch

### Classification

- **A. SMALL IMMEDIATE WINS** — no schema change, no unresolved design
  decision, measurable in the next playtest.
- **B. STRUCTURAL ACTIVITY WORK** — changes what the generator produces
  or what a room is. Needs owner sign-off on shape; needs numbers from a
  playtest.
- **C. FOUNDATIONAL SYSTEMS** — new subsystems. After B has been played.

### The batch: make the activity vocabulary actually play

This sits in **A**, deliberately, and it is the whole batch. It converts
57.7% of the content budget from scenery into gameplay without
generating one new room, without a `Zone` schema change, and without
touching Archipelago at all.

It is not the structural work. The structural work (**B**: Check-free
rooms, spurs, clustering Checks so room count stops tracking Check
count) comes next and needs numbers this batch produces.

---

## 4. The seven

### 4.1 Recommended next batch

**"Activities become gameplay."** Four items, in dependency order. The
first two are the batch; the second two are droppable without breaking
it.

**A1 — an activity can be completed.** Each kind gets a real completion
condition and a runtime that owns it:

| Kind | Completion |
|---|---|
| `switch_sequence` | every switch interacted with; in sequence when `ordered` |
| `target_challenge` | every target hit by Static Pulse — the permanent always-available ranged floor |
| `pressure_routing` | every plate registered while stood on |
| `timed_run` | goal element reached from the start element, inside `time_limit` when it is > 0 |

**A2 — completion has a consequence that already exists.** Route it to
the `grant_local_reward` validated transition with a kind from the
existing closed `EarnedLocalReward` catalog (`flavor_log` or
`epsilon_note`). No new catalog kind, no new AP semantics, no
play-affecting reward. The point is that finishing something is
observable and persists.

**A3 — the generator may set `time_limit` and `ordered`.** They are
schema fields with value weights that the fallback never sets, so every
activity in a real Zone is the easiest possible instance of its kind.
Expose the rate as one named constant marked provisional. **This batch
does not choose that number; playtest 3 does.** Droppable.

**A4 — stop hardcoding `unlocked_affordances=()` in the baseline
builder.** Measurement hygiene for §1.5. Droppable.

### 4.2 Exact scope

In scope: activity completion, its consequence, its instrumentation, and
the tests that pin behaviour rather than source text.

Out of scope, explicitly, even though adjacent: room counts, Check
placement, enemy counts, encounter design, drops, melee, art.

### 4.3 Files and systems likely touched

Client:
- `godot/scripts/generation/activities.gd` — builder emits interactive elements
- `godot/scripts/gameplay/activity_runtime.gd` — NEW; owns per-activity state, emits completion
- `godot/scripts/content/content_instantiator.gd:253-257` — wire the runtime at the existing seam
- `godot/scripts/gameplay/local_reward.gd`, `rule_runtime.gd:348` — route completion to the existing intent
- `godot/tests/test_activities.gd` — NEW suite

Bridge:
- `bridge/tests/test_runner_coverage.py` — add the behaviour pin; annotate the source-grep test with what it cannot see
- `bridge/archipepsi_bridge/instrumentation.py`, `playtest.py` — record and report per-activity outcomes
- `bridge/archipepsi_bridge/epsilon/fallback.py` — A3 only
- `bridge/archipepsi_bridge/fixtures/make_playtest_baseline.py` — A4 only

Regenerated, never hand-edited:
- `docs/baselines/playtest_2_5.json` → a new baseline for playtest 3
- `docs/AGENT_FRONTIER.md`

### 4.4 Invariants to preserve

1. **Archipelago owns randomized truth.** An activity completion must
   never touch AP truth. `EarnedLocalReward` is worth exactly zero to
   Archipelago and stays so.
2. **Persistent state changes go through validated transitions.**
   `grant_local_reward` already is one; use it, do not add a second path.
3. **Derived mechanics come only from the interpretation-log fold** and
   are not separately persisted. An activity reward must not become a
   derived mechanic.
4. **Nothing in the activity vocabulary may require an Echo.**
   `activities.gd`'s own rule. Static Pulse is the permanent
   always-available ranged floor and is what `target_challenge` may
   assume. **Assume no melee binding** — baseline melee lives on the
   permanent starting device/chassis and its binding is deliberately
   unresolved.
5. **Logical solvability.** An activity may never gate an objective or an
   exit. No AP location logic declares an activity as a prerequisite, so
   a physical activity gate would be exactly the thing §0-bis forbids: a
   physical gate the matching AP logic does not declare.
6. **`challenge_marker` stays deferred.** It is the local-reward kind an
   activity completion most obviously wants, and it is deliberately
   without semantics. Do not resolve that decision as a side effect of
   this batch. Do not remove the hook.
7. **Never weaken a test merely to pass it.** Generated artifacts are
   regenerated from source.
8. **Art lane.** Activity elements stay procedural graybox. This batch
   adds no art, promotes nothing, and touches no `review: pending` asset.

### 4.5 Tests to add first

Written before the implementation, and deliberately shaped not to
inherit the blind spot of the thing they guard.

1. **Behaviour coverage, not source coverage.** Build each activity kind,
   drive it to completion, assert a completion signal fires. The mirror
   of the existing builder pin — and the guard that would have caught
   today's state.
2. **Negative control.** An activity nobody touches never completes.
3. **N−1 is not N.** Completing all but one element does not complete the
   activity.
4. **Ordered means ordered.** An `ordered` activity driven out of
   sequence does not complete. The chosen rule (reset vs. no-credit) is
   pinned by the test rather than left to the implementation.
5. **Timed means timed.** A `time_limit > 0` activity not finished inside
   the limit does not complete.
6. **Scored implies playable.** Every activity kind `content_value.py`
   scores must have a runtime that can reach completion — so a future
   kind cannot earn budget without behaving.
7. **No new AP surface.** Assert the intent emitted on completion is
   `grant_local_reward` carrying a kind from the closed catalog, and that
   no AP location, Check, Coin or Signal Key is reachable from that path.

### 4.6 Measurable change expected in playtest 3

- **Inert share of content value: 57.7% → ~0 by construction.** The Zone
  still scores ~921; the difference is that the 531 points do something.
  This is a construction guarantee, not a prediction.
- **New instrumentation:** per-activity kind, attempted, completed,
  seconds. Today the concept does not exist in `playtime.jsonl`, so
  anything above zero is new signal.
- **Dwell should shift toward Check rooms.** The six corridors not
  obviously inflated by the death respawn ran 2.2-18.4 s, median 2.7 s;
  the eleven Check rooms from #7 onward averaged 15.7 s. If activities
  convert, that gap widens. If it does not widen, the conversion did not
  land, and that is the finding.
- **The human verdict.** "A bunch of meaningless static shapes" should
  become "things I did". That is the actual acceptance test and it is
  the owner's to give.

### 4.7 Explicitly deferred

| Deferred | Why | Where it goes |
|---|---|---|
| Check-free rooms, spurs, clustering Checks | needs numbers from playtest 3 | **B**, next batch |
| Numeric budgets: how many activities, what time limits, what share of rooms | owner ruling: playtest them, do not choose them | playtest 3 |
| Enemy / local drops as a play-affecting economy | new `EarnedLocalReward` kind = real blast radius through `echo.py`, `transitions.py`, `capabilities.py` | **C** |
| Encounter Director | Phase 4 | **C** |
| Baseline melee | blocked on the unresolved binding decision | **C** |
| Save / re-entry stations | changes what "elapsed" means; do it between comparisons | **C** |
| Zone-local keys, capability-gated required path | §0-bis permits the strong version, which makes it larger; wants Architecture D first | Phase 2 |
| `challenge_marker` semantics | deferred by standing instruction | — |
| `SECRET_VALUE = 8` | defined in `content_value.py:54`, read by nothing; no chamber field feeds it. Wire it or delete it | **B** |
| v9 buildcraft migration | Phase 3 | — |
| F3 art | deferred by the A/B verdict | art lane |

---

## 5. Phase 1, re-ordered against the evidence

The original list, from `ARCHIPEPSI_FINAL_FINAL_FINAL_PLAN` (Phase 1 —
Fun Slice On Current v0.8 Runtime), and where the measurement moves it.

| New | Old | Item | Why it moved |
|---:|---:|---|---|
| **1** | 6 | more meaningful combat/traversal moments using existing runtime | Promoted to first and narrowed to *activities*. 57.7% of content value is already allocated here and converts to nothing. Nothing else on the list changes that much for that little, and it needs no new system. |
| **2** | 4 | dead-end spurs / optional branches | This is the composition half of the priority. Held one slot back because it should be tuned against a Zone whose activities work — otherwise the spurs are more empty boxes. |
| **3** | 1 | enemy / local drops | Demoted. Combat was 32 s of 884 s across 6 encounters. A drop is a reward for fighting; the fights are currently too short and too rare for the reward to land on anything. |
| **4** | 2 | baseline melee + melee floor invariant | Demoted. Still wanted, but it deepens combat, and the measured problem is combat *volume and duration*. Also blocked on the unresolved binding decision. |
| **5** | 3 | save / re-entry station basics | Real — the single death cost a full re-walk and contaminated rooms 0 and 3 in the dwell data. But it changes what "elapsed" means, so it lands between playtests, not inside a comparison. |
| **6** | 5 | Zone-local keys | Stays last. Highest design risk of the six, and §0-bis has made the strong version legal, which makes it more interesting *and* more expensive. Wants Architecture D groundwork. |

---

## 6. Still open, carried forward

From `PLAYTEST_2_5_RESULT.md` §4, plus two new:

- **New:** 10 rooms hold enemies; 6 encounters were recorded. The
  recorder and the placement disagree and neither has been audited.
- **New:** `SECRET_VALUE` is priced and unproducible (§4.7).
