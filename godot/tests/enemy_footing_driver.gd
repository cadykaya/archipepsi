extends Node
## NO ENEMY LEAVES THE WORLD WITH NOBODY FIGHTING IT (`make godot-enemy-footing`).
##
## Found by H-MACHINE-LIFE's lifecycle run, where idle Zone visits
## recorded defeats nobody made:
## - **ML-F1:** 280 of the 768 enemies in the 23 fixture Zones below
##   spawned inside a solid: a warp station, a damageable crate, a cover
##   box, a reward pedestal, a shell's convex piece. The physics pushes each out on its first step,
##   and through a thin floor when down is nearest. The passing Zone's
##   `c023/scuttler#1` goes through its arena floor in 7 of 8 builds.
## - **ML-F2:** 57 patrollers have a lethal drop within
##   `ENEMY_PATROL_RADIUS`, and a patrol beat is picked at random. The
##   candidate's `c006/melee#0` walks off the transit hall's drop.
##
## Each fall is sent as `enemy_defeated`, which D-06 keeps and a
## `kill_all` counts: a room cleared with nobody in it.
##
## The cases judge by their own probes, not by `EnemyFooting`, so the
## rule is not graded by itself.

const ZONES := ["candidate_zone.json", "passing_zone.json", "played_zone.json"]
const SAMPLE_ZONES := 20
## The same margins the census used: a floor the feet rest on is not a
## solid they are inside.
const FOOT_MARGIN := 0.15
const SIDE_MARGIN := 0.05
const HEAD_MARGIN := 0.05
## Where the footing pass sets a ground enemy's feet: on its floor, a hair
## above it.
const FOOT_CLEARANCE := 0.02
const FLOOR_WITHIN := 3.0
## Idle builds per Zone, and how long each is watched.
const IDLE_BUILDS := 3
const IDLE_SECONDS := 4.0
## Patrol beats drawn per patroller.
const BEATS := 24
## A drop deeper than this between two samples is a ledge.
const LEDGE := 2.0

var checks := 0
var failures := 0


func _ready() -> void:
	_run()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("  ok: " + message)
	else:
		failures += 1
		print("FAIL: " + message)


func _run() -> void:
	await get_tree().process_frame
	await _every_enemy_stands()
	await _none_falls_idle()
	await _patrol_beats_keep_to_the_floor()
	await _an_idle_walk_stops_at_a_ledge()
	if failures == 0:
		print("GODOT ENEMY FOOTING OK (%d checks)" % checks)
	else:
		print("GODOT ENEMY FOOTING TESTS: %d failures in %d checks"
				% [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func _zone_files() -> Array[String]:
	var out: Array[String] = []
	for name: String in ZONES:
		out.append("res://tests/fixtures/" + name)
	for i in range(1, SAMPLE_ZONES + 1):
		out.append("res://tests/fixtures/sample/zone_%02d.json" % i)
	return out


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var zone: Dictionary = parsed
	if zone.has("zone") and not zone.has("chambers"):
		zone = zone["zone"]
	return zone


func _build(zone_data: Dictionary) -> ZoneController:
	var controller := ZoneController.new()
	get_tree().root.add_child(controller)
	controller.setup(zone_data)
	return controller


func _enemies_of(controller: ZoneController) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and controller.is_ancestor_of(node) \
				and not (node as Enemy)._dead:
			out.append(node)
	return out


## What a box of `envelope` with its feet at `at` overlaps: raised off the
## feet by `FOOT_MARGIN`, trimmed at the head and sides.
static func _box_hits(space: PhysicsDirectSpaceState3D, envelope: Dictionary,
		at: Vector3, own: Array[RID]) -> Array[Dictionary]:
	var size: Vector3 = envelope.get("size", Vector3.ONE)
	var box := BoxShape3D.new()
	box.size = Vector3(size.x - 2.0 * SIDE_MARGIN,
			size.y - FOOT_MARGIN - HEAD_MARGIN, size.z - 2.0 * SIDE_MARGIN)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(), at + Vector3.UP
			* (float(envelope.get("centre_y", 0.5))
				+ (FOOT_MARGIN - HEAD_MARGIN) / 2.0))
	query.exclude = own
	return space.intersect_shape(query, 8)


func _member(controller: ZoneController, member: String) -> Enemy:
	for foe: Enemy in _enemies_of(controller):
		if foe.member == member:
			return foe
	return null


static func _script_of(node: Node) -> String:
	if node == null:
		return "-"
	var script: Variant = node.get_script()
	return (script as Script).resource_path.get_file() if script != null \
			else node.get_class()


static func _own(node: Node, into: Array[RID]) -> void:
	if node is CollisionObject3D:
		into.append((node as CollisionObject3D).get_rid())
	for child: Node in node.get_children():
		_own(child, into)


# ---------------------------------------------------------------------------
# ML-F1: WHERE EACH ENEMY STANDS WHEN THE ZONE IS BUILT
# ---------------------------------------------------------------------------

func _every_enemy_stands() -> void:
	print("  -- EVERY ENEMY STANDS: clear of solids, over a floor")
	var total := 0
	var inside: Array[String] = []
	var unfloored: Array[String] = []
	var zones := 0
	var moved := 0
	var farthest := 0.0
	var needless: Array[String] = []
	for path: String in _zone_files():
		var zone_data := _load(path)
		if zone_data.is_empty():
			continue
		zones += 1
		var controller := _build(zone_data)
		await get_tree().physics_frame
		var space := controller.get_world_3d().direct_space_state
		for foe: Enemy in _enemies_of(controller):
			total += 1
			var own: Array[RID] = []
			_own(foe, own)
			var envelope: Dictionary = Constants.ENEMY_ENVELOPES.get(foe.archetype, {})
			for hit: Dictionary in _box_hits(space, envelope, foe.global_position, own):
				var who: Object = hit["collider"]
				if who is StaticBody3D or who is RigidBody3D:
					var body: Node = who
					inside.append("%s %s at %v, inside %s (%s under %s)%s" % [
							path.get_file(), foe.member,
							foe.global_position.snapped(Vector3(0.1, 0.1, 0.1)),
							body.name, _script_of(body), _script_of(body.get_parent()),
							(" -- the pass found nowhere: %s"
								% controller.enemy_footing_refusals[foe.member])
							if controller.get("enemy_footing_refusals") != null
								and (controller.enemy_footing_refusals as Dictionary)
									.has(foe.member) else ""])
					break
			if bool(envelope.get("flying", false)):
				continue
			var ray := PhysicsRayQueryParameters3D.create(
					foe.global_position + Vector3.UP * 0.5,
					foe.global_position + Vector3.DOWN * FLOOR_WITHIN)
			ray.exclude = own
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit["collider"] is CharacterBody3D:
				unfloored.append("%s %s at %v" % [path.get_file(), foe.member,
						foe.global_position.snapped(Vector3(0.1, 0.1, 0.1))])
		if controller.get("enemy_footing_moves") != null:
			moved += (controller.enemy_footing_moves as Dictionary).size()
			for member: Variant in controller.enemy_footing_moves:
				var move: Dictionary = controller.enemy_footing_moves[member]
				farthest = maxf(farthest, (move["from"] as Vector3)
						.distance_to(move["to"] as Vector3))
				# A MOVE THAT HAD A REASON: where it was placed, landed on
				# its floor, it stood inside something.
				var foe := _member(controller, str(member))
				if foe == null:
					continue
				var own: Array[RID] = []
				_own(foe, own)
				var from: Vector3 = move["from"]
				var under := _world_hit(space, from + Vector3.UP * 0.5,
						from + Vector3.DOWN * FLOOR_WITHIN, own)
				var landed := from if under.is_empty() \
						else Vector3(from.x, (under["position"] as Vector3).y
							+ FOOT_CLEARANCE, from.z)
				var envelope: Dictionary = Constants.ENEMY_ENVELOPES.get(
						foe.archetype, {})
				var stood_inside := false
				for hit: Dictionary in _box_hits(space, envelope, landed, own):
					if hit["collider"] is StaticBody3D or hit["collider"] is RigidBody3D:
						stood_inside = true
				if not stood_inside and not under.is_empty():
					needless.append("%s %s from %v (the pass said: %s)" % [
							path.get_file(), member,
							from.snapped(Vector3(0.1, 0.1, 0.1)), move["fault"]])
		controller.queue_free()
		for _i in 3:
			await get_tree().process_frame
	print("  the footing pass moved %d of %d enemies, the farthest %.1f m"
			% [moved, total, farthest])
	_check(total >= 700,
			"the census builds %d Zones and reads %d enemies" % [zones, total])
	_check(inside.is_empty(),
			"no enemy is built inside a solid (%d are): %s" % [inside.size(),
				"; ".join(inside.slice(0, 6))])
	_check(needless.is_empty(),
			"every enemy the pass moved stood inside something where it would "
			+ "have landed (%d did not): %s" % [needless.size(),
				"; ".join(needless.slice(0, 6))])
	_check(unfloored.is_empty(),
			"every ground enemy has floor within %.0f m under it (%d have none): %s"
			% [FLOOR_WITHIN, unfloored.size(), "; ".join(unfloored.slice(0, 6))])


# ---------------------------------------------------------------------------
# ML-F1 and ML-F2 in play: nobody near, nothing falls
# ---------------------------------------------------------------------------

func _none_falls_idle() -> void:
	print("  -- NONE FALLS IDLE: the player far away, every enemy at its job")
	for name: String in ["passing_zone.json", "candidate_zone.json"]:
		var zone_data := _load("res://tests/fixtures/" + name)
		var fallen: Array[String] = []
		var defeated := 0
		for build in IDLE_BUILDS:
			BridgeClient.sent_intents.clear()
			var controller := _build(zone_data)
			# Out of every enemy's notice and out of the physics: what the
			# enemies do now is their own job, and nothing else.
			var player := controller.player
			if is_instance_valid(player):
				player.global_position = Vector3(0.0, 5000.0, 0.0)
				player.process_mode = Node.PROCESS_MODE_DISABLED
			var starts := {}
			var frames := int(IDLE_SECONDS * 60.0)
			for frame in frames:
				await get_tree().physics_frame
				for foe: Enemy in _enemies_of(controller):
					if not starts.has(foe.member):
						starts[foe.member] = foe.global_position
					if foe.global_position.y < (starts[foe.member] as Vector3).y - 2.0 \
							and not fallen.has("%s build %d" % [foe.member, build]):
						fallen.append("%s build %d" % [foe.member, build])
			for intent: Dictionary in BridgeClient.sent_intents:
				if str(intent.get("type", "")) == "enemy_defeated":
					defeated += 1
					var who := "%s build %d (defeated)" % [intent.get("member", "?"), build]
					if not fallen.has(who):
						fallen.append(who)
			controller.queue_free()
			for _i in 3:
				await get_tree().process_frame
		_check(fallen.is_empty() and defeated == 0,
				"%s, %d builds of %.0f s with nobody near: no enemy drops 2 m, "
				% [name, IDLE_BUILDS, IDLE_SECONDS] + "no defeat is sent "
				+ "(%d drops, %d defeats): %s" % [fallen.size(), defeated,
					", ".join(fallen.slice(0, 6))])


# ---------------------------------------------------------------------------
# ML-F2: THE BEAT A PATROL PICKS
# ---------------------------------------------------------------------------

func _patrol_beats_keep_to_the_floor() -> void:
	print("  -- PATROL BEATS KEEP TO THE FLOOR: %d draws per patroller" % BEATS)
	for name: String in ["candidate_zone.json", "passing_zone.json"]:
		var controller := _build(_load("res://tests/fixtures/" + name))
		var player := controller.player
		if is_instance_valid(player):
			player.global_position = Vector3(0.0, 5000.0, 0.0)
			player.process_mode = Node.PROCESS_MODE_DISABLED
		# One frame, so every enemy has taken its post.
		for _i in 2:
			await get_tree().physics_frame
		var space := controller.get_world_3d().direct_space_state
		var drawn := 0
		var drawn_on := 0
		var over: Array[String] = []
		var patrollers := 0
		for foe: Enemy in _enemies_of(controller):
			if foe.job != "patrol":
				continue
			patrollers += 1
			var own: Array[RID] = []
			_own(foe, own)
			var keep_at := foe.global_position
			for k in BEATS:
				seed(1000 * k + patrollers)
				foe.global_position = keep_at
				foe._beat_set = false
				foe._pause = 0.0
				foe._patrol(0.0, 0.0)
				if not foe._beat_set:
					continue   # it chose to stand: no beat to judge
				drawn += 1
				var gap := _first_gap(space, foe.post, foe._beat, own)
				if gap >= 0.0:
					over.append("%s: beat %v leaves the floor %.2f m out"
							% [foe.member, foe._beat.snapped(Vector3(0.1, 0.1, 0.1)), gap])
			# AND FROM WHERE THE LAST BEAT LEFT IT: the next walk starts
			# there, not at the post, and must keep to the floor too.
			for k in BEATS:
				seed(7000 * k + patrollers)
				foe.global_position = keep_at
				foe._beat_set = false
				foe._pause = 0.0
				foe._patrol(0.0, 0.0)
				if not foe._beat_set:
					continue
				var standing := Vector3(foe._beat.x, keep_at.y, foe._beat.z)
				foe.global_position = standing
				seed(9000 * k + patrollers)
				foe._beat_set = false
				foe._pause = 0.0
				foe._patrol(0.0, 0.0)
				if not foe._beat_set:
					continue
				drawn_on += 1
				var gap_on := _first_gap(space, standing, foe._beat, own)
				if gap_on >= 0.0:
					over.append("%s: from %v, beat %v leaves the floor %.2f m out"
							% [foe.member, standing.snapped(Vector3(0.1, 0.1, 0.1)),
								foe._beat.snapped(Vector3(0.1, 0.1, 0.1)), gap_on])
			foe.global_position = keep_at
			foe.velocity = Vector3.ZERO
		print("    %d beats drawn from a previous beat" % drawn_on)
		_check(patrollers > 0 and drawn > 0 and drawn_on > 0,
				"%s: %d patrollers, %d beats drawn" % [name, patrollers, drawn])
		_check(over.is_empty(),
				"%s: every beat's path from the post keeps to the floor "
				% name + "(%d do not): %s" % [over.size(), "; ".join(over.slice(0, 5))])
		controller.queue_free()
		for _i in 3:
			await get_tree().process_frame


## The distance along post -> beat at which the floor first gives out, or
## -1. Sampled every 0.25 m: a floor more than `LEDGE` below the last
## sample, or none, is a ledge; a climb of more than 0.6 m is a wall.
## Stepping off the back of a cover wedge (1.2 m at most) is terrain, not
## a ledge, and the product's own rule is stricter than this one.
static func _first_gap(space: PhysicsDirectSpaceState3D, from: Vector3,
		to: Vector3, own: Array[RID]) -> float:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := flat.length()
	if length < 0.01:
		return -1.0
	var dir := flat / length
	var level := from.y
	var under := _world_hit(space, from + Vector3.UP * 0.5,
			from + Vector3.DOWN * 3.0, own)
	if not under.is_empty():
		level = (under["position"] as Vector3).y
	var gone := 0.25
	while gone <= length + 0.001:
		var at := from + dir * gone
		var hit := _world_hit(space, Vector3(at.x, level + 0.6, at.z),
				Vector3(at.x, level - LEDGE, at.z), own)
		if hit.is_empty():
			return gone
		level = (hit["position"] as Vector3).y
		gone += 0.25
	return -1.0


## The first hit that is the built world: characters are stepped past, as
## a probe of the floor must (every body is on one layer).
static func _world_hit(space: PhysicsDirectSpaceState3D, from: Vector3,
		to: Vector3, own: Array[RID]) -> Dictionary:
	var skip: Array[RID] = own.duplicate()
	for _tries in 8:
		var ray := PhysicsRayQueryParameters3D.create(from, to)
		ray.exclude = skip
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or not (hit["collider"] is CharacterBody3D):
			return hit
		skip.append(hit["rid"])
	return {}


# ---------------------------------------------------------------------------
# ML-F2's guard: an idle walk that meets a ledge
# ---------------------------------------------------------------------------

## A 6 m slab over nothing. A melee walks home to a post 5 m past its
## edge: nothing to fight, so this is a job walk, and it must stop at the
## edge rather than walk off. Standing there it takes up its post.
func _an_idle_walk_stops_at_a_ledge() -> void:
	print("  -- AN IDLE WALK STOPS AT A LEDGE")
	var stage := Node3D.new()
	stage.position = Vector3(0.0, 800.0, 0.0)
	get_tree().root.add_child(stage)
	var slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 0.5, 6.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.25, 0.0)
	slab.add_child(shape)
	stage.add_child(slab)
	var foe := Enemy.create("melee", "concrete_facility")
	stage.add_child(foe)
	foe.global_position = stage.global_position + Vector3(1.0, 0.05, 0.0)
	for _i in 3:
		await get_tree().physics_frame
	foe.post = stage.global_position + Vector3(8.0, 0.0, 0.0)
	foe.returning = true
	var lowest := foe.global_position.y
	var furthest := 0.0
	for _i in 240:
		await get_tree().physics_frame
		if not is_instance_valid(foe):
			break
		lowest = minf(lowest, foe.global_position.y)
		furthest = maxf(furthest, foe.global_position.x - stage.global_position.x)
	var stayed := is_instance_valid(foe) and lowest > stage.global_position.y - 0.5
	_check(stayed and furthest < 3.3,
			"walking home to a post past the edge, it stops on the slab: "
			+ "furthest %.2f m out (edge at 3.00), lowest %.2f m relative"
			% [furthest, lowest - stage.global_position.y])
	if is_instance_valid(foe):
		var post_out := foe.post.x - stage.global_position.x
		_check(not foe.returning and post_out < 3.0,
				"and takes up a post on the slab, not the one past the edge "
				+ "(returning %s, post %.2f m out)" % [foe.returning, post_out])
	stage.queue_free()
	for _i in 3:
		await get_tree().process_frame
