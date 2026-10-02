# D-12 — room cards for the three hosted minors (H-RELEASE-C)

**Dess → Prod, 2026-09-24.** This is the contract that H-UNWEIGHTED,
H-PASSING and H-COUNTERFIRE consume. It covers the ten fields of
`03_DELIVERY_PLAN` §4, the authority's rules and what each room must
prove in play.

**It is not a physical design.** It says what must be true. Where §4
asks you to "state that proposal before rebuilding", the proposal is
yours.

Sources:
- EX50-033, EX50-021 and EX50-011 as originally specified
  (`post_playtest_v1.0/references/`);
- `schemas/minors.py`;
- the owner's PT-04 to PT-07.

---

## The authority's rules, for all three

**R1 — the goal accepts any legal arrival.** All three specs accept
access the recorded latch never sees:
- EX50-033 §6: a strong jump before the crate;
- EX50-021 §6: "the goal should accept that access";
- EX50-011 §6: grapple or blink to the carrier.

So **the bridge does not gate a minor's Check on its latch.** The bolt,
release and stair are the return and the permanence, not the reward.
Gating on them would refuse legal alternates or impose the input order
the owner ruled out. Pinned in `bridge/tests/test_minor_release_boundaries.py`.

**R2 — world and authority agree through the world.** The bridge
accepts a claim whenever the world lets the player perform the goal
interaction. So the world must allow it **only on the goal gallery,
G**:
- nothing through glass;
- no pickup radius reaching through geometry;
- nothing from below or from the rail;
- no teleport target landing inside the reward's reach from outside G.

This is the fix for PT-05/PT-06's "directly collectible Check", and it
is physical.

**R3 — the return exists after every accepted arrival.** Each room's
return latch is operated from G, or fires on arriving at G, so a player
who arrived by an alternate still creates the way back:
- Unweighted: the bolt;
- Counterfire: the release;
- Passing: the stair.

It never depends on an optional movement item. Test the return after
**both** reference and alternate arrivals (PT-07).

**R4 — nothing here is an AP gate.** Each reference route needs only
the guaranteed kit:
- Unweighted's `lightened` is the room's own local source, not an AP
  grant;
- Counterfire's baseline is the west stair plus an ordinary shot;
- Passing needs walking and a short jump.

The minor's Check therefore needs no AP logic change. A mobility
alternate is an accelerator and is never required.

**R5 — persistence is as specified.**

| Scope | What |
|---|---|
| room-persistent | the return latches: `minor_<room>/{bolt,release,stair}` |
| package-local | the crate's position and the carrier poses |
| ephemeral | `lightened` and the receiver timer |
| outside any room | a claimed Check stays claimed. Replaying the room grants nothing twice (M-2, pinned) |

---

## Unweighted Switch (EX50-033), hosted as `minor_unweighted_switch`

| Field | Card |
|---|---|
| **Arrival read** | Open upper doorway, sill too high, a crate with a useful top. The recess reads as a plate, and the shutter visibly belongs to it |
| **Visible objective** | The goal on G, beyond the upper doorway, readable from the arrival floor as *up there, through that door* |
| **Actual obstruction** | The sill height, plus the HEAVY plate that closes the shutter while the crate — the needed step — sits on it |
| **Useful controls/tools** | The crate's service drive (reversible, so the relation is testable); the local `lightened` applicator; the bolt on G |
| **Meaningful state** | Crate on the plate: shutter closed. Crate `lightened` in place: shutter open *and* the step still there. That is the property conflict to preserve |
| **Valid alternates** | A strong jump or mobility tool before the crate goes in; a lighter object that fits the recess (the plate reads class, not an id); standing in the closing shutter (interlock). None is punished |
| **Refused cheap bypasses** | Reaching the goal from outside G, or via rail/geometry/pickup reach. The owner walked to the Check (PT-05) |
| **Reward transition** | The goal interaction on G; the Check is claimed there. The bolt does not gate it (R1) |
| **Return** | The bolt adds the return stair. The gallery also drops back through the return gap. Both work after an alternate arrival |
| **Reset/reload** | Crate is package-local; `lightened` is ephemeral and never cached as "plate off"; the bolt is persistent. Restore puts the body somewhere safe after recomputing the shutter |

**Owner-driven repairs (PT-05):**
- make the blocked upper route and the goal legible from a useful view;
- remove incidental bypasses;
- cut pointless waiting — slow drive speed is not puzzle depth;
- make the crate read as guided service hardware, not a breakable
  ordinary box;
- show what `lightened` changed.

## Counterfire Arcade (EX50-021), hosted as `minor_counterfire_arcade`

| Field | Card |
|---|---|
| **Arrival read** | The gunner's firing lane, the hooded receiver behind the bait stance, and why a reverse shot from the arrival cannot reach it |
| **Visible objective** | The goal on the upper flank, beyond the service shutter |
| **Actual obstruction** | The service shutter, opened for 8 s by a valid receiver hit |
| **Useful controls/tools** | The bait stance and the alcove; the receiver (any real hit, whoever fired it); the manual release on the flank |
| **Meaningful state** | Receiver hit → TIMER open (ephemeral). Manual release → a permanent service route |
| **Valid alternates** | West stair + fixed cover + ordinary combat to the gunner's side, then a baseline shot at the receiver's face or the reachable release; a mobility crossing during the opening; a legal landing on the flank that skips the receiver. **Kill-first is legitimate unless the instance review shows otherwise** |
| **Refused cheap bypasses** | Claiming from outside the flank; an "emergency" control that opens the reward without the room's relationship. PT-04's shot target has to be identified *before* anything is removed |
| **Reward transition** | The goal interaction on the flank. Not gated on `release` (R1), and not on the gunner's fate: a dead gunner strands nothing (pinned) |
| **Return** | The release adds a fixed stair back down, after any arrival. A dead gunner leaves the west stair and a shot at the receiver's face |
| **Reset/reload** | The timer is ephemeral, and saving mid-opening must restore a safe position, not a body inside a closing wall. The release is persistent. The gunner follows encounter persistence (D-06, `defeated`) |

**Owner-driven work (PT-04):**
- **First identify the instance the owner played.** Record occurrence
  and Zone ids on the next capture.
- Only then decide whether the target was the intended kill-first
  fallback, an unrelated activity, an exposed control or a bypass.
- Make gunner, receiver, shutter and reward read as one relationship,
  without printing the answer on entry.

## Passing Platforms (EX50-011), hosted as `minor_passing_platforms`

| Field | Card |
|---|---|
| **Arrival read** | Both carriers' paths, with G visible beyond the horizontal route, and the upper shelf plainly *not* the destination |
| **Visible objective** | The goal on G, reached by transferring between moving carriers (not by waiting on one). §4 asks you to state whether a visible machinery-locked cabinet or a destination mechanism is the right objective **before rebuilding** |
| **Actual obstruction** | No carrier alone reaches G. The lift V and the shuttle H meet only at the transfer plane |
| **Useful controls/tools** | Call / reverse / hold (STOP) for H; V's launch; RESET at arrival or the shelf. **Group the controls and label the actions** (PT-06) |
| **Meaningful state** | Carrier poses and holds, package-local, at rest only (`carrier_states`) |
| **Valid alternates** | STOP-and-transfer (the patient solution); a faster transfer; a qualified grapple or blink to H where range and landing permit. **The generator must not widen separation to erase them** |
| **Refused cheap bypasses** | A **baseline jump that reaches G or the goal directly** (§4 calls this first-order); pickup reach from the shelf or the floor |
| **Reward transition** | The goal interaction on G. Walking onto G releases the service stair (R3); the claim is not gated on it (R1) |
| **Return** | The service stair to the arrival floor, released on **any** arrival at G. A missed transfer falls to the recovery floor, whose stair climbs back. **A teleport is not a return** (PT-07) |
| **Reset/reload** | Carriers restore at their saved poses before the player. No random phase on reload. The stair is persistent. Before completion, death restores the safe initial configuration |

**Owner-driven repairs:**
- **PT-06:** test baseline walking, jumping and pickup range before any
  movement power; make the release relationship readable at the arrival
  camera; tune only necessary travel.
- **PT-07 (urgent):** reproduce the return after direct pickup, early
  gallery entry, carrier displacement and normal completion. Decide
  whether the stair was absent, blocked, untriggered or illegible.
  Don't remove the parent fight or its reward identity to make hosting
  easier.

---

## What the bridge changes, and what it deliberately does not

- **Pinned now:** R1 and the dead-gunner rule, as tests of existing
  behaviour (`test_minor_release_boundaries.py`).
- **No new claim gate, no inert field.** `MinorContract` already
  declares the return latches and says how the player gets back
  (`latches`, `recovery`); a field for alternates would have no
  consumer.
- If your rebuild changes which control releases the return or where
  the goal stands, say so here: the contract text and the `latches`
  entry move with it, after the handback.
