class_name ProjectileSilhouette
extends RefCounted
## What a projectile LOOKS like follows from what it DOES (art req 13).
##
## Three behaviours in one primitive family, and until now one sphere for
## all of them, scaled 1.5x for a lob. The three facts a player has to
## read before the shot lands are:
##
##     straight   it goes where I pointed
##     falling    it drops, so lead the shot upward
##     lobbed     it is fused, and it will explode
##
## Colour cannot carry any of that. **Colour is the source world's**: an
## Echo is tinted by the game whose item it reinterprets, so two Echoes
## with the same arc are different colours and two with the same colour
## have different arcs. Tinting by behaviour would overwrite identity
## with mechanics and lose both. So the difference is SHAPE, readable in
## silhouette, at distance, in greyscale:
##
##     straight   a long thin axial dart -- fast, flat, no mass to fall
##     falling    a head-heavy teardrop with a thin tail -- weight in front
##     lobbed     a squat banded ball -- obviously thrown, obviously fused
##
## This file SELECTS and it MEASURES. It does not decide difficulty: the
## selection reads the projectile's real flight fields and never writes
## them, so a silhouette can never become the reason a shot behaves the
## way it does. `EchoProjectile` keeps its 0.25 m collider whichever one
## it wears.
##
## The placeholder geometry below is a PLACEHOLDER, in the S12 sense: it
## is a valid, testable stand-in, and the moment an authored mesh lands in
## the registry under `content_id()` it is used instead with no code
## change here.

const STRAIGHT := "straight"
const FALLING := "falling"
const LOBBED := "lobbed"

## Every silhouette, in a fixed order. A closed family: `for_behaviour`
## is total over it, and the legibility rule below is checked pairwise
## across all of it, so a fourth member cannot be added without being
## made distinguishable from the other three.
const FAMILY: Array[String] = [STRAIGHT, FALLING, LOBBED]

## The registry category authored projectile meshes register under.
const CATEGORY := "projectile_visual"

## Two silhouettes read apart when one is at least this many times more
## needle-like than the other. A margin rather than "not equal": the
## claim is that they separate across a room, not that a script can tell
## them apart.
const LEGIBLE_RATIO := 1.8

## ...or when the widest point of one sits this much further along its
## travel axis than the other's. An absolute gap, not a ratio, because
## `balance` is a POSITION in 0..1 and 0.5 is not "twice" 0.25.
const LEGIBLE_BALANCE := 0.15


## The silhouette a projectile that behaves like this wears.
##
## Reads the flight fields themselves, in the order the player learns
## them: a blast radius means the thing is fused and explodes, and that
## outranks how it flies, because a lob is also fully gravity-affected
## and would otherwise read as "falling".
static func for_behaviour(gravity_scale: float, blast_radius: float) -> String:
	if blast_radius > 0.0:
		return LOBBED
	if gravity_scale > 0.0:
		return FALLING
	return STRAIGHT


## The content id an authored mesh for this silhouette registers under.
static func content_id(silhouette: String) -> String:
	return "projectile_%s" % silhouette


## Builds the placeholder silhouette, tinted by the SOURCE WORLD.
##
## The tint is identity and is applied to every part, so the shape is the
## only thing that varies with behaviour and the colour is the only thing
## that varies with provenance. Returns a bare `Node3D` whose children
## are meshes: the caller parents it under its own `Visual` container, so
## nothing here can reach a collider.
static func build(silhouette: String, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Silhouette"
	var material := ThemeMaterials.glow_material(tint, 2.5)
	match silhouette:
		FALLING:
			_teardrop(root, material)
		LOBBED:
			_banded_ball(root, material)
		_:
			_dart(root, material)
	return root


## A long thin axial spindle. Uniform along its length -- nothing about
## it suggests a nose-down weight, which is the point.
static func _dart(root: Node3D, material: Material) -> void:
	var body := CylinderMesh.new()
	body.top_radius = 0.055
	body.bottom_radius = 0.065
	# 0.52 + a 0.12 nose is about 0.64 m end to end, against a 0.25 m
	# collider. Longer reads better in flight and starts overhanging its
	# own hitbox by enough to mislead about what it will clip.
	body.height = 0.52
	_part(root, body, material, Vector3.ZERO,
			Vector3(PI * 0.5, 0.0, 0.0))          # lie along -Z, its travel
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.055
	nose.height = 0.12
	_part(root, nose, material, Vector3(0.0, 0.0, -0.32),
			Vector3(PI * 0.5, 0.0, 0.0))


## Weight in front, tail behind: the grammar for "this one drops".
static func _teardrop(root: Node3D, material: Material) -> void:
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.30
	_part(root, head, material, Vector3(0.0, 0.0, -0.18), Vector3.ZERO)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.12
	tail.bottom_radius = 0.03
	tail.height = 0.36
	_part(root, tail, material, Vector3(0.0, 0.0, 0.15),
			Vector3(-PI * 0.5, 0.0, 0.0))         # wide end toward the head


## Round, chunky, banded. Nothing about it is aerodynamic, and the band
## reads as a seam or a fuse ring rather than as decoration.
static func _banded_ball(root: Node3D, material: Material) -> void:
	var ball := SphereMesh.new()
	ball.radius = 0.17
	ball.height = 0.34
	_part(root, ball, material, Vector3.ZERO, Vector3.ZERO)
	var band := TorusMesh.new()
	band.inner_radius = 0.17
	band.outer_radius = 0.23
	# Centred, so the band sits on the equator and neither half of the
	# shape is heavier than the other.
	_part(root, band, material, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))


static func _part(root: Node3D, mesh: Mesh, material: Material,
		offset: Vector3, rotation: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = offset
	node.rotation = rotation
	root.add_child(node)


## The measurable shape of a built silhouette, along its travel axis.
##
## Measured from the GEOMETRY, never from the material, so the answer is
## the same in colour and in greyscale -- which is the whole requirement.
## Local space, with -Z as the direction of travel.
##
## Returns:
##   `length`      extent along travel
##   `cross`       widest extent perpendicular to travel
##   `elongation`  length / cross: how needle-like it is
##   `balance`     where the widest point sits, 0 at the nose, 1 at the
##                 tail: head-heavy, even, or tail-heavy
##   `parts`       how many meshes make it up
static func profile(root: Node3D) -> Dictionary:
	# The root's OWN basis counts. It is normally identity, and a shape
	# that quietly scaled itself -- by tint, by damage, by anything --
	# would otherwise be measured as if it had not, because every measure
	# below is taken from the children.
	var outer := Transform3D(root.transform.basis, Vector3.ZERO)
	var cross := 0.0
	var near := INF
	var far := -INF
	var widest_near := 0.0           # z span over which `cross` is reached
	var widest_far := 0.0
	var parts := 0
	for node in root.get_children():
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		parts += 1
		var box := mesh_node.mesh.get_aabb()
		# The part's own rotation is part of its shape, so measure the
		# transformed corners rather than the raw mesh AABB.
		var local := outer * Transform3D(
				Basis.from_euler(mesh_node.rotation), mesh_node.position)
		var part_radius := 0.0
		var part_near := INF
		var part_far := -INF
		for i in 8:
			var corner: Vector3 = local * (box.position + Vector3(
					box.size.x * float(i & 1),
					box.size.y * float((i >> 1) & 1),
					box.size.z * float((i >> 2) & 1)))
			part_near = minf(part_near, corner.z)
			part_far = maxf(part_far, corner.z)
			part_radius = maxf(part_radius,
					maxf(absf(corner.x), absf(corner.y)))
		near = minf(near, part_near)
		far = maxf(far, part_far)
		if part_radius > cross:
			cross = part_radius
			widest_near = part_near
			widest_far = part_far
	var length := maxf(far - near, 0.0001)
	var width := maxf(cross * 2.0, 0.0001)
	# Measured per PART rather than per corner: a bounding box cannot say
	# where along a single cone the wide end is, but it can say which of
	# several parts is the wide one and where that part sits. That is the
	# cue anyway -- a head-heavy shape is head-heavy because the fat piece
	# is at the front.
	var middle := (widest_near + widest_far) / 2.0
	return {
		"length": length,
		"cross": width,
		"elongation": length / width,
		"balance": clampf((middle - near) / length, 0.0, 1.0),
		"parts": parts,
	}


## Whether two profiles read as different shapes.
##
## Either measure is enough on its own, and both are SHAPE measures. Part
## count is deliberately not one: at distance a shape made of three
## meshes and the same shape made of one look identical, so counting them
## would let two identical silhouettes pass by being differently built.
static func reads_apart(a: Dictionary, b: Dictionary) -> bool:
	var lo := minf(float(a["elongation"]), float(b["elongation"]))
	var hi := maxf(float(a["elongation"]), float(b["elongation"]))
	if lo > 0.0 and hi / lo >= LEGIBLE_RATIO:
		return true
	return absf(float(a["balance"]) - float(b["balance"])) >= LEGIBLE_BALANCE
