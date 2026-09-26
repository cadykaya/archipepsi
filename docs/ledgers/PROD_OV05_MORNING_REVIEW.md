# Overnight 05 — morning review, filled in by Prod

The pristine template is `ov05/05_MORNING_REVIEW.md`, and it is
unchanged. Sections 1–3 are answered here. Section 4 is yours, and is
kept as written. The per-unit status is in `PROD_OV05_READY_QUEUE.md`.
Every row's detail is in `PROD_OV05.md`.

## 1. Lead with the playable change

**Tested revision:** `46bf023`, frozen for the whole run (see
`ov05_evidence/FROZEN_RUN.md`).

**Pushed revision:** the handoff commit directly on `46bf023`, on `claude/archipepsi-0-4-blindside`.
It adds documents and the zone audit's own provenance stamp on top of
the tested revision.

**Last known-good comparison:** `330c555`, the delivered handoff, taken
as delivered. Its frozen run was `57e962e` (56/56). The start is
preserved at `review/ov05-start-330c555`.

**Fresh launch:** `Diagnostic Campaign - Candidate (Windows).bat`, or
`cd bridge && python3 -m archipepsi_bridge.diagnostic --candidate`. The
first run makes the `candidate` slot, separate from your campaigns, and
stages nothing. Add `--new` for another fresh slot once one exists.

**Resume launch:** the same launcher again. It continues the candidate
slot under the profile that made it, and a restart comes back where you
left it (see the Persistence row). A different profile is refused with
nothing touched. An ordinary launch does not continue the candidate
slot.

**Provider / AP backend / scale / candidate profile:**

- Provider: the deterministic fallback, labelled. `ANTHROPIC_API_KEY` is
  unset, so no live model ran.
- AP backend: the mock multiworld.
- Scale: default.
- Candidate profile: transport, the reversible lever, P14's latch, the
  three minors and the consumable slot.

**Why the run stopped:** the owner's instruction on the remaining usage allowance: finish the running frozen verification, deliver the essential handoff, then stop. Ready work remains, listed in the filled queue and at the frontier head.

**What the player can do now that they could not at `330c555`:**

- Pick up a heavy power cell by hand, with its speed penalty and
  blocked slots. Carry it through a doorway into the next room, and
  install it in a socket that opens the way on.
- If it is dropped in the wrong place, destroyed or knocked off the map,
  it comes back as the same object and without solving anything.
- Pull a lever in one room and watch a doorway in another open, then
  close it again. It waits for you to step out of the doorway before it
  closes, and it stays as you left it across a restart.
- Meet all three minors inside composed Zones, each with its Check and
  its way back:
  - the Unweighted Switch, with its LIGHTENED crate;
  - the Counterfire Arcade, with its gunner and service shutter;
  - Passing Platforms, with a lift and shuttle that survive a restart
    mid-route.
- Use a consumable slot on the candidate. Its item is acquired, folded,
  equipped, spent and kept through the normal path.

The twelve manipulation verbs, the mass fields and the `rooted` and
`anchored` Statuses now work in the engine. **No Echo the fallback makes
delivers them yet**, so a player cannot reach them in the candidate.
That is the O05-08.5 boundary. The Blindside payoff is not playable; it
is blocked on three named policies.

## 2. Review the connected experience

| Question | Answer / evidence |
|---|---|
| Physical object | **Yes, physically.** The real Player picks up the 40 kg cell with the interact ray. It is carried continuously across the c004 → c005 connector and never recovered in between. It is installed at an `ObjectSocket` by `interact`; being nearby does nothing, and a wrong part is refused. It keeps one identity through drop, destruction, out-of-bounds and restart. `godot-transport` 106; `godot-transport-live` seed / place / install / restore. |
| Reversible consequence | **Yes.** The lever in c002 (source) shows PENDING, then ACCEPTED when the bridge's snapshot carries the new value. The doorway into c003 (remote) opens, and the lamp in c003 lights. Reversal closes it. With the player in the doorway it reads "CLOSING QUEUED · DOORWAY OCCUPIED" and waits. The value survives a restart. It is a variable, not a new permanent latch. `godot-reversible` 32/32; `godot-reversible-live`. |
| Featured Echo | **Not delivered: BLOCKED.** Each seam runs separately: claim, confirm, foreign delivery, interpretation, equip and grapple. The integrated loop at the junction is blocked on B-1 (a featured Check can hold your own item, which mints nothing), B-2 (nothing makes the Echo supply the function) and B-3 (no pre-seed AP representation). Nothing was faked: no foreign item, no walking bypass, no `blindside` step. M2 stays partial; the physical loop exists only in the labelled development scenario. The mock multiworld was used; no real multiworld proof is claimed. |
| Existing minors | **All three entered through candidate composition.** Unweighted Switch and Counterfire Arcade are in zone_001. Passing Platforms is in zone_002, because each Zone hosts two and the offer turns (a selection rule of this lane, recorded for Dess). Alternatives and recovery survived: the arcade's west stair, and a Static Pulse at the receiver face, with the gunner dead. The switch's bolt holds after a restart, even with the crate back on the plate. Passing Platforms' fast and patient routes, RESET by motion, and a shuttle stopped halfway that restores stopped. The standalone development rooms still pass. |
| Persistence | **The bridge process and the client were both stopped and restarted**, on a disposable save read back from disk each time. `godot-candidate-live` restarts eight times across its phases. After each restart: the cell was where it was left (or seated), the lever's doorway was open at load, the arcade's release held, the switch's bolt held, and the shuttle was where it stopped. Nothing was announced twice. |
| Consumables | **Candidate-only.** `CANDIDATE_ACTION_SLOTS` admits the slot; `IMPLEMENTED_ACTION_SLOTS` and production defaults are unchanged. Creation is the provider's own reading of the source (Bombs → bombs), acquired, folded, slotted and spent. Accepted-use accounting uses the generation plus use-index guard. The refill policy (refill when the deployment target changes) is **provisional**: it was proposed by this lane and not decided by the owner. A Bomb Bag after Bombs is a sequel (Bombs Mk II); capacity as an upgradable field is an open owner question. A live Godot run of the naturally acquired bomb is not claimed. |
| New expressive systems | **Verbs (runtime only, direct invocation, 95 checks):** PUSH, PULL, HOLD, ALIGN, SETTLE, TETHER, PIN, ROTATE, ATTACH, DETACH, LIGHTEN_FIELD, ANCHOR_FIELD, and one per-caster relations ledger. Consumers include the real plates, doors, hinges and constraint solver. Nothing delivers them (O05-08.5). **Graph kinds with consumers:** `PULSE_BUTTON`, `OR` (EX50-033's chain), `TIMER` and `SHOOTABLE_TARGET` in PULSE mode (EX50-021's chain), on top of NOT and LATCH. Signal verbs: none. **Status-target pairs:** `rooted`@enemy and `anchored`@enemy, on movement, knock, verbs and per role; played once through a real on-hit in a declared arena with an injected Echo. **Compounds:** none. |
| Art | **Nothing bound, nothing promoted, and Arty stayed paused.** No approved and delivered enemy or machinery models exist to bind, and no candidate pack is available to review. D-11's lookup is unchanged. |

## 3. Evidence to inspect first

- **The continuous acceptance log:** `godot-candidate-live` in the frozen
  run (`logs/` in the ZIP). It has one case identity per phase. The
  first phase generates `zone_001` through the real path, and later
  phases restart the processes.
- **Before/after and restart captures:** `make candidate-shots` frames
  through the player's camera (in the ZIP).
- **Isolated component tests vs the normal path:**
  - The verb suite (`godot-verb-runtime`) is direct invocation by
    design, and says so.
  - The Status suite's last case is the real input path with an injected
    Echo, and says so.
  - Neither substitutes for a normal-path claim; none is made for them.
- **The raw full-run summary:** `ov05_evidence/FROZEN_RUN.md`, and
  `summary.tsv` with every step's raw log in the ZIP.

## 4. Human playtest questions

These are questions for the owner, not claims the agent can answer alone:

- Did the new tool or carried object change a decision, or merely add errands?
- Could you predict what the control would affect, and recognize the consequence when returning?
- Was there an intelligible recovery after a failed attempt, without losing unrelated progress?
- Did an enemy arrangement make movement/target priority interesting, rather than merely increasing time or damage?
- Did the environment help you recognize where you were? Did the map preserve known facts without solving the room for you?

*(Yours to answer. Prod has not answered these.)*

## 5. Things that must not be waved through: how this run stands

- **No old save migrated.** No original foreign item was reassigned.
- **No undeclared physical AP gate:** the featured gate stays
  unavailable.
- **No silent guaranteed bypass, no hidden item injection, no disabled
  required obstacle.**
- **No name advertised as implemented.** Every Status and verb claim is
  per kind and target, and support is declared in the same change as
  its effect.
- **No art promoted.**
- **No live model and no live multiworld claimed** (fallback and mock).
- **No Windows execution claimed:** the `.bat` was read, and the Python
  it delegates to is tested.
- **The full-revision verification is the frozen run at the tested
  revision above.** Documents added after it are named as such.

## 6. Next assignment, from the evidence (Prod's suggestion; the choice is yours)

- **Decide O05-08.5's representation question** (atoms, or an interim
  representation). It is what turns twelve working verbs and two fields
  into something a player can earn.
- **Settle B-1..B-3** for the featured Echo. Each is a policy; the
  engine work waiting behind them is listed in the ledger.
- **Continue O05-09**, where a consumer exists:
  - `anchored` and `lightened` on the player: its class plates and knock
    exist;
  - `brittle`: its consumers exist, but it needs an object-targeted
    delivery decision.
- **O05-12**, the encounter work, not started.
