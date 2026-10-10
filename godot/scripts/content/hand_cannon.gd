class_name HandCannon
extends Node
## THE HAND-CANNON CANDIDATE (the weapon-feel range's mode H): Heavy Report
## (mode 2), the owner's pick, developed into a separate candidate. Modes
## 1-4 stay as they were, as references; the Static Pulse itself is not
## changed (`Player`, `Constants` and the Pulse's own feedback are
## untouched, and everything here is undone when H is left).
##
## What H adds over Heavy Report:
## - **Physical recoil.** A damped spring per channel (shove back, lift,
##   muzzle rise, roll; the camera's lift, roll and field of view), each
##   shot an impulse. It overshoots and settles like a heavy thing held in
##   a hand, instead of easing home on a curve. The aim never moves.
## - **A hand-cannon in the hand.** A placeholder revolver-shaped viewmodel
##   (gunmetal frame, barrel, cylinder, wooden grip), shown only in H.
##   Primitive shapes; its art is Arty's to make.
## - **A refined muzzle.** A star core and four flame petals at random
##   roll, a warm light that casts shadows and dies off exponentially,
##   then smoke that stays where the shot was fired.
## - **No white tracer.** The Pulse's beam is hidden in H; a hot bullet
##   streak and a fading smoke trail replace it.
## - **A slower cadence to test.** C cycles 0.35 / 0.55 / 0.80 s between
##   shots (the Pulse's own is 0.35). Damage stays the Pulse's 6 a hit;
##   balance is experimental and only the range sees it.
## - **Impacts by material:** metal sparks and a hot-rimmed hole, stone
##   chips and dust, wood splinters, flesh mist and droplets (on the gel
##   block, which jiggles). Every impact leaves a fading mark.
## - **Sound from SigmAudio, not code.** Each cue is a slot filled from
##   `AUDIO_DIR` (`<cue>.ogg|.wav`, or `<cue>_NN` variants picked at
##   random). Until Condi's SigmAudio cues land there, the report and hit
##   use Heavy Report's existing sounds, labelled as placeholders, and the
##   other cues are silent. No new sound is synthesised here.

const ID := "h"
const CADENCES: Array[float] = [0.35, 0.55, 0.8]
const DEFAULT_CADENCE := 0.55
const REST_POS := Vector3(0.34, -0.3, -0.62)
const REST_ROT := Vector3(0, 8, -4)
## The Pulse's muzzle light as the player builds it.
const PULSE_LIGHT_AT := Vector3(0, 0.02, -0.3)
const PULSE_LIGHT_RANGE := 9.0
## The cannon's barrel tip, in viewmodel space.
const MUZZLE := Vector3(0, 0.03, -0.47)
const AUDIO_DIR := "res://audio/sigmaudio/hand_cannon"
## Every cue the candidate asks SigmAudio for (the handoff names them).
const CUES: Array[String] = ["fire", "fire_tail", "mech_ready", "hit_confirm",
		"impact_metal", "impact_stone", "impact_wood", "impact_flesh"]
## Heavy Report's own sounds stand in until SigmAudio's arrive.
const PLACEHOLDER := {"fire": "a_report", "hit_confirm": "a_hit"}
const MATERIALS: Array[String] = ["metal", "stone", "wood", "flesh"]
const MAX_MARKS := 32
const MARK_SECONDS := 8.0
const STREAK_SPEED := 320.0

## THE SPRINGS. `jump` is the displacement on the shot's frame, `kick` the
## velocity added with it; `freq` (Hz) and `zeta` (damping ratio) decide
## how it comes home. Under-damped on purpose: a heavy gun overshoots.
## Units: metres, degrees, degrees of field of view.
const SPRINGS := {
	"back": {"jump": 0.19, "kick": 4.5, "freq": 6.0, "zeta": 0.45},
	"lift": {"jump": 0.05, "kick": 1.6, "freq": 6.0, "zeta": 0.45},
	"pitch": {"jump": 16.0, "kick": 620.0, "freq": 5.5, "zeta": 0.42},
	"roll": {"jump": 2.5, "kick": 40.0, "freq": 6.5, "zeta": 0.5},
	"cam_lift": {"jump": 0.03, "kick": 0.5, "freq": 8.0, "zeta": 0.6},
	"cam_roll": {"jump": 0.9, "kick": 25.0, "freq": 8.0, "zeta": 0.6},
	"fov": {"jump": 3.0, "kick": 0.0, "freq": 7.0, "zeta": 0.7},
}
const FLASH_ENERGY := 7.0
const FLASH_RANGE := 14.0
const FLASH_COLOR := Color(1.0, 0.72, 0.42)
const FLASH_DECAY := 0.12
const FLAME_SECONDS := 0.035

var feel: WeaponFeelTreatments
var player: Player
var active := false
var cadence := DEFAULT_CADENCE
## Every cue started, as [cue, process frame, playing, source], where
## source is "sigmaudio", "placeholder" or "missing".
var played: Array = []
## What the last shot did, for the check.
var last_material := ""
var last_impact: Node3D = null
var last_impact_at := Vector3.INF
var last_streak: Node3D = null
var tracers_hidden := 0
var marks: Array[Node3D] = []
## Where each cue comes from: cue -> Array of streams.
var streams := {}
var source := {}

var _state := {}
var _model: Node3D
var _muzzle: Marker3D
var _flame: Node3D
var _flash: OmniLight3D
var _flash_tween: Tween
var _flame_left := 0.0
var _hidden_parts := {}
var _base_fov := 75.0
var _roll_sign := 1.0
var _rng := RandomNumberGenerator.new()
var _wobble_tween: Tween


func bind(driver: WeaponFeelTreatments) -> void:
	feel = driver
	player = driver.player
	_base_fov = player.camera.fov
	_rng.seed = 1998
	_flash = player.viewmodel.get_node_or_null("MuzzleFlash")
	_build_model()
	_load_cues()
	for channel in SPRINGS:
		_state[channel] = Vector2.ZERO  # x: displacement, y: velocity


# ============================================================== enter/leave

func enter() -> void:
	active = true
	_hidden_parts.clear()
	for part in ["Device", "Tip", "EchoPart"]:
		var node: Node3D = player.viewmodel.get_node_or_null(part)
		if node != null:
			_hidden_parts[part] = node.visible
			node.visible = false
	_model.visible = true
	if _flash != null:
		_flash.position = MUZZLE
		_flash.shadow_enabled = true
	_reset_springs()


func leave() -> void:
	active = false
	for part in _hidden_parts:
		var node: Node3D = player.viewmodel.get_node_or_null(part)
		if node != null:
			node.visible = _hidden_parts[part]
	_hidden_parts.clear()
	_model.visible = false
	_flame.visible = false
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _flash != null:
		_flash.position = PULSE_LIGHT_AT
		_flash.shadow_enabled = false
		_flash.omni_range = PULSE_LIGHT_RANGE
		_flash.light_energy = 0.0
	_reset_springs()
	_clear_world()
	# The Pulse's own cooldown is never left stretched.
	player._pulse_cooldown = minf(player._pulse_cooldown,
			Constants.STATIC_PULSE_COOLDOWN)


## H selected again: everything settled, the gun still in hand.
func reset() -> void:
	_reset_springs()
	_clear_world()


func next_cadence() -> float:
	var at := CADENCES.find(cadence)
	cadence = CADENCES[(at + 1) % CADENCES.size()]
	return cadence


func _reset_springs() -> void:
	for channel in SPRINGS:
		_state[channel] = Vector2.ZERO
	_apply()
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()


func _clear_world() -> void:
	for mark in marks:
		if is_instance_valid(mark):
			mark.queue_free()
	marks.clear()
	for node in [last_impact, last_streak]:
		if is_instance_valid(node):
			node.queue_free()
	last_impact = null
	last_streak = null


# ================================================================ the shot

func on_fired() -> void:
	# The slower cadence: the Pulse has just set its own 0.35 s; this
	# replaces it, in H only.
	player._pulse_cooldown = cadence
	_kick()
	_muzzle_flash()
	_play("fire")
	_play("fire_tail")
	if cadence > 0.3:
		get_tree().create_timer(cadence - 0.12, false).timeout.connect(
				_ready_click)
	# The Pulse's white tracer is about to be spawned: hide it as it
	# enters the tree, until the end of this frame.
	if not get_tree().node_added.is_connected(_hide_tracer):
		get_tree().node_added.connect(_hide_tracer)
	_stop_hiding.call_deferred()
	# The same ray the player is about to cast.
	var hit := player.camera_ray(Constants.STATIC_PULSE_RANGE)
	var from := _muzzle.global_position
	var to: Vector3 = hit.get("position", player.camera.global_position
			- player.camera.global_basis.z * Constants.STATIC_PULSE_RANGE)
	_streak(from, to)
	if not hit.is_empty():
		_impact(hit["position"], hit["normal"], hit["collider"])
	else:
		last_material = ""


func on_hit(_killed: bool) -> void:
	feel._marker.show_mark("heavy", 0.16)
	_play("hit_confirm")


func _ready_click() -> void:
	if active:
		_play("mech_ready")


func _hide_tracer(node: Node) -> void:
	if node is Tracer:
		(node as Tracer).visible = false
		tracers_hidden += 1


func _stop_hiding() -> void:
	if get_tree().node_added.is_connected(_hide_tracer):
		get_tree().node_added.disconnect(_hide_tracer)


# ================================================================ recoil

func _kick() -> void:
	_roll_sign = -_roll_sign
	for channel in SPRINGS:
		var s: Dictionary = SPRINGS[channel]
		var way := _roll_sign if channel in ["roll", "cam_roll"] else 1.0
		var state: Vector2 = _state[channel]
		state.x += float(s["jump"]) * way
		state.y += float(s["kick"]) * way
		_state[channel] = state
	_apply()


func _process(delta: float) -> void:
	if not active:
		return
	# Two half steps: a stiff spring at 60 fps stays stable.
	for _i in 2:
		_step(delta * 0.5)
	_apply()
	if _flame_left > 0.0:
		_flame_left -= delta
		if _flame_left <= 0.0:
			_flame.visible = false


func _step(dt: float) -> void:
	for channel in SPRINGS:
		var s: Dictionary = SPRINGS[channel]
		var w := TAU * float(s["freq"])
		var state: Vector2 = _state[channel]
		var accel := -w * w * state.x - 2.0 * float(s["zeta"]) * w * state.y
		state.y += accel * dt
		state.x += state.y * dt
		_state[channel] = state


func _apply() -> void:
	var vm := player.viewmodel
	vm.position = REST_POS + Vector3(0, _x("lift"), _x("back"))
	vm.rotation_degrees = REST_ROT + Vector3(_x("pitch"), 0, _x("roll"))
	player.camera.v_offset = _x("cam_lift")
	player.camera.rotation.z = deg_to_rad(_x("cam_roll"))
	player.camera.fov = _base_fov + _x("fov")


func _x(channel: String) -> float:
	return (_state[channel] as Vector2).x


## The spring's displacement and velocity, for the check.
func spring(channel: String) -> Vector2:
	return _state[channel]


# ================================================================ muzzle

func _muzzle_flash() -> void:
	_flame.visible = true
	_flame_left = FLAME_SECONDS
	_flame.rotation.z = _rng.randf_range(0.0, TAU)
	_flame.scale = Vector3.ONE * _rng.randf_range(0.85, 1.15)
	if _flash != null:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash.light_color = FLASH_COLOR
		_flash.omni_range = FLASH_RANGE
		_flash.light_energy = FLASH_ENERGY
		_flash_tween = create_tween()
		_flash_tween.tween_property(_flash, "light_energy", 0.0, FLASH_DECAY) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Smoke stays in the world where the shot left the barrel.
	var at := _muzzle.global_position
	var forward := -player.camera.global_basis.z
	for i in 4:
		var puff := _billboard(_tex_soft(), Color(0.55, 0.53, 0.5, 0.32), 0.08)
		_world().add_child(puff)
		puff.global_position = at + forward * (0.04 + 0.05 * i)
		var tween := puff.create_tween().set_parallel()
		var life := 0.7 + 0.15 * i
		tween.tween_property(puff, "scale", Vector3.ONE * (4.0 + i),
				life).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "position",
				puff.position + Vector3(0, 0.25, 0) + forward * 0.15, life)
		tween.tween_property(puff.material_override, "albedo_color:a", 0.0,
				life)
		tween.chain().tween_callback(puff.queue_free)


func _streak(from: Vector3, to: Vector3) -> void:
	if is_instance_valid(last_streak):
		last_streak.queue_free()
	var root := Node3D.new()
	root.name = "CannonStreak"
	_world().add_child(root)
	last_streak = root
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var dir := (to - from) / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	# The bullet: a short, hot streak that crosses the range in a few
	# frames.
	var bullet := MeshInstance3D.new()
	var slug := BoxMesh.new()
	slug.size = Vector3(0.014, 0.014, minf(1.2, length))
	bullet.mesh = slug
	bullet.material_override = _additive(Color(1.0, 0.78, 0.4), 0.95)
	bullet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bullet)
	bullet.look_at_from_position(from + dir * minf(0.6, length * 0.5), to, up)
	var flight := maxf(1.0 / 60.0, length / STREAK_SPEED)
	var tween := root.create_tween()
	tween.tween_property(bullet, "global_position",
			to - dir * minf(0.6, length * 0.5), flight)
	tween.tween_callback(bullet.queue_free)
	# The trail: a faint grey line that widens and fades.
	var trail := MeshInstance3D.new()
	var line := BoxMesh.new()
	line.size = Vector3(0.008, 0.008, length)
	trail.mesh = line
	trail.material_override = _alpha(Color(0.7, 0.68, 0.64, 0.22))
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trail)
	trail.look_at_from_position((from + to) * 0.5, to, up)
	var fade := root.create_tween().set_parallel()
	fade.tween_property(trail, "scale", Vector3(3.0, 3.0, 1.0), 0.4)
	fade.tween_property(trail.material_override, "albedo_color:a", 0.0, 0.4)
	fade.chain().tween_callback(root.queue_free)


# ================================================================ impacts

## What a collider is made of: its own `impact_material` meta or an
## ancestor's; an enemy is flesh; anything else built of the range's
## concrete is stone.
static func material_of(collider: Variant) -> String:
	var node := collider as Node if is_instance_valid(collider) else null
	while node != null:
		if node.has_meta("impact_material"):
			return String(node.get_meta("impact_material"))
		if node.is_in_group("enemies"):
			return "flesh"
		node = node.get_parent()
	return "stone"


func _impact(at: Vector3, normal: Vector3, collider: Variant) -> void:
	var kind := material_of(collider)
	last_material = kind
	last_impact_at = at
	if is_instance_valid(last_impact):
		last_impact.queue_free()
	var root := Node3D.new()
	root.name = "CannonImpact_" + kind
	_world().add_child(root)
	root.global_position = at + normal * 0.02
	last_impact = root
	var life := 0.6
	match kind:
		"metal":
			_spray(root, normal, 26, 0.35, Vector2(4.0, 9.0), 55.0,
					Vector3(0.008, 0.008, 0.07), _additive(Color(1.0, 0.75, 0.35)),
					true)
			_light(root, normal, Color(1.0, 0.7, 0.35), 3.5, 0.12)
			_puff(root, Color(0.5, 0.5, 0.5, 0.25), 0.3, 0.5)
			life = 0.5
		"stone":
			_spray(root, normal, 22, 0.7, Vector2(2.0, 5.0), 55.0,
					Vector3(0.04, 0.03, 0.04), _lit(Color(0.3, 0.29, 0.27)),
					false)
			_puff(root, Color(0.42, 0.38, 0.33, 0.7), 1.3, 0.9)
			life = 0.9
		"wood":
			_spray(root, normal, 18, 0.6, Vector2(1.8, 4.0), 50.0,
					Vector3(0.016, 0.016, 0.1), _lit(Color(0.9, 0.78, 0.55)),
					false)
			_puff(root, Color(0.8, 0.68, 0.5, 0.55), 0.8, 0.7)
			life = 0.7
		"flesh":
			_puff(root, Color(0.45, 0.04, 0.05, 0.65), 0.55, 0.28)
			_spray(root, normal, 12, 0.45, Vector2(1.0, 2.5), 60.0,
					Vector3(0.018, 0.018, 0.018), _lit(Color(0.35, 0.02, 0.03)),
					false)
			life = 0.6
	var timer := root.create_tween()
	timer.tween_interval(life)
	timer.tween_callback(root.queue_free)
	_mark(at, normal, kind)
	_play_at("impact_" + kind, at)
	_react(collider, kind)


func _spray(root: Node3D, normal: Vector3, amount: int, life: float,
		speed: Vector2, spread: float, grain: Vector3, material: Material,
		streaks: bool) -> void:
	var p := CPUParticles3D.new()
	p.name = "Spray"
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3(0, 0, 1)
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0, -9.8, 0)
	p.particle_flag_align_y = streaks
	var box := BoxMesh.new()
	# Aligned to their velocity, sparks draw as streaks along Y.
	box.size = Vector3(grain.x, grain.z, grain.y) if streaks else grain
	p.mesh = box
	p.material_override = material
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	root.add_child(p)
	p.global_basis = Basis.looking_at(-normal, Vector3.UP
			if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD)
	p.emitting = true


func _light(root: Node3D, normal: Vector3, color: Color, energy: float,
		seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 3.0
	root.add_child(light)
	light.position = normal * 0.25
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _puff(root: Node3D, color: Color, size: float, seconds: float) -> void:
	var puff := _billboard(_tex_soft(), color, 0.12)
	root.add_child(puff)
	var tween := puff.create_tween().set_parallel()
	tween.tween_property(puff, "scale", Vector3.ONE * size / 0.12, seconds) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(puff.material_override, "albedo_color:a", 0.0,
			seconds)


## A mark that stays a while: a hole, a chip, a split, a stain.
func _mark(at: Vector3, normal: Vector3, kind: String) -> void:
	var decal := Decal.new()
	decal.name = "Mark_" + kind
	var across: float = {"metal": 0.22, "stone": 0.32, "wood": 0.26,
			"flesh": 0.4}.get(kind, 0.22)
	decal.size = Vector3(across, 0.25, across)
	decal.texture_albedo = _tex_mark(kind)
	if kind == "metal":
		decal.texture_emission = _tex_glow()
		decal.emission_energy = 2.5
	_world().add_child(decal)
	decal.global_position = at
	decal.global_basis = WeaponFeelTreatments._axis_onto(normal) \
			.rotated(normal.normalized(), _rng.randf_range(0.0, TAU))
	marks.append(decal)
	while marks.size() > MAX_MARKS:
		var old: Node3D = marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tween := decal.create_tween()
	if kind == "metal":
		# The hot rim cools.
		tween.tween_property(decal, "emission_energy", 0.0, 1.5)
	tween.tween_interval(MARK_SECONDS)
	tween.tween_property(decal, "modulate:a", 0.0, 1.0)
	tween.tween_callback(decal.queue_free)


## The target's own reaction: a figure rocks back, the gel jiggles.
func _react(collider: Variant, _kind: String) -> void:
	var node := collider as Node3D if is_instance_valid(collider) else null
	if node == null:
		return
	if node == feel._target_body and feel._target_visual != null:
		var visual := feel._target_visual
		if _wobble_tween != null and _wobble_tween.is_valid():
			_wobble_tween.kill()
		visual.rotation = Vector3(-deg_to_rad(9.0), 0, 0)
		_wobble_tween = create_tween()
		_wobble_tween.tween_property(visual, "rotation:x", 0.0, 0.42) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	elif node.has_method("jiggle"):
		node.jiggle()


# ================================================================ sound

## Fills each cue's slot from SigmAudio's folder, if it is there. `dir`
## is the folder to read (the check points it at a fixture).
func _load_cues(dir := AUDIO_DIR) -> void:
	streams.clear()
	source.clear()
	# `list_directory` sees imported files the way an exported build does.
	var files := ResourceLoader.list_directory(dir) \
			if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
	for cue in CUES:
		var found: Array = []
		for file in files:
			var base := file.get_basename()
			var ext := file.get_extension().to_lower()
			if not ext in ["ogg", "wav", "mp3"]:
				continue
			if base == cue or (base.begins_with(cue + "_")
					and base.substr(cue.length() + 1).is_valid_int()):
				var stream := load(dir + "/" + file) as AudioStream
				if stream != null:
					found.append(stream)
		if not found.is_empty():
			streams[cue] = found
			source[cue] = "sigmaudio"
		elif PLACEHOLDER.has(cue) and feel.sounds.has(PLACEHOLDER[cue]):
			streams[cue] = [(feel.sounds[PLACEHOLDER[cue]] as AudioStreamPlayer)
					.stream]
			source[cue] = "placeholder"
		else:
			source[cue] = "missing"


## Reads the cue slots again from `dir` (the check's fixture), or from
## SigmAudio's own folder.
func reload_cues(dir := AUDIO_DIR) -> void:
	_load_cues(dir)


## How many cues SigmAudio has filled.
func sigmaudio_cues() -> int:
	var count := 0
	for cue in source:
		if source[cue] == "sigmaudio":
			count += 1
	return count


func _play(cue: String) -> void:
	var options: Array = streams.get(cue, [])
	if options.is_empty():
		played.append([cue, Engine.get_process_frames(), false, "missing"])
		return
	var sound := AudioStreamPlayer.new()
	sound.stream = options[_rng.randi() % options.size()]
	sound.volume_db = -5.0 if source[cue] == "placeholder" else 0.0
	sound.pitch_scale = _rng.randf_range(0.96, 1.04) if cue == "fire" else 1.0
	add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
	played.append([cue, Engine.get_process_frames(), sound.playing,
			source[cue]])


func _play_at(cue: String, at: Vector3) -> void:
	var options: Array = streams.get(cue, [])
	if options.is_empty():
		played.append([cue, Engine.get_process_frames(), false, "missing"])
		return
	var sound := AudioStreamPlayer3D.new()
	sound.stream = options[_rng.randi() % options.size()]
	sound.unit_size = 6.0
	_world().add_child(sound)
	sound.global_position = at
	sound.play()
	sound.finished.connect(sound.queue_free)
	played.append([cue, Engine.get_process_frames(), sound.playing,
			source[cue]])


# ================================================================ the model

func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "HandCannonModel"
	_model.visible = false
	player.viewmodel.add_child(_model)
	var steel := _metal(Color(0.16, 0.17, 0.19), 0.85, 0.38)
	var brass := _metal(Color(0.6, 0.45, 0.2), 0.9, 0.3)
	var wood := _metal(Color(0.28, 0.14, 0.07), 0.0, 0.7)
	_part(_box(Vector3(0.055, 0.085, 0.2)), steel, Vector3(0, 0.0, -0.09))
	_part(_cyl(0.021, 0.3), steel, Vector3(0, 0.03, -0.32), Vector3(90, 0, 0))
	_part(_box(Vector3(0.028, 0.014, 0.3)), steel, Vector3(0, 0.055, -0.32))
	_part(_cyl(0.042, 0.075), steel, Vector3(0, 0.018, -0.06),
			Vector3(90, 0, 0))
	_part(_cyl(0.026, 0.02), brass, Vector3(0, 0.03, -0.46), Vector3(90, 0, 0))
	_part(_box(Vector3(0.006, 0.016, 0.01)), brass, Vector3(0, 0.069, -0.44))
	_part(_box(Vector3(0.016, 0.03, 0.03)), steel, Vector3(0, 0.055, 0.025),
			Vector3(-20, 0, 0))
	_part(_box(Vector3(0.048, 0.14, 0.06)), wood, Vector3(0, -0.085, 0.05),
			Vector3(-16, 0, 0))
	_part(_box(Vector3(0.02, 0.03, 0.05)), steel, Vector3(0, -0.04, -0.02))
	_muzzle = Marker3D.new()
	_muzzle.name = "CannonMuzzle"
	_muzzle.position = MUZZLE
	_model.add_child(_muzzle)
	# The flame: a star core and four petals around the line of fire.
	_flame = Node3D.new()
	_flame.name = "CannonFlame"
	_flame.position = MUZZLE
	_flame.visible = false
	_model.add_child(_flame)
	var core := MeshInstance3D.new()
	var core_quad := QuadMesh.new()
	core_quad.size = Vector2(0.3, 0.3)
	core.mesh = core_quad
	core.material_override = _textured(_tex_star(), Color(1.0, 0.92, 0.7), true)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.add_child(core)
	for i in 4:
		var petal := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.1, 0.42)
		petal.mesh = quad
		petal.material_override = _textured(_tex_flame(), Color(1.0, 0.62, 0.25),
				false)
		petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Lying along the barrel (-Z), fanned around it.
		petal.rotation = Vector3(-PI / 2.0, 0, 0)
		var holder := Node3D.new()
		holder.rotation.z = i * PI / 4.0
		holder.add_child(petal)
		petal.position = Vector3(0, 0, -0.19)
		_flame.add_child(holder)


func _part(mesh: Mesh, material: Material, at: Vector3,
		degrees := Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation_degrees = degrees
	_model.add_child(part)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cyl(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	return mesh


static func _metal(color: Color, metallic: float,
		roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _additive(color: Color, alpha := 0.9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	return material


static func _alpha(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material


static func _lit(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


static func _textured(texture: Texture2D, color: Color,
		billboard: bool) -> StandardMaterial3D:
	var material := _additive(color, 1.0)
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
	return material


func _billboard(texture: Texture2D, color: Color, size: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	node.mesh = quad
	var material := _alpha(color)
	material.albedo_texture = texture
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Without this a billboard ignores its node's scale: the puffs grow.
	material.billboard_keep_scale = true
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _world() -> Node:
	return get_tree().current_scene


# ======================================================= textures (cached)

static var _textures := {}


static func _cached(key: String, fn: Callable) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = fn.call()
	return _textures[key]


static func _tex_soft() -> Texture2D:
	return _cached("soft", _make_soft)


static func _tex_star() -> Texture2D:
	return _cached("star", _make_star)


static func _tex_flame() -> Texture2D:
	return _cached("flame", _make_flame)


static func _tex_glow() -> Texture2D:
	return _cached("glow", _make_glow)


static func _tex_mark(kind: String) -> Texture2D:
	return _cached("mark_" + kind, _make_mark.bind(kind))


static func _paint(size: int, fn: Callable) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (x + 0.5) / size * 2.0 - 1.0
			var v := (y + 0.5) / size * 2.0 - 1.0
			image.set_pixel(x, y, fn.call(u, v))
	return ImageTexture.create_from_image(image)


static func _make_soft() -> Texture2D:
	return _paint(64, _soft_px)


static func _soft_px(u: float, v: float) -> Color:
	var r := clampf(sqrt(u * u + v * v), 0.0, 1.0)
	return Color(1, 1, 1, pow(1.0 - r, 2.0))


static func _make_star() -> Texture2D:
	return _paint(64, _star_px)


static func _star_px(u: float, v: float) -> Color:
	var r := clampf(sqrt(u * u + v * v), 0.0, 1.0)
	var spikes := pow(absf(cos(3.0 * atan2(v, u))), 18.0) * (1.0 - r)
	var core := pow(1.0 - r, 3.0)
	return Color(1, 1, 1, clampf(core + spikes * 0.8, 0.0, 1.0))


static func _make_flame() -> Texture2D:
	return _paint(64, _flame_px)


static func _flame_px(u: float, v: float) -> Color:
	# Wide and hot at the barrel (v = 1), thin and cool at the tip.
	var along := (v + 1.0) * 0.5
	var width := 0.25 + 0.75 * along
	var across := clampf(1.0 - absf(u) / width, 0.0, 1.0)
	return Color(1, 1, 1, pow(across, 1.5) * pow(along, 1.3))


static func _make_glow() -> Texture2D:
	return _paint(64, _glow_px)


static func _glow_px(u: float, v: float) -> Color:
	# Emission ignores alpha, so the ring is in the colour itself.
	var r := sqrt(u * u + v * v)
	var ring := clampf(1.0 - absf(r - 0.32) / 0.18, 0.0, 1.0)
	return Color(1.0 * ring, 0.45 * ring, 0.12 * ring, 1.0)


static func _make_mark(kind: String) -> Texture2D:
	return _paint(64, _mark_px.bind(kind))


static func _mark_px(u: float, v: float, kind: String) -> Color:
	var r := sqrt(u * u + v * v)
	var angle := atan2(v, u)
	var jag := 0.08 * sin(angle * 7.0) + 0.05 * sin(angle * 13.0)
	match kind:
		"metal":
			var hole := clampf((0.3 + jag * 0.3 - r) / 0.06, 0.0, 1.0)
			var scorch := clampf(1.0 - r, 0.0, 1.0) * 0.55
			return Color(0.05, 0.045, 0.04, clampf(maxf(hole, scorch), 0.0, 1.0))
		"stone":
			var crater := clampf((0.55 + jag - r) / 0.12, 0.0, 1.0)
			var shade := lerpf(0.07, 0.3, clampf(r / 0.55, 0.0, 1.0))
			return Color(shade, shade * 0.97, shade * 0.93, crater * 0.95)
		"wood":
			var split := clampf((0.45 + jag * 1.5 - r) / 0.1, 0.0, 1.0)
			return Color(0.12, 0.07, 0.03, split * 0.9)
		"flesh":
			var blot := clampf((0.75 + jag * 2.0 - r) / 0.2, 0.0, 1.0)
			return Color(0.3, 0.01, 0.02, blot * 0.85)
	return Color(0, 0, 0, 0)


## A ballistic-gel block: the range's flesh stand-in. A damageable target
## like the dummy (it counts damage and never dies); it jiggles when hit.
class GelBlock extends StaticBody3D:
	var absorbed := 0.0
	var _mesh: MeshInstance3D
	var _tween: Tween

	func _ready() -> void:
		set_meta("impact_material", "flesh")
		add_to_group(Damageable.GROUP)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, 1.0, 0.45)
		shape.shape = box
		shape.position = Vector3(0, 0.5, 0)
		add_child(shape)
		_mesh = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		_mesh.mesh = mesh
		_mesh.position = Vector3(0, 0.5, 0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.85, 0.45, 0.42, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.25
		material.subsurf_scatter_enabled = true
		material.subsurf_scatter_strength = 0.6
		_mesh.material_override = material
		add_child(_mesh)
		var label := Label3D.new()
		label.text = "GEL (flesh)"
		label.font_size = 24
		label.pixel_size = 0.006
		label.position = Vector3(0, 1.25, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

	func take_damage(amount: float, _direction: Vector3 = Vector3.ZERO,
			_knockback: float = 0.0) -> bool:
		absorbed += amount
		return false

	func apply_knockback(_impulse: Vector3) -> void:
		pass

	func jiggle() -> void:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_mesh.scale = Vector3(1.12, 0.88, 1.12)
		_tween = create_tween()
		_tween.tween_property(_mesh, "scale", Vector3.ONE, 0.5) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	func visual() -> MeshInstance3D:
		return _mesh
