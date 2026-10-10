# What should these weapons be? A design exploration for the five families

*Arty — 2026-10-10*

**Status: EXPLORATION for the owner to react to. Nothing here is final, built into the game, or canon.**
- **Kept, untouched:** Batch 068 (the layered Glyph effects, the material impacts, the marks, the handoff to Prod) and Prod's working range.
- **Not changed:** damage, timing, firing behaviour or campaign systems.
- **Labelled as proposals:** every gameplay idea below, for Dess, Prod and Skyiah to weigh.
- **The pictures:** 2D concept sketches and diagrams drawn by script, and throwaway Blender maquettes photographed in Prod's own range. They are exploration, not models. No AI-generated imagery was used.

**The owner's note on Batch 068, which this answers:**
> "They look too much like familiar real-world firearms: a revolver, scoped rifle, carbine, shotgun and railgun. The silhouettes are different, but they don't have much personality or a distinctive science-fiction identity."

That's right, and the reason is worth naming. I designed *outlines*: I started from "what does a hand cannon look like?" and made five different outlines of five familiar answers. This exploration starts from the other end: **what does the weapon do, and what would have to be inside it to do that?** The outside comes last.

[WD0: where we are: Batch 068's five guns, five familiar archetypes (Prod's range placeholders are the same ones)](../review/weapon_design_2026-10-10/WD0_where_we_are.png)

---

## 1. What the game already tells us

I didn't want to invent a setting for the guns. The game already has one, and three facts in it shape everything below.

**1. There are no hands.** The viewmodel floats; there is no first-person body (Batch 032, and Prod's rig today).
- A conventional gun is designed around a hand that works it: a slide is racked, a bolt is pulled, a pump is pumped. Without a hand, all of that motion is unexplained.
- **So every weapon here must visibly operate itself.** Its recovery is not something the player does, it is something the machine does, and the player watches.
- This is not a limitation to hide. It is the most distinctive first-person read we have.

**2. The game is an interpretation.** "A local AI was handed a 1998 level editor and told to make a game" (art bible §1).
- Every Echo is Epsilon's *reading* of a foreign item: item → concepts → supported systems → recipe (`ECHOES.md` §15).
- D-21 §6 places future weapon variants inside these five families.
- So a family is not one gun. It is **a frame for many interpretations,** and its design has to leave room for a visiting world to show through.

**3. The world has two owners.** The human facility is cold, grey and institutional, with warm work lights (art bible §1z, §1a). Epsilon is foreign, asymmetric, embedded, and lit from inside. A weapon in the player's hand has to answer: **whose is it?** That question is a design axis, not a footnote.

**The rules from the game itself:**
- **Colours keep their meanings:** blue movement, green power (and Epsilon), orange destructible, red enemy, yellow-and-black hazard.
- **Flat-shaded 1998 brushwork:** strong silhouettes, one dominant cue per object, no greeble.
- **Recoil never moves the aim** (D-21 §4.6).
- **The tracer leaves the visible muzzle.**

---

## 2. One principle across the family: stored energy, made visible

"Sci-fi" here does not mean neon strips on a rifle. I wanted a reason for every unusual feature, and the one that held up was this:

> **Each family stores its energy in a different physical way, and the store is the silhouette.**

| Family | Its fantasy (D-21's role) | What it stores | What you see storing it | What you see releasing it |
|---|---|---|---|---|
| **Foundry** | One perfect, heavy blow you look forward to | **Heat and a raised mass** | a crucible re-glowing, a forge hammer rising | the hammer falls |
| **Sightline** | Reach; quiet, repeatable precision | **Tension in a resonator** | a bead riding forward between two tines | the tines snap and ring |
| **Switchback** | A stream you steer | **Regulated rotation** | flyballs climbing as the motor runs up | a shuttle switching back and forth |
| **Bulkhead** | Get close and commit | **Pressure behind a sealed door** | a hatch dogged shut, a gauge lever locked | the hatch vents through eight ports |
| **Mass Driver** | Move the world | **Momentum in a flywheel** | a heavy disc spinning up, the gun leaning on its gyro | the clutch bangs and the disc stops dead |

Five different physics, so they differ in kind, not in proportion. Each one gives the player a **readiness cue that needs no HUD and no colour**, because it is motion:
- Foundry's hammer is up or down.
- Sightline's bead is forward or travelling.
- Switchback's flyballs are out or in.
- Bulkhead's lever is locked or swung.
- Mass Driver's disc is a blur or still.

[WD2: the energy principle: the five stores, at rest, charged and released](../review/weapon_design_2026-10-10/WD2_energy_principle.png)

---

## 3. Four directions for the family as a whole

These are four answers to "whose is it?". The same five mechanisms are drawn in each direction's treatment, so the directions compare like with like.

[WD1: the four directions, the same five mechanisms in each](../review/weapon_design_2026-10-10/WD1_directions.png)

### Direction A: Station Instruments (adapted from the facility)

- **The idea:** each weapon is repurposed apparatus from the station. A foundry-lab drop hammer, a survey resonator, a regulated motor, a pressure hatch, a cargo flywheel. The player is using the building against what has moved into it.
- **Look:** institutional paint (pale grey, white, pale blue) worn to metal on the edges that work, stencilled lettering, inspection tags, rubber, cable, bolted plate. Asymmetric because it's improvised, not because it's alien.
- **Strength:** it belongs to *this* building and nowhere else, and reads as human, so the player trusts it.
- **Risk:** it can slide back toward "real tools". The mechanisms must stay impossible enough.

### Direction B: Epsilon's Readings (fabricated by Epsilon)

- **The idea:** Epsilon built these the way it builds enemies, "machinery told to be a creature" (art bible §4b): machinery told to be a weapon. Each is Epsilon's reading of a concept ("heavy", "reach", "stream", "breach", "throw").
- **Look:** dense near-black plating at a manufacture the building doesn't use; asymmetric growths through ordinary station plate (Epsilon is embedded, never placed); **one aperture** that lights from inside.
- **Strength:** the strangest and most memorable, and it says something unsettling: you're armed by the thing you're fighting.
- **Risk:**
  - its light is green, which is now also *power* (FU-4);
  - Batch 032 deliberately kept Epsilon off the player's own Static Pulse;
  - a whole arsenal in enemy language may read as enemy.

  Strongest as a **rare tier,** not the family.

### Direction C: Visitor Hearts (influenced by a visited world)

- **The idea:** each weapon is a station-built **carrier** around a **heart** whose form is the family's (a crucible, a resonator, a governor, a pressure door, a flywheel). The heart's *material, motif and accent* come from the visited world that contributed it.
- **It fits the Echo machinery exactly:** the source identity package already derives glyph, accent and particle style per source game (`ECHOES.md` §12). It never replicates an item from another game, as D-21 §6 requires.
- **Strength:** five families, endless variants, and every variant is visibly *from somewhere*.
- **Risk:** the hearts need a careful vocabulary so they don't become fantasy ornaments.

### Direction D: Around the Device (the player's constant)

- **The idea:** the Static Pulse's device is the one thing that is yours (Batch 032). In this direction every family **clamps round it**. The device is the trigger and the power; the family is the apparatus bolted on.
- **Look:** a familiar prism at the heart of all five, so the player always sees their own core, wearing a different machine.
- **Strength:** continuity across weapons, and a clean seam for the Echo system.
- **Risk:**
  - it constrains every silhouette to share a core;
  - whether the device is visible while a family weapon is out is Prod's and Dess's call (the range currently holsters it).

### My recommendation: A's body, C's heart, D's core; B as a seasoning

**A weapon is station apparatus, built around your device, with one heart a visiting world can change.**
- **Station (A)** keeps it human and trustworthy, and specific to this building.
- **The device (D)** keeps every weapon recognisably the player's.
- **The heart (C)** is where Echo variants live later. It never changes the mechanism, only the material and motif of the part that holds the energy.
- **Epsilon (B)** is reserved for a rare "conceptual" interpretation, one aperture, not a whole gun.

Nothing here is lore. It is a way to make the five look like they come from the same place.

---

## 4. The five families

Each family follows the same order: what the weapon is for, three mechanisms I explored (the one I recommend and two alternatives, all drawn), and then the recommendation in detail. The details cover how it works, how it looks, what the player sees, whose it might be, why it's memorable, and labelled proposals.

The **three alternatives are real options,** not straw men. If an alternative appeals more than my pick, that's a useful answer.

### 4.1 Foundry: the forge hammer

[WD3: Foundry, three mechanisms and the recommended one in detail](../review/weapon_design_2026-10-10/WD3_foundry.png)

**What it's for.** D-21: a deliberate single-shot finisher; 2 shots for 24 HP; the only hitscan that clears a rated panel. The owner's test: *do you look forward to the next shot?* So the gap between shots has to be **anticipation you can watch.**

**Explored:**

| | Mechanism | Silhouette | Why not (or why) |
|---|---|---|---|
| **A, recommended** | **Crucible and drop hammer.** A ceramic-lined crucible heats the next slug. A forge hammer on a rear hinge is raised and latched; the trigger drops it onto the crucible's breech, and the blow drives the molten slug out. | a heavy block, with a hammer standing up behind it like a raised fist | The wait is the hammer climbing back and the crucible re-glowing. It looks forward to the next shot *with* you. |
| B | **Pile driver.** An open column of puck-shaped slugs over a short, thick striker; a puck drops, the piston punches it. | a short stack-and-anvil | Strong, but the readiness cue (a puck dropping) is small and quick. |
| C | **Kiln door.** A bell-shaped breech whose front door swings open to fire and shuts to recover. | a bell | Memorable, but a door opening at the muzzle covers the target at the worst moment. |

**The recommendation, Crucible and Drop Hammer:**
- **Mechanism:** heat stores in the crucible's lining; the raised hammer is stored work. The blow converts both: the slug leaves soft and white-hot, which is exactly the Batch 068 slug and its hot trail. The flash *is* molten metal meeting air.
- **Body:** a station frame clamped round your device (A and D), the crucible (the heart, C), and the hammer on its rear hinge. The crucible's mouth is the muzzle: short, thick, a collar of heat-darkened plate.
- **Holding it:** the hammer stands up behind the crucible, the one dominant cue, low in the right of the screen. The crucible's mouth glows dull orange from inside, a temporary heat glow, not a painted strip.
- **Firing:** the hammer falls, and the gun leaps with the blow (mode H's flip is now *caused* by something). The core and flare burst from the mouth.
- **Recovering (0.65 s):** the hammer climbs back on its own (Prod's `mech` beat at 0.5 s is the latch). The crucible re-glows from dull red to orange. Ready is **hammer up, glow up.**
- **Whose it could be:**
  - station: a materials-lab drop hammer;
  - visiting world: the crucible's lining and motif change (the Foundry theme pack is its natural home);
  - Epsilon: a hammer that isn't hinged but *grows* back.
- **Why it's memorable:** you can tell it's ready from across the room, without colour.
- **Proposals:**
  - **[Prod]** the crucible's glow as the readiness cue (presentation only);
  - **[Dess]** if a faster cadence is ever tried, a "cold" early shot is a natural hook, but not now.

### 4.2 Sightline: the tines

[WD4: Sightline, three mechanisms and the recommended one](../review/weapon_design_2026-10-10/WD4_sightline.png)

**What it's for.** D-21: reach (60 m), steady precision, and a miss costs only 0.4 s. D-21's warning matters most here: **Sightline overlaps the Static Pulse** more than anything else (§4.1). Its presentation has to make *reach and precision* tangible, or it reads as a slightly better Pulse.

**Explored:**

| | Mechanism | Silhouette | Why not (or why) |
|---|---|---|---|
| **A, recommended** | **Resonant tines.** Two long, thin tines, side by side either side of the line of fire, held apart under tension. A bead (the needle) rides forward between them; when they snap and ring, the bead is flung down the slot. | an open fork, the lightest weapon | **You aim *through* it.** The slot between the tines is the line of fire, and their tips converge toward the target. Reach becomes something you see. |
| B | **Surveyor.** A theodolite head on a yoke, a graduated arc and a split-prism eyepiece; the shot is a survey dart. | a short telescope on a fork stand | It reads "measures distance", but it is a scope by another name. |
| C | **Long baseline.** A horizontal bar with an optical head at each end (a stereo rangefinder); the shot leaves from the centre. | a wide T | Very distinct, but 30 cm wide in the view: it fights the reticle. |

**The recommendation, Resonant Tines:**
- **Mechanism:** tension in two tines. The release lets them ring, and the ringing is what accelerates the needle. The ring-down is the cadence: you *can't* shoot cleanly until it settles, and you can see it settle.
- **Body:** a slim station chassis on the device, a resonator yoke where the tines root (the heart), and two tines about 0.6 m long. No scope: a sight post at the tips and a notch at the yoke. The weapon is the sight.
- **Holding it:** two thin tines either side of the line of fire, converging toward the target. From behind, you look straight down the slot between them. The least screen mass of the five, so the most of the target stays visible, which is right for the precision gun. The bead waits at the front stop.
- **The maquettes changed this, twice:**
  1. Stacked one above the other, the tines collapsed into a single thin line from the eye.
  2. Side by side but long and level, they foreshortened to almost nothing behind a tall yoke.

  They now splay wide at a low yoke near the eye and converge on the target: a V you look down.
- **Still the weakest read of the five from the eye.** That is partly right for the lightest gun, but a next pass should give the eye one more thing: the rear notch and front posts as a visible gate.
- **Firing:** the bead vanishes down the slot and the tines spring apart, their tips blurring. A thin cold flick at the tips; Batch 068's cold tracer leaves exactly between them.
- **Recovering (0.40 s):** the ringing decays, and a new bead slides forward from the yoke to the front stop. **The bead's travel is the cadence.**
- **Whose it could be:**
  - station: a resonance survey instrument from a materials lab;
  - visiting world: the yoke's material and the bead (a temple's resonance, a clockwork world's tuning);
  - Epsilon: tines that *grow* to length as charge builds.
- **Why it's memorable:** the only weapon that sings and that you look through, not over.
- **Proposals:**
  - **[Prod/Dess]** consecutive hits on one target raise the ring's pitch (presentation and audio only, no damage change), a precision "streak" with nothing new in the rules;
  - **[Prod]** a small range readout etched on the upper tine for D-21's 55 m test;
  - **[Condi]** the ring-down is the tail (D-21: under 400 ms).

### 4.3 Switchback: the governor

[WD5: Switchback, three mechanisms and the recommended one](../review/weapon_design_2026-10-10/WD5_switchback.png)

**What it's for.** D-21: hold to fire at 7 a second, track movers, a continuous buzz with a moving part; **inaccuracy is spread, never camera climb.** Prod's range grows the spread from 1.2° to about 4° as you hold. The trouble with automatic fire is that it all looks the same, so the spread is what this design makes visible.

**Explored:**

| | Mechanism | Silhouette | Why not (or why) |
|---|---|---|---|
| **A, recommended** | **Governor and shuttle.** A small motor drives a shuttle that switches back and forth, striking rounds into two short ports, left then right (Batch 068's alternating flashes). A centrifugal **flyball governor** on top regulates it, and its balls fly outward as the motor runs up. | a compact box with a little spinning "T" of weighted arms on top | **The flyballs' spread *is* the spread.** At 1.2° they hang low; at 4° they're flung out. The player reads accuracy in the corner of their eye. |
| B | **Shuttle loom.** The shuttle runs a visible zigzag track on the side (literally a switchback), feeding alternate ports. | a flat harp-like frame | The best name pun, but nothing in it shows the spread. |
| C | **Escapement.** A large escapement wheel and pallet fork ticking at 7 Hz, the balance wheel's swing growing with held fire. | a box with a big toothed wheel | Lovely, and it shows the spread, but a third large disc in the family (with Bulkhead's and Mass Driver's) blurs the grayscale lineup. Kept as a clockwork-world *heart* for later. |

**The recommendation, Governor and Shuttle:**
- **Mechanism:** rotation, regulated. The motor stores almost nothing (that's the point: it's a stream). The governor is what you watch.
- **Body:** a square station receiver; a forward housing with two short ports side by side; a short skeleton brace behind (D-21 asks for "medium stock / forward housing"). The governor stands on the rear top, a spindle with two arms and two weighted balls (the heart).
- **Holding it:** a compact box; the governor's balls hang at rest beside the spindle, a vertical shape low in the right of the screen. The maquette needed it a third bigger than first drawn to read from the eye.
- **Firing (held):** the spindle spins (it blurs), the balls climb outward with the spread, and the shuttle buzzes, its flashes alternating ports. The gun buzzes from its springs, never climbing.
- **Recovering (release):** the spindle coasts down and the balls drop back. **When they hang, you're accurate again.**
- **Whose it could be:**
  - station: an industrial motor's regulator;
  - visiting world: the governor's balls and their arms (brass and enamel for a clockwork world, stone for a temple);
  - Epsilon: a regulator that *breathes* rather than spins.
- **Why it's memorable:** a little spinning dancer on top of the gun that tells you how wild you're shooting.
- **Proposals:**
  - **[Prod]** map the governor angle to the live spread value (presentation of a number the range already has);
  - **[Condi]** the motor run-up and coast are the `fire_tail`.

### 4.4 Bulkhead: the hatch

[WD6: Bulkhead, three mechanisms and the recommended one](../review/weapon_design_2026-10-10/WD6_bulkhead.png)

**What it's for.** D-21: close range, 8 pellets in a cone, every 1.0 s; a heavy kick, then a pump-like return with no ammo. Up close the pellets add up to one blow, which leaves **one composite mark**. The decision it asks for is to close in.

**Explored:**

| | Mechanism | Silhouette | Why not (or why) |
|---|---|---|---|
| **A, recommended** | **Pressure hatch.** The body is a short pressure drum sealed at the front by a round hatch pierced with **eight ports** (eight pellets). Firing vents the whole drum through the ports at once. The dogging lever swings out to unlock, the drum re-pressurises with a hiss, and the lever swings home and locks. | a short drum with a big round door on the front and a long lever along its side | It's the station's own vocabulary (doors, seals, pressure), and the eight holes tell you what it fires. |
| B | **Bellows.** A pleated bellows behind a flared bell mouth; it breathes in to recover. | a bell and an accordion | A great "breathing" recovery, but the bell mouth is a blunderbuss, a familiar archetype again. |
| C | **Clamshell.** Two jaws (top and bottom) that open to fire and close to recover. | a mouth | Very memorable, but it reads as a creature: Epsilon's language, not the player's. Kept as Direction B's version. |

**The recommendation, Pressure Hatch:**
- **Mechanism:** pressure. The drum is the store; the hatch is the valve; the eight ports are the pellets.
- **Body:** a banded drum (a station pressure vessel), the hatch flange at the front, much wider than the drum, and the dogging lever along the top, hinged near the hatch, with the device clamped under the drum. The hatch is the heart: its port pattern could take a visiting world's motif.
- **Holding it:** the back of the drum, ringed by the hatch's rim and its four dogs, with the lever lying along the top. A broad ring low and right, clear of the reticle. Short and heavy, the widest silhouette in the family.
- **The maquette changed this:** from behind, the first hatch hid behind its own drum (you saw only a cylinder), and the side lever was out of view. The flange is now much wider and the lever is on top, where its swing is seen.
- **Firing:** all eight ports flash at once. The gun heaves up (Prod's 12° kick).
- **Recovering (1.0 s):** the lever swings up about 70° (unlocked), the drum hisses as it refills, and the lever swings home with a clunk. This is Prod's pump beat (0.30 s), turned from a slide into a swing you can see without a hand.
- **Whose it could be:**
  - station: a pressure-door seal and drum;
  - visiting world: the hatch's port pattern and rim (a wreck's riveted hatch, a temple's stone seal);
  - Epsilon: the clamshell.
- **Why it's memorable:** you carry a door, and up close it stamps its face into the wall.
- **Proposals:**
  - **[Prod, presentation]** at 3 m or less, the composite mark is the hatch's **eight-port rosette**, so the player sees the gun's face in the wall, scattering into separate pocks with distance (D-21's "one composite mark plus a few chips");
  - **[Condi]** the hiss of re-pressurising as the mechanical tail.

### 4.5 Mass Driver: the flywheel

[WD7: Mass Driver, three mechanisms and the recommended one](../review/weapon_design_2026-10-10/WD7_mass_driver.png)

**What it's for.** D-21: hold to charge (1.2 s), release a visible heavy projectile, and **move the world**: crates, the 36 kg weight, an enemy off a ledge. Batch 068's version was a railgun with rings, the most generic answer there is. "Momentum" is the honest physics of pushing things, so that's what this design stores.

**Explored:**

| | Mechanism | Silhouette | Why not (or why) |
|---|---|---|---|
| **A, recommended** | **Flywheel and clutch.** A heavy disc on the near side spins up while you hold. Release bangs a clutch in: the disc stops dead and its momentum leaves in the slug. | a gun with a big wheel on its side, the only round silhouette | **Charge is visible as blur:** spokes, then a blur, then a solid disc. The disc stopping is the release. And a spinning wheel is a gyroscope, so the gun *leans* as it charges. |
| B | **Ballast sling.** Two arms draw a dense ballast block back against tension; the gun sags with the charge and flings the block. | a fork with a block in it | Wonderful weight read (the sag), but the arms make a crossbow, a familiar archetype. |
| C | **Captive mass.** A dense sphere held in a closing cage that grows heavier as it charges. | a cage and a ball | The most alien option (Direction B's version), but a glowing sphere is close to the generic "charge orb". |

**The recommendation, Flywheel and Clutch:**
- **Mechanism:** momentum. Holding stores angular momentum; the clutch converts it to linear; the slug carries it into the crate. *Moving the world* is what flywheels do.
- **Body:** a launch channel (an open rail, the slug visible in its cradle), the flywheel on the near side, a heavy clutch block between hub and channel, and a hopper on top that drops the next slug. The flywheel is the heart; its spoke pattern and rim could take a visiting world's material.
- **Holding it:** a large disc low in the right of the screen, seen at an angle: the spokes are visible, the disc is still, and the slug sits in its cradle.
- **Charging (1.2 s):** the spokes blur into a solid ring as it spins up. The gun creeps forward and **leans** a few degrees on the gyro, and the lean is the charge, readable in grayscale. A tap releases early: the disc only half-blurred, a weaker shot, as the rules already do.
- **Releasing:** the clutch bangs. The disc stops *dead* (spokes snap back into view) and the slug leaves. A big straight shove, then a **sag**: the gun hangs heavy for a moment, the disc now dead weight. That is D-21's "a big shove, then a sag".
- **Recovering:** the next slug drops from the hopper into the cradle.
- **Whose it could be:**
  - station: a cargo-handling flywheel;
  - visiting world: the wheel's rim and spokes (a clockwork escapement wheel, a wreck's ship's wheel, as material rather than replica);
  - Epsilon: the captive mass.
- **Why it's memorable:** you hear and see it wind up, and when it stops, something across the room moves.
- **Proposals:**
  - **[Prod]** the gyro lean as a viewmodel rotation proportional to the charge (presentation only, never the aim);
  - **[Prod/Dess]** the hopper's slug as a visible "loaded" state between shots;
  - **[Condi]** the spin-up whine and the clutch bang.

---

## 5. The five together

[WD8: the five recommended concepts as maquettes, first person in Prod's range: hold, charge or ready, fire, recover](../review/weapon_design_2026-10-10/WD8_first_person_states.png)

[WD9: the lineup in grey: silhouettes side by side, and the five at rest from the eye](../review/weapon_design_2026-10-10/WD9_lineup_gray.png)

**What the maquettes taught.** Three things a side drawing couldn't, fixed before these final photographs:
- **Sightline's fork:** stacked tines read as one line from the eye, and a long level fork foreshortened to nothing. It is now a V splayed wide at a low yoke. Still the weakest read.
- Bulkhead's hatch hid behind its own drum, so the flange is wider and the lever on top.
- Switchback's governor was too small, so it is a third bigger.

Foundry's hammer and Mass Driver's disc read from the first try.

**Do they work as a family?**
- **Silhouettes:** the lineup separates in grey by *kind*, not proportion:
  - a block with a raised hammer;
  - an open fork;
  - a box with a spinning T;
  - a drum with a door;
  - a gun with a wheel.
- **Readiness:** each has a different motion cue in the same screen zone (low right), never on the reticle.
- **Shared language:**
  - station paint on all five, each clamped round the player's device (Directions A and D);
  - one heart each, which is where a visiting world would show (Direction C);
  - light only where energy actually is: inside the crucible, between the tines, at the ports, in the clutch. No strips.

**First-person rules I held them to:**
1. **Self-acting.** Every recovery is a visible motion of the machine, because there is no hand to explain it.
2. **The centre stays clear.** Every mechanism sits right of and below the reticle; the muzzle flash is the only thing allowed near the line of fire, and only for a few frames.
3. **One dominant cue each,** in the lower-right quadrant, readable in peripheral vision and in grey.
4. **Motion over colour.** A colour-blind or grayscale player reads every state from motion.
5. **Recoil is caused.** The hammer falls, the hatch vents, the clutch bangs; the springs Prod already has get a visible reason.
6. **No pistol grips.** With no hands, a grip floating in mid-air is the most firearm-like thing on a gun and does nothing. Every concept is clamped round the player's device instead (WD1–WD7). Direction A's version carries a station tool's bail handle; Epsilon's grows a stalk.

---

## 6. What I'd like from you

1. **The family direction.** Is "station apparatus around your device, with one heart a visiting world can change" right? Or does one of the other directions (pure station, Epsilon's readings, visitor hearts as the whole gun) excite you more?
2. **Per family:** recommendation or alternative? The alternatives are real:
   - the **Kiln door** and **Pile driver** for Foundry;
   - the **Surveyor** for Sightline;
   - the **Escapement** for Switchback;
   - the **Bellows** for Bulkhead;
   - the **Ballast sling** for Mass Driver.
3. **Which one should go to a first real model?** I'd suggest **Foundry's forge hammer**, since it's the benchmark weapon.
4. **For Dess and Prod (proposals, not changes):**
   - the readiness cues (hammer, bead, flyballs, lever, disc);
   - the governor-as-spread readout;
   - the rosette mark;
   - the gyro lean.

## 7. What this is not

- **Not models.** The maquettes are boxes and prisms posed by hand to test a read, thrown away after (`tools/blender/study_weapon_concepts.py` writes outside `assets/`).
- **Not lore.** "Station", "Epsilon" and "visiting world" are design lenses, not canon.
- **Not a change** to Batch 068, Prod's range, damage, cadence, firing behaviour or any campaign system.
- **Not tested in play.** These are frozen poses, not animation.

**Rebuilding the pictures** (all deterministic):
```
python3 tools/concept_art/weapon_concept_sheets.py OUT [RENDERS]          # WD0-WD7, WD9 (+WD8 with RENDERS)
.tools/blender/blender -b --python tools/blender/study_weapon_concepts.py -- MAQ
python3 tools/crossing_capture/weapon_concept_photos.py MAQ SPECS        # dcap specs, then dcap.gd per spec
```
The photographs come from a read-only checkout of Prod's `review/hand-cannon` range (`da0a859e`), at his five-weapon rig pose.

**STOP for the owner's reaction.** No watchers, subscriptions or merges.
