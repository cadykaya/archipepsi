# AGENT FRONTIER

## PROD LANE — Overnight 05 in progress: carry, delivery, reversible lever, candidate launcher, all three minors in Zones — 2026-09-23

**Assignment:** the owner's Overnight 05 work order,
`docs/ledgers/ov05/01_EXECUTION_PLAN.md` (verbatim copy, checksums
verified). Execution log, shared-seam table for Dess, and findings P5-1
to P5-16: `docs/ledgers/PROD_OV05.md`. Branch
`claude/archipepsi-0-4-blindside`. The start is protected as
`review/ov05-start-330c555`. **No heartbeat, watcher, subscription or
scheduled job is armed.** Dess and Arty stay paused, and this lane is the
one writer.

**Where it stands (details in the ledger rows):**

- **O05-01, hand carry: closed** (`ae8bcb7`).
- **O05-02/03, the required cell: verified.**
  - `godot-transport` passes 106/106. `godot-transport-live` passes all
    four phases: seed 6, place 16, install 18, restore 12. Real
    restarts, with the save read back off disk.
  - The composer only uses one-floor, walkable rooms (P5-2, P5-8).
- **O05-04, the reversible lever: verified.**
  - `godot-reversible` 32/32. `godot-reversible-live` seed 3,
    select 9, restore 3. `godot-zone-state` 60, after the P5-10 fix.
- **O05-05, the Blindside loop: reconciled and BLOCKED; M2 is partial.**
  - Three policies are missing: a featured Check can hold the player's
    own item; nothing qualifies the grant; there is no pre-seed AP
    representation.
  - The composed railway's span persistence is fixed (P5-9).
- **O05-13, the candidate profile: played whole.**
  - `godot-candidate-live` seed 38, play 20, restore 5. Its first run
    found P5-11 (two controls in one room); fixed.
  - The profile's Zone is re-certified by `validate_zone`, and a result
    that introduces an error is discarded whole.
  - Bounded sample: 12 cases (`docs/ledgers/ov05_evidence/candidate_sample.json`).
    Every case was certified and kept its Checks; transport declined
    once, by name.
- **O05-06, the minors: all three integrated, played and restarted.**
  - The candidate `minors` step ADDS each minor behind its own dead-end
    arena (P5-13) and moves that arena's Check onto it. Each Zone has
    room for two, so the offer order turns with the Zone
    (`minor_hosting.offer_order`, this lane's rule, recorded for Dess):
    zone_001 hosts EX50-033 + EX50-021, zone_002 EX50-021 + EX50-011.
    Sample at `3f6c1d3`: EX50-033 in 7 of 12 Zones, EX50-021 in 7,
    EX50-011 in 8; all certified, every Check kept.
  - EX50-021's gunner is the chamber's own declared enemy (§9).
  - EX50-011's carriers persist their REST (pose, destination, hold) in
    the new `ZoneProgress.carrier_states` (`PUZZLE_LOCAL`), recorded only
    at rest and accepted only for a declared carrier and stop. Played in
    zone_002, reached by abandoning zone_001 from the pause menu; a
    restart restores the shuttle HELD mid-track and the route is
    finished from it.
  - `godot-candidate-live` now has eight phases: seed 40, play 20,
    restore 5, minor 32, minor_restore 15, next 21, next_restore 18,
    next_final 7 (one run at `400ed37`, with the other live suites
    green around it).
  - Findings this segment: P5-16 (EX50-033's rails were a bypass), P5-17
    (the room audit measured side exits on the far wall), P5-18
    (EX50-011's stair ended against a railing). Earlier: P5-12 (budget),
    P5-14 (the mock forgot confirmed Checks).
- **O05-07, the shared graph: slice 1 done.** EX50-033's chain is
  declared in its minor contract and run by the shared `SignalGraph`:
  PULSE_BUTTON and OR join, with §19.1's port forms enforced. A Zone may
  still declare only plates, and a route gate still hangs only on
  plate/NOT/LATCH. `godot-unweighted` 69, where 7 checks read the graph
  itself, plus a sabotage showing the runtime is what drives the room.
  EX50-021 is deliberately not routed: its window is the shutter's own
  timer. Landed at `a718654`, with `godot-candidate-live` all eight
  phases.
- **O05-07 slice 2: EX50-021 through the graph: done.** The arcade's
  own chain, as §3 names it: the receiver's pulse feeds an 8 s TIMER;
  the TIMER and the release's LATCH meet in an OR that drives the
  shutter. TIMER and SHOOTABLE_TARGET (PULSE) join. `[RANGED]` is a
  floor, not a filter, because the runtime has no damage tags; that gap
  is stated. `ServiceShutter` lost its private clock. Slice 1's
  "not routed" note misread §3 and is corrected. `godot-counterfire` 55;
  candidate-live all eight phases; `make test-bridge` 1907.
- **O05-11: consumables promoted for the candidate only.** The
  `candidate.OPTIONS` option `consumables` is included in `all`; its
  requests advertise the slot and the gate admits exactly that.
  Production stays STAGED. Offered the slot, the fallback reads a Bomb
  Bag as three stun bombs. Claim, fold, slot, authorize, settle and
  reload are proven through the real engine with one arranged item name.
  The BOUNDARY (the sequel rule folded every Bomb Bag into an owned lob)
  is SETTLED by the owner's direction of 2026-09-23 and applied. A
  sequel needs the same reading of both sources, the same slot and a
  change of at least 25%, never the verb alone. The campaign's own Bomb
  Bag is now bombs, unarranged. Capacity is not an upgradable field
  (named gap). P5-19: projectiles now apply their on-hit status.
- **O05-08: answered, and bounded.** The verb RUNTIME is a faithful,
  bounded integration within authority. Echo DELIVERY needs the
  Amalgam's composition grammar (atoms, costs, discriminators), which
  the running Echo model does not implement for any verb, so a
  primitive would be a parallel path. That is a design boundary, not a
  missing mapping. Qualification waits on delivery.
- **O05-08.1: PUSH, PULL, HOLD, ALIGN and SETTLE, runtime only.**
  - One §14.2 table (`Manipulation.target_refusal`) serves every
    targeted verb.
  - HOLD sweeps its step at up to 8 m/s, passes through actors, and
    watches 7 release conditions. ALIGN turns over 0.3 s, then holds on
    the solver's axis lock for 2.5 s. SETTLE leaves FIXED, withheld and
    machine-driven bodies alone.
  - Design 2's acceptance items 5, 7, 8, 9, 10, 20, 21 and 28 are proven
    by direct invocation. `make godot-verb-runtime`: 56 checks, 1 note,
    10 sabotages.
  - Named source conflict: SETTLE's forced sleep holds an unsupported
    body in mid-air (0.003 m in 1 s) against PIN's short-duration
    rationale. It is unreachable while nothing delivers the verb.
- **O05-14: reconciled, nothing to bind.** No delivered enemy or
  machinery models exist; the 3 projectile visuals stay `pending`.
- **O05-10 in part: 10.1 audit, 10.3 reversal, 10.4 isolation.** Every
  doorway machine this run built is one `ServiceShutter` through the
  shared `SafeClosure`. EX50-021's shutter reverses mid-closure from
  where it was (0.591, no snap). Two arcades keep two windows, and a
  room freed mid-window reaches nothing. Each check was sabotaged. Power
  loss and a constrained assembly remain untested here.
  `godot-counterfire` 59.
- **O05-07.5, sensor safety: done (tests only).** Class-not-sum,
  duplicate occupancy (every plate answer recorded), a repeated pull,
  and a stale callback, each through the graph and each sabotaged.
  `godot-signal-graph` 57, `godot-unweighted` 70. Repeated shots wait
  on SHOOTABLE_TARGET.
- **O05-15, the launcher: built.**
  - `Diagnostic Campaign - Candidate (Windows).bat`, or
    `python -m archipepsi_bridge.diagnostic --candidate`.
  - Owner route: `docs/ledgers/PROD_OV05_ROUTE.md`. Answers:
    `docs/ledgers/PROD_OV05_ANSWERS.md`.
  - Review frames: `make candidate-shots`, through the player's camera.

**Next, in the plan's order:**

1. O05-07 further slices (TIMER/AND/DIRECT and sensors each with a
   real consumer; signal verbs), then O05-08 onward
   (manipulation verbs, Status, machinery interruptions, consumables,
   encounters, art binding). O05-10.2's Passing Platforms half is done
   with O05-06.2.
2. The O05-17 frozen run and ZIP.

## PROD LANE — P14 played and persisted, D-11 on the geometry: integration batch closed — 2026-09-23

**STOPPED here, by instruction.** This batch consumed Dess's `9ef2676`
(P14) and `83a8e7e` (D-11) and nothing else. Dess and Arty are paused.
Do not continue into P12, P16, P19, new theme packs or broader campaign
generation without a new instruction. **No heartbeat, watcher,
subscription or scheduled job is armed**: the next task starts by
turning one on, if it needs one.

**Tested revision:** `57e962e` on `claude/archipepsi-0-4-blindside`,
frozen (clean tree) for the whole run. The handoff commit on top of it
changes documents only. These are **local results**. Remote CI
availability is a separate question and was not polled.

| set, as CI runs it | local result on `57e962e` |
|---|---|
| `make test` | **1933 passed** (627 subtests), 211 s |
| `make smoke`; `python3 docs/design-packet-v0.8/check_packet.py`; `make export` + `git diff --exit-code` over the generated artifacts | green; nothing stale |
| `make godot-import`; `make doctor` | green |
| the 41 "Headless Godot suites" (the CI step's list). New in this batch: `godot-latched-route` **38 checks** and `godot-theme-pack` **30 checks**. Changed: `godot-mass-class` 59, `godot-signal-graph` 46 | **41 / 41 OK** |
| `godot-consumable-live`, `godot-consumable-restart`, `godot-latched-route-live` (seed 2 / play 18 / restore 12), `godot-ordinary-live`, `godot-integration`, `godot-integration-quiet`, `godot-integration-variant-live`, `godot-reload` | **8 / 8 OK** |
| `make version` | ok |

**56 of 56 steps passed, and nothing failed or was re-run.** The run
took 01:56–02:38 UTC. `make godot-zone-audit` restamped its five
generated placement captures (`controller_digest`, `source_commit`),
because `zone_controller.gd` changed. Those restamps are committed with
this handoff, and `test_placement_contract.py` passes on them.

**P14: delivered.** The per-row detail is in
`docs/D10_P14_PROD_ANSWER.md` §7.

- `ClassPlate.counts_player` is false by default, and EX50-033 is
  unchanged.
- `Player.mass_class()` reads the exported mass and ladder. Only
  `ClassPlate` reads a player's class.
- The route shutter is built across the `opened_by` doorway from the
  committed door frame.
- Accepted latches are restored before the first graph evaluation and
  settled without an announcement.
- `godot-latched-route` (38 checks) plays the fixture with the real
  body: arrive, clear the arena with the base kit, press at the shut
  doorway, step on, step off, walk into `c003` and back. The control
  with no `LATCH` is stopped at the door.
- `godot-latched-route-live` (seed 2 / play 18 / restore 12 checks)
  runs on a disposable save:
  - the real path generates `zone_001`, and the compose tool proves it
    is exactly Dess's fixture (`508868a38b2fd508`, no re-keying);
  - the real `Main` enters and gets the bridge's own verdict;
  - the real `latch_fired` is accepted and read off the save file as
    `graph_c002/held`;
  - forged latches are refused (uncommitted, unknown latch, no graph,
    unplaced room);
  - both processes restart, and the route is open before the plate,
    with nothing announced.

**D-11: delivered.** The per-row detail is in
`docs/D11_THEME_PACK_PROD_ANSWER.md` §7.

- The resolution order is the exact `<pack>/<theme>/<role>` first, then
  the family chain unchanged. There is no pack hop.
- The `(pack, theme, role)` cache and a pack-keyed material cache.
- Only `selectable` or `approved` packs bind.
- Universal-role pack rows are refused.
- The Zone binds its pack and the Hub binds none (owner-replaced), so
  nothing leaks.
- `godot-theme-pack` (30 checks) proves it on the materials of built
  meshes, with in-memory test-scoped packs. `make theme-pack-shots`
  renders it.

**Engine defects found and fixed on the way:**

- Enemies acted on a player the layout verdict was holding: 80 hp lost
  at the arrival to five artillery shells.
- A declared route gate read as a solid doorway, and the bridge refused
  the live layout.

Both have regression checks and were sabotage-checked.

**Launch or replay the latch-route candidate:**

```
make godot-latched-route          # standalone, ~95 s
make godot-latched-route-live     # seed -> compose -> play -> restart -> restore, ~85 s
make latched-route-play           # by hand, windowed, on .latched-route-play/ (FRESH=1 reseeds)
```

`docs/P14_LATCHED_ROUTE_REPLAY.md` says what to do in the game.

**Limits, stated:**

- The by-hand launch was not run windowed here, because there is no
  display. The same client path runs headless in the live gate.
- The latch closes one permanent interaction, not the cross-room puzzle
  programme.
- No production pack is selectable, and `THEME_PACK_STATUS` is `{}`.
- Consumables stay staged as agreed; D-9 was not reopened.
- **Observed in passing, not worked:** artillery shells hit a
  stationary player here. Five shells did exactly 80 hp to the held
  player at 20.6 m. That is a data point for the P08 note in
  `NEXT_STEPS.md`, not a P08 test.

---

## BRIDGE LANE — P14's latch on a route, and D-11's pack identity: handed off — 2026-09-22

**Tested revision:** `83a8e7e` on `claude/archipepsi-0-4-blindside`.
`make test` **1887 passed, 6 skipped**; `check_packet` green; exports
and both Zone fixtures regenerated through `make export`,
`make zone-fixture` and `make latched-route-fixture`. **No Godot suite
was run in this container** — there is no engine binary here — so every
engine-side claim below is Prod's to verify.

**Delivered:** `9ef2676` (P14 bridge half) and `83a8e7e` (D-11 bridge
half). Exact contracts: `docs/D10_P14_PROD_ANSWER.md` §5 and
`docs/D11_THEME_PACK_PROD_ANSWER.md` §5.

**P14.** LATCH is supported and exported (one input, no reset; a latch
set at rest is refused everywhere). `SensorNode.counts_player` defaults
false, preserving EX50-033. The route validator reads the chain that
drives the gating actuator and uses `plate_accepts_player` — the flag
first, so the player's mass alone never counts for an object-only
plate. Reachability models each route latch as a permanent variable
(search only) and refuses a trigger behind its own route by name.
`record_latch` accepts `graph_<room>` only for a declared LATCH in the
accepted Zone with a committed layout that placed the room; `graph_` is
reserved from physics packages, whose path is unchanged.
`compose_latched_route` (explicit step) → `latched_route_zone.json`:
plate and latch in `c002`, shutter across `e:c002:c003`.

**D-11.** `Zone.theme_pack` beside the unchanged six families; candidate
(descriptor rows) / selectable / approved (`THEME_PACK_STATUS`, empty)
kept apart; `pack_textures` contract and `resolution_order` with no
pack hop; universal roles refused for packs. Nothing selected, no asset
touched.

**Remaining runtime work, Prod's:** P14 — `ClassPlate` honours
`counts_player`; `Player.mass_class()` from `PLAYER_MASS_KG`;
`RoomGraphs.build` places the shutter across the `opened_by` doorway;
the played acceptance on `latched_route_zone.json` (step on, step off,
walk through with the base kit, normal save/reload, still open).
D-11 — the pack key in `_resolve`, `(pack, theme, role)` cache keys,
universal-role refusals for packs. **D-9** stays as agreed
(authorization before launch); consumables remain staged until the
combined feature is ready for promotion.

---

## BRIDGE LANE — three proposals on the table, one of them load-bearing — 2026-09-22

Coordination round. Each of these is one half of a contract with two
owners, and each says so in its own file rather than being announced as
settled.

**D-9 — consumable expenditure (`docs/D9_CONSUMABLE_ACCOUNTING_PROD.md`).**
A dropped socket and a dead process fail differently: retaining and
retransmitting an in-memory pending list closes the first completely and
cannot close the second. So the charge moves at AUTHORIZE time, before
anything irreversible, and reaches the disk there;
`ConsumableAuthorization` exists only so an unlaunched attempt can be
cancelled. Keyed by `(component, generation, use_index)` — the trio the
spend already checks — so two presses in one cooldown are two records
and cancelling the second leaves the first standing. Proven across a
real process boundary on the bridge side. **Not proven end to end**: the
client still launches first and reports after. Found on the way: the
settle branch was unreachable behind the "next index due" check.

**D-10 — the chain on a route (`docs/D10_P14_CHAIN_ON_A_ROUTE_PROD.md`).**
`TopologyEdge.opened_by` puts the gate on the edge, where reachability
reads. The base-kit question is arithmetic: the player is 80 kg
(MEDIUM) and §10.3 caps carrying at 60 kg (also MEDIUM), so `HEAVY`
needs a pushed object and therefore a capability `graph.Capability`
deliberately cannot name — the declared HEAVY chain may not gate a
route, and the refusal says that instead of inventing a prerequisite.
**The finding:** with `PRESSURE_PLATE` and `NOT`, a chain can only DENY
a route. `plate → NOT → shutter` rests open; `plate → shutter` rests
closed and is D-8 §11.2's held requirement wearing a room graph.
Opening a route needs `LATCH`, which §19.2 names and nothing
implements. Two candidates put to Prod.

**D-11 — game-pack identity (`docs/D11_THEME_PACK_IDENTITY_PROD.md`).**
One optional `Zone.theme_pack` beside the unchanged six-member
`Zone.theme`, one extra lookup key ahead of the existing fallback chain.
**Deliberately unbuilt** pending agreement.

---

## BRIDGE LANE — the carry line exists, and the killed write is a real kill — 2026-09-22

**Mass semantics, verified rather than assumed.** Design 2 §10.3 governs
ordinary pickup (`carriable == true` AND `mass_kg <= 60`);
`ENVELOPE_MASS_KG`'s 120 is one of three numbers a HOST must meet to be
a qualified manipulation provider. The 120 side was correct everywhere
it appeared. **The 60 side had no consumer at all** — design prose and
one art preview's row labels, no named constant on either side — so
nothing conflated them and nothing enforced §10.3 either. It was already
load-bearing in one place: `TransportedObject`'s own first sentence is
"an object the player carries between rooms", and a 320 kg `BALLAST`
validated. `physics.CARRY_MASS_KG` and `carriable_by_hand` now name it
once, exported, with `TransportedObject` handed the case that fails it.
Prod's `3b67921` correctly kept the residual: **no runtime consumer**,
because the carry verb is P12. A GDScript helper for a verb that does
not exist would be the inert framework this lane refused for P14, so
instead the exporter attaches a note to each mass and a test fails if
either is met bare in `constants.gd`.

**P04's cold-restart evidence, corrected on the owner's finding.** The
permanent/reversible case said in its docstring that the reversal ran
after the restart and then reversed an in-process round trip **in the
parent**. `_resumed_in_a_fresh_process` now runs resumed transitions
inside the restarted interpreter and asserts there, with two harness
self-proofs first; a second case carries the campaign forward in the
child. **The PID check proves the harness, not the lifecycle** — a
normal bridge/client restart and restored gameplay are unwritten and are
Prod's.

**P04.6 has a real killed write now.** SIGKILL *inside* `write_save` at
its three actual windows, with a previous save on disk; the old payload
survives all three. Sabotage-confirmed against a naive writer, which
also surfaced that a torn primary raises `SaveUnreadable` rather than
returning `None`. The stray-`.tmp` case is renamed for what it does.

**UNFINISHED is not PROHIBITED.** The §10.3 binding was right about the
rule and wrong about its reach: with only one shape available, a 320 kg
object came back refused by the carry line and there was no way to say
what was meant, so the schema encoded a ban the design never made.
`TransportedObject.movement` now separates the two questions.
`manipulated` is IN the vocabulary and refused as UNFINISHED, naming
what is missing — route validation that knows the object needs
`capability:core:manipulate` (`topology.py` does not read
`transported_objects` at all), the physical runtime, and a
doorway-clearance check on the object's own footprint.

**The bulwark's back is reachable with the base kit.** Bounded turning
at 90 deg/s, a 0.5 s commitment it cannot turn through, 0.9 s helpless
after. `bulwark_opening()`: a player at contact range circles at
167.1 deg/s for a net 77.1, clears the 69.5 deg shield half-angle in
0.90 s — half of one swing — and the 1.4 s no-turn window sweeps
234 deg, still 187 under a 0.8 strafe allowance. Instant tracking is
sabotage-confirmed to fail the same check. **The played acceptance is
OPEN**: geometry against a brief is not counterplay, and one test exists
purely to fail if the tuning stops saying so.

**P16's same-room check is a precondition, not physical proof.** It
refuses a client that contradicts its own earlier transport report. It
does not establish that anything was carried. Relabelled.

**DESS-16 — the doorway clearance.** `brute` fails worst (0.700 m near
edge against a 1.2 m half-width) and is an approved base-kit role that
**predates the composition widening**, so this is a latent defect the
widening made more common, not a regression it introduced. `melee`
clears at exactly 1.200 because `IN_THE_DOORWAY` was derived for a body
with the player's radius. `ENEMY_ENVELOPES` already exports
`lane_width`, so the fix needs no new number — it is Prod's nudge.

---

## ENGINE LANE — the press asks first; the bulwark from the door; LATCH built — 2026-09-22

**Consumables: the process boundary is closed.** D-9 converged with
Dess on *authorise before the irreversible effect*, and Prod took Dess's
shape (`docs/D9_CONSUMABLE_PROD_ANSWER.md`) because it can refund a press
that never launched and mine could not. `press_slot` now asks and fires
nothing; the snapshot in which the engine moved `spent` and wrote the
save is what runs `activate()`. Offline is a refusal with feedback. A
disconnect with a press unanswered is abandoned — neither fired late nor
refunded blind — and the reconnect snapshot answers it both ways.

`make godot-consumable-restart` is the owner's case with a real process
boundary: authorise, fire, drop the report, **kill Godot with a signal**,
relaunch a fresh process on the same unrefilled deployment. It reads
*"the save says 1 of 3 used … a press in the new process spends the NEXT
charge"*. Restoring launch-then-report fails it, and the marker line
states the defect alone: *"1 effect(s), save authorised 0 of 3"*.
`consumable_driver.gd` is at 91 and several cases now assert the opposite
of this morning, with their history kept. **Still staged**:
`IMPLEMENTED_ACTION_SLOTS` does not advertise `consumable`.

**The bulwark acceptance now starts at the door.** The controller's own
arrival, walked in on `move_forward` through real collision: 8.6 m in,
16.5 → 5.9 m in 1.2 s, cleared in 9.9 s at 60/100 hp; stable over five
runs. The placed-start case is kept as isolated counterplay evidence.
Tuning stays provisional for human playtest.

**P14: B chosen, LATCH built, and unreachable on purpose.**
`docs/D10_P14_PROD_ANSWER.md` answers Dess: `plate → LATCH → shutter`.
The runtime evaluates and restores LATCH (44 checks, sabotaged); the
schema has not admitted it, so a declaration is refused as a gap. **Two
findings for Dess:** the player cannot load a `ClassPlate` today (the
EX50-033 exclusion is applied everywhere and `Player` has no
`mass_class()`), so "MEDIUM is base kit" needs `SensorNode.counts_player`;
and **`record_latch` refuses a room-graph latch** — I had claimed it
needed nothing new, and it does. Reported under `graph_<room>` pending
the bridge change. **Nothing about the route consequence is played.**

**ThemePack: agreed** (`docs/D11_THEME_PACK_PROD_ANSWER.md`). Two fields,
the pack taking no role hop of its own so the one-hop rule survives, a
flat descriptor keyed like `textures`, universal roles refused for packs
as for themes. Bridge half first; the engine half is inert until a Zone
names a pack.

**Also:** the APWorld's vendored `constants.py` had drifted and `make
export` now copies it; `.ordinary-live-saves/` is untracked. Full
frontier before this round: 46/46.

**Open:** P14's played route (both halves in D-10 §4), P16 and P04's
Godot halves, OV04 P12, and the ThemePack engine half after Dess's.


## ENGINE LANE — the fight walks, the charge crosses a wire, a Zone asks for a chain — 2026-09-22

**`godot-encounter` is a gate now, ten runs for ten.** It ran about one
in five red before, always the three-scuttler `kill_all` case, and three
consecutive direct re-runs could not reproduce it — so the fight was
made to account for itself, and the next failure named the cause in one
line: `1800 frames, 1 left, 82 shots / 0 landed, range 20.4-20.4 m, the
ray hit Reward_89100002 (StaticBody3D) instead`. One range number twice
across thirty seconds is a body that never moved: a 30x28 room can place
a scuttler 20.4 m from the arrival point, outside the 18 m aggro radius,
with the reward pedestal on the line. Nothing there was a finding about
`scuttler`, `kill_all` or the placement — **a fight where the player
never moves is not a played fight**, and `_fight` walks now, sliding
along whatever it runs into. The bulwark's played acceptance stands:
cleared in 8.8 s with 50 of 100 hp, base kit only, continuous fight with
real movement and attacks.

**`godot-consumable-live`: one charge, from a keypress to the save, over
a real socket.** The spend was checked in two halves that never met —
Python arithmetic on one side, a client with `assume_sent` and a
hand-written snapshot on the other — and both could pass while the pair
was broken. The live target asks the only question that matters: HOW
MANY EFFECTS RAN, AND HOW MANY CHARGES DID THE SAVE AUTHORISE. Effects
are counted from `EchoRuntime.action_used`; authorisation is read out of
the snapshot's `consumable_uses`. Twenty checks, and the line it exists
for reads **"4 authorised, 4 run"** — two presses made with the socket
genuinely down, both resent on reconnect, both counted exactly once.

The campaign owns a consumable because `tools/give_consumable.py` puts
one in the save between two bridge runs, through the real models and the
real store: the fallback provider emits no `consumable`-slot Action, the
slot is still staged, and this target is about the expenditure rather
than about generation. **`IMPLEMENTED_ACTION_SLOTS` still does not
advertise `consumable`.**

**One sabotage it catches and one it does not, said out loud.** Dropping
the generation check from `spend_charge` fails it twice, the second
failure being the exact harm — "3 authorised, 2 run". Restoring
`_in_flight.clear()` on the disconnect path PASSES here, because the
sequence can only reach that transition with nothing held; that property
is proven in `consumable_driver.gd`, which fails three checks under the
same sabotage, and the live driver's docstring says so.

**P14's consumer exists: a Zone can ASK for the signal chain.**
`RoomGraphs.build` reads `Zone.room_graphs` and puts the plate, the NOT
and the shutter in the named room off the committed layout —
`RailNetworks`' move, for the same reason. `SignalGraph` evaluates in
declaration order, which the schema already guarantees is topological
order. The vocabulary is refused rather than dropped and a typo gets a
different answer from a gap (`NAND` is not one of the eleven; `AND` is
one of them with no runtime; `LEVER` is the same on §20's sensors), and
nothing is ever half-built. `SUPPORTED_ACTUATOR_OPS` is exported so the
refusal reads the same list the Zone was validated against.

**It does NOT gate a route, and that is a boundary rather than a
shortcut.** `RoomGraph` declares no capability gate, so a chain that
sealed an exit would be a physical gate the AP logic never declared —
SOLUTIONS_CATALOGUE §0-bis's one prohibition. Putting a graph on the
route needs the declaration to carry the gate: a schema change with
Dess's half in it.

**The player-exclusion case cannot tell two rules apart, and says so.**
Deleting `ClassPlate`'s player-group skip fails none of the suite,
because `Player` has no `mass_class()` either. The case pins the
behaviour and names what it cannot attribute rather than showing a green
tick for §3.

**Open, and unchanged by any of this:** P16's Godot half (player-operated
transport into a consuming mechanism; live Status continuity across room
boundaries with normal expiry), P04's Godot half (a normal bridge/client
restart and restored gameplay), OV04 P12's twelve manipulation verbs —
which must read `CARRY_MASS_KG`, not `ENVELOPE_MASS_KG` — and the
ThemePack identity extension to agree with Dess.


## ENGINE LANE — the Echo menu answers its own questions now — 2026-09-22

**From the owner, after playing.** The Echo menu was "a scrolling list
with no search or sort, and mixed passives with actives". `godot-archive`
is new at 23 checks.

The five slots are the top of the screen — what is on each key, what
replacing it costs, and the consumable's remaining uses — and clicking a
slot filters the list to what fits it. Search matches name, source game,
source item, description and concepts; sort offers newest / name /
source game; ACTIONS and ALWAYS ON are two counted sections. The
"1 of 3" form matters: a search hiding two things otherwise reads as
owning one.

**A fifth slot, `consumable`, on Q.** A consumable is an Action with
`charges` — not a new component kind, and not a zero-regen `Resource`,
because a Resource is a HUD channel with an economy and three uses of one
grenade has no decisions in it. Slot and charges imply each other
structurally. Charges persist (the fold says what the campaign was given;
button presses are not in it), and **refill on entering a Zone** by the
owner's decision. The supply is permanently owned: the last charge leaves
it equipped at `0 / max` saying what refills it.

**WHICH entries count as a refill is this lane's proposal, not a ruling**,
isolated in `transitions._refill_is_due` so it can be replaced without
touching the spend. As proposed, it refills when the deployment target
changes — so a re-entry, a reload and a Hub round trip do not restock, but
**A → B → A refills at both changes** and Hub → B → A is a restock loop one
Zone long. Per-Zone expenditure persistence is a different policy and the
owner has the decision.

**The spend is a compare-and-swap on the supply AND the use.** `use_index`
alone cannot reject a stale request across a refill: an old use 1 is exactly
the first index due afterwards, and an old use 3 matches again once two new
uses have landed. `consumable_generation` is minted by the refill and nothing
else, mirrored on the snapshot and echoed on the intent — the
`proposal_id`/`attempt` shape, not a second convention. `BridgeError.about`
carries the domain key of what was refused, so a client can release a spend
it is holding; it was the only server→client message with no identity at all.

**THE ADVERTISEMENT WAS WITHDRAWN AND THE ORDERING CORRECTED.** The
spend was right about messages and wrong about expenditure: the effect
fired on `action_used` and the client paid afterwards, so an offline
press ran an UNPAID activation and a refusal refunded a charge whose
effect was already in the world — one charge, two activations. Two of
this lane's own tests asserted that as the specification.

The order is **reserve → launch → report**. `reserve_consumable` takes
the charge before anything irreversible happens; `release_reservation`
is the only refund there is and it is pre-launch, when nothing has been
sent; `commit_consumable` reports a launch and keeps the charge spent
whatever the answer is; a refusal marks the reservation DISPUTED and
never hands it back. `IMPLEMENTED_ACTION_SLOTS` withholds `consumable`
again and the baseline is back to four slots.

`TestAuthoritativeExpenditure` counts how many charges the SAVE gave up
rather than how many messages went out — a retry is one expenditure, a
delayed response does not double-charge, refused attempts spend nothing,
a stale supply spends none of the new one. Four sabotages caught; a
fifth was not caught and so was not a sabotage, which is recorded
because it is the shape of a test that proves less than it claims.

**`make godot-consumable` is 61 checks** — the runtime half, on a
real Player, EchoRuntime and InventoryLayer. It counts charges accepted
AND actions run in every case, because those are two numbers. Three
sabotages caught. It found a real bug: `inventory.gd::_row` derived equip
buttons from a `create`-only loop while the list derived sections from the
fold, so an upgrade-only Echo was filed under ACTIONS and drawn as ALWAYS
ON with nothing to equip.

**Two silent five-slot bugs, found by reading rather than by failing.**
`resource_meters.gd` and CLEAR ALL both spelled the four names out, so a
consumable's cost would never register as paid and "clear all" would
leave it equipped. The keycap table lived in two Godot files; it is
exported now, and restoring the local copy makes the HUD render "? —".
`Hud._loadout_text()` had no test anywhere — the one slot-facing surface
with none — and that sabotage is what its new case catches.

**Live gameplay consequence, stated rather than buried:** widening
`SLOT_NAMES` widens `IMPLEMENTED_ACTION_SLOTS`, so Epsilon may now emit
consumables into new campaigns. That is what makes the slot real instead
of inert support. The Playtest 2.5 baseline was retaken for it; `zones`
is byte-identical.


## ENGINE LANE — the cargo swings, and §21's twelve are all built — 2026-09-22

**OV04 P13. `godot-constraints` is new at 67 checks.** Amalgam §14.8 and
§26.5 pinned from Design 2, plus §21.10's three actuators — the ones
`Actuator` refused by name when P15 landed §21's other nine. **All
twelve actuator kinds build now.**

**The headline is one measurement the Amalgam names itself:** *"A crane
in Design 2 is a `PULLEY` with a load on one end and a `WINCH` driving
it. Its cargo swings. Design 1's crane was a `PATH_MACHINE` whose cargo
was a child transform and could not."* An 80 kg cargo dropped 2.4 m out
from its anchor swings in to 0.00 m while the rope still holds it up.

**Two solvers, and the split is the substrate's.** Godot has a hinge and
a slider with real limits, so `HINGE`, `SLIDER`, `SEESAW` and a hinge
`PENDULUM` are those. It has nothing for a taut-only distance constraint
or two ropes sharing a total length, so `ROPE`, `CHAIN`, `PULLEY` and
`COUNTERWEIGHT` are solved here at §14.8's fixed eight iterations.
Consequence, declared rather than hidden: `breakable_at` is offered only
where a real constraint force exists, and asking for it on a hinge is
**refused by name**.

**The solver diverged to 1e18 on its first run.** `apply_central_impulse`
outside `_integrate_forces` is queued and does not change
`linear_velocity` until the next step, so eight passes each applied the
same full correction. It carries its own working velocity now.

**Two things the obvious implementation got wrong.** A brake is a motor
held at zero, not limits squeezed onto the current value — Godot
measures limits in the joint's frame and this class measures `value` in
the body's. And a `DRIVER` cannot turn a locked hinge: §23.5 rule 28
pairs a `BRAKE` with every mandatory-route `DRIVER`, so the brake winning
is what stalls the driver rather than letting whichever wrote the motor
last decide.

**P14 is NOT this lane's to build.** DESS-09 measured it and the argument
holds: the engine has one signal chain (`PoweredLink`), no node
vocabulary, no conduit, no graph, and declaring Design 1 §19's eleven
node types now would be a framework no room uses — which P14.5 warns
against in its own words.


## ENGINE LANE — §21's actuator contract, and the door reverses now — 2026-09-22

**OV04 P15. `godot-actuator` is new at 93 checks**, and it is the first
suite in this lane whose subject is a document section rather than a
room: Amalgam §21, all of it this engine can reach.

**The engine had six actuators and no contract.** `ServiceShutter`,
`RailCarrier`, `ShuttleDeck`, `RailJunction`, `PoweredLink`'s door and
`LaunchSolver`'s pad were each built for the room that needed them, and
no two of them answered "the input reversed halfway" or "the power went
out" the same way — because nobody had asked. §21.1 calls its transition
table "the complete answer… it applies to every actuator kind", so
`Actuator` is that answer written once, `SafeClosure` is §21.2's
interlock written once beside it, and `Constants.ACTUATOR_POWER_LOSS` is
§21.1.1's table with no holes in it.

**C4a is closed.** The shutter stopped where it was and waited, which
never crushed anybody and was half the rule. §21.2 requires a refused
closure to stop, **reverse to fully open**, and retry every 1.0 s,
repeating — because a panel parked halfway still narrows the doorway it
was asked to clear, and gives the person under it no sign that stepping
aside is what it is waiting for. It reverses now, on the contract class
and on the shipped machine, and its protected set widened from the
player to §21.2's "player or any `required = true` object" — which P16's
transported objects now carry as a group on the body.

**The suite did not cover its own defect on the first attempt.** Both
interlock cases opened the door fully, put a body in the doorway, and
only then asked it to shut: the panel never started moving, so "stopped"
and "reversed" were the same number, and reverting the repair left the
suite green. §21.2's subject is a closure that has *begun*. Corrected, the
same revert produces **nine failures**.

**Nine of twelve kinds build; three are refused by name.** §21.10's
`WINCH`, `BRAKE` and `DRIVER` drive a constraint solver this engine does
not have. They are in the vocabulary and in the power-loss table so the
table has no hole, and `Actuator.create` refuses them, which is the
honest report of where the substrate ends. That is **P13**.

**Also closed on machines that are in rooms today:** `ShuttleDeck` (the
LIFT) and `RailCarrier` (the MOVING_PLATFORM) had no notion of power at
all. Both now hold at the exact position they were caught at and resume
the errand they were on — §21.1.1's asymmetry argument is that a lift
which drops when a generator fails can strand or kill the player, and no
interlock helps, because the danger is the motion.

**Next ready Prod packages:** P12 (manipulation verbs), P13 (constraints
+ §21.10's three), P14 (signal graph and sensors), P10/P11 (remaining
Statuses and compounds), P17 (railway switching). **P08 stays blocked**
on seven content-value integers only the owner can set.


## BRIDGE LANE — four corrections applied, and the composer emits — 2026-09-22

**Two of the owner's four corrections were defects in rules I had
shipped and sabotage-proven**, which is worth saying plainly: a rule can
be correctly implemented, fully tested, and still be the wrong rule.

**Correction 2 was the real one.** The search let the player set any
variable whose setter's room they could reach, so Blindside's gantry —
4.6 m up, no mantle, no stairs — became operable the moment they walked
in underneath it. The search was granting itself a capability.
`ZoneStateSetter.capability` now declares what operating a control costs
beyond reaching its room, setter capabilities join the undeclared-gate
accounting, and §4.0's "a reversible variable cannot strand you" is
**withdrawn**: `selects` proves a reversal *operation* exists, not that
the player can reach it. Physical operability evidence stays the engine
lane's.

**Correction 4:** the cross-room rule had become a content restriction.
It now requires what it actually claims — at least one consequence
somewhere else — and allows a reader beside the control too.

**Correction 1:** held cross-room mechanics are **UNSUPPORTED, not
unfair**. I withdrew the fairness argument; they stay in the design and
the bounded §19.7 rule-2 amendment is drafted and ready to bring.
Reversible configuration is approved for the first Blindside
integration and is not a substitute.

**Correction 3:** the consecutive-dock rule describes the ordered-route
implementation and does **not** retire branching railways from the
design. `RailJunction` is not a track fork, and Blindside's acquisition
branch is walked, not ridden. DESS-01 lists the five pieces a branching
configuration would still need.

**The composer emits** (`cross_room.py`): handed a really composed Zone,
it derives a control in `c002` and a consequence in `c023`, 21 rooms
apart, gating a real edge — nothing in it names a room. It is a step,
not a default, so `played_zone_digest` and the 0.3 comparison do not
move. `transitions.record_zone_state` is the authoritative update path.

**DESS-02: one guarantee was vacuous.** The composer claims it declines
rather than emitting something broken; sabotaging that check left all
fourteen controls green, because no candidate was ever unsolvable. The
missing case — a Zone granting a capability, composed for a run not
guaranteed it — now exists, and the sabotage fails.

**Findings are lane-prefixed from here** (`DESS-nn` / `PROD-nn`). The
flat series collided twice in two merges and both were spent renumbering.

**Not done:** Prod's runtime half, physical acceptance, transported
objects (explicit unfinished 0.4 row), and the featured-acquisition/AP
delivery, which no macro declaration or dev grant proves.

## BRIDGE LANE — D-8 agreed, and the bridge half of cross-room is in — 2026-09-22

**The contract came out the same from both lanes.** Prod's
`docs/D8_CROSS_ROOM_PROD.md` and my
`docs/design-proposals/D8_CROSS_ROOM_STATE_CONTRACT.md` were written
without either of us seeing the other's. Both name Amalgam §19.7, both
quote *"a puzzle that should change the Zone drives a setter package's
interaction, which the player then performs"* as the reason the
forbidden global signal bus is unrepresentable rather than merely
banned, and both call it D-8.

**The crossing, as data:** a player interaction in the setter's room
writes a declared handle, and the destination room's graph reads it.
Rooms never address each other at any step. `Zone.zone_state` declares
the variables `physics.state_vector_product` has budgeted since before
anything could name one; `StateCondition` gives `TopologyEdge` the
predicate §5.6 step 6a always claimed to evaluate; `_explore` carries a
third state component; `ZoneProgress.macro_state` is overwritten rather
than accumulated, and stays out of monotone `latched`.

**§4.0 is the rule to argue with.** Lifetime is *proven* by the
declaration: `permanent` means the setter selects exactly one non-initial
state, `reversible` means it can always go back. The owner's "do not
silently replace a live requirement with a permanent latch" is then
unwritable rather than discouraged.

**F-26: my own test found the defect.** Threading the macro component
through five of six searches left `_key_graph_is_acyclic` at the initial
state, so a gated edge looked shut and a Zone with no cycle reported
one. One search knowing what another does not — reintroduced by the
change that added the thing it is about, and caught only because the
acceptance case runs on the really composed 23-room Zone instead of a
three-room fixture.

**Not done:** no composer emits a relationship, the engine half is
unbuilt by agreement, and no physical acceptance has been run. `make
test` 1631 passed, 6 skipped.

**Also this batch — F-24**, answering Prod's three D-4 questions: spans
must join consecutive docks (refused in the schema, where a Zone that
cannot be built should not validate), `docks` order *is* the route
order, and `home_dock` exists now with the engine's own default.

## ENGINE LANE — target facing is a gate, and a Zone can ask for a railway — 2026-09-22

### The bounded nudge, and 27 of 27

`godot-target-facing` is **in CI**. The entry in `NOT_A_SUITE` always said it
would come out "the moment that repair lands", and it has.

The nudge is generic — no room, element or world coordinate is named. Any
unmounted SHOT target that no rotation can aim gets a bounded walk in **its own
local frame**, `-basis.z` first, so the first thing tried is backing away from
whatever it is looking at. 0.05 m steps to 0.50 m, **distance-first**, so the
first candidate that survives is the smallest that exists. Rotation stays the
first answer; a case pins that in a room where every target can simply be
turned, **none of them moves**.

Four gates, all required: footprint (no solid, no other claim, no reservation —
reservations count for a move although they do not count for a facing),
support (`_floor_under`), route (floor and headroom where a player would
stand), and the shot at the **unchanged** 2.0 m. The claim follows the element:
the affected activity's footprints are recomputed by the same `_footprints`
that produced them.

**Two defects found building it, both measured.** The 0.35 m courtesy padding
is for keeping content off *content* — tested against architecture it rejected
every nudge for a collision the element was already in (local x 6.1, partition
at 6.7, silhouette clear, padded claim overlapping). And the firing ladder
started at 2.0 m, i.e. *past* the window it was meant to check, so a target
with exactly its clearance and something solid just beyond read as unshootable
while a player could stand at 1.5 m and hit it.

The diagnostic Zone's case moved **0.10 m** back along its own facing — exactly
the proposal the census had measured.

### D-4 consumed: `Zone.rail_networks` builds a real railway

`make godot-rail-zone`, **23 checks**, in CI. `ZoneController` reads the
contract Dess landed at `704f379` and `RailNetworks` builds it: docks at the
declared rooms' arrivals, a `RailPath` through them, a span per declaration
carrying its own `latch_id`, an `AlignmentControl` in the room
`control_room_id` names. A null control means the span ships commissioned,
because that is what the schema says it means.

Certified: every dock stands in the room its declaration names; a span with a
control starts **refused** and one without starts open; the control is in its
own room; and a Zone rebuilt knowing the latch fired comes up **commissioned**
— §5.4a recomputed from the latch, with nothing having saved a span.

**F-22, and the engine refuses rather than guesses.** The schema declares a
graph (`from_dock`/`to_dock`, any two of eight); `RailCarrier` runs one ordered
route. A non-adjacent span has no link to commission, so it is refused **by
name**, the network builds nothing, and the Zone still builds — a composition
finding on `rail_refusals`, not a crash. Three concrete questions go back to
the bridge lane: must spans join neighbours, is `docks` order the route order,
and is there a `home_dock`. Only the first can make a Zone unbuildable.

### Dess's deliveries integrated

`704f379` RailNetwork (consumed above), `c0d5446` the support-target export
(collapsed onto one name, F-21), and `96b6fdd` **D-1/D-2 the acquisition
binding** — `Zone.featured_acquisition` and `established_in_zone`, the producer
`capability_guarantee`'s case C never had. Merged clean; bridge suite **1650
passed + 627 subtests**. She notes nothing composes a featured Zone yet: that
composer half is this lane's, and is the next M2 step.

### The 2026-09-22 scope clarification: cross-room puzzles are 0.4

Recorded, measured and handed over — **no implementation**, because the owner's
instruction is *"agree the shared contract before competing implementations are
written"* and the contract is Dess's (D-8).

**§19.7 already pins the architecture**, so nothing needs inventing: room
graphs read macro state and never write it; the machine graph has no logic
nodes and is evaluated on macro change only; and *"a puzzle that should change
the Zone drives a setter package's interaction, which the player then performs
— the latch does not reach across rooms on its own."* That sentence is the
owner's "no permanent-latch shortcut" and "no global signal bus", already
written down.

**F-23, and it is the whole gap: every piece of Zone-scope state the engine has
is monotone.** Latches, keys, station reached-ness — all one-way. `PoweredLink`
is live-only and cannot write anything. Between permanent and gone-with-the-
frame there is nothing, so a cross-room puzzle on today's engine could only be
a latch. §20's `MACRO_STATE`/`MACRO_SELECTOR` and §21's macro effect types are
pinned and absent (`grep -rn macro godot/scripts/` returns nothing), while
`physics.py` already budgets macro variables against §4.10 — the accounting
exists, the declaration does not.

**Two rule questions, named rather than hidden** (`docs/D8_CROSS_ROOM_PROD.md`
§4). §19.7 does not cover transported objects; and **§19.7 rule 2 makes a
cross-room HELD requirement impossible**, since a held input is room-layer live
state and room graphs may not write macro state. Recommendation: express it as
reversible Zone configuration, which needs no amendment. The amendment that
would be needed otherwise is stated so the choice is visible.

**Acceptance case designed**: Blindside's major + acquisition branch, distinct
room IDs, through the real composition path — the central junction keeps its
alignment control, and one meaningful interaction elsewhere in the branch
changes a mechanism or route in another room. Finding the featured Echo is
necessary and **not sufficient**. Seven proofs, including that a rebuilt
destination binds by variable id and never to the setter's node.

Matrix: **M6**, 0.4 completion, not started, blocked on D-8.

### Still open, and not touched here

- **H1/H2 enemy variety** — 3 of 10 declared roles have behaviour. Separate
  explicit workstream, active in the queue.
- **The rest of the Amalgam catalogue** — 11 kinds named and unsupported.
- **No composer declares a railway or a featured acquisition yet**, so neither
  has been ridden or played. Build-and-certify is not the same as played, and
  the rows say so.
- The three EX50 rooms remain **playable development scenarios**; their
  interlocks, campaign integration and save requirements are open rows.


## ENGINE LANE — the Unweighted Switch stands, and the boundary caught a lie — 2026-09-21

**EX50-033 is a room you can walk.** `make godot-unweighted`, **61 checks**, in
CI. `--unweighted` builds it; `--disconnected` is §11's control.

The contradiction is real and measured: the upper sill at **1.9 m** is above a
baseline jump from the floor (apex **1.333 m**, from generated `Constants`) and
**0.433 m** inside one from the crate top at 1.0 m. The 200 kg crate is the only
step; the recess floor it must stand in is a HEAVY `ClassPlate` wired to the
shutter through a NOT. Placing the step you need closes the route you want.

**`lightened` resolves it by moving the class and not the kilograms**, through
the real path — `ManipulableBody.apply_status` into a `StatusEffects` at target
kind `object`, refused at the engine's own boundary if the runtime does not
implement the pair. No stand-in, no room-local vocabulary.

| measured in the room, on its own crate | before | while `lightened` |
|---|---|---|
| kilograms | 200.0 | **200.0** |
| mass class | HEAVY | **MEDIUM** |
| crate top | 0.99 m | **0.99 m**, ray still stops on it |
| one impulse | 0.1957 m/s | **0.3913 m/s** (x2.00) |
| plate, nothing having moved | satisfied | **released** |
| shutter | shut | **open** |

**And then it expires**, which is the half a room that only measured the opening
would never have found: at 8.0 s the class returns, the plate re-satisfies with
nothing having moved, and the shutter shuts again. That is why the bolt exists,
and the suite shows it outlasting the Status — crossing still open, return stair
still built, after the same expiry that shut the unbolted door.

The route is **walked**: drive lever, shot applicator (line of sight asserted,
not assumed), climb — feet settled at 0.99 m on the crate top — crossing at
z 7.02, bolt, goal.

### F-20 — the support table under-declared what the engine implements

`SUPPORTED_STATUS_TARGETS["vulnerable"]` said `("enemy",)`. The engine
implements it **twice**: `stat_stack.gd:93` multiplies the PLAYER's
`damage_taken`, `enemy.gd:434` multiplies the enemy's. Invisible while support
was asked per KIND; asking per TARGET turned `godot-stats` red on three cases,
including the cleanse order's own "`vulnerable`, which the player does suffer".

**Declared to match the runtime, not the other way about.** A target the engine
implements may not be refused, exactly as one it does not may not be allowed.
Reverting the row alone brings all three failures back.

The acceptance sweep was the weaker shape of the question — one `self` container
against `ECHO_STATUS_KINDS_IMPLEMENTED`, which only ever asked whether a kind
was accepted *somewhere*. It now sweeps 13 kinds across all five §15.1 targets
and asks both halves: accepted where declared; elsewhere no entry, no active
state, no `status_applied`.

### One export of the pair, not two

Dess exported the same map as `ECHO_STATUS_SUPPORTED_TARGETS` (`c0d5446`) while
this lane exported it as `ECHO_STATUS_TARGETS` (`fb11161`) — she branched before
mine landed. The merge **collapses them**; hers stands (her lane, her file, and
`SUPPORTED` is what the map is) and the three engine consumers are renamed onto
it. Two spellings of one fact is the thing this repository keeps uncreating.

### Target facing: 1 of 27 open, and the nudge is measured

`e13e7e0` took 7 wrong-facing targets to **1**. The survivor is
`ActivityElement_4` in `c002` at `(-17.1, 2.2, 29.1)`, facing -X, blocked at
**1.90 m** against a 2.0 m window — **10 cm short** — with a wall 1.25 m behind.

Per the owner's direction, the census now reports a **bounded** proposal rather
than searching: half a metre of travel in 5 cm steps, along the facing axis and
the two perpendiculars, at the *same* clearance every other target is held to,
rejecting any candidate that is not standing in open air or leaves the room.

> **PROPOSAL: move 0.10 m back along its own facing**, to
> `(-17.00, 2.20, 29.10)` — same room, same 2.0 m clearance, no rotation.

The wall behind goes 1.25 m → 1.15 m and the target is unmounted, so it owes
nothing back there. **Measured and reported, not applied**: it moves an element
in a shipping Zone's generation and ripples into the placement fixtures, so it
waits on the owner's word. `godot-target-facing` stays out of CI until it lands.

**FULL FRONTIER GREEN at `cf70a98`, on a frozen tree** (`git diff --stat HEAD`
empty at the start of the run): Python **1597 passed, 5 skipped**, and **30
Godot suites** — boot, test, hud, rules, stats, lab, affordance, verbs, blink,
content, activity, room, room-contract, graphs, movement, zone-audit, legible,
physics, traverse, return-placement, build-failure, exit-reach, passenger-carry,
rail-carrier, rail-junction, passing-platforms, counterfire, mass-class,
**unweighted**, reload.

The run was made in a separate `git worktree` at that commit so the main tree
stayed free for the documents. **The first attempt reported all thirty suites
FAILED and none of it was gameplay evidence**: `godot-bin/godot` is untracked
and lives only in the main checkout, so `make godot-import` could not find a
binary. Linking it and re-running gave the result above. An infrastructure
failure that looks exactly like thirty broken suites is worth writing down.

The only file the run itself changed is
`godot/tests/fixtures/placement/captures.json`, and only its own
`source_commit` stamp — the census re-attesting which commit produced it. That
stamp is carried into the checkpoint rather than reverted.

`godot-target-facing` is not in that list and is not a gate; it still reports
its one open case, now with the measured proposal above.

### Still open, and not touched by this checkpoint

- **H1/H2 enemy variety** — a separate workstream on the recovered roster.
- **The rest of the Amalgam Status catalogue** — 11 kinds named and unsupported;
  `lightened` crossed on ONE target and the other four still refuse it.
- **EX50-011 / EX50-021 / EX50-033 are playable development scenarios.** Their
  interlocks, campaign integration and save requirements are not discharged by
  their route tests and remain open rows.


## ENGINE LANE — EX50-033: class is not kilograms, and the Status is missing — 2026-09-21

**The ledger's open question is answered, and the answer is "neither".** The
question was whether the engine had EX50-033's semantic mass-class sensor or a
summed-kilogram plate. It had **no mass class at all** — `mass_kg` is a number
on `ManipulableBody`, `PoweredLink` adds it up, and nothing anywhere read a
class.

`make godot-mass-class`, **36 checks**, in CI.

**§10 says what to do before building anything**, and it was done in that order:
"Before building a platform room, verify that the same object remains
collidable while the plate's output changes under LIGHTENED." And it names the
**decisive negative control**: "replaces the class plate with a summed-kilogram
sensor without changing the Status... That control prevents the implementation
from conflating two distinct mass vocabularies."

The summed sensor is not written for the occasion. It is `PoweredLink`, the one
that already ships.

| measured, one crate, both sensors | class plate | summed kilograms |
|---|---|---|
| 200 kg crate at rest | held (HEAVY) | held (200 kg) |
| class dropped one step, kilograms untouched | **released** | **still 200 kg** |
| 50 kg taken off, class unchanged (still HEAVY) | **still held** | **reading fell to 150** |
| 300 kg of MEDIUM debris | not satisfied | over a 120 kg threshold |

The two vocabularies disagree in both directions, which is §6's "A mass-field
ability that changes kilograms without changing the plate's semantic class may
not release the plate" as well as §10's control. And the crate is still a step:
a body dropped on the lightened crate comes to rest on its top, and the crate
has not moved, shrunk or fallen.

**The thresholds are transcribed, not chosen.**
`docs/design-proposals/02_PHYSICS_IS_THE_GAME.md` §10.2 pins them — LIGHT below
30 kg, MEDIUM to 120, HEAVY to 400, FIXED above that or unmanipulable — and the
suite checks all six boundaries at three decimal places, because a
transcription is exactly the thing that goes wrong at its edges.

**F-15: `lightened` is not in the engine, and adding it is not a one-liner.**
The accepted design has it (Design 5 §15.2: 8.0 s, magnitude 0.40, "`mass_class`
drops one step"). `Constants.ECHO_STATUS_KINDS` does not, and that list is a
GENERATED artifact from the bridge schema's closed `StatusKind`. Widening it is
a shared-schema change — and worse, `StatusEffects.apply`'s own comment explains
why it is not a line: a kind the schema admits and no system implements is
"inert, because nothing reads it, yet still satisfying `status_active`
conditions and `status_applied` edges". `lightened`'s specified effect spans
impulse, wind, conveyors and Physics eligibility as well as class. That is
**B3**, and it is raised as **D-7** rather than taken.

So the class is lowered by `ManipulableBody.shift_class_provisionally`, named so
it cannot be mistaken for the Status, and every claim measured through it says
so. **That does not weaken the claims**: what is measured is what the two
SENSORS do when a class moves and kilograms do not, which is true whatever moved
the class.

**And EX50-033's room is deliberately not built.** Building a playable room
round a stand-in for its central mechanic is the coherent proposal dressed as
evidence this ledger exists to prevent. The recess, the sill, the guide track,
the far bolt and the return stair are named in the scope matrix as not started,
blocked on D-7.

**M3 stands at two of three**, with the third's blocker identified rather than
guessed at.


## ENGINE LANE — EX50-021: an enemy's shot as the input to a machine — 2026-09-21

**The second of the three approved minors.** `--counterfire`: a firing lane
with an emergency impact trip at the south end, hooded against the side you
arrive from, and a gunner covering the lane from the north gallery. Stand in
the lane, let it commit a shot, step into the alcove — the projectile carries
on into the stance you left and trips the receiver, which opens a service
shutter for eight seconds.

`make godot-counterfire`, **44 checks and 2 notes**, in CI.

**The specification names its own critical dependency and it did not exist.**
EX50-021 §12: "projectile-source acceptance at the receiver." §3: "Existing
player-only target filters must not be assumed to support this." Read rather
than assumed — and `EnemyProjectile` delivered `take_damage` to a body in
group `"player"` and to nothing else. Anything else it touched simply stopped
it.

**The extension is the smallest one that works, because the obvious one is
wrong.** Letting an enemy projectile call `Damageable.hit` on whatever it
touches is not a bounded extension; it is a change to what every damageable
node in the game means, and the first casualty is `BreakablePanel` — a gunner
opening the affordance whose capability the player is charged for. So a machine
**opts in**, through `Damageable.HOSTILE_INPUT`, and the suite asserts that an
ordinary shot element — damageable, hit by every player weapon — is untouched
by hostile fire.

**And the hood is steel, not a rule.** §3 asks for "physical directionality,
not an owner-ID exception", so a real Static Pulse fired from the arrival side
stops on real geometry, and the same weapon from the lane side operates the
same plate. Both halves are measured from two real standing positions.

| measured | value |
|---|---|
| flight, muzzle to stance (12.3 m at 14 m/s) | 0.88 s |
| the step into cover | 0.43 s |
| shutter interval left on reaching the service route | 5.4 s of 8 |
| the ranged archetype's windup | **none** — `_say("shot")` is a tone at the instant of firing |

**§11's three bars, all three met.** The committed shot lands in the vacated
stance (continuous play: nothing knows the enemy is about to fire, and the
dodge is a keypress made on seeing the projectile exist). `--blocked` puts real
steel across the lane and the shutter does not open — and the blocker is SOUTH
of the stance on purpose, because one north of it would break the gunner's line
of sight and the counterpart would then be failing for the wrong reason. And
with the gunner killed before any hit, the room still finishes: up the lane, an
ordinary Static Pulse on the plate, through the shutter, up to the flank, the
manual release, the goal — every metre walked.

**F-14** records both runtime facts. **What is not answered, and cannot be by a
test, is whether the bait is fair.** §12 says exactly that. The margin is
reported as a number so a playtest has something to disagree with.

**Next:** EX50-033 Unweighted Switch, the last of the three. One question
first: its sensor is a semantic mass-class / LIGHTENED interaction, **not** a
summed-kilogram plate, and which of the two the engine has is not established.


## ENGINE LANE — EX50-011 Passing Platforms, built to its own bar — 2026-09-21

**The first of the three approved minors is playable and measured.**
`--passing-platforms`: a 28×22 m chamber where a lift `V` rises from the
arrival floor to an upper shelf, pausing 2.5 s at the transfer plane on the
way, and a shuttle `H` crosses at that height to a goal gallery. Neither
reaches `G` alone. You choose when to start each.

`make godot-passing-platforms`, **63 checks and 7 notes**, in CI.

**§11's bar, both halves.** A continuous body run from the arrival floor boards
the lift, transfers to the shuttle with both machines commanded and moving, and
reaches `G` — nothing placed, nothing snapped, every command a keypress on a
lever the body is looking at, and the three deck railings counted before and
after. Then the counterpart: `--parted` shifts the shuttle's track so nothing
passes, **the same interval between LAUNCH and the step is replayed**, and `G`
is not reached. The walks are not replayed frame-by-frame and the suite says so
where it does it — a body arriving one frame late would fire its interact into
the air and fail for a reason that has nothing to do with whether the tracks
pass.

**§10's alternative is built, not prose.** "Stop H near the transfer, ride V,
board H, restart. If no accessible control permits that sequence, the paper
alternative is false and must be removed or built rather than left as
reassuring prose." There is a STOP at the arrival floor and a restart lever on
the shuttle's own deck, and the patient route is walked end to end.

| measured (§10) | value |
|---|---|
| overlap, for a 1 / 2 / 3 s board-and-launch | 2.17 / 2.68 / 1.75 s |
| the same, in the parted room | 0.00 s |
| relative speed at the transfer | 1.50 m/s |
| deck pairs that ever intersect | 0 of 1681 — they never share a `z` |
| fall from a missed transfer | 2.89 m, **0 HP** |

**Four findings.** F-10: the recovery floor had two strips of nothing in it,
three metres wide and the full depth of the room, and **nothing walked found
it** — the coverage census §10 asks for did, before anyone had an opinion about
where the floor should reach. F-11: `add_child` throws a colliding node name
away rather than making it readable, so the shuttle's second railing was
`@StaticBody3D@93` and a name-based census reported two railings of three.
F-12: §8 asks for the fall damage to be verified, and the answer is that **this
runtime has none at any height** — the recovery floor costs time, not health,
and that is an engine-wide default rather than anything this room does. F-13:
an instrument error — a body resting on a *stationary* deck can finish a frame
having slid against nothing, so `get_slide_collision` alone said it was not
aboard.

**One shared change to tested code.** `RailCarrier.top_speed` and `accel` are
now per-carrier, defaulting to the skiff's 7.0 / 3.0, so a maintenance shuttle
can run EX50-011's 1.5 m/s without a second class. `godot-rail-carrier` 73,
`godot-rail-junction` 140, `godot-passenger-carry` 4 — all re-run, all green.

**The lift is a new class and the shuttle is not.** A finite WEST HOLD / TRAVEL
EAST / EAST HOLD / TRAVEL WEST schedule *is* a two-dock railway with a
fail-safe stop, so `H` is a `RailCarrier`. A rail carrier on a vertical path
stands its deck on end — `RailPath` refuses past 75°, correctly — so `V` is a
`ShuttleDeck`. The two share `StopTravel` and nothing else.

**Not built, and named:** §9's save behaviour (there is no 0.4 save
representation — D-6), §8's boarding gates and interlocks, §7's later
encounter, which the specification itself defers. The full scope/status matrix,
including everything not started and which Dess handoff blocks which row, is in
`docs/ledgers/HUGE_BATCH_LEDGER.md`.

**Next:** EX50-021 Counterfire Arcade, then EX50-033 Unweighted Switch. Both
unblocked, neither started. EX50-033 carries an open question first — its
sensor is a semantic mass-class / LIGHTENED interaction, not a summed-kilogram
plate, and which of the two the engine has is not yet established.


## ENGINE LANE — the yard was answering an easier question — 2026-09-21

**Measured before anything was changed: the base kit could walk to S3.** With
the span still up and nothing in the mobility slot, a walked route round the
outside of the track — 42.3 m, no teleports — ended standing on S3's platform.
`_yard` laid one continuous slab and `_docks` put steps at every dock, S3
included; both were conveniences from assembling the place, and neither had ever
been measured.

**So the commissioned link was restoring VEHICLE SERVICE and nothing more,
while the scenario read as though it opened a destination.** Those are two
claims. The yard now makes both checkable: the floor is four slabs around a
hole, S3 stands on an island inside it, and a dock over the hole gets no steps
— a flight of stairs rising out of a void is a bridge.

| claim | measurement |
|---|---|
| destination access is gated | the walk ends in the hole at `y = -25.03`; narrowest gap round S3 is 6.0 m; a run-up and a jump from the far rim also ends in the hole |
| vehicle service is what the repair restores | same yard, span home, the carrier crosses to S3 in 10.9 s |

**And the island is not a trap.** Step off, send the skiff away, and one Static
Pulse at S3's forward chevron brings it back — the direction controls are
commands to the RAILWAY rather than calls placed at a dock. Held as a case, not
remembered.

**None of this is a progression claim.** It is dev scaffolding; it establishes
that the scenario shows what it is meant to show, and nothing about an AP
guarantee, a capability gate or a composed Zone.

**The three EX50 originals are in the repository**, byte-for-byte under
`docs/design-library/EX50_entries/`, with their digests verified after the copy
and an authority note that keeps paper proposals distinct from runtime evidence.
`make godot-rail-junction`, 140 checks.


## ENGINE LANE — the second binding, and a name I will not invent under — 2026-09-21

**`--railway --bracing` builds the same railway with the span held by a clamp
instead of by a gantry control.** A different relationship, not a relabel: the
first configuration asks the player to REACH a control and operate it, this one
asks them to remove what is holding the span up. The accepted consequence is
identical — the same latch, the same commissioned link — and what differs is the
verb and what it is aimed at.

**IT IS NOT A SECOND ACQUISITION LOOP**, and the addendum is explicit about why:
`ranged_hit` establishes no newly acquired capability, because the starting
player already shoots the transport receivers. It is an existing-tool objective
variant and is labelled one everywhere it appears.

**THE TWO ARE ALTERNATIVES, NEVER BOTH.** A yard offering a gantry *and* a clamp
the base kit can shoot is a yard where the acquisition branch is optional, which
is the guaranteed walking bypass under another name. The suite checks that the
bracing configuration has no gantry, no pedestal and no hook.

**EX50-011, EX50-021 AND EX50-033 ARE BLOCKED, AND NOT ON ENGINEERING.** Their
specifications came from the uploaded batch package and are not in this
repository. This lane will not invent content under names the owner gave
specific meanings to. The parts they were chosen to share — `RailCarrier`,
`RailReceiver`, `RailSpan`, the latch chain — all exist and are tested; what is
missing is the design.

Also: the scenario now draws the real HUD, bound the way `main.gd` binds it for
a Zone. A yard with shooters in it and no health readout is a yard where being
killed is a surprise.

`make godot-rail-junction`, 124 checks.


## ENGINE LANE — the whole loop, walked — 2026-09-21

**`_walked_end_to_end` places nothing.** The body walks from S1's platform onto
the deck, fires one Static Pulse at the chevron, rides to S2, is refused for
want of track when it fires again, steps off, turns onto the branch walkway,
walks it to the pedestal, takes the hookshot with the interact key, walks back,
stands on the platform, pulls itself onto the gantry with the mobility key,
throws the lever, comes down, steps aboard and rides to S3. Every metre is
walked, ridden or pulled; every command is a key. 114 checks, stable over four
runs.

**IT IS KEPT APART FROM THE OTHER EVIDENCE, which is the point.** The plan asks
that continuous play evidence not be blended with placed-near-target,
pre-unlocked, direct-handler and synthetic-state runs, and the ledger now has a
table saying which case is which. The one stated simplification here is that the
shooters are removed: this case measures the ROUTE, the fight has its own case,
and a walk that failed because the player was killed halfway would report the
route broken when it is not.

**Two things the walk found that the measured cases could not.** Steering
straight at the pedestal walks a body off the platform's outer edge before it
ever reaches the walkway — a player would see the walkway, and the steering had
to. And standing a metre and a half out from the platform's centre puts the body
UNDER the gantry's overhang, so the pull takes it into the underside rather than
over the lip: where you stand to fire is part of the shot.

**FULL FRONTIER GREEN at `88cb607`:** Python 1604 + 627 subtests, and 26 Godot
suites — activity, affordance, blink, boot, build-failure, content, exit-reach,
graphs, hud, lab, legible, movement, passenger-carry, physics, rail-carrier,
rail-junction, reload, return-placement, room, room-contract, rules, stats,
test, traverse, verbs, zone-audit.


## ENGINE LANE — the ride is not a tram ride — 2026-09-21

Three `ranged` shooters stand beside the S1-to-S2 leg on **alternating sides**,
and the skiff carries **chest-high cover on one edge of its deck**. The deck
turns through the corner and the cover turns with it, so a rider who wants to
stay behind it has to move — which is the movement `godot-passenger-carry`
was talking about when it recorded that a carrier's deck must be sized from
the rider rather than inherited from `MovingPlatform`.

The shield is part of the carrier's own body rather than a static body riding
on it: an `AnimatableBody3D` with `sync_to_physics` carries its own shapes
exactly, and a separate body standing on the deck would be a second thing to
keep in step. It sits on the side AWAY from the docks, because the carrier's
own +X is the side its platforms stand on and a shield there would be a wall
between the player and the only way aboard.

**What the suite holds, and what it does not.** Held: the shooters are real
enemies, they are not all on one side, the shield stops a shot from its side
while nothing on the carrier stops one from the other, and a shot fired from
the moving deck damages a shooter. **Not held: whether the fight is any good.**
That is a playtest question and the suite does not pretend to answer it.

`make godot-rail-junction`, 96 checks.


## ENGINE LANE — see it, cross to it, come back and open it — 2026-09-21

**M2-mech.** The railway scenario now carries the whole first loop. The gantry
that lowers the span is **overhead and out of reach**; the branch that supplies
the tool leaves the S2 dock and passes under it; the pedestal there hands over
`grapple_to_surface`; a ledge beside it is somewhere to learn it where a miss
costs nothing; and the same control the player could see from the junction opens
with it on the way back. That is the Blindside review's cause **B** and the
owner's approved first configuration.

**IT IS NOT M2 AND IT IS NOT MULTIWORLD-SAFE, and it says so on a sign.** The
Echo is handed over by the scenario's own pedestal, not by an AP Check, an
interpretation fold or a snapshot. The acquisition contract is M2's completion
requirement, it is Dess's, and it is not built. What this proves is the
EXPERIENCE; it proves nothing about progression.

**THE STAIRS ARE GONE.** The owner's direction is explicit — do not add a
guaranteed ordinary walking bypass to avoid the acquisition work — and a
placeholder that lets you skip the loop is not a placeholder for the loop.

**F-07: THE GRAPPLE IS A VERB THE BALLISTICS HAVE TO ALLOW.** `_grapple` sets
`velocity` toward the hit point and `player.gd` then lerps the HORIZONTAL part
toward the walk intent every frame: the vertical survives, most of the lateral
does not. Under this gravity (~21.9 m/s², measured from the arc) a 14 m/s pull
tops out 4.45 m above where it started. A gantry 3.8 m up and ten metres out was
outside that envelope — the first cut peaked 2.7 m and the player landed where
they started, and the second clipped its head on the gantry's own underside.
Fixed in the GEOMETRY: 3.1 m up, 7.5 m out, plate above the inner lip.
**Nothing in `player.gd` was changed** — its damping is production behaviour and
a feel change to it is the owner's call.

One defect repaired because the grapple is now load-bearing: `_grapple` burned
the cooldown and the power draw on a shot at the sky, while `_blink` and
`_grapple_swing` both refund. It refunds now, and so does a shot that lands on
something that is not a `StaticBody3D`.

**An instrument error, caught before reporting:** reading the cooldown one
physics frame after the press reported the Echo broken while the pull it fired
was in the air. A press issued from a coroutine lands between frames.

**NEXT:** the loop is playable and unplayed.


## ENGINE LANE — the railway is a place you can stand — 2026-09-21

**`godot --path godot -- --railway`.** Board at S1, shoot the chevron pointing
toward S2, ride; S2 to S3 is refused for want of track; climb the gantry stair,
press E on the lever, watch the span swing down and lock; ride to S3. The plan
calls M1 *"independently playable"* and until this existed nothing let anyone
walk into it.

**IT IS NOT A ZONE, and the distinction is load bearing.** No Checks, no exit,
no composition, no campaign, no bridge connection — it runs *before* `boot()`
and returns. Scaffolding in the `ShowcaseZone` tradition: it runs only when an
operator asks for it by name and cannot be reached by accident. The gantry's
stairs stand in for the grapple M2's acquisition branch will grant, and the
scenario says so on a sign, because walking the player up to a control the
design says is grappled to would misrepresent the design it exists to show.

**THREE DEFECTS THE SCREENSHOTS FOUND AND NO TEST WOULD HAVE.** `make
railway-shots` renders the place and `godot-rail-junction` passed throughout
every one of these:

- **The gantry stair reached nothing** — four metres short of the platform and
  two metres below it. The lever was unreachable, and the scenario turns on
  reaching it. `_stair` now takes both ends and solves the count and tread from
  them.
- **The stowed span read as more track.** Swung aside about the vertical, a
  fourteen-metre beam lands across the yard at an angle that looks like rail.
  Raised instead — a drawbridge — *"the bridge is up"* reads from anywhere.
- **The direction chevron was a rectangle.** A `PrismMesh` shows its triangle
  along one axis only, so aiming the apex down the track left the player
  looking at the extrusion. Before that it was buried inside the plate
  entirely, because the plate is turned to face the dock.

These are facts about legibility and reachability. The suite now builds the
scenario and holds the parts a test can hold: the controls are wired and aimed
along the track, the platforms are at deck height, the player lands on one, and
the far end of the locked span meets S3 to within 0.01 m.

**NEXT:** the railway is playable and unplayed. Walking it is worth more than
the next feature, because everything after this reuses its parts.


## ENGINE LANE — the first thing that stays fixed — 2026-09-21

**M1, the engine half.** A player pulls a lever; a span of track swings home and
locks; the link the carrier was refused on becomes crossable; and coming back
later finds the railway repaired. `make godot-rail-junction`, 49 checks, in CI.

**THE CLIENT HAD NEVER SENT A LATCH.** `ZoneProgress.latched`, `LatchFired` and
`record_latch` have been on the bridge since the physics slice landed --
monotone, idempotent by `package_id/latch_id`, refusing any latch the committed
manifest does not declare, and tested including reload survival and the
snapshot. Every `latched` in this lane was prose in a comment.
`ZoneController.report_latch` is the missing half, and `main.gd` now unions
`progress.latched` into `latches_carried` beside keys, locks and stations.

**FOUR LIFETIMES, MEASURED SEPARATELY**, because a system that treated them
alike would either lose a repair the player earned or resurrect a moment they
did not. The accepted repair persists and is RECOMPUTED at build time, never
separately saved (§5.4a). A span left mid-travel leaves nothing behind -- that
is the case that stops "accepted consequence" collapsing into "something
happened". The lever comes back armed. The carrier is parked on a dock this
build supports, never resumed from a saved transform.

**A RESTORE REPORTS NOTHING**, and the suite checks it: re-emitting the latch
would be the client telling the bridge a fact the bridge told the client, and on
a monotone set that noise is indistinguishable from a real latch.

**BLOCKED, AND NOT WORKED AROUND: a junction inside a real composed Zone.** A
physics package binds to `feature:<tag>` or `shell:<shell_id>`
(`layout.py::_content_refs`), and §13.2 forbids a `features:` tag from
mattering. Nothing in the Zone schema declares rail content, so the composer
cannot ask for a junction and the engine must not invent one. That is **D-4**,
and it is Dess's. One saved latch does not prove general persistence and is not
reported as if it did.

**`godot-return-journey` HAD BEEN RED SINCE `19c5d8e`.** The return plug stopped
being a tripwire that frame; two of its three consumers were updated and the
third -- the only one CI does not run -- was not. Its own guard file's thesis is
*"a suite nobody runs is worse than no suite"*. Repaired by holding in the pad
rather than by relaxing the assertion, and the entry is now checked to fire
NOTHING. The suite runs green end to end, including the three legs its CI
exclusion note calls blocked; that note may be stale and the exclusion was left
alone rather than changed without the owner.

**NEXT:** make M1 playable. Nothing yet lets the owner walk into it.


## ENGINE LANE — the railway: a carrier, its controls, and a beam that was in the wrong place — 2026-09-21

**0.4 line only.** `claude/archipepsi-0-4-blindside`, branched from `19c5d8e`.
The 0.3 comparison build on `claude/archipepsi-echoes-continuation-b1adno` is
untouched. Durable detail lives in `docs/ledgers/HUGE_BATCH_LEDGER.md`.

**P0 SAID THE CARRY WORKS, SO THE CANDIDATE `player.gd` REPAIRS WERE WITHDRAWN.**
Four hypothesised hazards (the step-down walker's raw `move_and_collide`, the
step-up teleport, world-space walk targets, `is_on_floor()`-gated control) were
named in the plan as likely repairs. None of them bit: four cases, all ABOARD,
grounded on 1200 of 1200 measured frames. Measurement, not reading.

**`RailCarrier` IS `MovingPlatform` WITH A PATH.** An `AnimatableBody3D` with
`sync_to_physics = true` advancing an offset along a `RailPath`. Docks are
ordered; `links[i]` joins dock `i` to `i+1`; a link that is not commissioned is
missing rail and the request is **refused at the dock, by name**, not glided
over. `godot-rail-carrier` is 73 checks — travel, stop, refusal, repair, repeat
shot, reverse, fail-safe hold, and a real `Player` carried round the corner
(DRIFT 0.124 m, GROUNDED 273/273, ABOARD yes).

**TWO DEFECTS FOUND BEFORE IT SHIPPED.** The textbook `v^2/2a` brake undershoots
by `v*delta/2` — 0.058 m at 7 m/s and 60 Hz, further than `DOCK_EPSILON` — so
the carrier would stutter into every dock; replaced by a speed ceiling of
`sqrt(2*ACCEL*remaining)`. And `hold(true)` left the carrier between docks where
every later command answered *"there is no dock behind this carrier"*: a
fail-safe that can never be released is a trap with a passenger in it.

**THE BEAM WAS NOT WHERE THE RIDE IS.** `RailPath` gained Catmull-Rom handles in
P3.5; `build_rail` still swept the CONTROL points. On a four-point bent route the
ride leaves that chord by **0.744 m** — the beam is 0.35 m thick. Swept along the
ride: **0.030 m**. Every rail shipped today is two points, `bow()` 0.0000, and is
swept exactly as before; the suite asserts that. `_the_rail_mesh_and_ride_come_from_one_path`
was asserting the divergence, so it now reads against the swept route and keeps
its sabotage resistance explicitly (the swept runs must not all be one length).
14 pieces checked where 3 were.

**A CONTROL IS SHOT, AND A COMMAND IS MOMENTARY.** `RailReceiver` wraps
`ActivityElement` SHOT — the organ that already builds a `TargetBody` a ray can
reach and joins `Damageable.GROUP` — and re-arms, because an element LATCHES and
a latching direction control is a one-shot lever. The re-arm window is also the
debounce: a shotgun's pellets are one request. `RailControls` collects a frame of
commands and resolves them together, so FORWARD and BACK in the same instant
**cancel and say so** rather than racing. Proven through
`Player._fire_static_pulse`, not by calling the element.

**NEXT:** P4/M1 — the first persistent machine chain. A player-performed setter
interaction fires the never-yet-sent `latch_fired`; the link's commissioned state
is **recomputed from the latch at build time**, never separately saved (§5.4a).


## ENGINE LANE — the exit that was a wall, and the plug that was a trap — 2026-09-20

**TWENTY OF TWENTY SAMPLE ZONES COULD NOT BE FINISHED.** The playtest
report was *"the exit is still a wall; if it's a door, how am I meant to
open it?"* with 15 of 15 Checks claimed and the HUD reading `EXIT 2m`.
Measured: `c023`'s exit doorway at `(-156.3, 31.6, -141.3)` is SEALED by
a solid slab, and that slab is the first solid thing 4.5 m back from the
exit room's own -- open -- entry face. The exit room was never at fault.

**BOTH HALVES WERE RIGHT ON THEIR OWN TERMS, WHICH IS WHY NOTHING CAUGHT
IT.** `topology.py` chains with `zip(spine, spine[1:])`, so the LAST room
is assigned no `exit` and `_seal_the_rest` seals it -- correct, because
nothing in THAT graph follows it. `zone_builder` then appends the exit
room and routes its approach out of exactly that face. A census of the
declared sample: **20 of 20 ended on a room whose exit was SEALED.**

**`ZONE_EXIT`: THE COMPOSER DECLARES THE WAY OUT.** A fourth `DoorUsage`,
passable geometry that names NO edge, because the room on its far side
is the engine's appended exit room and is in no `edges` list.
`_reserve_the_zone_exit` gives it to the last room on the spine in both
composers. Everything downstream keys off "not SEALED", so `cut_plan`
carves it and `layout.validate` expects a hole **with no exemption
anywhere** -- `SEALED` stays strict, and the wire and the geometry agree.

**THE ENGINE-SIDE CUT WAS TRIED FIRST AND WAS WRONG.** Having the engine
open the door on its own copy built fine and was then refused by the
bridge for every Zone: *door 'c023/exit' is SEALED and the engine
measured it as a hole*. Recorded because it is the evidence that this
could not be fixed in one lane.

**CONSTRAINED, NOT A LICENCE.** `Zone` refuses more than one `ZONE_EXIT`,
and refuses one on a room the chain still departs from by a JOINED edge.
Unrelated sealed faces stay sealed: `c023` keeps `side_left` and
`side_right` SEALED, and branches and Check allocation are untouched.

**OLDER SAVES ARE NOT TOUCHED.** A Zone committed before this existed
carries `exit: SEALED`. With its committed layout it **rebuilds exactly
as saved**, sealed exit and all, so nothing about a part-finished Zone
changes; proposed FRESH it is **refused**, naming the room, so the
bridge composes another. Both halves are measured against a fixture
taken from the sample (`fixtures/legacy/sealed_exit_zone.json`). No
migration, no abandonment.

**`make godot-exit-reach`** asks APERTURE, APPROACH and DEPARTURE of
every Zone in the declared sample with rays against built geometry, plus
a BACKTRACK naming the room that owns whatever is in the way, plus the
older-save pair. 81 checks, in CI. **Sabotage-verified.**

**AND THE WHOLE CONNECTION, NOT AN APERTURE.** `godot-traverse` now
walks the last room's ZONE_EXIT doorway -> the appended approach ->
the portal (REACHED, addressable at 2.11 m), unlocks it the way the
bridge does, interacts through `ExitPortal.interact`, and asserts
`ZoneController.exit_requested` -- the signal `main.gd` binds to
`_on_exit_zone`. **And that a portal still holding 3 Checks does not
fire**, so the check cannot pass on a portal that always opens.

**REPORTED, NOT ASSERTED:** the leg from `c023`'s arrival to its own
doorway is walked and printed rather than gated -- that room's arrival,
its Check pedestal and its exit are COLLINEAR, so a straight-line walker
jams on furniture a player walks around. The doorway being open from
inside the room is what `godot-exit-reach` measures, on all twenty.

**AND THE PLACEMENT SEARCH NOW HAS A BUDGET.** The new doorway moved one
live Zone from "routes" to "forty seconds, then refuses" -- feasibility
is content-dependent and the sample census is unchanged at 19 of 20 --
and that forty seconds runs on Godot's MAIN THREAD, so the client missed
websocket keepalives and the bridge dropped it mid-build: *sent 1011
(internal error) keepalive ping timeout*. The `build_failed` went into a
dead socket. `ZoneBuilder` has had `budget_ms` and `LAYOUT_TIMEOUT` all
along; its only caller passed `0.0`. Now 6000 ms -- ~3x the slowest Zone
that routes (measured: median 321 ms, p90 711 ms, max 2070 ms) and a
third of the keepalive. **A committed replay is exempt.** A/B verified:
green through `zone_015` with the budget, connection death without it.

**THE RETURN PLUG NO LONGER FIRES ON CONTACT.** It arms on entry and
fires after `HOLD_SECONDS` (2.0) of unbroken contact, with a ring that
climbs and a label that counts down; **leaving cancels it and costs
nothing**. Charged in physics time, where the contact is measured. The
two suites encoding the instant trigger were UPDATED, not weakened:
walk on, REMAIN, assert arrival -- and traverse asserts the wait is
real (113 frames held, of at least 60 owed), without which the contract
passes with `HOLD_SECONDS` at zero.

**FIXTURES REGENERATED FROM SOURCE:** the 20 sample Zones and
`played_zone.json`. The census is unchanged at **19 of 20 laid out and
ACCEPTED, 0 refused**; `zone_08` is the pre-existing router case and was
not forced.

**STILL OPEN.** Plug PLACEMENT ("only at the end of a long branch") is
shared `topology.py` and is untouched. 7 of 27 SHOT targets in Zone 1
aim into geometry (`godot-target-facing`, a report, not a gate). Both
climbing producers file their `exit` door record past the wall the hole
is cut in -- `tower` 9 m up and 2.2 m beyond, `platform_path` 2 m up --
so an aperture probe there reads the landing; recorded with numbers by
`godot-zone-audit`, not repaired, because `door_world` feeds join
sockets and lock slabs.

## ENGINE LANE — the last three sample cases, and a hang — 2026-09-19

**`zone_05` was a real collision, and the check that would have caught it
was never run.** `layout_findings` — written because "a builder whose
incremental check has a blind spot passes the first and fails this one"
— was called only from `room_contract_driver.gd`. Measured in the
assembled Zone rather than argued: `{ "c013": 1, "c010": 1 }`, one
collider from each room in the same 0.5 x 5.5 x 0.05 m box, and the
shape is not a collar. The SEARCH check asked a different question from
the committed one — a volume bound of half a cubic metre against a shape
rule — so it asks the collar question now. **That is a tightening**, and
`zone_05` now routes and is ACCEPTED. It ignores contacts thinner than
`BRIDGE_EPSILON`, the validator's own millimetre, because two abutting
rooms leave float noise on their shared face and a shape rule reads that
as a fourteen-metre interpenetration.

**AND THE COMMITTED CHECK IS NOT WIRED INTO THE ROUTER.** Wiring
`layout_findings` into `build()` was tried and reverted: it judges by
SHAPE, and two rooms wall-to-wall share their whole 0.4 m wall
allowance, so every tower and treasure shell became unplaceable. **An
envelope check cannot tell abutment from interpenetration** — only the
solids can, and that needs a physics space the router does not have.
That is the boundary this batch stops at.

**`zone_07` and `zone_08` share a cause and the ladder never reached
it.** `_wedged_after` mapped a wedged BRANCH room to its parent's spine
index and found nothing when that parent was itself a branch — so both
reported *"1 placement attempt(s); nudged nothing"*. It walks up the
branch tree now. Both spend 7 attempts and get materially further. With the search
correction below, **`zone_07` routes**; `zone_08` still exhausts the
bounded budget, and that is the limit, recorded not widened.

| declared sample | submitted | overall |
|---|---|---|
| before | 17 of 19 accepted, 2 refused | 17 of 20 |
| **after** | **19 of 19 accepted, 0 refused** | **19 of 20** |

`zone_08` alone produces no manifest; `zone_07` routes. The harness also stopped
judging STALE manifests: one is written only for a Zone that lays out
and was never deleted for one that stopped, so the census once read "19
of 20 laid out" beside a PLAYABLE line saying 17.

**NAMED CASES NOW RUN LIVE:** `make godot-named-case CASE=zone_05`.
`--epsilon=sample` serves one proposal re-keyed to a disposable
campaign's own identity and allocation; the client builds, certifies and
submits it for a real verdict. Nothing is fabricated.

**AND IT FOUND A HANG.** Pointed at a deliberately unroutable control,
the client never built and the Hub sat in GENERATING. Not the routing:
the validator's refusal message is longer than the 160 characters
`last_generation_error` allows, so `CampaignSnapshot` raised on
construction and killed the generation task AND the broadcast. **The
refusal died on its own error string.** Trimmed at the assignment sites
— widening the field moves the cliff. With it, the control refuses,
falls back, composes, is ACCEPTED and entered, Hub ZONE_ACTIVE, 15 of 15
Checks.

**THE OFFLINE FAILURES ARE SEED-SPECIFIC.** `ZoneBuilder` seeds
placement with `hash("<zone_id>|<theme>|layout")` and a campaign gives a
proposal its OWN zone_id. `zone_05`, `zone_07`, `zone_08` and `zone_12`
were each ACCEPTED first time live, 0 refusals, entered — including the
two the census calls unroutable. So "unroutable" means "unroutable under
the seed it was dumped with", and the phase prints that on every run.

**Save proposal:** unimplemented, targeted repair still the direction,
and the digest wording corrected — an anchor change needs a **new
content digest** plus explicit `repaired_from` linkage, never a
"same-digest repair". Committed-manifest protections untouched.



## ENGINE LANE — a door is not an opening while content stands in it — 2026-09-19

**FOUR MISMATCHES, TWO CAUSES.** `RoomAudit.aperture_blockers` reported
a node path and a step; it now carries the blocker's collision box back
through the same transform the door went out by, so the two can be
compared instead of inferred. That is what separated them:

| case | door (room-local) | blocker (room-local) |
|---|---|---|
| `zone_02` `c013/side_left` | (-3.95, 0, 6.8) | chain leaf x -4.55..-2.45, z 7.55..7.75 |
| `zone_04` `c009/side_right` | (4.0, 0, 6.8) | the same, mirrored |
| `zone_10` `c005/side_left` | (-11.75, 0, 9.65) | deck x -11.75..9.75, **y 1.34..1.74**, z 9.0..17.3 |
| `zone_14` `c006/side_left` | (-9.05, 0, 10.9) | a deck-height slab |

**A:** a side doorway is cut at the MIDDLE of the wall, which is exactly
where `resolve_position` puts a feature pushed out of the walking lane.
**B:** a `back` gallery's deck spans the room's WIDTH and meets both side
walls -- and `_side_socket` spelled its guard `f"side_{band.side}"`,
which for a `back` band is `side_back`, a socket that does not exist and
excluded nothing.

**BOTH REPAIRED AT `topology._side_socket`,** the one place that knows
the doors and is still free to choose. It already avoided the wall a
`left`/`right` deck hugs; it now blocks BOTH sides for a full-width band,
and blocks a side socket in a room whose features cannot clear it. **The
DOORWAY moves, because the feature is already placed and the door is
still being chosen.** Nothing turned SEALED, no branch dropped, no Check
reallocated, validator untouched. `FEATURE_MIN_DEPTH_BESIDE_DOOR` --
`2 * (2*half_depth + DOOR_WIDTH/2 + THRESHOLD_CLEARANCE)` -- is pinned
against the builder's own constants from both sides.

| declared sample | submitted | overall |
|---|---|---|
| before | 12 of 19 accepted | 12 of 20 |
| **after** | **17 of 19 accepted** | **17 of 20** |

All four named doors read as openings through a real `ZoneController`
(68, 62, 58, 62 doors measured, none solid) and every SEALED socket in
all four is still solid. **Revert control:** reverting `_side_socket`
alone fails two named regressions.

**REMAINING, NAMED, NOT A ROUTER REWRITE:** `zone_05` rooms `c010`/`c013`
overlap; `zone_08` does not route and emits a partial manifest;
`zone_07` produces no manifest at all.

**THE SAVE PROPOSAL IS CORRECTED.** Option A's claimed recovery was
wrong: `campaign.py` re-selects hosts only `if verdict.unhostable_rooms
and rec.manifest is None`, and `refuse_layout` preserves a committed Zone
as DORMANT with its progress intact and no way back in. So a refused
replay costs the whole Zone, behind an ABANDON the player pays for.
**`docs/RETURN_ANCHOR_PERSISTENCE.md`** now documents that, says what
each option would additionally need, and recommends the targeted anchor
repair (B) with A as its floor -- losing a solved Zone to relocate one
convenience device is out of all proportion to the fault. The
committed-manifest protection stays. Nothing implemented, nothing
migrated.

**AND `test_full_loop` IS LABELLED HONESTLY:** real handler and real
validator, **synthetic evidence**; `godot-integration` is the separate
physical and live coverage. Neither substitutes for the other.



## ENGINE LANE — ordinary generation: 0 of 20 was the harness — 2026-09-19

**The sampler's "0 of 20 accepted" was wrong twice, and the Zones were
not the reason either time.**

**NAMED CASE `zone_01`** — lays out physically, refused with one error:
*"room 'c001' declares 1 'powered_door' chain(s) the engine must certify
and the layout offers 0"*. Followed to its producer:

1. **A missing evidence class.** `ChainCertificate` is the only thing
   that makes a certified package and it ran only inside
   `ZoneController._certify_physics`. The harness stands a Zone up and
   measures it with the same `RoomAudit.measure_layout` a played Zone
   uses -- then emitted `packages: []` every time. The loop is now
   `ChainCertificate.of_build`: one implementation, two callers, the
   liveness guard passed in so the controller keeps its "a partial
   certification is never published" rule.
2. **A success test that could not be true.**
   `check_sample_layouts.py` asked `status == "LAYOUT_OK"` -- the
   ROUTER's word. `layout.validate` returns `ACCEPTED`/`LAYOUT_REFUSED`
   and carries `.accepted` for exactly this. The tool reported 0 **by
   construction**, for its whole life, hidden by (1).

**THEN THE CONTENT DEFECT UNDERNEATH.** `AffordanceFeatures.fits` asks
about width AND depth; only the width half was ever written down in
Python. A `powered_door` reaches 3.5 m along the run and needs **11.0 m**
of corridor -- the sample hung it on corridors of 8.6, 9.0, 9.2 and
9.8 m. All four passed `FEATURE_MIN_WIDTH`, all four were dropped by the
builder, all four Zones refused for a chain declared and never built.
`FEATURE_MIN_DEPTH` now joins it, pinned against
`AffordanceFeatures.FOOTPRINT` from both sides; the chamber model, the
shell selector and the fallback all ask it.

**NOT BY STRETCHING THE ROOM.** Lengthening a last-resort corridor cost
two Zones -- `zone_12` became a room overlap and `zone_18` stopped
routing. Widening moves a wall; lengthening moves everything downstream.
A tag with no corridor long enough is not dealt.

| on the same declared sample | accepted | lay out |
|---|---|---|
| reported before | **0 of 20** | 18 of 20 |
| harness repaired | 10 of 19 | 18 of 20 |
| + producer, by stretching | 11 of 19 | 17 of 20 |
| **+ producer, by not** | **12 of 19** | **18 of 20** |

**AND THE DOOR-POLARITY NOTE IS FOLKLORE.** `zone-sample` has carried
"door-polarity refusals here are about this harness" unmeasured for
months. Built and stood up by a real `ZoneController`, `zone_02` measures
`c013/side_left` **SOLID** while the composer declares it USED -- 1 of
68 doors, the exact door the bridge refuses that Zone for. The traverse
driver reports this on whatever Zone it is given; `played_zone`'s 66
doors all read as openings. **4 of the 7 remaining refusals are that
class and they are real.**

**SMOKE, RECONCILED WITH CERTIFICATION.** `claim_zone_check` refuses a
Check against unvalidated geometry, and `smoke.py` has no client, so its
claim/Echo/equip/reload half had been failing since that guard landed.
Every assertion moved to `bridge/tests/test_full_loop.py`, which enters
through `conftest.enter_zone` and certifies via the real
`handle_layout_result`; the live half is `godot-integration`. `smoke.py`
keeps what needs no client and now **asserts the guard**: UNCERTIFIED,
claim raises, refusal names the layout, location not marked checked.
Nothing was deleted and no placer was shipped in the package.

**THE SAVE ANCHOR ISSUE IS NOW ACTIONABLE, NOT ACTED ON.**
**`docs/RETURN_ANCHOR_PERSISTENCE.md`** — three options, recommending
the one that persists nothing new and migrates nothing: replay the
recorded anchor, re-measure it with the settle's own predicates, and
refuse the layout when it no longer holds, which is the recovery loop
the campaign already has. No migration was written, the placement repair
stands, and the owner's diagnostic save is untouched.

**STILL OPEN, SEPARATELY:** the 7 remaining sample refusals (4 door
polarity, 2 room overlap, 1 a Zone that does not route), `zone_07` which
never lays out, and remote CI startup, whose cause remains unconfirmed
and which nothing here waits on.



## ENGINE LANE — the c021 return, repaired and walked — 2026-09-19

**The acceptance case executes.** One route on `c021`, guaranteed kit,
every trigger live, nothing relocated between legs: real arrival
`(5.6, 0.0, 42.2)` -> the whole course **REACHED** in 143 frames with
the pad **not firing** on the way -> CHECK 126 found by the game's own
interact ray from where the route ends, and its real `interact()` run
from that position -> a deliberate walk onto `p:c021:start`, which
**fires** at frame 14 and **delivers**: the walk stops there and the
body lands **0.20 m** from `zone_start`, which is `anchor + UP * 0.2`
exactly. **30 checks on a fresh build from the owner's proposal.** Page:
**`docs/PLAYED_SESSION_FINDINGS.md`**.

**BOTH END CHECKS WERE LOOSER THAN THEY LOOKED, and are now tight.**
`interact_prompt() != ""` is a property of the OBJECT -- it reads the
same from the next room -- so it asserted nothing about where the route
ended; the game's own interact ray, polled from the final position, is
what answers, and the reward's own interaction path runs from there.
And the return leg used to keep steering for a hundred frames after the
teleport, drift several metres, and be excused by a tolerance of "a
quarter of the journey". `_walk` now takes a stop predicate and ends the
frame the plug fires, so what is measured is the LANDING.

**THE DEFECT WAS IN TWO PLACES AND THE SECOND ONE DID THE DAMAGE.**
`return_spot` reserved the end ledge's centre, which on a platform
course IS the reward. Then `RoomAudit._settle_return_anchors` rejected
that spot and searched -- and put the device on **island 3, the last
platform before the Check**. The guard meant to stop exactly that,
`clear_of_content_path`, was guarding nothing: its content point is the
room's warp station, `c021` has none, so `content_of` answered `INF` and
every candidate passed. Measured: unrepaired, the builder publishes
`(24.27, 1.53, 42.25)` and the controller receives `(19.0, 1.5, 42.2)`.

**REPAIRED IN BOTH.** `return_spot` now gathers the claims first and
tries the declared stands furthest-first, sampling each surface -- on
`c021`, local `(2.6, 1.53, 21.62)`: the same end ledge, beside the
reward, past the course. `content_of` falls back to the committed
reward where a room has no station. The first alone fixes `c021`; the
second is why the settle cannot re-create it elsewhere. No world
coordinate is hardcoded, no jump buff, no disabled trigger, no
completion gate.

**OPEN DEFECT, RECORDED SEPARATELY AND NOT RESOLVED HERE: a replayed
save does not keep its committed return placement.** The save file is
untouched -- `work_manifest.json` still carries
`room:c021:return = [18.99, 1.53, 42.25]`, byte for byte. But
`layout_from_json` parses the archived `anchors` block and `_build_once`
consumes only `rooms` and `joins`, so every anchor is RECOMPUTED from
the replayed poses. Reopening the owner's save on this build moves
`room:c021:return` **5.89 m**.

**That contradicts the committed-placement claim this branch has been
making** -- "a committed layout is replayed, never re-solved" holds for
room poses and joins and does NOT hold for anchors. This batch does not
adopt that as the intended persistence contract, does not revert the
placement repair to hide it, and does not invent a migration. It is an
open question for the owner: should a replayed anchor come from the
manifest, and if so what happens to a manifest whose anchor the current
rules would now refuse.

**AND A CORRECTION TO THE ENTRY BELOW.** "Archived and fresh anchors
agree" was stated twice off a comparison that read the "fresh" value out
of a `--manifest-json=` build -- the archive against itself. The claim
is true; that evidence never supported it. What does: a fresh build with
no manifest, on the unrepaired code, lands at `(19.0, 1.5, 42.2)`
against the archive's `(18.99, 1.53, 42.25)`.

New suite: `make godot-return-placement`, in CI.

**WHAT ELSE MOVED.** `godot/tests/fixtures/placement/supported.json`
regenerates with `room:c005:return` 2.6 m along -- the producer repair
putting a second room's return beside its reward instead of on it. The
`controller_digest` in `captures.json` is unchanged; only its
`source_commit` moved. `bridge/tests/test_placement_contract.py` reads
both and passes on the new pair. The whole CI list is green: python
1584 + 627 subtests, and every `godot-*` suite including `godot-reload`
(cold restart) and `godot-integration` (live bridge).

**THE DECLARED SAMPLE, MEASURED BOTH WAYS.** `make zone-sample` is
**0 of 20 accepted before and after**, and the Godot side still reports
`18 of 20 lay out; unbuildable: zone_07, zone_11` unchanged. One line
moved: `zone_11` went from *no manifest at all* to *a manifest the
bridge refuses*. Attributed by bisection -- with only the `return_spot`
repair the sample is byte-identical to baseline, so the `content_of`
fallback is what moved it. The 18 standing refusals are unchanged and
are about `powered_door` chain certification and join evidence, not
returns. **The sampler's own uncertainty stays separate from this
repair** and neither improves nor excuses it.

**OPEN, SEPARATE: REMOTE CI DOES NOT START.** Runs 357, 358 and 359 on
this branch each fail seconds after starting, with one job that reports
no steps, no assigned runner, empty `output.title`/`summary`/`text`, and
HTTP 404 on its log download. One re-run of the PR gate behaved the same
way. **The cause is unconfirmed** -- the metadata shows a job that never
ran, and nothing observed here says why. So a red conclusion on this
branch is not a statement about any commit in this batch, and the
verification of record is the LOCAL frontier run below. Not polled, not
re-run again, and no check-in scheduled for it.

**STILL RED, AND NOT FROM THIS BATCH: `make smoke`.** It fails with
`Zone 'zone_001' has not had its layout accepted (layout_state
UNCERTIFIED)`. Reproduced identically at `3f00ef2`, the commit before
this batch. Cause: the guard in `transitions.claim_zone_check` landed in
`9137c17` and is correct -- a Check may not be claimed against
geometry the bridge has not validated -- while `smoke.py` is
bridge-only, has no Godot client, and so never gets a layout certified.
**Not fixed here on purpose.** The two ways to make it pass are to stop
claiming Checks (deletes most of what the smoke covers) or to ship the
tests' synthetic `place_layout` inside the package (validation
constructing gameplay, which F-4 forbids). Which one the smoke should
become is a decision, not a repair.


## ENGINE LANE — Route C: not demonstrated, and why — 2026-09-18

The complete outbound route with every trigger active COULD NOT BE
DEMONSTRATED, and the interference is arithmetic.

`c021` is a line of NARROW PLATFORMS over the drop, not a wide walkway:
the centreline is solid x14.2-15.2 (y1.02), GAP to 17.7, solid
18.2-19.7 (y1.53, the pad's platform), GAP to 22.3, solid at 22.8 --
and at +3.0 m off-centre there is no floor at all. Swept laterally at
the pad's x: **the platform is 2.50 m wide (+/-1.25 m). Passing a 1.4 m
trigger with a 0.4 m body needs more than 1.80 m. Short by 0.55 m.**
The trigger spans its own platform; there is no floor beside the pad to
walk past it on.

SPECIFIC TO THIS COMMITTED PLACEMENT AND THIS CONTROLLER, and NOT a
claim that no route exists: the kit has a jump, this walker steers in
straight lines, and a player's own solution is not ruled out. Nothing
was repaired -- the pad was not moved, no return disabled in the live
route, no activation policy changed. *(Superseded above: the pad HAS
since been repaired, and "archived and fresh anchors agree" rested on a
circular comparison. The conclusion stands on better evidence; the
reasoning here does not.)*

**FOUR PROBE DESIGNS MEASURED THE WRONG SURFACE BEFORE THIS ONE** --
fixed height (rejected every ledge the course climbed above), room top
(a slab 6 m over the walkway, reported as 20 of 20), pad level (missed
everything climbed past it). Then the fourth was CORRECT at 2-3 of 20
and I distrusted it because it disagreed with a lane I had convinced
myself existed. Two commits in the sequence could not parse. The lesson
is in the file: print what the rays return before applying any
criterion to them.

Kept: the real-arrival test and the A/B diagnostic. `godot-traverse` is
23 checks on the fixture, 26 on a saved level.


## ENGINE LANE — the c021 crossing, from the real arrival — 2026-09-18

Two owner corrections to the saved-level work, both applied. Page:
**`docs/PLAYED_SESSION_FINDINGS.md`**.

**THE START WAS THE WRONG DOOR.** `_nearest_doorway` picks by distance
and checks neither usage nor the assigned arrival, so on `c021` it chose
`c021/exit` -- SEALED, no edge, nowhere a player has stood. That result
is LOCAL APPROACH EVIDENCE only. The route was re-run from the committed
arrival `(5.65, 0.0, 42.25)`, where `e:c018:c021` puts a body down, one
continuous walk, guaranteed kit, nothing relocated.

**A (everything live): the return plug FIRED.** `p:c021:start` sits on
the line, 13.4 m along an 18.7 m run, and announced itself on its own
`traversed` signal; the body left for `zone_start`. The DEVICE working,
not the course refusing.
**B (that one trigger muted): REACHED, 2.20 m, 143 frames** -- the
course is crossable from its real arrival on walk and jump alone.
**A valid way out is demonstrated:** walking from the Check onto the
plug fires it. Its walk outcome says BLOCKED at 2.25 m, which is the
walker aiming at a pad the body has just left -- an earlier version read
that as a softlock, which is the instrument measuring itself again.

**CONTROLLER: CURRENT, with this batch's descent repair.** Success here
says nothing about the owner's older build and does not explain their
session.

**WITHDRAWN: the "timed, gap-spanning switches" reading.** Measured:
`time_limit` 0.0, `ordered` false, all four switches at x 4.6 y 1.0
spanning 5.0 m in z at the ARRIVAL end, with 0 of 11 floor samples
missing between first and last -- ONE CONTINUOUS LEDGE, as the owner's
screenshot showed. It came from one camera angle instead of a
measurement. No replacement explanation is offered for the 792 active
seconds, and elapsed activity time is not used as a difficulty
diagnosis.

**26 of 26 checks pass on the saved level;** the ordinary fixture run is
unchanged at 23.


## ENGINE LANE — the saved level, walked — 2026-09-14

The owner's full bundle arrived: proposal, COMMITTED MANIFEST, `.bak`
and playtime log. Worked from a disposable copy; **not committed,
originals unmodified**, checksums verified. Full page:
**`docs/PLAYED_SESSION_FINDINGS.md`**.

**THE GEOMETRY CHECK NOBODY HAD RUN.** The fixture carries a proposal
and NO manifest, so every engine measurement this batch SOLVED the
layout afresh -- the right rooms in an arrangement nothing had compared
to the played one. `godot-traverse` now builds the saved proposal twice,
re-solved and replaying the committed placement, and compares every room
transform: **worst room 0.000 m across all 24 records.** The earlier
measurements were on the played geometry after all -- verified rather
than assumed. The walker takes `--zone-json=` and `--manifest-json=` and
replays a saved level; **24 of 24 checks pass on it**.

**CHECK 126 IS c021, confirmed by the game.** Base kit reaches the
pedestal from `c021`'s own doorway on the committed placement and the
prompt reads `[E] CLAIM CHECK 126`. `89100120` is allocated NOWHERE in
the save. A render of `c021` is in `docs/evidence/owner-save/`: the four
switches sit spread along the platform course over the drop, which makes
the 792 s on `c021_0` at least plausible -- correlation, not diagnosis.

**TWO WHISTLES, AND 126 IS THE UPGRADE.** First acquired at seq 4 from
CHECK 019 at 14 m; CHECK 126 at seq 5 IS the +6.0. So whatever crossing
reached 126 used AT MOST the 14 m Whistle. This page previously quoted
only the final 20 m -- right number, wrong moment, corrected.

**AND THE BASE-KIT CLAIM IS NOW EVIDENCE.** It was derived from declared
`gap_size` values, which say nothing about built geometry. Re-answered
by walking the committed placement: 6 of 6 sampled Checks REACHED, 0
BLOCKED, `Reward_89100126` addressable and its room leavable across a
measured 2.00 m gap. Six of fifteen sampled -- not a proof about all.

**Exit approach on the saved `e:__exit__`:** REACHED from `c023`, the
interact ray finds the portal, 3 of 16 bearings standable. `c023`'s
ordinary exit is SEALED while the synthetic join exists; both facts
preserved, neither is a verdict.

**The elapsed 4770 s is not play time** -- the session included
discussion and assistance. Re-worded wherever it implied otherwise.


## ENGINE LANE — the owner's own session, read — 2026-09-14

A private copy of the `.diagnostic-582e954` slot JSON, its `.bak` and a
`playtime.jsonl` arrived. **Not committed, originals untouched.** Full
page: **`docs/PLAYED_SESSION_FINDINGS.md`**.

**`played_zone.json` IS that Zone** -- same `zone_digest`,
`fe2b014761fbb449`. Every engine measurement this run (the `c021` Check
approach, the mounting census, the `c007` unmounted shot, the sealed
sweep, the panel) was taken on the level actually played.

**The Whistle crossing is answered.** The `.bak` and the live save
differ in exactly ONE field -- `slots.mobility`, Fresh Rep (dash) ->
Warp Whistle (blink, 20.0 m after four upgrades, cooldown 2.10). And
NOTHING IN THAT ZONE NEEDED IT: five rooms declare a gap, the widest
2.31 m against a 2.40 m base-kit allowance. Convenience, not a key; the
Zone stayed base-kit solvable.

**`Reward_89100126` is in the save as a collected Echo.** The Check this
lane reported as unreachable and then retracted was reached. The
retraction was right.

**THE TWO RETIRED FAMILIES ARE BROKEN, WHICH IS NOT WHAT THE VARIANT
FIXES.** `timed_run` completed with 0.00 active seconds 5 times of 9 --
median zero. `pressure_routing`: one activity needed 23 ATTEMPTS for
2.72 s of work, one needed 3, one was entered and never completed (the
Zone's only failure). The variant removes these two to cut content
VOLUME; the session says they should go because they DO NOT WORK. Two
different problems, and a 28% budget cut addresses neither. Not chased
-- diagnosing them is new work.

**Other numbers worth a look:** 79.5 minutes in one Zone, only 29% of it
inside an activity; the room holding the 23-attempt plate ate 17.7
minutes for 43 points; `c021_0`'s active timer ran 792 s on four
switches.


## ENGINE LANE — the variant, live at default scale — 2026-09-14

Merged the bridge lane at `fc7b6fb` (the acceptance correction; its two
rejection controls retained and re-verified decisive here without
editing the module). Full page: **`docs/FOLLOWUP_02_INTEGRATION.md`**,
§6a.

**THE VARIANT IS PARKED WITH ITS REPRODUCTION:
`make godot-integration-variant-live`.** One Zone, default scale,
variant on, nothing arranged. The band is genuinely lower -- the bridge
asks for **720 of 1000**, and the target fails if the clamp warning
appears -- and then ordinary bounded recovery NEVER STARTS: 1 router
refusal at build time, 0 certification refusals, 0 exhausted.

**Why: `ZoneController.setup` has two refusal paths and only one has a
recovery.** A certification refusal happens after a successful build,
goes to the bridge, and is bounded by `MAX_LAYOUT_REFUSALS`. A ROUTER
refusal happens during the build -- `setup` records `layout_failed` and
returns, nothing is sent, no verdict ever comes. `layout_failed` has no
consumer anywhere in the engine. **Pre-existing, not variant-specific**:
the same dead end on normal generation, which the variant reaches often
(3 of 5) and the baseline rarely (0 of 5). Fixing it is a protocol
change across both lanes and was NOT made.

**Two stages, not a contradiction.** Bridge validation asks whether a
proposal is sound; the router asks whether the rooms can be placed.
12/12 validated and 3/5 placed are answers to different questions -- my
earlier "the two sides disagreeing" was wrong. The station averages are
over successful builds only: five baseline, two variant.

**`test_startup` stays OPEN.** It does not reproduce here (5x alone, 3x
the file, every full-suite run), and that does not resolve Dess's 2-of-3
failures elsewhere. The fixed `TEST_PORT` is a HYPOTHESIS, never
observed; no waiver, and no owner decision is being asked for.

**The ordinary diagnostic replay is unaffected** and stays available
whatever happens to the variant.

**Verified at `a820ca3`:** one clean run, 29 targets green, final exit 0
(bridge 1414, apworld 39 + 627 subtests, schemas 131, 26 Godot targets
including all three integration loops). Numbers and limits in the
integration page, §8.

**The heartbeat stays PAUSED.** The authorised list is done: Dess's
correction is in, the variant is parked with its reproduction, and the
run is green. Turn it back on when there is a task -- unblocking the
router dead end is the obvious next one, and it needs an owner
go-ahead because it crosses both lanes.


## ENGINE LANE — follow-up 02 integration — 2026-09-14

**`claude/archipepsi-echoes-continuation-b1adno`**, merged from the
bridge lane at `fdac6ab`. Full page:
**`docs/FOLLOWUP_02_INTEGRATION.md`**. Read that, not this.

**The variant is selectable now, and selecting it needed two fixes.**
Separate save folders did not select it, and neither did the switch as
first wired: both `fallback_zone_attempt` and `generate_zone_validated`
read `request.campaign.zone_budget`, so narrowing
`constraints["zone_budget"]` changed nothing and delivered the
filter-only arm (a Zone asked for 72% arrived at 917 against 648-792).
Setting the band before the request is built fixed that and then crashed
at the low end -- 72% of the prototype's 200 is 144 against a floor of
200 -- so it is clamped to the floor and said out loud per Zone, because
a clamp that bites is filter-only again. `0.72` is untouched.

**Labelled as the owner asked: a LOWER-BUDGET GENERATION VARIANT**, not
the same level with two drills removed. +17 rooms, +27 enemies and
different rooms, carried in the banner, the launcher, `--help` and the
slot marker rather than left to be discovered.

**Stations counted, not inferred.** Five real manifests of each variant
built by `ZoneBuilder`: baseline 5 of 5 composed, 49 stations, 39
broken; variant **2 of 5 composed**, 20 stations, 12 broken. No station
in either starts broken in a room with no activity, and entrance and
exit are whole in both. The finding is the first column: three variant
manifests are refused by the engine's layout router (a branch room that
cannot be placed clear), all three accepted by `validate_zone` first.

**Both loops run.** `godot-integration` and the new
`godot-integration-quiet` both pass -- at prototype scale, where the
clamp makes it family-narrowing only. Default scale is not available in
that harness: it fails there for the baseline too.

**`test_startup`'s second-bridge case does not reproduce** (5x alone, 3x
the file, twice in the suite). Not waived: `TEST_PORT` is a fixed
constant and a colliding process on 38331 fails it for reasons unrelated
to the code. Left unchanged, recorded as a decision.

**The strictly matched no-compensation comparison remains incomplete.**
Recorded, not worked around.

**Verified at `6329cfa`:** one clean run, 28 targets green, final exit 0
(bridge 1412, apworld 39 + 627 subtests, schemas 131, 25 Godot targets
including both integration loops). Numbers and limits in the integration
page, §8.

**Waiting on Dess:** the `_accepts` correction. Nothing here depends on
it; their 12-of-12 acceptance figure does.

**The heartbeat stays PAUSED.** The authorised list is done and the run
is green. Turn it back on when there is a task -- integrating Dess's
re-report is the obvious next one.


## ENGINE LANE — owner-away follow-up 02 — 2026-09-13

**`claude/archipepsi-echoes-continuation-b1adno`**, from `eb14a38`.
Full handoff: `docs/FOLLOWUP_02_HANDOFF.md`. Ten-minute replay route:
`docs/REVIEW_ROUTE_0_3.md`. Read those, not this.

**Both fixture leads closed, and both were my instruments.** The Check
2.6 m "below the floor" sits on its producer's own end ledge with
0.00 m under it — the walker was standing in the secret alcove above
it, because the start rule cast from three metres up and took the first
surface. 6 of 6 sampled Checks reach now. `c001/side_left` is declared
`SEALED` with no edge; all 22 SEALED sockets measure solid. The 6-metre
partner proxy is gone, replaced by every declared door measured against
its own usage on the assembled Zone, with a counterpart that mislabels
a real opening.

**Mounting asks the geometry now.** As shipped it put 27 of 27 SHOT
elements on walls it never looked for. It needs a real wall behind the
stalk and somewhere a body can stand and shoot it from -- NOT floor
under the mount, which is the question a floor-placed element is owed
and which a first cut wrongly required. 15 of 27 mount in the
diagnostic Zone; every decline is printed by room, and there is no
quota. `godot-zone-audit` was corrected in the same pass: a mounted
element owes a standable firing position, not ground beneath it.

**The station panel reaches `main.gd`'s real consumers** — one warp,
no stale warp after the Zone is left, `leave_zone` never
`abandon_zone`, and closing it releases only its own modal claim.

**D (the opt-in quieter-generation comparison) is Dess's and is not
started here.** `origin/claude/archipepsi-amalgam-bridge` is still at
`afbdb7d`. `fallback.ACTIVITY_KINDS`, the compatibility tests and
`tools/family_retirement.py` are ready for it; station repair routes
are the thing to watch on integration.

**Waiting on the owner.** A private copy of `.diagnostic-582e954`'s
slot JSON; stair comfort; whether the unmounted target look is an
acceptable fallback; whether the F5 schematic is the map; the budget
shape.

**Verified at `e39bbca`:** one clean run, 27 targets green, final exit
0 (bridge 1389, apworld 39 + 627 subtests, schemas 131, 24 Godot
targets). Numbers and limits in the handoff, §6.

**The heartbeat is PAUSED.** Turn it back on when there is a task.


## ENGINE LANE — the owner-away batch — 2026-09-13

**`claude/archipepsi-echoes-continuation-b1adno`**, from `b914d98`.
Full handoff: `docs/AWAY_BATCH_0_3_HANDOFF.md`. Read that, not this.

**Done.** Stair descent repaired and its boundary proven (1 airborne
frame of 40, against 10; a 2.5 m ledge still falls at 9.2 m/s; a jump
at a tread's lip still peaks at 1.80 m; a ramp is unchanged). A new
`make godot-traverse` drives the real controller along named routes and
reports five outcomes of which only BLOCKED asserts — 5 of 6 sampled
Checks reached and addressable on the base kit, 0 blocked, 1 OFF_LEVEL.
Exit placement and exit approach measured separately. A diagnostic
launcher that pins default scale and a named save slot. Targets mounted
on real walls and shot from the walking lane. Stations open a travel
panel instead of teleporting. Key pickups say what they opened, once.
An activity says whether it was the one that brought its station
online.

**Blocked, with numbers.** Retiring `timed_run` and `pressure_routing`
removes 161 activities and returns 176 more of the two that stay
(`python -m tools.family_retirement`). The composer cycles a fixed
family list, so a shorter list is the same content made of two
families. It needs a policy choice about what fills the budget and the
composer is the bridge lane's file; the only edit made there is a pure
hoist to `fallback.ACTIVITY_KINDS`. The compatibility conditions are
fixed in place first.

**Prototype, review only.** `NavSchematic` on F5: rooms walked this
session, the Zone's own declared edges between two of them, locks,
stations, you-are-here. No stored topology, no persistence, no bearing
arrow.

**Waiting on the owner.** ~~A private copy of `.diagnostic-582e954`'s
slot JSON~~ — ARRIVED 2026-09-14, see the top entry — the original exit
seam stays
unresolved without it, and the original is not to be touched. Plus
comfort of the stairs, whether a Check 2.6 m below its walkway is a
bug, the `c001/side_left` leak candidate, and which budget shape the
retirement takes.

**The heartbeat is PAUSED.** The authorised list is done or blocked on
the owner. Turn it back on when there is a task.


## ENGINE LANE — the combined checkpoint, and the pad is out of the way — 2026-09-13

**`claude/archipepsi-echoes-continuation-b1adno`**, bridge lane merged at
`089dc64`, art lane at `1a9f1c9`. Read this first.

Both lanes had built truthful capacity and the attempt discriminator
against an earlier checkpoint of the other, so neither branch's report
described the combined tree. This is that tree, reconciled and re-run.

### One capacity authority, one attempt guard

`C.PROCEDURAL_SOCKET_CAPACITY` is the single declaration and keeps the
MEASURED table — **`platform_path` AND `tower`**, the two producers that
climb, each measured solid at the site with one control per chamber
type. `SIDELESS_PROCEDURAL_TYPES` is gone. `procedural_sockets_for`
projects the one map into four readers: the composer
(`topology._sockets_for`), the load-time invariant, Dess's
acceptance-time refusal in `validate_zone` — which now covers the tower
too — and the ENGINE through `constants.gd`. Dess's branch-reserve
replacement in `_branch_routes` and its regression tests are kept.

The attempt discriminator is one field and one guard: bound by
`MAX_LAYOUT_REFUSALS` where `layout_refusals` saturates, refusing a
mismatch in **either** direction. The client still takes the ordinal and
the digest from ONE read of the snapshot at build start, which is the
path `main.gd::_to_zone` actually walks.

**Across all 26 committed fixtures: 770 joined doors, 0 beyond
capacity.** Returns hold at 8 in all five controls; the sample is
160 → 159 (one Zone's `c019` stopped being a dead end, so it needs no
return), dead ends 141 → 141, no Zone reduced to a bare chain.

### The return pad no longer stands in front of the content

**The finding, measured on the merged tree before any repair:**

| Zone | pad off the arrival→content line | reached the content |
|---|---|---|
| `zone_01` `c018` | 7.67 m | yes |
| `zone_02` `c011` | **0.41 m** | NO — "took the return home by wandering onto it" |
| `zone_03` `c011` | **0.15 m** | NO |

Every journey that failed to reach its room's content had the device
within a body's width of the straight line to it; the one that succeeded
had it seven metres clear. `clear_of_arrival` had always kept the pad off
the spot a body appears on and said nothing about the metres between
that spot and the reward.

`RoomAudit.clear_of_content_path` is that rule, with the same margin as
the arrival — trigger plus a capsule — applied to the current anchor and
to every candidate.

**What counts as "the content" is the room's own warp station,
`st:<room id>`, read out of the build's station list.** Not the
producer's nominal `reward_position`: measured across all five generated
fixtures, the interactable the player's own probe actually stops at is
6 to 10 m from that nominal spot (`zone_02` `c011`:
`(15.2, 36.5, 131.45)` against `(8.8, 36.5, 134.97)`), so guarding the
nominal line guards a line nobody walks. And not "the first node with
`interact()` in the room", which is what it asked first: that is tree
order over a subtree whose membership is not the same on a replay,
because a key the player already carries is not rebuilt — and a return
anchor is committed geometry, so the point it is settled against has to
be a function of the committed layout alone. Every room measured gave
its own station under either rule, so asking for it by id changed no
measurement and removed the hazard.

**Result: 0.41 m → 2.50 m, 0.15 m → 2.57 m, and `zone_02` went from
"could NOT reach anything it holds" to "reached what it holds, and took
the return device home deliberately."** Journey `content` 2 → 3, stable
over four runs; `JOURNEY_FLOOR` raised.

### The settle has to survive a cold restart, and now it is proved to

A pad that moves is only a repair if the move is reproducible. The
return journey's replay control read the replayed device the instant
`setup()` returned and compared it against a SETTLED anchor — and
`_publish_layout` settles two physics frames later and is awaited by
nothing. While the settle moved nothing this went unnoticed; the moment
it started moving pads off the content line, the control reported a
4.1 m difference that was entirely its own timing.

It now waits on `ZoneController.measured_placement` — the controller's
own statement that it has measured — before reading. Settled against
settled, a fresh controller replaying the committed manifest puts the
device at `(-112.84, 31.57, -76.00)`, which is where the accepted build
stood it, to within the control's 0.01 m. The control says the stronger
thing now: not that the RESERVATION replays, but that the SETTLE does.

### What the remaining journey failures actually are

Diagnosed per route on the merged tree, bounded, no navigation bot:

| journey | class | evidence |
|---|---|---|
| `zone_04` `c009` → `c010` | **valid route, steering cannot follow** | the branch door `c009/side_left` measures OPEN; the body leaves the junction arrival and stops ~9 m in. The corridor carries `moving_platform` and `powered_door` — traversal the harness neither rides nor solves. |
| `zone_03` `c009` → `c011` | **valid route, steering cannot follow** | pad now 2.57 m clear; the room is an ordinary arena; the straight line from arrival to content has no standing room at t ≥ 0.6, i.e. furniture. Reachable around it, not through it. |
| re-entry, 3 deliberate returns | **steering** | a full cross-Zone walk BACK; floored at 0 and unchanged. |

**No remaining failure is an invalid or unreachable route, and none is
pad interference.** Every non-SEALED door on both routes measures as a
hole; every SEALED one measures solid. The one closed slab found is a
`PoweredDoorChain` on `c009/side_right` — a powered door before its
puzzle is solved, which is the door working.

### Suites on the combined commit

**Python** — `make test`: **1526 passed, 627 subtests passed**, 0
failed. `make test-schemas`: 131 passed. The v0.8 packet check: prose
matches the models across 11 documents. Every run below was serialised —
nothing else was touching the tree while it ran, which matters here
because `make godot-zone-audit` rewrites the capture fixtures the
placement contract reads.

**Godot, offline** — `godot-zone-audit`, `-test`, `-room`,
`-room-contract`, `-content`, `-activity`, `-graphs`, `-physics`,
`-movement`, `-boot`, `-hud`, `-rules`, `-lab`, `-legible`, `-stats`,
`-verbs`, `-affordance`, `-blink`, `-playtest3a`.

**Godot, live bridge** — all three, and they are three different things:

| target | what it is |
|---|---|
| `godot-integration` | a whole campaign to `ALL_CHECKS_CLEARED` at prototype scale |
| `godot-return-journey` | one Zone at DEFAULT scale: candidate layout → bridge acceptance → player traversal and deliberate return → **scene reconstruction** (a fresh `ZoneController` replaying the committed manifest inside one running process) |
| `godot-reload` | **both processes restart** — the Godot client exits, the bridge is killed and restarted from its own save file, and a fresh client resumes. PHASE 1 (2 checks) + PHASE 2 (18 checks) |

All three exited 0 on the tree below.

**The recovery that actually ran** in the return journey was
*re-selection stood down; the Zone was refused and composed again* — the
other designed recovery, not host re-selection. Host re-selection has
its own bridge controls in `test_amalgam_end_to_end.py`, where the host
is chosen for the property under test.

### NOT closed, and still on the backlog

1. **Overlap reconciliation** — the join/collar distinction, the separate
   "router found a candidate" vs "bridge accepted it" publication, and
   the bounds diagnosis for the four large-shell failures. The four
   reverted attempts are recorded in `zone_builder.gd`.
2. **The ordinary journey's steering** — the three failures above. They
   need a route-following harness or hand-verification, not a general
   navigation bot, and none of them is a defect in the game.
3. **The pending authored-room proof** — registry seam, one-neighbour
   Terminus, onward branch with its real departure, rotated placement.
   No asset is promoted for it.
4. **Re-selection is tight**: 1 of 8 hosts on a default-scale Zone can be
   barred with the arrangement preserved, where the flat four-door table
   claimed 8 of 8 through doors that did not exist. Branch preservation
   is untouched; the stand-down is the approved outcome and has its own
   control. Whether the composer should find more room is topology
   tuning and is the bridge lane's.

### 0.3 FOLLOW-THROUGH — see `docs/BATCH_0_3_FOLLOWTHROUGH_HANDOFF.md`

**Demonstrated.** The exit is now handled by the consumer that actually
handles it: `boot_driver` boots Main for real, wires a ZoneController the
way `main.gd` does, fires the signal the way the portal does, and asserts
the HUB view, a live Hub, the HUD on, the Zone gone, and that the Hub can
still start another Zone. Breaking `_to_hub()` fails four of five.

**Closed.** The Dictionary cast, and a wrong attribution with it: it was
recorded as `active_zone().is_empty()` on the refusal path, but
`active_zone()` cannot throw — it returns `{}` for a non-Dictionary by
construction. The real cast was in the TEST harness,
`.get("zone", {}) as Dictionary`, where a PENDING_GENERATION record
carries a null. **The Makefile exemption is deleted, not scoped**, the
run log has zero script errors, and the crash control still exits 2.

**Open, and not generalised.** Ascent success is NOT stair comfort:
descending a 0.4 m tread is still a free-fall and the control reports the
airborne count rather than asserting one. And the exact traversal case is
NOT recovered — the owner's `.diagnostic-582e954` is on their Windows
machine, not in this container; a copy is requested, the original
untouched. Until then the reproduction is APPROXIMATE (matching room ids
and shells does not establish identical placement), the required crossing
is untested with either kit, and the exit approach/seam is untested and
kept separate from the transition. The discarded lattice establishes a
failed instrument only — not a safe Zone, and not a verdict against
geometric searches.

### BOUNDED 0.3 REPAIR BATCH — see `docs/BATCH_0_3_REPAIR_HANDOFF.md`

Required traversal and activity feedback, from the first human playtest.
No bridge contract moved; `MAX_VERTICAL_STEP` is unchanged and has no
Python readers.

**Repaired.** The body now implements the step-up its own movement law
had only ever asserted, so a pedestal is walked rather than jumped —
the treatment the generator already builds towers around, with cover
(1.4 m), barrels (1.1 m) and anything the player is meant to SHOVE
refused. The activity completion chime asked the tone bank for
`secret_found` against a bank keyed `secret` and was therefore silent
since it was written; failure had no listener at all; a counted hit made
no sound; and the countdown that already existed sat on a label across
the room. All four now reach the player, and a Python check refuses the
next unresolvable tone name.

**Covered.** The real exit portal is now taken rather than simulated —
`integration_driver` admitted in a comment that it "never takes the real
exit path", which is why the crash reached a green suite. And
`godot-integration` now fails on a SCRIPT ERROR, which it never did:
verified clean-0 / crash-2.

**Open, and named rather than implied.** Descending a tread is still a
fall — `floor_snap_length` is set and Godot drops the body anyway.
Required-target reachability is UNMEASURED: the lattice flood-fill built
for it called 12 of 15 Checks unreachable in a layout the owner cleared,
so it was removed rather than tuned toward the known answer. That is
direct evidence on the review's open question — a geometric flood-fill
is not the cheaper decisive test.

### START HERE AFTER THE PLAYTEST

**The record was corrected on 2026-09-13 after an independent review.**
Five claims were wrong and are fixed in place, with the superseded text
preserved and labelled at the end of
`docs/PLAYTEST_DIAGNOSTIC_RESULT.md`: the timed-activity **countdown
already exists** (presentation failed, not existence); activity
completion **requests a tone name the bank does not define**
(`secret_found` against `secret`); **keys immediately try to open
matching locks** (`_open_what_the_keys_allow()`), so a door may change
before the player returns to see it; the **content score rewards stated
ingredients rather than their arrangement or consequence**; and
**several activities can share one station repair, which happens once**.

The synthesis's closing claim that "what is missing is not features but
proof" is withdrawn. Correctness and enjoyment are separate obligations:
a room can be provably completable and still be dull, and no validator
supplies the missing design.

`docs/PLAYTEST_SESSION_SYNTHESIS.md` — what happened, what it taught us,
every problem in severity order, and five proposed solutions.
`docs/PLAYTEST_DIAGNOSTIC_RESULT.md` is the raw log behind it, including
two retractions. `docs/CODEX_REVIEW_BRIEF.md` briefs an independent
reviewer.

**Fixed already: taking the exit portal crashed the game.** `camera_ray`
read `.direct_space_state` off a null `get_world_3d()` on the first
frame after the portal removed the player from the tree, and
`_physics_process` called `move_and_slide` on a freed space. The most
important transition in the game ended the process instead. No suite
caught it because none has ever taken the portal — the integration run
reaches `ALL_CHECKS_CLEARED` through intents. Fixed and controlled at
`cd620f0`, verified by removing the fix and watching the suite exit 2.

**The finding that organises the rest: the suite proves the pieces and
never the assembly.** A Check behind a jump gap passed "the room is
reachable". Stairs that must be jumped passed "the step is under 1.0 m".
Holes at a doorway passed "each chamber is sealed". The portal crash
passed "the campaign reaches ALL_CHECKS_CLEARED". All four were green on
the commit that contained them.

### THE DIAGNOSTIC PLAYTEST FOUND AN UNDECLARED CAPABILITY GATE

**Read `docs/PLAYTEST_DIAGNOSTIC_RESULT.md` before planning any batch.**
The owner reached an AP Check on a ledge that is, after trying,
unreachable without a teleport Echo. That is the one thing this
project's rules say may never happen: a physical gate the matching AP
location logic does not declare. Archipelago's item pool is Signal Key,
two fillers and Victory — **Echoes are not AP items**, so AP has no
vocabulary for the gate and believes the Check reachable.

`graph.Edge.capability` is the guard built for exactly this, and it
watches EDGES. This gate is INSIDE a room, where nothing measures
traversal at all: `reachability` proves "every Check in a reachable
ROOM" and `RoomAudit` proves the spot has floor and headroom, and a
pedestal across an uncrossable gap passes both.

The fix keeps what the owner liked, because AP's claim covers Checks and
not local rewards: a capability gate in front of a LOCAL REWARD is safe,
in front of an AP CHECK it is a deadlock — for the other player whose
progression item lands there. The composer cannot tell the difference
today. **Within-room reachability is the missing measurement, and it is
this lane's.**

### Two more from the same session, both load-bearing

**`MAX_VERTICAL_STEP` is a fiction.** `chamber_builders.gd` records it
already: "there is no step-up anywhere in `player.gd`;
`MAX_VERTICAL_STEP` is a constant validation reasons with, not one the
body implements." Validation blesses geometry as walkable at up to 1.0 m
while the player's real step-up is ZERO and a 0.35 m kerb stops them. The
same disease as the capability gate — a layer deciding reachability from
a number the physics does not honour. Either the body implements step-up
or validation stops claiming it.

**Do not fix the density findings by scaling the constants.** Owner: "big
rooms are not fun on their own, they give really really good
opportunities for fun. that distinction matters." Activities, lights and
Checks are all capped by flat count against variable room dimensions, and
the naive repair — make each a function of area — treats size AS content
and produces a better-lit room with nothing to do in it. Size buys KINDS
of content a small room cannot hold. `topology.SPINE_SHARE` already
records the unresolved half of this ("rooms behaved like enlarged
corridors"); the principle is the other half.

**The game is a Metroidvania with no map, and an unsolvable puzzle
strands the player against a promise.** No minimap, no compass, nothing
in `hud.gd` but one CHECK tracker — against local keys, colour-coded
locks, branches off a spine, warp stations to backtrack between and dead
ends that send you home. The owner got lost holding three unused keys.
Worse, the two findings below compound: a room with ANY activity gets a
station created BROKEN, that station repairs only when the room's
activity is solved, and `pressure_routing` has no solution — so such a
station can NEVER come online and the warp network is permanently
incomplete. A broken station is a promise; an unsolvable puzzle makes it
one the game can never keep.

**Nothing checks that a `pressure_routing` route exists.** An earlier
revision of this section called the family "unsolvable by construction";
that was WRONG and is retracted. Plates linger —
`PLATE_HOLD_SECONDS = 4.0`, so at `WALK_SPEED = 7.0` the puzzle carries a
28 m travel budget and is exactly the routing puzzle its name says.
The real defect is narrower: whether a route fits inside that budget
depends on the layout the composer happened to produce, and nothing
checks it. Five pads at 7 m apart is fair; five scattered across a large
arena cannot be done. Still the same family as the capability gate —
**content validated as PLACED and never as COMPLETABLE** — and a room
whose activity cannot be completed also holds a warp station that can
never be repaired, because a station in a room with activities starts
BROKEN and repairs only on that activity's completion.

The owner's two-pad room, reported impossible, was more likely
legibility: the only signal a plate is still holding is a glow energy
change (3.2 against 0.9), with no sound. (The countdown exists and is
sent to the label — see the corrected finding 3; it did not reach the
player.) The silent
activity finding is not a polish item — **a room was solvable and the
game hid it.**

**Nothing tests the seam where a connector meets a room.** The seal
probe `_test_no_chamber_leaks_off_its_centre_line` builds each chamber
ALONE — no neighbours, no connectors — so it proves a room is sealed by
itself and never that it is sealed where something joins it. Every room
reaches every other room through a join; the suite tests the pieces and
never the assembly. The zone audit already builds whole assembled Zones
from the five fixtures, so pointing the existing probe at those covers
every join in the game. Likely the visible end of the recorded overlap
item: `zone_builder` notes that "corridor adjacency keeps a tolerance,
rooms do not", and a tolerance at the join is how a crack appears around
a connector mouth.

### The rest of the diagnostic playtest — same document

**The return pad repair is confirmed by a human.** The owner found a
branch destination, read the `RETURN` sign before reaching it, crossed
the room to its content and its station, and took the device home
deliberately. It never fired by accident. The measurement said
0.41 m -> 2.50 m of clearance; the walk says that clearance is enough.

**The finding that reframes the rest: nothing in a Zone casts a
shadow.** Every room light is an `OmniLight3D` with
`shadow_enabled = false` and no comment saying why; the flashlight too.
With flat prop materials and no contact shadow, a grounded object and a
floating one are pixel-identical — which is why the owner reported the
hazard drums as floating and then retracted it on a closer look. The
generalisation this lane built on that report was retracted with it: the
ground socket's constant `0.0` foot is a real, unprobed assumption, not
a demonstrated defect.

The consequence is a constraint on this lane's own method: **placement
defects of this class are undetectable by eye in this build**, so
shadowing is a diagnostic prerequisite rather than polish. What still
stands unaided is the activity element — honestly grounded by
`activities.gd`'s surface search, carrying a stalk built to enter a wall
that placement never requires, and catchable only because the stalk
gives it away.

Branch depth went to the bridge lane: `MAX_SIDE_DEPTH = 2` is at its cap
and its own note asks to be settled on play evidence, but the owner's
ask is a distribution, not a larger number.

The cheapest and largest-felt item is **defect 2**, activity feedback
that does not reach the player — narrowed by the independent review and
verified: the completion path DOES call `tones.play("secret_found")`,
and the bank defines `"secret"`, so `Tones.play` finds no player and
returns silently. Set, hit and failed have no call at all. So the
completion cue is one wrong string and the rest is missing wiring.

### For the next owner playtest

Ready for a **diagnostic** playtest, not a verdict on the backlog.

Run `./start-archipepsi.sh` (or `Start Archipepsi (Windows).bat`), leave
that window open, launch Godot and press **MOCK CAMPAIGN**. No
Archipelago server and no seed are needed.

**Existing saves are untouched.** A normal run writes to `bridge/saves/`;
every test target in this batch used `ARCHIPEPSI_SAVE_DIR` pointed at its
own throwaway directory (`.integration-saves/`, `.journey-saves/`,
`.reload-saves/`), all gitignored, and none of them reads or writes
`bridge/saves/`.

What to expect, and what is known: Zones build, are accepted, and
reconstruct across a full two-process restart. Branch destinations are
reachable and their returns work. The three steering failures above are
harness limitations, so a human walking those routes is exactly the
evidence this lane does not have.

## ENGINE LANE — the advertised capacity is the built capacity, and the whole journey runs — 2026-09-13

**`claude/archipepsi-echoes-continuation-b1adno`**, bridge lane merged at
`2330017`, art lane at `1a9f1c9`. Read this first.

### A room is offered only the doorways its producer builds

`PROCEDURAL_SOCKETS` named four openings for every procedural room, so
`compose_with_branch` hung a branch off a `platform_path`'s `side_left`
exactly as it would off an arena's — and that producer raises a solid
wall there, over its kill pit and below its walkway. A declared `USED`
door the engine measures as solid refuses the WHOLE layout, which is why
a default-scale Zone could not be accepted at all.

**Measured, one control per chamber type**, each a real two-room Zone
with all four sockets assigned, asking three things of every side the
producer agrees to name: is the aperture a hole, is there floor a metre
inside it, and does the room name it at all. *An open aperture with
nothing under it is not a door.*

| producer | side doorways | note |
|---|---|---|
| `corridor` | hole + floor | cuts them since last batch |
| `arena` | hole + floor | keeps its crates out of them |
| `treasure_room` | hole + floor | |
| **`platform_path`** | **solid, no floor** | the middle of its side wall is over its pit |
| **`tower`** | **solid** | the other producer that climbs |

`C.PROCEDURAL_SOCKET_CAPACITY` is that measurement — **one declaration,
three consumers**, because fixing the planner alone is the
two-vocabulary defect this project keeps finding: the composer
(`topology._sockets_for`), the schema (`Zone`'s socket invariant) and
the engine (`ChamberBuilders.procedural_sockets`, via `constants.gd`).
`topology.apply` raises loudly if a product ever assigns beyond capacity
again, and an authored shell answers from its own catalogue entry
throughout. **It is a statement about today's producers**: a side-landing
variant simply comes out of the map.

**Old saves still load.** The NAME vocabulary stays four, because a
campaign composed before this was measured holds `platform_path` rooms
with side doors and `ZoneRecord.zone` is a typed `Zone`. What a room must
MENTION is what it carries. Such a Zone loads, is refused on the aperture
the engine no longer cuts, and is recomposed.

### Branching is preserved, and the journeys roughly doubled

| | before | after |
|---|---|---|
| sample returns (20 Zones) | 160 | 159 |
| sample dead ends | 141 | 141 |
| Zones left as a bare chain | — | none |
| journey `entered` / 5 | 2 | **4** |
| journey `stayed` | 2 | **4** |
| journey `content` | 0 | **2** |
| journey `returned` | 1 | **3** |

The one lost return is `zone_13`'s `c019`, which stopped being a dead end
(7 → 6) and therefore needs none. Every junction role lost was a
`platform_path`; every one gained was an arena. The journey legs are the
same five inputs, the same command, three consecutive runs agreeing —
the destinations used to be rooms that advertised a door and raised a
wall. `JOURNEY_FLOOR` is raised to that.

**The five and the sample are retained.**
`godot/tests/fixtures/generated-before-capacity/`,
`sample-before-capacity/` and `played_zone-before-capacity.json` keep
what they were; the live fixtures are regenerated from the same source
inputs with the same commands. Nothing was swapped for a luckier seed.

### Two tries at identical content are two attempts

`layout.proposal_digest` is CONTENT identity and stays that: identical
bytes hash identically, which is correct and is exactly why it cannot
separate two tries at the same content. Measured live — the
deterministic provider recomposes the same Zone after a refusal, the
digest matched on both sides, and the replaced build's late result spent
the replacement's budget.

So the discriminator is at the lifecycle boundary and is a quantity the
record already keeps and already sends: `LayoutResult.attempt` is
`ZoneRecord.layout_refusals` as it stood when the build started. A
refusal is what ends one attempt and begins the next. **The two cover
different cases and neither replaces the other** — re-selection changes
the graph without spending a refusal, so the digest catches it; a
recompose keeps the content and spends one, so the ordinal catches that.

**Permitted reuse, stated:** a result from the CURRENT attempt is current
however many times it arrives. A client resending after a dropped
connection is the same evidence, not a second charge. Only a result from
an attempt the Zone has moved past is discarded.

### The whole journey, driven — `make godot-return-journey`

| stage | result |
|---|---|
| candidate layout | the engine measures `NO_CANDIDATE`, 80 candidates searched |
| bridge acceptance | recovery taken and named; content kept; returns 8 → 8; attempt 0 → 1 |
| the replaced build reports late | no budget, no state, no commit, no bar, no graph change, no attempt, **no verdict** |
| the replacement | accepted, manifest committed |
| player traversal | arrival does not fire the device; the pad raises exactly one traversal for `p:c011:start` |
| deliberate return | the production consumer puts the body at the Zone start, **0.0 m** |
| cold reconstruction | the manifest replays; the device is back in `c011` at `(-114.137787, 31.570000, -72.089989)`, the same place to six decimals |

**Both recoveries are designed and the control names which ran.**
`_reselect_hosts` moves the branch when the arrangement can be rebuilt
without the barred room and stands down when it cannot; the ordinary
bounded refusal then takes the Zone back to Epsilon. Re-selection's own
properties are bridge controls in `test_amalgam_end_to_end.py`, where the
host can be chosen for the property under test.

### Suites, at this commit

`godot-zone-audit`, `-test`, `-room`, `-room-contract`, `-content`,
`-activity`, `-graphs`, `-physics`, `-movement`, `-boot`,
`godot-integration`, `godot-return-journey` — **OK**.

**`godot-reload` is GREEN for the first time**, both phases: PHASE 1
(2 checks) builds and accepts a fresh default-scale proposal, and PHASE 2
(18 checks) — manifest reconstruction, never reached before — passes.
Getting there took three harness corrections in its walker, each
measured: it walked a straight line between two rooms joined by a door
(11.6 m short, against the wall), it steered AT the opening rather than
through it (3.8 m, wedged 0.75 m from the near wall), and it never
climbed what it was pressed against.

### NOT closed by this batch, and still on the backlog

1. **Overlap reconciliation.** The join/collar distinction, the separate
   "router found a candidate" vs "bridge accepted it" publication, and
   the bounds diagnosis for the four large-shell failures. The four
   reverted attempts are recorded in `zone_builder.gd`.
2. **The ordinary journey.** `re_entered` reached 1 of 3 and is floored
   at 0 deliberately: it is a full cross-Zone walk BACK and is not yet
   reliable. The fall at waypoint 0 and the stop-shorts are unchanged.
3. **The pending-room integration proof.** Registry seam, one-neighbour
   Terminus with unused openings closed, onward branch with its real
   departure, rotated placement.
4. **Re-selection got tighter, and it is reported rather than hidden.**
   On a default-scale Zone, 8 of 8 hosts could be barred and re-selected
   with the branch count preserved under the flat table; **1 of 8** can
   under the measured capacity. The old number was not robustness — it
   was re-selection planning routes through walls the engine then
   measured as solid. Branch preservation is untouched and
   `_reselect_hosts` stands down as designed. Whether the composer
   should find more room to manoeuvre is topology tuning and is the
   bridge lane's.

**0.3 is not complete.** This batch closes the acceptance and
reconstruction blockers and the identity questions; it does not close
the backlog above, and none of it is the human playtest acceptance 0.3
still owes.

## BRIDGE LANE — a room offers the doors it can hold — 2026-09-13

**Merged with the engine lane at `74f6878`.** Read this first on a
wake-up.

**THE FOUR-DOOR ADVERTISEMENT WAS NOT TRUE, AND THREE PATHS BELIEVED
IT.** `PROCEDURAL_SOCKETS` named four joining sockets for every
procedural room whatever its type, so a `platform_path` offered
`side_left`/`side_right` — sockets `chamber_builders.procedural_sockets`
places at the middle of the side wall, which on a platform course is
over the kill pit and below the walkway. The engine says so at the site
and measured that relocating them does not help. Measured here before
repair: **28 chambers across 22 committed fixtures carried a used side
door on a platform course**, `c008` of the played Zone among them —
the room `zone_01` refuses its layout for.

`schemas/zone.procedural_sockets_for` is now the ONE declaration.
`topology._sockets_for` offers from it and `validate_zone` refuses a
proposal that went around it, so the planner and the validator cannot
drift into declaring different numbers of doors. An AUTHORED shell is
never asked: it declares its own openings and sharing a chamber type
with a procedural room says nothing about what an artist cut.

**The refusal is at ACCEPTANCE, not on load.** Every Zone composed
before this carries these doors; refusing them in the Zone's own
Invariant 8 would make a save holding one unreadable instead of
repairable. Invariant 8 audits what the type CAN hold and tolerates a
mention of what it cannot; `validate_zone` — the function whose whole
job is errors for a repair request — is where a new proposal is turned
back.

**BRANCHING IS PRESERVED BY MOVING JUNCTIONS, NOT BY DROPPING THEM.**
The junction search already walked back through candidates; the
DESTINATION did not. The budget picked which rooms were worth going to
without consulting which rooms could hold a doorway, so a destination
whose every predecessor was full simply fell back onto the spine.
`_branch_routes` now keeps a reserve and replaces a failed destination
rather than spending a branch on nothing. Regenerating the played Zone:
**same 23 rooms, same types, same 30 edges, same 8 plugs** — the two
branches that hung off `c008` moved to `c002` and `c005`.

**WHAT GOT HARDER, REPORTED RATHER THAN HIDDEN.** With honest capacity,
re-selection after an unhostable host is rarer: of the played Zone's
eight plug rooms, **one** can move its branch while preserving the
arrangement; the other seven stand down to the ordinary bounded layout
refusal. That is the approved outcome — branch removal to make a device
requirement go away is not — but it means the regraph recovery fires far
less often than it did against the advertisement. Tuning was NOT lowered
to hide it: `SPINE_SHARE` and `MAX_SIDE_DEPTH` are untouched.

**TWO ATTEMPTS AT IDENTICAL CONTENT ARE NOW TELLABLE APART.**
`proposal_digest` stays content identity and identical content still
hashes identically — correct, and exactly why it cannot discriminate
attempts. After a refusal the campaign asks the provider again and a
deterministic one returns the same Zone, so the previous attempt's
result matched the current proposal. Measured: **one real refusal became
two**, and three duplicate deliveries would exhaust a Zone that never
failed three times. `ZoneReady.attempt` / `LayoutResult.attempt` carry
the ordinal, read from `layout_refusals` at offer time so there is no
second counter and nothing is folded into the digest. Absent behaves as
today. A real second failure is still charged — sabotage-proven in both
directions.

**What this batch does NOT close.** The engine legs — the four player
crossings, `godot-return-journey`, `godot-zone-audit` — need a Godot
binary and none is present in this container; they are the engine lane's
and are NOT claimed here. The captured placement payloads are interface
evidence and are labelled as such in `test_placement_contract.py`: they
prove the wire shape and the recovery each outcome reaches, never that a
Zone's physical layout is acceptable or that a player crossed it.


## ENGINE LANE — one placement contract, one proposal identity, and the door that blocks acceptance — 2026-09-12

**`claude/archipepsi-echoes-continuation-b1adno`**, bridge lane merged at
`1297bb8`, art lane at `1a9f1c9`. Read this first.

### The placement seam is ONE contract, checked on real bytes

`RoomAudit` speaks `AMALGAM_BRIDGE.md` §5.9: **`PLACED` / `NO_EVIDENCE` /
`NO_CANDIDATE`, keyed by the plug's `edge_id`**, with `repaired` and
`how` beside `searched` and `probed`. `MEASURED` and `REPAIRED` collapse
into `PLACED` — the device is placed either way. An engine that measured
nothing now **says `NO_EVIDENCE`** instead of falling silent: silence
means "this payload predates the field", and a current client must not
describe itself that way.

`make godot-zone-audit` writes four payloads through the real serializer
and commits them with `captures.json` — the exact Zone proposal, the
outcome each demonstrates, the controller digest, the source commit, and
the one command that remakes them:

| capture | outcome | from |
|---|---|---|
| `supported` | `PLACED` | a `platform_path` whose reserved spot already holds |
| `repaired` | `PLACED`, `repaired: true` | an arena with its anchor moved into the arrival's clearance |
| `no_evidence` | `NO_EVIDENCE` | the same arena with its arrival unpublished |
| `exhausted` | `NO_CANDIDATE` | the pit room with its stands removed and its envelope lifted 60 m |

`bridge/tests/test_placement_contract.py` runs the **real validator** over
exactly those bytes — no key or outcome rewritten — and follows
`unhostable_rooms` into `compose_with_branch(barred=...)`. The decoder's
own shape rules are the bridge lane's and are not duplicated.

### The lattice had no centre line, and every corridor paid for it

`RETURN_OFFSETS` promises "a narrow room is served by its long axis". It
was not: the inner loop offered `dx = 0` and the outer loop never offered
`dz = 0`, so every candidate sat ≥ 2.5 m off the arrival **on both
axes** — and `grow(-0.6)` takes a 4 m-wide corridor to 2.8. Measured
before the fix: a corridor 8 × 4, a vault and a shaft each reported
`NO_CANDIDATE` **having run zero physics queries**. The one outcome that
bars a host, for three ordinary rooms with metres of clear floor.

Both axes carry zero now. `searched` (candidates enumerated) and
`probed` (positions put to the world) are separate, because one number
could not tell a finished search from an absent one — `searched: 80,
probed: 0` is a real answer; `searched: 0` was the bug.

**Consequence worth stating: no room the composer may propose fails
placement any more.** Every arena from `PROCEDURAL_ARENA_MIN_SPAN` (10 m)
up places; `platform_path` places on its declared ledges; the cliff is at
6 m square. The one schema-legal shape that genuinely cannot host a
return is a minimum corridor, 6 × 4, and corridors are not made into
branch destinations. `c012` is closed.

### The proposal identity reaches the build — by the carrier the build reads

`ZoneReady.proposal_id` exists, and **`zone_ready` does not reach a
build**: `main.gd::_to_zone` builds from
`BridgeClient.active_zone()["zone"]`, and `zone_ready_received` has no
connections anywhere in the client. Traced rather than assumed:

| path | offer before the build? |
|---|---|
| fresh entry | yes, at generation |
| re-selection | yes, `_reselect_hosts` re-offers |
| re-entry to a COMMITTED Zone | yes, the replay carries it |
| **cold restart into a Zone generated but never committed** | **no** |

So the **carrier adjustment**: `CampaignSnapshot.active_proposal_id`,
derived on every send from the record beside it, stored nowhere. Not two
copies of a fact — both it and `zone_ready.proposal_id` are
`layout.proposal_digest` of the same Zone, so they cannot disagree. This
is the same argument `test_physics_carrier.py` makes for `progress`.
**Dess: this is the one bridge-side line of mine in your lane.**

`ZoneController.setup` captures it where the build STARTS and
`send_layout_result` echoes what was captured, never what is current. An
omission is not silent: a controller that binds nothing while the bridge
holds that Zone says so.

### The re-selection journey — `make godot-return-journey`

One control, the same integration driver, a live bridge at
`--mock-scale=default` (prototype Zones are three rooms and carry no
branch — measured: four consecutive Zones with no plug at all). The
branch host is built at 5.5 m square in this client only; after the
lattice repair no room the composer may propose fails, so the recovery
path can no longer be reached by asking for Zones until one breaks.

**Bridge controls — all green:**

* the engine measures the shrunk host and reports `NO_CANDIDATE`;
* the bridge bars **exactly** `c011`, re-selects, and the branch moves to
  `c009` with the branch count preserved (8 → 8);
* the replacement is a different proposal while reusing **all 23 room
  names** — a digest over the graph alone would not have moved;
* A, still holding the old identity, reports late: **no refusal budget
  spent, no state changed, nothing committed, nothing further barred, the
  graph untouched**;
* the replacement binds its own identity.

**Blocked at acceptance**, and by something older — below.

### THE BLOCKER: a declared door the builder does not cut

`PROCEDURAL_SOCKETS` is four for every procedural room, so
`compose_with_branch` hangs branches off `side_left` / `side_right` as
readily as off `entry` / `exit` — and the bridge refuses the **whole
layout** when a door declared `USED`/`LOCKED` measures solid. That is
`godot-reload`'s PHASE 1 refusal, and it is what stops a default-scale
Zone being accepted at all. Diagnosed on `zone_01`, three parts:

| producer | what it did | now |
|---|---|---|
| `corridor` | raised two solid slabs and declared a doorway in each | **cuts them** |
| `arena` | cut them, then stood a perimeter crate 0.45 m inside | **`_greeble_room` keeps clear**, as it always has for the exit lane |
| `platform_path` | raises two solid slabs and **cannot honestly cut them** | **open** |

**Narrowed, measured, after the two fixes.** `godot-reload` PHASE 1 used
to be refused for `c008/side_left`, `c008/side_right` **and**
`c011/side_right`; it is now refused for the two `c008` doors alone, and
the re-selection journey's replacement for `c008` and `c012` alone —
every one of them a `platform_path`. One producer stands between this
project and an accepted default-scale Zone.

A `platform_path`'s declared side position is the middle of its side
wall: over the kill pit, below the walkway. Measured alternative —
moving the socket onto the start ledge cuts honestly and then `zone_01`
does not lay out at all ("branch room 'c014' off 'c008' could not be
placed clear of the 29 room(s) already standing"), because the branch
mouth moves to the room's entry end. **The remaining answers are
compositional** — the composer stops offering a climbing room's sides as
junctions, or the room grows a landing — and neither is a wall this
builder can cut. Waived by room type and **counted** in
`godot-zone-audit`, so a change either way goes red.

### Suites, at this commit

`godot-zone-audit`, `godot-test`, `godot-room`, `godot-room-contract`,
`godot-content`, `godot-activity`, `godot-graphs`, `godot-physics`,
`godot-movement`, `godot-integration` — **OK**. 1314 passed in
`bridge/tests`; schemas and the v0.8 packet check clean.

`godot-reload` — **RED**, PHASE 1, and now for the `platform_path` side
door and nothing else. `godot-return-journey` — **RED at its last three
legs**, same cause, everything before them green.

### NOT DONE, and not started

1. **The `platform_path` side door**, above. One decision, then
   `godot-reload` goes green and the journey's last three legs
   (acceptance, the walk onto the return, the restart replay) run
   without further work — the control is written and waiting behind it.
2. **Overlap reconciliation.** The join/collar distinction, the separate
   "router found a candidate" vs "bridge accepted it" publication, and
   the bounds diagnosis for the four large-shell failures. The four
   reverted attempts are recorded in `zone_builder.gd`.
3. **The pending-room integration proof.** Registry seam, one-neighbour
   Terminus with unused openings closed, onward branch with its real
   departure, rotated placement. Asset at
   `assets/models/batch044/shells/shell_bay_terminus.glb`.
4. **The three journey gaps** — the fall at waypoint 0, the two
   stop-shorts, and the device standing between the arrival and the
   content.

### For the other lanes

* **Dess** — a deterministic recomposition returns **byte-identical
  content**, so `proposal_digest` does not move: measured live,
  `4c1cd2d5405eeadf` before and after a refusal-driven recompose, and A's
  late result was then read as current. Re-selection does move it (the
  graph changes). Whether identical content over two generations should
  count as one proposal is yours to say; nothing here depends on the
  answer. The decoder holes in your own note (`or {}` on a list, a
  non-mapping container, a partly-wrong key set) are untouched by this
  lane.
* **Arty** — no assignment from this work.

## ENGINE LANE — the journey measures itself honestly now — 2026-09-13

**`claude/archipepsi-echoes-continuation-b1adno`**, bridge lane merged at
`4b68092`, art lane at `1a9f1c9`. Read this first.

### The reference round trip — GREEN

`godot-graphs` now proves ONE round trip through the real controller
before it says anything about a sample. A two-room Zone, a real
`ZoneController`, the real return action, **no edges** (so an
UNCERTIFIED Zone is never held for a verdict and this measures the
return path, not the bridge). Asserted in order, all passing:

walk in → stay standing, return not fired → reach a real interaction
target, **stopped by the player's own probe** (it found
`WarpStation_st_r002`, `[E] ACTIVATE R002`) → walk into the trigger,
stopped by the trigger → **exactly one** traversal, for the assigned
edge → the production consumer puts the body at `zone_start`, 0.0 m →
walk back in on foot and stay, no second traversal.

**And two controls, because a measurement that cannot fail is not one:**

| control | result |
|---|---|
| the production consumer taken off `traversed`, nothing else changed | the device still fires; the body ends **32.3 m** from the start. A driver asserting only the event cannot tell that from a completed return. |
| stopping at `ARRIVED` (the old rule) | the body stops **3.8 m** from a **1.4 m** trigger and nothing fires — this is what made the old journey read "could NOT get back". |

The four source-review findings are all closed: `ARRIVED` is no longer
one tolerance for every purpose (`_walk` takes a stopping condition);
the driver exercises `ZoneController._on_plug_traversed` rather than
instantiating a device; "content" is a node with `interact()` found by
the player's own probe; "re-entered" is walked.

### The preserved five, carried onto the same measurement

| leg | today |
|---|---|
| valid start | 5 of 5 |
| crossed the junction to the intended door | 5 |
| entered the side destination | 2 |
| remained standing in it | 2 |
| reached a real interaction target | **0** |
| completed the return | **1–2** |
| walked back in | 0 |

**`content` fell from 2 to 0 because it changed meaning** — it used to
be "reached the room's geometric middle". The old two were not two.
**`returned` rose from 0** because the walk is now stopped by the
trigger. Three approaches still never reach the branch (`zone_01` FALLS
at waypoint 0 even with the climb; `zone_04`, `zone_05` stop short), and
in the two that get in **the return device sits between the body and the
room's content**, so the content leg ends by being sent home — recorded
as "by wandering", which is not the §5.7 defect (it does not fire on
entry) and is not an intentional return either.

**`JOURNEY_FLOOR` is a MINIMUM OVER OBSERVED RUNS.** `returned` has been
seen at 2 and at 1 on the same commit from the same fixtures with
nothing changed: these legs are a real body in real physics steered by
signals and overlaps, and they do not repeat. Making them reproducible
is its own piece of work.

### Placement evidence — the correction, with five controls

Dess bars a host on evidence this lane produces, and three defects in it
could bar a good room. All three were mine and all three are fixed:

* `plug_clear` wrote `false` when the room published **no arrival**.
  `false` means "measured, and the body stands inside the device". The
  entry is now ABSENT — rule 4b refuses the LAYOUT for missing
  measurement, which is right, and does not condemn the ROOM.
* the settle **skipped its search whenever the pad was standable**,
  including a pad two metres from the arrival inside its own trigger.
  Support **and** clearance are asked now, of the anchor and of every
  candidate.
* one boolean cannot carry three outcomes. `plug_placement` reports, per
  room: `MEASURED`, `REPAIRED`, `NO_EVIDENCE`, `NO_CANDIDATE` — **and
  only `NO_CANDIDATE` may justify reselecting a host**, carrying what
  was searched (count, offsets, clearance, envelope) rather than a claim
  of impossibility.

Five controls in `godot-zone-audit`, each on a real built Zone. One of
them settles a question this lane got wrong: **a room over a kill pit
CAN host a return.** `platform_path` declares which square metres hold
weight and its end ledge holds a device as well as a player; with the
builder preferring a declared stand it reports MEASURED. "All pit rooms
are unhostable" was a generalisation from one position, and the control
exists so it cannot come back. `room:c012:return` no longer refuses
anything.

Also fixed: the arrival had **two sources** (`rooms[rid].arrival` and
`anchors["room:<rid>:arrival"]`). Both read the published anchor now.

### `godot-reload` — still RED, and it now names which half

**PHASE 1 (initial build + acceptance) fails**: a freshly composed Zone
is refused for *"door 'c008/side_left' is USED and the engine measured
it as solid"*. **PHASE 2 (reconstruction of an existing manifest) is
never reached**, so this run measures nothing about replay. Both phases
print what the bridge and the engine actually said instead of a bare
timeout. The earlier `room:c012:return` cause is gone; this is a
different, aperture-polarity failure and it is not diagnosed yet.

### NOT DONE in this batch, and not started

1. **Overlap reconciliation (item 2).** The join/collar distinction, the
   separate "router found a candidate" vs "bridge accepted it"
   publication, and the bounds diagnosis for the four large-shell
   failures. The previous batch's four attempts and why they were
   reverted are in `zone_builder.gd` and the section below.
2. **The pending-room integration proof (item 4).** The registry
   dependency seam, the one-neighbour Terminus with unused openings
   closed, the onward-branch assignment with its real departure, rotated
   placement and real arrival. The asset is present at
   `assets/models/batch044/shells/shell_bay_terminus.glb` (entry,
   branch_east, branch_west, **no exit**, and a manifest `exit_offset`
   of [0,0,22] which is exactly the fictional departure to refuse).
   `has_departure` and the consumer refusal are in; the seam is not.
3. **Items 2–4 of the placement correction**: the bar on required
   destinations, the no-automatic-branch-removal rule, and driving one
   real failed placement through reselection, rebuilding, acceptance,
   deliberate return and cold restart.
4. **The three journey gaps above** — the fall at waypoint 0, the two
   stop-shorts, and the device standing between the arrival and the
   content.

## ENGINE LANE — the recovery is driven, and the return stands up — 2026-09-13

**`claude/archipepsi-echoes-continuation-b1adno`, bridge lane merged at
`6d475e9`, art lane at `19e271b`.** Read this first; the section below
it is the router batch this continues.

### `godot-integration` is GREEN, end to end, with both new controls

A live bridge, a real campaign to `ALL_CHECKS_CLEARED` in 11 Zones.

**THE FAILED-ZONE RECOVERY, DRIVEN.** §5.7a defect 1 and §5.7b. The
control spends a Zone's whole layout budget with real refusals from the
real validator, then asserts what a player can do: the Hub names that
Zone to discard and offers no resume id for it; the portal is disabled
and asks for nothing; **a FRESH `HubController`** finds the console
visible and armed with the right id; the first press asks to confirm and
changes nothing; the second discards that Zone; its locations come back;
the next Zone generates. Twelve assertions, all passing.

**The owner's correction to the §5.7b handoff is in.** `discard_zone_id`
is populated in `ZONE_FAILED` and nowhere else, so the console resolves
its target **conditionally**: that field in `ZONE_FAILED`, `active_zone`
in the three modes it already served. One console, no second control.
An armed confirmation falls the moment its target moves or goes away.

**Successful generation and failed recovery are separate results**, and
here they are:

| | count |
|---|---|
| Zones played to completion | 11 |
| Zones that exhausted their layout budget and were discarded | **1** (`zone_007`) |
| layout refusals in the run | 7, of which 4 are the two controls' own falsifications |

Before the return-anchor settle below, those numbers were **5 discarded
and 19 refusals**. The difference is one defect, mine, described next.

### The return anchor — reserved, then SETTLED on measured ground

§5.7's engine half: `ChamberBuilders.return_spot` reserves the spot with
`_clear_spot` against the room's own furniture (claimed before the cover
crates roll), `anchors["room:<rid>:return"]` publishes it, `ReturnPlug`
stands on it, and `plug_clear[edge_id]` measures a player capsule at the
room's arrival against the device's trigger cylinder.

**AND RESERVING IS NOT STANDING.** A room with a chasm, a sunken bay or
a floor the builder does not model as furniture offers a spot that
reserves cleanly and holds no body — and the bridge refuses the WHOLE
layout for it. Measured live: *"a standing capsule does not fit at
'room:c003:return'"*, nine times, five Zones lost. So
`RoomAudit.measure_layout` now settles each return anchor onto ground it
has PROBED, and moves the plug node with it.

A lattice and not a ring, and that distinction was measured too: a ring
at 4 m and 7 m finds nothing in a corridor 7 m wide — every bearing but
two is outside the envelope and those two are the ones the ring steps
over. Nine refusals before, nine after, byte for byte. Offsets on both
axes, nearest first: **9 → 3**, and five discarded Zones became one.

When nothing holds, the anchor stays where the builder put it and the
bridge refuses — the honest outcome, not a silent one.

### A destination is not a through-room

The Terminus declares `entry`, `branch_east`, `branch_west` and no
`exit`. `_exit_offset` answers "where is the departure" by falling back
to the far face of the envelope, so a chain running through one would
advance its cursor through a back wall.

`ContentInstantiator` now reports **`has_departure`** as a fact of its
own — an assigned `depart_edge`, or a declared `exit`/`end_b` socket; a
shell that declares no sockets at all keeps the old answer, because the
whole authored contract post-dates it. `zone_builder` refuses a Zone
that asks a room with no departure to be walked through, naming it. **No
fabricated socket, no extra door, no silent fall back to a linear
Zone.** The last room on the spine is exempt: that is the leaf
assignment the shell is for, and a leaf may still carry branches — those
hang off its side sockets and never touch this.

**Not yet proven end to end**, and said plainly: the Terminus asset is
pending (Art `a6817cf`, not merged), and `zone_builder` builds through
`ContentInstantiator.build_chamber` without a registry argument, so a
synthetic destination shell cannot be routed into a full `ZoneBuilder`
test without a registry seam that does not exist yet. **Next item:** that
seam, then the leaf assignment through serialization and physical
placement with unused openings closed.

### MEASURED AND REVERTED: the router asking the validator's overlap question

The declared sample found a real disagreement. `_overlaps` in
`zone_builder` tolerates half a cubic metre so a room's inset entry
socket can swallow a little of the connector it joins; `layout.py`
tolerates a **millimetre on every axis** and refuses the whole manifest.
A thin, wide intersection sits inside one and outside the other, so the
router can return `LAYOUT_OK` for a proposal the bridge would not take —
`zone_10`'s `c008`/`c018` and `zone_12`'s `c005`/`c006`.

**Four changes were tried to close it, each correct about the thing in
front of it, and the stack does not hold:**

| change | result |
|---|---|
| the validator's rule as a post-check before claiming `LAYOUT_OK` | 36 shell/theme combinations in `godot-room-contract` stopped laying out — a real finding about those fixtures, not a repair |
| the same test pushed into `_search`, room against room | fixed those 36, and cost the turning fixture its turn: the route was free to corner back and undo an authored `exit_yaw` |
| forbidding that cancelling corner | the turning fixture then had no pose at all — a corridor leaving a room's face grazes that room, so the push broke against the room it had just left |
| exempting the room a route leaves | fixed that, and took the preserved five from **5 of 5 to 1**, branch rooms failing against 97 standing boxes where 42 had been the worst case |

So it is reverted, in the source and here. What the evidence says is that
the join exemption and the validator's rule have to be reconciled
**together** — corridor adjacency keeps a tolerance, rooms do not — and
that is a router change with its own measurements, not a rider on this
one. `SAMPLE_FLOOR` is 16 again, with the two unclean Zones named in the
constant's own comment rather than counted as clean.

Two tests whose premise the placement ladder outgrew were changed to
assert what they always claimed rather than to demand the router stay
worse: the spiral chain and the doubling-back chain each now say which
answer came back, assert the refusal's shape when refused, and assert
nothing is laid through anything when they lay out. The zero-budget arm
still holds the refusal's shape under test on a space that really is
empty.

### And the base kit had two definitions

`integration_driver.gd` carried a hand-written `["bounce_pad",
"moving_platform"]`; `bridge/tests/test_affordances.py` carried the
tuple. The day `powered_door` joined the kit the engine offered it
correctly and the client suite failed the Zone for offering it.
`BASE_KIT_TAGS` lives in `schemas/constants.py` now, exports, and both
sides read it.

### Withdrawn, and not implemented

The Batch 044 material-change request (lettering through the production
material path). The B image forcibly replaced authored shell materials in
a preview harness; `ContentInstantiator` does not do that, so the request
rested on reading the harness as the runtime path. **Nothing was changed
for it.** The procedural-material lettering issue is separate and still
open.

### `godot-reload` is RED, and the reason is a producer/consumer seam

`played_zone.json`'s `c012` is a `platform_path` — rising islands and two
narrow ledges over a kill pit — and the composer gives it a return plug.
**No spot in that room is both standable and clear of the arrival**, so
the layout is refused every time: *"a standing capsule does not fit at
'room:c012:return'"*.

Four placements were tried and measured, in this order: the reserved
spot from `_clear_spot`; the arrival's height instead of the envelope's
floor; a probed lattice around the arrival; and the room's own declared
`stand` surfaces probed in world space, which is the strongest answer
available and still finds nothing that clears the arrival by trigger
plus capsule. The engine now says so in its own words rather than
leaving the bridge's message to carry it alone.

**This is the §5.7 contract working, not failing** — the engine refuses
rather than standing a device where a player cannot be. **For Dess:** a
room over a kill pit is not a viable plug host. Either the composer
should not assign one there, or `platform_path` needs a declared return
surface wide enough to hold the device away from its start ledge. The
committed manifest was not rewritten to dodge this.

### What is still open

1. **The walker** — `_walk` steers flat through rooms fifty metres tall
   with elevation bands, so 3 of 5 branch approaches and both returns
   fall off a ledge. The single thing between here and a measured round
   trip. (See the section below for the leg-by-leg numbers.)
2. **`zone_007`** still loses its layout budget live: `room:c003:return`
   survives neither the reservation nor the settle.
3. **The destination/leaf seam** (above) — a registry argument through
   `ZoneBuilder`.
4. **Four sample Zones** wedge on oversized authored branch shells; a
   shell-vs-budget contract question, reported not repaired.

## ENGINE LANE — every preserved Zone lays out, and the journey is measured — 2026-09-13

**`claude/archipepsi-echoes-continuation-b1adno`, with the bridge lane
merged at `ef8ab36` and the art lane at `19e271b`.** Read this section
first on a wake-up; the one below it is the state this replaced.

### The router repair

**FIVE OF FIVE PRESERVED ORDINARY INPUTS NOW LAY OUT**, against the
same fixtures that recorded four failures, with topology and selected
shells held fixed. `KNOWN_INFEASIBLE` in `graph_driver.gd` is EMPTY and
all five are positive controls. Two faults, both diagnosed with
`--router-diag` before anything was changed:

1. **A room was placed without the corridor its own doors will need.**
   In three of the four failures the FIRST connector out of the
   junction's branch mouth started inside a standing room, so the branch
   search broke at push zero with open space two to eleven connectors
   further on that it could never reach. `zone_02` missed by 0.37 m of
   lateral clip; `zone_03` by 92 m³. A room now carries reservations for
   its unrouted branch doors and its own exit, two connectors deep, in
   its local frame, graded so a rung that cannot be honoured is dropped
   rather than costing the Zone the rungs that can.
2. **A refusal that had not looked.** `_search` stops at the first
   connector it cannot lay, so a room whose approach is blocked at push
   zero exhausted a candidate space of THREE poses out of a
   seventy-one connector budget and reported the Zone infeasible.
   Measured on `zone_02`'s `c022`: poses tested 3, corners entered 0.
   `ZoneBuilder.build` is now a bounded ladder around one greedy solve —
   when a layout wedges, the room the wedged one joined to takes the
   NEXT pose its own search already offered and the Zone is re-solved.
   Same seed, same graph, same shells, same candidate order; six rungs,
   two per room before it walks further back.

**Measured and rejected, recorded in the source:** a third reservation
rung holding the branch ROOM's envelope. Reserving 39 m × 50 m in front
of every junction that owes a branch pushed the spine around to find it
— the wider sample fell to fifteen and two preserved controls stopped
laying out.

### The declared sample: 14 of 20

Declared before it was run: the first twenty consecutive ordinary Zones
of a real campaign at `DEFAULT_CONFIG`, of which the preserved five are
exactly the prefix (generation is deterministic). `make zone-sample`
regenerates it; `SAMPLE_FLOOR` in `graph_driver.gd` ratchets it.

**41 placement attempts across the twenty in 8.3 s** — the retry
lifecycle measured, not estimated. The preserved five take 8 attempts
and 1.7 s. Six do not lay out:

* `zone_07`, `zone_13`, `zone_18`, `zone_20` — each wedges on an
  authored branch shell around **39 m deep and 50 m tall in a Zone 51 m
  tall**, with 30–50 rooms standing. The mouth is clear, the first five
  connectors are clear, and the room has nowhere to be. **This is a
  shell-vs-budget contract question, not a router repair**, and it is
  reported rather than fixed: either the world budget grows or a shell
  that size stops being eligible for a branch in a crowded Zone.
* `zone_10`, `zone_12` — overlap by less than the router used to care
  about. See below.

**THE ROUTER AND THE VALIDATOR DISAGREED ABOUT "OVERLAP".** `_overlaps`
in `zone_builder` tolerates half a cubic metre so a room's inset entry
socket can swallow a little of the connector it joins; `layout.py`
tolerates a MILLIMETRE on every axis and refuses the whole manifest. A
thin, wide intersection sits inside one and outside the other, and the
router returned `LAYOUT_OK` for two proposals the bridge would not take.
It now asks the validator's own question before claiming `LAYOUT_OK`.
That is why the recorded coverage is fourteen and not sixteen: **the
smaller number is the true one.**

### The player journey, measured leg by leg

`_walk_into` follows the **committed `links` corridor** waypoint by
waypoint. Steering a body at a side room's centre walks it into whichever
wall is between — which is what three of five Zones were reporting as
"stopped N metres short" while the route stood open.

Six results, ratcheted separately by `JOURNEY_FLOOR`:

| leg | today |
|---|---|
| valid start | 5 of 5 |
| crossed the junction to the intended door | 5 |
| entered the side destination | 2 |
| could remain in it, standing, not sent home | 2 |
| crossed it to its content | 2 |
| **completed the intended return** | **0** |

**THE JOURNEY IS NOT CLOSED AND THIS IS NOT A PASS.** `_walk` presses
forward and steers flat; these Zones have rooms fifty metres tall with
elevation bands, so a body steered at a waypoint on another level walks
off a ledge — `zone_05`'s ended twelve metres down. Three approaches and
both returns fall that way. **That is a harness limit, not a Zone
verdict**: two Zones' side rooms are demonstrably enterable and
crossable; the other three are unmeasured. **Next frontier item: a
walker that follows the corridor's floor rather than a flat bearing.**

### The return pad — §5.7 engine half, landed with Dess's

The composer names `room:<rid>:return` (`ef8ab36`) and this lane now:
reserves the spot with `_clear_spot` against the room's own furniture
(claimed before the cover crates roll, `return_clearance` = trigger +
capsule + margin); publishes `anchors["room:<rid>:return"]` for every
room; stands `ReturnPlug` there; and measures `plug_clear[edge_id]` —
capsule at the arrival against the device's trigger cylinder — reported
beside `apertures` and `arrival_ok`. Generated fixtures regenerated: all
five now name `:return`.

### The exhausted-layout Hub — §5.7a defect 1, owner's decision

A never-accepted Zone that spends its layout attempts is **not
enterable**. New snapshot field, computed where `MAX_LAYOUT_REFUSALS`
lives:

> **`HubStatus.resume_layout_exhausted: bool`** — "no committed manifest
> AND refusals spent". **Dess: this is the seam; confirm the spelling.**
> Nothing on the client derives the distinction from presentation text.

The portal offers no `[E]` in that state and refuses to emit; the
abandon console becomes visible and takes its zone id from
`resume_zone_id` (it read `active_zone`, which is empty in DORMANT, so
the only escape was both invisible and unarmed); and `_on_enter_zone`
refuses as a second lock, so stale `enter_zone` traffic cannot restart
the loop. A committed dormant Zone is unaffected — asserted as the
control in `godot-legible`. Dess's defect 2 (`layout_refusals` `le=99`
raising on the 100th) is now unreachable: it needed the loop.

### The lifetime boundary — after certify, before send

`_certify_physics` gave up when the Zone left the tree and then returned
to `send_layout_result`, which sent the half-measured result anyway; the
abandoned `_await_verdict` then spun for a Zone nobody is in and held or
released a **freed** `player` (`!= null` is not alive in GDScript).
Closed, with a regression in `godot-integration` that tears a Zone down
at two offsets and asserts a replacement reaches its own ACCEPTED
verdict, no freed-node access, no stale refusal, and no Check awarded by
certification.

### Two harness repairs, both of which had been reporting more than they measured

* the graph driver read every fixture from the generated directory
  whatever directory it was given — the sample read five files, failed
  to read fifteen, and announced "20 of 20 lay out" on fifteen empty
  Dictionaries;
* the integration driver sampled `layout_state` off the shared snapshot
  twelve physics frames after setup, walking past the very
  `layout_refusals` guard `_await_verdict` has for stale REFUSED. It
  waits for the controller's own recorded verdict now.

### What is still open

1. **The walker** (above) — the single thing between here and a measured
   round trip.
2. **Four sample Zones wedge on oversized authored branch shells** — a
   contract decision, not a router one.
3. **`zone_10` / `zone_12`** still overlap after the ladder; the router
   refuses them honestly now, but they are two Zones a player would be
   offered and could not enter.
4. **Offline layout acceptance** cannot be reproduced without playing
   the Zone (`ZoneController.setup` does more than `ZoneBuilder`), so
   `check_sample_layouts.py` is a REPORT. Acceptance is gated live by
   `godot-integration`.

## ENGINE LANE — Dess's carrier, and five Zones walked — 2026-09-13

**`claude/archipepsi-echoes-continuation-b1adno`, with the bridge lane
merged at `0ec9e8e` and the art lane at `19e271b`.** Read this section
first on a wake-up.

**THE PHYSICS PACKAGE TRAVELS ON DESS'S CARRIER.** Her `PlacedPackage`
landed while this lane was building a parallel `layout["physics"]` key;
hers is better — it binds the package to the Zone, the room AND the
declared content it realizes, and it goes into the manifest under the
same digest. So this lane took it: `ChainCertificate` emits
`layout["packages"]` as `PlacedPackage` records with the
`ReplayEvidence` inside the package, and the ad-hoc key is gone rather
than kept beside hers.

Three checks were added to her `_packages`, because
`check_physics_content` deliberately skips them: it passes over every
package that is not load-bearing — correctly, its subject is
progression guarantees — and a chain guarding a note is not one. On its
own it would have accepted every chain in silence.
`_certified_features` asks the inverted probe (a declared
`powered_door` with no package offered), the evidence gate (the same
`evidence_fault` function, asked of the packages it skips), and §13.2
(an optional feature's package may not be load-bearing).

**FIVE ORDINARY GENERATED ZONES, COMPOSED AND WALKED.**
`bridge/tools/dump_zones.py` writes a run of consecutive Zones from a
real campaign and `make godot-graphs` builds each one, reports its
shape, and sends the real `Player` into a side destination and back.
The shapes the composer makes today: 20–23 rooms, 4–5 junctions, 7–8
dead ends, degrees up to four. **No topology is preferred and none is
ruled out** — what is measured is whether the shape the composer chose
can be built and walked.

**Also landed:** the theme pack binds (22 surfaces of a real built room
painted from Arty's export, 3 from the procedural fallback), with the
hazard-role contradiction reconciled in the shared handoff — `hazard` is
universal, four roles need authored pixels, and a pack that paints its
own hazard is refused.

**AND FOUR OF THE FIVE ZONES DO NOT LAY OUT AT ALL:**

| | shape | layout |
|---|---|---|
| zone_01 | 23 rooms, 4 junctions, 7 dead ends | **LAYOUT_OK** |
| zone_02 | 23 rooms, 4 junctions, 7 dead ends | INFEASIBLE — branch `c021` off `c016`, 42 boxes standing |
| zone_03 | 23 rooms, 4 junctions, 7 dead ends | INFEASIBLE — branch `c015` off `c014`, 36 boxes |
| zone_04 | 20 rooms, 4 junctions, 7 dead ends | INFEASIBLE — branch `c019` off `c018`, 36 boxes |
| zone_05 | 20 rooms, 5 junctions, 8 dead ends | INFEASIBLE — spine room `c017`, 65 boxes |

**How bad is it, exactly.** An infeasible layout is not a dead end on
its own: `handle_layout_result` refuses it, puts the record back to
PENDING_GENERATION and composes again, up to `MAX_LAYOUT_REFUSALS` (3).
So a Zone gets four attempts, each a fresh shape. **One of the five
measured composed.** At that rate about two Zones in five would exhaust
all four attempts and go DORMANT — a Zone the player is offered and
cannot enter. Five samples is a small sample and the rate is not a
constant of nature, but the order of magnitude is what matters: this is
a degradation the player meets, not a test-only defect.

**This is the next thing to fix and it is the engine's.** The graphs are
legal; the router cannot lay four of them out. `branch_mouth` fixed the
case where the mouth was inside its own junction; what is left is a
route search that runs out of room. The smallest failing shapes are
captured in `godot/tests/fixtures/generated/`, and
`godot-bin/godot --headless --path godot -- --graphs --no-walk` composes
all five in about forty seconds, which is the loop to iterate the router
against.

**One lever was measured and does not fix it: `MAX_ROUTE_TURNS` 2 → 3.**
Still four failures, but on LATER rooms and with more boxes standing —
`c020` off `c018` at 43 boxes instead of `c021` off `c016` at 42,
`c014` off `c009` at 41 instead of `c015` off `c014` at 36. So more
turns does let the router get further before it wedges, and getting
further is not getting there: the Zone is refused either way, and the
extra search buys nothing a player can walk. Reverted to 2. **Written
down so the next pass does not spend the same afternoon on it.**

The shape of the real fix is structural rather than a constant: the
placement walk is greedy and never backtracks, so a Zone with eight
rooms off its spine eventually paints itself into a corner and the room
that cannot fit is whichever one was unlucky enough to be last. Either
the walk backtracks, or branch placement reserves its space before the
spine consumes it.

**`make godot-graphs` is GREEN and that is not the same as "this is
fine".** The four are recorded in `KNOWN_INFEASIBLE` with the room each
one wedges on, and the list is checked BOTH ways: a Zone that composes
today and stops is a regression and fails; one on the list that starts
composing means the router was fixed and the list is stale, which also
fails. A target simply left red on a known defect is a target people
learn to ignore, and then the regression it was meant to catch arrives
unnoticed. The defect is not hidden by this — it is in the list, in this
section, and in `NEXT_STEPS.md`.

**The player leg of that target reports and does not assert**, and the
comment in `_walk_one` says why: standing a body at an arbitrary
junction's side doorway is not solved, and failing on a walk that cannot
start would report a Zone defect that is not there. The junction
interior and branch that ARE walked with a proven spawn are in
`godot-room-contract`.

**Still open, and named rather than implied:** the four infeasible
layouts above; Art's half of §11.3 (a `player_entry` volume per
opening); the three Batch 044 junction shells are `review: "pending"`,
not exported, not selectable, and the owner's to review — **a
four-connection asset is not yet a four-neighbour room in a generated
Zone**; `latch_fired` from the engine when a player satisfies a declared
latch; and the fun verdict is not this lane's to award.

---

## ENGINE LANE — the chain is certified and the junction is walked — 2026-09-12

**`claude/archipepsi-echoes-continuation-b1adno`, with the bridge lane
merged at `603e876` and the art lane at `19e271b`.** Read this section
first on a wake-up.

**THE ENVIRONMENTAL-AGENCY CHAIN IS CLOSED, END TO END.** A physical
crate, a plate, a live signal and a powered door, in a Zone ordinary
generation produced — and the currently playable character performs it.
`Player._shove_what_i_walked_into` is what makes a body move a body:
`move_and_slide` resolves the contact by sliding the character, so
walking into a crate did nothing at all until the impulse was applied
from `_walk_intent` (direction × speed), which is the only quantity that
stays constant while a player leans on something. A 60 kg crate moves
7.10 m in three seconds; a 900 kg one moves 0.00 m.

`godot-physics` walks the whole chain with no force call by the test:
the door starts shut, a capsule does not fit through it, walking into
the crate puts 60 kg on a plate that asks for 36, the signal goes high,
the doorway opens — **and with the crate removed the same walk leaves
the door shut**, which is the sabotage that makes the rest evidence.

**AND THE ENGINE CERTIFIES IT IN THE CONTRACT'S OWN WORDS.**
`ChainCertificate` builds a `PhysicsPackage` for every `powered_door` a
room declares and replays it three times at exactly the manipulation
envelope **in the room it was built in** — the room's own crate, the
room's own plate, reset between runs — and sends the package and its
`ReplayEvidence` in `layout_result.layout["physics"]`.
`layout.validate` refuses a Zone whose declared chain is unreported,
unreplayed, replayed above the envelope, replayed against another
revision, or claims anything load-bearing (§13.2). `AMALGAM_BRIDGE.md`
§5.6a is the agreed shape. It costs about five seconds of Zone-entry
time per chain, inside the hold the player is already under.

The version this replaced measured the same physical fact and put a
four-word verdict in `build["mechanisms"]`, a key `layout_to_json` never
forwarded. It told nobody.

**BRANCHING IS A JOURNEY NOW, AND THE JUNCTION WAS BROKEN.** Ordinary
generation produces four junctions and eight rooms off the spine, and
the first Zone with two branches off one junction would not compose:
the branch mouth came from `ChamberBuilders.socket_placed` — the
PROCEDURAL socket table — and `c008` had answered a 17.9 m chamber with
a 41 × 60 m authored shell, so the mouth landed inside the junction
itself and every route failed at the first connector.
`ZoneBuilder.branch_mouth` reads the room's own door plan now, whichever
producer wrote it, and derives outward from the room's envelope rather
than from the name `side_left`. `09_ROOM_CONTRACT.md` §11.8.

With that fixed the real `Player` walks the whole journey in the
generated Zone: across the interior of a four-neighbour junction from
the opening it arrived through to the opening the branch leaves by, into
a side destination that is not the next room on the route, and back out.
Twenty-one corridor crossings never proved this; a corridor has two ends
and no inside.

**Also in this batch:** nobody spawns in a doorway whichever producer
built the room (the nudge moved to the runtime placement path, where
every producer's spawns become a body); the arrival region resolves by
the socket the chain arrives through (§11.3); and Arty's Span Basin
repair is walked by the actual Player rather than by a capsule.

**Still open, and named rather than implied:** Art's half of §11.3 (a
`player_entry` volume per opening); the three Batch 044 junction shells
are `review: "pending"` and are not selectable — the owner's to review,
and this lane does not write `pass`; and the fun verdict is not this
lane's to award.

---

## ENGINE LANE — the merged Zone opens again, and the way back is real — 2026-09-12

**`claude/archipepsi-echoes-continuation-b1adno`, from the art merge
`dfad94c`.** Read this section first on a wake-up; the bridge-lane
section below is still the payload reference.

**Green as of this section:** `make test` 1322, `check_packet.py`, and
every Godot target — `godot-test`, `-content`, `-room-contract`,
`-playtest3a`, `-zone-audit`, `-boot`, `-legible`, `-movement`, `-room`,
`-activity`, `-physics`, `-integration`, `-reload`. CI itself is red for
a reason that is not the tree: see `docs/CI.md`.

**THE GENERATED ZONE OPENS AGAIN.** `make godot-integration` was red
from the moment the art lane merged: `zone_001` was refused three times
on "door 'c002/entry' is USED and the engine measured it as solid" and
the client never left the Hub. The door was not solid. An **enemy was
standing in it** — `_enemy_spawns` fell back to `Vector3.ZERO` for a
shell that declares no `enemy_spawn` volume, and a shell's local origin
is not its centre, it is the wall the entry doorway is cut into. Ten
enemies, one 2.4 m opening.

Three things were wrong and all three are fixed:

* **The placement.** The fallback is the largest surface the shell
  declares standable, and every spawn is pushed out of any doorway it
  lands in (`ContentInstantiator.IN_THE_DOORWAY`). A player
  body-blocked in the only door is a defect whoever trips over it.
* **The probe.** `aperture_polarity` is ARCHITECTURAL — it already
  looks past a crate, a lock and the player. An enemy is placed content
  by the same reasoning and is looked past now.
* **The report.** "The engine measured it as solid" named the door and
  nothing else, so a Zone that would not open gave nobody a suspect.
  `RoomAudit.aperture_blockers` names the collider and the engine logs
  it.

**AND THE CENSUS HAD NEVER MEASURED A DOOR.** `_chamber_for` built
every registry shell with no `doors` at all, so
`_assigned_doors_match_their_usage` and `aperture_polarity` both ran
over an empty list and printed a clean sheet for twelve shells. The
recurring defect, again: a measurement that exists, is correct, and is
never handed the case that fails it. The census declares every doorway
socket now, and a second test
(`_test_every_shell_reports_its_apertures_once_placed`) places each
shell in a real three-room Zone, furnished the way the campaign
furnishes one, **in all six themes**, and reads the apertures the way
`ZoneController` reads them before putting them on the wire.

**THE UNRESOLVED CROSSINGS ARE CLOSED, AND THE LEVEL CHANGES ARE
COVERED.** `_player_walks_to` steers straight at its goal, so the old
test asked a body to walk through whatever stood between two arrivals
and pinned three joins on the result. The join's committed chain is the
route, and the body walks it doorway to doorway. `played_zone.json`:
**21 JOINED edges measured, 1 held behind a locked door, 21 crossed, 0
not** — 7 gridded arrival to arrival by the flood, 14 walked along the
corridor, five of those changing level by more than `MAX_VERTICAL_STEP`
(which the flood cannot grid and used to skip). `KNOWN_UNWALKED_JOINS`
is a dictionary of identity → reason and is **empty**, enforced in both
directions: a name that appears is a join that stopped connecting, and a
name that stops appearing has to be struck off. When a crossing does
fail, `_why_the_body_stopped` names the collider, the unsupported
interval, or the step the controller cannot climb — and says so when the
corridor is clear and the finding is about the steering.

What those 14 prove is the CORRIDOR. Getting from where a body lands to
its own room's doorway is the room's property and is proved by
`_test_the_played_zone_rooms_can_be_left_on_foot`.

**THE WAY BACK IN IS REAL, ON BOTH SIDES OF A RESTART.**
Two near-identically named constants were one question: `ZONE_DORMANT`
went into one and `portal_enabled` reads the other, so the portal showed
the mode's prompt and refused to fire — a way back that is wired,
labelled and dead. Both lanes found it independently, from opposite
ends. One name now (`ZONE_ENTERABLE_MODES`, the bridge's, spelled the
same in `HubController`), and the portal carries `[E] RETURN TO ZONE`.

`make godot-reload` **restarts the bridge too**. It used to stay up
across the two Godot processes, so "the campaign loads from disk" meant
the client loading from a bridge that still had everything in memory.
Both sides are new now, the bridge logs `loaded campaign`, and the
second process presses the real portal instead of setting
`_entering_zone` and sending the intent itself. 18 checks, including a
replay with **0 route searches**.

**A COMMITTED ZONE SURVIVES A REFUSED REPLAY.** `refuse_layout` cleared
`zone` and `manifest` whatever the Zone was, so a replay the validator
rejected sent a DIFFERENT Zone back under the same id, holding the same
Checks, with the player's keys and opened locks recorded against rooms
that no longer existed. `commit_layout` already refused to replace a
committed manifest; this was the other door into the same room. A
committed Zone keeps its manifest, its content and its progress and goes
DORMANT.

**Still unproved.** The physics contract in `schemas/physics.py` has no
runtime. The shared digest vectors, scene binding, rigid-body
interaction and the replay harness from the Amalgam brief are not
started. `shell_span_basin`'s pylon is Arty's open item and is a ROOM
finding, not a join one — the corridor either side of it crosses.
Procedural `ChamberBuilders` spawn placement is not covered by the
doorway rule; only the authored-shell path is.

**Done since:** levels 1 and 2 of the physics digest, and the first two
of `docs/AMALGAM_BRIDGE.md` §6.3's three — a rigid body that rests and
can be pushed (`ManipulableBody`), and one verb resolving to force,
range and mass (`Manipulation`). `make godot-physics`, 25 checks.

**THE ENGINE HAD NO `RigidBody3D` AT ALL** until this, so the physics
contract in `schemas/physics.py` described a system with no runtime.
Building one found a real disagreement: Godot's default friction of 1.0
resists a 120 kg body with ~1176 N against the envelope's 700 N of push,
so §29.3.2 promised something the substrate refused and a mandatory
route authored at the envelope would have been unsolvable by the host
the verifier says qualifies. A manipulable body's friction is derived
from the envelope now, and the three constants are exported to GDScript
from `physics.py` rather than retyped.

**And the headless replay harness (§6.3 item 3) runs.** `ReplayHarness`
replays a package three times, a fresh stage each, at the package's own
`fixed_step_hz`, against a provider at exactly the envelope, and reports
what latched PER RUN. A crate pushed onto a region latches in all three;
the same package with the push reversed latches in none, which is the
falsification. The substrate under it is deterministic: the same push
twice landed 0.000000 m apart, against a digest quantum of 1e-4 m.

`detail` and `reference_solution.steps` are opaque to the bridge by
design, so nothing had ever said what they contain. The engine's
vocabularies are written down in `docs/AMALGAM_BRIDGE.md` §6.3 now:
`POSITION_REGION` and `WEIGHT_THRESHOLD` are observed, `CONSTRAINT_STATE`
and `ATTACH_SENSOR` are **refused** because no joints and no attachment
sensors exist. Refused is not unlatched — a kind with no runtime reported
as "did not latch" is a harness claiming a puzzle is unsolvable.

**Still owed:** nothing in a campaign AUTHORS a physics package, so no
Zone has produced evidence and `handle_layout_result` has no path that
carries one. Levels 1, 2 and 3 all run; what has not happened is a
package reaching them from content.

## BRIDGE LANE — branches are choices, and a package has a carrier — 2026-09-12

**`claude/archipepsi-amalgam-bridge`, merged with the engine lane at
`7adc5e5`.** Read this before the older bridge section below; that one
is still the payload reference for the graph work.

**Green:** `make test` 1339, `check_packet.py`, `make mutate-bridge`
(layout 39 sites 0 unmeasured). No Godot run in this lane.

**FOUR BRANCHES WAS THE KEY RECIPE TALKING.** Whether a route off the
spine exists, whether it is locked, and how a lock and its key are
identified were one loop, so the branch count was capped at the four key
colours and every Zone got four. Three stages now: `_branch_routes` for
the topology, `_lock_routes` for which of those carry a lock,
`BranchLock` for identity and presentation. A route is lockable when its
key has somewhere to go that is not the spawn room; the rest are
ordinary branches, which are still choices. What bounds the route count
is real — spare rooms (`SPINE_SHARE`, **provisional tuning**), declared
socket capacity, and the `Zone` schema's own plug and edge maximums,
read from the schema rather than copied.

**AND EIGHT BRANCHES WAS ONE SIDE CHAIN.** The old report counted
locked doors; the new one reads the JOINED graph the Zone serialized
(`tests/zone_shape.py`). Eight "branches", seven "nested", were one side
chain eight rooms deep: one turning, taken once, **counted wrong**.
Default scale now measures **3-4 distinct side paths, 4-5 junctions, 2
inside a side path, 5-6 side dead ends, 4 locked and 4 open branch
edges**; prototype scale still composes chains and still says why. Two
instrument controls hand the report a spur and a fan that move the same
four rooms.

**NO SHAPE IS RULED OUT** (owner clarification, 2026-09-12). `SPINE_SHARE`
and `MAX_SIDE_DEPTH` are **provisional tuning and nothing more** — dials
where they currently sit, kept only if play evidence later gives them a
reason. A central junction connecting many rooms is good dungeon design,
and so are deep branches, shallow ones, nested ones, hubs, spurs and
dead ends. **The post-3A/3B complaint was never about graph shape**: it
was that rooms behaved like enlarged corridors, with little reason to
occupy or revisit them. That is a question about what is IN a room —
content, not topology — and no value of either constant answers it. Do
not promote either into a design law, and do not read the distribution
above as a target.

Two defects the measuring found: the planner gave up on a destination
when the *nearest* candidate junction had only its elevated wall spare
(one deck cost a 23-room Zone six of eight branches), and
`_branch_plan`'s no-destination path raised `NameError` instead of
falling back to the chain.

**§11.2 ANSWERED.** `arrive_edge`/`depart_edge` were read by
`content_instantiator.socket_for_edge` and written by nobody, so every
room fell through to the legacy `entry`/`exit` pair. The bridge writes
them now, derived from the door assignment and validated against it —
see `09_ROOM_CONTRACT.md` §11.7. §11.3 arrival regions and §11.4 branch
mouths remain the engine's.

**A PHYSICS PACKAGE HAS A CARRIER: option 2.** It arrives in
`layout_result`, is validated before anything commits, and rides the
accepted manifest — nothing on the Zone, so Epsilon's surface is
unchanged by construction. Three identities bound and resolved against
the Zone; a bad package refuses the layout rather than being dropped;
`latch_fired` is checked against the packages the manifest accepted and
only the approved consequence is persisted, in `ZoneProgress.latched`.
**Nothing became load-bearing** — no engine produces evidence yet, so
every load-bearing package is refused, and that is a test rather than a
promise. `docs/AMALGAM_BRIDGE.md` §5.6a says what the engine lane owes.

**THE RETURN PAD STOOD WHERE THE PLAYER LANDS** (engine-lane finding,
integrated build). The composer anchored a branch's return plug at
`room:<rid>:arrival`, which is exactly where `zone_builder` stands a
body entering the room, and `ReturnPlug` fires on `body_entered` — so
every side destination sent the player home on the first frame and did
it again on re-entry. The composer names `room:<rid>:return` now;
`layout.validate` rule 4b refuses a plug on the arrival and requires the
engine's measured `plug_clear`. `:arrival` stays a legal form so saves
already holding a branched Zone keep loading, and a committed manifest
is never repositioned. **The two halves must land together** — see
`AMALGAM_BRIDGE.md` §5.7 for the engine's side, which is
`ChamberBuilders._clear_spot` and one boolean.

**AND THE LIFECYCLE AFTER EVERY LAYOUT FAILS** (§5.7a), driven through
the handlers rather than read. Two things correct and now controlled: a
never-accepted Zone and a committed one stay properly distinct, and the
locations are recoverable — abandon returns them and the next Zone
generates. Two defects found, then AUTHORISED AND REPAIRED
(§5.7b): after exhaustion the Hub's only offer was re-entry into the
same refusal, and the counter was `le=99` but incremented without limit
so the 100th refusal raised instead of refusing.

**A FAILED ZONE IS A ZONE TO DISCARD.** `ZoneRecord.layout_exhausted` —
no manifest, REFUSED, budget spent — is the predicate, three existing
facts read together with no fourth field and no new `ZoneState`.
`hub_mode_for` is the one place that derives `ZONE_FAILED` from it; the
mode is held but neither enterable nor requestable, so `portal_enabled`
and `accepts_zone_request` fall out false without anything setting them,
and `enter_zone` refuses it at the transition too. `hub.discard_zone_id`
names the Zone for the abandon console — a separate name from
`resume_zone_id` so a consumer holding it cannot resume with it.
Nothing abandons automatically; the locations come back through
`abandon_zone` and no other path. `layout_refusals` saturates and a
further result is an ignored stale one, so 120 retries leave the field
at 3 and the save loading. A committed Zone is never swept in.
**Prod's half is two lines in `AbandonConsole`** — see §5.7b.

**A DESTINATION NEEDS NO DEPARTURE** (§5.8). `shell_bay_terminus`
declares `entry`, `branch_east`, `branch_west` and no `exit`.
`compose_with_branch` called `compose_chain` first as a feasibility
gate, and that requires an entry/exit pair from every room — so a
leaf-compatible room was refused as a through-room before it could be
chosen as a leaf, and the Zone came back with zero edges and every one
of its openings sealed. Roles are read from declared capacity now
(`_role`: through / leaf / unjoinable), before anything is composed; a
leaf is a REQUIRED destination that does not spend the branch budget;
and a leaf that cannot be placed, or that sits first or last, refuses
the Zone with the room named rather than linearising around it. A leaf
hosting one onward branch departs by a real doorway through
`depart_edge`, which is why `_exit_offset`'s fallback alone could not
fix it. **A capability probe, not a promotion** — no shipped shell
lacks `exit`, and nothing here offers a pending asset.

**AND THE REFUSAL IS A VALUE** (§5.8a). Those refusal paths returned an
edge-less product with a note, and nothing read it: `apply` drops notes,
`reachability` cannot tell an edge-less refusal from the legacy chain it
must keep accepting, and `_with_graph` handed it back as a good Zone —
caught only by the `Zone` schema rejecting doors-without-edges when
`accept_zone` rebuilt the record, which is a pydantic error out of a
background task. This lane's own recurring failure in its own code.
`GraphProduct.refusal` carries a code from a closed set now, a refused
product carries no doors, `_with_graph` raises, and the generation
handler takes the bounded recovery a failed generation already had. The
"no edges and a note" tests are gone; the controls drive the wrapper and
the real handler, and removing the consumption fails all five.

**A RETURN NEEDS A ROOM THAT CAN HOLD IT** (§5.9). `played_zone`'s
`c012` is a `platform_path` over a kill pit; the engine measured four
placements and none is standable and clear of the arrival, and the whole
Zone was lost for it. The bridge answers with a different host: the
graph is recomposed with that room barred, keeping the content, the
allocation and the Checks.

**ONE PLACEMENT CONTRACT, and the two halves did not meet.** Both lanes
shipped a `plug_placement`: the engine keyed by ROOM id with
MEASURED/REPAIRED/NO_EVIDENCE/NO_CANDIDATE, the bridge by EDGE id with
PLACED/CANDIDATE_REJECTED/NO_CANDIDATE. Traced: a `NO_CANDIDATE` in the
engine's shape was **accepted** here and barred nothing — a Zone
committing with a return that was never placed, both halves correct
alone. Reconciled to edge-keyed `PLACED` / `NO_EVIDENCE` /
`NO_CANDIDATE`, with MEASURED-vs-REPAIRED kept as diagnostic detail and
`CANDIDATE_REJECTED` dropped for having no producer. A report keyed by
something else is now REFUSED rather than read as an older payload,
which is how the mismatch stayed silent. The decoder had three further
holes, each measured: the key guard refused only when NONE of the keys
matched, so a room-keyed NO_CANDIDATE rode in beside a valid record;
`or {}` read an empty list as absence; and a non-container raised
TypeError out of the validator. Absent is a sentinel now, supplied must
be a dict, every key must name a plug, **a supplied report must cover
every plug**, and every record must validate. Prod's half is two lines; until
it lands, absence means the check does not apply.

**STALE PROPOSALS ARE CLOSED.** `proposal_id` on `zone_ready`, echoed on
`layout_result`, digesting the whole Zone so content replacement counts
as much as regraphing. A late result from a replaced proposal spends no
budget, bars no room, changes no graph and commits nothing, and the
replacement still completes its own acceptance.

**What bars a room is a PLACEMENT OUTCOME and nothing else** — and only
`NO_CANDIDATE`. Neither `arrival_ok` nor `plug_clear`
can carry that verdict and this lane read both as if they could:
`plugs_clear_of_arrivals` writes false when the ARRIVAL anchor is
missing, and `_settle_return_anchors` skips searching whenever the
current anchor is standable — so incomplete data, and a badly positioned
pad with a good alternate, each barred a whole room. Absent is
incomplete evidence and bars nothing, so nothing regresses before the
field arrives.

**Re-selection preserves the arrangement or stands down.** Handing back
a Zone with fewer branches is branch removal to dodge a device
requirement and is not an approved outcome; when no equal reassignment
exists the ordinary bounded refusal takes it. Not a branch quota, and
ordinary chains are untouched. `unhostable_rooms` is monotone AND
scoped: `accept_zone` clears it when content is replaced, because room
ids repeat across generations. A barred required leaf is
`destination_unhostable` rather than a filter it slips past.

Four recoveries, still separate: composition refusal, host re-selection,
fresh-proposal layout failure, committed-Zone preservation.

**NEXT FOR THIS LANE: nothing, until integration says otherwise**
(owner, 2026-09-12). Topology behaviour is to stay stable while Prod
exercises the integrated build. The next bridge work is **a specific
repair identified during that integration** — not a redesign, and not a
setting changed to produce a different-looking graph.

When a disagreement turns up, **read both ends before changing either
contract.** The producer here and the consumer in `godot/`. This lane
has twice been about to file a defect against the engine that the
payload settled in one run, and has twice committed two spellings of one
fact by writing its half without reading the other's. The existing
handoff — `09_ROOM_CONTRACT.md` §11.7 and `AMALGAM_BRIDGE.md` §5.6a —
is what Prod is building against; preserve it rather than adjusting it
to meet a finding partway.

**What is NOT claimed by any of the above.** Bridge acceptance is not
Godot layout acceptance and neither is a player walking it. Regenerating
`played_zone.json` and the playtest baseline updates the baseline; it is
not evidence the changed level is better or physically buildable. The
Godot targets have not been run in this lane.

---

## BRIDGE LANE — the Zone is a graph, and the path is connected — 2026-09-12

**`claude/archipepsi-amalgam-bridge`, from the engine slice `82d500f`,
merged up to `a632ec9`.** Read `docs/AMALGAM_BRIDGE.md` first: payloads,
what is proved by what, and the three-item handoff to the engine lane.

**Connected today, through real handlers:** generation composes the
graph and refuses one the player could not get around; `layout_result`
is validated and committed once; progress identities are checked against
the accepted Zone; leaving puts the Zone dormant with its Checks intact;
a reload from disk re-enters with layout, keys and locks preserved.
`test_amalgam_end_to_end.py` is that path and assigns to `engine.save`
nowhere.

**THE SEAM IS CROSSED, by the engine lane.** All three §5 items
landed at `dc4ef39`: `layout_result` is serialized, aperture and arrival
verdicts travel with it, and the committed manifest is replayed instead
of re-solved. That is their evidence — no Godot here, nothing in this
lane has run the integration driver.

**What this lane verified from the merge is narrower, and found a hole
that was mine.** The engine appends an exit room nobody declared and
files reserved joins (`e:__exit__`, `r:<room>`); the validator knew the
names and checked nothing else. It took two passes. Pass one caught an
exit room with no bounds and one inside `c001` — and **claimed a case it
had not fixed**: a corridor that *ends* ten kilometres away, as opposed
to one broken in the middle, still accepted, because internal continuity
has no opinion about where a corridor goes. So did deleting the reserved
pair outright, and a piece of a kind the engine cannot rebuild.

Pass two takes the contract from `zone_builder` instead of from taste:
the reserved pair is **required** (every LAYOUT_OK appends it), pieces
must satisfy `malformed_pieces` — kind, pose, a corner's turn — because
**that is the guard the engine runs before replaying a committed chain,
and when it trips the Zone returns LAYOUT_INFEASIBLE and does not
open**, and `e:__exit__` gets the full `socket_a -> chain -> socket_b`
walk, which the builder makes close exactly. The old fixtures were
brought up to that shape rather than the contract brought down to them.
34 of 34 refusals in `layout.py` are exercised. `docs/AMALGAM_BRIDGE.md`
§5.4.

**TWO QUESTIONS WAITING ON THE ENGINE LANE**, both implementation
details rather than owner decisions:
1. **`r:<room>` endpoints** — `docs/AMALGAM_BRIDGE.md` §5.4a. Can it be
   filed with doorway endpoints like `e:__exit__` already is? If yes the
   bridge deletes a special case and walks it like any other edge. One
   dictionary literal in `_joins`, one branch in `_check_reserved_join`.
2. **`scene_digest` coverage** — §6.2b. Five decisions with proposed
   defaults: float quantization, whether effective physics values are
   statically readable at all, what counts as participating geometry,
   ordering across saves, versioning granularity.

The bridge's half of the replay is connected and measured — re-entry
emits the manifest and `test_the_whole_path` asserts the emitted message
carries it. **Deleting that emit passed all 1091 tests until it was
asserted**: the save file is identical either way, so the suite was
reading storage and calling it the seam. Assert the message, not the
record.

**Connected since 2026-09-12 (engine lane):** all three of the items
this section used to list as missing. The engine serializes
`layout_result`, measures aperture polarity and arrival support and
sends both, and replays the committed manifest on re-entry with the
route search counter proving it did not re-solve. `make godot-integration`
plays a whole campaign with every layout ACCEPTED and carries a
deliberate refusal as its control; `make godot-reload` reopens a campaign
in a SECOND PROCESS and recovers the layout and the progress from the
bridge alone.

**Connected as of 2026-09-12:** the physics contract in
`schemas/physics.py`. The engine builds a `PhysicsPackage` for every
`powered_door` chain an ordinarily generated room declares, replays it
three times at exactly the manipulation envelope **in the room it built
it in**, and sends both in `layout_result.layout["physics"]`;
`layout.validate` refuses the Zone if a declared chain is unreported,
unreplayed, replayed above the envelope, replayed against a different
revision, or claims anything load-bearing. `AMALGAM_BRIDGE.md` §5.6a.

~~**The DORMANT-Hub hole (`AMALGAM_SLICE1.md` §5q) is half closed.**~~
**Closed on both sides, 2026-09-12.** The bridge side landed first:
`ZONE_DORMANT`, `hub.resume_zone_id`/`resume_zone_name` naming which
Zone the portal enters, `hub.revisitable` for finished Zones, and
`portal_enabled` true for the dormant mode. The Hub affordance landed in
the engine lane the same day — the portal branch reads the mode,
`_on_enter_zone` takes the id from `resume_zone_id`, and the portal
carries `[E] RETURN TO ZONE`. `make godot-reload` presses it, through a
restart of BOTH processes.

Both lanes found the same last obstacle independently and from opposite
ends: `portal_enabled` was reading a second constant that had never
heard of the new mode. There is one list now rather than two with equal
contents.

**All three of SOLUTIONS_CATALOGUE §2's local-key rules are enforced.**
A key reachable without passing its own lock, an acyclic key graph, and
every capability gate on the way to a key, a required Check or the Zone
exit declared in the matching AP logic. The third is currently a refusal
of everything — the apworld declares no prerequisites — which is the
intended behaviour and is a refusal rather than a silence.

~~**`manipulate` and `vector_latches` are blocked at the substrate.**
Zero `RigidBody3D` in the project.~~ **The substrate landed 2026-09-12**
(engine lane): `ManipulableBody`, `Manipulation` resolving §29.3.2's
three minima, and `ReplayHarness` replaying three times at exactly the
envelope. The capability vocabulary still omits `manipulate` on purpose
— a Zone must not declare a gate before content can author one — and
that is now a CONTENT gap rather than a substrate one.

**Three levels of evidence, kept apart.** The frontier is not "done /
not done":

| | |
|---|---|
| **Connected** — runs in a real campaign | graph composition at acceptance, reachability refusing an unreachable Zone, `layout_result` validated and committed, progress identities checked, DORMANT/VISITING, leave-reload-re-enter |
| **Fixture-tested** — the rule is decidable and proved, nothing calls it from a running engine yet | **nothing in this row today.** Layout evidence validation moved up when the engine sent a real `layout_result` (`dc4ef39`); the physics contract moved up on 2026-09-12 when the engine lane built `ManipulableBody`, `SceneDigest` and `ReplayHarness`, and moved to **Connected** the same day when `ChainCertificate` began producing a package and its evidence for an ordinarily generated Zone and `layout.validate` began refusing on them |
| **Requires Godot** | physical reachability and the whole physics substrate — `docs/AMALGAM_BRIDGE.md` §6. Aperture polarity and the manifest replay consumer moved to **Connected** on 2026-09-12 |

**The physics digest has three levels and only the first is done.**
Serialization agreement (the nine shared vectors in
`godot/tests/fixtures/physics_digest_vectors.json`, **constructed from
each vector's `package` and run through each lane's own production
serializer** — hashing the stored strings proves the file is
self-consistent and nothing about the code) — **both sides done, 2026-09
-12**: `PhysicsPackage` (`godot/scripts/content/physics_package.gd`)
builds each package and writes its own canonical bytes, and all nine
vectors agree BYTE FOR BYTE, not merely in digest. It carries its own
JSON writer because Godot's differs from Python's in two ways that both
change the hash — an integral float prints as `80` rather than `80.0`,
and non-ASCII is emitted raw rather than `\uXXXX`-escaped. Falsified
two ways in `godot-content`: half a kilogram of mass moves the digest,
and a package carrying a field this lane does not model is refused
rather than dropped out of the hash. Scene binding (`scene_digest` computed from a real setup, not
a constant) — not started; coverage list is `docs/AMALGAM_BRIDGE.md`
§6.2b, with **five decisions for the engine lane** (float
quantization, whether effective values are statically readable, what
counts as participating geometry, ordering, versioning granularity) —
all five answered and **implemented 2026-09-12** as `SceneDigest`
(`godot/scripts/content/scene_digest.gd`), falsified four ways: node
order does not move it, a millimetre does, a tenth of the quantum does
not, and a body that starts the replay moving does. Not yet called from
a replay, because there is no replay. Physical outcome
(replay) — not started. Level 1 passing says nothing about level 2, and
**a constant `scene_digest` passes every check on this side**: sixteen
hex characters is all the bridge can see. Regenerate the vectors with
`make physics-vectors`; **that is a contract change and the engine lane
must re-run.**

**THE WAY BACK INTO A ZONE WAS NOT REACHABLE.** Walk out, restart, and
the Hub said `ZONE_AVAILABLE` — "PORTAL READY" — over a DORMANT Zone
holding 15 Checks; pressing the portal got "still holds locations", and
the only way forward was to abandon the Zone. Beside it, `hub_status`
raised `KeyError: 'VISITING'` — out of the snapshot path — the moment a
player revisited a finished Zone. The bridge half is fixed:
`ZONE_DORMANT`, `hub.resume_zone_id`/`resume_zone_name`,
`hub.revisitable`, `ZONE_HELD_MODES` split from a new
`ZONE_OCCUPIED_MODES` (held and unoccupied could not be said with one
list), and `ZONE_STATE_HUB_MODE` total over `ZoneState` by assertion.
Proved by entering only through what the snapshot exposes.
**Two lines are owed by the Hub and are Prod's to write** —
`docs/AMALGAM_BRIDGE.md` §5.5b.

**A gate may stop you; it may not keep you — and `R ⊆ E` already said
so.** A claim here said §0-bis condition 4 "had no rule" and that a
one-way edge into a dead end passed every check. False: `R ⊆ E` requires
the exit reachable from every state, `_escapable` requires the entrance
or the exit, and the first implies the second — no Zone is refused by
one and accepted by the other. The fixture offered as proof also
disconnected the exit entirely. What `_escapable` adds is the
distinction between "blocked, can walk back and return with the
capability" (the intended gameplay) and "blocked and stuck" (a dead
run), which `R ⊆ E` reports with one sentence. It is also the backstop
for the day `R ⊆ E` is relaxed to allow a legally gated exit;
a test asserts the subsumption so that day gets noticed.

**Conditions 1 and 2 need an owner decision, and the proposal is
written.** `reachability` takes `declared_capabilities` and nothing
passes it, because capabilities are not AP items: they come from Epsilon
interpreting whatever the multiworld gave you, which is a random reward
rather than a proof of obtainability. **`docs/AP_CAPABILITY_LOGIC.md`**
traces the acquisition chain and compares explicit capability items
against guaranteed local acquisition represented in AP logic — for each,
where the guarantee comes from, how location rules match it, and how a
qualifying provider reaches the player. The two options are different
games; that is the choice. The choice is narrower than the
first draft claimed: an AP progression item does **not** cost the
interpretation premise, because a guarantee is a contract on FUNCTION
(primitive family, resolved parameters at or above the envelope) and
presentation stays interpreted and validated exactly as it is today.
What actually differs is whether capability progression sits in the
multiworld or beside it. Also corrected there: access rules are fixed
at seed generation, so the capability contract flows AP -> runtime
(location_id -> required capabilities, in slot data) and the allocator
obeys it — the runtime cannot attach a rule to a Zone it allocates
hours later. And hidden Checks are **not** exempt under the
gate-only-optional option: optional to finishing a Zone is not optional
to AP accessibility.

**READY FOR PROD, AND IT MOVES ON ITS OWN: the way back into a Zone.**
Bridge half done and accepted. **One task, and it is only the portal**
— `ZONE_DORMANT` routing and `resume_zone_id`. The progress half of the
restart is CLOSED: the engine lane fixed it independently at `fa5f056`,
better than the write-up here (it UNIONS the bridge's persisted
progress with the in-flight in-memory half, because an intent sent in
the same breath as leaving may not be in the snapshot yet, and both are
monotone sets). `ZoneReady.progress` was added here and is reverted: the
game reads progress and manifest from `BridgeClient.active_zone()`, the
snapshot record, so a field on `ZoneReady` was a second carrier for one
fact — the same failure as `ZONE_ENTER_MODES`, one commit after writing
it down. Regression coverage kept and now asserts the carrier in use. `docs/AMALGAM_BRIDGE.md` §5.5b has the exact
serialized `hub` block, the `hub.gd` / `main.gd` change, and the one
open Hub-design question (`revisitable` can hold many Zones and the
portal is one object). Take it whenever; nothing in the qualification
work below blocks it or is blocked by it.

**PROVIDER QUALIFICATION IS SEPARATE FROM IDENTITY, and now
implemented.** `owned_capabilities` said `cross_long_gap` for a 4 m/s
dash and a 20 m/s dash alike, so a six-metre route was proved by a
provider that might carry three. `qualifies_for_gap` reads RESOLVED
provider parameters against the route's requirement in metres;
`max_safe_gap(rise)` is the base kit's own reach, so a crossing inside
it is not a gate at all. **No envelope went into the `stats` Boolean** —
`stats` holds stat NAMES, and that branch is the identity question.
**Evidence is bound to what it describes, not just well-shaped.** A row
naming `blink` certified a dash, a row certifying a band of `range`
certified a `force` reading, and any well-formed `setup_digest` passed
because nothing compared it — the tests checked digest FORMATTING and
the provider mapping, never the bindings. All three refuse now
(`evidence_misfiled`, `evidence_for_another_setup`), and a missing
expected identity is `setup_identity_unknown` rather than a pass. **The
digest is recorded provenance, not working stale-evidence
invalidation**: the comparison is here and nothing produces the other
half, so where the expected setup identity comes from is the first thing
to agree with Prod (§8b).

`CROSSING_EVIDENCE` ships EMPTY and nothing qualifies without it:
`Dash.force` is a velocity impulse in m/s that `_dash` ADDS to current
velocity along camera-forward, so no closed form exists here and the
measurement is the engine lane's, like `scene_digest`.

**Evidence states what it covers and extrapolates nothing.** A first
draft stored `(parameter, reach)` points and read the largest at or
below the provider's value, so force 12 silently certified force 20 —
stronger is not automatically suitable, it can overshoot the landing.
And reach alone certified a six-metre gap landing a hundred metres up,
because `rise_m` reached the base-kit comparison and never the
provider's evidence. `CrossingEvidence` now names a certified parameter
band, an executed rise band and the `setup_digest` that produced it;
outside either band is `outside_measured_scope`, a different answer from
`no_envelope_measured`. Providers are scoped by name
(`QUALIFIABLE_PARAMETER`), so `glide` and `hover` report
`provider_not_qualifiable` rather than pretending to be unmeasured.

**The boundary, plainly: `qualifies_for_gap` has TEST CALLERS ONLY.**
What refuses an undeclared gate today is `topology.reachability`, on the
Archipelago side. The production consumer will be `layout.validate` —
the only place the bridge holds metres, since a gated TRAVERSAL_ONLY
edge's plug anchors give a gap and a rise once the engine returns
`layout_result`. AP obtainability and physical suitability are separate
obligations and neither substitutes for the other.
`docs/AP_CAPABILITY_LOGIC.md` §8b has the evidence shape to agree with
Prod, §8c the boundary. Design 1 §13.1 calls `DASH_IMPULSE` a distance
in metres while the schema carries m/s — a divergence someone has to
reconcile. **AP-relevant gates without a matching guarantee stay
refused.**

**BRANCHING COMES FROM THE CATALOGUE NOW.** `AUTHORED_SOCKETS` hardcoded
`("entry", "exit")` — true of all twelve shells, never a property of
being authored, and a three-door shell would have been composed as a
two-door one with its third opening SEALED. Capacity is read from the
catalogue end to end: `shells.joinable_sockets` off the entry,
`rule_of` carrying it on the wire so a generator can choose a shell that
branches, `topology` reading it and refusing rather than assuming for an
unknown shell. Junction candidacy is capacity, not authorship.

Composition derives what a Zone can afford from two things that already
exist — the spine keeps half the spare rooms, and `KeyColour` has four
values so a fifth branch would reuse a colour. Multiple branches and
branches off branches, with destinations that carry a Check or a key.
`make test` includes generation coverage over declared inputs that
REPORTS the distribution: prototype scale 3-4 rooms and 0 branches, each
saying which cost it could not meet; default scale 19-23 rooms, all
branching, all nesting, four each because the colour vocabulary caps it.

**Physics packages have no carrier yet and the reason is a boundary, not
an oversight.** `Chamber.packages` was refused by
`test_epsilon_vocabulary`: `LatchCondition.detail` and
`ReferenceSolution.steps` are free text, so a package on the Zone is a
package a creative provider could author. `docs/AMALGAM_BRIDGE.md` §5.6
puts three carrier shapes to Prod; this lane's half is ready to write
behind whichever answer.

**Capability gates are searched, not sampled.** A previous guard removed
one gate edge at a time with every other gate left passable, so two
undeclared gates each validated the other. Availability is a set the
question is asked under, and everything — exit, Checks, keys, `R ⊆ E` —
is asked under it. `BASELINE_CAPABILITIES` counts: `ranged_hit` is Static
Pulse and needs no AP logic behind it.

**`make mutate-bridge` asks which refusals anything has ever fired.**
Mute one, run the tests, and a green suite means nothing was reading it.
First run: eleven unmeasured, including the whole re-entry manifest
replay (deleting it passed all 1091 tests — every assertion read the
saved record, and the save file is identical either way) and the chain
walk's inductive step, which the single-piece fixture could not reach.
`layout.py` and `topology.py` are now at zero. **Seventeen survivors
remain in `schemas/transitions.py`, in pre-existing campaign
transitions** — `start_generation`, `accept_zone`, `abandon_zone`,
`release_location`, `claim_zone_check`, the shop pair,
`grant_local_reward` — left standing on purpose because they are not
this lane's; `docs/AMALGAM_BRIDGE.md` §4.1a has the command. A survivor
is a real gap, a backstop unreachable by construction, or dead code —
never something to close by weakening the check.

**The lesson worth keeping.** The first validator skipped every check
whose input was absent, so a layout with no apertures, no bounds and no
arrival verdicts was ACCEPTED. Missing evidence is not passing evidence;
a graph Zone now arrives complete or is refused.

# Archipepsi autonomous frontier

This file is the cheap wake-up state. Keep it short and current. Use `NEXT_STEPS.md` for the detailed project/history handoff and the v0.8 packet for authoritative contract details.

**A packet version is not a product milestone.** `design-packet-v0.4 / v0.7 / v0.8 / v0.9 / v0.10` are document revisions; **Playable 0.3** is the product milestone, frozen in `docs/ROAD_TO_PLAYABLE_0_3.md`. Packet v0.10 does not mean Playable 0.10, and Playable 0.3 has nothing to do with the superseded packet v0.3 — always write the full name.

## AMALGAM SLICE 1 — the active implementation branch

**`claude/archipepsi-amalgam-slice1`, from Production `c8ed2e9`.** The
playable checkpoint stays on `claude/archipepsi-echoes-continuation-b1adno`
and is not merged into.

**Read `docs/AMALGAM_SLICE1.md` first** — what is playable, what is
implemented but unintegrated, what remains, and how to run it
(`--slice1`).

Engine lane only. The bridge column — `TopologyEdge`, `DoorAssignment` /
`PlugAssignment`, `ZoneProgress`, `DORMANT`, `R ⊆ E`, the manifest and
check 19e — is Dess's and nothing here implements it.
`docs/reviews/2026-09-12-room-contract-prod-review.md` (on the checkpoint
branch) returned changes requested against `cb3bf64`; this slice builds
only what is invariant across how the `TRAVERSAL_ONLY` contradiction is
resolved.

**Dess has the bridge on `claude/archipepsi-amalgam-bridge`, from
`82d500f`** (owner assignment, 2026-09-11). Nothing in this lane
implements `TopologyEdge`, `DoorAssignment` / `PlugAssignment`,
`ZoneProgress`, `DORMANT`, `R ⊆ E`, the manifest or check 19e.

**Owner ruling, 2026-09-11: a fully cleared Zone stays revisitable.**
Final-Check completion does not permanently close it. This closes the
question this lane had open and is what §0-bis condition 5 needs.

**§30.11.2e constraint 3 is a refusal, not a solver.** `build()` returns
`LAYOUT_INFEASIBLE` naming `blocking_pairs` when a `JOINED` edge would
close a spatial cycle, before allocating anything, and
`routing_policy.closes_cycles` is `false`. A `TRAVERSAL_ONLY` edge is
never counted — a return plug creates no spatial cycle. Closing a real
loop needs a router that can return to a fixed transform and is not
built. See `docs/AMALGAM_SLICE1.md` §5e.

**Branches are placed, walked and remembered.** A chamber may declare
`branches: [{socket_id, chamber}]`; the branch is placed off that side
socket by the same route search the chain uses, furnished by the same
`_furnish_room`, and refused if the socket is not a way through. The
integrated proof crosses the lock into the branch, returns through its
plug, and re-enters to find the lock still open.

**THE SEAM IS CROSSED.** `placement_plan` reads the bridge's `edges` and
each chamber's `doors` and places the real branching graph; the layout
goes back as `layout_result` with measured apertures and arrival
verdicts; and `ZoneReady.manifest` is replayed on re-entry rather than
re-solved. Five of six generated Zones commit a layout with a digest.

**EVERY generated Zone commits a layout.** Crossing the seam with
acceptance gating on surfaced five defects between the Zone a composer
declares and the one the engine builds; all five are fixed and
`docs/AMALGAM_SLICE1.md` §5p names them. The shortest version: a socket
table that said every doorway was at `y = 0` while two producers carve
theirs metres up; five producers that ignored the door assignment
entirely; a front door both lanes carved against the composer's own
`SEALED`; an arena's cover crates and a band's access ramp standing where
a body arrives; and three authored shells whose `exit` is off their own
body.

**And withholding them costs two things, both recorded rather than
worked around.** The fallback's landmark arena was a fixed
`26.0 x 24.0 x 7.0` and the shell a big room happened to wear was doing
all its varying — the landmark rolls now. And no generated Zone can carry
an authored movement offer: four shells carry offers, three are withheld
and `shell_yard_gantry` is over `AUTHORED_AREA_BUDGET`. Raising the
budget to admit the yard was tried and put back (it made every Zone an
85 x 52 m room with two unwalkable joins and a rail a body cannot ride);
`godot-playtest3a`'s two offer tests state the whole reason and pin it,
so they fail the day any part of it is repaired.

**FOUR shells are withheld now, not three, and Art found the fourth.**
Arty's 2026-09-12 reply measured `shell_yard_gantry`'s doorways 0.40 m
past an envelope of -42.60..42.60 — the same defect on the other axis —
and measured the three repaired shells' walls running to exactly the
declared depth, which is what says a shell's `size` IS its outer face.
The gate allowed one `WALL_THICKNESS` and passed the yard by five
millimetres; it allows rounding now. A wall thickness still belongs in
`layout.SOCKET_PROUD`, which compares against the engine's REPORTED
bounds (wall centre planes), and that distinction is the whole fix.
Nothing about a generated Zone changes — the yard was already over
`AUTHORED_AREA_BUDGET` and the fixture digest is byte-identical — what
changes is that the gate now says the real reason.

**Those three shells are Art's and are withheld, not patched.**
`shell_hall_transit`, `shell_plenum_helix` and `shell_span_basin` each
declare their `exit` doorway 2.0 m past their own declared depth — the
router joins the corridor at the socket and the wall is two metres away,
which is the playtest's "the connecter isnt connected at all". Codex
measured the shipped GLBs independently and they end at the declared
depth, so the socket is the outlier. `shells.is_offerable` withholds
them and lets them back the moment the repair lands:
`docs/art-requests/2026-09-11-doorways-outside-their-envelope.md`.

**"Outside the envelope" is not the rule.** `corner` steps its exit a
full `WALL_THICKNESS` past its bounds deliberately and
`shell_yard_gantry` sits exactly on its wall face. A doorway is an
attachment transform and may sit one wall thickness proud; that one
allowance is defined once (`layout.SOCKET_PROUD` /
`shells.doorways_off_the_body`) and both lanes read it. It is a different
measurement from the aperture (is the hole cut) and from the arrival (can
a body stand), and all three are taken separately.

**Evidence comes from the body now, not only the model.** The flood
proposes a route and a real `Player` walks it; the two are reported
separately. c015, c005 and the pit are all left on foot, and the whole
branch journey — lock, key, crossing, plug, persist, re-enter — is walked
by a real body. See `docs/AMALGAM_SLICE1.md` §5o.

**A resume now comes from the save, not from memory.** `Main._to_zone`
read three in-memory dictionaries whose own docstring said they do not
survive quitting, so the bridge held the progress and the game walked
past it. `make godot-reload` is two Godot processes against one bridge
and one save directory: the first plays, the second is launched cold and
recovers the committed layout (0 route searches), the key, the lock and
the resume station from the bridge alone, then walks through the doorway
it opened last time without collecting the key again.

## THE ACTIVE FRONTIER: v0.9 — production and the authored-content transition

**`docs/design-packet-v0.9/IMPLEMENTATION_PLAN.md` is what wake-ups
execute.** S1–S10 (Echoes 2.0) are complete and are history below; the
plan is NOT exhausted.

The governing rule, from `docs/design-packet-v0.8/AUTHORED_CONTENT.md`
(normative, outranks the v0.9 plan): **developers author the alphabet, Godot
enforces the grammar, Epsilon writes sentences.** Epsilon is a composer,
never an asset generator. Do not manufacture "final art" procedurally to
claim a stage. Existing primitive geometry and materials are valid
TESTABLE placeholders and stay. Graybox `.tscn` scenes are legitimate
deliverables and must say in-file that they are not final art.

Dependency order (S21/S22 are independent of the asset pipeline, and are
the work that continues if an art gate blocks the rest):

```
S11  CI                        ── independent, first
S12  registry + asset contract ── the foundation S13-S19 consume
 ├── S13 instantiation pipeline
 │     ├── S14 Hub + Echo Lab migration
 │     ├── S15 room shells + connectors ── S16 encounter/traversal vocabulary
 │     ├── S17 interactable/presentation contracts
 │     └── S18 enemy/player/affordance visual interfaces
 └── S19 material/VFX/audio/lighting registries
S20  campaign spine (human-decision gates)
S21  settings/input/a11y       ── INDEPENDENT
S22  packaging/first-run       ── mostly independent
S23  release hardening         ── last
```

**Stage status:**

| Stage | State |
|---|---|
| S11 CI | **done** — three tiers green on real runners; `docs/CI.md` |
| S12 registry + asset contract | **done** — `schemas/content.py`, `content_registry.gd`, `docs/ART_ASSET_SPEC.md`, `make godot-content` |
| S13 instantiation pipeline | **done** — `content_instantiator.gd`, routed from `ZoneBuilder` |
| S14 Hub + Echo Lab migration | **done** — `hub_anchors.gd`, Lab gap pinned |
| S15 room shells + connectors | **grammar done; shells BLOCKED on Q1** |
| S16 encounter/traversal vocabulary | **done** — tower ascent bounded, gap bound exported |
| S17 interactable/presentation contracts | **done** — `interactable_contract.gd` |
| S18 enemy/player/affordance visual interfaces | **done** — `visual_interface.gd` |
| S19 material/VFX/audio/lighting vocabularies | **done** — `test_epsilon_vocabulary.py` |
| S21 settings/input/a11y | **done** — `player_settings.gd` |
| S22 packaging/first-run | **done** — `make doctor`, secrets tests |
| S20 campaign spine | **hooks built; BLOCKED on Q3** (narrative) |
| S23 release hardening | **done** — `AUTOMATION_LIMITS.md` |

S22 added `make doctor` (a fresh-clone preflight that separates
REQUIRED from optional — no API key is reported as fine, because the
fallback provider is what a player without one plays) and the secrets
tests: no tracked file may contain a key-shaped string, `.env` must be
ignored AND git must agree, and no third-party binary may be tracked
without a licensing decision (Q2).

S21 holds two rules: a preference is never campaign truth (asserted
against `CampaignSnapshot` and `CampaignSave` by reading the preference
names out of the GDScript, so the two cannot drift), and rebinding can
never leave a base-kit action unbound — a player who unbinds `jump` has
made their own seed unfinishable, in a menu, three rooms from the gap.
A hand-edited config is repaired rather than obeyed.

S19 enforces "Epsilon is a composer, never an asset generator"
STRUCTURALLY rather than by review: every string field of every model
Epsilon authors must be a closed vocabulary, a charset that cannot spell
a path, or allowlisted prose with a stated reason. A new free-text field
fails the test until someone says what it is for — which is the moment
to notice it is a filename. `concepts`, `tags`, `subject` and
`scaled_by` gained charset patterns; `res://x.tscn` is twelve characters
and fitted comfortably inside a 24-character free string.

S18 proved a visual swap cannot move a hitbox: every archetype built
under all six themes must produce byte-identical collision, and the
archetypes must differ from each other so that check cannot pass by
everything being one box. Two different rules, because procedural and
authored geometry fail differently — `_box` derives mesh and collider
from one `size` (so they must AGREE), while an authored scene has a
person on each side (so art must not carry collision at all).

S17's "do not leak hidden scouting information" was ALREADY enforced
where it matters: the bridge does not send item identity for an
unrevealed location (`ScoutedLocation._unrevealed_withholds_identity`),
tested in Python since the v0.4 review. S17 added the client-side half —
the client legitimately knows some item names (a shop-stocked location
is revealed), so a pedestal reading `scout.item_name` without checking
state would spoil exactly the Checks the player paid to learn about —
plus a readability rule: no two AP states may share both their words and
their colour.

S16 found and fixed a real I3/I4 inconsistency: the tower's spiral asked
for a 2.4 m mandatory jump at a 1.0 m rise, where the safe bound is 2.0 m
— the same bound the schema enforces on Epsilon's `platform_path`. The
engine was breaking a rule it imposes. `max_safe_gap` is now EXPORTED to
GDScript as a function, so a builder placing a raised platform can ask
instead of typing a number, and the tower's spacing is derived from it.
The tower suite now measures the built ascent rather than inferring it.

**Open question Q1 (`docs/design-packet-v0.9/OPEN_QUESTIONS.md`) blocks
graybox archetype shells.** Every chamber archetype carries continuous
generator-chosen dimensions and a `.tscn` is a fixed size; for
`platform_path` the schema's `gap_size <= SAFE_BASE_JUMP_GAP` bound is
how I3/I4 are enforced today, and a baked gap escapes it. The connector
grammar half of S15 is done and shipped. Do NOT author archetype shells
before Q1 is answered — doing so silently picks option C.

S14 put a named anchor contract between the Hub's logic and its
geometry: logic asks for `main_portal` or `shop`, `HubAnchors` decides
where that is, from the procedural defaults or from an authored scene's
markers. Adoption is per-anchor, so a graybox Hub can replace the room
one marker at a time. The Echo Lab's gap width is now a documented
constant pinned between `SAFE_BASE_JUMP_GAP` and `JUMP_FLAT_REACH` --
both bounds are silent failures if they break.

S13 routed every chamber through the registry, and every route still
ends at `ChamberBuilders` because every entry is still a declared
placeholder. That is the design: the generator is now the documented last
resort rather than the only path, so an authored shell can replace one at
a time without a flag day. A test pins the placeholder route to produce
exactly what calling the builder directly produces.

S12 landed the alphabet's shape, not the alphabet: everything in
`godot/content/registry/legacy_procedural.json` is `procedural_fallback:
true`, which is the registry stating honestly that it is generated
geometry. That is the correct state — the game is READY TO RECEIVE
authored content, and has none yet.

Conventions fixed by the spec but not yet wired (each marked "Not wired
yet" in `ART_ASSET_SPEC.md`, and each is a later stage's job, not debt):
material slot names → themed materials (S19), animation clip names →
interactable contracts (S17), manifest `cost` → a placement budget.

**Heartbeat behaviour: STOP. Every independently implementable stage is
done, and the owner's 2026-08-28 decisions
(`docs/design-packet-v0.9/OWNER_DECISIONS.md`) closed Q1, Q2 and Q3.**

Implemented since: the ending and postgame (D3), authored-shell semantic
authority with Godot measuring physical truth (D1), the asset licence
gate and notices (D2), the tier presentation arc (D4), visual layer
ownership (D6), and the art-lane review gate.

What remains needs a person, not more iteration
(`AUTOMATION_LIMITS.md`):

1. **Authored art** — the art lane is in STYLE LOCK 001-R and its assets
   are NOT approved. A file existing in the tree is not permission:
   `review: pending` entries are refused by the instantiator, and only
   `pass` ships. Do not recreate the art lane's work or choose between
   pending variants.
2. **Final writing** — the completion beat and postgame lines are
   placeholders in the established voice and say so in the source. D3
   fixed the structure and left the words open.
3. **Human playtesting** — every statable invariant has a test. Whether
   the game is GOOD is not among them. **Playtest 1 ran 2026-08-28 and
   ended at the title screen**: MOCK CAMPAIGN crashed on a null `world`,
   the menu panel sat in the bottom-right corner with QUIT off the edge,
   and the Output panel scrolled 81 warnings. All fixed; see below.
4. **`challenge_marker`** — deliberately deferred. The hook stays
   dormant and is not removed; a test refuses anything depending on it.
5. **Project code licensing** — separate from asset intake, and not
   decided.

## PLAYTEST HANDOFF READY — the 3A/3B checkpoint, 2026-09-11

**`docs/PLAYTEST_3AB_HANDOFF.md`** is the owner-facing handoff: where to
run it, prerequisites, exact commands for `none`, `rail` and `launch`,
controls, and a what-to-try list. **Play `96c450e`** -- game code and
assets are untouched by the handoff, which is documentation only.

**Vera's audit** (`docs/audit/2026-09-10-3ab-integration-audit.md` @
`a83a8a5`) found **no blocker**. A1 and A2 supported; A4 supported as the
Road words it. Three of the Production report's claims were stronger than
their evidence and are corrected in the handoff §6: the walk-in test
proves CROSSING and never waits for a landing; 34.3 m is DISPLACEMENT and
the authored curve is ~83.04 m; and the basin floor runs unbroken beneath
the rail, so the rail changes the route (which is what A4 asks) rather
than being the only way there.

**One stored Zone for all three modes**, guaranteed by a shared
`--save-dir` and verified: launch 1 generates once, launches 2 and 3
generate zero times and read back the same `zone_001` -- 23 chambers,
`shell_span_basin` plus six alternating corners, id `a9e649315285bdf3`.
The offline provider, not the showcase.

**Follow-ups logged, none done here and none blocking:** F-1 the Yard
join (its 26 m entry inset lets a connecting corridor intersect solid
wall; the area budget excludes the Yard today but that is a side effect,
not a placement guarantee, and the budget binds only the OFFLINE
generator -- a live provider is merely told about it); F-2 the missing
`is_on_floor()` assertion; F-3 the ground probe that samples 6.9 m off
the ride; F-4 INT-3's stress result being narrower than it reads.

**Not claimed:** full-run completion, the owner's own judgment of how it
plays, and Road criteria A3 and A5-A8 -- each still needs its own
evidence. This is a checkpoint.

## 3A/3B INTEGRATION CLOSED — an authored room a player rides, 2026-09-11

**CURRENT STATE.** Report:
`docs/reports/2026-09-11-3ab-integration.md`. Head before: `67277aa`.

**DONE.** A Zone the generator produced, loaded the ordinary way, holds an
authored room that carries movement offers. Zone 1 composes **7 of 23
chambers** from authored shells (`shell_span_basin` plus six alternating
corner shells); a player walks into it from outside and lands on its
floor, and its authored rail carries them **34.3 m along an 83 m path**
over ground that has none -- from the same start in `none`, the same push
ends 14.8 m away. Provider: **offline** (the deterministic fallback), no
live model call. Census on the generated Zone: declared 6, judged 5,
accepted 5, selected/built 1 in `rail` and in `launch`, 0 in `none`.

**THE OWNER RULING OF 2026-09-11.** An approved shell's geometry informs
the chamber being generated: the generator picks from the request's
catalog and DERIVES the chamber's dimensions from the shell, and the
shared rule holds the two to an equality. The one-sided pair it replaces
could not express that -- "no bigger than the chamber" refused every arena
shell outright. `ArenaChamber`'s field bounds are now a sanity ceiling;
the builder's 10-28 m range is enforced on rooms that name NO shell.

**Placement succeeds or says so.** `ZoneBuilder` plans a route (up to two
corners, connectors and the exit room all checked, its own pieces
included) and, when none exists, returns `{"failed": ...}` and attaches
nothing rather than laying a room on top of another. Measured: 120 copies
of the largest approved arena route with zero clashes; a chain whose
corridors all turn the same way is refused.

**Compatibility is 21 shared cases** in
`godot/tests/fixtures/shell_rule_cases.json`, executed by both languages,
clause for clause. A comparison changed on one side fails them even if
every field name stays -- which is what the field-name check could not
see.

**Digests:** played Zone `ab57d275eea29018` -> `a9e649315285bdf3`;
baseline `c1131ac29931cc68` -> `57e8baf561e38083`. 23 rooms, 15 Checks, 35
enemies unchanged; content value 922 -> 908, inside the band, because
rooms now have their shells' dimensions. Byte-identity outside `shell_id`
no longer holds and should not.

**CORRECTION.** 3B's "blocked on Art -- no arena shell fits" is
SUPERSEDED: the chamber adopts the shell, so the existing twelve compose
arenas today. What remains Art-side is only that no shell declares
`provides_elevation`, so a chamber with a band takes the procedural
builder; the field exists and needs no code change to take effect.

**Bounded by `AUTHORED_AREA_BUDGET` (4000 m2)** -- and its reason is
SCALE, not routing and not audit cost (both were measured and wrong).
Preferring authored everywhere multiplies a Zone's floor by ~10 with the
same content in it; how long a Zone should take is an owner decision.

**Gates:** Python 1144/0; 18 Godot suites exit 0; packet gate clean.

## STAGE 3B — authored rooms in a generated Zone, 2026-09-10

**CURRENT STATE.** `docs/ROAD_TO_PLAYABLE_0_3.md` is the frozen authority.
Report: `docs/reports/2026-09-10-playtest3b-authored-composition.md`.

**DONE.** Approved authored shells reach a played Zone through ordinary
generation -- selected by the offline generator from the request's own
catalog, judged by the shared rule, stored, and built by the runtime.
**Zone 1 composes 6 of 23 chambers from authored shells** (both corner
variants), and every one builds the authored scene. `--movement-package`
now reaches ordinary Zones, no `--playtest3a` required. The showcase is
unchanged and remains a regression fixture.

**Digests moved, content did not.** Played Zone `6e8d83d0f3ec088b` ->
`ab57d275eea29018`; baseline `5a7cfdc03da0e59b` -> `c1131ac29931cc68`.
Machine-checked on all three baseline Zones: with `shell_id` removed the
new and preserved Zones are byte-identical and every measurement matches
(23 rooms, 15 Checks, 922/912/913 value, 35/26/32 enemies). The pre-3B
baseline is kept verbatim at `docs/baselines/playtest_2_5.pre_3b.json`.

**ONE compatibility rule, mirrored.** `shells.rule_errors` (Python) and
`ContentInstantiator._misfit` (GDScript) judge `semantic_tags`, `size`,
`provides_elevation` and `fits_floors`. Godot previously checked
`fits_floors` alone. A parity test fails if a clause is added to one side
only. `shells.offer_of` is the single definition of the shell arguments a
request carries -- used by the acceptance path, the generator's
self-check, preflight, the archive replayer, the baseline fixture and the
tests, because the self-check being held to different rules than its
caller silently changed the played Zone's content.

**BLOCKED ON ART (SUPERSEDED 2026-09-11).** This said no approved shell
could build an arena, because every arena shell is 2-5x the size of any
arena the generator produces. The owner ruled instead that the chamber
adopts the shell's geometry, so the existing shells compose arenas as they
are. Only the elevation-band half stands: no shell declares
`provides_elevation`, so a chamber with a band takes the procedural
builder.

**Deliberately not attempted:** having the generator adopt a selected
shell's fixed dimensions as the chamber's. Probably the right long-term
design; it changes every downstream number and is an owner decision.

**Three defects found in code 3B did not touch,** all fixed: an authored
room's single merged mesh was read as one room-filling solid (the
`ROOM_SCALE_SOLID` filter was switched off by the same flag that enables
hull reading), so 22 activity elements were solved onto nothing; the
builder reserved the Check's space in a local array the composer never
saw; and a room that turned the chain could be followed by a corner piece
turning it again, folding rooms into each other.

**Gates:** Python 1142/0; 18 Godot suites exit 0; packet gate clean.
The production Epsilon prompt now states the catalog and every
compatibility clause; it had never mentioned `room_shells` at all.

## STAGE 3A — a player rides an authored rail, 2026-09-09

**CURRENT STATE.** `docs/ROAD_TO_PLAYABLE_0_3.md` is the frozen authority;
this is where 3A left the tree.

**DONE.** A real `Player` catches, rides and leaves an authored rail, and is
thrown by an authored launch pad whose **closest approach to its authored aim
is 0.20 m and whose landing is 1.03 m from it** -- two metrics, one flight,
both inside the authored 3.5 m landing radius -- in a Zone the real runtime
built from the four approved Wave-1 rooms. Operator control: `--playtest3a`
plus `--movement-package=none|rail|launch`. `make godot-playtest3a`.

**THREE PHASES: VALIDATE, SELECT, CONSTRUCT.** Every room is measured before
anything is chosen, and everything is chosen before anything is built --
measured by the runtime as `judged_before_first_build`, which is 4 in the
three-phase lifecycle and 1 in a per-room one. Selection names offers BY
IDENTITY (`chamber|kind|offer`, sorted), so construction is never told a kind
and can no longer build "everything that matches". Census, seven terms:
declared 24, judged 20 (a launch PAIR is one verdict over two authored
points), accepted 20, selected 0/4/4, built 0/4/4, declined 0, refused 0. The
12 accepted grapple points are never selected and construct zero nodes.

**THE SHOWCASE IS SCAFFOLDING (R2).** It names its four `shell_id` values by
hand. **A1 and A2 are NOT satisfied** — an ordinary generated Zone still
contains zero authored rooms. **A4 is mechanically proven and not yet closed**:
it must be re-proven through the normal played-Zone path after 3B.

**THE LAUNCH-AIR RULING, SETTLED 2026-09-09.** `LaunchSolver` solves a
ballistic arc; the airborne walk solve lerped horizontal velocity toward the
input at `AIR_CONTROL`, keeping 3.7e-7 of it over the hall pad's 1.43 s
ascent -- measured as "rose 24.21 m, travelled 0.00 m, landed back on the pad".
Every authored launch was a bounce. Owner ruling: **protect the launch, do not
lock the player.** Three behaviours, kept distinct: the BALLISTIC CARRIER
(the pad's validated horizontal velocity, stored apart from `velocity` and
never touched by the airborne lerp); a BOUNDED PLAYER CORRECTION layered on
top, capped at `Constants.LAUNCH_CORRECTION_SPEED` = **2.0 m/s, PROVISIONAL**,
whose final feel is Playtest 3's; and ORDINARY MOVEMENT, unchanged and resumed
the instant the arc ends.

**THE CARRIER MAY NOT BE CANCELLED.** Clamping the RESULT at zero prevented
reversal and still permitted cancellation -- a 1 m/s carrier opposed by 2 m/s
stopped moving forward while the carrier sat privately stored. The correction
is now DECOMPOSED against the authored axis before it is applied and the
opposing half removed: along-axis correction may only be positive, lateral is
free, so the applied axial speed is never below the carrier's own. Measured on
the 1.0 m/s slow-arc fixture: no input 1.883 m forward, full opposing input
1.900 m, applied axial never 0.0001 m/s under the carrier in either.

**AND A DEFECT IT UNCOVERED:** `is_on_floor()` is the previous frame's answer
and a pad fires a player STANDING on it, so the arc was ended before it rose --
every launch walked onto rather than fallen onto lost its carrier. Only a
landing ends the arc now, and `_launch_flight` is the single authority for
whether it is running. State clears on landing, rail, death, respawn and
`set_spawn`. **The regression that would have caught it now exists**:
`_test_a_player_walks_onto_a_pad_and_is_launched` settles a fresh player on
real floor 3.00 m from the hall's `launch_basin`, walks it on with ordinary
input, and requires the arc to survive the stale flag -- 24.21 m up and 14.53 m
forward, versus 24.21 m up and 0.00 m forward with the defect restored.

**SELECTION CARDINALITY: NO CAP** (owner ruling, 2026-09-10, superseding an
earlier exactly-one-per-Zone instruction). The harness selects ALL accepted
offers of the chosen mode, sorted by `chamber|kind|offer`. What is load-bearing
is the shape, not the count: pure validation -> pure selection -> exact-identity
construction, and construction may never expand the selection. This settles the
temporary 3A harness only, not the shipped package-selection design.

**THE `none` RESULT IS A SOLVABILITY AUDIT, NOT A COMPLETION.** 50 mandatory
endpoints, 0 without ground, zero offer geometry -- that is the authored
mandatory-route audit staying clean without offers. **A6 remains open**: no
end-to-end player completion of the showcase was performed or is claimed.

**NEXT IS 3B AND NOTHING ELSE (R4).** Epsilon must emit authored `shell_id`
values through the real path. Nothing unrelated goes between them; Wave 2 and
Theme Packs stay off the Playable 0.3 critical path.

## WAVE 1 COMPLETE — all twelve room shells pass, 2026-09-04

**CURRENT STATE. Nothing in this section is outstanding.**

The owner promoted the four Wave-1 shells at Art `ab74f5e`; Production
integrated the generated mirrors from Art `7ecd3fe`. Owner form verdict,
Production certification (`7e13f44`) and the independent audit (`f97545f`)
are all complete, and no review gate remains for any room shell.

**THE APPROVED AUTHORED CATALOG IS TWELVE.**

| chamber type | count | ids |
| --- | --- | --- |
| `arena` | 3 | `shell_hall_transit`, `shell_span_basin`, `shell_yard_gantry` |
| `tower` | 4 | `shell_plenum_helix`, `shell_tower_collapsed`, `shell_tower_gantry`, `shell_tower_spiral` |
| `corridor` | 2 | `shell_corner_left`, `shell_corner_right` |
| `treasure_room` | 3 | `shell_treasure_cache`, `shell_treasure_coffer`, `shell_treasure_vault` |

Wave 1 added the whole `arena` row plus `shell_plenum_helix`; the corridor,
tower and treasure-room entries the P2 review approved are untouched. The
registry is 18 `pass` / 3 `pending`, and the three pending are the
projectile substitutions, deliberately held as the standing proof that
per-entry review is a kill switch in both directions.

**PROMOTION MADE THEM SELECTABLE AND NOTHING ELSE.** The `7e13f44` ruling
holds: `OfferBinding.validate` is pure, Zone validation constructs zero
rails and zero launch pads, and no shipped path builds an authored offer.
The four promoted rooms measure `structural=0 measured=0`, declare 24
offers, produce 20 judgments and 0 declines, and mandatory routes work with
zero offer geometry. Promotion did not activate a single movement offer.

**RESOLVED, so that nothing below is read as current:** the plenum's
annular collar (twelve convex ring sectors per collar, holes physically
open, volume and topology audited, zero non-convex collider nodes in any
shell); the absent canonical real-geometry query (`SpaceProbe`, with the
2 m stride deleted rather than widened); and launch-source radius
semantics (`position` is the canonical foot-contact origin, `radius` is
the reservation the mechanism must fit inside — written into
`schemas/content.py`). Earlier dated sections that list any of these as
open are historical and are marked superseded in place.

**WAVE 2 IS UNSTARTED.** No Wave-2 room exists, is authored, or is planned
in code.

**THE NEXT MILESTONE IS 3A + 3B, JOINTLY** -- frozen in
`docs/ROAD_TO_PLAYABLE_0_3.md`, which is the acceptance contract for the
Playable 0.3 product milestone and takes precedence over any stage order
implied elsewhere in this file.

*3A, live movement integration:* no shipped consumer builds an authored
rail or launch pad in a played Zone, so no player has ridden one.

*3B, authored composition:* **no authored room has ever appeared in a
played Zone.** All 23 chambers of the played Zone carry `shell_id: null`,
and `SHELL_FOR_TYPE` maps every chamber type to a `*_proc` id, so every
room a player walks through is procedural. The reading side is complete --
`shell_id` is on the schema, refused if unoffered, and resolved by
`ContentInstantiator` -- but nothing writes it. Twelve approved shells are
selectable in principle and selected by nobody.

They are joint-first because neither is meaningful alone: a real Zone has
no authored rooms and therefore no authored offers, so 3A has nothing in a
real Zone to bind to. Room Wave 2 is OFF the Playable 0.3 critical path.
Neither blocks any room shell.

## WAVE-1 PRE-PROMOTION GUARD CLOSURE — landed 2026-09-03

The four Wave-1 rooms are **promotion-ready and still `review: pending`**.
Nothing was promoted; that is the owner's call.

**Art sync `466fd4e`** (mirrored, no Art branch history merged): one value
in `godot/content/registry/authored_art.json` —
`shell_yard_gantry / launch_west` `(-28.0, 0.5, 26.0) → (-28.0, 0.0, 26.0)`.
Its x, z, 3.0 radius, `launch_catwalk` target, and every other field of the
Yard entry are byte-identical. Art's head has since moved to `f2b920a`
(a report only).

**Six audit findings closed** (independent audit `f97545f`):

* **F-1 — a launch endpoint is a CONTACT point.** `LaunchSolver` asked
  `ground_below(..., MAX_VERTICAL_STEP)` for both endpoints: a metre of
  permitted daylight under a point `content.py` calls the foot-contact
  centre. Replaced with `LaunchSolver.off_surface`, which compares the
  declared world height against the height the probe actually hits and
  allows only `SpaceProbe.CONTACT_EPS`. Body-fit checks are unchanged and
  independent.
* **F-2 — the four repaired Art launch positions are a standing fixture.**
  `REPAIRED_LAUNCHES` puts each old value back into the room the art lane
  shipped and requires its specific physical refusal, including the
  plenum landing that sat 4.0 m inside `pl_machine`.
* **F-3 — order independence is a behavioural test.** A verdict on one
  offer must not depend on which other offers were asked about, in either
  request order or manifest order, and pure validation must add zero
  nodes.
* **F-4 — VALIDATION MUST NOT CONSTRUCT GAMEPLAY (owner ruling).**
  `MovementPackage` now has two entry points: `judge` reports
  `accepted / declined / refused` and builds nothing; `consume` builds and
  reports `built`. `OfferBinding.validate` is the pure one and is what
  `ZoneController` calls; `OfferBinding.construct` is the explicit one and
  **nothing shipped calls it**. A second construction into one root is
  refused by name. Nothing is called "built" unless a node was made, so a
  grapple point is accepted and never built.
* **F-5 — the two extra Hall colliders are identified by class,** and
  doing so corrected the previous report: both are `DestructibleCover`
  (3 cover sockets, one dropped for landing on occupied space), not "a
  cover and an activity element". Zero `ReactiveBarrel`, zero
  `ActivityElement`, zero `Player`.
* **F-6 — test counts are quoted with their environment.** This container
  (`make setup` complete) collects **1140, all passing, 627 subtests**.
  The audit's 1100/1094+6 reconciles exactly: without an Archipelago
  checkout the suite is 1103 (1098 + 5 skips), and without `anthropic`
  too it is 1100.

**Offer census, two scopes, both named.** DECLARED 24 (6 per room);
JUDGED 20 (a launch pair is one verdict measuring two authored points);
CONSTRUCTED 8 (4 rails + 4 pads; 12 grapple points construct nothing);
DECLINED 0.

**Recertified:** 12/12 shells structural 0 / measured 0; 17/17 Godot
suites exit 0; Python 1140/0/0; packet gate clean; `make baseline`
byte-identical; played Zone `6e8d83d0f3ec088b` unchanged (23 rooms,
15 Checks, 922 points, 35 enemies); 14 `pass` / 7 `pending` review states
unchanged.

**Guards proven by sabotage, not by inspection.** Widening the contact
tolerance back to a step: 11 red. Putting the repaired value in the F-2
fixture: red. Recombining judging with construction: 11 red, including
"six pure validations changed the hall from 174 nodes to 224". Making
`validate` return `consume` again: 17 red. Dropping the once-per-root
guard: red, and the second construction declined both offers against
beams the first one built.

## What playtest 2 taught

The game is playable end to end: Hub, portal, Zone, Checks claimed, a
Check sent to another slot. Everything below was found by a human in
about an hour, and every one of them had a green suite over it.

The pattern, stated once because it recurred all day: **these bugs are
correct as state, as geometry and as protocol, and wrong on screen.**
A backwards sign, a panel whose rect is off-screen, a room with no
ceiling, a fixture inside a slab — the bounds Dictionary is right, the
socket is in the right place, the snapshot validates. Nothing that
asserted on data could see any of it. What found them was standing
somewhere and looking, so the suites now do that: `godot-legible` builds
the Hub and reads its walls, `godot-boot` opens each panel and measures
it, `godot-test` stands inside each chamber and fires rays outward.

Three traps worth remembering, each caught by sabotage rather than by
review:

- A per-site fix leaves the others. `PRESET_CENTER` was wrong in SIX
  places; fixing the title screen for playtest 1 left five.
- A suite can pass on borrowed geometry. Every chamber was built at the
  origin, so they overlapped, and deleting `platform_path`'s ceiling
  failed the ARENA. Isolate before asserting.
- Fixing one half by breaking the other. Seeding the fallback per-run
  ends the sameness AND ends reproducibility; both halves are pinned.

**The fallback provider is the offline fixture.** It is what a player
with no `ANTHROPIC_API_KEY` gets, it is what the integration run plays,
and it was one hardcoded room list — so four Zones in a row were the same
Zone. It now varies deterministically by zone index. Real variety is the
Claude provider composing from the vocabulary; this is only about making
a keyless campaign bearable.

**Zone LENGTH: decided, implemented, NOT yet proven.** The owner's
CAMPAIGN SCALE brief (2026-08-28) answered the pacing question and
`docs/design-packet-v0.9/CAMPAIGN_SCALE.md` is the normative spec.
Defaults: `location_count: 450`, `zone_target_checks: 15`,
`zone_budget: 1000`, all exposed in YAML over bounded ranges
(30..600 / 1..30 / 200..2000). Every stage CS0-CS10 is implemented.

Read `CAMPAIGN_SCALE.md` before touching any of it. The three rules that
are load bearing and easy to break:

- **Epsilon does not declare its own score.** The engine computes
  `room_value` from what a room contains (`bridge/.../content_value.py`).
  A provider claiming a number is a provider grading its own homework.
- **Checks do not count as content.** `CHECK_VALUE = 0`. A Zone's length
  comes from what is in it, so the budget buys ROOMS, and a Zone with one
  Check and a thousand points is a long level rather than one big room.
- **Per-campaign config is truth, and the SAVE wins.** A run keeps the
  scale it was created with. A seed with no `campaign_scale` is a
  PROTOTYPE campaign (30 locations), never the current default —
  reinterpreting it would strand every Check it has.

## ART INTEGRATION — five engine contracts landed 2026-08-28

`docs/ART_INTEGRATION.md` is the index of every engine contract the art
lane consumes. Read it before touching anything the art branch depends
on. Summary of what is now unblocked, and what is not:

| Art req | Contract | State |
|---|---|---|
| 7 | `ENEMY_ENVELOPES` — ten roles, named fields, floor/flying explicit | **cleared** |
| 14 | `telegraph_started/finished`, `TelegraphOrigin`, `telegraph_progress()` | **cleared for the brute** |
| 15 | `AFFORDANCE_SIGNAL` — one identity for all seven affordances | **cleared** |
| 16 | `rail_ride_path()` / `build_rail_along()` — one authoritative polyline | **cleared** |
| 4 | `HubAnchors.epsilon_bay()` / `intruders()` — the bay is reserved | **cleared** |
| 19 | Enclosed by default; the tower is in the seal suite now | **cleared** |
| 20 | Two hazard-orange navigation markers removed, budget pinned at 2 | **cleared** |
| 3a | `ContentInstantiator.light_housing(theme)` | **cleared** |
| 5 | `ClusterFootprint` + `cluster_placement_errors()`, registry-enforced | **cleared** |
| Tier 7 | `shells.shell_catalog()` → request → validator → instantiator | **cleared** |
| 13 | `ProjectileSilhouette` — straight / falling / lobbed, by SHAPE | **cleared** |
| 11 | `RewardObject.state_profile()` — LOCKED and CONFIRMED are different FORMS | **cleared** |

**Three things they exposed, each worth remembering:**

- **`scale` on a CharacterBody3D scales its collider.** The brute's
  windup grew its own hitbox 12% and the hit flinch shrank it to 88%.
  Presentation now lives under a `Visual` container and structurally
  cannot move a collider.
- **The room-shell chain had three broken links and every link's own
  test passed.** `shell_id` was carried, validated and ignored, and
  nothing ever populated `legal_shell_ids`. A contract nothing connects
  is not a contract.
- **`make godot-<suite>` printing "TESTS OK" does not mean it passed.**
  The Makefile guards also fail on a raised runtime error. Sweep by EXIT
  CODE; a grep for the OK line hid a red suite for two commits.

**Two more, landed 2026-08-29, and both are the same lesson:** a state
the engine knows and the player cannot see is not a state the player has.

- **Requirement 13.** One primitive family flies three ways and looked
  one way — a sphere, scaled 1.5x for a lob. Now `straight`, `falling`
  and `lobbed` are different SHAPES, selected from the shot's own flight
  fields, because colour is not available: an Echo is tinted by the
  source world whose item it reinterprets, so spending hue on behaviour
  would overwrite identity with mechanics and lose both. `blast_radius`
  is tested before `gravity_scale` — a lob is also fully gravity-affected
  and would otherwise read as a falling bolt.
- **Requirement 11.** LOCKED and CONFIRMED were two greys eight percent
  of a shade apart plus a word, and a word is unreadable across a room.
  Now they are an open cradle and a collapsed spent mass. **The invariant
  is NOT that the destination ring exists** — it is that the forms
  differ, measured from geometry, with every state repainted one flat
  colour to prove the material is not what is talking.

Both intake seams exist and **no art-lane meshes were copied.** Register
a `projectile_visual`, or author a cradle, and it is used with no code
change.

**Still blocked, and none of it is engineering's:** telegraphs for melee
and ranged (they have no windup, and adding one changes difficulty —
combat decision); behaviour for the seven enveloped roles (same);
`arch_affordance_socket` (art has not chosen between a visible mount and
floor placement); neutral `concrete_facility` dressing (req 18);
`objective_marker` / `signage_module` navigation language;
`challenge_marker`.

## ECHO SCALE — the log outgrew its consumers, 2026-08-29

Same shape as CS8b, third time now: **the campaign scaled and a consumer
did not.** The interpretation log is complete local truth and stays
complete — nothing here truncates it, discards from it, or changes the
fold. What changed is who is handed all of it.

| Consumer | Was | Now |
|---|---|---|
| `PlayerContext.echoes` (Zone request) | every interpretation ever made | ≤12 examples + a whole-history aggregate |
| `EchoGenerationRequest.existing_echoes` | same, separately | the same projection, same code path |
| `CampaignSnapshot.interpretations` | whole log on every state change | only when it changed |

**The provider view is in `bridge/archipepsi_bridge/echo_projection.py`,
and it is the only one.** Three parts, all deterministic: the complete
folded capability set, an `accumulated_influence` aggregate counted over
the WHOLE log (top-N source games, recurring concepts, tags,
interpretation modes — bounded by the top-N, not by a window), and ≤12
detail examples chosen as the six most recent plus an evenly spaced walk
back through everything before them. The examples are FLAVOUR. Nothing
mechanical is read from them, so a Zone 28 request still knows about a
Zone 2 capability and a Zone 2 influence, which is the point: accumulated
world influence is intentional and a detail window would have thrown it
away. Both provider paths call `history_view()`; there is no second one
to forget. Measured at 449 Echoes: **89,585 → 3,520 characters**
(~22,400 → ~880 tokens), and 20× more history costs 18 characters.

**`derive()` is still not cached, and now says why with numbers.** The
old justification was "the log is at most 30 entries", true of the
prototype and false of a 450-location campaign. Measured: ~8 µs per
interpretation, linear — 0.2 ms at 30, 3.5 ms at 449, 5.0 ms at 600, on
an event-driven path that runs per intent, inside a message that spends
more than that on serialisation. A cache would be a second truth for the
one thing that has to be identical everywhere, bought for nothing.

**Snapshots stop re-sending the lifetime log.** `broadcast_snapshot()`
omits `interpretations` and sets `interpretations_complete: false` when
the log has not changed; the client puts its cached copy back before
anything reads the snapshot, so every consumer still just reads
`interpretations`. Back-compat is the DEFAULT: the flag defaults true, an
elided log is sent empty (never partial — the model refuses), and connect
and `hello` always answer complete, which is the whole correctness
argument. A real 30-Check campaign elides 74 times and the log arrives
gapless.

Two things worth carrying forward:

- **`mechanics` is now the big field, deliberately.** It is 97% of an
  elided late snapshot (~268 KB at 449). It is current derived state
  rather than history, and `CampaignSnapshot` validates `slots` against
  the `mechanics` it is sending — a v0.6 guard that eliding would switch
  off. Eliding it is a real option later; `TestTheFoldIsStillSentWhole`
  records the cost so the choice stays visible.
- **A test that only reads the end state cannot see this bug.** The first
  Godot sabotage — client never reattaches — PASSED, because the last
  snapshot before the driver's assertion happened to carry the log. The
  archive looks short only while it is short. `BridgeClient` now watches
  every snapshot for a log that went backwards within one campaign.

## PLAYTEST 2.5 — the pre-art baseline, ready 2026-08-29

`docs/PLAYTEST_BASELINE.md` is the operator's page: what to run, what it
measures, and the one instruction that matters — **change nothing to
make the numbers better.**

The comparison after authored art is about art only if everything else
held still, so the baseline's job is to hold everything else still and
be loud when it does not. `docs/baselines/playtest_2_5.json` records
three consecutive Zones (request and accepted output, verbatim), four
Echoes, and the campaign scale they were taken at; `make baseline`
regenerates it from source and it is never hand-edited.

Four tripwires, each sabotage-proven:

- the committed baseline no longer matches its generator — the engine
  builds a different Zone than anyone walked;
- a recorded Zone or Echo no longer replays from its own request, or no
  longer validates against today's schemas;
- **the campaign scale moved** — budget, Checks per Zone, location count,
  `CHECK_VALUE`, finale fraction, enemy cap. This is the owner's "do not
  retune" as a test, and it defends the COMPARISON rather than any of
  those numbers;
- someone retuned AND regenerated the baseline to match, which is the
  quiet version of the same thing. The 24-vs-30 Zone pacing figures are
  pinned separately for exactly that case.

Playtime records now stamp the **build** (commit, branch, tree clean or
not), because a measurement that cannot say which side of authored art
it is on cannot be compared to anything. It is handed in by the engine
rather than looked up: `instrumentation.py` imports nothing that could
reach anywhere and touches one file, and `version.build_metadata()`
shells out to git.

## THE ART A/B — CLOSED 2026-08-30, FREEZE LIFTED

**The A/B is decided and the gameplay freeze is lifted.** The result is
`docs/PLAYTEST_2_5_RESULT.md`; measured facts and interpretation are kept
apart there. Owner verdict: control valid, pipeline PASS, fixtures KEEP,
authored projectiles REJECT FOR NOW (reverted at `5f1435f` by moving the
three `projectile_*` registry entries back to `review: "pending"` — the
source art is preserved for redesign, and the art lane must export them
as pending or the next regeneration silently re-enables them), F3
DEFER.

The freeze text below is kept because it says what the freeze was for:

> Between the pre-art human run of Zone 1 and the post-art run of the
> SAME Zone 1, no unrelated runtime, gameplay or protocol optimization
> lands. The authored-art integration is the variable; anything else
> changing at the same time makes the comparison measure two things at
> once and neither cleanly.

Now unfrozen and available to pick up: **the `mechanics` websocket
payload.** It is ~97% of an elided
late snapshot (~268 KB at 449 Echoes), re-sent on every state change,
and it could be elided on exactly the key the Echo log already uses.
Three places say so where someone would trip over them —
`TestTheFoldIsStillSentWhole`, the `interpretations_complete` field
comment, and `docs/PLAYTEST_BASELINE.md`.

## PLAYTEST 2.5 — one double-click, one Zone

`Playtest 2.5 (Windows).bat`. The human plays **Zone 1 only**; Zone 2 is
optional (if Zone 1 looks anomalous, or for a second structural sample),
Zone 3 is not required and stays frozen in the corpus. The A/B uses the
same Zone 1 twice.

The launcher runs `archipepsi_bridge.playtest check`, refuses on drift
without ever repairing it, starts the bridge at the baseline scale,
keeps the run in `playtest-2.5/` away from real saves, and prints and
files the summary when the bridge stops. No pytest, no JSON hunting.
`make playtest-check` / `make playtest-report` are the same code from a
terminal.

**Two artifacts, and they are not the same Zone — this is the thing to
get right.** `docs/baselines/playtest_2_5.json` is a GENERATOR
FINGERPRINT built from fixed synthetic requests; nobody plays it. The
PLAYED Zone is the mock campaign's Zone 1 at the default scale, whose
request comes from the mock seed's own placements — same 23 rooms in the
same order with the same enemy counts, different theme, widths and
features. Printing the corpus Zone's numbers as "what you are about to
play" would have been confidently wrong, and a test now refuses to let
either quietly become the other.

Two things this needed that did not exist:

- **`--mock-scale`.** MOCK CAMPAIGN was the prototype's thirty locations
  and nothing could ask for anything else, so a human "playing the
  baseline" would have walked Zone 1 of a thirty-location campaign. The
  default is unchanged; the launcher passes `default`.
- **A level id on every playtime record** — sixteen characters of the
  Zone's own hash. Two records with the same id walked the same
  generated level, so the post-art run is PROVED to be the same level
  rather than assumed to be.

## What playtest 2.5 taught, 2026-08-29

The human played Zone 1 of the default-scale mock campaign and the
verdict was about CONTENT, not correctness: 23 rooms, 921 content
points, 32 activities across 19 rooms, and "nothing to do except shoot a
couple enemies or jump up a path". That indictment is the subject of
`docs/design-packet-v0.10/` and is NOT a bug list.

The bugs it did find are fixed, and three of the four are one shape:
**a guard inherits the blind spot of the fix it was built to protect.**

- Encounter timing was cancelled by `note_death()` and never scoped to a
  chamber, so 9 of 10 fights went untimed.
- The Hub described a thirty-Check game to a 450-Check player: the board
  and the denominators were pinned to the prototype. Fourth instance of
  "the options scaled and a consumer did not".
- **Zone signage rendered mirrored.** Playtest 1 found this in the Hub,
  it was fixed in the Hub, and the guard was built around the Hub -- so
  the Zone kept the bug through two more playtests.
- **A corridor had no end walls.** The playtest-2 comment names the three
  builders that had no ends; two of them got ends. Test 57 probes from
  the chamber's CENTRE only, so it was green the whole time. The seal
  suite now stands at 81 floor positions and looks four ways, and a
  sabotage proves test 57 cannot see an off-centre hole.

That last one also surfaced a contradiction nothing had ever hit:
`DOOR_WIDTH` 2.4 < `BRUTE_LANE` 2.6, so no doorway in this game has ever
met the lane budget. Resolved as stated design (a doorway is a narrowing
the 1.8 m brute passes with 0.3 a side) and pinned by a test rather than
left implicit.

One correction worth keeping: I reported that 24 of 25 `Label3D` sites
overflow their panels. **That was wrong on both mechanism and fact** --
`width` defaults to 500 and does nothing anyway because `autowrap_mode`
defaults OFF, and measurement shows every Hub sign fits. There was
nothing to fix, so `godot-legible` now measures the margin instead.

## v0.10 RESEARCH — hard progression, delivered 2026-08-29

`docs/design-packet-v0.10/RESEARCH_MEMO.md`. **Architecture D is proven,
not argued**: a disposable patch gated locations behind a capability
event and ran real `Generate.py` -- solo and multiworld generate clean,
and the negative control (same gate, event removed) FAILS generation.
So an unsatisfiable capability gate is a seed-generation error rather
than a dead seed discovered at hour twenty. **Archipelago polices this
for us.** The patch was reverted.

The owner's rule that governs the redesign: the multiworld must be
logically solvable; it is NOT that every room must be solvable with the
starting kit. Zone CLEARED (5 Checks + exit) is not Zone EXHAUSTED (15).

**No structural redesign is implemented and none is authorised.**

---

**OPEN PACING DECISION — recorded 2026-08-28, do NOT act on it.** The
owner spotted that the default campaign's goal becomes AVAILABLE well
before the campaign is finished: `FINALE_REQUIRED_FRACTION = 0.8` needs
360 of 449 Checks, which at 15 per Zone is exactly 24 Zones, against 30
for a 100% clear. At the provisional 40 minutes a Zone that is 16 hours
to the goal and 20 to a full clear.

So **do not quote "~20 hours" as the campaign length** — that is the
clear, not the ending. Both numbers are real and they are four hours
apart.

## Art branch — canonical

The single authoritative art lane is **`claude/archipepsi-art`**, and
**PR #5** (base `claude/archipepsi-build-inzshp`) is its canonical PR —
that base is what keeps the art diff properly scoped.

`claude/archipepsi-art-setup-9qsbss` was a temporary setup branch. It was a
clean linear continuation and has been **fast-forwarded into
`claude/archipepsi-art`** (merge base 649a6cc, no force, no history
rewritten, no commits lost). PR #6, opened from it against `main`, is
**superseded** — it showed the whole stacked project history rather than an
art diff. Do not maintain two active art branches.

## Art batches — state 2026-09-02, with a 2026-09-13 head note

**THE ART LANE IS WAITING ON AN OWNER VERDICT, NOT IDLE-WITH-WORK-TO-DO.**
Do not start work in it on a wake-up. Read this section and stop.

**2026-09-13 — three things another lane may need, from
`docs/art/reports/2026-09-13-presentation-study.md`:**

1. ~~**`shell_yard_gantry`'s two doorways are refused.**~~ **WRONG,
   withdrawn same day.** `shells.is_offerable` *reports*
   `doorways_off_the_body` and returns regardless, because a manifest
   rule cannot see floor and the assembled crossing decides. Art's gate
   now reports the 0.395 m without failing. **No socket repair is
   requested.**
2. ~~**The binder used to prove it is a proposal not wired into the
   game.**~~ **WRONG, withdrawn same day: the runtime binder exists.**
   `ThemeMaterials._material` asks `ThemePack.texture_for` first and
   falls back to `ProcTextures` on null. The art-side binder is deleted.
   What survives is the check nothing else makes — the pixels the GPU
   samples, against the authored PNG, through the real import — run
   against the material Production builds.
3. **Production reads shell sockets by kind and by name**, so a three- or
   four-connection room is readable. **A four-connection asset is still
   not a four-neighbour room in a generated Zone.**
4. **Every opening now declares its own arrival region**, named after its
   socket — Art's half of §11.3. Handoff:
   `docs/art-requests/2026-09-13-capacity-and-arrival-handoff.md`. It
   also corrects the capacity claim for `shell_bay_terminus`, which has
   **no `exit` socket** and is a destination, not a through-room.
5. ~~**Lettering cannot be fixed in UVs.**~~ **WRONG, withdrawn.**
   An authored `.glb` shell keeps the materials Blender baked:
   `ContentInstantiator` performs no material operation at all
   ("material" appears zero times in it), while `chamber_builders.gd`
   names `ThemeMaterials` 46 times. Themed materials are the PROCEDURAL
   path. The UV repair therefore lands, and is proved on both faces of a
   two-sided sign and with the room rotated. **The mirrored stencil is
   still real on the procedural path** — that is a separate, unfiled
   item, not Batch 044's.
6. **"LEAF" IS NOT "DEAD END".** A branch destination in this
   implementation can still host onward branches. Production's
   `dead_ends` is a measured degree (`n == 1` adjacency); Art's
   `dead_end` is a shape tag describing a treatment, and **nothing in
   Production reads it**. Measured: from the Terminus's approach the
   one-neighbour and two-neighbour states are pixel-identical (the mouth
   hides both side openings); from inside, an assigned branch is plainly
   a way on. Evaluate a one-neighbour assignment separately.
7. **`shell_bay_terminus` cannot be composed at all today**, and it is a
   PRODUCER limit, not a door count: `topology.compose_chain` returns
   `edges=()` when any chamber lacks the literal `entry`+`exit` pair, and
   `compose_with_branch` calls it first and returns immediately. So one
   destination room in the list seals every room's doors. A leaf is
   rejected before it can become a leaf. Dess's and Prod's to resolve.

**ALL TWELVE AUTHORED ROOM SHELLS PASS** (owner, 2026-09-04). The eight
P2 shells passed on 2026-09-02 after Production certified them at
`6640d86`; the hall and the three Wave 1 rooms were promoted on
2026-09-04 with owner form approval, Production's technical certification
at `7e13f44` and an independent audit at `f97545f` all agreeing. Nothing
in the pack is `pending` except the three projectile substitutions.

**`pass` DOES NOT MEAN THE MOVEMENT OFFERS ARE LIVE.** The four large
rooms carry `rail_route`, `launch_source`/`launch_target` and
`grapple_point` declarations reserved against a player-facing
movement-package consumer that is **not implemented**. A passing shell
can be placed, entered and walked end to end today; nobody can ride its
rail. Report:
`docs/art/reports/2026-09-04-wave1-promotion.md`.

**THE LARGE ROOM LIBRARY IS APPROVED AND WAVE 1 IS BUILT.** The owner
approved the ten-room slate (`docs/art/LARGE_ROOM_SLATE.md`) and the
3 / 4 / 3 wave plan. Wave 1 -- `shell_plenum_helix` (20x72x20, a 129 m
rail), `shell_yard_gantry` (84x16x52) and `shell_span_basin` (30x22x90)
-- is authored, verified and, since 2026-09-04, `review: "pass"`.
Package: `docs/art/review/wave1/`. **Wave 2 is four rooms and does NOT
start on a wake-up.** The Wave 1 verdict it was waiting on has arrived
and is a promotion, not an instruction to continue: Wave 2 needs its own
owner brief.

**`shell_hall_transit` is repaired** against Production's final walk law
at `b37fe07`: two of its three climbs were built backwards, and all three
were single wedges the import-time flood could not see through.
`shell_tower_spiral`'s `platform_8_to_deck` is a `gap`, from Production's
own probe.

**PHYSICAL-TRUTH REPAIR LANDED (2026-09-03).** The seven items of the
plenum/hall/span brief are done and measured:

* the three plenum collars ship as **12 convex sectors each** (117 -> 150
  colliders, same 1656 triangles). `roomcollision.assert_convex` now
  refuses ANY non-convex collider at build time, in all six builders
  that author collision — a
  `-convcolonly` node imports as the convex HULL of its vertices, so an
  annulus was shipping as a filled disc.
* every collar destination is on the band and none on the machine axis:
  three `landing_N_to_collar_K` endpoints, three `enemy_anchors`, the
  `check_anchor`, the `reward` and the launch target, all through one
  `_collar_point`, which now shares `_collar_axis` with the bridge that
  builds the spur.
* **`shell_plenum_helix`'s launch serves the LOW collar now, not the
  middle one.** Measured over 4537 floor stances on a 0.25 m grid: the
  top collar is reachable from none, the middle from five, the low from
  141. The reward stays on the middle collar.
* the plenum rail, the hall rail and the span rail were all rerouted off
  geometry their BAKED curve was inside; the plenum's grapple_1 moved a
  metre inward for its swing room.

New gates, both in `tools/verify_content_pack.sh`:
`tools/content/measure_offers.py` measures every declared rail, launch
and grapple against the shipped collider triangles, and
`tools/content/replay_audited.py` replays the pre-repair pack out of git
and FAILS unless every audited finding still comes back.
`tools/content/sabotage_offers.py` is their negative-control suite and
runs from `tools/sabotage_checks.sh`.

**AND THE TWO LAUNCH PADS, on the owner's ruling of the same day:** keep
both launches, move both pads the least that clears them. The hall's and
the span's flights each went through the platform they land on — 0.08 m
at first contact, 0.643 m and 0.806 m at their worst. An arc's shape is
fixed by its two heights, so neither could be dodged along z: the hall's
pad goes **3.00 m west to (9, 0, 18)** and the span's **7.02 m to
(−7, 0, 45)**, out from under the deck, and onto the basin's face. Both
are the nearest round metre that leaves a flying body the 0.325 m a rail
beam must keep. Targets, landings, routes and radii unchanged, and
`measure_offers.RAISED` is empty again. Reports:
`docs/art/reports/2026-09-03-physical-truth-repair.md` and
`docs/art/reports/2026-09-03-launch-pads.md`.

**RESOLVED 2026-09-04 — `launch_source.radius`.** Settled at Production
`833fe80` and guarded at `7e13f44`: `launch_source.position` is the exact
**foot-contact** launch origin, and `radius` reserves space for the
constructed pad — it is **not** a disc of possible ballistic origins. All
four large-room pads are correct as authored. *Superseded history: this
was previously recorded here as an open Production question.*

**RESOLVED — req 40.** `ShellValidator` is kind-aware through
`TraversalLaw`; it no longer applies base-kit jump bounds to continuous
walks or to ramps. Fixed before the Wave 1 promotion, so no room in the
library is refused by it. *Superseded history: this was previously
recorded here as needing Production.*

**THEME PACK: PREPARED AND PROVED, NOT BUILT (2026-09-10).** Two
inspection-only batches, no asset rebuilt and all twelve shells
byte-identical. The role contract is reconciled against
`ARCHIPEPSI_THEME_PACK_SYSTEM_AUTHORITY_20260903.txt`; all 597 shipped
material slots classify (0 canonical, 597 legacy, 0 unknown) and Godot
preserves every name exactly, so a binder can recover the role at runtime
with no manifest field; and one shipped room has been shown wearing two
themes **at once**, by per-surface override, with the shared mesh
unchanged and the collision digest identical. Reports:
`docs/art/reports/2026-09-10-theme-pack-preparation.md` and
`docs/art/reports/2026-09-10-batch041-two-themes.md`.

**What is left is PRODUCTION's, and there are four of them:** a ruling on
`hazard` (the authority makes it a required per-theme role; the art lane's
standing rule is that hazard is a universal colour no theme may re-tint,
and no theme has a hazard texture), the `material mode` and
`protected_materials` fields the registry entry schema does not have,
somewhere for the 37-PNG theme texture set to ship, and the binder itself.
**Do not start canonical `<role>` renaming on a wake-up** — it would
change all twelve shells' bytes to buy tidiness a legacy-aware binder does
not need.

**ECMS GLYPH IS AVAILABLE AND HAS BEEN RUN (2026-09-10).**
`cadykaya/ECMS-GLYPH` at **`727129e1`** on `main` — the implementation
merge. An earlier note in this lane read the frozen authority snapshot
`0cf872d` and concluded Glyph was "a specification, not a program"; that is
**superseded**, and the difference was the branch, not the project. `npm ci`
and `npm run build` are clean on Node 22, the worked example runs, and one
128 × 128 `concrete_facility` wall has been authored through it on the house
palette and structure, then bound onto real room geometry through Batch
041's override path. **It ships nowhere** and no approved asset changed.
Report: `docs/art/reports/2026-09-10-glyph-first-texture.md`.

Two things a later agent should not have to rediscover. **Glyph's indexed
colour has no partial mix**, and the house look is built from partial mixes,
so a Glyph-authored surface comes out crisper than `materials.py`'s — a
direction question, not a defect. And **the owner has settled `hazard`**:
every pack must resolve the role, but may resolve it to the same shared
universal material; separate theme-coloured hazard textures are not
required.

**001–022 PASS. 031–037 PASS** (031; 032 *with boundary*; 033 *audit, build
nothing*; 034 *the visual principle*; 035-R; 036-R; 037-R *with a documented
caveat*; boss audit *accepted, build nothing*).

**PENDING owner review: 023–030 only.** Nothing about them is actionable
without a verdict.

### The boundary — do NOT start the next art system

Two systems are being designed by the owner and a design collaborator, each
arriving as its own owner-authored brief:

1. **Modular Echo visual construction / kitbash system**
2. **Diegetic in-world interface system**

Until those briefs exist:

- **No Batch 038.**
- **Do not design or mass-produce Echo visual parts.** Requirement 32 is
  *only* the architectural seam — the Echo family must be visible through a
  swappable / composable `EchoPart` seam. The three built ranged / melee /
  grapple forms are **proof-of-seam only**, and are explicitly not approval
  of seven fixed family models, a final attachment grammar, a final part
  taxonomy, runtime composition rules, family silhouette rules, or
  provenance / source influence rules.
- **Do not expand the interaction kit** into menus, terminals, Archive UI,
  Forge UI, Zone-selection UI, or any other large physical interface.
- **No heartbeat, no polling, no autonomous expansion.**

### Rules locked by the post-030 review, worth carrying forward

- **If a distinction must survive gameplay distance, the distinguishing
  feature must affect object-scale SILHOUETTE.** Surface is what distance
  takes away first.
- Three channels on any operable object: **silhouette/structure** = what
  kind of thing; **interaction hardware** = yes this one is operable;
  **state treatment** = what it is doing now. The plate/bezel may stay as
  standardized hardware only while it is not the sole source of truth and
  does not rely on hue alone.
- Secrets: **no universal secret colour**; a cue is a **deviation from a
  learned environmental pattern**; a smaller reliable vocabulary beats a
  padded one. **Stop revising secrets until real in-game Zone testing.**
- Enemy surface: **plate** = proud slab / impact-bearing; **mechanism** =
  recessed, ribbed, rodded exposed function. No role colours.
- Accepted caveat: brute vs scuttler surface identity is weak. **Do not
  alter the approved scuttler silhouette or body to force a stronger
  surface distinction** — revisit only with gameplay evidence.

**Still blocked, and deliberately not routed around:** requirement 31 —
`ENEMY_ARCHETYPES` is still `("melee", "ranged", "brute")`, so seven roles
have a body, a collider, a telegraph seat and a surface, and no way to be
spawned.

**The art heartbeat is PAUSED** (`trig_01DSWy2dbCpeSefcx2YGS9Ys`, disabled
2026-08-29) under the owner's rule: pause the routine when there is no work,
resume it when there is a task. **Do not re-enable it on an idle lane.** PR
#5 activity still wakes the session directly, so nothing is missed.

Earlier decisions standing: `objective_marker`, `arch_objective_socket`,
`arch_signage_mount` and `arch_affordance_socket` all struck, each because
nothing places them. `arch_vista_socket` still blocked on a contract.
Requirement 23: engine `trim_mat` maps to authored `trim_plain`. The Batch
023 landmark audit was corrected on 2026-08-29 — Production **has** an
authored-content pipeline (`ContentRegistry`, `ContentInstantiator`,
`landmark` as a real L4 category); what is missing is the `.glb` →
`res://content/` scene step, a `landmark_id`, a placement path and a landmark
envelope. Requirement 24, reworded.

## Open decision, deliberately not guessed
`challenge_marker` (§14.2) and its `challenge_timer` readout (§14.1) have a complete bridge half — grantable, recorded, `best_seconds` improves — and no world half, because neither section says where a run starts, what ends it, or what counts as one. `test_stage_tripwires.py::test_the_challenge_marker_still_has_no_challenge` names the decision and comes due when it is made.

It is NOT to be changed yet: both figures are the unmeasured 40-minute
target multiplied out, and retuning a real gate to satisfy a guess is
exactly the mistake. Revisit on the first 1000-budget human playtest
evidence. `CAMPAIGN_SCALE.md` 3 holds the decision record, the
sensitivity table (only 100% reaches 30 Zones, so raising the percentage
alone is not an answer) and the owner's candidate fixes;
`test_campaign_config.py` pins the two numbers apart so they cannot be
quietly conflated again. The playtime log already carries what the
decision needs, so no instrumentation change comes first.

**The 40-minute Zone and the 20-hour campaign are still TARGETS.** They
are arithmetic, not measurements, and must not be described as proven.
CS10 is what can turn them into facts: Godot times each Zone (elapsed,
per-room dwell, deaths, encounter durations) and the bridge joins that to
the values it computed, one JSON line per Zone in `playtime.jsonl` beside
the saves. Local only — no analytics, no upload path, and a test asserts
`instrumentation.py` imports nothing that could reach a network. Read it
with `instrumentation.read_records()` / `summarise()`.

What CS8 turned up is the thing to remember: **the options, the item pool
and the apworld all scaled, and the ENGINE did not.** Scouting,
allocation, the save's Check cap, the goal id in five places, and the
acceptance validator were all still pinned to the prototype's thirty, so
a 450-location campaign scouted the first thirty, played them three at a
time, and ended itself when Check 030 confirmed. Every one of those had a
green suite over it, because the suite ran at prototype scale. The mock
backend now takes a `CampaignConfig` and
`bridge/tests/test_production_scale.py` runs the real engine at 450.

## WAVE 1 MEASURES TRUE, OFFERS INCLUDED — 2026-09-03

Art `468125e` synced: plenum collars decomposed into convex ring wedges,
collar traversal/reward/launch/rail/grapple corrections, hall and span
rail corrections, and both launch pads moved off the platforms they were
flying through. Four mirrored files, byte-identical to Art.

**ALL FOUR LARGE ROOMS: structural=0 measured=0, 5 offers built and 0
declined each.** Twenty offers built plus the four `launch_target`s
validated inside their pairs = **24 measured, 0 refused**, which is
exactly what the Art lane predicted and Production now proves with its
own runtime geometry binding. The plenum's three collar endpoints -- the
Production half of the audit's A-2 handoff, detected here before Art's
repair landed -- are gone.

**A LAUNCH SOURCE IS ONE ORIGIN, NOT A DISC** (owner ruling).
`launch_source.position` is THE canonical foot-contact centre the
constructed launch fires from; `launch_source.radius` is the region
RESERVED for the consuming package to build its mechanism in, and the one
thing it must be big enough for is the pad. `launch_target.position` is
the authored aim and its `radius` is the acceptable LANDING region: where
you leave from is exact, where you arrive is a region. Written into
`schemas/content.py` so it cannot go ambiguous again.

`LaunchPad.launch` derived its velocity from the pad centre and applied
it to whoever was overlapping the trigger, so a player clipping the edge
of a 2.4 m pad flew a trajectory beginning up to 1.2 m from the validated
one. The player is now CAPTURED to the canonical body pose first, and a
canonical origin that cannot hold a body refuses to fire rather than
teleporting somebody into a wall. Sabotaged: without the capture an edge
entry lands 1.63 m off target.

**AN OFFER IS A CLAIM ABOUT THE ROOM, NOT ABOUT OTHER OFFERS.** This pass
found `consume` validating and constructing in one pass, so the rail was
built before the launch was judged and the hall's arc collided with its
own new beam -- a refusal that flipped to a pass on a freshly built room.
The verdict depended on which kind was visited first. Judging is now a
separate phase from building, and nothing is constructed until every
verdict is in.

**71 vs 73 RECONCILED, and they were never the same question.** 71 is the
AUTHORED SHELL COLLIDERS -- the `-convcolonly` twins the importer builds
from the `.glb`, which is what an art-side gate can see. 73 is the
INSTANTIATED CHAMBER COLLIDERS, which additionally includes the two the
COMPOSER placed: a `DestructibleCover` and one activity element. No
duplicates in either scope, nothing importer-invented. Both counts are
now asserted by name, so neither can drift into the other.

The player is also no longer room geometry: a probe that reported "their
body is inside Player" was true and useless.

## AUTHORED LOCAL, PHYSICS WORLD — 2026-09-03

The binding at `50018d1` handed room-local offer coordinates straight to
a world-space `PhysicsDirectSpaceState3D`. `ZoneBuilder` places every
chamber at a nonzero translation and yaws many of them, so those are two
different points -- and **every authored-shell test placed its root at
identity, the one transform where the two frames coincide.** A fixture
at the origin cannot see an origin bug. Owner-reported, confirmed, fixed.

**THE CONTRACT.** Authored offer data and the nodes parented into a room
stay ROOM-LOCAL -- the content contract is local by definition, and
turning it into world coordinates would make a room mean something
different depending on where it was placed. Real-physics queries and
player motion are WORLD. One transform, `root.global_transform`, derived
once per `consume` and threaded to every probe. Diagnostics report the
LOCAL coordinate, because that is the number an artist can find.

**TWO RUNTIME CONSUMERS CARRIED THE SAME MISMATCH**, and both are
corrected. `LaunchPad.solve` used a global source and a room-local
target, so every pad in a placed Zone aimed at a point its room does not
contain; it now solves world body-pose to world body-pose, and the arc
pips come back through the pad's own transform instead of subtracting a
local `position`. `RailRider` compared the player's world position and
velocity against a local `RailPath` and then returned local path
positions as world player positions -- catchable from across the map,
and a teleport on catch. It now brings the player into the room's frame
for the comparison and returns world positions and world velocities, off
ONE authored path and a derived transform.

**A LAUNCH SOURCE IS A PLACE TOO.** Nothing ever checked the pad itself:
the arc skips its own first sample by design, so the one place the source
was looked at was the place it was excluded from. Support and a standing
body pose are now proven at the source as well as the target.

PROVEN AT SEVEN PLACEMENTS -- identity, translated X/Z, translated Y, yaw
90, 180, 270, and a nested transformed parent -- plus a REAL two-chamber
`ZoneBuilder` chain whose second chamber is 90 degrees rotated and away
from the origin, and all four LARGE shells measured at identity and again
at a placed-and-yawed transform. Identical verdicts everywhere.

Three sabotages, each red: leaving the launch target untransformed lands
a placed pad 43.36 m from its aim; returning local rider positions puts
the body at `(0, 3, 4)` where the placed curve is at `(137, 3, -80)`;
querying grapples in local coordinates reports a 60 m room as having no
ground in it.

The verdicts themselves did not move -- the previous pass measured at
identity, where the frames agree -- so `50018d1`'s findings stand and are
now true for a placed room as well. One diagnostic gained a subject: a
floor too close under an anchor names the collider that is too close.

## THE OFFER RULES AND THE GEOMETRY ARE IN THE SAME ROOM — 2026-09-03

Independent audit `802732d`, `docs/audit/2026-09-03-physical-truth-adjudication.md`.
Vera's B-1 in one line: `MovementPackage` had eight call sites, all in
one test file, and every one passed a constant or a half-space predicate
over a bare box. `PhysicsDirectSpaceState3D` never appeared in the file
that called it. The offer rules and the geometry they were written to
judge had never met, and `RoomAudit` does not read `offers` at all.

**`SpaceProbe` is the one canonical real-geometry query.**
`ground_below` (first ground at or below a point, exact reach, no
window), `body_fits` / `stance_fits` (the whole capsule, and the body
above step height), `column_is_clear` / `first_block_point` (swept, not
sampled at the ends), `stand_pose` (`SUPPORT_LIFT`), and `refusal` --
which makes a detached root or a null space an explicit REFUSAL rather
than the clean pass a probe with nowhere to go always returns. `RoomAudit`
and the offer validators now share one implementation of "is that a
crate", so they cannot come to disagree about the same crate.

**The stride is deleted, not tuned.** `_grapples` walked down in 2 m
steps asking a 1.5 m window at each. Two errors, different causes: a
window narrower than the stride leaves a blind band per step, which
refused three real span anchors because the floor at y=0 fell between
the samples at 1.4 and -0.6; and a window reaches past both bounds, which
accepted hang space under `SWING_ROOM` and ground past `GRAPPLE_DROP`.
Widening fixes the first and worsens the second. Now: one measured drop,
compared against both bounds, and a swept hang column.

**A LAUNCH TARGET NAMES THE FLOOR** (owner ruling). Support is proven at
the authored point, the body pose is derived with `stand_pose`, the
capsule is proven at that pose, and the arc is flown between poses.
Sabotaged: without the lift, a landing on a clean deck face is refused
"96% along its own arc" -- the three false findings the audit predicted a
new caller would manufacture on its first run.

**A destination must hold a player.** Traversal endpoints, optional ones
included, are now capsule-standable rather than merely above a ray hit.
Calibrated twice on the way: the full capsule at the marker refused every
endpoint beside a riser, and re-reading `TraversalLaw`'s own lesson gave
the body-above-step-height test; then the exact point alone refused the
rubble stones owner ruling C(ii) calls architecture, so the check now
searches the endpoint's neighbourhood exactly as `TraversalLaw._seed`
does. **It still catches what it was added for**: the plenum's three
collar endpoints, `pl_machine` named, without waiting on Art's collar
repair. That is the Production half of the shared A-2 handoff.

**A real production caller.** `OfferBinding` is the post-instantiation
stage, and `ZoneController` calls it one deferred physics frame after the
Zone root enters the tree. `ContentInstantiator` cannot own that moment:
`build_chamber` returns a DETACHED root, so no collider is registered and
`get_world_3d()` is null -- every probe would answer "nothing there".
`MovementPackage.consume` now takes the space itself rather than two
callables, so a lambda cannot be handed to it, and all eight former stub
call sites were rebuilt on real colliders.

REAL-GEOMETRY VERDICTS, first ever recorded:

| room | built | declined |
| --- | --- | --- |
| hall | 3 (all grapples) | rail into `hl_ramp1_tread3`; launch arc into `hl_east_gantry` |
| plenum | 2 grapples | rail into `pl_collar_0`; launch body inside `pl_machine`; `grapple_1` 0.76 m of hang space |
| span | 3 (all grapples) | rail into `sp_pylon_0`; launch arc into `sp_deck` |
| yard | 5 (everything) | none |

The span's three grapples confirm the audit's false-refusal finding. But
**the Hall's and the Span's launch-arc collisions were NEWLY DISCOVERED
here, not corroborations** -- Vera's B-4 isolated the landing-point
CONVENTION and read all three top-face targets as correctly authored,
which they are. What the corrected body-pose arc then found is a
different fact: the arc between two body poses clips `hl_east_gantry` at
38% and `sp_deck` at 29%. Neither appears in the audit. Yard is clean on
offers. Eight approved P2 shells,
hall, span and yard all remain `structural=0 measured=0`; the plenum
carries the three collar endpoints as pending evidence.

TWO CAVEATS, OPEN AT THE TIME AND **BOTH SUPERSEDED** (see WAVE 1
COMPLETE, 2026-09-04): the plenum's collar annuli importing as filled
convex hulls (Art, A-1), and the rail/launch routes that intersect real
geometry in three of four rooms (Art, A-4/B-4). Art `468125e` decomposed
every collar into twelve convex ring sectors and moved the routes; the
independent audit at `f97545f` measured both closed. Nothing here
repaired content.

## EVERY AUTHORED SHELL MEASURES TRUE — 2026-09-03

Art `26a2914` (repair `4441ea5`) synced. The mirrored delta is ONE file,
`registry/authored_art.json`, and eight declared points inside it. No
`.glb`, no `.tscn`, no `SCENE_PLAN.json`, no geometry, no traversal, no
entry connector. Art's independent reproduction agreed with Production's
eleven findings and with which three of them the entry ruling had already
superseded.

The eight points, each moved laterally off the block it was named inside:

* plenum `reward` volume `(0, 29.333, 10)` -> `(5.25, 29.333, 10)`
* yard `cover_0..3` z `16 -> 13.4`, `34 -> 37.1`, `15 -> 12.4`,
  `33 -> 36.6`
* span `cover_0..2` x `-9 -> -12.1`, `8 -> 10.6`, `-7 -> -10.6`

**ALL TWELVE AUTHORED SHELLS NOW MEASURE structural=0 measured=0** — the
eight approved P2 shells, the hall, and all three Wave-1 LARGE rooms.
First time the whole registry has been clean.

PROVEN AUTHORED, not inferred from a quiet census. Each of the three
carries `authored_shell` equal to the id requested, instantiates from its
own `.tscn` (`root.scene_file_path`), and presents exactly the counts its
manifest declares — plenum 20/15, yard 6/5, span 6/5. A procedural arena
produces none of those.

The arrival check is not vacuous either: all three declare a
`player_entry`, all three report `[]`, and moving the plenum's into its
own machine volume produces the finding immediately.

FORM PRESERVED, measured: plenum entry `(0, 68, 0)` / exit `(0, 0, 22)`,
73.60 m of geometry, top-entry and bottom-exit intact. Yard 17.60 m tall,
entered at `(-43, 0, 26)` and left at `(+43, 0, 26)`. Span keeps
`deck_to_basin`, a `drop` from y=14 to y=0, one way. Marker parity 12
scenes / 160 markers / 0 disagreements.

TWO CAVEATS CARRIED FORWARD UNRESOLVED at the time, by instruction.
**BOTH ARE NOW SUPERSEDED** -- see WAVE 1 COMPLETE, 2026-09-04. They are
kept here because the record of what a pass did NOT look at is worth
more than a tidy history:

1. The plenum's annular collar imports as a CONVEX COLLISION DISC. A
   ring whose hole is filled by its own collision hull is a floor where
   the room shows a void, and nothing in this pass looked at it.
   *SUPERSEDED:* Art `468125e` rebuilt each collar as twelve convex ring
   sectors, and `f97545f` verified mesh volume equals the sum of the
   sector hulls and the analytic annulus to 0.0001 m³. Zero non-convex
   collider nodes remain in any of the twelve shells.
2. There is still no canonical real-geometry `supported` caller for
   grapple validation. `MovementPackage` has no production caller at all,
   so the same three hall anchors build or decline depending on whether
   the probe window covers `_grapples`' own 2 m stride.
   *SUPERSEDED:* `SpaceProbe` (`50018d1`) is that one canonical query,
   the 2 m stride was deleted rather than widened, and `OfferBinding` is
   a committed Production caller.

## THE ENTRY IS WHERE THE ROOM SAYS IT IS — 2026-09-03

Owner ruling: `(0, 0, 0)` has no semantic meaning as the universal room
entrance. It was the value every shell happened to have, read by nobody,
and believed by `ZoneBuilder` and `RoomAudit` as though it were a
contract — so three LARGE rooms entered at their top or along their side
measured as having a sealed door in a solid wall, and the message blamed
the geometry for an assumption in the probe.

TWO CONCEPTS, KEPT APART. The **entry connector** (`doorway` socket
`entry`/`end_a`) is the room-to-room attachment transform; it sits on the
envelope and may sit slightly outside it — the yard's is 0.4 m past its
own west wall — so **no standing floor is required under it**. The
**`player_entry` volume** is the interior region the body arrives into,
and that is where capsule safety is proven. `player_entry` had been a
legal kind in `schemas/content.py` since S12 and was read by NOTHING: a
vocabulary word with no consumer, which is how three rooms declared an
arrival region no probe ever looked at.

`ZoneBuilder` now places a room so its entry connector lands on the
previous room's exit, `origin_for(join, yaw, entry)` and
`exit_cursor(origin, yaw, exit)`, both public so a test measures the seam
instead of reimplementing the subtraction. Vertical offset and yaw come
free: both connectors are room-local vectors turned by the room's own
yaw. The legacy fallback is `RoomContract.LEGACY_ENTRY` — named, not
assumed, because the old behaviour was identical AND invisible.

Seven proofs, each sabotage-checked. Reverting the audit to the origin
turns E1/E2 red with the exact old symptom; stubbing the arrival check
turns E5/E6 red; making `origin_for` return the join turns E3/E4/E7 red.

ONE STALE GUARD CORRECTED, not weakened. `movement_driver` pinned the
net-descent ruling by grepping `zone_builder.gd` for the literal
`cursor += _rot(yaw, result["exit_offset"])`. That line is gone, so the
guard pinned the SPELLING rather than the ruling; it now asserts the seam
itself — a room whose exit sits 6 m below its entry moves the chain down.

RESULT. Eight P2 shells unchanged at 0/0. The three entry findings
vanished — plenum 2 -> 1, span 4 -> 3, yard 5 -> 4 — and every declared
`player_entry` passes capsule safety on the first run, which is
independent evidence Art's arrival regions were right all along.

## HALL CERTIFIED — 2026-09-03

Art `0ed2292`: three `grapple_point` offers and one optional collar
`ring_s_to_ring_e`, no geometry change. 12 surfaces, 12 traversals (9
mandatory / 3 optional), 6 offers, 73 colliders, marker parity 12 scenes
/ 160 markers / 0 disagreements. **structural=0 measured=0.**

THE COLLAR IS OPTIONAL, AND `_traversal_is_true` SKIPS OPTIONAL
SEGMENTS, so `measured=0` did not prove it. Forced mandatory in a
throwaway manifest edit, the audit's own flood proved it and the room
still measured 0. That is the proof; the clean sheet alone was not one.

All three grapple offers BUILD through `MovementPackage`. But the same
offers DECLINE under a narrower `supported` probe, and the difference is
arithmetic rather than geometry: `_grapples` walks down in 2 m strides,
so a probe window narrower than the stride falls BETWEEN floors and
reports a 60 m hall as having no ground in it. **`MovementPackage` has
no production caller and Production has no canonical `clear`/`supported`
implementation** — the rules exist, their binding to real geometry does
not. Whoever writes that caller inherits this. Flagged, not fixed.

## shell_hall_transit IS TECHNICALLY CLEAN — 2026-09-03

Art `8fbb916` synced. The mirrored delta is five files: `SCENE_PLAN.json`
and four `.glb` meshes. The manifest and every `.tscn` are UNCHANGED, so
this is a pure geometry repair and marker parity could not have moved.

**THE HALL CERTIFIES: structural=0 measured=0**, over 12 surfaces and 11
traversals — not over zero probes, and not over a substitute room.

INSTANTIATED AUTHORED, proven four ways rather than inferred from the
absence of a REFUSED line: the builder's own stamp reads
`authored_shell=shell_hall_transit` (a fallback leaves it empty); the
instantiated root's `scene_file_path` is
`res://content/shells/shell_hall_transit.tscn`; that path is the one the
manifest declares; and the census surf/trav of 12/11 are exactly the
manifest's declared counts, which no procedural arena can produce.

THE SAWTOOTH IS GONE, measured with the real capsule's own ray at 0.10 m
along each segment. `basin_to_gallery`: 256 samples, 0 missing ground,
**max upward step +0.846 m**, max downward 0.000 — monotonic.
`gantry_to_exit`: 231 samples, 0 missing, **max upward step +0.875 m**,
max downward 0.000. Before the repair the same lines stepped ~1.40 m.
Both are inside `MAX_VERTICAL_STEP` = 1.0, and Art's own figure across 19
flights (0.89 m) sits just above Production's two measurements, which is
the right direction for a handoff claim to be wrong in.

A CAUTION ABOUT MY OWN PROBE, recorded because it nearly became a false
finding. The same straight-chord sampling reports max_up +21.000 for
`gallery_to_landing` and `ring_n_to_ring_e`. Those are not defects: the
chord between two ring surfaces cuts across the ring's open middle and
the ray falls to the basin floor and back. It is the collar-versus-chasm
trap again, from the other side — a chord probe is fine for a flight and
worthless for a loop. The authoritative flood passed both.

Nine mandatory segments chain unbroken vestibule -> basin -> gallery ->
landing -> bridge_n -> ring_n -> ring_e -> bridge_e -> gantry ->
exit_platform; `ring_s` and `ring_w` sit on the two optional segments by
design. Marker parity exact: 12 scenes, 158 markers, 0 disagreements.
Plinths keep their geometry and are not `stand` Surfaces; no plinth
traversal claims remain.

**Actual instantiated collider count: 73 `CollisionShape3D` (73
`StaticBody3D`, 3 `MeshInstance3D`).** Art's prose says 71. Not
reconciled, and deliberately not explained away — `all_solid_boxes`
returns 76 over the same root, so the three counts measure three
different things and only the 73 is what Godot instantiates.

Verdict: **TECHNICALLY CLEAN / OWNER REVIEW PENDING.** Still
`review: pending`, still out of the catalog, no owner pass assigned.

The refusal guard still bites: with the hall no longer refused, the
sabotage was recreated (review flipped to `pass` AND one traversal start
dragged 5 m off its marker) and the suite went red, exit 2, "approved
content and its authored scene was refused".

## HALL BUILDS; THE TWO CLIMBS DO NOT WALK — 2026-09-03

Art `6232a27` synced (`SCENE_PLAN.json`, `registry/authored_art.json`,
`shells/shell_hall_transit.tscn` — the `.glb` did NOT change, which is
itself the confirmation that only the markers were ever stale).

**THE STALE-SCENE DEFECT IS CLOSED.** Verified independently rather than
from Art's report: 12 scenes, 158 `Marker3D` nodes, **0 scene/manifest
disagreements**. `shell_hall_transit` now instantiates as AUTHORED —
surf=12, trav=11, sock=21, hull=73, **structural=0**. Surfaces 14 -> 12;
the plinths keep their geometry and stop being `stand` Surfaces, which
answers the 2026-09-02 finding.

**IT STILL DOES NOT CERTIFY: measured=2.** Both mandatory climbs —
`basin_to_gallery` (0 -> 11 m) and `gantry_to_exit` (21 -> 28 m) — fail
the walk-connectivity proof.

WHAT THE FINDING MEANS, measured rather than guessed. Sampled along each
flight, the AABB evidence and the physics evidence disagree, and they
disagree the way the recurring defect always does — two derivations of
one fact. `mesh_ground` over collision AABBs (what `ShellValidator` reads,
hence structural=0) sees clean monotonic treads: 21.00, 21.88, 22.75,
23.62, 24.50, 25.38, 26.25, 27.12, 28.00 — every rise 0.87. The physics
ray (what `RoomAudit` reads, and the final authority) sees a SAWTOOTH on
the same line: it reaches a tread top, descends 0.35-0.70 m before the
next tread, and the climb out is then **~1.40 m every time** —
21.17->22.57, 22.23->23.62, 22.92->24.32, 23.97->25.38, 24.68->26.07,
25.73->27.12, 26.43->27.82. `MAX_VERTICAL_STEP` is 1.0.

This is NOT a single-line sampling artifact, and the flood is what rules
that out: it is 8-connected at 0.4 m over the whole declared corridor and
visited 2312 cells of roughly 2848 available in the basin alone without
ever climbing. If any lane up either flight had rises within a step, the
search covered the width to find it.

So: a REAL geometry property, not a metadata defect and not a law that
needs relaxing. The real collision surface of both flights does not rise
monotonically, so a player walking up meets ~1.4 m rises. Art's to
remodel so the walking surface climbs in <=1.0 m increments, or the
owner's to re-declare these as something other than `walk`. Not repaired
here, and the law was not touched: `MAX_VERTICAL_STEP` stays 1.0 and no
tolerance was widened to make the room pass.

Small discrepancy worth a look: Production counts **73** CollisionShape3D
nodes in the hall; Art's handoff says 71.

Wave-1 unchanged and still inert — all four pending shells load,
`is_offerable` refuses each, catalog is exactly the eight approved P2
shells. Digest `6e8d83d0f3ec088b`, 23 rooms / 15 Checks / 922 points / 35
enemies, baseline byte-identical, 17/17 Godot suites and 1140 Python
tests green.

## HALL RECERTIFICATION — REFUSED, and the guard that hid it — 2026-09-02

Art `3b7bb02` is integrated verbatim (`SCENE_PLAN.json`,
`registry/authored_art.json`, `content/shells/`), including the three
Wave-1 LARGE rooms at `review: pending`. **`shell_hall_transit` DOES NOT
CERTIFY: it does not build.**

`ShellValidator` refuses it because Art's manifest and Art's own
`shell_hall_transit.tscn` disagree about where four traversals start and
end — eight endpoints, 0.71 m to 5.02 m apart. The refusal is real and
Production is right to make it.

WHICH HALF IS STALE, measured rather than assumed. Against the previous
manifest the scene's markers were exact (0 mismatches, all 26). Against
Art's new mesh, ALL 22 declared endpoints in the new manifest are
supported — every one finds ground within a legal step. So the manifest
is right about the geometry Art shipped and the `Marker3D` nodes are the
half that did not get regenerated. **The fix is Art's and it is one
file:** re-export `shell_hall_transit.tscn` from the source that
produced the manifest. Production did not hand-edit either artifact.

THE GUARD THAT HID IT, and this is the more durable lesson. The census
asked "did the authored scene answer?" as `not sockets.is_empty()` — and
a refusal falls back to the PROCEDURAL builder, whose rooms have sockets,
meshes and hulls like any other. So the hall was refused, silently
replaced by an arena, measured, and reported `structural=0 measured=0`:
a clean sheet for a room that never built, over a room nobody asked
about. The suite was GREEN while looking at the wrong geometry.

`ContentInstantiator` now stamps `authored_shell` on the result it
builds from a scene, because the builder is the only code that knows
which branch it took, and the driver asks it instead of inferring.
A refused shell gets no census line at all — it prints REFUSED and the
validator's reasons — since every number on that line would have been
the substitute room's. Sabotage: flipping the hall to `review: pass`
turns the suite red (exit 2, "approved content and its authored scene
was refused"); pending keeps it evidence, the same gate findings use.

SECOND FINDING, from the two plinth traversals Art deleted. The nine
MANDATORY traversals still chain unbroken vestibule -> basin -> gallery
-> landing -> bridge_n -> ring_n -> ring_e -> bridge_e -> gantry ->
exit, and the two optional ones close the ring westward, so base-kit
circulation survives the deletion. But `plinth_west` and `plinth_east`
are still declared `stand` surfaces, 6x6 m at y=4.0, and NOTHING
declared reaches them any more: no traversal, and no offer either — the
rail route passes nowhere near them and `launch_gantry` is the gantry at
(16, 21, 30). Under C(ii) a `stand` surface is a region OFFERED to a
placement consumer, so the hall now offers two standing regions that are
not behind a capability gate but behind nothing at all. Either the
plinths stop being surfaces or something declared reaches them. Owner /
Art decision; not repaired here.

The three Wave-1 rooms are INERT, proven at the seam rather than
asserted: all four pending shells load into the registry, `is_offerable`
refuses each, and `shell_catalog` is exactly the eight approved P2
shells. `SHELL_FOR_TYPE` still names the five procedural ids. Digest
`6e8d83d0f3ec088b`, 23 rooms, 15 Checks, 922 points, 35 enemies,
baseline byte-identical. Eight P2 shells still `structural=0
measured=0`.

## ROOM GRAMMAR v0 — landed 2026-08-30

The first bounded slice of `docs/proposals/ROOM_FIRST_GAMEPLAY.md`,
approved in direction by the owner. **The rest of that proposal is still
unbuilt and still needs approval per slice.**

What exists now. `ArenaChamber.elevation` is an optional `ElevationBand`
(gallery or pit, one per room, bounded rise/coverage/side/access), so a
room can say it has a second height — the field that did not exist. The
arena builder builds it as ordinary composition: deck, lip, and a ramp
whose run is three times its rise, so base movement always reaches it
(NO REQUIREMENT BEFORE GUARANTEE, applied to geometry). Ranged enemies
take the deck. Two environmental objects exist and answer when hit —
`DestructibleCover` (pays in space, not loot) and `ReactiveBarrel`
(hazard orange honestly spent) — placed only into builder-vouched
sockets. `make godot-room` is the suite; `make godot-zone-audit` now
measures every declared band in the real assembled Zone.

The socket contract is the load-bearing part: **the builder emits points
it vouches for, and regions of architecture that content must avoid are
DECLARED as `reserved` sockets rather than inferred.** Three defects in
this batch were all one shape — the ramp is 6.8 m long so occupancy
classified it as architecture and it became the one invisible obstacle
in the room; ground sockets were offered blind and landed inside crates
and inside the gallery's own mass; and the pit was dug under an intact
floor slab, a sealed basement that every unit test passed.

Measured, not tuned: 5 of 23 chambers in the played Zone declare a band
(4 galleries, 1 pit) on the deterministic seed. On the same Zone, this
batch's engine changes produce byte-identical audit results to the
pre-batch engine — 0 structural failures, 10 placement notes, every one
of them in a `platform_path` room and none in an arena.

`ENVIRONMENT_OBJECT_VALUE` was written and then deleted: how many objects
a room can hold is a fact about its built geometry, and Python pricing it
would be the same builder-knows-what-the-composer-does-not failure.

## P2 OWNER APPROVAL ABSORBED — the eight shells ship — landed 2026-09-02

Art `5998ef8`, integrated verbatim. **Exactly one field moved**:
`review` "pending" -> "pass" on the eight room shells, plus the matching
`runtime_substitution` in `SCENE_PLAN.json`. Every other field on every
entry is byte-identical -- geometry, collision, sockets, surfaces,
traversal, volumes, size_class, exit_yaw, fits_floors, cameras. The three
projectile visuals stay pending.

**The catalog is no longer empty, and that is what approval MEANS.**
`shell_catalog()` now offers all eight under corridor / tower /
treasure_room, because a passed shell is shippable and therefore
offerable. `SHELL_FOR_TYPE` is untouched and still names only procedural
ids, so the DEFAULT route is unchanged and the fallback provider names no
shell at all (all 23 played rooms carry `shell_id: null`). But a live
Epsilon provider is now shown them and may name one -- so "unavailable to
ordinary Zone composition" is true of the default and the fallback, not
of the live path.

Zone digest `6e8d83d0f3ec088b` unchanged; the played Zone is identical.

**Review is now a HARD gate.** An approved shell that fails the contract
turns the suite red rather than reporting a note. All eight measure
`structural=0 measured=0`, so the gate binds and passes.

Two suite guards were re-anchored, both to something stronger:
`_test_a_pending_shell_never_reaches_a_zone` used to walk the registry
for whatever happened to be pending and assert it found eight -- a gate
that stops testing on the day everything is approved, which is the day it
matters most. It now MAKES a pending shell from a real one, so the
refusal is exercised whatever the pack's review state is (sabotage-proven
against `is_shippable`). And `test_the_committed_registry_offers_exactly
_what_it_has` said in its own failure message that when authored shells
arrived it should start asserting they ARE offered; it now asserts the
offered set is exactly the shippable authored shells.

**OUTSTANDING, and NOT mine to take**: the Playtest 2.5 baseline no
longer matches, because the request catalog Epsilon is shown now contains
the eight. Measured: nine changed leaves, ALL under
`zones[*].request.catalog.room_shells`, ZERO under any zone output.
`preflight_problems()` says in as many words that retaking it is "a
developer's call, not yours", so it was not retaken. `make baseline`
fixes it, and `test-bridge` is red on those two tests until it is run.

## P3.5A — the walk proof is physical — landed 2026-09-02

**The owner found a real unsoundness and it is fixed.** P3.5 used
declared `stand` rects AS the proof of connectivity: two ends inside one
Surface passed unconditionally, and two rects overlapping in the
manifest were taken as an edge. Under C(ii) a Surface promises only that
a valid placement can be FOUND in it, so one valid Surface may span a
chasm -- and that chasm was being called walkable.

**Rects now BOUND the search; geometry proves it.** A bounded flood over
player-radius samples: a node exists only where the evidence finds
support at a walkable height and the player's body fits above step
height, and an edge exists only between neighbours within one
`MAX_VERTICAL_STEP`. Rings, switchbacks and long ramps flood; chasms do
not. The cap FAILS CLOSED.

Evidence: `ShellValidator` floods collision hulls (support only -- an
AABB body test at surface EDGES false-refuses every P2 shell, measured);
`RoomAudit` floods with the real capsule and is the final authority.

Two engine bugs surfaced on the way: the audit's ground ray reached only
0.8 m below its reference and so could not SEE a legal 1.0 m step down,
and a one-player-width lattice anchored on the start sampled only the
riser column of a step.

S1-S6 all pass and both sabotages are caught.

**ONE OUTSTANDING, and it is Art data, not the law**: `shell_tower_spiral`
`platform_8_to_deck` is declared `walk` and crosses a **0.8 m void** at
x=3.0 between two decks (probed: floor at 9.00 for x<=2.6, nothing at
x=3.0, 8.00 for x>=3.4). That is a legal hop, not a walk. The shell is
`review: pass`, so the gate turns `godot-room-contract` RED -- working
as designed. One word in Art's manifest (`walk` -> `gap`) clears it, and
Production must not make that edit.

## P3.5 — LARGE-room traversal semantics — landed 2026-09-02

Art `28c5a99` integrated. **`shell_hall_transit` stays `review: pending`:
approval does not override the gate, and it does not pass yet.** Three
precise findings, all its own declarations rather than its geometry —
`basin_to_gallery` declares a mandatory walk from the basin to a gallery
11 m up with no declared surface chain between them, and
`gallery_to_landing` / `gantry_to_exit` start 1.0 m past the end of the
platforms they leave from, in air with no geometry under them.

**Traversal kinds are claims, not exemptions.** `TraversalLaw` states the
law once; `ShellValidator` runs it on collision hulls at import,
`RoomAudit` on rays in the tree. `gap` and `rise` keep their bounds
untouched; a `walk` is checked as CONNECTIVITY over the room's declared
surfaces. My first draft used a straight-line ground sample, which is
wrong and worth remembering: a ring collar and a chasm crossing are
identical along the chord, so no chord test can separate them.

**Rails are smooth.** Catmull-Rom handles from the authored points, which
the curve passes exactly through. Measured on the shipped `rail_helix`:
worst baked turn **1.68 deg** over 735 samples versus **62.4 deg** per
corner as segments. Pitch and envelope containment are measured on the
BAKED curve, because points can be legal while the curve between them is
not. An invented max-bow constant was deleted rather than tuned.

**`grapple_point` is a place, not a mechanic.** A region offer, validated
(anchor clear, room to swing, ground below) and never built — Epsilon
picks the verb, or declines.

**Offers were never reaching the room**: `_from_authored_scene` did not
emit the key at all, so the P3.0 seam was unconnected on the authored
path. Fixed.

Four sabotages, all caught. Digest `6e8d83d0f3ec088b`, catalog 8 (the
hall is not in it), eight P2 shells unchanged at `structural=0
measured=0`.

## P3.0 — LARGE-ROOM MOVEMENT FOUNDATION — landed 2026-09-02

Contract only. **No LARGE room was authored**, and none of the eight P2
shells was touched. Full record: `docs/LARGE_ROOM_MOVEMENT.md`.

**What the rail was**: two points on one axis and an `Area3D` that
lowered friction while the player fell through it under normal gravity.
Not path following, no entry, no jump-off, corridors only. Calling it a
spline grinder would have been a lie, so the audit says so plainly.

**`RailPath`** owns a `Curve3D` with an explicit 0.2 m bake interval and
is the single authority for beam, ride volume, runtime and validation.
Curves, climbs, descents and helices are legal; past 75 degrees is
refused, and so is a degenerate path -- at build time, not under a rider.

**`RailRider`** is pure state, so the whole ride is driven frame-exact
headlessly. Entry needs proximity AND motion along the path; direction
comes from the sign of that motion; exit is the endpoint or jump, never a
dead stop. **The rail DRIVES** -- a target pace shifted by slope, with
arrival momentum riding on top and bleeding away. That is progression,
not taste: a map-provided route may be mandatory, so the base kit must
finish it, and the first ballistic draft stalled a walking player a third
of the way up a 6 m climb.

**`LaunchSolver`** derives the trajectory from source, destination and
gravity -- no authored velocity anywhere, so moving either end moves the
arc. A chosen apex rather than minimum time makes it readable AND unique,
which is what makes it deterministic. Refuses an obstructed arc, an
unsupported landing, a landing with no room, and a landing smaller than
a player can aim at. `bounce_pad` stays: different offer.

**The offer seam**: `offers` on the room output and in the manifest,
closed to `rail_route`, `launch_source`, `launch_target` -- the three
with consumers. `grapple_anchor`, `platform_route` and `wind_column`
arrive through the same key with the packages that read them.
`MovementPackage` is the minimum harness proving an offer can be
consumed, validated, and DECLINED, with the room still a room.

Ten engineering fixtures, all ugly boxes and bare paths. Four sabotages
run; three caught. The fourth found that the "too few points" branch is
redundant with the length rule -- recorded as defence in depth rather
than dressed up, and the missing coverage added anyway.

Digest `6e8d83d0f3ec088b` unchanged, catalog empty, all eight P2 shells
still `review: "pending"`.

## P2 TECHNICALLY COMPLETE — the eight shells satisfy the room
## contract — landed 2026-09-02

Art `1d22cef` integrated verbatim (every Production content file
byte-identical to Art's). **All eight shells: 0 structural, 0 physical
findings**, with the probe census printed beside them so a clean sheet
cannot be a clean sheet over nothing.

Repairs: a deck well over the collapsed and spiral climbs (the deck was
the obstruction, so the deck moved, not the validated climbs), both
`high_3` sockets re-derived by `stance_spot`, and treasure `step_low`
withdrawn as a Surface with its geometry untouched.

**The seven old findings are closed, proven by running the same
certification probes against the old pack in a worktree** -- they fail
there and pass here. The old pack also fails **spiral `high_3`**, which
the previous contract missed because `_points_have_ground` uses a 0.5 m
box and that socket cleared it by ~0.05 m; measuring the real `ranged`
envelope shows it never had room. Independent confirmation of the
owner's judgment call.

Two certification probes added, both producer-independent and both
measuring against rules the audit ALREADY holds rather than adding new
ones mid-certification: a mandatory route must arrive somewhere a
standing player fits (resolved to the declared region, because a
traversal endpoint is where a rise is measured, not a spawn point), and
an `enemy_high` socket must hold the envelope of what stands there.

`review: "pending"` on all eight -- NOT promoted. Catalog empty, digest
`6e8d83d0f3ec088b`, Zone audit JSON byte-identical to `1648fa9`. No
Production code writes any field Art emits, so the next regeneration
needs no patch reapplied.

Full record: `docs/audit/P2_SHELL_PHYSICAL_VERDICT.md`.

## P2 SURFACE SEMANTICS — a Surface is an offer — landed 2026-09-01

**Owner ruling C(ii).** A `stand` Surface does not promise every point of
its rect is clear. It promises **a valid placement can be FOUND somewhere
in it** -- the same shape as "a socket is an offer, not an order". A
Surface with ZERO valid placements is still invalid.

**One solver**: `scripts/content/placement.gd`. It owns the candidates,
their order, the footprint rule and the verdict. `RoomAudit` asks "can
this keep its promise?"; `Activities` asks "where is the point?". Both
call `Placement.find`. Evidence necessarily differs -- the audit measures
a room in the tree, the composer runs on a detached root -- so each
passes a `clear` Callable and the suite pins the two verdicts against
each other on every producer.

**`Activities` stopped choosing blind.** Its last-resort spot used to be
the first candidate whatever was there; it is now the first the ROOM
allows, so only crowding is traded away, never geometry. A surface that
cannot hold an element is declined and the flat solve stands.
`ChamberBuilders.all_solid_boxes` reads collision shapes too, because an
authored shell is one merged mesh and the composer could not otherwise
see inside it.

**No percentage is law.** Validity is geometric: a footprint fits, or it
does not.

**Findings 75 -> 7.** Every C finding gone, every A and B finding kept:
collapsed `rubble_1_0`/`rubble_1_1` + socket `high_3`, spiral
`platform_6`, treasure `step_low` x3. Those stay Art's.

**Proven, not asserted.** Four sabotages, each caught: restore "every
point must be clear" (fails on the PROCEDURAL producer too), make the
audit never refuse, make the composer skip geometry, stop reading
colliders. Determinism: same chamber composed twice, identical
positions; no RNG in the solver. Producer independence: a real
procedural island roofed in three steps -- none, half, all -- and the
verdict follows the geometry. Real-Zone proof: the 23-chamber activity
audit JSON is **byte-identical** to `940211e`.

## P2 PHYSICAL VERDICT — the shells are measurable, and measured —
## landed 2026-09-01

Art `a798b2c` brings collision: **1 render mesh + 10-33 convex hulls per
shell**, no trimesh, no drawn collision mesh, and the player's own
capsule passes every entry and exit plane. The audit's answer is no
longer "not measurable".

**75 findings, and they are three different things.** Full record with
every number: `docs/audit/P2_SHELL_PHYSICAL_VERDICT.md`.

The probe that separated them: sweep each declared rect 15x15, inset by
the player's diameter, and ask whether a 0.4 x 1.8 m capsule fits
standing at the declared height. Legitimate surfaces measure 40-100 %
usable; the defects measure **0 %**. Nothing sits near the boundary.

* **A — real geometry defect (27).** The last rungs of the *collapsed*
  and *spiral* climbs run under the top deck: 1.50 m and 0.50 m of
  clearance on a `mandatory: true` route. Art's.
* **B — metadata derivation defect (28).** Treasure `step_low` is a
  0.40 m riser whose exposed ring is 0.40 m wide against a 0.80 m
  player: 0/225 usable, declared a Surface. Collapsed socket `high_3`
  sits 0.2 m inside the stone above it. Geometry correct in both;
  the claim is not.
* **C — contract semantic mismatch (20), NOT implemented.** A `stand`
  rect that is the mesh's true top face, part of it under a stair or a
  dais. **The tower stones ARE general-purpose stand surfaces** — 2.6 m
  square with 40-100 % clear — so demoting them to traversal-only would
  throw away real space. But the contract cannot say WHICH PART of a
  face is clear, and measurement does not settle who should: Art
  declares only clear rects, or the audit measures usable area and
  `Activities` checks clearance where it places. **Owner decision, on
  record, not guessed at.**

Whichever way C goes, the rule that catches A and B is unchanged: a
`stand` surface with zero usable area is refused.

**One audit defect fixed.** Two 1.00 m rises measured **1.000039101** —
`.glb` float quantisation — and were refused, while the span check three
lines below had always carried `+ 0.01`. `RoomAudit.AS_BUILT_SLACK`
names the tolerance once for both. Pinned from both sides: 4 mm over is
the same step, 15 cm over is still refused.

All eight stay `review: "pending"`. Catalog empty, digest unchanged,
every chamber still builds procedurally.

## P2 FINAL — the eight shells are in the catalog, and refused by the
## audit — landed 2026-09-01

All eight are IN the registry (29 entries load), carry the owner's size
classes, and are `review: pending` — nothing can select them, the
catalog offered to Epsilon is empty, and the digest is unchanged.

**None of them measures true, and the reason is one thing: the imported
meshes carry NO COLLISION.** One `MeshInstance3D`, zero
`CollisionObject3D`, zero `CollisionShape3D`, in every shell. So the
audit's verdict is **"not measurable"**, not "measured and safe":
Art's 47 predicted headroom notes are neither confirmed nor refuted,
and neither are the doors or the jumps. `ART_ASSET_SPEC.md` §3 is
explicit that collision is authored (`-col` / `-convcol` / `-colonly`),
so this is an export gap, reported and not worked around. No mesh
repaired, no contract weakened, no metadata flipped.

**The envelope defect was real and shared.** `_check_envelope` allowed
0.15 m and ran on the AUTHORED PATH ALONE. Measured: procedural rooms
overhang their own bounds by **0.20 m** (`_perimeter` centres its walls
on the boundary), authored shells by **0.40 m** (their entry wall sits
at z ∈ [−0.40, 0]). One shared `RoomContract.WALL_ALLOWANCE` = one wall
thickness + tolerance now binds both, the audit reads EVERY mesh rather
than furniture only, and `ShellValidator` delegates to the same rule.

**Review is now the audit gate.** A `pending` shell's findings are
evidence for review; a shell marked `pass` that fails the contract turns
the suite red. Flipping one to `pass` today is caught immediately.

## P2 PREP — ready to accept the eight shells — landed 2026-09-01

Engineering only. **No authored room landed; Art's exporter has not run
yet** (see "what remains" below). P3 is not started.

**A. The Check/cover collision is fixed.** P1 found a Check pedestal
standing inside a crate in 2 of 4 arenas. The arena now decides where
its Checks go BEFORE it scatters anything, declares that space as a
`reserved` region — so activities and barrels avoid it too — and its
props take the first free spot near the one they rolled. The rng stream
is untouched, so a room with no conflict is byte-identical to before.
The band is built first for the same reason: `_elevation_band` already
DECLARES its deck and its ramp, so the anchor is chosen against those
rather than against a second derivation of where the band is.
`make godot-zone-audit` now measures all 15 Check pedestals of the real
Zone where `ZoneController` will really put them.

**B. `exit_yaw`.** `ContentEntry.exit_yaw`, `{-90, 0, +90}` only,
mirrored in `content_registry.gd` and `room_contract.gd`, emitted by
`_from_authored_scene`, consumed by `ZoneBuilder` AFTER the room is
placed and overlap-guarded — so the turn steers only what comes next.
Absent or 0 is straight through, which is what every room did before.
**The sign is Art's and was expensive: a shell leaving through its +X
wall turns the chain +90 and is the LEFT corner.**

**C. `floors=4`.** `ContentEntry.fits_floors` names the tower floor
counts a shell was BUILT for; empty means it does not care. A shell that
does not fit is not used and the permanent procedural builder makes the
room — there is no arm anywhere that stretches one. Bounds come from
`constants.TOWER_MIN_FLOORS/MAX`, which the schema, both validators and
GDScript all read.

**D. Size/intent.** No thresholds were invented. `size_class` steers
WHICH shell is offered and nothing else; `intent` is read by nothing;
`cost` never reaches `room_value`. A source-reading test keeps all three
that way. **One owner taste call remains open** — see NEXT_STEPS.

**E.** `spawn`/`objective`/`secret`/`vista`/`presentation` socket kinds
still have no live consumer. Untouched, recorded as deferred cleanup:
the eight shells do not need them.

## P1 — ROOM CONTRACT PARITY + THE GEOMETRIC AUDIT — landed 2026-09-01

The first slice of the adopted ROOM_ARCHITECTURE_STUDY hybrid (PR #7,
`a63220f`). SMALL/MEDIUM/LARGE is the active size vocabulary;
MICRO/MASSIVE are deferred, not retired; F3 is NOT integrated. **P2 and
P3 are not started and need their own approval.**

The asymmetry it closes: `ChamberBuilders` and `_from_authored_scene`
both answer "build me this chamber", and the authored one answered with
**no `sockets` key at all** — no cover, no barrels, no reserved regions,
nowhere to stand — so `Activities` flat-solved against its bounding box.
That is the defect `552469d` closed for `platform_path`, waiting in the
one path no Zone takes yet.

Three pieces:

* **`room_contract.gd`** — the room OUTPUT written down. Required keys,
  a CLOSED socket vocabulary (`stand`, `reserved`, `cover`, `reactive`,
  `enemy_high`, `access`), each tied to a consumer that runs today, plus
  optional `traversal` in `TraversalSegment`'s own shape. Structure only.
* **`room_audit.gd`** — the same claims measured with rays, boxes and
  the player's own capsule. **Author-declared metadata is a claim;
  Godot measurement is authority.** It refuses to report a clean sheet
  for a room outside the scene tree, because a probe with nothing to hit
  comes back clean.
* **`make godot-room-contract`** — ONE suite over both producers, in CI.
  Per-producer suites inherit the blind spot of the fix they protect;
  this project has watched that happen three times.

Schema (mirrored into `content_registry.gd` the same commit): a
`Surface` model and `ContentEntry.surfaces`; `Socket.kind` gains the
three runtime kinds `cover`/`reactive`/`enemy_high`; `Socket.surface_id`.
An authored room shell that declares no surfaces is refused; a
`procedural_fallback` entry is exempt, and the procedural route stays
permanently legal.

`ShellValidator` now keeps a promise `content.py` has always made in
prose and nothing kept: measured mesh AABBs against the declared `size`
envelope.

**Zero player-facing change, verified**: `zone_digest 6e8d83d0f3ec088b`
and the real-Zone audit are unchanged (0 failures, 0 notes), and no
committed registry entry, fixture or baseline moved.

One defect the audit FOUND and P1 does not fix: an arena scatters three
cover boxes at random through the middle half of the room and
`reward_position` is a fixed point on the centre line, so a Check
pedestal can stand inside a crate (2 of 4 arenas in the suite).
`zone_controller.gd:150` places it with no clearance test. Reported,
pinned so it cannot grow, not fixed — moving either would be a
player-facing change.

**Playtest-hygiene follow-up, same contract, one kind wider.** The
`platform_path` defect from `docs/ZONE_ACTIVITY_AUDIT.md` §4 is closed.
The row solver reads a room's width and depth, and a `platform_path` has
no floor across them — its bounds reach forty metres into a kill pit, so
19 elements were standing on nothing. `platform_path` now emits a
`stand` socket per surface it builds (start ledge, each island, end
ledge) and the solver places onto one chosen surface per activity.
Islands are refused by measurement, not by name: what is left beside an
element must be at least `BRUTE_LANE`, and 2.5 m of mandatory route over
a pit cannot give it. The real-Zone audit is **0 failures, 0 notes**,
`no_ground_under` is now a structural failure rather than a note, and
every arena element is byte-identical to `2699805`.

Owner ruling after playing Zone 1: the problem is not the activity
families, it is that **the rooms are miserable**. "There's more stuff to
do, but it does nothing and it's not fun." A breakable crate with
something in it beats four buttons that do nothing.

The measurement that explains it: **a room's entire shape is three
numbers.** `ArenaChamber` is width, depth, wall_height. There is no field
in which a balcony, a pit, an alcove or a side branch could be described,
so 23 of 23 rooms are rectangles and all eight corridors are the same
7.9 m width. The flatness is not the generator doing badly — it is the
generator faithfully building everything the schema can say.

Consequences measured in the played Zone: elevation exists in exactly one
chamber type (`platform_path`, the special-case minigame, and the one
where all 23 floating activity elements are); 28 of 41 enemies are ranged
with nowhere to be ranged from; 9 of 10 combat rooms hold a single enemy
group; 7–11 inert props per arena against 2 affordance features in the
whole Zone.

The proposal's load-bearing idea is SOCKETS — the room declares where
things may go. Every placement bug this month was one bug, "the builder
knows things the composer does not", and each was fixed by handing the
composer more information afterwards. Sockets end the class.

**F3 is answered by this, not deferred by taste.** Art's own handoff
measured that an authored shell replaces per-chamber dimensions with one
fixed size per registry entry, so integrating it today makes rooms MORE
uniform. The fix Art names — a shell that declares what sizes it can be —
is the socket contract. Grammar first, then authored rooms.

Smallest slice proposed: one elevation band in an arena, ranged enemies
on it, and crates that break into something. No new subsystem.

## ACTIVITY CONVERSION — LANDED 2026-08-30

The batch proposed below was approved and is built. `531 of 921` content
points stopped being glowing boxes: `ActivityRuntime` owns one state
machine (`NOT_YET / IDLE / ACTIVE / COMPLETE`) with the four families
configured in one `RULES` table, and `ActivityElement` is one class with
three trigger modes (`touch` latching, `shot` through `Damageable`,
`stand` momentary with a `PLATE_HOLD_SECONDS` window).

**The owner correction that shaped it: activities are NOT restricted to
the permanent baseline kit.** Prerequisites are SEMANTIC CAPABILITY
SATISFACTION — "can the player grapple", never "does the player hold the
Grapple Echo" — expressed over the primitive vocabulary the fold already
produces (`mechanics.ACTIVITY_CAPABILITIES`, four capabilities, same
shape as `AFFORDANCE_REQUIREMENTS`).

**NO REQUIREMENT BEFORE GUARANTEE.** `capability_guarantee()` answers
with the cheapest proof that holds: A `permanent_baseline`, B
`already_possessed` (over the fold, not the loadout), C
`established_in_zone` (a parameter with no producer yet — the seam a
capability-establishment construct plugs into), D `forge_constructible`
(named, unreachable, deferred). `validate_zone` refuses any activity
requirement outside the guaranteed set, and the default is the permanent
baseline so a caller that forgets refuses MORE than it should.

Raw damage can never be logic: a requirement carries no number at all,
and a capability may not be keyed on `damage_dealt`/`damage_taken`
(`test_a_capability_can_never_be_a_damage_number`).

NOT YET is reachable rather than theoretical: generation reasons over
what the campaign OWNS, `snapshot.available_capabilities` says what is
EQUIPPED, and the gap is the gate. It never fakes an interaction and
never downgrades to a base-kit substitute.

`make godot-activity` drives every family to completion AND to failure
through real physics and the real damage path. Sabotage-proven: inert
elements → 17 failures, always-complete → 8, unchecked ordering → 2.

Two defects fixed on the way. `make_playtest_baseline.py` hardcoded
`unlocked_affordances=()`, so the archive held zero features where the
played Zone held two — evidence that under-reports is worse than none.
And the fallback emitted seven `timed_run`s with `time_limit = 0`; the
clock is now derived from the schema's own floor, never chosen.

`challenge_marker` stays deferred: completion grants a `flavor_log`, and
a test fails if `activity_runtime.gd` ever names the marker.

Zone digest moved `98e08663ce6b3b7a` -> `1bdf42f800c5637e`. Same 23
rooms, 15 Checks, 41 enemies; the value moved 921 -> 916 because seven
runs now earn `ACTIVITY_TIMED_BONUS` and the top-up loop lands
differently. **The A/B is closed, so the digest was free to move.**

## AVAILABLE, NOT ADOPTED: the Art lane's camera bench

Art surfaced an existing render toolchain on `claude/archipepsi-art`
(`docs/art/CAMERA_BENCH.md`, `tools/artpreview/`, `tools/shots/*.json`,
and a finished `docs/art/proposals/photo_mode.gd`). **Awareness only —
no owner mandate to adopt any of it, and nothing here depends on it.**

Worth knowing because it names a real gap: Production has no
screenshot/render capture path at all, so a visual regression can exist
with every logic suite green. That is what the mirrored Hub sign and the
one-slab light fixture were. If a future batch wants golden shots of
REAL generated Zones, read `CAMERA_BENCH.md` first — `--headless`
selects the dummy driver and an awaited SubViewport capture hangs with
no output, which is an hour nobody needs to spend twice.

## THE BATCH THAT BECAME THE ABOVE — proposed 2026-08-30, approved

`docs/proposals/NEXT_BATCH_ACTIVITY_CONVERSION.md`. **Built and landed;
kept for the reasoning, not as a to-do.**

The owner's stated priority is PLAYER ACTIVITY MUST BE FUNDED
INDEPENDENTLY OF CHECK COUNT. Measuring the played Zone sharpened it:
531 of its 921 content points (57.7%) are already activities, and
`Activities._row()` builds a `StaticBody3D` with a mesh and a collider
and nothing else. No `Area3D`, no signal, no completion; nothing outside
`activities.gd` reads the four kinds at all. So the budget already flows
away from Checks and none of it becomes gameplay — the binding
constraint is conversion, not funding, and adding rooms first would
scale a conversion rate of zero.

Why it was invisible: `test_the_engine_builds_every_activity_the_schema_admits`
reads `activities.gd` as TEXT and proves a `match` branch exists. Right
question when the seam was geometry; it cannot see that the branch
produces something inert. The same shape as the mirrored sign, the
centre-only seal probe and the fixture detector: **a guard inherits the
blind spot of the fix it was built to protect.**

Two smaller finds recorded there: `SECRET_VALUE` is priced in
`content_value.py:54` and no chamber field can produce one, and
`make_playtest_baseline.py:91` hardcodes `unlocked_affordances=()` so the
archived baseline under-reports optional content against the Zone that
was actually played (2 features).

## Zone 1 playtest, 2026-09-11 — the frontier now

**`docs/reports/2026-09-11-playtest-zone1-findings.md` is the live list.**
Skyah played the 3A/3B checkpoint Zone start to portal in `none` mode.
Game code stayed at the audited `96c450e`; that report and the two
corrections beside it are documentation only.

**Both blockers are REPAIRED as of 2026-09-12** (see §6 of that report):
the escape flood in `room_contract_driver.gd` now walks `c015` and `c005`
from the played Zone's own chamber dictionaries, walking only, and each
repair was reverted individually to confirm the suite goes red without it.
The Span stairs are measured and handed to Art
(`docs/art-requests/2026-09-12-span-basin-stairs.md`): both flights stop
three risers short of their deck, a final step of 2.63 m against a jump
apex of 1.333 m. Promoting `shell_validator.gd:110` so a non-mandatory
`walk` is proven along its length is the follow-up and waits on that
repair, or it lands a red suite on an Art defect.

What was repaired, all in `_elevation_band` / `band_rect` and all
invisible because no fixture built a `back` band:

Two **blockers**, both run-ending without an Echo:

- A `gallery` with `side: "back"` puts its full-width deck across the room's
  own exit doorway. `c015` has 1.46 m under the deck and 1.34 m over it for
  a 1.8 m capsule. `_openings_are_holes` would refuse the room; no fixture
  ever builds that shape — `room_contract_driver.gd:743` rolls
  `["left","right","back"][i % 3]` inside `if i % 3 == 0:`, so only `left`
  is ever built, and the one `back` fixture is a pit.
- The pit ramp is built outside the recess it serves and the recess has
  three walls. Escape from a pit is never audited.

The structural finds that outrank polish: **Epsilon owns no positions**
(no chamber field expresses where anything goes, so intentional
composition is not expressible); **prop placement is a fixed lattice
identical in every arena**, with the barrel points and the enemy ring
computed by formulas that never compare (barrels cannot kill anything);
**there is no enemy perception** (18 m sphere, no line-of-sight check,
`_has_noticed` never cleared — 9 of 10 arenas are 100% watched before
entry); **enemy stats never scale while player power does**; and
**connectors are a collision spacer, not grammar**, so rooms butt into
coincident wall slabs and a fight leaks into the room behind it.

Nothing from this list is scheduled. It is the evidence the next batch
gets scoped from, and the owner decides the order.

## What playtest 1 taught, and the guard it left behind

Nine headless suites, a whole-campaign integration run and both CI tiers
were green while the game could not enter the Hub. Every one of those
suites is a DRIVER: it takes the dispatch branch in `Main._ready` and
returns before the real setup, then builds its own world. So the startup
path had NO coverage at all, and a refactor that deleted the two lines
assigning `world` and `tones` cost a day.

The general shape, worth carrying into any new test: **a suite that
substitutes for the code it is meant to protect proves nothing about it.**
Two structural guards now exist because a comment saying so did not work.

- `make godot-boot` calls the real `Main.boot()` and drives the
  transition that crashed. It runs FIRST in CI.
- `test_ci_coverage.py` fails when a Godot suite exists that CI does not
  run, because a hand-maintained list of tests falls behind the tests.

Godot's GDScript warnings are EDITOR-ONLY. `--import`, `--editor --quit`
and a SceneTree probe all report zero headlessly, so no CI tier can see
them and the count drifts silently. The three scratch analyzers used for
the sweep were not kept; a warning sweep means opening the editor.

Wake-ups are no-ops except for concrete regressions or CI failures. Do
NOT invent a new roadmap or speculative work to fill a heartbeat.
