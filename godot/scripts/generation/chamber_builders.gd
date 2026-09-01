class_name ChamberBuilders
extends RefCounted
## Brush-style chamber construction. Each builder returns:
##   { root: Node3D, exit_offset: Vector3, bounds: AABB,
##     enemy_spawns: Array[Vector3], reward_position: Vector3,
##     goal_area_position: Vector3 }
## Entrance is always local (0,0,0) facing +Z; the exit is on local +Z at
## exit_offset. ZoneBuilder chains chambers by translating each root.
##
## Geometry is boxes, prisms (wedges/ramps) and cylinders — the brushes of
## a 1998 level editor. Not voxels, not a visible grid.

const WALL_THICKNESS := 0.4
const DOOR_WIDTH := 2.4
const DOOR_HEIGHT := 3.2
const CORRIDOR_HEIGHT := 3.6

## Lane budget for colliding props: the widest actor is the 1.8 m brute,
## plus margin. A prop reaching PROP_FOOTPRINT in from each wall must
## still leave BRUTE_LANE between them.
const PROP_FOOTPRINT := 1.4
const BRUTE_LANE := 2.6

## A mesh at least this wide on both floor axes is architecture -- a
## floor slab, a ceiling, a wall, a band's deck -- not furniture. Room
## content is placed INSIDE the room, so treating the room itself as an
## obstacle would leave every solver with nowhere legal to go. Regions of
## architecture that content must nonetheless avoid are declared as
## `reserved` sockets instead.
const ROOM_SCALE_SOLID := 6.0

## Every piece of furniture-scale solid geometry under `node`, in that
## node's own space.
##
## ONE derivation, called by the builder to vouch for its sockets and by
## `ContentInstantiator` to place activities. Two derivations of one fact
## is how they disagree, and this project has already paid for a builder
## that knew a physical fact its composer did not.
##
## THE TRANSFORM IS ACCUMULATED BY HAND, and it has to be. The obvious
## version uses `mesh.global_transform`, which for a node OUTSIDE THE
## SCENE TREE does not accumulate -- and a chamber is built detached and
## added later, so every prop came back at its own local offset near the
## origin. The boxes looked plausible, intersected nothing, and the
## solver silently did nothing at all.
static func solid_boxes(node: Node,
		xform := Transform3D.IDENTITY) -> Array[AABB]:
	var out: Array[AABB] = []
	_gather_solids(node, xform, out)
	return out

static func _gather_solids(node: Node, xform: Transform3D,
		out: Array[AABB]) -> void:
	var here := xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var box: AABB = here * (node as MeshInstance3D).get_aabb()
		if box.size.x < ROOM_SCALE_SOLID and box.size.z < ROOM_SCALE_SOLID:
			out.append(box)
	for child in node.get_children():
		_gather_solids(child, here, out)

## The floor rectangle a band occupies, in room space (x, z).
##
## ONE derivation. `arena` has to carve its floor slab where a PIT goes
## and `_elevation_band` has to build the recess there, and the two
## computing the same rectangle separately is how a pit came to be a
## sealed basement under an intact floor: the recess was dug and the slab
## above it was never opened, so the real-Zone audit measured the pit's
## surface at 0.00 m in a room that declared it at -1.66 m.
static func band_rect(band: Dictionary, width: float,
		depth: float) -> Rect2:
	var coverage := clampf(float(band.get("coverage", 0.35)), 0.2, 0.55)
	var side := str(band.get("side", "left"))
	# The band occupies a strip against one wall. `back` runs the room's
	# width at the far end; `left`/`right` run its depth.
	var span_z := depth * coverage if side == "back" else depth
	var span_x := width if side == "back" else width * coverage
	var centre_x := 0.0
	var centre_z := depth / 2.0
	match side:
		"left":
			centre_x = -(width - span_x) / 2.0
		"right":
			centre_x = (width - span_x) / 2.0
		_:
			centre_z = depth - span_z / 2.0
	return Rect2(centre_x - span_x / 2.0, centre_z - span_z / 2.0,
			span_x, span_z)

## The room's floor slab, with a rectangle left OPEN where a pit goes.
##
## Built as up to four slabs around the hole rather than one slab and a
## hope. `_carve_gap` never removed the base slab and the Echo Lab has no
## gap because of it; a pit under an intact floor is that bug wearing a
## different name, and it shipped in this batch until the audit measured
## the surface instead of trusting the description.
static func _floor_with_hole(root: Node3D, width: float, depth: float,
		mat: Material, hole: Variant) -> void:
	var full := Vector3(width, 0.5, depth)
	var at := Vector3(0, -0.25, depth / 2.0)
	if hole == null:
		_box(root, full, at, mat)
		return
	var rect: Rect2 = hole
	var left := -width / 2.0
	var right := width / 2.0
	# Front and back strips run the full width; the side strips fill what
	# is left beside the hole. A zero-width strip is simply not built.
	for strip: Array in [
			[left, right, 0.0, rect.position.y],
			[left, right, rect.end.y, depth],
			[left, rect.position.x, rect.position.y, rect.end.y],
			[rect.end.x, right, rect.position.y, rect.end.y]]:
		var sx: float = strip[1] - strip[0]
		var sz: float = strip[3] - strip[2]
		if sx <= 0.01 or sz <= 0.01:
			continue
		_box(root, Vector3(sx, 0.5, sz),
				Vector3(strip[0] + sx / 2.0, -0.25, strip[2] + sz / 2.0),
				mat)

## How much room a Check needs, and why it is not a taste number.
##
## `Reward` builds a 1.4 m interaction box over a 0.75 m-radius pedestal,
## and the player has to be able to stand at it and shoot it. So the
## clearance is the pedestal plus the player's own capsule on each side,
## derived from both rather than typed -- if either grows, this grows.
const REWARD_PEDESTAL := 1.5
const REWARD_PEDESTAL_HEIGHT := 2.6

## How far apart `ZoneController` spaces a room's Checks along +Z. One
## derivation: a room with three Checks reserves room for three.
const REWARD_ROW_SPACING := 4.0

## The volume a room's Checks and the space to use them occupy.
##
## THE BUG THIS EXISTS FOR. An arena scattered three cover boxes at
## random through the middle half of the room and `reward_position` was a
## fixed point on the centre line, so nothing ever stopped one landing on
## the other -- and `ZoneController` places the pedestal at that anchor
## with no clearance test at all. Two of four arenas in the P1
## conformance suite spawned a Check inside a crate.
##
## Declared as a `reserved` region rather than fixed by moving one prop,
## because that makes it true for everything downstream at once: the
## builder's own props avoid it here, and occupancy keeps activities and
## environmental objects out of it for free.
static func reward_clearance(chamber: Dictionary, at: Vector3) -> AABB:
	var count := 1 if chamber.get("reward_location_id") != null else 0
	count += (chamber.get("additional_reward_location_ids", []) as Array
			).size()
	# AT LEAST ONE, always. `reward_position` is the room's promise about
	# where a Check goes, and a room does not get to assume the campaign
	# will not give it one -- the allocator decides that, later, and by
	# then the crate is built. A room that ends up with no Check has paid
	# three square metres for a promise it kept.
	count = maxi(count, 1)
	var span := REWARD_PEDESTAL + Constants.PLAYER_RADIUS * 4.0
	var along := REWARD_ROW_SPACING * float(count - 1) + span
	return AABB(
			Vector3(at.x - span / 2.0, at.y, at.z - span / 2.0),
			Vector3(span, REWARD_PEDESTAL_HEIGHT, along))

## The room's first choice for a prop, or the nearest free spot to it.
##
## No randomness: the caller has already rolled where it WANTS the prop,
## and a room with nothing in the way gets exactly that. The sweep only
## runs when the first choice would bury something the room reserved,
## and it returns the ideal when the room genuinely has no space --
## a missing prop is a room that quietly got emptier, and the Zone audit
## reports a buried Check either way.
static func _free_prop_spot(ideal: Vector3, size: Vector3, width: float,
		depth: float, taken: Array[AABB]) -> Vector3:
	if not box_hits(AABB(ideal - size / 2.0, size), taken):
		return ideal
	var lo_x := -width / 2.0 + 2.5
	var hi_x := width / 2.0 - 2.5
	var lo_z := depth * 0.25
	var hi_z := depth * 0.75
	var best := ideal
	var best_away := INF
	for xi in 9:
		for zi in 9:
			var at := Vector3(
					lerpf(lo_x, hi_x, float(xi) / 8.0), size.y / 2.0,
					lerpf(lo_z, hi_z, float(zi) / 8.0))
			if box_hits(AABB(at - size / 2.0, size), taken):
				continue
			var away := at.distance_to(ideal)
			if away < best_away:
				best_away = away
				best = at
	return best

## Where an arena's Checks go, out of the way of its own band.
##
## The default is the point the room has always used. It moves only when
## something the room already RESERVED is standing there -- a `back`
## gallery at 0.41 coverage reaches z = 0.59..1.0 of the room and its
## access ramp reaches most of the rest, and the pedestal anchor sat in
## both. That is the same bug as the crate, one room feature further
## out, and the same answer: the builder knows where it put the band, so
## the builder is what moves the anchor.
##
## `taken` is what `_elevation_band` DECLARED, handed in rather than
## recomputed here. The first version re-derived `band_rect` and missed
## the ramp entirely, which is the second derivation this project keeps
## paying for.
##
## Deterministic and ordered, never random: the same Zone must lay out
## the same room on every machine, and a Check that wanders is a Check
## the replay cannot find.
static func _reward_anchor(chamber: Dictionary, width: float,
		depth: float, taken: Array[AABB]) -> Vector3:
	var ideal := Vector3(0, 0, depth * 0.72)
	if taken.is_empty():
		return ideal
	var span := REWARD_PEDESTAL + Constants.PLAYER_RADIUS * 4.0
	# Down the middle first, then out to either side: a Check on the
	# centre line is the room's own convention and worth keeping when it
	# can be kept.
	var reach := maxf(width / 2.0 - WALL_THICKNESS - span / 2.0, 0.0)
	for at: Vector3 in [ideal,
			Vector3(0, 0, depth * 0.45),
			Vector3(-reach * 0.65, 0, depth * 0.72),
			Vector3(reach * 0.65, 0, depth * 0.72),
			Vector3(-reach * 0.65, 0, depth * 0.45),
			Vector3(reach * 0.65, 0, depth * 0.45),
			Vector3(0, 0, depth * 0.28)]:
		var claim := AABB(
				Vector3(at.x - span / 2.0, 0.0, at.z - span / 2.0),
				Vector3(span, REWARD_PEDESTAL_HEIGHT, span))
		if not box_hits(claim, taken):
			return at
	# Then a deterministic sweep of the whole legal floor, nearest to the
	# ideal first. The seven candidates above are the room's preferences
	# and they run out: a 12 x 10 arena with a 0.45-coverage band and its
	# ramp has none of them free, and a Check has to go SOMEWHERE it
	# fits. Same shape as `Activities._free_spot` -- ideal, then a grid,
	# and the ideal again only if the room really is full.
	var lo_x := -reach
	var hi_x := reach
	var lo_z := span / 2.0 + WALL_THICKNESS
	var hi_z := maxf(lo_z, depth - span / 2.0 - WALL_THICKNESS)
	var best := ideal
	var best_away := INF
	for xi in 9:
		for zi in 9:
			var at := Vector3(lerpf(lo_x, hi_x, float(xi) / 8.0), 0.0,
					lerpf(lo_z, hi_z, float(zi) / 8.0))
			var claim := AABB(
					Vector3(at.x - span / 2.0, 0.0, at.z - span / 2.0),
					Vector3(span, REWARD_PEDESTAL_HEIGHT, span))
			if box_hits(claim, taken):
				continue
			var away := at.distance_to(ideal)
			if away < best_away:
				best_away = away
				best = at
	return best

## The footprint a ground socket vouches for.
##
## Read off the objects themselves rather than restated here, so making a
## crate bigger moves the sockets instead of quietly invalidating them.
static func _ground_socket_size(kind: String) -> Vector3:
	match kind:
		"cover":
			return DestructibleCover.SIZE
		"reactive":
			return ReactiveBarrel.SIZE
	return Vector3.ONE

## Does `box` share space with anything in `boxes`?
static func box_hits(box: AABB, boxes: Array[AABB]) -> bool:
	for other in boxes:
		if box.intersects(other):
			return true
	return false

## Point a Label3D so its READABLE face looks toward `toward`.
##
## The one convention for world-space text. A Label3D draws on its local
## XY plane and reads correctly only from its local +Z side -- which is
## the OPPOSITE of the -Z that a Node3D calls "forward". So writing
## `rotation.y` by hand has a right answer and a plausible wrong one that
## differ by a sign, and both look equally deliberate in review.
##
## Playtest 1 found ten Hub signs on the wrong side of that sign. Every
## one of them was correct as state, as geometry and as protocol, which
## is why nine green suites had nothing to say about it. `make
## godot-legible` now checks the built room instead.
##
## Pass the direction from the sign to whoever must read it. Vertical
## component is dropped: wall text stays upright.
static func face_label(label: Label3D, toward: Vector3) -> void:
	var flat := Vector3(toward.x, 0.0, toward.z)
	if flat.length() < 0.0001:
		return
	# rotation.y = t sends local +Z to (sin t, 0, cos t).
	label.rotation.y = atan2(flat.x, flat.z)

static func _box(parent: Node3D, size: Vector3, position: Vector3,
		material: Material, collide := true) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		mesh_instance.add_child(body)
	return mesh_instance

static func _wedge(parent: Node3D, size: Vector3, position: Vector3,
		material: Material, y_rotation := 0.0,
		apex_at := 0.5) -> MeshInstance3D:
	## A PrismMesh ramp, collidable via ConvexPolygonShape.
	##
	## `apex_at` is `PrismMesh.left_to_right`. The default 0.5 is a
	## SYMMETRIC RIDGE -- it climbs and then descends -- which is what
	## every existing caller wants from a wedge-shaped prop. A RAMP needs
	## 0.0 or 1.0, and the first version of the elevation band did not
	## say so: the band's "ramp" was a ridge whose far face was a 2.2 m
	## wall, and the reachability probe measured exactly that.
	var mesh_instance := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.left_to_right = apex_at
	prism.size = size
	mesh_instance.mesh = prism
	mesh_instance.position = position
	mesh_instance.rotation.y = y_rotation
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = prism.create_convex_shape()
	body.add_child(shape)
	mesh_instance.add_child(body)
	return mesh_instance

## A collidable cylinder prop (drum, column stump), mirroring `_box`.
static func _cylinder_prop(parent: Node3D, radius: float, height: float,
		position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)
	mesh_instance.add_child(body)
	return mesh_instance

static func _light(parent: Node3D, position: Vector3, theme: String,
		range_override := 0.0) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = ThemeMaterials.light_color(theme)
	light.light_energy = ThemeMaterials.light_energy(theme)
	light.omni_range = range_override if range_override > 0.0 else 12.0
	light.shadow_enabled = false
	parent.add_child(light)
	# The HOUSING. Authored per theme where one exists, procedural where
	# it does not (art requirement 3a): six themes used to share one
	# `concrete_facility` slab because this was a hardcoded BoxMesh with
	# no way to ask for anything else.
	#
	# The light above is built either way. Illumination is engine-owned;
	# a housing is what it hangs in.
	var authored := ContentInstantiator.light_housing(theme)
	if authored != null:
		authored.name = "LightFixture"
		authored.position = position + Vector3(0, -0.05, 0)
		parent.add_child(authored)
		return

	var fixture := MeshInstance3D.new()
	# Named so a test can find it. Identifying a light fixture by its
	# size and material is how a check goes quietly wrong when either
	# changes.
	fixture.name = "LightFixture"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.1, 0.4)
	fixture.mesh = mesh
	# HANGS BELOW the light, not above it. Callers put lights just under
	# the ceiling -- an arena's sit at `height - 0.3` -- and a fixture
	# raised 0.15 above that ended up inside the ceiling slab with its
	# faces exactly coplanar, which is the shimmer playtest 2 saw along
	# the ceiling strips. Below, a fixture cannot reach the roof no
	# matter how tight the caller places the lamp.
	fixture.position = position + Vector3(0, -0.05, 0)
	fixture.material_override = ThemeMaterials.glow_material(
			ThemeMaterials.light_color(theme), 1.4)
	parent.add_child(fixture)

## Walls around a rectangular room with door gaps at entrance/exit centers.
## `exit_gap_y` raises the exit door's sill — a tower exits at its summit.
## One end wall with a doorway in it, at whatever height the doorway sits.
##
## `_perimeter` does this inline for its own two ends. The builders that
## raise their own walls -- `corridor`, `platform_path`, `corner` -- had
## no such thing, so they simply had no ends and no ceiling, and playtest
## 2 bounced out through the hole. A wall nobody raises is not a wall
## anybody notices missing: the bounds Dictionary still reads right, the
## exit socket is still in the right place, and every assertion passes.
static func _end_wall(root: Node3D, width: float, height: float, z: float,
		wall: Material, gap_y := 0.0) -> void:
	var side := (width - DOOR_WIDTH) / 2.0
	if side > 0.01:
		for sign_x: float in [-1.0, 1.0]:
			_box(root, Vector3(side, height, WALL_THICKNESS),
					Vector3(sign_x * (DOOR_WIDTH + side) / 2.0,
					height / 2.0, z), wall)
	if gap_y > 0.0:
		_box(root, Vector3(DOOR_WIDTH, gap_y, WALL_THICKNESS),
				Vector3(0, gap_y / 2.0, z), wall)
	var lintel := gap_y + DOOR_HEIGHT
	if height > lintel:
		_box(root, Vector3(DOOR_WIDTH, height - lintel, WALL_THICKNESS),
				Vector3(0, lintel + (height - lintel) / 2.0, z), wall)

static func _perimeter(root: Node3D, width: float, depth: float,
		height: float, theme: String, door_in := true, door_out := true,
		exit_gap_y := 0.0, left_gap_z := 0.0, left_gap_width := 0.0,
		left_gap_height := 0.0, ceiling := true) -> void:
	var wall := ThemeMaterials.wall_mat(theme)
	var half_w := width / 2.0
	var side := (width - DOOR_WIDTH) / 2.0
	# Front wall (z=0) with optional door gap.
	if door_in:
		_box(root, Vector3(side, height, WALL_THICKNESS),
				Vector3(-(DOOR_WIDTH + side) / 2.0, height / 2.0, 0), wall)
		_box(root, Vector3(side, height, WALL_THICKNESS),
				Vector3((DOOR_WIDTH + side) / 2.0, height / 2.0, 0), wall)
		if height > DOOR_HEIGHT:
			_box(root, Vector3(DOOR_WIDTH, height - DOOR_HEIGHT,
					WALL_THICKNESS),
					Vector3(0, DOOR_HEIGHT + (height - DOOR_HEIGHT) / 2.0, 0),
					wall)
	else:
		_box(root, Vector3(width, height, WALL_THICKNESS),
				Vector3(0, height / 2.0, 0), wall)
	# Back wall (z=depth), door gap carved from exit_gap_y up.
	if door_out:
		_box(root, Vector3(side, height, WALL_THICKNESS),
				Vector3(-(DOOR_WIDTH + side) / 2.0, height / 2.0, depth), wall)
		_box(root, Vector3(side, height, WALL_THICKNESS),
				Vector3((DOOR_WIDTH + side) / 2.0, height / 2.0, depth), wall)
		if exit_gap_y > 0.0:
			_box(root, Vector3(DOOR_WIDTH, exit_gap_y, WALL_THICKNESS),
					Vector3(0, exit_gap_y / 2.0, depth), wall)
		var lintel_bottom := exit_gap_y + DOOR_HEIGHT
		if height > lintel_bottom:
			_box(root, Vector3(DOOR_WIDTH, height - lintel_bottom,
					WALL_THICKNESS),
					Vector3(0, lintel_bottom + (height - lintel_bottom) / 2.0,
					depth), wall)
	else:
		_box(root, Vector3(width, height, WALL_THICKNESS),
				Vector3(0, height / 2.0, depth), wall)
	# Side walls. The left one can carry a real opening -- segments with a
	# hole, not a dark rectangle painted onto a solid slab. Playtest 1
	# walked into the Echo Lab's "doorway" and hit the wall behind it.
	if left_gap_width > 0.0:
		_side_wall_with_gap(root, -half_w, height, depth, wall,
				left_gap_z, left_gap_width, left_gap_height)
	else:
		_box(root, Vector3(WALL_THICKNESS, height, depth),
				Vector3(-half_w, height / 2.0, depth / 2.0), wall)
	_box(root, Vector3(WALL_THICKNESS, height, depth),
			Vector3(half_w, height / 2.0, depth / 2.0), wall)
	# A ceiling, by DEFAULT. This built four walls and called itself a
	# perimeter, so every chamber that did not add its own roof was open
	# to the void -- and one that jumps (bounce pad, platform, blink)
	# leaves the level through it. Callers that raise their own ceiling
	# pass `false` rather than stacking two coplanar slabs.
	if ceiling:
		_box(root, Vector3(width, WALL_THICKNESS, depth),
				Vector3(0, height, depth / 2.0), wall)

## A side wall in three pieces, leaving a hole you can actually walk
## through. Split rather than subtracted: `_box` is both the mesh and the
## collider, so a gap has to be an absence of boxes.
static func _side_wall_with_gap(root: Node3D, wall_x: float, height: float,
		depth: float, wall: Material, gap_z: float, gap_w: float,
		gap_h: float) -> void:
	var near_depth := (gap_z - gap_w / 2.0)
	if near_depth > 0.01:
		_box(root, Vector3(WALL_THICKNESS, height, near_depth),
				Vector3(wall_x, height / 2.0, near_depth / 2.0), wall)
	var far_start := gap_z + gap_w / 2.0
	if depth - far_start > 0.01:
		_box(root, Vector3(WALL_THICKNESS, height, depth - far_start),
				Vector3(wall_x, height / 2.0,
				far_start + (depth - far_start) / 2.0), wall)
	# Lintel: the wall above the opening, so the room still has a ceiling
	# line and the gap reads as a door rather than a missing wall.
	if height > gap_h:
		_box(root, Vector3(WALL_THICKNESS, height - gap_h, gap_w),
				Vector3(wall_x, gap_h + (height - gap_h) / 2.0, gap_z), wall)

# ---------------------------------------------------------------------------
# Greebles: the detail pass that makes a box read as 1998 level design.
# Deterministic per (chamber id, theme); wall- and ceiling-mounted only, so
# the mandatory path is never obstructed. All non-colliding.
# ---------------------------------------------------------------------------

static func _greeble_rng(chamber: Dictionary, theme: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|greebles" % [chamber.get("id", "c"), theme])
	return rng

## Structural ribs + a ceiling beam every few metres along a corridor-like
## space, plus wall vents and a sagging cable run.
static func _greeble_corridor(root: Node3D, length: float, width: float,
		height: float, theme: String, rng: RandomNumberGenerator) -> void:
	var trim := ThemeMaterials.trim_mat(theme)
	var accent := ThemeMaterials.accent_mat(theme)
	var rib_count := maxi(1, int(length / 6.0))
	for i in rib_count:
		var z := length * (float(i) + 0.5) / float(rib_count)
		for side in [-1.0, 1.0]:
			_box(root, Vector3(0.22, height, 0.35),
					Vector3(side * (width / 2.0 - 0.13), height / 2.0, z),
					trim, false)
		_box(root, Vector3(width, 0.25, 0.35),
				Vector3(0, height - 0.12, z), trim, false)
	# Wall vents.
	for i in rng.randi_range(1, 2):
		var z := rng.randf_range(1.5, length - 1.5)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		_box(root, Vector3(0.08, 0.7, 1.1),
				Vector3(side * (width / 2.0 - 0.05),
					rng.randf_range(1.0, height - 1.0), z), accent, false)
	# A cable run sagging along the ceiling.
	var cable_x := rng.randf_range(-width / 4.0, width / 4.0)
	var segments := maxi(2, int(length / 4.0))
	for i in segments:
		var z0 := length * float(i) / float(segments)
		var seg_length := length / float(segments)
		var sag := 0.12 + 0.1 * sin(float(i) * 1.7)
		_box(root, Vector3(0.06, 0.06, seg_length + 0.05),
				Vector3(cable_x, height - 0.25 - sag, z0 + seg_length / 2.0),
				trim, false)
	_theme_props(root, theme, rng, width, length, height)
	# Occasionally, Epsilon leaves a note.
	if rng.randf() < 0.3:
		_graffiti(root, Vector3(
				(-1.0 if rng.randf() < 0.5 else 1.0) * (width / 2.0 - 0.12),
				rng.randf_range(1.2, 2.2),
				rng.randf_range(2.0, length - 2.0)), theme, rng)

#: Authored, never generated at runtime. Epsilon's marginalia.
const GRAFFITI := [
	"EPSILON WAS HERE",
	"THIS WALL IS LOAD-BEARING, EMOTIONALLY",
	"DO NOT LICK THE STATIC",
	"THE EXIT IS REAL. PROBABLY.",
	"ANOTHER QUALITY CHAMBER",
	"I HAD MORE POLYGONS IN MIND",
	"YOUR ITEMS ARE IN ANOTHER WORLD",
	"SIGNAL LOST? KEEP WALKING",
	"BUILT IN 0.4 SECONDS. BE KIND.",
	"THE BRUTE IS A GOOD BOY",
	"MIND THE GAP",
	"1998 CALLED. I ANSWERED.",
]

static func _graffiti(root: Node3D, at: Vector3, theme: String,
		rng: RandomNumberGenerator) -> void:
	var label := Label3D.new()
	label.text = GRAFFITI[rng.randi_range(0, GRAFFITI.size() - 1)]
	label.font_size = 40
	label.pixel_size = 0.005
	label.modulate = Color(
			ThemeMaterials.spec(theme)["accent_color"]).lightened(0.2)
	label.modulate.a = 0.85
	label.position = at
	# Face into the corridor from whichever wall it is on.
	label.rotation.y = PI / 2.0 if at.x < 0 else -PI / 2.0
	label.rotation.z = rng.randf_range(-0.06, 0.06)
	root.add_child(label)

## Theme-signature props: what makes a gothic room gothic and a transit
## station a station. Wall-adjacent or ceiling-mounted; only floor pieces
## that hug walls may collide. `span_x` is the room width, `span_z` its
## depth/length; positions stay inside [1.2, span_z - 1.2].
static func _theme_props(root: Node3D, theme: String,
		rng: RandomNumberGenerator, span_x: float, span_z: float,
		height: float) -> void:
	var wall_x := span_x / 2.0
	# Colliding floor props are allowed only where the leftover lane still
	# admits the widest actor (the 1.8 m brute) with margin. A
	# schema-minimum 4 m corridor gets wall-mounted variants instead, so
	# the greeble invariant above stays literally true.
	var floor_props_ok := span_x - 2.0 * PROP_FOOTPRINT >= BRUTE_LANE
	var count := rng.randi_range(1, 2 + int(span_z / 10.0))
	for i in count:
		var z := rng.randf_range(1.4, span_z - 1.4)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		match theme:
			"gothic_stone":
				# Torch sconce: iron bracket, a flame that glows.
				_box(root, Vector3(0.12, 0.5, 0.12),
						Vector3(side * (wall_x - 0.16), 1.9, z),
						ThemeMaterials.trim_mat(theme), false)
				var flame := MeshInstance3D.new()
				var flame_mesh := PrismMesh.new()
				flame_mesh.size = Vector3(0.2, 0.35, 0.2)
				flame.mesh = flame_mesh
				flame.position = Vector3(side * (wall_x - 0.16), 2.35, z)
				flame.material_override = ThemeMaterials.glow_material(
						Color(1.0, 0.62, 0.2), 2.4)
				root.add_child(flame)
			"rusted_industrial":
				if floor_props_ok:
					# Oil drums against the wall, sometimes stacked.
					var drum := _cylinder_prop(root, 0.42, 0.95,
							Vector3(side * (wall_x - 0.75), 0.48, z),
							ThemeMaterials.accent_mat(theme))
					if rng.randf() < 0.4:
						var top := drum.duplicate()
						top.position.y += 0.95
						root.add_child(top)
				else:
					# Narrow space: a wall valve wheel instead.
					_box(root, Vector3(0.1, 0.7, 0.7),
							Vector3(side * (wall_x - 0.06), 1.5, z),
							ThemeMaterials.accent_mat(theme), false)
					_box(root, Vector3(0.16, 0.12, 0.12),
							Vector3(side * (wall_x - 0.2), 1.5, z),
							ThemeMaterials.trim_mat(theme), false)
			"neon_transit":
				# Hanging signage with authored transit nonsense.
				var signs := ["PLATFORM ε", "EXIT →", "← EXIT", "NO SIGNAL",
						"MIND THE STATIC", "TRANSFER: EVERYWHERE"]
				# ONE x for the plate and its text. This drew
				# `randf_range` twice, so the sign hung in one place and
				# its words in another -- the text was never on its own
				# plate, which is the "sign is off centre" from playtest
				# 1. Two draws from the same call read as one value at a
				# glance, and the second is a different number.
				var sign_x := rng.randf_range(-wall_x * 0.4, wall_x * 0.4)
				_box(root, Vector3(1.6, 0.5, 0.08),
						Vector3(sign_x, height - 0.7, z),
						ThemeMaterials.glow_material(
							Color(ThemeMaterials.spec(theme)["accent_color"]),
							1.3), false)
				var sign_label := Label3D.new()
				sign_label.text = signs[rng.randi_range(0, signs.size() - 1)]
				sign_label.font_size = 34
				sign_label.pixel_size = 0.004
				sign_label.modulate = Color(0.08, 0.09, 0.12)
				sign_label.position = Vector3(sign_x, height - 0.7, z - 0.05)
				# `face_label` takes a vector pointing TOWARD THE VIEWER
				# -- that is how the Hub calls it. A chamber is entered at
				# z = 0 and walked toward +z, so the viewer is always on
				# the sign's -Z side, which is `Vector3.FORWARD`.
				#
				# This passed `Vector3.BACK` and rendered every transit
				# sign as its own reflection. Playtest 1 found exactly
				# this in the Hub and it was fixed there; the guard was
				# then built around the Hub, so the Zone kept the bug for
				# two more playtests. `godot-legible` walks a built
				# chamber now as well as the Hub.
				face_label(sign_label, Vector3.FORWARD)
				root.add_child(sign_label)
			"temple_ruin":
				# Root tendrils crawling down the wall, or a column stump.
				if not floor_props_ok or rng.randf() < 0.5:
					var root_length := rng.randf_range(1.2,
							maxf(1.4, height - 0.6))
					_box(root, Vector3(0.1, root_length, 0.1),
							Vector3(side * (wall_x - 0.1),
								height - root_length / 2.0 - 0.2, z),
							ThemeMaterials.glow_material(
								Color(0.35, 0.5, 0.28), 0.15), false)
				else:
					var stump_height := rng.randf_range(0.6, 1.6)
					_cylinder_prop(root, 0.55, stump_height,
							Vector3(side * (wall_x - 0.85),
								stump_height / 2.0, z),
							ThemeMaterials.wall_mat(theme))
			"concrete_facility":
				# Bolted warning plate.
				_box(root, Vector3(0.06, 0.6, 0.9),
						Vector3(side * (wall_x - 0.05),
							rng.randf_range(1.2, 2.0), z),
						ThemeMaterials.hazard_mat(theme), false)
			"void_glitch":
				# The prop that never loaded.
				var missing := Label3D.new()
				missing.text = "prop_missing.mdl"
				missing.font_size = 28
				missing.pixel_size = 0.005
				missing.modulate = Color(1.0, 0.0, 0.9)
				missing.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				missing.position = Vector3(
						side * (wall_x - 0.9),
						rng.randf_range(0.6, height - 0.8), z)
				root.add_child(missing)

#: Epsilon's private notes, left up where the floor cannot take you.
const _SECRET_NOTES := [
	"You brought the right toy. I did not think you would.",
	"There is nothing up here. I built it anyway.",
	"Congratulations. This is the reward. It is a sentence.",
	"I hid this before I knew what you would be carrying.",
	"Somebody else's item paid for the jump you just made.",
	"This ledge is not in the schema. Do not tell anyone.",
	"If you are reading this, unequip and try walking it. You cannot.",
	"Every wall in here is 0.4 metres thick. Including this one.",
]

## A secret ledge has to clear two different things, and the second one
## bit: its UNDERSIDE must pass over the tallest actor in the game, or the
## slab becomes a wall the brute walks into. The brute's collider is 2.6 m
## (`Enemy.create`), and the integration driver cross-checks this constant
## against it so the two cannot drift apart.
const TALLEST_ACTOR := 2.6
const SECRET_LEDGE_THICKNESS := 0.3
const SECRET_UNDERSIDE_MIN := TALLEST_ACTOR + 0.15
## The lip, in turn, must be out of reach: a standing jump tops out at
## JUMP_APEX_HEIGHT (1.33 m) and the player has no mantle, so this clears
## it by better than a body length. A determined crate-hop off the arena's
## cover may still get you up there; that is allowed, because nothing up
## here is ever required.
const SECRET_LIP_MIN := SECRET_UNDERSIDE_MIN + SECRET_LEDGE_THICKNESS
const SECRET_LIP_MAX := 4.2
const SECRET_LEDGE_DEPTH := 1.8
#: Node group on a secret's trigger volume, so ZoneController can find one
#: without the builders having to hand a list back up through the chain.
const SECRET_GROUP := "secret_alcove"

## An optional ledge, holding a plaque and nothing else. DESIGN §19 permits
## exactly this: Echoes may open secrets, but never a mandatory path — so a
## secret never holds a reward, an exit or an objective, and the room plays
## identically if you never reach it.
##
## Built axis-aligned against the wall at `side * wall_x` rather than
## rotated into place, so the headless collider tests read its extents
## without having to unwind a basis.
## `floor_y` is the height of the floor a player would jump FROM, and
## every vertical measurement here is relative to it.
##
## It exists because an arena is not the only room with a floor. A
## platform_path's end ledge sits at `rise`, and a tower's top deck at its
## summit — both are flat ground the player is standing on, and both are
## the highest place base movement reaches in their chamber. Measuring the
## lip from absolute zero put the alcove *below* the player in either of
## them, which is a step rather than a secret.
static func _secret_alcove(root: Node3D, theme: String, side: float,
		wall_x: float, z: float, ceiling: float,
		rng: RandomNumberGenerator, floor_y := 0.0) -> void:
	var headroom := ceiling - floor_y
	var lip := floor_y + clampf(headroom - 2.4, SECRET_LIP_MIN, SECRET_LIP_MAX)
	# No headroom, no secret: a ledge you cannot stand on is a bump.
	if lip + Constants.PLAYER_HEIGHT + 0.3 > ceiling:
		return
	var inward := -side
	var center_x := side * (wall_x - 0.2) + inward * SECRET_LEDGE_DEPTH / 2.0
	_box(root, Vector3(SECRET_LEDGE_DEPTH, SECRET_LEDGE_THICKNESS, 2.4),
			Vector3(center_x, lip - SECRET_LEDGE_THICKNESS / 2.0, z),
			ThemeMaterials.accent_mat(theme))
	# The lip rail is decorative and non-colliding, so a hard landing is
	# never bounced back off the edge by a rail you meant to clear.
	_box(root, Vector3(0.12, 0.35, 2.4),
			Vector3(center_x + inward * (SECRET_LEDGE_DEPTH / 2.0 - 0.06),
				lip + 0.17, z), ThemeMaterials.trim_mat(theme), false)
	var glow := MeshInstance3D.new()
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(0.08, 0.45, 0.45)
	glow.mesh = glow_mesh
	glow.position = Vector3(side * (wall_x - 0.25), lip + 0.55, z)
	glow.material_override = ThemeMaterials.glow_material(
			Color(0.5, 1.0, 0.85), 1.8)
	root.add_child(glow)
	var note := Label3D.new()
	note.text = _SECRET_NOTES[rng.randi_range(0, _SECRET_NOTES.size() - 1)]
	note.font_size = 28
	note.pixel_size = 0.004
	note.width = 700
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.position = Vector3(center_x, lip + 1.1, z)
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	note.modulate = Color(0.6, 1.0, 0.88)
	root.add_child(note)
	# A trigger so the game can notice you got up here. Grouped rather than
	# wired: a chamber builder makes geometry and knows nothing about the
	# HUD. It carries no reward and reports nothing to Archipelago.
	var trigger := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SECRET_LEDGE_DEPTH, 2.0, 2.4)
	shape.shape = box
	trigger.add_child(shape)
	trigger.position = Vector3(center_x, lip + 1.0, z)
	trigger.add_to_group(SECRET_GROUP)
	root.add_child(trigger)

## Corner buttresses, perimeter crates and a hazard strip for room-like
## spaces. Crates hug the walls so the arena floor stays fightable.
static func _greeble_room(root: Node3D, width: float, depth: float,
		height: float, theme: String, rng: RandomNumberGenerator) -> void:
	var trim := ThemeMaterials.trim_mat(theme)
	var accent := ThemeMaterials.accent_mat(theme)
	for corner_x in [-1.0, 1.0]:
		for corner_z in [0.0, 1.0]:
			_box(root, Vector3(0.5, height, 0.5),
					Vector3(corner_x * (width / 2.0 - 0.3), height / 2.0,
						0.35 + corner_z * (depth - 0.7)), trim, false)
	for i in rng.randi_range(2, 4):
		var against_x := rng.randf() < 0.5
		var size := rng.randf_range(0.7, 1.3)
		var crate_position: Vector3
		if against_x:
			crate_position = Vector3(
					(-1.0 if rng.randf() < 0.5 else 1.0)
					* (width / 2.0 - size / 2.0 - 0.4),
					size / 2.0, rng.randf_range(2.0, depth - 2.0))
		else:
			# Back wall — keep clear of the exit door lane (a 1.3 m crate is
			# taller than MAX_VERTICAL_STEP, so it must never block a door).
			var lane := rng.randf_range(2.0, maxf(2.2, width / 2.0 - 2.0))
			crate_position = Vector3(
					lane * (-1.0 if rng.randf() < 0.5 else 1.0),
					size / 2.0, depth - size / 2.0 - 1.2)
		var crate := _box(root, Vector3(size, size, size), crate_position,
				accent, true)
		crate.rotation.y = rng.randf_range(-0.2, 0.2)
	# There WAS a hazard strip across every room's threshold here.
	#
	# Owner ruling 2026-08-28 (art requirement 20): hazard orange is
	# reserved for hazard and warning semantics. A threshold marking can
	# be legitimate caution language where there is a step or a lip;
	# applied to every room unconditionally it was decoration in the
	# loudest colour the palette has, and spending it on ordinary
	# architecture is how it stops meaning anything.
	#
	# Nothing replaces it. If playtesting shows thresholds need marking,
	# it is solved with a non-hazard channel -- neutral architectural
	# contrast, light placement, a trim or value change, or the future
	# approved signage language -- not by putting the orange back.
	_theme_props(root, theme, rng, width, depth, height)

# ---------------------------------------------------------------------------

static func build(chamber: Dictionary, theme: String) -> Dictionary:
	var result: Dictionary
	match chamber.get("type", ""):
		"corridor": result = corridor(chamber, theme)
		"arena": result = arena(chamber, theme)
		"platform_path": result = platform_path(chamber, theme)
		"tower": result = tower(chamber, theme)
		"treasure_room": result = treasure_room(chamber, theme)
		_: result = corridor({"length": 8.0, "width": 4.0}, theme)
	# Affordance features (§13) go in AFTER the room exists, because the
	# only safe way to place one is against the room's real extent — the
	# generator gives a fraction, this end owns the metres.
	var bounds: AABB = result["bounds"]
	result["features"] = AffordanceFeatures.place_all(
			result["root"], chamber, theme,
			bounds.size.x, bounds.size.z,
			float(result.get("room_height", CORRIDOR_HEIGHT)))
	return result

static func corridor(chamber: Dictionary, theme: String) -> Dictionary:
	var length := float(chamber.get("length", 12.0))
	var width := float(chamber.get("width", 5.0))
	# A corridor is the ONLY chamber that may carry an affordance feature
	# (every other type has a Check or a gating objective, and §13.2 bars
	# features from both), and the standard 3.6 m ceiling is not enough for
	# a grapple ledge or a bounce arc. So a corridor carrying one is built
	# to the height that feature needs.
	#
	# The alternative — clamping the feature to whatever fits — is what the
	# first version did, and it put the grapple plate, the bounce reward
	# and the wind perch above a solid ceiling slab where nothing could
	# reach them.
	var height := maxf(CORRIDOR_HEIGHT,
			AffordanceFeatures.required_height(chamber))
	var root := Node3D.new()
	_box(root, Vector3(width, 0.5, length),
			Vector3(0, -0.25, length / 2.0), ThemeMaterials.floor_mat(theme))
	var wall := ThemeMaterials.wall_mat(theme)
	_box(root, Vector3(WALL_THICKNESS, height, length),
			Vector3(-width / 2.0, height / 2.0, length / 2.0), wall)
	_box(root, Vector3(WALL_THICKNESS, height, length),
			Vector3(width / 2.0, height / 2.0, length / 2.0), wall)
	_box(root, Vector3(width, WALL_THICKNESS, length),
			Vector3(0, height, length / 2.0),
			ThemeMaterials.trim_mat(theme))
	# Ends, with a doorway through each.
	#
	# The playtest-2 fix named the three builders that raise their own
	# walls and therefore had no ends -- `corridor`, `platform_path`,
	# `corner` -- and then gave ends to two of them. A corridor stayed
	# open across its FULL WIDTH at both mouths, which nothing noticed
	# because a corridor in the middle of a chain has a neighbour parked
	# against each end. The two places it shows are the two places a
	# neighbour is narrower or absent: a wide corridor meeting a 4 m
	# connector leaves metres of open wall either side of the seam, and
	# the FIRST chamber of a Zone has nothing in front of it at all.
	# That second one is what playtest 2.5 walked up to.
	#
	# Inset by half a wall so the geometry stays inside the bounds this
	# builder declares. Two pieces then meet back-to-back at the seam
	# rather than occupying the same slab -- the difference between a
	# door frame and a z-fight.
	_end_wall(root, width, height, WALL_THICKNESS / 2.0, wall)
	_end_wall(root, width, height, length - WALL_THICKNESS / 2.0, wall)
	# Pipes along one wall: the load-bearing GoldSrc prop.
	var pipe := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.12
	cylinder.bottom_radius = 0.12
	cylinder.height = length
	pipe.mesh = cylinder
	pipe.rotation.x = PI / 2.0
	pipe.position = Vector3(width / 2.0 - 0.3, height - 0.5,
			length / 2.0)
	pipe.material_override = ThemeMaterials.trim_mat(theme)
	root.add_child(pipe)
	var count := maxi(1, int(length / 8.0))
	for i in count:
		_light(root, Vector3(0, height - 0.3,
				length * (i + 0.5) / count), theme)
	_greeble_corridor(root, length, width, height, theme,
			_greeble_rng(chamber, theme))
	var spawns: Array = []
	for group: Dictionary in chamber.get("enemies", []):
		for i in int(group.get("count", 0)):
			spawns.append({"archetype": group["archetype"],
					"position": Vector3(
						fposmod(float(i) * 1.7, width - 1.6) - (width - 1.6) / 2.0,
						0.2, length * 0.4 + float(i) * 1.9)})
	return {"root": root, "exit_offset": Vector3(0, 0, length),
			"bounds": AABB(Vector3(-width / 2.0, -1, 0),
					Vector3(width, height + 1, length)),
			"enemy_spawns": spawns,
			"room_height": height,
			"reward_position": Vector3(0, 0, length / 2.0)}

## ROOM GRAMMAR v0: a second walkable height inside an ordinary room.
##
## Returns the SOCKETS it created -- positions on real surfaces that
## composition may place things onto.
##
## Sockets are the answer to the bug class this project keeps paying for:
## THE BUILDER KNOWS PHYSICAL FACTS THE COMPOSER DOES NOT. Activities
## landed inside props, in mid-air and on top of each other, and each was
## fixed afterwards by handing the composer more information. A socket is
## a point the builder VOUCHES FOR, so anything placed on one is
## supported and clear by construction rather than by a later audit.
static func _elevation_band(root: Node3D, band: Dictionary, width: float,
		depth: float, theme: String) -> Array:
	var kind := str(band.get("kind", "gallery"))
	var rise := float(band.get("rise", 2.0))
	var coverage := clampf(float(band.get("coverage", 0.35)), 0.2, 0.55)
	var side := str(band.get("side", "left"))
	var access := str(band.get("access", "ramp"))
	var deck := ThemeMaterials.floor_mat(theme)
	var trim := ThemeMaterials.trim_mat(theme)
	var sockets: Array = []

	var rect := band_rect(band, width, depth)
	var span_x := rect.size.x
	var span_z := rect.size.y
	var centre_x := rect.get_center().x
	var centre_z := rect.get_center().y

	var surface := rise if kind == "gallery" else -rise
	if kind == "gallery":
		# The deck, and a lip so the edge reads from below rather than
		# being a texture change you notice by falling off it.
		_box(root, Vector3(span_x, 0.4, span_z),
				Vector3(centre_x, rise - 0.2, centre_z), deck)
		var lip_x := span_x if side == "back" else 0.25
		var lip_z := 0.25 if side == "back" else span_z
		var edge_x := centre_x + (span_x / 2.0 - 0.12) * (
				1.0 if side == "left" else -1.0)
		var edge_z := centre_z - span_z / 2.0 + 0.12
		_box(root, Vector3(lip_x, 0.35, lip_z),
				Vector3(centre_x if side == "back" else edge_x,
					rise + 0.17,
					edge_z if side == "back" else centre_z), trim)
	else:
		# A pit is a hole, so the floor slab is not carved -- the walls
		# of the recess are built and the deck is dropped. Carving the
		# base slab is what `_carve_gap` never actually did, and a pit
		# with a floor across it is not a pit.
		_box(root, Vector3(span_x, 0.4, span_z),
				Vector3(centre_x, -rise - 0.2, centre_z), deck)
		for wall: Array in [
				[Vector3(0.3, rise, span_z), Vector3(
					centre_x + span_x / 2.0, -rise / 2.0, centre_z)],
				[Vector3(0.3, rise, span_z), Vector3(
					centre_x - span_x / 2.0, -rise / 2.0, centre_z)],
				[Vector3(span_x, rise, 0.3), Vector3(
					centre_x, -rise / 2.0, centre_z - span_z / 2.0)]]:
			_box(root, wall[0] as Vector3, wall[1] as Vector3, trim)

	# ACCESS. A ramp is base-kit traversal in both directions, which is
	# what keeps NO REQUIREMENT BEFORE GUARANTEE true of geometry: a band
	# holding anything required must be reachable by movement the
	# campaign is guaranteed to have, and walking always is.
	#
	# The run is three times the rise, so the slope is the same gentle
	# angle whatever the band's height -- a fixed-length ramp gets
	# steeper as the band rises, and there is no reason to make the tall
	# ones the hard ones.
	var run := maxf(3.0, absf(rise) * 3.0)
	var width_of_ramp := 2.6
	# The prism's slope runs along its X and its apex sits at -X, so the
	# apex end is placed against the deck's inner edge and the ramp is
	# turned to face it.
	var ramp_at := Vector3.ZERO
	var turn := 0.0
	match side:
		"left":
			ramp_at = Vector3(centre_x + span_x / 2.0 + run / 2.0,
					surface / 2.0, centre_z)
		"right":
			ramp_at = Vector3(centre_x - span_x / 2.0 - run / 2.0,
					surface / 2.0, centre_z)
			turn = PI
		_:
			ramp_at = Vector3(centre_x,
					surface / 2.0, centre_z - span_z / 2.0 - run / 2.0)
			turn = -PI / 2.0
	var size := Vector3(run, absf(rise), width_of_ramp)
	# A pit's ramp descends, so its high end faces the ROOM rather than
	# the deck: the same wedge, turned the other way.
	if kind == "pit":
		turn += PI
	_wedge(root, size, ramp_at, deck, turn, 0.0)
	# WHERE THE WAY UP IS. Emitted as a socket so nothing has to rederive
	# it: a test walking "toward the band" found the gallery's edge and
	# reported a 2.2 m step, which is a correct measurement of the wrong
	# surface. The builder knows where the ramp is; saying so is cheaper
	# than every caller guessing.
	sockets.append({"kind": "access",
			"position": Vector3(ramp_at.x, 0.0, ramp_at.z),
			"along": "z" if side == "back" else "x",
			"length": run})
	# AND THE RAMP IS SPOKEN FOR TOO. A 3-to-1 ramp is over six metres
	# long, which is exactly the size at which `solid_boxes` stops
	# calling something furniture and starts calling it architecture --
	# so the one obstacle in the room nobody could see was the way up.
	# Two activity elements of the played Zone's c015 were inside it.
	# Architecture that content must avoid is DECLARED, never inferred.
	var ramp_span := Vector3(run, 0.0, width_of_ramp)
	if side == "back":
		ramp_span = Vector3(width_of_ramp, 0.0, run)
	ramp_span.y = maxf(absf(rise), 2.4) * 2.0
	sockets.append({"kind": "reserved", "name": "band_ramp",
			"position": Vector3(ramp_at.x, 0.0, ramp_at.z),
			"extent": ramp_span})

	# Sockets ON the band's deck, inset so nothing sits on the lip.
	var inset := 1.1
	for t: float in [0.3, 0.7]:
		var socket_x := centre_x
		var socket_z := centre_z
		if side == "back":
			socket_x = -span_x / 2.0 + inset + (span_x - inset * 2.0) * t
		else:
			socket_z = centre_z - span_z / 2.0 + inset \
					+ (span_z - inset * 2.0) * t
		sockets.append({"kind": "enemy_high",
				"position": Vector3(socket_x, surface + 0.2, socket_z)})
	sockets.append({"kind": "cover",
			"position": Vector3(centre_x, surface + 0.4,
				centre_z + span_z * 0.18 * (1.0 if side == "back" else 1.0))})
	# THE FOOTPRINT IS SPOKEN FOR at ground level. A gallery's deck is a
	# floor when you are on it and a ceiling when you are under it, and
	# ground-level composition has to treat it as neither: the space
	# below it belongs to the band. Said here rather than inferred,
	# because "the builder knows physical facts the composer does not" is
	# the bug class this whole contract exists to end -- the first run
	# with bands put six activity elements inside a deck.
	sockets.append({"kind": "reserved", "name": "band_deck",
			"position": Vector3(centre_x, 0.0, centre_z),
			"extent": Vector3(span_x, maxf(absf(rise), 2.4) * 2.0, span_z)})
	return sockets

static func arena(chamber: Dictionary, theme: String) -> Dictionary:
	var width := float(chamber.get("width", 16.0))
	var depth := float(chamber.get("depth", 16.0))
	var wall_height := float(chamber.get("wall_height", 5.0))
	var root := Node3D.new()
	# The floor goes down FIRST and has to know about a pit already: the
	# recess is dug later, and a slab laid across the whole room before
	# that is a lid.
	var declared: Variant = chamber.get("elevation")
	var hole: Variant = null
	if typeof(declared) == TYPE_DICTIONARY \
			and str((declared as Dictionary).get("kind", "")) == "pit":
		hole = band_rect(declared as Dictionary, width, depth)
	_floor_with_hole(root, width, depth, ThemeMaterials.floor_mat(theme),
			hole)
	_perimeter(root, width, depth, wall_height, theme)
	# ROOM GRAMMAR v0's band, built BEFORE anything is scattered.
	#
	# It used to go in near the end, which was fine while nothing else
	# needed to know where it was. The Check's space does: a `back`
	# gallery at 0.41 coverage reaches z = 0.59..1.0 of the room and its
	# access ramp reaches most of the rest, and the pedestal anchor sat
	# in both. Reordering rather than recomputing the band's footprint
	# somewhere else is the point -- `_elevation_band` already DECLARES
	# its deck and its ramp as `reserved`, and a second derivation of a
	# fact one function already owns is how the two come to disagree.
	# Nothing here consumes randomness, so the room is unchanged by the
	# move.
	var sockets: Array = []
	var band: Variant = chamber.get("elevation")
	if typeof(band) == TYPE_DICTIONARY:
		sockets = _elevation_band(root, band as Dictionary, width, depth,
				theme)

	# WHERE THE CHECKS GO, decided before anything is scattered.
	#
	# The room's own props used to be placed first and the reward anchor
	# announced afterwards, so a crate could stand exactly where the
	# pedestal was going to. Computing the anchor first and refusing to
	# build a prop inside it is the same move the ground sockets make:
	# the builder knows both facts, so the builder is what reconciles
	# them.
	var claimed: Array[AABB] = []
	for socket: Dictionary in sockets:
		if str(socket.get("kind", "")) == "reserved":
			var at: Vector3 = socket["position"]
			var extent: Vector3 = socket["extent"]
			claimed.append(AABB(at - extent * 0.5, extent))
	var reward_at := _reward_anchor(chamber, width, depth, claimed)
	var reward_box := reward_clearance(chamber, reward_at)
	if reward_box.size != Vector3.ZERO:
		claimed.append(reward_box)
	# Crude cover: a few boxes and a wedge.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(chamber.get("id", "c")) + theme)
	for i in 3:
		var size := Vector3(rng.randf_range(1.2, 2.4), rng.randf_range(0.8, 2.0),
				rng.randf_range(1.2, 2.4))
		# ONE roll, then a deterministic sweep. Rolling alternates was
		# the obvious fix and the wrong one: it moves the rng stream, so
		# every prop in every room without a conflict would have shifted
		# too. Taking the room's own first choice and then searching
		# WITHOUT randomness leaves an unconflicted room byte-identical
		# to what it was, and it is the same shape as
		# `Activities._free_spot` -- ideal, then a grid, and the ideal
		# again only if the room really is full.
		#
		# Cover is not deleted near a Check. It is placed where a Check
		# is not.
		var ideal := Vector3(
				rng.randf_range(-width / 2.0 + 2.5, width / 2.0 - 2.5),
				size.y / 2.0,
				rng.randf_range(depth * 0.25, depth * 0.75))
		var at := _free_prop_spot(ideal, size, width, depth, claimed)
		_box(root, size, at, ThemeMaterials.accent_mat(theme))
		claimed.append(AABB(at - size / 2.0, size))
	var wedge_at := Vector3(width * 0.25, 0.6, depth * 0.6)
	var wedge_size := Vector3(2.2, 1.2, 2.2)
	# The wedge has one home and no alternates; when that home is inside
	# the Check's space the wedge is the thing that yields.
	if not box_hits(AABB(wedge_at - wedge_size / 2.0, wedge_size), claimed):
		_wedge(root, wedge_size, wedge_at,
				ThemeMaterials.floor_mat(theme), rng.randf_range(0.0, TAU))
	else:
		rng.randf_range(0.0, TAU)   # keep the stream identical either way
	for corner in [Vector3(-width / 2.0 + 2, wall_height - 0.5, 2),
			Vector3(width / 2.0 - 2, wall_height - 0.5, depth - 2)]:
		_light(root, corner, theme, 16.0)
	_light(root, Vector3(0, wall_height - 0.5, depth / 2.0), theme, 18.0)
	var greeble_rng := _greeble_rng(chamber, theme)
	_greeble_room(root, width, depth, wall_height, theme, greeble_rng)
	# Roughly one arena in three gets a ledge you cannot walk to. It holds
	# nothing but one of Epsilon's notes; see `_secret_alcove`.
	if greeble_rng.randf() < 0.34:
		_secret_alcove(root, theme,
				-1.0 if greeble_rng.randf() < 0.5 else 1.0, width / 2.0,
				greeble_rng.randf_range(3.0, maxf(3.2, depth - 3.0)),
				wall_height, greeble_rng)
	var lowest := -1.0
	if typeof(band) == TYPE_DICTIONARY \
			and str((band as Dictionary).get("kind", "")) == "pit":
		lowest = -float((band as Dictionary).get("rise", 2.0)) - 1.0

	# The Check's space, said out loud. Declaring it rather than merely
	# avoiding it is what makes it true for the composer as well: nothing
	# reads `reward_position`, so an activity element or a barrel could
	# stand on the pedestal and no rule anywhere would object.
	if reward_box.size != Vector3.ZERO:
		sockets.append({"kind": "reserved", "name": "reward_lane",
				"position": reward_box.get_center(),
				"extent": reward_box.size})

	# Ground sockets, for the things a room stands on its floor. Kept out
	# of the walking lane the same way affordances and activities are --
	# and, unlike the first version of this loop, VOUCHED FOR.
	#
	# A socket is a promise that the point is on real floor and clear of
	# what is already there. Offering six fixed spots and hoping was the
	# same mistake the pressure plates made: three of the six landed
	# inside the room's own crates and, in a room with a gallery, inside
	# the gallery's solid mass. The builder knows where it put those, so
	# the builder is the one that can answer.
	var solids := solid_boxes(root)
	var reserved: Array[AABB] = []
	for socket: Dictionary in sockets:
		if str(socket.get("kind", "")) == "reserved":
			var at: Vector3 = socket["position"]
			var extent: Vector3 = socket["extent"]
			reserved.append(AABB(at - extent * 0.5, extent))
	for t: float in [0.28, 0.52, 0.76]:
		for side: float in [-1.0, 1.0]:
			var kind := "cover" if t > 0.4 else "reactive"
			var size := _ground_socket_size(kind)
			var foot := Vector3(side * width * 0.32, 0.0, depth * t)
			# Padded, so an object does not merely graze a crate.
			var claim := AABB(foot - Vector3(size.x / 2.0 + 0.25, 0.0,
					size.z / 2.0 + 0.25),
					Vector3(size.x + 0.5, size.y, size.z + 0.5))
			if box_hits(claim, solids) or box_hits(claim, reserved):
				continue
			sockets.append({"kind": kind, "position": foot,
					"extent": size})
			solids.append(claim)

	var spawns: Array = []
	var index := 0
	# RANGED UNITS TAKE THE HIGH GROUND. The measured problem: twenty-eight
	# of the played Zone's forty-one enemies were ranged, in flat boxes,
	# with no height to shoot from -- which makes a ranged enemy a melee
	# enemy that misses. This is placement, not AI: the archetypes and
	# their behaviour are untouched.
	var high: Array = []
	for socket: Dictionary in sockets:
		if str(socket.get("kind", "")) == "enemy_high":
			high.append(socket["position"])
	var taken_high := 0
	for group: Dictionary in chamber.get("enemies", []):
		for i in int(group.get("count", 0)):
			var at: Vector3
			if str(group["archetype"]) == "ranged" and taken_high < high.size():
				at = high[taken_high]
				taken_high += 1
			else:
				var angle := TAU * float(index) / 8.0
				at = Vector3(cos(angle) * width * 0.3, 0.2,
						depth / 2.0 + sin(angle) * depth * 0.3)
			spawns.append({"archetype": group["archetype"], "position": at})
			index += 1
	return {"root": root, "exit_offset": Vector3(0, 0, depth),
			"bounds": AABB(Vector3(-width / 2.0, lowest, 0),
					Vector3(width, wall_height - lowest, depth)),
			"enemy_spawns": spawns,
			"sockets": sockets,
			"room_height": wall_height,
			"reward_position": reward_at}

static func platform_path(chamber: Dictionary, theme: String) -> Dictionary:
	var segments := int(chamber.get("segment_count", 4))
	var gap := float(chamber.get("gap_size", 2.0))
	var step := float(chamber.get("vertical_step", 0.5))
	var platform := float(Constants.MIN_PLATFORM_SIZE)
	var width := 8.0
	var ledge := 4.0
	var total := ledge + (gap + platform) * segments + gap + ledge
	var rise := step * float(segments)
	var wall_height := rise + 6.0
	var root := Node3D.new()
	var floor_mat := ThemeMaterials.floor_mat(theme)
	# WHERE THE FLOOR ACTUALLY IS, said out loud as it is built.
	#
	# A `platform_path` has no floor. It has a start ledge, a handful of
	# rising islands and an end ledge, with a kill pit under everything
	# else -- and every consumer that treated its BOUNDS as a room laid
	# content out over the void. Twenty-three activity elements across
	# five rooms were standing on nothing, which is the defect this
	# vocabulary exists to end: the builder knows which square metres
	# hold weight, so the builder is what says so.
	var stands: Array = []
	var stands_traversal: Array = []
	var ledge_span := width - WALL_THICKNESS * 2.0
	# Start ledge.
	_box(root, Vector3(width, 0.5, ledge),
			Vector3(0, -0.25, ledge / 2.0), floor_mat)
	stands.append({"kind": "stand",
			"position": Vector3(0, 0.0, ledge / 2.0),
			"extent": Vector3(ledge_span, 0.0, ledge)})
	# Platforms, rising by `step` each. Crude prism feet make them read as
	# brushwork rather than floating tiles.
	for i in segments:
		var z := ledge + gap + (gap + platform) * float(i) + platform / 2.0
		var y := step * float(i + 1)
		_box(root, Vector3(platform, 0.6, platform),
				Vector3(0, y - 0.3, z), floor_mat)
		_wedge(root, Vector3(platform * 0.7, 0.5, platform * 0.7),
				Vector3(0, y - 0.75, z), ThemeMaterials.trim_mat(theme))
		# Offered like any other surface, and refused by the same rule
		# that refuses a crate in a doorway: a 2.5 m island cannot keep
		# BRUTE_LANE clear beside anything, and it is the MANDATORY
		# ROUTE over a kill pit. Said as a measurement rather than as a
		# special case, so the day a builder makes a wide platform, the
		# wide platform is usable.
		stands.append({"kind": "stand",
				"position": Vector3(0, y, z),
				"extent": Vector3(platform, 0.0, platform)})
	# End ledge at full rise.
	_box(root, Vector3(width, 0.5, ledge),
			Vector3(0, rise - 0.25, total - ledge / 2.0), floor_mat)
	stands.append({"kind": "stand",
			"position": Vector3(0, rise, total - ledge / 2.0),
			"extent": Vector3(ledge_span, 0.0, ledge)})
	# AND THE JUMPS, in the contract's own words.
	#
	# This room has always had mandatory jumps and has never said so out
	# loud: `gap_size` is bounded by `max_safe_gap(vertical_step)` in the
	# schema, and nothing downstream could see that a jump existed. An
	# authored shell declares its traversal, so the procedural producer
	# that actually HAS traversal should declare it too -- otherwise the
	# audit measures the movement law on one producer and takes the
	# other's word for it, which is the asymmetry the contract exists to
	# end. Endpoints are the real edges, so the span the audit measures
	# is the gap itself and not the gap plus an inset.
	for i in segments + 1:
		var from_z := ledge + (gap + platform) * float(i)
		stands_traversal.append({
			"name": "hop_%d" % i,
			"kind": "gap",
			"mandatory": true,
			"start": Vector3(0, step * float(i), from_z),
			"end": Vector3(0, step * float(mini(i + 1, segments)),
					from_z + gap),
		})
	# The pit: deep enough that a fall passes FALL_KILL_Y.
	_box(root, Vector3(width, 0.5, total),
			Vector3(0, Constants.FALL_KILL_Y - 6.0, total / 2.0),
			ThemeMaterials.hazard_mat(theme), false)
	# Side walls, full height.
	var wall := ThemeMaterials.wall_mat(theme)
	_box(root, Vector3(WALL_THICKNESS, wall_height + 40.0, total),
			Vector3(-width / 2.0, wall_height / 2.0 - 20.0, total / 2.0), wall)
	_box(root, Vector3(WALL_THICKNESS, wall_height + 40.0, total),
			Vector3(width / 2.0, wall_height / 2.0 - 20.0, total / 2.0), wall)
	# Ends and a ceiling. There were none: the lights below hung off
	# nothing, and the chamber was open to the void sideways of its own
	# doorways. The exit doorway is raised by `rise` because that is
	# where the path leaves from.
	_end_wall(root, width, wall_height, 0.0, wall)
	_end_wall(root, width, wall_height, total, wall, rise)
	_box(root, Vector3(width, WALL_THICKNESS, total),
			Vector3(0, wall_height, total / 2.0),
			ThemeMaterials.trim_mat(theme))
	# Half the segments, rounded down: an odd count gets the smaller
	# half, which is what the layout wants.
	@warning_ignore("integer_division")
	var pairs := maxi(2, segments / 2)
	for i in pairs:
		_light(root, Vector3(0, rise + 4.0,
				total * (float(i) + 0.5) / maxf(2.0, segments / 2.0)), theme,
				18.0)
	# Roughly one platform_path in three grows a secret, over the END
	# LEDGE. That ledge is the highest flat ground in the chamber and the
	# last thing the mandatory route touches, so a shelf above it is out of
	# reach of a standing jump from anywhere a base kit can stand — the
	# same argument the arena's alcove makes, applied to the floor that
	# happens to be at `rise` rather than at zero.
	#
	# Never over the platforms: a shelf above the route would be a shelf
	# somebody tries to jump to from a platform over a bottomless pit.
	var path_rng := _greeble_rng(chamber, theme)
	if path_rng.randf() < 0.34:
		_secret_alcove(root, theme,
				-1.0 if path_rng.randf() < 0.5 else 1.0, width / 2.0,
				total - ledge / 2.0, wall_height, path_rng, rise)
	var spawns: Array = []
	for group: Dictionary in chamber.get("enemies", []):
		for i in int(group.get("count", 0)):
			spawns.append({"archetype": group["archetype"],
					"position": Vector3(0, rise + 0.3,
							total - ledge + float(i) * 1.5)})
	return {"root": root, "exit_offset": Vector3(0, rise, total),
			"bounds": AABB(Vector3(-width / 2.0, -40, 0),
					Vector3(width, wall_height + 41.0, total)),
			"enemy_spawns": spawns,
			"sockets": stands,
			"traversal": stands_traversal,
			"room_height": wall_height,
			"reward_position": Vector3(0, rise, total - ledge / 2.0),
			"goal_area_position": Vector3(0, rise + 1.0, total - ledge)}

static func tower(chamber: Dictionary, theme: String) -> Dictionary:
	## A vertical shaft climbed on a square spiral of wall-hugging platforms.
	## Each platform rises `step_rise` ≤ MAX_VERTICAL_STEP, so the mandatory
	## route needs only base jumping — the template's guarantee.
	var floors := int(chamber.get("floors", 3))
	var side := 12.0
	var per_floor := 3.0
	var total_rise := per_floor * float(floors)
	var step_rise := minf(1.0, float(Constants.MAX_VERTICAL_STEP))
	var root := Node3D.new()
	var floor_mat := ThemeMaterials.floor_mat(theme)
	_box(root, Vector3(side, 0.5, side),
			Vector3(0, -0.25, side / 2.0), floor_mat)
	# The exit door is carved at summit height — the tower is climbed, and
	# its way out is at the top of the back wall.
	var summit := step_rise * ceilf(total_rise / step_rise)
	# Rolled BEFORE the shaft is built, because a tower that grows a secret
	# is a taller tower. Five metres over the summit leaves the alcove
	# 0.15 m short of standing room and `_secret_alcove` declines to build
	# it — silently, which is the worst of both.
	var tower_rng := _greeble_rng(chamber, theme)
	var wants_secret := tower_rng.randf() < 0.34
	var shaft_height := total_rise + (6.5 if wants_secret else 5.0)
	_perimeter(root, side, side, shaft_height, theme, true, true, summit)

	# Central column, so the shaft reads as a structure and blocks
	# straight-line ranged fire across it.
	_box(root, Vector3(2.2, total_rise + 2.0, 2.2),
			Vector3(0, (total_rise + 2.0) / 2.0 - 0.5, side / 2.0),
			ThemeMaterials.accent_mat(theme))

	# Square spiral path around the shaft interior.
	var inset := side / 2.0 - 1.7
	var margin := 2.0
	var corners := [
		Vector3(-inset, 0, margin), Vector3(-inset, 0, side - margin),
		Vector3(inset, 0, side - margin), Vector3(inset, 0, margin),
	]
	var platform_count := int(ceil(total_rise / step_rise))
	# The furthest a base jump may be ASKED to reach when landing
	# `step_rise` higher. This was a typed 2.4 against a bound of 2.0 --
	# the same bound `platform_path.gap_size` is held to in the schema,
	# so the engine was breaking a rule it imposes on Epsilon. Derived,
	# not typed, so it cannot drift from the movement constants again.
	var spacing := Constants.max_safe_gap(step_rise)
	var leg := 0
	var leg_progress := 0.0
	var platform_positions: Array[Vector3] = []
	for i in platform_count:
		var a: Vector3 = corners[leg % 4]
		var b: Vector3 = corners[(leg + 1) % 4]
		var leg_length := a.distance_to(b)
		leg_progress += spacing
		while leg_progress > leg_length:
			leg_progress -= leg_length
			leg += 1
			a = corners[leg % 4]
			b = corners[(leg + 1) % 4]
			leg_length = a.distance_to(b)
		var along := a.lerp(b, leg_progress / leg_length)
		var y := step_rise * float(i + 1)
		platform_positions.append(Vector3(along.x, y, along.z))
		_box(root, Vector3(2.6, 0.4, 2.6),
				Vector3(along.x, y - 0.2, along.z), floor_mat)
	# Top deck across the back, at the summit.
	var top_y := step_rise * float(platform_count)
	_box(root, Vector3(side, 0.5, 4.0),
			Vector3(0, top_y, side - 2.0), floor_mat)
	# Bridge strip out through the back wall to the exit.
	_box(root, Vector3(3.0, 0.5, 2.4),
			Vector3(0, top_y, side + 1.0), floor_mat)
	# Roughly one tower in three grows a secret over the TOP DECK. The
	# spiral hugs the walls the whole way up, so a shelf partway up the
	# shaft would be a step off the nearest platform rather than a secret;
	# above the deck is the one height the climb has finished at, and the
	# shaft is built `total_rise + 5` tall, which leaves the headroom.
	if wants_secret:
		_secret_alcove(root, theme,
				-1.0 if tower_rng.randf() < 0.5 else 1.0, side / 2.0,
				side - 2.0, shaft_height, tower_rng, top_y)

	for level in range(0, int(total_rise / per_floor) + 1):
		_light(root, Vector3(0, per_floor * float(level) + 2.5,
				side / 2.0), theme, 14.0)
	var spawns: Array = []
	var index := 0
	for group: Dictionary in chamber.get("enemies", []):
		for i in int(group.get("count", 0)):
			var spot := platform_positions[
					(index * 3 + 2) % platform_positions.size()] \
					if not platform_positions.is_empty() \
					else Vector3(0, 0.3, side * 0.6)
			spawns.append({"archetype": group["archetype"],
					"position": Vector3(spot.x * 0.6, spot.y + 0.3, spot.z)})
			index += 1
	return {"root": root, "exit_offset": Vector3(0, top_y, side + 2.2),
			"bounds": AABB(Vector3(-side / 2.0, -1, 0),
					Vector3(side, shaft_height + 1.0, side + 2.2)),
			"enemy_spawns": spawns,
			"room_height": shaft_height,
			# The ascent, so a test can MEASURE the mandatory jumps
			# rather than infer them from the source. Reading the code
			# proves the spacing is derived; reading the positions proves
			# the geometry that came out of it is walkable.
			"platforms": platform_positions,
			"reward_position": Vector3(-2.0, top_y, side - 2.0)}

## A 90° corner piece for non-linear layouts. Entrance on local z=0 facing
## +Z; exit through the +X wall (turn=+1) or -X wall (turn=-1) at z=S/2.
## The new heading after this piece is yaw + turn * PI/2.
static func corner(turn: int, theme: String) -> Dictionary:
	var S := 6.0
	var H := CORRIDOR_HEIGHT
	var root := Node3D.new()
	var wall := ThemeMaterials.wall_mat(theme)
	_box(root, Vector3(S, 0.5, S), Vector3(0, -0.25, S / 2.0),
			ThemeMaterials.floor_mat(theme))
	_box(root, Vector3(S, WALL_THICKNESS, S), Vector3(0, H, S / 2.0),
			ThemeMaterials.trim_mat(theme))
	# Entrance wall (z=0) with a centered door.
	var side := (S - DOOR_WIDTH) / 2.0
	for sign_x in [-1.0, 1.0]:
		_box(root, Vector3(side, H, WALL_THICKNESS),
				Vector3(sign_x * (DOOR_WIDTH + side) / 2.0, H / 2.0, 0), wall)
	_box(root, Vector3(DOOR_WIDTH, H - DOOR_HEIGHT, WALL_THICKNESS),
			Vector3(0, DOOR_HEIGHT + (H - DOOR_HEIGHT) / 2.0, 0), wall)
	# Back wall (z=S): solid.
	_box(root, Vector3(S, H, WALL_THICKNESS), Vector3(0, H / 2.0, S), wall)
	# Exit wall (x = turn * S/2) with a door centered at z = S/2; the other
	# side wall is solid.
	var exit_x := float(turn) * S / 2.0
	for seg in [[0.0, S / 2.0 - DOOR_WIDTH / 2.0],
			[S / 2.0 + DOOR_WIDTH / 2.0, S]]:
		var seg_length: float = seg[1] - seg[0]
		_box(root, Vector3(WALL_THICKNESS, H, seg_length),
				Vector3(exit_x, H / 2.0, seg[0] + seg_length / 2.0), wall)
	_box(root, Vector3(WALL_THICKNESS, H - DOOR_HEIGHT, DOOR_WIDTH),
			Vector3(exit_x, DOOR_HEIGHT + (H - DOOR_HEIGHT) / 2.0, S / 2.0),
			wall)
	_box(root, Vector3(WALL_THICKNESS, H, S),
			Vector3(-exit_x, H / 2.0, S / 2.0), wall)
	_light(root, Vector3(0, H - 0.3, S / 2.0), theme)
	# There WAS a hazard stripe on the turn's inner wall here, purely to
	# say "the corridor bends".
	#
	# Owner ruling 2026-08-28 (art requirement 20): REMOVE IT. *A corridor
	# turns here* is not a hazard, and hazard orange stays reserved for
	# things that hurt you. The turn's own form does the work -- the
	# opening, the jamb reveal, the light above it -- and if playtesting
	# shows turns need more wayfinding it gets a non-hazard channel.
	# Step the cursor a full wall thickness past the exit wall's center
	# plane: the next chamber's own front wall then butts against this
	# one's outer face instead of occupying the same slab (coincident
	# faces z-fight, and only bent layouts can produce them).
	return {"root": root,
			"exit_offset": Vector3(
					exit_x + float(turn) * WALL_THICKNESS, 0, S / 2.0),
			"bounds": AABB(Vector3(-S / 2.0, -1, 0), Vector3(S, H + 1, S)),
			"turn": turn}

static func treasure_room(_chamber: Dictionary, theme: String) -> Dictionary:
	var side := 8.0
	var height := 4.5
	var root := Node3D.new()
	_box(root, Vector3(side, 0.5, side),
			Vector3(0, -0.25, side / 2.0), ThemeMaterials.floor_mat(theme))
	_perimeter(root, side, side, height, theme)
	_box(root, Vector3(side, WALL_THICKNESS, side),
			Vector3(0, height, side / 2.0), ThemeMaterials.trim_mat(theme))
	# The one warm room in the building.
	_light(root, Vector3(0, height - 0.6, side / 2.0), theme, 12.0)
	# Pedestal steps.
	_box(root, Vector3(3.0, 0.4, 3.0), Vector3(0, 0.2, side / 2.0),
			ThemeMaterials.accent_mat(theme))
	_box(root, Vector3(2.2, 0.4, 2.2), Vector3(0, 0.6, side / 2.0),
			ThemeMaterials.accent_mat(theme))
	return {"root": root, "exit_offset": Vector3(0, 0, side),
			"bounds": AABB(Vector3(-side / 2.0, -1, 0),
					Vector3(side, height + 1, side)),
			"enemy_spawns": [],
			"room_height": height,
			"reward_position": Vector3(0, 1.0, side / 2.0)}
