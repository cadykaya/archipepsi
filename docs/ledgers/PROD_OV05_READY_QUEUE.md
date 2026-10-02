# Overnight 05 — ready queue, filled (Prod)

The pristine queue is `ov05/03_READY_QUEUE.md`, and it is unchanged.
This copy fills in each unit's status. Detail and evidence for every
row are in `PROD_OV05.md` under the same number.

**Statuses:**

- **CLOSED** means done at the scope the unit states.
- **PARTIAL** means some of it is done; the rest is named on the row.
- **BLOCKED** means a named decision is missing, and the row says whose.
- **NOT STARTED** means not reached. It is still ready work.
- **BOUNDARY** means it is not buildable without a design decision, and
  the row names that decision.

Revisions are commits on `claude/archipepsi-0-4-blindside`. The frozen
full run is recorded in `ov05_evidence/FROZEN_RUN.md`.

## O05-00 — Preserve, reconcile and start

- [x] **O05-00.1 — Protect the delivered checkpoint** — CLOSED. `330c555` preserved at the new ref `review/ov05-start-330c555`; the protected refs are untouched (ledger "Start").
- [x] **O05-00.2 — Reconcile the first dependencies** — CLOSED. See the ledger section "Reconciliation (O05-00.2)".
- [x] **O05-00.3 — Persist this work order and ownership** — CLOSED. The packet is verbatim in `ov05/`. The temporary shared-seam table lists every edit to Dess's files, with source rules and commits, for her review.
- [x] **O05-00.4 — Start a code unit** — CLOSED. `ae8bcb7` (O05-01).

## O05-01 — Ordinary hand carry, actually operated

- [x] **O05-01.1 — Implement the selected pickup/drop interaction** — CLOSED. `ae8bcb7`, `hand_carry.gd` (Design 2 §10.3–10.4).
- [x] **O05-01.2 — Keep it physical** — CLOSED. `ae8bcb7`. A swept hold: the object touches walls and is never inside them. A drop at rest. `godot-carry` 32.
- [x] **O05-01.3 — Integrate input and feedback** — CLOSED. `ae8bcb7`. The real `interact` binding, HUD carry feedback, the 0.85 factor for MEDIUM, and the blocked slots.
- [x] **O05-01.4 — Prove both legal and illegal cases** — CLOSED. `ae8bcb7`. Exact refusals: 60.00 kg accepted, 60.01 kg refused, LIGHTENED 70 kg refused. 2 sabotages.

## O05-02 — Carry one required object across rooms and use it

- [x] **O05-02.1 — Build from the delivered declaration** — CLOSED. `5902920`/`f1fc737`. `compose_transport` in a composed Zone. `test_transport_route.py` 51.
- [x] **O05-02.2 — Traverse actual connections** — CLOSED. `f1fc737`. The real Player carries the cell c004 → c005 across the connector. `godot-transport` 106.
- [x] **O05-02.3 — Install in the real consumer** — CLOSED. `f1fc737`. `ObjectSocket` by `interact`; the wrong part is refused; the declared doorway opens.
- [x] **O05-02.4 — Preserve authority and uniqueness** — CLOSED. `f1fc737`. Python holds room, pose and consumption. Forgeries are refused by name, in bridge tests and live.
- [x] **O05-02.5 — Demonstrate Status continuity separately** — CLOSED. `f1fc737`. The real LIGHTENED applicator; the Status crosses the threshold on its own clock; the kilograms are unchanged.

## O05-03 — Restore and recover the transported-object journey

- [x] **O05-03.1 — Persist the accepted physical facts** — CLOSED. `object_poses` and `consumed_objects`, ZONE_PERSISTENT.
- [x] **O05-03.2 — Restart at two meaningful points** — CLOSED. `godot-transport-live`: seed, place, restart, install, restart, restore. All OK at `400ed37`.
- [x] **O05-03.3 — Restore in the right order** — CLOSED. Both are handed to the Zone before build (P5-3). Seated at load, the doorway is open, and nothing is announced.
- [x] **O05-03.4 — Recover without solving for the player** — CLOSED. Out of volume: 1.0 s. Destroyed: 2.0 s. Out of bounds: at once. Death: dropped where held (`godot-transport`).
- [x] **O05-03.5 — Isolate reset domains** — CLOSED. Its own facts only. Lever, latch and keys survive side by side in the candidate Zone.

## O05-04 — A reversible branch action changes machinery elsewhere

- [x] **O05-04.1 — Bind an existing D-8 configuration** — CLOSED. `5902920`, `compose_zone_state(mechanism="lamp")`.
- [x] **O05-04.2 — Make the consequence useful and visible** — CLOSED. The doorway itself opens and closes; a lamp in the next room. PENDING → ACCEPTED/REFUSED at the source.
- [x] **O05-04.3 — Verify reversal and escape** — CLOSED. `godot-reversible` 32/32, both configurations and reversal played.
- [x] **O05-04.4 — Respect machinery occupancy** — CLOSED. "CLOSING QUEUED · DOORWAY OCCUPIED"; applies once clear.
- [x] **O05-04.5 — Restart with the chosen configuration** — CLOSED. `godot-reversible-live`: seed, select, restore OK (`d92d723`).

## O05-05 — Earn the featured Echo and use it at Blindside

- [x] **O05-05.1 — Reconcile the acquisition seams once** — CLOSED. `d92d723`. The seam table and the three blockers are in the ledger. P5-9 (rail span persistence) is fixed.
- [ ] **O05-05.2 — Compose the intended structure** — BLOCKED on B-1 (a featured Check can hold the player's own item, which mints no Echo) — Dess/owner.
- [ ] **O05-05.3 — Acquire before use** — BLOCKED on B-2 (nothing makes the Echo supply the function; no qualification rule is selected) — Dess/owner.
- [ ] **O05-05.4 — Make the return matter** — BLOCKED behind 05.2.
- [ ] **O05-05.5 — Preserve the five acquisition obligations** — BLOCKED on B-3 (no pre-seed AP representation of the capability gate; `AP_CAPABILITY_LOGIC.md` is a proposal) — owner.
- [ ] **O05-05.6 — Handle failure without counterfeit success** — PARTIAL/BLOCKED. No walking bypass, no faked foreign item, no `blindside` step; the profile refuses the name. The failure path itself waits on B-2.
- [ ] **O05-05.7 — Resume the earned result** — BLOCKED behind 05.3.

## O05-06 — Integrate the three existing minors without changing their meaning

- [x] **O05-06.1 — Supported occurrence contract** — CLOSED. `83044c3`, `schemas/minors.py`; each room extracted rather than duplicated.
- [x] **O05-06.2 — Passing Platforms** — CLOSED. `400ed37`. In the candidate's second Zone; restarted mid-route (`godot-candidate-live` next/next_restore/next_final).
- [x] **O05-06.3 — Counterfire Arcade** — CLOSED. `6cbe5f2`. The Zone's own enemy is the gunner; restore is played.
- [x] **O05-06.4 — Unweighted Switch** — CLOSED. `6f96ca9`/`38f3fc4`. Played by hand and restored.
- [x] **O05-06.5 — Real reward and return consumers** — CLOSED. The parent's Check is moved onto each minor's goal gallery; the return is played.

## O05-07 — Broaden the shared graph through actual consumers

- [x] **O05-07.1 — Inputs the existing rooms need next** — CLOSED at the scope reached. `PULSE_BUTTON` (`a718654`) and `SHOOTABLE_TARGET` in PULSE mode (`384497b`), each with its room's consumer. TOGGLE is refused, because nothing reads it.
- [ ] **O05-07.2 — Useful logic nodes** — PARTIAL. `OR` (`a718654`) and `TIMER` (`384497b`) join NOT/LATCH. AND, DIRECT and SEQUENCE are not added: no consumer in the rooms reached asks for them.
- [x] **O05-07.3 — Shared wiring where meanings match** — CLOSED. EX50-033's and EX50-021's own chains run through the shared graph; `bind_declared` is shared.
- [ ] **O05-07.4 — Signal verbs and state** — NOT STARTED. All five verbs. The expiry of a temporary override waits on them.
- [x] **O05-07.5 — Sensor distinctions and safety** — CLOSED. `4276835`. Class-not-sum, duplicate occupancy, a repeated pulse and a stale callback, through the graph, each sabotaged. `godot-signal-graph` 57.

## O05-08 — Complete more of the twelve manipulation verbs

- [x] **O05-08.1 — PULL/HOLD/ALIGN/SETTLE** — CLOSED, runtime only. `7ca5945`, `394817b`. With PUSH; items 5, 7–10, 20, 21, 28 by direct invocation. SETTLE's mid-air sleep vs PIN's rationale is a named source conflict.
- [x] **O05-08.2 — TETHER/PIN/ROTATE** — CLOSED, runtime only. `2b60770`. The relations ledger (§31.2, §14.4). Items 11–13, 17, 22, 23.
- [x] **O05-08.3 — ATTACH/DETACH** — CLOSED, runtime only. `0f4c335`. A weld is one body. Items 14–16. Weld persistence is named, not built.
- [x] **O05-08.4 — Mass fields and Status interactions** — CLOSED, runtime only. `38b104f`, `44f2e0e`. Kilograms, not class. Items 18–19 and the two real sensors. `godot-verb-runtime` 95.
- [ ] **O05-08.5 — Delivery and qualification** — BOUNDARY. Delivery needs the Amalgam's atom grammar (costed atoms, a `physics_verb` discriminator), which the running Echo model implements for no verb. A primitive would be a parallel ability system. Qualification waits on delivery. Owner/Dess decision: the grammar, or how atoms are represented until it exists.

## O05-09 — Advance the effective Status family, not the legacy count

- [ ] **O05-09.1 — Kinetic and material consumers first** — PARTIAL. `7abb338`: `rooted` and `anchored` on an enemy, on their real consumers (movement, knock, verbs, per role), and once through a real on-hit in a declared arena. `godot-status-family` 15, with 10 sabotages. Remaining:
  - `anchored` on an object and the player;
  - `lightened` on an enemy and the player;
  - `slippery`;
  - `conductive`, which has no electric hazard to consume it;
  - `brittle`: its consumers exist (`DestructibleCover`, constraint `breakable_at`), but object Statuses have no Echo path, because on-hit is gated at the enemy.
- [ ] **O05-09.2 — Actor behavior, not damage substitutes** — NOT STARTED (confused, turncoat, blinded, silenced, exposed).
- [ ] **O05-09.3 — Safe temporary collision and interactions** — NOT STARTED (phased).
- [ ] **O05-09.4 — Compounds with real inputs** — NOT STARTED.
- [ ] **O05-09.5 — Preserve compatibility boundaries** — PARTIAL, kept for what was done. Legacy burning/poisoned are untouched. New support is per kind and target. Refusals leave no state and no event (`godot-stats` sweep). Owned-Status and rule-effect paths admit the new pairs at the bridge; only the on-hit path is played.

## O05-10 — Machinery and physical assemblies survive interruptions

- [x] **O05-10.1 — Apply the existing common contracts to actual occurrences** — CLOSED for the kinds this run touched. `4d006e5`. Power loss is untested: no occurrence has a power source.
- [ ] **O05-10.2 — Package-specific physical restoration** — PARTIAL. The Passing Platforms half is done (O05-06.2). No constrained assembly is in the candidate.
- [x] **O05-10.3 — Interrupted operations** — CLOSED. EX50-021's shutter reverses mid-closure from 0.591 with no snap.
- [ ] **O05-10.4 — Ownership and isolation** — PARTIAL. Two arcades keep two windows. Counters across repeated enter/leave/restart cycles are not measured.

## O05-11 — Make the corrected consumable path useful in the candidate

- [x] **O05-11.1 — Reuse authorization before launch** — CLOSED. `65f3ef4`.
- [x] **O05-11.2 — Close any specific outstanding promotion condition** — CLOSED. `65f3ef4`; commitment ordering holds.
- [x] **O05-11.3 — Exercise normal acquisition/creation** — CLOSED, bridge and engine. `65f3ef4`, `b27bee5`. Acquired, folded, slotted, spent, kept. The owner's related-Echoes rule is applied. A live Godot run of the naturally acquired bomb is not claimed.
- [x] **O05-11.4 — Candidate-only promotion** — CLOSED. `CANDIDATE_ACTION_SLOTS`; `IMPLEMENTED_ACTION_SLOTS` and production defaults are unchanged. Capacity as an upgradable field is an owner question.

## O05-12 — Improve encounter relationships and legibility in existing content

- [ ] **O05-12.1 — One controlled placement comparison** — NOT STARTED.
- [ ] **O05-12.2 — Preserve intended counterplay** — NOT STARTED as a unit. The Bulwark flank and the roster behaviours are unchanged, and O05-09.1 names per-role counterplay under `rooted` and `anchored`.
- [ ] **O05-12.3 — Ground navigation and doorway occupancy** — NOT STARTED.
- [ ] **O05-12.4 — Truthful event instrumentation** — NOT STARTED.
- [ ] **O05-12.5 — Make consequences understandable** — NOT STARTED.

## O05-13 — Let the real candidate composer use the supported systems

- [x] **O05-13.1 — Candidate configuration, not fixture laundering** — CLOSED. `f1fc737`. A profile of the real composer.
- [x] **O05-13.2 — Offer meaningful choices** — CLOSED at the canonical set. It is not an expressive ceiling.
- [x] **O05-13.3 — Keep all identities and outcomes** — CLOSED. Re-certified, not trusted. `candidate/<zone>.json`. A bounded sample was regenerated on clean trees (`f4a938e`, `074627f`, `a63a319`, `0f4715a`).
- [x] **O05-13.4 — Use available provider paths honestly** — CLOSED. Deterministic fallback, labelled. No live model; mock multiworld.

## O05-14 — Consume existing visual work without restarting Arty

- [x] **O05-14.1 — Bind already approved assets where ready** — CLOSED as reconciled: nothing approved and ready to bind (no delivered enemy or machinery models).
- [x] **O05-14.2 — Make the pack path maintainable** — CLOSED as reconciled: D-11's lookup, family fallback and pack-aware caches stand.
- [x] **O05-14.3 — Review candidates without promotion** — CLOSED as reconciled: no candidate pack is available. Nothing was approved or promoted.

## O05-15 — Keep a playable build available before the entire queue finishes

- [x] **O05-15.1 — One clear launcher family** — CLOSED. `Diagnostic Campaign - Candidate (Windows).bat` / `python -m archipepsi_bridge.diagnostic --candidate`. Windows execution is not claimed.
- [x] **O05-15.2 — Normal lifecycle, no test-only superpowers** — CLOSED. The real Main, client and bridge.
- [x] **O05-15.3 — Preserve a green checkpoint early** — CLOSED. `f1fc737` verified with the whole profile played. This frozen run is the second checkpoint.
- [x] **O05-15.4 — Prepare owner review** — CLOSED. `PROD_OV05_ROUTE.md`, `PROD_OV05_ANSWERS.md`, `make candidate-shots`.

## O05-16 — Continue the named ready reserve instead of stopping early

- [ ] **O05-16.1 — Finish remaining verbs/sensors/status pairs** — PARTIAL. All twelve verbs have runtime-only evidence (O05-08.1–.4), and two Status pairs are done (O05-09.1). Remaining: delivery (08.5), the rest of O05-09, and the O05-07.2/07.4 kinds.
- [ ] **O05-16.2 — Existing railway network breadth** — NOT STARTED.
- [ ] **O05-16.3 — Gear/mod runtime where costs already exist** — NOT STARTED.
- [ ] **O05-16.4 — Approved transaction consumers only** — NOT STARTED.
- [ ] **O05-16.5 — Assembled runtime and generation recovery** — NOT STARTED.

## O05-17 — Final verification, evidence and stop

- [x] **O05-17.1 — Freeze one integrated revision** — see `ov05_evidence/FROZEN_RUN.md`.
- [x] **O05-17.2 — Preserve evidence distinctions** — CLOSED. Actual input, world effect, authoritative state, restart, direct invocation and injected components are labelled per row.
- [x] **O05-17.3 — Close the selected continuous journey** — see `FROZEN_RUN.md` (`godot-candidate-live` in the run).
- [x] **O05-17.4 — Inspect generated differences** — see `FROZEN_RUN.md`.
- [x] **O05-17.5 — One handoff, playable things first** — `PROD_OV05_MORNING_REVIEW.md`.
- [x] **O05-17.6 — End cleanly, not automatically** — no heartbeat, watcher, subscription or schedule is armed.
