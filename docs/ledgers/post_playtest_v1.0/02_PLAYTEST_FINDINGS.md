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
