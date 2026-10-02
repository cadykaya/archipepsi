# EX50-033 — Unweighted Switch

**Status:** REVISED_ON_PAPER
**Domain:** Status as a rule change / support versus sensing
**Scope:** Experimental 0.4 candidate. The player changes what a plate reads without removing the object that physically supports the route.
**Source baseline:** R-STATUS, R-INPUT, R-SIGNAL, R-PHYSICS, R-PERSIST, R-ACCESS. This uses semantic mass class, not an invented kilogram reduction.

## 1. Identity and the player’s decision

**Keep the object where its shape is useful while changing the property that makes the room react badly to it.** Moving the crate away opens the shutter but removes the step needed to reach it. Changing the crate's mass class can do both jobs at once.

A heavy service crate fits into a shallow recess below an upper doorway. Its top is a useful stepping surface. The recess floor is also a HEAVY-class plate, and that plate closes the upper shutter while a heavy object rests on it. The player discovers a contradiction: placing the step they need closes the route they want.

A local LIGHTENED applicator changes the crate from HEAVY to the next lower semantic class. The plate releases, but the crate remains collidable and physically present. The shutter opens and the player uses the same object as a step.

This is not a colored key or “cast the correct spell on the highlighted box.” The room should show both roles before asking for the Status: moving the crate changes the shutter, and the crate's unchanged geometry still supports the player after its class changes.

## 2. The room the player enters

A 16 by 14 m service chamber has actual arrival A on the south floor. The north wall contains an upper doorway to G. Its sill is above a comfortable baseline jump from the floor but reachable with margin from the 1 m high crate top; the exact heights must be measured against the chosen controller.

Below the doorway is a 2.4 by 2.4 m recess, bounded by real side walls. The heavy crate is about 2 m square and moves along a short guided service track from a parking place into the recess. The plate occupies the entire usable recess floor. Moving the crate slightly sideways cannot leave it as a valid step while evading the sensor by an arbitrary millimetre.

```text
N: upper shutter -> goal G and manual hold-open bolt
   [crate top becomes a step]
   [HEAVY-class plate filling the recess]
W: local applicator and fixed firing stance
S: A, crate parking position and service drive
```

The local applicator is reachable from A and can aim at the crate both in its parking position and in the recess. The route from the firing stance to the crate and upper sill is short and supported. There is no need to change loadout mid-room.

A fixed return stair becomes available from G. Before completion, the player can always retreat to A and move the crate back out. The shutter's closing volume cannot seal the player inside the recess.

## 3. The physical and signal components

**S:** a semantic pressure plate requiring HEAVY, a NOT node, a safe-closing shutter, a collidable object and the LIGHTENED Status. The plate accepts this object category; the player's own mass class does not count toward its threshold in this arrangement.

**S:** LIGHTENED lowers mass class one step under the Amalgam's Status rules. It does not remove collision, shrink the crate, erase gravity or necessarily alter its numerical `mass_kg`. The plate therefore changes because it reads class, while the stepping surface remains.

**B:** a guaranteed local applicator with an explicit source/Status/target binding for this crate. Required progression cannot depend on a random proc succeeding eventually. The local source must use the written guaranteed-application route or an equally explicit accepted binding.

**S/B:** a short service drive moves the crate between parking and recess. The track is physical and bounded; it does not teleport the crate to a puzzle socket. A qualified manipulation tool may move it instead if the actual constraints permit.

**S/B:** a manual hold-open bolt on the far side of the shutter. Reaching and operating it makes the useful crossing persistent without requiring the temporary Status to remain active forever.

## 4. Behavior and state

Initially the crate is parked, the plate is OFF and the shutter is open. The upper sill is visible but not comfortably reachable from the ground. The player can see why a step would help.

Moving the heavy crate into the recess turns the plate ON. Through NOT, the shutter's open command becomes false and the shutter closes under its safe interlock. The change is immediate and readable: the crate solves the height problem while creating a sensing problem.

Applying LIGHTENED makes the crate's class MEDIUM for the Status duration. The plate no longer has a qualifying HEAVY occupant, so it releases. The shutter opens. The crate remains a solid step; the player can climb it and reach the upper doorway.

A repeated valid application refreshes the duration rather than stacking infinite time. A visible Status indicator and the plate's own class glyph explain why it has released. The room does not substitute a generic eight-second race counter for the actual temporary property.

On expiry, the crate becomes HEAVY again and the shutter attempts to close. Safe closure protects a player occupying the doorway. Once the far bolt is engaged, the accepted hold-open condition overrides the temporary sensing route and the player can return safely.

## 5. A complete reference approach

The player enters A, sees the open upper doorway and tries the obvious lower approach. The sill is too high from the floor, while the nearby crate has a useful top surface. They move it into the recess using the service drive.

The plate depresses and the shutter closes. The player can reverse the drive and watch the shutter reopen, demonstrating that the crate's presence caused the change. That reversible test teaches the relationship before any Status is used.

They return the crate to the recess, use the local applicator and see the crate's class presentation change. The plate rises and the shutter opens while the crate remains in place. They climb the crate, cross the sill and reach G.

From the far side they engage the hold-open bolt, then operate the actual goal. The temporary Status may now expire without closing the accepted route. The player leaves by the fixed return stair or through the held-open doorway.

The reference timing is short enough to provide generous margin. The prototype must measure from application to safe crossing using the ordinary controller, not calculate it solely from straight-line distance and nominal walk speed.

## 6. Alternative approaches and toolkit effects

A sufficiently strong jump or mobility tool can reach the open upper doorway before the crate is inserted. That is a valid shortcut. The game should not demand that the player close the shutter and solve the Status interaction afterward.

A legal signal override can hold the shutter input open temporarily while the crate remains heavy. That substitutes a different rule intervention for LIGHTENED. It must respect the target node's legality and actual duration, and it remains an optional advantage rather than the required guarantee.

A lighter object with a suitable stable top could replace the heavy crate if the room genuinely provides one and its shape fits the recess. The plate reads class, not a special crate ID. The minimum version provides one controlled object so the intended relation is clear, but the implementation must not reject legitimate substitutions by name.

A player can stand in the shutter opening as the Status expires, relying on the existing closure interlock to keep it from crushing them. That may hold the door temporarily but does not teleport them to the goal. If this creates a valid route, it is normal physical behavior, not a bug to punish.

A mass-field ability that changes kilograms without changing the plate's semantic class may not release the plate. The feedback must state the actual class requirement so the player can distinguish this from a broken spell. A different authored version using WEIGHT_THRESHOLD would be a different sensor contract.

## 7. Combat, traversal, and local purpose

The recess is a service lockout: a heavy maintenance load closes the upper access while equipment is positioned beneath it. The player exploits the fact that the safety sensor reads a property distinct from the object's collision shape.

The minimum version is noncombat. The first exposure to a Status changing a sensor should be readable. Adding enemies who knock the crate off its track would create noise in the causal lesson.

The room's interest is not the duration alone. Even with a generous or manually refreshed Status, the player has to recognize that the object can remain useful while no longer satisfying the plate. That is the conceptual step.

The far bolt gives a tangible aftermath. The player turns a temporary opportunity into stable access by reaching the other side and operating real hardware. A completion toast alone would not explain why the route remains open after LIGHTENED expires.

## 8. Stop, misuse, destruction, and failure

If the player misses the applicator shot, the crate remains heavy and nothing changes. The source is reusable, and a missed shot does not consume a scarce AP currency. The player can reposition at the fixed firing stance.

If the Status expires early, the shutter closes safely. The player can retreat or refresh the effect. There is no instant failure that resets the crate and returns them to A while they are still standing on it.

The crate is constrained or sufficiently stable that the player's ordinary landing does not unpredictably roll it out of the recess. LIGHTENED increases impulse response under its actual rules, so a free loose crate could become less stable. The prototype must either support that deliberate behavior or use the authored guide track; it cannot ignore the Status's other effects.

Destroying the required crate is disallowed or recoverable through the package reset. A reset does not clear the accepted far bolt. Optional debris cannot accumulate into HEAVY on this semantic plate; the source contract explicitly distinguishes that from summed mass.

Power loss closes the shutter under interlock and holds the crate drive. The far-side return route remains available after accepted completion. No power event may leave the player sealed in an upper pocket with no way down.

## 9. Aftermath and persistence

Crate position and far-bolt state have their respective package-local and persistent scopes. LIGHTENED itself is ephemeral. On restore, the crate's original class returns, then the plate and shutter command are recomputed alongside the persistent hold-open condition.

A save cannot retain the plate OFF merely because it was OFF during the Status. That would turn a temporary property into a permanent unexplained sensor state. The accepted bolt, not a cached voltage, preserves access.

The player should reload at a safe supported point. If the Status was active before saving and its removal changes the shutter, the reconstruction must apply that change before placing the body in a conflicting position.

After completion the crate can remain beneath the open doorway as evidence of the solution. Removing it may remove the convenient step but not the fixed return stair. The goal stays claimed, and reapplying LIGHTENED grants no duplicate reward.

## 10. Implementation and authoring plan

The minimum prototype is one HEAVY-class object, one class plate, one shutter and a local guaranteed Status source. Before building a platform room, verify that the same object remains collidable while the plate's output changes under LIGHTENED.

Then add the recess and sill. Measure the ordinary floor-to-sill and crate-to-sill routes. A design that is trivially jumpable without the crate may still be a valid shortcut for an upgraded build, but the introductory relationship should not disappear for the actual baseline unless deliberately chosen.

The new work is the local guaranteed applicator and its correct sensor integration. The Status itself is specified, not verified here. The guide track and far bolt are small authored mechanisms, not a general status-crafting system.

The decisive negative control replaces the class plate with a summed-kilogram sensor without changing the Status. The expected effect should then differ if kilograms are unchanged. That control prevents the implementation from conflating two distinct mass vocabularies.

## 11. Why it might be fun—and why it might not be

The hypothesis is resolving a physical contradiction by changing one property rather than moving the object away. The player discovers that “still a step” and “no longer heavy enough for the plate” can be true simultaneously.

The strongest failure is a one-time obvious spell lock. If every room presents one highlighted heavy crate and one nearby LIGHTENED source, the relation becomes a color-matching task. This candidate is an introduction or a component in a later richer room, not a template to repeat indefinitely.

Another failure is inconsistent mass presentation. If the crate visibly shrinks or loses collision when lightened, the intended distinction is broken. If it slides wildly under the player, the concept may be correct but the interaction unpleasant.

Proposed controls check class, plate output, crate collision and shutter state before, during and after the Status. A deliberately disconnected plate consumer must make the expected shutter response fail. The full route is then attempted with all triggers active and the real expiry running.

Human review asks whether the player can explain why the door opened while the crate stayed. That understanding matters more than how quickly they crossed.

## 12. Distinctness review and unresolved decisions

Nearest existing: **SP-20 Scale Field.** The old seed changes physical scale broadly. Unweighted Switch changes one precisely specified sensed property while preserving shape and support. It does not require resizing anything.

Nearest experimental: **EX50-002 Moment Yard.** Moment Yard changes torque by relocating a known load. This room changes a sensor's class reading without relocating the load. Moving the crate off the plate defeats its other useful role and is therefore not an equivalent solution.

The local Status source and guide-track stability remain implementation dependencies. The concept is intentionally compact; its first prototype should prove the property distinction before being combined with a larger 0.4 setpiece.

**Implementation evidence:** none.
**Human playtest evidence:** none.
