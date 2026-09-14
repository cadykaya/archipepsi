class_name SceneDigest
extends RefCounted

## WHAT A REPLAY RAN AGAINST, which only the engine can say.
##
## `PhysicsSetup` carries body id, mass and constrained-ness -- what the
## CONTRACT reasons about. It is not what a replay ran against: collision
## geometry, initial transforms, static obstacles, gravity and layer
## masks can all change while every field the bridge holds stays
## identical, and a solution that latched before the crate moved two
## metres left is not evidence about the room as it now stands.
##
## The bridge cannot compute this and must not try -- re-deriving a
## physical fact in Python is what the lane split exists to prevent. It
## folds the sixteen characters into `package_digest` and never looks
## inside them. `docs/AMALGAM_BRIDGE.md` §6.2b is the agreed coverage and
## §6.2b ANSWERED is the five decisions this implements.
##
## **OF THE SETUP, BEFORE ANYTHING IS STEPPED.** A replay builds the
## setup, digests it, and then runs. A body already moving when the
## digest is taken means the digest is of a moment nobody can reproduce
## -- which is why the bodies carry their starting velocity and sleep
## state into it rather than being assumed at rest.
##
## **A CONSTANT PASSES THE BRIDGE.** Sixteen hex characters is all it can
## see, so nothing on that side will ever catch a fake. What catches one
## is here: `content_driver` computes a digest, moves a single collider
## by a millimetre, and requires a different answer. Without that
## sabotage this file is a constant with extra steps.

## Every length to 1e-4 m, every angle to 1e-4 rad, every velocity to
## 1e-4 m/s. `EPSILON_JOIN` is 1e-3 m and `MAX_VERTICAL_STEP` is 1.0 m,
## so a quantum is an order of magnitude below the tightest distance
## anything in this game reasons about and four below the smallest one a
## player can feel. Below that is single-precision noise, and a digest
## that churns on noise invalidates evidence nothing changed about.
const QUANTUM := 0.0001

## Bumped BY HAND whenever scene construction changes shape. A digest
## records what the solver used; two runs of a different generator over
## the same declarations are not the same experiment.
const GENERATOR_VERSION := 1

## Sixteen lowercase hex characters over `room`, as §6.2b covers it.
##
## `bounds` is the room's committed world envelope from the manifest --
## the thing that makes "within the room" decidable at all in a Zone that
## is one scene. `bodies` are the package's, in any order; they are
## sorted here. Node paths are taken relative to `room` and not to the
## Zone, because a Zone re-entered after a different number of rooms were
## placed gives the same room a different Zone-relative path.
static func of_room(room: Node3D, bounds: AABB,
		bodies: Array) -> String:
	return _hash(text_of_room(room, bounds, bodies))

## The string that gets hashed, so a test can compare the CONTENT and say
## which field moved rather than only that sixteen characters differ.
static func text_of_room(room: Node3D, bounds: AABB,
		bodies: Array) -> String:
	var lines: Array[String] = []
	lines.append("version %s" % _versioning())
	lines.append("gravity %s %s"
			% [_num(ProjectSettings.get_setting(
					"physics/3d/default_gravity", 9.8)),
				_vec(ProjectSettings.get_setting(
					"physics/3d/default_gravity_vector",
					Vector3.DOWN))])
	# THE LAYERS THE PACKAGE'S BODIES TEST AGAINST decide what
	# participates. Not a radius: a radius is a tuning constant and it
	# will drift.
	var mask := 0
	var sorted_bodies: Array = bodies.duplicate()
	sorted_bodies.sort_custom(func(a: Node, b: Node) -> bool:
		return str(a.name) < str(b.name))
	for node: Variant in sorted_bodies:
		var body := node as PhysicsBody3D
		if body == null:
			continue
		mask |= body.collision_mask
		lines.append("body %s" % _body(room, body))
	for line: String in _static_lines(room, room, bounds, mask):
		lines.append(line)
	for line: String in _area_lines(room, room, bounds):
		lines.append(line)
	for line: String in _shell_lines(room):
		lines.append(line)
	return "\n".join(lines)

# --- the pieces ----------------------------------------------------------

## Godot, the physics backend, and a hand-bumped generator constant.
##
## The same bodies under a different solver build are not the same
## experiment, and nothing else in the digest would notice a physics
## engine upgrade.
static func _versioning() -> String:
	var info := Engine.get_version_info()
	return "godot=%s.%s.%s.%s backend=%s generator=%d" % [
		info.get("major", 0), info.get("minor", 0), info.get("patch", 0),
		str(info.get("status", "?")),
		str(ProjectSettings.get_setting("physics/3d/physics_engine",
				"DEFAULT")),
		GENERATOR_VERSION]

## A body's EFFECTIVE values, as far as they are statically readable.
##
## Friction and restitution live on a `PhysicsMaterial` that may be null,
## inherited or shared, and resolving what a body actually experiences
## requires stepping the sim. A digest must not step anything -- so the
## material is digested as its resource path plus its own digest, never
## as a resolved number, exactly as §6.2b proposed.
static func _body(room: Node, body: PhysicsBody3D) -> String:
	var parts: Array[String] = [
		"path=%s" % str(room.get_path_to(body)),
		"xform=%s" % _xform(body.global_transform),
		"layer=%d mask=%d" % [body.collision_layer, body.collision_mask],
		"material=%s" % _material(body.physics_material_override),
	]
	var rigid := body as RigidBody3D
	if rigid != null:
		parts.append("mass=%s gravity_scale=%s"
				% [_num(rigid.mass), _num(rigid.gravity_scale)])
		parts.append("linear_damp=%s/%d angular_damp=%s/%d"
				% [_num(rigid.linear_damp), rigid.linear_damp_mode,
					_num(rigid.angular_damp), rigid.angular_damp_mode])
		parts.append("v=%s w=%s sleeping=%s"
				% [_vec(rigid.linear_velocity),
					_vec(rigid.angular_velocity),
					"1" if rigid.sleeping else "0"])
	for line: String in _shapes_of(room, body):
		parts.append(line)
	return " ".join(parts)

## Static geometry the bodies can touch, sorted by node path.
static func _static_lines(room: Node, at: Node, bounds: AABB,
		mask: int) -> Array[String]:
	var out: Array[String] = []
	for node: Node in at.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body.collision_layer & mask == 0:
			continue
		if not bounds.has_point(body.global_position):
			continue
		var parts: Array[String] = [
			"static %s" % str(room.get_path_to(body)),
			"xform=%s" % _xform(body.global_transform),
			"layer=%d" % body.collision_layer,
			"material=%s" % _material(body.physics_material_override),
		]
		for line: String in _shapes_of(room, body):
			parts.append(line)
		out.append(" ".join(parts))
	out.sort()
	return out

## `Area3D` gravity overrides, as (path, mode, value, priority).
##
## Resolving what a body actually experiences inside overlapping areas
## requires stepping the sim, so the areas are digested and the
## resolution is not attempted.
static func _area_lines(room: Node, at: Node,
		bounds: AABB) -> Array[String]:
	var out: Array[String] = []
	for node: Node in at.find_children("*", "Area3D", true, false):
		var area := node as Area3D
		if area.gravity_space_override == Area3D.SPACE_OVERRIDE_DISABLED:
			continue
		if not bounds.has_point(area.global_position):
			continue
		out.append("area %s mode=%d gravity=%s %s priority=%d"
				% [str(room.get_path_to(area)),
					area.gravity_space_override, _num(area.gravity),
					_vec(area.gravity_direction), area.priority])
	out.sort()
	return out

## Every authored shell whose geometry is in this room, by its DECLARED
## registry entry.
##
## What this covers and what it does not. The colliders above are what
## catch a shell whose SHAPE changed -- Arty's 2026-09-12 yard repair
## added `yd_threshold_±1` and the collider enumeration sees it while
## `size` and the sockets stayed byte-identical. This covers the other
## direction: a declaration that moved without the geometry moving, which
## the collider list cannot see and which changes what the room promises.
static func _shell_lines(room: Node) -> Array[String]:
	var out: Array[String] = []
	var registry := ContentRegistry.new()
	registry.load_all()
	var seen := {}
	for node: Node in room.find_children("*", "Node3D", true, false):
		var id := str(node.get_meta(
				ContentInstantiator.SHELL_META, ""))
		if id == "" or seen.has(id):
			continue
		seen[id] = true
		var entry := registry.get_entry(id)
		if entry.is_empty():
			out.append("shell %s MISSING" % id)
			continue
		out.append("shell %s %s"
				% [id, _hash(JSON.stringify({
					"size": entry.get("size", []),
					"sockets": entry.get("sockets", []),
					"surfaces": entry.get("surfaces", []),
					"volumes": entry.get("volumes", []),
					"scene": entry.get("scene", ""),
				}, "", true))])
	out.sort()
	return out

## Each collision shape a body owns: class, extents, local transform.
static func _shapes_of(room: Node, body: CollisionObject3D) -> Array[String]:
	var out: Array[String] = []
	for node: Node in body.find_children("*", "CollisionShape3D",
			true, false):
		var holder := node as CollisionShape3D
		if holder.shape == null or holder.disabled:
			continue
		out.append("shape[%s]=%s@%s" % [str(room.get_path_to(holder)),
				_shape(holder.shape), _xform(holder.transform)])
	out.sort()
	return out

static func _shape(shape: Shape3D) -> String:
	if shape is BoxShape3D:
		return "box:%s" % _vec((shape as BoxShape3D).size)
	if shape is SphereShape3D:
		return "sphere:%s" % _num((shape as SphereShape3D).radius)
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return "capsule:%s,%s" % [_num(capsule.radius),
				_num(capsule.height)]
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return "cylinder:%s,%s" % [_num(cylinder.radius),
				_num(cylinder.height)]
	if shape is ConvexPolygonShape3D:
		return "convex:%s" % _points(
				(shape as ConvexPolygonShape3D).points)
	if shape is ConcavePolygonShape3D:
		return "concave:%s" % _points(
				(shape as ConcavePolygonShape3D).get_faces())
	if shape is WorldBoundaryShape3D:
		var plane := (shape as WorldBoundaryShape3D).plane
		return "plane:%s,%s" % [_vec(plane.normal), _num(plane.d)]
	# NAMED RATHER THAN SKIPPED. A shape class this does not know is
	# geometry the digest would be blind to, and a blind digest is worse
	# than a missing one: it says two different scenes are the same.
	return "UNKNOWN:%s" % shape.get_class()

## A hulls' worth of points, as their own digest, so a mesh with eight
## thousand vertices does not put eight thousand numbers in the string.
static func _points(points: PackedVector3Array) -> String:
	var parts: Array[String] = []
	for point: Vector3 in points:
		parts.append(_vec(point))
	return "%d/%s" % [points.size(), _hash(",".join(parts))]

static func _material(material: PhysicsMaterial) -> String:
	if material == null:
		return "none"
	# PATH PLUS ITS OWN DIGEST, never the resolved numbers: a material
	# may be inherited or shared, and a digest that resolved it would be
	# claiming to know what the solver will do.
	return "%s/%s" % [material.resource_path if material.resource_path
			!= "" else "inline",
			_hash("%s,%s,%s,%s" % [_num(material.friction),
				_num(material.bounce), material.rough, material.absorbent])]

# --- quantization --------------------------------------------------------

## A fixed decimal representation, never a raw float's printed form. The
## quantum is applied first so two values a ten-thousandth apart agree
## and two a millimetre apart do not.
static func _num(value: float) -> String:
	return "%.4f" % (round(value / QUANTUM) * QUANTUM)

static func _vec(value: Vector3) -> String:
	return "%s,%s,%s" % [_num(value.x), _num(value.y), _num(value.z)]

static func _xform(value: Transform3D) -> String:
	return "%s|%s|%s|%s" % [_vec(value.basis.x), _vec(value.basis.y),
			_vec(value.basis.z), _vec(value.origin)]

static func _hash(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)
