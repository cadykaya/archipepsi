# D-19 — The charger: what it is, and why fighting it is fun

**Dess → Arty and Prod, for Skyiah. 2026-10-08. A design study, not
approved for building.** This is design and evidence only. Nothing here
commissions AI work or the encounter: that is gate G3, after Skyiah has
played the G1 room. The goal is a creature foundation Arty can draw from
before she models anything.

Source refs:
- **[G0]** = `review/impact-lab-g0` `c45086e1`.
- **[Art]** = Arty's batch 030 review, `docs/art/review/batch030/README.md`.

---

## 1. What exists today (measured, not designed)

| Fact | Value | Ref |
|---|---|---|
| Brief | "one telegraphed rush" | [G0] `bridge/archipepsi_bridge/schemas/constants.py:1074` |
| Stats | 40 HP; rush hit 14 (player has 100 HP); cooldown 3 s; walk 3 m/s; reach 14 m | same, `:1092` |
| Wind-up | 0.7 s, the longest on the roster | [G0] `godot/scripts/enemies/enemy.gd:90-94` |
| Rush | 1.1 s at 13 m/s (about 14 m), straight. A wall ends it, then recovery. | `enemy.gd` ~1150-1172; `constants.py:1191-1195` |
| Recovery | 1.4 s, "helpless … the whole counterplay" | `constants.py:1194-1195` |
| Job | `patrol` | `constants.py:1242` |
| Body envelope | 0.90 w × 1.05 h × 1.90 m long | [G0] `godot/scripts/autoload/constants.gd:293` |
| Arty's existing read | "a battering ram — the long axis *is* the attack". Strike surface: the whole leading face. Weak side: the open rear. | [Art] `:38, :145` |

**Why it failed in D.**
- The Static Pulse does 6 damage every 0.35 s, about **17 per second**. So
  the charger's 40 HP lasts **about 2.3 s**.
- From notice at 18 m it walks toward the player at 3 m/s until it is in
  rush reach. That takes about 1.3 s, then the 0.7 s wind-up, so its
  first rush starts **about 2.0 s** after it sees you.
- A player standing still kills it at about the moment it would have
  charged. That matches what Skyiah saw: it died without ever mattering.
- **More HP would only make a dull fight longer.** The fix is *when* it
  is vulnerable, not how much health it has.

---

## 2. Identity: the shunter

**What it is.** A station freight machine. Shunters push freight carts
and crates along the deck's guide lanes, between loading bays, butting
loads into their docks with a broad hinged plough face. They are low,
long, heavy and patient. They walk on four short piston legs rather than
wheels, because station decks are full of thresholds and steps.

**Why it fights.** The Crossing scrambled its routing. Its job is still
"keep the lane clear and the freight in its bay". But anything moving
through its lane that isn't freight now reads as an obstruction to clear.
It doesn't hunt the player; it clears them out of the way.

That gives everything it does a reason:
- it rushes in straight lines (lanes);
- it stops dead against walls (bay ends);
- it checks its work afterwards (recovery);
- it ignores you once you're out of its lane.

**What it did before you arrived** (what the player can watch from cover):
- **Tending.** It noses along a stack of crates and butts a stray one
  back into line with a short shove.
- **Docking.** It backs into a wall charging point and settles. Its lamps
  dim and its plough rests on the deck. It is slow to wake.
- **Patrolling its lane.** End to end, with a pause and a head sweep at
  each end. This is the existing `patrol` job, given a purpose.

**What we take from the Houndeye, and what we leave.**
- **Taken:**
  - a routine you can watch before it notices you;
  - a sound language that tells you its state;
  - a body whose shape explains its attack.
- **Not taken:**
  - the tripod body;
  - the sonic blast;
  - the pack attack;
  - anything copied from its model or behaviour.

**Its role among the other enemies: "the mover".** The ranged enemy
punishes standing in the open. The bulwark has to be flanked. The
shunter makes the player *leave where they are*:
- **With a ranged unit,** it flushes you out of cover into a firing line.
- **With destructible cover,** it changes the arena (§4).
- **With a beacon nearby,** everything near the beacon gets worse, the
  shunter included.

Its verb is **dodge and punish**, distinct from the bulwark's **flank**.

---

## 3. The fight: one decision, repeated

```
TENDING / DOCKED / PATROL --sees you (clear line)--> HORN (0.3 s)
   --you're within its rush reach--> BRACE (0.7 s) --> RUSH (1.1 s, 13 m/s, no steering)
   --hits you (14) | misses and overruns | hits a wall or cover--> RECOVERY (1.4 s) --> re-acquire
   --you're beyond its reach--> TROT to close, plough up (exposed), then BRACE
```

**The plough is armour only while it commits.**
- **During brace and rush,** the lowered plough takes reduced damage from
  the front: proposed 25 %. Shots spark and clang off it, in the same
  "too light" language as the impact shutter.
- **Sides and rear always take full damage.**
- **While tending, docked, trotting or recovering,** the plough is up and
  the whole body takes full damage.

So:
- **Standing still and shooting a committing shunter** is weak, and you
  get hit. Standing still becomes a risk.
- **Sidestepping, then punishing the recovery,** pays.
- **Hitting it before it notices you** (tending or docked) pays even
  more. Watching first is rewarded.

**Measured target for G3** (provisional; no numbers are hard-coded here):
- 1.4 s of recovery is about 4 Pulse shots, about 24 HP;
- with the plough up for the opening volley, that comes to about two
  charge cycles for a player who dodges, and fewer for an ambusher;
- **HP is the last thing to touch.**

**Hit reactions, every hit visible and audible:**

| Hit | Reaction |
|---|---|
| Plough | Spark and clang |
| Body | Jolt and servo squeal |
| Rear, during recovery | A stagger: recovery +0.4 s, once per recovery |
| Any hit, during the rush | Doesn't stop it. It's a ram, and commitment is its identity. |
| A heavy hit (≥12, the shutter's own rule), during the brace | Knocks it out of the brace and back to re-acquire. Heavy hits matter everywhere. |

**First contact.**
- **Notice needs a clear line of sight.** Today notice is a distance and
  passes through walls ([G0] `enemy.gd`). For this one enemy it should
  need a clear view.
- **The horn is information.** Anything in earshot that hears it turns
  toward the sound. That is the whole of the "pack": a horn means it's
  coming. No group AI.
- **If you're already inside its reach** when it sees you, it braces
  straight after the horn. It doesn't walk first.

---

## 4. Interactions with the environment

| Interaction | Today | Proposal (a hypothesis until G3) |
|---|---|---|
| **Wall or full cover** | The rush ends, then recovery (`enemy.gd` ~1166). | Keep it. A wall behind you plus a sidestep is a free opening, and the arena should offer such walls. |
| **Orange crates** (`DestructibleCover`, 40 HP) | The rush ends against one, like a wall. | The rush **breaks the crate and stops**. You lose the cover, but get the opening. The fight changes the room. |
| **Impact shutter** (G1's 1,000 J rule) | — | Give the shunter a physical mass of about 150 kg. A rush brings about 12,700 J, so a baited rush breaks a rated shutter. That would be **the first encounter that reuses a puzzle rule**: the Impact Relay with a shunter, where you can throw the weight, or make the shunter be the weight. After G3. |
| **Ramp edge or ledge** | Unknown | A rush that overruns an edge drops it to the lower level: longer out of the fight, no damage. The Yard's ramp becomes a tool. |
| **Its dock** | — | A docked shunter is the ambush opportunity. A dock is a wall fitting with a green power socket, and the green belongs to the dock, not the creature. |
| **Crates it tends** | — | Its butt is a small push of the crate through the existing `receive_impulse`. That shows its strength before it is ever aimed at you. |

**Level-design needs:**
- straight lanes of at least 14 m;
- something solid to miss into;
- not cramped rooms;
- one shunter per fight space at first.

---

## 5. A foundation for Arty

It must fit the existing envelope (0.90 × 1.05 × 1.90 m) and her batch 030
read: the ram face strikes, the open rear is the weak side. Arty may
redraw everything else.

- **Silhouette.** Low, long and front-heavy.
  - **The plough:** a hinged face covering the full 0.9 m width. It
    visibly **drops 15–20 cm** into a brace. The plough position is the
    state, readable from 20 m.
  - **Legs:** four short piston legs with a trotting gait, so it reads as
    alive and not a cart.
  - **The rear:** an open frame showing its power pack and vents. This
    is the weak point; it glows warm white during recovery.
- **Head.** A low cluster of two or three lamps under the plough lip.
  White or amber while working, **red** when alerted, braced or rushing,
  with red on the plough's edge too.
- **Colour language.**
  - **Red** is the enemy cue.
  - **No orange bands:** orange means breakable.
  - **No green on its body:** green belongs to its dock's socket.
  - **No yellow-black stripes:** those mean hazard.
- **Station identity.** Pale freight livery, stencilled lane numbers, and
  scuffs and dents on the plough from years of butting crates.
- **The Crossing layer.** Its scrambling should show as Arty's chosen
  Crossing treatment riding on or through the frame. Her direction
  studies decide how.
- **Animation states:**
  - idle sway, tending nose, crate butt;
  - docked settle and slow wake;
  - horn;
  - brace (plough drop, legs splay, scrape);
  - rush gallop;
  - wall impact (shudder, steam);
  - recovery (plough lifting, rear exposed);
  - front-hit spark, body jolt, rear stagger;
  - death: it powers down, the plough drops, the lamps fade, and it skids
    a metre if it was rushing.
- **Sound palette** (timing belongs to Prod's runtime; Arty only needs to
  know it exists):
  - servo whir and chirps while working;
  - a two-tone horn;
  - the scrape;
  - the rush rumble;
  - the wall clang;
  - a recovery hiss;
  - a power-down.

---

## 6. For later, at G3 (not commissioned)
**One shunter in the Upper Yard, enemy-free otherwise.** Measure:
- time from first sight to first brace;
- how many rushes before it dies, for a standing player and for a
  moving one;
- how often the player moved;
- hit and miss counts.

Then Skyiah plays.

**A second role** is tried only if one shunter is fun.

---

## 7. Decisions for Skyiah
1. **Identity.** A station freight machine scrambled by the Crossing
   (recommended), or a Crossing creature from somewhere else?
2. **Plough armour while committed,** instead of more HP? Recommended:
   yes.
3. **A rush breaks orange cover** (and stops)? Recommended: yes.
4. **Shunter-into-shutter** as the first combined encounter after G3?
   Recommended: yes.
