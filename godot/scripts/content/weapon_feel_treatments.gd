class_name WeaponFeelTreatments
extends Node
## THE WEAPON-FEEL TREATMENTS: four ways the Static Pulse can *feel* when
## it fires, and nothing else. Every number that decides combat -- the
## damage (`Constants.STATIC_PULSE_DAMAGE`), the cooldown
## (`Constants.STATIC_PULSE_COOLDOWN`), the ray, what it hits and what the
## target does with the hit -- stays in `Player._fire_static_pulse` and the
## target, untouched. A treatment only answers the two signals that path
## already emits, `fired_pulse` and `hit_confirmed`.
##
## **BASELINE** is the game as it ships: the player's own feedback (the
## anonymous handler `Player._ready` connects: `kick_viewmodel(0.05)` and
## `muzzle_flash(1.6, ...)`), left connected, plus the two tones `Main`
## wires (`pulse` on the shot, `confirm` on a connect).
##
## **A, B and C** disconnect that one handler while selected and answer the
## shot themselves: recoil and recovery on the viewmodel; a camera jolt
## that never moves the aim (the projection offset, the roll about the
## line of sight and the field of view -- none of them changes
## `-camera.basis.z`, so `camera_ray` is the same ray); the muzzle light
## and a muzzle bloom; a report built from the `Tones` bank's own recipe
## (`Tones._synth`, played through `Tones._make_player`); an impact at the
## ray's end; and a hit marker and a hit sound on `hit_confirmed`.
##
## The HUD's own crosshair punch and the target's own flash are the game's,
## and stay on in all four.

signal changed(id: String)

## The four references: the Pulse's baseline and the first three
## treatments, kept as they were delivered.
const IDS: Array[String] = ["baseline", "a", "b", "c"]
## And the hand-cannon candidate developed from A (`HandCannon`).
const HAND := "h"
const ALL_IDS: Array[String] = ["baseline", "a", "b", "c", "h"]
const NAMES := {
	"baseline": "BASELINE · the game as it ships",
	"a": "A · HEAVY REPORT",
	"b": "B · CRISP SNAP",
	"c": "C · ECHO RESONANCE",
	"h": "H · HAND-CANNON CANDIDATE",
}
## The player's viewmodel at rest (`Player._ready`).
const REST_POS := Vector3(0.34, -0.3, -0.62)
const REST_ROT := Vector3(0, 8, -4)
## The player's muzzle light as built, and the default shot's flash.
const LIGHT_RANGE := 9.0
const DEFAULT_COLOR := Color(0.75, 0.85, 1.0)
## Where the muzzle is on the viewmodel (the player's `MuzzleFlash`).
const MUZZLE := Vector3(0, 0.02, -0.3)

## THE TREATMENTS, as numbers. Distances in metres, angles in degrees,
## times in seconds. The report's table is this table.
const SPEC := {
	"a": {
		# Recoil: a big shove back and up, the barrel pitching 14 degrees,
		# then a slow return that settles past rest and back.
		"kick_back": 0.16, "kick_up": 0.05, "kick_pitch": 14.0,
		"kick_roll": 3.0, "recover": 0.30, "trans": Tween.TRANS_BACK,
		# The camera: lifted, rolled and widened, back in 0.24 s.
		"cam_lift": 0.035, "cam_roll": 1.2, "fov_punch": 3.0,
		"cam_recover": 0.24,
		# The muzzle: a hot, warm, wide light and a fireball bloom.
		"flash_energy": 5.0, "flash_range": 12.0,
		"flash_color": Color(1.0, 0.78, 0.5), "flash_decay": 0.14,
		"flash_echo": 0.0, "bloom": "ball", "bloom_size": 0.34,
		"bloom_time": 0.05, "bloom_color": Color(1.0, 0.72, 0.4),
		# The impact: a spray of sparks and a lit splash; the target's
		# figure rocks back.
		"impact": "sparks", "sparks": 18, "impact_time": 0.30,
		"impact_light": 2.5, "impact_color": Color(1.0, 0.7, 0.35),
		"wobble": 7.0, "wobble_time": 0.36,
		# Hit confirmation: a chunky marker and a low knock.
		"marker": "heavy", "marker_time": 0.16, "hit_delay": 0.0,
		"report_db": -5.0, "hit_db": -9.0,
	},
	"b": {
		# Recoil: short and sharp, back to rest in 0.08 s.
		"kick_back": 0.07, "kick_up": 0.015, "kick_pitch": 5.0,
		"kick_roll": 0.0, "recover": 0.08, "trans": Tween.TRANS_EXPO,
		"cam_lift": 0.012, "cam_roll": 0.0, "fov_punch": 0.0,
		"cam_recover": 0.06,
		# The muzzle: a cold white snap, gone in 0.04 s.
		"flash_energy": 3.0, "flash_range": 9.0,
		"flash_color": Color(0.95, 0.97, 1.0), "flash_decay": 0.04,
		"flash_echo": 0.0, "bloom": "ball", "bloom_size": 0.16,
		"bloom_time": 0.03, "bloom_color": Color(0.95, 0.97, 1.0),
		"impact": "puff", "sparks": 6, "impact_time": 0.12,
		"impact_light": 1.2, "impact_color": Color(0.9, 0.95, 1.0),
		"wobble": 2.0, "wobble_time": 0.12,
		"marker": "crisp", "marker_time": 0.09, "hit_delay": 0.0,
		"report_db": -8.0, "hit_db": -12.0,
	},
	"c": {
		# Recoil: medium, eased home over 0.22 s.
		"kick_back": 0.11, "kick_up": 0.03, "kick_pitch": 8.0,
		"kick_roll": -2.0, "recover": 0.22, "trans": Tween.TRANS_SINE,
		# The camera pulls IN a little rather than out: no lift, no roll.
		"cam_lift": 0.0, "cam_roll": 0.0, "fov_punch": -2.0,
		"cam_recover": 0.18,
		# The muzzle: a cyan light that flickers once more as it fades
		# (the echo), and a ring that opens from the barrel.
		"flash_energy": 3.0, "flash_range": 10.0,
		"flash_color": Color(0.5, 0.9, 1.0), "flash_decay": 0.18,
		"flash_echo": 0.08, "bloom": "ring", "bloom_size": 0.40,
		"bloom_time": 0.18, "bloom_color": Color(0.5, 0.9, 1.0),
		"impact": "ring", "sparks": 0, "impact_time": 0.30,
		"impact_light": 1.5, "impact_color": Color(0.5, 0.9, 1.0),
		"wobble": 3.0, "wobble_time": 0.25,
		# Hit confirmation: a ring marker, and a chime that answers 60 ms
		# after the hit -- the echo coming back.
		"marker": "ring", "marker_time": 0.22, "hit_delay": 0.06,
		"report_db": -8.0, "hit_db": -12.0,
	},
}

var current := "baseline"
var player: Player
var tones: Tones
## The player's own shot feedback, the one handler a treatment replaces.
var default_feedback := Callable()
## Every sound a treatment plays, by name ("a_report", "a_hit", ...).
var sounds := {}
## What the last shot did, for the check: the impact it made and where.
var last_impact: Node3D = null
var last_impact_at := Vector3.INF
var shots := 0
var hits := 0
## Every cue started, as [name, process frame, playing right after
## `play()`]: the check reads when each sound began from here.
var played: Array = []
## The hand-cannon candidate, which answers the shot while H is selected.
var hand: HandCannon

var _base_fov := 75.0
var _roll_sign := 1.0
var _flash: OmniLight3D
var _bloom: MeshInstance3D
var _overlay: CanvasLayer
var _marker: Marker
var _target_visual: Node3D = null
var _target_body: Node3D = null
var _recoil_tween: Tween
var _camera_tween: Tween
var _flash_tween: Tween
var _bloom_tween: Tween
var _wobble_tween: Tween


## Takes the player's shot over. Returns false when the player's feedback
## handler is not where `Player._ready` puts it (then nothing is changed).
func bind(p: Player, t: Tones, target: Node3D) -> bool:
	player = p
	tones = t
	_target_body = target
	for child in target.get_children():
		if child is MeshInstance3D:
			_target_visual = child
			break
	var found: Array[Callable] = []
	for connection in player.fired_pulse.get_connections():
		var callable: Callable = connection["callable"]
		if callable.is_custom() and callable.get_object() == player:
			found.append(callable)
	if found.size() != 1:
		return false
	default_feedback = found[0]
	_base_fov = player.camera.fov
	_flash = player.viewmodel.get_node_or_null("MuzzleFlash")
	_bloom = MeshInstance3D.new()
	_bloom.name = "FeelBloom"
	_bloom.position = MUZZLE
	_bloom.visible = false
	_bloom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.viewmodel.add_child(_bloom)
	_overlay = CanvasLayer.new()
	_overlay.layer = 4
	add_child(_overlay)
	_marker = Marker.new()
	_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_marker)
	_build_sounds()
	hand = HandCannon.new()
	hand.name = "HandCannon"
	add_child(hand)
	hand.bind(self)
	player.fired_pulse.connect(_on_fired)
	player.hit_confirmed.connect(_on_hit)
	return true


func select(id: String) -> void:
	if not id in ALL_IDS:
		return
	var was := current
	current = id
	_settle_all()
	if was == HAND and id != HAND:
		hand.leave()
	if id == HAND:
		# Entering hides the Pulse's own transmitter; selecting H again
		# only settles it.
		if was != HAND:
			hand.enter()
		else:
			hand.reset()
	var connected := player.fired_pulse.is_connected(default_feedback)
	if id == "baseline" and not connected:
		player.fired_pulse.connect(default_feedback)
	elif id != "baseline" and connected:
		player.fired_pulse.disconnect(default_feedback)
	changed.emit(id)


func spec() -> Dictionary:
	return SPEC.get(current, {})


## Everything a treatment moves, put back: the viewmodel at rest, the
## camera's offsets and field of view, the light, the bloom, the marker,
## the target's figure, any impact still on screen.
func _settle_all() -> void:
	for tween in [_recoil_tween, _camera_tween, _flash_tween, _bloom_tween,
			_wobble_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	player.viewmodel.position = REST_POS
	player.viewmodel.rotation_degrees = REST_ROT
	player.camera.v_offset = 0.0
	player.camera.rotation.z = 0.0
	player.camera.fov = _base_fov
	if _flash != null:
		_flash.light_energy = 0.0
		_flash.light_color = DEFAULT_COLOR
		_flash.omni_range = LIGHT_RANGE
	_bloom.visible = false
	_marker.clear()
	if _target_visual != null:
		_target_visual.rotation = Vector3.ZERO
	if is_instance_valid(last_impact):
		last_impact.queue_free()
	last_impact = null


# ================================================================ the shot

func _on_fired() -> void:
	shots += 1
	if current == HAND:
		hand.on_fired()
		return
	if current == "baseline":
		tones.play("pulse")
		_log("pulse", tones._players.get("pulse"))
		return
	var s := spec()
	_recoil(s)
	_camera_jolt(s)
	_muzzle(s)
	_play(current + "_report")
	# The same ray the player is about to cast: same origin, same
	# direction (nothing above moved either), same exclusion.
	var hit := player.camera_ray(Constants.STATIC_PULSE_RANGE)
	if not hit.is_empty():
		_impact(s, hit["position"], hit["normal"], hit["collider"])


func _on_hit(killed: bool) -> void:
	hits += 1
	if current == HAND:
		hand.on_hit(killed)
		return
	if current == "baseline":
		if not killed:
			tones.play("confirm")
			_log("confirm", tones._players.get("confirm"))
		return
	var s := spec()
	_marker.show_mark(String(s["marker"]), float(s["marker_time"]))
	var delay := float(s["hit_delay"])
	if delay <= 0.0:
		_play(current + "_hit")
	else:
		get_tree().create_timer(delay, false).timeout.connect(
				_play_for.bind(current, current + "_hit"))


func _recoil(s: Dictionary) -> void:
	var viewmodel := player.viewmodel
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	viewmodel.position = REST_POS + Vector3(0, float(s["kick_up"]),
			float(s["kick_back"]))
	viewmodel.rotation_degrees = REST_ROT + Vector3(float(s["kick_pitch"]), 0,
			float(s["kick_roll"]))
	_recoil_tween = create_tween().set_parallel()
	_recoil_tween.tween_property(viewmodel, "position", REST_POS,
			float(s["recover"])).set_trans(s["trans"]).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(viewmodel, "rotation_degrees", REST_ROT,
			float(s["recover"])).set_trans(s["trans"]).set_ease(Tween.EASE_OUT)


## The view jolts without the aim moving: `v_offset` shifts the picture,
## not the camera; a roll turns about the line of sight itself; the field
## of view is a lens. The next shot's ray is the one this shot's was.
func _camera_jolt(s: Dictionary) -> void:
	var camera := player.camera
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_roll_sign = -_roll_sign
	camera.v_offset = float(s["cam_lift"])
	camera.rotation.z = deg_to_rad(float(s["cam_roll"])) * _roll_sign
	camera.fov = _base_fov + float(s["fov_punch"])
	var back := float(s["cam_recover"])
	_camera_tween = create_tween().set_parallel()
	_camera_tween.tween_property(camera, "v_offset", 0.0, back) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "rotation:z", 0.0, back) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "fov", _base_fov, back) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _muzzle(s: Dictionary) -> void:
	if _flash != null:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		var energy := float(s["flash_energy"])
		_flash.light_color = s["flash_color"]
		_flash.omni_range = float(s["flash_range"])
		_flash.light_energy = energy
		var decay := float(s["flash_decay"])
		var echo := float(s["flash_echo"])
		_flash_tween = create_tween()
		if echo > 0.0:
			# Down, a second smaller flare, down again: the echo.
			_flash_tween.tween_property(_flash, "light_energy", 0.1 * energy,
					echo)
			_flash_tween.tween_property(_flash, "light_energy", 0.55 * energy,
					0.02)
			_flash_tween.tween_property(_flash, "light_energy", 0.0,
					maxf(0.02, decay - echo - 0.02))
		else:
			_flash_tween.tween_property(_flash, "light_energy", 0.0, decay)
	if _bloom_tween != null and _bloom_tween.is_valid():
		_bloom_tween.kill()
	var size := float(s["bloom_size"])
	var color: Color = s["bloom_color"]
	_bloom.mesh = _bloom_mesh(String(s["bloom"]))
	_bloom.material_override = _additive(color)
	_bloom.visible = true
	_bloom_tween = create_tween()
	if s["bloom"] == "ring":
		# Faces down the barrel and opens outward as it fades.
		_bloom.rotation_degrees = Vector3(90, 0, 0)
		_bloom.scale = Vector3.ONE * size * 0.25
		_bloom_tween.set_parallel()
		_bloom_tween.tween_property(_bloom, "scale", Vector3.ONE * size,
				float(s["bloom_time"])).set_ease(Tween.EASE_OUT)
		_bloom_tween.tween_property(_bloom.material_override, "albedo_color:a",
				0.0, float(s["bloom_time"]))
		_bloom_tween.chain().tween_callback(_hide_bloom)
	else:
		_bloom.rotation_degrees = Vector3.ZERO
		_bloom.scale = Vector3.ONE * size
		_bloom_tween.tween_property(_bloom, "scale", Vector3.ONE * size * 0.4,
				float(s["bloom_time"]))
		_bloom_tween.tween_callback(_hide_bloom)


func _hide_bloom() -> void:
	_bloom.visible = false


# ============================================================== the impact

func _impact(s: Dictionary, at: Vector3, normal: Vector3,
		collider: Variant) -> void:
	if is_instance_valid(last_impact):
		last_impact.queue_free()
	var root := Node3D.new()
	root.name = "FeelImpact"
	get_tree().current_scene.add_child(root)
	root.global_position = at + normal * 0.02
	last_impact = root
	last_impact_at = at
	var life := float(s["impact_time"])
	var color: Color = s["impact_color"]
	# A splash of light where it lands.
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = float(s["impact_light"])
	light.omni_range = 3.0
	light.position = normal * 0.3
	root.add_child(light)
	var fade := root.create_tween().set_parallel()
	fade.tween_property(light, "light_energy", 0.0, life * 0.5)
	fade.tween_interval(life)
	if s["impact"] == "ring":
		var ring := MeshInstance3D.new()
		ring.mesh = _bloom_mesh("ring")
		ring.material_override = _additive(color)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
		# The torus lies in its local XZ plane; turn its axis onto the
		# surface normal.
		ring.global_basis = _axis_onto(normal)
		ring.scale = Vector3.ONE * 0.3
		fade.tween_property(ring, "scale", Vector3.ONE * 1.6, life) \
				.set_ease(Tween.EASE_OUT)
		fade.tween_property(ring.material_override, "albedo_color:a", 0.0, life)
	else:
		var sparks := CPUParticles3D.new()
		sparks.name = "Sparks"
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.amount = int(s["sparks"])
		sparks.lifetime = life
		sparks.direction = Vector3(0, 0, 1)
		sparks.spread = 40.0 if s["impact"] == "sparks" else 70.0
		sparks.initial_velocity_min = 2.5 if s["impact"] == "sparks" else 1.5
		sparks.initial_velocity_max = 6.0 if s["impact"] == "sparks" else 3.0
		sparks.gravity = Vector3(0, -9.8, 0) if s["impact"] == "sparks" \
				else Vector3.ZERO
		sparks.scale_amount_min = 1.0
		sparks.scale_amount_max = 1.0
		var grain := BoxMesh.new()
		grain.size = Vector3.ONE * (0.035 if s["impact"] == "sparks" else 0.05)
		sparks.mesh = grain
		sparks.material_override = _additive(color)
		root.add_child(sparks)
		# Spray off the surface: the emitter's +Z onto the normal.
		sparks.global_basis = Basis.looking_at(-normal,
				Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99
				else Vector3.FORWARD)
		sparks.emitting = true
	fade.chain().tween_callback(root.queue_free)
	if collider == _target_body:
		_wobble(s)


## The target's FIGURE rocks; its collider does not move (the next shot
## lands where this one did).
func _wobble(s: Dictionary) -> void:
	if _target_visual == null:
		return
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()
	var tilt := deg_to_rad(float(s["wobble"]))
	# Knocked back on the hit's frame, then home.
	_target_visual.rotation = Vector3(-tilt, 0, 0)
	_wobble_tween = create_tween()
	_wobble_tween.tween_property(_target_visual, "rotation:x", 0.0,
			float(s["wobble_time"])).set_trans(Tween.TRANS_ELASTIC
			if s["impact"] == "sparks" else Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)


## A basis whose +Y is `normal` (a floor or ceiling hit included).
static func _axis_onto(normal: Vector3) -> Basis:
	var n := normal.normalized()
	if n.dot(Vector3.UP) > 0.999:
		return Basis()
	if n.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, n))


static func _bloom_mesh(kind: String) -> Mesh:
	if kind == "ring":
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42
		torus.outer_radius = 0.5
		torus.rings = 24
		torus.ring_segments = 6
		return torus
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	return ball


static func _additive(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color.r, color.g, color.b, 0.9)
	material.no_depth_test = false
	return material


# ================================================================== sound

## Each treatment's report and hit sound, from the `Tones` recipe: a
## sample function rendered by `Tones._synth` (22,050 Hz, 16-bit), played
## through a player `Tones._make_player` makes. Nothing new is built.
func _build_sounds() -> void:
	for cue in [["a_report", 0.42], ["a_hit", 0.12], ["b_report", 0.12],
			["b_hit", 0.04], ["c_report", 0.36], ["c_hit", 0.30]]:
		var name_in: String = cue[0]
		var stream := render(name_in, float(cue[1]))
		var sound := tones._make_player(stream)
		sound.name = "Feel_" + name_in
		var treatment := name_in.substr(0, 1)
		sound.volume_db = float(SPEC[treatment][
				"report_db" if name_in.ends_with("report") else "hit_db"])
		sounds[name_in] = sound


func _play(name_in: String) -> void:
	var sound: AudioStreamPlayer = sounds.get(name_in)
	if sound != null:
		sound.play()
		_log(name_in, sound)


## A delayed cue, dropped if the treatment changed while it waited.
func _play_for(treatment: String, name_in: String) -> void:
	if current == treatment:
		_play(name_in)


func _log(name_in: String, sound: AudioStreamPlayer) -> void:
	played.append([name_in, Engine.get_process_frames(),
			sound != null and sound.playing])


static func render(name_in: String, duration: float) -> AudioStreamWAV:
	return Tones._synth(func(t: float) -> float: return sample(name_in, t),
			duration)


## A deterministic noise source (no RNG state): the same burst every time.
static func _noise(t: float) -> float:
	return fposmod(sin(t * 12_989.8 + 78.233) * 43_758.545, 1.0) * 2.0 - 1.0


static func _sq(t: float, freq: float) -> float:
	return 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0


static func sample(name_in: String, t: float) -> float:
	match name_in:
		"a_report":
			# A falling low boom under a noise blast and a buzzing body.
			var freq := 40.0 + 22.0 * exp(-t * 12.0)
			var boom := sin(TAU * freq * t) * 0.62 * exp(-t * 7.0)
			var blast := _noise(t) * 0.55 * exp(-t * 70.0)
			var body := _sq(t, 150.0) * 0.18 * exp(-t * 30.0)
			# Scaled so the three together stay under full scale.
			return (boom + blast + body) * 0.72
		"a_hit":
			# A low knock: wood-ish body with a click on top.
			var knock := sin(TAU * 190.0 * t) * 0.6 * exp(-t * 32.0)
			var tick := _noise(t) * 0.35 * exp(-t * 400.0)
			return knock + tick
		"b_report":
			# A crack: a hard noise edge, a bright ping, a short square.
			var crack := _noise(t) * 0.75 * exp(-t * 220.0)
			var ping := sin(TAU * 1450.0 * t) * 0.25 * exp(-t * 80.0)
			var snap := _sq(t, 330.0) * 0.2 * exp(-t * 55.0)
			return crack + ping + snap
		"b_hit":
			# A bright, tight tick.
			return sin(TAU * 2100.0 * t) * 0.5 * pow(maxf(0.0,
					1.0 - t / 0.04), 3.0)
		"c_report":
			# A sweeping tone, then the same 60 ms twice more, quieter and
			# later: the shot's echo.
			return _c_body(t) + 0.45 * _c_body(t - 0.075) \
					+ 0.2 * _c_body(t - 0.15)
		"c_hit":
			# A two-note chime.
			var env := exp(-t * 14.0)
			return (sin(TAU * 1320.0 * t) * 0.3 + sin(TAU * 1980.0 * t) * 0.18) \
					* env
	return 0.0


static func _c_body(t: float) -> float:
	if t < 0.0:
		return 0.0
	var freq := 220.0 + 140.0 * exp(-t * 25.0)
	return sin(TAU * freq * t) * 0.5 * exp(-t * 16.0) \
			+ _noise(t) * 0.3 * exp(-t * 160.0)


# ============================================================ hit marker

## The treatment's hit marker, drawn over the crosshair (the HUD's own
## confirmation keeps running underneath).
class Marker extends Control:
	var kind := ""
	var life := 0.0
	var left := 0.0

	func show_mark(kind_in: String, seconds: float) -> void:
		kind = kind_in
		life = seconds
		left = seconds
		visible = true
		queue_redraw()

	func clear() -> void:
		left = 0.0
		visible = false

	func strength() -> float:
		return left / life if life > 0.0 else 0.0

	func _process(delta: float) -> void:
		if left <= 0.0:
			return
		left = maxf(0.0, left - delta)
		if left == 0.0:
			visible = false
		queue_redraw()

	func _draw() -> void:
		if left <= 0.0:
			return
		var centre := size / 2.0
		var k := strength()
		match kind:
			"heavy":
				var color := Color(1.0, 0.85, 0.6, k)
				for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1),
						Vector2(-1, -1)]:
					var dir: Vector2 = d.normalized()
					draw_line(centre + dir * (12.0 + 4.0 * k),
							centre + dir * (26.0 + 6.0 * k), color, 4.0, true)
			"crisp":
				var color := Color(1, 1, 1, minf(1.0, k * 1.5))
				for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1),
						Vector2(-1, -1)]:
					var dir: Vector2 = d.normalized()
					draw_line(centre + dir * 9.0, centre + dir * 17.0, color,
							2.0, true)
			"ring":
				draw_arc(centre, 10.0 + 18.0 * (1.0 - k), 0.0, TAU, 40,
						Color(0.5, 0.9, 1.0, k), 2.5, true)
