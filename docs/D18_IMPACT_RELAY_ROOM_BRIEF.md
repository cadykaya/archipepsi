# D-18 — Impact Relay: one mixed-system room (build-ready, v2)

**Dess → Prod and Arty, for Skyiah. 2026-10-08.**

**Concept A is approved** (Skyiah, 2026-10-08). This version is the brief
G1 builds from. It is reconciled to Prod's measured G0 lab: branch
`review/impact-lab-g0` at `c45086e1`, build `3337769d`, report
`docs/reports/2026-10-08-impact-lab-g0.md`.

v1 (`fabab375`) is in history. Its three-design comparison and three
mechanism tiers are settled and aren't repeated here.

Source refs:
- **[G0]** = `review/impact-lab-g0` `c45086e1`;
- **[R]** = the readability build `bb683ce0`;
- **[T]** = the 0.4 team head `claude/archipepsi-0-4-blindside` `a266d5da`.

---

## 0. What G0 changed, and what this brief now says

| Topic | v1 (proposed) | G0 (measured) | v2 (build this) | Why |
|---|---|---|---|---|
| Throw distance | ~17 m, apex ~3 m | 11 m, 1.0 s, apex 2.3 m, leaves at 12.4 m/s, **11.0 m/s into the face every time**; 40 of 40 broke it | **11 m**, Prod's arc | Measured and deterministic. A longer throw buys nothing the player feels, and 11 m keeps the impact readable from the plate. |
| Weight | 45 kg, two in a rack | 36 kg, one; slows the carrier ×0.85 | **One 36 kg weight** | Still `MEDIUM`, and still costs something to carry. A spare would bring in the untested several-objects case for no gain: a lost weight comes home anyway. |
| Activation | Rest 0.3 s, then a 1.0 s wind-up; re-arm 2 s | A settled, released body arms the plate for **0.6 s**, then it fires. Re-arm **1.0 s**. **One throw per arrival.** Unpowered gives a dud click. Powering a plate with a body already resting on it arms it. | **Prod's timings** | The 0.6 s ramp, from someone who has just put the weight down and stepped back, is the honest telegraph. A longer wait would only feel sluggish. |
| Teaching crate | 12 kg, meant to glance | A thrown 10 kg crate brings ~600 J and counts; two would break the shutter | **4 kg crate** (~240 J, refused) | v1's crate would have broken the shutter on the second throw. 4 kg is always refused, with margin (see §3). |
| Shutter | `BreakablePanel`, one qualifying impact | `ImpactShutter`: **40 HP, cumulative**. A blow under **12 HP** is refused. A body's blow is ½·m·v² into the face at **25 J per HP**. Wear shows on the seams. It breaks into slabs that collide only with the world. | **Prod's shutter as built**, 3 × 3 × 0.4 m | It is the same rated rule as the panel, now with a physical measure. |
| Fallback tiers | Throw, lift-and-drop, ram | Direct throw deterministic; fallbacks not built | **Throw only.** The fallbacks are not needed. | — |
| Window and Check | High window over the seal; Check on a 2.5 m dais | A low window beside the doorway (1.0–3.4 m), which stops shots | **Prod's window.** The Check sits behind it on a low dais (§2). | The eye line works from the gallery (§2). |
| Hall | 26 × 22 × 10 m | 20 × 22 × 8 m | **20 × 22 × 8 m** (Prod's lab hall) | Nothing in v2 needs more, and a smaller room is quieter. |

**Prod's three questions to me:**
1. **The `lightened` overshoot is a legal Echo outcome, not a defect. Don't
   patch it.** The only requirement is that the weight ends somewhere
   reachable, or comes home (§4).
2. **The rated shutter plus glass is the rule.** The machine opens the
   way because it hits hard, not because bullets are banned. Anything
   else that hits hard enough is welcome (§5).
3. **One target point:** the shutter's centre. No moving targets and no
   tight gaps.

---

## 1. The room direction this follows (owner, 2026-10-08)

- **Compatible activities, chosen on purpose.** There is no
  one-mechanic-per-room rule. Machinery, movement, destructibles and,
  later, enemies may act on each other, but only where the combination
  makes the room better.
- **Quiet rooms can stay quiet.** A movement room can stay a movement
  room. This one combines four systems because each answers the
  question the last one raised:
  - **power** wakes the plate;
  - **carrying** is how the weight reaches it;
  - **the plate's throw** is the movement;
  - **the shutter** is the consequence.
- **Echo equipment should open unexpected routes.** Clever skips are
  part of the randomiser, and §5 is where this room keeps that promise.

---

## 2. The room

### 2.1 The first ten seconds
You step from the connector onto a glass-fronted gallery 4.5 m above a
plain freight hall. Straight ahead, 18 m away, the far wall has a 3 m
doorway sealed by an orange-banded steel shutter. Beside it, a window
shows a lit stand-in Check on a low dais in the room beyond. Halfway
down the hall a blue-trimmed floor plate faces the shutter, with a
light plastic crate resting on it. A dark green line runs from the
plate along the floor to a lever at the foot of the stair below you. To
your right, a squat steel weight stands on its stand.

So the player sees what they want, what's in the way, a machine aimed
at it, where the power comes from, and something heavy. They don't
yet know how those fit together.

### 2.2 Layout (lab coordinates: x east, z south, y up, hall floor at y = 0)

```
                           N   onward door
              +---------------[====]----------------+
              |  VAULT  4 m high  (dais @ x 5)       |---+
              +-----[SHUTTER x -1.5..1.5]--[WINDOW x 3..7]   | loop
  hall x -10..10   ledge (local)    ^                        | corridor
  z -12..10        y 5, NW wall     | 11 m arc, peak 2.3 m   | (outside
  8 m high                          |                        |  the east
                 [lever]...green...[PLATE (0,-1)]            |  wall)
              stair                          [weight stand]  |
              (W wall)                         (6, 0, 2)     |
              +--------------------------------------------+-+
              |  GALLERY  y 4.5, z 6..10, glass front |door| <- "OPENS FROM
              +--- arrival connector -------------------+    THE OTHER SIDE"
```

| Part | Where and how big | Notes for Prod |
|---|---|---|
| **Hall** | x −10…10, z −12…10, 8 m high. Closed roof, trusses near 7 m. | Your lab hall unchanged. The trusses are swing anchors. |
| **Gallery** (arrival) | South wall, y = 4.5, z 6…10, full width. Glass front. Its east end is the loop door. | Dropping from the open stair head to the floor is legal and lands safely. |
| **Stair** | Down the west wall from the gallery (z 6) to the floor (z ≈ −2). | The base-kit way down. |
| **Lever** | Floor, near the stair foot, at about (−7, 0, −1). Arty's kit lever. | The raceway runs along the floor to the plate, about 7 m. |
| **Plate** | **(0, 0, −1)**, 2.0 × 0.25 × 2.0 m, aimed at the shutter's centre. Your `ObjectPlate`. | 11 m to the shutter face, as measured. |
| **Crate** | Rests on the plate at the start. **4 kg**, `LIGHT`, carriable, about 0.5 m. | §3: always refused. |
| **Weight** | Home on a low stand at **(6, 0, 2)**. **36 kg** `ManipulableBody`, 0.45 × 0.6 × 0.45 m. | Out of the arc lane. About 7 m to the plate. |
| **Shutter** | North wall doorway x −1.5…1.5, 3 m high. Your `ImpactShutter`. | — |
| **Window** | North wall, x 3…7, y 1.0…3.4. Glass that stops shots. | Measured in G0. |
| **Vault** | Behind the north wall, x −6…8, z −18…−12.5, 4 m high. **Dais** at (5, 0, −15), top 1.0 m, with the stand-in Check `relay_vault` on it. | Eye-line check from a gallery eye at (0, 6.1, 7): it crosses the north wall at about (4.3, 2.1), inside the window. **Please confirm in engine.** |
| **Onward door** | The vault's north wall. | The exit. |
| **Loop** | A door in the vault's east wall, opened from the vault side, leading into a corridor outside the hall's east wall. The corridor runs south with a stair up to 4.5 m and ends at the gallery's east-end door. From the gallery side the door reads "OPENS FROM THE OTHER SIDE" and is shut, so nobody walks to a dead end. | Your corridor stays enclosed: roof on, no gap into the hall. |
| **Ledge** | North-west corner, an alcove at y = 5.0 near (−9, 5, −9). Local stand-in `relay_ledge`. | Base kit must not reach it from the stair, gallery, plate or stand. Please run your D-9 reach measurement. |

### 2.3 What the player does, base kit only
1. **Pull the lever.** Green runs to the plate, the chevrons wake, the
   plate arms for 0.6 s and throws the crate. It hits the shutter and
   glances off: refused flash, a dull knock, "NEEDS A HEAVIER HIT". The
   crate drops by the shutter.
2. **Carry the weight to the plate** and set it down. The player is
   slowed and can't fire while carrying.
3. **Step back.** 0.6 s arming, then the throw: a short flight, a heavy
   impact, the seams flare and the shutter breaks into slabs. Light
   from the vault floods the hall.
4. **Walk in** and claim the Check on the dais.
5. **Open the loop door,** then take the onward door or walk the
   corridor back to the gallery.

The player could also do 2 before 1. Powering a plate with something
already on it arms it, so either order works.

---

## 3. Mechanism numbers (from the G0 code, not invented)

Throw speed into the face is **11.0 m/s**. The energy a thrown object
brings is ½·m·11² = **60.5·m J**, which is **2.42·m HP** at 25 J/HP.
The rating: a blow under 12 HP is refused, and the shutter holds 40 HP
in total.

| Blow | HP | Result |
|---|---|---|
| The 4 kg crate, thrown | 9.7 | **Refused**: flash, knock, label. The teaching beat. |
| Any thrown object under ~4.9 kg | under 12 | Refused |
| A thrown object of 5–16 kg | 12–40 | **Wears** the shutter (seams brighten). Two or more throws break it. No such object is in this room (v2 option, §8). |
| **The 36 kg weight, thrown** | **≈87** | **Breaks it in one throw** (2.2× the 40 HP) |
| The weight dropped, carried into the face, or rolled | ≈0 | A carried body never counts, and a drop has no speed into the face |
| Static Pulse (6) | 6 | Refused |
| Any single hit ≥ 12 (an Echo) | 12+ | Counts, and adds up: 4 hits of 12 break it |
| A PUSH that sends the weight in at ≥ 4.1 m/s | ≥ 12 | Counts. At ≥ 7.5 m/s it breaks in one blow. |

| Timing | Value |
|---|---|
| Arming (settled and released, then the ramp) | 0.6 s |
| Re-arm after a throw | 1.0 s |
| Throws per arrival on the plate | 1. Lift the object off and set it down again to re-fire. |
| Flight | 1.0 s |
| Unpowered | Dud: flicker and click, nothing moves |

---

## 4. Recovery and restart

| Case | Rule |
|---|---|
| **Weight leaves its allowed volume, or falls under the floor** | It comes home to its stand. **The allowed volume is the hall plus the vault.** After the break, a weight that flies on through the doorway stays in the vault, where it can be reached. |
| **Weight at rest out of reach** | Designed out (0 of 40 in G0). **Must also hold for:** a `lightened` overshoot (it hits the wall above the door, then falls; where does it settle?); a throw that hits a player standing in the arc; and the crate and weight on the plate together. |
| **Crate** | Same home rule; its home is the plate. It is never needed again, so it may lie wherever it falls. |
| **Several bodies on the plate** (crate left on it while the weight is set down beside it, then the lever) | **Prod measures what happens.** Acceptable outcome: the weight still reaches the shutter at ≥1,000 J, **or** lands somewhere reachable for a retry. If neither holds, throw the bodies one at a time, oldest first, each with its own 0.6 s arming. |
| **Pause mid-flight** | It resumes (measured). |
| **RESTART** (review menu) | Everything back, as measured in G0: unpowered, lever OFF, line dark, shutter whole, weight home, crate on the plate. Also: the loop door latched again, the Check stand-in unclaimed. |
| **Inside the vault with power OFF** | Nobody is stranded. The broken doorway is open on foot, and so are the onward and loop doors. |

The weight never has to be carried back through other rooms. The
deepest retry is: walk to the stand, carry it about 7 m, set it down.

---

## 5. Progression and Echo-skip rules

**Required, with base-kit routes:**

| Item | Route | Uses |
|---|---|---|
| Stand-in Check `relay_vault` (where an allocated Check would go) | Stair → lever → weight → plate → shutter → dais | Walk, carry, interact. No Echo, and no ranged hit needed. |
| Onward door (the exit) | Same | Same |

- **Under today's AP rule this is compliant.** An Echo may gate a
  Check, an AP-relevant key or an exit only if AP declares it, and AP
  declares none ([T] `docs/design-proposals/06_THE_AMALGAM.md:1494-1500`;
  `apworld/archipepsi/__init__.py:111-123`). This room has no AP key and
  grants no Echo, so the in-Zone Echo limit (DESS-28) isn't engaged.
- **The base-kit route is proven** by G0's 40 of 40, and G1's test
  repeats it in the real room.

**Optional:**
- the local stand-in `relay_ledge` (swing from a truss, or any movement
  Echo);
- the loop shortcut.

**Legal, never blocked:**
1. **Heavy hits.** Any Echo dealing ≥ 12 per hit wears the shutter, and
   enough hits open it. This skips the whole machine.
2. **PUSH or PULL.** Shove the weight onto the plate instead of carrying
   it, or straight into the shutter. Its speed decides whether the blow
   counts.
3. **`lightened`.** The weight is lighter to carry, and the plate throws
   it twice as hard, so it overshoots and misses. That is a harmless,
   legal discovery. Let the Status run out, then throw again.
4. **Movement Echoes.** Reach the ledge, skip the stair, or any line
   the player finds.
5. **The swing tether everywhere** in the review kit, with no area
   limit.
6. **Anything else** that reaches the same state by the room's own
   physics.

**Refused, and only these:**
- **Claiming the Check** from anywhere but its claim volume on the
  dais. Not through the window, not through the doorway.
- **An accidental base-kit bypass** of the shutter, the window or the
  vault roof, if one exists. None is intended. Prod's reach measurement
  confirms there is none.

**Separate checks, never solved by banning an ability:**
- **No escape from the world.** The roof, corridor and vault are closed.
  Probe it with the tether hooking any solid surface, everywhere.
- **No softlock.** §4.
- **AP correctness.** Above.

**Campaign note, for later (G5), not part of G1:** a generated world feature "may never
lie on the mandatory path, host an AP reward, an exit or an objective"
(ECHOES §13.2, enforced by `validate_zone`: [T]
`bridge/archipepsi_bridge/schemas/zone.py:377`, `layout.py:967`). So this room would join the campaign as a declared,
hand-built package with its own base-kit opener, like the D12 minor
cards. It would not be a generator affordance.

---

## 6. Feedback and colour

**Colour is an accent on hardware:**
- **green** on the lever pilot, the raceway and the plate's power
  terminal;
- **blue** on the plate's chevrons and leading lip (not the slab);
- **orange** on the shutter's bands and seams.

**Sound and light carry the explanation.** These are Prod's states, as
already listed for Arty:

| Moment | What you hear and see |
|---|---|
| Lever on | Clunk, then the line lights |
| Plate idle | Hum |
| Arming | Rising tick, chevron ramp |
| Throw | Thump and flash |
| Refused hit | Dull knock and seam flash |
| Wear | A heavier clang; the seams stay bright |
| Break | Crack, then the slabs fall |

The lab already wires the game's sound bank. G1 adds sounds for the
plate and the shutter; existing bank tones or simple placeholders are
fine.

**Labels, plain facts only:**
- "POWER OFF" on the lever;
- "IMPACT SHUTTER" on the shutter;
- "NEEDS A HEAVIER HIT" (already in the shutter);
- "OPENS FROM THE OTHER SIDE".

There is no instruction text.

**The crate and weight must look their mass.**
- **The crate:** a flimsy, open-sided plastic tote that wobbles when it
  lands.
- **The weight:** dense steel, a squat block with a carry handle. Before
  it moves, it should look like it would hurt.

---

## 7. G1 build list for Prod (all reuse, nothing general)

1. **Reuse from G0:** `ObjectPlate`, `Flight` and `ImpactShutter`
   (`impact_lab_parts.gd`), the recovery rule and the restart.
2. **Geometry per §2.2:**
   - the gallery and stair;
   - the vault with its dais, onward door and loop door (latched,
     opened from the vault side);
   - the enclosed loop corridor;
   - the ledge with its local stand-in.
3. **The crate** (4 kg) on the plate at the start; the weight on its
   stand.
4. **Live checks:**
   - lever first: the crate is refused and the shutter is unharmed;
   - the weight breaks it (repeat your 40-throw spread);
   - weight first, then the lever;
   - the crate and the weight on the plate together (§4);
   - `lightened`: where it settles;
   - a player standing in the arc;
   - the loop door opens from the vault only;
   - RESTART resets all the §4 items;
   - the eye line from the gallery to the Check;
   - a reach measurement on the ledge and the vault roof;
   - the tether everywhere, with no escape;
   - 0 bridge connections, and the stand-ins send nothing.
5. **Launch modes:**
   - **default:** enemy-free, base kit plus the swing tether
     everywhere;
   - **second:** a labelled heavy-hit mode, **only if** an existing
     Echo action deals ≥ 12 per hit. If none does, say so and don't
     invent one.
6. **The delivery note says what each thing does, not how to solve
   the room.**

**Cut order if time runs short:**
1. the ledge;
2. the loop corridor (exit through the broken doorway instead);
3. the crate's wobble polish.

**Never cut:** the crate's refused throw, the wear and refusal feedback,
the visible power line, the vault's view.

---

## 8. Options deferred: not in G1
- **A 10 kg toolbox** somewhere in the room, so two throws open the
  shutter too. It's a second legal solution, but it muddies the first
  lesson. Revisit after Skyiah plays.
- **Riding the plate.** It throws objects only. Player launches stay on
  the validated `LaunchPad`.
- **A charger baited into the shutter.** Its rush is about 13 m/s, which
  would be far more than 1,000 J. That makes it a strong combat-ready
  variant of this room, after G3 (see D-19).

---

## 9. Owner playtest card (enemy-free, sound on)
1. What caught your eye first? Did you want to reach the vault?
2. When the crate bounced off, did you know what to try next?
3. Did lever, plate and shutter feel like one machine?
4. What else did you try, and did the room let you?
5. Did a miss or a mistake make you want another go?
6. Did coming back by the loop feel like the room had changed?
7. Would you happily play another empty room built like this?

A bot completing the sequence is not a pass. Skyiah is.

---

## 10. Later gates (planned, not commissioned)
- **Room grammar (G2), after Skyiah approves G1:**
  - one question per room, plus zero to two supporting systems;
  - quiet rooms remain;
  - a base-kit route to everything AP counts, and Echo routes open by
    default;
  - live signals aren't saved, but consequences persist (the
    `PoweredLink` model).
- **Encounters:** the charger's identity and behaviour study is **D-19**
  (`docs/D19_CHARGER_STUDY.md`). It is design only.
- **No generator, composer or schema changes,** and no second room.
