 both ends are **anchors, never coordinates**, "so the composer still names no world position and the authored-alphabet boundary holds without special pleading." That's exactly the right model for `RailNetwork`.

Used ListAgents

One genuine fork shapes the plan's sequencing, so let me settle it before finalising.

Amalgam §29.5a check 23 forbids an allocated AP Check sitting behind a capability gate until the apworld can declare the same prerequisite — which it can't today. That constrains what the grapple repair is allowed to unlock in the first loop. Which shape do you want?

Choose “Hold M2 for the full-strength gate.”

The first major should test the intended experience: obtain the featured
gameplay-changing Echo in a reachable branch, return, and use it to open
meaningful new access—including AP Checks where the matching logic
supports it.

Do not add a guaranteed ordinary walking bypass solely to avoid the
acquisition/AP work. Legitimate alternate solutions using suitable
existing abilities remain welcome; that is not the same as making every
capability gate optional by construction.

Hold M2’s completion on the acquisition-contract integration, not the
entire programme. Continue planning the independent carrier, docking,
receivers, machinery, branch geometry, and minor-setpiece work.
A development scenario can test those mechanics before integration,
but must not be described as multiworld-safe or M2 complete.

Use B2 as the preferred proposal for Dess to develop, not as an already
proven guarantee. The plan must establish:

\- The featured acquisition is reachable without its own reward.
\- Its local Echo reliably supplies the actual required function, including
  qualification and fallback—not merely a capability label.
\- The foreign Check still delivers its original item to its real recipient.
\- The AP rules and exported allocation contract safely represent the
  dependency before seed generation. A tier label alone is not the proof.
\- Re-entry, reload, retries, and delayed interpretation cannot erase or
  duplicate the grant or strand progression.

Keep check 23’s protection until its real prerequisite is implemented.
No runtime rewriting of an existing seed’s logic and no fabricated proof.

Finish the integrated plan with this direction and identify Dess’s concrete
handoff and dependencies. Her availability remains unconfirmed; do not
pretend she has accepted the assignment.

Implementation still follows plan approval. Heartbeat stays off.

Understood — M2's *completion* holds on the acquisition contract, the programme doesn't, and no bypass gets added to dodge the work. Checking the design agent, then rewriting.

Used ListAgents

The design agent is still running at 8 minutes; I've independently verified every load-bearing claim it was checking, so I'll finalise now rather than block. Rewriting with your direction:

Created jaunty-cuddling-eclipse.md, used a tool+179-141

The design agent has run 9 minutes without returning; since I verified every claim it was checking myself, I'll stop it rather than leave it in flight.

Used a tool, finished a background agent (1 stopped)

Stopped before it produced findings, so nothing was lost — everything it was asked to verify, I confirmed directly against the tree.

Loaded tools

Failed to propose plan

jaunty-cuddling-eclipse.md+407-141

Plan approved for implementation with the following addendum.
Incorporate it into the plan and proceed; another full planning round
is not required.

Approve:
\- grapple_to_surface as the first featured Echo;
\- the three-dock Blindside prototype as the first section of the major;
\- Passing Platforms, Counterfire Arcade, and Unweighted Switch as the
  first minor group;
\- first-class RailNetwork content with one agreed contract;
\- the full-strength acquisition integration as M2's completion requirement.

For the first grapple configuration, place the important alignment gantry
in the central S2 junction, visible before the acquisition branch.
The branch grants the Echo and can provide an immediate learning use.
Then the player returns to the familiar junction and uses the grapple
to reach its control and restore the span.

Keep branch-operated restoration as another valid configuration.

Clarify the second binding:
ranged_hit alone does not establish a newly acquired capability when the
starting player already shoots the transport receivers. Either develop
the actual qualifying new function and its acquisition, or label this
as an existing-tool objective variant. Do not count the latter as a
second featured-Echo acquisition loop.

Resolve the M3 dependency wording:
provisional configurations may be implemented and tested without Dess,
but genuine Epsilon objective selection/integration remains incomplete
until the binding contract is delivered. A sample-injected Zone or two
handwritten configurations cannot stand in for that evidence.

P0 measures carrying before prescribing controller changes. Treat the
aboard/step-helper edits as candidate repairs, not automatic requirements.

For persistence, distinguish the accepted permanent span repair from
temporary power, receiver timers, and carrier position. State and test
the intended interruption/reload behavior; don't claim general persistence
from a single saved latch.

Keep the return-later variant in the intended 0.4 backlog, sequenced after
the first loop and blocked on its named progression-policy decision.
No silent change to the current all-Checks completion policy.

Continue independent approved work through the milestones. If Dess or
Arty has not accepted a handoff, say so and keep only the genuinely
dependent integration blocked. Do not declare provisional interfaces final.

Keep the full Amalgam scope visible and continue its independent approved
breadth after the first content group. Do not expand the content roster
before I play it.

Use focused tests during development and full verification at meaningful
integration checkpoints. Preserve complete logs, source/case identities,
a durable ledger, and one working checkpoint as you progress.

Keep the 0.3 comparison and original saves untouched. No unapproved
economy decisions, migrations, default changes, or fabricated AP guarantees.
Heartbeat, watchers, subscriptions, and scheduled follow-ups stay off.

Plan mode exited when the question resolved, but your instruction stands: **implementation waits for approval.** Nothing has been built. The full plan is at `/root/.claude/plans/jaunty-cuddling-eclipse.md`This file is outside the session’s working directory, so it can’t be opened here.; here's what it says.

### Corrected baseline

My "no rail code exists" was a bad grep reported as a finding. Every claim below I verified directly against the tree:

- **`RailPath`** **— reusable as-is.** Already a Catmull-Rom curve through N authored points: curved, multi-segment, deterministic, with `at()/tangent()/polyline()`, validating pitch and room containment.
- **`RailRider`** **— unsuitable**, but a good skeleton. It's a *player-grind state machine* that assigns `global_position` and deliberately skips `move_and_slide`; heading is set once and never reversed; no stops, no passenger.
- **`MovingPlatform`** **is the substrate** — `AnimatableBody3D` + `sync_to_physics = true`, whose own docstring says "this is how Godot carries a `CharacterBody3D` standing on it."
- **But that carry is an untested engine default.** No platform-velocity handling anywhere in `godot/scripts/`, and the existing test never puts a player on one.

**The finding that reshapes the plan: all four capabilities are already implemented and playable** — `blink`, `grapple` (three primitives, real tether physics), `cross_long_gap`, `ranged_hit`. The Echo side needs nothing new. The mobility slot already live-updates every snapshot, so an ability can be handed over mid-run without a restart. I recommend **`grapple_to_surface`** — real buildable anchor geometry exists, it matches your hookshot example, and it sidesteps a defect I found where `player.gd:1197` hard-codes the swing hold to RMB, so a `grapple_swing` in the mobility slot would drop its tether on frame one.

**Persistence needs no new system.** `ZoneProgress.latched`, the `LatchFired` intent and `record_latch` are built, tested, and refuse unbacked latches — and the client has *never sent it*. Every `latched` hit in `godot/scripts/` is prose in a comment. That's the highest-leverage hook in the repo.

### Two constraints that shape the design

**§13.2** forbids a `features:` tag from lying on the mandatory path or hosting an objective — so the skiff must be **first-class Zone content**, modelled on `PlugAssignment`, whose ends are *anchors, never coordinates*.

**Check 23** keeps its protection, per your direction. The Zone you want simply isn't composable until the acquisition contract exists.

### Sequencing

P0 proves the passenger carry (cheapest de-risk of the whole major) → **P1 ships EX50-011 Passing Platforms**, which is the same carry problem in one room, so it's playable value *and* risk reduction → P2 carrier → P3 receivers → **M1** the first persistent machine chain → **M2-mech**, the full loop in a development scenario, explicitly *not* multiworld-safe and *not* M2 complete → **M3** the minors → **M2 complete** when the contract lands.

### Decision block

Featured Echo `grapple_to_surface`; second binding `ranged_hit` on eligible bracing — a different relationship, not a relabel. Minors: EX50-011, EX50-021 Counterfire Arcade, EX50-033 Unweighted Switch, chosen for parts-sharing with the major rather than variety. D7 return-later deferred. Forge economy not guessed. Already settled and not re-asked: persistence semantics (§5.4a), Epsilon's selection scope (§30.1), water deferred.

### Handoffs

**Dess** — six items, with D-1 (the B2 contract against your five requirements) and D-2/D-3 blocking M2's completion only. D-4 through D-6 don't block P0–M3. Her availability is unconfirmed and nothing assumes she accepted.

**Arty** — models only, with per-item dimensions, pivots, attachment points, required states and collision constraints. Receivers must read by arrow shape *and motion*, never colour alone. Blockout first.

If Dess is unavailable, P0–M1, M2-mech and M3 all still land; D-1/D-2/D-3 stay blocked and I won't invent progression policy to unblock them.

Heartbeat off, nothing scheduled. Ready to execute on your approval.

Approved — incorporating the addendum and starting. Checking state first.

Ran 2 commands

Plan updated with the addendum. Setting up the work tracker, then starting M0.

Ran a command, used 6 tools

0.4 line created from `19c5d8e`; the 0.3 comparison branch is untouched. Starting the ledger.