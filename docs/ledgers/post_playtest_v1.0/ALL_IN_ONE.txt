# Archipepsi — Comprehensive post-playtest handoff v1.0

**Prepared 24 September 2026. Planning packet; nothing dispatched or implemented.**

This is the combined reading copy. The ZIP provides modular sections, three lane-specific starting briefs, structured queues and unchanged references. The accepted physical-rift story is preserved in its full original reference alongside this synthesis.



---

<!-- SOURCE: 00_READ_FIRST.md -->

# Archipepsi — post-playtest team handoff
## Repair the experience, preserve the programme, plan the next worlds

**Packet version:** 1.0 • **Prepared:** 24 September 2026 • **Owner:** Skyiah  
**Audience:** Prod, Dess, Arty • **Mode:** planning and handoff preparation; no agent dispatched and no repository changed by preparing this packet.

## The outcome we are protecting

The owner says the game is **a lot more fun**. Carrying the power cell and installing it in its receiver was particularly satisfying. Enemy audio helped distinguish threats. The machinery concepts are worth keeping.

The same playtest exposed unfair attacks, misleading enemy bodies, unsafe resumption, puzzle rewards that bypass their puzzles, unclear controls and goals, and an inventory that prevents the player understanding their own equipment. These are findings about the player's experience, not instructions to discard the working systems.

This packet brings together three different bodies of work:

| Track | What belongs here | What must not happen |
|---|---|---|
| **Near-term repair + interface package** | Combat/resume defects; selected room corrections; pressure/control semantics; actual 3D pause menu, equipment and map; reward visibility | Calling this only cosmetic polish, or claiming these changes finish all of 0.4 |
| **Inherited 0.4 completion** | Full accepted Amalgam and existing commitments, including the still-unearned Blindside loop and runtime-only systems awaiting delivery | Quietly moving unfinished 0.4 requirements to 0.5/0.6 |
| **Future 0.5 / 0.6 design** | Four-pillar dungeons, inhabiting factions, death/drop systems and station chapter; later generated visual Echoes, Temporal Echoes and workshops | Starting the whole future programme merely because it is documented |

The UI/map work is explicitly requested new scope. Its **release number is unassigned**; it must be planned and delivered as a named package, not omitted because an older order excluded map redesign. The broad room/generator overhaul remains 0.5. Documents are not evidence of implementation.

## Start here, by lane

**Prod:** read `dispatch/PROD_START.md`, then the relevant entries in `02_PLAYTEST_FINDINGS.md` and `03_DELIVERY_PLAN.md`. First execution slice, once resumed: preserve the reference and capture the unfair combat/resume failures. Do not start with a full suite or a new world generator.

**Dess:** read `dispatch/DESS_START.md`, then `09_CONTRACTS_AND_DECISIONS.md` and the inherited queue. First slice: reconcile Prod's authorized shared-seam edits, issue the narrow resume/pressure/reward/map contracts needed by the repairs, and advance the remaining acquisition decisions without inventing AP guarantees.

**Arty:** read `dispatch/ARTY_START.md`, then `04_3D_MENU_MAP_AND_GLYPH.md` and `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. First slice: one usable Glyph visual system for the inventory/control/map cues and one distance-readable enemy lineup, not seventy-four more unfinished packs.

Everyone receives **the same packet**. Each reads only the relevant contract/source when needed. Do not spend the reset rereading every historical document or reproducing the full 64-step baseline three times.

## Reference revisions and evidence

The review reference is `cadykaya/archipepsi` branch `claude/archipepsi-0-4-blindside`, handed off at **`a7456373fc76d1c4f8148ccd6b1c6c0beb0eab70`**. This ref was checked while preparing the packet. Prod's frozen local run was **`46bf023`**, 64/64 command steps, approximately 65 minutes, with 2,103 Python tests reported, 46 headless Godot suites and 11 live suites. The handoff above adds documents and the test-generated capture provenance, not gameplay code. [S01–S03]

Those are **Prod's reported Linux results**, not runs performed for this handoff. The owner subsequently played on Windows; the exact local commit/save digest for that session has not been independently verified here. Do not use an older uploaded save to decide whether tonight's candidate contained bombs.

Arty's preserved delivery is **`4093ded`**. Glyph's inspected newer tooling ref is **`87db9e20dd0c7cb1a1f7a3c617a47d5efa3526de`**; her previous authoring baseline was **`6c80b63`**. A new menu built with Glyph is an owner requirement, not permission to migrate every old art project. [S06–S08]

## Authority and execution

Direct owner feedback and later explicit rulings govern the requested change. They do not erase the record of what an earlier test proved. Preserve both: **historical technical status** and **new owner-review disposition**.

This packet is not a blanket approval of proposed API shapes, prices, migration behavior or future story choices. Owner requirements are labelled; engineering recommendations and unresolved choices are labelled separately. When Skyiah actually resumes a lane, that lane proceeds through its authorized, ready tasks and does not stop after one small integration. It stops at a real blocking decision, resource limit, owner stop instruction, or the chosen delivery checkpoint, with an exact remainder.

No heartbeat, background watcher, PR subscription, scheduled wake-up, or automatic 5 p.m. launch is authorized. The reset time is the owner's reported availability window, not a task scheduled by this packet. No purchases, model-key acquisition, tool-PR merge, artwork approval, default promotion, or original-save migration is implicit.

## Reading map

`01` records decisions; `02` preserves the playtest; `03` sequences delivery; `04` specifies the requested UI/map; `05` retains all 85 prior queue units; `06–08` preserve future gameplay and story; `09` defines contract/decision handoffs; `10` defines proof and review; `11` reconciles tools/art; `12` is the source register; `13` is the executable work inventory. `references/` is unchanged source history, not an instruction to execute every old order again.


---

<!-- SOURCE: 01_OWNER_DIRECTION_AND_SCOPE.md -->

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


---

<!-- SOURCE: 02_PLAYTEST_FINDINGS.md -->

# 02 — Playtest record and repair tickets

**Basis:** Skyiah's direct feedback in this conversation. Room identities are associated where recognizable; unclear identities remain unclear. The reference branch is `a745637`, but the exact played local SHA, save and runtime logs were not captured for this consolidation. A source-based diagnosis is not a reproduced live failure.

## Summary

| ID | Observation | Review disposition | Main lane / support |
|---|---|---|---|
| PT-01 | Remote lever made sense only when its door was visible | Works; relationship unreadable | Prod / Arty, Dess |
| PT-02 | Carrying and seating the cell was very cool | Preserve gameplay; replace placeholder later | Prod / Arty |
| PT-03 | Step-once plate works but violates what a plate should do | Owner rejects behavior/presentation | Dess + Prod |
| PT-04 | Possibly two Counterfires; shot a target, emergency door opened, took Check | Identity/main-route understanding unconfirmed | Prod / Arty |
| PT-05 | Unweighted appeared twice, goal unclear, very slow carriage, directly collectible Check | Rework selected room; preserve property idea | Prod / Dess, Arty |
| PT-06 | Passing machinery interesting, but neither problem nor solution readable; pickup directly reachable | Rework room goal, reward and controls | Prod / Dess, Arty |
| PT-07 | Passing branch end had no recognizable return except random teleport | Urgent escape-path investigation | Prod / Dess |
| PT-08 | Echo menu miserable; already better reference in Caster's Guide | Replace interface, not incremental list polish | Prod + Arty / Dess |
| PT-09 | No bombs found, or no bombs noticed | Acquisition versus discovery unresolved | Prod / Dess |
| PT-10 | Audio distinguishes threats; visually too similar, artillery a wider other robot | Keep audio; distinct distance-readable silhouettes | Arty + Prod |
| PT-11 | Bombardment attacks through walls and from other rooms | Unfair combat; targeted repair | Prod |
| PT-12 | Flyer hitbox above visible body | Align presentation and damageable volume | Prod + Arty |
| PT-13 | Flyers seemingly do not attack | Identify actual role and state; do not assume all roles broken | Prod / Dess |
| PT-14 | Navigation okay but needs always-on minimap/3D pause map | Explicit new map package | Prod / Dess, Arty |
| PT-15 | Earlier Zone yielded keys without noticed matching doors | Audit local payoff/visibility; not proof of global key scope | Dess + Prod |
| PT-16 | Reload restores room/items but respawns enemies around player | Urgent resume defect | Prod + Dess |
| PT-17 | Controls, models and common textures blend together | Functional art/readability, not only decoration | Arty / Prod |
| PT-18 | Overall game more fun | Preserve as positive result, not a blanket acceptance | All |

## 1. Controls and the successful cell journey

**PT-01 — visible cause and effect.** The owner noticed the lever's meaning only when it opened a door they could see. Dark-green lever/door is the owner's example. Give related controls, equipment and map barriers a shared circuit identity. Labels name the action and destination; symbols distinguish a power circuit from a key lock. Pending, accepted, refused, moving, blocked and completed must not look identical. A lamp is supplemental evidence, not a substitute for understanding which door moved.

**PT-02 — keep the cell insertion.** The receiver's yellow box clips/z-fights with nearby geometry. The owner explicitly deprioritized this because the whole placeholder model is to be replaced. Preserve actual pickup/carry/install, wrong-object refusal, object uniqueness and saved installation while replacing its art. Do not manufacture a much longer carry quest just because the short delivery was liked. This observation validates enjoyment of that interaction, not every carry edge case.

## 2. Pressure is not memory

**PT-03 — design revision, not broken code.** The old plate→LATCH route intentionally kept the shutter open and its tests correctly measured that behavior. The owner does not want an ordinary pressure plate to work that way. Proposed narrow repair: use a visibly latching lever/bolt for a permanent opening; use a genuinely held plate where the local weight arrangement is solvable. Preserve the general graph and latch persistence.

Do not solve this by silently retaining a four-second linger, renaming a pressure plate “plate,” or deleting the latch while requiring one player to hold it and walk through a distant door. Revalidate all affected route predicates, guaranteed bodies, recovery and closure safety. Existing old saves must not become unreadable because a new content validator disapproves their original declaration.

## 3. The three selected minors

**PT-04 — Counterfire needs identity and route review.** The owner is unsure that the remembered room was Counterfire. A shot target opened emergency access with a Check, after which they left. This is not enough to declare the gunner route broken or their alternate solution invalid. Inspect the committed instance and declared alternate release. Determine whether the emergency target was the intended kill-first fallback, an unrelated activity, an accidentally exposed control, or a bypass. Preserve legitimate alternate solutions. The room must show what the gunner, receiver, shutter and reward have to do with each other.

**PT-05 — Unweighted is currently optional machinery around a free reward.** The owner encountered it twice, saw an indestructible crate moved very slowly by a lever, did not understand the goal, and walked to the Check. Test the host's actual pickup interaction as well as the local scenario. Protect the property conflict: the same crate can be useful as a step and unhelpful as a sensed weight. Make the shutter/reward relationship readable and real. Faster movement alone is not the repair; arbitrary minimum waiting is not puzzle depth. Show guided-service hardware rather than an apparently ordinary breakable box when indestructibility is intentional.

**PT-06 — Passing needs a meaningful destination.** Test baseline walking/jumping and pickup range before advanced movement. The owner initially blamed movement powers but then found they were not required. Protect a real machinery-operated release condition, not a fixed input sequence. Glass and room scale are possible spatial tools, not automatic fixes. Check visual material separation, control grouping and action labels at the arrival camera. Quiet puzzle-only space is not automatically a defect; adding a horde does not explain an unreadable control board.

**PT-07 — escape from the player's route, not just the authored route.** Reproduce the return after direct pickup, early gallery entry, carrier displacement and normal completion. Confirm whether the return stair/connector was absent, blocked, untriggered or illegible. A teleport-only recovery is not an ordinary return unless that ability was explicitly guaranteed. The map cannot repair missing geometry. Preserve an intelligible physical way back or an explicitly signposted valid return device. Do not silently remove the parent fight or its reward identity to make a host easier.

**Repeated appearances:** two Unweighted sightings and possibly two Counterfire sightings are owner observations. It is not yet established that these were duplicates in one Zone rather than across Zones or visually similar spaces. Record occurrence and Zone IDs on the next capture. Do not impose a global no-repeat rule based only on this recollection.

## 4. Inventory and bombs

**PT-08 — equipment, not history-first archive.** The owner wants the Caster's Guide/BG3-like item-grid reference with visible equipped build, not an improved version of the current miserable list. No current Echo-menu screenshot was provided; use the actual build and reference implementation rather than inventing the screenshot. The requested real 3D Glyph-built shell is detailed in `04`.

**PT-09 — unavailable versus unnoticed.** Query the matching current candidate's interpretations, folded collection, slot assignments and acquisition events in a copy of the actual save when available. Then test normal claim→creation→inventory→equip→authorize→launch→count→zero/refill feedback. Keep normal delivery distinct from a fixture injecting a Bomb Bag. Do not use the old schema-8 uploaded playtest save as tonight's source, and do not assume that adding a free bomb proves discoverability. Prod explicitly did not claim a live naturally acquired bomb at the handoff. [S02]

## 5. Combat defects and visual identity

**PT-10 — audio works better than silhouettes.** Keep useful sound cues. Arty's lineup must make threats obvious across a normal arena without audio, captions, collider overlays or isolated studio lighting. Different widths alone do not suffice. Compare all existing roles with their actual colliders, muzzle positions and intended animation poses.

**PT-11 — artillery.** Earlier source inspection in this conversation found target selection without direct sight, position-driven shell arcs without world-path collision, and distance-only blast application. That is a strong diagnostic lead, not a fresh runtime reproduction by this packet. Reproduce all three separately. Indirect fire may cross legitimate openings or low cover; it may not pass through intact walls/ceilings or damage through blast-blocking architecture. Do not impose an invisible room-ID force field as a substitute for physical occlusion.

**PT-12 — flyers.** Earlier source inspection found role-specific collider centres alongside ground-style visual fallback construction. Use this as a lead. Compare visible body, collider, hover transform, hit point, muzzle and apparent facing through actual game-camera shots. A test aiming at an internal centre can be green while the player aims at a different visible location.

**PT-13 — attack behavior is a separate question.** Identify diver versus drifter and actual role preconditions. Log perception, holds, target state, attacks launched, impacts and cumulative damage/deaths. The previous “zero damage” diagnosis was once caused by reading HP after respawn; do not repeat it. A role intentionally waiting for an airborne target needs readable behavior, and its placement must give that specialization a purpose. An idle-looking specialist is not automatically a broken ranged attacker.

## 6. Maps and safe continuation

**PT-14/15 — navigation should externalize what is already discovered.** Keep names, real connector paths, elevation, current player location and matching barriers consistent. The requirement is a real miniature map, not only labelled boxes. Owned power supply does not imply powered/open door. Unknown barriers remain unknown rather than exposing their unseen solution. Local keys need local matching payoffs; inspect declaration, actual realized locks and already-open state before declaring a generator fault.

**PT-16 — resume failure.** Restored player + reset population is an unsafe combination. Proposed resolution is preserving defeated encounter members on ordinary quit/reload and restoring world facts before enemies can perceive or attack. Explicit death/reset rules remain separate. Older saves may lack per-enemy facts; absence does not mean all enemies were defeated. They need a safe compatibility plan, not guessed clear state or silent save replacement.

## 7. Information still missing—not homework before repairs

The played save/digest and exact local SHA; exact instance IDs for repeat rooms and the confused Counterfire; a video or frame of the actual flyer; a menu screenshot; the pickup path used for each bypass; whether the return existed but was concealed. These refine the reproductions. They do **not** block acting on the named requirements or preparing a targeted candidate that collects this evidence automatically.


---

<!-- SOURCE: 03_DELIVERY_PLAN.md -->

# 03 — Delivery plan and dependencies

## 1. A sequence of playable checkpoints, not one enormous merge

**Proposed execution order:** preserve → unfair combat/resume repair → selected-room correction → complete one real 3D equipment/map slice → finish the dedicated interface → continue ready inherited 0.4 work. Future 0.5/0.6 remain designed queues until explicitly activated.

This is not a promise of hours or completion by a reset. Each checkpoint has a playable result. Independent Art and bridge work can proceed while a runtime test runs, but nobody edits the same files a sabotage or frozen verification is exercising.

| Checkpoint | Player-visible result | Evidence needed before handoff |
|---|---|---|
| **CP0 — reproducible reference** | Existing candidate stays launchable; exact repair baseline and save copies retained | Branch/profile/provider printed; read-only reproductions; unchanged original saves |
| **CP1 — fair combat and safe resume** | Walls provide real protection, flyer bodies match hits, reopening does not respawn a cleared ambush | Actual room encounters, partial/full clears, two-process restart, normal game-camera aiming |
| **CP2 — understandable, consequential rooms** | Three selected minors have recognizable goals, meaningful release conditions and safe returns; pressure/control cues agree | Baseline and movement-assisted journeys, valid alternate solutions, no reward-through-wall shortcut |
| **CP3 — real 3D equipment slice** | Escape pauses into a rotating four-face scene; equipment face uses Glyph assets and real owned items | In-engine render, mouse/keyboard interaction, one real equip/refusal, paused live world and safe return |
| **CP4 — complete requested interface** | Inventory, persistent minimap, actual 3D dungeon map and useful journal operate as one system | Actual names/gates/current data, rotation/zoom/drag/input tests, reload, resizing and owner usability |
| **CP5 — next 0.4 capability checkpoint** | A selected still-missing capability becomes genuinely obtainable and useful; inherited progress continues | Contract + runtime + delivery + pre-seed proof where needed; no enum-only or fixture-only promotion |
| **CP6 — frozen review candidate** | One clear build with route, answers and exact remaining scope | Focused development checks, then one fixed-revision frontier and human-facing review evidence |

CP1 can be delivered before the whole menu is finished. CP4 is not “0.4 complete.” CP5 can have several useful increments, but no checkpoint silently deletes the remaining parent scope.

## 2. First shared seams: answer only what the next real consumer needs

Dess and Prod first agree narrow contracts for:

**Encounter resume:** stable enemy/encounter identity, defeated membership, authoritative recording, restoration order, old-save absence and explicit reset domains.

**Reward release:** what actual mechanical state makes the existing allocated Check accessible; which declaration represents that gate; what is visually blocking it; which alternate solutions are valid; how return is guaranteed after every accepted arrival/claim route.

**Pressure versus latch:** pure live sensing; explicit permanent release; declared player eligibility/mass; recovery and route reachability when a player must leave a plate.

**Map facts:** stable room/connector/control IDs, display names, circuit identity, discovered information and real blocking state. Both maps consume one projection rather than each computing a second version of progression.

**Inventory presentation:** a view of the existing fold, equipment and authority—not a new inventory backend. Items have stable identity, current resolved behavior, compatible slots, actual binding names, remaining charges, pending/refused state and optional source history.

These seams are delivery records, not permission to invent final field names by writing them in this packet. Each must land with its real producer, consumer and focused tests. Pure appearance work can continue on fixture data while a contract is settling, but cannot be called live integration.

## 3. CP1 — unfairness first

### Combat

Start from a controlled two-room/ceiling/doorway scene that reproduces the artillery complaint. Separate target knowledge from path feasibility and damage occlusion. Preserve legitimate arcing fire while preventing collision tunnelling and blasts through intact blocking surfaces. Include an open aperture positive control so the repair does not become “artillery never attacks.” Keep enemy attacks paused during build/restore holds.

For flyers, use ordinary player-camera shots at visible silhouettes. Inspect the actual transform chain rather than compensating in the bot aim. Align rendered body, collider, muzzle and hover origin without secretly widening every hitbox until a single ray passes. Then separately test the role's attack preconditions against a stationary ground player, a moving ground player and an airborne player as appropriate. Preserve the already-earned Bulwark normal-arrival counterplay evidence while touching shared enemy code.

### Resume

Do not infer cleared enemies from a claimed Check: a player can kill before collecting, collect via an alternate route, or partially clear an encounter. Proposed resume state records defeated members by stable identity and restores them before perception/attacks activate. Duplicate reports must be idempotent. Defeated enemies cannot farm another kill/drop after a restart. The later drop system depends on this distinction.

Do not serialize arbitrary engine node paths or save every internal AI timer as a first move. Reuse existing campaign progress and declared encounter identities. If remaining live enemies must reset to their start positions, explicitly protect the resumed player and agree that fallback; do not place them around an unchanged player location and call it an exact continuation.

Old saves without sufficient encounter facts require a transparent safe-resume policy. Make copies; do not reset the owner's campaign, assume missing means cleared, or migrate legacy saves without a chosen contract.

## 4. CP2 — the meaningful-room contract

Every selected minor needs a room card containing: **arrival read; visible objective; actual obstruction; useful controls/tools; meaningful mechanical state; valid alternate solutions; unavailable cheap bypasses; reward transition; return route; reset/reload behavior.** One room card, not a new universal situation compiler.

A pickup placed behind an enclosure must agree with the actual claim interaction. Test pickup radius, line of interaction, teleport target legality, gaps in glass, projectile reach, elevation and collision—not only walking reachability. Do not gate by a secret completed-input sequence while leaving the reward visibly accessible. Do not require an arbitrary wait or full lever choreography after the player has already achieved a valid state.

**Passing:** make the gallery/release relationship understandable; test whether a visible machinery-locked cabinet or a destination mechanism is the right objective. State that proposal before rebuilding. Group lift and shuttle controls, communicate call/reverse/hold, tune necessary travel rather than stretching the room indiscriminately. A baseline-jump bypass is a first-order failure. Preserve an actual return after both intended and accepted alternate access.

**Unweighted:** preserve the dual-use crate's collision-versus-class insight. Make the blocked upper route and goal legible from a useful view. Remove incidental rail/geometry/pickup bypasses, provide appropriate causal feedback and reduce pointless waiting. A local applicator should show what property changed. Retain the far hold-open release with a readable purpose and safe return. Model changes must not imply a breakable ordinary crate when its role is a guided service body.

**Counterfire:** identify the owner's instance first. Keep the source enemy, receiver, timing window and permanent service release as one understandable relationship. The kill-first fallback may be legitimate; confirm it before removing it. Show the indirect solution without printing a step-by-step answer on entry. A dead gunner must not permanently strand the reward.

**Step-once passage:** replace the misleading pressure interaction with a visibly latching control, or redesign the held-pressure arrangement with a guaranteed usable weight. No hidden plate linger as a cosmetic disguise. Reuse the graph and saved consequences.

**Cross-room lever/cell:** preserve functionality and the liked insertion. Apply circuit markers and clear source/destination naming. Keep physical occupancy protection and domain-correlated pending/refused feedback. Replace visual assets only against tested dimensions and interaction clearances.

## 5. CP3–4 — parallel work without separate incompatible menus

Prod builds the isolated 3D shell, page routing, paused input and real read model. Arty supplies the first coherent Glyph panel/font/icon family. Dess supplies the minimum map/discovery/gate and inventory-view meaning from existing authority. Integrate **one real equipment face first**, then apply the same shell to the map and journal. The blank other faces are an explicitly incomplete slice, not a final delivery.

Make minimap and 3D map share room names, discovered topology, circuit IDs and current gate state. Create render-only geometry from the accepted built layout. Do not make each map infer locks from colours or spawn a second dungeon. The journal can start with actual current objectives, known controls and earned discoveries; do not fabricate finished campaign lore or reveal unseen Check contents.

Do not stall all UI behind the expensive character model. A clearly provisional preview can be used to evaluate live inventory layout, while the finished art remains an open criterion. Likewise, a placeholder font can unblock an input prototype but does not satisfy the Glyph-authored final requirement.

## 6. Continue the inherited queue rather than restart it

`05_INHERITED_0_4_QUEUE.md` preserves all 85 OV05 child IDs. `O05-08.1–.4` already have runtime-only evidence: do not rebuild the twelve verbs just to obtain new counts. Their missing delivery/grammar path is the work. Graph and Status support grows only with real consumers. The full accepted Amalgam remains the destination; the runtime-only boundary is not a reason to stop permanently.

The self-addressed-Check direction has since been accepted at a high level. Dess should implement its exact contract rather than re-ask whether it may exist. It does not discharge qualification or the pre-seed AP gate. Blindside still needs its earned branch → actual featured function → useful return → restored span → AP-safe access, not a walking bypass or injected superpower.

## 7. Working discipline and coordination

**Proposed ownership:** Prod integrates gameplay/runtime and owns final frozen verification; Dess owns shared schemas/progression/fold/save contracts; Arty owns editable art/assets and their manifests. Shared files have one active writer. Each lane uses its own changes/branch/worktree and merges reviewed deliveries by revision; nobody force-resets another lane to an old reference.

Contracts should state what is sent, what is read, what persists, what refuses, and how to demonstrate it. A lane may revise a proposal before the other consumes it; after consumption, version the change and provide both halves. Use lane-prefixed finding IDs instead of three people racing to assign the same next F-number.

No recurring status messages while tests run. Compile/precondition checks first, focused suites during development, meaningful integrated runs at checkpoints. One live/sabotage runner at a time when it touches shared source or ports. Preserve logs and source checksums; after interruption, inspect for an un-restored sabotage before committing. An incomplete verification is not an excuse to claim a pass, nor a reason to bury a useful clean implementation checkpoint.

A delivery receipt has: revision; playable difference; exact verification; owner-review status; known limitations; next ready child. It does not repeat the whole session transcript.


---

<!-- SOURCE: 04_3D_MENU_MAP_AND_GLYPH.md -->

# 04 — Real 3D pause interface, equipment and spatial memory

## 1. Owner requirement

The menu exists in **actual 3D space**, uses **Glyph-authored fonts and textures**, and follows the owner's inside-of-a-box presentation. Escape pauses the game and opens Pause/Settings. Large left/right arrows rotate between four inward-facing pages. Left proceeds Settings → Equipment/Inventory → 3D Map → Objectives/Lore/Story → Settings; right reverses it.

This is not a static screenshot on a rectangle, an exterior cube viewed from outside, a scale-to-zero tab animation, or a long equipment event list with a 3D frame around it.

## 2. Reference to reuse, not misrepresent

`cadykaya/Caster-Guide-to-Fishing`, inspected at `a0eb2e4328dcc92ad8ae4856711691055b2faca3`, contains `scripts/ui/game_menu.gd` and `scripts/ui/inventory_slot.gd`. The implementation explicitly describes a BG3-style inventory and builds equipment around a character preview with a six-column bag grid, selected-item information, comparisons and drag-related handling. It pauses the game and cycles tabs. Its page animation is a horizontal squeeze, **not the requested inside-box rotation**. This packet does not claim the reference was rendered or usability-tested here. [S07]

Reuse the interaction/layout lessons and appropriate independent components. Do not port fishing-specific slots, bait, rods, class mechanics or a second save/fold backend into Archipepsi. Bind to its actual supported slots and item identities. Check the source licence before literal code reuse; an original adapted interface is always separable from copied implementation.

## 3. Proposed runtime architecture

Use a dedicated menu scene with its own controlled camera/render world, four inward-facing panel surfaces and real transforms. It is isolated from the dungeon's walls, lighting, combat physics and field of view. Ordinary UI controls can render to textures displayed on these real 3D surfaces; the information and click targets remain live. Equipment and map previews can have depth behind their panel frames.

Godot's viewport model supports rendering to textures and separate 3D worlds; SubViewports do not receive input automatically in every embedding. Its official GUI-in-3D demo is a starting reference for forwarding input. Confirm compatibility with the project's pinned Godot 4.5.1; do not upgrade the engine to copy a current demo. [S11–S13]

**Proposed division:** Godot owns geometry, camera, rotation, input, text, state and miniature layout. Glyph owns font glyphs/metrics, panel materials, nine-slice borders, item/circuit/map icons, arrow art and state artwork. Dynamic names, descriptions, amounts and binds are never painted into a whole-screen image.

At rest, the selected page faces the camera squarely and fills a readable area. Perspective should sell the turn, not shrink outer columns. The exact angular easing, camera distance, panel resolution and duration are measured choices, not prescribed numbers here. Offer a reduced-motion transition while preserving the underlying 3D scene and page order.

## 4. Pause is a world boundary, not an input hold

**Owner requirement:** gameplay pauses. Proposed policy: the dungeon, AI, projectiles, physics machinery, cooldowns and temporary gameplay-effect lifetimes stop advancing; menu animation and its previews continue. The external AP world is not paused—keep the connection and legitimate incoming delivery alive.

Godot documents that paused physics/process modes and signals are different: signal callbacks can run even when normal processing stops. The implementation must therefore audit callback-driven launches, deferred input, timers and bridge snapshot effects, not simply set a flag and infer the entire transaction is frozen. Do not re-enable the whole gameplay physics server just to make a menu ray test work. Use appropriate menu input mapping or isolated geometric picking. [S11]

Specific race to test: the player requested consumable authorization, then paused before the response. The accepted charge is not silently refunded, and its effect is not launched into a frozen world without an agreed policy. Preserve/reconcile the pending authorization through pause, disconnect and resume using the existing D-9 accounting. Closing the menu must not turn the click that selected an item into a grenade throw.

Use ownership-aware pause/input holds so closing one menu cannot release a layout/restore hold. A modal error, equipment picker, text field or binding dialog must not accidentally unpause. Opening/closing should preserve the intended mouse mode, focus and selected page context.

## 5. Equipment face

Three visible regions form the starting layout: **equipped build**, **owned-item grid**, **selected-item detail/comparison**. Fit them to actual supported data, not a fantasy slot count. Show readable icons, item names where needed, equipped/new markers, quantities and current resolved upgrade identity. Clicking a compatible equipment slot can filter or highlight its candidates; it does not hide the entire inventory with no way back.

The grid represents current owned items/components. Upgrade-only source events belong in history associated with the resolved item, not as fake additional equippable objects. Mixed Echoes with active and passive components need explicit component presentation without silently dropping either side. Passive does not automatically mean user-toggleable. Preserve source-owned modifiers and existing fold rules.

Selected-item information answers: what it does; activation/binding; target/usage restrictions; supported slot; actual cost/cooldown/charges; differences from equipped; why an attempted equip is refused. Detailed source history can expand after the useful summary. Keep pending/refused/accepted equipment changes correlated to the real authority rather than optimistically painting a success that never arrived.

Bombs need an obvious consumable slot and current binding, remaining uses and zero state. Distinguish **none owned**, **owned but not equipped**, **equipped and empty**, **pending authorization**, and **disconnected**. Natural acquisition should draw attention to the actual new item without blocking the AP transfer on an animation. Capacity upgrades and refill rules remain separate decisions.

Support mouse click, keyboard/controller navigation and a usable non-drag equip action. Drag-and-drop may be offered, but it must work while paused, preserve identity during a snapshot refresh, and cancel safely on page turn or close. Search must not trigger Q/C or movement. Use real binding names, not separately hard-coded keycaps. A direct Tab-to-equipment shortcut is a recommendation, not an owner-specified requirement.

## 6. Map facts: one projection, two views

Keep immutable room, edge, gate and mechanism identifiers for code/saves. Add or reuse stable display names for large ordinary rooms and setpieces. Both maps and relevant objectives show the same names. If a setpiece repeats, attach a meaningful location qualifier; do not randomly rename it on reload. Debug IDs can be available to a report tool without being the principal map label.

Build the map from the **accepted realized layout**: actual room envelopes/geometry, connector chains, vertical changes and meaningful passage openings. The overview graph alone can misrepresent a turning 76-m connector as a straight line; the map must not repeat that old traversal-harness error. A miniature should preserve enough real shape to recognize rooms while removing decoration that obscures navigation.

A shared read model supplies discovered room/connection identities, player location/facing, known gate state/reason, circuit identity, known terminals and objective references. Presentation colours are not permissions. A local map can display authoritative updates but cannot grant access or change progression by editing its copy.

**Green circuit example:** green supply → green receiver → green door. The minimap draws a green blocker on the connector through that door. The 3D map draws a small pulsing green indicator at that passage/area. If the player merely owns the supply, the barrier stays; after installation, it changes only when the real passage state changes. A jammed, closing or unknown passage is not silently labelled open. A reversible closure reappears correctly. An accepted permanent opening survives re-entry.

Supplement colour with reason symbols and readable details: key, power, mechanism, blocked/unsafe. Two unrelated circuits in one place need distinct identity even if colours are reused elsewhere. Do not reveal undiscovered control locations or hidden Check contents as a side effect of the map's access to complete generation data.

## 7. Minimap and 3D map interaction

The minimap stays visible during normal exploration/combat. Show position, facing, nearby actual connectors, useful known markers and an unambiguous floor/elevation convention. Do not cover the action with long labels; full names/details can appear on focus or the large map. “Always visible” does not require rendering it over the full pause map.

The map face contains a rotate/zoom/pan miniature. Offer cutaway roofs or selected-floor isolation so stacked rooms remain readable. Recenter on the player, distinguish current from other floors, and preserve useful inspection state through page changes. Mapping controls must not compete with the page-turn arrows. Known destinations and return routes should remain inspectable without spoilers.

Use **render-only** map geometry/resources. Never duplicate live scripts, collision, enemies, reward nodes, sounds or state setters into a small copy. Opening the map must not send a second Check, run a room `_ready` side effect or create another machine simulation. Cache appropriately and measure with a representative built Zone, not only an empty five-room mockup.

## 8. Journal and Settings faces

Journal initially lists real active objectives, completed consequences, discovered named places and appropriately earned notes. It can organize future lore/story, but the near-term delivery must not invent a finished campaign or spoil unvisited rewards. A control's recorded discovery can remind the player which door it affects; it should not reveal an undiscovered solution.

Settings includes resume, current campaign/profile information and supported options. Separate **return to Hub**, **abandon current Zone**, **quit**, and **new campaign** wherever those existing actions are offered. Destructive actions need their existing confirmation and accurate consequences. Do not change the all-Checks/abandon policy through a prettier button label.

## 9. Glyph asset handoff and visual floor

Use the inspected tooling branch in an isolated checkout for new sources. Read `AGENTS.md` and `GAME_ASSETS.md`; discover actual commands rather than infer them from an old guide. The documented relevant exports include bitmap-font `.fnt`, nine-patch panel blocks and SpriteFrames. These export resources/metadata; they do not create menu input or 3D geometry. The guide's font test names Godot 4.3, so the actual new import/interaction trial must use the project's 4.5.1. [S08]

Supply editable Glyph source identity/revision, exported asset paths/hashes, palette and metrics, states, atlas/region mapping, exact `res://` references and a consumer screenshot. The project receives assets through its normal versioned pipeline, not by runtime guessing filenames. No opening/checkpointing original approved `.glyph` files in an upgrade trial; work on copies, because Arty's trial recorded writes during opens/verifies.

Make typography a family: readable body text, distinguishable numerals, headings and keycaps. Long generated names, punctuation and unsupported characters must have a visible fallback rather than blanks. UI scale and panel sampling must be checked in the 3D consumer, including high-DPI and resizing. Decorative pixel art does not justify unreadable item descriptions. No actual font binaries are included in this planning handoff.

## 10. Completion means the real interaction works

One real item can be found, inspected, compared, equipped and unequipped through accepted/refused authority. A real new consumable is noticed and its count understood. A real named blocked door matches both maps and changes after its actual circuit operates. The player can rotate to the journal/settings and back without lost focus or a dangling drag. The gameplay world has not advanced behind the menu. Closing/reopening and cold restarting preserve correct state.

Review the in-engine menu itself at intended sizes, not only a Glyph render or a headless node census. Actual 3D construction and attractive flat screenshots are separate claims. Owner usability/visual approval remains an independent result.


---

<!-- SOURCE: 05_INHERITED_0_4_QUEUE.md -->

# 05 — Inherited 0.4 work: all 85 OV05 units retained

## How to use this ledger

The original accepted scope remains **full Amalgam + explicit 0.4 deferrals + the selected major/minors and acquisition obligations**. The 85-unit OV05 queue is a child inventory, not permission to forget other P00–P23/parent obligations. Original scope and OV04/OV05 documents are included as history. [S02, S10]

Every original OV05 task appears below with its **historical status reported at a745637**. No implementation or verification was performed to create this table. New owner feedback is a separate column/note. A formerly closed integration can need a new design repair without erasing its valid code or tests. `CLOSED` can mean runtime-only or merely reconciled, not collectible, owner-approved or aesthetically complete.

The machine-readable counterpart is `data/INHERITED_OV05_QUEUE.json`. The pristine unfilled original queue is preserved separately. Do not load its old `paused_agents` values as current execution instructions.

## Important carryovers

Blindside's B-1 self-item problem now has accepted high-level owner direction, but no new implementation proof. B-2 qualification and B-3 pre-seed representation remain real. The twelve manipulation verbs should not be rebuilt; they need their declared delivery/grammar path. Graph/Status/power/weld/railway/Gear breadth is unfinished. The full 0.4 destination does not become a small bug-fix release by renaming the remainder 0.5.

Historical technical integration of the minors is kept. Human acceptance of Unweighted and Passing is reopened. Counterfire needs an identified recheck. The natural bomb-acquisition experience remains unconfirmed.

## Historical status totals

**CLOSED: 59**, **BLOCKED: 5**, **PARTIAL/BLOCKED: 1**, **PARTIAL: 6**, **NOT STARTED: 13**, **BOUNDARY: 1**. These are report classifications, not newly measured completion percentages.

## O05-00 — Preserve, reconcile and start

Maps to P00 / P23. This is setup, not the night’s deliverable.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-00.1** Protect the delivered checkpoint | CLOSED | Preserved 330c555 reference; retain it and add a separate repair reference. |

| **O05-00.2** Reconcile the first dependencies | CLOSED | Retain reported closure at its original scope. |

| **O05-00.3** Persist this work order and ownership | CLOSED | Solo shared-seam edits were authorized; Dess reconciles them once. |

| **O05-00.4** Start a code unit | CLOSED | Retain reported closure at its original scope. |

## O05-01 — Ordinary hand carry, actually operated

Maps to P12 prerequisite / P16. Base-kit interaction is not an Echo HOLD ability.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-01.1** Implement the selected pickup/drop interaction | CLOSED | Retain reported closure at its original scope. |

| **O05-01.2** Keep it physical | CLOSED | Retain reported closure at its original scope. |

| **O05-01.3** Integrate input and feedback | CLOSED | Retain reported closure at its original scope. |

| **O05-01.4** Prove both legal and illegal cases | CLOSED | 60.00 kg carry accepted, 60.01 kg and LIGHTENED 70 kg refused in reported tests; do not conflate carry/mass class. |

## O05-02 — Carry one required object across rooms and use it

Maps to P16.1–.5 / P03. Do not introduce a fifth setpiece.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-02.1** Build from the delivered declaration | CLOSED | Retain reported closure at its original scope. |

| **O05-02.2** Traverse actual connections | CLOSED | Retain reported closure at its original scope. |

| **O05-02.3** Install in the real consumer | CLOSED | **OWNER POSITIVE — PRESERVE.** Owner enjoyed installing the cell. Preserve behavior; placeholder visuals can be replaced. |

| **O05-02.4** Preserve authority and uniqueness | CLOSED | Retain reported closure at its original scope. |

| **O05-02.5** Demonstrate Status continuity separately | CLOSED | Live doorway Status continuity is distinct from save persistence. |

## O05-03 — Restore and recover the transported-object journey

Maps to P04 / P16. Build on the delivered fresh-process and latch-restart coverage.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-03.1** Persist the accepted physical facts | CLOSED | Object poses and consumption, not a complete encounter-state guarantee. |

| **O05-03.2** Restart at two meaningful points | CLOSED | Retain reported closure at its original scope. |

| **O05-03.3** Restore in the right order | CLOSED | Restoring carried/installed object facts before build stays closed at that scope. Enemy resume is a new gap. |

| **O05-03.4** Recover without solving for the player | CLOSED | Recorded required-object recovery stays intact; never duplicate an installed object. |

| **O05-03.5** Isolate reset domains | CLOSED | Retain reported closure at its original scope. |

## O05-04 — A reversible branch action changes machinery elsewhere

Maps to P03 / P04 / P15. Independent early work when transport is blocked.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-04.1** Bind an existing D-8 configuration | CLOSED | Retain reported closure at its original scope. |

| **O05-04.2** Make the consequence useful and visible | CLOSED | **READABILITY REOPENED.** Technical effect works. PT-01 reopens human-readable source/destination mapping. |

| **O05-04.3** Verify reversal and escape | CLOSED | Retain reported closure at its original scope. |

| **O05-04.4** Respect machinery occupancy | CLOSED | Retain reported closure at its original scope. |

| **O05-04.5** Restart with the chosen configuration | CLOSED | Reversible configuration restoration is distinct from enemy restoration. |

## O05-05 — Earn the featured Echo and use it at Blindside

Maps to P01 / P02 / M2. This is the highest-value campaign payoff.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-05.1** Reconcile the acquisition seams once | CLOSED | Retain reported closure at its original scope. |

| **O05-05.2** Compose the intended structure | BLOCKED | Historical B-1. Later owner direction permits a local Echo from self-addressed originals; exact implementation still needed. |

| **O05-05.3** Acquire before use | BLOCKED | B-2: no selected actual-function qualification/fallback contract. |

| **O05-05.4** Make the return matter | BLOCKED | Depends on actual earned acquisition; no injected reward or walking bypass. |

| **O05-05.5** Preserve the five acquisition obligations | BLOCKED | B-3: pre-seed AP capability representation still required; proposal is not proof. |

| **O05-05.6** Handle failure without counterfeit success | PARTIAL/BLOCKED | Current refusal preserves safety. Failure recovery awaits qualification/delivery. |

| **O05-05.7** Resume the earned result | BLOCKED | Needs actual earned-grant and gate lifecycle, not only the railway latch. |

## O05-06 — Integrate the three existing minors without changing their meaning

Maps to P01.2 / P05. Three independent children, not an all-or-nothing dependency.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-06.1** Supported occurrence contract | CLOSED | **CONTENT CONTRACT REVISION REQUIRED.** Integrated occurrence contract exists. Revised pressure/reward behavior must amend it deliberately. |

| **O05-06.2** Passing Platforms | CLOSED | **OWNER REJECTS CURRENT ROOM EXPERIENCE.** Technical hosted/restart evidence retained; PT-06/07 reject bypass/readability/return experience. |

| **O05-06.3** Counterfire Arcade | CLOSED | **OWNER RECHECK / IDENTITY UNCERTAIN.** Technical hosted evidence retained; PT-04 identity and alternate route need owner recheck. |

| **O05-06.4** Unweighted Switch | CLOSED | **OWNER REJECTS CURRENT ROOM EXPERIENCE.** Technical integration retained; PT-05 rejects unclear/slow/bypassable current room. |

| **O05-06.5** Real reward and return consumers | CLOSED | **REWARD / RETURN REOPENED.** Reopened by ordinary pickup bypasses and unrecognized return; prove actual hosted claim/return. |

## O05-07 — Broaden the shared graph through actual consumers

Maps to P14. Do not stop at NOT + LATCH, and do not emit an unused catalogue.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-07.1** Inputs the existing rooms need next | CLOSED | PULSE_BUTTON and SHOOTABLE_TARGET PULSE have consumers; unsupported forms remain refused. |

| **O05-07.2** Useful logic nodes | PARTIAL | OR/TIMER done; AND/DIRECT/SEQUENCE require useful real consumers. |

| **O05-07.3** Shared wiring where meanings match | CLOSED | Both shared chains exist; a room design change is not deletion of graph integration. |

| **O05-07.4** Signal verbs and state | NOT STARTED | Five signal verbs and temporary override expiry not started. |

| **O05-07.5** Sensor distinctions and safety | CLOSED | Reported sensor/repeat/stale-callback controls retained; pressure redesign adds new cases. |

## O05-08 — Complete more of the twelve manipulation verbs

Maps to P12 / P13 / P18. This is substantial authorized continuation, not a new design brainstorm.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-08.1** PULL/HOLD/ALIGN/SETTLE | CLOSED | Runtime only, including PUSH; SETTLE sleep versus PIN rationale is a named source conflict. |

| **O05-08.2** TETHER/PIN/ROTATE | CLOSED | Runtime only; per-caster relations, PIN/TETHER/ROTATE. Not collectible Echo delivery. |

| **O05-08.3** ATTACH/DETACH | CLOSED | Runtime only; ATTACH/DETACH. Weld persistence named but unbuilt. |

| **O05-08.4** Mass fields and Status interactions | CLOSED | Runtime only; field kilograms and Status class differ. Enemy mass and further targets remain gaps. |

| **O05-08.5** Delivery and qualification | BOUNDARY | Atom grammar or explicitly approved interim representation; do not add a second ability path. |

## O05-09 — Advance the effective Status family, not the legacy count

Maps to P09–P11. Exact effective semantics, one shared support map.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-09.1** Kinetic and material consumers first | PARTIAL | Rooted/anchored enemy done. Remaining anchored object/player; lightened enemy/player; slippery; conductive hazard; brittle object delivery. |

| **O05-09.2** Actor behavior, not damage substitutes | NOT STARTED | confused, turncoat, blinded, silenced, exposed; effective actor behavior, not damage substitutes. |

| **O05-09.3** Safe temporary collision and interactions | NOT STARTED | phased: safe temporary collision/interaction, recovery and materialization. |

| **O05-09.4** Compounds with real inputs | NOT STARTED | Compounds with real inputs remain unstarted. |

| **O05-09.5** Preserve compatibility boundaries | PARTIAL | Per-kind/target gates retained for delivered support; wider compatibility unfinished. |

## O05-10 — Machinery and physical assemblies survive interruptions

Maps to P04 / P13 / P15. Extend scope, do not redo the proved latch.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-10.1** Apply the existing common contracts to actual occurrences | CLOSED | Closed only for touched occurrences; power loss untested because no power-source occurrence. |

| **O05-10.2** Package-specific physical restoration | PARTIAL | Passing restoration done; candidate constrained assembly remains. |

| **O05-10.3** Interrupted operations | CLOSED | Mid-closure reversal evidence retained. |

| **O05-10.4** Ownership and isolation | PARTIAL | Two-arcade isolation done; repeated lifecycle counters remain. |

## O05-11 — Make the corrected consumable path useful in the candidate

Maps to D-9 / P18 / P19. Do not restart the transaction design.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-11.1** Reuse authorization before launch | CLOSED | D-9 authorize/persist before irreversible launch retained. |

| **O05-11.2** Close any specific outstanding promotion condition | CLOSED | Reported staged promotion conditions handled for candidate only. |

| **O05-11.3** Exercise normal acquisition/creation | CLOSED | **NATURAL LIVE DISCOVERY UNCONFIRMED.** Bridge/engine acquisition proven; natural live acquisition not claimed and owner did not notice bombs. |

| **O05-11.4** Candidate-only promotion | CLOSED | Candidate-only promotion; production staged, refill and capacity rules still decisions. |

## O05-12 — Improve encounter relationships and legibility in existing content

Maps to P07 / P08 / P21. Use the research as a design lens, not an obsolete roadmap.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-12.1** One controlled placement comparison | NOT STARTED | Controlled same-ingredients encounter comparison remains. |

| **O05-12.2** Preserve intended counterplay | NOT STARTED | Preserve Bulwark counterplay; new visual/geometry failures do not erase it. |

| **O05-12.3** Ground navigation and doorway occupancy | NOT STARTED | Ground navigation, each body footprint and doorway occupancy remain. |

| **O05-12.4** Truthful event instrumentation | NOT STARTED | Actual event instrumentation needed; endpoint HP/teleported setups insufficient. |

| **O05-12.5** Make consequences understandable | NOT STARTED | Owner review now gives concrete readability changes. |

## O05-13 — Let the real candidate composer use the supported systems

Maps to P01 / P02 / P19. This must not remain a collection of save-editing tools.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-13.1** Candidate configuration, not fixture laundering | CLOSED | Real opt-in composer profile exists; do not substitute handwritten saved output. |

| **O05-13.2** Offer meaningful choices | CLOSED | Canonical choices are an increment, not the final expressive ceiling or a fun verdict. |

| **O05-13.3** Keep all identities and outcomes | CLOSED | Bounded sample/certification retained; future test denominators must include refusals. |

| **O05-13.4** Use available provider paths honestly | CLOSED | Deterministic fallback/mock only at reported handoff; no live-model claim. |

## O05-14 — Consume existing visual work without restarting Arty

Maps to P08.1 / P21.4 / D-11. Art is paused and approvals are unchanged.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-14.1** Bind already approved assets where ready | CLOSED | **CROSS-LANE DELIVERY RECONCILIATION.** Closed as reconciliation: nothing approved/ready to bind then. Art candidate archive exists separately. |

| **O05-14.2** Make the pack path maintainable | CLOSED | **CONSUME SETTLED D-11; DO NOT REBUILD.** D-11 delivered; stale Art namespace blocker is now integration work. |

| **O05-14.3** Review candidates without promotion | CLOSED | No pack approved/promoted. Preserve candidate versus selectable versus approved. |

## O05-15 — Keep a playable build available before the entire queue finishes

Maps to P21 / P23. Do this incrementally, not only after all reserve work.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-15.1** One clear launcher family | CLOSED | Launcher exists; reported Windows automation unrun. Print actual branch/profile. |

| **O05-15.2** Normal lifecycle, no test-only superpowers | CLOSED | **ENCOUNTER RESUME REOPENED.** Actual client/bridge path exists; unsafe combat resumption needs correction. |

| **O05-15.3** Preserve a green checkpoint early | CLOSED | Keep previous working checkpoints while changing UI/rooms. |

| **O05-15.4** Prepare owner review | CLOSED | Owner review occurred; preserve negative and positive findings separately from earlier technical checklist. |

## O05-16 — Continue the named ready reserve instead of stopping early

Maps to remaining P07/P10–P20/P22. These are authorized continuation priorities, not permission to invent extra systems.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-16.1** Finish remaining verbs/sensors/status pairs | PARTIAL | Residual graph/verb-delivery/Status rows remain; no enum-only close. |

| **O05-16.2** Existing railway network breadth | NOT STARTED | Railway switching/branch recall/occupied switch/restoration, no teleport over missing spans. |

| **O05-16.3** Gear/mod runtime where costs already exist | NOT STARTED | Already-costed Gear/mod consumers only; nine uncosted domains do not block all priced work. |

| **O05-16.4** Approved transaction consumers only | NOT STARTED | Exact approved Forge/Static transaction only; no invented economy. |

| **O05-16.5** Assembled runtime and generation recovery | NOT STARTED | Assembled runtime/performance/recovery measurement remains; headless timing is not renderer performance. |

## O05-17 — Final verification, evidence and stop

Maps to P23. End only under the stopping rules in §0.

| Unit | Reported state | Scope / new review |
|---|---|---|

| **O05-17.1** Freeze one integrated revision | CLOSED | Historical frozen 46bf023 run retained, not rerun by this packet. |

| **O05-17.2** Preserve evidence distinctions | CLOSED | Maintain direct-call versus real play versus human review distinctions. |

| **O05-17.3** Close the selected continuous journey | CLOSED | Continuous candidate driver passed its scope; owner found new missing cases. |

| **O05-17.4** Inspect generated differences | CLOSED | Capture provenance restamp distinct from gameplay edits. |

| **O05-17.5** One handoff, playable things first | CLOSED | Handoff complete at a745637; next handoff describes changed player experience. |

| **O05-17.6** End cleanly, not automatically | CLOSED | Stopped; no watcher/schedule. This packet does not resume anyone. |


---

<!-- SOURCE: 06_VERSION_0_5_PROGRAMME.md -->

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


---

<!-- SOURCE: 07_VERSION_0_6_ECHO_PROGRAMME.md -->

# 07 — 0.6: generated visual forms, Temporal Echoes and reconstruction workshops

**Status:** accepted future direction with unselected implementation details. Glyph is explicitly required for the new menu; applying it to the entire runtime-generated Echo pipeline is a strong proposed reuse, not a capability already integrated into Epsilon. [S05, S08]

## 1. Four things that must not be conflated

**Transferred original:** a real stranded item whose transfer completes to its AP-assigned recipient.  
**Ordinary Echo:** Epsilon's kept interpretation—a gun, mod, armour, ability or other supported part of the player's build.  
**Owned consumable Echo:** a kept tool/supply with charge expenditure and refill rules; exhaustion does not erase the item.  
**Temporal Echo:** a short-lived literal recreation, visibly drawn as the source item and usable for a limited time; not permanent equipment and not an AP Check.

A Temporal Keyblade is visibly a Keyblade with coherent supported behavior, not merely a gun with that name. Pixel-art flatness alone does not make an Echo temporary: ordinary skins/side weapons/companions may also be flat generated art. Do not add clothing or house creation from the reference analogy.

## 2. Prepare, release, finalize, grant

During Zone generation, Epsilon can inspect partial source information and prepare art plus valid interpretations. This does not reveal unclaimed hidden rewards to the player. The original has not transferred and no reward has been granted.

When the player releases the Check, the original completes its transfer and Epsilon obtains the final scan. Optional local art processing must not delay, revoke or duplicate the foreign delivery. Resolve the local interpretation/upgrade against the **current** owned collection, not a stale generation-time assumption. Store a recoverable earned local grant even when a later fabrication step fails.

A related Bomb Bag may improve already-owned bombs or create a distinct item. Similar names create creative opportunity, not a forced merge rule. Sharing `lob` or another primitive alone is insufficient. Prepared alternatives/fallbacks avoid a new unbounded art job at pickup. Save the accepted art/behavior identity so restart does not redraw or reroll it.

Self-addressed originals can also produce a distinct local Echo under the accepted design. Its exact transaction and progression integration remain inherited 0.4 work where needed; this later art pipeline cannot postpone that basic obligation.

## 3. Generated appearance never invents behavior

The runtime behavior vocabulary remains validated and supported. A sprite sheet declares visual size, facing, pivots, anchor points, animation clips and suitable render settings. The associated runtime contract declares movement, targeting, collision and effects. Drawing a giant blade does not silently enlarge a hit volume; drawing hands does not implement button operation.

Companions and side weapons need real supported action/perception/lifecycle contracts, not a following billboard plus a claimed ability. Visual and collision tests must agree from the player's camera—the current flyer mismatch is the counterexample to preserve. Ranged attacks should emerge from plausible sockets on the drawing.

Use bounded retries, cached/reused assets and stable source/output hashes. A failed optional image can use an appropriate approved fallback or omit a truly optional offering before entry without losing allocated rewards. A failed required function cannot be replaced by an unrelated pretty sprite. Generated content remains data, not arbitrary downloaded executable code.

## 4. Temporal item lifetime

Accepted direction: countdown starts when deliberately taken into use, pauses in a genuinely paused menu, and survives reload with remaining time rather than a reset lifetime. Ordinary equipment remains underneath; returning to the Hub ends the temporary item rather than creating permanent storage.

Exact duration, dismissal/binding and ordinary death behavior remain open. Define launched-projectile behavior on expiry explicitly; removing the held sprite must not duplicate or retroactively refund an irreversible attack. A Temporary item should be fun to use, with a visible lifetime and a useful nearby context, not expire during several empty return corridors.

Temporal tools can greatly change an optional fight without becoming its hidden sole viable solution. A chance drop or finite-lifetime side item cannot silently become an AP progression requirement. Other appropriate owned effects should exploit the same real mechanism where legal.

## 5. Temporal Shards and small workshop setpieces

Echo creatures can leave Temporal Shards. A small coherent setpiece workshop converts shards into a literal temporary item. The display, material and assembled object show the transformation in the world. A converter is not an excuse to attach five unrelated minigames to a crafting menu.

For a boss-linked converter, accepted retry direction charges the **local opportunity**. A failed boss attempt restores that opportunity with the encounter, not a duplicable refund of loose material. Preserve useful discovered shortcuts. General-purpose stock/refill/prices remain separate decisions. The system recycles local reconstruction material; it does not hold back a second original item or reopen a foreign transfer every time the player wants a weapon.

## 6. Echo creatures and factions

Echo creatures are Epsilon-style pixel-art reconstructions of beings associated with other worlds, not the actual native Multiworld population. An accepted starting explanation for hostile ones is escaped earlier research reconstructions: making an actor's form did not guarantee obedience. Later companions are specifically stabilized/bound for cooperation; ordinary use should not randomly betray the player under an undefined “unstable” exception.

Define distinct visual language for native creatures, hostile reconstructions and friendly companions. Their allegiance, lifetime, awareness, drop eligibility and save behavior need real rules. Not every world-inspired sprite requires a full new AI implementation; reuse behavior families deliberately while preserving recognizability and honesty about what the actor can do.

## 7. Wind, spikes and bosses

Owner concept: an optional side branch provides a temporary pushing/wind tool; a boss arena has major spikes; displacement creates an environmental opportunity. The causal sequence is force → susceptible motion → actual hazard contact → hazard consequence. There is no hidden “wind colour does extra damage” shortcut.

Bracing windows, armour breakage and exact timings are workshop proposals, not settled boss specifications. The effective authority's exclusion of physics puzzles in boss arenas requires an explicit compatibility ruling before this fight ships. Preserve the documented EXPOSED exception rather than claim a universal ban on all indirect damage changes.

## 8. Proposed incremental delivery

First, one generated **weapon appearance** on an already-supported behavior, with saved identity and correct import. Then one real **side weapon**. Then one **companion** with an observable useful action. Then one **Temporal pickup/converter** and a bounded **Echo-creature** encounter. Add the wind/spike boss only after its legal/runtime prerequisites and optionality are demonstrated.

These are suggested risk-reduction slices. They are not a requirement to deliver every source world's creatures or weapons. Keep the setpiece rollout gradual; tested library breadth should increase meaningful selection, not make each Zone longer or denser.


---

<!-- SOURCE: 08_STORY_AND_CHAPTER_HANDOFF.md -->

# 08 — Story handoff: what is settled and what still needs a chapter decision

## 1. Source and authority

The complete canonical workshop consolidation is included unchanged as `references/RIFT_DIRECTION_v0.3.1_original.md`. Use its **Owner direction / Accepted direction / Proposed detail / Open decision** labels. This summary is a reading aid and an implementation crosswalk, not a replacement story draft. [S05]

The latest refinements—world-signal origin, intentional research interference and controlled cleanup—are settled. Do not resurrect the simulation premise or turn the signals into an unknown caller. Exact faction names, numerical economy and the ending were not selected.

## 2. The operating premise

Epsilon was built to operate experimental station-to-station rift transit through the Multiworld, initially believed empty. Scientists detected other worlds across it, followed different world-signals, and deliberately increased interference to study them. They never completed clean transit into those worlds. Real traversable overlaps mixed station and neighbouring-world architecture, leaving material/transfers stranded.

The native population found the station through the repeated disturbance. Staff died or evacuated; the installation never returned home. The player, caught stealing research information, remained in cryogenic detention for trial. Security records know the detainee; crew evacuation did not treat them as staff; engineering/life support exposed the occupied pod but not the sealed case file. Epsilon used a failing emergency revival path with inadequate medical supervision. In the fiction, autobiographical memory is damaged; ordinary language and tool use survive.

Epsilon wants a way to leave, and the player wants freedom. He does not secretly know their whole past. Recovered records can teach both characters. Local uploads extend one ongoing Epsilon rather than making disposable independent copies. A later portable substrate/recovery core gives his escape a concrete physical objective. Some raider ships can genuinely leave; the story should not break every possible exit merely to avoid the choice of staying to help him.

## 3. Why a dungeon, not a hallway

Epsilon genuinely constructs a route. Multiworld interference changes what the apparatus can realize. The researchers amplified this for observation. The present expedition must expose enough of the existing contaminated pocket to reach and release its stranded transfers. Perfect isolation could provide simple transport elsewhere while cutting off precisely the things needing cleanup.

Independent enemies and secured systems are not his editable props. He can choose useful approaches, support traversable structures and operate systems under his actual control. Once stabilized, the place is physically committed and learnable. Interference does not authorize broken geometry, arbitrary room reshuffling, irrational puzzle clutter or Epsilon becoming conveniently incompetent.

Checks release the original to its assigned recipient. Epsilon studies it and makes a separate local Echo. Cleanup resolves the experiment's misplaced material/connections, not native life. Established station anchors maintain the traversable route; completing item transfers does not delete a learned dungeon, unfinished side branch or earned shortcut.

## 4. The first chapter, at the accepted level

Revive → establish the first Crossing → reach the real guarded warp-control terminal → install Epsilon's foothold → gain station-scale routing among established breachpoints. Long-range escape remains obstructed by unresolved interworld attachments and larger station objectives.

The guard is an actual sentient security machine occupying the endpoint, now on red alert. Epsilon can know the terminal's engineering function without knowing its custodian is still active. A later raider operation can motivate a route toward a real theft target; connecting a route can also give the raiders opportunities. Multiple bosses are allowed where their consequences differ, not as a quota.

Do not turn “secure destination” and “all transfers cleared” into one invisible event. The future campaign permits unfinished-Crossing revisits, while the existing 0.4 all-Checks/abandon policy remains until its explicit progression work changes it.

## 5. Remaining chapter choices—do not invent approval

| Decision | Current state | Recommended next artifact |
|---|---|---|
| How the stranded station accesses several old surveys | A proposal says unresolved survey links remain attached; not selected | One diagram/text route explanation with actual endpoint constraints |
| What physically releases an item anchor | Release event/transfer meaning settled; hardware and interaction presentation open | First-room release sequence, avoiding a compulsory new minigame per Check |
| Exact dependencies of first guard, upload, boss shard and next breachpoint | Their distinct purposes settled; detailed graph open | Chapter dependency map reconciled with AP requirements before implementation |
| Final campaign goal and treatment of unfinished transfers | Open; not “purify infinite worlds” by default | Owner/Dess progression proposal with local and multiworld consequences |
| Fiction of defeat | Emergency recovery was a proposal, not accepted canon | A bounded explanation or deliberate non-diegetic retry; no cloning/time-reversal invention |
| Names | Multiworld owner term; Crossing and native faction names still working/unselected | Name shortlist only when needed; code IDs remain stable |
| Raider theft target and Epsilon extraction hardware | Concrete target required; exact object open | One chosen object and recoverable failure consequence |

Current safe-resume repairs do **not** wait for a metaphysical explanation of death. Likewise, a working map can display existing objectives before the whole station campaign is written.

## 6. How to use the research already supplied

The two room-research documents are included as reference material. Preserve their separation of source observations, interpretations and proposed experiments. Use their discriminators—can the player explain a choice, learn a mechanism, remember a route, and understand a consequence—rather than turn their game examples into new mandatory rooms. No new external research or consensus finding is claimed by this packet.

The first useful story proof is one played Crossing where the destination, interference, physical task and lasting change are understandable without reading this handoff. The prose can stay brief; the machines and inhabitants should do part of the storytelling.


---

<!-- SOURCE: 09_CONTRACTS_AND_DECISIONS.md -->

# 09 — Contracts, decisions and inter-lane deliveries

## 1. Design intent is not a wire schema

The names below describe responsibilities, not final serialized field names. Before adding a record, look for the existing accepted shape and its producer/consumer. A contract lands with an actual small caller and case. No duplicate inventory, second fold, alternative ThemePack loader or free-form ability system is authorized.

A useful delivery note contains: source rule; current seam; chosen representation; emitted/read examples; authority; persistence lifetime; refusal behavior; compatibility; exact consumer; test/replay; revision. It should unblock the next step without demanding a comprehensive redesign of everything nearby.

## 2. Shared contract cards

### C-RESUME — encounter continuation

**Dess:** define stable declared encounter/member identities, saved defeated facts, legal reporting and reset semantics using existing campaign progress; explicitly address older saves lacking these fields. **Prod:** record real defeats, apply facts before spawn/perception, restore the player/world safely and demonstrate full/partial-clear cold restart. **Arty:** no save-schema work; visual death state must not imply an enemy is still alive or vice versa.

Proposed minimum: distinguish ordinary quit/reload from deliberate encounter reset; preserve defeated membership and future once-only drop eligibility. Do not derive kills from Check ownership or trust an arbitrary client list without consistency checks. Bridge validation is consistency/authority evidence, not proof of the physical kill; the runtime lifecycle supplies that evidence.

Open policy: old saves that have no member facts and partially active encounters. Provide a safe, explicit compatibility mode on a copy; no silent migration or invented clear state. Preserve original user saves and review snapshots.

### C-RELEASE — machine, reward and return

**Dess:** declared prerequisite/release condition and legitimate alternate solutions; AP reachability where the gate is required. **Prod:** actual obstruction/collision, physical effect, claim interaction and safe return. **Arty:** visible objective, control/device identity and state cues within agreed bounds.

Readiness must agree across world and authority. A reward visibly behind glass cannot be claimed through it. A legitimately opened path cannot remain software-locked solely because the player skipped one particular input order. The return condition must survive accepted alternate access and not rely on an optional movement item.

### C-PRESSURE — live input versus permanent decision

**Owner ruling:** ordinary pressure plates require continuing eligible pressure. **Dess:** update applicable content semantics/declarations without removing general LATCH; test a held arrangement against reachability. **Prod:** replace the misleading step-once route with an explicitly latching interaction or a genuinely solvable live-pressure mechanism; preserve safe closure/recovery. **Arty:** visibly different held plate versus lever/bolt, including pressure/state feedback.

A delayed/timed sensor would need its own explicit presentation/design; do not treat old four-second linger as an automatic substitute. `counts_player`, class sensing, kilogram sensing and hand-carry limits remain distinct; nobody changes 60 kg carry to 120 kg manipulation by renaming a device.

### C-MAP — shared navigational facts

**Dess:** decide which existing declaration/progress facts form a display projection, with stable room/edge/control/circuit references and discovery rules. **Prod:** one projection used by minimap, 3D map and journal; actual realized geometry and gate state. **Arty:** visual language for names, circuits and barriers; not a second truth table.

Separate unknown, blocked with known reason, transitioning/unsafe, and open. Item possession does not equal a completed power circuit. Names do not replace save IDs. The map can explain known state without revealing hidden content simply because the backend knows it.

### C-INVENTORY — presentation over the existing fold

**Dess:** current item/component identity, compatible slots, resolved properties, source history, consumable/pending/refusal presentation meaning. **Prod:** bind the new UI to real authority with stable focus/selection and once-only equip semantics. **Arty:** item family and state assets that communicate the data.

The menu never reconstructs its own upgrade arithmetic or fabricates a second copy of an item for its history. Mixed active/passive components remain representable. Read-only source provenance does not become a usable duplicate.

### C-ART — one importer and a pinned consumer

Each delivery gives source/export identity, role, units/bounds, pivots/sockets, animations/states, resource paths, hash, review status, supported consumer and actual screenshot. Glyph's panel/font output and Blender geometry remain separate inputs to existing game-owned integration. Fonts/art do not define collision, and the map/icon colour does not grant permission.

For packs, the settled D-11 schema/resolution in `11` governs. Arty's older folder-per-pack proposal is history. Do not keep two loaders “for compatibility” when neither source authorizes that duplication.

## 3. Decision register

| ID | Decision and present status | Responsible next step | What it blocks |
|---|---|---|---|
| D-01 | **Self-addressed originals may also yield a local Echo:** high-level owner direction accepted after historical B-1 | Dess writes exact source identity, grant and retry contract; Prod integrates | Closing B-1 in code, not discussion of whether the concept is allowed |
| D-02 | Featured Echo qualification and fallback not yet selected/implemented | Dess + Prod define actual range, targeting, attachments, slot and guaranteed function with a real recipient path | Blindside earned acquisition; no name-only capability claim |
| D-03 | Pre-seed AP representation of required capability/boss/shard gates still open | Dess develops explicit options; owner selects policy; implement real allocation/reachability proof | Multiworld-safe mandatory access, not independent machinery |
| D-04 | Full atom grammar versus an expressly bounded interim representation remains a design boundary | Dess develops within effective Amalgam; Prod names actual consumers; owner approves any temporary authority change | Delivering runtime-only manipulation verbs; no parallel primitive system |
| D-05 | Consumable refill policy and capacity-upgrade semantics remain unselected | Present current behavior and consequences; owner ruling; Dess source constant/contract | Production promotion/economy changes, not menu visibility or existing candidate tests |
| D-06 | Ordinary resume must be safe; exact partial/old-save policy needs a contract | Dess proposes narrow compatibility; Prod demonstrates; owner approves any migration/reset consequence | Unsafe-resume repair's compatibility part |
| D-07 | Step-once ordinary pressure behavior rejected | Implement explicit lever/bolt or solvable live pressure; no generic LATCH deletion | Revised passage acceptance |
| D-08 | New 3D Glyph menu/map is requested; exact release label not assigned | Keep a separate deliverable in near-term plan; owner chooses milestone label | Naming/release scope, not preparing the real UI slice |
| D-09 | D-11 pack identity and resolver are already settled and delivered | Reconcile into Art's branch/tools; no repeat architecture vote | Art integration, not namespace design |
| D-10 | Course candidate still awaits visual ruling; changes 18/22 pitches | Review by treatment before any mass regeneration | Applying candidate textures; not other asset work |
| D-11 | A tint/folder is not a completed game pack; interim candidate status may still be useful | Preserve reviewed/candidate/selectable/approved distinctions; finish two existing treatments first | Completion/promotion, not original source authoring |
| D-12 | Native faction names/motives, several chapter links and ending remain open | Finite chapter design using `08`; no lore invented as code constants | Those story beats only |
| D-13 | Boss physics-puzzle restriction versus wind/spike combat needs explicit compatibility | Dess reads effective rule; owner approves interpretation/amendment | That future boss, not ordinary knockback repair |
| D-14 | Drop quantities, recipes, sinks, Temporal duration and general workshop resets open | Future bounded economy proposal with persistence and AP separation | Production salvage/workshop economy, not death visuals |
| D-15 | General fictional defeat explanation not accepted | Story choice or explicit non-diegetic retry | Lore only; safe current resume is independently required |

Do not convert unspecified details into universal bans. An unimplemented mode is a gap, not proof the design forbids it. Equally, mentioning a mode in fiction does not make it supported. Refusals should distinguish invalid vocabulary, deliberately prohibited behavior, and known-but-unfinished support.

## 4. Inherited grammar and Status constraints

The twelve manipulation verbs have bounded runtime implementations in the handoff. Their earned Echo delivery, qualification and composition grammar do not follow automatically. The accepted 0.4 scope still owns those gaps; they must not become “later 0.6 companions” merely to produce a release label.

The shared graph has concrete PULSE_BUTTON/SHOOTABLE_TARGET/OR/TIMER consumers alongside earlier NOT/LATCH; AND/DIRECT/SEQUENCE and five signal verbs remain unfinished at the recorded scope. Inspect current support exports, not one older list, before changing them. Add a kind only with a meaningful actual consumer and refusal/persistence behavior.

Per-kind **and per-target** Status support matters. `rooted` and `anchored` on an enemy are not anchored on objects/players or lightened on every actor. Fields that scale kilograms differ from class-stepping Statuses. Preserve legacy compatibility and the effective EXPOSED exception. Temporary collision, compounds and object-targeted delivery need their own real consumers, not a green enum-storage test.

## 5. Lane ownership after the solo run

Prod's OV05 shared-seam table documents authorized changes to object poses/consumption, carrier states, candidate composition, minor hosting, latch namespaces, mock persistence, status support and exports. Dess reviews those **once** at the integrated head. Adopt correct work, repair real defects and record the evidence. Do not reverse valid work to reassert authorship. [S03]

For new shared edits, Dess owns schema/protocol/progression source and generated exports; Prod owns runtime integration and final combined tests. A bounded temporary transfer of a specific file can be agreed in the repo when necessary. Arty owns source assets and export manifests. Nobody independently edits the same live contract after the other has consumed it without a versioned handoff.

Keep approval separate: artists may submit/render/assess a candidate but cannot record owner approval. Runtime test success does not approve art, and an owner liking a concept does not promote a broken live gate.


---

<!-- SOURCE: 10_VERIFICATION_AND_OWNER_REVIEW.md -->

# 10 — Verification that matches the claim

## 1. The four questions

**Does the mechanism exist? Does normal play reach and use it? Does the state survive the promised lifecycle? Does the player understand and enjoy the situation?** A different kind of evidence answers each question. Preserve that separation.

Historical 64/64 success remains valid for the tested revision and tests. It does not refute a new bypass, unfair blast or confusing room. Add a case for the demonstrated gap; do not rewrite a test to accept the defect or discard a source fixture because it is inconvenient.

## 2. Targeted acceptance matrix

| Case | Setup/action | Required observation / distinguishing control |
|---|---|---|
| V-01 artillery isolation | Player and artillery in neighbouring sealed rooms, then same layout with a real opening | No damage through intact barrier; legitimate open-path attack still possible |
| V-02 shell path | Fire toward a reachable target with ceiling/obstacle intersecting the arc | Shell contacts the obstacle; no teleport through it; explosion uses actual impact |
| V-03 blast cover | Two players/probes or repeated trials equally near blast, one behind solid cover | Covered target is protected according to real occlusion; open target responds normally |
| V-04 flyer targeting | Normal player camera shoots visible body across near/mid/far views | Hit volume follows rendered body; intentional miss outside it remains a miss |
| V-05 flyer action | Actual declared role with ground/air/range/sight states recorded | Correct attack/wait state, real launched/impact events and cumulative damage; respawn cannot erase evidence |
| V-06 full clear reload | Clear a room, leave an object, quit both processes, resume same candidate | Item state returns, defeated population does not ambush player, no duplicate reward |
| V-07 partial/old-save reload | Kill subset, or load copied save lacking new fields | Explicit safe policy; no invented clear flags, silent reset or attacks during build |
| V-08 pressure semantics | Eligible pressure applied then removed | Ordinary plate output follows pressure; permanent lever/bolt is visibly distinct |
| V-09 puzzle cheap route | Fresh hosted minor with only base movement and real pickup range | No immediate reward bypass of the meaningful state; inspect actual geometry, not only room membership |
| V-10 movement assistance | Actual available double-jump/blink/grapple variants under their real rules | Useful alternatives remain; room still has a meaningful interaction, no global movement nerf |
| V-11 alternate Counterfire | Gunner-driven path and designed kill-first/service fallback | Both legitimate outcomes work; identify the owner's remembered instance before removing a fallback |
| V-12 return | Claim by intended and accepted alternate route, move carriers, die/re-enter | Clear, usable return without relying on optional random teleport |
| V-13 circuit legibility | Source control and remote door, same/adjacent rooms, replay | Colours/symbols/labels map consistently; pending/refused distinct from physical open |
| V-14 local keys | Inspect fresh Zone's keys, matching realized locks and open state | Meaningful matching local use; no useless awarded key with no declared consumer |
| V-15 bombs | Natural candidate claim, not injected component | Item discoverable, compatible equip and real authorized use; absent/owned/empty cases distinguished |
| V-16 paused equipment | Open via Escape/Tab; inspect/equip; type binding characters | World and gameplay clocks stop, UI remains usable, no input leakage |
| V-17 pause transaction | Authorization response/disconnect arrives during pause/page turn | No free/duplicate launch, no refund of irreversible work, safe reconciliation on resume |
| V-18 actual 3D navigation | Turn all four faces both ways; rapid/cancelled interaction | True panel transforms; correct face order; one active interaction surface; no accumulated turns |
| V-19 equipment data | Upgraded item, mixed Echo, empty slot, rejected equip, snapshot during selection | Current fold identity shown; no history-duplicates or false acceptance |
| V-20 two maps one state | Find green circuit, carry part, install, open, reverse, reload | Both maps match actual known passage state at each step |
| V-21 miniature integrity | Open actual multilevel Zone map repeatedly | Real connector/height geometry, no duplicated actors/scripts/rewards/physics |
| V-22 import/readability | Glyph source→export→Godot import→live menu at intended sizes | Correct font metrics/texture sampling, readable names/icons, actual input works |
| V-23 natural occurrence | Request fresh candidate through normal launcher/profile | Existing checks/identities preserved; proper selected content, no hand-edited save masquerading as generation |
| V-24 final journey | Start, acquire/equip, use machinery, claim, return, restart, continue | One coherent ordinary journey across contracts, not a collage of unrelated local proofs |

These are candidate test cases, not test results from this packet. Exact automated implementations can reuse existing drivers. Tests involving multiple perspectives can use repeated independent trials; they do not require introducing multiplayer player bodies.

## 3. Reproduction before a five-minute theory

Print relevant preconditions first: correct revision/profile/save, one normally placed player, existing holds, target role, visible/collision transforms, room/door state, resource/equip state and whether geometry is loaded. For movement, record actual displacement/speed and collisions. For damage, record events and deaths, not just HP at interval endpoints. For a screenshot, confirm the intended camera is current.

A bot stuck against the entry wall cannot prove a Bulwark unflankable. A spawn overlap cannot prove rooted movement is broken. A player who died and respawned cannot prove artillery dealt zero damage. These are preserved lessons, not reasons to distrust owner feedback.

## 4. Efficient negative controls

Use a minimal targeted control for each important invariant: remove cover check and covered-target case fails; omit saved-defeat restoration and the reload case fails; disconnect the reward consumer and the room's outcome fails; omit the pack cache identity and another pack leaks. Confirm the control breaks the actual function under test.

Do not run ten-minute mutations for every UI border or a full suite after every documentation line. Never edit a source file while another process expects a different sabotage. Keep restore checksums and original copies outside the mutation target. If a process/container stops, inspect and restore before committing anything. A sabotage that is not caught is a coverage gap or an invalid sabotage, not a pass to report away.

## 5. Frozen integration and platforms

Derive the required command list from the current Makefile/CI configuration. Run focused checks during work; one full fixed-revision frontier at an integrated delivery checkpoint. Capture command, exit code, duration, environment, source SHA and complete logs. Keep logs outside mutable tracked source. Record expected generated provenance restamps separately from code changes. Do not count steps from a truncated log tail or compare test totals from different revisions as one run.

Historical Linux evidence does not establish Windows execution. Test the exact Windows launch family/import on Windows when available. Otherwise deliver explicitly labelled unrun Windows verification and a short owner smoke route. Keep old ordinary/candidate saves separate; never use `--new` as a default fix for a failing save.

No remote CI polling/subscription is needed for local evidence. A remote runner failure is neither a code failure nor a reason to waive a real local failure. No watcher or scheduled resumption is added.

## 6. Owner review should be short and spoiler-light

Ask the owner to play a small changed route, not personally repeat this matrix. Give a separate answer guide. Capture spontaneous positives and problems; a puzzle bypass is evidence, not player noncompliance. Useful questions are: What did you think the room wanted? Which object changed something? What helped you recognize the threat? What did your movement ability let you do differently? Could you return without guessing?

Review one real inventory task: find a new item, compare/equip it, understand its binding/charges. Review one navigation task: identify a named known blocked door on the miniature, operate its circuit, see the map change and walk the route. Review one resume: clear, close, reopen, continue without a manufactured ambush.

Keep outcomes separate: technically verified, naturally encountered, human-understood, liked, rejected, untested. Do not roll them into a single “fun score.” The owner is not required to solve a confusing puzzle as intended merely so the report can call it complete.

## 7. Final handoff receipt

Include tested code SHA; pushed documentation/art SHA and difference; platform/runtime/profile; fresh/resume steps; preserved-save locations; spoiler-light changed route; answer guide; known blockers; actual natural-acquisition limits; visual/audio review status; exact next ready IDs. State what did **not** run. No repeated transcript, fabricated screenshot, unperformed listening claim, or “everything survives” shorthand without its reset domains.


---

<!-- SOURCE: 11_TOOLCHAIN_AND_ART_RECONCILIATION.md -->

# 11 — Toolchain and art reconciliation

## 1. The current cross-lane discrepancy

Arty's preserved `4093ded` delivery says the next pack lacks a material namespace and proposes alternatives. Later Prod/Dess deliveries have already settled and implemented D-11. Do not send Arty back to design a loader or describe this as waiting for the same decision. The remaining work is to **consume the delivered format**, produce appropriate material treatments and obtain review/selection—not to invent another schema. [S04, S06]

Prod's OV05 queue says no approved ready models/packs were available to bind. Arty's archive contains seven in-progress content kits. These statements can both hold: available candidate content is not an approved, selectable, integrated material pack. Reconcile by asset/revision/status rather than declare every Art delivery missing or promote all candidates.

## 2. D-11 contract to hand directly to Arty

`Zone.theme` remains one of six house families. `Zone.theme_pack` is separate and optional. A sibling **flat `pack_textures` table** uses keys `<pack>/<theme>/<role>` and the same fields as existing family texture rows. The bridge validates rows against the actual descriptor schema. Do not create a seventh house theme for each game or a separate folder-specific loader.

Resolution: exact pack/theme/role first; if absent, the unchanged family chain, including its existing one role fallback. The pack takes no fallback step of its own. Cache identity includes pack/theme/role; the Hub binds no pack, and teardown of an old owner must not clear a new owner's binding. Universal hazard roles remain universal; a pack cannot recolour them. [S04]

Candidate rows make artwork reviewable; selectable/approved status controls whether a Zone may name it. The source registry was empty at the handoff. A test-only pack does not establish production selection. Owner approval remains distinct from an agent's technical/import review. A controlled visual review mode is not permission to fake `approved` just to pass validation.

Arty must update her older README/frontier blocker with the consumed D-11 revision, without pretending her original report was wrong at its date. Complete one or two existing treatments and show them in real geometry before expanding T08 onward.

## 3. The seven existing kits and open course ruling

At the preserved Art delivery: **81 catalogue rows, 7 in progress, 0 completed**. This is a dated catalogue snapshot, not a fresh assertion about today's public Archipelago game count. Initial subthemes:

| ID | Reference game / chosen subtheme |
|---|---|
| T01 | Ocarina of Time / Forest Temple |
| T02 | Super Mario 64 / Tick Tock Clock |
| T03 | Bomb Rush Cyberfunk / Brink Terminal after hours |
| T04 | Super Metroid / Wrecked Ship |
| T05 | Kingdom Hearts II / Twilight Town service alley |
| T06 | Doom 1993 / UAC techbase |
| T07 | Dark Souls III / High Wall of Lothric aqueduct run |

The Twilight treatment's geometry differed but shared temple pixels still read like Forest Temple in Arty's own review. That is a recorded artist assessment, not a new visual judgment by this packet. Shared construction is encouraged; a generic tint/folder is not a completed pack. Distinctive material treatment, shapes, useful dressing and actual in-engine application are required.

The course candidate reports four broken axis/texture pairs reduced to zero while **18 of 22 pitches change**. It has not been applied. Art's preference was not uniform across themes. Keep the source/candidate comparison and obtain a treatment-specific ruling; do not resurrect the earlier incomplete “one line or start at half pitch” repair as a verified answer. Original source and updated findings are included under `references/`.

Preserve collision/clearance contracts and existing gates: doorway clearance, headroom, corridor fit, meaningful attachments and visual review are different. An overlap gate does not prove an architectural form looks supported. A surrounding model must not create an unapproved step or cover a landing, muzzle, control or hazard cue.

## 4. Glyph for the new interface

Verified reference branch while preparing this packet: `claude/feature-planning-roadmap-5oibiu` at **`87db9e20dd0c7cb1a1f7a3c617a47d5efa3526de`**. The older Arty authoring baseline is **`6c80b6315912a70b44c28d566ddff608eafa234a`**. Pulling main is not equivalent to using this newer tooling branch. [S08]

Use an isolated checkout and a disposable/new project for the new menu. Read the agent guide, discover actual commands and exercise granted artist attribution. The earlier trial already exercised an edit/render/open/reopen/export cycle; inspect those receipts rather than relitigate them, then prove the **specific font/panel import into the actual 3D menu**. An existing trial is not evidence of this new consumer.

The guide documents bitmap-font metrics/check/export, icon-family checks, nine-slice panels and Godot resource adapters. It does not make 3D mesh geometry or attach game callbacks. The documented bitmap-font import proof names Godot 4.3, while this game uses 4.5.1; test the actual target. No claim is made here that a new build/test/import run was executed.

Opening `.glyph` projects may checkpoint stored data; Arty recorded changed tracked fixtures during verification. Work on copies and inspect diffs. Do not mass-migrate/re-render approved content, run expensive certification benchmarks repeatedly, or equate `check_tiling` reports with automatic aesthetic rejection. New sources keep source SHA, exports/hashes and art-review state together.

## 5. SigmAudio stays in scope as a tool reference, not a DAW rebuild

The 22 September refresh is included unchanged. It inspected main at `2d76a5a3a6f77b5849ae0014178069ab642a6aa3` and development at `6897ce23f92dad6be13055e957049322e03999fe`. Those are **historical inspected pins**, not newly verified current heads for this handoff. No SigmAudio application was run and no audio was heard here. [S09]

Preserve useful existing threat audio. For new menu/control/death cues, use a supported original-authoring/export path and prove the actual game consumer. Do not copy referenced games' sounds or soundtracks. The documented development automation was opt-in; the older Godot adapter did not supply stinger playback/ducking, cross-cue sequencing or guaranteed sample-accurate automation. Do not assume that richer DAW authoring automatically added these runtime capabilities.

A small agreed cue/state handoff may be useful. It is not permission to rebuild the score, upgrade every project, or divert Prod/Arty into finishing SigmAudio. Listen through an available human/host path before reporting a sound judgment; rendering and numerical measurement are not listening.

## 6. Updated Art priority

First: the Glyph interface family, shared circuit/control cues and distance-readable current enemies. Second: replace functional machinery placeholders against the revised puzzle bounds; fix the receiver's z-fight as part of that replacement, not a separate high-priority polish task. Third: consume D-11 and finish initial material treatments. Then continue genuinely unblocked A15/A16/A17–A19 reserve work as authorized, preserving the original art queue.

Each delivery is a usable slice with actual consumer evidence and explicit review status. A state variant is not a new enemy, a cluster is not a dozen unique models, and a catalogue row is not a completed pack.


---

<!-- SOURCE: 12_SOURCES_AND_LIMITS.md -->

# 12 — Source register, evidence boundaries and freshness

## Source IDs used in this packet

| ID | Source | What it supports / limitation |
|---|---|---|
| S00 | Skyiah's direct messages and supplied reports in this conversation | Owner feedback/requirements and reported experience. Not a recorded input trace or a verified local playtest save |
| S01 | `cadykaya/archipepsi@a745637`, `docs/ledgers/ov05_evidence/FROZEN_RUN.md` | Prod's 64-step Linux run at `46bf023`; not a run performed for this packet or Windows automation |
| S02 | Same ref, `docs/ledgers/PROD_OV05_READY_QUEUE.md` | Historical status of all 85 OV05 units; technical scope, blockers and limits retained |
| S03 | Same ref, `docs/AGENT_FRONTIER.md` and `docs/ledgers/PROD_OV05.md` | Handoff and temporary shared-seam ledger. Older lower frontier entries can be stale; the new owner feedback governs new requirements |
| S04 | Same ref, `docs/D11_THEME_PACK_PROD_ANSWER.md`, including §5 and §7 | Settled pack table/selection/fallback and delivered runtime; test packs are not approved production art |
| S05 | Mounted `ARCHIPEPSI_RIFT_DIRECTION_v0.3.1.md`, included unchanged | Approved workshop rules, explicitly unselected proposals, supersessions and 0.5/0.6 boundaries |
| S06 | Art archive `archipepsi-art-2026-09-22-ALL.zip`, README/reports/COVERAGE; `archipepsi@4093ded` coverage read | Seven in-progress kits, dated 81-row catalogue, no completed pack, course candidate and tooling trial. No fresh visual assessment of all frames here |
| S07 | `cadykaya/Caster-Guide-to-Fishing@a0eb2e4328dcc92ad8ae4856711691055b2faca3`, `scripts/ui/game_menu.gd` and `inventory_slot.gd` | Existing BG3-style layout and interaction reference; no render or live use of it in this handoff |
| S08 | `cadykaya/ECMS-GLYPH@87db9e20dd0c7cb1a1f7a3c617a47d5efa3526de`, `AGENTS.md`, `GAME_ASSETS.md`, prior art trial | Documented authoring/export features; ref rechecked. No new Glyph build, resource import or menu assembled here |
| S09 | `ARCHIPEPSI_TOOLCHAIN_REFRESH_2026-09-22.md`, included unchanged | Historical SigmAudio/Glyph feature and compatibility review. SigmAudio heads not freshly queried; no audio heard |
| S10 | Supplied full 0.4 scope, first-major approval, OV04/OV05 master/queue and recovered EX50-011/021/033 | Original obligations and scope labels; historical implementation assumptions may have been superseded |
| S11 | Godot 4.5 documentation: Pausing games and process mode | Paused physics/processes and still-active signals; implementation proposals must be tested in 4.5.1 |
| S12 | Godot 4.5 documentation: Using Viewports | Texture targets, input forwarding boundaries, separate worlds; does not implement the requested menu |
| S13 | Official godot-demo-projects `viewport/gui_in_3d/README.md` on master | Reference demo for GUI in 3D; not a pinned compatible code dependency or a claim it was run |
| S14 | Two supplied room research Markdown documents, included unchanged | Prior source-labelled research and proposed experiment methodology, not newly verified outside findings |

## Repository lookup references

Use the exact immutable ref with each path. Recheck the live branch at resumption; do not reset it to the reference merely because new commits exist.

- Archipepsi integrated handoff: `a7456373fc76d1c4f8148ccd6b1c6c0beb0eab70`.
- Frozen code reference: `46bf023` (resolve full SHA in the repository before executing a reproducibility run).
- Art delivery reference: `4093ded` on `claude/archipepsi-art`.
- Glyph new tooling: `87db9e20dd0c7cb1a1f7a3c617a47d5efa3526de` on `claude/feature-planning-roadmap-5oibiu`.
- Glyph prior Art authoring: `6c80b6315912a70b44c28d566ddff608eafa234a`.
- Caster's Guide reference: `a0eb2e4328dcc92ad8ae4856711691055b2faca3`.

## Public implementation references

These were read for implementation constraints, not to replace private project authority:

- https://docs.godotengine.org/en/4.5/tutorials/scripting/pausing_games.html
- https://docs.godotengine.org/en/4.5/tutorials/rendering/viewports.html
- https://raw.githubusercontent.com/godotengine/godot-demo-projects/master/viewport/gui_in_3d/README.md

All external implementation advice in this packet is labelled as a proposal. No source code from these pages is redistributed here.

## Important corrections carried forward

The old plate route was built to latch; its technical pass is not the owner's approval of pressure semantics. The Counterfire recollection is uncertain. Duplicate-room sightings are not yet a proven same-Zone duplication bug. Missing/noticed bombs is not a proven missing-grant bug. The unsafe enemy restoration is the owner's direct experience; exact record mechanics are for reproduction. Earlier arithmetic/code leads for artillery and flyer construction are not a new end-to-end test.

The old uploaded schema-8 save and older pressure-routing investigation concern another historical build. They are not used as the current candidate's equipment/encounter state. No personal save or raw user account data is packaged.

D-11's implementation supersedes Art's old namespace proposal. It does not approve the seven art candidates. The new Glyph UI mandate does not retroactively migrate old sources or make Glyph the accepted runtime generator for all 0.6 art. The new map request supersedes a previous no-map-design restriction only for the newly requested package.

## What was actually done to prepare this handoff

Read the conversation, relevant uploaded/reference materials and selected repository handoff/contract files. Confirmed the integrated Archipepsi and Glyph branch refs. Read Godot's official implementation references. Consolidated requirements, proposed work/dependencies, retained all 85 inherited units and produced this packet with file checksums.

No game or agent was started. No gameplay code, GitHub branch, PR, setting, grant, installed tool or original save was changed. No test suite, new asset build, listening review or Windows launcher was executed. No schedule/watch was armed. Work states in `data/WORK_QUEUE.json` are planned—not completed just because they have acceptance criteria.

## Source copies and versioning

`data/SOURCE_COPIES.json` lists unchanged included source bytes and their hashes. `SHA256SUMS.txt` covers the delivered packet. Historical references retain old instructions for provenance; the current root documents explain which ones are superseded. The all-in-one Markdown is derived from the modular documents, so editing the source sections and rebuilding avoids two divergent specifications.


---

<!-- SOURCE: 13_WORK_QUEUE.md -->

# 13 — Work inventory and dependency map

All rows are prepared work, not executions. The chosen near-term candidate can stop at CP1/CP2 or include CP4; a full UI implementation must not delay shipping a critical combat/resume repair indefinitely. Future rows require explicit activation. Decisions in `09` block only their affected behavior. No task count below is a claim of added features or completion.

## SETUP

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-START — Preserve and reconcile the integrated reference** | Prod | None | Protected working checkpoint, actual profile/branch/save identity, one ownership note. Original save hashes unchanged; current branch read; no full baseline rerun as ritual. See `00_READ_FIRST.md`. |

| **H-SEAMS — Adopt or repair OV05 shared-seam deliveries** | Dess | H-START | Concise reviewed shared-seam table and named ownership. Correct prior work retained; actual defects/tests identified. See `09_CONTRACTS_AND_DECISIONS.md`. |

## REPAIR

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-ARTILLERY — Target acquisition, shell collision and blast cover** | Prod | H-START | Fair indirect-fire path and occlusion repair. V-01–03; actual open-path positive control; geometry blocks sealed-room attacks. See `03_DELIVERY_PLAN.md`. |

| **H-FLYER-HIT — Visible flyer body and damage volume agree** | Prod | H-START | Correct visual/collider/muzzle/hover transform alignment. V-04 normal camera shots; deliberate misses still miss; matching Art review. See `02_PLAYTEST_FINDINGS.md`. |

| **H-FLYER-AI — Identify and test actual flyer attack states** | Prod | H-FLYER-HIT | Role-specific diagnosis/fix and readable waiting/attacking. V-05 with events/deaths; no endpoint-HP or bot-aim fiction. See `02_PLAYTEST_FINDINGS.md`. |

| **H-RESUME-C — Encounter continuation and compatibility contract** | Dess | H-SEAMS; decisions D-06 | Stable identity/defeat/reset/restoration contract using existing save authority. Bridge state and idempotence cases; old absence explicitly handled. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-RESUME-R — Resume a cleared/part-cleared room fairly** | Prod | H-RESUME-C | Defeated membership restored before perception; safe player restoration. V-06–07 two-process lifecycle; object facts preserved; no farming duplicate. See `03_DELIVERY_PLAN.md`. |

| **H-PRESSURE-C — Live pressure versus explicit persistent release** | Dess | H-SEAMS; decisions D-07 | Revised applicable contract and solvable route fixture. Held output and explicit latching interaction distinguished; no unsolvable stand-and-walk gate. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-PRESSURE-R — Replace misleading step-once plate route** | Prod | H-PRESSURE-C | A readable lever/bolt or genuinely held-pressure route. V-08; actual route and closure/restart; general LATCH retained. See `03_DELIVERY_PLAN.md`. |

| **H-RELEASE-C — Hosted minor goal/release/return contract** | Dess | H-SEAMS | Three room cards and legal reward/alternate-route conditions. Allocation/return/known movement modeled; no secret input sequence. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-UNWEIGHTED — Repair Unweighted meaning and direct pickup** | Prod | H-RELEASE-C | Readable dual-use crate, tuned drive, real reward obstruction and safe return. V-09–10/12; hosted normal inputs and expiry; not only standalone driver. See `03_DELIVERY_PLAN.md`. |

| **H-PASSING — Repair Passing goal, controls, pickup and return** | Prod | H-RELEASE-C | Coherent lift/shuttle room with machine outcome and visible return. V-09–10/12 including baseline jump and alternate entry/claim. See `03_DELIVERY_PLAN.md`. |

| **H-COUNTERFIRE — Identify Counterfire and preserve valid fallback** | Prod | H-RELEASE-C | Main and designed alternate route with understandable causality. V-11; actual occurrence identified; gunner-dead condition does not strand reward. See `03_DELIVERY_PLAN.md`. |

| **H-CIRCUITS — Control/destination visual and semantic mapping** | Arty | H-PRESSURE-C, H-RELEASE-C | Shared matching colour/symbol/action-state family. V-13 on actual lever/cell/receiver/door, no conflicting key/power meanings. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-KEYS — Audit local key payoffs and visibility** | Dess | H-SEAMS | Candidate local key/realized lock audit and targeted defect repair. V-14; distinguish no lock from open/unseen lock; no unjustified global rescope. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-BOMBS — Natural consumable acquisition and discoverability** | Prod | H-SEAMS | Matching current-save diagnosis and normal acquisition/equip/use receipt. V-15; absent versus unnoticed distinguished; no artificial grant as evidence. See `02_PLAYTEST_FINDINGS.md`. |

## UI

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-UI-DATA — One live inventory view over current fold** | Dess | H-SEAMS | Resolved current item/slot/state presentation contract. Mixed/upgrade-only/refused/pending fixtures; no second fold. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-GLYPH-KIT — First menu font/panel/icon asset family** | Arty | H-START | New/copy-based Glyph sources, exports and actual target import trial. V-22 in Godot 4.5.1; metadata/source receipts; originals unchanged. See `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. |

| **H-3D-SHELL — Four real inward-facing rotating menu pages** | Prod | H-START | Real 3D scene, correct face order and live input mapping. V-18; scene transforms plus actual interacted render; not flat tab squeeze. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-PAUSE — Pause ownership, callbacks and authority races** | Prod | H-3D-SHELL | Paused world with usable menu, preserved other holds and safe in-flight accounting. V-16–17; no game-input leakage or delayed grenade launch/free refund. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-INVENTORY — Usable Glyph/Caster-reference equipment face** | Prod | H-UI-DATA, H-GLYPH-KIT, H-PAUSE | Current inventory/equipment/search/detail/compare with real equip authority. V-19/22; human find/compare/equip and empty/owned/charged distinctions. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-MAP-DATA — Shared known room/gate/circuit map facts** | Dess | H-SEAMS, H-RELEASE-C | Stable names/discovery/current gate projection for two maps and journal. Actual known-state fixtures; no auto-solved gate from possession; no secrets leaked. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-MINIMAP — Always-visible normal-play map with named barriers** | Prod | H-MAP-DATA, H-CIRCUITS | Named readable current location/connectors/colour-coded blockers. V-20; actual green circuit transitions and replay; readable floor convention. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-3D-MAP — Interactive miniature of actual built dungeon** | Prod | H-MAP-DATA, H-3D-SHELL, H-GLYPH-KIT | Rotate/zoom/pan/cutaway actual geometry, names and pulsing blockers. V-20–21; turns/heights real; no actors/colliders/reward scripts cloned. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-JOURNAL — Settings and earned objective/journal faces** | Prod | H-MAP-DATA, H-3D-SHELL | Useful actual current objectives/known discoveries and accurate lifecycle controls. No invented campaign, spoilers or altered abandon policy; page navigation/focus works. See `04_3D_MENU_MAP_AND_GLYPH.md`. |

| **H-UI-REVIEW — Integrated spatial menu usability and stability** | Prod | H-INVENTORY, H-MINIMAP, H-3D-MAP, H-JOURNAL | One reusable menu with correct input, readable art and stable selected state. Actual owner task; resize/high-DPI/focus/drag/reload; world clocks stopped. See `10_VERIFICATION_AND_OWNER_REVIEW.md`. |

## ART

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-ENEMY-ART — Distance-readable existing enemy lineup** | Arty | H-FLYER-HIT | Distinct silhouettes/weapon/motion family against current collision bounds. Normal-distance/mixed-light frames; no audio/nameplate required for threat distinction. See `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. |

| **H-MACHINE-ART — Revised selected-room machinery visual replacement** | Arty | H-UNWEIGHTED, H-PASSING, H-COUNTERFIRE, H-CIRCUITS | Readable machinery/cell/receiver assets with unchanged gameplay boundaries. Real occurrence fit/pivots/collision clearance; source-fixed clipping, no new footholds. See `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. |

| **H-PACKS — Consume delivered D-11 and finish existing treatments** | Arty | H-SEAMS; decisions D-09, D-11 | Updated stale blocker and small material-pack integration candidates. Exact flat pack table/caches/hazard rules; actual authored pixels visible; approval not fabricated. See `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. |

| **H-COURSES — Obtain and apply only a selected course treatment** | Arty | H-START; decisions D-10 | Treatment-specific review and source change only after ruling. Before/after in repeated geometry; 18/22 changed pitches disclosed. See `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. |

## INHERITED

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-SELF-ECHO — Implement accepted self-addressed local grant contract** | Dess | H-SEAMS; decisions D-01 | Original delivery plus distinct local grant identity/recovery. Self/foreign/retry/reload cases; no cloned AP item. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-QUALIFY — Qualify actual featured function and fallback** | Dess | H-SELF-ECHO; decisions D-02 | Qualified real range/target/slot/function contract and fallback. Recipient/reward semantics and real function tests, not capability-label proof. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-AP-GATE — Pre-seed representation of earned capability access** | Dess | H-QUALIFY; decisions D-03 | Owner-selected AP/progression representation with generated proof. Acquisition reachable before requirement; recipient unchanged; no live-seed rewrite. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-BLINDSIDE — Finish earned Blindside return loop** | Prod | H-QUALIFY, H-AP-GATE | Branch acquisition→useful gantry→commissioned span→Checks→return/restart. Normal continuous player/AP journey; no injected grapple or mandatory walking bypass. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-ATOM-DELIVERY — Resolve grammar and deliver implemented manipulation** | Dess | H-SEAMS; decisions D-04 | Effective grammar or approved bounded representation plus actual earned consumer. Create/fold/equip/activate/qualify persists; no parallel primitive system. See `09_CONTRACTS_AND_DECISIONS.md`. |

| **H-GRAPHS — Remaining useful graph nodes and signal verbs** | Prod | H-SEAMS | AND/DIRECT/SEQUENCE and five signal verbs as needed by real consumers. Actual input→consequence, override expiry, persistence and refusal. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-STATUS — Remaining supported Status-target behavior and compounds** | Prod | H-SEAMS | Per-target consumers/delivery for remaining kinetic/material/actor/collision/compound work. Behavior in world; no legacy corruption or actor damage substitute. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-MACHINE-LIFE — Power, assembly and repeated lifecycle evidence** | Prod | H-SEAMS | Real powered/constrained occurrence and ownership isolation. Power loss/restoration, occupied/reversing/reset, weld/assembly scope and repeated counters. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-RAIL-BREADTH — Switchable rail network and safe recall** | Prod | H-SEAMS | Physical branch selection and occupied-switch/recall/restoration. Actual track changes; no teleport across uncommissioned link. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-GEAR — Priced Gear/mod and approved transaction consumers** | Dess | H-SEAMS | Selected legal priced domains routed through current fold/equip. Real source-owned effect, clamps, save and transaction; uncosted domains named. See `05_INHERITED_0_4_QUEUE.md`. |

| **H-PERFORMANCE — Measure assembled candidate and bounded recovery** | Prod | H-UI-REVIEW | Actual menu+combat+machinery resource profile and recovery fixes. Main/physics/render separated; lifecycle leak and refusal denominators; no timeout padding. See `10_VERIFICATION_AND_OWNER_REVIEW.md`. |

## 0.5

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-05-ROOM — One four-pillar situation and quieter connectors** | Dess | H-UNWEIGHTED, H-PASSING, H-COUNTERFIRE | Selected authored situation with shared combat/environment/item/traversal relationships. Human choice explanation and usable returns; not four unrelated activity bins. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-COMPOSE — Purposeful room/connector generation and local-key payoff** | Prod | H-05-ROOM, H-KEYS | Generation uses proven relationships and calm connective space. Normal candidate samples include refusals; all Checks retained and local locks meaningful. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-FACTIONS — Bounded nonrobot faction roles** | Dess | H-ENEMY-ART; decisions D-12 | Native Multiworld and raider role briefs alongside security. Distinct purpose/counterplay/appearance; provisional budgets not difficulty claims. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-LIVING — Perception, routines and real world interaction** | Prod | H-05-FACTIONS | One useful noncombat job, faction relationship and actual mechanism interaction. No telepathy; real consequences; protected permanent state and required-item recovery. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-DEATH — Readable faction-appropriate defeat and aftermath** | Arty | H-05-FACTIONS, H-RESUME-R | Distinct defeat visuals/sound cues, bounded debris and safe hit-state integration. Immediate death recognition; cosmetic blast not automatic damage; no blocked passages. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-SALVAGE — Useful drop loop and agreed upgrade sink** | Dess | H-05-DEATH, H-GEAR; decisions D-14 | One priced useful material loop with once-only transactions. Environmental kills/reload uniqueness/pickup recovery; no meaningless scrap counter. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-SHARDS — Named permanent breachpoint progression rewards** | Dess | H-AP-GATE; decisions D-03, D-12 | Guaranteed intact boss shard access distinct from spending materials. No RNG softlock, no revisit fee, declared pre-seed dependence. See `06_VERSION_0_5_PROGRAMME.md`. |

| **H-05-BRANCH — Gradual setpiece branch rollout** | Prod | H-05-COMPOSE, H-05-LIVING | One developing situation spanning rooms with lasting return payoff. Play/revise before expanding catalogue; not three drills joined together. See `06_VERSION_0_5_PROGRAMME.md`. |

## 0.6

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-06-VISUAL — Saved generated weapon-appearance pipeline** | Prod | H-GLYPH-KIT, H-ATOM-DELIVERY | One prepared visual skin on supported behavior with stable saved identity. No pickup-time art stall, no redraw on restart, silhouette/collision agreement. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-SIDE — One real auxiliary weapon** | Prod | H-06-VISUAL | Visible auxiliary implement with supported effects and sockets. Own real action/authority, not a decorative sprite claiming a function. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-COMPANION — One useful generated companion** | Prod | H-06-VISUAL, H-05-LIVING | Bounded cooperative actor with observable action and lifecycle. No arbitrary hostility flip, universal interaction or appearance-defined powers. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-TEMPORAL — Literal temporary source item** | Prod | H-06-VISUAL, H-PAUSE; decisions D-14 | Recognizable temporary item over retained ordinary equipment. Start-on-use, pause/reload remaining time, Hub expiry and independent AP identity. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-CREATURE — Echo-creature population and Temporal remains** | Arty | H-06-VISUAL, H-05-DEATH | Distinct reconstruction actor presentation plus validated behavior/drop identity. Native versus Echo recognizable; actual threat and once-only remains. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-CONVERTER — Temporal-shard workshop and retry opportunity** | Prod | H-06-TEMPORAL, H-06-CREATURE, H-05-SALVAGE; decisions D-14 | Small coherent physical converter with agreed stock/cost/lifetime. Boss retry restores opportunity, not refundable duplicable currency. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

| **H-06-WIND-BOSS — Optional wind/displacement/spike encounter** | Prod | H-06-CONVERTER, H-05-SHARDS; decisions D-13, D-14 | Compatibility-approved positional boss and useful side branch. Actual displacement/contact, viable guaranteed kit, no hidden wind multiplier. See `07_VERSION_0_6_ECHO_PROGRAMME.md`. |

## STORY

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-STORY-LINKS — Resolve remaining first-chapter operating choices** | Dess | H-SEAMS; decisions D-12 | Finite dependency/route explanation with unresolved choices explicit. World signals/physical interference preserved; no invented caller/simulation. See `08_STORY_AND_CHAPTER_HANDOFF.md`. |

| **H-STORY-FIRST — First physical rift chapter** | Prod | H-STORY-LINKS, H-05-COMPOSE, H-05-SHARDS | Revival→real guarded terminal→local warp foothold. World demonstrates objective, Epsilon limit and lasting access without lore dump. See `08_STORY_AND_CHAPTER_HANDOFF.md`. |

| **H-STORY-RAID — Later raid and Epsilon extraction direction** | Dess | H-STORY-FIRST; decisions D-12, D-15 | Chosen theft target/portable substrate and clear consequences. One Epsilon, actual inhabited endpoints, meaningful possible player escape. See `08_STORY_AND_CHAPTER_HANDOFF.md`. |

## DELIVERY

| ID / work | Lead | Prerequisites | Delivery / proof |
|---|---|---|---|

| **H-FREEZE — Freeze the selected coherent review candidate** | Prod | H-ARTILLERY, H-FLYER-AI, H-RESUME-R, H-PRESSURE-R, H-UNWEIGHTED, H-PASSING, H-COUNTERFIRE | Source-pinned playable handoff with route/answers/raw logs and exact scope. Full current frontier on one revision; Windows status honest; no unattended jobs. See `10_VERIFICATION_AND_OWNER_REVIEW.md`. |

## Machine-readable use

`data/WORK_QUEUE.json` retains dependencies, decisions, primary lane, detail document, deliverable, evidence and legacy IDs. `data/INHERITED_OV05_QUEUE.json` retains all 85 original children and historical/report versus owner-review scope. They are derivative ledgers, not a new game schema. Update status only from actual execution evidence.


---

# Lane-specific starting briefs


---

# Prod — prepared resumption brief

**This file is a handoff, not evidence you are already running.** When Skyiah sends it with an instruction to proceed, use the shared packet's ready near-term tasks and inherited scope. No heartbeat, watcher, subscription or schedule. Do not change Epsilon's live model because the development agent model changed.

## What changed after your handoff

Your `a745637` checkpoint and `46bf023` frozen run are preserved. The owner played and says the game is more fun; seating the power cell was especially good. However: artillery damages through walls/from other rooms; flyers look displaced from their hitboxes and do not communicate reliable attacks; reloading a cleared room restores the player among respawned enemies; the Unweighted and Passing rewards were directly reachable without their intended machinery; returns and controls were confusing. Counterfire's remembered emergency-target route is uncertain—identify it before removing a valid fallback.

The owner rejects step-once ordinary pressure plates, wants colour-linked controls/destinations, and explicitly requests a replacement BG3/Caster's Guide equipment interface inside an actual 3D rotating four-face pause menu made with Glyph artwork. Both maps need real room names and matching blocked connectors; the pause map is a visual miniature of the actual dungeon. These UI/map requests are **new scope**, not a retroactive failure of your old no-map-redesign order.

## Read without rereading the whole project

Start with root `00_READ_FIRST.md`, `02_PLAYTEST_FINDINGS.md` and the relevant section of `03_DELIVERY_PLAN.md`. Use `04` for UI/map, `09` for shared contracts and `10` for verification. `05` retains all 85 original units. Read source authority when a task needs it, not every page before one code change.

## Your first execution slice

Preserve the current shared head and original saves; record current branch/profile/save identity. Capture the real combat/resume reproductions and cheap pickup routes with ordinary player inputs. Do quick precondition probes before long runs. Take the fair-combat fixes that do not need new shared fields while Dess agrees encounter-resume and reward/pressure contracts.

You own runtime/gameplay implementation, integration and final fixed-revision verification. Dess owns the new shared schema/progression/fold/save changes; temporary single-writer exceptions need explicit coordination. Your authorized OV05 shared edits are not presumed wrong—hand over their existing seam table and preserve correct work. Arty owns source art and export manifests. Agree actual pivots/collision/resource contracts before integration.

## Order and continuation

CP1 fair combat/safe resume → CP2 selected-room goals/rewards/returns → CP3 one real Glyph equipment face in the rotating shell → CP4 complete equipment/map/journal UI. Independent ready inherited 0.4 consumers can continue around agreed dependencies. Keep useful checkpoints and continue named ready children rather than stopping after a short integration. Do not drift into the full 0.5 generator/faction rewrite or 0.6 runtime art generation without a new activation of that phase.

When acquisition decisions arrive, finish Blindside's actual earned loop. Do not add a guaranteed walking bypass, inject the featured ability, fake a foreign recipient or rewrite live AP logic to call it complete. The high-level self-item direction is now available, but qualification and pre-seed proof are still required.

## Evidence and deliverables

For each repair: failing reproduction, actual changed behavior, focused regression/control, source revision and scope. Combat uses cumulative events/deaths and normal visible aiming. Rooms are tested as hosted in a real candidate, including baseline and movement-assisted access and return. Resume kills/relaunches both processes. Menu pause includes incoming authorizations and input leakage, not just a frozen player.

Deliver the best coherent playable checkpoint with exact Windows fresh/resume steps, tested versus unrun platform, spoiler-light route and separate answers. Reconcile the inherited queue without changing historical closures into universal success. Full frontier once at a meaningful fixed integration checkpoint; preserve raw logs. No new work or watcher after the selected stop.


---

# Dess — prepared resumption brief

**This is prepared planning material, not a dispatched session.** When Skyiah resumes you, act on ready shared-contract/bridge work within the packet. No heartbeat, watcher, subscription or schedule. Do not assume other sessions are available until an actual channel/receipt establishes that.

## Start from the integrated delivery, not your older branch picture

Reference `a745637` on `claude/archipepsi-0-4-blindside`. Read the top frontier and `docs/ledgers/PROD_OV05.md`'s temporary shared-seam table. Prod's solo Python/schema edits were authorized and have reported evidence. Review/adopt/correct them once; do not erase valid work because another lane wrote it. The parent full-Amalgam/0.4 scope and all 85 OV05 children remain.

The owner liked the cell insertion and overall improvement, but rejected ordinary pressure plates latching forever, found direct Check bypasses in the selected minors, and was ambushed by respawned enemies after ordinary reload. The menu and both maps need a shared clear representation of owned items, named rooms, circuit relationships and actual blocked/open state.

## First contract deliveries

Read root `09_CONTRACTS_AND_DECISIONS.md` and the corresponding observations in `02`. Provide narrow real-consumer contracts for encounter continuation/old-save absence, ordinary live pressure versus explicit latch, and machine-controlled reward/return. Map and inventory view data should project existing authoritative state, not become a second progression/fold implementation.

Your half includes real producers/validators/exports and an accepted fixture or action sequence. Prod's half is physical runtime acceptance. Your consistency refusal is not proof that a crate was carried, an enemy died or a door was crossed. Mark the Godot half unrun if you have no engine; do not let missing runtime capacity stop independent bridge work.

For resume, do not derive clear state from Check ownership or assume missing legacy fields mean no enemies. For reward gates, preserve all allocated identities and actual AP prerequisites. For pressure, do not replace one impossible route with another by deleting LATCH without a usable held-pressure solution. Ordinary plate behavior changes; the general permanent-state infrastructure stays.

## Close real boundaries rather than filing them forever

The owner accepted a local Echo from a self-addressed original. Develop that exact grant/retry contract; do not keep asking the old high-level B-1 question. B-2 needs actual functional qualification/fallback, and B-3 needs pre-seed AP representation. Do not invent an already-proven guarantee.

Continue the atom-grammar/delivery boundary for the twelve already implemented manipulation verbs. A new primitive that bypasses the accepted composition grammar is not a neutral mapping. Either implement the effective grammar or put a bounded interim authority change to the owner; no second ability system by stealth. Continue already-settled graph/Status/Gear consumers where ready; unknown prices block only their named domains.

## Art and future direction

D-11 is delivered, including the flat `pack_textures` table, exact pack role lookup, unchanged family fallback, status registry and universal hazards. Arty's old namespace blocker is stale relative to your/Prod's integration. Send her the actual contract and runtime revision, not another design proposal. Do not approve her packs for her.

The physical rift story and interference/access explanation are accepted. Signals are other worlds, not a mysterious caller; simulation explanations are superseded. `08` lists remaining chapter questions. Future 0.5/0.6 feature concepts are to be designed, not added as undeclared gates to existing seeds or used to defer full 0.4 obligations.

## Delivery discipline

Use lane-prefixed findings and one active writer per shared file. Each contract receipt names rule, schema/producer/consumer, refusal, persistence, migration boundary, test and revision. Keep effective authority copies/exports/AP constants synchronized through existing generation tools. Preserve unknown/unimplemented/prohibited distinctions. Run focused bridge checks, then the appropriate integrated checkpoint with Prod; do not compete with his live/sabotage runner for the same source/ports.

Deliver a compact readiness table that tells Prod exactly what he can consume and what remains blocked. No proof by JSON round-trip labelled as a restart, enum storage labelled as effects, or prose banning a future mode because it is unfinished.


---

# Arty — prepared resumption brief

**This handoff is prepared for the owner's later resumption instruction.** It does not start a session or authorize a watcher. Preserve your `4093ded` delivery and existing approved sources. Do not spend the next allowance continuing the 81-row catalogue before making the player's current interactions readable.

## What the owner actually wants now

The game is more fun and the cell insertion feels good. The current inventory is miserable. The new menu must be a **real 3D inward-facing four-face space**, with Glyph-made fonts/textures/icons, using the existing Caster's Guide/BG3-style equipment layout as the interaction reference. It turns through Settings, Inventory, 3D Map and Journal. Prod owns real geometry/rotation/input; you own the visual family and reliable imports, not a painted whole-screen replacement for live data.

Current controls and machinery blend together. Dark-green lever/door is the owner's matching-colour example. Distinct role silhouettes must be recognizable across an arena; artillery cannot merely be a wider version of another robot. Keep useful threat audio. The tiny receiver z-fight is low priority on a model being replaced; source-fix it during replacement, not as a separate polish project.

## Start with two usable visual slices

Read root `04_3D_MENU_MAP_AND_GLYPH.md` and `11_TOOLCHAIN_AND_ART_RECONCILIATION.md`. First deliver one coherent equipment panel/font/icon/state set for a live inventory face, plus shared circuit/blocked-exit/control symbols. Second deliver a distance-readable lineup of the existing enemies with actual scale, colliders, muzzle/sensor clearance and distinguishing shape/motion.

Inspect them through the actual Godot consumer/camera, not only an isolated turntable or enlarged Glyph pixels. Collaborate on revised puzzle bounds before remodeling a shutter/rail/glass panel. Art may not quietly create steps, block doors, move landing points or change an enemy's damage volume.

## Tooling

The inspected newer Glyph tooling is `87db9e20dd0c7cb1a1f7a3c617a47d5efa3526de`; preserve old `6c80b63` authoring sources. Use a separate checkout/new or copied project, actual command discovery and granted artist identity. Your earlier tool trial remains evidence at its scope; now prove the specific bitmap-font/panel/icon import into the target 4.5.1 menu. Glyph does not construct the menu geometry or its callbacks.

Opening/verifying older `.glyph` originals can write checkpoints—your report found that. Do not mutate approved sources during inspection. Keep editable source/revision, export path/hash, palette/metrics, state names and an actual in-engine render. A render is not approval. No full-library migration, tool PR merge, massive regeneration or certification-benchmark detour.

## The pack blocker has changed

Prod/Dess have delivered D-11 since your older coverage note. It uses optional `Zone.theme_pack`, a flat sibling `pack_textures` table keyed `<pack>/<theme>/<role>`, exact pack lookup then the unchanged family fallback, pack-aware caches and protected universal hazard roles. Read the delivered answer, consume it and update your stale blocker. Do not build a new loader or convert each game pack into a seventh/eighth house theme.

Seven kits are in progress; none was completed/approved in your preserved coverage. Catalogue 81/81 is historical catalogue coverage, not completed art or a fresh public count. Finish distinctive material treatments for a small existing pair before T08 expansion; the Twilight-versus-Forest issue is valuable evidence to address. Shared geometry is allowed. A recolour/folder does not meet the completed-pack bar.

The course candidate remains unapplied and awaits a visual ruling; 18/22 pitches change. Show the relevant before/after treatment rather than approving all of them yourself. Continue unblocked existing A15–A19 work only as its turn/authorization allows; no new authored-room roster or full future faction army invented to fill time.

## Delivery and stopping

Send coherent asset slices with dimensions, pivot/socket/state contract, source+export hashes, resource paths, actual consumer revision and review status. Geometry, variants, assemblies and packs have separate counts. Prod integrates reviewed permitted assets; no “installed” claim without receipt. SigmAudio is a supported cue-authoring reference, not permission to rebuild the soundtrack or its DAW.

Keep receipts brief, preserve negative and positive visual findings, and leave exact ready/blocked tasks. No watchers, recurring PR pings, self-approval or implicit promotion. Planning future mixed-world/faction/Temporal art is allowed within the brief; production of that future programme waits for its explicit activation.
