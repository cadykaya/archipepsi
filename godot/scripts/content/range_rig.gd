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
## **Three clocks per shot, kept apart and chained** (the owner's
## five-weapon playtest): the gun's visual recovery (`recover`), the aim
## settling (`aim_recover`, the view climb coming home) and mechanical
## readiness (the weapon's cooldown, which `RangeWeapons` animates as a
## hammer, bolt or pump). Each weapon's `RECOIL` envelope is timed so the
## gun comes home, then the sight settles, then the mechanism is ready:
## no dead wait at the end, no early snap.
##
## **Aim truth.** The view climb is the one thing that turns the camera,
## and it is temporary and exact: an envelope applied as a delta on top of
## the player's own look, which returns to precisely zero before the next
## semi-automatic shot can fire (the check proves it). Everything else is
## the projection offset, a roll about the line of sight and the field of
## view. All of it is scaled by `camera_motion` (0 with reduced motion on).

const REST := Vector3(0.3, -0.27, -0.55)
const REST_ROT := Vector3(0, 6, -3)

## Each weapon's springs: channel -> [jump, kick, freq Hz, damping].
## Units: metres for back/lift/cam_lift, degrees for the rest.
const SPRINGS := {
	"foundry": {"back": [0.03, 1.0, 7.0, 0.45], "lift": [0.01, 0.4, 7.0, 0.45],
		"pitch": [3.0, 160.0, 7.0, 0.4], "roll": [1.5, 40.0, 6.5, 0.5],
		"yaw": [0.0, 0.0, 8.0, 0.6],
		"cam_lift": [0.008, 0.2, 9.0, 0.6], "cam_roll": [1.1, 30.0, 8.0, 0.6],
		"fov": [0.0, 0.0, 9.0, 0.7]},
	"sightline": {"back": [0.015, 0.6, 12.0, 0.6], "lift": [0.004, 0.2, 12.0, 0.6],
		"pitch": [1.5, 80.0, 11.0, 0.55], "roll": [0.8, 18.0, 11.0, 0.6],
		"yaw": [0.0, 0.0, 11.0, 0.7],
		"cam_lift": [0.004, 0.1, 12.0, 0.8], "cam_roll": [0.35, 10.0, 12.0, 0.7],
		"fov": [0.0, 0.0, 12.0, 0.8]},
	"switchback": {"back": [0.025, 0.6, 9.0, 0.35], "lift": [0.006, 0.2, 9.0, 0.35],
		"pitch": [1.4, 45.0, 8.5, 0.35], "roll": [0.5, 12.0, 9.0, 0.4],
		"yaw": [0.0, 30.0, 9.0, 0.4],
		"cam_lift": [0.004, 0.05, 10.0, 0.6], "cam_roll": [0.25, 6.0, 10.0, 0.6],
		"fov": [0.0, 0.0, 10.0, 0.7]},
	"bulkhead": {"back": [0.03, 0.8, 6.0, 0.5], "lift": [0.01, 0.3, 6.0, 0.5],
		"pitch": [2.5, 120.0, 6.0, 0.45], "roll": [1.5, 40.0, 5.5, 0.5],
		"yaw": [0.0, 0.0, 6.0, 0.6],
		"cam_lift": [0.01, 0.2, 8.0, 0.6], "cam_roll": [1.2, 30.0, 7.0, 0.6],
		"fov": [0.0, 0.0, 6.0, 0.7]},
	"driver": {"back": [0.02, 0.6, 5.0, 0.55], "lift": [0.005, 0.2, 5.0, 0.55],
		"pitch": [1.0, 40.0, 5.0, 0.55], "roll": [0.6, 12.0, 5.0, 0.6],
		"yaw": [0.0, 0.0, 5.0, 0.6],
		"cam_lift": [0.006, 0.15, 7.0, 0.7], "cam_roll": [0.3, 8.0, 6.0, 0.7],
		"fov": [0.0, 0.0, 5.0, 0.8]},
}
const CHANNELS: Array[String] = ["back", "lift", "pitch", "roll", "yaw",
		"cam_lift", "cam_roll", "fov"]
const GUN_CHANNELS: Array[String] = ["back", "lift", "pitch", "roll", "yaw"]
## The springs' integration step and the longest frame they integrate.
const SUBSTEP := 1.0 / 240.0
const MAX_FRAME := 0.1

## Each recoil's envelope (seconds, metres, degrees): a fast `attack` to
## the peak, a `hang` there (the weight), then the return, which dips
## `dip` past rest and settles, ending exactly at `recover`. `aim` is the
## view climb (degrees, the one channel that turns the camera), home at
## `aim_recover`; `aim_yaw` its sideways wander; `jolt` a short camera
## shake (metres). Keys are recoil profiles, not weapons: a weapon's
## variant can carry its own.
const RECOIL := {
	"foundry": {"attack": 0.035, "hang": 0.06, "recover": 0.58, "dip": 0.07,
		"back": 0.27, "lift": 0.06, "pitch": 27.0, "roll": 5.0,
		"cam_lift": 0.03, "fov": 4.0, "aim": 2.2, "aim_recover": 0.64,
		"jolt": 0.012},
	"sightline": {"attack": 0.025, "hang": 0.03, "recover": 0.36, "dip": 0.06,
		"back": 0.1, "lift": 0.02, "pitch": 9.0, "roll": 1.5,
		"cam_lift": 0.012, "fov": 1.8, "aim": 1.1, "aim_recover": 0.4,
		"jolt": 0.005},
	# Switchback's baseline is its springs alone (the owner liked it);
	# "hard" is the stronger hip-fire experiment: a heavier gun and a view
	# that climbs and wanders while held, coming home after release.
	"switchback_hard": {"attack": 0.02, "hang": 0.0, "recover": 0.22,
		"dip": 0.0, "back": 0.03, "lift": 0.006, "pitch": 3.0, "roll": 0.8,
		"cam_lift": 0.004, "fov": 0.0, "aim": 0.5, "aim_yaw": 0.22,
		"aim_recover": 0.45, "jolt": 0.002},
	"bulkhead_breacher": {"attack": 0.04, "hang": 0.07, "recover": 0.7,
		"dip": 0.09, "back": 0.3, "lift": 0.05, "pitch": 22.0, "roll": 7.0,
		"cam_lift": 0.045, "fov": 5.0, "aim": 3.2, "aim_recover": 0.76,
		"jolt": 0.016},
	"bulkhead_sweeper": {"attack": 0.03, "hang": 0.03, "recover": 0.42,
		"dip": 0.06, "back": 0.16, "lift": 0.03, "pitch": 12.0, "roll": 3.5,
		"cam_lift": 0.025, "fov": 2.5, "aim": 1.6, "aim_recover": 0.47,
		"jolt": 0.009},
	"driver": {"attack": 0.05, "hang": 0.09, "recover": 0.62, "dip": 0.05,
		"back": 0.12, "lift": 0.02, "pitch": 3.5, "roll": 1.0,
		"cam_lift": 0.02, "fov": 5.5, "aim": 0.7, "aim_recover": 0.7,
		"jolt": 0.01},
}
const ENVELOPED: Array[String] = ["back", "lift", "pitch", "roll",
		"cam_lift", "fov"]

## Aiming down the sights (weapons that have it): the rig pose that puts
## the sight on the line of sight, the zoomed field of view and the time
## to come up.
const ADS := {
	"sightline": {"at": Vector3(0, -0.075, -0.3), "fov": 48.0, "time": 0.18},
	"switchback": {"at": Vector3(0, -0.065, -0.3), "fov": 60.0, "time": 0.14},
	"driver": {"at": Vector3(0, -0.13, -0.38), "fov": 55.0, "time": 0.2},
}

## Each weapon's muzzle: light, flame layers, smoke.
const MUZZLES := {
	"foundry": {"at": Vector3(0, 0.03, -0.47), "energy": 10.0, "range": 16.0,
		"color": Color(1.0, 0.72, 0.42), "decay": 0.12, "core": 0.32,
		"core_color": Color(1.0, 0.95, 0.8), "petals": 4,
		"petal": Vector2(0.11, 0.44), "petal_color": Color(1.0, 0.58, 0.22),
		"flame": 0.05, "smoke": 5, "afterglow": 0.3, "shadows": true,
		"ring": 0.9},
	"sightline": {"at": Vector3(0, 0.025, -0.74), "energy": 6.5, "range": 12.0,
		"color": Color(0.95, 0.95, 1.0), "decay": 0.07, "core": 0.22,
		"core_color": Color(1.0, 1.0, 1.0), "petals": 2,
		"petal": Vector2(0.05, 0.36), "petal_color": Color(1.0, 0.93, 0.8),
		"flame": 0.035, "smoke": 2, "afterglow": 0.12, "shadows": true,
		"ring": 0.5},
	"switchback": {"at": Vector3(0, 0.02, -0.42), "energy": 2.6, "range": 7.0,
		"color": Color(1.0, 0.8, 0.5), "decay": 0.05, "core": 0.19,
		"core_color": Color(1.0, 0.9, 0.7), "petals": 3,
		"petal": Vector2(0.05, 0.18), "petal_color": Color(1.0, 0.65, 0.3),
		"flame": 0.03, "smoke": 0, "afterglow": 0.0, "shadows": false},
	"bulkhead": {"at": Vector3(0, 0.02, -0.5), "energy": 8.0, "range": 12.0,
		"color": Color(1.0, 0.68, 0.38), "decay": 0.15, "core": 0.4,
		"core_color": Color(1.0, 0.9, 0.7), "petals": 8,
		"petal": Vector2(0.12, 0.3), "petal_color": Color(1.0, 0.55, 0.22),
		"flame": 0.06, "smoke": 7, "afterglow": 0.3, "shadows": true,
		"ring": 1.1},
	"driver": {"at": Vector3(0, 0.0, -0.62), "energy": 3.5, "range": 9.0,
		"color": Color(0.92, 0.9, 1.0), "decay": 0.25, "core": 0.34,
		"core_color": Color(0.95, 0.95, 1.0), "petals": 0,
		"petal": Vector2(0.0, 0.0), "petal_color": Color(1, 1, 1),
		"flame": 0.06, "smoke": 5, "afterglow": 0.0, "shadows": true,
		"ring": 1.0},
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
## The recoil profile `kick` uses (a key of `RECOIL`, or "" for springs
## only); `RangeWeapons` sets it with the weapon and its variant.
var recoil_key := ""
## Aiming down the sights: wanted (0/1) and where the rig is (0-1).
var ads_target := 0.0
var ads := 0.0
## Each live kick: {"t", "scale", "aim", "yaw", "spec"}.
var _kicks: Array = []
var _env := {}
var _clock := 0.0
## The view climb currently added on top of the player's look (degrees:
## x pitch, y yaw), so it can be taken back exactly.
var _aim_applied := Vector2.ZERO
var _aim := Vector2.ZERO
var _jolt := 0.0
var _jolt_t := 9.0


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
	_take_back_aim()
	_kicks.clear()
	_env.clear()
	_jolt = 0.0
	ads = 0.0
	ads_target = 0.0
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

## One shot's impulse; `scale` grows or shrinks the gun's part of it (a
## charge's strength, aiming down the sights), `aim_scale` the view climb
## (defaults to `scale`).
func kick(scale := 1.0, aim_scale := -1.0) -> void:
	if weapon == "":
		return
	if aim_scale < 0.0:
		aim_scale = scale
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
	var spec: Dictionary = RECOIL.get(recoil_key, {})
	if not spec.is_empty():
		_kicks.append({"t": _clock, "scale": scale, "aim": aim_scale,
				"yaw": _rng.randf_range(-1.0, 1.0), "roll": _roll_sign,
				"spec": spec})
		_jolt = float(spec.get("jolt", 0.0)) * scale
		_jolt_t = 0.0
	_envelopes()
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


## The shape of one recoil, 0 -> 1 -> (a dip past rest) -> exactly 0 at
## `recover`: a fast ease-out attack, a held peak sagging 4 %, then an
## ease-in-out return.
static func envelope(t: float, attack: float, hang: float, recover: float,
		dip: float) -> float:
	if t < 0.0 or t >= recover:
		return 0.0
	if t < attack:
		var a := t / attack
		return 1.0 - pow(1.0 - a, 3.0)
	if t < attack + hang:
		return 1.0 - 0.04 * (t - attack) / maxf(hang, 0.001)
	var u := (t - attack - hang) / maxf(recover - attack - hang, 0.001)
	var top := 0.96 if hang > 0.0 else 1.0
	if dip <= 0.0:
		return lerpf(top, 0.0, smoothstep(0.0, 1.0, u))
	if u < 0.82:
		var s := smoothstep(0.0, 0.82, u)
		return lerpf(top, -dip, s)
	return -dip * (1.0 - smoothstep(0.82, 1.0, u))


func _process(delta: float) -> void:
	if weapon == "":
		return
	_clock += delta
	_jolt_t += delta
	# Stiff springs integrated in small fixed steps, so a long frame (a
	# hitch, a slow machine) cannot make them blow up.
	var left := minf(delta, MAX_FRAME)
	var steps := maxi(1, ceili(left / SUBSTEP))
	for _i in steps:
		_step(left / steps)
	var spec: Dictionary = ADS.get(weapon, {})
	if spec.is_empty():
		ads_target = 0.0
	var rate := delta / float(spec.get("time", 0.15))
	ads = move_toward(ads, ads_target, rate)
	_envelopes()
	_apply()
	if _flame_left > 0.0:
		_flame_left -= delta
		if _flame_left <= 0.0:
			flame.visible = false


func _envelopes() -> void:
	for channel in ENVELOPED:
		_env[channel] = 0.0
	_aim = Vector2.ZERO
	var live: Array = []
	for kick: Dictionary in _kicks:
		var spec: Dictionary = kick["spec"]
		var t := _clock - float(kick["t"])
		var attack := float(spec["attack"])
		var hang := float(spec["hang"])
		var recover := float(spec["recover"])
		var aim_recover := float(spec["aim_recover"])
		if t >= maxf(recover, aim_recover):
			continue
		live.append(kick)
		var e := envelope(t, attack, hang, recover, float(spec["dip"]))
		var scale := float(kick["scale"])
		for channel in ENVELOPED:
			if channel == "fov":
				continue
			var way := float(kick["roll"]) if channel == "roll" else 1.0
			_env[channel] += float(spec.get(channel, 0.0)) * e * scale * way
		_env["fov"] += float(spec.get("fov", 0.0)) * scale * envelope(t,
				0.02, 0.0, minf(0.3, recover), 0.0)
		var a := envelope(t, attack, hang + 0.02, aim_recover, 0.0) \
				* float(kick["aim"])
		_aim += Vector2(float(spec.get("aim", 0.0)),
				float(spec.get("aim_yaw", 0.0)) * float(kick["yaw"])) * a
	_kicks = live


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
	var spec: Dictionary = ADS.get(weapon, {})
	var raised := ads * ads * (3.0 - 2.0 * ads)
	var at: Vector3 = REST.lerp(spec.get("at", REST), raised)
	var rot: Vector3 = REST_ROT.lerp(Vector3.ZERO if not spec.is_empty()
			else REST_ROT, raised)
	position = at + Vector3(0, _x("lift"), _x("back")) + shake
	rotation_degrees = rot + Vector3(_x("pitch"), _x("yaw"), _x("roll"))
	var camera := player.camera
	var jolt := Vector2.ZERO
	if _jolt_t < 0.12 and _jolt > 0.0:
		jolt = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) \
				* _jolt * (1.0 - _jolt_t / 0.12)
	camera.h_offset = jolt.x * camera_motion
	camera.v_offset = (_x("cam_lift") + jolt.y) * camera_motion
	camera.rotation.z = deg_to_rad(_x("cam_roll")) * camera_motion
	var zoom := lerpf(_base_fov, float(spec.get("fov", _base_fov)), raised)
	camera.fov = zoom + _x("fov") * camera_motion
	# The view climb: added as a delta on the player's own look, so mouse
	# look composes with it and it can be taken back exactly.
	var want := _aim * camera_motion
	var step := want - _aim_applied
	camera.rotation.x += deg_to_rad(step.x)
	camera.rotation.y += deg_to_rad(step.y)
	_aim_applied = want


## The camera put back exactly (leaving a range weapon).
func release_camera() -> void:
	_take_back_aim()
	player.camera.v_offset = 0.0
	player.camera.h_offset = 0.0
	player.camera.rotation.z = 0.0
	player.camera.fov = _base_fov


func _take_back_aim() -> void:
	if player == null:
		return
	player.camera.rotation.x -= deg_to_rad(_aim_applied.x)
	player.camera.rotation.y -= deg_to_rad(_aim_applied.y)
	_aim_applied = Vector2.ZERO
	_aim = Vector2.ZERO


## A channel's whole displacement: its spring plus its envelopes.
func displacement(name_in: String) -> float:
	return _x(name_in)


func _x(key: String) -> float:
	return (_state[key] as Vector2).x + float(_env.get(key, 0.0))


## Every spring within `eps` of rest (metres and degrees alike) and every
## envelope finished, the view climb included.
func at_rest(eps := 0.002) -> bool:
	return gun_at_rest(eps) and aim_settled() and _settled(["cam_lift",
			"cam_roll", "fov"], eps)


## The gun itself home (its visual recovery), whatever the view is doing.
func gun_at_rest(eps := 0.002) -> bool:
	for kick: Dictionary in _kicks:
		if _clock - float(kick["t"]) < float(kick["spec"]["recover"]):
			return false
	return _settled(GUN_CHANNELS, eps)


## The view climb fully home: the aim is exactly where the player left it.
func aim_settled() -> bool:
	return _aim_applied == Vector2.ZERO


## The view climb right now (degrees: pitch, yaw).
func aim_offset() -> Vector2:
	return _aim_applied


func _settled(channels: Array, eps: float) -> bool:
	for channel: String in channels:
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
	if float(m.get("ring", 0.0)) > 0.0:
		_shock_ring(at + forward * 0.06, float(m["ring"]) * strength)


## The blast's pressure front: a pale ring that races out from the muzzle
## and is gone in a tenth of a second. Weight you see, not light.
func _shock_ring(at: Vector3, size: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "ShockRing"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.12
	ring.mesh = quad
	var material := HandCannon._alpha(Color(1.0, 0.92, 0.82, 0.3))
	material.albedo_texture = _ring_texture()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(ring)
	ring.global_position = at
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * 4.5 * size, 0.1) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.1)
	tween.chain().tween_callback(ring.queue_free)


static var _ring_tex: Texture2D


static func _ring_texture() -> Texture2D:
	if _ring_tex != null:
		return _ring_tex
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var r := Vector2(x + 0.5 - size / 2.0, y + 0.5 - size / 2.0).length() \
					/ (size / 2.0)
			var a := clampf(1.0 - absf(r - 0.78) / 0.16, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, a * a))
	_ring_tex = ImageTexture.create_from_image(image)
	return _ring_tex


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
		"needle": {"len": 3.0, "w": 0.011, "speed": 750.0,
			"color": Color(1.0, 0.96, 0.85), "trail": 0.35, "trail_a": 0.2},
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
			# The hammer: falls on the shot, is drawn back as the cylinder
			# indexes, and is cocked the moment the gun is ready.
			var hammer := Node3D.new()
			hammer.name = "Hammer"
			hammer.position = Vector3(0, 0.04, 0.0)
			model.add_child(hammer)
			_box(hammer, Vector3(0.014, 0.045, 0.016), steel, Vector3(0, 0.02, 0.0))
			_box(hammer, Vector3(0.022, 0.01, 0.02), steel, Vector3(0, 0.043, 0.008))
			_parts["foundry/hammer"] = hammer
			_box(model, Vector3(0.048, 0.14, 0.06), wood, Vector3(0, -0.085, 0.05),
					Vector3(-16, 0, 0))
		"sightline":
			# Long and slender, with a sight rail and scope.
			_box(model, Vector3(0.045, 0.06, 0.34), polymer, Vector3(0, 0, -0.15))
			_cyl(model, 0.012, 0.42, steel, Vector3(0, 0.02, -0.52))
			_box(model, Vector3(0.02, 0.012, 0.36), steel, Vector3(0, 0.045, -0.2))
			# A ghost-ring sight (two open rings on the rail) rather than a
			# closed scope tube, so aiming down it looks through it.
			_sight_ring(model, 0.075, -0.07, 0.02, dark)
			_sight_ring(model, 0.075, -0.25, 0.014, dark)
			_box(model, Vector3(0.006, 0.03, 0.006), dark, Vector3(0, 0.06, -0.07))
			_box(model, Vector3(0.006, 0.03, 0.006), dark, Vector3(0, 0.06, -0.25))
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
			_sight_ring(model, 0.065, -0.02, 0.012, dark)
			_box(model, Vector3(0.006, 0.026, 0.006), dark, Vector3(0, 0.052, -0.02))
			_box(model, Vector3(0.004, 0.022, 0.004), steel, Vector3(0, 0.05, -0.38))
		"bulkhead":
			# Broad and short: two barrels and a pump forend.
			_box(model, Vector3(0.09, 0.08, 0.22), steel, Vector3(0, 0, -0.08))
			_cyl(model, 0.022, 0.36, steel, Vector3(-0.024, 0.02, -0.33))
			_cyl(model, 0.022, 0.36, steel, Vector3(0.024, 0.02, -0.33))
			_parts["bulkhead/pump"] = _box(model, Vector3(0.1, 0.05, 0.14), wood,
					Vector3(0, -0.035, -0.3))
			_box(model, Vector3(0.06, 0.13, 0.07), wood, Vector3(0, -0.085, 0.07),
					Vector3(-18, 0, 0))
			# The Sweeper's feed box under the receiver (that variant only).
			_parts["bulkhead/feed"] = _box(model, Vector3(0.07, 0.17, 0.09),
					HandCannon._metal(Color(0.55, 0.42, 0.16), 0.3, 0.6),
					Vector3(0, -0.11, -0.15), Vector3(8, 0, 0))
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
			# A raised sight, so the heavy body sits low when aiming.
			_sight_ring(model, 0.13, -0.03, 0.016, dark)
			_box(model, Vector3(0.008, 0.095, 0.008), dark, Vector3(0, 0.07, -0.03))
			_box(model, Vector3(0.005, 0.11, 0.005), brass, Vector3(0, 0.075, -0.58))
	return model


## An open sight ring on a post, facing down the barrel.
func _sight_ring(parent: Node3D, height: float, z: float, radius: float,
		material: Material) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.004
	ring.mesh = torus
	ring.material_override = material
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(0, height, z)
	parent.add_child(ring)


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
