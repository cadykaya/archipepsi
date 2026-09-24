# EX50-011 — Passing Platforms

**Status:** REVISED_ON_PAPER
**Domain:** Moving rendezvous / traversal
**Scope:** Experimental 0.4 candidate; no required precision race or new mobility ability.
**Source baseline:** R-MOTION, R-INPUT, R-PERSIST, R-ACCESS. Bounded cyclic paths and call scheduling are proposed adapters. Dimensions and dwell times require physical testing.

## 1. Identity and the player’s decision

**Choose when to board one carrier so that it meets another where you can transfer.** The destination is not reachable merely by waiting on the first platform. The player has to understand two journeys and decide which moving frame to occupy.

The first carrier rises from an arrival berth to an upper maintenance shelf. The second traverses the room at an intermediate height and reaches the goal gallery. Their routes pass close enough for an ordinary transfer, but not continuously. The player can call and hold the horizontal carrier at a visible waiting berth before launching the lift, giving them control over the rendezvous rather than leaving success to a global clock.

The fun hypothesis is prediction through space: “By the time I get there, that platform will be beside me.” This is traversal judgment, not necessarily a deep logic puzzle. It earns its place by letting the player prepare, ride, observe and recover within a working transport system.

Stopping both carriers and making a static bridge is not the central solution. That belongs to Ratchet Orchard. Here the intended transfer uses one moving carrier meeting another whose motion then takes the player onward.

## 2. The room the player enters

Prototype chamber: 28 by 22 m, 12 m high. Arrival A is on the south floor. Vertical carrier V rises from y=0 to y=8 near `(0,0,8)`. Horizontal carrier H travels east-west at y=4, crossing near V and ending at an east goal gallery. Both decks are roughly 4 by 4 m with clear boarding edges and noncolliding travel paths.

A fixed recovery floor lies 3 m below the transfer level, with stairs back to A. A missed transfer is a short fall and repositioning, not automatic death into a bottomless void. Railings protect nonboarding sides but do not block the intended stepping direction.

```text
upper maintenance shelf y8: safe observation and recall
                 V rises through transfer height y4
west waiting berth -- H ---- rendezvous ---- H --> east goal gallery G
lower recovery floor: stairs back to south arrival A
```

V has an authored pause at y=4 of roughly 2.5 seconds during its upward trip. This broad window is visible as a docking slowdown, not a hidden grace period. For an initial timing model, H takes approximately six seconds from its west waiting berth to the rendezvous center, moving at 1.5 m/s. V rises to y=4 at a proposed 1.5 m/s and pauses there for 2.5 seconds. These values leave a broad overlap after a roughly one-to-three-second board-and-launch action; they are not final movement tuning. A local call at A can start H, while V's launch lever is on its own deck.

The proposed reference starts H, boards V from A, and launches V so its intermediate pause coincides with H's arrival. Exact timings must be tuned from actual board-and-interact durations, with the shared timing-margin rule as a minimum. The paper does not assume instantaneous boarding.

If the player stays aboard V, it continues to the upper shelf, where they can safely recall either carrier and try again. The shelf is an observation position, not a sealed dead end.

## 3. The physical and signal components

**S:** a multi-stop LIFT, a horizontal PATH_MACHINE, moving-platform velocity inheritance, safe landing floors, call buttons and local selectors.

**B:** a finite shuttle schedule for H: WEST HOLD, TRAVEL EAST, EAST HOLD, TRAVEL WEST. It uses known paths and explicit dwell states. It is not an autonomous navigation system.

**B:** V's intermediate docking pause. Its control visits y=4 before y=8, with the pause duration declared in the package. A destination change or STOP follows the normal mover rules, and occupancy does not secretly speed up or slow down the schedule to rescue the player.

**S/B:** call controls at A, the upper shelf and G. Each selects a destination or releases a waiting carrier. Their sightline and access are authored. A player on a stopped carrier has an onboard emergency-return control or a safe fixed egress, not an inaccessible remote button.

The true output is physical arrival at G. A sensor may remember that the route was visited, but it does not replace walking off H onto the goal gallery. No ring checkpoint, target count or timed-run success flag is involved.

## 4. Behavior and state

Initially V waits at A and H waits at WEST. Calling H toward EAST begins its travel. V's onboard launch sends it through the intermediate stop to the upper shelf. Their motions are independent; the player chooses the relative start times.

V pauses at y=4 for its visible docking interval, then continues. H moves through the rendezvous at a proposed slow service speed, giving a broad lateral overlap. The player retains inherited platform velocity on leaving either deck. That means the actual transfer must be tested with the controller, not represented as a teleport between platform centers.

STOP holds the selected carrier. Resume follows its saved destination. Power loss holds both. A stopped carrier may not resume merely because the player lands on it unless that is explicitly the chosen call behavior; the first version requires a visible command.

The carriers do not collide during a mistimed meeting. Their sweeps are offset to leave a small safe step or gap between decks at the transfer plane. Neither can crush the player against the other's railing. The fixed recovery floor remains below all transfer attempts.

Arriving at G can release a permanent service stair down to A, making later traversal quick. The stair is not required to start the first attempt and does not depend on hitting a “transfer successful” trigger midair.

## 5. A complete reference approach

The player arrives at A and sees both carriers complete a slow demonstration cycle or inspects their paths while they wait. From A, the east goal gallery is visible beyond the horizontal route. The upper shelf clearly is not the same destination.

They call H from WEST toward EAST. They step onto V and operate its onboard launch. V rises. The player watches H approach from the west while the lift reaches its intermediate docking height.

During V's broad pause, H's deck overlaps the transfer region. The player steps or makes an ordinary short jump onto H. There is no hidden momentum cancellation; the landing uses the real movement controller. H then carries them east to G.

They walk off onto the fixed gallery, perform the goal interaction and release the service stair. They descend to A by the fixed route. Neither carrier is needed to escape after the goal.

If the first timing is late, the player stays on V rather than leaping at an impossible target. V reaches the upper shelf. From that safe position they can send H back west and recall V to the appropriate start, then retry. A failed plan does not cost a life or force a whole room reset.

The reference sequence requires only walking, a short ordinary transfer and local calls. Its timing window must include an inexperienced player's boarding delay. The prototype should not assume expert animation cancels.

## 6. Alternative approaches and toolkit effects

A patient player can use STOP to hold H near the rendezvous, ride V to the intermediate plane, transfer onto the stationary H, then restart it from its onboard control. This is a legitimate lower-pressure solution. It sacrifices speed but tests the same understanding of destinations and ownership of the moving frame.

A faster player can transfer without V's pause being fully used, retaining motion and arriving earlier. That is optional execution expression, not a required rating system.

A qualified grapple may reach H from the upper shelf or another authored anchor. A blink may bridge a wider momentary separation if its range, visibility and landing checks permit it. The generator should not increase carrier separation to erase those advantages.

A signal ability can remotely hold a visible movement input or power-enable node where legal, but must not directly set G's persistent arrival state. Temporary effects expiring must leave the same safe carrier-return or recovery-floor options.

The room does not promise carrying a large object between moving decks. A cargo version would introduce object support, transport and docking constraints and should be developed separately rather than counted as already supported by the player transfer.

## 7. Combat, traversal, and local purpose

The transport system serves intersecting maintenance routes: one reaches an upper service shelf, the other crosses to the cargo gallery. Their rendezvous is useful because a person can transfer between them.

The first prototype has no enemies. A later encounter could put ordinary gunners on fixed galleries so moving with H changes cover and angle. It must retain a safe inspection period and must not demand simultaneous precision aiming and a narrow jump simply to make the room “hard.”

The lower recovery floor is important to the experience. The player can make a decision, see it fail, and try a better one quickly. The room teaches movement prediction through feedback rather than punishment.

It should be possible to understand the two destinations from architecture. If H and V look identical and their end points are hidden, the puzzle becomes memorizing labels on a panel. Distinct deck shapes and visible tracks are functional presentation.

## 8. Stop, misuse, destruction, and failure

Missing H lands the player on the recovery floor. The actual maximum fall height and damage must be verified. A shallow visual void cannot secretly be a kill volume copied from another room type.

Calling a carrier away from a boarding edge should not pull the player into a wall. The call changes motion normally; the player can remain on fixed floor or board deliberately. Doors or boarding gates use their real safe interlocks.

A player who stops V between floors has an onboard return command. If its controls are destroyed or obscured, that would be a new failure state the prototype does not permit. Load-bearing machinery is non-destructible in this first version.

A local reset is available at A and the upper shelf, returning empty carriers to their initial berths. Reset while occupied uses the normal safe motion/checkpoint treatment, not instant relocation into a dock. No reset undoes G's released service stair or confirmed reward.

Repeated call presses cannot create multiple scheduled arrivals. Each carrier has one current destination and one motion state. An old delayed command must not resume travel after the player has explicitly stopped it.

## 9. Aftermath and persistence

Carrier poses, destinations and hold states are package-local. A stable save restores each at its saved pose before the player. A fresh phase is not drawn from a random clock on reload.

Transient dwell countdowns do not have to replay elapsed real-world time. On restore, a carrier in a dwell state can remain safely held until the player resumes, provided that behavior is consistent with the shared machinery contract and shown clearly. It must not instantly leave the platform the player is standing on because the application was closed for an hour.

G's service stair is room-persistent. Death after opening it preserves the shortcut. Before completion, death/reset restores the safe initial transport configuration, not a midair player with both platforms elsewhere.

A completed route is not automatically repeated on revisit. The carriers may remain usable for combat positioning or optional exploration, but ordinary return travel should use the shortcut if the player chooses.

## 10. Implementation and authoring plan

The minimum scene contains two carriers, three fixed destinations, one recovery floor and a handful of call controls. The only new scheduling behavior is a bounded intermediate dwell and a shuttle hold/release state. Do not build general train scheduling or a cinematic transfer controller.

Authoring must measure the world-space overlap duration, relative velocity at transfer, railing collision, jump landing and recovery-floor coverage. Declared periods alone do not prove any of those properties. A useful capture records the continuous body trajectory from A through the transfer and out at G.

The lowest-pressure solution must be present too: stop H near the transfer, ride V, board H, restart. If no accessible control permits that sequence, the paper alternative is false and must be removed or built rather than left as reassuring prose.

The full expression can add a visible drive loop, destination signs and mechanical docking sounds. A later faster variant should not reduce the timing window below the guarantee merely because the first room was easy.

## 11. Why it might be fun—and why it might not be

The intended feeling is making a moving connection: the player predicts a meeting, commits to one carrier, and transfers into a new trajectory. The environment moves them in a way they deliberately prepared.

The strongest failure is that waiting dominates play. Another is that players cannot distinguish a bad plan from bad collision. Short cycles, broad overlaps and a forgiving recovery floor are the first controls against those failures.

Observe whether players choose when to launch, stay aboard safely after a missed meeting, and discover the stop-and-transfer alternative. A player falling repeatedly without understanding why indicates a problem even if an automated route can perform the transfer perfectly.

For correctness, a continuous body run from A must board V, transfer to H with all motion active and reach G. A counterpart shifts H's track so no overlap exists; the same commanded timing must not be reported successful. The positive test must not snap the player onto H or disable its railing to pass.

Repeat-use interest comes from faster optional transfers and the later shortcut, not a mandatory repeated commute.

## 12. Distinctness review and unresolved decisions

Nearest existing: **SP-07 The Slingworks**, which offers a network of launch choices and combat repositioning. Passing Platforms does not solve an arc or select a launch destination. It asks the player to occupy one moving frame at the moment another becomes available.

Nearest experimental: **EX50-008 Ratchet Orchard.** Orchard prepares stopped architecture through relative phase. Passing Platforms uses motion to carry the player after the meeting. The patient stopped-H alternative is intentionally limited; stopping both and creating a permanent bridge would erase this distinction.

The unresolved question is whether the two timing plans are understandable without an explanatory overlay. No new controller behavior is assumed to make the transfer feel good. That remains a small, necessary prototype test.

**Implementation evidence:** none.
**Human playtest evidence:** none.
