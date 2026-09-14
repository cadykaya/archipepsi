# Is the game going to be fun? — an evidence review, and a proposal

**Dess, bridge lane — 2026-09-12.** Written because the owner asked the
question directly. Checked against the repository at `6669c74` rather
than against recollection, because three of the claims I made from
memory turned out to be wrong.

**Status: report and proposal. Nothing here is implemented, no contract
changes, and every action in §6 needs its own approval.** It duplicates
no existing proposal; where one already covers an item it routes to it.

---

## 1. Corrections first — three things I had wrong

Read this section before the rest. It is the reason the review exists.

| Claim I made | Verdict | Source |
|---|---|---|
| "Rooms have contents but no verb — you walk in, take the thing off the pedestal, leave." | **Wrong.** | `ZONE_ACTIVITY_AUDIT.md` §1: **30 activities across 19 of 23 rooms**, 30/30 runtimes built, 30/30 elements inside their own chamber, **4 of 4 kinds driven to `COMPLETE` in the assembled scene through real physics**. After the readiness batch: 0 structural failures, 0 placement notes. |
| "The physics package work is the load-bearing piece for enjoyment." | **Premature.** | `manipulable_body.gd` is real and new — `class_name ManipulableBody extends RigidBody3D`, and until it landed the engine had **no `RigidBody3D` anywhere**. But its own docstring: *"It is not a puzzle, not an activity, not a Check and not a verb."* The substrate exists. The verb is half. The puzzle (level 3) is **not built**. |
| "Zones are strictly one-way, so nothing can be deferred and returned to." (inherited from the 2026-09-11 findings, §S-9) | **Stale.** | `protocol.py`: `REVISITABLE_ZONE_STATES` includes `COMPLETE`; `ZONE_ENTERABLE_MODES` includes `ZONE_DORMANT`. The 2026-09-12 ruling (`09_ROOM_CONTRACT.md` check 14b) made a cleared Zone re-enterable with layout and progress intact. |

So the diagnosis "rooms are enlarged corridors" cannot be repeated in its
2026-08 form. The rooms have verbs now. The question moved.

---

## 2. What the measurements actually say

Everything below is measured, not estimated, and cited.

**Content distribution** (`PLAYTEST_2_5_RESULT.md` §2.1)
- **832 of 921 content points — 90.3% — sit in rooms that hold a Check.**
- Eight corridors carry **89 points between them**; three carry zero.
- Predicted at 89% from six synthetic Zones beforehand. The played Zone
  came in at 90.3%.

**Pace** (§2.2)
- Honest window (rooms 6–22, after the player stopped photographing):
  **0.302 s/point**. A 921-point Zone is therefore **~4.6 minutes** of
  normal play against a **40-minute target**.

**Combat** (§2.3)
- **6 encounters, 32 seconds total.** Median 6 s, longest 9 s.
- **41 enemies across 13 arenas, every one `kill_all`.**
- The set-piece — a 26 × 24 arena, 7 melee / 1 brute / 4 ranged, value
  121 — took **20.3 seconds**.
- Combat is therefore about **3.6% of the run**.

**What the Checks produced** (§2.4)
- 15 Checks → **5 components and 10 stat bumps**. Two thirds of the
  campaign's rewards were a number going up.
- **Two of four Echo slots were empty at the finish.**

**Vocabulary size** (read from the schemas)
- `ActivityKind`: **4** — `switch_sequence`, `timed_run`,
  `target_challenge`, `pressure_routing`.
- `ActivityCapability`: **4** — `blink`, `cross_long_gap`, `grapple`,
  `ranged_hit`.
- Arena `objective`: **2** — `kill_all`, `reach_reward`.
- Authored shell scenes: **19** (12 under `godot/content/shells/`).

**Perception** (`2026-09-11-playtest-zone1-findings.md` §S-9, corrected
2026-09-12)
- `activity_runtime.gd` carries the clock (92, 256, 363), appends it to
  the HUD prompt (178), says `DONE` (332), sends `grant_local_reward`
  (339) and emits `completed` (345). **The player ran four activities to
  completion and perceived no clock and no completion.** The report's own
  words: *"the mechanism existing is not evidence that it reaches the
  player."* Still open.

---

## 3. The finding: the project measures completability, never engagement

`ActivityOutcome` in `protocol.py` is one of the best-specified records in
this repository. Its docstring names the exact questions:

> Did they notice it? `entered` · Did they try it? `attempts` · Did they
> understand it? `attempts` against `completed` · Did they finish it?
> `completed` · How long did it hold them? `active_seconds` · Did a gate
> behave? `not_yet`
>
> `entered` and `attempts` are deliberately separate. "Walked past it" and
> "had a go and gave up" are different findings.

It is wired end to end. `playtime_log.gd` watches every activity the Zone
builds (`watch_activity`), marks entry per room
(`enter_chamber_activities`), and emits `"activities": _activity_reports()`
inside the `zone_timing` intent (line 130).

**No report in `docs/` reads it.** The only recorded baselines are
`playtest_2_5.json` and `playtest_2_5.pre_3b.json` — and playtest 2.5 ran
**2026-08-29**, one day before activities landed (**2026-08-30**). Every
number we have about player behaviour predates the system that was built
to fix player behaviour.

This is the project's own named failure mode, standing on the single
question that decides whether the game is good:

> **A measurement exists, is correct, and is never handed the case that
> fails it.**

`godot-zone-audit` proves an activity *can* be completed. Nothing
anywhere asks whether anyone *did*.

---

## 4. Why a room can hold a verb and still read as a corridor

Not because the verb is missing. Because until very recently it had no
consequence.

- `content_driver.gd:1302` still asserts that `zone_controller.gd` and
  `hub.gd` may not read `challenge_marker` — *"no progression may depend
  on a hook whose semantics are undefined"*. The hook is kept deliberately
  dormant (`_the_challenge_marker_hook_is_dormant_not_gone`).
- The activity-conversion entry records the payment plainly: *"completion
  grants a `flavor_log`."*
- The 2026-09-11 findings, on warp stations repaired by solving a puzzle:
  *"the **first real consequence anything has proposed** for
  `switch_sequence` / `pressure_routing` / `target_challenge`."*

That consequence has since been built — `zone_controller.gd:608`,
`_repair_station_for`: *"A solved puzzle switches on the broken station in
its own room."* **One room-state consequence now exists, in one shape, in
rooms that happen to hold a broken station.**

Everywhere else the arithmetic a player does is unchanged: an activity
costs time, risk and skill, and pays a note. `content_value.py` scores it
at `6 + 3/element (+4 timed, +3 ordered)` — **531 of 921 points** by the
conversion batch's own count. A competent player learns to walk past a
little over half the content budget, and the budget cannot tell.

`CHECK_VALUE = 0` is the honest corollary the codebase already states: a
Check is worth nothing as content. The content is supposed to be the
activity. The activity is optional.

---

## 5. What is actually blocking each part — three different things

The backlog is usually read as one list. It is three, and they need
different actions from different people.

**(a) Blocked on an owner ruling — not on work.**
`docs/AP_CAPABILITY_LOGIC.md`: *"Until it is settled the bridge keeps
refusing a capability gate on any AP-relevant route
(`topology.reachability`). That restriction is temporary and is **not** a
verdict on the gameplay."* Three of §0-bis's five conditions are enforced;
**two are not, and both are about Archipelago** — that AP location logic
declares the same prerequisite, and that AP proves the capability
progression obtainable.

This matters more than its position in any list suggests. *Find the
grapple, come back, open the door you could not open* is the core loop of
this genre, and it is the thing I described as the whole pleasure. It is
not unimplemented because anyone forgot. **It waits on a decision.** The
same document notes hidden Checks are *already permitted* by §0-bis and
*"nothing currently emits a declared gated Check. The missing piece is the
declared path, not permission."*

**(b) Proposed and approved-in-part, awaiting approval for the rest.**
`docs/proposals/ROOM_FIRST_GAMEPLAY.md` — SLICE 1 (ROOM GRAMMAR v0)
landed; §§2–11 are proposed and explicitly may not be started without
approval. Its §8 already reached the right conclusion and should be
credited: *"the first slice should pay in room state and access, not in
items."* `_repair_station_for` is the first instance of exactly that.

**(c) Asked for, never scheduled** (2026-09-11 §3): enemy perception,
enemy tiering, multi-room activities, physics props, a carry/throw verb,
letting a Zone close below 100%.

---

## 6. Proposal — six actions, ranked by information per unit of cost

Each names its evidence, its lane, and **what result would prove it
wrong**. None is started.

### P1 — Read the telemetry already being collected. *(Cheapest. Do this first.)*
One instrumented run of the current build, and a report of the
`activities` array in `zone_timing`: per activity, `entered`, `attempts`,
`completed`, `active_seconds`, `not_yet`.
- **Evidence:** §3. The record, the producer and the transport all exist;
  only the reading is missing. This is not new engineering.
- **Lane:** engine to capture, bridge to report, owner to play.
- **Cost:** one playtest plus a report. No new system.
- **What it decides:** `entered=true, attempts=0` on most activities is a
  *legibility or motivation* failure. High `attempts`, low `completed` is
  a *difficulty* failure. They have opposite fixes, and **we are currently
  guessing which one we have.** The record was built to separate exactly
  these two and has never been asked.
- **Falsifier:** if engagement comes back high, §4 is wrong and P3 drops
  down the list.

### P2 — Settle the capability-gate ruling.
`AP_CAPABILITY_LOGIC.md` is written and waiting, and the decision is
already reduced to a choice between three drafted options: **§4 Option A**
(explicit capability items), **§5 Option B** (guaranteed local acquisition
represented in AP logic), **§6 Option C** (the current restriction, kept).
§1 names the two unmet conditions the choice has to satisfy.
- **Evidence:** §5(a). The bridge refuses the gate today by standing
  instruction, not by limitation.
- **Lane:** owner decision; bridge implements.
- **Why it is ranked this high:** it unblocks the only mechanism that
  makes a room *owed* to the player across time. Every other item makes a
  room better to be in once. This is the one that makes a player come back.
- **Falsifier:** if the ruling lands and gated Checks still produce no
  backtracking in play, the debt model is wrong for this game and I would
  want to know that early.

### P3 — Generalise the consequence that already works.
`_repair_station_for` pays a solved activity in **room state**. Today that
requires the room to hold a broken warp station. Widen the same shape —
one activity, one local state change, in its own room — rather than
inventing a second reward model.
- **Evidence:** §4, plus `ROOM_FIRST_GAMEPLAY.md` §8's ranking, where
  "a temporary room advantage (a door opens, a lift powers)" is the
  cheapest row and a local consumable is *"real schema work"*.
- **Lane:** engine, with a bridge-side declaration if the composer must
  place the device.
- **Constraint to keep:** it must stay optional. §13.2 forbids an optional
  feature on the mandatory path, and that rule is what keeps a Zone
  base-kit completable. **This is a reason to occupy a room, not a reason
  to require it.**

### P4 — Let a Zone close below 100%, and make reaching the exit a Check.
- **Evidence:** `exit_portal.gd:3` — *"Locked until every assigned Check
  confirms."* In the played run a forgotten Check held the Zone shut and,
  combined with B-1, forced a Teleport backtrack through an impassable
  room. Already an ask (2026-09-11 §3).
- **Lane:** engine plus AP location definition; touches the item pool, so
  it needs an explicit owner decision and is **not** a quiet change.
- **Why it belongs here:** a hard 100% lock converts a missed thing into a
  softlock rather than into a reason to return. It is the exact opposite
  of the debt loop P2 enables.

### P5 — Multi-room activities.
A `timed_run` whose START and GOAL are in different rooms is a route, and
a route is the cheapest way to make the graph — junctions, side depth, the
branch topology already being generated — do work the player can feel.
- **Evidence:** already an ask (2026-09-11 §3); §S-8 records that
  activities are single-chamber and the chamber can be a 6 × 6 corner.
- **Lane:** engine; bridge would need to let an `ActivityPrimitive` name
  two rooms, which is a schema change I would want scoped before agreeing.
- **Note:** this is the one item that makes the *existing* topology work
  pay off. Everything the composer does — 20–23 rooms, 4–5 junctions, 7–8
  dead ends — is currently invisible to any single activity.

### P6 — Perception before tiering, for combat.
- **Evidence:** §S-3 *"There is no enemy perception"*; §S-4 *"Enemy power
  never scales; player power does"*; 41 enemies producing 32 seconds.
- **Lane:** engine.
- **Ordering claim:** perception first. Tiering a blind enemy produces a
  tougher blind enemy. Sight, an alert state, decaying memory and a leash
  change what a room *is* — cover, elevation and the sockets ROOM GRAMMAR
  v0 already built start mattering. That is the cheapest route from
  "32 seconds of combat" to combat worth having a room for.

### P7 — A level-3 physics puzzle, on the substrate that now exists.
- **Evidence:** `ManipulableBody` exists and rests; `PlacedPackage` and
  `ReplayEvidence` carry it; `manipulable_body.gd` states plainly that the
  puzzle layer is not built.
- **Lane:** engine, on Prod's physics packages.
- **Why last, not first:** it is the most expensive item here and the one
  most likely to be redesigned once P1 says what players actually do. I
  said in conversation that this was the load-bearing piece for fun. On
  the evidence that was premature, and I would rather correct it here than
  have it quoted back as a priority.

---

## 7. The honest answer to the question

**The floor is real.** The paranoia about logical-versus-base-kit
solvability — *a physical gate the AP logic does not declare may never
exist* — is not bureaucracy. The worst experience a randomizer can deliver
is a seed you cannot tell is broken: you are stuck, you do not know
whether it is you or the generator, and you lose an evening to the doubt.
This project has refused that failure from the start, and that refusal
buys the trust a player needs before they will push on a strange door. It
is a genuine contribution to the game being fun. It just cannot build
anything on top of itself.

**What I would bet, with the evidence in:**

- A game a randomizer community finds solid and trustworthy — **likely**.
  That work is done and holds.
- A game people run a second seed of — **turns on P1 and P3.** Half the
  content budget is currently optional and unrewarded, and nobody has
  measured whether it is being skipped.
- A game that makes someone backtrack across an hour because they
  remembered a door — **turns entirely on P2**, which is a decision, not
  a build.
- Memorable beyond the niche — still the fold. `derive_mechanics` is real
  and deterministic, but 15 Checks produced **10 stat bumps and 5
  components**, and two of four Echo slots were empty at the finish. Two
  thirds of interpretation currently arrives as a number going up. If
  interpretation changes what a player can **do**, it is the reason this
  game exists. If it changes what they read, it is decoration with a very
  good schema.

**One structural observation, offered once.** Every lane here owns whether
its part is correct — bridge, engine, art, interpretation, adversarial
check, audit. No lane owns whether the whole thing is enjoyable. That role
is the owner's alone and has no second opinion in it, which is precisely
why P1 matters more than its cost suggests: it is the only item on this
list that would let evidence, rather than one person's judgement, answer
the question.

---

## 8. What this report does not claim

- **I have not played it.** Every experiential statement here is derived
  from someone else's recorded session, and §S-9 is a standing warning
  that built and perceived are different facts.
- **P3, P5, P6 and P7 are not my lane.** They are recorded for the owner
  to route, not proposed for me to start.
- **No contract changes**, no topology preference, no item-pool change, no
  re-opening of the 0.4 implementation, and nothing here alters the
  `plug_placement` handoff still awaiting the engine lane's half.
- **Nothing is scheduled.** No watcher, no check-in, and no trigger armed.
