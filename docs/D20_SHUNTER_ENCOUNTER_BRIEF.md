# D-20 (revision 2) — One Shunter: a combat encounter built around decisions

**Dess → Prod and Arty, for Skyiah. 2026-10-10. Build-ready brief for the
first combat playtest. Isolated experiment, not approved for the
campaign.**

This brief has one Shunter in one arena, with the base kit, the Static
Pulse and the five range weapons as built. **Not included:**
- a new AI framework;
- a second enemy;
- new weapon families;
- campaign changes;
- an increase to the Shunter's HP.

Revision 1 (`a2f0efd8`) is in history; §11 lists what changed.

**Sources** (code read for this revision):
- **[E] / [C] / [P]:** `enemy.gd`, `constants.gd` and `player.gd` on
  `review/five-weapons` `a25f2f68`. These are unchanged since readable
  D, and since G1.
- **[5W]:** `docs/reports/2026-10-10-five-weapons.md`, the weapons as
  built (build `3fc8cf0c`).
- **[AR]:** Arty's `docs/art/reports/2026-10-09-shunter-pose-study.md`
  (art branches, 2026-10-09).
- **[SS]:** `godot/scripts/gameplay/service_shutter.gd` (SPEED 2.2,
  ACCEL 4.0).
- **D-19, D-21:** the Shunter's identity, and the weapon families.

Every number that is a guess, not a reading, is flagged **ASSUMPTION**
and collected in §10.

---

## 1. The fight in one breath

From a glass booth you watch a low freight machine potter between a
crate stack and its charging dock, nudging a stray tote back into line.
You pick your moment and your gun, and step out. It rears, flashes its
brow lamps, sounds its horn, and drops its plough. Now every few
seconds you face the same question:

> **It's bracing at me. Do I step aside in the open, bait it into
> steel, close the freight gate in its path, or hit it hard enough to
> break its brace?**

Steel is where you kill it. Open floor only chips it. A heavy gun buys
safety or tempo, never a free kill. The right answer depends on where
you are and what you're holding.

**The tuning target** (§4): about **two good decisions** kill it. **One
great decision**, a pillar or gate bait with the right gun, can. Standing
still loses about 40 % of your health.

---

## 2. Before the fight: a freight machine, not a monster

| Behaviour | Spec | Status |
|---|---|---|
| **Tend** | Walks its declared lane, crate stack (x −6) ↔ dock (x +6), at job speed (3 × 0.45 = 1.35 m/s, [C] :77). At the stack: a 1.5 s nose-down and a butt that nudges a loose 20 kg tote (`receive_impulse`). | Patrol exists, but with random ends around a post ([E] :1009-1041). **Declared ends are new.** |
| **Dock** | 3 s at the dock: backs in, body lowers 4 cm, amber lamps dim, a cable from the dock's **green** socket. Faces the wall, so its back is to the booth. | New (placeholder) |
| **Notice** | Within 18 m ([C] :72), **or** when hit, **or** (new) when it hears a Mass Driver charging within 18 m. That last one is a freight machine listening for machinery. | Distance exists ([E] ~676-698). Hit and charge-hearing are **new** (test profile). |
| **Horn** | 0.6 s: rears (body +6 cm, nose +6°), plough to its highest, a 0.15 s white brow flash, two-tone horn. Its plough is still up, so it takes full damage: the ambush window. | New ([AR] B pose) |
| **Back to work** | If you are more than 18 m away for 4 s, interest lapses and it returns to its lane. That is the existing "OUT OF MIND: back to work" branch ([E] ~730-737; `ENEMY_INTEREST_SECONDS` 4, [C] :75). | **Exists** |

**Two ambush openings for the player:**
- shoot it while it tends, facing along its lane;
- shoot it while it's docked, back toward you.

Both are reachable from just outside the booth door (§6).

---

## 3. The combat loop

```
WORK --notice--> HORN 0.6 s --> CLOSE (3 m/s, stops 11.2 m out) --> BRACE 0.7 s --> RUSH ≤1.1 s
   RUSH ends on: the player (0.7 s) | open floor (1.1 s) | crate (1.1 s, crate breaks) | pillar, wall or gate (1.8 s)
   --> RECOVER --> RE-AIM (turn 180 °/s, plough up) --> CLOSE or BRACE
```

**Kept from revision 1 / today:**

| Thing | Value | Ref |
|---|---|---|
| HP | 40 | [C] :272 |
| Rush damage | 14 + a shove of about 8 m/s along the rush (`Player.receive_knockback`) | [C] :272; [P] ~1430 |
| Wind-up | 0.7 s, direction locked at its start | [E] :94, :839-849 |
| Rush | 1.1 s at 13 m/s (≈ 14.3 m), unsteerable. Nothing interrupts it. | [C] :40-41 |
| Cooldown | 3.0 s from the start of the wind-up | [C] :272 |
| Approach | 3 m/s, stops at 11.2 m, rushes at ≤ 14 m with a clear line | [E] :1267-1270 |
| Plough armour | While closing, bracing and rushing, frontal hits (inside dot 0.35) take **25 %**. Reuses the bulwark's `_frontal_shrug` path. | [E] :1402-1414 |
| Turning | 180 °/s when not committed | new (test profile) |
| Lane telegraph | A floor strip, 14.3 m along the locked direction, drawn on `telegraph_started` | [E] :1797-1806 |

### 3.1 Recovery windows, retuned for the new weapons

The weapons as built do 21–25 damage per second; the Pulse does 17
([5W]). Revision 1's windows were sized for the Pulse, so I **shortened
them instead of raising HP**:

| What stopped the rush | Rev 1 | **Rev 2** | What the player sees ([AR] B) |
|---|---|---|---|
| The player (a hit) | 0.7 s | **0.7 s** | Plough lifts fast, a short plume, back to re-aim |
| Open floor (a miss) | 1.4 s | **1.1 s** | Nose dug in −9°, rear legs off the deck, a 15–20° skid, lamps dim |
| Orange crate | 1.4 s | **1.1 s**, and the crate bursts | The crate bursts, then the same skid |
| Pillar, wall or closed gate | 2.0 s | **1.8 s** | **Crumple:** the plough slams flat on the steel, the body jolts back 0.3 m, a burst of steam (not in Arty's study; placeholder) |
| Back-hit stagger (+0.4 s) | yes | **removed** | Replaced by heavy-hit reactions (§3.2), which change tempo, not time |

**In every recovery:**
- the plough folds high (lip 0.48 m, −30°) and the lamps go off;
- the two vent flaps open by 0.2 s, and a warm plume and rear glow rise;
- the plume fades over the **last 0.2 s, so the closing window is
  visible**.

### 3.2 Reactions to powerful shots

A **heavy hit** is any single damage event of **12 or more, measured
before armour**. That is the game's existing rated rule (`BreakablePanel`,
the Impact Relay shutter), so the same hit strength cracks a panel and
rocks a Shunter: one physical language. The plough soaks the damage,
not the force.

| State | A light hit (under 12) | **A heavy hit (12 or more)** |
|---|---|---|
| WORK / dock | Notice, then the horn | Notice. The horn is **delayed 0.3 s** while it's jolted sideways: a longer ambush window. |
| HORN | Full damage | Full damage, and a jolt |
| CLOSE | 25 % frontal, plough sparks and clangs | 25 % frontal; it **halts 0.3 s**, shoved back about 1 m through the existing `take_damage` knockback argument. Buys space. |
| **BRACE** | 25 % frontal, sparks, no effect | **Breaks the brace**, once per cycle: it rocks back and goes to RE-AIM (0.6 s, plough up). Its **next brace this cycle is locked**: sparks only, no second break. |
| RUSH | Sparks | Sparks and a clang. **Nothing stops a ram.** |
| RECOVER | Full damage, a jolt | Full damage, a big jolt, and the vents gust. **No extra time.** |

**Why breaking a brace is a choice, not a win button.** Breaking it is
safe, and gives one plough-up shot during the re-aim. But it spends your
heavy hit, gives no recovery window, and the next brace is locked, so
you still have to dodge it. You trade damage for safety and position:
use it to reach a pillar, or the gate.

### 3.3 The dodge, with corrected timing

**The hit rule:** contact with the body's volume. The player is hit when:
- they are within **1.0 m to the side** of the rush line (0.45 half-width
  + 0.4 player radius + 0.15);
- they are within **±1.35 m along it** (0.95 half-length + 0.4). This
  replaces revision 1's "ahead of its centre" only, which left the rear
  half without a rule.
- their feet are **below 1.05 m**.

Today's rule is any player within 2.8 m of its centre, in 3D
([E] ~1160), so a clean sidestep still gets hit and a jump never clears
it.

**Sidestep** (the main dodge): about 1.0 m of sideways movement. At the
7 m/s walk, that's about 0.15 s of movement. From the first tell you
have 1.6 s (rush from 14 m) or 1.06 s (from 6 m).

**Jump over** (an expert dodge). **Revision 1 contradicted itself:** §4
said "a ~0.1 s window", but the acceptance test said "start the jump
0.1 s before contact", which gets you hit. The corrected numbers:
- jump velocity 8 m/s, gravity 24 ([C] :115, :100);
- feet above 1.05 m from **0.180 s to 0.487 s** after take-off;
- the body overlaps the player for (1.9 + 0.8) / 13 = **0.208 s**;
- **so take off 0.18–0.28 s before the plough reaches you.** That's a
  0.10 s window, when the plough is about 2.3–3.6 m away (roughly two
  body lengths).
- **A jump started 0.10 s before contact is hit** (feet at 0.68 m).

The player lands behind it, facing its back, as the recovery starts.
**The fight never requires it.**

---

## 4. Different weapons, different openings

These use the weapons as built ([5W]). Damage per window assumes the
player starts firing 0.2 s into the window (**ASSUMPTION**), with the
plough up. Heavy hits are marked ■.

| Weapon (as built) | Heavy? | Hit recovery 0.7 s | Open miss 1.1 s | Pillar / gate 1.8 s | The decision it creates |
|---|---|---|---|---|---|
| **Pulse** (6, every 0.35 s) | no | 12 | 18 | 30 | Base kit. No brace break, so it lives on pillars. **≈ 2–3 windows.** |
| **Foundry** (15, every 0.72 s) | ■ | 15 | 30 | **45, kill** | **Break a brace, or keep the hit for the window.** 2 open windows, or 1 perfect pillar. |
| **Sightline** (8, every 0.34 s) | no | 16 | 24 | **40, kill if all land** | Precision from range: flank shots as it passes, the back during recovery, an ambush from the booth door at about 20 m. |
| **Switchback** (3.5, 7 a second, ≈ 80 % landing) | no | 11 | 20 | 34 | **Track it from the side as it thunders past.** Shreds orange crates fast, including your own cover. |
| **Bulkhead** (36 within about 4 m, about 18 at 10 m, every 1.0 s) | ■ when 3 or more pellets land | 36 | 36 | **72, kill** | **Get close to a stopped Shunter.** It halts 1–3 m past or beside you, so it's in range. Breaking a brace means standing within 4 m of a bracing ram. |
| **Mass Driver** (10–45 over its charge) | ■ at 12 or more | 45 | 45 | 45 | **Hold the charge while you dodge, release into the window: a kill (45 ≥ 40).** Its whine is heard within 18 m. Knockback shoves it during CLOSE or RECOVER. |

**Readings:**
- **Steel makes the kill.** A pillar or gate window kills with Foundry,
  Sightline (if perfect), Bulkhead or the Mass Driver. Open floor needs
  two windows. That puts **positioning and machinery at the centre**,
  which is what you asked for.
- **Light guns (Pulse, Sightline, Switchback)** never break a brace or
  jolt it. Their game is sustained damage plus position.
- **Heavy guns (Foundry, Bulkhead, Mass Driver)** add the brace-break
  choice.
- **The Mass Driver's one-shot (45 ≥ 40) is the known outlier.** Every
  window becomes a kill for a player who holds a charge through the
  dodge. This revision accepts it as the "one perfect shot" fantasy for
  the first playtest (**ASSUMPTION A5**). If it robs the fight, the knob
  is the Driver's damage against living targets (D-21 suggested a 30
  maximum), **not the Shunter's HP**.
- **Standing still with any gun** costs about one rush hit per cycle
  (14 + shove). With the Pulse that's about 3 cycles and about 42 HP
  lost.

---

## 5. The Shunter's look, reconciled with Arty's study

**Adopted: Arty's variant B** ([AR]), with four driven parts on a code
blockout:
- the body (lift and pitch);
- the plough (lip height and lean);
- a **brow lamp bar** about 0.6 m wide;
- a vent (two flaps, plus a plume and glow).

**The D-19 changes this accepts:**
- **Lamps move from under the plough lip to the brow.** Under the lip
  they were invisible from the front: 0 px changed on notice, at every
  distance.
- **The plough travels about 37 cm** instead of dropping 18 cm.
- **Notice gets the rear-up and white flash.** It is the weakest state
  at range, so the horn sound has to carry it as well.
- **The recovery plume may rise about 0.5 m above the envelope.** It is
  FX only, not collision.

| State | Duration (rev 2) | Plough lip / lean | Body | Lamps | Extra |
|---|---|---|---|---|---|
| Work / tend | — | 0.40 m / −8° | level, nose −4° at the stack | amber points, steady | legs visible |
| Docked | 3 s | 0.40 m / −8° | −4 cm | amber, dim | dock cable; green on the dock only |
| Horn | **0.6 s** (Arty used D-19's 0.3 s; the pose is reached in 0.1 s, then held) | 0.48 m / −14° | +6 cm, nose +6° | red, bright | 0.15 s white flash, horn |
| Close | — | 0.05 m / +12° | nose −4° | red | heavy footfalls |
| Brace | 0.7 s | drops to 0.03 m in the **first 0.25 s** | −7 cm, nose −4°, legs splay | red | red plough edge on the deck, scrape, floor lane |
| Rush | ≤ 1.1 s | 0.05 m / +15° | nose −6°, gallop | red | sparks along the lip (optional) |
| Brace broken | 0.6 s re-aim | snaps to 0.48 m | rocks back 0.2 m | flicker | clang |
| Miss (open floor / crate) | 1.1 s | 0.00 m / +20° | nose dug in −9°, rear up, 15–20° skid | red, dimmed | crate burst |
| Wall / pillar / gate | 1.8 s | flat on the steel | jolts back 0.3 m | off | steam burst (placeholder) |
| Recover | the window | 0.48 m / −30° in 0.3 s | −6 cm, nose +4°, legs buckled | **off** | flaps, plume and rear glow; fades in the last 0.2 s |
| Heavy jolt | 0.2 s | — | shoved 0.5–1 m, rocks | flicker | vents gust |
| Down | — | drops | powers down, skids 1 m if it was rushing | fade | power-down sound |

**Colour stays D-19's:**
- red: hostile;
- amber points: working;
- warm white: vulnerable.

**Not allowed:** orange bands, green on the body, yellow-and-black.

**Not studied by Arty, placeholders until she does:** docked, tend,
wall crumple, heavy jolt, death.

---

## 6. The arena: Freight Bay

```
                                 N
  +------------------------------------------------------+
  | [crate stack + tote]  ==== tend lane ====  [DOCK ●]   |  z -12   ● green socket
  |                                     ......green line  |
  |      [P1]                       :         [P2]        |  z -3    P = steel pillar
  |                     [ GATE ]<---:  (lever on both faces)  z  1   6 m frame, 3 m opening
  |   [C1 orange]                                         |  z  3
  |      [P3]                                  [P4]       |  z  7
  |                                  [C2 orange]          |  z  9
  |                                        +--------------+
  |                                        | BOOTH        |  z 11-14, floor 1.5 m, glass
  +----------------------------------------+--[door]------+   door to the bay: one way
      bay x -10..10, z -14..14, 7 m high, flat, closed roof
```

| Part | Spec | Decision it serves |
|---|---|---|
| **Booth** | Glass that stops shots (G0, measured). More than 18 m from the tend lane. Its stair lands at a bay door, about 19–20 m from the lane, that **closes behind you** once you're on the bay floor. It reopens on RESTART or when the Shunter is down. | Watching is safe. **It's for watching, not hiding:** no shooting-from-safety spot, and no stair face to farm wall-stops against. |
| **Tend lane and dock** | §2 | Ambush timing |
| **Pillars P1–P4** | Full-height steel, 1.2 × 1.2 m, at (±5, −3) and (±5, 7). They block line of sight. | **Bait into steel** (1.8 s). Break line of sight to stop a brace starting. |
| **Freight gate** (machinery) | A free-standing 6 m steel frame, with a 3 m roller shutter (`ServiceShutter`) in the middle, at (0, 1). Kit levers on both faces. A green line from the dock's power feeds it. One pull closes it for **6 s**, then it reopens. **It won't close on somebody** (the existing interlock). | **A wall you place in a lane.** Closing takes about **1.6 s** (**ASSUMPTION A2**: [SS] 2.2 m/s and 4 m/s² over about 3 m of travel), so **you plan it, you don't react with it.** Close it while the Shunter is closing in, then stand in front of the steel. The Shunter walks round it (sidestep, [E] ~770-785), so it's never a permanent hiding place. |
| **Orange crates C1, C2** | `DestructibleCover`, 40 HP | Cover that is spent once. Switchback and Bulkhead burn through it quickly, including your own. |
| **Floor** | Flat, no platforms. The Shunter doesn't pathfind, so a ledge would be a camping spot or a stuck Shunter. | — |
| **Restart** | Shunter at the dock, crates whole, gate open, booth door open, marks cleared | — |

---

## 7. What Prod builds (all local, behind a test profile)

Build it on **`review/five-weapons`**, so keys 1–5 (weapons), 6 and 0 come
for free, as an isolated scenario (for example `--freight-bay`). Every
rule change sits behind a **per-instance test profile**. **The
campaign's charger and every other role are unchanged.**

1. **Arena** per §6, using existing parts (pillars, `DestructibleCover`,
   `ServiceShutter`, the kit lever, a dock fitting). Stand-ins only, and
   nothing sends.
2. **Charger rules (test profile):**
   - the contact hit test, plus the shove;
   - recovery by what ended the rush (0.7 / 1.1 / 1.1 + crate break /
     1.8);
   - the plough shrug;
   - notice on being hit, and on hearing a Mass Driver charge within 18 m;
   - the 0.6 s horn;
   - **the heavy-hit reactions in §3.2** (a raw single event ≥ 12; the
     brace break once per cycle; the 0.3 s halt plus shove during CLOSE);
   - the 180 °/s turn;
   - declared tend ends, dock and tote nudge;
   - the power-down death.
3. **Bulkhead's heavy check** adds up the pellets of **one trigger pull**
   that strike the Shunter (**ASSUMPTION A3**: if the range applies
   damage pellet by pellet, sum them for the reaction check only, and
   leave damage alone).
4. **The look:**
   - the [AR] B blockout (four driven parts) per §5;
   - the lane strip;
   - plough sparks on armoured hits, including during the wind-up
     (today's hit punch is skipped mid-wind-up, [E] ~1683).
5. **Sound** (existing bank or labelled placeholders until Condi's):
   horn, scrape, rush, crumple clang, skid, vent gust, plume hiss,
   power-down. Weapon sounds come from the range's slots.
6. **Telemetry:** state changes, heavy and light hits per state, window
   damage, time-to-kill per weapon, rushes taken, distance moved.

---

## 8. Acceptance

### A. Scripted checks (truth, not fun)
1. **Pre-contact.** From the booth, at least 2 tend beats and 1 dock, with
   no notice. A Mass Driver charge inside 18 m causes notice; outside it
   does not.
2. **Horn.** Notice gives 0.6 s, plough up, full damage, then CLOSE. A
   heavy hit during WORK extends the horn by 0.3 s.
3. **Telegraph.** The lane appears at the wind-up's start and is followed
   to within 0.1 m.
4. **The dodge:**
   - a 1.1 m sidestep, started 0.3 s into the wind-up: **0 damage**;
   - standing in the lane: **14 plus a shove**;
   - a jump taking off **0.23 s** before plough contact: **0 damage**,
     lands behind;
   - a jump taking off **0.10 s** before contact: **hit**.
5. **Recovery windows:**
   - hit 0.7 s;
   - open floor 1.1 s;
   - crate 1.1 s, and the crate is destroyed;
   - pillar, wall or closed gate 1.8 s;
   - the plume fades in the last 0.2 s;
   - **no window ever extends.**
6. **Heavy hits:**
   - Foundry, a Mass Driver release of 12 or more, and Bulkhead with 3 or
     more pellets on target **are heavy**;
   - Pulse, Sightline and Switchback **never are**;
   - a heavy frontal hit in BRACE breaks it, **once per cycle**; the
     locked re-brace sparks only;
   - a heavy hit in RUSH changes nothing;
   - armour applies to damage, not to the reaction.
7. **The gate:**
   - closes in about 1.6 s (record the real number);
   - stops a rush (1.8 s crumple);
   - never closes on the player or the Shunter;
   - reopens after 6 s;
   - the Shunter walks around it.
8. **Weapon bots, plough up, firing from 0.2 s:** damage per window
   within ±1 shot of §4's table. A pillar window kills with Foundry,
   Bulkhead and a full Mass Driver. The Pulse needs at least 2 windows.
9. **Every hit answers** (sparks, jolt or flinch, plus a sound),
   including during the wind-up.
10. **Nothing stuck:**
    - no grinding against a pillar or the gate for more than 2 s;
    - the booth door closes behind and reopens on RESTART or a kill;
    - RESTART restores everything.
11. **Isolation:** 0 bridge connections, no AP sends or saves. The
    campaign charger is unchanged (Crossing D's probe re-run as is).
    The weapons behave exactly as in [5W].

### B. Skyiah's playtest (the real acceptance)
Play with sound, three runs:
- Pulse only;
- Foundry or Bulkhead;
- your choice.

1. Did watching it work make you want to plan an approach?
2. Could you read *when* and *where* it would charge, and did a dodge
   you saw miss really miss?
3. Did you choose between open floor, a pillar and the gate, rather
   than doing the same thing every time?
4. Did breaking its brace with a heavy shot feel like a real choice?
5. Did different guns make you fight differently?
6. Did the fight end on a good decision, not on attrition?
7. Did it feel like a freight machine, not a generic monster?

**The bar:** Skyiah enjoys it. Bots winning is not a pass.

---

## 9. Cut order
1. the tote nudge;
2. the dock settle;
3. the Mass Driver charge-hearing (keep notice on being hit);
4. the gate (the pillars still carry the steel decision);
5. the power-down death (keep the sound).

**Never cut:**
- the contact hit test and the corrected jump numbers;
- the lane telegraph;
- the plough armour;
- the retuned windows;
- heavy-hit reactions;
- notice on being hit;
- hit feedback during the wind-up.

**Deferred, unchanged:**
- the Shunter breaking the Impact Relay's shutter;
- notice by line of sight;
- a second enemy;
- a heavy Echo interrupting the rush.

---

## 10. Assumptions, all flagged
- **A1. The combat research you mentioned isn't in this session.** It
  wasn't on any remote branch (searched 2026-10-10) or among the
  uploads. So this revision applies only widely known principles from
  those games, from general knowledge, not from the team's write-up:
  - **DOOM:** movement is your defence, and big enemy vulnerability
    windows reward aggression;
  - **Destiny 2:** readable telegraphs, flinch on hits, and weapon roles
    that matter against a specific enemy behaviour (here, heavy hits
    breaking a brace, with no champion system);
  - **Half-Life:** enemies with a visible life before combat, and sound
    as information.

  **Please push the research and I'll reconcile anything it
  contradicts.**
- **A2.** The gate's ~1.6 s close is worked out from the
  `ServiceShutter` constants and an assumed 3 m of travel. Prod measures
  it. If it is much slower, use 6 s → 8 s held, never a faster bespoke
  shutter.
- **A3.** Bulkhead's heavy check adds up the pellets in one trigger
  pull.
- **A4.** The window maths assumes the player starts firing 0.2 s in.
  Real players are slower, so real fights run longer.
- **A5.** The Mass Driver's 45 one-shot is accepted for this playtest
  (§4).
- **A6.** Hearing a charge within 18 m is a new, test-only rule.
- **A7.** Switchback lands about 80 % of rounds on a passing or stopped
  Shunter at under 10 m.
- **A8.** Arty's B timings are kept, but stretched or held to fit these
  durations (horn 0.6 s; recover 0.7–1.8 s).

---

## 11. What changed from revision 1
1. **The jump contradiction is fixed:** take off 0.18–0.28 s before
   contact. The hit volume is symmetric along the body.
2. **Recovery windows shortened for the new weapons:** open floor and
   crate 1.4 → 1.1 s, steel 2.0 → 1.8 s. HP stays at 40.
3. **The back-hit stagger is removed.** Heavy-hit reactions (§3.2) change
   the tempo, never the window's length.
4. **The freight gate is added** as the arena's machinery, plus a
   **one-way booth door**.
5. **Arty's variant B** is adopted: brow lamps, 37 cm plough travel, the
   rear-up on notice, the recovery plume. New poses are specified for
   the wall crumple, the brace break, the heavy jolt and the dock.
6. **The weapon opportunity table** uses the five weapons as built.
   Notice on hearing a Mass Driver charge is new.
7. **The code baseline moves to `review/five-weapons`.**

## 12. Decisions for Skyiah
1. **The Mass Driver's 45 one-shot:** accept it for this playtest
   (recommended), or test it at a 30 maximum against living targets?
   Either way, not more Shunter HP.
2. **Heavy hits break a brace once per cycle,** and never stop a rush?
   Recommended: yes.
3. **The freight gate** as a planned tool (about 1.6 s to close), not a
   reflex button? Recommended: yes.
