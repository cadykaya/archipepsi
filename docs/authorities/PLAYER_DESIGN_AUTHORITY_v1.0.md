# ARCHIPEPSI — PLAYER DESIGN AUTHORITY v1.0

**Date:** 2026-09-02  
**Status:** Canonical full-game player target. This document finalizes the player-facing architecture; numerical tuning remains playtest-owned.  
**Scope:** Player body, controls, baseline actions, the Epsilon device, Weapon Echoes, Ability Echoes, Mobility Echoes, interaction, carryables, physics tools, combat resources, damage/defense, crit/overcrit, Status philosophy, Gear, Mods, loadout boundaries, progression-capability access, HUD/readability, first-person presentation, and migration from the current executable.  
**Supersedes where conflicting:** Earlier player/input/loadout drafts, including `E = interact`, `F = fire_echo_b`, the old single/dual-Echo control grammar, the `C` Utility slot, the old permanent “base movement + default attack solves every mandatory path forever” POC restriction, and the deterministic universal Status-pressure draft.  
**Does not supersede:** Archipelago item/location truth, Python/Godot authority boundaries, room-contract authority, authored-content ownership, persistent AP transaction rules, or validated capability-planning rules.

---

# 0. WHY THIS DOCUMENT EXISTS

The player redesign was decided in pieces while Archipepsi was also rebuilding room architecture, traversal validation, combat architecture, Echo interpretation, and procedural composition.

That made the individual ideas easy to remember and the **whole player** increasingly easy to lose.

This is now a real project risk. LARGE rooms, dungeon machinery, physical interaction, traversal offers, encounter design, Echo buildcraft, and semantic progression all depend on one stable answer to a basic question:

> **What can the Archipepsi player actually do, what inputs do those actions own, and what guarantees can the rest of the game safely design around?**

This document gives that answer.

It deliberately distinguishes four layers:

1. **Architectural laws** — stable truths other systems may rely on.
2. **Final v1 player-facing decisions** — the actual control/loadout shape we are building.
3. **Tuning values** — numbers that may change through playtesting without reopening the architecture.
4. **Deferred systems** — ideas that are valid possibilities but are intentionally outside the v1 player.

“Final” does not mean “never improve this again.” A later explicit owner decision or strong playtest result may revise this document. What it does mean is that Production should no longer choose between contradictory old drafts, half-implemented controls, and buried chat decisions.

---

# 1. THE PLAYER FANTASY

Archipepsi’s player is not a walking inventory of unrelated guns, spell icons, keys, and passive percentage soup.

The player has:

- a reliable physical body with a small permanent baseline capability set;
- one physical **Epsilon device** whose Weapon Echo configurations reinterpret how it attacks;
- five directly accessible Ability Echoes;
- one dedicated Mobility Echo;
- four passive Gear hosts;
- Mods that make those equipped things collide in surprising ways;
- ordinary hands for touching, carrying, pressing, hacking, and rearranging the authored world;
- optional Physics Echoes that extend those hands without becoming unrestricted telekinesis.

The intended feeling is:

> **I always know what my body can do. I always know how to touch the world. My build changes what the device and I can do, and simple weird rules collide in ways I can learn and exploit.**

Power should come from relationships, not an item-level treadmill.

A casual player should be able to equip something because it sounds fun and receive obvious value immediately. A build-focused player should be able to discover disgusting interactions. Neither player should need to read a wiki entry merely to understand one equipped object.

---

# 2. CORE PLAYER DESIGN LAWS

These are the truths other systems may safely design against.

## 2.1 A permanent baseline exists

The player never loses access to:

- base first-person movement;
- jump;
- world interaction;
- Static Pulse;
- baseline melee;
- menus/pause;
- system-required recovery such as out-of-bounds respawn.

Archipelago luck, Echo interpretation, Forge decisions, a broken generated recipe, a remote item drought, or an unavailable language-model provider cannot remove that floor.

The baseline is not intended to outperform a good build. It exists so the player is never mechanically helpless.

## 2.2 Inputs describe roles, not generated content

Epsilon may select a compatible mechanical family. It may not decide that a generated Echo “uses F,” “requires Alt+Q,” or creates a new input.

The engine owns the control grammar.

Generated content occupies legal roles:

- Weapon configuration;
- Ability slot;
- Mobility slot;
- Gear slot;
- Mod attachment.

This keeps controls learnable even after hundreds of interpretations.

## 2.3 Direct access beats mode churn

Actions expected to combine moment-to-moment are directly accessible.

The player gets:

- a compact Weapon cycle;
- five direct Ability inputs;
- one direct Mobility input;
- permanent melee;
- permanent interaction.

Ordinary combat should not require repeatedly opening radial menus, swapping action pages, or selecting a “current spell.”

## 2.4 Interaction is sacred

`F` belongs to **the world**, not to generated combat.

It means context-sensitive Use / Interact:

- press;
- pick up;
- drop/place;
- pull lever;
- operate;
- hack;
- open;
- activate;
- use terminal;
- other explicit authored interactions.

Generated Echoes may never steal that role.

## 2.5 Each Weapon Echo must stand on its own

Weapon synergy is welcome. Mandatory priming is not.

A Weapon Echo cannot be “the boring thing you shoot first so the actual fun Weapon works.”

The Weapon wheel is for choosing an expression, not performing maintenance rotations.

## 2.6 Complexity comes from combinations of simple rules

One mechanic should usually reduce to a small player-facing sentence.

Examples:

- “Overcrits advance Q.”
- “Defeating an airborne enemy feeds this Ability.”
- “This shot makes light objects easier to move.”
- “This Weapon cools while inactive.”
- “Successful Grapples briefly strengthen melee.”

Several simple sentences may interact in ridiculous ways.

One item should not need a paragraph of hidden exceptions.

## 2.7 Buildcraft may be weird; progression truth may not be lucky

A Zone may require a semantic capability such as `GRAPPLE`, but only when the planner can prove the capability is available before the requirement.

The invariant is:

> **NO REQUIREMENT BEFORE GUARANTEE.**

A hard progression gate never means:

- hopefully the player rolled enough DPS;
- hopefully a crate exploit reaches the ledge;
- hopefully a useful random Echo happened to arrive;
- hopefully Epsilon understood what the designer intended.

Logical capability truth and runtime physical truth must agree.

## 2.8 The world remains a game when Epsilon is absent

The player’s baseline, accepted Echo recipes, controls, combat simulation, dungeon machinery, and loadout projection do not require a live model response to function.

Epsilon is meaningful because it chooses and interprets inside a legal vocabulary, not because every button press asks a model what should happen.

---

# 3. FINAL DEFAULT CONTROL GRAMMAR

All normal player controls must be rebindable.

The table defines **semantic roles and defaults**, not hardcoded physical assumptions.

| Input | Final v1 role | Notes |
|---|---|---|
| `WASD` | Move | First-person planar movement |
| Mouse | Look / aim | Standard first-person camera |
| `Space` | Jump | Permanent baseline action |
| `LMB` | Active Weapon primary | Static Pulse or selected Weapon Echo configuration |
| `RMB` | Active Weapon secondary / intrinsic | Alternate fire, scope, guard, detonate, mode action, etc. when the selected configuration uses one |
| `MMB` | Baseline melee | Permanent directly-accessible melee; rebindable |
| Mouse wheel | Cycle Weapon configuration | Cycles Static Pulse plus up to three equipped Weapon Echoes |
| `Q` | Ability Echo slot Q | Direct |
| `E` | Ability Echo slot E | Direct; no longer world interaction |
| `1` | Ability Echo slot 1 | Direct |
| `2` | Ability Echo slot 2 | Direct |
| `3` | Ability Echo slot 3 | Direct |
| `Shift` | Mobility Echo | Dedicated movement expression |
| `F` | Interact / Use / Pick up / Place | Permanent world-action role |
| `R` | Active Weapon feed action | Reload, vent, feed-specific action, or no-op |
| `Tab` | Archive / loadout | Safe-boundary build interface |
| `Esc` | Pause / system menu | Permanent |
| `4` | Unassigned in v1 | Reserved; no dedicated Signature slot in v1 |
| Debug inputs | Developer only | Never part of player combat grammar |

## 3.1 Why this layout

The pattern matters more than the literal keyboard positions:

- the mouse cluster owns immediate Weapon combat and melee;
- `Q/E/1/2/3` are direct impossible actions;
- `Shift` always means this build’s movement verb;
- `F` always means “do something with the world”;
- `R` always means “service the thing I am currently firing”;
- the wheel changes Weapon expression without touching the rest of the build.

The player therefore retains the same mental model even when the Echoes themselves are bizarre.

## 3.2 Why `E` becomes an Ability slot

`E = interact` was sensible when the active Echo grammar was tiny.

The full game needs five direct Ability inputs. `Q/E/1/2/3` keeps those actions clustered around movement without adding a second mode or radial selection step.

`F` is close enough for frequent world use while clearly outside the Ability cluster.

The final design gives `E` and `F` stable, non-overlapping meanings.

## 3.3 Why baseline melee defaults to MMB

Baseline melee must remain available without:

- switching to a melee Weapon configuration;
- spending an Ability slot;
- consuming a resource;
- receiving an Echo;
- stealing `F`.

MMB keeps melee in the immediate combat cluster while leaving LMB/RMB coherent as the active Weapon’s own pair.

MMB is a default, not an accessibility assumption. Rebinding is first-class.

## 3.4 Why key `4` is not a Signature/Ultimate slot

A dedicated Signature slot was previously considered.

v1 does not use it.

The active player already has:

- up to four Weapon-cycle states including Static Pulse;
- five Ability Echoes;
- one Mobility Echo;
- permanent melee;
- four passive Gear hosts;
- installed Mods and triggered relationships.

A sixth special Ability category would increase HUD/input pressure while telling the item system one type of Ability is constitutionally “more ultimate.”

High-tier Echoes already provide build-defining mechanics inside normal categories. A devastating high-tier Ability may occupy Q, E, 1, 2, or 3 and use a Heavy/rare recharge profile without needing a special slot.

`4` remains available for a future feature only if playtesting identifies a genuinely missing role.

---

# 4. BASE PLAYER BODY AND MOVEMENT

## 4.1 Baseline movement package

The base player can always:

- move;
- look;
- jump;
- modestly correct in the air;
- interact;
- melee;
- fire Static Pulse;
- recover from authored out-of-bounds states.

The target feel is a **medium-fast first-person walk** with a forgiving jump.

Exact movement speed, acceleration, air control, jump velocity, coyote-time duration, and jump-buffer duration are tuning values.

The architecture must expose one authoritative movement law consumed by:

- the player controller;
- authored-room validation;
- procedural-room validation;
- mandatory traversal validation;
- headroom/body-clearance checks where relevant.

The game must not have several slightly different definitions of “a safe base jump.”

## 4.2 No dedicated sprint in v1

There is no ordinary sprint button and no stamina sprint system.

This is intentional.

A hold-to-sprint game often contains the hidden rule:

> “Normal movement is the speed you tolerate while the sprint key is unavailable.”

That would be particularly damaging now that Archipepsi is embracing LARGE rooms.

If crossing a LARGE room is boring at baseline speed, the fix is:

- baseline speed;
- room pacing;
- route composition;
- movement offers;
- encounter rhythm;
- rails;
- launch paths;
- landmarks;
- traversal choices.

“Hold Shift so the empty room is bearable” would conceal weak spatial design rather than fix it.

`Shift` also has a more valuable job: the Mobility Echo.

## 4.3 No baseline crouch or slide in v1

Crouch is not a baseline action in v1. Slide is therefore not a required base movement verb.

That is not a statement that crouching is bad.

It is a scope decision.

A second capsule/stance affects:

- every room’s headroom assumptions;
- doorway/secret dimensions;
- enemy targeting;
- camera height;
- interaction rays;
- traversal audit;
- generated passages;
- collision recovery;
- stealth expectations.

Slide adds momentum/state-transition rules on top.

Those systems should be added only when a real gameplay layer—stealth, momentum movement, low-clearance traversal, or a specific combat fantasy—earns them.

Rooms should not grow arbitrary knee-high tunnels merely because crouching is a traditional FPS checkbox.

## 4.4 Forgiveness

The jump should support:

- a small coyote-time window;
- a small input buffer;
- stable landing;
- predictable air correction;
- frame-rate-independent legality.

The exact windows are tuning.

The goal is not automatic platforming. It is for the controller to honor what the player clearly intended.

## 4.5 Environmental traversal is separate from baseline locomotion

Rails, bounce pads, launch pads, moving platforms, wind, water, and room machinery are **world traversal systems**.

They may be usable by the base player when the room/gameplay package chooses them.

A Grapple point is different: it is an opportunity that requires a compatible Grapple expression when a route truly uses semantic `GRAPPLE`.

This distinction lets rooms remain architecturally rich without pretending every traversal affordance belongs to the naked player body.

---

# 5. THE EPSILON DEVICE

## 5.1 One physical object

The player carries one principal Epsilon device.

Weapon Echoes do not materialize as three unrelated guns hanging invisibly in inventory.

Instead:

> **A Weapon Echo is a configuration/interpretation that the same device assumes.**

The device may visibly reconfigure through authored modular parts, moving mechanisms, silhouette changes, lights, and provenance accents.

Mechanically and fictionally, it remains one device.

## 5.2 Why one device is the right fantasy

Archipepsi is about one system interpreting objects and meanings from other worlds.

A single device makes that fiction visible.

When a foreign item becomes a shotgun-like Echo, beam, launcher, close-range weapon, or something barely recognizable as a gun, the player sees the same machine **trying to understand a new concept**.

Three literal carried guns would work in a conventional loot shooter, but here they would weaken the central fantasy and create extra pressure for:

- weapon pickup/drop rules;
- stash logistics;
- duplicate physical inventories;
- ammo-family inventories;
- first-person model persistence;
- more asset burden.

The one-device model lets complexity live in expression rather than inventory housekeeping.

---

# 6. STATIC PULSE — THE PERMANENT WEAPON FLOOR

## 6.1 Role

Static Pulse is always present in the Weapon cycle.

Even with three Weapon Echoes equipped, the cycle contains:

1. Static Pulse;
2. Weapon configuration A;
3. Weapon configuration B;
4. Weapon configuration C.

Empty slots are skipped.

Static Pulse cannot be:

- unequipped;
- consumed;
- forged away;
- disabled by missing AP items;
- disabled because Epsilon is unavailable.

## 6.2 Mechanical purpose

Static Pulse is:

- simple;
- reliable;
- unlimited in long-term ammunition;
- understandable without generated data;
- sufficient to keep mandatory combat technically possible;
- less expressive than a good Weapon Echo.

It is a floor, not the intended endpoint of buildcraft.

A previous tuning anchor has used roughly 6 damage every 0.35 seconds. That specific number remains tunable. The architectural rule is that Static Pulse is a stable reference baseline against which offensive Echo value can be measured.

## 6.3 Static Pulse is not Epsilon Static

These names are fictionally related but mechanically distinct.

**Static Pulse** is the player’s permanent fallback Weapon configuration.

**Epsilon Static** is an Archipelago-native filler item whose final broader economy/Integrity meaning is a separate system.

Receiving or failing to receive Epsilon Static never determines whether the player has a basic weapon.

## 6.4 Why a baseline ranged attack is mandatory

Without it, a randomized multiworld can create miserable states:

- the first useful Weapon is remote;
- utility arrives before offense;
- a Forge experiment leaves no useful attack equipped;
- an old generated recipe is quarantined during migration;
- a provider outage occurs at the wrong time.

Archipepsi should surprise the player with weird builds, not with “you rolled cannot fight.”

---

# 7. WEAPON ECHOES

## 7.1 Capacity

The player may equip **up to three Weapon Echo configurations**.

The wheel cycles those configurations plus Static Pulse.

That is the complete normal Weapon set exposed to moment-to-moment combat.

The Archive may own many more.

## 7.2 LMB is always primary

LMB activates the selected configuration’s primary Weapon action.

Examples may include:

- hitscan;
- projectile;
- burst;
- beam;
- spread shot;
- close-range device strike;
- charged emission;
- authored construct launcher;
- another validated Weapon-family action.

The input role is stable even when expression changes radically.

## 7.3 RMB belongs to the selected Weapon

RMB is the currently selected configuration’s secondary/intrinsic action.

Possible roles:

- alternate fire;
- aim/scope;
- guard;
- secondary emitter;
- detonator;
- special mode action;
- bounded manipulation behavior;
- another authored intrinsic.

A Weapon does not need an RMB action.

An absent secondary is better than invented filler whose only purpose is to occupy the button.

## 7.4 Weapon Echoes must be complete ideas

A Weapon Echo should be worthwhile if it is the only non-Static Weapon equipped.

Its normal loop must work before synergy.

Synergies may make it stronger or stranger, but basic usefulness cannot depend on touching the enemy with another Weapon first.

## 7.5 The anti-primer rule

Archipepsi rejects **primer gameplay as the default Weapon architecture**.

The rejected loop is:

1. switch to Weapon A;
2. apply stacks/status/color;
3. switch to Weapon B;
4. cash out;
5. repeat forever because this maintenance rotation is simply optimal.

That model can work in a game designed around it.

It is wrong for Archipepsi because it:

- makes Weapon A incomplete;
- turns the wheel into work;
- pressures Epsilon to generate matched pairs instead of independent toys;
- punishes players who identify with one favorite Weapon;
- increases generated-build failure cases;
- pushes Statuses back toward a damage spreadsheet.

Good synergy may still reward switching.

Examples:

- another system happens to apply a Status this Weapon benefits from;
- overcrit from one Weapon advances an Ability;
- Lightened enables a Physics interaction;
- Gear rewards changing configuration;
- a Weapon creates a physical state another mechanic can exploit.

The distinction:

> **Synergy may reward switching. The core design must not require priming.**

---

# 8. WEAPON FEED / AMMUNITION GRAMMAR

Weapon Echoes use a small authored feed vocabulary.

## 8.1 `MAGAZINE`

A Weapon has:

- capacity;
- per-shot consumption;
- reload duration;
- effectively infinite local reserve.

`R` reloads.

Magazine state exists for cadence, commitment, and timing.

Reserve does not exist to make the player hunt generated rooms for permission to use their favorite Weapon.

## 8.2 `HEAT`

Firing adds Heat.

The Weapon:

- cools according to an authored profile;
- may lock when overheated;
- may allow `R` to actively vent;
- declares whether inactive configurations cool.

Switching does not magically clear Heat.

## 8.3 `CHARGE`

Holding the authored firing input builds bounded charge.

The action defines:

- minimum charge;
- maximum charge;
- release behavior;
- cancellation behavior;
- feed-specific `R` behavior when relevant.

Switching does not grant a free fully charged shot.

## 8.4 `NONE`

The Weapon has no ammo/feed state.

`R` is mechanically a no-op/presentation acknowledgement for that configuration.

The HUD does not invent fake ammunition.

## 8.5 No persistent conventional ammunition economy in v1

There is no persistent bullet inventory.

Magazine reserve is infinite.

This is a major choice.

Archipepsi’s fun should come from **using strange build toys**.

A persistent ammo economy would interact badly with procedural generation:

- good Weapons could become unavailable because generated content did not spawn their ammo;
- Epsilon would inherit supply-distribution obligations;
- room packages would need ammunition contracts;
- LARGE rooms would require supply accounting;
- the player would hoard fun Weapons “for later”;
- Weapon families would need shared/separate ammo taxonomies;
- AP timing could indirectly distort local combat availability.

Feed states already provide the useful part of ammo design: rhythm.

They let a shotgun reload, a beam manage Heat, and a cannon charge without turning Archipepsi into a supply-management game.

---

# 9. WEAPON CYCLING RULES

## 9.1 Cycling preserves state

Switching away from a Weapon does not automatically:

- reload;
- refill;
- finish cooldown;
- vent;
- cool beyond its declared inactive policy;
- finish a held charge;
- regenerate a host resource;
- retrigger “on equip.”

Each configuration retains authored state.

## 9.2 Only the selected Weapon is activation-active

Inactive configurations do not run ordinary:

- combat passives;
- kill reactions;
- Status emitters;
- resource generators;
- target listeners;
- spawned Actors;
- global modifiers.

Only explicit inactive feed behavior may continue, such as cooling.

Otherwise “equip three Weapons” secretly becomes “equip three passive Gear trees plus one gun,” which destroys bounded loadout complexity.

## 9.3 Why three Weapon Echoes

Three configurations give enough room for identity:

- reliable favorite;
- situational tool;
- experimental weird thing.

More than three would make the wheel increasingly inventory-like.

Fewer than three would make the long-term Echo catalog harder to express.

Including Static Pulse, the maximum normal cycle has four states—still learnable.

---

# 10. BASELINE MELEE

## 10.1 Permanent action

Baseline melee is always available on MMB by default.

It is not:

- an Echo;
- a Weapon configuration;
- a progression gate;
- a resource spender;
- removable by loadout;
- dependent on receiving a melee item.

## 10.2 Role

Baseline melee provides:

- close-range fallback;
- finishing tool;
- a stable authored verb for Action recharge;
- a natural response to melee-breakable props where allowed;
- a guaranteed combat action distinct from Static Pulse.

It should feel intentional rather than like a debug punch.

Damage, reach, recovery, sweep shape, and impulse are tuning values.

## 10.3 Why melee is not a Weapon slot

If melee occupied one of the three Weapon configurations, players who enjoy close-range combat would pay an inventory tax just to possess a basic body action.

It would also remove a useful stable verb from the recharge/trigger grammar.

“Three baseline melee hits refill Q” is legible because baseline melee always means the same thing.

## 10.4 Why melee is not an Ability

Abilities are build choices.

Baseline melee remains when all five Ability slots are empty.

A special melee Ability or melee-oriented Weapon may still exist. It does not replace the permanent strike.

---

# 11. ABILITY ECHOES

## 11.1 Five direct slots

The player equips five Ability Echoes:

- Q;
- E;
- 1;
- 2;
- 3.

Each is directly activated.

There is no required Ability wheel.

## 11.2 What may be an Ability

Ability families may include validated forms of:

- offense;
- area control;
- defense;
- sustain;
- deployables;
- information;
- Status/control application;
- utility;
- physics manipulation;
- constructs;
- temporary typed rule changes;
- authored spatial actions that are not the player’s primary Mobility identity.

Family determines legal templates and budgets.

Epsilon chooses among legal expressions. It does not author a mini scripting language.

## 11.3 Activation forms

The engine supports a finite activation vocabulary such as:

- `PRESS`;
- `HOLD`;
- `CHARGE_RELEASE`;
- `CHANNEL`;
- authored scheduled burst patterns where a concrete mechanic requires them.

Every Ability defines a clear commit point.

Before commit, an impossible activation spends nothing.

Examples:

- Grapple with no legal target: no spend.
- Blink with no safe destination: no spend.
- Projectile successfully spawned then missed: committed, so cost remains spent.
- Channel: pays authored discrete samples and ends when the next complete sample cannot be paid.

Failure should be predictable.

## 11.4 Why five

One or two “spell buttons” would cramp Archipepsi’s entire build fantasy.

Five allows combinations of:

- offense;
- defense;
- control;
- utility;
- physics;
- support;
- strange build engines.

At the same time, five is a hard visible ceiling.

The Archive may contain hundreds of interpretations, but only five Ability hosts create active runtime state.

That bounded graph makes deep interactions tractable.

---

# 12. MOBILITY ECHO

## 12.1 One dedicated slot

The player equips one Mobility Echo on Shift.

The guiding rule:

> **Traversal-first active movement belongs here.**

Examples may include:

- dash;
- grapple;
- blink;
- burst jump;
- air-step;
- tether traversal;
- another authored movement expression.

## 12.2 Why Mobility deserves its own slot

Movement is different from ordinary utility.

The player should build a reflex:

> “Shift is how this build moves.”

Level design and Epsilon may then reason about the player’s traversal identity without asking which of five arbitrary Ability inputs happens to contain movement today.

A dedicated slot also prevents the fun movement skill from losing its place because another damage button has better DPS.

## 12.3 Mobility is not sprint

Shift should grant a meaningful build-specific verb.

It should not merely restore the movement speed the rooms were secretly designed around.

## 12.4 Incidental movement remains legal elsewhere

Other systems may move the player modestly:

- Weapon recoil;
- bounce surfaces;
- LaunchPads;
- moving platforms;
- world forces;
- an Ability with a secondary reposition component.

The rule is not “only Mobility may move the player.”

The rule is:

> **A generic Weapon/Physics/Ability interaction should not accidentally become a better universal traversal system than the dedicated Mobility family.**

---

# 13. READINESS × COST

This is one of the central player-system decisions.

## 13.1 Two questions, not one

Every activation has two conceptual questions:

1. **Readiness:** Is this action available now?
2. **Cost:** What, if anything, must be committed to use it?

“I have a charge but cannot afford the pool cost” is a different state from “I do not have a charge.”

The runtime may share implementation machinery, but the semantic distinction remains.

## 13.2 Three primary recharge identities

Every Ability or Mobility Echo has one primary player-facing recharge identity:

- `RESOURCE`;
- `COOLDOWN`;
- `ACTION`.

### RESOURCE

The Ability is principally constrained by a runtime pool.

Examples:

- 25 Energy per use;
- channel drain;
- pool generated by authored behavior;
- pool filled by a legal Link.

The pool is local gameplay state.

It is not an AP item, Coin balance, or permanent consumable.

### COOLDOWN

The Ability spends one of one-to-three charges.

Missing charges return deterministically through simulation time.

Multiple charges recharge serially by default.

Parallel hidden cooldowns are rejected because they make “when do I get one use back?” ambiguous and create strange burst refill behavior.

### ACTION

The Ability becomes ready by doing a defined gameplay verb or accumulating a defined metric.

Examples:

- land three baseline-melee hits;
- defeat two airborne enemies;
- move 20 meters;
- block a defined amount of damage;
- produce an overcrit;
- perform another explicit factual action.

Action recharge consumes facts/metrics, not UI events or arbitrary live queries.

The player should be able to read the sentence and intentionally pursue it.

## 13.3 Controlled hybrids are allowed

Legal authored hybrids may include:

- cooldown accelerated by kills;
- resource discounted after an action;
- action progress with a timeout/decay;
- resource generated by overcrit;
- cooldown advanced by movement.

These do not create a fourth “everything at once” model.

Each Echo keeps one primary identity for presentation.

The validator accepts only typed, bounded modifier patterns.

## 13.4 Arbitrary Boolean recharge logic is rejected

Epsilon cannot author:

> “Q is ready if you have 63% blue meter AND killed two Burning enemies OR have not jumped for seven seconds unless the target is airborne.”

That is executable logic disguised as data.

Legal recharge is:

- finite models;
- finite factual predicates;
- finite metrics;
- bounded contributions;
- authored hybrid templates;
- explicit caps.

## 13.5 No hidden second tax

A Cooldown Ability should not casually also require a major Resource pool because the generator thought that sounded dramatic.

A dual requirement is allowed only when a deliberate authored template makes it legible and worthwhile.

At a glance, the player should understand the primary reason an action is unavailable.

## 13.6 Fresh Zones begin with possibility

On a Zone’s first activation, equipped Ability/Mobility hosts begin in their authored ready/full state.

A new Zone should not open with five maintenance timers.

That does **not** mean newly swapped hosts in an already-active Zone receive free readiness.

---

# 14. RUNTIME RESOURCES ARE NOT ONE UNIVERSAL MANA BAR

Archipepsi does not force every Ability to draw from one global mana pool.

A Resource-model Echo may own or reference a runtime pool.

Two Echoes share one only through an explicit validated Link.

## 14.1 Why not universal mana

A single pool would homogenize radically different interpretations.

It also creates bad default coupling:

- defense starves movement;
- utility becomes a DPS loss by definition;
- one regeneration Mod buffs the entire kit;
- one drain mechanic disables everything;
- every generated Ability must be balanced against every other spender.

Explicit pools and Links let a shared economy exist **when that relationship is the point**.

## 14.2 Epsilon Static is not spend-per-cast mana

Core Ability use must not depend on AP-delivered Epsilon Static.

Otherwise:

- remote placement drought can disable a local build;
- player count changes combat pacing;
- reconnect state becomes a combat-resource issue;
- hundreds of Static receipts feel like repetitive mana refills;
- solo and multiworld balance diverge badly.

Epsilon Static may later affect instability, reserve, Integrity, or another persistent system. It does not control the player’s minute-to-minute permission to use their build.

---

# 15. UNIVERSAL WORLD INTERACTION — `F`

## 15.1 `F` is the context action

The world exposes authored Interactions.

The resolver chooses a legal focused candidate and shows the exact verb.

Examples:

- `[F] Press`
- `[F] Pick up`
- `[F] Place`
- `[F] Pull lever`
- `[F] Open`
- `[F] Hack`
- `[F] Use terminal`
- `[F] Activate Check`

The verb changes.

The input role does not.

## 15.2 Carry state

Ordinary room-local carryables use the same interaction grammar.

Default flow:

1. focus a carryable;
2. F picks it up;
3. player enters that object’s authored carry state;
4. F drops or places it;
5. a valid receiver/socket may change the prompt to a specific placement verb.

Carryables declare:

- pickup permission;
- carry pose/offset;
- collision behavior;
- allowed room/volume;
- reset behavior;
- required-object recovery;
- placement eligibility;
- persistence semantics.

## 15.3 Interaction priority while carrying

While carrying, the carried object’s legal Place/Drop behavior receives priority when the focused context supports it.

The resolver must never create ambiguous behavior such as:

> “F might activate the terminal behind the cube or might drop the cube.”

The prompt is authority.

## 15.4 Hacking

Hacking begins through F like any other mechanism.

A hack may open a short authored 5–15 second interaction such as:

- rerouting;
- frequency matching;
- circuit completion;
- signal ordering.

Hacking is simply another input into the room’s signal architecture.

It is not bespoke code attached individually to every hacked door.

## 15.5 Why one world-action key

The dungeon vocabulary is broad:

- cubes;
- buttons;
- levers;
- terminals;
- doors;
- emitters;
- receivers;
- reset controls;
- machines.

Giving each a bespoke key would make interaction into keybind trivia.

A universal action lets presentation say *what* the player is doing while controls answer *how the player engages with the world*.

## 15.6 AP Checks remain transactionally distinct

An AP Check may use F to activate.

Internally it remains different from a room-local lever.

A normal lever may change a local signal immediately.

A Check may involve:

- pending state;
- network send;
- confirmation;
- reconciliation;
- crash recovery.

Shared input does not mean shared authority.

Generic world interaction and AP Check transaction logic remain separate contracts.

---

# 16. DUNGEON MACHINERY AND THE PLAYER

The player design assumes a reusable machinery vocabulary:

> **INPUT → SIGNAL → OUTPUT**

Inputs may include:

- pressure plate;
- pulse button;
- persistent lever/toggle;
- shootable target;
- orb receiver;
- hack terminal;
- carryable placement;
- authored sensor.

Signal is represented by physically readable conduit/power routing authored into the room.

Outputs may include:

- door;
- gate;
- bridge;
- moving platform;
- lift;
- LaunchPad;
- hazard enable/disable;
- rotating machinery;
- actuator;
- other authored mechanism.

The player does not receive a new key for each mechanism.

This is why F, Weapon shots, carryables, and Physics Echoes need crisp boundaries.

---

# 17. ORDINARY CARRYING VS PHYSICS ECHOES

These systems are related but not identical.

## 17.1 Ordinary carrying is baseline

If a room expects the player to carry its Weighted Cube, that object should be pickable with F according to its authored carry profile.

The puzzle does not secretly require a Physics Echo unless the capability contract explicitly says it does.

## 17.2 Physics Echoes extend manipulation

Physics Echoes extend the player’s ability to rearrange authored matter.

Core principle:

> **PHYSICS ECHOES REARRANGE ENERGY AND MATTER MORE EFFECTIVELY THAN THEY CREATE EITHER.**

Possible legal primitives include:

- push;
- pull;
- grab at range;
- tether;
- pin;
- rotate/align;
- bounded impulse;
- temporary mass/drag/gravity-response change;
- spawn one of a small authored construct forms;
- recall/dissolve owned constructs.

## 17.3 Strong limited hands

The target feel is not omnipotent telekinesis.

The player should ask:

> “Can I move this enough to make something clever happen?”

not:

> “Why would I engage with the level when I can fling everything and myself anywhere?”

Physics tools have explicit contracts for:

- manipulation class;
- allowed target tags;
- acquisition range;
- hold range;
- force/work rate;
- release speed;
- tether length;
- active relation count;
- construct count;
- lifetime;
- incidental player impulse;
- upward-energy contribution.

The exact values are tuning.

The existence of the limits is architecture.

## 17.4 Physics is intentionally bad at replacing Mobility

Physics should allow delightful incidental tricks.

Optional sequence breaking is often good.

But a general Physics Echo must not become:

- infinite rocket jump;
- infinite staircase;
- permanent bridge printer;
- crate railgun;
- arbitrary enemy carrying;
- universal flight;
- a better Grapple than the Grapple Mobility family.

This preserves room/progression design without removing experimentation.

## 17.5 Physical impact damage

Physics impacts may deal capped normal damage through the same damage resolver as every other attack.

Requirements:

- meaningful speed/mass threshold;
- jitter/rest contacts cannot repeatedly damage;
- player-owned objects have a hard damage ceiling;
- provenance/credit is explicit;
- Physics impact does not inherit crit automatically.

The player may bowl a crate into an enemy.

The optimal boss build should not become “accelerate a coffee mug to relativistic speed.”

## 17.6 Required movable objects recover

Any movable object required for progress needs:

- stable room-local spawn identity;
- reset state;
- allowed-room volume;
- out-of-bounds recovery;
- unreachable-object recovery;
- player-accessible reset where appropriate.

Persistent save truth records semantic puzzle state, not arbitrary rigid-body transforms.

---

# 18. DAMAGE PHILOSOPHY

## 18.1 One damage road

Every actual loss of Health/Barrier from combat or hazards goes through the same typed damage system.

Weapons, Abilities, explosions, fire Actors, Physics impacts, and hazards do not each invent secret Health mutation.

This gives reactions and diagnostics one factual language.

## 18.2 Damage is not an elemental spreadsheet

Damage may carry useful source/cause tags such as:

- ranged;
- melee;
- projectile;
- beam;
- explosive;
- physics;
- fire;
- construct;
- environmental.

Tags may support authored interactions.

They do not create an automatic eight-color resistance chart.

## 18.3 No random base damage variance

The same ordinary non-crit attack against the same target state should produce the same result.

Random damage ranges add noise without adding a meaningful decision.

Randomness belongs where its role is understandable, such as crit remainder and Status application.

## 18.4 Health and Barrier

The v1 mental anchor is:

- **100 displayed base Health**;
- **0 baseline Barrier**.

Barrier is additional protection granted by mechanics.

Exact Health may change in tuning, but values should remain human-scale and readable rather than inflating into MMO-sized numbers.

## 18.5 Defense

Defense is a bounded gameplay stat/channel, not an item-level score.

Requirements:

- diminishing returns or explicit cap;
- no accidental infinite mitigation;
- distinct presentation from Barrier, invulnerability, and misses;
- bounded authored penetration;
- active defensive verbs remain meaningful.

## 18.6 Why no armor-score treadmill

Gear should change *how the build works*.

If new Gear is primarily “+27 Armor, requires higher level,” then:

- foreign-item meaning disappears under stats;
- old Gear becomes numerically obsolete;
- Epsilon’s interpretation becomes cosmetic;
- procedural difficulty chases item level;
- loot comparison becomes arithmetic rather than experimentation.

Archipepsi wants buildcraft, not vertical gear-score replacement.

---

# 19. CRIT AND OVERCRIT

Crit chance may exceed 100%.

This is intentional.

## 19.1 Rule

For crit chance `C`:

- every complete 100% guarantees one crit tier;
- remainder chance may add one additional tier.

Conceptually:

```text
guaranteed_tier = floor(C / 100%)
remainder       = C mod 100%
crit_tier       = guaranteed_tier + remainder_roll
```

With a normal 2× Tier-I multiplier, tiers scale linearly:

- normal = 1×;
- Tier I = 2×;
- Tier II = 3×;
- Tier III = 4×;
- Tier IV = 5×.

Exact technical cap is tuning.

## 19.2 Why overcrit exists

Stopping crit investment at 100% creates a buildcraft dead end.

Overcrit lets the player continue specializing while also becoming more reliable.

At 150% crit:

- the attack can never be ordinary;
- Tier I is guaranteed;
- the excitement is whether it reaches Tier II.

## 19.3 Why tiers are linear

Exponential 2× / 4× / 8× / 16× scaling makes feedback builds nearly impossible to balance.

Linear overcrit remains powerful while leaving room for:

- recharge triggers;
- Gear interactions;
- Status application;
- encounter scaling;
- reaction chains.

It makes “overcrit → recharge → Ability” a build engine rather than an automatic numerical apocalypse.

## 19.4 Crit eligibility is explicit

Not every damage source inherits player crit.

Direct Weapon attacks commonly can.

Physics impacts, world hazards, passive damaging Actors, and secondary explosions default not to unless the authored template explicitly permits it.

Provenance alone never grants crit permission.

---

# 20. STATUS DESIGN

This section resolves an older conflicting draft.

**Final player direction: Status application is chance-based, with visible pity/susceptibility after failure and adaptation after success.**

A deterministic universal Stability-fill system is superseded.

## 20.1 A Status changes rules

A Status may alter:

- movement;
- gravity;
- friction;
- mass/physics response;
- targeting;
- faction/allegiance;
- AI behavior;
- action permissions;
- perception;
- visibility;
- manipulation eligibility;
- collision/phase behavior;
- authored interaction rules.

Hard rule:

> **A STATUS NEVER DIRECTLY DEALS PERIODIC DAMAGE.**

## 20.2 Burning example

`BURNING` may mean:

- visibly on fire;
- AI panic/alarm;
- flammability changes;
- authored fuel responds;
- mechanisms detect the condition;
- light/perception changes.

The Status itself does not tick Health.

A real **world fire Actor** may independently deal ordinary damage to anything standing in it.

That damage has its own source, lifetime, geometry, and provenance.

The no-DoT law cannot be bypassed by attaching a hidden damaging helper to the Status.

## 20.3 Chance with visible pity

A Status attempt uses a bounded authored application profile.

Conceptually:

```text
effective_chance =
    base_chance
  + source_potency
  + visible_susceptibility
  - target_resistance
  - family_adaptation
```

Exact numbers are tuning.

On failure:

- failure is visible;
- bounded pity/susceptibility increases for the relevant target/status family.

On success:

- the Status meaningfully applies;
- relevant pity resets;
- temporary adaptation increases.

## 20.4 Why retain chance

Chance creates useful tension for reality-manipulation verbs.

It makes “can I get this impossible interpretation to stick?” meaningfully different from damage.

Visible pity prevents invisible RNG cruelty.

## 20.5 Why deterministic universal buildup was not selected

A deterministic Stability meter is technically elegant, but as the universal Status model it creates a second-health-bar pattern:

- every control attempt becomes “fill another meter”;
- proc surprise disappears;
- several Statuses risk several buildup bars;
- tough targets feel like they simply own more hidden HP;
- the system drifts toward stagger rather than uncertain reality manipulation.

Deterministic buildup may still exist for specific authored mechanics such as stagger, hacking, boss-break, or machine progress.

It is not the general Status resolver.

## 20.6 Strong enemies and bosses

Stronger targets may have:

- lower application chance;
- shorter duration;
- quicker/stronger adaptation;
- explicit authored restrictions where the full effect is mechanically impossible.

The preferred solution is not a giant wall of `IMMUNE`.

If a reduced expression can preserve the fantasy without breaking the encounter, use it.

Example:

- Turncoat ordinary enemy → temporary ally.
- Boss that cannot survive faction replacement → successful authored substitute such as brief targeting confusion.

True immunity remains valid when the effect is nonsensical or would invalidate encounter structure.

## 20.7 Statuses are not mandatory primers

A Status may create Weapon synergy.

It should not force every combat build into “apply Status, swap, consume Status for damage.”

Statuses are gameplay verbs first.

---

# 21. GEAR

The player has four passive Gear slots:

- **Head**
- **Torso**
- **Arms**
- **Legs**

## 21.1 Mechanical territories

These are strong design territories.

### Head

Good homes for:

- information;
- targeting;
- awareness;
- perception;
- trigger/recharge logic;
- readouts.

### Torso

Good homes for:

- survivability;
- Barrier;
- resource engines;
- major defense;
- sustain.

### Arms

Good homes for:

- Weapon/tool handling;
- melee;
- Grapple interaction;
- physical manipulation;
- interaction modifiers.

### Legs

Good homes for:

- movement;
- jump;
- landing;
- dodge;
- traversal;
- locomotion modifiers.

## 21.2 Useful vs high-tier Gear

Useful Gear:

- has a meaningful intrinsic;
- supports modest Mod capacity;
- is useful without becoming the entire build.

High-tier Gear:

- owns a build-defining signature rule;
- supports larger Mod capacity;
- still uses the same finite mechanic vocabulary.

High tier means deeper rule identity, not “same item with a larger number.”

## 21.3 One high-tier Gear piece in v1

Only one equipped Gear piece may be high-tier across Head/Torso/Arms/Legs.

Weapon, Ability, and Mobility Echoes do not share this restriction.

### Why

Active Echoes are naturally bounded by input slots.

Gear is passive. Four high-tier passive Gear pieces can create a huge reaction/resource machine before the player presses anything.

One high-tier Gear slot preserves one strong passive identity while keeping the active side of the build permissive.

## 21.4 Why not one universal Exotic rule across the whole loadout

A player should be allowed to combine:

- high-tier Weapon;
- high-tier Ability;
- high-tier Mobility;
- one signature Gear piece.

“One special item total” would suppress the central Archipepsi fantasy by making the player choose only one interesting toy.

## 21.5 Why not a global high-tier point currency

A global equip-point proposal is flexible, but it adds an abstract meta-resource the player must calculate.

The visible slot grammar already supplies natural ceilings.

v1 therefore uses:

- input slots for active complexity;
- one-high-tier-Gear for passive complexity;
- per-host Mod capacity;
- runtime/feedback validation.

---

# 22. MODS

## 22.1 What a Mod is

A Mod is a bounded mechanic attached to a compatible host.

It never owns a direct input.

Families may include:

- `AUGMENT`;
- `REPLACEMENT`;
- `TRIGGER`;
- `PASSIVE`;
- `CONVERSION`.

Examples:

- add Grapple behavior to a compatible Weapon secondary;
- replace an action with an authored alternate;
- brief invulnerability after a qualifying kill;
- overcrit advances an Ability;
- alter a legal feed/recharge profile;
- change a bounded Physics interaction.

## 22.2 Mods can be substantial

A Mod is not required to be `+3% damage`.

Archipepsi receives many foreign filler/trap items. Those interpretations need to remain meaningful.

A Mod may transform a host as long as the result is:

- legal;
- budgeted;
- explainable;
- validated;
- provenance-preserving.

## 22.3 Mod capacity

v1 begins with:

- Useful Echo/Gear: **2 Mod slots**;
- high-tier Echo/Gear: **4 Mod slots**.

These numbers are tuning-level capacity defaults.

Changing them after playtest does not reopen the player-control architecture.

## 22.4 Free experimentation

Installing/removing Mods at a valid loadout boundary is free.

There is no respec tax.

The player is supposed to experiment with strange combinations.

Charging every experiment encourages copying established builds and avoiding discovery.

Forge transformations may cost resources because Forge changes persistent item expression. Rearranging already-owned Mods does not.

## 22.5 Duplicate handling

Exact duplicate Mod interpretations consolidate for UI/rank/provenance rather than producing endless identical Archive rows.

Every provenance unit remains authoritative for Forge/accounting.

Mechanical stacking follows explicit authored policy.

---

# 23. ACTIVE LOADOUT VS OWNED ARCHIVE

The player may own a huge catalog.

The runtime must not pretend all of it is active.

## 23.1 Active projection

Only equipped hosts compile into gameplay:

- Static Pulse;
- up to 3 Weapon configurations;
- 5 Ability slots;
- 1 Mobility slot;
- 4 Gear slots;
- installed Mods on those hosts.

Unequipped definitions do not create:

- event listeners;
- reactions;
- resource generators;
- Status claims;
- scheduler entries;
- Actors;
- live target queries.

## 23.2 Why this matters

A full campaign can generate enormous provenance.

If “owned” meant “passively active,” the game would eventually become an unreadable event storm.

The Archive may be enormous.

The **active build** remains deliberately bounded.

---

# 24. LOADOUT EDIT BOUNDARIES

## 24.1 v1: edit at the Hub

Full loadout edits happen at the Hub between Zone excursions.

This includes:

- Weapon configuration selection;
- Ability Echoes;
- Mobility;
- Gear;
- Mods.

Weapon cycling remains available in combat because those configurations are already part of the committed build.

## 24.2 Why no unrestricted mid-combat swapping

If the player can equip a fresh host at any instant, the Archive becomes an exploit engine:

- fresh cooldowns;
- fresh resources;
- full magazines;
- emergency defensive Gear;
- repeated “on equip” triggers;
- infinite rotation through stored Abilities.

Fixing each exploit individually produces ugly exceptions.

The clean rule is that the active build is committed for the excursion.

## 24.3 Revisited Zones and cold introduction

A previously used exact host in a revisited Zone may restore saved Zone-local runtime state where the persistence system supports it.

A never-before-used host introduced to an already-active Zone must not appear fully precharged just because it sat in the Archive.

Cold-introduction examples:

- Resource: empty/authored cold state;
- Cooldown: no charges, legal recharge begins;
- Action: zero progress;
- Magazine: empty but reloadable;
- Heat: zero;
- Charge: unbuilt.

Exact cold values may be tuned.

The anti-exploit law is stable:

> **Loadout rotation cannot manufacture readiness.**

## 24.4 Future safe in-Zone stations

A future authored safe station may permit limited in-Zone loadout editing.

That is outside v1.

If added, it must use the same host-state registry/cold rules. It cannot become “visit station to refill all cooldowns.”

---

# 25. CAPABILITY PROGRESSION

The original POC required every mandatory route to remain completable forever with only base movement and the default attack.

That restriction was correct before Archipepsi had reliable capability planning and traversal validation.

It is no longer the final target.

## 25.1 Hard semantic capability gates are allowed

A generated Zone may require a family such as:

- `GRAPPLE`;
- another validated movement family;
- a validated manipulation family;
- another explicit semantic capability.

Only after the planner proves it is available before use.

## 25.2 Guarantee sources

A capability requirement may be legal when proved through a supported source such as:

- owned on Zone entry;
- established earlier;
- guaranteed by AP logic earlier;
- supplied by a guaranteed local mechanism;
- future Forge construction when both access and required resources are themselves guaranteed.

The capability planner owns this proof.

Epsilon does not.

## 25.3 Owned is not the same as slotted

Campaign truth may say the player owns `GRAPPLE`.

Moment-to-moment gameplay still needs a usable expression.

Therefore a Zone with a mandatory capability must satisfy one of:

1. a compatible expression is required/confirmed in the entry loadout; or
2. a guaranteed safe loadout opportunity exists before the first requirement.

v1 uses Hub-only loadout editing, so the normal solution is **entry-loadout validation**.

Before entry, the UI should clearly show mandatory semantic requirements and prevent accidental entry with no usable equipped expression unless the Zone itself guarantees access before use.

This preserves:

- campaign ownership truth;
- active player-loadout truth.

## 25.4 Raw DPS is never progression truth

A Zone may become easier or harder based on build strength.

AP reachability may not be encoded as:

- deal 500 DPS;
- own a high-tier gun;
- reach 200% crit;
- kill an arbitrary HP wall before a timer.

Damage is too fluid.

Delivery, movement, manipulation, keys, mechanisms, and explicit semantic capability families can be progression verbs.

## 25.5 Optional sequence breaking is good

If Physics, recoil, launch timing, or room geometry skips an **optional** obstacle, that is often delightful.

Do not cover the game in invisible anti-fun volumes merely to keep optional paths canonical.

Hard AP/progression gates need semantic protection.

Ordinary level geometry can tolerate cleverness.

---

# 26. FOREIGN ITEMS AND PLAYER BUILD PROGRESSION

From the player’s perspective:

- foreign filler → Mod;
- foreign trap → Mod, often with a visible bounded tradeoff flavor;
- foreign useful → Useful Echo/Gear candidate;
- foreign progression → high-tier Echo/Gear candidate.

Another game’s `progression` flag is not Archipepsi capability truth.

## 26.1 Why filler becomes real Mods

Large multiworlds can produce hundreds of foreign receipts.

Making every filler item a full independent active Echo would drown the player.

Turning all filler into generic crafting dust would erase the joke and provenance.

Mods are the middle ground:

- the foreign item remains a recognizable thing;
- its interpretation can matter mechanically;
- it does not consume another direct input;
- duplicates can consolidate;
- many Mods can feed Forge synthesis.

## 26.2 Why Epsilon cannot invent arbitrary mechanics

Epsilon receives a bounded legal candidate space.

Developers author the alphabet.

Godot enforces the grammar.

Epsilon chooses and describes a sentence.

A bizarre item name cannot create:

- raw code;
- an unknown keybind;
- a new callback;
- a progression bypass;
- arbitrary persistent mutation;
- unbounded Physics force.

## 26.3 Forge from the player perspective

Forge exists to turn accumulated interpreted material into more intentional build pieces.

Starting economic direction:

- roughly 5 Mods → 1 Useful Echo opportunity;
- roughly 5 Useful Echoes → 1 high-tier Echo opportunity.

Ratios are tuning.

The structural rule is that the player steers broad family/destination without typing exact stats.

Forge changes persistent expression.

Loadout editing does not.

---

# 27. PLAYER HUD AND READABILITY

The HUD explains the **active build**, not the entire Archive.

## 27.1 Always-visible or immediately readable information

The player needs clear access to:

- Health;
- Barrier when present;
- selected Weapon configuration;
- current Weapon feed state;
- Weapon-cycle context;
- five Ability states;
- Mobility state;
- current interaction prompt;
- relevant active Statuses;
- important temporary build state.

## 27.2 Recharge models should look different

Do not render five identical radial timers regardless of mechanic.

Resource should communicate **quantity/cost**.

Cooldown should communicate **charges/time**.

Action should communicate **the refill verb and progress**.

Examples:

```text
Q      62 / 100
E      1 / 2    1.4s
1      MELEE HITS 2 / 3
SHIFT  READY
```

Exact graphic design belongs to UI/Art.

Semantic distinction is mandatory.

## 27.3 Causality feedback

When a build relationship happens, the player should understand why.

Examples:

- overcrit visibly advances Q;
- kill trigger highlights its responsible host/Mod;
- failed Status increases susceptibility;
- successful control shows adaptation;
- Heat clearly reaches lockout;
- tether snaps with a physical/readable reason.

The player should not need logs to understand every basic interaction.

## 27.4 Color is not the only language

Archipepsi already reserves color for strong meanings including provenance, hazard orange, Check cyan/white, and Epsilon identity.

Combat/readiness/telegraph communication should also use:

- shape;
- iconography;
- motion;
- rhythm;
- intensity;
- spatial position;
- audio.

This improves readability and accessibility.

---

# 28. FIRST-PERSON PRESENTATION

The player redesign is not complete if the mechanics change while the device still looks like an unrelated generic debug gun.

## 28.1 Modular authored viewmodel

The Epsilon device should use authored modular pieces rather than runtime-generated arbitrary meshes.

Useful module roles may include:

- core/body;
- grip/mount;
- emitter/tool head;
- barrel/aperture;
- secondary module;
- moving mechanism;
- provenance accent;
- Epsilon intrusion element.

Weapon-family silhouette must remain readable after composition.

## 28.2 Configuration change should be visible

Cycling Weapon configurations should visibly communicate reinterpretation.

Possible authored presentation:

- mechanical rearrangement;
- emitter swap;
- aperture movement;
- moving panel;
- short geometry fold/unfold;
- audio signature;
- provenance accent change.

The transition should be quick enough for combat.

It should not be a one-second cinematic every time the wheel moves.

## 28.3 Static Pulse must remain visually recognizable

Even as the device changes, Static Pulse should read as the neutral/home configuration.

The player should be able to identify “I am back on baseline” without checking text.

## 28.4 Physics/interaction presentation

Picking up, tethering, pinning, or remotely manipulating an object should show ownership/state clearly.

The device may visually react, but physical world readability has priority.

The player needs to know:

- what is targeted;
- what is held;
- what is tethered;
- what will happen on release;
- why a relation failed/broke.

## 28.5 No presentation authority over simulation

Viewmodel animation, VFX, audio, camera shake, and UI never decide whether an action occurred.

Simulation commits first.

Presentation reports what happened.

---

# 29. DEATH, FALLING, CHECKPOINTS, AND RECOVERY

## 29.1 Death does not touch AP truth

Death may reset local runtime state according to Zone/checkpoint rules.

It does not:

- uncheck a confirmed AP location;
- delete received items;
- refund/spend Coins;
- reroll an Echo interpretation;
- alter capability truth.

## 29.2 Out-of-bounds recovery

Falling outside authored playable space returns the player to a valid recovery/checkpoint state.

LARGE rooms should prefer:

- recovery floors;
- lower basins;
- alternate routes;
- intentional falls;

instead of making every drop a kill void.

When a true out-of-bounds state occurs, recovery must be deterministic and safe.

## 29.3 Puzzle recovery

Required carryables, orbs, movable props, and temporary room machinery rebuild from valid semantic reset state.

The player should never have to abandon a save because a cube rolled behind generated geometry.

## 29.4 Death is not a refill exploit

Checkpoint restoration must be explicit.

Dying cannot become the optimal way to:

- refill resources;
- refresh cooldowns;
- refill magazines;
- clear an inconvenient feed state.

Exact Health restoration remains tuning.

Economy duplication is not.

---

# 30. REJECTED / DEFERRED PLAYER MODELS

This section is intentionally explicit so future work does not rediscover old alternatives and assume they were forgotten.

## 30.1 Three unrelated physical guns

**Not selected.**

Good for games about collecting literal firearms.

Poor fit here because the central fantasy is one Epsilon device reinterpreting foreign ideas.

It also multiplies inventory, ammo, visual, and persistence burden.

## 30.2 Warframe-style primer rotation as the default

**Rejected as a baseline law.**

Synergy is welcome.

Mandatory “apply with A, swap to B, cash out” maintenance is not.

Each Weapon should be fun and complete.

## 30.3 Warframe-style elemental/status damage soup

**Rejected.**

Archipepsi does not need:

- eight elemental damage channels;
- armor-color matchup charts;
- dozens of damaging proc types;
- mandatory composition knowledge.

Statuses are gameplay verbs.

Damage stays readable.

## 30.4 Status DoT

**Rejected.**

Status definitions cannot tick Health.

Spatial Actors such as actual fire may independently deal ordinary damage.

## 30.5 Deterministic universal Status buildup

**Rejected for the final universal Status model.**

A deterministic Stability/pressure architecture was explored and documented.

The final player direction is chance-based application with visible pity and adaptation.

Deterministic buildup remains valid for specific authored systems such as stagger, hacking, or machine progress.

## 30.6 One universal Ability cooldown model

**Rejected.**

It makes every impossible Echo feel like a different icon attached to the same timer.

Resource, Cooldown, and Action recharge should coexist.

## 30.7 One universal mana bar

**Rejected as mandatory architecture.**

Explicit shared Resource Links are allowed.

Universal mana creates excessive coupling.

## 30.8 Arbitrary hybrid recharge expressions

**Rejected.**

Controlled authored hybrids are good.

A Boolean scripting language is not.

## 30.9 Persistent bullet scarcity

**Rejected for v1.**

Weapon feeds create cadence.

Infinite local reserve prevents generated supply placement from disabling the player’s favorite Weapon.

## 30.10 Sprint/stamina baseline

**Rejected for v1.**

Baseline movement should feel good at baseline speed.

Shift belongs to Mobility.

## 30.11 Crouch/slide baseline

**Deferred.**

Add only if stealth, momentum, or low-clearance level design actually earns the complexity.

## 30.12 Dedicated Signature/Ultimate slot

**Deferred beyond v1.**

High-tier Echoes can be spectacular inside existing slots.

A sixth active category currently adds more complexity than value.

## 30.13 Unlimited mid-combat Archive swapping

**Rejected.**

It turns the Archive into an infinite bag of fresh cooldowns, resources, magazines, and defensive responses.

## 30.14 Respec tax

**Rejected.**

Experimentation with owned loadout pieces should be free at safe boundaries.

## 30.15 Armor score / item level

**Rejected.**

Power comes from rules and combinations, not a vertical replacement ladder.

## 30.16 Physics as unrestricted telekinesis

**Rejected.**

Physics Echoes are bounded manipulation tools.

## 30.17 Physics as the main movement system

**Rejected.**

Incidental tricks are good.

Primary active movement identity belongs to Mobility and authored world traversal.

## 30.18 Physics as dominant damage

**Rejected.**

Props may matter without invalidating Weapons.

## 30.19 Arbitrary runtime mesh construction

**Rejected.**

Created matter selects authored construct forms with known collision/safety semantics.

## 30.20 AP-delivered Epsilon Static as moment-to-moment ammo/mana

**Rejected.**

Remote placement must not starve local combat.

## 30.21 Bespoke interaction keys for each dungeon verb

**Rejected.**

F owns world interaction.

The prompt communicates the verb.

---

# 31. WHAT WE BORROW FROM OTHER GAMES — AND WHAT WE DO NOT

References are used to identify solved design problems, not as templates to clone.

## 31.1 Portal

Useful lessons:

- objects have obvious physical rules;
- cubes matter because rooms react to them;
- distant cause/effect is readable;
- launch plates, receivers, emitters, reset fields, and movable objects create legible puzzle sentences.

Not copied wholesale:

- no universal portal gun;
- not every room is a single-solution chamber;
- reusable architecture must support several procedural gameplay packages.

## 31.2 Half-Life

Useful lessons:

- ordinary props can be meaningful;
- Physics becomes fun when environment reacts;
- boards, barrels, carts, machinery, steam, electricity, hanging objects, and breakables create agency.

Not copied wholesale:

- Archipepsi Physics tools need stricter contracts because procedural composition and AP reachability magnify sequence-breaking risk;
- required props need explicit recovery semantics.

## 31.3 Zelda dungeon language

Useful lessons:

- switches should visibly change state;
- bridges/lifts/gates create spatial cause/effect;
- revisiting a room after changing a mechanism is satisfying;
- hookshot/grapple targets and bombable walls are semantic affordances.

Not copied wholesale:

- no permanent inventory button for every dungeon item;
- Epsilon-generated content needs a compact validated capability vocabulary.

## 31.4 Warframe

Useful lessons:

- movement and buildcraft can be expressive;
- crit above 100% can remain meaningful;
- combinations can matter more than flat upgrades.

Not copied:

- mandatory primer swapping;
- elemental/status damage soup;
- giant globally-active passive graphs;
- excessive stat-layer complexity.

## 31.5 Destiny-like ability readability

Useful lesson:

- active verbs benefit from stable input identities and readable readiness.

Not copied:

- one fixed cooldown identity for all Abilities;
- a tiny predetermined class kit.

Archipepsi needs Resource, Cooldown, and Action recharge because interpreted Echoes should feel mechanically different.

## 31.6 Traditional loot shooters / Borderlands-like weapon inventories

Useful lessons:

- Weapons should have strong independent personality;
- firing rhythm matters;
- a weird gun should be memorable immediately.

Not copied:

- dozens of literal carried guns;
- constant replacement by higher-level versions;
- persistent ammunition scarcity as the main rotation pressure.

The Epsilon device keeps Weapon personality while avoiding the inventory treadmill.

---

# 32. EXAMPLE BUILDS UNDER THE FINAL PLAYER MODEL

These are examples, not required content.

## 32.1 Rail skirmisher

**Weapon A:** rapid MAGAZINE Weapon that gains crit while airborne.  
**Weapon B:** Heat beam with strong RMB burst.  
**Q:** Action-recharge impulse Ability filled by distance traveled.  
**E:** Cooldown defensive field.  
**1:** Resource Status applicator.  
**2:** Cooldown deployable.  
**3:** Action Ability advanced by overcrit.  
**Shift:** Grapple Mobility.  
**Gear:** Legs intrinsic improves rail dismount control.

Loop:

- ride rail;
- movement feeds Q;
- airborne attacks build overcrit;
- overcrit feeds 3;
- Grapple catches a missed dismount.

No primer Weapon required.

## 32.2 Physics manipulator

**Weapon:** slow heavy projectile.  
**Q:** Pull Light objects.  
**E:** Pin.  
**1:** Lightened Status.  
**2:** defensive Cooldown.  
**3:** temporary authored wedge/block.  
**Shift:** short Blink.

Loop:

- Lightened changes manipulation response;
- Pull repositions;
- Pin creates cover or puzzle utility;
- impact can hurt but is capped;
- Blink remains true player traversal.

The room supplies most of the energy.

## 32.3 Overcrit recharge build

**Weapon:** accurate high-crit configuration.  
**Q:** heavy Cooldown attack.  
**Gear:** Head rule: overcrit advances Q.  
**Mod:** Q applies a non-damaging Status.  
**Ability:** Status success briefly increases target vulnerability.

Loop:

crit → recharge → Ability → rule change → more valuable attacks.

No hidden elemental matrix required.

## 32.4 Control build

**Weapon:** ordinary standalone generalist.  
**Q:** chance-based Lightened applicator.  
**E:** chance-based Attractor applicator.  
**1:** Mark/reveal utility.  
**Shift:** dash.

Failures increase visible susceptibility.

Success changes decisions rather than ticking damage.

## 32.5 Dungeon explorer

**Weapon:** reliable generalist.  
**Q:** scan.  
**E:** physics pull.  
**Shift:** Grapple.  
**F:** carry cube, operate lever, use terminal.

A LARGE room may contain:

- ordinary bridge route;
- Grapple shortcut;
- machinery puzzle;
- movable-object interaction;
- ranged combat across elevations.

Controls remain stable while Epsilon changes the gameplay package.

---

# 33. CURRENT EXECUTABLE VS TARGET

The player target is **not implemented yet**.

Production snapshot inspected during this design: commit `b37fe07`.

## 33.1 Current input reality at that snapshot

The executable still uses the transition-era grammar:

- LMB → `fire_pulse`;
- RMB → `fire_echo`;
- MMB **and F** → `fire_echo_b`;
- Shift → `fire_mobility`;
- C → `fire_utility`;
- E → `interact`;
- Q + wheel → `cycle_echo`;
- Tab → inventory;
- Space → jump.

That is current executable behavior.

It is not the final player design.

## 33.2 Required migration

| Current | Target |
|---|---|
| LMB dedicated `fire_pulse` | LMB active selected Weapon primary; Static Pulse becomes selectable fallback configuration |
| RMB `fire_echo` | RMB active selected Weapon secondary/intrinsic |
| MMB/F `fire_echo_b` | MMB baseline melee; F world interaction |
| Shift `fire_mobility` | Shift remains Mobility Echo |
| C `fire_utility` | No C Utility slot; direct Abilities use Q/E/1/2/3 |
| E `interact` | E becomes Ability slot E |
| Q cycles Echo | Q becomes Ability slot Q |
| Wheel cycles old Echo | Wheel cycles Static Pulse + up to 3 Weapon configurations |
| no canonical R feed role | R becomes selected Weapon feed action |
| old small Echo runtime | bounded active projection: 3 Weapons + 5 Abilities + Mobility + Gear + Mods |
| old generic input ownership | typed Weapon/Ability/Mobility/Gear/Mod roles |

## 33.3 Existing room movement work is not the player migration

Production already has useful environment foundations such as:

- rails;
- grapple opportunities;
- launch solving;
- bounce/wind/moving-platform affordances;
- reactive/destructible props;
- physical walk validation.

Those do not mean the player redesign has shipped.

The player migration needs its own implementation wave.

---

# 34. IMPLEMENTATION CONTRACT

Production should treat this as a player-system migration, not a keybind patch.

## 34.1 Semantic input roles

Create/normalize gameplay actions for:

- Weapon primary;
- Weapon secondary;
- melee;
- Ability Q/E/1/2/3;
- Mobility;
- interact;
- Weapon feed;
- next/previous Weapon;
- Archive;
- jump/movement.

Gameplay consumes roles.

Generated definitions never contain physical keycodes.

## 34.2 Device / Weapon cycle

Implement:

- Static Pulse fallback;
- three equipped configuration slots;
- selected configuration;
- wheel cycle;
- per-configuration feed state;
- selected-only activation;
- RMB intrinsic;
- R feed dispatch.

## 34.3 Baseline melee

Add permanent melee through the same combat request/damage road as other attacks.

It must remain available with no Echoes equipped.

## 34.4 World interaction service

Move world interaction to F.

Unify normal affordances under a context resolver while keeping AP Check transaction semantics separate.

Add carryable pickup/drop/place.

## 34.5 Ability slots

Implement Q/E/1/2/3 as five directly mapped equipped hosts.

## 34.6 Mobility

Keep Shift dedicated and migrate existing movement expressions into the new role.

## 34.7 Readiness / cost runtime

Implement Resource/Cooldown/Action identity plus controlled typed modifiers.

Preserve host state safely across persistence/loadout boundaries.

## 34.8 Gear / Mods

Compile only equipped hosts.

Prove unequipped Archive content produces no live work.

## 34.9 Physics player expressions

Build on the existing typed Physics/world contracts.

Generated tools never directly set arbitrary transforms/velocity.

## 34.10 Capability progression

Capability planner and Zone entry must agree on:

- required family;
- owned usable expression;
- equipped expression;
- safe access before first mandatory use.

---

# 35. ACCEPTANCE TESTS

The player redesign is not “done” merely because keybinds changed.

## 35.1 Baseline

1. Empty build can move, jump, interact, melee, and defeat a basic mandatory enemy with Static Pulse.
2. Static Pulse cannot be removed from the Weapon cycle.
3. Out-of-bounds recovery returns to valid state.
4. No foreign receipt is required for the player to remain basically playable.

## 35.2 Controls

5. Q/E/1/2/3 activate five distinct Ability slots directly.
6. Shift activates Mobility and never ordinary sprint.
7. F never activates a generated combat Echo.
8. MMB always reaches baseline melee unless rebound.
9. R dispatches only the selected Weapon’s feed action.
10. Player-facing bindings are rebindable without changing semantic slot roles.

## 35.3 Weapon cycle

11. Static + three Weapon Echoes produce four valid cycle states.
12. Empty slots are skipped.
13. Switching away from a partial magazine does not refill it.
14. Switching away from Heat does not clear it.
15. Switching does not activate inactive Weapon passives.
16. A selected Weapon remains useful without another Weapon acting as mandatory primer.

## 35.4 Ability recharge

17. Resource Ability cannot overspend its pool.
18. Multi-charge Cooldown recharges predictably and serially.
19. Action recharge advances only on declared facts/metrics.
20. Failed preflight spends nothing.
21. Post-commit miss receives no implicit refund.
22. Recharge modifiers cannot create an unbounded self-feed loop.
23. Resource/Cooldown/Action are visibly distinguishable in HUD.

## 35.5 Interaction

24. F activates a normal mechanism.
25. F activates an AP Check while preserving AP transaction semantics.
26. F picks up and drops/places carryables.
27. Required carryable lost out of bounds recovers.
28. Carrying produces unambiguous context prompt.
29. Hacking begins through F and resolves as a room-signal input rather than bespoke door logic.

## 35.6 Physics

30. Eligible object can be manipulated.
31. Ineligible progression object cannot be manipulated merely because it is physically light.
32. Physics cannot self-launch the player into universal traversal.
33. Player-owned impact has a hard damage ceiling.
34. Resting/jittering props cannot repeatedly damage.
35. Optional clever sequence breaks remain possible where no semantic gate forbids them.

## 35.7 Damage / crit / Status

36. No normal gameplay path writes Health outside the damage resolver.
37. Same ordinary non-crit attack under same state gives same damage.
38. 100% crit guarantees Tier I.
39. 150% crit never produces an ordinary hit.
40. Overcrit tiers scale linearly rather than exponentially.
41. Status cannot directly or indirectly schedule periodic Health damage.
42. Failed chance-based Status attempt visibly increases bounded susceptibility.
43. Successful Status application increases temporary adaptation.
44. Strong enemies can resist more without every effect becoming blanket `IMMUNE`.
45. World fire may damage independently from `BURNING`.

## 35.8 Loadout

46. Unequipped Archive hosts produce zero live listeners/reactions/resources.
47. Full loadout cannot be swapped during ordinary active combat.
48. Weapon cycling is not a full loadout swap.
49. Re-equipping an old host restores legal saved state instead of refilling it.
50. Newly introduced host cannot manufacture free readiness in an already-active Zone.
51. Mod insertion/removal at the Hub has no respec fee.
52. Only one high-tier Gear piece may be equipped across Head/Torso/Arms/Legs.

## 35.9 Capability progression

53. Hard capability gate cannot appear before guarantee.
54. Epsilon cannot invent a hard requirement.
55. GRAPPLE-required Zone verifies a usable expression is equipped before entry or supplies it before the requirement.
56. Raw DPS threshold cannot become AP reachability logic.
57. Physics/recoil may bypass optional geometry without automatically invalidating the Zone.

## 35.10 Presentation / device

58. Weapon-cycle transition visibly identifies the newly selected configuration.
59. Static Pulse has recognizable neutral/home presentation.
60. Viewmodel animation/VFX cannot decide simulation outcome.
61. Physics ownership/target/relation state is visually readable.
62. A configuration with no RMB or feed mechanic does not invent meaningless filler UI.

---

# 36. TUNING VALUES THAT MAY MOVE WITHOUT REOPENING THE DESIGN

These are playtest/balance knobs:

- base walk speed;
- acceleration/deceleration;
- air control;
- jump velocity;
- coyote-time;
- jump buffer;
- Static Pulse damage/cadence;
- baseline melee damage/reach/recovery;
- magazine sizes;
- reload durations;
- Heat rates/cooling;
- charge times;
- Resource capacities/costs;
- Cooldown durations;
- Action thresholds/contributions;
- Mod capacity if 2/4 proves wrong;
- exact base Health if 100 proves poor;
- Barrier values;
- Defense curve/cap;
- crit technical ceiling;
- Status base chances;
- pity gain;
- adaptation strength/decay;
- Status duration;
- Physics mass/force/range/speed ceilings;
- Forge conversion ratios;
- HUD dimensions/placement;
- device transformation animation speed.

Changing one tuning value does not reopen its architecture.

Examples:

Changing coyote time does not create sprint.

Changing Mod capacity does not create item level.

Changing Status chance does not turn Status into deterministic buildup or DoT.

---

# 37. ARCHITECTURAL TRUTHS A TUNING PASS MUST NOT ACCIDENTALLY REOPEN

Unless the owner explicitly changes this design:

- one Epsilon device;
- Static Pulse always selectable;
- up to three equipped Weapon Echo configurations;
- each Weapon must stand alone;
- wheel is Weapon selection, not primer maintenance;
- LMB primary / RMB Weapon intrinsic;
- five direct Ability slots Q/E/1/2/3;
- one Shift Mobility slot;
- F universal world interaction;
- R contextual Weapon feed;
- permanent baseline melee;
- MMB default melee binding;
- no dedicated Signature slot in v1;
- no baseline sprint/stamina;
- no baseline crouch/slide in v1;
- no persistent conventional bullet scarcity;
- Resource/Cooldown/Action all exist;
- Readiness and Cost remain conceptually distinct;
- controlled typed recharge hybrids only;
- runtime resources are not AP currency/items;
- Physics Tools are bounded manipulation, not universal movement/damage;
- ordinary F carryables do not secretly require a Physics Echo;
- one damage road;
- no random base-damage range;
- no elemental/resistance matrix as core damage model;
- linear overcrit;
- chance-based Status with visible pity + adaptation;
- Status never directly deals periodic damage;
- four Gear slots;
- one high-tier Gear piece across those four in v1;
- Mods may meaningfully transform hosts;
- loadout experimentation is free at safe boundaries;
- full loadout is committed during an excursion;
- only equipped hosts are runtime-active;
- hard capability requirements obey NO REQUIREMENT BEFORE GUARANTEE;
- raw DPS is not progression truth;
- optional sequence breaking is welcome;
- Epsilon never authors executable mechanics or keybinds.

---

# 38. FINAL PLAYER SNAPSHOT

A new player with no interesting Echoes enters a Zone.

Movement is fast enough that walking is not a punishment.

Space jumps.

MMB always gives a real melee strike.

The device always has Static Pulse.

F always touches the world.

Later, the build grows.

The same physical device now has three strange Weapon interpretations. The wheel changes what it believes it is. LMB fires that interpretation. RMB uses its intrinsic behavior. R services its feed.

Q, E, 1, 2, and 3 are five directly reachable impossible actions. Some wait. Some spend. Some demand that the player *do something* to earn them back.

Shift is the movement identity of the build.

Head, Torso, Arms, and Legs bend rules around those actions. Mods make relationships stranger.

The world is not decoration around the loadout.

It contains things the player can actually affect:

- cubes;
- plates;
- levers;
- signal lines;
- barrels;
- breakables;
- rails;
- launch machinery;
- doors;
- water;
- moving structures;
- physical objects that remember forces.

A Status does not mean “purple damage over time.”

It means the enemy is lighter now, or confused, or anchored, or burning in a way the environment understands.

A crit can become more than 100% certain.

A crate can hurt something without becoming the best gun.

A clever trick can skip an optional ledge without invalidating real progression.

A generated Zone can eventually say “this route requires Grapple,” but only after the game has proved the player can bring Grapple there.

And none of those systems need to ask Epsilon what a button means at runtime.

**That is the player Archipepsi is building.**

---

# 39. CHANGE CONTROL

This document is the canonical player target beginning with v1.0.

When another document conflicts on player design:

1. newer explicit owner decisions win;
2. strong playtest evidence may justify an explicit revision;
3. this document wins over older player/control/loadout drafts;
4. current executable code remains truth for what is **shipped today**, not authority for what the migration target is supposed to become.

Future architectural changes should update this document deliberately instead of leaving contradictory decisions buried in chats or implementation prompts.

**End of ARCHIPEPSI — PLAYER DESIGN AUTHORITY v1.0**
