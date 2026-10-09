# D-20 — One Shunter: a testable combat encounter (build-ready)

**Dess → Prod and Arty, for Skyiah. 2026-10-09. A brief for gate G3's
first enemy test, not approved for the campaign.** It turns D-19's
freight Shunter (`docs/D19_CHARGER_STUDY.md`) into one isolated
encounter: one Shunter, one bay, the base kit and the Static Pulse.

**Not in this test:**
- a new AI architecture, factions or an ecosystem;
- a second enemy;
- campaign changes.

**The Shunter breaking the Impact Relay's shutter stays a deferred
experiment** (§9).

**Code baseline:** `review/impact-relay-g1` `21b5fb2f` (build
`a3b59c46`). Its enemy, player and constants files are byte-identical
to G0 and to readable D. Every "today" value below was read from it:
- `godot/scripts/enemies/enemy.gd` **[E]**;
- `godot/scripts/autoload/constants.gd` **[C]**;
- `godot/scripts/gameplay/player.gd` **[P]**.

---

## 1. What the player does, in one breath

From a glass booth you watch a low freight machine shuffle between a
crate stack and its charging dock. You step out and it hears you: its
head comes up, it sounds a horn, and its plough drops. It plants,
scrapes, and a lane lights on the floor toward you. You step off the
lane. It thunders past, or slams into the pillar you were standing in
front of, and sits stunned with its back open. You punish it, then
it turns to find you again.

Two or three of those cycles and it powers down. Standing still and
shooting its plough is a losing trade. Watching first, baiting it into
steel and hitting the back is how you win.

---

## 2. The numbers: today, and what this test changes

The changes are deliberately few. They are everything needed for
"dodge, then punish" to be true in play.

| Thing | Today (source) | In this test | Why |
|---|---|---|---|
| HP | 40 (**[C]** :272) | **40, unchanged** | It isn't too fragile; it's vulnerable at the wrong time. HP is the last knob. |
| Rush damage | 14 of the player's 100 (**[C]** :272, :148) | **14, plus a shove**: about 8 m/s along the rush, through `Player.receive_knockback` (**[P]** ~1430) | Getting hit should move you out of the lane and be felt, not only subtracted. |
| Wind-up | 0.7 s, direction fixed when it starts (**[E]** :94, :839-849) | **0.7 s, unchanged** | It is already the roster's longest, and already commits. |
| Rush | 1.1 s at 13 m/s, about 14.3 m, no steering (**[C]** :40-41) | **Unchanged** | — |
| **What counts as a hit** | Any player within **2.8 m of its centre** (reach 14 × 0.2), in 3D (**[E]** ~1160) | **Contact with the plough:** player within **1.0 m sideways** of the rush line (0.45 half-width + 0.4 player radius + 0.15), within **1.35 m ahead** of its centre, and feet **below 1.05 m** (its height) | Today a sidestep that clearly misses still takes damage, and jumping can never clear it. The dodge has to be honest (§4). |
| Recovery | 1.4 s after any rush end, wall or not (**[C]** :39; **[E]** ~1166) | **Hit the player: 0.7 s. Open-floor miss: 1.4 s. Wall or pillar: 2.0 s. Orange crate: 1.4 s, and the crate breaks.** | A dodge has to earn more than avoiding 14 damage: a Shunter that connects recovers fast. Hitting steel should hurt it more, because that's the environment paying the player. |
| Cooldown | 3.0 s from the start of the wind-up | **Unchanged** | A cycle is about 0.7 + up to 1.1 + 0.7–2.0 s, so after a hit it waits a beat; otherwise it rarely waits. |
| Turning | Snaps to face the player (no `turn_rate` for the charger; the bulwark has 90 °/s, **[C]** :37) | **180 °/s**, only while not committed | Getting round to its back during recovery has to be possible and visible. |
| Approach | 3 m/s until 11.2 m away (reach × 0.8); rushes at 14 m or less with a clear line (**[E]** :1267-1270, :831-849) | **Unchanged.** Tuning knob: speed. | The plough (next row) is what fixes "shot dead while walking in", not more speed. |
| **Plough armour** | None (only the bulwark shrugs: 0.85 inside dot 0.35, **[E]** :1402-1414) | **The plough is down while closing, bracing and rushing: frontal hits (inside dot 0.35) take 25 %. Up while working and recovering: full damage.** Sides and back are always full. | Reuses the bulwark's existing `_frontal_shrug` path for one more role, with a state condition. |
| Notice | Within 18 m (`ENEMY_AGGRO_RADIUS`), through walls; interest lasts 4 s (**[C]** :72, :75; **[E]** ~668-698). **Being shot doesn't make it notice.** | **18 m, plus being hit.** On notice, a **0.6 s horn**: head up, plough still up. | Today a player 19–40 m away (Pulse range 40, **[C]** :190) can kill it before it ever reacts. The horn's 0.6 s is the ambush reward. |
| Hit feedback | A scale punch, skipped during any wind-up (**[E]** ~1683-1688), plus a wound tint | **Every hit answers:** plough hits spark and clang; body hits jolt; **a back hit during recovery staggers (+0.4 s, once per recovery)**. A spark still plays during the wind-up. | Silent hits were the D failure. |
| Death | Tips over and sinks (**[E]** :1831-1843) | **Powers down:** lamps fade, plough drops, it skids a metre if it was rushing. A distinct sound. | A satisfying end. Cosmetic only. |

**The player, unchanged** (**[C]**):
- walks at 7 m/s;
- jumps 1.33 m high, with 0.67 s airtime and a 4.67 m flat reach;
- radius 0.4 m;
- Static Pulse: 6 damage every 0.35 s (17.1 per second), hitscan, 40 m
  range, no knockback (**[P]** ~1086-1100);
- no damage immunity window, so a rush can only hit once (it ends on
  hitting).

### What the fight works out to (Static Pulse, from these numbers)

| How the player fights | Damage per opening | Expected result |
|---|---|---|
| **Stand still and shoot** | 1.5 a shot into the plough, plus about 2 full shots in each 0.7 s post-hit recovery ≈ 15 HP a cycle | About **3 cycles, about 9 s**, taking about 3 rushes (about 42 of 100, each with a shove). **Clearly the worse choice, not instant death.** |
| **Sidestep on open floor, then punish** | 1.4 s recovery ≈ 4 shots = 24 HP | Dead in about **2 cycles** (≈ 6–7 s after the first rush) |
| **Bait it into a pillar** | 2.0 s ≈ 5–6 shots, plus a stagger on the back | Dead in **1–2 cycles** |
| **Ambush from behind** while it works | The 0.6 s horn + up to 1 s to turn at 180 °/s ≈ 4–5 full shots ≈ 24–30 HP | Dead **during or right after the first recovery** |

**Time to threat:** inside 18 m, the first wind-up starts about 1.3–2.0 s
after notice. That is faster than any frontal shooter can kill it.

---

## 3. The states, as the player reads them

| State | What it's doing | What you see and hear | Plough |
|---|---|---|---|
| **TEND** | Walks its lane, crate stack ↔ dock, at the job speed (3 × 0.45 = 1.35 m/s, **[C]** :77). At the stack, a 1.5 s nose-and-butt. At the dock, a 3 s settle with lamps dimmed. | Servo whir, small chirps, white or amber lamps | Up |
| **HORN** (0.6 s) | Noticed you, or was hit | Head up, two-tone horn, lamps go red | Up |
| **CLOSE** | Walks at you, 3 m/s, stops 11.2 m away | Heavy footfalls | **Down** |
| **BRACE** (0.7 s) | Plants, direction locked | Plough drops 15–20 cm, legs splay, scrape, red edge; **a lane lights on the floor** along the locked direction, 14.3 m long | **Down** |
| **RUSH** (≤ 1.1 s) | 13 m/s straight; ends on contact, a wall, a crate, or after 1.1 s | Rumble, the lane fades behind it | **Down** |
| **RECOVER** (0.7 hit / 1.4 miss / 2.0 wall) | Helpless, decelerating | Wall: clang and shudder, steam. Open floor: skid and hiss. Its back is visibly open. | Up |
| **RE-AIM** | Turns at 180 °/s, then CLOSE or BRACE | Servo turn | Up while turning |
| **DOWN** | Dead | Power-down whine, lamps fade, plough drops | — |

**The lane decal is the one new telegraph object.** Arty's
`fx_charger_lane` brief already defines it as "a lane, not an arrow …
says where it will go *and that it cannot turn*". It is drawn on
`telegraph_started` from the fixed rush direction (**[E]** :1797-1806).
Until her art exists, a flat strip is fine. A placeholder plough slab
that drops is the minimum body read; today's engine telegraph is a 12 %
swell of the whole model (**[E]** ~631).

---

## 4. The dodge, measured against the player's movement

**Sidestep.** Clearing the plough needs about 1.0 m of sideways
movement from the lane's centre. At 7 m/s that's about 0.15 s once
you're moving. How much time you have:
- At **14 m** (the farthest it rushes from): the 0.7 s wind-up plus
  about 0.9 s of travel, so **1.6 s** from the first tell. Generous.
- At **6 m**: 0.7 + about 0.36 s, so **1.06 s**. Fair.
- **Close range is the danger.** Getting under 6 m of a braced Shunter
  should feel like a mistake.

**Jump over** (skill, legal):
- a jump keeps the feet above 1.05 m from 0.18 s to 0.49 s, a 0.31 s
  window;
- the Shunter needs about 0.21 s to pass a point (1.9 m long plus the
  0.8 m player, at 13 m/s);
- so a jump timed to about 0.1 s clears it, and **you land behind it,
  facing its back, at the start of its recovery**.

The contact rule (§2) is what makes this possible; today's 3D 2.8 m
sphere forbids it. The swing tether isn't needed, but it is legal in a
comparison mode (§7).

---

## 5. The arena: Shunter Bay

```
                                N
  +----------------------------------------------------+
  | [crate stack]  ==== tend lane (12 m) ====  [DOCK]  |  z -12
  |   x -6                                       x +6  |
  |                                                    |
  |      [P1]                              [P2]        |  z -2   P = steel pillar
  |                    [C1 orange]                     |  z  1   C = orange crate
  |                                                    |
  |      [P3]                              [P4]        |  z  6
  |  [C2 orange]                                       |  z  9
  |                                     +--------------+
  |                                     | ramp down    |  z 11
  +-------------------------------------+   BOOTH      |  z 14
                                        | (glass, 1.5 m up)
                                        +--------------+
      bay x -10..10, z -14..14, 7 m high, flat floor, closed roof
```

| Part | Size or position | Purpose |
|---|---|---|
| **Bay** | 20 × 28 m, 7 m high. Flat floor, closed roof, no pits. | The rush is 14.3 m, so lanes of 14 m or more exist down the centre and on the diagonals. Flat because the Shunter doesn't pathfind: it walks straight and sidesteps (**[E]** ~770-785). Any platform it can't drive onto would become a camping spot, or a stuck Shunter. |
| **Booth** (start) | South-east, floor 1.5 m up, glass front, a door onto a short ramp. The front is about 20 m from the nearest point of the tend lane. | Watch it work in safety. More than 18 m away means it can't notice you, and glass stops the Pulse (G0, measured), so it can't be sniped from inside. **Ambush from the booth door**, at 19–20 m, is legal. |
| **Tend lane** | Along the north wall, crate stack (x −6) to dock (x +6), 12 m. Declared patrol ends, not the job's random ends (**[E]** :1009-1041 picks ends around the post). | Its life before you: purposeful, and readable from the booth. |
| **Crate stack** | 3 stacked freight boxes, static, plus one loose 20 kg tote (`ManipulableBody`). | Its butt can nudge the tote (`receive_impulse`). **Optional, first to cut.** |
| **Dock** | A wall fitting with a **green** socket, a cable and a pilot light (green belongs to the dock). | Its rest point. In its 3 s settle it faces the wall, the best ambush moment. |
| **Pillars P1–P4** | Full-height steel, 1.2 × 1.2 m, at (±5, −2) and (±5, 6) | **Bait points.** Stand in front, sidestep: 2.0 s stun. They also block line of sight, which stops a wind-up from starting. |
| **Orange crates C1, C2** | `DestructibleCover`, 1.5 × 1.4 × 0.9 m, 40 HP | Low cover. A rush into one **breaks it** and gives a normal 1.4 s opening. The room changes, and hiding has a cost. |
| **Walls** | The bay's own | Rushes into walls give the 2.0 s stun, like pillars. |
| **Restart** | The review menu | Shunter back at the dock, crates whole, player in the booth |

**The movement choices this layout gives:**
- **Sidestep in the open.** Safe, with a normal opening.
- **Use a pillar.** A bigger opening, but you have to stand in front of
  steel and commit to the last moment.
- **Use a crate.** It protects you once, then it's gone.
- **Jump over.** Hard, and the best reward.
- **Circle behind** during recovery, against its 180 °/s turn.
- **Ambush** from the booth door, or from behind while it docks.
- **Break line of sight** behind a pillar to stop a wind-up starting.

---

## 6. What Prod builds (all local, no new system)

All of it lives in an **isolated scenario** (for example `--shunter-bay`)
on its own review branch, like the Impact Lab. Every rule change sits
behind a **per-instance test profile** set only by that scenario.
**The campaign's charger and every other role keep today's behaviour
unless Skyiah approves the result.**

1. **The arena** per §5, using the lab's builders. Stand-ins only, and
   nothing sends.
2. **Charger branches in `enemy.gd`,** gated by the profile:
   - the contact hit test, plus the shove;
   - recovery by what ended the rush (the player, open floor, wall or
     pillar, `Damageable` crate), with the crate taking ≥ 40;
   - the plough shrug inside `_frontal_shrug`, active in close, brace
     and rush;
   - a hit counts as notice, followed by the 0.6 s horn;
   - the once-per-recovery stagger on back hits;
   - a 180 °/s turn rate when not committed;
   - declared patrol ends with the two work pauses;
   - the power-down death.
3. **Readability:**
   - the lane strip on `telegraph_started`;
   - a placeholder plough slab driven by state;
   - lamp colours white/amber → red;
   - spark/clang versus jolt per hit, including during the wind-up.
4. **Sound:** horn (on `aggro`), scrape (on `windup`), rush rumble, wall
   clang, recovery hiss, power-down. Existing bank tones or placeholders
   are fine.
   **Prerequisite:** the player's shot must be audible, with a hit
   confirm (G0 measured the shot at −20 dBFS and 50 ms). If Prod's P2.1
   firing pass isn't in, put at least the existing bank's shot and hit
   tick at a level Skyiah can hear. Otherwise the fight's feel is
   confounded.
5. **Telemetry** for the checks below. The numbers diagnose; they don't
   replace the feel verdict.

---

## 7. Acceptance criteria

### A. Scripted live check (safety and truth, not fun)
1. **Watching works.** From the booth, the Shunter completes at least 2
   tend beats (stack ↔ dock) and never notices the player, attacks or
   moves toward the booth.
2. **Notice.** Entering within 18 m, or one Pulse hit from beyond it,
   gives: the horn, then 0.6 s with the plough up, then the plough down.
3. **The telegraph is true.** The lane appears at wind-up start, along
   the locked direction, 14.3 m long. The rush follows it to within
   0.1 m and never steers.
4. **The dodge is honest:**
   - a scripted step of 1.1 m sideways, started 0.3 s into the wind-up,
     takes **0** damage;
   - standing in the lane takes **14 and a shove**;
   - a jump started about 0.1 s before contact passes with **0** damage
     and lands behind it.
5. **Recovery comes from what stopped it:**
   - pillar or wall: **2.0 s**;
   - crate: the crate breaks, then **1.4 s**;
   - open floor: **1.4 s**;
   - after hitting the player: **0.7 s**.
6. **Armour:**
   - frontal Pulse while closing, bracing or rushing does **1.5** and
     sparks;
   - a back hit does **6**;
   - a frontal hit while tending or recovering does **6**;
   - one stagger per recovery, at most.
7. **The fight takes the predicted time** (scripted bots with the
   Static Pulse):
   - a standing frontal shooter needs **≥ 8 s** and takes **≥ 2** rushes;
   - a dodge-and-punish bot wins in **2 cycles**;
   - an ambush bot wins by the end of the **first recovery**.
8. **Time to threat.** Inside 18 m, the first wind-up starts within
   **2.5 s** of notice.
9. **Every hit answers.** Each Pulse hit logs a visual and a sound
   event, including hits during the wind-up.
10. **Nothing gets stuck:**
    - the Shunter never grinds against a pillar for more than 2 s;
    - it never leaves the floor;
    - RESTART restores everything in §5.
11. **Isolation:** 0 bridge connections, no AP sends, no save writes.
    The campaign charger is unchanged (re-run Crossing D's probe as it
    is).

### B. Skyiah's playtest (the real acceptance)
Play with sound on: once watching first, once rushing in.
1. Did you watch it work before fighting? Did that make it feel like it
   belonged there?
2. Could you tell *when* it would charge, and *where*?
3. Did you dodge on purpose, and did a dodge you saw miss actually miss?
4. Did a pillar or crate change what you did?
5. Did standing still feel risky?
6. Did every hit feel acknowledged, and did the end feel like an end?
7. Would you fight a second one? A second one *with a ranged enemy*?

**The bar:** Skyiah says it's fun. A bot winning is not a pass.

---

## 8. Cut order if time runs short
1. the tote nudge;
2. the dock settle (keep the patrol);
3. the power-down death (keep the sound);
4. the 180 °/s turn (keep the 2.0 s wall stun).

**Never cut:**
- the contact hit test;
- the lane telegraph;
- the plough armour;
- notice on being hit;
- hit feedback during the wind-up.

---

## 9. Deferred, not in this test
- **The Shunter breaking the Impact Relay shutter.** It needs a physical
  mass for the Shunter, and its rush delivered to the shutter's energy
  rule. At about 150 kg and 13 m/s that's ~12,700 J against the
  shutter's 1,000 J. An experiment after this encounter passes.
- **Notice by line of sight** instead of distance. The booth's distance
  covers this test.
- A second enemy role; shared horns between several Shunters; slow
  waking from the dock.
- A heavy-hit (≥ 12) Echo interrupting the brace. That needs an Echo
  weapon in the review kit.
- **Comparison mode:** the swing tether everywhere. Legal and welcome,
  but not part of the default test.

## 10. Decisions for Skyiah
1. **Changes behind a test profile only.** The campaign charger is
   untouched until you've played it. Recommended: yes.
2. **Keep HP at 40,** and fix the fight with the plough and the dodge?
   Recommended: yes.
3. **Is a jump-over dodge welcome?** It needs the contact rule.
   Recommended: yes.
