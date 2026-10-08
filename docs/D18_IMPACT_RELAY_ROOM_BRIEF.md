# D-18 — Impact Relay: one mixed-system room

**Dess → Skyiah, Prod and Arty, 2026-10-08. A proposal for review, not
approved for building.** It answers `04_DESS_PLAN.md` in the post-D crew
plan (2026-10-07): three different designs, one recommendation, and one
buildable room brief. The reusable room grammar and the charger
encounter at the end are plans for later gates, not commissions.

**Prod's P0 feasibility verdict had not been pushed when this was
written** (newest remote ref: `review/crossing-d-readability` `0e54caab`,
2026-10-07 20:06 UTC). So the room's key move, "the machine sends a
heavy object into the barrier", comes in three mechanism tiers that
share one layout, one state graph and one progression contract (§4.4).
Prod's spike picks the tier; no second design round is needed.

Source refs:
- **[R]** = the readability build Skyiah played, `bb683ce0`.
- **[T]** = the 0.4 team head `claude/archipepsi-0-4-blindside`, `a266d5da`.
- **[D]** = the original D, `wip/crossing-d-review`, `4462be29`.

---

## 1. Reality check

| Question | Answer in source | Ref |
|---|---|---|
| What must the base kit reach? | Every allocated Check, every key that matters to AP, and the Zone exit. Any of them may need an Echo only if the matching AP rule declares it, and the apworld declares none today. So today the **required** route uses the base kit plus Static Pulse's ranged hit. | [T] `docs/design-proposals/06_THE_AMALGAM.md:1494-1500`, check 23 at `:1780`; `apworld/archipepsi/__init__.py:111-123`; `bridge/archipepsi_bridge/topology.py:1183-1191, 1767-1786` |
| Are optional Echo routes allowed? | Yes. Shortcuts, secrets, "flanks and alternate routes", optional rewards and optional traversal may need anything. No code refuses an extra route. | [T] `06_THE_AMALGAM.md:1504-1510` |
| Echo picked up inside the room? | It may gate local rewards only (DESS-28). This room grants no Echo, so the rule is not engaged. | [T] `docs/ledgers/DESS_POST_PLAYTEST.md:1588` |
| Can pads move objects? | No. `LaunchPad` and `BouncePad` act only on `body is Player` and write `Player.velocity`. Pads have no powered state. | [R] `godot/scripts/gameplay/affordance_nodes.gd` (LaunchPad ~282-449, BouncePad ~451-494) |
| Can something push a prop? | Yes, through a narrow entry point that already exists: `ManipulableBody.receive_impulse()` (a `lightened` body takes double). Kinematic actuators push the bodies they meet and never apply force. | [R] `manipulable_body.gd` ~255-266; `actuator.gd` header |
| What can the hand do? | Carry a flagged object up to 60 kg. A `MEDIUM` object (30–120 kg) slows the walk to ×0.85. The drop is zero-velocity, and there is **no throw** ("PUSH is the throw", an Echo verb). Carrying blocks the Static Pulse. | [R] `hand_carry.gd` header; `constants.gd:234-237` |
| Is there a barrier only a heavy hit opens? | **Yes, already.** `BreakablePanel` refuses any single hit under `MIN_IMPACT` = 2 × Static Pulse (12 vs 6) and shows "NEEDS A HEAVIER HIT". `DestructibleCover` is different: 40 HP from any hits, which is pacing, not a gate. | [R] `affordance_nodes.gd` ~170-250; `destructible_cover.gd`; `constants.gd:188` |
| Does a collision deal damage? | No. Nothing turns collision energy into damage, so the room needs one narrow impact sensor. | [R] same files |
| What if the object is lost? | The carried-object rules send it home if it falls out of bounds (at once) or leaves its allowed volume (after 1 s). "At rest where the player cannot reach it" is **not implemented**, so the layout has to design it out. | [R] `transported_objects.gd:38-52` |
| Does glass stop the Static Pulse? | Unverified (open question 3 in the packet's `07`). **This design does not depend on it.** | — |

---

## 2. What D-18 corrects in D-17

D-17 stays on record as written ([T] `docs/D17_CROSSING_D_ROOM_BRIEF.md`).
For any room built from D-18, these replace it:

1. **"One main activity" becomes "one question".** A room asks one
   physical question, and up to two supporting systems may help answer
   it. That replaces D-17's habit of one system per wing.
2. **Rule 3 is narrowed.** Skipping the intended sequence is not a
   defect. Only two kinds of thing count as one:
   - a Check claimed without reaching its claim spot;
   - an *accidental base-kit* bypass, meaning plain movement doing what
     the room's machinery was meant to do. That is the actual scope of
     the owner's Unweighted ruling ([T] `DESS_POST_PLAYTEST.md:926-929`).

   Echo-enabled skips are legal and welcome. Softlocks, leaving the
   world and broken required access are separate checks, never
   reasons to ban an ability.
3. **The Machine Hall's "so nothing skips the gap"** reason is withdrawn.
4. **Rule 4 stays.** "The base kit reaches everything Archipelago counts"
   is the real AP rule today, and §5 applies it here.
5. **No area-only Echo limits.** The Courtyard-only swing in [D]
   `crossing_d.gd:213-229` is not a pattern to repeat.

---

## 3. Three designs, and the one to build

All three use only what exists: power, a blue movement device, an orange
breakable. Each makes the systems depend on one another.

### A — Impact Relay: power → the machine throws a weight → the impact opens the way
- **Fantasy.** "That machine is aimed at that door. If I give it
  something heavy enough..."
- **Layout.** A high entry gallery overlooks a freight hall. Across the
  hall is a vault: its Check is visible through a high window, and its
  mouth is closed by an orange impact seal. On the floor, a blue
  launch cradle points at the seal, and a dead green line runs from it
  to a lever.
- **Chain.** Lever on → cradle live → a heavy object settles in it → it
  flies → the seal breaks → vault, Check and a loop shortcut.
- **Clever legal skip.** Any single hit of 12 or more breaks the seal
  directly, so the machine is skipped. A PUSH can shove a canister into
  it.
- **Base-kit route.** Yes: walk, carry, pull the lever.
- **Biggest unknown.** A prop thrown repeatably, plus a reliable impact
  sensor (P0 items 1–4).
- **Expected delight.** High. A visible flight, a loud cause and effect,
  and the owner's own idea.
- **Failure case.** The throw is flaky: it misses, tunnels through, or
  lands somewhere unreachable. Then it feels like a broken physics
  toy.
- **Smallest test.** One lever, one cradle, two canisters, one seal, one
  room.

### B — Powered Traverse: power → a live rail gives a new angle → shoot the exposed support
- **Fantasy.** "From up there I could hit that bracket."
- **Layout.** A dead rail loops high around a hall. A collapsed catwalk
  hangs on an orange support whose weak seam faces only the rail's line,
  hooded like `ImpactReceiver`'s plate ([R] `impact_receiver.gd`).
- **Chain.** Lever on → rail live → ride it → shoot the seam (40 HP, any
  weapon) → the catwalk swings down → a bridge to the destination.
- **Clever legal skip.** Swing to a perch with the same angle; catch the
  rail early with a timed jump.
- **Base-kit route.** Yes.
- **Biggest unknown.** A powered state for the rail, and whether a
  hooded seam really can't be hit from the floor.
- **Expected delight.** Medium-high: shooting while riding feels good.
- **Failure case.** It reads as "aim at the orange thing". The weapon
  becomes the key, and machinery and movement turn into delivery.
- **Smallest test.** One rail loop, one seam, one swing-down catwalk.

### C — Reconfigure the Space: break the casing → read the hidden machine → choose what to power
- **Fantasy.** "There's a machine behind this wall, and I get to choose
  what it runs."
- **Layout.** A plant room whose orange panelling hides conduit. Breaking
  panels shows where green lines run, and one exposed junction can feed
  the lift **or** the pad. Each device reaches the destination
  differently.
- **Chain.** Break casing (any way) → junction visible → set it → one
  device live → a route.
- **Clever legal skip.** Swing past both devices; break panels in any
  order.
- **Base-kit route.** Yes.
- **Biggest unknown.** Whether reading the conduit is interesting, and
  whether the two outcomes are a real choice.
- **Expected delight.** Medium: curiosity rather than spectacle.
- **Failure case.** It collapses into "break box, flip switch", two
  chores.
- **Smallest test.** Three panels, one two-way junction, two devices.

### Recommendation: A, built at whichever mechanism tier P0 supports

- **Why A.** Its three systems form a single cause and effect. Each one
  answers a question the previous one raised.
- **It survives P0.** Its fallback tiers (§4.4) keep the same chain, so
  a bad P0 result changes how the room is built, not what it is.
- **Its skips are fun, not fatal.** The heavy-hit and PUSH skips come
  from rules that already exist, so nothing has to be invented to allow
  them.
- **Why not B or C first.**
  - **B** is cheaper but drifts toward combat-as-key.
  - **C** is the right shape for a later "recontextualise" room, once
    one chain has proved fun.
- **Fallback if even tier 3 fails:** B.

---

## 4. D-18 room brief: Impact Relay

### 4.1 The first ten seconds
You step from the connector onto a glass-fronted gallery 4.5 m above a
tall freight hall: cold station steel, roof trusses, quiet. Straight
across the hall, a lit vault sits behind a tall window, and on a raised
dais inside it stands the Check. Below the window, the vault's mouth is
closed by a battered bulkhead with orange impact seams. In the middle
of the floor, a squat blue-trimmed cradle points straight at that
bulkhead, holding a packing crate. A dark green line runs from the
cradle to a lever at the foot of the stairs below you. To the left is
a rack holding two steel canisters.

In ten seconds the player has seen:
- the **destination**: the Check;
- the **barrier**: the orange seal;
- the **machine aimed at it**: the cradle, which is the landmark;
- **power**: the dark line to the lever;
- the **material**: the canisters.

They don't yet know what any of it does.

### 4.2 Layout (indicative; Prod measures and adjusts)
Axes: x points east, z south, y up. The hall floor is at y = 0.

```
                               N
   +----------------------------------------+------------+
   | stair ->  [lever]  [rack: 2 canisters] |            |
   |   ^          :      ledge above, y 6   |   VAULT    |
   | GALLERY      :                         |  8 x 8 m   |
   | y 4.5,       :..green..[CRADLE]==lane==>SEAL   dais  |==> onward door
   | glass front            blue, aimed east|(orange)    |
   | south landing                          |            |
   +--[door: opens from other side]---------+--[latch]---+
      '----------- service corridor (loop) ----------'
```

| Part | Size or position | Why |
|---|---|---|
| **Hall** | 26 × 22 m. Closed roof at 10 m, with trusses. | Room for swing and arc recovery. Closed so nothing leaves the world. |
| **Gallery** | West wall, y = 4.5, 4 m deep. Glass front. A stair runs down the north wall. The south landing has an open edge for dropping straight to the floor, which is legal. | Preview, plus a base-kit way down. |
| **Lever** | Floor, at the stair foot (Arty's kit lever, Prod's mapping). Its raceway runs about 8 m along the floor to the cradle. | The first thing you reach. The line is the explanation. |
| **Rack** | North wall, near the lever. Two **45 kg canisters** (`MEDIUM`, carriable). Rack top 1.2 m. | Heavy enough to count, light enough to carry. The spare makes retries trivial. |
| **Cradle** | Floor, west of centre. 2.4 × 2.4 m tray with 0.3 m lips that funnel a dropped object onto one canonical seat (like `LaunchPad`'s canonical origin). About 17 m from the seal, aimed at its centre. | One seat gives one repeatable trajectory. |
| **Seal** | In the east wall at floor level, a 3 × 3 m opening. Per-hit rated like `BreakablePanel` (`MIN_IMPACT` 12), sized up or built from panels. | A plain material reason it can't simply be shot. |
| **Vault** | 8 × 8 m, ceiling 6 m. A west window at y 3.5–5.5 above the seal. The Check sits on a dais about 2.5 m high, with steps inside. **Prod confirms the eye line from the gallery to the Check.** | A destination visible early. |
| **Onward door** | Vault, east wall. | The way on lies behind the room's question. |
| **Loop shortcut** | A door in the vault's south wall, latched on the vault side. A corridor runs outside the hall's south wall to a door at the gallery's south end. The gallery side reads "OPENS FROM THE OTHER SIDE". | The return changes. On later visits it bypasses the hall. |
| **Ledge** | North wall, y = 6, a 3 m alcove with a **local** stand-in. Base-kit reach from rack, cradle or floor stays far below it. Reached by swinging from a truss, or any mobility Echo. | An optional Echo reward with nothing required behind it. |

### 4.3 States, not button order

```
power:   OFF <--lever--> ON                    (live; recomputed, not stored)
cradle:  DARK --power ON--> COCKED --occupant at rest, not held, 0.3 s--> WIND-UP (1.0 s)
         WIND-UP --> FIRED --> RE-ARM (2 s) --> COCKED
         any state --power OFF--> DARK          (wind-up cancelled; nothing fires)
object:  AT REST <-> CARRIED ; AT REST --fired--> IN FLIGHT --> AT REST | LOST --> HOME (rack)
seal:    INTACT --glance (light, slow or weak hit)--> INTACT + scuff
         INTACT --qualifying impact or a hit of 12 or more--> BROKEN   (irreversible)
check:   UNCLAIMED --claim on the dais--> CLAIMED  (stand-in; sends nothing)
loop:    LATCHED --interact on the vault side--> OPEN  (irreversible)
```

| State | Owner | What the player sees and hears | What changes it | On restart | Reached another way? |
|---|---|---|---|---|---|
| **power ON** | Room (lever) | The lever handle throws. Green runs along the raceway to the cradle. The cradle's green pilot lights. | Lever | OFF | — |
| **cradle COCKED** | Room | The tray settles back with a clunk. The blue emitter rails glow, with a low hum. | power ON | DARK | — |
| **WIND-UP** | Room | A rising whine, the tray tilts, and the blue rails pulse faster. Telegraphed so you can step out of the lane. | Occupant at rest and not held | — | — |
| **FIRED / IN FLIGHT** | Physics | The object leaves along an arc of about 1.0 s with an apex near 3 m. | Wind-up done | Objects back to their start poses | PUSH (Echo) can also send a canister |
| **seal glance** | Room | Dull thud, a spark along the seam, a scuff mark. Static Pulse hits spark too. The short plain label is allowed. | Light object, slow object, or a hit under 12 | Scuffs cleared | — |
| **seal BROKEN** | Room | The casing splits along its orange seams, panels fall, and the vault light floods the hall. | Qualifying impact, or a single hit of 12 or more | INTACT | **Yes.** A heavy-hit Echo or a PUSHed canister reaches the same state. |
| **loop OPEN** | Room | The latch swings and the corridor lights. | Interact on the vault side | LATCHED | Any route into the vault |
| **Check CLAIMED** | Bridge stand-in | The usual stand-in pickup. | The claim volume on the dais | Unclaimed | Any route into the vault |

- **Irreversible within a run:** the seal, the loop door, the Check.
- **Temporary:** power and every cradle state.
- **In a campaign later:** the seal and the loop would persist as accepted
  consequences; power would not. That is the `PoweredLink` model,
  "the signal is live and never saved" ([R] `powered_link.gd`).

**The teaching beat is the light crate already in the cradle.** The
first time the player pulls the lever, the cradle cocks, winds up and
throws the 12 kg crate. It lands on the seal with a thud, a spark and a
scuff, and the seal holds. In one beat the player has watched the
machine's purpose, its aim, its arc and the seal's rating, with no text.
"Something heavier" is the obvious next thought, and the canisters are
in plain view.

### 4.4 Physical contract, and the three mechanism tiers

**What stays the same in every tier:**
- **Canister.** 45 kg, `MEDIUM`, carriable. It leaves the hand only by
  the zero-velocity drop. Drop it into the tray and the lips seat it.
- **Fires only when ready.** The cradle fires only with power ON, a
  non-player occupant at rest and not held (`HandCarry` holder null) for
  0.3 s, after the 1.0 s wind-up. Only one shot per arm cycle.
- **Not for players.** The cradle ignores the player, so it is not a
  base-kit way over walls.
- **What counts as qualifying.** A `ManipulableBody` that reads `MEDIUM`
  or heavier, entering a sensor on the seal's face. Its speed **into
  the face** (along the seal's normal) must be at least about 6 m/s.
  That calls the seal's existing damage path once, with enough to break
  it. A canister dropped or rolled against the face never counts, which
  is physics, not a ban. A `lightened` canister reads `LIGHT` and
  glances, which is EX50-033's own meaning, left as is.
- **Lost canister.** It goes home to the rack if it falls out of bounds
  or leaves the hall's volume, using the §10.4 semantics already in
  `transported_objects.gd`. Nowhere in the hall may let a canister rest
  out of reach. Prod proves this with a scatter test, for example 50
  throws with ±10 % speed jitter. With the spare canister and the
  review menu's restart, there is always a next try.
- **The player in the lane.** A canister that hits the player just
  bounces off and lands on the floor. That counts as a miss, with no
  damage. Prod confirms no physics damage path exists.

| Tier | Mechanism | New code | Pick it when |
|---|---|---|---|
| **1 — the throw (preferred)** | On fire, the cradle calls `receive_impulse(mass × v)` along one solved arc. That is a fixed velocity change, so every object follows the same painted arc and mass matters only at the impact. The tray animation is cosmetic and synced. | One object-only cradle node, plus the seal's impact sensor. The player `LaunchPad` is not touched. | P0 items 1–5 pass. The throw repeats, nothing tunnels at about 17 m/s, and the sensor fires once per qualifying hit. |
| **2 — lift and drop** | The cradle becomes a loading tray beside the seal. A `LIFT` actuator raises it about 6 m, then a `DOOR`-kind slide pulls the tray floor out. The canister drops down a blue-edged steel chute that turns it into the seal's face. Gravity does the work. | Impact sensor only. The rest is existing actuators. | Tier 1 is flaky but rigid bodies ride actuators and fall reliably. |
| **3 — the ram (minimum)** | A kinematic ram pushes the loaded tray about 4 m along a track into the seal. The break is decided by "the ram reached the end with a `MEDIUM` occupant", read by a `ClassPlate` on the tray. Contact is real, but this is an **authored machine** and is described as one. | A small rule reading the plate and the ram. No sensor. | Collisions at speed are unreliable in Godot's tick. |

Tiers 2 and 3 move the device next to the seal, so the seal is no
longer fired at from across the hall. Everything else stays: the light
crate's lesson, the states, the AP contract.

**Should the player be able to fire the cradle at themselves?** Not in
this room. Riding the relay could be a later variant, but the room
isn't notably less fun without it, so it is deferred.

### 4.5 Progression contract

| Item | Kind | Base-kit route | Echo routes |
|---|---|---|---|
| Stand-in Check `relay_vault` | **Required** (stands where an allocated Check would go) | Gallery → stair → lever → carry a canister → cradle → seal → dais. Walk, carry and interact only; no Echo, and no ranged hit needed. | Heavy hit or PUSH on the seal; any movement Echo anywhere |
| Onward door | **Required** (the exit) | Same route | Same |
| Loop door | Shortcut | From inside the vault | — |
| Local stand-in `relay_ledge` | Optional local reward | None, by design | Swing or any mobility Echo. Allowed, because it is a local reward and not allocated (§29.5a). |

- **Under today's apworld this is compliant.** No Echo, no AP key, and no
  in-room Echo grant. The bridge sees rooms as wholes, so the engine
  proves the in-room base-kit route (Prod's tests in P1.2).
- **The only refusals:**
  - claiming the Check from anywhere but the dais;
  - an accidental base-kit bypass of the seal, the window or the vault
    roof. None is intended. Prod's reach measurement (standable
    surfaces plus the 1.40 m jump) confirms none exists.

  Nothing else is refused.
- **Separate checks, never solved by bans:**
  - **No escape from the world:** run the swing everywhere, since it
    hooks any `StaticBody3D` within 28 m.
  - **No softlocks:** every rest point is reachable, a canister in the
    vault can be walked back out, and power OFF strands nobody.
- **A review instance only.** Offline, with stand-ins that send nothing.
- **Campaign use later (G5).** The barrier uses `BreakablePanel`'s rated
  semantics, and §13.2 keeps rated affordances off a mandatory route in
  composed rooms. So the room would enter the campaign as a declared
  package with its own base-kit opener, like the D12 minor cards, and
  not as a generator affordance. That is a later decision, not part of
  this build.

### 4.6 Teaching, feedback and colour
- **Colour is an accent on real hardware:**
  - green on the lever pilot, the raceway and the cradle's pilot;
  - blue on the cradle's emitter rails and its direction chevrons;
  - orange on the seal's seams and scarring.

  The arc lane may have blue chevrons at the cradle end only.
- **Labels** state plain facts: "POWER OFF" on the lever, "IMPACT SEAL"
  on the bulkhead, and "OPENS FROM THE OTHER SIDE" on the loop door. No
  label gives away the solution.
- **Sound** is part of the explanation:
  - the hum when cocked;
  - the wind-up whine;
  - a thud for a glance, a crack for a break.

  D's isolated host had no `Tones` bound ([R] `crossing_d.gd`), so Prod
  binds sound before playtest.
- **The seal's glance must look like "not enough", not "immune".** It
  should spark and scuff, every time.

### 4.7 Anti-frustration
- **A miss is never far away.** The rack is 8 m from the cradle, there
  is a spare, and lost canisters come home.
- **No reach-only-the-floor trap.** Everything the room needs is on the
  floor or the gallery.
- **The machine shows its state.** It never fires without a wind-up. It
  never fires a held object. It never fires at power OFF.
- **After a failure it still makes sense.** The arc and the glance look
  the same every time.

### 4.8 Hand-offs
- **To Prod.** Pick the tier from P0 and tell me which. Measure:
  - throw repeatability;
  - the sensor firing exactly once per qualifying impact;
  - the scatter rest points;
  - the eye line from the gallery to the Check;
  - whether glass stops the Static Pulse (for the record only);
  - whether any review-equippable action deals 12 or more per hit.
    If none does, the heavy-hit skip stays a documented campaign
    alternate and goes untested here.

  Review kit: the base kit plus the swing tether **everywhere**, with no
  area limit. Enemy-free.
- **To Arty.** One blue device (the cradle: a tray, emitter rails, a
  visible cocked/fired motion) and one orange seal (casing, seams, a
  glance scuff state, a break-apart). Both with power-off, power-on and
  impact states, and Prod's footprints.
- **Cut order if time runs short:**
  1. the ledge;
  2. the loop corridor, replaced by walking out through the broken seal;
  3. tier 1, falling back to tier 2.

  Never cut: the light-crate lesson, the glance feedback, the visible
  power line.

---

## 5. Later gates: planned, not commissioned

### 5.1 Ordinary-room grammar (G2, only after Skyiah approves a D-18 playtest)
- **One question per room, plus zero to two supporting systems.** Not a
  rule that every room needs all three.
- **The verbs already exist:**
  - power → launch;
  - movement → destruction;
  - destruction → access;
  - power → bridge;
  - traversal → machine control;
  - cover → sightline.
- **Intensities:**
  - quiet connector;
  - discovery room;
  - physical puzzle;
  - multi-step interaction;
  - combat-ready room.
- **Generated or hand-built.**
  - Single-cause rooms ("introduce") can probably be generated from
    existing affordances.
  - Throw or impact chains like D-18 stay hand-built packages until
    proven repeatable.
- **Failure modes to check:**
  - mixed systems that don't affect each other;
  - colour painted over whole primitives;
  - a false puzzle gate;
  - interaction cycles that softlock;
  - movement forced into cramped corridors;
  - a clever skip wrongly nerfed.
- **The AP side for every room:**
  - a base-kit route to everything AP counts;
  - optional Echo routes by default;
  - persistence follows `PoweredLink`: consequences persist, live
    signals don't.

### 5.2 One-charger encounter card (G3, design only)
In the Upper Yard's geometry, one charger and nothing else.

- **Before it notices you.** It noses along the orange crates at the
  ramp's foot, a guard checking its stack, visible from the glass
  alcove.
- **Notice.** Only on line of sight. Today notice is a distance and
  works through walls ([R] `enemy.gd`); for this one enemy it should
  need a clear view.
- **Wind-up.** About 0.8 s: it stops, lowers its head, scrapes, and its
  eyes flare, with sound.
- **Commit.** It charges straight at where you were when the wind-up
  ended, and stops tracking you.
- **Miss.** It overruns about 3 m. Hitting a wall or full cover staggers
  it for about 1.2 s, its weak window. Overrunning at the ramp's top
  takes it off the edge for a longer recovery.
- **Crates.** A charge into an orange crate breaks it, so the fight
  changes the cover. This is a hypothesis: the charge would need to
  reach the damageable group.
- **Being hit.** Every hit visibly flinches it, with sound. Only a heavy
  hit, or a burst inside the wind-up, cancels the charge. So the player
  chooses: burst to interrupt, or dodge and punish the stagger.
- **Pacing to measure:**
  - from first sight, its first wind-up starts before baseline fire
    could kill it;
  - there are at least two charge cycles before it dies to a standing
    player;
  - HP is the last lever to touch.

### 5.3 What this does not start
No generator or composer changes, no schema, no AI framework, and no
second room. Each later gate needs Skyiah's playtest of the previous
one.

---

## 6. Owner playtest card (play enemy-free, with sound on)
1. What caught your eye first, and did you want to reach the vault?
2. When the crate hit the seal, did you know what to try next?
3. Did lever, cradle and seal feel like one machine, or three props?
4. What else did you try? Did the room let you?
5. When a throw missed or you got it wrong, did you want another go?
6. After the seal broke, did the room feel different coming back
   through it?
7. Would you happily play another empty room built like this?
8. Did it make you want one more interaction, or just promise future
   content?

A bot finishing the intended sequence is not a pass. Skyiah is.

---

## 7. Decisions for Skyiah
1. **Which concept:** A Impact Relay (recommended), B, C, or a hybrid.
2. **If the throw isn't reliable:** is the lift-and-drop version
   (tier 2) acceptable for this test? Recommended: yes. It is the same
   puzzle without the long arc.
3. **Review kit:** base kit plus the swing tether everywhere, with no
   area limit? Recommended: yes.
4. **The onward door inside the vault,** so the room gates the way on
   like a real campaign room? Recommended: yes. The alternative is a
   loop with the exit outside.
