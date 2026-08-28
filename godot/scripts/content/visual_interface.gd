class_name VisualInterface
extends RefCounted
## The line between what a thing LOOKS like and what it IS (v0.9 S18).
##
## Authored art is coming, and it arrives as a replacement for a
## silhouette that was built in code. The danger is not that the new
## model looks wrong -- that is obvious and someone fixes it. The danger
## is that it looks right and quietly moves a hitbox, so a brute becomes
## harder to hit, a ledge becomes unreachable, or a required jump becomes
## a required jump plus a corner.
##
## The rule, stated so it can be tested rather than remembered:
##
##     MECHANICS COME FROM DATA. VISUALS COME FROM ART.
##     A VISUAL MAY NOT CARRY COLLISION.
##
## Concretely: an enemy's hitbox is a function of its ARCHETYPE, a
## player's capsule is a function of `Constants`, and neither is a
## function of theme, palette, mesh, or anything an artist supplies. So
## the same archetype built under every theme must produce byte-identical
## collision, and no node under a visual subtree may be a collision
## object.
##
## This file provides the checks. It draws nothing and decides nothing.

## Every collision shape under `root`, in depth-first order.
##
## An ORDERED LIST, not a map keyed by node path: an unnamed node gets an
## instance-unique auto-name (`@CollisionShape3D@157`), so two builds of
## the same thing never share a path and a path-keyed comparison reports
## every shape as missing. Structure order is stable across builds and
## still catches a shape that moved, resized or changed type.
##
## Each entry is `{"shape": String, "size": Vector3, "position": Vector3}`.
## A shape type other than a box reports its class name, so a silent
## change from box to capsule cannot read as "unchanged".
static func collision_profile(root: Node3D) -> Array:
	var out: Array = []
	_walk_collision(root, out)
	return out

static func _walk_collision(node: Node, out: Array) -> void:
	if node is CollisionShape3D:
		var cs := node as CollisionShape3D
		var size := Vector3.ZERO
		var kind := "null"
		if cs.shape != null:
			kind = cs.shape.get_class()
			if cs.shape is BoxShape3D:
				size = (cs.shape as BoxShape3D).size
			elif cs.shape is CapsuleShape3D:
				var cap := cs.shape as CapsuleShape3D
				size = Vector3(cap.radius, cap.height, cap.radius)
			elif cs.shape is SphereShape3D:
				var sph := cs.shape as SphereShape3D
				size = Vector3(sph.radius, sph.radius, sph.radius)
		out.append({"shape": kind, "size": size, "position": cs.position})
	for child in node.get_children():
		_walk_collision(child, out)

## Nodes that are visuals AND carry collision.
##
## **Applies to AUTHORED scenes, not to procedural geometry.** The
## distinction is real rather than a convenience: `ChamberBuilders._box`
## derives the mesh size and the collider size from the same argument, so
## there is no independent art to swap and nothing can diverge. An
## authored scene is the opposite case -- a person made the mesh and a
## person made the collider, and replacing the mesh is exactly the
## operation that can silently move a wall.
##
## For procedural geometry the meaningful check is
## `mesh_collider_mismatches` below.
static func visuals_carrying_collision(root: Node3D) -> Array[String]:
	var out: Array[String] = []
	_walk_visuals(root, root, out)
	return out

static func _walk_visuals(root: Node3D, node: Node,
		out: Array[String]) -> void:
	if node is MeshInstance3D:
		for child in node.get_children():
			if child is CollisionShape3D or child is CollisionObject3D:
				out.append(str(root.get_path_to(node)))
				break
	for child in node.get_children():
		_walk_visuals(root, child, out)

## Whether two collision profiles are the same. Returns "" when they
## match, or the first difference, named -- a bare `false` from a hitbox
## comparison tells nobody which shape moved.
static func same_collision(a: Array, b: Array) -> String:
	if a.size() != b.size():
		return "one build has %d collision shapes and the other has %d" % [
				a.size(), b.size()]
	for i in a.size():
		var x: Dictionary = a[i]
		var y: Dictionary = b[i]
		if x["shape"] != y["shape"]:
			return "shape %d is a %s in one build and a %s in the other" % [
					i, x["shape"], y["shape"]]
		if not (x["size"] as Vector3).is_equal_approx(y["size"]):
			return "shape %d is %s in one build and %s in the other" % [
					i, x["size"], y["size"]]
		if not (x["position"] as Vector3).is_equal_approx(y["position"]):
			return "shape %d sits at %s in one build and %s in the other" % [
					i, x["position"], y["position"]]
	return ""


## Procedural geometry's version of the same worry: a box whose visual
## and whose collider disagree.
##
## A mesh 4 m wide with a 3 m collider is a wall the player can see
## through; a mesh 3 m wide with a 4 m collider is an invisible one they
## walk into. `_box` builds both from one `size`, so this holds today --
## and it holds silently, which is why it is worth a test. Anyone
## "adjusting the visual" of a box is one edit away from breaking it.
##
## Only box-mesh/box-shape pairs are compared. A `PrismMesh` collided by
## a `ConvexPolygonShape3D` (the ramp helper) has no comparable extent,
## and inventing one would mean this check reporting differences that
## are not differences.
static func mesh_collider_mismatches(root: Node3D) -> Array[String]:
	var out: Array[String] = []
	_walk_mismatch(root, out)
	return out

static func _walk_mismatch(node: Node, out: Array[String]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
		var mesh_size := ((node as MeshInstance3D).mesh as BoxMesh).size
		for shape: CollisionShape3D in _own_shapes(node):
			if not (shape.shape is BoxShape3D):
				continue
			var box := (shape.shape as BoxShape3D).size
			if not box.is_equal_approx(mesh_size):
				out.append("a %s mesh has a %s collider" % [mesh_size, box])
			# Offsets accumulate through the StaticBody3D the helper
			# inserts, so compare the total rather than one hop.
			var offset := shape.position
			var walk := shape.get_parent()
			while walk != null and walk != node:
				if walk is Node3D:
					offset += (walk as Node3D).position
				walk = walk.get_parent()
			if not offset.is_equal_approx(Vector3.ZERO):
				out.append("a %s mesh has a collider offset by %s"
						% [mesh_size, offset])
	for child in node.get_children():
		_walk_mismatch(child, out)

## Collision shapes belonging to this mesh, not to a nested mesh further
## down -- otherwise a greeble's collider would be reported against the
## wall it is bolted to.
static func _own_shapes(mesh: Node) -> Array:
	var out: Array = []
	for child in mesh.get_children():
		if child is MeshInstance3D:
			continue
		_collect_shapes(child, out)
	return out

static func _collect_shapes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		return
	if node is CollisionShape3D:
		out.append(node)
	for child in node.get_children():
		_collect_shapes(child, out)
