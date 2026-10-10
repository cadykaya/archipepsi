class_name RangeRig
extends Node3D
## THE FIVE-WEAPON RANGE'S VIEWMODEL RIG: one placeholder gun per weapon,
## held under the camera, with its own springs, muzzle layers and tracer.
## It replaces the player's own viewmodel only while a range weapon is
## out (`RangeWeapons` hides that one and shows this), so `EchoRuntime`'s
## built-in kick and flash, which act on the player's viewmodel, never
## fight these.
##
## The guns are primitive shapes: distinct silhouettes and moving parts
## to test feel with, not art. Arty owns the real silhouettes and the
## authored 2D flare layers; the 3D layers here (core, tongues, light,
## smoke, sparks, tracer) are Prod's and stay under Arty's frames.
##
## **Aim truth.** Nothing here turns the camera. Camera feedback is the
## projection offset, a roll about the line of sight and the field of
## view, scaled by `camera_motion` (0 with reduced motion on).

const REST := Vector3(0.3, -0.27, -0.55)
const REST_ROT := Vector3(0, 6, -3)

## Each weapon's springs: channel -> [jump, kick, freq Hz, damping].
## Units: metres for back/lift/cam_lift, degrees for the rest.
const SPRINGS := {
	"foundry": {"back": [0.19, 4.5, 6.0, 0.45], "lift": [0.05, 1.6, 6.0, 0.45],
		"pitch": [16.0, 620.0, 5.5, 0.42], "roll": [2.5, 40.0, 6.5, 0.5],
		"yaw": [0.0, 0.0, 8.0, 0.6],
		"cam_lift": [0.03, 0.5, 8.0, 0.6], "cam_roll": [0.9, 25.0, 8.0, 0.6],
		"fov": [3.0, 0.0, 7.0, 0.7]},
	"sightline": {"back": [0.05, 1.2, 11.0, 0.7], "lift": [0.01, 0.3, 11.0, 0.7],
		"pitch": [4.0, 120.0, 10.0, 0.65], "roll": [0.6, 10.0, 11.0, 0.7],
		"yaw": [0.0, 0.0, 11.0, 0.7],
		"cam_lift": [0.008, 0.1, 12.0, 0.8], "cam_roll": [0.0, 0.0, 12.0, 0.8],
		"fov": [0.6, 0.0, 12.0, 0.8]},
	"switchback": {"back": [0.025, 0.6, 9.0, 0.35], "lift": [0.006, 0.2, 9.0, 0.35],
		"pitch": [1.4, 45.0, 8.5, 0.35], "roll": [0.5, 12.0, 9.0, 0.4],
		"yaw": [0.0, 30.0, 9.0, 0.4],
		"cam_lift": [0.004, 0.05, 10.0, 0.6], "cam_roll": [0.25, 6.0, 10.0, 0.6],
		"fov": [0.0, 0.0, 10.0, 0.7]},
	"bulkhead": {"back": [0.24, 3.0, 4.5, 0.5], "lift": [0.03, 0.8, 4.5, 0.5],
		"pitch": [10.0, 300.0, 4.5, 0.5], "roll": [4.0, 60.0, 5.0, 0.5],
		"yaw": [0.0, 0.0, 6.0, 0.6],
		"cam_lift": [0.035, 0.6, 7.0, 0.6], "cam_roll": [1.2, 30.0, 7.0, 0.6],
		"fov": [4.0, 0.0, 6.0, 0.7]},
	"driver": {"back": [0.3, 3.5, 3.5, 0.6], "lift": [0.02, 0.5, 3.5, 0.6],
		"pitch": [5.0, 120.0, 3.5, 0.6], "roll": [1.0, 15.0, 4.0, 0.6],
		"yaw": [0.0, 0.0, 5.0, 0.6],
		"cam_lift": [0.04, 0.7, 6.0, 0.7], "cam_roll": [0.4, 10.0, 6.0, 0.7],
		"fov": [6.0, 0.0, 5.0, 0.8]},
}
const CHANNELS: Array[String] = ["back", "lift", "pitch", "roll", "yaw",
		"cam_lift", "cam_roll", "fov"]

## Each weapon's muzzle: light, flame layers, smoke.
const MUZZLES := {
	"foundry": {"at": Vector3(0, 0.03, -0.47), "energy": 7.0, "range": 14.0,
		"color": Color(1.0, 0.72, 0.42), "decay": 0.12, "core": 0.32,
		"core_color": Color(1.0, 0.95, 0.8), "petals": 4,
		"petal": Vector2(0.11, 0.44), "petal_color": Color(1.0, 0.58, 0.22),
		"flame": 0.05, "smoke": 4, "afterglow": 0.25, "shadows": true},
	"sightline": {"at": Vector3(0, 0.025, -0.74), "energy": 3.0, "range": 8.0,
		"color": Color(0.95, 0.95, 1.0), "decay": 0.05, "core": 0.12,
		"core_color": Color(1.0, 1.0, 1.0), "petals": 1,
		"petal": Vector2(0.04, 0.3), "petal_color": Color(1.0, 0.95, 0.85),
		"flame": 0.025, "smoke": 1, "afterglow": 0.0, "shadows": false},
	"switchback": {"at": Vector3(0, 0.02, -0.42), "energy": 2.6, "range": 7.0,
		"color": Color(1.0, 0.8, 0.5), "decay": 0.05, "core": 0.19,
		"core_color": Color(1.0, 0.9, 0.7), "petals": 3,
		"petal": Vector2(0.05, 0.18), "petal_color": Color(1.0, 0.65, 0.3),
		"flame": 0.03, "smoke": 0, "afterglow": 0.0, "shadows": false},
	"bulkhead": {"at": Vector3(0, 0.02, -0.5), "energy": 8.0, "range": 12.0,
		"color": Color(1.0, 0.68, 0.38), "decay": 0.15, "core": 0.4,
		"core_color": Color(1.0, 0.9, 0.7), "petals": 8,
		"petal": Vector2(0.12, 0.3), "petal_color": Color(1.0, 0.55, 0.22),
		"flame": 0.06, "smoke": 7, "afterglow": 0.3, "shadows": true},
	"driver": {"at": Vector3(0, 0.0, -0.62), "energy": 3.5, "range": 9.0,
		"color": Color(0.92, 0.9, 1.0), "decay": 0.25, "core": 0.34,
		"core_color": Color(0.95, 0.95, 1.0), "petals": 0,
		"petal": Vector2(0.0, 0.0), "petal_color": Color(1, 1, 1),
		"flame": 0.06, "smoke": 5, "afterglow": 0.0, "shadows": true},
}

var weapon := ""
var player: Player
## 1 normally, 0 with reduced camera motion.
var camera_motion := 1.0
var models := {}
var muzzles := {}
var light: OmniLight3D
var flame: Node3D
var _core: MeshInstance3D
var _petals: Array[MeshInstance3D] = []
var _state := {}
var _flame_left := 0.0
var _light_tween: Tween
var _base_fov := 75.0
var _roll_sign := 1.0
var _rng := RandomNumberGenerator.new()
var _tremble := 0.0
var _parts := {}
## The Mass Driver's charge, between the rails: an orb and its light.
var charge_orb: MeshInstance3D
var charge_light: OmniLight3D


func setup(p: Player) -> void:
	player = p
	name = "RangeRig"
	_rng.seed = 2024
	_base_fov = player.camera.fov
	player.camera.add_child(self)
	position = REST
	rotation_degrees = REST_ROT
	visible = false
	for w in SPRINGS:
		models[w] = _build_model(w)
		var marker := Marker3D.new()
		marker.name = "Muzzle"
		marker.position = MUZZLES[w]["at"]
		models[w].add_child(marker)
		muzzles[w] = marker
	light = OmniLight3D.new()
	light.name = "MuzzleLight"
	light.light_energy = 0.0
	add_child(light)
	flame = Node3D.new()
	flame.name = "Flame"
	flame.visible = false
	add_child(flame)
	_core = MeshInstance3D.new()
	var core_quad := QuadMesh.new()
	_core.mesh = core_quad
	_core.material_override = HandCannon._textured(HandCannon._tex_star(),
			Color(1, 1, 1), true)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.add_child(_core)
	for i in 8:
		var petal := MeshInstance3D.new()
		petal.mesh = QuadMesh.new()
		petal.material_override = HandCannon._textured(HandCannon._tex_flame(),
				Color(1, 0.6, 0.25), false)
		petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		petal.rotation = Vector3(-PI / 2.0, 0, 0)
		var holder := Node3D.new()
		holder.rotation.z = i * PI / 4.0
		holder.add_child(petal)
		flame.add_child(holder)
		_petals.append(petal)
	for channel in CHANNELS:
		_state[channel] = Vector2.ZERO
	charge_orb = _billboard(Color(0.92, 0.9, 1.0, 0.95), 0.2)
	charge_orb.name = "ChargeOrb"
	(charge_orb.material_override as StandardMaterial3D).blend_mode = \
			BaseMaterial3D.BLEND_MODE_ADD
	charge_orb.position = Vector3(0, 0.0, -0.4)
	charge_orb.visible = false
	(models["driver"] as Node3D).add_child(charge_orb)
	charge_light = OmniLight3D.new()
	charge_light.name = "ChargeLight"
	charge_light.light_color = Color(0.85, 0.85, 1.0)
	charge_light.omni_range = 3.0
	charge_light.light_energy = 0.0
	charge_light.position = Vector3(0, 0.0, -0.4)
	(models["driver"] as Node3D).add_child(charge_light)


## The charge telegraphed: the orb grows and the light flickers up with it.
func show_charge(ratio: float) -> void:
	charge_orb.visible = ratio > 0.0
	charge_orb.scale = Vector3.ONE * (0.15 + 0.85 * ratio) * _rng.randf_range(
			0.92, 1.08)
	charge_light.light_energy = 2.0 * ratio * _rng.randf_range(0.8, 1.0)


func select(w: String) -> void:
	weapon = w
	for key in models:
		(models[key] as Node3D).visible = key == w
	visible = w != ""
	reset()
	if w != "":
		var m: Dictionary = MUZZLES[w]
		light.position = m["at"]
		flame.position = m["at"]
		light.shadow_enabled = bool(m["shadows"])


func reset() -> void:
	for channel in CHANNELS:
		_state[channel] = Vector2.ZERO
	_tremble = 0.0
	_flame_left = 0.0
	flame.visible = false
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	light.light_energy = 0.0
	_apply()


## The muzzle's world position: where every tracer starts.
func muzzle_position() -> Vector3:
	return (muzzles[weapon] as Marker3D).global_position


func spring(channel: String) -> Vector2:
	return _state[channel]


# ================================================================ recoil

## One shot's impulse; `scale` grows or shrinks it (a charge's strength).
func kick(scale := 1.0) -> void:
	if weapon == "":
		return
	_roll_sign = -_roll_sign
	var springs: Dictionary = SPRINGS[weapon]
	for channel in CHANNELS:
		var s: Array = springs[channel]
		var way := 1.0
		if channel in ["roll", "cam_roll"]:
			way = _roll_sign
		elif channel == "yaw":
			way = _rng.randf_range(-1.0, 1.0)
		var state: Vector2 = _state[channel]
		state.x += float(s[0]) * way * scale
		state.y += float(s[1]) * way * scale
		_state[channel] = state
	_apply()


## An extra impulse on one channel (a pump's tilt, a bolt's knock).
func nudge(channel: String, displacement: float, velocity := 0.0) -> void:
	var state: Vector2 = _state[channel]
	state.x += displacement
	state.y += velocity
	_state[channel] = state


## A charge's tremble, 0-1; shakes the gun, never the camera's aim.
func tremble(amount: float) -> void:
	_tremble = amount


func _process(delta: float) -> void:
	if weapon == "":
		return
	for _i in 2:
		_step(delta * 0.5)
	_apply()
	if _flame_left > 0.0:
		_flame_left -= delta
		if _flame_left <= 0.0:
			flame.visible = false


func _step(dt: float) -> void:
	var springs: Dictionary = SPRINGS[weapon]
	for channel in CHANNELS:
		var s: Array = springs[channel]
		var w := TAU * float(s[2])
		var state: Vector2 = _state[channel]
		var accel := -w * w * state.x - 2.0 * float(s[3]) * w * state.y
		state.y += accel * dt
		state.x += state.y * dt
		_state[channel] = state


func _apply() -> void:
	var shake := Vector3.ZERO
	if _tremble > 0.0:
		shake = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1),
				_rng.randf_range(-1, 1)) * 0.004 * _tremble
	position = REST + Vector3(0, _x("lift"), _x("back")) + shake
	rotation_degrees = REST_ROT + Vector3(_x("pitch"), _x("yaw"), _x("roll"))
	var camera := player.camera
	camera.v_offset = _x("cam_lift") * camera_motion
	camera.rotation.z = deg_to_rad(_x("cam_roll")) * camera_motion
	camera.fov = _base_fov + _x("fov") * camera_motion


## The camera put back exactly (leaving a range weapon).
func release_camera() -> void:
	player.camera.v_offset = 0.0
	player.camera.rotation.z = 0.0
	player.camera.fov = _base_fov


func _x(channel: String) -> float:
	return (_state[channel] as Vector2).x


## Every spring within `eps` of rest (metres and degrees alike).
func at_rest(eps := 0.002) -> bool:
	for channel in CHANNELS:
		var limit := eps if channel in ["back", "lift", "cam_lift"] else eps * 100.0
		if absf(_x(channel)) > limit:
			return false
	return true


# ================================================================ muzzle

## The layered muzzle: a core, `petals` tongues at a random roll, a light
## that dies off exponentially, then smoke left in the world and, for the
## heavy guns, a short orange afterglow.
func muzzle_flash(strength := 1.0) -> void:
	var m: Dictionary = MUZZLES[weapon]
	flame.visible = true
	_flame_left = float(m["flame"])
	flame.rotation.z = _rng.randf_range(0.0, TAU)
	flame.scale = Vector3.ONE * _rng.randf_range(0.85, 1.15) * clampf(
			strength, 0.5, 1.5)
	(_core.mesh as QuadMesh).size = Vector2.ONE * float(m["core"])
	(_core.material_override as StandardMaterial3D).albedo_color = m["core_color"]
	var count := int(m["petals"])
	for i in _petals.size():
		var petal := _petals[i]
		petal.visible = i < count
		if i < count:
			# The first `count` petals, fanned evenly around the barrel.
			(petal.get_parent() as Node3D).rotation.z = i * TAU / count
			var size: Vector2 = m["petal"]
			(petal.mesh as QuadMesh).size = size
			petal.position = Vector3(0, 0, -size.y * 0.45)
			(petal.material_override as StandardMaterial3D).albedo_color = \
					m["petal_color"]
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	light.light_color = m["color"]
	light.omni_range = float(m["range"])
	light.light_energy = float(m["energy"]) * strength
	_light_tween = create_tween()
	_light_tween.tween_property(light, "light_energy", 0.0, float(m["decay"])) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var at := muzzle_position()
	var forward := -player.camera.global_basis.z
	for i in int(m["smoke"]):
		_smoke(at + forward * (0.04 + 0.05 * i), forward, 0.7 + 0.15 * i,
				0.28 if weapon != "driver" else 0.18)
	if float(m["afterglow"]) > 0.0:
		_afterglow(float(m["afterglow"]))


func _smoke(at: Vector3, forward: Vector3, life: float, alpha: float) -> void:
	var puff := _billboard(Color(0.55, 0.53, 0.5, alpha), 0.08)
	get_tree().current_scene.add_child(puff)
	puff.global_position = at
	var tween := puff.create_tween().set_parallel()
	tween.tween_property(puff, "scale", Vector3.ONE * 5.0, life) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "position",
			puff.position + Vector3(0, 0.25, 0) + forward * 0.15, life)
	tween.tween_property(puff.material_override, "albedo_color:a", 0.0, life)
	tween.chain().tween_callback(puff.queue_free)


func _afterglow(seconds: float) -> void:
	var glow := _billboard(Color(1.0, 0.5, 0.18, 0.6), 0.1)
	(glow.material_override as StandardMaterial3D).blend_mode = \
			BaseMaterial3D.BLEND_MODE_ADD
	(muzzles[weapon] as Node3D).add_child(glow)
	var tween := glow.create_tween()
	tween.tween_property(glow.material_override, "albedo_color:a", 0.0, seconds)
	tween.tween_callback(glow.queue_free)


func _billboard(color: Color, size: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	node.mesh = quad
	var material := HandCannon._alpha(color)
	material.albedo_texture = HandCannon._tex_soft()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


# ================================================================ tracers

## A weapon's own tracer from the visible muzzle to the resolved hit.
## Styles: "slug" (Foundry), "needle" (Sightline), "speck" (Switchback,
## every third round brighter), "pellet" (Bulkhead), none for the Driver,
## whose projectile is itself the tracer.
func tracer(style: String, from: Vector3, to: Vector3, bright := false) -> Node3D:
	var length := from.distance_to(to)
	if length < 0.05:
		return null
	var spec: Dictionary = {
		"slug": {"len": 1.2, "w": 0.014, "speed": 320.0,
			"color": Color(1.0, 0.78, 0.4), "trail": 0.4, "trail_a": 0.22},
		"needle": {"len": 2.4, "w": 0.006, "speed": 900.0,
			"color": Color(1.0, 0.95, 0.8), "trail": 0.15, "trail_a": 0.12},
		"speck": {"len": 0.35, "w": 0.008 if not bright else 0.012,
			"speed": 420.0, "color": Color(1.0, 0.8, 0.45)
				if not bright else Color(1.0, 0.9, 0.6),
			"trail": 0.0, "trail_a": 0.0},
		"pellet": {"len": 0.3, "w": 0.006, "speed": 300.0,
			"color": Color(1.0, 0.75, 0.45), "trail": 0.0, "trail_a": 0.0},
	}.get(style, {})
	if spec.is_empty():
		return null
	var root := Node3D.new()
	root.name = "Tracer_" + style
	get_tree().current_scene.add_child(root)
	root.set_meta("from", from)
	root.set_meta("to", to)
	var dir := (to - from) / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var slug_len := minf(float(spec["len"]), length)
	var bullet := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(spec["w"], spec["w"], slug_len)
	bullet.mesh = box
	bullet.material_override = HandCannon._additive(spec["color"], 0.95)
	bullet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bullet)
	bullet.look_at_from_position(from + dir * slug_len * 0.5, to, up)
	var flight := maxf(1.0 / 60.0, length / float(spec["speed"]))
	var tween := root.create_tween()
	tween.tween_property(bullet, "global_position", to - dir * slug_len * 0.5,
			flight)
	tween.tween_callback(bullet.queue_free)
	var hold := flight
	if float(spec["trail"]) > 0.0:
		var trail := MeshInstance3D.new()
		var line := BoxMesh.new()
		line.size = Vector3(0.008, 0.008, length)
		trail.mesh = line
		trail.material_override = HandCannon._alpha(
				Color(0.7, 0.68, 0.64, spec["trail_a"]))
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(trail)
		trail.look_at_from_position((from + to) * 0.5, to, up)
		var fade := root.create_tween().set_parallel()
		fade.tween_property(trail, "scale", Vector3(3.0, 3.0, 1.0),
				float(spec["trail"]))
		fade.tween_property(trail.material_override, "albedo_color:a", 0.0,
				float(spec["trail"]))
		hold = maxf(hold, float(spec["trail"]))
	var done := root.create_tween()
	done.tween_interval(hold + 0.02)
	done.tween_callback(root.queue_free)
	return root


# ============================================================ the models

## The moving parts the driver animates: bolt, pump, cylinder, coils, core.
func part(key: String) -> Node3D:
	return _parts.get(weapon + "/" + key)


func _build_model(w: String) -> Node3D:
	var model := Node3D.new()
	model.name = "Gun_" + w
	model.visible = false
	add_child(model)
	var steel := HandCannon._metal(Color(0.16, 0.17, 0.19), 0.85, 0.38)
	var dark := HandCannon._metal(Color(0.1, 0.1, 0.11), 0.6, 0.5)
	var brass := HandCannon._metal(Color(0.6, 0.45, 0.2), 0.9, 0.3)
	var wood := HandCannon._metal(Color(0.28, 0.14, 0.07), 0.0, 0.7)
	var polymer := HandCannon._metal(Color(0.22, 0.23, 0.2), 0.0, 0.8)
	match w:
		"foundry":
			# Short and heavy: the revolver from H.
			_box(model, Vector3(0.055, 0.085, 0.2), steel, Vector3(0, 0, -0.09))
			_cyl(model, 0.021, 0.3, steel, Vector3(0, 0.03, -0.32))
			_box(model, Vector3(0.028, 0.014, 0.3), steel, Vector3(0, 0.055, -0.32))
			var drum := _cyl(model, 0.042, 0.075, steel, Vector3(0, 0.018, -0.06))
			_parts["foundry/cylinder"] = drum
			_cyl(model, 0.026, 0.02, brass, Vector3(0, 0.03, -0.46))
			_box(model, Vector3(0.048, 0.14, 0.06), wood, Vector3(0, -0.085, 0.05),
					Vector3(-16, 0, 0))
		"sightline":
			# Long and slender, with a sight rail and scope.
			_box(model, Vector3(0.045, 0.06, 0.34), polymer, Vector3(0, 0, -0.15))
			_cyl(model, 0.012, 0.42, steel, Vector3(0, 0.02, -0.52))
			_box(model, Vector3(0.02, 0.012, 0.36), steel, Vector3(0, 0.045, -0.2))
			_cyl(model, 0.022, 0.18, dark, Vector3(0, 0.075, -0.16))
			_box(model, Vector3(0.04, 0.09, 0.05), polymer, Vector3(0, -0.07, 0.0),
					Vector3(-12, 0, 0))
			_box(model, Vector3(0.04, 0.05, 0.16), polymer, Vector3(0, -0.01, 0.1))
			_parts["sightline/handle"] = _box(model, Vector3(0.03, 0.012, 0.02),
					steel, Vector3(0.03, 0.03, -0.08))
		"switchback":
			# Compact and boxy; the bolt reciprocates every round.
			_box(model, Vector3(0.06, 0.08, 0.26), polymer, Vector3(0, 0, -0.12))
			_box(model, Vector3(0.05, 0.05, 0.14), dark, Vector3(0, 0.005, -0.32))
			_cyl(model, 0.012, 0.08, steel, Vector3(0, 0.02, -0.4))
			_box(model, Vector3(0.035, 0.12, 0.05), dark, Vector3(0, -0.09, -0.1),
					Vector3(10, 0, 0))
			_box(model, Vector3(0.04, 0.09, 0.05), polymer, Vector3(0, -0.07, 0.03),
					Vector3(-14, 0, 0))
			_parts["switchback/bolt"] = _box(model, Vector3(0.012, 0.025, 0.06),
					steel, Vector3(0.036, 0.02, -0.1))
		"bulkhead":
			# Broad and short: two barrels and a pump forend.
			_box(model, Vector3(0.09, 0.08, 0.22), steel, Vector3(0, 0, -0.08))
			_cyl(model, 0.022, 0.36, steel, Vector3(-0.024, 0.02, -0.33))
			_cyl(model, 0.022, 0.36, steel, Vector3(0.024, 0.02, -0.33))
			_parts["bulkhead/pump"] = _box(model, Vector3(0.1, 0.05, 0.14), wood,
					Vector3(0, -0.035, -0.3))
			_box(model, Vector3(0.06, 0.13, 0.07), wood, Vector3(0, -0.085, 0.07),
					Vector3(-18, 0, 0))
		"driver":
			# Two rails, three coils and an accumulator that glows.
			_box(model, Vector3(0.1, 0.09, 0.26), dark, Vector3(0, -0.01, -0.05))
			_box(model, Vector3(0.014, 0.02, 0.5), steel, Vector3(-0.03, 0.0, -0.37))
			_box(model, Vector3(0.014, 0.02, 0.5), steel, Vector3(0.03, 0.0, -0.37))
			var coils := Node3D.new()
			coils.name = "Coils"
			coils.position = Vector3(0, 0, -0.36)
			model.add_child(coils)
			for i in 3:
				var ring := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = 0.045
				torus.outer_radius = 0.06
				ring.mesh = torus
				ring.material_override = brass
				ring.rotation_degrees = Vector3(90, 0, 0)
				ring.position = Vector3(0, 0, -0.08 + 0.1 * i)
				coils.add_child(ring)
			_parts["driver/coils"] = coils
			var core := MeshInstance3D.new()
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.03
			capsule.height = 0.2
			core.mesh = capsule
			core.rotation_degrees = Vector3(90, 0, 0)
			core.position = Vector3(0, -0.07, -0.08)
			var glow := StandardMaterial3D.new()
			glow.albedo_color = Color(0.3, 0.3, 0.34)
			glow.emission_enabled = true
			glow.emission = Color(0.85, 0.85, 1.0)
			glow.emission_energy_multiplier = 0.0
			core.material_override = glow
			model.add_child(core)
			_parts["driver/core"] = core
			_box(model, Vector3(0.05, 0.12, 0.06), polymer, Vector3(0, -0.1, 0.07),
					Vector3(-14, 0, 0))
	return model


func _box(parent: Node3D, size: Vector3, material: Material, at: Vector3,
		degrees := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = HandCannon._box(size)
	node.material_override = material
	node.position = at
	node.rotation_degrees = degrees
	parent.add_child(node)
	return node


func _cyl(parent: Node3D, radius: float, length: float, material: Material,
		at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = HandCannon._cyl(radius, length)
	node.material_override = material
	node.position = at
	node.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(node)
	return node
