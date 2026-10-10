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

## Whether this collider is specifically an enemy — for the paths that
## mean enemies rather than targets.
static func enemy(collider: Variant) -> Enemy:
	if not is_instance_valid(collider):
		return null
	var node := collider as Node
	if node == null or not node.is_in_group("enemies"):
		return null
	return node as Enemy
