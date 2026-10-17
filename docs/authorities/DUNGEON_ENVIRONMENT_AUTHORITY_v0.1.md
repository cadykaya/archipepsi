# ARCHIPEPSI — DUNGEON & ENVIRONMENTAL GAMEPLAY AUTHORITY
## Canonical design target for room verbs, machinery, physical systems, dungeon state, procedural composition, and environmental gameplay

**Status:** Design authority  
**Version:** v0.1  
**Scope:** Rooms, dungeon machinery, environmental verbs, physical interaction, traversal machinery, hazards, signals, puzzle composition, room-state transformation, multi-room state, and Epsilon composition rules.  
**Relationship to other authorities:** This document is intended to sit beside the Player Design Authority and the room-contract / authored-shell architecture. Where this document refers to player controls, player capability guarantees, room manifests, movement offers, or placement surfaces, those existing authorities remain the source of truth for their own domains.

---

# 0. WHY THIS DOCUMENT EXISTS

Archipepsi's earlier procedural-room approach proved that having more objects, more activity labels, or more decorative variation does not automatically create more game.

A room can contain targets, pickups, traversal points, and props and still feel like the same rectangle with a different checklist.

The correction is not merely "add puzzles."

The correction is to give rooms a **shared environmental gameplay language** rich enough to express:

- physical cause and effect;
- authored spatial identity;
- changing topology;
- traversal machinery;
- systemic hazards;
- manipulable objects;
- readable signals;
- room-state transformations;
- combat/environment crossover;
- multi-room dependencies;
- dungeon-scale state changes;
- optional shortcuts and secrets;
- persistent consequences;
- recovery from failure;
- and combinations of all of the above.

This authority therefore does **not** define a bag of Portal-like props.

It defines the environmental grammar from which Archipepsi can build places.

The governing idea is:

> **A room is not interesting because it contains things. A room is interesting because things in it can change what the player can do, where the player can go, what the player can infer, and what happens next.**

The most useful reference lessons are broader than any one game:

- Portal demonstrates legible cause-and-effect, reusable puzzle primitives, and spatial routing.
- Half-Life demonstrates physical consequence, machinery as place, environmental combat, and objects that participate in the world.
- Zelda demonstrates room-state transformation, dungeon-wide state, local keys, shortcuts, gates, and mechanisms that reconfigure topology.
- Immersive sims demonstrate systems whose interactions create alternate solutions rather than isolated scripted answers.
- Physics platformers demonstrate that traversal and object motion can themselves be the puzzle language.

Archipepsi should borrow those **design lessons**, not reproduce their props one-for-one.

---

# 1. COMPLETENESS AUDIT

Before freezing the vocabulary, the design was checked against the broad question:

> **What kinds of meaningful environmental play commonly found in puzzle games, physics games, immersive sims, Zelda-like dungeons, and strong FPS spaces would still be impossible to express?**

The audit found several families that are easy to omit when thinking only in terms of "machinery props." They are included here as first-class parts of the system:

1. **Sound and acoustics**
   - noise-producing machinery;
   - audible timing cues;
   - sound-triggered sensors if ever desired;
   - alarms;
   - machinery that communicates state through sound;
   - sound occlusion / directionality as a readability tool.

2. **Temperature, pressure, atmosphere, and environmental media**
   - heat, cold, steam, smoke, gas, vacuum/pressure where appropriate;
   - vents;
   - extinguishing;
   - breathable / non-breathable regions;
   - environmental states that can be changed by machinery.

3. **Gravity and orientation**
   - low/high gravity regions;
   - directional gravity only if later supported by the player controller;
   - rotating rooms or architecture that changes which surfaces are traversable;
   - gravity-sensitive objects.

4. **Teleportation / phase-space transitions**
   - teleporters, phase gates, room-to-room transport, paired portals, or other space-folding mechanisms are legal vocabulary if authored later;
   - they are not assumed to be part of the first implementation slice.

5. **Constraint mechanics**
   - ropes, chains, hinges, pulleys, counterweights, seesaws, suspended loads, tethered objects, rails, tracks, and mechanically constrained movement;
   - not every physical object is free rigid-body clutter.

6. **NPC / AI participation**
   - enemies, turrets, drones, neutral machinery actors, and potentially allies can participate in sensors, hazards, doors, and room state;
   - environmental gameplay is not player-only.

7. **Information as gameplay**
   - light, sightlines, windows, screens, signage, sound cues, moving indicators, observation, silhouettes, and clue placement;
   - a puzzle must be understandable before it is solvable.

8. **Archipelago integration**
   - local dungeon mechanisms and AP Checks must remain distinct;
   - environmental systems may gate or reveal Checks, but may not manufacture progression truth or bypass AP transaction semantics.

9. **Accessibility and readability**
   - critical state cannot be communicated by color alone;
   - timing and signal state should have redundant visual and, where appropriate, audio cues;
   - puzzle readability is part of correctness, not polish.

10. **Determinism, validation, performance, and debugging**
    - procedural composition must be replayable;
    - runtime state must be inspectable;
    - puzzle packages must be validated;
    - system combinations need compatibility contracts;
    - simulation complexity must have budgets.

With those families included, this document is intended to be a complete **design vocabulary**, while still allowing future specific machines, hazards, and puzzle packages to be added without changing the core grammar.

---

# 2. THE CENTRAL ENVIRONMENTAL MODEL

The simplest machinery relationship is:

> **INPUT → SIGNAL → OUTPUT**

But the full environmental model is larger:

> **ACTOR / OBJECT / ENVIRONMENT**  
> interacts with  
> **INPUT / SENSOR / MATERIAL / FORCE / ROUTE**  
> which changes  
> **SIGNAL / STATE / PHYSICAL CONFIGURATION**  
> which changes  
> **OUTPUT / TOPOLOGY / TRAVERSAL / HAZARD / INFORMATION**  
> and therefore changes  
> **WHAT THE PLAYER CAN DO NEXT.**

A weighted object on a plate opening a door is one expression.

A generator restoring power across three rooms is another.

A crane moving cargo to create a bridge is another.

A player breaking a support so a hanging load crushes enemies is another.

A room flooding and turning walkable ground into swimming space is another.

The grammar must support all of them.

---

# 3. DESIGN LAWS

## 3.1 Cause and effect should be spatially legible

If an input controls an output, the player should normally have a way to understand that relationship through:

- visible conduit;
- mechanical linkage;
- direct sightline;
- repeated visual language;
- audio;
- motion;
- terminal UI;
- signage;
- or deliberate observation.

A hidden relationship is permitted only when discovering the relationship is itself the intended challenge.

## 3.2 Simulation owns truth; presentation explains truth

The signal graph, object state, traversal state, hazard state, and puzzle state are authoritative.

Visual conduit glow, particle pulses, sounds, animations, and UI report those states.

A missing VFX element may hurt readability but must not change the underlying mechanism.

## 3.3 Required progression may never depend on an unguaranteed capability

The Player Design Authority's rule applies:

> **NO REQUIREMENT BEFORE GUARANTEE**

If a room requires grapple, a Physics Echo primitive, swimming, a weapon interaction, or another semantic capability, the capability must be guaranteed and equipped before the requirement, or a validated safe loadout opportunity must exist before first use.

Owned is not the same as currently slotted.

## 3.4 Epsilon composes from truths; Epsilon does not invent truth

Epsilon may choose among validated packages, sockets, optional branches, skins, presentations, compatible outputs, and authored room opportunities.

It may not invent:

- arbitrary physics constants;
- arbitrary launch arcs;
- unvalidated signal graphs;
- new collision semantics;
- unsupported player capabilities;
- AP item truth;
- impossible timing windows;
- unrecoverable required objects;
- or novel logic that has no validator.

## 3.5 Environmental verbs should cross-pollinate

The goal is not fifty isolated gimmicks.

The goal is a smaller number of verbs that can safely interact:

- wind moves player + objects + projectiles;
- electricity powers machines + hazards + water interactions where authored;
- explosions hurt actors + move objects + break tagged surfaces;
- moving machinery changes cover + traversal + puzzle routing;
- enemies can trigger sensors or be killed by machinery;
- Physics Echoes manipulate real puzzle objects;
- rails can have switches;
- launch pads can send players or compatible objects;
- water affects buoyant objects and traversal.

Cross-system combinations should be intentional and contract-driven.

## 3.6 No softlocks

Every required package must either be naturally recoverable or provide explicit recovery.

If a necessary object can be:

- destroyed;
- dropped into a void;
- wedged;
- stranded;
- consumed;
- moved out of reach;
- or lost during save/load;

then the package must define recovery.

## 3.7 A room must remain a place, not become a circuit diagram

Machinery exists inside architecture.

The room should have:

- landmarks;
- local spaces;
- readable destinations;
- circulation;
- cover;
- height relationships;
- sightlines;
- and spatial identity

even when puzzle overlays are hidden.

---

# 4. ROOM PURPOSE GRAMMAR

A room can serve one or several purposes.

The purpose matters because the same object has different meaning in different contexts.

Supported purpose families include:

- traversal;
- arena;
- ranged arena;
- close combat arena;
- ambush;
- holdout;
- chase;
- escape;
- gauntlet;
- boss arena;
- environmental puzzle;
- physical puzzle;
- logic puzzle;
- routing puzzle;
- observation puzzle;
- timing challenge;
- multi-stage mechanism;
- exploration;
- secret room;
- reward room;
- junction;
- branching decision;
- return-loop room;
- shortcut room;
- vertical ascent;
- vertical descent;
- safe/recovery room;
- spectacle transition;
- dungeon-state control room;
- hybrid room.

Example:

A crane in a **combat room** is movable cover, threat, or weapon.

A crane in a **physics puzzle** moves cargo.

A crane in a **traversal room** creates platforms.

A crane in a **dungeon-state room** moves an enormous component that changes connections elsewhere.

Epsilon should choose a room purpose before choosing machinery packages.

---

# 5. INPUTS AND SENSORS

## 5.1 Universal interact button

The player uses **F**.

F is the world's semantic interaction key.

F may:

- press;
- activate;
- open;
- pick up;
- place;
- insert;
- remove;
- pull a lever;
- operate a crank;
- start a hack;
- use a terminal;
- call a lift;
- or interact with another clearly presented world object.

Context priority must be deterministic.

The player should not accidentally pick up a nearby crate while trying to operate the console in front of them.

## 5.2 Pressure plate

A pressure plate emits ON while qualifying weight satisfies its threshold.

Weight should use semantic categories or stable mass rules rather than uncontrolled debris accumulation.

Possible qualifying actors:

- player;
- weighted carryable;
- heavy movable object;
- enemy;
- vehicle or machinery component where authored.

## 5.3 Pulse button

F activation emits PULSE.

Typical use:

- door;
- elevator call;
- reset;
- temporary mechanism trigger;
- single machinery action.

## 5.4 Timed button

F activation produces ON for a defined duration.

The remaining state should be readable through:

- conduit animation;
- light behavior;
- sound cadence;
- explicit display;
- or mechanism motion.

Timing windows must be validated against the required traversal path.

## 5.5 Lever / toggle switch

Persistent binary state.

May represent:

- power routing;
- room transformation;
- bridge orientation;
- hazard state;
- conveyor direction;
- gate state.

## 5.6 Shootable target

A valid weapon hit emits PULSE or toggles state.

Mandatory targets must be triggerable by a guaranteed baseline weapon capability unless a stronger capability is explicitly guaranteed first.

## 5.7 Hack terminal

F enters a short interaction.

The default target length is approximately 5–15 seconds.

Possible minigame families:

- route connection;
- waveform/frequency matching;
- ordered nodes;
- circuit tracing;
- simple alignment;
- code/pattern interpretation.

A hack should not always be a button with extra animation.

It may:

- enable;
- disable;
- redirect;
- invert;
- select;
- override;
- or reveal.

## 5.8 Object socket

A semantic receptacle for a carryable object.

Examples:

- battery socket;
- fuse slot;
- key core cradle;
- gear mount;
- crank socket;
- power cell dock;
- removable control module.

The object is physically meaningful and may be inserted or removed.

## 5.9 Receiver

A receiver accepts a specific routed phenomenon.

Families:

- energy ball receiver;
- beam receiver;
- power cell receiver;
- fluid pressure receiver;
- magnetic alignment receiver;
- signal relay.

## 5.10 Proximity / presence sensor

Detects a qualifying actor inside a region.

Possible filters:

- player;
- enemy;
- object class;
- any actor;
- required object ID.

## 5.11 Enemy-clear sensor

Becomes active when an authored encounter or enemy group reaches its completion condition.

This is the correct basis for combat gates.

## 5.12 Trip beam / line-break sensor

Activates when a beam or line is interrupted.

Useful for:

- alarms;
- traps;
- stealth-like sequences;
- object placement;
- timing challenges.

## 5.13 State sensors

Possible observed state includes:

- water level;
- object position;
- lift position;
- machine phase;
- room power state;
- gravity mode;
- number of active inputs;
- target state;
- puzzle completion.

---

# 6. SIGNALS AND LOGIC

## 6.1 Signal forms

Initial semantic forms:

- **OFF**
- **ON**
- **PULSE**
- **VALUE** where a continuous or indexed control is genuinely needed.

VALUE should not be used merely because it exists.

Binary mechanisms remain binary.

## 6.2 Basic logic

Supported foundational logic:

- DIRECT;
- AND;
- OR;
- NOT;
- TIMER;
- LATCH.

Later or package-specific logic may include:

- SEQUENCE;
- COUNTER;
- SELECTOR;
- ROUTER;
- DELAY;
- THRESHOLD.

Arbitrary programmable logic is not a v1 requirement.

## 6.3 Signal latency

Logical state should normally propagate immediately unless delay is itself gameplay.

A visible pulse may travel along a conduit for communication while the authoritative state updates immediately, or the package may explicitly define delayed activation.

The player should never be confused about whether a visual travel animation is cosmetic or mechanically delayed.

## 6.4 Visible conduits

Visible conduits are a first-class readability system.

They are **not destructible by default**.

Their job is to communicate a declared relationship.

Suggested states:

- inactive;
- active;
- pulse travelling;
- blocked/disconnected;
- alternate route;
- faulted.

Critical state must not rely on hue alone.

Use combinations of:

- brightness;
- pattern;
- motion;
- shape;
- animation direction;
- sound.

Special authored "breakable junction" puzzles may allow signal infrastructure itself to be altered, but ordinary conduits are presentation, not fragile world wiring.

## 6.5 Mechanical linkages

Not all connections are electrical.

A mechanism may communicate linkage through:

- chain;
- belt;
- shaft;
- gear train;
- pipe;
- hose;
- rope;
- track;
- hydraulic cylinder;
- moving arm.

These are visual and potentially physical expressions of the same causal grammar.

---

# 7. OUTPUTS AND ACTUATORS

## 7.1 Door / gate / shutter

Possible state:

- open / closed;
- locked / unlocked;
- opening / closing;
- jammed;
- powered / unpowered.

Required doors should not silently crush or trap the player.

Default safe behavior:

> If closure would intersect the player or a required object, delay or reopen unless the mechanism is explicitly authored as a hazard.

## 7.2 Bridge

Possible forms:

- extending;
- rotating;
- folding;
- raising;
- lowering;
- hard-light / energy bridge later.

A bridge can alter topology, cover, combat lanes, and traversal simultaneously.

## 7.3 Stairs / ramps / ladders

May extend, retract, lower, rotate, or become accessible from the far side.

Useful for permanent shortcuts.

## 7.4 Moving platform

Possible control:

- start/stop;
- A/B;
- loop;
- reverse;
- selected stop;
- call-to-player;
- signal-directed destination.

## 7.5 Lift / elevator

May support:

- simple A/B;
- multiple stops;
- call buttons;
- destination selection;
- dungeon-state locking;
- physical cargo transport.

## 7.6 LaunchPad

Directional source-to-landing traversal.

Art/room author declares:

- source region;
- landing region;
- clearance.

Runtime solves the arc.

Authors do not define arbitrary velocity vectors.

## 7.7 Bounce pad

Primarily vertical or local impulse.

It remains distinct from a directional LaunchPad.

## 7.8 Fan / wind machine

Powered force source.

May affect authored compatible classes:

- player;
- light objects;
- projectiles;
- gas/smoke;
- hanging objects.

## 7.9 Conveyor / moving walkway

May:

- move player;
- move objects;
- route cargo;
- feed hazards;
- reverse;
- stop;
- change junction route.

## 7.10 Rotating machinery

Examples:

- turntable;
- rotating bridge;
- crane;
- giant arm;
- wheel;
- drum;
- central machine;
- rotating room segment.

## 7.11 Crane / hoist

May:

- move suspended load;
- alter cover;
- create bridge;
- reposition puzzle object;
- carry platform;
- create environmental kill;
- change room silhouette.

## 7.12 Piston / crusher / moving wall

Can be:

- traversal timing;
- hazard;
- enemy weapon;
- topology change;
- object manipulation;
- machine component.

## 7.13 Rail switch

Changes which branch a grind rail or transport rail follows.

A rail can therefore participate in signal logic rather than being a static movement line.

## 7.14 Hazard controller

Controls another hazard actor.

The hazard owns damage and collision.

The signal controls whether and how it operates.

## 7.15 Light controller

May:

- restore illumination;
- reveal markings;
- activate light-sensitive receivers;
- alter enemy behavior;
- communicate room state.

## 7.16 Atmosphere controller

Possible later actuators:

- vent;
- pump;
- drain;
- flood;
- pressurize;
- depressurize;
- heat;
- cool;
- purge gas;
- extinguish fire.

## 7.17 Teleporter / phase gate

Legal future actuator.

Requires explicit spatial and save/load semantics.

Not part of the minimum first slice.

---

# 8. PHYSICAL OBJECT VERBS

The environment should support more than "press F on prop."

Possible physical verbs include:

- pick up;
- drop;
- place;
- push;
- pull;
- drag;
- roll;
- rotate;
- stack;
- balance;
- wedge;
- jam;
- insert;
- remove;
- throw;
- launch;
- suspend;
- tether;
- pin;
- attach;
- detach;
- align;
- counterweight;
- block;
- shield;
- redirect;
- float;
- sink;
- carry on machinery;
- use as cover.

Not every object supports every verb.

Object semantics must be explicit.

---

# 9. CARRYABLE AND MOVABLE OBJECT CLASSES

## 9.1 Generic carryable
Basic F pickup/drop/place object.

## 9.2 Weighted carryable
Carries semantic weight for pressure systems. Visual form need not be a literal cube.

## 9.3 Power cell / battery
Carryable energy source. Can be inserted into a socket. May power local machinery while inserted.

## 9.4 Fuse / key component
Carryable progression object for local dungeon logic. Distinct from AP progression.

## 9.5 Crank / gear / mechanical part
Physical component needed to operate machinery.

## 9.6 Movable cover
Large enough to affect combat sightlines. May be pushed, pulled, crane-moved, Physics-Echo moved, destroyed, or used to block hazards.

## 9.7 Cart / wheeled object
Constrained physical object. May travel on floor, track, rail, or slope.

## 9.8 Floating / buoyant object
Supports water interactions.

## 9.9 Magnetic object
Supports attraction/repulsion machinery or Physics Echo interactions if later authored.

## 9.10 Reflector object
Redirects a beam or energy route.

## 9.11 Puzzle artifact
Room-specific semantic object. Should still obey common pickup, recovery, persistence, and socket contracts where possible.

---

# 10. OBJECT SPAWNING, DISPENSERS, AND RECOVERY

Required movable objects need reliable lifecycle behavior.

Possible infrastructure:

- object dispenser;
- respawner;
- return chute;
- recall pad;
- reset station;
- replacement spawn;
- dissolve-and-recreate volume;
- out-of-bounds detector.

A required object may not simply disappear forever.

Puzzle object identity should be semantic.

If a cube is recreated, the puzzle still knows "the required weighted object exists" rather than depending on one fragile runtime instance.

---

# 11. CONSTRAINT MECHANICS

Free rigid-body simulation is not the only kind of physicality.

Supported constraint families may include:

- hinge;
- slider;
- rope;
- chain;
- pulley;
- counterweight;
- seesaw;
- suspended load;
- pendulum;
- track;
- trolley;
- crane cable;
- tether;
- rotating axle.

These mechanisms provide readable, stable physical relationships.

A counterweight puzzle should behave like a counterweight, not like two arbitrary boxes connected by magic.

---

# 12. ROUTING SYSTEMS

"Get something from here to there" is a major puzzle family.

## 12.1 Energy ball

System:

> **Emitter → Ball → Receiver**

Desired properties:

- predictable speed;
- visible route;
- recoverable/resettable;
- can interact with tagged redirectors;
- may damage actors if appropriate;
- receiver behavior may latch or remain temporary.

The player does not pick up the raw ball with F by default.

## 12.2 Beam / laser

System:

> **Emitter → Beam Path → Receiver**

Potential interactions:

- blocker;
- reflector;
- movable reflector;
- rotating reflector;
- prism/splitter later;
- moving machinery;
- timed shutters.

## 12.3 Electricity / power routing

Can be represented by signal conduits, physical cables, power cells, generators, or junctions.

Do not simulate electrical engineering beyond what gameplay needs.

## 12.4 Fluid routing

Future family:

- pipe;
- valve;
- pump;
- reservoir;
- pressure;
- drain;
- fill;
- overflow;
- coolant.

## 12.5 Wind routing

Possible through:

- fans;
- ducts;
- shutters;
- vents;
- directional gates.

## 12.6 Cargo routing

Through:

- conveyors;
- cranes;
- rails;
- chutes;
- elevators;
- carts;
- diverters.

## 12.7 Rail routing

Traversal rails may support:

- branch switch;
- merge;
- direction change;
- power state;
- moving rail endpoint.

---

# 13. MATERIAL PROPERTIES

Materials are semantic gameplay traits, not merely shader labels.

Possible properties:

- breakable;
- bombable;
- brittle;
- burnable;
- conductive;
- insulating;
- reflective;
- transparent;
- opaque;
- slippery;
- sticky;
- buoyant;
- heavy;
- light;
- magnetic;
- grapple-compatible;
- climb-compatible;
- rail-compatible;
- penetrable;
- destructible support;
- heat-sensitive;
- cold-sensitive;
- pressure-sensitive;
- signal-blocking.

The exact v1 set should remain small.

New properties should exist because multiple systems use them, not because one puzzle needs a bespoke exception.

---

# 14. DESTRUCTION, CONSTRUCTION, AND ALTERATION

Possible world changes:

- crate breaks;
- glass shatters;
- wall explodes;
- support collapses;
- hanging load falls;
- barrier is removed;
- bridge is destroyed;
- debris changes cover;
- panel opens;
- temporary construct appears;
- object is repaired;
- junction is restored;
- component is inserted;
- surface freezes or melts later;
- rubble reveals a route.

Destruction must respect tagged authority.

Ordinary explosives do not mean "destroy arbitrary level geometry."

---

# 15. BREAKABLE CONTAINERS AND REWARDS

A breakable crate should normally have a gameplay reason to exist.

Possible outcomes:

- health;
- temporary combat resource;
- local puzzle object;
- cover removal;
- reveal target;
- reveal conduit;
- reveal route;
- hidden cache;
- environmental storytelling.

Not every crate needs loot.

AP progression items are not random crate drops unless an explicit AP Check is represented by the crate interaction.

---

# 16. EXPLOSIVES

## 16.1 Reactive barrel

Properties:

- takes normal damage;
- explodes;
- damages player and enemies;
- applies physical impulse;
- may chain react;
- can interact with bombable/destructible targets if authored.

## 16.2 Bomb-flower / timed explosive object

Portable recoverable explosive.

Possible behavior:

- F pickup arms it;
- hit arms it;
- socket creates timed charge;
- respawns after use if required.

Bombable geometry is explicitly tagged.

This is not unrestricted terrain destruction.

---

# 17. TRAVERSAL MACHINERY

Environmental movement vocabulary includes:

- smooth rails;
- LaunchPads;
- bounce pads;
- grapple targets;
- moving platforms;
- lifts;
- elevators;
- conveyors;
- moving walkways;
- cranes;
- swinging platforms;
- ropes/chains;
- ladders/climbables if later supported;
- wind columns;
- fans;
- water currents;
- floating platforms;
- rotating platforms;
- pistons;
- retracting stairs;
- sliding walls;
- hard-light bridge later;
- tractor stream / excursion-funnel-like force path later;
- speed surfaces;
- slippery surfaces;
- sticky surfaces;
- low/high gravity zones;
- directional gravity only after controller support;
- teleporter/phase transit later.

Traversal machinery must obey actual player movement and clearance audits.

---

# 18. GRAPPLE TARGETS

The room contract may expose a grapple opportunity.

A gameplay package can instantiate a readable grapple target within that opportunity.

The player must understand "this can be grappled" from consistent presentation.

Possible anchor behavior:

- fixed;
- moving;
- swinging;
- temporary;
- powered;
- disabled;
- breakable only if recovery is safe.

Mandatory grapple use requires guaranteed Grapple capability.

---

# 19. WATER AND LIQUIDS

Water is a full environment system, not a decorative volume.

Foundation behavior:

- enter;
- swim;
- surface;
- exit;
- oxygen;
- drowning / recovery;
- buoyancy for tagged objects;
- current;
- submerged interaction where appropriate.

Later machinery:

- pumps;
- valves;
- fill;
- drain;
- changing water level;
- flood gates;
- floating routes;
- submerged mechanisms.

Other liquids may exist later:

- acid;
- toxic fluid;
- lava-like hazards;
- coolant.

They should share media infrastructure where sensible without pretending all liquids behave identically.

---

# 20. GASES, SMOKE, STEAM, PRESSURE, AND TEMPERATURE

Possible later environmental media:

- smoke;
- steam;
- toxic gas;
- breathable air;
- vacuum / low pressure;
- heat;
- cold;
- fire;
- coolant mist.

Possible interactions:

- vents;
- fans;
- purge;
- ignition;
- extinguishing;
- visibility reduction;
- damage;
- sensor behavior;
- machinery state.

These are legal vocabulary but not required for the first machinery implementation.

---

# 21. LIGHT, DARKNESS, AND PERCEPTION

Lighting may participate in gameplay.

Possible uses:

- powered lighting;
- blackout;
- emergency lights;
- light-sensitive receiver;
- moving spotlight;
- shadow reveal;
- silhouette clues;
- navigation guidance;
- enemy behavior;
- reveal hidden markings.

Critical progression should not depend on display darkness so extreme that the player cannot reasonably perceive the clue.

---

# 22. SOUND AND ACOUSTICS

Sound is part of environmental readability.

Possible roles:

- mechanism startup;
- countdown;
- timer urgency;
- signal pulse;
- alarm;
- rotating machinery cadence;
- distant moving object;
- water / vent state;
- enemy alert;
- hidden machinery clue.

Potential later sensor:

- sound/noise-triggered mechanism.

If sound is mechanically required, a redundant visual cue should exist for accessibility.

---

# 23. FORCES AND FIELDS

Possible environmental forces:

- wind;
- suction;
- repulsion;
- attraction;
- magnetism;
- gravity;
- buoyancy;
- water current;
- pressure jet;
- piston;
- conveyor;
- explosion;
- rotating machinery;
- centrifugal motion;
- tractor stream.

Forces may affect different actor classes according to explicit compatibility.

---

# 24. GRAVITY AND ORIENTATION

Legal future vocabulary:

- low gravity;
- high gravity;
- gravity-sensitive objects;
- rotating architecture;
- rooms that reorient physically;
- directional gravity only if the player controller and camera support it robustly.

A room cannot require orientation mechanics that the current player implementation does not support.

---

# 25. HAZARDS

Hazards may include:

- flame jet;
- electricity;
- laser;
- crusher;
- piston;
- blade;
- gear;
- steam;
- falling debris;
- collapsing floor;
- acid;
- toxic gas;
- drowning;
- explosion;
- turret;
- electrified liquid;
- security field;
- environmental projectile;
- rotating arm;
- conveyor-to-hazard;
- timed shutter;
- moving wall.

Hazards should usually be readable before they deal unavoidable damage.

---

# 26. HAZARDS AS TOOLS

One of Archipepsi's strongest environmental goals:

> **A hazard should often be usable against something else.**

Examples:

- crusher kills enemy;
- fan blows enemy;
- LaunchPad throws enemy;
- explosive breaks wall;
- electricity powers or overloads mechanism;
- fire ignites fuel;
- moving wall changes cover;
- laser damages enemies;
- rotating machinery blocks projectiles;
- water carries object;
- crane drops load.

Environmental danger and environmental agency should share systems.

---

# 27. COMBAT / ENVIRONMENT CROSSOVER

Combat should not exist in a sealed layer separate from room systems.

Possible crossover:

- destructible cover;
- movable cover;
- exploding barrels;
- shootable machinery;
- enemies standing on pressure plates;
- enemies interrupting beams;
- enemies carried by conveyors;
- hazards killing enemies;
- machinery creating/removing high ground;
- doors splitting encounters;
- enemy projectiles triggering targets;
- turrets and security systems;
- destructible generators;
- cranes moving cover;
- launchers affecting enemies;
- Physics Echoes pushing enemies into hazards;
- encounter completion transforming the room.

All direct damage still goes through the common damage authority.

---

# 28. ENEMY / AI PARTICIPATION

Enemies may interact with environmental grammar if their contracts permit it.

Possible behavior:

- open door;
- trigger sensor;
- stand on plate;
- carry local key/core;
- operate or sabotage machine;
- guard control point;
- cross rail or moving platform;
- avoid or exploit hazard;
- repair generator;
- disable mechanism;
- break cover;
- be transported by machinery.

Required progression should not depend on brittle emergent enemy behavior unless the encounter package explicitly guarantees it.

---

# 29. INFORMATION AND OBSERVATION GAMEPLAY

A player can solve by noticing.

Vocabulary:

- observation window;
- distant destination;
- visible conduit;
- screen / monitor;
- signage;
- diagram;
- machine state indicator;
- silhouette;
- audio cue;
- moving mechanism;
- clue seen only from certain angle;
- target visible through gap;
- hidden route revealed by motion;
- scanner/terminal later;
- repeated symbolic language.

A puzzle's "aha" may be understanding the room rather than manipulating a complicated object.

---

# 30. TIME

Time can be gameplay through:

- timed button;
- moving platform cycle;
- rotating machine;
- energy-ball travel;
- periodic hazard;
- closing shutter;
- countdown;
- charge/discharge;
- delayed signal;
- sequence;
- synchronization;
- moving opportunity window;
- temporary power;
- timed explosive.

Timing must be readable and validated.

Mandatory timing should not require perfect execution.

---

# 31. KEYS, LOCKS, AND LOCAL DUNGEON ITEMS

Legal local progression objects:

- key;
- keycard;
- fuse;
- seal;
- core;
- mechanical component;
- boss-key-like local token;
- power cell.

These are **local dungeon truth**.

They are not automatically AP items.

Possible lock types:

- keyed;
- powered;
- capability-gated;
- puzzle-gated;
- combat-gated;
- signal-gated;
- one-way;
- remotely opened;
- permanently unlockable;
- multi-input.

---

# 32. TOPOLOGY-CHANGING ARCHITECTURE

Architecture may change connectivity.

Examples:

- door;
- gate;
- bridge;
- retracting stairs;
- rotating bridge;
- moving wall;
- sliding floor;
- trapdoor;
- collapsing floor;
- secret wall;
- breakable wall;
- lowered ladder;
- one-way drop;
- far-side unlock;
- shortcut gate;
- rotating room;
- room-state A/B;
- elevator connection;
- teleporter later.

This is a primary dungeon verb, not an edge case.

---

# 33. STATE-SWITCH / A-B MACHINERY

A first-class puzzle family inspired by broad dungeon design.

One input changes several related pieces.

Examples:

- red bridges active / blue bridges inactive;
- platform group A raised / B lowered;
- conveyor direction reversed;
- rail branch swapped;
- walls rotated;
- water gates opened/closed;
- light/dark state changed;
- hazard lanes switched.

The two states should be visually distinct without depending on color alone.

---

# 34. HIDDEN AND REVEALED ARCHITECTURE

Possible secrets:

- sliding wall;
- bombable wall;
- breakable floor;
- vent/grate;
- hidden lift;
- concealed conduit;
- retracting panel;
- underwater passage;
- optional grapple route;
- alternate rail branch;
- observation-based secret;
- destructible support.

Secrets should reward curiosity and spatial understanding.

They need not all announce themselves with a glowing marker.

---

# 35. ONE-WAY CONNECTIONS AND SHORTCUTS

Important dungeon topology tools:

- drop-down;
- gate opened from far side;
- ladder lowered;
- bridge deployed;
- door permanently unlocked;
- shortcut elevator;
- one-way vent;
- floor collapse into lower room;
- door that locks behind encounter.

A dungeon becomes coherent when later actions reconnect earlier spaces.

---

# 36. ROOM-STATE TRANSFORMATION

A room may change substantially while remaining the same authored room.

Examples:

- power restored;
- floor flooded;
- water drained;
- crane moved;
- bridge rotated;
- central machine activated;
- walls shifted;
- lights restored;
- security disabled;
- rail branch changed;
- room reoriented;
- machinery destroyed.

The transformed state should be part of the room's authored identity.

---

# 37. MULTI-STAGE MACHINERY

A mechanism can have sequential states:

1. restore generator;
2. route power;
3. operate machine;
4. open route;
5. create shortcut.

This must be represented as a validated package or state machine.

Epsilon may not invent arbitrary six-step dependency graphs without proof.

---

# 38. MULTI-ROOM MACHINERY

Environmental consequences may cross room boundaries.

Examples:

- generator in Room A powers lift in Room C;
- valve upstream changes water downstream;
- rail switch changes destination;
- control room disables hazards in several rooms;
- machine repair opens a route elsewhere;
- power restoration lights an entire wing;
- boss mechanism changes previous rooms.

Cross-room dependencies must be:

- visible or inferable;
- persistent correctly;
- validated for reachability;
- cycle-safe;
- save/load safe.

---

# 39. DUNGEON-SCALE STATE MACHINES

A Zone or authored dungeon may have a macro state.

Examples:

- unpowered → partially powered → fully powered;
- flooded → drained;
- security active → disabled;
- machine dormant → active;
- gravity state A → B;
- central mechanism progressively repaired;
- structure collapsed / intact;
- rail network rerouted.

Macro state can affect:

- topology;
- encounters;
- hazards;
- presentation;
- routes;
- secrets;
- traversal offers.

This is how a dungeon gains an identity larger than its individual rooms.

---

# 40. WORLD EVENTS AND PLAYABLE SPECTACLE

Large state changes can be gameplay, not cutscene-only decoration.

Examples:

- giant machine starts;
- train passes;
- crane drops cargo;
- wall ruptures;
- floor collapses;
- room floods;
- lift fails;
- structure rotates;
- machinery breaches a wall;
- enemies enter through damaged architecture.

World events should preserve player control where practical.

---

# 41. SECRETS AND EXPLORATION

Possible reward structure:

- optional room;
- hidden cache;
- AP Check;
- local reward;
- shortcut;
- alternate combat position;
- lore/archive object;
- traversal challenge;
- puzzle;
- hidden mechanism;
- alternate route.

Not every secret requires a unique mechanic.

Good secrets often remix existing verbs.

---

# 42. REWARDS

Environmental rewards may include:

- health;
- temporary combat resource;
- local puzzle resource;
- shortcut;
- safer route;
- high ground;
- disabled hazard;
- persistent room improvement;
- secret;
- lore/archive;
- cosmetic presentation;
- AP Check where explicitly placed.

The reward for solving machinery can be **a changed world**, not merely loot.

---

# 43. ARCHIPELAGO CHECK INTEGRATION

Environmental systems may:

- reveal a Check;
- unlock access to a Check;
- contain a Check;
- gate a Check behind a validated puzzle;
- use F to interact with a Check object.

But:

- local puzzle objects are not AP items by default;
- crates cannot randomly create AP progression;
- signal systems cannot silently award AP truth;
- AP transaction semantics remain distinct from ordinary interaction;
- procedural environmental rewards must not violate the AP request/catalog contract.

---

# 44. PHYSICS ECHO INTEGRATION

Physics Echoes should feel unusually useful in environmental spaces without becoming universal puzzle bypass tools.

Suitable interactions:

- push;
- pull;
- grab at range;
- tether;
- pin;
- rotate;
- align;
- bounded impulse;
- mass/drag response;
- manipulate authored constructs;
- recall/dissolve compatible constructs;
- reposition movable cover;
- interact with puzzle objects where tagged.

Physics Echoes should generally **rearrange energy and matter more effectively than they create either**.

Required puzzles must not assume an unequipped Physics Echo unless guaranteed.

Puzzle packages may expose optional Physics solutions while retaining a baseline validated solution.

---

# 45. MOVEMENT ECHO / MOVEMENT OFFER INTEGRATION

Existing movement-offer vocabulary remains valid:

- rail;
- launch;
- grapple;
- future movement offers.

Environmental machinery may:

- power a rail;
- switch a rail branch;
- activate a LaunchPad;
- move a grapple anchor;
- alter landing region;
- change the room around a movement route.

Mandatory routes remain subject to room and capability validation.

---

# 46. INTERACTION PRIORITY

Because F performs many world verbs, target selection must be deterministic.

Recommended priority uses:

1. direct explicit UI/terminal interaction currently focused;
2. required socket/place interaction;
3. pickup/drop target;
4. button/lever/door;
5. optional contextual interaction.

Selection should consider:

- center-screen focus;
- distance;
- line of sight;
- interaction cone;
- current carry state;
- semantic priority.

The UI should show what F will do before the press where ambiguity exists.

---

# 47. RESET GROUPS

Every puzzle package belongs to a semantic reset group.

Reset may restore:

- movable objects;
- emitter state;
- receiver state;
- temporary signals;
- timed mechanism;
- moving platforms;
- destructible required targets;
- local hazards;
- puzzle-specific doors;
- routing pieces.

Reset should not necessarily erase:

- completed AP Check;
- permanently opened shortcut;
- dungeon macro progress;
- boss completion;
- deliberate persistent unlock.

Reset scope is explicit.

---

# 48. SAVE / LOAD / DEATH / REENTRY SEMANTICS

Every persistent mechanism must declare behavior under:

- puzzle reset;
- player death;
- room unload/reload;
- Zone exit;
- game save/load;
- revisit later.

Suggested categories:

### EPHEMERAL
Reconstructed from initial state.

Examples:
- timed button;
- temporary projectile;
- transient energy ball.

### PUZZLE_LOCAL
Restored from puzzle semantic state.

Examples:
- cube socketed;
- lever state;
- bridge position.

### ROOM_PERSISTENT
Meaningful room change survives revisit.

Examples:
- shortcut unlocked;
- generator repaired.

### ZONE_PERSISTENT
Dungeon macro state survives across relevant rooms.

Examples:
- wing power restored;
- water drained.

### AP_PERSISTENT
Truth belongs to AP transaction state.

---

# 49. FAILURE AND FEEDBACK

When a player fails a mechanism, the game should explain why.

Examples:

- wrong sequence visibly resets;
- receiver rejects incompatible object;
- dead conduit branch is readable;
- timer has countdown;
- door shows unpowered state;
- launch plate indicates inactive;
- jammed mechanism visibly jams;
- reset control is obvious when necessary.

Avoid puzzle failure that manifests only as "nothing happened."

---

# 50. ACCESSIBILITY AND READABILITY

Critical environmental state should avoid single-channel communication.

Do not rely solely on:

- color;
- sound;
- subtle animation;
- tiny text;
- distant particle effect.

Use redundant cues.

Examples:

Active conduit:
- brighter;
- moving pattern;
- directional pulse;
- hum.

Timed state:
- shrinking light band;
- pulse cadence;
- countdown display;
- sound cadence.

A/B switch:
- shape/orientation difference;
- mechanical position;
- pattern;
- optional color.

---

# 51. PUZZLE PACKAGE PHILOSOPHY

Epsilon should not receive a pile of nodes and improvise an unverified puzzle.

Instead, developers author **validated puzzle package families**.

A package defines:

- required objects;
- required sockets;
- logical relationships;
- reachability expectations;
- timing constraints;
- reset behavior;
- persistence;
- capability requirements;
- compatible room offers;
- legal alternate solutions;
- audit criteria.

Epsilon chooses how to instantiate the package in valid authored space.

---

# 52. INITIAL PUZZLE PACKAGE FAMILIES

## 52.1 CARRY_TO_PLATE
Weighted object → plate → output.

## 52.2 INSERT_COMPONENT
Carryable component → socket → output.

## 52.3 PULSE_REMOTE
Button → output.

## 52.4 TIMED_TRAVERSE
Timed input → temporary route/output → validated traversal window.

## 52.5 SHOOT_TARGET
Weapon hit → output.

## 52.6 TOGGLE_ROOM_STATE
Lever → persistent room transformation.

## 52.7 ENERGY_ROUTE
Emitter → routed energy object → receiver → output.

## 52.8 BEAM_RECEIVER
Beam path → receiver → output.

## 52.9 HACK_OVERRIDE
Terminal → signal change / route change / output.

## 52.10 DUAL_INPUT
Two independent valid inputs → AND → output.

## 52.11 ALTERNATE_INPUT
Two or more valid inputs → OR → output.

## 52.12 ROUTE_SWITCH
Input → change rail/conveyor/beam/cargo route.

## 52.13 MOVING_MACHINE
Input → crane/lift/bridge/moving wall changes geometry.

## 52.14 BOMB_BARRIER
Recoverable explosive → tagged bombable target.

## 52.15 ENCOUNTER_GATE
Enemy-clear state → output.

## 52.16 OBSERVATION_TARGET
Player must identify a readable spatial clue and activate the corresponding mechanism.

## 52.17 A_B_STATE
Switch toggles linked architecture between two validated states.

## 52.18 LOCAL_KEY_LOOP
Find local item → return/open gate → create shortcut or progression.

## 52.19 MULTI_STAGE_MACHINE
Validated sequence of several mechanisms.

## 52.20 DUNGEON_STATE_CHANGE
A room action updates Zone-level macro state and validated dependent rooms.

---

# 53. MULTIPLE SOLUTIONS

Alternate solutions are encouraged when they are:

- intentional;
- readable;
- safe;
- and do not bypass progression guarantees accidentally.

A puzzle may support:

- baseline solution;
- Physics Echo shortcut;
- combat-based trigger;
- alternate input;
- traversal capability shortcut.

Emergent solutions are welcome.

But the only valid path may not be a fragile accident.

---

# 54. SEQUENCE AND MEMORY PUZZLES

Supported as package families.

Examples:

- targets in order;
- symbol pattern;
- repeated machine rhythm;
- light sequence;
- sound/light memory;
- rotating-statue alignment.

Sequence failure should visibly reset or indicate the error.

These should not become arbitrary code-entry chores disconnected from the room.

---

# 55. CONTROL PANELS AND SELECTORS

Some machinery benefits from more than binary activation.

A panel may:

- select floor;
- route power left/right;
- choose bridge position;
- rotate machine;
- call platform;
- reverse conveyor;
- choose rail destination.

This is where VALUE/SELECTOR signals are appropriate.

The player should see the physical consequence of the selection.

---

# 56. EMANCIPATION / RESET FIELD

An Archipepsi reset-field equivalent is allowed.

Its purpose:

> prevent temporary or puzzle-specific state from escaping its authored domain.

Possible configured behavior:

- dissolve carryable;
- respawn required object;
- consume energy ball;
- break temporary tether;
- remove temporary construct;
- clear incompatible projectile.

Player passage is normally safe unless the field is explicitly a hazard.

This is not an excuse for invisible walls.

---

# 57. PORTAL / SPACE-FOLDING MECHANICS

Paired portals or equivalent space-folding tools are **not assumed** to be part of the current player kit.

However, environmental teleporters, paired gates, or authored space-folding mechanisms remain legal later.

If introduced, they require:

- camera correctness;
- physics transport;
- projectile transport;
- object transport;
- AI semantics;
- save/load;
- room audit;
- recursive rendering budget where applicable.

This is deliberately deferred.

---

# 58. PERFORMANCE AND SIMULATION BUDGETS

Systemic rooms can become expensive.

Runtime should avoid uncontrolled counts of:

- active rigid bodies;
- dynamic joints;
- continuously simulated projectiles;
- beam bounces;
- moving collision bodies;
- physics-driven debris;
- signal updates;
- path queries.

Puzzle packages should declare practical budgets.

Decorative physics should sleep aggressively.

Required semantic objects should remain stable before being "realistic."

---

# 59. DETERMINISM

Given the same:

- seed;
- room;
- package selection;
- manifest;
- progression state;

environmental composition should be reproducible.

Random decorative variation may exist but must not change puzzle solvability.

Runtime simulation can naturally diverge under player action, but initial state and authored composition are deterministic.

---

# 60. DEBUGGING AND INSPECTION

Developers need to be able to inspect:

- signal graph;
- input state;
- output state;
- reset group;
- persistence category;
- required capability;
- active puzzle package;
- object semantic ID;
- route endpoints;
- timing window;
- movement offer;
- macro dungeon state;
- audit result.

Debug overlays should make invisible semantics visible.

This is essential for procedural content.

---

# 61. VALIDATION

A package is not valid merely because its metadata parses.

Validation should cover the relevant subset of:

- required interaction reachable;
- player fits at interaction point;
- carryable path exists;
- socket reachable;
- object can be recovered;
- timing window feasible;
- launch arc valid;
- rail valid;
- grapple region valid;
- signal dependencies acyclic where required;
- cross-room dependency reachable;
- required capability guaranteed;
- output does not trap player;
- state transitions preserve at least one progression path;
- save/load state reconstructs;
- reset works;
- alternate state is physically valid;
- hazard telegraph exists where needed.

Physical geometry remains final authority for physical claims.

---

# 62. COMPATIBILITY CONTRACTS

System combinations should be explicit.

Examples:

Explosion × breakable:
- allowed.

Explosion × ordinary structural wall:
- no effect unless tagged.

Wind × player:
- package-defined.

Wind × heavy cube:
- maybe no effect.

Water × electricity:
- only if authored behavior exists; do not assume universal conductivity simulation.

Physics Echo × key item:
- may move only if package permits.

Enemy × pressure plate:
- only if plate accepts enemy weight.

Beam × reflector:
- valid if reflector supports beam family.

A compatibility matrix is preferable to hidden ad hoc exceptions.

---

# 63. IMPLEMENTATION SLICES

The complete vocabulary should not be implemented at once.

## Slice 1 — Cause-and-effect foundation

Implement:

- F interact contract;
- generic carryable;
- weighted carryable;
- pressure plate;
- pulse button;
- timed button;
- lever;
- visible conduit;
- DIRECT/AND/OR/TIMER/LATCH foundation;
- powered door;
- shootable target;
- object dispenser/recovery;
- reset group;
- save/load semantic state;
- puzzle-package validator basics.

This already supports meaningful rooms.

## Slice 2 — Transforming architecture

Implement:

- moving platform;
- lift;
- bridge;
- rotating bridge/machine;
- moving wall;
- crane/hoist;
- hazard controller;
- rail switch;
- powered LaunchPad;
- local key/component socket;
- hack terminal.

## Slice 3 — Routed phenomena

Implement:

- energy emitter/ball/receiver;
- beam emitter/receiver;
- reflector;
- moving blocker;
- route switch;
- basic fan/wind.

## Slice 4 — Destruction and environmental combat

Implement:

- destructible crate;
- reactive barrel;
- bomb object;
- bombable surface;
- destructible support;
- environmental kill interactions;
- reset/emancipation field.

## Slice 5 — Media

Implement water foundation:

- swim;
- oxygen;
- buoyancy;
- current;
- safe exit;
- object compatibility.

Then:

- pump;
- fill/drain;
- changing level.

## Slice 6 — Advanced dungeon state

Implement:

- multi-room power/state;
- dungeon macro state;
- A/B architecture;
- persistent shortcuts;
- multi-stage machines;
- cross-room validator.

## Later

Possible later vocabulary:

- smoke/gas/pressure;
- heat/cold;
- advanced fluid routing;
- hard-light bridges;
- tractor streams;
- advanced gravity;
- rotating whole rooms;
- teleportation/space folding;
- sound-triggered systems;
- complex ropes/pulleys;
- programmable logic;
- advanced material interactions.

---

# 64. DELIBERATELY NOT REQUIRED FOR V1

The following are legal futures but should not inflate initial implementation:

- arbitrary programmable circuits;
- unrestricted terrain destruction;
- full electricity simulation;
- full fluid dynamics;
- universal chemistry;
- arbitrary object welding;
- persistent debris simulation;
- portals as a baseline player ability;
- arbitrary gravity direction;
- every surface having elemental properties;
- every object being pickup-able;
- every hazard combining with every medium;
- puzzle generation from unrestricted signal graphs.

Archipepsi needs **strong limited systems**, not an unbounded simulation.

---

# 65. AUTHORING CONTRACT FOR LARGE ROOMS

A LARGE authored shell should be able to expose more than empty space.

Potential offers / sockets include:

- stand regions;
- cover;
- reactive;
- enemy_high;
- access;
- rail;
- launch;
- grapple;
- machinery input location;
- machinery output location;
- conduit route;
- carryable spawn;
- carry path;
- moving-platform corridor;
- crane envelope;
- hazard lane;
- receiver line;
- beam corridor;
- water volume opportunity;
- secret opportunity;
- alternate route;
- reset station;
- dungeon-state control location.

Not every room needs every offer.

The point is that authored architecture can intentionally make room for later gameplay composition.

---

# 66. ART DIRECTION IMPLICATIONS

Environmental gameplay must be readable before final polish.

Art needs reusable visual families for:

- interactable;
- powered/unpowered;
- conduit;
- socket;
- carryable;
- weighted object;
- shootable target;
- grapple target;
- emitter;
- receiver;
- timed state;
- reset control;
- bombable/breakable;
- hazard;
- A/B machinery;
- locked/local-keyed;
- hackable;
- moving machinery.

These should be coherent without becoming giant UI icons glued to everything.

---

# 67. EXAMPLE ROOM: LARGE CRANE YARD

A room similar to `shell_yard_gantry` could support:

- enormous horizontal combat sightline;
- crane moving suspended cargo;
- rail along overhead gantry;
- 60+ metre LaunchPad;
- pressure plate controlling gate;
- shootable target on opposite wall;
- moving cargo as cover;
- generator powering crane;
- conduit visibly crossing the room;
- optional grapple shortcut;
- explosive barrels;
- encounter-clear sensor;
- hidden cache behind movable container.

Same architecture, many possible packages.

The room is valuable specifically because it has horizontal scale.

---

# 68. EXAMPLE ROOM: PLENUM HELIX

A vertical shaft can support:

- long smooth rail;
- descending mandatory route;
- hanging machine;
- powered collars;
- grapple points;
- moving lift;
- falling/suspended loads;
- wind shaft;
- rotating machinery;
- light restored in vertical stages;
- multi-level target chain;
- water or gas rising from below later;
- shortcut activated from bottom to top.

The machine can become a dungeon mechanism rather than decoration.

---

# 69. EXAMPLE ROOM: SPAN BASIN

Two-height route room can support:

- upper deck combat;
- lower recovery route;
- fall changes route instead of causing reload;
- moving bridge;
- water basin later;
- rail crossing;
- grapple recovery;
- launch between heights;
- lower machinery controlling upper route;
- secret under bridge;
- enemy pressure from upper/lower layers.

This is a strong example of failure becoming alternate play.

---

# 70. EXAMPLE DUNGEON CHAIN

A dungeon may create a coherent sequence:

1. Player enters an unpowered wing.
2. Windows reveal a lift and machinery that cannot yet run.
3. Side room contains a local power cell.
4. Inserting it starts a generator.
5. Visible conduits light through several rooms.
6. Security hazards become active, but the crane also becomes usable.
7. Crane moves cargo, opening a traversal route.
8. Player reaches control room.
9. Hack terminal redirects power from security to lift.
10. Lift reaches upper rail junction.
11. Shootable target switches rail route.
12. Rail carries player to a high gallery.
13. Lever permanently lowers a shortcut into the entry room.
14. A later macro-state change drains water from a previously inaccessible basin.
15. Optional secret and AP Check become reachable.

That is a dungeon.

It is not a list of activities.

---

# 71. ACCEPTANCE TESTS

The following tests define the intended quality bar.

## Interaction
1. F operates the intended focused object when several interactables are nearby.
2. Carryable pickup/drop is predictable.
3. Placing an object in a compatible socket succeeds.
4. An incompatible object is rejected visibly.
5. The player knows what F will do in an ambiguous context.

## Signals
6. A plate visibly communicates its output relationship.
7. A conduit state is understandable without relying only on color.
8. AND requires both inputs.
9. OR accepts either input.
10. Timed state visibly communicates remaining urgency.
11. Latch persists according to package semantics.
12. Signal reset restores initial state.

## Doors / topology
13. A powered door opens.
14. Removing power closes safely.
15. A player in the doorway is not silently crushed by a non-hazard door.
16. A persistent shortcut remains unlocked after room revisit.
17. A topology transformation never removes every valid progression route unintentionally.

## Carryables
18. Required carryable cannot be permanently lost.
19. Dropping it out of bounds restores it.
20. Destroying a replaceable required object restores it.
21. Save/load reconstructs its semantic state.
22. A weighted plate cannot be cheesed by meaningless tiny debris unless authored.

## Timed traversal
23. Required timed path is physically feasible.
24. Timing includes reasonable player variance.
25. Failure permits immediate retry.
26. Countdown is readable.

## Weapon input
27. Mandatory shootable target works with guaranteed baseline weapon capability.
28. Invalid hits do not trigger it.
29. Target state is readable at distance.

## Hack
30. Hack can enable an output.
31. Hack can redirect a connection in a package designed for routing.
32. Hack failure does not corrupt puzzle state.
33. Hack interaction can be exited/reset safely.

## Rails / movement
34. Powered rail state is readable.
35. Rail branch switch selects a physically valid route.
36. LaunchPad source/landing remains valid.
37. Grapple target exists within an audited grapple opportunity.
38. Moving platform does not strand required progression.

## Hazards
39. Hazard damage uses common damage road.
40. Hazard telegraphs before unavoidable contact where appropriate.
41. Hazard can affect enemies if package says it can.
42. Hazard controller correctly disables/enables it.
43. Reset restores hazard phase safely.

## Destruction
44. Reactive barrel damages valid actors.
45. Bombable wall responds to tagged explosive.
46. Ordinary architecture does not become arbitrarily destructible.
47. Destructible required support has recovery or alternate progression.

## Energy / beams
48. Energy ball reaches receiver on validated route.
49. Lost ball resets.
50. Reflector changes valid path.
51. Beam receiver responds continuously.
52. Moving blocker changes beam state correctly.

## Water
53. Player can enter, swim, surface, and exit.
54. Oxygen state is readable.
55. Required buoyant object behaves consistently.
56. Drain/fill state restores correctly after save/load when persistent.

## Combat/environment
57. Enemy can be killed by an environmental hazard.
58. Movable cover changes line of sight.
59. Enemy cannot permanently softlock a required plate.
60. Encounter-clear gate opens from authored encounter completion.

## Multi-room
61. Generator state propagates to dependent room.
62. Cross-room state survives unload/reload.
63. Dependency chain remains reachable.
64. Dungeon macro-state cannot create an accidental progression cycle.

## Reset
65. Puzzle reset affects only its declared reset group.
66. Completed AP Check is not undone by puzzle reset.
67. Persistent shortcut is not undone by local reset.
68. Temporary projectiles and signals are cleared.

## Readability / accessibility
69. Critical active/inactive state is distinguishable without color alone.
70. Required sound cue has visual equivalent.
71. A distant controlled output can be inferred from input.
72. Wrong-sequence failure communicates the error.

## Determinism
73. Same seed/package produces same initial composition.
74. Decorative randomness does not alter solvability.
75. Package audit produces stable results.

## Performance
76. Inactive physics objects sleep.
77. Large room does not keep unlimited projectiles alive.
78. Beam routing has bounded complexity.
79. Signal update is event-driven where practical.
80. Debug view can identify active semantic state without inspecting scene internals manually.

---

# 72. CANONICAL SUMMARY

Archipepsi's environmental gameplay is built around a **shared physical and causal grammar**, not a collection of unrelated activities.

The foundational causal model is:

> **INPUT → SIGNAL → OUTPUT**

But the complete level language also includes:

- physical manipulation;
- constrained machinery;
- changing topology;
- traversal systems;
- routed energy and beams;
- liquids, gases, forces, gravity, light, sound, and media;
- destructible and reactive materials;
- hazards that can become tools;
- enemy/environment crossover;
- keys and local dungeon items;
- observation and information;
- secrets and shortcuts;
- room-state transformation;
- multi-room dependencies;
- dungeon-scale state;
- deterministic procedural composition;
- persistence;
- reset;
- accessibility;
- and anti-softlock validation.

The decisive design principle is:

> **Environmental systems should change the player's relationship with space.**

A button is not interesting because it is a button.

It is interesting because it changes a bridge, starts a crane, redirects a rail, powers a launch plate, disables a hazard, floods a chamber, exposes a route, opens a shortcut, or changes the larger dungeon.

Likewise, a room is not interesting because it contains more props.

It is interesting because its architecture, machines, objects, enemies, and state can meaningfully interact.

That is the target.
