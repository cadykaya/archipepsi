class_name CrossingDParts
extends RefCounted
## CROSSING D'S SMALL PARTS, for the review build only (`CrossingD`).
##
## **Ported from Wisp's exploration studies after review, not copied.**
## The lean source (revision 33cc9385, baseline e0421aaa) changes nothing
## outside its own folder but `project.godot` and its export presets, so
## nothing here replaces a production file. What came across, and what
## was changed on the way:
##
## - **The palette** (`interaction_palette.gd`): the handoff's locked
##   vocabulary -- blue for movement, green for power, orange only for
##   what breaks, enemies included, yellow and black for hazards. Applied
##   to THIS build's pieces only; no shared material or constant changes
##   (Arty's colour note: no global palette conversion).
## - **The power lines** (`mounted_conduit.gd`): surface-mounted runs,
##   one axis per run, lit only while their source is live.
## - **The mounted lever** (`mounted_lever.gd`): pedestal, foot, ON/OFF
##   marks and a pilot light. The study set `locked = true` by hand;
##   here `lock(note)` is the one way to latch it, and it leaves the
##   handle's pose to `advance`, because this lever throws about Z where
##   `CallLever` throws about X.
##
## What is NOT here: the studies' offline bridge (this build uses the
## concourse playtest's guard, before any connection exists), their
## identity props and stair models (Arty's lane: the bounded visual kit),
## and their audio.

const MOVEMENT := Color("3266ee")
const POWER := Color("55e078")
const POWER_IDLE := Color("347b46")
const DESTRUCTIBLE := Color("f48a36")
const NEUTRAL := Color("d1d5d2")
const HAZARD_WARNING := Color("f4cf46")
const HAZARD_DARK := Color("20251f")
const THEME := "concrete_facility"

## Conduit geometry, from the study: a 6 cm run on a 12 cm standoff.
const CONDUIT_RADIUS := 0.06
const CONDUIT_STANDOFF := 0.12


static func strip(parent: Node3D, name_in: String, at: Vector3,
		size: Vector3, tint: Color, energy := 0.5) -> MeshInstance3D:
	var made := MeshInstance3D.new()
	made.name = name_in
	var mesh := BoxMesh.new()
	mesh.size = size
	made.mesh = mesh
	made.position = at
	made.material_override = ThemeMaterials.glow_material(tint, energy)
	parent.add_child(made)
	return made


## A small lamp and a word: POWER / ON or POWER / OFF. State, not
## decoration -- `set_power` is the only writer.
static func power_badge(parent: Node3D, at: Vector3, on := false,
		words := "POWER") -> Node3D:
	var badge := Node3D.new()
	badge.name = "PowerBadge"
	badge.position = at
	badge.set_meta("words", words)
	parent.add_child(badge)
	strip(badge, "Lamp", Vector3.ZERO, Vector3(0.32, 0.16, 0.12),
			POWER_IDLE, 0.15)
	var label := Label3D.new()
	label.name = "State"
	label.position = Vector3(0, 0.3, 0)
	label.font_size = 20
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	badge.add_child(label)
	badge.set_meta("powered", not on)
	set_power(badge, on)
	return badge


static func set_power(badge: Node3D, on: bool, words := "") -> void:
	if words != "":
		badge.set_meta("words", words)
	var text := "%s / %s" % [str(badge.get_meta("words", "POWER")),
			"ON" if on else "OFF"]
	var label: Label3D = badge.get_node("State")
	if badge.get_meta("powered", null) == on and label.text == text:
		return
	badge.set_meta("powered", on)
	var lamp: MeshInstance3D = badge.get_node("Lamp")
	lamp.material_override = ThemeMaterials.glow_material(
			POWER if on else POWER_IDLE, 0.7 if on else 0.08)
	label.text = text
	label.modulate = POWER if on else NEUTRAL


## Keep blue and green recognisable rather than clipping to cyan/white.
static func cap_emission(node: Node, maximum := 0.5) -> void:
	if node is MeshInstance3D:
		var material := (node as MeshInstance3D).material_override \
				as StandardMaterial3D
		if material != null and material.emission_enabled:
			material.emission_energy_multiplier = minf(
					material.emission_energy_multiplier, maximum)
	for child in node.get_children():
		cap_emission(child, maximum)


## THIS BUILD'S COLOUR ON A PRODUCTION PIECE. The approved affordance art
## (batch 009) carries signal teal in its own emitter, and the rail sweeps
## `Constants.AFFORDANCE_SIGNAL`; the locked vocabulary wants blue. Every
## emitting surface under `node` takes `tint`, on this instance only: a
## duplicate per surface, never the shared resource.
static func retint(node: Node, tint: Color, energy := 0.6) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var override := mesh_node.material_override as StandardMaterial3D
		if override != null:
			if override.emission_enabled:
				mesh_node.material_override = ThemeMaterials.glow_material(
						tint, energy)
		elif mesh_node.mesh != null:
			for i in mesh_node.mesh.get_surface_count():
				var source := mesh_node.get_active_material(i) \
						as StandardMaterial3D
				if source == null or not source.emission_enabled:
					continue
				var own := source.duplicate() as StandardMaterial3D
				own.emission = tint
				own.emission_energy_multiplier = energy
				own.albedo_color = tint.darkened(0.35)
				mesh_node.set_surface_override_material(i, own)
	for child in node.get_children():
		retint(child, tint, energy)


## A SURFACE-MOUNTED POWER LINE: axis-aligned runs between `points`, each
## carried `CONDUIT_STANDOFF` off the surface named by its normal (ZERO
## for a short protected lead into a housing). Visual only; the state it
## shows belongs to whatever drives `conduit_power`.
static func conduit(parent: Node3D, id: String, points: Array,
		normals: Array) -> Node3D:
	assert(normals.size() == points.size() - 1)
	var root := Node3D.new()
	root.name = "Conduit_" + id
	root.set_meta("path", points.duplicate())
	parent.add_child(root)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var delta := b - a
		var axes := int(absf(delta.x) > 0.001) + int(absf(delta.y) > 0.001) \
				+ int(absf(delta.z) > 0.001)
		assert(axes == 1, "a power run keeps to one axis")
		var axis := delta.normalized()
		var length := delta.length()
		var centre := (a + b) * 0.5
		var line := MeshInstance3D.new()
		line.name = "PowerRun_%d" % i
		line.set_meta("power_signal", true)
		var pipe := CylinderMesh.new()
		pipe.top_radius = CONDUIT_RADIUS
		pipe.bottom_radius = CONDUIT_RADIUS
		pipe.height = length
		line.mesh = pipe
		line.position = centre
		line.material_override = ThemeMaterials.glow_material(POWER_IDLE, 0.08)
		root.add_child(line)
		if not axis.is_equal_approx(Vector3.UP) \
				and not axis.is_equal_approx(Vector3.DOWN):
			line.quaternion = Quaternion(Vector3.UP, axis)
		var normal: Vector3 = normals[i]
		if normal == Vector3.ZERO:
			continue
		var across := axis.cross(normal).abs()
		var run_abs := axis.abs()
		var normal_abs := normal.abs()
		_hardware(root, "Raceway_%d" % i, centre - normal * CONDUIT_STANDOFF * 0.5,
				run_abs * length + across * 0.2 + normal_abs * CONDUIT_STANDOFF)
		var saddles := maxi(1, int(ceil(length / 1.4)))
		for j in saddles + 1:
			var at := a.lerp(b, (float(j) + 0.2) / (float(saddles) + 0.4))
			_hardware(root, "Saddle", at - normal * 0.035,
					run_abs * 0.1 + across * 0.29 + normal_abs * 0.17)
	return root


static func conduit_power(root: Node3D, on: bool) -> void:
	if root == null:
		return
	root.set_meta("live", on)
	for child in root.get_children():
		if child is MeshInstance3D and child.has_meta("power_signal"):
			(child as MeshInstance3D).material_override = \
					ThemeMaterials.glow_material(
						POWER if on else POWER_IDLE, 0.5 if on else 0.08)


static func _hardware(parent: Node3D, label: String, at: Vector3,
		size: Vector3) -> MeshInstance3D:
	var made := MeshInstance3D.new()
	made.name = label
	made.position = at
	var box := BoxMesh.new()
	box.size = size
	made.mesh = box
	made.material_override = ThemeMaterials.trim_mat(THEME)
	parent.add_child(made)
	return made


## A plain sign: what a thing does or where a way goes, in the handoff's
## plain words. A billboard so it reads from every approach.
static func plain_sign(parent: Node3D, text: String, at: Vector3, size := 26,
		tint := NEUTRAL) -> Label3D:
	var label := Label3D.new()
	label.name = "Sign"
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.01
	label.modulate = tint
	label.outline_size = 8
	label.outline_modulate = Color(0.05, 0.06, 0.06, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


## A LATCHING LEVER ON A FLOOR MOUNT (Wisp's B/C control, reviewed).
##
## The base `CallLever` is a momentary control that decides nothing; this
## one is the permanent kind -- the owner of the consequence calls
## `lock(note)` from its `pulled` handler, and the handle then stays ON
## and the prompt says what it did (D-07: a permanent control looks
## permanent). Its origin stands 1 m above the floor it is bolted to.
class Lever extends CallLever:
	const FLOOR_Y := -1.0
	const OFF_DEGREES := -55.0
	const ON_DEGREES := 55.0
	const PEDESTAL_SIZE := Vector3(0.46, 0.825, 0.46)
	const PEDESTAL_AT := Vector3(0.0, -0.5875, 0.0)
	const FOOT_SIZE := Vector3(0.7, 0.1, 0.7)
	const FOOT_AT := Vector3(0.0, -0.95, 0.0)

	var _pilot: MeshInstance3D
	var _pilot_material: StandardMaterial3D
	var _tint: Color

	static func mounted(label_in: String, tint: Color,
			theme := "concrete_facility") -> Lever:
		var made := Lever.new()
		made.label = label_in
		made.name = "Lever_%s" % label_in.to_lower().replace(" ", "_")
		made._build(tint, theme)
		return made

	func _build(tint: Color, theme: String) -> void:
		super._build(tint, theme)
		_tint = tint
		var metal := ThemeMaterials.glow_material(Color("697472"), 0.0)
		metal.metallic = 0.55
		metal.roughness = 0.7
		_part(self, "Pedestal", PEDESTAL_AT, PEDESTAL_SIZE, metal)
		_part(self, "Foot", FOOT_AT, FOOT_SIZE, metal)
		_collider("PedestalCollision", PEDESTAL_AT, PEDESTAL_SIZE)
		_collider("FootCollision", FOOT_AT, FOOT_SIZE)
		for x in [-0.26, 0.26]:
			for z in [-0.26, 0.26]:
				_part(self, "Bolt", Vector3(x, -0.89, z),
						Vector3(0.06, 0.04, 0.06), metal)
		var handle := ThemeMaterials.glow_material(tint, 0.25)
		(_arm.get_child(0) as MeshInstance3D).material_override = handle
		_part(_arm, "Grip", Vector3(0, ARM.y - 0.04, 0),
				Vector3(0.26, 0.15, 0.18), handle)
		_arm.rotation = Vector3(0, 0, deg_to_rad(OFF_DEGREES))
		# A pilot on the pedestal's face: horizontal and dim while OFF,
		# upright and lit once latched -- readable without the words.
		var housing := Node3D.new()
		housing.name = "Pilot"
		housing.position = Vector3(0, -0.31, 0.245)
		add_child(housing)
		_part(housing, "Housing", Vector3.ZERO, Vector3(0.3, 0.24, 0.06), metal)
		_pilot_material = ThemeMaterials.glow_material(tint.darkened(0.5), 0.06)
		_pilot = _part(housing, "Bar", Vector3(0, 0, 0.035),
				Vector3(0.045, 0.14, 0.02), _pilot_material)
		_mark("OFF", Vector3(0.235, 0.02, BASE.z * 0.5 + 0.002))
		_mark("ON", Vector3(-0.235, 0.02, BASE.z * 0.5 + 0.002))
		_sync()

	## LATCH IT. `CallLever.lock` throws the arm about X -- the base
	## lever's own swing -- which on this mount would leave the handle
	## pointing sideways; the pose here is `advance`'s.
	func lock(note: String) -> void:
		locked = true
		if note != "":
			done_label = note
		_thrown = 1.0
		_sync()

	func interact_prompt() -> String:
		if locked and done_label != "":
			return done_label
		return super.interact_prompt()

	## The handle travels from wherever it is to ON once latched; a pull
	## that latched nothing (a control without power) swings it and lets
	## it fall back, so the press is still seen.
	func advance(delta: float) -> void:
		if _arm == null:
			return
		var target := OFF_DEGREES
		if locked:
			target = ON_DEGREES
		elif _thrown > 0.0:
			_thrown = maxf(_thrown - delta / THROW_SECONDS, 0.0)
			target = lerpf(OFF_DEGREES, ON_DEGREES, _thrown)
		var speed := deg_to_rad(ON_DEGREES - OFF_DEGREES) / THROW_SECONDS
		_arm.rotation = Vector3(0, 0, move_toward(_arm.rotation.z,
				deg_to_rad(target), maxf(delta, 0.0) * speed))
		_sync()

	## Where the handle is, in degrees: OFF is -55, ON is +55.
	func handle_degrees() -> float:
		return rad_to_deg(_arm.rotation.z) if _arm != null else 0.0

	func _sync() -> void:
		if _pilot_material == null:
			return
		var lit := _tint if locked else _tint.darkened(0.5)
		_pilot_material.albedo_color = lit
		_pilot_material.emission = lit
		_pilot_material.emission_energy_multiplier = 0.5 if locked else 0.06
		_pilot.rotation.z = 0.0 if locked else PI * 0.5

	func _collider(name_in: String, at: Vector3, size: Vector3) -> void:
		var shape := CollisionShape3D.new()
		shape.name = name_in
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = at
		add_child(shape)

	func _part(parent: Node3D, name_in: String, at: Vector3, size: Vector3,
			material: Material) -> MeshInstance3D:
		var mesh := MeshInstance3D.new()
		mesh.name = name_in
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.position = at
		mesh.material_override = material
		parent.add_child(mesh)
		return mesh

	func _mark(text_in: String, at: Vector3) -> void:
		var mark := Label3D.new()
		mark.name = text_in + "Mark"
		mark.text = text_in
		mark.position = at
		mark.font_size = 32
		mark.pixel_size = 0.0018
		mark.modulate = NEUTRAL
		add_child(mark)


## THE POWER SOCKET THE CELL INSTALLS INTO: `ObjectSocket`, so the hand
## installs it through the ordinary carry path (`HandCarry.on_interact`
## asks `install_refusal`, then `install`). Standalone, with no Zone state
## or transported-objects ledger behind it, so it names its one object
## itself; and its ring is power green, not the base socket's orange --
## orange is for what breaks.
class CellSocket extends ObjectSocket:
	var cell: ManipulableBody = null

	static func made(id: String, the_cell: ManipulableBody,
			theme := "concrete_facility") -> CellSocket:
		var socket := CellSocket.new()
		socket.mechanism_id = id
		socket.accepts = "power_cell"
		socket.cell = the_cell
		socket.name = "Socket_%s" % id
		socket._theme = theme
		socket._build()
		return socket

	func install_refusal(body: ManipulableBody) -> String:
		if installed_object != "":
			return "SOCKET FULL"
		if body == null or not is_instance_valid(body) or body != cell:
			return "THIS SOCKET TAKES THE POWER CELL"
		return ""

	func _show() -> void:
		if _ring == null:
			return
		var on := installed_object != ""
		_ring.material_override = ThemeMaterials.glow_material(
				POWER if on else POWER_IDLE, 0.7 if on else 0.15)

	func interact_prompt() -> String:
		if installed_object != "":
			return "POWER CELL INSTALLED"
		return "SOCKET · BRING THE POWER CELL"


## WHERE AN ALLOCATED CHECK (OR A LOCAL REWARD) WOULD STAND: a stand-in.
##
## Dess's brief: Checks in the review build sit exactly where allocated
## Checks would go, are marked as stand-ins and send nothing. This holds
## no item, names no location, recipient or AP id, and talks to nobody;
## finding one only tells this session's tally.
class StandIn extends StaticBody3D:
	signal found(id: String)

	var id := ""
	var kind := "check"
	## False while something still holds it shut (the Yard's, until clear).
	var available := true
	var claimed := false
	var _core: MeshInstance3D
	var _label: Label3D
	var _spin := 0.0

	static func make(id_in: String, kind_in := "check",
			theme := "concrete_facility") -> StandIn:
		var made := StandIn.new()
		made.id = id_in
		made.kind = kind_in
		made.name = "StandIn_%s" % id_in
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, 1.0, 0.9)
		shape.shape = box
		shape.position = Vector3(0, 0.5, 0)
		made.add_child(shape)
		var plinth := MeshInstance3D.new()
		var plinth_mesh := BoxMesh.new()
		plinth_mesh.size = Vector3(0.9, 1.0, 0.9)
		plinth.mesh = plinth_mesh
		plinth.position = Vector3(0, 0.5, 0)
		plinth.material_override = ThemeMaterials.trim_mat(theme)
		made.add_child(plinth)
		made._core = MeshInstance3D.new()
		var gem := SphereMesh.new()
		gem.radius = 0.24
		gem.height = 0.48
		gem.radial_segments = 6
		gem.rings = 3
		made._core.mesh = gem
		made._core.position = Vector3(0, 1.35, 0)
		made.add_child(made._core)
		made._label = Label3D.new()
		made._label.position = Vector3(0, 2.05, 0)
		made._label.font_size = 22
		made._label.pixel_size = 0.008
		made._label.outline_size = 6
		made._label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		made._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		made.add_child(made._label)
		made._refresh()
		return made

	func _process(delta: float) -> void:
		_spin += delta
		if _core != null and not claimed:
			_core.rotation.y = _spin * 0.8
			_core.position.y = 1.35 + sin(_spin * 2.0) * 0.06

	func set_available(value: bool) -> void:
		available = value
		_refresh()

	func title() -> String:
		return "CHECK" if kind == "check" else "LOCAL REWARD"

	func interact_prompt() -> String:
		if claimed:
			return "%s FOUND · STAND-IN, NOTHING SENT" % title()
		if not available:
			return "%s · OPENS WHEN THE YARD IS CLEAR" % title()
		return "[E] %s · STAND-IN" % title()

	func interact(_who: Node) -> void:
		if claimed or not available:
			return
		claimed = true
		_refresh()
		found.emit(id)

	func _refresh() -> void:
		if _core == null:
			return
		var white := Color(0.92, 0.94, 0.96)
		_core.material_override = ThemeMaterials.glow_material(
				white, 0.15 if claimed else (0.9 if available else 0.3))
		_core.visible = not claimed
		_label.text = "%s\nSTAND-IN · SENDS NOTHING%s" % [title(),
				"\nFOUND" if claimed else ""]
		_label.modulate = white if available else white.darkened(0.35)


## THE WAY OUT, in the approved portal art (`content/ways_out`), with this
## build's own words: the ordinary portal says RETURN TO HUB, and there
## is no hub here.
class ExitDoor extends StaticBody3D:
	signal used

	var uses := 0

	static func make(theme := "concrete_facility") -> ExitDoor:
		var door := ExitDoor.new()
		door.name = "ExitDoor"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 4.0, 1.0)
		shape.shape = box
		shape.position = Vector3(0, 2.0, 0)
		door.add_child(shape)
		var frame := MeshInstance3D.new()
		frame.name = "Frame"
		var wound := ExitPortal.art_mesh("portal_b2_wound")
		if wound != null:
			frame.mesh = wound
		else:
			var plain := BoxMesh.new()
			plain.size = Vector3(3.2, 4.2, 0.6)
			frame.mesh = plain
			frame.position = Vector3(0, 2.1, 0)
			frame.material_override = ThemeMaterials.trim_mat(theme)
		door.add_child(frame)
		var core := MeshInstance3D.new()
		core.name = "Core"
		var lit := ExitPortal.art_mesh("portal_core_unlocked")
		if lit != null:
			core.mesh = lit
		else:
			var plain_core := BoxMesh.new()
			plain_core.size = Vector3(2.4, 3.4, 0.2)
			core.mesh = plain_core
			core.position = Vector3(0, 1.9, 0)
			core.material_override = ThemeMaterials.glow_material(
					Color(0.5, 1.0, 0.6), 2.0)
		door.add_child(core)
		var label := Label3D.new()
		label.text = "EXIT"
		label.position = Vector3(0, 4.6, 0)
		label.font_size = 44
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.6, 1.0, 0.7)
		door.add_child(label)
		return door

	func interact_prompt() -> String:
		return "[E] LEAVE THE CROSSING"

	func interact(_who: Node) -> void:
		uses += 1
		used.emit()
