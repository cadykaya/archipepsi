# Archipepsi — 0.4 huge batch: Blindside Skiff major + Amalgam breadth

## Context

Skyiah asked for a large implementation campaign, not a cleanup: protect the 0.3
comparison build, advance substantial accepted Amalgam systems, and deliver a
playable Echo-driven major setpiece (Blindside Skiff as a railway junction) with
~3 minor situations, on a separate 0.4 development line.

The destination stays **full accepted Amalgam + all explicit 0.4 deferrals**. This
plan sequences that campaign and details the **first complete gameplay loop** —
first visit → acquisition branch → featured Echo → return → materially changed use
of the railway → progress that survives leaving and returning.

**Owner direction (2026-09-21):** the first major must test the *intended*
experience. The featured Echo opens meaningful new access **including AP Checks
where the matching logic supports it**. No guaranteed walking bypass is added
merely to avoid the acquisition/AP work. **M2's completion** — not the programme —
holds on the acquisition-contract integration.

**Baseline:** `19c5d8e` on `claude/archipepsi-echoes-continuation-b1adno`, draft
PR #4. Clean tree; full frontier green (Python 1604 + 627 subtests; 27 Godot suites
including 5 live-bridge).

---

## 1. Corrected baseline — what already exists

I previously said "no rail code exists." **That was wrong** — a bad grep
(`skiff|railcar|rail_switch`) reported as a finding. Corrected classification; every
row verified against the tree.

| System | Verdict | Evidence |
|---|---|---|
| `RailPath` (`rail_path.gd`) | **REUSABLE AS-IS** | Curve3D wrapper, Catmull-Rom through N authored points, curved + multi-segment, deterministic `BAKE_INTERVAL 0.2`, `at()/tangent()/nearest_offset()/polyline()`, validates pitch ≤75° and room containment |
| `RailRider` (`rail_rider.gd`) | **UNSUITABLE** (useful skeleton) | Player-grind state machine: `player.gd:375-380` assigns `global_position` and deliberately skips `move_and_slide`; `heading` set once (`rail_rider.gd:130`), never reversed; no stops, no passenger |
| `MovingPlatform` (`affordance_nodes.gd:398`) | **EXTENDABLE — the substrate** | `AnimatableBody3D`, `sync_to_physics = true`; its own docstring: "which is how Godot carries a `CharacterBody3D` standing on it". Limits: fixed cosine loop, linear `travel`, hardcoded 2.4×0.4×2.4 deck, no stops/direction |
| Player carried on a moving body | **UNTESTED ENGINE DEFAULT** | No `get_platform_velocity`/`platform_floor_layers` anywhere in `godot/scripts/`; `affordance_driver.gd:531-557` never puts a player on one |
| All four capabilities | **IMPLEMENTED AND PLAYABLE** | Full dispatch `echo_runtime.gd:302-322`; real tether physics `player.gd:1184-1202`; `DEFERRED_PRIMITIVES = {}` since S9 |
| `grapple_anchor` geometry | **REUSABLE AS-IS** | Real ceiling plate + ledge, raycast-biteable, `affordance_features.gd:323-349` |
| Four-slot equip loop | **REUSABLE AS-IS** | intent → fold → snapshot → `set_equipped`; live-updates every snapshot, so an ability can be handed over mid-run with no restart |
| `ActivityElement` SHOT/STAND/TOUCH | **REUSABLE AS-IS** | Generic sensor that decides nothing; shot targets already route via a nested `StaticBody3D` so rays hit them |
| `PoweredLink` | **REUSABLE AS PATTERN** | The one working input→actuator chain; verifies physically (`doorway_is_clear`), not by node position. Hard-wired plate-mass in, one door out |
| `ZoneProgress.latched` + `LatchFired` + `record_latch` | **EXTENDABLE — highest-leverage hook** | Bridge half built and tested (`protocol.py:179-201`, monotone), refuses unbacked latches. Client **never sends it** — every `latched` hit in `godot/scripts/` is prose in a comment |
| `--epsilon=sample` Zone injection | **REUSABLE AS-IS** | `epsilon/sample.py` puts a hand-authored Zone into a *real* campaign: real allocation, real acceptance, re-keys ids, fabricates nothing |
| `capability_guarantee` case C `established_in_zone` | **EXTENDABLE — the designed seam** | Exists as a *parameter*; every caller passes `()`. Comment: "when a capability-establishment construct exists it plugs in here" |
| `DoorAssignment.requires` | **DOES-NOT-EXIST** | Client capability door is complete (`locked_door.gd:96-117`) and **dead** — no schema field carries the gate |
| Machine graph, signal graph, general actuator, `AgencyRecord` | **DOES-NOT-EXIST** | Zero hits outside documentation |
| Per-object / transform persistence | **DOES-NOT-EXIST** | Only 3 monotone sets + `resume_anchor` cross the Zone boundary |

**Two runtime defects, verified directly, both load-bearing if grapple is featured:**
- `player.gd:1197-1198` hard-codes `Input.is_action_pressed("fire_echo")` (RMB) for
  the swing hold, while `SLOT_ACTIONS` maps `mobility`→`fire_mobility` — a
  `grapple_swing` in the mobility slot drops its tether on frame 1.
- `echo_runtime.gd:1010-1012` `_grapple` returns on a miss with no `_refund_press()`,
  burning cooldown and cost on a sky shot (`_blink` and `_grapple_swing` both refund).

### Featured-Echo check (focused, as instructed)

**`grapple_to_surface`.** Implemented and tested; its anchor is real buildable
geometry; it matches the hookshot example; it gives an unambiguous "I can reach that
now" delta; and it sidesteps the swing-slot defect (different primitive).
**Swimming is excluded** — water is explicitly deferred in all five proposals
(Amalgam §2.2).

---

## 2. Two hard constraints that shape the design

1. **§13.2** (enforced by `validate_zone`): a `features:` tag mechanism may never lie
   on the mandatory path, host an AP reward, an exit, or an objective.
   → **The skiff cannot be a feature tag.** It must be first-class Zone content.
2. **§29.5a check 23**: an allocated AP Check, AP-relevant key, or the Zone exit may
   sit behind a capability gate only when the apworld declares the same prerequisite
   and AP proves it obtainable. → **Check 23's protection stays.** The Zone the owner
   wants is simply not composable until the acquisition contract exists. We build
   toward it; we do not weaken the check, fabricate a proof, or rewrite a live seed.

---

## 3. The first playable loop — detailed

A hand-authored Zone injected by `--epsilon=sample` into a real campaign. Three
docks, two links, one branch — the Blindside review's own §11 prototype slice.

```
S1 ==commissioned== S2 - - -broken- - - S3
                    |
                    +-- B2 branch: grapple Echo + gantry alignment control
                          `-- return to S2 (the dock departed from)
```

**Sequence:** board at S1 from a real firing position → shoot FORWARD → ride to S2
through one meaningful combat situation → try S2→S3, get accurate refusal without
stranding → take B2 **with the base kit only** → acquire `grapple_to_surface` →
grapple to the overhead gantry → operate the alignment control → span moves, locks,
latch fires → return to S2 and *see* the link commissioned → ride to S3 → leave and
re-enter; the repair and the remaining Checks match the accepted state.

### Build order

| Stage | Ships | Why here |
|---|---|---|
| **P0** | `godot-passenger-carry`: a real `Player` stands on a `MovingPlatform` through curve, acceleration and stop | The carry is an *untested engine default* with four known hazards. If Godot will not carry a body cleanly, everything downstream changes. Cheapest possible de-risk |
| **P1** | **EX50-011 Passing Platforms** as a real minor | The same carry problem in a 28×22 m room — playable value *and* the skiff's risk reduction in one deliverable |
| **P2** | `RailCarrier`: the `MovingPlatform` pattern advancing an offset along a `RailPath`; docks, direction, reverse, safe stop, fail-safe hold; deck swept along `polyline()` not `segments()` | The vehicle |
| **P3** | Shootable FORWARD/BACK receivers driving P2 via `ActivityElement` SHOT; conflicting-pair and repeat-shot rules per the review's §4 | The controls |
| **P4** | **M1** — alignment control as a player-performed setter interaction; span moves and locks; `latch_fired` emitted; `main.gd` reads `progress["latched"]` back; state re-applied at build | First persistent machine chain, independently playable |
| **P5** | **M2-mech** — full loop in a **development scenario**, grapple granted by the dev path. Explicitly **not multiworld-safe and not M2 complete** | Proves the *experience* early while the contract is developed |
| **P6** | **M3** — EX50-021, EX50-033; second objective binding | First review batch |
| **P7** | **M2 complete** — only when the acquisition contract lands (§5) | The intended experience, multiworld-safe |

### Player-carry work (P0)

`player.gd` needs an explicit "aboard" state exempting `_note_a_step_down_ahead` /
`_follow_the_step_down` (raw `move_and_collide` + forced `velocity.y = 0`) and
`_climb_a_step_the_law_promises` (teleports via `global_position +=`). Detect aboard
from `get_last_slide_collision()` collider class, not a trigger volume.

### Persistence (P4) — no new system invented

Use the rail that already exists. The control is a **setter interaction the player
performs** (satisfying §19.7 — a latch never reaches across rooms on its own); it
declares a `LatchCondition` in the `PhysicsPackage` the client already certifies
(`chain_certificate.gd:279-314`, this time with non-empty `required_latches`); the
client sends the never-yet-sent `latch_fired`; and the link's commissioned state is
**recomputed from the latch at build time, never separately saved** (§5.4a: accepted
consequences persist, live values do not). **No `AgencyRecord` in this slice** — it
is the correct long-term home and is scheduled in M4.

---

## 4. Full workstream outline (scope retained)

Detail decreases with distance from the first loop; later uncertainty is marked as
such rather than guessed.

- **A — 0.3 cleanup.** A1 target orientation (repair, then promote
  `godot-target-facing` to a gate); A2 climbing-producer door records (both producers
  file `exit` past the wall the hole is cut in — `tower` 9 m up and 2.2 m beyond,
  `platform_path` 2 m up; bounded repair, scoped carefully because `door_world` feeds
  join sockets and lock slabs); A3 finish-path coverage; A4 stop tracking disposable
  test saves, launch hygiene. Brought into the 0.4 line deliberately, with lineage
  recorded.
- **B — Amalgam player/item.** Scope-to-code matrix (present / partial / missing /
  blocked-by-named-decision) built **incrementally**, never as a prerequisite to
  starting. B1 one shared effect path; B2 usable builds; B3 Status/physics subsets
  (13 Statuses in 4 families, 8 compounds, trait gating on world not actors);
  B4 Forge/Static **pending decision**; B5 independent breadth after M3.
- **C — environmental objectives.** C1 reuse `ActivityElement` sensors; C2 a
  signal-driven actuator generalised from `PoweredLink`; C3 semantics **already
  settled** by §5.4a — implement, do not re-ask; C4 reset/interruption/tool loss;
  C5 readable cause and effect from the existing vocabulary; C6 bounded
  objective-binding schema so Epsilon selects relationships, not skins.
- **D — Blindside major.** D1–D5 per §3. D6 second binding: `ranged_hit` on eligible
  bracing releasing the same span — a different *relationship*, not a relabel.
  **D7 return-later is blocked** on the all-Checks exit policy; tracked, not forced.
- **E — minors.** EX50-011 (traversal, P1), EX50-021 Counterfire Arcade (combat),
  EX50-033 Unweighted Switch (physical/signal). Chosen for **parts-sharing with the
  major** — receivers, carriers, latches, Status — not for variety.
- **F — progression/Epsilon/AP.** Largely Dess (§5). Engine side: the
  `established_in_zone` producer's client half, and honest `NOT YET` rendering
  (`activity_runtime.gd:230-252` already does this).
- **G — persistence/launch.** G1 0.4 save representation (Dess); G2 legacy migration
  stays separate — **no old campaign touched**; G3 interruption; G4 two unmistakable
  launch modes with separate saves and printed revision/provider/scale.

**Milestones:** M0 approved/baseline protected · M1 one real machine chain ·
**M2-mech** dev-scenario loop (labelled) · M3 first content group ·
**M2 complete** (gated on §5) · M4 remaining Amalgam breadth · M5 pinned review build.
These are checkpoints, **not stop-and-ask gates**: after approval I continue through
independent approved work, preserving a usable checkpoint whenever a stage completes.

---

## 5. The acquisition contract — what M2's completion waits on

**B2 is the preferred proposal for Dess to develop — not an already proven
guarantee.** The plan must establish all five before M2 can be called complete:

1. The featured acquisition is **reachable without its own reward**.
2. Its local Echo **reliably supplies the actual required function** — qualification
   (range, attachment behaviour, legal targeting, slot compatibility) and fallback —
   not merely a capability label.
3. The foreign Check **still delivers its original item to its real recipient**.
4. The AP rules and the **exported allocation contract safely represent the dependency
   before seed generation**. A tier label alone is not proof.
5. **Re-entry, reload, retries and delayed interpretation cannot erase or duplicate
   the grant, or strand progression.**

Until all five hold: check 23 keeps refusing the composition, and that is correct.
No runtime rewriting of an existing seed's logic; no fabricated proof; nothing
described as multiworld-safe that is not.

---

## 6. Decision block — recommendation + consequence

| # | Decision | Recommendation | Consequence |
|---|---|---|---|
| 1 | **Featured Echo + first binding** | `grapple_to_surface` → overhead gantry alignment control. Second binding: `ranged_hit` on eligible bracing releasing the same span | Uses only implemented runtime; avoids the swing-slot defect; matches the hookshot example |
| 2 | **Acquisition contract** | **Settled by your direction:** B2 developed by Dess against the five requirements in §5; M2's completion waits on it; the rest of the programme does not | Full-strength gate; M2 slips behind a bridge-lane dependency, stated honestly rather than dodged |
| 3 | **Skiff as first-class Zone content** | New `RailNetwork` element modelled on `PlugAssignment` — docks named as **anchors, never coordinates**, so the composer still names no world position | §13.2 forbids a `features:` tag from mattering. Cost: a shared schema change needing Dess |
| 4 | **Minor roster** | EX50-011, EX50-021, EX50-033 | Maximum parts-sharing; EX50-011 doubles as the carry de-risk |
| 5 | **Return-later variant (D7)** | **Defer.** Needs "continue the campaign with Checks unfinished", which the exit policy forbids today | Ship local-acquisition; track the dependency. Do not quietly change the all-Checks exit rule |
| 6 | **Forge/Static economy (B4)** | **Not guessed.** Implement only accepted recipes/costs/outputs; new economy rules stay a decision | Forge-dependent work stays blocked and labelled |

**Already settled — I will not re-ask:** transient vs latched vs macro persistence
(§5.4a, owner ruling 2026-09-05); Epsilon's shell/theme/name selection (§30.1);
capability-gate legality (§29.5a — decided; code must catch up); water deferred.

---

## 7. Handoffs (prepared, not dispatched — availability unconfirmed)

**Dess — design development + assigned bridge work.** She has not accepted this;
nothing here assumes she has.

| # | Item | Blocks |
|---|---|---|
| D-1 | **B2 acquisition contract** developed against §5's five requirements | **M2 complete** |
| D-2 | `capability_guarantee` case C producer (`established_in_zone`) | M2 complete |
| D-3 | `DoorAssignment.requires: Capability \| None` — lights up a complete, dead client path | Capability gates |
| D-4 | `RailNetwork` schema + validation (docks/links/carrier at anchors) | Nothing in P0–P4 — engine builds against the interface, provisional and labelled |
| D-5 | Objective-binding vocabulary for Epsilon (C6/F4), bounded and closed | Second binding at M3 |
| D-6 | 0.4 save representation (G1); legacy-migration separation (G2) | G-workstream |

**If she is unavailable:** P0–P4, M1, M2-mech and M3 proceed. D-4 becomes an
engine-local provisional interface with the exact shape she would own. D-1/D-2/D-3
stay blocked — I will not invent progression policy.

**Arty — 3D models only.** Functional layout, sight lines, machinery behaviour and
runtime feedback stay with Prod. Asset brief per item: dimensions, pivot, attachment
points, required states, collision/gameplay constraints. Items: skiff deck + shield,
dock platform, FORWARD/BACK receivers (arrow shape **and motion**, never colour
alone), rail span in aligned/misaligned states, gantry + grapple anchor, alignment
control. **Readable blockout ships first**; final art is for the visual verdict, not
for testing whether the interaction is worth developing.

---

## 8. Verification

- Per stage: focused suite plus a negative control that distinguishes broken from
  repaired.
- New gates: `godot-passenger-carry`, `godot-rail-network`. Extend
  `godot-exit-reach` / `godot-traverse` where the major touches them.
- Full frontier (Python + 27 Godot suites) at stage boundaries and before any
  checkpoint claim; source tree fixed during final verification.
- **Continuous play evidence kept separate** from placed-near-target, pre-unlocked,
  direct-handler and synthetic-state runs. The review's §11 proof sequence followed
  end to end, including the counterexamples (missing track refuses travel; blocked
  command issues no movement; return wrongly bound to S1; recall across a missing
  link; a reset duplicating the grant).
- Ledger `docs/ledgers/HUGE_BATCH_LEDGER.md` in the package's format:
  planned / active / implemented / verified / blocked / unrun / superseded.
  Implemented ≠ verified ≠ fun. Raw logs retained, not tails.
- 0.3 comparison build untouched and launchable throughout; 0.4 on its own
  development line with separate saves.

## 9. Not doing

No save migration. No AP/Static/Forge economy guesses. No production-default changes.
No new map design — the F5 map is preserved. No swimming, crouch or prone. No content
expansion past M3 before you have played it. No heartbeat, watchers, subscriptions or
scheduled follow-ups.