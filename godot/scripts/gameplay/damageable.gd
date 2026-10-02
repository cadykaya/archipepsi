class_name Damageable
extends RefCounted
## Anything a hit can land on.
##
## Every damage path in the game used to test `is_in_group("enemies")`
## before calling `take_damage`, which was fine while enemies were the only
## thing that could be hurt. S9 added a breakable wall panel — an
## affordance whose whole contract (§13.1) is that it opens to "an owned
## action that can deal impact damage at or above a threshold" — and
## nothing could touch it. Not the Static Pulse, not a melee swing, not a
## projectile, not a slam. `BreakablePanel.take_damage` was unreachable
## code, and the capability meant to pay for the affordance never mattered
## because the affordance could not be used at all.
##
## So the question the damage paths ask is now "can this be hurt", not "is
## this an enemy". Target SELECTION keeps asking the narrower question:
## `scan_mark` marks enemies and `grapple_pull_target` pulls them, and
## neither should reach for a wall.

const GROUP := "damageable"

## Anything a HOSTILE projectile is allowed to operate.
##
## A strictly narrower question than `GROUP`, with a declared answer, and
## the narrowness is the point. EX50-021 turns an enemy's committed shot
## into the input to a machine, and the shortest way to do that would be
## to let an enemy projectile call `Damageable.hit` on whatever it
## touches. That is not a bounded extension -- it is a change to what
## every existing damageable node means. A gunner would break the
## `BreakablePanel` guarding an affordance, and the capability that
## affordance charges for would stop mattering, exactly as it once did
## for the opposite reason.
##
## So a machine OPTS IN, one node at a time, and nothing that has not
## opted in changes behaviour at all. EX50-021 §2 calls this "a declared
## bounded extension"; this group is where the declaration lives.
const HOSTILE_INPUT := "hostile_input"

## The damageable node behind a collider, or null.
##
## Colliders reach here from raycasts, area overlaps and group scans, so
## the input is deliberately `Variant`: half the call sites hold a
## `hit["collider"]` whose type nothing has narrowed yet.
static func of(collider: Variant) -> Node:
	if not is_instance_valid(collider):
		return null
	var node := collider as Node
	if node == null or not node.is_in_group(GROUP):
		return null
	return node

## Deal damage, and report whether THIS hit was the one that finished it.
##
## The same signature `Enemy.take_damage` already had, because every call
## site was already speaking it — the only thing that changes is which
## nodes are allowed to answer.
static func hit(collider: Variant, amount: float,
		direction := Vector3.ZERO, knockback := 0.0) -> bool:
	var node := of(collider)
	if node == null:
		return false
	return bool(node.take_damage(amount, direction, knockback))

## The node behind a collider that has declared it accepts hostile fire.
##
## Separate from `of` rather than a flag on it, because the two are asked
## by different callers for different reasons and a boolean argument
## would let a caller ask the wrong one by accident.
static func hostile_input(collider: Variant) -> Node:
	if not is_instance_valid(collider):
		return null
	var node := collider as Node
	if node == null or not node.is_in_group(HOSTILE_INPUT):
		return null
	return node


## Whether this collider is specifically an enemy — for the paths that
## mean enemies rather than targets.
static func enemy(collider: Variant) -> Enemy:
	if not is_instance_valid(collider):
		return null
	var node := collider as Node
	if node == null or not node.is_in_group("enemies"):
		return null
	return node as Enemy
