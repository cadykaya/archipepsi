class_name RangeWeapons
extends Node
## THE FIVE WEAPONS (01_FIVE_WEAPONS.md), as five firing behaviours in one
## isolated range. Working names, not lore; prototype numbers, not
## balance.
##
## **The shot is the engine's.** Each weapon is an Echo action equipped on
## the player's second Echo slot and fired through `EchoRuntime`'s own
## primitives:
## - Foundry and Sightline: single-pellet `hitscan_damage`;
## - Switchback: `hitscan_damage` re-armed while the trigger is held, its
##   spread growing as it fires;
## - Bulkhead: `hitscan_damage` with eight pellets;
## - Mass Driver: `charge_shot`.
## Damage, the rays, the hits and the hit confirmation are all
## `EchoRuntime`'s and `Damageable`'s. Nothing new decides a hit.
##
## **The presentation is this range's.** The left button drives the
## equipped action (the Static Pulse is held off while a weapon is out
## and handed back exactly when it is put away). `EchoRuntime`'s own
## tracers are hidden as they spawn, and each one's resolved end is read
## back. That is the hit this range draws to, from the visible muzzle of
## `RangeRig`. Its kick and flash act on the player's own viewmodel,
## which is hidden while a weapon is out.
##
## **Mass Driver's push** is a seam, not engine behaviour. `EchoProjectile`
## frees itself on a world hit and pushes nothing, so the range follows
## the real projectile and, where it ends on a `ManipulableBody`, calls
## that body's own `receive_impulse` (the existing API). The report says
## so.

signal changed(id: String)

const SLOT := "echo_b"
const IDS: Array[String] = ["foundry", "sightline", "switchback", "bulkhead",
		"driver"]
const PROFILES := {
	"foundry": {
		"name": "1 · FOUNDRY — heavy hand cannon",
		"hint": "One heavy shot at a time. Big kick, big hit: make each one count.",
		"trigger": "semi", "tracer": "slug", "power": 1.0, "mark": 1.0,
		"marker": "heavy",
		"action": {"cooldown": 0.72, "primitive": {"type": "hitscan_damage",
			"damage": 15.0, "pellets": 1, "spread_degrees": 0.0,
			"range": 45.0}}},
	"sightline": {
		"name": "2 · SIGHTLINE — scout rifle",
		"hint": "Quick, accurate, light kick. Place hit after hit at range.",
		"trigger": "semi", "tracer": "needle", "power": 0.55, "mark": 0.6,
		"marker": "crisp",
		"action": {"cooldown": 0.34, "primitive": {"type": "hitscan_damage",
			"damage": 8.0, "pellets": 1, "spread_degrees": 0.0,
			"range": 70.0}}},
	"switchback": {
		"name": "3 · SWITCHBACK — automatic carbine",
		"hint": "Hold to fire about 7 rounds a second. Track movers; it spreads at range.",
		"trigger": "auto", "tracer": "speck", "power": 0.3, "mark": 0.4,
		"marker": "crisp",
		# base spread, added per round, the most, decay per second idle
		"bloom": [1.2, 0.45, 4.5, 6.0],
		"action": {"cooldown": 0.135, "primitive": {"type": "hitscan_damage",
			"damage": 3.5, "pellets": 1, "spread_degrees": 1.2,
			"range": 32.0}}},
	"bulkhead": {
		"name": "4 · BULKHEAD — scattergun",
		"hint": "Eight pellets in a wide cone. Get close, then commit.",
		"trigger": "semi", "tracer": "pellet", "power": 1.2, "mark": 1.0,
		"marker": "heavy",
		"action": {"cooldown": 1.0, "primitive": {"type": "hitscan_damage",
			"damage": 4.5, "pellets": 8, "spread_degrees": 11.0,
			"range": 24.0}}},
	"driver": {
		"name": "5 · MASS DRIVER — charged kinetic",
		"hint": "Hold to charge, release to launch a heavy slug that shoves loose objects.",
		"trigger": "charge", "tracer": "", "power": 1.5, "mark": 1.3,
		"marker": "heavy",
		# impulse (N·s) at no charge and at full charge
		"impulse": [12.0, 70.0],
		"action": {"cooldown": 1.8, "primitive": {"type": "charge_shot",
			"charge_time": 1.1, "min_damage": 10.0, "max_damage": 45.0,
			"speed": 60.0}}},
}
## A press this close to the end of a cooldown fires as soon as it ends.
const BUFFER := 0.15

var current := ""
var player: Player
var feel: WeaponFeelTreatments
var runtime: EchoRuntime
var rig: RangeRig
var impacts: RangeImpacts
var audio: RangeAudio
var reduced_motion := false
var shots := 0
var hits := 0
var pushes := 0
## The last shot: weapon, frame, muzzle, ends (each {from, to, hit}).
var last_shot := {}
## The last Mass Driver slug's end: hit, impulse, body moved.
var last_slug := {}
var charging := false
var bloom := 0.0

var _buffer := 0.0
var _caught: Array[Node] = []
var _slugs: Array = []
var _was_held := false


func bind(host: WeaponFeel) -> void:
	name = "RangeWeapons"
	player = host.player
	feel = host.feel
	runtime = player.runtimes[SLOT]
	rig = RangeRig.new()
	rig.setup(player)
	impacts = RangeImpacts.new()
	impacts.name = "Impacts"
	add_child(impacts)
	audio = RangeAudio.new()
	audio.name = "Audio"
	add_child(audio)
	audio.setup(IDS, _placeholders(host.tones))
	player.hit_confirmed.connect(_on_hit)


## The labelled stand-ins until SigmAudio's renders land: the range's
## existing sounds, never presented as finished.
func _placeholders(tones: Tones) -> Dictionary:
	var a_report: AudioStream = (feel.sounds["a_report"] as AudioStreamPlayer).stream
	var b_report: AudioStream = (feel.sounds["b_report"] as AudioStreamPlayer).stream
	var players: Dictionary = tones._players
	var thud: AudioStream = (players["step_a"] as AudioStreamPlayer).stream
	return {
		"foundry/fire": [a_report, 1.0], "foundry/mech": [thud, 1.8],
		"sightline/fire": [b_report, 1.0], "sightline/mech": [thud, 2.2],
		"switchback/fire": [b_report, 1.35],
		"bulkhead/fire": [a_report, 0.75], "bulkhead/mech": [thud, 1.4],
		"driver/charge": [Tones._hum_loop(), 1.0],
		"driver/release": [a_report, 0.55],
		"impacts/impact_metal": [(players["hit"] as AudioStreamPlayer).stream, 1.0],
		"impacts/impact_stone": [(players["land"] as AudioStreamPlayer).stream, 1.2],
		"impacts/impact_wood": [(players["step_b"] as AudioStreamPlayer).stream, 1.5],
		"impacts/impact_organic": [thud, 0.8],
	}


func profile() -> Dictionary:
	return PROFILES.get(current, {})


## A weapon out, or "" to put it away and hand the Static Pulse back.
func select(id: String) -> void:
	if charging:
		_cancel_charge()
	if id != "" and not id in IDS:
		return
	if id == "":
		current = ""
		rig.select("")
		rig.release_camera()
		player.viewmodel.visible = true
		runtime.set_equipped({})
		player._pulse_cooldown = 0.0
		changed.emit("")
		return
	if feel.current != "baseline":
		feel.select("baseline")
	current = id
	bloom = 0.0
	_buffer = 0.0
	player.viewmodel.visible = false
	var action: Dictionary = (PROFILES[id]["action"] as Dictionary).duplicate(true)
	action["kind"] = "action"
	action["component_id"] = "range_" + id
	action["display_name"] = String(PROFILES[id]["name"]).get_slice(" — ", 0) \
			.get_slice("· ", 1)
	action["slot"] = SLOT
	action["modifiers"] = []
	runtime.set_equipped(action)
	rig.camera_motion = 0.0 if reduced_motion else 1.0
	rig.select(id)
	changed.emit(id)


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	rig.camera_motion = 0.0 if on else 1.0


# ================================================================ input

func _physics_process(delta: float) -> void:
	if current == "":
		return
	# The Pulse stays holstered while a weapon is out.
	player._pulse_cooldown = 999.0
	var held := Input.is_action_pressed("fire_pulse")
	var pressed := Input.is_action_just_pressed("fire_pulse")
	var p := profile()
	match String(p["trigger"]):
		"semi":
			if pressed:
				_buffer = BUFFER
			if _buffer > 0.0:
				if runtime.cooldown_remaining <= 0.0:
					_buffer = 0.0
					_fire()
				else:
					_buffer -= delta
		"auto":
			if held and runtime.cooldown_remaining <= 0.0:
				_fire()
			if not held:
				var spec: Array = p["bloom"]
				bloom = maxf(0.0, bloom - float(spec[3]) * delta)
				if _was_held:
					audio.play(current, "fire_tail")
		"charge":
			if pressed and not charging and runtime.cooldown_remaining <= 0.0:
				_begin_charge()
			if charging:
				var ratio := runtime.charge_ratio()
				rig.tremble(ratio)
				_charge_look(ratio, delta)
				audio.set_pitch(current, "charge", 0.8 + 0.6 * ratio)
				if not held:
					_release()
	_was_held = held
	_follow_slugs()


## Calls `call` while catching every node it adds to the tree: the
## engine's tracers and projectiles, spawned inside it.
func _catching(call: Callable) -> Array[Node]:
	_caught.clear()
	get_tree().node_added.connect(_catch)
	call.call()
	get_tree().node_added.disconnect(_catch)
	return _caught.duplicate()


func _catch(node: Node) -> void:
	if node is Tracer or node is EchoProjectile:
		_caught.append(node)
		if node is Tracer:
			(node as Tracer).visible = false


# ================================================================ the shot

func _fire() -> void:
	var p := profile()
	if current == "switchback":
		var spec: Array = p["bloom"]
		runtime.equipped["primitive"]["spread_degrees"] = float(spec[0]) + bloom
	var before := runtime.cooldown_remaining
	var caught := _catching(runtime.activate)
	if runtime.cooldown_remaining <= before:
		return  # the engine refused it
	shots += 1
	var muzzle := rig.muzzle_position()
	var ends: Array = []
	for node in caught:
		if node is Tracer:
			ends.append(_resolve(node as Tracer))
	rig.kick()
	rig.muzzle_flash()
	audio.play(current, "fire", 0.03)
	_mechanics()
	var style := String(p["tracer"])
	for i in ends.size():
		var end: Dictionary = ends[i]
		end["from"] = muzzle
		end["tracer"] = rig.tracer(style, muzzle, end["to"],
				current == "switchback" and shots % 3 == 0)
	_impacts(ends)
	last_shot = {"weapon": current, "frame": Engine.get_process_frames(),
			"muzzle": muzzle, "ends": ends,
			"spread": float(runtime.equipped["primitive"].get("spread_degrees", 0))}
	if current == "switchback":
		var spec: Array = p["bloom"]
		bloom = minf(float(spec[2]) - float(spec[0]), bloom + float(spec[1]))


## Where a hidden engine tracer ended, and what the camera's ray meets
## there: the engine's own resolved hit, read back.
func _resolve(tracer: Tracer) -> Dictionary:
	var length := (tracer.mesh as BoxMesh).size.z
	var forward := -tracer.global_basis.z
	var to := tracer.global_position + forward * length * 0.5
	var eye := player.camera.global_position
	var dir := (to - eye).normalized()
	var hit := player.camera_ray(eye.distance_to(to) + 0.05, dir)
	return {"to": to, "hit": hit}


func _impacts(ends: Array) -> void:
	var p := profile()
	var power := float(p["power"])
	var mark := float(p["mark"])
	if current == "bulkhead":
		_scatter(ends, power, mark)
		return
	for end in ends:
		var hit: Dictionary = end["hit"]
		if hit.is_empty():
			continue
		var info := impacts.impact(hit["position"], hit["normal"],
				hit["collider"], power, mark, current != "switchback")
		end["material"] = info["material"]
		if current != "switchback" or shots % 2 == 0:
			audio.play_at("impact_" + String(info["material"]),
					hit["position"], get_tree().current_scene)


## A scattergun's pellets: one coherent blast where most of them landed,
## a chip mark for up to three others, nothing for the rest.
func _scatter(ends: Array, power: float, mark: float) -> void:
	var groups := {}
	for end in ends:
		var hit: Dictionary = end["hit"]
		if hit.is_empty():
			continue
		var key: Object = hit["collider"]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(end)
	if groups.is_empty():
		return
	var best: Object = null
	for key in groups:
		if best == null or groups[key].size() > groups[best].size():
			best = key
	var main: Array = groups[best]
	var centroid := Vector3.ZERO
	for end in main:
		centroid += end["hit"]["position"]
	centroid /= main.size()
	var center: Dictionary = main[0]
	for end in main:
		if (end["hit"]["position"] as Vector3).distance_to(centroid) \
				< (center["hit"]["position"] as Vector3).distance_to(centroid):
			center = end
	var hit: Dictionary = center["hit"]
	var share := float(main.size()) / 8.0
	var info := impacts.impact(hit["position"], hit["normal"], hit["collider"],
			power * (0.5 + share), mark, true)
	for end in ends:
		end["material"] = RangeImpacts.material_of(end["hit"].get("collider"))
	audio.play_at("impact_" + String(info["material"]), hit["position"],
			get_tree().current_scene)
	var chips := 0
	for end in ends:
		if chips >= 3 or end == center or end["hit"].is_empty():
			continue
		impacts.chip(end["hit"]["position"], end["hit"]["normal"],
				end["hit"]["collider"])
		chips += 1


## Each gun's moving parts and the mechanical cue that goes with them.
func _mechanics() -> void:
	match current:
		"foundry":
			_later(0.5, _mech_cue.bind("foundry"))
		"sightline":
			var handle := rig.part("handle")
			_slide(handle, 0.02, 0.1, 0.05)
			_later(0.12, _mech_cue.bind("sightline"))
		"switchback":
			_slide(rig.part("bolt"), 0.035, 0.0, 0.03)
		"bulkhead":
			_later(0.3, _pump)


func _pump() -> void:
	if current != "bulkhead":
		return
	_slide(rig.part("pump"), 0.1, 0.0, 0.13)
	rig.nudge("roll", 6.0, 80.0)
	rig.nudge("back", 0.02, 0.3)
	audio.play("bulkhead", "mech")


func _mech_cue(weapon: String) -> void:
	if current == weapon:
		audio.play(weapon, "mech")


## Slides a part back along the barrel and home again.
func _slide(part: Node3D, distance: float, delay: float, each: float) -> void:
	if part == null:
		return
	if not part.has_meta("rest"):
		part.set_meta("rest", part.position)
	var rest: Vector3 = part.get_meta("rest")
	var tween := part.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(part, "position", rest + Vector3(0, 0, distance), each)
	tween.tween_property(part, "position", rest, each * 1.2)


func _later(seconds: float, call: Callable) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(call)


func _on_hit(_killed: bool) -> void:
	if current == "":
		return
	hits += 1
	feel._marker.show_mark(String(profile()["marker"]),
			0.16 if profile()["marker"] == "heavy" else 0.08)


# ============================================================ Mass Driver

func _begin_charge() -> void:
	var before := runtime.cooldown_remaining
	_catching(runtime.activate)
	if runtime.cooldown_remaining <= before:
		return
	charging = true
	audio.play("driver", "charge")


func _cancel_charge() -> void:
	charging = false
	runtime.cancel_holds()
	audio.stop("driver", "charge")
	rig.tremble(0.0)
	_charge_look(0.0, 0.0)


func _release() -> void:
	var ratio := runtime.charge_ratio()
	charging = false
	var caught := _catching(runtime.release)
	audio.stop("driver", "charge")
	audio.play("driver", "release")
	shots += 1
	rig.tremble(0.0)
	rig.show_charge(0.0)
	rig.kick(0.5 + 0.5 * ratio)
	rig.muzzle_flash(0.6 + 0.6 * ratio)
	_power_down()
	for node in caught:
		if node is EchoProjectile:
			_adopt(node as EchoProjectile, ratio, rig.muzzle_position())
	last_shot = {"weapon": "driver", "frame": Engine.get_process_frames(),
			"muzzle": rig.muzzle_position(), "ratio": ratio, "ends": []}


## The accumulator glows and the coils spin up with the charge.
func _charge_look(ratio: float, delta: float) -> void:
	rig.show_charge(ratio)
	var core := rig.part("core")
	if core != null:
		(core.material_override as StandardMaterial3D) \
				.emission_energy_multiplier = 4.0 * ratio
	var coils := rig.part("coils")
	if coils != null:
		coils.rotation.z += delta * (2.0 + 22.0 * ratio)


## After the release the accumulator flares, then dims over 0.7 s.
func _power_down() -> void:
	var core := rig.part("core")
	if core == null:
		return
	var glow := core.material_override as StandardMaterial3D
	glow.emission_energy_multiplier = 7.0
	var tween := core.create_tween()
	tween.tween_property(glow, "emission_energy_multiplier", 0.0, 0.7) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Follows the engine's projectile: a heavier look on it, and where it
## ends, the impact and (on a loose body) the push.
func _adopt(slug: EchoProjectile, ratio: float, muzzle: Vector3) -> void:
	var record := {"node": slug, "last": slug.global_position,
			"dir": slug.direction, "speed": slug.speed, "ratio": ratio}
	_slugs.append(record)
	slug.tree_exiting.connect(_slug_end.bind(record))
	_reskin.call_deferred(slug, ratio, muzzle)


## The engine's projectile flies from the camera's line (aim truth); its
## visible slug starts at the gun's muzzle and closes onto it in 0.12 s.
func _reskin(slug: EchoProjectile, ratio: float, muzzle: Vector3) -> void:
	if not is_instance_valid(slug):
		return
	for child in slug.get_children():
		var conceal := child is Node3D and not (child is CollisionShape3D)
		if conceal:
			(child as Node3D).visible = false
	var body := MeshInstance3D.new()
	body.name = "Slug"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.05 + 0.03 * ratio
	capsule.height = 0.35 + 0.25 * ratio
	body.mesh = capsule
	body.material_override = HandCannon._additive(Color(0.95, 0.93, 1.0), 0.95)
	slug.add_child(body)
	var dir := slug.direction.normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	body.basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI / 2.0)
	body.global_position = muzzle
	var close := body.create_tween()
	close.tween_property(body, "position", Vector3.ZERO, 0.12) \
			.set_ease(Tween.EASE_OUT)
	var heat := CPUParticles3D.new()
	heat.name = "Wake"
	heat.amount = 24
	heat.lifetime = 0.35
	heat.local_coords = false
	heat.gravity = Vector3.ZERO
	heat.initial_velocity_min = 0.0
	heat.initial_velocity_max = 0.2
	var puff := QuadMesh.new()
	puff.size = Vector2(0.12, 0.12)
	heat.mesh = puff
	var material := HandCannon._alpha(Color(0.8, 0.78, 0.82, 0.25))
	material.albedo_texture = HandCannon._tex_soft()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	heat.material_override = material
	slug.add_child(heat)
	heat.emitting = true


func _follow_slugs() -> void:
	for record in _slugs:
		var slug: EchoProjectile = record["node"]
		if is_instance_valid(slug) and slug.is_inside_tree():
			record["last"] = slug.global_position
			record["dir"] = slug.direction


func _slug_end(record: Dictionary) -> void:
	_slugs.erase(record)
	if not is_inside_tree() or is_queued_for_deletion() \
			or get_tree().current_scene == null:
		return
	var dir: Vector3 = record["dir"]
	var from: Vector3 = record["last"] - dir * 0.3
	var reach := float(record["speed"]) / 60.0 * 4.0 + 0.6
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		last_slug = {"hit": {}, "pushed": false}
		return
	var ratio := float(record["ratio"])
	var p: Dictionary = PROFILES["driver"]
	impacts.impact(hit["position"], hit["normal"], hit["collider"],
			0.8 + 0.7 * ratio, 0.8 + 0.5 * ratio, true)
	audio.play_at("impact_" + RangeImpacts.material_of(hit["collider"]),
			hit["position"], get_tree().current_scene)
	var spec: Array = p["impulse"]
	var impulse := dir * lerpf(float(spec[0]), float(spec[1]), ratio)
	var body: Object = hit["collider"]
	var pushed := false
	if body != null and body.has_method("receive_impulse"):
		body.receive_impulse(impulse)
		pushes += 1
		pushed = true
	last_slug = {"hit": hit, "pushed": pushed, "impulse": impulse,
			"ratio": ratio}
