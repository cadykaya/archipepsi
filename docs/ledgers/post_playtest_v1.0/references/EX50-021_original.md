# EX50-021 — Counterfire Arcade

**Status:** REVISED_ON_PAPER
**Domain:** Combat positioning / external input source
**Scope:** Experimental 0.4 candidate. Enemy projectiles operating a receiver are a declared bounded extension, never the sole guarantee for required progression.
**Source baseline:** R-INPUT, R-MOTION, R-SIGNAL, R-PERSIST, R-ACCESS. Projectile speed and encounter layout are untested proposals.

## 1. Identity and the player’s decision

**Use an enemy's committed shot as the input to a machine, then stop being where that shot is going.** The player positions themselves to make an ordinary hostile action useful.

An emergency impact receiver stands behind a narrow exposed firing lane. From the arrival side, the player cannot directly address its active face because a steel hood covers the reverse angle. A gunner on the opposite gallery can shoot that face when aiming through the lane at the player. Letting it commit a projectile and then stepping behind cover triggers a short opening in a service shutter.

The receiver does not recognize “enemy successfully baited” as a scripted event. A real projectile must hit its real active surface. The player's movement changes the enemy's aim, and the projectile's travel supplies the interval in which the player can leave the line.

There is a slower baseline route to the receiver's front or a manual release after clearing the gallery. Killing the gunner must not permanently remove the only way to finish the room.

## 2. The room the player enters

Prototype chamber: 24 by 18 m, with a south arrival arcade and a north gunner gallery. A central lane is roughly 16 m long. The impact receiver is mounted near the south end, behind the player's bait stance from the gunner's point of view. A fixed side alcove lies one short step away from that stance.

The service shutter is on the east wall. When the receiver is hit, it opens for a proposed eight-second interval, revealing a short supported route to an upper flank and a manual persistent release. A longer west stair reaches the gunner gallery through ordinary cover and combat, from which the receiver's front is also visible.

```text
N: gunner gallery; ordinary west stair reaches it
            committed projectile path
       fixed lane baffles
S: receiver face <- bait stance -> side alcove / arrival A
E: timed service shutter -> upper flank and permanent manual release
```

The gunner uses a visible projectile attack with a fixed trajectory after launch, not an instantaneous hitscan or homing shot. The source weapon profile and AI must actually support that behavior. A proposed projectile speed around 15–20 m/s over the visible lane gives time to sidestep, but the real telegraph, player acceleration and geometry must be measured.

The receiver's hood blocks the player's direct reverse shot. It does not make the receiver immune to player projectiles from a legitimate front angle. The west route therefore remains a clear fallback and a potential alternative strategy.

## 3. The physical and signal components

**S:** ordinary projectile collision, a ranged enemy profile, fixed cover, a shootable input, TIMER and safe shutter actuator.

**B:** the receiver accepts qualifying projectile hits from both player and hostile sources while preserving damage provenance. Existing player-only target filters must not be assumed to support this. The receiver emits one pulse per valid hit; it does not award combat credit or damage the player by proxy.

**S/B:** the gunner commits aim at the moment of firing and its projectile continues along that trajectory. If the available enemy only uses hitscan or homing attacks, select or author a bounded compatible projectile profile. Do not claim the current AI already does so without testing it.

**S:** the eight-second TIMER refreshes on another valid receiver hit. Its output opens the service shutter. The manual release beyond the shutter accepts a permanent return/shortcut condition.

**B:** receiver-face and hood geometry. A shot from behind hits the hood; a shot from the gunner side can hit the active plate. This is physical directionality, not an owner-ID exception.

No mind control, enemy-operated console, or special “baited” AI state is required. The enemy simply aims at a visible player using its ordinary attack.

## 4. Behavior and state

Initially the service shutter is closed, the receiver uncharged, and the gunner occupies its gallery. The player can enter the bait stance without automatically starting a timed minigame. The gunner's actual perception and firing telegraph determine when a shot is committed.

A qualifying hit on the receiver starts or refreshes its timer. A missed shot hits ordinary geometry and changes no machine state. A projectile intercepted by the player's cover cannot also trigger the receiver behind it.

The shutter opens under normal movement rules. Timer expiry requests closure under its safety interlock. A player already in the doorway is not crushed, and the upper manual release provides a permanent way back once reached.

The gunner may die at any point. That changes the encounter, not the receiver's input contract. The west route remains available, allowing the player to approach a valid firing angle or use the manual machinery path.

Power loss closes the uncompleted shutter safely and disables the receiver's active circuit. It does not resurrect the gunner. The permanent manual release is restored through its accepted state, not by replaying a projectile event.

## 5. A complete reference approach

The player arrives under the south arcade and sees the gunner's firing lane. The receiver's plate and conduit are visible behind the bait stance, while its hood explains why a reverse shot from A does not reach the active face.

They step into the lane until the gunner begins its visible attack. They wait for the projectile to be committed, then move into the nearby alcove. The projectile passes through the vacated stance and hits the receiver. Its actual hit pulse lights the conduit and opens the east shutter.

The player leaves the alcove and runs a short supported route through that shutter. The timer has enough margin for this movement and the opening animation. They reach the upper manual release, operate it, and secure the shortcut permanently.

From the upper flank they can fight the gunner normally or leave it alive while continuing to the goal. The actual goal interaction occurs beyond the released route. Returning uses the permanently open service connection, not another required baited shot.

This sequence assumes neither an invulnerable bait stance nor a scripted enemy miss. A mistimed dodge can hurt the player under ordinary combat rules. Its practical fairness requires a real encounter prototype.

## 6. Alternative approaches and toolkit effects

The conservative solution uses the west stair, fixed cover and ordinary combat to reach the gunner's side. From there, a baseline ranged shot can operate the receiver directly, or a reachable manual release can provide equivalent access. This guarantees that killing the gunner does not destroy required progress.

A mobility tool may cross from the arrival arcade to the service route while the shutter is briefly open, giving a more forgiving timing. A sufficiently capable route to the upper flank may bypass the receiver entirely if the physical landing is legal. The goal should accept that access.

A projectile-deflection ability would offer a distinct approach only if such a supported tool actually exists. It is not assumed from the word “parry.” The baseline bait uses a committed ordinary shot and movement, not reflection.

A signal tool can temporarily operate a visible shutter input where legal, but cannot directly set the permanent shortcut state. It must leave a safe return when the effect expires.

A player can deliberately remain in the lane and absorb damage while allowing a projectile to hit a receiver only if the projectile's real penetration behavior permits it. The design must not assume the same shot passes through the player merely to complete the puzzle.

## 7. Combat, traversal, and local purpose

The receiver is an emergency impact trip for a security shutter. Its placement makes sense as a control exposed toward the dangerous lane and protected from casual damage on the service side. The player uses hostile fire to operate that protection from an otherwise inconvenient position.

The gunner has a clear job: cover the central approach. Its position and line of fire explain its presence before the player arrives. It does not need a long patrol schedule or a simulated maintenance routine to make this encounter coherent.

The opened route changes the fight by providing a flank. It is not merely a box that dispenses loot after a successful dodge. The player can exploit the changed geometry immediately.

The alternative west approach is important. The room should offer a choice between reading and using the gunner's attack or fighting through the ordinary route. Neither is automatically the designer's morally correct method.

## 8. Stop, misuse, destruction, and failure

A missed bait leaves the player in the arcade with another attempt possible. The gunner has ordinary ammunition behavior; required progression cannot depend on an enemy with a finite unrecoverable shot supply unless the manual fallback is complete.

Killing the gunner early leaves the west route and receiver-front access. Destroying the receiver itself is not allowed in the first version; it is a machine input with visible durable housing. A later destructible control must have another repair or access route.

A projectile striking the receiver after the player has left the room may refresh a transient timer but must not produce duplicate rewards or reopen a stale scene object. The machine and projectile lifecycle need ordinary validity checks.

The shutter's timer can expire while the player approaches. The safe interlock and retreat route prevent an unavoidable crush. The player may wait for another shot or use the west route rather than restarting the whole Zone.

A local reset does not respawn enemies for repeated rewards after an encounter-clear flag has been accepted. It restores only unfinished machinery and the appropriate encounter state under the existing rules.

## 9. Aftermath and persistence

The receiver timer is ephemeral. The manual shortcut release and confirmed goal are persistent. Saving after opening the shutter but before reaching the release must restore a safe player position with a legitimate route, not an expired timer trapping the player in a thin wall volume.

Enemy position and health follow the source encounter persistence rather than a new puzzle-owned copy. An accepted cleared encounter is not undone by resetting the receiver.

The receiver's last hit source may be kept for diagnostics, but it is not the progression authority. A player projectile and hostile projectile operating the same surface lead to the same machine state.

On revisit, the service route remains open after its accepted release. The player is not required to bait the gunner again, and a dead gunner does not invalidate the room.

## 10. Implementation and authoring plan

First verify a real hostile projectile can hit the receiver and produce the same input pulse as a player projectile, without double-counting impact or changing damage provenance. Then build the lane and sidestep alcove around a compatible enemy attack profile.

The authored requirements are the bait stance, actual enemy muzzle, committed projectile trajectory, receiver active face, protective hood, sidestep clearance and the short shutter route. A camera ray from the player to the receiver is not sufficient evidence for the hostile shot path.

The minimum scene needs one gunner, one receiver and two access approaches. Do not add multiple enemies, ricochets or a sequence of projectile-operated targets before the single relationship is readable.

The full expression adds clear impact machinery and attack telegraphs. A more advanced variant may use different projectile sources, but each must preserve the fallback when the source disappears.

## 11. Why it might be fun—and why it might not be

The hypothesis is turning an adversary's action into environmental leverage. The player feels clever because the gunner's normal attack operated a real machine after the player changed position.

The strongest failure is that the gunner's aim or firing cadence is too unpredictable. Another is that the bait stance is so explicitly marked that the action becomes a scripted quick-time event. The prototype needs readable geometry and a broad dodge opportunity without an on-screen “stand here now” instruction.

Observe whether players predict the shot-receiver relationship, whether a miss is understandable, and whether they choose between baiting and the west route. If the only successful players wait for instructions, the scene has not communicated its system.

For correctness, a committed hostile projectile must pass through the vacated stance and hit the actual receiver while the player reaches cover. A counterpart adds a real blocker between muzzle and receiver; the shutter must not open. Killing the gunner before any hit must still leave the fallback route completable.

Repeat-use should exploit the persistent flank or ordinary combat, not demand the same bait each visit.

## 12. Distinctness review and unresolved decisions

Nearest existing: **SP-25 Defense Grid.** Counterfire Arcade is not a broad choice of which security systems to activate. It uses a hostile projectile as a physical input whose trajectory the player influences by positioning.

Nearest experimental: **EX50-025 Watchful Bulkhead.** That candidate uses an enemy's aiming rotation to move attached cover. Counterfire uses a committed projectile after firing; moving the enemy's cover alone cannot operate the receiver.

The critical unsupported dependency is projectile-source acceptance at the receiver. It is bounded and explicit. The actual fairness of the bait remains unverified and must be tested before this room can be considered more than a coherent proposal.

**Implementation evidence:** none.
**Human playtest evidence:** none.
