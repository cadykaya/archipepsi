# 06 — 0.5: coherent dungeons, inhabiting enemies and useful aftermath

**Status:** owner direction, organized into proposed future delivery slices. Not an instruction to implement all of 0.5 during the near-term repairs. Original 0.4 obligations retain their original milestone. [S05]

## 1. Room identity: four pillars acting on the same situation

The owner wants each Zone to feel like a Metroidvania, a Zelda dungeon, Doom combat and Portal-style environmental puzzles. Large ordinary rooms and both large/small setpieces should carry several meaningful aspects of those pillars. Do not fulfill this with a combat arena plus three disconnected activities pasted onto its walls.

A useful room asks the player to observe an objective and obstruction, understand the relevant tools/environment, decide an approach, act, see consequences, and retain meaningful access or knowledge. Combat placement, cover, controls, elevation, rewards and exits must participate in that situation. A barrel outside any useful enemy/hazard relationship is dressing, not an encounter opportunity.

**Proposed room brief:** identity/name; first view and destination; obstacle/cause; cross-pillar relationships; guaranteed and optional tools; enemy jobs/positions; meaningful alternate solutions; consequence; local and cross-room state; next visit; recovery; why this particular layout is worth playing. This is a content brief, not a requirement to introduce a giant compiler before building a room.

## 2. Quiet connectors are part of pacing

Hallways and small connecting rooms mostly connect. Give them a simple purpose and at most the ingredients it needs. A short jump challenge, underwater passage in a future supported build, grapple branch, small horde, observation window or uncomplicated mechanism can be enough. Empty space is a valid authored result. Do not compensate for deleting hallway clutter by moving identical chores into every large room to preserve an activity count.

Audit exits and hierarchy: useful route indicators belong at real decisions; a ceiling light should not compete equally with controls, a reward and a return path. A route that revisits a familiar place can be richer than another unique box. Ordinary keys are scoped to the current Zone and have a meaningful local lock/purpose that the map helps remember.

This generator work is 0.5. Fixing the three selected 0.4 rooms does not require rewriting every composer first.

## 3. Build the next scene by changing a relationship

Preserve the selected first content group and improve it before adding a new wave. Proposed first 0.5 demonstration: one substantial room with shared combat/environment/traversal consequences, connected through simple useful corridors to a recognizable return. Compare it against a baseline with the same broad ingredients. Test whether the player can explain a different approach, not just whether a bot takes more frames.

The owner's **blast shield + bomb-drop** concept is a candidate for that slice. Opening the shield releases enemies; another mechanism can drop explosives behind it, turning a risky enclosure into an advantage. Careless shooting/activation may hurt the player, but danger must be readable and governed by real geometry. No unseen rule that punishes a specific arbitrary target. This concept still needs its layout/timing/reset and progression contract before it becomes a commission.

A side-branch tool or earned Echo should change useful possibilities. Deliberate movement shortcuts are welcome when they retain the valued decision. A Check collectible without any meaningful interaction is not automatically an “emergent solution.” Do not protect a puzzle by globally nerfing teleport/double-jump or putting every room in an unexplained anti-ability field.

## 4. Enemies inhabit the same space

Three 0.5 populations form the story basis: **station security/maintenance**, **native Multiworld creatures**, and **looters/raiders/scrappers**. The fourth—pixel-art Echo creatures—is 0.6. Final faction names remain unselected. Different body type, allegiance and combat role are separate concepts.

Begin with a bounded meaningful set of nonrobot roles rather than recolouring the existing ten robots. Every new role needs a visible silhouette, recognizable movement/attack tells, actual perception, a purpose before combat, a response to allies/rivals, a counterplay opportunity, collision aligned with its body, and a drop/death identity. New health/damage/prices remain provisional until measured; a content score is not a measured difficulty percentage.

Existing roles are not thrown away. Preserve good audio and counterplay, correct their unfair geometry first, then give groups relationships. Examples for design selection include cover used to protect a worker, a creature attracted to a noisy machine, a scavenger carrying an object, or security defending a real restricted door. Those are proposals, not a demand to implement all examples at once.

## 5. Perception, interaction and bounded control

Actors act on things they perceive or receive through actual communication. A hidden enemy does not know the player's exact position in another sealed room merely because the player node exists. A faction relationship is not universal telepathy. Two factions already fighting retain their own goals when the player arrives; they do not become one coordinated anti-player team.

Role-specific interaction uses real mechanisms: an eligible enemy presses an actual button, carries or guards an actual object, reacts to a real blast, or repairs a component with an observable effect. An animation alone is atmospheric behavior, not mechanical repair. No actor can operate every object just because a generic interact method exists.

Define permitted tactical changes and protected permanent consequences. Enemies may contest a live switch or obstruct a route; offscreen routines may not erase earned station access or invalidate seed progression. A necessary item displaced/destroyed by an enemy needs recovery preserving identity, not a softlock or duplicate reward.

Prototype noncombat behavior where it tells the player something useful—guarding, servicing, moving supplies, feeding, nesting, investigating. Avoid an expensive all-station life simulator unless actual scenes demonstrate the need.

## 6. Defeat must finish a fight and produce a useful consequence

Robots should visibly break, scatter parts or collapse; flyers and heavy bodies may have different finishes. Organic/interstitial populations need appropriate deaths, not mandatory metal explosions. Make defeat immediately legible, including whether the unit is still dangerous. Ordinary cosmetic explosions do not automatically cause damage. Dangerous death attacks require a deliberate role, warning and counterplay.

Most debris should be visual, pooled/bounded and not block doors, trigger every pressure plate, hide pickups or remain an unbounded physics cost. Specific useful physical remains are possible only as declared gameplay objects with recovery/route implications.

Faction materials are an owner direction; exact recipes and amounts are open. Immediate repair/barrier/resource pickups are proposals, not a finalized table. Each production drop must have a useful supported destination before the game asks the player to collect it. Do not ship meaningless scrap counters as a substitute for an economy.

Use consistent defeat identity for drop eligibility. The same enemy must not pay twice through reload, duplicate kill reports or environmental damage plus player damage. Environmental kills still deserve the appropriate reward. A flyer falling into an inaccessible pit needs a sensible recoverable drop treatment. Consolidate small pickups and permit convenient collection; do not introduce repeated post-fight interaction spam.

## 7. Progression shards are not upgrade currency

Guaranteed intact Multiworld boss shards open **named breachpoints permanently**. They cannot be accidentally spent upgrading equipment and are not rolled as rare loot. Smaller fragments may feed optional crafting. Establishing access does not charge again on every revisit.

Several bosses can exist in one Zone because they accomplish different things: a security custodian grants terminal access, a Multiworld creature obstructs a breach, a raider leader controls stolen equipment. This is not a required boss quota. Any shard/boss requirement affecting AP access must be represented before seed generation. The story cannot justify silently inventing a runtime gate.

Build one chapter dependency graph before expanding this system. Avoid “collect all shards/kill every enemy” as an unselected default campaign goal. Completing transfers cleans the experiment's contamination; killing native life is not by itself purification.

## 8. First station chapter and visual identity

The bounded first narrative chapter accepted in the rift brief is revival → first Crossing → guarded station terminal → local warp routing. Treat the story as context for real interactions, not a separate lore terminal at every doorway. Epsilon's choices and limits should be demonstrated by what he can stabilize, power or explain. Independent inhabitants remain real.

Mixed station/world architecture should combine forms and useful relationships, not merely switch the colour of six house textures. Preserve recognisable station components across foreign influences. Use the now-existing pack identity/resolver, and keep common gameplay signals universal. One coherent subtheme per initial game pack is better than an averaged mash of every setting in its source game.

## 9. Proposed rollout and acceptance

**0.5-A:** one four-pillar situation, quieter connectors, local-key payoff and readable return.  
**0.5-B:** one bounded interacting faction encounter with noncombat behavior and nonrobot participants.  
**0.5-C:** readable death/collection loop with one useful agreed material sink and persistence.  
**0.5-D:** the first station objective and deliberately represented breachpoint progression.  
**0.5-E:** more rooms and then one multi-room setpiece branch only after playing the earlier slices.

These are proposed checkpoints, not separate promised releases. Each is judged by a real continuous journey and human understanding/preference. More rooms, types and green checks are not a substitute for a coherent situation. No new art catalogue count automatically means a finished selectable pack.
