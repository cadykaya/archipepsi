class_name ImpactLabParts
extends RefCounted
## THE IMPACT LAB'S TWO NEW PIECES, for the G0 feasibility fixture only
## (`ImpactLab`, post-D playtest plan, Prod P0.2). Placeholder looks on
## purpose: the question here is whether the mechanism is TRUE, and the art
## is Arty's lane.
##
## **OBJECTS, NEVER THE PLAYER.** The game's `LaunchPad` and `BouncePad`
## launch only a `Player`, by solving and writing `Player.velocity`; that
## contract is untouched. `ObjectPlate` is a separate, narrow device: it
## never looks at a `Player`, and it moves a released `ManipulableBody`
## the way the rest of the game moves one -- `receive_impulse`, through the
## solver, so a `lightened` body flies twice as hard, as the contract says.
##
## **IMPACT IS MEASURED, NOT ANIMATED.** `ImpactShutter` takes damage from
## the kinetic energy a real body brings into it, read off the solver at
## the moment it arrives. Nothing breaks because an animation played.

const MOVEMENT := CrossingDParts.MOVEMENT
const POWER := CrossingDParts.POWER
const POWER_IDLE := CrossingDParts.POWER_IDLE
const DESTRUCTIBLE := CrossingDParts.DESTRUCTIBLE
const THEME := CrossingDParts.THEME


static func box(parent: Node3D, label: String, at: Vector3, size: Vector3,
		material: Material) -> MeshInstance3D:
	var made := MeshInstance3D.new()
	made.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	made.mesh = mesh
	made.position = at
	made.material_override = material
	parent.add_child(made)
	return made


## A POWERED OBJECT PLATE: a floor plate that, while powered, throws a
## released object resting on it along one fixed, solved arc.
##
## * It fires only at a body that has SETTLED on it -- not held, not
##   installed, not frozen, slow -- for `SETTLE_SECONDS`, so a dropped
##   object visibly arms the plate before anything happens.
## * Unpowered, the same settle gets a dud: the plate flickers and
##   `dud` fires, so the player learns it is the plate, without power.
## * The arc is solved once, from the plate's own centre, on the engine's
##   integrator (gravity, then linear damping, then position, per tick),
##   so a body at the centre arrives at `target` after `flight_seconds`.
##   It does not aim per object: an object set down off-centre flies the
##   same arc from where it sits, which is what a catapult does.
## * One firing per arrival: a body has to leave the plate before it can
##   be thrown again, and the plate re-arms after `REARM_SECONDS`.
class ObjectPlate extends Node3D:
	signal fired(body: ManipulableBody, velocity: Vector3)
	signal dud(body: ManipulableBody)
	signal armed(body: ManipulableBody)

	const SIZE := Vector3(2.0, 0.25, 2.0)
	const SETTLE_SECONDS := 0.6
	const REARM_SECONDS := 1.0
	## Slower than this, a body counts as resting on the plate.
	const REST_SPEED := 0.25

	var powered := false
	## The arc's end, in world space, and how long it takes to get there.
	var target := Vector3.ZERO
	var flight_seconds := 1.0
	var launches := 0
	var duds := 0

	var _sensor: Area3D
	var _inside: Array[ManipulableBody] = []
	var _settled := {}
	var _spent := {}
	var _rearm := 0.0
	var _chevrons: Array[MeshInstance3D] = []
	var _lamp: MeshInstance3D
	var _flash := 0.0

	func build(launch_direction: Vector3) -> void:
		var trim := ThemeMaterials.trim_mat(THEME)
		var top := SIZE.y
		# The plate itself: a solid you can stand on and set things down on.
		var slab := ChamberBuilders._box(self, SIZE,
				Vector3(0, top * 0.5, 0), trim)
		slab.name = "Slab"
		# BLUE ON THE MOVING PART, not over everything: three chevrons on
		# the deck pointing the way it throws, and a lip on its leading edge.
		var flat := Vector3(launch_direction.x, 0, launch_direction.z)
		var yaw := atan2(-flat.x, -flat.z) if flat.length() > 0.01 else 0.0
		var deck := Node3D.new()
		deck.name = "Deck"
		deck.rotation.y = yaw
		add_child(deck)
		for i in 3:
			var z := 0.45 - 0.45 * i
			for side in [-1.0, 1.0]:
				var arm := ImpactLabParts.box(deck, "Chevron", Vector3(side * 0.22, top + 0.012,
						z), Vector3(0.5, 0.02, 0.1), null)
				arm.rotation.y = side * 0.62
				_chevrons.append(arm)
		ImpactLabParts.box(deck, "Lip", Vector3(0, top * 0.5, -SIZE.z * 0.5 - 0.04),
				Vector3(SIZE.x, top, 0.08), ThemeMaterials.glow_material(
					MOVEMENT, 0.5))
		# GREEN WHERE THE POWER ARRIVES: a lamp on the west face, where the
		# raceway runs in.
		_lamp = ImpactLabParts.box(self, "PowerLamp", Vector3(-SIZE.x * 0.5 - 0.06, top * 0.5,
				0.6), Vector3(0.1, 0.14, 0.3), null)
		_sensor = Area3D.new()
		_sensor.name = "Sensor"
		var shape := CollisionShape3D.new()
		var sensor_box := BoxShape3D.new()
		sensor_box.size = Vector3(SIZE.x - 0.2, 0.9, SIZE.z - 0.2)
		shape.shape = sensor_box
		shape.position = Vector3(0, top + 0.45, 0)
		_sensor.add_child(shape)
		add_child(_sensor)
		_sensor.body_entered.connect(_on_entered)
		_sensor.body_exited.connect(_on_exited)
		_paint()

	## POWER ARRIVES: anything already resting here arms afresh, so the
	## weight can be set down first and the lever pulled after, or the
	## other way round.
	func set_powered(value: bool) -> void:
		if value and not powered:
			_spent.clear()
			for body in _settled.keys():
				_settled[body] = 0.0
		powered = value
		_paint()

	## The velocity a body resting at the plate's centre leaves with, to
	## reach `target` in `flight_seconds` on this engine's integrator,
	## flying as `Flight` lets it (no coasting damp in the air).
	func solve(_body: RigidBody3D) -> Vector3:
		var from := global_position + Vector3(0, SIZE.y, 0) \
				+ Vector3(0, half_height(_body), 0)
		return ImpactLabParts.arc(from, target, flight_seconds,
				Flight.AIR_DAMP)

	func half_height(body: RigidBody3D) -> float:
		var hull := body.get_node_or_null("hull") as CollisionShape3D
		if hull != null and hull.shape is BoxShape3D:
			return (hull.shape as BoxShape3D).size.y * 0.5
		return 0.3

	func _on_entered(node: Node3D) -> void:
		var body := node as ManipulableBody
		if body != null and not _inside.has(body):
			_inside.append(body)
			_settled[body] = 0.0

	func _on_exited(node: Node3D) -> void:
		var body := node as ManipulableBody
		if body != null:
			_inside.erase(body)
			_settled.erase(body)
			_spent.erase(body)

	func _physics_process(delta: float) -> void:
		_rearm = maxf(_rearm - delta, 0.0)
		_flash = maxf(_flash - delta, 0.0)
		var arming := 0.0
		for body: ManipulableBody in _inside.duplicate():
			if not is_instance_valid(body):
				_inside.erase(body)
				continue
			if not _resting(body) or _spent.has(body):
				_settled[body] = 0.0
				continue
			_settled[body] = float(_settled[body]) + delta
			var held_for: float = _settled[body]
			if not powered:
				if held_for >= SETTLE_SECONDS:
					_spent[body] = true
					duds += 1
					_flash = 0.35
					dud.emit(body)
				continue
			if held_for - delta <= 0.0:
				armed.emit(body)
			arming = maxf(arming, held_for / SETTLE_SECONDS)
			if held_for >= SETTLE_SECONDS and _rearm <= 0.0:
				_fire(body)
		_paint(arming)

	func _resting(body: ManipulableBody) -> bool:
		return body.carried_by == null and body.installed_in == null \
				and not body.freeze \
				and body.linear_velocity.length() < REST_SPEED

	func _fire(body: ManipulableBody) -> void:
		ImpactLabParts.Flight.begin(body, flight_seconds + 1.5, self)
		var velocity := solve(body)
		body.receive_impulse((velocity - body.linear_velocity) * body.mass)
		_spent[body] = true
		_rearm = REARM_SECONDS
		_flash = 0.25
		launches += 1
		fired.emit(body, velocity)

	## The plate shows its own state: dark chevrons unpowered (a flicker on
	## a dud), lit and filling as an object arms it, bright as it throws.
	func _paint(arming := 0.0) -> void:
		var lit := 0.12
		var tint := MOVEMENT.darkened(0.55)
		if powered:
			tint = MOVEMENT
			lit = 0.35 + 1.6 * arming + (2.5 if _flash > 0.0 else 0.0)
		elif _flash > 0.0:
			lit = 0.6 if int(_flash * 20.0) % 2 == 0 else 0.05
		var chevron := ThemeMaterials.glow_material(tint, lit)
		for mesh in _chevrons:
			mesh.material_override = chevron
		if _lamp != null:
			_lamp.material_override = ThemeMaterials.glow_material(
					POWER if powered else POWER_IDLE, 0.7 if powered else 0.06)


## THE ARC, ON THIS ENGINE'S INTEGRATOR. Godot's own physics steps a rigid
## body as: velocity += gravity·dt; velocity *= (1 − damp·dt); position +=
## velocity·dt. Position after N ticks is therefore linear in the launch
## velocity, so the launch is solved exactly, per axis, rather than with
## a textbook parabola that ignores the body's damping.
static func arc(from: Vector3, to: Vector3, seconds: float,
		damp: float) -> Vector3:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var ticks := maxi(1, roundi(seconds / dt))
	var keep := maxf(1.0 - damp * dt, 0.0)
	var gravity := Vector3.DOWN * ManipulableBody.gravity()
	var per_unit := 0.0
	var drift := Vector3.ZERO
	var unit := 1.0
	var fall := Vector3.ZERO
	for _i in ticks:
		unit *= keep
		fall = (fall + gravity * dt) * keep
		per_unit += unit * dt
		drift += fall * dt
	return (to - from - drift) / per_unit


## The damping a body actually flies under: its own, plus the project's
## default when it combines (the `ManipulableBody` default).
static func total_damp(body: RigidBody3D) -> float:
	var own := body.linear_damp
	if body.linear_damp_mode == RigidBody3D.DAMP_MODE_COMBINE:
		own += float(ProjectSettings.get_setting(
				"physics/3d/default_linear_damp", 0.1))
	return own


## IN THE AIR, NOT ON THE FLOOR. `ManipulableBody` damps every body at
## 1.2/s (plus the project's 0.1) so a pushed crate "coasts to a stop
## rather than sliding for twenty metres": a stand-in for floor friction.
## Left on in flight it brakes a thrown 36 kg weight to half its speed in
## half a second, an arc that reads as syrup and lands with a third of its
## energy. So for its flight only, the body flies on `AIR_DAMP`; its own
## damping (and its CCD and contact settings) come back at its first
## contact with anything, when a hand takes it, or after `limit` seconds,
## whichever is first. Nothing else about the body changes.
class Flight extends Node:
	const AIR_DAMP := 0.0

	var body: RigidBody3D
	var limit := 3.0
	## What threw it: scraping its own launcher on the way off is not
	## the flight ending.
	var launcher: Node = null
	var _damp := 0.0
	var _mode := RigidBody3D.DAMP_MODE_COMBINE
	var _ccd := false
	var _monitor := false
	var _reported := 0
	var _age := 0.0

	static func begin(target: RigidBody3D, seconds: float,
			from: Node = null) -> void:
		var old := target.get_node_or_null("Flight")
		if old != null:
			(old as Flight).end()
		var made := Flight.new()
		made.name = "Flight"
		made.body = target
		made.limit = seconds
		made.launcher = from
		made._damp = target.linear_damp
		made._mode = target.linear_damp_mode
		made._ccd = target.continuous_cd
		made._monitor = target.contact_monitor
		made._reported = target.max_contacts_reported
		target.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		target.linear_damp = AIR_DAMP
		target.continuous_cd = true
		target.contact_monitor = true
		target.max_contacts_reported = maxi(target.max_contacts_reported, 1)
		target.add_child(made)

	func _physics_process(delta: float) -> void:
		_age += delta
		if not is_instance_valid(body):
			queue_free()
			return
		var held := body is ManipulableBody \
				and (body as ManipulableBody).carried_by != null
		if held or _age > limit or _struck():
			end()

	## Touching anything but its own launcher.
	func _struck() -> bool:
		for other in body.get_colliding_bodies():
			if launcher == null or not launcher.is_ancestor_of(other):
				return true
		return false

	func end() -> void:
		if is_instance_valid(body):
			body.linear_damp_mode = _mode
			body.linear_damp = _damp
			body.continuous_cd = _ccd
			body.contact_monitor = _monitor
			body.max_contacts_reported = _reported
		body = null
		if is_inside_tree():
			get_parent().remove_child(self)
		queue_free()


## A RATED IMPACT SHUTTER: an orange-banded steel shutter in a doorway,
## built to stop a pulse and give to a real impact.
##
## The rating is the game's own rule for a breakable panel (§13.1,
## `AffordanceNodes.BreakablePanel`): per hit, a blow under twice the
## Static Pulse's damage does nothing, and says so. Here a blow is either a
## damage call (a shot) or a body arriving: ½·m·v² of what it brings INTO
## the shutter (the speed along the shutter's normal), at `JOULES_PER_HP`.
## So a 36 kg weight at 11 m/s is ~2,200 J -- ~87 HP -- and breaks it; the
## same weight dropped from the hands brings a few hundred and does not.
class ImpactShutter extends StaticBody3D:
	signal broken(at: Vector3)
	signal struck(amount: float, accepted: bool, body: Node3D)

	const HP := 40.0
	const MIN_HIT := Constants.STATIC_PULSE_DAMAGE * 2.0
	const JOULES_PER_HP := 25.0
	const MARGIN := 0.12

	var size := Vector3(3.0, 3.0, 0.4)
	## Which way the shutter's face looks (world), for "into it".
	var normal := Vector3.BACK
	var hp := HP
	var refused := 0
	var last_impact := {}

	var _seams: Array[MeshInstance3D] = []
	var _cooldown := {}
	## Bodies coming at the face, and their velocity as of the tick before:
	## the speed a body HAD, before the contact that stops it.
	var _approaching := {}

	func build() -> void:
		add_to_group(Damageable.GROUP)
		var shape := CollisionShape3D.new()
		var collider := BoxShape3D.new()
		collider.size = size
		shape.shape = collider
		add_child(shape)
		var steel := ThemeMaterials.trim_mat(THEME)
		ImpactLabParts.box(self, "Casing", Vector3.ZERO, size, steel)
		# ORANGE ON WHAT GIVES: banding round the edge and two seams across
		# the face, on both faces, not an orange box.
		var band := ThemeMaterials.glow_material(DESTRUCTIBLE, 0.35)
		for face in [-1.0, 1.0]:
			var z: float = face * (size.z * 0.5 + 0.01)
			for y in [-size.y * 0.5 + 0.12, size.y * 0.5 - 0.12]:
				ImpactLabParts.box(self, "Band", Vector3(0, y, z),
						Vector3(size.x, 0.2, 0.02), band)
			for i in 2:
				var seam := ImpactLabParts.box(self, "Seam",
						Vector3(0, -0.45 + 0.9 * i, z),
						Vector3(size.x * 0.8, 0.07, 0.025), null)
				seam.rotation.z = 0.35 * (1.0 if i == 0 else -1.0)
				_seams.append(seam)
		var sensor := Area3D.new()
		sensor.name = "ImpactSensor"
		var sensor_shape := CollisionShape3D.new()
		var sensor_box := BoxShape3D.new()
		sensor_box.size = size + Vector3(0.2, 0.2, MARGIN * 2.0)
		sensor_shape.shape = sensor_box
		sensor.add_child(sensor_shape)
		add_child(sensor)
		sensor.body_entered.connect(_on_body_entered)
		# THE APPROACH: two metres in front of the face. The thin sensor
		# alone could not measure an impact: at 11 m/s a body moves 0.18 m
		# a tick, so on some ticks the solver has already stopped it at the
		# face by the time the overlap is reported, and the "impact" read
		# 0.9 m/s. Velocities recorded here, before each tick's step, are
		# what the body brought.
		var approach := Area3D.new()
		approach.name = "Approach"
		var approach_shape := CollisionShape3D.new()
		var approach_box := BoxShape3D.new()
		approach_box.size = Vector3(size.x + 0.6, size.y + 0.6, 2.0)
		approach_shape.shape = approach_box
		approach_shape.position = normal * (size.z * 0.5 + 1.0)
		approach.add_child(approach_shape)
		add_child(approach)
		approach.body_entered.connect(func(node: Node3D) -> void:
			if node is ManipulableBody:
				_approaching[node] = [(node as RigidBody3D).linear_velocity])
		approach.body_exited.connect(func(node: Node3D) -> void:
			_approaching.erase(node))
		_paint()

	func _physics_process(delta: float) -> void:
		# The last three ticks: the overlap that reports the blow can arrive
		# a tick after the tick that took the speed off.
		for node in _approaching.keys():
			if is_instance_valid(node):
				var seen: Array = _approaching[node]
				seen.push_front((node as RigidBody3D).linear_velocity)
				if seen.size() > 3:
					seen.pop_back()
			else:
				_approaching.erase(node)
		for key in _cooldown.keys():
			_cooldown[key] = float(_cooldown[key]) - delta
			if float(_cooldown[key]) <= 0.0:
				_cooldown.erase(key)

	## A BODY ARRIVES: the energy it brings into the face, as damage. A
	## carried object never counts -- the hands move it, not momentum.
	func _on_body_entered(node: Node3D) -> void:
		var body := node as ManipulableBody
		if body == null or body.carried_by != null or _cooldown.has(body):
			return
		_cooldown[body] = 0.5
		var into := absf(body.linear_velocity.dot(normal))
		for seen: Vector3 in _approaching.get(body, []):
			into = maxf(into, absf(seen.dot(normal)))
		var joules := 0.5 * body.mass * into * into
		last_impact = {"speed": maxf(body.linear_velocity.length(), into), "into": into,
				"joules": joules, "at": body.global_position}
		take_damage(joules / JOULES_PER_HP, -normal, 0.0, body)

	## `Enemy`'s signature, so the Pulse reaches it like anything else.
	func take_damage(amount: float, _direction: Vector3 = Vector3.ZERO,
			_knockback: float = 0.0, source: Node3D = null) -> bool:
		if hp <= 0.0:
			return false
		if amount < MIN_HIT:
			refused += 1
			struck.emit(amount, false, source)
			_paint(0.6)
			return false
		hp -= amount
		struck.emit(amount, true, source)
		if hp > 0.0:
			_paint()
			return false
		broken.emit(global_position)
		_debris()
		queue_free()
		return true

	func apply_knockback(_impulse: Vector3) -> void:
		pass

	## The seams say how close it is: dim, brighter as it weakens, and a
	## flash on a blow too light to count.
	func _paint(flash := 0.0) -> void:
		var wear := 1.0 - clampf(hp / HP, 0.0, 1.0)
		var seam := ThemeMaterials.glow_material(DESTRUCTIBLE,
				0.4 + 2.0 * wear + flash)
		for mesh in _seams:
			mesh.material_override = seam

	## What is left, falling: a few slabs that collide with the world and
	## nothing else (so they never block the doorway they opened), gone
	## after a few seconds.
	func _debris() -> void:
		var parent := get_parent() as Node3D
		if parent == null:
			return
		var steel := ThemeMaterials.trim_mat(THEME)
		for i in 6:
			var chunk := RigidBody3D.new()
			chunk.name = "Debris"
			chunk.collision_layer = 0
			chunk.collision_mask = 1
			chunk.mass = 20.0
			var shape := CollisionShape3D.new()
			var chunk_box := BoxShape3D.new()
			chunk_box.size = Vector3(0.9, 0.7, 0.18)
			shape.shape = chunk_box
			chunk.add_child(shape)
			ImpactLabParts.box(chunk, "Slab", Vector3.ZERO, chunk_box.size,
					steel if i % 2 == 0 else ThemeMaterials.glow_material(
						DESTRUCTIBLE, 0.3))
			parent.add_child(chunk)
			chunk.global_position = global_position + Vector3(
					(float(i % 3) - 1.0) * 0.9, floorf(i / 3.0) * 0.9 - 0.4, 0)
			chunk.linear_velocity = -normal * 3.0 + Vector3(
					(float(i % 3) - 1.0) * 1.2, 1.5, 0)
			chunk.angular_velocity = Vector3(1.5, 0.7 * i, 0.4)
			var timer := chunk.get_tree().create_timer(4.0)
			timer.timeout.connect(chunk.queue_free)
