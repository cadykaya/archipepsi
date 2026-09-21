# Archipepsi 0.4 huge batch — durable work ledger

## Approved assignment

- **Approved plan/version:** 2026-09-21 integrated plan + owner addendum of the
  same date (gantry in S2; second binding relabelled; P0 measures before
  prescribing; four persistence lifetimes; D7 backlogged).
- **Actual starting revision:** `19c5d8e` ("Restamp the placement captures against
  the verified revision").
- **Production comparison revision:** `19c5d8e` on
  `claude/archipepsi-echoes-continuation-b1adno` (draft PR #4) — **untouched**.
- **Development branch:** `claude/archipepsi-0-4-blindside`, branched from
  `19c5d8e`.
- **Latest known-good playable checkpoint:** `19c5d8e` (0.3 candidate; full
  frontier green).
- **Scope decisions approved:** `grapple_to_surface` featured; three-dock Blindside
  prototype; minors EX50-011 / EX50-021 / EX50-033; first-class `RailNetwork`;
  full-strength acquisition integration as M2's completion requirement.
- **Decisions still unresolved:** Forge/Static economy (B4); seed/retry policy;
  D7 return-later progression policy; old-save repair.
- **Processes running:** none.
- **Scheduler state:** heartbeat disabled; no watchers, subscriptions or scheduled
  check-ins. Observed via `list_triggers` — the account's routines are one-shot
  pokes belonging to an unrelated project, none firing into this session.

## Lane status

| Lane | Owner | Accepted? | Blocking |
|---|---|---|---|
| Engine / integration | Prod (this session) | yes | — |
| Bridge / design (D-1..D-6) | Dess | **not accepted — handoff prepared only** | M2 completion (D-1/D-2/D-3); genuine Epsilon objective selection (D-5) |
| 3D models | Arty | **not accepted — asset brief prepared only** | Final visual verdict only; blockout ships first |

## Task statuses

| ID | Player-visible outcome / contract | Source authority | Depends on | Owner/files | State | Revision | Evidence / limit |
|---|---|---|---|---|---|---|---|
| M0 | 0.4 line exists, 0.3 untouched | plan §4 | — | branch, this ledger | implemented | `19c5d8e`+ | branch created from 19c5d8e; 0.3 head unchanged |
| P0 | Measured: is a body actually carried on a moving platform? | addendum "P0 measures before prescribing" | — | `godot/tests/passenger_carry_driver.gd` | **verified** | `a7d23df`+ | 4 cases, all ABOARD, GROUNDED 300/300 in every case. `make godot-passenger-carry`, in CI |

## Findings

### F-01 — the carry works; the deck is the constraint

- **Task / case identity:** P0, `make godot-passenger-carry` at `a7d23df`+,
  `AffordanceNodes.MovingPlatform` (2.4 x 0.4 x 2.4 deck, `PERIOD 5.0`), real
  `Player.create()`, four travel vectors.
- **Observation (not hypothesis):**

  | case | travel | DRIFT | GROUNDED | ABOARD |
  |---|---|---|---|---|
  | horizontal (skiff's case) | `(6,0,0)` | 0.609 m | 300/300 | yes |
  | vertical (shipped case) | `(0,3,0)` | 0.304 m | 300/300 | yes |
  | diagonal (climbing) | `(4,2,0)` | 0.454 m | 300/300 | yes |
  | horizontal + one footfall | `(6,0,0)` | 0.823 m | 300/300 | yes |

  Final offset returns to the starting offset in every non-walking case
  (e.g. horizontal `(-0.25, 0.20, 0)` -> `(-0.21, 0.20, 0)`).
- **Hypothesis and contradictory evidence checked:** four `player.gd` sites were
  suspected of fighting a moving deck — the step-down walker
  (`_note_a_step_down_ahead` / `_follow_the_step_down`, raw `move_and_collide`
  plus forced `velocity.y = 0`), the step-up climb
  (`_climb_a_step_the_law_promises`, `global_position +=`), world-space-absolute
  walk targets, and `is_on_floor()`-gated control. **None of them bit.** 100%
  grounded across 1200 measured frames, including the descending half of the
  diagonal case, contradicts the step-down hypothesis directly.
- **Cause established by:** measurement, not reading. `sync_to_physics = true` on
  an `AnimatableBody3D` does carry a `CharacterBody3D`, as
  `affordance_nodes.gd:398-400` claimed and nothing had tested.
- **Change:** **none to `player.gd`.** The candidate repairs named in the plan are
  withdrawn on the evidence. Added `godot/tests/passenger_carry_driver.gd` and the
  `godot-passenger-carry` gate.
- **Two instrument errors, caught before reporting:** (1) holding `move_forward`
  for a full 5 s period walked the passenger off a 2.4 m deck at 0.15 s and
  reported it as a carry failure — that is arithmetic about deck width, not a
  finding; (2) `ABOARD_LIMIT` was 1.0 m from the deck origin while the deck's own
  half-width is 1.2 m, so it called a passenger "off" while they were still
  standing on it. Both corrected; the case now measures one footfall against the
  real deck edge.
- **Remaining limit:** drift up to 0.609 m is transient lag while the deck
  *accelerates*, recovered afterwards. It is a function of the carrier's
  acceleration profile, so it is a **P2 tuning input**, not a defect.
- **Consequence for the carrier (design input):** the shipped 2.4 m deck is
  crossed by a walking rider in ~0.4 s. A skiff whose passenger moves to aim or
  take cover needs a deck sized from the rider's movement; 2.4 m must not be
  inherited from `MovingPlatform`.

## Full-Amalgam matrix

*(built incrementally per plan §4 — never a prerequisite to starting)*

## Playable milestones

| Milestone | Build/ref | Launch/mode/save | Actual continuous player path | Test shortcuts | Owner verdict |
|---|---|---|---|---|---|
| 0.3 candidate | `19c5d8e` | production mode | exit/hold patch unplayed by owner | — | not yet played |

## Checkpoint

- **Last completed milestone:** M0 (in progress).
- **Current coherent tree:** `19c5d8e` on `claude/archipepsi-0-4-blindside`.
- **Exact next action:** P0 — measure the passenger carry.
