# 01 — Owner decisions, continuity and boundaries

## 1. How to read this packet

**OWNER REQUIREMENT:** stated by Skyiah, including specific later approval of a prior recommendation.  
**OBSERVATION:** what the owner experienced; causal diagnosis may still be open.  
**HISTORICAL EVIDENCE:** what a pinned source/report claims, with its environment and scope.  
**PROPOSED IMPLEMENTATION:** a suggested way to satisfy a requirement; not an already-selected public contract.  
**OPEN DECISION:** affects implementation or progression and needs a named resolution.  
**FUTURE DIRECTION:** accepted destination, not authorization to ship all of it in the next repair build.

The earlier rift brief is included unchanged. Its detailed approval labels remain intact. The new menu/map requirements add to that brief rather than pretending they were present in v0.3.1.

## 2. Preserve these successes

The game is more fun. The power-cell journey and the act of seating it are positive owner results. The basic moving-machine ideas are interesting. Audio already distinguishes some threats. Restarting restored the room and placed items in the owner's experience, even though combat restoration was unsafe.

Preserve those gains while changing presentation, reward dependency and unfair behavior. Do not erase the original run or rewrite the old passing tests as if their narrower claims never held.

## 3. New playtest requirements

| ID | Requirement / ruling | Consequence |
|---|---|---|
| U-01 | Controls and what they affect should be colour-coded together: dark-green lever, dark-green door | Share a circuit identity across relevant objects; supplement colour with shape/symbol and actual state |
| U-02 | Pressure plates require pressure | A plate is a live sensor; a permanent opening needs a clearly different latching interaction, not hidden plate memory |
| U-03 | Movement may assist a puzzle, not instantly make the puzzle irrelevant | Test baseline jump first, then actual obtainable movement; protect meaningful outcomes, not a prescribed traversal script |
| U-04 | Reward enclosure/door is preferable to a free pickup on an open platform when the machinery is the puzzle | Investigate the physical and authoritative release boundary; do not add only an invisible software refusal |
| U-05 | New rooms need substantially more tuning, larger/clearer space where useful, and understandable goals | All three selected minors need a room-level review; scale is a tool, not a universal cure |
| U-06 | Inventory should follow the already-built Caster's Guide/BG3-style inventory | Adapt that interaction/layout reference; do not add another filter to the old event-list presentation |
| U-07 | Escape pauses and opens Pause/Settings; page arrows turn through Inventory, Map and Journal | One connected four-face pause system; big arrows; reverse direction supported |
| U-08 | The menu exists in actual 3D space and uses Glyph-made fonts/textures | Real inward-facing 3D panels and live interaction, not a fake tab animation or a static screenshot |
| U-09 | Minimap remains visible; pause menu contains a 3D miniature of the actual dungeon | Map geometry follows the built layout; clear floor/height handling and usable player location |
| U-10 | Large rooms and setpieces have names on both maps, not only IDs such as 014 | Stable internal IDs remain; separate persistent display names; do not rename by replay |
| U-11 | Blocked connectors reflect matching mechanism colours on both maps | Green barrier on minimap connector; small pulsing green indicator in 3D; state follows actual door, not merely item ownership |
| U-12 | Enemies must be visually distinguishable at distance | Different threat silhouettes/weapon placement/motion, not only wider versions or colour changes |
| U-13 | Through-wall artillery and misleading flyer hitboxes are unacceptable | Reproduce and repair targeting/path/blast and visual/collision alignment separately |
| U-14 | Reload cannot turn a cleared room into an ambush around the restored player | Explicit encounter-resume semantics and safe restoration order; ordinary resume is not a hidden encounter reset |
| U-15 | The receiver's tiny z-fighting defect is low priority because its placeholder model will be replaced | Log it; repair in source during replacement; do not divert the repair batch into polishing disposable geometry |

A permanently visible minimap can still be occluded by the full pause screen; the requirement is not that it remain redundantly drawn over every menu. Exact controller bindings, text sizes and transition durations remain implementation choices to measure, not decisions already made by the owner.

## 4. Earlier gameplay direction remains

**0.5:** Each Zone should feel like a Metroidvania + Zelda dungeon + Doom combat + Portal-style environmental reasoning. Large ordinary rooms, large setpieces and small setpieces should combine meaningful aspects of these pillars. This is not satisfied by placing four unrelated minigames together. Quiet introduction and payoff beats are permissible within a coherent situation; do not weaken the direction to four isolated genre-labelled room types.

Hallways and small connector rooms should primarily connect places. They may contain a small traversal opportunity, a horde, a simple mechanism, useful assets, a future underwater route, or a grapple branch. They do not need a dense activity bundle, arbitrary ceiling exit lights or explosive barrels too far from threats to matter. Water is still a separately deferred implementation requirement, not suddenly available because an example mentions it.

Ordinary coloured keys belong to the Zone that awards them. A memorable local matching lock matters. A cross-Zone boss shard is a different category with an explicit named destination. The earlier report of keys without visible doors is a visibility/generation question to inspect, not proof that all current keys are globally scoped.

Enemies need independent activities, perception, relations with allies/rivals and role-appropriate use of the world's objects. Add nonrobot populations in 0.5. Add readable destruction and useful drops instead of simple disappearance. Introduce new setpieces gradually and later expand to whole coherent branches.

**0.6:** Ordinary Echoes remain kept interpretations—guns, mods, armour, abilities and supported equipment. Related or similar-sounding source items may improve an existing Echo or inspire a different one; sharing a primitive alone does not require merging. Temporal Echoes are temporary literal pixel-art recreations independent of AP Checks. Generated companions, side weapons/skins and Echo creatures are the later visual capability expansion, not clothing or house design.

Effects should do something in the world. Preserve the effective Amalgam's exact exceptions and compatibility rules, including the recorded EXPOSED exception; do not convert this preference into an invented claim that no Status can ever affect resulting damage.

## 5. Story is physical, not simulated

Epsilon operates experimental rift transit between designated station endpoints. Scientists thought the intermediate Multiworld empty. Signals were **actual other worlds**; researchers followed different signals and deliberately amplified interference to study them. Unfinished crossings mixed the ship with nearby worlds and stranded transfers. Native creatures found the installation through these disturbances.

The player really entered to steal information, was caught, and was detained in cryo for trial after a return that never happened. Separate custody/evacuation/engineering access explains abandonment and Epsilon's limited knowledge. Emergency revival causes autobiographical memory loss in the fiction. Epsilon and the player want freedom and cooperate.

Epsilon really constructs the route; interference affects its physical realization, not his intelligence. A perfectly isolated transport hallway would not reach the contaminated pockets and stranded items. Cleanup finishes existing transfers rather than generating a fresh unresolved backlog. Contamination does not mean native life is dirty or must be exterminated.

Crossings persist; station anchors and item-transfer anchors have different jobs. Local uploads extend one Epsilon, not unlimited independent copies. The first warp foothold gives local routing among established points; long-range escape is later. Returning to unfinished Crossings is future accepted direction but still requires deliberate AP/lifecycle changes rather than editing an old seed's policy.

## 6. Supersessions to apply narrowly

The new map/menu request supersedes the older prohibition on **new map design** for this newly requested package. It does not retroactively change what Prod was assigned in OV05.

The live-pressure requirement supersedes the step-once plate presentation. Retain generic LATCH and saved permanent consequences for appropriate levers/bolts. Do not globally delete persistence or make existing routes impossible.

The future physical-rift premise supersedes simulation explanations. It does not require a repository-wide rename of `Zone`, nor authorize generated hazards to violate collision/progression contracts under the word “interference.”

Multi-lane work resumes only when the owner resumes it. Prod's temporary solo access to shared schema files during OV05 was authorized; Dess reviews and adopts/corrects it instead of rolling it back merely because Prod wrote it. Arty's new UI/texture role broadens the old “models only” brief for the explicit menu request; it does not give Art authority over gameplay collision or the save schema.

## 7. No false finish line

A good repair candidate is a checkpoint. “All 0.4 is complete” still requires the full accepted Amalgam/deferrals, selected content, earned acquisition/AP integration and documented remaining scope. The 85-unit OV05 inventory is retained, and it is not itself a replacement for every parent-programme obligation. [S02, S04, S10]
