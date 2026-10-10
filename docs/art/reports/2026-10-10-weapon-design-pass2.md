# The five weapons, hybrid direction: design pass 2 (mechanisms for approval)

*Arty — 2026-10-10*

**Status: for MECHANISM APPROVAL. No final models have been started, and none will start until you've reviewed and approved each mechanism.**
- Batch 068, Prod's range, damage, timing and firing behaviour are untouched.
- Pass 1 (`2026-10-10-weapon-design-exploration.md`) stays as the record.
- Gameplay ideas are labelled as proposals.

**Your direction (Skyiah, 2026-10-10):**
- **The hybrid:** station-built engineering, Epsilon technology and foreign-world-influenced Echo cores.
- **Keep the mechanism-first process.**
- **The visual-quality bar:** "Functional sci-fi detail > intentional simplicity > meaningless decorative sci-fi detail." Believable mechanical complexity: interacting parts, purposeful housings, cooling, energy transfer, articulation, material differences, wear and construction. Every major feature has a reason. No random glowing lines, vents or panels.
- **First person:** detail should reward close inspection while staying readable in movement and firing.

The pass-1 maquettes were deliberately blocks; you were right that their look can't go anywhere near production. This pass designs each weapon to the level where you can approve **how it works, part by part**, before anything is modelled.

---

## 1. The hybrid as a power train

[WC0: the hybrid language](../review/weapon_design_pass2_2026-10-10/WC0_hybrid_language.png)

A mix of three styles would look like a costume. Instead, each weapon is a **three-stage power train, one stage per origin**, so the hybrid is a story you can follow along the gun:

| Stage | Origin | Its job | How it looks |
|---|---|---|---|
| Source | **Echo core** (the visiting world) | the capability itself; swappable | foreign material; its accent comes from the source game's identity package (violet in the drawings is a placeholder) |
| Converter | **Epsilon** | turns the source into one form of energy | dense black plate at a manufacture the station doesn't use; it **bursts through** station plate; lit only through its seams |
| Mechanism | **station** | stores the energy, delivers it, survives it | institutional paint worn to metal where it works; fasteners, guards, stencils, inspection tags |

**The player's device is the fourth owner.** Every family clamps round it, so there are no pistol grips (first person has no hands).

**Why the work is split this way.** Each origin does what it is believable doing:
- the humans who built the station could build a hammer, a flywheel or a pressure door, but not a heat source that fits in a hand;
- Epsilon could;
- the foreign core is what Epsilon is interpreting.

So the most impossible part of each weapon is always the Epsilon part, and the swappable part is always the core.

| Weapon | Echo core (source) | Epsilon (converter) | Station (mechanism) | What it stores |
|---|---|---|---|---|
| **Foundry** | an ingot cartridge | heat lattice round the crucible | crucible, drop hammer, re-cock strut | heat and a raised mass |
| **Sightline** | a tuning seed | resonance drivers at the tine roots | tines, node dampers, bead feeder | tension in a resonator |
| **Switchback** | a rotor | the motor | governor, throttle linkage, shuttle, rod cutter | regulated rotation |
| **Bulkhead** | a pressure charge | membrane compressor | drum, hatch, cam ring and dogs | pressure behind a door |
| **Mass Driver** | a dense hub | field drive in the guard ring | flywheel, dog clutch, brake band, gimbal | momentum |

---

## 2. What "detail" means here

[WC1: the fidelity ladder, the same hammer at four levels](../review/weapon_design_pass2_2026-10-10/WC1_fidelity_ladder.png)

**The test:** every detail has to name its job. A part that can't name one is decoration, and it goes.

| Job | Examples |
|---|---|
| mechanical | the strut that re-cocks the hammer, the pawl that holds it, the cam that drives the dogs |
| structural | rails, posts, hoop bands, cradles |
| thermal | fins where the heat is, ceramic spacers that keep the frame cool, vents that purge steam |
| energy | the core, the converter, the cable loom |
| mounting | the cam clamps that fix the family to the device |
| maintenance | screws, nozzle inserts, a hatch hinge, tuning screws |
| readout | the gauge, the flyballs, the bead |
| safety | the guard ring round a spinning wheel, a relief valve that vents up and never at the player, tip caps |

**What this pass deliberately does:**
- **Explains every motion the player sees.** No hands means the recovery is done by a part, and the part is drawn: the gas strut, the throttle linkage, the cam ring, the clutch fork.
- **Puts heat where it is.** Fins only on the Foundry's mouth and the Switchback's shrouds, the two parts that get hot. The Foundry's quench vent gives its residual smoke a cause.
- **Shows wear where hands, tools and heat work.** Chipped paint on clamp edges and hoop bands, heat tint on the mouth, an inspection tag on a band.
- **Uses stencils that say something.** "HOT 1400C", "MAX 40 BAR", "KEEP CLEAR OF WHEEL", "RATE 7/S". Station labelling, not alien greebles.

---

## 3. The five, for approval

Each sheet has:
- the elevation with numbered parts;
- the parts list (owner, job, and why it exists);
- the power train in section;
- the key mechanism exploded;
- what it does, in three states.

### Foundry: crucible and drop hammer

[WC2: Foundry](../review/weapon_design_pass2_2026-10-10/WC2_foundry.png)

**What's new since pass 1, and why:**
- **The hammer is held, released, and re-cocked:**
  - a latch pawl holds it up;
  - the device's trigger signal fires a solenoid that drops it;
  - a **gas strut** lifts it back. That is the "climbs back by itself" the player watches.
- **The blow has a path:** hammer → anvil → striker → ram → the slug in the crucible.
- **The slugs come from somewhere:** a station magazine of plain blanks feeds the breech. They are melted, not loaded rounds.
- **The heat is contained and kept off you:**
  - an Epsilon lattice bursts through the lower casing and turns the core's output into heat in the ceramic lining;
  - ceramic spacers keep the rail and the device cool;
  - fins shed heat at the mouth;
  - a quench vent purges steam after each shot, so the smoke has a cause.
- **The core** sits in a cradle under the crucible: swappable, latched, and the only foreign material on the gun.

### Sightline: resonant tines

[WC3: Sightline](../review/weapon_design_pass2_2026-10-10/WC3_sightline.png)

**What's new since pass 1, and why:**
- **Why its kick is small:** rubber isolation mounts let the tines ring without shaking the gun.
- **Why its cadence is 0.4 s:** node damper pads clamped at the vibration nodes stop the ring.
- **How it is tuned:** micrometer tension screws on the yoke.
- **The source:** the core is a tuning seed caged on the yoke, because it is brittle. The Epsilon resonance drivers grip the tine roots, and their seams pulse with the ring.
- **Where the rounds come from:** a bead feeder (tube and escapement) under the yoke.
- **Sighting:** front posts with a windage screw, and a rear notch on the yoke. You aim down the slot.
- **Protection:** the tips are capped, because a bent tine detunes the gun.
- **Proposal:** a range scale etched on the tine (20 / 40 / 60 m) for D-21's long-range test.

### Switchback: governor and shuttle

[WC4: Switchback](../review/weapon_design_pass2_2026-10-10/WC4_switchback.png)

**What's new since pass 1, and why:**
- **The governor really regulates.** Its sleeve pulls a throttle linkage on the Epsilon motor, so the flyballs climbing is the motor running faster *and* the spread opening. The readout is the mechanism.
- **The source is visible:** the core is the rotor, seen through a window in the motor.
- **No magazine and no reload:** plain bar stock feeds through the brace on guide rollers, and a cutter chops a slug each stroke. The rod advances as you fire, which is another motion cue.
- **Reversals are handled:** the shuttle runs on rails between rubber buffers.
- **Sustained fire runs hot:** the only weapon that does, so it has perforated shrouds round the twin ports and slotted flash hiders, so held fire doesn't blind you.
- **Service:** an access panel over the cutter, held by four screws.

### Bulkhead: pressure hatch

[WC5: Bulkhead](../review/weapon_design_pass2_2026-10-10/WC5_bulkhead.png)

**What's new since pass 1, and why:**
- **The heavy kick has a cause and a limit:** the drum rides on a cradle with two shock absorbers.
- **The source:** the core is a pressure charge, bayonet-locked in the rear cap. An Epsilon membrane compressor under the drum turns it into pressure through a braided charge hose.
- **The lever is a real linkage:** it turns a **cam ring**, and the cam ring drives **four dogs** that lock the hatch against the drum's pressure. "Swings up to vent" is the lever unlocking the hatch.
- **Eight nozzle inserts, one per pellet,** screw in as wear parts. The hatch has a hinge so they can be changed.
- **Safety and readout:**
  - a sprung relief valve vents up, never at the player;
  - the gauge is a second ready cue.

### Mass Driver: flywheel and clutch

[WC6: Mass Driver](../review/weapon_design_pass2_2026-10-10/WC6_mass_driver.png)

**What's new since pass 1, and why:**
- **The mass is at the hub:** the core is the dense hub at the flywheel's centre. Epsilon's field-drive segments, set into the guard ring, spin the wheel without touching it.
- **A guard ring,** because a spinning wheel beside the player's head gets one.
- **The lean is mechanical:** the flywheel group sits on a **gimbal**, so the gun leans on its gyro while the aim stays true.
- **Release:** a **dog clutch** thrown by a solenoid fork bangs in. The wheel stops dead and the sabot slug goes.
- **Power-down:** a **brake band** bleeds the remaining spin after a tap.
- **The slug is seen:** the launch channel is open on top. A hopper with a gate drops the next slug.
- **Balance:** balance weights on the rim, because a wheel that size has to be balanced.

---

## 4. Readable in play, rewarding up close

[WC7: three distances: at speed, in play, up close](../review/weapon_design_pass2_2026-10-10/WC7_readability.png)

Detail is tiered by distance:

| Distance | What must read | Where detail belongs |
|---|---|---|
| **At speed** (small, grey, motion-blurred) | the silhouette and the one moving cue: hammer, fork, flyballs, drum and door, wheel | nothing finer: it can't survive |
| **In play** | primary forms and owners: station paint against Epsilon black against the core | large parts only |
| **Up close** (the rear-upper zone nearest the eye, and the camera-facing top and left side) | everything | fasteners, stencils, wear, the core's material |

The surfaces the player never sees (the underside and the far side) stay simple.

**The finding:**
- At speed, Foundry, Switchback, Bulkhead and Mass Driver still read by silhouette and cue.
- **Sightline thins to a line.** That suits the lightest gun, but it needs the rear notch and front posts to carry more weight in the final model (pass 1 found the same).

---

## 5. A budget question that has to be settled before modelling

The art bible already targets this era: "Late-1990s PC FPS. GoldSrc / Quake-era" (§1), and GoldSrc is Half-Life's engine. Half-Life's own weapons got their richness from **many distinct, purposeful parts plus hand-painted textures, not from smooth high-poly surfaces.** That is exactly this pass's approach, so the direction fits the bible.

But the bible has **no viewmodel triangle ceiling yet**, and its viewmodel texel tier (256 texels/m) is marked **deferred, not built** (`ART_BIBLE.md` §2). These designs need both decided, and adding a budget category is a decision for you and Prod, not for the art lane.

**My proposal, for you and Prod:**
- **A `viewmodel` budget category.** It sits ~0.4 m from the eye (§2) and on screen all the time, so it should get more than `hero` (1,200). I'd derive the number the way the bible derives every ceiling, starting from roughly 2,500–4,000 triangles with no hands to spend them on.
- **Textures:** the bible's reserved 256 texels/m, with painted wear, stencils and edge highlights.
- **Edges:** one-segment chamfers on viewmodel edges that catch light. The bible allows a 1-segment micro-bevel only on hand-scale props over 0.5 m that the player walks up to (§2). A viewmodel is not one of those, so this would **extend** that exception to the most inspected object in the game, and it needs approval like the rest.
- **Shading:** flat, as everywhere else.

This is a proposal. Nothing is modelled until it is settled.

---

## 6. What I need from you

1. **Each mechanism: approve, change, or reject.** In particular:
   - Foundry's gas strut and melted blanks;
   - Sightline's damper pads setting the cadence;
   - Switchback's rod-and-cutter feed (no magazine);
   - Bulkhead's cam-and-dog hatch;
   - Mass Driver's gimbal lean and brake band.
2. **The power-train split** (core, then Epsilon, then station). Right for the hybrid?
3. **The budget proposal** in §5, with Prod.
4. **Epsilon's light colour.** Its seams are drawn in the art bible's identity green, which now overlaps "green = power" (FU-4, still open).
5. **After approval, my suggested next step:** one 3D fidelity study of the Foundry, to calibrate the budget and the chamfer, texture and wear treatment against your bar before the other four are modelled.

## 7. What this pass is not

- **Not models.** These are 2D side elevations, sections and exploded views. The pass-1 maquettes have not been updated and stay blockouts.
- **Not canon.** "Station", "Epsilon" and "Echo core" are design roles.
- **Not a change** to damage, cadence, firing behaviour, Batch 068 or Prod's range.
- **Not tested in play.**

**Rebuilding the sheets** (deterministic):
```
python3 tools/concept_art/weapon_detail_sheets.py OUT     # WC0-WC7
```
Sources: `tools/concept_art/detail_kit.py` (the drawing kit) and `tools/concept_art/weapon_details.py` (the five designs and their parts lists).

**STOP for mechanism approval.** No watchers, subscriptions or merges.
