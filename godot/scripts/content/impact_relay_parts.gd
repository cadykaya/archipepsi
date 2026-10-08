class_name ImpactRelayParts
extends RefCounted
## THE IMPACT RELAY'S OWN PIECES (G1, D-18 v2). The mechanism is the G0
## lab's (`ImpactLabParts`: the plate, the flight and the shutter,
## unchanged) and the Crossing kit's (`CrossingDParts`: the lever, the
## raceway, the stand-ins). What is here is a door, and the fitting of
## Arty's CANDIDATE art onto those G0 pieces (Batch 065, and two Batch 043
## physics props for the tote and the weight; `tools/impact_relay/
## import_kit.sh`). The art only shows state: every state it shows is read
## off the G0 piece it is fitted to, and nothing here changes a collider,
## an impulse or a rating. When the candidate files are absent the room
## falls back to the G0 placeholder looks.

const L := preload("res://scripts/content/impact_lab_parts.gd")
const P := preload("res://scripts/content/crossing_d_parts.gd")
const KIT := "res://candidate/impact_relay/%s.glb"


## One candidate piece, as its own scene, or null when it is not there.
static func kit(piece: String) -> Node3D:
	var path := KIT % piece
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


## A glowing material of `tint`: the kit's state colours are flat emitters.
static func glow(tint: Color, energy: float) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = tint
	made.emission_enabled = true
	made.emission = tint
	made.emission_energy_multiplier = energy
	return made


## THE OBJECT LAUNCHER (Batch 065 `ir_object_launcher`), worn by a G0
## `ObjectPlate`. A child of the plate at identity (the plate throws along
## its -Z here, as the kit is built). The plate's own code boxes -- slab
## look, chevrons, lip, lamp -- are hidden; its collider (the slab's body)
## and its sensor stay exactly as G0 built them.
##
## **The funnel stays off.** The GLB carries convex colliders on the side
## lips and the rear housing ("-convcolonly"), which the importer turns into
## live bodies. They would change what happens to an object set down near
## an edge, so they are removed here unless `funnel` is set -- a physics
## change that has to be measured on its own before it is switched on.
##
## **States, read off the plate** (the manifest's table, Prod's names):
## dark (unpowered: rails, chevrons and power lens idle); cocked (powered:
## rails live, lens lit); arming (the 0.6 s ramp: rails pulse faster, the
## chevrons light 1, 2, 3 back to front at 1/3, 2/3, 3/3); fired (a 0.12 s
## flash, and the deck kicks 10 degrees in 0.06 s and back in 0.25 s, only
## on the plate's `fired`); re-arm (the chevrons fade over the plate's own
## re-arm time); dud (one dim flicker of the rails; the lens stays idle,
## which is the reason).
class LauncherArt extends Node3D:
	const IDLE := Color("1b2d66")
	const LIVE := Color("3266ee")
	const KICK_DEGREES := 10.0
	const KICK_UP := 0.06
	const KICK_DOWN := 0.25
	const FLASH := 0.12
	const DUD := 0.35

	var plate: L.ObjectPlate
	var model: Node3D
	var funnel := false
	## What it shows now, for the checks: dark, cocked, arming, fired,
	## re_arm, dud.
	var state := "dark"
	var arming := 0.0
	var chevrons_lit := 0
	var kicks := 0
	var _rails: Array[MeshInstance3D] = []
	var _chevrons: Array[MeshInstance3D] = []
	var _power: Array[MeshInstance3D] = []
	var _hinge: Node3D
	var _rail_mat: StandardMaterial3D
	var _chevron_mats: Array[StandardMaterial3D] = []
	var _since_fired := INF
	var _dud_left := 0.0
	var _clock := 0.0

	static func fit(on: L.ObjectPlate, with_funnel := false) -> LauncherArt:
		var piece := ImpactRelayParts.kit("ir_object_launcher")
		if piece == null:
			return null
		var made := LauncherArt.new()
		made.name = "LauncherArt"
		made.plate = on
		made.funnel = with_funnel
		made.model = piece
		on.add_child(made)
		made.add_child(piece)
		made._wire()
		return made

	func _wire() -> void:
		for label in ["Slab", "Deck", "PowerLamp"]:
			var placeholder := plate.get_node_or_null(label) as Node3D
			if placeholder != null:
				placeholder.visible = false
		if not funnel:
			for body in model.find_children("*", "StaticBody3D", true, false):
				body.get_parent().remove_child(body)
				body.queue_free()
		for node in model.find_children("move_rail_*", "MeshInstance3D", true, false):
			_rails.append(node as MeshInstance3D)
		for i in 3:
			_chevrons.append(model.find_child("move_chevron_%d" % (i + 1), true,
					false) as MeshInstance3D)
		for node in P.kit_power_nodes(model):
			_power.append(node as MeshInstance3D)
		_hinge = model.find_child("deck_hinge", true, false) as Node3D
		_rail_mat = ImpactRelayParts.glow(IDLE, 0.2)
		for mesh in _rails:
			mesh.material_override = _rail_mat
		for mesh in _chevrons:
			var mat := ImpactRelayParts.glow(IDLE, 0.2)
			_chevron_mats.append(mat)
			mesh.material_override = mat
		plate.fired.connect(func(_b: ManipulableBody, _v: Vector3) -> void:
			_since_fired = 0.0
			kicks += 1)
		plate.dud.connect(func(_b: ManipulableBody) -> void:
			_dud_left = DUD)
		_paint()

	## Colliders the fitted model brought with it (none unless `funnel`).
	func colliders() -> int:
		return model.find_children("*", "StaticBody3D", true, false).size()

	func _physics_process(delta: float) -> void:
		_clock += delta
		_since_fired += delta
		_dud_left = maxf(_dud_left - delta, 0.0)
		_paint()

	## How far through its arming the plate is: what G0's own `_paint`
	## reads, from the same fields, for the body nearest to throwing.
	func _arming() -> float:
		if not plate.powered:
			return 0.0
		var most := 0.0
		for body in plate._inside:
			if is_instance_valid(body) and not plate._spent.has(body) \
					and plate._settled.has(body):
				most = maxf(most, float(plate._settled[body])
						/ L.ObjectPlate.SETTLE_SECONDS)
		return clampf(most, 0.0, 1.0)

	func _paint() -> void:
		arming = _arming()
		var rail_tint := IDLE
		var rail := 0.2
		var lit := 0
		var chevron := 0.2
		var fade := 0.0
		if not plate.powered:
			state = "dud" if _dud_left > 0.0 else "dark"
			if _dud_left > 0.0:
				rail = 0.6 if int(_dud_left * 20.0) % 2 == 0 else 0.05
		elif _since_fired < FLASH:
			state = "fired"
			rail_tint = LIVE
			rail = 2.5
			lit = 3
			chevron = 2.5
		elif arming > 0.0:
			state = "arming"
			rail_tint = LIVE
			var rate := lerpf(2.0, 10.0, arming)
			rail = 0.9 + 0.7 * (0.5 + 0.5 * sin(_clock * TAU * rate))
			lit = int(floor(arming * 3.0 + 0.0001))
			chevron = 1.6
		elif plate._rearm > 0.0:
			state = "re_arm"
			rail_tint = LIVE
			rail = 0.9
			fade = clampf(plate._rearm / L.ObjectPlate.REARM_SECONDS, 0.0, 1.0)
		else:
			state = "cocked"
			rail_tint = LIVE
			rail = 0.9
		chevrons_lit = lit
		_rail_mat.albedo_color = rail_tint
		_rail_mat.emission = rail_tint
		_rail_mat.emission_energy_multiplier = rail
		for i in _chevron_mats.size():
			var mat := _chevron_mats[i]
			var on := i < lit
			var energy := chevron if on else 0.2
			var tint := LIVE if (on or fade > 0.0) else IDLE
			if fade > 0.0 and not on:
				energy = 0.2 + 1.4 * fade
			mat.albedo_color = tint
			mat.emission = tint
			mat.emission_energy_multiplier = energy
		for node in _power:
			P.kit_power(node, plate.powered)
		if _hinge != null:
			var angle := 0.0
			if _since_fired < KICK_UP:
				angle = KICK_DEGREES * _since_fired / KICK_UP
			elif _since_fired < KICK_UP + KICK_DOWN:
				angle = KICK_DEGREES * (1.0 - (_since_fired - KICK_UP) / KICK_DOWN)
			_hinge.rotation.x = deg_to_rad(angle)


## THE IMPACT SEAL (Batch 065 `ir_impact_seal`) on a G0 `ImpactShutter`.
## Everything the shutter decides is G0's -- its collider, its sensors, the
## rating, the HP, the blow -- and it is this subclass only so that its two
## LOOK hooks show the kit: `_paint` (wear and the refused flash) and
## `_debris` (what is left when it breaks). Without the candidate file it is
## exactly G0's shutter.
##
## * **Wear:** the orange seam collars brighten as hp falls, held at 0.7 to
##   0.9 emission so a damaged seal stays orange (G0's 0.4 + 2.0 x wear
##   reaches 2.4 and washes orange out to yellow, which reads as hazard).
## * **Refused:** the collars flicker for 0.25 s -- dimming, never brighter
##   than 0.9. A refused BODY (the crate) is a glance: the next scuff shows
##   too, and the flicker is 0.15 s. "Not enough", not "immune".
## * **Broken:** the six slabs fall as six bodies (60 kg each, colliding
##   with the world only, as G0's debris), from where each was; the core
##   goes with the shutter. The jamb is on the wall, not here: it stays.
class RelayShutter extends L.ImpactShutter:
	const WEAR_FROM := 0.7
	const WEAR_TO := 0.9
	const REFUSED_FLASH := 0.25
	const GLANCE_FLASH := 0.15
	const SLAB_KG := 60.0

	var art: Node3D
	var glances := 0
	var scuffs_shown := 0
	## The collars' emission right now, and the highest it has been.
	var collar_energy := 0.0
	var collar_peak := 0.0
	var _collar: StandardMaterial3D
	var _scuffs: Array[MeshInstance3D] = []
	var _flash_left := 0.0

	func build() -> void:
		art = ImpactRelayParts.kit("ir_impact_seal")
		super.build()
		if art == null:
			return
		art.name = "SealArt"
		add_child(art)
		# G0's looks are the shutter's own direct meshes (its casing, bands
		# and seams); its collider and sensors are not meshes and stay.
		for child in get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = false
		for i in 3:
			var scuff := art.find_child("scuff_%d" % (i + 1), true, false) as MeshInstance3D
			if scuff != null:
				scuff.visible = false
				_scuffs.append(scuff)
		for slab in art.find_children("slab_*_mesh", "MeshInstance3D", true, false):
			var mesh := (slab as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s)
				if mat != null and mat.resource_name == "ca_orange":
					if _collar == null:
						_collar = (mat as StandardMaterial3D).duplicate()
						_collar.emission_enabled = true
						_collar.emission = CrossingDParts.DESTRUCTIBLE
					(slab as MeshInstance3D).set_surface_override_material(s, _collar)
		struck.connect(_on_struck)
		_paint()

	func _on_struck(_amount: float, accepted: bool, source: Node3D) -> void:
		if accepted:
			return
		if source != null:
			glances += 1
			if scuffs_shown < _scuffs.size():
				_scuffs[scuffs_shown].visible = true
				scuffs_shown += 1
			_flash_left = GLANCE_FLASH
		else:
			_flash_left = REFUSED_FLASH

	## G0's own hook, called by G0's `take_damage` on every blow.
	func _paint(flash := 0.0) -> void:
		super._paint(flash)
		_show_collars()

	func _process(delta: float) -> void:
		if _flash_left > 0.0:
			_flash_left = maxf(_flash_left - delta, 0.0)
			_show_collars()

	func _show_collars() -> void:
		if _collar == null:
			return
		var wear := 1.0 - clampf(hp / HP, 0.0, 1.0)
		var energy := lerpf(WEAR_FROM, WEAR_TO, wear)
		if _flash_left > 0.0 and int(_flash_left * 30.0) % 2 == 0:
			energy = 0.25
		_collar.emission_energy_multiplier = energy
		collar_energy = energy
		collar_peak = maxf(collar_peak, energy)

	## G0's own hook, called once as it breaks.
	func _debris() -> void:
		var parent := get_parent() as Node3D
		if art == null or parent == null:
			super._debris()
			return
		var across := global_basis.x
		var n := 0
		for slab in art.find_children("slab_?", "Node3D", true, false):
			var mesh := slab.get_child(0) as MeshInstance3D
			var at := (slab as Node3D).global_transform
			var body := RigidBody3D.new()
			body.name = "SealSlab"
			body.set_meta("seal_slab", true)
			body.collision_layer = 0
			body.collision_mask = 1
			body.mass = SLAB_KG
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.96, 1.47, 0.354)
			shape.shape = box
			body.add_child(shape)
			parent.add_child(body)
			body.global_transform = at
			mesh.reparent(body, true)
			var side := signf(to_local(at.origin).x)
			body.linear_velocity = -normal * 3.0 + across * side * 1.2 \
					+ Vector3.UP * (1.5 if to_local(at.origin).y > 0.0 else 0.6)
			body.angular_velocity = Vector3(1.2 * side, 0.4 * n, 0.3)
			body.get_tree().create_timer(6.0).timeout.connect(body.queue_free)
			n += 1


## A PLAIN DOOR that slides up into its head when told to, and stays open.
class SlideDoor extends StaticBody3D:
	signal opened

	var size := Vector3(2.0, 3.0, 0.3)
	var is_open := false
	var _rise := 0.0
	var _home := Vector3.ZERO

	func build(material: Material, trim: Material) -> void:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		add_child(shape)
		L.box(self, "Leaf", Vector3.ZERO, size, material)
		for y in [-size.y * 0.3, size.y * 0.3]:
			L.box(self, "Rib", Vector3(0, y, 0), Vector3(size.x - 0.2, 0.12,
					size.z + 0.04), trim)
		_home = position

	func open() -> void:
		if is_open:
			return
		is_open = true
		_home = position
		opened.emit()

	func _physics_process(delta: float) -> void:
		if not is_open or _rise >= size.y - 0.05:
			return
		_rise = minf(_rise + delta * 2.5, size.y - 0.05)
		position = _home + Vector3.UP * _rise
