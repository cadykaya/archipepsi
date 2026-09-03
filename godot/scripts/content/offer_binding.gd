class_name OfferBinding
extends RefCounted
## THE PRODUCTION CALLER for movement offers (owner ruling, 2026-09-03).
##
## `MovementPackage` has carried the offer rules since P3.0 and until now
## had no caller outside a test file, all eight of whose call sites
## passed a constant instead of geometry. So a shell could declare a rail
## through a pylon, a launch into a machine and an anchor with no hang
## space, and every gate in the project would report the room clean --
## the rules and the geometry had never been in the same room.
##
## WHY THIS IS A SEPARATE STAGE, and not `ContentInstantiator`'s job.
## `build_chamber` returns a room whose root is DETACHED: nothing is in
## the scene tree yet, so no collider is registered with the physics
## server and `get_world_3d()` is null. Every probe would answer "nothing
## there", which is the vacuous pass this whole change exists to remove.
## Colliders become real one physics frame after the root enters the
## tree, and that moment belongs to whoever owns the tree -- so the
## binding is offered here as an explicit post-instantiation stage and
## called by `ZoneController` once the Zone is live.
##
## VALIDATION, NEVER REPAIR. A declined offer is reported and the room
## plays without it, exactly as `MovementPackage` always intended: an
## offer is an opportunity, and a room that loses one is still a room.
## Nothing here edits content, and nothing here is allowed to decide a
## room is fine because it could not measure it.

## Validate one live room's offers. `room` is a `build_chamber` result
## and `root` must already be in the scene tree.
static func validate(root: Node3D, room: Dictionary,
		who := "offers", only: Array = []) -> Dictionary:
	return MovementPackage.consume(root, room, space_of(root), only)

## The physics space a live room sits in, or null.
##
## Named rather than inlined because "which space" is exactly the
## question a caller gets wrong: a room's own world, not the caller's.
static func space_of(root: Node3D) -> PhysicsDirectSpaceState3D:
	if root == null or not root.is_inside_tree():
		return null
	var world := root.get_world_3d()
	if world == null:
		return null
	return world.direct_space_state

## Validate every chamber of a live Zone and report what was declined.
##
## Returns one entry per chamber that had something to say, so a caller
## can log or surface it. A REFUSAL is carried through as a refusal --
## `refused` is true when the room could not be measured at all, and a
## caller must never read that as "no problems found".
static func validate_zone(chambers: Array) -> Array:
	var out: Array = []
	for entry: Variant in chambers:
		var record: Dictionary = entry
		var node := record.get("node") as Node3D
		var build: Dictionary = record.get("build", {})
		if node == null or build.is_empty():
			continue
		var named := str((record.get("chamber", {}) as Dictionary)
				.get("id", "chamber"))
		var verdict := validate(node, build, named)
		if bool(verdict.get("refused", false)) \
				or not (verdict["declined"] as Array).is_empty():
			out.append({"chamber": named, "verdict": verdict})
	return out

## The one-line summary a log wants, for a `validate` result.
static func summarise(named: String, verdict: Dictionary) -> String:
	if bool(verdict.get("refused", false)):
		var first: Dictionary = (verdict["declined"] as Array)[0]
		return "%s: offers NOT MEASURED -- %s" % [named, str(first["why"])]
	var parts: Array[String] = []
	for raw: Variant in verdict["declined"] as Array:
		var item: Dictionary = raw
		parts.append("%s (%s): %s" % [str(item.get("name", "?")),
				str(item.get("kind", "?")), str(item.get("why", "?"))])
	return "%s: %d offer(s) built, %d declined%s" % [named,
			(verdict["built"] as Array).size(),
			(verdict["declined"] as Array).size(),
			("" if parts.is_empty() else " -- " + "; ".join(parts))]
